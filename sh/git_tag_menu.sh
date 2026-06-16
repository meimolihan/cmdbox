#!/bin/bash
set -uo pipefail

list_color_init() {
    export gl_hui=$'\033[38;5;59m'   # 灰色
    export gl_hong=$'\033[38;5;9m'   # 红色
    export gl_lv=$'\033[38;5;10m'    # 绿色
    export gl_huang=$'\033[38;5;11m' # 黄色
    export gl_lan=$'\033[38;5;32m'   # 蓝色
    export gl_bai=$'\033[38;5;15m'   # 白色
    export gl_zi=$'\033[38;5;13m'    # 紫色
    export gl_bufan=$'\033[38;5;14m' # 亮青色
    export reset=$'\033[0m'          # 重置
}
list_color_init

log_info()  { echo -e "${gl_lan}[信息]${gl_bai} $*"; }
log_ok()    { echo -e "${gl_lv}[成功]${gl_bai} $*"; }
log_warn()  { echo -e "${gl_huang}[警告]${gl_bai} $*"; }
log_error() { echo -e "${gl_hong}[错误]${gl_bai} $*" >&2; }

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
    sleep_fractional 1
    echo -e "${gl_huang}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai})${gl_huang}。${gl_bai}"
    sleep_fractional 1
    echo -e "${gl_lv}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai})${gl_lv}。${gl_bai}"
    sleep_fractional 0.5
    return 2
}

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n 1 -s -r -p ""
    echo ""
    clear
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

# 检查 Git 仓库
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

list_tags() {
    clear
    echo -e ""
    echo -e "${gl_zi}>>> 所有标签列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    local tag_count=$(git tag 2>/dev/null | wc -l)
    if [[ "$tag_count" -eq 0 ]]; then
        echo -e "${gl_hui}  无标签${gl_bai}"
    else
        git tag -n | while IFS= read -r tag_line; do
            echo -e "${gl_bai}  $tag_line"
        done
    fi
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}标签数量: ${gl_lv}$tag_count${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

create_lightweight_tag() {
    echo -e ""
    read -r -e -p "$(echo -e "${gl_bai}请输入标签名称(${gl_huang}0${gl_bai}返回): ")" tag_name
    [ "$tag_name" = "0" ] && { cancel_return "Git 标签管理"; return 1; }
    
    if [[ -z "$tag_name" ]]; then
        log_error "标签名称不能为空"
        break_end
        return 1
    fi
    
    if git rev-parse --verify --quiet "$tag_name" >/dev/null; then
        log_error "标签 ${gl_huang}$tag_name ${gl_hong}已存在"
        break_end
        return 1
    fi
    
    read -r -e -p "$(echo -e "${gl_bai}在哪个提交创建标签? (默认: 最新提交, 输入 commit hash 或分支名): ")" commit_ref
    commit_ref="${commit_ref:-HEAD}"
    
    echo -e ""
    if git tag "$tag_name" "$commit_ref" 2>/dev/null; then
        log_ok "轻量标签 ${gl_huang}$tag_name ${gl_lv}创建成功"
        
        read -r -e -p "$(echo -e "${gl_bai}是否立即推送到远程仓库? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" push_now
        
        if [[ "$push_now" =~ ^[Yy]$ ]]; then
            if git push origin "$tag_name" 2>/dev/null; then
                log_ok "标签已推送到远程仓库"
            else
                log_warn "推送失败，请手动执行: git push origin $tag_name"
            fi
        fi
    else
        log_error "标签创建失败"
    fi
    
    break_end
}

create_annotated_tag() {
    echo -e ""
    read -r -e -p "$(echo -e "${gl_bai}请输入标签名称(${gl_huang}0${gl_bai}返回): ")" tag_name
    [ "$tag_name" = "0" ] && { cancel_return "Git 标签管理"; return 1; }
    
    if [[ -z "$tag_name" ]]; then
        log_error "标签名称不能为空"
        break_end
        return 1
    fi
    
    if git rev-parse --verify --quiet "$tag_name" >/dev/null; then
        log_error "标签 ${gl_huang}$tag_name ${gl_hong}已存在"
        break_end
        return 1
    fi
    
    read -r -e -p "$(echo -e "${gl_bai}请输入标签描述: ")" tag_message
    if [[ -z "$tag_message" ]]; then
        tag_message="Release $tag_name"
    fi
    
    read -r -e -p "$(echo -e "${gl_bai}在哪个提交创建标签? (默认: 最新提交, 输入 commit hash 或分支名): ")" commit_ref
    commit_ref="${commit_ref:-HEAD}"
    
    echo -e ""
    if git tag -a "$tag_name" -m "$tag_message" "$commit_ref" 2>/dev/null; then
        log_ok "附注标签 ${gl_huang}$tag_name ${gl_lv}创建成功"
        
        read -r -e -p "$(echo -e "${gl_bai}是否立即推送到远程仓库? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" push_now
        
        if [[ "$push_now" =~ ^[Yy]$ ]]; then
            if git push origin "$tag_name" 2>/dev/null; then
                log_ok "标签已推送到远程仓库"
            else
                log_warn "推送失败，请手动执行: git push origin $tag_name"
            fi
        fi
    else
        log_error "标签创建失败"
    fi
    
    break_end
}

delete_local_tag() {
    echo -e ""
    echo -e "${gl_bai}当前标签列表:${gl_bai}"
    git tag -n
    
    echo -e ""
    read -r -e -p "$(echo -e "${gl_bai}请输入要删除的标签名称(${gl_huang}0${gl_bai}返回): ")" tag_name
    [ "$tag_name" = "0" ] && { cancel_return "Git 标签管理"; return 1; }
    
    if [[ -z "$tag_name" ]]; then
        log_error "标签名称不能为空"
        break_end
        return 1
    fi
    
    if ! git rev-parse --verify --quiet "$tag_name" >/dev/null; then
        log_error "标签 ${gl_huang}$tag_name ${gl_hong}不存在"
        break_end
        return 1
    fi
    
    echo -e ""
    read -r -e -p "$(echo -e "${gl_hong}确认删除标签 ${gl_huang}$tag_name${gl_hong}? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_warn "取消删除"
        break_end
        return 0
    fi
    
    if git tag -d "$tag_name" 2>/dev/null; then
        log_ok "本地标签 ${gl_huang}$tag_name ${gl_lv}已删除"
    else
        log_error "标签删除失败"
    fi
    
    break_end
}

push_tag() {
    echo -e ""
    echo -e "${gl_bai}当前标签列表:${gl_bai}"
    git tag -n
    
    echo -e ""
    read -r -e -p "$(echo -e "${gl_bai}请输入要推送的标签名称(留空推送所有标签, ${gl_huang}0${gl_bai}返回): ")" tag_name
    [ "$tag_name" = "0" ] && { cancel_return "Git 标签管理"; return 1; }
    
    if [[ -z "$tag_name" ]]; then
        read -r -e -p "$(echo -e "${gl_hong}确认推送所有标签到远程? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm_all
        
        if [[ "$confirm_all" =~ ^[Yy]$ ]]; then
            echo -e ""
            if git push --tags; then
                log_ok "所有标签已推送到远程"
            else
                log_error "标签推送失败"
            fi
        else
            log_warn "取消推送"
        fi
    else
        if ! git rev-parse --verify --quiet "$tag_name" >/dev/null; then
            log_error "标签 ${gl_huang}$tag_name ${gl_hong}不存在"
            break_end
            return 1
        fi
        
        echo -e ""
        read -r -e -p "$(echo -e "${gl_bai}确认推送标签 ${gl_huang}$tag_name ${gl_bai}到远程? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            if git push origin "$tag_name"; then
                log_ok "标签 ${gl_huang}$tag_name ${gl_lv}已推送到远程"
            else
                log_error "标签推送失败"
            fi
        else
            log_warn "取消推送"
        fi
    fi
    
    break_end
}

delete_remote_tag() {
    echo -e ""
    echo -e "${gl_bai}当前标签列表:${gl_bai}"
    git tag -n
    
    echo -e ""
    read -r -e -p "$(echo -e "${gl_bai}请输入要删除的远程标签名称(${gl_huang}0${gl_bai}返回): ")" tag_name
    [ "$tag_name" = "0" ] && { cancel_return "Git 标签管理"; return 1; }
    
    if [[ -z "$tag_name" ]]; then
        log_error "标签名称不能为空"
        break_end
        return 1
    fi
    
    if ! git rev-parse --verify --quiet "$tag_name" >/dev/null; then
        log_error "标签 ${gl_huang}$tag_name ${gl_hong}不存在"
        break_end
        return 1
    fi
    
    echo -e ""
    echo -e "${gl_hong}警告: 将删除远程标签 ${gl_huang}$tag_name${gl_hong}${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}确认删除? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_warn "取消删除"
        break_end
        return 0
    fi
    
    echo -e ""
    if git push origin --delete "$tag_name" 2>/dev/null; then
        log_ok "远程标签 ${gl_huang}$tag_name ${gl_lv}已删除"
        
        read -r -e -p "$(echo -e "${gl_bai}是否同时删除本地标签? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" delete_local
        
        if [[ "$delete_local" =~ ^[Yy]$ ]]; then
            if git tag -d "$tag_name" 2>/dev/null; then
                log_ok "本地标签 ${gl_huang}$tag_name ${gl_lv}已删除"
            else
                log_warn "本地标签删除失败"
            fi
        fi
    else
        log_error "远程标签删除失败"
    fi
    
    break_end
}

show_tag() {
    echo -e ""
    echo -e "${gl_bai}当前标签列表:${gl_bai}"
    git tag -n
    
    echo -e ""
    read -r -e -p "$(echo -e "${gl_bai}请输入要查看的标签名称(${gl_huang}0${gl_bai}返回): ")" tag_name
    [ "$tag_name" = "0" ] && { cancel_return "Git 标签管理"; return 1; }
    
    if [[ -z "$tag_name" ]]; then
        log_error "标签名称不能为空"
        break_end
        return 1
    fi
    
    clear
    echo -e ""
    echo -e "${gl_zi}>>> 标签详情: ${gl_huang}$tag_name${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    if git rev-parse --verify --quiet "$tag_name" >/dev/null; then
        echo -e "${gl_bai}标签类型: ${gl_lv}$(git cat-file -t "$tag_name" 2>/dev/null)${gl_bai}"
        echo -e "${gl_bai}标签信息:${gl_bai}"
        git show --quiet --stat "$tag_name"
        
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bai}标签内容:${gl_bai}"
        git cat-file -p "$tag_name" 2>/dev/null
    else
        log_error "标签 ${gl_huang}$tag_name ${gl_hong}不存在"
    fi
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

batch_sync_tags() {
    echo -e ""
    echo -e "${gl_zi}>>> 批量标签同步${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    local local_tags=()
    while IFS= read -r tag; do
        [[ -n "$tag" ]] && local_tags+=("$tag")
    done < <(git tag 2>/dev/null)
    
    local remote_tags=()
    while IFS= read -r tag; do
        [[ -n "$tag" ]] && remote_tags+=("$tag")
    done < <(git ls-remote --tags origin 2>/dev/null | awk -F'/' '{print $3}' | sed 's/\^{}//')
    
    if [[ ${#local_tags[@]} -eq 0 ]]; then
        echo -e "${gl_huang}本地没有标签${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return 0
    fi
    
    local only_local=()
    local only_remote=()
    local synced=()
    
    for tag in "${local_tags[@]}"; do
        if [[ " ${remote_tags[*]} " =~ " ${tag} " ]]; then
            synced+=("$tag")
        else
            only_local+=("$tag")
        fi
    done
    
    for tag in "${remote_tags[@]}"; do
        if [[ ! " ${local_tags[*]} " =~ " ${tag} " ]]; then
            only_remote+=("$tag")
        fi
    done
    
    echo -e "${gl_bai}标签同步状态:${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    echo -e "${gl_lv}仅本地 (${#only_local[@]}):${gl_bai}"
    if [[ ${#only_local[@]} -gt 0 ]]; then
        for tag in "${only_local[@]}"; do
            echo -e "  ${gl_huang}↑${gl_bai} $tag"
        done
    else
        echo -e "  ${gl_hui}  (无)${gl_bai}"
    fi
    
    echo -e ""
    echo -e "${gl_lan}仅远程 (${#only_remote[@]}):${gl_bai}"
    if [[ ${#only_remote[@]} -gt 0 ]]; then
        for tag in "${only_remote[@]}"; do
            echo -e "  ${gl_hong}↓${gl_bai} $tag"
        done
    else
        echo -e "  ${gl_hui}  (无)${gl_bai}"
    fi
    
    echo -e ""
    echo -e "${gl_lv}已同步 (${#synced[@]}):${gl_bai}"
    if [[ ${#synced[@]} -gt 0 ]]; then
        for tag in "${synced[@]}"; do
            echo -e "  ${gl_lv}✓${gl_bai} $tag"
        done
    else
        echo -e "  ${gl_hui}  (无)${gl_bai}"
    fi
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bufan}1.  ${gl_bai}推送所有本地标签到远程"
    echo -e "${gl_bufan}2.  ${gl_bai}拉取所有远程标签到本地"
    echo -e "${gl_bufan}3.  ${gl_bai}删除本地未推送的标签"
    echo -e "${gl_bufan}4.  ${gl_bai}删除远程已不存在的本地标签"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_huang}0.  ${gl_bai}返回"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}请选择操作: ")" sync_choice
    
    case "$sync_choice" in
    1)
        if [[ ${#only_local[@]} -eq 0 ]]; then
            log_warn "没有需要推送的本地标签"
            break_end
            return 0
        fi
        echo -e ""
        echo -e "${gl_bai}将推送以下标签:${gl_bai}"
        for tag in "${only_local[@]}"; do
            echo -e "  ${gl_huang}↑ $tag${gl_bai}"
        done
        read -r -e -p "$(echo -e "${gl_bai}确认推送? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            if git push --tags; then
                log_ok "所有本地标签已推送到远程"
            else
                log_error "推送失败"
            fi
        else
            log_warn "取消推送"
        fi
        ;;
    2)
        if [[ ${#only_remote[@]} -eq 0 ]]; then
            log_warn "没有需要拉取的远程标签"
            break_end
            return 0
        fi
        echo -e ""
        echo -e "${gl_bai}将拉取以下标签:${gl_bai}"
        for tag in "${only_remote[@]}"; do
            echo -e "  ${gl_hong}↓ $tag${gl_bai}"
        done
        read -r -e -p "$(echo -e "${gl_bai}确认拉取? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            if git fetch --tags; then
                log_ok "远程标签已拉取到本地"
            else
                log_error "拉取失败"
            fi
        else
            log_warn "取消拉取"
        fi
        ;;
    3)
        if [[ ${#only_local[@]} -eq 0 ]]; then
            log_warn "没有仅本地的标签"
            break_end
            return 0
        fi
        echo -e ""
        echo -e "${gl_hong}警告: 将删除以下仅本地的标签:${gl_bai}"
        for tag in "${only_local[@]}"; do
            echo -e "  ${gl_hong}✗ $tag${gl_bai}"
        done
        read -r -e -p "$(echo -e "${gl_hong}确认删除? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            local del_count=0
            for tag in "${only_local[@]}"; do
                if git tag -d "$tag" 2>/dev/null; then
                    ((del_count++))
                    log_info "已删除: $tag"
                fi
            done
            log_ok "共删除 $del_count 个本地标签"
        else
            log_warn "取消删除"
        fi
        ;;
    4)
        if [[ ${#only_remote[@]} -eq 0 ]]; then
            log_warn "没有仅远程的标签"
            break_end
            return 0
        fi
        echo -e ""
        echo -e "${gl_hong}警告: 将删除以下远程标签（本地保留）:${gl_bai}"
        for tag in "${only_remote[@]}"; do
            echo -e "  ${gl_hong}✗ $tag${gl_bai}"
        done
        read -r -e -p "$(echo -e "${gl_hong}确认删除远程标签? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            local del_count=0
            for tag in "${only_remote[@]}"; do
                if git push origin --delete "$tag" 2>/dev/null; then
                    ((del_count++))
                    log_info "已删除远程: $tag"
                fi
            done
            log_ok "共删除 $del_count 个远程标签"
        else
            log_warn "取消删除"
        fi
        ;;
    0)
        cancel_return "Git 标签管理"
        return 1
        ;;
    *)
        handle_invalid_input
        return 1
        ;;
    esac
    
    break_end
}

git_tag_menu() {
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
        echo -e "${gl_zi}>>> Git 标签管理${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        local repo_name=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "未知仓库")
        local current_branch=$(git branch --show-current 2>/dev/null || echo "")
        local tag_count=$(git tag 2>/dev/null | wc -l)
        
        echo -e "${gl_bai}仓库: ${gl_huang}$repo_name"
        echo -e "${gl_bai}分支: ${gl_lv}$current_branch"
        echo -e "${gl_bai}标签: ${gl_lan}$tag_count${gl_bai}"
        
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}查看所有标签        ${gl_bufan}2.  ${gl_bai}创建轻量标签"
        echo -e "${gl_bufan}3.  ${gl_bai}创建附注标签        ${gl_bufan}4.  ${gl_bai}删除本地标签"
        echo -e "${gl_bufan}5.  ${gl_bai}推送标签到远程      ${gl_bufan}6.  ${gl_bai}删除远程标签"
        echo -e "${gl_bufan}7.  ${gl_bai}查看标签详情        ${gl_bufan}8.  ${gl_bai}批量标签同步"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单      ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" choice
        
        case $choice in
            1) list_tags ;;
            2) create_lightweight_tag ;;
            3) create_annotated_tag ;;
            4) delete_local_tag ;;
            5) push_tag ;;
            6) delete_remote_tag ;;
            7) show_tag ;;
            8) batch_sync_tags ;;
            0) cancel_return "已是主菜单" || continue ;;
            00 | 000 | 0000) exit_script ;;
            *) handle_invalid_input ;;
        esac
    done
}

main() {
    git_tag_menu "${1:-}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi