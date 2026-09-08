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
    local menu_name="${1:-退出脚本}"
    echo -ne "${gl_lv}即将返回 ${gl_huang}${menu_name} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
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

cancel_empty() {
    local menu_name="${1:-上一级选单}"
    echo -e "${gl_hong}空输入，返回 ${gl_huang}${menu_name} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo ""
    clear
}

handle_invalid_input() {
    echo -ne "\r\033[K${gl_huang}无效的输入,请重新输入! ${gl_zi} 1 ${gl_huang} 秒后返回"
    sleep_fractional 1
    echo -ne "\r\033[K${gl_lv}无效的输入,请重新输入! ${gl_zi}0${gl_lv} 秒后返回"
    sleep_fractional 0.5
    echo -ne "\r\033[K"
    return 2
}

# ====================== 文件迁移工具 主函数 ======================
video_move() {
    # 默认参数
    local DEF_EXT=""
    local DEF_SIZE=""
    local DEF_MODE="preview"

    local SRC_ROOT=""
    local DST_ROOT=""
    local EXCLUDE_EXT="$DEF_EXT"
    local EXCLUDE_SIZE="$DEF_SIZE"
    local RUN_MODE="$DEF_MODE"

    # 判断是否传参
    if [ $# -ge 1 ]; then
        # 传参模式：必须传入源目录、目标目录，后面3个参数可选
        if [ $# -lt 2 ]; then
            log_error "传参模式必须至少传入【源目录】【目标目录】两个参数！"
            log_info "用法示例:"
            log_info "$0 /vol/src /vol/dst"
            log_info "$0 /vol/src /vol/dst mp4 10 preview"
            exit_script
        fi
        SRC_ROOT="$1"
        DST_ROOT="$2"
        [ $# -ge 3 ] && EXCLUDE_EXT="$3"
        [ $# -ge 4 ] && EXCLUDE_SIZE="$4"
        [ $# -ge 5 ] && RUN_MODE="$5"
    else
        # ========== 交互式输入 ==========
        echo -e "${gl_zi}>>> 视频资源迁移工具${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        read -r -e -p "$(echo -e "${gl_bai}输入源根目录：")" TMP_SRC
        if [ -z "${TMP_SRC}" ]; then
            cancel_empty "交互菜单"
            return
        fi
        SRC_ROOT="${TMP_SRC}"

        read -r -e -p "$(echo -e "${gl_bai}输入目标根目录：")" TMP_DST
        if [ -z "${TMP_DST}" ]; then
            cancel_empty "交互菜单"
            return
        fi
        DST_ROOT="${TMP_DST}"

        read -r -e -p "$(echo -e "${gl_bai}输入要排除的文件后缀（多个逗号分隔，例 mp4,mkv；回车=不排除）：")" TMP_EXT
        [ -n "$TMP_EXT" ] && EXCLUDE_EXT="$TMP_EXT"

        read -r -e -p "$(echo -e "${gl_bai}大于多少MB的文件需要排除（十进制MB，回车=不按大小排除）：")" TMP_SIZE
        [ -n "$TMP_SIZE" ] && EXCLUDE_SIZE="$TMP_SIZE"

        read -r -e -p "$(echo -e "${gl_bai}模式选择：${gl_lv}preview${gl_bai}预览 / ${gl_hong}run${gl_bai}执行移动【回车默认preview】：")" TMP_MODE
        [ -n "$TMP_MODE" ] && RUN_MODE="$TMP_MODE"
    fi

    echo -e "\n${gl_bufan}==================== 配置汇总 ====================${gl_bai}"
    log_info "源 目 录    : ${gl_lan}${SRC_ROOT}${gl_bai}"
    log_info "目标目录    : ${gl_lan}${DST_ROOT}${gl_bai}"
    log_info "排除后缀    : ${gl_huang}${EXCLUDE_EXT:-无}${gl_bai}"
    log_info "排除大于    : ${gl_huang}${EXCLUDE_SIZE:-不限制}${gl_bai} MB(十进制)"
    log_info "运行模式    : ${gl_zi}${RUN_MODE}${gl_bai}"
    echo -e "${gl_bufan}==================================================${gl_bai}"

    read -r -p "$(echo -e "${gl_bai}确认继续？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}) ")" CONFIRM
    if [[ ! "${CONFIRM,,}" =~ ^y ]]; then
        log_warn "已取消任务，退出"
        exit_script
    fi

    # 循环遍历一级子文件夹
    for SRC_DIR in "${SRC_ROOT}"/*/; do
        # 取出文件夹名称
        DIR_NAME=$(basename "${SRC_DIR%/}")
        DST_DIR="${DST_ROOT}/${DIR_NAME}"

        echo -e "\n${gl_bufan}=====================================${gl_bai}"
        log_info "处理目录: ${gl_zi}${DIR_NAME}${gl_bai}"
        log_info "源 目 录: ${gl_lan}${SRC_DIR}${gl_bai}"
        log_info "目标目录: ${gl_lan}${DST_DIR}${gl_bai}"

        mkdir -p "${DST_DIR}"

        echo -e "\n${gl_huang}【待处理列表】${gl_bai}"
        CMD=(find "${SRC_DIR}" -maxdepth 1 ! -path "${SRC_DIR}" \( ! -type f -o \( -type f )

        # 拼接后缀排除
        if [ -n "$EXCLUDE_EXT" ]; then
            IFS=',' read -ra EXT_ARR <<< "$EXCLUDE_EXT"
            for ext in "${EXT_ARR[@]}"; do
                CMD+=(! -name "*.$ext")
            done
        fi
        # 拼接大小条件，MB十进制
        if [ -n "$EXCLUDE_SIZE" ]; then
            local SIZE_BYTES
            SIZE_BYTES=$(awk -v s="$EXCLUDE_SIZE" 'BEGIN{printf "%d", s*1000*1000+0.5}')
            CMD+=(! -size +"${SIZE_BYTES}"c)
        fi
        CMD+=(\) \))

        # 打印列表
        "${CMD[@]}"

        if [ "${RUN_MODE}" = "run" ]; then
            echo -e "\n${gl_hong}>>> 执行移动 <<<${gl_bai}"
            "${CMD[@]}" -exec mv {} "${DST_DIR}/" \;
        fi

        log_ok "${DIR_NAME} 处理完成"
    done

    echo -e "\n${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_ok "🎉 全部任务结束"
    break_end
}

# 入口：检测传参
if [ $# -ge 1 ]; then
    video_move "$@"
else
    video_move
fi