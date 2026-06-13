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

cancel_return() {
    local menu_name="${1:-上一级选单}"
    echo -ne "${gl_lv}即将返回 ${gl_huang}${menu_name} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
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

list_beautify_docker_system() {
    {
        docker system df | awk -v gray="$gl_hui" -v green="$gl_lv" -v yellow="$gl_huang" \
            -v blue="$gl_lan" -v cyan="$gl_bufan" -v reset="$reset" '
        BEGIN {
            print gray "类型\t总数\t活跃\t大小\t可回收" reset
            print gray "----------\t--------\t--------\t----------\t----------" reset
        }
        NR > 1 {
            type = $1
            total = $2
            active = $3
            size = $4
            reclaim = $5
            if (type == "Local") {
                type = $1 " " $2
                total = $3
                active = $4
                size = $5
                reclaim = $6
            }
            if (type == "Images") color = green
            else if (type == "Containers") color = yellow
            else if (type == "Local Volumes") color = blue
            else if (type == "Build Cache") color = cyan
            else color = reset
            print color type "\t" total "\t" active "\t" size "\t" reclaim reset
        }' | column_if_available
    }
}

handle_invalid_input() {
    echo -ne "\r${gl_hong}无效的输入，请重新输入 ${gl_zi} 2 ${gl_hong}秒后返回 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.3
    echo -ne "\r${gl_huang}无效的输入，请重新输入 ${gl_zi} 1 ${gl_huang}秒后返回 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.3
    echo -e "\r${gl_lv}无效的输入，请重新输入 ${gl_zi} 0 ${gl_lv}秒后返回 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    return 2
}

exit_script() {
    echo ""
    echo -ne "${gl_hong}感谢使用，再见！ ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    clear
    exit 0
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

docker_image_backup_tools() {
    clear
    list_image_backups() {
        local BACKUP_ROOT="/mnt/backup_images"
        mkdir -p "$BACKUP_ROOT"
        chmod 755 "$BACKUP_ROOT"
        echo -e "${gl_huang}>>> 当前镜像备份列表${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        shopt -s nullglob
        local list
        list=("${BACKUP_ROOT}"/images_backup_*)
        shopt -u nullglob
        ((${#list[@]})) && ls -1d "${list[@]}" || echo -e "${gl_huang}暂无镜像备份${gl_bai}"

        for backup_dir in "${list[@]}"; do
            if [[ -f "${backup_dir}/manifest.json" ]]; then
                local img_count=$(jq '.images | length' "${backup_dir}/manifest.json" 2>/dev/null || echo "?")
                local backup_size=$(du -sh "${backup_dir}" 2>/dev/null | cut -f1 || echo "未知")
                echo -e "${gl_bai}备份 ${gl_huang}$(basename "${backup_dir}")${gl_bai}: ${gl_zi}${img_count}${gl_bai} 个镜像, ${gl_lv}${backup_size}${gl_bai}"
            fi
        done
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    }

    backup_docker_images() {
        echo -e ""
        echo -e "${gl_zi}安装依赖中 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        install tar jq gzip sshpass pigz
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        if ! command -v docker &>/dev/null || ! docker info &>/dev/null; then
            echo -e "${gl_hong}错误: Docker 未安装或未运行${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            exit_animation
            return 1
        fi

        local BACKUP_ROOT="/mnt/backup_images"
        local DATE_STR=$(date +%Y%m%d_%H%M%S)
        local BACKUP_DIR="${BACKUP_ROOT}/images_backup_${DATE_STR}"
        mkdir -p "$BACKUP_DIR"

        clear
        echo -e "${gl_zi}>>> 备份 ${gl_huang}Docker${gl_zi} 镜像 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        log_info "正在获取 Docker 镜像列表 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        mapfile -t IMAGES < <(docker images --format "{{.Repository}}:{{.Tag}}" | grep -v "<none>" | grep -v "REPOSITORY:TAG")

        if [[ ${#IMAGES[@]} -eq 0 ]]; then
            log_warn "未找到任何 Docker 镜像"
            exit_animation
            return
        fi

        echo -e "${gl_zi}找到以下 ${gl_huang}${#IMAGES[@]}${gl_zi} 个镜像:${gl_bai}"
        for i in "${!IMAGES[@]}"; do
            echo -e "  ${gl_huang}$((i + 1)).${gl_bai} ${IMAGES[i]}"
        done

        echo -e ""
        echo -e "${gl_huang}>>> 请选择备份方式:${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai} 备份所有镜像 (${gl_huang}${#IMAGES[@]}${gl_bai} 个)"
        echo -e "${gl_bufan}2.  ${gl_bai} 手动选择镜像"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}0.  ${gl_bai} 返回主上一级选单"
        echo -e "${gl_hong}00. ${gl_bai} 退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "请输入你的选择 : " backup_choice

        case "$backup_choice" in
        1)
            images_to_backup=("${IMAGES[@]}")
            ;;
        2)
            images_to_backup=()
            echo -e ""
            echo -e "${gl_huang}>>> 手动选择镜像${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_huang}请输入要备份的镜像编号 (用空格分隔，例如: ${gl_hong}1 ${gl_huang}3 ${gl_lv}5${gl_bai}):"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            read -r -e -p "请输入你的选择: " selected_nums

            for num in $selected_nums; do
                if [[ "$num" =~ ^[0-9]+$ ]] && [[ $num -ge 1 ]] && [[ $num -le ${#IMAGES[@]} ]]; then
                    images_to_backup+=("${IMAGES[$((num - 1))]}")
                fi
            done

            if [[ ${#images_to_backup[@]} -eq 0 ]]; then
                log_warn "未选择任何镜像"
                exit_animation
                return
            fi
            echo -e "${gl_zi}已选择 ${gl_huang}${#images_to_backup[@]}${gl_zi} 个镜像${gl_bai}"

            ;;
        0) cancel_return; return ;;
        00 | 000 | 0000) exit_script ;;
        *) handle_invalid_input ;;
        esac

        local RESTORE_SCRIPT="${BACKUP_DIR}/restore_images.sh"
        cat >"$RESTORE_SCRIPT" <<'EOF'
#!/bin/bash
set -e

gl_bai='\033[0m'
gl_bufan='\033[96m'
gl_lv='\033[32m'
gl_huang='\033[33m'
gl_hong='\033[31m'
gl_zi='\033[35m'

exit_animation() {
    echo -ne "\r${gl_lv}即将退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo ""
}

BACKUP_DIR="$(cd "$(dirname "$0")"; pwd)"
MANIFEST="${BACKUP_DIR}/manifest.json"

echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
echo -e "${gl_zi}>>> 恢复 Docker 镜像 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

if [[ ! -f "$MANIFEST" ]]; then
    echo -e "${gl_hong}错误: 未找到 manifest.json 文件${gl_bai}"
    exit_animation
    exit 1
fi

IMAGE_COUNT=$(jq '.images | length' "$MANIFEST")
echo -e "${gl_bai}发现 ${gl_huang}${IMAGE_COUNT}${gl_bai} 个镜像需要加载${gl_bai}"

read -r -e -p "$(echo -e "${gl_bai}是否要加载所有镜像? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo -e "${gl_huang}已取消${gl_bai}"
    exit_animation
    exit 0
fi

for i in $(seq 0 $((IMAGE_COUNT-1))); do
    IMAGE_NAME=$(jq -r ".images[$i].name" "$MANIFEST")
    IMAGE_FILE=$(jq -r ".images[$i].file" "$MANIFEST")
    IMAGE_PATH="${BACKUP_DIR}/${IMAGE_FILE}"
    
    echo -e "${gl_bai}[$((i+1))/${IMAGE_COUNT}] 加载镜像: ${gl_huang}${IMAGE_NAME}${gl_bai}"
    
    if [[ -f "$IMAGE_PATH" ]]; then
        docker load -i "$IMAGE_PATH"
        echo -e "${gl_lv}✓ 完成${gl_bai}"
    else
        echo -e "${gl_hong}✗ 文件不存在: ${IMAGE_FILE}${gl_bai}"
    fi
done

echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
echo -e "${gl_lv}所有镜像加载完成！${gl_bai}"
echo -e "${gl_bai}使用 ${gl_huang}docker images${gl_bai} 查看已加载的镜像${gl_bai}"
echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
EOF
        chmod +x "$RESTORE_SCRIPT"

        local MANIFEST="${BACKUP_DIR}/manifest.json"
        cat >"$MANIFEST" <<EOF
{
    "backup_date": "$(date -Iseconds)",
    "images": []
}
EOF

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_zi}开始备份 ${gl_huang}${#images_to_backup[@]}${gl_zi} 个镜像 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

        success_count=0
        fail_count=0

        for i in "${!images_to_backup[@]}"; do
            local image="${images_to_backup[i]}"
            local safe_name=$(echo "$image" | sed 's/[\/:]/-/g' | sed 's/^-*//')
            local backup_file="${safe_name}.tar"

            echo -e "${gl_bai}[$((i + 1))/${#images_to_backup[@]}] 备份: ${gl_huang}${image}${gl_bai}"

            if docker save -o "${BACKUP_DIR}/${backup_file}" "$image" 2>/dev/null; then
                if command -v pigz &>/dev/null; then
                    pigz "${BACKUP_DIR}/${backup_file}"
                    backup_file="${backup_file}.gz"
                else
                    gzip "${BACKUP_DIR}/${backup_file}"
                    backup_file="${backup_file}.gz"
                fi

                jq --arg name "$image" --arg file "$backup_file" \
                    '.images += [{"name": $name, "file": $file}]' \
                    "$MANIFEST" >"${MANIFEST}.tmp" && mv "${MANIFEST}.tmp" "$MANIFEST"

                echo -e "${gl_lv}✓ 成功${gl_bai}"
                ((success_count++))
            else
                echo -e "${gl_hong}✗ 失败${gl_bai}"
                ((fail_count++))
            fi
        done

        local total_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1 || echo "未知")

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_lv}备份完成！${gl_bai}"
        echo -e "  ${gl_bai}备份目录: ${gl_huang}${BACKUP_DIR}${gl_bai}"
        echo -e "  ${gl_bai}镜像数量: ${gl_huang}${success_count}/${#images_to_backup[@]}${gl_bai} 成功"
        echo -e "  ${gl_bai}备份大小: ${gl_huang}${total_size}${gl_bai}"
        echo -e "  ${gl_bai}恢复脚本: ${gl_huang}${RESTORE_SCRIPT}${gl_bai}"
        echo -e "  ${gl_bai}使用说明: bash ${RESTORE_SCRIPT}${gl_bai}"

        if [[ $fail_count -gt 0 ]]; then
            echo -e "${gl_hong}警告: ${fail_count} 个镜像备份失败${gl_bai}"
        fi

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
    }

    migrate_docker_images() {
        echo -e ""
        echo -e "${gl_zi}安装依赖中 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        install tar jq gzip sshpass pigz
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        if ! command -v docker &>/dev/null || ! docker info &>/dev/null; then
            echo -e "${gl_hong}错误: Docker 未安装或未运行${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            exit_animation
            return 1
        fi

        clear
        echo -e "${gl_zi}>>> 迁移 ${gl_huang}Docker${gl_zi} 镜像 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        local BACKUP_ROOT="/mnt/backup_images"
        mkdir -pm 755 "$BACKUP_ROOT"

        local latest_backup=""
        shopt -s nullglob
        local backups=("${BACKUP_ROOT}"/images_backup_*)
        shopt -u nullglob

        local latest_backup_name=""
        if ((${#backups[@]} > 0)); then
            latest_backup=$(printf '%s\n' "${backups[@]}" | sort -r | head -n1)
            latest_backup_name=$(basename "$latest_backup")
        fi

        if [[ -n "$latest_backup" ]]; then
            log_info "${gl_bai}最新备份: ${gl_lv}$latest_backup${gl_bai}"
        fi

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        log_info "可用备份列表："
        if ((${#backups[@]} > 0)); then
            for i in "${!backups[@]}"; do
                local backup_dir="${backups[i]}"
                local img_count="?"
                local backup_size="未知"

                if [[ -f "${backup_dir}/manifest.json" ]]; then
                    img_count=$(jq '.images | length' "${backup_dir}/manifest.json" 2>/dev/null || echo "?")
                fi
                backup_size=$(du -sh "${backup_dir}" 2>/dev/null | cut -f1 || echo "未知")

                echo -e "${gl_huang}$((i + 1)).${gl_bai} $(basename "${backup_dir}") (${gl_huang}${img_count}${gl_bai} 个镜像, ${gl_huang}${backup_size}${gl_bai})"
            done
        else
            log_warn "无备份"
            return 1
        fi
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        local BACKUP_DIR=""
        if [[ -n "$latest_backup_name" ]]; then
            read -r -e -p "$(echo -e "${gl_bai}请输入备份目录路径 (回车使用最新备份: ${gl_lv}$latest_backup_name${gl_bai})(${gl_huang}0${gl_bai}返回): ")" BACKUP_DIR

            [[ -z "$BACKUP_DIR" ]] && { cancel_empty "上一级选单"; continue; }
            [[ "$BACKUP_DIR" == "0" ]] && { cancel_return "上一级选单"; continue; }

            if [[ -z "$BACKUP_DIR" ]]; then
                BACKUP_DIR="$latest_backup"
                log_info "${gl_bai}使用默认最新备份: ${gl_lv}$latest_backup${gl_bai}"
            fi
        else
            read -r -e -p "$(echo -e "${gl_bai}请输入备份目录路径: ")" BACKUP_DIR
        fi

        if [[ "$BACKUP_DIR" =~ ^[0-9]+$ ]] && [[ $BACKUP_DIR -ge 1 ]] && [[ $BACKUP_DIR -le ${#backups[@]} ]]; then
            BACKUP_DIR="${backups[$((BACKUP_DIR - 1))]}"
            log_info "选择备份: $BACKUP_DIR"
        fi

        if [[ -n "$BACKUP_DIR" ]] && [[ ! "$BACKUP_DIR" =~ ^/ ]] && [[ ! "$BACKUP_DIR" =~ ^[0-9]+$ ]]; then
            local full_path="$BACKUP_ROOT/$BACKUP_DIR"
            if [[ -d "$full_path" ]]; then
                BACKUP_DIR="$full_path"
            fi
        fi

        [[ ! -d "$BACKUP_DIR" ]] && {
            log_error "备份目录不存在: $BACKUP_DIR"
            exit_animation
            return 1
        }

        if [[ ! -d "$BACKUP_DIR" ]]; then
            log_error "${gl_bai}备份目录不存在: ${gl_hong}$BACKUP_DIR${gl_bai}"
            exit_animation
            return 1
        fi

        local img_count=$(jq '.images | length' "$BACKUP_DIR/manifest.json" 2>/dev/null || echo "0")
        local backup_date=$(jq -r '.backup_date' "$BACKUP_DIR/manifest.json" 2>/dev/null || echo "未知")
        local backup_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1 || echo "未知")

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bai}备份信息:${gl_bai}"
        echo -e "${gl_bai}  目录: ${gl_huang}$BACKUP_DIR${gl_bai}"
        echo -e "${gl_bai}  时间: ${gl_huang}${backup_date}${gl_bai}"
        echo -e "${gl_bai}  镜像: ${gl_huang}${img_count}${gl_bai} 个"
        echo -e "${gl_bai}  大小: ${gl_huang}${backup_size}${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        read -r -e -p "$(echo -e "${gl_bai}目标服务器 IP: ")" TARGET_IP
        [[ -z "$TARGET_IP" ]] && {
            log_error "目标服务器 IP 不能为空"
            exit_animation
            return 1
        }

        read -r -e -p "$(echo -e "${gl_bai}目标服务器 SSH 用户名 [默认 ${gl_huang}root${gl_bai}]: ")" TARGET_USER
        TARGET_USER=${TARGET_USER:-root}

        read -r -e -p "$(echo -e "${gl_bai}目标服务器 SSH 端口 [默认 ${gl_huang}22${gl_bai}]: ")" TARGET_PORT
        TARGET_PORT=${TARGET_PORT:-22}

        read -s -p "$(echo -e "${gl_bai}目标服务器 ${TARGET_USER} 密码: ")" SSHPASS
        echo
        export SSHPASS

        log_info "验证目标服务器连接性 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        if ! sshpass -e ssh -p "$TARGET_PORT" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
            "${TARGET_USER}@${TARGET_IP}" "whoami" &>/dev/null; then
            log_error "无法连接到目标服务器或认证失败"
            exit_animation
            return 1
        fi

        if ! sshpass -e ssh -p "$TARGET_PORT" -o StrictHostKeyChecking=no \
            "${TARGET_USER}@${TARGET_IP}" "docker info &>/dev/null" &>/dev/null; then
            echo -e "${gl_hong}警告: 目标服务器 Docker 可能未安装或未运行${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bai}是否继续? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" continue_choice
            if [[ ! "$continue_choice" =~ ^[Yy]$ ]]; then
                log_info "已取消迁移"
                exit_animation
                return 1
            fi
        fi

        local target_backup_dir="/mnt/backup_images"
        local backup_base_name=$(basename "$BACKUP_DIR")

        log_info "开始传输镜像备份到目标服务器 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        if ! sshpass -e ssh -p "$TARGET_PORT" -o StrictHostKeyChecking=no \
            "${TARGET_USER}@${TARGET_IP}" "mkdir -p '$target_backup_dir'" 2>/dev/null; then
            log_error "${gl_bai}无法在目标服务器创建目录: ${gl_huang}$target_backup_dir${gl_bai}"
            exit_animation
            return 1
        fi

        local total_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1 || echo "未知")
        echo -e "${gl_bai}传输大小: ${gl_huang}${total_size}${gl_bai}"
        echo -e "${gl_bai}目标路径: ${gl_huang}${TARGET_USER}@${TARGET_IP}:${target_backup_dir}/${backup_base_name}${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        if sshpass -e scp -o StrictHostKeyChecking=no -P "$TARGET_PORT" -r \
            "$BACKUP_DIR" "${TARGET_USER}@${TARGET_IP}:${target_backup_dir}/" 2>/dev/null; then
            log_ok "备份传输完成"
        else
            log_info "SCP 传输失败，尝试备用传输方式 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            if sshpass -e ssh -p "$TARGET_PORT" -o StrictHostKeyChecking=no \
                "${TARGET_USER}@${TARGET_IP}" "mkdir -p '${target_backup_dir}/${backup_base_name}'" &&
                tar -czf - -C "$(dirname "$BACKUP_DIR")" "$backup_base_name" |
                sshpass -e ssh -p "$TARGET_PORT" -o StrictHostKeyChecking=no \
                    "${TARGET_USER}@${TARGET_IP}" "tar -xzf - -C '${target_backup_dir}'"; then
                log_ok "备用传输方式完成"
            else
                log_error "所有传输方式均失败"
                exit_animation
                return 1
            fi
        fi

        if sshpass -e ssh -p "$TARGET_PORT" -o StrictHostKeyChecking=no \
            "${TARGET_USER}@${TARGET_IP}" "test -f '${target_backup_dir}/${backup_base_name}/manifest.json'" 2>/dev/null; then

            local remote_img_count=$(sshpass -e ssh -p "$TARGET_PORT" -o StrictHostKeyChecking=no \
                "${TARGET_USER}@${TARGET_IP}" "jq '.images | length' '${target_backup_dir}/${backup_base_name}/manifest.json'" 2>/dev/null || echo "?")

            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            log_ok "迁移完成！"
            echo -e "${gl_bai}镜像备份已传输到目标服务器${gl_bai}"
            echo -e "${gl_bai}目标路径: ${gl_huang}${target_backup_dir}/${backup_base_name}${gl_bai}"
            echo -e "${gl_bai}镜像数量: ${gl_huang}${remote_img_count}${gl_bai} 个"
            echo -e ""
            echo -e "${gl_bai}在目标服务器上执行以下命令加载镜像:${gl_bai}"
            echo -e "${gl_huang}cd '${target_backup_dir}/${backup_base_name}' && ./restore_images.sh${gl_bai}"
            echo -e ""
            echo -e "${gl_bai}或者手动加载:${gl_bai}"
            echo -e "${gl_huang}cd '${target_backup_dir}/${backup_base_name}'${gl_bai}"
            echo -e "${gl_huang}for tar_file in *.tar.gz; do docker load -i \"\$tar_file\"; done${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
        else
            log_error "传输验证失败，备份可能不完整"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            return 1
        fi
    }

    load_docker_images() {
        echo -e ""
        echo -e "${gl_zi}安装依赖中 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        install tar jq gzip pigz
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        if ! command -v docker &>/dev/null || ! docker info &>/dev/null; then
            echo -e "${gl_hong}错误: Docker 未安装或未运行${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"exit_animation
            return 1
        fi

        clear
        echo -e "${gl_zi}>>> 加载 ${gl_huang}Docker${gl_zi} 镜像 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        local BACKUP_ROOT="/mnt/backup_images"
        mkdir -pm 755 "$BACKUP_ROOT"

        local latest_backup=""
        shopt -s nullglob
        local backups=("${BACKUP_ROOT}"/images_backup_*)
        shopt -u nullglob

        local latest_backup_name=""
        if ((${#backups[@]} > 0)); then
            latest_backup=$(printf '%s\n' "${backups[@]}" | sort -r | head -n1)
            latest_backup_name=$(basename "$latest_backup")
        fi

        if [[ -n "$latest_backup" ]]; then
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            log_info "${gl_bai}最新备份: ${gl_lv}$latest_backup${gl_bai}"
        fi

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        log_info "可用备份列表："
        if ((${#backups[@]} > 0)); then
            for i in "${!backups[@]}"; do
                local backup_dir="${backups[i]}"
                local img_count="?"
                local backup_size="未知"

                if [[ -f "${backup_dir}/manifest.json" ]]; then
                    img_count=$(jq '.images | length' "${backup_dir}/manifest.json" 2>/dev/null || echo "?")
                fi
                backup_size=$(du -sh "${backup_dir}" 2>/dev/null | cut -f1 || echo "未知")

                echo -e "${gl_huang}$((i + 1)).${gl_bai} $(basename "${backup_dir}") (${gl_huang}${img_count}${gl_bai} 个镜像, ${gl_huang}${backup_size}${gl_bai})"
            done
        else
            log_warn "无备份"
            return
        fi
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        local BACKUP_DIR=""
        if [[ -n "$latest_backup_name" ]]; then
            read -r -e -p "$(echo -e "${gl_bai}请输入备份目录路径 (回车使用最新备份: ${gl_lv}$latest_backup_name${gl_bai})(${gl_huang}0${gl_bai}返回): ")" BACKUP_DIR

            [[ -z "$BACKUP_DIR" ]] && { cancel_empty "上一级选单"; continue; }
            [[ "$BACKUP_DIR" == "0" ]] && { cancel_return "上一级选单"; continue; }

            if [[ -z "$BACKUP_DIR" ]]; then
                BACKUP_DIR="$latest_backup"
                log_info "使用默认最新备份: $latest_backup"
            fi
        else
            read -r -e -p "$(echo -e "${gl_bai}请输入备份目录路径: ")" BACKUP_DIR
        fi

        if [[ "$BACKUP_DIR" =~ ^[0-9]+$ ]] && [[ $BACKUP_DIR -ge 1 ]] && [[ $BACKUP_DIR -le ${#backups[@]} ]]; then
            BACKUP_DIR="${backups[$((BACKUP_DIR - 1))]}"
            log_info "${gl_bai}选择备份:${gl_huang} $BACKUP_DIR${gl_bai}"
        fi

        if [[ -n "$BACKUP_DIR" ]] && [[ ! "$BACKUP_DIR" =~ ^/ ]] && [[ ! "$BACKUP_DIR" =~ ^[0-9]+$ ]]; then
            local full_path="$BACKUP_ROOT/$BACKUP_DIR"
            if [[ -d "$full_path" ]]; then
                BACKUP_DIR="$full_path"
            fi
        fi

        [[ ! -d "$BACKUP_DIR" ]] && {
            log_error "${gl_bai}备份目录不存在: ${gl_hong}$BACKUP_DIR${gl_bai}"
            exit_animation
            return
        }

        local RESTORE_SCRIPT="$BACKUP_DIR/restore_images.sh"
        if [[ -f "$RESTORE_SCRIPT" ]]; then
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            log_info "找到自动恢复脚本"
            echo -e "${gl_bai}是否使用自动恢复脚本? ${gl_lv}(推荐)${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bai}使用自动脚本? (${gl_lv}Y${gl_bai}/${gl_hong}n${gl_bai}): ")" use_auto

            if [[ -z "$use_auto" || "$use_auto" =~ ^[Yy]$ ]]; then
                log_info "正在执行自动恢复脚本 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                bash "$RESTORE_SCRIPT"
                exit_animation
                return
            fi
        fi

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_zi}手动加载模式 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

        shopt -s nullglob
        local image_files=("$BACKUP_DIR"/*.tar.gz "$BACKUP_DIR"/*.tar)
        shopt -u nullglob

        if [[ ${#image_files[@]} -eq 0 ]]; then
            log_warn "未找到镜像文件 (.tar 或 .tar.gz)"
            exit_animation
            return
        fi

        echo -e "${gl_bai}找到 ${gl_huang}${#image_files[@]}${gl_bai} 个镜像文件:${gl_bai}"
        for i in "${!image_files[@]}"; do
            local file_size=$(du -h "${image_files[i]}" 2>/dev/null | cut -f1 || echo "未知")
            echo -e "${gl_huang}$((i + 1)).${gl_bai} $(basename "${image_files[i]}") (${gl_huang}${file_size}${gl_bai})"
        done

        echo -e ""
        echo -e "${gl_huang}>>> 请选择加载方式:${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai} 加载所有镜像"
        echo -e "${gl_bufan}2.  ${gl_bai} 选择特定镜像"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}0.  ${gl_bai} 返回上一级选单"
        echo -e "${gl_hong}00. ${gl_bai} 退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "请输入你的选择: " load_choice

        case "$load_choice" in
        1)
            files_to_load=("${image_files[@]}")
            ;;
        2)
            files_to_load=()
            echo -e "${gl_bai}请输入要加载的镜像文件编号 (用空格分隔):${gl_bai}"
            read -r -e -p "选择: " selected_nums

            for num in $selected_nums; do
                if [[ "$num" =~ ^[0-9]+$ ]] && [[ $num -ge 1 ]] && [[ $num -le ${#image_files[@]} ]]; then
                    files_to_load+=("${image_files[$((num - 1))]}")
                fi
            done

            if [[ ${#files_to_load[@]} -eq 0 ]]; then
                log_warn "未选择任何镜像文件"
                exit_animation
                return
            fi
            ;;
        0) cancel_return; break ;;
        00 | 000 | 0000) exit_script ;;
        *) handle_invalid_input ;;
        esac

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_zi}开始加载 ${gl_huang}${#files_to_load[@]}${gl_zi} 个镜像 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

        success_count=0
        fail_count=0

        for i in "${!files_to_load[@]}"; do
            local image_file="${files_to_load[i]}"
            local filename=$(basename "$image_file")

            echo -e "${gl_bai}[$((i + 1))/${#files_to_load[@]}] 加载: ${gl_huang}${filename}${gl_bai}"

            if docker load -i "$image_file" 2>/dev/null; then
                echo -e "${gl_lv}✓ 成功${gl_bai}"
                ((success_count++))
            else
                echo -e "${gl_hong}✗ 失败${gl_bai}"
                ((fail_count++))
            fi
        done

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_lv}加载完成！${gl_bai}"
        echo -e "  ${gl_bai}成功: ${gl_huang}${success_count}${gl_bai} 个"
        echo -e "  ${gl_bai}失败: ${gl_huang}${fail_count}${gl_bai} 个"
        echo -e ""
        echo -e "${gl_bai}使用 ${gl_huang}docker images${gl_bai} 查看已加载的镜像${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
    }

    manage_docker_images() {
        if ! command -v docker &>/dev/null || ! docker info &>/dev/null; then
            echo -e "${gl_hong}错误: Docker 未安装或未运行${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            return 1
        fi

        while true; do
            clear
            echo -e "${gl_huang}>>> 当前 Docker 镜像列表${gl_bai}"

            mapfile -t ALL_IMAGES < <(docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}" | tail -n +2)

            if [[ ${#ALL_IMAGES[@]} -eq 0 ]]; then
                echo -e "${gl_huang}没有找到 Docker 镜像${gl_bai}"
            else
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

                for i in "${!ALL_IMAGES[@]}"; do
                    IFS=$'\t' read -r repo tag id size <<<"${ALL_IMAGES[i]}"
                    local full_name="${repo}:${tag}"
                    if [[ "$tag" == "<none>" ]]; then
                        full_name="${repo}"
                    fi

                    local num_width=$((${#ALL_IMAGES[@]} > 99 ? 3 : ${#ALL_IMAGES[@]} > 9 ? 2 : 1))
                    printf "${gl_huang}%-${num_width}d${gl_bai}\t%-40s\t%-12s\t%s\n" \
                        $((i + 1)) \
                        "${full_name:0:40}" \
                        "${id:0:12}" \
                        "$size"
                done
            fi

            local total_images=$(docker images -q | wc -l)
            local total_size=$(docker system df --format "{{.TotalSize}}" 2>/dev/null || echo "未知")

            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

            echo -e ""
            echo -e "${gl_zi}>>> 管理 ${gl_huang}Docker${gl_zi} 镜像${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_bufan}1.  ${gl_bai} 删除指定镜像      ${gl_bufan}2.  ${gl_bai} 清理悬空镜像"
            echo -e "${gl_bufan}3.  ${gl_bai} 清理未使用镜像    ${gl_bufan}4.  ${gl_bai} 导出单个镜像"
            echo -e "${gl_bufan}5.  ${gl_bai} 加载单个镜像      ${gl_bufan}6.  ${gl_bai} 管理导出的镜像"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_huang}0.  ${gl_bai} 返回上一级选单    ${gl_hong}00.  ${gl_bai}退出脚本"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            read -r -e -p "请输入你的选择: " manage_choice

            case "$manage_choice" in
            1)
                clear
                echo -e "${gl_huang}>>> 当前 Docker 镜像列表${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

                mapfile -t ALL_IMAGES < <(docker images --format "{{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}" | grep -v "<none>")

                if [[ ${#ALL_IMAGES[@]} -eq 0 ]]; then
                    echo -e "${gl_huang}没有可删除的镜像${gl_bai}"
                    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                    read -n 1 -s -r -p "$(echo -e "按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}")"
                    echo
                    continue
                fi

                for i in "${!ALL_IMAGES[@]}"; do
                    IFS=$'\t' read -r repo tag id size <<<"${ALL_IMAGES[i]}"
                    full_name="${repo}:${tag}"
                    num_width=$(( ${#ALL_IMAGES[@]} > 9 ? 2 : 1 ))
                    printf "${gl_huang}%-${num_width}d${gl_bai}\t%-40s\t%-12s\t%s\n" $((i+1)) "${full_name:0:40}" "${id:0:12}" "$size"
                done

                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                read -r -e -p "请输入要删除的镜像序号(空格分隔多个)：" delete_nums

                for num in $delete_nums; do
                    if [[ ! $num =~ ^[0-9]+$ ]] || [[ $num -lt 1 || $num -gt ${#ALL_IMAGES[@]} ]]; then
                        continue
                    fi
                    IFS=$'\t' read -r repo tag id size <<<"${ALL_IMAGES[$((num-1))]}"
                    echo -e "${gl_bai}准备删除：${gl_huang}${repo}:${tag}${gl_bai}"

                    containers=$(docker ps -a -q --filter ancestor="$id")
                    if [[ -n $containers ]]; then
                        echo -e "${gl_hong}警告：镜像正在被容器使用，无法删除${gl_bai}"
                        continue
                    fi

                    read -r -e -p "确认删除？(y/N)：" confirm
                    if [[ "$confirm" =~ ^[Yy]$ ]]; then
                        docker rmi "$id" >/dev/null 2>&1
                        if [[ $? -eq 0 ]]; then
                            echo -e "${gl_lv}✓ 删除成功${gl_bai}"
                        else
                            echo -e "${gl_hong}✗ 删除失败${gl_bai}"
                        fi
                    fi
                done

                read -n 1 -s -r -p "$(echo -e "按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}")"
                echo
                ;;
            2)
                echo -e "${gl_bai}正在查找悬空镜像 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                local dangling_images
                dangling_images=$(docker images -f "dangling=true" -q)

                if [[ -z "${dangling_images}" ]]; then
                    echo -e "${gl_huang}没有悬空镜像${gl_bai}"
                    read -n 1 -s -r -p "$(echo -e "按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}")"
                    echo ""
                else
                    echo -e "${gl_bai}找到悬空镜像:${gl_bai}"
                    docker images -f "dangling=true" --format "  {{.ID}}  {{.Repository}}:{{.Tag}}"

                    read -r -e -p "$(echo -e "是否清理所有悬空镜像? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
                    if [[ "${confirm}" =~ ^[Yy]$ ]]; then
                        if echo "${dangling_images}" | xargs -r docker rmi -f 2>/dev/null; then
                            echo -e "${gl_lv}✓ 悬空镜像清理完成${gl_bai}"
                        else
                            echo -e "${gl_hong}✗ 清理失败，请检查权限或Docker状态${gl_bai}"
                        fi
                        read -n 1 -s -r -p "$(echo -e "按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}")"
                        echo ""
                    else
                        echo -e "${gl_huang}已取消清理${gl_bai}"
                        read -n 1 -s -r -p "$(echo -e "按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}")"
                        echo ""
                    fi
                fi
                ;;
            3)
                echo -e ""
                echo -e "${gl_bai}当前镜像空间使用情况:${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                list_beautify_docker_system
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                read -r -e -p "$(echo -e "是否清理所有未使用的镜像? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    docker image prune -a -f
                    echo -e "${gl_lv}✓ 未使用镜像清理完成${gl_bai}"
                fi
                ;;
            4)
                if [[ ${#ALL_IMAGES[@]} -eq 0 ]]; then
                    echo -e "${gl_huang}没有可导出的镜像${gl_bai}"
                    exit_animation    # 即将退出动画
                    continue
                fi

                clear
                echo -e "${gl_huang}>>> 当前 Docker 镜像列表${gl_bai}"

                mapfile -t ALL_IMAGES < <(docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}" | tail -n +2)

                if [[ ${#ALL_IMAGES[@]} -eq 0 ]]; then
                    echo -e "${gl_huang}没有找到 Docker 镜像${gl_bai}"
                else
                    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

                    for i in "${!ALL_IMAGES[@]}"; do
                        IFS=$'\t' read -r repo tag id size <<<"${ALL_IMAGES[i]}"
                        local full_name="${repo}:${tag}"
                        if [[ "$tag" == "<none>" ]]; then
                            full_name="${repo}"
                        fi

                        local num_width=$((${#ALL_IMAGES[@]} > 99 ? 3 : ${#ALL_IMAGES[@]} > 9 ? 2 : 1))
                        printf "${gl_huang}%-${num_width}d${gl_bai}\t%-40s\t%-12s\t%s\n" \
                            $((i + 1)) \
                            "${full_name:0:40}" \
                            "${id:0:12}" \
                            "$size"
                    done
                fi

                local total_images=$(docker images -q | wc -l)
                local total_size=$(docker system df --format "{{.TotalSize}}" 2>/dev/null || echo "未知")
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

                echo -e ""
                echo -e "${gl_zi}>>> 请输入要导出的镜像编号:${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                read -r -e -p "请输入你的选择: " export_num

                if [[ "$export_num" =~ ^[0-9]+$ ]] && [[ $export_num -ge 1 ]] && [[ $export_num -le ${#ALL_IMAGES[@]} ]]; then
                    local image_info="${ALL_IMAGES[$((export_num - 1))]}"
                    local repo=$(echo "$image_info" | grep -oP '^\S+')
                    local tag=$(echo "$image_info" | grep -oP '\S+\s+\K\S+' | head -1)
                    local export_name="${repo}:${tag}"

                    local safe_name=$(echo "$export_name" | sed 's/[^a-zA-Z0-9._-]/-/g')
                    local export_file="/mnt/backup_images/${safe_name}_$(date +%Y%m%d_%H%M%S).tar"

                    echo -e "${gl_bai}正在导出镜像: ${gl_huang}${export_name}${gl_bai}"
                    echo -e "${gl_bai}保存到: ${gl_huang}${export_file}${gl_bai}"

                    mkdir -p "/mnt/backup_images"
                    if docker save -o "$export_file" "$export_name" 2>/dev/null; then
                        echo -e "${gl_lv}✓ 导出成功${gl_bai}"

                        read -r -e -p "$(echo -e "是否压缩? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" compress
                        if [[ "$compress" =~ ^[Yy]$ ]]; then
                            if gzip "$export_file"; then
                                echo -e "${gl_lv}✓ 压缩完成: ${export_file}.gz${gl_bai}"
                            fi
                        fi
                    else
                        echo -e "${gl_hong}✗ 导出失败${gl_bai}"
                        docker save "$export_name" 2>&1 | grep -i error
                    fi
                fi
                ;;
            5)
                mkdir -p "/mnt/backup_images"

                local backup_files=()
                local i=1

                echo -e "${gl_bai}正在扫描备份目录 /mnt/backup_images ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

                while IFS= read -r -d $'\0' file; do
                    backup_files+=("$file")
                done < <(find "/mnt/backup_images" -type f \( -name "*.tar" -o -name "*.tar.gz" -o -name "*.tgz" \) -print0 2>/dev/null | sort -z)

                if [[ ${#backup_files[@]} -eq 0 ]]; then
                    echo -e "${gl_huang}在 /mnt/backup_images 目录中没有找到备份文件${gl_bai}"
                    echo -e "${gl_bai}支持的格式: .tar, .tar.gz, .tgz${gl_bai}"
                    read -n 1 -s -r -p "$(echo -e "按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}")"
                    echo
                    continue
                fi

                clear
                echo -e "${gl_huang}>>> 可加载的备份文件列表${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                echo -e "${gl_lv}编号\t文件大小\t最后修改\t文件名${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

                for i in "${!backup_files[@]}"; do
                    local file="${backup_files[i]}"
                    local file_name=$(basename "$file")
                    local file_size=$(du -h "$file" | cut -f1)
                    local mod_time=$(stat -c "%y" "$file" | cut -d' ' -f1,2 | cut -d'.' -f1)
                    local file_num=$((i + 1))

                    printf "${gl_huang}%3d${gl_bai}\t%-8s\t%s\t${gl_lv}%s${gl_bai}\n" \
                        "$file_num" \
                        "$file_size" \
                        "$mod_time" \
                        "$file_name"
                done

                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                echo -e ""
                echo -e "${gl_zi}>>> 请输入要加载的备份文件编号:${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                read -r -e -p "请输入你的选择: " file_num

                if [[ ! "$file_num" =~ ^[0-9]+$ ]] || [[ $file_num -lt 1 ]] || [[ $file_num -gt ${#backup_files[@]} ]]; then
                    echo -e "${gl_hong}✗ 无效的编号${gl_bai}"
                    continue
                fi

                local selected_file="${backup_files[$((file_num - 1))]}"
                local file_size=$(du -h "$selected_file" | cut -f1)
                local file_name=$(basename "$selected_file")

                echo -e ""
                echo -e "${gl_bai}选择的文件: ${gl_huang}${file_name}${gl_bai}"
                echo -e "${gl_bai}文件大小: ${gl_huang}${file_size}${gl_bai}"
                echo -e "${gl_bai}完整路径: ${gl_huang}${selected_file}${gl_bai}"
                echo -e ""

                read -r -e -p "$(echo -e "确认加载此镜像? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm_load
                if [[ ! "$confirm_load" =~ ^[Yy]$ ]]; then
                    echo -e "${gl_huang}已取消加载${gl_bai}"
                    continue
                fi

                echo -e "${gl_bai}正在加载镜像，请稍候 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

                echo -n "["
                for i in {1..20}; do
                    echo -n " "
                done
                echo -n "]"

                local load_output=$(docker load -i "$selected_file" 2>&1)
                local load_status=$?

                echo -ne "\r\033[K"

                if [[ $load_status -eq 0 ]]; then
                    echo -e "${gl_lv}✓ 镜像加载成功${gl_bai}"

                    local loaded_image=$(echo "$load_output" | grep -oP "Loaded image: \K.*" || echo "")

                    if [[ -n "$loaded_image" ]]; then
                        echo -e "${gl_bai}加载的镜像: ${gl_huang}${loaded_image}${gl_bai}"

                        echo -e ""
                        echo -e "${gl_bai}当前镜像列表中的最新镜像:${gl_bai}"
                        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                        docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}" | head -n 6
                        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                    else
                        echo -e "${gl_bai}加载的输出: ${gl_huang}${load_output}${gl_bai}"
                    fi

                    echo -e ""
                    read -r -e -p "$(echo -e "是否删除备份文件? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" delete_file
                    if [[ "$delete_file" =~ ^[Yy]$ ]]; then
                        if rm -f "$selected_file"; then
                            echo -e "${gl_lv}✓ 备份文件已删除${gl_bai}"
                        else
                            echo -e "${gl_hong}✗ 文件删除失败${gl_bai}"
                        fi
                    fi
                else
                    echo -e "${gl_hong}✗ 镜像加载失败${gl_bai}"
                    echo -e "${gl_bai}错误信息:${gl_bai}"
                    echo -e "${gl_huang}${load_output}${gl_bai}"
                    echo -e ""
                    echo -e "${gl_huang}可能的原因:${gl_bai}"
                    echo -e "  1. 文件损坏或不完整"
                    echo -e "  2. 磁盘空间不足"
                    echo -e "  3. Docker 服务异常"
                    echo -e "  4. 权限不足"
                    echo -e "  5. 镜像格式不正确"
                fi
                read -n 1 -s -r -p "$(echo -e "按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}")"
                echo
                ;;
            6)
                cd "/mnt/backup_images" && bash <(curl -sL gitee.com/meimolihan/cmdbox/raw/master/sh/linux_file_menu.sh)
                ;;
            0) cancel_return; break ;;
            00 | 000 | 0000) exit_script ;;
            *) handle_invalid_input ;;
            esac
            echo
        done
    }

    delete_image_backup() {
        local BACKUP_ROOT="/mnt/backup_images"

        echo -e ""
        echo -e "${gl_zi}>>> 删除镜像备份 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        shopt -s nullglob
        local backups=("${BACKUP_ROOT}"/images_backup_*)
        shopt -u nullglob

        if [[ ${#backups[@]} -eq 0 ]]; then
            echo -e "${gl_huang}没有找到镜像备份${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            exit_animation
            return
        fi

        echo -e "${gl_bai}可用备份列表:${gl_bai}"
        for i in "${!backups[@]}"; do
            local backup_dir="${backups[i]}"
            local img_count="?"
            local backup_size="未知"

            if [[ -f "${backup_dir}/manifest.json" ]]; then
                img_count=$(jq '.images | length' "${backup_dir}/manifest.json" 2>/dev/null || echo "?")
            fi
            backup_size=$(du -sh "${backup_dir}" 2>/dev/null | cut -f1 || echo "未知")

            echo -e "${gl_huang}$((i + 1)).${gl_bai} $(basename "${backup_dir}") (${gl_huang}${img_count}${gl_bai} 个镜像, ${gl_huang}${backup_size}${gl_bai})"
        done
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        read -r -e -p "$(echo -e "${gl_bai}请输入要删除的备份编号 (用空格分隔多个)，${gl_hong}回车${gl_bai}删除全部: ")" delete_input

        if [[ -z "$delete_input" ]]; then
            read -r -e -p "$(echo -e "确认删除 ${gl_huang}${#backups[@]}${gl_bai} 个备份? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm

            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                for backup in "${backups[@]}"; do
                    rm -rf "$backup"
                done
                echo -e "${gl_lv}✓ 已删除所有备份${gl_bai}"
            else
                echo -e "${gl_huang}已取消${gl_bai}"
            fi
        else
            for num in $delete_input; do
                if [[ "$num" =~ ^[0-9]+$ ]] && [[ $num -ge 1 ]] && [[ $num -le ${#backups[@]} ]]; then
                    local backup_dir="${backups[$((num - 1))]}"
                    read -r -e -p "$(echo -e "确认删除 ${gl_huang}$(basename "${backup_dir}")${gl_bai}? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm

                    if [[ "$confirm" =~ ^[Yy]$ ]]; then
                        rm -rf "$backup_dir"
                        echo -e "${gl_lv}✓ 已删除: $(basename "${backup_dir}")${gl_bai}"
                    else
                        echo -e "${gl_huang}跳过: $(basename "${backup_dir}")${gl_bai}"
                    fi
                fi
            done
        fi

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    }

    main_menu() {
        while true; do
            clear
            list_image_backups
            echo -e ""
            echo -e "${gl_zi}>>> Docker 镜像备份/迁移/还原工具${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_bufan}1.  ${gl_bai}备份 Docker 镜像"
            echo -e "${gl_bufan}2.  ${gl_bai}迁移 Docker 镜像"
            echo -e "${gl_bufan}3.  ${gl_bai}加载 Docker 镜像"
            echo -e "${gl_bufan}4.  ${gl_bai}管理 Docker 镜像"
            echo -e "${gl_bufan}5.  ${gl_bai}删除 Docker 镜像备份"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单"
            echo -e "${gl_hong}00. ${gl_bai}退出脚本"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            read -r -e -p "请输入你的选择: " choice
            case $choice in
            1) backup_docker_images ;;
            2) migrate_docker_images ;;
            3) load_docker_images ;;
            4) manage_docker_images ;;
            5) delete_image_backup ;;
            0) cancel_return "已是主菜单" || continue ;;
            00 | 000 | 0000) exit_script ;;
            *) handle_invalid_input ;;
            esac
        done
    }

    main_menu
}


docker_image_backup_tools