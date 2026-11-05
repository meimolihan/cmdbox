#!/bin/bash
set -euo pipefail

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

install_tailscale() {
    curl -fsSL https://tailscale.com/install.sh | sh
    systemctl enable --now tailscaled
    log_ok "Tailscale 已安装并启动"
    echo -e "${gl_bai}请运行：tailscale up${gl_bai}"
}

install_zerotier() {
    curl -s https://install.zerotier.com | sudo bash
    systemctl enable --now zerotier-one
    log_ok "ZeroTier 已安装并启动"
    echo -e "${gl_bai}请运行：zerotier-cli join <网络ID>${gl_bai}"
}

main() {
    root_use
    echo -e "${gl_zi}>>> 请选择 VPN 工具${reset}"
    echo -e "${gl_bufan}1. ${gl_bai}Tailscale"
    echo -e "${gl_bufan}2. ${gl_bai}ZeroTier"
    read -r -e -p "${gl_bai}请输入选择 (回车默认 1): ${gl_bai}" choice
    case "$choice" in
        2) install_zerotier ;;
        *) install_tailscale ;;
    esac
    log_ok "VPN 安装完成"
}

main "$@"
