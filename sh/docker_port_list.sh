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
    read -r -n 1 -s -p ""
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

list_beautify_docker_port() {
    {
        printf "%s%s\t%s%s\n" "$gl_hui" "容器名称" "端口映射" "$reset"
        printf "%s%s\t%s%s\n" "$gl_hui" "----------" "----------------------------------------" "$reset"

        data=$(docker ps --format "{{.Names}}\t{{.Ports}}" 2>/dev/null)
        if [ -z "$data" ]; then
            printf "%s%s\t%s%s\n" "$gl_huang" "(无运行中容器)" "(无运行中容器)" "$reset"
        else
            echo "$data" | awk -v green="$gl_lv" -v yellow="$gl_huang" -v cyan="$gl_bufan" -v reset="$reset" '
            BEGIN {FS="\t"; OFS="\t"}
            {
                name = $1
                ports = $2
                if (ports == "") ports = "(无端口映射)"
                print green name reset, cyan ports reset
            }'
        fi
    } | column_if_available
}

list_beautify_all() {
    clear
    echo -e "${gl_zi}>>> Docker 容器端口列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_docker_port
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all
