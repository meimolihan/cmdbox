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

sleep_fractional() {
    local seconds=$1
    if sleep "$seconds" 2>/dev/null; then return 0; fi
    if command -v perl >/dev/null 2>&1; then perl -e "select(undef, undef, undef, $seconds)"; return 0; fi
    if command -v python3 >/dev/null 2>&1; then python3 -c "import time; time.sleep($seconds)"; return 0; fi
    if command -v python >/dev/null 2>&1; then python -c "import time; time.sleep($seconds)"; return 0; fi
    local int_seconds=$(echo "$seconds" | awk '{print int($1+0.999)}')
    sleep "$int_seconds"
}

exit_animation() {
    echo -ne "${gl_lv}即将退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo ""
    clear
}

docker_check_env() {
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_info "正在检查 Docker 运行环境 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

    if command -v docker &>/dev/null; then
        local ver
        ver=$(docker --version | awk '{print $3}' | sed 's/,//g')
        log_ok "Docker 已安装，版本：${gl_lv}$ver${gl_bai}"
    else
        log_warn "Docker 未安装，即将自动安装 Docker 环境 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        bash <(curl -sL gitee.com/meimolihan/cmdbox/raw/master/sh/linux_docker.sh)

        if ! command -v docker &>/dev/null; then
            log_error "Docker 安装失败，请手动安装后重试！"
            exit_animation
            exit 1
        fi
        log_ok "Docker 安装成功！"
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_info "正在检查 Docker Compose 环境 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

    if command -v docker-compose &>/dev/null; then
        local ver
        ver=$(docker-compose --version 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        [ -z "$ver" ] && ver=$(docker-compose --version 2>/dev/null | awk '{print $3}' | sed 's/,//g')
        log_ok "Docker Compose 已安装，版本：${gl_lv}$ver${gl_bai}"
    else
        log_warn "Docker Compose 未安装，即将自动安装 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        bash <(curl -sL gitee.com/meimolihan/cmdbox/raw/master/sh/linux_compose.sh)

        if ! command -v docker-compose &>/dev/null; then
            log_error "Docker Compose 安装失败，请手动安装后重试！"
            exit_animation
            exit 1
        fi
        log_ok "Docker Compose 安装成功！"
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_ok "Docker 运行环境准备完成！"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    sleep 1
}

docker_check_env