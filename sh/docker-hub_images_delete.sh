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
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n 1 -s -r -p ""
    echo ""
    clear
}

install() {
    [[ $# -eq 0 ]] && {
        log_error "未提供软件包参数!"
        return 1
    }

    local pkg mgr ver installed
    
    for pkg in "$@"; do
        installed=false
        ver=""
        
        case "$pkg" in
            7zip|7z)
                if command -v 7z &>/dev/null; then
                    ver=$(7z 2>&1 | grep -oE '[0-9]+(\.[0-9]+)+' | head -n1)
                    [[ -n "$ver" ]] && installed=true
                fi
                ;;
            *)
                if command -v "$pkg" &>/dev/null; then
                    ver=$("$pkg" --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)+' | head -n1)
                    [[ -n "$ver" ]] && installed=true
                fi
                ;;
        esac
        
        if [[ "$installed" == false ]] && command -v opkg &>/dev/null; then
            if opkg list-installed 2>/dev/null | grep -q "^${pkg} "; then
                installed=true
                ver=$(opkg list-installed 2>/dev/null | grep "^${pkg} " | awk '{print $3}')
            fi
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
                    opkg update && {
                        if [[ "$pkg" == "7zip" || "$pkg" == "7z" ]]; then
                            opkg install p7zip && install_success=true
                        else
                            opkg install "$pkg" && install_success=true
                        fi
                    }
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
                    apt update -y && apt install -y "$pkg" && install_success=true
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

get_docker_token() {
    local repo=$1
    local pat=$2
    local token
    
    token=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:${repo}:pull,push,delete" \
        -H "Authorization: Bearer ${pat}" | jq -r '.token')
    
    if [[ -z "$token" || "$token" == "null" ]]; then
        token=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:${repo}:pull,push,delete" \
            -u "${pat}" | jq -r '.token')
    fi
    
    echo "$token"
}

main() {
    install curl jq

    local INPUT_PAT="$1"
    local INPUT_REPO="$2"
    local PAT REPO USER TOKEN

    clear
    echo -e "${gl_zi}>>> Docker Hub 镜像标签删除工具${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if [[ -z "${INPUT_PAT}" ]]; then
        read -r -e -p "$(echo -e "${gl_bai}请输入 Docker Hub PAT 或 用户名:密码(格式: username:password) (${gl_hong}0${gl_bai}退出): ")" PAT
        [[ "${PAT}" = "0" ]] && exit_script
    else
        PAT="${INPUT_PAT}"
        log_info "已使用传入的 PAT"
    fi

    if [[ -z "${INPUT_REPO}" ]]; then
        read -r -e -p "$(echo -e "${gl_bai}请输入仓库名称(格式:用户名/仓库名 ${gl_hong}0${gl_bai}退出，默认:mobufan/cmdbox): ")" REPO
        [[ "${REPO}" = "0" ]] && exit_script
        [[ -z "${REPO}" ]] && REPO="mobufan/cmdbox"
    else
        REPO="${INPUT_REPO}"
        log_info "已使用传入的仓库: ${REPO}"
    fi

    USER="${REPO%%/*}"
    echo -e "${gl_bai}当前操作用户: ${gl_lv}${USER}${gl_bai}，仓库: ${gl_huang}${REPO}${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    log_info "正在获取认证 Token ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    TOKEN=$(get_docker_token "$REPO" "$PAT")
    
    if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
        log_error "认证失败！请检查 PAT 或用户名密码是否正确"
        exit 1
    fi
    log_ok "认证成功"

    echo -e ""
    echo -e "${gl_huang}>>> 正在获取仓库所有标签 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    
    # 初始获取标签列表（使用 Hub API 获取完整列表）
    TAGS=$(curl -s "https://hub.docker.com/v2/repositories/${REPO}/tags?page_size=100" | jq -r '.results[].name')
    
    if [[ -z "${TAGS}" ]]; then
        log_error "获取标签失败或仓库无标签"
        exit 1
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_info "当前仓库所有标签列表:"
    echo "${TAGS}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local SELECT_TAG
    while true; do
        read -r -e -p "$(echo -e "${gl_bai}请输入要删除的标签名(${gl_hong}0${gl_bai}退出): ")" SELECT_TAG
        [[ "${SELECT_TAG}" = "0" ]] && exit_script
        if echo "${TAGS}" | grep -qw "${SELECT_TAG}"; then
            break
        else
            log_warn "输入的标签不存在，请重新输入"
        fi
    done

    echo -e ""
    echo -e "${gl_huang}>>> 标签 ${gl_lv}${SELECT_TAG}${gl_huang} 镜像摘要${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_info "正在获取标签 ${gl_huang}${SELECT_TAG}${gl_bai} 对应的镜像摘要 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    
    # 获取 digest（从 Registry API 获取）
    DIGEST=$(curl -s -I -X GET \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
        "https://registry-1.docker.io/v2/${REPO}/manifests/${SELECT_TAG}" 2>/dev/null | \
        grep -i "Docker-Content-Digest" | awk '{print $2}' | tr -d '\r')
    
    if [[ -z "${DIGEST}" ]]; then
        log_error "获取镜像摘要失败"
        exit 1
    fi
    
    log_info "镜像摘要: ${DIGEST}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local CONFIRM
    read -r -e -p "$(echo -e "${gl_bai}确认删除标签 [${gl_huang}${SELECT_TAG}${gl_bai}] ?(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" CONFIRM
    case "${CONFIRM}" in
        [Yy])
            echo -e ""
            echo -e "${gl_huang}>>> 开始执行删除操作 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            
            RESPONSE=$(curl -s -X DELETE \
                -H "Authorization: Bearer ${TOKEN}" \
                -w "\n%{http_code}" \
                "https://registry-1.docker.io/v2/${REPO}/manifests/${DIGEST}")
            
            HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
            BODY=$(echo "$RESPONSE" | sed '$d')
            
            if [[ "$HTTP_CODE" == "202" ]] || [[ "$HTTP_CODE" == "204" ]]; then
                log_ok "标签删除成功！"
                echo -e "${gl_lv}✓ 标签 ${SELECT_TAG} 已被删除${gl_bai}"
            else
                log_error "删除失败 (HTTP ${HTTP_CODE})"
                echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
                exit 1
            fi

            echo -e ""
            echo -e "${gl_huang}>>> 正在获取仓库最新标签列表 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            log_info "等待 3 秒让 Docker Hub 同步 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            sleep 3
            
            log_info "使用 Hub API 获取最新标签列表 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            NEW_TAGS=$(curl -s "https://hub.docker.com/v2/repositories/${REPO}/tags?page_size=100" | jq -r '.results[].name')
            
            # 如果 Hub API 返回空，尝试 Registry API
            if [[ -z "${NEW_TAGS}" ]]; then
                log_info "Hub API 未返回标签，尝试 Registry API ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                NEW_TAGS=$(curl -s -H "Authorization: Bearer ${TOKEN}" \
                    "https://registry-1.docker.io/v2/${REPO}/tags/list" | jq -r '.tags[]?')
            fi

            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            log_info "当前仓库所有标签列表:"
            if [[ -n "${NEW_TAGS}" ]]; then
                echo "${NEW_TAGS}"
                if echo "${NEW_TAGS}" | grep -qw "${SELECT_TAG}"; then
                    log_warn "⚠ 标签 ${SELECT_TAG} 仍然存在，Docker Hub 可能需要更多时间同步"
                    log_info "请稍后手动检查或等待 1-2 分钟后再试"
                else
                    log_ok "✓ 标签 ${gl_huang}${SELECT_TAG}${gl_bai} 已成功从列表中移除"
                fi
            else
                echo -e "${gl_huang}⚠ 仓库暂无标签或 API 尚未同步${gl_bai}"
                log_warn "如果仓库确实还有标签，请稍后手动刷新查看"
            fi
            ;;
        [Nn])
            log_warn "已取消删除操作"
            ;;
        *)
            handle_y_n
            ;;
    esac

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

main "$@"