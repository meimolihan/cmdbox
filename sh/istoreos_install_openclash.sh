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
    read -r -n 1 -s _
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

exit_animation() {
    echo -ne "${gl_lv}即将退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
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

cancel_return() {
    local menu_name="${1:-上一级选单}"
    echo -ne "${gl_lv}即将返回 ${gl_huang}${menu_name} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo ""
    clear
}

handle_invalid_input() {
    echo -ne "\r${gl_hong}无效的输入，请重新输入 ${gl_zi} 2 ${gl_hong}秒后返回 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.3
    echo -ne "\r${gl_huang}无效的输入，请重新输入 ${gl_zi} 1 ${gl_huang}秒后返回 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.3
    echo -e "\r${gl_lv}无效的输入，请重新输入 ${gl_zi} 0 ${gl_lv}秒后返回 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    return 2
}

OpenClash_init_env() {
    OpenClash_detect_pkg_manager || return 1
    OpenClash_detect_firewall
    return 0
}

OpenClash_detect_pkg_manager() {
    if command -v opkg >/dev/null 2>&1; then
        OPENCLASH_PKG_MANAGER="opkg"
        OPENCLASH_PKG_EXT="ipk"
    elif command -v apk >/dev/null 2>&1; then
        OPENCLASH_PKG_MANAGER="apk"
        OPENCLASH_PKG_EXT="apk"
    else
        log_error "未检测到支持的包管理器(opkg/apk)"
        return 1
    fi
}

OpenClash_detect_firewall() {
    if command -v nft >/dev/null 2>&1; then
        OPENCLASH_FIREWALL_TYPE="nftables"
    else
        OPENCLASH_FIREWALL_TYPE="iptables"
    fi
}

OpenClash_install_optimized() {
    local pkg="$1"
    if opkg list-installed 2>/dev/null | grep -q "^${pkg} "; then
        log_info "${pkg} 已安装，跳过"
        return 0
    fi
    
    echo -e "${gl_bai}正在安装：${gl_huang}${pkg} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    ${OPENCLASH_PKG_MANAGER} install "$pkg"
    
    if [ $? -eq 0 ]; then
        log_ok "${pkg} 安装成功"
    else
        log_error "${pkg} 安装失败"
        return 1
    fi
}

OpenClash_install_dependencies() {
    if ! OpenClash_init_env; then
        return 1
    fi
    
    log_info "正在安装依赖 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    
    ${OPENCLASH_PKG_MANAGER} update
    
    if [ "${OPENCLASH_FIREWALL_TYPE:-}" = "iptables" ]; then
        local pkgs=("bash" "iptables" "dnsmasq-full" "curl" "ca-bundle" "ipset" "ip-full" "iptables-mod-tproxy" "iptables-mod-extra" "ruby" "ruby-yaml" "kmod-tun" "kmod-inet-diag" "unzip" "luci-compat" "luci" "luci-base")
    else
        local pkgs=("bash" "dnsmasq-full" "curl" "ca-bundle" "ip-full" "ruby" "ruby-yaml" "kmod-tun" "kmod-inet-diag" "unzip" "kmod-nft-tproxy" "luci-compat" "luci" "luci-base")
    fi
    
    for pkg in "${pkgs[@]}"; do
        OpenClash_install_optimized "$pkg"
    done
    
    log_ok "依赖检查/安装完成"
}

OpenClash_get_latest_version() {
    log_info "正在获取最新版本 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    
    OPENCLASH_LATEST_VERSION=$(curl -s --max-time 5 https://api.github.com/repos/vernesong/OpenClash/releases/latest 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [ -z "$OPENCLASH_LATEST_VERSION" ]; then
        log_warn "无法从 GitHub API 获取版本，尝试其他方法"

        OPENCLASH_LATEST_VERSION=$(curl -s --max-time 5 https://github.com/vernesong/OpenClash/releases 2>/dev/null | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' | head -n1)
        
        if [ -z "$OPENCLASH_LATEST_VERSION" ]; then
            OPENCLASH_LATEST_VERSION="v0.47.071"
            log_warn "无法获取最新版本，使用默认版本: ${OPENCLASH_LATEST_VERSION}"
        else
            log_info "从页面获取到版本: ${OPENCLASH_LATEST_VERSION}"
        fi
    fi
    
    OPENCLASH_VERSION_NUMBER=${OPENCLASH_LATEST_VERSION#v}
    log_info "使用版本: ${OPENCLASH_LATEST_VERSION}"
}

OpenClash_download() {
    if ! OpenClash_init_env; then
        return 1
    fi
    
    OpenClash_get_latest_version
    
    OPENCLASH_DOWNLOAD_URL="https://github.com/vernesong/OpenClash/releases/download/${OPENCLASH_LATEST_VERSION}/luci-app-openclash_${OPENCLASH_VERSION_NUMBER}_all.${OPENCLASH_PKG_EXT}"
    OPENCLASH_OUTPUT_FILE="/tmp/openclash.${OPENCLASH_PKG_EXT}"
    
    log_info "正在下载: ${OPENCLASH_DOWNLOAD_URL}"
    
    rm -f "$OPENCLASH_OUTPUT_FILE"
    
    if command -v wget >/dev/null 2>&1; then
        wget -O "$OPENCLASH_OUTPUT_FILE" "$OPENCLASH_DOWNLOAD_URL"
    else
        curl -L -o "$OPENCLASH_OUTPUT_FILE" "$OPENCLASH_DOWNLOAD_URL"
    fi
    
    if [ $? -eq 0 ] && [ -f "$OPENCLASH_OUTPUT_FILE" ]; then
        if [ -f "$OPENCLASH_OUTPUT_FILE" ]; then
            if command -v wc >/dev/null 2>&1; then
                file_size=$(wc -c < "$OPENCLASH_OUTPUT_FILE")
            elif command -v ls >/dev/null 2>&1; then
                file_size=$(ls -l "$OPENCLASH_OUTPUT_FILE" 2>/dev/null | awk '{print $5}' 2>/dev/null)
            else
                file_size=0
            fi
            
            if [ "$file_size" -gt 10000 ]; then
                log_ok "下载完成: $OPENCLASH_OUTPUT_FILE (大小: $((file_size/1024))KB)"
            else
                log_warn "下载的文件可能不完整，大小: ${file_size}字节"
                rm -f "$OPENCLASH_OUTPUT_FILE"
                return 1
            fi
        else
            log_error "下载的文件不存在"
            return 1
        fi
    else
        log_error "下载失败"
        return 1
    fi
}

OpenClash_install() {
    if ! OpenClash_init_env; then
        return 1
    fi
    
    log_info "正在安装OpenClash ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    
    OPENCLASH_OUTPUT_FILE="/tmp/openclash.${OPENCLASH_PKG_EXT}"
    
    if [ ! -f "$OPENCLASH_OUTPUT_FILE" ]; then
        log_error "安装文件不存在: $OPENCLASH_OUTPUT_FILE"
        return 1
    fi
    
    if [ "$OPENCLASH_PKG_MANAGER" = "opkg" ]; then
        ${OPENCLASH_PKG_MANAGER} install "$OPENCLASH_OUTPUT_FILE"
    else
        ${OPENCLASH_PKG_MANAGER} add -q --force-overwrite --clean-protected --allow-untrusted "$OPENCLASH_OUTPUT_FILE"
    fi
    
    if [ $? -eq 0 ]; then
        log_ok "OpenClash安装成功！"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}安装完成，请按以下步骤操作:${gl_bai}"
        echo -e "${gl_bai}1. 访问 Web 界面: ${gl_lan}http://路由器IP/cgi-bin/luci/admin/services/openclash${gl_bai}"
        echo -e "${gl_bai}2. 在版本更新标签下下载 Clash 内核"
        echo -e "${gl_bai}3. 上传订阅配置文件"
        echo -e "${gl_bai}4. 启动服务"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    else
        log_error "OpenClash安装失败"
    fi
}

OpenClash_uninstall() {
    if ! OpenClash_init_env; then
        return 1
    fi
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_hong}警告: 这将卸载OpenClash${gl_bai}"
    echo -e "${gl_huang}配置文件会自动备份到 /tmp 目录${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    echo -e -n "${gl_bai}是否继续? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): "
    read -r confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        log_info "正在卸载OpenClash ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        
        if [ "$OPENCLASH_PKG_MANAGER" = "opkg" ]; then
            ${OPENCLASH_PKG_MANAGER} remove luci-app-openclash
        else
            ${OPENCLASH_PKG_MANAGER} del luci-app-openclash
        fi
        
        if [ $? -eq 0 ]; then
            log_ok "OpenClash卸载成功"
            echo -e "${gl_huang}配置文件已备份到 /tmp 目录${gl_bai}"
        else
            log_error "OpenClash卸载失败"
        fi
    else
        echo -e "${gl_huang}取消卸载${gl_bai}"
    fi
}

OpenClash_install_core() {
    while true; do
        clear
        echo -e "${gl_zi}>>> 安装 Clash 内核${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}Clash Premium 内核       ${gl_bufan}2.  ${gl_bai}Clash.Meta 内核"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e -n "${gl_bai}请选择(${gl_huang}0${gl_bai})返回: "
        read -r core_choice
        
        case $core_choice in
            1)
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                echo -e "${gl_huang}Clash Premium 内核安装步骤:${gl_bai}"
                echo -e "${gl_bai}1. 下载地址: ${gl_lan}https://github.com/Dreamacro/clash/releases${gl_bai}"
                echo -e "${gl_bai}2. 选择适合您架构的版本下载"
                echo -e "${gl_bai}3. 解压文件"
                echo -e "${gl_bai}4. 将二进制文件复制到: ${gl_huang}/etc/openclash/core/${gl_bai}"
                echo -e "${gl_bai}5. 重命名为: ${gl_huang}clash${gl_bai}"
                echo -e "${gl_bai}6. 给予执行权限: ${gl_huang}chmod +x /etc/openclash/core/clash${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                ;;
            2)
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                echo -e "${gl_huang}Clash.Meta 内核安装步骤:${gl_bai}"
                echo -e "${gl_bai}1. 下载地址: ${gl_lan}https://github.com/MetaCubeX/Clash.Meta/releases${gl_bai}"
                echo -e "${gl_bai}2. 选择适合您架构的版本下载"
                echo -e "${gl_bai}3. 解压文件"
                echo -e "${gl_bai}4. 将二进制文件复制到: ${gl_huang}/etc/openclash/core/${gl_bai}"
                echo -e "${gl_bai}5. 重命名为: ${gl_huang}clash_meta${gl_bai}"
                echo -e "${gl_bai}6. 给予执行权限: ${gl_huang}chmod +x /etc/openclash/core/clash_meta${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                ;;
            0) cancel_return; break ;;
            *) handle_invalid_input ;;
        esac
        break_end
    done
}

OpenClash_check_status() {
    if ! OpenClash_init_env; then
        return 1
    fi
    
    echo -e ""
    echo -e "${gl_zi}>>> 检查安装状态${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local oc_installed=0
    opkg list-installed 2>/dev/null | grep -qi "openclash" && oc_installed=1
    [ -d "/usr/lib/lua/luci/controller/openclash" ] && oc_installed=1
    [ -d "/etc/openclash" ] && oc_installed=1
    [ -f "/etc/init.d/openclash" ] && oc_installed=1

    if [ "$oc_installed" -eq 1 ]; then
        log_ok "OpenClash 已安装"
    else
        log_error "OpenClash 未安装"
    fi
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_lan}内核文件检查:${gl_bai}"
    if [ -f "/etc/openclash/core/clash" ]; then
        echo -e "✓ ${gl_lv}Clash Premium 内核已安装${gl_bai}"
        chmod +x /etc/openclash/core/clash 2>/dev/null
    else
        echo -e "✗ ${gl_huang}Clash Premium 内核未安装${gl_bai}"
    fi
    
    if [ -f "/etc/openclash/core/clash_meta" ]; then
        echo -e "✓ ${gl_lv}Clash.Meta 内核已安装${gl_bai}"
        chmod +x /etc/openclash/core/clash_meta 2>/dev/null
    else
        echo -e "✗ ${gl_huang}Clash.Meta 内核未安装${gl_bai}"
    fi
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_lan}系统信息:${gl_bai}"
    echo -e "包管理器: ${gl_lv}${OPENCLASH_PKG_MANAGER:-未检测到}${gl_bai}"
    echo -e "防火墙: ${gl_lv}${OPENCLASH_FIREWALL_TYPE:-未检测到}${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

OpenClash_cleanup_temp() {
    log_info "正在清理临时文件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    rm -f /tmp/openclash.ipk /tmp/openclash.apk
    log_ok "清理完成"
}

OpenClash_quick_install() {
    log_info "开始快速安装 OpenClash"
    
    if ! OpenClash_init_env; then
        return 1
    fi
    
    OpenClash_install_dependencies
    OpenClash_download
    OpenClash_install
    break_end
}

is_istoreos_system() {
    if [ ! -d "/usr/lib/lua/luci/controller" ]; then
        echo -e ""
        echo -en "\r${gl_hong}你这不是 ${gl_huang}iStoreOS${gl_hong} 系统！即将退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
        exit_animation
        return 1
    fi
    return 0
}

OpenClash_menu() {
    OpenClash_init_env
    while true; do
        is_istoreos_system || return 1
        clear
        echo -e "${gl_huang}>>> 系统信息:${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo "包管理器: ${gl_lv}${OPENCLASH_PKG_MANAGER:-未检测到}${gl_bai}"
        echo "防火墙: ${gl_lv}${OPENCLASH_FIREWALL_TYPE:-未检测到}${gl_bai}"
        echo "系统架构: ${gl_lv}$(uname -m)${gl_bai}"
        echo "内核版本: ${gl_lv}$(uname -r)${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e ""
        echo -e "${gl_zi}>>> OpenClash 安装管理${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}快速安装OpenClash      ${gl_bufan}2.  ${gl_bai}仅安装依赖"
        echo -e "${gl_bufan}3.  ${gl_bai}仅下载安装包           ${gl_bufan}4.  ${gl_bai}安装Clash内核"
        echo -e "${gl_bufan}5.  ${gl_bai}卸载OpenClash          ${gl_bufan}6.  ${gl_bai}检查安装状态"
        echo -e "${gl_bufan}7.  ${gl_bai}清理临时文件"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_hong}0.  ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e -n "${gl_bai}请输入你的选择: "
        read -r choice
        
        case $choice in
        1) OpenClash_quick_install ;;
        2) OpenClash_install_dependencies; break_end ;;
        3) OpenClash_download; break_end ;;
        4) OpenClash_install_core ;;
        5) OpenClash_uninstall; break_end ;;
        6) OpenClash_check_status ;;
        7) OpenClash_cleanup_temp; break_end ;;
        0) exit_script ;;
        *) handle_invalid_input ;;
        esac
    done
}

OpenClash_menu