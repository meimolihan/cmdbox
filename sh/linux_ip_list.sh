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

list_beautify_linux_ip() {
    {
        printf "%s%s\t%s\t%s\t%s%s\n" "$gl_hui" "接口" "状态" "IP地址" "路由" "$reset"
        printf "%s%s\t%s\t%s\t%s%s\n" "$gl_hui" "--------" "--------" "--------" "--------" "$reset"

        data=$(ip -o addr show 2>/dev/null | grep -v "fe80\|127.0.0.1" | head -20)
        if [ -z "$data" ]; then
            printf "%s%s\t%s\t%s\t%s%s\n" "$gl_huang" "(无数据)" "(无数据)" "(无数据)" "(无数据)" "$reset"
        else
            interfaces=$(ip -o addr show | awk '{print $2}' | sed 's/://' | sort -u)
            for iface in $interfaces; do
                state=$(ip link show "$iface" 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="state") print $(i+1)}')
                mac=$(ip link show "$iface" 2>/dev/null | awk '/link\/ether/{print $2}')
                ipv4=$(ip -o addr show "$iface" 2>/dev/null | awk '$3=="inet"{print $4; exit}')
                ipv6=$(ip -o addr show "$iface" 2>/dev/null | awk '$3=="inet6" && $4!~"fe80"{print $4; exit}')
                ip_str=""
                [ -n "$ipv4" ] && ip_str="$ipv4"
                [ -n "$ipv6" ] && ip_str="${ip_str:+$ip_str, }$ipv6"
                [ -z "$ip_str" ] && ip_str="--"

                printf "%s%s\t%s%s\t%s%s\t" "$gl_lan" "$iface" "$reset" \
                       "$([ "$state" = "UP" ] && echo "${gl_lv}启用${reset}" || echo "${gl_hong}停用${reset}")" \
                       "$gl_bufan" "$ip_str$reset"
                mac_str="${mac:---}"
                printf "%s%s\t%s%s\n" "$gl_hui" "$mac_str" "$reset"
            done
        fi

        echo -e "${gl_zi}--- 路由表 ---${gl_bai}"
        printf "%s%s\t%s\t%s%s\n" "$gl_hui" "目标" "网关" "接口" "$reset"
        printf "%s%s\t%s\t%s%s\n" "$gl_hui" "--------" "--------" "--------" "$reset"

        route_data=$(ip route show 2>/dev/null | head -20)
        if [ -z "$route_data" ]; then
            printf "%s%s\t%s\t%s%s\n" "$gl_huang" "(无路由)" "(无路由)" "(无路由)" "$reset"
        else
            echo "$route_data" | while IFS= read -r line; do
                dest=$(echo "$line" | awk '{print $1}')
                gateway=$(echo "$line" | awk '{print $3}')
                dev=$(echo "$line" | awk '{print $5}')
                [ "$dest" = "default" ] && dest="默认"
                [ -z "$gateway" ] && gateway="直连"
                printf "%s%s\t%s%s\t%s%s\n" "$gl_lv" "$dest$reset" \
                       "$gl_huang" "$gateway$reset" \
                       "$gl_lan" "${dev:---}$reset"
            done
        fi
    } | column_if_available
}

list_beautify_all() {
    clear
    echo -e "${gl_zi}>>> Linux IP地址与路由列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_linux_ip
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all
