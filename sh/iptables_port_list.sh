#!/bin/bash
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

# 提取所有iptables端口
list_all_iptables_ports() {
    if ! iptables -L -n &>/dev/null; then
        echo -e "${gl_hong}错误: 需要 root 权限读取 iptables${gl_bai}" >&2
        return 1
    fi

    iptables -L -n --line-numbers 2>/dev/null | awk -v green="\033[1;32m" -v red="\033[1;31m" -v yellow="\033[1;33m" -v cyan="\033[1;36m" -v blue="\033[1;34m" -v reset="\033[0m" '
    function parse_port(val,    arr,n,i) {
        if (val ~ /^dpt:/) {
            val=substr(val,5)
        }
        if (val ~ /^spt:/) {
            val=substr(val,5)
        }
        if (val ~ /multiport/) {
            sub(/.*multiport */,"",val)
            sub(/^(dports|sports) */,"",val)
        }
        gsub(/,/," ",val)
        return val
    }
    /^[0-9]/ {
        target = $2; prot = $3
        source = $5; dest = $6
        port_raw = ""
        for(i=7;i<=NF;i++){
            if ($i ~ /^(dpt:|spt:|multiport)/) {
                port_raw = $i
                for(j=i+1;j<=NF;j++){
                    port_raw = port_raw " " $j
                }
                break
            }
        }
        if(port_raw == "") {
            next
        }

        ports_str = parse_port(port_raw)
        split(ports_str, port_arr, / /)
        for(p in port_arr){
            pval = port_arr[p]
            if(pval ~ /^[0-9]+(-[0-9]+)?$/){
                proto = prot
                if(proto=="tcp") {
                    proto="TCP"
                } else if(proto=="udp") {
                    proto="UDP"
                } else {
                    proto=prot
                }
                tgt = target
                if(tgt=="ACCEPT") {
                    t="允许"; c=green
                } else if(tgt=="DROP") {
                    t="丢弃"; c=red
                } else if(tgt=="REJECT") {
                    t="拒绝"; c=red
                } else {
                    t=tgt; c=yellow
                }
                printf "%s\t%s\t%s\t%s\t%s\n", proto, pval, t, source, dest
            }
        }
    }' | sort -u | awk -v green="\033[1;32m" -v red="\033[1;31m" -v yellow="\033[1;33m" -v cyan="\033[1;36m" -v blue="\033[1;34m" -v reset="\033[0m" '
    BEGIN{
        printf "%s%-6s%s|%s%-12s%s|%s%-10s%s|%s%-18s%s|%s%-18s%s\n",
        cyan,"协议",reset,
        yellow,"端口",reset,
        green,"动作",reset,
        blue,"源地址",reset,
        blue,"目的地址",reset
    }
    {
        proto=$1; port=$2; act=$3; src=$4; dst=$5
        if(act=="允许") {
            c=green
        } else if(act=="丢弃" || act=="拒绝") {
            c=red
        } else {
            c=yellow
        }
        s = (src == "0.0.0.0/0") ? "任意" : src
        d = (dst == "0.0.0.0/0") ? "任意" : dst
        printf "%s%-6s%s|%s%-12s%s|%s%-10s%s|%s%-18s%s|%s%-18s%s\n",
        cyan,proto,reset,
        yellow,port,reset,
        c,act,reset,
        blue,s,reset,
        blue,d,reset
    }' | sed 's/|/\t/g' | column_if_available
}

list_beautify_all() {
    clear
    echo -e "${gl_zi}>>> iptables 所有端口规则汇总${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    local out
    out=$(list_all_iptables_ports)
    if [[ -z "$out" ]]; then
        echo -e "${gl_huang}>>> iptables 未找到任何带端口匹配的规则${gl_bai}"
    else
        echo "$out"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all