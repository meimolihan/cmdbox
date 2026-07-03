#!/bin/bash
set -euo pipefail

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

exit_script() {
    echo ""
    echo -ne "${gl_hong}感谢使用，再见！ ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    clear
    exit 0
}

mount_partition() {
    clear
    if [[ $(hostname | tr '[:upper:]' '[:lower:]') != "fnos" ]]; then
            echo -e ""
            echo -e "${gl_zi}>>> FnOS 挂载分区${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            log_error "当前并非 FNOS 系统，脚本仅支持在 FNOS 环境下运行"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            return 1
    fi
    echo -e "${gl_zi}>>> FnOS 挂载分区"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}可用的未挂载分区列表：${gl_bai}"
    echo -e "${gl_hui}序号 分区名称   大小      文件系统  挂载点  类型${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    local PARTITIONS=()
    while IFS= read -r line; do
        fstype=$(lsblk -lno FSTYPE "/dev/$line" 2>/dev/null)
        [[ "$fstype" =~ ^(ext[234]|xfs|btrfs|ntfs|vfat|exfat)$ ]] && PARTITIONS+=("$line")
    done < <(lsblk -lno NAME,TYPE,MOUNTPOINT | awk '$2=="part" && $3=="" {print $1}')

    if [ ${#PARTITIONS[@]} -eq 0 ]; then
        log_error "没有找到未挂载的可用分区！"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return
    fi
    
    local -A part_map
    local idx=1
    for part in "${PARTITIONS[@]}"; do
        part_map[$idx]=$part
        info=$(lsblk -lno NAME,SIZE,FSTYPE,MOUNTPOINT,TYPE "/dev/$part" 2>/dev/null)
        [ -z "$info" ] && continue
        read -r name size fstype mount _ <<< "$info"
        echo -e "${gl_huang}  $idx.${gl_bai}  $name  $size  $fstype  ${mount:-"未挂载"}  part"
        ((idx++))
    done
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}请选择分区序号 (${gl_huang}1${gl_bai}-${gl_lv}${#PARTITIONS[@]}${gl_bai}) 或输入分区名称(${gl_hong}0${gl_bai}退出): ")" SELECTION
    [ "$SELECTION" = "0" ] && exit_script
    
    local PARTITION=""
    if [[ "$SELECTION" =~ ^[0-9]+$ ]] && [ -n "${part_map[$SELECTION]-}" ]; then
        PARTITION="${part_map[$SELECTION]}"
    elif [[ -n "$SELECTION" ]]; then
        if ! lsblk -o NAME | grep -wq "$SELECTION"; then
            log_error "分区 '$SELECTION' 不存在！"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            return
        fi
        fstype=$(lsblk -lno FSTYPE "/dev/$SELECTION" 2>/dev/null)
        if [[ ! "$fstype" =~ ^(ext[234]|xfs|btrfs|ntfs|vfat|exfat)$ ]]; then
            log_error "分区 '$SELECTION' 不是普通文件系统类型或未格式化！"
            echo -e "${gl_bai}文件系统类型: ${fstype:-"未格式化"}"
            echo -e "${gl_bai}可用的文件系统类型: ext2/3/4, xfs, btrfs, ntfs, vfat, exfat"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            return
        fi
        PARTITION="$SELECTION"
    else
        log_error "未输入任何内容！"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return
    fi

    if mount | grep -q "/dev/$PARTITION "; then
        log_warn "分区已经挂载！"
        mount | grep "/dev/$PARTITION"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return
    fi

    echo -e ""
    echo -e "${gl_huang}您选择了分区: ${gl_lv}/dev/$PARTITION${gl_bai}"
    echo -e "${gl_hui}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}分区详细信息:${gl_bai}"
    lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,TYPE,UUID,LABEL | grep -w "$PARTITION"
    echo -e "${gl_hui}————————————————————————————————————————————————${gl_bai}"
    
    read -r -p "$(echo -e "${gl_bai}是否确认挂载该分区? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    log_info "操作已取消"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    exit_animation
    return
    fi
    
    echo ""
    local DEFAULT_MOUNT="/mnt/$PARTITION"
    echo -e "${gl_bai}默认挂载点为: ${gl_huang}${DEFAULT_MOUNT}${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}请输入挂载点路径（直接回车使用默认）: ")" MOUNT_POINT
    [ "$MOUNT_POINT" = "0" ] && return 1

    [ -z "$MOUNT_POINT" ] && MOUNT_POINT="$DEFAULT_MOUNT"
    if [[ ! "$MOUNT_POINT" =~ ^/ ]]; then
        log_error "挂载点必须是绝对路径！"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return
    fi
    if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
        log_error "挂载点已被占用！"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return
    fi

    mkdir -p "$MOUNT_POINT"
    if mount "/dev/$PARTITION" "$MOUNT_POINT"; then
        log_ok "分区挂载成功: $MOUNT_POINT"
        echo -e ""
        echo -e "${gl_bai}挂载信息：${gl_bai}"
        df -h "$MOUNT_POINT"
    else
        log_warn "自动挂载失败，正在尝试使用常见文件系统类型挂载 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        local FS_TYPES=("vfat" "ntfs" "ext4" "ext3" "xfs" "btrfs") mounted=false
        for fs_type in "${FS_TYPES[@]}"; do
            if mount -t "$fs_type" "/dev/$PARTITION" "$MOUNT_POINT" 2>/dev/null; then
                log_ok "分区挂载成功 (使用 $fs_type 文件系统): $MOUNT_POINT"
                mounted=true
                break
            fi
        done
        if [ "$mounted" = false ]; then
            log_error "分区挂载失败！可能的原因："
            log_error "1. 文件系统损坏或不支持"
            log_error "2. 需要特殊挂载参数"
            log_error "3. 权限不足"
            echo ""
            log_warn "建议检查："
            log_warn "1. 使用 'blkid /dev/$PARTITION' 查看文件系统UUID和类型"
            log_warn "2. 使用 'sudo dmesg | tail' 查看详细错误信息"
            log_warn "3. 使用 'file -sL /dev/$PARTITION' 检测文件系统"
            rmdir "$MOUNT_POINT" 2>/dev/null && log_info "已清理挂载点目录"
        else
            echo -e ""
            echo -e "${gl_bai}挂载信息：${gl_bai}"
            df -h "$MOUNT_POINT"
        fi
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

mount_partition
