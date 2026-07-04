#!/bin/bash
set -uo pipefail

gl_hui=$'\033[38;5;59m'
gl_huang=$'\033[38;5;11m'
gl_hong=$'\033[38;5;9m'
gl_lan=$'\033[38;5;32m'
gl_lv=$'\033[38;5;10m'
gl_qing=$'\033[38;5;14m'
gl_zi=$'\033[38;5;13m'
gl_bai=$'\033[38;5;15m'
gl_bufan=$'\033[38;5;14m'
reset=$'\033[0m'

break_end() {
    echo -e "${gl_bufan}————————————————————————————————————————————————${reset}"
    echo -e "${gl_lv}操作完成${reset}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${reset}\c"
    read -r -n 1 -s
    echo ""
    clear
}

list_beautify_directory() {
    local target_dir="${1:-.}"
    [[ -d "$target_dir" ]] || {
        echo -e "${gl_hong}错误：目录不存在 → $target_dir${reset}"
        return 1
    }

    clear
    echo -e "${gl_zi}>>> 目录文件列表（按时间排序）${reset}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${reset}"
    echo -e "${gl_lan}路径：${gl_huang}${target_dir}${reset}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${reset}"

    # 总大小
    du -sh "$target_dir" 2>/dev/null | awk -v qing="$gl_qing" -v rst="$reset" \
        '{print qing "总计 " $1 rst}'

    # 核心：不用 ls，直接用 stat
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

            printf "%s%-12s%s %s%4s%s %s%-8s%s %s%-8s%s %s%6s%s %s%-19s%s %s%s%s\n",
                hui, $1, rst,
                huang, $2, rst,
                lan, $3, rst,
                lv, $4, rst,
                huang, size, rst,
                qing, ctime, rst,
                zi, fname, rst
        }'
    done
}

main() {
    list_beautify_directory "${1:-.}"
    break_end
}

main "$@"
