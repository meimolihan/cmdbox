#!/bin/bash
# HEVC‑QSV批量转码 hvc1标记 nohup后台版｜兼容curl管道执行，fnOS N100/N305
# 用法: bash ffmpeg_video_hvc1_all.sh 源目录 输出目录 [del_src:true/false]
set -uo pipefail
######################## 配置区 ########################
LOCKFILE="/tmp/videnc_nohup.lock"
QSV_PRESET="fast"
QSV_BITRATE="2600k"
QSV_MAXRATE="5200k"
QSV_BUFSIZE="10400k"
QSV_GLOBAL_QUALITY=28
MOVFLAGS_FASTSTART=true
FF_THREADS=2
PROBESIZE="32M"
MAX_RETRY=1
KEEP_ALL_LOG=false
########################################################
gl_hui=$'\033[38;5;8m'
gl_hong=$'\033[38;5;9m'
gl_lv=$'\033[38;5;10m'
gl_huang=$'\033[38;5;11m'
gl_lan=$'\033[38;5;12m'
gl_zi=$'\033[38;5;13m'
gl_cyan=$'\033[38;5;14m'
gl_bai=$'\033[38;5;15m'
my_dirname(){
    local p="$1"
    [[ "$p" == */* ]] && { local x="${p%/*}"; [[ -z "$x" ]] && echo "/" || echo "$x"; } || echo "."
}
my_basename(){ local p="$1"; echo "${p##*/}"; }
g_interrupted=0
sig_handler(){
    g_interrupted=1
    echo -e "\n${gl_huang}[!] 收到终止信号，停止ffmpeg${gl_bai}"
    pkill -9 -f ffmpeg 2>/dev/null
}
install_deps(){
    echo -e "${gl_zi}>>> 检查依赖${gl_bai}"
    if ! command -v ffmpeg &>/dev/null || ! command -v ffprobe &>/dev/null;then
        echo -e "${gl_hong}[X] ffmpeg/ffprobe未找到${gl_bai}"
        exit 1
    fi
    echo -e "${gl_lv}ffmpeg/ffprobe 已安装: $(command -v ffmpeg)${gl_bai}"
    if ! ffmpeg -h encoder=hevc_qsv &>/dev/null;then
        echo -e "${gl_hong}[X] 不支持hevc_qsv编码器${gl_bai}"
        exit 1
    fi
    echo -e "${gl_lv}hevc_qsv 硬件编码器 ✅${gl_bai}"
    if command -v vainfo &>/dev/null;then
        vainfo &>/dev/null && echo -e "${gl_lv}VA‑API硬件环境正常 ✅${gl_bai}" || echo -e "${gl_huang}[!] vainfo异常${gl_bai}"
    else
        echo -e "${gl_huang}[i] 未安装vainfo${gl_bai}"
    fi
}
do_encode(){
    local src="$1" dst="$2" log="$3" retry="$4"
    local logdir; logdir=$(my_dirname "${log}")
    mkdir -p "${logdir}" 2>/dev/null
    >"${log}"
    [[ ! -f "${src}" ]] && { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✘源不存在 ${src}">>"${log}";return 127; }
    [[ ! -r "${src}" ]] && { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✘无读权限 ${src}">>"${log}";return 126; }
    if ! ffprobe -v error -show_format "${src}" >>"${log}" 2>&1;then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✘源文件损坏">>"${log}";return 10
    fi
    local dstdir; dstdir=$(my_dirname "${dst}")
    mkdir -p "${dstdir}" 2>/dev/null
    [[ ! -w "${dstdir}" ]] && { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✘输出目录无写权限">>"${log}";return 13; }
    echo "------------------------------------------------------------">>"${log}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] >>>开始转码 retry=${retry}">>"${log}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SRC:${src}">>"${log}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] DST:${dst}">>"${log}"
    local ffmpeg_cmd=(
        ffmpeg
        -threads "${FF_THREADS}"
        -probesize "${PROBESIZE}"
        -fflags +genpts+igndts
        -qsv_device /dev/dri/renderD128
        -extra_hw_frames 64
        -i "${src}"
        -y
        -c:v hevc_qsv
        -preset "${QSV_PRESET}"
        -global_quality "${QSV_GLOBAL_QUALITY}"
        -b:v "${QSV_BITRATE}"
        -maxrate "${QSV_MAXRATE}"
        -bufsize "${QSV_BUFSIZE}"
        -tag:v hvc1
    )
    [[ "${MOVFLAGS_FASTSTART}" == true ]] && ffmpeg_cmd+=(-movflags +faststart)
    ffmpeg_cmd+=(-avoid_negative_ts make_zero -c:a copy "${dst}")
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] CMD:${ffmpeg_cmd[*]}">>"${log}"
    "${ffmpeg_cmd[@]}">>"${log}" 2>&1
    local ret=$?
    [[ ${g_interrupted} -eq 1 ]] && { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️外部中断">>"${log}";return 255; }
    if [[ ${ret} -eq 0 ]];then
        if ffprobe -v error -show_streams "${dst}">>"${log}" 2>&1;then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✔完成 ${dst}校验正常">>"${log}"
            [[ "${KEEP_ALL_LOG}" == false ]] && rm -f "${log}"
            return 0
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✘输出视频损坏">>"${log}"
            rm -f "${dst}" 2>/dev/null
            return 2
        fi
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✘ffmpeg退出码=${ret}">>"${log}"
        rm -f "${dst}" 2>/dev/null
        return "${ret}"
    fi
}
run_batch_inner(){
    local src_root="$1" dst_root="$2" del_src="$3"
    local main_log="${dst_root}/batch_main.log"
    mkdir -p "${dst_root}"
    >"${main_log}"
    trap sig_handler SIGTERM SIGINT
    local ok=0 fail=0 skip=0 total=0
    local file_list=()
    while IFS= read -r -d '' line;do file_list+=("$line");done < <(find "${src_root}" -type f \( -iname "*.mp4" -o -iname "*.mkv" \) -print0 )
    for src_file in "${file_list[@]}";do
        [[ ${g_interrupted} -eq 1 ]] && { echo -e "\n[!]中断退出">>"${main_log}";break; }
        ((total++))
        local relpath="${src_file#${src_root}/}"
        local dst_file="${dst_root}/${relpath%.*}.mp4"
        local log_file="${dst_root}/${relpath%.*}.log"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] tail -f ${log_file}">>"${main_log}"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 文件:$(my_basename "${src_file}")">>"${main_log}"
        if [[ -f "${dst_file}" ]];then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⏭已存在跳过 ${dst_file}">>"${main_log}"
            ((skip++))
            echo >>"${main_log}"
            continue
        fi
        local rc=1
        for ((r=0;r<=MAX_RETRY;r++));do
            do_encode "${src_file}" "${dst_file}" "${log_file}" "${r}"
            rc=$?
            [[ ${rc} -eq 0 ]] && break
            [[ ${g_interrupted} -eq 1 ]] && { rc=255;break; }
            sleep 0.5
        done
        if [[ ${rc} -eq 0 ]];then
            ((ok++))
            [[ "${del_src}" == "true" ]] && rm -f "${src_file}"
        else
            ((fail++))
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌失败 rc=${rc} log=${log_file}">>"${main_log}"
        fi
        echo >>"${main_log}"
    done
    echo -e "\n====================================">>"${main_log}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 📊任务结束｜成功:${ok} 失败:${fail} 跳过:${skip} 总计:${total}">>"${main_log}"
}
cli_mode(){
    local src_in="$1" dst_in="$2" del_src="${3:-false}"
    exec 9>"${LOCKFILE}"
    if ! flock -n 9 ;then
        echo -e "${gl_hong}[X]已有任务在运行，禁止重复启动${gl_bai}"
        exit 1
    fi
    install_deps
    src_in=$(realpath -m "${src_in}")
    dst_in=$(realpath -m "${dst_in}")
    [[ ! -d "${src_in}" ]] && { echo -e "${gl_hong}[X]源目录不存在 ${src_in}${gl_bai}";exit 1; }
    mkdir -p "${dst_in}" || { echo -e "${gl_hong}[X]创建输出目录失败${gl_bai}";exit 1; }
    echo -e "${gl_cyan}————————————————————————————————————${gl_bai}"
    echo -e "${gl_zi}HEVC‑QSV批量转码 N100/N305 nohup后台${gl_bai}"
    echo -e "${gl_lan}源目录: ${src_in}${gl_bai}"
    echo -e "${gl_lan}输出目录: ${dst_in}${gl_bai}"
    echo -e "${gl_lan}删除源文件: ${del_src}${gl_bai}"
    echo -e "${gl_cyan}————————————————————————————————————${gl_bai}"
    # nohup后台，不使用setsid，不调用$0，规避/dev/fd问题
    nohup bash -c '
        src_in="$1";dst_in="$2";del_src="$3"
        export KEEP_ALL_LOG='"${KEEP_ALL_LOG}"'
        export QSV_PRESET='"${QSV_PRESET}"'
        export QSV_BITRATE='"${QSV_BITRATE}"'
        export QSV_MAXRATE='"${QSV_MAXRATE}"'
        export QSV_BUFSIZE='"${QSV_BUFSIZE}"'
        export QSV_GLOBAL_QUALITY='"${QSV_GLOBAL_QUALITY}"'
        export MOVFLAGS_FASTSTART='"${MOVFLAGS_FASTSTART}"'
        export FF_THREADS='"${FF_THREADS}"'
        export PROBESIZE='"${PROBESIZE}"'
        export MAX_RETRY='"${MAX_RETRY}"'
        '"$(declare -f my_dirname my_basename sig_handler do_encode run_batch_inner)"'
        run_batch_inner "${src_in}" "${dst_in}" "${del_src}"
    ' bash "${src_in}" "${dst_in}" "${del_src}" >"${dst_in}/nohup.out" 2>&1 &
    local bg_pid=$!
    exec 9<&-
    echo -e "${gl_lv}✅ nohup后台任务已启动 PID:${bg_pid}${gl_bai}"
    echo ""
    echo -e "${gl_zi}📋查看实时日志${gl_bai}"
    echo -e "${gl_hui}#批量总进度${gl_bai}"
    echo "tail -f ${dst_in}/batch_main.log"
    echo ""
    echo -e "${gl_hui}#查看进程${gl_bai}"
    echo "pgrep -af ffmpeg"
    echo ""
    echo -e "${gl_hui}#⛔停止全部任务${gl_bai}"
cat <<'EOF'
bash -c 'pkill -9 -f ffmpeg 2>/dev/null; rm -f /tmp/videnc_nohup.lock'
EOF
    echo -e "${gl_cyan}————————————————————————————————————${gl_bai}"
}
main(){
    [[ $# -lt 2 ]] && { echo "用法: $0 源目录 输出目录 [del_src:true/false]";exit 1; }
    cli_mode "$1" "$2" "${3:-false}"
}
main "$@"
