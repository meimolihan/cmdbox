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
    echo -e "\n${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    read -r -n 1 -s -r -p ""
    echo ""
    clear
    exit 0
}

filter_real_vga() {
    lspci -k 2>/dev/null | awk '
        /VGA compatible controller|3D controller/ {
            vga_line = $0
            getline
            sub_line = $0
            getline
            driver_line = $0
            print vga_line
            print sub_line
            print driver_line
        }
    '
}

get_opengl_renderer() {
    if command -v glxinfo &> /dev/null; then
        opengl_info=$(glxinfo -B 2>/dev/null | grep "OpenGL renderer" | sed 's/OpenGL renderer string: //')
        if [ -n "$opengl_info" ]; then
            echo "$opengl_info"
        else
            echo "无法获取 OpenGL 信息"
        fi
    else
        echo "未安装 glxinfo (mesa-utils)"
    fi
}

beautify_vga_info() {
    clear
    echo -e "${gl_zi}>>> Linux 系统显卡信息详情（中文版）${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    vga_data=$(filter_real_vga)

    if [ -z "$vga_data" ]; then
        echo -e "${gl_hong}[错误] 未检测到真实显卡设备${reset}"
        echo -e "${gl_bai}手动验证：lspci -k | grep -iE \"VGA compatible controller|3D controller\"${reset}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        echo -e "\n${gl_huang}>>> OpenGL 渲染信息（当前使用）${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        opengl_renderer=$(get_opengl_renderer)
        echo -e "${gl_hui}[OpenGL 渲染器]：${reset} ${gl_lv}$opengl_renderer${reset}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        break_end
    fi

    last_driver_status=""

    echo "$vga_data" | while read -r line1 && read -r line2 && read -r line3; do
        line1=$(echo "$line1" | sed 's/^[ \t]*//; s/[ \t]*$//')
        line2=$(echo "$line2" | sed 's/^[ \t]*//; s/[ \t]*$//')
        line3=$(echo "$line3" | sed 's/^[ \t]*//; s/[ \t]*$//')

        [ -z "$line1" ] && continue

        bus_id=$(echo "$line1" | awk '{print $1}')
        [ -z "$bus_id" ] && bus_id="未知总线号"

        vga_model=$(echo "$line1" | sed -E 's/^[0-9a-f]{2}:[0-9a-f]{2}\.[0-9] //' | sed -E 's/ \(rev [0-9a-f]+\)//' | sed -E 's/VGA compatible controller: //' | sed -E 's/3D controller: //')
        [ -z "$vga_model" ] && vga_model="未知显卡型号"
        [ ${#vga_model} -gt 60 ] && vga_model="${vga_model:0:57}..."

        subsystem=$(echo "$line2" | sed -E 's/^[ \t]+Subsystem: //' | sed -E 's/^[ \t]+//')
        [ -z "$subsystem" ] && subsystem="未知厂商信息"

        driver=$(echo "$line3" | grep -oP 'Kernel driver in use: \K\S+' || echo "")
        if [ -z "$driver" ]; then
            driver_display="${gl_hong}未加载驱动${reset}"
            driver_status="not_loaded"
        else
            driver_display="${gl_lv}$driver${reset}"
            driver_status="loaded"
        fi

        printf "%s%-10s%s%s\n" "${gl_hui}[总 线 号]：" "${reset}" "${gl_lan}$bus_id${reset}"
        printf "%s%-10s%s%s\n" "${gl_hui}[显卡型号]：" "${reset}" "${gl_huang}$vga_model${reset}"
        printf "%s%-10s%s%s\n" "${gl_hui}[厂商信息]：" "${reset}" "${gl_bai}$subsystem${reset}"
        printf "%s%-10s%s%s\n" "${gl_hui}[内核驱动]：" "${reset}" "$driver_display"

        if [ "$driver_status" = "loaded" ]; then
            echo -e "\n${gl_lv}[状态] 显卡驱动已正常加载，可正常使用${reset}"
        else
            if echo "$vga_model" | grep -qiE "AMD|Radeon|ATI"; then
                recommend="sudo modprobe amdgpu"
            elif echo "$vga_model" | grep -qiE "Intel|UHD|Iris"; then
                recommend="sudo modprobe i915"
            elif echo "$vga_model" | grep -qi "NVIDIA"; then
                recommend="sudo modprobe nvidia"
            else
                recommend="sudo modprobe amdgpu 或 sudo modprobe i915"
            fi
            echo -e "\n${gl_hong}[状态] 显卡驱动未加载，可能影响显示功能${reset}"
            echo -e "${gl_bai}建议执行：$recommend${reset}"
        fi

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        last_driver_status="$driver_status"
    done

    echo -e "\n${gl_huang}>>> OpenGL 渲染信息（当前使用）${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    opengl_renderer=$(get_opengl_renderer)
    
    if echo "$opengl_renderer" | grep -qi "llvmpipe"; then
        echo -e "${gl_hui}[OpenGL 渲染器]：${reset} ${gl_hong}$opengl_renderer${reset}"
        echo -e "${gl_hong}[注意] 当前使用软件渲染(llvmpipe)，3D性能较差，建议安装硬件驱动${reset}"
    elif echo "$opengl_renderer" | grep -qi "AMD\|Radeon\|Intel\|NVIDIA"; then
        echo -e "${gl_hui}[OpenGL 渲染器]：${reset} ${gl_lv}$opengl_renderer${reset}"
        echo -e "${gl_lv}[正常] 已启用硬件加速渲染${reset}"
    else
        echo -e "${gl_hui}[OpenGL 渲染器]：${reset} ${gl_huang}$opengl_renderer${reset}"
    fi
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    if [ "${last_driver_status}" = "loaded" ] && echo "$opengl_renderer" | grep -qi "llvmpipe"; then
        echo -e "\n${gl_huang}[提示] 内核驱动已加载，但 OpenGL 使用软件渲染${reset}"
        echo -e "${gl_bai}可能原因：缺少用户态驱动(mesa)或权限问题${reset}"
        echo -e "${gl_bai}解决方案：${reset}"
        echo -e "  ${gl_lv}• AMD  显卡：${reset}sudo apt install mesa-utils mesa-vulkan-drivers"
        echo -e "  ${gl_lv}• Intel显卡：${reset}sudo apt install mesa-utils mesa-vulkan-drivers"
        echo -e "  ${gl_lv}• NVIDIA显卡：${reset}sudo apt install nvidia-driver-xxx"
    fi
}

beautify_vga_info
break_end
