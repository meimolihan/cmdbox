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

handle_invalid_input() {
    echo -ne "\r\033[K${gl_huang}无效的输入,请重新输入! ${gl_zi} 1 ${gl_huang} 秒后返回"
    sleep_fractional 1
    echo -ne "\r\033[K${gl_lv}无效的输入,请重新输入! ${gl_zi}0${gl_lv} 秒后返回"
    sleep_fractional 0.5
    echo -ne "\r\033[K"
    return 2
}

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n 1 -s -r -p ""
    echo ""
    clear
}

main() {
    local DEFAULT_DIR="/vol1/1000/GitHub/cmdbox-main"
    local DEFAULT_IMG="mobufan/cmdbox"
    local BUILDER_NAME="mybuilder"
    local PLATFORMS="linux/amd64,linux/arm64"
    local DOCKER_PWD=""
    local WORK_DIR=""
    local IMAGE_FULL=""

    clear
    echo -e "${gl_zi}>>> 多架构镜像自动构建推送${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if [ $# -ge 1 ]; then
        DOCKER_PWD="$1"
        WORK_DIR="${DEFAULT_DIR}"
        IMAGE_FULL="${DEFAULT_IMG}"
        log_info "检测到传入密码参数，使用默认配置执行"
    else
        read -r -e -p "$(echo -e "${gl_bai}请输入项目目录 (回车使用默认 ${gl_huang}${DEFAULT_DIR}${gl_bai}): ")" input_dir
        WORK_DIR="${input_dir:-${DEFAULT_DIR}}"

        read -r -e -p "$(echo -e "${gl_bai}请输入镜像名称 (回车使用默认 ${gl_huang}${DEFAULT_IMG}${gl_bai}): ")" input_img
        IMAGE_FULL="${input_img:-${DEFAULT_IMG}}"

        read -r -s -p "$(echo -e "${gl_bai}请输入DockerHub密码 (格式参考 ${gl_huang}dckr_pat_xxxxxx${gl_bai}): ")" DOCKER_PWD
        echo ""
    fi

    log_info "校验工作目录 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    if [ ! -d "${WORK_DIR}" ]; then
        log_error "工作目录不存在：${WORK_DIR}"
        break_end
        exit 1
    fi
    cd "${WORK_DIR}"

    log_info "初始化 buildx 构建器 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    docker buildx use "${BUILDER_NAME}" 2>/dev/null || docker buildx create --name "${BUILDER_NAME}" --use

    log_info "加载 QEMU 跨架构模拟支持 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    docker buildx inspect "${BUILDER_NAME}" --bootstrap

    echo -e ""
    echo -e "${gl_huang}>>> 登录 DockerHub 镜像仓库 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo "${DOCKER_PWD}" | docker login -u mobufan --password-stdin

    echo -e ""
    echo -e "${gl_huang}>>> 清理 Docker 无用资源 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    docker system prune -f

    local BUILD_TAG=$(date +%Y.%m.%d)
    echo -e ""
    echo -e "${gl_huang}>>> 开始构建镜像 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}  平台：${gl_lv}${PLATFORMS}${gl_bai}"
    echo -e "${gl_bai}  标签：${gl_lv}latest ${gl_bai}/ ${gl_lv}${BUILD_TAG}${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    docker buildx build \
        --platform "${PLATFORMS}" \
        --no-cache \
        -t "${IMAGE_FULL}:latest" \
        -t "${IMAGE_FULL}:${BUILD_TAG}" \
        --push \
        .

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_ok "镜像构建推送完成！"
    log_ok "镜像地址：${gl_lv}${IMAGE_FULL}:latest ${gl_bai}、 ${gl_lv}${IMAGE_FULL}:${BUILD_TAG}${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

main "$@"
