#!/bin/bash

export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8

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

sleep_fractional() {
    local seconds=$1
    if sleep "$seconds" 2>/dev/null; then return 0; fi
    if command -v perl >/dev/null 2>&1; then perl -e "select(undef, undef, undef, $seconds)"; return 0; fi
    if command -v python3 >/dev/null 2>&1; then python3 -c "import time; time.sleep($seconds)"; return 0; fi
    if command -v python >/dev/null 2>&1; then python -c "import time; time.sleep($seconds)"; return 0; fi
    local int_seconds=$(awk -v s="$seconds" 'BEGIN{print int(s+0.999)}')
    sleep "$int_seconds"
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

exit_script() {
    echo ""
    echo -ne "${gl_hong}感谢使用，再见！ ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    clear
    exit 0
}

if ! command -v apt-get &> /dev/null; then
    log_error "此脚本仅支持基于 Debian/Ubuntu 的系统，请在支持 apt-get 的系统上运行！"
    exit 1
fi

REQUIRED_CMDS=("curl" "wget" "dpkg" "awk" "sed" "sysctl" "jq")
for cmd in "${REQUIRED_CMDS[@]}"; do
    if ! command -v $cmd &> /dev/null; then
        log_warn "缺少依赖：$cmd，正在安装 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        sudo apt-get update && sudo apt-get install -y $cmd > /dev/null 2>&1
    fi
done

ARCH=$(uname -m)
if [[ "$ARCH" != "aarch64" && "$ARCH" != "x86_64" ]]; then
    log_error "这个脚本只支持 ARM 和 x86_64 架构哦~ 您的系统架构是：$ARCH"
    exit 1
fi

CURRENT_ALGO=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
CURRENT_QDISC=$(sysctl net.core.default_qdisc | awk '{print $3}')

SYSCTL_CONF="/etc/sysctl.d/99-joeyblog.conf"

clean_sysctl_conf() {
    sudo touch "$SYSCTL_CONF"
    sudo sed -i '/net.core.default_qdisc/d' "$SYSCTL_CONF"
    sudo sed -i '/net.ipv4.tcp_congestion_control/d' "$SYSCTL_CONF"
}

ask_to_save() {
    read -r -e -p "$(echo -e "${gl_bufan}要将这些配置永久保存到 $SYSCTL_CONF 吗? (${gl_lv}y${gl_bai}/${gl_hong}n${gl_bai}): ")" SAVE
    if [[ "$SAVE" == "y" || "$SAVE" == "Y" ]]; then
        clean_sysctl_conf
        echo "net.core.default_qdisc=$QDISC" | sudo tee -a "$SYSCTL_CONF" > /dev/null
        echo "net.ipv4.tcp_congestion_control=$ALGO" | sudo tee -a "$SYSCTL_CONF" > /dev/null
        sudo sysctl --system > /dev/null 2>&1
        log_ok "更改已永久保存啦~"
    else
        log_warn "好吧，没有永久保存呢~"
    fi
}

get_installed_version() {
    dpkg -l | grep "linux-image" | grep "joeyblog" | awk '{print $2}' | sed 's/linux-image-//' | head -n 1
}

update_bootloader() {
    log_info "正在更新引导加载程序 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    if command -v update-grub &> /dev/null; then
        log_warn "检测到 GRUB，正在执行 update-grub ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        if sudo update-grub; then
            log_ok "GRUB 更新成功！"
            return 0
        else
            log_error "GRUB 更新失败！"
            return 1
        fi
    else
        log_warn "未找到 'update-grub'。您的系统可能使用 U-Boot 或其他引导程序。"
        log_warn "在许多 ARM 系统上，内核安装包会自动处理引导更新，通常无需手动操作。"
        log_warn "如果重启后新内核未生效，您可能需要手动更新引导配置，请参考您系统的文档。"
        return 0
    fi
}

install_packages() {
    if ! ls /tmp/linux-*.deb &> /dev/null; then
        log_error "未在 /tmp 目录下找到内核文件，安装中止。"
        return 1
    fi
    
    log_info "开始卸载旧版内核 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    INSTALLED_PACKAGES=$(dpkg -l | grep "joeyblog" | awk '{print $2}' | tr '\n' ' ')
    if [[ -n "$INSTALLED_PACKAGES" ]]; then
        sudo apt-get remove --purge $INSTALLED_PACKAGES -y > /dev/null 2>&1
    fi

    log_info "开始安装新内核 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    if sudo dpkg -i /tmp/linux-*.deb && update_bootloader; then
        log_ok "内核安装并配置完成！"
        read -r -e -p "$(echo -e "${gl_bufan}需要重启系统来加载新内核。是否立即重启? (${gl_lv}y${gl_bai}/${gl_hong}n${gl_bai}): ")" REBOOT_NOW
        if [[ "$REBOOT_NOW" == "y" || "$REBOOT_NOW" == "Y" ]]; then
            log_info "系统即将重启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            sudo reboot
        else
            log_warn "操作完成。请记得稍后手动重启 ('sudo reboot') 来应用新内核。"
        fi
    else
        log_error "内核安装或引导更新失败！系统可能处于不稳定状态。请不要重启并寻求手动修复！"
    fi
}

install_latest_version() {
    log_info "正在从 GitHub 获取最新版本信息 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    BASE_URL="https://api.github.com/repos/byJoey/Actions-bbr-v3/releases"
    RELEASE_DATA=$(curl -sL "$BASE_URL")
    if [[ -z "$RELEASE_DATA" ]]; then
        log_error "从 GitHub 获取版本信息失败。请检查网络连接或 API 状态。"
        return 1
    fi

    local ARCH_FILTER=""
    [[ "$ARCH" == "aarch64" ]] && ARCH_FILTER="arm64"
    [[ "$ARCH" == "x86_64" ]] && ARCH_FILTER="x86_64"

    LATEST_TAG_NAME=$(echo "$RELEASE_DATA" | jq -r --arg filter "$ARCH_FILTER" 'map(select(.tag_name | test($filter; "i"))) | sort_by(.published_at) | .[-1].tag_name')

    if [[ -z "$LATEST_TAG_NAME" || "$LATEST_TAG_NAME" == "null" ]]; then
        log_error "未找到适合当前架构 ($ARCH) 的最新版本。"
        return 1
    fi
    echo -e "${gl_bufan}检测到最新版本：${gl_lv}$LATEST_TAG_NAME${gl_bai}"

    INSTALLED_VERSION=$(get_installed_version)
    echo -e "${gl_bufan}当前已安装版本：${gl_lv}${INSTALLED_VERSION:-"未安装"}${gl_bai}"

    CORE_LATEST_VERSION="${LATEST_TAG_NAME#x86_64-}"
    CORE_LATEST_VERSION="${CORE_LATEST_VERSION#arm64-}"

    if [[ -n "$INSTALLED_VERSION" && "$INSTALLED_VERSION" == "$CORE_LATEST_VERSION"* ]]; then
        log_ok "您已安装最新版本，无需更新！"
        return 0
    fi

    log_warn "发现新版本或未安装内核，准备下载 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    ASSET_URLS=$(echo "$RELEASE_DATA" | jq -r --arg tag "$LATEST_TAG_NAME" '.[] | select(.tag_name == $tag) | .assets[].browser_download_url')
    
    rm -f /tmp/linux-*.deb

    for URL in $ASSET_URLS; do
        log_info "正在下载文件：$URL"
        wget -q --show-progress "$URL" -P /tmp/ || { log_error "下载失败：$URL"; return 1; }
    done
    
    install_packages
}

install_specific_version() {
    BASE_URL="https://api.github.com/repos/byJoey/Actions-bbr-v3/releases"
    RELEASE_DATA=$(curl -s "$BASE_URL")
    if [[ -z "$RELEASE_DATA" ]]; then
        log_error "从 GitHub 获取版本信息失败。请检查网络连接或 API 状态。"
        return 1
    fi

    local ARCH_FILTER=""
    [[ "$ARCH" == "aarch64" ]] && ARCH_FILTER="arm64"
    [[ "$ARCH" == "x86_64" ]] && ARCH_FILTER="x86_64"
    
    MATCH_TAGS=$(echo "$RELEASE_DATA" | jq -r --arg filter "$ARCH_FILTER" '.[] | select(.tag_name | test($filter; "i")) | .tag_name')

    if [[ -z "$MATCH_TAGS" ]]; then
        log_error "未找到适合当前架构的版本。"
        return 1
    fi

    echo -e "${gl_bai}以下为适用于当前架构的版本：${gl_bai}"
    IFS=$'\n' read -rd '' -a TAG_ARRAY <<<"$MATCH_TAGS"

    for i in "${!TAG_ARRAY[@]}"; do
        echo -e "${gl_bufan}$((i+1)). ${gl_huang}${TAG_ARRAY[$i]}${gl_bai}"
    done

    echo -e "${gl_bufan}——————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}请输入要安装的版本编号（输入 ${gl_bufan}0${gl_bai} 返回）: ")" CHOICE
    
    if [[ "$CHOICE" == "0" ]]; then
        return
    fi
    
    if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || (( CHOICE < 1 || CHOICE > ${#TAG_ARRAY[@]} )); then
        log_error "输入无效编号，取消操作。"
        return 1
    fi
    
    INDEX=$((CHOICE-1))
    SELECTED_TAG="${TAG_ARRAY[$INDEX]}"
    echo -e "${gl_bufan}已选择版本：${gl_lv}$SELECTED_TAG${gl_bai}"

    ASSET_URLS=$(echo "$RELEASE_DATA" | jq -r --arg tag "$SELECTED_TAG" '.[] | select(.tag_name == $tag) | .assets[].browser_download_url')
    
    rm -f /tmp/linux-*.deb
    
    for URL in $ASSET_URLS; do
        log_info "下载中：$URL"
        wget -q --show-progress "$URL" -P /tmp/ || { log_error "下载失败：$URL"; return 1; }
    done

    install_packages
}

show_main_menu() {
    while true; do
        clear
        echo -e "${gl_zi}>>> BBR 管理脚本${gl_bai}"
        echo -e "${gl_bufan}——————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}当前拥塞控制算法：${gl_lv}$CURRENT_ALGO${gl_bai}"
        echo -e "${gl_bufan}当前队列管理算法：${gl_lv}$CURRENT_QDISC${gl_bai}"
        echo -e "${gl_bufan}——————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}安装或更新 BBR v3 (最新版)"
        echo -e "${gl_bufan}2.  ${gl_bai}指定版本安装"
        echo -e "${gl_bufan}3.  ${gl_bai}检查 BBR v3 状态"
        echo -e "${gl_bufan}4.  ${gl_bai}启用 BBR + FQ"
        echo -e "${gl_bufan}5.  ${gl_bai}启用 BBR + FQ_PIE"
        echo -e "${gl_bufan}6.  ${gl_bai}启用 BBR + CAKE"
        echo -e "${gl_bufan}7.  ${gl_bai}卸载 BBR 内核"
        echo -e "${gl_bufan}——————————————————————————————————————————${gl_bai}"
        echo -e "${gl_hong}0.  ${gl_bai}退出脚本"
        echo -e "${gl_bufan}——————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ${gl_bai}")" ACTION
        
        case "$ACTION" in
            1)
                echo -e ""
                echo -e "${gl_zi}>>> 安装或更新 BBR v3${gl_bai}"
                echo -e "${gl_bufan}——————————————————————————————————————————${gl_bai}"
                install_latest_version
                echo -e "${gl_bufan}——————————————————————————————————————————${gl_bai}"
                break_end
                ;;
            2)
                echo -e ""
                echo -e "${gl_zi}>>> 安装指定版本的 BBR${gl_bai}"
                echo -e "${gl_bufan}——————————————————————————————————————————${gl_bai}"
                install_specific_version
                ;;
            3)
                echo -e ""
                echo -e "${gl_zi}>>> 检查是否为 BBR v3${gl_bai}"
                echo -e "${gl_bufan}——————————————————————————————————————————${gl_bai}"
                BBR_MODULE_INFO=$(modinfo tcp_bbr 2>/dev/null)
                if [[ -z "$BBR_MODULE_INFO" ]]; then
                    log_error "未加载 tcp_bbr 模块，无法检查版本。请先安装内核并重启。"
                else
                    BBR_VERSION=$(echo "$BBR_MODULE_INFO" | awk '/^version:/ {print $2}')
                    if [[ "$BBR_VERSION" == "3" ]]; then
                        echo -e "${gl_bufan}✔ BBR 模块版本：${gl_lv}$BBR_VERSION (v3)${gl_bai}"
                    else
                        log_warn "检测到 BBR 模块，但版本是：$BBR_VERSION，不是 v3！"
                    fi
                    
                    CURRENT_ALGO=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
                    if [[ "$CURRENT_ALGO" == "bbr" ]]; then
                        echo -e "${gl_bufan}✔ TCP 拥塞控制算法：${gl_lv}$CURRENT_ALGO${gl_bai}"
                    else
                        log_error "当前算法不是 bbr，而是：$CURRENT_ALGO"
                    fi

                    if [[ "$BBR_VERSION" == "3" && "$CURRENT_ALGO" == "bbr" ]]; then
                        log_ok "检测完成，BBR v3 已正确安装并生效！"
                    else
                        log_warn "BBR v3 未完全生效。请确保已安装内核并重启，然后使用选项 4/5/6 启用。"
                    fi
                fi
                echo -e "${gl_bufan}——————————————————————————————————————————${gl_bai}"
                break_end
                ;;
            4)
                echo -e ""
                echo -e "${gl_zi}>>> 使用 BBR + FQ 加速${gl_bai}"
                echo -e "${gl_bufan}——————————————————————————————————————————${gl_bai}"
                ALGO="bbr"
                QDISC="fq"
                ask_to_save
                break_end
                echo -e "${gl_bufan}——————————————————————————————————————————${gl_bai}"
                ;;
            5)
                echo -e ""
                echo -e "${gl_zi}>>> 使用 BBR + FQ_PIE 加速${gl_bai}"
                echo -e "${gl_bufan}——————————————————————————————————————————${gl_bai}"
                ALGO="bbr"
                QDISC="fq_pie"
                ask_to_save
                echo -e "${gl_bufan}——————————————————————————————————————————${gl_bai}"
                break_end
                ;;
            6)
                echo -e ""
                echo -e "${gl_zi}>>> BBR + CAKE 加速${gl_bai}"
                echo -e "${gl_bufan}——————————————————————————————————————————${gl_bai}"
                ALGO="bbr"
                QDISC="cake"
                ask_to_save
                echo -e "${gl_bufan}——————————————————————————————————————————${gl_bai}"
                break_end
                ;;
            7)
                echo -e ""
                echo -e "${gl_zi}>>> 卸载 BBR 内核${gl_bai}"
                echo -e "${gl_bufan}——————————————————————————————————————————${gl_bai}"
                PACKAGES_TO_REMOVE=$(dpkg -l | grep "joeyblog" | awk '{print $2}' | tr '\n' ' ')
                if [[ -n "$PACKAGES_TO_REMOVE" ]]; then
                    log_info "将要卸载以下内核包: ${gl_huang}$PACKAGES_TO_REMOVE${gl_bai}"
                    sudo apt-get remove --purge $PACKAGES_TO_REMOVE -y
                    update_bootloader
                    log_ok "内核包已卸载。请记得重启系统。"
                else
                    log_warn "未找到由本脚本安装的 'joeyblog' 内核包。"
                fi
                echo -e "${gl_bufan}——————————————————————————————————————————${gl_bai}"
                break_end
                ;;
            0)
                exit_script
                ;;
            *)
                handle_invalid_input
                ;;
        esac
    done
}

show_main_menu