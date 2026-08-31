#!/usr/bin/env bash
set -euo pipefail

# 只安装当前 Linux ARM64 正式包；不下载、不覆盖、不升级已有安装。
if [[ "${EUID}" -ne 0 ]]; then
  echo "必须以 root 执行 ChatServer 安装" >&2
  exit 1
fi
case "$(uname -m)" in
  aarch64|arm64) ;;
  *) echo "ChatServer 安装包只支持 Linux ARM64" >&2; exit 1 ;;
esac
if [[ "$#" -ne 3 ]]; then
  echo "用法: install.sh <tls-cert.pem> <tls-key.pem> <jwt-ed25519-public.pem>" >&2
  exit 1
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
package_root="$(cd -- "${script_dir}/.." && pwd)"
binary="${CHATSERVER_BINARY:-${package_root}/chatserver}"
config="${CHATSERVER_CONFIG:-${script_dir}/chatserver.toml}"
schema="${package_root}/schema.sql"
unit="${script_dir}/chatserver.service"
tls_cert="$1"
tls_key="$2"
jwt_public="$3"

for command in install systemctl useradd userdel runuser; do
  command -v "$command" >/dev/null
done
runuser_bin="$(command -v runuser)"
for source in "$binary" "$config" "$schema" "$unit" "$tls_cert" "$tls_key" "$jwt_public"; do
  [[ -f "$source" ]] || { echo "安装输入不存在: $source" >&2; exit 1; }
done
[[ -x "$binary" ]] || { echo "ChatServer ARM64 二进制不可执行" >&2; exit 1; }
if [[ -e /usr/local/bin/chatserver || -e /etc/chatserver || -e /var/lib/chatserver \
   || -e /etc/systemd/system/chatserver.service ]]; then
  echo "检测到已有 ChatServer 安装；禁止覆盖或兼容安装" >&2
  exit 1
fi

created_user=0
schema_initialized=0
rollback() {
  systemctl disable --now chatserver.service >/dev/null 2>&1 || true
  if [[ "$schema_initialized" -eq 1 && -x /usr/local/bin/chatserver \
     && -f /etc/chatserver/chatserver.toml ]]; then
    if ! "$runuser_bin" -u chatserver -- /usr/local/bin/chatserver purge \
      /etc/chatserver/chatserver.toml >/dev/null 2>&1; then
      echo "数据库回滚失败；已保留恢复所需的二进制、配置和系统用户" >&2
      return 0
    fi
  fi
  rm -f /etc/systemd/system/chatserver.service /usr/local/bin/chatserver
  rm -rf /etc/chatserver /var/lib/chatserver /usr/share/chatserver
  if [[ "$created_user" -eq 1 ]]; then userdel chatserver >/dev/null 2>&1 || true; fi
  systemctl daemon-reload >/dev/null 2>&1 || true
}
trap rollback ERR

if ! id chatserver >/dev/null 2>&1; then
  useradd --system --home-dir /var/lib/chatserver --shell /usr/sbin/nologin chatserver
  created_user=1
else
  echo "系统用户 chatserver 已存在；拒绝复用未知身份" >&2
  exit 1
fi

install -d -o root -g chatserver -m 0750 /etc/chatserver
install -d -o root -g chatserver -m 0750 /etc/chatserver/tls /etc/chatserver/auth /etc/chatserver/push
install -d -o chatserver -g chatserver -m 0700 /var/lib/chatserver/objects
install -d -o root -g root -m 0755 /usr/share/chatserver
install -o root -g root -m 0755 "$binary" /usr/local/bin/chatserver
install -o root -g chatserver -m 0640 "$config" /etc/chatserver/chatserver.toml
install -o root -g root -m 0644 "$schema" /usr/share/chatserver/schema.sql
install -o root -g chatserver -m 0640 "$tls_cert" /etc/chatserver/tls/server-cert.pem
install -o root -g chatserver -m 0640 "$tls_key" /etc/chatserver/tls/server-key.pem
install -o root -g chatserver -m 0640 "$jwt_public" /etc/chatserver/auth/jwt-ed25519-public.pem
install -o root -g root -m 0644 "$unit" /etc/systemd/system/chatserver.service

sudo_user=("$runuser_bin" -u chatserver --)
"${sudo_user[@]}" /usr/local/bin/chatserver init \
  /etc/chatserver/chatserver.toml /usr/share/chatserver/schema.sql
schema_initialized=1
"${sudo_user[@]}" /usr/local/bin/chatserver check /etc/chatserver/chatserver.toml
systemctl daemon-reload
systemctl enable --now chatserver.service
trap - ERR
echo "ChatServer Linux ARM64 安装成功"
