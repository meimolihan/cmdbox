#!/bin/bash
set -uo pipefail

# ====================== 【可自定义配置区】 ======================
DEFAULT_TITLE="Stirling PDF PDF 处理工具 一键部署"
DEFAULT_COMPOSE_DIR="/vol1/1000/compose/stirling-pdf"
DEFAULT_PORT="8080"
DEFAULT_CONTAINER_NAME="stirling-pdf"
# ===============================================================

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
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local dots=("${gl_hong}." "${gl_huang}." "${gl_lv}." "${gl_bufan}." "${gl_zi}.")
    local dot_buffer="" frame_len=${#frames[@]} local dot_idx=0 local total_dots=${#dots[@]}
    for ((i=0;i<20;i++)); do
        if (( i > 0 && i % 3 == 0 && dot_idx < total_dots )); then dot_buffer+=${dots[$dot_idx]}; ((dot_idx++)); fi
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
    if [[ -z "$PORT" ]]; then log_error "未指定端口"; return 1; fi
    log_info "检查端口 ${gl_huang}${PORT}${gl_bai} 是否放行 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    if iptables -L INPUT -n 2>/dev/null | grep -qE "dpt:${PORT}[[:space:]]|dpt:${PORT}$" 2>/dev/null; then
        log_ok "端口 ${PORT} 已放行，无需操作"; return 0
    fi
    log_warn "端口 ${gl_hong}${PORT}${gl_bai} 未放行，正在开放 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    iptables -I INPUT -p tcp --dport "${PORT}" -j ACCEPT 2>/dev/null
    log_info "保存防火墙规则 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    if command -v iptables-save >/dev/null 2>&1; then
        mkdir -p /etc/iptables 2>/dev/null
        iptables-save > /etc/iptables/rules.v4 2>/dev/null && log_ok "IPv4 规则已保存到 /etc/iptables/rules.v4"
    fi
    log_ok "端口 ${gl_lv}${PORT}${gl_bai} 已开放"
}

check_port_available() {
    local PORT="$1"
    ss -tuln | grep -q ":${PORT} " && return 1
    netstat -tuln 2>/dev/null | grep -q ":${PORT} " && return 1
    return 0
}

get_free_port() {
    local start_port=$1 port=$start_port
    while ! check_port_available $port; do port=$((port+1)); if [ $port -gt $((start_port+100)) ]; then echo ""; return 1; fi; done
    echo $port
}

clean_old_container() {
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
}

docker_check_env() {
    if ! command -v docker &>/dev/null; then
        log_info "正在检查 Docker 运行环境 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        log_warn "Docker 未安装，即将自动安装 Docker 环境"
        bash <(curl -sSL gitee.com/meimolihan/cmdbox/raw/master/sh/lx_install_docker.sh)
        if ! command -v docker &>/dev/null; then log_error "Docker 安装失败，请手动安装后重试！"; sleep 1; exit 1; fi
        log_ok "Docker 安装成功！"
    fi
    if ! command -v docker-compose &>/dev/null && ! docker compose version &>/dev/null; then
        log_info "正在检查 Docker Compose 环境 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        log_warn "Docker Compose 未安装，即将自动安装"
        bash <(curl -sSL gitee.com/meimolihan/cmdbox/raw/master/sh/lx_install_compose.sh)
        if ! command -v docker-compose &>/dev/null && ! docker compose version &>/dev/null; then log_error "Docker Compose 安装失败，请手动安装后重试！"; sleep 1; exit 1; fi
        log_ok "Docker Compose 安装成功！"
    fi
}

deploy_app() {
    local COMPOSE_DIR="" PORT=""
    root_use || return 1
    clear
    echo -e "${gl_zi}>>> ${DEFAULT_TITLE}${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    docker_check_env
    for arg in "$@"; do
        if [[ "$arg" =~ ^[0-9]+$ ]]; then [ -z "$PORT" ] && PORT="$arg"; else COMPOSE_DIR="$arg"; fi
    done
    [ -z "$PORT" ] && PORT="$DEFAULT_PORT"
    if [ -z "${COMPOSE_DIR}" ]; then
        read -r -e -p "${gl_bai}请输入 docker-compose 存放路径（回车默认：${gl_huang}${DEFAULT_COMPOSE_DIR}${gl_bai}）(${gl_hong}0${gl_bai} 退出安装）：" input_dir
        COMPOSE_DIR=${input_dir:-$DEFAULT_COMPOSE_DIR}
    fi
    if [ "$COMPOSE_DIR" = "0" ]; then exit_script; return 1; fi
    log_info "部署目录：${gl_huang}${COMPOSE_DIR}${gl_bai}"
    mkdir -p "${COMPOSE_DIR}" || { log_error "目录创建失败"; break_end; return 1; }
    cd "${COMPOSE_DIR}" || { log_error "进入目录失败"; break_end; return 1; }
    if [ -z "${PORT}" ]; then
        read -r -e -p "${gl_bai}请输入 Stirling PDF 访问端口（回车默认：${gl_huang}${DEFAULT_PORT}${gl_bai}）(${gl_hong}0${gl_bai} 退出安装）：" input_port
        PORT=${input_port:-$DEFAULT_PORT}
    fi
    if [ "$PORT" = "0" ]; then exit_script; rm -rf "${COMPOSE_DIR}"; return 1; fi
    if ! check_port_available $PORT; then
        log_warn "端口 ${gl_hong}${PORT}${gl_bai} 已被占用"
        NEW_PORT=$(get_free_port $((PORT+1)))
        if [ -n "$NEW_PORT" ]; then log_info "自动分配新端口：${gl_lv}${NEW_PORT}${gl_bai}"; PORT=$NEW_PORT; else log_error "无法找到可用端口，请手动指定"; break_end; return 1; fi
    fi
    check_and_open_port "${PORT}"
    clean_old_container "${DEFAULT_CONTAINER_NAME}"

    mkdir -p config trainData

    cat > docker-compose.yml << COMPOSE_EOF
version: "3.8"
services:
  stirling-pdf:
    container_name: stirling-pdf
    image: frooodle/s-pdf:latest
    restart: unless-stopped
    ports:
      - "${PORT}:8080"
    volumes:
      - ./config:/config
      - ./trainData:/usr/share/tesseract-ocr/5/tessdata
    environment:
      - TZ=Asia/Shanghai
      - LANGS=eng,chi_sim
      - DISABLE_TESSERACT_UPDATE=true
COMPOSE_EOF

    if docker-compose up -d; then
        log_ok "容器启动成功"
    elif docker compose up -d; then
        log_ok "容器启动成功"
    else
        log_error "容器启动失败"; break_end; return 1
    fi

    echo -e ""
    echo -e "${gl_huang}>>> 容器运行状态${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    docker ps --filter "name=stirling-pdf" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    log_info "部署完成！"
    log_info "Stirling PDF 访问地址：${gl_lv}http://${LOCAL_IP}:${PORT}${gl_bai}"
    log_info "部署目录：${gl_huang}${COMPOSE_DIR}${gl_bai}"
    echo -e ""
    log_info "支持 PDF 合并、拆分、转换、压缩、水印等操作，所有处理均在本地完成。"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

deploy_app "$@"
