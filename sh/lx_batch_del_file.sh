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

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n 1 -s -p ""
    echo ""
    clear
}

clear
echo -e "${gl_zi}>>> 批量删除指定文件工具${gl_bai}"
echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

if [[ -n "${1:-}" ]]; then
    SCAN_DIR="$1"
else
    read -r -e -p "$(echo -e "${gl_bai}请输入要扫描的目录路径: ")" SCAN_DIR
fi

if [[ -n "${2:-}" ]]; then
    DEL_FILE="$2"
else
    read -r -e -p "$(echo -e "${gl_bai}请输入要删除的文件名称(支持*通配符): ")" DEL_FILE
fi

echo -e ""
log_info "开始扫描目录: ${gl_huang}${SCAN_DIR}${gl_bai}"
log_info "要删除的文件: ${gl_lv}${DEL_FILE}${gl_bai}"
echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

log_info "正在扫描并预览匹配项 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
mapfile -t RESULT < <(find "${SCAN_DIR}" -type f -name "${DEL_FILE}" 2>/dev/null)
COUNT=${#RESULT[@]}

if [[ ${COUNT} -eq 0 ]]; then
    log_warn "未找到任何匹配的 ${DEL_FILE} 文件"
    break_end
    exit 0
fi

for line in "${RESULT[@]}"; do
    echo -e "${gl_bai}${line}"
done

echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
log_ok "扫描完成，共找到 ${gl_hong}${COUNT}${gl_bai} 个目标文件"
echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
read -r -e -p "$(echo -e "${gl_bai}确定删除以上所有文件？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" choice
case "${choice}" in
    [Yy])
        log_warn "正在删除，请稍候 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        for file in "${RESULT[@]}"; do
            rm -f "${file}"
        done
        log_ok "删除完成，共删除 ${COUNT} 个文件"
        ;;
    [Nn]|*)
        log_warn "已取消删除操作"
        ;;
esac
echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
break_end