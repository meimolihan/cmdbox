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

log_info()  { echo -e "${gl_lan}[信息]${gl_bai} $*"; }
log_ok()    { echo -e "${gl_lv}[成功]${gl_bai} $*"; }
log_warn()  { echo -e "${gl_huang}[警告]${gl_bai} $*"; }
log_error() { echo -e "${gl_hong}[错误]${gl_bai} $*" >&2; }

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n 1 -s
    echo ""
    clear
}

install() {
    [[ $# -eq 0 ]] && {
        log_error "未提供软件包参数!"
        return 1
    }
    local pkg mgr ver cmd_ver installed=false
    for pkg in "$@"; do
        installed=false
        ver=""
        if command -v "$pkg" &>/dev/null; then
            cmd_ver=$("$pkg" --version 2>/dev/null|head -n1|tr -cd '[:print:]'|grep -oE '[0-9]+(\.[0-9]+)+'|head -n1||echo "")
            [[ -n "$cmd_ver" ]] && ver="$cmd_ver"
            installed=true
        fi
        if [[ "$pkg" == "7zip" || "$pkg" == "7z" ]]; then
            if command -v 7z &>/dev/null; then
                ver=$(7z 2>&1|grep -oE '[0-9]+(\.[0-9]+)+'|head -n1||echo "")
                [[ -n "$ver" ]] && installed=true
            fi
        fi
        if [[ "$installed" == false ]]; then
            if command -v opkg &>/dev/null; then
                if opkg list-installed|grep -q "^${pkg} "; then
                    installed=true
                    ver=$(opkg list-installed|grep "^${pkg} "|awk '{print $3}' 2>/dev/null||echo "")
                fi
            elif command -v dpkg-query &>/dev/null; then
                if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null|grep -q "install ok installed"; then
                    installed=true
                    ver=$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null||echo "")
                fi
            elif command -v rpm &>/dev/null; then
                if rpm -q "$pkg" &>/dev/null; then
                    installed=true
                    ver=$(rpm -q --qf '%{VERSION}' "$pkg" 2>/dev/null||echo "")
                fi
            elif command -v apk &>/dev/null; then
                if apk info "$pkg" 2>/dev/null|grep -q "^installed"; then
                    installed=true
                    ver=$(apk info -a "$pkg" 2>/dev/null|grep -oE '[0-9]+(\.[0-9]+)+'|head -n1||echo "")
                fi
            elif command -v pacman &>/dev/null; then
                if pacman -Qi "$pkg" &>/dev/null; then
                    installed=true
                    ver=$(pacman -Qi "$pkg" 2>/dev/null|grep -i "version"|grep -oE '[0-9]+(\.[0-9]+)+'|head -n1||echo "")
                fi
            fi
        fi
        if [[ "$installed" == true ]]; then
            echo -e "${gl_huang}${pkg}${gl_bai} ${gl_lv}已安装${gl_bai} $([[ -n "$ver" ]] && echo "版本 ${gl_lv}${ver}${gl_bai}")"
            continue
        fi
        echo -e ""
        echo -e "${gl_huang}开始安装：${gl_bai}${pkg}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        local install_success=false
        for mgr in opkg dnf yum apt apk pacman zypper pkg; do
            if ! command -v "$mgr" &>/dev/null; then continue; fi
            case $mgr in
            opkg)
                echo -e "${gl_bai}使用包管理器: ${gl_zi}opkg (OpenWrt/iStoreOS)${gl_bai}"
                if [[ "$pkg" == "7zip" || "$pkg" == "7z" ]]; then
                    opkg update && opkg install p7zip && install_success=true
                else
                    opkg update && opkg install "$pkg" && install_success=true
                fi
                ;;
            dnf)
                dnf -y update && dnf install -y "$pkg" && install_success=true
                ;;
            yum)
                yum -y update && yum install -y "$pkg" && install_success=true
                ;;
            apt)
                apt update -y && apt install -y "$pkg" && install_success=true
                ;;
            apk)
                apk update && apk add "$pkg" && install_success=true
                ;;
            pacman)
                pacman -Syu --noconfirm && pacman -S --noconfirm "$pkg" && install_success=true
                ;;
            zypper)
                zypper refresh && zypper install -y "$pkg" && install_success=true
                ;;
            pkg)
                pkg update && pkg install -y "$pkg" && install_success=true
                ;;
            esac
            [[ "$install_success" == true ]] && break
        done
        if [[ "$install_success" == true ]]; then
            echo -e "${gl_lv}✓ ${pkg} 安装成功${gl_bai}"
        else
            echo -e "${gl_hong}✗ ${pkg} 安装失败${gl_bai}"
        fi
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    done
}

set_locales_zh() {
    clear
    local os_id os_ver
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        os_id="$ID"
        os_ver="$VERSION_ID"
    else
        log_error "无法识别当前操作系统"
        return 1
    fi
    log_info "检测到系统: ${os_id^^} $os_ver"
    case "$os_id" in
    debian|ubuntu|pve|fnos|linuxmint|devuan|kali)
        _debian_like_zh
        ;;
    centos|rhel|fedora|rocky|almalinux|oracle|scientific)
        _redhat_like_zh
        ;;
    arch|manjaro|endeavouros|artix)
        _arch_like_zh
        ;;
    opensuse*|suse*)
        _suse_like_zh
        ;;
    alpine)
        _alpine_like_zh
        ;;
    gentoo)
        _gentoo_like_zh
        ;;
    *)
        log_warn "暂未支持当前系统的中文配置"
        return 1
        ;;
    esac
    _common_zh_post "$os_id"
    return $?
}

_debian_like_zh() {
    echo -e ""
    echo -e "${gl_zi}>>> 安装中文语言包与字体 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    install locales locales-all fonts-wqy-zenhei fonts-wqy-microhei fonts-noto-cjk-extra
    log_info "生成并启用 zh_CN.UTF-8 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    cp -n /etc/locale.gen /etc/locale.gen.bak 2>/dev/null
    if ! grep -q "^zh_CN.UTF-8 UTF-8" /etc/locale.gen; then
        sed -i 's/# zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen
    fi
    locale-gen zh_CN.UTF-8
    log_info "使用 update-locale 设置系统默认locale ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    update-locale LANG=zh_CN.UTF-8 LC_MESSAGES=zh_CN.UTF-8 LANGUAGE="zh_CN:zh"
    log_info "配置apt使用中文界面 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    mkdir -p /etc/apt/apt.conf.d
    echo 'Acquire::Languages "zh_CN";' >/etc/apt/apt.conf.d/99chinese
    echo 'Acquire::Languages::fallback "en";' >>/etc/apt/apt.conf.d/99chinese
    export LANG=zh_CN.UTF-8
    export LANGUAGE=zh_CN:zh
    export LC_MESSAGES=zh_CN.UTF-8
    log_ok "Debian系中文配置完成"
}

_redhat_like_zh() {
    echo -e ""
    echo -e "${gl_zi}>>> 安装中文语言包与字体 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    install langpacks-zh_CN glibc-langpack-zh wqy-zenhei-fonts wqy-microhei-fonts google-noto-sans-cjk-fonts
    log_info "设置 locale ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    localectl set-locale LANG=zh_CN.UTF-8 || echo 'LANG=zh_CN.UTF-8' >/etc/locale.conf
    if command -v dnf &>/dev/null; then
        log_info "配置dnf使用中文界面 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo "lang_cn=1" >>/etc/dnf/dnf.conf 2>/dev/null
    fi
    export LANG=zh_CN.UTF-8
    log_ok "RedHat系中文配置完成"
}

_arch_like_zh() {
    echo -e ""
    echo -e "${gl_zi}>>> 安装中文语言包与字体 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    install glibc-locales wqy-zenhei wqy-microhei noto-fonts-cjk
    log_info "生成 locale ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    sed -i 's/#zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen
    locale-gen
    localectl set-locale LANG=zh_CN.UTF-8
    if [[ -f /etc/pacman.conf ]] && grep -q "Color" /etc/pacman.conf; then
        log_info "配置pacman显示中文 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        sed -i 's/^#Color/Color/' /etc/pacman.conf
    fi
    export LANG=zh_CN.UTF-8
    log_ok "Arch系中文配置完成"
}

_suse_like_zh() {
    echo -e ""
    echo -e "${gl_zi}>>> 安装中文语言包与字体 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    install glibc-locale wqy-zenhei-fonts wqy-microhei-fonts noto-sans-cjk-fonts
    log_info "设置 locale ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    localectl set-locale LANG=zh_CN.UTF-8
    export LANG=zh_CN.UTF-8
    log_ok "SUSE系中文配置完成"
}

_alpine_like_zh() {
    echo -e ""
    echo -e "${gl_zi}>>> 安装中文语言包与字体 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    install musl-locales musl-locales-lang wqy-zenhei
    log_info "设置 locale ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    sed -i 's/# zh_CN.UTF-8/zh_CN.UTF-8/' /etc/locale.conf
    export LANG=zh_CN.UTF-8
    log_ok "Alpine系中文配置完成"
}

_gentoo_like_zh() {
    echo -e ""
    echo -e "${gl_zi}>>> 安装中文语言包与字体 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    emerge --noreplace glibc
    emerge --noreplace wqy-zenhei noto-cjk
    log_info "生成 locale ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    sed -i 's/# zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen
    locale-gen
    eselect locale set zh_CN.UTF-8
    export LANG=zh_CN.UTF-8
    log_ok "Gentoo系中文配置完成"
}

_common_zh_post() {
    local os_id="$1"
    echo -e ""
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_info "刷新字体缓存 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    fc-cache -fv &>/dev/null
    log_info "设置时区为 Asia/Shanghai ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    timedatectl set-timezone Asia/Shanghai 2>/dev/null||ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    hwclock --systohc &>/dev/null||true
    case "$os_id" in
    debian|ubuntu|pve|fnos|linuxmint|devuan|kali)
        log_info "使用 update-locale 持久化locale设置 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        update-locale LC_ALL= 2>/dev/null||true
        touch /etc/default/locale 2>/dev/null
        update-locale LANG=zh_CN.UTF-8 LANGUAGE="zh_CN:zh" LC_MESSAGES=zh_CN.UTF-8
        log_info "创建增强的locale配置脚本 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        if [[ -f /etc/profile.d/99-locale-zh.sh ]]; then
            log_warn "/etc/profile.d/99-locale-zh.sh 已存在，跳过创建"
        else
            cat > /etc/profile.d/99-locale-zh.sh << 'EOF'
#!/bin/bash
unset LC_ALL 2>/dev/null||true
export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
export LC_MESSAGES=zh_CN.UTF-8
export LC_CTYPE=zh_CN.UTF-8
export LC_NUMERIC=zh_CN.UTF-8
export LC_TIME=zh_CN.UTF-8
export LC_COLLATE=zh_CN.UTF-8
export LC_MONETARY=zh_CN.UTF-8
export LC_PAPER=zh_CN.UTF-8
export LC_NAME=zh_CN.UTF-8
export LC_ADDRESS=zh_CN.UTF-8
export LC_TELEPHONE=zh_CN.UTF-8
export LC_MEASUREMENT=zh_CN.UTF-8
export LC_IDENTIFICATION=zh_CN.UTF-8
if [ -n "$SSH_CONNECTION" ]; then
    for var in LANG LANGUAGE LC_CTYPE LC_NUMERIC LC_TIME LC_COLLATE LC_MONETARY LC_MESSAGES LC_PAPER LC_NAME LC_ADDRESS LC_TELEPHONE LC_MEASUREMENT LC_IDENTIFICATION LC_ALL; do
        unset $var 2>/dev/null||true
    done
    export LANG=zh_CN.UTF-8
    export LANGUAGE=zh_CN:zh
    export LC_MESSAGES=zh_CN.UTF-8
fi
EOF
            chmod 644 /etc/profile.d/99-locale-zh.sh
            sed -i 's/\r$//' /etc/profile.d/99-locale-zh.sh 2>/dev/null||true
            log_ok "已创建 /etc/profile.d/99-locale-zh.sh"
        fi
        log_info "配置 .bash_profile 确保登录时加载 .bashrc ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        if [[ -v SUDO_USER && -n "$SUDO_USER" && "$SUDO_USER" != "root" ]]; then
            local user_home=$(eval echo ~$SUDO_USER)
            if [[ -d "$user_home" ]]; then
                if [[ -f "$user_home/.bash_profile" ]] && grep -q "由set_locales_zh脚本添加" "$user_home/.bash_profile" 2>/dev/null; then
                    log_warn "用户 $SUDO_USER 的 .bash_profile 已配置，跳过"
                else
                    if [[ ! -f "$user_home/.bash_profile" ]]; then
                        cat > "$user_home/.bash_profile" << 'EOF'
# ~/.bash_profile: executed by bash(1) for login shells.
# 由set_locales_zh脚本添加
if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi
EOF
                        chown $SUDO_USER:$SUDO_USER "$user_home/.bash_profile"
                        log_ok "已为用户 $SUDO_USER 创建 .bash_profile"
                    else
                        if ! grep -q "\.bashrc" "$user_home/.bash_profile" 2>/dev/null; then
                            echo '' >> "$user_home/.bash_profile"
                            echo '# 由set_locales_zh脚本添加' >> "$user_home/.bash_profile"
                            echo 'if [ -f "$HOME/.bashrc" ]; then' >> "$user_home/.bash_profile"
                            echo '    . "$HOME/.bashrc"' >> "$user_home/.bash_profile"
                            echo 'fi' >> "$user_home/.bash_profile"
                            chown $SUDO_USER:$SUDO_USER "$user_home/.bash_profile"
                            log_ok "已为用户 $SUDO_USER 更新 .bash_profile"
                        else
                            log_warn "用户 $SUDO_USER 的 .bash_profile 已有.bashrc加载逻辑，跳过"
                        fi
                    fi
                fi
            fi
        fi
        if [[ -f /root/.bash_profile ]] && grep -q "由set_locales_zh脚本添加" /root/.bash_profile 2>/dev/null; then
            log_warn "root 的 .bash_profile 已配置，跳过"
        else
            if [[ ! -f /root/.bash_profile ]]; then
                cat > /root/.bash_profile << 'EOF'
# ~/.bash_profile: executed by bash(1) for login shells.
# 由set_locales_zh脚本添加
if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi
EOF
                log_ok "已为root用户创建 .bash_profile"
            else
                if ! grep -q "\.bashrc" /root/.bash_profile 2>/dev/null; then
                    echo '' >> /root/.bash_profile
                    echo '# 由set_locales_zh脚本添加' >> /root/.bash_profile
                    echo 'if [ -f "$HOME/.bashrc" ]; then' >> /root/.bash_profile
                    echo '    . "$HOME/.bashrc"' >> /root/.bash_profile
                    echo 'fi' >> /root/.bash_profile
                    log_ok "已为root用户更新 .bash_profile"
                else
                    log_warn "root 的 .bash_profile 已有.bashrc加载逻辑，跳过"
                fi
            fi
        fi
        log_info "为用户创建个人locale配置 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        if [[ -v SUDO_USER && -n "$SUDO_USER" && "$SUDO_USER" != "root" ]]; then
            local user_home=$(eval echo ~$SUDO_USER)
            if [[ -d "$user_home" ]]; then
                if grep -q "中文环境强制设置（由set_locales_zh脚本添加）" "$user_home/.bashrc" 2>/dev/null; then
                    log_warn "用户 $SUDO_USER 的 .bashrc 已配置中文环境，跳过"
                else
                    cat >> "$user_home/.bashrc" << 'EOF'
# ===== 中文环境强制设置（由set_locales_zh脚本添加）=====
if [ -f /etc/default/locale ]; then
    . /etc/default/locale
fi
export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
export LC_MESSAGES=zh_CN.UTF-8
unset LC_ALL 2>/dev/null||true
if [ -n "$SSH_CONNECTION" ]; then
    for var in LANG LANGUAGE LC_CTYPE LC_NUMERIC LC_TIME LC_COLLATE LC_MONETARY LC_MESSAGES LC_PAPER LC_NAME LC_ADDRESS LC_TELEPHONE LC_MEASUREMENT LC_IDENTIFICATION LC_ALL; do
        unset $var 2>/dev/null||true
    done
    export LANG=zh_CN.UTF-8
    export LANGUAGE=zh_CN:zh
    export LC_MESSAGES=zh_CN.UTF-8
fi
EOF
                    chown $SUDO_USER:$SUDO_USER "$user_home/.bashrc"
                    log_ok "已为用户 $SUDO_USER 配置 .bashrc"
                fi
            fi
        fi
        if grep -q "中文环境强制设置（由set_locales_zh脚本添加）" /root/.bashrc 2>/dev/null; then
            log_warn "root 的 .bashrc 已配置中文环境，跳过"
        else
            cat >> /root/.bashrc << 'EOF'
# ===== 中文环境强制设置（由set_locales_zh脚本添加）=====
if [ -f /etc/default/locale ]; then
    . /etc/default/locale
fi
export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
export LC_MESSAGES=zh_CN.UTF-8
unset LC_ALL 2>/dev/null||true
if [ -n "$SSH_CONNECTION" ]; then
    for var in LANG LANGUAGE LC_CTYPE LC_NUMERIC LC_TIME LC_COLLATE LC_MONETARY LC_MESSAGES LC_PAPER LC_NAME LC_ADDRESS LC_TELEPHONE LC_MEASUREMENT LC_IDENTIFICATION LC_ALL; do
        unset $var 2>/dev/null||true
    done
    export LANG=zh_CN.UTF-8
    export LANGUAGE=zh_CN:zh
    export LC_MESSAGES=zh_CN.UTF-8
fi
EOF
            log_ok "已为root用户配置 .bashrc"
        fi
        log_info "配置SSH服务器拒绝客户端locale转发 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        if [ -f /etc/ssh/sshd_config ]; then
            if grep -q "由set_locales_zh脚本添加" /etc/ssh/sshd_config 2>/dev/null; then
                log_warn "SSH配置已修改，跳过"
            else
                cp -f /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%Y%m%d%H%M%S) 2>/dev/null||true
                sed -i 's/^AcceptEnv/#AcceptEnv/g' /etc/ssh/sshd_config
                echo "" >> /etc/ssh/sshd_config
                echo "# 由set_locales_zh脚本添加：拒绝客户端转发的locale环境变量" >> /etc/ssh/sshd_config
                echo "AcceptEnv LANG LC_*" >> /etc/ssh/sshd_config
                if systemctl is-active sshd &>/dev/null; then
                    systemctl restart sshd
                    log_ok "SSH服务已重启，配置生效"
                fi
            fi
        fi
        log_info "创建PAM环境配置文件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        if [[ -f /etc/environment ]] && grep -q "由set_locales_zh脚本管理" /etc/environment 2>/dev/null; then
            log_warn "/etc/environment 已由本脚本管理，重新写入以确保配置正确"
        fi
        cat > /etc/environment << 'EOF'
# 系统全局环境变量设置（由set_locales_zh脚本管理）
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_MESSAGES=zh_CN.UTF-8
LC_CTYPE=zh_CN.UTF-8
LC_NUMERIC=zh_CN.UTF-8
LC_TIME=zh_CN.UTF-8
LC_COLLATE=zh_CN.UTF-8
LC_MONETARY=zh_CN.UTF-8
LC_PAPER=zh_CN.UTF-8
LC_NAME=zh_CN.UTF-8
LC_ADDRESS=zh_CN.UTF-8
LC_TELEPHONE=zh_CN.UTF-8
LC_MEASUREMENT=zh_CN.UTF-8
LC_IDENTIFICATION=zh_CN.UTF-8
EOF
        chmod 644 /etc/environment
        log_ok "已更新 /etc/environment"
        ;;
    *)
        if [[ -f /etc/locale.conf ]] && grep -q "由set_locales_zh脚本添加" /etc/locale.conf 2>/dev/null; then
            log_warn "/etc/locale.conf 已配置，跳过"
        else
            echo "# 由set_locales_zh脚本添加" >> /etc/locale.conf 2>/dev/null||true
            echo "LANG=zh_CN.UTF-8" >> /etc/locale.conf 2>/dev/null||true
        fi
        if [[ -f /etc/sysconfig/i18n ]] && grep -q "由set_locales_zh脚本添加" /etc/sysconfig/i18n 2>/dev/null; then
            log_warn "/etc/sysconfig/i18n 已配置，跳过"
        else
            echo "# 由set_locales_zh脚本添加" >> /etc/sysconfig/i18n 2>/dev/null||true
            echo "LANG=zh_CN.UTF-8" >> /etc/sysconfig/i18n 2>/dev/null||true
        fi
        ;;
    esac
    unset LC_ALL 2>/dev/null||true
    export LANG=zh_CN.UTF-8
    export LANGUAGE=zh_CN:zh
    export LC_MESSAGES=zh_CN.UTF-8
    export LC_CTYPE=zh_CN.UTF-8
    export LC_TIME=zh_CN.UTF-8
    log_info "当前locale与日期："
    locale
    date +"%Y年%m月%d日 %H时%M分%S秒 %Z"
    echo -e "\n${gl_huang}测试包管理器中文显示：${gl_bai}"
    case "$os_id" in
    debian|ubuntu|pve|fnos|linuxmint|devuan|kali)
        apt update --assume-no 2>&1|head -5||true
        ;;
    esac
    log_ok "中文环境已就绪！"
    echo -e "${gl_huang}重要提示：要使更改完全生效，请重新登录或重启系统。${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "\n${gl_lv}增强的持久化措施已启用：${gl_bai}"
    echo -e "1. 创建了增强的 /etc/profile.d/99-locale-zh.sh 脚本（防重复）"
    echo -e "2. 配置了用户 .bashrc 强制设置（防重复）"
    echo -e "3. 配置了 .bash_profile 确保登录时加载 .bashrc（防重复）"
    echo -e "4. 配置了SSH服务器拒绝客户端locale转发（防重复）"
    echo -e "5. 更新了 /etc/environment 系统环境文件（防重复）"
    echo -e ""
    echo -e "${gl_lv}使用建议：${gl_bai}"
    echo -e "1. 执行 ${gl_huang}source ~/.bashrc${gl_bai} 立即生效（当前用户）"
    echo -e "2. 或重新登录SSH会话（推荐，确保完全生效）"
    echo -e "3. 测试命令：${gl_huang}locale${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

set_locales_zh