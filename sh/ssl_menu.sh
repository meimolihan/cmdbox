#!/bin/bash
set -uo pipefail

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

DEFAULT_EMAIL="meimolihan@live.com"
CF_INI="/etc/letsencrypt/cloudflare.ini"
ACME_HOME_DEFAULT="${HOME:-/root}/.acme.sh"
ACME_CF_ENV="${ACME_HOME_DEFAULT}/conf/cloudflare.env"
ACME_BIN=""
ACME_HOME="$ACME_HOME_DEFAULT"
EMAIL=""
CERT_NAME=""
STAGING=0
REPLY_VALUE=""
DOMAINS=()
D_ARGS=()
CERTBOT_KEY_ARGS=(--key-type ecdsa --elliptic-curve secp256r1)
ACME_KEYLENGTH="ec-256"

line() {
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
}

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
    local int_seconds
    int_seconds=$(echo "$seconds" | awk '{print int($1+0.999)}')
    sleep "$int_seconds"
}

handle_invalid_input() {
    echo -ne "\r\033[K${gl_huang}无效的输入,请重新输入! ${gl_zi} 1 ${gl_huang} 秒后返回"
    sleep_fractional 1
    echo -ne "\r\033[K${gl_lv}无效的输入,请重新输入! ${gl_zi}0${gl_lv} 秒后返回"
    sleep_fractional 0.5
    echo -ne "\r\033[K"
    return 2
}

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n 1 -s -r -p ""
    echo ""
    clear
}

cancel_return() {
    local menu_name="${1:-上一级选单}"
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
    local i
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

check_root() {
    if [ "${EUID:-$(id -u)}" -ne 0 ]; then
        echo -e "${gl_hong}[错误]${gl_bai} 请使用 root 权限运行此脚本"
        echo -e "${gl_bai}示例: ${gl_lv}sudo bash $0${gl_bai}"
        exit 1
    fi
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

reload_nginx() {
    if command_exists systemctl; then
        systemctl reload nginx
    elif command_exists nginx; then
        nginx -s reload
    else
        return 1
    fi
}

read_value() {
    local prompt="$1"
    local default="${2:-}"
    local value=""
    if [ -n "$default" ]; then
        read -r -e -p "$(echo -e "${gl_bai}${prompt} [${gl_lv}${default}${gl_bai}]: ")" value
        REPLY_VALUE="${value:-$default}"
    else
        read -r -e -p "$(echo -e "${gl_bai}${prompt}: ")" value
        REPLY_VALUE="$value"
    fi
}

read_secret() {
    local prompt="$1"
    local value=""
    read -r -s -p "$(echo -e "${gl_bai}${prompt}: ")" value
    echo ""
    REPLY_VALUE="$value"
}

confirm_yes() {
    local prompt="$1"
    local default="${2:-n}"
    local value=""
    read -r -e -p "$(echo -e "${gl_bai}${prompt} (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" value
    value="${value:-$default}"
    [[ "$value" =~ ^[Yy]$ ]]
}

safe_name() {
    echo "$1" | sed 's/\*/wildcard/g; s/[^A-Za-z0-9._-]/_/g'
}

validate_domain() {
    local d="${1:-}"
    [ -n "$d" ] || return 1
    [[ "$d" =~ ^[A-Za-z0-9*._-]+$ ]] || return 1
    [[ "$d" == *.* ]] || return 1
    [[ "$d" != *..* ]] || return 1
    [[ "$d" != -* ]] || return 1
    if [[ "$d" == *"*"* && "$d" != \*.* ]]; then
        return 1
    fi
    return 0
}

find_acme_bin() {
    local c
    for c in "${HOME:-/root}/.acme.sh/acme.sh" "/root/.acme.sh/acme.sh" /home/*/.acme.sh/acme.sh /usr/local/bin/acme.sh; do
        if [ -x "$c" ]; then
            echo "$c"
            return 0
        fi
    done
    if command_exists acme.sh; then
        c="$(command -v acme.sh 2>/dev/null || true)"
        if [ -n "$c" ] && [ -x "$c" ]; then
            echo "$c"
            return 0
        fi
    fi
    return 1
}

refresh_acme_env() {
    ACME_BIN="$(find_acme_bin || true)"
    if [ -n "$ACME_BIN" ]; then
        ACME_HOME="$(dirname "$ACME_BIN")"
    else
        ACME_HOME="$ACME_HOME_DEFAULT"
    fi
    ACME_CF_ENV="$ACME_HOME/conf/cloudflare.env"
}

read_domains() {
    local input=""
    local d
    local raw=()
    read -r -e -p "$(echo -e "${gl_bai}请输入域名 (空格或逗号分隔, 支持泛域名, 如 example.com *.example.com): ")" input
    input="${input//,/ }"
    read -r -a raw <<< "$input"
    DOMAINS=()
    if [ "${#raw[@]}" -eq 0 ]; then
        log_error "未输入域名"
        return 1
    fi
    for d in "${raw[@]}"; do
        if ! validate_domain "$d"; then
            log_warn "忽略无效域名: $d"
            continue
        fi
        DOMAINS+=("$d")
    done
    if [ "${#DOMAINS[@]}" -eq 0 ]; then
        log_error "未输入有效域名"
        return 1
    fi
    return 0
}

build_d_args() {
    D_ARGS=()
    local d
    for d in "${DOMAINS[@]}"; do
        D_ARGS+=(-d "$d")
    done
}

choose_email() {
    local e=""
    read -r -e -p "$(echo -e "${gl_bai}请输入邮箱 [${gl_lv}${DEFAULT_EMAIL}${gl_bai}]: ")" e
    EMAIL="${e:-$DEFAULT_EMAIL}"
}

choose_key() {
    local c=""
    echo -e "${gl_bai}请选择密钥类型:${gl_bai}"
    echo -e "${gl_bufan}1.  ${gl_bai}ECC ec-256 (推荐, 更安全高效)"
    echo -e "${gl_bufan}2.  ${gl_bai}RSA 2048 (兼容性更好)"
    read -r -e -p "$(echo -e "${gl_bai}请输入你的选择 [${gl_lv}1${gl_bai}]: ")" c
    c="${c:-1}"
    case "$c" in
        2)
            CERTBOT_KEY_ARGS=(--key-type rsa --rsa-key-size 2048)
            ACME_KEYLENGTH="2048"
            log_info "密钥类型: RSA 2048"
            ;;
        *)
            CERTBOT_KEY_ARGS=(--key-type ecdsa --elliptic-curve secp256r1)
            ACME_KEYLENGTH="ec-256"
            log_info "密钥类型: ECC ec-256"
            ;;
    esac
}

choose_cert_name() {
    local def="${DOMAINS[0]}"
    def="${def#\*.}"
    local c=""
    read -r -e -p "$(echo -e "${gl_bai}请输入证书名称 [${gl_lv}${def}${gl_bai}]: ")" c
    CERT_NAME="${c:-$def}"
    if ! [[ "$CERT_NAME" =~ ^[A-Za-z0-9._-]+$ ]]; then
        log_error "证书名称只能包含字母、数字、点、下划线、短横线"
        return 1
    fi
    return 0
}

choose_staging() {
    local s=""
    STAGING=0
    read -r -e -p "$(echo -e "${gl_bai}是否使用 Let's Encrypt 测试环境? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" s
    if [[ "$s" =~ ^[Yy]$ ]]; then
        STAGING=1
        log_warn "已启用测试环境, 证书不会被浏览器信任"
    fi
}

configure_cloudflare() {
    local pause="${1:-1}"
    local token=""
    local zone=""

    clear
    echo -e "${gl_zi}>>> 配置 Cloudflare API${gl_bai}"
    line
    log_info "请前往 Cloudflare 控制台创建 API Token"
    log_info "权限: Zone - DNS - Edit, 资源: 包含目标域名"
    line

    read_secret "请输入 Cloudflare API Token (输入不显示)"
    token="$REPLY_VALUE"
    if [ -z "$token" ]; then
        log_error "Token 不能为空"
        [ "$pause" -eq 1 ] && break_end
        return 1
    fi
    if ! [[ "$token" =~ ^[A-Za-z0-9._-]+$ ]]; then
        log_error "Token 格式不正确"
        [ "$pause" -eq 1 ] && break_end
        return 1
    fi

    read_value "请输入 Zone ID (可选, 留空自动识别)" ""
    zone="$REPLY_VALUE"
    if [ -n "$zone" ] && ! [[ "$zone" =~ ^[A-Fa-f0-9]{32}$ ]]; then
        log_warn "Zone ID 格式不正确, 已忽略"
        zone=""
    fi

    mkdir -p /etc/letsencrypt "$ACME_HOME/conf" 2>/dev/null
    printf 'dns_cloudflare_api_token = %s\n' "$token" > "$CF_INI"
    chmod 600 "$CF_INI"

    {
        printf "export CF_Token='%s'\n" "$token"
        if [ -n "$zone" ]; then
            printf "export CF_Zone_ID='%s'\n" "$zone"
        fi
    } > "$ACME_CF_ENV"
    chmod 600 "$ACME_CF_ENV"

    unset CF_Token CF_Zone_ID 2>/dev/null || true
    export CF_Token="$token"
    if [ -n "$zone" ]; then
        export CF_Zone_ID="$zone"
    fi

    log_ok "Cloudflare API 配置完成"
    log_info "CertBot: $CF_INI"
    log_info "ACME:    $ACME_CF_ENV"
    [ "$pause" -eq 1 ] && break_end
    return 0
}

ensure_cf_certbot() {
    if [ ! -s "$CF_INI" ]; then
        log_warn "未检测到 CertBot Cloudflare 配置, 请先配置"
        configure_cloudflare 0 || return 1
    fi
    return 0
}

ensure_cf_acme() {
    if [ -f "$ACME_CF_ENV" ]; then
        . "$ACME_CF_ENV"
    fi
    if [ -z "${CF_Token:-}" ]; then
        log_warn "未检测到 ACME Cloudflare 配置, 请先配置"
        configure_cloudflare 0 || return 1
        . "$ACME_CF_ENV"
    fi
    if [ -z "${CF_Token:-}" ]; then
        log_error "Cloudflare Token 未配置"
        return 1
    fi
    return 0
}

install_certbot() {
    clear
    echo -e "${gl_zi}>>> 安装 CertBot${gl_bai}"
    line

    if command_exists certbot; then
        if certbot plugins 2>/dev/null | grep -q "dns-cloudflare"; then
            log_ok "CertBot 已安装: $(certbot --version 2>&1 | head -1)"
            log_ok "Cloudflare 插件已安装"
            break_end
            return 0
        fi
        log_warn "CertBot 已安装, 但缺少 Cloudflare 插件"
    fi

    log_info "正在安装 CertBot 及 Cloudflare 插件..."
    local ok=1
    if command_exists apt-get; then
        apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y certbot python3-certbot-dns-cloudflare || ok=0
    elif command_exists dnf; then
        dnf install -y certbot python3-certbot-dns-cloudflare || ok=0
    elif command_exists yum; then
        yum install -y epel-release || true
        yum install -y certbot python3-certbot-dns-cloudflare || ok=0
    elif command_exists apk; then
        apk add --no-cache certbot certbot-dns-cloudflare || ok=0
    else
        ok=0
    fi

    line
    if [ "$ok" -eq 1 ] && command_exists certbot; then
        log_ok "CertBot 安装完成: $(certbot --version 2>&1 | head -1)"
        if certbot plugins 2>/dev/null | grep -q "dns-cloudflare"; then
            log_ok "Cloudflare 插件已安装"
        else
            log_warn "Cloudflare 插件可能未安装, 请手动检查"
        fi
        break_end
        return 0
    fi
    log_error "自动安装失败, 请参考文档手动安装 CertBot 和 Cloudflare 插件"
    break_end
    return 1
}

install_acme() {
    clear
    echo -e "${gl_zi}>>> 安装 / 升级 ACME.sh${gl_bai}"
    line

    refresh_acme_env
    if [ -n "$ACME_BIN" ]; then
        log_ok "acme.sh 已安装: $("$ACME_BIN" -v 2>&1 | head -1)"
        if confirm_yes "是否升级 acme.sh 并开启自动升级?" "y"; then
            "$ACME_BIN" --upgrade --auto-upgrade
        fi
        refresh_acme_env
        break_end
        return 0
    fi

    choose_email
    local install_ok=0
    if command_exists curl; then
        curl -s https://get.acme.sh | sh -s email="$EMAIL" && install_ok=1
    elif command_exists wget; then
        wget -qO- https://get.acme.sh | sh -s email="$EMAIL" && install_ok=1
    else
        log_error "未找到 curl 或 wget, 无法安装 acme.sh"
    fi

    refresh_acme_env
    line
    if [ "$install_ok" -eq 1 ] && [ -n "$ACME_BIN" ]; then
        "$ACME_BIN" --set-default-ca --server letsencrypt
        "$ACME_BIN" --upgrade --auto-upgrade
        log_ok "acme.sh 安装完成: $("$ACME_BIN" -v 2>&1 | head -1)"
        log_info "安装目录: $ACME_HOME"
        break_end
        return 0
    fi
    log_error "acme.sh 安装失败"
    break_end
    return 1
}

ensure_acme() {
    refresh_acme_env
    if [ -z "$ACME_BIN" ]; then
        log_warn "未检测到 acme.sh"
        if confirm_yes "是否立即安装 acme.sh?" "y"; then
            install_acme
            refresh_acme_env
        else
            return 1
        fi
    fi
    if [ -z "$ACME_BIN" ]; then
        log_error "acme.sh 不可用"
        return 1
    fi
    return 0
}

show_cert_summary() {
    local items=()
    local n=""
    local i=0
    local name=""
    local tag=""

    if command_exists certbot; then
        while IFS= read -r n; do
            [ -n "$n" ] && items+=("$n|CertBot")
        done < <(certbot certificates 2>/dev/null | awk '/Certificate Name:/{print $3}')
    fi

    refresh_acme_env
    if [ -n "$ACME_BIN" ]; then
        while IFS= read -r n; do
            [ -n "$n" ] && items+=("$n|ACME")
        done < <("$ACME_BIN" --list 2>/dev/null | tail -n +2 | awk 'NF{print $1}')
    fi

    if [ "${#items[@]}" -eq 0 ]; then
        echo -e "  ${gl_huang}未发现证书${gl_bai}"
        return 0
    fi

    for ((i=0; i<${#items[@]} && i<5; i++)); do
        IFS='|' read -r name tag <<< "${items[$i]}"
        echo -e "  ${gl_lan}${name}${gl_bai} ${gl_hui}[${tag}]${gl_bai}"
    done
    if [ "${#items[@]}" -gt 5 ]; then
        echo -e "  ${gl_hui}... 共 ${#items[@]} 个证书, 选择 3 查看详情${gl_bai}"
    fi
}

show_current_certs() {
    clear
    echo -e "${gl_zi}>>> 当前 SSL 证书${gl_bai}"
    line

    if command_exists certbot; then
        log_info "CertBot 证书"
        certbot certificates 2>/dev/null || log_warn "未找到 CertBot 证书"
    else
        log_warn "未安装 CertBot"
    fi

    line
    refresh_acme_env
    if [ -n "$ACME_BIN" ]; then
        log_info "ACME.sh 证书"
        "$ACME_BIN" --list 2>/dev/null || log_warn "未找到 ACME 证书"
    else
        log_warn "未安装 acme.sh"
    fi

    line
    break_end
}

show_main_menu() {
    clear
    echo -e "${gl_zi}>>> SSL 证书申请${gl_bai}"
    line
    show_cert_summary
    line
    echo -e "${gl_bufan}1.  ${gl_bai}CertBot 申请"
    echo -e "${gl_bufan}2.  ${gl_bai}ACME 申请"
    echo -e "${gl_bufan}3.  ${gl_bai}证书管理"
    echo -e "${gl_bufan}4.  ${gl_bai}证书部署"
    echo -e "${gl_bufan}5.  ${gl_bai}环境安装与配置"
    line
    echo -e "${gl_hong}0.  ${gl_bai}退出脚本"
}

certbot_issue_manual() {
    clear
    echo -e "${gl_zi}>>> CertBot DNS 手动验证申请${gl_bai}"
    line

    if ! command_exists certbot; then
        log_warn "未检测到 CertBot"
        if ! confirm_yes "是否立即安装 CertBot?" "y"; then
            cancel_return "CertBot 申请"
            return
        fi
        install_certbot || { cancel_return "CertBot 申请"; return; }
    fi

    read_domains || { break_end; return; }
    build_d_args
    choose_email
    choose_key
    choose_cert_name || { break_end; return; }
    choose_staging

    local args=(certonly --manual --preferred-challenges dns "${D_ARGS[@]}" --agree-tos --cert-name "$CERT_NAME")
    if [ -n "$EMAIL" ]; then
        args+=(--email "$EMAIL")
    else
        args+=(--register-unsafely-without-email)
    fi
    args+=("${CERTBOT_KEY_ARGS[@]}")
    [ "$STAGING" -eq 1 ] && args+=(--test-cert)

    line
    log_info "请按提示在 DNS 中添加 TXT 记录, 完成后回到终端继续"
    if certbot "${args[@]}"; then
        log_ok "证书申请完成"
        log_info "证书目录: /etc/letsencrypt/live/$CERT_NAME"
    else
        log_error "证书申请失败"
    fi
    break_end
}

certbot_issue_cloudflare() {
    local force_staging="${1:-0}"
    clear
    echo -e "${gl_zi}>>> CertBot Cloudflare API 自动验证申请${gl_bai}"
    line

    if ! command_exists certbot; then
        log_warn "未检测到 CertBot"
        if ! confirm_yes "是否立即安装 CertBot?" "y"; then
            cancel_return "CertBot 申请"
            return
        fi
        install_certbot || { cancel_return "CertBot 申请"; return; }
    fi

    ensure_cf_certbot || { break_end; return; }
    read_domains || { break_end; return; }
    build_d_args
    choose_email
    choose_key
    choose_cert_name || { break_end; return; }
    if [ "$force_staging" -eq 1 ]; then
        STAGING=1
        log_warn "已启用测试环境, 证书不会被浏览器信任"
    else
        choose_staging
    fi

    local prop=""
    read_value "DNS 传播等待秒数" "60"
    prop="$REPLY_VALUE"
    [[ "$prop" =~ ^[0-9]+$ ]] || prop=60

    local args=(certonly --dns-cloudflare --dns-cloudflare-credentials "$CF_INI" --dns-cloudflare-propagation-seconds "$prop" "${D_ARGS[@]}" --agree-tos --cert-name "$CERT_NAME" --non-interactive)
    if [ -n "$EMAIL" ]; then
        args+=(--email "$EMAIL")
    else
        args+=(--register-unsafely-without-email)
    fi
    args+=("${CERTBOT_KEY_ARGS[@]}")
    [ "$STAGING" -eq 1 ] && args+=(--test-cert)

    line
    log_info "正在通过 Cloudflare API 申请证书..."
    if certbot "${args[@]}"; then
        log_ok "证书申请完成"
        log_info "证书目录: /etc/letsencrypt/live/$CERT_NAME"
        log_info "下一步可在 [证书部署] 中部署到 Nginx"
    else
        log_error "证书申请失败"
    fi
    break_end
}

acme_issue_cloudflare() {
    local force_staging="${1:-0}"
    clear
    echo -e "${gl_zi}>>> ACME Cloudflare API 自动验证申请${gl_bai}"
    line

    ensure_acme || { break_end; return; }
    ensure_cf_acme || { break_end; return; }
    read_domains || { break_end; return; }
    build_d_args
    choose_key
    if [ "$force_staging" -eq 1 ]; then
        STAGING=1
        log_warn "已启用测试环境, 证书不会被浏览器信任"
    else
        choose_staging
    fi

    local args=(--issue --dns dns_cf "${D_ARGS[@]}" --keylength "$ACME_KEYLENGTH")
    [ "$STAGING" -eq 1 ] && args+=(--staging)

    line
    log_info "正在通过 Cloudflare API 申请证书..."
    if "$ACME_BIN" "${args[@]}"; then
        log_ok "证书申请完成"
        log_info "证书目录: $ACME_HOME/${DOMAINS[0]}"
        log_info "下一步可在 [证书部署] 中部署到 Nginx"
    else
        log_error "证书申请失败"
    fi
    break_end
}

acme_issue_manual() {
    clear
    echo -e "${gl_zi}>>> ACME DNS 手动验证申请${gl_bai}"
    line

    ensure_acme || { break_end; return; }
    read_domains || { break_end; return; }
    build_d_args
    choose_key
    choose_staging

    local args=(--issue --dns "${D_ARGS[@]}" --keylength "$ACME_KEYLENGTH" --yes-I-know-dns-manual-mode-enough-go-ahead-please)
    [ "$STAGING" -eq 1 ] && args+=(--staging)

    line
    "$ACME_BIN" "${args[@]}"
    line
    log_warn "请根据上方提示在 DNS 中添加 TXT 记录"
    log_warn "确认记录已生效后再继续, 泛域名通常需要添加多条 TXT 记录"
    read -r -e -p "$(echo -e "${gl_bai}DNS 生效后按回车继续验证: ")" _
    if "$ACME_BIN" --renew -d "${DOMAINS[0]}" --yes-I-know-dns-manual-mode-enough-go-ahead-please; then
        log_ok "证书申请完成"
        log_info "证书目录: $ACME_HOME/${DOMAINS[0]}"
    else
        log_error "证书验证失败"
    fi
    break_end
}

acme_set_ca() {
    clear
    echo -e "${gl_zi}>>> 设置 ACME 默认 CA${gl_bai}"
    line
    ensure_acme || { break_end; return; }

    local c=""
    echo -e "${gl_bufan}1.  ${gl_bai}Let's Encrypt (推荐)"
    echo -e "${gl_bufan}2.  ${gl_bai}Buypass"
    echo -e "${gl_bufan}3.  ${gl_bai}ZeroSSL"
    echo -e "${gl_bufan}4.  ${gl_bai}SSL.com"
    echo -e "${gl_bufan}5.  ${gl_bai}Google Public CA"
    line
    read -r -e -p "$(echo -e "${gl_bai}请输入你的选择 [${gl_lv}1${gl_bai}]: ")" c
    c="${c:-1}"

    local server=""
    case "$c" in
        2) server="buypass" ;;
        3) server="zerossl" ;;
        4) server="ssl.com" ;;
        5) server="google" ;;
        *) server="letsencrypt" ;;
    esac

    if "$ACME_BIN" --set-default-ca --server "$server"; then
        log_ok "默认 CA 已设置为: $server"
    else
        log_error "设置默认 CA 失败"
    fi
    break_end
}

certbot_renew() {
    clear
    echo -e "${gl_zi}>>> CertBot 证书续签${gl_bai}"
    line
    if ! command_exists certbot; then
        log_error "未安装 CertBot"
        break_end
        return
    fi

    read_value "请输入证书名称 (留空续签全部)" ""
    local name="$REPLY_VALUE"
    if [ -n "$name" ] && ! [[ "$name" =~ ^[A-Za-z0-9._-]+$ ]]; then
        log_error "证书名称格式不正确"
        break_end
        return
    fi

    local args=(renew)
    if [ -n "$name" ]; then
        args+=(--cert-name "$name")
    else
        args+=(--quiet)
    fi
    if confirm_yes "是否强制续签?" "n"; then
        args+=(--force-renewal)
    fi

    line
    if certbot "${args[@]}"; then
        log_ok "CertBot 续签完成"
    else
        log_error "CertBot 续签失败"
    fi
    break_end
}

acme_renew() {
    clear
    echo -e "${gl_zi}>>> ACME 证书续签${gl_bai}"
    line
    ensure_acme || { break_end; return; }

    read_value "请输入域名 (留空续签全部)" ""
    local domain="$REPLY_VALUE"
    local force=0
    if confirm_yes "是否强制续签?" "n"; then
        force=1
    fi

    line
    local args=()
    if [ -z "$domain" ]; then
        args=(--cron --home "$ACME_HOME")
        if [ "$force" -eq 1 ]; then
            log_warn "全部续签不支持强制续签, 将按到期时间自动续签"
        fi
    else
        if ! validate_domain "$domain"; then
            log_error "域名格式不正确"
            break_end
            return
        fi
        args=(--renew -d "$domain")
        [ "$force" -eq 1 ] && args+=(--force)
    fi

    if "$ACME_BIN" "${args[@]}"; then
        log_ok "ACME 续签完成"
    else
        log_error "ACME 续签失败"
    fi
    break_end
}

certbot_revoke() {
    clear
    echo -e "${gl_zi}>>> CertBot 撤销并删除证书${gl_bai}"
    line
    if ! command_exists certbot; then
        log_error "未安装 CertBot"
        break_end
        return
    fi

    read_value "请输入证书名称" ""
    local name="$REPLY_VALUE"
    if [ -z "$name" ] || ! [[ "$name" =~ ^[A-Za-z0-9._-]+$ ]]; then
        log_error "证书名称格式不正确"
        break_end
        return
    fi
    local cert_path="/etc/letsencrypt/live/$name/cert.pem"
    if [ ! -f "$cert_path" ]; then
        log_error "未找到证书: $cert_path"
        break_end
        return
    fi
    if ! confirm_yes "确认撤销并删除证书 ${name} ?" "n"; then
        cancel_return "撤销/删除菜单"
        return
    fi

    if certbot revoke --cert-path "$cert_path" --non-interactive; then
        log_ok "证书已撤销"
        certbot delete --cert-name "$name" --non-interactive
        log_ok "证书已删除"
    else
        log_error "撤销证书失败"
    fi
    break_end
}

acme_revoke() {
    clear
    echo -e "${gl_zi}>>> ACME 撤销并删除证书${gl_bai}"
    line
    ensure_acme || { break_end; return; }

    read_value "请输入域名" ""
    local domain="$REPLY_VALUE"
    if ! validate_domain "$domain"; then
        log_error "域名格式不正确"
        break_end
        return
    fi
    if ! confirm_yes "确认撤销并删除证书 ${domain} ?" "n"; then
        cancel_return "撤销/删除菜单"
        return
    fi

    if "$ACME_BIN" --revoke -d "$domain"; then
        log_ok "证书已撤销"
        "$ACME_BIN" --remove -d "$domain"
        log_ok "证书记录已删除"
    else
        log_error "撤销证书失败"
    fi
    break_end
}

revoke_menu() {
    while true; do
        clear
        echo -e "${gl_zi}>>> 撤销 / 删除证书${gl_bai}"
        line
        echo -e "${gl_bufan}1.  ${gl_bai}CertBot 撤销并删除"
        echo -e "${gl_bufan}2.  ${gl_bai}ACME 撤销并删除"
        line
        echo -e "${gl_hong}0.  ${gl_bai}返回证书管理"
        line
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" choice
        case "$choice" in
            1) certbot_revoke ;;
            2) acme_revoke ;;
            0) cancel_return "证书管理"; return ;;
            *) handle_invalid_input ;;
        esac
    done
}

check_cert_expiry() {
    clear
    echo -e "${gl_zi}>>> 检查证书有效期${gl_bai}"
    line
    if ! command_exists openssl; then
        log_error "未安装 openssl"
        break_end
        return
    fi

    read_value "请输入证书文件路径" "/etc/nginx/ssl/cert.pem"
    local path="$REPLY_VALUE"
    if [ ! -f "$path" ]; then
        log_error "证书文件不存在: $path"
        break_end
        return
    fi

    openssl x509 -in "$path" -noout -subject -issuer -dates 2>/dev/null
    line
    local end_date=""
    end_date=$(openssl x509 -in "$path" -noout -enddate 2>/dev/null | cut -d= -f2)
    if [ -n "$end_date" ]; then
        local end_epoch=""
        local now_epoch=""
        end_epoch=$(date -d "$end_date" +%s 2>/dev/null || true)
        now_epoch=$(date +%s)
        if [ -n "$end_epoch" ]; then
            local days=$(( (end_epoch - now_epoch) / 86400 ))
            if [ "$days" -lt 0 ]; then
                log_error "证书已过期 ${days#-} 天"
            elif [ "$days" -le 7 ]; then
                log_error "证书将在 ${days} 天后过期"
            elif [ "$days" -le 30 ]; then
                log_warn "证书将在 ${days} 天后过期"
            else
                log_ok "证书有效期剩余 ${days} 天"
            fi
        else
            log_warn "无法计算剩余天数, 到期时间: $end_date"
        fi
    fi
    break_end
}

setup_auto_renew() {
    clear
    echo -e "${gl_zi}>>> 配置自动续签${gl_bai}"
    line
    mkdir -p /etc/cron.d

    local created=0
    if command_exists certbot; then
        local certbot_bin=""
        certbot_bin="$(command -v certbot)"
        cat > /etc/cron.d/certbot-renew <<EOF
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
0 3 * * * root "$certbot_bin" renew --quiet --deploy-hook "systemctl reload nginx 2>/dev/null || true"
EOF
        chmod 644 /etc/cron.d/certbot-renew
        log_ok "CertBot 自动续签任务已写入 /etc/cron.d/certbot-renew"
        created=1
    else
        log_warn "未安装 CertBot, 跳过 CertBot 自动续签"
    fi

    refresh_acme_env
    if [ -n "$ACME_BIN" ]; then
        cat > /etc/cron.d/acme-renew <<EOF
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
0 0 * * * root "$ACME_BIN" --cron --home "$ACME_HOME" >/dev/null 2>&1
EOF
        chmod 644 /etc/cron.d/acme-renew
        log_ok "ACME 自动续签任务已写入 /etc/cron.d/acme-renew"
        created=1
    else
        log_warn "未安装 acme.sh, 跳过 ACME 自动续签"
    fi

    if [ "$created" -eq 0 ]; then
        log_error "未检测到 CertBot 或 acme.sh"
    fi
    line
    log_info "当前任务:"
    [ -f /etc/cron.d/certbot-renew ] && cat /etc/cron.d/certbot-renew
    [ -f /etc/cron.d/acme-renew ] && cat /etc/cron.d/acme-renew
    line
    break_end
}

cert_manage_menu() {
    while true; do
        clear
        echo -e "${gl_zi}>>> 证书管理${gl_bai}"
        line
        echo -e "${gl_bufan}1.  ${gl_bai}查看所有证书"
        echo -e "${gl_bufan}2.  ${gl_bai}CertBot 续签"
        echo -e "${gl_bufan}3.  ${gl_bai}ACME 续签"
        echo -e "${gl_bufan}4.  ${gl_bai}撤销 / 删除证书"
        echo -e "${gl_bufan}5.  ${gl_bai}检查证书有效期"
        echo -e "${gl_bufan}6.  ${gl_bai}配置自动续签"
        line
        echo -e "${gl_hong}0.  ${gl_bai}返回主菜单"
        line
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" choice
        case "$choice" in
            1) show_current_certs ;;
            2) certbot_renew ;;
            3) acme_renew ;;
            4) revoke_menu ;;
            5) check_cert_expiry ;;
            6) setup_auto_renew ;;
            0) cancel_return "主菜单"; return ;;
            *) handle_invalid_input ;;
        esac
    done
}

deploy_acme_cert() {
    clear
    echo -e "${gl_zi}>>> ACME 证书部署到 Nginx${gl_bai}"
    line
    ensure_acme || { break_end; return; }

    read_value "请输入证书主域名" ""
    local domain="$REPLY_VALUE"
    if ! validate_domain "$domain"; then
        log_error "域名格式不正确"
        break_end
        return
    fi

    local safe=""
    safe="$(safe_name "$domain")"
    read_value "请输入目标目录" "/etc/nginx/ssl/$safe"
    local target="$REPLY_VALUE"
    if ! [[ "$target" =~ ^/[A-Za-z0-9._/-]+$ ]]; then
        log_error "目标目录格式不正确"
        break_end
        return
    fi
    read_value "请输入重载命令" "systemctl reload nginx"
    local reload_cmd="$REPLY_VALUE"

    mkdir -p "$target"
    chmod 755 "$target"
    line
    if "$ACME_BIN" --install-cert -d "$domain" \
        --key-file "$target/key.pem" \
        --fullchain-file "$target/cert.pem" \
        --reloadcmd "$reload_cmd"; then
        chmod 644 "$target/cert.pem" 2>/dev/null || true
        chmod 600 "$target/key.pem" 2>/dev/null || true
        log_ok "证书部署完成"
        log_info "证书: $target/cert.pem"
        log_info "私钥: $target/key.pem"
    else
        log_error "证书部署失败"
    fi
    break_end
}

deploy_certbot_cert() {
    clear
    echo -e "${gl_zi}>>> CertBot 证书部署到 Nginx${gl_bai}"
    line

    read_value "请输入 CertBot 证书名称" ""
    local name="$REPLY_VALUE"
    if [ -z "$name" ] || ! [[ "$name" =~ ^[A-Za-z0-9._-]+$ ]]; then
        log_error "证书名称格式不正确"
        break_end
        return
    fi
    local src="/etc/letsencrypt/live/$name"
    if [ ! -f "$src/fullchain.pem" ] || [ ! -f "$src/privkey.pem" ]; then
        log_error "未找到证书: $src"
        break_end
        return
    fi

    local safe=""
    safe="$(safe_name "$name")"
    read_value "请输入目标目录" "/etc/nginx/ssl/$safe"
    local target="$REPLY_VALUE"
    if ! [[ "$target" =~ ^/[A-Za-z0-9._/-]+$ ]]; then
        log_error "目标目录格式不正确"
        break_end
        return
    fi
    read_value "请输入重载命令" "systemctl reload nginx"
    local reload_cmd="$REPLY_VALUE"

    mkdir -p "$target"
    chmod 755 "$target"
    cp -L "$src/fullchain.pem" "$target/cert.pem"
    cp -L "$src/privkey.pem" "$target/key.pem"
    chmod 644 "$target/cert.pem"
    chmod 600 "$target/key.pem"

    local hook_dir="/etc/letsencrypt/renewal-hooks/deploy"
    mkdir -p "$hook_dir"
    local hook="$hook_dir/${safe}.sh"
    cat > "$hook" <<EOF
#!/bin/bash
set -e
mkdir -p "$target"
cp -L "$src/fullchain.pem" "$target/cert.pem"
cp -L "$src/privkey.pem" "$target/key.pem"
chmod 644 "$target/cert.pem"
chmod 600 "$target/key.pem"
$reload_cmd
EOF
    chmod +x "$hook"

    line
    if bash "$hook"; then
        log_ok "证书部署完成"
        log_info "证书: $target/cert.pem"
        log_info "私钥: $target/key.pem"
        log_info "续签钩子: $hook"
    else
        log_error "部署或重载失败, 请检查命令"
    fi
    break_end
}

generate_nginx_conf() {
    clear
    echo -e "${gl_zi}>>> 生成 Nginx 反向代理配置${gl_bai}"
    line

    read_value "请输入域名 (多个用空格分隔)" ""
    local server_name="$REPLY_VALUE"
    if ! [[ "$server_name" =~ ^[A-Za-z0-9.*_-]+( [A-Za-z0-9.*_-]+)*$ ]]; then
        log_error "域名格式不正确"
        break_end
        return
    fi

    read_value "请输入后端地址" "http://127.0.0.1:8080"
    local upstream="$REPLY_VALUE"
    if ! [[ "$upstream" =~ ^https?://[A-Za-z0-9._:/-]+$ ]]; then
        log_error "后端地址格式不正确, 示例: http://127.0.0.1:8080"
        break_end
        return
    fi

    read_value "请输入监听端口" "443"
    local port="$REPLY_VALUE"
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        log_error "端口格式不正确"
        break_end
        return
    fi

    read_value "请输入证书路径" "/etc/nginx/ssl/cert.pem"
    local cert="$REPLY_VALUE"
    read_value "请输入私钥路径" "/etc/nginx/ssl/key.pem"
    local key="$REPLY_VALUE"
    if ! [[ "$cert" =~ ^/[A-Za-z0-9._/-]+$ ]] || ! [[ "$key" =~ ^/[A-Za-z0-9._/-]+$ ]]; then
        log_error "证书或私钥路径格式不正确"
        break_end
        return
    fi

    local file=""
    file="$(safe_name "$server_name")"
    local conf="/etc/nginx/conf.d/${file}.conf"
    if [ -f "$conf" ]; then
        if ! confirm_yes "配置文件已存在, 是否覆盖?" "n"; then
            cancel_return "证书部署"
            return
        fi
    fi

    mkdir -p /etc/nginx/conf.d
    {
        printf 'server {\n'
        printf '    listen %s ssl;\n' "$port"
        printf '    listen [::]:%s ssl;\n' "$port"
        printf '    server_name %s;\n' "$server_name"
        printf '\n'
        printf '    ssl_certificate %s;\n' "$cert"
        printf '    ssl_certificate_key %s;\n' "$key"
        printf '    ssl_session_cache shared:SSL:10m;\n'
        printf '    ssl_session_timeout 10m;\n'
        printf '    ssl_protocols TLSv1.2 TLSv1.3;\n'
        printf '    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;\n'
        printf '    ssl_prefer_server_ciphers on;\n'
        printf '    server_tokens off;\n'
        printf '\n'
        printf '    add_header X-Frame-Options DENY always;\n'
        printf '    add_header X-Content-Type-Options nosniff always;\n'
        printf '    add_header X-XSS-Protection "1; mode=block" always;\n'
        printf '\n'
        printf '    client_max_body_size 100m;\n'
        printf '\n'
        printf '    location / {\n'
        printf '        proxy_pass %s;\n' "$upstream"
        printf '        proxy_set_header Host $host;\n'
        printf '        proxy_set_header X-Real-IP $remote_addr;\n'
        printf '        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\n'
        printf '        proxy_set_header X-Forwarded-Proto $scheme;\n'
        printf '        proxy_http_version 1.1;\n'
        printf '        proxy_set_header Upgrade $http_upgrade;\n'
        printf '        proxy_set_header Connection "upgrade";\n'
        printf '        proxy_connect_timeout 60s;\n'
        printf '        proxy_send_timeout 60s;\n'
        printf '        proxy_read_timeout 60s;\n'
        printf '    }\n'
        printf '}\n'
        if [ "$port" = "443" ]; then
            printf '\n'
            printf 'server {\n'
            printf '    listen 80;\n'
            printf '    listen [::]:80;\n'
            printf '    server_name %s;\n' "$server_name"
            printf '    return 301 https://$host$request_uri;\n'
            printf '}\n'
        fi
    } > "$conf"

    line
    log_ok "配置已写入: $conf"
    if command_exists nginx; then
        if nginx -t; then
            if reload_nginx; then
                log_ok "Nginx 已重载"
            else
                log_error "Nginx 重载失败, 请手动重载"
            fi
        else
            log_error "Nginx 配置检查失败, 请手动修复"
        fi
    else
        log_warn "未安装 Nginx, 配置已保留"
    fi
    break_end
}

convert_cert() {
    clear
    echo -e "${gl_zi}>>> 证书格式转换${gl_bai}"
    line
    if ! command_exists openssl; then
        log_error "未安装 openssl"
        break_end
        return
    fi

    local c=""
    echo -e "${gl_bufan}1.  ${gl_bai}PEM 转 PKCS12"
    echo -e "${gl_bufan}2.  ${gl_bai}PEM 转 DER"
    line
    read -r -e -p "$(echo -e "${gl_bai}请输入你的选择 [${gl_lv}1${gl_bai}]: ")" c
    c="${c:-1}"

    if [ "$c" = "2" ]; then
        read_value "请输入证书路径" "/etc/nginx/ssl/cert.pem"
        local cert="$REPLY_VALUE"
        read_value "请输入输出路径" "/etc/nginx/ssl/cert.der"
        local out="$REPLY_VALUE"
        if [ ! -f "$cert" ]; then
            log_error "证书文件不存在"
            break_end
            return
        fi
        if openssl x509 -in "$cert" -outform der -out "$out"; then
            log_ok "转换完成: $out"
        else
            log_error "转换失败"
        fi
    else
        read_value "请输入证书链路径" "/etc/nginx/ssl/cert.pem"
        local cert="$REPLY_VALUE"
        read_value "请输入私钥路径" "/etc/nginx/ssl/key.pem"
        local key="$REPLY_VALUE"
        read_value "请输入输出路径" "/etc/nginx/ssl/cert.p12"
        local out="$REPLY_VALUE"
        read_secret "请输入 PKCS12 密码 (可留空)"
        local pass="$REPLY_VALUE"
        if [ ! -f "$cert" ] || [ ! -f "$key" ]; then
            log_error "证书或私钥文件不存在"
            break_end
            return
        fi
        if openssl pkcs12 -export -in "$cert" -inkey "$key" -out "$out" -passout pass:"$pass"; then
            log_ok "转换完成: $out"
        else
            log_error "转换失败"
        fi
    fi
    break_end
}

test_reload_nginx() {
    clear
    echo -e "${gl_zi}>>> 测试并重载 Nginx${gl_bai}"
    line
    if ! command_exists nginx; then
        log_error "未安装 Nginx"
        break_end
        return
    fi
    if nginx -t; then
        if reload_nginx; then
            log_ok "Nginx 已重载"
        else
            log_error "Nginx 重载失败"
        fi
    else
        log_error "Nginx 配置检查失败"
    fi
    break_end
}

deploy_menu() {
    while true; do
        clear
        echo -e "${gl_zi}>>> 证书部署${gl_bai}"
        line
        echo -e "${gl_bufan}1.  ${gl_bai}ACME 证书部署到 Nginx"
        echo -e "${gl_bufan}2.  ${gl_bai}CertBot 证书部署到 Nginx"
        echo -e "${gl_bufan}3.  ${gl_bai}生成 Nginx 反向代理配置"
        echo -e "${gl_bufan}4.  ${gl_bai}证书格式转换"
        echo -e "${gl_bufan}5.  ${gl_bai}测试并重载 Nginx"
        line
        echo -e "${gl_hong}0.  ${gl_bai}返回主菜单"
        line
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" choice
        case "$choice" in
            1) deploy_acme_cert ;;
            2) deploy_certbot_cert ;;
            3) generate_nginx_conf ;;
            4) convert_cert ;;
            5) test_reload_nginx ;;
            0) cancel_return "主菜单"; return ;;
            *) handle_invalid_input ;;
        esac
    done
}

show_env_status() {
    clear
    echo -e "${gl_zi}>>> 环境状态${gl_bai}"
    line

    if command_exists certbot; then
        log_ok "CertBot: $(certbot --version 2>&1 | head -1)"
    else
        log_warn "CertBot: 未安装"
    fi

    refresh_acme_env
    if [ -n "$ACME_BIN" ]; then
        log_ok "ACME.sh: $("$ACME_BIN" -v 2>&1 | head -1)"
        log_info "ACME 目录: $ACME_HOME"
    else
        log_warn "ACME.sh: 未安装"
    fi

    if [ -f "$CF_INI" ]; then
        log_ok "CertBot Cloudflare 配置: 已配置"
    else
        log_warn "CertBot Cloudflare 配置: 未配置"
    fi

    if [ -f "$ACME_CF_ENV" ]; then
        log_ok "ACME Cloudflare 配置: 已配置"
    else
        log_warn "ACME Cloudflare 配置: 未配置"
    fi

    if command_exists nginx; then
        log_ok "Nginx: $(nginx -v 2>&1)"
        if command_exists systemctl; then
            log_info "Nginx 状态: $(systemctl is-active nginx 2>/dev/null || true)"
        fi
    else
        log_warn "Nginx: 未安装"
    fi

    if command_exists openssl; then
        log_ok "OpenSSL: $(openssl version 2>/dev/null)"
    else
        log_warn "OpenSSL: 未安装"
    fi
    line
    break_end
}

env_menu() {
    while true; do
        clear
        echo -e "${gl_zi}>>> 环境安装与配置${gl_bai}"
        line
        echo -e "${gl_bufan}1.  ${gl_bai}安装 CertBot + Cloudflare 插件"
        echo -e "${gl_bufan}2.  ${gl_bai}安装 / 升级 ACME.sh"
        echo -e "${gl_bufan}3.  ${gl_bai}配置 Cloudflare API Token"
        echo -e "${gl_bufan}4.  ${gl_bai}设置 ACME 默认 CA"
        echo -e "${gl_bufan}5.  ${gl_bai}查看环境状态"
        line
        echo -e "${gl_hong}0.  ${gl_bai}返回主菜单"
        line
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" choice
        case "$choice" in
            1) install_certbot ;;
            2) install_acme ;;
            3) configure_cloudflare ;;
            4) acme_set_ca ;;
            5) show_env_status ;;
            0) cancel_return "主菜单"; return ;;
            *) handle_invalid_input ;;
        esac
    done
}

certbot_menu() {
    while true; do
        clear
        echo -e "${gl_zi}>>> CertBot 申请${gl_bai}"
        line
        echo -e "${gl_bufan}1.  ${gl_bai}DNS 手动验证申请"
        echo -e "${gl_bufan}2.  ${gl_bai}Cloudflare API 自动验证申请"
        echo -e "${gl_bufan}3.  ${gl_bai}申请测试证书 (Staging)"
        line
        echo -e "${gl_hong}0.  ${gl_bai}返回主菜单"
        line
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" choice
        case "$choice" in
            1) certbot_issue_manual ;;
            2) certbot_issue_cloudflare 0 ;;
            3) certbot_issue_cloudflare 1 ;;
            0) cancel_return "主菜单"; return ;;
            *) handle_invalid_input ;;
        esac
    done
}

acme_menu() {
    while true; do
        clear
        echo -e "${gl_zi}>>> ACME 申请${gl_bai}"
        line
        echo -e "${gl_bufan}1.  ${gl_bai}Cloudflare API 自动验证申请"
        echo -e "${gl_bufan}2.  ${gl_bai}DNS 手动验证申请"
        echo -e "${gl_bufan}3.  ${gl_bai}申请测试证书 (Staging)"
        echo -e "${gl_bufan}4.  ${gl_bai}设置默认 CA"
        line
        echo -e "${gl_hong}0.  ${gl_bai}返回主菜单"
        line
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" choice
        case "$choice" in
            1) acme_issue_cloudflare 0 ;;
            2) acme_issue_manual ;;
            3) acme_issue_cloudflare 1 ;;
            4) acme_set_ca ;;
            0) cancel_return "主菜单"; return ;;
            *) handle_invalid_input ;;
        esac
    done
}

main() {
    check_root
    refresh_acme_env
    while true; do
        show_main_menu
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" choice
        case "$choice" in
            1) certbot_menu ;;
            2) acme_menu ;;
            3) cert_manage_menu ;;
            4) deploy_menu ;;
            5) env_menu ;;
            0|00) exit_script ;;
            *) handle_invalid_input ;;
        esac
    done
}

main "$@"
