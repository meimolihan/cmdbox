#!/bin/bash
set -uo pipefail

# ====================== 共有函数库（自包含，勿改函数名） ======================
# ==== BOILERPLATE:START ====
# 本段为 cmdbox 统一函数库，保证脚本自包含、拉取即用；手工复制时整段照搬。
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

log_info()  { echo -e "${gl_lan}[信息]${gl_bai} $*"; }
log_ok()    { echo -e "${gl_lv}[成功]${gl_bai} $*"; }
log_warn()  { echo -e "${gl_huang}[警告]${gl_bai} $*"; }
log_error() { echo -e "${gl_hong}[错误]${gl_bai} $*" >&2; }

sleep_fractional() {
    local seconds=$1
    if sleep "$seconds" 2>/dev/null; then return 0; fi
    if command -v perl >/dev/null 2>&1; then perl -e "select(undef, undef, undef, $seconds)"; return 0; fi
    if command -v python3 >/dev/null 2>&1; then python3 -c "import time; time.sleep($seconds)"; return 0; fi
    if command -v python >/dev/null 2>&1; then python -c "import time; time.sleep($seconds)"; return 0; fi
    local int_seconds=$(echo "$seconds" | awk '{print int($1+0.999)}')
    sleep "$int_seconds"
}

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n 1 -s -r -p ""
    echo ""
    clear
}

cancel_return() {
    local menu_name="${1:-上一级选单}"
    echo -ne "${gl_lv}即将返回到 ${gl_huang}${menu_name}${gl_lv} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    sleep_fractional 0.6
    echo ""
    clear
}

exit_animation() {
    echo -ne "${gl_lv}即将退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo ""
    clear
}

exit_script() {
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local dots=(
        "${gl_hong}."
        "${gl_huang}."
        "${gl_lv}."
        "${gl_bufan}."
        "${gl_zi}."
    )
    local dot_buffer=""
    local frame_len=${#frames[@]}
    local dot_idx=0
    local total_dots=${#dots[@]}

    for ((i=0; i<20; i++)); do
        if (( i > 0 && i % 3 == 0 && dot_idx < total_dots )); then
            dot_buffer+=${dots[$dot_idx]}
            ((dot_idx++))
        fi
        echo -ne "\r\033[K${gl_bufan}${frames[i % frame_len]}${gl_bai} 正在退出 ${dot_buffer}"
        sleep_fractional 0.06
    done
    echo -e "\r\033[K${gl_lv}✓${gl_bai} 成功退出\n"
    clear
    exit 0
}

handle_invalid_input() {
    echo -ne "\r\033[K${gl_huang}无效的输入,请重新输入! ${gl_zi} 1 ${gl_huang} 秒后返回"
    sleep_fractional 1
    echo -ne "\r\033[K${gl_lv}无效的输入,请重新输入! ${gl_zi}0${gl_lv} 秒后返回"
    sleep_fractional 0.5
    echo -ne "\r\033[K"
    continue
}

column_if_available() {
    if command -v column &> /dev/null; then
        column -t -s $'\t'
    else
        cat
    fi
}
# ==== BOILERPLATE:END ====
# ============================================================================

list_beautify_nginx_server() {
    {
        printf "%s%s\t%s%s\n" "$gl_hui" "ServerName域名" "Listen监听配置" "$reset"
        printf "%s%s\t%s%s\n" "$gl_hui" "--------------" "--------------" "$reset"

        data=$(nginx -T 2>/dev/null | grep -E "server_name|listen" | grep -v '^[[:space:]]*#' )
        if [ -z "$data" ]; then
            printf "%s%s\t%s%s\n" "$gl_huang" "(无站点数据)" "(无数据)" "$reset"
        else
            echo "$data" | awk -v dom_color="$gl_lan" \
                                -v listen_color="$gl_lv" \
                                -v empty_color="$gl_huang" \
                                -v reset="$reset" '
            BEGIN {
                FS=";"
                OFS="\t"
                last_dom = "--"
            }
            {
                gsub(/^[ \t]+/,"",$1);
                line = $1
                if (match(line,/^server_name[ \t]+/)){
                    sub(/^server_name[ \t]+/,"",line)
                    gsub(/[ \t]+$/,"",line)
                    last_dom = line
                }else if(match(line,/^listen[ \t]+/)){
                    sub(/^listen[ \t]+/,"",line)
                    gsub(/[ \t]+$/,"",line)
                    if(last_dom == "") last_dom="--"
                    print dom_color last_dom reset , listen_color line reset
                }
            }'
        fi
    } | column_if_available
}

list_nginx_all() {
    clear
    echo -e "${gl_zi}>>> Nginx虚拟主机域名&监听列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_nginx_server
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_nginx_all
