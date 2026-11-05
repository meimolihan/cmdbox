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

network_bench() {
    echo -e "${gl_zi}>>> 网络基准测试${reset}"
    if command -v speedtest-cli &>/dev/null; then
        speedtest-cli --simple 2>/dev/null || true
    elif command -v curl &>/dev/null; then
        curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 - --simple 2>/dev/null || true
    else
        log_warn "未安装 speedtest-cli，跳过网络测试"
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
