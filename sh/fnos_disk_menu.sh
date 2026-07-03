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
    export gl_qing=$'\033[38;5;14m'
    export reset=$'\033[0m'
}
list_color_init

log_info()  { echo -e "${gl_lan}[信息]${gl_bai} $*"; }
log_ok()    { echo -e "${gl_lv}[成功]${gl_bai} $*"; }
log_warn()  { echo -e "${gl_huang}[警告]${gl_bai} $*"; }
log_error() { echo -e "${gl_hong}[错误]${gl_bai} $*" >&2; }

column_if_available() {
    if command -v column &> /dev/null; then
        column -t -s $'\t'
    else
        cat
    fi
}

list_beautify_disk_simple() {
    {
        printf "%s%s\t%s\t%s\t%s%s\n" "$gl_hui" "设备名" "大小" "文件系统" "挂载点" "$reset"
        printf "%s%s\t%s\t%s\t%s%s\n" "$gl_hui" "--------" "--------" "--------" "--------" "$reset"

        data=$(lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT | grep -v "sr\|loop" | tail -n +2)
        if [ -z "$data" ]; then
            printf "%s%s\t%s\t%s\t%s%s\n" "$gl_huang" "(无数据)" "(无数据)" "(无数据)" "(无数据)" "$reset"
        else
            echo "$data" | sed 's/^[[:space:]]*//' | awk -v name_color="$gl_lan" \
                                                         -v size_color="$gl_lv" \
                                                         -v fstype_color="$gl_huang" \
                                                         -v mount_color="$gl_bufan" \
                                                         -v reset="$reset" '
            {
                printf "%s%s%s\t%s%s%s\t%s%s%s\t%s%s%s\n", 
                    name_color, $1, reset,
                    size_color, $2, reset,
                    fstype_color, $3, reset,
                    mount_color, $4, reset
            }'
        fi
    } | column_if_available
}

list_beautify_disk_full() {
    {
        printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "文件系统" "容量" "已用" "可用" "使用百分比" "挂载点" "$reset"
        printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "--------" "--------" "--------" "--------" "--------" "--------" "$reset"

        data=$(df -hP | grep -v "tmpfs\|udev\|overlay" | tail -n +2)
        if [ -z "$data" ]; then
            printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_huang" "(无数据)" "(无数据)" "(无数据)" "(无数据)" "(无数据)" "(无数据)" "$reset"
        else
            echo "$data" | awk -v fs_color="$gl_lan" \
                                -v size_color="$gl_lv" \
                                -v used_color="$gl_huang" \
                                -v avail_color="$gl_bufan" \
                                -v use_color="$gl_huang" \
                                -v mount_color="$gl_hui" \
                                -v reset="$reset" '
            BEGIN {
                FS="[[:space:]]+";
                OFS="\t"
            }
            {
                filesystem = $1
                size = $2
                used = $3
                avail = $4
                use_percent = $5
                mount = $6
                for (i=7; i<=NF; i++) {
                    mount = mount " " $i
                }

                print fs_color filesystem reset,
                      size_color size reset,
                      used_color used reset,
                      avail_color avail reset,
                      use_color use_percent reset,
                      mount_color mount reset
            }'
        fi
    } | column_if_available
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
    if command -v perl >/dev/null 2>&1; then perl -e "select(undef, undef, undef, $seconds)"; return 0; fi
    if command -v python3 >/dev/null 2>&1; then python3 -c "import time; time.sleep($seconds)"; return 0; fi
    if command -v python >/dev/null 2>&1; then python -c "import time; time.sleep($seconds)"; return 0; fi
    local int_seconds=$(echo "$seconds" | awk '{print int($1+0.999)}')
    sleep "$int_seconds"
}

exit_animation() {
    echo -ne "${gl_lv}即退将出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
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

exit_script() {
    echo ""
    echo -ne "${gl_hong}感谢使用，再见！ ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    clear
    exit 0
}

handle_y_n() {
    echo -ne "\r${gl_hong}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai}) ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.3
    echo -ne "\r${gl_huang}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai}) ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.3
    echo -ne "\r${gl_lv}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai}) ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo ""
    return 2
}

handle_invalid_input() {
    echo -ne "\r\033[K${gl_huang}无效的输入,请重新输入! ${gl_zi} 1 ${gl_huang} 秒后返回"
    sleep_fractional 1
    echo -ne "\r\033[K${gl_lv}无效的输入,请重新输入! ${gl_zi}0${gl_lv} 秒后返回"
    sleep_fractional 0.5
    echo -ne "\r\033[K"
    return 2
}

mount_partition() {
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
    [ "$SELECTION" = "0" ] && { cancel_return "硬盘分区管理"; return 1; }
    
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

    # 检查分区是否已经挂载
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

unmount_partition() {
    echo ""
    echo -e "${gl_zi}>>> 卸载分区"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local DEV_ARR=()
    local MP_ARR=()
    local FS_ARR=()
    local SIZE_ARR=()
    local i=1

    printf "${gl_hui}%-2s    %-14s    %-11s    %-38s    %s${gl_bai}\n" \
      "序号" "设备路径" "容量" "挂载点" "文件系统"
    printf "${gl_hui}%-4s    %-10s    %-8s    %-35s    %s${gl_bai}\n" \
      "----" "----------" "---------" "----------------------------------" "----------"

    while read -r dev mp fs; do
        [[ "$dev" != /dev/sd* ]] && continue
        [[ "$mp" == "/" ]] && continue
        [[ "$mp" =~ ^/vol[0-9]?$ ]] && continue
        [[ -z "$mp" ]] && continue

        size=$(lsblk -dno SIZE "$dev" | tr -d ' ')

        DEV_ARR[$i]="$dev"
        MP_ARR[$i]="$mp"
        FS_ARR[$i]="$fs"
        SIZE_ARR[$i]="$size"

        printf "${gl_huang}%-4s${gl_bai}    %-10s    %-9s    %-35s    %s\n" \
          "${i}." "$dev" "$size" "$mp" "$fs"

        ((i++))
    done < <(mount | grep ^/dev/ | grep -v loop | sort | awk '{print $1,$3,$5}')

    if [ ${#DEV_ARR[@]} -eq 0 ]; then
        log_warn "没有可卸载的分区！"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation
        return
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}请选择卸载序号 (${gl_huang}1-${#DEV_ARR[@]}${gl_bai}) 或 输入设备路径(如/dev/sdd1) (${gl_huang}0${gl_bai}返回): ")" sel

    [ "$sel" = "0" ] && { cancel_return "硬盘分区管理"; return 1; }

    local target_dev=""
    if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -le ${#DEV_ARR[@]} ]; then
        target_dev="${DEV_ARR[$sel]}"
    elif [[ -b "$sel" ]]; then
        target_dev="$sel"
    else
        log_error "输入无效！"
        exit_animation
        return
    fi

    local target_mp=$(mount | grep -w "$target_dev" | awk '{print $3}')
    if [ -z "$target_mp" ]; then
        log_warn "该设备未挂载！"
        exit_animation
        return
    fi

    echo -e ""
    echo -e "${gl_huang}将要卸载：${gl_lv}$target_dev${gl_bai}"
    echo -e "${gl_huang}挂载点：${gl_lv}$target_mp${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -p "$(echo -e "${gl_bai}确认卸载？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
    [[ ! "$confirm" =~ ^[Yy]$ ]] && { log_info "已取消"; exit_animation; return; }

    echo ""
    umount "$target_dev" 2>/dev/null

    if [ $? -eq 0 ]; then
        log_ok "卸载成功：$target_mp"
        rmdir "$target_mp" 2>/dev/null
    else
        log_error "卸载失败！设备忙或权限不足"
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

check_partition() {
    echo -e ""
    echo -e "${gl_zi}>>> 检查分区状态${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    echo -e "${gl_bai}可用的分区列表：${gl_bai}"
    echo -e "${gl_hui}序号 分区名称   大小      文件系统  挂载点  类型${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    local PARTITION_LIST=()
    local PARTITION_NAMES=()
    local i=1
    
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            local cleaned_line=$(echo "$line" | sed 's/^[[:space:]]*[├└─]*[[:space:]]*//')
            local partition_name=$(echo "$cleaned_line" | awk '{print $1}')
            
            if [[ "$cleaned_line" =~ part$ ]] && [[ ! "$partition_name" =~ ^trim_ ]]; then
                echo -e "${gl_huang}  $i.${gl_bai}  $cleaned_line"
                PARTITION_NAMES[$i]="$partition_name"
                ((i++))
            fi
        fi
    done < <(lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,TYPE | tail -n +2)
    
    if [ ${#PARTITION_NAMES[@]} -eq 0 ]; then
        log_warn "未找到可用分区！"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation
        return
    fi
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -p "$(echo -e "${gl_bai}请选择分区序号 (1-${#PARTITION_NAMES[@]}) 或输入分区名称: ")" SELECTION
    
    if [[ "$SELECTION" =~ ^[0-9]+$ ]] && [ "$SELECTION" -ge 1 ] && [ "$SELECTION" -le ${#PARTITION_NAMES[@]} ]; then
        PARTITION="${PARTITION_NAMES[$SELECTION]}"
    elif [[ -n "$SELECTION" ]]; then
        PARTITION="$SELECTION"
    else
        log_error "未输入任何内容！"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation
        return
    fi
    
    # 检查分区是否存在
    if ! lsblk -o NAME | grep -w "$PARTITION" >/dev/null; then
        log_warn "分区不存在！"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation
        return
    fi

    echo -e ""
    echo -e "${gl_huang}>>> 分区 ${gl_lv}/dev/$PARTITION${gl_huang} 的详细信息：${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINT,UUID | grep -w "$PARTITION"

    echo -e ""
    echo -e "${gl_huang}>>> 文件系统信息：${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    df -h "/dev/$PARTITION"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

mount_fnos_partition() {
    echo ""
    echo -e "${gl_zi}>>> 挂载Video分区"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

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

    echo -e "${gl_bai}未挂载分区列表："
    for i in "${!PARTITIONS[@]}"; do
        fstype=$(lsblk -lno FSTYPE "/dev/${PARTITIONS[i]}" 2>/dev/null)
        echo -e "  ${gl_huang}$((i + 1))${gl_bai}. ${PARTITIONS[i]} ($fstype)"
    done

    if [ ${#PARTITIONS[@]} -eq 1 ]; then
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bai}检测到只有一个未挂载分区，将默认挂载 ${gl_huang}${PARTITIONS[0]}${gl_bai}"
        echo -e "${gl_bai}按回车键确认，或按 ${gl_huang}0${gl_bai}返回"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入（直接回车确认或 ${gl_huang}0${gl_bai}返回）: ")" USER_INPUT

        if [[ -z "$USER_INPUT" ]]; then
            PARTITION="${PARTITIONS[0]}"
        elif [[ "$USER_INPUT" == "0" ]]; then
            cancel_return
            return
        else
            PARTITION="$USER_INPUT"
        fi
    else
        # 多个分区时，显示完整提示
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入序号或分区名称（${gl_huang}0${gl_bai}返回，${gl_huang}回车${gl_bai} 跳过）: ")" USER_INPUT

        if [[ -z "$USER_INPUT" ]]; then
            echo -e "${gl_bai}操作已跳过"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            return
        elif [[ "$USER_INPUT" == "0" ]]; then
            cancel_return
            return
        elif [[ "$USER_INPUT" =~ ^[0-9]+$ ]]; then
            INDEX=$((USER_INPUT - 1))
            if [ $INDEX -ge 0 ] && [ $INDEX -lt ${#PARTITIONS[@]} ]; then
                PARTITION="${PARTITIONS[$INDEX]}"
            else
                log_error "序号无效！"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                return
            fi
        else
            PARTITION="$USER_INPUT"
        fi
    fi

    if ! lsblk -o NAME | grep -w "$PARTITION" >/dev/null; then
        log_error "分区不存在！"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation
        return
    fi

    if lsblk -o NAME,MOUNTPOINT | grep -w "$PARTITION" | grep -q "/"; then
        log_warn "分区已经挂载！"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation
        return
    fi

    fstype=$(lsblk -lno FSTYPE "/dev/$PARTITION" 2>/dev/null)
    if [[ ! "$fstype" =~ ^(ext[234]|xfs|btrfs|ntfs|vfat|exfat)$ ]]; then
        log_error "分区文件系统类型不支持挂载！"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation
        return
    fi

    MOUNT_POINT="/vol2/1000/mydisk/Video"
    mkdir -p "$MOUNT_POINT"

    mount "/dev/$PARTITION" "$MOUNT_POINT"

    if [ $? -eq 0 ]; then
        log_ok "分区挂载成功: $MOUNT_POINT"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    else
        log_error "分区挂载失败！"
        rmdir "$MOUNT_POINT" 2>/dev/null
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    fi
    break_end
}

mount_usb_partition() {
    echo ""
    echo -e "${gl_zi}>>> 挂载USB分区"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

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
        break_end
        return
    fi

    echo -e "${gl_bai}未挂载分区列表："
    for i in "${!PARTITIONS[@]}"; do
        fstype=$(lsblk -lno FSTYPE "/dev/${PARTITIONS[i]}" 2>/dev/null)
        echo -e "  ${gl_huang}$((i + 1))${gl_bai}. ${PARTITIONS[i]} ($fstype)"
    done

    if [ ${#PARTITIONS[@]} -eq 1 ]; then
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bai}检测到只有一个未挂载分区，将默认挂载 ${gl_huang}${PARTITIONS[0]}${gl_bai}"
        echo -e "${gl_bai}按回车键确认，或按 ${gl_huang}0${gl_bai}返回"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入（直接回车确认或 ${gl_huang}0${gl_bai}返回）: ")" USER_INPUT

        if [[ -z "$USER_INPUT" ]]; then
            PARTITION="${PARTITIONS[0]}"
        elif [[ "$USER_INPUT" == "0" ]]; then
            cancel_return
            return
        else
            PARTITION="$USER_INPUT"
        fi
    else
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入序号或分区名称（${gl_huang}0${gl_bai}返回，${gl_huang}回车${gl_bai} 跳过）: ")" USER_INPUT

        if [[ -z "$USER_INPUT" ]]; then
            echo -e "${gl_bai}操作已跳过"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            return
        elif [[ "$USER_INPUT" == "0" ]]; then
            cancel_return
            return
        elif [[ "$USER_INPUT" =~ ^[0-9]+$ ]]; then
            INDEX=$((USER_INPUT - 1))
            if [ $INDEX -ge 0 ] && [ $INDEX -lt ${#PARTITIONS[@]} ]; then
                PARTITION="${PARTITIONS[$INDEX]}"
            else
                log_error "序号无效！"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                return
            fi
        else
            PARTITION="$USER_INPUT"
        fi
    fi

    if ! lsblk -o NAME | grep -w "$PARTITION" >/dev/null; then
        log_error "分区不存在！"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation
        return
    fi

    if lsblk -o NAME,MOUNTPOINT | grep -w "$PARTITION" | grep -q "/"; then
        log_warn "分区已经挂载！"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation
        return
    fi

    fstype=$(lsblk -lno FSTYPE "/dev/$PARTITION" 2>/dev/null)
    if [[ ! "$fstype" =~ ^(ext[234]|xfs|btrfs|ntfs|vfat|exfat)$ ]]; then
        log_error "分区文件系统类型不支持挂载！"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation
        return
    fi

    MOUNT_POINT="/vol2/1000/mydisk/USB"
    mkdir -p "$MOUNT_POINT"

    mount "/dev/$PARTITION" "$MOUNT_POINT"

    if [ $? -eq 0 ]; then
        log_ok "分区挂载成功: $MOUNT_POINT"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    else
        log_error "分区挂载失败！"
        rmdir "$MOUNT_POINT" 2>/dev/null
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    fi
    break_end
}

unmount_by_path() {
    echo ""
    echo -e "${gl_zi}>>> 卸载指定目录"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if [ -n "$1" ]; then
        MOUNT_POINT="$1"
    else
        read -r -e -p "$(echo -e "${gl_bai}请输入要卸载的目录路径: ")" MOUNT_POINT
    fi

    if [ ! -d "$MOUNT_POINT" ]; then
        log_warn "目录不存在: $MOUNT_POINT"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation
        return
    fi

    if ! mountpoint -q "$MOUNT_POINT"; then
        log_warn "目录未挂载: $MOUNT_POINT"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation
        return
    fi

    umount "$MOUNT_POINT" 2>/dev/null

    if [ $? -eq 0 ]; then
        log_ok "卸载成功: $MOUNT_POINT"
        rmdir "$MOUNT_POINT" 2>/dev/null
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    else
        log_error "卸载失败: $MOUNT_POINT"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    fi
    break_end
}

list_mounted_partitions() {
    echo ""
    echo -e "${gl_zi}>>> 列出已挂载的分区"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    # df -h | grep -v "tmpfs\|udev\|overlay"
    list_beautify_disk_full
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

format_partition() {
    echo ""
    echo -e "${gl_zi}>>> 格式化分区"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}请输入要格式化的分区名称（例如 ${gl_huang}sda1${gl_bai})(${gl_huang}0${gl_bai}返回): ")" PARTITION
    [ "$PARTITION" = "0" ] && { cancel_return "硬盘分区管理"; return 1; }

    if ! lsblk -o NAME | grep -w "$PARTITION" >/dev/null; then
        log_error "分区不存在！"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation
        return
    fi

    if lsblk -o MOUNTPOINT | grep -w "$PARTITION" >/dev/null; then
        log_warn "分区已经挂载，请先卸载！"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation
        return
    fi

    echo "请选择文件系统类型："
    echo -e "${gl_bufan}1. ${gl_bai}ext4"
    echo -e "${gl_bufan}2. ${gl_bai}xfs"
    echo -e "${gl_bufan}3. ${gl_bai}ntfs"
    echo -e "${gl_bufan}4. ${gl_bai}vfat"
    read -r -e -p "请输入你的选择: " FS_CHOICE

    case $FS_CHOICE in
    1) FS_TYPE="ext4" ;;
    2) FS_TYPE="xfs" ;;
    3) FS_TYPE="ntfs" ;;
    4) FS_TYPE="vfat" ;;
    *)
        log_error "无效的选择！"
        exit_animation
        return
        ;;
    esac

    read -r -e -p "$(echo -e "${gl_bai}确认格式化分区 ${gl_huang}/dev/$PARTITION${gl_bai} 为 ${gl_lv}$FS_TYPE ${gl_bai}吗？ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai})(${gl_huang}0${gl_bai}返回): ")" CONFIRM
    [ "$CONFIRM" = "0" ] && { cancel_return "硬盘分区管理"; return 1; }

    if [ "$CONFIRM" != "y" ]; then
        log_info "操作已取消。"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation
        return
    fi

    echo -e "正在格式化分区 ${gl_huang}/dev/$PARTITION${gl_bai} 为 ${gl_lv}$FS_TYPE ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    mkfs.$FS_TYPE "/dev/$PARTITION"

    if cmd; then
        log_ok "分区格式化成功！"
    else
        log_error "分区格式化失败！"
    fi
    break_end
}

format_disk() {
    echo ""
    echo -e "${gl_zi}>>> 格式化硬盘"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    echo -e "${gl_bai}可用的硬盘列表："
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    lsblk -d -o NAME,SIZE,TYPE,MOUNTPOINT | grep -E "^(NAME|sd|nvme|vd)" | grep -v loop
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    read -r -e -p "$(echo -e "${gl_bai}请输入要格式化的硬盘名称（例如 ${gl_huang}sde${gl_bai}，不含/dev/）(${gl_huang}0${gl_bai}返回): ")" DISK
    [ "$DISK" = "0" ] && { cancel_return "硬盘分区管理"; return 1; }

    if [ ! -b "/dev/$DISK" ]; then
        log_error "硬盘 /dev/$DISK 不存在！"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation
        return
    fi

    DISK_TYPE=$(lsblk -d -o NAME,TYPE "/dev/$DISK" 2>/dev/null | tail -1 | awk '{print $2}')
    if [ "$DISK_TYPE" != "disk" ]; then
        log_error "/dev/$DISK 不是一个硬盘，请输入硬盘名称（如 sde）！"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation
        return
    fi

    echo ""
    echo -e "${gl_bai}硬盘信息："
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    fdisk -l "/dev/$DISK" 2>/dev/null | head -20
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    PARTITIONS=$(lsblk -o NAME,TYPE "/dev/$DISK" 2>/dev/null | grep "part$" | awk '{print $1}')
    MOUNTED_PARTS=""
    MOUNT_POINTS=""

    if [ -n "$PARTITIONS" ]; then
        echo -e "${gl_bai}找到以下分区："
        for part in $PARTITIONS; do
            mountpoint=$(lsblk -o NAME,MOUNTPOINT "/dev/$part" 2>/dev/null | grep "$part" | awk '{print $2}')
            if [ -n "$mountpoint" ] && [ "$mountpoint" != "" ]; then
                MOUNTED_PARTS="$MOUNTED_PARTS $part"
                MOUNT_POINTS="$MOUNT_POINTS $mountpoint"
                echo -e "  ${gl_hong}${part}${gl_bai} - 已挂载到 ${gl_huang}${mountpoint}${gl_bai}"

                # 检查是否有进程占用
                if lsof "$mountpoint" 2>/dev/null | head -5; then
                    echo -e "  ${gl_hong}警告：有进程正在使用此挂载点！${gl_bai}"
                fi
            else
                echo -e "  ${gl_lv}${part}${gl_bai} - 未挂载"
            fi
        done
    else
        echo -e "${gl_bai}该硬盘没有分区。"
    fi

    echo ""
    echo "请选择文件系统类型："
    echo -e "${gl_bufan}1. ${gl_bai}ext4 (Linux推荐)"
    echo -e "${gl_bufan}2. ${gl_bai}xfs (高性能文件系统)"
    echo -e "${gl_bufan}3. ${gl_bai}ntfs (Windows兼容)"
    echo -e "${gl_bufan}4. ${gl_bai}vfat (FAT32，通用格式)"
    echo -e "${gl_bufan}5. ${gl_bai}btrfs (高级文件系统)"
    read -r -e -p "请输入你的选择 [1-5]: " FS_CHOICE

    case $FS_CHOICE in
    1)
        FS_TYPE="ext4"
        FS_DESC="Linux ext4 文件系统"
        ;;
    2)
        FS_TYPE="xfs"
        FS_DESC="XFS 高性能文件系统"
        ;;
    3)
        FS_TYPE="ntfs"
        FS_DESC="NTFS (Windows兼容)"
        ;;
    4)
        FS_TYPE="vfat"
        FS_DESC="FAT32 (通用格式)"
        ;;
    5)
        FS_TYPE="btrfs"
        FS_DESC="Btrfs 高级文件系统"
        ;;
    *)
        log_error "无效的选择！"
        return
        ;;
    esac

    echo ""
    echo "请选择分区表类型："
    echo -e "${gl_bufan}1. ${gl_bai}GPT (推荐，支持2TB以上硬盘)"
    echo -e "${gl_bufan}2. ${gl_bai}MBR (传统BIOS引导)"
    read -r -e -p "请输入你的选择 [1-2]: " TABLE_CHOICE

    case $TABLE_CHOICE in
    1) TABLE_TYPE="gpt" ;;
    2) TABLE_TYPE="msdos" ;;
    *)
        log_error "无效的选择！"
        exit_animation
        return
        ;;
    esac

    echo ""
    echo -e "${gl_hong}警告：此操作将销毁硬盘 /dev/$DISK 上的所有数据！${gl_bai}"
    echo -e "将执行以下操作："
    echo -e "  1. 卸载所有已挂载的分区"
    echo -e "  2. 删除所有现有分区"
    echo -e "  3. 创建新的 $TABLE_TYPE 分区表"
    echo -e "  4. 创建单个分区占用整个硬盘"
    echo -e "  5. 格式化为 $FS_DESC"

    if [ -n "$MOUNTED_PARTS" ]; then
        echo -e "${gl_hong}注意：以下分区将被卸载：$MOUNTED_PARTS${gl_bai}"
    fi

    read -r -e -p "$(echo -e "${gl_bai}确认格式化硬盘 ${gl_huang}/dev/$DISK ${gl_bai}吗？ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" CONFIRM1
    [ "$CONFIRM1" = "0" ] && { cancel_return "上一级选单"; return 1; }      # break 或 continue 或 return ，视上下文而定
    if [ "$CONFIRM1" != "y" ] && [ "$CONFIRM1" != "Y" ]; then
        log_info "操作已取消。"
        exit_animation
        return
    fi

    read -r -e -p "$(echo -e "${gl_huang}再次确认，输入 ${gl_lv}YES${gl_huang} 继续: ${gl_bai}")" CONFIRM2
     [ "$CONFIRM2" = "0" ] && { cancel_return "上一级选单"; return 1; }      # break 或 continue 或 return ，视上下文而定
    if [ "$CONFIRM2" != "YES" ]; then
        log_info "操作已取消。"
        exit_animation
        return
    fi

    if [ -n "$MOUNTED_PARTS" ]; then
        echo ""
        echo -e "${gl_bai}步骤1: 卸载分区 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        for part in $PARTITIONS; do
            mountpoint=$(lsblk -o NAME,MOUNTPOINT "/dev/$part" 2>/dev/null | grep "$part" | awk '{print $2}')
            if [ -n "$mountpoint" ] && [ "$mountpoint" != "" ]; then
                echo -e "卸载分区 ${gl_huang}/dev/$part${gl_bai} (挂载点: $mountpoint)"

                umount "/dev/$part" 2>/dev/null

                if mountpoint -q "$mountpoint" 2>/dev/null; then
                    echo -e "  ${gl_hong}正常卸载失败，尝试强制卸载 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                    umount -f "/dev/$part" 2>/dev/null

                    if mountpoint -q "$mountpoint" 2>/dev/null; then
                        echo -e "  ${gl_hong}强制卸载失败，尝试延迟卸载 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                        umount -l "/dev/$part" 2>/dev/null

                        if mountpoint -q "$mountpoint" 2>/dev/null; then
                            log_error "无法卸载 $mountpoint，可能有进程正在使用"
                            echo -e "  ${gl_bai}尝试查找占用进程 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                            lsof "$mountpoint" 2>/dev/null | head -10
                            read -r -e -p "$(echo -e "${gl_hong}是否终止占用进程？(y/N): ")" KILL_PROC
                            if [ "$KILL_PROC" = "y" ] || [ "$KILL_PROC" = "Y" ]; then
                                fuser -km "$mountpoint" 2>/dev/null
                                sleep_fractional 2
                                umount "/dev/$part" 2>/dev/null
                            else
                                log_error "无法卸载分区，操作终止。"
                                exit_animation
                                return
                            fi
                        fi
                    fi
                fi

                echo -e "  ${gl_lv}✓ 卸载成功${gl_bai}"
            fi
        done
    fi

    echo ""
    echo -e "${gl_bai}步骤2: 创建新分区表 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

    echo -e "正在清除磁盘签名 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    wipefs -a "/dev/$DISK" 2>/dev/null
    if [ $? -ne 0 ]; then
        echo -e "  ${gl_hong}wipefs 失败，尝试使用 dd 清除 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        dd if=/dev/zero of="/dev/$DISK" bs=1M count=100 2>/dev/null
    fi

    echo -e "正在创建 $TABLE_TYPE 分区表 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    if ! parted -s "/dev/$DISK" mklabel $TABLE_TYPE 2>/dev/null; then
        log_error "创建分区表失败！"
        exit_animation
        return
    fi

    echo -e "正在创建分区 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    if [ "$TABLE_TYPE" = "gpt" ]; then
        if ! parted -s "/dev/$DISK" mkpart primary 0% 100% 2>/dev/null; then
            log_error "创建分区失败！"
            exit_animation
            return
        fi
    else
        if ! parted -s "/dev/$DISK" mkpart primary 0% 100% 2>/dev/null; then
            log_error "创建分区失败！"
            exit_animation
            return
        fi
        parted -s "/dev/$DISK" set 1 boot on 2>/dev/null
    fi

    echo -e "更新内核分区表 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    partprobe "/dev/$DISK" 2>/dev/null
    sleep_fractional 3

    if [ -b "/dev/${DISK}1" ]; then
        NEW_PARTITION="${DISK}1"
    elif [ -b "/dev/${DISK}p1" ]; then
        NEW_PARTITION="${DISK}p1"
    else
        echo -e "等待系统识别新分区 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        sleep_fractional 2

        echo 1 >/sys/class/block/"${DISK}"/device/rescan 2>/dev/null

        if [ -b "/dev/${DISK}1" ]; then
            NEW_PARTITION="${DISK}1"
        elif [ -b "/dev/${DISK}p1" ]; then
            NEW_PARTITION="${DISK}p1"
        else
            echo -e "${gl_bai}查找新创建的分区 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            lsblk -o NAME,TYPE "/dev/$DISK" | grep "part"
            read -r -e -p "请输入新分区的名称（如 ${DISK}1）: " NEW_PARTITION
            [ "$NEW_PARTITION" = "0" ] && { cancel_return "上一级选单"; return 1; }

            if [ ! -b "/dev/$NEW_PARTITION" ]; then
                log_error "无法找到新分区，请手动检查！"
                echo -e "${gl_bai}当前硬盘分区状态："
                fdisk -l "/dev/$DISK" 2>/dev/null
                exit_animation    # 即将退出动画
                return
            fi
        fi
    fi

    echo -e "  ${gl_lv}✓ 创建分区: /dev/$NEW_PARTITION${gl_bai}"

    echo ""
    echo -e "${gl_bai}步骤3: 格式化分区 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "正在格式化分区 ${gl_huang}/dev/$NEW_PARTITION${gl_bai} 为 ${gl_lv}$FS_TYPE${gl_bai}"

    FORMAT_SUCCESS=false

    case $FS_TYPE in
    ext4)
        echo -e "创建 ext4 文件系统 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_hong}这可能需要几分钟，请稍候 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

        if timeout 300 mkfs.ext4 -F "/dev/$NEW_PARTITION" 2>&1; then
            FORMAT_SUCCESS=true
        else
            if [ $? -eq 124 ]; then
                log_error "格式化超时！可能需要更多时间或硬盘有问题。"
            else
                log_error "格式化失败！"
            fi
        fi
        ;;

    xfs)
        echo -e "创建 XFS 文件系统 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_hong}这可能需要几分钟，请稍候 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

        if timeout 300 mkfs.xfs -f "/dev/$NEW_PARTITION" 2>&1; then
            FORMAT_SUCCESS=true
        else
            if [ $? -eq 124 ]; then
                log_error "格式化超时！"
            else
                log_error "格式化失败！"
            fi
        fi
        ;;

    ntfs)
        echo -e "创建 NTFS 文件系统 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        if command -v mkfs.ntfs >/dev/null 2>&1; then
            if timeout 300 mkfs.ntfs -f "/dev/$NEW_PARTITION" 2>&1; then
                FORMAT_SUCCESS=true
            else
                if [ $? -eq 124 ]; then
                    log_error "格式化超时！"
                else
                    log_error "格式化失败！"
                fi
            fi
        elif command -v mkntfs >/dev/null 2>&1; then
            if timeout 300 mkntfs -f "/dev/$NEW_PARTITION" 2>&1; then
                FORMAT_SUCCESS=true
            else
                if [ $? -eq 124 ]; then
                    log_error "格式化超时！"
                else
                    log_error "格式化失败！"
                fi
            fi
        else
            log_error "未找到 ntfs 格式化工具，请安装 ntfs-3g 或 ntfsprogs"
            echo -e "${gl_bai}可以运行以下命令安装："
            echo -e "  Ubuntu/Debian: sudo apt-get install ntfs-3g"
            echo -e "  RHEL/CentOS: sudo yum install ntfs-3g"
            exit_animation
            return
        fi
        ;;

    vfat)
        echo -e "创建 FAT32 文件系统 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        if timeout 60 mkfs.vfat -F 32 "/dev/$NEW_PARTITION" 2>&1; then
            FORMAT_SUCCESS=true
        else
            if [ $? -eq 124 ]; then
                log_error "格式化超时！"
            else
                log_error "格式化失败！"
            fi
        fi
        ;;

    btrfs)
        echo -e "创建 Btrfs 文件系统 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_hong}这可能需要几分钟，请稍候 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

        if timeout 300 mkfs.btrfs -f "/dev/$NEW_PARTITION" 2>&1; then
            FORMAT_SUCCESS=true
        else
            if [ $? -eq 124 ]; then
                log_error "格式化超时！"
            else
                log_error "格式化失败！"
            fi
        fi
        ;;
    esac

    if [ "$FORMAT_SUCCESS" = true ]; then
        echo ""
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_lv}✓ 硬盘格式化成功！${gl_bai}"
        echo -e "${gl_bai}硬盘: ${gl_huang}/dev/$DISK${gl_bai}"
        echo -e "${gl_bai}分区: ${gl_huang}/dev/$NEW_PARTITION${gl_bai}"
        echo -e "${gl_bai}文件系统: ${gl_lv}$FS_TYPE${gl_bai}"
        echo -e "${gl_bai}分区表: ${gl_lv}$TABLE_TYPE${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        echo ""
        echo -e "${gl_bai}新分区信息："
        lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT,LABEL,UUID "/dev/$NEW_PARTITION" 2>/dev/null

        echo ""
        echo -e "${gl_bai}文件系统详情："
        if [ "$FS_TYPE" = "ext4" ]; then
            tune2fs -l "/dev/$NEW_PARTITION" 2>/dev/null | grep -E "Filesystem volume name|Filesystem UUID|Block count|Block size|Reserved block count"
        elif [ "$FS_TYPE" = "xfs" ]; then
            xfs_info "/dev/$NEW_PARTITION" 2>/dev/null
        fi

        echo ""
        read -r -e -p "$(echo -e "${gl_bai}是否要挂载新分区？ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" MOUNT_CONFIRM
        if [ "$MOUNT_CONFIRM" = "y" ] || [ "$MOUNT_CONFIRM" = "Y" ]; then
            DEFAULT_MOUNT="/mnt/${NEW_PARTITION}"
            read -r -e -p "$(echo -e "${gl_bai}请输入挂载点路径（默认为 ${gl_huang}${DEFAULT_MOUNT}${gl_bai}）: ")" MOUNT_POINT
            MOUNT_POINT=${MOUNT_POINT:-$DEFAULT_MOUNT}

            if [ -n "$MOUNT_POINT" ]; then
                mkdir -p "$MOUNT_POINT" 2>/dev/null

                if [ $? -ne 0 ]; then
                    echo -e "${gl_hong}无法创建目录 $MOUNT_POINT，尝试使用sudo ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                    sudo mkdir -p "$MOUNT_POINT" 2>/dev/null
                fi

                echo -e "挂载分区到 ${gl_huang}$MOUNT_POINT ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                mount "/dev/$NEW_PARTITION" "$MOUNT_POINT" 2>/dev/null

                if [ $? -eq 0 ]; then
                    echo -e "${gl_lv}✓ 分区已成功挂载到 $MOUNT_POINT${gl_bai}"

                    echo ""
                    echo -e "${gl_bai}磁盘使用情况："
                    df -h "/dev/$NEW_PARTITION" 2>/dev/null

                    # 询问是否添加到fstab
                    read -r -e -p "$(echo -e "${gl_bai}是否添加到 /etc/fstab 实现开机自动挂载？ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" FSTAB_CONFIRM
                    if [ "$FSTAB_CONFIRM" = "y" ] || [ "$FSTAB_CONFIRM" = "Y" ]; then
                        UUID=$(blkid -s UUID -o value "/dev/$NEW_PARTITION" 2>/dev/null)
                        if [ -n "$UUID" ]; then
                            cp /etc/fstab "/etc/fstab.backup.$(date +%Y%m%d%H%M%S)" 2>/dev/null

                            echo "# /dev/$NEW_PARTITION $(date)" | sudo tee -a /etc/fstab >/dev/null
                            echo "UUID=$UUID $MOUNT_POINT $FS_TYPE defaults 0 2" | sudo tee -a /etc/fstab >/dev/null
                            echo -e "${gl_lv}✓ 已添加到 /etc/fstab${gl_bai}"
                        else
                            echo -e "${gl_hong}警告：无法获取分区UUID，已使用设备路径代替${gl_bai}"
                            echo "# /dev/$NEW_PARTITION $(date)" | sudo tee -a /etc/fstab >/dev/null
                            echo "/dev/$NEW_PARTITION $MOUNT_POINT $FS_TYPE defaults 0 2" | sudo tee -a /etc/fstab >/dev/null
                            echo -e "${gl_lv}✓ 已添加到 /etc/fstab${gl_bai}"
                        fi
                    fi
                else
                    log_error "挂载失败，请检查！"
                    echo -e "${gl_bai}尝试使用sudo挂载 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                    sudo mount "/dev/$NEW_PARTITION" "$MOUNT_POINT" 2>/dev/null
                    if [ $? -eq 0 ]; then
                        echo -e "${gl_lv}✓ 分区已成功挂载到 $MOUNT_POINT${gl_bai}"
                    else
                        echo -e "${gl_hong}挂载失败，请手动挂载：${gl_bai}"
                        echo -e "  sudo mount /dev/$NEW_PARTITION $MOUNT_POINT"
                    fi
                fi
            fi
        fi
    else
        log_error "格式化失败！"
        echo -e "${gl_bai}尝试检查硬盘状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        smartctl -H "/dev/$DISK" 2>/dev/null | grep -i "test" || echo "无法检查硬盘健康状况"
    fi
    break_end
}

add_to_fstab() {
    echo ""
    echo -e "${gl_zi}>>> 添加到开机自动挂载"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}请输入分区名称（例如 ${gl_huang}sda1${gl_bai}）(${gl_huang}0 ${gl_bai}返回): ")" PARTITION

    [ "$PARTITION" = "0" ] && { cancel_return "硬盘分区管理"; return 1; }   # break 或 continue 或 return ，视上下文而定

    if [ ! -b "/dev/$PARTITION" ]; then
        log_error "分区 /dev/$PARTITION 不存在！"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation
        return
    fi

    MOUNT_POINT=$(findmnt -n -o TARGET "/dev/$PARTITION" 2>/dev/null)
    if [ -z "$MOUNT_POINT" ]; then
        read -r -e -p "$(echo -e "${gl_bai}分区未挂载，请输入挂载点路径: ")" MOUNT_POINT
        if [ -z "$MOUNT_POINT" ]; then
            log_error "挂载点不能为空！"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            exit_animation
            return
        fi

        mkdir -p "$MOUNT_POINT" 2>/dev/null

        echo -e "正在挂载分区 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        mount "/dev/$PARTITION" "$MOUNT_POINT" 2>/dev/null
        if [ $? -ne 0 ]; then
            log_error "挂载失败，请检查分区状态！"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            exit_animation
            return
        fi
    fi

    UUID=$(blkid -s UUID -o value "/dev/$PARTITION" 2>/dev/null)
    FSTYPE=$(blkid -s TYPE -o value "/dev/$PARTITION" 2>/dev/null | tr -d '"')

    if [ -z "$UUID" ] || [ -z "$FSTYPE" ]; then
        log_error "无法获取分区UUID或文件系统类型！"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation
        return
    fi

    echo -e "${gl_bai}分区信息："
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "设备: ${gl_huang}/dev/$PARTITION${gl_bai}"
    echo -e "UUID: ${gl_lv}$UUID${gl_bai}"
    echo -e "文件系统: ${gl_lv}$FSTYPE${gl_bai}"
    echo -e "挂载点: ${gl_huang}$MOUNT_POINT${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    echo -e ""
    echo -e "${gl_huang}>>> 挂载选项：${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bufan}1. ${gl_bai}默认选项 (defaults)"
    echo -e "${gl_bufan}2. ${gl_bai}读写选项 (rw,defaults)"
    echo -e "${gl_bufan}3. ${gl_bai}用户可读写 (users,rw,defaults)"
    echo -e "${gl_bufan}4. ${gl_bai}自定义选项"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "请输入你的选择: " OPT_CHOICE

    case $OPT_CHOICE in
    1) MOUNT_OPTS="defaults" ;;
    2) MOUNT_OPTS="rw,defaults" ;;
    3) MOUNT_OPTS="users,rw,defaults" ;;
    4)
        read -r -e -p "请输入自定义选项: " MOUNT_OPTS
        if [ -z "$MOUNT_OPTS" ]; then
            MOUNT_OPTS="defaults"
        fi
        ;;
    0) cancel_return "硬盘分区管理" ; return 1 ;;
    *) MOUNT_OPTS="defaults" ;;
    esac

    echo ""
    echo -e "${gl_hong}将要添加到 /etc/fstab 的内容："
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "UUID=$UUID  $MOUNT_POINT  $FSTYPE  $MOUNT_OPTS  0  2"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    read -r -e -p "$(echo -e "${gl_bai}确认添加到 /etc/fstab 吗？ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" CONFIRM
    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        log_info "操作已取消。"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation
        return
    fi

    FSTAB_BACKUP="/etc/fstab.backup.$(date +%Y%m%d%H%M%S)"
    cp /etc/fstab "$FSTAB_BACKUP"
    echo -e "${gl_bai}已备份 /etc/fstab 到 $FSTAB_BACKUP"

    echo "" >>/etc/fstab
    echo "# Added by disk_manager script on $(date)" >>/etc/fstab
    echo "UUID=$UUID  $MOUNT_POINT  $FSTYPE  $MOUNT_OPTS  0  2" >>/etc/fstab

    if [ $? -eq 0 ]; then
        log_ok "已成功添加到 /etc/fstab！"

        echo -e "${gl_bai}测试挂载配置 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        mount -a 2>/dev/null
        if [ $? -eq 0 ]; then
            log_ok "fstab配置测试通过！"
        else
            log_warn "fstab配置测试失败，请检查配置！"
        fi
    else
        log_error "添加失败，请检查权限！"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

disk_edit_fstab() {
    install nano
    root_use
    nano /etc/fstab

    echo -e ""
    echo -e "${gl_bai}检测到 ${gl_huang}/etc/fstab ${gl_bai}文件已被修改。"

    while true; do
        read -r -e -p "$(echo -e "${gl_bai}是否应用更改？ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" choice
        [ "$choice" = "0" ] && { cancel_return "硬盘分区管理"; return; }   # break 或 continue 或 return ，视上下文而定

        case "$choice" in
        y | Y)
            echo -e "正在检查 fstab 语法 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            if sudo mount -a --fake; then
                echo -e "${gl_lv}语法检查通过。${gl_bai}"
                echo -e "${gl_bai}正在应用更改 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                if sudo mount -a; then
                    echo -e "${gl_lv}✓ fstab 更改已成功应用。${gl_bai}"
                    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                    break_end
                else
                    echo -e "${gl_huang}✗ 应用更改时出错。${gl_bai}"
                    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                    break_end
                fi
            else
                echo -e "${gl_hong}✗ fstab 语法检查失败。${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
            fi
            break
            ;;
        n | N)
            echo -e ""
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_lv}已跳过应用更改。${gl_bai}"
            exit_animation
            break
            ;;
        *)
            echo "无效输入，请输入 y 或 n。"
            ;;
        esac
    done
}

fnos_disk_menu() {
    local menu_name="${1:-上一级选单}"
    while true; do
        clear
        echo -e "${gl_zi}>>> 硬盘分区管理工具${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        list_beautify_disk_simple
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}挂载分区             ${gl_bufan}2.  ${gl_bai}卸载分区"
        echo -e "${gl_bufan}3.  ${gl_bai}挂载Video分区        ${gl_bufan}4.  ${gl_bai}卸载Video分区"
        echo -e "${gl_bufan}5.  ${gl_bai}挂载USB分区          ${gl_bufan}6.  ${gl_bai}卸载USB分区"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}7.  ${gl_bai}格式化分区           ${gl_bufan}8.  ${gl_bai}格式化硬盘"
        echo -e "${gl_bufan}9.  ${gl_bai}查看已挂载分区       ${gl_bufan}10. ${gl_bai}检查分区状态"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}11. ${gl_bai}添加到自动挂载       ${gl_bufan}12. ${gl_bai}编辑fstab文件"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单       ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "请输入你的选择: " choice
        case $choice in
        1)  mount_partition ;; 
        2)  unmount_partition ;;
        3)  mount_fnos_partition ;;
        4)  unmount_by_path "/vol2/1000/mydisk/Video" ;;
        5)  mount_usb_partition ;;
        6)  unmount_by_path "/vol2/1000/mydisk/USB" ;;
        7)  format_partition ;;
        8)  format_disk ;;
        9)  list_mounted_partitions ;;
        10) check_partition ;;
        11) add_to_fstab ;;
        12) disk_edit_fstab ;;
        0) cancel_return "已是主菜单" || continue ;;
        00 | 000 | 0000) exit_script ;;
        *) handle_invalid_input ;;
        esac
    done
}

fnos_disk_menu