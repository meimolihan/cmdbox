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

list_beautify_pve_pct() {
    {
        printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "CTID" "状态" "名称" "内存(MB)" "磁盘(GB)" "锁" "$reset"
        printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "----" "----" "----" "----" "----" "----" "$reset"

        # 直接使用 pct list 并逐行处理
        pct list 2>/dev/null | tail -n +2 | while IFS= read -r line; do
            # 跳过空行
            [ -z "$line" ] && continue
            
            # 提取 CTID（第一个字段）
            ctid=$(echo "$line" | awk '{print $1}')
            [[ ! "$ctid" =~ ^[0-9]+$ ]] && continue
            
            # 提取状态（第二个字段）
            status=$(echo "$line" | awk '{print $2}')
            
            # 如果状态不是 running/stopped，可能是其他格式，尝试第三个字段
            if [[ "$status" != "running" && "$status" != "stopped" ]]; then
                status=$(echo "$line" | awk '{print $3}')
            fi
            
            # 只处理有效的状态
            if [[ "$status" != "running" && "$status" != "stopped" ]]; then
                continue
            fi
            
            # 提取内存、磁盘、锁（使用默认值避免未定义变量）
            mem=$(echo "$line" | awk '{print $4}')
            disk=$(echo "$line" | awk '{print $6}')
            lock=$(echo "$line" | awk '{print $7}')
            
            # 设置默认值
            [ -z "$mem" ] || [ "$mem" = "running" ] || [ "$mem" = "stopped" ] && mem="-"
            [ -z "$disk" ] || [ "$disk" = "running" ] || [ "$disk" = "stopped" ] && disk="-"
            [ -z "$lock" ] && lock="-"
            
            # 提取名称（移除 CTID 和状态后的内容，再排除数字和特殊字段）
            name=$(echo "$line" | sed -E "s/^[ ]*${ctid}[ ]+//" | sed -E "s/^${status}[ ]+//")
            
            # 进一步清理名称（移除内存、磁盘等数字字段）
            name=$(echo "$name" | sed -E 's/[ ]+[0-9]+[ ]+[0-9.]+[ ]+[^ ]*[ ]*$//' | sed -E 's/[ ]+[0-9]+[ ]+[0-9.]+$//' | xargs)
            
            [ -z "$name" ] && name="(未命名)"
            
            # 状态翻译
            if [[ "$status" == "running" ]]; then
                status_cn="运行中"
                stat_color="${gl_lv}"
            else
                status_cn="已停止"
                stat_color="${gl_hong}"
            fi
            
            echo -e "${gl_lan}${ctid}${reset}\t${stat_color}${status_cn}${reset}\t${gl_bufan}${name}${reset}\t${gl_huang}${mem}${reset}\t${gl_zi}${disk}${reset}\t${gl_hui}${lock}${reset}"
        done
    } | column_if_available
    
    # 如果没有输出任何数据，显示提示
    if [ $? -ne 0 ]; then
        echo -e "${gl_huang}(无数据)\t(无数据)\t(无数据)\t(无数据)\t(无数据)\t(无数据)"
    fi
}

list_beautify_all() {
    clear
    if ! command -v pct &> /dev/null; then
        echo -e ""
        echo -e "${gl_zi}>>> PVE PCT容器列表${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        log_error "未检测到Proxmox VE环境，请确保脚本在PVE节点上运行"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return 1
    fi
    echo -e "${gl_zi}>>> PVE PCT容器列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_pve_pct
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all