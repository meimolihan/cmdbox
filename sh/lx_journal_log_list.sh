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

list_beautify_linux_journal_log() {
    {
        LINE=${1:-50}

        journalctl -n $LINE --no-pager 2>/dev/null | awk -v gray="$gl_hui" -v green="$gl_lv" \
        -v yellow="$gl_huang" -v purple="$gl_zi" -v red="$gl_hong" -v reset="$reset" '
        BEGIN {
            OFS = "\t"
            print gray "时间\t主机名\t服务进程\t日志信息" reset
            print gray "----------\t----------\t----------\t----------------------------------------" reset
        }
        /^$/ { next }
        {
            time = $1 " " $2 " " $3
            host = $4
            service = $5
            gsub(/:$/, "", service)
            msg = substr($0, index($0, $6))

            color = yellow
            if (msg ~ /error|Error|ERROR|fail|Fail|FAIL|warning|Warning|WARNING/) color = red

            print gray time reset, purple host reset, green service reset, color msg reset
        }' | column_if_available
    }
}

list_beautify_all() {
    clear
    echo -e "${gl_zi}>>> 美化Linux最近系统日志${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_linux_journal_log
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all