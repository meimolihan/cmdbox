#!/bin/bash

list_color_init() {
    export gl_hui=$'\033[38;5;59m'
    export gl_hong=$'\033[38;5;9m'
    export gl_lv=$'\033[38;5;10m'
    export gl_huang=$'\033[38;5;11m'
    export gl_lan=$'\033[38;5;32m'
    export gl_bai=$'\033[38;5;15m'
    export gl_zi=$'\033[38;5;13m'
    export gl_bufan=$'\033[38;5;14m'
    export gl_cheng=$'\033[38;5;208m'
    export reset=$'\033[0m'
}
list_color_init

log_info() { echo -e "${gl_lan}[信息]${gl_bai} $*"; }
log_ok() { echo -e "${gl_lv}[成功]${gl_bai} $*"; }
log_warn() { echo -e "${gl_huang}[警告]${gl_bai} $*"; }
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

exit_animation() {
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local dots=(
        "${gl_hong}."
        "${gl_huang}."
        "${gl_lv}."
        "${gl_bufan}."
        "${gl_zi}."
        "${gl_cheng}."
    )
    local dot_buffer=""
    local frame_len=${#frames[@]}
    local dot_idx=0
    local total_dots=6

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
}

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    read -r -n 1 -s -r -p ""
    echo ""
    clear
}

handle_invalid_input() {
    echo -ne "\r${gl_hong}无效的输入，请重新输入 ${gl_zi} 2 ${gl_hong}秒后返回 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.3
    echo -ne "\r${gl_huang}无效的输入，请重新输入 ${gl_zi} 1 ${gl_huang}秒后返回 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.3
    echo -e "\r${gl_lv}无效的输入，请重新输入 ${gl_zi} 0 ${gl_lv}秒后返回 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    return 2
}

handle_y_n() {
    echo -ne "\r${gl_hong}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai}) ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.3
    echo -ne "\r${gl_huang}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai}) ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.3
    echo -ne "\r${gl_lv}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai}) ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    return 2
}

exit_script() {
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local dots=(
        "${gl_hong}."
        "${gl_huang}."
        "${gl_lv}."
        "${gl_bufan}."
        "${gl_zi}."
        "${gl_cheng}."
    )
    local dot_buffer=""
    local frame_len=${#frames[@]}
    local dot_idx=0
    local total_dots=6

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

cancel_empty() {
    local menu_name="${1:-上一级选单}"
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local dots=(
        "${gl_hong}."
        "${gl_huang}."
        "${gl_lv}."
        "${gl_bufan}."
        "${gl_zi}."
        "${gl_cheng}."
    )
    local dot_buffer=""
    local frame_len=${#frames[@]}
    local dot_idx=0
    local total_dots=6

    for ((i=0; i<20; i++)); do
        if (( i > 0 && i % 3 == 0 && dot_idx < total_dots )); then
            dot_buffer+=${dots[$dot_idx]}
            ((dot_idx++))
        fi
        echo -ne "\r\033[K${gl_bufan}${frames[i % frame_len]}${gl_bai}空输入，返回 ${gl_huang}${menu_name} ${dot_buffer}"
        sleep_fractional 0.06
    done
    echo -e "\r\033[K${gl_lv}✓${gl_bai}成功返回${gl_huang}${menu_name}${gl_bai} \n"
    clear
}


cancel_return() {
    local menu_name="${1:-上一级选单}"
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local dots=(
        "${gl_hong}."
        "${gl_huang}."
        "${gl_lv}."
        "${gl_bufan}."
        "${gl_zi}."
        "${gl_cheng}."
    )
    local dot_buffer=""
    local frame_len=${#frames[@]}
    local dot_idx=0
    local total_dots=6

    for ((i=0; i<20; i++)); do
        if (( i > 0 && i % 3 == 0 && dot_idx < total_dots )); then
            dot_buffer+=${dots[$dot_idx]}
            ((dot_idx++))
        fi
        echo -ne "\r\033[K${gl_bufan}${frames[i % frame_len]}${gl_bai}即将返回 ${gl_huang}${menu_name} ${dot_buffer}"
        sleep_fractional 0.06
    done
    echo -e "\r\033[K${gl_lv}✓${gl_bai} 成功返回${gl_huang}${menu_name}${gl_bai} \n"
    clear
}


get_internal_ip() {
	local ip=""
	if command -v hostname >/dev/null 2>&1; then
		ip=$(hostname -I | awk '{print $1}')
	elif command -v ip >/dev/null 2>&1; then
		ip=$(ip route get 1 2>/dev/null | awk '{print $7}' | head -1)
	elif command -v ifconfig >/dev/null 2>&1; then
		ip=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -1)
	fi
	echo "$ip"
}

safe_read() {
    local prompt="$1"
    local var_name="$2"
    local validation="${3:-any}"
    local default="$4"
    local min="${5:-}"
    local max="${6:-}"

    while :; do
        local full_prompt="${prompt}"
        [[ -n $default ]] && full_prompt+=" [默认: ${default}]"
        full_prompt+=": "

        local raw
        IFS= read -r -e -p "$full_prompt" raw || return 1
        [[ -z $raw && -n $default ]] && raw="$default"
        [[ -z $raw ]] && echo "错误：输入不能为空，请重新输入" && continue
        [[ $raw =~ ^(q|quit|exit)$ ]] && echo "退出操作" && return 1

        case "$validation" in
        number)
            [[ $raw =~ ^[0-9]+$ ]] || {
                echo "错误：请输入有效的数字"
                return
            }
            [[ -n $min && $raw -lt $min ]] && {
                echo "错误：数字不能小于 $min"
                return
            }
            [[ -n $max && $raw -gt $max ]] && {
                echo "错误：数字不能大于 $max"
                return
            }
            ;;
        file)
            local expanded
            eval "expanded=\"$raw\""
            [[ -f $expanded ]] || {
                echo "错误：文件 '$raw' 不存在"
                return
            }
            ;;
        dir)
            local expanded
            eval "expanded=\"$raw\""
            [[ -d $expanded ]] || {
                echo "错误：目录 '$raw' 不存在"
                return
            }
            ;;
        any) ;;
        *)
            echo "错误：未知的验证类型: $validation"
            return 1
            ;;
        esac
        printf -v "$var_name" "%s" "$raw"
        return 0
    done
}

declare -A _compose_state_color=()
_compose_state_ok=0

_compose_project_ids() {
    local dir="$1"
    [[ -d "$dir" ]] || return 0
    (
        cd "$dir" 2>/dev/null || exit 0
        if docker compose version &>/dev/null 2>&1; then
            docker compose ps --all --quiet 2>/dev/null
        fi
        if command -v docker-compose &>/dev/null 2>&1; then
            docker-compose ps --quiet 2>/dev/null
        fi
    )
}

collect_compose_states() {
    local base_path="$1"
    shift
    local -a names=("$@")
    local item

    if (( ${#names[@]} == 0 )); then
        while IFS= read -r -d '' item; do
            names+=("$(basename "$item")")
        done < <(find "$base_path" -mindepth 1 -maxdepth 1 -type d ! -name '.*' -print0 | sort -z)
    fi

    local -A id_level=() name_level=() dir_level=() proj_level=()
    local -a level_color=("${gl_hong}" "${gl_lv}" "${gl_huang}")
    local snapshot=""
    local cid cname wd proj status lvl id_key d_key p_key
    local name dir path color_lvl v found max_lvl

    _compose_state_color=()
    _compose_state_ok=0

    command -v docker >/dev/null 2>&1 || return 0
    if snapshot=$(docker ps -a --format \
        '{{.ID}}|{{.Names}}|{{.Label "com.docker.compose.project.working_dir"}}|{{.Label "com.docker.compose.project"}}|{{.Status}}' 2>/dev/null); then
        _compose_state_ok=1
    else
        return 0
    fi

    while IFS='|' read -r cid cname wd proj status; do
        [[ -z "$cid" ]] && continue
        if [[ "$status" == Restarting* ]]; then
            lvl=2
        elif [[ "$status" == Up* && "$status" != *Paused* ]]; then
            lvl=1
        else
            lvl=0
        fi

        id_key="${cid:0:12}"
        if (( lvl > ${id_level["$id_key"]:-0} )); then id_level["$id_key"]=$lvl; fi
        if [[ -n "$cname" ]]; then
            if (( lvl > ${name_level["$cname"]:-0} )); then name_level["$cname"]=$lvl; fi
        fi

        [[ -z "$wd" && -z "$proj" ]] && continue
        if [[ -n "$wd" ]]; then
            d_key="${wd%/}"
            if (( lvl > ${dir_level["$d_key"]:-0} )); then dir_level["$d_key"]=$lvl; fi
        fi
        if [[ -n "$proj" ]]; then
            p_key="${proj,,}"
            p_key="${p_key//[^a-z0-9_-]/}"
            if [[ -n "$p_key" ]]; then
                if (( lvl > ${proj_level["$p_key"]:-0} )); then proj_level["$p_key"]=$lvl; fi
            fi
        fi
    done <<< "$snapshot"

    for name in "${names[@]}"; do
        dir="$base_path/$name"
        path="$(realpath "$dir" 2>/dev/null || printf '%s' "${dir%/}")"
        p_key="${name,,}"
        p_key="${p_key//[^a-z0-9_-]/}"

        if [[ -n "${dir_level["$path"]:-}" ]]; then
            color_lvl="${dir_level["$path"]}"
        elif [[ -n "$p_key" ]] && [[ -n "${proj_level["$p_key"]:-}" ]]; then
            color_lvl="${proj_level["$p_key"]}"
        elif [[ -n "${name_level["$name"]:-}" ]]; then
            color_lvl="${name_level["$name"]}"
        else
            local f has_yml=0
            for f in "$dir"/*.yml "$dir"/*.yaml; do
                [[ -f "$f" ]] && { has_yml=1; break; }
            done
            if (( has_yml )); then
                found=0
                max_lvl=0
                while IFS= read -r cid; do
                    [[ -z "$cid" ]] && continue
                    id_key="${cid:0:12}"
                    [[ -z "${id_level["$id_key"]:-}" ]] && continue
                    found=1
                    v="${id_level["$id_key"]}"
                    if (( v > max_lvl )); then max_lvl=$v; fi
                done < <(_compose_project_ids "$dir")
                color_lvl=0
                if (( found )); then color_lvl=$max_lvl; fi
            else
                color_lvl=0
            fi
        fi

        _compose_state_color["$name"]="${level_color[$color_lvl]:-${gl_bufan}}"
    done
}

show_directory_list() {
    local base_path="${1:-.}"
    local items_per_line="${2:-4}"
    local show_hidden="${3:-false}"
    local exit_on_empty="${4:-true}"
    local return_array_var="${5:-}"
    local status_mode="${6:-}"

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

    if [[ "$status_mode" == "compose" && ${#_compose_state_color[@]} -eq 0 ]]; then
        collect_compose_states "$base_path" "${dir_array[@]}"
    fi

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

        local idx_color="${gl_bufan}"
        if [[ "$status_mode" == "compose" && ${_compose_state_ok:-0} -eq 1 ]]; then
            idx_color="${_compose_state_color["${dir_array[i]}"]:-${gl_hong}}"
        fi
        printf "%s%s${gl_bai} %s" "$idx_color" "$index_str" "${dir_array[i]}"

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

show_compose_project_menu() {
    local base_path
    base_path="${1:-$(pwd)}"

    if [ ! -d "$base_path" ]; then
        echo -e "${gl_huang}错误: 路径 $base_path 不存在${gl_bai}"
        exit_animation
        return 1
    fi

    cd "$base_path" 2>/dev/null || {
        echo -e "${gl_huang}错误: 无法进入路径 $base_path${gl_bai}"
        exit_animation
        return 1
    }

    while true; do
        clear
        echo -e "${gl_zi}>>> Compose 项目列表${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bai}当前工作目录: ${gl_huang}$base_path${gl_bai}"
        echo -e "${gl_bai}内网 IP 地址: ${gl_huang}$(get_internal_ip)${gl_bai}"
        collect_compose_states "$base_path"
        if (( ${_compose_state_ok:-0} )); then
            echo -e "${gl_bai}状态: ${gl_lv}● 运行中${gl_bai}   ${gl_huang}● 重启中${gl_bai}   ${gl_hong}● 已停止/未启动${gl_bai}"
        else
            echo -e "${gl_hui}⚠ 无法获取容器状态，序号保持默认颜色${gl_bai}"
        fi
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        local projects
        if ! show_directory_list "$base_path" 2 false true projects compose; then
            log_info "没有找到Git项目，按任意键返回 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            exit_animation
            return 1
        fi

        local count=${#projects[@]}

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "输入 ${gl_lv}序号   ${gl_bai}进入并管理项目"
        echo -e "输入 ${gl_lv}目录名 ${gl_bai}创建新项目"
        echo -e "输入 ${gl_hong}0${gl_bai}      退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        local project_choice

        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" project_choice

        if [ "$project_choice" = "q" ] || [ "$project_choice" = "quit" ] || [ "$project_choice" = "exit" ]; then
            echo -e "${gl_huang}退出操作${gl_bai}"
            exit_animation
            return 1
        fi

        [ "$project_choice" == "0" ] && { cancel_return; return 1; }

        if ! [[ "$project_choice" =~ ^[0-9]+$ ]] || [ "$project_choice" -lt 1 ] || [ "$project_choice" -gt $count ]; then

            local dir_name=$(echo "$project_choice" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            if [ -z "$dir_name" ]; then
                echo -e "${gl_huang}无效的选择，请重新输入${gl_bai}"
                exit_animation
                continue
            fi

            if [[ "$dir_name" =~ ^/ ]] || [[ "$dir_name" =~ \.\. ]] || [[ "$dir_name" =~ / ]]; then
                log_error "目录名不能包含路径分隔符或相对路径符号"
                exit_animation
                continue
            fi

            local new_path="$base_path/$dir_name"

            if [ -d "$new_path" ]; then
                if cd "$new_path" 2>/dev/null; then
                    echo -e "${gl_lv}进入已有目录: $dir_name"
                    show_compose_commands_menu
                    cd "$base_path"
                    continue
                fi
            fi

            if mkdir -p "$new_path" 2>/dev/null; then
                echo -e "${gl_lv}已创建新目录: $dir_name"
                if cd "$new_path" 2>/dev/null; then
                    echo -e "${gl_lan}项目路径: $new_path${gl_bai}"
                    show_compose_commands_menu
                    cd "$base_path"
                    continue
                else
                    echo -e "${gl_hong}错误: 无法进入新创建的目录 '$new_path'${gl_bai}"
                    sleep_fractional 1
                    continue
                fi
            else
                echo -e "${gl_hong}错误: 无法创建目录 '$new_path'${gl_bai}"
                sleep_fractional 1
                continue
            fi
        fi

        local selected_project="${projects[$((project_choice - 1))]}"
        local full_path="$base_path/$selected_project"

        if [ ! -d "$full_path" ]; then
            echo -e "${gl_hong}错误: 目录 '$full_path' 不存在${gl_bai}"
            exit_animation
            return
        fi

        if cd "$full_path" 2>/dev/null; then
            echo -e "${gl_lv}已选择项目: $selected_project"
            echo -e "${gl_lan}项目路径: $full_path${gl_bai}"
            show_compose_commands_menu
            cd "$base_path"
        else
            echo -e "${gl_hong}错误: 无法进入目录 '$full_path'${gl_bai}"
            echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            read -r -r -n 1 -s
        fi
    done
}

show_inner_url() {
    local yml="docker-compose.yml"
    [[ -f $yml ]] || {
        echo -e "当前目录没有 $yml"
        return 1
    }

    local port
    port=$(awk '
    match($0, /-[[:space:]]*"?([0-9]+):[0-9]+/) {
      split(substr($0, RSTART, RLENGTH), a, /:/);
      gsub(/[^0-9]/, "", a[1]);
      print a[1]; exit
    }' "$yml")

    [[ -z $port ]] && {
        echo -e "服务访问链接：未检测到 http 端口映射"
        return 2
    }

    local ip=$(hostname -I | awk '{print $1}')
    echo -e "${gl_bufan}服务访问链接：${gl_lv}http://${ip}:${port}${gl_bai}"
}

show_compose_commands_menu() {
    local current_dir="$(pwd)"
    while true; do
        clear
        echo -e ""
        local current_dir_name=$(basename "$PWD")

        echo -e "${gl_zi}>>> Compose 项目菜单${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bai}当前工作目录: ${gl_huang}$current_dir${gl_bai}"
        echo -e "${gl_bai}当前项目名称: ${gl_huang}$current_dir_name${gl_bai}"
        echo -e "${gl_bai}内网 IP 地址: ${gl_huang}$(get_internal_ip)${gl_bai}"

        docker inspect -f \
            '{{if .State.Running}}'"$gl_lv"'已启动'"$gl_bai"'{{else}}'"$gl_hui"'已停止'"$gl_bai"'{{end}}' \
            "$current_dir_name" >/dev/null 2>&1 && {
            echo -e "${gl_bai}当前容器状态：$(docker inspect -f \
                '{{if .State.Running}}'"$gl_lv"'已启动'"$gl_bai"'{{else}}'"$gl_hui"'已停止'"$gl_bai"'{{end}}' \
                "$current_dir_name")"
        } || {
            printf "${gl_bai}当前容器状态：${gl_hui}容器 ${gl_huang}%s${gl_hui} 不存在(${gl_huang}确保容器名和文件夹名称一致${gl_hui})${gl_bai}\n" "$current_dir_name"
        }

        show_inner_url

        echo -e "${gl_bai}公网访问链接：${gl_lv}https://$current_dir_name.mobufan.eu.org:666${gl_bai}"

        check_container_status() {
            if docker inspect "$1" &>/dev/null; then
                if docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null | grep -q "true"; then
                    echo "${gl_lv}"
                else
                    echo "${gl_hong}"
                fi
            else
                echo "${gl_hui}"
            fi
        }

        container_color=$(check_container_status "$current_dir_name")

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}停止${container_color}$current_dir_name${gl_bai}服务      ${gl_bufan}2.  ${gl_bai}启动${container_color}$current_dir_name${gl_bai}服务"
        echo -e "${gl_bufan}3.  ${gl_bai}重启${container_color}$current_dir_name${gl_bai}服务      ${gl_bufan}4.  ${gl_bai}更新${container_color}$current_dir_name${gl_bai}容器"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}5.  ${gl_bai}查看${container_color}$current_dir_name${gl_bai}配置文件  ${gl_bufan}6.  ${gl_bai}编辑${container_color}$current_dir_name${gl_bai}配置文件"
        echo -e "${gl_bufan}7.  ${gl_bai}创建${container_color}$current_dir_name${gl_bai}配置文件  ${gl_bufan}8.  ${gl_bai}查看${container_color}$current_dir_name${gl_bai}最终配置"
        echo -e "${gl_bufan}9.  ${gl_bai}查看${container_color}$current_dir_name${gl_bai}服务日志  ${gl_bufan}10. ${gl_bai}跟踪${container_color}$current_dir_name${gl_bai}服务日志"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}11. ${gl_bai}查看${container_color}$current_dir_name${gl_bai}服务状态  ${gl_bufan}12. ${gl_bai}查看${container_color}$current_dir_name${gl_bai}镜像详情"
        echo -e "${gl_bufan}13. ${gl_bai}查看${container_color}$current_dir_name${gl_bai}资源占用  ${gl_bufan}14. ${gl_bai}拉取${container_color}$current_dir_name${gl_bai}镜像文件"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}23. ${gl_bai}开放${container_color}$current_dir_name${gl_bai}访问端口  ${gl_bufan}24. ${gl_bai}重构${container_color}$current_dir_name${gl_bai}后并启动"
        echo -e "${gl_bufan}25. ${gl_bai}进入${container_color}$current_dir_name${gl_bai}服务终端  ${gl_bufan}26. ${gl_bai}修改${container_color}$current_dir_name${gl_bai}重启策略"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}88. ${gl_huang}停止${container_color}$current_dir_name${gl_huang}后并清理${gl_bai}  ${gl_hong}99. ${gl_hong}停止${container_color}$current_dir_name${gl_hong}彻底清理${gl_bai}"
        echo -e "${gl_huang}0.  ${gl_bai}返回${container_color}$current_dir_name${gl_bai}上级      ${gl_hong}00. ${gl_bai}退出${container_color}$current_dir_name${gl_bai}脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        if ! safe_read "请输入你的选择" cmd_choice "number" "" 0 99; then
            return
        fi

        case $cmd_choice in
        1)
            echo -e ""
            echo -e "${gl_bai}正在停止并删除 ${gl_huang}$current_dir_name${gl_bai} 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker-compose down
            echo -e "\n"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        2)
            echo -e ""
            echo -e "正在启动 ${gl_huang}$current_dir_name${gl_bai} 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker-compose up -d --remove-orphans
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        3)
            echo -e ""
            echo -e "${gl_bai}正在重启 ${gl_huang}$current_dir_name${gl_bai} 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker-compose down && docker-compose up -d --remove-orphans
            echo -e "\n"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        4)
            echo -e ""
            echo -e "${gl_bai}正在更新 ${gl_huang}$current_dir_name${gl_bai} 容器 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker-compose pull && docker-compose up -d --remove-orphans && docker image prune -f
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        5)
            echo -e ""
            echo -e "${gl_bai}正在显示 ${gl_huang}$current_dir_name${gl_bai} 配置文件内容 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            if [ -f "docker-compose.yml" ]; then
                cat docker-compose.yml | sed '/^$/d'
            else
                echo -e "${gl_hong}[错误]: docker-compose.yml 文件不存在${gl_bai}"
            fi
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        6)
            echo -e ""
            echo -e "${gl_bai}正在打开 ${gl_huang}$current_dir_name${gl_bai} 配置文件编辑器 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            if [ -f "docker-compose.yml" ]; then
                nano docker-compose.yml
            else
                echo -e "${gl_hong}[错误]: docker-compose.yml 文件不存在${gl_bai}"
                read -r -e -p "$(echo -e "${gl_bai}docker-compose.yml 不存在，要创建吗？ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" create_choice
                if [[ "$create_choice" =~ ^[Yy]$ ]]; then
                    echo -e "${gl_lv}正在创建 docker-compose.yml ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                    create_file docker-compose.yml
                else
                    echo -e "${gl_huang}已取消创建${gl_bai}"
                fi
            fi
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        7)
            echo
            echo -e "${gl_bai}正在创建${gl_huang}$current_dir_name${gl_bai}配置文件"
            create_file docker-compose.yml
            ;;
        8)
            echo -e ""
            echo -e "${gl_bai}正在查看 ${gl_huang}$current_dir_name${gl_bai} 服务最终生效配置 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker-compose config
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        9)
            echo -e ""
            echo -e "${gl_bai}正在显示 ${gl_huang}$current_dir_name${gl_bai} 服务日志 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker-compose logs
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        10)
            view_compose_logs
            ;;
        11)
            echo -e ""
            echo -e "${gl_bai}正在显示 ${gl_huang}$current_dir_name${gl_bai} 服务状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker-compose ps
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        12)
            list_beautify_all
            ;;
        13)
            echo
            echo -e "${gl_huang}$current_dir_name${gl_bai}服务列表 & 实时资源占用（Ctrl-C 退出）"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            bash <(curl -sSL https://cmdbox.meimolihan.eu.org/sh/docker_occupy_list.sh) $current_dir_name
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            ;;
        14)
            echo
            echo -e "${gl_bai}仅拉取${gl_huang}$current_dir_name${gl_bai}镜像（不启动）"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker-compose pull
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;

        23)
            echo -e ""
            echo -e "${gl_zi}>>> 开放$current_dir_name访问端口 ${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            default_port=$(
                awk '
                match($0, /-[[:space:]]*([0-9]+):[0-9]+/) {
                print substr($0, RSTART+1, RLENGTH-1) + 0;
                exit
                }
            ' docker-compose.yml 2>/dev/null
            )
            [[ -z $default_port ]] && default_port=""
            if [[ -n "$default_port" ]]; then
                echo -e "${gl_bai}默认端口: ${gl_lv}${default_port}${gl_bai} (直接回车使用此端口)"
                read -r -e -p "$(echo -e "${gl_bai}请输入要放行的端口号 (${gl_huang}0${gl_bai}返回): ")" port
                [[ -z "$port" ]] && port="$default_port"
            else
                read -r -e -p "$(echo -e "${gl_bai}请输入要放行的端口号 (${gl_huang}0${gl_bai}返回): ")" port
            fi
            [ "$port" == "0" ] && { cancel_return "上一级选单"; continue; }
            if [[ $port =~ ^[0-9]+$ && $port -ge 1 && $port -le 65535 ]]; then
                iptables -A INPUT -p tcp --dport "$port" -j ACCEPT
                echo -e ""
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                log_ok "已放行 TCP 端口 $port"
            else
                echo -e ""
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                log_error "端口号非法，已跳过"
            fi
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        24)
            echo -e ""
            echo -e "${gl_bai}正在重新构建 ${gl_huang}$current_dir_name${gl_bai} 并启动服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker-compose up -d --build
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        25)
            local TARGET_SERVICE="$MAIN_SERVICE"
            if [[ -f "docker-compose.yml" ]] || [[ -f "docker-compose.yaml" ]]; then
                local selected_service=$(select_service)
                [[ -n "$selected_service" ]] && TARGET_SERVICE="$selected_service"
            fi
            if [[ -z "$TARGET_SERVICE" ]]; then
                echo -e "${gl_hong}未找到可进入的服务${gl_bai}"
                break_end
                continue
            fi
            echo -e ""
            echo -e "${gl_bai}进入 ${gl_huang}$TARGET_SERVICE${gl_bai} 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            if ! docker inspect "$TARGET_SERVICE" &>/dev/null; then
                echo -e "${gl_hong}容器 $TARGET_SERVICE 不存在${gl_bai}"
                read -r -e -p "$(echo -e "${gl_bai}是否启动容器？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" start_choice
                if [[ "$start_choice" =~ ^[Yy]$ ]]; then
                    docker-compose up -d "$TARGET_SERVICE"
                    sleep 2
                else
                    break_end
                    continue
                fi
            fi
            if ! docker inspect -f '{{.State.Running}}' "$TARGET_SERVICE" 2>/dev/null | grep -q "true"; then
                echo -e "${gl_hong}容器 $TARGET_SERVICE 未运行${gl_bai}"
                read -r -e -p "$(echo -e "${gl_bai}是否启动容器？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" start_choice
                if [[ "$start_choice" =~ ^[Yy]$ ]]; then
                    docker-compose up -d "$TARGET_SERVICE"
                    sleep 2
                else
                    break_end
                    continue
                fi
            fi
            if ! docker exec -it "$TARGET_SERVICE" bash 2>/dev/null; then
                echo -e "${gl_hong}bash 不可用，尝试使用 sh ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                docker exec -it "$TARGET_SERVICE" sh
            fi
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        26)
            local TARGET_SERVICE="$MAIN_SERVICE"
            if [[ -f "docker-compose.yml" ]] || [[ -f "docker-compose.yaml" ]]; then
                local selected_service=$(select_service)
                [[ -n "$selected_service" ]] && TARGET_SERVICE="$selected_service"
            fi
            if [[ -z "$TARGET_SERVICE" ]]; then
                echo -e "${gl_hong}未找到可修改的服务${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
                continue
            fi
            install yq
            clear
            echo -e ""
            echo -e "${gl_zi}>>> 永久修改重启策略 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            if [ ! -f "docker-compose.yml" ] && [ ! -f "docker-compose.yaml" ]; then
                echo -e "${gl_hong}❌ 未找到 docker-compose.yml 文件${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
                continue
            fi
            compose_file="docker-compose.yml"
            if [ ! -f "$compose_file" ]; then
                compose_file="docker-compose.yaml"
            fi
            echo -e "${gl_bai}配置文件: ${gl_huang}$compose_file${gl_bai}"
            echo -e "${gl_bai}目标服务: ${gl_huang}$TARGET_SERVICE${gl_bai}"
            echo -e ""
            echo -e "${gl_huang}当前配置:${gl_bai}"
            if command -v yq &>/dev/null; then
                yq e ".services.$TARGET_SERVICE" "$compose_file" 2>/dev/null || {
                    echo -e "${gl_bai}使用grep过滤注释行:${gl_bai}"
                    grep -A 20 "^\s*$TARGET_SERVICE:" "$compose_file" | grep -v "^\s*#" | head -15
                }
            else
                echo -e "${gl_bai}服务 $TARGET_SERVICE 的配置:${gl_bai}"
                grep -A 20 "^\s*$TARGET_SERVICE:" "$compose_file" | grep -v "^\s*#" | head -15
            fi
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e ""
            current_restart=$(grep -A 10 "^\s*$TARGET_SERVICE:" "$compose_file" | grep "^\s*restart:" | head -1 | sed 's/^\s*restart:\s*//' || echo "未设置")
            echo -e "${gl_bai}当前重启策略: ${gl_lv}${current_restart:-未设置}${gl_bai}"
            echo -e "${gl_huang}>>> 请选择重启策略:${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_bufan}1.  ${gl_lv}no${gl_bai} - 不自动重启 (默认)"
            echo -e "${gl_bufan}2.  ${gl_lv}always${gl_bai} - 总是重启"
            echo -e "${gl_bufan}3.  ${gl_lv}on-failure${gl_bai} - 失败时重启"
            echo -e "${gl_bufan}4.  ${gl_lv}unless-stopped${gl_bai} - 除非手动停止，否则总是重启"
            echo -e "${gl_bufan}5.  ${gl_huang}自定义策略 (如: on-failure:3)${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单"
            echo -e "${gl_hong}00. ${gl_bai}退出脚本"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            read -p "请输入选择 [0-5]: " policy_choice
            case $policy_choice in
            1) new_policy="no" ;;
            2) new_policy="always" ;;
            3) new_policy="on-failure" ;;
            4) new_policy="unless-stopped" ;;
            5)
                read -r -e -p "$(echo -e "${gl_bai}请输入自定义策略${gl_huang}on-failure:3${gl_bai}(${gl_huang}0${gl_bai}返回): ")" new_policy
                [ "$new_policy" == "0" ] && { cancel_return "上一级选单"; continue; }
                ;;
            0) cancel_return; continue ;;
            00|000|0000) exit_script; return 0 ;;
            *) handle_invalid_input ;;
            esac
            echo -e ""
            if grep -q "^\s*restart:" "$compose_file"; then
                if sed -i "s/^\(\s*\)restart:.*/\1restart: $new_policy/" "$compose_file"; then
                    echo -e "${gl_lv}✓ 已更新重启策略${gl_bai}"
                else
                    echo -e "${gl_hong}✗ 更新重启策略失败${gl_bai}"
                fi
            else
                if grep -q "^\s*$TARGET_SERVICE:" "$compose_file"; then
                    line_num=$(grep -n "^\s*$TARGET_SERVICE:" "$compose_file" | head -1 | cut -d: -f1)
                    if [ -n "$line_num" ]; then
                        sed -i "${line_num}a\ \ \ \ restart: $new_policy" "$compose_file"
                        echo -e "${gl_lv}✓ 已添加重启策略${gl_bai}"
                    else
                        echo -e "${gl_hong}✗ 未找到 $TARGET_SERVICE 服务定义${gl_bai}"
                    fi
                else
                    echo -e "${gl_hong}✗ 未找到 $TARGET_SERVICE 服务定义${gl_bai}"
                fi
            fi
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_huang}修改后的配置:${gl_bai}"
            if command -v yq &>/dev/null; then
                yq e ".services.$TARGET_SERVICE" "$compose_file" 2>/dev/null || {
                    echo -e "${gl_bai}使用grep显示修改后的配置:${gl_bai}"
                    grep -A 20 "^\s*$TARGET_SERVICE:" "$compose_file" | grep -v "^\s*#" | head -20
                }
            else
                echo -e "${gl_bai}服务 $TARGET_SERVICE 的配置:${gl_bai}"
                grep -A 20 "^\s*$TARGET_SERVICE:" "$compose_file" | grep -v "^\s*#" | head -20
            fi
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            if docker inspect "$TARGET_SERVICE" >/dev/null 2>&1; then
                echo -e ""
                echo -e "${gl_huang}检测到容器 $TARGET_SERVICE 正在运行${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                read -r -e -p "$(echo -e "${gl_bai}是否立即更新容器的重启策略？ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" update_now
                if [[ "$update_now" =~ ^[Yy]$ ]]; then
                    echo -e "${gl_bai}更新容器重启策略 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                    if docker update --restart="$new_policy" "$TARGET_SERVICE" >/dev/null 2>&1; then
                        echo -e "${gl_lv}✓ 容器重启策略已更新${gl_bai}"
                    else
                        echo -e "${gl_hong}✗ 容器重启策略更新失败${gl_bai}"
                    fi
                else
                    echo -e "${gl_huang}注意: 配置文件已修改，但容器重启策略未更新${gl_bai}"
                    echo -e "${gl_bai}如需应用到容器，请手动执行:${gl_bai}"
                    echo -e "${gl_lv}docker update --restart=$new_policy $TARGET_SERVICE${gl_bai}"
                fi
                echo -e ""
                echo -e "${gl_huang}是否重新创建容器以应用配置？${gl_bai}"
                echo -e "${gl_bai}重新创建容器会停止并重新启动容器，但会保留数据卷${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                read -r -e -p "$(echo -e "输入 ${gl_bufan}y${gl_bai} 重新创建，其他键跳过:")" recreate_choice
                if [ "$recreate_choice" = "y" ] || [ "$recreate_choice" = "Y" ]; then
                    echo -e "${gl_bai}重新创建容器 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                    if command -v docker-compose &>/dev/null; then
                        docker-compose down && docker-compose up -d
                    elif command -v docker &>/dev/null && docker compose version &>/dev/null; then
                        docker compose down && docker compose up -d
                    else
                        echo -e "${gl_hong}未找到 docker-compose 或 docker compose 命令${gl_bai}"
                    fi
                    echo -e "${gl_lv}✓ 容器已重新创建${gl_bai}"
                else
                    echo -e "${gl_huang}注意: 需要重新创建容器以使配置文件完全生效${gl_bai}"
                    echo -e "${gl_bai}手动执行: ${gl_lv}docker-compose down && docker-compose up -d${gl_bai}"
                fi
            else
                echo -e "${gl_huang}容器 $TARGET_SERVICE 未运行${gl_bai}"
                echo -e "${gl_bai}下次启动容器时会应用新的重启策略${gl_bai}"
            fi
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        88)
            echo -e ""
            echo -e "${gl_bai}正在停止并删除 ${gl_huang}$current_dir_name${gl_bai} 服务及相关资源 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_hong}⚠️  警告: 此操作将删除容器、网络和卷、删除项目镜像！${gl_bai}"
            echo -e "${gl_bai}数据卷不会被删除，但网络和相关资源将被清理${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bai}确认执行？ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                docker compose down --rmi all --remove-orphans && docker system prune -af --volumes
                echo -e ""
                echo -e "${gl_lv}✓ 服务、网络和卷已清理完成${gl_bai}"
            else
                echo -e "${gl_huang}已取消操作${gl_bai}"
            fi
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        99)
            echo -e ""
            echo -e "${gl_bai}正在停止并删除 ${gl_huang}$current_dir_name${gl_bai} 服务及相关资源 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_hong}⚠️  警告: 此操作将删除容器、网络、卷、镜像，并且【删除整个项目目录】！${gl_bai}"
            echo -e "${gl_hong}项目目录路径：${gl_huang}${current_dir}${gl_bai}"
            echo -e "${gl_bai}目录内所有文件都会被永久删除！${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            read -r -e -p "$(echo -e "${gl_hong}确认要执行吗？ ${gl_bai}(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                docker compose down --rmi all --remove-orphans && docker system prune -af --volumes
                echo -e "${gl_lv}✓ Compose容器、网络、卷已清理${gl_bai}"

                local parent_dir=$(dirname "${current_dir}")
                cd "${parent_dir}" || {
                    log_error "无法切换到上级目录 ${parent_dir}"
                    read -r
                    break_end
                }

                echo -e "${gl_huang}正在删除项目目录：${current_dir}${gl_bai}"
                rm -rf "${current_dir}"
                echo -e "${gl_lv}✓ 项目目录已彻底删除${gl_bai}"

                return 0
            else
                echo -e "${gl_huang}已取消操作${gl_bai}"
            fi
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        0) cancel_return; break ;;
        00 | 000 | 0000) exit_script ;;
        *) handle_invalid_input ;;
        esac
    done
}

show_help() {
    cat <<EOF
用法: $(basename "$0") [选项] [compose项目根目录]

说明:
  传参时：如果目标目录含 docker-compose.yml / docker-compose.yaml，
          直接进入该项目的 Compose 管理菜单；
          否则把该目录当作项目根目录，进入交互式项目选择菜单。
  不传参：进入交互式项目选择菜单（等同旧行为）。

选项:
  -h, --help    显示本帮助信息

示例:
  $(basename "$0")                              # 交互式选择项目
  $(basename "$0") /opt/stacks/myapp            # 直接进入指定项目
  $(basename "$0") .                            # 直接管理当前目录
  $(basename "$0") /opt/stacks                  # 以 /opt/stacks 为根进行选择
EOF
}

main() {
    case "${1:-}" in
        -h|--help)
            show_help
            exit 0
            ;;
    esac

    if [[ $# -gt 0 ]]; then
        local project_dir="$1"
        if [[ ! -d "$project_dir" ]]; then
            log_error "目录不存在: $project_dir"
            exit 1
        fi
        if ! cd "$project_dir" 2>/dev/null; then
            log_error "无法进入目录: $project_dir"
            exit 1
        fi
        local abs_path
        abs_path="$(pwd)"

        if [[ -f "docker-compose.yml" || -f "docker-compose.yaml" ]]; then
            log_ok "已选择项目: $(basename "$abs_path")"
            log_info "项目路径: $abs_path"
            sleep_fractional 0.5
            show_compose_commands_menu
            exit_animation
            exit 0
        else
            log_info "未在该目录发现 docker-compose 文件，作为根目录进入交互式选择"
            sleep_fractional 0.5
            show_compose_project_menu "$abs_path"
        fi
    else
        show_compose_project_menu
    fi
}

main "$@"