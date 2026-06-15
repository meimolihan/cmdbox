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

        awk '/^md/{name=$1; level=$4; status=$3; disks=""; for(i=5;i<=NF;i++){gsub(/\[[0-9]+\]/,"",$i); disks=disks $i " "}; getline; size=$1; split($5,arr,"/"); active=arr[1]; total=arr[2]; print name,level,size,active"/"total,status,disks}' /proc/mdstat | \
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            md_name=$(echo "$line" | awk '{print $1}')
            md_level=$(echo "$line" | awk '{print $2}')
            md_size=$(echo "$line" | awk '{print $3}')
            md_active=$(echo "$line" | awk '{print $4}')
            md_status=$(echo "$line" | awk '{print $5}')
            md_disks=$(echo "$line" | awk '{for(i=6;i<=NF;i++) printf "%s ", $i}' | sed 's/ *$//')

            # Strip "md" prefix then re-add to ensure consistent format
            md_name="md${md_name#md}"

            case "$md_status" in
                active) status_color="$gl_lv"; status_text="正常" ;;
                *) status_color="$gl_hong"; status_text="$md_status" ;;
            esac

            if [ -n "$md_size" ] && [ "$md_size" -eq "$md_size" ] 2>/dev/null; then
                md_size=$(( md_size / 1024 ))M
            else
                md_size="?"
            fi

            md_disks=$(echo "$md_disks" | sed 's/\[[^]]*\]//g')

            printf "%s%s\t%s%s\t%s%s\t%s%s\t%s%s\t%s%s%s\n" \
                "$gl_lan" "$md_name" \
                "$gl_bufan" "$md_level" \
                "$gl_lv" "$md_size" \
                "$gl_bai" "$md_active" \
                "$status_color" "$status_text" \
                "$gl_hui" "$md_disks" "$reset"
        done
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
