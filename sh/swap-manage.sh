#!/bin/bash
set -euo pipefail

SWAP_FILE="/swapfile"
SWAP_SIZE="2G"

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

show_swap() {
    free -h
    echo -e "${gl_bai}---${gl_bai}"
    swapon --show
}

create_swap() {
    read -r -e -p "${gl_bai}请输入 Swap 大小 (如 2G, 回车默认 2G): ${gl_bai}" sz
    sz=${sz:-2G}
    if [ -f "$SWAP_FILE" ]; then
        log_warn "Swap 文件已存在，先禁用并删除"
        swapoff "$SWAP_FILE" 2>/dev/null || true
        rm -f "$SWAP_FILE"
    fi
    fallocate -l "$sz" "$SWAP_FILE" || dd if=/dev/zero of="$SWAP_FILE" bs=1M count=$(echo "$sz" | sed 's/G//')
    chmod 600 "$SWAP_FILE"
    mkswap "$SWAP_FILE"
    swapon "$SWAP_FILE"
    grep -q "$SWAP_FILE" /etc/fstab || echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab
    log_ok "已创建并启用 Swap $sz"
}

set_swappiness() {
    read -r -e -p "${gl_bai}请输入 swappiness 值 (0-100, 回车默认 60): ${gl_bai}" val
    val=${val:-60}
    sysctl vm.swappiness="$val"
    grep -q "vm.swappiness" /etc/sysctl.conf && sed -i "s/^vm.swappiness.*/vm.swappiness=$val/" /etc/sysctl.conf || echo "vm.swappiness=$val" >> /etc/sysctl.conf
    log_ok "swappiness 已设为 $val"
}

disable_swap() {
    swapoff -a
    sed -i '/ swap /d' /etc/fstab
    log_ok "Swap 已禁用"
}

delete_swap() {
    swapoff "$SWAP_FILE" 2>/dev/null || true
    rm -f "$SWAP_FILE"
    sed -i "/$SWAP_FILE/d" /etc/fstab
    log_ok "Swap 文件已删除"
}

main() {
    root_use
    echo -e "${gl_zi}>>> Swap 管理${gl_bai}"
    echo -e "${gl_bufan}1. ${gl_bai}查看当前 Swap"
    echo -e "${gl_bufan}2. ${gl_bai}创建/调整 Swap"
    echo -e "${gl_bufan}3. ${gl_bai}设置 swappiness"
    echo -e "${gl_bufan}4. ${gl_bai}禁用 Swap"
    echo -e "${gl_bufan}5. ${gl_bai}删除 Swap 文件"
    echo -e "${gl_bufan}0. ${gl_bai}退出"
    read -r -e -p "${gl_bai}请输入选择: ${gl_bai}" choice
    case "$choice" in
        1) show_swap ;;
        2) create_swap ;;
        3) set_swappiness ;;
        4) disable_swap ;;
        5) delete_swap ;;
        0) exit 0 ;;
        *) log_warn "无效选择" ;;
    esac
}

main "$@"
