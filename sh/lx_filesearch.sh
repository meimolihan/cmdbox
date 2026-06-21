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
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n 1 -s -p ""
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

sleep_fractional() {
    local seconds=$1
    if sleep "$seconds" 2>/dev/null; then return 0; fi
    if command -v perl >/dev/null 2>&1; then perl -e "select(undef, undef, undef, $seconds)"; return 0; fi
    if command -v python3 >/dev/null 2>&1; then python3 -c "import time; time.sleep($seconds)"; return 0; fi
    if command -v python >/dev/null 2>&1; then python -c "import time; time.sleep($seconds)"; return 0; fi
    local int_seconds=$(echo "$seconds" | awk '{print int($1+0.999)}')
    sleep "$int_seconds"
}

search_file_here() {
    local keyword=""
    local non_interactive=false

    if [[ $# -gt 0 ]]; then
        keyword="$*"
        non_interactive=true
    fi

    while true; do
        if [[ "$non_interactive" == false ]]; then
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
            echo -e "${gl_zi}>>> 文件模糊搜索${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_huang}输入文件名的一部分，即可自动匹配查找所有相关文件。${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bai}请输入搜索关键词 (${gl_hong}0${gl_bai}退出): ")" keyword
            [[ "$keyword" == "0" ]] && { exit_script; }
            if [[ -z "$keyword" ]]; then
                echo -ne "${gl_huang}输入搜索关键词 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
                sleep_fractional 0.5
                echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
                sleep_fractional 0.6
                continue
            fi
        fi

        local here
        here="$(pwd)"
        local found=0

        if [[ "$non_interactive" == false ]]; then
            echo -e ""
            echo -e "${gl_huang}>>> 正在执行模糊搜索 \"${gl_lv}${keyword}${gl_huang}\" ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        fi

        local search_results=()

        while IFS= read -r -d '' file; do
            [[ -n "$file" ]] && search_results+=("$file")
        done < <(find "$here" -iname "*${keyword}*" -type f -print0 2>/dev/null)

        while IFS= read -r -d '' file; do
            if [[ -n "$file" ]] && [[ ! " ${search_results[@]} " =~ " ${file} " ]]; then
                search_results+=("$file")
            fi
        done < <(find "$here" -type f -iregex ".*${keyword}.*" -print0 2>/dev/null)

        if command -v ag &>/dev/null; then
            while IFS= read -r -d '' file; do
                file="${file#./}"
                if [[ -n "$file" ]] && [[ ! " ${search_results[@]} " =~ " ${file} " ]]; then
                    search_results+=("$here/$file")
                fi
            done < <(cd "$here" && ag -l -g ".*${keyword}.*" . 2>/dev/null | tr '\n' '\0')
        fi

        local unique_results=()
        if [[ ${#search_results[@]} -gt 0 ]]; then
            while IFS= read -r -d '' file; do
                [[ -n "$file" ]] && unique_results+=("$file")
            done < <(printf "%s\0" "${search_results[@]}" | sort -uz)
        fi

        if [[ ${#unique_results[@]} -gt 0 ]]; then
            if [[ "$non_interactive" == true ]]; then
                echo "找到 ${#unique_results[@]} 个匹配的文件："
            else
                log_ok "找到 ${#unique_results[@]} 个匹配的文件："
            fi
            echo
            for file in "${unique_results[@]}"; do
                local abs_path
                abs_path="$(readlink -f "$file" 2>/dev/null || echo "$file")"

                if [[ "$non_interactive" == true ]]; then
                    echo "$abs_path"
                else
                    echo -e "${gl_lv}${abs_path}${gl_bai}"

                    if [[ -r "$file" ]]; then
                        local file_info size time_info permissions
                        file_info=$(ls -lh "$file" 2>/dev/null)
                        if [[ $? -eq 0 ]]; then
                            size=$(echo "$file_info" | awk '{print $5}')
                            time_info=$(ls -l --time-style=long-iso "$file" 2>/dev/null | awk 'NR==1 {print $6, $7}')
                            permissions=$(ls -l "$file" 2>/dev/null | awk 'NR==1 {print $1}')
                            echo -e "  ${gl_hui}权限: $permissions | 大小: $size | 修改: $time_info${gl_bai}"

                            if file "$file" 2>/dev/null | grep -q "text"; then
                                local preview
                                preview=$(head -1 "$file" 2>/dev/null | cut -c-50)
                                [[ -n "$preview" ]] && echo -e "  ${gl_zi}预览: ${preview} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                            fi
                        else
                            echo -e "  ${gl_hui}[无法获取文件信息]${gl_bai}"
                        fi
                    else
                        echo -e "  ${gl_hui}[无法读取文件详细信息]${gl_bai}"
                    fi
                    echo
                fi
                ((found++))
            done
        else
            if [[ "$non_interactive" == true ]]; then
                echo "未找到包含 \"${keyword}\" 的文件。"
            else
                log_warn "未找到包含 \"${keyword}\" 的文件。"
                log_info "搜索建议："
                echo -e "  ${gl_hui}• 尝试不同的关键词"
                echo -e "  ${gl_hui}• 使用更通用的词汇"
                echo -e "  ${gl_hui}• 检查文件是否在其他位置${gl_bai}"
                log_info "当前目录下的文件："
                find "$here" -maxdepth 1 -type f -name "*" | head -5 | while read -r similar; do
                    echo -e "  ${gl_hui}$(basename "$similar")${gl_bai}"
                done
            fi
        fi

        if [[ "$non_interactive" == true ]]; then
            break
        fi

	    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
    done
}

search_file_here "$@"