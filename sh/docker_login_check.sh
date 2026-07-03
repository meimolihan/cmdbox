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

sleep_fractional() {
    local seconds=$1
    if sleep "$seconds" 2>/dev/null; then return 0; fi
    if command -v python3 >/dev/null 2>&1; then python3 -c "import time; time.sleep($seconds)"; return 0; fi
    local int_seconds=$(awk -v s="$seconds" 'BEGIN{print int(s+0.999)}')
    sleep "$int_seconds"
}

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n 1 -s -p ""
    echo ""
    clear
}

check_docker_credential() {
    clear
    echo -e "${gl_zi}>>> Docker 登录状态检查${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo ""
    echo -e "${gl_huang}>>> 检查 Docker 凭证配置${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    cat /root/.docker/config.json

    echo ""
    echo ""
    echo -e "${gl_huang}>>> 检查凭证助手状态${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    if command -v docker-credential-pass &>/dev/null; then
        docker-credential-pass version
        log_ok "凭证助手正常运行"
    else
        log_error "未找到 docker-credential-pass"
    fi

    echo ""
    echo -e "${gl_huang}>>> 检查 GPG 密钥${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    gpg --list-secret-keys 2>/dev/null || log_warn "未找到 GPG 私钥"

    echo ""
    echo -e "${gl_huang}>>> 检查 Pass 密码仓库${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    pass list 2>/dev/null || log_warn "Pass 仓库未初始化"

    echo ""
    echo -e "${gl_huang}>>> 检查 Docker 登录状态${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    local stored_cred docker_username
    stored_cred=$(pass list 2>/dev/null | grep "docker-credential-helpers" | head -1 || true)
    docker_username=$(docker info 2>/dev/null | grep -i "Username" || true)

    if [[ -n "$docker_username" ]]; then
        log_ok "Docker 登录成功：$docker_username"
    elif [[ -n "$stored_cred" ]]; then
        log_ok "Docker 登录成功（加密存储模式，docker info 不显示用户名）"
    else
        log_error "Docker 未登录"
    fi

    echo ""
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

check_docker_credential