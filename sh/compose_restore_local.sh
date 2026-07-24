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

sleep_fractional() {
    local seconds=$1
    if sleep "$seconds" 2>/dev/null; then return 0; fi
    if command -v perl >/dev/null 2>&1; then
        perl -e "select(undef, undef, undef, $seconds)"
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c "import time; time.sleep($seconds)"
    elif command -v python >/dev/null 2>&1; then
        python -c "import time; time.sleep($seconds)"
    else
        sleep $(echo "$seconds" | awk '{print int($1+0.999)}')
    fi
}

handle_invalid_input() {
    echo -e "${gl_hong}无效的输入，请重新输入！${gl_bai}"
    sleep_fractional 0.8
}

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n 1 -s -p ""
    echo ""
    clear
}

exit_script() {
    echo -ne "${gl_hong}感谢使用，再见！${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    clear
    exit 0
}

ARCHIVE_DIR="${1:-}"
TARGET_ROOT="${2:-}"

ask_if_empty() {
    local var_name="$1"
    local prompt="$2"
    local default="${3:-}"

    if [[ -z "${!var_name}" ]]; then
        if [[ -n "$default" ]]; then
            read -r -e -p "$(echo -e "${gl_bai}${prompt}${gl_huang}[$default]${gl_bai}: ")" input
            eval "$var_name=\"${input:-$default}\""
        else
            read -r -e -p "$(echo -e "${gl_bai}${prompt}: ")" input
            eval "$var_name=\"$input\""
        fi
    fi
}

interactive_setup() {
    clear
    echo -e "${gl_zi}>>> 交互式配置${gl_bai}"
    echo -e "${gl_bufan}——————————————————————————————————————————————————————————${gl_bai}"

    ask_if_empty ARCHIVE_DIR   "请输入压缩包目录"        "/vol2/1000/file/myfile/compose/downloads"
    ask_if_empty TARGET_ROOT   "请输入解压目标根目录"    "/vol1/1000/compose"

    echo ""
    echo -e "${gl_lv}配置完成:${gl_bai}"
    echo -e "压缩包目录 : ${gl_huang}$ARCHIVE_DIR${gl_bai}"
    echo -e "解压根目录 : ${gl_huang}$TARGET_ROOT${gl_bai}"
    echo ""
    sleep 1
}

if [[ $# -lt 2 ]]; then
    interactive_setup
fi

if [[ ! -d "$ARCHIVE_DIR" ]]; then
    log_error "压缩包目录不存在: $ARCHIVE_DIR"
    exit 1
fi

mkdir -p "$TARGET_ROOT"

extract_archive() {
    local archive_path="$1"
    local dest_dir="$2"
    local filename
    filename=$(basename "$archive_path")

    # 验证是有效的 gzip 文件
    if ! gzip -t "$archive_path" 2>/dev/null; then
        log_error "不是有效的 gzip 格式: $filename"
        return 1
    fi

    mkdir -p "$dest_dir"

    log_info "解压: $filename → $dest_dir"
    if tar -xzf "$archive_path" -C "$dest_dir" 2>/dev/null; then
        log_ok "解压完成: $filename"
        return 0
    else
        log_error "解压失败: $filename"
        return 1
    fi
}

declare -A projects

scan_archives() {
    projects=()
    local index=1

    local files
    if find "$ARCHIVE_DIR" -maxdepth 1 -name "*.tar.gz" -printf "%f\n" >/dev/null 2>&1; then
        mapfile -t files < <(find "$ARCHIVE_DIR" -maxdepth 1 -name "*.tar.gz" -printf "%f\n" | sort)
    else
        mapfile -t files < <(ls -1 "$ARCHIVE_DIR"/*.tar.gz 2>/dev/null | xargs -n1 basename | sort)
    fi

    if [[ ${#files[@]} -eq 0 ]]; then
        log_error "未找到任何 .tar.gz 文件"
        return 1
    fi

    for f in "${files[@]}"; do
        local name="${f%.tar.gz}"
        projects["$index"]="$name"
        ((index++))
    done
}

parse_selection() {
    local input="$1"
    local total="$2"
    local -n out_arr="$3"
    out_arr=()

    local tokens
    read -ra tokens <<< "$input"

    for token in "${tokens[@]}"; do
        if [[ "$token" =~ ^[0-9]+$ ]]; then
            if (( token >= 1 && token <= total )); then
                out_arr+=("$token")
            else
                return 1
            fi
        elif [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            local start="${BASH_REMATCH[1]}"
            local end="${BASH_REMATCH[2]}"
            if (( start < 1 || end > total || start > end )); then
                return 1
            fi
            for ((i=start; i<=end; i++)); do
                out_arr+=("$i")
            done
        else
            return 1
        fi
    done

    if [[ ${#out_arr[@]} -gt 0 ]]; then
        mapfile -t out_arr < <(printf "%s\n" "${out_arr[@]}" | sort -n | uniq)
        return 0
    fi
    return 1
}

IDX_W=0
NAME_W=0
GAP="    "

calc_layout() {
    local max_idx=0
    local max_name=0

    for i in "${!projects[@]}"; do
        (( i > max_idx )) && max_idx=$i
        local n="${projects[$i]}"
        (( ${#n} > max_name )) && max_name=${#n}
    done

    IDX_W=${#max_idx}
    NAME_W=$max_name
}

print_row() {
    local i1=$1
    local i2="${2:-}"

    local fmt_left
    local fmt_right
    fmt_left=$(printf "%%%dd.  %%-%ds" "$IDX_W" "$NAME_W")
    fmt_right=$(printf "%s%%%dd.  %%-%ss" "$GAP" "$IDX_W" "$NAME_W")

    if [[ -n "$i2" ]]; then
        printf "${gl_bufan}${fmt_left}${gl_bai}%s${gl_bufan}${fmt_right}${gl_bai}\n" \
            "$i1" "${projects[$i1]}" \
            "$GAP" \
            "$i2" "${projects[$i2]}"
    else
        printf "${gl_bufan}${fmt_left}${gl_bai}\n" \
            "$i1" "${projects[$i1]}"
    fi
}

batch_extract() {
    local -a selected_indices=("$@")
    local ok=0 fail=0 failed_names=()

    echo -e "${gl_huang}开始批量解压（共 ${#selected_indices[@]} 个项目）${gl_bai}"
    echo -e "${gl_bufan}——————————————————————————————————————————————————————————${gl_bai}"

    for idx in "${selected_indices[@]}"; do
        local name="${projects[$idx]}"
        local archive="$ARCHIVE_DIR/${name}.tar.gz"

        echo -ne "${gl_huang}[$idx] $name ... ${gl_bai}"
        if extract_archive "$archive" "$TARGET_ROOT" >/dev/null 2>&1; then
            echo -e "${gl_lv}✓ 成功${gl_bai}"
            ((ok++))
        else
            echo -e "${gl_hong}✗ 失败${gl_bai}"
            ((fail++))
            failed_names+=("$name")
        fi
    done

    echo -e "${gl_bufan}——————————————————————————————————————————————————————————${gl_bai}"
    echo -e "批量解压完成: ${gl_lv}成功 $ok${gl_bai}, ${gl_hong}失败 $fail${gl_bai}"

    if [[ ${#failed_names[@]} -gt 0 ]]; then
        echo -e "${gl_hong}失败项目: ${failed_names[*]}${gl_bai}"
    fi
}

main_menu() {
    scan_archives || return 1
    local total=${#projects[@]}
    calc_layout

    while true; do
        clear
        echo -e "${gl_zi}>>> Compose 项目本地还原工具${gl_bai}"
        echo -e "${gl_bufan}——————————————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bai}压缩包目录 : ${gl_huang}$ARCHIVE_DIR${gl_bai}"
        echo -e "${gl_bai}解压目标   : ${gl_huang}$TARGET_ROOT${gl_bai}"
        echo -e "${gl_bufan}——————————————————————————————————————————————————————————${gl_bai}"

        local i=1
        while (( i <= total )); do
            j=$((i + 1))
            if (( j <= total )); then
                print_row "$i" "$j"
            else
                print_row "$i" ""
            fi
            i=$((i + 2))
        done

        echo -e "${gl_bufan}——————————————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}99. ${gl_bai}解压全部项目${gl_bai}"
        echo -e "${gl_bufan}——————————————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}0.  ${gl_bai}返回/重新配置          ${gl_hong}00. ${gl_bai}退出脚本${gl_bai}"
        echo -e "${gl_bufan}——————————————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bai}提示: 可多选，如 ${gl_huang}1 3 5${gl_bai} 或 ${gl_huang}1-5${gl_bai} 或 ${gl_huang}1 3-5 8${gl_bai}"
        echo -e "${gl_bufan}——————————————————————————————————————————————————————————${gl_bai}"

        read -r -e -p "$(echo -e "${gl_bai}请输入项目序号: ")" choice

        if [[ -z "$choice" ]]; then
            handle_invalid_input
            continue
        fi

        case "$choice" in
        0)
            if [[ $# -lt 2 ]]; then
                interactive_setup
                scan_archives || return 1
                total=${#projects[@]}
                calc_layout
            else
                log_warn "非交互模式无法重新配置"
            fi
            ;;
        00) exit_script ;;
        99)
            clear
            echo -e "${gl_huang}正在解压全部项目 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}——————————————————————————————————————————————————————————${gl_bai}"
            all_indices=()
            for ((i=1; i<=total; i++)); do
                all_indices+=("$i")
            done
            batch_extract "${all_indices[@]}"
            break_end
            ;;
        *)
            selected_indices=()
            if parse_selection "$choice" "$total" selected_indices; then
                if [[ ${#selected_indices[@]} -eq 1 ]]; then
                    idx="${selected_indices[0]}"
                    name="${projects[$idx]}"
                    archive="$ARCHIVE_DIR/${name}.tar.gz"
                    echo -e ""
                    echo -e "${gl_huang}正在处理: $name${gl_bai}"
                    echo -e "${gl_bufan}——————————————————————————————————————————————————————————${gl_bai}"
                    if extract_archive "$archive" "$TARGET_ROOT"; then
                        echo -e "${gl_bufan}——————————————————————————————————————————————————————————${gl_bai}"
                        log_ok "$name 解压成功"
                    else
                        echo -e "${gl_bufan}——————————————————————————————————————————————————————————${gl_bai}"
                        log_error "$name 解压失败"
                    fi
                    echo -e "${gl_bufan}——————————————————————————————————————————————————————————${gl_bai}"
                    break_end
                else
                    clear
                    batch_extract "${selected_indices[@]}"
                    break_end
                fi
            else
                handle_invalid_input
            fi
            ;;
        esac
    done
}

main_menu