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

handle_invalid_input() {
    echo -ne "\r\033[K${gl_huang}无效的输入,请重新输入! ${gl_zi} 1 ${gl_huang} 秒后返回"
    sleep_fractional 1
    echo -ne "\r\033[K${gl_lv}无效的输入,请重新输入! ${gl_zi}0${gl_lv} 秒后返回"
    sleep_fractional 0.5
    echo -ne "\r\033[K"
    return 2
}

handle_y_n() {
    echo -e "${gl_hong}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai})${gl_hong}。${gl_bai}"
    sleep 1
    echo -e "${gl_huang}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai})${gl_huang}。${gl_bai}"
    sleep 1
    echo -e "${gl_lv}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai})${gl_lv}。${gl_bai}"
    sleep 0.5
    return 2
}

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n 1 -s -r -p ""
    echo ""
    clear
}

sleep_fractional() {
    local seconds=$1
    if sleep "$seconds" 2>/dev/null; then
        return 0
    fi
    
    if command -v perl >/dev/null 2>&1; then
        perl -e "select(undef, undef, undef, $seconds)"
        return 0
    fi
    
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "import time; time.sleep($seconds)"
        return 0
    elif command -v python >/dev/null 2>&1; then
        python -c "import time; time.sleep($seconds)"
        return 0
    fi
    
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
    sleep 0.6
    echo ""
    clear
}

check_git_repo() {
    if ! command -v git &>/dev/null; then
        log_error "Git 未安装，请先安装 Git"
        return 1
    fi
    
    if [[ ! -d ".git" ]]; then
        log_error "当前目录不是 Git 仓库"
        return 1
    fi
    
    return 0
}

get_current_branch() {
    git branch --show-current 2>/dev/null || echo ""
}

list_branches() {
    clear
    echo -e ""
    echo -e "${gl_zi}>>> 所有分支列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    local current_branch=$(get_current_branch)
    
    echo -e "${gl_bai}本地分支:${gl_bai}"
    git branch -v | while IFS= read -r branch; do
        if [[ "$branch" == "*"* ]]; then
            echo -e "${gl_lv}✓ $branch${gl_bai}"
        else
            echo -e "${gl_bai}  $branch"
        fi
    done
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    echo -e "${gl_bai}远程分支:${gl_bai}"
    git branch -r 2>/dev/null | while IFS= read -r branch; do
        echo -e "${gl_hui}  $branch${gl_bai}"
    done || echo -e "${gl_hui}  无远程分支${gl_bai}"
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

create_branch() {
    echo -e ""
    read -r -e -p "$(echo -e "${gl_bai}请输入新分支名称(${gl_huang}0${gl_bai}返回): ")" branch_name
    if [[ "$branch_name" == "0" ]]; then
        cancel_return "Git 分支管理"
        return 1
    fi
    
    if [[ -z "$branch_name" ]]; then
        log_error "分支名称不能为空"
        break_end
        return 1
    fi
    
    if git rev-parse --verify --quiet "$branch_name" >/dev/null; then
        log_error "分支 ${gl_huang}$branch_name ${gl_hong}已存在"
        break_end
        return 1
    fi
    
    read -r -e -p "$(echo -e "${gl_bai}从哪个分支创建? (默认: 当前分支): ")" base_branch
    base_branch=${base_branch:-$(get_current_branch)}
    
    if [[ -z "$base_branch" ]]; then
        log_error "基础分支不存在"
        break_end
        return 1
    fi
    
    echo -e ""
    if git checkout -b "$branch_name" "$base_branch" 2>/dev/null; then
        log_ok "分支 ${gl_huang}$branch_name ${gl_lv}创建成功 (基于 ${gl_huang}$base_branch${gl_lv})"
    else
        log_error "分支创建失败"
        break_end
        return 1
    fi
    
    read -r -e -p "$(echo -e "${gl_bai}是否推送到远程仓库? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" push_to_remote
    
    if [[ "$push_to_remote" =~ ^[Yy]$ ]]; then
        if git push -u origin "$branch_name" 2>/dev/null; then
            log_ok "已推送到远程分支 ${gl_huang}origin/$branch_name"
        else
            log_warn "推送失败，请手动执行: git push -u origin $branch_name"
        fi
    fi
    
    break_end
}

delete_branch() {
    local current_branch=$(get_current_branch)
    
    echo -e ""
    read -r -e -p "$(echo -e "${gl_bai}请输入要删除的分支名称(${gl_huang}0${gl_bai}返回): ")" branch_name
    if [[ "$branch_name" == "0" ]]; then
        cancel_return "Git 分支管理"
        return 1
    fi
    
    if [[ -z "$branch_name" ]]; then
        log_error "分支名称不能为空"
        break_end
        return 1
    fi
    
    if [[ "$branch_name" == "$current_branch" ]]; then
        log_error "不能删除当前分支，请先切换到其他分支"
        echo -e "${gl_bai}当前分支: ${gl_lv}$current_branch${gl_bai}"
        break_end
        return 1
    fi
    
    if ! git rev-parse --verify --quiet "$branch_name" >/dev/null; then
        log_error "分支 ${gl_huang}$branch_name ${gl_hong}不存在"
        break_end
        return 1
    fi
    
    echo -e ""
    echo -e "${gl_hong}警告: 删除分支 ${gl_huang}$branch_name${gl_hong}${gl_bai}"
    echo -e "${gl_huang}最后一次提交信息:${gl_bai}"
    git log -1 --pretty=format:"%s" "$branch_name" 2>/dev/null || echo "无法获取提交信息"
    
    echo -e ""
    read -r -e -p "$(echo -e "${gl_bai}确认删除? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_warn "取消删除"
        break_end
        return 0
    fi
    
    echo -e ""
    read -r -e -p "$(echo -e "${gl_bai}是否强制删除未合并的分支? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" force_delete
    echo -e ""
    
    if [[ "$force_delete" =~ ^[Yy]$ ]]; then
        if git branch -D "$branch_name" 2>/dev/null; then
            log_ok "分支 ${gl_huang}$branch_name ${gl_lv}已强制删除"
        else
            log_error "强制删除失败"
        fi
    else
        if git branch -d "$branch_name" 2>/dev/null; then
            log_ok "分支 ${gl_huang}$branch_name ${gl_lv}已安全删除"
        else
            log_error "删除失败 (分支可能未合并，使用 -D 强制删除)"
        fi
    fi
    
    break_end
}

switch_branch() {
    local current_branch=$(get_current_branch)
    
    echo -e "\n${gl_bai}当前分支: ${gl_lv}$current_branch${gl_bai}"
    echo -e "${gl_bai}可切换的分支:${gl_bai}"
    
    git branch | while IFS= read -r branch; do
        if [[ "$branch" == "*"* ]]; then
            echo -e "${gl_lv}✓ $branch${gl_bai}"
        else
            branch_name=$(echo "$branch" | sed 's/^[ *]*//')
            echo -e "${gl_bai}  $branch_name"
        fi
    done
    
    echo -e ""
    read -r -e -p "$(echo -e "${gl_bai}请输入分支名称(${gl_huang}0${gl_bai}返回): ")" branch_name
    if [[ "$branch_name" == "0" ]]; then
        cancel_return "Git 分支管理"
        return 1
    fi
    
    if [[ -z "$branch_name" ]]; then
        log_error "分支名称不能为空"
        break_end
        return 1
    fi
    
    if [[ "$branch_name" == "$current_branch" ]]; then
        log_warn "已经在 ${gl_huang}$branch_name ${gl_huang}分支上${gl_bai}"
        break_end
        return 0
    fi
    
    echo -e ""
    if git checkout "$branch_name" 2>/dev/null; then
        log_ok "已切换到分支 ${gl_huang}$branch_name"
    else
        log_error "切换失败，分支可能不存在"
        
        read -r -e -p "$(echo -e "${gl_bai}是否从远程拉取并切换? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" create_from_remote
        
        if [[ "$create_from_remote" =~ ^[Yy]$ ]]; then
            if git checkout -b "$branch_name" "origin/$branch_name" 2>/dev/null; then
                log_ok "已创建并切换到分支 ${gl_huang}$branch_name ${gl_lv}(从远程分支 origin/$branch_name)"
            else
                log_error "从远程创建失败"
            fi
        fi
    fi
    
    break_end
}

merge_branch() {
    local current_branch=$(get_current_branch)
    
    echo -e "\n${gl_bai}当前分支: ${gl_lv}$current_branch${gl_bai}"
    echo -e "${gl_bai}可合并的分支:${gl_bai}"
    
    git branch | while IFS= read -r branch; do
        if [[ "$branch" != "*"* ]]; then
            branch_name=$(echo "$branch" | sed 's/^[ *]*//')
            echo -e "${gl_bai}  $branch_name"
        fi
    done
    
    echo -e ""
    read -r -e -p "$(echo -e "${gl_bai}请输入要合并的分支名称(${gl_huang}0${gl_bai}返回): ")" branch_name
    if [[ "$branch_name" == "0" ]]; then
        cancel_return "Git 分支管理"
        return 1
    fi
    
    if [[ -z "$branch_name" ]]; then
        log_error "分支名称不能为空"
        break_end
        return 1
    fi
    
    if [[ "$branch_name" == "$current_branch" ]]; then
        log_error "不能合并到当前分支自身"
        break_end
        return 1
    fi
    
    if ! git rev-parse --verify --quiet "$branch_name" >/dev/null; then
        log_error "分支 ${gl_huang}$branch_name ${gl_hong}不存在"
        break_end
        return 1
    fi
    
    echo -e ""
    read -r -e -p "$(echo -e "${gl_bai}是否使用 --no-ff (不快速合并，保留合并历史)? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" no_ff_option
    echo -e ""
    
    local merge_command="git merge"
    if [[ "$no_ff_option" =~ ^[Yy]$ ]]; then
        merge_command="$merge_command --no-ff"
    else
        merge_command="$merge_command --ff"
    fi
    
    read -r -e -p "$(echo -e "${gl_bai}是否跳过编辑提交信息? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" no_edit_option
    
    if [[ "$no_edit_option" =~ ^[Yy]$ ]]; then
        merge_command="$merge_command --no-edit"
    fi
    
    echo -e ""
    log_info "正在合并分支: ${gl_huang}$branch_name ${gl_lan}→ ${gl_lv}$current_branch${gl_bai}"
    
    if eval "$merge_command \"$branch_name\"" 2>/dev/null; then
        log_ok "分支 ${gl_huang}$branch_name ${gl_lv}已成功合并到 ${gl_huang}$current_branch${gl_bai}"
    else
        log_error "合并失败，可能存在冲突，请手动解决"
    fi
    
    break_end
}

rename_branch() {
    local current_branch=$(get_current_branch)
    
    echo -e "\n${gl_bai}当前分支: ${gl_lv}$current_branch${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}请输入原分支名称 (默认: 当前分支, ${gl_huang}0${gl_bai}返回): ")" old_name
    if [[ "$old_name" == "0" ]]; then
        cancel_return "Git 分支管理"
        return 1
    fi
    old_name="${old_name:-$current_branch}"
    
    if [[ -z "$old_name" ]]; then
        log_error "原分支名称不能为空"
        break_end
        return 1
    fi
    
    if ! git rev-parse --verify --quiet "$old_name" >/dev/null; then
        log_error "分支 ${gl_huang}$old_name ${gl_hong}不存在"
        break_end
        return 1
    fi
    
    read -r -e -p "$(echo -e "${gl_bai}请输入新分支名称: ")" new_name
    
    if [[ -z "$new_name" ]]; then
        log_error "新分支名称不能为空"
        break_end
        return 1
    fi
    
    if git rev-parse --verify --quiet "$new_name" >/dev/null; then
        log_error "分支 ${gl_huang}$new_name ${gl_hong}已存在"
        break_end
        return 1
    fi
    
    echo -e ""
    if [[ "$old_name" == "$current_branch" ]]; then
        echo -e "${gl_bai}当前分支: ${gl_lv}$old_name ${gl_bai}→ ${gl_huang}$new_name${gl_bai}"
        
        if git branch -m "$new_name" 2>/dev/null; then
            log_ok "当前分支重命名为: ${gl_huang}$new_name${gl_bai}"
            
            read -r -e -p "$(echo -e "${gl_bai}是否更新远程分支? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" update_remote
            
            if [[ "$update_remote" =~ ^[Yy]$ ]]; then
                if git push origin --delete "$old_name" 2>/dev/null && git push -u origin "$new_name" 2>/dev/null; then
                    log_ok "远程分支已更新: ${gl_huang}origin/$old_name → origin/$new_name${gl_bai}"
                else
                    log_warn "更新远程分支失败，请手动执行:"
                    echo -e "${gl_hui}  git push origin --delete $old_name"
                    echo -e "${gl_hui}  git push -u origin $new_name${gl_bai}"
                fi
            fi
        else
            log_error "重命名失败"
        fi
    else
        echo -e "${gl_bai}分支重命名: ${gl_lv}$old_name ${gl_bai}→ ${gl_huang}$new_name${gl_bai}"
        
        if git branch -m "$old_name" "$new_name" 2>/dev/null; then
            log_ok "分支重命名成功: ${gl_huang}$old_name → $new_name${gl_bai}"
        else
            log_error "重命名失败"
        fi
    fi
    
    break_end
}

git_branch_menu() {
    local target_dir="${1:-$(pwd)}"
    
    if [[ ! -d "$target_dir" ]]; then
        log_error "目录不存在: ${gl_huang}$target_dir${gl_bai}"
        break_end
        return 1
    fi
    
    if ! cd "$target_dir" 2>/dev/null; then
        log_error "无法进入目录: ${gl_huang}$target_dir${gl_bai}"
        break_end
        return 1
    fi
    
    if ! check_git_repo; then
        break_end
        return 1
    fi
    
    while true; do
        clear
        echo -e ""
        echo -e "${gl_zi}>>> Git 分支管理${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        local repo_name=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "未知仓库")
        local current_branch=$(get_current_branch)
        local commit_count=$(git rev-list --count HEAD 2>/dev/null || echo "?")
        local last_commit=$(git log -1 --format="%s" 2>/dev/null | head -c 50)
        
        echo -e "${gl_bai}仓库: ${gl_huang}$repo_name"
        echo -e "${gl_bai}分支: ${gl_lv}$current_branch"
        echo -e "${gl_bai}提交: ${gl_lan}$commit_count"
        
        if [[ -n "$last_commit" ]]; then
            echo -e "${gl_bai}最近提交: ${gl_hui}$last_commit"
        fi
        
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}查看所有分支        ${gl_bufan}2.  ${gl_bai}创建新分支"
        echo -e "${gl_bufan}3.  ${gl_bai}删除分支            ${gl_bufan}4.  ${gl_bai}切换分支"
        echo -e "${gl_bufan}5.  ${gl_bai}合并分支            ${gl_bufan}6.  ${gl_bai}重命名分支"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单      ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" choice
        
        case $choice in
            1) list_branches ;;
            2) create_branch ;;
            3) delete_branch ;;
            4) switch_branch ;;
            5) merge_branch ;;
            6) rename_branch ;;
            0) cancel_return "已是主菜单" && continue ;;
            00) exit_script ;;
            *) handle_invalid_input ;;
        esac
    done
}

main() {
    if [[ -n "${1:-}" ]]; then
        git_branch_menu "$1"
    else
        git_branch_menu
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi