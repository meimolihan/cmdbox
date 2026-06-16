#!/bin/bash
set -euo pipefail

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
    if command -v perl >/dev/null 2>&1; then perl -e "select(undef, undef, undef, $seconds)"; return 0; fi
    if command -v python3 >/dev/null 2>&1; then python3 -c "import time; time.sleep($seconds)"; return 0; fi
    if command -v python >/dev/null 2>&1; then python -c "import time; time.sleep($seconds)"; return 0; fi
    local int_seconds=$(echo "$seconds" | awk '{print int($1+0.999)}')
    sleep "$int_seconds"
}

column_if_available() {
    if command -v column &> /dev/null; then
        column -t -s $'\t'
    else
        cat
    fi
}

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

exit_animation() {
    echo -ne "${gl_lv}即将退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo ""
    clear
}

list_beautify_docker_images() {
    local filter_image="$1"
    {
        printf "%s%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "仓库" "标签" "镜像ID" "创建时间" "大小" "$reset"
        printf "%s%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "----------" "----------" "----------" "----------" "----------" "$reset"

        if [[ -n "$filter_image" ]]; then
            docker image ls --format "{{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedSince}}\t{{.Size}}" "$filter_image"
        else
            docker image ls --format "{{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedSince}}\t{{.Size}}"
        fi | \
        awk -v green="$gl_lv" -v yellow="$gl_huang" -v cyan="$gl_bufan" -v blue="$gl_lan" -v white="$gl_bai" -v reset="$reset" '
        BEGIN {FS="\t"; OFS="\t"}
        {
            id = substr($3, 1, 12)
            time = $4
            gsub(/ years ago/, "年前", time)
            gsub(/ year ago/, "年前", time)
            gsub(/ months ago/, "个月前", time)
            gsub(/ month ago/, "个月前", time)
            gsub(/ weeks ago/, "周前", time)
            gsub(/ week ago/, "周前", time)
            gsub(/ days ago/, "天前", time)
            gsub(/ day ago/, "天前", time)
            gsub(/ hours ago/, "小时前", time)
            gsub(/ hour ago/, "小时前", time)
            gsub(/ minutes ago/, "分钟前", time)
            gsub(/ minute ago/, "分钟前", time)
            gsub(/ seconds ago/, "秒前", time)
            gsub(/ second ago/, "秒前", time)
            gsub(/About /, "", time)
            
            print green $1 reset, yellow $2 reset, cyan id reset, blue time reset, white $5 reset
        }'
    } | column_if_available
}

parse_full_image_name() {
    local full_name="$1"
    if [[ "$full_name" == 0 ]]; then
        exit_script
    fi

    if [[ "$full_name" != *:* ]]; then
        full_name="${full_name}:latest"
    fi

    local repo part1 part2
    repo=$(echo "$full_name" | cut -d: -f1)
    if [[ "$repo" == */* ]]; then
        part1=$(echo "$repo" | cut -d/ -f1)
        part2=$(echo "$repo" | cut -d/ -f2-)
    else
        part1=""
        part2="$repo"
    fi

    IMAGE_TAG=$(echo "$full_name" | cut -d: -f2)
    DOCKER_USERNAME="$part1"
    IMAGE_NAME="$part2"
    FULL_IMAGE_NAME="$full_name"
}

# ===================== 核心修改：支持传参完整镜像名 =====================
# 第一个参数：工作目录（默认当前）
# 第二个参数：完整镜像名（可选）
WORK_DIR="${1:-.}"
INPUT_IMAGE=""

# 如果传入了2个参数：第1个是目录，第2个是镜像名
if [[ $# -ge 2 ]]; then
    INPUT_IMAGE="$2"
# 如果只传入1个参数且不是目录：当作镜像名，目录使用当前目录
elif [[ $# -eq 1 ]] && [[ ! -d "$1" ]]; then
    INPUT_IMAGE="$1"
    WORK_DIR="."
fi

if [ ! -d "${WORK_DIR}" ]; then
    log_error "工作目录不存在：${WORK_DIR}"
    exit 1
fi

cd "${WORK_DIR}" || {
    log_error "无法进入工作目录：${WORK_DIR}"
    exit 1
}

clear
echo -e "${gl_zi}>>> Docker 镜像构建与推送工具${gl_bai}"
echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
log_info "当前工作目录：${gl_lv}${PWD}"

# 传参则直接使用，否则交互式输入
if [[ -n "${INPUT_IMAGE}" ]]; then
    log_info "检测到传入镜像：${gl_lv}${INPUT_IMAGE}"
    FULL_IMAGE_INPUT="${INPUT_IMAGE}"
else
    read -r -e -p "$(echo -e "${gl_bai}请输入完整镜像名称(${gl_huang}示例: mobufan/nginx:latest${gl_bai}, 0返回): ")" FULL_IMAGE_INPUT
fi
parse_full_image_name "$FULL_IMAGE_INPUT"
# ======================================================================

echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
log_info "即将构建镜像：${gl_lv}${FULL_IMAGE_NAME}"
echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

log_info "开始执行 docker build ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
if docker build -t "${FULL_IMAGE_NAME}" .; then
    log_ok "镜像构建成功！${gl_lv}${FULL_IMAGE_NAME}"
    list_beautify_docker_images "${FULL_IMAGE_NAME}"
else
    log_error "镜像构建失败！"
    exit_animation
    exit 1
fi

echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

while true; do
    read -r -e -p "$(echo -e "${gl_bai}是否推送镜像到 Docker Hub？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" PUSH_CHOICE
    case "$PUSH_CHOICE" in
        [Yy]) break ;;
        [Nn])
            log_info "已取消推送"
            exit_animation
            exit 0
            ;;
        *) handle_y_n ;;
    esac
done

echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

if [[ -z "$DOCKER_USERNAME" ]]; then
    read -r -e -p "$(echo -e "${gl_bai}请输入 Docker Hub 用户名(${gl_huang}0${gl_bai}返回): ")" DOCKER_USERNAME
    [ "$DOCKER_USERNAME" = "0" ] && exit_script
    FULL_IMAGE_NAME="${DOCKER_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG}"
fi

log_info "检查 Docker Hub 登录状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
if ! docker info 2>/dev/null | grep -q "Username: ${DOCKER_USERNAME}"; then
    log_warn "未登录用户 ${DOCKER_USERNAME}，开始登录 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    docker login -u "${DOCKER_USERNAME}"
    if [ $? -ne 0 ]; then
        log_error "登录失败！"
        exit_animation
        exit 1
    fi
    log_ok "登录成功！"
else
    log_ok "已登录用户：${gl_lv}${DOCKER_USERNAME}"
fi

echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

while true; do
    read -r -e -p "$(echo -e "${gl_bai}确定推送 ${gl_lv}${FULL_IMAGE_NAME}${gl_bai}？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" CONFIRM
    case "$CONFIRM" in
        [Yy])
            log_info "开始推送镜像 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            docker push "${FULL_IMAGE_NAME}"
            if [ $? -eq 0 ]; then
                log_ok "镜像推送成功！"
            else
                log_error "镜像推送失败！"
            fi
            break
            ;;
        [Nn])
            log_info "已取消推送"
            exit_animation
            exit 0
            ;;
        *) handle_y_n ;;
    esac
done

echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
break_end