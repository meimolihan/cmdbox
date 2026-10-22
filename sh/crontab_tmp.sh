#!/bin/bash
# =============================================================
#  临时目录过期清理脚本（atime 判断，超过阈值无访问即删除）
#  由 install_crontab_tmp.sh 安装到 /usr/local/bin/crontab_tmp.sh
#  手动执行: bash /usr/local/bin/crontab_tmp.sh
# =============================================================
set -uo pipefail

# ---------- 可配置区（安装时由安装器写入） ----------
TMP_DIR="/vol2/1000/tmp"             # 目标临时目录
EXPIRE_ATIME="+1"                  # 过期时间 atime：+0.5 = 12小时（+1=24h, +3=3天）
LOG_FILE="/var/log/crontab_tmp.log"  # 日志文件
# ---------- 配置结束 ----------

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# 目标目录不存在 → 记录并退出
if [ ! -d "$TMP_DIR" ]; then
    log "ERROR: 目录不存在 ${TMP_DIR}"
    exit 1
fi

# 日志目录不存在则创建
[ -d "$(dirname "$LOG_FILE")" ] || mkdir -p "$(dirname "$LOG_FILE")"

log "==== 开始清理 ${TMP_DIR} (atime>${EXPIRE_ATIME}) ===="

# 1) 删除过期文件（-print 先记录清单再删除；不需要明细可去掉 -print）
#    -mindepth 1 保证不处理扫描根目录本身
find "$TMP_DIR" -mindepth 1 -type f -atime "$EXPIRE_ATIME" -print -delete >> "$LOG_FILE" 2>&1

# 2) 删除空目录（-mindepth 1 必须加：否则 TMP_DIR 变空时会被一起删掉）
find "$TMP_DIR" -mindepth 1 -type d -empty -print -delete >> "$LOG_FILE" 2>&1

# 3) 统计剩余内容
LEFT=$(find "$TMP_DIR" -mindepth 1 | wc -l)
log "==== 清理完成，剩余条目：${LEFT} ===="

exit 0
