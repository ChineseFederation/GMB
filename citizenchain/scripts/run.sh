#!/usr/bin/env bash
# CitizenConsole 本机产品启动入口:只构建并运行 Release，不清库，继续使用
# 【冻结 SSOT】(node/chainspecs/citizenchain.plain.json)续跑现有开发数据。
# 单元测试和开发者手工 Debug 不走本入口；需要清理开发数据或 fresh 链时改用 clean-run.sh。
#
# 启动后:节点自动挖矿;链上中国平台需在节点设置页手动启动,统一入口 https://onchina.local:8964。
# 平台登录与节点启动**解耦**:本机构管理员用冷钱包扫码、对链上 Active 管理员集合
# 鉴权(3b)即可登录;不是本机构管理员就不用管,也没有任何机构权限。
set -euo pipefail

MACOS_APP_BUNDLE=''
MACOS_APP_PENDING=0

cleanup() {
    # 只清理本轮尚未通过完整签名验收的固定 App；历史成功归档和用户数据均不触碰。
    if [[ "${MACOS_APP_PENDING:-0}" == 1 \
        && -n "${TARGET_DIR:-}" \
        && "${MACOS_APP_BUNDLE:-}" == "$TARGET_DIR/release/bundle/macos/citizenchain.app" ]]; then
        rm -rf -- "$MACOS_APP_BUNDLE"
    fi
    echo ""
    echo "==> 正在关闭节点 + 链上中国平台 + 内嵌 PG..."
    pkill -f "citizenchain" 2>/dev/null || true
    pkill -f "target/release/onchina" 2>/dev/null || true
    lsof -ti:5173 2>/dev/null | xargs kill -9 2>/dev/null || true
    if [ -n "${ONCHINA_PG_BIN_DIR:-}" ] && [ -n "${ONCHINA_PG_DATA_DIR:-}" ] && [ -d "${ONCHINA_PG_DATA_DIR:-}" ]; then
        "$ONCHINA_PG_BIN_DIR/pg_ctl" stop -D "$ONCHINA_PG_DATA_DIR" -m fast >/dev/null 2>&1 || true
    fi
    sleep 1
    echo "    已关闭"
}
trap cleanup EXIT INT TERM HUP

# macOS 产品 App 只接受今后唯一的新团队 Developer ID；禁止按枚举顺序选证书，
# 否则 Apple Development 或其它团队身份可能被静默当成控制台运行软件的签名。
MACOS_SIGNING_IDENTITY='Developer ID Application: WEI CHENG (MHYMVRN6FC)'
MACOS_TEAM_ID='MHYMVRN6FC'
MACOS_BUNDLE_ID='macOS.citizenappchain'
MACOS_APPLICATION_ID="${MACOS_TEAM_ID}.${MACOS_BUNDLE_ID}"
MACOS_PROFILE_NAME='CitizenChain Developer ID'
MACOS_PROFILE_DIR="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"

require_macos_signing_identity() {
    /usr/bin/security find-identity -v -p codesigning 2>/dev/null \
        | grep -F "\"$MACOS_SIGNING_IDENTITY\"" >/dev/null
}

# Apple 安全时间戳服务偶发不可用时只重试签名相关步骤。错误不属于该服务、
# 或三次重试仍失败时立即关闭，不允许改用无时间戳、临时签名等降级路径。
MACOS_TIMESTAMP_RETRY_DELAYS=(2 5 10)

is_macos_timestamp_service_failure() {
    local output="$1"
    [[ "$output" == *"A timestamp was expected but was not found"* \
        || "$output" == *"The timestamp service is not available"* \
        || "$output" == *"timestamp service is not available"* ]]
}

run_with_macos_timestamp_retry() {
    local action="$1"
    shift
    local output='' status=0 retry=0 delay
    while true; do
        set +e
        output="$("$@" 2>&1)"
        status=$?
        set -e
        [[ -z "$output" ]] || printf '%s\n' "$output"
        [[ "$status" == 0 ]] && return 0
        is_macos_timestamp_service_failure "$output" || return "$status"
        if (( retry >= ${#MACOS_TIMESTAMP_RETRY_DELAYS[@]} )); then
            echo "    [error] $action 因 Apple 安全时间戳服务异常连续重试三次后仍失败" >&2
            return "$status"
        fi
        delay="${MACOS_TIMESTAMP_RETRY_DELAYS[$retry]}"
        retry=$((retry + 1))
        echo "    [warn] $action 未取得 Apple 安全时间戳，${delay} 秒后执行第 $retry 次重试" >&2
        sleep "$delay"
    done
}

# Apple 重新签发描述文件会改变 UUID，因此禁止绑定文件名。只允许唯一一个同时匹配
# 产品名、Team ID 和公民链 App ID 的 Developer ID 描述文件，重复或旧标识均失败关闭。
resolve_macos_profile() {
    local candidate profile_name application_id team_id matched='' matched_count=0
    shopt -s nullglob
    for candidate in "$MACOS_PROFILE_DIR"/*.provisionprofile "$MACOS_PROFILE_DIR"/*.mobileprovision; do
        profile_name="$(security cms -D -i "$candidate" 2>/dev/null \
            | plutil -extract Name raw -o - - 2>/dev/null || true)"
        application_id="$(security cms -D -i "$candidate" 2>/dev/null \
            | plutil -extract 'Entitlements.com\.apple\.application-identifier' raw -o - - 2>/dev/null || true)"
        team_id="$(security cms -D -i "$candidate" 2>/dev/null \
            | plutil -extract 'Entitlements.com\.apple\.developer\.team-identifier' raw -o - - 2>/dev/null || true)"
        if [[ "$profile_name" == "$MACOS_PROFILE_NAME" \
            && "$application_id" == "$MACOS_APPLICATION_ID" \
            && "$team_id" == "$MACOS_TEAM_ID" ]]; then
            matched="$candidate"
            matched_count=$((matched_count + 1))
        fi
    done
    shopt -u nullglob
    [[ "$matched_count" == 1 ]] || {
        echo "    [error] 必须且只能安装一个匹配 $MACOS_BUNDLE_ID 的 $MACOS_PROFILE_NAME" >&2
        return 1
    }
    printf '%s\n' "$matched"
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"   # citizenchain/
GMB_REPOSITORY_ROOT="$(dirname "$REPO_ROOT")"
TARGET_DIR="$REPO_ROOT/target"
GENESIS_STATE_RESOURCE_DIR="$REPO_ROOT/node/resources/genesis-state"

# 与 CI/Release 共用 .github/dependencies.json 的精确 Node.js 版本和 npm lockfile。
# 必须 source，使 prepare-toolchain.sh 通过 nvm 选择的 Node.js 留在本进程中。
source "$GMB_REPOSITORY_ROOT/scripts/prepare-toolchain.sh"

# 本地启动脚本只使用当前源码构建 runtime WASM。
# runtime 正式升级走链上 setCode，桌面端启动不再从 GitHub CI 下载 wasm 产物。
unset WASM_FILE
# Release 是控制台运行的软件构建类型；gmb.dev 是本机开发数据隔离环境，两者彼此独立。
# 本任务不迁移、不删除正式 gmb 数据，也不让控制台启动的软件争用正式安装版 RocksDB。
export CITIZENCHAIN_DATA_PROFILE=dev
mkdir -p "$TARGET_DIR" "$GENESIS_STATE_RESOURCE_DIR"

# ── OnChina 控制台本机配置 ──
# 启动节点不需要任何机构鉴权/身份。这里只让本机能跑起链上中国平台服务:
#   ① 构建 onchina 二进制(节点同目录,设置页手动启动时由 onchina_proc 拉起)+ 前端产物;
#   ② DB 用内嵌私有 PG(方案 A):借本机 PostgreSQL 二进制起一个 onchina 专属实例(127.0.0.1)。
# 本机构的"系统签名钥 / 机构身份"是可选配置(签登录 QR / 签发凭证才需要),非启动前提。
echo "==> 构建 OnChina Release 二进制 + 前端..."
( cd "$REPO_ROOT" && CARGO_INCREMENTAL=0 cargo build --release -p onchina )
echo "==> 构建链上中国平台前端产物..."
( cd "$REPO_ROOT/onchina/frontend" && npm run build )
PG_PREFIX=""
for v in postgresql@17 postgresql@16 postgresql@15 postgresql; do
    if p="$(brew --prefix "$v" 2>/dev/null)" && [ -x "$p/bin/initdb" ]; then PG_PREFIX="$p"; break; fi
done
if [ -n "$PG_PREFIX" ]; then
    export ONCHINA_EMBEDDED_PG=1
    export ONCHINA_PG_BIN_DIR="$PG_PREFIX/bin"
    export ONCHINA_PG_PORT="${ONCHINA_PG_PORT:-5433}"
    export ONCHINA_PG_DATA_DIR="$HOME/Library/Application Support/gmb.dev/onchina-pgdata"
    echo "    内嵌私有 PG:$ONCHINA_PG_BIN_DIR(端口 $ONCHINA_PG_PORT)"
else
    echo "    [warn] 未找到本机 PostgreSQL(brew install postgresql@16);链上中国平台仍可起但缺 DB,功能受限。"
fi
export ONCHINA_CHINA_DB="$REPO_ROOT/onchina/src/cid/china/china.sqlite"
export ONCHINA_FRONTEND_DIST="$REPO_ROOT/onchina/frontend/dist"
export ONCHINA_ENABLE_TLS=1
export ONCHINA_TLS_DIR="$HOME/Library/Application Support/gmb.dev/onchina-tls"
# 公权机构目录只允许从链上投影到本地缓存;开发启动不再打开旧本地生成开关。
# 链不可达或投影不可读时,链上中国按 fail-closed 不放行平台服务。
# OnChina 后端不再持有任何链上签名钥:机构操作全部由管理员冷钱包直接冷签,
# 原平台签名钥与注销凭证签发配置已随注销凭证链路整体删除。

echo "==> 使用本地源码构建 runtime WASM，不下载 GitHub CI WASM..."
echo "    节点启动产物目录: $TARGET_DIR"
echo "    Release 运行数据目录: $HOME/Library/Application Support/gmb.dev"
echo "==> 链上中国平台:节点设置页点击「启动」后访问 https://onchina.local:8964"

# ── 启动 ──
cd "$REPO_ROOT/node"
echo "==> 启动公民链..."
if [[ "$(uname -s)" == "Darwin" ]]; then
    require_macos_signing_identity || {
        echo "    [error] 未找到唯一允许的新团队 Developer ID：$MACOS_SIGNING_IDENTITY" >&2
        exit 1
    }
    export APPLE_SIGNING_IDENTITY="$MACOS_SIGNING_IDENTITY"
    macos_profile="$(resolve_macos_profile)"
    echo "    使用新团队 Developer ID 构建带摄像头权限的 Release App"
    # 使用 frontend/package-lock.json 固定的仓库 CLI；禁止回退到本机全局 cargo-tauri 造成版本漂移。
    app_bundle="$TARGET_DIR/release/bundle/macos/citizenchain.app"
    MACOS_APP_BUNDLE="$app_bundle"
    # Tauri 2 的 build 默认且唯一正式模式就是 Release；--debug 才会切换为开发产物。
    # 编译与封装分离，时间戳瞬时失败时只重试封装签名，不重复整轮 Rust 编译。
    CARGO_INCREMENTAL=0 node frontend/node_modules/@tauri-apps/cli/tauri.js build --no-bundle --ci -- --locked
    MACOS_APP_PENDING=1
    bundle_macos_app() {
        rm -rf -- "$app_bundle"
        CARGO_INCREMENTAL=0 node frontend/node_modules/@tauri-apps/cli/tauri.js bundle --bundles app --ci
    }
    run_with_macos_timestamp_retry "Tauri App 封装签名" bundle_macos_app

    app_plist="$app_bundle/Contents/Info.plist"
    app_executable="$app_bundle/Contents/MacOS/citizenchain"
    [[ -x "$app_executable" ]] || {
        echo "    [error] Tauri 构建完成但缺少 App 主程序：$app_executable" >&2
        exit 1
    }
    # Tauri 负责生成产品 App；描述文件属于本机正式材料，绝不进入仓库或 GitHub 候选。
    # 嵌入后必须重新封签根 App，使描述文件、唯一 App ID 与权限成为同一个签名整体。
    /usr/bin/ditto "$macos_profile" "$app_bundle/Contents/embedded.provisionprofile"
    run_with_macos_timestamp_retry "描述文件嵌入后的 App 封签" \
        /usr/bin/codesign --force --deep --options runtime --timestamp \
        --entitlements "$REPO_ROOT/node/Entitlements.plist" \
        --sign "$MACOS_SIGNING_IDENTITY" "$app_bundle"
    codesign --verify --deep --strict "$app_bundle"
    signature_details="$(codesign -dv --verbose=4 "$app_bundle" 2>&1)"
    grep -Fqx "Authority=$MACOS_SIGNING_IDENTITY" <<<"$signature_details" || {
        echo "    [error] macOS App 未使用唯一允许的新团队 Developer ID" >&2
        exit 1
    }
    grep -Fqx "TeamIdentifier=$MACOS_TEAM_ID" <<<"$signature_details" || {
        echo "    [error] macOS App Team ID 不属于唯一允许的新团队" >&2
        exit 1
    }
    grep -Eq '^CodeDirectory .*flags=.*\(runtime\)' <<<"$signature_details" || {
        echo "    [error] macOS App 未启用 Hardened Runtime" >&2
        exit 1
    }
    grep -Eq '^Timestamp=' <<<"$signature_details" || {
        echo "    [error] macOS App 缺少安全时间戳" >&2
        exit 1
    }
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_plist")" == "$MACOS_BUNDLE_ID" ]] || {
        echo "    [error] macOS App Bundle ID 与 Tauri 配置不一致" >&2
        exit 1
    }
    embedded_profile_name="$(security cms -D -i "$app_bundle/Contents/embedded.provisionprofile" 2>/dev/null \
        | plutil -extract Name raw -o - - 2>/dev/null || true)"
    [[ "$embedded_profile_name" == "$MACOS_PROFILE_NAME" ]] || {
        echo "    [error] macOS App 未嵌入 $MACOS_PROFILE_NAME" >&2
        exit 1
    }
    /usr/libexec/PlistBuddy -c 'Print :NSCameraUsageDescription' "$app_plist" >/dev/null
    signed_entitlements="$(codesign -d --entitlements :- "$app_bundle" 2>/dev/null)"
    for entitlement in \
        com.apple.security.device.camera \
        com.apple.security.cs.allow-jit \
        com.apple.security.cs.allow-unsigned-executable-memory; do
        # plutil 把点号解释为字典层级；entitlement 名本身含点号，必须先转义为单个键。
        entitlement_key_path="${entitlement//./\\.}"
        [[ "$(printf '%s' "$signed_entitlements" | plutil -extract "$entitlement_key_path" raw -)" == "true" ]] || {
            echo "    [error] macOS App 签名缺少 $entitlement" >&2
            exit 1
        }
    done
    get_task_allow="$(printf '%s' "$signed_entitlements" \
        | plutil -extract 'com\.apple\.security\.get-task-allow' raw - 2>/dev/null \
        || printf 'false')"
    [[ "$get_task_allow" == "false" ]] || {
        echo "    [error] macOS Release App 禁止 get-task-allow" >&2
        exit 1
    }
    MACOS_APP_PENDING=0
    echo "    Release 路径、新团队签名、Bundle ID、Hardened Runtime、安全时间戳与 entitlement 校验通过"
    # Build 成功产物只进入 citizenchain 唯一 target/ 根；按完成时间保留最近两份。
    # 先写同卷 staging，完整压缩成功后再原子改名，任何失败都不形成成功代际。
    local_artifact_root="$TARGET_DIR/local-artifacts/macos"
    local_artifact_generation="$(date -u +%Y%m%dT%H%M%SZ)-$$"
    local_artifact_staging="$local_artifact_root/.staging-$local_artifact_generation"
    local_artifact_destination="$local_artifact_root/$local_artifact_generation"
    mkdir -p "$local_artifact_staging"
    if ! ditto -c -k --sequesterRsrc --keepParent \
        "$app_bundle" "$local_artifact_staging/CitizenChain.app.zip"; then
        rm -rf "$local_artifact_staging"
        echo "    [error] CitizenChain 本机成功产物归档失败" >&2
        exit 1
    fi
    mv "$local_artifact_staging" "$local_artifact_destination"
    find "$local_artifact_root" -mindepth 1 -maxdepth 1 -type d -name '20*' -exec basename {} \; \
        | sort -r | tail -n +3 | while IFS= read -r old; do rm -rf "${local_artifact_root:?}/$old"; done
    # 不重定向 LaunchServices 的标准流：桌面会话下把 /dev/stdout、/dev/stderr 作为目标路径
    # 会触发 LS -10810，导致已正确签名的 App 根本无法启动。
    open_args=(-n)
    for name in \
        CITIZENCHAIN_DATA_PROFILE \
        ONCHINA_EMBEDDED_PG ONCHINA_PG_BIN_DIR ONCHINA_PG_PORT ONCHINA_PG_DATA_DIR \
        ONCHINA_CHINA_DB ONCHINA_FRONTEND_DIST ONCHINA_ENABLE_TLS ONCHINA_TLS_DIR; do
        [[ -z "${!name:-}" ]] || open_args+=(--env "$name=${!name}")
    done
    # LaunchServices 让 TCC 以 macOS.citizenappchain 识别请求方；编译任务只负责确认
    # App 进程和 RPC 已就绪，不继续占用 CitizenConsole 标签跟踪节点生命周期。
    open "${open_args[@]}" "$app_bundle"
    node_health=''
    node_ready=0
    for _ in {1..60}; do
        if pgrep -f "$app_executable" >/dev/null 2>&1; then
            node_health="$(curl --silent --max-time 2 \
                -H 'content-type: application/json' \
                --data '{"id":1,"jsonrpc":"2.0","method":"system_health","params":[]}' \
                http://127.0.0.1:9944 2>/dev/null || true)"
            if grep -Eq '"result"[[:space:]]*:[[:space:]]*\{' <<<"$node_health"; then
                node_ready=1
                break
            fi
        fi
        sleep 1
    done
    [[ "$node_ready" == 1 ]] || {
        echo "    [error] CitizenChain App 已打开，但进程或 RPC 未在 60 秒内就绪" >&2
        exit 1
    }
    # 节点已由 LaunchServices 独立托管；此后脚本正常退出不得触发失败路径的进程清理。
    trap - EXIT INT TERM HUP
    echo "    节点启动验证通过，CitizenConsole 编译任务结束"
else
    echo "    [error] CitizenConsole 本机产品启动入口只支持 macOS；其它平台请使用正式安装包" >&2
    exit 1
fi
