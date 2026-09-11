#!/bin/bash

gl_hong='\033[0;31m'
gl_lv='\033[0;32m'
gl_huang='\033[1;33m'
gl_lan='\033[0;34m'
gl_hui='\033[1;30m'
gl_end='\033[0m'

STOP_FILE="./.move.stop"

move_mp4_and_cover() {
  local SEARCH_ROOT="${1:-.}"
  for f in ./*.mp4; do
    [ -f "$f" ] || continue
    base="${f%.mp4}"
    base_name="$(basename -- "$base")"
    target_dir="./$base_name"
    mkdir -p "$target_dir"
    mv -- "$f" "$target_dir/"
    webp=$(find "$SEARCH_ROOT" -type f -name "${base_name}.webp" | head -n1)
    if [ -n "$webp" ] && [ -f "$webp" ]; then
      mv -- "$webp" "$target_dir/"
      echo -e "${gl_lv}✅ 找到封面：$webp -> $target_dir/${gl_end}"
    else
      echo -e "${gl_huang}⚠️ 未找到 ${base_name}.webp${gl_end}"
    fi
  done
}

batch_run() {
  local work_dir="$1"
  local depth="$2"
  local stop_file="${work_dir}/.move.stop"

  echo -e "\n${gl_lan}===== 工作目录：${work_dir} | 遍历层级：maxdepth=${depth} =====${gl_end}"
  find "${work_dir}" -mindepth 1 -maxdepth "${depth}" -type d -print0 | while IFS= read -r -d '' dir; do
    if [[ -f "${stop_file}" ]]; then
      echo -e "\n${gl_hong}🛑 检测到停止标记，任务退出${gl_end}"
      rm -f "${stop_file}"
      return 0
    fi

    echo -e "\n${gl_lan}===== 开始处理目录：$dir =====${gl_end}"
    (
      cd "$dir" || { echo -e "${gl_hong}❌ 无法进入 $dir${gl_end}"; exit 1; }
      move_mp4_and_cover .
    )
    echo -e "${gl_lan}===== 目录 $dir 处理完成 =====${gl_end}\n"
  done
  echo -e "${gl_lv}✅ 全部目录处理完毕${gl_end}"
}

ARG_DIR="${1:-}"
ARG_DEPTH="${2:-}"

if [[ -z "${ARG_DIR}" ]]; then
  WORK_DIR="$(pwd)"
else
  WORK_DIR="${ARG_DIR}"
fi
WORK_DIR="$(realpath -- "${WORK_DIR}")"

if [[ -z "${ARG_DEPTH}" ]]; then
  echo -e "${gl_huang}请选择遍历目录层级：${gl_end}"
  echo -e "${gl_hui} 1 = 仅一级子目录（原版逻辑）${gl_end}"
  echo -e "${gl_hui} 2 = 一级+二级子目录${gl_end}"
  read -r -p "$(echo -e "${gl_huang}输入数字: ${gl_end}")" ARG_DEPTH
fi

if ! [[ "${ARG_DEPTH}" =~ ^[0-9]+$ ]]; then
  echo -e "${gl_hong}❌ 层级必须是数字！${gl_end}"
  exit 1
fi

echo -e "${gl_huang}工作目录: ${WORK_DIR}${gl_end}"
echo -e "${gl_huang}遍历maxdepth: ${ARG_DEPTH}${gl_end}"
read -r -p "$(echo -e "${gl_lv}确认开始？[Y/n] ${gl_end}")" confirm
confirm=${confirm:-Y}
if [[ ! "${confirm,,}" =~ ^y ]]; then
  echo -e "${gl_huang}任务已取消${gl_end}"
  exit 0
fi

batch_run "${WORK_DIR}" "${ARG_DEPTH}"