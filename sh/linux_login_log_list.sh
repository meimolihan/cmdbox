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

list_beautify_linux_login_log() {
    {
        printf "%s%-12s\t%-10s\t%-18s\t%-25s\t%-20s%s\n" \
            "$gl_hui" "用户名" "终端" "来源IP" "登录时间" "状态" "$reset"
        printf "%s%-12s\t%-10s\t%-18s\t%-25s\t%-20s%s\n" \
            "$gl_hui" "------------" "----------" "------------------" "-------------------------" "--------------------" "$reset"

        last -n 10 2>/dev/null | awk '
        NF >= 8 && $1 != "reboot" && $1 != "wtmp" {
            user = $1
            tty  = $2
            from = ($3 ~ /^[0-9]/ || $3 ~ /:/) ? $3 : "本地"
            time = $4" "$5" "$6" "$7
            stat = "已登录"
            if ($0 ~ /still logged in/) stat = "在线中"
            else if ($0 ~ /gone/) stat = "已退出"
            print user, tty, from, time, stat
        }' | awk -v green="$gl_lv" \
            -v yellow="$gl_huang" \
            -v blue="$gl_lan" \
            -v cyan="$gl_bufan" \
            -v purple="$gl_zi" \
            -v gray="$gl_hui" \
            -v white="$gl_bai" \
            -v reset="$reset" '
        BEGIN { FS=" "; OFS="\t" }
        {
            printf "%s%-12s%s\t", green,    $1, reset
            printf "%s%-10s%s\t", yellow,  $2, reset
            printf "%s%-18s%s\t", blue,    $3, reset
            printf "%s%-25s%s\t", cyan,    $4" "$5" "$6" "$7, reset
            printf "%s%-20s%s\n", white,   $8, reset
        }'
    } | column_if_available
}


list_beautify_all() {
    clear
    echo -e "${gl_zi}>>> Linux登录日志${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_linux_login_log
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all