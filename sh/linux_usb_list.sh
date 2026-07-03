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

list_beautify_linux_usb() {
    {
        printf "%s%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "总线" "设备" "厂商" "产品" "描述" "$reset"
        printf "%s%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "--------" "--------" "--------" "--------" "--------" "$reset"

        data=$(lsusb 2>/dev/null)
        if [ -z "$data" ]; then
            printf "%s%s\t%s\t%s\t%s\t%s%s\n" "$gl_huang" "(无数据)" "(无数据)" "(无数据)" "(无数据)" "(无数据)" "$reset"
        else
            echo "$data" | awk -v bus_color="$gl_bufan" \
                               -v dev_color="$gl_lv" \
                               -v vendor_color="$gl_huang" \
                               -v product_color="$gl_lan" \
                               -v desc_color="$gl_hui" \
                               -v reset="$reset" '
            BEGIN {
                FS="[[:space:]]+";
                OFS="\t"
            }
            {
                bus = $2
                dev = $4
                gsub(/^0+/, "", bus)
                gsub(/^0+/, "", dev)
                gsub(/:$/, "", dev)

                vendor = $6
                product = ""

                desc_start = 7
                len = length(vendor)
                if (len == 9) {
                    product = $7
                    desc_start = 8
                } else if (len == 4) {
                    product = ""
                    desc_start = 6
                }

                desc = ""
                for (i = desc_start; i <= NF; i++) {
                    if (desc == "") {
                        desc = $i
                    } else {
                        desc = desc " " $i
                    }
                }

                print bus_color bus reset,
                      dev_color dev reset,
                      vendor_color vendor reset,
                      product_color product reset,
                      desc_color desc reset
            }'
        fi
    } | column_if_available
}

list_beautify_all() {
    clear
    echo -e "${gl_zi}>>> Linux USB设备列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_linux_usb
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all
