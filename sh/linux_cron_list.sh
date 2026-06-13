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

list_beautify_linux_crontab() {
    {
        printf "%s%-12s\t%-8s\t%-8s\t%-8s\t%-12s\t%-40s%s\n" \
            "$gl_hui" "分钟" "小时" "日期" "月份" "星期" "执行命令" "$reset"
        printf "%s%-12s\t%-8s\t%-8s\t%-8s\t%-12s\t%-40s%s\n" \
            "$gl_hui" "------------" "--------" "--------" "--------" "------------" "----------------------------------------" "$reset"

        crontab -l 2>/dev/null | grep -v '^#' | awk NF | \
            awk -v green="$gl_lv" -v yellow="$gl_huang" \
                -v blue="$gl_lan" -v reset="$reset" '
        BEGIN {OFS="\t"}
        {
            if ($1 ~ /^@/) {
                minute = $1
                hour = ""
                day = ""
                month = ""
                week = ""
                cmd = substr($0, index($0, $2))
            } else {
                minute = $1
                hour = $2
                day = $3
                month = $4
                week = $5
                cmd = substr($0, index($0, $6))
            }
            printf "%s%-12s%s\t%s%-8s%s\t%s%-8s%s\t%s%-8s%s\t%s%-12s%s\t%s%-40s%s\n",
                blue, minute, reset,
                yellow, hour, reset,
                blue, day, reset,
                yellow, month, reset,
                blue, week, reset,
                green, cmd, reset
        }'
    } | column_if_available
}

list_beautify_all() {
    clear
    echo -e "${gl_zi}>>> Linux定时任务列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_linux_crontab
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all