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

translate_vga_info() {
    local info="$1"
    info=${info//"VGA compatible controller"/"VGA兼容控制器"}
    info=${info//"Intel Corporation"/"英特尔公司"}
    info=${info//"Advanced Micro Devices, Inc."/"超微半导体公司"}
    info=${info//"AMD"/"AMD"}
    info=${info//"NVIDIA Corporation"/"英伟达公司"}
    info=${info//"Graphics"/"显卡"}
    info=${info//"UHD Graphics"/"超高清显卡"}
    info=${info//"HD Graphics"/"高清显卡"}
    info=${info//"Integrated Graphics Controller"/"集成显卡控制器"}
    info=${info//"Display controller"/"显示控制器"}
    info=${info//"3D controller"/"3D控制器"}
    info=${info//"rev"/"修订版本"}
    echo "$info"
}

list_beautify_vga() {
    if ! command -v lspci &> /dev/null; then
        echo -e "${gl_hong}[错误] 未检测到 lspci 命令${reset}"
        return 1
    fi
    
    local vga_info=$(lspci | grep -i vga)
    
    if [ -z "$vga_info" ]; then
        echo -e "${gl_huang}未找到任何 VGA 设备${reset}"
        return 0
    fi
    
    {
        printf "%s%s\t%s%s\n" "$gl_hui" "设备地址" "VGA控制器信息" "$reset"
        printf "%s%s\t%s%s\n" "$gl_hui" "--------" "----------------" "$reset"
        
        echo "$vga_info" | while IFS= read -r line; do
            local addr=$(echo "$line" | awk '{print $1}')
            local info=$(echo "$line" | cut -d' ' -f2-)
            local info_cn=$(translate_vga_info "$info")
            
            echo -e "${gl_lan}${addr}${reset}\t${gl_bufan}${info_cn}${reset}"
        done
    } | column_if_available
}

list_beautify_all() {
    clear
    
    if ! command -v qm &> /dev/null; then
	    echo -e ""
	    echo -e "${gl_huang}>>> PCI VGA 兼容控制器列表${gl_bai}"
	    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
	    log_error "未检测到Proxmox VE环境，请确保脚本在PVE节点上运行"
	    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
	    break_end
	    return 1
    fi
    
    echo -e "${gl_zi}>>> PCI VGA 兼容控制器列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_vga
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all
