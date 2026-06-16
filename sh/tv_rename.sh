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

TARGET_DIR="${1:-.}"

if ! TARGET_DIR=$(realpath -- "$TARGET_DIR" 2>/dev/null); then
    echo -e "${gl_hong}[错误]${gl_bai} 路径解析失败，请检查路径格式${gl_end}"
    exit 1
fi

if [[ ! -d "$TARGET_DIR" ]]; then
    echo -e "${gl_hong}[错误]${gl_bai} 目录不存在：$TARGET_DIR${gl_end}"
    exit 1
fi

if ! cd -- "$TARGET_DIR" 2>/dev/null; then
    echo -e "${gl_hong}[错误]${gl_bai} 无法进入目录，权限不足：$TARGET_DIR${gl_end}"
    exit 1
fi

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

cancel_return() {
    local menu_name="${1:-上一级选单}"
    echo -ne "${gl_lv}即将返回 ${gl_huang}${menu_name} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo ""
    clear
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

handle_invalid_input() {
    echo -ne "\r\033[K${gl_huang}无效的输入,请重新输入! ${gl_zi} 1 ${gl_huang} 秒后返回"
    sleep_fractional 1
    echo -ne "\r\033[K${gl_lv}无效的输入,请重新输入! ${gl_zi}0${gl_lv} 秒后返回"
    sleep_fractional 0.5
    echo -ne "\r\033[K"
    continue
}

go_parent_directory() {
    if [[ "$(pwd)" != "/" ]]; then
        local current_path="$(pwd)"
        cd ..
        echo -e "${gl_lv}已返回上级目录: ${gl_huang}$(pwd) ${gl_bai}"
        exit_animation
    else
        echo -e "${gl_huang}已经在根目录: ${gl_hong}/ ${gl_bai}"
        exit_animation
    fi
}

batch_rename_files() {
    while true; do
        local current_dir=$(pwd)
        local files=()
        
        while IFS= read -r -d $'\0' file; do
            if [[ -f "$file" ]]; then
                files+=("$file")
            fi
        done < <(find "$current_dir" -maxdepth 1 -type f -print0 2>/dev/null)
        
        local file_count=${#files[@]}
        
        clear
        echo -e ""
        echo -e "${gl_zi}>>> 批量重命名文件${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        if [[ $file_count -eq 0 ]]; then
            echo -e "${gl_huang}当前目录下没有找到任何文件${gl_bai}"
        else
            echo -e "${gl_bai}当前目录: ${gl_lv}${current_dir}${gl_bai}  ${gl_bai}文件数量: ${gl_lv}${file_count}${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            
            if [[ $file_count -le 20 ]]; then
                echo -e "${gl_bai}文件列表:${gl_bai}"
                for i in "${!files[@]}"; do
                    local file="${files[$i]}"
                    local filename=$(basename "$file")
                    echo -e "  ${gl_huang}$((i + 1))${gl_bai}. ${gl_bufan}${filename}${gl_bai}"
                done
            else
                echo -e "${gl_bai}显示前 20 个文件:${gl_bai}"
                for i in {0..19}; do
                    if [[ $i -lt $file_count ]]; then
                        local file="${files[$i]}"
                        local filename=$(basename "$file")
                        echo -e "  ${gl_huang}$((i + 1))${gl_bai}. ${gl_bufan}${filename}${gl_bai}"
                    fi
                done
                echo -e "  ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}还有 $((file_count - 20)) 个文件${gl_bai}"
            fi
        fi
        
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}添加前缀              ${gl_bufan}2.  ${gl_bai}添加后缀"
        echo -e "${gl_bufan}3.  ${gl_bai}替换字符串            ${gl_bufan}4.  ${gl_bai}序号重命名"
        echo -e "${gl_bufan}5.  ${gl_bai}大小写转换            ${gl_bufan}6.  ${gl_bai}移除字符"
        echo -e "${gl_bufan}7.  ${gl_bai}删除所有空格"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请选择重命名模式: ")" rename_mode

        case "$rename_mode" in
        1) rename_files_add_prefix ;;
        2) rename_files_add_suffix ;;
        3) rename_files_replace_string ;;
        4) rename_files_sequential ;;
        5) rename_files_change_case ;;
        6) rename_files_remove_chars ;;
        7) rename_files_remove_spaces ;;
        0) cancel_return; return ;;
        *) handle_invalid_input ;;
        esac
    done
}

rename_files_add_prefix() {
    local current_dir=$(pwd)
    local files=()
    while IFS= read -r -d $'\0' file; do
        if [[ -f "$file" ]]; then
            files+=("$file")
        fi
    done < <(find "$current_dir" -maxdepth 1 -type f -print0 2>/dev/null)
    
    local file_count=${#files[@]}
    
    if [[ $file_count -eq 0 ]]; then
        echo -e "${gl_huang}当前目录下没有找到任何文件${gl_bai}"
        exit_animation
        return
    fi
    
    echo -e ""
    echo -e "${gl_zi}>>> 批量添加前缀${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -e -p "$(echo -e "${gl_bai}请输入要添加的前缀(${gl_huang}0${gl_bai}返回): ")" prefix
    if [[ -z "$prefix" ]]; then
        log_warn "前缀不能为空"
        exit_animation
        return
    fi

    [ "$prefix" == "0" ] && { cancel_return "上一级选单"; return 1; }  

    echo -e "${gl_bai}预览重命名结果:${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local rename_count=0
    local rename_files=()
    for file in "${files[@]}"; do
        local filename=$(basename "$file")
        local dir=$(dirname "$file")
        local newname="${dir}/${prefix}${filename}"

        if [[ "$filename" != "${prefix}${filename}" ]]; then
            rename_files+=("$file:$newname")
            echo -e "  ${gl_bufan}${filename}${gl_bai} -> ${gl_lv}${prefix}${filename}${gl_bai}"
        fi
    done

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}将重命名 ${gl_lv}${#rename_files[@]}${gl_bai} 个文件${gl_bai}"

    if [[ ${#rename_files[@]} -gt 0 ]]; then
        read -r -e -p "$(echo -e "${gl_bai}确认执行重命名? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
        [ "$confirm" = "0" ] && { cancel_return "上一级选单"; return 1; }  
        case "$confirm" in
        [Yy])
            for rename_pair in "${rename_files[@]}"; do
                IFS=':' read -r old_name new_name <<<"$rename_pair"
                if mv "$old_name" "$new_name" 2>/dev/null; then
                    ((rename_count++))
                    log_info "已重命名: ${gl_bufan}$(basename "$old_name")${gl_bai} -> ${gl_lv}$(basename "$new_name")${gl_bai}"
                else
                    log_error "重命名失败: ${gl_bufan}$(basename "$old_name")${gl_bai}"
                fi
            done
            ;;
        [Nn])
            log_warn "操作已取消"
            ;;
        *) handle_y_n ;;
        esac
    else
        log_warn "没有文件需要重命名（可能文件已有相同前缀）"
    fi

    if [[ $rename_count -gt 0 ]]; then
        log_ok "成功重命名 ${rename_count} 个文件"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

rename_files_add_suffix() {
    local current_dir=$(pwd)
    local files=()
    while IFS= read -r -d $'\0' file; do
        if [[ -f "$file" ]]; then
            files+=("$file")
        fi
    done < <(find "$current_dir" -maxdepth 1 -type f -print0 2>/dev/null)
    
    local file_count=${#files[@]}
    
    if [[ $file_count -eq 0 ]]; then
        echo -e "${gl_huang}当前目录下没有找到任何文件${gl_bai}"
        exit_animation
        return
    fi
    
    echo -e ""
    echo -e "${gl_zi}>>> 批量添加后缀${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -e -p "$(echo -e "${gl_bai}请输入要添加的后缀 (不含扩展名)(${gl_huang}0${gl_bai}返回): ")" suffix
    if [[ -z "$suffix" ]]; then
        log_warn "后缀不能为空"
        exit_animation
        return
    fi

    [[ "$suffix" == "0" ]] && { cancel_return "上一级选单"; return 1; }

    echo -e "${gl_bai}预览重命名结果:${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local rename_count=0
    local rename_files=()
    for file in "${files[@]}"; do
        local filename=$(basename "$file")
        local dir=$(dirname "$file")
        local newname

        if [[ "$filename" =~ \. ]]; then
            local ext="${filename##*.}"
            local name="${filename%.*}"
            if [[ "$name" == "$ext" ]]; then
                newname="${dir}/${filename}${suffix}"
            else
                newname="${dir}/${name}${suffix}.${ext}"
            fi
        else
            newname="${dir}/${filename}${suffix}"
        fi

        if [[ "$filename" != "$(basename "$newname")" ]]; then
            rename_files+=("$file:$newname")
            echo -e "  ${gl_bufan}${filename}${gl_bai} -> ${gl_lv}$(basename "$newname")${gl_bai}"
        fi
    done

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}将重命名 ${gl_lv}${#rename_files[@]}${gl_bai} 个文件${gl_bai}"

    if [[ ${#rename_files[@]} -gt 0 ]]; then
        read -r -e -p "$(echo -e "${gl_bai}确认执行重命名? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
        case "$confirm" in
        [Yy])
            for rename_pair in "${rename_files[@]}"; do
                IFS=':' read -r old_name new_name <<<"$rename_pair"
                if mv "$old_name" "$new_name" 2>/dev/null; then
                    ((rename_count++))
                    log_info "已重命名: ${gl_bufan}$(basename "$old_name")${gl_bai} -> ${gl_lv}$(basename "$new_name")${gl_bai}"
                else
                    log_error "重命名失败: ${gl_bufan}$(basename "$old_name")${gl_bai}"
                fi
            done
            ;;
        [Nn])
            log_warn "操作已取消"
            ;;
        *) handle_y_n ;;
        esac
    else
        log_warn "没有文件需要重命名"
    fi

    if [[ $rename_count -gt 0 ]]; then
        log_ok "成功重命名 ${rename_count} 个文件"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

rename_files_replace_string() {
    local current_dir=$(pwd)
    local files=()
    while IFS= read -r -d $'\0' file; do
        if [[ -f "$file" ]]; then
            files+=("$file")
        fi
    done < <(find "$current_dir" -maxdepth 1 -type f -print0 2>/dev/null)
    
    local file_count=${#files[@]}
    
    if [[ $file_count -eq 0 ]]; then
        echo -e "${gl_huang}当前目录下没有找到任何文件${gl_bai}"
        exit_animation
        return
    fi
    
    echo -e ""
    echo -e "${gl_zi}>>> 替换字符${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -e -p "$(echo -e "${gl_bai}请输入要替换的字符串(${gl_huang}0${gl_bai}返回): ")" old_str

    [[ "$old_str" == "0" ]] && { cancel_return "上一级选单"; return 1; }

    if [[ -z "$old_str" ]]; then
        log_warn "要替换的字符串不能为空"
        exit_animation
        return
    fi

    read -r -e -p "$(echo -e "${gl_bai}请输入替换为的字符串: ")" new_str
    [ "$new_str" == "0" ] && { cancel_return "上一级选单"; return 1; }   

    echo -e "${gl_bai}预览重命名结果:${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local rename_count=0
    local rename_files=()
    for file in "${files[@]}"; do
        local filename=$(basename "$file")
        local dir=$(dirname "$file")
        local newname="${dir}/${filename//$old_str/$new_str}"

        if [[ "$filename" != "$(basename "$newname")" ]]; then
            rename_files+=("$file:$newname")
            echo -e "  ${gl_bufan}${filename}${gl_bai} -> ${gl_lv}$(basename "$newname")${gl_bai}"
        fi
    done

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}将重命名 ${gl_lv}${#rename_files[@]}${gl_bai} 个文件${gl_bai}"

    if [[ ${#rename_files[@]} -gt 0 ]]; then
        read -r -e -p "$(echo -e "${gl_bai}确认执行重命名? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
        [ "$confirm" == "0" ] && { cancel_return "上一级选单"; return 1; }  
        case "$confirm" in
        [Yy])
            for rename_pair in "${rename_files[@]}"; do
                IFS=':' read -r old_name new_name <<<"$rename_pair"
                if mv "$old_name" "$new_name" 2>/dev/null; then
                    ((rename_count++))
                    log_info "已重命名: ${gl_bufan}$(basename "$old_name")${gl_bai} -> ${gl_lv}$(basename "$new_name")${gl_bai}"
                else
                    log_error "重命名失败: ${gl_bufan}$(basename "$old_name")${gl_bai}"
                fi
            done
            ;;
        [Nn])
            log_warn "操作已取消"
            ;;
        *) handle_y_n ;;
        esac
    else
        log_warn "没有找到匹配的字符串 '$old_str'"
    fi

    if [[ $rename_count -gt 0 ]]; then
        log_ok "成功重命名 ${rename_count} 个文件"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

rename_files_sequential() {
    local current_dir=$(pwd)
    local files=()
    while IFS= read -r -d $'\0' file; do
        if [[ -f "$file" ]]; then
            files+=("$file")
        fi
    done < <(find "$current_dir" -maxdepth 1 -type f -print0 2>/dev/null)
    
    local file_count=${#files[@]}
    
    if [[ $file_count -eq 0 ]]; then
        echo -e "${gl_huang}当前目录下没有找到任何文件${gl_bai}"
        exit_animation
        return
    fi
    
    echo -e ""
    echo -e "${gl_huang}>>> 序号重命名模板说明:${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "  ${gl_huang}###${gl_bai} 表示三位数字序号 (如: 001, 002)"
    echo -e "  ${gl_huang}##${gl_bai}  表示两位数字序号 (如: 01, 02)"
    echo -e "  ${gl_huang}#${gl_bai}   表示一位数字序号 (如: 1, 2)"
    echo -e "  ${gl_huang}%d${gl_bai}  表示数字序号 (如: 1, 2, 3)"
    echo -e ""
    echo -e "${gl_bai}示例:${gl_bai}"
    echo -e "  ${gl_huang}image-###.jpg${gl_bai}   -> ${gl_lv}image-001.jpg, image-002.jpg, ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "  ${gl_huang}document_##.txt${gl_bai} -> ${gl_lv}document_01.txt, document_02.txt, ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "  ${gl_huang}file_#.pdf${gl_bai}      -> ${gl_lv}file_1.pdf, file_2.pdf, ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    echo -e ""
    echo -e "${gl_zi}>>> 序号重命名${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -e -p "$(echo -e "${gl_bai}请输入文件名模板(${gl_huang}0${gl_bai}返回): ")" template
    [[ "$template" == "0" ]] && { cancel_return "上一级选单"; return 1; }

    if [[ -z "$template" ]]; then
        log_warn "模板不能为空"
        exit_animation
        return
    fi

    echo -e "${gl_bai}预览重命名结果:${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local rename_count=0
    local rename_files=()
    local idx=1

    for file in "${files[@]}"; do
        local dir=$(dirname "$file")
        local filename=$(basename "$file")
        local ext="${filename##*.}"
        local name_without_ext="${filename%.*}"
        
        if [[ "$filename" =~ \. ]] && [[ "$name_without_ext" != "$ext" ]]; then
            local newname_template="${template%.*}"
            if [[ -z "$newname_template" ]]; then
                newname_template="$template"
            fi
            
            if [[ "$newname_template" =~ "###" ]]; then
                newname_template="${newname_template//###/$(printf "%03d" $idx)}"
            elif [[ "$newname_template" =~ "##" ]]; then
                newname_template="${newname_template//##/$(printf "%02d" $idx)}"
            elif [[ "$newname_template" =~ "#" ]]; then
                newname_template="${newname_template//#/$idx}"
            elif [[ "$newname_template" =~ "%d" ]]; then
                newname_template="${newname_template//%d/$idx}"
            else
                newname_template="${newname_template}_${idx}"
            fi
            
            local newname="${dir}/${newname_template}.${ext}"
        else
            local newname_template="$template"
            
            if [[ "$newname_template" =~ "###" ]]; then
                newname_template="${newname_template//###/$(printf "%03d" $idx)}"
            elif [[ "$newname_template" =~ "##" ]]; then
                newname_template="${newname_template//##/$(printf "%02d" $idx)}"
            elif [[ "$newname_template" =~ "#" ]]; then
                newname_template="${newname_template//#/$idx}"
            elif [[ "$newname_template" =~ "%d" ]]; then
                newname_template="${newname_template//%d/$idx}"
            else
                newname_template="${newname_template}_${idx}"
            fi
            
            local newname="${dir}/${newname_template}"
        fi
        
        rename_files+=("$file:$newname")
        echo -e "  ${gl_bufan}${filename}${gl_bai} -> ${gl_lv}$(basename "$newname")${gl_bai}"
        ((idx++))
    done

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}将重命名 ${gl_lv}${#rename_files[@]}${gl_bai} 个文件${gl_bai}"

    if [[ ${#rename_files[@]} -gt 0 ]]; then
        read -r -e -p "$(echo -e "${gl_bai}确认执行重命名? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
        [ "$confirm" == "0" ] && { cancel_return "上一级选单"; return 1; }
        case "$confirm" in
        [Yy])
            for rename_pair in "${rename_files[@]}"; do
                IFS=':' read -r old_name new_name <<<"$rename_pair"
                if mv "$old_name" "$new_name" 2>/dev/null; then
                    ((rename_count++))
                    log_info "已重命名: ${gl_bufan}$(basename "$old_name")${gl_bai} -> ${gl_lv}$(basename "$new_name")${gl_bai}"
                else
                    log_error "重命名失败: ${gl_bufan}$(basename "$old_name")${gl_bai}"
                fi
            done
            ;;
        [Nn])
            log_warn "操作已取消"
            ;;
        *) handle_y_n ;;
        esac
    fi

    if [[ $rename_count -gt 0 ]]; then
        log_ok "成功重命名 ${rename_count} 个文件"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

rename_files_change_case() {
    local current_dir=$(pwd)
    local files=()
    while IFS= read -r -d $'\0' file; do
        if [[ -f "$file" ]]; then
            files+=("$file")
        fi
    done < <(find "$current_dir" -maxdepth 1 -type f -print0 2>/dev/null)
    
    local file_count=${#files[@]}
    
    if [[ $file_count -eq 0 ]]; then
        echo -e "${gl_huang}当前目录下没有找到任何文件${gl_bai}"
        exit_animation
        return
    fi
    
    while true; do
        echo -e ""
        echo -e "${gl_zi}>>> 大小写转换${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}转为小写              ${gl_bufan}2.  ${gl_bai}转为大写"
        echo -e "${gl_bufan}3.  ${gl_bai}首字母大写            ${gl_bufan}4.  ${gl_bai}单词首字母大写"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请选择转换模式: ")" case_mode

        case "$case_mode" in
        0) cancel_return;  return  ;;
        1 | 2 | 3 | 4)
            local rename_count=0
            local rename_files=()

            echo -e "${gl_bai}预览重命名结果:${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

            for file in "${files[@]}"; do
                local filename=$(basename "$file")
                local dir=$(dirname "$file")
                local newname

                case "$case_mode" in
                1) newname="${dir}/${filename,,}" ;;
                2) newname="${dir}/${filename^^}" ;;
                3) newname="${dir}/${filename^}" ;;
                4)
                    newname="$filename"
                    if [[ "$newname" =~ [a-zA-Z] ]]; then
                        newname=$(echo "$newname" | sed -E 's/(^|_)([a-z])/\1\u\2/g' 2>/dev/null || echo "$newname")
                    fi
                    newname="${dir}/${newname}"
                    ;;
                esac

                if [[ "$filename" != "$(basename "$newname")" ]]; then
                    rename_files+=("$file:$newname")
                    echo -e "  ${gl_bufan}${filename}${gl_bai} -> ${gl_lv}$(basename "$newname")${gl_bai}"
                fi
            done

            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_bai}将重命名 ${gl_lv}${#rename_files[@]}${gl_bai} 个文件${gl_bai}"

            if [[ ${#rename_files[@]} -gt 0 ]]; then
                read -r -e -p "$(echo -e "${gl_bai}确认执行重命名? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
                [ "$confirm" = "0" ] && { cancel_return "上一级选单"; continue; }
                case "$confirm" in
                [Yy])
                    for rename_pair in "${rename_files[@]}"; do
                        IFS=':' read -r old_name new_name <<<"$rename_pair"
                        if mv "$old_name" "$new_name" 2>/dev/null; then
                            ((rename_count++))
                            log_info "已重命名: ${gl_bufan}$(basename "$old_name")${gl_bai} -> ${gl_lv}$(basename "$new_name")${gl_bai}"
                        else
                            log_error "重命名失败: ${gl_bufan}$(basename "$old_name")${gl_bai}"
                        fi
                    done
                    ;;
                [Nn])
                    log_warn "操作已取消"
                    ;;
                *) handle_y_n ;;
                esac
            else
                log_warn "没有文件需要转换大小写"
            fi

            if [[ $rename_count -gt 0 ]]; then
                log_ok "成功重命名 ${rename_count} 个文件"
            fi
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            return
            ;;
        *) handle_invalid_input ;;
        esac
    done
}

rename_files_remove_chars() {
    local current_dir=$(pwd)
    local files=()
    while IFS= read -r -d $'\0' file; do
        if [[ -f "$file" ]]; then
            files+=("$file")
        fi
    done < <(find "$current_dir" -maxdepth 1 -type f -print0 2>/dev/null)
    
    local file_count=${#files[@]}
    
    if [[ $file_count -eq 0 ]]; then
        echo -e "${gl_huang}当前目录下没有找到任何文件${gl_bai}"
        exit_animation
        return
    fi
    
    echo -e ""
    echo -e "${gl_zi}>>> 移除字符${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -e -p "$(echo -e "${gl_bai}请输入要移除的字符或模式(${gl_huang}0${gl_bai}返回): ")" remove_pattern

    [[ "$remove_pattern" == "0" ]] && { cancel_return "上一级选单"; return 1; }

    if [[ -z "$remove_pattern" ]]; then
        log_warn "要移除的字符不能为空"
        exit_animation
        return
    fi

    echo -e "${gl_bai}预览重命名结果:${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local rename_count=0
    local rename_files=()
    for file in "${files[@]}"; do
        local filename=$(basename "$file")
        local dir=$(dirname "$file")
        local newname="${dir}/${filename//$remove_pattern/}"

        if [[ "$filename" != "$(basename "$newname")" ]]; then
            rename_files+=("$file:$newname")
            echo -e "  ${gl_bufan}${filename}${gl_bai} -> ${gl_lv}$(basename "$newname")${gl_bai}"
        fi
    done

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}将重命名 ${gl_lv}${#rename_files[@]}${gl_bai} 个文件${gl_bai}"

    if [[ ${#rename_files[@]} -gt 0 ]]; then
        read -r -e -p "$(echo -e "${gl_bai}确认执行重命名? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
        [[ "$confirm" == "0" ]] && { cancel_return "上一级选单"; return 1; }
        case "$confirm" in
        [Yy])
            for rename_pair in "${rename_files[@]}"; do
                IFS=':' read -r old_name new_name <<<"$rename_pair"
                if mv "$old_name" "$new_name" 2>/dev/null; then
                    ((rename_count++))
                    log_info "已重命名: ${gl_bufan}$(basename "$old_name")${gl_bai} -> ${gl_lv}$(basename "$new_name")${gl_bai}"
                else
                    log_error "重命名失败: ${gl_bufan}$(basename "$old_name")${gl_bai}"
                fi
            done
            ;;
        [Nn])
            log_warn "操作已取消"
            ;;
        *) handle_y_n ;;
        esac
    else
        log_warn "没有找到匹配的字符 '$remove_pattern'"
    fi

    if [[ $rename_count -gt 0 ]]; then
        log_ok "成功重命名 ${rename_count} 个文件"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

rename_files_remove_spaces() {
    local current_dir=$(pwd)
    local files=()
    while IFS= read -r -d $'\0' file; do
        if [[ -f "$file" ]]; then
            files+=("$file")
        fi
    done < <(find "$current_dir" -maxdepth 1 -type f -print0 2>/dev/null)
    
    local file_count=${#files[@]}
    
    if [[ $file_count -eq 0 ]]; then
        echo -e "${gl_huang}当前目录下没有找到任何文件${gl_bai}"
        exit_animation
        return
    fi
    
    echo -e ""
    echo -e "${gl_zi}>>> 删除文件名中的所有空格${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    echo -e "${gl_bai}注意: 此操作将删除文件名中的所有空格字符${gl_bai}"
    echo -e "${gl_bai}包括文件名开头、中间和结尾的空格${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    echo -e "${gl_bai}预览重命名结果:${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local rename_count=0
    local rename_files=()
    for file in "${files[@]}"; do
        local filename=$(basename "$file")
        local dir=$(dirname "$file")
        local newname="${dir}/${filename// /}"

        if [[ "$filename" != "$(basename "$newname")" ]]; then
            rename_files+=("$file:$newname")
            echo -e "  ${gl_bufan}${filename}${gl_bai} -> ${gl_lv}$(basename "$newname")${gl_bai}"
        fi
    done

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}将重命名 ${gl_lv}${#rename_files[@]}${gl_bai} 个文件${gl_bai}"

    if [[ ${#rename_files[@]} -gt 0 ]]; then
        read -r -e -p "$(echo -e "${gl_bai}确认执行重命名? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
        [[ "$confirm" == "0" ]] && { cancel_return "上一级选单"; return 1; }
        case "$confirm" in
        [Yy])
            for rename_pair in "${rename_files[@]}"; do
                IFS=':' read -r old_name new_name <<<"$rename_pair"
                if mv "$old_name" "$new_name" 2>/dev/null; then
                    ((rename_count++))
                    log_info "已重命名: ${gl_bufan}$(basename "$old_name")${gl_bai} -> ${gl_lv}$(basename "$new_name")${gl_bai}"
                else
                    log_error "重命名失败: ${gl_bufan}$(basename "$old_name")${gl_bai}"
                fi
            done
            ;;
        [Nn])
            log_warn "操作已取消"
            ;;
        *) handle_y_n ;;
        esac
    else
        log_warn "没有文件名包含空格"
    fi

    if [[ $rename_count -gt 0 ]]; then
        log_ok "成功重命名 ${rename_count} 个文件"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

show_directory_list() {
    local base_path="${1:-.}"
    local items_per_line="${2:-4}"
    local show_hidden="${3:-false}"
    local exit_on_empty="${4:-true}"
    local return_array_var="$5"

    local dir_array=()
    for dir in "$base_path"/*/; do
        [[ -d "$dir" ]] || continue
        local dir_name
        dir_name=$(basename "$dir")

        if [[ "$show_hidden" == "true" || "$show_hidden" == "1" ]]; then
            dir_array+=("$dir_name")
        elif [[ ! "$dir_name" =~ ^\. ]]; then
            dir_array+=("$dir_name")
        fi
    done

    if [[ ${#dir_array[@]} -eq 0 ]]; then
        echo -e "${gl_huang}当前目录为空${gl_bai}"
        if [[ "$exit_on_empty" == "true" || "$exit_on_empty" == "1" ]]; then
            if [[ -n "$return_array_var" ]]; then
                eval "$return_array_var=()"
            fi
            return 0
        fi
    fi

    mapfile -t dir_array < <(printf '%s\n' "${dir_array[@]}" | sort)

    if [[ -n "$return_array_var" ]]; then
        eval "$return_array_var=($(printf '%q ' "${dir_array[@]}"))"
    fi

    get_display_width() {
        local str="$1"
        local width=0
        local len=${#str}

        for ((i = 0; i < len; i++)); do
            local char="${str:i:1}"
            local code=$(printf '%d' "'$char")

            if [[ $code -lt 128 ]]; then
                ((width++))
            elif [[ $code -ge 0x4E00 && $code -le 0x9FFF ]] ||
                [[ $code -ge 0x3400 && $code -le 0x4DBF ]] ||
                [[ $code -ge 0x20000 && $code -le 0x2A6DF ]] ||
                [[ $code -ge 0x2A700 && $code -le 0x2B73F ]] ||
                [[ $code -ge 0x2B740 && $code -le 0x2B81F ]] ||
                [[ $code -ge 0x2B820 && $code -le 0x2CEAF ]] ||
                [[ $code -ge 0xF900 && $code -le 0xFAFF ]] ||
                [[ $code -ge 0x2F800 && $code -le 0x2FA1F ]]; then
                ((width += 2))
            elif [[ $code -ge 0x3000 && $code -le 0x303F ]] ||
                [[ $code -ge 0xFF00 && $code -le 0xFFEF ]]; then
                ((width += 2))
            else
                ((width += 2))
            fi
        done

        echo $width
    }

    local max_display_width=0
    for d in "${dir_array[@]}"; do
        local width
        width=$(get_display_width "$d")
        (($width > max_display_width)) && max_display_width=$width
    done

    local column_width=$((max_display_width + 4))

    local count=0
    for i in "${!dir_array[@]}"; do
        count=$((i + 1))

        local index_str
        printf -v index_str "%2d." "$count"

        local current_width
        current_width=$(get_display_width "${dir_array[i]}")

        local padding=$((column_width - current_width))

        printf "${gl_bufan}%s${gl_bai} %s" "$index_str" "${dir_array[i]}"

        for ((s = 0; s < padding; s++)); do
            printf " "
        done

        if (((i + 1) % items_per_line == 0)); then
            echo
        fi
    done

    if ((count % items_per_line != 0)); then
        echo
    fi
    return 0
}

enter_directory() {
    local current_path="$(pwd)"
    local return_target="${1:-电视剧文件重命名}"
    clear
    local dirs=()
    echo -e "${gl_huang}>>> 当前目录子目录列表：${gl_bai}(${gl_lv}$current_path${gl_bai})"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    show_directory_list "." 2 false true "dirs"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e ""
    echo -e "${gl_zi}>>> 进入电视剧所在目录${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}请输入 ${gl_huang}序号${gl_bai} ${gl_lv}目录名${gl_bai} ${gl_lan}路径${gl_bai} (${gl_hui}..上级${gl_bai} ${gl_zi}~家${gl_bai} ${gl_hong}/根${gl_bai}) 或 ${gl_huang}0${gl_bai}返回: ")" input

    if [[ -z "$input" ]]; then
        cancel_empty
        continue
    fi
    
    if [[ "$input" == "0" ]]; then
        cancel_return "$return_target"
        continue
    fi

    if [[ "$input" =~ ^[0-9]+$ ]]; then
        if [[ -z "${dirs[@]}" ]]; then
            echo -e "${gl_hong}当前目录没有可用的子目录列表，无法通过序号选择${gl_bai}"
            exit_animation
            return 1
        fi

        if [[ "$input" -ge 1 ]] && [[ "$input" -le ${#dirs[@]} ]]; then
            local selected_dir="${dirs[$((input - 1))]}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_bai}已选择: ${gl_lv}$selected_dir${gl_bai}"

            if cd "$selected_dir" 2>/dev/null; then
                echo -e "${gl_bai}成功进入目录: ${gl_lv}$(pwd)${gl_bai}"
            else
                echo -e "${gl_hong}无法进入目录: $selected_dir${gl_bai}"
                echo -e "${gl_hong}可能的原因：${gl_bai}"
                echo -e "${gl_huang}1. 目录不存在${gl_bai}"
                echo -e "${gl_huang}2. 没有访问权限${gl_bai}"
                echo -e "${gl_huang}3. 输入路径有误${gl_bai}"
            fi
        else
            echo -e "${gl_hong}序号 $input 超出范围 (1-${#dirs[@]})${gl_bai}"
        fi
    else
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_lv}尝试进入: $input${gl_bai}"

        local target_path="$input"
        if [[ "$input" == ".." ]]; then
            target_path=".."
        elif [[ "$input" == "~" ]]; then
            target_path=~
        elif [[ "$input" == "/" ]]; then
            target_path="/"
        fi

        if cd "$target_path" 2>/dev/null; then
            local new_path="$(pwd)"
            echo -e "${gl_lv}成功进入目录: $new_path${gl_bai}"

            if [[ ! -d "$new_path" ]]; then
                echo -e "${gl_hong}警告：目标不是一个有效的目录${gl_bai}"
                cd "$current_path" 2>/dev/null
            fi
        else
            echo -e "${gl_hong}无法进入目录: $input${gl_bai}"
            echo -e "${gl_hong}可能的原因：${gl_bai}"
            echo -e "${gl_huang}1. 路径不存在${gl_bai}"
            echo -e "${gl_huang}2. 没有访问权限${gl_bai}"
            echo -e "${gl_huang}3. 不是有效的目录${gl_bai}"
            echo -e "${gl_huang}4. 路径格式错误${gl_bai}"

            if [[ -e "$input" ]] && [[ ! -d "$input" ]]; then
                echo -e "${gl_huang}注意：'$input' 是一个文件，不是目录${gl_bai}"
            fi
        fi
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_huang}即将进入 ${gl_lv}$(basename "$(pwd)")${gl_huang} 目录 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    sleep_fractional 1.6
    return 0
}

tv_rename_ultimate() {

    quick_rename() {
        clear
        echo -e "${gl_zi}>>> 快速重命名（智能识别版）${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        local VIDEO_EXTS=("mp4" "avi" "mov" "wmv" "flv" "webm" "m4v" "mpg" "mpeg" "kvm")
        
        local ext_pattern=""
        for ext in "${VIDEO_EXTS[@]}"; do
            if [ -z "$ext_pattern" ]; then
                ext_pattern="-name \"*.$ext\""
            else
                ext_pattern="$ext_pattern -o -name \"*.$ext\""
            fi
        done
        
        log_info "扫描当前目录视频文件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        local files=()
        while IFS= read -r file; do
            if [ -f "$file" ]; then
                files+=("$file")
            fi
        done < <(eval "find . -maxdepth 1 -type f \( $ext_pattern \) 2>/dev/null" | sort -V)
        
        if [ ${#files[@]} -eq 0 ]; then
            log_error "未找到视频文件！"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            exit_animation
            return
        fi
        
        echo -e "${gl_bai}找到 ${#files[@]} 个视频文件:${gl_bai}"
        for ((i = 0; i < ${#files[@]}; i++)); do
            local filename=$(basename -- "${files[$i]}")
            echo -e "  ${gl_bufan}$(safe_printf "%02d" $((i + 1))).${gl_bai} $filename"
        done
        
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        echo -e "${gl_huang}正在智能识别剧集信息 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        local prefix=""
        local season="01"
        local start_ep="1"
        local detected_info=0
        
        local candidates=()
        local counts=()
        local total_files=${#files[@]}
        
        for file in "${files[@]}"; do
            local filename=$(basename -- "$file")
            if command -v extract_prefix_candidate >/dev/null 2>&1; then
                local candidate=$(extract_prefix_candidate "$filename")
            else
                local basename="${filename%.*}"
                local candidate=$(echo "$basename" | sed -E 's/[._ -]*[Ss][0-9]{1,2}[Ee][0-9]{1,3}[._ -]*//g')
                candidate=$(echo "$candidate" | sed -E 's/[._ -]*[Ee][Pp][0-9]{1,3}[._ -]*//g')
                candidate=$(echo "$candidate" | sed -E 's/[._ -]*第[0-9]{1,3}[集話话][._ -]*//g')
                candidate=$(echo "$candidate" | sed 's/^[._ -]*//;s/[._ -]*$//')
            fi
            
            if [ -n "$candidate" ] && [ ${#candidate} -ge 2 ]; then
                local found=-1
                for idx in "${!candidates[@]}"; do
                    if [ "${candidates[$idx]}" = "$candidate" ]; then
                        found=$idx
                        break
                    fi
                done
                if [ $found -ge 0 ]; then
                    counts[$found]=$((counts[$found] + 1))
                else
                    candidates+=("$candidate")
                    counts+=(1)
                fi
            fi
        done
        
        if [ ${#candidates[@]} -gt 0 ]; then
            local best_idx=0
            for i in "${!candidates[@]}"; do
                if [ ${counts[$i]} -gt ${counts[$best_idx]} ]; then
                    best_idx=$i
                fi
            done
            prefix="${candidates[$best_idx]}"
            detected_info=1
            log_ok "自动识别剧集前缀: ${gl_lv}$prefix${gl_bai}"
        else
            prefix="电视剧"
            log_warn "无法识别剧集前缀，使用默认值: ${gl_lv}电视剧${gl_bai}"
        fi
        
        local season_array=()
        local season_count_array=()
        
        for file in "${files[@]}"; do
            local filename=$(basename -- "$file")
            if [[ "$filename" =~ [Ss]([0-9]{1,2})[Ee] ]]; then
                local s="${BASH_REMATCH[1]}"
                local found=0
                for i in "${!season_array[@]}"; do
                    if [ "${season_array[i]}" = "$s" ]; then
                        season_count_array[i]=$((season_count_array[i] + 1))
                        found=1
                        break
                    fi
                done
                if [ $found -eq 0 ]; then
                    season_array+=("$s")
                    season_count_array+=(1)
                fi
            fi
        done
        
        if [ ${#season_array[@]} -gt 0 ]; then
            local best_idx=0
            for i in "${!season_array[@]}"; do
                if [ ${season_count_array[i]} -gt ${season_count_array[$best_idx]} ]; then
                    best_idx=$i
                fi
            done
            season=$(safe_printf "%02d" "${season_array[$best_idx]}")
            detected_info=1
            log_ok "自动识别季号: ${gl_lv}S$season${gl_bai}"
        else
            log_info "使用默认季号: ${gl_lv}S$season${gl_bai}"
        fi
        
        local min_episode=999
        for file in "${files[@]}"; do
            local filename=$(basename -- "$file")
            if [[ "$filename" =~ [Ss][0-9]{1,2}[Ee]([0-9]{1,3}) ]]; then
                local ep="${BASH_REMATCH[1]}"
                ep=$(echo "$ep" | sed 's/^0*//')
                [ -z "$ep" ] && ep=0
                if [ "$ep" -lt "$min_episode" ] && [ "$ep" -gt 0 ]; then
                    min_episode="$ep"
                fi
            elif [[ "$filename" =~ [Ee][Pp]([0-9]{1,3}) ]]; then
                local ep="${BASH_REMATCH[1]}"
                ep=$(echo "$ep" | sed 's/^0*//')
                [ -z "$ep" ] && ep=0
                if [ "$ep" -lt "$min_episode" ] && [ "$ep" -gt 0 ]; then
                    min_episode="$ep"
                fi
            elif [[ "$filename" =~ 第([0-9]{1,3})[集話话] ]]; then
                local ep="${BASH_REMATCH[1]}"
                ep=$(echo "$ep" | sed 's/^0*//')
                [ -z "$ep" ] && ep=0
                if [ "$ep" -lt "$min_episode" ] && [ "$ep" -gt 0 ]; then
                    min_episode="$ep"
                fi
            fi
        done
        
        if [ "$min_episode" -ne 999 ]; then
            start_ep="$min_episode"
            detected_info=1
            log_ok "自动识别起始集数: ${gl_lv}E$(safe_printf "%02d" "$start_ep")${gl_bai}"
        else
            log_info "使用默认起始集数: ${gl_lv}E$(safe_printf "%02d" "$start_ep")${gl_bai}"
        fi
        
        if [ $detected_info -eq 1 ]; then
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_lv}✓ 智能识别完成${gl_bai}"
        fi
        
        clear
        echo -e "${gl_zi}>>> 预览重命名结果${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        echo -e "${gl_bai}自动识别设置:${gl_bai}"
        echo -e "  ${gl_bufan}剧集前缀:${gl_bai} $prefix"
        echo -e "  ${gl_bufan}季号:${gl_bai} S$season"
        echo -e "  ${gl_bufan}起始集数:${gl_bai} E$(safe_printf "%02d" "$start_ep")"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        echo -e "${gl_bai}重命名预览 (共 ${#files[@]} 个文件):${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        local preview_files=()
        for ((i = 0; i < ${#files[@]}; i++)); do
            local file="${files[$i]}"
            local filename=$(basename -- "$file")
            local extension="${filename##*.}"
            local episode=$((start_ep + i))
            local formatted_ep=$(safe_printf "%02d" "$episode")
            local new_name="${prefix}-S${season}E${formatted_ep}.${extension}"
            
            preview_files+=("$file:$new_name")
            
            echo -e "  ${gl_bufan}[$(safe_printf "%02d" $((i + 1)))]${gl_bai}"
            echo -e "    原文件: ${gl_hui}$filename${gl_bai}"
            echo -e "    新文件: ${gl_lv}$new_name${gl_bai}"
            echo ""
        done
        
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        echo -e "${gl_bai}是否修改设置?${gl_bai}"
        echo -e "  ${gl_bufan}1.${gl_bai} 直接重命名 (使用当前设置)"
        echo -e "  ${gl_bufan}2.${gl_bai} 修改剧集前缀"
        echo -e "  ${gl_bufan}3.${gl_bai} 修改季号"
        echo -e "  ${gl_bufan}4.${gl_bai} 修改起始集数"
        echo -e "  ${gl_bufan}5.${gl_bai} 进入详细设置"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}0.  ${gl_bai}返回"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" choice
        
        case $choice in
        1)
            log_info "开始重命名 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            local success_count=0
            
            for item in "${preview_files[@]}"; do
                IFS=':' read -r old_file new_name <<<"$item"
                local old_filename=$(basename -- "$old_file")
                
                if mv -- "$old_file" "./$new_name" 2>/dev/null; then
                    echo -e "  ${gl_lv}✓ $old_filename → $new_name${gl_bai}"
                    ((success_count++))
                else
                    echo -e "  ${gl_hong}✗ 重命名失败: $old_filename${gl_bai}"
                fi
            done
            
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            log_ok "重命名完成！成功 $success_count 个文件"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        2)
            clear
            echo -e "${gl_zi}>>> 修改剧集前缀${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            
            echo -e "${gl_bai}当前前缀: ${gl_lv}$prefix${gl_bai}"
            echo -e "${gl_bai}示例: ${gl_bufan}庆余年${gl_bai} → ${gl_bufan}庆余年-S${season}E01.kvm${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            
            read -r -e -p "$(echo -e "${gl_bai}请输入新的剧集前缀 (回车保持原值): ")" new_prefix
            
            if [ -n "$new_prefix" ]; then
                prefix="$new_prefix"
                log_ok "剧集前缀已修改为: $prefix"
            else
                log_info "保持原剧集前缀: $prefix"
            fi
            
            quick_rename_preview "${files[@]}" "$prefix" "$season" "$start_ep"
            ;;
        
        3)
            clear
            echo -e "${gl_zi}>>> 修改季号${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            
            echo -e "${gl_bai}当前季号: ${gl_lv}S$season${gl_bai}"
            echo -e "${gl_bai}示例: ${gl_bufan}01${gl_bai} 表示第 ${gl_bufan}1${gl_bai} 季 (将显示为 S01)"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            
            read -r -e -p "$(echo -e "${gl_bai}请输入新的季号 (回车保持原值): ")" new_season
            
            if [ -n "$new_season" ]; then
                if [[ "$new_season" =~ ^[0-9]{1,2}$ ]]; then
                    season=$(safe_printf "%02d" "$new_season")
                    log_ok "季号已修改为: S$season"
                else
                    log_error "请输入有效的数字 (1-99)！"
                fi
            else
                log_info "保持原季号: S$season"
            fi
            
            quick_rename_preview "${files[@]}" "$prefix" "$season" "$start_ep"
            ;;
        4)
            clear
            echo -e "${gl_zi}>>> 修改起始集数${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            
            echo -e "${gl_bai}当前起始集数: ${gl_lv}E$(safe_printf "%02d" "$start_ep")${gl_bai}"
            echo -e "${gl_bai}示例: ${gl_bufan}26${gl_bai} 表示从第 ${gl_bufan}26${gl_bai} 集开始编号"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            
            read -r -e -p "$(echo -e "${gl_bai}请输入新的起始集数 (回车保持原值): ")" new_start
            
            if [ -n "$new_start" ]; then
                if [[ "$new_start" =~ ^[0-9]{1,3}$ ]] && [ "$new_start" -ge 1 ]; then
                    start_ep="$new_start"
                    log_ok "起始集数已修改为: E$(safe_printf "%02d" "$start_ep")"
                else
                    log_error "请输入有效的集数 (1-999)！"
                fi
            else
                log_info "保持原起始集数: E$(safe_printf "%02d" "$start_ep")"
            fi
            
            quick_rename_preview "${files[@]}" "$prefix" "$season" "$start_ep"
            ;;
        
        5)
            rename_tv_files_ultimate
            ;;
        0) cancel_return; return ;;
        *) handle_invalid_input ;;
        esac
    }

    quick_rename_preview() {
        local files=("${@:1:${#@}-3}")
        local prefix="${@: -3:1}"
        local season="${@: -2:1}"
        local start_ep="${@: -1}"
        
        clear
        echo -e "${gl_zi}>>> 预览重命名结果${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        echo -e "${gl_bai}当前设置:${gl_bai}"
        echo -e "  ${gl_bufan}剧集前缀:${gl_bai} $prefix"
        echo -e "  ${gl_bufan}季号:${gl_bai} S$season"
        echo -e "  ${gl_bufan}起始集数:${gl_bai} E$(safe_printf "%02d" "$start_ep")"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        echo -e "${gl_bai}重命名预览:${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        for ((i = 0; i < ${#files[@]}; i++)); do
            local file="${files[$i]}"
            local filename=$(basename -- "$file")
            local extension="${filename##*.}"
            local episode=$((start_ep + i))
            local formatted_ep=$(safe_printf "%02d" "$episode")
            local new_name="${prefix}-S${season}E${formatted_ep}.${extension}"
            
            echo -e "  ${gl_bufan}[$(safe_printf "%02d" $((i + 1)))]${gl_bai}"
            echo -e "    原文件: ${gl_hui}$filename${gl_bai}"
            echo -e "    新文件: ${gl_lv}$new_name${gl_bai}"
            echo ""
        done
        
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        read -r -e -p "$(echo -e "${gl_bai}是否执行重命名? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
        
        case "$confirm" in
        [Yy])
            log_info "开始重命名 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            local success_count=0
            
            for ((i = 0; i < ${#files[@]}; i++)); do
                local file="${files[$i]}"
                local filename=$(basename -- "$file")
                local extension="${filename##*.}"
                local episode=$((start_ep + i))
                local formatted_ep=$(safe_printf "%02d" "$episode")
                local new_name="${prefix}-S${season}E${formatted_ep}.${extension}"
                
                if mv -- "$file" "./$new_name" 2>/dev/null; then
                    echo -e "  ${gl_lv}✓ $filename → $new_name${gl_bai}"
                    ((success_count++))
                else
                    echo -e "  ${gl_hong}✗ 重命名失败: $filename${gl_bai}"
                fi
            done
            
            log_ok "重命名完成！成功 $success_count 个文件"
            ;;
        [Nn])
            log_info "已取消重命名操作"
            ;;
        *)
            log_error "无效的选择！"
            ;;
        esac
        
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
    }

    safe_printf() {
        local format="$1"
        local number="$2"

        if [[ "$format" == "%d" ]] || [[ "$format" == "%02d" ]] || [[ "$format" == "%03d" ]]; then
            number=$(echo "$number" | sed 's/^0*//')
            if [ -z "$number" ]; then
                number=0
            fi
        fi

        printf "$format" "$number"
    }

    enhanced_extract_episode_info() {
        local filename="$1"
        local results=()

        if [[ "$filename" =~ [Ss]([0-9]{1,2})[Ee]([0-9]{1,3}) ]]; then
            local season="${BASH_REMATCH[1]}"
            local episode="${BASH_REMATCH[2]}"
            results+=("S${season}E${episode}:${season}:${episode}:SxE格式")
        fi

        if [[ "$filename" =~ [Ee][Pp]([0-9]{1,3})[^0-9] ]]; then
            local episode="${BASH_REMATCH[1]}"
            results+=("EP${episode}:01:${episode}:EP格式")
        fi

        if [[ "$filename" =~ 第([0-9]{1,3})[集話话] ]]; then
            local episode="${BASH_REMATCH[1]}"
            results+=("第${episode}集:01:${episode}:中文第X集")
        fi

        if [[ "$filename" =~ [^0-9]([0-9]{1,3})[^0-9] ]]; then
            local num="${BASH_REMATCH[1]}"
            if [ "$num" -lt 1000 ] || [ "$num" -gt 2100 ]; then
                results+=("${num}:01:${num}:数字格式")
            fi
        fi

        if [[ "$filename" =~ ^([0-9]{1,3}) ]]; then
            local episode="${BASH_REMATCH[1]}"
            results+=("${episode}:01:${episode}:开头数字")
        fi

        if [[ "$filename" =~ ([0-9]{1,3})\.[^.]*$ ]]; then
            local episode="${BASH_REMATCH[1]}"
            results+=("${episode}:01:${episode}:结尾数字")
        fi

        if [ ${#results[@]} -eq 0 ]; then
            results+=("0:01:1:未识别")
        fi

        printf "%s\n" "${results[@]}"
    }

    analyze_filename_patterns() {
        local files=("$@")

        echo -e "${gl_zi}>>> 智能模式分析${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        local pattern_array=()
        local example_array=()
        local count_array=()

        for file in "${files[@]}"; do
            local filename=$(basename -- "$file")
            local results=($(enhanced_extract_episode_info "$filename"))

            for result in "${results[@]}"; do
                IFS=':' read -r pattern season episode type <<<"$result"
                if [ "$type" != "未识别" ]; then
                    local found=0
                    for i in "${!pattern_array[@]}"; do
                        if [ "${pattern_array[i]}" = "$type" ]; then
                            count_array[i]=$((count_array[i] + 1))
                            found=1
                            break
                        fi
                    done

                    if [ $found -eq 0 ]; then
                        pattern_array+=("$type")
                        example_array+=("$filename")
                        count_array+=(1)
                    fi
                    break
                fi
            done
        done

        if [ ${#pattern_array[@]} -eq 0 ]; then
            echo -e "${gl_huang}未检测到有效的剧集编号模式${gl_bai}"
        else
            echo -e "${gl_bai}检测到的剧集编号模式:${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

            for ((i = 0; i < ${#pattern_array[@]}; i++)); do
                local type="${pattern_array[i]}"
                local count="${count_array[i]}"
                local example="${example_array[i]}"
                local percentage=$((count * 100 / ${#files[@]}))
                local index=$((i + 1))

                if [ $percentage -ge 50 ]; then
                    echo -e "  ${gl_lv}${index}.${gl_bai} ${gl_bufan}${type}${gl_bai} (${percentage}% 文件)"
                else
                    echo -e "  ${gl_huang}${index}.${gl_bai} ${gl_bufan}${type}${gl_bai} (${percentage}% 文件)"
                fi
                echo -e "     示例: ${gl_hui}${example}${gl_bai}"
            done
        fi

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        return 0
    }

    auto_detect_rename_plan() {
        local files=("$@")
        local plans=()
        clear
        echo -e "${gl_zi}>>> 自动检测重命名方案${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        local season_array=()
        local season_count_array=()

        for file in "${files[@]}"; do
            local filename=$(basename -- "$file")
            if [[ "$filename" =~ [Ss]([0-9]{1,2})[Ee] ]]; then
                local season="${BASH_REMATCH[1]}"

                local found=0
                for i in "${!season_array[@]}"; do
                    if [ "${season_array[i]}" = "$season" ]; then
                        season_count_array[i]=$((season_count_array[i] + 1))
                        found=1
                        break
                    fi
                done

                if [ $found -eq 0 ]; then
                    season_array+=("$season")
                    season_count_array+=(1)
                fi
            fi
        done

        if [ ${#season_array[@]} -gt 0 ]; then
            local best_season=""
            local best_count=0
            for i in "${!season_array[@]}"; do
                if [ ${season_count_array[i]} -gt $best_count ]; then
                    best_count=${season_count_array[i]}
                    best_season="${season_array[i]}"
                fi
            done

            if [ -n "$best_season" ]; then
                local formatted_season=$(safe_printf "%02d" "$best_season")
                plans+=("保持原季号|S${formatted_season}|检测到S${formatted_season}格式|高")
            fi
        fi

        if [ ${#files[@]} -gt 0 ]; then
            local sample_file=$(basename -- "${files[0]}")

            if [[ "$sample_file" =~ ^([^0-9.-[:space:]]+)[^0-9]* ]]; then
                local chinese_name="${BASH_REMATCH[1]}"
                chinese_name=$(echo "$chinese_name" | sed 's/^[[:space:][:punct:]]*//;s/[[:space:][:punct:]]*$//')
                if [ -n "$chinese_name" ] && [ ${#chinese_name} -ge 2 ]; then
                    plans+=("中文剧名|${chinese_name}|从文件名提取中文名|中")
                fi
            fi

            if [[ "$sample_file" =~ \.([A-Za-z][A-Za-z. ]+?)[^A-Za-z] ]]; then
                local english_name="${BASH_REMATCH[1]}"
                english_name=$(echo "$english_name" | sed 's/\./ /g;s/ $//')
                if [ -n "$english_name" ]; then
                    plans+=("英文剧名|${english_name}|从文件名提取英文名|中")
                fi
            fi
        fi

        if [ ${#plans[@]} -eq 0 ]; then
            echo -e "${gl_huang}未检测到有效的重命名方案${gl_bai}"
            return 1
        fi

        echo -e "${gl_bai}检测到的重命名方案:${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        for ((i = 0; i < ${#plans[@]}; i++)); do
            IFS='|' read -r type value description confidence <<<"${plans[$i]}"
            local index=$((i + 1))

            case $confidence in
            高) color="${gl_lv}" ;;
            中) color="${gl_huang}" ;;
            *) color="${gl_hong}" ;;
            esac

            echo -e "  ${gl_bufan}${index}.${gl_bai} ${color}${type}${gl_bai}"
            echo -e "     值: ${gl_bufan}${value}${gl_bai}"
            echo -e "     说明: ${gl_hui}${description}${gl_bai}"
            echo -e "     置信度: ${color}${confidence}${gl_bai}"
            echo ""
        done

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        return 0
    }

    rename_tv_files_ultimate() {
        local VIDEO_EXTS=("mp4" "avi" "mov" "wmv" "flv" "webm" "m4v" "mpg" "mpeg" "kvm")
        local PREFIX=""
        local SEASON="01"
        local START_EP="1"
        local preview_mode=1
        local rename_count=0
        local auto_detected=0
        local detection_results=()

        scan_video_files() {
            local -n files_ref=$1
            local -n episode_info_ref=$2
            local -n pattern_types_ref=$3

            local ext_pattern=""
            for ext in "${VIDEO_EXTS[@]}"; do
                if [ -z "$ext_pattern" ]; then
                    ext_pattern="-name \"*.$ext\""
                else
                    ext_pattern="$ext_pattern -o -name \"*.$ext\""
                fi
            done

            while IFS= read -r file; do
                if [ -f "$file" ]; then
                    local filename=$(basename -- "$file")
                    local extension="${filename##*.}"

                    local results=($(enhanced_extract_episode_info "$filename"))
                    local found=0

                    for result in "${results[@]}"; do
                        IFS=':' read -r pattern season episode type <<<"$result"
                        if [ "$episode" != "0" ] && { [ "$episode" != "1" ] || [ "$type" != "未识别" ]; }; then
                            files_ref+=("$file")
                            episode_info_ref+=("$episode:$season:$type")
                            pattern_types_ref+=("$type")
                            found=1
                            break
                        fi
                    done

                    if [ $found -eq 0 ]; then
                        log_warn "无法识别集数: $filename"
                    fi
                fi
            done < <(eval "find . -maxdepth 1 -type f \( $ext_pattern \) 2>/dev/null" | sort -V)
        }

        while true; do
            clear
            echo -e "${gl_zi}>>> 电视剧文件重命名（终极版）${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

            if [ -n "$PREFIX" ]; then
                echo -e "${gl_bufan}当前设置:${gl_bai}"
                echo -e "  ${gl_bufan}剧集前缀:${gl_bai} $PREFIX"
                echo -e "  ${gl_bufan}季号:${gl_bai} S$SEASON"
                echo -e "  ${gl_bufan}起始集数:${gl_bai} E$(safe_printf "%02d" $START_EP)"
                if [ $auto_detected -eq 1 ]; then
                    echo -e "  ${gl_lv}✓ 智能检测已应用${gl_bai}"
                fi
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            fi

            log_info "扫描当前目录视频文件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            local files=()
            local episode_info=()
            local pattern_types=()

            scan_video_files files episode_info pattern_types

            if [ ${#files[@]} -eq 0 ]; then
                log_error "未找到可识别的视频文件！"
                echo -e "${gl_bai}支持格式: ${gl_bufan}${VIDEO_EXTS[*]}${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                read -r -e -p "$(echo -e "${gl_bai}请按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} ")" -n 1
                return
            fi

            if [ ${#files[@]} -gt 0 ]; then
                local sorted_files=()
                local sorted_episodes=()

                while IFS= read -r line; do
                    IFS=':' read -r episode season type <<<"$line"
                    for i in "${!files[@]}"; do
                        if [[ "${episode_info[$i]}" == "$line" ]]; then
                            sorted_episodes+=("$episode:$season:$type")
                            sorted_files+=("${files[$i]}")
                            break
                        fi
                    done
                done < <(printf "%s\n" "${episode_info[@]}" | sort -t: -k1,1n)

                files=("${sorted_files[@]}")
                episode_info=("${sorted_episodes[@]}")
            fi

            echo -e "${gl_bufan}找到 ${#files[@]} 个可识别文件:${gl_bai}"
            for ((i = 0; i < ${#files[@]}; i++)); do
                local filename=$(basename -- "${files[$i]}")
                IFS=':' read -r episode season type <<<"${episode_info[$i]}"
                echo -e "  ${gl_bufan}$(safe_printf "%02d" $((i + 1))).${gl_bai} E$(safe_printf "%02d" "$episode") [${type}] - $filename"
            done

            if [ $auto_detected -eq 0 ] && [ ${#files[@]} -gt 0 ]; then
                echo -e ""
                echo -e "${gl_bai}检测到的模式分布:${gl_bai}"

                local pattern_array=()
                local count_array=()

                for pattern in "${pattern_types[@]}"; do
                    local found=0
                    for i in "${!pattern_array[@]}"; do
                        if [ "${pattern_array[i]}" = "$pattern" ]; then
                            count_array[i]=$((count_array[i] + 1))
                            found=1
                            break
                        fi
                    done

                    if [ $found -eq 0 ]; then
                        pattern_array+=("$pattern")
                        count_array+=(1)
                    fi
                done

                for i in "${!pattern_array[@]}"; do
                    local pattern="${pattern_array[i]}"
                    local count="${count_array[i]}"
                    local percentage=$((count * 100 / ${#files[@]}))
                    echo -e "  ${gl_bufan}${pattern}:${gl_bai} ${count} 文件 (${percentage}%)"
                done
            fi

            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

            echo -e "${gl_bufan}1.  ${gl_bai}智能检测最佳方案"
            echo -e "${gl_bufan}2.  ${gl_bai}设置剧集前缀"
            echo -e "${gl_bufan}3.  ${gl_bai}设置季号"
            echo -e "${gl_bufan}4.  ${gl_bai}设置起始集数"
            echo -e "${gl_bufan}5.  ${gl_bai}详细模式分析"
            echo -e "${gl_bufan}6.  ${gl_bai}预览重命名结果"

            if [ $preview_mode -eq 1 ] && [ -n "$PREFIX" ]; then
                echo -e "${gl_bufan}7.  ${gl_lv}执行重命名${gl_bai}"
            else
                echo -e "${gl_bufan}7.  ${gl_bai}执行重命名"
            fi

            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

            read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" choice

            case $choice in
            1)
                clear
                echo -e "${gl_zi}>>> 智能检测最佳方案${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

                auto_detect_rename_plan "${files[@]}"

                if [ $? -eq 0 ]; then
                    echo -e ""
                    echo -e "${gl_bai}是否应用检测到的方案?${gl_bai}"
                    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

                    read -r -e -p "$(echo -e "${gl_bai}应用检测结果? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" apply_choice

                    case "$apply_choice" in
                    [Yy])
                        auto_detected=1
                        if [ ${#files[@]} -gt 0 ]; then
                            local sample_file=$(basename -- "${files[0]}")

                            if [[ "$sample_file" =~ ^([^0-9.-[:space:]]+)[^0-9]* ]]; then
                                local extracted_prefix="${BASH_REMATCH[1]}"
                                extracted_prefix=$(echo "$extracted_prefix" | sed 's/[[:space:][:punct:]]*$//')
                                if [ ${#extracted_prefix} -ge 2 ]; then
                                    PREFIX="$extracted_prefix"
                                    log_ok "自动设置剧集前缀: $PREFIX"
                                fi
                            fi

                            local season_array=()
                            local season_count_array=()

                            for info in "${episode_info[@]}"; do
                                IFS=':' read -r episode season type <<<"$info"
                                if [ "$season" != "01" ]; then
                                    local found=0
                                    for i in "${!season_array[@]}"; do
                                        if [ "${season_array[i]}" = "$season" ]; then
                                            season_count_array[i]=$((season_count_array[i] + 1))
                                            found=1
                                            break
                                        fi
                                    done

                                    if [ $found -eq 0 ]; then
                                        season_array+=("$season")
                                        season_count_array+=(1)
                                    fi
                                fi
                            done

                            if [ ${#season_array[@]} -gt 0 ]; then
                                local best_season=""
                                local best_count=0
                                for i in "${!season_array[@]}"; do
                                    if [ ${season_count_array[i]} -gt $best_count ]; then
                                        best_count=${season_count_array[i]}
                                        best_season="${season_array[i]}"
                                    fi
                                done

                                if [ -n "$best_season" ]; then
                                    SEASON=$(safe_printf "%02d" "$best_season")
                                    log_ok "自动设置季号: S$SEASON"
                                fi
                            fi
                        fi

                        log_ok "智能检测已应用！"
                        preview_mode=0
                        ;;

                    [Nn]) log_info "已取消应用检测结果" ;;
                    *) handle_y_n ;;
                    esac
                fi
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
                ;;

            2)
                clear
                echo -e "${gl_zi}>>> 设置剧集前缀${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                extract_prefix_candidate() {
                    local filename="$1"
                    local basename="${filename%.*}"
                    local results=($(enhanced_extract_episode_info "$filename"))
                    if [ ${#results[@]} -gt 0 ]; then
                        IFS=':' read -r pattern season episode type <<<"${results[0]}"
                        if [ "$type" != "未识别" ] && [ -n "$pattern" ]; then
                            local cleaned=$(echo "$basename" | sed -E "s/[._ -]*${pattern}[._ -]*//g")
                            if [ -n "$cleaned" ]; then
                                cleaned=$(echo "$cleaned" | sed 's/^[._ -]*//;s/[._ -]*$//')
                                if [ -n "$cleaned" ] && [ ${#cleaned} -ge 2 ]; then
                                    echo "$cleaned"
                                    return
                                fi
                            fi
                        fi
                    fi
                    local fallback=$(echo "$basename" | sed 's/^[._ -]*//;s/[._ -]*$//')
                    if [ -n "$fallback" ] && [ ${#fallback} -ge 2 ]; then
                        echo "$fallback"
                    else
                        echo ""
                    fi
                }

                local candidates=()
                local counts=()
                local total_files=${#files[@]}

                for file in "${files[@]}"; do
                    local filename=$(basename -- "$file")
                    local candidate=$(extract_prefix_candidate "$filename")
                    if [ -z "$candidate" ]; then
                        continue
                    fi
                    local found=-1
                    for idx in "${!candidates[@]}"; do
                        if [ "${candidates[$idx]}" = "$candidate" ]; then
                            found=$idx
                            break
                        fi
                    done
                    if [ $found -ge 0 ]; then
                        counts[$found]=$((counts[$found] + 1))
                    else
                        candidates+=("$candidate")
                        counts+=(1)
                    fi
                done

                if [ ${#candidates[@]} -eq 0 ]; then
                    candidates=("电视剧")
                    counts=($total_files)
                    log_warn "无法自动识别前缀，使用默认值: 电视剧"
                fi

                for ((i = 0; i < ${#candidates[@]} - 1; i++)); do
                    for ((j = i + 1; j < ${#candidates[@]}; j++)); do
                        if [ ${counts[$j]} -gt ${counts[$i]} ]; then
                            tmp_c="${candidates[$i]}"
                            tmp_n="${counts[$i]}"
                            candidates[$i]="${candidates[$j]}"
                            counts[$i]="${counts[$j]}"
                            candidates[$j]="$tmp_c"
                            counts[$j]="$tmp_n"
                        fi
                    done
                done

                local display_limit=10
                if [ ${#candidates[@]} -gt $display_limit ]; then
                    candidates=("${candidates[@]:0:$display_limit}")
                    counts=("${counts[@]:0:$display_limit}")
                fi

                echo -e "${gl_bai}从文件名中提取到的剧名前缀:${gl_bai}"
                for i in "${!candidates[@]}"; do
                    local idx=$((i + 1))
                    local percentage=$((counts[i] * 100 / total_files))
                    echo -e "  ${gl_bufan}${idx}.${gl_bai} ${gl_lv}${candidates[$i]}${gl_bai} (出现 ${counts[$i]} 次, ${percentage}%)"
                done
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                echo -e "${gl_bai}推荐: ${gl_lv}${candidates[0]}${gl_bai} (${gl_huang}回车直接使用推荐${gl_bai})"
                echo -e "${gl_bai}示例: ${gl_bufan}${candidates[0]}-S${SEASON}E01.扩展名${gl_bai}"
                echo -e "${gl_bai}指定: ${gl_bai}手动输入自定义前缀"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

                read -r -e -p "$(echo -e "${gl_bai}请输入序号或自定义前缀 (${gl_huang}0${gl_bai}返回): ")" input_prefix

                [[ "$input_prefix" == "0" ]] && { cancel_return "上一级选单"; continue; }

                if [[ "$input_prefix" =~ ^[0-9]+$ ]] && [ "$input_prefix" -ge 1 ] && [ "$input_prefix" -le ${#candidates[@]} ]; then
                    PREFIX="${candidates[$((input_prefix - 1))]}"
                    log_ok "剧集前缀已设置为: $PREFIX (通过序号选择)"
                elif [ -z "$input_prefix" ]; then
                    PREFIX="${candidates[0]}"
                    log_ok "剧集前缀已设置为: $PREFIX (使用推荐)"
                else
                    PREFIX="$input_prefix"
                    log_ok "剧集前缀已设置为: $PREFIX (手动输入)"
                fi

                preview_mode=0
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
                ;;
            3)
                echo -e ""
                echo -e "${gl_zi}>>> 设置季号${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                local season_array=()
                local season_count_array=()

                for info in "${episode_info[@]}"; do
                    IFS=':' read -r episode season type <<<"$info"
                    if [ "$season" != "01" ]; then
                        local found=0
                        for i in "${!season_array[@]}"; do
                            if [ "${season_array[i]}" = "$season" ]; then
                                season_count_array[i]=$((season_count_array[i] + 1))
                                found=1
                                break
                            fi
                        done

                        if [ $found -eq 0 ]; then
                            season_array+=("$season")
                            season_count_array+=(1)
                        fi
                    fi
                done

                if [ ${#season_array[@]} -gt 0 ]; then
                    echo -e "${gl_bai}从文件名检测到季号:${gl_bai}"
                    for i in "${!season_array[@]}"; do
                        local season="${season_array[i]}"
                        local count="${season_count_array[i]}"
                        local percentage=$((count * 100 / ${#files[@]}))
                        echo -e "  ${gl_bufan}S${season}:${gl_bai} ${count} 文件 (${percentage}%)"
                    done
                    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                fi

                echo -e "${gl_bai}当前季号: ${gl_bufan}S${SEASON}${gl_bai}"
                echo -e "${gl_bai}示例: ${gl_bufan}01${gl_bai} 表示第 ${gl_bufan}1${gl_bai} 季 (将显示为 S01)"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                read -r -e -p "$(echo -e "${gl_bai}请输入季号 (当前: ${gl_lv}S${SEASON}${gl_bai}，回车保持，${gl_huang}0${gl_bai}返回): ")" input_season

                [[ "$input_season" == "0" ]] && { cancel_return "上一级选单"; continue; }

                if [ -z "$input_season" ]; then
                    echo -e "${gl_bai}保持当前季号: S${SEASON}${gl_bai}"
                    continue
                fi

                if [[ "$input_season" =~ ^[0-9]{1,2}$ ]]; then
                    SEASON=$(safe_printf "%02d" "$input_season")
                    log_ok "季号已设置为: S$SEASON"
                    preview_mode=0
                    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                    break_end
                else
                    log_error "请输入有效的数字 (1-99)！"
                    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                    break_end
                fi
                ;;
            4)
                echo -e ""
                echo -e "${gl_zi}>>> 设置起始集数${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                if [ ${#episode_info[@]} -gt 0 ]; then
                    local first_info="${episode_info[0]}"
                    local last_info="${episode_info[-1]}"
                    IFS=':' read -r first_ep first_season first_type <<<"$first_info"
                    IFS=':' read -r last_ep last_season last_type <<<"$last_info"

                    echo -e "${gl_bai}识别的集数范围:${gl_bai}"
                    echo -e "  ${gl_bufan}最小:${gl_bai} E$(safe_printf "%02d" "$first_ep") (${first_type})"
                    echo -e "  ${gl_bufan}最大:${gl_bai} E$(safe_printf "%02d" "$last_ep") (${last_type})"
                    echo -e "  ${gl_bufan}建议:${gl_bai} 从 E$(safe_printf "%02d" "$first_ep") 开始"
                    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                fi

                echo -e "${gl_bai}当前起始集数: ${gl_bufan}E$(safe_printf "%02d" "$START_EP")${gl_bai}"
                echo -e "${gl_bai}示例: ${gl_bufan}26${gl_bai} 表示从第 ${gl_bufan}26${gl_bai} 集开始编号"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                read -r -e -p "$(echo -e "${gl_bai}请输入起始集数 (当前: ${gl_lv}E$(safe_printf "%02d" "$START_EP")${gl_bai}，回车保持，${gl_huang}0${gl_bai}返回): ")" input_start

                [[ "$input_start" == "0" ]] && { cancel_return "上一级选单"; continue; } 

                if [ -z "$input_start" ]; then
                    echo -e "${gl_bai}保持当前起始集数: E$(safe_printf "%02d" "$START_EP")${gl_bai}"
                    continue
                fi

                if [[ "$input_start" =~ ^[0-9]{1,3}$ ]] && [ "$input_start" -ge 1 ]; then
                    START_EP="$input_start"
                    log_ok "起始集数已设置为: E$(safe_printf "%02d" "$START_EP")"
                    preview_mode=0
                    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                    break_end
                else
                    log_error "请输入有效的集数 (1-999)！"
                    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                    break_end
                fi
                ;;
            5)
                clear
                analyze_filename_patterns "${files[@]}"

                echo -e ""
                echo -e "${gl_zi}>>> 详细文件分析${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

                echo -e "${gl_bai}文件分析详情:${gl_bai}"
                for ((i = 0; i < ${#files[@]} && i < 10; i++)); do
                    local filename=$(basename -- "${files[$i]}")
                    IFS=':' read -r episode season type <<<"${episode_info[$i]}"
                    echo -e "  ${gl_bufan}$(safe_printf "%02d" $((i + 1))).${gl_bai} $filename"
                    echo -e "      识别为: ${type}"
                    echo -e "      季号: S${season}"
                    echo -e "      集数: E$(safe_printf "%02d" "$episode")"
                    echo ""
                done

                if [ ${#files[@]} -gt 10 ]; then
                    echo -e "  ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} 还有 $((${#files[@]} - 10)) 个文件未显示${gl_bai}"
                fi

                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
                ;;

            6)
                if [ -z "$PREFIX" ]; then
                    log_error "请先设置剧集前缀！"
                    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                    exit_animation
                    continue
                fi

                clear
                echo -e "${gl_zi}>>> 预览重命名结果${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                echo -e "${gl_bufan}当前设置:${gl_bai}"
                echo -e "  ${gl_bufan}剧集前缀:${gl_bai} $PREFIX"
                echo -e "  ${gl_bufan}季号:${gl_bai} S$SEASON"
                echo -e "  ${gl_bufan}起始集数:${gl_bai} E$(safe_printf "%02d" "$START_EP")"
                if [ $auto_detected -eq 1 ]; then
                    echo -e "  ${gl_lv}✓ 智能检测已应用${gl_bai}"
                fi
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

                local current_ep=$START_EP
                detection_results=()
                local summary_array=()
                local summary_count_array=()

                echo -e "${gl_bai}重命名预览:${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

                for ((i = 0; i < ${#files[@]}; i++)); do
                    local file="${files[$i]}"
                    local filename=$(basename -- "$file")
                    local extension="${filename##*.}"
                    IFS=':' read -r original_ep original_season type <<<"${episode_info[$i]}"
                    local formatted_ep=$(safe_printf "%02d" "$current_ep")
                    local new_name="${PREFIX}-S${SEASON}E${formatted_ep}.${extension}"

                    local found=0
                    for j in "${!summary_array[@]}"; do
                        if [ "${summary_array[j]}" = "$type" ]; then
                            summary_count_array[j]=$((summary_count_array[j] + 1))
                            found=1
                            break
                        fi
                    done

                    if [ $found -eq 0 ]; then
                        summary_array+=("$type")
                        summary_count_array+=(1)
                    fi

                    echo -e "  ${gl_bufan}[$(safe_printf "%02d" $((i + 1)))]${gl_bai}"
                    echo -e "    原文件: ${gl_hui}$filename${gl_bai}"
                    echo -e "    识别为: ${type} (E$(safe_printf "%02d" "$original_ep"))"
                    echo -e "    新文件: ${gl_lv}$new_name${gl_bai}"
                    echo ""

                    detection_results+=("$file:$new_name:$type:$original_ep")
                    ((current_ep++))
                done

                if [ ${#summary_array[@]} -gt 0 ]; then
                    echo -e "${gl_bai}识别模式统计:${gl_bai}"
                    for i in "${!summary_array[@]}"; do
                        local type="${summary_array[i]}"
                        local count="${summary_count_array[i]}"
                        local percentage=$((count * 100 / ${#files[@]}))
                        echo -e "  ${gl_bufan}${type}:${gl_bai} ${count} 文件 (${percentage}%)"
                    done
                fi

                preview_mode=1
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                local accurate_count=0
                for i in "${!summary_array[@]}"; do
                    local type="${summary_array[i]}"
                    if [[ "$type" == "SxE格式" ]] || [[ "$type" == "EP格式" ]] || [[ "$type" == "中文第X集" ]]; then
                        accurate_count=$((accurate_count + summary_count_array[i]))
                    fi
                done

                local accuracy=0
                if [ ${#files[@]} -gt 0 ]; then
                    accuracy=$((accurate_count * 100 / ${#files[@]}))
                fi

                log_info "预览完成，共 ${#detection_results[@]} 个文件"
                if [ ${#files[@]} -gt 0 ]; then
                    log_info "识别准确率: ${accuracy}%"
                fi
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
                ;;
            7)
                if [ $preview_mode -eq 0 ]; then
                    log_error "请先预览重命名结果！"
                    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                    exit_animation
                    continue
                fi

                if [ ${#detection_results[@]} -eq 0 ]; then
                    log_error "没有可重命名的文件！"
                    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                    exit_animation
                    continue
                fi

                clear
                echo -e "${gl_zi}>>> 确认重命名${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                local type_array=()
                local type_count_array=()

                for item in "${detection_results[@]}"; do
                    IFS=':' read -r old_file new_name type original_ep <<<"$item"

                    local found=0
                    for i in "${!type_array[@]}"; do
                        if [ "${type_array[i]}" = "$type" ]; then
                            type_count_array[i]=$((type_count_array[i] + 1))
                            found=1
                            break
                        fi
                    done

                    if [ $found -eq 0 ]; then
                        type_array+=("$type")
                        type_count_array+=(1)
                    fi
                done

                echo -e "${gl_bai}重命名统计:${gl_bai}"
                echo -e "  ${gl_bufan}总文件数:${gl_bai} ${#detection_results[@]}"
                for i in "${!type_array[@]}"; do
                    local type="${type_array[i]}"
                    local count="${type_count_array[i]}"
                    echo -e "  ${gl_bufan}${type}:${gl_bai} ${count} 文件"
                done
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

                read -r -e -p "$(echo -e "${gl_bai}确定要执行重命名吗? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm

                case "$confirm" in
                [Yy])
                    log_info "开始重命名 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                    rename_count=0
                    local success_count=0
                    local fail_count=0

                    for item in "${detection_results[@]}"; do
                        IFS=':' read -r old_file new_name type original_ep <<<"$item"

                        if [ -f "$old_file" ]; then
                            echo -e "${gl_bai}处理: ${gl_hui}$(basename "$old_file")${gl_bai}"
                            echo -e "  识别: ${type} (E$(safe_printf "%02d" "$original_ep"))"

                            if mv -- "$old_file" "./$new_name" 2>/dev/null; then
                                echo -e "  ${gl_lv}✓ 重命名为: $new_name${gl_bai}"
                                ((success_count++))
                            else
                                echo -e "  ${gl_hong}✗ 重命名失败${gl_bai}"
                                ((fail_count++))
                            fi
                        else
                            echo -e "${gl_huang}⚠ 文件不存在: $(basename "$old_file")${gl_bai}"
                            ((fail_count++))
                        fi
                        echo ""
                    done

                    rename_count=$success_count
                    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                    echo -e "${gl_lv}成功:${gl_bai} $success_count 个文件"
                    echo -e "${gl_hong}失败:${gl_bai} $fail_count 个文件"
                    log_ok "重命名完成！"

                    preview_mode=0
                    auto_detected=0
                    detection_results=()
                    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                    break_end
                    ;;

                [Nn])
                    log_info "已取消重命名操作"
                    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                    break_end
                    ;;

                *) handle_y_n ;;
                esac
                ;;
            0)
                if [ $rename_count -gt 0 ]; then
                    log_ok "操作完成，已重命名 $rename_count 个文件"
                fi
                cancel_return
                return
                ;;
            *) handle_invalid_input ;;
            esac
        done
    }

    test_all_recognition_modes() {
        clear
        echo -e "${gl_zi}>>> 批量测试识别模式${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        local test_cases=(
            "电视剧集.How.Dare.You.S01E26.2026.2160p.IQ.WEB-DL.H265.DDP5.1-ColorWEB.kvm|SxE格式|S01E26"
            "EP26-剧情发展.mp4|EP格式|EP26"
            "第26集.电视剧名.avi|中文第X集|第26集"
            "26-剧集名.mov|数字格式|26"
            "01.第一集.kvm|开头数字|01"
            "S1E1.测试.kvm|SxE格式|S1E1"
            "Episode.1.kvm|EP格式|EP1"
            "test-26-video.kvm|数字格式|26"
            "2026.2160p.WEB-DL.kvm|未识别|未识别"
            "电影名.1080p.mp4|未识别|未识别"
        )

        echo -e "${gl_bai}测试识别引擎准确性:${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        local total_cases=${#test_cases[@]}
        local correct_cases=0
        local partially_correct=0

        for test_case in "${test_cases[@]}"; do
            IFS='|' read -r filename expected_type expected_pattern <<<"$test_case"

            echo -e "  ${gl_bufan}测试文件:${gl_bai} ${gl_hui}$filename${gl_bai}"

            local results=($(enhanced_extract_episode_info "$filename"))
            local first_result="${results[0]}"
            IFS=':' read -r pattern season episode type <<<"$first_result"

            if [ "$type" = "$expected_type" ]; then
                echo -e "  ${gl_lv}✓ 正确识别: ${type} (${pattern})${gl_bai}"
                ((correct_cases++))
            elif [ "$type" != "未识别" ] && [ "$expected_type" != "未识别" ]; then
                echo -e "  ${gl_huang}⚠ 部分识别: ${type} (预期: ${expected_type})${gl_bai}"
                ((partially_correct++))
            else
                echo -e "  ${gl_hong}✗ 识别错误: ${type} (预期: ${expected_type})${gl_bai}"
            fi

            if [ ${#results[@]} -gt 1 ]; then
                echo -e "  ${gl_bai}所有可能的识别:${gl_bai}"
                for result in "${results[@]}"; do
                    IFS=':' read -r p s e t <<<"$result"
                    echo -e "    - ${t}: ${p} (S${s}E${e})"
                done
            fi

            echo ""
        done

        local accuracy=0
        local partial_accuracy=0
        if [ $total_cases -gt 0 ]; then
            accuracy=$((correct_cases * 100 / total_cases))
            partial_accuracy=$(((correct_cases + partially_correct) * 100 / total_cases))
        fi

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bai}识别准确率统计:${gl_bai}"
        echo -e "  ${gl_bufan}测试用例:${gl_bai} $total_cases 个"
        echo -e "  ${gl_lv}完全正确:${gl_bai} $correct_cases 个"
        echo -e "  ${gl_huang}部分正确:${gl_bai} $partially_correct 个"
        echo -e "  ${gl_bufan}完全准确率:${gl_bai} ${accuracy}%"
        echo -e "  ${gl_bufan}部分准确率:${gl_bai} ${partial_accuracy}%"

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
    }

    create_mixed_test_files() {
        echo -e ""
        echo -e "${gl_zi}>>> 创建多种格式测试文件${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        read -r -e -p "$(echo -e "${gl_bai}要创建多少个测试文件? (默认: ${gl_lv}16${gl_bai}, ${gl_huang}0${gl_bai}返回): ")" file_count
        [[ "$file_count" == "0" ]] && { cancel_return "上一级选单"; return 1; }

        if [ -z "$file_count" ]; then
            file_count=16
            log_info "使用默认值: ${gl_lv}16${gl_bai} 个文件"
        fi

        if ! [[ "$file_count" =~ ^[0-9]+$ ]] || [ "$file_count" -lt 1 ]; then
            log_error "请输入有效的数字！"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            exit_animation
            return
        fi

        log_info "${gl_bai}正在创建 ${gl_huang}$file_count ${gl_bai}个测试文件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

        for i in $(seq 1 $file_count); do
            case $((i % 6)) in
            0) filename="S01E$(printf "%02d" $i).2026.2160p.WEB-DL.kvm" ;;
            1) filename="EP$(printf "%02d" $i)-剧情发展.mp4" ;;
            2) filename="第$(printf "%d" $i)集.电视剧名.avi" ;;
            3) filename="$(printf "%02d" $i)-剧集名.mov" ;;
            4) filename="电视剧.S01E$(printf "%02d" $i).WEBRip.wmv" ;;
            5) filename="test$(printf "%d" $i).480p.mpeg" ;;
            esac

            touch "$filename"
            echo -e "  ${gl_lv}创建:${gl_bai} $filename"
        done

        log_ok "${gl_bai}创建完成！共创建 ${gl_lv}$file_count ${gl_bai}个测试文件"
        log_info "包含多种识别格式"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
    }

    show_current_files() {

        local video_count=0

        for ext in mp4 kvm avi mov wmv flv webm m4v mpg mpeg kvm; do
            for file in *."$ext"; do
                if [ -f "$file" ]; then
                    echo -e "  ${gl_bufan}▶${gl_bai} $file"
                    ((video_count++))
                fi
            done 2>/dev/null || true
        done

        if [ $video_count -eq 0 ]; then
            echo -e "  ${gl_huang}无视频文件${gl_bai}"
        fi

        echo -e ""
        echo -e "${gl_huang}文件统计:${gl_bai}"
        echo -e "  ${gl_bai}视频文件:${gl_lv} $video_count ${gl_bai}个"
    }

    delete_test_files() {
        echo -e ""
        echo -e "${gl_zi}>>> 删除测试文件${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        read -r -e -p "$(echo -e "${gl_bai}确定要删除所有测试文件吗? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm

        case "$confirm" in
        [Yy])
            local count=0
            for ext in mp4 avi mov wmv flv webm m4v mpg mpeg kvm; do
                for file in *."$ext"; do
                    if [ -f "$file" ]; then
                        rm -f "$file"
                        echo -e "  ${gl_hong}删除:${gl_bai} $file"
                        ((count++))
                    fi
                done 2>/dev/null || true
            done

            if [ $count -gt 0 ]; then
                log_ok "删除完成！共删除 $count 个文件"
            else
                log_warn "没有找到测试文件"
            fi
            ;;

        [Nn])
            log_info "已取消删除操作"
            ;;

        *) handle_y_n ;;
        esac
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
    }

    quick_rename() {
        clear
        echo -e "${gl_zi}>>> 快速重命名${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        local VIDEO_EXTS=("mp4" "avi" "mov" "wmv" "flv" "webm" "m4v" "mpg" "mpeg" "kvm")

        local ext_pattern=""
        for ext in "${VIDEO_EXTS[@]}"; do
            if [ -z "$ext_pattern" ]; then
                ext_pattern="-name \"*.$ext\""
            else
                ext_pattern="$ext_pattern -o -name \"*.$ext\""
            fi
        done

        log_info "扫描当前目录视频文件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        local files=()
        while IFS= read -r file; do
            if [ -f "$file" ]; then
                files+=("$file")
            fi
        done < <(eval "find . -maxdepth 1 -type f \( $ext_pattern \) 2>/dev/null" | sort -V)

        if [ ${#files[@]} -eq 0 ]; then
            log_error "未找到视频文件！"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            exit_animation
            return
        fi

        echo -e "${gl_bai}找到 ${#files[@]} 个视频文件:${gl_bai}"
        for ((i = 0; i < ${#files[@]}; i++)); do
            local filename=$(basename -- "${files[$i]}")
            echo -e "  ${gl_bufan}$(safe_printf "%02d" $((i + 1))).${gl_bai} $filename"
        done

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        echo -e "${gl_bai}请选择重命名方式:${gl_bai}"
        echo -e "  ${gl_bufan}1.${gl_bai} 自动识别剧集编号并重命名"
        echo -e "  ${gl_bufan}2.${gl_bai} 手动输入前缀和起始集数"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择 (${gl_huang}0${gl_bai}返回): ")" rename_method
        [[ "$rename_method" == "0" ]] && { cancel_return; return 1; }

        case $rename_method in
        1) rename_tv_files_ultimate ;;
        2)
            clear
            echo -e "${gl_zi}>>> 手动重命名设置${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

            read -r -e -p "$(echo -e "${gl_bai}请输入剧集前缀: ")" prefix
            if [ -z "$prefix" ]; then
                log_error "剧集前缀不能为空！"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                exit_animation
                return
            fi

            read -r -e -p "$(echo -e "${gl_bai}请输入季号 (默认 ${gl_lv}01${gl_bai}): ")" season
            season="${season:-01}"

            read -r -e -p "$(echo -e "${gl_bai}请输入起始集数 (默认 ${gl_lv}1${gl_bai}): ")" start_ep
            start_ep="${start_ep:-1}"

            clear
            echo -e "${gl_zi}>>> 预览重命名结果${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_bai}将重命名 ${#files[@]} 个文件:${gl_bai}"

            for ((i = 0; i < ${#files[@]}; i++)); do
                local file="${files[$i]}"
                local filename=$(basename -- "$file")
                local extension="${filename##*.}"
                local episode=$((start_ep + i))
                local formatted_ep=$(safe_printf "%02d" "$episode")
                local new_name="${prefix}-S${season}E${formatted_ep}.${extension}"

                echo -e "  ${gl_hui}$filename${gl_bai}"
                echo -e "  ${gl_lv}→ $new_name${gl_bai}"
                echo ""
            done

            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bai}确定要执行重命名吗? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm

            case "$confirm" in
            [Yy])
                log_info "开始重命名 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                local success_count=0

                for ((i = 0; i < ${#files[@]}; i++)); do
                    local file="${files[$i]}"
                    local filename=$(basename -- "$file")
                    local extension="${filename##*.}"
                    local episode=$((start_ep + i))
                    local formatted_ep=$(safe_printf "%02d" "$episode")
                    local new_name="${prefix}-S${season}E${formatted_ep}.${extension}"

                    if mv -- "$file" "./$new_name" 2>/dev/null; then
                        echo -e "  ${gl_lv}✓ $filename → $new_name${gl_bai}"
                        ((success_count++))
                    else
                        echo -e "  ${gl_hong}✗ 重命名失败: $filename${gl_bai}"
                    fi
                done

                log_ok "重命名完成！成功 $success_count 个文件"
                ;;

            [Nn]) log_info "已取消重命名操作" ;;
            *) handle_y_n ;;
            esac

            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;

        *) handle_y_n; return ;;
        esac
    }

    move_videos_interactive() {
        clear
        check_directory_empty "." "移动视频文件" "true" || return

        local source_dir="$(pwd)"
        echo -e "${gl_huang}>>> 当前目录文件列表：${gl_bai}(${gl_lv}${source_dir}${gl_bai})"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        show_current_files
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e ""
        echo -e "${gl_zi}>>> 移动视频文件${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}将移动${gl_lv}${source_dir}${gl_huang}目录下的所有视频文件${gl_bai}"
        echo -e "${gl_lv}/vol2/1000/media/电视剧集/国产剧/xxx/Season 1${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        while true; do
            read -r -e -p "$(echo -e "${gl_bai}请输入目标目录 (${gl_huang}0${gl_bai}返回): ")" target_dir

            [[ "$target_dir" == "0" ]] && { cancel_return; return 1; }

            if [ -z "$target_dir" ]; then
                log_error "目标目录不能为空, 请重新输入"
                continue
            fi
            break
        done

        if [ ! -d "$target_dir" ]; then
            read -r -e -p "$(echo -e "${gl_bai}目录不存在, 是否创建? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" create_dir
            case "$create_dir" in
            [Yy])
                mkdir -p "$target_dir"
                if [ $? -ne 0 ]; then
                    log_error "创建目录失败！"
                    exit_animation
                    return 1
                fi
                log_ok "目录已创建: ${target_dir}"
                ;;
            [Nn] | "")
                log_error "操作取消: 目录不存在"
                exit_animation
                return 1
                ;;
            *) handle_y_n; return 1 ;;
            esac
        else
            log_info "目标目录已存在: ${target_dir}"
        fi

        clear
        echo -e "${gl_huang}>>> 将移动${gl_lv}${source_dir}${gl_huang}目录下的所有视频文件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        log_info "正在扫描视频文件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

        local video_extensions=("mp4" "avi" "kvm" "mov" "wmv" "flv" "webm"
            "m4v" "mpg" "mpeg" "3gp" "mts" "m2ts"
            "ts" "vob" "ogg" "ogv" "divx" "f4v")

        local found_files=()
        local found_count=0

        for ext in "${video_extensions[@]}"; do
            while IFS= read -r -d '' file; do
                if [ -f "$file" ]; then
                    found_files+=("$file")
                    ((found_count++))
                fi
            done < <(find "$source_dir" -maxdepth 1 -type f -iname "*.$ext" -print0 2>/dev/null)
        done

        if [ $found_count -eq 0 ]; then
            log_warn "未找到任何视频文件"
            return 0
        fi

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}找到的文件${gl_bai}"

        for file in "${found_files[@]}"; do
            filename=$(basename "$file")
            echo -e "  ${gl_hui}${filename}${gl_bai}"
        done

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_lv}共找到 ${gl_huang}${found_count} ${gl_lv}个视频文件${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        read -r -e -p "$(echo -e "${gl_bai}确认移动到 '${gl_huang}${target_dir}${gl_bai}'目录吗? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm_move
        case "$confirm_move" in
        [Yy])
            echo -e "${gl_bai}正在移动文件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            ;;
        [Nn] | "")
            log_info "操作已取消"
            exit_animation
            return 0
            ;;
        *) handle_y_n; return 1 ;;
        esac

        local moved_count=0
        local failed_count=0

        for file in "${found_files[@]}"; do
            if [ -f "$file" ]; then
                filename=$(basename "$file")

                if [ -f "$target_dir/$filename" ]; then
                    log_warn "目标文件已存在, 跳过: ${filename}"
                    ((failed_count++))
                    continue
                fi

                if mv "$file" "$target_dir/" 2>/dev/null; then
                    ((moved_count++))
                    echo -e "  ${gl_lv}✓${gl_bai} 移动: ${filename}"
                else
                    log_error "移动失败: ${filename}"
                    ((failed_count++))
                fi
            fi
        done

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        if [ $moved_count -gt 0 ]; then
            log_ok "移动完成!"
            echo -e "${gl_lv}移动成功: ${moved_count} 个文件${gl_bai}"
            echo -e "${gl_lan}目标目录: ${target_dir}${gl_bai}"

            if [ $failed_count -gt 0 ]; then
                echo -e "${gl_huang}移动失败: ${failed_count} 个文件${gl_bai}"
            fi

            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bai}是否切换到目标目录? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" open_dir
            case "$open_dir" in
            [Yy])
                clear
                cd "$target_dir"
                local source_dir="$(pwd)"
                echo -e "${gl_huang}>>> 当前目录文件列表：${gl_bai}(${gl_lv}${source_dir}${gl_bai})"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                show_current_files
                ;;
            esac
        else
            log_error "没有文件被移动"
        fi

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
    }

    main_menu() {
        while true; do
            clear
            echo -e "${gl_zi}>>> 刮削目录结构示例${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_bufan}庆余年/${gl_bai}                      ${gl_hui}<-- ${gl_lan}电视剧根目录${gl_hui} (可含年份：庆余年 (2024))${gl_bai}"
            echo -e "${gl_bufan}     ├──${gl_lv}Season 01/${gl_bai}           ${gl_hui}<-- ${gl_lan}第一季文件夹${gl_hui} (标准命名：Season XX)${gl_bai}"
            echo -e "${gl_bufan}     │   ├──${gl_huang}庆余年-S01E01.mp4${gl_bai}"
            echo -e "${gl_bufan}     │   ├──${gl_huang}庆余年-S01E02.mp4${gl_bai}"
            echo -e "${gl_bufan}     │   └── ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}     └──${gl_lv}Season 02/${gl_bai}           ${gl_hui}<-- ${gl_lan}第二季文件夹${gl_hui} (标准命名：Season XX)${gl_bai}"
            echo -e "${gl_bufan}         ├──${gl_huang}庆余年-S02E01.mp4${gl_bai}"
            echo -e "${gl_bufan}         ├──${gl_huang}庆余年-S02E02.mp4${gl_bai}"
            echo -e "${gl_bufan}         └── ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e ""
            local source_dir="$(pwd)"
            echo -e "${gl_huang}>>> 当前目录文件列表：${gl_bai}(${gl_lv}${source_dir}${gl_bai})"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            show_current_files
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e ""
            echo -e "${gl_zi}>>> 电视剧文件重命名${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_bufan}1.  ${gl_bai}进入电视剧所在目录       ${gl_bufan}2.  ${gl_bai}返回上一级目录"
            echo -e "${gl_bufan}3.  ${gl_bai}快速重命名               ${gl_bufan}4.  ${gl_bai}详细重命名"
            echo -e "${gl_bufan}5.  ${gl_bai}创建测试文件             ${gl_bufan}6.  ${gl_bai}删除测试文件"
            echo -e "${gl_bufan}7.  ${gl_bai}移动视频文件             ${gl_bufan}8.  ${gl_bai}测试识别模式"
            echo -e "${gl_bufan}9.  ${gl_bai}批量重命名"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单           ${gl_hong}00. ${gl_bai}退出脚本"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

            read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" choice

            case $choice in
            1)  enter_directory ;;
            2)  go_parent_directory ;;
            3)  quick_rename ;;
            4)  rename_tv_files_ultimate ;;
            5)  create_mixed_test_files ;;
            6)  delete_test_files ;;
            7)  move_videos_interactive ;;
            8)  test_all_recognition_modes ;;
            9)  batch_rename_files ;;
            0) cancel_return "已是主菜单" || continue ;;
            00 | 000 | 0000) exit_script ;;
            *) handle_invalid_input; continue ;;
            esac
        done
    }
    main_menu
}

tv_rename_ultimate
