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

list_beautify_linux_tcp() {
    {
        printf "%s%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "协议" "监听地址" "端口" "状态" "进程" "$reset"
        printf "%s%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "--------" "--------" "--------" "--------" "--------" "$reset"

        (
            ss -tlnp 2>/dev/null | tail -n +2 | sed 's/^/tcp /'
            ss -ulnp 2>/dev/null | tail -n +2 | sed 's/^/udp /'
        ) | awk -v proto_color="$gl_bufan" \
                -v addr_color="$gl_lan" \
                -v port_color="$gl_huang" \
                -v state_color="$gl_lv" \
                -v proc_color="$gl_hui" \
                -v reset="$reset" '
        BEGIN {
            FS="[[:space:]]+";
            OFS="\t"
        }
        NF >= 6 {
            proto = $1
            state = $2
            local_full = $5

            n = split(local_full, parts, ":")
            port = parts[n]

            addr = substr(local_full, 1, length(local_full) - length(port) - 1)

            if (addr ~ /^\[.*\]$/) {
                addr = substr(addr, 2, length(addr) - 2)
            }

            if (addr == "" || addr == "*") addr = "0.0.0.0"

            process = ""
            for (i = 7; i <= NF; i++) {
                if (i > 7) process = process " "
                process = process $i
            }

            gsub(/^users:\(\(/, "", process)
            gsub(/\)\)$/, "", process)

            proc_clean = ""
            if (process != "") {
                n_entries = split(process, entries, /\),\(/)
                for (i = 1; i <= n_entries; i++) {
                    gsub(/^"|"$/, "", entries[i])
                    split(entries[i], fields, ",")
                    name = fields[1]
                    gsub(/"/, "", name)
                    gsub(/^[[:space:]]*|[[:space:]]*$/, "", name)
                    if (name != "") {
                        if (proc_clean != "") proc_clean = proc_clean ", "
                        proc_clean = proc_clean name
                    }
                }
            }
            if (proc_clean == "") proc_clean = "-"

            if (state == "LISTEN") state_disp = "监听"
            else if (state == "UNCONN") state_disp = "未连接"
            else if (state == "ESTAB") state_disp = "已建立"
            else if (state == "TIME_WAIT") state_disp = "超时等待"
            else if (state == "CLOSE_WAIT") state_disp = "关闭等待"
            else if (state == "SYN_SENT") state_disp = "SYN已发"
            else if (state == "SYN_RECV") state_disp = "SYN收到"
            else if (state == "FIN_WAIT1") state_disp = "结束等待1"
            else if (state == "FIN_WAIT2") state_disp = "结束等待2"
            else if (state == "LAST_ACK") state_disp = "最后确认"
            else if (state == "CLOSING") state_disp = "关闭中"
            else if (state == "CLOSED") state_disp = "已关闭"
            else state_disp = state

            print proto_color proto reset,
                  addr_color addr reset,
                  port_color port reset,
                  state_color state_disp reset,
                  proc_color proc_clean reset
        }'
    } | column_if_available
}

list_beautify_all() {
    clear
    echo -e "${gl_zi}>>> Linux TCP/UDP监听列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_linux_tcp
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all
