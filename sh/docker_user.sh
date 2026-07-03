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

handle_invalid_input() {
    echo -ne "\r\033[K${gl_huang}无效的输入,请重新输入! ${gl_zi} 1 ${gl_huang} 秒后返回"
    sleep_fractional 1
    echo -ne "\r\033[K${gl_lv}无效的输入,请重新输入! ${gl_zi}0${gl_lv} 秒后返回"
    sleep_fractional 0.5
    echo -ne "\r\033[K"
    return 2
}

handle_y_n() {
    echo -e "${gl_hong}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai})${gl_hong}。${gl_bai}"
    sleep 1
    echo -e "${gl_huang}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai})${gl_huang}。${gl_bai}"
    sleep 1
    echo -e "${gl_lv}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai})${gl_lv}。${gl_bai}"
    sleep 0.5
    return 2
}

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n 1 -s -r -p ""
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
    echo -ne "${gl_lv}即将退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
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

cancel_return() {
    local menu_name="${1:-上一级选单}"
    echo -e "${gl_lv}即将返回到 ${gl_huang}${menu_name}${gl_lv} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    sleep 0.6
    echo ""
    clear
}

check_user_in_docker_group() {
    if getent group docker | grep -q "\b${USER}\b"; then
        return 0
    else
        return 1
    fi
}

add_user_to_docker() {
    clear
    echo -e ""
    echo -e "${gl_zi}>>> 添加用户到Docker组${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    log_info "检查当前用户在 Docker 组中的状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

    if check_user_in_docker_group; then
        log_ok "当前用户 ${USER} 已在 docker 组中"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return 0
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    log_info "当前 Docker 组成员:"
    getent group docker || echo -e "  ${gl_huang}Docker 组不存在${gl_bai}"

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    read -r -e -p "$(echo -e "${gl_bai}是否将当前用户 ${gl_lv}${USER}${gl_bai} 添加到 docker 组? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm_add

    [ "$confirm_add" = "0" ] && { cancel_return "Docker用户管理"; return 1; }

    case "$confirm_add" in
    [Yy])
        echo -e "${gl_bai}正在执行添加操作 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        ;;
    *) 
        handle_y_n
        return 1
        ;;
    esac

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_info "执行命令: sudo usermod -aG docker ${USER}"

    if sudo usermod -aG docker "$USER"; then
        log_ok "已成功将用户 ${USER} 添加到 docker 组"

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        log_info "更新后的 Docker 组成员:"
        getent group docker

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}重要提示:${gl_bai}"
        echo -e "  ${gl_huang}• 需要重新登录或执行以下命令使更改生效:${gl_bai}"
        echo -e "  ${gl_lv}  newgrp docker${gl_bai}"
        echo -e "  ${gl_huang}• 或者注销后重新登录系统${gl_bai}"

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}是否立即应用更改? (执行 ${gl_lv}newgrp docker${gl_bai}) (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" apply_now
        case "$apply_now" in
        [Yy])
            log_info "正在应用更改 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_huang}注意: 执行 newgrp docker 后，您将进入新的 shell 会话${gl_bai}"
            echo -e "${gl_huang}要返回原会话，请输入 'exit' 命令${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            
            read -r -e -p "$(echo -e "${gl_hong}警告: ${gl_bai}这将结束当前脚本并启动新会话。继续? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" final_confirm
            if [[ "$final_confirm" =~ ^[Yy]$ ]]; then
                log_info "正在启动新会话 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                exec newgrp docker
            else
                log_info "已取消立即应用更改"
                echo -e "${gl_huang}请稍后手动执行 'newgrp docker' 或重新登录系统${gl_bai}"
            fi
            ;;
        esac
    else
        log_error "添加用户到 docker 组失败"
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

remove_user_from_docker() {
    echo -e ""
    echo -e "${gl_zi}>>> 从Docker组移除用户${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    log_info "检查当前用户在 Docker 组中的状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

    if ! check_user_in_docker_group; then
        log_warn "当前用户 ${USER} 不在 docker 组中"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return 0
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    log_info "当前 Docker 组成员:"
    getent group docker

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    read -r -e -p "$(echo -e "${gl_bai}是否从 docker 组中移除用户 ${gl_lv}${USER}${gl_bai}? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm_remove
    [ "$confirm_remove" = "0" ] && { cancel_return "Docker用户管理"; return 1; }
    
    case "$confirm_remove" in
    [Yy])
        echo -e "${gl_bai}正在执行移除操作 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        ;;
    *) 
        handle_y_n
        return 1
        ;;
    esac

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}请选择移除方式:${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bufan}1.  ${gl_bai}使用 sudo gpasswd -d 命令 (推荐)"
    echo -e "${gl_bufan}2.  ${gl_bai}使用 sudo deluser 命令"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_huang}0.  ${gl_bai}返回"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}请选择 (${gl_bai}1${gl_bai}-${gl_bai}2${gl_bai}/${gl_huang}0${gl_bai}返回): ")" remove_method

    case "$remove_method" in
    1)
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        log_info "执行命令: sudo gpasswd -d ${USER} docker"

        if sudo gpasswd -d "$USER" docker; then
            log_ok "已成功从 docker 组移除用户 ${USER}"
        else
            log_error "移除用户失败"
        fi
        ;;
    2)
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        log_info "执行命令: sudo deluser ${USER} docker"

        if sudo deluser "$USER" docker; then
            log_ok "已成功从 docker 组移除用户 ${USER}"
        else
            log_error "移除用户失败"
        fi
        ;;
    0) 
        cancel_return
        return 0
        ;;
    *) 
        handle_invalid_input
        return 1
        ;;
    esac

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_info "更新后的 Docker 组成员:"
    getent group docker || echo -e "  ${gl_huang}Docker 组不存在或为空${gl_bai}"

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_warn "注意: 更改可能需要重新登录或新会话才能生效"

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

check_docker_group_status() {
    echo -e ""
    echo -e "${gl_zi}>>> Docker组状态检查${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    if getent group docker >/dev/null; then
        log_info "Docker 组存在"
        
        echo -e "${gl_bai}Docker 组详细信息:${gl_bai}"
        getent group docker

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        if check_user_in_docker_group; then
            log_ok "当前用户 ${USER} 是 docker 组成员"
        else
            log_warn "当前用户 ${USER} 不是 docker 组成员"
        fi
        
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bai}Docker 组所有成员:${gl_bai}"
        getent group docker | cut -d: -f4 | tr ',' '\n' | while IFS= read -r member; do
            if [ -n "$member" ]; then
                echo -e "  ${gl_lv}•${gl_bai} $member"
            fi
        done
    else
        log_error "Docker 组不存在，可能需要先安装 Docker"
    fi
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

docker_user_management_menu() {
    while true; do
        clear
        echo -e ""
        echo -e "${gl_zi}>>> Docker 用户组管理${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        if getent group docker >/dev/null; then
            if check_user_in_docker_group; then
                echo -e "${gl_bai}当前状态: ${gl_lv}用户 ${USER} 是 docker 组成员${gl_bai}"
            else
                echo -e "${gl_bai}当前状态: ${gl_huang}用户 ${USER} 不是 docker 组成员${gl_bai}"
            fi
        else
            echo -e "${gl_bai}当前状态: ${gl_hong}Docker 组不存在${gl_bai}"
        fi
        
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}添加用户到Docker组"
        echo -e "${gl_bufan}2.  ${gl_bai}从Docker组移除用户"
        echo -e "${gl_bufan}3.  ${gl_bai}查看Docker组状态"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_hong}0.  ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" choice
        
        case $choice in
            1) add_user_to_docker ;;
            2) remove_user_from_docker ;;
            3) check_docker_group_status ;;
            0 | 00) exit_script ;;
            *) handle_invalid_input ;;
        esac
    done
}

process_command_line() {
    local cmd="${1:-}"
    
    case "$cmd" in
        "add"|"--add")
            add_user_to_docker
            ;;
        "remove"|"--remove")
            remove_user_from_docker
            ;;
        "status"|"--status")
            check_docker_group_status
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            docker_user_management_menu
            ;;
    esac
}

show_help() {
    echo -e ""
    echo -e "${gl_zi}>>> Docker 用户组管理工具${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}用法: $0 [命令]${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}可用命令:${gl_bai}"
    echo -e "${gl_lv}  add, --add      ${gl_bai}添加当前用户到 Docker 组"
    echo -e "${gl_lv}  remove, --remove ${gl_bai}从 Docker 组移除当前用户"
    echo -e "${gl_lv}  status, --status ${gl_bai}查看 Docker 组状态"
    echo -e "${gl_lv}  help, --help, -h${gl_bai}显示此帮助信息"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}示例:${gl_bai}"
    echo -e "${gl_huang}  $0 add        ${gl_bai}# 添加用户到 Docker 组"
    echo -e "${gl_huang}  $0 --status   ${gl_bai}# 查看 Docker 组状态"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}无参数时进入交互式菜单${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
}

main() {
    if [[ $# -gt 0 ]]; then
        process_command_line "$1"
    else
        docker_user_management_menu
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi