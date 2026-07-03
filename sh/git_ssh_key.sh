#!/usr/bin/env bash
set -uo pipefail

gl_hui='\e[37m'
gl_hong='\033[31m'
gl_lv='\033[32m'
gl_huang='\033[33m'
gl_lan='\033[34m'
gl_zi='\033[35m'
gl_bufan='\033[96m'
gl_bai='\033[0m'

sleep_fractional() {
    local seconds=$1
    if sleep "$seconds" 2>/dev/null; then return 0; fi
    if command -v perl >/dev/null 2>&1; then perl -e "select(undef, undef, undef, $seconds)"; return 0; fi
    if command -v python3 >/dev/null 2>&1; then python3 -c "import time; time.sleep($seconds)"; return 0; fi
    if command -v python >/dev/null 2>&1; then python -c "import time; time.sleep($seconds)"; return 0; fi
    local int_seconds=$(echo "$seconds" | awk '{print int($1+0.999)}')
    sleep "$int_seconds"
}

exit_animation() {
    echo -ne "\r${gl_lv}即将退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo ""
}

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    read -r -n 1 -s -p ""
    echo ""
    clear
}

exit_script() {
    echo ""
    echo -ne "${gl_hong}感谢使用，再见！ ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    clear
    exit 0
}

handle_invalid_input() {
    echo -ne "\r\033[K${gl_huang}无效的输入,请重新输入! ${gl_zi} 1 ${gl_huang} 秒后返回"
    sleep_fractional 1
    echo -ne "\r\033[K${gl_lv}无效的输入,请重新输入! ${gl_zi}0${gl_lv} 秒后返回"
    sleep_fractional 0.5
    echo -ne "\r\033[K"
    return 2
}

install() {
    [[ $# -eq 0 ]] && return 1
    for pkg in "$@"; do
        if command -v "$pkg" &>/dev/null; then continue; fi
        echo -e "\n${gl_huang}检查依赖：${gl_bai}$pkg${gl_bai}"
        if command -v apt &>/dev/null; then
            apt update -y && apt install -y "$pkg" >/dev/null 2>&1
        elif command -v dnf &>/dev/null; then
            dnf install -y "$pkg" >/dev/null 2>&1
        elif command -v yum &>/dev/null; then
            yum install -y "$pkg" >/dev/null 2>&1
        fi
    done
}

declare -A PLATFORMS=(
    [gitee]="gitee.com"
    [github]="github.com"
    [gitlab]="gitlab.com"
)
declare -A KEY_URLS=(
    [gitee]="https://gitee.com/profile/sshkeys"
    [github]="https://github.com/settings/keys"
    [gitlab]="https://gitlab.com/-/profile/keys"
)
declare -A SSH_HOSTS=(
    [gitee]="gitee.com"
    [github]="ssh.github.com"
    [gitlab]="gitlab.com"
)
declare -A SSH_PORTS=(
    [gitee]="22"
    [github]="443"
    [gitlab]="22"
)

log_info()  { echo -e "${gl_lan}[INFO]${gl_bai} $*"; }
log_ok()    { echo -e "${gl_lv}[OK ]${gl_bai} $*"; }
log_warn()  { echo -e "${gl_huang}[WARN]${gl_bai} $*"; }
log_error() { echo -e "${gl_hong}[ERR]${gl_bai} $*" >&2; }

select_platform() {
    local input="${1,,}"
    if [[ -n "$input" && -n "${PLATFORMS[$input]-}" ]]; then
        SELECTED="$input"
        return
    fi

    clear
    echo -e "${gl_zi}>>> SSH密钥一键配置${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}请选择你要配置的平台：${gl_bai}"
    echo -e "${gl_bufan}1.  ${gl_bai}Gitee"
    echo -e "${gl_bufan}2.  ${gl_bai}GitHub"
    echo -e "${gl_bufan}3.  ${gl_bai}GitLab"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_hong}0.  ${gl_bai}退出脚本"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" choice

    case "$choice" in
        1) SELECTED="gitee" ;;
        2) SELECTED="github" ;;
        3) SELECTED="gitlab" ;;
        0) exit_script ;; 
        *) handle_invalid_input ;;
    esac
}

init_config() {
    PLATFORM="$SELECTED"
    DOMAIN="${PLATFORMS[$PLATFORM]}"
    KEY_URL="${KEY_URLS[$PLATFORM]}"
    SSH_HOST="${SSH_HOSTS[$PLATFORM]}"
    SSH_PORT="${SSH_PORTS[$PLATFORM]}"
    KEY_FILE="$HOME/.ssh/id_rsa_$PLATFORM"
    EMAIL="user@$PLATFORM.com"
    COMMENT="auto@$PLATFORM"
}

show_key_url() {
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_huang}请打开以下地址添加公钥：${gl_bai}"
    echo -e "${gl_lv}$KEY_URL${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
}

generate_key() {
    log_info "生成 4096 位 RSA 密钥"
    if [ -f "$KEY_FILE" ]; then
        log_warn "密钥已存在：${gl_huang}$KEY_FILE${gl_bai}"
    else
        ssh-keygen -t rsa -b 4096 -C "$COMMENT" -f "$KEY_FILE" -N ""
        log_ok "密钥生成完成"
    fi
}

show_public_key() {
    log_info "你的公钥（请完整复制）："
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    cat "${KEY_FILE}.pub"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
     read -r -p "$(echo -e "${gl_bai}完成后按 Enter 继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}")" 
}

write_ssh_config() {
    log_info "写入 SSH 配置文件"
    mkdir -p ~/.ssh && chmod 700 ~/.ssh
    cat > ~/.ssh/config <<EOF
Host $DOMAIN
    User git
    Hostname $SSH_HOST
    Port $SSH_PORT
    IdentityFile $KEY_FILE
    IdentitiesOnly yes
    StrictHostKeyChecking no
    ServerAliveInterval 60
EOF
    chmod 600 ~/.ssh/config
    log_ok "SSH 配置已生效"
}

# ========== 修复：自动永久加载密钥（核心） ==========
auto_load_ssh_key() {
    log_info "设置开机自动加载SSH密钥（永久生效）"
    echo "" >> ~/.bashrc
    echo "# 自动加载 $PLATFORM SSH 密钥" >> ~/.bashrc
    echo "if ! ssh-add -l | grep -q '$KEY_FILE'; then" >> ~/.bashrc
    echo "    eval \$(ssh-agent -s) >/dev/null 2>&1" >> ~/.bashrc
    echo "    ssh-add $KEY_FILE >/dev/null 2>&1" >> ~/.bashrc
    echo "fi" >> ~/.bashrc
    chmod 600 "$KEY_FILE"
    chmod 600 "${KEY_FILE}.pub"
    eval "$(ssh-agent -s)"
    ssh-add "$KEY_FILE"
    log_ok "SSH密钥已永久自动加载"
}

add_known_hosts() {
    log_info "添加主机信任"
    ssh-keyscan -H "$DOMAIN" >> ~/.ssh/known_hosts 2>/dev/null || true
}

test_connection() {
    log_info "测试 SSH 连接"
    echo -e "${gl_huang}执行测试: ssh -T git@$DOMAIN${gl_bai}"
    ssh -T "git@$DOMAIN" || true
    log_ok "配置完成！出现欢迎语即成功"
}

main() {
    clear
    install git
    select_platform "${1:-}"
    init_config
    echo -e ""
    echo -e "${gl_zi}>>> 正在配置 ${PLATFORM^^} SSH 密钥${gl_bai}"
    show_key_url
    generate_key
    show_public_key
    write_ssh_config
    auto_load_ssh_key   # 新增：永久修复
    add_known_hosts
    test_connection
    echo -e "\n${gl_lv}全部配置完成！可直接使用 SSH 克隆/推送${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
    exit 0
}

main "$@"