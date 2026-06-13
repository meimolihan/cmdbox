#!/bin/bash

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

exit_script() {
    echo -ne "${gl_hong}感谢使用，再见！${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 1
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 1
    clear
    exit 0
}

open_new_browser_window() {
    local url="$1"
    if command -v google-chrome &>/dev/null; then
        setsid google-chrome --new-window "$url" >/dev/null 2>&1 &
    elif command -v microsoft-edge &>/dev/null; then
        setsid microsoft-edge --new-window "$url" >/dev/null 2>&1 &
    elif command -v firefox &>/dev/null; then
        setsid firefox --new-window "$url" >/dev/null 2>&1 &
    else
        setsid xdg-open "$url" >/dev/null 2>&1 &
    fi
    sleep_fractional 0.5
}

parse_args() {
    DEFAULT_NETWORK="10.10.10"
    DEFAULT_PORT="8080"
    NETWORK="$DEFAULT_NETWORK"
    PORT="$DEFAULT_PORT"

    if [ $# -eq 0 ]; then
        return
    elif [ $# -eq 1 ]; then
        if [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            NETWORK="$1"
        elif [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]; then
            PORT="$1"
        else
            log_warn "参数无效，使用默认配置"
        fi
    elif [ $# -eq 2 ]; then
        p1="$1"
        p2="$2"
        if [[ "$p1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && [[ "$p2" =~ ^[0-9]+$ ]]; then
            NETWORK="$p1"
            PORT="$p2"
        elif [[ "$p2" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && [[ "$p1" =~ ^[0-9]+$ ]]; then
            NETWORK="$p2"
            PORT="$p1"
        else
            log_warn "参数格式错误，使用默认配置"
        fi
    else
        log_warn "参数过多，使用默认配置"
    fi

    if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
        log_warn "端口无效，使用默认端口 8080"
        PORT="$DEFAULT_PORT"
    fi
}
parse_args "$@"

clear
echo -e "${gl_zi}>>> 洛雪音乐 lxserver 扫描${gl_bai}"
echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

log_info "当前配置：网段 ${gl_huang}${NETWORK}.0/24 ${gl_bai}| 端口 ${gl_lv}${PORT}${gl_bai}"
log_info "正在扫描 ${gl_huang}${NETWORK}.0/24 ${gl_bai}寻找 lxserver 服务（端口 ${gl_lv}${PORT}${gl_bai}）"

for i in {1..254}; do
    IP="${NETWORK}.${i}"
    if timeout 0.3 bash -c "echo > /dev/tcp/${IP}/${PORT}" 2>/dev/null; then
        log_ok "发现 lxserver 服务：${IP}:${PORT} 正在打开浏览器 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        
        open_new_browser_window "http://${IP}:${PORT}"
        
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_script
    fi
done

echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
log_info "未发现 lxserver 服务"
