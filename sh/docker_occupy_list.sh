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

column_if_available() {
    if command -v column &> /dev/null; then
        column -t -s $'\t'
    else
        cat
    fi
}

show_help() {
    echo -e "${gl_lv}使用说明:${gl_bai}"
    echo -e "  ${gl_bai}$0 ${gl_lan}[容器名称]${gl_bai}"
    echo -e ""
    echo -e "${gl_lv}参数:${gl_bai}"
    echo -e "  ${gl_lan}[容器名称]${gl_bai}  可选的容器名称或ID"
    echo -e ""
    echo -e "${gl_lv}示例:${gl_bai}"
    echo -e "  ${gl_bai}$0${gl_bai}                         # 查看所有运行中的容器"
    echo -e "  ${gl_bai}$0 ${gl_lan}nginx${gl_bai}          # 查看指定容器"
    echo -e "  ${gl_bai}$0 ${gl_lan}myapp${gl_bai}          # 查看指定容器"
    echo -e "  ${gl_bai}$0 ${gl_lan}-h${gl_bai}             # 显示帮助信息"
    echo -e ""
    exit 0
}

check_container_exists() {
    local container_name="$1"
    if ! docker inspect "$container_name" &>/dev/null; then
        log_error "容器不存在或未运行: $container_name"
        return 1
    fi
    return 0
}

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    read -r -n 1 -s -p ""
    echo ""
    clear
}

get_running_containers() {
    docker ps --format "{{.Names}}" 2>/dev/null
}

list_beautify_specific_container() {
    local container_name="$1"
    
    if ! check_container_exists "$container_name"; then
        return 1
    fi
    
    {
        data=$(docker stats --no-stream "$container_name" --format "{{.Container}}\t{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}\t{{.PIDs}}" 2>/dev/null)
        
        if [ -z "$data" ]; then
            printf "%s%s\n" "$gl_huang" "容器 $container_name 没有资源使用数据" "$reset"
            return
        fi

        printf "%s%-12s\t%-20s\t%-8s\t%-20s\t%-8s\t%-12s\t%-12s\t%-6s%s\n" \
            "$gl_hui" "容器ID" "名称" "CPU%" "内存使用/限制" "内存%" "网络I/O" "块I/O" "PIDs" "$reset"
        printf "%s%-12s\t%-20s\t%-8s\t%-20s\t%-8s\t%-12s\t%-12s\t%-6s%s\n" \
            "$gl_hui" "------------" "--------------------" "--------" "--------------------" "--------" "------------" "------------" "------" "$reset"

        echo "$data" | awk -v cyan="$gl_bufan" -v green="$gl_lv" -v yellow="$gl_huang" \
            -v blue="$gl_lan" -v white="$gl_bai" -v reset="$reset" '
        BEGIN {FS="\t"; OFS="\t"}
        {
            id = substr($1, 1, 12)
            name = $2
            cpu = $3
            mem_usage = $4
            mem_perc = $5
            net_io = $6
            block_io = $7
            pids = $8

            print cyan id reset, green name reset, yellow cpu reset, blue mem_usage reset, \
                  yellow mem_perc reset, white net_io reset, white block_io reset, white pids reset
        }'
    } | column_if_available
}

list_beautify_all_containers() {
    {
        data=$(docker stats --no-stream --format "{{.Container}}\t{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}\t{{.PIDs}}" 2>/dev/null)
        
        if [ -z "$data" ]; then
            printf "%s%s\n" "$gl_huang" "没有运行中的容器" "$reset"
            return
        fi

        printf "%s%-12s\t%-20s\t%-8s\t%-20s\t%-8s\t%-12s\t%-12s\t%-6s%s\n" \
            "$gl_hui" "容器ID" "名称" "CPU%" "内存使用/限制" "内存%" "网络I/O" "块I/O" "PIDs" "$reset"
        printf "%s%-12s\t%-20s\t%-8s\t%-20s\t%-8s\t%-12s\t%-12s\t%-6s%s\n" \
            "$gl_hui" "------------" "--------------------" "--------" "--------------------" "--------" "------------" "------------" "------" "$reset"

        echo "$data" | awk -v cyan="$gl_bufan" -v green="$gl_lv" -v yellow="$gl_huang" \
            -v blue="$gl_lan" -v white="$gl_bai" -v reset="$reset" '
        BEGIN {FS="\t"; OFS="\t"}
        {
            id = substr($1, 1, 12)
            name = $2
            cpu = $3
            mem_usage = $4
            mem_perc = $5
            net_io = $6
            block_io = $7
            pids = $8

            print cyan id reset, green name reset, yellow cpu reset, blue mem_usage reset, \
                  yellow mem_perc reset, white net_io reset, white block_io reset, white pids reset
        }'
    } | column_if_available
}

main() {
    if ! docker info &>/dev/null; then
        log_error "Docker 服务未运行"
        exit 1
    fi
    
    local TARGET_CONTAINER=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                ;;
            *)
                if [[ -z "$TARGET_CONTAINER" ]]; then
                    TARGET_CONTAINER="$1"
                else
                    log_error "未知参数: $1"
                    echo -e "${gl_bai}使用 ${gl_huang}$0 -h ${gl_bai}查看帮助${gl_bai}"
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    if [[ -n "$TARGET_CONTAINER" ]]; then
        clear
        echo -e "${gl_zi}>>> 容器资源占用: ${gl_huang}$TARGET_CONTAINER${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        if ! list_beautify_specific_container "$TARGET_CONTAINER"; then
            local containers=($(get_running_containers))
            if [ ${#containers[@]} -gt 0 ]; then
                echo -e "${gl_bai}运行中的容器:${gl_bai}"
                for container in "${containers[@]}"; do
                    echo -e "  ${gl_lv}•${gl_bai} $container"
                done
            fi
        fi
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
    else
        clear
        echo -e "${gl_zi}>>> Docker容器占用列表${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        list_beautify_all_containers
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi