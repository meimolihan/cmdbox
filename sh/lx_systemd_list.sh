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

list_beautify_linux_systemd() {
    {
        printf "%s%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "单元" "加载" "激活" "子状态" "描述" "$reset"
        printf "%s%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "--------" "--------" "--------" "--------" "--------" "$reset"

        data=$(systemctl list-units --type=service --all --no-legend 2>/dev/null | head -n 50)
        if [ -z "$data" ]; then
            printf "%s%s\t%s\t%s\t%s\t%s%s\n" "$gl_huang" "(无数据)" "(无数据)" "(无数据)" "(无数据)" "(无数据)" "$reset"
        else
            echo "$data" | awk -v unit_color="$gl_lan" \
                               -v load_color="$gl_bufan" \
                               -v active_color="$gl_lv" \
                               -v substate_color="$gl_huang" \
                               -v desc_color="$gl_hui" \
                               -v reset="$reset" '
            BEGIN {
                FS="[[:space:]]+";
                OFS="\t"
            }
            {
                unit = $1
                load = $2
                active = $3
                substate = $4
                desc = ""
                for (i=5; i<=NF; i++) {
                    if (desc == "") desc = $i; else desc = desc " " $i
                }

                act_color = active_color
                if (active == "active" && substate == "running") {
                    act_color = active_color
                } else if (active == "failed") {
                    act_color = "\033[38;5;9m"
                } else if (active == "inactive") {
                    act_color = "\033[38;5;59m"
                }

                sub_color = substate_color
                if (substate == "running") {
                    sub_color = "\033[38;5;10m"
                } else if (substate == "failed") {
                    sub_color = "\033[38;5;9m"
                } else if (substate == "exited") {
                    sub_color = "\033[38;5;11m"
                }

                if (load == "loaded") load = "已加载"
                else if (load == "not-found") load = "未找到"
                else if (load == "bad") load = "错误"

                if (active == "active") active = "已激活"
                else if (active == "inactive") active = "未激活"
                else if (active == "failed") active = "失败"

                if (substate == "running") substate = "运行中"
                else if (substate == "exited") substate = "已退出"
                else if (substate == "dead") substate = "已停止"
                else if (substate == "waiting") substate = "等待中"
                else if (substate == "activating") substate = "激活中"
                else if (substate == "deactivating") substate = "停用中"

                print unit_color unit reset,
                      load_color load reset,
                      act_color active reset,
                      sub_color substate reset,
                      desc_color desc reset
            }'
        fi
    } | column_if_available
}

list_beautify_all() {
    clear
    echo -e "${gl_zi}>>> Linux Systemd服务列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_linux_systemd
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all
