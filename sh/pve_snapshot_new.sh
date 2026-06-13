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

test_snapshot_compatibility() {
    local vmid=$1
    
    local test_name="test_$(date +%s)_$$"
    
    if qm snapshot "$vmid" "$test_name" >/dev/null 2>&1; then
        qm delsnapshot "$vmid" "$test_name" >/dev/null 2>&1
        return 0
    fi
    
    return 1
}

list_snapshot_supported_vms() {
    local vms=$(qm list 2>/dev/null | awk 'NR>1 {print $1}' | sort -n)
    local supported_vms=()
    
    for vmid in $vms; do
        if test_snapshot_compatibility "$vmid"; then
            local vm_name=$(qm config "$vmid" 2>/dev/null | grep "^name:" | awk '{print $2}')
            supported_vms+=("$vmid:$vm_name")
        fi
    done
    
    printf '%s\n' "${supported_vms[@]}"
}

create_vm_snapshot() {
    local vmid=$1
    local snapname=$2
    local description=$3
    
    log_info "正在为虚拟机 ${gl_bufan}$vmid${gl_bai} 创建快照 ${gl_bufan}$snapname${gl_bai}"
    
    if qm listsnapshot "$vmid" 2>/dev/null | grep -q "$snapname"; then
        log_error "快照名称 $snapname 已存在"
        return 1
    fi
    
    if [ -n "$description" ]; then
        qm snapshot "$vmid" "$snapname" --description "$description" 2>&1
    else
        qm snapshot "$vmid" "$snapname" 2>&1
    fi
    
    if [ $? -eq 0 ]; then
        log_ok "快照创建成功"
        return 0
    else
        log_error "快照创建失败"
        return 1
    fi
}

create_ct_snapshot() {
    local ctid=$1
    local snapname=$2
    local description=$3
    
    log_info "正在为容器 ${gl_bufan}$ctid${gl_bai} 创建快照 ${gl_bufan}$snapname${gl_bai}"
    
    if pct listsnapshot "$ctid" 2>/dev/null | grep -q "$snapname"; then
        log_error "快照名称 $snapname 已存在"
        return 1
    fi
    
    if [ -n "$description" ]; then
        pct snapshot "$ctid" "$snapname" --description "$description" 2>&1
    else
        pct snapshot "$ctid" "$snapname" 2>&1
    fi
    
    if [ $? -eq 0 ]; then
        log_ok "快照创建成功"
        return 0
    else
        log_error "快照创建失败"
        return 1
    fi
}

handle_invalid_input() {
    echo -ne "\r${gl_huang}无效的输入，请重新输入! ${gl_zi} 1 ${gl_huang} 秒后返回"
    sleep 1
    echo -e "\r${gl_lv}无效的输入，请重新输入! ${gl_zi}0${gl_lv} 秒后返回"
    sleep 0.5
}

main() {
    while true; do
        clear
        root_use
        
        if ! command -v qm &> /dev/null; then
            echo -e ""
            echo -e "${gl_huang}>>> PVE 创建虚拟机/容器快照 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            log_error "未检测到Proxmox VE环境，请确保脚本在PVE节点上运行"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            return 1
        fi
        
        echo -e ""
        echo -e "${gl_zi}>>> PVE 创建虚拟机/容器快照 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        local supported_vms=()
        local vm_list=$(list_snapshot_supported_vms)
        
        if [ -n "$vm_list" ]; then
            local index=1
            while IFS=: read -r vmid vmname; do
                supported_vms+=("$vmid")
                if [ -n "$vmname" ]; then
                    echo -e "${gl_bufan}$index. ${gl_bai}VM $vmid - $vmname"
                else
                    echo -e "${gl_bufan}$index. ${gl_bai}VM $vmid"
                fi
                ((index++))
            done <<< "$vm_list"
        else
            echo -e "${gl_huang}未找到支持快照的虚拟机${gl_bai}"
        fi
        
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        local cts=$(pct list 2>/dev/null | awk 'NR>1 {print $1}' | sort -n)
        if [ -n "$cts" ]; then
            for ctid in $cts; do
                local ct_name=$(pct config "$ctid" 2>/dev/null | grep "^hostname:" | awk '{print $2}')
                echo -e "${gl_bufan}$index. ${gl_bai}CT $ctid - $ct_name"
                supported_vms+=("ct:$ctid")
                ((index++))
            done
        fi
        
        if [ ${#supported_vms[@]} -eq 0 ]; then
            echo -e "${gl_huang}没有可用的虚拟机或容器${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bai}请输入你的选择 (${gl_hong}0${gl_bai}退出): ")" choice
            if [ "$choice" = "0" ]; then
                exit_script
            fi
            continue
        fi
        
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        read -r -e -p "$(echo -e "${gl_bai}请选择要创建快照的实例序号 (${gl_hong}0${gl_bai} 退出): ")" choice
        
        if [ "$choice" = "0" ]; then
            exit_script
        fi
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#supported_vms[@]}" ]; then
            local selected="${supported_vms[$((choice-1))]}"
            local type=""
            local id=""
            
            if [[ "$selected" == ct:* ]]; then
                type="ct"
                id="${selected#ct:}"
            else
                type="vm"
                id="$selected"
            fi
            
            read -r -e -p "$(echo -e "${gl_bai}请输入快照名称: ")" snapname
            
            if [ -z "$snapname" ]; then
                log_error "快照名称不能为空"
                break_end
                return 1
            fi
            
            if [[ ! "$snapname" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                log_error "快照名称只能包含字母、数字、下划线和横线"
                break_end
                return 1
            fi
            
            read -r -e -p "$(echo -e "${gl_bai}请输入快照描述 (${gl_huang}可选${gl_bai}，直接回车跳过): ")" description
            
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            
            if [ "$type" = "ct" ]; then
                create_ct_snapshot "$id" "$snapname" "$description"
            else
                create_vm_snapshot "$id" "$snapname" "$description"
            fi
            
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            return 1
        else
            handle_invalid_input
        fi
    done
}

main
