#!/bin/bash
# =============================================================
#  一键安装：临时目录过期清理计划任务 + logrotate 日志轮转
#  用法: sudo bash install_crontab_tmp.sh
#  说明: 幂等，可重复执行；已存在则自动去重更新
# =============================================================
set -euo pipefail

# ---------- 可配置区（按需修改，也可用同名环境变量覆盖） ----------
TMP_DIR="${TMP_DIR:-/vol2/1000/tmp}"              # 目标临时目录
EXPIRE_ATIME="${EXPIRE_ATIME:-+1}"              # 过期时间 atime：+0.5 = 12小时（+1=24h, +3=3天）
LOG_FILE="${LOG_FILE:-/var/log/crontab_tmp.log}"  # 日志文件
CLEAN_SCRIPT="${CLEAN_SCRIPT:-/usr/local/bin/crontab_tmp.sh}" # 清理脚本路径
CRON_SCHED="${CRON_SCHED:-*/10 * * * *}"          # 执行频率：每10分钟
ROTATE_KEEP="${ROTATE_KEEP:-7}"                   # logrotate 保留历史日志份数
# ---------- 配置结束 ----------

CRON_LINE="${CRON_SCHED} ${CLEAN_SCRIPT} >/dev/null 2>&1"

# 校验 root 权限
if [[ "$(id -u)" -ne 0 ]]; then
    echo "[ERROR] 请使用 root 或 sudo 执行本脚本"
    exit 1
fi

# 校验目标目录
if [ ! -d "${TMP_DIR}" ]; then
    echo "[WARN] 目标目录不存在: ${TMP_DIR}（可继续安装，清理时会记录 ERROR 日志）"
fi

# ================= 1. 创建清理脚本 =================
# 脚本目录不存在则创建
mkdir -p "$(dirname "${CLEAN_SCRIPT}")"
cat > "${CLEAN_SCRIPT}" <<EOF
#!/bin/bash
# 临时目录过期清理（atime 判断，超过 ${EXPIRE_ATIME} 天无访问即删除）
set -uo pipefail
TMP_DIR="${TMP_DIR}"
EXPIRE_ATIME="${EXPIRE_ATIME}"
LOG_FILE="${LOG_FILE}"

log() {
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] \$*" >> "\$LOG_FILE"
}

if [ ! -d "\${TMP_DIR}" ]; then
    log "ERROR: 目录不存在 \${TMP_DIR}"
    exit 1
fi

[ -d "\$(dirname "\$LOG_FILE")" ] || mkdir -p "\$(dirname "\$LOG_FILE")"

log "==== 开始清理 \${TMP_DIR} (atime>\${EXPIRE_ATIME}) ===="
# 删除过期文件（-print 记录删除清单；不需要明细可去掉 -print）
find "\${TMP_DIR}" -mindepth 1 -type f -atime "\${EXPIRE_ATIME}" -print -delete >> "\$LOG_FILE" 2>&1
# 删除空目录（-mindepth 1 必须加，否则 TMP_DIR 变空时会被一起删掉）
find "\${TMP_DIR}" -mindepth 1 -type d -empty -print -delete >> "\$LOG_FILE" 2>&1
LEFT=\$(find "\${TMP_DIR}" -mindepth 1 | wc -l)
log "==== 清理完成，剩余条目：\${LEFT} ===="
EOF
chmod 700 "${CLEAN_SCRIPT}"
echo "[OK] 清理脚本已创建: ${CLEAN_SCRIPT}"

# ================= 2. 写入 crontab（自动去重） =================
# 备份现有 crontab
if crontab -l >/dev/null 2>&1; then
    crontab -l > "/tmp/crontab.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
    echo "[OK] 原 crontab 已备份至 /tmp/crontab.bak.*"
fi

# 移除旧条目后追加新条目
# 注意：grep -vF 在「无匹配行」时返回 1，必须加 || true，
# 否则 set -e 会中止子 shell，导致 echo 不执行、crontab 被写成空文件
( crontab -l 2>/dev/null | grep -vF "${CLEAN_SCRIPT}" || true ; echo "${CRON_LINE}" ) | crontab -

# 校验写入结果
if crontab -l 2>/dev/null | grep -qF "${CLEAN_SCRIPT}"; then
    echo "[OK] 计划任务已写入: ${CRON_LINE}"
    echo "     当前 crontab 中该任务:"
    crontab -l | grep -F "${CLEAN_SCRIPT}"
else
    echo "[ERROR] 计划任务写入失败，请手动执行: crontab -e"
    exit 1
fi

# ================= 3. 配置 logrotate =================
ROTATE_CONF="/etc/logrotate.d/crontab_tmp"
cat > "${ROTATE_CONF}" <<EOF
${LOG_FILE} {
    daily
    rotate ${ROTATE_KEEP}
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
EOF
echo "[OK] logrotate 配置已创建: ${ROTATE_CONF}"

# 校验 logrotate 配置（模拟运行，不实际执行）
if logrotate -d "${ROTATE_CONF}" 2>&1 | grep -qi "error"; then
    echo "[WARN] logrotate 配置校验出现异常，请检查"
else
    echo "[OK] logrotate 配置校验通过"
fi

# ================= 4. 可选：首次立即执行一次清理 =================
echo ""
echo "[提示] 是否立即执行一次清理验证？(y/N)"
read -r RUN_NOW || RUN_NOW="N"
if [[ "${RUN_NOW}" == "y" || "${RUN_NOW}" == "Y" ]]; then
    bash "${CLEAN_SCRIPT}" || true
    echo "--- 日志内容 ---"
    tail -20 "${LOG_FILE}" 2>/dev/null || echo "日志文件尚未生成"
fi

echo ""
echo "=============================================================="
echo " 安装完成。"
echo "  清理脚本:   ${CLEAN_SCRIPT}"
echo "  计划任务:   ${CRON_LINE}"
echo "  日志文件:   ${LOG_FILE}"
echo "  logrotate:  ${ROTATE_CONF} (保留${ROTATE_KEEP}份)"
echo ""
echo " 查看日志:  tail -f ${LOG_FILE}"
echo " 手动清理:  bash ${CLEAN_SCRIPT}"
echo " 预览将删除的文件(不带-delete):"
echo "   find ${TMP_DIR} -type f -atime ${EXPIRE_ATIME}"
echo "=============================================================="
