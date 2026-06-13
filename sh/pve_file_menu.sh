#!/bin/bash

SCRIPT_WORKDIR=""

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -w|--workdir)
                if [[ -n "${2:-}" ]]; then
                    SCRIPT_WORKDIR="$2"
                    shift 2
                else
                    echo "错误: -w/--workdir 需要参数值" >&2
                    exit 1
                fi
                ;;
            -h|--help)
                cat << 'HELPEOF'
用法: linux_file_menu.sh [选项] [工作路径]

描述: Linux 文件管理器 - 完整功能版，支持39项操作

选项:
  -w, --workdir <路径>    指定工作路径
  -h, --help              显示此帮助信息

示例:
  ./linux_file_menu.sh /home/user/documents
  ./linux_file_menu.sh --workdir /tmp
  ./linux_file_menu.sh
HELPEOF
                exit 0
                ;;
            -*)
                echo "未知选项: $1" >&2
                exit 1
                ;;
            *)
                if [[ -z "$SCRIPT_WORKDIR" && -d "$1" ]]; then
                    SCRIPT_WORKDIR="$1"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$SCRIPT_WORKDIR" ]]; then
        SCRIPT_WORKDIR="$(pwd)"
    fi

    if [[ ! -d "$SCRIPT_WORKDIR" ]]; then
        echo "错误: 工作路径不存在: $SCRIPT_WORKDIR" >&2
        exit 1
    fi
}

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
    echo -ne "\r${gl_huang}无效的输入,请重新输入! ${gl_zi} 1 ${gl_huang} 秒后返回"
    sleep 1
    echo -e "\r${gl_lv}无效的输入,请重新输入! ${gl_zi}0${gl_lv} 秒后返回"
    sleep 0.5
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
    echo -ne "\r${gl_lv}即将退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo ""
}

cancel_return() {
    local menu_name="${1:-上一级选单}"
    echo -e "${gl_lv}即将返回到 ${gl_huang}${menu_name}${gl_lv} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    sleep 0.6
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

exit_script() {
    echo ""
    echo -ne "${gl_hong}感谢使用，再见！ ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    clear
    exit 0
}

install() {
    [[ $# -eq 0 ]] && { log_error "未提供软件包参数!"; return 1; }

    local pkg mgr install_success=false
    for pkg in "$@"; do
        if command -v "$pkg" &>/dev/null; then
            continue
        fi
        echo -e "${gl_huang}开始安装：${gl_bai}${pkg}"
        for mgr in apt dnf yum apk pacman; do
            if ! command -v "$mgr" &>/dev/null; then
                continue
            fi
            case $mgr in
                apt)
                    apt update -y && apt install -y "$pkg" && install_success=true
                    ;;
                dnf)
                    dnf install -y "$pkg" && install_success=true
                    ;;
                yum)
                    yum install -y "$pkg" && install_success=true
                    ;;
                apk)
                    apk add "$pkg" && install_success=true
                    ;;
                pacman)
                    pacman -S --noconfirm "$pkg" && install_success=true
                    ;;
            esac
            [[ "$install_success" == true ]] && break
        done
        if [[ "$install_success" == true ]]; then
            echo -e "${gl_lv}✓ ${pkg} 安装成功${gl_bai}"
        else
            echo -e "${gl_hong}✗ ${pkg} 安装失败${gl_bai}"
        fi
    done
}

check_directory_empty() {
    local dir="${1:-.}"
    local title="${2:-检查目录}"
    local exit_on_empty="${3:-true}"

    if [ ! -d "$dir" ]; then
        echo ""
        echo -e "${gl_zi}>>> ${title}${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_hong}错误：目录不存在 ${gl_huang}${dir}${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_lv}即将退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
        sleep_fractional 1
        return 2
    fi

    if [ -z "$(ls -A "$dir" 2>/dev/null)" ]; then
        if [ "$exit_on_empty" != "true" ] && [ "$exit_on_empty" != "1" ]; then
            echo -e "${gl_huang}当前目录为空：${gl_bai}(${gl_lv}$(pwd)${gl_bai})"
            return 0
        fi
        echo ""
        echo -e "${gl_zi}>>> ${title}${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}当前目录为空：${gl_bai}(${gl_lv}$(pwd)${gl_bai})"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_lv}即将退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
        sleep_fractional 1
        return 1
    fi
    return 0
}
show_directory_list() {
    local base_path="${1:-.}"
    local items_per_line="${2:-4}"
    local show_hidden="${3:-false}"
    local exit_on_empty="${4:-true}"
    local return_array_var="${5:-}"

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
            if [[ -n "${return_array_var:-}" ]]; then
                eval "${return_array_var}=()"
            fi
            return 0
        fi
    fi

    mapfile -t dir_array < <(printf '%s\n' "${dir_array[@]}" | sort)

    if [[ -n "${return_array_var:-}" ]]; then
        eval "${return_array_var}=($(printf '%q ' "${dir_array[@]}"))"
    fi

    _sdl_get_width() {
        local s="${1:-}"
        local w=0 len=${#s} i code
        for ((i = 0; i < len; i++)); do
            code=$(printf '%d' "'${s:i:1}")
            if [[ $code -lt 128 ]]; then
                ((w++))
            elif [[ $code -ge 0x4E00 && $code -le 0x9FFF ]] ||
                [[ $code -ge 0x3400 && $code -le 0x4DBF ]] ||
                [[ $code -ge 0xF900 && $code -le 0xFAFF ]] ||
                [[ $code -ge 0x3000 && $code -le 0x303F ]] ||
                [[ $code -ge 0xFF00 && $code -le 0xFFEF ]]; then
                ((w += 2))
            else
                ((w += 2))
            fi
        done
        echo $w
    }

    local max_display_width=0 d width
    for d in "${dir_array[@]}"; do
        width=$(_sdl_get_width "$d")
        (($width > max_display_width)) && max_display_width=$width
    done

    local column_width=$((max_display_width + 4))
    local count=0 i index_str current_width padding
    for i in "${!dir_array[@]}"; do
        count=$((i + 1))
        printf -v index_str "%2d." "$count"
        current_width=$(_sdl_get_width "${dir_array[i]}")
        padding=$((column_width - current_width))
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

declare -a LIST_FILES_ARRAY=()
LIST_FILES_COUNT=0

list_files() {
    local target_dir="${1:-.}"
    local show_hidden="${2:-0}"
    local custom_cols="${3:-2}"
    local dir="${CURRENT_DIR:-.}"        # 使用环境变量
    
    LIST_FILES_ARRAY=()
    LIST_FILES_COUNT=0
    
    if [[ ! -d "$target_dir" ]]; then
        log_error "目录不存在: $target_dir"
        exit_animation    # 即将退出动画
        return 1
    fi
    
    local original_dir="$(pwd)"
    
    if ! cd "$target_dir" 2>/dev/null; then
        log_error "无法进入目录: $target_dir"
        exit_animation    # 即将退出动画
        return 1
    fi
    
    local file_items=()
    local dir_items=()
    
    if [[ "$show_hidden" == "0" ]]; then
        for item in *; do
            [[ "$item" == "*" ]] && continue
            
            if [[ -f "$item" ]]; then
                file_items+=("$item")
            elif [[ -d "$item" ]]; then
                dir_items+=("$item")
            fi
        done
    else
        for item in *; do
            [[ "$item" == "*" ]] && continue
            
            if [[ -f "$item" ]]; then
                file_items+=("$item")
            elif [[ -d "$item" ]]; then
                dir_items+=("$item")
            fi
        done
        
        for item in .*; do
            [[ "$item" == "." ]] && continue
            [[ "$item" == ".." ]] && continue
            [[ "$item" == ".*" ]] && continue
            
            if [[ -f "$item" ]]; then
                file_items+=("$item")
            elif [[ -d "$item" ]]; then
                dir_items+=("$item")
            fi
        done
    fi
    
    cd "$original_dir" || return 1
    
    LIST_FILES_ARRAY=("${dir_items[@]}" "${file_items[@]}")
    LIST_FILES_COUNT=${#LIST_FILES_ARRAY[@]}
    
    calculate_display_width() {
        local str="$1"
        local width=0
        local i
        local char
        local utf8_char
        
        for ((i=0; i<${#str}; i++)); do
            char="${str:$i:1}"
            utf8_char=$(printf "%s" "$char" | od -An -tx1 | tr -d ' ')
            
            if [[ ${#utf8_char} -eq 2 && "0x$utf8_char" -le "0x7F" ]]; then
                ((width++))
            else
                ((width += 2))
            fi
        done
        echo "$width"
    }
    
    format_fixed_width() {
        local str="$1"
        local fixed_width="${2:-18}"
        
        local result=""
        local char_width=0
        local total_width=0
        
        total_width=$(calculate_display_width "$str")
        
        if [[ $total_width -le $fixed_width ]]; then
            result="$str"
            char_width=$total_width
        else
            local ext=""
            local name_part="$str"
            local has_extension=false
            
            for ((i=${#str}-1; i>=0; i--)); do
                if [[ "${str:$i:1}" == "." && $i -gt 0 && $i -lt $((${#str}-1)) ]]; then
                    ext="${str:$i}"
                    name_part="${str:0:$i}"
                    has_extension=true
                    break
                fi
            done
            
            local ext_width=0
            if $has_extension; then
                ext_width=$(calculate_display_width "$ext")
            fi
            
            local reserved_for_ellipsis=2
            local name_available_width=$((fixed_width - ext_width - reserved_for_ellipsis))
            if [[ $name_available_width -lt 1 ]]; then
                name_available_width=1
            fi
            
            local truncated_name=""
            local current_width=0
            local i=0
            
            while [[ $i -lt ${#name_part} && $current_width -lt $name_available_width ]]; do
                local char="${name_part:$i:1}"
                local char_w=1
                
                local utf8_char=$(printf "%s" "$char" | od -An -tx1 | tr -d ' ')
                if [[ ${#utf8_char} -gt 2 || ("0x$utf8_char" -gt "0x7F" && ${#utf8_char} -eq 2) ]]; then
                    char_w=2
                fi
                
                if [[ $((current_width + char_w)) -le $name_available_width ]]; then
                    truncated_name="${truncated_name}${char}"
                    current_width=$((current_width + char_w))
                    ((i++))
                else
                    break
                fi
            done
            
            truncated_name="${truncated_name}.."
            current_width=$((current_width + reserved_for_ellipsis))
            
            if $has_extension; then
                result="${truncated_name}${ext}"
                char_width=$((current_width + ext_width))
            else
                result="$truncated_name"
                char_width=$current_width
            fi
        fi
        
        while [[ $char_width -lt $fixed_width ]]; do
            result="${result} "
            ((char_width++))
        done
        
        echo "$result"
    }
    
    local items_per_line="$custom_cols"
    ((items_per_line < 1)) && items_per_line=2
    ((items_per_line > 4)) && items_per_line=4
    
    local name_width
    local total_available_width=80
    local column_padding=3  # 列间距
    
    case $items_per_line in
        1) 
            name_width=70 
            ;;
        2) 
            name_width=$(( (total_available_width - column_padding) / 2 ))
            ;;
        3) 
            name_width=$(( (total_available_width - 2 * column_padding) / 3 ))
            ;;
        4) 
            name_width=$(( (total_available_width - 3 * column_padding) / 4 ))
            ;;
        *) 
            name_width=30 
            ;;
    esac
    
    ((name_width < 8)) && name_width=8
    ((name_width > 70)) && name_width=70
    
    echo ""
    echo -e "${gl_huang}>>> 当前目录文件列表：${gl_bai}(${gl_lv}$(pwd)${gl_bai})"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    if [ -z "$(ls -A)" ]; then
        echo -e "${gl_huang}当前目录为空${gl_bai}"
    fi

    local count=0
    for ((i=0; i<LIST_FILES_COUNT; i++)); do
        ((count++))
        local item="${LIST_FILES_ARRAY[$i]}"
        local item_path="$target_dir/$item"
        
        local color="${gl_lv}"  # 默认文件绿色
        if [[ -d "$item_path" ]]; then
            color="${gl_zi}"    # 目录紫色
        elif [[ -x "$item_path" ]]; then
            color="${gl_huang}"  # 可执行文件黄色
        elif [[ "$item" == .* ]]; then
            color="${gl_hui}"    # 隐藏文件灰色
        elif [[ "$item" =~ \.(zip|tar|gz|bz2|7z|rar)$ ]]; then
            color="${gl_hong}"  # 压缩文件红色
        elif [[ "$item" =~ \.(sh|bash|zsh)$ ]]; then
            color="${gl_lan}"   # 脚本文件蓝色
        elif [[ "$item" =~ \.(txt|md|conf|ini|cfg)$ ]]; then
            color="${gl_qing}"  # 配置文件青色
        fi
        
        local display_name=$(format_fixed_width "$item" $name_width)
        
        printf "${gl_bufan}%3d.${gl_bai} ${color}%s" "$count" "$display_name"
        
        if ((count % items_per_line != 0 && count < LIST_FILES_COUNT)); then
            case $items_per_line in
                2) printf "   " ;;
                3) printf "  " ;;
                4) printf " " ;;
                *) printf "  " ;;
            esac
        fi
        
        if ((count % items_per_line == 0 || count == LIST_FILES_COUNT)); then
            echo ""
        fi
    done
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}目录:${gl_zi}■${gl_bai} 文件:${gl_lv}■${gl_bai} 隐藏:${gl_hui}■${gl_bai} 压缩:${gl_hong}■${gl_bai} ${gl_bai}脚本:${gl_lan}■${gl_bai} 配置:${gl_qing}■${gl_bai} 执行:${gl_huang}■${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    return 0
}

display_storage_info() {
    local target_path="${1:-.}"
    local show_all="${2:-false}"

    echo -e ""
    echo -e "${gl_zi}>>> 存储信息汇总${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local disk_info
    disk_info=$(df -h "$target_path" 2>/dev/null | tail -1)
    local total=$(echo "$disk_info" | awk '{print $2}')
    local used=$(echo "$disk_info" | awk '{print $3}')
    local avail=$(echo "$disk_info" | awk '{print $4}')
    local use_pct=$(echo "$disk_info" | awk '{print $5}')
    local mount_point=$(echo "$disk_info" | awk '{print $6}')
    local fs_type=$(df -T "$target_path" 2>/dev/null | tail -1 | awk '{print $2}')

    echo -e "${gl_bai}磁盘信息 (${mount_point}):"
    echo -e "  ${gl_bai}文件系统: ${gl_huang}${fs_type:-未知}${gl_bai}"
    echo -e "  ${gl_bai}总容量:   ${gl_lv}${total}${gl_bai}"
    echo -e "  ${gl_bai}已使用:   ${gl_huang}${used}${gl_bai} (${use_pct})"
    echo -e "  ${gl_bai}可用空间: ${gl_lv}${avail}${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local dir_info
    dir_info=$(du -sh "$target_path" 2>/dev/null)
    local dir_size=$(echo "$dir_info" | awk '{print $1}')
    local dir_path=$(echo "$dir_info" | awk '{print $2}')

    echo -e "${gl_bai}当前目录: ${gl_huang}${dir_path}${gl_bai}"
    echo -e "  ${gl_bai}目录总大小: ${gl_lv}${dir_size}${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if [[ "$show_all" == "true" ]]; then
        echo -e "${gl_bai}子目录大小:"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        du -h --max-depth=1 "$target_path" 2>/dev/null | sort -hr | head -10 | while read -r size path; do
            echo -e "  ${gl_huang}$(printf '%-10s' "$size")${gl_bai}$(basename "$path")"
        done
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    fi

    echo -e "${gl_bai}文件类型统计:"
    local ext_count
    ext_count=$(find "$target_path" -maxdepth 1 -type f 2>/dev/null | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -5)
    if [[ -n "$ext_count" ]]; then
        echo "$ext_count" | while read -r count ext; do
            echo -e "  ${gl_lv}$(printf '%4s' "$count")${gl_bai} 个 .${ext} 文件"
        done
    else
        echo -e "  ${gl_hui}无文件${gl_bai}"
    fi
}

root_use() {
    if [[ $EUID -ne 0 ]]; then
        if command -v sudo >/dev/null 2>&1; then
            echo -e "${gl_huang}提示: 某些操作需要 root 权限${gl_bai}"
            echo -e "${gl_huang}如需权限，请使用 sudo 运行此脚本${gl_bai}"
        elif command -v doas >/dev/null 2>&1; then
            echo -e "${gl_huang}提示: 某些操作需要 root 权限${gl_bai}"
        fi
    fi
}

enter_directory() {
    local current_path="$(pwd)"
    local return_target="${1:-文件管理器}"  # 接收参数，默认值为"文件管理器"
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
        if [[ ${#dirs[@]} -eq 0 ]]; then
            echo -e "${gl_hong}当前目录没有可用的子目录列表，无法通过序号选择${gl_bai}"
            exit_animation    # 即将退出动画
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

create_directory() {
    local return_target="${1:-文件管理器}"  # 接收参数，默认值为"文件管理器"
    read -r -e -p "$(echo -e "${gl_bai}请输入要创建的目录名(${gl_huang}0${gl_bai}返回): ")" dirname
    [ -z "$dirname" ] && { cancel_empty "上一级选单"; return 1; }                        # break 或 continue 或 return ，视上下文而定
    [ "$dirname" == "0" ] && { cancel_return "$return_target"; return 1; }  # break 或 continue 或 return ，视上下文而定
    mkdir -p "$dirname" && sleep_fractional 0.6 && echo -e "${gl_lv}目录已创建${gl_bai}" || echo "${gl_hong}创建失败${gl_bai}"
    return 0
}

modify_directory_permissions() {
    echo -e ""
    echo -e "${gl_zi}>>> 修改目录权限${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    local dir_list=()

    if show_directory_list "." 4 false true "dir_list"; then
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入目录序号或路径(${gl_huang}0${gl_bai}返回): ")" input

        [ -z "$input" ] && { cancel_empty "上一级选单"; return 1; }                      # break 或 continue 或 return ，视上下文而定
        [ "$input" == "0" ] && { cancel_return "文件管理器"; return 1; }     # break 或 continue 或 return ，视上下文而定
        local target_dir=""
        
        if [[ "$input" =~ ^[0-9]+$ ]] && [[ "$input" -ge 1 ]] && [[ "$input" -le ${#dir_list[@]} ]]; then
            target_dir="${dir_list[$((input-1))]}"
        else
            target_dir="$input"
        fi
        
        local old_perm old_owner
        old_perm=$(stat -c '%a' "$target_dir" 2>/dev/null || stat -f '%Lp' "$target_dir" 2>/dev/null)
        old_owner=$(stat -c '%U:%G' "$target_dir" 2>/dev/null || stat -f '%Su:%Sg' "$target_dir" 2>/dev/null)
        
        echo -e ""
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bai}[${gl_huang}修改前${gl_bai}]"
        echo -e "  ${gl_bai}目录: ${gl_bufan}$target_dir${gl_bai}"
        echo -e "  ${gl_bai}权限: ${gl_huang}$old_perm ($(stat -c '%A' "$target_dir" 2>/dev/null || stat -f '%Sp' "$target_dir" 2>/dev/null))"
        echo -e "  ${gl_bai}所有者: ${gl_lv}$old_owner${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        read -e -p "$(echo -e "${gl_bai}请输入新权限 (如 ${gl_huang}755${gl_bai}) (${gl_huang}0${gl_bai}返回)): ")" perm

        [ -z "$perm" ] && { cancel_empty "上一级选单"; return 1; }                       # break 或 continue 或 return ，视上下文而定
        [ "$perm" == "0" ] && { cancel_return "文件管理器"; return 1; }  # break 或 continue 或 return ，视上下文而定
        
        if [[ ! "$perm" =~ ^[0-7]{3,4}$ ]]; then
            echo -e "${gl_hong}错误：权限格式不正确，请输入3-4位数字 (如 755, 644)${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            exit_animation    # 即将退出动画
            return 1
        fi
        
        if chmod "$perm" "$target_dir"; then
            echo -e ""
            echo -e "${gl_lv}✓ 权限修改成功${gl_bai}"
            
            local new_perm new_owner
            new_perm=$(stat -c '%a' "$target_dir" 2>/dev/null || stat -f '%Lp' "$target_dir" 2>/dev/null)
            new_owner=$(stat -c '%U:%G' "$target_dir" 2>/dev/null || stat -f '%Su:%Sg' "$target_dir" 2>/dev/null)
            
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_bai}[${gl_huang}修改后${gl_bai}]"
            echo -e "  ${gl_bai}目录: ${gl_bufan}$target_dir${gl_bai}"
            echo -e "  ${gl_bai}权限: ${gl_huang}$new_perm ($(stat -c '%A' "$target_dir" 2>/dev/null || stat -f '%Sp' "$target_dir" 2>/dev/null))"
            echo -e "  ${gl_bai}所有者: ${gl_lv}$new_owner${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
        else
            echo -e "${gl_hong}✗ 修改失败 (可能需要root权限): $target_dir${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            exit_animation    # 即将退出动画
        fi
    fi
    return 0
} 

compress_file_or_directory() {
    read -r -e -p "$(echo -e "${gl_bai}请输入要压缩的文件/目录名(${gl_huang}0${gl_bai}返回): ")" name

    [ -z "$name" ] && { cancel_empty "上一级选单"; return 1; }                   # break 或 continue 或 return ，视上下文而定
    [ "$name" = "0" ] && { cancel_return "文件管理器"; return 1; }   # break 或 continue 或 return ，视上下文而定
    
    if [ ! -e "$name" ]; then
        echo -e "${gl_bai}文件/目录 ${gl_lv}'$name' ${gl_bai}不存在"
        exit_animation    # 即将退出动画
        return 1
    fi
    
    install tar
    tar -czvf "$name.tar.gz" "$name" && echo -e "${gl_lv}已压缩为 ${gl_huang}$name.tar.gz${gl_bai}" || echo -e "${gl_hong}压缩失败${gl_bai}"
}

rename_directory() {
    echo -e ""
    echo -e "${gl_zi}>>> 重命名目录${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    local dir_list=()
    if show_directory_list "." 4 false true "dir_list"; then
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -e -p "$(echo -e "${gl_bai}请输入目录序号或目录名(${gl_huang}0${gl_bai}返回): ")" input

        [ -z "$input" ] && { cancel_empty "上一级选单"; return 1; }                      # break 或 continue 或 return ，视上下文而定
        [ "$input" == "0" ] && { cancel_return "文件管理器"; return 1; }     # break 或 continue 或 return ，视上下文而定
        
        local current_name=""
        if [[ "$input" =~ ^[0-9]+$ ]] && [[ "$input" -ge 1 ]] && [[ "$input" -le ${#dir_list[@]} ]]; then
            current_name="${dir_list[$((input-1))]}"
        else
            current_name="$input"
        fi
        
        [[ ! -d "$current_name" ]] && { log_error "目录不存在: $current_name"; return 1; }
        
        read -e -p "$(echo -e "${gl_bai}请输入新目录名(${gl_huang}0${gl_bai}返回): ")" new_name
        [ -z "$new_name" ] && { cancel_empty "上一级选单"; return 1; }                           # break 或 continue 或 return ，视上下文而定
        [ "$new_name" == "0" ] && { cancel_return "文件管理器"; return 1; }          # break 或 continue 或 return ，视上下文而定
        [[ -e "$new_name" ]] && { log_error "目标已存在: $new_name"; return 1; }     # break 或 continue 或 return ，视上下文而定
        
        if mv "$current_name" "$new_name"; then
            echo -e "${gl_bai}目录已重命名: ${gl_huang}$current_name ${gl_bai}-> ${gl_lv}$new_name${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
        else
            echo -e "${gl_hong}重命名失败: ${gl_huang}$current_name${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
        fi
    fi
    return 0
}

delete_directories() {
    echo -e ""
    echo -e "${gl_zi}>>> 删除目录${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    local dir_list=()
    if show_directory_list "." 4 false true "dir_list"; then
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}提示: 可输入序号、路径，或多个（空格分隔）${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -e -p "$(echo -e "${gl_bai}请输入要删除的目录(${gl_huang}0${gl_bai}返回): ")" input

        [ -z "$input" ] && { cancel_empty "上一级选单"; return 1; }                      # break 或 continue 或 return ，视上下文而定
        [ "$input" == "0" ] && { cancel_return "文件管理器"; return 1; }     # break 或 continue 或 return ，视上下文而定
        
        local -a targets=()
        for item in $input; do
            if [[ "$item" =~ ^[0-9]+$ ]] && [[ "$item" -ge 1 ]] && [[ "$item" -le ${#dir_list[@]} ]]; then
                targets+=("${dir_list[$((item-1))]}")
            else
                targets+=("$item")
            fi
        done
        
        [[ ${#targets[@]} -eq 0 ]] && { log_warn "未指定有效目录"; return 1; }  # break 或 continue 或 return ，视上下文而定
        
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}即将删除以下目录:${gl_bai}"
        for d in "${targets[@]}"; do echo "  - $d"; done
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        read -r -e -p "$(echo -e "${gl_bai}确认删除? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
        [ "$confirm" = "0" ] && { cancel_return "上一级选单"; return 1; }      # break 或 continue 或 return ，视上下文而定
        case "$confirm" in
            [Yy])
                for dir in "${targets[@]}"; do
                    if [[ -d "$dir" ]]; then
                        rm -rf "$dir" && log_ok "已删除: $dir" || log_error "删除失败: $dir"
                        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                        break_end
                    else
                        log_warn "不存在: $dir"
                        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                        break_end
                    fi
                done
                ;;
            *)
                log_warn "已取消删除"
                ;;
        esac
    fi
    return 0
}

go_parent_directory() {
    if [[ "$(pwd)" != "/" ]]; then
        local current_path="$(pwd)"
        cd ..
        echo -e "${gl_lv}已返回上级目录: ${gl_huang}$(pwd) ${gl_bai}"
        exit_animation    # 即将退出动画
    else
        echo -e "${gl_huang}已经在根目录: ${gl_hong}/ ${gl_bai}"
        exit_animation    # 即将退出动画
    fi
}

search_dir_here() {
    local keyword
    local non_interactive=false

    [[ $# -gt 0 && "$1" == "search_dir_here" ]] && shift
    [[ $# -gt 0 ]] && {
        keyword="$*"
        non_interactive=true
    }

    while true; do
        if [[ "$non_interactive" == false ]]; then 

            check_directory_empty "." "${gl_huang}目录${gl_zi}模糊搜索" "true" || return

            clear
            echo -e ""
            echo -e "${gl_zi}>>> ${gl_huang}目录${gl_zi}模糊搜索${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "当前目录: ${gl_huang}$(pwd)${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            ls --color=auto -x
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bai}请输入搜索关键词 (${gl_huang}0${gl_bai}返回): ")" keyword

            [[ "$keyword" == "0" ]] && { cancel_return "上一级选单"; break; }    # break 或 continue 或 return ，视上下文而定

            [[ -z "$keyword" ]] && {
                log_error "关键词不能为空！"
                continue
            }
        fi

        local here
        here="$(pwd)"
        local found=0
        local search_results=()

        while IFS= read -r -d '' dir; do
            local base_dir="${dir##*/}"
            [[ "${base_dir,,}" == *"${keyword,,}"* ]] && search_results+=("$dir")
        done < <(find "$here" -type d -print0 2>/dev/null)

        local unique_results=()
        while IFS= read -r -d '' dir; do
            unique_results+=("$dir")
        done < <(printf "%s\0" "${search_results[@]}" | sort -uz)

        if [[ ${#unique_results[@]} -gt 0 ]]; then
            [[ "$non_interactive" == true ]] &&
                echo "找到 ${#unique_results[@]} 个匹配的目录：" ||
                log_ok "找到 ${#unique_results[@]} 个匹配的目录："
            echo
            for dir in "${unique_results[@]}"; do
                local abs_path
                abs_path="$(readlink -f "$dir" 2>/dev/null || echo "$dir")"
                if [[ "$non_interactive" == true ]]; then
                    echo "$abs_path"
                else
                    echo -e "${gl_lv}${abs_path}${gl_bai}"
                    local dir_info=$(ls -ldh "$dir" 2>/dev/null)
                    local size=$(echo "$dir_info" | awk '{print $5}')
                    local time_info=$(ls -ld --time-style=long-iso "$dir" 2>/dev/null | awk '{print $6, $7}')
                    local permissions=$(echo "$dir_info" | awk '{print $1}')
                    echo -e "  ${gl_hui}权限: $permissions | 大小: $size | 修改: $time_info${gl_bai}"
                    echo
                fi
                ((found++))
            done
        else
            [[ "$non_interactive" == true ]] &&
                echo "未找到包含 \"${keyword}\" 的目录。" ||
                {
                    log_warn "未找到包含 \"${keyword}\" 的目录。"
                    echo
                    log_info "类似目录："
                    find "$here" -type d -maxdepth 2 | head -10 | while read -r d; do echo -e "  ${gl_hui}$(basename "$d")${gl_bai}"; done
                }
        fi

        [[ "$non_interactive" == false ]] && echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        [[ "$non_interactive" == true ]] && break
        echo -e "${gl_lv}操作完成${gl_bai}"
        read -n 1 -s -r -p "$(echo -e "${gl_bai}按任意键继续搜索 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}")"
        echo
    done
}

find_large_directories() {
    echo -e ""
    echo -e "${gl_zi}>>> 查找当前目录中的大目录${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    du -h --max-depth=1 . 2>/dev/null | sort -hr | head -6
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_dir_colorful() {
    local show_hidden="${1:-0}"
    local user_cols="${2:-0}"
    local files=()
    local has_content=0
    local item
    
    declare -A type_color=(
        [dir]="${gl_bufan}"      # 目录
        [exe]="${gl_lv}"         # 可执行文件
        [link]="${gl_zi}"        # 软链接
        [archive]="${gl_hong}"   # 压缩包
        [image]="${gl_huang}"    # 图片
        [code]="${gl_lan}"       # 代码文件
        [text]="${gl_bai}"       # 普通文本
        [else]="${gl_hui}"       # 其他
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
    
    return 0
}

list_directory_sizes() {
    local target_path="${1:-$(pwd)}"  # 支持传参，默认当前目录
    
    if [ ! -d "$target_path" ]; then
        echo -e "${gl_hong}错误: 路径不存在: ${target_path}${gl_bai}"
        exit_animation    # 即将退出动画
        return 1
    fi
    
    local original_path="$(pwd)"
    cd "$target_path" || {
        echo -e "${gl_hong}错误: 无法进入目录: ${target_path}${gl_bai}"
        exit_animation    # 即将退出动画
        return 1
    }

    display_storage_info "$target_path" true

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

create_new_file() {
    read -e -p "$(echo -e "${gl_bai}请输入要创建的文件名(${gl_huang}0${gl_bai}返回): ")" filename
    [ -z "$filename" ] && { cancel_empty "上一级选单"; return 1; }
    [ "$filename" == "0" ] && { cancel_return "文件管理器"; return 1; }
    touch "$filename" && echo -e "${gl_lv}文件已创建${gl_bai}" || echo -e "${gl_hong}创建失败${gl_bai}"
}

manage_backup_files_simple() {
    local target_func="${1:-linux_file}" # 若未传参则默认使用 linux_file
    
    while true; do
        clear
        echo -e ""
        echo -e "${gl_zi}>>> 常用目录管理 ${gl_bai}[${gl_huang}调用函数: ${gl_lv}${target_func}${gl_bai}]"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        if [[ -d "/vol1/1000/compose" ]]; then
            echo -e "${gl_bufan}1.${gl_bai} ${gl_lv}/vol1/1000/compose${gl_bai}                       ${gl_bufan}[Compose 目录] ✔${gl_bai}"
        else
            echo -e "${gl_bufan}1.${gl_bai} ${gl_hui}/vol1/1000/compose${gl_bai}                       ${gl_huang}[Compose 目录] ✖${gl_bai}"
        fi

        if [[ -d "/vol2/1000/mydisk/Video" ]]; then
            echo -e "${gl_bufan}2.${gl_bai} ${gl_lv}/vol2/1000/mydisk/Video${gl_bai}                  ${gl_bufan}[飞牛视频目录] ✔${gl_bai}"
        else
            echo -e "${gl_bufan}2.${gl_bai} ${gl_hui}/vol2/1000/mydisk/Video${gl_bai}                  ${gl_huang}[飞牛视频目录] ✖${gl_bai}"
        fi

        if [[ -d "/vol2/1000/media" ]]; then
            echo -e "${gl_bufan}3.${gl_bai} ${gl_lv}/vol2/1000/media${gl_bai}                         ${gl_bufan}[飞牛影视目录] ✔${gl_bai}"
        else
            echo -e "${gl_bufan}3.${gl_bai} ${gl_hui}/vol2/1000/media${gl_bai}                         ${gl_huang}[飞牛影视目录] ✖${gl_bai}"
        fi

        if [[ -d "/vol2/1000" ]]; then
            echo -e "${gl_bufan}4.${gl_bai} ${gl_lv}/vol2/1000${gl_bai}                               ${gl_bufan}[飞牛常用目录] ✔${gl_bai}"
        else
            echo -e "${gl_bufan}4.${gl_bai} ${gl_hui}/vol2/1000${gl_bai}                               ${gl_huang}[飞牛常用目录] ✖${gl_bai}"
        fi

        if [[ -d "/vol1/1000/compose/random-pic-api/photos" ]]; then
            echo -e "${gl_bufan}5.${gl_bai} ${gl_lv}/vol1/1000/compose/random-pic-api/photos${gl_bai} ${gl_bufan}[随机壁纸目录] ✔${gl_bai}"
        else
            echo -e "${gl_bufan}5.${gl_bai} ${gl_hui}/vol1/1000/compose/random-pic-api/photos${gl_bai} ${gl_huang}[随机壁纸目录] ✖${gl_bai}"
        fi

        if [[ -d "/var/lib/vz/template/iso" ]]; then
            echo -e "${gl_bufan}6.${gl_bai} ${gl_lv}/var/lib/vz/template/iso${gl_bai}                 ${gl_bufan}[PVE 固件目录] ✔${gl_bai}"
        else
            echo -e "${gl_bufan}6.${gl_bai} ${gl_hui}/var/lib/vz/template/iso${gl_bai}                 ${gl_huang}[PVE 固件目录] ✖${gl_bai}"
        fi

        if [[ -d "/var/lib/vz/dump" ]]; then
            echo -e "${gl_bufan}7.${gl_bai} ${gl_lv}/var/lib/vz/dump${gl_bai}                         ${gl_bufan}[PVE 备份目录] ✔${gl_bai}"
        else
            echo -e "${gl_bufan}7.${gl_bai} ${gl_hui}/var/lib/vz/dump${gl_bai}                         ${gl_huang}[PVE 备份目录] ✖${gl_bai}"
        fi

        if [[ -d "/mnt/compose" ]]; then
            echo -e "${gl_bufan}8.${gl_bai} ${gl_lv}/mnt/compose${gl_bai}                             ${gl_bufan}[Docker  目录] ✔${gl_bai}"
        else
            echo -e "${gl_bufan}8.${gl_bai} ${gl_hui}/mnt/compose${gl_bai}                             ${gl_huang}[Docker  目录] ✖${gl_bai}"
        fi

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}9.${gl_bai} 手动输入路径${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请选择路径序号 (${gl_huang}0${gl_bai}返回): ")" pve_file

        case "$pve_file" in
        1)
            if [[ -d "/vol1/1000/compose" ]]; then
                cd "/vol1/1000/compose" && $target_func "." "Compose项目管理" "常用目录管理"
            else
                check_directory_empty "/vol1/1000/compose" "Compose项目管理" || continue
            fi
            ;;
        2)
            if [[ -d "/vol2/1000/mydisk/Video" ]]; then
                cd "/vol2/1000/mydisk/Video" && $target_func "/vol2/1000/mydisk/Video" "视频文件管理" "常用目录管理"
            else
                check_directory_empty "/vol2/1000/mydisk/Video" "视频文件管理" || continue
            fi
            ;;
        3)
            if [[ -d "/vol2/1000/media" ]]; then
                cd "/vol2/1000/media" && $target_func "." "飞牛 TV 目录管理" "常用目录管理"
            else
                check_directory_empty "/vol2/1000/media" "飞牛 TV 目录管理" || continue
            fi
            ;;
        4)
            if [[ -d "/vol2/1000" ]]; then
                cd "/vol2/1000" && $target_func "." "飞牛文件管理" "常用目录管理"
            else
                check_directory_empty "/vol2/1000" "飞牛文件管理" || continue
            fi
            ;;
        5)
            if [[ -d "/vol1/1000/compose/random-pic-api/photos" ]]; then
                cd "/vol1/1000/compose/random-pic-api/photos" && $target_func "." "随机壁纸待处理目录管理" "常用目录管理"
            else
                check_directory_empty "/vol1/1000/compose/random-pic-api/photos" "随机壁纸待处理目录管理" || continue
            fi
            ;;
        6)
            if [[ -d "/var/lib/vz/template/iso" ]]; then
                cd "/var/lib/vz/template/iso" && $target_func "." "PVE 固件目录管理" "常用目录管理"
            else
                check_directory_empty "/var/lib/vz/template/iso" "PVE 固件目录管理" || continue
            fi
            ;;
        7)
            if [[ -d "/var/lib/vz/dump" ]]; then
                cd "/var/lib/vz/dump" && $target_func "." "PVE 备份目录管理" "常用目录管理"
            else
                check_directory_empty "/var/lib/vz/dump" "PVE 备份目录管理" || continue
            fi
            ;;
        8)
            if [[ -d "/mnt/compose" ]]; then
                cd "/mnt/compose" && $target_func "/mnt/compose" "Compose项目管理" "常用目录管理"
            else
                check_directory_empty "/mnt/compose" "Compose项目管理" || continue
            fi
            ;;
        9)
            read -r -e -p "$(echo -e "${gl_bai}请输入要进入的目录路径: ")" custom_path
            if [[ -d "$custom_path" ]]; then
                cd "$custom_path" && $target_func "." "自定义目录管理" "常用目录管理"
            else
                check_directory_empty "$custom_path" "飞牛文件管理" || continue
            fi
            ;;
        0) cancel_return; return ;;
        *) handle_invalid_input ;;
        esac
    done
}

edit_file_with_nano() {

    check_directory_empty "." "编辑文件" "true" || return

    clear
    echo -e "${gl_huang}>>> 当前目录文件列表：${gl_bai}(${gl_lv}$(pwd)${gl_bai})"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    if ! list_files "." 0 4; then
        exit_animation    # 即将退出动画
        return 1
    fi
    
    if [[ ${#LIST_FILES_ARRAY[@]} -eq 0 ]] || [[ "$LIST_FILES_COUNT" -eq 0 ]]; then
        exit_animation    # 即将退出动画
        return 1
    fi
    
    echo ""
    echo -e "${gl_zi}>>> 编辑文件${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}请输入序号(${gl_huang}1${gl_bai}-${gl_lv}${LIST_FILES_COUNT}${gl_bai})或文件名(${gl_huang}0${gl_bai}返回): ")" user_input

    [ -z "$user_input" ] && { cancel_empty "上一级选单"; return 1; }                     # break 或 continue 或 return ，视上下文而定
    [ "$user_input" == "0" ] && { cancel_return "文件管理器"; return 1; }    # break 或 continue 或 return ，视上下文而定
    
    local target_file=""
    
    if [[ "$user_input" =~ ^[0-9]+$ ]]; then
        local idx=$((user_input - 1))
        if [[ $idx -ge 0 && $idx -lt ${#LIST_FILES_ARRAY[@]} ]]; then
            target_file="${LIST_FILES_ARRAY[$idx]}"
        else
            log_error "序号超出范围: $user_input (有效范围: 1-${LIST_FILES_COUNT})"
            exit_animation    # 即将退出动画
            return 1
        fi
    else
        target_file="$user_input"
    fi
    
    if [[ ! -f "$target_file" ]]; then
        log_error "文件不存在: $target_file"
        exit_animation    # 即将退出动画
        return 1
    fi
    
    install nano
    nano "$target_file"
}

file_chmod() {
    local return_target="${1:-文件管理器}"  # 接收参数，默认值为"文件管理器"
    while :; do
        check_directory_empty "." "修改文件权限" || return
        clear
        
        if ! list_files "." 0 4; then
            exit_animation    # 即将退出动画
            return
        fi
        
        if [[ ${#LIST_FILES_ARRAY[@]} -eq 0 ]] || [[ "$LIST_FILES_COUNT" -eq 0 ]]; then
            exit_animation    # 即将退出动画
            return
        fi
        
        echo ""
        echo -e "${gl_zi}>>> 修改文件权限${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        read -r -e -p "$(echo -e "${gl_bai}请输入文件序号(${gl_huang}1${gl_bai}-${gl_lv}${LIST_FILES_COUNT}${gl_bai})或文件名(${gl_huang}0${gl_bai}返回): ")" user_input
        
        [ -z "$user_input" ] && { cancel_empty "重新输入"; continue; }                    # break 或 continue 或 return ，视上下文而定
        [ "$user_input" = "0" ] && { cancel_return "$return_target"; break; }            # break 或 continue 或 return ，视上下文而定
        
        local filename=""
        
        if [[ "$user_input" =~ ^[0-9]+$ ]]; then
            local idx=$((user_input - 1))
            if [[ $idx -ge 0 && $idx -lt ${#LIST_FILES_ARRAY[@]} ]]; then
                filename="${LIST_FILES_ARRAY[$idx]}"
            else
                log_error "序号超出范围: $user_input (有效范围: 1-${LIST_FILES_COUNT})"
                sleep_fractional 1
                continue
            fi
        else
            filename="${user_input/#\~/$HOME}"
        fi
        
        if [[ ! -e "$filename" ]]; then
            log_error "文件或目录不存在: $filename"
            exit_animation    # 即将退出动画
            continue
        fi
        
        local curr_oct=$(stat -c "%a" "$filename" 2>/dev/null || stat -f "%A" "$filename" 2>/dev/null)
        local curr_sym=$(stat -c "%A" "$filename" 2>/dev/null || stat -f "%Sp" "$filename" 2>/dev/null)
        
        echo ""
        echo -e "${gl_huang}>>> 当前权限信息${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bai}文件: ${gl_huang}${filename}${gl_bai}"
        echo -e "${gl_bai}权限: ${gl_lv}${curr_sym}${gl_bai}  (${gl_huang}${curr_oct}${gl_bai})"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo ""
        
        local new_perm=""
        while :; do
            read -r -e -p "$(echo -e "${gl_bai}请输入新权限 (如 ${gl_huang}755${gl_bai}、${gl_lv}+x${gl_bai}、${gl_hui}u-w${gl_bai}等，${gl_hong}0${gl_bai}取消): ")" new_perm
            
            [[ "$new_perm" == "0" ]] && { echo -e "${gl_huang}已取消操作 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"; sleep_fractional 0.6; break 2; }
            [[ -z "$new_perm" ]] && { echo -e "${gl_huang}已取消操作 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"; sleep_fractional 0.6; break 2; }
            
            if [[ "$new_perm" =~ ^[0-7]{1,3}$ ]] || [[ "$new_perm" =~ ^[ugoa]*[+-=][rwxXstugo]+$ ]]; then
                break
            else
                log_error "输入格式错误！请重新输入（例如 644、755、+x、g-w 等）"
                sleep_fractional 0.5
            fi
        done
        
        echo ""
        if chmod "$new_perm" "$filename" 2>/dev/null; then
            sync
            local new_oct=$(stat -c "%a" "$filename" 2>/dev/null || stat -f "%A" "$filename" 2>/dev/null)
            local new_sym=$(stat -c "%A" "$filename" 2>/dev/null || stat -f "%Sp" "$filename" 2>/dev/null)
            
            log_ok "权限修改成功！"
            echo ""
            echo -e "${gl_lv}>>> 修改后权限${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_bai}文件: ${gl_huang}${filename}${gl_bai}"
            echo -e "${gl_bai}权限: ${gl_lv}${new_sym}${gl_bai}  (${gl_huang}${new_oct}${gl_bai})"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        else
            log_error "修改失败，请检查文件系统权限或输入格式"
        fi
        
        break_end
    done
}

rename_file_or_dir() {
    clear
    echo -e "${gl_huang}>>> 当前目录文件列表：${gl_bai}(${gl_lv}$(pwd)${gl_bai})"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    if ! list_files "." 0 4; then
        exit_animation    # 即将退出动画
        return 1
    fi
    
    if [[ ${#LIST_FILES_ARRAY[@]} -eq 0 ]] || [[ "$LIST_FILES_COUNT" -eq 0 ]]; then
        exit_animation    # 即将退出动画
        return 1
    fi
    
    local current_name=""
    local new_name=""
    local user_input=""
    
    echo ""
    echo -e "${gl_zi}>>> 重命名文件${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}输入序号选择文件，或直接输入文件名 (${gl_huang}0${gl_bai}返回): ")" user_input
    
    [ -z "$user_input" ] && { cancel_empty "上一级选单"; return 1; }                     # break 或 continue 或 return ，视上下文而定
    [ "$user_input" == "0" ] && { cancel_return "文件管理器"; return 1; }    # break 或 continue 或 return ，视上下文而定
    
    if [[ "$user_input" =~ ^[0-9]+$ ]]; then
        local idx=$((user_input - 1))
        if ((idx >= 0 && idx < LIST_FILES_COUNT)); then
            current_name="${LIST_FILES_ARRAY[$idx]}"
            log_ok "已选择 [$user_input]: $current_name"
        else
            log_error "无效的序号: $user_input (有效范围: 1-$LIST_FILES_COUNT)"
            exit_animation    # 即将退出动画
            return 1
        fi
    else
        current_name="$user_input"
        if [[ ! -e "$current_name" ]]; then
            log_error "文件不存在: $current_name"
            exit_animation    # 即将退出动画
            return 1
        fi
        log_ok "已指定文件: $current_name"
    fi
    
    if [[ ! -e "$current_name" ]]; then
        log_error "无法访问文件: $current_name"
        exit_animation    # 即将退出动画
        return 1
    fi
    
    echo ""
    echo -e "${gl_bai}当前文件名: ${gl_huang}${gl_bai}$current_name${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}请输入新文件名: ")" new_name
    [ "$new_name" = "0" ] && { cancel_return "上一级选单"; return 1; }      # break 或 continue 或 return ，视上下文而定
    
    if [[ -z "$new_name" ]]; then
        log_error "新文件名不能为空"
        exit_animation    # 即将退出动画
        return 1
    fi
    
    if [[ -e "$new_name" ]]; then
        log_error "目标文件已存在: $new_name"
        exit_animation    # 即将退出动画
        return 1
    fi
    
    if [[ "$current_name" == "$new_name" ]]; then
        log_warn "新旧文件名相同，无需重命名"
        exit_animation    # 即将退出动画
        return 1
    fi
    
    echo ""
    echo -e "${gl_huang}即将重命名:${gl_bai}"
    echo -e "  ${gl_huang}$current_name${gl_bai} ${gl_abi}->${gl_bai} ${gl_lv}$new_name${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}确认执行重命名吗? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
    [ "$confirm" = "0" ] && { cancel_return "上一级选单"; return 1; }      # break 或 continue 或 return ，视上下文而定

    case "$confirm" in
        [Yy])
            if mv "$current_name" "$new_name"; then
                echo ""
                log_ok "文件重命名成功"
                echo -e "${gl_huang}  $current_name ${gl_bai}-> ${gl_lv}$new_name${gl_bai}"
            else
                log_error "重命名失败"
                exit_animation    # 即将退出动画
            fi
            ;;
        [Nn]|"")
            log_warn "已取消操作"
            exit_animation    # 即将退出动画
            ;;
        *) handle_y_n ;;        # 无效的输入,请输入(y或N)。
    esac
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

delete_files() {
    check_directory_empty "." "删除文件" "true" || return
    clear
    if ! list_files "." 0 4; then
        exit_animation    # 即将退出动画
        return 1
    fi
    
    if [[ ${#LIST_FILES_ARRAY[@]} -eq 0 ]] || [[ "$LIST_FILES_COUNT" -eq 0 ]]; then
        exit_animation    # 即将退出动画
        return 1
    fi
    
    echo ""
    echo -e "${gl_zi}>>> 删除文件${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    read -r -e -p "$(echo -e "${gl_bai}请输入文件序号(${gl_huang}1${gl_bai}-${gl_lv}${LIST_FILES_COUNT}${gl_bai})或文件名(${gl_huang}0${gl_bai}返回): ")" user_input
    
    [ -z "$user_input" ] && { cancel_empty "上一级选单"; return 1; }                     # break 或 continue 或 return ，视上下文而定
    [ "$user_input" == "0" ] && { cancel_return "文件管理器"; return 1; }    # break 或 continue 或 return ，视上下文而定
    
    local inputs=($user_input)
    local files_to_delete=()
    local invalid_inputs=()
    
    for input in "${inputs[@]}"; do
        local target_file=""
        
        if [[ "$input" =~ ^[0-9]+$ ]]; then
            local idx=$((input - 1))
            if [[ $idx -ge 0 && $idx -lt ${#LIST_FILES_ARRAY[@]} ]]; then
                target_file="${LIST_FILES_ARRAY[$idx]}"
            else
                invalid_inputs+=("$input(超出范围)")
                continue
            fi
        else
            target_file="${input/#\~/$HOME}"
        fi
        
        if [[ -e "$target_file" ]]; then
            if [[ -d "$target_file" ]]; then
                log_warn "跳过目录(请使用目录删除功能): $target_file"
                exit_animation    # 即将退出动画
            else
                files_to_delete+=("$target_file")
            fi
        else
            invalid_inputs+=("$input(不存在)")
        fi
    done
    
    if [[ ${#invalid_inputs[@]} -gt 0 ]]; then
        log_error "无效输入: ${invalid_inputs[*]}"
        exit_animation    # 即将退出动画
    fi
    
    if [[ ${#files_to_delete[@]} -eq 0 ]]; then
        log_warn "没有可删除的文件"
        exit_animation    # 即将退出动画
        return 1
    fi
    
    echo ""
    echo -e "${gl_hong}>>> 待删除文件列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    local count=0
    for file in "${files_to_delete[@]}"; do
        ((count++))
        printf "${gl_bufan}%2d.${gl_bai} ${gl_hong}%s${gl_bai}\n" "$count" "$file"
    done
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    read -r -e -p "$(echo -e "${gl_bai}确认删除以上 ${gl_hong}${#files_to_delete[@]}${gl_bai} 个文件? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
    [ "$confirm" = "0" ] && { cancel_return "上一级选单"; return 1; }      # break 或 continue 或 return ，视上下文而定
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "已取消删除操作"
        exit_animation    # 即将退出动画
        return 1
    fi
    
    echo ""
    local success_count=0
    local fail_count=0
    
    for file in "${files_to_delete[@]}"; do
        if rm -f "$file"; then
            log_info "已删除: ${gl_hong}$file${gl_bai}"
            ((success_count++))
        else
            log_error "删除失败: $file"
            ((fail_count++))
        fi
    done
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_lv}成功: $success_count${gl_bai}  ${gl_hong}失败: $fail_count${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

cat_view_file_content() {
    local return_target="${1:-文件管理器}"  # 接收参数，默认值为"文件管理器"

    check_directory_empty "." "预览文件内容" "true" || return

    clear
    
    if ! list_files "." 0 4; then
        exit_animation    # 即将退出动画
        return 1
    fi
    
    if [[ ${#LIST_FILES_ARRAY[@]} -eq 0 ]] || [[ "$LIST_FILES_COUNT" -eq 0 ]]; then
        exit_animation    # 即将退出动画
        return 1
    fi
    
    echo ""
    echo -e "${gl_zi}>>> 预览文件内容${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    read -r -e -p "$(echo -e "${gl_bai}请输入文件序号(${gl_huang}1${gl_bai}-${gl_lv}${LIST_FILES_COUNT}${gl_bai})或文件名(${gl_huang}0${gl_bai}返回): ")" user_input
    
    [ -z "$user_input" ] && { cancel_empty "上一级选单"; return 1; }                         # break 或 continue 或 return ，视上下文而定
    [ "$user_input" == "0" ] && { cancel_return "$return_target"; return 1; }   # break 或 continue 或 return ，视上下文而定
    
    local target_file=""
    
    if [[ "$user_input" =~ ^[0-9]+$ ]]; then
        local idx=$((user_input - 1))
        if [[ $idx -ge 0 && $idx -lt ${#LIST_FILES_ARRAY[@]} ]]; then
            target_file="${LIST_FILES_ARRAY[$idx]}"
        else
            log_error "序号超出范围: $user_input (有效范围: 1-${LIST_FILES_COUNT})"
            exit_animation    # 即将退出动画
            return 1
        fi
    else
        target_file="${user_input/#\~/$HOME}"
    fi
    
    if [[ ! -e "$target_file" ]]; then
        log_error "文件不存在: $target_file"
        exit_animation    # 即将退出动画
        return 1
    fi
    
    if [[ -d "$target_file" ]]; then
        log_error "无法预览目录内容: $target_file"
        exit_animation    # 即将退出动画
        return 1
    fi
    
    local file_size=$(stat -c%s "$target_file" 2>/dev/null || stat -f%z "$target_file" 2>/dev/null)
    
    clear
    echo -e "${gl_zi}>>> 文件内容: ${gl_huang}$target_file${gl_bai} (${gl_lv}$file_size${gl_bai} bytes)"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    cat "$target_file"
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

search_file_here() {
    local keyword
    local non_interactive=false

    if [[ $# -gt 0 ]]; then
        if [[ "${1:-}" == "search_file_here" ]]; then
            shift
        fi
        if [[ $# -gt 0 ]]; then
            keyword="$*"
            non_interactive=true
        fi
    fi

    while true; do
        if [[ "$non_interactive" == false ]]; then

            check_directory_empty "." "${gl_huang}文件${gl_zi}模糊搜索" "true" || return

            clear
            echo -e "${gl_huang}>>> 当前 ${gl_lv}$(pwd) ${gl_huang}目录内容:"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            if [ -z "$(ls -A)" ]; then
                echo -e "${gl_huang}当前目录为空${gl_bai}"
            else
                ls --color=auto -xa
            fi

            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e ""
            echo -e "${gl_zi}>>> ${gl_huang}文件${gl_zi}模糊搜索${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bai}请输入搜索关键词 (${gl_huang}0${gl_bai}返回): ")" keyword

            [[ "$keyword" == "0" ]] && { cancel_return "上一级选单"; break; }    # break 或 continue 或 return ，视上下文而定
            [[ -z "$keyword" ]] && { cancel_empty "上一级选单"; continue; }      # break 或 continue 或 return ，视上下文而定
        fi

        local here
        here="$(pwd)"
        local found=0

        if [[ "$non_interactive" == false ]]; then
            echo -e ""
            echo -e "${gl_huang}>>> 正在执行模糊搜索 \"${keyword}\" ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        fi

        local search_results=()

        while IFS= read -r -d '' file; do
            [[ -n "$file" ]] && search_results+=("$file")
        done < <(find "$here" -iname "*${keyword}*" -type f -print0 2>/dev/null)

        while IFS= read -r -d '' file; do
            if [[ -n "$file" ]] && [[ ! " ${search_results[@]} " =~ " ${file} " ]]; then
                search_results+=("$file")
            fi
        done < <(find "$here" -type f -iregex ".*${keyword}.*" -print0 2>/dev/null)

        if command -v ag &>/dev/null; then
            while IFS= read -r -d '' file; do
                file="${file#./}"
                if [[ -n "$file" ]] && [[ ! " ${search_results[@]} " =~ " ${file} " ]]; then
                    search_results+=("$file")
                fi
            done < <(cd "$here" && ag -l -g ".*${keyword}.*" . 2>/dev/null | tr '\n' '\0')
        fi

        local unique_results=()
        if [[ ${#search_results[@]} -gt 0 ]]; then
            while IFS= read -r -d '' file; do
                [[ -n "$file" ]] && unique_results+=("$file")
            done < <(printf "%s\0" "${search_results[@]}" | sort -uz)
        fi

        if [[ ${#unique_results[@]} -gt 0 ]]; then
            if [[ "$non_interactive" == true ]]; then
                echo "找到 ${#unique_results[@]} 个匹配的文件："
            else
                log_ok "找到 ${#unique_results[@]} 个匹配的文件："
            fi
            echo
            for file in "${unique_results[@]}"; do
                if [[ ! -f "$file" ]]; then
                    if [[ -f "$here/$file" ]]; then
                        file="$here/$file"
                    else
                        continue
                    fi
                fi

                local abs_path
                abs_path="$(readlink -f "$file" 2>/dev/null || echo "$file")"
                if [[ "$non_interactive" == true ]]; then
                    echo "$abs_path"
                else
                    echo -e "${gl_lv}${abs_path}${gl_bai}"

                    if [[ -r "$file" ]]; then
                        local file_info
                        file_info=$(ls -lh "$file" 2>/dev/null)
                        if [[ $? -eq 0 ]]; then
                            local size
                            size=$(echo "$file_info" | awk '{print $5}')
                            local time_info
                            time_info=$(ls -l --time-style=long-iso "$file" 2>/dev/null | awk 'NR==1 {print $6, $7}')
                            local permissions
                            permissions=$(ls -l "$file" 2>/dev/null | awk 'NR==1 {print $1}')

                            echo -e "  ${gl_hui}权限: $permissions | 大小: $size | 修改: $time_info${gl_bai}"

                            if file "$file" 2>/dev/null | grep -q "text"; then
                                local preview
                                preview=$(head -1 "$file" 2>/dev/null | cut -c-50)
                                if [[ -n "$preview" ]]; then
                                    echo -e "  ${gl_zi}预览: ${preview} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                                fi
                            fi
                        else
                            echo -e "  ${gl_hui}[无法获取文件信息]${gl_bai}"
                        fi
                    else
                        echo -e "  ${gl_hui}[无法读取文件详细信息]${gl_bai}"
                    fi
                    echo
                fi
                ((found++))
            done
        else
            if [[ "$non_interactive" == true ]]; then
                echo "未找到包含 \"${keyword}\" 的文件。"
            else
                log_warn "未找到包含 \"${keyword}\" 的文件。"
                log_info "搜索建议："
                echo -e "  ${gl_hui}• 尝试不同的关键词"
                echo -e "  ${gl_hui}• 使用更通用的词汇"
                echo -e "  ${gl_hui}• 检查文件是否在其他位置${gl_bai}"

                log_info "当前目录下的文件："
                find "$here" -maxdepth 1 -type f -name "*" | head -5 | while read -r similar; do
                    echo -e "  ${gl_hui}$(basename "$similar")${gl_bai}"
                done
            fi
        fi

        if [[ "$non_interactive" == false ]]; then
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        fi

        if [[ "$non_interactive" == true ]]; then
            break
        fi

        break_end
    done
}

find_large_files() {
    check_directory_empty "." "查找当前目录中的大文件" "true" || return
    echo -e ""
    echo -e "${gl_zi}>>> 查找当前目录中的大文件${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    find . -path ./proc -prune -o -path ./sys -prune -o -type f -exec du -b {} + 2>/dev/null | sort -nr | head -5 | numfmt --to=iec --field=1
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

create_file() {
    local file_name=${1:-}

    echo -e ""
    echo -e "${gl_zi}>>> 创建文件${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if [[ -z $file_name ]]; then
        read -r -e -p "$(echo -e "${gl_bai}请输入文件名(${gl_huang}0${gl_bai}返回): ")" file_name || return
        [[ -z "$file_name" ]] && { cancel_empty "上一级选单"; return 1; }
        [[ "$file_name" == "0" ]] && { cancel_return "上一级选单"; return 1; }
    fi

    if [[ -e $file_name ]]; then
        echo -e "${gl_hong}文件已存在：$file_name${gl_bai}"
        local overwrite
        read -r -e -p "$(echo -e "${gl_bai}是否覆盖？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}，${gl_huang}0${gl_bai}返回): ")" overwrite || return
        [[ "$overwrite" == "0" ]] && { cancel_return "上一级选单"; return 1; }
        [[ "$overwrite" != [yY] ]] && { echo -e "${gl_huang}已取消操作 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"; sleep_fractional 0.6; return; }
    fi

    echo -e "${gl_huang}将创建文件：$file_name${gl_bai}"
    echo -e "${gl_bufan}按回车键开始用 nano 编辑文件(${gl_huang}Ctrl+X${gl_bai}退出nano)${gl_bai}"
    read -r -n 1 -s  # 等待任意键继续

    local tmp line_count=0
    tmp=$(mktemp)

    if nano "$tmp"; then
        if [[ -s $tmp ]]; then
            line_count=$(wc -l < "$tmp" 2>/dev/null || echo 0)
            mv "$tmp" "$file_name"
            echo -e "${gl_huang}文件创建成功，共写入 $line_count 行${gl_bai}"
            [[ -s $file_name ]] && cat -n "$file_name"
        else
            touch "$file_name"
            echo -e "${gl_bufan}创建空文件完成${gl_bai}"
        fi
    else
        echo -e "${gl_hong}nano 编辑失败或已取消${gl_bai}"
        rm -f "$tmp"
        return
    fi

    if [[ $file_name =~ \.(sh|py|pl)$ ]]; then
        local add_exec
        echo -e ""
        read -r -e -p "$(echo -e "${gl_bai}检测到脚本文件，是否添加执行权限？ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}，${gl_huang}0${gl_bai}返回): ")" add_exec || return
        [[ "$add_exec" == "0" ]] && { echo -e "${gl_huang}已跳过权限设置${gl_bai}"; }
        [[ "$add_exec" == [yY] ]] && chmod +x "$file_name"
        new_oct=$(stat -c "%a" "$file_name")
        new_sym=$(stat -c "%A" "$file_name")
        echo -e ""
        log_ok "权限已修改！"
        echo -e ""
        echo -e "${gl_bai}修改后 ${gl_huang}${file_name}${gl_bai} 权限: ${gl_lv}${new_sym}${gl_bai}  (${gl_huang}${new_oct}${gl_bai})"
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end  # 假设这是一个自定义的暂停函数
}

extract_archive() {
    if ! command -v tar &> /dev/null; then
        install tar
    fi
    echo -e ""
    echo -e "${gl_zi}>>> 解压文件/目录${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    read -e -p "$(echo -e "${gl_bai}请输入要解压的文件名(${gl_lv}.tar.gz${gl_bai})(${gl_huang}0${gl_bai}返回): ")" filename

    [ -z "$filename" ] && { cancel_empty "上一级选单"; return 1; }
    [ "$filename" == "0" ] && { cancel_return "文件管理器"; return 1; }
    
    if [[ ! -f "$filename" ]]; then
        echo -e "${gl_hong}✗ 错误: 文件不存在: $filename${gl_bai}"
        exit_animation    # 即将退出动画
        return 1
    fi
    
    if [[ ! "$filename" =~ \.(tar\.gz|tgz|tar)$ ]]; then
        echo -e "${gl_huang}⚠ 警告: 文件可能不是标准的 tar.gz/tgz/tar 格式${gl_bai}"
        read -r -e -p "$(echo -e "是否继续解压? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo -e "${gl_huang}已取消操作 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
            exit_animation    # 即将退出动画
            return 1
        fi
    fi
    
    echo -e "${gl_bai}正在解压: ${gl_huang}$filename${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    if tar -xzvf "$filename"; then
        echo -e ""
        echo -e "${gl_lv}✓ 解压成功!${gl_bai}"
        
        echo -e "${gl_bai}解压内容:${gl_bai}"
        tar -tzf "$filename" 2>/dev/null | head -10 | while read -r line; do
            echo -e "  ${gl_lv}•${gl_bai} $line"
        done
        local total_files=$(tar -tzf "$filename" 2>/dev/null | wc -l)
        if [[ $total_files -gt 10 ]]; then
            echo -e "  ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} 共 $total_files 个文件/目录${gl_bai}"
        fi
    else
        echo -e ""
        echo -e "${gl_hong}✗ 解压失败${gl_bai}"
        echo -e "${gl_huang}可能原因:${gl_bai}"
        echo -e "  1. 文件损坏或不完整"
        echo -e "  2. 文件格式不正确（非 gzip 压缩的 tar 文件）"
        echo -e "  3. 权限不足（尝试使用 sudo）"
        echo -e "  4. 磁盘空间不足"
        echo -e "  5. 文件名包含特殊字符"
    fi
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
    return 0
}

interactive_compress() {
    if [[ -z "$TRASH_CMD" ]]; then
        install_trash
    fi

    while true; do
        clear
        echo -e "${gl_huang}>>> 当前${gl_bai}(${gl_lv}文件${gl_hong}/${gl_zi}目录${gl_bai})${gl_huang}列表：${gl_lv}$(pwd)${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        local list=() item i choice target fmt_idx format
        local compress_extensions=("zip" "7z" "tar" "tar.gz" "tgz" "rar" "gz")

        for item in *; do
            [[ "$item" == .* ]] && continue

            [[ ! -e "$item" ]] && continue

            local is_compressed=0
            for ext in "${compress_extensions[@]}"; do
                if [[ "$item" == *".$ext" ]]; then
                    is_compressed=1
                    break
                fi
            done

            ((is_compressed == 0)) && list+=("$item")
        done

        for item in */; do
            if [[ -d "$item" && "$item" != .*/ && "$item" != "./" ]]; then
                item="${item%/}"
                local exists=0
                for existing in "${list[@]}"; do
                    [[ "$existing" == "$item" ]] && exists=1 && break
                done
                ((exists == 0)) && list+=("$item")
            fi
        done

        if ((${#list[@]} > 0)); then
            IFS=$'\n' list=($(sort <<<"${list[*]}"))
            unset IFS
        fi

        if ((${#list[@]} == 0)); then
            echo -e "${gl_huang}当前目录无可压缩的文件/目录${gl_bai}"
            exit_animation    # 即将退出动画
            return
        fi
        
        display_horizontal_list "${list[@]}"

        echo -e ""
        echo -e "${gl_zi}>>> 压缩模式${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入序号选择，或手动输入${gl_bai}(${gl_lv}文件${gl_hong}/${gl_zi}目录${gl_bai}) (${gl_huang}0 ${gl_bai}返回): ")" choice

        if [[ -z "$choice" || "$choice" == "0" ]]; then
            return
        fi

        if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#list[@]})); then
            target="${list[$((choice - 1))]}"
        else
            target="$choice"
        fi

        [[ -e "$target" ]] || {
            echo -e "${gl_hong}错误：'$target' 不存在！${gl_bai}"
            echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            read -r -n1 -s
            continue
        }

        echo -e ""
        echo -e "${gl_huang}请选择压缩格式：${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}1.${gl_bai} zip (通用)      ${gl_huang}2.${gl_bai} 7z (高压缩率)"
        echo -e "${gl_huang}3.${gl_bai} tar.gz (平衡)  ${gl_huang}4.${gl_bai} tar (仅打包)"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        safe_read "请输入你的选择: " fmt_idx "number"

        case "$fmt_idx" in
        1) format="zip" ;;
        2) format="7z" ;;
        3) format="tar.gz" ;;
        4) format="tar" ;;
        *)
            echo -e "${gl_hong}无效序号！${gl_bai}"
            echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            read -r -n1 -s
            continue
            ;;
        esac

        local output_dir
        read -r -e -p "$(echo -e "${gl_bai}输出目录 (${gl_huang}留空为当前目录${gl_bai}): ")" output_dir
        output_dir="${output_dir:-.}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e ""

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        compress_file "$target" "$format" "$output_dir"

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
    done
}

interactive_extract() {
    clear
    echo -e "${gl_zi}>>> 解压模式${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local list=() file i choice archive dest
    local extensions=("zip" "7z" "tar" "tar.gz" "tgz" "rar" "gz")
    
    list=()
    
    for ext in "${extensions[@]}"; do
        while IFS= read -r -d '' file; do
            [[ -n "$file" && -f "$file" ]] && {
                local exists=false
                for item in "${list[@]}"; do
                    [[ "$item" == "$file" ]] && { exists=true; break; }
                done
                [[ "$exists" == false ]] && list+=("$file")
            }
        done < <(find . -maxdepth 1 -type f -name "*.$ext" -print0 2>/dev/null)
    done

    if ((${#list[@]} == 0)); then
        log_warn "当前目录无压缩包文件"

        log_warn "正在检查无扩展名的压缩文件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        local file_count=0
        
        while IFS= read -r -d '' file; do
            [[ -f "$file" ]] && {
                if file "$file" 2>/dev/null | grep -qi "compressed\|archive\|zip\|gzip\|tar"; then
                    echo -e "${gl_huang}发现可能的压缩文件: $file${gl_bai}"
                    local exists=false
                    for item in "${list[@]}"; do
                        [[ "$item" == "$file" ]] && { exists=true; break; }
                    done
                    [[ "$exists" == false ]] && {
                        list+=("$file")
                        ((file_count++))
                    }
                fi
            }
        done < <(find . -maxdepth 1 -type f ! -name "*.*" -print0 2>/dev/null)

        if ((file_count == 0)); then
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_bai}按任意键返回 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
            read -r -n1 -s
            return
        fi
    fi

    if ((${#list[@]} > 0)); then
        IFS=$'\n' list=($(sort <<<"${list[*]}"))
        unset IFS
    fi

    echo -e "当前工作目录 ${gl_huang}$(pwd) ${gl_lv}可用的压缩包：${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local count=0
    local items_per_line=2
    local max_length=0

    for file in "${list[@]}"; do
        local len=${#file}
        ((len > max_length)) && max_length=$len
    done

    local term_width=$(tput cols 2>/dev/null || echo 80)
    if ((term_width > 120)); then
        items_per_line=4
    elif ((term_width > 80)); then
        items_per_line=3
    fi

    max_length=$((max_length + 4))

    for i in "${!list[@]}"; do
        count=$((count + 1))

        local file_ext="${list[i]##*.}"
        case "$file_ext" in
        zip | 7z)
            printf "${gl_huang}%2d.${gl_bai} ${gl_lv}%-${max_length}s${gl_bai}" "$count" "${list[i]}"
            ;;
        tar* | tgz)
            printf "${gl_huang}%2d.${gl_bai} ${gl_zi}%-${max_length}s${gl_bai}" "$count" "${list[i]}"
            ;;
        gz)
            printf "${gl_huang}%2d.${gl_bai} ${gl_lan}%-${max_length}s${gl_bai}" "$count" "${list[i]}"
            ;;
        *)
            printf "${gl_huang}%2d.${gl_bai} ${gl_bai}%-${max_length}s" "$count" "${list[i]}"
            ;;
        esac

        if ((count % items_per_line == 0)); then
            echo ""
        fi
    done

    ((count % items_per_line != 0)) && echo ""

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    read -r -e -p "$(echo -e "${gl_bai}请输入序号选择，或手动输入文件名(${gl_huang}0 ${gl_bai}返回): ")" choice

    [[ -z "$choice" ]] && {
        echo -e "${gl_huang}已取消${gl_bai}"
        return
    }

    if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#list[@]})); then
        archive="${list[$((choice - 1))]}"
    else
        archive="$choice"
    fi

    [[ -f "$archive" ]] || {
        echo -e "${gl_hong}错误：'$archive' 不存在！${gl_bai}"
        return
    }

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}解压到目录 (${gl_huang}留空为当前目录${gl_bai}): ")" dest
    dest="${dest:-.}"

    if [[ ! -d "$dest" ]]; then
        echo -e "${gl_huang}目录 '$dest' 不存在，是否创建？(${gl_lv}y${gl_huang}/${gl_bai}N${gl_huang})${gl_bai}"
        read -r -n1 -s create_dir
        if [[ $create_dir =~ ^[Yy]$ ]]; then
            mkdir -p "$dest" && echo -e "${gl_lv}目录已创建${gl_bai}" || {
                echo -e "${gl_hong}创建目录失败！${gl_bai}"
                return
            }
        else
            dest="."
        fi
    fi

    extract_file "$archive" "$dest" "false"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

batch_extract_all() {
    clear
    echo -e "${gl_zi}>>> 批量解压模式${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}当前工作目录: ${gl_huang}$(pwd)${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local archives=()
    local archive dest_dir overwrite_all=false skip_all=false
    local extensions=("zip" "7z" "tar" "tar.gz" "tar.bz2" "tar.xz" "tgz" "tbz2" "txz" "rar" "gz" "bz2" "xz")

    for ext in "${extensions[@]}"; do
        for file in *."$ext"; do
            [[ -f "$file" ]] && archives+=("$file")
        done
    done

    for file in *; do
        [[ -f "$file" && ! "$file" =~ \. ]] && {
            if file "$file" | grep -qi "compressed\|archive\|zip\|gzip\|bzip2\|xz\|tar\|rar"; then
                archives+=("$file")
            fi
        }
    done

    archives=($(printf "%s\n" "${archives[@]}" | sort -u))
    local total=${#archives[@]}

    if [[ $total -eq 0 ]]; then
        log_warn "当前目录下没有找到压缩文件"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation    # 即将退出动画
        return 1
    fi

    echo -e "${gl_lv}发现 ${gl_huang}$total${gl_lv} 个压缩文件:${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local count=0 max_length=0 items_per_line=2
    local term_width=$(tput cols 2>/dev/null || echo 80)

    for archive in "${archives[@]}"; do
        local len=${#archive}
        ((len > max_length)) && max_length=$len
    done

    if ((term_width > 120)); then
        items_per_line=4
    elif ((term_width > 80)); then
        items_per_line=3
    fi
    max_length=$((max_length + 4))

    for archive in "${archives[@]}"; do
        ((count++))
        local file_ext="${archive##*.}"
        local color="${gl_bai}"

        case "$file_ext" in
            zip|7z) color="${gl_lv}" ;;
            tar*|tgz|tbz2|txz) color="${gl_zi}" ;;
            gz|bz2|xz) color="${gl_lan}" ;;
            rar) color="${gl_hong}" ;;
        esac

        printf "${gl_huang}%2d.${gl_bai} ${color}%-${max_length}s${gl_bai}" "$count" "$archive"

        if ((count % items_per_line == 0)); then
            echo ""
        fi
    done
    ((count % items_per_line != 0)) && echo ""

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    read -r -e -p "$(echo -e "${gl_bai}确认解压以上 ${gl_lv}$total${gl_bai} 个文件? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
    [[ ! "$confirm" =~ ^[Yy]$ ]] && {
        log_info "已取消解压操作"
        exit_animation    # 即将退出动画
        return 1
    }

    echo ""
    echo -e "${gl_bai}解压选项:${gl_bai}"
    echo -e "${gl_huang}1.${gl_bai} 解压到各自同名目录"
    echo -e "${gl_huang}2.${gl_bai} 全部解压到当前目录（推荐）"
    echo -e "${gl_huang}3.${gl_bai} 解压到指定目录"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    read -r -e -p "$(echo -e "${gl_bai}请选择解压方式(${gl_huang}默认${gl_lv}2${gl_bai}): ")" extract_mode
    [ "$extract_mode" = "0" ] && { cancel_return "上一级选单"; return 1; }      # break 或 continue 或 return ，视上下文而定
    extract_mode="${extract_mode:-2}"

    local custom_dest=""
    if [[ "$extract_mode" == "3" ]]; then
        read -r -e -p "$(echo -e "${gl_bai}请输入目标目录路径: ")" custom_dest
        [ "$custom_dest" = "0" ] && { cancel_return "上一级选单"; return 1; }      # break 或 continue 或 return ，视上下文而定
        custom_dest="${custom_dest/#\~/$HOME}"
        [[ -z "$custom_dest" ]] && custom_dest="."
        
        if [[ ! -d "$custom_dest" ]]; then
            read -r -e -p "$(echo -e "${gl_huang}目录不存在，是否创建? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_huang})${gl_bai}: ")" create_dir
            [ "$create_dir" = "0" ] && { cancel_return "上一级选单"; return 1; }      # break 或 continue 或 return ，视上下文而定
            if [[ "$create_dir" =~ ^[Yy]$ ]]; then
                mkdir -p "$custom_dest" || {
                    log_error "创建目录失败: $custom_dest"
                    exit_animation    # 即将退出动画
                    return 1
                }
            else
                log_info "已取消"
                exit_animation    # 即将退出动画
                return 1
            fi
        fi
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local success=0 failed=0 skipped=0
    local i=0

    for archive in "${archives[@]}"; do
        ((i++))
        local archive_name=$(basename "$archive")
        local archive_base="${archive_name%.tar.gz}"  # 移除 .tar.gz 后缀
        archive_base="${archive_base%.tar.bz2}"
        archive_base="${archive_base%.tar.xz}"
        archive_base="${archive_base%.tgz}"
        archive_base="${archive_base%.tbz2}"
        archive_base="${archive_base%.txz}"
        archive_base="${archive_base%.zip}"
        archive_base="${archive_base%.7z}"
        archive_base="${archive_base%.rar}"
        archive_base="${archive_base%.tar}"
        archive_base="${archive_base%.gz}"
        archive_base="${archive_base%.bz2}"
        archive_base="${archive_base%.xz}"

        case "$extract_mode" in
            "1") dest_dir="./${archive_base}" ;;
            "2") dest_dir="." ;;
            "3") dest_dir="$custom_dest" ;;
            *) dest_dir="./${archive_base}" ;;
        esac

        echo -e "${gl_bai}[${gl_huang}$i${gl_bai}/${gl_lv}$total${gl_bai}] 正在解压: ${gl_huang}$archive_name${gl_bai}"

        if [[ "$dest_dir" != "." ]] && [[ -d "$dest_dir" ]]; then
            if [[ "$skip_all" == true ]]; then
                log_info "跳过（已存在）: $archive_name"
                ((skipped++))
                continue
            elif [[ "$overwrite_all" == false ]]; then
                read -r -e -p "$(echo -e "${gl_huang}目录 '$dest_dir' 已存在，如何处理? (${gl_lv}o${gl_huang}覆盖/${gl_lv}s${gl_huang}跳过/${gl_lv}O${gl_huang}全部覆盖/${gl_lv}S${gl_huang}全部跳过): ")" action
                case "$action" in
                    [Oo]) ;;  # 覆盖，继续执行
                    [Ss])
                        log_info "跳过: $archive_name"
                        ((skipped++))
                        continue
                        ;;
                    "O"|"o")
                        overwrite_all=true
                        ;;
                    "S"|"s")
                        skip_all=true
                        ((skipped++))
                        continue
                        ;;
                esac
            fi
            
            if [[ "$overwrite_all" == true ]] || [[ "$action" =~ ^[Oo]$ ]]; then
                rm -rf "$dest_dir" 2>/dev/null || {
                    log_error "无法删除旧目录: $dest_dir"
                    ((failed++))
                    continue
                }
            fi
        fi

        if [[ "$dest_dir" != "." ]]; then
            mkdir -p "$dest_dir" || {
                log_error "创建目录失败: $dest_dir"
                ((failed++))
                continue
            }
        fi

        local result=0

        if [[ "$archive" == *.zip ]]; then
            if [[ "$dest_dir" == "." ]]; then
                unzip -o "$archive" >/dev/null 2>&1
            else
                unzip -o "$archive" -d "$dest_dir" >/dev/null 2>&1
            fi
            result=$?

        elif [[ "$archive" == *.7z ]]; then
            if [[ "$dest_dir" == "." ]]; then
                7z x "$archive" -y >/dev/null 2>&1
            else
                7z x "$archive" -o"$dest_dir" -y >/dev/null 2>&1
            fi
            result=$?

        elif [[ "$archive" == *.tar.gz ]] || [[ "$archive" == *.tgz ]]; then
            if [[ "$dest_dir" == "." ]]; then
                tar -xzf "$archive" >/dev/null 2>&1
            else
                tar -xzf "$archive" -C "$dest_dir" --strip-components=0 >/dev/null 2>&1
            fi
            result=$?

        elif [[ "$archive" == *.tar.bz2 ]] || [[ "$archive" == *.tbz2 ]]; then
            if [[ "$dest_dir" == "." ]]; then
                tar -xjf "$archive" >/dev/null 2>&1
            else
                tar -xjf "$archive" -C "$dest_dir" --strip-components=0 >/dev/null 2>&1
            fi
            result=$?

        elif [[ "$archive" == *.tar.xz ]] || [[ "$archive" == *.txz ]]; then
            if [[ "$dest_dir" == "." ]]; then
                tar -xJf "$archive" >/dev/null 2>&1
            else
                tar -xJf "$archive" -C "$dest_dir" --strip-components=0 >/dev/null 2>&1
            fi
            result=$?

        elif [[ "$archive" == *.tar ]]; then
            if [[ "$dest_dir" == "." ]]; then
                tar -xf "$archive" >/dev/null 2>&1
            else
                tar -xf "$archive" -C "$dest_dir" --strip-components=0 >/dev/null 2>&1
            fi
            result=$?

        elif [[ "$archive" == *.gz ]] && [[ "$archive" != *.tar.gz ]]; then
            local output_name="${archive%.gz}"
            [[ "$dest_dir" != "." ]] && output_name="$dest_dir/$(basename "$output_name")"
            gunzip -c "$archive" > "$output_name" 2>/dev/null
            result=$?

        elif [[ "$archive" == *.bz2 ]] && [[ "$archive" != *.tar.bz2 ]]; then
            local output_name="${archive%.bz2}"
            [[ "$dest_dir" != "." ]] && output_name="$dest_dir/$(basename "$output_name")"
            bunzip2 -c "$archive" > "$output_name" 2>/dev/null
            result=$?

        elif [[ "$archive" == *.xz ]] && [[ "$archive" != *.tar.xz ]]; then
            local output_name="${archive%.xz}"
            [[ "$dest_dir" != "." ]] && output_name="$dest_dir/$(basename "$output_name")"
            unxz -c "$archive" > "$output_name" 2>/dev/null
            result=$?

        elif [[ "$archive" == *.rar ]]; then
            if [[ "$dest_dir" == "." ]]; then
                unrar x -o+ "$archive" >/dev/null 2>&1
            else
                unrar x -o+ "$archive" "$dest_dir/" >/dev/null 2>&1
            fi
            result=$?

        else
            if [[ "$dest_dir" == "." ]]; then
                7z x "$archive" -y >/dev/null 2>&1
            else
                7z x "$archive" -o"$dest_dir" -y >/dev/null 2>&1
            fi
            result=$?
        fi

        if [[ $result -eq 0 ]]; then
            log_info "✓ 成功解压: ${gl_lv}$archive_name${gl_bai} → ${gl_huang}$dest_dir${gl_bai}"
            ((success++))
        else
            log_error "✗ 解压失败: ${gl_hong}$archive_name${gl_bai} (退出码: $result)"
            ((failed++))
        fi
    done

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_zi}批量解压完成!${gl_bai}"
    echo -e "${gl_lv}  成功: $success${gl_bai}  |  ${gl_hong}失败: $failed${gl_bai}  |  ${gl_huang}跳过: $skipped${gl_bai}  |  总计: $total${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    break_end
    return 0
}

compress_tool() {

    local install_only=false compress_file="" extract_file="" compress_format=""
    local output_dir="" auto_yes=false system_type=""

    setup_completion() {
        local current_word="${COMP_WORDS[COMP_CWORD]}"
        local previous_word="${COMP_WORDS[COMP_CWORD - 1]}"

        case "${previous_word}" in
        --compress | --extract)
            COMPREPLY=($(compgen -f -- "${current_word}"))
            ;;
        --format)
            local formats=("zip" "7z" "tar.gz" "tar")
            COMPREPLY=($(compgen -W "${formats[*]}" -- "${current_word}"))
            ;;
        --output)
            COMPREPLY=($(compgen -d -- "${current_word}"))
            ;;
        *)
            local options=("--install-only" "--compress" "--extract" "--format" "--output" "--auto-yes" "-h" "--help")
            COMPREPLY=($(compgen -W "${options[*]}" -- "${current_word}"))
            ;;
        esac
    }

    if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
        complete -F setup_completion compress_tool
    fi

    _detect_system() {
        if [[ -f /etc/os-release ]]; then
            source /etc/os-release
            echo "$ID"
        elif command -v lsb_release &>/dev/null; then
            lsb_release -si | tr '[:upper:]' '[:lower:]'
        else
            echo "unknown"
        fi
    }

    batch_compress_dirs() {
        clear
        echo -e "${gl_zi}>>> 批量压缩子目录${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bai}当前工作目录: ${gl_huang}$(pwd)${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        local dirs=()
        local dir

        for dir in */; do
            [[ -d "$dir" ]] && dirs+=("${dir%/}")
        done

        if ((${#dirs[@]} == 0)); then
            echo -e "${gl_hong}当前目录下没有子文件夹！${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_bai}按任意键返回 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
            read -r -n1 -s
            return
        fi

        echo -e "${gl_lv}发现以下子目录：${gl_bai}"
        local count=0
        for dir in "${dirs[@]}"; do
            ((count++))
            echo -e "${gl_huang}$count.${gl_bai} $dir"
        done
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        echo -e "${gl_bai}请选择压缩格式：${gl_bai}"
        echo -e "${gl_huang}1.${gl_bai} zip        ${gl_huang}2.${gl_bai} tar.gz"
        echo -e "${gl_huang}3.${gl_bai} 7z         ${gl_huang}4.${gl_bai} tar"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        local format_choice compress_format compress_ext
        read -r -e -p "$(echo -e "${gl_bai}请输入格式序号(${gl_huang}默认1${gl_bai}): ")" format_choice
        format_choice="${format_choice:-1}"

        case "$format_choice" in
            1) compress_format="zip"; compress_ext="zip" ;;
            2) compress_format="tar.gz"; compress_ext="tar.gz" ;;
            3) compress_format="7z"; compress_ext="7z" ;;
            4) compress_format="tar"; compress_ext="tar" ;;
            *) compress_format="zip"; compress_ext="zip" ;;
        esac

        echo -e "${gl_lv}已选择格式: $compress_format${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        read -r -e -p "$(echo -e "${gl_huang}确认压缩以上 ${gl_lv}$count${gl_huang} 个目录为 ${gl_lv}.$compress_ext${gl_huang} 格式? (${gl_lv}y${gl_huang}/${gl_bai}N${gl_huang})${gl_bai}: ")" confirm
        [[ ! "$confirm" =~ ^[Yy]$ ]] && {
            echo -e "${gl_huang}已取消${gl_bai}"
            return
        }

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        local success=0 failed=0
        for dir in "${dirs[@]}"; do
            local output_name="${dir}.${compress_ext}"
            echo -e "${gl_bai}正在压缩: ${gl_huang}$dir${gl_bai} → ${gl_lv}$output_name${gl_bai}"
            
            case "$compress_format" in
                "zip")
                    zip -r "$output_name" "$dir" >/dev/null 2>&1 && ((success++)) || ((failed++))
                    ;;
                "tar")
                    tar -cvf "$output_name" "$dir" >/dev/null 2>&1 && ((success++)) || ((failed++))
                    ;;
                "tar.gz")
                    tar -czvf "$output_name" "$dir" >/dev/null 2>&1 && ((success++)) || ((failed++))
                    ;;
                "7z")
                    7z a "$output_name" "$dir" >/dev/null 2>&1 && ((success++)) || ((failed++))
                    ;;
            esac
        done

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_lv}压缩完成！成功: $success, 失败: $failed${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
    }

    interactive_menu() {
        while true; do
            check_directory_empty "." "Linux压缩/解压工具" "true" || return

            clear
            echo -e ""
            echo -e "${gl_zi}安装依赖中 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            install zip 7zip gzip
            clear
            list_dir_colorful 0 4 # 当前目录列表
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e ""
            echo -e "${gl_zi}>>> Linux压缩/解压工具${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_bufan}1.  ${gl_bai}压缩文件/目录         ${gl_bufan}2.  ${gl_bai}解压文件"
            echo -e "${gl_bufan}3.  ${gl_bai}进入指定目录          ${gl_bufan}4.  ${gl_bai}返回上一级目录"
            echo -e "${gl_bufan}5.  ${gl_bai}文件管理工具          ${gl_bufan}6.  ${gl_bai}文件下载工具"
            echo -e "${gl_bufan}7.  ${gl_bai}安全删除工具          ${gl_bufan}8.  ${gl_bai}文件回收站"
            echo -e "${gl_bufan}9.  ${gl_bai}批量压缩子目录        ${gl_bufan}10. ${gl_bai}批量解压模式"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单        ${gl_hong}00. ${gl_bai}退出脚本"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            read -r -e -p "请输入你的选择: " choice
            case $choice in

            1)  interactive_compress ;;                             # 压缩文件/目录
            2)  interactive_extract ;;                              # 解压文件
            1)  enter_directory "Linux压缩/解压工具" ;;              # 进入指定目录
            4)  cd .. ;;                                            # 返回上一级目录
            5)  linux_file "." "文件管理工具" "Linux压缩/解压工具";;  # 文件管理工具
            6)  download_file ;;                                    # 文件下载工具
            7)  interactive_delete ;;                               # 安全删除工具
            8)  manage_trash_menu ;;                                # 文件回收站
            9)  batch_compress_dirs ;;                              # 批量压缩子目录（新增）
            10) batch_extract_all ;;                                # 批量解压模式
            0) cancel_return; return 0 ;;                           # 返回到上一级菜单
            00 | 000 | 0000) exit_script ;;                         # 感谢使用，再见！
            *) handle_invalid_input ;;                              # 无效的输入,请重新输入!
            esac
        done
    }

    while [[ $# -gt 0 ]]; do
        case ${1:-} in
        --install-only)
            install_only=true
            shift
            ;;
        --compress)
            compress_file="${2:-}"
            shift 2
            ;;
        --extract)
            extract_file="${2:-}"
            shift 2
            ;;
        --format)
            compress_format="${2:-}"
            shift 2
            ;;
        --output)
            output_dir="${2:-}"
            shift 2
            ;;
        --auto-yes)
            auto_yes=true
            shift
            ;;
        *)
            echo -e "${gl_hong}未知参数: $1${gl_bai}"
            return 1
            ;;
        esac
    done

    interactive_menu
}

batch_rename_files() {
    while true; do
        local current_dir=$(pwd)
        local files=()
        
        while IFS= read -r -d $'\0' file; do
            if [[ -f "$file" ]]; then
                files+=("$file")
            fi
        done < <(find "$current_dir" -maxdepth 1 -type f -print0 2>/dev/null)
        
        local file_count=${#files[@]}
        
        clear
        echo -e ""
        echo -e "${gl_zi}>>> 批量重命名文件${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        if [[ $file_count -eq 0 ]]; then
            echo -e "${gl_huang}当前目录下没有找到任何文件${gl_bai}"
        else
            echo -e "${gl_bai}当前目录: ${gl_lv}${current_dir}${gl_bai}  ${gl_bai}文件数量: ${gl_lv}${file_count}${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            
            if [[ $file_count -le 20 ]]; then
                echo -e "${gl_bai}文件列表:${gl_bai}"
                for i in "${!files[@]}"; do
                    local file="${files[$i]}"
                    local filename=$(basename "$file")
                    echo -e "  ${gl_huang}$((i + 1))${gl_bai}. ${gl_bufan}${filename}${gl_bai}"
                done
            else
                echo -e "${gl_bai}显示前 20 个文件:${gl_bai}"
                for i in {0..19}; do
                    if [[ $i -lt $file_count ]]; then
                        local file="${files[$i]}"
                        local filename=$(basename "$file")
                        echo -e "  ${gl_huang}$((i + 1))${gl_bai}. ${gl_bufan}${filename}${gl_bai}"
                    fi
                done
                echo -e "  ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}还有 $((file_count - 20)) 个文件${gl_bai}"
            fi
        fi
        
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}添加前缀              ${gl_bufan}2.  ${gl_bai}添加后缀"
        echo -e "${gl_bufan}3.  ${gl_bai}替换字符串            ${gl_bufan}4.  ${gl_bai}序号重命名"
        echo -e "${gl_bufan}5.  ${gl_bai}大小写转换            ${gl_bufan}6.  ${gl_bai}移除字符"
        echo -e "${gl_bufan}7.  ${gl_bai}删除所有空格"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单        ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请选择重命名模式: ")" rename_mode

        case "$rename_mode" in
        1) rename_files_add_prefix ;;           # 添加前缀
        2) rename_files_add_suffix ;;           # 添加后缀
        3) rename_files_replace_string ;;       # 替换字符串
        4) rename_files_sequential ;;           # 序号重命名
        5) rename_files_change_case ;;          # 大小写转换
        6) rename_files_remove_chars ;;         # 移除字符
        7) rename_files_remove_spaces ;;        # 删除所有空格
        0) cancel_return; return ;;             # 返回到上一级菜单
        00 | 000 | 0000) exit_script ;;         # 感谢使用，再见！
        *) handle_invalid_input ;;              # 无效的输入,请重新输入!
        esac
    done
}

rename_files_add_prefix() {
    local current_dir=$(pwd)
    local files=()
    while IFS= read -r -d $'\0' file; do
        if [[ -f "$file" ]]; then
            files+=("$file")
        fi
    done < <(find "$current_dir" -maxdepth 1 -type f -print0 2>/dev/null)
    
    local file_count=${#files[@]}
    
    if [[ $file_count -eq 0 ]]; then
        echo -e "${gl_huang}当前目录下没有找到任何文件${gl_bai}"
        exit_animation    # 即将退出动画
        return
    fi
    
    echo -e ""
    echo -e "${gl_zi}>>> 批量添加前缀${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -e -p "$(echo -e "${gl_bai}请输入要添加的前缀(${gl_huang}0${gl_bai}返回): ")" prefix
    if [[ -z "$prefix" ]]; then
        log_warn "前缀不能为空"
        exit_animation    # 即将退出动画
        return
    fi

    [ "$prefix" == "0" ] && { cancel_return "上一级选单"; return 1; }  # break 或 continue 或 return ，视上下文而定

    echo -e "${gl_bai}预览重命名结果:${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local rename_count=0
    local rename_files=()
    for file in "${files[@]}"; do
        local filename=$(basename "$file")
        local dir=$(dirname "$file")
        local newname="${dir}/${prefix}${filename}"

        if [[ "$filename" != "${prefix}${filename}" ]]; then
            rename_files+=("$file:$newname")
            echo -e "  ${gl_bufan}${filename}${gl_bai} -> ${gl_lv}${prefix}${filename}${gl_bai}"
        fi
    done

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}将重命名 ${gl_lv}${#rename_files[@]}${gl_bai} 个文件${gl_bai}"

    if [[ ${#rename_files[@]} -gt 0 ]]; then
        read -r -e -p "$(echo -e "${gl_bai}确认执行重命名? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
        [ "$confirm" = "0" ] && { cancel_return "上一级选单"; return 1; }      # break 或 continue 或 return ，视上下文而定
        case "$confirm" in
        [Yy])
            for rename_pair in "${rename_files[@]}"; do
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
        *) handle_y_n ;;        # 无效的输入,请输入(y或N)。
        esac
    else
        log_warn "没有文件需要重命名（可能文件已有相同前缀）"
    fi

    if [[ $rename_count -gt 0 ]]; then
        log_ok "成功重命名 ${rename_count} 个文件"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

rename_files_add_suffix() {
    local current_dir=$(pwd)
    local files=()
    while IFS= read -r -d $'\0' file; do
        if [[ -f "$file" ]]; then
            files+=("$file")
        fi
    done < <(find "$current_dir" -maxdepth 1 -type f -print0 2>/dev/null)
    
    local file_count=${#files[@]}
    
    if [[ $file_count -eq 0 ]]; then
        echo -e "${gl_huang}当前目录下没有找到任何文件${gl_bai}"
        exit_animation    # 即将退出动画
        return
    fi
    
    echo -e ""
    echo -e "${gl_zi}>>> 批量添加后缀${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -e -p "$(echo -e "${gl_bai}请输入要添加的后缀 (不含扩展名)(${gl_huang}0${gl_bai}返回): ")" suffix
    if [[ -z "$suffix" ]]; then
        log_warn "后缀不能为空"
        exit_animation    # 即将退出动画
        return
    fi

    [[ "$suffix" == "0" ]] && { cancel_return "上一级选单"; return 1; }    # break 或 continue 或 return ，视上下文而定

    echo -e "${gl_bai}预览重命名结果:${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local rename_count=0
    local rename_files=()
    for file in "${files[@]}"; do
        local filename=$(basename "$file")
        local dir=$(dirname "$file")
        local newname

        if [[ "$filename" =~ \. ]]; then
            local ext="${filename##*.}"
            local name="${filename%.*}"
            if [[ "$name" == "$ext" ]]; then
                newname="${dir}/${filename}${suffix}"
            else
                newname="${dir}/${name}${suffix}.${ext}"
            fi
        else
            newname="${dir}/${filename}${suffix}"
        fi

        if [[ "$filename" != "$(basename "$newname")" ]]; then
            rename_files+=("$file:$newname")
            echo -e "  ${gl_bufan}${filename}${gl_bai} -> ${gl_lv}$(basename "$newname")${gl_bai}"
        fi
    done

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}将重命名 ${gl_lv}${#rename_files[@]}${gl_bai} 个文件${gl_bai}"

    if [[ ${#rename_files[@]} -gt 0 ]]; then
        read -r -e -p "$(echo -e "${gl_bai}确认执行重命名? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
        case "$confirm" in
        [Yy])
            for rename_pair in "${rename_files[@]}"; do
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
        *) handle_y_n ;;        # 无效的输入,请输入(y或N)。
        esac
    else
        log_warn "没有文件需要重命名"
    fi

    if [[ $rename_count -gt 0 ]]; then
        log_ok "成功重命名 ${rename_count} 个文件"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

rename_files_replace_string() {
    local current_dir=$(pwd)
    local files=()
    while IFS= read -r -d $'\0' file; do
        if [[ -f "$file" ]]; then
            files+=("$file")
        fi
    done < <(find "$current_dir" -maxdepth 1 -type f -print0 2>/dev/null)
    
    local file_count=${#files[@]}
    
    if [[ $file_count -eq 0 ]]; then
        echo -e "${gl_huang}当前目录下没有找到任何文件${gl_bai}"
        exit_animation    # 即将退出动画
        return
    fi
    
    echo -e ""
    echo -e "${gl_zi}>>> 替换字符${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -e -p "$(echo -e "${gl_bai}请输入要替换的字符串(${gl_huang}0${gl_bai}返回): ")" old_str

    [[ "$old_str" == "0" ]] && { cancel_return "上一级选单"; return 1; }

    if [[ -z "$old_str" ]]; then
        log_warn "要替换的字符串不能为空"
        exit_animation    # 即将退出动画
        return
    fi

    read -r -e -p "$(echo -e "${gl_bai}请输入替换为的字符串: ")" new_str
    [ "$new_str" == "0" ] && { cancel_return "上一级选单"; return 1; }   # break 或 continue 或 return ，视上下文而定

    echo -e "${gl_bai}预览重命名结果:${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local rename_count=0
    local rename_files=()
    for file in "${files[@]}"; do
        local filename=$(basename "$file")
        local dir=$(dirname "$file")
        local newname="${dir}/${filename//$old_str/$new_str}"

        if [[ "$filename" != "$(basename "$newname")" ]]; then
            rename_files+=("$file:$newname")
            echo -e "  ${gl_bufan}${filename}${gl_bai} -> ${gl_lv}$(basename "$newname")${gl_bai}"
        fi
    done

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}将重命名 ${gl_lv}${#rename_files[@]}${gl_bai} 个文件${gl_bai}"

    if [[ ${#rename_files[@]} -gt 0 ]]; then
        read -r -e -p "$(echo -e "${gl_bai}确认执行重命名? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
        [ "$confirm" == "0" ] && { cancel_return "上一级选单"; return 1; }      # break 或 continue 或 return ，视上下文而定
        case "$confirm" in
        [Yy])
            for rename_pair in "${rename_files[@]}"; do
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
        *) handle_y_n ;;        # 无效的输入,请输入(y或N)。
        esac
    else
        log_warn "没有找到匹配的字符串 '$old_str'"
    fi

    if [[ $rename_count -gt 0 ]]; then
        log_ok "成功重命名 ${rename_count} 个文件"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

rename_files_sequential() {
    local current_dir=$(pwd)
    local files=()
    while IFS= read -r -d $'\0' file; do
        if [[ -f "$file" ]]; then
            files+=("$file")
        fi
    done < <(find "$current_dir" -maxdepth 1 -type f -print0 2>/dev/null)
    
    local file_count=${#files[@]}
    
    if [[ $file_count -eq 0 ]]; then
        echo -e "${gl_huang}当前目录下没有找到任何文件${gl_bai}"
        exit_animation    # 即将退出动画
        return
    fi
    
    echo -e ""
    echo -e "${gl_huang}>>> 序号重命名模板说明:${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "  ${gl_huang}###${gl_bai} 表示三位数字序号 (如: 001, 002)"
    echo -e "  ${gl_huang}##${gl_bai}  表示两位数字序号 (如: 01, 02)"
    echo -e "  ${gl_huang}#${gl_bai}   表示一位数字序号 (如: 1, 2)"
    echo -e "  ${gl_huang}%d${gl_bai}  表示数字序号 (如: 1, 2, 3)"
    echo -e ""
    echo -e "${gl_bai}示例:${gl_bai}"
    echo -e "  ${gl_huang}image-###.jpg${gl_bai}   -> ${gl_lv}image-001.jpg, image-002.jpg, ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "  ${gl_huang}document_##.txt${gl_bai} -> ${gl_lv}document_01.txt, document_02.txt, ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "  ${gl_huang}file_#.pdf${gl_bai}      -> ${gl_lv}file_1.pdf, file_2.pdf, ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    echo -e ""
    echo -e "${gl_zi}>>> 序号重命名${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -e -p "$(echo -e "${gl_bai}请输入文件名模板(${gl_huang}0${gl_bai}返回): ")" template
    [[ "$template" == "0" ]] && { cancel_return "上一级选单"; return 1; }

    if [[ -z "$template" ]]; then
        log_warn "模板不能为空"
        exit_animation    # 即将退出动画
        return
    fi

    echo -e "${gl_bai}预览重命名结果:${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local rename_count=0
    local rename_files=()
    local idx=1

    for file in "${files[@]}"; do
        local dir=$(dirname "$file")
        local filename=$(basename "$file")
        local ext="${filename##*.}"
        local name_without_ext="${filename%.*}"
        
        if [[ "$filename" =~ \. ]] && [[ "$name_without_ext" != "$ext" ]]; then
            local newname_template="${template%.*}"
            if [[ -z "$newname_template" ]]; then
                newname_template="$template"
            fi
            
            if [[ "$newname_template" =~ "###" ]]; then
                newname_template="${newname_template//###/$(printf "%03d" $idx)}"
            elif [[ "$newname_template" =~ "##" ]]; then
                newname_template="${newname_template//##/$(printf "%02d" $idx)}"
            elif [[ "$newname_template" =~ "#" ]]; then
                newname_template="${newname_template//#/$idx}"
            elif [[ "$newname_template" =~ "%d" ]]; then
                newname_template="${newname_template//%d/$idx}"
            else
                newname_template="${newname_template}_${idx}"
            fi
            
            local newname="${dir}/${newname_template}.${ext}"
        else
            local newname_template="$template"
            
            if [[ "$newname_template" =~ "###" ]]; then
                newname_template="${newname_template//###/$(printf "%03d" $idx)}"
            elif [[ "$newname_template" =~ "##" ]]; then
                newname_template="${newname_template//##/$(printf "%02d" $idx)}"
            elif [[ "$newname_template" =~ "#" ]]; then
                newname_template="${newname_template//#/$idx}"
            elif [[ "$newname_template" =~ "%d" ]]; then
                newname_template="${newname_template//%d/$idx}"
            else
                newname_template="${newname_template}_${idx}"
            fi
            
            local newname="${dir}/${newname_template}"
        fi
        
        rename_files+=("$file:$newname")
        echo -e "  ${gl_bufan}${filename}${gl_bai} -> ${gl_lv}$(basename "$newname")${gl_bai}"
        ((idx++))
    done

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}将重命名 ${gl_lv}${#rename_files[@]}${gl_bai} 个文件${gl_bai}"

    if [[ ${#rename_files[@]} -gt 0 ]]; then
        read -r -e -p "$(echo -e "${gl_bai}确认执行重命名? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
        [ "$confirm" == "0" ] && { cancel_return "上一级选单"; return 1; }      # break 或 continue 或 return ，视上下文而定
        case "$confirm" in
        [Yy])
            for rename_pair in "${rename_files[@]}"; do
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
        *) handle_y_n ;;        # 无效的输入,请输入(y或N)。
        esac
    fi

    if [[ $rename_count -gt 0 ]]; then
        log_ok "成功重命名 ${rename_count} 个文件"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

rename_files_change_case() {
    local current_dir=$(pwd)
    local files=()
    while IFS= read -r -d $'\0' file; do
        if [[ -f "$file" ]]; then
            files+=("$file")
        fi
    done < <(find "$current_dir" -maxdepth 1 -type f -print0 2>/dev/null)
    
    local file_count=${#files[@]}
    
    if [[ $file_count -eq 0 ]]; then
        echo -e "${gl_huang}当前目录下没有找到任何文件${gl_bai}"
        exit_animation    # 即将退出动画
        return
    fi
    
    while true; do
        echo -e ""
        echo -e "${gl_zi}>>> 大小写转换${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}转为小写              ${gl_bufan}2.  ${gl_bai}转为大写"
        echo -e "${gl_bufan}3.  ${gl_bai}首字母大写            ${gl_bufan}4.  ${gl_bai}单词首字母大写"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单        ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请选择转换模式: ")" case_mode

        case "$case_mode" in
        0) cancel_return;  return  ;;
        00 | 000 | 0000) exit_script ;; # 感谢使用，再见！
        1 | 2 | 3 | 4)
            local rename_count=0
            local rename_files=()

            echo -e "${gl_bai}预览重命名结果:${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

            for file in "${files[@]}"; do
                local filename=$(basename "$file")
                local dir=$(dirname "$file")
                local newname

                case "$case_mode" in
                1) # 转为小写
                    newname="${dir}/${filename,,}"
                    ;;
                2) # 转为大写
                    newname="${dir}/${filename^^}"
                    ;;
                3) # 首字母大写
                    newname="${dir}/${filename^}"
                    ;;
                4) # 单词首字母大写
                    newname="$filename"
                    if [[ "$newname" =~ [a-zA-Z] ]]; then
                        newname=$(echo "$newname" | sed -E 's/(^|_)([a-z])/\1\u\2/g' 2>/dev/null || echo "$newname")
                    fi
                    newname="${dir}/${newname}"
                    ;;
                esac

                if [[ "$filename" != "$(basename "$newname")" ]]; then
                    rename_files+=("$file:$newname")
                    echo -e "  ${gl_bufan}${filename}${gl_bai} -> ${gl_lv}$(basename "$newname")${gl_bai}"
                fi
            done

            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_bai}将重命名 ${gl_lv}${#rename_files[@]}${gl_bai} 个文件${gl_bai}"

            if [[ ${#rename_files[@]} -gt 0 ]]; then
                read -r -e -p "$(echo -e "${gl_bai}确认执行重命名? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
                [ "$confirm" = "0" ] && { cancel_return "上一级选单"; continue; }      # break 或 continue 或 return ，视上下文而定
                case "$confirm" in
                [Yy])
                    for rename_pair in "${rename_files[@]}"; do
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
                *) handle_y_n ;;       # 无效的输入,请重新输入!
                esac
            else
                log_warn "没有文件需要转换大小写"
            fi

            if [[ $rename_count -gt 0 ]]; then
                log_ok "成功重命名 ${rename_count} 个文件"
            fi
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            return
            ;;
        *) handle_invalid_input ;;
        esac
    done
}

rename_files_remove_chars() {
    local current_dir=$(pwd)
    local files=()
    while IFS= read -r -d $'\0' file; do
        if [[ -f "$file" ]]; then
            files+=("$file")
        fi
    done < <(find "$current_dir" -maxdepth 1 -type f -print0 2>/dev/null)
    
    local file_count=${#files[@]}
    
    if [[ $file_count -eq 0 ]]; then
        echo -e "${gl_huang}当前目录下没有找到任何文件${gl_bai}"
        exit_animation    # 即将退出动画
        return
    fi
    
    echo -e ""
    echo -e "${gl_zi}>>> 移除字符${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -e -p "$(echo -e "${gl_bai}请输入要移除的字符或模式(${gl_huang}0${gl_bai}返回): ")" remove_pattern

    [[ "$remove_pattern" == "0" ]] && { cancel_return "上一级选单"; return 1; }    # break 或 continue 或 return ，视上下文而定

    if [[ -z "$remove_pattern" ]]; then
        log_warn "要移除的字符不能为空"
        exit_animation    # 即将退出动画
        return
    fi

    echo -e "${gl_bai}预览重命名结果:${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local rename_count=0
    local rename_files=()
    for file in "${files[@]}"; do
        local filename=$(basename "$file")
        local dir=$(dirname "$file")
        local newname="${dir}/${filename//$remove_pattern/}"

        if [[ "$filename" != "$(basename "$newname")" ]]; then
            rename_files+=("$file:$newname")
            echo -e "  ${gl_bufan}${filename}${gl_bai} -> ${gl_lv}$(basename "$newname")${gl_bai}"
        fi
    done

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}将重命名 ${gl_lv}${#rename_files[@]}${gl_bai} 个文件${gl_bai}"

    if [[ ${#rename_files[@]} -gt 0 ]]; then
        read -r -e -p "$(echo -e "${gl_bai}确认执行重命名? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
        [[ "$confirm" == "0" ]] && { cancel_return "上一级选单"; return 1; }    # break 或 continue 或 return ，视上下文而定
        case "$confirm" in
        [Yy])
            for rename_pair in "${rename_files[@]}"; do
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
        *) handle_y_n ;;        # 无效的输入,请输入(y或N)。
        esac
    else
        log_warn "没有找到匹配的字符 '$remove_pattern'"
    fi

    if [[ $rename_count -gt 0 ]]; then
        log_ok "成功重命名 ${rename_count} 个文件"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

rename_files_remove_spaces() {
    local current_dir=$(pwd)
    local files=()
    while IFS= read -r -d $'\0' file; do
        if [[ -f "$file" ]]; then
            files+=("$file")
        fi
    done < <(find "$current_dir" -maxdepth 1 -type f -print0 2>/dev/null)
    
    local file_count=${#files[@]}
    
    if [[ $file_count -eq 0 ]]; then
        echo -e "${gl_huang}当前目录下没有找到任何文件${gl_bai}"
        exit_animation    # 即将退出动画
        return
    fi
    
    echo -e ""
    echo -e "${gl_zi}>>> 删除文件名中的所有空格${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    echo -e "${gl_bai}注意: 此操作将删除文件名中的所有空格字符${gl_bai}"
    echo -e "${gl_bai}包括文件名开头、中间和结尾的空格${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    echo -e "${gl_bai}预览重命名结果:${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local rename_count=0
    local rename_files=()
    for file in "${files[@]}"; do
        local filename=$(basename "$file")
        local dir=$(dirname "$file")
        local newname="${dir}/${filename// /}"

        if [[ "$filename" != "$(basename "$newname")" ]]; then
            rename_files+=("$file:$newname")
            echo -e "  ${gl_bufan}${filename}${gl_bai} -> ${gl_lv}$(basename "$newname")${gl_bai}"
        fi
    done

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}将重命名 ${gl_lv}${#rename_files[@]}${gl_bai} 个文件${gl_bai}"

    if [[ ${#rename_files[@]} -gt 0 ]]; then
        read -r -e -p "$(echo -e "${gl_bai}确认执行重命名? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
        [[ "$confirm" == "0" ]] && { cancel_return "上一级选单"; return 1; }    # break 或 continue 或 return ，视上下文而定
        case "$confirm" in
        [Yy])
            for rename_pair in "${rename_files[@]}"; do
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
        *) handle_y_n ;;        # 无效的输入,请输入(y或N)。
        esac
    else
        log_warn "没有文件名包含空格"
    fi

    if [[ $rename_count -gt 0 ]]; then
        log_ok "成功重命名 ${rename_count} 个文件"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

download_single() {
    local url="${1:-}"
    [[ -z "$url" ]] && return 1 # 保险

    local raw_name=$(echo "$url" | sed 's/^.*\///' | sed 's/?.*$//')
    local filename=$(printf '%b' "${raw_name//%/\\x}" 2>/dev/null || echo "$raw_name")
    [[ -z "$filename" || "$filename" == "/" ]] && filename="downloaded_file"
    filename=$(echo "$filename" | tr -d '\000-\037' | tr '/' '_' | tr ':' '_' | tr '()[]{}<>' '_' | tr '*?&' '_')

    echo -e ""
    echo -e ""
    echo -e "${gl_huang}>>> 下载文件默认名称为: ${gl_lv}$filename${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}是否修改文件名？(${gl_huang}回车${gl_bai}使用默认名称): ")" new_filename
    [[ -n "$new_filename" ]] && filename="$new_filename"

    echo -e "${gl_bai}检测文件信息 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    local expected_size=0
    if command -v curl &>/dev/null; then
        expected_size=$(curl -s -L -I "$url" 2>/dev/null | grep -i 'content-length' | awk '{print $2}' | tr -d '\r' | tail -1)
    elif command -v wget &>/dev/null; then
        expected_size=$(wget --spider -S "$url" 2>&1 | grep -i 'content-length' | awk '{print $2}' | tail -1)
    fi
    [[ -n "$expected_size" && "$expected_size" -gt 0 ]] &&
        echo -e "${gl_bai}检测到文件大小: ${gl_lv}$(numfmt --to=iec "$expected_size")${gl_bai}" ||
        echo -e "${gl_huang}无法获取文件大小，将进行完整下载 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

    local download_tool=""
    if command -v wget &>/dev/null; then
        download_tool="wget"
        echo -e ""
        echo -e "${gl_huang}使用 wget 下载${gl_bai}"
    elif command -v curl &>/dev/null; then
        download_tool="curl"
        echo -e ""
        echo -e "${gl_huang}使用 curl 下载${gl_bai}"
    else
        echo -e ""
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_hong}错误：未找到可用的下载工具 (wget/curl)${gl_bai}"
        read -n 1 -p "$(echo -e "按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} ")"
        return 1
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    local existing_size=0
    if [[ -f "$filename" ]]; then
        existing_size=$(stat -c%s "$filename" 2>/dev/null || echo 0)
        if [[ "$expected_size" -gt 0 && "$existing_size" -eq "$expected_size" ]]; then
            echo -e "${gl_lv}✓ 文件已存在且完整，无需下载。${gl_bai}"
            echo -e "${gl_lv}文件路径: ${gl_bai}$(realpath "$filename" 2>/dev/null || echo "$filename")"
            return 0
        elif [[ "$existing_size" -gt 0 ]]; then
            echo -e "${gl_huang}检测到已下载: ${gl_lv}$(numfmt --to=iec "$existing_size")${gl_huang}，将尝试断点续传 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        fi
    fi

    fmt_time() {
        local sec=$1
        local h=$((sec / 3600))
        local m=$(((sec % 3600) / 60))
        local s=$((sec % 60))
        printf "%02d:%02d:%02d" "$h" "$m" "$s"
    }
    local start_ts=$(date +%s)
    echo -e "${gl_lv}开始下载 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

    local exit_code=0
    case $download_tool in
    wget)
        wget -c -T 30 --progress=bar:force:noscroll -O "$filename" "$url"
        exit_code=$?
        ;;
    curl)
        curl -L -C - --progress-bar -o "$filename" "$url"
        exit_code=$?
        ;;
    esac

    local end_ts=$(date +%s)
    local elapsed=$((end_ts - start_ts))
    echo -e "${gl_lv}下载耗时：${gl_bai}$(fmt_time "$elapsed")"

    [[ $exit_code -ne 0 ]] && echo -e "${gl_hong}下载失败！错误代码: $exit_code${gl_bai}" && return 1
    local actual_size=$(stat -c%s "$filename" 2>/dev/null || echo 0)
    if [[ "$expected_size" -gt 0 && "$actual_size" -ne "$expected_size" ]]; then
        echo -e "${gl_hong}文件大小不匹配，下载不完整！${gl_bai}"
        echo -e "${gl_hong}实际: ${gl_lv}$(numfmt --to=iec "$actual_size")${gl_hong}，期望: ${gl_lv}$(numfmt --to=iec "$expected_size")${gl_bai}"
        read -n 1 -p "$(echo -e "${gl_hong}按任意键退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}")"
        return 1
    fi
    echo -e "${gl_lv}✓ 下载成功！文件大小完整。${gl_bai}"

    echo -e ""
    echo -e "${gl_huang}>>> 下载文件信息：${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    if [[ -f "$filename" ]]; then
        local file_path=$(realpath "$filename" 2>/dev/null || echo "$filename")
        local file_size_human
        file_size_human=$(stat -c %s "$filename" 2>/dev/null | numfmt --to=iec 2>/dev/null || echo "未知")
        local file_bytes=$(stat -c%s "$filename" 2>/dev/null || echo 0)
        local file_type=$(file -b "$filename" 2>/dev/null || echo "未知")
        local mod_time=$(stat -c "%y" "$filename" 2>/dev/null | cut -d'.' -f1 || echo "未知")
        local md5sum=$(md5sum "$filename" 2>/dev/null | cut -d' ' -f1 || echo "计算失败")

        echo -e "${gl_bai}文件路径: ${gl_lv}$file_path${gl_bai}"
        echo -e "${gl_bai}文件大小: ${gl_lv}$file_size_human (${file_bytes} 字节)${gl_bai}"
        [[ "$expected_size" -gt 0 ]] && echo -e "${gl_bai}完整性: ${gl_lv}✓ 完整${gl_bai}"
        echo -e "${gl_bai}文件类型: ${gl_lv}$file_type${gl_bai}"
        echo -e "${gl_bai}修改时间: ${gl_lv}$mod_time${gl_bai}"
        echo -e "${gl_bai}MD5 校验: ${gl_lv}$md5sum${gl_bai}"
    else
        echo -e "${gl_hong}错误：无法找到下载的文件${gl_bai}"
    fi
    return 0
}

download_file() {
    if [[ -n "${1:-}" ]]; then
        download_single "$1"
        return
    fi

    while true; do
        clear
        if [ -z "$(ls -A)" ]; then
            echo -e "${gl_huang}>>> 当前目录文件列表：${gl_bai}(${gl_lv}$(pwd)${gl_bai})"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_huang}当前目录为空${gl_bai}"
        else
            list_dir_colorful 0 4
        fi
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e ""
        echo -e "${gl_zi}>>> 文件下载${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入下载链接（${gl_huang}0${gl_bai}返回）：")" url
        [ "$url" = "0" ] && { cancel_return; return 1; }
        [[ -z "$url" ]] && echo -e "${gl_hong}错误：链接不能为空！${gl_bai}" && read -n 1 -p "$(echo -e "按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} ")" && continue
        url=$(echo "$url" | sed 's|https://https://|https://|g')

        if [[ ! "$url" =~ ^https?:// ]]; then
            echo -e "${gl_hong}错误：链接必须以http://或https://开头！${gl_bai}"
            exit_animation    # 即将退出动画
            continue
        fi

        download_single "$url"

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_lv}✓ 下载成功！${gl_bai}"
        read -r -n 1 -p "$(echo -e "${gl_bai}按任意键继续下载 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}")"
    done
}

move_file_or_directory() {

    check_directory_empty "." "移动文件或目录" "true" || return

    clear
    
    if ! list_files "." 0 4; then
        exit_animation    # 即将退出动画
        return 1
    fi
    
    if [[ ${#LIST_FILES_ARRAY[@]} -eq 0 ]] || [[ "$LIST_FILES_COUNT" -eq 0 ]]; then
        exit_animation    # 即将退出动画
        return 1
    fi
    
    echo ""
    echo -e "${gl_zi}>>> 移动文件或目录${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}提示: 支持输入序号、完整路径或通配符模式(${gl_lv}如 *.tar.gz${gl_bai})${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    read -r -e -p "$(echo -e "${gl_bai}请输入源文件序号(${gl_huang}1${gl_bai}-${gl_lv}${LIST_FILES_COUNT}${gl_bai})、路径或通配符(${gl_huang}0${gl_bai}返回): ")" src_input
    
    [ -z "$src_input" ] && { cancel_empty "上一级选单"; return 1; }                      # break 或 continue 或 return ，视上下文而定
    [ "$src_input" == "0" ] && { cancel_return "文件管理器"; return 1; }     # break 或 continue 或 return ，视上下文而定
    
    local src_paths=()  # 改为数组，支持多文件
    
    if [[ "$src_input" =~ ^[0-9]+$ ]]; then
        local idx=$((src_input - 1))
        if [[ $idx -ge 0 && $idx -lt ${#LIST_FILES_ARRAY[@]} ]]; then
            src_paths=("${LIST_FILES_ARRAY[$idx]}")
        else
            log_error "序号超出范围: $src_input (有效范围: 1-${LIST_FILES_COUNT})"
            exit_animation    # 即将退出动画
            return 1
        fi
    elif [[ "$src_input" == *"*"* ]] || [[ "$src_input" == *"?"* ]] || [[ "$src_input" == *"["* ]]; then
        local pattern="${src_input/#\~/$HOME}"
        
        local matched_files=()
        local file
        for file in $pattern; do
            [[ -e "$file" ]] && matched_files+=("$file")
        done
        
        if [[ ${#matched_files[@]} -eq 0 ]]; then
            log_error "未找到匹配的文件: $src_input"
            exit_animation    # 即将退出动画
            return 1
        fi
        
        echo -e ""
        echo -e "${gl_lv}找到 ${gl_huang}${#matched_files[@]}${gl_lv} 个匹配文件:${gl_bai}"
        local count=0
        for file in "${matched_files[@]}"; do
            ((count++))
            printf "${gl_huang}%2d.${gl_bai} ${gl_bai}%-30s${gl_bai}" "$count" "$(basename "$file")"
            if ((count % 2 == 0)); then
                echo ""
            fi
        done
        if ((count % 2 != 0)); then
            echo ""
        fi
        echo ""
        
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}确认移动以上文件? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
        [ "$confirm" == "0" ] && { cancel_return "文件管理器"; return 1; }      # break 或 continue 或 return ，视上下文而定
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_info "已取消移动操作"
            exit_animation    # 即将退出动画
            return 1
        fi
        
        src_paths=("${matched_files[@]}")
    else
        local manual_path="${src_input/#\~/$HOME}"
        if [[ -e "$manual_path" ]]; then
            src_paths=("$manual_path")
        else
            log_error "文件或目录不存在: $manual_path"
            exit_animation    # 即将退出动画
            return 1
        fi
    fi
    
    echo ""
    echo -e "${gl_huang}>>> 选择目标位置${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    local dir_array=()
    local dir_count=0
    local i item item_path
    for i in "${!LIST_FILES_ARRAY[@]}"; do
        item="${LIST_FILES_ARRAY[$i]}"
        item_path="./$item"
        if [[ -d "$item_path" ]]; then
            dir_array[$dir_count]="$item"
            ((dir_count++))
        fi
    done
    
    if [[ $dir_count -gt 0 ]]; then
        echo -e "${gl_bufan}当前目录中的子目录:${gl_bai}"
        local count=0
        for ((i=0; i<dir_count; i++)); do
            ((count++))
            printf "${gl_bufan}%2d.${gl_bai} ${gl_zi}%-20s${gl_bai}" "$count" "${dir_array[$i]}"
            if ((count % 2 == 0)); then
                echo ""
            fi
        done
        if ((count % 2 != 0)); then
            echo ""
        fi
        echo ""
    fi
    
    read -r -e -p "$(echo -e "${gl_bai}请输入目标路径 (目录序号、目录名或完整路径)(${gl_huang}0${gl_bai}返回): ")" dest_input

    [ -z "$dest_input" ] && { cancel_empty "上一级选单"; return 1; }                     # break 或 continue 或 return ，视上下文而定
    [ "$dest_input" == "0" ] && { cancel_return "文件管理器"; return 1; }    # break 或 continue 或 return ，视上下文而定
    
    local dest_path=""
    
    if [[ "$dest_input" =~ ^[0-9]+$ ]]; then
        local idx=$((dest_input - 1))
        if [[ $idx -ge 0 && $idx -lt $dir_count ]]; then
            dest_path="${dir_array[$idx]}"
        else
            log_error "目录序号超出范围: $dest_input"
            exit_animation    # 即将退出动画
            return 1
        fi
    else
        dest_path="${dest_input/#\~/$HOME}"
    fi
    
    if [[ ! -d "$dest_path" ]]; then
        if [[ -e "$dest_path" ]]; then
            log_error "目标必须是目录: $dest_path"
            exit_animation    # 即将退出动画
            return 1
        else
            read -r -e -p "$(echo -e "${gl_bai}目标目录不存在，是否创建? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" create_confirm
            [ "$create_confirm" = "0" ] && { cancel_return "上一级选单"; return 1; }      # break 或 continue 或 return ，视上下文而定
            if [[ "$create_confirm" =~ ^[Yy]$ ]]; then
                if ! mkdir -p "$dest_path"; then
                    log_error "创建目录失败: $dest_path"
                    exit_animation    # 即将退出动画
                    return 1
                fi
                log_info "已创建目录: $dest_path"
            else
                log_info "已取消移动操作"
                exit_animation    # 即将退出动画
                return 1
            fi
        fi
    fi
    
    [[ "$dest_path" != */ ]] && dest_path="$dest_path/"
    
    local success_count=0
    local fail_count=0
    local src_path src_basename dest_full_path
    
    for src_path in "${src_paths[@]}"; do
        src_basename=$(basename "$src_path")
        dest_full_path="${dest_path}${src_basename}"
        
        if [[ -e "$dest_full_path" ]]; then
            read -r -e -p "$(echo -e "${gl_bai}目标已存在 '${gl_huang}$src_basename${gl_bai}'，是否覆盖? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}/${gl_huang}a${gl_bai}全部): ")" confirm
            [ "$confirm" = "0" ] && { cancel_return "上一级选单"; return 1; }      # break 或 continue 或 return ，视上下文而定
            case "$confirm" in
                [Aa])  # 全部覆盖，不再询问
                    ;;
                [Yy])  # 单个覆盖
                    ;;
                *)     # 跳过
                    log_info "跳过: $src_basename"
                    ((fail_count++))
                    continue
                    ;;
            esac
        fi
        
        if mv "$src_path" "$dest_full_path"; then
            log_info "成功移动: ${gl_huang}$src_basename${gl_bai}"
            ((success_count++))
        else
            log_error "移动失败: ${gl_huang}$src_basename${gl_bai}"
            ((fail_count++))
        fi
    done
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    if [[ ${#src_paths[@]} -gt 1 ]]; then
        log_info "批量移动完成: 成功 ${gl_lv}$success_count${gl_bai}, 失败 ${gl_hong}$fail_count${gl_bai}, 总计 ${gl_huang}${#src_paths[@]}${gl_bai}"
    else
        log_info "移动完成: ${gl_lv}$success_count${gl_bai} 成功, ${gl_hong}$fail_count${gl_bai} 失败"
    fi
    
    break_end 
    return 0
}

copy_file_or_directory() {
    check_directory_empty "." "复制文件/目录" "true" || return
    clear

    if ! list_files "." 0 4; then
        exit_animation    # 即将退出动画
        return 1
    fi
    
    if [[ ${#LIST_FILES_ARRAY[@]} -eq 0 ]] || [[ "$LIST_FILES_COUNT" -eq 0 ]]; then
        exit_animation    # 即将退出动画
        return 1
    fi
    
    local src_path=""
    local dest_path=""
    local user_input=""
    local src_name=""
    
    echo ""
    echo -e "${gl_zi}>>> 复制文件/目录${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}输入序号选择源文件/目录，或直接输入路径 (${gl_huang}0${gl_bai}返回): ")" user_input
    
    [[ -z "$user_input" ]] && { cancel_empty "上一级选单"; return 1; }                       # break 或 continue 或 return ，视上下文而定
    [[ "$user_input" == "0" ]] && { cancel_return "文件管理器"; return 1; }      # break 或 continue 或 return ，视上下文而定
    
    if [[ "$user_input" =~ ^[0-9]+$ ]]; then
        local idx=$((user_input - 1))
        if ((idx >= 0 && idx < LIST_FILES_COUNT)); then
            src_path="${LIST_FILES_ARRAY[$idx]}"
            log_ok "已选择 [$user_input]: $src_path"
        else
            log_error "无效的序号: $user_input (有效范围: 1-$LIST_FILES_COUNT)"
            exit_animation    # 即将退出动画
            return 1
        fi
    else
        src_path="$user_input"
        if [[ ! -e "$src_path" ]]; then
            log_error "文件或目录不存在: $src_path"
            exit_animation    # 即将退出动画
            return 1
        fi
        log_ok "已指定: $src_path"
    fi
    
    if [[ ! -e "$src_path" ]]; then
        log_error "无法访问: $src_path"
        exit_animation    # 即将退出动画
        return 1
    fi
    
    src_name=$(basename "$src_path")
    
    echo ""
    echo -e "${gl_bai}源路径: ${gl_huang}$src_path${gl_bai}"
    if [[ -d "$src_path" ]]; then
        echo -e "${gl_bai}类型: ${gl_zi}目录${gl_bai}"
    else
        echo -e "${gl_bai}类型: ${gl_lv}文件${gl_bai}"
        local file_size=$(du -h "$src_path" 2>/dev/null | cut -f1)
        echo -e "${gl_bai}大小: ${gl_huang}$file_size${gl_bai}"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    read -r -e -p "$(echo -e "${gl_bai}请输入目标路径 (包括新文件名或目录名)(${gl_huang}0${gl_bai}返回)"：)" dest_path

    [[ "$dest_path" == "0" ]] && { cancel_return "文件管理器"; return 1; }
    
    if [[ -z "$dest_path" ]]; then
        log_error "目标路径不能为空"
        exit_animation    # 即将退出动画
        return 1
    fi
    
    if [[ -e "$dest_path" ]]; then
        if [[ -d "$dest_path" ]]; then
            dest_path="${dest_path%/}/$src_name"
            log_info "目标为目录，自动调整为: $dest_path"
        else
            log_warn "目标文件已存在: $dest_path"
            read -r -e -p "$(echo -e "${gl_bai}是否覆盖? (${gl_hong}y${gl_bai}/${gl_lv}N${gl_bai}): ")" overwrite
            if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
                log_info "已取消操作"
                exit_animation    # 即将退出动画
                return 1
            fi
        fi
    fi
    
    echo ""
    echo -e "${gl_huang}即将复制:${gl_bai}"
    echo -e "  ${gl_huang}$src_path${gl_bai}"
    echo -e "${gl_bai}到:${gl_bai}"
    echo -e "  ${gl_lv}$dest_path${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}确认执行复制吗? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
    [[ "$confirm" == "0" ]] && { cancel_return "文件管理器"; return 1; }      # break 或 continue 或 return ，视上下文而定
    
    case "$confirm" in
        [Yy])
            if cp -r "$src_path" "$dest_path"; then
                echo ""
                log_ok "复制成功"
                echo -e "${gl_huang}$src_path${gl_bai} -> ${gl_lv}$dest_path${gl_bai}"
                
                if [[ -e "$dest_path" ]]; then
                    if [[ -d "$dest_path" ]]; then
                        local dest_count=$(find "$dest_path" -type f 2>/dev/null | wc -l)
                        echo -e "${gl_bai}目标目录包含 ${gl_huang}$dest_count${gl_bai} 个文件"
                    else
                        local dest_size=$(du -h "$dest_path" 2>/dev/null | cut -f1)
                        echo -e "${gl_bai}目标文件大小: ${gl_huang}$dest_size${gl_bai}"
                    fi
                fi
            else
                log_error "复制失败"
                exit_animation    # 即将退出动画
            fi
            ;;
        [Nn]|"")
            log_warn "已取消操作"
            exit_animation    # 即将退出动画
            ;;
        *) handle_y_n ;;        # 无效的输入,请输入(y或N)。
    esac
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
    return 0
}

search_here() {
    local keyword
    local non_interactive=false

    [[ $# -gt 0 ]] && {
        keyword="$*"
        non_interactive=true
    }

    while true; do
        if [[ "$non_interactive" == false ]]; then

            check_directory_empty "." "当前目录递归内容搜索" "true" || return

            clear
            echo -e ""
            echo -e "${gl_zi}>>> 当前目录递归内容搜索${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "当前目录: ${gl_huang}$(pwd)${gl_bai}"
            echo -e ""
            ls --color=auto -x
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bai}请输入要搜索的关键词 (${gl_huang}0${gl_bai}返回): ")" keyword
            [[ "$keyword" == "0" ]] && { cancel_return "上一级选单"; break; }    # break 或 continue 或 return ，视上下文而定
            [[ -z "$keyword" ]] && { cancel_empty "重新输入"; continue; }      # break 或 continue 或 return ，视上下文而定
        fi

        local here
        here="$(pwd)"
        local found=0

        log_info "正在递归扫描 ${gl_huang}${here}${gl_bai} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        while IFS= read -r -d '' file; do
            while IFS=: read -r -r line_num content; do
                echo
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                log_ok "${file}"
                log_ok "第 ${gl_zi}${line_num}${gl_lv} 行"
                log_ok "${gl_hui}${content}${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                ((found++))
            done < <(grep -in --color=always "$keyword" "$file" 2>/dev/null)
        done < <(find "$here" -type f -print0)

        if [[ $found -eq 0 ]]; then
            echo
            log_warn "未在任何文件内找到匹配内容。"
        fi

        [[ "$non_interactive" == true ]] && break

        break_end
    done
}

manual_file_search_and_process() {
    local search_path="${1:-.}"
    check_directory_empty "." "文件搜索并处理" "true" || return

    clear

    if [ -z "$(ls -A 2>/dev/null)" ]; then
        echo -e "${gl_huang}>>> 当前目录文件列表：${gl_bai}(${gl_lv}$(pwd)${gl_bai})"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}当前目录为空${gl_bai}"
    else
        list_dir_colorful 0 4
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e ""
    echo -e "${gl_zi}>>> 文件搜索并处理${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    echo -e "${gl_huang}文件搜索支持以下模式：${gl_bai}"
    echo -e "${gl_bai}1. 精确文件名: ${gl_lv}example.txt${gl_bai}"
    echo -e "${gl_bai}2. 通配符搜索: ${gl_lv}*.txt${gl_bai} 或 ${gl_lv}test-*.jpg${gl_bai}"
    echo -e "${gl_bai}3. 部分匹配: ${gl_lv}*test*${gl_bai} 或 ${gl_lv}*.log*${gl_bai}"
    echo -e "${gl_bai}4. 模糊搜索: ${gl_lv}example${gl_bai} (包含此关键词的所有文件)"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    read -r -e -p "$(echo -e "${gl_bai}请输入要搜索的文件名、模式或关键词 (${gl_huang}0${gl_bai}返回): ")" pattern

    case "$pattern" in
    0) cancel_return; return 1 ;;
    esac

    if [[ -z "$pattern" ]]; then
        log_error "搜索模式不能为空！"
        return 1
    fi

    echo -e ""
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}正在搜索模式 ${gl_huang}${pattern}${gl_bai} 的文件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    local files=()

    if [[ "$pattern" =~ [\*\?\[\]] ]]; then
        while IFS= read -r -d $'\0' file; do
            files+=("$file")
        done < <(find "$search_path" -name "$pattern" -type f -print0 2>/dev/null)
    else
        echo -e "${gl_bai}使用模糊搜索模式: 搜索包含 \"${gl_huang}${pattern}${gl_bai}\" 的文件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

        while IFS= read -r -d $'\0' file; do
            files+=("$file")
        done < <(find "$search_path" -type f -iname "*${pattern}*" -print0 2>/dev/null)

        if [[ ${#files[@]} -eq 0 ]]; then
            echo -e "${gl_bai}尝试深度模糊搜索 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            while IFS= read -r -d $'\0' file; do
                files+=("$file")
            done < <(find "$search_path" -type f -exec grep -l "$pattern" {} \; -print0 2>/dev/null)
        fi
    fi

    if [[ ${#files[@]} -eq 0 ]]; then
        log_warn "未找到任何匹配 ${gl_bufan}${pattern}${gl_bai} 的文件！"

        echo -e "${gl_bai}${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}搜索建议：${gl_bai}"
        echo -e "${gl_bai}1. 尝试不同的关键词或模式"
        echo -e "${gl_bai}2. 使用通配符: ${gl_lv}*${pattern}*${gl_bai} 或 ${gl_lv}${pattern}*${gl_bai}"
        echo -e "${gl_bai}3. 尝试搜索当前目录: ${gl_lv}.${gl_bai}"
        echo -e "${gl_bai}4. 使用更广泛的搜索路径"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        break_end
        return 1
    fi

    mapfile -t sorted_files < <(printf '%s\n' "${files[@]}" | sort)
    files=("${sorted_files[@]}")

    while true; do
        clear
        echo -e "${gl_huang}>>> 找到 ${gl_lv}${#files[@]} ${gl_huang}个匹配 ${gl_bufan}${pattern}${gl_huang} 的文件:${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        for i in "${!files[@]}"; do
            local abs_path=$(readlink -f "${files[$i]}" 2>/dev/null || realpath "${files[$i]}" 2>/dev/null || echo "${files[$i]}")
            local file_size=$(du -h "${files[$i]}" 2>/dev/null | cut -f1)
            local file_date=$(date -r "${files[$i]}" "+%Y-%m-%d %H:%M" 2>/dev/null)

            if [[ ${#abs_path} -gt 60 ]]; then
                local part1="${abs_path:0:30}"
                local part2="${abs_path: -30}"
                printf "${gl_huang}%3d.${gl_bai} ${gl_lv}%s${gl_bai} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}${gl_lv}%s${gl_bai} ${gl_huang}%8s${gl_bai} ${gl_zi}%s${gl_bai}\n" \
                    $((i + 1)) \
                    "$part1" \
                    "$part2" \
                    "${file_size:-N/A}" \
                    "${file_date:-N/A}"
            else
                printf "${gl_huang}%3d.${gl_bai} ${gl_lv}%-60s${gl_bai} ${gl_huang}%8s${gl_bai} ${gl_zi}%s${gl_bai}\n" \
                    $((i + 1)) \
                    "$abs_path" \
                    "${file_size:-N/A}" \
                    "${file_date:-N/A}"
            fi
        done
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        echo -e ""
        echo -e "${gl_zi}>>> 处理搜索到的文件${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}复制独立文件        ${gl_bufan}2.  ${gl_bai}复制全部文件"
        echo -e "${gl_bufan}3.  ${gl_bai}移动独立文件        ${gl_bufan}4.  ${gl_bai}移动全部文件"
        echo -e "${gl_bufan}5.  ${gl_bai}删除独立文件        ${gl_bufan}6.  ${gl_bai}删除全部文件"
        echo -e "${gl_bufan}7.  ${gl_bai}预览文件内容        ${gl_bufan}8.  ${gl_bai}查看文件信息"
        echo -e "${gl_bufan}9.  ${gl_bai}批量重命名文件      ${gl_bufan}10. ${gl_bai}文件权限批量修改"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}11. ${gl_bai}切到文件所在目录    ${gl_bufan}12. ${gl_bai}下载文件到本地"
        echo -e "${gl_bufan}13. ${gl_bai}文件管理工具        ${gl_bufan}14. ${gl_bai}图片格式转换工具"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单      ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" choice

        case $choice in
        1) # 复制独立文件
            echo -e ""
            echo -e "${gl_zi}>>> 复制独立文件${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bai}请输入要复制的文件编号 (多个用空格分隔) (${gl_huang}0${gl_bai}返回): ")" indices

            case "$indices" in
            0) cancel_return "处理搜索到的文件"; continue ;;
            esac

            read -r -e -p "$(echo -e "${gl_bai}请输入目标目录: ")" target_dir

            if [[ ! -d "$target_dir" ]]; then
                read -r -e -p "$(echo -e "${gl_bai}目标目录不存在，是否创建? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" create_dir
                case "$create_dir" in
                [Yy])
                    mkdir -p "$target_dir" && log_ok "目录已创建: ${gl_bufan}$target_dir${gl_bai}" || {
                        log_error "创建目录失败！"
                        break_end
                        return 1
                    }
                    ;;
                [Nn])
                    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                    echo -e "${gl_huang}已取消安装${gl_bufan}mobufan${gl_huang}脚本${gl_bai}"
                    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
                    read -r -n 1 -s -r -p ""
                    continue # 返回菜单
                    ;;
                0) cancel_return "处理搜索到的文件"; continue ;;
                *) handle_y_n; continue ;;
                esac
            fi

            local copy_count=0
            for idx in $indices; do
                local file_idx=$((idx - 1))
                if [[ $file_idx -ge 0 && $file_idx -lt ${#files[@]} ]]; then
                    if cp "${files[$file_idx]}" "$target_dir/" 2>/dev/null; then
                        log_ok "已复制: ${gl_bufan}$(basename "${files[$file_idx]}")${gl_bai} -> ${gl_lv}$target_dir/${gl_bai}"
                        ((copy_count++))
                        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                        echo -e "${gl_lv}复制完成${gl_bai}"
                        echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
                        read -r -n 1 -s -r -p ""
                        continue # 完成后返回菜单
                    else
                        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                        echo -e "${gl_hong}复制复制失败: ${gl_bufan}${files[$file_idx]}${gl_bai}"
                        echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
                        read -r -n 1 -s -r -p ""
                        continue # 完成后返回菜单
                    fi
                fi
            done
            ;;
        2) # 复制全部文件
            echo -e ""
            echo -e "${gl_zi}>>> 复制全部文件${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bai}请输入目标目录 (${gl_huang}0${gl_bai}返回): ")" target_dir

            case "$target_dir" in
            0) cancel_return "处理搜索到的文件"; continue ;;
            esac

            if [[ ! -d "$target_dir" ]]; then
                read -r -e -p "$(echo -e "${gl_bai}目标目录不存在，是否创建? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" create_dir
                case "$create_dir" in
                [Yy])
                    mkdir -p "$target_dir" && log_ok "目录已创建: ${gl_bufan}$target_dir${gl_bai}" || {
                        log_error "创建目录失败！"
                        break_end
                        return 1
                    }
                    ;;
                [Nn])
                    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                    echo -e "${gl_huang}已取消安装${gl_bufan}mobufan${gl_huang}脚本${gl_bai}"
                    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
                    read -r -n 1 -s -r -p ""
                    continue # 返回菜单
                    ;;
                *)
                    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                    handle_y_n        # 无效的输入,请输入(y或N)。
                    continue # 返回菜单
                    ;;
                esac
            fi

            local copy_count=0
            for file in "${files[@]}"; do
                if cp "$file" "$target_dir/" 2>/dev/null; then
                    log_info "已复制: ${gl_bufan}$(basename "$file")${gl_bai}"
                    ((copy_count++))
                else
                    log_error "复制失败: ${gl_bufan}$file${gl_bai}"
                fi
            done
            if [[ $copy_count -gt 0 ]]; then
                log_ok "成功复制 ${copy_count}/${#files[@]} 个文件到: ${gl_bufan}$target_dir/${gl_bai}"
            fi
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_lv}复制完成${gl_bai}"
            echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
            read -r -n 1 -s -r -p ""
            continue # 完成后返回菜单
            ;;
        3) # 移动独立文件
            echo -e ""
            echo -e "${gl_zi}>>> 移动独立文件${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bai}请输入要移动的文件编号 (多个用空格分隔) (${gl_huang}0${gl_bai}返回): ")" indices

            case "$indices" in
            0) cancel_return "处理搜索到的文件"; continue ;;
            esac

            read -r -e -p "$(echo -e "${gl_bai}请输入目标目录: ")" target_dir

            if [[ ! -d "$target_dir" ]]; then
                read -r -e -p "$(echo -e "${gl_bai}目标目录不存在，是否创建? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" create_dir
                case "$create_dir" in
                [Yy])
                    mkdir -p "$target_dir" && log_ok "目录已创建: ${gl_bufan}$target_dir${gl_bai}" || {
                        log_error "创建目录失败！"
                        break_end
                        return 1
                    }
                    ;;
                [Nn])
                    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                    echo -e "${gl_huang}已取消安装${gl_bufan}mobufan${gl_huang}脚本${gl_bai}"
                    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
                    read -r -n 1 -s -r -p ""
                    continue # 返回菜单
                    ;;
                *)
                    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                    handle_y_n        # 无效的输入,请输入(y或N)。
                    continue # 返回菜单
                    ;;
                esac
            fi

            local sorted_indices=($(echo "$indices" | tr ' ' '\n' | sort -unr))
            local move_count=0

            for idx in "${sorted_indices[@]}"; do
                local file_idx=$((idx - 1))
                if [[ $file_idx -ge 0 && $file_idx -lt ${#files[@]} ]]; then
                    if mv "${files[$file_idx]}" "$target_dir/" 2>/dev/null; then
                        log_ok "已移动: ${gl_bufan}$(basename "${files[$file_idx]}")${gl_bai} -> ${gl_lv}$target_dir/${gl_bai}"
                        unset 'files[file_idx]' # 从数组中移除
                        ((move_count++))
                    else
                        log_error "移动失败: ${gl_bufan}${files[$file_idx]}${gl_bai}"
                    fi
                fi
            done

            files=("${files[@]}")

            if [[ $move_count -gt 0 ]]; then
                log_ok "成功移动 ${move_count} 个文件"
            fi

            if [[ ${#files[@]} -eq 0 ]]; then
                log_warn "所有文件已移动，返回上级菜单"
                exit_animation    # 即将退出动画
                break
            fi

            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_lv}移动完成${gl_bai}"
            echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
            read -r -n 1 -s -r -p ""
            continue # 完成后返回菜单（已刷新）
            ;;
        4) # 移动全部文件
            echo -e ""
            echo -e "${gl_zi}>>> 移动全部文件${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bai}请输入目标目录 (${gl_huang}0${gl_bai}返回): ")" target_dir

            case "$target_dir" in
            0) cancel_return "处理搜索到的文件"; continue ;;
            esac

            if [[ ! -d "$target_dir" ]]; then
                read -r -e -p "$(echo -e "${gl_bai}目标目录不存在，是否创建? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" create_dir
                case "$create_dir" in
                [Yy])
                    mkdir -p "$target_dir" && log_ok "目录已创建: ${gl_bufan}$target_dir${gl_bai}" || {
                        log_error "创建目录失败！"
                        break_end
                        return 1
                    }
                    ;;
                [Nn])
                    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                    echo -e "${gl_huang}已取消安装${gl_bufan}mobufan${gl_huang}脚本${gl_bai}"
                    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
                    read -r -n 1 -s -r -p ""
                    continue # 返回菜单
                    ;;
                *)
                    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                    handle_y_n        # 无效的输入,请输入(y或N)。
                    continue # 返回菜单
                    ;;
                esac
            fi

            local move_count=0
            for file in "${files[@]}"; do
                if mv "$file" "$target_dir/" 2>/dev/null; then
                    log_info "已移动: ${gl_bufan}$(basename "$file")${gl_bai}"
                    ((move_count++))
                else
                    log_error "移动失败: ${gl_bufan}$file${gl_bai}"
                fi
            done
            if [[ $move_count -gt 0 ]]; then
                log_ok "成功移动 ${move_count}/${#files[@]} 个文件到: ${gl_bufan}$target_dir/${gl_bai}"
            fi

            files=()
            break_end
            break # 退出菜单（无文件剩余）
            ;;
        5) # 删除独立文件
            echo -e ""
            echo -e "${gl_zi}>>> 删除独立文件${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bai}请输入要删除的文件编号 (多个用空格分隔) (${gl_huang}0${gl_bai}返回): ")" indices

            case "$indices" in
            0) cancel_return "处理搜索到的文件"; continue ;;
            esac

            echo -e "${gl_bai}${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_hong}警告：${gl_bai}以下文件将被删除："
            for idx in $indices; do
                local file_idx=$((idx - 1))
                if [[ $file_idx -ge 0 && $file_idx -lt ${#files[@]} ]]; then
                    echo -e "  ${gl_bufan}${files[$file_idx]}${gl_bai}"
                fi
            done
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

            read -r -e -p "$(echo -e "${gl_bai}确认删除这些文件? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm

            case "$confirm" in
            [Yy])
                local sorted_indices=($(echo "$indices" | tr ' ' '\n' | sort -unr))
                local delete_count=0

                for idx in "${sorted_indices[@]}"; do
                    local file_idx=$((idx - 1))
                    if [[ $file_idx -ge 0 && $file_idx -lt ${#files[@]} ]]; then
                        if rm -f "${files[$file_idx]}" 2>/dev/null; then
                            log_ok "已删除: ${gl_bufan}$(basename "${files[$file_idx]}")${gl_bai}"
                            unset 'files[file_idx]' # 从数组中移除已删除的文件
                            ((delete_count++))
                        else
                            log_error "删除失败: ${gl_bufan}${files[$file_idx]}${gl_bai}"
                        fi
                    fi
                done

                files=("${files[@]}")

                if [[ $delete_count -gt 0 ]]; then
                    log_ok "成功删除 ${delete_count} 个文件"
                    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                    echo -e "${gl_lv}删除完成${gl_bai}"
                    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
                    read -r -n 1 -s -r -p ""
                    continue # 完成后返回菜单（已刷新）
                fi

                if [[ ${#files[@]} -eq 0 ]]; then
                    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                    echo -e "${gl_lv}删除完成${gl_bai}"
                    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
                    read -r -n 1 -s -r -p ""
                    continue # 完成后返回菜单（已刷新）
                fi
                ;;
            [Nn])
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                echo -e "${gl_huang}已取消安装${gl_bufan}mobufan${gl_huang}脚本${gl_bai}"
                echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
                read -r -n 1 -s -r -p ""
                continue # 返回菜单
                ;;
            *)
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                handle_y_n        # 无效的输入,请输入(y或N)。
                continue # 返回菜单
                ;;
            esac
            ;;
        6) # 删除全部文件
            echo -e ""
            echo -e "${gl_zi}>>> 删除全部文件${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_hong}警告：${gl_bai}将删除所有 ${#files[@]} 个匹配的文件！"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

            read -r -e -p "$(echo -e "${gl_bai}确认删除所有找到的文件? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm

            case "$confirm" in
            [Yy])
                local delete_count=0
                for file in "${files[@]}"; do
                    if rm -f "$file" 2>/dev/null; then
                        log_info "已删除: ${gl_bufan}$(basename "$file")${gl_bai}"
                        ((delete_count++))
                    else
                        log_error "删除失败: ${gl_bufan}$file${gl_bai}"
                    fi
                done
                if [[ $delete_count -gt 0 ]]; then
                    log_ok "成功删除 ${delete_count}/${#files[@]} 个文件"
                fi
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                echo -e "${gl_lv}删除完成${gl_bai}"
                echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
                read -r -n 1 -s -r -p ""

                files=()
                continue # 返回菜单
                ;;
            [Nn])
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                echo -e "${gl_huang}已取消安装${gl_bufan}mobufan${gl_huang}脚本${gl_bai}"
                exit_animation    # 即将退出动画
                continue # 返回菜单
                ;;
            *)
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                handle_y_n        # 无效的输入,请输入(y或N)。
                continue # 返回菜单
                ;;
            esac
            ;;
        7) # 预览文件内容
            echo -e ""
            echo -e "${gl_zi}>>> 预览文件内容${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bai}请输入要预览的文件编号 (${gl_huang}0${gl_bai}返回): ")" idx

            case "$idx" in
            0) cancel_return "处理搜索到的文件"; continue ;;
            esac

            local file_idx=$((idx - 1))
            if [[ $file_idx -ge 0 && $file_idx -lt ${#files[@]} ]]; then
                local preview_file="${files[$file_idx]}"
                echo -e "${gl_bai}${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                echo -e "${gl_bai}预览文件: ${gl_huang}$preview_file${gl_bai}"
                echo -e "${gl_bai}文件大小: ${gl_lv}$(du -h "$preview_file" 2>/dev/null | cut -f1)${gl_bai}"
                echo -e "${gl_bai}最后修改: ${gl_zi}$(date -r "$preview_file" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)${gl_bai}"
                echo -e "${gl_bai}${gl_bufan}————————————————————————————————————————————————${gl_bai}"

                local file_type=$(file -b "$preview_file" 2>/dev/null)
                echo -e "${gl_bai}文件类型: ${gl_bufan}${file_type:-未知}${gl_bai}"

                if [[ -f "$preview_file" ]]; then
                    echo -e "${gl_bai}${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                    echo -e "${gl_bai}文件前 20 行内容:${gl_bai}"
                    echo -e "${gl_bai}${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                    head -n 20 "$preview_file" 2>/dev/null
                else
                    log_error "无法读取文件: ${gl_bufan}$preview_file${gl_bai}"
                fi
                echo -e "${gl_bai}${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
                read -r -n 1 -s -r -p ""
            else
                log_error "无效的文件编号！"
                echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
                read -r -n 1 -s -r -p ""
            fi
            continue # 预览完成后返回菜单
            ;;
        8) # 查看文件信息
            echo -e ""
            echo -e "${gl_zi}>>> 查看文件信息${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bai}请输入要查看的文件编号 (${gl_huang}0${gl_bai}返回): ")" idx

            case "$idx" in
            0) cancel_return "处理搜索到的文件"; continue ;;
            esac

            local file_idx=$((idx - 1))
            if [[ $file_idx -ge 0 && $file_idx -lt ${#files[@]} ]]; then
                local info_file="${files[$file_idx]}"
                echo -e "${gl_bai}${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                echo -e ""
                echo -e "${gl_huang}文件详细信息:${gl_bai}"
                echo -e "${gl_bai}${gl_bufan}————————————————————————————————————————————————${gl_bai}"

                if command -v stat &>/dev/null; then
                    echo -e "${gl_bai}文件名: ${gl_lv}$(basename "$info_file")${gl_bai}"
                    echo -e "${gl_bai}完整路径: ${gl_bufan}$info_file${gl_bai}"
                    echo -e "${gl_bai}文件大小: ${gl_zi}$(du -h "$info_file" 2>/dev/null | cut -f1)${gl_bai}"
                    echo -e "${gl_bai}文件类型: ${gl_bufan}$(file -b "$info_file" 2>/dev/null)${gl_bai}"
                    echo -e "${gl_bai}权限: ${gl_lv}$(stat -c "%A" "$info_file" 2>/dev/null)${gl_bai}"
                    echo -e "${gl_bai}所有者: ${gl_huang}$(stat -c "%U:%G" "$info_file" 2>/dev/null)${gl_bai}"
                    echo -e "${gl_bai}创建时间: ${gl_zi}$(stat -c "%w" "$info_file" 2>/dev/null)${gl_bai}"
                    echo -e "${gl_bai}修改时间: ${gl_zi}$(stat -c "%y" "$info_file" 2>/dev/null)${gl_bai}"
                    echo -e "${gl_bai}访问时间: ${gl_zi}$(stat -c "%x" "$info_file" 2>/dev/null)${gl_bai}"
                else
                    ls -la "$info_file" 2>/dev/null
                fi

                if [[ "$info_file" =~ \.(txt|sh|bash|zsh|py|js|html|css|json|xml|md|yml|yaml)$ ]]; then
                    echo -e "${gl_bai}文件编码: ${gl_lv}$(file -bi "$info_file" 2>/dev/null | grep -oP 'charset=\K[^;]+' || echo "未知")${gl_bai}"
                fi

                echo -e "${gl_bai}${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
                read -r -n 1 -s -r -p ""
            else
                echo -e "${gl_bai}${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                handle_y_n        # 无效的输入,请输入(y或N)。
                continue # 返回菜单
            fi
            continue # 查看完成后返回菜单
            ;;
        9) # 批量重命名文件
            echo -e ""
            echo -e "${gl_zi}>>> 批量重命名文件${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_bai}重命名模式：${gl_bai}"
            echo -e "${gl_bufan}1. ${gl_bai}添加前缀${gl_bai}        ${gl_bufan}2. ${gl_bai}添加后缀${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_bufan}3. ${gl_bai}替换字符串${gl_bai}      ${gl_bufan}4. ${gl_bai}序号重命名${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bai}请选择重命名模式 (${gl_huang}0${gl_bai}返回): ")" rename_mode

            case "$rename_mode" in
            0) cancel_return "处理搜索到的文件"; continue ;;
            1) # 添加前缀
                read -r -e -p "$(echo -e "${gl_bai}请输入要添加的前缀: ")" prefix
                local rename_count=0
                for file in "${files[@]}"; do
                    local filename=$(basename "$file")
                    local dir=$(dirname "$file")
                    local newname="${dir}/${prefix}${filename}"
                    if mv "$file" "$newname" 2>/dev/null; then
                        log_ok "已重命名: ${gl_bufan}${filename}${gl_bai} -> ${gl_lv}${prefix}${filename}${gl_bai}"
                        ((rename_count++))
                    fi
                done
                ;;
            2) # 添加后缀
                read -r -e -p "$(echo -e "${gl_bai}请输入要添加的后缀 (不含扩展名): ")" suffix
                local rename_count=0
                for file in "${files[@]}"; do
                    local filename=$(basename "$file")
                    local dir=$(dirname "$file")
                    local ext="${filename##*.}"
                    local name="${filename%.*}"
                    local newname="${dir}/${name}${suffix}.${ext}"
                    if [[ "$filename" == "$ext" ]]; then
                        newname="${dir}/${filename}${suffix}"
                    fi
                    if mv "$file" "$newname" 2>/dev/null; then
                        log_ok "已重命名: ${gl_bufan}${filename}${gl_bai} -> ${gl_lv}$(basename "$newname")${gl_bai}"
                        ((rename_count++))
                    fi
                done
                ;;
            3) # 替换字符串
                read -r -e -p "$(echo -e "${gl_bai}请输入要替换的字符串: ")" old_str
                read -r -e -p "$(echo -e "${gl_bai}请输入替换为的字符串: ")" new_str
                local rename_count=0
                for file in "${files[@]}"; do
                    local filename=$(basename "$file")
                    local dir=$(dirname "$file")
                    local newname="${dir}/${filename//$old_str/$new_str}"
                    if [[ "$filename" != "$(basename "$newname")" ]]; then
                        if mv "$file" "$newname" 2>/dev/null; then
                            log_ok "已重命名: ${gl_bufan}${filename}${gl_bai} -> ${gl_lv}$(basename "$newname")${gl_bai}"
                            ((rename_count++))
                        fi
                    fi
                done
                ;;
            4) # 序号重命名
                read -r -e -p "$(echo -e "${gl_bai}请输入文件名模板 (如: file-###.txt, ### 将被替换为序号): ")" template
                local rename_count=0
                local idx=1
                for file in "${files[@]}"; do
                    local dir=$(dirname "$file")
                    local ext="${file##*.}"
                    local newname="${dir}/${template//###/$(printf "%03d" $idx)}"
                    if [[ "$template" != *"###"* ]]; then
                        newname="${dir}/${template}_${idx}.${ext}"
                    fi
                    if mv "$file" "$newname" 2>/dev/null; then
                        log_ok "已重命名: ${gl_bufan}$(basename "$file")${gl_bai} -> ${gl_lv}$(basename "$newname")${gl_bai}"
                        ((rename_count++))
                    fi
                    ((idx++))
                done
                ;;
            *) handle_invalid_input ;;
            esac

            if [[ $rename_count -gt 0 ]]; then
                log_ok "成功重命名 ${rename_count} 个文件"
                files=()
                while IFS= read -r -d $'\0' file; do
                    files+=("$file")
                done < <(find "$search_path" -name "$pattern" -type f -print0 2>/dev/null)
                mapfile -t sorted_files < <(printf '%s\n' "${files[@]}" | sort)
                files=("${sorted_files[@]}")
            fi
            echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
            read -r -n 1 -s -r -p ""
            continue
            ;;
        10) # 文件权限批量修改
            echo -e ""
            echo -e "${gl_zi}>>> 批量修改文件权限${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_bai}权限设置：${gl_bai}"
            echo -e "${gl_bai}1. ${gl_lv}755${gl_bai} (rwxr-xr-x) - 可执行文件"
            echo -e "${gl_bai}2. ${gl_lv}644${gl_bai} (rw-r--r--) - 普通文件"
            echo -e "${gl_bai}3. ${gl_lv}600${gl_bai} (rw-------) - 敏感文件"
            echo -e "${gl_bai}4. ${gl_lv}777${gl_bai} (rwxrwxrwx) - 完全开放"
            echo -e "${gl_bai}5. ${gl_lv}自定义${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bai}请选择权限模式 (${gl_huang}0${gl_bai}返回): ")" perm_mode

            local chmod_val=""
            case "$perm_mode" in
            0) cancel_return "处理搜索到的文件"; continue ;;
            1) chmod_val="755" ;;
            2) chmod_val="644" ;;
            3) chmod_val="600" ;;
            4) chmod_val="777" ;;
            5)
                read -r -e -p "$(echo -e "${gl_bai}请输入权限值 (如: 755, 644): ")" chmod_val
                ;;
            *)
                handle_invalid_input
                continue
                ;;
            esac

            if [[ -n "$chmod_val" ]]; then
                local chmod_count=0
                for file in "${files[@]}"; do
                    if chmod "$chmod_val" "$file" 2>/dev/null; then
                        log_info "已修改权限: ${gl_bufan}$(basename "$file")${gl_bai} -> ${gl_lv}$chmod_val${gl_bai}"
                        ((chmod_count++))
                    else
                        log_error "修改失败: ${gl_bufan}$file${gl_bai}"
                    fi
                done
                if [[ $chmod_count -gt 0 ]]; then
                    log_ok "成功修改 ${chmod_count}/${#files[@]} 个文件的权限"
                fi
            fi
            echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
            read -r -n 1 -s -r -p ""
            continue
            ;;
        11) # 切换到文件目录
            echo -e ""
            echo -e "${gl_zi}>>> 切换到文件所在目录${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bai}请输入要切换目录的文件编号 (${gl_huang}0${gl_bai}返回): ")" idx

            case "$idx" in
            0) cancel_return "处理搜索到的文件"; continue ;;
            esac

            local file_idx=$((idx - 1))
            if [[ $file_idx -ge 0 && $file_idx -lt ${#files[@]} ]]; then
                local target_file="${files[$file_idx]}"
                local abs_path=$(readlink -f "$target_file" 2>/dev/null || realpath "$target_file" 2>/dev/null || echo "$target_file")
                local target_dir=$(dirname "$abs_path")

                if cd "$target_dir" 2>/dev/null; then
                    log_ok "已切换到目录: ${gl_lv}$target_dir${gl_bai}"
                else
                    log_error "切换目录失败: ${gl_huang}$target_dir${gl_bai}"
                fi
            else
                log_error "无效的文件编号！"
            fi
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            exit_animation    # 即将退出动画
            list_dir_colorful 0 4
            continue # 返回菜单
            ;;
        12) rz_download_files_to_local; continue ;;             # 下载文件到本地
        13) linux_file "." "处理搜索到的文件" "处理搜索到的文件";; # 文件管理工具
        14) image_converter_main "处理搜索到的文件" ;;            # 图片格式转换工具
        0) cancel_return; break ;;                              # 返回上一级选单
        00 | 000 | 0000) exit_script ;;
        *) handle_invalid_input ;;
        esac
    done

    return 0
}

duwatch() {
    local dir
    if [[ -n $1 ]]; then
        dir=$1
    else
        echo -e ""
        echo -e "${gl_zi}>>> 实时监控目录大小${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "输入要监控的目录 (默认当前目录): " dir
        dir=${dir:-.}
    fi

    if [[ ! -d $dir ]]; then
        echo -e "${gl_hong}目录不存在: ${gl_huang}$dir${gl_bai}" >&2
        exit_animation    # 即将退出动画
        return 1
    fi

    echo -e ""
    echo -e "${gl_bai}开始监控: ${gl_lv}$(realpath "$dir")  ${gl_bai}（${gl_huang}Ctrl-C 停止${gl_bai}）"
    if du -sb "$dir" 2>&1 | grep -q "权限不够"; then
        echo -e "${gl_huang}提示: 部分文件因权限无法访问，统计结果可能小于实际占用${gl_bai}"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    while :; do
        local size_mb
        size_mb=$(du -sb "$dir" 2>/dev/null | awk '{print $1/1024/1024}')

        if (($(echo "$size_mb > 1024" | bc -l 2>/dev/null || echo "0"))); then
            printf '%(%F %T)T\t%.2f GB\n' -1 "$(echo "$size_mb/1024" | bc -l)"
        else
            printf '%(%F %T)T\t%.3f MB\n' -1 "$size_mb"
        fi
        sleep_fractional 2
    done
}

remove_duplicate_files() {
    local search_path="."
    local method="md5"
    local total_files_count=0
    local duplicate_files_count=0
    local total_duplicate_size=0
    declare -gA duplicate_groups

    while true; do

        check_directory_empty "." "文件去重工具" "true" || return

        clear
        if [ -z "$(ls -A "$search_path" 2>/dev/null)" ]; then
            echo -e "${gl_huang}当前目录为空${gl_bai}"
        else
            cd ${search_path} && list_dir_colorful 0 4
        fi
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e ""
        echo -e "${gl_zi}>>> 文件去重工具${gl_bai}"

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}扫描重复文件      ${gl_bufan}2.  ${gl_bai}交互式删除重复文件"
        echo -e "${gl_bufan}3.  ${gl_bai}自动删除重复文件  ${gl_bufan}4.  ${gl_bai}切换去重方法 (当前: ${gl_lv}${method}${gl_bai})"
        echo -e "${gl_bufan}5.  ${gl_bai}设置搜索路径      ${gl_bufan}6.  ${gl_bai}查看扫描统计"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单    ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" choice

        case $choice in
        1) scan_duplicate_files ;;
        2) interactive_remove_duplicates ;;
        3) auto_remove_duplicates ;;
        4) switch_duplicate_method ;;
        5) set_duplicate_search_path ;;
        6) show_scan_statistics ;;
        0) cancel_return; break ;;                        # 返回上一级选单
        00 | 000 | 0000) exit_script ;;
        *) handle_invalid_input ;;
        esac
    done
}

scan_duplicate_files() {
    echo -e "${gl_bai}正在扫描重复文件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e ""

    if [[ "$method" == "md5" ]] && ! command -v md5sum &>/dev/null; then
        log_error "md5sum 命令未找到，请安装 coreutils 或使用其他去重方法"
        exit_animation    # 即将退出动画
        return 1
    elif [[ "$method" == "sha1" ]] && ! command -v sha1sum &>/dev/null; then
        log_error "sha1sum 命令未找到，请安装 coreutils 或使用其他去重方法"
        exit_animation    # 即将退出动画
        return 1
    fi

    get_duplicate_groups

    echo -e ""
    echo -e "${gl_zi}>>> 重复文件扫描结果${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if [[ ${#duplicate_groups[@]} -eq 0 ]]; then
        log_ok "未发现重复文件！"
        echo -e "${gl_bai}扫描路径: ${gl_lv}${search_path}${gl_bai}"
        echo -e "${gl_bai}去重方法: ${gl_huang}${method}${gl_bai}"
        echo -e "${gl_bai}文件总数: ${gl_lv}${total_files_count}${gl_bai}"
    else
        echo -e "${gl_bai}扫描路径: ${gl_lv}${search_path}${gl_bai}"
        echo -e "${gl_bai}去重方法: ${gl_huang}${method}${gl_bai}"
        echo -e "${gl_bai}文件总数: ${gl_lv}${total_files_count}${gl_bai}"
        echo -e "${gl_bai}重复文件: ${gl_hong}${duplicate_files_count}${gl_bai}"

        if [[ $duplicate_files_count -gt 0 ]]; then
            local duplicate_size_mb=$(echo "scale=2; $total_duplicate_size / 1024 / 1024" | bc 2>/dev/null || echo "0")
            echo -e "${gl_bai}浪费空间: ${gl_hong}${duplicate_size_mb} MB${gl_bai}"
        fi

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        local group_count=0
        for checksum in "${!duplicate_groups[@]}"; do
            IFS='|' read -ra files <<<"${duplicate_groups[$checksum]}"
            if [[ ${#files[@]} -gt 1 ]]; then
                group_count=$((group_count + 1))
                echo -e "${gl_huang}第 ${group_count} 组重复文件 (${#files[@]} 个):${gl_bai}"

                for i in "${!files[@]}"; do
                    local file="${files[$i]}"
                    if [[ -f "$file" ]]; then
                        local file_size=$(stat -c%s "$file" 2>/dev/null || echo 0)
                        local size_human=$(numfmt --to=iec --suffix=B "$file_size" 2>/dev/null || echo "${file_size}B")
                        local mtime=$(stat -c "%y" "$file" 2>/dev/null | cut -d'.' -f1 2>/dev/null || echo "未知")

                        if [[ $i -eq 0 ]]; then
                            echo -e "  ${gl_lv}✓ ${file}${gl_bai} (${size_human}, ${mtime}) - ${gl_lv}[保留建议]${gl_bai}"
                        else
                            echo -e "  ${gl_hui}${i}. ${file}${gl_bai} (${size_human}, ${mtime})"
                        fi
                    else
                        echo -e "  ${gl_hong}× ${file}${gl_bai} (文件不存在或无法访问)"
                    fi
                done
                echo -e ""
            fi
        done

        if [[ $group_count -eq 0 ]]; then
            log_ok "未发现重复文件！"
        else
            echo -e "${gl_bai}共发现 ${gl_hong}${group_count}${gl_bai} 组重复文件"
        fi
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n 1 -s -r -p ""
}

image_converter_main() {
    local menu_name="${1:-上一级选单}"
    while true; do
        install ffmpeg

        check_directory_empty "." "图片格式转换工具" "true" || return

        clear
        echo -e "${gl_zi}>>> 图片格式转换工具${gl_bai}(${gl_lv}$(pwd)${gl_bai})"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        local image_files=()
        local image_sizes=()
        image_converter_find_images image_files image_sizes

        if [[ ${#image_files[@]} -eq 0 ]]; then
            echo -e "${gl_huang}当前目录没有找到图片文件${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -ne "${gl_lv}即将退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
            sleep_fractional 0.5
            echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
            sleep_fractional 0.5
            return
        else
            image_converter_show_list image_files image_sizes
        fi

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}指定转${gl_bufan}JPG${gl_bai}格式       ${gl_bufan}2.  ${gl_bai}全部转${gl_bufan}JPG${gl_bai}格式"
        echo -e "${gl_bufan}3.  ${gl_bai}指定转${gl_bufan}PNG${gl_bai}格式       ${gl_bufan}4.  ${gl_bai}全部转${gl_bufan}PNG${gl_bai}格式"
        echo -e "${gl_bufan}5.  ${gl_bai}指定转${gl_bufan}WEBP${gl_bai}格式      ${gl_bufan}6.  ${gl_bai}全部转${gl_bufan}WEBP${gl_bai}格式"
        echo -e "${gl_bufan}7.  ${gl_bai}指定转${gl_bufan}BMP${gl_bai}格式       ${gl_bufan}8.  ${gl_bai}全部转${gl_bufan}BMP${gl_bai}格式"
        echo -e "${gl_bufan}9.  ${gl_bai}指定转${gl_bufan}JPEG${gl_bai}格式      ${gl_bufan}10. ${gl_bai}全部转${gl_bufan}JPEG${gl_bai}格式"
        echo -e "${gl_bufan}11. ${gl_bai}指定转${gl_bufan}GIF${gl_bai}格式       ${gl_bufan}12. ${gl_bai}全部转${gl_bufan}GIF${gl_bai}格式"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}13. ${gl_bai}质量压缩图片        ${gl_bufan}14. ${gl_bai}批量调整尺寸${gl_bai}"
        echo -e "${gl_bufan}15. ${gl_bai}批量重命名          ${gl_bufan}16. ${gl_bai}批量删除图片${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单      ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" choice

        case $choice in
        1)  image_converter_convert_selected "jpg" image_files ;;   # 指定转JPG格式
        2)  image_converter_batch_all "jpg" image_files ;;          # 全部转JPG格式
        3)  image_converter_convert_selected "png" image_files ;;   # 指定转PNG格式
        4)  image_converter_batch_all "png" image_files ;;          # 全部转PNG格式
        5)  image_converter_convert_selected "webp" image_files ;;  # 指定转WEBP格式
        6)  image_converter_batch_all "webp" image_files ;;         # 全部转WEBP格式
        7)  image_converter_convert_selected "bmp" image_files ;;   # 指定转BMP格式
        8)  image_converter_batch_all "bmp" image_files ;;          # 全部转BMP格式
        9)  image_converter_convert_selected "jpeg" image_files ;;  # 指定转JPEG格式
        10) image_converter_batch_all "jpeg" image_files ;;         # 全部转JPEG格式
        11) image_converter_convert_selected "gif" image_files ;;   # 指定转GIF格式
        12) image_converter_batch_all "gif" image_files ;;          # 全部转GIF格式
        13) image_converter_compress_quality image_files ;;         # 质量压缩图片
        14) image_converter_resize_batch image_files ;;             # 批量调整尺寸
        15) image_converter_batch_rename image_files ;;             # 批量重命名
        16) image_converter_batch_delete image_files ;;             # 批量删除图片
        0) cancel_return "$menu_name"; break ;;                     # 返回到上一级菜单
        00 | 000 | 0000) exit_script ;;                             # 感谢使用，再见！
        *) handle_invalid_input ;;                                  # 无效的输入,请重新输入!
        esac
    done
}

image_converter_find_images() {
    local -n files_ref=$1
    local -n sizes_ref=$2

    files_ref=()
    sizes_ref=()

    local exts=("jpg" "jpeg" "png" "bmp" "gif" "tiff" "tif" "webp" "heic" "JPG" "JPEG" "PNG" "BMP" "GIF" "TIFF" "TIF" "WEBP" "HEIC")

    for ext in "${exts[@]}"; do
        for file in *."$ext"; do
            if [[ -f "$file" ]] && [[ "$file" != *\* ]]; then
                files_ref+=("$file")
            fi
        done
    done

    if [[ ${#files_ref[@]} -gt 0 ]]; then
        IFS=$'\n' files_ref=($(printf '%s\n' "${files_ref[@]}" | sort))
        unset IFS
    fi

    for file in "${files_ref[@]}"; do
        if [[ -f "$file" ]]; then
            local size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo "0")
            if [[ $size -ge 1048576 ]]; then
                local size_display=$(echo "scale=1; $size/1048576" | bc 2>/dev/null || echo "0")M
            elif [[ $size -ge 1024 ]]; then
                local size_display=$(echo "scale=1; $size/1024" | bc 2>/dev/null || echo "0")K
            else
                local size_display="${size}B"
            fi
        else
            local size_display="未知"
        fi
        sizes_ref+=("$size_display")
    done
}

image_converter_show_list() {
    local -n files_ref=$1
    local -n sizes_ref=$2

    for i in "${!files_ref[@]}"; do
        local file="${files_ref[i]}"
        local resolution="未知"

        if command -v identify &>/dev/null; then
            resolution=$(identify -format "%wx%h" "$file" 2>/dev/null || echo "未知")
        elif command -v ffprobe &>/dev/null; then
            resolution=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$file" 2>/dev/null | tr ',' 'x' || echo "未知")
        elif [[ "$file" =~ \.(jpg|jpeg|png|gif|bmp|tiff|tif|webp)$ ]]; then
            resolution=$(file "$file" 2>/dev/null | grep -oE "[0-9]+ x [0-9]+" | head -1 | tr ' ' 'x' || echo "未知")
        fi

        if [[ "$resolution" == "" ]] || [[ "$resolution" == "x" ]]; then
            resolution="未知"
        fi

        printf "${gl_huang}%3d${gl_bai}.  ${gl_lv}%-25s${gl_bai}  ${gl_zi}%12s${gl_bai}  ${gl_lan}%8s${gl_bai}\n" \
            $((i + 1)) "${files_ref[i]}" "$resolution" "${sizes_ref[i]}"
    done
}

image_converter_convert_single() {
    local file="${1:-}"
    local format="${2:-}"

    if [[ ! -f "$file" ]]; then
        log_error "文件不存在: $file"
        return 1
    fi

    local filename=$(basename "$file")
    local name="${filename%.*}"

    local new_name="${name}.${format}"
    local count=1
    while [[ -f "$new_name" ]]; do
        new_name="${name}_${count}.${format}"
        count=$((count + 1))
    done

    log_info "开始转换: ${filename} → ${new_name}"

    if ffmpeg -i "$file" "$new_name" 2>/dev/null; then
        local input_size=$(du -h "$file" 2>/dev/null | cut -f1)
        local output_size=$(du -h "$new_name" 2>/dev/null | cut -f1)
        log_ok "转换成功"
        log_info "原文件: ${filename} (${input_size:-未知})"
        log_info "新文件: ${new_name} (${output_size:-未知})"
        return 0
    else
        log_error "转换失败: ${filename}"
        return 1
    fi
}

image_converter_batch_all() {
    local format="${1:-}"
    local -n files_ref=$2

    if [[ ${#files_ref[@]} -eq 0 ]]; then
        log_error "没有图片可转换"
        return
    fi

    echo ""
    log_info "开始批量转换全部图片为 ${format} 格式 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo ""

    local success=0
    local total=${#files_ref[@]}

    for i in "${!files_ref[@]}"; do
        local file="${files_ref[i]}"
        local progress=$(((i + 1) * 100 / total))

        printf "\r${gl_bai}处理中: [${gl_lv}%3d%%${gl_bai}] ${gl_huang}%d/${total}${gl_bai} - ${gl_lan}%s${gl_bai}" \
            "$progress" "$((i + 1))" "$file"

        if image_converter_convert_single "$file" "$format" >/dev/null 2>&1; then
            success=$((success + 1))
        fi
    done

    echo -e "\n\n${gl_bufan}————————————————————————${gl_bai}"
    log_ok "批量转换完成"
    log_info "成功: ${gl_lv}${success}${gl_bai} 个文件"
    if [[ $((total - success)) -gt 0 ]]; then
        log_warn "失败: ${gl_huang}$((total - success))${gl_bai} 个文件"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    break_end
}

image_converter_convert_selected() {
    local format="${1:-}"
    local -n files_ref=$2

    if [[ ${#files_ref[@]} -eq 0 ]]; then
        log_error "没有图片可选"
        return
    fi

    echo ""
    echo -e "${gl_bai}请选择要转换的图片序号${gl_bai}"
    echo -e "${gl_huang}支持: 单个序号, 多个用空格分隔, 范围用'-'连接${gl_bai}"
    echo -e "${gl_huang}示例: 1 3 5 或 2-5 或 1,3,7${gl_bai}"
    echo ""

    read -r -e -p "$(echo -e "${gl_bai}请输入你的选择 (${gl_huang}0${gl_bai}返回): ")" selection

    [[ -z "$selection" ]] && { cancel_empty "上一级选单"; return 1; }       # break 或 continue 或 return ，视上下文而定
    [[ "$selection" == "0" ]] && { cancel_return "上一级选单"; return; }    # break 或 continue 或 return ，视上下文而定

    local selected_files=()

    selection=$(echo "$selection" | tr ',' ' ')

    if [[ "$selection" =~ ^[0-9]+-[0-9]+$ ]]; then
        local start=${selection%-*}
        local end=${selection#*-}
        for ((i = start; i <= end; i++)); do
            if [[ $i -ge 1 ]] && [[ $i -le ${#files_ref[@]} ]]; then
                selected_files+=("${files_ref[$((i - 1))]}")
            fi
        done
    else
        for num in $selection; do
            if [[ $num =~ ^[0-9]+$ ]]; then
                if [[ $num -ge 1 ]] && [[ $num -le ${#files_ref[@]} ]]; then
                    selected_files+=("${files_ref[$((num - 1))]}")
                else
                    log_warn "序号 ${num} 无效"
                fi
            fi
        done
    fi

    if [[ ${#selected_files[@]} -eq 0 ]]; then
        log_error "没有选择有效的图片"
        return
    fi

    echo ""
    echo -e "${gl_bai}选择的图片:${gl_bai}"
    for file in "${selected_files[@]}"; do
        echo -e "  ${gl_lv}✓${gl_bai} $file"
    done
    echo ""

    read -r -e -p "$(echo -e "${gl_bai}确认转换这 ${#selected_files[@]} 个文件为 ${format} 格式? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "操作取消"
        return
    fi

    echo ""
    log_info "开始转换 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo ""

    local success=0
    local total=${#selected_files[@]}

    for i in "${!selected_files[@]}"; do
        local file="${selected_files[i]}"
        echo -e "${gl_huang}[$((i + 1))/$total]${gl_bai} 处理: $file"

        if image_converter_convert_single "$file" "$format"; then
            success=$((success + 1))
        fi
        echo ""
    done

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_ok "转换完成"
    log_info "成功: ${gl_lv}${success}${gl_bai} 个文件"
    if [[ $((total - success)) -gt 0 ]]; then
        log_warn "失败: ${gl_huang}$((total - success))${gl_bai} 个文件"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    break_end
}

image_converter_compress_quality() {
    local -n files_ref=$1

    if [[ ${#files_ref[@]} -eq 0 ]]; then
        log_error "没有图片可压缩"
        return
    fi

    echo ""
    echo -e "${gl_bai}请选择要压缩的图片序号${gl_bai}"
    echo -e "${gl_huang}支持: 单个序号, 多个用空格分隔, 范围用'-'连接${gl_bai}"
    echo -e "${gl_huang}示例: 1 3 5 或 2-5 或 1,3,7${gl_bai}"
    echo ""

    read -r -e -p "$(echo -e "${gl_bai}请输入你的选择 (${gl_huang}0${gl_bai}返回): ")" selection

    [[ -z "$selection" ]] && { cancel_empty "上一级选单"; return 1; }
    [[ "$selection" == "0" ]] && { cancel_return "上一级选单"; return 1; }

    local selected_files=()
    selection=$(echo "$selection" | tr ',' ' ')

    if [[ "$selection" =~ ^[0-9]+-[0-9]+$ ]]; then
        local start=${selection%-*}
        local end=${selection#*-}
        for ((i = start; i <= end; i++)); do
            if [[ $i -ge 1 ]] && [[ $i -le ${#files_ref[@]} ]]; then
                selected_files+=("${files_ref[$((i - 1))]}")
            fi
        done
    else
        for num in $selection; do
            if [[ $num =~ ^[0-9]+$ ]]; then
                if [[ $num -ge 1 ]] && [[ $num -le ${#files_ref[@]} ]]; then
                    selected_files+=("${files_ref[$((num - 1))]}")
                else
                    log_warn "序号 ${num} 无效"
                fi
            fi
        done
    fi

    if [[ ${#selected_files[@]} -eq 0 ]]; then
        log_error "没有选择有效的图片"
        return
    fi

    echo ""
    echo -e "${gl_bai}输入质量参数 (1-100, 默认85)${gl_bai}"
    echo -e "${gl_huang}数值越高质量越好, 文件越大${gl_bai}"

    read -r -e -p "$(echo -e "${gl_bai}请输入质量 (${gl_huang}1-100${gl_bai}): ")" quality
    quality=${quality:-85}

    if ! [[ "$quality" =~ ^[0-9]+$ ]] || [ "$quality" -lt 1 ] || [ "$quality" -gt 100 ]; then
        log_error "质量参数无效, 使用默认值85"
        quality=85
    fi

    echo ""
    echo -e "${gl_bai}选择的图片:${gl_bai}"
    for file in "${selected_files[@]}"; do
        echo -e "  ${gl_lv}✓${gl_bai} $file"
    done
    echo ""

    read -r -e -p "$(echo -e "${gl_bai}确认压缩这 ${#selected_files[@]} 个文件? 质量: ${quality} (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "操作取消"
        return
    fi

    local success=0
    local total=${#selected_files[@]}

    for i in "${!selected_files[@]}"; do
        local file="${selected_files[i]}"
        local filename=$(basename "$file")
        local extension="${filename##*.}"
        local name="${filename%.*}"
        local new_name="${name}_compressed.${extension}"
        local count=1

        while [[ -f "$new_name" ]]; do
            new_name="${name}_compressed_${count}.${extension}"
            count=$((count + 1))
        done

        echo -e "${gl_huang}[$((i + 1))/$total]${gl_bai} 压缩: $file"

        if ffmpeg -i "$file" -q:v "$quality" "$new_name" 2>/dev/null; then
            log_ok "压缩成功: $new_name"
            success=$((success + 1))
        else
            log_error "压缩失败: $file"
        fi
    done

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_ok "压缩完成"
    log_info "成功: ${gl_lv}${success}${gl_bai} 个文件"
    if [[ $((total - success)) -gt 0 ]]; then
        log_warn "失败: ${gl_huang}$((total - success))${gl_bai} 个文件"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    break_end
}

image_converter_resize_batch() {
    local -n files_ref=$1

    if [[ ${#files_ref[@]} -eq 0 ]]; then
        log_error "没有图片可调整"
        return
    fi

    echo ""
    echo -e "${gl_bai}请选择调整模式${gl_bai}"
    echo -e "${gl_bufan}1.  ${gl_bai}按宽度等比缩放"
    echo -e "${gl_bufan}2.  ${gl_bai}按高度等比缩放"
    echo -e "${gl_bufan}3.  ${gl_bai}按百分比缩放"
    echo -e "${gl_bufan}4.  ${gl_bai}指定宽度和高度"
    echo ""

    read -r -e -p "$(echo -e "${gl_bai}请输入模式 (${gl_huang}1-4${gl_bai}): ")" mode

    case $mode in
    1)
        read -r -e -p "$(echo -e "${gl_bai}请输入目标宽度: ")" width
        if ! [[ "$width" =~ ^[0-9]+$ ]]; then
            log_error "无效的宽度"
            return
        fi
        resize_cmd="-vf scale=${width}:-1"
        ;;
    2)
        read -r -e -p "$(echo -e "${gl_bai}请输入目标高度: ")" height
        if ! [[ "$height" =~ ^[0-9]+$ ]]; then
            log_error "无效的高度"
            return
        fi
        resize_cmd="-vf scale=-1:${height}"
        ;;
    3)
        read -r -e -p "$(echo -e "${gl_bai}请输入缩放百分比 (如50表示50%): ")" percent
        if ! [[ "$percent" =~ ^[0-9]+$ ]]; then
            log_error "无效的百分比"
            return
        fi
        local scale_percent=$(echo "scale=2; $percent/100" | bc)
        resize_cmd="-vf scale=iw*${scale_percent}:ih*${scale_percent}"
        ;;
    4)
        read -r -e -p "$(echo -e "${gl_bai}请输入目标宽度: ")" width
        read -r -e -p "$(echo -e "${gl_bai}请输入目标高度: ")" height
        if ! [[ "$width" =~ ^[0-9]+$ ]] || ! [[ "$height" =~ ^[0-9]+$ ]]; then
            log_error "无效的尺寸"
            return
        fi
        resize_cmd="-vf scale=${width}:${height}"
        ;;
    *)
        log_error "无效的模式"
        return
        ;;
    esac

    echo ""
    echo -e "${gl_bai}请选择要调整的图片${gl_bai}"
    echo -e "${gl_bai}输入 ${gl_lv}all${gl_bai} 批量处理所有图片"
    echo -e "${gl_bai}或输入序号 (用空格分隔, 如 1 3 5)${gl_bai}"

    read -r -e -p "$(echo -e "${gl_bai}请输入你的选择 (${gl_huang}0${gl_bai}返回): ")" selection

    [[ -z "$selection" ]] && { cancel_empty "上一级选单"; return 1; }        # break 或 continue 或 return ，视上下文而定
    [[ "$selection" == "0" ]] && { cancel_return "上一级选单"; return; }     # break 或 continue 或 return ，视上下文而定

    local selected_files=()

    if [[ "$selection" == "all" ]]; then
        selected_files=("${files_ref[@]}")
    else
        selection=$(echo "$selection" | tr ',' ' ')

        if [[ "$selection" =~ ^[0-9]+-[0-9]+$ ]]; then
            local start=${selection%-*}
            local end=${selection#*-}
            for ((i = start; i <= end; i++)); do
                if [[ $i -ge 1 ]] && [[ $i -le ${#files_ref[@]} ]]; then
                    selected_files+=("${files_ref[$((i - 1))]}")
                fi
            done
        else
            for num in $selection; do
                if [[ $num =~ ^[0-9]+$ ]]; then
                    if [[ $num -ge 1 ]] && [[ $num -le ${#files_ref[@]} ]]; then
                        selected_files+=("${files_ref[$((num - 1))]}")
                    else
                        log_warn "序号 ${num} 无效"
                    fi
                fi
            done
        fi
    fi

    if [[ ${#selected_files[@]} -eq 0 ]]; then
        log_error "没有选择有效的图片"
        return
    fi

    echo ""
    echo -e "${gl_bai}选择的图片:${gl_bai}"
    for file in "${selected_files[@]}"; do
        echo -e "  ${gl_lv}✓${gl_bai} $file"
    done
    echo ""

    read -r -e -p "$(echo -e "${gl_bai}确认调整这 ${#selected_files[@]} 个文件的尺寸? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "操作取消"
        return
    fi

    local success=0
    local total=${#selected_files[@]}

    for i in "${!selected_files[@]}"; do
        local file="${selected_files[i]}"
        local filename=$(basename "$file")
        local extension="${filename##*.}"
        local name="${filename%.*}"
        local new_name="${name}_resized.${extension}"
        local count=1

        while [[ -f "$new_name" ]]; do
            new_name="${name}_resized_${count}.${extension}"
            count=$((count + 1))
        done

        echo -e "${gl_huang}[$((i + 1))/$total]${gl_bai} 调整: $file"

        if ffmpeg -i "$file" $resize_cmd "$new_name" 2>/dev/null; then
            log_ok "调整成功: $new_name"
            success=$((success + 1))
        else
            log_error "调整失败: $file"
        fi
    done

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_ok "尺寸调整完成"
    log_info "成功: ${gl_lv}${success}${gl_bai} 个文件"
    if [[ $((total - success)) -gt 0 ]]; then
        log_warn "失败: ${gl_huang}$((total - success))${gl_bai} 个文件"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    break_end
}

image_converter_batch_rename() {
    local -n files_ref=$1

    if [[ ${#files_ref[@]} -eq 0 ]]; then
        log_error "没有图片可重命名"
        return
    fi

    echo ""
    echo -e "${gl_bai}批量重命名图片${gl_bai}"
    echo -e "${gl_huang}请输入新的文件名前缀${gl_bai}"
    echo -e "${gl_huang}示例: 输入 ${gl_bai}photo${gl_huang}, 会生成 ${gl_bai}photo_001.jpg, photo_002.png${gl_huang} 等${gl_bai}"

    read -r -e -p "$(echo -e "${gl_bai}请输入前缀 (${gl_huang}0${gl_bai}返回): ")" prefix

    [[ -z "$prefix" ]] && { cancel_empty "上一级选单"; return 1; }       # break 或 continue 或 return ，视上下文而定
    [[ "$prefix" == "0" ]] && { cancel_return "上一级选单"; return 1; }    # break 或 continue 或 return ，视上下文而定

    echo ""
    echo -e "${gl_bai}是否保持原扩展名?${gl_bai}"
    echo -e "${gl_huang}保持: 文件扩展名不变"
    echo -e "统一: 所有图片使用相同的扩展名${gl_bai}"
    echo ""
    echo -e "${gl_bufan}1.  ${gl_bai}保持原扩展名"
    echo -e "${gl_bufan}2.  ${gl_bai}统一为JPG格式"
    echo -e "${gl_bufan}3.  ${gl_bai}统一为PNG格式"
    echo -e "${gl_bufan}4.  ${gl_bai}统一为WEBP格式"
    echo ""

    read -r -e -p "$(echo -e "${gl_bai}请选择 (${gl_huang}1-4${gl_bai}): ")" ext_choice

    case $ext_choice in
    1) keep_original=true ;;
    2) target_ext="jpg" ;;
    3) target_ext="png" ;;
    4) target_ext="webp" ;;
    *)
        log_error "无效的选择"
        return
        ;;
    esac

    echo ""
    echo -e "${gl_bai}请选择要重命名的图片${gl_bai}"
    echo -e "${gl_bai}输入 ${gl_lv}all${gl_bai} 批量处理所有图片"
    echo -e "${gl_bai}或输入序号 (用空格分隔)${gl_bai}"

    read -r -e -p "$(echo -e "${gl_bai}请输入选择 (${gl_huang}0${gl_bai}返回): ")" selection

    [[ -z "$selection" ]] && { cancel_empty "上一级选单"; return 1; }      # break 或 continue 或 return ，视上下文而定
    [[ "$selection" == "0" ]] && { cancel_return "上一级选单"; return 1; } # break 或 continue 或 return ，视上下文而定

    local selected_files=()

    if [[ "$selection" == "all" ]]; then
        selected_files=("${files_ref[@]}")
    else
        selection=$(echo "$selection" | tr ',' ' ')

        if [[ "$selection" =~ ^[0-9]+-[0-9]+$ ]]; then
            local start=${selection%-*}
            local end=${selection#*-}
            for ((i = start; i <= end; i++)); do
                if [[ $i -ge 1 ]] && [[ $i -le ${#files_ref[@]} ]]; then
                    selected_files+=("${files_ref[$((i - 1))]}")
                fi
            done
        else
            for num in $selection; do
                if [[ $num =~ ^[0-9]+$ ]]; then
                    if [[ $num -ge 1 ]] && [[ $num -le ${#files_ref[@]} ]]; then
                        selected_files+=("${files_ref[$((num - 1))]}")
                    else
                        log_warn "序号 ${num} 无效"
                    fi
                fi
            done
        fi
    fi

    if [[ ${#selected_files[@]} -eq 0 ]]; then
        log_error "没有选择有效的图片"
        return
    fi

    echo ""
    echo -e "${gl_bai}选择的图片:${gl_bai}"
    for file in "${selected_files[@]}"; do
        echo -e "  ${gl_lv}✓${gl_bai} $file"
    done
    echo ""

    read -r -e -p "$(echo -e "${gl_bai}确认重命名这 ${#selected_files[@]} 个文件? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "操作取消"
        return
    fi

    local success=0
    local total=${#selected_files[@]}

    for i in "${!selected_files[@]}"; do
        local file="${selected_files[i]}"
        local filename=$(basename "$file")

        if [[ "$keep_original" == "true" ]]; then
            local extension="${filename##*.}"
        else
            local extension="$target_ext"
        fi

        local index=$(printf "%03d" $((i + 1)))
        local new_name="${prefix}_${index}.${extension}"
        local count=1

        while [[ -f "$new_name" ]]; do
            new_name="${prefix}_${index}_${count}.${extension}"
            count=$((count + 1))
        done

        echo -e "${gl_huang}[$((i + 1))/$total]${gl_bai} 重命名: $file → $new_name"

        if mv "$file" "$new_name" 2>/dev/null; then
            files_ref[$i]="$new_name"
            log_ok "重命名成功"
            success=$((success + 1))
        else
            log_error "重命名失败: $file"
        fi
    done

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_ok "重命名完成"
    log_info "成功: ${gl_lv}${success}${gl_bai} 个文件"
    if [[ $((total - success)) -gt 0 ]]; then
        log_warn "失败: ${gl_huang}$((total - success))${gl_bai} 个文件"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    break_end
}

image_converter_batch_delete() {
    local -n files_ref=$1

    if [[ ${#files_ref[@]} -eq 0 ]]; then
        log_error "没有图片可删除"
        return
    fi

    echo ""
    echo -e "${gl_bai}批量删除图片${gl_bai}"
    echo -e "${gl_hong}警告: 此操作不可恢复!${gl_bai}"
    echo ""
    echo -e "${gl_bai}请选择要删除的图片${gl_bai}"
    echo -e "${gl_bai}输入 ${gl_lv}all${gl_bai} 删除所有图片"
    echo -e "${gl_bai}或输入序号 (用空格分隔)${gl_bai}"

    read -r -e -p "$(echo -e "${gl_bai}请输入选择 (${gl_huang}0${gl_bai}返回): ")" selection

    [[ -z "$selection" ]] && { cancel_empty "上一级选单"; return 1; }      # break 或 continue 或 return ，视上下文而定
    [[ "$selection" == "0" ]] && { cancel_return "上一级选单"; return 1; } # break 或 continue 或 return ，视上下文而定

    local selected_files=()

    if [[ "$selection" == "all" ]]; then
        selected_files=("${files_ref[@]}")
    else
        selection=$(echo "$selection" | tr ',' ' ')

        if [[ "$selection" =~ ^[0-9]+-[0-9]+$ ]]; then
            local start=${selection%-*}
            local end=${selection#*-}
            for ((i = start; i <= end; i++)); do
                if [[ $i -ge 1 ]] && [[ $i -le ${#files_ref[@]} ]]; then
                    selected_files+=("${files_ref[$((i - 1))]}")
                fi
            done
        else
            for num in $selection; do
                if [[ $num =~ ^[0-9]+$ ]]; then
                    if [[ $num -ge 1 ]] && [[ $num -le ${#files_ref[@]} ]]; then
                        selected_files+=("${files_ref[$((num - 1))]}")
                    else
                        log_warn "序号 ${num} 无效"
                    fi
                fi
            done
        fi
    fi

    if [[ ${#selected_files[@]} -eq 0 ]]; then
        log_error "没有选择有效的图片"
        return
    fi

    echo ""
    echo -e "${gl_bai}将要删除的图片:${gl_bai}"
    for file in "${selected_files[@]}"; do
        echo -e "  ${gl_hong}✗${gl_bai} $file"
    done
    echo ""

    read -r -e -p "$(echo -e "${gl_hong}确认删除这 ${#selected_files[@]} 个文件? 此操作不可恢复! (${gl_hong}Y${gl_bai}/${gl_lv}n${gl_bai}): ")" confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]] && [[ -z "$confirm" ]]; then
        log_info "操作取消"
        return
    fi

    echo ""
    read -r -e -p "$(echo -e "${gl_hong}最后确认! 输入${gl_lv}confirm${gl_hong}以继续删除: ")" final_confirm
    if [[ "$final_confirm" != "confirm" ]]; then
        log_info "操作取消"
        return
    fi

    local success=0
    local total=${#selected_files[@]}

    for i in "${!selected_files[@]}"; do
        local file="${selected_files[i]}"
        echo -e "${gl_huang}[$((i + 1))/$total]${gl_bai} 删除: $file"

        if rm -f "$file" 2>/dev/null; then
            log_ok "删除成功"
            success=$((success + 1))
        else
            log_error "删除失败: $file"
        fi
    done

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_ok "删除完成"
    log_info "成功: ${gl_lv}${success}${gl_bai} 个文件"
    if [[ $((total - success)) -gt 0 ]]; then
        log_warn "失败: ${gl_huang}$((total - success))${gl_bai} 个文件"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    break_end
}

transfer_file_to_remote() {
    local file_to_transfer=""
    local remote_ip=""
    local remote_user=""
    local remote_password=""
    local remote_port=""
    local user_input=""
    
    clear
    
    if ! list_files "." 0 4; then
        echo -e "${gl_huang}当前目录没有可传输的文件${gl_bai}"
        exit_animation    # 即将退出动画
        return 1
    fi
    
    if [[ ${#LIST_FILES_ARRAY[@]} -eq 0 ]] || [[ "$LIST_FILES_COUNT" -eq 0 ]]; then
        echo -e "${gl_huang}当前目录没有可传输的文件${gl_bai}"
        exit_animation    # 即将退出动画
        return 1
    fi
    
    echo ""
    echo -e "${gl_zi}>>> 传送文件至远端服务器${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}输入序号选择文件，或直接输入文件路径 (${gl_huang}0${gl_bai}返回): ")" user_input
    
    [[ -z "$user_input" ]] && { cancel_empty "上一级选单"; return 1; }                       # break 或 continue 或 return ，视上下文而定
    [[ "$user_input" == "0" ]] && { cancel_return "文件管理器"; return 1; }      # break 或 continue 或 return ，视上下文而定
    
    if [[ "$user_input" =~ ^[0-9]+$ ]]; then
        local idx=$((user_input - 1))
        if ((idx >= 0 && idx < LIST_FILES_COUNT)); then
            file_to_transfer="${LIST_FILES_ARRAY[$idx]}"
            log_ok "已选择 [$user_input]: $file_to_transfer"
        else
            log_error "无效的序号: $user_input (有效范围: 1-$LIST_FILES_COUNT)"
            exit_animation    # 即将退出动画
            return 1
        fi
    else
        file_to_transfer="$user_input"
        if [[ ! -f "$file_to_transfer" ]]; then
            log_error "文件不存在: $file_to_transfer"
            exit_animation    # 即将退出动画
            return 1
        fi
        log_ok "已指定文件: $file_to_transfer"
    fi
    
    if [[ ! -f "$file_to_transfer" ]]; then
        log_error "无法访问文件: $file_to_transfer"
        exit_animation    # 即将退出动画
        return 1
    fi
    
    echo ""
    echo -e "${gl_bai}源文件: ${gl_huang}$file_to_transfer${gl_bai}"
    local file_size=$(du -h "$file_to_transfer" 2>/dev/null | cut -f1)
    echo -e "${gl_bai}文件大小: ${gl_huang}$file_size${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    read -r -e -p "$(echo -e "${gl_bai}请输入远端服务器IP: ")" remote_ip
    [ "$remote_ip" = "0" ] && { cancel_return "上一级选单"; return 1; }      # break 或 continue 或 return ，视上下文而定
    if [[ -z "$remote_ip" ]]; then
        log_error "远端服务器IP不能为空"
        exit_animation    # 即将退出动画
        return 1
    fi
    
    read -r -e -p "$(echo -e "${gl_bai}请输入远端服务器用户名 (${gl_lv}默认root${gl_bai}): ")" remote_user
    [ "$remote_user" = "0" ] && { cancel_return "上一级选单"; return 1; }      # break 或 continue 或 return ，视上下文而定
    remote_user=${remote_user:-root}
    
    read -r -e -p "$(echo -e "${gl_bai}请输入远端服务器密码: ")" -s remote_password
    [ "$remote_password" = "0" ] && { cancel_return "上一级选单"; return 1; }      # break 或 continue 或 return ，视上下文而定
    echo ""
    if [[ -z "$remote_password" ]]; then
        log_error "密码不能为空"
        exit_animation    # 即将退出动画
        return 1
    fi
    
    read -r -e -p "$(echo -e "${gl_bai}请输入登录端口 (${gl_lv}默认22${gl_bai}): ")" remote_port
    [ "$remote_port" = "0" ] && { cancel_return "上一级选单"; return 1; }      # break 或 continue 或 return ，视上下文而定
    remote_port=${remote_port:-22}
    
    echo ""
    echo -e "${gl_huang}传送信息确认:${gl_bai}"
    echo -e "${gl_bai}文件: ${gl_huang}$file_to_transfer${gl_bai}"
    echo -e "${gl_bai}目标: ${gl_huang}$remote_user@$remote_ip:$remote_port${gl_bai}"
    echo -e "${gl_bai}目标目录: ${gl_huang}/home/${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}确认执行传送吗? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
    [ "$confirm" = "0" ] && { cancel_return "上一级选单"; return 1; }      # break 或 continue 或 return ，视上下文而定
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_warn "已取消操作"
        exit_animation    # 即将退出动画
        return 1
    fi
    
    log_info "清理SSH已知主机记录 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    ssh-keygen -f "/root/.ssh/known_hosts" -R "$remote_ip" 2>/dev/null
    
    echo -e "${gl_bai}正在传送文件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    if scp -P "$remote_port" -o StrictHostKeyChecking=no -o ConnectTimeout=30 "$file_to_transfer" "$remote_user@$remote_ip:/home/" <<< "$remote_password"; then
        echo ""
        log_ok "文件传送成功"
        echo -e "${gl_bai}文件已传送至: ${gl_lv}$remote_user@$remote_ip:/home/$file_to_transfer${gl_bai}"
    else
        echo ""
        log_error "文件传送失败"
        echo -e "${gl_huang}可能原因:${gl_bai}"
        echo -e "  1. 网络连接失败"
        echo -e "  2. IP地址或端口错误"
        echo -e "  3. 用户名或密码错误"
        echo -e "  4. 远端服务器SSH服务未启动"
        echo -e "  5. 防火墙阻止连接"
        return 1
    fi
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
    return 0
}

select_and_display_file_info() {
    local target_dir="${1:-.}"
    local show_hidden="${2:-0}"
    local custom_cols="${3:-2}"
    
    LIST_CURRENT_DIR="$target_dir"
    
    clear
    if ! list_files "$target_dir" "$show_hidden" "$custom_cols"; then
        echo -e "${gl_lv}即将退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
        sleep_fractional 0.8
        return
    fi
    
    echo -e ""
    echo -e "${gl_huang}请选择操作：${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "  ${gl_lv}[1-${LIST_FILES_COUNT}]${gl_bai} 查看对应文件/目录详情"
    echo -e "  ${gl_lv}[r]${gl_bai} 刷新当前目录"
    echo -e "  ${gl_huang}[0]${gl_bai} 返回上一级选单"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    read -r -e -p "$(echo -e "${gl_bai}请输入你的选择(${gl_huang}0${gl_bai}返回): ")" user_choice
    
    case "$user_choice" in
        [1-9]|[1-9][0-9]|[1-9][0-9][0-9])
            if (( user_choice >= 1 && user_choice <= LIST_FILES_COUNT )); then
                local index=$((user_choice - 1))
                local selected_file="${LIST_FILES_ARRAY[$index]}"
                local full_path="${LIST_CURRENT_DIR%/}/${selected_file}"
                
                clear
                
                local absolute_path=$(realpath "$full_path" 2>/dev/null || echo "$full_path")
                echo -e ""
                echo -e "${gl_huang}📁 文件/目录信息${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                echo -e ""
                echo -e "${gl_lv}🔍 选中文件: ${gl_bai}${selected_file}"
                echo -e "${gl_lv}📁 相对路径: ${gl_bai}${full_path}"
                echo -e "${gl_lv}📍 绝对路径: ${gl_bai}${absolute_path}"
                echo -e ""
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                
                display_file_info "$full_path" "true"
                
                echo -e ""
                echo -e "${gl_huang}操作菜单：${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                echo -e "  ${gl_lv}[enter]${gl_bai} 返回文件列表"
                echo -e "  ${gl_lv}[e]${gl_bai} 编辑文件"
                echo -e "  ${gl_huang}[0]${gl_bai} 返回上一级选单"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                
                read -rp "$(echo -e ${gl_bai}"请输入你的选择: "${gl_bai})" file_action
                
                case "$file_action" in
                    "")
                        clear
                        select_and_display_file_info "$target_dir" "$show_hidden" "$custom_cols"
                        ;;
                    "e"|"E")
                        if [ -f "$full_path" ]; then
                            if command -v nano &>/dev/null; then
                                nano "$full_path"
                            elif command -v vi &>/dev/null; then
                                vi "$full_path"
                            elif command -v vim &>/dev/null; then
                                vim "$full_path"
                            else
                                echo -e "${gl_hong}未找到可用的编辑器${gl_bai}"
                                read -n1 -rp "$(echo -e ${gl_huang}"按任意键继续{gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"${gl_bai})"
                            fi
                        else
                            echo -e "${gl_hong}不能编辑目录${gl_bai}"
                            read -n1 -rp "$(echo -e ${gl_huang}"按任意键继续{gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"${gl_bai})"
                        fi
                        clear
                        select_and_display_file_info "$target_dir" "$show_hidden" "$custom_cols"
                        ;;
                    0)  create_directory || return 0 ;;
                    *)
                        clear
                        select_and_display_file_info "$target_dir" "$show_hidden" "$custom_cols"
                        ;;
                esac
            else
                echo -e "${gl_hong}无效的选择序号${gl_bai}"
                read -n1 -rp "$(echo -e ${gl_huang}"按任意键继续{gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"${gl_bai})"
                clear
                select_and_display_file_info "$target_dir" "$show_hidden" "$custom_cols"
            fi
            ;;
        "r"|"R")
            clear
            select_and_display_file_info "$target_dir" "$show_hidden" "$custom_cols"
            ;;
        0) cancel_return; return 0 ;;    # 返回到上一级菜单
        *)
            echo -e "${gl_hong}无效的选择${gl_bai}"
            read -n1 -rp "$(echo -e ${gl_huang}"按任意键继续{gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"${gl_bai})"
            clear
            select_and_display_file_info "$target_dir" "$show_hidden" "$custom_cols"
            ;;
    esac
    
    return 0
}

show_directory_tree() {
    install tree
    check_directory_empty "." "生成目录树" "true" || return
    clear
    echo -e "${gl_zi}当前 ${gl_huang}$(pwd)${gl_zi} 目录树${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    tree . 2>/dev/null || find . -print | sed -e 's;[^/]*/;|____;g;s;____|; |;g'
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

interactive_delete() {
    echo -e ""

    if [[ -z "$TRASH_CMD" ]]; then
        install_trash
    fi

    while true; do
        check_directory_empty "." "删除模式" "true" || return

        clear

        if ! list_files "." 0 4; then
            exit_animation    # 即将退出动画
            return 1
        fi

        if [[ ${#LIST_FILES_ARRAY[@]} -eq 0 ]] || [[ "$LIST_FILES_COUNT" -eq 0 ]]; then
            exit_animation    # 即将退出动画
            return 1
        fi
        local list=("${LIST_FILES_ARRAY[@]}")

        echo -e ""
        echo -e "${gl_zi}>>> 删除模式${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入序号 (多选用空格分隔) (${gl_huang}0 ${gl_bai}返回, ${gl_hong}c${gl_bai} 清空目录): ")" -e raw

        [ -z "$raw" ] && { cancel_empty "上一级选单"; return 1; }        # break 或 continue 或 return ，视上下文而定
        [ "$raw" = "0" ] && { cancel_return "上一级选单"; return 1; }   # break 或 continue 或 return ，视上下文而定

        if [[ $raw == "c" || $raw == "C" ]]; then
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_hong}⚠ 警告：您选择了清空当前目录！${gl_bai}"
            echo -e "${gl_huang}当前目录 ${gl_lv}$(pwd) ${gl_bai}下共有 ${gl_lv}${#list[@]}${gl_bai} 个文件/目录"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

            echo -e "${gl_huang}将要删除以下所有内容：${gl_bai}"
            for item in "${list[@]}"; do
                if [[ -d "$item" ]]; then
                    echo -e "  ${gl_bai}目录: ${gl_zi}$item${gl_bai}"
                else
                    echo -e "  ${gl_bai}文件: ${gl_lv}$item${gl_bai}"
                fi
            done
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

            read -r -e -p "$(echo -e "${gl_bai}确认要清空当前目录吗？(输入 ${gl_hong}yes${gl_bai} 确认): ")" confirm_response

            if [[ $confirm_response == "yes" ]]; then
                local ok=0 fail=0

                for item in "${list[@]}"; do
                    if [[ -n "$TRASH_CMD" ]]; then
                        if delete_file_with_trash "$item"; then
                            ((ok++))
                        else
                            ((fail++))
                        fi
                    else
                        if delete_file_with_trash "$item"; then
                            ((ok++))
                        else
                            ((fail++))
                        fi
                    fi
                done

                if [[ -n "$TRASH_CMD" ]]; then
                    if ((ok > 0)); then
                        echo -e "${gl_lv}✓ 成功移动 ${gl_huang}$ok${gl_bai} 项到回收站${gl_bai}"
                    fi
                    if ((fail > 0)); then
                        echo -e "${gl_hong}✗ $fail 项移动失败${gl_bai}"
                    fi
                else
                    if ((ok > 0)); then
                        echo -e "${gl_lv}✓ 成功删除 ${gl_huang}$ok${gl_bai} 项${gl_bai}"
                    fi
                    if ((fail > 0)); then
                        echo -e "${gl_hong}✗ $fail 项删除失败${gl_bai}"
                    fi
                fi
            else
                echo -e "${gl_huang}已取消清空目录操作${gl_bai}"
            fi

            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            continue
        fi

        local to_del=() tok idx
        read -r -a tokens <<<"$raw"

        for tok in "${tokens[@]}"; do
            [[ -z "$tok" ]] && continue

            if [[ $tok =~ ^[0-9]+$ ]] && ((tok >= 1 && tok <= ${#list[@]})); then
                local selected_item="${list[$((tok - 1))]}"
                [[ -e "$selected_item" ]] && to_del+=("$selected_item")
                continue
            fi

            local glob_result=()
            shopt -s nullglob
            glob_result=($tok) # 故意不加双引号，让 bash 展开
            shopt -u nullglob

            if ((${#glob_result[@]})); then
                for item in "${glob_result[@]}"; do
                    [[ "$item" == ./* ]] && item="${item#./}"
                    [[ -e "$item" ]] && to_del+=("$item")
                done
                continue
            fi

            if [[ -e "$tok" ]]; then
                to_del+=("$tok")
            else
                echo -e "${gl_hong}跳过无效输入或文件不存在: $tok${gl_bai}"
            fi
        done
        ((${#to_del[@]} == 0)) && {
            echo -e "${gl_huang}没有有效的文件可删除${gl_bai}"
            exit_animation    # 即将退出动画
            continue
        }

        echo
        echo -e "${gl_huang}>>> 即将删除以下 ${gl_bufan}${#to_del[@]}${gl_bai} ${gl_huang}项："
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        for item in "${to_del[@]}"; do
            echo -e "  ${gl_lv}$item${gl_bai}"
        done

        local confirm_response
        if [[ -n "$TRASH_CMD" ]]; then
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bai}确认移动到回收站? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm_response
        else
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bai}确认永久删除? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm_response
        fi

        [[ $confirm_response =~ ^[Yy]$ ]] || {
            echo -e "${gl_huang}操作已取消${gl_bai}"
            exit_animation    # 即将退出动画
            continue
        }

        local ok=0 fail=0
        for item in "${to_del[@]}"; do
            if [[ -n "$TRASH_CMD" ]]; then
                if delete_file_with_trash "$item"; then
                    ((ok++))
                else
                    ((fail++))
                fi
            else
                if delete_file_with_trash "$item"; then
                    ((ok++))
                else
                    ((fail++))
                fi
            fi
        done

        if [[ -n "$TRASH_CMD" ]]; then
            if ((ok > 0)); then
                echo -e "${gl_lv}✓ 成功移动 ${gl_huang}$ok${gl_bai} 项到回收站${gl_bai}"
            fi
            if ((fail > 0)); then
                echo -e "${gl_hong}✗ $fail 项移动失败${gl_bai}"
            fi
        else
            if ((ok > 0)); then
                echo -e "${gl_lv}✓ 成功删除 ${gl_huang}$ok${gl_bai} 项${gl_bai}"
            fi
            if ((fail > 0)); then
                echo -e "${gl_hong}✗ $fail 项删除失败${gl_bai}"
            fi
        fi

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
    done
}

check_rm_redirect_silent() {
    local user_shell=$(basename "$SHELL")
    local config_file=""

    case "$user_shell" in
    bash)
        config_file="$HOME/.bashrc"
        ;;
    zsh)
        config_file="$HOME/.zshrc"
        ;;
    *)
        return
        ;;
    esac

    if grep -q "alias rm=" "$config_file" 2>/dev/null; then
        echo -e "${gl_bufan}rm  重定向: ${gl_lv}已启用${gl_bai}"
    else
        echo -e "${gl_bufan}rm  重定向: ${gl_hui}未启用${gl_bai}"
    fi
}

show_trash_contents_and_stats() {
    if [[ -z "$TRASH_CMD" ]]; then
        echo -e "${gl_huang}回收站未启用${gl_bai}"
        return
    fi

    local trash_json=$(get_trash_list)
    local item_count=0
    local total_files=0
    local total_dirs=0
    local total_size=0

    if command -v jq &>/dev/null; then
        item_count=$(echo "$trash_json" | jq length)
    else
        item_count=$(echo "$trash_json" | grep -o '"index"' | wc -l)
    fi

    if [[ $item_count -eq 0 ]]; then
        echo -e "${gl_huang}回收站为空${gl_bai}"
        return
    fi

    echo -e "${gl_huang}回收站中的文件:${gl_bai}"
    echo

    local files=()
    local actual_items=0

    if command -v jq &>/dev/null; then
        while IFS= read -r line; do
            files+=("$line")
            ((actual_items++))
        done < <(echo "$trash_json" | jq -r '.[] | "\(.index). \(.name)"')
    else
        local index=1
        if [[ "$TRASH_CMD" == "gio trash" ]]; then
            local trash_dir="$HOME/.local/share/Trash/files"
            if [[ -d "$trash_dir" ]]; then
                for item in "$trash_dir"/*; do
                    if [[ -e "$item" ]]; then
                        local filename=$(basename "$item")
                        files+=("$index. $filename")
                        ((index++))
                        ((actual_items++))
                    fi
                done
            fi
        elif [[ "$TRASH_CMD" == "trash-put" ]] && command -v trash-list &>/dev/null; then
            while IFS= read -r line; do
                if [[ -n "$line" ]]; then
                    local filename=$(echo "$line" | awk '{$1=$2=""; print substr($0,3)}' | sed 's/^ *//' | xargs basename)
                    files+=("$index. $filename")
                    ((index++))
                    ((actual_items++))
                fi
            done < <(trash-list 2>/dev/null)
        fi
    fi

    if [[ ${actual_items} -eq 0 ]]; then
        echo -e "${gl_huang}回收站为空${gl_bai}"
        return
    fi

    local count=0
    local items_per_line=4 # 每行显示4个项目
    local max_length=0

    for file in "${files[@]}"; do
        local len=${#file}
        if [ "$len" -gt "$max_length" ]; then
            max_length=$len
        fi
    done

    max_length=$((max_length + 4)) # 增加一些间距

    for i in "${!files[@]}"; do
        count=$((count + 1))
        printf "${gl_bufan}%2d.${gl_bai} %-${max_length}s" "$count" "${files[i]#*. }"

        if [ $((count % items_per_line)) -eq 0 ]; then
            echo ""
        fi
    done

    if [ $((count % items_per_line)) -ne 0 ]; then
        echo ""
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    echo -e "${gl_huang}统计信息:${gl_bai}"

    if [[ "$TRASH_CMD" == "gio trash" ]]; then
        local trash_dir="$HOME/.local/share/Trash/files"
        if [[ -d "$trash_dir" ]]; then
            total_files=0
            total_dirs=0

            for item in "$trash_dir"/*; do
                if [[ -e "$item" ]]; then
                    if [[ -f "$item" ]] || [[ -L "$item" ]]; then
                        ((total_files++))
                    elif [[ -d "$item" ]]; then
                        ((total_dirs++))
                    fi
                fi
            done

            if [[ $total_files -gt 0 || $total_dirs -gt 0 ]]; then
                total_size=$(du -sb "$trash_dir" 2>/dev/null | cut -f1)
                if [[ $total_size -ge 1073741824 ]]; then
                    total_size_display=$(echo "scale=2; $total_size / 1073741824" | bc 2>/dev/null)GB
                elif [[ $total_size -ge 1048576 ]]; then
                    total_size_display=$(echo "scale=2; $total_size / 1048576" | bc 2>/dev/null)MB
                elif [[ $total_size -ge 1024 ]]; then
                    total_size_display=$(echo "scale=2; $total_size / 1024" | bc 2>/dev/null)KB
                else
                    total_size_display="${total_size}B"
                fi
            fi

            echo -e "  ${gl_bai}项目总数:${gl_bai} ${gl_huang}${actual_items}${gl_bai}"
            echo -e "  ${gl_bai}文件数量:${gl_bai} ${gl_huang}${total_files}${gl_bai}"
            echo -e "  ${gl_bai}目录数量:${gl_bai} ${gl_huang}${total_dirs}${gl_bai}"
            if [[ -n "$total_size_display" ]]; then
                echo -e "  ${gl_bai}大小总计:${gl_bai} ${gl_huang}${total_size_display}${gl_bai}"
            fi
        fi
    elif [[ "$TRASH_CMD" == "trash-put" ]]; then
        local trash_dir=""
        local trash_paths=(
            "$HOME/.local/share/Trash/files"
            "$HOME/.local/share/trash/files"
            "/tmp/.Trash-$(id -u)/files"
        )

        for trash_path in "${trash_paths[@]}"; do
            if [[ -d "$trash_path" ]]; then
                trash_dir="$trash_path"
                break
            fi
        done

        if [[ -n "$trash_dir" ]] && [[ -d "$trash_dir" ]]; then
            total_files=0
            total_dirs=0

            for item in "$trash_dir"/*; do
                if [[ -e "$item" ]]; then
                    if [[ -f "$item" ]] || [[ -L "$item" ]]; then
                        ((total_files++))
                    elif [[ -d "$item" ]]; then
                        ((total_dirs++))
                    fi
                fi
            done

            if [[ $total_files -gt 0 || $total_dirs -gt 0 ]]; then
                total_size=$(du -sb "$trash_dir" 2>/dev/null | cut -f1)
                if [[ $total_size -ge 1073741824 ]]; then
                    total_size_display=$(echo "scale=2; $total_size / 1073741824" | bc 2>/dev/null)GB
                elif [[ $total_size -ge 1048576 ]]; then
                    total_size_display=$(echo "scale=2; $total_size / 1048576" | bc 2>/dev/null)MB
                elif [[ $total_size -ge 1024 ]]; then
                    total_size_display=$(echo "scale=2; $total_size / 1024" | bc 2>/dev/null)KB
                else
                    total_size_display="${total_size}B"
                fi
            fi

            echo -e "  ${gl_bufan}项目总数:${gl_bai} ${gl_huang}${actual_items}${gl_bai}"
            echo -e "  ${gl_bufan}文件数量:${gl_bai} ${gl_huang}${total_files}${gl_bai}"
            echo -e "  ${gl_bufan}目录数量:${gl_bai} ${gl_huang}${total_dirs}${gl_bai}"
            if [[ -n "$total_size_display" ]]; then
                echo -e "  ${gl_bufan}总大小:${gl_bai} ${gl_huang}${total_size_display}${gl_bai}"
            fi
        else
            if command -v trash-list &>/dev/null; then
                local trash_output=$(trash-list 2>/dev/null)
                if [[ -n "$trash_output" ]]; then
                    local line_count=$(echo "$trash_output" | wc -l)
                    echo -e "  ${gl_bufan}项目总数:${gl_bai} ${gl_huang}${line_count}${gl_bai}"

                    for trash_path in "$HOME/.local/share/Trash" "$HOME/.local/share/trash"; do
                        if [[ -d "$trash_path/files" ]]; then
                            total_size=$(du -sb "$trash_path/files" 2>/dev/null | cut -f1)
                            if [[ -n "$total_size" ]] && [[ $total_size -gt 0 ]]; then
                                if [[ $total_size -ge 1073741824 ]]; then
                                    total_size_display=$(echo "scale=2; $total_size / 1073741824" | bc 2>/dev/null)GB
                                elif [[ $total_size -ge 1048576 ]]; then
                                    total_size_display=$(echo "scale=2; $total_size / 1048576" | bc 2>/dev/null)MB
                                elif [[ $total_size -ge 1024 ]]; then
                                    total_size_display=$(echo "scale=2; $total_size / 1024" | bc 2>/dev/null)KB
                                else
                                    total_size_display="${total_size}B"
                                fi
                                echo -e "  ${gl_bufan}总大小:${gl_bai} ${gl_huang}${total_size_display}${gl_bai}"
                                break
                            fi
                        fi
                    done
                fi
            else
                echo -e "  ${gl_bufan}项目总数:${gl_bai} ${gl_huang}${actual_items}${gl_bai}"
                echo -e "  ${gl_huang}(无法获取详细统计信息)${gl_bai}"
            fi
        fi
    fi

}

TRASH_CONFIG_FILE="$HOME/.trash_config"

save_trash_config() {
    local config_content=""
    if [[ -n "$TRASH_CMD" ]]; then
        config_content="TRASH_CMD=\"$TRASH_CMD\""
    else
        config_content="TRASH_CMD=\"\""
    fi

    echo "# 回收站配置文件" >"$TRASH_CONFIG_FILE"
    echo "# 最后更新时间: $(date '+%Y-%m-%d %H:%M:%S')" >>"$TRASH_CONFIG_FILE"
    echo "" >>"$TRASH_CONFIG_FILE"
    echo "$config_content" >>"$TRASH_CONFIG_FILE"

    chmod 600 "$TRASH_CONFIG_FILE" 2>/dev/null
}

load_trash_config() {
    if [[ -f "$TRASH_CONFIG_FILE" ]]; then
        source "$TRASH_CONFIG_FILE" 2>/dev/null || {
            echo -e "${gl_huang}回收站配置文件加载失败，将重新检测${gl_bai}"
            TRASH_CMD=""
        }

        if [[ -n "$TRASH_CMD" ]]; then
            if [[ "$TRASH_CMD" == "gio trash" ]]; then
                if ! command -v gio &>/dev/null; then
                    echo -e "${gl_huang}配置的回收站工具 gio 不可用，重新检测${gl_bai}"
                    TRASH_CMD=""
                fi
            elif [[ "$TRASH_CMD" == "trash-put" ]]; then
                if ! command -v trash-put &>/dev/null; then
                    echo -e "${gl_huang}配置的回收站工具 trash-put 不可用，重新检测${gl_bai}"
                    TRASH_CMD=""
                fi
            else
                if ! eval "$TRASH_CMD --help" &>/dev/null && ! eval "$TRASH_CMD -h" &>/dev/null; then
                    echo -e "${gl_huang}配置的回收站工具可能不可用，重新检测${gl_bai}"
                    TRASH_CMD=""
                fi
            fi
        fi
    else
        TRASH_CMD=""
    fi
}

install_trash() {
    local trash_cmd=""

    load_trash_config

    if [[ -n "$TRASH_CMD" ]]; then
        echo -e "${gl_lv}已加载回收站配置: $TRASH_CMD${gl_bai}"
        return 0
    fi

    if command -v trash-put &>/dev/null; then
        trash_cmd="trash-put"
        echo -e "${gl_lv}检测到已安装 trash-cli 回收站工具${gl_bai}"
    elif command -v gio &>/dev/null; then
        trash_cmd="gio trash"
        echo -e "${gl_lv}检测到已安装 gio 回收站工具${gl_bai}"
    else
        log_warn "未找到回收站工具，正在尝试安装 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

        if command -v apt &>/dev/null; then
            log_warn "${gl_lan}检测到 Debian/Ubuntu 系统，安装 trash-cli ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            sudo apt update && sudo apt install -y trash-cli
            if command -v trash-put &>/dev/null; then
                trash_cmd="trash-put"
            fi
        elif command -v yum &>/dev/null; then
            log_warn "${gl_lan}检测到 CentOS/RHEL 系统，安装 trash-cli ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            sudo yum install -y trash-cli
            if command -v trash-put &>/dev/null; then
                trash_cmd="trash-put"
            fi
        elif command -v dnf &>/dev/null; then
            log_warn "${gl_lan}检测到 Fedora 系统，安装 trash-cli ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            sudo dnf install -y trash-cli
            if command -v trash-put &>/dev/null; then
                trash_cmd="trash-put"
            fi
        elif command -v pacman &>/dev/null; then
            log_warn "${gl_lan}检测到 Arch Linux 系统，安装 trash-cli ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            sudo pacman -S --noconfirm trash-cli
            if command -v trash-put &>/dev/null; then
                trash_cmd="trash-put"
            fi
        else
            log_error "${gl_hong}无法自动安装回收站工具，请手动安装 trash-cli${gl_bai}"
            return 1
        fi
    fi

    if [[ -n "$trash_cmd" ]]; then
        TRASH_CMD="$trash_cmd"
        save_trash_config
        log_warn "回收站功能已启用并保存配置: ${gl_lv}$TRASH_CMD${gl_bai}"
        return 0
    else
        log_error "回收站工具安装失败"
        return 1
    fi
}

auto_setup_trash() {
    echo -e "${gl_zi}>>> 正在自动初始化回收站 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    if [[ -z "$TRASH_CMD" ]]; then
        if install_trash; then
            log_ok "回收站初始化成功"
        else
            log_error "回收站初始化失败"
            exit_animation
            return 1
        fi
    else
        echo -e "${gl_lv}回收站已初始化: $TRASH_CMD${gl_bai}"
    fi

    local user_shell=$(basename "$SHELL")
    local config_file=""

    case "$user_shell" in
    bash)
        config_file="$HOME/.bashrc"
        ;;
    zsh)
        config_file="$HOME/.zshrc"
        ;;
    *)
        log_error "不支持的shell: $user_shell，跳过rm重定向配置"
        return 0
        ;;
    esac

    if grep -q "alias rm=" "$config_file" 2>/dev/null; then
        echo -e "${gl_huang}rm重定向已配置，无需重复配置${gl_bai}"
        return 0
    fi

    echo -e ""
    echo -e "${gl_zi}>>> 正在自动配置${gl_huang}rm${gl_zi}命令重定向到回收站 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    echo "" >>"$config_file"
    echo "# 自动配置：rm命令重定向到回收站" >>"$config_file"
    echo "# 配置时间: $(date '+%Y-%m-%d %H:%M:%S')" >>"$config_file"
    echo "alias rm='$TRASH_CMD'" >>"$config_file"
    echo "" >>"$config_file"

    if [[ $? -eq 0 ]]; then
        log_ok "${gl_huang}rm${gl_bai}重定向配置成功"
        log_warn "配置已添加到: ${gl_huang}$config_file${gl_bai}"
        log_warn "请重新登录或运行: ${gl_huang}source $config_file 使配置生效${gl_bai}"

        alias rm='$TRASH_CMD' 2>/dev/null
        log_ok "已为当前${gl_bufan}shell${gl_bai} 设置 ${gl_huang} rm ${gl_bai}别名"

        return 0
    else
        echo -e "${gl_hong}rm${gl_bai}重定向配置失败"
        exit_animation
        return 1
    fi
}

delete_file_with_trash() {
    local file="${1:-}"

    if [[ -z "$file" ]]; then
        echo -e "${gl_hong}错误：文件名参数为空${gl_bai}"
        return 1
    fi

    if [[ -z "$TRASH_CMD" ]]; then
        echo -e "${gl_huang}回收站未初始化，尝试自动安装 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        install_trash || {
            echo -e "${gl_hong}回收站安装失败，将使用直接删除${gl_bai}"
            return 1
        }
    fi

    if [[ -e "$file" ]]; then
        echo -e ""
        echo -e "${gl_huang}正在移动到回收站: ${gl_lv}$file${gl_bai}"

        if eval "$TRASH_CMD \"$file\"" 2>/dev/null; then
            echo -e "${gl_lv}✓ ${gl_bai}已移动到回收站: ${gl_lv}$file${gl_bai}"
            return 0
        else
            local error_msg
            error_msg=$(eval "$TRASH_CMD \"$file\"" 2>&1)

            if echo "$error_msg" | grep -q "不支持在系统内部挂载上的丢弃到回收站操作" ||
                echo "$error_msg" | grep -qi "not supported.*trash" ||
                echo "$error_msg" | grep -qi "cannot trash.*mount" ||
                echo "$error_msg" | grep -qi "cannot move to trash" ||
                echo "$error_msg" | grep -qi "trash not available"; then

                echo -e "${gl_huang}⚠ 此位置不支持回收站，将使用直接删除${gl_bai}"
                echo -e "${gl_lan}正在直接删除: $file${gl_bai}"

                if [[ -d "$file" ]]; then
                    if rm -rf "$file" 2>/dev/null; then
                        echo -e "${gl_lv}✓ ${gl_bai}已直接删除目录: ${gl_huang}$file${gl_bai}"
                        return 0
                    else
                        echo -e "${gl_hong}✗ ${gl_bai}直接删除目录失败: ${gl_huang}$file${gl_bai}"
                        return 1
                    fi
                else
                    if rm -f "$file" 2>/dev/null; then
                        echo -e "${gl_lv}✓ ${gl_bai}已直接删除文件: ${gl_huang}$file${gl_bai}"
                        return 0
                    else
                        echo -e "${gl_hong}✗ ${gl_bai}直接删除文件失败: ${gl_huang}$file${gl_bai}"
                        return 1
                    fi
                fi
            else
                echo -e "${gl_hong}✗ ${gl_bai}移动到回收站失败: ${gl_huang}$file${gl_bai}"
                echo -e "${gl_hui}错误信息: $error_msg${gl_bai}"
                return 1
            fi
        fi
    else
        echo -e "${gl_huang}文件不存在: $file${gl_bai}"
        return 1
    fi
}

get_trash_list() {
    local trash_items=()

    if [[ -z "$TRASH_CMD" ]]; then
        echo "[]"
        return
    fi

    if [[ "$TRASH_CMD" == "gio trash" ]]; then
        local trash_dir="$HOME/.local/share/Trash"
        if [[ -d "$trash_dir/files" ]]; then
            local count=1
            for item in "$trash_dir/files"/*; do
                if [[ -e "$item" ]]; then
                    local filename=$(basename "$item")
                    local info_file="$trash_dir/info/${filename}.trashinfo"
                    local original_path=""
                    local deletion_date=""

                    if [[ -f "$info_file" ]]; then
                        original_path=$(grep "^Path=" "$info_file" | cut -d= -f2-)
                        deletion_date=$(grep "^DeletionDate=" "$info_file" | cut -d= -f2-)
                    fi

                    trash_items+=("{\"index\":$count,\"name\":\"$filename\",\"original_path\":\"$original_path\",\"deletion_date\":\"$deletion_date\"}")
                    ((count++))
                fi
            done
        fi
    elif [[ "$TRASH_CMD" == "trash-put" ]] && command -v trash-list &>/dev/null; then
        local count=1
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                local deletion_date=$(echo "$line" | awk '{print $1 " " $2}')
                local original_path=$(echo "$line" | awk '{$1=$2=""; print substr($0,3)}' | sed 's/^ *//')
                local filename=$(basename "$original_path")

                trash_items+=("{\"index\":$count,\"name\":\"$filename\",\"original_path\":\"$original_path\",\"deletion_date\":\"$deletion_date\"}")
                ((count++))
            fi
        done < <(trash-list 2>/dev/null)
    fi

    if [[ ${#trash_items[@]} -eq 0 ]]; then
        echo "[]"
    else
        echo "[$(
            IFS=,
            echo "${trash_items[*]}"
        )]"
    fi
}

enable_trash() {
    echo
    echo -e "${gl_zi}>>> 启用回收站${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    load_trash_config

    if [[ -n "$TRASH_CMD" ]]; then
        echo -e "${gl_lv}回收站已经启用${gl_bai}"
        echo -e "${gl_bufan}当前回收站工具: ${gl_lv}$TRASH_CMD${gl_bai}"
    else
        if install_trash; then
            echo -e "${gl_lv}回收站启用成功${gl_bai}"
        else
            echo -e "${gl_hong}回收站启用失败${gl_bai}"
        fi
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    exit_animation
    return 1
}

disable_trash() {
    echo
    echo -e "${gl_zi}>>> 关闭回收站${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if [[ -n "$TRASH_CMD" ]]; then
        TRASH_CMD=""
        save_trash_config
        echo -e "${gl_lv}回收站已关闭${gl_bai}"
        echo -e "${gl_huang}现在删除文件将直接永久删除，请谨慎操作！${gl_bai}"
    else
        echo -e "${gl_huang}回收站已经是关闭状态${gl_bai}"
    fi

    echo
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    exit_animation
    return 1
}

empty_trash() {
    echo
    echo -e "${gl_zi}>>> 清空回收站${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if [[ -z "$TRASH_CMD" ]]; then
        echo -e "${gl_hong}回收站未启用${gl_bai}"
        exit_animation
        return
    fi

    if [[ "$TRASH_CMD" == "gio trash" ]]; then
        local trash_dir="$HOME/.local/share/Trash"
        if [[ -d "$trash_dir" ]]; then
            rm -rf "$trash_dir/files/"* 2>/dev/null
            rm -rf "$trash_dir/info/"* 2>/dev/null
            echo -e "${gl_lv}回收站已清空${gl_bai}"
        else
            echo -e "${gl_huang}回收站目录不存在${gl_bai}"
        fi
    elif [[ "$TRASH_CMD" == "trash-put" ]]; then
        if command -v trash-empty &>/dev/null; then
            trash-empty
            echo -e "${gl_lv}回收站已清空${gl_bai}"
        else
            echo -e "${gl_hong}trash-empty 命令不可用${gl_bai}"
        fi
    else
        echo -e "${gl_hong}不支持的回收站工具: $TRASH_CMD${gl_bai}"
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    exit_animation
    return 1
}

restore_trash_interactive() {
    echo
    echo -e "${gl_zi}>>> 恢复回收站文件${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if [[ -z "$TRASH_CMD" ]]; then
        echo -e "${gl_hong}回收站未启用${gl_bai}"
        exit_animation
        return
    fi

    local trash_json=$(get_trash_list)
    local item_count=0

    if command -v jq &>/dev/null; then
        item_count=$(echo "$trash_json" | jq length)
    else
        item_count=$(echo "$trash_json" | grep -o '"index"' | wc -l)
    fi

    if [[ $item_count -eq 0 ]]; then
        echo -e "${gl_huang}回收站为空，没有文件可恢复${gl_bai}"
        exit_animation
        return
    fi

    echo -e "${gl_bufan}可恢复的文件:${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if command -v jq &>/dev/null; then
        echo "$trash_json" | jq -r '.[] | "\(.index). \(.name)"' | while read -r line; do
            local index=$(echo "$line" | cut -d. -f1)
            local filename=$(echo "$line" | cut -d. -f2- | sed 's/^ *//')
            echo -e "  ${gl_huang}$index.${gl_bai} $filename"
        done
    else
        local index=1
        if [[ "$TRASH_CMD" == "gio trash" ]]; then
            local trash_dir="$HOME/.local/share/Trash/files"
            for item in "$trash_dir"/*; do
                if [[ -e "$item" ]]; then
                    local filename=$(basename "$item")
                    echo -e "  ${gl_huang}$index.${gl_bai} $filename"
                    ((index++))
                fi
            done
        elif [[ "$TRASH_CMD" == "trash-put" ]] && command -v trash-list &>/dev/null; then
            trash-list | while read -r line; do
                if [[ -n "$line" ]]; then
                    local filename=$(echo "$line" | awk '{$1=$2=""; print substr($0,3)}' | sed 's/^ *//' | xargs basename)
                    echo -e "  ${gl_huang}$index.${gl_bai} $filename"
                    ((index++))
                fi
            done
        fi
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_huang}提示：可输入多个序号，用空格分隔；0 或留空取消${gl_bai}"

    echo -ne "${gl_bufan}请输入要恢复的文件序号: ${gl_bai}"
    read -r -e raw
    [[ -z "$raw" || "$raw" == "0" ]] && return

    local to_restore=()
    read -r -ra tokens <<<"$raw"

    for tok in "${tokens[@]}"; do
        [[ -z "$tok" ]] && continue

        if [[ $tok =~ ^[0-9]+$ ]] && ((tok >= 1 && tok <= item_count)); then
            to_restore+=("$tok")
        else
            echo -e "${gl_hong}跳过无效序号: $tok${gl_bai}"
        fi
    done

    ((${#to_restore[@]} == 0)) && {
        echo -e "${gl_huang}没有选择有效的文件序号，取消恢复${gl_bai}"
        exit_animation
        return
    }

    echo
    echo -e "${gl_hong}即将恢复以下 ${#to_restore[@]} 个文件：${gl_bai}"
    for index in "${to_restore[@]}"; do
        if command -v jq &>/dev/null; then
            local filename=$(echo "$trash_json" | jq -r ".[] | select(.index==$index) | .name")
            echo -e "  ${gl_huang}$index. $filename${gl_bai}"
        else
            echo -e "  ${gl_huang}$index. 文件${gl_bai}"
        fi
    done

    read -r -e -p "$(echo -e "${gl_bai}确认恢复这些文件? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" -n1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] || return

    local ok=0 fail=0
    for index in "${to_restore[@]}"; do
        if restore_single_file "$index"; then
            ((ok++))
        else
            ((fail++))
        fi
    done

    echo
    if ((ok > 0)); then
        echo -e "${gl_lv}✓ 成功恢复 $ok 个文件${gl_bai}"
    fi
    if ((fail > 0)); then
        echo -e "${gl_hong}✗ $fail 个文件恢复失败${gl_bai}"
    fi

    echo
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

restore_single_file() {
    local index="${1:-}"

    if [[ "$TRASH_CMD" == "gio trash" ]]; then
        local trash_dir="$HOME/.local/share/Trash"
        local files_dir="$trash_dir/files"
        local info_dir="$trash_dir/info"

        local filename=""
        local count=1
        for item in "$files_dir"/*; do
            if [[ -e "$item" ]]; then
                if [[ $count -eq $index ]]; then
                    filename=$(basename "$item")
                    break
                fi
                ((count++))
            fi
        done

        if [[ -z "$filename" ]]; then
            echo -e "${gl_hong}无法找到文件: 序号 $index${gl_bai}"
            exit_animation
            return 1
        fi

        local file_path="$files_dir/$filename"
        local info_file="$info_dir/${filename}.trashinfo"
        local original_path=""

        if [[ -f "$info_file" ]]; then
            original_path=$(grep "^Path=" "$info_file" | cut -d= -f2-)
        fi

        if [[ -n "$original_path" && -e "$file_path" ]]; then
            local target_dir=$(dirname "$original_path")
            mkdir -p "$target_dir"

            if mv "$file_path" "$original_path" 2>/dev/null; then
                rm -f "$info_file"
                echo -e "${gl_lv}✓ 已恢复: $filename${gl_bai}"
                return 0
            else
                echo -e "${gl_hong}✗ 恢复失败: $filename${gl_bai}"
                exit_animation
                return 1
            fi
        else
            echo -e "${gl_hong}✗ 文件信息不完整: $filename${gl_bai}"
            exit_animation
            return 1
        fi

    elif [[ "$TRASH_CMD" == "trash-put" ]]; then
        if command -v trash-restore &>/dev/null; then
            echo -e "${gl_huang}请手动在接下来的界面中选择要恢复的文件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            trash-restore
            return $?
        else
            echo -e "${gl_hong}trash-restore 命令不可用${gl_bai}"
            exit_animation
            return 1
        fi
    else
        echo -e "${gl_hong}不支持的回收站工具${gl_bai}"
        exit_animation
        return 1
    fi
}

refresh_trash() {
    echo
    echo -e "${gl_zi}>>> 刷新回收站状态${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    load_trash_config

    if [[ -n "$TRASH_CMD" ]]; then
        echo -e "${gl_lv}✓ 回收站状态已刷新${gl_bai}"
        echo -e "${gl_bufan}当前回收站工具: ${gl_lv}$TRASH_CMD${gl_bai}"
    else
        echo -e "${gl_hong}回收站功能不可用${gl_bai}"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    exit_animation
    return 1
}

test_trash_function() {
    echo
    echo -e "${gl_zi}>>> 测试回收站功能${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if [[ -z "$TRASH_CMD" ]]; then
        echo -e "${gl_hong}回收站未启用${gl_bai}"
        exit_animation
        return
    fi

    local test_file="trash_test_$(date +%s).sh"
    echo -e "${gl_huang}创建测试文件: $test_file${gl_bai}"
    touch "$test_file"

    if [[ -e "$test_file" ]]; then
        echo -e "${gl_lv}测试文件创建成功${gl_bai}"
        echo -e "${gl_huang}尝试移动到回收站 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

        if delete_file_with_trash "$test_file"; then
            echo -e "${gl_lv}测试成功：文件已移动到回收站${gl_bai}"
        else
            echo -e "${gl_hong}测试失败：文件未能移动到回收站${gl_bai}"
        fi
    else
        echo -e "${gl_hong}测试文件创建失败${gl_bai}"
    fi

    local test_folder="trash_test_folder_$(date +%s)"
    echo -e "${gl_huang}创建测试文件夹: $test_folder${gl_bai}"
    mkdir -p "$test_folder"

    if [[ -d "$test_folder" ]]; then
        echo -e "${gl_lv}测试文件夹创建成功${gl_bai}"
        echo -e "${gl_huang}尝试将文件夹移动到回收站 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

        if delete_file_with_trash "$test_folder"; then
            echo -e "${gl_lv}测试成功：文件夹已移动到回收站${gl_bai}"
        else
            echo -e "${gl_hong}测试失败：文件夹未能移动到回收站${gl_bai}"
            rmdir "$test_folder" 2>/dev/null
        fi
    else
        echo -e "${gl_hong}测试文件夹创建失败${gl_bai}"
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

setup_rm_redirect() {
    echo
    echo -e "${gl_zi}=== 配置 rm 命令重定向到回收站 ===${gl_bai}"

    if [[ -z "$TRASH_CMD" ]]; then
        echo -e "${gl_hong}回收站未启用，请先启用回收站${gl_bai}"
        exit_animation
        return
    fi

    echo -e "${gl_huang}此功能将创建一个别名，将 rm 命令重定向到回收站${gl_bai}"
    echo -e "${gl_huang}这样使用 rm 删除的文件也会进入回收站${gl_bai}"
    echo
    echo -e "${gl_hong}警告：这可能会影响系统脚本和其他应用程序的行为${gl_bai}"
    echo -e "${gl_huang}建议仅在交互式shell中使用此功能${gl_bai}"
    echo

    read -r -e -p "$(echo -e "${gl_bai}确认配置 rm 命令重定向? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" -n1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${gl_huang}已取消配置${gl_bai}"
        return
    fi

    local user_shell=$(basename "$SHELL")
    local config_file=""

    case "$user_shell" in
    bash)
        config_file="$HOME/.bashrc"
        ;;
    zsh)
        config_file="$HOME/.zshrc"
        ;;
    *)
        echo -e "${gl_hong}不支持的shell: $user_shell${gl_bai}"
        echo -e "${gl_huang}请手动在您的shell配置文件中添加以下别名:${gl_bai}"
        echo "alias rm='$TRASH_CMD'"
        echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        read -r -n1 -s
        return
        ;;
    esac

    if grep -q "alias rm=" "$config_file" 2>/dev/null; then
        echo -e "${gl_huang}检测到已存在 rm 别名配置${gl_bai}"
        echo -e "${gl_huang}当前配置: $(grep "alias rm=" "$config_file")${gl_bai}"

        read -r -e -p "$(echo -e "${gl_bai}是否覆盖现有配置? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" -n1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${gl_huang}已取消配置${gl_bai}"
            return
        fi

        sed -i '/alias rm=/d' "$config_file"
    fi

    echo "# 配置rm命令重定向到回收站" >>"$config_file"
    echo "# 配置时间: $(date '+%Y-%m-%d %H:%M:%S')" >>"$config_file"
    echo "alias rm='$TRASH_CMD'" >>"$config_file"

    if [[ $? -eq 0 ]]; then
        echo -e "${gl_lv}✓ 已成功配置 rm 命令重定向${gl_bai}"
        echo -e "${gl_huang}配置已添加到: $config_file${gl_bai}"
        echo -e "${gl_huang}请重新登录或运行: source $config_file${gl_bai}"
        echo
        echo -e "${gl_lv}现在使用 rm 命令删除的文件将进入回收站${gl_bai}"
    else
        echo -e "${gl_hong}✗ 配置失败${gl_bai}"
    fi

    echo
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n1 -s
}

remove_rm_redirect() {
    echo
    echo -e "${gl_zi}=== 移除 rm 命令重定向 ===${gl_bai}"

    local user_shell=$(basename "$SHELL")
    local config_file=""

    case "$user_shell" in
    bash)
        config_file="$HOME/.bashrc"
        ;;
    zsh)
        config_file="$HOME/.zshrc"
        ;;
    *)
        echo -e "${gl_hong}不支持的shell: $user_shell${gl_bai}"
        echo -e "${gl_huang}请手动从您的shell配置文件中移除 rm 别名${gl_bai}"
        echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        read -r -n1 -s
        return
        ;;
    esac

    if grep -q "alias rm=" "$config_file" 2>/dev/null; then
        echo -e "${gl_huang}检测到 rm 别名配置: $(grep "alias rm=" "$config_file")${gl_bai}"

        read -r -e -p "$(echo -e "${gl_bai}确认移除 rm 命令重定向? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" -n1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${gl_huang}已取消操作 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
            exit_animation
            return
        fi

        sed -i '/alias rm=/d' "$config_file"

        if [[ $? -eq 0 ]]; then
            echo -e "${gl_lv}✓ 已成功移除 rm 命令重定向${gl_bai}"
            echo -e "${gl_huang}请重新登录或运行: source $config_file${gl_bai}"
            echo
            echo -e "${gl_lv}现在 rm 命令将恢复为系统默认行为${gl_bai}"
        else
            echo -e "${gl_hong}✗ 移除失败${gl_bai}"
        fi
    else
        echo -e "${gl_huang}未找到 rm 命令重定向配置${gl_bai}"
    fi

    echo
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    read -r -n1 -s
}

check_rm_redirect() {
    echo
    echo -e "${gl_zi}=== rm 命令重定向状态 ===${gl_bai}"

    local user_shell=$(basename "$SHELL")
    local config_file=""

    case "$user_shell" in
    bash)
        config_file="$HOME/.bashrc"
        ;;
    zsh)
        config_file="$HOME/.zshrc"
        ;;
    *)
        echo -e "${gl_hong}不支持的shell: $user_shell${gl_bai}"
        return
        ;;
    esac

    if grep -q "alias rm=" "$config_file" 2>/dev/null; then
        echo -e "${gl_lv}✓ rm 命令重定向已启用${gl_bai}"
        echo -e "${gl_huang}当前配置: $(grep "alias rm=" "$config_file")${gl_bai}"
        echo
        echo -e "${gl_lv}使用 rm 命令删除的文件将进入回收站${gl_bai}"
    else
        echo -e "${gl_huang}✗ rm 命令重定向未启用${gl_bai}"
        echo
        echo -e "${gl_huang}使用 rm 命令删除的文件将永久删除${gl_bai}"
        echo -e "${gl_huang}不会进入回收站${gl_bai}"
    fi

    echo
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    read -r -n1 -s
}

remove_rm_redirect_silent() {
    local user_shell=$(basename "$SHELL")
    local config_file=""

    case "$user_shell" in
    bash)
        config_file="$HOME/.bashrc"
        ;;
    zsh)
        config_file="$HOME/.zshrc"
        ;;
    *)
        return
        ;;
    esac

    if grep -q "alias rm=" "$config_file" 2>/dev/null; then
        sed -i '/alias rm=/d' "$config_file"
    fi
}

uninstall_trash_tool() {
    clear
    echo
    echo -e "${gl_zi}>>> 卸载回收站工具${gl_bai}"
    if [[ -n "$TRASH_CMD" ]]; then
        echo -e "${gl_bufan}当前回收站工具: ${gl_lv}$TRASH_CMD${gl_bai}"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_warn "此操作将卸载回收站工具并清理相关文件！"
    echo -e "${gl_huang}这将导致：${gl_bai}"
    echo -e "   ${gl_bufan}1. ${gl_bai}回收站工具将被卸载"
    echo -e "   ${gl_bufan}2. ${gl_bai}回收站中的文件将${gl_hong}永久丢失${gl_bai}"
    echo -e "   ${gl_bufan}3. ${gl_bai}rm重定向配置将被移除"
    echo -e "   ${gl_bufan}4. ${gl_bai}回收站相关目录可能被清理"
    echo -e "   ${gl_bufan}5. ${gl_bai}回收站配置文件将被删除"

    local has_files=false
    if [[ "$TRASH_CMD" == "gio trash" ]]; then
        local trash_dir="$HOME/.local/share/Trash/files"
        if [[ -d "$trash_dir" ]] && [[ -n "$(ls -A "$trash_dir" 2>/dev/null)" ]]; then
            has_files=true
            echo -e "${gl_hong}回收站中有文件，卸载前建议先清空回收站！${gl_bai}"
        fi
    elif [[ "$TRASH_CMD" == "trash-put" ]] && command -v trash-list &>/dev/null; then
        if [[ -n "$(trash-list 2>/dev/null)" ]]; then
            has_files=true
            echo -e "${gl_hong}回收站中有文件，卸载前建议先清空回收站！${gl_bai}"
        fi
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}确认要卸载回收站工具? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" -n1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${gl_huang}已取消卸载操作${gl_bai}"
        exit_animation
        return
    fi

    if [[ "$has_files" == "true" ]]; then
        echo
        read -r -e -p "$(echo -e "${gl_bai}回收站中仍有文件，确定要继续卸载吗? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" -n1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${gl_huang}已取消卸载操作${gl_bai}"
            exit_animation
            return
        fi
    fi

    local uninstall_success=false
    local cleanup_success=false

    clear
    echo
    echo -e "${gl_zi}>>> 正在卸载回收站工具 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if command -v trash-put &>/dev/null; then
        echo -e "${gl_lan}检测到 trash-cli，正在卸载 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

        if command -v apt &>/dev/null; then
            sudo apt remove -y trash-cli && uninstall_success=true
        elif command -v yum &>/dev/null; then
            sudo yum remove -y trash-cli && uninstall_success=true
        elif command -v dnf &>/dev/null; then
            sudo dnf remove -y trash-cli && uninstall_success=true
        elif command -v pacman &>/dev/null; then
            sudo pacman -R --noconfirm trash-cli && uninstall_success=true
        else
            echo -e "${gl_huang}无法自动卸载，请手动卸载 trash-cli${gl_bai}"
        fi

        if [[ -d "$HOME/.local/share/trash" ]]; then
            rm -rf "$HOME/.local/share/trash" 2>/dev/null
        fi
    fi

    if [[ "$TRASH_CMD" == "gio trash" ]] && command -v gio &>/dev/null; then
        echo -e "${gl_huang}注意：gio 是 glib 的一部分，通常不建议卸载${gl_bai}"
        echo -e "${gl_huang}将只清理回收站目录，不卸载 gio${gl_bai}"
    fi

    echo -e ""
    echo -e "${gl_zi}>>> 正在清理回收站目录 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local trash_dirs=(
        "$HOME/.local/share/Trash"
        "$HOME/.local/share/trash"
        "/tmp/.Trash-$(id -u)"
    )

    for dir in "${trash_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log_info "清理目录: ${gl_huang}$dir${gl_bai}"
            rm -rf "$dir" 2>/dev/null && cleanup_success=true
        fi
    done

    log_info "正在移除rm重定向配置 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    remove_rm_redirect_silent

    log_info "正在清理配置文件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

    if [[ -f "$TRASH_CONFIG_FILE" ]]; then
        rm -f "$TRASH_CONFIG_FILE" && log_ok "删除回收站配置文件${gl_bai}"
    fi

    local shell_configs=(
        "$HOME/.bashrc"
        "$HOME/.bash_profile"
        "$HOME/.bash_aliases"
        "$HOME/.zshrc"
        "$HOME/.zprofile"
        "$HOME/.zsh_aliases"
    )

    for config in "${shell_configs[@]}"; do
        if [[ -f "$config" ]]; then
            sed -i '/alias trash=/d' "$config" 2>/dev/null
            sed -i '/alias rm=/d' "$config" 2>/dev/null
            sed -i '/# 回收站配置/d' "$config" 2>/dev/null
            sed -i '/# Trash configuration/d' "$config" 2>/dev/null
            sed -i '/# 自动配置：rm命令重定向到回收站/d' "$config" 2>/dev/null
            sed -i '/# 配置时间:/d' "$config" 2>/dev/null
        fi
    done

    unset TRASH_CMD

    if [[ "$uninstall_success" == "true" || "$cleanup_success" == "true" ]]; then
        log_ok "回收站工具卸载完成"
        echo
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}以下操作已完成：${gl_bai}"
        echo -e "   ${gl_lv}✓ ${gl_bai}回收站工具已卸载"
        echo -e "   ${gl_lv}✓ ${gl_bai}回收站目录已清理"
        echo -e "   ${gl_lv}✓ ${gl_bai}rm重定向配置已移除"
        echo -e "   ${gl_lv}✓ ${gl_bai}配置文件已清理"
        echo -e "   ${gl_lv}✓ ${gl_bai}环境变量已清理"
    else
        echo -e "${gl_hong}⚠ 卸载过程中可能存在问题${gl_bai}"
        echo -e "${gl_huang}请检查：${gl_bai}"
        echo -e "  • 回收站工具是否已安装"
        echo -e "  • 是否有足够的权限"
        echo -e "  • 手动检查配置文件"
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n1 -s
}

one_click_auto_setup() {
    echo -e ""
    echo -e "${gl_zi}>>> 一键自动初始化和配置回收站${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    read -r -e -p "$(echo -e "${gl_bai}是否要自动初始化和配置回收站功能? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" -n1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${gl_huang}已取消自动配置${gl_bai}"
        exit_animation
        return
    fi

    if auto_setup_trash; then
        echo -e "${gl_lv}✓ 回收站自动配置完成！${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}已启用功能：${gl_bai}"
        echo -e "  ${gl_lv}✓ ${gl_bai}回收站工具已安装/初始化"
        echo -e "  ${gl_lv}✓ ${gl_bai}rm命令已重定向到回收站"
        echo -e "  ${gl_lv}✓ ${gl_bai}配置文件已更新"
        echo
        echo -e "${gl_huang}现在删除文件将进入回收站，可以通过回收站管理恢复文件。${gl_bai}"
    else
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_hong}✗ 回收站自动配置失败${gl_bai}"
        echo -e "${gl_huang}请检查：${gl_bai}"
        echo -e "  • 网络连接"
        echo -e "  • 系统包管理器"
        echo -e "  • 权限设置"
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n1 -s
}

manage_trash_menu() {
    load_trash_config

    local user_shell=$(basename "$SHELL")
    local config_file=""

    case "$user_shell" in
    bash) config_file="$HOME/.bashrc" ;;
    zsh) config_file="$HOME/.zshrc" ;;
    esac

    local rm_configured=false
    if [[ -n "$config_file" ]] && grep -q "alias rm=" "$config_file" 2>/dev/null; then
        rm_configured=true
    fi

    if [[ "$rm_configured" == "false" ]]; then
        clear
        echo -e "${gl_zi}>>> 回收站管理${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_hong}检测到您的系统尚未配置回收站功能${gl_bai}"
        echo -e "${gl_huang}自动配置将执行以下操作：${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "   ${gl_bufan}1. ${gl_bai}安装回收站工具（如未安装）"
        echo -e "   ${gl_bufan}2. ${gl_bai}初始化回收站功能"
        echo -e "   ${gl_bufan}3. ${gl_bai}配置 ${gl_huang}rm${gl_bai} 命令重定向到回收站"
        echo -e "   ${gl_bufan}4. ${gl_bai}更新 ${gl_huang}shell${gl_bai} 配置文件"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_hong}注意：配置后，使用 ${gl_huang}rm${gl_hong} 命令删除的文件将进入回收站而非永久删除${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        read -r -e -p "$(echo -e "${gl_bai}是否自动配置回收站? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" -n1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            auto_setup_trash
            echo
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_bai}按任意键进入回收站管理菜单 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
            read -r -n1 -s
        fi
    fi

    while true; do
        clear
        echo -e "${gl_zi}>>> 回收站管理${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        if [[ -n "$TRASH_CMD" ]]; then
            echo -e "${gl_bufan}回收站状态: ${gl_lv}已启用 (${gl_huang}$TRASH_CMD)${gl_bai}"
        else
            echo -e "${gl_bufan}回收站状态: ${gl_hui}未启用${gl_bai}"
        fi

        check_rm_redirect_silent
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        show_trash_contents_and_stats

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}关闭回收站            ${gl_bufan}2.  ${gl_bai}开启回收站"
        echo -e "${gl_bufan}3.  ${gl_bai}清空回收站            ${gl_bufan}4.  ${gl_bai}恢复回收站"
        echo -e "${gl_bufan}5.  ${gl_bai}刷新回收站            ${gl_bufan}6.  ${gl_bai}测试回收站"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_lv}66. ${gl_bai}初始化回收站          ${gl_hong}99. ${gl_bai}卸载回收站"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单        ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "请输入你的选择: " sub_choice
        case $sub_choice in
        1) disable_trash ;;
        2) enable_trash ;;
        3) empty_trash ;;
        4) restore_trash_interactive ;;
        5) refresh_trash ;;
        6) test_trash_function ;;
        66) one_click_auto_setup ;;
        99) uninstall_trash_tool ;;
        0) cancel_return; break ;;
        00 | 000 | 0000) save_trash_config; exit_script ;;
        *) handle_invalid_input ;;
        esac
    done
}

linux_file() {
    local title="${1:-文件管理器}"
    local menu_name="${2:-上一级选单}"
    
    # 如果第一个参数是目录，直接使用它
    if [[ -d "${1:-}" ]] && [[ "${1:-}" != "." ]]; then
        cd "$1" 2>/dev/null || true
        title="${2:-文件管理器}"
        menu_name="${3:-上一级选单}"
    fi

    root_use
    while true; do
        clear
        local current_dir="$(pwd)"
        if [ -z "$(ls -A "$current_dir" 2>/dev/null)" ]; then
            echo -e "${gl_huang}>>> 当前目录文件列表：${gl_bai}(${gl_lv}$current_dir${gl_bai})"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_huang}当前目录为空${gl_bai}"
        else
            list_dir_colorful 0 4
        fi
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e ""
        echo -e "${gl_zi}>>> ${title}${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}目录操作 ${gl_huang}★${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}进入目录  ${gl_bufan}2.  ${gl_bai}创建目录   ${gl_bufan}3.  ${gl_bai}修改目录权限"
        echo -e "${gl_bufan}4.  ${gl_bai}改目录名  ${gl_bufan}5.  ${gl_bai}删除目录   ${gl_bufan}6.  ${gl_bai}返回上一级目录"
        echo -e "${gl_bufan}7.  ${gl_bai}搜索目录  ${gl_bufan}8.  ${gl_bai}查找大目录 ${gl_bufan}9.  ${gl_bai}列出目录大小"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}文件操作 ${gl_huang}★${gl_bai}"
        echo -e "${gl_bufan}11. ${gl_bai}创建文件  ${gl_bufan}12. ${gl_bai}编辑文件   ${gl_bufan}13. ${gl_bai}修改文件权限"
        echo -e "${gl_bufan}14. ${gl_bai}改文件名  ${gl_bufan}15. ${gl_bai}删除文件   ${gl_bufan}16. ${gl_bai}预览文件内容"
        echo -e "${gl_bufan}17. ${gl_bai}搜索文件  ${gl_bufan}18. ${gl_bai}查找大文件 ${gl_bufan}19. ${gl_bai}创建并编辑文件"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}通用操作 ${gl_huang}★${gl_bai}"
        echo -e "${gl_bufan}21. ${gl_bai}压缩文件  ${gl_bufan}22. ${gl_bai}解压文件   ${gl_bufan}23. ${gl_bai}解压/压缩工具"
        echo -e "${gl_bufan}24. ${gl_bai}批量改名  ${gl_bufan}25. ${gl_bai}安全删除   ${gl_bufan}26. ${gl_bai}下载文件工具"
        echo -e "${gl_bufan}27. ${gl_bai}移动文件  ${gl_bufan}28. ${gl_bai}复制文件   ${gl_bufan}29. ${gl_bai}文件回收站"
        echo -e "${gl_bufan}31. ${gl_bai}搜索内容  ${gl_bufan}32. ${gl_bai}搜索并处理 ${gl_bufan}33. ${gl_bai}实时监控目录大小"
        echo -e "${gl_bufan}34. ${gl_bai}文件去重  ${gl_bufan}35. ${gl_bai}图片转格式 ${gl_bufan}36. ${gl_bai}传送文件至远端"
        echo -e "${gl_bufan}37. ${gl_bai}文件信息  ${gl_bufan}38. ${gl_bai}生成目录树 ${gl_bufan}39. ${gl_bai}常用目录管理"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单           ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" Limiting

        case "$Limiting" in
        1)  enter_directory "文件管理器" ;;
        2)  create_directory "文件管理器" || continue ;;
        3)  modify_directory_permissions || continue ;;
        4)  rename_directory ;;
        5)  delete_directories ;;
        6)  go_parent_directory ;;
        7)  search_dir_here ;;
        8)  find_large_directories ;;
        9)  list_directory_sizes ;;
        11) create_new_file ;;
        12) edit_file_with_nano ;;
        13) file_chmod "文件管理器" ;;
        14) rename_file_or_dir ;;
        15) delete_files ;;
        16) cat_view_file_content "文件管理器" ;;
        17) search_file_here ;;
        18) find_large_files ;;
        19) create_file ;;
        21) compress_file_or_directory ;;
        22) extract_archive ;;
        23) compress_tool ;;
        24) batch_rename_files ;;
        25) interactive_delete ;;
        26) download_file ;;
        27) move_file_or_directory ;;
        28) copy_file_or_directory ;;
        29) manage_trash_menu ;;
        31) search_here ;;
        32) manual_file_search_and_process ;;
        33) duwatch ;;
        34) remove_duplicate_files ;;
        35) image_converter_main "文件管理器" ;;
        36) transfer_file_to_remote ;;
        37) check_directory_empty "." "查看文件信息" "true" || continue
            select_and_display_file_info "." 1 4 ;;
        38) show_directory_tree ;;
        39) manage_backup_files_simple "linux_file" ;;
        0) cancel_return "$menu_name"; return ;;
        00 | 000 | 0000) exit_script ;;
        *)  handle_invalid_input ;;
        esac
    done
}

main() {
    local target_dir="${1:-}"
    
    if [[ -n "$target_dir" ]] && [[ -d "$target_dir" ]]; then
        cd "$target_dir" && linux_file "$(pwd)" "文件管理器" "主菜单"
    elif [[ -n "$SCRIPT_WORKDIR" ]] && [[ -d "$SCRIPT_WORKDIR" ]]; then
        cd "$SCRIPT_WORKDIR" && linux_file "$(pwd)" "文件管理器" "主菜单"
    else
        linux_file "$(pwd)" "文件管理器" "主菜单"
    fi
}

is_pve_system() {
    if [ ! -d "/var/lib/vz/template/iso" ]; then
        echo -e ""
        echo -en "${gl_hong}你这不是 ${gl_huang}PVE${gl_hong} 系统！\c"
        exit_script
        exit 0
    fi
    return 0
}

pve_file_menu() {
    while true; do
        clear
        
        if ! command -v qm &> /dev/null; then
            echo -e ""
            echo -e "${gl_zi}>>> PVE 文件管理${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            log_error "未检测到Proxmox VE环境，请确保脚本在PVE节点上运行"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            return 1
        fi
        
        echo -e "${gl_zi}>>> PVE 文件管理${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}镜像文件管理       ${gl_bufan}2.  ${gl_bai}备份文件管理"
        echo -e "${gl_bufan}3.  ${gl_bai}容器配置管理       ${gl_bufan}4.  ${gl_bai}虚拟机配置管理"
        echo -e "${gl_bufan}5.  ${gl_bai}虚拟磁盘管理       ${gl_bufan}6.  ${gl_bai}数据总目录管理"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单     ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "请输入你的选择: " choice
        
        case $choice in
        1) linux_file /var/lib/vz/template/iso "PVE 镜像文件管理" "主菜单" ;;
        2) linux_file /var/lib/vz/dump "PVE 备份文件管理" "主菜单" ;;
        3) linux_file /etc/pve/lxc "PVE 容器配置管理" "主菜单" ;;
        4) linux_file /etc/pve/qemu-server "PVE 虚拟机配置管理" "主菜单" ;;
        5) linux_file /var/lib/vz/images "PVE 虚拟磁盘管理" "主菜单" ;;
        6) linux_file /var/lib/vz "PVE 数据总目录管理" "主菜单" ;;
        0) cancel_return "已是主菜单" || continue ;;
        00 | 000 | 0000) exit_script ;;
        *) handle_invalid_input ;;
        esac
    done
}

parse_arguments "$@"

if [[ -n "$SCRIPT_WORKDIR" ]] && [[ "$SCRIPT_WORKDIR" != "$(pwd)" ]]; then
    main "$SCRIPT_WORKDIR"
else
    pve_file_menu
    main "$@"
fi
