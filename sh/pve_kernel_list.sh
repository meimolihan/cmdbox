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
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    read -r -n 1 -s -r -p ""
    echo ""
    clear
}

column_if_available() {
    if command -v column &> /dev/null; then
        column -t -s $'\t'
    else
        cat
    fi
}

parse_pve_kernel() {
    apt-cache search 'pve-kernel' 2>/dev/null | while read -r line; do
        [[ -z $line ]] && continue
        pkg_name=$(echo "$line" | awk '{print $1}')
        desc=${line#"$pkg_name" }
        desc=$(echo "$desc" | xargs)

        if [[ $pkg_name =~ ^pve-kernel-[0-9] ]]; then
            pkg_color="$gl_lan"
        else
            pkg_color="$gl_bufan"
        fi

        echo -e "${gl_huang}内核包${reset}\t${pkg_color}${pkg_name}${reset}\t${gl_bai}${desc}${reset}"
    done
}

show_pve_kernel() {
    clear
    
    if ! command -v qm &> /dev/null; then
        echo -e ""
        echo -e "${gl_zi}>>> PVE 可用内核包列表${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        log_error "未检测到Proxmox VE环境，请确保脚本在PVE节点上运行"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return 1
    fi

    echo -e "${gl_zi}>>> PVE 可用内核包列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    {
        printf "%s%s\t%s\t%s%s\n" "$gl_hui" "类型" "软件包名" "描述" "$reset"
        printf "%s%s\t%s\t%s%s\n" "$gl_hui" "----" "--------" "----" "$reset"
        parse_pve_kernel
    } | column_if_available

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

show_pve_kernel
