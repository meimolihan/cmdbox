#!/bin/bash
set -uo pipefail

gl_hui='\033[38;5;59m'
gl_hong='\033[38;5;9m'
gl_lv='\033[38;5;10m'
gl_huang='\033[38;5;11m'
gl_lan='\033[38;5;32m'
gl_bai='\033[38;5;15m'
gl_zi='\033[38;5;13m'
gl_bufan='\033[38;5;14m'

log_info() { echo -e "${gl_lan}[信息]${gl_bai} $*"; }
log_ok() { echo -e "${gl_lv}[成功]${gl_bai} $*"; }
log_warn() { echo -e "${gl_huang}[警告]${gl_bai} $*"; }
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

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    read -r -n 1 -s -p ""
    echo ""
    clear
}

exit_script() {
    echo ""
    echo -ne "${gl_hong}感谢使用，再见！ ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    clear
    exit 0
}

install() {
    [[ $# -eq 0 ]] && return 1
    for pkg in "$@"; do
        if command -v "$pkg" &>/dev/null; then continue; fi
        log_info "正在安装依赖：${gl_huang}$pkg${gl_bai}"
        if command -v apt &>/dev/null; then
            apt update -y && apt install -y "$pkg" >/dev/null 2>&1
        elif command -v dnf &>/dev/null; then
            dnf install -y "$pkg" >/dev/null 2>&1
        elif command -v yum &>/dev/null; then
            yum install -y "$pkg" >/dev/null 2>&1
        fi
    done
}

clone_repository() {
    install git
    local repo_url="$1"
    if [[ -z "$repo_url" ]]; then
        clear
        echo -e ""
        echo -e "${gl_huang}当前工作目录: ${gl_lv}$(pwd)${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        ls --color=auto -x
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e ""
        echo -e "${gl_huang}>>> Git克隆仓库${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入仓库地址 (${gl_huang}0${gl_bai}退出): ")" repo_url
    fi

    [ -z "$repo_url" ] && { log_error "仓库地址不能为空"; return 1; }
    [ "$repo_url" = "0" ] && { exit_script; }

    echo -e ""
    echo -e "${gl_huang}>>> 正在克隆仓库中 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_info "当前克隆目录：${gl_huang}$(pwd)${gl_bai}"
    
    if git clone "$repo_url"; then
        log_ok "仓库克隆成功！"
    else
        log_error "仓库克隆失败"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

clone_repository "$1"