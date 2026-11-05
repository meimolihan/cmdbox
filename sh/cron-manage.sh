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

show_cron() {
    crontab -l 2>/dev/null || log_warn "当前用户无 crontab 任务"
}

add_cron() {
    read -r -e -p "${gl_bai}请输入 cron 表达式 (如 0 2 * * *): ${gl_bai}" expr
    read -r -e -p "${gl_bai}请输入执行命令: ${gl_bai}" cmd
    (crontab -l 2>/dev/null; echo "$expr $cmd") | crontab -
    log_ok "定时任务已添加"
}

del_cron() {
    show_cron
    read -r -e -p "${gl_bai}请输入要删除的行号: ${gl_bai}" num
    crontab -l 2>/dev/null | sed "${num}d" | crontab -
    log_ok "定时任务已删除"
}

main() {
    root_use
    while true; do
        clear
        echo -e "${gl_zi}>>> 定时任务管理${reset}"
        echo -e "${gl_bufan}─────────────────────────────────────────────────────${reset}"
        show_cron
        echo -e "${gl_bufan}─────────────────────────────────────────────────────${reset}"
        echo -e "${gl_bufan}1. ${gl_bai}添加任务"
        echo -e "${gl_bufan}2. ${gl_bai}删除任务"
        echo -e "${gl_bufan}0. ${gl_bai}退出"
        echo -e "${gl_bufan}─────────────────────────────────────────────────────${reset}"
        read -r -e -p "${gl_bai}请输入选择: ${gl_bai}" choice
        case "$choice" in
            1) add_cron ;;
            2) del_cron ;;
            0) break ;;
            *) log_warn "无效选择" ;;
        esac
    done
}

main "$@"
