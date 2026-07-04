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

list_beautify_pve_qm() {
    {
        printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "VMID" "名称" "状态" "内存(MB)" "磁盘(GB)" "锁" "$reset"
        printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "----" "----" "----" "----" "----" "----" "$reset"

        # 保存原始 IFS 并设置为只按换行分割
        local IFS=$'\n'
        local lines=($(qm list | tail -n +2))
        
        for line in "${lines[@]}"; do
            # 跳过空行
            [ -z "$line" ] && continue
            
            # 提取 VMID（第一个字段，数字）
            vmid=$(echo "$line" | awk '{print $1}')
            [[ ! "$vmid" =~ ^[0-9]+$ ]] && continue
            
            # 提取状态字段
            status=$(echo "$line" | awk '{print $3}')
            [[ "$status" != "running" && "$status" != "stopped" ]] && continue
            
            # 提取内存和磁盘
            mem=$(echo "$line" | awk '{print $4}')
            disk=$(echo "$line" | awk '{print $5}')
            
            # 提取锁字段（第6个字段）
            lock=$(echo "$line" | awk '{print $6}')
            [ -z "$lock" ] && lock="-"
            
            # 提取名称（从第2个字段开始，但要排除状态、内存、磁盘、锁）
            # 方法：移除前面的 VMID，然后移除后面的状态、内存、磁盘、锁
            name=$(echo "$line" | sed -E 's/^[ ]*[0-9]+[ ]+//' | sed -E 's/[ ]+(running|stopped)[ ]+[0-9]+[ ]+[0-9.]+[ ]+[^ ]*[ ]*$//')
            [ -z "$name" ] && name="(未命名)"
            
            # 状态翻译和颜色设置
            if [[ $status == "running" ]]; then
                status_cn="运行中"
                stat_color="${gl_lv}"
            else
                status_cn="已停止"
                stat_color="${gl_hong}"
            fi
            
            echo -e "${gl_lan}${vmid}${reset}\t${gl_bufan}${name}${reset}\t${stat_color}${status_cn}${reset}\t${gl_huang}${mem}${reset}\t${gl_zi}${disk}${reset}\t${gl_hui}${lock}${reset}"
        done
    } | column_if_available
}

list_beautify_all() {
    clear
    if ! command -v qm &> /dev/null; then
        echo -e ""
        echo -e "${gl_zi}>>> PVE QM虚拟机列表${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        log_error "未检测到Proxmox VE环境，请确保脚本在PVE节点上运行"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return 1
    fi
    echo -e "${gl_zi}>>> PVE QM虚拟机列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_pve_qm
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all