#!/usr/bin/env bash
# CitizenSDK 原生核心唯一构建入口。源码目录只读，Cargo 与平台产物必须写入显式的外部目录。
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
sdk_dir="$(dirname "$script_dir")"
ffi_manifest="$sdk_dir/native/smoldot/ffi/Cargo.toml"
target_name="${1:-all}"
console_target_root="/Users/rhett/Only/console/target/citizensdk"

fail() {
  echo "CitizenSDK 原生构建失败：$1" >&2
  exit 1
}

canonical_directory() {
  local path="$1" label="$2"
  [[ -n "$path" ]] || fail "缺少 $label"
  [[ ! -L "$path" ]] || fail "$label 禁止使用符号链接：$path"
  mkdir -p "$path"
  (cd "$path" && pwd -P)
}

# 中文注释：GitHub Actions 使用 Runner 临时盘；当前开发机的任何本地记录只能进入
# Console 统一 target/citizensdk。先检查原始路径，避免错误输入也创建目录。
if [[ "${GITHUB_ACTIONS:-}" != true ]]; then
  for path in "${CITIZENSDK_WORK_DIR:-}" "${CITIZENSDK_NATIVE_OUTPUT_DIR:-}"; do
    case "$path/" in
      "$console_target_root/"*) ;;
      *) fail "本机构建目录必须位于 $console_target_root：${path:-<empty>}" ;;
    esac
  done
fi

work_dir="$(canonical_directory "${CITIZENSDK_WORK_DIR:-}" CITIZENSDK_WORK_DIR)"
output_dir="$(canonical_directory "${CITIZENSDK_NATIVE_OUTPUT_DIR:-}" CITIZENSDK_NATIVE_OUTPUT_DIR)"

# 中文注释：无论本机、Console 还是 GitHub runner，都禁止把 Cargo、二进制或符号清单
# 回写到 SDK 源码树；Console 本机调用时两个目录必须位于 console/target/citizensdk。
for directory in "$work_dir" "$output_dir"; do
  case "$directory/" in
    "$sdk_dir/"*) fail "工作目录或产物目录位于 CitizenSDK 源码树：$directory" ;;
  esac
  if [[ "${GITHUB_ACTIONS:-}" != true ]]; then
    case "$directory/" in
      "$console_target_root/"*) ;;
      *) fail "本机构建真实路径越出 $console_target_root：$directory" ;;
    esac
  fi
done

export CARGO_TARGET_DIR="$work_dir/cargo"

require_rust_target() {
  local target="$1"
  rustup target list --installed | grep -Fxq "$target" \
    || fail "Rust 目标未预装：$target"
}

assert_new_file() {
  [[ ! -e "$1" ]] || fail "目标文件已存在，拒绝覆盖：$1"
}

symbol_list_android() {
  local library="$1" nm_bin="$2"
  {
    "$nm_bin" -D --defined-only "$library" 2>/dev/null \
      | awk '{ print $NF }' \
      | grep -E '^(smoldot_|citizen_[a-z0-9_]+|account_crypto_)' \
      | sort -u
  } || true
}

symbol_list_ios() {
  local library="$1" nm_bin="$2"
  {
    ("$nm_bin" -g --defined-only "$library" 2>/dev/null || true) \
      | awk '$2 == "T" { print $3 }' \
      | grep -E '^_(smoldot_|citizen_[a-z0-9_]+|account_crypto_)' \
      | sort -u
  } || true
}

verify_symbol_contract() {
  local symbols="$1" prefix="$2" label="$3" normalized signer_count smoldot_count
  normalized="$(printf '%s\n' "$symbols" | sed "s/^${prefix}//")"
  smoldot_count="$(printf '%s\n' "$normalized" | grep -c '^smoldot_' || true)"
  signer_count="$(printf '%s\n' "$normalized" | grep -c '^citizen_sr25519_' || true)"
  [[ "$smoldot_count" -gt 0 ]] || fail "$label 缺少 smoldot_* 轻节点符号"
  [[ "$signer_count" -eq 4 ]] || fail "$label 的 citizen_sr25519_* 符号必须正好为 4 个"
  for symbol in \
    citizen_sr25519_derive_hard \
    citizen_sr25519_public_key \
    citizen_sr25519_sign \
    citizen_sr25519_verify; do
    printf '%s\n' "$normalized" | grep -Fxq "$symbol" || fail "$label 缺少 $symbol"
  done
  if printf '%s\n' "$normalized" | grep -Eq '^(citizen_chat_mls_|account_crypto_)'; then
    fail "$label 混入聊天或产品账户密码学符号"
  fi
}

android_toolchain() {
  local ndk_home="${ANDROID_NDK_HOME:-}" sdk_home host_tag
  if [[ -z "$ndk_home" ]]; then
    sdk_home="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
    [[ -n "$sdk_home" && -d "$sdk_home/ndk" ]] || fail "缺少 ANDROID_NDK_HOME 或 Android SDK NDK"
    ndk_home="$(find "$sdk_home/ndk" -mindepth 1 -maxdepth 1 -type d -print | sort | tail -1)"
  fi
  [[ -d "$ndk_home" ]] || fail "Android NDK 不存在：$ndk_home"
  case "$(uname -s)-$(uname -m)" in
    Darwin-arm64)
      host_tag=darwin-aarch64
      [[ -d "$ndk_home/toolchains/llvm/prebuilt/$host_tag" ]] || host_tag=darwin-x86_64
      ;;
    Darwin-x86_64)
      host_tag=darwin-x86_64
      [[ -d "$ndk_home/toolchains/llvm/prebuilt/$host_tag" ]] || host_tag=darwin-aarch64
      ;;
    Linux-x86_64) host_tag=linux-x86_64 ;;
    *) fail "不支持的 Android 构建宿主：$(uname -s)-$(uname -m)" ;;
  esac
  local toolchain="$ndk_home/toolchains/llvm/prebuilt/$host_tag"
  [[ -d "$toolchain" ]] || fail "Android NDK toolchain 不存在：$toolchain"
  printf '%s\n' "$toolchain"
}

build_android() {
  require_rust_target aarch64-linux-android
  local toolchain destination source_library symbols
  toolchain="$(android_toolchain)"
  destination="$output_dir/android/arm64-v8a/libsmoldot.so"
  assert_new_file "$destination"
  mkdir -p "$(dirname "$destination")"
  export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="$toolchain/bin/aarch64-linux-android24-clang"
  export CC_aarch64_linux_android="$toolchain/bin/aarch64-linux-android24-clang"
  export AR_aarch64_linux_android="$toolchain/bin/llvm-ar"
  cargo build --manifest-path "$ffi_manifest" --release --locked --target aarch64-linux-android
  source_library="$CARGO_TARGET_DIR/aarch64-linux-android/release/libsmoldot.so"
  [[ -f "$source_library" ]] || fail "Android 原生库未生成"
  cp "$source_library" "$destination"
  symbols="$(symbol_list_android "$destination" "$toolchain/bin/llvm-nm")"
  verify_symbol_contract "$symbols" "" "Android libsmoldot.so"
  echo "CitizenSDK Android ARM64 原生库完成：$destination"
}

build_ios() {
  require_rust_target aarch64-apple-ios
  local destination symbols_path source_library nm_bin symbols
  destination="$output_dir/ios/libsmoldot.a"
  symbols_path="$output_dir/ios/exported_symbols.txt"
  assert_new_file "$destination"
  assert_new_file "$symbols_path"
  mkdir -p "$(dirname "$destination")"
  cargo build --manifest-path "$ffi_manifest" --release --locked --target aarch64-apple-ios
  source_library="$CARGO_TARGET_DIR/aarch64-apple-ios/release/libsmoldot.a"
  [[ -f "$source_library" ]] || fail "iOS 原生库未生成"
  cp "$source_library" "$destination"
  nm_bin="$(xcrun --find llvm-nm)"
  symbols="$(symbol_list_ios "$destination" "$nm_bin")"
  verify_symbol_contract "$symbols" "_" "iOS libsmoldot.a"
  printf '%s\n' "$symbols" > "$symbols_path"
  echo "CitizenSDK iOS ARM64 原生库完成：$destination"
}

build_host() {
  [[ "$(uname -s)" == "Darwin" ]] || fail "当前宿主测试库只允许在 macOS runner 构建"
  local destination source_library nm_bin symbols
  destination="$output_dir/host/libsmoldot.dylib"
  assert_new_file "$destination"
  mkdir -p "$(dirname "$destination")"
  # 中文注释：这份 dylib 只供 flutter_tester 动态加载，不进入 SDK Release 平台集合。
  CARGO_PROFILE_RELEASE_STRIP=false cargo build --manifest-path "$ffi_manifest" --release --locked
  source_library="$CARGO_TARGET_DIR/release/libsmoldot.dylib"
  [[ -f "$source_library" ]] || fail "macOS 宿主测试库未生成"
  cp "$source_library" "$destination"
  nm_bin="$(xcrun --find llvm-nm)"
  symbols="$(symbol_list_ios "$destination" "$nm_bin")"
  verify_symbol_contract "$symbols" "_" "macOS 宿主测试库"
  echo "CitizenSDK macOS 宿主测试库完成：$destination"
}

verify_outputs() {
  local android_library="$output_dir/android/arm64-v8a/libsmoldot.so"
  local ios_library="$output_dir/ios/libsmoldot.a"
  local ios_symbols="$output_dir/ios/exported_symbols.txt"
  [[ -f "$android_library" && -f "$ios_library" && -f "$ios_symbols" ]] \
    || fail "Android/iOS 原生产物集合不完整"
  local toolchain nm_bin extracted
  toolchain="$(android_toolchain)"
  verify_symbol_contract "$(symbol_list_android "$android_library" "$toolchain/bin/llvm-nm")" "" "Android libsmoldot.so"
  nm_bin="$(xcrun --find llvm-nm)"
  extracted="$(symbol_list_ios "$ios_library" "$nm_bin")"
  verify_symbol_contract "$extracted" "_" "iOS libsmoldot.a"
  [[ "$(printf '%s\n' "$extracted")" == "$(sed '/^[[:space:]]*$/d' "$ios_symbols")" ]] \
    || fail "iOS exported_symbols.txt 与真实静态库不一致"
  echo "CitizenSDK Android/iOS 原生产物合同通过"
}

case "$target_name" in
  android) build_android ;;
  ios) build_ios ;;
  host) build_host ;;
  all) build_android; build_ios; build_host; verify_outputs ;;
  verify) verify_outputs ;;
  *) fail "用法：$0 [android|ios|host|all|verify]" ;;
esac
