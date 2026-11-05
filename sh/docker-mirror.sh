#!/bin/bash
set -euo pipefail

MIRROR="https://docker.mirrors.ustc.edu.cn"

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

choose_mirror() {
    echo -e "${gl_zi}>>> 请选择镜像加速器${reset}"
    echo -e "${gl_bufan}1. ${gl_bai}中科大 (ustc)"
    echo -e "${gl_bufan}2. ${gl_bai}阿里云 (aliyun)"
    echo -e "${gl_bufan}3. ${gl_bai}官方中国 (docker-cn)"
    echo -e "${gl_bufan}4. ${gl_bai}自定义"
    read -r -e -p "${gl_bai}请输入选择 (回车默认 1): ${gl_bai}" choice
    case "$choice" in
        2) MIRROR="https://mirror.aliyuncs.com" ;;
        3) MIRROR="https://registry.docker-cn.com" ;;
        4) read -r -e -p "${gl_bai}请输入自定义镜像地址: ${gl_bai}" MIRROR ;;
        *) MIRROR="https://docker.mirrors.ustc.edu.cn" ;;
    esac
}

configure_daemon() {
    local conf="/etc/docker/daemon.json"
    mkdir -p /etc/docker
    if [ -f "$conf" ]; then
        cp "$conf" "${conf}.bak.$(date +%s)"
    fi
    cat > "$conf" << EOF
{
  "registry-mirrors": ["$MIRROR"]
}
EOF
    log_ok "Docker 镜像加速器已配置：$MIRROR"
}

restart_docker() {
    systemctl daemon-reload
    systemctl restart docker
    log_ok "Docker 服务已重启"
}

verify() {
    docker info 2>/dev/null | grep -i "Registry Mirrors" -A1 || true
    log_ok "配置生效，可执行 docker info 查看"
}

main() {
    root_use
    choose_mirror
    configure_daemon
    restart_docker
    verify
    echo -e "${gl_lv}Docker 镜像加速配置完成${gl_bai}"
}

main "$@"
