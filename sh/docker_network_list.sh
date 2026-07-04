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

list_beautify_docker_network() {
    {
        printf "%s%s\t%s\t%s\t%s%s\n" "$gl_hui" "网络ID" "名称" "驱动" "作用域" "$reset"
        printf "%s%s\t%s\t%s\t%s%s\n" "$gl_hui" "--------" "--------" "--------" "--------" "$reset"

        data=$(docker network ls --format "{{.ID}}\t{{.Name}}\t{{.Driver}}\t{{.Scope}}")
        if [ -z "$data" ]; then
            printf "%s%s\t%s\t%s\t%s%s\n" "$gl_huang" "(无网络)" "(无网络)" "(无网络)" "(无网络)" "$reset"
        else
            echo "$data" | awk -v cyan="$gl_bufan" -v green="$gl_lv" -v yellow="$gl_huang" -v blue="$gl_lan" -v reset="$reset" '
            BEGIN {FS="\t"; OFS="\t"}
            {
                id = substr($1, 1, 12)
                name = $2
                driver = $3
                scope = $4
                print cyan id reset, green name reset, yellow driver reset, blue scope reset
            }'
        fi
    } | column_if_available
}

list_beautify_all() {
    clear
    echo -e "${gl_zi}>>> Docker网络列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_docker_network
	
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all