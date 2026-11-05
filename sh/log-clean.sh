#!/bin/bash
set -euo pipefail

RETENTION_DAYS="7"
LOG_DIRS=("/var/log" "/var/log/journal")

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

root_use() {
    if [ "$EUID" -ne 0 ]; then
        log_error "该脚本需要root用户运行"; exit 1
    fi
}

clean_journal() {
    if command -v journalctl &>/dev/null; then
        journalctl --vacuum-time="${RETENTION_DAYS}d"
        log_ok "journal 日志已清理，保留 ${RETENTION_DAYS} 天"
    fi
}

clean_var_log() {
    local freed=0
    for dir in "${LOG_DIRS[@]}"; do
        [ -d "$dir" ] || continue
        find "$dir" -type f -name "*.log" -mtime +"$RETENTION_DAYS" -delete 2>/dev/null || true
        find "$dir" -type f -name "*.log.*" -mtime +"$RETENTION_DAYS" -delete 2>/dev/null || true
        find "$dir" -type f -name "*.gz" -mtime +"$RETENTION_DAYS" -delete 2>/dev/null || true
    done
    log_ok "/var/log 旧日志已清理"
}

rotate_active() {
    if command -v logrotate &>/dev/null; then
        logrotate -f /etc/logrotate.conf 2>/dev/null || true
        log_ok "日志已强制旋转"
    fi
}

show_before_after() {
    echo -e "${gl_bai}清理前：${gl_bai}"
    du -sh /var/log 2>/dev/null || true
}

main() {
    root_use
    show_before_after
    clean_journal
    clean_var_log
    rotate_active
    echo -e "${gl_bai}清理后：${gl_bai}"
    du -sh /var/log 2>/dev/null || true
    log_ok "系统日志清理完成"
}

main "$@"
