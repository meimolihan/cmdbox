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

log_info() { echo -e "${gl_lan}[信息]${gl_bai} $*"; }
log_ok() { echo -e "${gl_lv}[成功]${gl_bai} $*"; }
log_warn() { echo -e "${gl_huang}[警告]${gl_bai} $*"; }
log_error() { echo -e "${gl_hong}[错误]${gl_bai} $*" >&2; }

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

cancel_return() {
    local menu_name="${1:-上一级选单}"
    echo -e "${gl_lv}即将返回到 ${gl_huang}${menu_name}${gl_lv} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
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
    echo -e "${gl_hong}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai})${gl_hong}。${gl_bai}"
    sleep_fractional 1
    echo -e "${gl_huang}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai})${gl_huang}。${gl_bai}"
    sleep_fractional 1
    echo -e "${gl_lv}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai})${gl_lv}。${gl_bai}"
    sleep_fractional 0.5
    return 2
}

cancel_empty() {
    local menu_name="${1:-上一级选单}"
    echo -e "${gl_hong}空输入，返回 ${gl_huang}${menu_name} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
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

confirm_y_n() {
    local prompt="$1"
    local ans
    while true; do
        read -r -p "$(echo -e "${gl_huang}${prompt} ${gl_bai}[${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}]: ")" ans
        case "$ans" in
            y|Y) return 0 ;;
            n|N|"") return 1 ;;
            *) handle_y_n ;;
        esac
    done
}

get_backup_list() {
    local bak_dir="$1"
    find "${bak_dir}" -maxdepth 1 -type f -name "*.txt" -printf "%T@ %p\n" 2>/dev/null | sort -nr | cut -d' ' -f2-
}

print_backup_top5() {
    local bak_dir="$1"
    mkdir -p "${bak_dir}"
    local file_list
    file_list=$(get_backup_list "${bak_dir}")
    if [[ -z "${file_list}" ]]; then
        log_warn "暂无Git备份记录"
        return 1
    fi
    local idx=1
    while IFS= read -r file && (( idx <=5 )); do
        local commit_hash
        local mtime
        commit_hash=$(head -n1 "${file}")
        mtime=$(date -d "@$(stat -c %Y "${file}")" +"%Y-%m-%d %H:%M:%S")
        local note="${file##*/}"
        note="${note%.txt}"
        echo -e "${gl_lv}${idx}.${gl_bai} 版本:${gl_zi}${commit_hash}${gl_bai} | 备注:${gl_huang}${note}${gl_bai} | 时间:${gl_bufan}${mtime}${gl_bai}"
        ((idx++))
    done <<< "${file_list}"
    return 0
}

print_full_backup_list() {
    local bak_dir="$1"
    mkdir -p "${bak_dir}"
    file_list=()
    local raw_list
    raw_list=$(get_backup_list "${bak_dir}")
    if [[ -z "${raw_list}" ]]; then
        log_warn "暂无Git备份记录"
        return 1
    fi
    local idx=1
    while IFS= read -r file; do
        file_list+=("${file}")
        local commit_hash
        local mtime
        commit_hash=$(head -n1 "${file}")
        mtime=$(date -d "@$(stat -c %Y "${file}")" +"%Y-%m-%d %H:%M:%S")
        local note="${file##*/}"
        note="${note%.txt}"
        echo -e "${gl_lv}${idx}.${gl_bai} 版本:${gl_zi}${commit_hash}${gl_bai} | 备注:${gl_huang}${note}${gl_bai} | 时间:${gl_bufan}${mtime}${gl_bai}"
        ((idx++))
    done <<< "${raw_list}"
    return 0
}

git_backup() {
    local bak_dir="$1"
    local note="$2"
    log_info "正在获取当前Git短commit哈希"
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        log_error "当前目录不是Git仓库！"
        return 1
    fi
    local short_hash
    short_hash=$(git rev-parse --short HEAD)
    mkdir -p "${bak_dir}"
    local bak_file="${bak_dir}/${note}.txt"
    echo "${short_hash}" > "${bak_file}"
    log_ok "备份成功！"
    log_info "备份文件: ${bak_file}"
    log_info "Commit: ${short_hash}"
    return 0
}

git_reset() {
    local bak_file="$1"
    if [[ ! -f "${bak_file}" ]]; then
        log_error "备份文件不存在: ${bak_file}"
        return 1
    fi
    local commit_hash
    commit_hash=$(head -n1 "${bak_file}")
    log_warn "准备执行 git reset --hard ${commit_hash}"
    log_warn "⚠️  本地未提交的修改会全部丢失！"
    if confirm_y_n "确认执行本地reset回滚"; then
        git reset --hard "${commit_hash}"
        log_ok "本地reset回滚完成，commit: ${commit_hash}"
    else
        log_info "已取消reset操作"
    fi
    return 0
}

git_revert() {
    local bak_file="$1"
    if [[ ! -f "${bak_file}" ]]; then
        log_error "备份文件不存在: ${bak_file}"
        return 1
    fi
    local commit_hash
    commit_hash=$(head -n1 "${bak_file}")
    log_warn "准备执行 git revert ${commit_hash} && git push"
    log_warn "⚠️  将生成revert提交并推送到远程仓库"
    if confirm_y_n "确认执行远程revert回滚并推送"; then
        git revert "${commit_hash}"
        git push
        log_ok "远程revert完成并推送，commit: ${commit_hash}"
    else
        log_info "已取消revert操作"
    fi
    return 0
}

menu_git_version() {
    local default_bak_dir="$1"
    while true; do
        clear
        echo -e "${gl_zi}>>> Git 版本备份与还原${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}【当前备份目录】${gl_lan}${default_bak_dir}${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        print_backup_top5 "${default_bak_dir}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}备份当前版本"
        echo -e "${gl_bufan}2.  ${gl_bai}还原历史版本"
        echo -e "${gl_bufan}3.  ${gl_bai}删除历史备份"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单"
        echo -e "${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" action
        case "${action}" in
        1)
            clear
            echo -e "${gl_zi}>>> 备份当前Git版本${gl_bai}"
            echo -e "${gl_bufan}----------------------------${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bai}备份目录 [默认:${gl_lan}${default_bak_dir}${gl_bai}]: ")" input_dir
            local bak_dir="${input_dir:-${default_bak_dir}}"
            read -r -e -p "$(echo -e "${gl_bai}输入备注名称(文件名，自动加.txt后缀): ")" note_name
            if [[ -z "${note_name}" ]]; then
                cancel_empty "Git备份菜单"
                continue
            fi
            git_backup "${bak_dir}" "${note_name}"
            echo -e "${gl_bufan}----------------------------${gl_bai}"
            break_end
            ;;
        2)
            clear
            echo -e "${gl_zi}>>> 还原历史版本${gl_bai}"
            echo -e "${gl_bufan}【当前备份目录】${gl_lan}${default_bak_dir}${gl_bai}"
            echo -e "${gl_bufan}----------------------------${gl_bai}"
            local file_list=()
            if ! print_full_backup_list "${default_bak_dir}"; then
                break_end
                continue
            fi
            echo -e "${gl_bufan}----------------------------${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bai}请输入要还原的序号: ")" sel_idx
            if ! [[ "${sel_idx}" =~ ^[0-9]+$ ]]; then
                handle_invalid_input
                continue
            fi
            local arr_idx=$((sel_idx - 1))
            if (( arr_idx < 0 || arr_idx >= ${#file_list[@]} )); then
                log_error "序号超出范围！"
                break_end
                continue
            fi
            local target_file="${file_list[$arr_idx]}"
            local commit_target
            commit_target=$(head -n1 "${target_file}")
            echo -e "${gl_bai}选中备份文件: ${gl_huang}${target_file}"
            echo -e "${gl_bai}对应commit: ${gl_zi}${commit_target}"
            echo -e "${gl_bufan}请选择还原方式：${gl_bai}"
            echo -e "${gl_lv}1${gl_bai}.本地reset回滚  ${gl_huang}2${gl_bai}.远程revert回滚"
            read -r -e -p "$(echo -e "${gl_bai}选择方式: ")" roll_type
            case "${roll_type}" in
                1) git_reset "${target_file}" ;;
                2) git_revert "${target_file}" ;;
                *) handle_invalid_input ;;
            esac
            echo -e "${gl_bufan}----------------------------${gl_bai}"
            break_end
            ;;
        3)
            clear
            echo -e "${gl_zi}>>> 删除历史备份${gl_bai}"
            echo -e "${gl_bufan}【当前备份目录】${gl_lan}${default_bak_dir}${gl_bai}"
            echo -e "${gl_bufan}----------------------------${gl_bai}"
            local file_list=()
            if ! print_full_backup_list "${default_bak_dir}"; then
                break_end
                continue
            fi
            echo -e "${gl_bufan}----------------------------${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bai}请输入要删除备份的序号: ")" sel_idx
            if ! [[ "${sel_idx}" =~ ^[0-9]+$ ]]; then
                handle_invalid_input
                continue
            fi
            local arr_idx=$((sel_idx - 1))
            if (( arr_idx < 0 || arr_idx >= ${#file_list[@]} )); then
                log_error "序号超出范围！"
                break_end
                continue
            fi
            local target_file="${file_list[$arr_idx]}"
            if confirm_y_n "确认删除备份文件 ${target_file} ?"; then
                rm -f "${target_file}"
                log_ok "备份文件已删除"
            else
                log_info "取消删除操作"
            fi
            echo -e "${gl_bufan}----------------------------${gl_bai}"
            break_end
            ;;
        0)
            cancel_return "主菜单"
            continue
            ;;
        00 | 000 | 0000)
            exit_script
            ;;
        *)
            handle_invalid_input
            ;;
        esac
    done
}

cli_main() {
    local cmd="$1"
    local arg="$2"
    local default_bak="/vol2/1000/tmp/Git-bak"
    case "${cmd}" in
        backup)
            local bak_target="${arg:-${default_bak}/backup_commit.txt}"
            local bak_dir="${bak_target%/*}"
            local note="${bak_target##*/}"
            note="${note%.txt}"
            git_backup "${bak_dir}" "${note}"
            ;;
        reset)
            local bak_file="${arg:-${default_bak}/backup_commit.txt}"
            git_reset "${bak_file}"
            ;;
        revert)
            local bak_file="${arg:-${default_bak}/backup_commit.txt}"
            git_revert "${bak_file}"
            ;;
        *)
            log_error "未知命令！支持：backup / reset / revert"
            log_info "示例："
            log_info "./git_version_tool.sh backup /vol2/1000/tmp/Git-bak/backup_commit.txt"
            log_info "./git_version_tool.sh reset /vol2/1000/tmp/Git-bak/backup_commit.txt"
            log_info "./git_version_tool.sh revert /vol2/1000/tmp/Git-bak/backup_commit.txt"
            exit 1
            ;;
    esac
}

main() {
    if [[ $# -eq 0 ]]; then
        menu_git_version "/vol2/1000/tmp/Git-bak"
    else
        local first_arg="$1"
        case "${first_arg}" in
            backup|reset|revert)
                cli_main "$@"
                ;;
            *)
                local target_dir="$first_arg"
                mkdir -p "${target_dir}"
                menu_git_version "${target_dir}"
                ;;
        esac
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
