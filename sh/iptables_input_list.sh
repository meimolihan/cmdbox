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

list_beautify_iptables_input() {
    local chain="${1:-INPUT}"
    if ! iptables -L "$chain" -n --line-numbers &>/dev/null; then
        echo -e "\033[1;31m错误: 需要 root 权限或链 $chain 不存在\033[0m" >&2
        return 1
    fi
    local policy_line policy policy_display policy_color
    policy_line=$(iptables -L "$chain" -n 2>/dev/null | head -n1)
    if [[ "$policy_line" =~ \(policy\ ([A-Z]+)\) ]]; then
        policy="${BASH_REMATCH[1]}"
    else
        policy="自定义"
    fi
    case "$policy" in
        ACCEPT) policy_display="允许"; policy_color="\033[1;32m" ;;
        DROP)   policy_display="丢弃"; policy_color="\033[1;31m" ;;
        REJECT) policy_display="拒绝"; policy_color="\033[1;31m" ;;
        自定义) policy_display="自定义"; policy_color="\033[1;33m" ;;
        *)      policy_display="$policy"; policy_color="\033[1;33m" ;;
    esac
    echo -e "\033[1;34m链: $chain\033[0m  策略: ${policy_color}${policy_display}\033[0m\n"

    iptables -L "$chain" -n --line-numbers 2>/dev/null | awk -v green="\033[1;32m" -v red="\033[1;31m" -v yellow="\033[1;33m" -v cyan="\033[1;36m" -v blue="\033[1;34m" -v reset="\033[0m" '
    /^[0-9]/ {
        num = $1; target = $2; prot = $3; source = $5; dest = $6
        port_info = ""
        for (i=7; i<=NF; i++) {
            if ($i ~ /^dpt:/) { port_info = $i; break }
            else if ($i ~ /^spt:/) { port_info = $i; break }
            else if ($i ~ /^multiport/) { port_info = $i; break }
        }
        if (port_info ~ /^dpt:/) port = "→" substr(port_info,4)
        else if (port_info ~ /^spt:/) port = "←" substr(port_info,4)
        else if (port_info ~ /^multiport/) port = "多端口"
        else port = ""

        if (target == "ACCEPT") { t = "允许"; c = green }
        else if (target == "DROP") { t = "丢弃"; c = red }
        else if (target == "REJECT") { t = "拒绝"; c = red }
        else if (target ~ /^f2b-/) { t = "⛓封禁(" substr(target,5) ")"; c = red }
        else { t = target; c = yellow }

        if (prot == "tcp") proto = "TCP"
        else if (prot == "udp") proto = "UDP"
        else if (prot == "all") proto = "全部"
        else proto = prot

        s = (source == "0.0.0.0/0") ? "任意" : source
        d = (dest == "0.0.0.0/0") ? "任意" : dest

        printf "%s%2d%s|%s%-14s%s|%s%-6s%s|%s%-18s%s|%s%-18s%s|%s%-10s%s\n",
            yellow, num, reset,
            c, t, reset,
            cyan, proto, reset,
            blue, s, reset,
            blue, d, reset,
            yellow, port, reset
    }' | sed 's/|/\t/g' | column_if_available
}

list_beautify_all() {
    clear
    echo -e "${gl_zi}>>> iptables中INPUT链规则列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_iptables_input
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all