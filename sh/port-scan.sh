#!/bin/bash
set -uo pipefail

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

scan_local() {
    echo -e "${gl_zi}>>> 本地监听端口${reset}"
    echo -e "${gl_bufan}─────────────────────────────────────────────────────${reset}"
    if command -v ss &>/dev/null; then
        ss -tuln
    elif command -v netstat &>/dev/null; then
        netstat -tuln
    fi
    echo -e "${gl_bufan}─────────────────────────────────────────────────────${reset}"
}

scan_processes() {
    echo -e "${gl_zi}>>> 端口占用进程${reset}"
    echo -e "${gl_bufan}─────────────────────────────────────────────────────${reset}"
    if command -v lsof &>/dev/null; then
        lsof -i -P -n 2>/dev/null || true
    elif command -v fuser &>/dev/null; then
        fuser -v -n tcp 22 80 443 8080 3306 6379 2>/dev/null || true
    fi
    echo -e "${gl_bufan}─────────────────────────────────────────────────────${reset}"
}

scan_lan() {
    read -r -e -p "${gl_bai}请输入目标 IP 或网段 (回车跳过): ${gl_bai}" target
    if [ -z "$target" ]; then return; fi
    echo -e "${gl_zi}>>> 扫描 $target 常用端口${reset}"
    echo -e "${gl_bufan}─────────────────────────────────────────────────────${reset}"
    if command -v nmap &>/dev/null; then
        nmap -sT -p 22,80,443,3306,6379,8080,8443 "$target" 2>/dev/null || true
    else
        log_warn "未安装 nmap，跳过远程扫描"
    fi
    echo -e "${gl_bufan}─────────────────────────────────────────────────────${reset}"
}

main() {
    echo -e "${gl_zi}>>> 端口扫描与资产盘点${reset}"
    scan_local
    scan_processes
    scan_lan
    log_ok "资产盘点完成"
}

main "$@"
