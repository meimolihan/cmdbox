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

docker-ps-find() {
    {
        local filters=("$@")

        printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "容器ID" "名称" "状态" "端口" "创建时间" "镜像" "$reset"
        printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "----------" "----------" "----------" "----------" "----------" "----------" "$reset"

        docker ps --format "{{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.RunningFor}}\t{{.Image}}" | \
        
        if [ $# -gt 0 ]; then
            awk -v filters="${filters[*]}" '
            BEGIN {
                split(filters, arr, " ")
                for (i in arr) pattern[arr[i]] = 1
            }
            {
                for (p in pattern) {
                    if ($2 ~ p) {
                        print
                        next
                    }
                }
            }'
        else
            cat
        fi | \

        awk -v green="$gl_lv" -v red="$gl_hong" -v yellow="$gl_huang" -v cyan="$gl_bufan" -v blue="$gl_lan" -v white="$gl_bai" -v reset="$reset" '
        BEGIN {FS="\t"; OFS="\t"}
        {
            id = substr($1, 1, 12)
            name = $2
            status = $3
            ports = $4
            time = $5
            image = $6

            gsub(/healthy/, "健康", status)
            gsub(/unhealthy/, "不健康", status)
            gsub(/starting/, "启动中", status)
            gsub(/Up /, "已运行 ", status)
            gsub(/days/, "天", status)
            gsub(/hours/, "小时", status)
            gsub(/minutes/, "分钟", status)
            gsub(/seconds/, "秒", status)

            if (status !~ /健康|不健康|启动中/) {
                status = status " (正常)"
            }

            gsub(/[0-9]+/, green "&" reset, status)

            gsub(/健康/, green "&" reset, status)    # 健康=绿色
            gsub(/不健康/, red "&" reset, status)    # 不健康=红色
            gsub(/启动中/, yellow "&" reset, status) # 启动中=黄色
            gsub(/正常/, blue "&" reset, status)     # 正常=蓝色

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
            gsub(/About /, "", time)
            
            gsub(/[0-9]+/, green "&" reset, time)

            print cyan id reset, green name reset, yellow status reset, blue ports reset, white time reset, white image reset
        }'
    } | column_if_available
}

list_beautify_all() {
    clear
    echo -e "${gl_zi}>>> Docker容器列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    docker-ps-find "$@"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all "$@"