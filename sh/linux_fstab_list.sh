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

list_beautify_linux_fstab() {
    if [ ! -f /etc/fstab ]; then
        printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hong" "(无 /etc/fstab)" "(无 /etc/fstab)" "(无 /etc/fstab)" "(无 /etc/fstab)" "(无 /etc/fstab)" "(无 /etc/fstab)" "$reset"
        return
    fi

    if [ ! -s /etc/fstab ]; then
        printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_huang" "(空文件)" "(空文件)" "(空文件)" "(空文件)" "(空文件)" "(空文件)" "$reset"
        return
    fi

    {
        printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "设备" "挂载点" "类型" "选项" "备份" "自检" "$reset"
        printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "--------" "--------" "--------" "--------" "--------" "--------" "$reset"

        while IFS= read -r line || [ -n "$line" ]; do
            line=$(echo "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
            [ -z "$line" ] && continue

            if echo "$line" | grep -q "^\s*#"; then
                printf "%s%s%s\n" "$gl_hui" "$line" "$reset"
                continue
            fi

            device=$(echo "$line" | awk '{print $1}')
            mount=$(echo "$line" | awk '{print $2}')
            fstype=$(echo "$line" | awk '{print $3}')
            options=$(echo "$line" | awk '{print $4}')
            dump=$(echo "$line" | awk '{print $5}')
            pass=$(echo "$line" | awk '{print $6}')

            [ -z "$device" ] && continue

            if echo "$fstype" | grep -qi "ext\|xfs\|btrfs\|zfs"; then
                type_color="$gl_lv"
            elif echo "$fstype" | grep -qi "swap"; then
                type_color="$gl_huang"
            elif echo "$fstype" | grep -qi "ntfs\|vfat\|fat\|exfat"; then
                type_color="$gl_bufan"
            else
                type_color="$gl_hui"
            fi

            printf "%s%s\t%s%s\t%s%s\t%s%s\t%s%s\t%s%s%s\n" \
                "$gl_lan" "$device" \
                "$gl_bai" "$mount" \
                "$type_color" "$fstype" \
                "$gl_hui" "$options" \
                "$gl_lv" "$dump" \
                "$gl_huang" "$pass" \
                "$reset"
        done < /etc/fstab
    } | column_if_available
}

list_beautify_all() {
    clear
    echo -e "${gl_zi}>>> Linux fstab 挂载配置列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_linux_fstab
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all
