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

show_snapshots() {
    clear
    root_use
    
    if ! command -v qm &> /dev/null; then
        echo -e ""
        echo -e "${gl_huang}>>> KVM 虚拟机快照 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        log_error "未检测到Proxmox VE环境，请确保脚本在PVE节点上运行"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return 1
    fi
    
    echo -e ""
    echo -e "${gl_zi}>>> KVM 虚拟机快照 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    local vms=$(qm list 2>/dev/null | awk 'NR>1 {print $1}' | sort -n)
    
    if [ -z "$vms" ]; then
        log_info "未找到任何虚拟机"
    else
        for vmid in $vms; do
            echo -e "\n${gl_lv}┌── 虚拟机 ID：${gl_bufan}$vmid${gl_bai}"
            local snap=$(qm listsnapshot "$vmid" 2>/dev/null)
            
            if [ -z "$snap" ]; then
                echo -e "${gl_lv}└─ ${gl_huang}暂无快照${gl_bai}"
            else
                echo "$snap" | sed \
                    -e 's/current/当前系统/g' \
                    -e 's/You are here!/当前运行节点/g' \
                    -e 's/no-description/无备注/g' \
                    -e 's/^/├─ /'
                echo -e "${gl_lv}└────────────────────────────────────${gl_bai}"
            fi
        done
    fi
    
    echo -e "\n${gl_zi}>>> LXC 容器快照 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    local cts=$(pct list 2>/dev/null | awk 'NR>1 {print $1}' | sort -n)
    
    if [ -z "$cts" ]; then
        log_info "未找到任何容器"
    else
        for ctid in $cts; do
            echo -e "\n${gl_lv}┌── 容器 ID：${gl_bufan}$ctid${gl_bai}"
            local snap=$(pct listsnapshot "$ctid" 2>/dev/null)
            
            if [ -z "$snap" ]; then
                echo -e "${gl_lv}└─ ${gl_huang}暂无快照${gl_bai}"
            else
                echo "$snap" | sed \
                    -e 's/current/当前系统/g' \
                    -e 's/You are here!/当前运行节点/g' \
                    -e 's/no-description/无备注/g' \
                    -e 's/^/├─ /'
                echo -e "${gl_lv}└────────────────────────────────────${gl_bai}"
            fi
        done
    fi
    
    echo -e "\n${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

if [ "$EUID" -ne 0 ]; then
    log_error "此脚本需要 root 权限运行"
    echo -e "${gl_huang}请使用 sudo 执行此脚本${gl_bai}"
    exit 1
fi

show_snapshots
