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

write_log() {
    local log_file="$1"
    local log_content="$2"
    echo -e "$log_content" >> "$log_file"
}

get_human_size() {
    local file_path="$1"
    if [[ -f "$file_path" ]]; then
        local size_bytes=$(stat -c%s "$file_path" 2>/dev/null || stat -f%z "$file_path" 2>/dev/null)
        if [[ -n "$size_bytes" ]]; then
            numfmt --to=iec-i --suffix=B "$size_bytes" 2>/dev/null || echo "${size_bytes}B"
        else
            echo "未知"
        fi
    else
        echo "文件不存在"
    fi
}

init_log_file() {
    local backup_dest_dir="$1"
    local logs_dir="${backup_dest_dir}/logs"
    mkdir -p "$logs_dir"
    local timestamp=$(date +"%Y-%m-%d-%H-%M-%S")
    local log_file="${logs_dir}/${timestamp}.log"
    touch "$log_file"
    echo "$log_file"
}

write_log_header() {
    local log_file="$1"
    local start_time="$2"
    local backup_type="$3"
    write_log "$log_file" ">>> ${backup_type}"
    write_log "$log_file" ""
    write_log "$log_file" "备份时间：    ${start_time}"
    write_log "$log_file" ""
}

write_log_footer() {
    local log_file="$1"
    local end_time="$2"
    local log_file_path="$3"
    write_log "$log_file" ""
    write_log "$log_file" "脚本结束时间：${end_time}"
    write_log "$log_file" "日志文件路径：${log_file_path}"
}

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

    local pkg mgr ver cmd_ver installed=false
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
    local items=("$@")
    local cols=4
    local count=0
    local max_len=0

    for item in "${items[@]}"; do
        local fname=$(basename "$item" 2>/dev/null || echo "$item")
        [[ ${#fname} -gt "$max_len" ]] && max_len=${#fname}
    done
    ((max_len += 2))

    for item in "${items[@]}"; do
        local fname=$(basename "$item" 2>/dev/null || echo "$item")
        printf "${gl_bufan}%2d.${gl_bai} ${gl_lv}%-*s${gl_bai} " $((count + 1)) "$max_len" "$fname"
        count=$((count + 1))
        if (( count % cols == 0 )); then
            echo
        fi
    done

    (( count % cols != 0 )) && echo
}

backup_single_compose_project() {
    local target="$1"
    local format="$2"
    local temp_dir="$3"
    local dest_dir="$4"
    local log_file="$5"
    local backup_start_time="$6"
    local is_batch_backup="$7"
    
    local backup_name="${target}.${format}"
    local backup_path="${dest_dir}/${backup_name}"
    local source_abs_path=$(cd "$(dirname "$target")" && pwd)/$(basename "$target")
    
    echo -e ""
    echo -e "${gl_huang}>>> 开始备份：${gl_lv}${target}${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_info "备份格式：${gl_lan}${format}${gl_bai}"
    log_info "备份路径：${gl_huang}${backup_path}${gl_bai}"

    case "$format" in
        tar.gz)
            tar -zcvf "$backup_path" -C "$(dirname "$target")" "$(basename "$target")" >/dev/null 2>&1
            ;;
        zip)
            zip -rq -o "$backup_path" "$target" >/dev/null 2>&1
            ;;
    esac

    if [[ -f "$backup_path" ]]; then
        local file_size=$(get_human_size "$backup_path")
        log_ok "备份成功！文件：${gl_lv}${backup_path}${gl_bai} (大小: ${file_size})"
        
        if [[ "$is_batch_backup" == "true" ]]; then
            write_log "$log_file" "  - $(basename "$target")"
            write_log "$log_file" "源文件目录：  ${source_abs_path}"
            write_log "$log_file" "备份文件路径：${backup_path}"
            write_log "$log_file" "压缩后大小：  ${file_size}"
            write_log "$log_file" ""
        else
            write_log "$log_file" "源文件目录：      ${source_abs_path}"
            write_log "$log_file" "备份文件路径：${backup_path}"
            write_log "$log_file" "压缩后大小：  ${file_size}"
        fi
    else
        log_error "备份失败！"
        if [[ "$is_batch_backup" == "true" ]]; then
            write_log "$log_file" "  - $(basename "$target")"
            write_log "$log_file" "源文件目录：${source_abs_path}"
            write_log "$log_file" "状态：        备份失败"
            write_log "$log_file" ""
        else
            write_log "$log_file" "源文件目录：${source_abs_path}"
            write_log "$log_file" "状态：        备份失败"
        fi
    fi
}

backup_all_compose_projects() {
    local log_file="$1"
    local fmt="$2"
    shift 2
    local projects=("$@")
    
    echo -e ""
    echo -e "${gl_zi}开始批量备份所有项目，共计：${gl_lv}${#projects[@]} ${gl_zi}个${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    write_log "$log_file" "批量备份项目列表："
    write_log "$log_file" "备份项目数量共计：${#projects[@]} 个"
    write_log "$log_file" ""
    
    for project in "${projects[@]}"; do
        backup_single_compose_project "$project" "$fmt" "$BACKUP_TEMP_DIR" "$BACKUP_DEST_DIR" "$log_file" "" "true"
    done
    
    echo -e ""
    log_ok "全部项目备份完成！"
}

get_backup_list() {
    local work_dir="$1"
    local -n out_list="$2"
    out_list=()
    local compress_extensions=("zip" "7z" "tar" "tar.gz" "tar.bz2" "tar.xz" "tgz" "tbz2" "txz" "rar" "gz" "bz2" "xz")

    cd "$work_dir" || return
    local item
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
        ((is_compressed == 0)) && out_list+=("$item")
    done

    for item in */; do
        if [[ -d "$item" && "$item" != .*/ && "$item" != "./" ]]; then
            item="${item%/}"
            local exists=0
            for existing in "${out_list[@]}"; do
                [[ "$existing" == "$item" ]] && exists=1 && break
            done
            ((exists == 0)) && out_list+=("$item")
        fi
    done

    if ((${#out_list[@]} > 0)); then
        IFS=$'\n' out_list=($(sort <<<"${out_list[*]}"))
        unset IFS
    fi
}

linux_dir_file_backup() {
    local DEFAULT_WORK_DIR="$(pwd)"
    local DEFAULT_BACKUP_DIR="/mnt/backup"
    local BACKUP_TEMP_DIR="/tmp"
    local LOG_FILE=""
    local SCRIPT_START_TIME=$(date +"%Y-%m-%d %H:%M:%S")
    local BACKUP_TYPE=""

    if [[ $# -eq 3 ]]; then
        local WORK_DIR="$1"
        local BACKUP_DEST_DIR="$2"
        local BACKUP_FMT="$3"

        if [[ "$BACKUP_FMT" != "tar.gz" && "$BACKUP_FMT" != "zip" ]]; then
            log_error "错误：仅支持 tar.gz / zip 两种格式"
            exit 1
        fi

        if [[ ! -d "$WORK_DIR" ]]; then
            log_error "工作目录不存在：${WORK_DIR}"
            exit 1
        fi
        mkdir -p "$BACKUP_DEST_DIR"

        install zip unzip tar

        local -a file_list
        get_backup_list "$WORK_DIR" file_list

        if ((${#file_list[@]} == 0)); then
            log_warn "目录内无可备份文件/目录，退出"
            exit 0
        fi

        LOG_FILE=$(init_log_file "$BACKUP_DEST_DIR")
        BACKUP_TYPE="传参免交互-全部批量备份"
        write_log_header "$LOG_FILE" "$SCRIPT_START_TIME" "$BACKUP_TYPE"

        cd "$WORK_DIR" || {
            log_error "无法进入工作目录：${WORK_DIR}"
            exit 1
        }
        backup_all_compose_projects "$LOG_FILE" "$BACKUP_FMT" "${file_list[@]}"

        local SCRIPT_END_TIME=$(date +"%Y-%m-%d %H:%M:%S")
        write_log_footer "$LOG_FILE" "$SCRIPT_END_TIME" "$LOG_FILE"
        log_ok "日志已保存至：${LOG_FILE}"
        log_ok "免交互备份任务执行完毕"
        exit 0
    fi

    local WORK_DIR BACKUP_DEST_DIR
    if [[ $# -ge 2 ]]; then
        WORK_DIR="$1"
        BACKUP_DEST_DIR="$2"
        log_info "使用命令行参数：工作目录=${WORK_DIR} 备份目录=${BACKUP_DEST_DIR}"
    else
        install zip unzip tar
        clear
        echo -e ""
        echo -e "${gl_zi}>>> 文件/目录 批量备份工具【${gl_huang}无时间戳+强制覆盖${gl_zi}】${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}未传参默认备份当前目录文件${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入工作目录 [回车默认: ${gl_lv}${DEFAULT_WORK_DIR}${gl_bai}] (${gl_hong}0${gl_bai}退出)：")" input_work
        WORK_DIR="${input_work:-$DEFAULT_WORK_DIR}"
        if [[ "$input_work" == "0" ]]; then
            exit_script
        fi
        
        read -r -e -p "$(echo -e "${gl_bai}请输入备份目录 [回车默认: ${gl_lv}${DEFAULT_BACKUP_DIR}${gl_bai}] (${gl_hong}0${gl_bai}退出)：")" input_backup
        BACKUP_DEST_DIR="${input_backup:-$DEFAULT_BACKUP_DIR}"
        if [[ "$input_backup" == "0" ]]; then
            exit_script
        fi
        
        log_info "已配置：工作目录=${WORK_DIR} 备份目录=${BACKUP_DEST_DIR}"
        sleep_fractional 1
    fi

    if [[ ! -d "$WORK_DIR" ]]; then
        log_error "工作目录不存在：${WORK_DIR}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        exit 0
    fi
    mkdir -p "$BACKUP_DEST_DIR"

    cd "$WORK_DIR" || {
        log_error "无法进入工作目录：${WORK_DIR}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        exit 0
    }

    while true; do
        install zip unzip tar
        clear
        echo -e "${gl_huang}>>> 当前${gl_bai}(${gl_lv}文件${gl_hong}/${gl_zi}目录${gl_bai})${gl_huang}列表：${gl_lv}$(pwd)${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        local list=() item i choice target fmt_idx format
        local compress_extensions=("zip" "7z" "tar" "tar.gz" "tar.bz2" "tar.xz" "tgz" "tbz2" "txz" "rar" "gz" "bz2" "xz")

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
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            exit 0
        fi
        
        display_horizontal_list "${list[@]}"

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e ""
        echo -e "${gl_zi}>>> 文件/目录批量备份工具【${gl_huang}无时间戳+强制覆盖${gl_zi}】${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bai}临时目录: ${gl_lv}$BACKUP_TEMP_DIR${gl_bai}"
        echo -e "${gl_bai}工作目录: ${gl_lv}$WORK_DIR${gl_bai}"
        echo -e "${gl_bai}备份目标: ${gl_lv}$BACKUP_DEST_DIR${gl_bai}"
        echo -e "${gl_huang}温馨提示: 输入序号备份单个项目，输入 ${gl_hong}666${gl_huang} 备份全部项目${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入序号选择，或手动输入${gl_bai}(${gl_lv}文件${gl_hong}/${gl_zi}目录${gl_bai}) (${gl_hong}0${gl_bai}退出): ")" choice

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

        LOG_FILE=$(init_log_file "$BACKUP_DEST_DIR")
        log_ok "日志文件已创建：${LOG_FILE}"

        if [[ -n "$LOG_FILE" ]] && [[ -f "$LOG_FILE" ]]; then
            if [[ "$choice" == "666" ]]; then
                BACKUP_TYPE="批量备份（全部项目）"
            else
                BACKUP_TYPE="独立备份"
            fi
            write_log_header "$LOG_FILE" "$SCRIPT_START_TIME" "$BACKUP_TYPE"
        fi

        if [[ "$choice" == "666" ]]; then
            echo -e ""
            echo -e "${gl_huang}请选择备份格式：${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_huang}1.${gl_bai} tar.gz (推荐)   ${gl_huang}2.${gl_bai} zip (通用)"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            read -r -e -p "请输入你的选择：" fmt_idx
            case "$fmt_idx" in
                1) format="tar.gz" ;;
                2) format="zip" ;;
                *)
                    echo -e "${gl_hong}无效序号！${gl_bai}"
                    read -r -n1 -s
                    continue
                    ;;
            esac

            backup_all_compose_projects "$LOG_FILE" "$format" "${list[@]}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            
            if [[ -n "$LOG_FILE" ]] && [[ -f "$LOG_FILE" ]]; then
                local SCRIPT_END_TIME=$(date +"%Y-%m-%d %H:%M:%S")
                write_log_footer "$LOG_FILE" "$SCRIPT_END_TIME" "$LOG_FILE"
                log_ok "日志已保存至：${LOG_FILE}"
            fi
            
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            continue
        fi

        if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#list[@]})); then
            target="${list[$((choice - 1))]}"
        else
            target="$choice"
        fi

        [[ -e "$target" ]] || {
        	echo -e ""
            echo -e "${gl_hong}错误：'$target' 不存在！${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            exit_animation
            continue
        }

        echo -e ""
        echo -e "${gl_huang}请选择备份格式：${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}1.${gl_bai} tar.gz (推荐)   ${gl_huang}2.${gl_bai} zip (通用)"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        read -r -e -p "请输入你的选择：" fmt_idx

        case "$fmt_idx" in
        1) format="tar.gz" ;;
        2) format="zip" ;;
        *)
            echo -e "${gl_hong}无效序号！${gl_bai}"
            echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            read -r -n1 -s
            continue
            ;;
        esac

        backup_single_compose_project "$target" "$format" "$BACKUP_TEMP_DIR" "$BACKUP_DEST_DIR" "$LOG_FILE" "$SCRIPT_START_TIME" "false"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        if [[ -n "$LOG_FILE" ]] && [[ -f "$LOG_FILE" ]]; then
            local SCRIPT_END_TIME=$(date +"%Y-%m-%d %H:%M:%S")
            write_log_footer "$LOG_FILE" "$SCRIPT_END_TIME" "$LOG_FILE"
            log_ok "日志已保存至：${LOG_FILE}"
        fi
        
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
    done
}

linux_dir_file_backup "$@"
