#!/usr/bin/env bash
# CitizenSDK 原生核心唯一构建入口。源码目录只读，Cargo 与平台产物必须写入显式的外部目录。
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
sdk_dir="$(dirname "$script_dir")"
ffi_manifest="$sdk_dir/native/smoldot/ffi/Cargo.toml"
product_ffi_manifest="$sdk_dir/native/ffi/Cargo.toml"
product_header="$sdk_dir/include/citizensdk.h"
product_types_header="$sdk_dir/include/citizensdk_types.h"
android_gradle_project="$sdk_dir/android"
darwin_source_root="$sdk_dir/darwin/Sources/CitizenSDK"
darwin_flutter_source_root="$sdk_dir/darwin/Sources/CitizenSDKFlutter"
apple_asset_root="$sdk_dir/assets/citizenchain"
target_name="${1:-all}"
tata_console_target_root="/Users/rhett/TATA/tataconsole/target/citizensdk"
ios_deployment_target=16.0
macos_deployment_target=13.0
android_ndk_version=28.2.13676358

fail() {
  echo "CitizenSDK 原生构建失败：$1" >&2
  exit 1
}

assert_safe_directory_path() {
  local path="$1" label="$2" component current=''
  local -a components
  [[ -n "$path" && "$path" == /* && "$path" != */ && "$path" != *//* ]] \
    || fail "$label 必须使用不含重复分隔符的绝对规范路径：${path:-<empty>}"
  IFS='/' read -r -a components <<<"$path"
  for component in "${components[@]}"; do
    [[ -n "$component" ]] || continue
    [[ "$component" != . && "$component" != .. ]] \
      || fail "$label 禁止包含 . 或 .. 路径段：$path"
    current="$current/$component"
    [[ ! -L "$current" ]] || fail "$label 的既存路径祖先禁止使用符号链接：$current"
    if [[ -e "$current" && ! -d "$current" ]]; then
      fail "$label 的既存路径不是目录：$current"
    fi
    [[ -e "$current" ]] || break
  done
}

canonical_directory() {
  local path="$1" label="$2"
  [[ -n "$path" ]] || fail "缺少 $label"
  assert_safe_directory_path "$path" "$label"
  mkdir -p "$path"
  (cd "$path" && pwd -P)
}

# 中文注释：GitHub Actions 使用 Runner 临时盘；当前开发机的任何本地记录只能进入
# TataConsole 统一 target/citizensdk。先检查原始路径，避免错误输入也创建目录。
if [[ "${GITHUB_ACTIONS:-}" != true ]]; then
  for path in "${CITIZENSDK_WORK_DIR:-}" "${CITIZENSDK_NATIVE_OUTPUT_DIR:-}"; do
    assert_safe_directory_path "$path" 本机构建目录
    case "$path/" in
      "$tata_console_target_root/"*) ;;
      *) fail "本机构建目录必须位于 $tata_console_target_root：${path:-<empty>}" ;;
    esac
  done
fi

work_dir="$(canonical_directory "${CITIZENSDK_WORK_DIR:-}" CITIZENSDK_WORK_DIR)"
output_dir="$(canonical_directory "${CITIZENSDK_NATIVE_OUTPUT_DIR:-}" CITIZENSDK_NATIVE_OUTPUT_DIR)"

# 中文注释：无论本机、TataConsole 还是 GitHub runner，都禁止把 Cargo、二进制或符号清单
# 回写到 SDK 源码树；TataConsole 本机调用时两个目录必须位于
# /Users/rhett/TATA/tataconsole/target/citizensdk。
for directory in "$work_dir" "$output_dir"; do
  case "$directory/" in
    "$sdk_dir/"*) fail "工作目录或产物目录位于 CitizenSDK 源码树：$directory" ;;
  esac
  if [[ "${GITHUB_ACTIONS:-}" != true ]]; then
    case "$directory/" in
      "$tata_console_target_root/"*) ;;
      *) fail "本机构建真实路径越出 $tata_console_target_root：$directory" ;;
    esac
  fi
done

require_rust_target() {
  local target="$1"
  rustup target list --installed | grep -Fxq "$target" \
    || fail "Rust 目标未预装：$target"
}

assert_new_file() {
  [[ ! -e "$1" && ! -L "$1" ]] || fail "目标文件已存在或是符号链接，拒绝覆盖：$1"
}

assert_descendant_path() {
  local root="$1" path="$2" label="$3"
  [[ "$path" != "$root" ]] || fail "$label 不能等于受控根目录：$path"
  case "$path/" in
    "$root/"*) ;;
    *) fail "$label 越出受控根目录 $root：$path" ;;
  esac
}

prepare_safe_directory() {
  local root="$1" path="$2" label="$3" real_path
  assert_descendant_path "$root" "$path" "$label"
  assert_safe_directory_path "$path" "$label"
  mkdir -p "$path"
  # mkdir 后必须重新逐级 lstat；这样预置的 live/dangling symlink 或非目录
  # 祖先都不能被后续 Cargo、cp、lipo 或重定向跟随到受控根之外。
  assert_safe_directory_path "$path" "$label"
  [[ -d "$path" && ! -L "$path" ]] || fail "$label 不是普通目录：$path"
  real_path="$(cd "$path" && pwd -P)"
  case "$real_path/" in
    "$root/"*) ;;
    *) fail "$label 的真实路径越出受控根目录 $root：$real_path" ;;
  esac
  [[ "$real_path" == "$path" ]] || fail "$label 的真实路径发生漂移：$path -> $real_path"
}

prepare_safe_output_file() {
  local root="$1" path="$2" label="$3" parent
  assert_descendant_path "$root" "$path" "$label"
  [[ "${path##*/}" != . && "${path##*/}" != .. ]] \
    || fail "$label 文件名无效：$path"
  assert_new_file "$path"
  parent="$(dirname "$path")"
  prepare_safe_directory "$root" "$parent" "$label 父目录"
  # 父目录创建后再 lstat 最终项，特别拒绝 `-e` 看不到的 dangling symlink。
  assert_new_file "$path"
}

cargo_target_dir="$work_dir/cargo"
prepare_safe_directory "$work_dir" "$cargo_target_dir" "Cargo target 目录"
export CARGO_TARGET_DIR="$cargo_target_dir"

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

product_header_symbols() {
  perl -0777 -ne 'while (/\b(citizensdk_[a-z0-9_]+)\s*\(/g) { print "$1\n" }' \
    "$product_header" | sort -u
}

product_library_symbols() {
  local library="$1" nm_bin="$2" prefix="$3"
  local raw_symbols
  if [[ -n "$prefix" ]]; then
    raw_symbols="$("$nm_bin" -g --defined-only "$library" 2>/dev/null)" \
      || fail "无法读取 CitizenSDK 产品 ABI 的 Mach-O 外部已定义符号"
  else
    raw_symbols="$("$nm_bin" -D -g --defined-only "$library" 2>/dev/null)" \
      || fail "无法读取 CitizenSDK 产品 ABI 的 ELF 动态导出符号"
  fi
  # 必须先取得完整外部已定义/动态导出集合，再统一去掉 Mach-O 的单个前导
  # 下划线。禁止先按已知前缀 grep，否则 foreign_probe 等额外全局符号会消失。
  printf '%s\n' "$raw_symbols" \
    | awk 'NF > 0 && $NF !~ /:$/ { print $NF }' \
    | sed "s/^${prefix}//" \
    | LC_ALL=C sort -u
}

verify_product_abi_symbols() {
  local library="$1" nm_bin="$2" prefix="$3" label="$4"
  local actual expected forbidden
  actual="$(product_library_symbols "$library" "$nm_bin" "$prefix")"
  expected="$(product_header_symbols)"
  forbidden="$(printf '%s\n' "$actual" \
    | grep -E '^(smoldot_|citizen_sr25519_|account_crypto_)' || true)"
  [[ -z "$forbidden" ]] \
    || fail "$label 泄露低层或密码学符号：$(printf '%s' "$forbidden" | tr '\n' ' ')"
  [[ "$actual" == "$expected" ]] || {
    local missing extra
    missing="$(comm -23 <(printf '%s\n' "$expected") <(printf '%s\n' "$actual"))"
    extra="$(comm -13 <(printf '%s\n' "$expected") <(printf '%s\n' "$actual"))"
    fail "$label 与 include/citizensdk.h 不一致；缺失=${missing:-无}；额外=${extra:-无}"
  }
}

jni_library_symbols() {
  local library="$1" nm_bin="$2"
  "$nm_bin" -D -g --defined-only "$library" 2>/dev/null \
    | awk 'NF > 0 && $NF !~ /:$/ { print $NF }' \
    | LC_ALL=C sort -u
}

verify_jni_symbols() {
  local library="$1" nm_bin="$2" symbols
  symbols="$(jni_library_symbols "$library" "$nm_bin")" \
    || fail "无法读取 CitizenSDK Android JNI 动态导出"
  [[ "$symbols" == 'JNI_OnLoad@@CITIZENSDK_JNI_1.0' ]] \
    || fail "Android JNI 全局导出必须精确为版本化 JNI_OnLoad；实际=${symbols:-无}"
}

android_elf_dynamic_values() {
  local library="$1" readelf_bin="$2" tag="$3"
  "$readelf_bin" -d "$library" 2>/dev/null \
    | sed -n "s/.*(${tag}).*\[\([^]]*\)\].*/\1/p"
}

verify_android_elf_identity() {
  local core_library="$1" jni_library="$2" readelf_bin="$3"
  local core_soname jni_soname core_needed jni_needed core_dependency_count
  [[ -x "$readelf_bin" ]] || fail "Android NDK llvm-readelf 不可执行：$readelf_bin"
  core_soname="$(android_elf_dynamic_values "$core_library" "$readelf_bin" SONAME)"
  jni_soname="$(android_elf_dynamic_values "$jni_library" "$readelf_bin" SONAME)"
  core_needed="$(android_elf_dynamic_values "$core_library" "$readelf_bin" NEEDED)"
  jni_needed="$(android_elf_dynamic_values "$jni_library" "$readelf_bin" NEEDED)"
  [[ "$core_soname" == libcitizensdk.so ]] \
    || fail "Android Core SONAME 必须精确为 libcitizensdk.so；实际=${core_soname:-无}"
  [[ "$jni_soname" == libcitizensdk_jni.so ]] \
    || fail "Android JNI SONAME 必须精确为 libcitizensdk_jni.so；实际=${jni_soname:-无}"
  if printf '%s\n%s\n' "$core_needed" "$jni_needed" | grep -q '/'; then
    fail "Android ELF DT_NEEDED 禁止包含构建机路径"
  fi
  core_dependency_count="$(printf '%s\n' "$jni_needed" \
    | grep -Fxc libcitizensdk.so || true)"
  [[ "$core_dependency_count" == 1 ]] \
    || fail "Android JNI 必须精确依赖一次 libcitizensdk.so；实际=${core_dependency_count}"
}

resolve_gradle() {
  local executable="${CITIZENSDK_GRADLE:-}"
  if [[ -z "$executable" ]]; then
    executable="$(command -v gradle || true)"
  fi
  [[ -n "$executable" ]] \
    || fail "缺少 Gradle；请用 CITIZENSDK_GRADLE 指向受控 gradle/gradlew 绝对路径"
  [[ "$executable" == /* ]] || fail "CITIZENSDK_GRADLE 必须解析为绝对路径"
  [[ -f "$executable" && ! -L "$executable" && -x "$executable" ]] \
    || fail "Gradle 必须是可执行普通文件且不能是符号链接：$executable"
  printf '%s\n' "$executable"
}

verify_android_aar() {
  local aar="$1" core_library="$2" jni_library="$3" nm_bin="$4"
  local entries native_entries expected_native verify_dir aar_core aar_jni classes
  local class_entries classes_payload
  command -v unzip >/dev/null 2>&1 || fail "Android AAR 核验需要 unzip"
  [[ -f "$aar" && -f "$core_library" && -f "$jni_library" ]] \
    || fail "Android AAR 或双原生库不完整"
  entries="$(unzip -Z1 "$aar")" || fail "无法读取 Android AAR 文件闭集"
  native_entries="$(printf '%s\n' "$entries" \
    | grep -E '^jni/' \
    | grep -v '/$' \
    | LC_ALL=C sort || true)"
  expected_native=$'jni/arm64-v8a/libcitizensdk.so\njni/arm64-v8a/libcitizensdk_jni.so'
  [[ "$native_entries" == "$expected_native" ]] \
    || fail "Android AAR 原生库必须精确为 arm64-v8a 双库；实际=${native_entries:-无}"
  printf '%s\n' "$entries" | grep -Fxq AndroidManifest.xml \
    || fail "Android AAR 缺少 AndroidManifest.xml"
  printf '%s\n' "$entries" | grep -Fxq classes.jar \
    || fail "Android AAR 缺少 classes.jar"
  for asset in \
    assets/citizenchain/chainspec.json \
    assets/citizenchain/light_sync_state.json \
    assets/citizenchain/manifest.json; do
    printf '%s\n' "$entries" | grep -Fxq "$asset" \
      || fail "Android AAR 缺少已验证链资产：$asset"
    cmp -s <(unzip -p "$aar" "$asset") "$sdk_dir/$asset" \
      || fail "Android AAR 链资产与源码信任锚字节不一致：$asset"
  done
  if printf '%s\n' "$entries" | grep -Eq '(^|/)(libsmoldot|libc\+\+_shared)\.so$|\.aar$'; then
    fail "Android AAR 混入 legacy/C++ 共享运行库或嵌套 AAR"
  fi

  verify_dir="$(mktemp -d "$work_dir/android-aar-verify.XXXXXX")" \
    || fail "无法创建 Android AAR 核验目录"
  assert_safe_directory_path "$verify_dir" "Android AAR 核验目录"
  aar_core="$verify_dir/libcitizensdk.so"
  aar_jni="$verify_dir/libcitizensdk_jni.so"
  classes="$verify_dir/classes.jar"
  classes_payload="$verify_dir/classes.payload"
  unzip -p "$aar" jni/arm64-v8a/libcitizensdk.so >"$aar_core" \
    || fail "无法提取 AAR Core 库"
  unzip -p "$aar" jni/arm64-v8a/libcitizensdk_jni.so >"$aar_jni" \
    || fail "无法提取 AAR JNI 库"
  unzip -p "$aar" classes.jar >"$classes" || fail "无法提取 AAR classes.jar"
  cmp -s "$core_library" "$aar_core" || fail "AAR 与外部 libcitizensdk.so 字节不一致"
  cmp -s "$jni_library" "$aar_jni" || fail "AAR 与外部 libcitizensdk_jni.so 字节不一致"
  verify_jni_symbols "$jni_library" "$nm_bin"
  verify_android_elf_identity \
    "$core_library" "$jni_library" "${nm_bin%/*}/llvm-readelf"
  class_entries="$(unzip -Z1 "$classes")" || fail "无法读取 AAR classes.jar 闭集"
  if printf '%s\n' "$class_entries" | grep -Eq '^io/flutter/'; then
    fail "原生 AAR classes.jar 混入 Flutter 类"
  fi
  for required_class in \
    org/citizen/sdk/CitizenSdk.class \
    org/citizen/sdk/CitizenSdkOperation.class \
    org/citizen/sdk/internal/CitizenSdkNative.class \
    org/citizen/sdk/internal/CitizenSdkHardwareVault.class; do
    printf '%s\n' "$class_entries" | grep -Fxq "$required_class" \
      || fail "原生 AAR classes.jar 缺少必需实现：$required_class"
  done
  unzip -p "$classes" >"$classes_payload" || fail "无法读取 AAR classes.jar 内容"
  if LC_ALL=C grep -a -q 'io/flutter/' "$classes_payload"; then
    fail "原生 AAR classes.jar 引用了 Flutter API"
  fi
}

android_toolchain() {
  local ndk_home="${ANDROID_NDK_HOME:-}" sdk_home host_tag expected_ndk
  if [[ -n "${ANDROID_HOME:-}" && -n "${ANDROID_SDK_ROOT:-}" \
    && "$ANDROID_HOME" != "$ANDROID_SDK_ROOT" ]]; then
    fail "ANDROID_HOME 与 ANDROID_SDK_ROOT 指向不同目录"
  fi
  sdk_home="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
  if [[ -z "$ndk_home" ]]; then
    if [[ -z "$sdk_home" ]]; then
      [[ -n "${HOME:-}" ]] || fail "缺少 Android SDK 环境与 HOME"
      case "$(uname -s)" in
        Darwin) sdk_home="$HOME/Library/Android/sdk" ;;
        Linux) sdk_home="$HOME/Android/Sdk" ;;
        *) fail "当前宿主没有登记 Android SDK 标准目录：$(uname -s)" ;;
      esac
    fi
    assert_safe_directory_path "$sdk_home" "Android SDK"
    [[ -d "$sdk_home" ]] || fail "Android SDK 不存在：$sdk_home"
    sdk_home="$(cd "$sdk_home" && pwd -P)"
    ndk_home="$sdk_home/ndk/$android_ndk_version"
  else
    assert_safe_directory_path "$ndk_home" "ANDROID_NDK_HOME"
    [[ -d "$ndk_home" ]] || fail "Android NDK 不存在：$ndk_home"
    ndk_home="$(cd "$ndk_home" && pwd -P)"
    [[ "${ndk_home##*/}" == "$android_ndk_version" ]] \
      || fail "ANDROID_NDK_HOME 必须使用统一版本 $android_ndk_version"
    if [[ -n "$sdk_home" ]]; then
      assert_safe_directory_path "$sdk_home" "Android SDK"
      [[ -d "$sdk_home" ]] || fail "Android SDK 不存在：$sdk_home"
      sdk_home="$(cd "$sdk_home" && pwd -P)"
      expected_ndk="$sdk_home/ndk/$android_ndk_version"
      [[ "$ndk_home" == "$expected_ndk" ]] \
        || fail "ANDROID_NDK_HOME 不属于统一 Android SDK 与 NDK 版本"
    fi
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
  local toolchain gradle_bin android_build_dir gradle_project_cache gradle_user_home
  local kotlin_persistent_dir
  local core_stage core_destination jni_destination aar_destination source_library
  local built_aar aar_jni nm_bin strip_bin
  toolchain="$(android_toolchain)"
  gradle_bin="$(resolve_gradle)"
  android_build_dir="$work_dir/gradle-native"
  gradle_project_cache="$work_dir/gradle-project-cache"
  gradle_user_home="$work_dir/gradle-home"
  kotlin_persistent_dir="$work_dir/kotlin-project-persistent"
  core_stage="$work_dir/android-core/arm64-v8a"
  core_destination="$output_dir/android/arm64-v8a/libcitizensdk.so"
  jni_destination="$output_dir/android/arm64-v8a/libcitizensdk_jni.so"
  aar_destination="$output_dir/android/citizensdk.aar"
  for directory in \
    "$android_build_dir" "$gradle_project_cache" "$gradle_user_home" \
    "$kotlin_persistent_dir" "$core_stage"; do
    prepare_safe_directory "$work_dir" "$directory" "Android 外部构建目录"
  done
  export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="$toolchain/bin/aarch64-linux-android24-clang"
  export CC_aarch64_linux_android="$toolchain/bin/aarch64-linux-android24-clang"
  export AR_aarch64_linux_android="$toolchain/bin/llvm-ar"
  CARGO_TARGET_AARCH64_LINUX_ANDROID_RUSTFLAGS='-C link-arg=-Wl,-soname,libcitizensdk.so' \
    cargo build --manifest-path "$product_ffi_manifest" --release --locked \
      --target aarch64-linux-android
  source_library="$CARGO_TARGET_DIR/aarch64-linux-android/release/libcitizensdk.so"
  [[ -f "$source_library" ]] || fail "Android CitizenSDK Core 库未生成"
  prepare_safe_output_file "$work_dir" "$core_stage/libcitizensdk.so" \
    "Android Gradle Core staging"
  cp "$source_library" "$core_stage/libcitizensdk.so"
  nm_bin="$toolchain/bin/llvm-nm"
  strip_bin="$toolchain/bin/llvm-strip"
  [[ -x "$strip_bin" ]] || fail "Android NDK llvm-strip 不可执行：$strip_bin"
  # AGP 会对 Release AAR 中的 JNI 库执行 --strip-unneeded。先在受控 staging
  # 对 Core 做同一次确定性处理，再把这一个字节版本同时投影到独立双库和 AAR；
  # 否则外部 SO 与 AAR 会在打包后悄然变成两个不同产物。
  "$strip_bin" --strip-unneeded "$core_stage/libcitizensdk.so"
  verify_product_abi_symbols "$core_stage/libcitizensdk.so" "$nm_bin" "" \
    "Android libcitizensdk.so"
  prepare_safe_output_file "$output_dir" "$core_destination" "Android CitizenSDK Core 库"
  cp "$core_stage/libcitizensdk.so" "$core_destination"

  CITIZENSDK_ANDROID_BUILD_DIR="$android_build_dir" \
  CITIZENSDK_ANDROID_CORE_DIR="$core_stage" \
  GRADLE_USER_HOME="$gradle_user_home" \
    "$gradle_bin" --no-daemon --stacktrace \
      --project-cache-dir "$gradle_project_cache" \
      -Pkotlin.project.persistent.dir="$kotlin_persistent_dir" \
      -p "$android_gradle_project" :native:assembleRelease
  built_aar="$android_build_dir/native/outputs/aar/native-release.aar"
  [[ -f "$built_aar" ]] || fail "Android CitizenSDK AAR 未生成：$built_aar"

  prepare_safe_output_file "$output_dir" "$jni_destination" "Android CitizenSDK JNI 库"
  unzip -p "$built_aar" jni/arm64-v8a/libcitizensdk_jni.so >"$jni_destination" \
    || fail "无法从 AAR 提取 libcitizensdk_jni.so"
  prepare_safe_output_file "$output_dir" "$aar_destination" "Android CitizenSDK AAR"
  cp "$built_aar" "$aar_destination"
  verify_android_aar \
    "$aar_destination" "$core_destination" "$jni_destination" "$nm_bin"
  echo "CitizenSDK Android Core/JNI/AAR 完成：$aar_destination"
}

apple_product_symbols() {
  local library="$1" nm_bin="$2"
  "$nm_bin" -gU "$library" 2>/dev/null \
    | awk 'NF > 0 && $NF !~ /:$/ { print $NF }' \
    | sed 's/^_//' \
    | LC_ALL=C sort -u
}

verify_apple_product_abi_symbols() {
  local library="$1" nm_bin="$2" label="$3"
  local all_symbols actual expected forbidden foreign swift_symbols expected_count
  all_symbols="$(apple_product_symbols "$library" "$nm_bin")" \
    || fail "无法读取 $label 的 Mach-O 外部已定义符号"
  actual="$(printf '%s\n' "$all_symbols" | grep '^citizensdk_' || true)"
  expected="$(product_header_symbols)"
  expected_count="$(printf '%s\n' "$expected" | grep -c '^citizensdk_' || true)"
  [[ "$expected_count" == 70 ]] \
    || fail "include/citizensdk.h 必须精确声明 70 个 citizensdk_* 函数"
  forbidden="$(printf '%s\n' "$all_symbols" \
    | grep -E '^(smoldot_|citizen_sr25519_|account_crypto_)' || true)"
  [[ -z "$forbidden" ]] \
    || fail "$label 泄露 legacy 低层符号：$(printf '%s' "$forbidden" | tr '\n' ' ')"
  [[ "$actual" == "$expected" ]] || {
    local missing extra
    missing="$(comm -23 <(printf '%s\n' "$expected") <(printf '%s\n' "$actual"))"
    extra="$(comm -13 <(printf '%s\n' "$expected") <(printf '%s\n' "$actual"))"
    fail "$label 的 citizensdk_* 与 70 函数产品头不一致；缺失=${missing:-无}；额外=${extra:-无}"
  }
  # 动态 framework 同时提供 Swift API 和 C ABI。Swift public/ABI-support 符号
  # 只能属于本模块 mangling；除这组 Swift 符号外，全部外部已定义符号必须正好
  # 是产品头中的 70 个 C ABI，Rust staticlib 及其依赖不得穿透边界。
  swift_symbols="$(printf '%s\n' "$all_symbols" | grep '^\$s10CitizenSDK' || true)"
  [[ -n "$swift_symbols" ]] || fail "$label 未导出 CitizenSDK Swift 模块符号"
  foreign="$(printf '%s\n' "$all_symbols" \
    | grep -Ev '^(citizensdk_|\$s10CitizenSDK)' || true)"
  [[ -z "$foreign" ]] \
    || fail "$label 泄露非 CitizenSDK 产品符号：$(printf '%s' "$foreign" | tr '\n' ' ')"
}

write_apple_exported_symbols() {
  local probe="$1" nm_bin="$2" destination="$3" label="$4"
  local all_symbols actual expected swift_symbols
  all_symbols="$(apple_product_symbols "$probe" "$nm_bin")" \
    || fail "无法读取 $label 的未过滤 Mach-O 符号"
  actual="$(printf '%s\n' "$all_symbols" | grep '^citizensdk_' || true)"
  expected="$(product_header_symbols)"
  [[ "$actual" == "$expected" ]] \
    || fail "$label 未过滤链接未完整包含 70 个 citizensdk_* 产品符号"
  swift_symbols="$(printf '%s\n' "$all_symbols" | grep '^\$s10CitizenSDK' || true)"
  [[ -n "$swift_symbols" ]] || fail "$label 未过滤链接没有 CitizenSDK Swift 导出"
  prepare_safe_output_file "$work_dir" "$destination" "$label 导出允许集"
  {
    printf '%s\n' "$expected"
    printf '%s\n' "$swift_symbols"
  } | sed 's/^/_/' | LC_ALL=C sort -u >"$destination"
  [[ "$(grep -c '^_citizensdk_' "$destination" || true)" == 70 ]] \
    || fail "$label 导出允许集没有精确 70 个 C ABI"
}

write_framework_plist() {
  local path="$1" supported_platform="$2" platform_name="$3"
  local minimum_key="$4" minimum_version="$5" software_version="$6"
  /usr/bin/plutil -create xml1 "$path"
  /usr/libexec/PlistBuddy \
    -c "Add :CFBundleDevelopmentRegion string en" \
    -c "Add :CFBundleExecutable string CitizenSDK" \
    -c "Add :CFBundleIdentifier string org.citizen.sdk" \
    -c "Add :CFBundleInfoDictionaryVersion string 6.0" \
    -c "Add :CFBundleName string CitizenSDK" \
    -c "Add :CFBundlePackageType string FMWK" \
    -c "Add :CFBundleShortVersionString string $software_version" \
    -c "Add :CFBundleVersion string $software_version" \
    -c "Add :CFBundleSupportedPlatforms array" \
    -c "Add :CFBundleSupportedPlatforms:0 string $supported_platform" \
    -c "Add :DTPlatformName string $platform_name" \
    -c "Add :$minimum_key string $minimum_version" \
    "$path" >/dev/null
}

write_framework_module_map() {
  local path="$1"
  printf '%s\n' \
    'framework module CitizenSDK {' \
    '  umbrella header "citizensdk.h"' \
    '  export *' \
    '  module * { export * }' \
    '}' >"$path"
}

resolve_flutter_sdk_root() {
  local flutter_bin flutter_root
  flutter_bin="$(command -v flutter || true)"
  [[ -n "$flutter_bin" && "$flutter_bin" == /* && -f "$flutter_bin" \
    && ! -L "$flutter_bin" && -x "$flutter_bin" ]] \
    || fail "Apple Flutter adapter 编译需要绝对路径的普通 Flutter 可执行文件"
  flutter_root="$(cd "$(dirname "$flutter_bin")/.." && pwd -P)"
  [[ -d "$flutter_root/bin/cache/artifacts/engine" ]] \
    || fail "Flutter SDK 缺少已缓存 Apple engine artifacts：$flutter_root"
  printf '%s\n' "$flutter_root"
}

resolve_flutter_macos_xcframework() {
  local flutter_root="$1" candidate
  local -a candidates=()
  while IFS= read -r candidate; do
    candidates+=("$candidate")
  done < <(find "$flutter_root/bin/cache/artifacts/engine" \
    -mindepth 2 -maxdepth 2 -type d -name FlutterMacOS.xcframework \
    -path '*/darwin-*-release/FlutterMacOS.xcframework' -print | LC_ALL=C sort)
  [[ "${#candidates[@]}" == 1 ]] \
    || fail "Flutter SDK 必须精确提供一个 macOS Release XCFramework；实际=${#candidates[@]}"
  printf '%s\n' "${candidates[0]}"
}

resolve_xcframework_framework_slice() {
  local xcframework="$1" module="$2" platform="$3" expected_variant="$4"
  local index=0 identifier library_path actual_platform actual_variant architectures
  local framework found='' count=0
  [[ -d "$xcframework" && ! -L "$xcframework" \
    && -f "$xcframework/Info.plist" && ! -L "$xcframework/Info.plist" ]] \
    || fail "$module XCFramework 缺失或不是普通目录"
  while identifier="$(/usr/libexec/PlistBuddy \
    -c "Print :AvailableLibraries:$index:LibraryIdentifier" \
    "$xcframework/Info.plist" 2>/dev/null)"; do
    actual_platform="$(/usr/libexec/PlistBuddy \
      -c "Print :AvailableLibraries:$index:SupportedPlatform" \
      "$xcframework/Info.plist")"
    actual_variant="$(/usr/libexec/PlistBuddy \
      -c "Print :AvailableLibraries:$index:SupportedPlatformVariant" \
      "$xcframework/Info.plist" 2>/dev/null || true)"
    if [[ "$actual_platform" == "$platform" && "$actual_variant" == "$expected_variant" ]]; then
      architectures="$(/usr/libexec/PlistBuddy \
        -c "Print :AvailableLibraries:$index:SupportedArchitectures" \
        "$xcframework/Info.plist")"
      printf '%s\n' "$architectures" | grep -Eq '(^|[[:space:]])arm64([[:space:]]|$)' \
        || fail "$module 的 $platform/${expected_variant:-device} slice 不支持 arm64"
      library_path="$(/usr/libexec/PlistBuddy \
        -c "Print :AvailableLibraries:$index:LibraryPath" \
        "$xcframework/Info.plist")"
      framework="$xcframework/$identifier/$library_path"
      [[ -d "$framework" && "$(basename "$framework")" == "$module.framework" ]] \
        || fail "$module 的 $platform/${expected_variant:-device} framework 路径无效"
      found="$framework"
      count=$((count + 1))
    fi
    index=$((index + 1))
  done
  [[ "$count" == 1 ]] \
    || fail "$module 必须精确提供一个 $platform/${expected_variant:-device} arm64 slice；实际=$count"
  printf '%s\n' "$found"
}

compile_apple_flutter_adapter() {
  local apple_sdk="$1" swift_target="$2" slice_name="$3" platform="$4"
  local variant="$5" flutter_module="$6" flutter_xcframework="$7"
  local citizen_slice_root="$8" flutter_framework flutter_framework_root
  local sdk_path swiftc compile_root module_cache source object_count
  local -a swift_sources swift_arguments

  [[ -d "$citizen_slice_root/CitizenSDK.framework" \
    && ! -L "$citizen_slice_root/CitizenSDK.framework" ]] \
    || fail "$slice_name Flutter adapter 必须从最终 XCFramework slice 导入 CitizenSDK"
  [[ -d "$darwin_flutter_source_root" && ! -L "$darwin_flutter_source_root" ]] \
    || fail "CitizenSDKFlutter 生产源码目录缺失"
  swift_sources=()
  while IFS= read -r source; do
    swift_sources+=("$source")
  done < <(find "$darwin_flutter_source_root" -maxdepth 1 -type f \
    -name '*.swift' -print | LC_ALL=C sort)
  [[ "${#swift_sources[@]}" -gt 0 ]] || fail "CitizenSDKFlutter 生产源码为空"

  flutter_framework="$(resolve_xcframework_framework_slice \
    "$flutter_xcframework" "$flutter_module" "$platform" "$variant")"
  flutter_framework_root="$(dirname "$flutter_framework")"
  sdk_path="$(xcrun --sdk "$apple_sdk" --show-sdk-path)"
  swiftc="$(xcrun --sdk "$apple_sdk" --find swiftc)"
  [[ -d "$sdk_path" && -x "$swiftc" ]] \
    || fail "$slice_name Flutter adapter 缺少受控 Apple SDK 或 swiftc"

  compile_root="$work_dir/apple-flutter-compile/$slice_name"
  module_cache="$compile_root/module-cache"
  [[ ! -e "$compile_root" && ! -L "$compile_root" ]] \
    || fail "$slice_name Flutter adapter 编译目录必须全新"
  prepare_safe_directory "$work_dir" "$compile_root" \
    "$slice_name Flutter adapter 编译目录"
  prepare_safe_directory "$work_dir" "$module_cache" \
    "$slice_name Flutter adapter module cache"
  swift_arguments=("${swift_sources[@]}"
    -parse-as-library
    -swift-version 5
    -warnings-as-errors
    -strict-concurrency=complete
    -module-name CitizenSDKFlutter
    -module-cache-path "$module_cache"
    -sdk "$sdk_path"
    -target "$swift_target"
    -F "$citizen_slice_root"
    -F "$flutter_framework_root")

  # 第一遍是严格类型检查；第二遍真实生成每个 Swift 源文件的目标文件。
  # 两遍都从最终 XCFramework slice 导入 @_spi(CitizenSDKFlutter)，不能从
  # 同次 Swift 源码或构建前 framework 旁路产品边界。
  "$swiftc" "${swift_arguments[@]}" -typecheck
  (
    cd "$compile_root"
    "$swiftc" "${swift_arguments[@]}" -c
  )
  object_count="$(find "$compile_root" -mindepth 1 -maxdepth 1 \
    -type f -name '*.o' -print | wc -l | tr -d '[:space:]')"
  [[ "$object_count" == "${#swift_sources[@]}" ]] \
    || fail "$slice_name Flutter adapter 编译目标闭集漂移：$object_count/${#swift_sources[@]}"
}

write_apple_test_package() {
  local harness="$1" static_library="$2" flutter_module="$3"
  local source destination
  for directory in \
    "$harness/Sources/CitizenSDK" \
    "$harness/Sources/CitizenSDKC/include" \
    "$harness/Sources/CitizenSDKFlutter" \
    "$harness/Tests/CitizenSDKTests" \
    "$harness/Tests/CitizenSDKFlutterTests" \
    "$harness/Libraries"; do
    prepare_safe_directory "$work_dir" "$directory" "Apple XCTest 临时 harness"
  done
  cp "$product_header" "$harness/Sources/CitizenSDKC/include/citizensdk.h"
  cp "$product_types_header" "$harness/Sources/CitizenSDKC/include/citizensdk_types.h"
  cp "$static_library" "$harness/Libraries/libcitizensdk.a"
  printf '%s\n' \
    '#include "citizensdk.h"' \
    'int citizensdk_test_harness_anchor(void) { return 0; }' \
    >"$harness/Sources/CitizenSDKC/harness.c"
  while IFS= read -r source; do
    destination="$harness/Sources/CitizenSDK/$(basename "$source")"
    {
      printf '%s\n' 'import CitizenSDKC'
      cat "$source"
    } >"$destination"
  done < <(find "$darwin_source_root" -maxdepth 1 -type f -name '*.swift' \
    -print | LC_ALL=C sort)
  printf '%s\n' '@_exported import CitizenSDKC' \
    >"$harness/Sources/CitizenSDK/CitizenSDKCExports.swift"
  cp "$darwin_flutter_source_root"/*.swift "$harness/Sources/CitizenSDKFlutter/"
  cp "$sdk_dir/darwin/Tests/CitizenSDKTests"/*.swift \
    "$harness/Tests/CitizenSDKTests/"
  cp "$sdk_dir/darwin/Tests/CitizenSDKFlutterTests"/*.swift \
    "$harness/Tests/CitizenSDKFlutterTests/"

  cat >"$harness/Package.swift" <<PACKAGE
// swift-tools-version: 5.9
import PackageDescription

let strict: [SwiftSetting] = [
    .unsafeFlags(["-warnings-as-errors", "-strict-concurrency=complete"]),
]

// Release-mode cross compilation does not make package modules testable by
// default. The harness needs internal access for the canonical @testable XCTest
// suites, so only its two generated implementation targets receive this flag.
let testable: [SwiftSetting] = [
    .unsafeFlags(["-warnings-as-errors", "-strict-concurrency=complete", "-enable-testing"]),
]

let package = Package(
    name: "CitizenSDKAppleTests",
    platforms: [.iOS(.v16), .macOS(.v13)],
    targets: [
        .binaryTarget(name: "$flutter_module", path: "Artifacts/$flutter_module.xcframework"),
        .target(
            name: "CitizenSDKC",
            path: "Sources/CitizenSDKC",
            publicHeadersPath: "include"
        ),
        .target(
            name: "CitizenSDK",
            dependencies: ["CitizenSDKC"],
            path: "Sources/CitizenSDK",
            swiftSettings: testable,
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-force_load", "-Xlinker", "$harness/Libraries/libcitizensdk.a"]),
                .linkedFramework("Security"),
                .linkedFramework("LocalAuthentication"),
                .linkedLibrary("sqlite3"),
            ]
        ),
        .target(
            name: "CitizenSDKFlutter",
            dependencies: ["CitizenSDK", "$flutter_module"],
            path: "Sources/CitizenSDKFlutter",
            swiftSettings: testable
        ),
        .testTarget(
            name: "CitizenSDKTests",
            dependencies: ["CitizenSDK"],
            path: "Tests/CitizenSDKTests",
            swiftSettings: strict
        ),
        .testTarget(
            name: "CitizenSDKFlutterTests",
            dependencies: ["CitizenSDK", "CitizenSDKFlutter"],
            path: "Tests/CitizenSDKFlutterTests",
            swiftSettings: strict
        ),
    ],
    swiftLanguageVersions: [.v5]
)
PACKAGE
}

run_apple_test_harness() {
  local rust_target="$1" apple_sdk="$2" swift_target="$3" slice_name="$4"
  local flutter_module="$5" flutter_xcframework="$6" mode="$7"
  local static_library harness scratch artifact sdk_path runtime_framework_root=''
  local flutter_test_bundle framework_destination test_product_root test_bundle_names
  local -a swiftpm_paths swiftpm_target
  static_library="$CARGO_TARGET_DIR/$rust_target/release/libcitizensdk.a"
  [[ -f "$static_library" && ! -L "$static_library" ]] \
    || fail "$slice_name XCTest 缺少已构建 native/ffi 静态 Core"
  harness="$work_dir/apple-test-harness/$slice_name"
  scratch="$work_dir/apple-test-scratch/$slice_name"
  [[ ! -e "$harness" && ! -L "$harness" && ! -e "$scratch" && ! -L "$scratch" ]] \
    || fail "$slice_name XCTest harness/scratch 必须全新"
  prepare_safe_directory "$work_dir" "$harness" "$slice_name XCTest harness"
  prepare_safe_directory "$work_dir" "$scratch" "$slice_name XCTest scratch"
  write_apple_test_package "$harness" "$static_library" "$flutter_module"
  prepare_safe_directory "$work_dir" "$harness/Artifacts" "$slice_name XCTest artifacts"
  artifact="$harness/Artifacts/$flutter_module.xcframework"
  [[ ! -e "$artifact" && ! -L "$artifact" ]] \
    || fail "$slice_name Flutter 测试 artifact 目标必须全新"
  cp -R "$flutter_xcframework" "$artifact"
  sdk_path="$(xcrun --sdk "$apple_sdk" --show-sdk-path)"
  swiftpm_paths=(
    --package-path "$harness"
    --cache-path "$scratch/cache"
    --config-path "$scratch/config"
    --security-path "$scratch/security"
    --scratch-path "$scratch/build"
    --manifest-cache local
    --disable-dependency-cache
    --configuration release
    --triple "$swift_target"
    --sdk "$sdk_path"
  )
  prepare_safe_directory "$work_dir" "$scratch/tmp" "$slice_name XCTest TMPDIR"
  prepare_safe_directory "$work_dir" "$scratch/home" "$slice_name XCTest HOME"
  case "$mode" in
    run|compile) swiftpm_target=(build --build-tests) ;;
    *) fail "Apple XCTest mode 未登记：$mode" ;;
  esac
  if [[ "$mode" == run ]]; then
    runtime_framework_root="$(dirname "$(resolve_xcframework_framework_slice \
      "$artifact" "$flutter_module" macos '')")"
  fi
  TMPDIR="$scratch/tmp" HOME="$scratch/home" \
  CLANG_MODULE_CACHE_PATH="$scratch/clang-module-cache" \
  SWIFTPM_MODULECACHE_OVERRIDE="$scratch/swift-module-cache" \
    swift "${swiftpm_target[@]}" "${swiftpm_paths[@]}"
  if [[ "$mode" == run ]]; then
    # SwiftPM does not embed a binary-target framework in a macOS XCTest
    # bundle. Embed the exact resolved Flutter framework after build, then run
    # with --skip-build so dyld resolves only the bundle-owned copy.
    test_product_root="$scratch/build/out/Products/Release"
    test_bundle_names="$(find "$test_product_root" -mindepth 1 -maxdepth 1 \
      -type d -name '*.xctest' -exec basename {} \; | LC_ALL=C sort)"
    [[ "$test_bundle_names" == $'CitizenSDKFlutterTests.xctest\nCitizenSDKTests.xctest' ]] \
      || fail "macOS XCTest 产品闭集漂移：${test_bundle_names:-无}"
    flutter_test_bundle="$test_product_root/CitizenSDKFlutterTests.xctest"
    framework_destination="$flutter_test_bundle/Contents/Frameworks/$flutter_module.framework"
    prepare_safe_directory "$work_dir" "$(dirname "$framework_destination")" \
      "macOS Flutter XCTest framework 目录"
    [[ ! -e "$framework_destination" && ! -L "$framework_destination" ]] \
      || fail "macOS Flutter XCTest framework 目标必须全新"
    cp -R "$runtime_framework_root/$flutter_module.framework" "$framework_destination"
    TMPDIR="$scratch/tmp" HOME="$scratch/home" \
    CLANG_MODULE_CACHE_PATH="$scratch/clang-module-cache" \
    SWIFTPM_MODULECACHE_OVERRIDE="$scratch/swift-module-cache" \
      swift test --skip-build "${swiftpm_paths[@]}"
  fi
}

run_final_apple_consumer_smoke() {
  local xcframework="$output_dir/apple/CitizenSDK.xcframework"
  local framework framework_root
  local smoke_root="$work_dir/apple-consumer-smoke"
  local source="$smoke_root/CitizenSDKConsumerSmoke.swift"
  local executable="$smoke_root/CitizenSDKConsumerSmoke"
  local sdk_path swiftc architectures linked citizen_links
  local expected_install_name='@rpath/CitizenSDK.framework/Versions/A/CitizenSDK'
  framework="$(resolve_xcframework_framework_slice \
    "$xcframework" CitizenSDK macos '')"
  framework_root="$(dirname "$framework")"
  [[ -d "$framework" && ! -L "$framework" ]] \
    || fail "最终 XCFramework macOS slice 缺失，拒绝消费者 smoke"
  [[ ! -e "$smoke_root" && ! -L "$smoke_root" ]] \
    || fail "最终 XCFramework 消费者 smoke 目录必须全新"
  prepare_safe_directory "$work_dir" "$smoke_root" "Apple 消费者 smoke"
  for directory in \
    "$smoke_root/home-normal" "$smoke_root/home-supervisor" \
    "$smoke_root/tmp-normal" "$smoke_root/tmp-supervisor" \
    "$smoke_root/module-cache" "$smoke_root/logs"; do
    prepare_safe_directory "$work_dir" "$directory" "Apple 消费者 smoke 状态目录"
  done
  cat >"$source" <<'SWIFT'
import CitizenSDK
import Darwin
import Foundation

private enum SmokeFailure: Error, CustomStringConvertible {
    case failed(String)
    var description: String {
        switch self { case let .failed(message): return message }
    }
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else { throw SmokeFailure.failed(message) }
}

private func verifyCapabilities(_ sdk: CitizenSDK) throws {
    let capabilities = try sdk.capabilities()
    let actual = capabilities.statuses.map(\.name.rawValue).sorted()
    let expected = CitizenCapabilityName.allCases.map(\.rawValue).sorted()
    try require(capabilities.revision >= 1, "capability revision must be at least one")
    try require(capabilities.statuses.count == 10, "capability status count must be exactly ten")
    try require(actual == expected, "capability names must be the exact ten-value public enum")
}

private let publicSQLiteSuffix = "/citizensdk/v1/public/public-state-v1.sqlite3"
private let secureSQLiteSuffix = "/citizensdk/v1/secure/secure-state-v1.sqlite3"

private func citizenSDKSQLiteFileDescriptors() -> Set<String> {
    var paths = Set<String>()
    let descriptorLimit = max(0, Int(getdtablesize()))
    for descriptor in 0..<descriptorLimit {
        var bytes = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        if fcntl(Int32(descriptor), F_GETPATH, &bytes) == 0 {
            let path = String(cString: bytes)
            if path.hasSuffix(publicSQLiteSuffix) || path.hasSuffix(secureSQLiteSuffix) {
                paths.insert(path)
            }
        }
    }
    return paths
}

private func normalCloseSmoke() throws {
    let sdk = try CitizenSDK.open()
    try require(sdk.lifecycle == .created, "open must produce created lifecycle")
    try verifyCapabilities(sdk)
    try sdk.close()
    try require(sdk.lifecycle == .disposed, "close must commit disposed lifecycle")
    try sdk.close()
    try require(sdk.lifecycle == .disposed, "idempotent close must remain disposed")
}

private func supervisorSmoke() throws {
    var abandoned: CitizenSDK? = try CitizenSDK.open()
    try verifyCapabilities(abandoned!)
    let initiallyOpen = citizenSDKSQLiteFileDescriptors()
    try require(initiallyOpen.contains(where: { $0.hasSuffix(publicSQLiteSuffix) }),
                "public SQLite descriptor must be open before abandonment")
    try require(initiallyOpen.contains(where: { $0.hasSuffix(secureSQLiteSuffix) }),
                "secure SQLite descriptor must be open before abandonment")
    abandoned = nil

    let deadline = DispatchTime.now().uptimeNanoseconds + 15_000_000_000
    while !citizenSDKSQLiteFileDescriptors().isEmpty
            && DispatchTime.now().uptimeNanoseconds < deadline {
        Thread.sleep(forTimeInterval: 0.05)
    }
    try require(citizenSDKSQLiteFileDescriptors().isEmpty,
                "supervisor must close public and secure SQLite descriptors")

    let reopened = try CitizenSDK.open()
    try verifyCapabilities(reopened)
    try reopened.close()
    try require(reopened.lifecycle == .disposed,
                "reopen after supervised cleanup must close successfully")
}

@main
private enum CitizenSDKConsumerSmoke {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            throw SmokeFailure.failed("expected exactly one smoke mode")
        }
        switch CommandLine.arguments[1] {
        case "normal": try normalCloseSmoke()
        case "supervisor": try supervisorSmoke()
        default: throw SmokeFailure.failed("unknown smoke mode")
        }
    }
}
SWIFT
  sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
  swiftc="$(xcrun --sdk macosx --find swiftc)"
  prepare_safe_output_file "$work_dir" "$executable" "Apple 消费者 smoke 可执行文件"
  "$swiftc" "$source" \
    -parse-as-library \
    -swift-version 5 \
    -warnings-as-errors \
    -strict-concurrency=complete \
    -module-cache-path "$smoke_root/module-cache" \
    -sdk "$sdk_path" \
    -target arm64-apple-macosx13.0 \
    -F "$framework_root" \
    -framework CitizenSDK \
    -Xlinker -rpath \
    -Xlinker "$framework_root" \
    -o "$executable"
  architectures="$(xcrun lipo -archs "$executable")"
  [[ "$architectures" == arm64 ]] \
    || fail "Apple 消费者 smoke 必须精确编译为 arm64"
  linked="$(xcrun otool -L "$executable")"
  citizen_links="$(printf '%s\n' "$linked" \
    | awk '$1 ~ /CitizenSDK\.framework\// { print $1 }' \
    | LC_ALL=C sort -u)"
  [[ "$citizen_links" == "$expected_install_name" ]] \
    || fail "Apple 消费者 smoke 的 CitizenSDK 链接闭集漂移：${citizen_links:-无}"
  HOME="$smoke_root/home-normal" \
  CFFIXED_USER_HOME="$smoke_root/home-normal" \
  TMPDIR="$smoke_root/tmp-normal" \
  DYLD_FRAMEWORK_PATH="$framework_root" \
    "$executable" normal >"$smoke_root/logs/normal.log" 2>&1 \
    || fail "最终 XCFramework 普通 open/capabilities/close smoke 失败"
  HOME="$smoke_root/home-supervisor" \
  CFFIXED_USER_HOME="$smoke_root/home-supervisor" \
  TMPDIR="$smoke_root/tmp-supervisor" \
  DYLD_FRAMEWORK_PATH="$framework_root" \
    "$executable" supervisor >"$smoke_root/logs/supervisor.log" 2>&1 \
    || fail "最终 XCFramework supervisor/SQLite FD smoke 失败"
}

build_apple_tests() {
  [[ "$(uname -s)" == Darwin && "$(uname -m)" == arm64 ]] \
    || fail "macOS XCTest 只允许在 Apple Silicon runner 执行"
  local xcframework flutter_root flutter_ios_xcframework flutter_macos_xcframework
  local test_header_root
  xcframework="$output_dir/apple/CitizenSDK.xcframework"
  verify_apple_xcframework "$xcframework"
  flutter_root="$(resolve_flutter_sdk_root)"
  flutter_ios_xcframework="$flutter_root/bin/cache/artifacts/engine/ios-release/Flutter.xcframework"
  flutter_macos_xcframework="$(resolve_flutter_macos_xcframework "$flutter_root")"
  # Source tests resolve include/ from their canonical repository-relative
  # location. Recreate that shared layout above all per-platform harnesses.
  test_header_root="$work_dir/apple-test-harness/include"
  prepare_safe_directory "$work_dir" "$test_header_root" \
    "Apple XCTest 共享头文件目录"
  for header in citizensdk.h citizensdk_types.h; do
    prepare_safe_output_file "$work_dir" "$test_header_root/$header" \
      "Apple XCTest 共享头文件"
    cp "$sdk_dir/include/$header" "$test_header_root/$header"
  done
  run_apple_test_harness aarch64-apple-ios iphoneos arm64-apple-ios16.0 \
    aarch64-apple-ios Flutter "$flutter_ios_xcframework" compile
  run_apple_test_harness aarch64-apple-ios-sim iphonesimulator \
    arm64-apple-ios16.0-simulator aarch64-apple-ios-sim Flutter \
    "$flutter_ios_xcframework" compile
  run_apple_test_harness aarch64-apple-darwin macosx arm64-apple-macosx13.0 \
    aarch64-apple-darwin FlutterMacOS "$flutter_macos_xcframework" run
  run_final_apple_consumer_smoke
}

build_apple_framework_slice() {
  local rust_target="$1" apple_sdk="$2" swift_target="$3" slice_name="$4"
  local module_identity="$5" supported_platform="$6" platform_name="$7"
  local minimum_key="$8" minimum_version="$9"
  local slice_root framework framework_content_root framework_headers modules
  local framework_resources framework_binary framework_plist framework_install_name
  local module_map module_cache
  local sdk_path swiftc static_library software_version privacy_file source nm_bin
  local probe export_list
  local -a swift_sources swift_command

  require_rust_target "$rust_target"
  software_version="$(sed -n 's/^version: \([0-9][0-9.]*\)$/\1/p' "$sdk_dir/pubspec.yaml")"
  [[ "$software_version" =~ ^[0-9]+\.[0-9]{1,2}\.[0-9]{1,2}$ ]] \
    || fail "pubspec.yaml 软件版本无效"
  privacy_file="$darwin_source_root/PrivacyInfo.xcprivacy"
  [[ -d "$darwin_source_root" && -f "$privacy_file" \
    && -f "$product_header" && -f "$product_types_header" ]] \
    || fail "Apple Swift 源码、隐私清单或产品头不完整"

  swift_sources=()
  while IFS= read -r source; do
    swift_sources+=("$source")
  done < <(find "$darwin_source_root" -maxdepth 1 -type f -name '*.swift' -print | LC_ALL=C sort)
  [[ "${#swift_sources[@]}" -gt 0 ]] || fail "CitizenSDK Swift 产品源码为空"

  case "$rust_target" in
    aarch64-apple-ios|aarch64-apple-ios-sim)
      IPHONEOS_DEPLOYMENT_TARGET="$ios_deployment_target" \
        CARGO_PROFILE_RELEASE_STRIP=false \
        cargo build --manifest-path "$product_ffi_manifest" --release --locked \
          --target "$rust_target"
      ;;
    aarch64-apple-darwin)
      MACOSX_DEPLOYMENT_TARGET="$macos_deployment_target" \
        CARGO_PROFILE_RELEASE_STRIP=false \
        cargo build --manifest-path "$product_ffi_manifest" --release --locked \
          --target "$rust_target"
      ;;
    *) fail "Apple 产品禁止未登记 Rust target：$rust_target" ;;
  esac
  static_library="$CARGO_TARGET_DIR/$rust_target/release/libcitizensdk.a"
  [[ -f "$static_library" && ! -L "$static_library" ]] \
    || fail "$slice_name 的 native/ffi 静态 Core 未生成"

  slice_root="$work_dir/apple-build/$slice_name"
  [[ ! -e "$slice_root" && ! -L "$slice_root" ]] \
    || fail "$slice_name Apple slice 构建目录必须全新"
  framework="$slice_root/CitizenSDK.framework"
  if [[ "$module_identity" == arm64-apple-macos ]]; then
    # macOS framework 必须采用 Apple 标准版本化目录。iOS 设备与
    # simulator 技术变体均保持 Apple 要求的 shallow framework；三者
    # 最终进入同一个 CitizenSDK.xcframework，公开平台名只是 iOS/macOS。
    framework_content_root="$framework/Versions/A"
    framework_plist="$framework_content_root/Resources/Info.plist"
    framework_install_name='@rpath/CitizenSDK.framework/Versions/A/CitizenSDK'
  else
    framework_content_root="$framework"
    framework_plist="$framework/Info.plist"
    framework_install_name='@rpath/CitizenSDK.framework/CitizenSDK'
  fi
  framework_headers="$framework_content_root/Headers"
  modules="$framework_content_root/Modules/CitizenSDK.swiftmodule"
  framework_resources="$framework_content_root/Resources"
  framework_binary="$framework_content_root/CitizenSDK"
  module_map="$framework_content_root/Modules/module.modulemap"
  module_cache="$work_dir/apple-module-cache/$slice_name"
  for directory in \
    "$framework_headers" "$modules" "$framework_resources/citizenchain" "$module_cache"; do
    prepare_safe_directory "$work_dir" "$directory" "$slice_name Apple 构建目录"
  done
  cp "$product_header" "$framework_headers/citizensdk.h"
  cp "$product_types_header" "$framework_headers/citizensdk_types.h"
  write_framework_module_map "$module_map"
  for asset in chainspec.json light_sync_state.json manifest.json; do
    [[ -f "$apple_asset_root/$asset" && ! -L "$apple_asset_root/$asset" ]] \
      || fail "Apple 链资产缺失：$asset"
    cp "$apple_asset_root/$asset" "$framework_resources/citizenchain/$asset"
  done
  cp "$privacy_file" "$framework_resources/PrivacyInfo.xcprivacy"
  prepare_safe_output_file "$work_dir" "$framework_plist" "$slice_name Info.plist"
  write_framework_plist \
    "$framework_plist" "$supported_platform" "$platform_name" \
    "$minimum_key" "$minimum_version" "$software_version"

  if [[ "$module_identity" == arm64-apple-macos ]]; then
    # 只允许这四个已经存在目标的目录链接；最终二进制写入 Versions/A 后再建立
    # 第五个链接，构建期间不会制造悬空入口，也不会让秘密或产物越出中央 workdir。
    for link_spec in \
      'Versions/Current|A' \
      'Headers|Versions/Current/Headers' \
      'Modules|Versions/Current/Modules' \
      'Resources|Versions/Current/Resources'; do
      local link_path="${link_spec%%|*}" link_target="${link_spec#*|}"
      prepare_safe_output_file "$work_dir" "$framework/$link_path" \
        "$slice_name framework 标准目录链接"
      ln -s "$link_target" "$framework/$link_path"
      [[ -L "$framework/$link_path" && -e "$framework/$link_path" \
        && "$(readlink "$framework/$link_path")" == "$link_target" ]] \
        || fail "$slice_name framework 标准目录链接创建失败：$link_path"
    done
  fi

  sdk_path="$(xcrun --sdk "$apple_sdk" --show-sdk-path)"
  swiftc="$(xcrun --sdk "$apple_sdk" --find swiftc)"
  nm_bin="$(xcrun --find nm)"
  [[ -d "$sdk_path" && -x "$swiftc" && -x "$nm_bin" ]] \
    || fail "$slice_name 缺少受控 Apple SDK、swiftc 或 nm"
  swift_command=("$swiftc" "${swift_sources[@]}"
    -parse-as-library \
    -swift-version 5 \
    -warnings-as-errors \
    -strict-concurrency=complete \
    -O \
    -whole-module-optimization \
    -enable-library-evolution \
    -emit-library \
    -emit-module \
    -emit-module-path "$modules/$module_identity.swiftmodule" \
    -emit-module-interface-path "$modules/$module_identity.swiftinterface" \
    -emit-private-module-interface-path "$modules/$module_identity.private.swiftinterface" \
    -module-name CitizenSDK \
    -module-cache-path "$module_cache" \
    -sdk "$sdk_path" \
    -target "$swift_target" \
    -import-underlying-module \
    -F "$slice_root" \
    -Xcc "-I$framework/Headers" \
    -Xlinker -force_load \
    -Xlinker "$static_library" \
    -Xlinker -install_name \
    -Xlinker "$framework_install_name" \
    -framework Security \
    -framework LocalAuthentication \
    -lsqlite3)
  # 第一阶段只存在中央 workdir，用于从真实 Swift 编译结果提取本模块 mangled
  # exports；第二阶段才用允许集生成候选 framework。允许集不写入源码或候选。
  probe="$slice_root/CitizenSDK.unfiltered"
  export_list="$slice_root/CitizenSDK.exported-symbols"
  prepare_safe_output_file "$work_dir" "$probe" "$slice_name 未过滤链接"
  "${swift_command[@]}" -o "$probe"
  write_apple_exported_symbols "$probe" "$nm_bin" "$export_list" "$slice_name"
  prepare_safe_output_file "$work_dir" "$framework_binary" "$slice_name framework 二进制"
  "${swift_command[@]}" \
    -Xlinker -exported_symbols_list \
    -Xlinker "$export_list" \
    -o "$framework_binary"
  if [[ "$module_identity" == arm64-apple-macos ]]; then
    prepare_safe_output_file "$work_dir" "$framework/CitizenSDK" \
      "$slice_name framework 标准二进制链接"
    ln -s 'Versions/Current/CitizenSDK' "$framework/CitizenSDK"
    [[ -L "$framework/CitizenSDK" && -e "$framework/CitizenSDK" \
      && "$(readlink "$framework/CitizenSDK")" == 'Versions/Current/CitizenSDK' ]] \
      || fail "$slice_name framework 标准二进制链接创建失败"
  fi
  # 对最终候选中的 textual interface 重新调用 Swift frontend。该 interface
  # 必须通过同名 framework module 解析根 C 头；编译时不使用 bridging header，
  # 从而维持一个 CitizenSDK 混合模块而非第二个 CitizenSDKC 产品。
  prepare_safe_directory "$work_dir" "$module_cache/interface" \
    "$slice_name Swift interface module cache"
  for source in \
    "$modules/$module_identity.swiftinterface" \
    "$modules/$module_identity.private.swiftinterface"; do
    "$swiftc" -frontend \
      -typecheck-module-from-interface "$source" \
      -module-name CitizenSDK \
      -swift-version 5 \
      -warnings-as-errors \
      -strict-concurrency=complete \
      -sdk "$sdk_path" \
      -target "$swift_target" \
      -import-underlying-module \
      -F "$slice_root" \
      -module-cache-path "$module_cache/interface"
  done
}

restore_swift_module_artifacts() {
  local xcframework="$1" build_key module_identity platform variant extension
  local source source_root destination destination_framework destination_root
  while IFS='|' read -r build_key module_identity platform variant; do
    source_root="$work_dir/apple-build/$build_key/CitizenSDK.framework"
    destination_framework="$(resolve_xcframework_framework_slice \
      "$xcframework" CitizenSDK "$platform" "$variant")"
    destination_root="$destination_framework"
    if [[ "$platform" == macos ]]; then
      source_root="$source_root/Versions/A"
      destination_root="$destination_root/Versions/A"
    fi
    # `xcodebuild -create-xcframework` may rewrite or omit compiler-emitted
    # module sidecars. Restore/compare the exact six-file Swift module closure
    # from each already verified input slice, never only the executable module.
    for extension in \
      abi.json private.swiftinterface swiftdoc swiftinterface swiftmodule swiftsourceinfo; do
      source="$source_root/Modules/CitizenSDK.swiftmodule/$module_identity.$extension"
      destination="$destination_root/Modules/CitizenSDK.swiftmodule/$module_identity.$extension"
      [[ -f "$source" && ! -L "$source" ]] \
        || fail "$platform/$variant 输入 framework 缺少 Swift module 产物：$extension"
      if [[ -e "$destination" || -L "$destination" ]]; then
        [[ -f "$destination" && ! -L "$destination" ]] \
          || fail "$platform/$variant XCFramework Swift module 产物不是普通文件：$extension"
        cmp -s "$source" "$destination" \
          || fail "$platform/$variant XCFramework Swift module 产物字节漂移：$extension"
      else
        prepare_safe_output_file "$work_dir" "$destination" \
          "$platform/$variant Swift module 产物投影：$extension"
        cp "$source" "$destination"
      fi
    done
  done <<'MODULES'
aarch64-apple-ios|arm64-apple-ios|ios|
aarch64-apple-ios-sim|arm64-apple-ios-simulator|ios|simulator
aarch64-apple-darwin|arm64-apple-macos|macos|
MODULES
}

verify_apple_framework_slice() {
  local framework="$1" label="$2" expected_platform="$3" expected_minos="$4"
  local module_identity="$5" framework_content_root framework_plist binary nm_bin
  local architectures install_name expected_install_name build_info links top_entries version_entries
  local actual_platform actual_minos entries expected_entries swift_modules module_entries
  local bundle_platform platform_name minimum_key software_version expected_plist
  [[ -d "$framework" && ! -L "$framework" ]] || fail "$label framework 缺失"
  entries="$(find "$(dirname "$framework")" -mindepth 1 -maxdepth 1 -print \
    | sed 's#^.*/##' | LC_ALL=C sort)"
  [[ "$entries" == CitizenSDK.framework ]] \
    || fail "$label slice 目录闭集漂移：${entries:-无}"
  if [[ "$module_identity" == arm64-apple-macos ]]; then
    top_entries="$(find "$framework" -mindepth 1 -maxdepth 1 -print \
      | sed 's#^.*/##' | LC_ALL=C sort)"
    [[ "$top_entries" == $'CitizenSDK\nHeaders\nModules\nResources\nVersions' ]] \
      || fail "$label 版本化 framework 顶层闭集漂移"
    version_entries="$(find "$framework/Versions" -mindepth 1 -maxdepth 1 -print \
      | sed 's#^.*/##' | LC_ALL=C sort)"
    [[ "$version_entries" == $'A\nCurrent' ]] \
      || fail "$label Versions 闭集漂移"
    links="$(find "$framework" -type l -print \
      | sed "s#^$framework/##" | LC_ALL=C sort)"
    [[ "$links" == $'CitizenSDK\nHeaders\nModules\nResources\nVersions/Current' ]] \
      || fail "$label 标准内部符号链接闭集漂移：${links:-无}"
    while IFS='|' read -r link_path link_target; do
      [[ -L "$framework/$link_path" \
        && "$(readlink "$framework/$link_path")" == "$link_target" \
        && -e "$framework/$link_path" ]] \
        || fail "$label 标准内部符号链接漂移：$link_path"
    done <<'MACOS_FRAMEWORK_LINKS'
CitizenSDK|Versions/Current/CitizenSDK
Headers|Versions/Current/Headers
Modules|Versions/Current/Modules
Resources|Versions/Current/Resources
Versions/Current|A
MACOS_FRAMEWORK_LINKS
    framework_content_root="$framework/Versions/A"
    entries="$(find "$framework_content_root" -mindepth 1 -maxdepth 1 -print \
      | sed 's#^.*/##' | LC_ALL=C sort)"
    [[ "$entries" == $'CitizenSDK\nHeaders\nModules\nResources' ]] \
      || fail "$label Versions/A 内容闭集漂移"
    framework_plist="$framework_content_root/Resources/Info.plist"
  else
    [[ -z "$(find "$framework" -type l -print -quit)" ]] \
      || fail "$label shallow framework 禁止符号链接"
    top_entries="$(find "$framework" -mindepth 1 -maxdepth 1 -print \
      | sed 's#^.*/##' | LC_ALL=C sort)"
    [[ "$top_entries" == $'CitizenSDK\nHeaders\nInfo.plist\nModules\nResources' ]] \
      || fail "$label shallow framework 顶层闭集漂移"
    framework_content_root="$framework"
    framework_plist="$framework/Info.plist"
  fi
  binary="$framework_content_root/CitizenSDK"
  [[ -f "$binary" && ! -L "$binary" ]] || fail "$label framework 二进制缺失"
  architectures="$(xcrun lipo -archs "$binary")"
  [[ "$architectures" == arm64 ]] || fail "$label 内部架构必须精确为 arm64；实际=$architectures"
  install_name="$(xcrun otool -D "$binary" | tail -n +2 | sed '/^[[:space:]]*$/d')"
  if [[ "$module_identity" == arm64-apple-macos ]]; then
    expected_install_name='@rpath/CitizenSDK.framework/Versions/A/CitizenSDK'
  else
    expected_install_name='@rpath/CitizenSDK.framework/CitizenSDK'
  fi
  [[ "$install_name" == "$expected_install_name" ]] \
    || fail "$label install name 漂移：${install_name:-无}"
  build_info="$(xcrun vtool -show-build "$binary")"
  actual_platform="$(printf '%s\n' "$build_info" | awk '$1 == "platform" { print $2 }')"
  actual_minos="$(printf '%s\n' "$build_info" | awk '$1 == "minos" { print $2 }')"
  [[ "$actual_platform" == "$expected_platform" && "$actual_minos" == "$expected_minos" ]] \
    || fail "$label 平台/最低版本漂移：$actual_platform/$actual_minos"
  nm_bin="$(xcrun --find nm)"
  verify_apple_product_abi_symbols "$binary" "$nm_bin" "$label"

  [[ -d "$framework_content_root/Headers" \
    && ! -L "$framework_content_root/Headers" ]] \
    || fail "$label Headers 不是普通目录"
  entries="$(find "$framework_content_root/Headers" -mindepth 1 -maxdepth 1 -print \
    | sed 's#^.*/##' | LC_ALL=C sort)"
  expected_entries=$'citizensdk.h\ncitizensdk_types.h'
  [[ "$entries" == "$expected_entries" ]] || fail "$label 产品头闭集漂移"
  [[ -f "$framework_content_root/Headers/citizensdk.h" \
    && ! -L "$framework_content_root/Headers/citizensdk.h" \
    && -f "$framework_content_root/Headers/citizensdk_types.h" \
    && ! -L "$framework_content_root/Headers/citizensdk_types.h" ]] \
    || fail "$label 产品头必须全部为普通文件"
  cmp -s "$framework_content_root/Headers/citizensdk.h" "$product_header" \
    || fail "$label citizensdk.h 与根产品头不一致"
  cmp -s "$framework_content_root/Headers/citizensdk_types.h" "$product_types_header" \
    || fail "$label citizensdk_types.h 与根产品头不一致"
  [[ -d "$framework_content_root/Modules" \
    && ! -L "$framework_content_root/Modules" ]] \
    || fail "$label Modules 不是普通目录"
  module_entries="$(find "$framework_content_root/Modules" \
    -mindepth 1 -maxdepth 1 -print | sed 's#^.*/##' | LC_ALL=C sort)"
  [[ "$module_entries" == $'CitizenSDK.swiftmodule\nmodule.modulemap' \
    && -f "$framework_content_root/Modules/module.modulemap" \
    && ! -L "$framework_content_root/Modules/module.modulemap" \
    && -d "$framework_content_root/Modules/CitizenSDK.swiftmodule" \
    && ! -L "$framework_content_root/Modules/CitizenSDK.swiftmodule" ]] \
    || fail "$label Modules 节点闭集或类型漂移"
  grep -Fq 'framework module CitizenSDK' "$framework_content_root/Modules/module.modulemap" \
    || fail "$label 缺少 CitizenSDK Clang module"
  swift_modules="$(find "$framework_content_root/Modules/CitizenSDK.swiftmodule" \
    -mindepth 1 -maxdepth 1 -print | sed 's#^.*/##' | LC_ALL=C sort)"
  expected_entries="$(printf '%s\n' \
    "$module_identity.abi.json" \
    "$module_identity.private.swiftinterface" \
    "$module_identity.swiftdoc" \
    "$module_identity.swiftinterface" \
    "$module_identity.swiftmodule" \
    "$module_identity.swiftsourceinfo" | LC_ALL=C sort)"
  [[ "$swift_modules" == "$expected_entries" ]] \
    || fail "$label Swift module 六文件闭集漂移"
  for interface in \
    "$framework_content_root/Modules/CitizenSDK.swiftmodule/$module_identity.swiftinterface" \
    "$framework_content_root/Modules/CitizenSDK.swiftmodule/$module_identity.private.swiftinterface"; do
    grep -Fxq '@_exported import CitizenSDK' "$interface" \
      || fail "$label Swift interface 未固定同名 underlying Clang module"
  done
  grep -Fq '@_spi(CitizenSDKFlutter)' \
    "$framework_content_root/Modules/CitizenSDK.swiftmodule/$module_identity.private.swiftinterface" \
    || fail "$label private Swift interface 缺少 CitizenSDKFlutter SPI"
  while IFS= read -r module_file; do
    [[ -f "$framework_content_root/Modules/CitizenSDK.swiftmodule/$module_file" \
      && ! -L "$framework_content_root/Modules/CitizenSDK.swiftmodule/$module_file" ]] \
      || fail "$label Swift module 必须全部为普通文件：$module_file"
  done <<<"$swift_modules"
  [[ -d "$framework_content_root/Resources" \
    && ! -L "$framework_content_root/Resources" \
    && -d "$framework_content_root/Resources/citizenchain" \
    && ! -L "$framework_content_root/Resources/citizenchain" ]] \
    || fail "$label Resources 或 citizenchain 不是普通目录"
  entries="$(find "$framework_content_root/Resources" -mindepth 1 -print \
    | sed 's#^.*/Resources/##' | LC_ALL=C sort)"
  if [[ "$module_identity" == arm64-apple-macos ]]; then
    expected_entries=$'Info.plist\nPrivacyInfo.xcprivacy\ncitizenchain\ncitizenchain/chainspec.json\ncitizenchain/light_sync_state.json\ncitizenchain/manifest.json'
  else
    expected_entries=$'PrivacyInfo.xcprivacy\ncitizenchain\ncitizenchain/chainspec.json\ncitizenchain/light_sync_state.json\ncitizenchain/manifest.json'
  fi
  [[ "$entries" == "$expected_entries" ]] || fail "$label Resources 闭集漂移"
  for asset in chainspec.json light_sync_state.json manifest.json; do
    [[ -f "$framework_content_root/Resources/citizenchain/$asset" \
      && ! -L "$framework_content_root/Resources/citizenchain/$asset" ]] \
      || fail "$label 链资产不是普通文件：$asset"
    cmp -s "$framework_content_root/Resources/citizenchain/$asset" "$apple_asset_root/$asset" \
      || fail "$label 链资产字节漂移：$asset"
  done
  [[ -f "$framework_content_root/Resources/PrivacyInfo.xcprivacy" \
    && ! -L "$framework_content_root/Resources/PrivacyInfo.xcprivacy" \
    && -f "$framework_plist" && ! -L "$framework_plist" ]] \
    || fail "$label 隐私清单或 Info.plist 不是普通文件"
  cmp -s "$framework_content_root/Resources/PrivacyInfo.xcprivacy" \
    "$darwin_source_root/PrivacyInfo.xcprivacy" \
    || fail "$label 隐私清单字节漂移"
  case "$module_identity" in
    arm64-apple-ios)
      bundle_platform=iPhoneOS; platform_name=iphoneos; minimum_key=MinimumOSVersion ;;
    arm64-apple-ios-simulator)
      bundle_platform=iPhoneSimulator; platform_name=iphonesimulator; minimum_key=MinimumOSVersion ;;
    arm64-apple-macos)
      bundle_platform=MacOSX; platform_name=macosx; minimum_key=LSMinimumSystemVersion ;;
    *) fail "$label Swift module identity 未登记：$module_identity" ;;
  esac
  software_version="$(sed -n 's/^version: \([0-9][0-9.]*\)$/\1/p' "$sdk_dir/pubspec.yaml")"
  expected_plist="$work_dir/apple-plist-contract/$module_identity.plist"
  if [[ ! -e "$expected_plist" && ! -L "$expected_plist" ]]; then
    prepare_safe_output_file "$work_dir" "$expected_plist" "$label Info.plist 合同"
    write_framework_plist "$expected_plist" "$bundle_platform" "$platform_name" \
      "$minimum_key" "$expected_minos" "$software_version"
  fi
  cmp -s \
    <(/usr/bin/plutil -convert binary1 -o - "$framework_plist") \
    <(/usr/bin/plutil -convert binary1 -o - "$expected_plist") \
    || fail "$label Info.plist 完整字段合同漂移"
}

verify_apple_xcframework() {
  local xcframework="$1" entries expected_entries index identifier library_path
  local binary_path expected_binary_path architecture extra_architecture platform variant
  local metadata expected_metadata plist_keys library_keys expected_library_keys
  local identifiers='' ios_device_identifier='' ios_simulator_identifier=''
  local macos_identifier=''
  [[ -d "$xcframework" && ! -L "$xcframework" ]] \
    || fail "CitizenSDK.xcframework 缺失或不是普通目录"
  [[ -f "$xcframework/Info.plist" && ! -L "$xcframework/Info.plist" ]] \
    || fail "CitizenSDK.xcframework 缺少普通 Info.plist"
  plist_keys="$(/usr/libexec/PlistBuddy -c Print "$xcframework/Info.plist" \
    | awk '/^    [^ ]/ && / = / { print $1 }' | LC_ALL=C sort)"
  [[ "$plist_keys" == $'AvailableLibraries\nCFBundlePackageType\nXCFrameworkFormatVersion' \
    && "$(/usr/libexec/PlistBuddy -c 'Print :XCFrameworkFormatVersion' \
      "$xcframework/Info.plist")" == 1.0 ]] \
    || fail "XCFramework Info.plist 根字段闭集或格式版本漂移"
  metadata=''
  for index in 0 1 2; do
    identifier="$(/usr/libexec/PlistBuddy \
      -c "Print :AvailableLibraries:$index:LibraryIdentifier" \
      "$xcframework/Info.plist")"
    library_path="$(/usr/libexec/PlistBuddy \
      -c "Print :AvailableLibraries:$index:LibraryPath" \
      "$xcframework/Info.plist")"
    binary_path="$(/usr/libexec/PlistBuddy \
      -c "Print :AvailableLibraries:$index:BinaryPath" \
      "$xcframework/Info.plist")"
    architecture="$(/usr/libexec/PlistBuddy \
      -c "Print :AvailableLibraries:$index:SupportedArchitectures:0" \
      "$xcframework/Info.plist")"
    extra_architecture="$(/usr/libexec/PlistBuddy \
      -c "Print :AvailableLibraries:$index:SupportedArchitectures:1" \
      "$xcframework/Info.plist" 2>/dev/null || true)"
    platform="$(/usr/libexec/PlistBuddy \
      -c "Print :AvailableLibraries:$index:SupportedPlatform" \
      "$xcframework/Info.plist")"
    variant="$(/usr/libexec/PlistBuddy \
      -c "Print :AvailableLibraries:$index:SupportedPlatformVariant" \
      "$xcframework/Info.plist" 2>/dev/null || true)"
    [[ "$identifier" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ \
      && -d "$xcframework/$identifier" && ! -L "$xcframework/$identifier" ]] \
      || fail "XCFramework LibraryIdentifier 必须是 Xcode 生成的安全不透明目录标识：$identifier"
    if printf '%s\n' "$identifiers" | grep -Fxq "$identifier"; then
      fail "XCFramework LibraryIdentifier 重复：$identifier"
    fi
    identifiers+="$identifier"$'\n'
    library_keys="$(/usr/libexec/PlistBuddy \
      -c "Print :AvailableLibraries:$index" "$xcframework/Info.plist" \
      | awk '/^    [^ ]/ && / = / { print $1 }' | LC_ALL=C sort)"
    if [[ -n "$variant" ]]; then
      expected_library_keys=$'BinaryPath\nLibraryIdentifier\nLibraryPath\nSupportedArchitectures\nSupportedPlatform\nSupportedPlatformVariant'
    else
      expected_library_keys=$'BinaryPath\nLibraryIdentifier\nLibraryPath\nSupportedArchitectures\nSupportedPlatform'
    fi
    [[ "$library_keys" == "$expected_library_keys" ]] \
      || fail "XCFramework slice 字段闭集漂移：$identifier"
    case "$platform/$variant" in
      ios/)
        [[ -z "$ios_device_identifier" ]] \
          || fail "XCFramework 重复声明 iOS 设备技术变体"
        ios_device_identifier="$identifier"
        expected_binary_path='CitizenSDK.framework/CitizenSDK'
        ;;
      ios/simulator)
        [[ -z "$ios_simulator_identifier" ]] \
          || fail "XCFramework 重复声明 iOS simulator 技术变体"
        ios_simulator_identifier="$identifier"
        expected_binary_path='CitizenSDK.framework/CitizenSDK'
        ;;
      macos/)
        [[ -z "$macos_identifier" ]] \
          || fail "XCFramework 重复声明 macOS"
        macos_identifier="$identifier"
        expected_binary_path='CitizenSDK.framework/Versions/A/CitizenSDK'
        ;;
      *) fail "XCFramework 含未登记 Apple 技术变体：$platform/$variant" ;;
    esac
    [[ "$library_path" == CitizenSDK.framework && "$architecture" == arm64 \
      && "$binary_path" == "$expected_binary_path" && -z "$extra_architecture" ]] \
      || fail "XCFramework slice 必须精确为单一 arm64 framework：$identifier"
    metadata+="$platform|$variant"$'\n'
  done
  metadata="$(printf '%s' "$metadata" | LC_ALL=C sort)"
  expected_metadata=$'ios|\nios|simulator\nmacos|'
  [[ "$metadata" == "$expected_metadata" ]] \
    || fail "XCFramework Info.plist 三 slice 元数据漂移"
  [[ -n "$ios_device_identifier" && -n "$ios_simulator_identifier" \
    && -n "$macos_identifier" ]] \
    || fail "XCFramework 必须覆盖 iOS 设备、iOS simulator 技术变体和 macOS"
  # LibraryIdentifier 是 xcodebuild 生成的不透明技术标识，不得改写为
  # 产品平台名。目录闭集只从 Info.plist 反向发现。
  entries="$(find "$xcframework" -mindepth 1 -maxdepth 1 -print \
    | sed 's#^.*/##' | LC_ALL=C sort)"
  expected_entries="$(printf '%s\n' Info.plist "$ios_device_identifier" \
    "$ios_simulator_identifier" "$macos_identifier" | LC_ALL=C sort)"
  [[ "$entries" == "$expected_entries" ]] \
    || fail "CitizenSDK.xcframework slice 闭集漂移：${entries:-无}"
  [[ -z "$(find "$xcframework/$ios_device_identifier" \
    "$xcframework/$ios_simulator_identifier" -type l -print -quit)" ]] \
    || fail "CitizenSDK.xcframework 的 iOS 技术变体禁止符号链接"
  while IFS= read -r link; do
    case "$link" in
      "$xcframework/$macos_identifier/CitizenSDK.framework/CitizenSDK"|\
      "$xcframework/$macos_identifier/CitizenSDK.framework/Headers"|\
      "$xcframework/$macos_identifier/CitizenSDK.framework/Modules"|\
      "$xcframework/$macos_identifier/CitizenSDK.framework/Resources"|\
      "$xcframework/$macos_identifier/CitizenSDK.framework/Versions/Current") ;;
      *) fail "CitizenSDK.xcframework 含未登记符号链接：$link" ;;
    esac
  done < <(find "$xcframework" -type l -print)
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundlePackageType' \
    "$xcframework/Info.plist")" == XFWK ]] \
    || fail "XCFramework Info.plist 产品类型必须是 XFWK"
  /usr/libexec/PlistBuddy -c 'Print :AvailableLibraries:3' \
    "$xcframework/Info.plist" >/dev/null 2>&1 \
    && fail "XCFramework Info.plist 含额外 slice" || true
  verify_apple_framework_slice \
    "$xcframework/$ios_device_identifier/CitizenSDK.framework" \
    "CitizenSDK iOS（设备技术变体）" IOS 16.0 arm64-apple-ios
  verify_apple_framework_slice \
    "$xcframework/$ios_simulator_identifier/CitizenSDK.framework" \
    "CitizenSDK iOS（simulator 技术变体）" IOSSIMULATOR 16.0 \
    arm64-apple-ios-simulator
  verify_apple_framework_slice \
    "$xcframework/$macos_identifier/CitizenSDK.framework" \
    "CitizenSDK macOS" MACOS 13.0 arm64-apple-macos
}

build_apple() {
  [[ "$(uname -s)" == Darwin ]] || fail "Apple 产品只允许在 macOS runner 构建"
  local create_root created_xcframework destination flutter_root
  local flutter_ios_xcframework flutter_macos_xcframework
  local citizen_ios_framework citizen_ios_simulator_framework citizen_macos_framework
  command -v xcodebuild >/dev/null 2>&1 || fail "缺少 xcodebuild"
  build_apple_framework_slice \
    aarch64-apple-ios iphoneos arm64-apple-ios16.0 aarch64-apple-ios \
    arm64-apple-ios iPhoneOS iphoneos MinimumOSVersion "$ios_deployment_target"
  build_apple_framework_slice \
    aarch64-apple-ios-sim iphonesimulator arm64-apple-ios16.0-simulator \
    aarch64-apple-ios-sim arm64-apple-ios-simulator iPhoneSimulator iphonesimulator \
    MinimumOSVersion "$ios_deployment_target"
  build_apple_framework_slice \
    aarch64-apple-darwin macosx arm64-apple-macosx13.0 aarch64-apple-darwin \
    arm64-apple-macos MacOSX macosx LSMinimumSystemVersion "$macos_deployment_target"

  create_root="$work_dir/apple-xcframework"
  prepare_safe_directory "$work_dir" "$create_root" "Apple XCFramework 生成目录"
  created_xcframework="$create_root/CitizenSDK.xcframework"
  [[ ! -e "$created_xcframework" && ! -L "$created_xcframework" ]] \
    || fail "Apple XCFramework 生成目标已存在"
  xcodebuild -create-xcframework \
    -framework "$work_dir/apple-build/aarch64-apple-ios/CitizenSDK.framework" \
    -framework "$work_dir/apple-build/aarch64-apple-ios-sim/CitizenSDK.framework" \
    -framework "$work_dir/apple-build/aarch64-apple-darwin/CitizenSDK.framework" \
    -output "$created_xcframework"
  # Xcode 27 在存在 stable interface 时会从 create-xcframework 输出中移除
  # 编译 `.swiftmodule`。从三个已经逐 slice 验证的输入 framework 原字节恢复，
  # 让同编译器快速路径与跨编译器 textual interface 同时进入唯一产品。
  restore_swift_module_artifacts "$created_xcframework"
  verify_apple_xcframework "$created_xcframework"

  flutter_root="$(resolve_flutter_sdk_root)"
  flutter_ios_xcframework="$flutter_root/bin/cache/artifacts/engine/ios-release/Flutter.xcframework"
  flutter_macos_xcframework="$(resolve_flutter_macos_xcframework "$flutter_root")"
  citizen_ios_framework="$(resolve_xcframework_framework_slice \
    "$created_xcframework" CitizenSDK ios '')"
  citizen_ios_simulator_framework="$(resolve_xcframework_framework_slice \
    "$created_xcframework" CitizenSDK ios simulator)"
  citizen_macos_framework="$(resolve_xcframework_framework_slice \
    "$created_xcframework" CitizenSDK macos '')"
  compile_apple_flutter_adapter iphoneos arm64-apple-ios16.0 aarch64-apple-ios \
    ios '' Flutter "$flutter_ios_xcframework" "$(dirname "$citizen_ios_framework")"
  compile_apple_flutter_adapter iphonesimulator arm64-apple-ios16.0-simulator \
    aarch64-apple-ios-sim ios simulator Flutter "$flutter_ios_xcframework" \
    "$(dirname "$citizen_ios_simulator_framework")"
  compile_apple_flutter_adapter macosx arm64-apple-macosx13.0 \
    aarch64-apple-darwin macos '' FlutterMacOS "$flutter_macos_xcframework" \
    "$(dirname "$citizen_macos_framework")"

  destination="$output_dir/apple/CitizenSDK.xcframework"
  prepare_safe_directory "$output_dir" "$(dirname "$destination")" \
    "Apple 产品父目录"
  [[ ! -e "$destination" && ! -L "$destination" ]] \
    || fail "Apple 产品目标已存在：$destination"
  cp -R "$created_xcframework" "$destination"
  verify_apple_xcframework "$destination"
  echo "CitizenSDK iOS/macOS XCFramework 完成：$destination"
}

build_host() {
  [[ "$(uname -s)" == "Darwin" ]] || fail "当前宿主测试库只允许在 macOS runner 构建"
  local destination arm_library nm_bin symbols architectures
  require_rust_target aarch64-apple-darwin
  destination="$output_dir/host/libsmoldot.dylib"
  # legacy Dart/smoldot 差分测试运行件只保留当前正式 macOS；其
  # 内部 Mach-O 架构必须是工具链值 arm64，且它绝不进入
  # CitizenSDK 候选，也不能借 Rosetta 再建立 x86_64/universal 第二条构建路径。
  MACOSX_DEPLOYMENT_TARGET="$macos_deployment_target" \
  CARGO_PROFILE_RELEASE_STRIP=false cargo build --manifest-path "$ffi_manifest" \
    --release --locked --target aarch64-apple-darwin
  arm_library="$CARGO_TARGET_DIR/aarch64-apple-darwin/release/libsmoldot.dylib"
  [[ -f "$arm_library" ]] || fail "macOS 宿主测试库未生成"
  prepare_safe_output_file "$output_dir" "$destination" "macOS 宿主测试库"
  cp "$arm_library" "$destination"
  architectures="$(xcrun lipo -archs "$destination")"
  [[ "$architectures" == arm64 ]] || fail "macOS 宿主测试库内部架构必须精确为 arm64"
  nm_bin="$(xcrun --find llvm-nm)"
  symbols="$(symbol_list_ios "$destination" "$nm_bin")"
  verify_symbol_contract "$symbols" "_" "macOS 宿主测试库"
  echo "CitizenSDK macOS 宿主测试库完成：$destination"
}

build_abi_host() {
  local destination source_library nm_bin extension prefix
  case "$(uname -s)" in
    Darwin)
      extension=dylib
      prefix=_
      nm_bin="$(xcrun --find llvm-nm)"
      ;;
    Linux)
      extension=so
      prefix=''
      nm_bin="$(command -v llvm-nm || command -v nm || true)"
      [[ -n "$nm_bin" ]] || fail "当前 Linux 宿主缺少 llvm-nm 或 nm"
      ;;
    *) fail "产品 ABI 宿主验证尚不支持：$(uname -s)" ;;
  esac
  destination="$output_dir/abi-host/libcitizensdk.$extension"
  CARGO_PROFILE_RELEASE_STRIP=false cargo build --manifest-path "$product_ffi_manifest" \
    --release --locked
  source_library="$CARGO_TARGET_DIR/release/libcitizensdk.$extension"
  [[ -f "$source_library" ]] || fail "CitizenSDK 产品 ABI 宿主库未生成"
  prepare_safe_output_file "$output_dir" "$destination" "CitizenSDK 产品 ABI 宿主库"
  cp "$source_library" "$destination"
  verify_product_abi_symbols "$destination" "$nm_bin" "$prefix" \
    "CitizenSDK 产品 ABI 宿主库"
  "${CC:-cc}" -std=c11 -fsyntax-only -I"$sdk_dir/include" \
    "$sdk_dir/native/ffi/tests/c_header_c11.c"
  "${CXX:-c++}" -std=c++17 -fsyntax-only -I"$sdk_dir/include" \
    "$sdk_dir/native/ffi/tests/c_header_cpp17.cc"
  echo "CitizenSDK 产品 ABI 宿主验证完成：$destination"
}

verify_outputs() {
  local android_core="$output_dir/android/arm64-v8a/libcitizensdk.so"
  local android_jni="$output_dir/android/arm64-v8a/libcitizensdk_jni.so"
  local android_aar="$output_dir/android/citizensdk.aar"
  local apple_xcframework="$output_dir/apple/CitizenSDK.xcframework"
  local host_library="$output_dir/host/libsmoldot.dylib"
  [[ -f "$android_core" && -f "$android_jni" && -f "$android_aar" \
    && -d "$apple_xcframework" \
    && -f "$host_library" ]] \
    || fail "Android/iOS/macOS 产品与 legacy macOS 宿主测试运行件集合不完整"
  local toolchain nm_bin
  toolchain="$(android_toolchain)"
  verify_product_abi_symbols "$android_core" "$toolchain/bin/llvm-nm" "" \
    "Android libcitizensdk.so"
  verify_android_aar \
    "$android_aar" "$android_core" "$android_jni" "$toolchain/bin/llvm-nm"
  verify_apple_xcframework "$apple_xcframework"
  nm_bin="$(xcrun --find llvm-nm)"
  local host_architectures
  host_architectures="$(xcrun lipo -archs "$host_library")"
  [[ "$host_architectures" == arm64 ]] \
    || fail "macOS 宿主测试库内部架构必须精确为 arm64"
  verify_symbol_contract "$(symbol_list_ios "$host_library" "$nm_bin")" "_" \
    "macOS 宿主测试库"
  echo "CitizenSDK Android AAR、iOS/macOS XCFramework 与 legacy macOS 宿主测试合同通过"
}

case "$target_name" in
  android) build_android ;;
  apple) build_apple ;;
  host) build_host ;;
  abi-host) build_abi_host ;;
  apple-tests) build_apple_tests ;;
  all) build_android; build_apple; build_apple_tests; build_host; verify_outputs ;;
  verify) verify_outputs ;;
  __test-android-toolchain)
    [[ "${CITIZENSDK_BUILD_TEST:-}" == 1 ]] || fail "Android toolchain 测试入口未授权"
    android_toolchain
    ;;
  __test-product-abi-symbols)
    [[ "${CITIZENSDK_BUILD_TEST:-}" == 1 ]] || fail "产品 ABI 符号测试入口未授权"
    [[ -n "${CITIZENSDK_TEST_LIBRARY:-}" && -n "${CITIZENSDK_TEST_NM_BIN:-}" ]] \
      || fail "产品 ABI 符号测试缺少伪库或 nm"
    verify_product_abi_symbols \
      "$CITIZENSDK_TEST_LIBRARY" \
      "$CITIZENSDK_TEST_NM_BIN" \
      "${CITIZENSDK_TEST_SYMBOL_PREFIX:-}" \
      "CitizenSDK 产品 ABI 测试库"
    ;;
  __test-jni-symbols)
    [[ "${CITIZENSDK_BUILD_TEST:-}" == 1 ]] || fail "JNI 符号测试入口未授权"
    [[ -n "${CITIZENSDK_TEST_LIBRARY:-}" && -n "${CITIZENSDK_TEST_NM_BIN:-}" ]] \
      || fail "JNI 符号测试缺少伪库或 nm"
    verify_jni_symbols "$CITIZENSDK_TEST_LIBRARY" "$CITIZENSDK_TEST_NM_BIN"
    ;;
  __test-android-elf-identity)
    [[ "${CITIZENSDK_BUILD_TEST:-}" == 1 ]] || fail "Android ELF 测试入口未授权"
    [[ -n "${CITIZENSDK_TEST_CORE_LIBRARY:-}" \
      && -n "${CITIZENSDK_TEST_JNI_LIBRARY:-}" \
      && -n "${CITIZENSDK_TEST_READELF_BIN:-}" ]] \
      || fail "Android ELF 测试缺少伪库或 readelf"
    verify_android_elf_identity \
      "$CITIZENSDK_TEST_CORE_LIBRARY" \
      "$CITIZENSDK_TEST_JNI_LIBRARY" \
      "$CITIZENSDK_TEST_READELF_BIN"
    ;;
  __test-safe-output-file)
    [[ "${CITIZENSDK_BUILD_TEST:-}" == 1 ]] || fail "安全写路径测试入口未授权"
    [[ -n "${CITIZENSDK_TEST_OUTPUT_RELATIVE:-}" \
      && "${CITIZENSDK_TEST_OUTPUT_RELATIVE}" != /* ]] \
      || fail "安全写路径测试缺少相对目标"
    prepare_safe_output_file \
      "$output_dir" \
      "$output_dir/$CITIZENSDK_TEST_OUTPUT_RELATIVE" \
      "CitizenSDK 安全写路径测试目标"
    ;;
  *) fail "用法：$0 [android|apple|apple-tests|host|abi-host|all|verify]" ;;
esac
