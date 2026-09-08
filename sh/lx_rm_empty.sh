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
    clear
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

del_empty_dir() {
    local target_dir
    local auto_confirm="0"
    local -a empty_dirs=()

    if [[ $# -ge 1 ]]; then
        target_dir="$1"
    else
        target_dir="$(pwd)"
    fi

    if [[ $# -ge 2 && "$2" == "--y" ]]; then
        auto_confirm="1"
    fi

    if [[ ! -d "${target_dir}" ]]; then
        log_error "目录不存在：${target_dir}"
        return 1
    fi

    log_info "扫描目录：${target_dir}"
    log_info "正在查找所有空目录（深度优先） ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    while IFS= read -r line; do
        empty_dirs+=("$line")
    done < <(find "${target_dir}" -depth -type d -empty 2>/dev/null)

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    local count=${#empty_dirs[@]}

    if [[ ${count} -eq 0 ]]; then
        log_ok "未发现任何空目录"
        break_end
        return 0
    fi

    log_warn "一共找到 ${gl_huang}${count}${gl_bai} 个空目录："
    for d in "${empty_dirs[@]}"; do
        echo -e "  ${gl_zi}${d}${gl_bai}"
    done
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local answer
    if [[ "${auto_confirm}" -eq 1 ]]; then
        answer="y"
        log_warn "免交互模式，直接开始删除..."
    else
        read -r -e -p "$(echo -e "${gl_bai}确认删除以上全部空目录？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" answer
        answer="${answer,,}"
        case "${answer}" in
            y|yes) ;;
            n|no|"")
                log_info "已取消删除操作"
                break_end
                return 0
                ;;
            *)
                handle_y_n
                return 2
                ;;
        esac
    fi

    local del_cnt=0
    log_info "开始删除空目录："
    for d in "${empty_dirs[@]}"; do
        if rmdir -- "${d}" 2>/dev/null; then
            log_ok "已删除：${d}"
            ((del_cnt++))
        else
            log_error "删除失败：${d}"
        fi
    done

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_ok "本次成功删除 ${gl_lv}${del_cnt}${gl_bai} / ${gl_huang}${count}${gl_bai} 个空目录"
    break_end
}

del_empty_dir "$@"