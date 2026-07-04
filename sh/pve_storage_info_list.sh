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

format_size() {
    local size=$1
    if [[ ! "$size" =~ ^[0-9]+$ ]]; then
        echo "-"
        return
    fi
    
    if [ $size -ge 1073741824 ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $size/1073741824}") GB"
    elif [ $size -ge 1048576 ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $size/1048576}") MB"
    elif [ $size -ge 1024 ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $size/1024}") KB"
    else
        echo "${size} B"
    fi
}

get_usage_color() {
    local usage=$1
    if [[ ! "$usage" =~ ^[0-9]+$ ]]; then
        echo "$gl_hui"
        return
    fi
    
    if [ $usage -ge 90 ]; then
        echo "$gl_hong"
    elif [ $usage -ge 75 ]; then
        echo "$gl_huang"
    else
        echo "$gl_lv"
    fi
}

show_storage_status() {
    clear
    if ! command -v pvesm &> /dev/null; then
        echo -e ""
        echo -e "${gl_zi}>>> PVE 存储状态${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        log_error "未检测到Proxmox VE环境，请确保脚本在PVE节点上运行"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return 1
    fi
    
    echo -e "${gl_zi}>>> PVE 存储状态${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    {
        printf "%s%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s%s\n" \
            "$gl_hui" "存储名称" "类型" "状态" "总容量" "已使用" "可用" "使用率" "挂载点" "$reset"
        printf "%s%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s%s\n" \
            "$gl_hui" "--------" "----" "----" "------" "------" "----" "------" "--------" "$reset"
        
        pvesm status 2>/dev/null | tail -n +2 | while IFS= read -r line; do

            storage=$(echo "$line" | awk '{print $1}')
            type=$(echo "$line" | awk '{print $2}')
            status=$(echo "$line" | awk '{print $3}')
            total=$(echo "$line" | awk '{print $4}')
            used=$(echo "$line" | awk '{print $5}')
            avail=$(echo "$line" | awk '{print $6}')
            usage_percent=$(echo "$line" | awk '{print $7}' | sed 's/%//')
            mountpoint=$(echo "$line" | awk '{print $8}')
            total_fmt=$(format_size "$total")
            used_fmt=$(format_size "$used")
            avail_fmt=$(format_size "$avail")

            if [ "$status" = "active" ]; then
                status_color="$gl_lv"
                status_text="运行中"
            else
                status_color="$gl_hong"
                status_text="离线"
            fi
            
            usage_color=$(get_usage_color "$usage_percent")
            
            case "$type" in
                dir|directory)
                    type_color="$gl_bufan"
                    ;;
                nfs)
                    type_color="$gl_lan"
                    ;;
                lvm|lvmthin)
                    type_color="$gl_zi"
                    ;;
                zfspool)
                    type_color="$gl_huang"
                    ;;
                *)
                    type_color="$gl_hui"
                    ;;
            esac
            
            echo -e "${gl_bufan}${storage}${reset}\t${type_color}${type}${reset}\t${status_color}${status_text}${reset}\t${gl_huang}${total_fmt}${reset}\t${gl_zi}${used_fmt}${reset}\t${gl_lv}${avail_fmt}${reset}\t${usage_color}${usage_percent}%${reset}\t${gl_hui}${mountpoint}${reset}"
        done
    } | column_if_available
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

show_help() {
    echo -e "${gl_zi}PVE 存储状态查看工具${reset}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${reset}"
    echo -e "用法: $0 [选项]"
    echo -e ""
    echo -e "选项:"
    echo -e "  ${gl_lv}-h, --help${reset}      显示此帮助信息"
    echo -e "  ${gl_lv}-s, --simple${reset}    简单模式（不显示挂载点）"
    echo -e ""
    echo -e "示例:"
    echo -e "  $0              ${gl_hui}# 显示详细存储状态${reset}"
    echo -e "  $0 -s           ${gl_hui}# 显示简化存储状态${reset}"
}

show_storage_status_simple() {
    clear
    echo -e "${gl_zi}>>> PVE 存储状态${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    {
        printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" \
            "$gl_hui" "存储名称" "类型" "状态" "总容量" "已使用" "使用率" "$reset"
        printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" \
            "$gl_hui" "--------" "----" "----" "------" "------" "------" "$reset"
        
        pvesm status 2>/dev/null | tail -n +2 | while read -r line; do
            storage=$(echo "$line" | awk '{print $1}')
            type=$(echo "$line" | awk '{print $2}')
            status=$(echo "$line" | awk '{print $3}')
            total=$(echo "$line" | awk '{print $4}')
            used=$(echo "$line" | awk '{print $5}')
            usage_percent=$(echo "$line" | awk '{print $7}' | sed 's/%//')
            
            total_fmt=$(format_size "$total")
            used_fmt=$(format_size "$used")
            
            if [ "$status" = "active" ]; then
                status_color="$gl_lv"
                status_text="运行中"
            else
                status_color="$gl_hong"
                status_text="离线"
            fi
            
            usage_color=$(get_usage_color "$usage_percent")
            
            echo -e "${gl_bufan}${storage}${reset}\t${gl_hui}${type}${reset}\t${status_color}${status_text}${reset}\t${gl_huang}${total_fmt}${reset}\t${gl_zi}${used_fmt}${reset}\t${usage_color}${usage_percent}%${reset}"
        done
    } | column_if_available
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

main() {
    case "$1" in
        -h|--help)
            show_help
            ;;
        -s|--simple)
            show_storage_status_simple
            ;;
        *)
            show_storage_status
            ;;
    esac
}

main "$@"
