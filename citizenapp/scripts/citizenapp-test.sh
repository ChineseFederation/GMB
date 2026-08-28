#!/usr/bin/env bash
# CitizenApp 本机与 CI 唯一 Flutter 测试入口。
#
# flutter_tester 是宿主进程，不会链接 iOS Runner 的 libsmoldot.a，也不会使用
# Android APK 内的 libsmoldot.so。任何 Dart FFI 测试开始前，必须先构建并验收
# 当前宿主的 libsmoldot.dylib/so；随后才允许 analyze 和顺序执行测试。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CITIZENAPP_DIR="$(dirname "$SCRIPT_DIR")"
REPO_ROOT="$(dirname "$CITIZENAPP_DIR")"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"

if [[ "${CI:-}" != true && "${GMB_CENTRAL_SNAPSHOT:-}" != 1 ]]; then
  CONSOLE_TARGET_ROOT="${CONSOLE_TARGET_ROOT:-/Users/rhett/Only/console/target}"
  CONSOLE_WORK_DIR="$CONSOLE_TARGET_ROOT/.work/citizenapp-test"
  helper=/Users/rhett/Only/console/actions/local-build.sh
  [[ -f "$helper" && "$CONSOLE_WORK_DIR" == /Users/rhett/Only/console/target/.work/citizenapp-test ]] \
    || { echo '本机CitizenApp测试缺少Console中央快照入口' >&2; exit 1; }
  /usr/bin/find "$CONSOLE_WORK_DIR" -depth -delete 2>/dev/null || true
  mkdir -p "$CONSOLE_WORK_DIR"
  export CONSOLE_TARGET_ROOT CONSOLE_WORK_DIR
  # shellcheck disable=SC1090
  source "$helper"
  snapshot_root="$(stage_gmb_mobile_source "$REPO_ROOT" citizenapp)"
  # CitizenApp 的跨产品契约测试直接读取链端 SCALE 金标和 CitizenServe 推送实现，
  # 不在应用目录保存镜像副本。中央快照必须携带这些只读真源，避免本机测试因
  # 快照缺文件而失败，同时继续保证测试读取的是本次仓库源码而非过期复制品。
  snapshot_truth_sources=(
    citizenchain/runtime/primitives/tests/fixtures/scale_codec_vectors.json
    citizenchain/runtime/tests/fixtures/role_permission.json
    citizenserve/src/chat/push.ts
  )
  for relative_path in "${snapshot_truth_sources[@]}"; do
    source_path="$REPO_ROOT/$relative_path"
    snapshot_path="$snapshot_root/$relative_path"
    [[ -f "$source_path" ]] \
      || { echo "CitizenApp测试真源缺失：$source_path" >&2; exit 1; }
    mkdir -p "$(dirname "$snapshot_path")"
    /usr/bin/ditto "$source_path" "$snapshot_path"
  done
  cleanup_snapshot() {
    /usr/bin/find "$CONSOLE_WORK_DIR" -depth -delete 2>/dev/null || true
    rmdir "$CONSOLE_TARGET_ROOT/.work" 2>/dev/null || true
  }
  trap cleanup_snapshot EXIT INT TERM HUP
  GMB_CENTRAL_SNAPSHOT=1 CONSOLE_TARGET_ROOT="$CONSOLE_TARGET_ROOT" \
    CONSOLE_WORK_DIR="$CONSOLE_WORK_DIR" \
    bash "$snapshot_root/citizenapp/scripts/citizenapp-test.sh" "$@"
  exit $?
fi

if [[ "${CI:-}" != true ]]; then
  [[ "$CITIZENAPP_DIR" == "$CONSOLE_WORK_DIR/source/GMB/citizenapp" ]] \
    || { echo "CitizenApp本机测试源码不在Console中央快照：$CITIZENAPP_DIR" >&2; exit 1; }
fi

if ! command -v "$FLUTTER_BIN" >/dev/null 2>&1; then
  echo "错误: 找不到 Flutter: $FLUTTER_BIN" >&2
  exit 1
fi

EXPECTED_FLUTTER_VERSION="$(
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["toolchains"]["flutter"])' \
    "$REPO_ROOT/.github/dependencies.json"
)"
ACTUAL_FLUTTER_VERSION="$(
  "$FLUTTER_BIN" --version --machine \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["frameworkVersion"])'
)"
if [ "$ACTUAL_FLUTTER_VERSION" != "$EXPECTED_FLUTTER_VERSION" ]; then
  echo "错误: Flutter 版本为 $ACTUAL_FLUTTER_VERSION，仓库要求 $EXPECTED_FLUTTER_VERSION" >&2
  exit 1
fi

if [ ! -f "$CITIZENAPP_DIR/.dart_tool/package_config.json" ]; then
  if [[ "${CI:-}" == true ]]; then
    echo "错误: 缺少 .dart_tool/package_config.json；CI必须先执行锁定依赖解析" >&2
    exit 1
  fi
  (cd "$CITIZENAPP_DIR" && "$FLUTTER_BIN" pub get --enforce-lockfile)
fi

# 设备 Release 构建会先 cargo clean；测试必须从宿主库构建开始一直持锁到最后一个
# flutter_tester 退出，禁止其它进程在测试中途删除 dylib/so。macOS 用系统 shlock
# 自动识别死亡 PID，Linux CI 用 util-linux flock，二者都不依赖仓库内状态文件。
NATIVE_BUILD_LOCK_PATH="${TMPDIR:-/tmp}/gmb-citizenapp-native-build.lock"
NATIVE_BUILD_LOCK_KIND=""
acquire_native_build_lock() {
  case "$(uname -s)" in
    Darwin)
      while ! shlock -f "$NATIVE_BUILD_LOCK_PATH" -p $$; do
        echo "等待 CitizenApp 设备原生构建结束..."
        sleep 1
      done
      NATIVE_BUILD_LOCK_KIND=shlock
      ;;
    Linux)
      exec 9>"$NATIVE_BUILD_LOCK_PATH"
      flock 9
      NATIVE_BUILD_LOCK_KIND=flock
      ;;
    *)
      echo "错误: 不支持的原生测试锁平台：$(uname -s)" >&2
      return 1
      ;;
  esac
}
release_native_build_lock() {
  case "$NATIVE_BUILD_LOCK_KIND" in
    shlock)
      if [[ "$(cat "$NATIVE_BUILD_LOCK_PATH" 2>/dev/null || true)" == "$$" ]]; then
        rm -f -- "$NATIVE_BUILD_LOCK_PATH"
      fi
      ;;
    flock)
      flock -u 9
      exec 9>&-
      ;;
  esac
  NATIVE_BUILD_LOCK_KIND=""
}

cd "$CITIZENAPP_DIR"
acquire_native_build_lock
trap release_native_build_lock EXIT
"$SCRIPT_DIR/build-smoldot-native.sh" host
"$FLUTTER_BIN" analyze --no-pub
"$FLUTTER_BIN" test --no-pub --concurrency=1 "$@"
