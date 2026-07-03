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
    echo -ne "\r\033[K${gl_huang}无效的输入,请重新输入! ${gl_zi} 1 ${gl_huang} 秒后返回"
    sleep_fractional 1
    echo -ne "\r\033[K${gl_lv}无效的输入,请重新输入! ${gl_zi}0${gl_lv} 秒后返回"
    sleep_fractional 0.5
    echo -ne "\r\033[K"
    return 2
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
    local return_target="${1:-字符串替换工具}"
    clear
    local dirs=()
    echo -e "${gl_huang}>>> 当前目录子目录列表：${gl_bai}(${gl_lv}$current_path${gl_bai})"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    show_directory_list "." 2 false true "dirs"

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e ""
    echo -e "${gl_zi}>>> 进入指定目录${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}请输入 ${gl_huang}序号${gl_bai} ${gl_lv}目录名${gl_bai} ${gl_lan}路径${gl_bai} (${gl_hui}..上级${gl_bai} ${gl_zi}~家${gl_bai} ${gl_hong}/根${gl_bai}) 或 ${gl_hong}0${gl_bai}返回: ")" input

    if [[ -z "$input" ]]; then
        cancel_empty "$return_target"
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


do_replace() {
    local old_str="$1"
    local new_str="$2"
    local current_dir=$(pwd)
    local items=()
    while IFS= read -r -d $'\0' item; do
        items+=("$item")
    done < <(find "$current_dir" -maxdepth 1 -print0 2>/dev/null | grep -zv "^${current_dir}$")
    
    local item_count=${#items[@]}
    
    if [[ $item_count -eq 0 ]]; then
        echo -e "${gl_huang}当前目录下没有找到任何项目${gl_bai}"
        exit_animation
        return
    fi

    echo -e ""
    echo -e "${gl_zi}>>> 批量替换文件名字符串${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}待替换: ${gl_hong}$old_str${gl_bai} → ${gl_lv}$new_str${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    echo -e "${gl_bai}预览重命名结果:${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local rename_count=0
    local rename_items=()
    for item in "${items[@]}"; do
        local itemname=$(basename "$item")
        local dir=$(dirname "$item")
        local newname="${dir}/${itemname//$old_str/$new_str}"

        if [[ "$itemname" != "$(basename "$newname")" ]]; then
            rename_items+=("$item:$newname")
            if [[ -d "$item" ]]; then
                echo -e "  ${gl_lv}[目录]${gl_bai} ${gl_bufan}${itemname}${gl_bai} -> ${gl_lv}$(basename "$newname")${gl_bai}"
            else
                echo -e "  ${gl_hui}[文件]${gl_bai} ${gl_bufan}${itemname}${gl_bai} -> ${gl_lv}$(basename "$newname")${gl_bai}"
            fi
        fi
    done

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}将重命名 ${gl_lv}${#rename_items[@]}${gl_bai} 个项目${gl_bai}"

    if [[ ${#rename_items[@]} -gt 0 ]]; then
        read -r -e -p "$(echo -e "${gl_bai}确认执行重命名? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
        [ "$confirm" == "0" ] && { cancel_return; return 1; }
        case "$confirm" in
        [Yy])
            for rename_pair in "${rename_items[@]}"; do
                IFS=':' read -r old_name new_name <<<"$rename_pair"
                if mv "$old_name" "$new_name" 2>/dev/null; then
                    ((rename_count++))
                    log_info "已重命名: ${gl_bufan}$(basename "$old_name")${gl_bai} -> ${gl_lv}$(basename "$new_name")${gl_bai}"
                else
                    log_error "重命名失败: ${gl_bufan}$(basename "$old_name")${gl_bai}"
                fi
            done
            ;;
        [Nn])
            log_warn "操作已取消"
            ;;
        *) handle_y_n ;;
        esac
    else
        log_warn "没有找到匹配的字符串 '$old_str'"
    fi

    if [[ $rename_count -gt 0 ]]; then
        log_ok "成功重命名 ${rename_count} 个项目"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}


interactive_mode() {
    while true; do
        clear
        local current_dir=$(pwd)
        local items=()
        while IFS= read -r -d $'\0' item; do
            items+=("$item")
        done < <(find "$current_dir" -maxdepth 1 -print0 2>/dev/null | grep -zv "^${current_dir}$")
        local item_count=${#items[@]}

        echo -e "${gl_zi}===== 批量文件名替换工具 =====${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bai}当前目录: ${gl_lv}${current_dir}${gl_bai}  项目总数: ${gl_lv}${item_count}${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        if [[ $item_count -gt 0 ]]; then
            if [[ $item_count -le 20 ]]; then
                for i in "${!items[@]}"; do
                    local item="${items[$i]}"
                    local itemname=$(basename "$item")
                    if [[ -d "$item" ]]; then
                        echo -e "  ${gl_huang}$((i + 1))${gl_bai}. ${gl_lv}[目录]${gl_bai} ${gl_bufan}${itemname}${gl_bai}"
                    else
                        echo -e "  ${gl_huang}$((i + 1))${gl_bai}. ${gl_hui}[文件]${gl_bai} ${gl_bufan}${itemname}${gl_bai}"
                    fi
                done
            else
                for i in {0..19}; do
                    if [[ $i -lt $item_count ]]; then
                        local item="${items[$i]}"
                        local itemname=$(basename "$item")
                        if [[ -d "$item" ]]; then
                            echo -e "  ${gl_huang}$((i + 1))${gl_bai}. ${gl_lv}[目录]${gl_bai} ${gl_bufan}${itemname}${gl_bai}"
                        else
                            echo -e "  ${gl_huang}$((i + 1))${gl_bai}. ${gl_hui}[文件]${gl_bai} ${gl_bufan}${itemname}${gl_bai}"
                        fi
                    fi
                done
                echo -e "  ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}还有 $((item_count - 20)) 个项目${gl_bai}"
            fi
        else
            echo -e "${gl_huang}当前目录无文件/目录${gl_bai}"
        fi

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}提示：输入 .cd 切换目录 | 输入 .up 返回上级 | ${gl_hong}0${gl_bai} 退出程序${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -e -p "$(echo -e "${gl_bai}请输入要替换的字符串(${gl_hong}0${gl_bai}退出): ")" old_str

        case "$old_str" in
            0) exit_script ;;
            .cd) enter_directory "交互替换" ; continue ;;
            .up) go_parent_directory ; continue ;;
        esac

        if [[ -z "$old_str" ]]; then
            log_warn "要替换的字符串不能为空"
            sleep_fractional 1
            continue
        fi

        read -r -e -p "$(echo -e "${gl_bai}请输入替换为的字符串: ")" new_str
        [[ "$new_str" == "0" ]] && continue

        do_replace "$old_str" "$new_str"
    done
}


if [[ $# -eq 2 ]]; then
    do_replace "$1" "$2"
elif [[ $# -eq 0 ]]; then
    interactive_mode
else
    echo -e "${gl_hong}[错误] 参数格式错误${gl_bai}"
    echo -e "${gl_bai}使用方式："
    echo -e "  ${gl_lv}./batch_replace_name.sh${gl_bai}          # 无参数，进入交互模式（已移除功能菜单）"
    echo -e "  ${gl_lv}./batch_replace_name.sh 旧文本 新文本${gl_bai} # 直接批量替换文件名"
    exit 1
fi
