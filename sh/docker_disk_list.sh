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

list_beautify_docker_disk() {
    {
        docker system df | awk -v gray="$gl_hui" -v green="$gl_lv" -v yellow="$gl_huang" \
            -v blue="$gl_lan" -v cyan="$gl_bufan" -v reset="$reset" '
        BEGIN {
            print gray "类型\t总数\t活跃\t大小\t可回收" reset
            print gray "----------\t--------\t--------\t----------\t----------" reset
        }
        NR > 1 {
            type = $1
            total = $2
            active = $3
            size = $4
            reclaim = $5
            if (type == "Local") {
                type = $1 " " $2
                total = $3
                active = $4
                size = $5
                reclaim = $6
            }
            if (type == "Images") color = green
            else if (type == "Containers") color = yellow
            else if (type == "Local Volumes") color = blue
            else if (type == "Build Cache") color = cyan
            else color = reset
            print color type "\t" total "\t" active "\t" size "\t" reclaim reset
        }' | column_if_available
    }
}

list_beautify_all() {
    clear
    echo -e "${gl_zi}>>> Docker磁盘使用列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_docker_disk
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all