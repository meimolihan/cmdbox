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

hash_verify() {
    local p1="${1:-}"
    local p2="${2:-}"
    local file=""
    local expect_hash=""
    local algo=""

    if [[ -n "${p1}" && -f "$p1" ]]; then
        file="$p1"
        expect_hash="$p2"
    elif [[ -n "${p2}" && -f "$p2" ]]; then
        file="$p2"
        expect_hash="$p1"
    fi

    if [[ -z "$file" ]]; then
        clear
        echo -e "${gl_zi}>>> 交互式哈希校验 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入文件绝对路径: ")" file
        if [[ -z "$file" ]]; then
            cancel_empty "返回"
            return 1
        fi
        if [[ ! -f "$file" ]]; then
            log_error "文件不存在：$file"
            return 1
        fi
        echo ""
        read -r -e -p "$(echo -e "${gl_bai}请输入预期哈希值: ")" expect_hash
        if [[ -z "$expect_hash" ]]; then
            cancel_empty "返回"
            return 1
        fi
    fi

    local hash_len=${#expect_hash}
    if [[ "$hash_len" -eq 64 ]]; then
        algo="sha256"
    elif [[ "$hash_len" -eq 32 ]]; then
        algo="md5"
    else
        log_error "哈希长度非法！sha256=64位，md5=32位"
        return 1
    fi

    local cur_hash
    case "$algo" in
        sha256)
            cur_hash=$(sha256sum "$file" | awk '{print $1}')
            ;;
        md5)
            cur_hash=$(md5sum "$file" | awk '{print $1}')
            ;;
    esac

    if [[ "$cur_hash" == "$expect_hash" ]]; then
        log_ok "【$algo】哈希匹配，文件完好"
        return 0
    else
        log_error "【$algo】哈希不匹配！"
        echo -e "${gl_bai}  预期: $expect_hash"
        echo -e "${gl_bai}  当前: $cur_hash"
        return 2
    fi
}

hash_verify "$@"