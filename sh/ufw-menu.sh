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

sleep_fractional() {
    local seconds=$1
    if sleep "$seconds" 2>/dev/null; then return 0; fi
    if command -v perl >/dev/null 2>&1; then perl -e "select(undef, undef, undef, $seconds)"; return 0; fi
    if command -v python3 >/dev/null 2>&1; then python3 -c "import time; time.sleep($seconds)"; return 0; fi
    local int_seconds
    int_seconds=$(echo "$seconds" | awk '{print int($1+0.999)}')
    sleep "$int_seconds"
}

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n 1 -s -r -p ""
    echo ""
    clear
}

exit_script() {
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    for ((i=0; i<20; i++)); do
        echo -ne "\r\033[K${gl_bufan}${frames[i % ${#frames[@]}]}${gl_bai} 正在退出 ..."
        sleep_fractional 0.06
    done
    echo -e "\r\033[K${gl_lv}✓${gl_bai} 成功退出\n"
    clear
    exit 0
}

root_use() {
    if [ "$EUID" -ne 0 ]; then
        log_error "该脚本需要 root 用户运行，请使用 sudo 或切换到 root 后重试"
        exit 1
    fi
}

ensure_ufw() {
    if command -v ufw &>/dev/null; then
        return 0
    fi

    log_warn "未检测到 ufw，尝试自动安装"
    if command -v apt-get &>/dev/null; then
        if apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ufw; then
            log_ok "ufw 安装完成"
            return 0
        fi
    elif command -v apt &>/dev/null; then
        if apt update -qq && DEBIAN_FRONTEND=noninteractive apt install -y -qq ufw; then
            log_ok "ufw 安装完成"
            return 0
        fi
    else
        log_error "当前系统包管理器不受支持，请手动安装 ufw 后重试"
        return 1
    fi

    log_error "ufw 安装失败，请手动执行 apt install -y ufw 后重试"
    return 1
}

ufw_run() {
    if ! command -v ufw &>/dev/null; then
        log_error "ufw 不可用，请检查安装状态"
        return 1
    fi
    ufw "$@"
}

confirm_y_n() {
    local prompt="$1"
    local answer
    read -r -e -p "$prompt" answer
    case "${answer:-N}" in
        [yY] | [yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

show_menu() {
    clear
    echo -e "${gl_zi}>>> UFW 防火墙管理菜单${reset}"
    echo -e "${gl_bufan}─────────────────────────────────────────────────────${reset}"
    echo -e "${gl_hui}当前状态：$(ufw status 2>/dev/null | head -1)${reset}"
    echo -e "${gl_bufan}─────────────────────────────────────────────────────${reset}"
    echo -e "${gl_bufan}1. ${gl_bai}查看当前规则"
    echo -e "${gl_bufan}2. ${gl_bai}开放端口"
    echo -e "${gl_bufan}3. ${gl_bai}删除规则"
    echo -e "${gl_bufan}4. ${gl_bai}启用防火墙"
    echo -e "${gl_bufan}5. ${gl_bai}禁用防火墙"
    echo -e "${gl_bufan}6. ${gl_bai}重置防火墙"
    echo -e "${gl_bufan}0. ${gl_bai}退出脚本"
    echo -e "${gl_bufan}─────────────────────────────────────────────────────${reset}"
}

view_rules() {
    echo -e "${gl_zi}>>> 当前 UFW 规则${gl_bai}"
    echo -e "${gl_bufan}─────────────────────────────────────────────────────${gl_bai}"
    ufw_run status numbered || log_warn "无法读取规则，防火墙可能尚未启用"
    echo -e "${gl_bufan}─────────────────────────────────────────────────────${gl_bai}"
    break_end
}

allow_port() {
    local port proto
    read -r -e -p "${gl_bai}请输入端口号 (0 返回): ${gl_bai}" port
    [ "$port" = "0" ] && return 0

    if [[ ! "$port" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
        log_error "端口号必须为 1-65535 之间的数字"
        break_end
        return 1
    fi

    read -r -e -p "${gl_bai}请输入协议 (tcp/udp, 回车默认 tcp): ${gl_bai}" proto
    proto=${proto:-tcp}
    proto=$(echo "$proto" | tr '[:upper:]' '[:lower:]')
    if [[ "$proto" != "tcp" && "$proto" != "udp" ]]; then
        log_error "协议只能是 tcp 或 udp"
        break_end
        return 1
    fi

    if ufw_run allow "${port}/${proto}"; then
        log_ok "已开放端口 ${port}/${proto}"
    else
        log_error "开放端口失败，请检查 ufw 状态"
    fi
    break_end
}

delete_rule() {
    local num
    ufw_run status numbered || true
    echo -e "${gl_bufan}─────────────────────────────────────────────────────${gl_bai}"
    read -r -e -p "${gl_bai}请输入规则编号 (0 返回): ${gl_bai}" num
    [ "$num" = "0" ] && return 0

    if [[ ! "$num" =~ ^[0-9]+$ ]] || (( num < 1 )); then
        log_error "规则编号必须为正整数"
        break_end
        return 1
    fi

    if ufw_run --force delete "$num"; then
        log_ok "已删除规则 $num"
    else
        log_error "删除规则失败，请确认编号是否存在"
    fi
    break_end
}

enable_ufw() {
    if ufw_run --force enable; then
        log_ok "防火墙已启用"
        ufw_run status numbered || true
    else
        log_error "启用防火墙失败"
    fi
    break_end
}

disable_ufw() {
    log_warn "禁用防火墙后主机将失去 UFW 保护"
    if confirm_y_n "${gl_bai}确认禁用防火墙？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): "; then
        if ufw_run disable; then
            log_ok "防火墙已禁用"
        else
            log_error "禁用防火墙失败"
        fi
    else
        log_info "已取消禁用操作"
    fi
    break_end
}

reset_ufw() {
    log_warn "重置会清空所有 UFW 规则并关闭防火墙"
    if confirm_y_n "${gl_bai}确认重置防火墙？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): "; then
        if ufw_run --force reset; then
            log_ok "防火墙规则已重置"
        else
            log_error "重置防火墙失败"
        fi
    else
        log_info "已取消重置操作"
    fi
    break_end
}

main() {
    root_use
    if ! ensure_ufw; then
        break_end
        exit 1
    fi

    while true; do
        show_menu
        read -r -e -p "${gl_bai}请输入你的选择: ${gl_bai}" choice
        case "$choice" in
            1) view_rules ;;
            2) allow_port ;;
            3) delete_rule ;;
            4) enable_ufw ;;
            5) disable_ufw ;;
            6) reset_ufw ;;
            0) exit_script ;;
            *) log_warn "无效选择，请输入 0-6"; sleep_fractional 1 ;;
        esac
    done
}

main "$@"
