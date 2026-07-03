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
    export gl_cheng=$'\033[38;5;208m'
    export reset=$'\033[0m'
    export bold=$'\033[1m'
}
list_color_init

break_end() {
    echo -e "\n${gl_lv}操作完成${reset}"
    echo -en "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}${reset}"
    read -r -n 1 -s -r -p ""
    echo ""
    clear
}

detect_pkg_manager() {
    if [[ -n "${PKG_MANAGER_CACHED:-}" ]]; then
        echo "$PKG_MANAGER_CACHED"
        return
    fi
    
    local pm="unknown"
    if command -v dpkg-query &> /dev/null; then
        pm="dpkg"
    elif command -v rpm &> /dev/null; then
        pm="rpm"
    elif command -v pacman &> /dev/null; then
        pm="pacman"
    elif command -v apk &> /dev/null; then
        pm="apk"
    fi
    export PKG_MANAGER_CACHED="$pm"
    echo "$pm"
}

count_packages() {
    local search="${1:-}"
    local pm=$(detect_pkg_manager)
    local count=0
    
    case "$pm" in
        dpkg)
            if [[ -n "$search" ]]; then
                count=$(dpkg-query -W -f '${Package}\n' 2>/dev/null | grep -i "$search" | wc -l)
            else
                count=$(dpkg-query -W 2>/dev/null | wc -l)
            fi
            ;;
        rpm)
            if [[ -n "$search" ]]; then
                count=$(rpm -qa 2>/dev/null | grep -i "$search" | wc -l)
            else
                count=$(rpm -qa 2>/dev/null | wc -l)
            fi
            ;;
        pacman)
            if [[ -n "$search" ]]; then
                count=$(pacman -Q 2>/dev/null | cut -d' ' -f1 | grep -i "$search" | wc -l)
            else
                count=$(pacman -Q 2>/dev/null | wc -l)
            fi
            ;;
        apk)
            if [[ -n "$search" ]]; then
                count=$(apk list -I 2>/dev/null | cut -d' ' -f1 | grep -i "$search" | wc -l)
            else
                count=$(apk list -I 2>/dev/null | wc -l)
            fi
            ;;
    esac
    echo "${count:-0}"
}

highlight_search() {
    local text="$1"
    local search="$2"
    if [[ -z "$search" ]]; then
        echo "$text"
        return
    fi
    echo "$text" | sed "s/\($search\)/${gl_cheng}${bold}\1${reset}/gi"
}

list_beautify_packages_dpkg() {
    local search="${1:-}"
    local temp_file=$(mktemp)
    
    dpkg-query -W -f '${Package}\t${Version}\t${Installed-Size}\t${Section}\t${Status}\n' 2>/dev/null | \
    while IFS=$'\t' read -r pkg ver size section status; do
        [[ -n "$search" && ! "$pkg" =~ $search ]] && continue
        
        local st=""
        local st_color=""
        if [[ "$status" =~ installed ]]; then
            st="已安装"
            st_color="$gl_lv"
        elif [[ "$status" =~ not-installed ]]; then
            st="未安装"
            st_color="$gl_hui"
        elif [[ "$status" =~ deinstall ]]; then
            st="待移除"
            st_color="$gl_huang"
        else
            st="${status%% *}"
            st_color="$gl_bai"
        fi
        
        local size_disp=""
        if [[ -z "$size" || "$size" == "0" ]]; then
            size_disp="-"
        else
            if command -v numfmt &> /dev/null; then
                size_disp=$(numfmt --to=iec --suffix=B "$size" 2>/dev/null || echo "${size}KB")
            else
                size_disp="${size}KB"
            fi
        fi
        
        local pkg_disp=$(highlight_search "$pkg" "$search")
        
        printf "%s\t%s\t%s\t%s\t%s\n" \
            "$pkg_disp" \
            "${gl_bai}$ver${reset}" \
            "${gl_lan}$size_disp${reset}" \
            "${gl_bufan}$section${reset}" \
            "${st_color}$st${reset}"
    done > "$temp_file"
    
    printf "${gl_hui}%-40s %-20s %-12s %-15s %-10s${reset}\n" \
        "软件包" "版本" "大小" "类别" "状态"
    printf "${gl_hui}%-40s %-20s %-12s %-15s %-10s${reset}\n" \
        "$(printf '%0.s-' {1..40})" \
        "$(printf '%0.s-' {1..20})" \
        "$(printf '%0.s-' {1..12})" \
        "$(printf '%0.s-' {1..15})" \
        "$(printf '%0.s-' {1..10})"
    
    if command -v column &> /dev/null; then
        column -t -s $'\t' "$temp_file"
    else
        cat "$temp_file"
    fi
    
    rm -f "$temp_file"
}

list_beautify_packages_rpm() {
    local search="${1:-}"
    local temp_file=$(mktemp)
    
    rpm -qa --queryformat '%{NAME}\t%{VERSION}-%{RELEASE}\t%{SIZE}\t%{GROUP}\n' 2>/dev/null | \
    while IFS=$'\t' read -r pkg ver size group; do
        [[ -n "$search" && ! "$pkg" =~ $search ]] && continue
        
        local size_disp=""
        if [[ -z "$size" || "$size" == "0" ]]; then
            size_disp="-"
        else
            if command -v numfmt &> /dev/null; then
                size_disp=$(numfmt --to=iec --suffix=B "$size" 2>/dev/null || echo "${size}B")
            else
                size_disp="${size}B"
            fi
        fi
        
        local pkg_disp=$(highlight_search "$pkg" "$search")
        
        printf "%s\t%s\t%s\t%s\n" \
            "$pkg_disp" \
            "${gl_bai}$ver${reset}" \
            "${gl_lan}$size_disp${reset}" \
            "${gl_bufan}$group${reset}"
    done > "$temp_file"
    
    printf "${gl_hui}%-50s %-25s %-12s %-20s${reset}\n" "软件包" "版本" "大小" "分组"
    printf "${gl_hui}%-50s %-25s %-12s %-20s${reset}\n" \
        "$(printf '%0.s-' {1..50})" \
        "$(printf '%0.s-' {1..25})" \
        "$(printf '%0.s-' {1..12})" \
        "$(printf '%0.s-' {1..20})"
    
    if command -v column &> /dev/null; then
        column -t -s $'\t' "$temp_file"
    else
        cat "$temp_file"
    fi
    
    rm -f "$temp_file"
}

list_beautify_packages_pacman() {
    local search="${1:-}"
    local temp_file=$(mktemp)
    
    pacman -Q 2>/dev/null | \
    while read -r pkg ver; do
        [[ -n "$search" && ! "$pkg" =~ $search ]] && continue
        local pkg_disp=$(highlight_search "$pkg" "$search")
        printf "%s\t%s\n" "$pkg_disp" "${gl_bai}$ver${reset}"
    done > "$temp_file"
    
    printf "${gl_hui}%-40s %-30s${reset}\n" "软件包" "版本"
    printf "${gl_hui}%-40s %-30s${reset}\n" \
        "$(printf '%0.s-' {1..40})" \
        "$(printf '%0.s-' {1..30})"
    
    if command -v column &> /dev/null; then
        column -t -s $'\t' "$temp_file"
    else
        cat "$temp_file"
    fi
    
    rm -f "$temp_file"
}

list_beautify_packages_apk() {
    local search="${1:-}"
    local temp_file=$(mktemp)
    
    apk list -I 2>/dev/null | sed 's/-[0-9].*_\|-[0-9].*\./-/' | \
    while read -r pkg ver; do
        [[ -n "$search" && ! "$pkg" =~ $search ]] && continue
        local pkg_disp=$(highlight_search "$pkg" "$search")
        printf "%s\t%s\n" "$pkg_disp" "${gl_bai}$ver${reset}"
    done > "$temp_file"
    
    printf "${gl_hui}%-40s %-30s${reset}\n" "软件包" "版本"
    printf "${gl_hui}%-40s %-30s${reset}\n" \
        "$(printf '%0.s-' {1..40})" \
        "$(printf '%0.s-' {1..30})"
    
    if command -v column &> /dev/null; then
        column -t -s $'\t' "$temp_file"
    else
        cat "$temp_file"
    fi
    
    rm -f "$temp_file"
}

list_beautify_all() {
    clear
    
    local pm=$(detect_pkg_manager)
    local filter="${1:-}"
    
    local title=""
    local func=""
    case "$pm" in
        dpkg)
            title="已安装软件包列表 (dpkg)"
            func="list_beautify_packages_dpkg"
            ;;
        rpm)
            title="已安装软件包列表 (rpm)"
            func="list_beautify_packages_rpm"
            ;;
        pacman)
            title="已安装软件包列表 (pacman)"
            func="list_beautify_packages_pacman"
            ;;
        apk)
            title="已安装软件包列表 (apk)"
            func="list_beautify_packages_apk"
            ;;
        *)
            echo -e "${gl_hong}✗ 错误: 未检测到支持的包管理器 (dpkg/rpm/pacman/apk)${reset}"
            exit 1
            ;;
    esac
    
    echo -e "${gl_zi}${bold}>>> $title${reset}"
    if [[ -n "$filter" ]]; then
        echo -e "${gl_huang}🔍 过滤: ${gl_cheng}${bold}$filter${reset}"
    fi
    
    local total=$(count_packages "$filter")
    echo -e "${gl_lan}📦 软件包总数: ${bold}${total}${reset}"
    echo -e "${gl_bufan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
    
    $func "$filter"
    
    echo -e "\n${gl_bufan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
    break_end
}

if [[ $# -gt 0 ]]; then
    list_beautify_all "$*"
else
    list_beautify_all ""
fi
