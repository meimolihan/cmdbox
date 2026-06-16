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
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
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
                if opkg list-installed 2>/dev/null | grep -q "^${pkg} "; then
                    installed=true
                    ver=$(opkg list-installed 2>/dev/null | grep "^${pkg} " | awk '{print $3}' || echo "")
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
                dnf install -y "$pkg" && install_success=true
                ;;
            yum)
                echo -e "${gl_bai}使用包管理器: ${gl_zi}yum (CentOS/RHEL)${gl_bai}"
                yum install -y "$pkg" && install_success=true
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
                pacman -S --noconfirm "$pkg" && install_success=true
                ;;
            zypper)
                echo -e "${gl_bai}使用包管理器: ${gl_zi}zypper (openSUSE)${gl_bai}"
                zypper --non-interactive install "$pkg" && install_success=true
                ;;
            pkg)
                echo -e "${gl_bai}使用包管理器: ${gl_zi}pkg (FreeBSD)${gl_bai}"
                pkg install -y "$pkg" && install_success=true
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

show_crontab_list() {
    if ! command -v crontab &>/dev/null; then
        echo -e "${gl_hong}错误：crontab命令不存在${gl_bai}"
        return 1
    fi

    local crontab_content
    crontab_content=$(crontab -l 2>/dev/null)

    if [[ -n "$crontab_content" ]]; then
        local valid_tasks
        valid_tasks=$(echo "$crontab_content" | grep -v '^#' | grep -v '^[[:space:]]*$')

        if [[ -n "$valid_tasks" ]]; then
            local line_number=1
            while IFS= read -r line; do
                if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]]; then
                    echo -e "${gl_huang}${line_number}. ${gl_lv}${line}${gl_bai}"
                    ((line_number++))
                fi
            done <<<"$crontab_content"
            return 0
        else
            echo -e "${gl_huang}当前用户没有有效的${gl_bufan}crontab${gl_huang}任务${gl_bai}（${gl_lv}只有注释和空行${gl_bai}）"
            return 0
        fi
    else
        echo -e "${gl_huang}当前用户没有${gl_bufan}crontab${gl_huang}任务${gl_bai}"
        return 0
    fi
}

view_raw_crontab() {
    clear
    echo -e "${gl_zi}>>> 查看crontab原始内容（包含注释）${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if ! command -v crontab &>/dev/null; then
        log_error "crontab命令不存在，请检查系统"
        exit_animation
        return 1
    fi

    local crontab_content
    crontab_content=$(crontab -l 2>/dev/null)

    if [[ -n "$crontab_content" ]]; then
        echo -e "${gl_lv}当前用户的crontab原始内容：${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo "$crontab_content" | awk '{printf "%2d    %s\n", NR, $0}'
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        local total_lines
        total_lines=$(echo "$crontab_content" | wc -l)
        local valid_tasks
        valid_tasks=$(echo "$crontab_content" | grep -v '^#' | grep -v '^[[:space:]]*$' | wc -l)

        echo -e "${gl_bai}总行数: ${gl_huang}${total_lines}${gl_bai}，有效任务数: ${gl_lv}${valid_tasks}${gl_bai}"
    else
        echo -e "${gl_huang}当前用户没有${gl_bufan}crontab${gl_huang}任务${gl_bai}"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

add_crontab() {
    clear
    echo -e "${gl_zi}>>> 添加新的cron任务${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if ! command -v crontab &>/dev/null; then
        log_error "crontab命令不存在，请检查系统"
        exit_animation
        return 1
    fi

    show_crontab_list

    local temp_file
    temp_file=$(mktemp)

    crontab -l 2>/dev/null >"$temp_file"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e ""
    echo -e "${gl_bufan}请按以下格式输入cron表达式和命令：${gl_bai}"
    echo -e "${gl_bufan}*   *   *   *   *   ${gl_huang}要执行的命令${gl_bai}/${gl_hong}脚本路径${gl_bai}\n\
${gl_zi}|   ${gl_lan}|   ${gl_huang}|   ${gl_lv}|   ${gl_hong}|${gl_bai}\n\
${gl_zi}|   ${gl_lan}|   ${gl_huang}|   ${gl_lv}|   ${gl_hong}└── ${gl_hong}星期 (0-7, 0和7都代表周日)${gl_bai}\n\
${gl_zi}|   ${gl_lan}|   ${gl_huang}|   ${gl_lv}└────── ${gl_lv}月份 (1-12)${gl_bai}\n\
${gl_zi}|  ${gl_lan} |   ${gl_huang}└────────── ${gl_huang}日期 (1-31)${gl_bai}\n\
${gl_zi}|   ${gl_lan}└────────────── ${gl_lan}小时 (0-23)${gl_bai}\n\
${gl_zi}└────────────────── ${gl_zi}分钟 (0-59)${gl_bai}"
    echo -e ""
    echo -e "${gl_bai}任务示例: ${gl_lv}0 1 * * * /path/to/script.sh${gl_bai}"
    echo -e "${gl_bai}示例说明: 表达式 ${gl_lv}0 1 * * *${gl_bai} 精准匹配 “每天凌晨 ${gl_huang}1 ${gl_bai}点整” 执行任务"

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    read -r -e -p "$(echo -e "${gl_bai}请输入cron任务 (${gl_huang}0${gl_bai}返回): ")" new_cron

    if [[ "$new_cron" == "0" ]]; then
        rm -f "$temp_file"
        cancel_return
        return
    fi

    if [[ -n "$new_cron" ]]; then
        echo "$new_cron" >>"$temp_file"

        if crontab "$temp_file" 2>/dev/null; then
            log_ok "任务添加成功"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_lv}已添加的任务：${gl_bai}"
            echo -e "${gl_hui}$new_cron${gl_bai}"
        else
            log_error "任务添加失败，请检查cron表达式格式"
        fi
    else
        log_warn "输入为空，未添加任何任务"
    fi

    rm -f "$temp_file"
    break_end
}

delete_crontab() {
    clear
    echo -e "${gl_zi}>>> 删除cron任务${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if ! command -v crontab &>/dev/null; then
        log_error "crontab命令不存在，请检查系统"
        exit_animation
        return 1
    fi

    local crontab_content
    crontab_content=$(crontab -l 2>/dev/null)

    local valid_tasks
    valid_tasks=$(echo "$crontab_content" | grep -v '^#' | grep -v '^[[:space:]]*$')

    if [[ -z "$valid_tasks" ]]; then
        echo -e "${gl_huang}当前用户没有有效的${gl_bufan}crontab${gl_huang}任务可删除${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation
        return
    fi

    echo -e "${gl_lv}当前crontab有效任务列表：${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local line_number=1
    local task_lines=()
    while IFS= read -r line; do
        if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]]; then
            echo -e "${gl_bufan}$(printf "%2d" $line_number). ${gl_bai}$line"
            task_lines+=("$line")
            ((line_number++))
        fi
    done <<<"$crontab_content"

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    read -r -e -p "$(echo -e "${gl_bai}请输入要删除的任务行号 (${gl_huang}0${gl_bai}返回): ")" line_num

    [[ "$line_num" == "0" ]] && { cancel_return "上一级选单"; return 1; }

    if [[ ! "$line_num" =~ ^[0-9]+$ ]]; then
        log_error "请输入有效的数字"
        exit_animation
        return
    fi

    local total_tasks=${#task_lines[@]}

    if [[ "$line_num" -gt 0 && "$line_num" -le "$total_tasks" ]]; then
        # 使用 sed 按行号删除（保留注释和空行结构）
        local target_line_num_in_original=0
        local current_line=0
        # 找到原文件中对应有效任务的行号
        while IFS= read -r line; do
            ((current_line++))
            if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]]; then
                ((target_line_num_in_original++))
                if [[ "$target_line_num_in_original" -eq "$line_num" ]]; then
                    break
                fi
            fi
        done <<<"$crontab_content"

        local temp_file
        temp_file=$(mktemp)
        echo "$crontab_content" | sed "${current_line}d" > "$temp_file"

        if crontab "$temp_file" 2>/dev/null; then
            log_ok "第 ${line_num} 行任务已删除"
            log_info "删除的任务: ${task_lines[$((line_num-1))]}"
        else
            log_error "删除任务失败"
        fi

        rm -f "$temp_file"
    else
        log_error "行号超出范围 (1-${total_tasks})"
    fi

    break_end
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

clear_crontab() {
    clear
    echo -e "${gl_zi}>>> 清空当前用户的所有crontab任务${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if ! command -v crontab &>/dev/null; then
        log_error "crontab命令不存在，请安装cron/crontabs组件"
        exit_animation
        return 1
    fi

    show_crontab_list

    echo -e "${gl_hong}⚠️  警告：这将彻底删除当前用户的所有crontab任务！${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}确认要清空吗？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
    confirm=${confirm:-N}

    case "$confirm" in
    [yY] | [yY][eE][sS])
        echo -e "${gl_lan}正在清空crontab ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        if crontab -r 2>/dev/null; then
            log_ok "crontab已清空（crontab -r）"
        elif echo "" | crontab - 2>/dev/null; then
            log_ok "crontab已清空（空内容替换）"
        else
            log_error "清空crontab失败"
        fi
        ;;
    *)
        log_info "已取消清空crontab操作"
        ;;
    esac

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

show_crontab_status() {
    if ! command -v crontab &>/dev/null; then
        echo -e "${gl_hong}✗ crontab 命令不存在，请安装 cron/cronie/crond${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return 1
    fi

    local cron_process_found=0
    local pid_list=""

    if command -v pidof &>/dev/null; then
        pid_list=$(pidof cron crond cronie 2>/dev/null | tr '\n' ' ')
        [ -n "$pid_list" ] && cron_process_found=1
    fi

    if [ $cron_process_found -eq 0 ] && command -v pgrep &>/dev/null; then
        pid_list=$(pgrep -f "(cron|crond|cronie)" 2>/dev/null | tr '\n' ' ')
        [ -n "$pid_list" ] && cron_process_found=1
    fi

    if [ $cron_process_found -eq 0 ]; then
        if ps aux 2>/dev/null | grep -v grep | grep -qiE "[c]ron|[c]rond"; then
            cron_process_found=1
            pid_list=$(ps aux 2>/dev/null | grep -v grep | grep -iE "(cron|crond)" | awk '{print $2}' | tr '\n' ' ')
        elif ps -ef 2>/dev/null | grep -v grep | grep -qiE "[c]ron|[c]rond"; then
            cron_process_found=1
            pid_list=$(ps -ef 2>/dev/null | grep -v grep | grep -iE "(cron|crond)" | awk '{print $2}' | tr '\n' ' ')
        fi
    fi

    if [ $cron_process_found -eq 1 ]; then
        echo -e "${gl_bai}进程状态: ${gl_lv}✓ cron 守护进程正在运行${gl_bai} (PID: ${gl_huang}${pid_list}${gl_bai})"
    else
        echo -e "${gl_bai}进程状态: ${gl_hong}✗ cron 守护进程未运行${gl_bai}"
    fi

    local service_name=""
    local systemd_active=""

    if command -v systemctl &>/dev/null; then
        for name in cron crond cronie; do
            if systemctl list-unit-files --type=service 2>/dev/null | grep -q "^${name}.service"; then
                service_name="$name"
                local active_state=$(systemctl is-active "$name" 2>/dev/null)
                local enabled_state=$(systemctl is-enabled "$name" 2>/dev/null)
                systemd_active="$active_state"
                case "$active_state" in
                    active)   echo -e "${gl_bai}服务状态: ${gl_lv}●${gl_bai} $name.service - ${gl_lv}已激活${gl_bai} (enabled: ${enabled_state:-unknown})" ;;
                    inactive) echo -e "${gl_bai}服务状态: ${gl_hong}○${gl_bai} $name.service - ${gl_hong}未激活${gl_bai}" ;;
                    *)        echo -e "${gl_bai}服务状态: ${gl_huang}?${gl_bai} $name.service - ${gl_huang}状态未知${gl_bai}" ;;
                esac
                break
            fi
        done

        if [ $cron_process_found -eq 0 ] && [ "$systemd_active" = "active" ]; then
            echo -e "${gl_huang}⚠️  注意：systemd 显示服务 active，但未找到 cron 进程。可能服务已死但仍被标记为 active。${gl_bai}"
            echo -e "${gl_huang}   建议执行：sudo systemctl restart $service_name${gl_bai}"
        fi
    fi

    if [ -z "$service_name" ] && command -v service &>/dev/null; then
        for name in cron crond; do
            if service "$name" status 2>/dev/null | grep -qi "running\|started\|active"; then
                service_name="$name"
                echo -e "${gl_bai}服务状态: ${gl_lv}●${gl_bai} $name - ${gl_lv}正在运行${gl_bai}"
                break
            elif [ -f "/etc/init.d/$name" ]; then
                service_name="$name"
                local status_output=$(service "$name" status 2>&1)
                if echo "$status_output" | grep -qi "not running\|stopped"; then
                    echo -e "${gl_bai}服务状态: ${gl_hong}○${gl_bai} $name - ${gl_hong}未运行${gl_bai}"
                else
                    echo -e "${gl_bai}服务状态: ${gl_huang}?${gl_bai} $name - ${gl_huang}状态未知${gl_bai}"
                fi
                break
            fi
        done
    fi

    if [ -z "$service_name" ] && command -v rc-service &>/dev/null; then
        for name in cron crond; do
            if rc-service "$name" status 2>/dev/null | grep -qi "started"; then
                service_name="$name"
                echo -e "${gl_bai}服务状态: ${gl_lv}●${gl_bai} $name (OpenRC) - ${gl_lv}正在运行${gl_bai}"
                break
            elif [ -f "/etc/init.d/$name" ]; then
                local status_output=$(rc-service "$name" status 2>&1)
                if echo "$status_output" | grep -qi "stopped"; then
                    echo -e "${gl_bai}服务状态: ${gl_hong}○${gl_bai} $name (OpenRC) - ${gl_hong}未运行${gl_bai}"
                else
                    echo -e "${gl_bai}服务状态: ${gl_huang}?${gl_bai} $name (OpenRC) - ${gl_huang}状态未知${gl_bai}"
                fi
                break
            fi
        done
    fi

    if [ -z "$service_name" ]; then
        if [ -x "/etc/init.d/cron" ]; then
            echo -e "${gl_bai}服务状态: ${gl_huang}i${gl_bai} /etc/init.d/cron 存在，请手动执行 '/etc/init.d/cron status' 查看"
        elif [ -x "/etc/init.d/crond" ]; then
            echo -e "${gl_bai}服务状态: ${gl_huang}i${gl_bai} /etc/init.d/crond 存在，请手动执行 '/etc/init.d/crond status' 查看"
        else
            echo -e "${gl_bai}服务状态: ${gl_hong}✗ 未检测到已知的 cron 服务管理器${gl_bai}"
        fi
    fi

}

detect_cron_service() {
    service_command=""
    cron_service_name=""

    if command -v systemctl &>/dev/null; then
        service_command="systemctl"
        for service in cron crond cronie; do
            if systemctl list-unit-files --type=service 2>/dev/null | grep -q "^${service}.service"; then
                cron_service_name="$service"
                break
            fi
        done
    elif command -v service &>/dev/null; then
        service_command="service"
        for service in cron crond; do
            if service --status-all 2>/dev/null | grep -q "\s${service}" || [ -f "/etc/init.d/${service}" ]; then
                cron_service_name="$service"
                break
            fi
        done
    elif command -v rc-service &>/dev/null; then
        service_command="rc-service"
        cron_service_name="cron"
    elif [ -f "/etc/init.d/cron" ] || [ -f "/etc/init.d/crond" ]; then
        service_command="init.d"
        if [ -f "/etc/init.d/cron" ]; then
            cron_service_name="cron"
        else
            cron_service_name="crond"
        fi
    fi
}

_stop_cron_service() {
    echo -e ""
    echo -e "${gl_zi}>>> 正在停止cron服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    detect_cron_service

    if [ -n "$service_command" ] && [ -n "$cron_service_name" ]; then
        local cmd=""
        case "$service_command" in
        "systemctl") cmd="systemctl stop $cron_service_name" ;;
        "service")   cmd="service $cron_service_name stop" ;;
        "rc-service")cmd="rc-service $cron_service_name stop" ;;
        "init.d")    cmd="/etc/init.d/$cron_service_name stop" ;;
        esac
        if eval "sudo $cmd" 2>/dev/null; then
            log_ok "cron服务已停止"
        else
            log_error "停止cron服务失败，可能需要root权限或服务未安装"
        fi
    else
        log_error "无法确定如何停止cron服务"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

_start_cron_service() {
    echo -e ""
    echo -e "${gl_zi}>>> 正在启动cron服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    detect_cron_service

    if [ -n "$service_command" ] && [ -n "$cron_service_name" ]; then
        local cmd=""
        case "$service_command" in
        "systemctl") cmd="systemctl start $cron_service_name" ;;
        "service")   cmd="service $cron_service_name start" ;;
        "rc-service")cmd="rc-service $cron_service_name start" ;;
        "init.d")    cmd="/etc/init.d/$cron_service_name start" ;;
        esac
        if eval "sudo $cmd" 2>/dev/null; then
            log_ok "cron服务已启动"
        else
            log_error "启动cron服务失败，可能需要root权限或服务未安装"
        fi
    else
        log_error "无法确定如何启动cron服务"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

_restart_cron_service() {
    echo -e ""
    echo -e "${gl_zi}>>> 正在重启cron服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    detect_cron_service

    if [ -n "$service_command" ] && [ -n "$cron_service_name" ]; then
        local cmd=""
        case "$service_command" in
        "systemctl") cmd="systemctl restart $cron_service_name" ;;
        "service")   cmd="service $cron_service_name restart" ;;
        "rc-service")cmd="rc-service $cron_service_name restart" ;;
        "init.d")    cmd="/etc/init.d/$cron_service_name restart" ;;
        esac
        if eval "sudo $cmd" 2>/dev/null; then
            log_ok "cron服务重启成功"
        else
            log_error "重启cron服务失败，可能需要root权限或服务未安装"
        fi
    else
        log_error "无法确定如何重启cron服务"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

_reload_cron_config() {
    echo -e ""
    echo -e "${gl_zi}>>> 重新加载cron配置 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    detect_cron_service

    if [ "$service_command" = "systemctl" ] && [ -n "$cron_service_name" ]; then
        if sudo systemctl reload "$cron_service_name" 2>/dev/null; then
            log_ok "cron配置重新加载成功"
        else
            log_warn "systemd reload不支持，尝试重启服务"
            sudo systemctl restart "$cron_service_name" 2>/dev/null && log_ok "服务已重启" || log_error "操作失败"
        fi
    else
        log_warn "当前系统不支持单独reload，建议使用重启功能"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

create_script_in_opt() {
    echo -e ""
    echo -e "${gl_zi}>>> 在${gl_huang}/opt/scripts${gl_zi}创建脚本文件并用编辑器打开${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local editor=""
    if command -v nano &>/dev/null; then
        editor="nano"
    elif command -v vim &>/dev/null; then
        editor="vim"
    elif command -v vi &>/dev/null; then
        editor="vi"
    else
        log_warn "未找到nano/vi/vim，尝试安装nano"
        install nano
        if command -v nano &>/dev/null; then
            editor="nano"
        else
            log_error "无法安装编辑器，请手动安装nano或vi"
            return 1
        fi
    fi

    local target_dir="/opt/scripts"

    if [ ! -d "$target_dir" ]; then
        log_info "目录 ${gl_lv}$target_dir${gl_bai} 不存在，正在创建 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        if mkdir -p "$target_dir" 2>/dev/null; then
            log_ok "目录创建成功"
        elif sudo mkdir -p "$target_dir" 2>/dev/null; then
            log_ok "使用sudo创建目录成功"
        else
            log_error "目录创建失败，请检查权限"
            return 1
        fi
    fi

    if [ ! -w "$target_dir" ]; then
        log_warn "目录不可写，尝试使用sudo"
        USE_SUDO="sudo"
    else
        USE_SUDO=""
    fi

    while true; do
        read -r -e -p "$(echo -e "${gl_bai}请输入脚本名称 (直接回车使用 ${gl_lv}test${gl_bai}, ${gl_huang}0${gl_bai}返回): ")" script_name

        case "$script_name" in
        0) cancel_return; return 0 ;;
        "") script_name="test" ;;
        *) ;;
        esac

        if [[ ! "$script_name" =~ \.sh$ ]]; then
            script_name="${script_name}.sh"
        fi

        local file_path="$target_dir/$script_name"

        if [ -f "$file_path" ]; then
            log_warn "文件 $file_path 已存在。是否覆盖？"
            read -r -e -p "$(echo -e "${gl_bai}确认覆盖吗? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
            case "$confirm" in
            [Yy] | [Yy][Ee][Ss])
                log_info "将覆盖现有文件。"
                ;;
            *)
                log_info "跳过创建。"
                continue
                ;;
            esac
        fi

        if $USE_SUDO touch "$file_path" 2>/dev/null; then
            echo -e "${gl_bai}文件 ${gl_huang}$file_path ${gl_bai}创建成功。"
            $USE_SUDO chmod +x "$file_path"
            $USE_SUDO "$editor" "$file_path"

            echo -e ""
            echo -e "${gl_zi}>>> 脚本文件使用说明${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_bufan}请按以下格式输入cron表达式和命令：${gl_bai}"
            echo -e "${gl_bufan}*   *   *   *   *   ${gl_huang}要执行的命令${gl_bai}/${gl_hong}脚本路径${gl_bai}\n\
${gl_zi}|   ${gl_lan}|   ${gl_huang}|   ${gl_lv}|   ${gl_hong}|${gl_bai}\n\
${gl_zi}|   ${gl_lan}|   ${gl_huang}|   ${gl_lv}|   ${gl_hong}└── ${gl_hong}星期 (0-7, 0和7都代表周日)${gl_bai}\n\
${gl_zi}|   ${gl_lan}|   ${gl_huang}|   ${gl_lv}└────── ${gl_lv}月份 (1-12)${gl_bai}\n\
${gl_zi}|  ${gl_lan} |   ${gl_huang}└────────── ${gl_huang}日期 (1-31)${gl_bai}\n\
${gl_zi}|   ${gl_lan}└────────────── ${gl_lan}小时 (0-23)${gl_bai}\n\
${gl_zi}└────────────────── ${gl_zi}分钟 (0-59)${gl_bai}"
            echo -e ""
            echo -e "${gl_bai}任务示例: ${gl_zi}0 ${gl_lan}1 ${gl_huang}* ${gl_lv}* ${gl_hong}* ${gl_bufan}$file_path${gl_bai}"
            echo -e "${gl_bai}示例说明: 表达式 ${gl_lv}0 1 * * *${gl_bai} 精准匹配 “每天凌晨 ${gl_huang}1 ${gl_bai}点整” 执行任务"

            log_ok "脚本文件创建/编辑完成"
            echo -e "${gl_bai}文件：${gl_lv}${file_path}${gl_bai}"
            break_end
            return 0
        else
            log_error "文件创建失败，请检查权限"
            read -r -e -p "$(echo -e "${gl_bai}是否重试? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" retry
            case "$retry" in
            [Yy] | [Yy][Ee][Ss]) continue ;;
            *) return 1 ;;
            esac
        fi
    done
}

delete_scripts() {
    local target_dir="/opt/scripts"
    if [ ! -d "$target_dir" ]; then
        log_warn "目录 $target_dir 不存在"
        exit_animation
        return
    fi

    cd "$target_dir" || { log_error "无法进入目录"; return; }

    while true; do
        clear
        echo -e "${gl_zi}>>> 删除脚本文件 (目录: $target_dir)${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        local files=()
        local i=1
        for f in *; do
            if [ -e "$f" ]; then
                echo -e "${gl_bufan}$(printf "%2d" $i). ${gl_bai}$f"
                files+=("$f")
                ((i++))
            fi
        done

        if [ ${#files[@]} -eq 0 ]; then
            echo -e "${gl_huang}目录为空，没有可删除的文件${gl_bai}"
            break_end
            return
        fi

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入要删除的序号 (空格分隔多个, ${gl_huang}0${gl_bai}返回, ${gl_hong}a${gl_bai}全删): ")" input

        if [[ "$input" == "0" ]]; then
            cancel_return
            return
        fi

        if [[ "$input" == "a" || "$input" == "A" ]]; then
            echo -e "${gl_hong}⚠️  警告：将删除当前目录下所有文件！${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bai}确认删除所有? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                rm -rf *
                log_ok "已清空目录"
            fi
            break_end
            continue
        fi

        local to_del=()
        for num in $input; do
            if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#files[@]}" ]; then
                to_del+=("${files[$((num-1))]}")
            else
                log_warn "无效序号: $num"
            fi
        done

        if [ ${#to_del[@]} -eq 0 ]; then
            log_warn "没有有效的文件被选中"
            break_end
            continue
        fi

        echo -e "${gl_huang}即将删除以下文件：${gl_bai}"
        for f in "${to_del[@]}"; do
            echo -e "  ${gl_lv}$f${gl_bai}"
        done
        read -r -e -p "$(echo -e "${gl_bai}确认删除? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            for f in "${to_del[@]}"; do
                if rm -rf "$f" 2>/dev/null; then
                    echo -e "${gl_lv}✓ 已删除: $f${gl_bai}"
                else
                    echo -e "${gl_hong}✗ 删除失败: $f${gl_bai}"
                fi
            done
        fi
        break_end
    done
}

linux_crontab_management() {
    while true; do
        clear
        echo -e "${gl_zi}>>> cron计划任务管理器${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        show_crontab_status
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        show_crontab_list
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}停止cron服务            ${gl_bufan}2.  ${gl_bai}启动cron服务"
        echo -e "${gl_bufan}3.  ${gl_bai}重启cron服务            ${gl_bufan}4.  ${gl_bai}重载cron配置"
        echo -e "${gl_bufan}5.  ${gl_bai}创建脚本文件            ${gl_bufan}6.  ${gl_bai}删除脚本文件"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}7.  ${gl_bai}添加cron任务            ${gl_bufan}8.  ${gl_bai}删除cron任务"
        echo -e "${gl_bufan}9.  ${gl_bai}编辑cron文件            ${gl_bufan}10. ${gl_bai}查看cron文件"
        echo -e "${gl_bufan}11. ${gl_bai}刷新任务列表            ${gl_bufan}12. ${gl_bai}清空cron任务"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单          ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" choice

        case "$choice" in
        1)  _stop_cron_service; continue ;;
        2)  _start_cron_service; continue ;;
        3)  _restart_cron_service; continue ;;
        4)  _reload_cron_config; continue ;;
        5)  create_script_in_opt; continue ;;
        6)  delete_scripts; continue ;;
        7)  add_crontab; continue ;;
        8)  delete_crontab; continue ;;
        9)  edit_crontab; continue ;;
        10) view_raw_crontab; continue ;;
        11) continue ;;
        12) clear_crontab; continue ;;
        0) cancel_return "已是主菜单" || continue ;;
        00 | 000 | 0000) exit_script ;;
        *)  handle_invalid_input ;;
        esac
    done
}

linux_crontab_management