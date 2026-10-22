#!/bin/bash
set -uo pipefail

# ============================================================
# Compose 项目备份 / 迁移 / 恢复 / 管理工具
# 参考: docker_images_manager.sh
# 用法:
#   ./compose_images_manager.sh                      # 交互菜单
#   ./compose_images_manager.sh -c <目录> -b <目录>   # 备份（进入选择菜单）
#   ./compose_images_manager.sh -c <目录> -b <目录> -a   # 备份全部子项目
#   ./compose_images_manager.sh -c <目录> -b <目录> -p <项目名>  # 备份单个项目
#   ./compose_images_manager.sh -r -a                # 恢复全部备份
#   ./compose_images_manager.sh -r -p <项目名>       # 恢复单个项目
#   ./compose_images_manager.sh -r -c <目录> -b <目录> -a        # 指定目录恢复全部
#   追加 --dry-run 仅打印将执行的动作，不导出、不打包
# ============================================================

COMPOSE_ROOT="${COMPOSE_ROOT:-/vol1/1000/compose}"
BACKUP_ROOT="${BACKUP_ROOT:-/mnt/backup_compose}"
DRY_RUN=0
ACTION=""
BATCH=0
PROJECT_TARGET=""
CLI_MODE=0
ACTION_SET=0
DELETE_IMAGE_PKGS=0

usage() {
    cat <<EOF
用法: $0 [选项]

选项:
  -c, --compose <目录>   Compose 项目根目录（默认: /vol1/1000/compose）
  -b, --backup  <目录>   备份根目录（默认: /mnt/backup_compose）
  -r, --restore          恢复模式（默认执行备份）
  -a, --all              批量处理全部项目 / 全部备份
  -p, --project <名称>   只处理指定项目
      --dry-run          试运行：只打印动作，不导出、不打包、不启动
      --delete-pkgs      恢复后删除已加载的 *_dd.tar.gz 镜像包（不询问）
  -h, --help             显示帮助

示例:
  $0 -c /vol1/1000/compose -b /mnt/backup_compose
  $0 -c /vol1/1000/compose -b /mnt/backup_compose -a
  $0 -r -a
  $0 -r -p dufs-zh
  $0 -c /vol1/1000/compose -b /mnt/backup_compose --dry-run -a
EOF
}

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

exit_animation() {
    echo -ne "\r${gl_lv}即将退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo ""
}

cancel_empty() {
    local menu_name="${1:-上一级选单}"
    echo -e "${gl_hong}空输入，返回 ${gl_huang}${menu_name} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo ""
    clear
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

handle_invalid_input() {
    echo -ne "\r${gl_huang}无效的输入,请重新输入! ${gl_zi}1${gl_huang}秒后返回"
    sleep_fractional 1
    echo -e "\r${gl_lv}无效的输入,请重新输入! ${gl_zi}0${gl_lv}秒后返回"
    sleep_fractional 0.5
    return 2
}

exit_script() {
    clear
    exit 0
}

column_if_available() {
    if command -v column &> /dev/null; then
        column -t -s $'\t'
    else
        cat
    fi
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

ensure_dependencies() {
    install tar gzip
    if ! command -v pigz &>/dev/null; then
        install pigz
    fi
    if ! command -v curl &>/dev/null; then
        install curl
    fi
}

require_docker() {
    if ! command -v docker &>/dev/null; then
        log_error "Docker 未安装，无法继续"
        return 1
    fi
    if ! docker info &>/dev/null; then
        log_error "Docker 未运行或当前用户无权限，无法继续"
        return 1
    fi
    return 0
}

compress_cmd() {
    if command -v pigz &>/dev/null; then
        echo pigz
    else
        echo gzip
    fi
}

tar_create() {
    local out="$1" base="$2" name="$3"
    if command -v pigz &>/dev/null; then
        tar -I pigz -cf "$out" -C "$base" "$name"
    else
        tar -czf "$out" -C "$base" "$name"
    fi
}

compose_up() {
    local compose_file="$1"
    if docker compose version >/dev/null 2>&1; then
        docker compose -f "$compose_file" up -d
    elif command -v docker-compose >/dev/null 2>&1; then
        docker-compose -f "$compose_file" up -d
    else
        log_error "未找到 docker compose / docker-compose"
        return 1
    fi
}

find_compose_file() {
    local dir="$1" f
    for f in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
        if [[ -f "$dir/$f" ]]; then
            echo "$dir/$f"
            return 0
        fi
    done
    return 1
}

parse_images() {
    local compose_file="$1" images=""
    if docker compose version >/dev/null 2>&1; then
        images=$(docker compose -f "$compose_file" config --images 2>/dev/null)
    elif command -v docker-compose >/dev/null 2>&1; then
        images=$(docker-compose -f "$compose_file" config --images 2>/dev/null)
    fi

    if [[ -z "$images" ]]; then
        images=$(grep -E '^[[:space:]]*image:[[:space:]]*' "$compose_file" 2>/dev/null \
            | sed -E 's/^[[:space:]]*image:[[:space:]]*//' \
            | sed -E 's/[[:space:]]*#.*$//' \
            | tr -d "\"'" \
            | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' \
            | grep -v '^$')
    fi

    if [[ -n "$images" ]]; then
        printf '%s\n' "$images" | sort -u
    fi
}

image_pkg_basename() {
    local img="$1" name tag base
    img="${img#docker.io/}"

    if [[ "$img" == *"@"* ]]; then
        name="${img%@*}"
        tag="${img##*@}"
        tag="${tag//:/_}"
    elif [[ "$img" == *":"* && "${img##*:}" != *"/"* ]]; then
        name="${img%:*}"
        tag="${img##*:}"
    else
        name="$img"
        tag="latest"
    fi

    base="${name##*/}"
    echo "${base}_${tag}_dd"
}

list_subprojects() {
    local d
    COMPOSE_PROJECTS=()
    [[ -d "$COMPOSE_ROOT" ]] || return 0
    shopt -s nullglob
    for d in "$COMPOSE_ROOT"/*/; do
        [[ -d "$d" ]] && COMPOSE_PROJECTS+=("$(basename "$d")")
    done
    shopt -u nullglob
}

list_backups() {
    local f
    COMPOSE_BACKUPS=()
    [[ -d "$BACKUP_ROOT" ]] || return 0
    shopt -s nullglob
    for f in "$BACKUP_ROOT"/*.tar.gz; do
        [[ -f "$f" ]] && COMPOSE_BACKUPS+=("$f")
    done
    shopt -u nullglob
}

print_two_columns() {
    local -a items=("$@")
    local n=${#items[@]}
    local half=$(( (n + 1) / 2 ))
    local i j left right
    [[ $n -eq 0 ]] && return 0
    for ((i = 0; i < half; i++)); do
        left="${items[i]}"
        j=$((i + half))
        if (( j < n )); then
            right="${items[j]}"
            printf "%3d. %-24s\t%3d. %s\n" "$((i + 1))" "$left" "$((j + 1))" "$right"
        else
            printf "%3d. %-24s\n" "$((i + 1))" "$left"
        fi
    done | column_if_available
}

resolve_choice() {
    local choice="$1"
    shift
    local -a arr=("$@")
    if [[ "$choice" =~ ^[0-9]+$ ]]; then
        local idx=$((choice - 1))
        if (( idx >= 0 && idx < ${#arr[@]} )); then
            echo "${arr[idx]}"
            return 0
        fi
        return 1
    fi
    echo "$choice"
    return 0
}

backup_one_project() {
    local project_dir="$1" project_name compose_file images
    project_name="$(basename "$project_dir")"
    local img_count=0 img_ok=0 img_skip=0 img_fail=0 img pkg out tmp
    local -a exported_pkgs=()

    echo -e "${gl_zi}>>> 备份 ${gl_huang}$project_name${gl_zi} 项目${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if ! compose_file="$(find_compose_file "$project_dir")"; then
        log_warn "[$project_name] 未找到 docker-compose.yml/.yaml，跳过"
        return 2
    fi

    log_info "[$project_name] 使用 Compose 文件: $compose_file"
    images="$(parse_images "$compose_file")"

    if [[ -z "$images" ]]; then
        log_warn "[$project_name] 未解析到任何 image 字段，跳过"
        return 2
    fi

    while IFS= read -r img; do
        [[ -z "$img" ]] && continue
        img_count=$((img_count + 1))

        if ! docker image inspect "$img" >/dev/null 2>&1; then
            log_warn "  镜像本地不存在，跳过: $img"
            img_skip=$((img_skip + 1))
            continue
        fi

        pkg="$(image_pkg_basename "$img")"
        out="$project_dir/${pkg}.tar.gz"

        if [[ $DRY_RUN -eq 1 ]]; then
            log_info "  [dry-run] docker save $img | $(compress_cmd) -c > $out"
            img_ok=$((img_ok + 1))
            continue
        fi

        log_info "  导出镜像: $img -> ${pkg}.tar.gz"
        tmp="${out}.tmp"
        if docker save "$img" 2>/dev/null | "$(compress_cmd)" -c > "$tmp" && [[ -s "$tmp" ]]; then
            mv -f "$tmp" "$out"
            log_ok "  已 导 出: ${pkg}.tar.gz ($(du -h "$out" 2>/dev/null | cut -f1))"
            exported_pkgs+=("$out")
            img_ok=$((img_ok + 1))
        else
            rm -f "$tmp"
            log_error "  导出失败: $img"
            img_fail=$((img_fail + 1))
        fi
    done <<< "$images"

    local archive="$BACKUP_ROOT/${project_name}.tar.gz"
    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[$project_name] [dry-run] tar -czf $archive -C $(dirname "$project_dir") $project_name"
        log_ok "[$project_name] 汇总: 镜像 ${img_count} 个（导出 ${img_ok}，跳过 ${img_skip}，失败 ${img_fail}）"
        return 0
    fi

    mkdir -p "$BACKUP_ROOT"
    local atmp="${archive}.tmp"
    if tar_create "$atmp" "$(dirname "$project_dir")" "$project_name"; then
        mv -f "$atmp" "$archive"
        log_ok "[$project_name] 项目备份完成: $archive ($(du -h "$archive" 2>/dev/null | cut -f1))"
        log_ok "[$project_name] 汇总: 镜像 ${img_count} 个（导出 ${img_ok}，跳过 ${img_skip}，失败 ${img_fail}）"
        if [[ ${#exported_pkgs[@]} -gt 0 ]]; then
            local p
            for p in "${exported_pkgs[@]}"; do
                if rm -f "$p"; then
                    log_ok "[$project_name] 删除镜像包: $p"
                else
                    log_warn "删除镜像包失败: $p"
                fi
            done
        fi
        return 0
    else
        rm -f "$atmp"
        log_error "[$project_name] 项目打包失败"
        return 1
    fi
}

backup_all_projects() {
    ensure_dependencies
    require_docker || return 1
    list_subprojects

    if [[ ${#COMPOSE_PROJECTS[@]} -eq 0 ]]; then
        log_warn "未在 $COMPOSE_ROOT 下找到任何子项目目录"
        return 1
    fi

    local ok=0 skip=0 fail=0 name rc

    clear
    echo -e "${gl_zi}>>> 批量备份 Compose 项目（共 ${gl_huang}${#COMPOSE_PROJECTS[@]} ${gl_zi}个）${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e ""

    for name in "${COMPOSE_PROJECTS[@]}"; do
        backup_one_project "$COMPOSE_ROOT/$name"
        rc=$?
        case $rc in
        0) ok=$((ok + 1)) ;;
        2) skip=$((skip + 1)) ;;
        *) fail=$((fail + 1)) ;;
        esac
        echo -e ""
    done

    log_ok "批量备份结束：成功 ${ok}，跳过 ${skip}，失败 ${fail}"
}

is_safe_tar() {
    local file="$1" entry
    while IFS= read -r entry; do
        [[ -z "$entry" ]] && continue
        case "$entry" in
        /* | ../* | */../* | ..) return 1 ;;
        esac
    done < <(tar -tzf "$file" 2>/dev/null)
    return 0
}

delete_image_packages() {
    local project_dir="$1" p pkg_count=0
    [[ -d "$project_dir" ]] || return 0
    shopt -s nullglob
    for p in "$project_dir"/*_dd.tar.gz; do
        rm -f "$p"
        pkg_count=$((pkg_count + 1))
    done
    shopt -u nullglob
    [[ $pkg_count -gt 0 ]] && log_ok "已删除 ${pkg_count} 个镜像包: $project_dir"
    return 0
}

restore_one_backup() {
    local backup_file="$1" project_name project_dir compose_file
    local p pkg_count=0 pkg_ok=0 pkg_fail=0

    project_name="$(basename "$backup_file")"
    project_name="${project_name%.tar.gz}"

    echo -e ""
    echo -e "${gl_zi}>>> 恢复 ${gl_huang}$project_name${gl_zi} 项目${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if ! tar -tzf "$backup_file" >/dev/null 2>&1; then
        log_warn "[$project_name] 备份包损坏或不是 tar.gz，跳过: $backup_file"
        return 2
    fi

    if ! is_safe_tar "$backup_file"; then
        log_warn "[$project_name] 备份包含非法路径，跳过: $backup_file"
        return 2
    fi

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[$project_name] [dry-run] tar -xzf $backup_file -C $COMPOSE_ROOT"
    else
        mkdir -p "$COMPOSE_ROOT"
        if ! tar -xzf "$backup_file" -C "$COMPOSE_ROOT"; then
            log_error "[$project_name] 解压失败: $backup_file"
            return 1
        fi
        log_ok "[$project_name] 已解压到: $COMPOSE_ROOT/$project_name"
    fi

    project_dir="$COMPOSE_ROOT/$project_name"
    if ! compose_file="$(find_compose_file "$project_dir")"; then
        log_warn "[$project_name] 恢复后未找到 compose 文件，跳过启动"
        return 2
    fi

    shopt -s nullglob
    local -a pkgs=("$project_dir"/*_dd.tar.gz)
    shopt -u nullglob

    pkg_count=${#pkgs[@]}
    if [[ $pkg_count -eq 0 ]]; then
        log_warn "[$project_name] 未找到 *_dd.tar.gz 镜像包，仅恢复配置"
    else
        for p in "${pkgs[@]}"; do
            if [[ $DRY_RUN -eq 1 ]]; then
                log_info "  [dry-run] docker load -i $p"
                pkg_ok=$((pkg_ok + 1))
                continue
            fi
            if docker load -i "$p" >/dev/null 2>&1; then
                log_ok "  已导入镜像包: $(basename "$p")"
                pkg_ok=$((pkg_ok + 1))
            else
                log_error "  导入失败: $(basename "$p")"
                pkg_fail=$((pkg_fail + 1))
            fi
        done
    fi

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[$project_name] [dry-run] docker compose -f $compose_file up -d"
        log_ok "[$project_name] 汇总: 镜像包 ${pkg_count} 个（成功 ${pkg_ok}，失败 ${pkg_fail}）"
        return 0
    fi

    if (cd "$project_dir" && compose_up "$compose_file" >/dev/null 2>&1); then
        log_ok "[$project_name] 已启动: docker compose -f $compose_file up -d"
    else
        log_error "[$project_name] 启动失败，请手动执行: docker compose -f $compose_file up -d"
    fi

    log_ok "[$project_name] 汇总: 镜像包 ${pkg_count} 个（成功 ${pkg_ok}，失败 ${pkg_fail}）"

    if [[ $DELETE_IMAGE_PKGS -eq 1 && $pkg_count -gt 0 ]]; then
        delete_image_packages "$project_dir"
    fi

    return 0
}

restore_all_backups() {
    ensure_dependencies
    require_docker || return 1
    list_backups

    if [[ ${#COMPOSE_BACKUPS[@]} -eq 0 ]]; then
        log_warn "未在 $BACKUP_ROOT 下找到任何 *.tar.gz 备份包"
        return 1
    fi

    local ok=0 skip=0 fail=0 f rc
    local -a restored_dirs=()

    clear
    echo -e "${gl_zi}>>> 批量恢复 Compose 备份（共 ${gl_huang}${#COMPOSE_BACKUPS[@]} ${gl_zi}个）${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e ""

    for f in "${COMPOSE_BACKUPS[@]}"; do
        restore_one_backup "$f"
        rc=$?
        case $rc in
        0) ok=$((ok + 1)); restored_dirs+=("$COMPOSE_ROOT/$(basename "${f%.tar.gz}")") ;;
        2) skip=$((skip + 1)) ;;
        *) fail=$((fail + 1)) ;;
        esac
        echo -e ""
    done

    if [[ $DRY_RUN -eq 0 && $DELETE_IMAGE_PKGS -eq 0 && ${#restored_dirs[@]} -gt 0 ]]; then
        local confirm
        read -r -e -p "$(echo -e "${gl_bai}是否删除已加载的镜像包 *_dd.tar.gz ? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            local d
            for d in "${restored_dirs[@]}"; do
                delete_image_packages "$d"
            done
        else
            log_info "已保留镜像包"
        fi
    fi

    log_ok "批量恢复结束：成功 ${ok}，跳过 ${skip}，失败 ${fail}"
}

backup_one_named() {
    ensure_dependencies
    require_docker || return 1
    local name="$1"
    if [[ ! -d "$COMPOSE_ROOT/$name" ]]; then
        log_error "项目目录不存在: $COMPOSE_ROOT/$name"
        return 1
    fi
    backup_one_project "$COMPOSE_ROOT/$name"
}

restore_one_named() {
    ensure_dependencies
    require_docker || return 1
    local name="$1" file
    name="${name%.tar.gz}"
    file="$BACKUP_ROOT/${name}.tar.gz"
    if [[ ! -f "$file" ]]; then
        log_error "备份文件不存在: $file"
        return 1
    fi
    restore_one_backup "$file"
    if [[ $DRY_RUN -eq 0 && $DELETE_IMAGE_PKGS -eq 0 ]]; then
        local confirm
        read -r -e -p "$(echo -e "${gl_bai}是否删除已加载的镜像包 *_dd.tar.gz ? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
        [[ "$confirm" =~ ^[Yy]$ ]] && delete_image_packages "$COMPOSE_ROOT/${name}"
    fi
}

migrate_compose_backups() {
    ensure_dependencies
    list_backups

    echo -e ""
    echo -e "${gl_zi}>>> 迁移 Compose 备份${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bufan}备份路径：${gl_bai}$BACKUP_ROOT"

    if [[ ${#COMPOSE_BACKUPS[@]} -eq 0 ]]; then
        log_warn "未找到任何备份包"
        break_end
        return 1
    fi

    local i f
    for i in "${!COMPOSE_BACKUPS[@]}"; do
        f="${COMPOSE_BACKUPS[$i]}"
        printf "%3d. %-40s %s\n" "$((i + 1))" "$(basename "$f")" "$(du -h "$f" 2>/dev/null | cut -f1)"
    done
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_huang}输入 666 迁移全部${gl_bai}"

    local choice target_ip target_user target_port target_dir remote_files=() name
    read -r -e -p "请输入你的选择（序号/文件名）: " choice
    if [[ "$choice" == "666" ]]; then
        remote_files=("${COMPOSE_BACKUPS[@]}")
    else
        name="$(resolve_choice "$choice" "${COMPOSE_BACKUPS[@]}")" || { handle_invalid_input; return 2; }
        [[ "$name" != /* ]] && name="$BACKUP_ROOT/$name"
        [[ -f "$name" ]] && remote_files=("$name") || { log_error "备份不存在: $name"; return 1; }
    fi

    read -r -e -p "$(echo -e "${gl_bai}目标服务器 IP: ")" target_ip
    read -r -e -p "$(echo -e "${gl_bai}目标服务器 SSH 用户名 [默认 ${gl_huang}root${gl_bai}]: ")" target_user
    target_user="${target_user:-root}"
    read -r -e -p "$(echo -e "${gl_bai}目标服务器 SSH 端口 [默认 ${gl_huang}22${gl_bai}]: ")" target_port
    target_port="${target_port:-22}"
    read -r -e -p "$(echo -e "${gl_bai}目标备份目录 [默认 ${gl_huang}/mnt/backup_compose${gl_bai}]: ")" target_dir
    target_dir="${target_dir:-/mnt/backup_compose}"

    local ssh_opts=(-o StrictHostKeyChecking=no -p "$target_port")
    local scp_opts=(-o StrictHostKeyChecking=no -P "$target_port")
    local ssh_cmd=(ssh "${ssh_opts[@]}")
    local scp_cmd=(scp "${scp_opts[@]}")
    local pass=""

    read -r -s -e -p "$(echo -e "${gl_bai}SSH 密码（留空则使用密钥/交互输入）: ${gl_bai}")" pass
    echo ""
    if [[ -n "$pass" ]]; then
        install sshpass
        ssh_cmd=(sshpass -p "$pass" ssh "${ssh_opts[@]}")
        scp_cmd=(sshpass -p "$pass" scp "${scp_opts[@]}")
    fi

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[dry-run] ${ssh_cmd[*]} ${target_user}@${target_ip} mkdir -p $target_dir"
        for f in "${remote_files[@]}"; do
            log_info "[dry-run] ${scp_cmd[*]} $f ${target_user}@${target_ip}:$target_dir/"
        done
        return 0
    fi

    "${ssh_cmd[@]}" "$target_user@$target_ip" "mkdir -p '$target_dir'" || { log_error "无法连接目标服务器"; return 1; }

    local ok=0 fail=0
    for f in "${remote_files[@]}"; do
        log_info "传输: $(basename "$f")"
        if "${scp_cmd[@]}" "$f" "$target_user@$target_ip:$target_dir/"; then
            log_ok "已传输: $(basename "$f")"
            ok=$((ok + 1))
        else
            log_error "传输失败: $(basename "$f")"
            fail=$((fail + 1))
        fi
    done
    log_ok "迁移结束：成功 ${ok}，失败 ${fail}"

    read -r -e -p "$(echo -e "${gl_bai}是否在目标服务器立即恢复? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "${gl_bai}默认根目录：${gl_huang}/vol1/1000/compose${gl_bai}"
        local remote_compose_root
        read -r -e -p "$(echo -e "${gl_bai}请输入项目根目录（回车使用默认）：${gl_bai}")" remote_compose_root
        remote_compose_root="${remote_compose_root:-/vol1/1000/compose}"

        if [[ $DRY_RUN -eq 1 ]]; then
            log_info "[dry-run] 在目标服务器 ${remote_compose_root} 解压并加载镜像、启动 compose"
            return 0
        fi

        log_info "在目标服务器执行恢复，项目根目录: ${remote_compose_root}"

        local remote_script
        remote_script=$(cat <<REMOTE
set -e
mkdir -p "${remote_compose_root}"
cd "${target_dir}"
for p in *.tar.gz; do
    [ -f "\$p" ] || continue
    d="\${p%.tar.gz}"
    tar -xzf "\$p" -C "${remote_compose_root}"
    proj_dir="${remote_compose_root}/\$d"
    for i in "\$proj_dir"/*_dd.tar.gz; do
        [ -f "\$i" ] && docker load -i "\$i"
    done
    if [ -f "\$proj_dir/docker-compose.yml" ]; then
        (cd "\$proj_dir" && docker compose -f docker-compose.yml up -d) || true
    elif [ -f "\$proj_dir/docker-compose.yaml" ]; then
        (cd "\$proj_dir" && docker compose -f docker-compose.yaml up -d) || true
    fi
done
REMOTE
)
        if "${ssh_cmd[@]}" "$target_user@$target_ip" "$remote_script"; then
            log_ok "目标服务器恢复完成"
        else
            log_error "目标服务器恢复失败，请登录目标服务器手动检查"
        fi
    fi
}

manage_compose_backups() {
    while true; do
        clear
        list_backups

        echo -e "${gl_zi}>>> 管理 Compose 备份${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}备份路径：${gl_bai}$BACKUP_ROOT"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        if [[ ${#COMPOSE_BACKUPS[@]} -eq 0 ]]; then
            log_warn "暂无备份"
        else
            local i f
            for i in "${!COMPOSE_BACKUPS[@]}"; do
                f="${COMPOSE_BACKUPS[$i]}"
                printf "%3d. %-40s %s\n" "$((i + 1))" "$(basename "$f")" "$(du -h "$f" 2>/dev/null | cut -f1)"
            done
        fi
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单"
        echo -e "${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入要删除的备份编号（空格分隔多个，${gl_hong}回车${gl_bai}删除全部）: ")" delete_input

        case "$delete_input" in
        0) cancel_return; return ;;
        00 | 000 | 0000) exit_script ;;
        esac

        if [[ ${#COMPOSE_BACKUPS[@]} -eq 0 ]]; then
            handle_invalid_input
            continue
        fi

        if [[ -z "$delete_input" ]]; then
            local confirm
            read -r -e -p "$(echo -e "确认删除 ${gl_huang}${#COMPOSE_BACKUPS[@]}${gl_bai} 个备份? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                local f
                for f in "${COMPOSE_BACKUPS[@]}"; do
                    rm -f "$f"
                done
                log_ok "已删除所有备份"
            else
                log_info "已取消"
            fi
        else
            local num
            for num in $delete_input; do
                if [[ "$num" =~ ^[0-9]+$ ]] && (( num >= 1 && num <= ${#COMPOSE_BACKUPS[@]} )); then
                    local f="${COMPOSE_BACKUPS[$((num - 1))]}"
                    if [[ $DRY_RUN -eq 1 ]]; then
                        log_info "[dry-run] rm -f $f"
                        continue
                    fi
                    local confirm
                    read -r -e -p "$(echo -e "确认删除 ${gl_huang}$(basename "$f")${gl_bai}? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
                    if [[ "$confirm" =~ ^[Yy]$ ]]; then
                        rm -f "$f"
                        log_ok "已删除: $(basename "$f")"
                    else
                        log_info "跳过: $(basename "$f")"
                    fi
                fi
            done
        fi
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
    done
}

backup_menu() {
    while true; do
        clear
        list_subprojects

        echo -e "${gl_zi}>>> 备份 Compose 项目${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}项目路径：${gl_bai}$COMPOSE_ROOT"
        echo -e "${gl_bufan}备份路径：${gl_bai}$BACKUP_ROOT"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        if [[ ${#COMPOSE_PROJECTS[@]} -eq 0 ]]; then
            log_warn "未找到任何子项目目录"
        else
            print_two_columns "${COMPOSE_PROJECTS[@]}"
        fi

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}666. ${gl_bai}备份全部"
        echo -e "${gl_huang}0.   ${gl_bai}返回上一级选单"
        echo -e "${gl_hong}00.  ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "请输入你的选择（序号/项目名）: " choice

        case "$choice" in
        0) cancel_return; return ;;
        00 | 000 | 0000) exit_script ;;
        "")
            cancel_empty
            continue
            ;;
        666)
            backup_all_projects
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        *)
            local name
            if ! name="$(resolve_choice "$choice" "${COMPOSE_PROJECTS[@]}")"; then
                handle_invalid_input
                continue
            fi
            if [[ -d "$COMPOSE_ROOT/$name" ]]; then
                backup_one_named "$name"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
            else
                handle_invalid_input
            fi
            ;;
        esac
    done
}

restore_menu() {
    while true; do
        clear
        list_backups

        echo -e "${gl_zi}>>> 恢复 Compose 备份${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}恢复目录：${gl_bai}$COMPOSE_ROOT"
        echo -e "${gl_bufan}备份路径：${gl_bai}$BACKUP_ROOT"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        if [[ ${#COMPOSE_BACKUPS[@]} -eq 0 ]]; then
            log_warn "未找到任何备份包"
        else
            local i f
            for i in "${!COMPOSE_BACKUPS[@]}"; do
                f="${COMPOSE_BACKUPS[$i]}"
                printf "%3d. %-40s %s\n" "$((i + 1))" "$(basename "$f")" "$(du -h "$f" 2>/dev/null | cut -f1)"
            done
        fi

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}666. ${gl_bai}恢复全部"
        echo -e "${gl_huang}0.   ${gl_bai}返回上一级选单"
        echo -e "${gl_hong}00.  ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "请输入你的选择（序号/文件名）: " choice

        case "$choice" in
        0) cancel_return; return ;;
        00 | 000 | 0000) exit_script ;;
        "")
            cancel_empty
            continue
            ;;
        666)
            restore_all_backups
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        *)
            local name
            if ! name="$(resolve_choice "$choice" "${COMPOSE_BACKUPS[@]}")"; then
                handle_invalid_input
                continue
            fi
            restore_one_named "$(basename "$name")"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        esac
    done
}

main_menu() {
    while true; do
        clear
        list_backups

        echo -e "${gl_zi}>>> Compose 备份/迁移/还原工具${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}备份 Compose 项目"
        echo -e "${gl_bufan}2.  ${gl_bai}迁移 Compose 备份"
        echo -e "${gl_bufan}3.  ${gl_bai}恢复 Compose 备份"
        echo -e "${gl_bufan}4.  ${gl_bai}管理 Compose 备份"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单"
        echo -e "${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "请输入你的选择: " choice
        case $choice in
        1) backup_menu ;;
        2) migrate_compose_backups; break_end ;;
        3) restore_menu ;;
        4) manage_compose_backups ;;
        0) cancel_return "已是主菜单" || continue ;;
        00 | 000 | 0000) exit_script ;;
        *) handle_invalid_input ;;
        esac
    done
}

while [[ $# -gt 0 ]]; do
    case "$1" in
    -c | --compose)
        COMPOSE_ROOT="${2:-}"
        [[ -z "$COMPOSE_ROOT" ]] && { log_error "$1 需要一个目录参数"; exit 1; }
        CLI_MODE=1
        shift 2
        ;;
    -b | --backup)
        BACKUP_ROOT="${2:-}"
        [[ -z "$BACKUP_ROOT" ]] && { log_error "$1 需要一个目录参数"; exit 1; }
        CLI_MODE=1
        shift 2
        ;;
    -r | --restore)
        ACTION="restore"
        ACTION_SET=1
        CLI_MODE=1
        shift
        ;;
    -a | --all)
        BATCH=1
        ACTION_SET=1
        CLI_MODE=1
        shift
        ;;
    -p | --project)
        PROJECT_TARGET="${2:-}"
        [[ -z "$PROJECT_TARGET" ]] && { log_error "$1 需要一个项目名"; exit 1; }
        ACTION_SET=1
        CLI_MODE=1
        shift 2
        ;;
    --dry-run)
        DRY_RUN=1
        CLI_MODE=1
        shift
        ;;
    --delete-pkgs)
        DELETE_IMAGE_PKGS=1
        CLI_MODE=1
        shift
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        log_error "未知参数: $1"
        usage
        exit 1
        ;;
    esac
done

export COMPOSE_ROOT BACKUP_ROOT

if [[ $DRY_RUN -eq 1 ]]; then
    log_warn "已启用 --dry-run 试运行模式，不会实际导出/打包/启动"
fi

if [[ $CLI_MODE -eq 0 || $ACTION_SET -eq 0 ]]; then
    main_menu
else
    if [[ "$ACTION" == "restore" ]]; then
        if [[ $BATCH -eq 1 ]]; then
            restore_all_backups
        elif [[ -n "$PROJECT_TARGET" ]]; then
            restore_one_named "$PROJECT_TARGET"
        else
            restore_menu
        fi
    else
        if [[ $BATCH -eq 1 ]]; then
            backup_all_projects
        elif [[ -n "$PROJECT_TARGET" ]]; then
            backup_one_named "$PROJECT_TARGET"
        else
            backup_menu
        fi
    fi
fi