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
    if command -v perl >/dev/null 2>&1; then
        perl -e "select(undef, undef, undef, $seconds)"
        return 0
    fi
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "import time; time.sleep($seconds)"
        return 0
    fi
    if command -v python >/dev/null 2>&1; then
        python -c "import time; time.sleep($seconds)"
        return 0
    fi
    sleep "$(awk -v s="$seconds" 'BEGIN{print int(s+0.999)}')"
}

BACKUP_ROOT="/mnt/backup_images"
BACKUP_DIR=""

install_dep() {
    local pkg="$1"
    command -v "$pkg" &>/dev/null && return 0
    for mgr in apt apk opkg dnf yum pacman; do
        command -v "$mgr" &>/dev/null || continue
        case "$mgr" in
            apt) apt update -y && apt install -y "$pkg" ;;
            apk) apk update && apk add "$pkg" ;;
            opkg) opkg update && opkg install "$pkg" ;;
            dnf) dnf -y install "$pkg" ;;
            yum) yum -y install "$pkg" ;;
            pacman) pacman -S --noconfirm "$pkg" ;;
        esac
        [[ $? -eq 0 ]] && return 0
    done
    log_error "无法安装依赖 $pkg"
    return 1
}

list_backups() {
    shopt -s nullglob
    local arr=("${BACKUP_ROOT}"/images_backup_*)
    shopt -u nullglob
    [[ ${#arr[@]} -eq 0 ]] && return 1
    printf "%s\n" "${arr[@]}"
}

get_latest_backup() {
    list_backups | sort -r | head -n1
}

validate_backup() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        log_error "备份目录不存在: $dir"
        return 1
    fi
    if [[ ! -f "${dir}/manifest.json" ]]; then
        log_error "manifest.json 不存在，不是合法镜像备份目录: $dir"
        return 1
    fi
    return 0
}

pick_backup() {
    local backups
    backups=$(list_backups) || {
        log_error "默认目录 ${BACKUP_ROOT} 没有备份"
        return 1
    }

    local arr=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && arr+=("$line")
    done <<< "$backups"

    if [[ ${#arr[@]} -eq 1 ]]; then
        BACKUP_DIR="${arr[0]}"
        return 0
    fi

    BACKUP_DIR=$(get_latest_backup)
    if [[ -t 0 && -t 1 ]]; then
        echo -e "${gl_zi}>>> 选择要还原的备份${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        for ((i=0; i<${#arr[@]}; i++)); do
            echo -e "  ${gl_huang}$((i+1))${gl_bai}. ${arr[$i]}"
        done
        echo -e "  ${gl_huang}0${gl_bai}. 使用最新备份 (${gl_zi}${BACKUP_DIR}${gl_bai})"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -p "请输入你的选择: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#arr[@]} )); then
            BACKUP_DIR="${arr[$((choice-1))]}"
        fi
    fi
    return 0
}

main() {
    local arg="${1:-}"
    if [[ -n "$arg" ]]; then
        validate_backup "$arg" || exit 1
        BACKUP_DIR="$arg"
    else
        pick_backup || exit 1
    fi

    if ! command -v docker &>/dev/null || ! docker info &>/dev/null; then
        log_error "docker未安装或未运行"
        exit 1
    fi

    install_dep jq || exit 1
    install_dep gzip || exit 1

    local MANIFEST="${BACKUP_DIR}/manifest.json"
    local IMAGE_COUNT
    IMAGE_COUNT=$(jq -r '.images | length' "$MANIFEST")
    log_info "备份目录: ${BACKUP_DIR}"
    log_info "需要恢复镜像总数: ${IMAGE_COUNT}"

    local success=0 fail=0
    for ((i=0; i<IMAGE_COUNT; i++)); do
        local IMAGE_NAME IMAGE_FILE IMAGE_PATH
        IMAGE_NAME=$(jq -r ".images[$i].name" "$MANIFEST")
        IMAGE_FILE=$(jq -r ".images[$i].file" "$MANIFEST")
        IMAGE_PATH="${BACKUP_DIR}/${IMAGE_FILE}"

        echo -e "${gl_huang}[$((i+1))/${IMAGE_COUNT}]${gl_bai} 加载镜像: ${gl_zi}${IMAGE_NAME}${gl_bai}"
        if [[ ! -f "$IMAGE_PATH" ]]; then
            log_error "文件缺失 ${IMAGE_FILE}"
            ((fail++))
            continue
        fi
        if docker load -i "$IMAGE_PATH"; then
            log_ok "加载成功: ${IMAGE_NAME}"
            ((success++))
        else
            log_error "docker load 失败: ${IMAGE_NAME}"
            ((fail++))
        fi
    done

    echo -e "${gl_bufan}========================================${gl_bai}"
    if [[ $fail -gt 0 ]]; then
        log_error "恢复完成: 成功 ${success} , 失败 ${fail}"
        exit 2
    fi
    log_ok "恢复完成: 成功 ${success} , 失败 ${fail}"
    exit 0
}

main "$@"
