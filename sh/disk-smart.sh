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

check_smartctl() {
    if ! command -v smartctl &>/dev/null; then
        log_warn "smartctl 未安装，尝试安装 smartmontools"
        if command -v apt &>/dev/null; then apt update && apt install -y smartmontools; fi
        if command -v yum &>/dev/null; then yum install -y smartmontools; fi
        if command -v dnf &>/dev/null; then dnf install -y smartmontools; fi
    fi
}

list_disks() {
    lsblk -d -n -o NAME | grep -E '^(sd|hd|vd|nvme)' || true
}

inspect_disk() {
    local dev="/dev/$1"
    echo -e "${gl_zi}>>> 磁盘 $dev${reset}"
    smartctl -H "$dev" 2>/dev/null || smartctl -H -d sat "$dev" 2>/dev/null || log_warn "无法读取 $dev SMART 信息"
    smartctl -A "$dev" 2>/dev/null | grep -E 'Temperature|Reallocated|Power_On_Hours|Power_Cycle|UDMA_CRC_Error' || true
    echo -e "${gl_bufan}─────────────────────────────────────────────────────${reset}"
}

main() {
    check_smartctl
    echo -e "${gl_zi}>>> 磁盘 SMART 巡检${reset}"
    echo -e "${gl_bufan}─────────────────────────────────────────────────────${reset}"
    local found=0
    for disk in $(list_disks); do
        inspect_disk "$disk"
        found=1
    done
    if [ "$found" -eq 0 ]; then
        log_warn "未发现可检测的磁盘设备"
    fi
    echo -e "${gl_bufan}─────────────────────────────────────────────────────${reset}"
    log_ok "SMART 巡检完成"
}

main "$@"
