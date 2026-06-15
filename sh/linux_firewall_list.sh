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

list_beautify_linux_firewall() {
    tables="filter nat mangle"
    for table in $tables; do
        raw=$(iptables -t "$table" -L -n -v 2>/dev/null)
        [ -z "$raw" ] && continue

        has_rules=$(echo "$raw" | awk '/^[[:space:]]*[0-9]/{c++} END{print c}')
        [ "$has_rules" -eq 0 ] && continue

        echo -e "${gl_zi}--- 表: $table ---${gl_bai}"

        {
            printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "链" "策略" "目标" "协议" "源地址" "目的地址" "$reset"
            printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "--------" "--------" "--------" "--------" "--------" "--------" "$reset"

            chains=$(echo "$raw" | awk '/^Chain /{print $2}')
            for chain in $chains; do
                chain_rules=$(iptables -t "$table" -L "$chain" -n -v 2>/dev/null)
                policy=$(echo "$chain_rules" | head -1 | awk -F'policy ' '{print $2}' | awk '{print $1}')
                [ -z "$policy" ] && policy="ACCEPT"

                case "$policy" in
                    ACCEPT) policy_disp="允许"; policy_color="${gl_lv}" ;;
                    DROP) policy_disp="丢弃"; policy_color="${gl_hong}" ;;
                    *) policy_disp="$policy"; policy_color="${gl_huang}" ;;
                esac

                echo "$chain_rules" | tail -n +3 | awk -v chain_color="${gl_lan}${chain}${reset}" \
                    -v policy_color="$policy_color" \
                    -v policy_disp="$policy_disp" \
                    -v gl_lv="$gl_lv" \
                    -v gl_hong="$gl_hong" \
                    -v gl_huang="$gl_huang" \
                    -v gl_lan="$gl_lan" \
                    -v gl_hui="$gl_hui" \
                    -v gl_bufan="$gl_bufan" \
                    -v gl_bai="$gl_bai" \
                    -v reset="$reset" '
                NF >= 6 {
                    target = $3
                    prot = $4
                    src = $5
                    dst = $6

                    if (target == "ACCEPT") { tcol = gl_lv; tdisp = "允许" }
                    else if (target == "DROP") { tcol = gl_hong; tdisp = "丢弃" }
                    else if (target == "REJECT") { tcol = gl_hong; tdisp = "拒绝" }
                    else { tcol = gl_huang; tdisp = target }

                    if (prot == "tcp") { pcol = gl_lan; pdisp = "TCP" }
                    else if (prot == "udp") { pcol = gl_lan; pdisp = "UDP" }
                    else if (prot == "all") { pcol = gl_hui; pdisp = "全部" }
                    else { pcol = gl_bufan; pdisp = prot }

                    print chain_color "\t" \
                          policy_color policy_disp reset "\t" \
                          tcol tdisp reset "\t" \
                          pcol pdisp reset "\t" \
                          gl_bai src reset "\t" \
                          gl_bai dst reset
                }'
            done
        } | column_if_available
    done
}

list_beautify_all() {
    clear
    echo -e "${gl_zi}>>> Linux防火墙规则列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_linux_firewall
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all
