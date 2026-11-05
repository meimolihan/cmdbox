#!/bin/bash
set -euo pipefail

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

root_use() {
    if [ "$EUID" -ne 0 ]; then
        log_error "该脚本需要root用户运行"; exit 1
    fi
}

optimize() {
    local conf="/etc/docker/daemon.json"
    mkdir -p /etc/docker
    if [ -f "$conf" ]; then
        cp "$conf" "${conf}.bak.$(date +%s)"
    fi
    cat > "$conf" << EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "max-concurrent-downloads": 10,
  "max-concurrent-uploads": 5,
  "ipv6": false,
  "userland-proxy": false
}
EOF
    systemctl daemon-reload
    systemctl restart docker
    log_ok "Docker daemon 已优化并重启"
}

verify() {
    docker info 2>/dev/null | grep -E "Storage Driver|Logging Driver" || true
    log_ok "Docker daemon 优化完成，可执行 docker info 查看详情"
}

main() {
    root_use
    optimize
    verify
    echo -e "${gl_lv}Docker daemon 优化完成${gl_bai}"
}

main "$@"
