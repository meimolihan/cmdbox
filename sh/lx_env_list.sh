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

list_beautify_linux_env() {
    {
        printf "%s%-20s\t%-30s%s\n" "$gl_hui" "变量名" "变量值" "$reset"
        printf "%s%-20s\t%-30s%s\n" "$gl_hui" "------------------------------" "--------------------------------------------------" "$reset"

        env | grep -E '^(PATH|USER|HOME|SHELL|PWD|LANG|HOSTNAME|TERM)' | sort | \
            awk -v green="$gl_lv" -v blue="$gl_lan" -v reset="$reset" '
        BEGIN {FS="="; OFS="\t"}
        {
            key = $1
            val = substr($0, index($0, $2))
            printf "%s%-20s%s\t%s%-30s%s\n",
                blue, key, reset,
                green, val, reset
        }'
    } | column_if_available
}

list_beautify_all() {
    clear
    echo -e "${gl_zi}>>> Linux系统环境变量${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_linux_env
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all