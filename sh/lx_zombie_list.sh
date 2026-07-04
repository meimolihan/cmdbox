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

list_beautify_linux_zombie() {
    {
        printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "进程ID" "用户" "CPU" "内存" "状态" "命令" "$reset"
        printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "--------" "--------" "--------" "--------" "--------" "--------" "$reset"

        data=$(ps aux 2>/dev/null | awk '$8 ~ /Z/')
        if [ -z "$data" ]; then
            printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_lv" "(无僵尸进程)" "(无僵尸进程)" "(无僵尸进程)" "(无僵尸进程)" "(无僵尸进程)" "(无僵尸进程)" "$reset"
        else
            echo "$data" | awk -v pid_color="$gl_hong" \
                              -v user_color="$gl_bufan" \
                              -v cpu_color="$gl_huang" \
                              -v mem_color="$gl_huang" \
                              -v stat_color="$gl_huang" \
                              -v cmd_color="$gl_lan" \
                              -v reset="$reset" '
            BEGIN {
                FS="[[:space:]]+";
                OFS="\t"
            }
            {
                user = $1
                pid = $2
                cpu = $3
                mem = $4
                stat = $8
                cmd = $11
                for (i=12; i<=NF; i++) {
                    cmd = cmd " " $i
                }

                print pid_color pid reset,
                      user_color user reset,
                      cpu_color cpu reset,
                      mem_color mem reset,
                      stat_color stat reset,
                      cmd_color cmd reset
            }'

            zcount=$(echo "$data" | wc -l)
            printf "\n%s⚠ 警告: 发现 %d 个僵尸进程 %s\n" "$gl_hong" "$zcount" "$reset"
        fi
    } | column_if_available
}

list_beautify_all() {
    clear
    echo -e "${gl_zi}>>> Linux僵尸进程列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_linux_zombie
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all
