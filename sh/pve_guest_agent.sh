#!/bin/bash

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

exit_script() {
    echo ""
    echo -ne "${gl_hong}感谢使用，再见！${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    clear
    exit 0
}

handle_invalid_input() {
    echo -ne "\r\033[K${gl_huang}无效的输入,请重新输入! ${gl_zi} 1 ${gl_huang} 秒后返回"
    sleep_fractional 1
    echo -ne "\r\033[K${gl_lv}无效的输入,请重新输入! ${gl_zi}0${gl_lv} 秒后返回"
    sleep_fractional 0.5
    echo -ne "\r\033[K"
    return 2
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        log_error "无法检测操作系统"
        return 1
    fi
}

install_qga() {
    echo -e ""
    echo -e "${gl_zi}>>> 安装 QEMU Guest Agent${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_info "开始安装 QEMU Guest Agent ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    case $OS in
        debian|ubuntu)
            apt update
            apt install -y qemu-guest-agent
            ;;
        centos|rhel|almalinux|rocky)
            if command -v dnf >/dev/null 2>&1; then
                dnf install -y qemu-guest-agent
            else
                yum install -y qemu-guest-agent
            fi
            ;;
        opensuse*)
            zypper install -y qemu-guest-agent
            ;;
        *)
            log_error "不支持的操作系统: $OS"
            return 1
            ;;
    esac
    log_ok "QEMU Guest Agent 安装完成"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

start_qga() {
    echo -e ""
    echo -e "${gl_zi}>>> 启动 QEMU Guest Agent 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    if command -v systemctl >/dev/null 2>&1; then
        systemctl start qemu-guest-agent
        systemctl enable qemu-guest-agent
        log_ok "服务已启动并设置开机自启"
    else
        if [ -f /etc/init.d/qemu-guest-agent ]; then
            service qemu-guest-agent start
            chkconfig qemu-guest-agent on
            log_ok "服务已启动并设置开机自启"
        else
            log_error "未找到 qemu-guest-agent 服务脚本"
            return 1
        fi
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

stop_qga() {
    echo -e ""
    echo -e "${gl_zi}>>> 停止 QEMU Guest Agent 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    if command -v systemctl >/dev/null 2>&1; then
        systemctl stop qemu-guest-agent
        systemctl disable qemu-guest-agent
        log_ok "服务已停止并禁用开机自启"
    else
        if [ -f /etc/init.d/qemu-guest-agent ]; then
            service qemu-guest-agent stop
            chkconfig qemu-guest-agent off
            log_ok "服务已停止并禁用开机自启"
        else
            log_error "未找到 qemu-guest-agent 服务脚本"
            return 1
        fi
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

restart_qga() {
    echo -e ""
    echo -e "${gl_zi}>>> 重启 QEMU Guest Agent 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    if command -v systemctl >/dev/null 2>&1; then
        systemctl restart qemu-guest-agent
        log_ok "服务已重启"
    else
        if [ -f /etc/init.d/qemu-guest-agent ]; then
            service qemu-guest-agent restart
            log_ok "服务已重启"
        else
            log_error "未找到 qemu-guest-agent 服务脚本"
            return 1
        fi
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

status_qga() {
    echo -e ""
    echo -e "${gl_zi}>>> 查看 QEMU Guest Agent 服务状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    if command -v systemctl >/dev/null 2>&1; then
        systemctl status qemu-guest-agent --no-pager
    else
        if [ -f /etc/init.d/qemu-guest-agent ]; then
            service qemu-guest-agent status
        else
            log_error "未找到 qemu-guest-agent 服务"
            return 1
        fi
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

test_qga() {
    echo -e ""
    echo -e "${gl_zi}>>> 测试 QEMU Guest Agent 通信 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    if [ -S /dev/virtio-ports/org.qemu.guest_agent.0 ]; then
        log_ok "virtio-serial 设备存在"
    else
        log_warn "virtio-serial 设备不存在，请确保虚拟机已启用 QEMU Guest Agent"
    fi
    
    if pgrep -x "qemu-ga" > /dev/null; then
        log_ok "qemu-ga 进程正在运行"
        QGA_VERSION=$(qemu-ga --version 2>/dev/null | head -1)
        log_info "版本信息: $QGA_VERSION"
    else
        log_error "qemu-ga 进程未运行"
    fi
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

remove_qga() {
    echo -e ""
    echo -e "${gl_zi}>>> 卸载  QEMU Guest Agent${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_hong}确定要卸载  QEMU Guest Agent 吗？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
    case $confirm in
        [Yy])
            log_info "开始卸载 QEMU Guest Agent ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            case $OS in
                debian|ubuntu)
                    apt remove -y qemu-guest-agent
                    apt autoremove -y
                    ;;
                centos|rhel|almalinux|rocky)
                    if command -v dnf >/dev/null 2>&1; then
                        dnf remove -y qemu-guest-agent
                    else
                        yum remove -y qemu-guest-agent
                    fi
                    ;;
                opensuse*)
                    zypper remove -y qemu-guest-agent
                    ;;
                *)
                    log_error "不支持的操作系统: $OS"
                    return 1
                    ;;
            esac
            log_ok "QEMU Guest Agent 已卸载"
            ;;
        [Nn])
            log_info "已取消卸载"
            ;;
        *)
            handle_invalid_input
            ;;
    esac
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

main_menu() {
    while true; do
        clear
        
        if ! command -v qm &> /dev/null; then
            echo -e ""
            echo -e "${gl_zi}>>> PVE Guest Agent 管理脚本${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            log_error "未检测到Proxmox VE环境，请确保脚本在PVE节点上运行"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            return 1
        fi
        
        echo -e "${gl_zi}>>> PVE Guest Agent 管理脚本${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}安装 QEMU Guest Agent"
        echo -e "${gl_bufan}2.  ${gl_bai}启动服务"
        echo -e "${gl_bufan}3.  ${gl_bai}停止服务"
        echo -e "${gl_bufan}4.  ${gl_bai}重启服务"
        echo -e "${gl_bufan}5.  ${gl_bai}查看服务状态"
        echo -e "${gl_bufan}6.  ${gl_bai}测试代理通信"
        echo -e "${gl_bufan}7.  ${gl_bai}卸载 QEMU Guest Agent"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_hong}0.  ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "请输入你的选择: " choice
        
        case $choice in
            1)
                detect_os
                install_qga
                ;;
            2)
                start_qga
                ;;
            3)
                stop_qga
                ;;
            4)
                restart_qga
                ;;
            5)
                status_qga
                ;;
            6)
                test_qga
                ;;
            7)
                detect_os
                remove_qga
                ;;
            0)
                exit_script
                ;;
            *)
                handle_invalid_input
                ;;
        esac
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main_menu
fi
