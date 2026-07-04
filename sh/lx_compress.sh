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

compress_file() {
    local target="$1" format="$2" output_dir="${3:-.}"
    local archive_name="$output_dir/$(basename "$target").$format"

    [[ -e "$target" ]] || { log_error "不存在：$target"; return 1; }
    [[ -d "$output_dir" ]] || mkdir -p "$output_dir"

    log_info "正在压缩：$target → $archive_name"

    case "$format" in
        zip)    [[ -d "$target" ]] && zip -rq "$archive_name" "$target" || zip -q "$archive_name" "$target" ;;
        7z)     7z a -y "$archive_name" "$target" >/dev/null 2>&1 ;;
        tar)    tar -cf "$archive_name" "$target" ;;
        tar.gz) tar -zcf "$archive_name" "$target" ;;
        *)      log_error "不支持格式：$format"; return 1 ;;
    esac

    if [[ $? -eq 0 ]]; then
        log_ok "压缩完成！大小：$(du -h "$archive_name" | cut -f1)"
        return 0
    else
        log_error "压缩失败！"
        return 1
    fi
}

interactive_compress() {
    clear
    log_info "自动安装依赖工具：zip unzip 7z"
    install zip unzip p7zip-full

    while true; do
        clear
        echo -e "${gl_huang}>>> 当前目录：${gl_lv}$(pwd)${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        local list=() compress_ext=("zip" "7z" "tar" "tar.gz" "rar" "gz")
        for item in *; do
            [[ "$item" == .* || ! -e "$item" ]] && continue
            local skip=0
            for ext in "${compress_ext[@]}"; do
                [[ "$item" == *.$ext ]] && { skip=1; break; }
            done
            ((skip == 0)) && list+=("$item")
        done

        if ((${#list[@]} == 0)); then
            log_warn "无可压缩文件"
            exit_animation
            return
        fi

        display_horizontal_list list

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e ""
        echo -e "${gl_zi}>>> 压缩模式${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        safe_read "选择序号/输入名称 (${gl_huang}0${gl_bai}退出脚本): " choice "any"

        [[ -z "$choice" || "$choice" == "0" ]] && exit_script

        local target
        if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#list[@]})); then
            target="${list[$((choice-1))]}"
        else
            target="$choice"
        fi

        [[ -e "$target" ]] || { log_error "不存在：$target"; read -r -n1 -s; continue; }

        echo -e ""
        echo -e "${gl_huang}>>> 选择格式：${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}zip    ${gl_bufan}2.  ${gl_bai}7z    ${gl_bufan}3.  ${gl_bai}tar.gz   ${gl_bufan}4.  ${gl_bai}tar"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        safe_read "请输入你的选择: " fmt_idx "num"

        local format
        case "$fmt_idx" in
            1) format="zip" ;;
            2) format="7z" ;;
            3) format="tar.gz" ;;
            4) format="tar" ;;
            *) log_error "无效选择"; continue ;;
        esac

        echo -e ""
        echo -e "${gl_huang}>>> 选择输出目录${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        safe_read "请选择输出目录 (${gl_huang}默认当前${gl_bai}): " output_dir "any"
        output_dir="${output_dir:-.}"

        compress_file "$target" "$format" "$output_dir"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
    done
}

main() {
    if [[ $# -ge 2 ]]; then
        target="$1"
        fmt="$2"
        dir="${3:-.}"
        compress_file "$target" "$fmt" "$dir"
        exit 0
    fi
    interactive_compress
}

main "$@"