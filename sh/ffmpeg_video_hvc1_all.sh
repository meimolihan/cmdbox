#!/bin/bash
# ==============================================================================
# HEVC hvc1 QSV批量目录转码脚本｜遍历一级子目录
# 支持：交互式 / 命令行传参
# 参数：源目录 目标目录 是否删除源文件(true/false)
# 更新：支持 mp4,mkv；mkv转码输出为mp4；mp4保持后缀不变
# 逻辑不变：遍历源下一级子文件夹，串行转码；成功后按需删源+清理空目录
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
    echo -e "${gl_zi}>>> 检查依赖${gl_bai}"
    if command -v ffmpeg &>/dev/null; then
        echo -e "${gl_lv}ffmpeg 已安装: $(command -v ffmpeg)${gl_bai}"
        if ffmpeg -h encoder=hevc_qsv >/dev/null 2>&1; then
            echo -e "${gl_lv}hevc_qsv 硬件编码器（FFmpeg编译支持）✅${gl_bai}"
            if command -v vainfo &>/dev/null; then
                if vainfo >/dev/null 2>&1; then
                    echo -e "${gl_lv}VA‑API硬件环境正常 ✅${gl_bai}"
                else
                    echo -e "${gl_huang}⚠ vainfo检测异常：VA‑API驱动/权限可能异常，QSV硬件可能无法工作${gl_bai}"
                fi
            else
                echo -e "${gl_huang}ℹ 未安装vainfo，跳过硬件环境校验${gl_bai}"
            fi
        else
            echo -e "${gl_hong}❌ 当前ffmpeg未编译支持 hevc_qsv 编码器，硬件转码不可用${gl_bai}"
        fi
        return 0
    fi

    echo -e "${gl_huang}ffmpeg 未找到，尝试自动安装 ...${gl_bai}"
    if command -v apt &>/dev/null; then
        sudo apt update && sudo apt install -y ffmpeg vainfo
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y ffmpeg vainfo
    elif command -v yum &>/dev/null; then
        sudo yum install -y epel-release && sudo yum install -y ffmpeg vainfo
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm ffmpeg vainfo
    elif command -v zypper &>/dev/null; then
        sudo zypper install -y ffmpeg vainfo
    elif command -v apk &>/dev/null; then
        sudo apk add ffmpeg vainfo
    elif command -v brew &>/dev/null; then
        brew install ffmpeg
    else
        echo -e "${gl_hong}无法自动安装 ffmpeg，请手动安装后重试${gl_bai}"
    fi
    if ! command -v ffmpeg &>/dev/null; then
        echo -e "${gl_hong}ffmpeg 安装失败，请手动安装${gl_bai}"
        return 1
    fi
    echo -e "${gl_lv}ffmpeg 安装成功${gl_bai}"
    return 0
}

do_batch_encode() {
    local SRC_ROOT="$1"
    local DST_ROOT="$2"
    local DEL_SRC="$3"

    for SRC_DIR in "${SRC_ROOT}"/*/; do
        DIR_NAME=$(basename "${SRC_DIR%/}")
        DST_DIR="${DST_ROOT}/${DIR_NAME}"

        echo -e "${gl_bufan}=====================================${gl_bai}"
        echo -e "${gl_zi}正在处理目录：${DIR_NAME}${gl_bai}"
        echo -e "${gl_hui}源目录: ${gl_lan}${SRC_DIR}${gl_bai}"
        echo -e "${gl_hui}目标目录: ${gl_lan}${DST_DIR}${gl_bai}"

        mkdir -p "${DST_DIR}"

        # 遍历mp4 mkv
        for src_file in "${SRC_DIR}"*.{mp4,mkv}; do
            [ -f "${src_file}" ] || continue

            FILENAME=$(basename "${src_file}")
            NAME_NO_EXT="${FILENAME%.*}"
            EXT="${FILENAME##*.}"

            # mkv输出后缀改为mp4，mp4保持mp4
            if [[ "${EXT,,}" == "mkv" ]]; then
                DST_FILE="${DST_DIR}/${NAME_NO_EXT}.mp4"
            else
                DST_FILE="${DST_DIR}/${FILENAME}"
            fi
            LOG_FILE="${DST_DIR}/${NAME_NO_EXT}.log"

            echo -e "${gl_bufan}开始转码: ${gl_bai}${src_file}"
            echo -e "${gl_bufan}输出文件: ${gl_bai}${DST_FILE}"
            echo -e "${gl_bufan}日志文件: ${gl_bai}${LOG_FILE}"

            ffmpeg -threads auto -probesize 32M -avioflags direct \
                -i "${src_file}" -y \
                -c:v hevc_qsv -preset fast -b:v 2600k -maxrate 5200k -bufsize 10400k -tag:v hvc1 \
                -c:a copy \
                "${DST_FILE}" > "${LOG_FILE}" 2>&1

            if [ $? -eq 0 ]; then
                echo -e "${gl_lv}✅ ${FILENAME} 转码成功${gl_bai}"
                if [[ "${DEL_SRC}" == "true" ]]; then
                    echo -e "${gl_lv}删除源文件${gl_bai}"
                    rm -f "${src_file}"
                    echo -e "${gl_huang}🔍 清理空目录...${gl_bai}"
                    find "${SRC_ROOT}" -type d -empty -delete
                fi
            else
                echo -e "${gl_hong}❌ ${FILENAME} 转码失败！保留源文件，继续下一个文件${gl_bai}"
            fi
        done
    done

    if [[ "${DEL_SRC}" == "true" ]]; then
        echo -e "\n${gl_lv}🎉 全部目录处理完毕，执行最后一次空目录清理${gl_bai}"
        find "${SRC_ROOT}" -type d -empty -delete
    else
        echo -e "\n${gl_lv}🎉 全部目录处理完毕（不删除源文件，跳过空目录清理）${gl_bai}"
    fi
}

cli_mode() {
    local src_dir="$1"
    local dst_dir="$2"
    local del_src="${3:-false}"

    src_dir=$(abspath "${src_dir}")
    dst_dir=$(abspath "${dst_dir}")

    if [[ ! -d "${src_dir}" ]]; then
        echo -e "${gl_hong}错误：源目录不存在 -> ${src_dir}${gl_bai}"
        return 1
    fi
    mkdir -p "${dst_dir}" || { echo -e "${gl_hong}无法创建目标目录${gl_bai}"; return 1; }

    echo -e "${gl_zi}>>> 命令行批量转码模式${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_hui}源目录：${gl_lan}${src_dir}${gl_bai}"
    echo -e "${gl_hui}目标目录：${gl_lan}${dst_dir}${gl_bai}"
    echo -e "${gl_hui}转码成功后删除源文件：${gl_huang}${del_src}${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    do_batch_encode "${src_dir}" "${dst_dir}" "${del_src}"
    return $?
}

interactive_mode() {
    clear
    echo -e "${gl_zi}>>> 交互式 一级子目录批量转码（mp4/mkv → mp4）${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    read -r -e -p "$(echo -e "${gl_bai}输入源根目录: ${gl_bai}")" src_in
    src_in=$(abspath "${src_in}")
    if [[ ! -d "${src_in}" ]]; then
        echo -e "${gl_hong}源目录不存在${gl_bai}"
        break_end
        return 1
    fi

    read -r -e -p "$(echo -e "${gl_bai}输入目标根目录: ${gl_bai}")" dst_in
    dst_in=$(abspath "${dst_in}")
    mkdir -p "${dst_in}" || { echo -e "${gl_hong}无法创建目标目录${gl_bai}"; break_end; return 1; }

    read -r -e -p "$(echo -e "${gl_bai}转码成功是否删除源文件?(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}) [默认N]: ")" del_choice
    local del_src="false"
    if [[ "${del_choice}" =~ ^[Yy]$ ]]; then
        del_src="true"
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_hui}源目录：${gl_lan}${src_in}${gl_bai}"
    echo -e "${gl_hui}目标目录：${gl_lan}${dst_in}${gl_bai}"
    echo -e "${gl_hui}删除源文件：${gl_huang}${del_src}${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}确认开始？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
    if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
        echo -e "${gl_huang}已取消任务${gl_bai}"
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