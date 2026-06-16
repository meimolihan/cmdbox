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

log_info()  { echo -e "${gl_lan}[信息]${gl_bai} $*"; }
log_ok()    { echo -e "${gl_lv}[成功]${gl_bai} $*"; }
log_warn()  { echo -e "${gl_huang}[警告]${gl_bai} $*"; }
log_error() { echo -e "${gl_hong}[错误]${gl_bai} $*" >&2; }

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
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
    if command -v perl >/dev/null 2>&1; then perl -e "select(undef, undef, undef, $seconds)"; return 0; fi
    if command -v python3 >/dev/null 2>&1; then python3 -c "import time; time.sleep($seconds)"; return 0; fi
    if command -v python >/dev/null 2>&1; then python -c "import time; time.sleep($seconds)"; return 0; fi
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
    echo -ne "${gl_lv}即将返回 ${gl_huang}${menu_name} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
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
    continue
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

edit_crontab() {
    clear
    echo -e "${gl_zi}>>> 编辑cron文件${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if ! command -v crontab &>/dev/null; then
        log_error "crontab命令不存在，请检查系统"
        exit_animation
        return 1
    fi

    echo -e "${gl_bai}正在打开${gl_lv}crontab${gl_bai}编辑器 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    log_warn "请谨慎编辑，保存后更改将立即生效"

    if crontab -e; then
        log_ok "crontab编辑完成"
    else
        log_error "crontab编辑失败"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
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

column_if_available() {
    if command -v column &> /dev/null; then
        column -t -s $'\t'
    else
        cat
    fi
}

list_beautify_linux_crontab() {
    {
        printf "%s%-12s\t%-8s\t%-8s\t%-8s\t%-12s\t%-40s%s\n" \
            "$gl_hui" "分钟" "小时" "日期" "月份" "星期" "执行命令" "$reset"
        printf "%s%-12s\t%-8s\t%-8s\t%-8s\t%-12s\t%-40s%s\n" \
            "$gl_hui" "------------" "--------" "--------" "--------" "------------" "----------------------------------------" "$reset"

        crontab -l 2>/dev/null | grep -v '^#' | awk NF | \
            awk -v green="$gl_lv" -v yellow="$gl_huang" \
                -v blue="$gl_lan" -v reset="$reset" '
        BEGIN {OFS="\t"}
        {
            if ($1 ~ /^@/) {
                minute = $1
                hour = ""
                day = ""
                month = ""
                week = ""
                cmd = substr($0, index($0, $2))
            } else {
                minute = $1
                hour = $2
                day = $3
                month = $4
                week = $5
                cmd = substr($0, index($0, $6))
            }
            printf "%s%-12s%s\t%s%-8s%s\t%s%-8s%s\t%s%-8s%s\t%s%-12s%s\t%s%-40s%s\n",
                blue, minute, reset,
                yellow, hour, reset,
                blue, day, reset,
                yellow, month, reset,
                blue, week, reset,
                green, cmd, reset
        }'
    } | column_if_available
}

list_beautify_all() {
    clear
    echo -e "${gl_zi}>>> Linux定时任务列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_linux_crontab
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

local_init_globals() {
    LOCAL_SYNC_CONFIG="$HOME/.local_rsync_tasks"

    mkdir -p "$(dirname "$LOCAL_SYNC_CONFIG")" 2>/dev/null || {
        echo -e "${gl_hong}错误: 无法创建配置目录${gl_bai}"
        return 1
    }
    return 0
}

local_list_tasks() {
    local_init_globals || return 1

    echo "已保存的本地同步任务:"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    if [[ -f "$LOCAL_SYNC_CONFIG" ]] && [[ -s "$LOCAL_SYNC_CONFIG" ]]; then
        local line_num=1
        while IFS='|' read -r name source target options; do
            printf "${gl_bufan}%3d. ${gl_bai}- ${gl_zi}%-10s${gl_bai} ( ${gl_huang}%s${gl_bai} -> ${gl_lv}%s${gl_bai} )\n" \
                "$line_num" "$name" "$source" "$target"
            ((line_num++))
        done <"$LOCAL_SYNC_CONFIG"
    else
        echo -e "${gl_huang}暂无同步任务${gl_bai}"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
}

local_add_task() {
    local_init_globals || return 1

    echo "创建新本地同步任务示例："
    echo -e "  ${gl_bai}- 任务名称: ${gl_huang}backup_www${gl_bai}"
    echo -e "  ${gl_bai}- 源目录: ${gl_huang}/var/www${gl_bai}"
    echo -e "  ${gl_bai}- 目标目录: ${gl_huang}/backup/www${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local name source_path target_path options

    while true; do
        read -r -e -p "$(echo -e "${gl_bai}请输入任务名称(${gl_huang}0${gl_bai})返回: ")" name
        [ "$name" = "0" ] && { cancel_return "上一级选单"; return 1; }
        if [[ -z "$name" ]]; then
            echo -e "${gl_hong}错误: 任务名称不能为空${gl_bai}"
            continue
        fi
        
        if [[ -f "$LOCAL_SYNC_CONFIG" ]] && grep -q "^$name|" "$LOCAL_SYNC_CONFIG"; then
            echo -e "${gl_hong}错误: 任务名称已存在，请重新输入${gl_bai}"
            continue
        fi
        break
    done

    while true; do
        read -r -e -p "请输入源目录: " source_path
        if [[ -z "$source_path" ]]; then
            echo -e "${gl_hong}错误: 源目录不能为空${gl_bai}"
            continue
        fi
        
        if [[ ! -d "$source_path" ]]; then
            echo -e "${gl_huang}警告: 源目录不存在，请确认路径是否正确${gl_bai}"
            read -r -e -p "是否继续创建任务? (y/n): " confirm
            if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
                continue
            fi
        fi
        break
    done

    while true; do
        read -r -e -p "请输入目标目录: " target_path
        if [[ -z "$target_path" ]]; then
            echo -e "${gl_hong}错误: 目标目录不能为空${gl_bai}"
            continue
        fi
        break
    done

    source_path="${source_path%/}/"
    target_path="${target_path%/}/"

    echo ""
    echo -e "${gl_huang}>>> 请选择同步模式"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bufan}1. ${gl_bai}标准模式 (-avhz --progress) - 增量同步，保留文件属性"
    echo -e "${gl_bufan}2. ${gl_bai}安全模式 (-avhz --progress --delete-delay) - 删除目标中多余文件"
    echo -e "${gl_bufan}3. ${gl_bai}严格模式 (-avhz --progress --delete --checksum) - 校验文件内容"
    echo -e "${gl_bufan}4. ${gl_bai}快速模式 (-avh) - 基本同步，不压缩"
    echo -e "${gl_bufan}5. ${gl_bai}权限友好模式 (-avh --no-perms --no-owner --no-group) - 忽略权限问题"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "请输入你的选择: " mode

    case $mode in
    1) options="-avhz --progress" ;;
    2) options="-avhz --progress --delete-delay" ;;
    3) options="-avhz --progress --delete --checksum" ;;
    4) options="-avh" ;;
    5) options="-avh --no-perms --no-owner --no-group" ;;
    *)
        echo "无效选择，使用标准模式 -avhz --progress"
        options="-avhz --progress"
        ;;
    esac

    echo ""
    echo -e "${gl_huang}>>> 高级选项"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bufan}1. ${gl_bai}限速同步 (避免影响系统性能)"
    echo -e "${gl_bufan}2. ${gl_bai}排除特定文件类型"
    echo -e "${gl_bufan}3. ${gl_bai}排除Windows系统目录 (解决权限问题)"
    echo -e "${gl_bufan}4. ${gl_bai}跳过高级选项"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "请输入你的选择: " advanced_opt

    case $advanced_opt in
    1)
        read -r -e -p "请输入限速值 (单位: KB/s): " speed_limit
        if [[ "$speed_limit" =~ ^[0-9]+$ ]]; then
            options="$options --bwlimit=$speed_limit"
            echo -e "${gl_lv}已设置限速: ${speed_limit}KB/s${gl_bai}"
        else
            echo -e "${gl_hong}无效的限速值，跳过限速设置${gl_bai}"
        fi
        ;;
    2)
        read -r -e -p "请输入要排除的文件模式 (如: *.tmp,*.log): " exclude_patterns
        if [[ -n "$exclude_patterns" ]]; then
            options="$options --exclude='$exclude_patterns'"
            echo -e "${gl_lv}已设置排除模式: $exclude_patterns${gl_bai}"
        fi
        ;;
    3)
        options="$options --exclude='\$RECYCLE.BIN/' --exclude='System Volume Information/' --exclude='Thumbs.db' --exclude='Desktop.ini'"
        echo -e "${gl_lv}已排除Windows系统目录，解决权限问题${gl_bai}"
        ;;
    4 | "")
        echo "跳过高级选项"
        ;;
    *)
        echo -e "${gl_hong}无效选择，跳过高级选项${gl_bai}"
        ;;
    esac

    echo "$name|$source_path|$target_path|$options" >>"$LOCAL_SYNC_CONFIG"
    echo -e "${gl_lv}✓ 本地同步任务 '${name}' 已保存!${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}任务详情:${gl_bai}"
    echo -e "  ${gl_bai}名称: ${gl_huang}${name}${gl_bai}"
    echo -e "  ${gl_bai}源目录: ${gl_huang}${source_path}${gl_bai}"
    echo -e "  ${gl_bai}目标目录: ${gl_lv}${target_path}${gl_bai}"
    echo -e "  ${gl_bai}同步选项: ${gl_zi}${options}${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

local_delete_task() {
    local_init_globals || return 1

    if [[ ! -f "$LOCAL_SYNC_CONFIG" ]] || [[ ! -s "$LOCAL_SYNC_CONFIG" ]]; then
        echo -e "${gl_hong}错误: 暂无同步任务可删除${gl_bai}"
        exit_animation
        return 1
    fi

    echo ""

    local_list_tasks

    echo ""
    echo -e "${gl_huang}>>> 删除本地同步任务${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    local num
    read -r -e -p "$(echo -e "${gl_bai}请输入要删除的任务编号(${gl_huang}0${gl_bai}返回): ")" num

    [ "$num" = "0" ] && { cancel_return "Rsync本地同步工具"; return 1; }

    if ! [[ "$num" =~ ^[0-9]+$ ]]; then
        echo -e "${gl_hong}错误: 请输入有效的数字编号${gl_bai}"
        exit_animation
        return 1
    fi

    local total_tasks
    total_tasks=$(wc -l <"$LOCAL_SYNC_CONFIG" 2>/dev/null)
    if [[ "$num" -lt 1 || "$num" -gt "$total_tasks" ]]; then
        echo -e "${gl_hong}错误: 任务编号不存在${gl_bai}"
        exit_animation
        return 1
    fi

    local task_line
    task_line=$(sed -n "${num}p" "$LOCAL_SYNC_CONFIG")
    local task_name source_path target_path options
    IFS='|' read -r task_name source_path target_path options <<<"$task_line"

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}即将删除的任务:${gl_bai}"
    echo -e "  名称: ${gl_huang}${task_name}${gl_bai}"
    echo -e "  源目录: ${gl_huang}${source_path}${gl_bai}"
    echo -e "  目标目录: ${gl_lv}${target_path}${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    read -r -e -p "$(echo -e "${gl_bai}确定要删除这个任务吗? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        local temp_file
        temp_file=$(mktemp)
        sed "${num}d" "$LOCAL_SYNC_CONFIG" >"$temp_file"
        if mv "$temp_file" "$LOCAL_SYNC_CONFIG" 2>/dev/null; then
            echo -e "${gl_lv}✓ 任务已删除!${gl_bai}"
        else
            echo -e "${gl_hong}错误: 删除任务失败${gl_bai}"
            rm -f "$temp_file"
            return 1
        fi
    else
        echo "取消删除"
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

local_run_task() {
    local_init_globals || return 1

    if [[ ! -f "$LOCAL_SYNC_CONFIG" ]] || [[ ! -s "$LOCAL_SYNC_CONFIG" ]]; then
        echo -e "${gl_hong}错误: 暂无同步任务可执行${gl_bai}"
        return 1
    fi

    local num="$1"

    if [[ -z "$num" ]]; then
        local_list_tasks
        read -r -e -p "请输入要执行的任务编号: " num
    fi

    if ! [[ "$num" =~ ^[0-9]+$ ]]; then
        echo -e "${gl_hong}错误: 请输入有效的数字编号${gl_bai}"
        exit_animation
        return 1
    fi

    local total_tasks
    total_tasks=$(wc -l <"$LOCAL_SYNC_CONFIG" 2>/dev/null)
    if [[ "$num" -lt 1 || "$num" -gt "$total_tasks" ]]; then
        echo -e "${gl_hong}错误: 任务编号不存在${gl_bai}"
        exit_animation
        return 1
    fi

    local task
    task=$(sed -n "${num}p" "$LOCAL_SYNC_CONFIG")
    local name source_path target_path options
    IFS='|' read -r name source_path target_path options <<<"$task"

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}开始执行本地同步任务: ${gl_huang}${name}${gl_bai}"
    echo -e "${gl_bai}同步方向: ${gl_huang}${source_path} ${gl_hong}-> ${gl_lv}${target_path}${gl_bai}"
    echo -e "${gl_bai}同步选项: ${gl_zi}${options}${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if [[ ! -d "$source_path" ]]; then
        echo -e "${gl_hong}错误: 源目录不存在!${gl_bai}"
        echo -e "${gl_hong}请检查路径: ${source_path}${gl_bai}"
        exit_animation
        return 1
    fi

    if [[ ! -r "$source_path" ]]; then
        echo -e "${gl_huang}警告: 源目录读取权限受限${gl_bai}"
        echo -e "${gl_huang}建议: 使用权限友好模式同步${gl_bai}"
    fi

    if [[ ! -d "$target_path" ]]; then
        echo -e "${gl_huang}目标目录不存在，正在自动创建: ${gl_lv}${target_path}${gl_bai}"
        if mkdir -p "$target_path" 2>/dev/null; then
            echo -e "${gl_lv}✓ 目标目录已创建${gl_bai}"
        else
            echo -e "${gl_hong}错误: 无法创建目标目录${gl_bai}"
            exit_animation
            return 1
        fi
    fi

    if [[ ! -w "$target_path" ]]; then
        echo -e "${gl_hong}错误: 目标目录写入权限不足!${gl_bai}"
        echo -e "${gl_huang}请检查目录权限或使用sudo执行${gl_bai}"
        exit_animation
        return 1
    fi

    local start_time
    start_time=$(date +%s)
    echo -e "${gl_bai}开始时间: ${gl_lv}$(date)${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}正在执行同步 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bai}详细输出如下:${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    local output_file
    output_file=$(mktemp)
    local sync_result
    local error_count=0
    eval rsync $options "$source_path" "$target_path" 2>&1 | tee "$output_file"
    sync_result=${PIPESTATUS[0]}
    error_count=$(grep -c "Permission denied\|rsync error\|failed" "$output_file" || echo 0)
    rm -f "$output_file"
    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    if [[ $sync_result -eq 0 ]]; then
        echo -e "${gl_lv}✓ 本地同步完成!${gl_bai}"
        echo -e "${gl_bai}同步统计:${gl_bai}"
        echo -e "  - 任务名称: ${gl_huang}${name}${gl_bai}"
        echo -e "  - 源目录: ${gl_huang}${source_path}${gl_bai}"
        echo -e "  - 目标目录: ${gl_lv}${target_path}${gl_bai}"
        echo -e "  - 耗时: ${gl_zi}${duration}秒${gl_bai}"
        echo -e "  - 完成时间: ${gl_lv}$(date)${gl_bai}"
        echo -e "  - 同步结果: ${gl_lv}成功${gl_bai}"
    elif [[ $sync_result -eq 23 ]] && [[ $error_count -gt 0 ]]; then
        echo -e "${gl_huang}⚠ 同步部分完成，但有文件权限问题${gl_bai}"
        echo -e "${gl_bai}同步统计:${gl_bai}"
        echo -e "  - 任务名称: ${gl_huang}${name}${gl_bai}"
        echo -e "  - 源目录: ${gl_huang}${source_path}${gl_bai}"
        echo -e "  - 目标目录: ${gl_lv}${target_path}${gl_bai}"
        echo -e "  - 耗时: ${gl_zi}${duration}秒${gl_bai}"
        echo -e "  - 完成时间: ${gl_lv}$(date)${gl_bai}"
        echo -e "  - 同步结果: ${gl_huang}部分成功${gl_bai}"
        echo -e "  - 错误类型: 文件权限受限"
        echo -e "${gl_huang}建议解决方案:${gl_bai}"
        echo -e "  ${gl_bufan}1. ${gl_bai}重新编辑任务，选择'权限友好模式'"
        echo -e "  ${gl_bufan}2. ${gl_bai}在高级选项中选择'排除Windows系统目录'"
        echo -e "  ${gl_bufan}3. ${gl_bai}使用root权限执行: sudo m local_rsync_run $num"
    else
        echo -e "${gl_hong}✗ 同步失败! 错误代码: ${sync_result}${gl_bai}"
        echo -e "${gl_hong}可能的原因:${gl_bai}"
        echo -e "  ${gl_bufan}1. ${gl_bai}目标目录权限不足 - 使用sudo或检查目录权限"
        echo -e "  ${gl_bufan}2. ${gl_bai}磁盘空间不足 - 检查目标磁盘空间"
        echo -e "  ${gl_bufan}3. ${gl_bai}文件被占用或权限问题 - 尝试重新编辑任务选择权限友好模式"
        echo -e "  ${gl_bufan}4. ${gl_bai}网络存储连接问题（如果是网络路径）"
        echo -e "  ${gl_bufan}5. ${gl_bai}rsync选项配置错误 - 检查同步选项"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
    return $sync_result
}

local_run_all_tasks() {
    local_init_globals || return 1

    if [[ ! -f "$LOCAL_SYNC_CONFIG" ]] || [[ ! -s "$LOCAL_SYNC_CONFIG" ]]; then
        echo -e "${gl_hong}错误: 暂无同步任务可执行${gl_bai}"
        exit_animation
        return 1
    fi

    local total_tasks
    total_tasks=$(wc -l <"$LOCAL_SYNC_CONFIG")
    echo -e ""
    echo -e "${gl_bai}开始批量执行 ${gl_huang}${total_tasks} ${gl_bai}个本地同步任务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local success_count=0
    local fail_count=0
    local partial_count=0
    local current_task=0

    while IFS= read -r task; do
        ((current_task++))
        local name source_path target_path options
        IFS='|' read -r name source_path target_path options <<<"$task"

        echo -e "${gl_bai}[${gl_lv}${current_task}${gl_bai}/${gl_huang}${total_tasks}${gl_bai}] 执行任务: ${gl_huang}${name}${gl_bai}"
        echo -e "${gl_bai}路径: ${gl_huang}${source_path} ${gl_bai}-> ${gl_lv}${target_path}${gl_bai}"

        if [[ ! -d "$source_path" ]]; then
            echo -e "${gl_hong}✗ 失败: 源目录不存在${gl_bai}"
            ((fail_count++))
            echo ""
            continue
        fi

        local output_file
        output_file=$(mktemp)
        eval rsync $options "$source_path" "$target_path" >"$output_file" 2>&1
        local sync_result=$?

        if [[ $sync_result -eq 0 ]]; then
            echo -e "${gl_lv}✓ 成功${gl_bai}"
            ((success_count++))
        elif [[ $sync_result -eq 23 ]] && grep -q "Permission denied" "$output_file"; then
            echo -e "${gl_huang}⚠ 部分成功 (权限问题)${gl_bai}"
            ((partial_count++))
        else
            echo -e "${gl_hong}✗ 失败 (错误代码: $sync_result)${gl_bai}"
            ((fail_count++))
        fi

        rm -f "$output_file"
        echo ""
    done <"$LOCAL_SYNC_CONFIG"

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}批量执行完成:"
    echo -e "  ${gl_lv}✓ 成功: ${success_count}${gl_bai}"
    echo -e "  ${gl_huang}⚠ 部分成功: ${partial_count}${gl_bai}"
    echo -e "  ${gl_hong}✗ 失败: ${fail_count}${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end

    if [[ $fail_count -eq 0 ]] && [[ $partial_count -eq 0 ]]; then
        return 0
    elif [[ $fail_count -gt 0 ]]; then
        return 1
    else
        return 2
    fi
}

local_schedule_task() {
    echo ""
    echo -e "${gl_zi}>>> 创建本地定时任务${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    local_init_globals || return 1

    if [[ ! -f "$LOCAL_SYNC_CONFIG" ]] || [[ ! -s "$LOCAL_SYNC_CONFIG" ]]; then
        echo -e "${gl_hong}错误: 暂无同步任务可设置定时${gl_bai}"
        exit_animation
        return 1
    fi

    local num

    read -r -e -p "$(echo -e "${gl_bai}请输入要定时同步的任务编号(${gl_huang}0${gl_bai}返回): ")" num

    [ "$num" = "0" ] && { cancel_return "Rsync本地同步工具"; return 1; }
    [ -z "$num" ] && { cancel_empty "上一级选单"; return 1; }

    if ! [[ "$num" =~ ^[0-9]+$ ]]; then
        echo -e "${gl_hong}错误: 请输入有效的数字编号${gl_bai}"
        exit_animation
        return 1
    fi

    local total_tasks
    total_tasks=$(wc -l <"$LOCAL_SYNC_CONFIG")
    if [[ "$num" -lt 1 || "$num" -gt "$total_tasks" ]]; then
        echo -e "${gl_hong}错误: 任务编号不存在${gl_bai}"
        exit_animation
        return 1
    fi

    local task
    task=$(sed -n "${num}p" "$LOCAL_SYNC_CONFIG")
    local name source_path target_path options
    IFS='|' read -r name source_path target_path options <<<"$task"

    echo ""
    echo -e "${gl_huang}>>> 请选择定时执行间隔${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bufan}1. ${gl_bai}每小时执行一次"
    echo -e "${gl_bufan}2. ${gl_bai}每天执行一次"
    echo -e "${gl_bufan}3. ${gl_bai}每周执行一次"
    echo -e "${gl_bufan}4. ${gl_bai}每月执行一次"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "请输入你的选择: " interval

    local random_minute
    random_minute=$(shuf -i 0-59 -n 1)
    local cron_time=""
    local interval_desc=""

    case "$interval" in
    1)
        cron_time="$random_minute * * * *"
        interval_desc="每小时（随机分钟 $random_minute）"
        ;;
    2)
        cron_time="$random_minute 2 * * *"
        interval_desc="每天凌晨2点（随机分钟 $random_minute）"
        ;;
    3)
        cron_time="$random_minute 3 * * 1"
        interval_desc="每周一凌晨3点（随机分钟 $random_minute）"
        ;;
    4)
        cron_time="$random_minute 4 1 * *"
        interval_desc="每月1号凌晨4点（随机分钟 $random_minute）"
        ;;
    *)
        echo -e "${gl_hong}错误: 请输入有效的选项！${gl_bai}"
        return 1
        ;;
    esac

    local script_path
    script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

    local cron_job
    cron_job="$cron_time m local_rsync_run $num"

    local cron_service_active=false
    if command -v systemctl >/dev/null 2>&1; then
        if systemctl is-active cron >/dev/null 2>&1 || systemctl is-active crond >/dev/null 2>&1; then
            cron_service_active=true
        fi
    elif command -v service >/dev/null 2>&1; then
        if service cron status >/dev/null 2>&1 || service crond status >/dev/null 2>&1; then
            cron_service_active=true
        fi
    fi

    if ! $cron_service_active; then
        echo -e "${gl_huang}警告: cron服务未运行，正在尝试启动 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        if command -v systemctl >/dev/null 2>&1; then
            sudo systemctl start cron 2>/dev/null || sudo systemctl start crond 2>/dev/null
        elif command -v service >/dev/null 2>&1; then
            sudo service cron start 2>/dev/null || sudo service crond start 2>/dev/null
        fi
    fi

    if crontab -l 2>/dev/null | grep -q "local_rsync_run $num"; then
        echo -e "${gl_hong}错误: 该任务的定时同步已存在！${gl_bai}"
        return 1
    fi

    (
        crontab -l 2>/dev/null | grep -v "^#"
        echo "# 本地Rsync定时任务: $name"
        echo "$cron_job"
        echo ""
    ) | crontab -

    echo ""
    echo -e "${gl_lv}✓ 定时任务已创建：${gl_huang}$cron_job${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}任务详情:${gl_bai}"
    echo -e "  - 任务名称: ${gl_huang}${name}${gl_bai}"
    echo -e "  - 执行间隔: ${gl_huang}${interval_desc}${gl_bai}"
    echo -e "  - 源目录: ${gl_huang}${source_path}${gl_bai}"
    echo -e "  - 目标目录: ${gl_lv}${target_path}${gl_bai}"
    echo -e "  - 同步选项: ${gl_zi}${options}${gl_bai}"
    echo -e "  - Cron命令: ${gl_zi}$cron_job${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}当前cron状态:${gl_bai}"
    if $cron_service_active; then
        echo -e "  ${gl_lv}✓ cron服务运行正常${gl_bai}"
    else
        echo -e "  ${gl_huang}⚠ cron服务未运行，定时任务可能无法执行${gl_bai}"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

local_view_schedules() {
    echo "当前的本地同步定时任务:"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    local cron_active=false
    if command -v systemctl >/dev/null 2>&1; then
        if systemctl is-active cron >/dev/null 2>&1 || systemctl is-active crond >/dev/null 2>&1; then
            cron_active=true
        fi
    elif command -v service >/dev/null 2>&1; then
        if service cron status >/dev/null 2>&1 || service crond status >/dev/null 2>&1; then
            cron_active=true
        fi
    fi

    if ! $cron_active; then
        echo -e "${gl_huang}警告: cron服务未运行，定时任务可能无法执行${gl_bai}"
        echo -e "${gl_huang}启动命令: sudo systemctl start cron${gl_bai}"
    fi

    local crontab_content
    crontab_content=$(crontab -l 2>/dev/null)

    if [[ $? -ne 0 ]] || [[ -z "$crontab_content" ]]; then
        echo -e "${gl_huang}当前用户暂无定时任务${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        return 0
    fi

    local task_count=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^# ]] && continue

        if [[ "$line" =~ local_rsync_run ]] || [[ "$line" =~ local_rsync_run ]]; then
            ((task_count++))
            local task_num
            task_num=$(echo "$line" | grep -o -- "local_rsync_run [0-9]\+" | awk '{print $2}' ||
                echo "$line" | grep -o "local_rsync_run [0-9]\+" | awk '{print $2}')

            local task_name=""
            local source_path=""
            local target_path=""
            local options=""
            if [[ -n "$task_num" ]] && [[ -f "$LOCAL_SYNC_CONFIG" ]]; then
                local task_line
                task_line=$(sed -n "${task_num}p" "$LOCAL_SYNC_CONFIG" 2>/dev/null)
                if [[ -n "$task_line" ]]; then
                    IFS='|' read -r task_name source_path target_path options <<<"$task_line"
                fi
            fi

            echo -e "${gl_bufan}${task_count}. ${gl_bai}Cron表达式: ${gl_zi}${line}${gl_bai}"
            if [[ -n "$task_name" ]]; then
                echo -e "   任务名称: ${gl_huang}${task_name}${gl_bai}"
                echo -e "   源目录:   ${gl_huang}${source_path}${gl_bai}"
                echo -e "   目标目录: ${gl_lv}${target_path}${gl_bai}"
                echo -e "   同步选项: ${gl_zi}${options}${gl_bai}"
            else
                echo -e "   ${gl_hong}警告: 无法获取任务详细信息（可能对应的同步任务已被删除）${gl_bai}"
            fi
            echo ""
        fi
    done <<<"$crontab_content"

    if [[ $task_count -eq 0 ]]; then
        echo -e "${gl_huang}暂无本地同步定时任务${gl_bai}"
    else
        echo -e "${gl_bai}共找到 ${gl_huang}${task_count} ${gl_bai}个定时任务${gl_bai}"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
}

local_delete_schedule() {
    clear
    echo ""
    echo -e "${gl_zi}>>> 删除定时任务${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    local_view_schedules

    local task_num

    read -r -e -p "$(echo -e "${gl_bai}请输入要删除的定时任务编号(${gl_huang}0${gl_bai}返回): ")" task_num

    [ "$task_num" = "0" ] && { cancel_return "Rsync本地同步工具"; return 1; }
    [ -z "$task_num" ] && { cancel_empty "上一级选单"; return 1; }

    if ! [[ "$task_num" =~ ^[0-9]+$ ]]; then
        echo -e "${gl_hong}错误: 请输入有效的数字编号${gl_bai}"
        exit_animation    # 即将退出动画
        return 1
    fi

    local crontab_content
    crontab_content=$(crontab -l 2>/dev/null)

    if [[ $? -ne 0 ]] || [[ -z "$crontab_content" ]]; then
        echo -e "${gl_hong}错误: 未找到定时任务${gl_bai}"
        exit_animation
        return 1
    fi

    local current_task=0
    local target_line=""
    local target_comment_line=""
    local found_target=false
    local prev_line=""
    
    while IFS= read -r line; do
        if [[ "$line" =~ local_rsync_run ]] || [[ "$line" =~ local_rsync_run ]]; then
            ((current_task++))
            if [[ $current_task -eq $task_num ]]; then
                target_line="$line"
                found_target=true
                
                if [[ -n "$prev_line" ]] && [[ "$prev_line" =~ ^#.*本地Rsync定时任务 ]]; then
                    target_comment_line="$prev_line"
                fi
                break
            fi
        fi
        prev_line="$line"
    done <<<"$crontab_content"

    if [[ -z "$target_line" ]]; then
        echo -e "${gl_hong}错误: 未找到该编号的定时任务${gl_bai}"
        exit_animation
        return 1
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}即将删除的任务:${gl_bai}"
    if [[ -n "$target_comment_line" ]]; then
        echo -e "${gl_huang}注释行: $target_comment_line${gl_bai}"
    fi
    echo -e "${gl_huang}任务行: $target_line${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    read -r -e -p "$(echo -e "${gl_bai}确定要删除这个定时任务吗? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        local temp_file
        temp_file=$(mktemp)
        
        crontab -l 2>/dev/null > "$temp_file"
        
        if [[ -n "$target_comment_line" ]]; then
            local temp_file2
            temp_file2=$(mktemp)
            grep -vF "$target_comment_line" "$temp_file" > "$temp_file2"
            mv "$temp_file2" "$temp_file"
        fi
        
        local temp_file3
        temp_file3=$(mktemp)
        grep -vF "$target_line" "$temp_file" > "$temp_file3"
        mv "$temp_file3" "$temp_file"

        if grep -qF "$target_line" "$temp_file"; then
            echo -e "${gl_hong}错误: 删除任务失败${gl_bai}"
        else
            crontab "$temp_file"
            echo -e "${gl_lv}✓ 定时任务已删除!${gl_bai}"
            
            if crontab -l 2>/dev/null | grep -qF "$target_line"; then
                echo -e "${gl_huang}警告: 定时任务可能未被完全删除${gl_bai}"
            fi
        fi

        rm -f "$temp_file"
    else
        echo "取消删除"
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

local_run_task_reverse() {
    local_init_globals || return 1

    if [[ ! -f "$LOCAL_SYNC_CONFIG" ]] || [[ ! -s "$LOCAL_SYNC_CONFIG" ]]; then
        echo -e "${gl_hong}错误: 暂无同步任务可执行${gl_bai}"
        exit_animation
        return 1
    fi

    local num="$1"

    if [[ -z "$num" ]]; then
        local_list_tasks
        read -r -e -p "请输入要执行反向同步的任务编号: " num
    fi

    if ! [[ "$num" =~ ^[0-9]+$ ]]; then
        echo -e "${gl_hong}错误: 请输入有效的数字编号${gl_bai}"
        exit_animation
        return 1
    fi

    local total_tasks
    total_tasks=$(wc -l <"$LOCAL_SYNC_CONFIG" 2>/dev/null)
    if [[ "$num" -lt 1 || "$num" -gt "$total_tasks" ]]; then
        echo -e "${gl_hong}错误: 任务编号不存在${gl_bai}"
        exit_animation
        return 1
    fi

    local task
    task=$(sed -n "${num}p" "$LOCAL_SYNC_CONFIG")
    local name source_path target_path options
    IFS='|' read -r name source_path target_path options <<<"$task"

    echo -e "${gl_hong}⚠⚠⚠ 警告：反向同步 ⚠⚠⚠${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}原始任务方向: ${gl_huang}${source_path} ${gl_bai}-> ${gl_lv}${target_path}${gl_bai}"
    echo -e "${gl_bai}反向同步方向: ${gl_hong}${target_path} ${gl_bai}-> ${gl_huang}${source_path}${gl_bai}"
    echo -e ""
    echo -e "${gl_hong}注意：此操作会将目标目录的内容同步回源目录，可能会覆盖源文件！${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}确认执行反向同步吗? (${gl_hong}输入 ${gl_huang}y ${gl_hong}确认${gl_bai}/${gl_lv}任意键取消${gl_bai}): ")" confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${gl_huang}已取消反向同步操作${gl_bai}"
        return 0
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}开始执行本地反向同步任务: ${gl_hong}${name}${gl_bai}"
    echo -e "${gl_bai}同步方向: ${gl_lv}${target_path} ${gl_hong}-> ${gl_huang}${source_path}${gl_bai}"
    echo -e "${gl_bai}同步选项: ${gl_zi}${options}${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if [[ ! -d "$target_path" ]]; then
        echo -e "${gl_hong}错误: 原目标目录（现源目录）不存在!${gl_bai}"
        echo -e "${gl_hong}请检查路径: ${target_path}${gl_bai}"
        exit_animation
        return 1
    fi

    if [[ ! -d "$source_path" ]]; then
        echo -e "${gl_huang}警告: 原源目录（现目标目录）不存在，正在自动创建: ${gl_huang}${source_path}${gl_bai}"
        if mkdir -p "$source_path" 2>/dev/null; then
            echo -e "${gl_lv}✓ 目录已创建${gl_bai}"
        else
            echo -e "${gl_hong}错误: 无法创建目录${gl_bai}"
            exit_animation
            return 1
        fi
    fi

    if [[ ! -w "$source_path" ]]; then
        echo -e "${gl_hong}错误: 原源目录（现目标目录）写入权限不足!${gl_bai}"
        echo -e "${gl_huang}请检查目录权限或使用sudo执行${gl_bai}"
        exit_animation
        return 1
    fi

    local start_time
    start_time=$(date +%s)
    echo -e "${gl_bai}开始时间: ${gl_lv}$(date)${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}正在执行反向同步 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bai}详细输出如下:${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local output_file
    output_file=$(mktemp)
    local sync_result
    local error_count=0

    eval rsync $options "$target_path" "$source_path" 2>&1 | tee "$output_file"
    sync_result=${PIPESTATUS[0]}

    error_count=$(grep -c "Permission denied\|rsync error\|failed" "$output_file" || echo 0)
    rm -f "$output_file"

    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if [[ $sync_result -eq 0 ]]; then
        echo -e "${gl_lv}✓ 本地反向同步完成!${gl_bai}"
        echo -e "${gl_bai}同步统计:${gl_bai}"
        echo -e "  - 任务名称: ${gl_hong}${name}${gl_bai}"
        echo -e "  - 同步方向: ${gl_lv}${target_path} ${gl_hong}-> ${gl_huang}${source_path}${gl_bai}"
        echo -e "  - 耗时: ${gl_zi}${duration}秒${gl_bai}"
        echo -e "  - 完成时间: ${gl_lv}$(date)${gl_bai}"
        echo -e "  - 同步结果: ${gl_lv}成功${gl_bai}"
    elif [[ $sync_result -eq 23 ]] && [[ $error_count -gt 0 ]]; then
        echo -e "${gl_huang}⚠ 反向同步部分完成，但有文件权限问题${gl_bai}"
        echo -e "${gl_bai}同步统计:${gl_bai}"
        echo -e "  - 任务名称: ${gl_hong}${name}${gl_bai}"
        echo -e "  - 同步方向: ${gl_lv}${target_path} ${gl_hong}-> ${gl_huang}${source_path}${gl_bai}"
        echo -e "  - 耗时: ${gl_zi}${duration}秒${gl_bai}"
        echo -e "  - 完成时间: ${gl_lv}$(date)${gl_bai}"
        echo -e "  - 同步结果: ${gl_huang}部分成功${gl_bai}"
        echo -e "  - 错误类型: 文件权限受限"
        echo -e "${gl_huang}建议解决方案:${gl_bai}"
        echo -e "  ${gl_bufan}1. ${gl_bai}重新编辑任务，选择'权限友好模式'"
        echo -e "  ${gl_bufan}2. ${gl_bai}在高级选项中选择'排除Windows系统目录'"
        echo -e "  ${gl_bufan}3. ${gl_bai}使用root权限执行"
    else
        echo -e "${gl_hong}✗ 反向同步失败! 错误代码: ${sync_result}${gl_bai}"
        echo -e "${gl_hong}可能的原因:${gl_bai}"
        echo -e "  ${gl_bufan}1. ${gl_bai}原源目录（现目标目录）权限不足 - 使用sudo或检查目录权限"
        echo -e "  ${gl_bufan}2. ${gl_bai}磁盘空间不足 - 检查目标磁盘空间"
        echo -e "  ${gl_bufan}3. ${gl_bai}文件被占用或权限问题 - 尝试重新编辑任务选择权限友好模式"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
    return $sync_result
}

local_forward_sync_menu() {
    clear
    echo ""
    echo -e "${gl_huang}>>> 执行正向同步 ${gl_bai}(${gl_huang}源 ${gl_bai}-> ${gl_lv}目标${gl_bai})${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    local_list_tasks
    local task_num
    read -r -e -p "$(echo -e "${gl_bai}请输入要执行的任务编号(${gl_huang}0${gl_bai}返回): ")" task_num

    [ "$task_num" = "0" ] && { cancel_return "Rsync本地同步工具"; return 1; }
    [ -z "$task_num" ] && { cancel_empty "上一级选单"; return 1; }

    local_run_task "$task_num"
}

local_reverse_sync_menu() {
    clear
    echo ""
    echo -e "${gl_zi}>>> 执行反向同步 ${gl_bai}(${gl_huang}目标 ${gl_bai}-> ${gl_lv}源${gl_bai})${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_huang}注意：反向同步会用目标目录文件覆盖源目录！${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    local_list_tasks
    local task_num

    read -r -e -p "$(echo -e "${gl_bai}请输入要执行反向同步的任务编号(${gl_huang}0${gl_bai}返回): ")" task_num

    [ "$task_num" = "0" ] && { cancel_return "Rsync本地同步工具"; return 1; }
    [ -z "$task_num" ] && { cancel_empty "上一级选单"; return 1; }

    local_run_task_reverse "$task_num"
}

local_fix_permission_menu() {
    clear
    echo ""
    echo -e "${gl_huang}>>> 修复权限问题${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}常见权限问题解决方案:${gl_bai}"
    echo -e "  ${gl_bufan}1. ${gl_bai}重新创建任务，选择'权限友好模式'"
    echo -e "  ${gl_bufan}2. ${gl_bai}在高级选项中选择'排除Windows系统目录'"
    echo -e "  ${gl_bufan}3. ${gl_bai}使用sudo权限执行同步"
    echo -e "  ${gl_bufan}4. ${gl_bai}修改源目录权限: chmod -R 755 /path/to/source"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

local_show_task_details() {
    local_init_globals || return 1
    echo ""
    echo -e "${gl_zi}>>> 查看本地同步任务详细信息${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    if [[ ! -f "$LOCAL_SYNC_CONFIG" ]]; then
        echo -e "${gl_huang}配置文件不存在，暂无同步任务${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation
        return 0
    fi
    
    if [[ ! -s "$LOCAL_SYNC_CONFIG" ]]; then
        echo -e "${gl_huang}暂无同步任务${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation
        return 0
    fi
    
    echo -e "${gl_bai}提示: 直接${gl_lv}回车${gl_bai}查看全部任务，输入${gl_huang}0${gl_bai}返回${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}请输入要查看的任务编号(${gl_huang}0${gl_bai}返回): ")" num
    [ "$num" = "0" ] && { cancel_return "Rsync本地同步工具"; return 1; }
    
    if [[ -z "$num" ]]; then
        echo ""
        echo -e "${gl_zi}>>> 所有本地同步任务详情${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        local line_num=1
        while IFS='|' read -r name source_path target_path options; do
            echo -e "${gl_bufan}任务 #${line_num}${gl_bai}"
            echo -e "  ${gl_bai}任务名称: ${gl_zi}$name${gl_bai}"
            echo -e "  ${gl_bai}源目录: ${gl_huang}$source_path${gl_bai}"
            echo -e "  ${gl_bai}目标目录: ${gl_lv}$target_path${gl_bai}"
            echo -e "  ${gl_bai}同步选项: ${gl_zi}$options${gl_bai}"
            
            if [[ -d "$source_path" ]]; then
                local source_size=$(du -sh "$source_path" 2>/dev/null | cut -f1)
                local source_count=$(find "$source_path" -type f 2>/dev/null | wc -l)
                echo -e "  ${gl_bai}源目录状态: ${gl_lv}存在${gl_bai}"
                echo -e "  ${gl_bai}源目录大小: ${gl_bai}${source_size:-未知}"
                echo -e "  ${gl_bai}源文件数量: ${gl_bai}${source_count}"
                
                if [[ ! -r "$source_path" ]]; then
                    echo -e "  ${gl_hong}警告: 源目录读取权限不足!${gl_bai}"
                fi
            else
                echo -e "  ${gl_hong}警告: 源目录不存在!${gl_bai}"
            fi
            
            if [[ -d "$target_path" ]]; then
                local target_size=$(du -sh "$target_path" 2>/dev/null | cut -f1)
                local target_count=$(find "$target_path" -type f 2>/dev/null | wc -l)
                echo -e "  ${gl_bai}目标目录状态: ${gl_lv}存在${gl_bai}"
                echo -e "  ${gl_bai}目标目录大小: ${gl_bai}${target_size:-未知}"
                echo -e "  ${gl_bai}目标文件数量: ${gl_bai}${target_count}"
                
                if [[ ! -w "$target_path" ]]; then
                    echo -e "  ${gl_hong}警告: 目标目录写入权限不足!${gl_bai}"
                fi
            else
                echo -e "  ${gl_huang}目标目录状态: ${gl_huang}不存在${gl_bai}"
            fi
            
            if [[ "$source_path" =~ ^// ]] || [[ "$source_path" =~ ^smb:// ]] || [[ "$target_path" =~ ^// ]] || [[ "$target_path" =~ ^smb:// ]]; then
                echo -e "  ${gl_bai}网络路径: ${gl_huang}是${gl_bai}"
            fi
            
            echo -e "${gl_bai}磁盘空间信息:${gl_bai}"
            local source_disk=$(df -h "$source_path" 2>/dev/null | tail -1)
            local target_disk=$(df -h "$target_path" 2>/dev/null | tail -1)
            
            if [[ -n "$source_disk" ]]; then
                local source_fs=$(echo "$source_disk" | awk '{print $1}')
                local source_avail=$(echo "$source_disk" | awk '{print $4}')
                echo -e "  ${gl_bai}源磁盘可用空间: ${gl_bai}$source_avail (文件系统: $source_fs)"
            fi
            
            if [[ -n "$target_disk" ]]; then
                local target_fs=$(echo "$target_disk" | awk '{print $1}')
                local target_avail=$(echo "$target_disk" | awk '{print $4}')
                echo -e "  ${gl_bai}目标磁盘可用空间: ${gl_bai}$target_avail (文件系统: $target_fs)"
            fi
            
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            ((line_num++))
        done <"$LOCAL_SYNC_CONFIG"
        echo -e "${gl_lv}共找到 $((line_num-1)) 个同步任务${gl_bai}"
    else
        local task=$(sed -n "${num}p" "$LOCAL_SYNC_CONFIG" 2>/dev/null)
        if [[ -z "$task" ]]; then
            echo -e "${gl_hong}错误: 未找到任务 #$num${gl_bai}"
            exit_animation
            return
        fi
        
        IFS='|' read -r name source_path target_path options <<<"$task"
        
        echo ""
        echo -e "${gl_zi}>>> 本地同步任务 #$num 详情${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "  ${gl_bai}任务名称: ${gl_zi}$name${gl_bai}"
        echo -e "  ${gl_bai}源目录: ${gl_huang}$source_path${gl_bai}"
        echo -e "  ${gl_bai}目标目录: ${gl_lv}$target_path${gl_bai}"
        echo -e "  ${gl_bai}同步选项: ${gl_zi}$options${gl_bai}"
        
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "  ${gl_bai}同步选项解析:${gl_bai}"
        
        if [[ "$options" == *"-a"* ]]; then
            echo -e "  ${gl_bai}  - archive: 归档模式，保留所有文件属性${gl_bai}"
        fi
        if [[ "$options" == *"-v"* ]]; then
            echo -e "  ${gl_bai}  - verbose: 详细输出模式${gl_bai}"
        fi
        if [[ "$options" == *"-h"* ]]; then
            echo -e "  ${gl_bai}  - human-readable: 人类可读的文件大小${gl_bai}"
        fi
        if [[ "$options" == *"-z"* ]]; then
            echo -e "  ${gl_bai}  - compress: 传输时压缩数据${gl_bai}"
        fi
        if [[ "$options" == *"--progress"* ]]; then
            echo -e "  ${gl_bai}  - progress: 显示传输进度${gl_bai}"
        fi
        if [[ "$options" == *"--delete"* ]]; then
            echo -e "  ${gl_bai}  - delete: 删除目标目录中多余的文件${gl_bai}"
        fi
        if [[ "$options" == *"--delete-delay"* ]]; then
            echo -e "  ${gl_bai}  - delete-delay: 延迟删除文件，传输完成后删除${gl_bai}"
        fi
        if [[ "$options" == *"--checksum"* ]]; then
            echo -e "  ${gl_bai}  - checksum: 基于校验和而非大小和时间决定是否跳过${gl_bai}"
        fi
        if [[ "$options" == *"--no-perms"* ]]; then
            echo -e "  ${gl_bai}  - no-perms: 不保留权限${gl_bai}"
        fi
        if [[ "$options" == *"--no-owner"* ]]; then
            echo -e "  ${gl_bai}  - no-owner: 不保留所有者${gl_bai}"
        fi
        if [[ "$options" == *"--no-group"* ]]; then
            echo -e "  ${gl_bai}  - no-group: 不保留组${gl_bai}"
        fi
        if [[ "$options" == *"--bwlimit"* ]]; then
            local bwlimit=$(echo "$options" | grep -o -- "--bwlimit=[0-9]*" | cut -d= -f2)
            echo -e "  ${gl_bai}  - bwlimit: 限速 ${bwlimit}KB/s${gl_bai}"
        fi
        if [[ "$options" == *"--exclude"* ]]; then
            local excludes=$(echo "$options" | grep -o -- "--exclude='[^']*'" || echo "$options" | grep -o -- '--exclude=[^[:space:]]*')
            echo -e "  ${gl_bai}  - exclude: 排除以下文件:${gl_bai}"
            for exclude in $excludes; do
                local pattern=$(echo "$exclude" | sed "s/--exclude='//" | sed "s/'$//" | sed "s/--exclude=//")
                echo -e "    ${gl_bai}    * $pattern${gl_bai}"
            done
        fi
        
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "  ${gl_bai}源目录状态检查:${gl_bai}"
        
        if [[ -d "$source_path" ]]; then
            local source_size=$(du -sh "$source_path" 2>/dev/null | cut -f1)
            local source_file_count=$(find "$source_path" -type f 2>/dev/null | wc -l)
            local source_dir_count=$(find "$source_path" -type d 2>/dev/null | wc -l)
            
            echo -e "  ${gl_bai}  - 存在: ${gl_lv}是${gl_bai}"
            echo -e "  ${gl_bai}  - 总大小: ${gl_bai}$source_size"
            echo -e "  ${gl_bai}  - 文件数量: ${gl_bai}$source_file_count"
            echo -e "  ${gl_bai}  - 目录数量: ${gl_bai}$source_dir_count"
            
            if [[ -r "$source_path" ]]; then
                echo -e "  ${gl_bai}  - 读取权限: ${gl_lv}正常${gl_bai}"
            else
                echo -e "  ${gl_bai}  - 读取权限: ${gl_hong}不足${gl_bai}"
            fi
            
            local mod_time=$(stat -c "%y" "$source_path" 2>/dev/null | cut -d'.' -f1)
            echo -e "  ${gl_bai}  - 最后修改: ${gl_bai}${mod_time:-未知}"
            
        else
            echo -e "  ${gl_bai}  - 存在: ${gl_hong}否${gl_bai}"
            echo -e "  ${gl_bai}  - 状态: ${gl_hong}目录不存在!${gl_bai}"
        fi
        
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "  ${gl_bai}目标目录状态检查:${gl_bai}"
        
        if [[ -d "$target_path" ]]; then
            local target_size=$(du -sh "$target_path" 2>/dev/null | cut -f1)
            local target_file_count=$(find "$target_path" -type f 2>/dev/null | wc -l)
            local target_dir_count=$(find "$target_path" -type d 2>/dev/null | wc -l)
            
            echo -e "  ${gl_bai}  - 存在: ${gl_lv}是${gl_bai}"
            echo -e "  ${gl_bai}  - 总大小: ${gl_bai}$target_size"
            echo -e "  ${gl_bai}  - 文件数量: ${gl_bai}$target_file_count"
            echo -e "  ${gl_bai}  - 目录数量: ${gl_bai}$target_dir_count"
            
            if [[ -w "$target_path" ]]; then
                echo -e "  ${gl_bai}  - 写入权限: ${gl_lv}正常${gl_bai}"
            else
                echo -e "  ${gl_bai}  - 写入权限: ${gl_hong}不足${gl_bai}"
            fi
            
            local disk_info=$(df -h "$target_path" 2>/dev/null | tail -1)
            if [[ -n "$disk_info" ]]; then
                local fs_type=$(echo "$disk_info" | awk '{print $1}')
                local total_space=$(echo "$disk_info" | awk '{print $2}')
                local used_space=$(echo "$disk_info" | awk '{print $3}')
                local avail_space=$(echo "$disk_info" | awk '{print $4}')
                local use_percent=$(echo "$disk_info" | awk '{print $5}')
                
                echo -e "  ${gl_bai}  - 文件系统: ${gl_bai}$fs_type"
                echo -e "  ${gl_bai}  - 总空间: ${gl_bai}$total_space"
                echo -e "  ${gl_bai}  - 已用空间: ${gl_bai}$used_space ($use_percent)"
                echo -e "  ${gl_bai}  - 可用空间: ${gl_bai}$avail_space"
                
                if [[ -n "$source_size" ]] && [[ "$source_size" =~ ^[0-9.]+[KMGTPE]?$ ]]; then
                    local source_bytes=$(echo "$source_size" | numfmt --from=iec 2>/dev/null)
                    local avail_bytes=$(echo "$avail_space" | numfmt --from=iec 2>/dev/null)
                    
                    if [[ -n "$source_bytes" ]] && [[ -n "$avail_bytes" ]] && [[ "$source_bytes" -gt "$avail_bytes" ]]; then
                        echo -e "  ${gl_hong}警告: 目标磁盘空间不足!${gl_bai}"
                        echo -e "  ${gl_hong}源目录大小 ($source_size) 大于可用空间 ($avail_space)${gl_bai}"
                    fi
                fi
            fi
            
        else
            echo -e "  ${gl_bai}  - 存在: ${gl_huang}否${gl_bai}"
            echo -e "  ${gl_bai}  - 状态: 目录不存在，执行同步时会自动创建${gl_bai}"
        fi
        
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "  ${gl_bai}路径类型检测:${gl_bai}"
        
        if [[ "$source_path" =~ ^// ]] || [[ "$source_path" =~ ^smb:// ]] || mount | grep -q " on $source_path "; then
            echo -e "  ${gl_bai}  - 源路径类型: ${gl_huang}网络共享/挂载点${gl_bai}"
        elif [[ "$source_path" =~ ^/mnt/ ]] || [[ "$source_path" =~ ^/media/ ]]; then
            echo -e "  ${gl_bai}  - 源路径类型: ${gl_huang}挂载点${gl_bai}"
        else
            echo -e "  ${gl_bai}  - 源路径类型: ${gl_lv}本地目录${gl_bai}"
        fi
        
        if [[ "$target_path" =~ ^// ]] || [[ "$target_path" =~ ^smb:// ]] || mount | grep -q " on $target_path "; then
            echo -e "  ${gl_bai}  - 目标路径类型: ${gl_huang}网络共享/挂载点${gl_bai}"
        elif [[ "$target_path" =~ ^/mnt/ ]] || [[ "$target_path" =~ ^/media/ ]]; then
            echo -e "  ${gl_bai}  - 目标路径类型: ${gl_huang}挂载点${gl_bai}"
        else
            echo -e "  ${gl_bai}  - 目标路径类型: ${gl_lv}本地目录${gl_bai}"
        fi
        
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "  ${gl_bai}执行命令预览:${gl_bai}"
        echo -e "  ${gl_bai}  - 正向同步: ${gl_zi}rsync $options \"$source_path\" \"$target_path\"${gl_bai}"
        echo -e "  ${gl_bai}  - 反向同步: ${gl_zi}rsync $options \"$target_path\" \"$source_path\"${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "  ${gl_bai}定时任务检查:${gl_bai}"
        
        local cron_count=$(crontab -l 2>/dev/null | grep -c "local_rsync_run $num")
        if [[ $cron_count -gt 0 ]]; then
            local cron_jobs=$(crontab -l 2>/dev/null | grep "local_rsync_run $num")
            echo -e "  ${gl_bai}  - 定时任务: ${gl_lv}已设置 ($cron_count 个)${gl_bai}"
            while IFS= read -r cron_line; do
                echo -e "  ${gl_bai}    * $cron_line${gl_bai}"
            done <<< "$cron_jobs"
        else
            echo -e "  ${gl_bai}  - 定时任务: ${gl_huang}未设置${gl_bai}"
        fi
        
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "  ${gl_bai}同步建议:${gl_bai}"
        
        if [[ "$options" == *"--delete"* ]]; then
            echo -e "  ${gl_bai}  - ${gl_huang}⚠ 警告: 此任务会删除目标目录中多余的文件${gl_bai}"
        fi
        
        if [[ ! -d "$source_path" ]]; then
            echo -e "  ${gl_bai}  - ${gl_hong}✗ 错误: 源目录不存在，同步将失败${gl_bai}"
        fi
        
        if [[ ! -d "$target_path" ]] && [[ ! -w "$(dirname "$target_path")" ]]; then
            echo -e "  ${gl_bai}  - ${gl_huang}⚠ 注意: 目标目录不存在且父目录不可写，同步将失败${gl_bai}"
        fi
        
        if [[ "$options" != *"--no-perms"* ]] && [[ "$options" != *"--no-owner"* ]] && [[ "$options" != *"--no-group"* ]]; then
            if [[ "$source_path" =~ ^// ]] || [[ "$target_path" =~ ^// ]]; then
                echo -e "  ${gl_bai}  - ${gl_huang}💡 建议: 网络共享建议使用权限友好模式${gl_bai}"
            fi
        fi
    fi
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

local_rsync_manager() {
    local menu_name="${1:-上一级选单}"
    local_init_globals || return 1

    while true; do
        install sshpass rsync
        clear
        local_list_tasks
        echo ""
        local_view_schedules
        echo ""
        echo -e "${gl_zi}>>> Rsync本地同步工具${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo "本地目录之间同步，支持增量同步，高效稳定。"
        df -hT | grep -E "(cifs|smb)" 2>/dev/null || echo -e "${gl_huang}无Samba/CIFS挂载${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}创建新任务           ${gl_bufan}2.  ${gl_bai}查看任务详情"
        echo -e "${gl_bufan}3.  ${gl_bai}执行正向同步         ${gl_bufan}4.  ${gl_bai}执行反向同步"
        echo -e "${gl_bufan}5.  ${gl_bai}批量执行所有任务     ${gl_bufan}6.  ${gl_bai}删除同步任务"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}7.  ${gl_bai}创建定时任务         ${gl_bufan}8.  ${gl_bai}删除定时任务"
        echo -e "${gl_bufan}9.  ${gl_bai}编辑cron文件         ${gl_bufan}10. ${gl_bai}查看cron文件"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单       ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        read -r -e -p "请输入你的选择: " choice
        case $choice in
        1)  local_add_task ;;
        2)  local_show_task_details ;;
        3)  local_forward_sync_menu ;;
        4)  local_reverse_sync_menu ;;
        5)  local_run_all_tasks ;;
        6)  local_delete_task ;;
        7)  local_schedule_task ;;
        8)  local_delete_schedule ;;
        9)  edit_crontab; continue ;;
        10) list_beautify_all ;;
        0) cancel_return "已是主菜单" || continue ;;
        00 | 000 | 0000) exit_script ;;
        *) handle_invalid_input ;;
        esac
    done
}

local_rsync_manager