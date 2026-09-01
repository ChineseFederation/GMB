#!/usr/bin/env bash
# 清理目标平台缓存并生成本机优化安装包；本脚本不启动、不安装产品。
#
# 用法：citizenapp-run.sh <ios|android>
# 只读包检查：citizenapp-run.sh <verify-ios-localization|verify-android-localization> <产物路径>
#
# 目标平台是必填参数，不做任何自动探测：探测总要在失败时选一个回落，
# 而回落的那一端会被当成用户想编的那一端——「以为编了 iOS、实际编的 Android」
# 就是这么来的。塔塔控制台的「编译iOS端 / 编译Android端」两个按钮各自传死这个参数。
#
# 本机中间文件只允许进入TataConsole中央`.work`，最终成功包覆盖中央产品产物目录中的固定文件。
# 固定使用 smoldot 轻节点连接区块链（无需 RPC 服务器）。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# 消解 scripts/..，确保直接产品源码身份使用唯一真实路径。
APP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PLATFORM="${1:?缺少目标平台，用法：$0 <ios|android>}"
[[ "$PLATFORM" == ios || "$PLATFORM" == android \
  || "$PLATFORM" == verify-ios-localization || "$PLATFORM" == verify-android-localization ]] \
  || { echo "目标平台或检查模式不合法：$PLATFORM" >&2; exit 1; }
cd "$APP_ROOT"

if [[ "$PLATFORM" == ios || "$PLATFORM" == android ]]; then
  : "${TATA_CONSOLE_TARGET_ROOT:?本机编译必须由 TataConsole 提供中央产物目录}"
  : "${TATA_CONSOLE_WORK_DIR:?本机编译必须由 TataConsole 提供中央工作目录}"
  case "$TATA_CONSOLE_WORK_DIR" in "$TATA_CONSOLE_TARGET_ROOT/.work/citizenapp-$PLATFORM") ;; *)
    echo "公民中央工作目录不合法：$TATA_CONSOLE_WORK_DIR" >&2; exit 1 ;;
  esac
  # Flutter会把依赖状态写到当前工程；Build直接读取产品源码，并在退出时清除临时状态。
  [[ "$APP_ROOT" == "$REPO_ROOT/citizenapp" ]] || {
  echo "citizenapp本机Build源码身份无效：$APP_ROOT" >&2
  exit 1

}

CHATSDK_OVERRIDE_PATH="$APP_ROOT/pubspec_overrides.yaml"
PUBSPEC_LOCK_BACKUP="$TATA_CONSOLE_WORK_DIR/citizenapp.pubspec.lock"

prepare_local_chat_sdk_dependency() {
  [[ ! -e "$CHATSDK_OVERRIDE_PATH" ]] || {
    echo "CitizenApp 本机依赖覆盖文件已存在：$CHATSDK_OVERRIDE_PATH" >&2
    exit 1
  }
  cp -p "$APP_ROOT/pubspec.lock" "$PUBSPEC_LOCK_BACKUP"
  # 本机开发只直连当前仓库 ChatSDK；正式源码依赖仍由准确 Git Release Tag 管理。
  cat > "$CHATSDK_OVERRIDE_PATH" <<'YAML'
dependency_overrides:
  gmb_chat_sdk:
    path: ../chatsdk
YAML
}

cleanup_direct_source_state() {
  rm -rf "$APP_ROOT/.dart_tool" "$APP_ROOT/.flutter-plugins" \
    "$APP_ROOT/.flutter-plugins-dependencies" "$APP_ROOT/ios/Pods" \
    "$APP_ROOT/ios/.symlinks" "$APP_ROOT/android/.gradle"
  rm -f "$CHATSDK_OVERRIDE_PATH"
  if [[ -f "$PUBSPEC_LOCK_BACKUP" ]]; then
    cp -p "$PUBSPEC_LOCK_BACKUP" "$APP_ROOT/pubspec.lock"
    rm -f "$PUBSPEC_LOCK_BACKUP"
  fi
  if [[ "$PLATFORM" == ios ]]; then
    rm -f "$REPO_ROOT/chatsdk/ios/ChatSDK.xcframework"
  fi
}
trap 'status=$?; cleanup_direct_source_state; exit "$status"' EXIT
prepare_local_chat_sdk_dependency
fi

INCREMENTAL_CACHE_DIR="${TATA_CONSOLE_INCREMENTAL_CACHE_DIR:?缺少TataConsole本机增量缓存目录}"
[[ "$INCREMENTAL_CACHE_DIR" == "$TATA_CONSOLE_WORK_DIR/cache" ]] || {
  echo "CitizenApp本机增量缓存必须位于$TATA_CONSOLE_WORK_DIR/cache" >&2
  exit 1
}
BUILD_DIR="$INCREMENTAL_CACHE_DIR/flutter-build"
ARTIFACT_ROOT="$TATA_CONSOLE_TARGET_ROOT/citizenapp"
export TATA_CONSOLE_BUILD_DIR="$BUILD_DIR"
export TATA_CONSOLE_NATIVE_ANDROID_DIR="$INCREMENTAL_CACHE_DIR/native/android"
export TATA_CONSOLE_NATIVE_IOS_DIR="$INCREMENTAL_CACHE_DIR/native/ios"
export CARGO_TARGET_DIR="$INCREMENTAL_CACHE_DIR/cargo-target"
export XDG_CONFIG_HOME="$INCREMENTAL_CACHE_DIR/flutter-config"
mkdir -p "$XDG_CONFIG_HOME"
build_dir_relative="$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$BUILD_DIR" "$APP_ROOT")"
flutter config --build-dir="$build_dir_relative" >/dev/null

# iOS 与 Android 使用独立中央缓存。中间产物保留，最终候选包每轮必须重新生成。
clean_platform_build_outputs() {
  case "$PLATFORM" in
    ios) rm -rf "$BUILD_DIR/ios/iphoneos/Runner.app" ;;
    android) rm -f "$BUILD_DIR/app/outputs/flutter-apk/"*.apk ;;
  esac
  mkdir -p "$BUILD_DIR"
}

# iOS Runner.app完成签名后只覆盖固定 `ios.app.zip`。
retain_ios_local_artifact() {
  local app_bundle="$1" staging="$TATA_CONSOLE_WORK_DIR/ios.app.zip" destination="$ARTIFACT_ROOT/ios.app.zip"
  rm -f "$staging"
  ditto -c -k --sequesterRsrc --keepParent "$app_bundle" "$staging"
  mkdir -p "$ARTIFACT_ROOT"
  # 同卷固定名称覆盖保证失败时不先删除上一次成功产物。
  mv -f "$staging" "$destination"
}

# 系统权限弹窗由操作系统渲染；App 唯一能提供的是最终包内的受支持语言和本地化产品名。
# 只检查源码会漏掉 Xcode variant group 未入 Resources 等问题，Build必须回读最终包。
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
    # TataConsole 只向子进程传公开工具链环境，不依赖启动它的桌面进程恰好继承
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
echo "[Build模式] smoldot轻节点 · 目标平台 $PLATFORM"

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
# 它要解决的残留问题已经由塔塔控制台承接：所有动作子进程都在独立进程组里启动，
# 「停止」与塔塔控制台退出都按进程组终止整棵进程树，不会再留下脱缰的 flutter。

# Rust 的 iOS、Android 与宿主产物分别位于不同 target 子目录。禁止设备构建执行根级
# `cargo clean` 或产品级等待；Cargo 自身负责并发依赖锁，最终平台库也复制到不同目录。
echo "==> 编译 Rust 原生库（${PLATFORM}）..."
"$SCRIPT_DIR/build-smoldot-native.sh" "$PLATFORM"
# Smoldot 和 ChatSDK 分别生成自己的原生产物；iOS 由静态 Smoldot Framework 与
# 动态 ChatSDK XCFramework 隔离 Rust runtime，Android 继续使用两个独立 .so。
if [[ "$PLATFORM" == ios ]]; then
  CHATSDK_PACKAGE_IOS_DIR="$REPO_ROOT/chatsdk/ios" \
    "$REPO_ROOT/chatsdk/scripts/build-native.sh" "$PLATFORM"
else
  "$REPO_ROOT/chatsdk/scripts/build-native.sh" "$PLATFORM"
fi

echo "==> 清理 ${PLATFORM} 平台构建产物..."
clean_platform_build_outputs
echo "==> 获取依赖..."
flutter pub get

# Build不选择、不安装、不启动设备，只读取当前产品源码并生成中央产物。
# `--release`只是本机优化配置，不表示或触发正式Release流程。
echo "==> 编译本机优化安装包..."
if [[ "$PLATFORM" == ios ]]; then
  flutter build ios --release ${DART_DEFINES[@]+"${DART_DEFINES[@]}"}
  IOS_APP="$BUILD_DIR/ios/iphoneos/Runner.app"
  "$SCRIPT_DIR/build-smoldot-native.sh" verify-ios-package "$IOS_APP"
  "$REPO_ROOT/chatsdk/scripts/build-native.sh" verify-ios-package "$IOS_APP"
  verify_ios_release_localization "$IOS_APP"
  retain_ios_local_artifact "$IOS_APP"
  echo ""
  echo "==> Build完成：iOS产物已写入TataConsole中央目录。"
elif [[ "$PLATFORM" == android ]]; then
  ANDROID_APK="$BUILD_DIR/app/outputs/flutter-apk/app-release.apk"
  # Flutter 27 的 Android 包定位器仍可能只检查产品默认 build/，即使 Gradle 已按
  # TATA_CONSOLE_BUILD_DIR 把唯一 Release APK 写入中央目录。只允许用这个准确中央产物
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
  "$REPO_ROOT/chatsdk/scripts/build-native.sh" verify-android-package "$ANDROID_APK"
  verify_android_release_localization "$ANDROID_APK"
  echo "==> Android无私钥候选完成，正在交给原生安全进程完成Build签名。"
fi
