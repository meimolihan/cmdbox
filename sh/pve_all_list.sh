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

log_info() { echo -e "${gl_lan}[信息]${gl_bai} $*"; }
log_ok() { echo -e "${gl_lv}[成功]${gl_bai} $*"; }
log_warn() { echo -e "${gl_huang}[警告]${gl_bai} $*"; }
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
        echo -e "${gl_zi}>>> PVE 全部实例列表(VM虚拟机 + CT容器)${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        log_error "未检测到Proxmox VE环境，请确保脚本在PVE节点上运行"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return 1
    fi
    echo -e "${gl_zi}>>> PVE 全部实例列表(VM虚拟机 + CT容器)${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    {
        printf "%s%s\t%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "类型" "ID" "名称" "状态" "内存" "磁盘" "锁" "$reset"
        printf "%s%s\t%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "----" "----" "----" "----" "----" "----" "----" "$reset"

        parse_qm_list
        parse_pct_list
    } | column_if_available

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

show_all_instance