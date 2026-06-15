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

list_beautify_linux_raid() {
    if [ ! -f /proc/mdstat ] || ! grep -q "^md" /proc/mdstat 2>/dev/null; then
        printf "%s%s\t%s\t%s\t%s\t%s%s\n" "$gl_huang" "(无RAID阵列)" "(无RAID阵列)" "(无RAID阵列)" "(无RAID阵列)" "(无RAID阵列)" "$reset"
        return
    fi

    {
        printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "阵列名" "级别" "大小" "活动数" "状态" "成员" "$reset"
        printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "--------" "--------" "--------" "--------" "--------" "--------" "$reset"

        while IFS= read -r line; do
            if echo "$line" | grep -q "^md"; then
                md_name=$(echo "$line" | awk '{print $1}')
                md_level=$(echo "$line" | awk '{print $2}')
                md_status=$(echo "$line" | awk '{print $NF}')
                md_disks=$(echo "$line" | awk '{for(i=3;i<NF-2;i++) printf "%s ", $i; print ""}' | sed 's/\[[^]]*\]//g; s/  */ /g; s/^ *//; s/ *$//')

                md_size=""
                if command -v mdadm &> /dev/null; then
                    detail=$(mdadm --detail "/dev/$md_name" 2>/dev/null)
                    md_size=$(echo "$detail" | grep "Array Size" | awk '{print $4}')
                    if [ -n "$md_size" ]; then
                        md_size=$(( md_size / 1024 )) "M"
                    fi
                    active_devices=$(echo "$detail" | grep "Working Devices" | awk '{print $4}')
                    total_devices=$(echo "$detail" | grep "Total Devices" | awk '{print $4}')
                    md_active="${active_devices}/${total_devices}"
                else
                    md_active="?"
                    md_size="?"
                fi

                if [ "$md_status" = "UU" ] || [ "$md_status" = "normal" ]; then
                    status_color="$gl_lv"
                    status_text="正常"
                elif [ "$md_status" = "_" ] || echo "$md_status" | grep -q "_"; then
                    status_color="$gl_huang"
                    status_text="降级"
                else
                    status_color="$gl_hong"
                    status_text="故障"
                fi

                printf "%s%s\t%s%s\t%s%s\t%s%s\t%s%s\t%s%s%s\n" \
                    "$gl_lan" "$md_name" \
                    "$gl_bufan" "$md_level" \
                    "$gl_lv" "$md_size" \
                    "$gl_bai" "$md_active" \
                    "$status_color" "$status_text" \
                    "$gl_hui" "$md_disks" "$reset"
            fi
        done < /proc/mdstat
    } | column_if_available
}

list_beautify_all() {
    clear
    echo -e "${gl_zi}>>> Linux RAID状态列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_linux_raid
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all
