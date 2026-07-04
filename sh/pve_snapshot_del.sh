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

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
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

exit_animation() {
    echo -ne "${gl_lv}即将退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo ""
    clear
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

list_vms_with_snapshots() {
    local vms=$(qm list 2>/dev/null | awk 'NR>1 {print $1}' | sort -n)
    local result=()
    for vmid in $vms; do
        local snap_count=$(qm listsnapshot "$vmid" 2>/dev/null | grep -vc "current\|You are here")
        if [ "$snap_count" -gt 0 ]; then
            local vm_name=$(qm config "$vmid" 2>/dev/null | grep "^name:" | awk '{print $2}')
            result+=("$vmid:$vm_name")
        fi
    done
    printf '%s\n' "${result[@]}"
}

list_cts_with_snapshots() {
    local cts=$(pct list 2>/dev/null | awk 'NR>1 {print $1}' | sort -n)
    local result=()
    for ctid in $cts; do
        local snap_count=$(pct listsnapshot "$ctid" 2>/dev/null | grep -vc "current\|You are here")
        if [ "$snap_count" -gt 0 ]; then
            local ct_name=$(pct config "$ctid" 2>/dev/null | grep "^hostname:" | awk '{print $2}')
            result+=("$ctid:$ct_name")
        fi
    done
    printf '%s\n' "${result[@]}"
}

get_snapshot_names() {
    local type=$1
    local id=$2
    if [ "$type" = "vm" ]; then
        qm listsnapshot "$id" 2>/dev/null | awk 'NR>1 && !/current/ {print $2}'
    else
        pct listsnapshot "$id" 2>/dev/null | awk 'NR>1 && !/current/ {print $2}'
    fi
}

get_snapshot_description() {
    local type=$1
    local id=$2
    local snapname=$3
    if [ "$type" = "vm" ]; then
        qm listsnapshot "$id" 2>/dev/null | awk -v snap="$snapname" '$2 == snap {desc=""; for(i=4;i<=NF;i++){if($i!="no-description"&&$i!="current"){desc=(desc?desc" ":"")$i}}; if(desc) print desc}'
    else
        pct listsnapshot "$id" 2>/dev/null | awk -v snap="$snapname" '$2 == snap {desc=""; for(i=4;i<=NF;i++){if($i!="no-description"&&$i!="current"){desc=(desc?desc" ":"")$i}}; if(desc) print desc}'
    fi
}

is_current_snapshot() {
    local type=$1
    local id=$2
    local snapname=$3
    if [ "$type" = "vm" ]; then
        qm listsnapshot "$id" 2>/dev/null | awk -v snap="$snapname" '$2 == snap {for(i=1;i<=NF;i++) if($i=="current") print "yes"}'
    else
        pct listsnapshot "$id" 2>/dev/null | awk -v snap="$snapname" '$2 == snap {for(i=1;i<=NF;i++) if($i=="current") print "yes"}'
    fi
}

delete_vm_snapshot() {
    local vmid=$1
    local snapname=$2
    
    log_info "正在删除虚拟机 ${gl_bufan}$vmid${gl_bai} 的快照 ${gl_bufan}$snapname${gl_bai}"
    
    if qm delsnapshot "$vmid" "$snapname" 2>&1; then
        log_ok "快照 $snapname 已删除"
        return 0
    else
        log_error "快照 $snapname 删除失败"
        return 1
    fi
}

delete_ct_snapshot() {
    local ctid=$1
    local snapname=$2
    
    log_info "正在删除容器 ${gl_bufan}$ctid${gl_bai} 的快照 ${gl_bufan}$snapname${gl_bai}"
    
    if pct delsnapshot "$ctid" "$snapname" 2>&1; then
        log_ok "快照 $snapname 已删除"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        return 0
    else
        log_error "快照 $snapname 删除失败"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        return 1
    fi
}

handle_invalid_input() {
    echo -ne "\r\033[K${gl_huang}无效的输入,请重新输入! ${gl_zi} 1 ${gl_huang} 秒后返回"
    sleep_fractional 1
    echo -ne "\r\033[K${gl_lv}无效的输入,请重新输入! ${gl_zi}0${gl_lv} 秒后返回"
    sleep_fractional 0.5
    echo -ne "\r\033[K"
    return 2
}

main() {
    while true; do
        clear
        root_use
        
        if ! command -v qm &> /dev/null; then
            echo -e ""
            echo -e "${gl_huang}>>> PVE 删除虚拟机/容器快照 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            log_error "未检测到Proxmox VE环境，请确保脚本在PVE节点上运行"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            return 1
        fi
        
        echo -e ""
        echo -e "${gl_zi}>>> PVE 删除虚拟机/容器快照 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        local instance_list=()
        local index=1
        
        local vm_list=$(list_vms_with_snapshots)
        if [ -n "$vm_list" ]; then
            while IFS=: read -r vmid vmname; do
                instance_list+=("vm:$vmid")
                if [ -n "$vmname" ]; then
                    echo -e "${gl_bufan}$index. ${gl_bai}VM $vmid - $vmname"
                else
                    echo -e "${gl_bufan}$index. ${gl_bai}VM $vmid"
                fi
                ((index++))
            done <<< "$vm_list"
        fi
        
        local ct_list=$(list_cts_with_snapshots)
        if [ -n "$ct_list" ]; then
            while IFS=: read -r ctid ctname; do
                instance_list+=("ct:$ctid")
                if [ -n "$ctname" ]; then
                    echo -e "${gl_bufan}$index. ${gl_bai}CT $ctid - $ctname"
                else
                    echo -e "${gl_bufan}$index. ${gl_bai}CT $ctid"
                fi
                ((index++))
            done <<< "$ct_list"
        fi
        
        if [ ${#instance_list[@]} -eq 0 ]; then
            echo -e "${gl_huang}没有拥有快照的虚拟机或容器${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            return 1
        fi
        
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请选择要删除快照的实例序号 (${gl_hong}0${gl_bai} 退出): ")" choice
        
        if [ "$choice" = "0" ]; then
            exit_script
        fi
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#instance_list[@]}" ]; then
            local selected="${instance_list[$((choice-1))]}"
            local type="${selected%%:*}"
            local id="${selected#*:}"
            
            clear
            echo -e ""
            echo -e "${gl_zi}>>> 快照列表 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_bai}实例: ${gl_bufan}$id${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            
            local snap_names=()
            local snap_index=1
            while IFS= read -r snapname; do
                [ -z "$snapname" ] && continue
                snap_names+=("$snapname")
                local desc=$(get_snapshot_description "$type" "$id" "$snapname")
                local current_mark=$(is_current_snapshot "$type" "$id" "$snapname")
                
                if [ -n "$current_mark" ]; then
                    echo -e "${gl_bufan}$snap_index. ${gl_lv}$snapname ${gl_huang}(当前)${gl_bai}"
                elif [ -n "$desc" ]; then
                    echo -e "${gl_bufan}$snap_index. ${gl_bai}$snapname - $desc"
                else
                    echo -e "${gl_bufan}$snap_index. ${gl_bai}$snapname"
                fi
                ((snap_index++))
            done <<< "$(get_snapshot_names "$type" "$id")"
            
            if [ ${#snap_names[@]} -eq 0 ]; then
                log_info "该实例没有可删除的快照"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
                continue
            fi
            
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bai}请选择要删除的快照序号 (${gl_hong}0${gl_bai} 取消): ")" snap_choice
            
            if [ "$snap_choice" = "0" ]; then
                continue
            fi
            
            if [[ "$snap_choice" =~ ^[0-9]+$ ]] && [ "$snap_choice" -ge 1 ] && [ "$snap_choice" -le "${#snap_names[@]}" ]; then
                local snapname="${snap_names[$((snap_choice-1))]}"
                
                echo -e ""
                read -r -e -p "$(echo -e "${gl_bai}确定删除快照 ${gl_huang}$snapname${gl_bai} 吗？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
                
                if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
                    log_info "已取消删除"
                    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                    break_end
                    continue
                fi
                
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                if [ "$type" = "ct" ]; then
                    delete_ct_snapshot "$id" "$snapname"
                else
                    delete_vm_snapshot "$id" "$snapname"
                fi
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
                return 1
            else
                handle_invalid_input
            fi
        else
            handle_invalid_input
        fi
    done
}

main
