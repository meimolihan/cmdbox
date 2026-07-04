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

exit_script() {
    echo ""
    echo -ne "${gl_hong}感谢使用，再见！${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo -e "${reset}"
    clear
    exit 0
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

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}${reset}"
    echo -e -n "${gl_bai}按任意键继续${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} ${reset}"
    read -r -n 1 -s
    echo ""
    clear
}

remove_deployment_dir() {
    local deploy_dir="$1"
    if [[ -n "$deploy_dir" && -d "$deploy_dir" ]]; then
        log_warn "正在删除部署目录: $deploy_dir"
        rm -rf "$deploy_dir"
        if [[ $? -eq 0 ]]; then
            log_ok "部署目录已删除: $deploy_dir"
        else
            log_error "部署目录删除失败: $deploy_dir"
        fi
    elif [[ -n "$deploy_dir" ]]; then
        log_warn "部署目录不存在，跳过删除: $deploy_dir"
    fi
}

column_if_available() {
    if command -v column &> /dev/null; then
        column -t -s $'\t'
    else
        cat
    fi
}

list_beautify_docker_ps() {
    {
        printf "%s%s\t%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "容器ID" "镜像" "命令" "创建时间" "状态" "端口" "名称" "$reset"
        printf "%s%s\t%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "--------" "--------" "--------" "--------" "--------" "--------" "--------" "$reset"

        docker ps -a --format "{{.ID}}\t{{.Image}}\t{{.Command}}\t{{.RunningFor}}\t{{.Status}}\t{{.Ports}}\t{{.Names}}" | \
        awk -v cyan="$gl_bufan" -v green="$gl_lv" -v yellow="$gl_huang" -v blue="$gl_lan" -v white="$gl_bai" -v reset="$reset" '
        BEGIN {FS="\t"; OFS="\t"}
        {
            id = substr($1, 1, 12)
            image = $2
            cmd = $3
            created = $4
            status = $5
            ports = $6
            name = $7

            gsub(/ years ago/, "年前", created)
            gsub(/ year ago/, "年前", created)
            gsub(/ months ago/, "个月前", created)
            gsub(/ month ago/, "个月前", created)
            gsub(/ weeks ago/, "周前", created)
            gsub(/ week ago/, "周前", created)
            gsub(/ days ago/, "天前", created)
            gsub(/ day ago/, "天前", created)
            gsub(/ hours ago/, "小时前", created)
            gsub(/ hour ago/, "小时前", created)
            gsub(/ minutes ago/, "分钟前", created)
            gsub(/ minute ago/, "分钟前", created)
            gsub(/ seconds ago/, "秒前", created)
            gsub(/ second ago/, "秒前", created)
            gsub(/About /, "", created)

            gsub(/ years ago/, "年前", status)
            gsub(/ year ago/, "年前", status)
            gsub(/ months ago/, "个月前", status)
            gsub(/ month ago/, "个月前", status)
            gsub(/ weeks ago/, "周前", status)
            gsub(/ week ago/, "周前", status)
            gsub(/ days ago/, "天前", status)
            gsub(/ day ago/, "天前", status)
            gsub(/ hours ago/, "小时前", status)
            gsub(/ hour ago/, "小时前", status)
            gsub(/ minutes ago/, "分钟前", status)
            gsub(/ minute ago/, "分钟前", status)
            gsub(/ seconds ago/, "秒前", status)
            gsub(/ second ago/, "秒前", status)
            gsub(/About /, "", status)

            print cyan id reset, blue image reset, white cmd reset, blue created reset, yellow status reset, white ports reset, green name reset
        }'
    } | column_if_available
}

docker_clean_all() {
    local deploy_dir="${1:-}"
    
    clear
    echo -e "${gl_huang}>>> Docker 容器/镜像 列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_docker_ps
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    echo ""
    echo -e "${gl_zi}>>> Docker 环境彻底清理${gl_bai}${reset}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_hong}⚠️  警告: 此操作将彻底清理 Docker 环境！${reset}"
    echo -e "${gl_huang}  - 删除所有容器 (运行中/停止)${reset}"
    echo -e "${gl_huang}  - 删除所有镜像${reset}"
    if [[ -n "$deploy_dir" ]]; then
        echo -e "${gl_huang}  - 删除部署目录: $deploy_dir${reset}"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${reset}"
    
    read -r -e -p "$(echo -e "${gl_bai}确定执行彻底清理吗？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai})(${gl_hong}0${gl_bai}退出): ${reset}")" choice
    
    case "$choice" in
        [Yy])
            echo -ne "${gl_huang}正在停止并删除所有容器${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
            sleep_fractional 0.5
            echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
            sleep_fractional 0.5
            echo ""
            
            local containers=$(docker ps -aq 2>/dev/null)
            if [[ -n "$containers" ]]; then
                docker stop $containers 2>/dev/null || true
                docker rm -f $containers 2>/dev/null || true
                log_ok "所有容器已删除"
            else
                log_info "没有容器需要删除"
            fi
            
            echo -ne "${gl_huang}正在删除所有镜像${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
            sleep_fractional 0.5
            echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
            sleep_fractional 0.5
            echo ""
            
            local images=$(docker images -q 2>/dev/null)
            if [[ -n "$images" ]]; then
                docker rmi -f $images 2>/dev/null || true
                log_ok "所有镜像已删除"
            else
                log_info "没有镜像需要删除"
            fi
            
            if [[ -n "$deploy_dir" ]]; then
                remove_deployment_dir "$deploy_dir"
            fi

            log_ok "Docker 环境彻底清理完成！"
            echo -e ""
            echo -e "${gl_huang}>>> Docker 容器/镜像 列表${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            list_beautify_docker_ps
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        0) 
            exit_script
            return 1
            ;;
        *) 
            handle_y_n
            ;;
    esac
}

docker_clean_all "${1:-}"