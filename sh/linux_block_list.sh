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

list_beautify_linux_block() {
    {
        printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "设备" "容量" "类型" "挂载点" "文件系统" "型号" "$reset"
        printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "--------" "--------" "--------" "--------" "--------" "--------" "$reset"

        data=$(lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE,MODEL 2>/dev/null | tail -n +2)
        if [ -z "$data" ]; then
            printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_huang" "(无数据)" "(无数据)" "(无数据)" "(无数据)" "(无数据)" "(无数据)" "$reset"
        else
            echo "$data" | awk -v name_color="$gl_lan" \
                              -v size_color="$gl_lv" \
                              -v type_color="$gl_bufan" \
                              -v mount_color="$gl_lv" \
                              -v fs_color="$gl_huang" \
                              -v model_color="$gl_hui" \
                              -v reset="$reset" '
            BEGIN {
                FS="[[:space:]]+";
                OFS="\t"
            }
            {
                name = $1
                size = $2
                type = $3
                mount = $4
                fstype = $5
                model = ""
                for (i=6; i<=NF; i++) {
                    model = model " " $i
                }
                sub(/^ /, "", model)
                if (model == "") model = "--"

                print name_color name reset,
                      size_color size reset,
                      type_color type reset,
                      mount_color mount reset,
                      fs_color fstype reset,
                      model_color model reset
            }'
        fi
    } | column_if_available
}

list_beautify_all() {
    clear
    echo -e "${gl_zi}>>> Linux块设备列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_linux_block
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all
