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

exit_animation() {
    echo -ne "${gl_lv}即将退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep 0.6
    echo ""
}

file_rename_sorter() {
    local default_prefix="$1"
    shift
    local user_ext_list=("$@")

    [[ -z "$default_prefix" ]] && default_prefix="pc"

    echo ""
    echo -e "${gl_zi}>>> 批量文件重命名排序 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    read -r -e -p "$(echo -e "${gl_bai}请输入文件名前缀（默认 ${gl_lv}$default_prefix${gl_bai}）: ")" prefix
    [[ -z "$prefix" ]] && prefix="$default_prefix"
    log_info "正在使用前缀: ${gl_lv}$prefix${gl_bai}"

    local temp_folder="temp_rename_folder_$RANDOM"
    local processed_count=0
    local final_count=0
    local all_files=()

    shopt -s nullglob nocaseglob

    if [[ ${#user_ext_list[@]} -eq 0 ]]; then
        log_info "匹配模式: ${gl_lv}全部文件${gl_bai}（保留原后缀）"
        all_files=(*)
        local script_name="${0##*/}"
        all_files=("${all_files[@]/$script_name/}")
    else
        log_info "匹配模式: ${gl_lv}指定后缀 ${user_ext_list[*]}${gl_bai}"
        for ext in "${user_ext_list[@]}"; do
            all_files+=(*."$ext")
        done
    fi

    local filter_files=()
    for f in "${all_files[@]}"; do
        [[ -f "$f" ]] && [[ -n "$f" ]] && [[ "$f" != .* ]] && filter_files+=("$f")
    done
    all_files=("${filter_files[@]}")

    if [[ ${#all_files[@]} -eq 0 ]]; then
        echo -e "${gl_huang}当前目录中未匹配到可处理文件${gl_bai}"
        exit_animation
        return 1
    fi
    log_info "共匹配到 ${#all_files[@]} 个待处理文件"

    if ! mkdir -p "$temp_folder" 2>/dev/null; then
        log_error "无法创建临时文件夹"
        exit_animation
        return 1
    fi

    echo ""
    log_info "正在移动文件到临时文件夹 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    for file in "${all_files[@]}"; do
        if mv -n "$file" "$temp_folder/" 2>/dev/null; then
            ((processed_count++))
            echo -e "  ${gl_huang}[$processed_count/${#all_files[@]}]${gl_bai} 已移动: ${gl_lv}$file${gl_bai}"
        else
            log_warn "移动失败: $file"
        fi
        sleep 0.01
    done

    local moved_files=("$temp_folder"/*)
    if [[ ${#moved_files[@]} -eq 0 ]]; then
        log_warn "没有文件被移动到临时文件夹"
        rm -rf "$temp_folder" 2>/dev/null
        exit_animation
        return 1
    fi

    echo ""
    log_info "正在批量重命名文件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    local rename_counter=1
    for old_path in "${moved_files[@]}"; do
        local file="${old_path##*/}"

        if [[ "$file" == *.* ]]; then
            local file_ext="${file##*.}"
            local new_file=$(printf "%s-%03d.%s" "$prefix" "$rename_counter" "$file_ext")
        else
            local new_file=$(printf "%s-%03d" "$prefix" "$rename_counter")
        fi

        echo -e "  ${gl_huang}[$rename_counter/${#moved_files[@]}]${gl_bai} 重命名: ${gl_lv}$file${gl_bai} → ${gl_lv}$new_file${gl_bai}"

        if mv -n "$old_path" "./$new_file" 2>/dev/null; then
            ((rename_counter++))
        else
            log_error "重命名失败: $file"
        fi
    done

    rm -rf "$temp_folder" 2>/dev/null

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    final_count=$((rename_counter - 1))

    if [[ $final_count -gt 0 ]]; then
        log_ok "文件批量重命名完成！共处理 ${gl_lv}$final_count${gl_bai} 个文件"
        log_info "规则: 仅修改文件名、完全保留原后缀格式"
    else
        log_warn "没有文件被重命名"
    fi
    return 0
}

if [[ $# -ge 1 ]]; then
    file_rename_sorter "$1" "${@:2}"
else
    file_rename_sorter "pc"
fi
