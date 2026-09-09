#!/bin/bash
# ==============================================================================
# libx264 CRF恒定质量 H.264 批量目录转码脚本
# 参数：源目录 目标目录 是否删除源文件(true/false)
# 特性：前台启动自动nohup后台，加锁防重复运行，全局batch_main.log
# 智能判断：
#   非H264/yuv420p → CRF23重编码
#   H264+yuv420p，视频码率>3000kbps → CRF23瘦身重编码
#   H264+yuv420p，视频码率≤3000kbps → -c copy 无损流复制
# ==============================================================================
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
}
list_color_init

# 码率阈值：3000000 bps = 3000 kbps，可自行修改
BITRATE_THRESHOLD=3000000

LOCK="/tmp/videnc_batch.lock"

if [[ "${1:-}" != "__BG_RUN__" ]]; then
    if [[ -f "${LOCK}" ]]; then
        echo "任务正在运行，锁文件 ${LOCK} 存在，禁止重复启动"
        exit 1
    fi
    SRC_DIR_PARAM="${1:-}"
    DST_DIR_PARAM="${2:-}"
    DEL_SRC_PARAM="${3:-false}"
    nohup bash "$0" __BG_RUN__ "$@" >/dev/null 2>&1 &
    echo ">>> 命令行批量转码模式"
    echo "————————————————————————————————————————————————"
    echo "源 目 录：${SRC_DIR_PARAM}"
    echo "目标目录：${DST_DIR_PARAM}"
    echo "转码成功后删除源文件：${DEL_SRC_PARAM}"
    echo "✅ 任务已自动进入后台静默执行"
    echo "📖 查看全局日志：tail -f ${DST_DIR_PARAM}/batch_main.log"
    echo "❌ 强制结束进程：pkill -9 -f ffmpeg && rm -f /tmp/videnc_batch.lock"
    echo "————————————————————————————————————————————————"
    exit 0
fi

shift
SRC_ROOT="$1"
DST_ROOT="$2"
DEL_SRC="$3"
GLOBAL_LOG="${DST_ROOT}/batch_main.log"
mkdir -p "${DST_ROOT}"

log_print() {
    echo -e "$1"
    echo -e "$1" | sed -r 's/\x1B\[[0-9;]*[a-zA-Z]//g' >> "${GLOBAL_LOG}"
}

echo $$ > "${LOCK}"
trap 'rm -f "${LOCK}"' EXIT

calc_est_time() {
    local src_file="$1"
    local speed_x="1.5"
    local dur
    dur=$(ffprobe -v error -select_streams v:0 \
        -show_entries stream=duration \
        -of default=noprint_wrappers=1:nokey=1 "${src_file}" 2>/dev/null)
    if [[ -z "${dur}" || "${dur}" == "N/A" ]]; then
        log_print "[警告] 无法读取视频时长"
        return 1
    fi
    local dur_int
    dur_int=$(echo "scale=0; ${dur}/1" | bc)
    local dur_h=$(( dur_int / 3600 ))
    local dur_rem=$(( dur_int % 3600 ))
    local dur_m=$(( dur_rem / 60 ))
    local dur_s=$(( dur_rem % 60 ))
    local est_sec
    est_sec=$(echo "scale=0; ${dur} / ${speed_x}" | bc -l)
    local total_int=${est_sec%%.*}
    local h=$(( total_int / 3600 ))
    local rem=$(( total_int % 3600 ))
    local m=$(( rem / 60 ))
    local s=$(( rem % 60 ))
    log_print "视频时长：${dur} 秒（≈ ${dur_h}小时${dur_m}分${dur_s}秒）"
    log_print "预估耗时：${h}小时${m}分${s}秒 (转码速度=${speed_x}倍)"
    return 0
}

# 智能检测函数：输出三个变量 codec / pixfmt / vbitrate
get_video_info(){
    local f="$1"
    local out
    out=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,pix_fmt,bit_rate -of default=noprint_wrappers=1:nokey=1 "$f" 2>/dev/null)
    read -r codec pixfmt vbitrate <<< $(echo $out | tr '\n' ' ')
    echo "$codec $pixfmt $vbitrate"
}

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    read -r -n 1 -s -r -p ""
    echo ""
    clear
}

abspath() {
    local p="$1"
    if command -v realpath &>/dev/null; then
        realpath "$p" 2>/dev/null || readlink -f "$p" 2>/dev/null || echo "$p"
    else
        case "$p" in
            /*) echo "$p" ;;
            *)  echo "$PWD/$p" ;;
        esac
    fi
}

install_deps() {
    if command -v ffmpeg &>/dev/null; then
        if ffmpeg -h encoder=libx264 >/dev/null 2>&1; then
            return 0
        fi
    fi
    echo -e "${gl_huang}ffmpeg 未找到，尝试自动安装${gl_bai}"
    if command -v apt &>/dev/null; then
        sudo apt update && sudo apt install -y ffmpeg
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y ffmpeg
    elif command -v yum &>/dev/null; then
        sudo yum install -y epel-release && sudo yum install -y ffmpeg
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm ffmpeg
    elif command -v zypper &>/dev/null; then
        sudo zypper install -y ffmpeg
    elif command -v apk &>/dev/null; then
        sudo apk add ffmpeg
    elif command -v brew &>/dev/null; then
        brew install ffmpeg
    else
        echo -e "${gl_hong}无法自动安装 ffmpeg${gl_bai}"
    fi
    if ! command -v ffmpeg &>/dev/null; then
        echo -e "${gl_hong}ffmpeg 安装失败，请手动安装${gl_bai}"
        return 1
    fi
    return 0
}

do_batch_encode() {
    local SRC_ROOT="$1"
    local DST_ROOT="$2"
    local DEL_SRC="$3"
    local GLOBAL_LOG="${DST_ROOT}/batch_main.log"
    log_print "====================================="
    local now
    now=$(date +"%Y-%m-%d %H:%M:%S")
    log_print "[${now}] ====== 开始本轮批量任务 ======"
    log_print "阈值设置：视频码率大于 $((BITRATE_THRESHOLD/1000)) kbps 将进行CRF23重编码瘦身"

    for SRC_DIR in "${SRC_ROOT}"/*/; do
        [ -d "${SRC_DIR}" ] || continue
        DIR_NAME=$(basename "${SRC_DIR%/}")
        DST_DIR="${DST_ROOT}/${DIR_NAME}"
        log_print ""
        now=$(date +"%Y-%m-%d %H:%M:%S")
        log_print "[${now}] 正在处理目录：${DIR_NAME}"
        log_print "====================================="
        log_print "源 目 录: ${SRC_DIR}"
        log_print "目标目录: ${DST_DIR}"
        mkdir -p "${DST_DIR}"

        for src_file in "${SRC_DIR}"*.{mp4,mkv}; do
            [ -f "${src_file}" ] || continue
            FILENAME=$(basename "${src_file}")
            NAME_NO_EXT="${FILENAME%.*}"
            EXT="${FILENAME##*.}"
            if [[ "${EXT,,}" == "mkv" ]]; then
                DST_FILE="${DST_DIR}/${NAME_NO_EXT}.mp4"
            else
                DST_FILE="${DST_DIR}/${FILENAME}"
            fi
            LOG_FILE="${DST_DIR}/${NAME_NO_EXT}.log"
            log_print "正在处理：${src_file}"
            calc_est_time "${src_file}"

            # 获取视频信息
            read codec pixfmt vbitrate <<< $(get_video_info "${src_file}")
            log_print "文件名称: ${FILENAME}"
            log_print "源视频编码: $codec , pixfmt: $pixfmt , bitrate: $vbitrate bps"
            log_print "输出文件: ${DST_FILE}"
            log_print "日志文件: ${LOG_FILE}"

            NEED_ENCODE=1
            if [[ "$codec" == "h264" && "$pixfmt" == "yuv420p" ]];then
                if [[ "$vbitrate" != "N/A" && "$vbitrate" -le "${BITRATE_THRESHOLD}" ]];then
                    NEED_ENCODE=0
                    log_print "✅ H264+yuv420p，码率低于阈值，采用流复制封装（无损）"
                else
                    log_print "🔄 H264+yuv420p，但码率超过阈值，执行CRF23重编码瘦身"
                fi
            else
                log_print "🔄 非标准H264/yuv420p，执行CRF23重编码"
            fi

            if [[ $NEED_ENCODE -eq 1 ]];then
                ffmpeg -threads auto -probesize 32M -avioflags direct \
                    -i "${src_file}" -y \
                    -c:v libx264 -preset fast -profile:v main -crf 23 \
                    -c:a copy \
                    -movflags +faststart \
                    "${DST_FILE}" > "${LOG_FILE}" 2>&1
            else
                ffmpeg -threads auto -probesize 32M -avioflags direct \
                    -i "${src_file}" -y \
                    -c copy -movflags +faststart \
                    "${DST_FILE}" > "${LOG_FILE}" 2>&1
            fi

            if [ $? -eq 0 ]; then
                log_print "✅ ${FILENAME} 处理成功"
                rm -f "${LOG_FILE}"
                if [[ "${DEL_SRC}" == "true" ]]; then
                    log_print "✅ 删除源文件"
                    rm -f "${src_file}"
                    find "${SRC_ROOT}" -depth -type d -empty -delete
                fi
            else
                log_print "❌ ${FILENAME} 处理失败！保留源文件和日志，继续下一个文件"
            fi
            log_print ""
        done
    done

    now=$(date +"%Y-%m-%d %H:%M:%S")
    log_print "[${now}] ====== 本轮所有文件处理完成 ======"
    if [[ "${DEL_SRC}" == "true" ]]; then
        log_print "\n🎉 全部目录处理完毕，执行最后一次空目录清理"
        find "${SRC_ROOT}" -depth -type d -empty -delete
    else
        log_print "\n🎉 全部目录处理完毕（不删除源文件，跳过空目录清理）"
    fi
}

cli_mode() {
    local src_dir="$1"
    local dst_dir="$2"
    local del_src="${3:-false}"
    src_dir=$(abspath "${src_dir}")
    dst_dir=$(abspath "${dst_dir}")
    if [[ ! -d "${src_dir}" ]]; then
        echo "错误：源目录不存在 -> ${src_dir}"
        return 1
    fi
    mkdir -p "${dst_dir}" || { echo "无法创建目标目录"; break_end; return 1; }
    echo ">>> 命令行批量转码模式"
    echo "————————————————————————————————————————————————"
    echo "源 目 录：${src_dir}"
    echo "目标目录：${dst_dir}"
    echo "转码成功后删除源文件：${del_src}"
    echo "————————————————————————————————————————————————"
    do_batch_encode "${src_dir}" "${dst_dir}" "${del_src}"
    return $?
}

interactive_mode() {
    clear
    echo ">>> 交互式 一级子目录批量 libx264 CRF H.264智能处理（mp4/mkv → mp4）"
    echo "规则：H264+yuv420p且码率>3000kbps自动瘦身；低于阈值直接无损复制"
    echo "————————————————————————————————————————————————"
    read -r -e -p "输入源根目录: " src_in
    src_in=$(abspath "${src_in}")
    if [[ ! -d "${src_in}" ]]; then
        echo "源目录不存在"
        break_end
        return 1
    fi
    read -r -e -p "输入目标根目录: " dst_in
    dst_in=$(abspath "${dst_in}")
    mkdir -p "${dst_in}" || { echo "无法创建目标目录"; break_end; return 1; }
    read -r -e -p "$(echo -e "${gl_bai}处理成功是否删除源文件？ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" del_choice
    local del_src="false"
    if [[ "${del_choice}" =~ ^[Yy]$ ]]; then
        del_src="true"
    fi
    echo "————————————————————————————————————————————————"
    echo "源 目 录：${src_in}"
    echo "目标目录：${dst_in}"
    echo "删除源文件：${del_src}"
    echo "码率阈值：$((BITRATE_THRESHOLD/1000)) kbps"
    echo "————————————————————————————————————————————————"
    read -r -e -p "$(echo -e "${gl_bai}确认开始？ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
    if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
        echo "已取消任务"
        break_end
        return 0
    fi
    do_batch_encode "${src_in}" "${dst_in}" "${del_src}"
    break_end
}

main() {
    install_deps || exit 1
    if [[ $# -ge 1 ]]; then
        cli_mode "$@"
    else
        interactive_mode
    fi
}

main "$@"