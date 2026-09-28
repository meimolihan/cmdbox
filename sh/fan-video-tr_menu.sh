
#!/bin/bash
set -uo pipefail

# ================== terminal colors ==================
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

# ================== customize me ==================
SERVICE="fan-video-tr"

INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-video-tr/main/scripts/install.sh"
UNINSTALL_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-video-tr/main/scripts/uninstall.sh"
# fan-video-tr 仓库未提供备份脚本，这里复用 cmdbox 通用目录备份脚本（源目录 备份目录 保留份数）
BACKUP_SCRIPT_URL="gitee.com/meimolihan/cmdbox/raw/master/sh/universal_backup.sh"

BACKUP_DIR="/vol2/1000/file/backup/fan-video-tr-backup"
BACKUP_KEEP="6"
DEFAULT_DATA_DIR="/var/lib/fan-video-tr/data"
RECORD_FILE="/etc/${SERVICE}.conf"
# ====================================================================

log_info() { echo -e "${gl_lan}[信息]${gl_bai} $*"; }
log_ok() { echo -e "${gl_lv}[成功]${gl_bai} $*"; }
log_warn() { echo -e "${gl_huang}[警告]${gl_bai} $*"; }
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

cancel_return() {
    local menu_name="${1:-退出脚本}"
    echo -ne "${gl_lv}即将返回 ${gl_huang}${menu_name} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
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

handle_y_n() {
    echo -ne "\r${gl_hong}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai}) ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.3
    echo -ne "\r${gl_huang}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai}) ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.3
    echo -ne "\r${gl_lv}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai}) ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo ""
    return 2
}

exit_animation() {
    echo -ne "\r${gl_lv}即将退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo ""
    clear
}

cancel_empty() {
    local menu_name="${1:-上一级选单}"
    echo -e "${gl_hong}空输入，返回 ${gl_huang}${menu_name} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
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

# 读取安装记录 /etc/fan-video-tr.conf 中的 KEY，缺失或为空时回退 fallback
get_record_value() {
    local key="$1"
    local fallback="$2"
    local value=""
    [ -f "${RECORD_FILE}" ] || { echo "${fallback}"; return 0; }
    value=$(grep -E "^${key}=" "${RECORD_FILE}" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '\r')
    if [ -n "${value}" ]; then
        echo "${value}"
    else
        echo "${fallback}"
    fi
}

show_service_url() {
    local service="${1:-fan-video-tr}"
    local url=""
    local port=""
    local ip
    ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    [ -z "$ip" ] && ip=$(ip route get 1 2>/dev/null | awk '{print $7}' | head -1)
    [ -z "$ip" ] && ip=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -1)
    [ -z "$ip" ] && ip="127.0.0.1"

    # 启动日志：fan-video-tr v1.0.0 启动成功，监听 :8790（数据目录: ...） / 已启动：http://127.0.0.1:8790
    port=$(journalctl -u "$service" --no-pager -n 200 -o cat 2>/dev/null \
        | grep -E '启动成功，监听 :[0-9]+|已启动：http://127\.0\.0\.1:[0-9]+' \
        | tail -1 | grep -oE ':[0-9]+' | head -1 | sed 's/^://')

    if [ -z "$port" ]; then
        port=$(get_record_value "PORT" "")
    fi

    if [ -z "$port" ]; then
        local exec_cmd
        exec_cmd=$(systemctl show -p ExecStart "$service" 2>/dev/null | cut -d= -f2-)
        port=$(echo "$exec_cmd" | grep -oE ' -{1,2}port[ =]+[0-9]+' | grep -oE '[0-9]+' | head -1)
    fi

    if [ -z "$port" ] && command -v ss >/dev/null 2>&1;then
        local pid
        pid=$(systemctl show -p MainPID "$service" 2>/dev/null | cut -d= -f2-)
        if [[ "$pid" =~ ^[0-9]+$ && "$pid" -gt 0 ]];then
            port=$(ss -tlnp 2>/dev/null | grep ",pid=$pid," | grep -oE ':[0-9]+' | sed 's/^://' | head -1)
        fi
    fi

    if [ -n "$port" ]; then
        url="http://${ip}:${port}"
    fi

    if [ -n "$url" ]; then
        echo -e "访问地址：${gl_lv}${url}${gl_bai}"
    else
        echo -e "访问地址：${gl_hong}无法获取访问地址${gl_bai}"
        return 1
    fi
}

show_service_status() {
    local service="${1:-fan-video-tr}"

    local version=""
    local ver_regex='\b(v[0-9]+\.[0-9]+\.[0-9]+|[0-9]+\.[0-9]+\.[0-9]+)\b'

    if command -v "$service" &>/dev/null; then
        version=$("$service" --version 2>/dev/null | grep -vE '[_#]{3,}' | grep -oE "$ver_regex" | head -1)
        [ -z "$version" ] && version=$("$service" version 2>/dev/null | grep -vE '[_#]{3,}' | grep -oE "$ver_regex" | head -1)
    fi

    if [ -z "$version" ]; then
        local exec_path
        exec_path=$(systemctl show -p ExecStart "$service" 2>/dev/null | cut -d= -f2 | awk '{print $1}')
        if [ -n "$exec_path" ] && [ -x "$exec_path" ]; then
            version=$("$exec_path" --version 2>/dev/null | grep -vE '[_#]{3,}' | grep -oE "$ver_regex" | head -1)
            [ -z "$version" ] && version=$("$exec_path" version 2>/dev/null | grep -vE '[_#]{3,}' | grep -oE "$ver_regex" | head -1)
        fi
    fi

    if [ -z "$version" ] && command -v journalctl &>/dev/null; then
        version=$(journalctl -u "$service" --no-pager -n 50 -o cat 2>/dev/null | grep -oE "$ver_regex" | head -1)
    fi

    if [[ ! "$version" =~ $ver_regex ]]; then
        version=""
    fi

    if systemctl is-active --quiet "$service"; then
        echo -e "运行状态：${gl_lv}$service 正在运行${gl_bai}"
    else
        echo -e "运行状态：${gl_hong}$service 未运行${gl_bai}"
    fi
    if [ -n "$version" ]; then
        echo -e "版本信息：${gl_huang}$version${gl_bai}"
    else
        echo -e "版本信息：${gl_huang}无法获取${gl_bai}"
    fi
}

# 备份数据目录：调用 cmdbox 通用备份脚本（tar.gz + 自动保留份数）
backup_data() {
    local service="${1:-fan-video-tr}"
    local data_dir
    data_dir=$(get_record_value "DATA_DIR" "${DEFAULT_DATA_DIR}")

    echo -e ""
    echo -e "${gl_zi}>>> 备份 fan-video-tr 数据 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_info "数据目录：${gl_huang}${data_dir}${gl_bai}"
    log_info "备份目录：${gl_huang}${BACKUP_DIR}${gl_bai}（保留 ${BACKUP_KEEP} 份）"

    if [ ! -d "${data_dir}" ]; then
        log_error "数据目录不存在：${data_dir}，请先安装并启动服务"
        return 1
    fi

    bash <(curl -sL ${BACKUP_SCRIPT_URL}) "${data_dir}" "${BACKUP_DIR}" "${BACKUP_KEEP}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_ok "转码成品体积较大，备份耗时取决于 output 目录大小"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
}

# 从最新备份恢复数据目录：原数据目录重命名保留，再解压覆盖后重启服务
recover_data() {
    local service="${1:-fan-video-tr}"
    local data_dir backup_file stamp keep_dir ans="N"
    data_dir=$(get_record_value "DATA_DIR" "${DEFAULT_DATA_DIR}")

    echo -e ""
    echo -e "${gl_zi}>>> 恢复 fan-video-tr 数据（最新备份）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if [ ! -d "${BACKUP_DIR}" ]; then
        log_error "备份目录不存在：${BACKUP_DIR}，请先执行 77 备份数据"
        return 1
    fi

    backup_file=$(ls -1t "${BACKUP_DIR}"/*.tar.gz 2>/dev/null | head -1)
    if [ -z "${backup_file}" ]; then
        log_error "未找到备份文件：${BACKUP_DIR}/*.tar.gz"
        return 1
    fi

    log_info "数据目录：${gl_huang}${data_dir}${gl_bai}"
    log_info "备份文件：${gl_huang}${backup_file}${gl_bai}（$(du -h "${backup_file}" 2>/dev/null | cut -f1)）"
    log_warn "恢复会覆盖现有数据，原数据目录将被重命名保留"

    read -r -p "$(echo -e "${gl_bai}确认恢复？输入 ${gl_lv}y${gl_bai} 确认，其余取消: ")" ans
    if [[ ! "$ans" =~ ^[Yy]$ ]]; then
        log_warn "已取消恢复"
        return 1
    fi

    sudo systemctl stop "${service}" >/dev/null 2>&1 || true
    sudo systemctl stop "${service}.service" >/dev/null 2>&1 || true

    stamp=$(date +%Y%m%d_%H%M%S)
    keep_dir="${data_dir}.bak.${stamp}"
    if [ -d "${data_dir}" ]; then
        if sudo mv "${data_dir}" "${keep_dir}" 2>/dev/null; then
            log_ok "原数据目录已保留为：${gl_huang}${keep_dir}${gl_bai}"
        else
            log_warn "重命名失败，改为清空数据目录后恢复"
            sudo mkdir -p "${data_dir}" && sudo find "${data_dir}" -mindepth 1 -delete
        fi
    fi

    if sudo tar -xzf "${backup_file}" -C "$(dirname "${data_dir}")"; then
        sudo mkdir -p "${data_dir}"
        sudo chmod 755 "${data_dir}" 2>/dev/null || true
        log_ok "数据已从备份恢复：${gl_huang}${data_dir}${gl_bai}"
    else
        log_error "解压失败，请手动恢复：sudo tar -xzf ${backup_file} -C $(dirname "${data_dir}")"
        sudo systemctl start "${service}" >/dev/null 2>&1 || true
        return 1
    fi

    sudo systemctl start "${service}" >/dev/null 2>&1 || true
    sleep 1
    sudo systemctl --no-pager status "${service}" 2>/dev/null | head -n 12 || true
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_ok "服务已重启，请确认转码任务与模板是否正常"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
}

manage_fan_video_tr() {
    while true; do
        clear
        echo -e ""
        echo -e "${gl_zi}>>> fan-video-tr 管理工具${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        show_service_status ${SERVICE}
        show_service_url ${SERVICE}
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}停止 fan-video-tr   ${gl_bufan}2.  ${gl_bai}启动 fan-video-tr"
        echo -e "${gl_bufan}3.  ${gl_bai}重启 fan-video-tr   ${gl_bufan}4.  ${gl_bai}查看服务状态"
        echo -e "${gl_bufan}5.  ${gl_bai}查看开机自启状态   ${gl_bufan}6.  ${gl_bai}开启开机自启"
        echo -e "${gl_bufan}7.  ${gl_bai}禁用开机自启       ${gl_bufan}8.  ${gl_bai}查看日志(100行)"
        echo -e "${gl_bufan}9.  ${gl_bai}实时跟踪日志       ${gl_bufan}10. ${gl_bai}查看转码能力/健康"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_lv}66. ${gl_bai}安装/升级 fan-video-tr  ${gl_huang}77. ${gl_bai}备份数据"
        echo -e "${gl_lv}88. ${gl_bai}恢复数据             ${gl_hong}99. ${gl_bai}卸载 fan-video-tr"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单       ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" action


        case "$action" in
        1)
            echo -e ""
            echo -e "${gl_zi}>>> 正在停止 fan-video-tr 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl stop ${SERVICE}
            log_ok "fan-video-tr 服务已停止（进行中的转码任务会中断）"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        2)
            echo -e ""
            echo -e "${gl_zi}>>> 正在启动 fan-video-tr 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl start ${SERVICE}
            log_ok "fan-video-tr 服务已启动"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        3)
            echo -e ""
            echo -e "${gl_zi}>>> 正在重启 fan-video-tr 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl restart ${SERVICE}
            log_ok "fan-video-tr 服务已重启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        4)
            echo -e ""
            echo -e "${gl_zi}>>> fan-video-tr 服务状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl status ${SERVICE}
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        5)
            echo -e ""
            echo -e "${gl_zi}>>> fan-video-tr 开机自启状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            local status=$(sudo systemctl is-enabled ${SERVICE} 2>/dev/null)
            case "$status" in
                enabled)   echo -e "${gl_lv}已启用${gl_bai}" ;;
                disabled)  echo -e "${gl_hong}已禁用${gl_bai}" ;;
                static)    echo "静态（非服务单元）" ;;
                indirect)  echo "间接（依赖其他单元）" ;;
                *)         echo "$status" ;;
            esac
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        6)
            echo -e ""
            echo -e "${gl_zi}>>> 正在开启 fan-video-tr 开机自启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl enable ${SERVICE}
            log_ok "已开启 fan-video-tr 开机自启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        7)
            echo -e ""
            echo -e "${gl_zi}>>> 正在禁用 fan-video-tr 开机自启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl disable ${SERVICE}
            log_ok "已禁用 fan-video-tr 开机自启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        8)
            echo -e ""
            echo -e "${gl_zi}>>> fan-video-tr 日志（最近100行）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo journalctl -u ${SERVICE} -n 100
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        9)
            echo -e ""
            echo -e "${gl_zi}>>> 实时跟踪 fan-video-tr 日志（按 Ctrl+C 退出）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo journalctl -u ${SERVICE} -f
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        10)
            echo -e ""
            echo -e "${gl_zi}>>> fan-video-tr 转码能力 / 健康检查 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            local port=""
            port=$(get_record_value "PORT" "8790")
            log_info "健康检查：${gl_huang}http://127.0.0.1:${port}/api/health${gl_bai}"
            curl -sS --max-time 5 "http://127.0.0.1:${port}/api/health" 2>/dev/null && echo "" || log_warn "健康检查无响应（服务未启动或端口不一致）"
            log_info "版本信息：${gl_huang}http://127.0.0.1:${port}/api/version${gl_bai}"
            curl -sS --max-time 5 "http://127.0.0.1:${port}/api/version" 2>/dev/null && echo "" || log_warn "无法获取版本信息"
            log_info "编码器 / 硬件加速：${gl_huang}http://127.0.0.1:${port}/api/capabilities${gl_bai}"
            curl -sS --max-time 8 "http://127.0.0.1:${port}/api/capabilities" 2>/dev/null && echo "" || log_warn "无法获取编码能力"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            log_info "启动日志中的「编码能力」一行可确认 NVENC/QSV/VAAPI 实际可用情况"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        66)
            bash -c "$(curl -sSL ${INSTALL_SCRIPT_URL})"
            break_end
            continue
            ;;
        77)
            backup_data ${SERVICE}
            break_end
            continue
            ;;
        88)
            recover_data ${SERVICE}
            break_end
            continue
            ;;
        99)
            bash <(curl -sSL ${UNINSTALL_SCRIPT_URL})
            break_end
            continue
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

manage_fan_video_tr
