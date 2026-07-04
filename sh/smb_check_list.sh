#!/bin/bash
set -uo pipefail

# ====================== 【可自定义配置区】 在这里修改所有默认参数 ======================
# 自动获取当前服务器本机IP（排除本地回环地址）
get_local_ip() {
    hostname -I | awk '{print $1}'
}
DEFAULT_SMB_IP=$(get_local_ip)

# 默认 SMB 用户名
DEFAULT_SMB_USER="guest"

# 默认 SMB 密码（空 = 匿名访问）
DEFAULT_SMB_PASS=""
# ====================================================================================

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

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    read -r -n 1 -s -r -p ""
    echo ""
    clear
}

column_if_available() {
    if command -v column &> /dev/null; then
        column -t -s $'\t'
    else
        cat
    fi
}

list_beautify_smb() {
    local smb_ip="${1:-$DEFAULT_SMB_IP}"
    local smb_user="${2:-$DEFAULT_SMB_USER}"
    local smb_pass="${3:-$DEFAULT_SMB_PASS}"

    {
        printf "%s%-20s\t%-10s\t%s%s\n" \
            "$gl_hui" "共享名称" "类型" "备注" "$reset"
        printf "%s%-20s\t%-10s\t%s%s\n" \
            "$gl_hui" "--------------------" "----------" "-------------------------" "$reset"

        smbclient -L "${smb_ip}" -U "${smb_user}%${smb_pass}" -m SMB3 2>/dev/null \
        | awk -v blue="$gl_lan" -v yellow="$gl_huang" -v white="$gl_bai" -v reset="$reset" '
        /^[[:space:]]+Sharename/ {next}
        /^[[:space:]]+---------/ {next}
        /^Reconnecting/ {next}
        /protocol negotiation/ {next}
        /Unable to connect/ {next}
        NF >= 3 {
            name=$1; type=$2; comment=""
            for(i=3; i<=NF; i++) comment = comment $i " "
            gsub(/^[ \t]+|[ \t]+$/, "", comment)
            printf "%s%-20s%s\t%s%-10s%s\t%s%s%s\n",
                blue, name, reset,
                yellow, type, reset,
                white, comment, reset
        }'
    } | column_if_available
}

list_beautify_all() {
    local target_ip="${1:-$DEFAULT_SMB_IP}"
    local target_user="${2:-$DEFAULT_SMB_USER}"
    local target_pass="${3:-$DEFAULT_SMB_PASS}"

    clear
    echo -e "${gl_zi}>>> SMB 共享资源查询 ${gl_bai}"
    echo -e "${gl_bufan}目标地址: ${target_ip}  用户: ${target_user}${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_smb "$target_ip" "$target_user" "$target_pass"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all "$@"
