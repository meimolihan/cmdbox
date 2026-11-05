#!/bin/bash
set -euo pipefail

NEW_USER="admin"
SSH_PORT="2222"
SSH_KEY_URL=""

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

create_user() {
    if id "$NEW_USER" &>/dev/null; then
        log_warn "用户 $NEW_USER 已存在，跳过创建"
    else
        useradd -m -s /bin/bash "$NEW_USER"
        usermod -aG sudo "$NEW_USER" 2>/dev/null || usermod -aG wheel "$NEW_USER" 2>/dev/null || true
        log_ok "已创建用户 $NEW_USER 并加入 sudo/wheel 组"
    fi
}

setup_ssh_key() {
    local home_dir
    home_dir=$(getent passwd "$NEW_USER" | cut -d: -f6)
    mkdir -p "$home_dir/.ssh"
    chmod 700 "$home_dir/.ssh"
    if [ -n "$SSH_KEY_URL" ]; then
        curl -sSL "$SSH_KEY_URL" -o "$home_dir/.ssh/authorized_keys"
    fi
    chmod 600 "$home_dir/.ssh/authorized_keys"
    chown -R "$NEW_USER:$NEW_USER" "$home_dir/.ssh"
    log_ok "SSH 公钥已部署"
}

harden_sshd() {
    local sshd_config="/etc/ssh/sshd_config"
    cp "$sshd_config" "${sshd_config}.bak.$(date +%s)"
    sed -i "s/^#*Port .*/Port $SSH_PORT/" "$sshd_config"
    sed -i "s/^#*PermitRootLogin .*/PermitRootLogin prohibit-password/" "$sshd_config"
    sed -i "s/^#*PasswordAuthentication .*/PasswordAuthentication no/" "$sshd_config"
    sed -i "s/^#*PubkeyAuthentication .*/PubkeyAuthentication yes/" "$sshd_config"
    systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || true
    log_ok "SSH 已加固：端口 $SSH_PORT，禁止 root 密码登录"
}

setup_firewall() {
    if command -v ufw &>/dev/null; then
        ufw allow "$SSH_PORT"/tcp
        ufw allow 22/tcp
        ufw --force enable
        log_ok "UFW 防火墙已启用并放行 SSH 端口"
    elif command -v firewall-cmd &>/dev/null; then
        firewall-cmd --permanent --add-port="$SSH_PORT"/tcp
        firewall-cmd --permanent --add-port=22/tcp
        firewall-cmd --reload
        log_ok "firewalld 防火墙已放行 SSH 端口"
    fi
}

auto_update() {
    if command -v unattended-upgrades &>/dev/null; then
        dpkg-reconfigure -f noninteractive unattended-upgrades 2>/dev/null || true
        log_ok "已启用自动安全更新"
    fi
}

main() {
    root_use
    create_user
    setup_ssh_key
    harden_sshd
    setup_firewall
    auto_update
    echo -e "${gl_lv}服务器初始化与安全加固完成${gl_bai}"
    echo -e "${gl_huang}新用户：$NEW_USER，SSH 端口：$SSH_PORT${gl_bai}"
}

main "$@"
