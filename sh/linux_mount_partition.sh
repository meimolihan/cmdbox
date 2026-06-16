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

handle_invalid_input() {
    echo -ne "\r\033[K${gl_huang}无效的输入,请重新输入! ${gl_zi} 1 ${gl_huang} 秒后返回"
    sleep_fractional 1
    echo -ne "\r\033[K${gl_lv}无效的输入,请重新输入! ${gl_zi}0${gl_lv} 秒后返回"
    sleep_fractional 0.5
    echo -ne "\r\033[K"
    return 2
}

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
    if command -v python3 >/dev/null 2>&1; then python3 -c "import time; time.sleep($seconds)"; return 0; fi
    local int_seconds=$(echo "$seconds" | awk '{print int($1+0.999)}')
    sleep "$int_seconds"
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

exit_animation() {
    echo -ne "\r${gl_lv}即将退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo ""
}

linux_mount_partition() {
    echo ""
    echo -e "${gl_zi}>>> 挂载分区"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    echo -e "${gl_bai}可用的未挂载分区列表：${gl_bai}"
    echo -e "${gl_hui}序号 分区名称   大小      文件系统  挂载点  类型${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    local PARTITION_NAMES=()
    local PARTITION_SIZES=()
    local PARTITION_FSTYPES=()
    local PARTITION_TYPES=()
    local PARTITION_MOUNTS=()
    local i=1
    
    PARTITIONS=()
    while IFS= read -r line; do
        fstype=$(lsblk -lno FSTYPE "/dev/$line" 2>/dev/null)

        if [[ "$fstype" =~ ^(ext[234]|xfs|btrfs|ntfs|vfat|exfat)$ ]]; then
            PARTITIONS+=("$line")
        fi
    done < <(lsblk -lno NAME,TYPE,MOUNTPOINT | awk '$2=="part" && $3=="" {print $1}')

    if [ ${#PARTITIONS[@]} -eq 0 ]; then
        log_error "没有找到未挂载的可用分区！"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation
        return
    fi
    
    for idx in "${!PARTITIONS[@]}"; do
        PARTITION_NAME="${PARTITIONS[$idx]}"
        PARTITION_INFO=$(lsblk -lno NAME,SIZE,FSTYPE,MOUNTPOINT,TYPE "/dev/$PARTITION_NAME" 2>/dev/null)
        if [ -n "$PARTITION_INFO" ]; then
            NAME=$(echo "$PARTITION_INFO" | awk '{print $1}')
            SIZE=$(echo "$PARTITION_INFO" | awk '{print $2}')
            FSTYPE=$(echo "$PARTITION_INFO" | awk '{print $3}')
            MOUNTPOINT=$(echo "$PARTITION_INFO" | awk '{print $4}')
            TYPE=$(echo "$PARTITION_INFO" | awk '{print $5}')
            
            echo -e "${gl_huang}  $((idx + 1)).${gl_bai}  $NAME  $SIZE  $FSTYPE  ${MOUNTPOINT:-"未挂载"}  $TYPE"
            
            PARTITION_NAMES[$((idx + 1))]="$NAME"
            PARTITION_SIZES[$((idx + 1))]="$SIZE"
            PARTITION_FSTYPES[$((idx + 1))]="$FSTYPE"
            PARTITION_TYPES[$((idx + 1))]="$TYPE"
            PARTITION_MOUNTS[$((idx + 1))]="$MOUNTPOINT"
        fi
    done
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}请选择分区序号 (${gl_huang}1${gl_bai}-${gl_lv}${#PARTITION_NAMES[@]}${gl_bai}) 或输入分区名称(${gl_huang}0${gl_bai}返回): ")" SELECTION
    [ "$SELECTION" = "0" ] && { exit_script; }
    
    if [[ "$SELECTION" =~ ^[0-9]+$ ]] && [ "$SELECTION" -ge 1 ] && [ "$SELECTION" -le ${#PARTITIONS[@]} ]; then
        PARTITION="${PARTITION_NAMES[$SELECTION]}"
        PARTITION_SIZE="${PARTITION_SIZES[$SELECTION]}"
        PARTITION_FSTYPE="${PARTITION_FSTYPES[$SELECTION]}"
    elif [[ -n "$SELECTION" ]]; then
        FOUND=0
        for idx in "${!PARTITIONS[@]}"; do
            if [[ "${PARTITIONS[$idx]}" == "$SELECTION" ]]; then
                PARTITION="$SELECTION"
                PARTITION_INFO=$(lsblk -lno NAME,SIZE,FSTYPE,MOUNTPOINT,TYPE "/dev/$PARTITION" 2>/dev/null)
                if [ -n "$PARTITION_INFO" ]; then
                    PARTITION_SIZE=$(echo "$PARTITION_INFO" | awk '{print $2}')
                    PARTITION_FSTYPE=$(echo "$PARTITION_INFO" | awk '{print $3}')
                fi
                FOUND=1
                break
            fi
        done
        
        if [ $FOUND -eq 0 ]; then
            if lsblk -o NAME | grep -w "$SELECTION" >/dev/null; then
                fstype=$(lsblk -lno FSTYPE "/dev/$SELECTION" 2>/dev/null)
                if [[ ! "$fstype" =~ ^(ext[234]|xfs|btrfs|ntfs|vfat|exfat)$ ]]; then
                    log_error "分区 '$SELECTION' 不是普通文件系统类型或未格式化！"
                    echo -e "${gl_bai}文件系统类型: ${fstype:-"未格式化"}"
                    echo -e "${gl_bai}可用的文件系统类型: ext2/3/4, xfs, btrfs, ntfs, vfat, exfat"
                    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                    return
                fi
                PARTITION="$SELECTION"
                PARTITION_INFO=$(lsblk -lno NAME,SIZE,FSTYPE,MOUNTPOINT,TYPE "/dev/$PARTITION" 2>/dev/null)
                if [ -n "$PARTITION_INFO" ]; then
                    PARTITION_SIZE=$(echo "$PARTITION_INFO" | awk '{print $2}')
                    PARTITION_FSTYPE=$(echo "$PARTITION_INFO" | awk '{print $3}')
                fi
            else
                log_error "分区 '$SELECTION' 不存在！"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                exit_animation
                return
            fi
        fi
    else
        log_error "未输入任何内容！"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation
        return
    fi

    if mount | grep -q "/dev/$PARTITION "; then
        log_warn "分区已经挂载！"
        echo -e "${gl_bai}当前挂载信息：${gl_bai}"
        mount | grep "/dev/$PARTITION"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation
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

    DEFAULT_MOUNT="/mnt/$PARTITION"
    echo -e "${gl_bai}默认挂载点为: ${gl_huang}${DEFAULT_MOUNT}${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}请输入挂载点路径（直接回车使用默认）: ")" MOUNT_POINT
    [ "$MOUNT_POINT" = "0" ] && { cancel_return "上一级选单"; return 1; }

    if [ -z "$MOUNT_POINT" ]; then
        MOUNT_POINT="$DEFAULT_MOUNT"
    else
        if [[ ! "$MOUNT_POINT" =~ ^/ ]]; then
            log_error "挂载点必须是绝对路径！"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            exit_animation
            return
        fi

        if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
            log_error "挂载点已被占用！"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            exit_animation
            return
        fi
    fi

    mkdir -p "$MOUNT_POINT"

    mount "/dev/$PARTITION" "$MOUNT_POINT"

    if [ $? -eq 0 ]; then
        log_ok "分区挂载成功: $MOUNT_POINT"
        echo -e ""
        echo -e "${gl_bai}挂载信息：${gl_bai}"
        df -h "$MOUNT_POINT"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    else
        log_warn "自动挂载失败，正在尝试使用常见文件系统类型挂载 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        
        local FS_TYPES=("vfat" "ntfs" "ext4" "ext3" "xfs" "btrfs")
        local mounted=false
        
        for fs_type in "${FS_TYPES[@]}"; do
            mount -t "$fs_type" "/dev/$PARTITION" "$MOUNT_POINT" 2>/dev/null
            if [ $? -eq 0 ]; then
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
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    fi
    break_end
}

linux_mount_partition