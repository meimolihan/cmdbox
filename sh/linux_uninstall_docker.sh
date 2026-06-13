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

handle_invalid_input() {
    echo -ne "\r${gl_huang}无效的输入,请重新输入! ${gl_zi}1 ${gl_bai}秒后返回"
    sleep_fractional 1
    echo -ne "\r${gl_lv}无效的输入,请重新输入! ${gl_zi}0 ${gl_bai}秒后返回"
    sleep_fractional 0.5
    echo ""
    return 2
}

exit_animation() {
    echo -ne "${gl_lv}即将退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo ""
    clear
}

uninstall_docker_environment() {
    if ! command -v docker &>/dev/null; then
        echo -e ""
        echo -e "${gl_zi}>>> 卸载 Docker 环境 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        log_warn "Docker 未安装，无需卸载"
        exit_animation
        return 1
    fi

	clear
    echo -e ""
    echo -e "${gl_zi}>>> 卸载 Docker 环境 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_hong}注意: ${gl_bai}确定卸载 Docker 环境吗？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" choice
    [ "$choice" = "0" ] && { exit_animation; return 1; }

    case "$choice" in
        [Yy])
            echo -e "${gl_zi}>>> 正在清理所有 Docker 资源 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            
            log_info "正在停止所有容器 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            docker stop $(docker ps -aq) >/dev/null 2>&1
            
            log_info "正在删除容器、镜像、网络、数据卷 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            docker system prune -a --volumes -f >/dev/null 2>&1
            
            log_info "正在卸载 Docker 相关组件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            if command -v apt &>/dev/null; then
                apt remove -y docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-compose >/dev/null 2>&1
                apt autoremove -y >/dev/null 2>&1
            elif command -v yum &>/dev/null || command -v dnf &>/dev/null; then
                yum remove -y docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-compose >/dev/null 2>&1
            fi
            
            log_info "正在删除配置文件与残留目录 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            rm -rf /etc/docker /var/lib/docker /var/run/docker.sock >/dev/null 2>&1
            hash -r
            
            echo -e ""
            log_ok "Docker 环境已完全卸载！"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        [Nn])
            log_info "已取消卸载操作"
            exit_animation
            return 0
            ;;
        *)
            handle_invalid_input
            return 1
            ;;
    esac
}

uninstall_docker_environment