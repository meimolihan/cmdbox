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

list_beautify_linux_timezone() {
    {
        printf "%s%s\t%s\t%s%s\n" "$gl_hui" "项目" "值" "状态" "$reset"
        printf "%s%s\t%s\t%s%s\n" "$gl_hui" "--------" "--------" "--------" "$reset"

        local tz=""
        local utc_time=""
        local local_time=""
        local rtc_time=""
        local ntp_enabled=""
        local ntp_sync=""

        if command -v timedatectl &> /dev/null; then
            tz=$(timedatectl status 2>/dev/null | grep "Time zone" | awk -F: '{print $2}' | xargs)
            utc_time=$(timedatectl status 2>/dev/null | grep "Universal" | awk -F: '{print $2}' | xargs)
            local_time=$(timedatectl status 2>/dev/null | grep "Local time" | awk -F: '{print $2}' | xargs)
            rtc_time=$(timedatectl status 2>/dev/null | grep "RTC time" | awk -F: '{print $2}' | xargs)
            ntp_enabled=$(timedatectl status 2>/dev/null | grep "NTP enabled" | awk -F: '{print $2}' | xargs)
            ntp_sync=$(timedatectl status 2>/dev/null | grep "NTP synchronized" | awk -F: '{print $2}' | xargs)
        fi

        [ -z "$tz" ] && tz=$(readlink /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||')
        [ -z "$tz" ] && tz="UTC"
        [ -z "$utc_time" ] && utc_time=$(date -u '+%Y-%m-%d %H:%M:%S UTC' 2>/dev/null)
        [ -z "$local_time" ] && local_time=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
        [ -z "$rtc_time" ] && rtc_time="(未获取)"
        [ -z "$ntp_enabled" ] && ntp_enabled="未知"
        [ -z "$ntp_sync" ] && ntp_sync="未知"

        printf "%s%s\t%s%s\t%s%s\n" "$gl_lan" "时区$reset" \
               "$gl_bufan" "$tz$reset" \
               "$gl_lv" "正常$reset"

        printf "%s%s\t%s%s\t%s%s\n" "$gl_lan" "本地时间$reset" \
               "$gl_bufan" "$local_time$reset" \
               "$gl_lv" "正常$reset"

        printf "%s%s\t%s%s\t%s%s\n" "$gl_lan" "UTC时间$reset" \
               "$gl_bufan" "$utc_time$reset" \
               "$gl_lv" "参考$reset"

        printf "%s%s\t%s%s\t%s%s\n" "$gl_lan" "RTC硬件时间$reset" \
               "$gl_huang" "$rtc_time$reset" \
               "$gl_hui" "硬件$reset"

        local ntp_color="$gl_lv"
        [ "$ntp_enabled" != "yes" ] && ntp_color="$gl_hong"
        printf "%s%s\t%s%s\t%s%s\n" "$gl_lan" "NTP启用$reset" \
               "$ntp_color" "$ntp_enabled$reset" \
               "$gl_hui" "服务$reset"

        local sync_color="$gl_lv"
        [ "$ntp_sync" != "yes" ] && sync_color="$gl_hong"
        printf "%s%s\t%s%s\t%s%s\n" "$gl_lan" "NTP同步$reset" \
               "$sync_color" "$ntp_sync$reset" \
               "$gl_hui" "同步$reset"

        echo ""
        echo -e "${gl_zi}--- 时区偏移 ---${gl_bai}"

        local offset=$(date '+%z' 2>/dev/null)
        local epoch=$(date '+%s' 2>/dev/null)
        printf "%s%s\t%s%s\n" "$gl_hui" "UTC偏移" "当前时间戳" "$reset"
        printf "%s%s\t%s%s\n" "$gl_hui" "--------" "--------" "$reset"
        printf "%s%s\t%s%s\n" "$gl_lv" "$offset$reset" \
               "$gl_huang" "${epoch:---}$reset"

    } | column_if_available
}

list_beautify_all() {
    clear
    echo -e "${gl_zi}>>> Linux时区与时间列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_linux_timezone
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all
