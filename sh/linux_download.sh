#!/bin/bash
set -uo pipefail

gl_hui='\e[37m'
gl_hong='\033[31m'
gl_lv='\033[32m'
gl_huang='\033[33m'
gl_lan='\033[34m'
gl_zi='\033[35m'
gl_bufan='\033[96m'
gl_bai='\033[97m'

log_info()  { echo -e "${gl_lan}[信息]${gl_bai} $*"; }
log_ok()    { echo -e "${gl_lv}[成功]${gl_bai} $*"; }
log_warn()  { echo -e "${gl_huang}[警告]${gl_bai} $*"; }
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

handle_y_n() {
    echo -ne "\r${gl_hong}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai}) ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.3
    echo -ne "\r${gl_huang}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai}) ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.3
    echo -ne "\r${gl_lv}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai}) ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo ""
    return 2
}

exit_animation() {
    echo -ne "\r${gl_lv}即将退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo ""
}

handle_invalid_input() {
    echo -ne "\r\033[K${gl_huang}无效的输入,请重新输入! ${gl_zi} 1 ${gl_huang} 秒后返回"
    sleep_fractional 1
    echo -ne "\r\033[K${gl_lv}无效的输入,请重新输入! ${gl_zi}0${gl_lv} 秒后返回"
    sleep_fractional 0.5
    echo -ne "\r\033[K"
    return 2
}

cancel_return() {
    local menu_name="${1:-上一级菜单}"
    echo -e "${gl_lv}即将返回到 ${gl_huang}${menu_name}${gl_lv} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    sleep_fractional 0.6
    echo ""
    clear
}

download_single() {
    local url="$1"
    [[ -z "$url" ]] && { log_error "下载链接不能为空"; return 1; }

    url=$(echo "$url" | sed -E 's|(https?://)+|\1|g')

    if [[ ! "$url" =~ ^https?:// ]]; then
        log_error "链接必须以 http:// 或 https:// 开头"
        return 1
    fi

    local raw_name=$(echo "$url" | sed 's/^.*\///' | sed 's/?.*$//')
    local filename=$(printf '%b' "${raw_name//%/\\x}" 2>/dev/null || echo "$raw_name")
    [[ -z "$filename" || "$filename" == "/" ]] && filename="downloaded_file"
    filename=$(echo "$filename" | tr -d '\000-\037' | tr '/' '_' | tr ':' '_' | tr '()[]{}<>' '_' | tr '*?&' '_')

    echo -e ""
    log_info "默认文件名：${gl_lv}$filename"
    echo -e ""
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}修改文件名？(${gl_huang}回车使用默认${gl_bai})：")" new_filename
    [[ -n "$new_filename" ]] && filename="$new_filename"

    local expected_size=0
    if command -v curl &>/dev/null; then
        expected_size=$(curl -s -L -I "$url" 2>/dev/null | grep -i 'content-length' | awk '{print $2}' | tr -d '\r' | tail -1)
    elif command -v wget &>/dev/null; then
        expected_size=$(wget --spider -S "$url" 2>&1 | grep -i 'content-length' | awk '{print $2}' | tail -1)
    fi

    if [[ -n "$expected_size" && "$expected_size" -gt 0 ]]; then
        log_info "文件大小：${gl_lv}$(numfmt --to=iec "$expected_size")"
    else
        log_warn "无法获取文件大小，将直接下载"
    fi

    local download_tool=""
    if command -v wget &>/dev/null; then
        download_tool="wget"
        log_info "使用下载工具：wget"
    elif command -v curl &>/dev/null; then
        download_tool="curl"
        log_info "使用下载工具：curl"
    else
        log_error "未找到下载工具，请先安装 wget 或 curl"
        return 1
    fi

    if [[ -f "$filename" ]]; then
        local existing_size=$(stat -c%s "$filename" 2>/dev/null || echo 0)
        if [[ "$expected_size" -gt 0 && "$existing_size" -eq "$expected_size" ]]; then
            log_ok "文件已存在且完整：${gl_bai}$filename"
            return 0
        elif [[ "$existing_size" -gt 0 ]]; then
            log_warn "检测到未完成文件，启用断点续传"
        fi
    fi

    local start_ts=$(date +%s)
    log_info "开始下载${gl_lv} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    local exit_code=0

    case $download_tool in
        wget) wget -c -T 30 --quiet --show-progress -O "$filename" "$url"; exit_code=$? ;;
        curl) curl -L -C - --progress-bar -o "$filename" "$url"; exit_code=$? ;;
    esac

    local elapsed=$(( $(date +%s) - start_ts ))
    printf -v dur "%02d:%02d:%02d" $((elapsed/3600)) $(((elapsed%3600)/60)) $((elapsed%60))
    log_info "下载耗时：${gl_lv}$dur"

    [[ $exit_code -ne 0 ]] && { log_error "下载失败！错误码：$exit_code"; return 1; }

    local actual_size=$(stat -c%s "$filename" 2>/dev/null || echo 0)
    if [[ "$expected_size" -gt 0 && "$actual_size" -ne "$expected_size" ]]; then
        log_error "文件不完整！实际：$(numfmt --to=iec $actual_size)，期望：$(numfmt --to=iec $expected_size)"
        return 1
    fi

    log_ok "下载完成！"
    local fp=$(realpath "$filename" 2>/dev/null || echo "$filename")
    local fs=$(numfmt --to=iec "$actual_size" 2>/dev/null || echo "未知")
    local md5=$(md5sum "$filename" 2>/dev/null | awk '{print $1}' || echo "获取失败")

    echo -e ""
    log_info "下载文件信息"
    echo -e "${gl_bai}路径：${gl_lv}$fp"
    echo -e "${gl_bai}大小：${gl_lv}$fs"
    echo -e "${gl_bai}MD5：${gl_lv}$md5"
    echo -e ""
    return 0
}

main() {
    clear
    if [[ $# -ge 1 ]]; then
        local url="$1"
        download_single "$url"
        exit 0
    fi

    while true; do
    echo -e "${gl_huang}>>> 当前目录文件列表：${gl_bai}(${gl_lv}$(pwd)${gl_bai})"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local file_count
    file_count=$(find . -maxdepth 1 -type f | wc -l)
    if [[ "$file_count" -eq 0 ]]; then
        echo -e "${gl_huang}当前目录为空${gl_bai}"
    else
        ls --color=auto -x
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e ""
        echo -e "${gl_zi}>>> 文件下载${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入下载链接（${gl_hong}0${gl_bai}退出）：")" url
        [[ "$url" == "0" ]] && { exit_script; }
        [[ -z "$url" ]] && { log_warn "链接不能为空"; continue; }

        download_single "$url"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
    done
}

main "$@"