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

install_docker_compose() {
    clear
    echo -e "${gl_zi}>>> Docker Compose 安装${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    log_info "检测操作系统与架构 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        OS="unknown"
    fi
    log_ok "检测到系统: $OS"

    log_info "清理旧版本残留 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    rm -f /usr/bin/docker-compose /usr/local/bin/docker-compose
    mkdir -p /usr/libexec/docker/cli-plugins
    rm -f /usr/libexec/docker/cli-plugins/docker-compose
    log_ok "清理完成"

    log_info "安装依赖工具 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    if [[ "$OS" == "debian" || "$OS" == "ubuntu" ]]; then
        apt update >/dev/null 2>&1
        apt install -y curl wget >/dev/null 2>&1
    elif [[ "$OS" == "centos" || "$OS" == "rhel" || "$OS" == "fedora" ]]; then
        yum install -y curl wget >/dev/null 2>&1
    elif [[ "$OS" == "arch" ]]; then
        pacman -Sy --noconfirm curl wget >/dev/null 2>&1
    fi
    log_ok "依赖安装完成"

    log_info "安装 Docker Compose 插件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    if [[ "$OS" == "debian" || "$OS" == "ubuntu" ]]; then
        apt install -y docker-compose-plugin >/dev/null 2>&1
    elif [[ "$OS" == "centos" || "$OS" == "rhel" || "$OS" == "fedora" ]]; then
        yum install -y docker-compose-plugin >/dev/null 2>&1
    elif [[ "$OS" == "arch" ]]; then
        pacman -Sy --noconfirm docker-compose >/dev/null 2>&1
    else
        log_warn "未知系统，使用通用安装方式"
    fi

    log_info "下载官方最新版（兼容所有Linux）"
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
        DL_ARCH="x86_64"
    elif [ "$ARCH" = "aarch64" ]; then
        DL_ARCH="aarch64"
    else
        DL_ARCH="x86_64"
    fi
    log_info "系统架构: $ARCH"

    LATEST_URL="https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$DL_ARCH"
    
    echo -e "${gl_huang}开始下载，请稍候 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    if command -v curl >/dev/null 2>&1; then
        curl -# -L "$LATEST_URL" -o /usr/libexec/docker/cli-plugins/docker-compose
    else
        wget -q --show-progress "$LATEST_URL" -O /usr/libexec/docker/cli-plugins/docker-compose
    fi
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    chmod +x /usr/libexec/docker/cli-plugins/docker-compose
    log_ok "文件下载完成，权限设置成功"

    log_info "创建双命令兼容（WSL+全Linux通用） ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    ln -sf /usr/libexec/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose
    ln -sf /usr/libexec/docker/cli-plugins/docker-compose /usr/bin/docker-compose
    log_ok "命令链接创建完成"

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_ok "Docker Compose 版本信息："
    if command -v docker-compose >/dev/null 2>&1; then
        { docker-compose version; echo -ne "${reset}"; } | sed "s/^/${gl_lv}/"
    else
        { /usr/local/bin/docker-compose version; echo -ne "${reset}"; } | sed "s/^/${gl_lv}/"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_ok "✅ 安装完成！全系统兼容！"
    log_ok "✅ 可使用：docker compose"
    log_ok "✅ 可使用：docker-compose"
}

install_docker_compose
