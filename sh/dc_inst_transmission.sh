#!/bin/bash
set -uo pipefail

# ====================== 【可自定义配置区】 在这里修改所有默认参数 ======================
# 项目标题
DEFAULT_TITLE="Transmission 下载工具 一键部署"

# 部署目录（不传参时的默认路径）
DEFAULT_COMPOSE_DIR="/vol1/1000/compose/transmission"

# 默认 Web 访问端口（不传参时使用），映射容器 9091
DEFAULT_PORT="9091"

# 默认容器名称（可自定义）
DEFAULT_CONTAINER_NAME="transmission"

# 默认用户名
DEFAULT_USERNAME="admin"

# 默认密码
DEFAULT_PASSWORD="12345678"
# ====================================================================================

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

    log_info "检查端口 ${gl_huang}${PORT}${gl_bai} 是否放行 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

    # 检查端口是否已放行
    if iptables -L INPUT -n 2>/dev/null | grep -qE "dpt:${PORT}[[:space:]]|dpt:${PORT}$" 2>/dev/null; then
        log_ok "端口 ${PORT} 已放行，无需操作"
        return 0
    fi

    log_warn "端口 ${gl_hong}${PORT}${gl_bai} 未放行，正在开放 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

    # 开放端口
    iptables -I INPUT -p tcp --dport "${PORT}" -j ACCEPT 2>/dev/null
    iptables -I INPUT -p udp --dport "${PORT}" -j ACCEPT 2>/dev/null

    log_info "保存防火墙规则 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

    # 方法1: 使用 iptables-save 保存到文件（最可靠，不会卡住）
    local SAVED=0
    if command -v iptables-save >/dev/null 2>&1; then
        mkdir -p /etc/iptables 2>/dev/null
        if iptables-save > /etc/iptables/rules.v4 2>/dev/null; then
            log_ok "IPv4 规则已保存到 /etc/iptables/rules.v4"
            SAVED=1
        fi
        if command -v ip6tables-save >/dev/null 2>&1; then
            ip6tables-save > /etc/iptables/rules.v6 2>/dev/null
        fi
    fi

    # 方法2: 尝试使用 netfilter-persistent（带超时，避免卡住）
    if command -v netfilter-persistent >/dev/null 2>&1; then
        log_info "尝试 netfilter-persistent 保存..."
        (
            timeout 5 netfilter-persistent save >/dev/null 2>&1
        ) &
        local SAVE_PID=$!
        local WAIT=0
        while kill -0 $SAVE_PID 2>/dev/null && [ $WAIT -lt 6 ]; do
            sleep 1
            WAIT=$((WAIT + 1))
        done
        if kill -0 $SAVE_PID 2>/dev/null; then
            kill -9 $SAVE_PID 2>/dev/null
            log_warn "netfilter-persistent 保存超时，已跳过"
        else
            wait $SAVE_PID 2>/dev/null
            if [ $? -eq 0 ]; then
                log_ok "netfilter-persistent 保存成功"
                SAVED=1
            fi
        fi
    fi

    # 方法3: 尝试使用 service iptables save（带超时）
    if [ $SAVED -eq 0 ] && command -v service >/dev/null 2>&1; then
        if service iptables status >/dev/null 2>&1; then
            log_info "尝试 service iptables save..."
            (
                timeout 5 service iptables save >/dev/null 2>&1
            ) &
            local SAVE_PID=$!
            local WAIT=0
            while kill -0 $SAVE_PID 2>/dev/null && [ $WAIT -lt 6 ]; do
                sleep 1
                WAIT=$((WAIT + 1))
            done
            if kill -0 $SAVE_PID 2>/dev/null; then
                kill -9 $SAVE_PID 2>/dev/null
                log_warn "service iptables save 超时"
            else
                wait $SAVE_PID 2>/dev/null
                if [ $? -eq 0 ]; then
                    log_ok "service iptables save 成功"
                    SAVED=1
                fi
            fi
        fi
    fi

    # 方法4: 尝试使用 iptables-persistent（Debian/Ubuntu）
    if [ $SAVED -eq 0 ] && command -v iptables-save >/dev/null 2>&1 && [ -f /etc/iptables/rules.v4 ]; then
        log_info "iptables 规则已通过文件备份: /etc/iptables/rules.v4"
        log_info "重启后如需恢复规则，可执行: iptables-restore < /etc/iptables/rules.v4"
        SAVED=1
    fi

    if [ $SAVED -eq 0 ]; then
        log_warn "无法自动持久化保存规则，但端口已临时开放"
        log_info "如需永久保存，请手动执行: iptables-save > /etc/iptables/rules.v4"
    fi

    log_ok "端口 ${gl_lv}${PORT}${gl_bai} 已开放"
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

        if [ -n "$filter_name" ]; then
            docker_filter="--filter name=${filter_name}"
        fi

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

            gsub(/ years ago/, "年前", time)
            gsub(/ year ago/, "年前", time)
            gsub(/ months ago/, "个月前", time)
            gsub(/ month ago/, "个月前", time)
            gsub(/ weeks ago/, "周前", time)
            gsub(/ week ago/, "周前", time)
            gsub(/ days ago/, "天前", time)
            gsub(/ day ago/, "天前", time)
            gsub(/ hours ago/, "小时前", time)
            gsub(/ hour ago/, "小时前", time)
            gsub(/ minutes ago/, "分钟前", time)
            gsub(/ minute ago/, "分钟前", time)
            gsub(/ seconds ago/, "秒前", time)
            gsub(/ second ago/, "秒前", time)
            gsub(/About /, "", time)

            print cyan id reset, green name reset, yellow status reset, blue ports reset, white time reset, gl_bai image reset
        }'
    } | column_if_available
}

docker_check_env() {
    if ! command -v docker &>/dev/null; then
        log_info "正在检查 Docker 运行环境 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        log_warn "Docker 未安装，即将自动安装 Docker 环境 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        bash <(curl -sL gitee.com/meimolihan/cmdbox/raw/master/sh/linux_docker.sh)

        if ! command -v docker &>/dev/null; then
            log_error "Docker 安装失败，请手动安装后重试！"
            sleep 1
            exit 1
        fi
        log_ok "Docker 安装成功！"
    fi

    if ! command -v docker-compose &>/dev/null && ! docker compose version &>/dev/null; then
        echo -e ""
        log_info "正在检查 Docker Compose 环境 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        log_warn "Docker Compose 未安装，即将自动安装 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        bash <(curl -sL gitee.com/meimolihan/cmdbox/raw/master/sh/linux_compose.sh)

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
}

deploy_app() {
    local COMPOSE_DIR="$DEFAULT_COMPOSE_DIR"
    local HOST_PORT="$DEFAULT_PORT"

    root_use || return 1
    clear
    echo -e "${gl_zi}>>> ${DEFAULT_TITLE}${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    docker_check_env

    log_info "部署目录：${gl_huang}${COMPOSE_DIR}${gl_bai}"
    mkdir -p "${COMPOSE_DIR}" || { log_error "目录创建失败"; break_end; return 1; }
    cd "${COMPOSE_DIR}" || { log_error "进入目录失败"; break_end; return 1; }

    log_info "使用 Web 端口：${gl_lv}${HOST_PORT}${gl_bai}"

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
    check_and_open_port "51413"
    
    # 停止并删除旧容器
    echo -e ""
    echo -e "${gl_huang}>>> 停止并删除旧容器${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    if docker ps -a --filter "name=^/${DEFAULT_CONTAINER_NAME}$" --format "{{.Names}}" | grep -q "^${DEFAULT_CONTAINER_NAME}$"; then
        docker-compose down 2>/dev/null || docker compose down 2>/dev/null
        docker rm -f "${DEFAULT_CONTAINER_NAME}" >/dev/null 2>&1
        log_ok "旧容器已删除"
    fi

    # 创建必要的目录
    mkdir -p transmission/config
    mkdir -p transmission/watch

    # 下载中文界面
    echo -e ""
    echo -e "${gl_huang}>>> 下载中文 Web 控制界面${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    rm -rf transmission-web-control
    log_info "正在从 GitHub 下载 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    git clone https://github.com/ronggang/transmission-web-control.git 2>/dev/null
    
    if [ ! -d "transmission-web-control" ]; then
        log_warn "GitHub 下载失败，尝试使用 Gitee 备用源 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        git clone https://gitee.com/culturist/transmission-web-control.git 2>/dev/null
    fi
    
    if [ -d "transmission-web-control/src" ]; then
        log_ok "中文界面下载成功"
    else
        log_warn "中文界面下载失败，将使用原版界面"
    fi

    echo -e ""
    echo -e "${gl_huang}>>> 生成 ${gl_lv}docker-compose.yml${gl_huang} 文件${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    # 生成 docker-compose.yml（默认包含中文界面）
    cat > docker-compose.yml << EOF
services:
   ${DEFAULT_CONTAINER_NAME}:
      image: linuxserver/transmission:latest
      container_name: ${DEFAULT_CONTAINER_NAME}
      network_mode: bridge
      restart: unless-stopped
      environment:
         - PUID=1000
         - PGID=1000
         - TZ=Asia/Shanghai
         - USER=${DEFAULT_USERNAME}
         - PASS=${DEFAULT_PASSWORD}
         - TRANSMISSION_WEB_HOME=/web-control/src
      ports:
         - ${HOST_PORT}:9091
         - 51413:51413
         - 51413:51413/udp
      volumes:
         - ./transmission/config:/config
         - ./transmission/watch:/watch
         - ./transmission-web-control:/web-control
EOF

    if [ -f "docker-compose.yml" ]; then
        log_ok "配置文件创建成功"
    else
        log_error "配置文件创建失败"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return 1
    fi

    # 启动容器
    echo -e ""
    echo -e "${gl_huang}>>> 启动容器 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    START_SUCCESS=false
    if command -v docker-compose &>/dev/null; then
        if docker-compose up -d; then
            START_SUCCESS=true
        fi
    fi
    
    if [ "$START_SUCCESS" = false ]; then
        if docker compose up -d; then
            START_SUCCESS=true
        fi
    fi
    
    if [ "$START_SUCCESS" = false ]; then
        log_error "容器启动失败"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return 1
    fi
    
    log_ok "容器启动成功"

    # 显示容器状态
    echo -e ""
    echo -e "${gl_huang}>>> 容器运行状态${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    docker-ps-cn ${DEFAULT_CONTAINER_NAME}
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    # 显示访问信息
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    echo ""
    log_info "========================================部署完成！"
    log_info "访问地址：${gl_lv}http://${LOCAL_IP}:${HOST_PORT}${gl_bai}"
    log_info "默认用户名：${gl_lv}${DEFAULT_USERNAME}${gl_bai}"
    log_info "默认密码：${gl_lv}${DEFAULT_PASSWORD}${gl_bai}"
    log_info "部署目录：${gl_huang}${COMPOSE_DIR}${gl_bai}"
    
    if [ -d "transmission-web-control/src" ]; then
        log_ok "已安装中文 Web 控制界面"
        log_info "如果界面显示英文，请按 ${gl_lv}Ctrl+F5${gl_bai} 强制刷新浏览器"
    else
        log_info "使用原版 Web 界面"
    fi
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

deploy_app
