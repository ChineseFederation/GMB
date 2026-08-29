#!/usr/bin/env bash
# 清理目标平台缓存、编译本机优化安装包并覆盖安装到设备。
# iOS 由系统开发设备签名后原位安装；Android 只在此生成无私钥候选，随后由
# ProgramConsole 原生安全进程使用固定本机开发签名并安装。
#
# 用法：citizenwallet-run.sh <ios|android>
#
# 目标平台是必填参数，不做任何自动探测：探测总要在失败时选一个回落，
# 而回落的那一端会被当成用户想编的那一端。编程控制台的「编译iOS端 / 编译Android端」
# 两个按钮各自传死这个参数。与 citizenapp-run.sh 同口径。
#
# 本机中间文件只允许进入 ProgramConsole 中央 `.work`，最终成功包直接覆盖产品目录中的固定文件。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CITIZENWALLET_DIR="$SCRIPT_DIR/.."
REPO_ROOT="$SCRIPT_DIR/../.."
PLATFORM="${1:?缺少目标平台，用法：$0 <ios|android>}"
[[ "$PLATFORM" == ios || "$PLATFORM" == android ]] \
  || { echo "本机目标平台只接受 ios 或 android：$PLATFORM" >&2; exit 1; }
cd "$CITIZENWALLET_DIR"

: "${PROGRAM_CONSOLE_TARGET_ROOT:?本机编译必须由 ProgramConsole 提供中央产物目录}"
: "${PROGRAM_CONSOLE_WORK_DIR:?本机编译必须由 ProgramConsole 提供中央工作目录}"
case "$PROGRAM_CONSOLE_WORK_DIR" in "$PROGRAM_CONSOLE_TARGET_ROOT/.work/citizenwallet-$PLATFORM") ;; *)
  echo "公民钱包中央工作目录不合法：$PROGRAM_CONSOLE_WORK_DIR" >&2; exit 1 ;;
esac
# 与公民使用同一条不可绕过边界：脚本只接受ProgramConsole中央一次性源码快照，禁止
# 通过手工注入中央build目录却仍在GMB主检出执行Flutter并恢复产品缓存。
[[ "$CITIZENWALLET_DIR" == "$PROGRAM_CONSOLE_WORK_DIR/source/GMB/citizenwallet" ]] || {
  echo "公民钱包本机编译只能在ProgramConsole中央源码快照中运行：$CITIZENWALLET_DIR" >&2
  exit 1
}
BUILD_DIR="$PROGRAM_CONSOLE_WORK_DIR/build"
ARTIFACT_ROOT="$PROGRAM_CONSOLE_TARGET_ROOT/citizenwallet"
export PROGRAM_CONSOLE_BUILD_DIR="$BUILD_DIR"
export PROGRAM_CONSOLE_NATIVE_ANDROID_DIR="$PROGRAM_CONSOLE_WORK_DIR/native/android"
export PROGRAM_CONSOLE_NATIVE_IOS_DIR="$PROGRAM_CONSOLE_WORK_DIR/native/ios"
export XDG_CONFIG_HOME="$PROGRAM_CONSOLE_WORK_DIR/flutter-config"
mkdir -p "$XDG_CONFIG_HOME"
build_dir_relative="$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$BUILD_DIR" "$CITIZENWALLET_DIR")"
flutter config --build-dir="$build_dir_relative" >/dev/null

# 与 CitizenApp 共用仓库根 Flutter 依赖真源；版本不符必须在
# 依赖解析之前失败，不能生成另一套 iOS 依赖状态污染工程。
EXPECTED_FLUTTER_VERSION="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["toolchains"]["flutter"])' "$REPO_ROOT/.github/dependencies.json")"
ACTUAL_FLUTTER_VERSION="$(flutter --version --machine 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["frameworkVersion"])' 2>/dev/null || true)"
[[ "$ACTUAL_FLUTTER_VERSION" == "$EXPECTED_FLUTTER_VERSION" ]] || {
  echo "Flutter 版本不一致：要求 ${EXPECTED_FLUTTER_VERSION}，实际 ${ACTUAL_FLUTTER_VERSION:-未安装}" >&2
  exit 1
}

# 与CitizenApp相同，两个平台使用独立中央工作目录，产品仓库不得恢复`build/`。
clean_platform_build_outputs() {
  rm -rf "$BUILD_DIR"
  mkdir -p "$BUILD_DIR"
}

retain_ios_local_artifact() {
  local app_bundle="$1" staging="$PROGRAM_CONSOLE_WORK_DIR/ios.app.zip" destination="$ARTIFACT_ROOT/ios.app.zip"
  rm -f "$staging"
  ditto -c -k --sequesterRsrc --keepParent "$app_bundle" "$staging"
  mkdir -p "$ARTIFACT_ROOT"
  # 同卷固定名称覆盖保证失败时不先删除上一次成功产物。
  mv -f "$staging" "$destination"
}


# iOS 必须走 CoreDevice 的原位安装，禁止 `flutter install`：该命令的卸载式安装
# install 命令默认先卸载旧 App，会连带删除 Application Support 中的钱包 Isar 数据库。
# `devicectl` 直接接受 Flutter 返回的硬件 UDID。iOS 更新时允许迁移数据容器并改变
# 绝对路径，因此不能比较 UUID；改为在覆盖前后复读钱包 Isar 文件并核对大小。
install_ios_update() {
  local device_id="$1" expected_bundle_id="$2" app_bundle="$3" wallet_database="$4" expected_bundle_version
  expected_bundle_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app_bundle/Info.plist")"
  local actual_bundle_id team_id before_data_container after_data_container
  local before_database_size after_database_size

  [[ -d "$app_bundle" ]] || { echo "iOS App 产物不存在：$app_bundle" >&2; return 1; }
  actual_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_bundle/Info.plist" 2>/dev/null || true)"
  [[ "$actual_bundle_id" == "$expected_bundle_id" ]] || {
    echo "iOS Bundle ID 不匹配：期望 ${expected_bundle_id}，实际 ${actual_bundle_id:-空}" >&2
    return 1
  }
  team_id="$(codesign -d --verbose=4 "$app_bundle" 2>&1 | sed -n 's/^TeamIdentifier=//p' | head -n 1)"
  [[ -n "$team_id" && "$team_id" != Not\ Set ]] || {
    echo "iOS App 缺少有效签名团队，拒绝覆盖设备中的正式数据" >&2
    return 1
  }

  ios_data_container() {
    xcrun devicectl device info apps --quiet \
      --device "$device_id" \
      --bundle-id "$expected_bundle_id" \
      --include-container-paths \
      --json-output - |
      python3 -c '
import json, sys
apps = json.load(sys.stdin).get("result", {}).get("apps", [])
if len(apps) > 1:
    raise SystemExit("同一 Bundle ID 返回多个 App，拒绝继续")
if apps:
    path = apps[0].get("dataContainerPath", "")
    if not path:
        raise SystemExit("无法读取已安装 App 的数据容器，拒绝覆盖")
    print(path)
'
  }

  ios_wallet_database_size() {
    xcrun devicectl device info files --quiet \
      --device "$device_id" \
      --domain-type appDataContainer \
      --domain-identifier "$expected_bundle_id" \
      --subdirectory 'Library/Application Support' \
      --recurse \
      --json-output - |
      python3 -c '
import json, sys
database = sys.argv[1]
files = json.load(sys.stdin).get("result", {}).get("files", [])
matches = [item for item in files if item.get("name") == database]
if len(matches) > 1:
    raise SystemExit("钱包数据库返回多个同名文件，拒绝继续")
if matches:
    size = matches[0].get("metadata", {}).get("size", 0)
    if not isinstance(size, int) or size <= 0:
        raise SystemExit("钱包数据库大小无效，拒绝继续")
    print(size)
' "$wallet_database"
  }

  before_data_container="$(ios_data_container)"
  if [[ -n "$before_data_container" ]]; then
    before_database_size="$(ios_wallet_database_size)"
  else
    before_database_size=""
  fi
  xcrun devicectl device install app --quiet --timeout 180 \
    --device "$device_id" "$app_bundle"
  after_data_container="$(ios_data_container)"
  [[ -n "$after_data_container" ]] || {
    echo "iOS 覆盖安装后未找到 $expected_bundle_id" >&2
    return 1
  }
  xcrun devicectl device info apps --quiet --device "$device_id" \
    --bundle-id "$expected_bundle_id" --json-output - | python3 -c '
import json, sys
expected = sys.argv[1]
apps = json.load(sys.stdin).get("result", {}).get("apps", [])
if len(apps) != 1 or str(apps[0].get("bundleVersion", "")) != expected:
    raise SystemExit("iOS 设备安装后的包版本标识不一致")
' "$expected_bundle_version"
  if [[ -n "$before_database_size" ]]; then
    after_database_size="$(ios_wallet_database_size)"
    [[ "$after_database_size" == "$before_database_size" ]] || {
      echo "iOS 覆盖安装后钱包数据库不存在或大小改变，拒绝把本次安装判为成功" >&2
      return 1
    }
  fi
  echo "    iOS 原位覆盖完成：Bundle ID=${expected_bundle_id}，Team ID=${team_id}，钱包数据库已保留"
}

# 本机编译只调用仓库内唯一的索引同步实现，禁止在本脚本复制第二份规则。
"$SCRIPT_DIR/sync-pallet-registry.sh" "$REPO_ROOT"

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
# 必须用绝对路径 SCRIPT_DIR:上方已 cd 进 CITIZENWALLET_DIR,而编程控制台以相对路径
# 调本脚本时 $0 是相对串,$(dirname "$0") 会拼在新 cwd 上多套一层目录。
"$SCRIPT_DIR/build-signer-native.sh" "$PLATFORM"

# iOS 在脚本内挑选设备并把 id 显式传给系统安装命令；Android 的设备选择、签名证书
# 比对与覆盖安装全部归原生安全进程，脚本不得取得 APP_KEY 或自行调用 adb 安装。
DEVICE_ID=""
if [[ "$PLATFORM" == ios ]]; then
  echo "==> 选择 iOS 设备..."
  DEVICE_ID="$(perl -e 'alarm 60; exec @ARGV' flutter devices --machine 2>/dev/null | python3 -c "
import sys, json
want = sys.argv[1]
try:
    for device in json.load(sys.stdin):
        if want in device.get('targetPlatform', ''):
            print(device['id']); break
except Exception:
    pass
" "$PLATFORM" || true)"
  [[ -n "$DEVICE_ID" ]] || {
    echo "未检测到 iOS 设备：请连接设备后重试。" >&2
    exit 1
  }
  echo "    设备: $DEVICE_ID"
fi

# 本机「编译」只处理当前工作区源码并覆盖安装到设备，不读取或触发任何远端流程。
# 一律 build + install，不用 `flutter run`（它只把 App 挂在调试器上跑）。
# 口径与 citizenapp-run.sh 完全一致,详细理由见该脚本同位置注释:
# - `--release` 只是 Flutter 的本机优化配置，不表示或触发项目的 Release 流程。
# - iOS 必须使用该优化配置：iOS 14+ 禁止 Flutter debug 版脱离 flutter tooling / Xcode 启动,
#   装了 debug 版从桌面点图标必然起不来(表现为"一点就闪退")。安装直接走
#   `devicectl device install app`，接受 flutter 返回的硬件 UDID 且不先卸载旧 App；
#   `flutter install` 默认先卸载，会删除钱包数据，永久禁用。
# - Android 同样构建本机优化包。Gradle 输出无私钥候选；脚本退出后由原生安全进程使用
#   Data Protection Keychain 内的固定本机开发证书签名，证书一致才保留数据覆盖安装。
echo "==> 编译本机优化安装包..."
if [[ "$PLATFORM" == ios ]]; then
  flutter build ios --release
  IOS_APP="$BUILD_DIR/ios/iphoneos/Runner.app"
  "$SCRIPT_DIR/build-signer-native.sh" verify-ios-package "$IOS_APP"
  install_ios_update "$DEVICE_ID" ios.citizenwallet "$IOS_APP" citizenwallet.isar
  retain_ios_local_artifact "$IOS_APP"
  echo ""
  echo "==> 安装完成:请在设备桌面点开「公民钱包」。"
elif [[ "$PLATFORM" == android ]]; then
  flutter build apk --release --target-platform android-arm64
  ANDROID_APK="$BUILD_DIR/app/outputs/flutter-apk/app-release.apk"
  [[ -f "$ANDROID_APK" ]] || {
    echo "Android 本机无私钥 APK 不存在" >&2
    exit 1
  }
  "$SCRIPT_DIR/build-signer-native.sh" verify-android-package "$ANDROID_APK"
  echo "==> Android 本机候选完成，正在交给原生安全进程做本机开发签名并安装。"
fi
