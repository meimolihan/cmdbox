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

list_beautify_linux_lvm_pv() {
    if ! command -v pvs &> /dev/null; then
        printf "%s%s\t%s\t%s\t%s%s\n" "$gl_hong" "(缺少 pvs 命令)" "(缺少 pvs 命令)" "(缺少 pvs 命令)" "(缺少 pvs 命令)" "$reset"
        return
    fi

    data=$(pvs 2>/dev/null | tail -n +2)
    if [ -z "$data" ]; then
        printf "%s%s\t%s\t%s\t%s%s\n" "$gl_huang" "(无物理卷)" "(无物理卷)" "(无物理卷)" "(无物理卷)" "$reset"
    else
        echo "$data" | awk -v pv_color="$gl_lan" \
                            -v vg_color="$gl_bufan" \
                            -v size_color="$gl_lv" \
                            -v free_color="$gl_huang" \
                            -v reset="$reset" '
        BEGIN {
            FS="[[:space:]]+";
            OFS="\t"
        }
        {
            pv = $1
            vg = $2
            psize = $3
            pfree = $4
            if (NF >= 6) {
                psize = $3
                pfree = $4
            }

            print pv_color pv reset,
                  vg_color vg reset,
                  size_color psize reset,
                  free_color pfree reset
        }'
    fi
}

list_beautify_linux_lvm_vg() {
    if ! command -v vgs &> /dev/null; then
        printf "%s%s\t%s\t%s%s\n" "$gl_hong" "(缺少 vgs 命令)" "(缺少 vgs 命令)" "(缺少 vgs 命令)" "$reset"
        return
    fi

    data=$(vgs 2>/dev/null | tail -n +2)
    if [ -z "$data" ]; then
        printf "%s%s\t%s\t%s%s\n" "$gl_huang" "(无卷组)" "(无卷组)" "(无卷组)" "$reset"
    else
        echo "$data" | awk -v vg_color="$gl_lan" \
                            -v size_color="$gl_lv" \
                            -v free_color="$gl_huang" \
                            -v reset="$reset" '
        BEGIN {
            FS="[[:space:]]+";
            OFS="\t"
        }
        {
            vg = $1
            vsize = $2
            vfree = $3

            print vg_color vg reset,
                  size_color vsize reset,
                  free_color vfree reset
        }'
    fi
}

list_beautify_linux_lvm_lv() {
    if ! command -v lvs &> /dev/null; then
        printf "%s%s\t%s\t%s%s\n" "$gl_hong" "(缺少 lvs 命令)" "(缺少 lvs 命令)" "(缺少 lvs 命令)" "$reset"
        return
    fi

    data=$(lvs 2>/dev/null | tail -n +2)
    if [ -z "$data" ]; then
        printf "%s%s\t%s\t%s%s\n" "$gl_huang" "(无逻辑卷)" "(无逻辑卷)" "(无逻辑卷)" "$reset"
    else
        echo "$data" | awk -v lv_color="$gl_zi" \
                            -v vg_color="$gl_bufan" \
                            -v size_color="$gl_lv" \
                            -v reset="$reset" '
        BEGIN {
            FS="[[:space:]]+";
            OFS="\t"
        }
        {
            lv = $1
            vg = $2
            lsize = $4

            print lv_color lv reset,
                  vg_color vg reset,
                  size_color lsize reset
        }'
    fi
}

list_beautify_all() {
    clear
    echo -e "${gl_zi}>>> Linux LVM 物理卷 (PV)${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    {
        printf "%s%s\t%s\t%s\t%s%s\n" "$gl_hui" "物理卷" "卷组" "体积" "空闲" "$reset"
        printf "%s%s\t%s\t%s\t%s%s\n" "$gl_hui" "--------" "--------" "--------" "--------" "$reset"
        list_beautify_linux_lvm_pv
    } | column_if_available

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_zi}>>> Linux LVM 卷组 (VG)${gl_bai}"
    {
        printf "%s%s\t%s\t%s%s\n" "$gl_hui" "卷组" "体积" "空闲" "$reset"
        printf "%s%s\t%s\t%s%s\n" "$gl_hui" "--------" "--------" "--------" "$reset"
        list_beautify_linux_lvm_vg
    } | column_if_available

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_zi}>>> Linux LVM 逻辑卷 (LV)${gl_bai}"
    {
        printf "%s%s\t%s\t%s%s\n" "$gl_hui" "逻辑卷" "卷组" "大小" "$reset"
        printf "%s%s\t%s\t%s%s\n" "$gl_hui" "--------" "--------" "--------" "$reset"
        list_beautify_linux_lvm_lv
    } | column_if_available

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all
