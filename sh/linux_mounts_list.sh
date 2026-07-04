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

list_beautify_linux_mounts() {
    {
        printf "%s%-25s\t%-25s\t%-15s\t%-20s%s\n" \
            "$gl_hui" "设备" "挂载点" "文件系统" "权限" "$reset"
        printf "%s%-25s\t%-25s\t%-15s\t%-20s%s\n" \
            "$gl_hui" "-------------------------" "-------------------------" "---------------" "--------------------" "$reset"

        mount | grep -E '^/dev/' | grep -v 'loop' | sort | \
            awk -v green="$gl_lv" -v yellow="$gl_huang" \
                -v blue="$gl_lan" -v reset="$reset" '
        BEGIN {OFS="\t"}
        {
            dev = $1
            mp = $3
            fs = $5
            perm = $6
            gsub(/[()]/, "", perm)
            printf "%s%-25s%s\t%s%-25s%s\t%s%-15s%s\t%s%-20s%s\n",
                blue, dev, reset,
                yellow, mp, reset,
                green, fs, reset,
                green, perm, reset
        }'
    } | column_if_available
}

list_beautify_all() {
    clear
    echo -e "${gl_zi}>>> Linux系统所有挂载点${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_linux_mounts
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all