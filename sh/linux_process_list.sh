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
    export gl_cheng=$'\033[38;5;208m'
    export reset=$'\033[0m'
    export bold=$'\033[1m'
}
list_color_init

break_end() {
    echo -e "\n${gl_lv}操作完成${reset}"
    echo -en "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}${reset}"
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

format_bytes() {
    local bytes="$1"
    if [[ "$bytes" -eq 0 ]]; then
        echo "0B"
        return
    fi
    
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0
    local size="$bytes"
    
    while [[ "$size" -ge 1024 && "$unit" -lt 4 ]]; do
        size=$((size / 1024))
        ((unit++))
    done
    
    echo "${size}${units[$unit]}"
}

get_process_data() {
    local filter="${1:-}"
    
    if [[ -n "$filter" ]]; then
        ps aux | awk -v filter="$filter" '
            NR > 1 && tolower($0) ~ tolower(filter) {print}
        '
    else
        ps aux | tail -n +2
    fi
}

list_beautify_process() {
    local sort_by="${1:-cpu}"
    local filter="${2:-}"
    local temp_file=$(mktemp)
    
    local sort_cmd=""
    local sort_name=""
    case "$sort_by" in
        cpu|C|1)
            sort_cmd="sort -rn -k3"
            sort_name="CPU"
            ;;
        mem|m|M|2)
            sort_cmd="sort -rn -k4"
            sort_name="内存"
            ;;
        pid|p|P|3)
            sort_cmd="sort -n -k2"
            sort_name="PID"
            ;;
        vsz|v|V|4)
            sort_cmd="sort -rn -k5"
            sort_name="虚拟内存"
            ;;
        rss|r|R|5)
            sort_cmd="sort -rn -k6"
            sort_name="物理内存"
            ;;
        *)
            sort_cmd="sort -rn -k3"
            sort_name="CPU"
            ;;
    esac
    
    local process_data=$(get_process_data "$filter")
    
    if [[ -z "$process_data" ]]; then
        echo -e "${gl_huang}⚠ 未找到匹配的进程${reset}"
        return 1
    fi
    
    echo "$process_data" | eval "$sort_cmd" | awk -v red="$gl_hong" -v yellow="$gl_huang" \
        -v green="$gl_lv" -v blue="$gl_lan" -v cyan="$gl_bufan" \
        -v white="$gl_bai" -v gray="$gl_hui" -v orange="$gl_cheng" \
        -v reset="$reset" -v bold="$bold" '
    BEGIN {
        # 初始化阈值
        cpu_high = 80
        cpu_medium = 20
        mem_high = 50
        mem_medium = 10
    }
    {
        user = $1
        pid = $2
        cpu = $3
        mem = $4
        vsz = $5
        rss = $6 * 1024  # 转换为字节
        cmd = $11
        for (i = 12; i <= NF; i++) cmd = cmd " " $i
        
        # 截断命令
        if (length(cmd) > 60) cmd = substr(cmd, 1, 57) "..."
        
        # CPU 着色
        cpu_disp = sprintf("%5.1f", cpu)
        if (cpu >= cpu_high) {
            cpu_color = red bold
        } else if (cpu >= cpu_medium) {
            cpu_color = yellow
        } else {
            cpu_color = green
        }
        
        mem_disp = sprintf("%5.1f", mem)
        if (mem >= mem_high) {
            mem_color = red bold
        } else if (mem >= mem_medium) {
            mem_color = yellow
        } else {
            mem_color = blue
        }
        
        user_disp = sprintf("%-8s", user)
        pid_disp = sprintf("%6s", pid)
        
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n", 
               user_disp, pid_disp, 
               cpu_color cpu_disp reset, 
               mem_color mem_disp reset, 
               blue vsz reset, 
               cyan rss reset, 
               white cmd reset
    }' > "$temp_file"
    
    printf "%s%-8s\t%s\t%s\t%s\t%s\t%s\t%s%s\n" \
        "${gl_hui}" "用户" "PID" "CPU%" "MEM%" "虚拟内存" "物理内存" "命令" "${reset}"
    printf "%s%-8s\t%s\t%s\t%s\t%s\t%s\t%s%s\n" \
        "${gl_hui}" "--------" "-----" "----" "----" "----------" "----------" "----------------------" "${reset}"
    
    cat "$temp_file" | column_if_available
    
    local total_lines=$(wc -l < "$temp_file" | tr -d ' ')
    echo -e "\n${gl_lan}📊 统计: 共 ${bold}${total_lines}${reset}${gl_lan} 个进程${reset}"
    
    rm -f "$temp_file"
    return 0
}

show_system_summary() {
    echo -e "${gl_zi}${bold}📈 系统状态摘要${reset}"
    
    if [[ -f /proc/loadavg ]]; then
        read -r load1 load5 load15 _ < /proc/loadavg
        echo -e "${gl_bai}负载: ${gl_cheng}${load1}${reset}${gl_hui} (1分钟)  ${gl_cheng}${load5}${reset}${gl_hui} (5分钟)  ${gl_cheng}${load15}${reset}${gl_hui} (15分钟)${reset}"
    fi
    
    if command -v free &> /dev/null; then
        local mem_info=$(free -h | awk '/^Mem:/ {print $3"/"$2}')
        echo -e "${gl_bai}内存: ${gl_lv}${mem_info}${reset}"
    fi
    
    local total_procs=$(ps aux | wc -l)
    total_procs=$((total_procs - 1))
    echo -e "${gl_bai}进程: ${gl_bufan}${total_procs}${reset}"
    
    echo -e "${gl_bufan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
}

interactive_mode() {
    local refresh_interval="${1:-3}"
    
    while true; do
        clear
        show_system_summary
        list_beautify_process "cpu" ""
        
        echo -e "\n${gl_hui}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
        echo -e "${gl_bufan}🔄 实时模式 | 刷新间隔: ${refresh_interval}秒 | 按 Ctrl+C 退出${reset}"
        sleep "$refresh_interval"
    done
}

show_help() {
    cat << EOF
${gl_zi}${bold}进程管理工具 - 使用说明${reset}

${gl_bai}用法:${reset}
  $0 [选项] [搜索关键词]

${gl_bai}排序选项:${reset}
  cpu, 1    按 CPU 占用排序（默认）
  mem, 2    按内存占用排序
  pid, 3    按 PID 排序
  vsz, 4    按虚拟内存排序
  rss, 5    按物理内存排序

${gl_bai}其他选项:${reset}
  -h, --help        显示此帮助信息
  -i, --interactive 交互式实时监控模式
  -r, --refresh N   设置刷新间隔（秒，默认3秒，配合-i使用）
  -t, --top N       显示前 N 个进程

${gl_bai}示例:${reset}
  $0                    显示所有进程（按CPU排序）
  $0 nginx              搜索并显示包含 nginx 的进程
  $0 mem sshd           按内存排序显示 sshd 相关进程
  $0 -t 10              显示 CPU 占用最高的 10 个进程
  $0 -i                 进入交互式实时监控模式
  $0 -i -r 5            实时监控，每5秒刷新

${gl_bai}快捷键:${reset}
  在交互模式中按 Ctrl+C 退出

EOF
}

list_beautify_all() {
    clear
    
    local sort_by="cpu"
    local filter=""
    local interactive=false
    local refresh=3
    local top_n=0
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -i|--interactive)
                interactive=true
                shift
                ;;
            -r|--refresh)
                refresh="$2"
                shift 2
                ;;
            -t|--top)
                top_n="$2"
                shift 2
                ;;
            cpu|mem|pid|vsz|rss|1|2|3|4|5)
                sort_by="$1"
                shift
                ;;
            *)
                if [[ -z "$filter" ]]; then
                    filter="$1"
                else
                    filter="$filter $1"
                fi
                shift
                ;;
        esac
    done
    
    if [[ "$interactive" == true ]]; then
        interactive_mode "$refresh"
        return
    fi
    
    show_system_summary
    
    local sort_name=""
    case "$sort_by" in
        cpu|1) sort_name="CPU 占用" ;;
        mem|2) sort_name="内存占用" ;;
        pid|3) sort_name="PID" ;;
        vsz|4) sort_name="虚拟内存" ;;
        rss|5) sort_name="物理内存" ;;
        *) sort_name="CPU 占用" ;;
    esac
    
    echo -e "${gl_zi}${bold}>>> 进程列表 (按 ${sort_name} 排序)${reset}"
    if [[ -n "$filter" ]]; then
        echo -e "${gl_huang}🔍 过滤: ${gl_cheng}${bold}${filter}${reset}"
    fi
    
    if [[ $top_n -gt 0 ]]; then
        echo -e "${gl_bufan}📌 显示前 ${top_n} 个进程${reset}"
    fi
    
    echo -e "${gl_bufan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
    
    if [[ $top_n -gt 0 ]]; then
        list_beautify_process "$sort_by" "$filter" | head -n $((top_n + 2))
    else
        list_beautify_process "$sort_by" "$filter"
    fi
    
    echo -e "${gl_bufan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
    break_end
}

list_beautify_all "$@"
