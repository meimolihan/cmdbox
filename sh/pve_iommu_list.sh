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

translate_dmar_iommu() {
    local line="$1"
    line=${line//"ACPI: DMAR"/"ACPI: DMAR"}
    line=${line//"Reserving DMAR table memory"/"保留DMAR表内存"}
    line=${line//"Host address width"/"主机地址宽度"}
    line=${line//"DRHD base"/"DRHD基地址"}
    line=${line//"flags"/"标志"}
    line=${line//"reg_base_addr"/"寄存器基地址"}
    line=${line//"ver"/"版本"}
    line=${line//"cap"/"能力"}
    line=${line//"ecap"/"扩展能力"}
    line=${line//"RMRR base"/"RMRR基地址"}
    line=${line//"end"/"结束地址"}
    line=${line//"DMAR-IR:"/"DMAR-中断重映射:"}
    line=${line//"IOAPIC id"/"IOAPIC编号"}
    line=${line//"under DRHD base"/"位于DRHD基地址"}
    line=${line//"HPET id"/"HPET编号"}
    line=${line//"Queued invalidation will be enabled to support"/"队列失效将启用以支持"}
    line=${line//"x2apic and Intr-remapping"/"x2apic和中断重映射"}
    line=${line//"Enabled IRQ remapping in"/"已启用中断重映射模式"}
    line=${line//"mode"/"模式"}
    line=${line//"Skip IOMMU disabling for graphics"/"跳过为显卡禁用IOMMU"}
    line=${line//"No ATSR found"/"未找到ATSR"}
    line=${line//"No SATC found"/"未找到SATC"}
    line=${line//"Using Queued invalidation"/"使用队列失效"}
    line=${line//"Intel(R) Virtualization Technology for Directed I/O"/"英特尔定向I/O虚拟化技术"}
    line=${line//"DMAR:"/"DMAR:"}
    line=${line//"IOMMU"/"IOMMU"}
    line=${line//"enabled"/"已启用"}
    line=${line//"disabled"/"已禁用"}
    line=${line//"will be"/"将"}
    line=${line//"to support"/"以支持"}
    line=${line//"found"/"找到"}
    line=${line//"Using"/"使用"}
    line=${line//"Skip"/"跳过"}
    line=${line//"graphics"/"显卡"}
    line=${line//"dmar0"/"DMAR0"}
    line=${line//"dmar1"/"DMAR1"}
    line=${line//"IRQ remapping"/"中断重映射"}
    line=${line//"x2apic"/"x2apic"}
    line=${line//"Remapping"/"重映射"}
    line=${line//"Interrupt"/"中断"}
    line=${line//"Queued invalidation"/"队列失效"}
    echo "$line"
}

list_beautify_dmar_iommu() {
    if ! command -v dmesg &> /dev/null; then
        echo -e "${gl_hong}[错误] 未检测到 dmesg 命令${reset}"
        return 1
    fi
    
    local dmar_info=$(dmesg 2>/dev/null | grep -E "DMAR|IOMMU")
    
    if [ -z "$dmar_info" ]; then
        echo -e "${gl_huang}未找到任何 DMAR/IOMMU 相关信息${reset}"
        return 0
    fi
    
    local line_num=0
    
    {
        printf "%s%s\t%s\t%s%s\n" "$gl_hui" "序号" "时间戳" "内核信息" "$reset"
        printf "%s%s\t%s\t%s%s\n" "$gl_hui" "----" "--------" "--------" "$reset"
        
        echo "$dmar_info" | while IFS= read -r line; do
            line_num=$((line_num + 1))
            local timestamp=$(echo "$line" | grep -oP '\[\s*\K[0-9.]+' | head -1)
            local message=$(echo "$line" | sed -E 's/^.*[0-9]+\] //')
            local message_cn=$(translate_dmar_iommu "$message")
            
            if [[ "$message" == *"error"* ]] || [[ "$message" == *"fault"* ]] || [[ "$message" == *"fail"* ]]; then
                echo -e "${gl_hong}${line_num}${reset}\t${gl_huang}${timestamp}${reset}\t${gl_hong}${message_cn}${reset}"
            elif [[ "$message" == *"Enabled"* ]] || [[ "$message" == *"enabled"* ]] || [[ "$message" == *"Using"* ]]; then
                echo -e "${gl_lv}${line_num}${reset}\t${gl_huang}${timestamp}${reset}\t${gl_lv}${message_cn}${reset}"
            else
                echo -e "${gl_bai}${line_num}${reset}\t${gl_huang}${timestamp}${reset}\t${gl_bufan}${message_cn}${reset}"
            fi
        done
    } | column_if_available
}

list_beautify_all() {
    clear
    
    if ! command -v qm &> /dev/null; then
        echo -e ""
        echo -e "${gl_zi}>>> DMAR/IOMMU 内核信息列表${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        log_error "未检测到Proxmox VE环境，请确保脚本在PVE节点上运行"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return 1
    fi
    
    echo -e "${gl_zi}>>> DMAR/IOMMU 内核信息列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————————————————————————————${gl_bai}"
    list_beautify_dmar_iommu
    echo -e "${gl_bufan}————————————————————————————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all
