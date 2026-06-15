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

list_beautify_linux_timer() {
    {
        printf "%s%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "定时器" "下次触发" "已过时间" "所属服务" "状态" "$reset"
        printf "%s%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "--------" "--------" "--------" "--------" "--------" "$reset"

        data=$(systemctl list-timers --all 2>/dev/null)
        if [ -z "$data" ]; then
            printf "%s%s\t%s\t%s\t%s\t%s%s\n" "$gl_huang" "(无数据)" "(无数据)" "(无数据)" "(无数据)" "(无数据)" "$reset"
        else
            echo "$data" | tail -n +2 | grep -v "^$" | \
            grep -v "^[0-9]\+ timers listed\|^[0-9]\+ unit\|^LIST\|^$" | \
            awk -v name_color="$gl_bufan" \
                -v next_color="$gl_lv" \
                -v left_color="$gl_huang" \
                -v service_color="$gl_lan" \
                -v status_color="$gl_hui" \
                -v reset="$reset" '
            BEGIN {
                FS="[[:space:]]][[:space:]]*";
                OFS="\t"
            }
            {
                if (NF >= 5) {
                    nxt = $1
                    left = $2
                    serv = $3
                    unit = $4
                    active = $5
                } else if (NF >= 4) {
                    nxt = $1
                    left = $2
                    serv = $3
                    unit = $4
                    active = ""
                } else if (NF >= 3) {
                    nxt = $1
                    left = $2
                    serv = $3
                    unit = ""
                    active = ""
                } else {
                    next
                }

                gsub(/^[[:space:]]+/, "", nxt)
                gsub(/^[[:space:]]+/, "", left)
                gsub(/^[[:space:]]+/, "", serv)
                gsub(/^[[:space:]]+/, "", unit)
                gsub(/^[[:space:]]+/, "", active)

                gsub(/[[:space:]]+$/, "", nxt)
                gsub(/[[:space:]]+$/, "", left)
                gsub(/[[:space:]]+$/, "", serv)
                gsub(/[[:space:]]+$/, "", unit)
                gsub(/[[:space:]]+$/, "", active)

                if (nxt == "" || nxt == "-")
                    nxt = "(已过期)"

                if (active == "active") active = "激活"

                print name_color unit reset,
                      next_color nxt reset,
                      left_color left reset,
                      service_color serv reset,
                      status_color active reset
            }'
        fi
    } | column_if_available
}

list_beautify_all() {
    clear
    echo -e "${gl_zi}>>> Linux Systemd定时器列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_linux_timer
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all
