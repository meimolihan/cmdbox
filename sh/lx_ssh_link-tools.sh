#!/bin/bash
set -uo pipefail

# ====================== 共有函数库（自包含，勿改函数名） ======================
# ==== BOILERPLATE:START ====
# 本段为 cmdbox 统一函数库，保证脚本自包含、拉取即用；手工复制时整段照搬。
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

sleep_fractional() {
    local seconds=$1
    if sleep "$seconds" 2>/dev/null; then return 0; fi
    if command -v perl >/dev/null 2>&1; then perl -e "select(undef, undef, undef, $seconds)"; return 0; fi
    if command -v python3 >/dev/null 2>&1; then python3 -c "import time; time.sleep($seconds)"; return 0; fi
    if command -v python >/dev/null 2>&1; then python -c "import time; time.sleep($seconds)"; return 0; fi
    local int_seconds=$(echo "$seconds" | awk '{print int($1+0.999)}')
    sleep "$int_seconds"
}

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n 1 -s -r -p ""
    echo ""
    clear
}

cancel_return() {
    local menu_name="${1:-上一级选单}"
    echo -ne "${gl_lv}即将返回到 ${gl_huang}${menu_name}${gl_lv} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    sleep_fractional 0.6
    echo ""
    clear
}

exit_animation() {
    echo -ne "${gl_lv}即将退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo ""
    clear
}

exit_script() {
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local dots=(
        "${gl_hong}."
        "${gl_huang}."
        "${gl_lv}."
        "${gl_bufan}."
        "${gl_zi}."
    )
    local dot_buffer=""
    local frame_len=${#frames[@]}
    local dot_idx=0
    local total_dots=${#dots[@]}

    for ((i=0; i<20; i++)); do
        if (( i > 0 && i % 3 == 0 && dot_idx < total_dots )); then
            dot_buffer+=${dots[$dot_idx]}
            ((dot_idx++))
        fi
        echo -ne "\r\033[K${gl_bufan}${frames[i % frame_len]}${gl_bai} 正在退出 ${dot_buffer}"
        sleep_fractional 0.06
    done
    echo -e "\r\033[K${gl_lv}✓${gl_bai} 成功退出\n"
    clear
    exit 0
}

handle_invalid_input() {
    echo -ne "\r\033[K${gl_huang}无效的输入,请重新输入! ${gl_zi} 1 ${gl_huang} 秒后返回"
    sleep_fractional 1
    echo -ne "\r\033[K${gl_lv}无效的输入,请重新输入! ${gl_zi}0${gl_lv} 秒后返回"
    sleep_fractional 0.5
    echo -ne "\r\033[K"
    continue
}
# ==== BOILERPLATE:END ====
# ============================================================================

# 显示连接列表
list_connections() {
    echo -e "${gl_huang}已保存的连接:${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    awk -F'|' '{print NR " - " $1 " (" $2 ")"}' "$CONFIG_FILE"
}

# 添加新连接
add_connection() {
    echo -e ""
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "创建新连接示例："
    echo -e "  ${gl_bai}- 连接名称: ${gl_huang}my_server${gl_bai}"
    echo -e "  ${gl_bai}- IP地址: ${gl_huang}192.168.1.100${gl_bai}"
    echo -e "  ${gl_bai}- 用户名: ${gl_huang}root${gl_bai}"
    echo -e "  ${gl_bai}- 端口: ${gl_huang}22${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}请输入连接名称(${gl_huang}0${gl_bai}返回): ")" name
    [ "$name" = "0" ] && { cancel_return "SSH 远程连接工具"; return; }

    read -r -e -p "$(echo -e "${gl_bai}请输入IP地址(${gl_huang}0${gl_bai}返回): ")" ip
    [ "$ip" = "0" ] && { cancel_return "SSH 远程连接工具"; return; }

    read -r -e -p "$(echo -e "${gl_bai}请输入用户名 (默认: ${gl_huang}root${gl_bai})(${gl_huang}0${gl_bai}返回): ")" user
    [ "$user" = "0" ] && { cancel_return "SSH 远程连接工具"; return; }

    local user=${user:-root}
    read -r -e -p "$(echo -e "${gl_bai}请输入端口号 (默认: ${gl_huang}22${gl_bai})(${gl_huang}0${gl_bai}返回): ")" port
    [ "$port" = "0" ] && { cancel_return "SSH 远程连接工具"; return; }

    local port=${port:-22}

    echo "请选择身份验证方式:"
    echo -e "${gl_bufan}1. ${gl_bai}密码"
    echo -e "${gl_bufan}2. ${gl_bai}密钥"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}请输入你的选择(${gl_lv}1${gl_bai}/${gl_hong}2${gl_bai})(${gl_huang}0${gl_bai}返回): ")" auth_choice
    [ "$auth_choice" = "0" ] && { cancel_return "SSH 远程连接工具"; return; }

    case $auth_choice in
    1)
        read -r -s -p "请输入密码: " password_or_key
        echo
        ;;
    2)
        echo "请粘贴密钥内容 (粘贴完成后按两次回车)："
        local password_or_key=""
        while IFS= read -r -r line; do
            if [[ -z "$line" && "$password_or_key" == *"-----BEGIN"* ]]; then
                break
            fi
            if [[ -n "$line" || "$password_or_key" == *"-----BEGIN"* ]]; then
                local password_or_key+="${line}"$'\n'
            fi
        done

        if [[ "$password_or_key" == *"-----BEGIN"* && "$password_or_key" == *"PRIVATE KEY-----"* ]]; then
            local key_file="$KEY_DIR/$name.key"
            echo -n "$password_or_key" >"$key_file"
            chmod 600 "$key_file"
            local password_or_key="$key_file"
        fi
        ;;
    *) handle_invalid_input ;;
    esac
    echo "$name|$ip|$user|$port|$password_or_key" >>"$CONFIG_FILE"
    echo "连接已保存!"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

delete_connection() {
    read -r -e -p "$(echo -e "${gl_bai}请输入要删除的连接编号(${gl_huang}0${gl_bai}返回): ")" num
    [ "$num" = "0" ] && { cancel_return "SSH 远程连接工具"; return; }

    local connection
    connection=$(sed -n "${num}p" "$CONFIG_FILE")
    if [[ -z "$connection" ]]; then
        echo "错误：未找到对应的连接。"
        exit_animation
        return
    fi

    IFS='|' read -r -r name ip user port password_or_key <<<"$connection"

    if [[ "$password_or_key" == "$KEY_DIR"* ]]; then
        rm -f "$password_or_key"
    fi

    sed -i "${num}d" "$CONFIG_FILE"
    echo "连接已删除!"
}

use_connection() {
    read -r -e -p "$(echo -e "${gl_bai}请输入要使用的连接编号(${gl_huang}0${gl_bai}返回): ")" num
    [ "$num" = "0" ] && { cancel_return "SSH 远程连接工具"; return; }

    local connection
    connection=$(sed -n "${num}p" "$CONFIG_FILE")
    if [[ -z "$connection" ]]; then
        echo "错误：未找到对应的连接。"
        exit_animation
        return
    fi

    IFS='|' read -r -r name ip user port password_or_key <<<"$connection"

    echo -e "正在连接到 $name ($ip) ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    if [[ -f "$password_or_key" ]]; then
        if ! ssh -o StrictHostKeyChecking=no -i "$password_or_key" -p "$port" "$user@$ip"; then
            echo "连接失败！请检查以下内容："
            echo -e "${gl_bufan}1. ${gl_bai}密钥文件路径是否正确：$password_or_key"
            echo -e "${gl_bufan}2. ${gl_bai}密钥文件权限是否正确（应为 600）。"
            echo -e "${gl_bufan}3. ${gl_bai}目标服务器是否允许使用密钥登录。"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
        fi
    else
        if ! command -v sshpass &>/dev/null; then
            echo "错误：未安装 sshpass，请先安装 sshpass。"
            echo "安装方法："
            echo "  - Ubuntu/Debian: apt install sshpass"
            echo "  - CentOS/RHEL: yum install sshpass"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            return
        fi
        if ! sshpass -p "$password_or_key" ssh -o StrictHostKeyChecking=no -p "$port" "$user@$ip"; then
            echo -e "${gl_bufan}连接失败！请检查以下内容：${gl_bai}"
            echo -e "${gl_bufan}1. ${gl_bai}用户名和密码是否正确。"
            echo -e "${gl_bufan}2. ${gl_bai}目标服务器是否允许密码登录。"
            echo -e "${gl_bufan}3. ${gl_bai}目标服务器的 SSH 服务是否正常运行。"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            return
        fi
    fi
}

linux_ssh_manager() {
    CONFIG_FILE="$HOME/.ssh_connections"
    KEY_DIR="$HOME/.ssh/ssh_manager_keys"

    if [[ ! -f "$CONFIG_FILE" ]]; then
        touch "$CONFIG_FILE"
    fi

    if [[ ! -d "$KEY_DIR" ]]; then
        mkdir -p "$KEY_DIR"
        chmod 700 "$KEY_DIR"
    fi

    while true; do
        clear
        echo -e "${gl_zi}>>> SSH 远程连接工具"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo "可以通过SSH连接到其他Linux系统上"
        list_connections
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}创建新连接"
        echo -e "${gl_bufan}2.  ${gl_bai}使用连接"
        echo -e "${gl_bufan}3.  ${gl_bai}删除连接"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单"
        echo -e "${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "请输入你的选择: " choice
        case $choice in
        1) add_connection ;;
        2) use_connection ;;
        3) delete_connection ;;
        0) cancel_return "系统工具"; break ;;
        00 | 000 | 0000) exit_script ;;
        *) handle_invalid_input ;;
        esac
    done
}

linux_ssh_manager "$@"
