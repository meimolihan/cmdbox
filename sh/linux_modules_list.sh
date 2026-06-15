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

list_beautify_linux_modules() {
    {
        printf "%s%s\t%s\t%s\t%s%s\n" "$gl_hui" "模块名" "大小" "被引用" "被谁引用" "$reset"
        printf "%s%s\t%s\t%s\t%s%s\n" "$gl_hui" "--------" "--------" "--------" "--------" "$reset"

        data=$(lsmod 2>/dev/null | tail -n +2)
        if [ -z "$data" ]; then
            printf "%s%s\t%s\t%s\t%s%s\n" "$gl_huang" "(无数据)" "(无数据)" "(无数据)" "(无数据)" "$reset"
        else
            echo "$data" | sort -k1,1 | while IFS= read -r line; do
                [ -z "$(echo "$line" | tr -d ' ')"] && continue
                modname=$(echo "$line" | awk '{print $1}')
                size=$(echo "$line" | awk '{print $2}')
                used=$(echo "$line" | awk '{print $3}')
                by=$(echo "$line" | awk '{for(i=4;i<=NF;i++) printf "%s ", $i;}' | sed 's/[[:space:]]*$//')
                [ -z "$by" ] && by="-"

                used_color="$gl_lv"
                [ "$used" -gt 0 ] 2>/dev/null && used_color="$gl_huang"
                [ "$used" -gt 10 ] 2>/dev/null && used_color="$gl_hong"

                printf "%s%s\t%s%s\t%s%s\t%s%s\n" \
                       "$gl_lan" "$modname$reset" \
                       "$gl_bufan" "$size$reset" \
                       "$used_color" "$used$reset" \
                       "$gl_hui" "$by$reset"
            done
        fi
    } | column_if_available
}

list_beautify_all() {
    clear
    echo -e "${gl_zi}>>> Linux内核模块列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_linux_modules
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all
