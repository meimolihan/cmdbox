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

sleep_fractional() {
    local seconds=$1
    if sleep "$seconds" 2>/dev/null; then return 0; fi
    if command -v perl >/dev/null 2>&1; then perl -e "select(undef, undef, undef, $seconds)"; return 0; fi
    if command -v python3 >/dev/null 2>&1; then python3 -c "import time; time.sleep($seconds)"; return 0; fi
    if command -v python >/dev/null 2>&1; then python -c "import time; time.sleep($seconds)"; return 0; fi
    local int_seconds=$(echo "$seconds" | awk '{print int($1+0.999)}')
    sleep "$int_seconds"
}

exit_script() {
    echo ""
    echo -ne "${gl_hong}感谢使用，再见！${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
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

handle_y_n() {
    echo -e "${gl_hong}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai})${gl_hong}。${gl_bai}"
    sleep 1
    echo -e "${gl_huang}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai})${gl_huang}。${gl_bai}"
    sleep 1
    echo -e "${gl_lv}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai})${gl_lv}。${gl_bai}"
    sleep 0.5
    return 2
}

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n 1 -s -r -p ""
    echo ""
    clear
}

get_current_kernel() {
    uname -r | sed 's/-pve//'
}

show_installed_packages() {
    echo -e "${gl_lv}------------ 已安装的内核及头文件 -------------${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local count=1
    local current_kernel=$(uname -r)

    while IFS= read -r pkg; do
        if [[ -n "$pkg" ]]; then
            if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
                if [[ "$pkg" == *"$current_kernel"* ]]; then
                    echo -e "${gl_bai}$count. ${gl_huang}$pkg   ## 当前运行, 不可卸载${gl_bai}"
                else
                    echo -e "${gl_bai}$count. $pkg${gl_bai}"
                fi
                ((count++))
            fi
        fi
    done < <(dpkg -l 2>/dev/null | grep "proxmox-headers" | awk '{print $2}')

    while IFS= read -r pkg; do
        if [[ -n "$pkg" ]]; then
            if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
                if [[ "$pkg" == *"$current_kernel"* ]]; then
                    echo -e "${gl_bai}$count. ${gl_huang}$pkg    ## 当前运行, 不可卸载${gl_bai}"
                elif [[ "$pkg" == "proxmox-kernel-7.0" ]]; then
                    echo -e "${gl_bai}$count. ${gl_huang}$pkg            ## 基础包, 不建议卸载${gl_bai}"
                elif [[ "$pkg" == "proxmox-kernel-helper" ]]; then
                    continue
                else
                    echo -e "${gl_bai}$count. $pkg${gl_bai}"
                fi
                ((count++))
            fi
        fi
    done < <(dpkg -l 2>/dev/null | grep "proxmox-kernel" | grep -v "proxmox-kernel-helper" | awk '{print $2}')

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bufan}X. 一键卸载其他内核及头文件${gl_bai}"
    echo -e "${gl_hong}0. ${gl_bai}退出脚本${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
}

uninstall_kernel_package() {
    local pkg=$1
    log_info "正在卸载 $pkg ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

    if apt-get purge -y "$pkg" 2>&1 | tee -a /var/log/pve-kernel-cleanup.log; then
        log_ok "成功卸载 $pkg"
        return 0
    else
        log_error "卸载 $pkg 失败"
        return 1
    fi
}

uninstall_headers_package() {
    local pkg=$1
    log_info "正在卸载 $pkg ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

    if apt-get purge -y "$pkg" 2>&1 | tee -a /var/log/pve-kernel-cleanup.log; then
        log_ok "成功卸载 $pkg"
        return 0
    else
        log_error "卸载 $pkg 失败"
        return 1
    fi
}

uninstall_all_other_kernels() {
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_huang}# 注意事项${gl_bai}"
    echo -e ""
    echo -e "${gl_bai}如果当前运行的内核为测试版或第三方内核, 则官方稳定版内核可能会卸载失败${gl_bai}"
    echo -e ""
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_warn "即将卸载非当前运行的内核及头文件"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local current_kernel=$(uname -r | sed 's/-pve//')
    local removed_count=0
    local failed_count=0

    local keep_packages=(
        "proxmox-kernel-7.0"
    )

    while IFS= read -r pkg; do
        if [[ "$pkg" == *"$current_kernel"* ]] && [[ "$pkg" == *"headers"* ]]; then
            keep_packages+=("$pkg")
        fi
    done < <(dpkg -l 2>/dev/null | grep "proxmox-headers" | awk '{print $2}')

    while IFS= read -r pkg; do
        if [[ "$pkg" == *"$current_kernel"* ]]; then
            keep_packages+=("$pkg")
        fi
    done < <(dpkg -l 2>/dev/null | grep "proxmox-kernel" | grep -v "proxmox-kernel-helper" | awk '{print $2}')

    log_info "正在处理头文件包 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    while IFS= read -r pkg; do
        if [[ -n "$pkg" ]]; then
            local should_keep=false
            for keep in "${keep_packages[@]}"; do
                if [[ "$pkg" == "$keep" ]]; then
                    should_keep=true
                    break
                fi
            done

            if [[ "$should_keep" == false ]] && dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
                if uninstall_headers_package "$pkg"; then
                    ((removed_count++))
                else
                    ((failed_count++))
                fi
            fi
        fi
    done < <(dpkg -l 2>/dev/null | grep "proxmox-headers" | awk '{print $2}')

    log_info "正在处理内核包 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    while IFS= read -r pkg; do
        if [[ -n "$pkg" ]]; then
            local should_keep=false
            for keep in "${keep_packages[@]}"; do
                if [[ "$pkg" == "$keep" ]]; then
                    should_keep=true
                    break
                fi
            done

            if [[ "$should_keep" == false ]] && dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
                if uninstall_kernel_package "$pkg"; then
                    ((removed_count++))
                else
                    ((failed_count++))
                fi
            fi
        fi
    done < <(dpkg -l 2>/dev/null | grep "proxmox-kernel" | grep -v "proxmox-kernel-helper" | awk '{print $2}')

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_ok "一键卸载其他内核及头文件完成"
    log_info "成功卸载: $removed_count 个包"
    if [[ $failed_count -gt 0 ]]; then
        log_warn "失败: $failed_count 个包"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    log_info "正在更新GRUB配置 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    update-grub 2>&1 | tee -a /var/log/pve-kernel-cleanup.log
    log_ok "GRUB更新完成"
}

single_uninstall() {
    local choice=$1
    local pkg_name=$(show_installed_packages | sed -n "${choice}p" | awk '{print $2}')

    if [[ -z "$pkg_name" ]]; then
        log_error "无效的选择"
        return 1
    fi

    if [[ "$pkg_name" == *"$(uname -r)"* ]]; then
        log_error "不能卸载当前运行的内核: $pkg_name"
        return 1
    fi

    if [[ "$pkg_name" == "proxmox-kernel-7.0" ]]; then
        log_error "不建议卸载基础包: $pkg_name"
        return 1
    fi

    read -r -e -p "$(echo -e "${gl_bai}确认要卸载 ${gl_huang}$pkg_name${gl_bai} ? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        if [[ "$pkg_name" == *"headers"* ]]; then
            uninstall_headers_package "$pkg_name"
        else
            uninstall_kernel_package "$pkg_name"
        fi
        update-grub
    else
        log_info "取消卸载"
    fi
}

main_menu() {
    while true; do
        clear
        
        if ! command -v qm &> /dev/null; then
            echo -e ""
            echo -e "${gl_zi}>>> 卸载 PVE 内核及头文件${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            log_error "未检测到Proxmox VE环境，请确保脚本在PVE节点上运行"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            return 1
        fi
        
        echo -e "${gl_zi}>>> 卸载 PVE 内核及头文件${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}注意事项${gl_bai}"
        echo -e "${gl_bai}如果当前运行的内核为测试版或第三方内核, 则官方稳定版内核可能会卸载失败${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        show_installed_packages

        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ${gl_bai}")" choice

        case $choice in
            0)
                exit_script
                break
                ;;
            [Xx])
                echo ""
                uninstall_all_other_kernels
                ;;
            [1-9]*)
                if [[ "$choice" =~ ^[0-9]+$ ]]; then
                    single_uninstall "$choice"
                else
                    handle_invalid_input
                fi
                ;;
            *)
                handle_invalid_input
                ;;
        esac

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
    done
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        echo -e "${gl_bai}请使用: ${gl_huang}sudo $0${gl_bai}"
        exit_script
    fi
}

main() {
    check_root

    LOG_FILE="/var/log/pve-kernel-cleanup.log"
    touch "$LOG_FILE" 2>/dev/null || log_warn "无法创建日志文件"
    log_info "日志文件: $LOG_FILE"

    log_info "当前运行内核: $(uname -r)"

    main_menu
}

main "$@"
