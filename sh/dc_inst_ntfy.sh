#!/bin/bash
set -uo pipefail

# ====================== 【可自定义配置区】 在这里修改所有默认参数 ======================
# 项目标题
DEFAULT_TITLE="ntfy 消息推送服务 一键部署"

# 部署目录（不传参时的默认路径）
DEFAULT_COMPOSE_DIR="/vol1/1000/compose/ntfy"

# 默认访问端口（不传参时使用）
DEFAULT_PORT="8480"

# 默认容器名称（可自定义）
DEFAULT_CONTAINER_NAME="ntfy"

# 镜像地址
DEFAULT_IMAGE="binwiederhier/ntfy:latest"

# 容器内端口
DEFAULT_CONTAINER_PORT="80"
# ==============================================================================

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

root_use() {
    clear
    if [ "$EUID" -ne 0 ]; then
        echo -e "\n${gl_zi}>>> ROOT 登录检查 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}提示: ${gl_bai}该功能需要 root 用户才能运行！"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return 1
    fi
    return 0
}

check_port_available() {
    local PORT="$1"
    if ss -tuln | grep -q ":${PORT} "; then
        return 1
    elif netstat -tuln 2>/dev/null | grep -q ":${PORT} "; then
        return 1
    else
        return 0
    fi
}

get_free_port() {
    local start_port=$1
    local port=$start_port
    while ! check_port_available $port; do
        port=$((port + 1))
        if [ $port -gt $((start_port + 100)) ]; then
            echo ""
            return 1
        fi
    done
    echo $port
}

check_and_open_port() {
    local PORT="$1"
    [ -z "$PORT" ] && { log_error "未指定端口"; return 1; }
    if iptables -L INPUT -n 2>/dev/null | grep -qE "dpt:${PORT}[[:space:]]|dpt:${PORT}$"; then
        log_ok "端口 ${PORT} 已放行，无需操作"
        return 0
    fi
    log_warn "端口 ${PORT} 未放行，正在开放"
    iptables -I INPUT -p tcp --dport "${PORT}" -j ACCEPT 2>/dev/null
    iptables -I INPUT -p udp --dport "${PORT}" -j ACCEPT 2>/dev/null
    if command -v iptables-save >/dev/null 2>&1; then
        mkdir -p /etc/iptables 2>/dev/null
        iptables-save > /etc/iptables/rules.v4 2>/dev/null && log_ok "防火墙规则已保存"
    fi
    log_ok "端口 ${PORT} 已开放"
}

docker_check_env() {
    if ! command -v docker &>/dev/null; then
        log_warn "Docker 未安装，即将自动安装"
        bash <(curl -sSL gitee.com/meimolihan/cmdbox/raw/master/sh/lx_install_docker.sh)
        command -v docker &>/dev/null || { log_error "Docker 安装失败，请手动安装后重试"; sleep 1; exit 1; }
    fi
    if ! command -v docker-compose &>/dev/null && ! command -v docker &>/dev/null; then
        log_warn "Docker Compose 未安装，即将自动安装"
        bash <(curl -sSL gitee.com/meimolihan/cmdbox/raw/master/sh/lx_install_compose.sh)
        command -v docker-compose &>/dev/null || { log_error "Docker Compose 安装失败，请手动安装后重试"; sleep 1; exit 1; }
    fi
}

clean_old_container() {
    local targets=("$@")
    for container_name in "${targets[@]}"; do
        if docker ps -a --filter "name=^/${container_name}$" --format "{{.Names}}" | grep -q "^${container_name}$"; then
            log_info "检测到容器 ${container_name}，正在停止并删除"
            docker rm -f "${container_name}" >/dev/null 2>&1
            log_ok "容器 ${container_name} 清理完成"
        else
            log_ok "容器 ${container_name} 不存在，跳过"
        fi
    done
}

docker-ps-cn() {
    local filter_name="$1"
    local docker_filter=""
    [ -n "$filter_name" ] && docker_filter="--filter name=${filter_name}"
    printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "容器ID" "名称" "状态" "端口" "创建时间" "镜像" "$reset"
    docker ps ${docker_filter} --format "{{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.RunningFor}}\t{{.Image}}" \
        | awk -v cyan="$gl_lv" -v reset="$reset" 'BEGIN {FS="\t"; OFS="\t"} {gsub(/ days ago/,"天前"); gsub(/ hours ago/,"小时前"); gsub(/ minutes ago/,"分钟前"); gsub(/ seconds ago/,"秒前"); print cyan $2 reset, $3, $4, $5, $6}'
}

deploy_app() {
    local COMPOSE_DIR=""
    local HOST_PORT=""

    root_use || return 1
    clear
    echo -e "${gl_zi}>>> ${DEFAULT_TITLE}${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    docker_check_env

    # 传参解析：数字当端口，其余当目录
    for arg in "$@"; do
        if [[ "$arg" =~ ^[0-9]+$ ]]; then
            HOST_PORT="$arg"
        else
            COMPOSE_DIR="$arg"
        fi
    done

    if [ -z "${COMPOSE_DIR}" ]; then
        read -r -e -p "${gl_bai}请输入 docker-compose 存放路径（回车默认：${gl_huang}${DEFAULT_COMPOSE_DIR}${gl_bai}）(${gl_hong}0${gl_bai} 退出安装）：" input_dir
        COMPOSE_DIR=${input_dir:-$DEFAULT_COMPOSE_DIR}
    fi
    [ "$COMPOSE_DIR" = "0" ] && { exit_script; return 1; }

    log_info "部署目录：${COMPOSE_DIR}"
    mkdir -p "${COMPOSE_DIR}" "${COMPOSE_DIR}/cache" "${COMPOSE_DIR}/config" || { log_error "目录创建失败"; break_end; return 1; }
    cd "${COMPOSE_DIR}" || { log_error "进入目录失败"; break_end; return 1; }

    if [ -z "${HOST_PORT}" ]; then
        read -r -e -p "${gl_bai}请输入 HTTP 映射端口（回车默认：${gl_huang}${DEFAULT_PORT}${gl_bai}）(${gl_hong}0${gl_bai} 退出安装）：" input_port
        HOST_PORT=${input_port:-$DEFAULT_PORT}
    fi
    [ "$HOST_PORT" = "0" ] && { exit_script; rm -rf "${COMPOSE_DIR}"; return 1; }

    if ! check_port_available $HOST_PORT; then
        log_warn "端口 ${HOST_PORT} 已被占用"
        NEW_PORT=$(get_free_port $((HOST_PORT + 1)))
        [ -n "$NEW_PORT" ] && { log_info "自动分配新端口：${NEW_PORT}"; HOST_PORT=$NEW_PORT; } \
            || { log_error "无法找到可用端口"; break_end; return 1; }
    fi

    check_and_open_port "${HOST_PORT}"
    clean_old_container "${DEFAULT_CONTAINER_NAME}"

    # 生成 docker-compose.yml
    cat > docker-compose.yml <<EOF
services:
  ntfy:
    image: ${DEFAULT_IMAGE}
    container_name: ${DEFAULT_CONTAINER_NAME}
    command: serve
    environment:
      - TZ=Asia/Shanghai
    volumes:
      - ./cache:/var/cache/ntfy
      - ./config:/etc/ntfy
    ports:
      - "${HOST_PORT}:${DEFAULT_CONTAINER_PORT}"
    restart: always
EOF

    if docker-compose up -d 2>/dev/null; then
        log_ok "容器启动成功"
    elif docker compose up -d 2>/dev/null; then
        log_ok "容器启动成功"
    else
        log_error "容器启动失败"
        break_end
        return 1
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    docker-ps-cn ${DEFAULT_CONTAINER_NAME}
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    log_info "部署完成！访问地址：${gl_lv}http://${LOCAL_IP}:${HOST_PORT}${gl_bai}"
    log_info "部署目录：${gl_huang}${COMPOSE_DIR}${gl_bai}"
    log_info "数据目录：${gl_huang}${COMPOSE_DIR}/cache${gl_bai}"
    log_info "配置目录：${gl_huang}${COMPOSE_DIR}/config${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

deploy_app "$@"
