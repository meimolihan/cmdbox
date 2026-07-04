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

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n 1 -s
    echo ""
    clear
}

sleep_fractional() {
    local seconds=$1
    if sleep "$seconds" 2>/dev/null; then return 0; fi
    if command -v perl >/dev/null 2>&1; then perl -e "select(undef, undef, undef, $seconds)"; return 0; fi
    if command -v python3 >/dev/null 2>&1; then python3 -c "import time; time.sleep($seconds)"; return 0; fi
    if command -v python >/dev/null 2>&1; then python -c "import time; time.sleep($seconds)"; return 0; fi
    local int_seconds=$(awk -v s="$seconds" 'BEGIN{print int(s+0.999)}')
    sleep "$int_seconds"
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

display_horizontal_list() {
    local list=("${@}")
    local items_per_line="${display_cols:-3}"
    local min_spacing="${display_spacing:-2}"
    local max_length=0
    local count=0

    for item in "${list[@]}"; do
        local fname=$(basename "$item")
        local len=${#fname}
        ((len > max_length)) && max_length=$len
    done

    local term_width=$(tput cols 2>/dev/null || echo 80)
    local col_spacing=$((min_spacing + 2))

    if ((term_width > 0)); then
        local max_cols=10
        local found_optimal=false

        for ((cols = 10; cols >= 1; cols--)); do
            local col_width=$((max_length + 4 + col_spacing))
            local total_width=$((col_width * cols))

            if ((total_width <= term_width)); then
                items_per_line=$cols
                found_optimal=true
                break
            fi
        done

        if [[ "$found_optimal" == false ]]; then
            items_per_line=1
            col_spacing=2
        fi
    fi

    for i in "${!list[@]}"; do
        count=$((count + 1))
        local fname=$(basename "${list[$i]}")
        local item_width=$((max_length + col_spacing))
        printf "${gl_bufan}%2d.${gl_bai} ${gl_lv}%-${item_width}s${gl_bai}" "$count" "${fname}"
        if ((count % items_per_line == 0)); then echo ""; fi
    done
    ((count % items_per_line != 0)) && echo ""
}

restore_single_file() {
    local archive="$1"
    local dest_dir="$2"

    log_info "开始恢复：$(basename "$archive")"
    log_info "恢复路径：${dest_dir}"

    mkdir -p "$dest_dir"
    local success=false

    if [[ "$archive" == *.tar.gz ]]; then
        tar -zxvf "$archive" -C "$dest_dir" >/dev/null 2>&1 && success=true
    elif [[ "$archive" == *.zip ]]; then
        unzip -o "$archive" -d "$dest_dir" >/dev/null 2>&1 && success=true
    fi

    if [[ "$success" == true ]]; then
        log_ok "恢复成功！原始目录结构已还原"
    else
        log_error "恢复失败！"
    fi
}

linux_dir_file_restore() {
    local DEFAULT_BACKUP_DIR="$(pwd)"
    local DEFAULT_RESTORE_DIR="/mnt/data"
    local archive_list=()

    install zip unzip tar
    clear

    # ===================== 传参只赋值，不自动恢复 =====================
    if [[ $# -ge 2 ]]; then
        BACKUP_DIR="$1"
        RESTORE_DIR="$2"
    else
        # 无参，正常交互式输入
        echo -e "${gl_huang}>>> 当前目录：${gl_lv}$(pwd)${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入备份文件所在目录 [回车默认: ${gl_lv}当前目录${gl_bai}] (${gl_hong}0${gl_bai}退出)：")" input_backup_dir
        BACKUP_DIR="${input_backup_dir:-$DEFAULT_BACKUP_DIR}"
        [[ "$BACKUP_DIR" == "0" ]] && exit_script

        read -r -e -p "$(echo -e "${gl_bai}请输入恢复文件的路径 [回车默认: ${gl_lv}/mnt/data${gl_bai}] (${gl_hong}0${gl_bai}退出)：")" input_restore_dir
        RESTORE_DIR="${input_restore_dir:-$DEFAULT_RESTORE_DIR}"
        [[ "$RESTORE_DIR" == "0" ]] && exit_script
    fi

    [[ ! -d "$BACKUP_DIR" ]] && { log_error "目录不存在：${BACKUP_DIR}"; exit 1; }
    mkdir -p "$RESTORE_DIR"

    shopt -s nullglob
    archive_list=("$BACKUP_DIR"/*.tar.gz "$BACKUP_DIR"/*.zip)
    
    if [[ ${#archive_list[@]} -eq 0 ]]; then
        log_error "未找到任何备份文件！"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bai}按任意键退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
        read -r -n 1 -s
        clear
        exit 0
    fi

    # ===================== 统一进入交互式选择 =====================
    while true; do
        clear
        echo -e "${gl_huang}>>> 备份文件列表${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        display_horizontal_list "${archive_list[@]}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e ""
        echo -e "${gl_zi}>>> 恢复备份工具${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bai}备份目录: ${gl_lv}${BACKUP_DIR}"
        echo -e "${gl_bai}恢复目录: ${gl_lv}${RESTORE_DIR}"
        echo -e "${gl_huang}温馨提示: 输入序号恢复单个，输入 ${gl_hong}999${gl_huang} 恢复所有，输入 ${gl_hong}0${gl_huang} 退出${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        read -r -e -p "请输入你的选择：" choice

        if [[ -z "$choice" ]]; then
            echo -ne "${gl_hong}输入为空请重新输入 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
            sleep_fractional 0.5
            echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
            sleep_fractional 0.6
            continue
        fi

        if [[ "$choice" == "0" ]]; then
            exit_script
        fi

        if [[ "$choice" == "999" ]]; then
            log_info "开始批量恢复所有备份文件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            for arc in "${archive_list[@]}"; do
                restore_single_file "$arc" "$RESTORE_DIR"
            done
            log_ok "✅ 全部恢复完成！"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            continue
        fi

        if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#archive_list[@]})); then
            local target="${archive_list[$((choice - 1))]}"
            restore_single_file "$target" "$RESTORE_DIR"
        else
            log_error "输入无效！"
            sleep_fractional 1
        fi
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
    done
}

linux_dir_file_restore "$@"