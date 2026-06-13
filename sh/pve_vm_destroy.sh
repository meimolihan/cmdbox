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

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    read -r -n 1 -s -r -p ""
    echo ""
    clear
}

root_use() {
    clear
    if [ "$EUID" -ne 0 ]; then
        echo -e "\n${gl_zi}>>> ROOT登录检查 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}提示: ${gl_bai}该功能需要root用户才能运行！"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        mobufan
        return 1
    fi
    return 0
}

column_if_available() {
    if command -v column &> /dev/null; then
        column -t -s $'\t'
    else
        cat
    fi
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

exit_script() {
    echo ""
    echo -ne "${gl_hong}感谢使用，再见！${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    clear
    exit 0
}

parse_qm_list() {
    local data
    data=$(qm list 2>/dev/null | tail -n +2)
    if [ -z "$data" ]; then
        return
    fi
    echo "$data" | while read -r line; do
        vmid=$(echo "$line" | awk '{print $1}')
        status=$(echo "$line" | awk '{print $3}')
        mem=$(echo "$line" | awk '{print $4}')
        disk=$(echo "$line" | awk '{print $5}')
        lock=$(echo "$line" | awk '{print $6}')
        name=$(echo "$line" | sed -E "s/^[ ]*${vmid}[ ]+//;s/[ ]+${status}.*$//" | xargs)

        if [[ $status == "running" ]]; then
            status_cn="运行中"
            st_color="$gl_lv"
        else
            status_cn="已停止"
            st_color="$gl_hong"
        fi
        
        echo -e "${gl_huang}VM${reset}\t${gl_lan}${vmid}${reset}\t${gl_bufan}${name}${reset}\t${st_color}${status_cn}${reset}\t${gl_huang}${mem}${reset}\t${gl_zi}${disk}${reset}\t${gl_hui}${lock}${reset}"
    done
}

parse_pct_list() {
    local raw_output
    raw_output=$(pct list 2>/dev/null)
    
    local data
    data=$(echo "$raw_output" | tail -n +2)
    if [ -z "$data" ]; then
        return
    fi
    
    echo "$data" | while read -r line; do
        ctid=$(echo "$line" | awk '{print $1}')
        
        [[ ! "$ctid" =~ ^[0-9]+$ ]] && continue
        
        status=$(echo "$line" | awk '{print $2}')
        if [[ "$status" != "running" && "$status" != "stopped" ]]; then
            status=$(echo "$line" | awk '{print $3}')
        fi
        
        local fields=($line)
        local field_count=${#fields[@]}
        
        if [ $field_count -ge 7 ]; then
            mem="${fields[2]}"
            disk="${fields[4]}"
            lock="${fields[5]}"
            name=$(echo "$line" | awk '{for(i=7;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/ $//')
        elif [ $field_count -eq 4 ]; then
            mem="${fields[2]}"
            disk="-"
            lock="-"
            name=$(echo "$line" | awk '{for(i=4;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/ $//')
        elif [ $field_count -eq 3 ]; then
            mem="-"
            disk="-"
            lock="-"
            name=$(echo "$line" | awk '{for(i=3;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/ $//')
        else
            name=$(echo "$line" | sed -E "s/^[ ]*${ctid}[ ]+//" | sed -E "s/^${status}[ ]+//" | sed -E 's/[ ]+[0-9]+[ ]+[0-9.]+[ ]+[^ ]*[ ]*$//')
        fi
        
        name=$(echo "$name" | xargs)
        [ -z "$name" ] && name="(未命名)"
        
        [[ ! "$mem" =~ ^[0-9]+$ ]] && mem="-"
        [[ ! "$disk" =~ ^[0-9.]+$ ]] && disk="-"
        [ -z "$lock" ] && lock="-"
        
        if [[ $status == "running" ]]; then
            status_cn="运行中"
            st_color="$gl_lv"
        elif [[ $status == "stopped" ]]; then
            status_cn="已停止"
            st_color="$gl_hong"
        else
            status_cn="$status"
            st_color="$gl_huang"
        fi
        
        echo -e "${gl_lan}CT${reset}\t${gl_lan}${ctid}${reset}\t${gl_bufan}${name}${reset}\t${st_color}${status_cn}${reset}\t${gl_huang}${mem}${reset}\t${gl_zi}${disk}${reset}\t${gl_hui}${lock}${reset}"
    done
}

show_all_instance() {
    clear
    if ! command -v qm &> /dev/null; then
        echo -e ""
        echo -e "${gl_huang}>>> PVE 全部实例列表(VM虚拟机 + CT容器)${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        log_error "未检测到Proxmox VE环境，请确保脚本在PVE节点上运行"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return 1
    fi
    echo -e "${gl_huang}>>> PVE 全部实例列表(VM虚拟机 + CT容器)${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    {
        printf "%s%s\t%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "类型" "ID" "名称" "状态" "内存" "磁盘" "锁" "$reset"
        printf "%s%s\t%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "----" "----" "----" "----" "----" "----" "----" "$reset"

        parse_qm_list
        parse_pct_list
    } | column_if_available

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
}

get_all_instance_ids() {
    local ids=()

    if command -v qm &> /dev/null; then
        while IFS= read -r id; do
            [ -n "$id" ] && ids+=("$id")
        done < <(qm list 2>/dev/null | awk 'NR>1 {print $1}')
    fi

    if command -v pct &> /dev/null; then
        while IFS= read -r id; do
            [ -n "$id" ] && ids+=("$id")
        done < <(pct list 2>/dev/null | awk 'NR>1 {print $1}')
    fi

    printf '%s\n' "${ids[@]}" | sort -u | tr '\n' ' '
}

unlock_instance() {
    local VMID="$1"
    local TYPE="$2"
    local lock_files=(
        "/var/lock/qemu-server/lock-${VMID}.conf"
        "/run/lock/qemu-server/lock-${VMID}.conf"
        "/var/lock/pve-manager/lock-${VMID}.conf"
        "/var/lock/lxc/pve-config-${VMID}.lock"
        "/run/lock/lxc/pve-config-${VMID}.lock"
    )
    
    local unlocked=false
    
    for lock_file in "${lock_files[@]}"; do
        if [ -f "$lock_file" ]; then
            if rm -f "$lock_file" 2>/dev/null; then
                log_info "${TYPE} ${VMID}: 已移除锁文件 ${lock_file}"
                unlocked=true
            else
                log_warn "${TYPE} ${VMID}: 无法移除锁文件 ${lock_file}"
            fi
        fi
    done

    if [ "$TYPE" = "QM虚拟机" ]; then
        if qm unlock "$VMID" 2>/dev/null; then
            log_info "${TYPE} ${VMID}: 已通过 qm unlock 解锁"
            unlocked=true
        fi
    elif [ "$TYPE" = "LXC容器" ]; then
        if pct unlock "$VMID" 2>/dev/null; then
            log_info "${TYPE} ${VMID}: 已通过 pct unlock 解锁"
            unlocked=true
        fi
    fi
    
    if [ "$unlocked" = false ]; then
        log_info "${TYPE} ${VMID}: 未发现锁文件或已解锁"
    fi
    
    return 0
}

stop_instance() {
    local VMID="$1"
    local TYPE="$2"
    local status=""
    
    if [ "$TYPE" = "QM虚拟机" ]; then
        status=$(qm status "$VMID" 2>/dev/null | awk '{print $2}')
        if [ "$status" = "running" ]; then
            log_info "${TYPE} ${VMID}: 正在停止 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            if qm stop "$VMID" --timeout 60 &>/dev/null; then
                log_ok "${TYPE} ${VMID}: 已停止"
                sleep 2
                return 0
            else
                log_warn "${TYPE} ${VMID}: 正常停止失败，尝试强制停止 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                if qm stop "$VMID" --skiplock --timeout 10 &>/dev/null; then
                    log_ok "${TYPE} ${VMID}: 已强制停止"
                    return 0
                else
                    log_error "${TYPE} ${VMID}: 停止失败"
                    return 1
                fi
            fi
        elif [ "$status" = "stopped" ]; then
            log_info "${TYPE} ${VMID}: 已处于停止状态"
            return 0
        fi
    elif [ "$TYPE" = "LXC容器" ]; then
        status=$(pct status "$VMID" 2>/dev/null)
        if [[ "$status" == *"running"* ]]; then
            log_info "${TYPE} ${VMID}: 正在停止 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            if pct stop "$VMID" --timeout 60 &>/dev/null; then
                log_ok "${TYPE} ${VMID}: 已停止"
                sleep 2
                return 0
            else
                log_warn "${TYPE} ${VMID}: 正常停止失败，尝试强制停止 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                if pct stop "$VMID" --skiplock --timeout 10 &>/dev/null; then
                    log_ok "${TYPE} ${VMID}: 已强制停止"
                    return 0
                else
                    log_error "${TYPE} ${VMID}: 停止失败"
                    return 1
                fi
            fi
        elif [[ "$status" == *"stopped"* ]]; then
            log_info "${TYPE} ${VMID}: 已处于停止状态"
            return 0
        fi
    fi
    
    return 1
}

cleanup_volumes() {
    local VMID="$1"
    local TYPE="$2"
    local cleaned=false
    
    local volumes=()
    
    if [ "$TYPE" = "QM虚拟机" ]; then
        local disk_list
        disk_list=$(qm config "$VMID" 2>/dev/null | grep -E "^virtio|^scsi|^ide|^sata" | grep -oP '(?<=: )\S+(?=,)' | sort -u)
        while IFS= read -r vol; do
            [ -n "$vol" ] && volumes+=("$vol")
        done <<< "$disk_list"
        
        log_info "${TYPE} ${VMID}: 正在清理磁盘卷 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        for vol in "${volumes[@]}"; do
            if qm cleanup-volumes "$VMID" --volume "$vol" &>/dev/null; then
                log_ok "${TYPE} ${VMID}: 已清理卷 ${vol}"
                cleaned=true
            elif qm move-volume "$VMID" "$vol" &>/dev/null; then
                : # 忽略 move 操作
            fi
        done
        
    elif [ "$TYPE" = "LXC容器" ]; then
        local mp_list
        mp_list=$(pct config "$VMID" 2>/dev/null | grep -E "^mp[0-9]+" | grep -oP '(?<=: )\S+(?=,|$)' | sort -u)
        while IFS= read -r mp; do
            [ -n "$mp" ] && volumes+=("$mp")
        done <<< "$mp_list"
        
        log_info "${TYPE} ${VMID}: 正在清理挂载点 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        for mp in "${volumes[@]}"; do
            if [ -d "$mp" ] && rm -rf "$mp" 2>/dev/null; then
                log_ok "${TYPE} ${VMID}: 已清理挂载点 ${mp}"
                cleaned=true
            fi
        done
    fi
    
    local config_paths=(
        "/etc/pve/qemu-server/${VMID}.conf"
        "/etc/pve/lxc/${VMID}.conf"
        "/etc/pve/nodes/*/qemu-server/${VMID}.conf"
        "/etc/pve/nodes/*/lxc/${VMID}.conf"
    )
    
    for config_path in "${config_paths[@]}"; do
        if compgen -G "$config_path" > /dev/null; then
            if rm -f $config_path 2>/dev/null; then
                log_ok "${TYPE} ${VMID}: 已清理配置文件 ${config_path}"
                cleaned=true
            fi
        fi
    done
    
    if [ "$TYPE" = "QM虚拟机" ]; then
        local snap_dir="/var/lib/vz/images/${VMID}"
        if [ -d "$snap_dir" ]; then
            log_info "${TYPE} ${VMID}: 清理快照目录 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            rm -rf "$snap_dir" 2>/dev/null && log_ok "${TYPE} ${VMID}: 已清理快照目录" || log_warn "${TYPE} ${VMID}: 无法清理快照目录"
        fi
    fi
    
    if [ "$cleaned" = false ]; then
        log_info "${TYPE} ${VMID}: 未发现需要额外清理的卷"
    fi
    
    return 0
}

destroy_instance() {
    local VMID="$1"
    local TYPE=""
    
    # 检测实例类型
    if qm status "$VMID" &>/dev/null 2>&1; then
        TYPE="QM虚拟机"
    elif pct status "$VMID" &>/dev/null 2>&1; then
        TYPE="LXC容器"
    else
        log_error "实例 ${VMID} 不存在"
        return 1
    fi
    
    # 获取实例名称用于显示
    local INSTANCE_NAME=""
    if [ "$TYPE" = "QM虚拟机" ]; then
        INSTANCE_NAME=$(qm config "$VMID" 2>/dev/null | grep "^name:" | awk '{print $2}')
    else
        INSTANCE_NAME=$(pct config "$VMID" 2>/dev/null | grep "^hostname:" | awk '{print $2}')
    fi
    [ -z "$INSTANCE_NAME" ] && INSTANCE_NAME="(未命名)"
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${reset}"
    echo -e "${gl_huang}准备销毁: ${TYPE} ${gl_lv}${VMID}${gl_huang} - ${gl_bufan}${INSTANCE_NAME}${reset}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${reset}"
    
    read -r -e -p "$(echo -e "${gl_bai}确定要销毁该实例吗？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_info "已取消销毁 ${TYPE} ${VMID}"
        return 0
    fi
    
    log_info "${TYPE} ${VMID}: 步骤1/4 - 解除实例锁 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    unlock_instance "$VMID" "$TYPE"
    
    log_info "${TYPE} ${VMID}: 步骤2/4 - 停止实例 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    if ! stop_instance "$VMID" "$TYPE"; then
        log_warn "${TYPE} ${VMID}: 实例无法停止，尝试继续销毁 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    fi
    
    log_info "${TYPE} ${VMID}: 步骤3/4 - 销毁实例 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    local destroy_success=false
    
    if [ "$TYPE" = "QM虚拟机" ]; then
        # 尝试正常销毁
        if qm destroy "$VMID" --skiplock --purge --destroy-unreferenced-disks 2>/dev/null; then
            destroy_success=true
            log_ok "${TYPE} ${VMID}: 实例已销毁（带清理参数）"
        elif qm destroy "$VMID" --skiplock 2>/dev/null; then
            destroy_success=true
            log_ok "${TYPE} ${VMID}: 实例已销毁"
        elif qm destroy "$VMID" 2>/dev/null; then
            destroy_success=true
            log_ok "${TYPE} ${VMID}: 实例已销毁"
        else
            log_error "${TYPE} ${VMID}: 销毁失败"
            return 1
        fi
    elif [ "$TYPE" = "LXC容器" ]; then
        # 尝试正常销毁
        if pct destroy "$VMID" --skiplock --purge 2>/dev/null; then
            destroy_success=true
            log_ok "${TYPE} ${VMID}: 实例已销毁（带清理参数）"
        elif pct destroy "$VMID" --force 2>/dev/null; then
            destroy_success=true
            log_ok "${TYPE} ${VMID}: 实例已销毁（强制）"
        elif pct destroy "$VMID" 2>/dev/null; then
            destroy_success=true
            log_ok "${TYPE} ${VMID}: 实例已销毁"
        else
            log_error "${TYPE} ${VMID}: 销毁失败"
            return 1
        fi
    fi
    
    if [ "$destroy_success" = true ]; then
        log_info "${TYPE} ${VMID}: 步骤4/4 - 清理残留文件和卷 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        cleanup_volumes "$VMID" "$TYPE"
        log_ok "${TYPE} ${VMID}: 完整销毁流程完成"
    fi
    
    return 0
}

destroy_instances() {
    local ids=("$@")
    local success_count=0
    local fail_count=0
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${reset}"
    echo -e "${gl_zi}将销毁 ${#ids[@]} 个实例${reset}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${reset}"
    
    for id in "${ids[@]}"; do
        if destroy_instance "$id"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
        echo ""
    done
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${reset}"
    echo -e "${gl_lv}成功销毁: ${success_count}${reset}  ${gl_hong}失败: ${fail_count}${reset}"
    
    if [ $success_count -gt 0 ]; then
        echo -e "${gl_huang}提示: 如果还有残留存储卷，可以使用以下命令手动清理:${reset}"
        echo -e "${gl_hui}  pvesm free <volume-id>${reset}"
        echo -e "${gl_hui}  pvesm remove <storage>:<volume-id>${reset}"
    fi
}

main() {
    clear
    root_use
    echo -e "${gl_zi}>>> PVE 实例安全销毁工具${reset}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${reset}"
    
    local ids_to_destroy=()
    
    if [ $# -gt 0 ]; then
        ids_to_destroy=("$@")
    else
        clear
        show_all_instance
        echo -e ""
        echo -e "${gl_zi}>>> PVE 实例安全销毁工具${reset}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${reset}"
        echo -e "  ${gl_lv}销毁流程:${gl_bai} 解锁 → 停止 → 销毁 → 清理残留"
        echo -e "  • 输入 ${gl_lv}实例ID${gl_bai}，多个ID用 ${gl_huang}空格${gl_bai} 分隔"
        echo -e "  • 支持格式: ${gl_hui}100 101 102${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${reset}"
        
        local INPUT
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择(${gl_hong}0${gl_bai} 退出):")" INPUT
        
        if [ "$INPUT" = "0" ]; then
            exit_script
        fi
        
        ids_to_destroy=($INPUT)
    fi
    
    if [ ${#ids_to_destroy[@]} -gt 0 ]; then
        destroy_instances "${ids_to_destroy[@]}"
    else
        log_warn "没有需要销毁的实例"
    fi
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${reset}"
    break_end
}

main "$@"