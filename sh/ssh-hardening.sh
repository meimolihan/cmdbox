#!/bin/bash
set -euo pipefail

SSH_PORT="2222"
MAX_AUTH_TRIES="3"
CLIENT_ALIVE_INTERVAL="300"
CLIENT_ALIVE_COUNT_MAX="3"

list_color_init() {
    export gl_hui=$'\033[38;5;59m'
    export gl_hong=$'\033[38;5;9m'
    export gl_lv=$'\033[38;5;10m'
    export gl_huang=$'\033[38;5;11m'
    export gl_lan=$'\033[38;5;32m'
    export gl_bai=$'\033[38;5;15m'
    export gl_zi=$'\033[38;5;13m'
    export gl_bufan=$'\033[38;5;14m'
    export reset=$'\033[0m'
}
list_color_init

log_info()  { echo -e "${gl_lan}[信息]${gl_bai} $*"; }
log_ok()    { echo -e "${gl_lv}[成功]${gl_bai} $*"; }
log_warn()  { echo -e "${gl_huang}[警告]${gl_bai} $*"; }
log_error() { echo -e "${gl_hong}[错误]${gl_bai} $*" >&2; }

root_use() {
    if [ "$EUID" -ne 0 ]; then
        log_error "该脚本需要root用户运行"; exit 1
    fi
}

backup_config() {
    local cfg="/etc/ssh/sshd_config"
    cp "$cfg" "${cfg}.bak.$(date +%Y%m%d%H%M%S)"
    log_info "已备份 sshd_config"
}

harden() {
    local cfg="/etc/ssh/sshd_config"
    sed -i "s/^#*Port .*/Port $SSH_PORT/" "$cfg"
    sed -i "s/^#*PermitRootLogin .*/PermitRootLogin prohibit-password/" "$cfg"
    sed -i "s/^#*PasswordAuthentication .*/PasswordAuthentication no/" "$cfg"
    sed -i "s/^#*PermitEmptyPasswords .*/PermitEmptyPasswords no/" "$cfg"
    sed -i "s/^#*PubkeyAuthentication .*/PubkeyAuthentication yes/" "$cfg"
    sed -i "s/^#*MaxAuthTries .*/MaxAuthTries $MAX_AUTH_TRIES/" "$cfg"
    sed -i "s/^#*ClientAliveInterval .*/ClientAliveInterval $CLIENT_ALIVE_INTERVAL/" "$cfg"
    sed -i "s/^#*ClientAliveCountMax .*/ClientAliveCountMax $CLIENT_ALIVE_COUNT_MAX/" "$cfg"
    grep -q "^Port " "$cfg" || echo "Port $SSH_PORT" >> "$cfg"
    grep -q "^MaxAuthTries " "$cfg" || echo "MaxAuthTries $MAX_AUTH_TRIES" >> "$cfg"
    grep -q "^ClientAliveInterval " "$cfg" || echo "ClientAliveInterval $CLIENT_ALIVE_INTERVAL" >> "$cfg"
    grep -q "^ClientAliveCountMax " "$cfg" || echo "ClientAliveCountMax $CLIENT_ALIVE_COUNT_MAX" >> "$cfg"
    systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || true
    log_ok "SSH 加固完成：端口 $SSH_PORT，最大认证失败 $MAX_AUTH_TRIES 次"
}

open_firewall() {
    if command -v ufw &>/dev/null; then
        ufw allow "$SSH_PORT"/tcp
        ufw reload
        log_ok "UFW 已放行端口 $SSH_PORT"
    elif command -v firewall-cmd &>/dev/null; then
        firewall-cmd --permanent --add-port="$SSH_PORT"/tcp
        firewall-cmd --reload
        log_ok "firewalld 已放行端口 $SSH_PORT"
    fi
}

main() {
    root_use
    backup_config
    harden
    open_firewall
    echo -e "${gl_lv}SSH 安全加固完成${gl_bai}"
    echo -e "${gl_huang}请在关闭当前会话前，用新端口 $SSH_PORT 验证登录${gl_bai}"
}

main "$@"
