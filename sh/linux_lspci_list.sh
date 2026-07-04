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

column_if_available() {
    if command -v column &> /dev/null; then
        column -t -s $'\t'
    else
        cat
    fi
}

translate_device_info() {
    local info="$1"
    info=${info//"Intel Corporation"/"英特尔公司"}
    info=${info//"Advanced Micro Devices, Inc."/"超微半导体公司"}
    info=${info//"AMD"/"AMD"}
    info=${info//"NVIDIA Corporation"/"英伟达公司"}
    info=${info//"Realtek Semiconductor Co., Ltd."/"瑞昱半导体公司"}
    info=${info//"Qualcomm"/"高通公司"}
    info=${info//"Broadcom Inc."/"博通公司"}
    info=${info//"Marvell Technology Group Ltd."/"美满电子科技公司"}
    info=${info//"VMware"/"威睿"}
    info=${info//"Red Hat, Inc."/"红帽公司"}
    info=${info//"Silicon Motion, Inc."/"慧荣科技公司"}
    info=${info//"Host bridge"/"主机桥接器"}
    info=${info//"DRAM Registers"/"内存寄存器"}
    info=${info//"UHD 显卡"/"超高清显卡"}
    info=${info//"Graphics"/"显卡"}
    info=${info//"Ethernet Controller"/"以太网控制器"}
    info=${info//"Ethernet controller"/"以太网控制器"}
    info=${info//"Controller"/"控制器"}
    info=${info//"Network"/"网络"}
    info=${info//"Adapter"/"适配器"}
    info=${info//"Bridge"/"桥接器"}
    info=${info//"Root Port"/"根端口"}
    info=${info//"Family"/"系列"}
    info=${info//"Rev"/"修订版"}
    info=${info//"Chipset"/"芯片组"}
    info=${info//"Processor"/"处理器"}
    info=${info//"Express"/"高速"}
    info=${info//"SATA"/"SATA"}
    info=${info//"PCI"/"PCI"}
    info=${info//"USB"/"USB"}
    info=${info//"HDMI"/"高清多媒体接口"}
    info=${info//"DisplayPort"/"显示端口"}
    info=${info//"RAM memory"/"内存"}
    info=${info//"Shared SRAM"/"共享静态随机存取存储器"}
    info=${info//"ISA bridge"/"ISA桥接器"}
    info=${info//"eSPI Controller"/"增强型串行外设接口控制器"}
    info=${info//"High Definition Audio controller"/"高清音频控制器"}
    info=${info//"SMBus"/"系统管理总线"}
    info=${info//"Serial bus controller"/"串行总线控制器"}
    info=${info//"SPI (flash) controller"/"SPI闪存控制器"}
    info=${info//"DRAM-less"/"无内存"}
    info=${info//"Host"/"主机"}
    info=${info//"Registers"/"寄存器"}
    info=${info//"PCH"/"平台控制中心"}
    info=${info//"Root"/"根"}
    info=${info//"Port"/"端口"}
    info=${info//"Shared"/"共享"}
    echo "$info"
}

list_beautify_linux_lspci() {
    {
        printf "%s%s\t%s\t%s%s\n" "$gl_hui" "总线号" "设备类型" "设备描述" "$reset"
        printf "%s%s\t%s\t%s%s\n" "$gl_hui" "-------" "----------------" "-------------------------------------------" "$reset"
        
        data=$(lspci 2>/dev/null)
        
        if [ -z "$data" ]; then
            printf "%s%s\t%s\t%s%s\n" "$gl_hong" "(错误)" "(错误)" "无法执行 lspci 命令" "$reset"
        else
            total_devices=$(echo "$data" | wc -l)
            
            echo "$data" | while IFS= read -r line; do
                bus_id=$(echo "$line" | cut -d' ' -f1)
                device_desc=$(echo "$line" | cut -d' ' -f2-)
                
                device_type=$(echo "$device_desc" | cut -d: -f1)
                device_detail=$(echo "$device_desc" | cut -d: -f2- | sed 's/^ //')
                device_detail_cn=$(translate_device_info "$device_detail")
                
                if [ -z "$device_detail" ]; then
                    device_detail_cn="$device_desc"
                    device_type="未知"
                fi
                
                case "$device_type" in
                    "Host bridge")
                        type_color=$gl_lan
                        type_display="${type_color}主机桥$reset"
                        ;;
                    "VGA compatible controller")
                        type_color=$gl_zi
                        type_display="${type_color}VGA控制器$reset"
                        ;;
                    "Ethernet controller")
                        type_color=$gl_lv
                        type_display="${type_color}以太网卡$reset"
                        ;;
                    "Network controller")
                        type_color=$gl_bufan
                        type_display="${type_color}网络控制器$reset"
                        ;;
                    "USB controller")
                        type_color=$gl_huang
                        type_display="${type_color}USB控制器$reset"
                        ;;
                    "SATA controller")
                        type_color=$gl_hong
                        type_display="${type_color}SATA控制器$reset"
                        ;;
                    "Audio device")
                        type_color=$gl_bufan
                        type_display="${type_color}音频设备$reset"
                        ;;
                    "PCI bridge")
                        type_color=$gl_hui
                        type_display="${type_color}PCI桥$reset"
                        ;;
                    "Non-Volatile memory controller")
                        type_color=$gl_hong
                        type_display="${type_color}NVMe控制器$reset"
                        ;;
                    "SCSI storage controller")
                        type_color=$gl_zi
                        type_display="${type_color}SCSI控制器$reset"
                        ;;
                    "SMBus")
                        type_color=$gl_hui
                        type_display="${type_color}系统管理总线$reset"
                        ;;
                    "Communication controller")
                        type_color=$gl_bufan
                        type_display="${type_color}通信控制器$reset"
                        ;;
                    "RAID bus controller")
                        type_color=$gl_hong
                        type_display="${type_color}RAID控制器$reset"
                        ;;
                    "Serial controller")
                        type_color=$gl_huang
                        type_display="${type_color}串行控制器$reset"
                        ;;
                    "FireWire (IEEE 1394)")
                        type_color=$gl_huang
                        type_display="${type_color}火线控制器$reset"
                        ;;
                    "RAM memory")
                        type_color=$gl_huang
                        type_display="${type_color}内存$reset"
                        ;;
                    "ISA bridge")
                        type_color=$gl_hui
                        type_display="${type_color}ISA桥$reset"
                        ;;
                    "Serial bus controller")
                        type_color=$gl_bufan
                        type_display="${type_color}串行总线控制器$reset"
                        ;;
                    *)
                        type_color=$gl_huang
                        translated_type=$(translate_device_info "$device_type")
                        type_display="${type_color}${translated_type}$reset"
                        ;;
                esac
                
                if [ ${#device_detail_cn} -gt 55 ]; then
                    device_detail_cn="${device_detail_cn:0:52}..."
                fi
                
                printf "%s%s%s\t%s\t%s%s%s\n" \
                    "$gl_lan" "$bus_id" "$reset" \
                    "$type_display" \
                    "$gl_bufan" "$device_detail_cn" "$reset"
            done
            
            printf "\n"
            printf "%sPCI设备%s%s%s个%s\n" "$gl_hui" "$gl_lv" "$total_devices" "$gl_hui" "$reset"
        fi
        
    } | column_if_available
}

list_beautify_all() {
    clear
    echo -e "${gl_zi}>>> Linux系统PCI设备列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————————————————————————————————${gl_bai}"
    list_beautify_linux_lspci
    echo -e "${gl_bufan}————————————————————————————————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all