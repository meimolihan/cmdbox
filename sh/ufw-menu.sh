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

show_menu() {
    clear
    echo -e "${gl_zi}>>> UFW 防火墙管理菜单${reset}"
    echo -e "${gl_bufan}─────────────────────────────────────────────────────${reset}"
    echo -e "${gl_bufan}1. ${gl_bai}查看当前规则"
    echo -e "${gl_bufan}2. ${gl_bai}开放端口"
    echo -e "${gl_bufan}3. ${gl_bai}删除规则"
    echo -e "${gl_bufan}4. ${gl_bai}启用防火墙"
    echo -e "${gl_bufan}5. ${gl_bai}禁用防火墙"
    echo -e "${gl_bufan}6. ${gl_bai}重置防火墙"
    echo -e "${gl_bufan}0. ${gl_bai}退出脚本"
    echo -e "${gl_bufan}─────────────────────────────────────────────────────${reset}"
}

view_rules() {
    ufw status numbered
    echo -e "${gl_bai}按任意键继续${gl_bai}"
    read -r -n 1 -s -p ""
}

allow_port() {
    read -r -e -p "${gl_bai}请输入端口号: ${gl_bai}" port
    read -r -e -p "${gl_bai}请输入协议 (tcp/udp, 回车默认 tcp): ${gl_bai}" proto
    proto=${proto:-tcp}
    ufw allow "$port"/"$proto"
    log_ok "已开放端口 $port/$proto"
}

delete_rule() {
    ufw status numbered
    read -r -e -p "${gl_bai}请输入规则编号: ${gl_bai}" num
    ufw --force delete "$num"
    log_ok "已删除规则 $num"
}

enable_ufw() {
    ufw --force enable
    log_ok "防火墙已启用"
}

disable_ufw() {
    ufw disable
    log_ok "防火墙已禁用"
}

reset_ufw() {
    ufw --force reset
    log_ok "防火墙规则已重置"
}

main() {
    root_use
    while true; do
        show_menu
        read -r -e -p "${gl_bai}请输入你的选择: ${gl_bai}" choice
        case "$choice" in
            1) view_rules ;;
            2) allow_port ;;
            3) delete_rule ;;
            4) enable_ufw ;;
            5) disable_ufw ;;
            6) reset_ufw ;;
            0) break ;;
            *) log_warn "无效选择" ;;
        esac
    done
}

main "$@"
