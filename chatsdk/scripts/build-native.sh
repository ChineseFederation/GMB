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
  if ! grep -Eq '^_?chat_sdk_mls_' <<<"$symbols"; then
    printf 'ChatSDK OpenMLS symbols missing from %s\n' "$library" >&2
    exit 1
  fi
  if [[ "$(grep -Ec '^_?chat_sdk_device_identity_json$' <<<"$symbols" || true)" != 1 ]]; then
    printf 'ChatSDK device identity symbol must occur once in %s\n' "$library" >&2
    exit 1
  fi
  if [[ "$(grep -Ec '^_?chat_sdk_free_string$' <<<"$symbols" || true)" != 1 ]]; then
    printf 'ChatSDK string release symbol must occur once in %s\n' "$library" >&2
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
  : "${PROGRAM_CONSOLE_NATIVE_ANDROID_DIR:?PROGRAM_CONSOLE_NATIVE_ANDROID_DIR is required}"
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

  local destination="$PROGRAM_CONSOLE_NATIVE_ANDROID_DIR/arm64-v8a"
  mkdir -p "$destination"
  cp "$TARGET_DIR/aarch64-linux-android/release/libchat_sdk.so" "$destination/"
  assert_symbols "$destination/libchat_sdk.so" "$toolchain/bin/llvm-nm"
}

build_ios() {
  : "${PROGRAM_CONSOLE_NATIVE_IOS_DIR:?PROGRAM_CONSOLE_NATIVE_IOS_DIR is required}"
  ensure_target aarch64-apple-ios
  cargo build --manifest-path "$MANIFEST" --release --target aarch64-apple-ios

  local library="$TARGET_DIR/aarch64-apple-ios/release/libchat_sdk.a"
  assert_symbols "$library" "$(xcrun --find llvm-nm)"
  mkdir -p "$PROGRAM_CONSOLE_NATIVE_IOS_DIR"
  cp "$library" "$PROGRAM_CONSOLE_NATIVE_IOS_DIR/libchat_sdk.a"
  cp "$library" "$ROOT/ios/libchat_sdk.a"
}

case "$MODE" in
  host|macos) build_host ;;
  android) build_android ;;
  ios) build_ios ;;
  *) printf 'Usage: %s [host|macos|android|ios]\n' "$0" >&2; exit 64 ;;
esac
