#!/bin/bash
set -euo pipefail

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
log_error() { echo -e "${gl_hong}[错误]${gl_bai} $*" >&2; exit 1; }

detect_pkg() {
    if command -v apt &>/dev/null; then echo "apt"
    elif command -v dnf &>/dev/null; then echo "dnf"
    elif command -v yum &>/dev/null; then echo "yum"
    elif command -v pacman &>/dev/null; then echo "pacman"
    elif command -v apk &>/dev/null; then echo "apk"
    else echo "unknown"; fi
}

check_docker() {
    if ! command -v docker &>/dev/null; then
        log_error "Docker 未安装，请先安装 Docker"
    fi
    log_ok "Docker 已安装"
}

clean_all_old_keys() {
    log_info "正在清理所有旧密钥、GPG、Docker 凭证、残留配置 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    pkill -f gpg-agent 2>/dev/null || true
    rm -rf /root/.gnupg /root/.password-store /root/.docker
    rm -f /usr/local/bin/docker-credential-pass /usr/local/bin/docker-credential-secretservice
    mkdir -p /root/.gnupg
    chmod 700 /root/.gnupg
    log_ok "旧密钥与配置已**完全清空**"
}

install_deps() {
    local pkg=$(detect_pkg)
    log_info "检测到包管理器：$pkg"
    log_info "安装依赖 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    case $pkg in
        apt)
            apt update -y
            apt install -y curl ca-certificates rng-tools5 pass gnupg
            ;;
        dnf)
            dnf install -y curl pass gnupg2 rng-tools
            ;;
        yum)
            yum install -y epel-release
            yum install -y curl pass gnupg2 rng-tools
            ;;
        pacman)
            pacman -S --noconfirm curl pass gnupg rng-tools
            ;;
        apk)
            apk add curl pass gnupg rng-tools
            ;;
        *)
            log_error "不支持的系统包管理器"
            ;;
    esac
    systemctl start rng-tools 2>/dev/null || rngd -r /dev/urandom 2>/dev/null || true
}

install_pass_helper() {
    local helper_path="/usr/local/bin/docker-credential-pass"
    local arch=$(uname -m)
    local url=""
    case "$arch" in
        x86_64)
            url="https://github.com/docker/docker-credential-helpers/releases/download/v0.8.0/docker-credential-pass-v0.8.0.linux-amd64"
            ;;
        aarch64)
            url="https://github.com/docker/docker-credential-helpers/releases/download/v0.8.0/docker-credential-pass-v0.8.0.linux-arm64"
            ;;
        *)
            log_error "不支持的架构: $arch"
            ;;
    esac
    log_info "下载加密助手 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    curl -fSL --connect-timeout 10 --max-time 30 -o "$helper_path" "$url"
    chmod +x "$helper_path"
    log_ok "加密助手安装成功"
}

generate_full_gpg() {
    log_info "生成【带加密能力】的 GPG 密钥 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    export GPG_TTY=$(tty 2>/dev/null || echo /dev/tty)

gpg --batch --passphrase '' --gen-key <<EOF
%echo Generating secure Docker key
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: Docker-Credential
Name-Email: docker@local
Expire-Date: 0
%no-protection
%commit
EOF

    local keyid=$(gpg --list-keys --with-colons | grep '^pub' | cut -d: -f5 | head -1)
    pass init "$keyid" >/dev/null 2>&1
    log_ok "GPG 密钥【加密可用】生成成功"
}

configure_docker() {
    mkdir -p /root/.docker
    cat > /root/.docker/config.json <<'EOF'
{
  "credsStore": "pass"
}
EOF
    chmod 600 /root/.docker/config.json
    log_ok "Docker 已配置 pass 加密存储"
}

main() {
    clear
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_lv}    Docker 加密凭证助手（终极无错版）${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo

    check_docker
    clean_all_old_keys
    install_deps
    install_pass_helper
    generate_full_gpg
    configure_docker

    echo
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_ok "✅ 全部完成！登录一次永久生效"
    echo -e "${gl_huang}使用示例：docker login -u 用户名 -p dckr_pat_密钥 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
}

main