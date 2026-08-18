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

filter_kernel_version() {
    local pkg="$1"
    local min_ver="$2"
    [[ -z "$min_ver" ]] && return 0

    local ver_raw
    ver_raw=$(echo "$pkg" | sed -E \
        -e 's/^proxmox-kernel-//' \
        -e 's/\+deb[0-9u-]*//' \
        -e 's/-rc[0-9]+//' \
        -e 's/-pve.*//' \
        -e 's/-[0-9]+$//')

    local smallest
    smallest=$(printf "%s\n" "$min_ver" "$ver_raw" | sort -V | head -n1)
    if [[ "$smallest" == "$ver_raw" ]]; then
        return 1
    fi
    return 0
}

parse_pve_kernel() {
    local min_version="$1"
    apt-cache pkgnames 2>/dev/null \
        | grep -E '^(proxmox|pve)-kernel-' \
        | grep -v -- '-signed$' \
        | sort -V \
        | while read -r pkg_name; do
        [[ -z $pkg_name ]] && continue

        local desc
        desc=$(apt-cache show "$pkg_name" 2>/dev/null | grep -m1 '^Description:' | sed 's/^Description://' | xargs)
        [[ -z "$desc" ]] && continue

        [[ "$desc" != "Proxmox Kernel Image" && "$desc" != "Latest Proxmox Kernel Image" ]] && continue

        if ! filter_kernel_version "$pkg_name" "$min_version"; then
            continue
        fi

        pkg_color="$gl_lan"
        echo -e "${gl_huang}内核包${reset}\t${pkg_color}${pkg_name}${reset}\t${gl_bai}${desc}${reset}"
    done
}

show_pve_kernel() {
    local min_version="${1:-}"
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

    local title=">>> PVE 可用内核包列表（排除‑signed签名包）"
    if [[ -n "$min_version" ]]; then
        title+=" (仅展示 >= ${min_version})"
    fi
    echo -e "${gl_zi}${title}${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    {
        printf "%s%s\t%s\t%s%s\n" "$gl_hui" "类型" "软件包名" "描述" "$reset"
        printf "%s%s\t%s\t%s%s\n" "$gl_hui" "----" "--------" "----" "$reset"
        parse_pve_kernel "$min_version"
    } | column_if_available
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

show_pve_kernel "${1:-}"