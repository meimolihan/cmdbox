#!/usr/bin/env bash
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
    echo -ne "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} "
    read -r -n 1 -s
    echo ""
    clear
}

sleep_fractional() {
    local seconds="${1:-0}"
    if sleep "$seconds" 2>/dev/null; then return; fi
    if command -v perl >/dev/null 2>&1; then perl -e "select(undef,undef,undef,$seconds)"; return; fi
    if command -v python3 >/dev/null 2>&1; then python3 -c "import time; time.sleep($seconds)"; return; fi
    sleep "$(printf "%.0f" "$seconds")"
}

exit_animation() {
    echo -ne "${gl_lv}即将退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    sleep_fractional 0.6
    echo ""
    clear
}

exit_script() {
    echo ""
    echo -ne "${gl_hong}感谢使用，再见！ ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    sleep_fractional 0.6
    clear
    exit 0
}

column_if_available() {
    if command -v column &> /dev/null; then
        column -t -s $'\t'
    else
        cat
    fi
}

docker-ps-cn() {
    local filter_name="${1:-}"
    {
        printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "容器ID" "名称" "状态" "端口" "创建时间" "镜像" "$reset"
        printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "----------" "----------" "----------" "----------" "----------" "----------" "$reset"
        local docker_cmd=(docker ps)
        [ -n "$filter_name" ] && docker_cmd+=(--filter "name=${filter_name}")
        "${docker_cmd[@]}" --format "{{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.RunningFor}}\t{{.Image}}" |
        awk -v green="$gl_lv" -v yellow="$gl_huang" -v cyan="$gl_bufan" -v blue="$gl_lan" -v white="$gl_bai" -v reset="$reset" '
        BEGIN { FS="\t"; OFS="\t" }
        {
            gsub(/ years? ago/, "年前", $5)
            gsub(/ months? ago/, "个月前", $5)
            gsub(/ weeks? ago/, "周前", $5)
            gsub(/ days? ago/, "天前", $5)
            gsub(/ hours? ago/, "小时前", $5)
            gsub(/ minutes? ago/, "分钟前", $5)
            gsub(/ seconds? ago/, "秒前", $5)
            gsub(/About /, "", $5)
            printf "%s%s%s\t%s%s\t%s%s\t%s%s\t%s%s\t%s%s\n",
                cyan, substr($1,1,12), reset,
                green, $2, reset,
                yellow, $3, reset,
                blue, $4, reset,
                white, $5, reset,
                white, $6, reset
        }'
    } | column_if_available
}

list_beautify_docker_images() {
    local filter_image="${1:-}"
    {
        printf "%s%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "仓库" "标签" "镜像ID" "创建时间" "大小" "$reset"
        printf "%s%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "----------" "----------" "----------" "----------" "----------" "$reset"
        local docker_cmd=(docker image ls --format "{{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedSince}}\t{{.Size}}")
        [ -n "$filter_image" ] && docker_cmd+=("$filter_image")
        "${docker_cmd[@]}" |
        awk -v green="$gl_lv" -v yellow="$gl_huang" -v cyan="$gl_bufan" -v blue="$gl_lan" -v white="$gl_bai" -v reset="$reset" '
        BEGIN { FS="\t"; OFS="\t" }
        {
            gsub(/ years? ago/, "年前", $4)
            gsub(/ months? ago/, "个月前", $4)
            gsub(/ weeks? ago/, "周前", $4)
            gsub(/ days? ago/, "天前", $4)
            gsub(/ hours? ago/, "小时前", $4)
            gsub(/ minutes? ago/, "分钟前", $4)
            gsub(/ seconds? ago/, "秒前", $4)
            gsub(/About /, "", $4)
            printf "%s%s%s\t%s%s\t%s%s\t%s%s\t%s%s\n",
                green, $1, reset,
                yellow, $2, reset,
                cyan, substr($3,1,12), reset,
                blue, $4, reset,
                white, $5, reset
        }'
    } | column_if_available
}

docker_check_env() {
    if ! command -v docker &>/dev/null; then
        log_info "正在检查 Docker 运行环境 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        log_warn "Docker 未安装，即将自动安装 Docker 环境 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        bash <(curl -sL gitee.com/meimolihan/cmdbox/raw/master/linux_install_docker.sh)
        if ! command -v docker &>/dev/null; then
            log_error "Docker 安装失败，请手动安装后重试！"
            sleep 1
            exit 1
        fi
        log_ok "Docker 安装成功！"
    fi

    if ! command -v docker-compose &>/dev/null && ! docker compose version &>/dev/null; then
        log_info "正在检查 Docker Compose 环境 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        log_warn "Docker Compose 未安装，即将自动安装 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        bash <(curl -sL gitee.com/meimolihan/cmdbox/raw/master/linux_install_compose.sh)
        if ! command -v docker-compose &>/dev/null && ! docker compose version &>/dev/null; then
            log_error "Docker Compose 安装失败，请手动安装后重试！"
            sleep 1
            exit 1
        fi
        log_ok "Docker Compose 安装成功！"
    fi
}

clean_old_container() {
    if [ $# -eq 0 ]; then
        log_warn "未传入任何容器名称参数，跳过清理"
        return 1
    fi

    local targets=("$@")
    echo -e "${gl_huang}>>> 清理容器与相关镜像（目标：${targets[*]}）${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    for container_name in "${targets[@]}"; do
        if docker ps -a --filter "name=^/${container_name}$" --format "{{.Names}}" | grep -q "^${container_name}$"; then
            log_info "检测到容器 ${gl_huang}${container_name}${gl_bai}，正在停止并删除"
            docker rm -f "${container_name}" >/dev/null 2>&1
            log_ok "容器 ${container_name} 清理完成"
        else
            log_ok "容器 ${container_name} 不存在，跳过"
        fi
    done

    log_info "清理相关镜像（关键词：${targets[*]}）"
    for keyword in "${targets[@]}"; do
        docker images --format "{{.Repository}}:{{.Tag}}" | grep "${keyword}" | xargs -r docker rmi -f >/dev/null 2>&1
    done
    log_ok "相关镜像清理完成"

    log_info "清理悬空镜像"
    docker image prune -f >/dev/null 2>&1
    log_ok "Docker 系统资源清理完成"

    log_info "验证清理结果"
    local remain=0
    for name in "${targets[@]}"; do
        docker ps -a --filter "name=^/${name}$" --format "{{.Names}}" | grep -q "^${name}$" && remain=$((remain+1))
    done

    if [ "$remain" -eq 0 ]; then
        log_ok "所有指定容器、镜像、残留资源已彻底清理"
    else
        log_warn "仍有 ${gl_huang}${remain}${gl_bai} 个相关容器未清理"
    fi
}

deploy_cmdbox() {
    clear
    echo -e "${gl_zi}>>> cmdbox 项目本地构建一键部署${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    docker_check_env

    DEFAULT_PROJECT_DIR="/vol1/1000/compose/opencode/workspace/cmdbox-main"
    DEFAULT_DEPLOY_DIR="/vol1/1000/compose/cmdbox"
    DEFAULT_PORT="9665"

    PROJECT_DIR="${1:-}"
    if [ -z "${PROJECT_DIR}" ]; then
        read -r -e -p "${gl_bai}请输入项目源码目录（回车默认：${gl_huang}${DEFAULT_PROJECT_DIR}${gl_bai}）(${gl_hong}0${gl_bai} 退出)：" PROJECT_DIR
        PROJECT_DIR="${PROJECT_DIR:-${DEFAULT_PROJECT_DIR}}"
    fi
    [ "${PROJECT_DIR}" = "0" ] && exit_script && return 1

    DEPLOY_DIR="${2:-}"
    if [ -z "${DEPLOY_DIR}" ]; then
        read -r -e -p "${gl_bai}请输入部署运行目录（回车默认：${gl_huang}${DEFAULT_DEPLOY_DIR}${gl_bai}）(${gl_hong}0${gl_bai} 退出)：" DEPLOY_DIR
        DEPLOY_DIR="${DEPLOY_DIR:-${DEFAULT_DEPLOY_DIR}}"
    fi
    [ "${DEPLOY_DIR}" = "0" ] && exit_script && return 1

    HOST_PORT="${3:-}"
    if [ -z "${HOST_PORT}" ]; then
        read -r -e -p "${gl_bai}请输入映射端口（回车默认：${gl_huang}${DEFAULT_PORT}${gl_bai}）(${gl_hong}0${gl_bai} 退出)：" HOST_PORT
        HOST_PORT="${HOST_PORT:-${DEFAULT_PORT}}"
    fi
    [ "${HOST_PORT}" = "0" ] && exit_script && rm -rf "${DEPLOY_DIR}" && return 1

    log_info "项目源码目录：${gl_huang}${PROJECT_DIR}${gl_bai}"
    log_info "部署运行目录：${gl_huang}${DEPLOY_DIR}${gl_bai}"
    log_info "使用端口：${gl_lv}${HOST_PORT}${gl_bai}"
    mkdir -p "${DEPLOY_DIR}" || { log_error "部署目录创建失败"; exit_animation; return 1; }

    if [ ! -d "${PROJECT_DIR}" ]; then
        log_error "项目源码目录不存在：${PROJECT_DIR}"
        exit_animation
        return 1
    fi

    clean_old_container "cmdbox" "command"

    echo -e ""
    echo -e "${gl_huang}>>> 开始构建项目${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    cd "${PROJECT_DIR}" || { log_error "进入项目目录失败"; break_end; return 1; }

    log_info "执行 docker build 构建镜像"
    docker build -t mobufan/cmdbox:latest . || { log_error "镜像构建失败"; break_end; return 1; }

    log_ok "项目构建 + 镜像制作完成！"
    echo -e ""
    echo -e "${gl_huang}>>> 镜像详情${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_docker_images "mobufan/cmdbox:latest"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    echo -e ""
    log_info "生成 docker-compose.yml 配置文件"
    cd "${DEPLOY_DIR}" || { log_error "进入部署目录失败"; exit_animation; return 1; }

    cat > docker-compose.yml << EOF
services:
    cmdbox:
        image: mobufan/cmdbox:latest
        container_name: cmdbox
        restart: always
        ports:
            - ${HOST_PORT}:80
EOF

    [ ! -f docker-compose.yml ] && log_error "配置文件创建失败" && exit_animation && return 1
    log_ok "配置文件创建成功"

    echo -e ""
    log_info "启动容器"
    if docker compose up -d 2>/dev/null || docker-compose up -d; then
        log_ok "容器启动成功"
    else
        log_error "容器启动失败"
        exit_animation
        return 1
    fi

    echo -e ""
    echo -e "${gl_huang}>>> 容器运行状态${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    docker-ps-cn cmdbox
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    LOCAL_IP=$(hostname -I | awk '{print $1}')
    log_info "部署完成！"
    log_info "访问地址：${gl_lv}http://${LOCAL_IP}:${HOST_PORT}${gl_bai}"
    log_info "项目源码目录：${gl_huang}${PROJECT_DIR}${gl_bai}"
    log_info "部署运行目录：${gl_huang}${DEPLOY_DIR}${gl_bai}"
    log_info "容器名称：${gl_lv}cmdbox${gl_bai}"
    log_info "使用镜像：${gl_lv}mobufan/cmdbox:latest${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

deploy_cmdbox "${1:-}" "${2:-}" "${3:-}"
