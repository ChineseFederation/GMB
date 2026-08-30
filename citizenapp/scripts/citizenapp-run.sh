#!/usr/bin/env bash
# 清理目标平台缓存、编译本机优化安装包并覆盖安装到设备。
# iOS 由系统开发设备签名后原位安装；Android 只在此生成无私钥候选，随后由
# ProgramConsole 原生安全进程使用固定本机开发签名并安装。
#
# 用法：citizenapp-run.sh <ios|android>
# 只读包检查：citizenapp-run.sh <verify-ios-localization|verify-android-localization> <产物路径>
#
# 目标平台是必填参数，不做任何自动探测：探测总要在失败时选一个回落，
# 而回落的那一端会被当成用户想编的那一端——「以为编了 iOS、实际编的 Android」
# 就是这么来的。编程控制台的「编译iOS端 / 编译Android端」两个按钮各自传死这个参数。
#
# 本机中间文件只允许进入 ProgramConsole 中央 `.work`，最终成功包直接覆盖产品目录中的固定文件。
# 固定使用 smoldot 轻节点连接区块链（无需 RPC 服务器）。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# 中央快照门禁比较的是唯一真实路径；先消解 scripts/..，避免同一路径因文本形态不同被误拒绝。
APP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PLATFORM="${1:?缺少目标平台，用法：$0 <ios|android>}"
[[ "$PLATFORM" == ios || "$PLATFORM" == android \
  || "$PLATFORM" == verify-ios-localization || "$PLATFORM" == verify-android-localization ]] \
  || { echo "目标平台或检查模式不合法：$PLATFORM" >&2; exit 1; }
cd "$APP_ROOT"

if [[ "$PLATFORM" == ios || "$PLATFORM" == android ]]; then
  : "${PROGRAM_CONSOLE_TARGET_ROOT:?本机编译必须由 ProgramConsole 提供中央产物目录}"
  : "${PROGRAM_CONSOLE_WORK_DIR:?本机编译必须由 ProgramConsole 提供中央工作目录}"
  case "$PROGRAM_CONSOLE_WORK_DIR" in "$PROGRAM_CONSOLE_TARGET_ROOT/.work/citizenapp-$PLATFORM") ;; *)
    echo "公民中央工作目录不合法：$PROGRAM_CONSOLE_WORK_DIR" >&2; exit 1 ;;
  esac
  # Flutter会把.dart_tool、Pods、Gradle和Xcode状态写到当前工程。编译脚本只接受
  # ProgramConsole建立的一次性源码快照，直接从GMB主检出运行必须在任何Flutter命令前失败。
  [[ "$APP_ROOT" == "$PROGRAM_CONSOLE_WORK_DIR/source/GMB/citizenapp" ]] || {
    echo "公民本机编译只能在ProgramConsole中央源码快照中运行：$APP_ROOT" >&2
    exit 1
  }
  INCREMENTAL_CACHE_DIR="${PROGRAM_CONSOLE_INCREMENTAL_CACHE_DIR:?缺少ProgramConsole本机增量缓存目录}"
  [[ "$INCREMENTAL_CACHE_DIR" == "$PROGRAM_CONSOLE_WORK_DIR/cache" ]] || {
    echo "CitizenApp本机增量缓存必须位于$PROGRAM_CONSOLE_WORK_DIR/cache" >&2
    exit 1
  }
  BUILD_DIR="$INCREMENTAL_CACHE_DIR/flutter-build"
  ARTIFACT_ROOT="$PROGRAM_CONSOLE_TARGET_ROOT/citizenapp"
  export PROGRAM_CONSOLE_BUILD_DIR="$BUILD_DIR"
  export PROGRAM_CONSOLE_NATIVE_ANDROID_DIR="$INCREMENTAL_CACHE_DIR/native/android"
  export PROGRAM_CONSOLE_NATIVE_IOS_DIR="$INCREMENTAL_CACHE_DIR/native/ios"
  export CARGO_TARGET_DIR="$INCREMENTAL_CACHE_DIR/cargo-target"
  export XDG_CONFIG_HOME="$INCREMENTAL_CACHE_DIR/flutter-config"
  mkdir -p "$XDG_CONFIG_HOME"
  build_dir_relative="$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$BUILD_DIR" "$APP_ROOT")"
  flutter config --build-dir="$build_dir_relative" >/dev/null
fi

# 本机编译只读取仓库统一的 Flutter 依赖真源。禁止直接接受 PATH 中任意
# Flutter；否则同一 iOS 工程会在旧 CocoaPods 与新 SPM 生成状态之间来回切换。
EXPECTED_FLUTTER_VERSION="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["toolchains"]["flutter"])' "$REPO_ROOT/.github/dependencies.json")"
ACTUAL_FLUTTER_VERSION="$(flutter --version --machine 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["frameworkVersion"])' 2>/dev/null || true)"
[[ "$ACTUAL_FLUTTER_VERSION" == "$EXPECTED_FLUTTER_VERSION" ]] || {
  echo "Flutter 版本不一致：要求 ${EXPECTED_FLUTTER_VERSION}，实际 ${ACTUAL_FLUTTER_VERSION:-未安装}" >&2
  exit 1
}

# iOS 与 Android 使用独立中央缓存。中间产物保留，最终候选包每轮必须重新生成。
clean_platform_build_outputs() {
  case "$PLATFORM" in
    ios) rm -rf "$BUILD_DIR/ios/iphoneos/Runner.app" ;;
    android) rm -f "$BUILD_DIR/app/outputs/flutter-apk/"*.apk ;;
  esac
  mkdir -p "$BUILD_DIR"
}

# iOS 的 Runner.app 已由系统签名并经设备安装回读验证；成功后只覆盖固定 `ios.app.zip`。
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
  local signed_apns_environment profile_apns_environment profile_path

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
  if ! signed_apns_environment="$(
    codesign -d --entitlements :- "$app_bundle" 2>/dev/null |
      plutil -extract aps-environment raw -o - -
  )"; then
    echo "iOS App 最终签名缺少有效 aps-environment，拒绝安装" >&2
    return 1
  fi
  [[ "$signed_apns_environment" == development || "$signed_apns_environment" == production ]] || {
    echo "iOS App 最终签名包含未知 aps-environment：$signed_apns_environment" >&2
    return 1
  }
  profile_path="$app_bundle/embedded.mobileprovision"
  if [[ -f "$profile_path" ]]; then
    if ! profile_apns_environment="$(
      security cms -D -i "$profile_path" 2>/dev/null |
        plutil -extract Entitlements.aps-environment raw -o - -
    )"; then
      echo "iOS provisioning profile 缺少有效 aps-environment，拒绝安装" >&2
      return 1
    fi
    [[ "$profile_apns_environment" == development || "$profile_apns_environment" == production ]] || {
      echo "iOS provisioning profile 包含未知 aps-environment：$profile_apns_environment" >&2
      return 1
    }
    [[ "$profile_apns_environment" == "$signed_apns_environment" ]] || {
      echo "iOS provisioning profile 与最终签名的 APNs 环境不一致，拒绝安装" >&2
      return 1
    }
  elif [[ "$signed_apns_environment" != production ]]; then
    echo "无 provisioning profile 的 iOS App 只能使用 production APNs 环境" >&2
    return 1
  fi

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
  echo "    iOS 原位覆盖完成：Bundle ID=${expected_bundle_id}，Team ID=${team_id}，APNs=${signed_apns_environment}，钱包数据库已保留"
}

# 系统权限弹窗由操作系统渲染；App 唯一能提供的是最终包内的受支持语言和本地化产品名。
# 只检查源码会漏掉 Xcode variant group 未入 Resources 等问题，本机安装必须回读最终包。
verify_ios_release_localization() {
  local app_bundle="$1" info="$1/Info.plist"
  local zh_strings="$1/zh-Hans.lproj/InfoPlist.strings"
  local en_strings="$1/en.lproj/InfoPlist.strings"
  [[ -f "$info" && -f "$zh_strings" && -f "$en_strings" ]] || {
    echo "iOS Release 缺少 Info.plist 或中英文本地化资源：$app_bundle" >&2
    return 1
  }
  [[ "$(plutil -extract CFBundleDevelopmentRegion raw -o - "$info")" == zh-Hans ]] || {
    echo 'iOS Release 默认回落语言必须是 zh-Hans' >&2
    return 1
  }
  plutil -extract CFBundleLocalizations json -o - "$info" | python3 -c '
import json, sys
if json.load(sys.stdin) != ["zh-Hans", "en"]:
    raise SystemExit("iOS Release 支持语言必须严格为 zh-Hans、en")
'
  [[ "$(plutil -extract CFBundleDisplayName raw -o - "$zh_strings")" == 公民 \
    && "$(plutil -extract CFBundleName raw -o - "$zh_strings")" == 公民 ]] || {
    echo 'iOS Release 中文产品名必须是“公民”' >&2
    return 1
  }
  [[ "$(plutil -extract CFBundleDisplayName raw -o - "$en_strings")" == CitizenApp \
    && "$(plutil -extract CFBundleName raw -o - "$en_strings")" == CitizenApp ]] || {
    echo 'iOS Release 英文产品名必须是 CitizenApp' >&2
    return 1
  }
  echo '    iOS Release 本地化通过：中文=公民，英文=CitizenApp，默认回落=zh-Hans'
}

# Android 权限正文由系统按手机语言渲染；这里锁定最终 APK 的默认中文和英文限定应用名。
verify_android_release_localization() {
  local apk="$1" aapt_bin sdk_home
  [[ -f "$apk" ]] || { echo "Android Release APK 不存在：$apk" >&2; return 1; }
  aapt_bin="$(command -v aapt2 || true)"
  if [[ -z "$aapt_bin" ]]; then
    # ProgramConsole 只向子进程传公开工具链环境，不依赖启动它的桌面进程恰好继承
    # ANDROID_HOME。与原生库构建保持同一确定性规则：显式 SDK 优先，macOS 默认
    # SDK 目录兜底，再从已安装 build-tools 中选择最高版本，禁止硬编码具体版本。
    sdk_home="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
    aapt_bin="$(find "$sdk_home/build-tools" -type f -name aapt2 -print 2>/dev/null | sort -V | tail -n 1)"
  fi
  [[ -x "$aapt_bin" ]] || { echo '找不到 Android SDK aapt2，无法核验 APK 本地化' >&2; return 1; }
  "$aapt_bin" dump resources "$apk" | python3 -c '
import re, sys
text = sys.stdin.read()
match = re.search(r"resource 0x[0-9a-f]+ string/app_name\n(?P<body>(?:      .*\n)+?)    resource ", text)
if match is None:
    raise SystemExit("Android Release APK 缺少 string/app_name")
body = match.group("body")
if "() \"公民\"" not in body or "(en) \"CitizenApp\"" not in body:
    raise SystemExit("Android Release APK 的默认中文或英文应用名不正确")
'
  echo '    Android Release 本地化通过：默认=公民，英文=CitizenApp'
}

if [[ "$PLATFORM" == verify-ios-localization ]]; then
  verify_ios_release_localization "${2:?缺少 Runner.app 路径}"
  exit 0
fi
if [[ "$PLATFORM" == verify-android-localization ]]; then
  verify_android_release_localization "${2:?缺少 APK 路径}"
  exit 0
fi


# 构造 dart-define 参数
DART_DEFINES=()
echo "[启动模式] smoldot 轻节点 · 目标平台 $PLATFORM"

# ── chainspec.json 是从链端 plain SSOT + 创世状态包派生的轻节点创世 ──
# 节点 SSOT = citizenchain/node/chainspecs/citizenchain.plain.json;App 资产只保留
# genesis.stateRootHash 轻形态。正式创世请先跑 citizenchain/scripts/bake-chainspec.sh
# 同步 plain SSOT、App 轻形态和 genesis-state;runtime 升级走链上 system.setCode。
# 可执行冻结契约由 check-chainspec-frozen.sh 负责。
bash "$SCRIPT_DIR/check-chainspec-frozen.sh"

# 这里曾有一句 `pkill -9 -f flutter_tools.snapshot`，用途是清掉上一轮残留的 flutter。
# 已删除：`-f` 匹配全命令行，而 `flutter_tools.snapshot` 是每一个 flutter 命令的实际执行体，
# 那一枪不区分产品、不区分平台、也不区分是不是本次运行的——公民钱包正在跑的编译、
# 乃至你自己在终端里手敲的 flutter，都会一起被 SIGKILL（现象是 `Killed: 9`）。
# 它要解决的残留问题已经由编程控制台承接：所有动作子进程都在独立进程组里启动，
# 「停止」与编程控制台退出都按进程组终止整棵进程树，不会再留下脱缰的 flutter。

# Rust 的 iOS、Android 与宿主产物分别位于不同 target 子目录。禁止设备构建执行根级
# `cargo clean` 或产品级等待；Cargo 自身负责并发依赖锁，最终平台库也复制到不同目录。
echo "==> 编译 Rust 原生库（${PLATFORM}）..."
"$SCRIPT_DIR/build-smoldot-native.sh" "$PLATFORM"
# iOS 的 ChatSDK 已由 libsmoldot.a 在 Rust 层统一承载，避免同一 Runner 链接两套
# Rust runtime；Android 的两个 .so 拥有独立链接空间，继续分别构建和装载。
if [[ "$PLATFORM" == android ]]; then
  "$SCRIPT_DIR/../../chatsdk/scripts/build-native.sh" android
fi

echo "==> 清理 ${PLATFORM} 平台构建产物..."
clean_platform_build_outputs
echo "==> 获取依赖..."
flutter pub get

# iOS 在脚本内挑选设备并把 id 显式传给系统安装命令；Android 的设备选择、签名证书
# 比对与覆盖安装全部归原生安全进程，脚本不得取得 APP_KEY 或自行调用 adb 安装。
# 不传设备 id 时 flutter 自己挑：同时连着安卓机和 iPhone 就无从决定，而编程控制台日志面板
# 没有输入框，它的选择提示在那里根本回答不了。挑不到就报错退出，绝不改编另一端。
# `flutter devices --machine` 内部会调 `adb devices`，万一 adb 异常会永久阻塞，
# 故用 perl alarm 包 60s 超时（macOS 自带 perl，无 GNU `timeout`）。
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
# 一律 build + install，不用 `flutter run`（它只把 App 挂在调试器上跑）：
#
# - `--release` 只是 Flutter 的本机优化配置，不表示或触发项目的 Release 流程。
# - iOS 必须使用该优化配置。iOS 14+ 禁止 Flutter debug 版脱离 flutter tooling / Xcode 启动;
#   debug 版装进手机后从桌面点图标必然起不来(系统提示 "Cannot create a FlutterEngine
#   instance in debug mode",随后 signal 11)——表现就是"一点就闪退"。
#   iOS 安装直接走 `devicectl device install app`:它接受 flutter 返回的硬件 UDID，
#   且不会先卸载旧 App；`flutter install` 默认先卸载，会删除钱包数据，永久禁用。
# - Android 同样构建本机优化包。Gradle 输出无私钥候选；脚本退出后由原生安全进程使用
#   Data Protection Keychain 内的固定本机开发证书签名，证书一致才保留数据覆盖安装。
echo "==> 编译本机优化安装包..."
if [[ "$PLATFORM" == ios ]]; then
  flutter build ios --release ${DART_DEFINES[@]+"${DART_DEFINES[@]}"}
  IOS_APP="$BUILD_DIR/ios/iphoneos/Runner.app"
  "$SCRIPT_DIR/build-smoldot-native.sh" verify-ios-package "$IOS_APP"
  verify_ios_release_localization "$IOS_APP"
  install_ios_update "$DEVICE_ID" ios.citizenapp "$IOS_APP" citizenapp.isar
  retain_ios_local_artifact "$IOS_APP"
  echo ""
  echo "==> 安装完成:请在设备桌面点开「公民」。"
elif [[ "$PLATFORM" == android ]]; then
  ANDROID_APK="$BUILD_DIR/app/outputs/flutter-apk/app-release.apk"
  # Flutter 27 的 Android 包定位器仍可能只检查产品默认 build/，即使 Gradle 已按
  # PROGRAM_CONSOLE_BUILD_DIR 把唯一 Release APK 写入中央目录。只允许用这个准确中央产物
  # 收口该工具误报；Gradle 未产出时保持失败，禁止搜索猜测或复制回源码目录。
  if ! flutter build apk --release --target-platform android-arm64 \
    ${DART_DEFINES[@]+"${DART_DEFINES[@]}"}; then
    [[ -f "$ANDROID_APK" ]] || {
      echo "Android Gradle 未产出中央无私钥 APK" >&2
      exit 1
    }
    echo "==> Flutter 未识别中央 APK，已按唯一固定路径接管 Gradle 成功产物。"
  fi
  [[ -f "$ANDROID_APK" ]] || {
    echo "Android 本机无私钥 APK 不存在" >&2
    exit 1
  }
  "$SCRIPT_DIR/build-smoldot-native.sh" verify-android-package "$ANDROID_APK"
  verify_android_release_localization "$ANDROID_APK"
  echo "==> Android 本机候选完成，正在交给原生安全进程做本机开发签名并安装。"
fi
