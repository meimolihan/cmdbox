#!/bin/bash
SH_VERSION="1.0.3"

gl_hui='\e[37m'
gl_hong='\033[31m'
gl_lv='\033[32m'
gl_huang='\033[33m'
gl_lan='\033[34m'
gl_bai='\033[0m'
gl_zi='\033[35m'
gl_bufan='\033[96m'

log_info()  { echo -e "${gl_lan}[信息]${gl_bai} $*"; }
log_ok()    { echo -e "${gl_lv}[成功]${gl_bai} $*"; }
log_warn()  { echo -e "${gl_huang}[警告]${gl_bai} $*"; }
log_error() { echo -e "${gl_hong}[错误]${gl_bai} $*" >&2; }

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    read -r -n 1 -s -r -p ""
    echo ""
    clear
}

exit_script() {
    clear
    exit 0
}

handle_invalid_input() {
    echo -ne "\r${gl_huang}无效的输入,请重新输入! ${gl_zi}1${gl_huang}秒后返回"
    sleep 1
    echo -e "\r${gl_lv}无效的输入,请重新输入! ${gl_zi}0${gl_lv}秒后返回"
    sleep 0.5
    return 2
}

get_remote_version() {
    local remote_version
    
    # 使用多个源，提高成功率
    remote_version=$(curl -s --connect-timeout 5 \
        https://gitee.com/meimolihan/cmdbox/raw/master/sh/linux-check.sh \
        | grep -o 'SH_VERSION="[0-9.]*"' 2>/dev/null | head -1 | cut -d'"' -f2)
    
    if [ -z "$remote_version" ]; then
        remote_version=$(curl -s --connect-timeout 5 \
            https://cmdbox.meimolihan.eu.org/sh/linux-check.sh \
            | grep -o 'SH_VERSION="[0-9.]*"' 2>/dev/null | head -1 | cut -d'"' -f2)
    fi
    
    echo "$remote_version"
}

check_for_update() {
    local remote_version
    remote_version=$(get_remote_version)
    
    if [ -z "$remote_version" ]; then
        return 1
    fi
    
    if [ "$SH_VERSION" != "$remote_version" ]; then
        echo -e "\n${gl_hong}🎉 发现新版本！${gl_bai}"
        echo -e "${gl_bufan}————————————————————————${gl_bai}"
        echo -e "  当前版本: ${gl_huang}v$SH_VERSION${gl_bai}"
        echo -e "  最新版本: ${gl_lv}v$remote_version${gl_bai}"
        echo -e "${gl_bufan}————————————————————————${gl_bai}"
        echo -e "  ${gl_bai}输入命令: ${gl_huang}g up${gl_bai} 更新到最新版"
        echo -e "${gl_bufan}————————————————————————${gl_bai}\n"
        return 0
    fi
    
    return 1
}

get_local_ip() {
    local ip
    ip=$(hostname -I 2>/dev/null | awk '{print $1}' | head -n1)
    
    if [ -z "$ip" ]; then
        ip=$(ip -o -4 addr show scope global 2>/dev/null | awk '{print $4}' | cut -d'/' -f1 | head -n1)
    fi
    
    [ -n "$ip" ] && echo "$ip" || echo "无法获取IP"
}

get_cpu_usage() {
    local cpu_usage
    cpu_usage=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{printf "%.2f%%", 100 - $8}')
    
    if [ -z "$cpu_usage" ]; then
        cpu_usage=$(mpstat 1 1 2>/dev/null | tail -1 | awk '{printf "%.2f%%", 100 - $NF}')
    fi
    
    [ -n "$cpu_usage" ] && echo "$cpu_usage" || echo "无法获取"
}

get_uptime() {
    local uptime_seconds hours minutes
    uptime_seconds=$(awk '{print int($1)}' /proc/uptime 2>/dev/null)
    
    if [ -n "$uptime_seconds" ]; then
        hours=$((uptime_seconds / 3600))
        minutes=$(((uptime_seconds % 3600) / 60))
        echo "${hours}时${minutes}分"
    else
        uptime_seconds=$(uptime -p 2>/dev/null | sed 's/up //')
        [ -n "$uptime_seconds" ] && echo "$uptime_seconds" || echo "无法获取"
    fi
}

get_default_gateway() {
    local gateway
    gateway=$(ip route show default 2>/dev/null | awk '/default/ {print $3}' | head -n1)
    
    if [ -z "$gateway" ]; then
        gateway=$(route -n 2>/dev/null | awk '$1 == "0.0.0.0" {print $2}' | head -n1)
    fi
    
    [ -n "$gateway" ] && echo "$gateway" || echo "无法获取"
}

get_disk_usage() {
    local disk_info
    disk_info=$(df -h / 2>/dev/null | awk 'NR==2 {printf "%s/%s (%s)", $3, $2, $5}')
    
    if [ -z "$disk_info" ]; then
        disk_info=$(df -h . 2>/dev/null | awk 'NR==2 {printf "%s/%s (%s)", $3, $2, $5}')
    fi
    
    [ -n "$disk_info" ] && echo "$disk_info" || echo "无法获取"
}

show_system_info() {
    clear
    echo -e "${gl_zi}>>> 系统信息${gl_bai}"
    # echo -e "${gl_lv}💡 输入 ${gl_huang}g up${gl_lv} 可更新脚本${gl_bai}"
    echo -e "${gl_bufan}————————————————————————${gl_bai}"
    echo -e "${gl_bufan}主机名称 : ${gl_bai}$(hostname 2>/dev/null || echo "未知")"
    echo -e "${gl_bufan}内核版本 : ${gl_bai}$(uname -r 2>/dev/null || echo "未知")"
    echo -e "${gl_bufan}————————————————————————${gl_bai}"
    echo -e "${gl_bufan}CPU 架构 : ${gl_bai}$(uname -m 2>/dev/null || echo "未知")"
    echo -e "${gl_bufan}CPU 占用 : ${gl_bai}$(get_cpu_usage)"
    echo -e "${gl_bufan}————————————————————————${gl_bai}"
    echo -e "${gl_bufan}IPV4内网 : ${gl_bai}$(get_local_ip)"
    echo -e "${gl_bufan}默认网关 : ${gl_bai}$(get_default_gateway)"
    echo -e "${gl_bufan}————————————————————————${gl_bai}"
    echo -e "${gl_bufan}磁盘占用 : ${gl_bai}$(get_disk_usage)"
    echo -e "${gl_bufan}运行时间 : ${gl_bai}$(get_uptime)"
    echo -e "${gl_bufan}————————————————————————${gl_bai}"
    
}

main() {
    case "$1" in
        up|update|upgrade)
            bash <(curl -sL gitee.com/meimolihan/script/raw/master/sh/install/check.sh)
            bash /etc/profile.d/linux-check.sh
            exit
            ;;
        version|v|-v|--version)
            echo -e "${gl_bufan}脚本版本: ${gl_huang}v$SH_VERSION${gl_bai}"
            check_for_update
            return 0
            ;;
        help|h|-h|--help)
            echo -e "${gl_bufan}可用命令:${gl_bai}"
            echo -e "${gl_bufan}————————————————————————${gl_bai}"
            echo -e "  ${gl_huang}g${gl_bai}         显示系统信息"
            echo -e "  ${gl_huang}g up${gl_bai}     更新脚本到最新版"
            echo -e "  ${gl_huang}g version${gl_bai} 显示当前版本"
            echo -e "  ${gl_huang}g help${gl_bai}   显示帮助信息"
            echo -e "${gl_bufan}————————————————————————${gl_bai}"
            return 0
            ;;
    esac
    
    show_system_info
    
    if [[ $- == *i* ]]; then
        if [ -z "$LINUX_CHECK_SHOWN" ]; then
            export LINUX_CHECK_SHOWN=1
        fi
    else
        check_for_update
    fi
}

main "$@"