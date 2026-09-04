#!/usr/bin/env bash
# 在本端中央工作根生成本机优化安装包；本脚本不启动、不安装产品。
#
# 用法：citizenwallet-run.sh <ios|android>
#
# 目标平台是必填参数，不做任何自动探测：探测总要在失败时选一个回落，
# 而回落的那一端会被当成用户想编的那一端。塔塔控制台的「编译iOS端 / 编译Android端」
# 两个按钮各自传死这个参数。与 citizenapp-run.sh 同口径。
#
# 本机中间文件只允许进入TataConsole中央`.work`，最终成功包覆盖中央产品产物目录中的固定文件。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CITIZENWALLET_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PLATFORM="${1:?缺少目标平台，用法：$0 <ios|android>}"
[[ "$PLATFORM" == ios || "$PLATFORM" == android ]] \
  || { echo "本机目标平台只接受 ios 或 android：$PLATFORM" >&2; exit 1; }

: "${TATA_CONSOLE_TARGET_ROOT:?本机编译必须由 TataConsole 提供中央产物目录}"
: "${TATA_CONSOLE_WORK_DIR:?本机编译必须由 TataConsole 提供中央工作目录}"
case "$TATA_CONSOLE_WORK_DIR" in "$TATA_CONSOLE_TARGET_ROOT/.work/GMB/citizenwallet/$PLATFORM") ;; *)
  echo "公民钱包中央工作目录不合法：$TATA_CONSOLE_WORK_DIR" >&2; exit 1 ;;
esac
# 源码根只读；两个端的 Flutter、Pods 和 Gradle 状态分别由控制台生成。
[[ "$CITIZENWALLET_DIR" == "$REPO_ROOT/citizenwallet" ]] || {
  echo "citizenwallet本机Build源码身份无效：$CITIZENWALLET_DIR" >&2
  exit 1
}
: "${TATA_CONSOLE_FLUTTER_ROOT:?缺少本端Flutter配置根}"
[[ "$TATA_CONSOLE_FLUTTER_ROOT" == "$TATA_CONSOLE_WORK_DIR" \
  && ! -L "$TATA_CONSOLE_FLUTTER_ROOT" \
  && -f "$TATA_CONSOLE_FLUTTER_ROOT/pubspec.yaml" \
  && ! -L "$TATA_CONSOLE_FLUTTER_ROOT/pubspec.yaml" ]] || {
  echo 'CitizenWallet 必须使用本端独立生成的 Flutter 配置' >&2
  exit 1
}
cd "$TATA_CONSOLE_FLUTTER_ROOT"
[[ "$(pwd -P)" == "$TATA_CONSOLE_WORK_DIR" ]] || {
  echo 'CitizenWallet 中央工作根不得通过符号链接指向其它目录' >&2
  exit 1
}
INCREMENTAL_CACHE_DIR="${TATA_CONSOLE_INCREMENTAL_CACHE_DIR:?缺少TataConsole本机增量缓存目录}"
[[ "$INCREMENTAL_CACHE_DIR" == "$TATA_CONSOLE_WORK_DIR/cache" ]] || {
  echo "CitizenWallet本机增量缓存必须位于$TATA_CONSOLE_WORK_DIR/cache" >&2
  exit 1
}
BUILD_DIR="$INCREMENTAL_CACHE_DIR/flutter-build"
ARTIFACT_ROOT="$TATA_CONSOLE_TARGET_ROOT/GMB/citizenwallet/$PLATFORM"
export TATA_CONSOLE_BUILD_DIR="$BUILD_DIR"
export TATA_CONSOLE_NATIVE_ANDROID_DIR="$INCREMENTAL_CACHE_DIR/native/android"
export TATA_CONSOLE_NATIVE_IOS_DIR="$INCREMENTAL_CACHE_DIR/native/ios"
export CARGO_TARGET_DIR="$INCREMENTAL_CACHE_DIR/cargo-target"
export XDG_CONFIG_HOME="$INCREMENTAL_CACHE_DIR/flutter-config"
export PUB_CACHE="$INCREMENTAL_CACHE_DIR/dart-pub"
export GRADLE_USER_HOME="$INCREMENTAL_CACHE_DIR/gradle"
export CP_HOME_DIR="$INCREMENTAL_CACHE_DIR/cocoapods"
export TMPDIR="$TATA_CONSOLE_WORK_DIR/"
export FLUTTER_SUPPRESS_ANALYTICS=true COCOAPODS_DISABLE_STATS=true
mkdir -p "$XDG_CONFIG_HOME"
flutter config --build-dir=cache/flutter-build >/dev/null

# 与 CitizenApp 共用仓库根 Flutter 依赖真源；版本不符必须在
# 依赖解析之前失败，不能生成另一套 iOS 依赖状态污染工程。
EXPECTED_FLUTTER_VERSION="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["toolchains"]["flutter"])' "$REPO_ROOT/.github/dependencies.json")"
ACTUAL_FLUTTER_VERSION="$(flutter --version --machine 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["frameworkVersion"])' 2>/dev/null || true)"
[[ "$ACTUAL_FLUTTER_VERSION" == "$EXPECTED_FLUTTER_VERSION" ]] || {
  echo "Flutter 版本不一致：要求 ${EXPECTED_FLUTTER_VERSION}，实际 ${ACTUAL_FLUTTER_VERSION:-未安装}" >&2
  exit 1
}

# 仅清理本任务候选包；退出清理由控制台核对任务身份后执行，不触碰源码或另一端。
clean_platform_build_outputs() {
  case "$PLATFORM" in
    ios) rm -rf "$BUILD_DIR/ios/iphoneos/Runner.app" ;;
    android) rm -f "$BUILD_DIR/app/outputs/flutter-apk/"*.apk ;;
  esac
  mkdir -p "$BUILD_DIR"
}

retain_ios_local_artifact() {
  local app_bundle="$1" staging="$TATA_CONSOLE_WORK_DIR/ios.app.zip" destination="$ARTIFACT_ROOT/ios.app.zip"
  rm -f "$staging"
  ditto -c -k --sequesterRsrc --keepParent "$app_bundle" "$staging"
  mkdir -p "$ARTIFACT_ROOT"
  # 同卷固定名称覆盖保证失败时不先删除上一次成功产物。
  mv -f "$staging" "$destination"
}


# 已跟踪的 pallet_registry.dart 是构建输入；本机编译不得回写共享源码索引。

echo "==> 清理 ${PLATFORM} 平台构建产物..."
clean_platform_build_outputs
echo "==> 获取依赖..."
flutter pub get
# Isar 与 QR 生成文件已经纳入仓库。本机四端编译只消费同一份源码，禁止两个平台在
# 构建过程中同时运行 build_runner 改写源文件。

# sr25519 原生签名库(schnorrkel)。签名、派生、验签全走它，缺库会在运行时才炸，
# 所以必须先于 flutter build 产出；实现来自 shared/citizen-signer，
# 与 CitizenApp 热端同一份源码。
echo "==> 编译原生签名库（${PLATFORM}）..."
# 必须用绝对路径 SCRIPT_DIR:上方已 cd 进本端中央工作根,而塔塔控制台以相对路径
# 调本脚本时 $0 是相对串,$(dirname "$0") 会拼在新 cwd 上多套一层目录。
"$SCRIPT_DIR/build-signer-native.sh" "$PLATFORM"

# Build不选择、不安装、不启动设备，只读取当前产品源码并生成中央产物。
# `--release`只是本机优化配置，不表示或触发正式Release流程。
echo "==> 编译本机优化安装包..."
if [[ "$PLATFORM" == ios ]]; then
  flutter build ios --release
  IOS_APP="$BUILD_DIR/ios/iphoneos/Runner.app"
  "$SCRIPT_DIR/build-signer-native.sh" verify-ios-package "$IOS_APP"
  retain_ios_local_artifact "$IOS_APP"
  echo ""
  echo "==> Build完成：iOS产物已写入TataConsole中央目录。"
elif [[ "$PLATFORM" == android ]]; then
  flutter build apk --release --target-platform android-arm64
  ANDROID_APK="$BUILD_DIR/app/outputs/flutter-apk/app-release.apk"
  [[ -f "$ANDROID_APK" ]] || {
    echo "Android 本机无私钥 APK 不存在" >&2
    exit 1
  }
  "$SCRIPT_DIR/build-signer-native.sh" verify-android-package "$ANDROID_APK"
  echo "==> Android无私钥候选完成，正在交给原生安全进程完成Build签名。"
fi
