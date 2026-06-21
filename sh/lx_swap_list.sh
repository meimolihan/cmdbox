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

list_beautify_linux_swap() {
    {
        printf "%s%-18s\t%-12s\t%-12s\t%-12s\t%-12s%s\n" \
            "$gl_hui" "内存类型" "总大小(MB)" "已用(MB)" "空闲(MB)" "使用率" "$reset"
        printf "%s%-18s\t%-12s\t%-12s\t%-12s\t%-12s%s\n" \
            "$gl_hui" "------------------" "------------" "------------" "------------" "------------" "$reset"

        free -m | awk -v green="$gl_lv" -v yellow="$gl_huang" \
            -v blue="$gl_lan" -v red="$gl_hong" -v reset="$reset" '
        function percent(u,t) { return t+0 == 0 ? "0%" : sprintf("%.1f%%", u*100/t) }
        NR==2 {
            total=$2; used=$3; free=$4
            printf "%s%-18s%s\t%s%-12s%s\t%s%-12s%s\t%s%-12s%s\t%s%-12s%s\n",
                blue, "物理内存", reset,
                yellow, total, reset,
                red, used, reset,
                green, free, reset,
                red, percent(used, total), reset
        }
        NR==3 {
            total=$2; used=$3; free=$4
            printf "%s%-18s%s\t%s%-12s%s\t%s%-12s%s\t%s%-12s%s\t%s%-12s%s\n",
                blue, "交换分区", reset,
                yellow, total, reset,
                red, used, reset,
                green, free, reset,
                red, percent(used, total), reset
        }'
    } | column_if_available
}

list_beautify_all() {
    clear
    echo -e "${gl_zi}>>> Linux系统内存/交换分区信息${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_linux_swap
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all