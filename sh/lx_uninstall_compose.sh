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
    read -r -n 1 -s -p ""
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
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local dots=(
        "${gl_hong}."
        "${gl_huang}."
        "${gl_lv}."
        "${gl_bufan}."
        "${gl_zi}."
    )
    local dot_buffer=""
    local frame_len=${#frames[@]}
    local dot_idx=0
    local total_dots=${#dots[@]}


    for ((i=0; i<20; i++)); do
        if (( i > 0 && i % 3 == 0 && dot_idx < total_dots )); then
            dot_buffer+=${dots[$dot_idx]}
            ((dot_idx++))
        fi
        echo -ne "\r\033[K${gl_bufan}${frames[i % frame_len]}${gl_bai} 正在退出 ${dot_buffer}"
        sleep_fractional 0.06
    done
    echo -e "\r\033[K${gl_lv}✓${gl_bai} 成功退出\n"
    clear
    exit 0
}

uninstall_docker_compose() {
    clear
    echo -e "${gl_zi}>>> Docker Compose 卸载${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    log_info "正在检查已安装的 Docker Compose ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

    local FOUND_FILES=()
    local VERSION_INFO=""
    local INSTALLED=false

    local OLD_VERSION=""
    if command -v docker-compose &>/dev/null; then
        OLD_VERSION=$(docker-compose --version 2>/dev/null)
    elif docker compose version &>/dev/null 2>&1; then
        OLD_VERSION=$(docker compose version 2>&1 | head -n 1)
    fi

    if command -v docker-compose &>/dev/null; then
        VERSION_INFO=$(docker-compose --version 2>/dev/null)
        INSTALLED=true
        log_ok "在系统 PATH 中找到: $(which docker-compose)"
    fi

    local CHECK_PATHS=(
        "/usr/bin/docker-compose"
        "/usr/local/bin/docker-compose"
        "/usr/local/bin/docker-compose-plugin"
        "/bin/docker-compose"
        "/usr/sbin/docker-compose"
    )

    for path in "${CHECK_PATHS[@]}"; do
        if [ -f "$path" ] || [ -L "$path" ]; then
            FOUND_FILES+=("$path")
            log_info "发现文件: $path"
            [ -z "$VERSION_INFO" ] && VERSION_INFO=$("$path" --version 2>/dev/null)
            INSTALLED=true
        fi
    done

    local PLUGIN_PATHS=(
        "/usr/libexec/docker/cli-plugins/docker-compose"
        "/usr/local/libexec/docker/cli-plugins/docker-compose"
        "/usr/local/lib/docker/cli-plugins/docker-compose"
        "/usr/lib/docker/cli-plugins/docker-compose"
        "$HOME/.docker/cli-plugins/docker-compose"
        "/root/.docker/cli-plugins/docker-compose"
    )

    for path in "${PLUGIN_PATHS[@]}"; do
        if [ -f "$path" ] || [ -L "$path" ]; then
            FOUND_FILES+=("$path")
            log_info "发现插件: $path"
            INSTALLED=true
        fi
    done

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if [ "$INSTALLED" = false ]; then
        log_warn "未找到 Docker Compose 安装文件"
        read -r -e -p "$(echo -e "${gl_bai}是否全盘搜索? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" search_more
        if [[ "$search_more" =~ ^[Yy]$ ]]; then
            log_info "正在全盘搜索 docker-compose 文件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            while read -r file; do
                [ -z "$file" ] && continue
                FOUND_FILES+=("$file")
                log_info "发现: $file"
                INSTALLED=true
            done < <(find / -name "*docker-compose*" -type f -executable 2>/dev/null | grep -E "(docker-compose|docker/compose)" | head -20)
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        fi
    fi

    if [ "$INSTALLED" = false ]; then
        log_error "系统未安装 Docker Compose"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation
        return
    fi

    [ -n "$VERSION_INFO" ] && { log_info "当前版本信息:"; echo -e "${gl_hui}$VERSION_INFO${gl_bai}"; }

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if [ ${#FOUND_FILES[@]} -gt 0 ]; then
        log_warn "将删除以下文件:"
        for file in "${FOUND_FILES[@]}"; do echo -e "${gl_hui}  $file${gl_bai}"; done
    fi

    echo ""
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}确认卸载 Docker Compose? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm_uninstall
    [ "$confirm_uninstall" = "0" ] && { exit_script; }

    if [[ ! "$confirm_uninstall" =~ ^[Yy]$ ]]; then
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_hong}卸载已取消${gl_bai}"
        exit_animation
        return
    fi

    log_info "正在卸载 Docker Compose ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

    local REMOVED_COUNT=0
    local FAILED_FILES=()

    for file in "${FOUND_FILES[@]}"; do
        log_info "正在删除: $file"
        if sudo rm -f "$file" 2>/dev/null; then
            ((REMOVED_COUNT++))
            log_ok "删除成功"
        else
            log_error "删除失败"
            FAILED_FILES+=("$file")
        fi
    done

    hash -r 2>/dev/null
    log_info "已清理命令缓存"

    command -v docker &>/dev/null && { docker compose version &>/dev/null 2>&1; log_info "已清理 Docker 插件缓存"; }

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    [ $REMOVED_COUNT -gt 0 ] && log_ok "已成功删除 $REMOVED_COUNT 个文件"
    [ ${#FAILED_FILES[@]} -gt 0 ] && { log_error "以下文件删除失败:"; for f in "${FAILED_FILES[@]}"; do echo -e "${gl_hui}  $f${gl_bai}"; done; }

    log_info "验证卸载结果:"
    local STILL_INSTALLED=false

    if command -v docker-compose &>/dev/null; then
        log_warn "docker-compose 命令仍存在"
        STILL_INSTALLED=true
    fi

    if ! docker compose version &>/dev/null 2>&1; then
        log_ok "Docker Compose 插件已成功卸载"
    else
        log_warn "Docker Compose 插件仍存在，建议重启 Docker/终端"
    fi

    [ "$STILL_INSTALLED" = false ] && log_ok "Docker Compose 已完全卸载！"

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

uninstall_docker_compose
