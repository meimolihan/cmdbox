#!/bin/bash
set -uo pipefail

list_color_init() {
    gl_hui=$'\033[38;5;59m'
    gl_hong=$'\033[38;5;9m'
    gl_lv=$'\033[38;5;10m'
    gl_huang=$'\033[38;5;11m'
    gl_lan=$'\033[38;5;32m'
    gl_bai=$'\033[38;5;15m'
    gl_zi=$'\033[38;5;13m'
    gl_bufan=$'\033[38;5;14m'
    reset=$'\033[0m'
}
list_color_init

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    read -n 1 -s -r
    echo ""
    clear
}

column_if_available() {
    if command -v column >/dev/null 2>&1; then
        command column -t -s $'\t'
    else
        cat
    fi
}

parse_crontab() {
    crontab -l 2>/dev/null | grep -v '^#' | awk '
    NF {
        if ($1 ~ /^@/) {
            min=$1; hour=""; day=""; mon=""; week=""; cmd=substr($0, index($0,$2))
        } else {
            min=$1; hour=$2; day=$3; mon=$4; week=$5; cmd=substr($0, index($0,$6))
        }
        printf "%s\t%s\t%s\t%s\t%s\t%s\n", min, hour, day, mon, week, cmd
    }'
}

cron_desc() {
    local min="$1" hour="$2" day="$3" mon="$4" week="$5" cmd="$6"
    local desc="" min_txt="" hour_txt="" step=""
    local w="" week_txt=""
    local is_min_single=0 is_hour_single=0

    if [ "${min#@}" != "$min" ]; then
        case "$min" in
            @reboot) desc="开机时执行" ;;
            @yearly|@annually) desc="每年执行一次" ;;
            @monthly) desc="每月执行一次" ;;
            @weekly) desc="每周执行一次" ;;
            @daily|@midnight) desc="每天凌晨执行" ;;
            @hourly) desc="每小时执行一次" ;;
            *) desc="特殊定时标记 $min" ;;
        esac
    else
        case "$min" in
            */*) step="${min#*/}"; min_txt="每${step}分钟" ;;
            *)
                if [ "$min" = "*" ]; then
                    min_txt="每分钟"
                else
                    min_txt="第${min}分"
                fi
            ;;
        esac

        case "$hour" in
            */*) step="${hour#*/}"; hour_txt="每${step}小时" ;;
            *)
                if [ "$hour" = "*" ]; then
                    hour_txt=""
                else
                    hour_txt="${hour}点"
                fi
            ;;
        esac

        case "$min"  in *[-,/*]*) ;; *) is_min_single=1  ;; esac
        case "$hour" in *[-,/*]*) ;; *) is_hour_single=1 ;; esac

        if [ $is_min_single -eq 1 ] && [ $is_hour_single -eq 1 ]; then
            desc="每天 ${hour}:${min} 执行"
        else
            desc="${min_txt}"
            [ -n "$hour_txt" ] && desc="${desc}，${hour_txt}"
        fi

        [ "$day"  != "*" ] && desc="${desc}，每月${day}日"
        [ "$mon"  != "*" ] && desc="${desc}，${mon}月"

        if [ "$week" != "*" ]; then
            w="$week"
            case "$w" in
                0|7) week_txt="周日" ;;
                1)   week_txt="周一" ;;
                2)   week_txt="周二" ;;
                3)   week_txt="周三" ;;
                4)   week_txt="周四" ;;
                5)   week_txt="周五" ;;
                6)   week_txt="周六" ;;
                *)   week_txt="星期${week}" ;;
            esac
            desc="${desc}，${week_txt}"
        fi
    fi
    echo -e "${gl_huang}${desc}${reset}    ${gl_lv}${cmd}${reset}"
}

list_beautify_linux_crontab() {
    {
        printf "%s%-7s\t%-5s\t%-5s\t%-5s\t%-7s\t%-40s%s\n" \
            "$gl_hui" "分钟" "小时" "日期" "月份" "星期" "执行命令" "$reset"
        printf "%s%-7s\t%-5s\t%-5s\t%-5s\t%-7s\t%-40s%s\n" \
            "$gl_hui" "-------" "-----" "-----" "-----" "-------" "----------------------------------------" "$reset"

        parse_crontab | awk -F '\t' \
            -v green="$gl_lv" -v yellow="$gl_huang" \
            -v blue="$gl_lan" -v reset="$reset" '
        BEGIN {OFS="\t"}
        {
            printf "%s%-7s%s\t%s%-5s%s\t%s%-5s%s\t%s%-5s%s\t%s%-7s%s\t%s%-40s%s\n",
                blue,   $1, reset,
                yellow, $2, reset,
                blue,   $3, reset,
                yellow, $4, reset,
                blue,   $5, reset,
                green,  $6, reset
        }'
    } | column_if_available
}

list_cron_desc() {
    echo ""
    echo -e "${gl_zi}>>> 中文详解${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    parse_crontab | while IFS=$'\t' read -r min hour day mon week cmd; do
        cron_desc "$min" "$hour" "$day" "$mon" "$week" "$cmd"
    done
}

list_beautify_all() {
    clear
    echo -e "${gl_zi}>>> Linux定时任务列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_linux_crontab
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_cron_desc
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all