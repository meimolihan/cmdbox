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
    export gl_qing=$'\033[38;5;14m'
    export reset=$'\033[0m'
}
list_color_init

log_info()  { echo -e "${gl_lan}[信息]${gl_bai} $*"; }
log_ok()    { echo -e "${gl_lv}[成功]${gl_bai} $*"; }
log_warn()  { echo -e "${gl_huang}[警告]${gl_bai} $*"; }
log_error() { echo -e "${gl_hong}[错误]${gl_bai} $*" >&2; }

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意继键续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
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

exit_animation() {
    echo -ne "${gl_lv}即退将出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo ""
    clear
}

cancel_return() {
    local menu_name="${1:-上一级选单}"
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

handle_invalid_input() {
    echo -ne "\r\033[K${gl_huang}无效的输入,请重新输入! ${gl_zi} 1 ${gl_huang} 秒后返回"
    sleep_fractional 1
    echo -ne "\r\033[K${gl_lv}无效的输入,请重新输入! ${gl_zi}0${gl_lv} 秒后返回"
    sleep_fractional 0.5
    echo -ne "\r\033[K"
    return 2
}

install() {
    [[ $# -eq 0 ]] && {
        log_error "未提供软件包参数!"
        return 1
    }

    local pkg mgr ver cmd_ver pkg_ver installed=false
    for pkg in "$@"; do
        installed=false
        ver=""
        
        if command -v "$pkg" &>/dev/null; then
            cmd_ver=$("$pkg" --version 2>/dev/null | head -n1 | tr -cd '[:print:]' | grep -oE '[0-9]+(\.[0-9]+)+' | head -n1 || echo "")
            [[ -n "$cmd_ver" ]] && ver="$cmd_ver"
            installed=true
        fi
        
        if [[ "$pkg" == "7zip" || "$pkg" == "7z" ]]; then
            if command -v 7z &>/dev/null; then
                ver=$(7z 2>&1 | grep -oE '[0-9]+(\.[0-9]+)+' | head -n1 || echo "")
                [[ -n "$ver" ]] && installed=true
            fi
        fi
        
        if [[ "$installed" == false ]]; then
            if command -v opkg &>/dev/null; then
                if opkg list-installed | grep -q "^${pkg} "; then
                    installed=true
                    ver=$(opkg list-installed | grep "^${pkg} " | awk '{print $3}' 2>/dev/null || echo "")
                fi
            elif command -v dpkg-query &>/dev/null; then
                if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
                    installed=true
                    ver=$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null || echo "")
                fi
            elif command -v rpm &>/dev/null; then
                if rpm -q "$pkg" &>/dev/null; then
                    installed=true
                    ver=$(rpm -q --qf '%{VERSION}' "$pkg" 2>/dev/null || echo "")
                fi
            elif command -v apk &>/dev/null; then
                if apk info "$pkg" 2>/dev/null | grep -q "^installed"; then
                    installed=true
                    ver=$(apk info -a "$pkg" 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)+' | head -n1 || echo "")
                fi
            elif command -v pacman &>/dev/null; then
                if pacman -Qi "$pkg" &>/dev/null; then
                    installed=true
                    ver=$(pacman -Qi "$pkg" 2>/dev/null | grep -i "version" | grep -oE '[0-9]+(\.[0-9]+)+' | head -n1 || echo "")
                fi
            fi
        fi
        
        if [[ "$installed" == true ]]; then
            echo -e "${gl_huang}${pkg}${gl_bai} ${gl_lv}已安装${gl_bai}" \
                "$([[ -n "$ver" ]] && echo "版本 ${gl_lv}${ver}${gl_bai}")"
            continue
        fi
        
        echo -e ""
        echo -e "${gl_huang}开始安装：${gl_bai}${pkg}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        local install_success=false
        
        for mgr in opkg dnf yum apt apk pacman zypper pkg; do
            if ! command -v "$mgr" &>/dev/null; then
                continue
            fi
            
            case $mgr in
            opkg)
                echo -e "${gl_bai}使用包管理器: ${gl_zi}opkg (OpenWrt/iStoreOS)${gl_bai}"
                if [[ "$pkg" == "7zip" || "$pkg" == "7z" ]]; then
                    echo -e "${gl_bai}正在安装: ${gl_lv}p7zip${gl_bai}"
                    opkg update && opkg install p7zip && install_success=true
                else
                    opkg update && opkg install "$pkg" && install_success=true
                fi
                ;;
            dnf)
                echo -e "${gl_bai}使用包管理器: ${gl_zi}dnf (Fedora/RHEL)${gl_bai}"
                dnf -y update && dnf install -y "$pkg" && install_success=true
                ;;
            yum)
                echo -e "${gl_bai}使用包管理器: ${gl_zi}yum (CentOS/RHEL)${gl_bai}"
                yum -y update && yum install -y "$pkg" && install_success=true
                ;;
            apt)
                echo -e "${gl_bai}使用包管理器: ${gl_zi}apt (Debian/Ubuntu)${gl_bai}"
                apt update -y && apt install -y "$pkg" && install_success=true
                ;;
            apk)
                echo -e "${gl_bai}使用包管理器: ${gl_zi}apk (Alpine)${gl_bai}"
                apk update && apk add "$pkg" && install_success=true
                ;;
            pacman)
                echo -e "${gl_bai}使用包管理器: ${gl_zi}pacman (Arch/Manjaro)${gl_bai}"
                pacman -Syu --noconfirm && pacman -S --noconfirm "$pkg" && install_success=true
                ;;
            zypper)
                echo -e "${gl_bai}使用包管理器: ${gl_zi}zypper (openSUSE)${gl_bai}"
                zypper refresh && zypper install -y "$pkg" && install_success=true
                ;;
            pkg)
                echo -e "${gl_bai}使用包管理器: ${gl_zi}pkg (FreeBSD)${gl_bai}"
                pkg update && pkg install -y "$pkg" && install_success=true
                ;;
            esac
            
            [[ "$install_success" == true ]] && break
        done
        
        if [[ "$install_success" == true ]]; then
            echo -e "${gl_lv}✓ ${pkg} 安装成功${gl_bai}"
        else
            echo -e "${gl_hong}✗ ${pkg} 安装失败${gl_bai}"
        fi
        
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    done
}

list_files() {
    local target_dir="${1:-.}"
    local show_hidden="${2:-0}"
    local custom_cols="${3:-2}"
    local dir="${CURRENT_DIR:-.}"
    
    LIST_FILES_ARRAY=()
    LIST_FILES_COUNT=0
    
    if [[ ! -d "$target_dir" ]]; then
        log_error "目录不存在: $target_dir"
        exit_animation
        return 1
    fi
    
    local original_dir="$(pwd)"
    
    if ! cd "$target_dir" 2>/dev/null; then
        log_error "无法进入目录: $target_dir"
        exit_animation
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
    local column_padding=3
    
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
        
        local color="${gl_lv}"
        if [[ -d "$item_path" ]]; then
            color="${gl_zi}"
        elif [[ -x "$item_path" ]]; then
            color="${gl_huang}"
        elif [[ "$item" == .* ]]; then
            color="${gl_hui}"
        elif [[ "$item" =~ \.(zip|tar|gz|bz2|7z|rar)$ ]]; then
            color="${gl_hong}"
        elif [[ "$item" =~ \.(sh|bash|zsh)$ ]]; then
            color="${gl_lan}"
        elif [[ "$item" =~ \.(txt|md|conf|ini|cfg)$ ]]; then
            color="${gl_qing}"
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

rz_upload_file() {
    clear
    list_files "." 0 4
    echo -e ""
    echo -e "${gl_zi}>>> 上传文件到服务器 (rz)${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_info "准备接收来自本地的文件"
    echo -e "${gl_bai}终端支持检测:${gl_bai}"
    echo -e "${gl_bai}支持的终端: ${gl_lv}MobaXterm, Xshell, SecureCRT, Tabby, WindTerm${gl_bai}"
    echo -e "${gl_huang}注意: PuTTY 不支持Zmodem协议${gl_bai}"
    echo -e "${gl_huang}注意: Windows Terminal 需安装lrzsz并配置${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    echo -e "${gl_huang}请在本地客户端选择要上传的文件${gl_bai}"
    
    for i in {2..1}; do
        echo -ne "${gl_huang}将在 ${gl_lv}$i${gl_bai} 秒后弹出文件选择对话框 \r"
        sleep_fractional 1
    done
    echo ""
    
    if command -v rz >/dev/null 2>&1; then
        echo -e "${gl_bai}执行命令: ${gl_zi}rz${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}提示: 按${gl_lv}Ctrl+C${gl_bai}取消上传${gl_bai}"
        
        if rz; then
            log_ok "文件上传成功!"
            echo -e "${gl_bai}上传的文件:${gl_bai}"
            ls -lth | head -5
        else
            if [[ $? -eq 130 ]]; then
                log_info "上传被用户取消"
            else
                log_warn "文件上传失败，请检查终端是否支持Zmodem"
            fi
        fi
    else
        log_error "rz命令不可用，请先安装lrzsz"
    fi
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

rz_upload_compressed_file() {
    clear
    echo -e "${gl_zi}>>> 上传文件夹到服务器 (压缩上传)${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_info "此功能将本地文件夹压缩后上传到服务器"
    echo -e "${gl_bai}支持格式:${gl_bai}"
    echo -e "  ${gl_bufan}1. ${gl_bai}通过rz上传ZIP/TAR压缩包"
    echo -e "  ${gl_bufan}2. ${gl_bai}自动解压到当前目录"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    local -a files_before=(*)
    
    read -r -e -p "$(echo -e "${gl_bai}是否自动解压? (${gl_lv}y${gl_bai}/${gl_hong}n${gl_bai}): ")" extract_choice
    
    for i in {2..1}; do
        echo -ne "${gl_huang}将在 ${gl_lv}$i${gl_bai} 秒后开始上传 \r"
        sleep_fractional 1
    done
    echo ""
    
    if ! command -v rz >/dev/null 2>&1; then
        log_error "rz命令不可用，请先安装 lrzsz"
        break_end
        return 1
    fi
    
    echo -e "${gl_huang}提示: 按${gl_lv}Ctrl+C${gl_bai}取消上传${gl_bai}"
    echo -e "${gl_lv}请在选择文件对话框中选择要上传的压缩包${gl_bai}"
    
    if ! rz; then
        local exit_code=$?
        [[ $exit_code -eq 130 ]] && log_info "上传被用户取消" || log_warn "上传失败"
        break_end
        return 1
    fi
    
    local -a files_after=(*) new_files=()
    for f in "${files_after[@]}"; do
        local is_new=true
        for old in "${files_before[@]}"; do
            [[ "$f" == "$old" ]] && { is_new=false; break; }
        done
        [[ "$is_new" == true ]] && new_files+=("$f")
    done
    
    if [[ ${#new_files[@]} -eq 0 ]]; then
        log_warn "未检测到新上传的文件"
        break_end
        return 1
    fi
    
    local zip_file
    if [[ ${#new_files[@]} -eq 1 ]]; then
        zip_file="${new_files[0]}"
        log_ok "检测到上传文件: ${gl_huang}${zip_file}${gl_bai}"
    else
        log_info "检测到多个新文件:"
        local i=1
        for f in "${new_files[@]}"; do
            echo -e "  ${gl_lv}${i}.${gl_bai} $f"
            ((i++))
        done
        read -r -e -p "请选择编号 [1-${#new_files[@]}]: " choice
        [[ "$choice" =~ ^[0-9]+$ && $choice -ge 1 && $choice -le ${#new_files[@]} ]] || {
            log_error "无效选择"
            break_end
            return 1
        }
        zip_file="${new_files[$((choice-1))]}"
    fi
    
    if [[ "$extract_choice" == [yY] ]]; then
        log_info "正在解压: ${gl_huang}${zip_file}${gl_bai}"
        local extract_success=false
        
        case "$zip_file" in
            *.zip)
                command -v unzip >/dev/null && unzip -o "$zip_file" >/dev/null 2>&1 && {
                    log_ok "ZIP 解压完成"
                    extract_success=true
                } || log_error "解压失败或缺少 unzip"
                ;;
            *.tar.gz|*.tgz) tar -xzf "$zip_file" >/dev/null 2>&1 && { log_ok "TAR.GZ 解压完成"; extract_success=true; } ;;
            *.tar.bz2) tar -xjf "$zip_file" >/dev/null 2>&1 && { log_ok "TAR.BZ2 解压完成"; extract_success=true; } ;;
            *.tar.xz) tar -xJf "$zip_file" >/dev/null 2>&1 && { log_ok "TAR.XZ 解压完成"; extract_success=true; } ;;
            *.tar) tar -xf "$zip_file" >/dev/null 2>&1 && { log_ok "TAR 解压完成"; extract_success=true; } ;;
            *.gz) gunzip -f "$zip_file" >/dev/null 2>&1 && { log_ok "GZ 解压完成"; extract_success=true; } ;;
            *) log_warn "不支持的格式" ;;
        esac
        
        if [[ "$extract_success" == true ]]; then
            read -r -e -p "是否删除压缩包? (y/n): " delete_choice
            [[ "$delete_choice" == [yY] ]] && rm -f "$zip_file" && log_ok "已删除压缩包"
        fi
    else
        log_info "文件已保存：$(pwd)/$zip_file"
    fi
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

rz_download_folder() {
    clear
    echo -e "${gl_zi}>>> 下载文件夹到本地 (压缩下载)${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    local -a dir_array=() dir_names=()
    while IFS= read -r -d '' dir; do
        dir_array+=("$dir")
        dir_names+=("$(basename "$dir")")
    done < <(find . -maxdepth 1 -type d -not -name ".*" -print0 2>/dev/null | sort -zV)
    
    if [[ ${#dir_array[@]} -eq 0 ]]; then
        log_warn "当前目录无可下载文件夹"
        break_end
        return 1
    fi
    
    echo -e "${gl_bai}文件夹列表:${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    for i in "${!dir_array[@]}"; do
        printf "${gl_bufan}%3d. ${gl_bai}%-30s\n" $((i+1)) "${dir_names[$i]}"
    done
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "请输入序号 (0返回): " dir_choice
    [[ "$dir_choice" == "0" ]] && { cancel_return "返回"; return 1; }
    [[ ! "$dir_choice" =~ ^[0-9]+$ || $dir_choice -lt 1 || $dir_choice -gt ${#dir_array[@]} ]] && {
        log_error "无效序号"
        break_end
        return 1
    }
    
    local selected_dir="${dir_array[$((dir_choice-1))]}"
    local dir_name="${dir_names[$((dir_choice-1))]}"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local zip_file="${dir_name}_${timestamp}"
    
    echo -e "${gl_bai}选择：${gl_huang}$dir_name${gl_bai}"
    echo -e "${gl_huang}>>> 选择压缩格式${gl_bai}"
    echo -e "1.tar.gz 2.zip 3.tar.bz2 4.tar.xz"
    read -r -e -p "请选择 [1-4]: " format_choice
    
    case $format_choice in
        1) zip_file+=".tar.gz"; tar -czf "$zip_file" "$dir_name" >/dev/null 2>&1 || { log_error "压缩失败"; break_end; return 1; } ;;
        2) zip_file+=".zip"; command -v zip >/dev/null && zip -rq "$zip_file" "$dir_name" >/dev/null 2>&1 || { log_error "缺少zip"; break_end; return 1; } ;;
        3) zip_file+=".tar.bz2"; tar -cjf "$zip_file" "$dir_name" >/dev/null 2>&1 || { log_error "压缩失败"; break_end; return 1; } ;;
        4) zip_file+=".tar.xz"; tar -cJf "$zip_file" "$dir_name" >/dev/null 2>&1 || { log_error "压缩失败"; break_end; return 1; } ;;
        *) log_warn "使用默认tar.gz"; zip_file+=".tar.gz"; tar -czf "$zip_file" "$dir_name" >/dev/null 2>&1 ;;
    esac
    
    [[ -f "$zip_file" ]] || { log_error "压缩失败"; break_end; return 1; }
    log_ok "压缩完成：$zip_file"
    
    read -r -e -p "是否下载? (y/n): " download_choice
    if [[ "$download_choice" == [yY] ]]; then
        for i in {2..1}; do echo -ne "将在 $i 秒后开始下载 \r"; sleep_fractional 1; done
        echo ""
        sz "$zip_file" && log_ok "下载成功" || log_info "下载取消/中断"
    fi
    
    read -r -e -p "是否删除临时压缩包? (y/n): " delete_choice
    [[ "$delete_choice" == [yY] ]] && rm -f "$zip_file" && log_ok "已删除"
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

rz_download_files_interactive() {
    clear
    echo -e "${gl_zi}>>> 选择文件下载 (交互式)${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    local search_pattern
    read -r -e -p "搜索模式(*显示全部): " search_pattern
    search_pattern=${search_pattern:-*}
    
    local -a file_list=()
    while IFS= read -r -d '' file; do
        file_list+=("$file")
    done < <(find . -maxdepth 1 -type f -name "$search_pattern" -print0 2>/dev/null | sort -zV)
    
    [[ ${#file_list[@]} -eq 0 ]] && { log_warn "无匹配文件"; break_end; return 1; }
    
    echo -e "${gl_bai}文件列表:${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    local -a interactive_files=()
    for i in "${!file_list[@]}"; do
        printf "${gl_bufan}%3d. ${gl_bai}%-40s\n" $((i+1)) "$(basename "${file_list[$i]}")"
        interactive_files+=("${file_list[$i]}")
    done
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "选择(序号/1-5/1,3): " file_choices
    [[ "$file_choices" == "0" ]] && { cancel_return "返回"; return 1; }
    [[ -z "$file_choices" ]] && { log_error "输入不能为空"; break_end; return 1; }
    
    local -a selected_files=()
    if [[ "$file_choices" =~ ^[0-9]+$ ]]; then
        [[ $file_choices -ge 1 && $file_choices -le ${#interactive_files[@]} ]] && selected_files+=("${interactive_files[$((file_choices-1))]}")
    elif [[ "$file_choices" =~ ^[0-9]+-[0-9]+$ ]]; then
        local start=$(echo $file_choices | cut -d'-' -f1) end=$(echo $file_choices | cut -d'-' -f2)
        for ((i=start; i<=end; i++)); do selected_files+=("${interactive_files[$((i-1))]}"); done
    else
        IFS=',' read -ra choices <<< "$file_choices"
        for c in "${choices[@]}"; do
            c=$(echo $c | tr -d ' ')
            [[ "$c" =~ ^[0-9]+$ && $c -ge 1 && $c -le ${#interactive_files[@]} ]] && selected_files+=("${interactive_files[$((c-1))]}")
        done
    fi
    
    [[ ${#selected_files[@]} -eq 0 ]] && { log_error "无有效选择"; break_end; return 1; }
    
    echo -e "选择了 ${#selected_files[@]} 个文件"
    read -r -e -p "确认下载? (y/n): " confirm
    if [[ "$confirm" == [yY] ]]; then
        for i in {2..1}; do echo -ne "将在 $i 秒后开始 \r"; sleep_fractional 1; done
        echo ""
        sz "${selected_files[@]}" && log_ok "下载完成" || log_info "取消/中断"
    fi
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

rz_upload_files_batch() {
    clear
    echo -e "${gl_zi}>>> 批量上传多个文件${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_info "支持一次上传多个文件"
    read -r -e -p "是否继续? (y/n): " confirm
    [[ "$confirm" != [yY] ]] && { break_end; return; }
    
    for i in {2..1}; do echo -ne "将在 $i 秒后弹出选择框 \r"; sleep_fractional 1; done
    echo ""
    
    if command -v rz >/dev/null; then
        rz -bye >/dev/null 2>&1 && log_ok "批量上传成功" || {
            [[ $? -eq 130 ]] && log_info "已取消" || { log_warn "批量失败，尝试普通模式"; rz; }
        }
    else
        log_error "rz 不可用"
    fi
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

rz_check_zmodem_support() {
    clear
    echo -e "${gl_zi}>>> 检查终端Zmodem支持${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    command -v sz && command -v rz && log_ok "lrzsz 已安装" || log_warn "lrzsz 未安装"
    [[ -n "$SSH_TTY" ]] && log_ok "SSH 连接正常" || log_warn "非SSH连接可能不支持"
    echo -e "支持：MobaXterm/Xshell/SecureCRT/Tabby/WindTerm"
    echo -e "不推荐：PuTTY / Windows Terminal(需配置)"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

rz_view_transfer_history() {
    clear
    echo -e "${gl_zi}>>> 传输历史/最近文件${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "最近修改文件："
    find . -maxdepth 1 -type f -printf "%T+\t%f\n" | sort -r | head -10
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

rz_download_files_to_local() {
    local target_dir="${1:-.}"
    install lrzsz bc
    clear
    echo -e "${gl_zi}>>> 下载文件到本地 (sz)${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    list_files "." 0 10
    
    read -r -e -p "选择文件(序号/通配符/名称，0返回)：" user_input
    [[ "$user_input" == "0" ]] && { cancel_return "返回"; return 1; }
    
    local -a all_files=(*) selected_files=()
    if [[ "$user_input" =~ ^[0-9]+(-[0-9]+)?$ || "$user_input" =~ ^[0-9]+(\ [0-9]+)*$ ]]; then
        [[ "$user_input" =~ ^[0-9]+$ ]] && selected_files+=("${all_files[$((user_input-1))]}")
        [[ "$user_input" =~ ^[0-9]+-[0-9]+$ ]] && {
            local s=$(echo $user_input | cut -d- f1) e=$(echo $user_input | cut -d- f2)
            for ((i=s; i<=e; i++)); do selected_files+=("${all_files[$((i-1))]}"); done
        }
    elif [[ "$user_input" == *\** ]]; then
        selected_files=($user_input)
    else
        selected_files=($user_input)
    fi
    
    [[ ${#selected_files[@]} -eq 0 ]] && { log_error "未匹配到文件"; break_end; return 1; }
    
    echo -e "选中：${#selected_files[@]} 个文件"
    read -r -e -p "确认下载? (y/n): " confirm
    [[ "$confirm" != [yY] ]] && { log_info "已取消"; break_end; return; }
    
    for i in {3..1}; do echo -ne "将在 $i 秒后开始传输 \r"; sleep_fractional 1; done
    echo ""
    sz "${selected_files[@]}" && log_ok "传输完成" || log_info "取消/中断"
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

rz_clean_temp_files() {
    clear
    echo -e "${gl_zi}>>> 清理临时文件${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    local -a temp_files=()
    while IFS= read -r -d '' f; do temp_files+=("$f"); done < <(find . -maxdepth 1 -type f \( -name "*.tmp" -o -name "*.swp" -o -name "*~" \) -print0 2>/dev/null)
    
    [[ ${#temp_files[@]} -eq 0 ]] && { log_info "无临时文件"; break_end; return; }
    
    echo -e "找到 ${#temp_files[@]} 个临时文件"
    read -r -e -p "删除? (y/n): " del
    [[ "$del" == [yY] ]] && {
        rm -f "${temp_files[@]}"
        log_ok "清理完成"
    } || log_info "已取消"
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

rz_create_test_files() {
    clear
    echo -e "${gl_zi}>>> 创建测试文件${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "1.1KB  2.1MB  3.10MB  4.自定义"
    read -r -e -p "选择：" opt
    
    case $opt in
        1) echo "test" > test_1k.txt; log_ok "已创建 1KB 文件" ;;
        2) dd if=/dev/zero of=test_1m.txt bs=1M count=1 >/dev/null 2>&1; log_ok "已创建 1MB 文件" ;;
        3) dd if=/dev/zero of=test_10m.txt bs=1M count=10 >/dev/null 2>&1; log_ok "已创建 10MB 文件" ;;
        4) read -p "大小(1K/1M): " sz; dd if=/dev/zero of=test_custom.txt bs=$sz count=1 >/dev/null 2>&1; log_ok "创建完成" ;;
    esac
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

file_transfer_manager() {
    while true; do
        install lrzsz bc zip unzip
        clear
        echo -e "${gl_zi}>>> Zmodem 文件传输管理器${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}上传文件        ${gl_bufan}2.  ${gl_bai}下载文件 "
        echo -e "${gl_bufan}3.  ${gl_bai}上传文件夹      ${gl_bufan}4.  ${gl_bai}下载文件夹"
        echo -e "${gl_bufan}5.  ${gl_bai}选择下载        ${gl_bufan}6.  ${gl_bai}批量上传"
        echo -e "${gl_bufan}7.  ${gl_bai}测试文件        ${gl_bufan}8.  ${gl_bai}清理临时文件"
        echo -e "${gl_bufan}9.  ${gl_bai}检测Zmodem      ${gl_bufan}10. ${gl_bai}传输记录"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单  ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        read -r -e -p "请输入你的选择：" choice
        case $choice in
            1)  rz_upload_file ;;
            2)  rz_download_files_to_local ;;
            3)  rz_upload_compressed_file ;;
            4)  rz_download_folder ;;
            5)  rz_download_files_interactive ;;
            6)  rz_upload_files_batch ;;
            7)  rz_create_test_files ;;
            8)  rz_clean_temp_files ;;
            9)  rz_check_zmodem_support ;;
            10) rz_view_transfer_history ;;
            0) cancel_return "已是主菜单" || continue ;;
            00 | 000 | 0000) exit_script ;;
            *)  handle_invalid_input ;;
        esac
    done
}

file_transfer_manager