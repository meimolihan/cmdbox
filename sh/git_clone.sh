#!/bin/bash

gl_hui='\033[38;5;59m'
gl_hong='\033[38;5;9m'
gl_lv='\033[38;5;10m'
gl_huang='\033[38;5;11m'
gl_lan='\033[38;5;32m'
gl_bai='\033[38;5;15m'
gl_zi='\033[38;5;13m'
gl_bufan='\033[38;5;14m'

log_info()  { echo -e "${gl_lan}[信息]${gl_bai} $*"; }
log_ok()    { echo -e "${gl_lv}[成功]${gl_bai} $*"; }
log_warn()  { echo -e "${gl_huang}[警告]${gl_bai} $*"; }
log_error() { echo -e "${gl_hong}[错误]${gl_bai} $*" >&2; }

sleep_fractional() {
    local seconds=$1
    if sleep "$seconds" 2>/dev/null; then return 0; fi
    if command -v perl >/dev/null; then perl -e "select(undef, undef, undef, $seconds)"; return 0; fi
    if command -v python3 >/dev/null; then python3 -c "import time; time.sleep($seconds)"; return 0; fi
    if command -v python >/dev/null; then python -c "import time; time.sleep($seconds)"; return 0; fi
    local int_seconds=$(awk -v s="$seconds" 'BEGIN{print int(s+0.999)}')
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
        command -v "$pkg" >/dev/null && continue
        log_info "正在安装依赖：${gl_huang}$pkg${gl_bai}"
        if command -v apt >/dev/null; then
            apt update -y && apt install -y "$pkg" >/dev/null 2>&1
        elif command -v dnf >/dev/null; then
            dnf install -y "$pkg" >/dev/null 2>&1
        elif command -v yum >/dev/null; then
            yum install -y "$pkg" >/dev/null 2>&1
        fi
    done
}

input_repo_list() {
    local repo_list=()
    clear
    echo -e "${gl_huang}当前工作目录: ${gl_lv}$(pwd)${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    ls --color=auto -x
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e ""
    echo -e "${gl_zi}>>> Git批量克隆仓库${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}逐行输入仓库地址，输入 ${gl_hong}0${gl_bai} 退出，空行结束输入${gl_bai}"
    echo -e "${gl_bai}————————————————————————————————————————————————${gl_bai}"

    while true; do
        read -r -e -p "$(echo -e "${gl_bai}> ")" input_tmp
        input_tmp=$(echo "$input_tmp" | xargs)
        if [[ "$input_tmp" == "0" ]]; then
            exit_script
        fi
        if [[ -z "$input_tmp" ]]; then
            break
        fi
        repo_list+=("$input_tmp")
    done
    echo "${repo_list[@]}"
}

# 提取仓库目录名
get_repo_name() {
    local url="$1"
    url="${url%/.git}"
    url="${url%.git}"
    echo "${url##*/}"
}

clone_repository() {
    install git
    local repo_list=()

    if [[ $# -eq 0 ]]; then
        read -ra repo_list <<< "$(input_repo_list)"
        if [[ ${#repo_list[@]} -eq 0 ]]; then
            log_warn "未输入任何仓库地址"
            break_end
            return 1
        fi
    else
        repo_list=("$@")
    fi

    local -A seen
    local unique_list=()
    for item in "${repo_list[@]}"; do
        [[ -z ${seen[$item]} ]] && unique_list+=("$item") && seen[$item]=1
    done
    repo_list=("${unique_list[@]}")

    echo -e ""
    echo -e "${gl_zi}>>> 开始批量克隆，总计 ${gl_lv}${#repo_list[@]}${gl_huang} 个仓库 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_info "克隆目标目录：${gl_huang}$(pwd)${gl_bai}"
    echo ""

    local succ=0 skip=0 fail=0
    for url in "${repo_list[@]}"; do
        local name=$(get_repo_name "$url")
        echo -e "${gl_huang}>>> 正在处理：${gl_huang}$url${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        if [[ -d "$name" ]]; then
            log_warn "[$name] 目录已存在，跳过克隆"
            ((skip++))
            echo ""
            continue
        fi

        if git clone -- "$url"; then
            log_ok "[$name] 克隆成功"
            ((succ++))
        else
            log_error "[$name] 克隆失败"
            ((fail++))
        fi
    done

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_info "批量任务汇总：${gl_lv}成功${succ}${gl_bai} 个，${gl_huang}跳过${skip}${gl_bai} 个，${gl_hong}失败${fail}${gl_bai} 个"
    break_end
}

