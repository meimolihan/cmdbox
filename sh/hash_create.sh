#!/bin/bash

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

cancel_empty() {
    local menu_name="${1:-上一级选单}"
    echo -e "${gl_hong}空输入，返回 ${gl_huang}${menu_name} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep 0.6
    echo ""
    clear
}

hash_create() {
    local p1="${1:-}"
    local p2="${2:-}"
    local target_file=""
    local algo=""

    if [[ -n "${p1}" && -f "$p1" ]]; then
        target_file="$p1"
        algo="$p2"
    elif [[ -n "${p2}" && -f "$p2" ]]; then
        target_file="$p2"
        algo="$p1"
    fi

    if [[ -z "$target_file" ]]; then
        clear
        echo -e "${gl_zi}>>> 交互式哈希生成 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入文件绝对路径: ")" target_file
        if [[ -z "$target_file" ]]; then
            cancel_empty "返回"
            return 1
        fi
        if [[ ! -f "$target_file" ]]; then
            log_error "文件不存在：$target_file"
            return 1
        fi
        echo ""
        echo -e "${gl_huang}>>> 请选择哈希算法${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1. ${gl_bai}sha256"
        echo -e "${gl_bufan}2. ${gl_bai}md5"
        echo -e "${gl_bufan}3. ${gl_bai}all（同时生成sha256+md5）"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}输入选项 [1/2/3]: ")" sel
        case "$sel" in
            1) algo="sha256" ;;
            2) algo="md5" ;;
            3) algo="all" ;;
            *)
                log_error "无效选项"
                return 1
                ;;
        esac
    fi

    local base_name=$(basename "$target_file")
    local dir_name=$(dirname "$target_file")
    local stem="${base_name%.*}"
    algo=$(echo "$algo" | tr '[:upper:]' '[:lower:]')

    gen_single() {
        local a="$1"
        local hash_out
        case "$a" in
            sha256)
                hash_out=$(sha256sum "$target_file" | awk -v n="$base_name" '{print $1,"./"n}')
                echo "$hash_out" > "${dir_name}/${stem}_hash-sha256.txt"
                log_ok "sha256 已保存: ${dir_name}/${stem}_hash-sha256.txt"
                ;;
            md5)
                hash_out=$(md5sum "$target_file" | awk -v n="$base_name" '{print $1,"./"n}')
                echo "$hash_out" > "${dir_name}/${stem}_hash-md5.txt"
                log_ok "md5 已保存: ${dir_name}/${stem}_hash-md5.txt"
                ;;
            *)
                log_error "不支持算法: $a，仅支持 md5 / sha256 / all"
                return 2
        esac
    }

    case "$algo" in
        ""|all)
            gen_single sha256
            gen_single md5
            ;;
        sha256|md5)
            gen_single "$algo"
            ;;
        *)
            log_error "不支持参数：$algo，可选 sha256 / md5 / all"
            return 2
            ;;
    esac
}

hash_create "$@"