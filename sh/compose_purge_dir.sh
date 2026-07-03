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

log_info()  { echo -e "${gl_lan}[信息]${gl_bai} $*${reset}"; }
log_ok()    { echo -e "${gl_lv}[成功]${gl_bai} $*${reset}"; }
log_warn()  { echo -e "${gl_huang}[警告]${gl_bai} $*${reset}"; }
log_error() { echo -e "${gl_hong}[错误]${gl_bai} $*${reset}" >&2; }

sleep_fractional() {
    local seconds=$1
    if sleep "$seconds" 2>/dev/null; then return 0; fi
    if command -v perl >/dev/null 2>&1; then perl -e "select(undef, undef, undef, $seconds)"; return 0; fi
    if command -v python3 >/dev/null 2>&1; then python3 -c "import time; time.sleep($seconds)"; return 0; fi
    if command -v python >/dev/null 2>&1; then python -c "import time; time.sleep($seconds)"; return 0; fi
    local int_seconds=$(awk -v s="$seconds" 'BEGIN{print int(s+0.999)}')
    sleep "$int_seconds"
}

handle_y_n() {
    echo -e "${gl_hong}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai})${gl_hong}。${reset}"
    sleep 1
    echo -e "${gl_huang}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai})${gl_huang}。${reset}"
    sleep 1
    echo -e "${gl_lv}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai})${gl_lv}。${reset}"
    sleep_fractional 0.5
    return 2
}

exit_script() {
    echo ""
    echo -ne "${gl_hong}感谢使用，再见！${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}${reset}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}${reset}\c"
    sleep_fractional 0.6
    clear
    exit 0
}

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}${reset}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} ${reset}\c"
    read -r -n 1 -s -r -p ""
    echo ""
    clear
}

purge_compose_dir() {
    local COMPOSE_DIR="${1:-}"

    clear
    echo -e "${gl_zi}>>> 彻底清理 docker-compose 项目${gl_bai}${reset}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${reset}"

    if [[ -z "$COMPOSE_DIR" ]]; then
        read -r -e -p "$(echo -e "${gl_bai}请输入 docker-compose 目录路径 (${gl_hong}0${gl_bai}退出): ${reset}")" COMPOSE_DIR
        if [[ "$COMPOSE_DIR" == "0" ]]; then
            exit_script
        fi
    fi

    COMPOSE_DIR="$(realpath "$COMPOSE_DIR" 2>/dev/null || echo "$COMPOSE_DIR")"
    local COMPOSE_FILE="$COMPOSE_DIR/docker-compose.yml"

    log_info "目标目录: $COMPOSE_DIR"
    log_info "Compose 文件: $COMPOSE_FILE"

    if [[ ! -f "$COMPOSE_FILE" ]]; then
        log_error "未找到 docker-compose.yml"
        break_end
        exit 1
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${reset}"
    read -r -e -p "$(echo -e "${gl_hong}确认${gl_huang}删除容器${gl_bai}、${gl_huang}删除镜像 ${gl_bai}并 ${gl_huang}删除该目录${gl_hong}吗？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ${reset}")" confirm

    case "$confirm" in
        [Yy])
            echo ""
            echo -e "${gl_huang}>>> 停止并清理容器 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}${reset}"
            if command -v docker-compose &>/dev/null; then
                docker-compose -f "$COMPOSE_FILE" down --volumes --remove-orphans
            elif docker compose version &>/dev/null; then
                docker compose -f "$COMPOSE_FILE" down --volumes --remove-orphans
            else
                log_error "未找到 docker-compose 命令"
                break_end
                exit 1
            fi

            echo ""
            echo -e "${gl_huang}>>> 清理 Docker 系统资源 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}${reset}"
            docker system prune -af --volumes

            log_warn "强制删除目录: $COMPOSE_DIR"
            rm -rf "$COMPOSE_DIR"

            if [[ $? -eq 0 ]]; then
                log_ok "清理完成！目录已删除: $COMPOSE_DIR"
            else
                log_error "目录删除失败: $COMPOSE_DIR"
            fi
            ;;
        [Nn])
            log_warn "已取消操作"
            ;;
        *)
            handle_y_n
            purge_compose_dir "$@"
            return
            ;;
    esac

    echo -e "${gl_bufan}————————————————————————————————————————————————${reset}"
    break_end
}

main() {
    purge_compose_dir "${1:-}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
