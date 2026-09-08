#!/bin/bash
# ==============================================================================
# HEVC hvc1 QSV批量转码脚本｜setsid后台静默执行
# 适配SR‑IOV VF虚拟GPU｜CPU解码 + hevc_qsv硬件编码 VBR模式
# 模式：交互式 / curl调用 / 目录批量 / 单文件
# ==============================================================================
set -uo pipefail

########################### 【可配置参数区】###########################
LOCKFILE="/tmp/ffmpeg_batch_encode.lock"
# QSV编码参数
QSV_PRESET="fast"
QSV_BV="2200k"
QSV_MAXRATE="4400k"
QSV_BUFSIZE="8800k"
# mp4 faststart：开启=支持流式播放；关闭=减少转码末尾大IO，适合机械盘/CIFS
MOVFLAGS_FASTSTART=true
# ffmpeg输入参数
FFMPEG_THREADS="auto"
PROBESIZE="32M"
AVIOFLAGS="direct"
######################################################################

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

# 锁增强：检测锁内PID是否存活，避免僵尸锁
lock_acquire() {
    if [[ -f "${LOCKFILE}" ]]; then
        local oldpid
        oldpid=$(<"${LOCKFILE}")
        if [[ -n "${oldpid}" ]] && kill -0 "${oldpid}" 2>/dev/null; then
            echo -e "\033[38;5;9m⚠️ 检测到已有转码任务(PID:${oldpid})运行，拒绝重复启动\033[0m"
            exit 1
        else
            echo -e "${gl_huang}⚠️ 锁文件残留，进程已死亡，自动清理旧锁${gl_bai}"
            rm -f "${LOCKFILE}"
        fi
    fi
    trap 'rm -f "${LOCKFILE}"' EXIT INT TERM HUP QUIT
    echo "$$" > "${LOCKFILE}"
}

install_deps() {
    echo -e "${gl_zi}>>> 检查依赖${gl_bai}"
    if command -v ffmpeg &>/dev/null; then
        echo -e "${gl_lv}ffmpeg 已安装: $(command -v ffmpeg)${gl_bai}"
        if ffmpeg -h encoder=hevc_qsv >/dev/null 2>&1; then
            echo -e "${gl_lv}hevc_qsv 硬件编码器 ✅${gl_bai}"
            if command -v vainfo &>/dev/null; then
                if vainfo >/dev/null 2>&1; then
                    echo -e "${gl_lv}VA‑API硬件环境正常 ✅${gl_bai}"
                else
                    echo -e "${gl_huang}⚠ vainfo检测异常：VA‑API驱动/权限异常，QSV可能失效${gl_bai}"
                fi
            else
                echo -e "${gl_huang}ℹ 未安装vainfo，跳过硬件校验${gl_bai}"
            fi
        else
            echo -e "${gl_hong}❌ ffmpeg不支持hevc_qsv，硬件转码不可用${gl_bai}"
            exit 1
        fi
        return 0
    fi
    echo -e "${gl_huang}ffmpeg未找到，尝试自动安装${gl_bai}"
    if command -v apt &>/dev/null; then
        apt update && apt install -y ffmpeg vainfo
    elif command -v dnf &>/dev/null; then
        dnf install -y ffmpeg vainfo
    elif command -v yum &>/dev/null; then
        yum install -y epel-release && yum install -y ffmpeg vainfo
    elif command -v pacman &>/dev/null; then
        pacman -S --noconfirm ffmpeg vainfo
    elif command -v zypper &>/dev/null; then
        zypper install -y ffmpeg vainfo
    elif command -v apk &>/dev/null; then
        apk add ffmpeg vainfo
    elif command -v brew &>/dev/null; then
        brew install ffmpeg
    else
        echo -e "${gl_hong}无法自动安装ffmpeg，请手动安装后重试${gl_bai}"
        exit 1
    fi
    if ! command -v ffmpeg &>/dev/null; then
        echo -e "${gl_hong}ffmpeg安装失败${gl_bai}"
        exit 1
    fi
    echo -e "${gl_lv}ffmpeg安装成功${gl_bai}"
    return 0
}

scan_videos() {
    local dir="$1"
    local exts=(mp4 mkv mov avi)
    local find_args=()
    for ext in "${exts[@]}"; do
        find_args+=(-iname "*.${ext}")
        find_args+=(-o)
    done
    if (( ${#find_args[@]} > 0 )); then
        unset 'find_args[${#find_args[@]}-1]'
    fi
    find "$dir" -maxdepth 1 -type f \( "${find_args[@]}" \) -print0 2>/dev/null | sort -z
}

do_encode() {
    local src="$1"
    local dst="$2"
    local log="$3"
    local fname
    fname=$(basename "$src")
    mkdir -p "$(dirname "$log")" 2>/dev/null

    # 前置校验
    if [[ ! -s "${src}" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✘ 源文件为空或不存在: ${src}" | tee -a "$log"
        return 1
    fi
    if [[ ! -w "$(dirname "$dst")" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✘ 输出目录无写入权限 $(dirname "$dst")" | tee -a "$log"
        return 1
    fi

    echo "------------------------------------------------------------" >> "$log"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] >>> 开始转码: ${fname}" | tee -a "$log"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 输入: ${src}" >> "$log"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 输出: ${dst}" >> "$log"

    # 组装ffmpeg参数
    local ffmpeg_cmd=(
        ffmpeg
        -threads "${FFMPEG_THREADS}"
        -probesize "${PROBESIZE}"
        -avioflags "${AVIOFLAGS}"
        -i "$src"
        -y
        -c:v hevc_qsv
        -preset "${QSV_PRESET}"
        -b:v "${QSV_BV}"
        -maxrate "${QSV_MAXRATE}"
        -bufsize "${QSV_BUFSIZE}"
        -tag:v hvc1
    )
    if [[ "${MOVFLAGS_FASTSTART}" == true ]]; then
        ffmpeg_cmd+=(-movflags +faststart)
    fi
    ffmpeg_cmd+=(-c:a copy "$dst")

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ffmpeg_cmd: ${ffmpeg_cmd[*]}" >> "$log"
    "${ffmpeg_cmd[@]}" >> "$log" 2>&1
    local ret=$?

    if [[ $ret -eq 0 ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✔ 完成: ${dst}" | tee -a "$log"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✘ 失败: ${src} (exit=${ret})" | tee -a "$log"
    fi
    return "${ret}"
}

run_queue() {
    local out_dir="$1"
    local use_suffix="$2"
    shift 2
    local files=("$@")
    local ok=0 fail=0
    local total=${#files[@]}

    # 提示网络挂载风险
    if mount | grep -qE "cifs|nfs|smb"; then
        echo -e "${gl_huang}⚠ 检测到网络文件系统，IO等待wa可能升高，建议关闭MOVFLAGS_FASTSTART${gl_bai}"
    fi

    for ((i=0; i<total; i++)); do
        local src="${files[$i]}"
        local fname=$(basename "$src")
        local name="${fname%.*}"
        local ext="${fname##*.}"
        local dst
        if [[ "$use_suffix" == "true" ]]; then
            dst="${out_dir}/${name}_HEVC-hvc1.${ext}"
        else
            dst="${out_dir}/${fname}"
        fi
        local log="${out_dir}/${name}.log"
        echo -e "${gl_bufan}[$((i+1))/${total}]${gl_bai} ${fname}"
        echo -e "${gl_hui}------------------------------------------------------------${gl_bai}"
        if [[ -f "$dst" ]]; then
            echo -e "${gl_huang}跳过（已存在）: ${dst}${gl_bai}"
            ((ok++))
            continue
        fi
        if do_encode "$src" "$dst" "$log"; then
            ((ok++))
        else
            ((fail++))
        fi
    done
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_hui}转码结束：成功 ${gl_lv}${ok}${gl_hui} / 失败 ${gl_hong}${fail}${gl_hui} / 总计 ${total}${gl_bai}"
    return 0
}

launch_bg() {
    local out_dir="$1"
    local use_suffix="$2"
    local tmpfiles="$3"
    env \
        "PATH=$PATH" \
        "LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-}" \
        "LIBVA_DRIVERS_PATH=${LIBVA_DRIVERS_PATH:-}" \
        "LIBVA_DRIVER_NAME=${LIBVA_DRIVER_NAME:-}" \
        "LOCKFILE=${LOCKFILE}" \
        "QSV_PRESET=${QSV_PRESET}" \
        "QSV_BV=${QSV_BV}" \
        "QSV_MAXRATE=${QSV_MAXRATE}" \
        "QSV_BUFSIZE=${QSV_BUFSIZE}" \
        "MOVFLAGS_FASTSTART=${MOVFLAGS_FASTSTART}" \
        "FFMPEG_THREADS=${FFMPEG_THREADS}" \
        "PROBESIZE=${PROBESIZE}" \
        "AVIOFLAGS=${AVIOFLAGS}" \
    setsid bash -c "
        out_dir='${out_dir}'
        use_suffix='${use_suffix}'
        tmpfiles='${tmpfiles}'
        files_list=()
        while IFS= read -r -d '' f; do
            [[ -n \"\$f\" ]] && files_list+=(\"\$f\")
        done < \"\$tmpfiles\"
        $(declare -f list_color_init abspath do_encode run_queue)
        list_color_init
        run_queue \"\$out_dir\" \"\$use_suffix\" \"\${files_list[@]}\"
        rm -f \"\$tmpfiles\"
    " > "${out_dir}/batch_main.log" 2>&1 &
    disown
    echo "$!"
}

interactive_mode() {
    clear
    echo -e "${gl_zi}>>> 交互式 HEVC hvc1 QSV转码${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_huang}当前目录: ${gl_lv}${PWD}${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e ""
    echo -e "${gl_hui}>>> 视频文件列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    local files=()
    while IFS= read -r -d '' f; do
        [[ -n "$f" ]] && files+=("$f")
    done < <(scan_videos "$PWD")
    local cnt=${#files[@]}
    if (( cnt == 0 )); then
        echo -e "${gl_hong}>>> [WARN] 当前目录未找到视频文件${gl_bai}"
        break_end
        return 1
    fi
    for ((i=0; i<cnt; i++)); do
        printf "${gl_bufan}%${#cnt}d.${gl_bai}   %s\n" "$((i+1))" "$(basename "${files[$i]}")"
    done
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_huang}666.${gl_bai} 批量转码全部视频"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}请输入序号选择单个视频，或输入 ${gl_huang}666${gl_bai} 处理全部: ${gl_bai}")" input
    local selected=()
    if [[ "$input" == "666" ]]; then
        selected=("${files[@]}")
    elif [[ "$input" =~ ^[0-9]+$ ]]; then
        local idx=$((input - 1))
        if (( idx >= 0 && idx < cnt )); then
            selected=("${files[$idx]}")
        else
            echo -e "${gl_hong}序号超出范围${gl_bai}"
            return 1
        fi
    else
        echo -e "${gl_hong}无效输入${gl_bai}"
        return 1
    fi
    read -r -e -p "$(echo -e "${gl_bai}转码后保存路径（${gl_huang}回车${gl_lv}=${gl_huang}当前目录${gl_bai}）: ${gl_bai}")" out_dir
    out_dir="${out_dir:-$PWD}"
    mkdir -p "$out_dir" || { echo -e "${gl_hong}无法创建目录${gl_bai}"; return 1; }
    local use_suffix="true"
    local abs_src abs_out
    abs_src=$(abspath "$PWD")
    abs_out=$(abspath "$out_dir")
    if [[ "$abs_src" == "$abs_out" ]]; then
        use_suffix="true"
        echo -e "${gl_huang}输出到当前目录，强制添加后缀${gl_bai}"
    else
        echo -e ""
        echo -e "${gl_hui}命名方式:${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "  ${gl_bufan}1.  ${gl_bai}使用原视频文件名"
        echo -e "  ${gl_bufan}2.  ${gl_bai}添加后缀 (_HEVC-hvc1)"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择 [${gl_huang}1${gl_bai}/${gl_lv}2${gl_bai}]，默认 ${gl_lv}2${gl_bai}: ")" naming
        naming="${naming:-2}"
        [[ "$naming" == "1" ]] && use_suffix="false" || use_suffix="true"
    fi
    local bg_choice
    read -r -e -p "$(echo -e "${gl_bai}是否在后台运行？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ${gl_bai}")" bg_choice
    if [[ "$bg_choice" =~ ^[Yy]$ ]]; then
        echo -e "${gl_lv}正在后台启动  ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_hui}日志将保存在: ${gl_lan}${out_dir}${gl_bai}"
        local tmpfiles
        tmpfiles=$(mktemp /tmp/encode_XXXXXX.files)
        printf '%s\0' "${selected[@]}" > "$tmpfiles"
        local pid
        pid=$(launch_bg "$out_dir" "$use_suffix" "$tmpfiles")
        echo -e ""
        echo -e "${gl_lv}后台任务已启动 (PID: ${pid})${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_hui}查看总日志: tail -f ${out_dir}/batch_main.log${gl_bai}"
        echo -e "${gl_hui}查看单文件:  tail -f ${out_dir}/<视频名>.log${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        return 0
    fi
    run_queue "$out_dir" "$use_suffix" "${selected[@]}"
    break_end
}

cli_mode() {
    local src="$1"
    local out_dir="${2:-$(dirname "$src")}"
    local use_suffix_str="${3:-true}"
    local run_bg_str="${4:-true}"
    local use_suffix="true"
    [[ "$use_suffix_str" == "false" ]] && use_suffix="false"
    local run_bg="true"
    [[ "$run_bg_str" == "false" ]] && run_bg="false"
    mkdir -p "$out_dir" || return 1
    if [[ -d "$src" ]]; then
        clear
        echo -e "${gl_zi}>>> 命令行目录批量模式 QSV‑hvc1${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_hui}源 目 录: ${gl_bai}${src}"
        echo -e "${gl_hui}输出目录: ${gl_bai}${out_dir}"
        echo -e "${gl_hui}后台运行: ${gl_bai}${run_bg}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        local files=()
        while IFS= read -r -d '' f; do
            [[ -n "$f" ]] && files+=("$f")
        done < <(scan_videos "$src")
        local cnt=${#files[@]}
        if (( cnt == 0 )); then
            echo -e "${gl_hong}错误：目录内未找到支持的视频文件${gl_bai}"
            return 1
        fi
        echo -e "${gl_lv}找到 ${gl_huang}${cnt}${gl_lv} 个待处理视频${gl_bai}"
        if [[ "$run_bg" == "true" ]]; then
            local tmpfiles
            tmpfiles=$(mktemp /tmp/encode_XXXXXX.files)
            printf '%s\0' "${files[@]}" > "$tmpfiles"
            local pid
            pid=$(launch_bg "$out_dir" "$use_suffix" "$tmpfiles")
            echo -e "${gl_lv}✅ 后台任务已启动 (PID: ${pid})${gl_bai}"
            echo -e "${gl_hui}总 日 志：tail -f ${out_dir}/batch_main.log${gl_bai}"
            echo -e "${gl_hui}强制停止：pkill -9 -f ffmpeg; rm -f ${LOCKFILE}"
            return 0
        fi
        run_queue "$out_dir" "$use_suffix" "${files[@]}"
        return $?
    fi
    if [[ ! -f "$src" ]]; then
        echo -e "${gl_hong}错误：文件不存在: ${src}${gl_bai}"
        return 1
    fi
    local fname=$(basename "$src")
    local name="${fname%.*}"
    local ext="${fname##*.}"
    local dst
    if [[ "$use_suffix" == "true" ]]; then
        dst="${out_dir}/${name}_HEVC-hvc1.${ext}"
    else
        dst="${out_dir}/${fname}"
    fi
    local log="${out_dir}/${name}.log"
    echo -e "${gl_zi}>>> 命令行单文件转码 QSV‑hvc1${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_hui}输入: ${gl_bai}${src}"
    echo -e "${gl_hui}输出: ${gl_bai}${dst}"
    echo -e "${gl_hui}日志: ${gl_bai}${log}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    if [[ -f "$dst" ]]; then
        echo -e "${gl_huang}跳过（已存在）: ${dst}${gl_bai}"
        return 0
    fi
    if [[ "$run_bg" == "true" ]]; then
        env \
            "PATH=$PATH" "LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-}" \
            "QSV_PRESET=${QSV_PRESET}" "QSV_BV=${QSV_BV}" \
            "QSV_MAXRATE=${QSV_MAXRATE}" "QSV_BUFSIZE=${QSV_BUFSIZE}" \
            "MOVFLAGS_FASTSTART=${MOVFLAGS_FASTSTART}" "FFMPEG_THREADS=${FFMPEG_THREADS}" \
            "PROBESIZE=${PROBESIZE}" "AVIOFLAGS=${AVIOFLAGS}" \
        setsid bash -c "
            $(declare -f list_color_init abspath do_encode)
            list_color_init
            do_encode '${src}' '${dst}' '${log}'
        " >/dev/null 2>&1 &
        disown
        echo -e "${gl_lv}✅ 单文件后台启动 PID:$!${gl_bai}"
        return 0
    fi
    do_encode "$src" "$dst" "$log"
    return $?
}

main() {
    lock_acquire
    install_deps || exit 1
    if [[ $# -ge 1 ]]; then
        cli_mode "$@"
    else
        interactive_mode
    fi
}

main "$@"
