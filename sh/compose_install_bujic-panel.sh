#!/bin/bash
set -uo pipefail

# ====================== 【可自定义配置区】 ======================
DEFAULT_TITLE="Bujic Panel 布吉岛导航 一键部署"
DEFAULT_COMPOSE_DIR="/vol1/1000/compose/bujic-panel"
DEFAULT_PORT="3000"
DEFAULT_CONTAINER_NAME="bujic-panel"
# =================================================================

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

root_use() {
    clear
    if [ "$EUID" -ne 0 ]; then
        echo -e "\n${gl_zi}>>> ROOT登录检查 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}提示: ${gl_bai}该功能需要root用户才能运行！"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return 1
    fi
    return 0
}

docker_check_env() {
    echo -e ""
    echo -e "${gl_huang}>>> Docker环境检查 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    if command -v docker &>/dev/null; then
        log_ok "Docker 已安装"
    else
        log_warn "Docker 未安装，开始安装"
        bash <(curl -sL gitee.com/meimolihan/cmdbox/raw/master/sh/linux_install_docker.sh)
    fi
    if command -v docker-compose &>/dev/null || docker compose version &>/dev/null; then
        log_ok "Docker Compose 已安装"
    else
        log_warn "Docker Compose 未安装，开始安装"
        bash <(curl -sL gitee.com/meimolihan/cmdbox/raw/master/sh/linux_install_compose.sh)
    fi
}

check_and_open_port() {
    local PORT="$1"
    if [[ -z "$PORT" ]]; then
        log_error "未指定端口"
        return 1
    fi

    log_info "检查端口 ${gl_huang}${PORT}${gl_bai} 是否放行 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

    if iptables -L INPUT -n 2>/dev/null | grep -qE "dpt:${PORT}[[:space:]]|dpt:${PORT}$" 2>/dev/null; then
        log_ok "端口 ${PORT} 已放行"
        return 0
    fi

    log_warn "端口 ${gl_hong}${PORT}${gl_bai} 未放行，正在开放 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    iptables -I INPUT -p tcp --dport "${PORT}" -j ACCEPT 2>/dev/null
    iptables -I INPUT -p udp --dport "${PORT}" -j ACCEPT 2>/dev/null

    log_info "保存防火墙规则 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    local SAVED=0
    if command -v iptables-save >/dev/null 2>&1; then
        mkdir -p /etc/iptables 2>/dev/null
        iptables-save > /etc/iptables/rules.v4 2>/dev/null && SAVED=1
        if [ -d /etc/netplan ]; then
            iptables-save > /etc/netplan/iptables.rules 2>/dev/null
        fi
    fi
    [ "$SAVED" -eq 1 ] && log_ok "防火墙规则已保存" || log_warn "规则已添加但未持久化"
}

check_port_available() {
    local port=$1
    if command -v ss &>/dev/null; then
        ss -tlnp "sport = :$port" 2>/dev/null | grep -q ":$port" && return 1
    fi
    return 0
}

get_free_port() {
    local start=$1
    for ((i = start; i < start + 100; i++)); do
        if check_port_available $i; then
            echo "$i"
            return 0
        fi
    done
    echo ""
    return 1
}

clean_old_container() {
    local targets=("$@")
    echo -e ""
    echo -e "${gl_huang}>>> 清理容器与相关镜像（目标：${targets[*]}）${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    for container_name in "${targets[@]}"; do
        if docker ps -a --filter "name=^/${container_name}$" --format "{{.Names}}" | grep -q "^${container_name}$"; then
            log_info "检测到容器 ${gl_huang}${container_name}${gl_bai}，正在停止并删除 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            docker rm -f "${container_name}" >/dev/null 2>&1
            log_ok "容器 ${container_name} 清理完成"
        else
            log_ok "容器 ${container_name} 不存在，跳过"
        fi
    done

    log_info "开始清理相关镜像（关键词：${targets[*]}） ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    local image_ids=$(docker images --format "{{.ID}}" | grep -f <(printf "%s\n" "${targets[@]}" | sed 's/^/-i /;s/ / -i /g'))
    if [ -n "$image_ids" ]; then
        echo "$image_ids" | xargs docker rmi -f >/dev/null 2>&1
        log_ok "相关镜像已全部删除"
    else
        log_ok "未找到相关镜像"
    fi

    log_info "清理悬空镜像与未使用镜像 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    docker image prune -a -f >/dev/null 2>&1
    log_ok "未使用镜像清理完成"

    log_info "清理Docker无用资源 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    docker system prune -a -f --volumes >/dev/null 2>&1
    docker builder prune -af >/dev/null 2>&1
    log_ok "Docker系统资源清理完成"

    log_info "验证清理结果 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    local remain=0
    for name in "${targets[@]}"; do
        docker ps -a --filter "name=^/${name}$" --format "{{.Names}}" | grep -q "^${name}$" && remain=$((remain+1))
    done

    if [ "$remain" -eq 0 ]; then
        log_ok "所有指定容器、镜像、残留资源已彻底清理，无名称冲突"
    else
        log_warn "仍有 ${gl_huang}${remain}${gl_bai} 个相关容器未清理，请手动检查"
    fi
}

DOCKER_PS_CN_LOADED=false
docker-ps-cn() {
    local container_name="$1"
    if docker ps -a --filter "name=^/${container_name}$" --format "{{.ID}}" | grep -q .; then
        echo -e "${gl_bai}容器ID:   ${gl_lv}$(docker ps -a --filter "name=^/${container_name}$" --format "{{.ID}}")${gl_bai}"
        echo -e "${gl_bai}名称:     ${gl_lv}${container_name}${gl_bai}"
        echo -e "${gl_bai}镜像:     ${gl_bai}$(docker ps -a --filter "name=^/${container_name}$" --format "{{.Image}}")${gl_bai}"
        echo -e "${gl_bai}状态:     $(docker ps -a --filter "name=^/${container_name}$" --format "{{.Status}}")${gl_bai}"
        echo -e "${gl_bai}端口:     ${gl_huang}$(docker ps -a --filter "name=^/${container_name}$" --format "{{.Ports}}")${gl_bai}"
    else
        echo -e "${gl_hong}容器 ${container_name} 未运行${gl_bai}"
    fi
}

generate_encrypt_key() {
    echo $(openssl rand -hex 32 2>/dev/null || echo "please_replace_with_your_64_hex_chars_encrypt_key")
}

deploy_app() {
    local COMPOSE_DIR=""
    local HOST_PORT=""

    root_use || return 1
    docker_check_env
    clear
    echo -e "${gl_zi}>>> ${DEFAULT_TITLE}${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

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
    else
        log_info "已通过传参指定部署目录：${gl_huang}${COMPOSE_DIR}${gl_bai}"
    fi

    if [ "$COMPOSE_DIR" = "0" ]; then
        exit_script
        return 1
    fi

    log_info "部署目录：${gl_huang}${COMPOSE_DIR}${gl_bai}"
    mkdir -p "${COMPOSE_DIR}" || { log_error "目录创建失败"; break_end; return 1; }
    cd "${COMPOSE_DIR}" || { log_error "进入目录失败"; break_end; return 1; }

    if [ -z "${HOST_PORT}" ]; then
        read -r -e -p "${gl_bai}请输入映射端口（回车默认：${gl_huang}${DEFAULT_PORT}${gl_bai}）(${gl_hong}0${gl_bai} 退出安装）：" input_port
        HOST_PORT=${input_port:-$DEFAULT_PORT}
    else
        log_info "已通过传参指定端口：${gl_lv}${HOST_PORT}${gl_bai}"
    fi

    if [ "$HOST_PORT" = "0" ]; then
        exit_script
        rm -rf "${COMPOSE_DIR}"
        return 1
    fi

    log_info "使用端口：${gl_lv}${HOST_PORT}${gl_bai}"

    if ! check_port_available $HOST_PORT; then
        log_warn "端口 ${gl_hong}${HOST_PORT}${gl_bai} 已被占用"
        NEW_PORT=$(get_free_port $((HOST_PORT + 1)))
        if [ -n "$NEW_PORT" ]; then
            log_info "自动分配新端口：${gl_lv}${NEW_PORT}${gl_bai}"
            HOST_PORT=$NEW_PORT
        else
            log_error "无法找到可用端口，请手动指定"
            break_end
            return 1
        fi
    fi

    check_and_open_port ${HOST_PORT}
    clean_old_container "${DEFAULT_CONTAINER_NAME}"

    echo -e ""
    echo -e "${gl_huang}>>> 配置加密密钥 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_info "ENCRYPT_KEY 用于数据加密，需 64 位十六进制字符"
    read -r -e -p "${gl_bai}请输入加密密钥 ENCRYPT_KEY（回车自动生成）：" input_key
    local ENCRYPT_KEY="${input_key:-$(generate_encrypt_key)}"
    log_ok "ENCRYPT_KEY 已设置"

    echo -e ""
    echo -e "${gl_huang}>>> 生成 ${gl_lv}docker-compose.yml${gl_huang} 文件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    cat > docker-compose.yml << EOF
services:
  bujic-panel:
    image: crpi-a1liy20beodq2bdl.cn-beijing.personal.cr.aliyuncs.com/bujic/bujic-panel:latest
    container_name: bujic-panel
    restart: unless-stopped
    ports:
      - "${HOST_PORT}:3000"
    volumes:
      - ./data:/app/data
    environment:
      - DATA_DIR=/app/data
      - ENCRYPT_KEY=${ENCRYPT_KEY}
EOF

    if [ -f "docker-compose.yml" ]; then
        log_ok "配置文件创建成功"
    else
        log_error "配置文件创建失败"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return 1
    fi

    echo -e ""
    echo -e "${gl_huang}>>> 尝试启动容器 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    if docker-compose up -d; then
        log_ok "容器启动成功"
    else
        log_warn "docker-compose 启动失败，尝试兼容版 docker compose ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        if docker compose up -d; then
            log_ok "容器启动成功"
        else
            log_error "容器启动失败"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            return 1
        fi
    fi

    echo -e ""
    echo -e "${gl_huang}>>> 容器运行状态${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    docker-ps-cn ${DEFAULT_CONTAINER_NAME}
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    log_info "部署完成！"
    log_info "访问地址：${gl_lv}http://${LOCAL_IP}:${HOST_PORT}${gl_bai}"
    log_info "部署目录：${gl_huang}${COMPOSE_DIR}${gl_bai}"
    log_info "数据目录：${gl_huang}${COMPOSE_DIR}/data${gl_bai}"
    log_info "默认账号：${gl_huang}admin${gl_bai}  默认密码：${gl_huang}admin${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

deploy_app "$@"
