#!/bin/bash
set -euo pipefail

NTP_SERVERS="ntp.aliyun.com cn.pool.ntp.org time.google.com"
TIMEZONE="Asia/Shanghai"

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

install_chrony() {
    if command -v chronyd &>/dev/null; then
        log_warn "chrony 已安装"
    elif command -v apt &>/dev/null; then
        apt update && apt install -y chrony
    elif command -v yum &>/dev/null; then
        yum install -y chrony
    elif command -v dnf &>/dev/null; then
        dnf install -y chrony
    else
        log_error "未找到支持的包管理器"; exit 1
    fi
}

configure() {
    local conf="/etc/chrony/chrony.conf"
    cp "$conf" "${conf}.bak.$(date +%s)" 2>/dev/null || true
    {
        echo "server ntp.aliyun.com iburst"
        echo "server cn.pool.ntp.org iburst"
        echo "server time.google.com iburst"
        echo "driftfile /var/lib/chrony/drift"
        echo "makestep 1.0 3"
        echo "rtcsync"
        echo "allow 127.0.0.1"
        echo "logdir /var/log/chrony"
    } > "$conf"
    timedatectl set-timezone "$TIMEZONE" 2>/dev/null || ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
    systemctl enable --now chronyd 2>/dev/null || systemctl enable --now chrony 2>/dev/null || true
    log_ok "chrony 已配置，时区：$TIMEZONE"
}

check_sync() {
    sleep 2
    chronyc tracking 2>/dev/null || chronyc -n tracking 2>/dev/null || true
    log_ok "时间同步服务已启动"
}

main() {
    root_use
    install_chrony
    configure
    check_sync
    echo -e "${gl_lv}系统时间同步配置完成${gl_bai}"
}

main "$@"
