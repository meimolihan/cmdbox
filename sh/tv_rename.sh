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
    echo -e "${gl_hong}[错误]${gl_bai} 路径解析失败，请检查路径格式${gl_bai}"
    exit 1
fi

if [[ ! -d "$TARGET_DIR" ]]; then
    echo -e "${gl_hong}[错误]${gl_bai} 目录不存在：$TARGET_DIR${gl_bai}"
    exit 1
fi

if ! cd -- "$TARGET_DIR" 2>/dev/null; then
    echo -e "${gl_hong}[错误]${gl_bai} 无法进入目录，权限不足：$TARGET_DIR${gl_bai}"
    exit 1
fi

log_info() { echo -e "${gl_lan}[信息]${gl_bai} $*${gl_bai}"; }
log_ok() { echo -e "${gl_lv}[成功]${gl_bai} $*${gl_bai}"; }
log_warn() { echo -e "${gl_huang}[警告]${gl_bai} $*${gl_bai}"; }
log_error() { echo -e "${gl_hong}[错误]${gl_bai} $*${gl_bai}" >&2; }

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c${gl_bai}"
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
    echo -ne "${gl_lv}即将返回 ${gl_huang}${menu_name} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c${gl_bai}"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c${gl_bai}"
    sleep_fractional 0.6
    echo ""
    clear
}

handle_y_n() {
    echo -ne "\r${gl_hong}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai}) ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c${gl_bai}"
    sleep_fractional 0.3
    echo -ne "\r${gl_huang}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai}) ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c${gl_bai}"
    sleep_fractional 0.3
    echo -ne "\r${gl_lv}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai}) ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c${gl_bai}"
    sleep_fractional 0.6
    echo ""
    return 2
}

exit_animation() {
    echo -ne "\r${gl_lv}即将退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c${gl_bai}"
    sleep_fractional 1
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c${gl_bai}"
    sleep_fractional 1
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
    echo -ne "\r\033[K${gl_huang}无效的输入,请重新输入! ${gl_zi} 1 ${gl_huang} 秒后返回${gl_bai}"
    sleep_fractional 1
    echo -ne "\r\033[K${gl_lv}无效的输入,请重新输入! ${gl_zi}0${gl_lv} 秒后返回${gl_bai}"
    sleep_fractional 0.5
    echo -ne "\r\033[K"
    continue
}

rename_tv_files_ultimate() {
    local VIDEO_EXTS=("mp4" "mkv" "avi" "mov" "wmv" "flv" "webm" "m4v" "mpg" "mpeg" "kvm")
    local PREFIX=""
    local SEASON="01"
    local START_EP="1"
    local preview_mode=1
    local rename_count=0
    local auto_detected=0
    local detection_results=()

    local prefix_set=0
    local preview_done=0

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
                    echo -e "  ${gl_lv}${index}.${gl_bai} ${gl_bufan}${type}${gl_bai} (${percentage}% 文件)${gl_bai}"
                else
                    echo -e "  ${gl_huang}${index}.${gl_bai} ${gl_bufan}${type}${gl_bai} (${percentage}% 文件)${gl_bai}"
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
        echo -e "${gl_zi}>>> 电视剧文件重命名${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        local files=()
        local episode_info=()
        local pattern_types=()
        scan_video_files files episode_info pattern_types
        if [ ${#files[@]} -eq 0 ]; then
            log_error "未找到可识别的视频文件！"
            echo -e "${gl_bai}支持格式: ${gl_bufan}${VIDEO_EXTS[*]}${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单${gl_bai}"
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
        echo -e "${gl_huang}找到 ${gl_lv}${#files[@]} ${gl_huang}个可识别文件:${gl_bai}"
        echo -e ""
        for ((i = 0; i < ${#files[@]}; i++)); do
            local filename=$(basename -- "${files[$i]}")
            IFS=':' read -r episode season type <<<"${episode_info[$i]}"
            echo -e "  ${gl_bufan}$(safe_printf "%02d" $((i + 1))).${gl_bai} E$(safe_printf "%02d" "$episode") [${type}] - $filename${gl_bai}"
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
                echo -e "  ${gl_bufan}${pattern}:${gl_lv} ${count} ${gl_bai}文件 (${percentage}%)${gl_bai}"
            done
        fi

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        if [ -n "$PREFIX" ]; then
            echo -e "${gl_bufan}当前设置:${gl_bai}"
            echo -e "  ${gl_bufan}剧集前缀:${gl_bai} $PREFIX${gl_bai}"
            echo -e "  ${gl_bufan}起始季号:${gl_bai} S$SEASON${gl_bai}"
            echo -e "  ${gl_bufan}起始集数:${gl_bai} E$(safe_printf "%02d" $START_EP)${gl_bai}"
            if [ $auto_detected -eq 1 ]; then
                echo -e "  ${gl_lv}✓ 智能检测已应用${gl_bai}"
            fi
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        fi

        # =========菜单行根据状态切换显示文字颜色=========
        if [[ $prefix_set -eq 1 ]]; then
            echo -e "${gl_bufan}1.  ${gl_bai}设置剧集前缀 ${gl_lv}★ 已设置${gl_bai}"
        else
            echo -e "${gl_bufan}1.  ${gl_bai}设置剧集前缀 ${gl_hong}★ 必须设置${gl_bai}"
        fi
        echo -e "${gl_bufan}2.  ${gl_bai}设置起始季号 ${gl_huang}★ 默认S01（非必选）${gl_bai}"
        echo -e "${gl_bufan}3.  ${gl_bai}设置起始集数 ${gl_huang}★ 默认E01（非必选）${gl_bai}"
        if [[ $preview_done -eq 1 ]]; then
            echo -e "${gl_bufan}4.  ${gl_bai}预览命名结果 ${gl_lv}★ 已预览${gl_bai}"
        else
            echo -e "${gl_bufan}4.  ${gl_bai}预览命名结果 ${gl_hong}★ 强制预览${gl_bai}"
        fi

        if [ $preview_mode -eq 1 ] && [ -n "$PREFIX" ]; then
            echo -e "${gl_bufan}5.  ${gl_lv}执行重命名   ✓ 可执行${gl_bai}"
        else
            echo -e "${gl_bufan}5.  ${gl_bai}执行重命名   ${gl_hong}✗ 不可执行${gl_bai}"
        fi
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_hong}0.  ${gl_bai}退出脚本${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" choice
        case $choice in
        1)
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
                echo -e "  ${gl_bufan}${idx}.${gl_bai} ${gl_lv}${candidates[$i]}${gl_bai} (出现 ${counts[$i]} 次, ${percentage}%)${gl_bai}"
            done
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_bai}推荐: ${gl_lv}${candidates[0]}${gl_bai} (${gl_huang}回车直接使用推荐${gl_bai})${gl_bai}"
            echo -e "${gl_bai}示例: ${gl_bufan}${candidates[0]}-S${SEASON}E01.扩展名${gl_bai}"
            echo -e "${gl_bai}指定: ${gl_bai}手动输入自定义前缀${gl_bai}"
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
            prefix_set=1   # 标记前缀已设置
            preview_done=0 # 修改前缀后重置预览状态
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        2)
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
                    echo -e "  ${gl_bufan}S${season}:${gl_bai} ${count} 文件 (${percentage}%)${gl_bai}"
                done
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            fi
            echo -e "${gl_bai}当前季号: ${gl_bufan}S${SEASON}${gl_bai}"
            echo -e "${gl_bai}示例: ${gl_bufan}01${gl_bai} 表示第 ${gl_bufan}1${gl_bai} 季 (将显示为 S01)${gl_bai}"
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
                preview_done=0 # 修改季号重置预览状态
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
            else
                log_error "请输入有效的数字 (1-99)！"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
            fi
            ;;
        3)
            echo -e ""
            echo -e "${gl_zi}>>> 设置起始集数${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            if [ ${#episode_info[@]} -gt 0 ]; then
                local first_info="${episode_info[0]}"
                local last_info="${episode_info[-1]}"
                IFS=':' read -r first_ep first_season first_type <<<"$first_info"
                IFS=':' read -r last_ep last_season last_type <<<"$last_info"
                echo -e "${gl_bai}识别的集数范围:${gl_bai}"
                echo -e "  ${gl_bufan}最小:${gl_bai} E$(safe_printf "%02d" "$first_ep") (${first_type})${gl_bai}"
                echo -e "  ${gl_bufan}最大:${gl_bai} E$(safe_printf "%02d" "$last_ep") (${last_type})${gl_bai}"
                echo -e "  ${gl_bufan}建议:${gl_bai} 从 E$(safe_printf "%02d" "$first_ep") 开始${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            fi
            echo -e "${gl_bai}当前起始集数: ${gl_bufan}E$(safe_printf "%02d" "$START_EP")${gl_bai}"
            echo -e "${gl_bai}示例: ${gl_bufan}26${gl_bai} 表示从第 ${gl_bufan}26${gl_bai} 集开始编号${gl_bai}"
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
                preview_done=0 # 修改起始集数重置预览状态
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
            else
                log_error "请输入有效的集数 (1-999)！"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
            fi
            ;;
        4)
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
            echo -e "  ${gl_bufan}剧集前缀:${gl_bai} $PREFIX${gl_bai}"
            echo -e "  ${gl_bufan}起始季号:${gl_bai} S$SEASON${gl_bai}"
            echo -e "  ${gl_bufan}起始集数:${gl_bai} E$(safe_printf "%02d" "$START_EP")${gl_bai}"
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
                echo -e "    识别为: ${type} (E$(safe_printf "%02d" "$original_ep"))${gl_bai}"
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
                    echo -e "  ${gl_bufan}${type}:${gl_bai} ${count} 文件 (${percentage}%)${gl_bai}"
                done
            fi
            preview_mode=1
            preview_done=1 # 标记已完成预览
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
            log_info "预览完成，共 ${gl_lv}${#detection_results[@]} ${gl_bai}个文件"
            if [ ${#files[@]} -gt 0 ]; then
                log_info "识别准确率: ${gl_lv}${accuracy}${gl_bai}%"
            fi
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        5)
            if [ $preview_mode -eq 0 ]; then
                echo -e ""
                log_error "请先预览重命名结果！"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                exit_animation
                continue
            fi
            if [ ${#detection_results[@]} -eq 0 ]; then
                echo -e ""
                log_error "请先设置剧集前缀，或没有可重命名的文件！"
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
            echo -e "  ${gl_bufan}总文件数:${gl_bai} ${#detection_results[@]}${gl_bai}"
            for i in "${!type_array[@]}"; do
                local type="${type_array[i]}"
                local count="${type_count_array[i]}"
                echo -e "  ${gl_bufan}${type}:${gl_bai} ${count} 文件${gl_bai}"
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
                        echo -e "  识别: ${type} (E$(safe_printf "%02d" "$original_ep"))${gl_bai}"
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
                echo -e "${gl_lv}成功:${gl_bai} $success_count 个文件${gl_bai}"
                echo -e "${gl_hong}失败:${gl_bai} $fail_count 个文件${gl_bai}"
                log_ok "重命名完成！"
                preview_mode=0
                auto_detected=0
                detection_results=()
                # 重命名完成重置状态标记
                prefix_set=0
                preview_done=0
                PREFIX=""
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
                ;;
            [Nn])
                log_info "已取消重命名操作"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
                ;;
            *)
                handle_y_n
                ;;
            esac
            ;;
        0) exit_script ;;
        *) handle_invalid_input ;;
        esac
    done
}

rename_tv_files_ultimate
