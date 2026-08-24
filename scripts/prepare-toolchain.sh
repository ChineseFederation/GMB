#!/usr/bin/env bash
# 本地构建工具链统一入口：版本只读取 .github/dependencies.json，依赖只按 lockfile 安装。
# run.sh / clean-run.sh 必须 source 本脚本，使 nvm 选择的精确 Node.js 版本留在调用进程中。
set -euo pipefail

PREPARE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GMB_REPOSITORY_ROOT="$(dirname "$PREPARE_SCRIPT_DIR")"
DEPENDENCY_CONTRACT="$GMB_REPOSITORY_ROOT/.github/dependencies.json"

[[ -f "$DEPENDENCY_CONTRACT" ]] || {
    echo "[error] 缺少统一依赖真源：$DEPENDENCY_CONTRACT" >&2
    return 1 2>/dev/null || exit 1
}
command -v python3 >/dev/null 2>&1 || {
    echo "[error] 读取统一依赖真源需要 python3" >&2
    return 1 2>/dev/null || exit 1
}

EXPECTED_NODE_VERSION="$(python3 -c \
    'import json, sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["toolchains"]["node"])' \
    "$DEPENDENCY_CONTRACT")"
CURRENT_NODE_VERSION="$(node --version 2>/dev/null | sed 's/^v//' || true)"

if [[ "$CURRENT_NODE_VERSION" != "$EXPECTED_NODE_VERSION" ]]; then
    NODE_VERSION_MANAGER_DIR="${NVM_DIR:-$HOME/.nvm}"
    if [[ ! -s "$NODE_VERSION_MANAGER_DIR/nvm.sh" ]]; then
        echo "[error] 当前 Node.js 为 ${CURRENT_NODE_VERSION:-未安装}，仓库要求 ${EXPECTED_NODE_VERSION}" >&2
        echo "[error] 未找到 nvm：$NODE_VERSION_MANAGER_DIR/nvm.sh" >&2
        return 1 2>/dev/null || exit 1
    fi
    export NVM_DIR="$NODE_VERSION_MANAGER_DIR"
    # nvm 会读取若干可选环境变量；临时关闭 nounset，加载后立即恢复严格模式。
    set +u
    # shellcheck source=/dev/null
    source "$NVM_DIR/nvm.sh"
    nvm install "$EXPECTED_NODE_VERSION"
    nvm use "$EXPECTED_NODE_VERSION"
    set -u
fi

CURRENT_NODE_VERSION="$(node --version | sed 's/^v//')"
[[ "$CURRENT_NODE_VERSION" == "$EXPECTED_NODE_VERSION" ]] || {
    echo "[error] Node.js 版本未统一：当前 ${CURRENT_NODE_VERSION}，要求 ${EXPECTED_NODE_VERSION}" >&2
    return 1 2>/dev/null || exit 1
}

echo "==> 准备统一本地工具链（Node.js ${EXPECTED_NODE_VERSION}）..."
for project in \
    "shared/scanner-react" \
    "citizenchain/node/frontend" \
    "citizenchain/onchina/frontend"
do
    echo "    npm ci: $project"
    npm --prefix "$GMB_REPOSITORY_ROOT/$project" ci
done
echo "    统一本地工具链已就绪"
