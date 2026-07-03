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

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    read -r -n 1 -s -r -p ""
    echo ""
    clear
}

translate_key() {
    local key="$1"
    key=${key//"balloon"/"内存动态调整"}
    key=${key//"ballooninfo"/"调整详情"}
    key=${key//"actual"/"实际分配内存"}
    key=${key//"free_mem"/"空闲内存"}
    key=${key//"last_update"/"最后更新"}
    key=${key//"major_page_faults"/"主要缺页"}
    key=${key//"max_mem"/"最大限制内存"}
    key=${key//"mem_swapped_in"/"换入内存"}
    key=${key//"mem_swapped_out"/"换出内存"}
    key=${key//"minor_page_faults"/"次要缺页"}
    key=${key//"total_mem"/"总内存容量"}
    key=${key//"blockstat"/"磁盘统计"}
    key=${key//"account_failed"/"统计失败"}
    key=${key//"account_invalid"/"统计无效"}
    key=${key//"failed_flush_operations"/"失败刷新"}
    key=${key//"failed_rd_operations"/"失败读"}
    key=${key//"failed_unmap_operations"/"失败取消映射"}
    key=${key//"failed_wr_operations"/"失败写"}
    key=${key//"flush_operations"/"刷新次数"}
    key=${key//"flush_total_time_ns"/"刷新耗时"}
    key=${key//"idle_time_ns"/"空闲时间"}
    key=${key//"invalid_flush_operations"/"无效刷新"}
    key=${key//"invalid_rd_operations"/"无效读"}
    key=${key//"invalid_unmap_operations"/"无效取消映射"}
    key=${key//"invalid_wr_operations"/"无效写"}
    key=${key//"rd_bytes"/"读取字节"}
    key=${key//"rd_merged"/"读合并"}
    key=${key//"rd_operations"/"读取次数"}
    key=${key//"rd_total_time_ns"/"读取耗时"}
    key=${key//"timed_stats"/"定时统计"}
    key=${key//"unmap_bytes"/"取消映射字节"}
    key=${key//"unmap_merged"/"取消映射合并"}
    key=${key//"unmap_operations"/"取消映射次数"}
    key=${key//"unmap_total_time_ns"/"取消映射耗时"}
    key=${key//"wr_bytes"/"写入字节"}
    key=${key//"wr_highest_offset"/"最大写入偏移"}
    key=${key//"wr_merged"/"写合并"}
    key=${key//"wr_operations"/"写入次数"}
    key=${key//"wr_total_time_ns"/"写入耗时"}
    key=${key//"cpus"/"CPU核心数"}
    key=${key//"disk"/"磁盘使用"}
    key=${key//"diskread"/"磁盘读取速度"}
    key=${key//"diskwrite"/"磁盘写入速度"}
    key=${key//"free_memory"/"空闲内存"}
    key=${key//"maxdisk"/"最大磁盘"}
    key=${key//"maxmem"/"最大内存"}
    key=${key//"mem"/"内存使用"}
    key=${key//"memory_host"/"宿主机内存"}
    key=${key//"name"/"虚拟机名称"}
    key=${key//"netin"/"网络接收速度"}
    key=${key//"netout"/"网络发送速度"}
    key=${key//"nics"/"网络接口"}
    key=${key//"pid"/"进程ID"}
    key=${key//"pressure_cpu_full"/"CPU完全压力"}
    key=${key//"pressure_cpu_some"/"CPU部分压力"}
    key=${key//"pressure_io_full"/"IO完全压力"}
    key=${key//"pressure_io_some"/"IO部分压力"}
    key=${key//"pressure_memory_full"/"内存完全压力"}
    key=${key//"pressure_memory_some"/"内存部分压力"}
    key=${key//"qmpstatus"/"QMP状态"}
    key=${key//"running-machine"/"机器类型"}
    key=${key//"running-qemu"/"QEMU版本"}
    key=${key//"status"/"运行状态"}
    key=${key//"tags"/"标签"}
    key=${key//"uptime"/"运行时间"}
    key=${key//"vmid"/"虚拟机ID"}
    key=${key//"proxmox-support"/"Proxmox支持特性"}
    echo "$key"
}

format_size() {
    local size="$1"
    if [[ "$size" =~ ^[0-9]+$ ]]; then
        if [ $size -gt 1073741824 ]; then
            echo "$(echo "scale=2; $size/1073741824" | bc)GB"
        elif [ $size -gt 1048576 ]; then
            echo "$(echo "scale=2; $size/1048576" | bc)MB"
        elif [ $size -gt 1024 ]; then
            echo "$(echo "scale=2; $size/1024" | bc)KB"
        else
            echo "${size}B"
        fi
    else
        echo "$size"
    fi
}

format_speed() {
    local speed="$1"
    if [[ "$speed" =~ ^[0-9]+$ ]]; then
        if [ $speed -gt 1073741824 ]; then
            echo "$(echo "scale=2; $speed/1073741824" | bc)GB/s"
        elif [ $speed -gt 1048576 ]; then
            echo "$(echo "scale=2; $speed/1048576" | bc)MB/s"
        elif [ $speed -gt 1024 ]; then
            echo "$(echo "scale=2; $speed/1024" | bc)KB/s"
        else
            echo "${speed}B/s"
        fi
    else
        echo "$speed"
    fi
}

format_time() {
    local seconds="$1"
    if [[ "$seconds" =~ ^[0-9]+$ ]]; then
        local days=$((seconds / 86400))
        local hours=$(( (seconds % 86400) / 3600 ))
        local minutes=$(( (seconds % 3600) / 60 ))
        local secs=$((seconds % 60))
        
        if [ $days -gt 0 ]; then
            echo "${days}天${hours}时${minutes}分${secs}秒"
        elif [ $hours -gt 0 ]; then
            echo "${hours}时${minutes}分${secs}秒"
        elif [ $minutes -gt 0 ]; then
            echo "${minutes}分${secs}秒"
        else
            echo "${secs}秒"
        fi
    else
        echo "$seconds"
    fi
}

extract_disk_stats() {
    local device="$1"
    local data="$2"
    
    local read_bytes=$(echo "$data" | grep -E "^[[:space:]]+rd_bytes:" | awk '{print $2}')
    local write_bytes=$(echo "$data" | grep -E "^[[:space:]]+wr_bytes:" | awk '{print $2}')
    local read_ops=$(echo "$data" | grep -E "^[[:space:]]+rd_operations:" | awk '{print $2}')
    local write_ops=$(echo "$data" | grep -E "^[[:space:]]+wr_operations:" | awk '{print $2}')
    local flush_ops=$(echo "$data" | grep -E "^[[:space:]]+flush_operations:" | awk '{print $2}')
    
    if [ -n "$read_bytes" ] || [ -n "$write_bytes" ]; then
        echo -e "    ${gl_hui}📖 读取:${reset} $(format_size "$read_bytes") (${read_ops}次)"
        echo -e "    ${gl_hui}📝 写入:${reset} $(format_size "$write_bytes") (${write_ops}次)"
        [ -n "$flush_ops" ] && [ "$flush_ops" != "0" ] && echo -e "    ${gl_hui}🔄 刷新:${reset} ${flush_ops}次"
    fi
}

extract_balloon_stats() {
    local data="$1"
    
    local actual=$(echo "$data" | grep -E "^[[:space:]]+actual:" | awk '{print $2}')
    local max_mem=$(echo "$data" | grep -E "^[[:space:]]+max_mem:" | awk '{print $2}')
    local free_mem=$(echo "$data" | grep -E "^[[:space:]]+free_mem:" | awk '{print $2}')
    local total_mem=$(echo "$data" | grep -E "^[[:space:]]+total_mem:" | awk '{print $2}')
    
    if [ -n "$actual" ]; then
        echo -e "    ${gl_hui}📊 实际分配内存:${reset} $(format_size "$actual")"
        [ -n "$max_mem" ] && echo -e "    ${gl_hui}📈 最大限制内存:${reset} $(format_size "$max_mem")"
        [ -n "$total_mem" ] && echo -e "    ${gl_hui}💾 总内存容量:${reset} $(format_size "$total_mem")"
        [ -n "$free_mem" ] && echo -e "    ${gl_hui}✨ 空闲内存:${reset} $(format_size "$free_mem")"
    fi
}

extract_nic_stats() {
    local nic="$1"
    local data="$2"
    
    local netin=$(echo "$data" | grep -E "^[[:space:]]+netin:" | awk '{print $2}')
    local netout=$(echo "$data" | grep -E "^[[:space:]]+netout:" | awk '{print $2}')
    
    if [ -n "$netin" ] || [ -n "$netout" ]; then
        echo -e "    ${gl_hui}📥 接收:${reset} $(format_speed "$netin")"
        echo -e "    ${gl_hui}📤 发送:${reset} $(format_speed "$netout")"
    fi
}

list_beautify_qm_status() {
    local vmid="$1"
    
    if ! command -v qm &> /dev/null; then
        echo -e "${gl_hong}[错误] 未检测到 qm 命令${reset}"
        return 1
    fi
    
    if [ -z "$vmid" ]; then
        echo -e "${gl_hong}[错误] 请指定虚拟机ID${reset}"
        return 1
    fi
    
    local status_output=$(qm status "$vmid" --verbose 2>&1)
    
    if [ $? -ne 0 ]; then
        echo -e "${gl_hong}[错误] 无法获取虚拟机状态${reset}"
        return 1
    fi
    
    local vm_name=$(echo "$status_output" | grep "^name:" | awk '{print $2}')
    [ -z "$vm_name" ] && vm_name="未知"
    
    {
        echo -e "${gl_zi}>>> 虚拟机状态详情 (VMID: ${gl_huang}$vmid ${gl_bai}- ${gl_zi}名称: ${gl_lv}$vm_name)${reset}"
        echo -e "${gl_bufan}———————————————————————————————————————————————————————————${reset}"
        
        local current_section=""
        local section_buffer=""
        
        echo "$status_output" | while IFS= read -r line; do
            if [[ "$line" =~ ^[a-zA-Z0-9_-]+: ]] && ! [[ "$line" =~ ^[[:space:]]+ ]]; then
                if [ -n "$current_section" ] && [ -n "$section_buffer" ]; then
                    case "$current_section" in
                        "ballooninfo")
                            echo -e "${gl_lv}▶ 调整详情${reset}"
                            extract_balloon_stats "$section_buffer"
                            ;;
                        "blockstat")
                            local device=$(echo "$section_buffer" | head -1 | sed 's/^[[:space:]]*//' | cut -d':' -f1)
                            echo -e "${gl_huang}▶ 磁盘设备: ${device}${reset}"
                            extract_disk_stats "$device" "$section_buffer"
                            ;;
                    esac
                fi
                
                current_section=""
                section_buffer=""
                
                local key=$(echo "$line" | cut -d':' -f1)
                local value=$(echo "$line" | cut -d':' -f2- | sed 's/^ //')
                local key_cn=$(translate_key "$key")
                local formatted_value="$value"
                local value_color=$gl_bai
                
                case "$key" in
                    "status")
                        if [ "$value" == "running" ]; then
                            formatted_value="✅ 运行中"
                            value_color=$gl_lv
                        elif [ "$value" == "stopped" ]; then
                            formatted_value="⏹️ 已停止"
                            value_color=$gl_hong
                        else
                            formatted_value="❓ 未知"
                            value_color=$gl_huang
                        fi
                        ;;
                    "qmpstatus")
                        if [ "$value" == "running" ]; then
                            formatted_value="✅ 运行中"
                            value_color=$gl_lv
                        else
                            formatted_value="$value"
                            value_color=$gl_huang
                        fi
                        ;;
                    "uptime")
                        formatted_value="⏱️ $(format_time "$value")"
                        value_color=$gl_lv
                        ;;
                    "mem"|"maxmem"|"free_memory"|"memory_host")
                        formatted_value="$(format_size "$value")"
                        value_color=$gl_huang
                        ;;
                    "disk"|"maxdisk")
                        formatted_value="$(format_size "$value")"
                        value_color=$gl_zi
                        ;;
                    "diskread"|"diskwrite")
                        formatted_value="$(format_speed "$value")"
                        value_color=$gl_bufan
                        ;;
                    "netin"|"netout")
                        formatted_value="$(format_speed "$value")"
                        value_color=$gl_bufan
                        ;;
                    "cpus")
                        formatted_value="${value} 核心"
                        value_color=$gl_lan
                        ;;
                    "pid")
                        formatted_value="🔢 ${value}"
                        value_color=$gl_lan
                        ;;
                    "balloon")
                        formatted_value="$(format_size "$value")"
                        echo -e "${gl_lv}▶ 内存动态调整: ${formatted_value}${reset}"
                        current_section=""
                        continue
                        ;;
                    "ballooninfo")
                        current_section="ballooninfo"
                        continue
                        ;;
                    "blockstat")
                        current_section="blockstat"
                        continue
                        ;;
                    "nics")
                        current_section="nics"
                        continue
                        ;;
                    "proxmox-support")
                        echo -e ""
                        echo -e "${gl_bufan}▶ Proxmox支持特性${reset}"
                        current_section="proxmox"
                        continue
                        ;;
                    *)
                        printf "%-24s ${value_color}%s${reset}\n" "${gl_lan}${key_cn}${reset}:" "$formatted_value"
                        ;;
                esac
                
                if [[ "$key" != "balloon" ]] && [[ "$key" != "ballooninfo" ]] && [[ "$key" != "blockstat" ]] && [[ "$key" != "nics" ]] && [[ "$key" != "proxmox-support" ]]; then
                    printf "%-24s ${value_color}%s${reset}\n" "${gl_lan}${key_cn}${reset}:" "$formatted_value"
                fi
                
            elif [ -n "$current_section" ]; then
                section_buffer="${section_buffer}${line}\n"
            elif [[ "$current_section" == "nics" ]] && [[ "$line" =~ ^[[:space:]]+[a-zA-Z0-9_-]+: ]]; then
                local nic_name=$(echo "$line" | sed 's/^[[:space:]]*//' | cut -d':' -f1)
                echo -e "  ${gl_bufan}🔗 ${nic_name}${reset}"
            elif [[ "$current_section" == "nics" ]] && [[ "$line" =~ ^[[:space:]]+netin: ]] || [[ "$line" =~ ^[[:space:]]+netout: ]]; then
                local nic_key=$(echo "$line" | sed 's/^[[:space:]]*//' | cut -d':' -f1)
                local nic_value=$(echo "$line" | sed 's/^[[:space:]]*//' | cut -d':' -f2- | sed 's/^ //')
                if [ "$nic_key" == "netin" ]; then
                    echo -e "    ${gl_hui}📥 接收:${reset} $(format_speed "$nic_value")"
                elif [ "$nic_key" == "netout" ]; then
                    echo -e "    ${gl_hui}📤 发送:${reset} $(format_speed "$nic_value")"
                fi
            elif [[ "$current_section" == "proxmox" ]] && [[ "$line" =~ ^[[:space:]]+[a-zA-Z0-9_-]+: ]]; then
                local p_key=$(echo "$line" | sed 's/^[[:space:]]*//' | cut -d':' -f1)
                local p_value=$(echo "$line" | sed 's/^[[:space:]]*//' | cut -d':' -f2- | sed 's/^ //')
                p_key=$(translate_key "$p_key")
                if [ ${#p_value} -gt 50 ]; then
                    p_value="${p_value:0:47}..."
                fi
                echo -e "  ${gl_hui}${p_key}:${reset} ${gl_bufan}${p_value}${reset}"
            fi
        done
        
        echo -e "${gl_bufan}———————————————————————————————————————————————————————————${reset}"
    }
}

main() {
    local vmid="${1:-}"
    
    clear

    if ! command -v qm &> /dev/null; then
	    echo -e ""
	    echo -e "${gl_huang}>>> Proxmox VE 虚拟机状态查询${gl_bai}"
	    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
	    log_error "未检测到Proxmox VE环境，请确保脚本在PVE节点上运行"
	    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
	    break_end
	    return 1
    fi
    
    if [ -z "$vmid" ]; then
        echo -e "${gl_zi}>>> Proxmox VE 虚拟机状态查询${gl_bai}"
        echo -e "${gl_bufan}———————————————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}请指定虚拟机ID${reset}"
        echo -e "${gl_bai}用法: $0 <VMID>${reset}"
        echo -e "${gl_bai}示例: $0 252${reset}"
        echo -e "${gl_bufan}———————————————————————————————————————————————————————————${gl_bai}"
        break_end
        return 1
    fi
    
    list_beautify_qm_status "$vmid"
    break_end
}

main "$@"
