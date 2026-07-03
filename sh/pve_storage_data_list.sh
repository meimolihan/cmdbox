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

# 格式化文件大小（字节转可读格式）
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

# 获取文件类型图标
get_file_icon() {
    local volid=$1
    local format=$2
    local type=$3
    
    if [[ "$volid" =~ \.iso$ ]] || [ "$type" = "iso" ]; then
        echo "💿"
    elif [[ "$volid" =~ \.qcow2$ ]] || [ "$format" = "qcow2" ]; then
        echo "💽"
    elif [[ "$volid" =~ \.raw$ ]] || [ "$format" = "raw" ]; then
        echo "🖴"
    elif [[ "$volid" =~ \.(tar|gz|zst)$ ]] || [ "$type" = "backup" ]; then
        echo "📦"
    elif [ "$type" = "vztmpl" ]; then
        echo "📋"
    elif [ "$type" = "rootdir" ]; then
        echo "🗄️"
    else
        echo "📄"
    fi
}

# 显示存储内容（使用 pvesm list）
show_storage_by_list() {
    local storage_name="$1"
    
    echo -e "${gl_zi}>>> 存储: ${gl_huang}${storage_name}${reset}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    {
        printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" \
            "$gl_hui" "图标" "卷ID" "格式" "类型" "大小" "VMID" "$reset"
        printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" \
            "$gl_hui" "----" "-----" "----" "----" "----" "----" "$reset"
        
        # 使用 pvesm list 获取完整信息
        pvesm list "$storage_name" 2>/dev/null | tail -n +2 | while read -r line; do
            volid=$(echo "$line" | awk '{print $1}')
            format=$(echo "$line" | awk '{print $2}')
            type=$(echo "$line" | awk '{print $3}')
            size=$(echo "$line" | awk '{print $4}')
            vmid=$(echo "$line" | awk '{print $5}')
            
            # 格式化大小
            size_fmt=$(format_size "$size")
            
            # 获取图标
            icon=$(get_file_icon "$volid" "$format" "$type")
            
            # 根据类型设置颜色
            case "$type" in
                images)
                    type_color="$gl_huang"
                    ;;
                iso)
                    type_color="$gl_lv"
                    ;;
                backup)
                    type_color="$gl_zi"
                    ;;
                vztmpl)
                    type_color="$gl_bufan"
                    ;;
                rootdir)
                    type_color="$gl_lan"
                    ;;
                *)
                    type_color="$gl_hui"
                    ;;
            esac
            
            # 根据格式设置颜色
            case "$format" in
                qcow2)
                    format_color="$gl_huang"
                    ;;
                raw)
                    format_color="$gl_lv"
                    ;;
                iso)
                    format_color="$gl_lv"
                    ;;
                tar|zst|gz)
                    format_color="$gl_zi"
                    ;;
                *)
                    format_color="$gl_hui"
                    ;;
            esac
            
            # 提取简短名称
            short_name=$(basename "$volid")
            
            echo -e "${gl_bufan}${icon}${reset}\t${gl_bufan}${short_name}${reset}\t${format_color}${format}${reset}\t${type_color}${type}${reset}\t${gl_huang}${size_fmt}${reset}\t${gl_hui}${vmid}${reset}"
        done
    } | column_if_available
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    # 显示统计信息
    local total_size=0
    local image_count=0
    local iso_count=0
    local backup_count=0
    local template_count=0
    
    while read -r line; do
        size=$(echo "$line" | awk '{print $4}')
        type=$(echo "$line" | awk '{print $3}')
        
        if [[ "$size" =~ ^[0-9]+$ ]]; then
            total_size=$((total_size + size))
        fi
        
        case "$type" in
            images) image_count=$((image_count + 1));;
            iso) iso_count=$((iso_count + 1));;
            backup) backup_count=$((backup_count + 1));;
            vztmpl) template_count=$((template_count + 1));;
        esac
    done < <(pvesm list "$storage_name" 2>/dev/null | tail -n +2)
    
    total_size_fmt=$(format_size "$total_size")
    
    echo -e "${gl_hui}统计: ${gl_huang}磁盘镜像: ${image_count}${reset}  ${gl_lv}ISO镜像: ${iso_count}${reset}  ${gl_zi}备份: ${backup_count}${reset}  ${gl_bufan}模板: ${template_count}${reset}  ${gl_lan}总大小: ${total_size_fmt}${reset}"
}

# 显示所有存储内容
show_all_storages() {
    clear
    echo -e "${gl_zi}>>> PVE 所有存储内容列表${reset}"
    echo -e "${gl_bufan}================================================================${reset}"
    
    # 获取所有活跃存储
    local storages=()
    while read -r line; do
        storage=$(echo "$line" | awk '{print $1}')
        status=$(echo "$line" | awk '{print $3}')
        if [ "$status" = "active" ]; then
            storages+=("$storage")
        fi
    done < <(pvesm status 2>/dev/null | tail -n +2)
    
    if [ ${#storages[@]} -eq 0 ]; then
        log_error "未找到任何活跃存储"
        break_end
        return 1
    fi
    
    local count=0
    for storage in "${storages[@]}"; do
        ((count++))
        echo ""
        show_storage_by_list "$storage"
        if [ $count -lt ${#storages[@]} ]; then
            echo -e "${gl_hui}按任意键继续查看下一个存储...${reset}"
            read -r -n 1 -s -r -p ""
            echo ""
            clear
        fi
    done
    
    echo -e "${gl_bufan}================================================================${reset}"
    break_end
}

# 显示帮助
show_help() {
    echo -e "${gl_zi}PVE 存储内容查看工具${reset}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${reset}"
    echo -e "用法: $0 [选项] [存储名称]"
    echo -e ""
    echo -e "选项:"
    echo -e "  ${gl_lv}-h, --help${reset}      显示此帮助信息"
    echo -e "  ${gl_lv}-l, --list${reset}      列出所有可用存储"
    echo -e "  ${gl_lv}-a, --all${reset}      显示所有存储内容（默认）"
    echo -e ""
    echo -e "示例:"
    echo -e "  $0              ${gl_hui}# 显示所有存储内容${reset}"
    echo -e "  $0 local        ${gl_hui}# 显示 local 存储内容${reset}"
    echo -e "  $0 -l           ${gl_hui}# 列出所有存储${reset}"
}

# 列出所有存储
list_storages() {
    clear
    echo -e "${gl_zi}>>> PVE 可用存储列表${reset}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    pvesm status 2>/dev/null | tail -n +2 | while read -r line; do
        storage=$(echo "$line" | awk '{print $1}')
        type=$(echo "$line" | awk '{print $2}')
        status=$(echo "$line" | awk '{print $3}')
        total=$(echo "$line" | awk '{print $4}')
        used=$(echo "$line" | awk '{print $5}')
        
        if [ "$status" = "active" ]; then
            status_color="$gl_lv"
            status_text="✓ 运行中"
        else
            status_color="$gl_hong"
            status_text="✗ 离线"
        fi
        
        total_fmt=$(format_size "$total")
        used_fmt=$(format_size "$used")
        
        echo -e "  ${gl_bufan}${storage}${reset} (${gl_hui}${type}${reset}) ${status_color}${status_text}${reset}"
        echo -e "    总容量: ${gl_huang}${total_fmt}${reset}  已使用: ${gl_zi}${used_fmt}${reset}"
        echo ""
    done
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

# 主函数
main() {
    if ! command -v pvesm &> /dev/null; then
        echo -e ""
        echo -e "${gl_zi}>>> PVE 存储内容查看器${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        log_error "未检测到Proxmox VE环境，请确保脚本在PVE节点上运行"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return 1
    fi
    
    case "$1" in
        -h|--help)
            show_help
            ;;
        -l|--list)
            list_storages
            ;;
        -a|--all)
            show_all_storages
            ;;
        "")
            show_all_storages
            ;;
        *)
            show_storage_by_list "$1"
            break_end
            ;;
    esac
}

main "$@"
