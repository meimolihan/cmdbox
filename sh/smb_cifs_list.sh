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

list_beautify_smb_cifs() {
    {
        printf "%s%s\t%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "文件系统" "类型" "容量" "已用" "可用" "使用占比" "挂载点" "$reset"
        printf "%s%s\t%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "--------" "----" "--------" "--------" "--------" "--------" "--------" "$reset"

        data=$(df -hT | grep -E "(cifs|smb)" 2>/dev/null)
        if [ -z "$data" ]; then
            printf "%s%s\t%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_huang" "(无SMB/CIFS挂载)" "" "" "" "" "" "" "$reset"
        else
            echo "$data" | awk -v fs_color="$gl_lan" \
                                -v type_color="$gl_zi" \
                                -v size_color="$gl_lv" \
                                -v used_color="$gl_huang" \
                                -v avail_color="$gl_bufan" \
                                -v use_color="$gl_hong" \
                                -v mount_color="$gl_hui" \
                                -v reset="$reset" '
            BEGIN {
                FS="[[:space:]]+";
                OFS="\t"
            }
            {
                filesystem = $1
                fstype = $2
                size = $3
                used = $4
                avail = $5
                use_percent = $6
                mount = $7
                for (i=8; i<=NF; i++) {
                    mount = mount " " $i
                }

                print fs_color filesystem reset,
                      type_color fstype reset,
                      size_color size reset,
                      used_color used reset,
                      avail_color avail reset,
                      use_color use_percent reset,
                      mount_color mount reset
            }'
        fi
    } | column_if_available
}

list_smb_cifs_all() {
    clear
    echo -e "${gl_zi}>>> SMB/CIFS网络共享挂载列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_smb_cifs
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_smb_cifs_all
