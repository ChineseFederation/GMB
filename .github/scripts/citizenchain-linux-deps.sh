#!/usr/bin/env bash

set -euo pipefail

# 中文注释：GitHub Ubuntu Runner 默认优先使用 Azure 区域镜像，该镜像偶发卡住时
# Acquire::Retries 无法保证整条 apt-get 命令及时退出。这里为当前命令提供独立官方源，
# 不改写 Runner 的全局 sources 文件，也不访问与 CitizenChain 构建无关的第三方仓库。
# shellcheck disable=SC1091
source /etc/os-release

if [[ "${ID:-}" != "ubuntu" || -z "${VERSION_CODENAME:-}" ]]; then
  echo "::error::只支持带 VERSION_CODENAME 的 Ubuntu Runner"
  exit 1
fi

citizenchain_arch="$(dpkg --print-architecture)"
citizenchain_source="$(mktemp)"
trap 'rm -f "${citizenchain_source}"' EXIT

case "${citizenchain_arch}" in
  amd64)
    citizenchain_archive="https://archive.ubuntu.com/ubuntu"
    citizenchain_security="https://security.ubuntu.com/ubuntu"
    ;;
  arm64)
    citizenchain_archive="https://ports.ubuntu.com/ubuntu-ports"
    citizenchain_security="${citizenchain_archive}"
    ;;
  *)
    echo "::error::不支持的 Ubuntu 架构：${citizenchain_arch}"
    exit 1
    ;;
esac

{
  echo "deb [arch=${citizenchain_arch} signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] ${citizenchain_archive} ${VERSION_CODENAME} main restricted universe multiverse"
  echo "deb [arch=${citizenchain_arch} signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] ${citizenchain_archive} ${VERSION_CODENAME}-updates main restricted universe multiverse"
  echo "deb [arch=${citizenchain_arch} signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] ${citizenchain_archive} ${VERSION_CODENAME}-backports main restricted universe multiverse"
  echo "deb [arch=${citizenchain_arch} signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] ${citizenchain_security} ${VERSION_CODENAME}-security main restricted universe multiverse"
} > "${citizenchain_source}"

citizenchain_apt_options=(
  -o "Dir::Etc::sourcelist=${citizenchain_source}"
  -o "Dir::Etc::sourceparts=-"
  -o Acquire::Retries=2
  -o Acquire::http::Timeout=20
  -o Acquire::https::Timeout=20
  -o Acquire::Languages=none
)

citizenchain_packages=(
  clang
  llvm
  llvm-dev
  libclang-dev
  libpam0g-dev
  libssl-dev
  libwebkit2gtk-4.1-dev
  libgtk-3-dev
  libayatana-appindicator3-dev
  librsvg2-dev
  pkg-config
  protobuf-compiler
  patchelf
  file
)

run_apt() {
  local citizenchain_label="$1"
  local citizenchain_timeout="$2"
  shift 2

  local citizenchain_attempt
  local citizenchain_status=1
  for citizenchain_attempt in 1 2 3; do
    echo "${citizenchain_label}：第 ${citizenchain_attempt}/3 次"
    if timeout --signal=TERM --kill-after=15s "${citizenchain_timeout}" "$@"; then
      return 0
    else
      citizenchain_status=$?
    fi

    if [[ "${citizenchain_attempt}" -lt 3 ]]; then
      # 中文注释：重试整条 APT 事务，避免单个 Acquire 重试耗尽后直接终止产品流水线。
      sleep "$((citizenchain_attempt * 10))"
    fi
  done

  echo "::error::${citizenchain_label}连续三次失败，最后退出码为 ${citizenchain_status}"
  return "${citizenchain_status}"
}

run_apt \
  "更新 CitizenChain Linux 官方软件源" \
  4m \
  sudo env DEBIAN_FRONTEND=noninteractive apt-get \
    "${citizenchain_apt_options[@]}" update

run_apt \
  "安装 CitizenChain Linux 系统依赖" \
  8m \
  sudo env DEBIAN_FRONTEND=noninteractive apt-get \
    "${citizenchain_apt_options[@]}" install -y \
    "${citizenchain_packages[@]}"

# 中文注释：APT 成功退出后再回读包状态和关键命令，禁止缺少依赖时进入 Rust/前端构建。
for citizenchain_package in "${citizenchain_packages[@]}"; do
  if [[ "$(dpkg-query -W -f='${Status}' "${citizenchain_package}" 2>/dev/null || true)" != "install ok installed" ]]; then
    echo "::error::CitizenChain Linux 依赖未安装：${citizenchain_package}"
    exit 1
  fi
done

for citizenchain_command in clang llvm-config pkg-config protoc patchelf file; do
  if ! command -v "${citizenchain_command}" >/dev/null 2>&1; then
    echo "::error::CitizenChain Linux 构建命令不可用：${citizenchain_command}"
    exit 1
  fi
done

echo "CitizenChain Linux 系统依赖已通过官方 Ubuntu 源安装并回读验证。"
