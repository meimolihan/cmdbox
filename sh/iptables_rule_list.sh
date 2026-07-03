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

list_beautify_iptables_rule_list() {
    {
        if ! iptables -L -n --line-numbers &>/dev/null; then
            echo -e "${gl_hong}错误: 需要 root 权限运行 iptables${reset}"
            return 1
        fi
        
        output=$(iptables -L -n --line-numbers 2>/dev/null)
        if [ -z "$output" ]; then
            echo -e "${gl_huang}iptables 规则为空${reset}"
            return 0
        fi
        
        echo "$output" | awk -v green="$gl_lv" -v red="$gl_hong" -v yellow="$gl_huang" \
            -v cyan="$gl_bufan" -v blue="$gl_lan" -v reset="$reset" '
        /^Chain / {
            chain = $2
            policy = ""
            for (i=4; i<=NF; i++) {
                if ($i == "(policy") {
                    policy = $(i+1)
                    gsub(/[()]/, "", policy)
                    break
                }
            }
            if (policy == "") {
                for (i=4; i<=NF; i++) {
                    if ($i == "references" || $i ~ /^[0-9]+$/) {
                        policy = "自定义"
                        break
                    }
                }
            }
            if (chain == "INPUT") {
                chain_display = "入站"
                chain_color = blue
            } else if (chain == "OUTPUT") {
                chain_display = "出站"
                chain_color = blue
            } else if (chain == "FORWARD") {
                chain_display = "转发"
                chain_color = blue
            } else if (chain ~ /^f2b-/) {
                chain_display = "⛓" chain
                chain_color = red
            } else if (chain ~ /^DOCKER/) {
                chain_display = "🐳" chain
                chain_color = cyan
            } else {
                chain_display = "🔗" chain
                chain_color = blue
            }
            if (policy == "ACCEPT") {
                policy_display = "允许"
                policy_color = green
            } else if (policy == "DROP") {
                policy_display = "丢弃"
                policy_color = red
            } else if (policy == "REJECT") {
                policy_display = "拒绝"
                policy_color = red
            } else if (policy == "1" || policy == "references" || policy == "自定义") {
                policy_display = "自定义"
                policy_color = yellow
            } else {
                policy_display = policy
                policy_color = yellow
            }
            printf "%s%s%s  策略: %s%s%s\n\n", chain_color, chain_display, reset, policy_color, policy_display, reset
        }
        
        /^[0-9]/ && NF >= 6 {
            num = $1
            target = $2
            source = $5
            dest = $6
            
            ports = ""
            for (i=7; i<=NF; i++) {
                if ($i ~ /dpt:[0-9]+/) {
                    match($i, /dpt:[0-9]+/)
                    ports = substr($i, RSTART+4, RLENGTH-4)
                    break
                } else if ($i ~ /multiport/) {
                    ports = "多端口"
                    break
                }
            }
            
            if (source == "0.0.0.0/0" && dest == "0.0.0.0/0" && ports == "" && target == "ACCEPT") {
                next
            }
            
            if (target == "ACCEPT") {
                target_display = "✓允许"
                target_color = green
            } else if (target == "DROP") {
                target_display = "✗丢弃"
                target_color = red
            } else if (target == "REJECT") {
                target_display = "✗拒绝"
                target_color = red
            } else if (target == "LOG") {
                target_display = "📋日志"
                target_color = cyan
            } else if (target == "RETURN") {
                target_display = "↩返回"
                target_color = yellow
            } else if (target ~ /DNAT|SNAT|MASQUERADE/) {
                target_display = "↔NAT"
                target_color = cyan
            } else if (target ~ /^f2b-/) {
                target_display = "⛓封禁"
                target_color = red
            } else if (target ~ /^DOCKER-/) {
                target_display = "🐳Docker"
                target_color = cyan
            } else {
                target_display = "•" target
                target_color = yellow
            }
            
            if (source == "0.0.0.0/0") source = ""
            if (dest == "0.0.0.0/0") dest = ""
            if (source != "" && dest != "") {
                addr = source "→" dest
            } else if (source != "") {
                addr = source
            } else if (dest != "") {
                addr = "→" dest
            } else {
                addr = ""
            }
            
            if (ports != "") {
                ports_display = "端口:" ports
            } else {
                ports_display = ""
            }
            
            printf "  %s%2s%s\t", yellow, num, reset
            printf "%s%-8s%s\t", target_color, target_display, reset
            printf "%s%s%s\t", cyan, addr, reset
            if (ports_display != "") {
                printf "%s%s%s", yellow, ports_display, reset
            } else {
                printf "%s", reset
            }
            printf "\n"
        }'
        
    } | column_if_available
}

list_beautify_all() {
    clear
    echo -e "${gl_zi}>>> iptables所有规则列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_iptables_rule_list
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all