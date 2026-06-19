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

log_info()  { echo -e "${gl_lan}[信息]${gl_bai} $*"; }
log_ok()    { echo -e "${gl_lv}[成功]${gl_bai} $*"; }
log_warn()  { echo -e "${gl_huang}[警告]${gl_bai} $*"; }
log_error() { echo -e "${gl_hong}[错误]${gl_bai} $*" >&2; }

handle_invalid_input() {
    echo -ne "\r\033[K${gl_huang}无效的输入,请重新输入! ${gl_zi} 1 ${gl_huang} 秒后返回"
    sleep 1
    echo -ne "\r\033[K${gl_lv}无效的输入,请重新输入! ${gl_zi}0${gl_lv} 秒后返回"
    sleep 0.5
    echo -ne "\r\033[K"
}

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    read -r -n 1 -s -p ""
    echo ""
}

show_help() {
    echo -e "${gl_lv}用法:${gl_bai} $0 ${gl_lan}<备份包路径>${gl_bai} ${gl_hui}[镜像名]${gl_bai}"
    echo -e "  或: ${gl_bai}$0 ${gl_hui}[镜像名]${gl_bai} ${gl_lan}<备份包路径>${gl_bai}"
    echo ""
    echo -e "${gl_lv}从备份包导入为 Docker 镜像${gl_bai}"
    echo ""
    echo -e "${gl_lv}参数:${gl_bai}"
    echo -e "  ${gl_lan}<备份包路径>${gl_bai}  要导入的 tar 备份文件"
    echo -e "  ${gl_hui}[镜像名]${gl_bai}      目标镜像名称（默认: restore_img:latest）"
    echo ""
    echo -e "${gl_lv}示例:${gl_bai}"
    echo -e "  ${gl_bai}$0 ${gl_lan}my-nginx_2025-01-01.tar${gl_bai}"
    echo -e "  ${gl_bai}$0 ${gl_lan}my-nginx_2025-01-01.tar${gl_bai} ${gl_hui}my-nginx:latest${gl_bai}"
    echo -e "  ${gl_bai}$0 ${gl_hui}my-nginx:latest${gl_bai} ${gl_lan}my-nginx_2025-01-01.tar${gl_bai}"
    exit 0
}

import_container() {
    local FILE="$1"
    local IMAGE="$2"

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_info "备份包: ${gl_bai}${FILE}"
    log_info "镜像名: ${gl_bai}${IMAGE}"

    if ! [[ -f "$FILE" ]]; then
        log_error "文件不存在: $FILE"
        return 1
    fi

    docker import "$FILE" "$IMAGE"
    log_ok "已导入镜像: ${gl_bai}${IMAGE}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
}

parse_args() {
    local FILE=""
    local IMAGE="restore_img:latest"

    if [[ -f "$1" ]]; then
        FILE="$1"
        [[ $# -ge 2 ]] && IMAGE="$2"
    elif [[ -f "$2" ]]; then
        IMAGE="$1"
        FILE="$2"
    else
        if [[ $# -ge 2 ]]; then
            FILE="$1"
            IMAGE="$2"
        else
            log_error "备份文件不存在: $1"
            exit 1
        fi
    fi

    import_container "$FILE" "$IMAGE"
}

interactive_mode() {
    while true; do
        clear
        echo -e "${gl_zi}>>> Docker 镜像导入${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bai}列出当前目录下可用的 tar 备份包:${gl_bai}"

        local files=()
        while IFS= read -r -d '' f; do
            files+=("$f")
        done < <(find . -maxdepth 1 -name "*.tar" -print0 2>/dev/null)

        if [[ ${#files[@]} -gt 0 ]]; then
            for i in "${!files[@]}"; do
                local name="${files[$i]}"
                echo -e "  ${gl_bufan}$((i+1)).${gl_bai} ${name#./}"
            done
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "  ${gl_bai}或直接输入备份包路径"
        else
            echo -e "  ${gl_huang}(当前目录无 tar 文件)${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        fi

        echo -e "  ${gl_hong}0.${gl_bai} 退出"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请选择备份包: ")" input

        if [[ "$input" == "0" || "$input" == "00" || "$input" == "000" ]]; then
            clear
            exit 0
        fi

        local selected_file=""
        if [[ -f "$input" ]]; then
            selected_file="$input"
        elif [[ "$input" =~ ^[0-9]+$ ]] && [[ "$input" -ge 1 ]] && [[ "$input" -le "${#files[@]}" ]]; then
            selected_file="${files[$((input-1))]}"
        else
            handle_invalid_input
            continue
        fi

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入镜像名 (回车默认 ${gl_huang}restore_img:latest${gl_bai}): ")" img_input
        local IMAGE="${img_input:-restore_img:latest}"

        import_container "$selected_file" "$IMAGE"
        
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        break
    done
}

main() {
    if [[ $# -ge 1 ]]; then
        parse_args "$@"
    else
        interactive_mode
    fi
}

main "$@"
