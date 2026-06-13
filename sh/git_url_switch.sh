#!/bin/bash
set -uo pipefail

# 配色定义
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

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    read -r -n 1 -s -p ""
    echo ""
    clear
}

handle_y_n() {
    echo -ne "\r${gl_hong}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai}) ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.3
    echo -ne "\r${gl_huang}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai}) ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.3
    echo -ne "\r${gl_lv}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai}) ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo ""
    return 2
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
        echo -e "\n${gl_huang}检查依赖：${gl_bai}$pkg${gl_bai}"
        if command -v apt &>/dev/null; then
            apt update -y && apt install -y "$pkg" >/dev/null 2>&1
        elif command -v dnf &>/dev/null; then
            dnf install -y "$pkg" >/dev/null 2>&1
        elif command -v yum &>/dev/null; then
            yum install -y "$pkg" >/dev/null 2>&1
        fi
    done
}

sleep_fractional() {
    local seconds=$1
    if sleep "$seconds" 2>/dev/null; then return 0; fi
    if command -v perl >/dev/null 2>&1; then perl -e "select(undef, undef, undef, $seconds)"; return 0; fi
    if command -v python3 >/dev/null 2>&1; then python3 -c "import time; time.sleep($seconds)"; return 0; fi
    if command -v python >/dev/null 2>&1; then python -c "import time; time.sleep($seconds)"; return 0; fi
    local int_seconds=$(echo "$seconds" | awk '{print int($1+0.999)}')
    sleep "$int_seconds"
}

check_git_repo() {
    local target_dir=${1:-.}
    cd "$target_dir" || return 1
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        log_error "目录 [$target_dir] 不是 Git 仓库！"
        return 1
    fi
    return 0
}

get_remote_url() {
    local target_dir=${1:-.}
    cd "$target_dir" || return 1
    git remote get-url origin 2>/dev/null
}

convert_git_url() {
    local url="$1"
    if [[ "$url" =~ ^https://(github|gitee|gitlab)\.com/([^/]+/[^/.]+)(\.git)?$ ]]; then
        echo "git@${BASH_REMATCH[1]}.com:${BASH_REMATCH[2]}.git"
    elif [[ "$url" =~ ^git@(github|gitee|gitlab)\.com:([^/]+/[^/.]+)(\.git)?$ ]]; then
        echo "https://${BASH_REMATCH[1]}.com/${BASH_REMATCH[2]}.git"
    else
        echo ""
    fi
}

convert_to_ssh() {
    local url="$1"
    if [[ "$url" =~ ^https://(github|gitee|gitlab)\.com/([^/]+/[^/.]+)(\.git)?$ ]]; then
        echo "git@${BASH_REMATCH[1]}.com:${BASH_REMATCH[2]}.git"
    elif [[ "$url" =~ ^git@(github|gitee|gitlab)\.com:([^/]+/[^/.]+)(\.git)?$ ]]; then
        echo "$url"
    else
        echo ""
    fi
}

convert_to_https() {
    local url="$1"
    if [[ "$url" =~ ^git@(github|gitee|gitlab)\.com:([^/]+/[^/.]+)(\.git)?$ ]]; then
        echo "https://${BASH_REMATCH[1]}.com/${BASH_REMATCH[2]}.git"
    elif [[ "$url" =~ ^https://(github|gitee|gitlab)\.com/([^/]+/[^/.]+)(\.git)?$ ]]; then
        echo "$url"
    else
        echo ""
    fi
}

set_remote_url() {
    local target_dir=$1
    local new_url=$2
    cd "$target_dir" || return 1
    git remote set-url origin "$new_url"
}

git_switch_remote() {
    local target_dir=${1:-.}
    local target_proto="$2"
    clear
    install git
    echo -e "${gl_zi}>>> Git远程协议切换工具${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    check_git_repo "$target_dir" || { sleep_fractional 2; return 1; }
    local old_url=$(get_remote_url "$target_dir")
    
    [[ -z "$old_url" ]] && { log_error "未配置 origin 远程仓库"; sleep_fractional 2; return 1; }

    local protocol
    if [[ "$old_url" == https* ]]; then
        protocol="${gl_lv}HTTPS${gl_bai}"
    elif [[ "$old_url" == git@* ]]; then
        protocol="${gl_huang}SSH${gl_bai}"
    else
        protocol="${gl_hong}未知协议${gl_bai}"
    fi

    echo -e "${gl_lan}操作目录：${gl_bai}$target_dir"
    echo -e "${gl_lan}当前协议：${protocol}"
    echo -e "${gl_lan}远程地址：${gl_bai}$old_url"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    # 智能获取目标地址
    local new_url=""
    if [[ -n "$target_proto" ]]; then
        local lp=$(echo "$target_proto" | tr '[:upper:]' '[:lower:]')
        if [[ "$lp" == "ssh" ]]; then
            new_url=$(convert_to_ssh "$old_url")
        elif [[ "$lp" == "https" ]]; then
            new_url=$(convert_to_https "$old_url")
        fi
    else
        new_url=$(convert_git_url "$old_url")
    fi

    [[ -z "$new_url" ]] && { log_error "不支持的 Git 地址格式"; sleep_fractional 2; return 1; }

    if [[ "$old_url" == "$new_url" ]]; then
        log_ok "当前已是目标协议，无需切换"
        break_end
        exit 0
    fi

    read -r -e -p "$(echo -e "${gl_bai}切换为新地址？${gl_lv}y${gl_bai}/${gl_hong}n${gl_bai}，输入${gl_huang}0${gl_bai}退出脚本：")" choice
    
    case "${choice,,}" in
        0) exit_script ;;
        y|yes)
            set_remote_url "$target_dir" "$new_url"
            log_ok "切换成功！新地址：$new_url"
            break_end
            ;;
        n|no)
            log_info "已取消操作"
            sleep_fractional 1
            ;;
        *) handle_y_n ;;
    esac
}

# 入口：智能兼容所有传参
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    target_dir="."
    target_proto=""

    for arg in "$@"; do
        lower=$(echo "$arg" | tr '[:upper:]' '[:lower:]')
        if [[ "$lower" == "ssh" || "$lower" == "https" ]]; then
            target_proto="$lower"
        else
            target_dir="$arg"
        fi
    done

    while true; do
        git_switch_remote "$target_dir" "$target_proto"
    done
fi