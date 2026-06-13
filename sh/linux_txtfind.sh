#!/bin/bash
set -uo pipefail

gl_hui='\033[38;5;59m'
gl_hong='\033[38;5;9m'
gl_lv='\033[38;5;10m'
gl_huang='\033[38;5;11m'
gl_lan='\033[38;5;32m'
gl_bai='\033[38;5;15m'
gl_zi='\033[38;5;13m'
gl_bufan='\033[38;5;14m'

log_info()  { echo -e "${gl_lan}[信息]${gl_bai} $*"; }
log_ok()    { echo -e "${gl_lv}[成功]${gl_bai} $*"; }
log_warn()  { echo -e "${gl_huang}[警告]${gl_bai} $*"; }
log_error() { echo -e "${gl_hong}[错误]${gl_bai} $*" >&2; }

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n 1 -s -r -p ""
    echo ""
    clear
}

exit_script() {
    echo ""
    echo -ne "${gl_hong}感谢使用，再见！ ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    clear
    exit 0
}

do_search() {
    local keyword="$1"
    
    if [[ -z "$keyword" ]]; then
        log_error "搜索关键词不能为空！"
        return 1
    fi

    echo -e ""
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_info "正在递归搜索：${gl_huang}$keyword${gl_bai}"
    log_info "搜索范围：当前目录 + 所有子目录"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    grep -r -n --color=always "$keyword" .

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_ok "搜索完成！"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

search_menu() {
    while true; do
        clear
        if [ -z "$(ls -A 2>/dev/null)" ]; then
            echo -e "${gl_huang}>>> 目录状态: ${gl_bai}(${gl_lv}$(pwd)${gl_bai})"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_huang}当前目录为空${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        else
            echo -e "${gl_huang}>>> 目录内容: ${gl_bai}(${gl_lv}$(pwd)${gl_bai})"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            ls --color=auto -xA
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        fi
        echo -e ""
        echo -e "${gl_zi}>>> 递归文件内容搜索工具${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        read -r -e -p "$(echo -e "${gl_bufan}请输入要搜索的关键词(${gl_hong}0${gl_bai}退出): ")" keyword
        [[ "$keyword" == "0" ]] && exit_script

        do_search "$keyword"

    done

    log_info "已退出搜索工具"
    clear
}

if [[ $# -ge 1 ]]; then
    do_search "$*"
    echo ""
else
    search_menu
fi