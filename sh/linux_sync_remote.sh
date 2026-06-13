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

list_tasks() {
    echo "已保存的远程同步任务:"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${gl_huang}配置文件不存在，暂无同步任务${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        return 0
    fi

    if [[ ! -s "$CONFIG_FILE" ]]; then
        echo -e "${gl_huang}暂无同步任务${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        return 0
    fi

    local line_num=1
    while IFS='|' read -r name local_path remote remote_path port options auth_method password_or_key; do
        printf "${gl_bufan}%3d. ${gl_bai}- ${gl_zi}%-10s${gl_bai} ( ${gl_huang}%s${gl_bai} -> ${gl_bufan}%s${gl_bai}:${gl_lv}%s${gl_bai} )\n" \
            "$line_num" "$name" "$local_path" "$remote" "$remote_path"
        ((line_num++))
    done <"$CONFIG_FILE"

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
}

remote_add_task() {
    clear
    echo ""
    echo -e "${gl_huang}>>> 创建新任务 (远程同步)${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo "创建新同步任务示例："
    echo -e "  ${gl_bai}- 任务名称: ${gl_huang}backup_www${gl_bai}"
    echo -e "  ${gl_bai}- 本地目录: ${gl_huang}/var/www${gl_bai}"
    echo -e "  ${gl_bai}- 远程地址: ${gl_huang}user@192.168.1.100${gl_bai}"
    echo -e "  ${gl_bai}- 远程目录: ${gl_huang}/backup/www${gl_bai}"
    echo -e "  ${gl_bai}- 端口号  : ${gl_huang}(默认 22)${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "请输入任务名称 (${gl_huang}0${gl_bai}返回): ")" name
    [[ -z "$name" ]] && { cancel_empty "上一级选单"; return 1; }
    [[ "$name" == "0" ]] && { cancel_return "上一级选单"; return 1; }

    read -r -e -p "$(echo -e "请输入本地目录 (${gl_huang}0${gl_bai}返回): ")" local_path
    [[ -z "$local_path" ]] && { cancel_empty "上一级选单"; return 1; }
    [[ "$local_path" == "0" ]] && { cancel_return "上一级选单"; return 1; }

    read -r -e -p "$(echo -e "请输入远程用户@IP (${gl_huang}0${gl_bai}返回): ")" remote
    [[ -z "$remote" ]] && { cancel_empty "上一级选单"; return 1; }
    [[ "$remote" == "0" ]] && { cancel_return "上一级选单"; return 1; }

    read -r -e -p "$(echo -e "请输入远程目录 (${gl_huang}0${gl_bai}返回): ")" remote_path
    [[ -z "$remote_path" ]] && { cancel_empty "上一级选单"; return 1; }
    [[ "$remote_path" == "0" ]] && { cancel_return "上一级选单"; return 1; }

    read -r -e -p "$(echo -e "请输入 SSH 端口 (默认 22, ${gl_huang}0${gl_bai}返回): ")" port
    [[ "$port" == "0" ]] && { cancel_return "上一级选单"; return 1; }  # break 或 continue 或 return ，视上下文而定
    port=${port:-22}

    local_path="${local_path%/}/"
    remote_path="${remote_path%/}/"

    echo ""
    echo -e "${gl_huang}>>> 请选择身份验证方式${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bufan}1. ${gl_bai}密码"
    echo -e "${gl_bufan}2. ${gl_bai}密钥"
    echo -e "${gl_bufan}0. ${gl_bai}返回"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "请输入你的选择: " auth_choice
    [[ -z "$auth_choice" ]] && { cancel_empty "上一级选单"; continue; }
    [[ "$auth_choice" == "0" ]] && { cancel_return "上一级选单"; continue; }

    case $auth_choice in
    1)
        read -r -s -p "请输入密码 (输入0并回车可返回): " password_or_key
        echo
        if [[ "$password_or_key" == "0" ]]; then return; fi
        auth_method="password"
        ;;
    2)
        echo "请粘贴密钥内容 (粘贴完成后按两次回车，输入0并回车可返回)："
        IFS= read -r first_line
        if [[ "$first_line" == "0" ]]; then return; fi

        local password_or_key="$first_line"$'\n'
        while IFS= read -r line; do
            if [[ -z "$line" && "$password_or_key" == *"-----BEGIN"* ]]; then
                break
            fi
            if [[ -n "$line" || "$password_or_key" == *"-----BEGIN"* ]]; then
                password_or_key+="${line}"$'\n'
            fi
        done

        if [[ "$password_or_key" == *"-----BEGIN"* && "$password_or_key" == *"PRIVATE KEY-----"* ]]; then
            local key_file="$KEY_DIR/${name}_sync.key"
            echo -n "$password_or_key" >"$key_file"
            chmod 600 "$key_file"
            password_or_key="$key_file"
            auth_method="key"
        else
            echo -e "${gl_hong}无效的密钥内容！${gl_bai}"
            exit_animation
            return
        fi
        ;;
    *)
        echo -e "${gl_hong}无效的选择！${gl_bai}"
        exit_animation
        return
        ;;
    esac

    echo ""
    echo -e "${gl_huang}>>> 请选择同步模式${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bufan}1. ${gl_bai}标准模式 (-avz)"
    echo -e "${gl_bufan}2. ${gl_bai}删除目标文件 (-avz --progress --delete-delay)"
    echo -e "${gl_bufan}0. ${gl_bai}返回"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "请输入你的选择: " mode
    if [[ "$mode" == "0" ]]; then return; fi
    case $mode in
    1) options="-avz" ;;
    2) options="-avz --progress --delete-delay" ;;
    *)
        echo "无效选择，使用默认 -avz"
        exit_animation
        options="-avz"
        ;;
    esac

    echo "$name|$local_path|$remote|$remote_path|$port|$options|$auth_method|$password_or_key" >>"$CONFIG_FILE"

    echo -e "${gl_lv}任务已保存!${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

remote_delete_task() {
    echo ""
    echo -e "${gl_zi}>>> 删除远程同步任务${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}请输入要删除的任务编号(${gl_huang}0${gl_bai}返回): ")" num

    [ "$num" = "0" ] && { cancel_return "Rsync远程同步工具"; return 1; }
    [ -z "$num" ] && { cancel_empty "上一级选单"; return 1; }

    local task
    task=$(sed -n "${num}p" "$CONFIG_FILE")
    if [[ -z "$task" ]]; then
        echo -e "${gl_hong}错误：未找到对应的任务。${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation
        return
    fi

    IFS='|' read -r -r name local_path remote remote_path port options auth_method password_or_key <<<"$task"

    if [[ "$auth_method" == "key" && "$password_or_key" == "$KEY_DIR"* ]]; then
        rm -f "$password_or_key"
    fi

    sed -i "${num}d" "$CONFIG_FILE"
    echo -e "${gl_lv}任务已删除!${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

remote_run_task() {
    echo ""
    echo -e "${gl_zi}>>> 执行同步任务${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    CONFIG_FILE="$HOME/.remote_rsync_tasks"
    CRON_FILE="$HOME/.remote_rsync_cron"

    local direction="push"
    local num

    if [[ "$1" == "push" || "$1" == "pull" ]]; then
        direction="$1"
        num="$2"
    else
        num="$1"
    fi

    read -r -e -p "$(echo -e "${gl_bai}请输入要执行的任务编号(${gl_huang}0${gl_bai}返回): ")" num

    [ "$num" = "0" ] && { cancel_return "Rsync远程同步工具"; return 1; }
    [ -z "$num" ] && { cancel_empty "上一级选单"; return 1; }

    local task=$(sed -n "${num}p" "$CONFIG_FILE")
    if [[ -z "$task" ]]; then
        echo -e "${gl_hong}错误: 未找到该任务!${gl_bai}"
        return
    fi

    IFS='|' read -r name local_path remote remote_path port options auth_method password_or_key <<<"$task"

    if [[ "$direction" == "pull" ]]; then
        echo -e ""
        echo -e "${gl_zi}>>> 正在拉取同步到本地: ${gl_huang}$remote:$remote_path ${gl_bai}-> ${gl_lv}$local_path ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        source="$remote:$remote_path"
        destination="$local_path"
    else
        echo -e ""
        echo -e "${gl_zi}>>> 正在推送同步到远端: ${gl_huang}$local_path ${gl_bai}-> ${gl_lv}$remote:$remote_path ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        source="$local_path"
        destination="$remote:$remote_path"
    fi

    local ssh_options="-p $port -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

    if [[ "$auth_method" == "password" ]]; then
        if ! command -v sshpass &>/dev/null; then
            echo -e "${gl_hong}错误：未安装 ${gl_huang}sshpass${gl_hong}，请先安装 ${gl_huang}sshpass${gl_hong}。${gl_bai}"
            echo "安装方法："
            echo -e "  - ${gl_huang}Ubuntu/Debian: ${gl_lv}apt install sshpass${gl_bai}"
            echo -e "  - ${gl_huang}CentOS/RHEL: ${gl_lv}yum install sshpass${gl_bai}"
            exit_animation
            return
        fi
        sshpass -p "$password_or_key" rsync $options -e "ssh $ssh_options" "$source" "$destination"
    else
        if [[ ! -f "$password_or_key" ]]; then
            echo -e "${gl_hong}错误：密钥文件不存在：${gl_huang}$password_or_key${gl_bai}"
            exit_animation
            return
        fi

        if [[ "$(stat -c %a "$password_or_key")" != "600" ]]; then
            echo -e "${gl_huang}警告：密钥文件权限不正确，正在修复 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            chmod 600 "$password_or_key"
        fi

        rsync $options -e "ssh -i $password_or_key $ssh_options" "$source" "$destination"
    fi

    if [[ $? -eq 0 ]]; then
        echo -e "${gl_lv}同步完成!${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
    else
        echo -e ""
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_hong}同步失败! 请检查以下内容：${gl_bai}"
        echo -e "${gl_bufan}1. ${gl_bai}网络连接是否正常"
        echo -e "${gl_bufan}2. ${gl_bai}远程主机是否可访问"
        echo -e "${gl_bufan}3. ${gl_bai}认证信息是否正确"
        echo -e "${gl_bufan}4. ${gl_bai}本地和远程目录是否有正确的访问权限"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
    fi
}

remote_schedule_task() {
    echo -e ""
    echo -e "${gl_zi}>>> 创建远程定时任务${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}请输入要定时同步的任务编号(${gl_huang}0${gl_bai}返回): ")" num

    [ "$num" = "0" ] && { cancel_return "Rsync远程同步工具"; return 1; }
    [ -z "$num" ] && { cancel_empty "上一级选单"; return 1; }

    if ! [[ "$num" =~ ^[0-9]+$ ]]; then
        echo "错误: 请输入有效的任务编号！"
        exit_animation
        return
    fi

    local task_name=""
    if [[ -f "$CONFIG_FILE" ]]; then
        task_name=$(sed -n "${num}p" "$CONFIG_FILE" 2>/dev/null | cut -d'|' -f1)
    fi
    
    if [[ -z "$task_name" ]]; then
        echo -e "${gl_hong}错误: 未找到编号为 ${gl_huang}$num ${gl_hong}的任务！${gl_bai}"
        exit_animation
        return
    fi

    echo ""
    echo -e "${gl_huang}>>> 请选择定时执行间隔${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bufan}1. ${gl_bai}每小时执行一次"
    echo -e "${gl_bufan}2. ${gl_bai}每天执行一次"
    echo -e "${gl_bufan}3. ${gl_bai}每周执行一次"
    echo -e "${gl_bufan}4. ${gl_bai}每月执行一次"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "请输入你的选项: " interval

    local random_minute
    random_minute=$(shuf -i 0-59 -n 1)
    local cron_time=""
    case "$interval" in
    1) cron_time="$random_minute * * * *" ;; # 每小时，随机分钟执行
    2) cron_time="$random_minute 0 * * *" ;; # 每天，随机分钟执行
    3) cron_time="$random_minute 0 * * 1" ;; # 每周，随机分钟执行
    4) cron_time="$random_minute 4 1 * *" ;; # 每月1号凌晨4点，随机分钟执行
    *)
        echo "错误: 请输入有效的选项！"
        exit_animation
        return
        ;;
    esac

    local cron_job="$cron_time m remote_rsync_run $num"

    if crontab -l | grep -q "m remote_rsync_run $num"; then
        echo -e "${gl_hong}错误: 该任务的定时同步已存在！${gl_bai}"
        exit_animation
        return
    fi

    (
        crontab -l 2>/dev/null
        echo "# 远程Rsync定时任务: $task_name"
        echo "$cron_job"
        echo ""
    ) | crontab -
    echo -e "${gl_lv}✓ 定时任务已创建：${gl_huang}$cron_job${gl_bai}"
    echo -e "${gl_bai}任务名称: ${gl_huang}$task_name${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

view_tasks() {
    echo "当前的定时任务:"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if ! crontab -l >/dev/null 2>&1; then
        echo -e "${gl_huang}当前用户暂无定时任务${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        return 0
    fi

    local crontab_content
    crontab_content=$(crontab -l 2>/dev/null)
    local task_count=0

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        if [[ "$line" == *"m remote_rsync_run"* ]]; then
            ((task_count++))
            local task_num=$(echo "$line" | grep -oE "m remote_rsync_run [0-9]+" | awk '{print $3}')
            local task_name=""
            local local_path=""
            local remote=""
            local remote_path=""
            local options=""
            
            local prev_line=$(echo "$crontab_content" | sed -n "/^#.*远程Rsync定时任务:.*任务编号: $task_num\$/p" | head -1)
            if [[ -n "$prev_line" ]]; then
                task_name=$(echo "$prev_line" | sed -n 's/^#.*远程Rsync定时任务: \(.*\) (任务编号: [0-9]*)$/\1/p')
            fi
            
            if [[ -z "$task_name" ]] && [[ -n "$task_num" ]] && [[ -f "$CONFIG_FILE" ]]; then
                local task_line=$(sed -n "${task_num}p" "$CONFIG_FILE" 2>/dev/null)
                if [[ -n "$task_line" ]]; then
                    IFS='|' read -r task_name local_path remote remote_path port options auth_method password_or_key <<<"$task_line"
                fi
            fi

            echo -e "${gl_bufan}${task_count}. ${gl_bai}Cron表达式: ${gl_zi}${line}${gl_bai}"
            if [[ -n "$task_name" ]]; then
                echo -e "   任务名称: ${gl_huang}${task_name}${gl_bai}"
                echo -e "   任务编号: ${gl_huang}${task_num}${gl_bai}"
                if [[ -n "$local_path" ]]; then
                    echo -e "   本地目录: ${gl_huang}${local_path}${gl_bai}"
                    echo -e "   远程地址: ${gl_lv}${remote}:${remote_path}${gl_bai}"
                    echo -e "   端口号:   ${gl_bai}${port}${gl_bai}"
                    echo -e "   同步选项: ${gl_zi}${options}${gl_bai}"
                    echo -e "   认证方式: ${gl_huang}${auth_method}${gl_bai}"
                fi
            else
                echo -e "   ${gl_hong}警告: 无法获取任务详细信息（可能对应的同步任务已被删除）${gl_bai}"
            fi
            echo ""
        fi
    done <<<"$crontab_content"

    if [[ $task_count -eq 0 ]]; then
        echo -e "${gl_huang}暂无定时同步任务${gl_bai}"
    else
        echo -e "${gl_bai}共找到 ${gl_huang}${task_count} ${gl_bai}个定时任务${gl_bai}"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
}

remote_delete_task_schedule() {
    echo ""
    echo -e "${gl_zi}>>> 删除定时任务${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    local crontab_content
    crontab_content=$(crontab -l 2>/dev/null)
    
    if [[ $? -ne 0 ]] || [[ -z "$crontab_content" ]]; then
        echo -e "${gl_huang}当前用户暂无定时任务${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation
        return 0
    fi
    
    local remote_task_count=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        if [[ "$line" == *"m remote_rsync_run"* ]]; then
            ((remote_task_count++))
        fi
    done <<<"$crontab_content"
    
    if [[ $remote_task_count -eq 0 ]]; then
        echo -e "${gl_huang}暂无远程同步定时任务，无需删除。${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation
        return 0
    fi
    
    echo -e "${gl_bai}提示: 请输入要删除的任务在列表中的序号 (1~${remote_task_count})${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}请输入要删除的任务编号(${gl_huang}0${gl_bai}返回): ")" num

    [ "$num" = "0" ] && { cancel_return "Rsync远程同步工具"; return 1; }
    [ -z "$num" ] && { cancel_empty "上一级选单"; return 1; }

    if ! [[ "$num" =~ ^[0-9]+$ ]]; then
        echo "错误: 请输入有效的任务编号！"
        exit_animation
        return
    fi

    if [[ "$num" -lt 1 ]] || [[ "$num" -gt "$remote_task_count" ]]; then
        echo -e "${gl_hong}错误: 请输入有效的任务编号 (1~${remote_task_count})！${gl_bai}"
        exit_animation
        return
    fi

    local current_task=0
    local target_line=""
    local target_comment_line=""
    local line_num=0
    
    while IFS= read -r line; do
        ((line_num++))
        [[ -z "$line" ]] && continue
        
        if [[ "$line" == *"m remote_rsync_run"* ]]; then
            ((current_task++))
            if [[ $current_task -eq $num ]]; then
                target_line="$line"
                if [[ $line_num -gt 1 ]]; then
                    local prev_line_num=$((line_num - 1))
                    local prev_line=$(echo "$crontab_content" | sed -n "${prev_line_num}p")
                    if [[ "$prev_line" =~ ^#.*远程Rsync定时任务 ]]; then
                        target_comment_line="$prev_line"
                    fi
                fi
                break
            fi
        fi
    done <<<"$crontab_content"

    if [[ -z "$target_line" ]]; then
        echo -e "${gl_hong}错误: 无法找到对应的定时任务${gl_bai}"
        exit_animation
        return
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}即将删除的任务:${gl_bai}"
    if [[ -n "$target_comment_line" ]]; then
        echo -e "  ${gl_huang}注释行: $target_comment_line${gl_bai}"
    fi
    echo -e "  ${gl_zi}任务行: $target_line${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    read -r -e -p "$(echo -e "${gl_bai}确认删除吗? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
    [ "$confirm" = "0" ] && { cancel_return "上一级选单"; return 1; }
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${gl_huang}取消删除操作${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation
        return
    fi

    local temp_file
    temp_file=$(mktemp)
    
    if [[ -n "$target_comment_line" ]]; then
        crontab -l 2>/dev/null | grep -vF "$target_comment_line" | grep -vF "$target_line" > "$temp_file"
    else
        crontab -l 2>/dev/null | grep -vF "$target_line" > "$temp_file"
    fi
    
    crontab "$temp_file"
    rm -f "$temp_file"
    
    echo -e "${gl_lv}定时任务已删除!${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

remote_show_task_details() {
    echo ""
    echo -e "${gl_zi}>>> 查看远程任务详细信息${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${gl_huang}配置文件不存在，暂无同步任务${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation
        return 0
    fi
    
    if [[ ! -s "$CONFIG_FILE" ]]; then
        echo -e "${gl_huang}暂无同步任务${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation
        return 0
    fi
    
    echo -e "${gl_bai}提示: 直接${gl_lv}回车${gl_bai}查看全部任务，输入${gl_huang}0${gl_bai}返回${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "请输入要查看的任务编号: " num

    [ "$num" = "0" ] && { cancel_return "Rsync远程同步工具"; return 1; }
    
    if [[ -z "$num" ]]; then
        echo ""
        echo -e "${gl_zi}>>> 所有同步任务详情${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        local line_num=1
        while IFS='|' read -r name local_path remote remote_path port options auth_method password_or_key; do
            echo -e "${gl_bufan}任务 #${line_num}${gl_bai}"
            echo -e "  ${gl_bai}任务名称: ${gl_zi}$name${gl_bai}"
            echo -e "  ${gl_bai}本地目录: ${gl_huang}$local_path${gl_bai}"
            echo -e "  ${gl_bai}远程地址: ${gl_bufan}$remote${gl_bai}"
            echo -e "  ${gl_bai}远程目录: ${gl_lv}$remote_path${gl_bai}"
            echo -e "  ${gl_bai}SSH 端口: ${gl_bai}$port"
            echo -e "  ${gl_bai}同步选项: ${gl_zi}$options${gl_bai}"
            echo -e "  ${gl_bai}认证方式: ${gl_huang}$auth_method${gl_bai}"
            
            if [[ "$auth_method" == "password" ]]; then
                echo -e "  ${gl_bai}密码: ${gl_hong}****** (已加密)${gl_bai}"
            elif [[ "$auth_method" == "key" ]]; then
                echo -e "  ${gl_bai}密钥文件: ${gl_lv}$password_or_key${gl_bai}"
                if [[ -f "$password_or_key" ]]; then
                    local key_perms=$(stat -c "%a" "$password_or_key" 2>/dev/null)
                    echo -e "  ${gl_bai}密钥权限: ${gl_bai}${key_perms}"
                    
                    if [[ "$key_perms" != "600" ]]; then
                        echo -e "  ${gl_hong}警告: 密钥文件权限不安全!${gl_bai}"
                    fi
                else
                    echo -e "  ${gl_hong}警告: 密钥文件不存在!${gl_bai}"
                fi
            fi
            
            if [[ -d "$local_path" ]]; then
                local local_size=$(du -sh "$local_path" 2>/dev/null | cut -f1)
                echo -e "  ${gl_bai}本地目录大小: ${gl_bai}${local_size:-未知}"
            else
                echo -e "  ${gl_hong}警告: 本地目录不存在!${gl_bai}"
            fi
            
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            ((line_num++))
        done <"$CONFIG_FILE"
        echo -e "${gl_lv}共找到 $((line_num-1)) 个同步任务${gl_bai}"
    else
        local task=$(sed -n "${num}p" "$CONFIG_FILE" 2>/dev/null)
        if [[ -z "$task" ]]; then
            echo -e "${gl_hong}错误: 未找到任务 #$num${gl_bai}"
            exit_animation
            return
        fi
        
        IFS='|' read -r name local_path remote remote_path port options auth_method password_or_key <<<"$task"
        
        echo ""
        echo -e "${gl_zi}>>> 任务 #$num 详情${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "  ${gl_bai}任务名称: ${gl_zi}$name${gl_bai}"
        echo -e "  ${gl_bai}本地目录: ${gl_huang}$local_path${gl_bai}"
        echo -e "  ${gl_bai}远程地址: ${gl_bufan}$remote${gl_bai}"
        echo -e "  ${gl_bai}远程目录: ${gl_lv}$remote_path${gl_bai}"
        echo -e "  ${gl_bai}SSH 端口: ${gl_bai}$port"
        echo -e "  ${gl_bai}同步选项: ${gl_zi}$options${gl_bai}"
        echo -e "  ${gl_bai}认证方式: ${gl_huang}$auth_method${gl_bai}"
        
        if [[ "$auth_method" == "password" ]]; then
            echo -e "  ${gl_bai}密码: ${gl_hong}****** (已加密)${gl_bai}"
        elif [[ "$auth_method" == "key" ]]; then
            echo -e "  ${gl_bai}密钥文件: ${gl_lv}$password_or_key${gl_bai}"
            if [[ -f "$password_or_key" ]]; then
                local key_perms=$(stat -c "%a" "$password_or_key" 2>/dev/null)
                echo -e "  ${gl_bai}密钥权限: ${gl_bai}${key_perms}"
                
                if [[ "$key_perms" != "600" ]]; then
                    echo -e "  ${gl_hong}警告: 密钥文件权限不安全! 建议执行:${gl_bai}"
                    echo -e "  ${gl_bai}chmod 600 \"$password_or_key\"${gl_bai}"
                fi
                
                echo -e "  ${gl_bai}密钥文件信息:${gl_bai}"
                if file "$password_or_key" | grep -q "PEM RSA private key"; then
                    echo -e "  ${gl_bai}  - 类型: RSA 私钥"
                elif file "$password_or_key" | grep -q "PEM EC private key"; then
                    echo -e "  ${gl_bai}  - 类型: EC 私钥"
                elif file "$password_or_key" | grep -q "PEM DSA private key"; then
                    echo -e "  ${gl_bai}  - 类型: DSA 私钥"
                elif file "$password_or_key" | grep -q "OpenSSH private key"; then
                    echo -e "  ${gl_bai}  - 类型: OpenSSH 私钥"
                else
                    echo -e "  ${gl_bai}  - 类型: 未知"
                fi
            else
                echo -e "  ${gl_hong}错误: 密钥文件不存在!${gl_bai}"
            fi
        fi
        
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "  ${gl_bai}本地目录检查:${gl_bai}"
        if [[ -d "$local_path" ]]; then
            local local_size=$(du -sh "$local_path" 2>/dev/null | cut -f1)
            local file_count=$(find "$local_path" -type f 2>/dev/null | wc -l)
            echo -e "  ${gl_bai}  - 存在: ${gl_lv}是${gl_bai}"
            echo -e "  ${gl_bai}  - 大小: ${gl_bai}${local_size:-未知}"
            echo -e "  ${gl_bai}  - 文件数: ${gl_bai}${file_count}"
        else
            echo -e "  ${gl_bai}  - 存在: ${gl_hong}否${gl_bai}"
        fi
        
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "  ${gl_bai}连接测试:${gl_bai}"
        echo -e "  ${gl_bai}正在测试 SSH 连接 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        
        local ssh_test_cmd=""
        if [[ "$auth_method" == "password" ]]; then
            if command -v sshpass &>/dev/null; then
                ssh_test_cmd="sshpass -p '$password_or_key' ssh -p $port -o StrictHostKeyChecking=no -o ConnectTimeout=5 $remote 'echo connected' 2>&1"
            else
                echo -e "  ${gl_hong}  - sshpass 未安装，无法测试密码连接${gl_bai}"
            fi
        else
            ssh_test_cmd="ssh -i '$password_or_key' -p $port -o StrictHostKeyChecking=no -o ConnectTimeout=5 $remote 'echo connected' 2>&1"
        fi
        
        if [[ -n "$ssh_test_cmd" ]]; then
            local ssh_output
            ssh_output=$(eval "$ssh_test_cmd" 2>&1)
            if echo "$ssh_output" | grep -q "connected"; then
                echo -e "  ${gl_bai}  - SSH 连接: ${gl_lv}成功${gl_bai}"
            else
                echo -e "  ${gl_bai}  - SSH 连接: ${gl_hong}失败${gl_bai}"
                echo -e "  ${gl_bai}  - 错误信息: ${gl_hong}$ssh_output${gl_bai}"
            fi
        fi
        
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "  ${gl_bai}执行同步命令:${gl_bai}"
        if [[ "$auth_method" == "password" ]]; then
            if command -v sshpass &>/dev/null; then
                echo -e "  ${gl_bai}  - 推送到远端: ${gl_zi}sshpass -p '******' rsync $options -e \"ssh -p $port -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null\" \"$local_path\" \"$remote:$remote_path\"${gl_bai}"
                echo -e "  ${gl_bai}  - 从远端拉取: ${gl_zi}sshpass -p '******' rsync $options -e \"ssh -p $port -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null\" \"$remote:$remote_path\" \"$local_path\"${gl_bai}"
            else
                echo -e "  ${gl_hong}  - sshpass 未安装，请先安装${gl_bai}"
            fi
        else
            echo -e "  ${gl_bai}  - 推送到远端: ${gl_zi}rsync $options -e \"ssh -i '$password_or_key' -p $port -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null\" \"$local_path\" \"$remote:$remote_path\"${gl_bai}"
            echo -e "  ${gl_bai}  - 从远端拉取: ${gl_zi}rsync $options -e \"ssh -i '$password_or_key' -p $port -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null\" \"$remote:$remote_path\" \"$local_path\"${gl_bai}"
        fi
    fi
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

remote_run_all_tasks_push() {
    echo ""
    echo -e "${gl_huang}>>> 批量推送所有任务（推送到远端）${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${gl_huang}配置文件不存在，暂无同步任务${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation
        return 0
    fi
    
    if [[ ! -s "$CONFIG_FILE" ]]; then
        echo -e "${gl_huang}暂无同步任务${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation
        return 0
    fi
    
    local total_tasks=$(wc -l <"$CONFIG_FILE")
    echo -e "${gl_bai}找到 ${gl_huang}${total_tasks} ${gl_bai}个同步任务${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    echo -e "${gl_hong}⚠ 警告：即将批量执行所有任务，这可能会花费较长时间${gl_bai}"
    echo -e "${gl_huang}请确保网络连接稳定，且远程服务器可访问${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    read -r -e -p "$(echo -e "${gl_bai}确认执行批量推送吗? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${gl_huang}已取消批量执行${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation
        return
    fi
    
    echo -e "${gl_bai}开始批量执行推送任务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    local success_count=0
    local failed_count=0
    local current_task=0
    
    while IFS='|' read -r name local_path remote remote_path port options auth_method password_or_key; do
        ((current_task++))
        
        echo ""
        echo -e "${gl_bai}[${gl_lv}${current_task}${gl_bai}/${gl_huang}${total_tasks}${gl_bai}] 执行任务: ${gl_huang}${name}${gl_bai}"
        echo -e "${gl_bai}同步方向: ${gl_huang}${local_path} ${gl_hong}-> ${gl_lv}${remote}:${remote_path}${gl_bai}"
        
        if [[ ! -d "$local_path" ]]; then
            echo -e "${gl_hong}✗ 失败: 本地目录不存在${gl_bai}"
            ((failed_count++))
            exit_animation
            continue
        fi
        
        if [[ "$auth_method" == "password" ]] && ! command -v sshpass &>/dev/null; then
            echo -e "${gl_hong}✗ 失败: sshpass 未安装${gl_bai}"
            ((failed_count++))
            exit_animation
            continue
        fi
        
        if [[ "$auth_method" == "key" ]] && [[ ! -f "$password_or_key" ]]; then
            echo -e "${gl_hong}✗ 失败: 密钥文件不存在${gl_bai}"
            ((failed_count++))
            exit_animation
            continue
        fi
        
        local ssh_options="-p $port -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
        
        local output_file
        output_file=$(mktemp)
        local sync_result=0
        
        if [[ "$auth_method" == "password" ]]; then
            sshpass -p "$password_or_key" rsync $options -e "ssh $ssh_options" "$local_path" "$remote:$remote_path" >"$output_file" 2>&1
            sync_result=$?
        else

            if [[ "$(stat -c %a "$password_or_key")" != "600" ]]; then
                chmod 600 "$password_or_key" 2>/dev/null
            fi
            
            rsync $options -e "ssh -i $password_or_key $ssh_options" "$local_path" "$remote:$remote_path" >"$output_file" 2>&1
            sync_result=$?
        fi

        if [[ $sync_result -eq 0 ]]; then
            echo -e "${gl_lv}✓ 推送成功${gl_bai}"
            ((success_count++))
        else
            echo -e "${gl_hong}✗ 推送失败 (错误代码: $sync_result)${gl_bai}"
            echo -e "${gl_bai}错误信息:"
            tail -5 "$output_file" 2>/dev/null || echo "无法获取错误信息"
            ((failed_count++))
        fi
        
        rm -f "$output_file"
        
    done <"$CONFIG_FILE"
    
    echo ""
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}批量执行完成:${gl_bai}"
    echo -e "  ${gl_lv}✓ 成功: ${success_count}${gl_bai}"
    echo -e "  ${gl_hong}✗ 失败: ${failed_count}${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    if [[ $failed_count -eq 0 ]]; then
        echo -e "${gl_lv}✓ 所有任务执行成功!${gl_bai}"
    elif [[ $success_count -eq 0 ]]; then
        echo -e "${gl_hong}✗ 所有任务执行失败!${gl_bai}"
    else
        echo -e "${gl_huang}⚠ 部分任务执行失败，请检查错误信息${gl_bai}"
    fi
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
    
    if [[ $failed_count -gt 0 ]]; then
        return 1
    fi
    return 0
}

remote_rsync_manager() {
    CONFIG_FILE="$HOME/.remote_rsync_tasks"
    CRON_FILE="$HOME/.remote_rsync_cron"
    install sshpass rsync
    while true; do
        clear
        list_tasks
        echo
        view_tasks
        echo -e ""
        echo -e "${gl_zi}>>> Rsync远程同步工具${gl_bai}"
        echo "远程目录之间同步，支持增量同步，高效稳定。"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}创建新任务            ${gl_bufan}2.  ${gl_bai}查看任务详情"
        echo -e "${gl_bufan}3.  ${gl_bai}执行本地同步到远端    ${gl_bufan}4.  ${gl_bai}执行远端同步到本地"
        echo -e "${gl_bufan}5.  ${gl_bai}批量推送所有任务      ${gl_bufan}6.  ${gl_bai}删除同步任务"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}7.  ${gl_bai}创建定时任务          ${gl_bufan}8.  ${gl_bai}删除定时任务"
        echo -e "${gl_bufan}9.  ${gl_bai}编辑cron文件          ${gl_bufan}10. ${gl_bai}查看cron文件"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单        ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "请输入你的选择: " choice
        case $choice in
        1)  remote_add_task ;;
        2)  remote_show_task_details ;;
        3)  remote_run_task push ;;
        4)  remote_run_task pull ;;
        5)  remote_run_all_tasks_push ;;
        6)  remote_delete_task ;;
        7)  remote_schedule_task ;;
        8)  remote_delete_task_schedule ;;
        9)  edit_crontab; continue ;;
        10) view_raw_crontab ;;
        0) cancel_return "已是主菜单" || continue ;;
        00 | 000 | 0000) exit_script ;;
        *) handle_invalid_input ;;
        esac
    done
}

remote_rsync_manager