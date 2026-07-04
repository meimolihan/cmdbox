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

list_beautify_linux_user() {
    {
        printf "%s%-24s\t%-34s\t%-20s\t%-10s%s\n" "$gl_hui" "用户名" "用户权限" "用户组" "sudo权限" "$reset"
        printf "%s%-24s\t%-34s\t%-20s\t%-10s%s\n" "$gl_hui" "------------------------" "----------------------------------" "--------------------" "----------" "$reset"

        while IFS=: read -r username _ _ _ _ homedir shell; do
            groups_info=$(groups "$username" 2>/dev/null | cut -d: -f2- | sed 's/^ //')
            [ -z "$groups_info" ] && groups_info="(无组信息)"

            sudo_status="No"
            sudo_output=$(sudo -n -lU "$username" 2>/dev/null)
            if [ -n "$sudo_output" ]; then
                if echo "$sudo_output" | grep -qE '\(ALL( : ALL)?\) ALL'; then
                    sudo_status="Yes"
                fi
            fi

            printf "%s\t%s\t%s\t%s\n" "$username" "$homedir" "$groups_info" "$sudo_status"
        done </etc/passwd | awk -v green="$gl_lv" -v yellow="$gl_huang" -v blue="$gl_lan" -v cyan="$gl_bufan" -v reset="$reset" '
        BEGIN {FS="\t"; OFS="\t"}
        {
            print green $1 reset, yellow $2 reset, blue $3 reset, cyan $4 reset
        }'
    } | column_if_available
}

list_beautify_all() {
    clear
    echo -e "${gl_zi}>>> Linux用户列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_linux_user
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all