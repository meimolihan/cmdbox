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

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    read -r -n 1 -s -p ""
    echo ""
    clear
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

exit_animation() {
    echo -ne "\r${gl_lv}即将退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo ""
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

check_existing_git_repo() {
    if [[ -d ".git" ]]; then
        log_warn "当前目录已存在 Git 仓库"
        read -r -e -p "$(echo -e "${gl_bai}是否继续初始化？(${gl_lv}y${gl_bai}/${gl_hong}n${gl_bai}): ")" continue_choice
        [[ "${continue_choice,,}" != "y" ]] && { log_info "已取消"; exit_animation; return 1; }
    fi
    return 0
}

handle_readme() {
    local repo_name="$1"
    [[ -f "README.md" ]] && { log_info "检测到已存在 README.md，跳过创建"; return; }
    echo "## $repo_name 项目说明" > README.md
    log_ok "已创建 README.md"
}

generate_ssh_url() {
    local base="$1"
    local name="$2"
    if [[ "$base" =~ https://gitee.com/([^/]+)/*$ ]]; then
        echo "git@gitee.com:${BASH_REMATCH[1]}/$name.git"
    elif [[ "$base" =~ https://github.com/([^/]+)/*$ ]]; then
        echo "git@github.com:${BASH_REMATCH[1]}/$name.git"
    elif [[ "$base" =~ https://gitlab.com/([^/]+)/*$ ]]; then
        echo "git@gitlab.com:${BASH_REMATCH[1]}/$name.git"
    else
        echo "$base"
    fi
}

git_init_repository() {
    local repo_name="$1"
    local repo_url="$2"

    if ! command -v git &>/dev/null; then
        log_error "未找到 git，请先安装"; return 1
    fi
    check_existing_git_repo || return 1

    log_info "正在初始化 Git 仓库 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    git init -q && log_ok "已初始化 Git 仓库"

    git config --global --add safe.directory "$(pwd)" &>/dev/null
    log_info "已配置安全目录"

    handle_readme "$repo_name"

    log_info "正在添加文件到暂存区 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    git add . &>/dev/null && log_ok "文件已暂存"

    log_info "正在提交初始版本 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    git config user.email "user@example.com" &>/dev/null
    git config user.name "Git User" &>/dev/null
    git commit -m "init: first commit" &>/dev/null
    log_ok "已提交初始版本"

    local real_ssh=$(generate_ssh_url "$repo_url" "$repo_name")
    log_info "使用SSH仓库：$real_ssh"

    git remote remove origin &>/dev/null
    git remote add origin "$real_ssh"
    log_ok "已配置SSH远程仓库"

    log_info "正在推送代码 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    if git push -u origin master 2>/dev/null || git push -u origin main 2>/dev/null; then
        log_ok "代码推送成功！"
    else
        log_warn "推送失败 → 请先在平台创建仓库并配置SSH密钥"
    fi
    return 0
}

git_init_menu() {
    local repo_url="$1"
    local platform=""
    local show_tip5=false

    if [[ "$repo_url" == *"gitee.com"* ]]; then
        platform="Gitee"
        show_tip5=true
    elif [[ "$repo_url" == *"github.com"* ]]; then
        platform="GitHub"
        show_tip5=true
    elif [[ "$repo_url" == *"gitlab.com"* ]]; then
        platform="GitLab"
        show_tip5=true
    fi

    while true; do
        clear
        install git
        echo -e "${gl_zi}>>> Git 新仓库初始化${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        local repo_dir=$(basename "$PWD")
        echo -e "${gl_lan}当前工作目录: ${gl_bai}$PWD"
        echo -e "${gl_lan}建议仓库名称: ${gl_huang}$repo_dir${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_lv}注意事项:${gl_bai}"
        echo -e "${gl_bufan}1. ${gl_bai}请提前在 Gitee/Github/GitLab 创建空仓库"
        echo -e "${gl_bufan}2. ${gl_bai}确保已配置 SSH 密钥"
        echo -e "${gl_bufan}3. ${gl_bai}当前目录文件将被添加到版本控制"
        echo -e "${gl_bufan}4. ${gl_bai}如无 README.md 文件将自动创建"
        [[ $show_tip5 == true ]] && echo -e "${gl_bufan}5. ${gl_bai}前往${platform}创建名为${gl_huang}$repo_dir${gl_bai}的仓库：${gl_lv}$repo_url${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        read -r -e -p "$(echo -e "${gl_bai}请输入仓库名称(回车默认${gl_huang}$repo_dir${gl_bai})，输入${gl_huang}0${gl_bai}退出: ")" input_name
        [[ "$input_name" == "0" ]] && { exit_animation; return; }
        local repo_name=${input_name:-$repo_dir}

        [[ -z "$repo_name" ]] && { log_error "名称不能为空"; sleep_fractional 1; continue; }
        read -r -e -p "$(echo -e "${gl_bai}确认初始化仓库 '${gl_huang}$repo_name${gl_bai}'? (${gl_lv}y${gl_bai}/${gl_hong}n${gl_bai}): ")" confirm

        case "${confirm,,}" in
            y|yes) git_init_repository "$repo_name" "$repo_url"
                       echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                       break_end; break ;;
            n|no) log_info "已取消"; break ;;
            0) exit_animation; return ;;
            *) handle_y_n ;;
        esac
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -eq 0 ]]; then
        clear
        sleep_fractional 0.5
        read -r -e -p "$(echo -e "\n${gl_bai}请输入你的仓库主页地址（如 https://github.com/xxx）：")" repo_url
        if [[ -z "$repo_url" ]]; then
            log_error "地址不能为空，退出"
            exit 1
        fi
        git_init_menu "$repo_url"
    else
        git_init_menu "$1"
    fi
fi
