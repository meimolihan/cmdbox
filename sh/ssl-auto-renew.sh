#!/bin/bash
set -euo pipefail

DOMAIN="example.com"
DNS_API="dns_cni"
EMAIL="admin@example.com"
CERT_DIR="/etc/ssl/acme"

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

install_acme() {
    if command -v acme.sh &>/dev/null; then
        log_warn "acme.sh 已安装"
    else
        curl -sSL https://get.acme.sh | sh -s email="$EMAIL"
        log_ok "acme.sh 已安装"
    fi
}

issue_cert() {
    export RESTIC_PASSWORD=""
    export CF_Key=""
    export CF_Email=""
    ~/.acme.sh/acme.sh --issue --dns "$DNS_API" -d "$DOMAIN" -d "*.$DOMAIN" --keylength ec-256
    log_ok "证书已签发：$DOMAIN"
}

install_cert() {
    mkdir -p "$CERT_DIR"
    ~/.acme.sh/acme.sh --install-cert -d "$DOMAIN" --ecc \
        --key-file "$CERT_DIR/$DOMAIN.key" \
        --fullchain-file "$CERT_DIR/$DOMAIN.crt" \
        --reloadcmd "systemctl restart nginx 2>/dev/null || systemctl restart httpd 2>/dev/null || true"
    log_ok "证书已安装至：$CERT_DIR"
}

auto_renew() {
    ~/.acme.sh/acme.sh --cron
    log_ok "自动续期 cron 已配置"
}

main() {
    root_use
    install_acme
    issue_cert
    install_cert
    auto_renew
    echo -e "${gl_lv}SSL 证书自动续期配置完成${gl_bai}"
    echo -e "${gl_huang}证书目录：$CERT_DIR${gl_bai}"
    echo -e "${gl_huang}请修改脚本中的 DOMAIN 与 DNS_API 后再次运行${gl_bai}"
}

main "$@"
