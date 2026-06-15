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

log_info() { echo -e "${gl_lan}[信息]${gl_bai} $*"; }
log_ok() { echo -e "${gl_lv}[成功]${gl_bai} $*"; }
log_warn() { echo -e "${gl_huang}[警告]${gl_bai} $*"; }
log_error() { echo -e "${gl_hong}[错误]${gl_bai} $*" >&2; }

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    read -r -n 1 -s -p ""
    echo ""
    clear
}

sleep_fractional() {
    local seconds=$1
    if sleep "$seconds" 2>/dev/null; then return 0; fi
    if command -v perl >/dev/null 2>&1; then perl -e "select(undef, undef, undef, $seconds)"; return 0; fi
    if command -v python3 >/dev/null 2>&1; then python3 -c "import time; time.sleep($seconds)"; return 0; fi
    if command -v python >/dev/null 2>&1; then python -c "import time; time.sleep($seconds)"; return 0; fi
    local int_seconds=$(echo "$seconds" | awk '{print int($1+0.999)}')
    sleep "$int_seconds"
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

handle_invalid_input() {
    echo -ne "\r${gl_hong}无效的输入，请重新输入 ${gl_zi} 2 ${gl_hong}秒后返回 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.3
    echo -ne "\r${gl_huang}无效的输入，请重新输入 ${gl_zi} 1 ${gl_huang}秒后返回 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.3
    echo -e "\r${gl_lv}无效的输入，请重新输入 ${gl_zi} 0 ${gl_lv}秒后返回 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    continue
}

if [[ $# -ne 1 ]]; then
    clear
    echo -e "${gl_zi}>>> Docker Hub 项目管理${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_error "参数错误！用法：$0 <DockerHub_Token>"
    echo -e "示例：$0 mobufan:dckr_pat_xxxxxx"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
    exit 1
fi
DH_TOKEN="$1"

docker-hub_images_delete_menu() {
    while true; do
        clear
        echo -e "${gl_zi}>>> Docker Hub 项目管理${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}cmdbox"
        echo -e "${gl_bufan}2.  ${gl_bai}dufs-zh"
        echo -e "${gl_bufan}3.  ${gl_bai}metube-zh"
        echo -e "${gl_bufan}4.  ${gl_bai}random-pic-api"
        echo -e "${gl_bufan}5.  ${gl_bai}speedtest-go-zh"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_lv}66. ${gl_bai}推送当前项目更新"
        echo -e "${gl_huang}99. ${gl_bai}拉取当前项目更新"
        echo -e "${gl_hong}0.  ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" rename_mode

        case "$rename_mode" in
        1) bash <(curl -sL gitee.com/meimolihan/cmdbox/raw/master/sh/docker-hub_images_delete.sh) "${DH_TOKEN}" mobufan/cmdbox ;;
        2) bash <(curl -sL gitee.com/meimolihan/cmdbox/raw/master/sh/docker-hub_images_delete.sh) "${DH_TOKEN}" mobufan/dufs-zh ;;
        3) bash <(curl -sL gitee.com/meimolihan/cmdbox/raw/master/sh/docker-hub_images_delete.sh) "${DH_TOKEN}" mobufan/metube-zh ;;
        4) bash <(curl -sL gitee.com/meimolihan/cmdbox/raw/master/sh/docker-hub_images_delete.sh) "${DH_TOKEN}" mobufan/random-pic-api ;;
        5) bash <(curl -sL gitee.com/meimolihan/cmdbox/raw/master/sh/docker-hub_images_delete.sh) "${DH_TOKEN}" mobufan/speedtest-go-zh ;;
        0 | 00 | 000) exit_script ;;
        *) handle_invalid_input ;;
        esac
    done
}

docker-hub_images_delete_menu