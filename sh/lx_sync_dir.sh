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

DEFAULT_LOG="/var/log/rsync/lx_sync_dir.log"

get_linux_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$ID"
    elif [[ -f /etc/redhat-release ]]; then
        echo "rhel"
    elif [[ -f /etc/debian_version ]]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

install_rsync() {
    local distro=$(get_linux_distro)
    log_warn "未检测到 rsync，开始自动安装 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    log_info "当前系统发行版: ${distro}"

    case "${distro}" in
        debian|ubuntu|pop|mint)
            apt update -y && apt install -y rsync
            ;;
        rhel|centos|rocky|almalinux|fedora)
            if command -v dnf &>/dev/null; then
                dnf install -y rsync
            else
                yum install -y rsync
            fi
            ;;
        arch|manjaro)
            pacman -Syu --noconfirm rsync
            ;;
        suse|opensuse)
            zypper install -y rsync
            ;;
        *)
            log_error "暂不支持当前发行版自动安装，请手动安装 rsync"
            exit 127
            ;;
    esac

    if command -v rsync &>/dev/null; then
        log_ok "rsync 安装完成"
    else
        log_error "rsync 安装失败，请手动处理"
        exit 127
    fi
}

check_deps() {
    if ! command -v rsync &>/dev/null; then
        install_rsync
    fi
}

handle_invalid_input() {
    echo -ne "\r\033[K${gl_huang}无效的输入,请重新输入! ${gl_zi} 1 ${gl_huang} 秒后返回"
    sleep_fractional 1
    echo -ne "\r\033[K${gl_lv}无效的输入,请重新输入! ${gl_zi}0${gl_lv} 秒后返回"
    sleep_fractional 0.5
    echo -ne "\r\033[K"
    return 2
}

handle_y_n() {
    echo -e "${gl_hong}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai})${gl_hong}。${gl_bai}"
    sleep 1
    echo -e "${gl_huang}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai})${gl_huang}。${gl_bai}"
    sleep 1
    echo -e "${gl_lv}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai})${gl_lv}。${gl_bai}"
    sleep 0.5
    return 2
}

exit_script() {
    echo ""
    echo -ne "${gl_hong}感谢使用，再见！${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    clear
    exit 0
}

exit_animation() {
    echo -ne "${gl_lv}即将退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
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
    local menu_name="${1:-上一级选单}"
    echo -e "${gl_lv}即将返回到 ${gl_huang}${menu_name}${gl_lv}${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    sleep 0.6
    echo ""
    clear
}

LOG_FILE=""
SOURCE_DIR=""
TARGET_DIR=""

usage() {
    cat << EOF
用法: $0 [选项]
不传参：进入交互式路径配置
传参：指定对应参数执行

可选参数：
  -s, --source    必填，源目录路径
  -t, --target    必填，目标目录路径
  -l, --log       选填，日志文件路径，留空默认使用 ${DEFAULT_LOG}
  -h, --help      显示本帮助并退出

示例：
  $0
  $0 -s /var/www -t /backup/www
  $0 -s /var/www -t /backup/www -l /tmp/www_sync.log
EOF
    exit 1
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--source)
                [[ -z "$2" ]] && log_error "-s 后必须指定源目录路径" && usage
                SOURCE_DIR="$2"
                shift 2
                ;;
            -t|--target)
                [[ -z "$2" ]] && log_error "-t 后必须指定目标目录路径" && usage
                TARGET_DIR="$2"
                shift 2
                ;;
            -l|--log)
                LOG_FILE="$2"
                shift 2
                ;;
            -h|--help)
                usage
                ;;
            *)
                log_error "未知参数: $1"
                usage
                ;;
        esac
    done

    if [[ -z "$SOURCE_DIR" || -z "$TARGET_DIR" ]]; then
        log_error "传参模式下 -s -t 为必填项"
        usage
    fi
}

interactive_input() {
    clear
    echo -e "${gl_zi}>>> Rsync 目录同步工具${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    while true; do
        read -r -e -p "请输入源目录路径: " SOURCE_DIR
        [[ -n "$SOURCE_DIR" ]] && break
        log_error "路径不能为空，请重新输入！"
    done

    while true; do
        read -r -e -p "请输入目标目录路径: " TARGET_DIR
        [[ -n "$TARGET_DIR" ]] && break
        log_error "路径不能为空，请重新输入！"
    done

    read -r -e -p "请输入日志文件路径(回车使用默认日志): " LOG_FILE

    echo -e "\n${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_info "源目录:   $SOURCE_DIR"
    log_info "目标目录: $TARGET_DIR"
    if [[ -n "$LOG_FILE" ]]; then
        log_info "日志文件: $LOG_FILE"
    else
        log_info "日志: 使用默认路径 ${DEFAULT_LOG}"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "确认开始同步？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
    case $confirm in
        [Nn])
            log_warn "用户取消，退出脚本"
            exit_animation
            exit 0
            ;;
        [Yy])
            ;;
        *)
            handle_y_n
            exit 1
            ;;
    esac
    echo ""
}

main_log() {
    local msg="$1"
    echo "$msg"
    [[ -n "$LOG_FILE" ]] && echo "$msg" >> "$LOG_FILE"
}

check_deps

if [[ $# -eq 0 ]]; then
    interactive_input
else
    parse_args "$@"
fi

[[ -z "$LOG_FILE" ]] && LOG_FILE="${DEFAULT_LOG}"

log_info "最终日志文件: ${LOG_FILE}"
log_info "日志存放目录: $(dirname "${LOG_FILE}")"

mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$TARGET_DIR"

SOURCE_DIR="${SOURCE_DIR%/}/"
TARGET_DIR="${TARGET_DIR%/}/"

main_log ""
main_log "【目录同步任务】开始时间: $(date +"%Y-%m-%d %H:%M:%S")"
main_log "================================================================"
main_log "【配置】日志文件路径: ${LOG_FILE}"

if [[ ! -d "$SOURCE_DIR" ]]; then
    main_log "【错误】源目录不存在: $SOURCE_DIR"
    main_log "【状态】同步任务失败，源目录未找到"
    main_log "================================================================"
    exit 1
fi

main_log "【信息】源目录: $SOURCE_DIR"
main_log "【信息】目标目录: $TARGET_DIR"
main_log "【信息】源目录大小: $(du -sh "$SOURCE_DIR" | cut -f1)"
main_log "【信息】开始同步目录..."
main_log "【执行】开始执行 rsync 命令..."

SYNC_START=$(date +%s)
if [[ -n "$LOG_FILE" ]]; then
    rsync -avhz --delete-delay "$SOURCE_DIR" "$TARGET_DIR" 2>&1 | tee -a "$LOG_FILE"
else
    rsync -avhz --delete-delay "$SOURCE_DIR" "$TARGET_DIR"
fi
SYNC_RET=${PIPESTATUS[0]}
SYNC_END=$(date +%s)
DURATION=$((SYNC_END - SYNC_START))

if [[ $SYNC_RET -eq 0 ]]; then
    main_log "【成功】目录同步完成"
    if [[ -d "$TARGET_DIR" ]]; then
        main_log "【验证】目标目录已创建/更新"
        main_log "【验证】目标目录大小: $(du -sh "$TARGET_DIR" | cut -f1)"
    else
        main_log "【警告】同步完成但目标目录未找到"
    fi
else
    main_log "【错误】同步失败，rsync 退出码: $SYNC_RET"
    main_log "【状态】同步任务未完成"
fi

main_log "【信息】同步结束时间: $(date +"%Y-%m-%d %H:%M:%S")"
main_log "【信息】任务执行时长: ${DURATION} 秒"
main_log "================================================================"
