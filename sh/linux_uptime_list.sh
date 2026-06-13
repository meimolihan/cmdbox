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

list_beautify_linux_uptime() {
    {
        printf "%s%-18s\t%-30s\t%-20s%s\n" \
            "$gl_hui" "开机时间" "运行时长" "当前时间" "$reset"
        printf "%s%-18s\t%-30s\t%-20s%s\n" \
            "$gl_hui" "------------------" "------------------------------" "--------------------" "$reset"

        boot_time=$(uptime -s 2>/dev/null || who -b 2>/dev/null | awk '{print $3,$4}')
        up_time=$(uptime -p 2>/dev/null | sed 's/up //' \
            | sed -E 's/ years?/年/g' \
            | sed -E 's/ months?/月/g' \
            | sed -E 's/ weeks?/周/g' \
            | sed -E 's/ days?/天/g' \
            | sed -E 's/ hours?/小时/g' \
            | sed -E 's/ minutes?/分钟/g' \
            | sed -E 's/ seconds?/秒/g' \
            | sed 's/,/，/g')
        now_time=$(date +"%Y-%m-%d %H:%M:%S")

        printf "%s%-18s%s\t%s%-30s%s\t%s%-20s%s\n" \
            "$gl_lan" "${boot_time:-未知}" "$reset" \
            "$gl_huang" "${up_time:-未知}" "$reset" \
            "$gl_lv" "${now_time}" "$reset"
    } | column_if_available
}

list_beautify_all() {
    clear
    echo -e "${gl_zi}>>> Linux系统开机时间/运行时长${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_linux_uptime
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all