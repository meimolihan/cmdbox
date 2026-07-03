#!/bin/bash
set -uo pipefail

gl_hui='\e[37m'
gl_hong='\033[31m'
gl_lv='\033[32m'
gl_huang='\033[33m'
gl_lan='\033[34m'
gl_zi='\033[35m'
gl_bufan='\033[96m'
gl_bai='\033[97m'

log_info()  { echo -e "${gl_lan}[信息]${gl_bai} $*"; }
log_ok()    { echo -e "${gl_lv}[成功]${gl_bai} $*"; }
log_warn()  { echo -e "${gl_huang}[警告]${gl_bai} $*"; }
log_error() { echo -e "${gl_hong}[错误]${gl_bai} $*" >&2; }

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    read -r -n 1 -s -p ""
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

sleep_fractional() {
    local seconds=$1
    if sleep "$seconds" 2>/dev/null; then return 0; fi
    if command -v python3 >/dev/null 2>&1; then python3 -c "import time; time.sleep($seconds)"; return 0; fi
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

handle_invalid_input() {
    echo -ne "\r\033[K${gl_huang}无效的输入,请重新输入! ${gl_zi} 1 ${gl_huang} 秒后返回"
    sleep_fractional 1
    echo -ne "\r\033[K${gl_lv}无效的输入,请重新输入! ${gl_zi}0${gl_lv} 秒后返回"
    sleep_fractional 0.5
    echo -ne "\r\033[K"
    continue
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

safe_read() {
    local prompt="$1"
    local var_name="$2"
    local type="$3"
    read -r -p "$(echo -e "${gl_bai}$prompt")" "$var_name"
}

display_horizontal_list() {
    local -n arr=$1
    local count=0 items_per_line=2 term_width=$(tput cols 2>/dev/null || echo 80)
    ((term_width > 120)) && items_per_line=4
    ((term_width > 80 && term_width <=120)) && items_per_line=3
    local max_len=0

    for item in "${arr[@]}"; do
        ((${#item} > max_len)) && max_len=${#item}
    done
    max_len=$((max_len + 4))

    for i in "${!arr[@]}"; do
        count=$((count+1))
        printf "${gl_huang}%2d.${gl_bai} %-${max_len}s" "$((i+1))" "${arr[$i]}"
        ((count % items_per_line == 0)) && echo ""
    done
    ((count % items_per_line != 0)) && echo ""
}

install() {
    [[ $# -eq 0 ]] && { log_error "未提供软件包参数!"; return 1; }

    local pkg mgr ver installed
    for pkg in "$@"; do
        installed=false
        ver=""

        if command -v "$pkg" &>/dev/null; then
            ver=$("$pkg" --version 2>/dev/null | head -n1 | grep -oE '[0-9]+(\.[0-9]+)+' | head -n1 || true)
            installed=true
        fi

        if [[ "$pkg" == "7zip" || "$pkg" == "7z" ]] && command -v 7z &>/dev/null; then
            ver=$(7z 2>&1 | grep -oE '[0-9]+(\.[0-9]+)+' | head -n1 || true)
            installed=true
        fi

        if [[ "$installed" == true ]]; then
            echo -e "${gl_huang}${pkg}${gl_bai} ${gl_lv}已安装${gl_bai} ${gl_lv}${ver:-}${gl_bai}"
            continue
        fi

        log_info "${gl_bai}开始安装：${gl_hong}$pkg ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        local install_success=false

        for mgr in opkg dnf yum apt apk pacman zypper pkg; do
            command -v "$mgr" &>/dev/null || continue

            case $mgr in
                opkg) opkg update && opkg install "${pkg//7zip/p7zip}" && install_success=true ;;
                dnf)  dnf -y install "$pkg" && install_success=true ;;
                yum)  yum -y install "$pkg" && install_success=true ;;
                apt)  apt update -y && apt install -y "$pkg" && install_success=true ;;
                apk)  apk add "$pkg" && install_success=true ;;
                pacman) pacman -S --noconfirm "$pkg" && install_success=true ;;
                zypper) zypper install -y "$pkg" && install_success=true ;;
                pkg) pkg install -y "$pkg" && install_success=true ;;
            esac
            [[ "$install_success" == true ]] && break
        done

        if [[ "$install_success" == true ]]; then
            log_ok "$pkg 安装成功"
        else
            log_error "$pkg 安装失败"
        fi
    done
}

###### 上传文件到服务器
rz_upload_file() {
    install lrzsz
    clear
    if ! list_files "." 0 4; then
        return
    fi
    echo -e ""
    echo -e "${gl_zi}>>> 上传文件到服务器 (rz)${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_info "准备接收来自本地的文件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bai}终端支持检测:${gl_bai}"
    echo -e "${gl_bai}支持的终端: ${gl_lv}MobaXterm, Xshell, SecureCRT, Tabby, WindTerm${gl_bai}"
    echo -e "${gl_huang}注意: PuTTY 不支持Zmodem协议${gl_bai}"
    echo -e "${gl_huang}注意: Windows Terminal 需安装lrzsz并配置${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    echo -e "${gl_huang}请在本地客户端选择要上传的文件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    
    for i in {2..1}; do
        echo -ne "${gl_huang}将在 ${gl_lv}$i${gl_bai} 秒后弹出文件选择对话框${gl_bai}\r"
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

###### 上传文件夹
# 上传文件夹函数（支持压缩上传）
rz_upload_compressed_file() {
    clear
    echo -e "${gl_zi}>>> 上传文件夹到服务器 (压缩上传)${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_info "此功能将本地文件夹压缩后上传到服务器"
    echo -e "${gl_bai}支持格式:${gl_bai}"
    echo -e "  ${gl_bufan}1. ${gl_bai}通过rz上传ZIP/TAR压缩包"
    echo -e "  ${gl_bufan}2. ${gl_bai}自动解压到当前目录"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    # 记录上传前的文件列表
    local -a files_before
    files_before=(*)
    
    read -r -e -p "$(echo -e "${gl_bai}是否自动解压? (${gl_lv}y${gl_bai}/${gl_hong}n${gl_bai}): ")" extract_choice
    
    for i in {2..1}; do
        echo -ne "${gl_huang}将在 ${gl_lv}$i${gl_bai} 秒后开始上传 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\r"
        sleep_fractional 1
    done
    echo ""
    
    if ! command -v rz >/dev/null 2>&1; then
        log_error "rz命令不可用，请先安装 lrzsz"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation    # 即将退出动画
        return 1
    fi
    
    echo -e "${gl_huang}提示: 按${gl_lv}Ctrl+C${gl_bai}取消上传${gl_bai}"
    echo -e "${gl_lv}请在选择文件对话框中选择要上传的压缩包 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    
    if ! rz; then
        local exit_code=$?
        if [[ $exit_code -eq 130 ]]; then
            log_info "上传被用户取消"
        else
            log_warn "文件上传失败，请检查终端是否支持Zmodem"
        fi
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation    # 即将退出动画
        return 1
    fi
    
    # ========== 智能检测新上传的文件 ==========
    local -a files_after
    local -a new_files
    files_after=(*)
    new_files=()
    
    # 找出新增的文件
    for f in "${files_after[@]}"; do
        local is_new=true
        for old in "${files_before[@]}"; do
            [[ "$f" == "$old" ]] && is_new=false && break
        done
        [[ "$is_new" == true ]] && new_files+=("$f")
    done
    
    # 检查是否找到新文件
    if [[ ${#new_files[@]} -eq 0 ]]; then
        log_warn "未检测到新上传的文件"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation    # 即将退出动画
        return 1
    fi
    
    # 如果上传了多个，取第一个（或让用户选择）
    local zip_file
    if [[ ${#new_files[@]} -eq 1 ]]; then
        zip_file="${new_files[0]}"
        log_ok "检测到上传文件: ${gl_huang}${zip_file}${gl_bai} (${gl_lv}$(du -h "$zip_file" 2>/dev/null | cut -f1)${gl_bai})"
    else
        log_info "检测到多个新文件:"
        local i=1
        for f in "${new_files[@]}"; do
            echo -e "  ${gl_lv}${i}.${gl_bai} $f ${gl_huang}($(du -h "$f" 2>/dev/null | cut -f1)${gl_bai})"
            ((i++))
        done
        read -r -e -p "$(echo -e "${gl_bai}请选择要处理的文件编号 [1-${#new_files[@]}]: ")" choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#new_files[@]} )); then
            zip_file="${new_files[$((choice-1))]}"
        else
            log_error "无效选择"
            exit_animation    # 即将退出动画
            return 1
        fi
    fi
    
    # ========== 解压逻辑 ==========
    if [[ "$extract_choice" == "y" || "$extract_choice" == "Y" ]]; then
        log_info "正在解压: ${gl_huang}${zip_file}${gl_bai}"
        local extract_success=false
        
        # ZIP
        if [[ "$zip_file" == *.zip ]]; then
            if command -v unzip >/dev/null 2>&1; then
                if unzip -o "$zip_file" 2>/dev/null; then
                    log_ok "ZIP解压完成 → 当前目录"
                    extract_success=true
                else
                    log_error "ZIP解压失败"
                fi
            else
                log_error "缺少unzip命令: apt install unzip / yum install unzip"
            fi
            
        # TAR.GZ / TGZ
        elif [[ "$zip_file" == *.tar.gz || "$zip_file" == *.tgz ]]; then
            if [[ -f "$zip_file" ]] && file "$zip_file" | grep -q "gzip compressed data"; then
                if tar -xzf "$zip_file" 2>/dev/null; then
                    log_ok "TAR.GZ解压完成 → 当前目录"
                    extract_success=true
                else
                    log_error "TAR.GZ解压失败，可能是文件损坏或权限问题"
                fi
            else
                log_error "文件格式不匹配或文件已损坏"
            fi
            
        # TAR.BZ2
        elif [[ "$zip_file" == *.tar.bz2 ]]; then
            if [[ -f "$zip_file" ]] && (file "$zip_file" | grep -q "bzip2 compressed data" || file "$zip_file" | grep -q "tar archive"); then
                if tar -xjf "$zip_file" 2>/dev/null; then
                    log_ok "TAR.BZ2解压完成 → 当前目录"
                    extract_success=true
                else
                    log_error "TAR.BZ2解压失败，可能是文件损坏或权限问题"
                fi
            else
                log_error "文件格式不匹配或文件已损坏"
            fi
            
        # TAR.XZ
        elif [[ "$zip_file" == *.tar.xz ]]; then
            if [[ -f "$zip_file" ]] && (file "$zip_file" | grep -q "XZ compressed data" || file "$zip_file" | grep -q "tar archive"); then
                if tar -xJf "$zip_file" 2>/dev/null; then
                    log_ok "TAR.XZ解压完成 → 当前目录"
                    extract_success=true
                else
                    log_error "TAR.XZ解压失败，可能是文件损坏或权限问题"
                fi
            else
                log_error "文件格式不匹配或文件已损坏"
            fi
            
        # TAR
        elif [[ "$zip_file" == *.tar ]]; then
            if [[ -f "$zip_file" ]] && (file "$zip_file" | grep -q "tar archive" || file "$zip_file" | grep -q "POSIX tar archive"); then
                if tar -xf "$zip_file" 2>/dev/null; then
                    log_ok "TAR解压完成 → 当前目录"
                    extract_success=true
                else
                    log_error "TAR解压失败，可能是文件损坏或权限问题"
                fi
            else
                log_error "文件格式不匹配或文件已损坏"
            fi
            
        # GZ (非tar)
        elif [[ "$zip_file" == *.gz && ! "$zip_file" == *.tar.gz ]]; then
            if [[ -f "$zip_file" ]] && (file "$zip_file" | grep -q "gzip compressed data"); then
                if gunzip -f "$zip_file" 2>/dev/null; then
                    log_ok "GZ解压完成 → 当前目录"
                    extract_success=true
                else
                    log_error "GZ解压失败，可能是文件损坏或权限问题"
                fi
            else
                log_error "文件格式不匹配或文件已损坏"
            fi
            
        else
            log_warn "不支持的格式: ${gl_huang}${zip_file##*.}${gl_bai}，请手动解压"
        fi
        
        # 询问是否删除压缩包
        if [[ "$extract_success" == true ]]; then
            read -r -e -p "$(echo -e "${gl_bai}是否删除压缩包? (${gl_lv}y${gl_bai}/${gl_hong}n${gl_bai}): ")" delete_choice
            if [[ "$delete_choice" == "y" || "$delete_choice" == "Y" ]]; then
                rm -f "$zip_file" 2>/dev/null && log_ok "已删除压缩包" || log_warn "删除失败"
            fi
        fi
    else
        # 不解压，只显示信息
        if [[ -f "$zip_file" ]]; then
            log_info "文件已保存: ${gl_huang}$(pwd)/${zip_file}${gl_bai}"
        else
            log_warn "文件不存在或已被移动"
        fi
    fi
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

###### 下载文件夹
# 下载文件夹函数（压缩下载）
rz_download_folder() {
    clear
    echo -e "${gl_zi}>>> 下载文件夹到本地 (压缩下载)${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    # 列出当前目录的文件夹
    local dir_index=1
    local dir_array=()
    local dir_names=()
    
    echo -e "${gl_bai}当前目录文件夹列表:${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    # 使用数组安全地存储目录名
    while IFS= read -r -d '' dir; do
        if [[ -d "$dir" ]] && [[ "$dir" != "." ]] && [[ "$dir" != ".." ]] && [[ ! -L "$dir" ]]; then
            dir_array+=("$dir")
            dir_names+=("$(basename "$dir")")
            ((dir_index++))
        fi
    done < <(find . -maxdepth 1 -type d -not -name ".*" -print0 2>/dev/null | sort -zV)
    
    if [[ ${#dir_array[@]} -eq 0 ]]; then
        echo -e "${gl_huang}当前目录没有可下载的文件夹"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation    # 即将退出动画
        return 1
    fi
    
    # 显示文件夹列表
    for i in "${!dir_array[@]}"; do
        local idx=$((i + 1))
        local dir="${dir_array[$i]}"
        local dir_name="${dir_names[$i]}"
        local dir_size
        dir_size=$(du -sh "$dir" 2>/dev/null | cut -f1 || echo "未知")
        local file_count
        file_count=$(find "$dir" -type f 2>/dev/null | wc -l)
        
        printf "${gl_bufan}%3d. ${gl_bai}%-30s ${gl_huang}大小: %-8s ${gl_lv}文件数: %d\n" \
               "$idx" "$dir_name" "$dir_size" "$file_count"
    done
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}请输入要下载的文件夹序号 (${gl_huang}0${gl_bai})返回: ")" dir_choice
    
    [ "$dir_choice" = "0" ] && { cancel_return "上一级选单"; return 1; }    # break 或 continue 或 return ，视上下文而定
    
    if ! [[ "$dir_choice" =~ ^[0-9]+$ ]] || \
       [[ "$dir_choice" -lt 1 ]] || \
       [[ "$dir_choice" -gt ${#dir_array[@]} ]]; then
        log_error "无效的文件夹序号"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation    # 即将退出动画
        return 1
    fi
    
    local selected_dir="${dir_array[$((dir_choice-1))]}"
    local dir_name="${dir_names[$((dir_choice-1))]}"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local zip_file="${dir_name}_${timestamp}"
    
    echo -e "${gl_bai}选择的文件夹: ${gl_huang}${dir_name}${gl_bai}"
    echo -e "${gl_bai}文件夹大小: ${gl_huang}$(du -sh "$selected_dir" 2>/dev/null | cut -f1)${gl_bai}"
    
    echo -e "${gl_huang}>>> 请选择压缩格式${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bufan}1.${gl_bai} tar.gz (推荐)"
    echo -e "${gl_bufan}2.${gl_bai} zip"
    echo -e "${gl_bufan}3.${gl_bai} tar.bz2"
    echo -e "${gl_bufan}4.${gl_bai} tar.xz"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}请输入你的选择 ${gl_bai}[${gl_lv}1${gl_bai}-${gl_huang}4${gl_bai}]: ")" format_choice
    
    case $format_choice in
        1)
            zip_file="${zip_file}.tar.gz"
            echo -e ""
            echo -e "${gl_huang}>>> 正在压缩为tar.gz格式 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            if tar -czf "$zip_file" "$dir_name" 2>/dev/null; then
                log_ok "文件夹压缩完成: ${gl_huang}$(du -h "$zip_file" 2>/dev/null | cut -f1)${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            else
                log_error "文件夹压缩失败"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
                return 1
            fi
            ;;
        2)
            zip_file="${zip_file}.zip"
            if command -v zip >/dev/null 2>&1; then
                echo -e ""
                echo -e "${gl_huang}>>> 正在压缩为zip格式 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                if zip -rq "$zip_file" "$dir_name" 2>/dev/null; then
                    log_ok "文件夹压缩完成: ${gl_huang}$(du -h "$zip_file" 2>/dev/null | cut -f1)${gl_bai}"
                    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                else
                    log_error "文件夹压缩失败"
                    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                    break_end
                    return 1
                fi
            else
                log_error "未找到zip命令，使用tar.gz格式"
                zip_file="${dir_name}_${timestamp}.tar.gz"
                tar -czf "$zip_file" "$dir_name" 2>/dev/null
            fi
            ;;
        3)
            zip_file="${zip_file}.tar.bz2"
            echo -e ""
            echo -e "${gl_huang}>>> 正在压缩为tar.bz2格式 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            if tar -cjf "$zip_file" "$dir_name" 2>/dev/null; then
                log_ok "文件夹压缩完成: ${gl_huang}$(du -h "$zip_file" 2>/dev/null | cut -f1)${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            else
                log_error "文件夹压缩失败"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
                return 1
            fi
            ;;
        4)
            zip_file="${zip_file}.tar.xz"
            echo -e ""
            echo -e "${gl_huang}>>> 正在压缩为tar.xz格式 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            if tar -cJf "$zip_file" "$dir_name" 2>/dev/null; then
                log_ok "文件夹压缩完成: ${gl_huang}$(du -h "$zip_file" 2>/dev/null | cut -f1)${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            else
                log_error "文件夹压缩失败"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
                return 1
            fi
            ;;
        *)
            log_warn "无效选择，使用默认tar.gz格式"
            zip_file="${zip_file}.tar.gz"
            tar -czf "$zip_file" "$dir_name" 2>/dev/null
            ;;
    esac
    
    if [[ -f "$zip_file" ]]; then
        read -r -e -p "$(echo -e "${gl_bai}是否下载压缩包? (${gl_lv}y${gl_bai}/${gl_hong}n${gl_bai}): ")" download_choice
        if [[ "$download_choice" == "y" || "$download_choice" == "Y" ]]; then
            echo -e "${gl_bai}使用命令: ${gl_zi}sz \"${zip_file}\"${gl_bai}"
            echo -e "${gl_huang}请在本地客户端接收文件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            
            for i in {2..1}; do
                echo -ne "${gl_huang}将在 ${gl_lv}$i${gl_bai} 秒后开始下载${gl_bai}\r"
                sleep_fractional 1
            done
            echo ""
            
            if sz "$zip_file"; then
                log_ok "文件夹下载成功!"
            else
                if [[ $? -eq 130 ]]; then
                    log_info "下载被用户取消"
                else
                    log_warn "文件传输可能被中断"
                fi
            fi
        fi
        
        read -r -e -p "$(echo -e "${gl_bai}是否删除临时压缩包? (${gl_lv}y${gl_bai}/${gl_hong}n${gl_bai}): ")" delete_choice
        if [[ "$delete_choice" == "y" || "$delete_choice" == "Y" ]]; then
            if rm -f "$zip_file" 2>/dev/null; then
                log_ok "已删除临时压缩包"
            else
                log_warn "删除临时压缩包失败"
            fi
        fi
    else
        log_error "压缩文件创建失败"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

###### 选择文件下载
rz_download_files_interactive() {
    clear
    echo -e "${gl_zi}>>> 选择文件下载 (交互式)${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    local search_pattern
    read -r -e -p "$(echo -e "${gl_bai}请输入文件搜索模式 (如: *.txt, *.sh, 留空显示所有): ")" search_pattern
    
    if [[ -z "$search_pattern" ]]; then
        search_pattern="*"
    fi
    
    local file_list=()
    while IFS= read -r -d '' file; do
        file_list+=("$file")
    done < <(find . -maxdepth 1 -type f -name "$search_pattern" 2>/dev/null | sort -zV)
    
    if [[ ${#file_list[@]} -eq 0 ]]; then
        log_warn "未找到匹配的文件: ${gl_huang}${search_pattern}${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation    # 即将退出动画
        return 1
    fi
    
    echo -e "${gl_bai}找到以下文件:${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    local file_index=1
    local interactive_files=()
    
    for file in "${file_list[@]}"; do
        if [[ -f "$file" ]]; then
            local file_size
            file_size=$(stat -c%s "$file" 2>/dev/null || echo "0")
            local size_display
            
            if [[ $file_size -ge 1073741824 ]]; then
                size_display=$(echo "scale=2; $file_size/1073741824" | bc)G
            elif [[ $file_size -ge 1048576 ]]; then
                size_display=$(echo "scale=2; $file_size/1048576" | bc)M
            elif [[ $file_size -ge 1024 ]]; then
                size_display=$(echo "scale=2; $file_size/1024" | bc)K
            else
                size_display="${file_size}B"
            fi
            
            printf "${gl_bufan}%3d. ${gl_bai}%-40s ${gl_huang}%8s\n" \
                   "$file_index" "$(basename "$file")" "$size_display"
            interactive_files+=("$file")
            ((file_index++))
        fi
    done
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}输入: ${gl_huang}单个序号${gl_bai} 或 ${gl_huang}多个序号用逗号分隔${gl_bai} 或 ${gl_huang}范围如1-5${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}请选择要下载的文件 (${gl_huang}0${gl_bai})返回: ")" file_choices
    
    [ "$file_choices" = "0" ] && { cancel_return "上一级选单"; return 1; }    # break 或 continue 或 return ，视上下文而定
    
    if [[ -z "$file_choices" ]]; then
        log_error "请输入有效的文件序号"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation    # 即将退出动画
        return 1
    fi
    
    local selected_files=()
    
    # 处理输入格式
    if [[ "$file_choices" =~ ^[0-9]+$ ]]; then
        # 单个数字
        if [[ "$file_choices" -ge 1 && "$file_choices" -le ${#interactive_files[@]} ]]; then
            selected_files+=("${interactive_files[$((file_choices-1))]}")
        else
            log_error "无效的文件序号: $file_choices"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            exit_animation    # 即将退出动画
            return 1
        fi
    elif [[ "$file_choices" =~ ^[0-9]+-[0-9]+$ ]]; then
        # 范围
        local start
        start=$(echo "$file_choices" | cut -d'-' -f1)
        local end
        end=$(echo "$file_choices" | cut -d'-' -f2)
        
        if [[ $start -ge 1 && $end -le ${#interactive_files[@]} && $start -le $end ]]; then
            for ((i=start; i<=end; i++)); do
                selected_files+=("${interactive_files[$((i-1))]}")
            done
        else
            log_error "无效的文件范围: $file_choices"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            exit_animation    # 即将退出动画
            return 1
        fi
    else
        # 多个用逗号分隔
        IFS=',' read -ra choices <<< "$file_choices"
        for choice in "${choices[@]}"; do
            choice=$(echo "$choice" | tr -d '[:space:]')
            if [[ "$choice" =~ ^[0-9]+$ ]] && \
               [[ "$choice" -ge 1 && "$choice" -le ${#interactive_files[@]} ]]; then
                selected_files+=("${interactive_files[$((choice-1))]}")
            fi
        done
    fi
    
    if [[ ${#selected_files[@]} -eq 0 ]]; then
        log_error "没有选择有效的文件"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation    # 即将退出动画
        return 1
    fi
    
    echo -e "${gl_bai}选择的文件:${gl_bai}"
    for file in "${selected_files[@]}"; do
        local file_size
        file_size=$(stat -c%s "$file" 2>/dev/null || echo "0")
        local size_display
        
        if [[ $file_size -ge 1073741824 ]]; then
            size_display=$(echo "scale=2; $file_size/1073741824" | bc)G
        elif [[ $file_size -ge 1048576 ]]; then
            size_display=$(echo "scale=2; $file_size/1048576" | bc)M
        elif [[ $file_size -ge 1024 ]]; then
            size_display=$(echo "scale=2; $file_size/1024" | bc)K
        else
            size_display="${file_size}B"
        fi
        
        echo -e "  ${gl_bufan}• ${gl_bai}$(basename "$file") (${gl_huang}$size_display${gl_bai})"
    done
    
    read -r -e -p "$(echo -e "${gl_bai}确认下载 ${gl_huang}${#selected_files[@]} ${gl_bai}个文件? (${gl_lv}y${gl_bai}/${gl_hong}n${gl_bai}): ")" confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        log_info "开始批量下载文件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_huang}请在本地客户端接收文件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        
        for i in {2..1}; do
            echo -ne "${gl_huang}将在 ${gl_lv}$i${gl_bai} 秒后开始${gl_bai}\r"
            sleep_fractional 1
        done
        echo ""
        
        if sz "${selected_files[@]}"; then
            log_ok "批量下载完成!"
        else
            if [[ $? -eq 130 ]]; then
                log_info "下载被用户取消"
            else
                log_warn "批量下载可能被中断"
            fi
        fi
    else
        log_info "取消下载操作"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

###### 批量上传多个文件
rz_upload_files_batch() {
    clear
    echo -e "${gl_zi}>>> 批量上传多个文件${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_info "可以一次选择多个文件上传"
    echo -e "${gl_bai}支持批量上传多个文件到当前目录${gl_bai}"
    echo -e "${gl_huang}注意: 请确保终端支持Zmodem批量上传${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    read -r -e -p "$(echo -e "${gl_bai}是否继续? (${gl_lv}y${gl_bai}/${gl_hong}n${gl_bai}): ")" confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        echo -e "${gl_bai}使用命令: ${gl_zi}rz -bye${gl_bai}"
        echo -e "${gl_huang}请在本地客户端选择多个文件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_huang}提示: 按${gl_bai}Ctrl+C${gl_huang}取消上传${gl_bai}"
        
        for i in {2..1}; do
            echo -ne "${gl_huang}将在 ${gl_lv}$i${gl_bai} 秒后弹出文件选择对话框${gl_bai}\r"
            sleep_fractional 1
        done
        echo ""
        
        if command -v rz >/dev/null 2>&1; then
            # 尝试使用rz的批量上传参数
            if rz -bye 2>/dev/null; then
                log_ok "批量上传完成!"
                
                # 显示上传的文件
                echo -e "${gl_bai}最近上传的文件:${gl_bai}"
                ls -lt --color=always 2>/dev/null | head -6
            else
                if [[ $? -eq 130 ]]; then
                    log_info "上传被用户取消"
                else
                    log_warn "批量上传失败，尝试普通上传模式 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                    if rz; then
                        log_ok "文件上传完成!"
                    else
                        log_warn "文件上传可能被取消"
                    fi
                fi
            fi
        else
            log_error "rz命令不可用"
        fi
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

###### 检查终端Zmodem支持函数
rz_check_zmodem_support() {
    clear
    echo -e "${gl_zi}>>> 检查终端Zmodem支持${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    echo -e "${gl_bai}Zmodem协议支持检测:${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    # 检查工具安装
    if command -v sz >/dev/null 2>&1 && command -v rz >/dev/null 2>&1; then
        echo -e "  ${gl_lv}✓ ${gl_bai}lrzsz已安装: ${gl_huang}$(sz --version 2>&1 | head -1)${gl_bai}"
    else
        echo -e "  ${gl_hong}✗ ${gl_bai}lrzsz未安装"
    fi
    
    # 检查当前终端
    if [[ -n "$SSH_TTY" ]]; then
        echo -e "  ${gl_lv}✓ ${gl_bai}通过SSH连接${gl_bai}"
    else
        echo -e "  ${gl_huang}⚠ ${gl_bai}非SSH连接，Zmodem可能不可用${gl_bai}"
    fi
    
    # 终端支持列表
    echo -e "${gl_bai}支持的终端软件:${gl_bai}"
    echo -e "  ${gl_bufan}• ${gl_lv}MobaXterm${gl_bai} - 内置完美支持"
    echo -e "  ${gl_bufan}• ${gl_lv}Xshell${gl_bai} - 需要启用ZMODEM选项"
    echo -e "  ${gl_bufan}• ${gl_lv}SecureCRT${gl_bai} - 需要配置ZMODEM"
    echo -e "  ${gl_bufan}• ${gl_lv}Tabby${gl_bai} - 需要安装Zmodem插件"
    echo -e "  ${gl_bufan}• ${gl_lv}WindTerm${gl_bai} - 内置支持"
    echo -e "  ${gl_bufan}• ${gl_lv}FinalShell${gl_bai} - 内置支持"
    echo -e "  ${gl_huang}⚠ ${gl_bai}PuTTY${gl_bai} - 不支持Zmodem协议"
    echo -e "  ${gl_huang}⚠ ${gl_bai}Windows Terminal${gl_bai} - 需要额外配置"
    
    # 快速测试
    echo -e "${gl_bai}快速测试:${gl_bai}"
    echo -e "  ${gl_bufan}1. ${gl_bai}上传测试: ${gl_zi}echo 'test' > test.txt && sz test.txt${gl_bai}"
    echo -e "  ${gl_bufan}2. ${gl_bai}下载测试: ${gl_zi}rz (然后选择文件)${gl_bai}"
    
    echo -e "${gl_bai}其他传输方式:${gl_bai}"
    echo -e "  ${gl_bufan}• ${gl_bai}SCP: ${gl_zi}scp user@host:file .${gl_bai}"
    echo -e "  ${gl_bufan}• ${gl_bai}SFTP: ${gl_zi}sftp user@host${gl_bai}"
    echo -e "  ${gl_bufan}• ${gl_bai}HTTP: ${gl_zi}python3 -m http.server${gl_bai}"
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}是否创建测试文件? (${gl_lv}y${gl_bai}/${gl_hong}n${gl_bai}): ")" test_choice
    if [[ "$test_choice" == "y" || "$test_choice" == "Y" ]]; then
        echo "这是一个Zmodem传输测试文件，创建于: $(date)" > zmodem_test.txt
        echo "文件大小: 1KB" >> zmodem_test.txt
        echo "用于测试Zmodem文件传输功能" >> zmodem_test.txt
        # 填充到1KB
        dd if=/dev/zero bs=1k count=1 2>/dev/null >> zmodem_test.txt
        log_ok "测试文件已创建: ${gl_huang}zmodem_test.txt${gl_bai}"
        echo -e "${gl_bai}使用命令测试: ${gl_zi}sz zmodem_test.txt${gl_bai}"
    fi
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

###### 查看传输历史记录函数
rz_view_transfer_history() {
    clear
    echo -e "${gl_zi}>>> 查看传输历史记录${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    # 检查最近修改的文件
    echo -e "${gl_bai}最近修改的文件 (可能是上传的文件):${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    find . -maxdepth 1 -type f -printf "%T+ %p\n" 2>/dev/null | sort -r | head -10 | while read -r line; do
        local file_date file_name
        file_date=$(echo "$line" | awk '{print $1" "$2}' | cut -d'.' -f1)
        file_name=$(echo "$line" | awk '{for(i=2;i<=NF;i++) printf $i" "}' | sed 's/ $//')
        local file_size
        file_size=$(stat -c%s "$file_name" 2>/dev/null || echo "0")
        local size_display
        
        if [[ $file_size -ge 1073741824 ]]; then
            size_display=$(echo "scale=2; $file_size/1073741824" | bc)G
        elif [[ $file_size -ge 1048576 ]]; then
            size_display=$(echo "scale=2; $file_size/1048576" | bc)M
        elif [[ $file_size -ge 1024 ]]; then
            size_display=$(echo "scale=2; $file_size/1024" | bc)K
        else
            size_display="${file_size}B"
        fi
        
        printf "${gl_bai}%-20s ${gl_huang}%8s ${gl_lv}%s\n" "$file_date" "$size_display" "$(basename "$file_name")"
    done
    
    # 检查大文件
    echo -e "${gl_bai}当前目录中大文件 (>10MB):${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    find . -maxdepth 1 -type f -size +10M 2>/dev/null | while read -r file; do
        local file_size
        file_size=$(stat -c%s "$file" 2>/dev/null || echo "0")
        local size_display
        
        if [[ $file_size -ge 1073741824 ]]; then
            size_display=$(echo "scale=2; $file_size/1073741824" | bc)G
        elif [[ $file_size -ge 1048576 ]]; then
            size_display=$(echo "scale=2; $file_size/1048576" | bc)M
        fi
        
        printf "${gl_bai}%-40s ${gl_huang}%8s\n" "$(basename "$file")" "$size_display"
    done | head -5
    
    # 统计文件信息
    local total_size
    total_size=$(find . -maxdepth 1 -type f -exec stat -c%s {} \; 2>/dev/null | awk '{sum+=$1} END {print sum}')
    local total_files
    total_files=$(find . -maxdepth 1 -type f 2>/dev/null | wc -l)
    local total_size_display
    
    if [[ $total_size -ge 1073741824 ]]; then
        total_size_display=$(echo "scale=2; $total_size/1073741824" | bc)GB
    elif [[ $total_size -ge 1048576 ]]; then
        total_size_display=$(echo "scale=2; $total_size/1048576" | bc)MB
    elif [[ $total_size -ge 1024 ]]; then
        total_size_display=$(echo "scale=2; $total_size/1024" | bc)KB
    else
        total_size_display="${total_size}B"
    fi
    
    echo -e "${gl_bai}统计信息:${gl_bai}"
    echo -e "  ${gl_bufan}• ${gl_bai}文件总数: ${gl_huang}${total_files}${gl_bai} 个"
    echo -e "  ${gl_bufan}• ${gl_bai}总大小: ${gl_huang}${total_size_display}${gl_bai}"
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}按回车键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}")"
    break_end
}

###### 清理临时文件
rz_clean_temp_files() {
    clear
    echo -e "${gl_zi}>>> 清理临时文件${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    # 查找常见的临时文件
    echo -e "${gl_bai}正在查找临时文件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    local temp_files=()
    while IFS= read -r -d '' file; do
        temp_files+=("$file")
    done < <(find . -maxdepth 1 -type f \( -name "*.tmp" -o -name "*.temp" -o -name "*.swp" -o -name "*.swo" -o -name "*~" -o -name ".#*" \) -print0 2>/dev/null)
    
    if [[ ${#temp_files[@]} -gt 0 ]]; then
        echo -e "${gl_bai}找到以下临时文件:${gl_bai}"
        for file in "${temp_files[@]}"; do
            local file_size
            file_size=$(stat -c%s "$file" 2>/dev/null || echo "0")
            local size_display
            
            if [[ $file_size -ge 1048576 ]]; then
                size_display=$(echo "scale=2; $file_size/1048576" | bc)M
            elif [[ $file_size -ge 1024 ]]; then
                size_display=$(echo "scale=2; $file_size/1024" | bc)K
            else
                size_display="${file_size}B"
            fi
            
            printf "  ${gl_bufan}• ${gl_bai}%-40s ${gl_huang}%8s\n" "$(basename "$file")" "$size_display"
        done
        
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}是否删除这些临时文件? (${gl_lv}y${gl_bai}/${gl_hong}n${gl_bai}): ")" delete_choice
        
        if [[ "$delete_choice" == "y" || "$delete_choice" == "Y" ]]; then
            local deleted_count=0
            local deleted_size=0
            
            for file in "${temp_files[@]}"; do
                local file_size
                file_size=$(stat -c%s "$file" 2>/dev/null || echo "0")
                if rm -f "$file" 2>/dev/null; then
                    ((deleted_count++))
                    deleted_size=$((deleted_size + file_size))
                fi
            done
            
            local deleted_size_display
            if [[ $deleted_size -ge 1048576 ]]; then
                deleted_size_display=$(echo "scale=2; $deleted_size/1048576" | bc)MB
            elif [[ $deleted_size -ge 1024 ]]; then
                deleted_size_display=$(echo "scale=2; $deleted_size/1024" | bc)KB
            else
                deleted_size_display="${deleted_size}B"
            fi
            
            log_ok "已删除 ${gl_huang}${deleted_count}${gl_bai} 个临时文件，释放空间: ${gl_huang}${deleted_size_display}${gl_bai}"
        else
            log_info "取消删除临时文件"
        fi
    else
        log_info "未找到临时文件"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

###### 创建测试文件
rz_create_test_files() {
    clear
    echo -e "${gl_zi}>>> 创建测试文件${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    echo -e "${gl_bai}创建测试文件用于测试Zmodem传输:${gl_bai}"
    echo -e "${gl_bufan}1. ${gl_bai}创建小文件 (1KB)"
    echo -e "${gl_bufan}2. ${gl_bai}创建中文件 (1MB)"
    echo -e "${gl_bufan}3. ${gl_bai}创建大文件 (10MB)"
    echo -e "${gl_bufan}4. ${gl_bai}创建随机文件"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    read -r -e -p "$(echo -e "${gl_bai}请选择 [1-4]: ")" test_choice
    
    case $test_choice in
        1)
            echo "Zmodem测试文件 - 小文件 (1KB)" > test_small.txt
            echo "创建时间: $(date)" >> test_small.txt
            dd if=/dev/zero bs=1k count=1 2>/dev/null >> test_small.txt
            log_ok "已创建测试文件: ${gl_huang}test_small.txt${gl_bai} (1KB)"
            ;;
        2)
            echo "Zmodem测试文件 - 中文件 (1MB)" > test_medium.txt
            echo "创建时间: $(date)" >> test_medium.txt
            dd if=/dev/zero bs=1M count=1 2>/dev/null >> test_medium.txt
            log_ok "已创建测试文件: ${gl_huang}test_medium.txt${gl_bai} (1MB)"
            ;;
        3)
            echo "Zmodem测试文件 - 大文件 (10MB)" > test_large.txt
            echo "创建时间: $(date)" >> test_large.txt
            dd if=/dev/zero bs=1M count=10 2>/dev/null >> test_large.txt
            log_ok "已创建测试文件: ${gl_huang}test_large.txt${gl_bai} (10MB)"
            ;;
        4)
            read -r -e -p "$(echo -e "${gl_bai}请输入文件大小 (如: 1K, 1M, 10M): ")" size
            echo "Zmodem测试文件 - 随机文件 (${size})" > "test_random_${size}.txt"
            echo "创建时间: $(date)" >> "test_random_${size}.txt"
            
            if dd if=/dev/urandom bs="${size}" count=1 2>/dev/null >> "test_random_${size}.txt"; then
                log_ok "已创建测试文件: ${gl_huang}test_random_${size}.txt${gl_bai} (${size})"
            else
                log_error "创建文件失败，请检查输入格式 (如: 1K, 1M, 10M)"
            fi
            ;;
        0) cancel_return; return ;;    # 返回到上一级菜单
        *) handle_invalid_input ;;      # 无效的输入,请重新输入!
    esac
    
    if [[ -f "test_"*".txt" ]]; then
        echo -e "${gl_bai}测试文件信息:${gl_bai}"
        ls -lh test_*.txt 2>/dev/null
        
        read -r -e -p "$(echo -e "${gl_bai}是否立即测试下载? (${gl_lv}y${gl_bai}/${gl_hong}n${gl_bai}): ")" download_test
        if [[ "$download_test" == "y" || "$download_test" == "Y" ]]; then
            for i in {2..1}; do
                echo -ne "${gl_huang}将在 ${gl_lv}$i${gl_bai} 秒后开始下载测试文件${gl_bai}\r"
                sleep_fractional 1
            done
            echo ""
            
            sz test_*.txt
        fi
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_dir_colorful() {
    # ---- 参数处理 ----
    local show_hidden="${1:-0}"
    local user_cols="${2:-0}"
    local files=()
    local has_content=0
    local item
    
    # 文件类型 → 颜色 关联表（使用你定义的颜色变量）
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
    
    # 获取文件列表（兼容旧版 Bash）
    if [[ "${show_hidden}" -eq 1 ]]; then
        # 显示隐藏文件：使用 ls -A 再过滤，或逐个检查
        while IFS= read -r item; do
            [[ -e "${item}" || -L "${item}" ]] && {
                files+=("${item}")
                has_content=1
            }
        done < <(ls -A 2>/dev/null)
    else
        # 不显示隐藏文件
        for item in *; do
            [[ -e "${item}" || -L "${item}" ]] && {
                files+=("${item}")
                has_content=1
            }
        done 2>/dev/null
    fi
    
    # 输出标题
    echo -e "${gl_huang}>>> 当前目录文件列表：${gl_bai}(${gl_lv}$(pwd)${gl_bai})"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    # 空目录处理
    if [[ ${has_content} -eq 0 ]]; then
        echo -e "${gl_huang}当前目录为空${gl_bai}"
        return 0
    fi
    
    # ---- 预计算文件信息 ----
    local file_info=()
    local max_display_width=0
    
    for item in "${files[@]}"; do
        local color="" suffix=""
        
        # 判断文件类型
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
        
        # 计算显示宽度（正确处理中文等宽字符）
        if command -v wc &>/dev/null; then
            display_width=$(printf "%s" "${display_str}" | wc -L 2>/dev/null || echo "${#display_str}")
        else
            display_width=${#display_str}
        fi
        
        (( display_width > max_display_width )) && max_display_width=${display_width}
        
        # 存储：0=原名, 1=颜色, 2=后缀, 3=显示宽度, 4=完整显示串
        file_info+=("${item}" "${color}" "${suffix}" "${display_width}" "${display_str}")
    done
    
    # ---- 计算布局 ----
    local term_width
    term_width=$(tput cols 2>/dev/null || echo 80)
    
    # 列宽 = 最大显示宽度 + 4字符间隔
    local col_width=$((max_display_width + 4))
    
    # 确定列数
    local items_per_line
    if [[ ${user_cols} -gt 0 ]]; then
        items_per_line=${user_cols}
        # 检查是否超出终端宽度，如果是则调整为最大可用列数
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
    
    # ---- 输出文件（行优先：横向阅读顺序） ----
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
                
                # 计算填充空格数
                padding=$((col_width - file_width))
                
                # 输出彩色文件名（颜色码不占用显示宽度）
                printf "%b%s%b" "${file_color}" "${file_name}${file_suffix}" "${gl_bai}"
                
                # 填充空格（最后一列不填充间隔）
                if ((col < items_per_line - 1 && index < total_items - 1)); then
                    printf "%*s" "${padding}" ""
                fi
            fi
        done
        echo
    done
    
    # ---- 统计信息 ----
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

# 文件传输管理器 - 支持sz/rz本地与服务器互传
file_transfer_manager() {
    while true; do
        install lrzsz bc
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
        echo -e "${gl_zi}>>> 文件传输管理器 (Zmodem)${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}上传文件到服务器 ${gl_huang}★${gl_bai}    ${gl_bufan}2.  ${gl_bai}下载文件到本地 ${gl_huang}★${gl_bai}"
        echo -e "${gl_bufan}3.  ${gl_bai}选择文件下载          ${gl_bufan}4.  ${gl_bai}批量上传多个文件"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}5.  ${gl_bai}上传文件夹${gl_huang}压缩包${gl_bai}      ${gl_bufan}6.  ${gl_bai}下载文件夹${gl_huang}压缩包${gl_bai}"
        echo -e "${gl_bufan}7.  ${gl_bai}创建测试文件          ${gl_bufan}8.  ${gl_bai}清理临时文件"
        echo -e "${gl_bufan}9.  ${gl_bai}检查终端Zmodem支持    ${gl_bufan}10. ${gl_bai}查看传输历史记录"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_hong}0.  ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" choice
        
        case $choice in
        1)  rz_upload_file; continue ;;                              # 上传文件到服务器
        2)  rz_download_files_to_local; continue ;;                  # 下载文件到本地
        3)  rz_download_files_interactive; continue ;;               # 选择文件下载
        4)  rz_upload_files_batch; continue ;;                       # 批量上传多个文件
        5)  rz_upload_compressed_file; continue ;;                   # 上传文件夹
        6)  rz_download_folder; continue ;;                          # 下载文件夹
        7)  rz_create_test_files; continue ;;                        # 创建测试文件
        8)  rz_clean_temp_files; continue ;;                         # 清理临时文件
        9)  rz_check_zmodem_support; continue ;;                     # 检查终端Zmodem支持
        10) rz_view_transfer_history; continue ;;                    # 查看传输历史记录
        0)  exit_script ;;                                           # 感谢使用，再见！
        *) handle_invalid_input ;;                                   # 无效的输入,请重新输入!
        esac
    done
}

file_transfer_manager