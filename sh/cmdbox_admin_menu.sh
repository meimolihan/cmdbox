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
    echo -ne "${gl_lv}即将 ${gl_huang}${menu_name} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
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
    echo -ne "\r${gl_hong}无效的输入，请重新输入 ${gl_zi} 2 ${gl_hong}秒后返回 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.3
    echo -ne "\r${gl_huang}无效的输入，请重新输入 ${gl_zi} 1 ${gl_huang}秒后返回 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.3
    echo -e "\r${gl_lv}无效的输入，请重新输入 ${gl_zi} 0 ${gl_lv}秒后返回 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    continue
}

go_parent_directory() {
    if [[ "$(pwd)" != "/" ]]; then
        local current_path="$(pwd)"
        cd ..
        echo -e "${gl_lv}已返回上级目录: ${gl_huang}$(pwd) ${gl_bai}"
        exit_animation
    else
        echo -e "${gl_huang}已经在根目录: ${gl_hong}/ ${gl_bai}"
        exit_animation
    fi
}

enter_directory() {
    local current_path="$(pwd)"
    local return_target="${1:-文件管理器}"
    clear
    local dirs=()
    echo -e "${gl_huang}>>> 当前目录子目录列表：${gl_bai}(${gl_lv}$current_path${gl_bai})"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    show_directory_list "." 2 false true "dirs"

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e ""
    echo -e "${gl_zi}>>> 进入指定目录${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}请输入 ${gl_huang}序号${gl_bai} ${gl_lv}目录名${gl_bai} ${gl_lan}路径${gl_bai} (${gl_hui}..上级${gl_bai} ${gl_zi}~家${gl_bai} ${gl_hong}/根${gl_bai}) 或 ${gl_huang}0${gl_bai}返回: ")" input

    if [[ -z "$input" ]]; then
        cancel_empty
        return 1
    fi
    
    if [[ "$input" == "0" ]]; then
        cancel_return "$return_target"
        return 1
    fi

    if [[ "$input" =~ ^[0-9]+$ ]]; then
        if [[ -z "${dirs[@]}" ]]; then
            echo -e "${gl_hong}当前目录没有可用的子目录列表，无法通过序号选择${gl_bai}"
            exit_animation
            return 1
        fi

        if [[ "$input" -ge 1 ]] && [[ "$input" -le ${#dirs[@]} ]]; then
            local selected_dir="${dirs[$((input - 1))]}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_bai}已选择: ${gl_lv}$selected_dir${gl_bai}"

            if cd "$selected_dir" 2>/dev/null; then
                echo -e "${gl_bai}成功进入目录: ${gl_lv}$(pwd)${gl_bai}"
            else
                echo -e "${gl_hong}无法进入目录: $selected_dir${gl_bai}"
                echo -e "${gl_hong}可能的原因：${gl_bai}"
                echo -e "${gl_huang}1. 目录不存在${gl_bai}"
                echo -e "${gl_huang}2. 没有访问权限${gl_bai}"
                echo -e "${gl_huang}3. 输入路径有误${gl_bai}"
            fi
        else
            echo -e "${gl_hong}序号 $input 超出范围 (1-${#dirs[@]})${gl_bai}"
        fi
    else
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_lv}尝试进入: $input${gl_bai}"

        local target_path="$input"
        if [[ "$input" == ".." ]]; then
            target_path=".."
        elif [[ "$input" == "~" ]]; then
            target_path=~
        elif [[ "$input" == "/" ]]; then
            target_path="/"
        fi

        if cd "$target_path" 2>/dev/null; then
            local new_path="$(pwd)"
            echo -e "${gl_lv}成功进入目录: $new_path${gl_bai}"

            if [[ ! -d "$new_path" ]]; then
                echo -e "${gl_hong}警告：目标不是一个有效的目录${gl_bai}"
                cd "$current_path" 2>/dev/null
            fi
        else
            echo -e "${gl_hong}无法进入目录: $input${gl_bai}"
            echo -e "${gl_hong}可能的原因：${gl_bai}"
            echo -e "${gl_huang}1. 路径不存在${gl_bai}"
            echo -e "${gl_huang}2. 没有访问权限${gl_bai}"
            echo -e "${gl_huang}3. 不是有效的目录${gl_bai}"
            echo -e "${gl_huang}4. 路径格式错误${gl_bai}"

            if [[ -e "$input" ]] && [[ ! -d "$input" ]]; then
                echo -e "${gl_huang}注意：'$input' 是一个文件，不是目录${gl_bai}"
            fi
        fi
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_huang}即将进入 ${gl_lv}$(basename "$(pwd)")${gl_huang} 目录 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    sleep_fractional 1.6
    return 0
}

show_directory_list() {
    local base_path="${1:-.}"
    local items_per_line="${2:-4}"
    local show_hidden="${3:-false}"
    local exit_on_empty="${4:-true}"
    local return_array_var="$5"

    local dir_array=()
    for dir in "$base_path"/*/; do
        [[ -d "$dir" ]] || continue
        local dir_name
        dir_name=$(basename "$dir")

        if [[ "$show_hidden" == "true" || "$show_hidden" == "1" ]]; then
            dir_array+=("$dir_name")
        elif [[ ! "$dir_name" =~ ^\. ]]; then
            dir_array+=("$dir_name")
        fi
    done

    if [[ ${#dir_array[@]} -eq 0 ]]; then
        echo -e "${gl_huang}当前目录为空${gl_bai}"
        if [[ "$exit_on_empty" == "true" || "$exit_on_empty" == "1" ]]; then
            if [[ -n "$return_array_var" ]]; then
                eval "$return_array_var=()"
            fi
            return 0
        fi
    fi

    mapfile -t dir_array < <(printf '%s\n' "${dir_array[@]}" | sort)

    if [[ -n "$return_array_var" ]]; then
        eval "$return_array_var=($(printf '%q ' "${dir_array[@]}"))"
    fi

    get_display_width() {
        local str="$1"
        local width=0
        local len=${#str}

        for ((i = 0; i < len; i++)); do
            local char="${str:i:1}"
            local code=$(printf '%d' "'$char")

            if [[ $code -lt 128 ]]; then
                ((width++))
            elif [[ $code -ge 0x4E00 && $code -le 0x9FFF ]] ||
                [[ $code -ge 0x3400 && $code -le 0x4DBF ]] ||
                [[ $code -ge 0x20000 && $code -le 0x2A6DF ]] ||
                [[ $code -ge 0x2A700 && $code -le 0x2B73F ]] ||
                [[ $code -ge 0x2B740 && $code -le 0x2B81F ]] ||
                [[ $code -ge 0x2B820 && $code -le 0x2CEAF ]] ||
                [[ $code -ge 0xF900 && $code -le 0xFAFF ]] ||
                [[ $code -ge 0x2F800 && $code -le 0x2FA1F ]]; then
                ((width += 2))
            elif [[ $code -ge 0x3000 && $code -le 0x303F ]] ||
                [[ $code -ge 0xFF00 && $code -le 0xFFEF ]]; then
                ((width += 2))
            else
                ((width += 2))
            fi
        done

        echo $width
    }

    local max_display_width=0
    for d in "${dir_array[@]}"; do
        local width
        width=$(get_display_width "$d")
        (($width > max_display_width)) && max_display_width=$width
    done

    local column_width=$((max_display_width + 4))

    local count=0
    for i in "${!dir_array[@]}"; do
        count=$((i + 1))

        local index_str
        printf -v index_str "%2d." "$count"

        local current_width
        current_width=$(get_display_width "${dir_array[i]}")

        local padding=$((column_width - current_width))

        printf "${gl_bufan}%s${gl_bai} %s" "$index_str" "${dir_array[i]}"

        for ((s = 0; s < padding; s++)); do
            printf " "
        done

        if (((i + 1) % items_per_line == 0)); then
            echo
        fi
    done

    if ((count % items_per_line != 0)); then
        echo
    fi
    return 0
}

list_dir_colorful() {
    local show_hidden="${1:-0}"
    local user_cols="${2:-0}"
    local files=()
    local has_content=0
    local item
    
    declare -A type_color=(
        [dir]="${gl_bufan}"
        [exe]="${gl_lv}"
        [link]="${gl_zi}"
        [archive]="${gl_hong}"
        [image]="${gl_huang}"
        [code]="${gl_lan}"
        [text]="${gl_bai}"
        [else]="${gl_hui}"
    )
    
    if [[ "${show_hidden}" -eq 1 ]]; then
        while IFS= read -r item; do
            [[ -e "${item}" || -L "${item}" ]] && {
                files+=("${item}")
                has_content=1
            }
        done < <(ls -A 2>/dev/null)
    else
        for item in *; do
            [[ -e "${item}" || -L "${item}" ]] && {
                files+=("${item}")
                has_content=1
            }
        done 2>/dev/null
    fi
    
    echo -e "${gl_huang}>>> 当前目录文件列表：${gl_bai}(${gl_lv}$(pwd)${gl_bai})"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    if [[ ${has_content} -eq 0 ]]; then
        echo -e "${gl_huang}当前目录为空${gl_bai}"
        return 0
    fi
    
    local file_info=()
    local max_display_width=0
    
    for item in "${files[@]}"; do
        local color="" suffix=""
        
        if [[ -L "${item}" ]]; then
            color="${type_color[link]}"
            suffix="@"
        elif [[ -d "${item}" ]]; then
            color="${type_color[dir]}"
            suffix="/"
        elif [[ -x "${item}" ]]; then
            color="${type_color[exe]}"
            suffix="*"
        else
            local ext="${item##*.}"
            if [[ "${ext}" != "${item}" ]]; then
                case "${ext,,}" in
                    tar|gz|bz2|xz|zip|7z|rar|zst|tgz|tbz2|txz) 
                        color="${type_color[archive]}" ;;
                    jpg|jpeg|png|gif|bmp|webp|svg|ico|tiff|avif) 
                        color="${type_color[image]}" ;;
                    sh|py|pl|rb|go|cpp|c|h|hpp|js|ts|jsx|tsx|java|php|rs|swift|kt|lua|vim) 
                        color="${type_color[code]}" ;;
                    txt|md|log|conf|cfg|yml|yaml|json|xml|ini|csv|toml) 
                        color="${type_color[text]}" ;;
                    *) 
                        color="${type_color[else]}" ;;
                esac
            else
                if [[ -b "${item}" || -c "${item}" ]]; then
                    color="${type_color[else]}"
                else
                    color="${type_color[text]}"
                fi
            fi
        fi
        
        local display_str="${item}${suffix}"
        local display_width
        
        if command -v wc &>/dev/null; then
            display_width=$(printf "%s" "${display_str}" | wc -L 2>/dev/null || echo "${#display_str}")
        else
            display_width=${#display_str}
        fi
        
        (( display_width > max_display_width )) && max_display_width=${display_width}
        
        file_info+=("${item}" "${color}" "${suffix}" "${display_width}" "${display_str}")
    done
    
    local term_width
    term_width=$(tput cols 2>/dev/null || echo 80)
    
    local col_width=$((max_display_width + 4))
    
    local items_per_line
    if [[ ${user_cols} -gt 0 ]]; then
        items_per_line=${user_cols}
        local needed_width=$((items_per_line * col_width - 4))
        if (( needed_width > term_width )); then
            items_per_line=$(( (term_width + 4) / col_width ))
            (( items_per_line < 1 )) && items_per_line=1
        fi
    else
        items_per_line=$((term_width / col_width))
        (( items_per_line < 1 )) && items_per_line=1
    fi
    
    (( items_per_line > ${#files[@]} )) && items_per_line=${#files[@]}
    
    local total_items=${#files[@]}
    local rows=$(( (total_items + items_per_line - 1) / items_per_line ))
    
    local row col index idx_base file_name file_color file_suffix file_width padding
    
    for ((row = 0; row < rows; row++)); do
        for ((col = 0; col < items_per_line; col++)); do
            index=$((row * items_per_line + col))
            
            if ((index < total_items)); then
                idx_base=$((index * 5))
                file_name="${file_info[idx_base]}"
                file_color="${file_info[idx_base+1]}"
                file_suffix="${file_info[idx_base+2]}"
                file_width="${file_info[idx_base+3]}"
                
                padding=$((col_width - file_width))
                
                printf "%b%s%b" "${file_color}" "${file_name}${file_suffix}" "${gl_bai}"
                
                if ((col < items_per_line - 1 && index < total_items - 1)); then
                    printf "%*s" "${padding}" ""
                fi
            fi
        done
        echo
    done
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    local total=${#files[@]}
    local dir_count=0 file_count=0 link_count=0
    for item in "${files[@]}"; do
        if [[ -L "${item}" ]]; then
            ((link_count++))
        elif [[ -d "${item}" ]]; then
            ((dir_count++))
        else
            ((file_count++))
        fi
    done
    
    echo -e "${gl_bai}总计: ${gl_lv}${total}${gl_bai} 项    ${gl_bufan}目录: ${dir_count}${gl_bai}    文件: ${file_count}${gl_bai}    ${gl_zi}链接: ${link_count}${gl_bai}"
    
    if [[ ${user_cols} -gt 0 ]]; then
        echo -e "${gl_hui}布局: ${gl_lv}${rows}${gl_hui} 行 ${gl_huang}× ${gl_lv}${items_per_line}${gl_hui} 列${gl_bai}"
    else
        echo -e "${gl_hui}布局: ${gl_lv}${rows}${gl_hui} 行 ${gl_huang}× ${gl_lv}${items_per_line}${gl_hui} 列 (${gl_huang}自动计算${gl_hui})${gl_bai}"
    fi
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    return 0
}

cmdbox_admin_menu() {
    while true; do
        clear
        if [[ $(hostname | tr '[:upper:]' '[:lower:]') != "fnos" ]]; then
            echo -e "${gl_zi}>>> FnOS 项目管理${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            log_error "当前并非 FNOS 系统，脚本仅支持在 FNOS 环境下运行"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            return 1
        fi
        
        if [ -z "$(ls -A 2>/dev/null)" ]; then
            echo -e "${gl_huang}>>> 当前目录文件列表：${gl_bai}(${gl_lv}$current_dir${gl_bai})"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_huang}当前目录为空${gl_bai}"
        else
            list_dir_colorful 0 4
        fi
        echo -e ""
        echo -e "${gl_zi}>>> FnOS 项目管理${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}进入指定目录 "
        echo -e "${gl_bufan}2.  ${gl_bai}返回上一级目录"
        echo -e "${gl_bufan}3.  ${gl_bai}FnOS推送cmdbox-main"
        echo -e "${gl_bufan}4.  ${gl_bai}FnOS推送cmdbox-main并构建"
        echo -e "${gl_bufan}5.  ${gl_bai}FnOS推送cmdbox脚本库"
        echo -e "${gl_bufan}6.  ${gl_bai}FnOS推送GitHub mobufan 脚本工具箱"
        echo -e "${gl_bufan}7.  ${gl_bai}FnOS推送Gitee mobufan 脚本工具箱"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_lv}66. ${gl_bai}推送当前项目更新"
        echo -e "${gl_huang}99. ${gl_bai}拉取当前项目更新"
        echo -e "${gl_hong}0.  ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" rename_mode

        case "$rename_mode" in
        1) enter_directory "FnOS 项目推送" ;;
        2) go_parent_directory "FnOS 项目推送" ;;
        3) bash <(curl -sL gitee.com/meimolihan/cmdbox/raw/master/sh/git_push.sh) /vol1/1000/GitHub/cmdbox-main ;;
        4) bash <(curl -sL gitee.com/meimolihan/cmdbox/raw/master/sh/cmdbox_push.sh) /vol1/1000/GitHub/cmdbox-main /vol1/1000/GitHub/cmdbox ;;
        5) bash <(curl -sL gitee.com/meimolihan/cmdbox/raw/master/sh/git_push.sh) /vol1/1000/Gitee/cmdbox ;;
        6) bash <(curl -sL gitee.com/meimolihan/cmdbox/raw/master/sh/git_push.sh) /vol1/1000/GitHub/sh ;;
        7) bash <(curl -sL gitee.com/meimolihan/cmdbox/raw/master/sh/git_push.sh) /vol1/1000/Gitee/sh ;;
        66) bash <(curl -sL gitee.com/meimolihan/cmdbox/raw/master/sh/git_push.sh) ;;
        99) bash <(curl -sL gitee.com/meimolihan/cmdbox/raw/master/sh/git_pull.sh) ;;
        0 | 00 | 000) exit_script ;;
        *) handle_invalid_input ;;
        esac
    done
}

cmdbox_admin_menu
