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
    read -r -n 1 -s -p ""
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

list_beautify_docker_images() {
    local filter_image="$1"
    {
        printf "%s%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "仓库" "标签" "镜像ID" "创建时间" "大小" "$reset"
        printf "%s%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "----------" "----------" "----------" "----------" "----------" "$reset"

        if [[ -n "$filter_image" ]]; then
            docker image ls --format "{{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedSince}}\t{{.Size}}" "$filter_image"
        else
            docker image ls --format "{{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedSince}}\t{{.Size}}"
        fi | \
        awk -v green="$gl_lv" -v yellow="$gl_huang" -v cyan="$gl_bufan" -v blue="$gl_lan" -v white="$gl_bai" -v reset="$reset" '
        BEGIN {FS="\t"; OFS="\t"}
        {
            id = substr($3, 1, 12)
            time = $4
            gsub(/ years ago/, "年前", time)
            gsub(/ year ago/, "年前", time)
            gsub(/ months ago/, "个月前", time)
            gsub(/ month ago/, "个月前", time)
            gsub(/ weeks ago/, "周前", time)
            gsub(/ week ago/, "周前", time)
            gsub(/ days ago/, "天前", time)
            gsub(/ day ago/, "天前", time)
            gsub(/ hours ago/, "小时前", time)
            gsub(/ hour ago/, "小时前", time)
            gsub(/ minutes ago/, "分钟前", time)
            gsub(/ minute ago/, "分钟前", time)
            gsub(/ seconds ago/, "秒前", time)
            gsub(/ second ago/, "秒前", time)
            gsub(/About /, "", time)
            
            print green $1 reset, yellow $2 reset, cyan id reset, blue time reset, white $5 reset
        }'
    } | column_if_available
}

list_beautify_all() {
    local filter_img=""
    # 安全判断参数，避免未绑定变量错误
    if [[ $# -ge 1 ]]; then
        filter_img="$1"
    fi

    clear
    echo -e "${gl_zi}>>> Docker镜像列表${gl_bai}"
    if [[ -n "$filter_img" ]]; then
        echo -e "${gl_lan}已过滤镜像: ${gl_lv}${filter_img}${gl_bai}"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_docker_images "$filter_img"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

# 安全调用
if [[ $# -ge 1 ]]; then
    list_beautify_all "$1"
else
    list_beautify_all
fi