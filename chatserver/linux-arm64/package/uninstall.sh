#!/usr/bin/env bash
set -euo pipefail

# 卸载是显式彻底删除：数据库规范表、本机密文对象、配置、服务和系统用户均不保留。
if [[ "${EUID}" -ne 0 ]]; then
  echo "必须以 root 执行 ChatServer 卸载" >&2
  exit 1
fi
for path in /usr/local/bin/chatserver /etc/chatserver/chatserver.toml \
  /etc/systemd/system/chatserver.service /var/lib/chatserver; do
  [[ -e "$path" ]] || { echo "ChatServer 安装不完整，拒绝部分卸载: $path" >&2; exit 1; }
done
id chatserver >/dev/null 2>&1 || { echo "ChatServer 系统用户不存在" >&2; exit 1; }
runuser_bin="$(command -v runuser)"

systemctl disable --now chatserver.service
"$runuser_bin" -u chatserver -- /usr/local/bin/chatserver purge \
  /etc/chatserver/chatserver.toml
rm -f /etc/systemd/system/chatserver.service /usr/local/bin/chatserver
rm -rf /etc/chatserver /var/lib/chatserver /usr/share/chatserver
userdel chatserver
systemctl daemon-reload
echo "ChatServer Linux ARM64 已彻底卸载"
