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
                # OpenWrt/iStoreOS的opkg检查
                if opkg list-installed | grep -q "^${pkg} "; then
                    installed=true
                    ver=$(opkg list-installed | grep "^${pkg} " | awk '{print $3}' 2>/dev/null || echo "")
                fi
            elif command -v dpkg-query &>/dev/null; then
                # Debian/Ubuntu
                if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
                    installed=true
                    ver=$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null || echo "")
                fi
            elif command -v rpm &>/dev/null; then
                # RedHat/CentOS
                if rpm -q "$pkg" &>/dev/null; then
                    installed=true
                    ver=$(rpm -q --qf '%{VERSION}' "$pkg" 2>/dev/null || echo "")
                fi
            elif command -v apk &>/dev/null; then
                # Alpine
                if apk info "$pkg" 2>/dev/null | grep -q "^installed"; then
                    installed=true
                    ver=$(apk info -a "$pkg" 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)+' | head -n1 || echo "")
                fi
            elif command -v pacman &>/dev/null; then
                # Arch/Manjaro
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
                # OpenWrt需要特殊处理7zip
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

extract_file() {
    local archive="$1" output_dir="${2:-.}" auto_yes="${3:-false}"

    [[ -f "$archive" ]] || {
        log_error "文件不存在：$archive"
        exit_animation
        return 1
    }

    [[ -d "$output_dir" ]] || {
        log_info "创建目录：$output_dir"
        mkdir -p "$output_dir"
    }

    local cmd=()
    case "$archive" in
    *.zip)
        [[ "$auto_yes" == "true" ]] && cmd=("unzip" "-o" "-q") || cmd=("unzip" "-q")
        command -v unzip &>/dev/null || { log_error "请安装 unzip"; exit_animation; return 1; }
        ;;
    *.7z)
        cmd=("7z" "x" "-y")
        command -v 7z &>/dev/null || { log_error "请安装 7z"; exit_animation; return 1; }
        ;;
    *.tar) cmd=("tar" "-xf") ;;
    *.tar.gz | *.tgz) cmd=("tar" "-zxf") ;;
    *.rar)
        if command -v unrar &>/dev/null; then cmd=("unrar" "x" "-inul")
        elif command -v rar &>/dev/null; then cmd=("rar" "x" "-inul")
        else log_error "请安装 unrar/rar"; exit_animation; return 1; fi
        ;;
    *.gz | *.img.gz) ;;
    *) log_error "不支持格式：$archive"; exit_animation; return 1 ;;
    esac

    log_info "正在解压：$archive → $output_dir"

    local result=0
    case "$archive" in
    *.zip) "${cmd[@]}" "$archive" -d "$output_dir"; result=$? ;;
    *.7z) "${cmd[@]}" "$archive" "-o$output_dir"; result=$? ;;
    *.tar | *.tar.gz | *.tgz) "${cmd[@]}" "$archive" -C "$output_dir"; result=$? ;;
    *.rar) "${cmd[@]}" "$archive" "$output_dir/"; result=$? ;;
    *.gz | *.img.gz)
        local target_file="$output_dir/$(basename "${archive%.gz}")"
        gzip -kd "$archive" > "$target_file" 2>/dev/null
        [[ -f "$target_file" && -s "$target_file" ]] && result=0 || result=1
        ;;
    esac

    [[ $result -eq 0 ]] && log_ok "解压完成！" || log_error "解压失败！"
    return $result
}

interactive_extract() {
    install unzip p7zip-full unrar
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
                for item in "${list[@]}"; do [[ "$item" == "$file" ]] && { exists=true; break; }; done
                [[ "$exists" == false ]] && list+=("$file")
            }
        done < <(find . -maxdepth 1 -type f -name "*.$ext" -print0 2>/dev/null)
    done

    if ((${#list[@]} == 0)); then
        log_warn "当前目录无压缩包"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bai}按任意键退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
        read -r -n1 -s
        exit_script
    fi

    IFS=$'\n' list=($(sort <<<"${list[*]}"))
    unset IFS

    echo -e "当前目录 ${gl_huang}$(pwd) ${gl_lv}可用压缩包：${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local count=0 items_per_line=2 max_length=0 term_width=$(tput cols 2>/dev/null || echo 80)
    ((term_width > 120)) && items_per_line=4
    ((term_width > 80 && term_width <=120)) && items_per_line=3

    for file in "${list[@]}"; do
        local len=${#file}
        ((len > max_length)) && max_length=$len
    done
    max_length=$((max_length + 4))

    for i in "${!list[@]}"; do
        count=$((count + 1))
        local file_ext="${list[i]##*.}"
        case "$file_ext" in
            zip|7z) printf "${gl_huang}%2d.${gl_bai} ${gl_lv}%-${max_length}s${gl_bai}" "$count" "${list[i]}" ;;
            tar*|tgz) printf "${gl_huang}%2d.${gl_bai} ${gl_zi}%-${max_length}s${gl_bai}" "$count" "${list[i]}" ;;
            gz) printf "${gl_huang}%2d.${gl_bai} ${gl_lan}%-${max_length}s${gl_bai}" "$count" "${list[i]}" ;;
            *) printf "${gl_huang}%2d.${gl_bai} ${gl_bai}%-${max_length}s" "$count" "${list[i]}" ;;
        esac
        ((count % items_per_line == 0)) && echo ""
    done
    ((count % items_per_line != 0)) && echo ""

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}请输入序号或文件名(${gl_huang}0 ${gl_bai}退出): ")" choice

    [[ -z "$choice" ]] && { echo -e "${gl_huang}已取消${gl_bai}"; return; }
    [[ "$choice" == "0" ]] && exit_script

    if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#list[@]})); then
        archive="${list[$((choice - 1))]}"
    else
        archive="$choice"
    fi

    [[ -f "$archive" ]] || { log_error "不存在：$archive"; return; }

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}解压到目录 (回车=当前): ")" dest
    dest="${dest:-.}"

    if [[ ! -d "$dest" ]]; then
        echo -e "${gl_huang}目录不存在，创建？(${gl_lv}y${gl_bai}/N) \c"
        read -r -n1 -s create_dir
        echo ""
        [[ $create_dir =~ ^[Yy]$ ]] && mkdir -p "$dest" || dest="."
    fi

    extract_file "$archive" "$dest" "false"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

main() {
    clear
    if [[ $# -ge 1 ]]; then
        local file="$1"
        local dir="${2:-.}"
        extract_file "$file" "$dir" "true"
        exit 0
    fi
    while true; do interactive_extract; done
}

main "$@"