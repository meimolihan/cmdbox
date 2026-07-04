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

list_beautify_linux_port() {
    {
        printf "%s%-20s\t%-8s\t%-12s\t%-6s\t%-6s\t%-12s\t%-8s\t%-6s\t%-30s%s\n" \
            "$gl_hui" "程序名" "PID" "用户" "FD" "类型" "设备" "大小" "节点" "监听地址" "$reset"
        printf "%s%-20s\t%-8s\t%-12s\t%-6s\t%-6s\t%-12s\t%-8s\t%-6s\t%-30s%s\n" \
            "$gl_hui" "--------------------" "--------" "------------" "------" "------" "------------" "--------" "------" "------------------------------" "$reset"

        lsof -i -P -n 2>/dev/null | awk '
        /LISTEN/ && !seen[$0]++ {
            command = $1
            pid = $2
            user = $3
            fd = $4
            type = $5
            device = $6
            size = $7
            node = $8
            name = substr($0, index($0, $9))
            print command, pid, user, fd, type, device, size, node, name
        }' | awk -v green="$gl_lv" -v yellow="$gl_huang" -v blue="$gl_lan" -v cyan="$gl_bufan" \
            -v purple="$gl_zi" -v gray="$gl_hui" -v white="$gl_bai" -v reset="$reset" '
        BEGIN {FS=" "; OFS="\t"}
        {
            print green $1 reset,
                  yellow $2 reset,
                  blue $3 reset,
                  cyan $4 reset,
                  purple $5 reset,
                  gray $6 reset,
                  gray $7 reset,
                  gray $8 reset,
                  white $9 reset
        }'
    } | column_if_available
}

list_beautify_all() {
    clear
    echo -e "${gl_zi}>>> Linux端口占用状态列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_linux_port
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all