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
    local int_seconds=$(awk -v s="$seconds" 'BEGIN{print int(s+0.999)}')
    sleep "$int_seconds"
}

install() {
    [[ $# -eq 0 ]] && { log_error "未提供软件包参数!"; return 1; }
    local pkg mgr installed=false ver=""
    for pkg in "$@"; do
        installed=false; ver=""
        if command -v "$pkg" &>/dev/null; then
            cmd_ver=$("$pkg" --version 2>/dev/null | head -n1 | tr -cd '[:print:]' | grep -oE '[0-9]+(\.[0-9]+)+' | head -n1 || echo "")
            [[ -n "$cmd_ver" ]] && ver="$cmd_ver" && installed=true
        fi
        if [[ "$pkg" == "7zip" || "$pkg" == "7z" ]]; then
            command -v 7z &>/dev/null && { ver=$(7z 2>&1 | grep -oE '[0-9]+(\.[0-9]+)+' | head -n1 || echo ""); installed=true; }
        fi
        if [[ "$installed" == false ]]; then
            if command -v opkg &>/dev/null; then
                opkg list-installed | grep -q "^${pkg} " && { installed=true; ver=$(opkg list-installed | grep "^${pkg} " | awk '{print $3}' 2>/dev/null || echo ""); }
            elif command -v dpkg-query &>/dev/null; then
                dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed" && { installed=true; ver=$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null || echo ""); }
            elif command -v rpm &>/dev/null; then
                rpm -q "$pkg" &>/dev/null && { installed=true; ver=$(rpm -q --qf '%{VERSION}' "$pkg" 2>/dev/null || echo ""); }
            elif command -v apk &>/dev/null; then
                apk info "$pkg" 2>/dev/null | grep -q "^installed" && { installed=true; ver=$(apk info -a "$pkg" 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)+' | head -n1 || echo ""); }
            elif command -v pacman &>/dev/null; then
                pacman -Qi "$pkg" &>/dev/null && { installed=true; ver=$(pacman -Qi "$pkg" 2>/dev/null | grep -i "version" | grep -oE '[0-9]+(\.[0-9]+)+' | head -n1 || echo ""); }
            fi
        fi
        if [[ "$installed" == true ]]; then
            echo -e "${gl_huang}${pkg}${gl_bai} ${gl_lv}已安装${gl_bai}$([[ -n "$ver" ]] && echo " 版本 ${gl_lv}${ver}${gl_bai}")"
            continue
        fi
        echo -e "\n${gl_huang}开始安装：${gl_bai}${pkg}"
        local install_success=false
        for mgr in opkg dnf yum apt apk pacman zypper pkg; do
            command -v "$mgr" &>/dev/null || continue
            case $mgr in
            opkg)
                [[ "$pkg" == "7zip" || "$pkg" == "7z" ]] && { opkg update && opkg install p7zip && install_success=true; } || { opkg update && opkg install "$pkg" && install_success=true; }
                ;;
            dnf) dnf -y update && dnf install -y "$pkg" && install_success=true ;;
            yum) yum -y update && yum install -y "$pkg" && install_success=true ;;
            apt) apt update -y && apt install -y "$pkg" && install_success=true ;;
            apk) apk update && apk add "$pkg" && install_success=true ;;
            pacman) pacman -Syu --noconfirm && pacman -S --noconfirm "$pkg" && install_success=true ;;
            zypper) zypper refresh && zypper install -y "$pkg" && install_success=true ;;
            pkg) pkg update && pkg install -y "$pkg" && install_success=true ;;
            esac
            [[ "$install_success" == true ]] && break
        done
        [[ "$install_success" == true ]] && echo -e "${gl_lv}✓ ${pkg} 安装成功${gl_bai}" || echo -e "${gl_hong}✗ ${pkg} 安装失败${gl_bai}"
    done
}

backup_all_docker_images() {
    local BACKUP_ROOT="$1"
    local RETAIN_COUNT="$2"

    log_info "安装依赖 tar jq gzip pigz"
    install tar jq gzip pigz

    if ! command -v docker &>/dev/null || ! docker info &>/dev/null; then
        log_error "Docker未安装或未运行"
        return 1
    fi

    clear
    echo -e "${gl_zi}>>> 备份所有 Docker 镜像${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    if [[ -n "${RETAIN_COUNT}" && "${RETAIN_COUNT}" -gt 0 ]]; then
        log_info "轮转策略：总共保留 ${RETAIN_COUNT} 套备份(含本次新建)"
        mapfile -t EXIST_BACKUPS < <(find "${BACKUP_ROOT}" -maxdepth 1 -type d -name "images_backup_*" | sort)
        local exist_cnt=${#EXIST_BACKUPS[@]}
        log_info "当前已存在历史备份: ${exist_cnt} 套"
        # 本次会新增1套，所以历史最多允许保留 RETAIN_COUNT -1 套
        local max_keep_history=$(( RETAIN_COUNT - 1 ))
        if [[ ${exist_cnt} -gt ${max_keep_history} ]]; then
            local del_cnt=$(( exist_cnt - max_keep_history ))
            log_warn "历史备份超出配额，将删除最旧 ${del_cnt} 套备份"
            for ((i=0; i<del_cnt; i++)); do
                local rm_dir="${EXIST_BACKUPS[$i]}"
                log_info "删除旧备份: ${rm_dir}"
                rm -rf "${rm_dir}"
            done
        else
            log_info "历史备份数量(${exist_cnt}) ≤ 允许历史保留(${max_keep_history})，无需删除"
        fi
    fi

    local DATE_STR=$(date +%Y%m%d_%H%M%S)
    local BACKUP_DIR="${BACKUP_ROOT}/images_backup_${DATE_STR}"
    mkdir -p "$BACKUP_DIR"
    log_info "本次备份目录: ${BACKUP_DIR}"

    mapfile -t IMAGES < <(docker images --format "{{.Repository}}:{{.Tag}}" | grep -v "<none>" | grep -v "REPOSITORY:TAG")
    if [[ ${#IMAGES[@]} -eq 0 ]]; then
        log_warn "未找到任何Docker镜像，退出"
        return 0
    fi
    log_info "共计 ${#IMAGES[@]} 个镜像，全部开始备份"

    local RESTORE_SCRIPT="${BACKUP_DIR}/restore_images.sh"
    cat >"$RESTORE_SCRIPT" <<'EOF'
#!/bin/bash
set -e
gl_bai='\033[0m';gl_bufan='\033[96m';gl_lv='\033[32m';gl_huang='\033[33m';gl_hong='\033[31m';gl_zi='\033[35m'
BACKUP_DIR="$(cd "$(dirname "$0")"; pwd)"
MANIFEST="${BACKUP_DIR}/manifest.json"
[[ ! -f "$MANIFEST" ]] && { echo -e "${gl_hong}错误:未找到manifest.json${gl_bai}";exit 1; }
IMAGE_COUNT=$(jq '.images | length' "$MANIFEST")
echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
echo -e "${gl_zi}>>>恢复Docker镜像${gl_bai}"
for i in $(seq 0 $((IMAGE_COUNT-1))); do
    IMAGE_NAME=$(jq -r ".images[$i].name" "$MANIFEST")
    IMAGE_FILE=$(jq -r ".images[$i].file" "$MANIFEST")
    IMAGE_PATH="${BACKUP_DIR}/${IMAGE_FILE}"
    echo -e "${gl_bai}[$((i+1))/${IMAGE_COUNT}]加载镜像:${gl_huang}${IMAGE_NAME}${gl_bai}"
    [[ -f "$IMAGE_PATH" ]] && docker load -i "$IMAGE_PATH" && echo -e "${gl_lv}✓完成${gl_bai}" || echo -e "${gl_hong}✗文件不存在${IMAGE_FILE}${gl_bai}"
done
echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
echo -e "${gl_lv}全部镜像加载完成！执行docker images查看${gl_bai}"
EOF
    chmod +x "$RESTORE_SCRIPT"

    local MANIFEST="${BACKUP_DIR}/manifest.json"
    cat >"$MANIFEST" <<EOF
{
    "backup_date": "$(date -Iseconds)",
    "images": []
}
EOF

    local success_count=0 fail_count=0
    for i in "${!IMAGES[@]}"; do
        local image="${IMAGES[i]}"
        local safe_name=$(echo "$image" | sed 's/[\/:]/-/g' | sed 's/^-*//')
        local backup_file="${safe_name}.tar"
        echo -e "${gl_bai}[$((i + 1))/${#IMAGES[@]}]备份镜像: ${gl_huang}${image}${gl_bai}"
        if docker save -o "${BACKUP_DIR}/${backup_file}" "$image" 2>/dev/null; then
            if command -v pigz &>/dev/null; then pigz "${BACKUP_DIR}/${backup_file}"; backup_file="${backup_file}.gz";
            else gzip "${BACKUP_DIR}/${backup_file}"; backup_file="${backup_file}.gz"; fi
            jq --arg name "$image" --arg file "$backup_file" '.images += [{"name":$name,"file":$file}]' "$MANIFEST" >"${MANIFEST}.tmp" && mv "${MANIFEST}.tmp" "$MANIFEST"
            echo -e "${gl_lv}✓成功${gl_bai}"
            ((success_count++))
        else
            echo -e "${gl_hong}✗失败${gl_bai}"
            ((fail_count++))
        fi
    done

    local total_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1 || echo "未知")
    echo -e "${gl_bufan}================================================${gl_bai}"
    log_ok "镜像备份任务结束"
    echo -e "备份目录  : ${gl_huang}${BACKUP_DIR}${gl_bai}"
    echo -e "成功镜像  : ${gl_huang}${success_count}/${#IMAGES[@]}${gl_bai}"
    echo -e "备份总大小: ${gl_huang}${total_size}${gl_bai}"
    echo -e "恢复脚本  : ${gl_huang}${RESTORE_SCRIPT}${gl_bai}"
    [[ $fail_count -gt 0 ]] && log_warn "有 ${fail_count} 个镜像备份失败"
    echo -e "${gl_bufan}================================================${gl_bai}"
}

ARG_BACKUP_ROOT="/mnt/backup_images"
ARG_RETAIN=""

for arg in "$@"; do
    if [[ "$arg" =~ ^[0-9]+$ ]]; then
        ARG_RETAIN="$arg"
    else
        ARG_BACKUP_ROOT="$arg"
    fi
done

backup_all_docker_images "${ARG_BACKUP_ROOT}" "${ARG_RETAIN}"
