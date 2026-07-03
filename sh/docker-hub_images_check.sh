#!/bin/bash
set -uo pipefail
IFS=$'\n\t'

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

exit_script() {
    echo ""
    echo -ne "${gl_hong}感谢使用，再见！${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep 0.6
    clear
    exit 0
}

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n 1 -s -p ""
    echo ""
    clear
}

install() {
    [[ $# -eq 0 ]] && {
        log_error "未提供软件包参数!"
        return 1
    }
    local pkg mgr ver installed
    local repo_updated=false

    for pkg in "$@"; do
        installed=false
        ver=""
        case "$pkg" in
            7zip|7z)
                command -v 7z &>/dev/null && {
                    ver=$(7z 2>&1 | grep -oE '[0-9]+(\.[0-9]+)+' | head -n1)
                    [[ -n "$ver" ]] && installed=true
                }
                ;;
            *)
                command -v "$pkg" &>/dev/null && {
                    ver=$("$pkg" --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)+' | head -n1)
                    [[ -n "$ver" ]] && installed=true
                }
                ;;
        esac

        if [[ "$installed" == false && -x /usr/bin/opkg ]]; then
            opkg list-installed 2>/dev/null | grep -q "^${pkg} " && {
                installed=true
                ver=$(opkg list-installed 2>/dev/null | awk -v p="$pkg" '$1==p{print $3}')
            }
        fi

        if [[ "$installed" == true ]]; then
            echo -e "${gl_huang}${pkg}${gl_bai} ${gl_lv}已安装${gl_bai}${ver:+ 版本 ${gl_lv}${ver}${gl_bai}}"
            continue
        fi

        echo -e "\n${gl_huang}开始安装：${gl_bai}${pkg}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        local install_success=false

        for mgr in opkg dnf yum apt apk pacman zypper pkg; do
            command -v "$mgr" &>/dev/null || continue
            case $mgr in
                opkg)
                    echo -e "${gl_bai}使用包管理器: ${gl_zi}opkg (OpenWrt/iStoreOS)${gl_bai}"
                    [[ $repo_updated == false ]] && opkg update && repo_updated=true
                    [[ "$pkg" == "7zip" || "$pkg" == "7z" ]] && opkg install p7zip || opkg install "$pkg"
                    [[ $? -eq 0 ]] && install_success=true
                    ;;
                dnf)
                    echo -e "${gl_bai}使用包管理器: ${gl_zi}dnf (Fedora/RHEL)${gl_bai}"
                    dnf install -y "$pkg" && install_success=true
                    ;;
                yum)
                    echo -e "${gl_bai}使用包管理器: ${gl_zi}yum (CentOS/RHEL)${gl_bai}"
                    yum install -y "$pkg" && install_success=true
                    ;;
                apt)
                    echo -e "${gl_bai}使用包管理器: ${gl_zi}apt (Debian/Ubuntu)${gl_bai}"
                    [[ $repo_updated == false ]] && apt update -y && repo_updated=true
                    apt install -y "$pkg" && install_success=true
                    ;;
                apk)
                    echo -e "${gl_bai}使用包管理器: ${gl_zi}apk (Alpine)${gl_bai}"
                    apk add "$pkg" && install_success=true
                    ;;
                pacman)
                    echo -e "${gl_bai}使用包管理器: ${gl_zi}pacman (Arch/Manjaro)${gl_bai}"
                    pacman -S --noconfirm "$pkg" && install_success=true
                    ;;
                zypper)
                    echo -e "${gl_bai}使用包管理器: ${gl_zi}zypper (openSUSE)${gl_bai}"
                    zypper install -y "$pkg" && install_success=true
                    ;;
                pkg)
                    echo -e "${gl_bai}使用包管理器: ${gl_zi}pkg (FreeBSD)${gl_bai}"
                    pkg install -y "$pkg" && install_success=true
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

get_all_tags() {
    local repo="$1"
    local auth="$2"
    local url="https://hub.docker.com/v2/repositories/${repo}/tags?page_size=100"
    local all_tags=""

    while [[ -n "$url" && "$url" != "null" ]]; do
        local resp http_code
        resp=$(curl -s -w "%{http_code}" -u "${auth}" "${url}")
        http_code=${resp: -3}
        resp=${resp%???}

        if [[ "$http_code" != "200" ]]; then
            log_error "接口请求失败，HTTP 状态码: ${http_code}"
            return 1
        fi

        if ! echo "$resp" | jq empty 2>/dev/null; then
            log_error "接口返回非标准 JSON"
            return 1
        fi

        local page_tags
        page_tags=$(echo "$resp" | jq -r '.results[].name')
        all_tags+="${page_tags}"$'\n'

        url=$(echo "$resp" | jq -r '.next')
    done

    echo "$all_tags" | sed '/^$/d' | sort -u
}

show_usage() {
    clear
    echo -e "${gl_zi}>>> Docker Hub 镜像标签查看工具${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}用法：${gl_bai}$0 <用户名:PAT> [仓库1 仓库2 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}]"
    echo -e "${gl_bai}示例："
    echo -e "  $0 mobufan:dckr_pat_xxxxxx"
    echo -e "  $0 mobufan:dckr_pat_xxxxxx mobufan/cmdbox mobufan/test"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
}

main() {
    install curl jq

    local AUTH=""
    local REPO_LIST=()

    if [[ $# -ge 1 ]]; then
        AUTH="$1"
        shift
        REPO_LIST=("$@")
    fi

    clear
    echo -e "${gl_zi}>>> Docker Hub 镜像标签查看工具${gl_bai}"
    echo -e "${gl_bufan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"

    while [[ -z "${AUTH}" ]]; do
        read -r -e -p "$(echo -e "${gl_bai}请输入 用户名:PAT (格式:mobufan:dckr_pat_xxxxxx，${gl_hong}0 ${gl_bai}退出): ")" AUTH
        [[ "${AUTH}" = "0" ]] && exit_script
    done

    if [[ ${#REPO_LIST[@]} -eq 0 ]]; then
        read -r -e -p "$(echo -e "${gl_bai}请输入镜像仓库(多仓库空格分隔，格式:用户名/仓库名，输入 0 退出): ")" REPO_INPUT
        [[ "${REPO_INPUT}" = "0" ]] && exit_script
        [[ -z "${REPO_INPUT}" ]] && REPO_INPUT="mobufan/cmdbox"
        REPO_LIST=($REPO_INPUT)
    fi

    for repo in "${REPO_LIST[@]}"; do
        local USER="${repo%%/*}"
        echo -e ""
        echo -e "${gl_huang}>>> ${gl_bai}仓库: ${gl_huang}${repo}${gl_bai} (操作用户: ${gl_lv}${USER}${gl_bai})"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        echo -e "${gl_bai}正在获取标签列表 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        local TAGS
        TAGS=$(get_all_tags "${repo}" "${AUTH}") || continue

        if [[ -z "${TAGS}" ]]; then
            log_warn "仓库 ${repo} 暂无标签"
            continue
        fi
        echo -e "${gl_bai}当前标签列表："
        echo -e "${gl_lv}${TAGS}${gl_bai}"
    done

    echo -e ""
    echo -e "${gl_bufan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
    break_end
}

main "$@"