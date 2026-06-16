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

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    read -r -n 1 -s -r -p ""
    echo ""
    clear
}

sleep_fractional() {
    local seconds=$1
    if sleep "$seconds" 2>/dev/null; then return 0; fi
    if command -v perl &>/dev/null; then perl -e "select(undef, undef, undef, $seconds)"; return 0; fi
    if command -v python3 &>/dev/null; then python3 -c "import time; time.sleep($seconds)"; return 0; fi
    if command -v python &>/dev/null; then python -c "import time; time.sleep($seconds)"; return 0; fi
    local int_seconds=$(awk -v sec="$seconds" 'BEGIN{print int(sec+0.999)}')
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

exit_script() {
    echo ""
    echo -ne "${gl_hong}感谢使用，再见！ ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    clear
    exit 0
}

cancel_return() {
    local menu_name="${1:-上一级选单}"
    echo -e "${gl_lv}即将返回到 ${gl_huang}${menu_name}${gl_lv} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    sleep_fractional 0.6
    echo ""
    clear
}

is_directory() {
    [[ -d "$1" ]] || [[ "$1" =~ ^[~/] ]] || [[ "$1" =~ ^\.{1,2}/ ]]
}

is_tag_name() {
    [[ "$1" =~ ^[a-zA-Z0-9vV] ]] && [[ ! "$1" =~ / ]] && [[ ! "$1" =~ ^\.*$ ]]
}

is_message() {
    [[ ${#1} -gt 10 ]] || [[ "$1" =~ \  ]] || [[ "$1" =~ ^[\"\'\(] ]]
}

parse_args() {
    local tag_name=""
    local project_dir=""
    local tag_message=""

    for arg in "$@"; do
        if is_directory "$arg"; then
            project_dir="$arg"
        elif is_message "$arg"; then
            tag_message="$arg"
        elif is_tag_name "$arg"; then
            tag_name="$arg"
        else
            [[ -z "$tag_name" ]] && tag_name="$arg" || tag_message="$arg"
        fi
    done

    echo "$tag_name|$project_dir|$tag_message"
}

check_git_repo() {
    if ! command -v git &>/dev/null; then
        log_error "Git 未安装，请先安装 Git"
        return 1
    fi
    [[ ! -d ".git" ]] && { log_error "当前目录不是 Git 仓库"; return 1; }
    return 0
}

show_tag_detail() {
    local tag_name="$1"
    echo -e ""
    echo -e "${gl_zi}>>> 标签详情: ${gl_huang}$tag_name${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    local tag_type=$(git cat-file -t "$tag_name" 2>/dev/null)
    local tag_object=$(git rev-parse "$tag_name" 2>/dev/null)
    local commit_hash=$(git log -1 --format="%H" "$tag_name" 2>/dev/null)
    local commit_date=$(git log -1 --format="%ci" "$tag_name" 2>/dev/null)
    local commit_author=$(git log -1 --format="%an <%ae>" "$tag_name" 2>/dev/null)
    local commit_message=$(git log -1 --format="%s" "$tag_name" 2>/dev/null)
    
    echo -e "${gl_bai}标签名称:    ${gl_huang}$tag_name${gl_bai}"
    echo -e "${gl_bai}标签类型:    ${gl_lv}${tag_type:-轻量标签}${gl_bai}"
    echo -e "${gl_bai}标签对象:    ${gl_lan}${tag_object:0:12}${gl_bai}"
    echo -e "${gl_bai}提交哈希:    ${gl_lan}${commit_hash:0:12}${gl_bai}"
    echo -e "${gl_bai}提交日期:    ${gl_lv}$commit_date${gl_bai}"
    echo -e "${gl_bai}提交作者:    ${gl_bai}$commit_author${gl_bai}"
    echo -e "${gl_bai}提交信息:    ${gl_bai}$commit_message${gl_bai}"
    
    if [[ "$tag_type" == "tag" ]]; then
        echo -e ""
        echo -e "${gl_bai}附注信息:${gl_bai}"
        git tag -n1 "$tag_name" | sed 's/^[^ ]* //' | while IFS= read -r line; do
            echo -e "  ${gl_bufan}$line${gl_bai}"
        done
    fi
    
    echo -e ""
    echo -e "${gl_bai}变更统计:${gl_bai}"
    git show --stat --oneline "$tag_name" 2>/dev/null | tail -n +2 | head -n -1 | while IFS= read -r line; do
        echo -e "  ${gl_bai}$line${gl_bai}"
    done
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

create_annotated_tag() {
    local tag_name="$1"
    local project_dir="$2"
    local tag_message="$3"
    local commit_ref="HEAD"
    
    clear
    echo -e "${gl_zi}>>> Git 标签创建${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    if [[ -n "$project_dir" ]]; then
        if ! cd "$project_dir" 2>/dev/null; then
            log_error "无法进入目录: ${gl_huang}$project_dir${gl_bai}"
            return 1
        fi
        log_info "已切换到项目目录: ${gl_lv}$(pwd)${gl_bai}"
    fi
    
    if ! check_git_repo; then
        return 1
    fi
    
    if [[ -z "$tag_name" ]]; then
        echo -e ""
        read -r -e -p "$(echo -e "${gl_bai}请输入标签名称(${gl_huang}0${gl_bai}返回): ")" tag_name
        [[ "$tag_name" == "0" ]] && { cancel_return "Git 标签管理"; return 1; }
    fi
    
    [[ -z "$tag_name" ]] && { log_error "标签名称不能为空"; return 1; }
    
    if git rev-parse --verify --quiet "$tag_name" &>/dev/null; then
        log_error "标签 ${gl_huang}$tag_name ${gl_hong}已存在${gl_bai}"
        echo -e ""
        echo -e "${gl_bai}现有标签详情:${gl_bai}"
        show_tag_detail "$tag_name"
        return 1
    fi
    
    if [[ -z "$tag_message" ]]; then
        read -r -e -p "$(echo -e "${gl_bai}请输入标签描述 (默认: Release $tag_name): ")" tag_message
    fi
    tag_message="${tag_message:-Release $tag_name}"
    
    if [[ -z "$1" ]]; then
        read -r -e -p "$(echo -e "${gl_bai}在哪个提交创建标签? (默认: 最新提交): ")" commit_ref_input
        commit_ref="${commit_ref_input:-HEAD}"
    fi
    
    echo -e ""
    if git tag -a "$tag_name" -m "$tag_message" "$commit_ref" 2>/dev/null; then
        log_ok "附注标签 ${gl_huang}$tag_name ${gl_lv}创建成功${gl_bai}"
        show_tag_detail "$tag_name"
        
        read -r -e -p "$(echo -e "${gl_bai}是否推送到远程仓库? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" push_now
        if [[ "$push_now" =~ ^[Yy]$ ]]; then
            echo -e ""
            log_info "正在推送标签 ${gl_huang}$tag_name${gl_bai} 至远程 origin..."
            if git push origin "$tag_name" 2>/dev/null; then
                log_ok "标签已成功推送到远程仓库"
            else
                log_error "推送失败，请检查网络或远程权限"
                log_warn "手动推送命令: ${gl_lan}git push origin $tag_name${gl_bai}"
            fi
        else
            log_warn "已跳过推送，可后续手动执行 git push origin $tag_name"
        fi
        break_end
        return 0
    else
        log_error "标签创建失败"
        return 1
    fi
}

main() {
    local parsed
    parsed=$(parse_args "$@")
    local tag_name
    tag_name=$(cut -d'|' -f1 <<< "$parsed")
    local project_dir
    project_dir=$(cut -d'|' -f2 <<< "$parsed")
    local tag_message
    tag_message=$(cut -d'|' -f3 <<< "$parsed")
    
    create_annotated_tag "$tag_name" "$project_dir" "$tag_message"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"