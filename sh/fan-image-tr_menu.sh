
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

# ================== 【可自定义配置区】 ==================
SERVICE="fan-image-tr"
SERVICE_USER="fit"
INSTALL_BIN="/usr/local/bin/fan-image-tr"
UNIT_FILE="/etc/systemd/system/${SERVICE}.service"
ENV_FILE_DIR="/etc/${SERVICE}"
DEFAULT_PORT="8791"
DEFAULT_DATA_DIR="/var/lib/fan-image-tr"
DEFAULT_MEDIA_DIR="/srv/photos"
DEFAULT_WORKER="2"
BACKUP_DIR="/vol2/1000/file/backup/fan-image-tr-backup"
BACKUP_KEEP="6"
REPO_URL="https://github.com/meimolihan/fan-image-tr"
RELEASE_URL="https://github.com/meimolihan/${SERVICE}/releases/latest/download"
# ====================================================

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

get_local_ip() {
    local ip
    ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    [ -z "$ip" ] && ip=$(ip route get 1 2>/dev/null | awk '{print $7}' | head -1)
    [ -z "$ip" ] && ip=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -1)
    [ -z "$ip" ] && ip="127.0.0.1"
    echo "$ip"
}

detect_arch() {
    case "$(uname -m 2>/dev/null)" in
        x86_64 | amd64)  echo "amd64" ;;
        aarch64 | arm64) echo "arm64" ;;
        *)               echo "amd64" ;;
    esac
}

show_service_url() {
    local service="${1:-fan-image-tr}"
    local url=""
    local port=""
    local ip
    ip=$(get_local_ip)

    # 1. 优先从 unit 的 FIT_APP_PORT 环境变量取端口
    port=$(systemctl show -p Environment --value "$service" 2>/dev/null \
        | grep -oE 'FIT_APP_PORT=[0-9]+' | grep -oE '[0-9]+' | head -1)

    # 2. 回退：解析启动日志里打印的“已启动: http://127.0.0.1:端口”
    if [ -z "$port" ];then
        port=$(journalctl -u "$service" --no-pager -n 300 -o cat 2>/dev/null \
            | grep -oE '已启动: http://127\.0\.0\.1:[0-9]+' | grep -oE '[0-9]+$' | tail -1)
    fi

    # 3. 回退：解析 ExecStart 上的 -port 参数
    if [ -z "$port" ];then
        local exec_cmd
        exec_cmd=$(systemctl show -p ExecStart "$service" 2>/dev/null | cut -d= -f2-)
        port=$(echo "$exec_cmd" | grep -oE ' -{1,2}port[ =]+[0-9]+' | grep -oE '[0-9]+' | head -1)
    fi

    # 4. 回退：按 MainPID 找监听端口
    if [ -z "$port" ] && command -v ss >/dev/null 2>&1;then
        local pid
        pid=$(systemctl show -p MainPID "$service" 2>/dev/null | cut -d= -f2)
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
    local service="${1:-fan-image-tr}"

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

# ================== 安装 / 卸载 / 备份 / 恢复 ==================

# install_ffmpeg 安装 ffmpeg 与 ffprobe（项目运行强依赖）
install_ffmpeg() {
    if command -v ffmpeg &>/dev/null && command -v ffprobe &>/dev/null; then
        log_ok "FFmpeg 环境已就绪：$(ffmpeg -version 2>/dev/null | head -1)"
        return 0
    fi

    log_warn "未检测到 ffmpeg / ffprobe，正在安装 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    if command -v apt-get &>/dev/null; then
        apt-get update -qq >/dev/null 2>&1
        apt-get install -y -qq ffmpeg >/dev/null 2>&1
    elif command -v dnf &>/dev/null; then
        dnf install -y -q ffmpeg >/dev/null 2>&1
    elif command -v yum &>/dev/null; then
        yum install -y -q ffmpeg >/dev/null 2>&1
    elif command -v apk &>/dev/null; then
        apk add --no-cache ffmpeg >/dev/null 2>&1
    fi

    if command -v ffmpeg &>/dev/null && command -v ffprobe &>/dev/null; then
        log_ok "FFmpeg 安装成功"
        return 0
    fi
    log_error "FFmpeg 安装失败，请手动安装 ffmpeg（内含 ffprobe）后重试"
    return 1
}

# ensure_service_user 创建服务运行账号
ensure_service_user() {
    if id -u "${SERVICE_USER}" &>/dev/null; then
        log_ok "服务账号 ${gl_huang}${SERVICE_USER}${gl_bai} 已存在"
        return 0
    fi
    useradd -r -s /sbin/nologin -d "${DEFAULT_DATA_DIR}" "${SERVICE_USER}" 2>/dev/null
    if id -u "${SERVICE_USER}" &>/dev/null; then
        log_ok "服务账号 ${gl_huang}${SERVICE_USER}${gl_bai} 创建成功"
        return 0
    fi
    log_warn "服务账号创建失败，安装将继续（将使用当前用户运行）"
    return 1
}

# write_unit_file 写入 systemd 服务单元（对齐仓库 scripts/fan-image-tr.service）
write_unit_file() {
    log_info "写入 systemd 服务单元：${gl_huang}${UNIT_FILE}${gl_bai}"
    cat > "${UNIT_FILE}" << EOF
[Unit]
Description=fan-image-tr 图片批量处理服务
Documentation=${REPO_URL}
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_USER}
WorkingDirectory=${DEFAULT_DATA_DIR}

# 监听地址与目录：按需修改
Environment=FIT_APP_PORT=${DEFAULT_PORT}
Environment=FIT_APP_DATA_DIR=${DEFAULT_DATA_DIR}
Environment=FIT_APP_MEDIA_DIR=${DEFAULT_MEDIA_DIR}
Environment=FIT_APP_WORKER=${DEFAULT_WORKER}
Environment=FIT_FFMPEG_ACCEL=auto
EnvironmentFile=-${ENV_FILE_DIR}/${SERVICE}.env

ExecStart=${INSTALL_BIN}
# 不提供 ExecReload：服务不支持热重载配置，reload 请走 restart

# 进程管理：异常退出自动重启，正常退出不重启
Restart=on-failure
RestartSec=3s
KillSignal=SIGTERM
TimeoutStopSec=20s

# 日志交给 journald
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${SERVICE}

# ===== 基础加固 =====
NoNewPrivileges=true
PrivateTmp=true
PrivateDevices=false
ProtectSystem=strict
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictNamespaces=true
RestrictRealtime=true
RestrictSUIDSGID=true
LockPersonality=true
MemoryDenyWriteExecute=true
# 允许写入数据目录与浏览根目录
ReadWritePaths=${DEFAULT_DATA_DIR} ${DEFAULT_MEDIA_DIR}

[Install]
WantedBy=multi-user.target
EOF
    log_ok "服务单元写入完成"
}

# install_fan_image_tr 一键安装 / 升级（下载 GitHub Releases 二进制 + systemd 托管）
install_fan_image_tr() {
    if [ "$EUID" -ne 0 ]; then
        log_error "安装 / 升级需要 root 权限，请用 sudo 运行本菜单"
        return 1
    fi

    local arch
    arch=$(detect_arch)
    echo -e ""
    echo -e "${gl_zi}>>> 安装 / 升级 fan-image-tr（linux/${gl_huang}${arch}${gl_zi}）${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    install_ffmpeg || return 1

    local tmp_bin
    tmp_bin=$(mktemp "/tmp/${SERVICE}.XXXXXX")

    log_info "从 GitHub Releases 下载二进制 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    if curl -fsSL --retry 3 "${RELEASE_URL}/${SERVICE}-linux-${arch}" -o "${tmp_bin}"; then
        log_ok "二进制下载完成"
    else
        log_warn "Release 下载失败，回退到源码编译（需要本机安装 Go 1.25+）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        rm -f "${tmp_bin}"
        local build_dir
        build_dir=$(mktemp -d "/tmp/${SERVICE}-src.XXXXXX")
        if ! git clone --depth 1 "${REPO_URL}" "${build_dir}" >/dev/null 2>&1; then
            log_error "源码克隆失败，请检查网络后重试"
            rm -rf "${build_dir}"
            return 1
        fi
        if ! (cd "${build_dir}" && CGO_ENABLED=0 go build -trimpath -o "${tmp_bin}" .); then
            log_error "源码编译失败，请确认已安装 Go 1.25+"
            rm -rf "${build_dir}"
            return 1
        fi
        rm -rf "${build_dir}"
        log_ok "源码编译完成"
    fi

    install -m 0755 "${tmp_bin}" "${INSTALL_BIN}" || { log_error "二进制安装失败"; rm -f "${tmp_bin}"; return 1; }
    rm -f "${tmp_bin}"
    log_ok "二进制已安装到 ${gl_huang}${INSTALL_BIN}${gl_bai}"
    log_info "版本信息：${gl_huang}$("${INSTALL_BIN}" version 2>/dev/null | head -1)${gl_bai}"

    ensure_service_user

    mkdir -p "${DEFAULT_DATA_DIR}" "${DEFAULT_MEDIA_DIR}" "${ENV_FILE_DIR}"
    chown -R "${SERVICE_USER}:${SERVICE_USER}" "${DEFAULT_DATA_DIR}" 2>/dev/null || log_warn "数据目录属主修正失败：${DEFAULT_DATA_DIR}"

    if ! command -v systemctl &>/dev/null; then
        log_error "未检测到 systemd，请改用 Docker 部署：ops-script/dc_inst_fan-image-tr.md"
        return 1
    fi

    write_unit_file

    systemctl daemon-reload || { log_error "systemctl daemon-reload 失败"; return 1; }
    systemctl enable "${SERVICE}" >/dev/null 2>&1
    systemctl restart "${SERVICE}" || { log_error "服务启动失败，请查看 journalctl -u ${SERVICE} -n 50"; return 1; }

    log_ok "安装完成，服务已启动并设置开机自启"
    log_info "访问地址：${gl_lv}http://$(get_local_ip):${DEFAULT_PORT}${gl_bai}（无账号体系，打开即用）"
    log_info "数据目录：${gl_huang}${DEFAULT_DATA_DIR}${gl_bai} / 图片根目录：${gl_huang}${DEFAULT_MEDIA_DIR}${gl_bai}"
    log_info "自定义端口 / 目录：编辑 ${gl_huang}${UNIT_FILE}${gl_bai} 后 systemctl restart ${SERVICE}"
    return 0
}

# uninstall_fan_image_tr 卸载（可选是否保留数据目录）
uninstall_fan_image_tr() {
    if [ "$EUID" -ne 0 ]; then
        log_error "卸载需要 root 权限，请用 sudo 运行本菜单"
        return 1
    fi

    echo -e ""
    echo -e "${gl_zi}>>> 卸载 fan-image-tr${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if systemctl list-unit-files 2>/dev/null | grep -q "^${SERVICE}.service"; then
        systemctl stop "${SERVICE}" 2>/dev/null
        systemctl disable "${SERVICE}" >/dev/null 2>&1
        log_ok "服务已停止并取消开机自启"
    else
        log_ok "未发现 ${SERVICE} 服务，跳过服务清理"
    fi

    rm -f "${UNIT_FILE}"
    systemctl daemon-reload 2>/dev/null
    systemctl reset-failed "${SERVICE}" 2>/dev/null
    log_ok "服务单元 ${gl_huang}${UNIT_FILE}${gl_bai} 已删除"

    if [ -f "${INSTALL_BIN}" ]; then
        rm -f "${INSTALL_BIN}"
        log_ok "二进制 ${gl_huang}${INSTALL_BIN}${gl_bai} 已删除"
    fi

    read -r -e -p "$(echo -e "${gl_bai}是否同时删除数据目录 ${gl_huang}${DEFAULT_DATA_DIR}${gl_bai}？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}) 默认 N: ")" purge
    if [[ "$purge" =~ ^[Yy]$ ]]; then
        rm -rf "${DEFAULT_DATA_DIR}"
        log_ok "数据目录已删除"
    else
        log_info "数据目录已保留：${gl_huang}${DEFAULT_DATA_DIR}${gl_bai}"
    fi

    log_ok "卸载完成"
    return 0
}

# backup_data 备份数据目录为 tar.gz，并按份数滚动清理
backup_data() {
    local backup_dir="${1:-$BACKUP_DIR}"
    local keep="${2:-$BACKUP_KEEP}"

    if [ ! -d "${DEFAULT_DATA_DIR}" ]; then
        log_error "数据目录不存在：${gl_huang}${DEFAULT_DATA_DIR}${gl_bai}"
        return 1
    fi

    mkdir -p "${backup_dir}" || { log_error "备份目录创建失败：${backup_dir}"; return 1; }

    local ts
    ts=$(date +%Y%m%d-%H%M%S)
    local target="${backup_dir}/${SERVICE}-${ts}.tar.gz"

    log_info "正在备份 ${gl_huang}${DEFAULT_DATA_DIR}${gl_bai} → ${gl_huang}${target}${gl_bai}"
    if ! tar -czf "${target}" -C "$(dirname "${DEFAULT_DATA_DIR}")" "$(basename "${DEFAULT_DATA_DIR}")"; then
        log_error "备份失败"
        rm -f "${target}"
        return 1
    fi

    log_ok "备份完成：${gl_huang}$(du -h "${target}" 2>/dev/null | cut -f1)${gl_bai} ${target}"

    if [[ "$keep" =~ ^[0-9]+$ ]] && [ "$keep" -gt 0 ]; then
        local old_list
        old_list=$(ls -1t "${backup_dir}"/${SERVICE}-*.tar.gz 2>/dev/null | tail -n +$((keep + 1)))
        if [ -n "$old_list" ]; then
            echo "$old_list" | xargs -r rm -f
            log_ok "已清理超出份数（保留最近 ${keep} 份）的旧备份"
        fi
    fi
    return 0
}

# recover_data 从备份目录恢复最新一份
recover_data() {
    local backup_dir="${1:-$BACKUP_DIR}"

    if [ ! -d "${backup_dir}" ]; then
        log_error "备份目录不存在：${gl_huang}${backup_dir}${gl_bai}"
        return 1
    fi

    local latest
    latest=$(ls -1t "${backup_dir}"/${SERVICE}-*.tar.gz 2>/dev/null | head -1)
    if [ -z "$latest" ]; then
        log_error "备份目录中没有找到 ${gl_huang}${SERVICE}-*.tar.gz${gl_bai} 备份"
        return 1
    fi

    echo -e ""
    echo -e "${gl_zi}>>> 从最新备份恢复数据${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_info "备份文件：${gl_huang}${latest}${gl_bai}"

    read -r -e -p "$(echo -e "${gl_bai}确认恢复？现有数据将被备份为 ${gl_huang}${DEFAULT_DATA_DIR}.bak.$(date +%Y%m%d-%H%M%S)${gl_bai} (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}) 默认 N: ")" ok
    if [[ ! "$ok" =~ ^[Yy]$ ]]; then
        log_warn "已取消恢复操作"
        return 1
    fi

    systemctl stop "${SERVICE}" 2>/dev/null

    local old_dir="${DEFAULT_DATA_DIR}.bak.$(date +%Y%m%d-%H%M%S)"
    if [ -d "${DEFAULT_DATA_DIR}" ]; then
        mv "${DEFAULT_DATA_DIR}" "${old_dir}" && log_ok "原数据目录已备份到 ${gl_huang}${old_dir}${gl_bai}"
    fi
    mkdir -p "$(dirname "${DEFAULT_DATA_DIR}")"

    if ! tar -xzf "${latest}" -C "$(dirname "${DEFAULT_DATA_DIR}")"; then
        log_error "恢复失败，正在回滚到原数据目录"
        [ -d "${old_dir}" ] && mv "${old_dir}" "${DEFAULT_DATA_DIR}"
        systemctl start "${SERVICE}" 2>/dev/null
        return 1
    fi

    chown -R "${SERVICE_USER}:${SERVICE_USER}" "${DEFAULT_DATA_DIR}" 2>/dev/null
    systemctl start "${SERVICE}" 2>/dev/null

    log_ok "数据恢复完成，服务已重启"
    return 0
}

# show_ffmpeg_check 执行 FFmpeg 环境与硬件加速自检
show_ffmpeg_check() {
    echo -e ""
    echo -e "${gl_zi}>>> fan-image-tr FFmpeg 能力自检 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    if [ ! -x "${INSTALL_BIN}" ]; then
        log_error "未找到 ${gl_huang}${INSTALL_BIN}${gl_bai}，请先执行选项 66 安装"
        return 1
    fi
    sudo "${INSTALL_BIN}" check
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
}

# show_runtime_status 查看运行状态与目录占用
show_runtime_status() {
    echo -e ""
    echo -e "${gl_zi}>>> fan-image-tr 运行状态与容量 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    if [ ! -x "${INSTALL_BIN}" ]; then
        log_error "未找到 ${gl_huang}${INSTALL_BIN}${gl_bai}，请先执行选项 66 安装"
        return 1
    fi
    sudo "${INSTALL_BIN}" status
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
}

manage_fan_image_tr() {
    while true; do
        clear
        echo -e ""
        echo -e "${gl_zi}>>> fan-image-tr 管理工具${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        show_service_status fan-image-tr
        show_service_url fan-image-tr
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}停止 fan-image-tr   ${gl_bufan}2.  ${gl_bai}启动 fan-image-tr"
        echo -e "${gl_bufan}3.  ${gl_bai}重启 fan-image-tr   ${gl_bufan}4.  ${gl_bai}查看服务状态"
        echo -e "${gl_bufan}5.  ${gl_bai}查看开机自启状态   ${gl_bufan}6.  ${gl_bai}开启开机自启"
        echo -e "${gl_bufan}7.  ${gl_bai}禁用开机自启       ${gl_bufan}8.  ${gl_bai}查看日志(100行)"
        echo -e "${gl_bufan}9.  ${gl_bai}实时跟踪日志"
        echo -e "${gl_bufan}10. ${gl_bai}FFmpeg 能力自检     ${gl_bufan}11. ${gl_bai}运行状态与容量"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_lv}66. ${gl_bai}安装/升级 fan-image-tr  ${gl_huang}77. ${gl_bai}备份数据"
        echo -e "${gl_lv}88. ${gl_bai}恢复数据             ${gl_hong}99. ${gl_bai}卸载 fan-image-tr"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单       ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" action


        case "$action" in
        1)
            echo -e ""
            echo -e "${gl_zi}>>> 正在停止 fan-image-tr 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl stop ${SERVICE}
            log_ok "fan-image-tr 服务已停止"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        2)
            echo -e ""
            echo -e "${gl_zi}>>> 正在启动 fan-image-tr 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl start ${SERVICE}
            log_ok "fan-image-tr 服务已启动"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        3)
            echo -e ""
            echo -e "${gl_zi}>>> 正在重启 fan-image-tr 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl restart ${SERVICE}
            log_ok "fan-image-tr 服务已重启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        4)
            echo -e ""
            echo -e "${gl_zi}>>> fan-image-tr 服务状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl status ${SERVICE}
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        5)
            echo -e ""
            echo -e "${gl_zi}>>> fan-image-tr 开机自启状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
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
            echo -e "${gl_zi}>>> 正在开启 fan-image-tr 开机自启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl enable ${SERVICE}
            log_ok "已开启 fan-image-tr 开机自启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        7)
            echo -e ""
            echo -e "${gl_zi}>>> 正在禁用 fan-image-tr 开机自启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl disable ${SERVICE}
            log_ok "已禁用 fan-image-tr 开机自启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        8)
            echo -e ""
            echo -e "${gl_zi}>>> fan-image-tr 日志（最近100行）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo journalctl -u ${SERVICE} -n 100
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        9)
            echo -e ""
            echo -e "${gl_zi}>>> 实时跟踪 fan-image-tr 日志（按 Ctrl+C 退出）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo journalctl -u ${SERVICE} -f
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        10)
            show_ffmpeg_check
            break_end
            ;;
        11)
            show_runtime_status
            break_end
            ;;
        66)
            install_fan_image_tr
            break_end
            continue
            ;;
        77)
            backup_data "${BACKUP_DIR}" "${BACKUP_KEEP}"
            break_end
            continue
            ;;
        88)
            recover_data "${BACKUP_DIR}"
            break_end
            continue
            ;;
        99)
            uninstall_fan_image_tr
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

manage_fan_image_tr
