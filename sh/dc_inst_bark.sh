#!/bin/bash
set -uo pipefail

DEFAULT_TITLE="Bark 推送服务 一键部署"
DEFAULT_COMPOSE_DIR="/vol1/1000/compose/bark"
DEFAULT_PORT="8380"
DEFAULT_CONTAINER_NAME="bark"
DEFAULT_IMAGE="finab/bark-server"
DEFAULT_CONTAINER_PORT="8080"

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
        echo -e "\n${gl_zi}>>> ROOT登录检查 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}提示: ${gl_bai}该功能需要root用户才能运行！"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return 1
    fi
    return 0
}

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n 1 -s -p ""
    echo ""
    clear
}

check_and_open_port() {
    local PORT="$1"
    [[ -z "$PORT" ]] && { log_error "未指定端口"; return 1; }
    log_info "检查端口 ${gl_huang}${PORT}${gl_bai} 是否放行 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    if iptables -L INPUT -n 2>/dev/null | grep -qE "dpt:${PORT}[[:space:]]|dpt:${PORT}$" 2>/dev/null; then
        log_ok "端口 ${PORT} 已放行，无需操作"
        return 0
    fi
    log_warn "端口 ${gl_hong}${PORT}${gl_bai} 未放行，正在开放 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    iptables -I INPUT -p tcp --dport "${PORT}" -j ACCEPT 2>/dev/null
    iptables -I INPUT -p udp --dport "${PORT}" -j ACCEPT 2>/dev/null
    if command -v iptables-save >/dev/null 2>&1; then
        mkdir -p /etc/iptables 2>/dev/null
        iptables-save > /etc/iptables/rules.v4 2>/dev/null
        command -v ip6tables-save >/dev/null 2>&1 && ip6tables-save > /etc/iptables/rules.v6 2>/dev/null
    fi
    return 0
}

install_docker_compose() {
    command -v docker compose >/dev/null 2>&1 || command -v docker-compose >/dev/null 2>&1 && return 0
    if command -v apt-get >/dev/null 2>&1; then apt-get update -y >/dev/null 2>&1 && apt-get install -y docker-compose-plugin >/dev/null 2>&1
    elif command -v yum >/dev/null 2>&1; then yum install -y docker-compose-plugin >/dev/null 2>&1
    elif command -v dnf >/dev/null 2>&1; then dnf install -y docker-compose-plugin >/dev/null 2>&1
    fi
    return 0
}

docker_compose_cmd() {
    if command -v docker compose >/dev/null 2>&1; then echo "docker compose"; else echo "docker-compose"; fi
}

parse_args() {
    local arg1="$1" arg2="$2" dir="" port=""
    if [[ -n "${arg1:-}" && "${arg1:-}" =~ ^[0-9]+$ ]]; then
        port="$arg1"
        [[ -n "${arg2:-}" && "${arg2:-}" =~ ^/ ]] && dir="$arg2"
    elif [[ -n "${arg1:-}" && "${arg1:-}" =~ ^/ ]]; then
        dir="$arg1"
        [[ -n "${arg2:-}" && "${arg2:-}" =~ ^[0-9]+$ ]] && port="$arg2"
    fi
    [[ -z "$port" ]] && port="$DEFAULT_PORT"
    [[ -z "$dir" ]] && dir="$DEFAULT_COMPOSE_DIR"
    echo "$dir $port"
}

main() {
    clear
    root_use || exit_script
    install_docker_compose
    local parsed dir port DCOM
    parsed=$(parse_args "${1:-}" "${2:-}")
    dir=$(echo "$parsed" | awk '{print $1}')
    port=$(echo "$parsed" | awk '{print $2}')
    [[ ! "$port" =~ ^[0-9]+$ ]] && { read -p "请输入端口 [默认: $DEFAULT_PORT]: " port; port=${port:-$DEFAULT_PORT}; }
    [[ -z "$dir" || "$dir" != /* ]] && { read -p "请输入部署目录 [默认: $DEFAULT_COMPOSE_DIR]: " dir; dir=${dir:-$DEFAULT_COMPOSE_DIR}; }
    echo ""
    log_info "部署信息预览"
    echo "----------------------------------------"
    echo "项目名称: $DEFAULT_TITLE"
    echo "容器名称: $DEFAULT_CONTAINER_NAME"
    echo "镜像地址: $DEFAULT_IMAGE"
    echo "部署目录: $dir"
    echo "访问端口: $port:$DEFAULT_CONTAINER_PORT"
    echo "数据目录: $dir/bark-data"
    echo "----------------------------------------"
    echo ""
    read -p "确认开始部署？ [Y/n]: " CONFIRM; CONFIRM=${CONFIRM:-Y}
    [[ ! "$CONFIRM" =~ ^[Yy]$ ]] && { log_warn "已取消部署"; exit_script; }
    check_and_open_port "$port"
    mkdir -p "$dir" "$dir/bark-data"
    log_info "生成 docker-compose.yml"
    cat > "$dir/docker-compose.yml" <<EOF
services:
  bark:
    image: ${DEFAULT_IMAGE}
    container_name: ${DEFAULT_CONTAINER_NAME}
    ports:
      - "${port}:${DEFAULT_CONTAINER_PORT}"
    volumes:
      - ./bark-data:/data
    restart: always
    tty: true
EOF
    log_ok "docker-compose.yml 已生成：$dir/docker-compose.yml"
    cd "$dir" || { log_error "无法进入目录 $dir"; exit_script; }
    DCOM=$(docker_compose_cmd)
    log_info "拉取镜像并启动服务"
    $DCOM pull >/dev/null 2>&1
    $DCOM up -d
    if [ $? -eq 0 ]; then
        echo ""
        log_ok "Bark 推送服务部署成功！"
        echo "----------------------------------------"
        echo "访问地址: http://$(hostname -I | awk '{print $1}'):$port"
        echo "本地访问: http://127.0.0.1:$port"
        echo "部署目录: $dir"
        echo "数据目录: $dir/bark-data"
        echo "容器名称: $DEFAULT_CONTAINER_NAME"
        echo "----------------------------------------"
        echo ""
        echo "常用命令："
        echo "  查看日志：cd $dir && $DCOM logs -f"
        echo "  重启服务：cd $dir && $DCOM restart"
        echo "  停止服务：cd $dir && $DCOM down"
        echo "  启动服务：cd $dir && $DCOM up -d"
        echo ""
    else
        log_error "部署失败，请查看日志排查问题"
        echo "排查命令: cd $dir && $DCOM logs"
    fi
    break_end
    exit_script
}

main "$@"
