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

list_beautify_linux_io() {
    {
        printf "%s%s\t%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "设备" "读/s" "写/s" "读kB/s" "写kB/s" "等待" "使用率" "$reset"
        printf "%s%s\t%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "--------" "--------" "--------" "--------" "--------" "--------" "--------" "$reset"

        if command -v iostat &> /dev/null; then
            data=$(iostat -x 2>/dev/null | awk 'NR>2 && /^[a-z]/ {print $1, $4, $5, $6, $7, $10, $12}' 2>/dev/null)
        else
            data=$(cat /proc/diskstats 2>/dev/null | awk '$3 ~ /^[a-z]+$/ && $3 !~ /loop|ram/ {
                device=$3; rs=$4; ws=$8;
                rkb=$6*512/1024; wkb=$10*512/1024;
                await_t=($7+$11)/($4+$8+0.01);
                printf "%s %.0f %.0f %.1f %.1f %.1f 0.0\n", device, rs, ws, rkb, wkb, await_t
            }')
        fi

        if [ -z "$data" ]; then
            printf "%s%s\t%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_huang" "(无数据)" "(无数据)" "(无数据)" "(无数据)" "(无数据)" "(无数据)" "(无数据)" "$reset"
        else
            echo "$data" | awk -v dev_color="$gl_lan" \
                               -v rs_color="$gl_lv" \
                               -v ws_color="$gl_bufan" \
                               -v rkb_color="$gl_lv" \
                               -v wkb_color="$gl_bufan" \
                               -v await_color="$gl_huang" \
                               -v util_color="$gl_huang" \
                               -v gl_hong_io="$gl_hong" \
                               -v reset="$reset" '
            BEGIN {
                FS="[[:space:]]+";
                OFS="\t"
            }
            {
                device = $1
                rs = $2
                ws = $3
                rkb = $4
                wkb = $5
                await = $6
                util = $7

                await_color_actual = await_color
                if (await + 0 > 100) {
                    await_color_actual = gl_hong_io
                } else if (await + 0 > 50) {
                    await_color_actual = "\033[38;5;11m"
                }

                util_color_actual = util_color
                if (util + 0 > 80) {
                    util_color_actual = gl_hong_io
                } else if (util + 0 > 50) {
                    util_color_actual = "\033[38;5;11m"
                }

                print dev_color device reset,
                      rs_color rs reset,
                      ws_color ws reset,
                      rkb_color rkb reset,
                      wkb_color wkb reset,
                      await_color_actual await reset,
                      util_color_actual util "%" reset
            }'
        fi
    } | column_if_available
}

list_beautify_all() {
    clear
    echo -e "${gl_zi}>>> Linux磁盘I/O列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_linux_io
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all
