#!/bin/bash

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
    echo -ne "\r\033[K${gl_huang}无效的输入,请重新输入! ${gl_zi} 1 ${gl_huang} 秒后返回"
    sleep_fractional 1
    echo -ne "\r\033[K${gl_lv}无效的输入,请重新输入! ${gl_zi}0${gl_lv} 秒后返回"
    sleep_fractional 0.5
    echo -ne "\r\033[K"
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

exit_animation() {
    echo -ne "\r${gl_lv}即将退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo ""
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

install() {
    [[ $# -eq 0 ]] && {
        log_error "未提供软件包参数!"
        return 1
    }

    local pkg mgr ver cmd_ver pkg_ver installed=false
    for pkg in "$@"; do
        installed=false
        ver=""

        if command -v "$pkg" &>/dev/null; then
            cmd_ver=$("$pkg" --version 2>/dev/null | head -n1 | tr -cd '[:print:]' | grep -oE '[0-9]+(\.[0-9]+)+' | head -n1 || echo "")
            [[ -n "$cmd_ver" ]] && ver="$cmd_ver"
            installed=true
        fi
        
        if [[ "$pkg" == "7zip" || "$pkg" == "7z" ]]; then
            if command -v 7z &>/dev/null; then
                ver=$(7z 2>&1 | grep -oE '[0-9]+(\.[0-9]+)+' | head -n1 || echo "")
                [[ -n "$ver" ]] && installed=true
            fi
        fi
        
        if [[ "$installed" == false ]]; then
            if command -v opkg &>/dev/null; then
                if opkg list-installed | grep -q "^${pkg} "; then
                    installed=true
                    ver=$(opkg list-installed | grep "^${pkg} " | awk '{print $3}' 2>/dev/null || echo "")
                fi
            elif command -v dpkg-query &>/dev/null; then
                if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
                    installed=true
                    ver=$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null || echo "")
                fi
            elif command -v rpm &>/dev/null; then
                if rpm -q "$pkg" &>/dev/null; then
                    installed=true
                    ver=$(rpm -q --qf '%{VERSION}' "$pkg" 2>/dev/null || echo "")
                fi
            elif command -v apk &>/dev/null; then
                if apk info "$pkg" 2>/dev/null | grep -q "^installed"; then
                    installed=true
                    ver=$(apk info -a "$pkg" 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)+' | head -n1 || echo "")
                fi
            elif command -v pacman &>/dev/null; then
                if pacman -Qi "$pkg" &>/dev/null; then
                    installed=true
                    ver=$(pacman -Qi "$pkg" 2>/dev/null | grep -i "version" | grep -oE '[0-9]+(\.[0-9]+)+' | head -n1 || echo "")
                fi
            fi
        fi
        
        if [[ "$installed" == true ]]; then
            echo -e "${gl_huang}${pkg}${gl_bai} ${gl_lv}已安装${gl_bai}" \
                "$([[ -n "$ver" ]] && echo "版本 ${gl_lv}${ver}${gl_bai}")"
            continue
        fi
        
        echo -e ""
        echo -e "${gl_huang}开始安装：${gl_bai}${pkg}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        local install_success=false
        
        for mgr in opkg dnf yum apt apk pacman zypper pkg; do
            if ! command -v "$mgr" &>/dev/null; then
                continue
            fi
            
            case $mgr in
            opkg)
                echo -e "${gl_bai}使用包管理器: ${gl_zi}opkg (OpenWrt/iStoreOS)${gl_bai}"
                if [[ "$pkg" == "7zip" || "$pkg" == "7z" ]]; then
                    echo -e "${gl_bai}正在安装: ${gl_lv}p7zip${gl_bai}"
                    opkg update && opkg install p7zip && install_success=true
                else
                    opkg update && opkg install "$pkg" && install_success=true
                fi
                ;;
            dnf)
                echo -e "${gl_bai}使用包管理器: ${gl_zi}dnf (Fedora/RHEL)${gl_bai}"
                dnf -y update && dnf install -y "$pkg" && install_success=true
                ;;
            yum)
                echo -e "${gl_bai}使用包管理器: ${gl_zi}yum (CentOS/RHEL)${gl_bai}"
                yum -y update && yum install -y "$pkg" && install_success=true
                ;;
            apt)
                echo -e "${gl_bai}使用包管理器: ${gl_zi}apt (Debian/Ubuntu)${gl_bai}"
                apt update -y && apt install -y "$pkg" && install_success=true
                ;;
            apk)
                echo -e "${gl_bai}使用包管理器: ${gl_zi}apk (Alpine)${gl_bai}"
                apk update && apk add "$pkg" && install_success=true
                ;;
            pacman)
                echo -e "${gl_bai}使用包管理器: ${gl_zi}pacman (Arch/Manjaro)${gl_bai}"
                pacman -Syu --noconfirm && pacman -S --noconfirm "$pkg" && install_success=true
                ;;
            zypper)
                echo -e "${gl_bai}使用包管理器: ${gl_zi}zypper (openSUSE)${gl_bai}"
                zypper refresh && zypper install -y "$pkg" && install_success=true
                ;;
            pkg)
                echo -e "${gl_bai}使用包管理器: ${gl_zi}pkg (FreeBSD)${gl_bai}"
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

show_kernel_version() {
    is_pve_system || return 1
    echo -e ""
    echo -e "${gl_zi}>>> 查看内核版本${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    uname -r
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

show_available_kernels() {
    is_pve_system || return 1
    clear
    echo -e ""
    echo -e "${gl_zi}>>> 查看可用内核${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    apt-cache search pve-kernel
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

install_and_pin_kernel() {
    is_pve_system || return 1
    clear
    echo -e ""
    echo -e "${gl_zi}>>> 安装内核并固化${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "请输入内核版本（如 6.5.11-4-pve）： " kernel_ver
    
    [ "$kernel_ver" = "0" ] && { 
            cancel_return
            return 1
        }

    [[ -z $kernel_ver ]] &&
        {
            log_error "内核版本不能为空！"
            exit_animation
            return 1
        }

    echo -e "${gl_bai}正在安装 ${gl_lv}pve-kernel-${kernel_ver}${gl_bai} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    apt update >/dev/null
    apt install -y "pve-kernel-${kernel_ver}" ||
        {
            log_error "安装失败！"
            exit_animation
            return 1
        }

    echo -e ""
    echo -e "${gl_huang}>>> 正在固化内核 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}${gl_hui}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    proxmox-boot-tool kernel pin "$kernel_ver" ||
        {
            log_error "固化失败！"
            exit_animation
            return 1
        }
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    log_info "内核 ${gl_lv}$kernel_ver${gl_bai} 已安装并固化！"
    echo -e ""
    echo -e "${gl_huang}>>> 当前固化列表：${gl_hui}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    proxmox-boot-tool kernel list
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

reboot_for_new_kernel() {
    is_pve_system || return 1

    echo -e ""
    echo -e "${gl_zi}>>> 重启应用新内核${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}重启后新内核生效，立即重启吗? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
    case "$confirm" in
    [yY])
        log_info "系统将在 3 秒后重启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        sleep_fractional 3
        reboot
        ;;
    *)
        log_info "已取消重启，返回主菜单。"
        sleep_fractional 1
        ;;
    esac
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

modify_grub_params() {
    is_pve_system || return 1
    echo -e ""
    echo -e "${gl_zi}>>> 修改 GRUB 默认引导参数${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}原行：${gl_huang}$(grep ^GRUB_CMDLINE_LINUX_DEFAULT /etc/default/grub)${gl_bai}"
    echo -e "${gl_bai}新行：${gl_lv}GRUB_CMDLINE_LINUX_DEFAULT=\"quiet iommu=pt i915.enable_guc=3 i915.max_vfs=7\"${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}确认写入？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm

    case "$confirm" in
    [yY])
        sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet iommu=pt i915.enable_guc=3 i915.max_vfs=7"/' /etc/default/grub
        log_info "${gl_bai}已更新 ${gl_huang}/etc/default/grub${gl_bai}，需要执行 'update-grub' 生效。"

        read -r -e -p "$(echo -e "${gl_bai}立即执行 update-grub？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" do_update
        case "$do_update" in
        [yY])
            update-grub
            log_info "${gl_lv}update-grub 执行完成，重启后新内核参数生效。${gl_bai}"
            ;;
        *)
            log_info "${gl_huang}已跳过 update-grub，请记得手动执行！${gl_bai}"
            ;;
        esac
        ;;
    *)
        log_info "已取消修改，返回主菜单。"
        sleep_fractional 1
        ;;
    esac
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

install_i915_sriov_driver() {
    is_pve_system || return 1

    echo -e ""
    echo -e "${gl_zi}>>> 安装i915 SR-IOV驱动${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_huang}i915-sriov-dkms 一键安装${gl_bai}"
    echo -e "${gl_huang}作用：${gl_bai}"
    echo -e "${gl_bufan}    ① ${gl_bai}为 PVE 系统编译并安装 strongtz/i915-sriov-dkms 最新发行包。"
    echo -e "${gl_bufan}    ① ${gl_bai}使 Intel 11/12/13/14 代核显支持 SR-IOV，可在虚拟机中直通 vGPU。"
    echo -e "${gl_huang}前提：${gl_bai}"
    echo -e "${gl_bufan}    ① ${gl_bai}必须是 PVE 系统（检测 /var/lib/vz/template/iso）。"
    echo -e "${gl_bufan}    ② ${gl_bai}已联网，能访问 GitHub；如需代理请提前 export https_proxy。"
    echo -e "${gl_bufan}    ③ ${gl_bai}内核头文件（pve-headers-$(uname -r)）能正常安装。"
    echo -e "${gl_huang}流程：${gl_bai}装依赖 → 取最新 release → 下载 *.deb → dpkg/补依赖 → 清理 → 提示重启。"
    echo -e "${gl_huang}注意：${gl_bai}安装后必须重启宿主机；每个宿主机只需执行一次，升级内核时会自动重编。"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}确定要安装i915 SR-IOV驱动吗？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")"
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${gl_huang}已取消安装操作${gl_bai}"
        return 1
    fi

    apt update
    apt install -y jq curl wget
    clear
    echo -e ""
    echo -e "${gl_bai}当前内核的头文件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}${gl_hui}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    apt install -y "pve-headers-$(uname -r)" || {
        log_error "内核头文件安装失败"
        exit_animation
        return 1
    }
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e ""

    echo -e "${gl_bai}正在检测 GitHub 最新版本 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}${gl_hui}"
    VER=""

    API="https://api.github.com/repos/strongtz/i915-sriov-dkms/releases/latest"
    VER=$(curl -s --connect-timeout 10 --max-time 15 "$API" | jq -r .tag_name 2>/dev/null)
    
    if [[ -z "$VER" || "$VER" == "null" ]]; then
        VER=$(curl -s --connect-timeout 10 --max-time 15 "https://github.com/strongtz/i915-sriov-dkms/releases/latest" \
            | grep -oP 'tag/\K[0-9.]+' | head -n1)
    fi

    if [[ -z "$VER" ]]; then
        log_error "无法获取最新版本，请检查网络"
        exit_animation
        return 1
    fi

    DEB="i915-sriov-dkms_${VER}_amd64.deb"
    URL="https://github.com/strongtz/i915-sriov-dkms/releases/download/${VER}/${DEB}"

    echo -e "${gl_bai}准备下载 ${gl_lv}$DEB${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    wget -q --show-progress --connect-timeout 10 --tries 3 -c "$URL" -O "$DEB" || {
        log_error "下载失败！"
        exit_animation
        return 1
    }
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e ""

    echo -e "${gl_bai}准备安装 ${gl_lv}$DEB${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -rp "$(echo -e "${gl_bai}确认安装？ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
    case "$confirm" in
    [yY])
        dpkg -i "$DEB"
        apt install -fy -q
        ;;
    *)
        log_info "已取消安装，返回主菜单。"
        exit_animation
        return 1
        ;;
    esac

    rm -f "$DEB"
    echo -e ""
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_info "i915 SR-IOV DKMS 驱动安装完成，请重启系统生效。"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

update_initramfs_and_reboot() {
    is_pve_system || return 1

    echo -e "${gl_bai}正在更新 initramfs ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}${gl_hui}"
    update-initramfs -u -k all || {
        log_error "update-initramfs 失败！"
        exit_animation
        return 1
    }
    log_info "initramfs 更新完成。"

    echo ""
    read -r -e -p "$(echo -e "${gl_bai}需要重启生效，立即重启? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
    case "$confirm" in
    [yY])
        log_info "${gl_lv}系统将在 3 秒后重启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        exit_animation
        reboot
        ;;
    *)
        log_info "${gl_huang}已取消重启，请稍后手动执行 'reboot' 生效。${gl_bai}"
        exit_animation
        ;;
    esac
    break_end
}

check_sriov_status() {
    
    echo -e ""
    echo -e "${gl_huang}>>> 正在扫描 Intel i915 PF / VF 设备 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}${gl_hui}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    pf_list=$(lspci -nn | grep -i 'HD Graphics')
    vf_list=$(lspci -nn | grep -iE 'HD Graphics.*Virtual Function|8086:56[0-9a-f]')

    [[ -z $pf_list ]] && echo -e "${gl_huang}未检测到 PF（Physical Function）${gl_bai}" ||
        {
            echo -e "${gl_lv}PF 列表：${gl_bai}"
            echo "$pf_list" | nl -w2 -s') '
        }

    [[ -z $vf_list ]] && echo -e "${gl_huang}未检测到 VF（Virtual Function）${gl_bai}" ||
        {
            echo -e "${gl_lv}VF 列表：${gl_bai}"
            echo "$vf_list" | nl -w2 -s') '
        }

    echo -e "\nDKMS 状态："
    dkms status | grep -E 'i915|sr-iov' || echo "暂无记录"

    [[ -e /sys/class/drm/card0/device/sriov_numvfs ]] &&
        echo -e "\n已启用 ${gl_lv}VF${gl_bai} / 最大支持：${gl_lv}$(cat /sys/class/drm/card0/device/sriov_numvfs) ${gl_bai}/ ${gl_lv}$(cat /sys/class/drm/card0/device/sriov_totalvfs)${gl_bai}"

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

is_pve_system() {
    if [ ! -d "/var/lib/vz/template/iso" ]; then
        echo -e ""
        echo -en "\r${gl_hong}你这不是 ${gl_huang}PVE${gl_hong} 系统！\c"
        exit_animation
        return 1
    fi
    return 0
}

pve_optimize_script() {
    is_pve_system || return 1
    clear
    wget -q -O /root/pve_source.tar.gz 'https://gitee.com/meimolihan/script/raw/master/sh/pve/pve_source.tar.gz' && tar zxvf /root/pve_source.tar.gz && /root/./pve_source
    break_end
}

show_gpu_usage() {
    is_pve_system || return 1
    check_and_install intel-gpu-tools && intel_gpu_top -d sriov
}

check_pve_version() {
    if command -v pveversion &>/dev/null; then
        pve_version=$(pveversion | grep -oP 'pve-manager\/\K[^ ]+')
        kernel_version=$(uname -r)

        echo -e "${gl_bai}PVE 系统版本：${gl_lv}$pve_version${gl_bai}"
        echo -e "${gl_bai}PVE 内核版本：${gl_lv}$kernel_version${gl_bai}"
    else
        echo -e "${gl_bai}PVE 系统版本：${gl_hong}非PVE系统或未安装pveversion${gl_bai}"
    fi
}

linux_pve_menu() {
    while true; do
        clear
    
        if ! command -v qm &> /dev/null; then
            echo -e ""
            echo -e "${gl_zi}>>> PVE SR-IOV驱动管理${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            log_error "未检测到Proxmox VE环境，请确保脚本在PVE节点上运行"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            return 1
        fi
    
        echo -e ""
        echo -e "${gl_zi}>>> PVE SR-IOV驱动管理${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        check_pve_version
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}安装更新内核${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}查看内核版本       ${gl_bufan}2.  ${gl_bai}查看可用内核"
        echo -e "${gl_bufan}3.  ${gl_bai}安装内核并固化     ${gl_bufan}4.  ${gl_bai}重启应用新内核"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}SR-IOV驱动管理${gl_bai}"
        echo -e "${gl_bufan}5.  ${gl_bai}修改GRUB引导参数   ${gl_bufan}6.  ${gl_bai}安装i915 SR-IOV驱动"
        echo -e "${gl_bufan}7.  ${gl_bai}更新重启initramfs  ${gl_bufan}8.  ${gl_bai}检查SR-IOV状态"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}9.  ${gl_bai}查看核显使用率     ${gl_bufan}10. ${gl_bai}PVE优化脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}0.  ${gl_bai}返回主菜单         ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "请输入你的选择: " sub_choice

        case $sub_choice in
        1)  show_kernel_version || continue ;;
        2)  show_available_kernels || continue ;;
        3)  install_and_pin_kernel || continue ;;
        4)  reboot_for_new_kernel || continue ;;
        5)  modify_grub_params || continue ;;
        6)  install_i915_sriov_driver || continue ;;
        7)  update_initramfs_and_reboot || continue ;;
        8)  check_sriov_status || continue ;;
        9)  show_gpu_usage ;;
        10) pve_optimize_script ;;
        0 | 00 | 000 | 0000) exit_script ;;
        *) handle_invalid_input ;;
        esac
    done
}

linux_pve_menu
