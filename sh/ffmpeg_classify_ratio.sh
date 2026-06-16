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
    export reset=$'\033[0m'
}
list_color_init

log_info()  { echo -e "${gl_lan}[信息]${gl_bai} $*"; }
log_ok()    { echo -e "${gl_lv}[成功]${gl_bai} $*"; }
log_warn()  { echo -e "${gl_huang}[警告]${gl_bai} $*"; }
log_error() { echo -e "${gl_hong}[错误]${gl_bai} $*" >&2; }

handle_invalid_input() {
    echo -ne "\r\033[K${gl_huang}无效的输入,请重新输入! ${gl_zi} 1 ${gl_huang} 秒后返回"
    sleep_fractional 1
    echo -ne "\r\033[K${gl_lv}无效的输入,请重新输入! ${gl_zi}0${gl_lv} 秒后返回"
    sleep_fractional 0.5
    echo -ne "\r\033[K"
    return 2
}

handle_y_n() {
    echo -e "${gl_hong}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai})${gl_hong}。${gl_bai}"
    sleep 1
    echo -e "${gl_huang}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai})${gl_huang}。${gl_bai}"
    sleep 1
    echo -e "${gl_lv}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai})${gl_lv}。${gl_bai}"
    sleep 0.5
    return 2
}

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n 1 -s -r -p ""
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

exit_animation() {
    echo -ne "${gl_lv}即将退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo ""
    clear
}

exit_script() {
    echo ""
    echo -ne "${gl_hong}感谢使用，再见！${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    clear
    exit 0
}

cancel_return() {
    local menu_name="${1:-上一级选单}"
    echo -e "${gl_lv}即将返回到 ${gl_huang}${menu_name}${gl_lv}${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    sleep 0.6
    echo ""
    clear
}

install_ffmpeg() {
    if command -v ffprobe &>/dev/null; then
        log_ok "ffmpeg已存在，无需安装"
        return 0
    fi
    log_info "开始自动安装ffmpeg..."
    if command -v apt &>/dev/null; then
        apt update -y && apt install ffmpeg -y
    elif command -v dnf &>/dev/null; then
        dnf install ffmpeg -y
    elif command -v yum &>/dev/null; then
        yum install ffmpeg -y
    elif command -v pacman &>/dev/null; then
        pacman -S ffmpeg --noconfirm
    else
        log_error "不支持当前系统包管理器，请手动安装ffmpeg"
        return 1
    fi
    if command -v ffprobe &>/dev/null; then
        log_ok "ffmpeg安装成功"
        return 0
    else
        log_error "ffmpeg安装失败"
        return 1
    fi
}

classify_images() {
    local src="${1:-.}"
    local tolerance=0.05

    local -A LANDSCAPE=(
        [4x3]=1.333333   [3x2]=1.500000
        [16x10]=1.600000 [16x9]=1.777778
        [17x9]=1.888889  [19x10]=1.900000
        [2x1]=2.000000   [18x9]=2.000000
        [20x9]=2.222222  [21x9]=2.333333
        [24x9]=2.666667  [32x9]=3.555556
    )

    local -A PORTRAIT=(
        [1x1]=1.000000   [4x5]=1.250000
        [3x4]=1.333333   [2x3]=1.500000
        [10x16]=1.600000 [9x16]=1.777778
        [6x13]=2.166667  [9x21]=2.333333
    )

    shopt -s nullglob nocaseglob
    local files=("$src"/*.{webp,jpg,jpeg,png,bmp,jfif})
    shopt -u nullglob nocaseglob
    local total=${#files[@]}

    clear
    echo -e "${gl_zi}>>> 图片智能分类（自动识别横竖屏）${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_info "共 ${total} 个图片文件"
    echo ""

    local -A stats
    local moved=0 errors=0

    for f in "${files[@]}"; do
        local name=$(basename "$f")
        local dim=$(ffprobe -v error -select_streams v:0 \
                    -show_entries stream=width,height -of csv=p=0 "$f" 2>/dev/null)
        [[ -z "$dim" ]] && { ((errors++)); log_error "处理失败: $name"; continue; }

        local w=${dim%%,*}
        local h=${dim#*,}

        local mode
        if (( w > h )); then
            mode="landscape"
            local -n R=LANDSCAPE
            local val=$(awk "BEGIN{printf\"%.10f\",$w/$h}")
        else
            mode="portrait"
            local -n R=PORTRAIT
            local val=$(awk "BEGIN{printf\"%.10f\",$h/$w}")
        fi

        local best_dir="other" best_diff=99
        for dir in "${!R[@]}"; do
            local diff=$(awk "BEGIN{d=$val-${R[$dir]};if(d<0)d=-d;print d}")
            local cmp=$(awk "BEGIN{print($diff<$best_diff)?1:0}")
            [[ $cmp -eq 1 ]] && { best_diff=$diff; best_dir=$dir; }
        done

        [[ $(awk "BEGIN{print($best_diff<$tolerance)?1:0}") -eq 0 ]] && best_dir="other"

        local target="$src/$mode/$best_dir"
        mkdir -p "$target"
        mv "$f" "$target/"
        ((moved++))
        local key="$mode/$best_dir"
        stats[$key]=$((stats[$key]+1))

        ((moved % 20 == 0)) && log_info "已处理: ${moved} 个图片"
    done

    echo ""
    echo -e "${gl_huang}>>> 分类完成，分类统计${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_info "统计结果："
    echo ""
    for key in $(printf '%s\n' "${!stats[@]}" | sort); do
        local pct=$(awk "BEGIN{printf\"%.1f\",${stats[$key]}/$total*100}")
        log_info "  $key: ${stats[$key]} 个图片 (${pct}%)"
    done
    echo ""
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_ok "共成功处理 ${moved} 个图片！"
    [[ $errors -gt 0 ]] && log_error "处理失败: ${errors} 个"
    local all_files=$(find "$src" -maxdepth 3 -type f 2>/dev/null | wc -l)
    log_info "脚本目录下现存总计文件数: ${all_files} 个"
}

main(){
    install_ffmpeg
    local run_path="${1:-.}"
    if [[ ! -d "$run_path" ]];then
        log_error "目录不存在: $run_path"
        exit 1
    fi
    classify_images "$run_path"
}

main "$@"
