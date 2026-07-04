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

list_beautify_linux_inode() {
    {
        printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "文件系统" "Inode总数" "已用" "可用" "使用率" "挂载点" "$reset"
        printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "--------" "--------" "--------" "--------" "--------" "--------" "$reset"

        data=$(df -i 2>/dev/null | grep -v "tmpfs\|udev\|overlay" | tail -n +2)
        if [ -z "$data" ]; then
            printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_huang" "(无数据)" "(无数据)" "(无数据)" "(无数据)" "(无数据)" "(无数据)" "$reset"
        else
            echo "$data" | awk -v fs_color="$gl_lan" \
                               -v total_color="$gl_lv" \
                               -v used_color="$gl_huang" \
                               -v avail_color="$gl_bufan" \
                               -v use_color="$gl_huang" \
                               -v mount_color="$gl_hui" \
                               -v gl_huang_inode="$gl_huang" \
                               -v gl_hong_inode="$gl_hong" \
                               -v reset="$reset" '
            BEGIN {
                FS="[[:space:]]+";
                OFS="\t"
            }
            {
                filesystem = $1
                itotal = $2
                iused = $3
                ifree = $4
                iuse_percent = $5
                mount = $6
                for (i=7; i<=NF; i++) {
                    mount = mount " " $i
                }

                gsub(/%/, "", iuse_percent)
                pct = iuse_percent + 0
                iuse_percent = iuse_percent "%"

                pct_color = use_color
                if (pct >= 90) {
                    pct_color = gl_hong_inode
                } else if (pct >= 80) {
                    pct_color = gl_huang_inode
                }

                print fs_color filesystem reset,
                      total_color itotal reset,
                      used_color iused reset,
                      avail_color ifree reset,
                      pct_color iuse_percent reset,
                      mount_color mount reset
            }'
        fi
    } | column_if_available
}

list_beautify_all() {
    clear
    echo -e "${gl_zi}>>> Linux Inode使用列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_linux_inode
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all
