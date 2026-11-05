#!/bin/bash
set -euo pipefail

SOURCE_DIR="/etc /var/www"
DEST_DIR="/mnt/backups/rsync"
EXCLUDES="--exclude=/var/www/cache --exclude=/etc/ssl/private"
KEEP_DAYS="7"

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

install_rsync() {
    if command -v rsync &>/dev/null; then
        log_warn "rsync 已安装"
    elif command -v apt &>/dev/null; then apt update && apt install -y rsync; fi
    if command -v yum &>/dev/null; then yum install -y rsync; fi
    if command -v dnf &>/dev/null; then dnf install -y rsync; fi
}

prepare_dest() {
    mkdir -p "$DEST_DIR"
    log_ok "备份目标目录已准备：$DEST_DIR"
}

run_backup() {
    local today
    today=$(date +%Y%m%d)
    local link_dest=""
    if [ -d "$DEST_DIR/latest" ]; then
        link_dest="--link-dest=$DEST_DIR/latest"
    fi
    rsync -aH --delete $EXCLUDES $link_dest $SOURCE_DIR "$DEST_DIR/$today/"
    rm -f "$DEST_DIR/latest"
    ln -s "$DEST_DIR/$today" "$DEST_DIR/latest"
    log_ok "增量备份完成：$DEST_DIR/$today"
}

clean_old() {
    find "$DEST_DIR" -maxdepth 1 -type d -mtime +"$KEEP_DAYS" -exec rm -rf {} \; 2>/dev/null || true
    log_ok "已清理 $KEEP_DAYS 天前的旧备份"
}

main() {
    root_use
    install_rsync
    prepare_dest
    run_backup
    clean_old
    echo -e "${gl_lv}Rsync 增量备份完成${gl_bai}"
    echo -e "${gl_huang}备份目录：$DEST_DIR${gl_bai}"
}

main "$@"
