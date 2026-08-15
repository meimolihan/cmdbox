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

# 默认备份目录
BACKUP_DIR="/vol2/1000/file/backup/2panel-backup"

# 参数解析：支持传备份目录，兼容逻辑同备份脚本
# 用法：
# ./2panel_recover.sh                     # 使用默认目录，取最新备份
# ./2panel_recover.sh /data/bak           # 指定备份目录，取该目录最新备份
parse_args() {
    local p1="$1"
    if [[ -n "${p1}" ]]; then
        BACKUP_DIR="${p1}"
    fi
}
parse_args "$@"

echo -e "${gl_zi}>>> 2Panel 恢复脚本${gl_bai}"
echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
echo -e "${gl_huang}备份目录：${gl_lv}${BACKUP_DIR}${gl_bai}"

mkdir -p "${BACKUP_DIR}"

echo -e ""
echo -e "${gl_lan}>>> 查找最新备份文件${gl_bai}"
f=$(find "$BACKUP_DIR" -maxdepth 1 -type f -name "2Panel-*.zip" -printf "%f\n" \
| sed -E 's/^2Panel-([0-9]{4}-[0-9]{2}-[0-9]{2}(_[0-9]{2}-[0-9]{2}-[0-9]{2})?)\.zip$/\1 &/' \
| sort -k1,1 \
| tail -n1 \
| awk '{print $2}')

if [ -z "$f" ];then
    echo -e "${gl_hong}❌ 无备份文件，退出${gl_bai}"
    exit 1
fi

RESTORE_FILE="${BACKUP_DIR}/${f}"
echo -e "${gl_huang}恢复文件: ${gl_lv}${RESTORE_FILE}${gl_bai}"

echo -e ""
echo -e "${gl_huang}>>> 执行恢复 -y 自动确认${gl_bai}"
2panel restore -y "${RESTORE_FILE}"

echo -e ""
echo -e "${gl_huang}>>> 重载systemd配置并启动服务${gl_bai}"
systemctl daemon-reload
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