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

# 默认值
BACKUP_DIR="/vol2/1000/file/backup/2panel-backup"
KEEP_NUM=6
BIN_2PANEL="/usr/local/bin/2panel"

# 二进制校验
if [[ ! -x "${BIN_2PANEL}" ]];then
    echo -e "${gl_hong}❌ 错误：2panel二进制不存在或无执行权限 ${BIN_2PANEL}${gl_bai}"
    exit 1
fi

parse_args() {
    # set‑u兼容：${1:-} 不存在则为空字符串，不抛异常
    local p1="${1:-}"
    local p2="${2:-}"
    if [[ -z "${p1}" ]]; then
        return
    fi
    if [[ "${p1}" =~ ^[0-9]+$ ]]; then
        KEEP_NUM="${p1}"
        if [[ -n "${p2}" ]]; then
            BACKUP_DIR="${p2}"
        fi
    else
        BACKUP_DIR="${p1}"
        if [[ -n "${p2}" && "${p2}" =~ ^[0-9]+$ ]]; then
            KEEP_NUM="${p2}"
        fi
    fi
}
parse_args "$@"

echo -e ""
echo -e "${gl_zi}>>> 备份 2Panel${gl_bai}"
echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
echo -e "${gl_huang}保存目录：${gl_lv}${BACKUP_DIR}${gl_bai}"
echo -e "${gl_huang}保留数量：${gl_lv}${KEEP_NUM}${gl_bai}"

NOW=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_FILE="${BACKUP_DIR}/2Panel-${NOW}.zip"
mkdir -p "${BACKUP_DIR}"

echo -e ""
echo -e "${gl_huang}>>> 停止 2panel 服务${gl_bai}"
systemctl stop 2panel

echo -e ""
echo -e "${gl_lan}>>> 执行备份：${BACKUP_FILE}${gl_bai}"
"${BIN_2PANEL}" backup "${BACKUP_FILE}"

cd "${BACKUP_DIR}" || exit 1
old_files=$(find . -maxdepth 1 -type f -name "2Panel-*.zip" -printf "%f\n" \
| sed -E 's/^2Panel-([0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2})\.zip$/\1 &/' \
| sort -k1,1 \
| head -n -${KEEP_NUM} \
| awk '{print $2}')

if [ -n "${old_files}" ];then
    echo -e ""
    echo -e "${gl_hong}>>> 将删除过期备份文件：${gl_bai}"
    echo "${old_files}"
    echo "${old_files}" | xargs -I {} rm -f "./{}"
else
    echo -e "${gl_lv}>>> 无过期备份需要删除${gl_bai}"
fi

echo -e ""
echo -e "${gl_huang}>>> 启动 2panel 服务${gl_bai}"
systemctl start 2panel
sleep 2
STATUS=$(systemctl is-active 2panel)
case "${STATUS}" in
    active)
        echo -e "${gl_lv}✅ 服务状态：运行中${gl_bai}"
        ;;
    inactive)
        echo -e "${gl_hong}❌ 服务状态：已停止${gl_bai}"
        ;;
    failed)
        echo -e "${gl_hong}❌ 服务状态：启动失败${gl_bai}"
        ;;
    *)
        echo -e "${gl_huang}⚠️ 服务状态：${STATUS}${gl_bai}"
        ;;
esac
echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"