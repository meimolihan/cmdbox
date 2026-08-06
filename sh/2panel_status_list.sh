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

get_2panel_pid() {
    systemctl show -p MainPID 2panel 2>/dev/null | cut -d= -f2
}

list_beautify_2panel_status() {
    local PID
    PID=$(get_2panel_pid)

    if [[ -z "$PID" || ! -d "/proc/$PID" ]]; then
        echo -e "${gl_hong}❌ 2panel 服务未运行${reset}"
        return 1
    fi

    local VmSize VmRSS Threads
    VmSize=$(awk '/VmSize/ {print $2}' /proc/$PID/status)
    VmRSS=$(awk '/VmRSS/ {print $2}' /proc/$PID/status)
    Threads=$(awk '/Threads/ {print $2}' /proc/$PID/status)

    local VmSize_MB VmRSS_MB
    VmSize_MB=$(awk -v v="$VmSize" 'BEGIN{printf "%.2f", v/1024}')
    VmRSS_MB=$(awk -v r="$VmRSS" 'BEGIN{printf "%.2f", r/1024}')

    local PORT
    PORT=$(lsof -p "$PID" -i -P 2>/dev/null | grep LISTEN | awk '{print $9}' | sed -E 's/.*:([0-9]+)$/\1/' | head -n1)

    local RUN_SEC RUN_STR H M S
    RUN_SEC=$(systemctl show -p ActiveEnterTimestampMonotonic 2panel 2>/dev/null | cut -d= -f2 | awk '{print int($1/1000000)}')
    if [[ -n "$RUN_SEC" ]]; then
        H=$(( RUN_SEC / 3600 ))
        M=$(( (RUN_SEC % 3600) / 60 ))
        S=$(( RUN_SEC % 60 ))
        RUN_STR="${H}小时 ${M}分钟 ${S}秒"
    else
        RUN_STR="未知"
    fi

    printf "%-14s ${gl_lv}%s${reset}\n" "${gl_lan}进程 PID${reset}" "$PID"
    printf "%-14s ${gl_lv}%s${reset}\n" "${gl_lan}监听端口${reset}" "${PORT:-未找到}"
    printf "%-14s ${gl_lv}%s${reset}\n" "${gl_lan}运行时长${reset}" "$RUN_STR"
    printf "%-14s ${gl_lv}%s kB (${VmSize_MB} MB)${reset}\n" "${gl_lan}虚拟内存${reset}" "$VmSize"
    printf "%-14s ${gl_lv}%s kB (${VmRSS_MB} MB)${reset}\n" "${gl_lan}物理内存${reset}" "$VmRSS"
    printf "%-14s ${gl_lv}%s${reset}\n" "${gl_lan}线程数量${reset}" "$Threads"
    printf "%-14s ${gl_lv}%s${reset}\n" "${gl_lan}数据目录${reset}" "/var/lib/2panel"
}

list_beautify_all() {
    clear
    echo -e "${gl_zi}>>> 2Panel 服务详细状态${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_2panel_status
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all
