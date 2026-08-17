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


sleep_fractional() {
    local seconds=$1
    if sleep "$seconds" 2>/dev/null; then return 0; fi
    if command -v perl >/dev/null 2>&1; then perl -e "select(undef, undef, undef, $seconds)"; return 0; fi
    if command -v python3 >/dev/null 2>&1; then python3 -c "import time; time.sleep($seconds)"; return 0; fi
    if command -v python >/dev/null 2>&1; then python -c "import time; time.sleep($seconds)"; return 0; fi
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


cancel_return() {
    local menu_name="${1:-上一级选单}"
    echo -e "${gl_lv}即将返回到 ${gl_huang}${menu_name}${gl_lv} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    sleep_fractional 0.6
    echo ""
    clear
}


break_end() {
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n 1 -s -r -p ""
    echo ""
    clear
}


safe_read() {
    local prompt="$1"
    local var_name="$2"
    local type="${3:-"string"}"
    local default_value="${4:-}"
    local min_value="${5:-}"
    local max_value="${6:-}"
    local max_retry=3
    local retry_count=0
    
    while [[ $retry_count -lt $max_retry ]]; do
        if [[ -n "$default_value" ]]; then
            read -r -e -p "$(echo -e "${gl_bai}$prompt (${gl_huang}默认: $default_value${gl_bai}): ")" "$var_name"
            [[ -z "${!var_name}" ]] && eval "$var_name=\"\$default_value\""
        else
            read -r -e -p "$(echo -e "${gl_bai}$prompt: ")" "$var_name"
        fi
        
        if [[ -z "${!var_name}" ]]; then
            if [[ -n "$default_value" ]]; then
                eval "$var_name=\"\$default_value\""
                return 0
            else
                log_error "输入不能为空"
                retry_count=$((retry_count + 1))
                continue
            fi
        fi
        
        case "$type" in
            "number")
                if ! [[ "${!var_name}" =~ ^[0-9]+$ ]]; then
                    log_error "请输入数字"
                    retry_count=$((retry_count + 1))
                    continue
                fi
                
                if [[ -n "$min_value" ]] && [[ "${!var_name}" -lt "$min_value" ]]; then
                    log_error "输入值不能小于 $min_value"
                    retry_count=$((retry_count + 1))
                    continue
                fi
                
                if [[ -n "$max_value" ]] && [[ "${!var_name}" -gt "$max_value" ]]; then
                    log_error "输入值不能大于 $max_value"
                    retry_count=$((retry_count + 1))
                    continue
                fi
                ;;
            "y/n")
                if ! [[ "${!var_name}" =~ ^[YyNn]$ ]]; then
                    log_error "请输入 y 或 n"
                    retry_count=$((retry_count + 1))
                    continue
                fi
                ;;
        esac
        
        return 0
    done
    
    log_error "输入尝试次数过多，返回上一级"
    return 1
}


handle_invalid_input() {
    echo -ne "\r\033[K${gl_huang}无效的输入,请重新输入! ${gl_zi} 1 ${gl_huang} 秒后返回"
    sleep_fractional 1
    echo -ne "\r\033[K${gl_lv}无效的输入,请重新输入! ${gl_zi}0${gl_lv} 秒后返回"
    sleep_fractional 0.5
    echo -ne "\r\033[K"
    return 2
}


disk_speed_test() {
    local test_dir="$1"
    local test_file="${test_dir}/.speed_test_tmp.dat"
    local bs="1M"
    local count="500"
    local write_speed=""
    local read_speed=""


    [[ -d "${test_dir}" ]] || { log_error "目录不存在：${test_dir}"; return 1; }

    clear
    echo -e ""
    echo -e "${gl_zi}>>> 磁盘读写测速${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_info "测速目录地址: ${gl_huang}${test_dir}${gl_bai}"
    log_info "测试文件大小: ${gl_huang}${count}MiB${gl_bai}, 块大小=${gl_huang}${bs}${gl_bai}, 启用直接IO"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"


    echo -e "${gl_lv}▶ ${gl_bai}正在执行${gl_lv}写入${gl_bai}测速 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    local dd_out
    dd_out=$(dd if=/dev/zero of="${test_file}" bs=${bs} count=${count} oflag=direct 2>&1)
    local wr_ret=$?
    echo "${dd_out}"


    if [[ ${wr_ret} -ne 0 ]]; then
        log_warn "直接IO写入失败，关闭直接IO重试（受系统缓存影响，结果仅供参考）"
        dd_out=$(dd if=/dev/zero of="${test_file}" bs=${bs} count=${count} 2>&1)
        echo "${dd_out}"
    fi
    write_speed=$(echo "${dd_out}" | grep -Eo '[0-9.]+ MB/s' | awk '{print $1}')


    echo -e ""
    echo -e "${gl_lv}▶ ${gl_bai}正在执行${gl_lv}读取${gl_bai}测速 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    dd_out=$(dd if="${test_file}" of=/dev/null bs=${bs} iflag=direct 2>&1)
    local rd_ret=$?
    echo "${dd_out}"


    if [[ ${rd_ret} -ne 0 ]]; then
        log_warn "直接IO读取失败，关闭直接IO重试（受系统缓存影响，结果仅供参考）"
        dd_out=$(dd if="${test_file}" of=/dev/null bs=${bs} 2>&1)
        echo "${dd_out}"
    fi
    read_speed=$(echo "${dd_out}" | grep -Eo '[0-9.]+ MB/s' | awk '{print $1}')


    # log_info "清理临时测速文件"
    rm -f "${test_file}"

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_huang}测速汇总：${gl_bai}"
    if [[ -n "${write_speed}" ]]; then
        echo -e "  ${gl_bai}顺序${gl_lv}写入${gl_bai}速度：${gl_lv}${write_speed} MB/s${gl_bai}"
    else
        echo -e "  ${gl_bai}顺序${gl_lv}写入${gl_bai}速度：${gl_hong}获取失败${gl_bai}"
    fi
    if [[ -n "${read_speed}" ]]; then
        echo -e "  ${gl_bai}顺序${gl_lv}读取${gl_bai}速度：${gl_lv}${read_speed} MB/s${gl_bai}"
    else
        echo -e "  ${gl_bai}顺序${gl_lv}读取${gl_bai}速度：${gl_hong}获取失败${gl_bai}"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_ok "磁盘测速完成"
}


show_help() {
    echo -e "${gl_lv}使用说明:${gl_bai}"
    echo -e "  ${gl_bai}$0 ${gl_lan}[测速目录]${gl_bai}"
    echo -e ""
    echo -e "${gl_lv}参数:${gl_bai}"
    echo -e "  ${gl_lan}[测速目录]${gl_bai}  要测试的目录路径（默认为当前目录）"
    echo -e ""
    echo -e "${gl_lv}示例:${gl_bai}"
    echo -e "  ${gl_bai}$0 ${gl_lan}/mnt/data${gl_bai}    # 测试指定目录的磁盘速度"
    echo -e "  ${gl_bai}$0${gl_bai}                 # 测试当前目录的磁盘速度"
    echo -e "  ${gl_bai}$0 ${gl_lan}-h${gl_bai}           # 显示帮助信息"
    echo -e ""
    exit 0
}


interactive_menu() {
    clear
    echo -e ""
    echo -e "${gl_zi}>>> 磁盘读写测速工具${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    local target_dir
    safe_read "输入测速目录" "target_dir" "string" "$(pwd)"
    
    disk_speed_test "${target_dir}"

    break_end
}


main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                ;;
            *)
                disk_speed_test "$1"
                exit 0
                ;;
        esac
    done
    
    interactive_menu
}


if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
