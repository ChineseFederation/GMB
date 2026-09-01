#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-host}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$ROOT/native/Cargo.toml"
TARGET_DIR="${CARGO_TARGET_DIR:-$ROOT/native/target}"
export CARGO_TARGET_DIR="$TARGET_DIR"

ensure_target() {
  local target="$1"
  if ! rustup target list --installed | grep -qx "$target"; then
    rustup target add "$target"
  fi
}

assert_symbols() {
  local library="$1"
  local nm_bin="${2:-nm}"
  local symbols
  symbols="$("$nm_bin" -g "$library" 2>/dev/null | awk '{print $NF}' || true)"
  local required_symbols=(
    chat_sdk_mls_create_key_package_json
    chat_sdk_mls_group_create_json
    chat_sdk_mls_group_add_members_json
    chat_sdk_mls_group_remove_members_json
    chat_sdk_mls_group_create_message_json
    chat_sdk_mls_group_process_json
    chat_sdk_mls_group_state_json
    chat_sdk_free_string
  )
  local symbol
  for symbol in "${required_symbols[@]}"; do
    if [[ "$(grep -Ec "^_?${symbol}$" <<<"$symbols" || true)" != 1 ]]; then
      printf 'ChatSDK required symbol %s must occur once in %s\n' \
        "$symbol" "$library" >&2
      exit 1
    fi
  done

  # 中文注释：原始 HPKE 与独立设备身份接口已被统一 OpenMLS 群协议取代，禁止重新导出。
  if grep -Eq '^_?chat_sdk_(device_identity|mls_encrypt|mls_decrypt)_json$' <<<"$symbols"; then
    printf 'ChatSDK legacy direct-encryption symbols found in %s\n' "$library" >&2
    exit 1
  fi
}

build_host() {
  cargo build --manifest-path "$MANIFEST"
  case "$(uname -s)" in
    Darwin) library="$TARGET_DIR/debug/libchat_sdk.dylib" ;;
    Linux) library="$TARGET_DIR/debug/libchat_sdk.so" ;;
    *) printf 'Unsupported ChatSDK host\n' >&2; exit 1 ;;
  esac
  assert_symbols "$library"
}

build_android() {
  : "${TATA_CONSOLE_NATIVE_ANDROID_DIR:?TATA_CONSOLE_NATIVE_ANDROID_DIR is required}"
  ensure_target aarch64-linux-android

  local ndk_home="${ANDROID_NDK_HOME:-}"
  if [[ -z "$ndk_home" ]]; then
    local sdk_home="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
    ndk_home="$(ls -d "$sdk_home/ndk/"* 2>/dev/null | sort -V | tail -1 || true)"
  fi
  [[ -d "$ndk_home" ]] || { printf 'Android NDK not found\n' >&2; exit 1; }

  local toolchain
  case "$(uname -s)" in
    Darwin)
      toolchain="$ndk_home/toolchains/llvm/prebuilt/darwin-x86_64"
      [[ -d "$toolchain" ]] ||
        toolchain="$ndk_home/toolchains/llvm/prebuilt/darwin-aarch64"
      ;;
    Linux) toolchain="$ndk_home/toolchains/llvm/prebuilt/linux-x86_64" ;;
    *) printf 'Unsupported Android build host\n' >&2; exit 1 ;;
  esac
  [[ -d "$toolchain" ]] || {
    printf 'Android NDK toolchain not found\n' >&2
    exit 1
  }

  export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="$toolchain/bin/aarch64-linux-android24-clang"
  export CC_aarch64_linux_android="$toolchain/bin/aarch64-linux-android24-clang"
  export AR_aarch64_linux_android="$toolchain/bin/llvm-ar"
  cargo build --manifest-path "$MANIFEST" --release --target aarch64-linux-android

  local destination="$TATA_CONSOLE_NATIVE_ANDROID_DIR/arm64-v8a"
  mkdir -p "$destination"
  cp "$TARGET_DIR/aarch64-linux-android/release/libchat_sdk.so" "$destination/"
  assert_symbols "$destination/libchat_sdk.so" "$toolchain/bin/llvm-nm"
}

build_ios() {
  : "${TATA_CONSOLE_NATIVE_IOS_DIR:?TATA_CONSOLE_NATIVE_IOS_DIR is required}"
  ensure_target aarch64-apple-ios
  export IPHONEOS_DEPLOYMENT_TARGET=16.0
  # Write the final framework install name during the Rust link. Rust 1.97's
  # Mach-O strip path can leave LC_SYMTAB.stroff only 4-byte aligned, which
  # current Xcode rejects; keep Rust output unstripped and let Xcode process the
  # final signed app instead.
  local ios_rustflags="${RUSTFLAGS:-}"
  ios_rustflags="${ios_rustflags:+$ios_rustflags }-C strip=none -C link-arg=-Wl,-install_name,@rpath/ChatSDK.framework/ChatSDK"
  RUSTFLAGS="$ios_rustflags" \
    cargo build --manifest-path "$MANIFEST" --release --target aarch64-apple-ios

  local library="$TARGET_DIR/aarch64-apple-ios/release/libchat_sdk.dylib"
  local framework_root="$TARGET_DIR/ios-framework"
  local framework="$framework_root/ChatSDK.framework"
  local xcframework="$TATA_CONSOLE_NATIVE_IOS_DIR/ChatSDK.xcframework"
  local nm_bin
  nm_bin="$(xcrun --find llvm-nm)"
  assert_symbols "$library" "$nm_bin"
  local string_offset
  string_offset="$(otool -l "$library" | awk '/cmd LC_SYMTAB/{active=1;next} active&&/cmd /{active=0} active&&/stroff/{print $2}')"
  [[ -n "$string_offset" && $((string_offset % 8)) -eq 0 ]] || {
    printf 'ChatSDK iOS LINKEDIT string pool is not 8-byte aligned\n' >&2
    exit 1
  }

  # 中文注释：ChatSDK 以自己的动态 Framework 进入宿主，Smoldot 不再承载或
  # 保活任何聊天符号。Framework 的 install name 固定为标准 @rpath，由 Xcode
  # 嵌入并签名，Dart FFI 只解析这一份已经装载的动态库。
  if [[ -e "$framework_root" ]]; then
    find "$framework_root" -depth -delete
  fi
  mkdir -p "$framework/Headers" "$framework/Modules"
  cp "$library" "$framework/ChatSDK"
  chmod 755 "$framework/ChatSDK"
  cp "$ROOT/include/chat_sdk.h" "$framework/Headers/chat_sdk.h"
  cat > "$framework/Modules/module.modulemap" <<'MODULEMAP'
framework module ChatSDK {
  umbrella header "chat_sdk.h"
  export *
}
MODULEMAP
  cat > "$framework/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>ChatSDK</string>
  <key>CFBundleIdentifier</key><string>org.cocoapods.ChatSDK</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>ChatSDK</string>
  <key>CFBundlePackageType</key><string>FMWK</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>MinimumOSVersion</key><string>16.0</string>
</dict>
</plist>
PLIST
  assert_symbols "$framework/ChatSDK" "$nm_bin"

  mkdir -p "$TATA_CONSOLE_NATIVE_IOS_DIR"
  if [[ -e "$xcframework" ]]; then
    find "$xcframework" -depth -delete
  fi
  xcodebuild -create-xcframework -framework "$framework" -output "$xcframework"

  # CocoaPods only accepts vendored frameworks inside the Pod root. A Flutter
  # host provides this optional package directory during its iOS build; stage only a
  # temporary symlink, while the actual bytes remain in TataConsole storage.
  if [[ -n "${CHATSDK_PACKAGE_IOS_DIR:-}" ]]; then
    local staged="$CHATSDK_PACKAGE_IOS_DIR/ChatSDK.xcframework"
    mkdir -p "$CHATSDK_PACKAGE_IOS_DIR"
    if [[ -e "$staged" && ! -L "$staged" ]]; then
      printf 'ChatSDK iOS stage path is occupied by a non-symlink: %s\n' "$staged" >&2
      exit 1
    fi
    rm -f "$staged"
    ln -s "$xcframework" "$staged"
  fi

  local packaged
  packaged="$(find "$xcframework" -type f -path '*/ChatSDK.framework/ChatSDK' -print -quit)"
  [[ -n "$packaged" ]] || {
    printf 'ChatSDK XCFramework missing dynamic binary\n' >&2
    exit 1
  }
  [[ "$(lipo -archs "$packaged")" == arm64 ]] || {
    printf 'ChatSDK iOS framework must contain only arm64\n' >&2
    exit 1
  }
  assert_symbols "$packaged" "$nm_bin"
  otool -D "$packaged" | tail -n +2 | grep -qx '@rpath/ChatSDK.framework/ChatSDK' || {
    printf 'ChatSDK iOS framework install name is invalid\n' >&2
    exit 1
  }
}

verify_android_package() {
  local package="${1:?Android package is required}"
  local entry temporary packaged nm_bin
  [[ -f "$package" ]] || { printf 'Android package not found: %s\n' "$package" >&2; exit 1; }
  case "$package" in
    *.apk) entry='lib/arm64-v8a/libchat_sdk.so' ;;
    *.aab) entry='base/lib/arm64-v8a/libchat_sdk.so' ;;
    *) printf 'Unsupported Android package: %s\n' "$package" >&2; exit 1 ;;
  esac
  temporary="$(mktemp -d)"
  packaged="$temporary/libchat_sdk.so"
  unzip -p "$package" "$entry" > "$packaged" || {
    find "$temporary" -depth -delete
    printf 'Android package missing ChatSDK library\n' >&2
    exit 1
  }
  nm_bin="${ANDROID_NM:-}"
  if [[ -z "$nm_bin" ]]; then
    local sdk_home="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
    nm_bin="$(ls "$sdk_home"/ndk/*/toolchains/llvm/prebuilt/*/bin/llvm-nm 2>/dev/null | tail -1 || true)"
  fi
  [[ -n "$nm_bin" ]] || {
    find "$temporary" -depth -delete
    printf 'Android llvm-nm not found\n' >&2
    exit 1
  }
  assert_symbols "$packaged" "$nm_bin"
  find "$temporary" -depth -delete
  if unzip -Z1 "$package" | grep -E '(^|/)lib/(armeabi-v7a|x86|x86_64)/libchat_sdk\.so$'; then
    printf 'Android package contains unsupported ChatSDK ABI\n' >&2
    exit 1
  fi
}

verify_ios_package() {
  local app_bundle="${1:?Runner.app is required}"
  local executable="$app_bundle/Runner"
  local framework="$app_bundle/Frameworks/ChatSDK.framework/ChatSDK"
  local nm_bin
  [[ -f "$executable" ]] || { printf 'iOS Runner not found\n' >&2; exit 1; }
  [[ -f "$framework" ]] || { printf 'iOS package missing ChatSDK.framework\n' >&2; exit 1; }
  [[ "$(lipo -archs "$framework")" == arm64 ]] || {
    printf 'Packaged ChatSDK framework must contain only arm64\n' >&2
    exit 1
  }
  file "$framework" | grep -q 'dynamically linked shared library' || {
    printf 'Packaged ChatSDK binary is not a dynamic framework\n' >&2
    exit 1
  }
  otool -L "$executable" | grep -q '@rpath/ChatSDK.framework/ChatSDK' || {
    printf 'iOS Runner does not link the independent ChatSDK framework\n' >&2
    exit 1
  }
  nm_bin="$(xcrun --find llvm-nm)"
  assert_symbols "$framework" "$nm_bin"
}

case "$MODE" in
  host|macos) build_host ;;
  android) build_android ;;
  ios) build_ios ;;
  verify-android-package) verify_android_package "${2:-}" ;;
  verify-ios-package) verify_ios_package "${2:-}" ;;
  *) printf 'Usage: %s [host|macos|android|ios|verify-android-package|verify-ios-package]\n' "$0" >&2; exit 64 ;;
esac
