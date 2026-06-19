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
    sleep 1
    echo -ne "\r\033[K${gl_lv}无效的输入,请重新输入! ${gl_zi}0${gl_lv} 秒后返回"
    sleep 0.5
    echo -ne "\r\033[K"
}

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    read -r -n 1 -s -p ""
    echo ""
}

show_help() {
    echo -e "${gl_lv}用法:${gl_bai} $0 ${gl_lan}<容器名>${gl_bai}"
    echo ""
    echo -e "${gl_lv}导出指定容器为 tar 备份包${gl_bai}"
    echo ""
    echo -e "${gl_lv}参数:${gl_bai}"
    echo -e "  ${gl_lan}<容器名>${gl_bai}  要导出的容器名称或ID"
    echo ""
    echo -e "${gl_lv}示例:${gl_bai}"
    echo -e "  ${gl_bai}$0 ${gl_lan}my-nginx${gl_bai}"
    echo -e "  ${gl_bai}$0 ${gl_lan}container_name${gl_bai}"
    exit 0
}

check_container_exists() {
    local container_name="$1"
    if ! docker inspect "$container_name" &>/dev/null; then
        return 1
    fi
    return 0
}

get_running_containers() {
    docker ps --format "{{.Names}}" 2>/dev/null
}

export_container() {
    local CONTAINER="$1"
    local BACKUP="${CONTAINER}_$(date +%F).tar"

    if ! check_container_exists "$CONTAINER"; then
        log_error "容器不存在: $CONTAINER"
        return 1
    fi

    docker export "$CONTAINER" > "$BACKUP"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_ok "已导出: ${gl_bai}${BACKUP}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
}

interactive_mode() {
    local containers=()
    while IFS= read -r line; do
        containers+=("$line")
    done < <(get_running_containers)

    if [[ ${#containers[@]} -eq 0 ]]; then
        clear
        echo -e "${gl_zi}>>> Docker 容器导出${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        log_warn "没有运行中的容器"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return
    fi

    while true; do
        clear
        echo -e "${gl_zi}>>> Docker 容器导出${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bai}运行中的容器:${gl_bai}"
        for i in "${!containers[@]}"; do
            echo -e "  ${gl_bufan}$((i+1)).${gl_bai} ${containers[$i]}"
        done
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "  ${gl_hong}0.${gl_bai} 退出"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请选择容器编号: ")" choice

        if [[ "$choice" == "0" || "$choice" == "00" || "$choice" == "000" ]]; then
            clear
            exit 0
        fi

        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt "${#containers[@]}" ]]; then
            handle_invalid_input
            continue
        fi

        local selected="${containers[$((choice-1))]}"
        export_container "$selected"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        break
    done
}

main() {
    if [[ $# -ge 1 ]]; then
        export_container "$1"
    else
        interactive_mode
    fi
}

main "$@"
