#!/bin/bash
sh_v="1.1.2"

gl_hui='\e[37m'
gl_hong='\033[31m'
gl_lv='\033[32m'
gl_huang='\033[33m'
gl_lan='\033[34m'
gl_bai='\033[0m'
gl_zi='\033[35m'
gl_bufan='\033[96m'

mobufan_sh_update() {
    local sh_v_new=$(curl -s https://gitee.com/meimolihan/cmdbox/raw/master/sh/istoreos-check.sh \
        | grep -o 'sh_v="[0-9.]*"' | cut -d '"' -f 2)

    if [ "$sh_v" != "$sh_v_new" ]; then
        echo -e "${gl_hong}发现新版本！${gl_bai}"
        
        local current_text="${gl_bai}当前版本号 ${gl_huang}v$sh_v"
        local latest_text="${gl_bai}最新版本号 ${gl_lv}v$sh_v_new"
        local input_text="${gl_bai}命令行输入${gl_huang} g up"
        local update_text="${gl_bai}更新至新版 ${gl_lv}v$sh_v_new"
        
        calc_display_width() {
            echo "$1" | sed 's/\x1B\[[0-9;]*[a-zA-Z]//g' | wc -m
        }
        
        local col1_width1=$(calc_display_width "$current_text")
        local col2_width1=$(calc_display_width "$latest_text")
        local col1_width2=$(calc_display_width "$input_text")
        local col2_width2=$(calc_display_width "$update_text")
        
        local max_col1_width=$(( col1_width1 > col1_width2 ? col1_width1 : col1_width2 ))
        local max_col2_width=$(( col2_width1 > col2_width2 ? col2_width1 : col2_width2 ))
        
        local pad_col1_1=$(( max_col1_width - col1_width1 ))
        local pad_col1_2=$(( max_col1_width - col1_width2 ))
        
        echo -e "${current_text}$(printf '%*s' $pad_col1_1)    ${latest_text}${gl_bai}"
        echo -e "${input_text}$(printf '%*s' $pad_col1_2)    ${update_text}${gl_bai}"
        echo -e "${gl_bufan}————————————————————————${gl_bai}"
    fi
}

show_system_info() {
    echo -e "${gl_lv}命令行输入${gl_huang}g${gl_lv}可快速启动脚本${gl_bai}"

    get_local_ip() {
        ifconfig br-lan | awk -F '[ :]+' '/inet addr/{print $4}'
    }

    get_cpu_usage() {
        top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{printf "%.2f%%", 100 - $8}' || echo "无法获取你想要的信息！"
    }

    get_uptime() {
        uptime_seconds=$(awk '{print int($1)}' /proc/uptime 2>/dev/null)
        if [ -n "$uptime_seconds" ]; then
            hours=$((uptime_seconds / 3600))
            minutes=$(( (uptime_seconds % 3600) / 60 ))
            echo "${hours}时 ${minutes}分"
        else
            echo "无法获取你想要的信息！"
        fi
    }

    get_default_gateway() {
        local gateway
        gateway=$(ip route show default 2>/dev/null | awk '/default/ {print $3}' | head -n1)
        if [ -n "$gateway" ]; then
            echo "$gateway"
        else
            echo "无法获取你想要的信息！"
        fi
    }

    get_disk_usage() {
        local disk_info
        disk_info=$(df -h / 2>/dev/null | awk 'NR==2 {print $3"/"$2 " ("$5")"}')
        if [ -n "$disk_info" ]; then
            echo "$disk_info"
        else
            echo "无法获取你想要的信息！"
        fi
    }

    clear
    echo -e ""
    echo -e "${gl_zi}>>> 系统信息${gl_bai}"
    echo -e "${gl_bufan}————————————————————————${gl_bai}"
    echo -e "${gl_bufan}主机名称 : ${gl_bai}$(cat /proc/sys/kernel/hostname 2>/dev/null || echo "Unknown")"
    echo -e "${gl_bufan}内核版本 : ${gl_bai}$(uname -r)"
    echo -e "${gl_bufan}————————————————————————${gl_bai}"
    echo -e "${gl_bufan}CPU 架构 : ${gl_bai}$(uname -m)"
    echo -e "${gl_bufan}CPU 占用 : ${gl_bai}$(get_cpu_usage)"
    echo -e "${gl_bufan}————————————————————————${gl_bai}"
    echo -e "${gl_bufan}IPV4内网 : ${gl_bai}$(get_local_ip)"
    echo -e "${gl_bufan}默认网关 : ${gl_bai}$(get_default_gateway)"
    echo -e "${gl_bufan}————————————————————————${gl_bai}"
    echo -e "${gl_bufan}磁盘占用 : ${gl_bai}$(get_disk_usage)"
    echo -e "${gl_bufan}运行时间 : ${gl_bai}$(get_uptime)"
    echo -e "${gl_bufan}————————————————————————${gl_bai}"
}

update_script() {
    echo -e "${gl_huang}正在更新脚本 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    
    local update_url="https://gitee.com/meimolihan/cmdbox/raw/master/sh/check.sh"
    
    if bash <(curl -sSL "$update_url"); then
        echo -e "${gl_lv}脚本更新成功！${gl_bai}"
        
        if alias g >/dev/null 2>&1; then
            source ~/.bashrc 2>/dev/null || source ~/.bash_profile 2>/dev/null || source ~/.zshrc 2>/dev/null
        fi
        
        echo -ne "${gl_bai}即将启动新版本脚本，倒计时: ${gl_huang}2${gl_bai} 秒" 
        sleep 1
        echo -ne "\r${gl_bai}即将启动新版本脚本，倒计时: ${gl_lv}1${gl_bai} 秒"
        sleep 1
        echo -e "\r${gl_lv}正在启动新版本脚本 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        
        if [ -f "/etc/profile.d/linux-check.sh" ]; then
            bash /etc/profile.d/linux-check.sh
        else
            echo -e "${gl_hong}错误：找不到 /etc/profile.d/linux-check.sh 文件${gl_bai}"
            return 1
        fi
        
        exit 0
        
    else
        echo -e "${gl_hong}脚本更新失败！请检查网络连接。${gl_bai}"
        return 1
    fi
}

main() {
    if [ "$1" = "up" ] || [ "$1" = "update" ]; then
        update_script
        return $?
    fi
    
    if [[ $- == *i* ]]; then
        if [ -z "$LINUX_CHECK_SHOWN" ]; then
            show_system_info
            export LINUX_CHECK_SHOWN=1
        fi
    else
        show_system_info
    fi

    if [[ $- != *i* ]]; then
        mobufan_sh_update
    fi
}

main "$@"