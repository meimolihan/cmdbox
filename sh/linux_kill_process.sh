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

kill_by_pid() {
    local pid="$1"
    if ! kill -0 "$pid" 2>/dev/null; then
        echo -e "${gl_hong}错误: 进程 PID ${pid} 不存在${reset}"
        return 1
    fi

    local info
    info=$(ps -p "$pid" -o user=,pid=,cpu=,mem=,cmd= --no-headers 2>/dev/null)
    local user cmd cpu mem
    user=$(echo "$info" | awk '{print $1}')
    cpu=$(echo "$info" | awk '{print $3}')
    mem=$(echo "$info" | awk '{print $4}')
    cmd=$(echo "$info" | awk '{for(i=5;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/ $//')
    [ -z "$cmd" ] && cmd="(未知)"

    echo -e "${gl_zi}>>> 进程信息${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_lv}用户:${reset}  ${gl_bai}${user}${reset}"
    echo -e "${gl_lv}PID:${reset}  ${gl_huang}${pid}${reset}"
    echo -e "${gl_lv}CPU:${reset}  ${gl_bai}${cpu}%${reset}"
    echo -e "${gl_lv}内存:${reset} ${gl_bai}${mem}%${reset}"
    echo -e "${gl_lv}命令:${reset} ${gl_bai}${cmd}${reset}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    read -r -e -p "$(echo -e "${gl_bai}确认终止此进程? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ${reset}")" confirm
    case "$confirm" in
        y|Y|yes|YES)
            if kill "$pid" 2>/dev/null; then
                echo -e "${gl_lv}✓ 进程 ${pid} 已终止${reset}"
            else
                echo -e "${gl_hong}✗ 终止失败，尝试强制终止...${reset}"
                if kill -9 "$pid" 2>/dev/null; then
                    echo -e "${gl_huang}⚠ 进程 ${pid} 已强制终止 (SIGKILL)${reset}"
                else
                    echo -e "${gl_hong}✗ 无法终止进程 ${pid} (权限不足?)${reset}"
                    return 1
                fi
            fi
            ;;
        *)
            echo -e "${gl_hui}已取消${reset}"
            return 0
            ;;
    esac
}

list_and_select_process() {
    local sort_by="${1:-cpu}"

    echo -e "${gl_zi}>>> 进程列表 (按 CPU 降序)${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local tmpfile
    tmpfile=$(mktemp /tmp/kill_select.XXXXXX)
    trap 'rm -f "$tmpfile"' EXIT

    ps aux --sort=-%cpu | tail -n +2 | head -n 30 | \
    awk -v red="$gl_hong" -v yellow="$gl_huang" -v green="$gl_lv" \
        -v blue="$gl_lan" -v cyan="$gl_bufan" -v white="$gl_bai" -v gray="$gl_hui" -v reset="$reset" '
    {
        user = $1
        pid = $2
        cpu = $3
        mem = $4
        cmd = $11
        for (i = 12; i <= NF; i++) cmd = cmd " " $i
        if (length(cmd) > 40) cmd = substr(cmd, 1, 40) "…"
        cpu_color = (cpu + 0 > 50) ? red : (cpu + 0 > 10) ? yellow : green
        mem_color = (mem + 0 > 50) ? red : (mem + 0 > 10) ? yellow : blue
        printf "%s%3d%s  %s%-6s%s %s%-6s%s %s%-5s%s %s%-5s%s %s%-40s%s\n",
            yellow, NR, reset,
            white, user, reset,
            gray, pid, reset,
            cpu_color, cpu, reset,
            mem_color, mem, reset,
            white, cmd, reset
        printf "%d\t%s\n", NR, pid >> "'"$tmpfile"'"
    }'

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_hui}共 30 条 (CPU 占用前 30)${reset}"
    echo ""
    echo -e "${gl_bai}请输入要终止的进程编号 (1-30) (${gl_hong}0${gl_bai} 退出):${reset} \c"
    read -r selection

    case "$selection" in
        0)
            echo -e "${gl_hui}已退出${reset}"
            return 0
            ;;
        ''|*[!0-9]*)
            echo -e "${gl_hong}输入无效${reset}"
            return 1
            ;;
        *)
            if [ "$selection" -lt 1 ] || [ "$selection" -gt 30 ]; then
                echo -e "${gl_hong}编号超出范围 (1-30)${reset}"
                return 1
            fi
            target_pid=$(awk -F'\t' -v sel="$selection" '$1==sel {print $2}' "$tmpfile")
            if [ -z "$target_pid" ]; then
                echo -e "${gl_hong}未找到对应进程${reset}"
                return 1
            fi
            echo ""
            kill_by_pid "$target_pid"
            ;;
    esac
}

kill_by_name() {
    local name="$1"
    local matches
    matches=$(ps aux | grep -i "$name" | grep -v grep | grep -v "$0")
    if [ -z "$matches" ]; then
        echo -e "${gl_hong}未找到匹配 \"${name}\" 的进程${reset}"
        return 1
    fi

    local count
    count=$(echo "$matches" | wc -l)

    echo -e "${gl_zi}>>> 匹配 \"${name}\" 的进程 (共 ${count} 个)${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local tmpfile
    tmpfile=$(mktemp /tmp/kill_name.XXXXXX)
    trap 'rm -f "$tmpfile"' EXIT

    echo "$matches" | \
    awk -v red="$gl_hong" -v yellow="$gl_huang" -v green="$gl_lv" \
        -v blue="$gl_lan" -v cyan="$gl_bufan" -v white="$gl_bai" -v gray="$gl_hui" -v reset="$reset" '
    {
        user = $1
        pid = $2
        cpu = $3
        mem = $4
        cmd = $11
        for (i = 12; i <= NF; i++) cmd = cmd " " $i
        cpu_color = (cpu + 0 > 50) ? red : (cpu + 0 > 10) ? yellow : green
        mem_color = (mem + 0 > 50) ? red : (mem + 0 > 10) ? yellow : blue
        printf "%s%3d%s  %s%-6s%s %s%-6s%s %s%-5s%s %s%-5s%s %s%-50s%s\n",
            yellow, NR, reset,
            white, user, reset,
            gray, pid, reset,
            cpu_color, cpu, reset,
            mem_color, mem, reset,
            white, cmd, reset
        printf "%d\t%s\n", NR, pid >> "'"$tmpfile"'"
    }'

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if [ "$count" -eq 1 ]; then
        local single_pid
        single_pid=$(echo "$matches" | awk '{print $2}')
        echo -e ""
        read -r -e -p "$(echo -e "${gl_bai}确认终止所有匹配进程? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ${reset}")" confirm
        case "$confirm" in
            y|Y|yes|YES)
                kill_by_pid "$single_pid"
                ;;
            *)
                echo -e "${gl_hui}已取消${reset}"
                return 0
                ;;
        esac
    else
        echo -e "${gl_huang}请选择要终止的进程编号 (1-${count}) 或 a(全部) 或 q(退出):${reset} \c"
        read -r selection
        case "$selection" in
            q|Q|quit|exit)
                echo -e "${gl_hui}已退出${reset}"
                return 0
                ;;
            a|A|all|ALL)
                read -r -e -p "$(echo -e "${gl_bai}确认终止全部 ${count} 个匹配进程? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ${reset}")" confirm
                case "$confirm" in
                    y|Y|yes|YES)
                        echo "$matches" | awk '{print $2}' | while read -r pid; do
                            kill_by_pid "$pid"
                        done
                        ;;
                    *)
                        echo -e "${gl_hui}已取消${reset}"
                        ;;
                esac
                ;;
            ''|*[!0-9]*)
                echo -e "${gl_hong}输入无效${reset}"
                return 1
                ;;
            *)
                if [ "$selection" -lt 1 ] || [ "$selection" -gt "$count" ]; then
                    echo -e "${gl_hong}编号超出范围${reset}"
                    return 1
                fi
                target_pid=$(awk -F'\t' -v sel="$selection" '$1==sel {print $2}' "$tmpfile")
                if [ -z "$target_pid" ]; then
                    echo -e "${gl_hong}未找到对应进程${reset}"
                    return 1
                fi
                echo ""
                kill_by_pid "$target_pid"
                ;;
        esac
    fi
}

main() {
    clear
    if [ $# -eq 0 ]; then
        # 交互模式: 显示进程列表供选择
        list_and_select_process
        echo ""
        break_end
    elif [ $# -eq 1 ]; then
        local arg="$1"
        if [[ "$arg" =~ ^[0-9]+$ ]]; then
            # 传参为 PID
            kill_by_pid "$arg"
        else
            # 传参为进程名
            kill_by_name "$arg"
        fi
        echo ""
        break_end
    else
        echo -e "${gl_huang}用法:${reset}"
        echo -e "  ${gl_bai}$0${reset}           ${gl_hui}— 交互模式，选择进程终止${reset}"
        echo -e "  ${gl_bai}$0 <PID>${reset}      ${gl_hui}— 按 PID 终止进程${reset}"
        echo -e "  ${gl_bai}$0 <名称>${reset}     ${gl_hui}— 按名称搜索并终止进程${reset}"
        echo ""
        break_end
    fi
}

main "$@"
