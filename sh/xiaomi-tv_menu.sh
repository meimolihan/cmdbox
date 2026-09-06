#!/bin/bash
set -uo pipefail

gl_hui='\033[38;5;59m'
gl_hong='\033[38;5;9m'
gl_lv='\033[38;5;10m'
gl_huang='\033[38;5;11m'
gl_lan='\033[38;5;32m'
gl_bai='\033[38;5;15m'
gl_zi='\033[38;5;13m'
gl_bufan='\033[38;5;14m'

log_info()  { echo -e "${gl_lan}[信息]${gl_bai} $*${gl_bai}"; }
log_ok()    { echo -e "${gl_lv}[成功]${gl_bai} $*${gl_bai}"; }
log_warn()  { echo -e "${gl_huang}[警告]${gl_bai} $*${gl_bai}" >&2; }
log_error() { echo -e "${gl_hong}[错误]${gl_bai} $*${gl_bai}" >&2; }

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
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    read -r -n 1 -s -p ""
    echo ""
    clear
}

cancel_return() {
    local menu_name="${1:-上一级选单}"
    echo -e "${gl_lv}即将返回到 ${gl_huang}${menu_name}${gl_lv} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    sleep_fractional 0.6
    echo ""
    clear
}

handle_invalid_input() {
    echo -ne "\r\033[K${gl_huang}无效的输入,请重新输入! ${gl_zi} 1 ${gl_huang} 秒后返回"
    sleep_fractional 1
    echo -ne "\r\033[K${gl_lv}无效的输入,请重新输入! ${gl_zi}0${gl_lv} 秒后返回"
    sleep_fractional 0.5
    echo -ne "\r\033[K"
    return 2
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

monitor_status_show() {
    local SERVICE="monitor.service"
    local STATUS
    STATUS=$(systemctl status "$SERVICE" --no-pager --lines=5 2>/dev/null)
    if [ $? -ne 0 ]; then
        log_error "服务 ${SERVICE} 不存在或未安装"
        return 1
    fi

    local ACTIVE=$(echo "$STATUS" | awk '/Active:/ {print $2}')
    local STATE
    if [[ "$ACTIVE" == "active" ]]; then
        STATE="${gl_lv}运行中 ✅${gl_bai}"
    else
        STATE="${gl_hong}已停止 ❌${gl_bai}"
    fi

    local PID=$(echo "$STATUS" | awk '/Main PID:/ {print $3}')
    local MEM=$(echo "$STATUS" | awk '/Memory:/ {print $2}')
    local CPU=$(echo "$STATUS" | awk '/CPU:/ {print $2}')

    local LAST_LOG
    LAST_LOG=$(echo "$STATUS" | grep -E "^[[:space:]]*[A-Za-z]{3} [0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}" | tail -1 | sed 's/^[[:space:]]*//' | cut -d' ' -f4-)
    [[ -z "${LAST_LOG:-}" ]] && LAST_LOG="暂无日志输出"

    local TV_STATUS
    if echo "$LAST_LOG" | grep -q "电视上线\|检测到电视上线"; then
        TV_STATUS="${gl_lv}电视已上线 📺${gl_bai}"
    elif echo "$LAST_LOG" | grep -q "电视离线"; then
        TV_STATUS="${gl_huang}电视离线 💤${gl_bai}"
    elif echo "$LAST_LOG" | grep -q "启动成功"; then
        TV_STATUS="${gl_lv}APP 已启动 🚀${gl_bai}"
    elif echo "$LAST_LOG" | grep -q "启动失败\|请求失败"; then
        TV_STATUS="${gl_hong}启动失败 ❌${gl_bai}"
    else
        TV_STATUS="${gl_hui}未知状态${gl_bai}"
    fi

    echo ""
    echo -e "${gl_zi}>>> 电视自动启动监控服务状态${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}服务状态  : $STATE"
    echo -e "${gl_bai}主进程 PID: ${PID:-—}"
    echo -e "${gl_bai}内存占用  : ${MEM:-—}"
    echo -e "${gl_bai}CPU 耗时  : ${CPU:-—}"
    echo -e "${gl_bai}电视状态  : $TV_STATUS"
    echo -e "${gl_bai}最近活动  : ${LAST_LOG}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

check_dependencies() {
    if ! command -v androguard &>/dev/null && ! command -v aapt &>/dev/null; then
        log_warn "未检测到 androguard 或 aapt，尝试自动安装 androguard${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        if command -v apt &>/dev/null; then
            apt update && apt install androguard -y
            if [ $? -eq 0 ]; then
                log_ok "androguard 安装成功"
                return 0
            else
                log_error "apt 安装 androguard 失败，请手动安装"
                return 1
            fi
        else
            log_error "当前系统不是 Debian/Ubuntu，请手动安装 androguard 或 aapt"
            return 1
        fi
    fi
    return 0
}

extract_package_name() {
    local apk_path="$1"
    local pkg_name=""

    if command -v androguard &>/dev/null; then
        if command -v python3 &>/dev/null; then
            pkg_name=$(androguard apkid "${apk_path}" 2>/dev/null | python3 -c "import json,sys; data=json.load(sys.stdin); print(list(data.values())[0][0])" 2>/dev/null)
        else
            pkg_name=$(androguard apkid "${apk_path}" 2>/dev/null | grep -o '"[^"]*"' | head -1 | tr -d '"')
        fi
    elif command -v aapt &>/dev/null; then
        pkg_name=$(aapt dump badging "${apk_path}" 2>/dev/null | grep -E '^package:' | sed -n "s/.*name='\([^']*\)'.*/\1/p")
    fi

    echo "$pkg_name" | tr -d '\n\r'
}


monitor_install() {
    echo ""
    echo -e "${gl_zi}>>> 开始安装 monitor 监控服务${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if ! check_dependencies; then
        log_error "依赖安装失败，请手动安装 androguard 或 aapt"
        return 1
    fi

    local apk_path=""
    while true; do
        read -r -e -p "$(echo -e "${gl_bai}请输入APK完整路径: ")" apk_path
        apk_path="${apk_path// /}"
        if [[ -z "$apk_path" ]]; then
            log_warn "路径不能为空，请重新输入"
            continue
        fi
        if [[ ! -f "$apk_path" ]]; then
            log_error "文件不存在：${apk_path}"
            continue
        fi
        break
    done

    log_info "正在解析包名${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    local pkg_name=""
    pkg_name=$(extract_package_name "$apk_path")
    if [[ -z "$pkg_name" ]]; then
        log_warn "自动解析包名失败，请手动输入包名（例如 com.trim.tv）"
        read -r -e -p "$(echo -e "${gl_bai}请输入应用包名: ")" pkg_name
        pkg_name="${pkg_name// /}"
        if [[ -z "$pkg_name" ]]; then
            log_error "包名不能为空"
            return 1
        fi
    else
        log_ok "解析得到应用包名：${gl_lv}${pkg_name}${gl_bai}"
        echo -e "${gl_hui}如需修改，可在此输入新包名（直接回车使用自动提取的）${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}确认包名（直接回车使用）: ")" manual_pkg
        if [[ -n "$manual_pkg" ]]; then
            pkg_name="$manual_pkg"
            log_info "使用手动输入的包名：${gl_lv}${pkg_name}${gl_bai}"
        fi
    fi

    local tv_ip=""
    while true; do
        read -r -e -p "$(echo -e "${gl_bai}请输入电视IP地址: ")" tv_ip
        tv_ip="${tv_ip// /}"
        if [[ -z "$tv_ip" ]]; then
            log_warn "IP不能为空，请重新输入"
            continue
        fi
        break
    done
    log_ok "电视IP设置为：${gl_lv}${tv_ip}${gl_bai}"

    mkdir -p /opt/scripts
    log_info "生成 /opt/scripts/monitor.sh"
    cat > /opt/scripts/monitor.sh <<'EOF'
#!/bin/sh
# ============================================================
# Xiaomi TV Auto Start APP
# fnOS / Linux 常驻监控脚本
# ============================================================
# 配置区（可自行修改）
# ============================================================
TV_IP="__TV_IP__"
APP_PACKAGE="__PKG_NAME__"
CHECK_INTERVAL=5
TV_PORT=6095
START_APP_URL="http://${TV_IP}:${TV_PORT}/controller?action=startapp&&type=packagename&packagename=${APP_PACKAGE}"
# ============================================================
# 状态变量
# ============================================================
TV_ONLINE=0
APP_STARTED=0
# ============================================================
# 启动日志输出
# ============================================================
echo "========================================================"
echo "         Xiaomi TV Auto Start APP"
echo "========================================================"
echo
echo "TV IP       : ${TV_IP}"
echo "APP Package : ${APP_PACKAGE}"
echo "Check       : ${CHECK_INTERVAL} 秒"
echo "URL         : ${START_APP_URL}"
echo
echo "========================================================"
echo "开始监控 ..."
echo "按 Ctrl+C 停止。"
echo "========================================================"
echo
# ============================================================
# 依赖检测
# ============================================================
if ! command -v ping >/dev/null 2>&1; then
    echo "错误：系统中没有 ping 命令。"
    exit 1
fi
if ! command -v curl >/dev/null 2>&1; then
    echo "错误：系统中没有 curl 命令。"
    exit 1
fi
# ============================================================
# APP 启动函数
# ============================================================
start_app()
{
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 正在尝试启动 APP ..."
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 包名: ${APP_PACKAGE}"
    RESPONSE=$(curl \
        --silent \
        --show-error \
        --max-time 5 \
        "${START_APP_URL}" 2>/dev/null)
    CURL_RESULT=$?
    if [ ${CURL_RESULT} -ne 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 请求失败。5秒后重试。"
        return 1
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 请求发送成功。"
    echo "${RESPONSE}" | grep -qi "success"
    if [ $? -eq 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] APP 启动成功，本次开机不再重复启动。"
        APP_STARTED=1
        return 0
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] APP 未启动成功，返回内容: ${RESPONSE}"
        return 1
    fi
}
# ============================================================
# 主循环常驻监控
# ============================================================
while true
do
    ping -c 1 -W 1 "${TV_IP}" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        if [ "${TV_ONLINE}" -eq 1 ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] 电视离线，重置启动状态。"
            TV_ONLINE=0
            APP_STARTED=0
        fi
        sleep ${CHECK_INTERVAL}
        continue
    fi

    if [ "${TV_ONLINE}" -eq 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 检测到电视上线。"
        TV_ONLINE=1
    fi

    if [ "${APP_STARTED}" -eq 0 ]; then
        start_app
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 电视在线，APP 已启动。"
    fi

    sleep ${CHECK_INTERVAL}
done
EOF

    tv_ip_clean=$(echo "$tv_ip" | tr -d '\n\r')
    pkg_name_clean=$(echo "$pkg_name" | tr -d '\n\r')

    if ! sed -i "s|__TV_IP__|${tv_ip_clean}|g" /opt/scripts/monitor.sh 2>/dev/null; then
        log_error "替换 TV_IP 失败，请手动编辑 /opt/scripts/monitor.sh"
        return 1
    fi
    if ! sed -i "s|__PKG_NAME__|${pkg_name_clean}|g" /opt/scripts/monitor.sh 2>/dev/null; then
        log_error "替换 PKG_NAME 失败，请手动编辑 /opt/scripts/monitor.sh"
        return 1
    fi
    chmod +x /opt/scripts/monitor.sh

    log_info "生成 /etc/systemd/system/monitor.service"
    cat > /etc/systemd/system/monitor.service <<'EOF'
[Unit]
Description=TV App AutoStart Monitor
After=network.target

[Service]
Type=simple
ExecStart=/opt/scripts/monitor.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable monitor.service
    systemctl start monitor.service

    log_ok "monitor.service 安装完成，已设置开机自启并启动服务"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    return 0
}

monitor_simple_status() {
    local SERVICE="monitor.service"
    local STATUS_OUT
    STATUS_OUT=$(systemctl status "$SERVICE" --no-pager --lines=0 2>/dev/null)
    if [ $? -ne 0 ]; then
        log_error "服务 ${SERVICE} 不存在或未安装"
        return 1
    fi

    local ACTIVE=$(echo "$STATUS_OUT" | awk '/Active:/ {print $2}')
    local STATE
    if [[ "$ACTIVE" == "active" ]]; then
        STATE="${gl_lv}运行中 ✅${gl_bai}"
    else
        STATE="${gl_hong}已停止 ❌${gl_bai}"
    fi


    local LOG_LINES
    LOG_LINES=$(journalctl -u "${SERVICE}" --no-pager -n 10 -o cat 2>/dev/null | tac 2>/dev/null || tail -r 2>/dev/null)
    if [[ -z "$LOG_LINES" ]]; then
        LOG_LINES=$(systemctl status "$SERVICE" --no-pager --lines=10 2>/dev/null | grep -E "^[[:space:]]*[A-Za-z]{3} [0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}" | sed 's/^[[:space:]]*//' | cut -d' ' -f4- | tac 2>/dev/null || tail -r 2>/dev/null)
    fi

    local LAST_LOG=""
    local TV_STATUS="${gl_hui}暂无有效状态 ⚠️${gl_bai}"


    if [[ -n "$LOG_LINES" ]]; then
        while IFS= read -r line; do
            if [[ -z "$line" ]]; then continue; fi

            if echo "$line" | grep -qE "电视上线|检测到电视上线|电视在线"; then
                TV_STATUS="${gl_lv}电视已上线 📺${gl_bai}"
                LAST_LOG="$line"
                break
            fi

            if echo "$line" | grep -q "电视离线"; then
                TV_STATUS="${gl_huang}电视离线 💤${gl_bai}"
                LAST_LOG="$line"
                break
            fi

            if echo "$line" | grep -qE "启动成功|APP 已启动"; then
                TV_STATUS="${gl_lv}APP 已启动 🚀${gl_bai}"
                LAST_LOG="$line"
                break
            fi

            if echo "$line" | grep -qE "启动失败|请求失败"; then
                TV_STATUS="${gl_hong}启动失败 ❌${gl_bai}"
                LAST_LOG="$line"
                break
            fi
        done <<< "$LOG_LINES"
    fi

    if [[ -z "$LAST_LOG" && -n "$LOG_LINES" ]]; then
        LAST_LOG=$(echo "$LOG_LINES" | head -n1)
        TV_STATUS="${gl_hui}最近日志: ${LAST_LOG}${gl_bai}"
    fi

    echo -e "${gl_bai}服务状态 : $STATE"
    echo -e "${gl_bai}电视状态 : $TV_STATUS"
    if [[ -n "$LAST_LOG" ]]; then
        echo -e "${gl_hui}最新活动 : ${LAST_LOG}${gl_bai}"
    fi
}

monitor_menu() {
    while true; do
        clear
        echo -e "${gl_zi}>>> TV monitor 服务管理${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        monitor_simple_status
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}停止 monitor           ${gl_bufan}2.  ${gl_bai}启动 monitor"
        echo -e "${gl_bufan}3.  ${gl_bai}重启 monitor           ${gl_bufan}4.  ${gl_bai}查看服务状态"
        echo -e "${gl_bufan}5.  ${gl_bai}查看开机自启状态       ${gl_bufan}6.  ${gl_bai}禁用开机自启"
        echo -e "${gl_bufan}7.  ${gl_bai}查看日志               ${gl_bufan}8.  ${gl_bai}实时跟踪日志"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_lv}66. ${gl_bai}安装 monitor           ${gl_hong}99. ${gl_bai}卸载 monitor 全套"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单         ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" action

        case "$action" in
        1)
            echo ""
            echo -e "${gl_zi}>>> 停止 monitor${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            log_info "正在停止 monitor.service"
            systemctl stop monitor.service 2>/dev/null
            log_ok "monitor.service 已停止"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        2)
            echo ""
            echo -e "${gl_zi}>>> 启动 monitor${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            log_info "正在启动 monitor.service"
            systemctl start monitor.service 2>/dev/null
            log_ok "monitor.service 已启动"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        3)
            echo ""
            echo -e "${gl_zi}>>> 重启 monitor${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            log_info "正在重启 monitor.service"
            systemctl restart monitor.service 2>/dev/null
            log_ok "monitor.service 已重启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        4)
            monitor_status_show
            ;;
        5)
            echo ""
            echo -e "${gl_zi}>>> monitor 开机自启状态${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            local ena_stat=$(systemctl is-enabled monitor.service 2>/dev/null || echo "未安装")
            case "$ena_stat" in
                enabled)   echo -e "${gl_lv}已启用${gl_bai}" ;;
                disabled)  echo -e "${gl_huang}已禁用${gl_bai}" ;;
                static)    echo -e "${gl_hui}静态单元${gl_bai}" ;;
                indirect)  echo -e "${gl_hui}间接依赖${gl_bai}" ;;
                *)         echo "$ena_stat" ;;
            esac
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        6)
            echo ""
            echo -e "${gl_zi}>>> 禁用 monitor 开机自启${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            log_info "正在禁用 monitor 开机自启"
            systemctl disable monitor.service 2>/dev/null
            log_ok "已禁用 monitor 开机自启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        7)
            echo ""
            echo -e "${gl_zi}>>> monitor 日志（最近100行）${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            journalctl -u monitor.service -n 100
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        8)
            echo ""
            echo -e "${gl_zi}>>> 实时跟踪日志（按 Ctrl+C 返回）${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            journalctl -u monitor.service -f
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        66)
            monitor_install
            break_end
            ;;
        99)
            echo ""
            echo -e "${gl_zi}>>> 彻底卸载 monitor.service${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bai}即将彻底卸载 monitor.service，确认继续？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" ans
            if [[ "${ans,,}" == "y" ]]; then
                systemctl stop monitor.service 2>/dev/null
                systemctl disable monitor.service 2>/dev/null
                rm -f /etc/systemd/system/monitor.service
                systemctl daemon-reload
                rm -f /opt/scripts/monitor.sh
                rmdir /opt/scripts 2>/dev/null
                log_ok "monitor.service 全套卸载完成"
            else
                log_info "已取消卸载"
            fi
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        0)
            cancel_return "已是主菜单"
            continue
            ;;
        00 | 000 | 0000)
            exit_script
            ;;
        *)
            handle_invalid_input
            ;;
        esac
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    monitor_menu
fi