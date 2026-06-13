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
    local int_seconds=$(echo "$seconds" | awk '{print int($1+0.888)}')
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

reboot_instance() {
    local VMID="$1"
    local TYPE=""
    
    if qm status "$VMID" &>/dev/null; then
        TYPE="QM虚拟机"
        local CURRENT_STATUS
        CURRENT_STATUS=$(qm status "$VMID" 2>/dev/null | awk '{print $2}')
        
        if [ "$CURRENT_STATUS" = "stopped" ]; then
            log_warn "${TYPE} ${VMID} 已停止，跳过重启"
            return 0
        fi
        
        if qm reboot "$VMID" &>/dev/null; then
            log_ok "${TYPE} ${VMID} 已重启"
            return 0
        else
            log_error "${TYPE} ${VMID} 重启失败"
            return 1
        fi
        
    elif pct status "$VMID" &>/dev/null; then
        TYPE="LXC容器"
        local CURRENT_STATUS
        CURRENT_STATUS=$(pct status "$VMID" 2>/dev/null | awk '{print $2}')
        
        if [ "$CURRENT_STATUS" = "stopped" ]; then
            log_warn "${TYPE} ${VMID} 已停止，跳过重启"
            return 0
        fi
        
        if pct reboot "$VMID" &>/dev/null; then
            log_ok "${TYPE} ${VMID} 已重启"
            return 0
        else
            log_error "${TYPE} ${VMID} 重启失败"
            return 1
        fi
    else
        log_error "实例 ${VMID} 不存在"
        return 1
    fi
}

reboot_instances() {
    local ids=("$@")
    local success_count=0
    local fail_count=0
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${reset}"
    
    for id in "${ids[@]}"; do
        if reboot_instance "$id"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
    done
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${reset}"
    echo -e "${gl_lv}成功: ${success_count}${reset}  ${gl_hong}失败: ${fail_count}${reset}"
}

main() {
    clear
    echo -e "${gl_zi}>>> PVE 实例重启工具${reset}"
    
    local ids_to_reboot=()
    
    if [ $# -gt 0 ]; then
        if [ "$1" = "all" ]; then
            log_info "获取所有实例ID ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            IFS=' ' read -r -a ids_to_reboot <<< "$(get_all_instance_ids)"
            if [ ${#ids_to_reboot[@]} -eq 0 ]; then
                log_error "未找到任何实例"
                break_end
                exit 1
            fi
            log_info "找到 ${#ids_to_reboot[@]} 个实例"
        else
            ids_to_reboot=("$@")
        fi
    else
        clear
        show_all_instance
        echo -e ""
        echo -e "${gl_zi}>>> PVE 实例重启工具${reset}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${reset}"
        echo -e "  • 输入 ${gl_lv}实例ID${gl_bai}，多个ID用 ${gl_huang}空格${gl_bai} 分隔"
        echo -e "  • 输入 ${gl_lv}888${gl_bai} 重启 ${gl_huang}所有实例${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${reset}"
        
        local INPUT
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择(${gl_hong}0${gl_bai} 退出):")" INPUT
        
        if [ "$INPUT" = "0" ]; then
            exit_script
        fi
        
        if [ "$INPUT" = "888" ]; then
            log_info "获取所有实例ID ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            IFS=' ' read -r -a ids_to_reboot <<< "$(get_all_instance_ids)"
            if [ ${#ids_to_reboot[@]} -eq 0 ]; then
                log_error "未找到任何实例"
                break_end
                exit 1
            fi
            log_info "找到 ${#ids_to_reboot[@]} 个实例"
        else
            ids_to_reboot=($INPUT)
        fi
    fi
    
    if [ ${#ids_to_reboot[@]} -gt 0 ]; then
        reboot_instances "${ids_to_reboot[@]}"
    else
        log_warn "没有需要重启的实例"
    fi
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${reset}"
    break_end
}

main "$@"
