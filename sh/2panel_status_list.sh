#!/bin/bash
set -uo pipefail

export gl_hui=$'\033[38;5;59m'
export gl_hong=$'\033[38;5;9m'
export gl_lv=$'\033[38;5;10m'
export gl_huang=$'\033[38;5;11m'
export gl_lan=$'\033[38;5;32m'
export gl_bai=$'\033[38;5;15m'
export gl_zi=$'\033[38;5;13m'
export gl_bufan=$'\033[38;5;14m'
export reset=$'\033[0m'

break_end() {
    echo -e "${gl_lv}操作完成${reset}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    read -r -n 1 -s
    echo ""
    clear
}

# 修改：标签靠左，无前置缩进
kv() {
    printf "${gl_lan}%-14s${reset} ${gl_lv}%s${reset}\n" "$1" "$2"
}

section() {
    echo -e "${gl_zi}▶ $1${reset}"
}

separator() {
echo -e "${gl_bufan}————————————————————————————————————————————————${reset}"
}

get_pid() {
    local pid
    pid=$(systemctl show -p MainPID 2panel 2>/dev/null | cut -d= -f2)
    if [[ -n "$pid" && -d "/proc/$pid" ]]; then
        echo "$pid"
        return 0
    fi
    for p in /proc/[0-9]*/exe; do
        local target
        target=$(readlink "$p" 2>/dev/null) || continue
        if [[ "$(basename "$target")" == "2panel" ]]; then
            echo "$(basename "$(dirname "$p")")"
            return 0
        fi
    done
    return 1
}

get_listen_port() {
    local pid=$1
    local inodes=""
    for fd in /proc/$pid/fd/*; do
        local link
        link=$(readlink "$fd" 2>/dev/null) || continue
        if [[ "$link" =~ ^socket:\[([0-9]+)\]$ ]]; then
            inodes+=" ${BASH_REMATCH[1]}"
        fi
    done
    [[ -z "$inodes" ]] && return

    local proto
    for proto in tcp tcp6; do
        local line
        while read -r line; do
            [[ -z "$line" ]] && continue
            local fields=($line)
            [[ ${#fields[@]} -lt 10 ]] && continue
            [[ "${fields[3]}" != "0A" ]] && continue
            local inode="${fields[9]}"
            if [[ " $inodes " == *" $inode "* ]]; then
                local hex_port="${fields[1]##*:}"
                printf "%d" "0x$hex_port" 2>/dev/null
                return
            fi
        done < <(tail -n +2 /proc/$pid/net/$proto 2>/dev/null)
    done
}

proc_field() {
    local pid=$1 field=$2
    awk -v f="$field" '$1==f":" {print $2}' /proc/$pid/status 2>/dev/null
}

# ── 计算运行时长 ──
get_uptime() {
    local pid=$1
    local start_ticks uptime_sec elapsed
    start_ticks=$(awk '{print $22}' /proc/$pid/stat 2>/dev/null) || return
    uptime_sec=$(awk '{printf "%d", $1}' /proc/uptime 2>/dev/null) || return
    (( start_ticks <= 0 || uptime_sec <= 0 )) && return
    elapsed=$(( uptime_sec - start_ticks / 100 ))
    (( elapsed < 0 )) && elapsed=0
    printf "%d小时 %d分钟 %d秒" $((elapsed/3600)) $(((elapsed%3600)/60)) $((elapsed%60))
}

fmt_mem() {
    local kb=${1:-0}
    (( kb == 0 )) && { echo "未知"; return; }
    if (( kb >= 1048576 )); then
        printf "%d kB (%.2f GB)" "$kb" "$(awk "BEGIN{printf \"%.2f\", $kb/1048576}")"
    else
        printf "%d kB (%.2f MB)" "$kb" "$(awk "BEGIN{printf \"%.2f\", $kb/1024}")"
    fi
}

main() {
    local pid
    pid=$(get_pid) || {
        echo -e "${gl_hong}❌ 2panel 服务未运行${reset}"
        break_end
        return 1
    }

    clear
    echo -e "${gl_zi}>>> 2Panel 服务状态${reset}"
    separator

    local vm_size vm_rss threads
    vm_size=$(proc_field "$pid" VmSize)
    vm_rss=$(proc_field "$pid" VmRSS)
    threads=$(proc_field "$pid" Threads)

    local port uptime_str nfd
    port=$(get_listen_port "$pid")
    uptime_str=$(get_uptime "$pid")
    nfd=$(ls /proc/$pid/fd 2>/dev/null | wc -l)

    section "进程"
    kv "  进程 PID"   "$pid"
    kv "  线程数量"   "${threads:-未知}"
    kv "  监听端口"   "${port:-未找到}"
    kv "  运行时长"   "${uptime_str:-未知}"

    section "内存"
    kv "  虚拟内存"   "$(fmt_mem "$vm_size")"
    kv "  物理内存"   "$(fmt_mem "$vm_rss")"

    section "资源"
    kv "  打开文件" "${nfd:-?}"

    separator
    kv "  数据目录"   "/var/lib/2panel"
    kv "  安装路径" "$(readlink /proc/$pid/exe 2>/dev/null || echo '未知')"

    separator
    break_end
}

main