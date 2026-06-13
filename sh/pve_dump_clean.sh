#!/bin/bash
set -uo pipefail

# 颜色定义
gl_hui=$'\033[38;5;59m'
gl_huang=$'\033[38;5;11m'
gl_lan=$'\033[38;5;32m'
gl_lv=$'\033[38;5;10m'
gl_qing=$'\033[38;5;14m'
gl_zi=$'\033[38;5;13m'
gl_bai=$'\033[38;5;15m'
gl_bufan=$'\033[38;5;14m'
gl_hong=$'\033[38;5;9m'
reset=$'\033[0m'

# 要清理的文件路径
CLEAN_DIR="/var/lib/vz/dump"
CLEAN_FILES=("*.log" "*.notes")

# 分隔与结束提示
break_end() {
    echo -e "${gl_bufan}————————————————————————————————————————————————${reset}"
    echo -e "${gl_lv}操作完成${reset}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${reset}\c"
    read -r -n 1 -s
    echo ""
    clear
}

# 美化目录列表（按时间排序）
list_beautify_directory() {
    local target_dir="${1:-.}"
    [[ -d "$target_dir" ]] || {
        echo -e "${gl_hong}错误：目录不存在 → $target_dir${reset}"
        return 1
    }

    echo -e "${gl_bufan}————————————————————————————————————————————————${reset}"
    echo -e "${gl_lan}路径：${gl_huang}${target_dir}${reset}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${reset}"

    # 总大小
    du -sh "$target_dir" 2>/dev/null | awk -v qing="$gl_qing" -v rst="$reset" \
        '{print qing "总计 " $1 rst}'

    # 按修改时间排序输出文件
    find "$target_dir" -maxdepth 1 -type f -printf '%T@ %p\0' |
    sort -zn |
    while IFS= read -r -d '' line; do
        mtime="${line%% *}"
        file="${line#* }"

        stat --format="%A %h %U %G %s" "$file" | awk \
            -v hui="$gl_hui" \
            -v huang="$gl_huang" \
            -v lan="$gl_lan" \
            -v lv="$gl_lv" \
            -v qing="$gl_qing" \
            -v zi="$gl_zi" \
            -v rst="$reset" \
            -v mtime="$mtime" \
            -v fname="$(basename "$file")" '
        {
            size=$5
            if (size >= 1073741824)
                size=sprintf("%.1fG", size/1073741824)
            else if (size >= 1048576)
                size=sprintf("%.1fM", size/1048576)
            else if (size >= 1024)
                size=sprintf("%.1fK", size/1024)
            else
                size=size "B"

            cmd="date -d @" mtime " \"+%F %T\""
            cmd | getline ctime
            close(cmd)

            printf "%-12s %4s %-8s %-8s %6s %-19s %s\n",
                hui $1 rst,
                huang $2 rst,
                lan $3 rst,
                lv $4 rst,
                huang size rst,
                qing ctime rst,
                zi fname rst
        }'
    done
}

# 主流程
main() {
    clear
    
    if ! command -v qm &> /dev/null; then
        echo -e ""
        echo -e "${gl_zi}>>> 一键清理 PVE 备份文件的所有日志和备注文件${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        log_error "未检测到Proxmox VE环境，请确保脚本在PVE节点上运行"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return 1
    fi
    
    echo -e "${gl_zi}>>> ${gl_huang}【删除前】${gl_zi}目录文件列表（按时间排序）${reset}"
    list_beautify_directory "$CLEAN_DIR"
    echo -e "${gl_bufan}————————————————————————————————————————————————${reset}"
    echo -e "\n"

    echo -e "${gl_zi}>>> 一键清理 PVE 备份文件的所有日志和备注文件${reset}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${reset}"
    echo -e "${gl_hong}即将删除以下文件：${reset}"
    for pattern in "${CLEAN_FILES[@]}"; do
        echo -e "  ${gl_huang}$CLEAN_DIR/$pattern${reset}"
    done

    echo -e "${gl_bufan}————————————————————————————————————————————————${reset}"
    echo -e "${gl_bai}确认执行删除？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai})：\c"
    read -r confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${gl_lv}已取消删除操作${reset}"
        break_end
        exit 0
    fi

    echo -e "\n${gl_qing}正在执行删除 ${gl_hong}.${gl_huang}.${gl_lv}.${reset}"
    for pattern in "${CLEAN_FILES[@]}"; do
        rm -f "$CLEAN_DIR"/$pattern
    done
    echo -e "${gl_lv}删除完成！${reset}\n"

    echo -e ""

    echo -e "${gl_zi}>>> ${gl_huang}【删除后】${gl_zi}目录文件列表（按时间排序）${reset}"
    list_beautify_directory "$CLEAN_DIR"

    break_end
}

main "$@"
