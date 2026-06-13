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
    echo -e "${gl_bai}按任意键继续${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n 1 -s -p ""
    echo ""
    clear
}

sleep_fractional() {
    local seconds=$1
    if sleep "$seconds" 2>/dev/null; then return 0; fi
    if command -v perl >/dev/null 2>&1; then perl -e "select(undef, undef, undef, $seconds)"; return 0; fi
    if command -v python3 >/dev/null 2>&1; then python3 -c "import time; time.sleep($seconds)"; return 0; fi
    if command -v python >/dev/null 2>&1; then python -c "import time; time.sleep($seconds)"; return 0; fi
    local int_seconds=$(echo "$seconds" | awk '{print int($1+0.999)}')
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

check_pve_status() {
    local VMID="$1"
    local TYPE=""
    local RAW_STATUS=""

    if qm status "$VMID" &>/dev/null; then
        TYPE="QM 虚拟机"
        RAW_STATUS=$(qm status "$VMID" | awk '{print $2}')
    elif pct status "$VMID" &>/dev/null; then
        TYPE="LXC  容器"
        RAW_STATUS=$(pct status "$VMID" | awk '{print $2}')
    else
        printf "${gl_hong}[错误] ${gl_bai}%-8s ${gl_huang}%4s ${gl_bai}状态：${gl_hong}不存在${gl_bai}\n" "— 实例 —" "$VMID"
        return
    fi

    case "${RAW_STATUS}" in
        running)
            printf "${gl_lv}[成功] ${gl_bai}%-8s ${gl_huang}%4s ${gl_bai}状态：${gl_lv}正在运行${gl_bai}\n" "$TYPE" "$VMID"
        ;;
        stopped)
            printf "${gl_hong}[停止] ${gl_bai}%-8s ${gl_huang}%4s ${gl_bai}状态：${gl_hong}已关机${gl_bai}\n" "$TYPE" "$VMID"
        ;;
        suspended)
            printf "${gl_huang}[挂起] ${gl_bai}%-8s ${gl_huang}%4s ${gl_bai}状态：${gl_huang}已挂起${gl_bai}\n" "$TYPE" "$VMID"
        ;;
        *)
            printf "${gl_hong}[错误] ${gl_bai}%-8s ${gl_huang}%4s ${gl_bai}状态：${gl_hui}未知(%s)${gl_bai}\n" "$TYPE" "$VMID" "$RAW_STATUS"
        ;;
    esac
}

main() {
    clear
    if ! command -v qm &> /dev/null; then
	echo -e ""
	echo -e "${gl_huang}>>> Proxmox VE 实例状态查询${gl_bai}"
	echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
	log_error "未检测到Proxmox VE环境，请确保脚本在PVE节点上运行"
	echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
	break_end
	return 1
    fi
    echo -e "${gl_zi}>>> Proxmox VE 实例状态查询${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if [ $# -gt 0 ]; then
        for VMID in "$@"; do
            check_pve_status "$VMID"
        done
    else
        read -r -e -p "$(echo -e "${gl_bufan}请输入实例ID，多个ID用空格分隔 (${gl_hong}0${gl_bai}退出): ")" ID_LIST
        if [ "$ID_LIST" = "0" ]; then
            exit_script
        fi

        echo -e ""
        echo -e "${gl_huang}>>> LXC容器/VM虚拟机状态${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        for VMID in $ID_LIST; do
            check_pve_status "$VMID"
        done
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

main "$@"
