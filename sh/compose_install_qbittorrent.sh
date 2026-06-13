#!/bin/bash
set -uo pipefail

# ====================== 【可自定义配置区】 ======================
DEFAULT_TITLE="qBittorrent 下载工具 一键部署"
DEFAULT_COMPOSE_DIR="/vol1/1000/compose/qbittorrent"
DEFAULT_PORT="8081"
DEFAULT_CONTAINER_NAME="qbittorrent"
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

exit_script() {
    echo ""
    echo -ne "${gl_hong}感谢使用，再见！ ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
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

check_and_open_port() {
    local PORT="$1"
    if [[ -z "$PORT" ]]; then
        log_error "未指定端口"
        return 1
    fi

    log_info "检查端口 ${gl_huang}${PORT}${gl_bai} 是否放行"

    local opened=false
    if command -v firewall-cmd &>/dev/null && firewall-cmd --state &>/dev/null; then
        if firewall-cmd --list-ports | grep -qw "${PORT}/tcp"; then
            opened=true
        fi
    elif iptables -L INPUT -n 2>/dev/null | grep -qE "dpt:${PORT}.*ACCEPT"; then
        opened=true
    fi

    if $opened; then
        log_ok "端口 ${PORT} 已放行"
        return 0
    fi

    log_warn "端口 ${gl_hong}${PORT}${gl_bai} 未放行，正在开放"

    if command -v firewall-cmd &>/dev/null && firewall-cmd --state &>/dev/null; then
        firewall-cmd --permanent --add-port=${PORT}/tcp >/dev/null 2>&1
        firewall-cmd --permanent --add-port=${PORT}/udp >/dev/null 2>&1
        firewall-cmd --reload >/dev/null 2>&1
        log_ok "端口 ${PORT} 已通过 firewalld 开放"
    else
        iptables -I INPUT -p tcp --dport "${PORT}" -j ACCEPT 2>/dev/null
        iptables -I INPUT -p udp --dport "${PORT}" -j ACCEPT 2>/dev/null
        if command -v iptables-save >/dev/null 2>&1; then
            if command -v netfilter-persistent >/dev/null 2>&1; then
                netfilter-persistent save >/dev/null 2>&1
            elif [ -d /etc/iptables ]; then
                iptables-save > /etc/iptables/rules.v4
            fi
        fi
        log_ok "端口 ${PORT} 已通过 iptables 开放"
    fi
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
docker-ps-cn() {
    {
        local filter_name="$1"
        local docker_filter=""
        [ -n "$filter_name" ] && docker_filter="--filter name=${filter_name}"
        
        printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "容器ID" "名称" "状态" "端口" "创建时间" "镜像" "$reset"
        printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "----------" "----------" "----------" "----------" "----------" "----------" "$reset"
        
        docker ps ${docker_filter} --format "{{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.RunningFor}}\t{{.Image}}" | \
        awk -v green="$gl_lv" -v yellow="$gl_huang" -v cyan="$gl_bufan" -v blue="$gl_lan" -v white="$gl_bai" -v reset="$reset" -v gl_bai="$gl_bai" '
        BEGIN {FS="\t"; OFS="\t"}
        {
            id = substr($1, 1, 12)
            name = $2
            status = $3
            ports = $4
            time = $5
            image = $6
            gsub(/ years? ago/, "年前", time)
            gsub(/ months? ago/, "个月前", time)
            gsub(/ weeks? ago/, "周前", time)
            gsub(/ days? ago/, "天前", time)
            gsub(/ hours? ago/, "小时前", time)
            gsub(/ minutes? ago/, "分钟前", time)
            gsub(/ seconds? ago/, "秒前", time)
            gsub(/About /, "", time)
            print cyan id reset, green name reset, yellow status reset, blue ports reset, white time reset, gl_bai image reset
        }'
    } | column_if_available
}

docker_check_env() {
    if ! command -v docker &>/dev/null; then
        log_info "Docker 未安装，开始自动安装 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        bash <(curl -sL gitee.com/meimolihan/cmdbox/raw/master/sh/linux_docker.sh)
        if ! command -v docker &>/dev/null; then
            log_error "Docker 安装失败！"
            exit 1
        fi
        log_ok "Docker 安装成功"
    fi
    
    if ! command -v docker-compose &>/dev/null && ! docker compose version &>/dev/null; then
        log_info "Docker Compose 未安装，开始自动安装 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        bash <(curl -sL gitee.com/meimolihan/cmdbox/raw/master/sh/linux_compose.sh)
        if ! command -v docker-compose &>/dev/null && ! docker compose version &>/dev/null; then
            log_error "Docker Compose 安装失败！"
            exit 1
        fi
        log_ok "Docker Compose 安装成功"
    fi
}

clean_old_container() {
    local targets=("$@")
    [ ${#targets[@]} -eq 0 ] && return
    
    echo -e "\n${gl_huang}>>> 清理旧容器${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    for container_name in "${targets[@]}"; do
        if docker ps -a --format "{{.Names}}" | grep -q "^${container_name}$"; then
            log_info "删除容器: ${container_name}"
            docker rm -f "${container_name}" >/dev/null 2>&1
        fi
    done
    log_ok "清理完成"
}

wait_and_get_password() {
    local container_name=$1
    local port=$2
    local max_wait=60
    local waited=0
    
    log_info "等待 Web 服务启动 (最多 ${max_wait} 秒) ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    while [ $waited -lt $max_wait ]; do
        local status_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${port} 2>/dev/null)
        if [ "$status_code" = "200" ] || [ "$status_code" = "401" ] || [ "$status_code" = "403" ]; then
            log_ok "Web 服务已就绪 (HTTP ${status_code})"
            break
        fi
        sleep_fractional 1
        waited=$((waited + 1))
        echo -n "."
    done
    echo ""
    
    local password=""
    local logs=$(docker logs "$container_name" 2>&1)
    password=$(echo "$logs" | grep -oP 'temporary password is provided for this session: \K[A-Za-z0-9]+' | head -1)
    if [ -z "$password" ]; then
        password=$(echo "$logs" | grep -oP 'Password: \K[A-Za-z0-9]+' | head -1)
    fi
    echo "$password"
}

deploy_app() {
    local COMPOSE_DIR=""
    local HOST_PORT=""
    
    root_use || return 1
    clear
    echo -e "${gl_zi}>>> ${DEFAULT_TITLE}${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    docker_check_env
    
    for arg in "$@"; do
        if [[ "$arg" =~ ^[0-9]+$ ]]; then
            HOST_PORT="$arg"
        else
            COMPOSE_DIR="$arg"
        fi
    done
    
    if [ -z "${COMPOSE_DIR}" ]; then
        read -r -e -p "${gl_bai}部署目录（回车默认：${gl_huang}${DEFAULT_COMPOSE_DIR}${gl_bai}）(0退出): " input_dir
        COMPOSE_DIR=${input_dir:-$DEFAULT_COMPOSE_DIR}
    fi
    
    if [ "$COMPOSE_DIR" = "0" ]; then
        exit_script
        return 1
    fi
    
    log_info "部署目录：${gl_huang}${COMPOSE_DIR}${gl_bai}"
    mkdir -p "${COMPOSE_DIR}" || { log_error "目录创建失败"; break_end; return 1; }
    cd "${COMPOSE_DIR}" || { log_error "目录切换失败"; break_end; return 1; }
    
    if [ -z "${HOST_PORT}" ]; then
        read -r -e -p "${gl_bai}Web端口（回车默认：${gl_huang}${DEFAULT_PORT}${gl_bai}）(0退出): " input_port
        HOST_PORT=${input_port:-$DEFAULT_PORT}
    fi
    
    if [ "$HOST_PORT" = "0" ]; then
        exit_script
        rm -rf "${COMPOSE_DIR}"
        return 1
    fi
    
    log_info "Web端口：${gl_lv}${HOST_PORT}${gl_bai}，BT端口：6881"

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

    check_and_open_port "${HOST_PORT}"
    check_and_open_port "6881"
    
    clean_old_container "${DEFAULT_CONTAINER_NAME}"
    
    echo -e "\n${gl_huang}>>> 生成配置文件${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    mkdir -p config downloads
    chown -R 1000:1000 config downloads
    
    cat > docker-compose.yml << EOF
services:
   ${DEFAULT_CONTAINER_NAME}:
      container_name: ${DEFAULT_CONTAINER_NAME}
      image: lscr.io/linuxserver/qbittorrent:latest
      restart: unless-stopped
      network_mode: bridge
      ports:
         - 6881:6881
         - 6881:6881/udp
         - ${HOST_PORT}:8081
      volumes:
         - ./config:/config
         - ./downloads:/downloads
      environment:
         - PUID=1000
         - PGID=1000
         - TZ=Asia/Shanghai
         - UMASK_SET=022
         - WEBUI_PORT=8081
EOF
    
    log_ok "配置文件已创建"
    
    echo -e "\n${gl_huang}>>> 启动容器${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    if docker-compose up -d 2>/dev/null || docker compose up -d 2>/dev/null; then
        log_ok "容器启动成功"
    else
        log_error "容器启动失败"
        break_end
        return 1
    fi
    
    log_info "等待容器完全启动 (约 15 秒) ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    sleep_fractional 15
    
    local QB_PASSWORD=$(wait_and_get_password "${DEFAULT_CONTAINER_NAME}" "${HOST_PORT}")
    
    echo -e "\n${gl_huang}>>> 容器状态${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    docker-ps-cn ${DEFAULT_CONTAINER_NAME}
    
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    echo -e "\n${gl_zi}========================================${gl_bai}"
    echo -e "${gl_lv}✅ 部署完成！${gl_bai}"
    echo -e "${gl_zi}========================================${gl_bai}"
    echo -e "${gl_bufan}📁 部署目录：${gl_huang}${COMPOSE_DIR}${gl_bai}"
    echo -e "${gl_bufan}🌐 访问地址：${gl_lv}http://${LOCAL_IP}:${HOST_PORT}${gl_bai}"
    echo -e "${gl_bufan}👤 用户名：${gl_lv}admin${gl_bai}"
    
    if [ -n "$QB_PASSWORD" ]; then
        echo -e "${gl_bufan}🔑 登录密码：${gl_lv}${QB_PASSWORD}${gl_bai}"
        echo -e "${gl_huang}⚠️  首次登录后会提示修改密码，请及时修改！${gl_bai}"
    else
        echo -e "${gl_huang}⚠️  未能自动提取密码，请手动执行：${gl_bai}"
        echo -e "    ${gl_bufan}docker logs ${DEFAULT_CONTAINER_NAME} | grep -i password${gl_bai}"
        echo -e "${gl_huang}   通常密码为随机字符串，或使用默认密码 adminadmin${gl_bai}"
    fi
    
    echo -e "${gl_zi}========================================${gl_bai}"
    echo -e "${gl_bufan}💡 查看实时日志：docker logs -f ${DEFAULT_CONTAINER_NAME}${gl_bai}"
    echo -e "${gl_bufan}💡 重启容器：docker restart ${DEFAULT_CONTAINER_NAME}${gl_bai}"
    echo -e "${gl_bufan}💡 停止容器：docker stop ${DEFAULT_CONTAINER_NAME}${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    break_end
}

deploy_app "$@"
