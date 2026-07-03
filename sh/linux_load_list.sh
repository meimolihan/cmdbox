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

list_beautify_linux_load() {
    {
        printf "%s%-18s\t%-10s\t%-10s\t%-10s\t%-20s%s\n" \
            "$gl_hui" "负载指标" "1分钟" "5分钟" "15分钟" "CPU逻辑核心数" "$reset"
        printf "%s%-18s\t%-10s\t%-10s\t%-10s\t%-20s%s\n" \
            "$gl_hui" "------------------" "----------" "----------" "----------" "--------------------" "$reset"

        cpu_num=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo "未知")

        uptime | awk -v cpu="$cpu_num" -v green="$gl_lv" -v yellow="$gl_huang" \
            -v red="$gl_hong" -v blue="$gl_lan" -v reset="$reset" '
        {
            m1 = $(NF-2); gsub(/,/, "", m1)
            m5 = $(NF-1); gsub(/,/, "", m5)
            m15 = $(NF);   gsub(/,/, "", m15)

            c1 = green; if (m1+0 > cpu+0) c1 = red
            c5 = green; if (m5+0 > cpu+0) c5 = red
            c15= green; if (m15+0> cpu+0) c15= red

            printf "%s%-18s%s\t%s%-10s%s\t%s%-10s%s\t%s%-10s%s\t%s%-20s%s\n",
                blue, "系统平均负载", reset,
                c1, m1, reset,
                c5, m5, reset,
                c15, m15, reset,
                yellow, cpu, reset
        }'
    } | column_if_available
}


list_beautify_all() {
    clear
    echo -e "${gl_zi}>>> Linux系统负载/CPU平均负载${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_linux_load
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all