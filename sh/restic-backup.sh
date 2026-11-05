#!/bin/bash
set -euo pipefail

BACKUP_DIR="/etc /var/www"
RESTIC_REPO="/mnt/backups/restic-repo"
RESTIC_PASSWORD="changeme"
RETENTION="--keep-daily 7 --keep-weekly 4 --keep-monthly 6"

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

install_restic() {
    if command -v restic &>/dev/null; then
        log_warn "restic 已安装"
    elif command -v apt &>/dev/null; then apt update && apt install -y restic; fi
    if command -v yum &>/dev/null; then yum install -y restic; fi
    if command -v dnf &>/dev/null; then dnf install -y restic; fi
}

init_repo() {
    export RESTIC_PASSWORD="$RESTIC_PASSWORD"
    if [ ! -d "$RESTIC_REPO" ]; then
        mkdir -p "$RESTIC_REPO"
        restic init --repo "$RESTIC_REPO"
        log_ok "Restic 仓库已初始化：$RESTIC_REPO"
    fi
}

run_backup() {
    export RESTIC_PASSWORD="$RESTIC_PASSWORD"
    restic backup $BACKUP_DIR --repo "$RESTIC_REPO"
    restic forget --repo "$RESTIC_REPO" $RETENTION --prune
    restic snapshots --repo "$RESTIC_REPO"
    log_ok "备份完成"
}

main() {
    root_use
    install_restic
    init_repo
    run_backup
    echo -e "${gl_lv}Restic 增量备份完成${gl_bai}"
    echo -e "${gl_huang}仓库：$RESTIC_REPO${gl_bai}"
}

main "$@"
