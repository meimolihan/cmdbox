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

log_info()  { echo -e "${gl_lan}[信息]${gl_bai} $*"; }
log_ok()    { echo -e "${gl_lv}[成功]${gl_bai} $*"; }
log_warn()  { echo -e "${gl_huang}[警告]${gl_bai} $*"; }
log_error() { echo -e "${gl_hong}[错误]${gl_bai} $*" >&2; }

cpu_bench() {
    echo -e "${gl_zi}>>> CPU 基准测试${reset}"
    if command -v sysbench &>/dev/null; then
        sysbench cpu --cpu-max-prime=20000 run 2>/dev/null | grep -E 'total time|events per second' || true
    else
        log_warn "未安装 sysbench，尝试安装"
        if command -v apt &>/dev/null; then apt update && apt install -y sysbench; fi
        if command -v yum &>/dev/null; then yum install -y sysbench; fi
        if command -v dnf &>/dev/null; then dnf install -y sysbench; fi
        sysbench cpu --cpu-max-prime=20000 run 2>/dev/null | grep -E 'total time|events per second' || true
    fi
    echo -e "${gl_bufan}─────────────────────────────────────────────────────${reset}"
}

memory_bench() {
    echo -e "${gl_zi}>>> 内存基准测试${reset}"
    if command -v sysbench &>/dev/null; then
        sysbench memory --memory-total=1G run 2>/dev/null | grep -E 'transferred|MiB/sec' || true
    else
        log_warn "sysbench 未安装，跳过内存测试"
    fi
    echo -e "${gl_bufan}─────────────────────────────────────────────────────${reset}"
}

disk_bench() {
    echo -e "${gl_zi}>>> 磁盘 I/O 基准测试${reset}"
    dd if=/dev/zero of=/tmp/bench-test bs=1M count=1024 conv=fdatasync 2>&1 | grep -E 'copied|s,' || true
    rm -f /tmp/bench-test
    echo -e "${gl_bufan}─────────────────────────────────────────────────────${reset}"
}

run_with_timeout() {
    local secs="$1"
    shift
    if command -v timeout &>/dev/null; then
        timeout "$secs" "$@"
    else
        "$@"
    fi
}

network_bench() {
    echo -e "${gl_zi}>>> 网络基准测试${reset}"
    if ! command -v curl &>/dev/null; then
        log_warn "未安装 curl，跳过网络测试"
        echo -e "${gl_bufan}─────────────────────────────────────────────────────${reset}"
        return 0
    fi

    if command -v speedtest-cli &>/dev/null; then
        log_info "使用 speedtest-cli 测速（限时 30 秒）"
        run_with_timeout 30 speedtest-cli --simple --timeout 5 --retries 0 2>/dev/null \
            || log_warn "speedtest-cli 测速超时或失败，改用 curl 测试"
    fi

    local latency_url="" latency=""
    local url
    for url in https://gitee.com https://www.cloudflare.com; do
        latency=$(curl -s -o /dev/null -w '%{time_total}' --connect-timeout 3 --max-time 8 "$url" 2>/dev/null) || continue
        [ -n "$latency" ] && [ "$latency" != "0" ] && { latency_url="$url"; break; }
    done
    if [ -n "$latency_url" ]; then
        awk -v t="$latency" -v u="$latency_url" 'BEGIN {printf "延迟(%s): %.0f ms\n", u, t*1000}'
    else
        log_warn "延迟测试失败，所有目标均连接超时"
    fi

    local speed=""
    speed=$(curl -s -o /dev/null -w '%{speed_download}' --connect-timeout 3 --max-time 12 \
        'https://speed.cloudflare.com/__down?bytes=10485760' 2>/dev/null) || speed=""
    if [ -n "$speed" ] && [ "$speed" != "0" ]; then
        awk -v s="$speed" 'BEGIN {printf "下载速度: %.2f MB/s (%.1f Mbps)\n", s/1048576, s*8/1000000}'
    else
        log_warn "下载测速失败或超时，已跳过"
    fi

    echo -e "${gl_bufan}─────────────────────────────────────────────────────${reset}"
}

main() {
    echo -e "${gl_zi}>>> 系统跑分与性能基准${reset}"
    echo -e "${gl_bufan}─────────────────────────────────────────────────────${reset}"
    cpu_bench
    memory_bench
    disk_bench
    network_bench
    log_ok "系统跑分完成"
}

main "$@"
