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

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n 1 -s -r -p ""
    echo ""
}

exit_animation() {
    echo -ne "${gl_lv}即将退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo ""
    clear
}

query_github_dns() {
    echo -e "${gl_zi}>>> 查询 GitHub 域名解析 IP${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_info "使用 223.5.5.5 阿里DNS解析"
    nslookup github.com 223.5.5.5
    echo ""
    log_info "使用 114.114.114.114 公共DNS解析"
    nslookup github.com 114.114.114.114
}

test_github_ip() {
    echo -e "${gl_huang}>>> 批量测试 GitHub IP 可用性${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    local ip_list=("140.82.112.3" "140.82.112.4" "185.199.108.153" "20.205.243.166")
    for ip in "${ip_list[@]}"; do
        log_info "正在测试节点：$ip"
        timeout 3 curl -sI -o /dev/null -w "%{http_code} %{time_total}s\n" \
            --connect-timeout 2 "https://$ip" -H "Host: github.com" -k
    done
    echo -e ""
}

config_github_hosts() {
    echo -e "${gl_huang}>>> 清理并配置 /etc/hosts${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if [ "$(id -u)" -ne 0 ]; then
        log_error "修改 hosts 需要 root 权限，请使用 sudo 执行脚本"
        return 1
    fi

    log_info "查看当前 hosts 内 github 相关条目"
    grep -n "github" /etc/hosts || log_info "未发现原有 github 条目"

    log_info "清理所有 github 相关 hosts 记录"
    sed -i '/github/d' /etc/hosts

    local best_ip="140.82.112.3"
    log_info "写入最优解析 IP：${best_ip}"
    echo "${best_ip} github.com" >> /etc/hosts

    log_info "验证最终解析结果"
    getent hosts github.com

    log_ok "GitHub hosts 配置完成"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    return 0
}

#  Ping 测试函数，美化延迟展示
ping_github_check() {
    echo -e "${gl_lan}>>> 最终连通性&延迟测试${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    local ping_result=$(ping -c 3 github.com 2>/dev/null)
    if echo "$ping_result" | grep -q "0% packet loss"; then
        local rtt=$(echo "$ping_result" | awk '/rtt/ {print $4}')
        local min_lat=$(echo "$rtt" | cut -d'/' -f1)
        local avg_lat=$(echo "$rtt" | cut -d'/' -f2)
        local max_lat=$(echo "$rtt" | cut -d'/' -f3)
        
        log_ok "网络连通正常"
        echo -e "${gl_huang}最小延迟: ${gl_bai}${min_lat} ms"
        echo -e "${gl_huang}平均延迟: ${gl_bai}${avg_lat} ms"
        echo -e "${gl_huang}最大延迟: ${gl_bai}${max_lat} ms"
    else
        log_error "网络连通异常，存在丢包/请求超时"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
}

main() {
    clear
    query_github_dns
    test_github_ip
    config_github_hosts
    ping_github_check
    break_end
}

main