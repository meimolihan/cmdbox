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
reset=$'\033[0m'


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


cancel_return() {
    local menu_name="${1:-退出脚本}"
    echo -ne "${gl_lv}即将返回 ${gl_huang}${menu_name} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo ""
    clear
}


exit_script() {
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local dots=(
        "${gl_hong}."
        "${gl_huang}."
        "${gl_lv}."
        "${gl_bufan}."
        "${gl_zi}."
    )
    local dot_buffer=""
    local frame_len=${#frames[@]}
    local dot_idx=0
    local total_dots=${#dots[@]}
    for ((i=0; i<20; i++)); do
        if (( i > 0 && i % 3 == 0 && dot_idx < total_dots )); then
            dot_buffer+=${dots[$dot_idx]}
            ((dot_idx++))
        fi
        echo -ne "\r\033[K${gl_bufan}${frames[i % frame_len]}${gl_bai} 正在退出 ${dot_buffer}"
        sleep_fractional 0.06
    done
    echo -e "\r\033[K${gl_lv}✓${gl_bai} 成功退出\n"
    clear
    exit 0
}


handle_y_n() {
    echo -ne "\r${gl_hong}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}/${gl_hong}n${gl_bai}/${gl_zi}0${gl_bai}) ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.3
    echo -ne "\r${gl_huang}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}/${gl_hong}n${gl_bai}/${gl_zi}0${gl_bai}) ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.3
    echo -ne "\r${gl_lv}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}/${gl_hong}n${gl_bai}/${gl_zi}0${gl_bai}) ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo ""
    return 2
}


cancel_empty() {
    local menu_name="${1:-上一级选单}"
    echo -e "${gl_hong}空输入，返回 ${gl_huang}${menu_name} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo ""
    clear
}


handle_invalid_input() {
    echo -ne "\r\033[K${gl_huang}无效的输入,请重新输入! ${gl_zi} 1 ${gl_huang} 秒后返回"
    sleep_fractional 1
    echo -ne "\r\033[K${gl_lv}无效的输入,请重新输入! ${gl_zi}0${gl_lv} 秒后返回"
    sleep_fractional 0.5
    echo -ne "\r\033[K"
    return 2
}


confirm_action() {
    local prompt="$1"
    local ans
    while true; do
        read -r -p "$(echo -e "${gl_huang}${prompt} ${gl_bai}[${gl_lv}y${gl_bai}=本地+推送 / ${gl_hong}n${gl_bai}=仅本地回滚 / ${gl_zi}0${gl_bai}=取消退出]: ")" ans
        case "$ans" in
            y|Y) return 0 ;;
            n|N) return 1 ;;
            0)   exit_script ;;
            *) handle_y_n ;;
        esac
    done
}


check_git_repo() {
    local repo_path="$1"
    if [[ ! -d "${repo_path}" ]]; then
        log_error "目录不存在：${repo_path}"
        return 1
    fi
    cd "${repo_path}" || { log_error "无法进入目录 ${repo_path}"; return 1; }
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        log_error "当前目录不是Git仓库！"
        return 1
    fi
    return 0
}


list_recent_8_commit() {
    local -n out_arr=$1
    out_arr=()
    while IFS= read -r line; do
        out_arr+=("${line}")
    done < <(git log --oneline -8)
}


show_commit_detail() {
    local hash="$1"
    echo -e "${gl_huang}>>> 提交 ${gl_lv}${hash} ${gl_huang}详细信息${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    git show --stat "${hash}"
}


run_hard_reset_push() {
    local repo_path="$1"
    local target_hash="$2"
    local auto_yes="$3"
    if ! check_git_repo "${repo_path}"; then
        return 1
    fi


    if ! git rev-parse --verify "${target_hash}" >/dev/null 2>&1; then
        log_error "提交哈希 ${target_hash} 在仓库中不存在！"
        return 1
    fi


    show_commit_detail "${target_hash}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_warn "⚠️ 操作说明：git reset --hard ${target_hash}"
    log_warn "⚠️ 本地所有未提交修改会全部丢失，丢弃该提交之后所有本地提交！"
    local action_code=0
    if [[ "${auto_yes}" == "1" ]]; then
        log_info "免交互模式，自动确认：本地硬回滚 + 远程强制同步"
        action_code=0
    else
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        confirm_action "请选择执行方式"
        action_code=$?
        case "${action_code}" in
            2)
                log_info "已选择0，取消，不执行任何操作"
                return 0
                ;;
        esac
    fi


    if [[ "${action_code}" -eq 0 ]]; then
        # y：本地回滚 + 推送
        log_info "执行 git reset --hard ${target_hash}"
        git reset --hard "${target_hash}"
        log_ok "✅ 本地硬回滚完成"
        local br_name
        br_name=$(git rev-parse --abbrev-ref HEAD)
        log_info "当前分支: ${br_name}"
        log_warn "⚠️ 高危：执行 git push --force-with-lease origin ${br_name}"
        git push --force-with-lease origin "${br_name}"
        log_ok "✅ 远程分支已强制同步完成"
    else
        # n：仅本地回滚，不推送
        log_info "执行 git reset --hard ${target_hash}"
        git reset --hard "${target_hash}"
        log_ok "✅ 仅本地硬回滚完成，不推送远程"
    fi
    return 0
}


menu_git_hard_reset() {
    local repo_path="${1:-.}"
    while true; do
        clear
        echo -e "${gl_zi}>>> 本地硬回滚 + 远程强制同步${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        if ! check_git_repo "${repo_path}"; then
            cancel_return "退出脚本"
            return 1
        fi
        local commit_list=()
        list_recent_8_commit commit_list
        local count=${#commit_list[@]}
        if (( count == 0 )); then
            log_warn "仓库暂无提交记录"
            break_end
            continue
        fi
        log_info "最近8条提交列表（选择序号，或手动输入完整/短hash）"
        for ((i=0; i<count; i++)); do
            echo -e "${gl_lv}$((i+1)).${gl_bai} ${commit_list[$i]}"
        done
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}说明：选择序号或者手动输入commit hash，执行硬回滚${gl_bai}"
        echo -e "${gl_huang}      回滚后可选择是否强制同步远程${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" sel_input
        if [[ -z "${sel_input}" ]]; then
            cancel_empty "Git硬回滚菜单"
            continue
        fi
        local target_hash=""
        if [[ "${sel_input}" =~ ^[0-9]+$ ]]; then
            local idx=$((sel_input -1))
            if (( idx <0 || idx >= count )); then
                log_error "序号超出范围！"
                break_end
                continue
            fi
            target_hash=$(echo "${commit_list[$idx]}" | awk '{print $1}')
        else
            target_hash="${sel_input}"
        fi
        clear
        run_hard_reset_push "${repo_path}" "${target_hash}" "0"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
    done
}
cli_main() {
    local repo_path=""
    local commit_id=""
    local auto_yes=0
    for arg in "$@"; do
        case "${arg}" in
            -y) auto_yes=1 ;;
            *)
                if [[ -d "${arg}" ]]; then
                    repo_path="${arg}"
                elif [[ "${arg}" =~ ^[0-9a-fA-F]{4,40}$ ]]; then
                    commit_id="${arg}"
                fi
                ;;
        esac
    done
    if [[ -z "${repo_path}" || -z "${commit_id}" ]]; then
        log_error "参数不足！用法："
        log_info "交互模式(无参数): $0"
        log_info "半交互: $0 /vol1/1000/GitHub/fan-md 4c867d5"
        log_info "免交互: $0 /vol1/1000/GitHub/fan-md 4c867d5 -y"
        log_info "参数位置可互换，支持 $0 4c867d5 /vol1/1000/GitHub/fan-md -y"
        exit 1
    fi
    run_hard_reset_push "${repo_path}" "${commit_id}" "${auto_yes}"
}


main() {
    if [[ $# -eq 0 ]]; then
        menu_git_hard_reset "."
    else
        cli_main "$@"
    fi
}
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
