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

list_beautify_linux_nic() {
    {
        printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "接口名" "状态" "IPv4地址" "MAC地址" "MTU" "速度" "$reset"
        printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "--------" "--------" "------------------" "--------------------" "----" "----" "$reset"

        for nic in $(ls /sys/class/net 2>/dev/null); do
            state=$(cat /sys/class/net/$nic/operstate 2>/dev/null)
            ipaddr=$(ip -4 addr show $nic 2>/dev/null | awk '/inet /{print $2}' | head -n1)
            mac=$(cat /sys/class/net/$nic/address 2>/dev/null)
            mtu=$(cat /sys/class/net/$nic/mtu 2>/dev/null)
            speed_path="/sys/class/net/$nic/speed"
            if [ -f "$speed_path" ]; then
                speed=$(cat "$speed_path" 2>/dev/null)
                if [[ "$speed" =~ ^[0-9]+$ ]] && [ "$speed" -gt 0 ]; then
                    speed="${speed}Mb/s"
                else
                    speed="未知"
                fi
            else
                speed="N/A"
            fi
            
            state=${state:-unknown}
            ipaddr=${ipaddr:-无}
            mac=${mac:-无}
            mtu=${mtu:-未知}
            
            case $state in
                "up")
                    state_color=$gl_lv
                    state_display="${state_color}up$reset"
                    ;;
                "down")
                    state_color=$gl_hui
                    state_display="${state_color}down$reset"
                    ;;
                "unknown")
                    state_color=$gl_hong
                    state_display="${state_color}unknown$reset"
                    ;;
                *)
                    state_color=$gl_huang
                    state_display="${state_color}$state$reset"
                    ;;
            esac
            
            printf "%s%s%s\t%s\t%s%s%s\t%s%s%s\t%s%s%s\t%s%s%s\n" \
                "$gl_lan" "$nic" "$reset" \
                "$state_display" \
                "$gl_bufan" "$ipaddr" "$reset" \
                "$gl_huang" "$mac" "$reset" \
                "$gl_zi" "$mtu" "$reset" \
                "$gl_hui" "$speed" "$reset"
        done
        
        if [ -z "$(ls /sys/class/net 2>/dev/null)" ]; then
            printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hong" "(无网络接口)" "(无网络接口)" "(无网络接口)" "(无网络接口)" "(无网络接口)" "(无网络接口)" "$reset"
        fi
    } | column_if_available
}

list_beautify_all() {
    clear
    echo -e "${gl_zi}>>> Linux网卡信息列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_linux_nic
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all