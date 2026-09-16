#!/bin/bash
set -uo pipefail

# ================== terminal colors ==================
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
SERVICE="fan-md"

INSTALL_SCRIPT_URL="gitee.com/meimolihan/cmdbox/raw/master/sh/dc_inst_fan-md.sh"
BACKUP_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-md/main/scripts/fan-md_backup.sh"
RECOVER_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-md/main/scripts/fan-md_recover.sh"

log_info() { echo -e "${gl_lan}[信息]${gl_bai} $*"; }
log_ok() { echo -e "${gl_lv}[成功]${gl_bai} $*"; }
log_warn() { echo -e "${gl_huang}[警告]${gl_bai} $*"; }
log_error() { echo -e "${gl_hong}[错误]${gl_bai} $*" >&2; }

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
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

cancel_return() {
    local menu_name="${1:-退出脚本}"
    echo -ne "${gl_lv}即将返回 ${gl_huang}${menu_name} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
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

exit_animation() {
    echo -ne "\r${gl_lv}即将退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
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
    return 2
}

show_service_url() {
    local service="${1:-fan-md}"
    local url=""
    local port=""
    local ip
    ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    [ -z "$ip" ] && ip=$(ip route get 1 2>/dev/null | awk '{print $7}' | head -1)
    [ -z "$ip" ] && ip=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -1)
    [ -z "$ip" ] && ip="127.0.0.1"

    if command -v docker >/dev/null 2>&1 \
        && docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "${service}"; then
        port=$(docker port "${service}" 9900/tcp 2>/dev/null | head -1 | grep -oE ':[0-9]+$' | sed 's/^://')
    fi

    if [ -z "$port" ] && [ -f /vol1/1000/compose/fan-md/docker-compose.yml ]; then
        port=$(grep -oE '[0-9]+:9900' /vol1/1000/compose/fan-md/docker-compose.yml | head -1 | cut -d: -f1)
    fi

    if [ -n "$port" ]; then
        url="http://${ip}:${port}"
    fi

    if [ -n "$url" ]; then
        echo -e "访问地址：${gl_lv}${url}${gl_bai}"
    else
        echo -e "访问地址：${gl_hong}无法获取访问地址${gl_bai}"
        return 1
    fi
}
show_service_status() {
    local service="${1:-fan-md}"

    if ! command -v docker >/dev/null 2>&1; then
        echo -e "运行状态：${gl_hong}docker 未安装${gl_bai}"
        echo -e "版本信息：${gl_huang}无法获取${gl_bai}"
        return
    fi

    if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qx "${service}"; then
        local state=$(docker inspect -f '{{.State.Status}}' "${service}" 2>/dev/null)
        if [ "$state" = "running" ]; then
            echo -e "运行状态：${gl_lv}${service} 正在运行${gl_bai}"
        else
            echo -e "运行状态：${gl_hong}${service} 未运行（${state}）${gl_bai}"
        fi
        local image=$(docker inspect -f '{{.Config.Image}}' "${service}" 2>/dev/null)
        echo -e "镜像版本：${gl_huang}${image}${gl_bai}"
    else
        echo -e "运行状态：${gl_hong}${service} 未运行${gl_bai}"
        echo -e "版本信息：${gl_huang}容器不存在${gl_bai}"
    fi
}

manage_fan_md() {
    while true; do
        clear
        echo -e ""
        echo -e "${gl_zi}>>> fan-md 管理工具${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        show_service_status fan-md
        show_service_url fan-md
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}停止 fan-md       ${gl_bufan}2.  ${gl_bai}启动 fan-md"
        echo -e "${gl_bufan}3.  ${gl_bai}重启 fan-md       ${gl_bufan}4.  ${gl_bai}查看容器状态"
        echo -e "${gl_bufan}5.  ${gl_bai}查看端口映射     ${gl_bufan}6.  ${gl_bai}设置开机自启"
        echo -e "${gl_bufan}7.  ${gl_bai}取消开机自启     ${gl_bufan}8.  ${gl_bai}查看日志(100行)"
        echo -e "${gl_bufan}9.  ${gl_bai}实时跟踪日志"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_lv}66. ${gl_bai}部署/升级 fan-md   ${gl_huang}77. ${gl_bai}备份数据"
        echo -e "${gl_lv}88. ${gl_bai}恢复数据             ${gl_hong}99. ${gl_bai}卸载 fan-md"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单       ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" action


        case "$action" in
        1)
            echo -e ""
            echo -e "${gl_zi}>>> 正在停止 fan-md 容器 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker stop ${SERVICE}
            log_ok "fan-md 容器已停止"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        2)
            echo -e ""
            echo -e "${gl_zi}>>> 正在启动 fan-md 容器 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker start ${SERVICE}
            log_ok "fan-md 容器已启动"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        3)
            echo -e ""
            echo -e "${gl_zi}>>> 正在重启 fan-md 容器 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker restart ${SERVICE}
            log_ok "fan-md 容器已重启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        4)
            echo -e ""
            echo -e "${gl_zi}>>> fan-md 容器状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker ps -a --filter "name=^/${SERVICE}$"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        5)
            echo -e ""
            echo -e "${gl_zi}>>> fan-md 端口映射 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker port ${SERVICE}
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        6)
            echo -e ""
            echo -e "${gl_zi}>>> 设置 fan-md 开机自启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker update --restart always ${SERVICE}
            log_ok "已设置 fan-md 开机自启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        7)
            echo -e ""
            echo -e "${gl_zi}>>> 取消 fan-md 开机自启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker update --restart no ${SERVICE}
            log_ok "已取消 fan-md 开机自启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        8)
            echo -e ""
            echo -e "${gl_zi}>>> fan-md 日志（最近100行）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker logs -n 100 ${SERVICE}
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        9)
            echo -e ""
            echo -e "${gl_zi}>>> 实时跟踪 fan-md 日志（按 Ctrl+C 退出）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker logs -f ${SERVICE}
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        66)
            bash <(curl -sL ${INSTALL_SCRIPT_URL})
            break_end
            continue
            ;;
        77)
            bash <(curl -sL ${BACKUP_SCRIPT_URL})
            break_end
            continue
            ;;
        88)
            bash <(curl -sL ${RECOVER_SCRIPT_URL})
            break_end
            continue
            ;;
        99)
            docker rm -f ${SERVICE} && docker rmi -f mobufan/fan-md:latest
            break_end
            continue
            ;;
        0)
            cancel_return "已是主菜单"
            continue
            ;;
        00 | 000 | 0000)
            exit_script
            ;;
        *)
            handle_invalid_input
            ;;
        esac
    done
}

manage_fan_md