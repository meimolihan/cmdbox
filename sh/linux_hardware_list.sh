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
    export gl_reset=$'\033[0m'
}
list_color_init

break_end() {
    echo -e "${gl_lv}操作完成${gl_reset}"
    echo -e "${gl_reset}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_reset}\c"
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

install() {
    [[ $# -eq 0 ]] && return 1
    local need_install=()
    
    for pkg in "$@"; do
        if command -v "$pkg" &>/dev/null; then
            echo -e "${gl_lv}✓ $pkg 已安装${gl_reset}"
        else
            need_install+=("$pkg")
        fi
    done
    
    if [ ${#need_install[@]} -eq 0 ]; then
        return 0
    fi
    
    echo -e "\n${gl_huang}需要安装以下依赖: ${gl_bai}${need_install[*]}${gl_reset}"
    
    for pkg in "${need_install[@]}"; do
        echo -e "\n${gl_huang}正在安装: ${gl_bai}$pkg${gl_reset}"
        
        if command -v apt &>/dev/null; then
            apt update -y >/dev/null 2>&1 && apt install -y "$pkg" >/dev/null 2>&1
        elif command -v dnf &>/dev/null; then
            dnf install -y "$pkg" >/dev/null 2>&1
        elif command -v yum &>/dev/null; then
            yum install -y "$pkg" >/dev/null 2>&1
        elif command -v pacman &>/dev/null; then
            pacman -S --noconfirm "$pkg" >/dev/null 2>&1
        elif command -v zypper &>/dev/null; then
            zypper install -y "$pkg" >/dev/null 2>&1
        elif command -v apk &>/dev/null; then
            apk add "$pkg" >/dev/null 2>&1
        else
            echo -e "${gl_hong}错误：无法检测到包管理器，请手动安装 $pkg${gl_reset}"
            return 1
        fi
        
        if command -v "$pkg" &>/dev/null; then
            echo -e "${gl_lv}✓ $pkg 安装成功${gl_reset}"
        else
            echo -e "${gl_hong}✗ $pkg 安装失败，请手动安装${gl_reset}"
            return 1
        fi
    done
}

translate_hw_class() {
    case "$1" in
        "system") echo "系统" ;;
        "processor") echo "处理器" ;;
        "cpu") echo "CPU" ;;
        "memory") echo "内存" ;;
        "storage") echo "存储" ;;
        "disk") echo "磁盘" ;;
        "volume") echo "卷" ;;
        "bridge") echo "桥接器" ;;
        "display") echo "显示" ;;
        "graphics") echo "显卡" ;;
        "network") echo "网络" ;;
        "bus") echo "总线" ;;
        "usb") echo "USB" ;;
        "input") echo "输入" ;;
        "generic") echo "通用" ;;
        "scsi") echo "SCSI" ;;
        "communication") echo "通信" ;;
        "multimedia") echo "多媒体" ;;
        *) echo "$1" ;;
    esac
}

translate_device_info() {
    local info="$1"
    if [[ "$info" =~ ^Project-Id-Version ]] || [[ "$info" =~ ^PO-Revision-Date ]]; then
        echo "内存信息异常"
        return
    fi
    
    info=${info//"OptiPlex"/"OptiPlex"}
    info=${info//"Core(TM)"/"酷睿"}
    info=${info//"CPU"/"处理器"}
    info=${info//"@"/"@"}
    info=${info//"GHz"/"GHz"}
    info=${info//"Gen Core Processor"/"代酷睿处理器"}
    info=${info//"Host Bridge/DRAM Registers"/"主机桥接器/内存寄存器"}
    info=${info//"UHD Graphics"/"超高清显卡"}
    info=${info//"Xeon"/"至强"}
    info=${info//"PCH"/"平台控制中心"}
    info=${info//"USB 3.1 xHCI Host Controller"/"USB 3.1 xHCI主机控制器"}
    info=${info//"xHCI Host Controller"/"xHCI主机控制器"}
    info=${info//"Serial IO I2C Controller"/"串行IO I2C控制器"}
    info=${info//"HECI Controller"/"HECI控制器"}
    info=${info//"SATA AHCI Controller"/"SATA AHCI控制器"}
    info=${info//"PCI Express Root Port"/"PCI Express根端口"}
    info=${info//"PCI Express-to-PCI Bridge"/"PCI Express转PCI桥接器"}
    info=${info//"Ethernet Controller"/"以太网控制器"}
    info=${info//"Ethernet Connection"/"以太网连接"}
    info=${info//"Chipset LPC/eSPI Controller"/"芯片组 LPC/eSPI控制器"}
    info=${info//"SMBus Controller"/"SMBus控制器"}
    info=${info//"SPI Controller"/"SPI控制器"}
    info=${info//"Sleep Button"/"睡眠按钮"}
    info=${info//"Power Button"/"电源按钮"}
    info=${info//"Video Bus"/"视频总线"}
    info=${info//"DIMM DDR4 Synchronous"/"DDR4同步内存"}
    info=${info//"MHz"/"MHz"}
    info=${info//"ns"/"纳秒"}
    info=${info//"L1 cache"/"L1缓存"}
    info=${info//"L2 cache"/"L2缓存"}
    info=${info//"L3 cache"/"L3缓存"}
    info=${info//"System Memory"/"系统内存"}
    info=${info//"BIOS"/"BIOS"}
    info=${info//"NTFS volume"/"NTFS卷"}
    info=${info//"FAT volume"/"FAT卷"}
    info=${info//"EXT4 volume"/"EXT4卷"}
    info=${info//"NVMe disk"/"NVMe磁盘"}
    info=${info//"USB Receiver"/"USB接收器"}
    info=${info//"Logitech"/"罗技"}
    info=${info//"Gaming Mouse"/"游戏鼠标"}
    info=${info//"Keyboard"/"键盘"}
    info=${info//"TOSHIBA"/"东芝"}
    info=${info//"WDC"/"西部数据"}
    info=${info//"HDMI Audio"/"HDMI音频"}
    info=${info//"Headphone Mic"/"耳机麦克风"}
    info=${info//"Line Out"/"线路输出"}
    info=${info//"Dell"/"戴尔"}
    info=${info//"AIO WMI hotkeys"/"一体机WMI热键"}
    info=${info//"WMI hotkeys"/"WMI热键"}
    echo "$info"
}

get_class_color() {
    case "$1" in
        "系统") echo "$gl_zi" ;;
        "处理器"|"CPU") echo "$gl_lv" ;;
        "内存") echo "$gl_huang" ;;
        "存储"|"磁盘"|"SCSI") echo "$gl_hong" ;;
        "网络") echo "$gl_bufan" ;;
        "显示"|"显卡") echo "$gl_zi" ;;
        "总线"|"桥接器") echo "$gl_hui" ;;
        "输入") echo "$gl_bai" ;;
        "卷") echo "$gl_bufan" ;;
        "通用") echo "$gl_hui" ;;
        "USB") echo "$gl_huang" ;;
        "通信") echo "$gl_bufan" ;;
        "多媒体") echo "$gl_bufan" ;;
        *) echo "$gl_bai" ;;
    esac
}

list_beautify_lshw() {
    if ! command -v lshw &> /dev/null; then
        echo -e "${gl_hong}[错误] 未检测到 lshw 命令${gl_reset}"
        echo -e "${gl_huang}正在尝试自动安装...${gl_reset}"
        install lshw
        if ! command -v lshw &> /dev/null; then
            echo -e "${gl_hong}[错误] 安装失败，请手动安装 lshw${gl_reset}"
            return 1
        fi
    fi
    
    echo -e "${gl_zi}>>> 系统硬件设备列表${gl_reset}"
    echo -e "${gl_bufan}————————————————————————————————————————————————————————————————————————————${gl_reset}"
    
    {
        printf "${gl_hui}%-25s\t%-12s\t%-18s\t%s${gl_reset}\n" "总线地址" "类型" "名称" "描述"
        printf "${gl_hui}%-25s\t%-12s\t%-18s\t%s${gl_reset}\n" "--------" "----" "----" "----"
        
        local total=0
        while IFS= read -r line; do
            [[ -z "$line" || "$line" =~ ^H/W ]] && continue
            
            if [[ "$line" =~ Project-Id-Version ]] || [[ "$line" =~ PO-Revision-Date ]]; then
                continue
            fi
            
            local bus_addr=$(echo "$line" | awk '{print $1}')
            local hw_class=$(echo "$line" | awk '{print $2}')
            
            local name_desc=$(echo "$line" | awk '{for(i=3;i<=NF;i++) printf "%s%s", $i, (i<NF?" ":"")}')
            
            local device_name=""
            local device_desc=""
            
            if [[ "$name_desc" =~ ^([^[:space:]]+)[[:space:]]+(.*)$ ]]; then
                device_name="${BASH_REMATCH[1]}"
                device_desc="${BASH_REMATCH[2]}"
            else
                device_name="-"
                device_desc="$name_desc"
            fi
            
            [ -z "$bus_addr" ] && continue
            
            local class_cn=$(translate_hw_class "$hw_class")
            local class_color=$(get_class_color "$class_cn")
            local device_desc_cn=$(translate_device_info "$device_desc")
            
            if [ ${#device_desc_cn} -gt 55 ]; then
                device_desc_cn="${device_desc_cn:0:52}..."
            fi
            
            if [ -z "$device_name" ] || [ "$device_name" = "-" ] || [[ "$device_name" =~ ^(Project-Id-Version|PO-Revision-Date) ]]; then
                device_name="-"
            fi
            
            printf "${gl_lan}%-25s${gl_reset}\t${class_color}%-12s${gl_reset}\t${gl_huang}%-18s${gl_reset}\t${gl_bufan}%s${gl_reset}\n" \
                "$bus_addr" "$class_cn" "$device_name" "$device_desc_cn"
            
            total=$((total + 1))
        done < <(lshw -short 2>/dev/null | tail -n +3 | head -n 70)
        
        echo ""
        echo -e "${gl_hui}硬件设备 ${gl_lv}${total}${gl_hui} 个${gl_reset}"

    } | column -t -s $'\t'
    

    echo -e "${gl_bufan}————————————————————————————————————————————————————————————————————————————${gl_reset}"
    break_end
}

list_beautify_all() {
    root_use || return 1
    list_beautify_lshw
}

list_beautify_all
