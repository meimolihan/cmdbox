#!/bin/bash
set -euo pipefail

gl_hui='\e[37m'
gl_hong='\033[31m'
gl_lv='\033[32m'
gl_huang='\033[33m'
gl_lan='\033[34m'
gl_zi='\033[35m'
gl_bufan='\033[96m'
gl_bai='\033[0m'

log_info()  { echo -e "${gl_lan}[信息]${gl_bai} $*"; }
log_ok()    { echo -e "${gl_lv}[成功]${gl_bai} $*"; }
log_warn()  { echo -e "${gl_huang}[警告]${gl_bai} $*"; }
log_error() { echo -e "${gl_hong}[错误]${gl_bai} $*" >&2; }

DEFAULT_LOG="/var/log/rsync/lx_sync_many_file_dir.log"
LOG_FILE="$DEFAULT_LOG"
LOG_DIR=$(dirname "$LOG_FILE")
mkdir -p "$LOG_DIR"

ROTATE_CONF="/etc/logrotate.d/rsync"
if [[ ! -f "$ROTATE_CONF" ]]; then
    sudo tee "$ROTATE_CONF" >/dev/null <<'EOF'
/var/log/rsync/*.log {
    daily   rotate 4   maxage 15   compress   delaycompress
    missingok   notifempty   copytruncate
}
EOF
fi

log(){
    local color=$1; shift
    echo -e "${color}${*}${gl_bai}"
    echo "[$(date '+%F %T')] $*" >> "$LOG_FILE"
}

echo -e "${gl_bai}
╔══════════════════════════════════════════════════════════════════════╗
║  多目录/文件增量同步工具  lx_sync_many_file_dir.sh  ${gl_huang}★ v1.3 ★${gl_bai}                         ║
║  一键多目标 · 彩色日志 · 完成度估算 · 耗时统计                       ║
║  ${gl_huang}使用说明：${gl_bai}                                                          ║
║    - 多目录同步：${gl_zi}lx_sync_many_file_dir.sh ${gl_hong}/etc/nginx ${gl_huang}/backup/nginx ${gl_lv}/mnt/nginx${gl_bai}        ║
║    - 多文件同步：${gl_zi}lx_sync_many_file_dir.sh -f ${gl_hong}test.txt ${gl_huang}/backup/test.txt ${gl_lv}/mnt/test.txt${gl_bai} ║
╚══════════════════════════════════════════════════════════════════════╝
${gl_bai}"

log_info "当前生效日志文件：${gl_huang}${LOG_FILE}${gl_bai}"
log_info "日志存放目录：${gl_huang}${LOG_DIR}${gl_bai}"

SINGLE_FILE=false
if [[ ${1:-} == "-f" ]]; then
    SINGLE_FILE=true
    shift
fi

if [[ $# -lt 2 ]]; then
    log_error "用法1（多目录同步）: ${gl_zi}$0${gl_bai} <${gl_hong}源目录${gl_bai}> <${gl_huang}目标目录1${gl_bai}> [${gl_lv}目标目录2${gl_bai}] "
    log_error "用法2（多文件同步）: ${gl_zi}$0 -f${gl_bai} <${gl_hong}源文件${gl_bai}> <${gl_huang}目标文件1${gl_bai}> [${gl_lv}目标文件2${gl_bai}] "
    exit 1
fi

source_path="${1%/}"; shift
targets=("$@")

{ echo ""; echo "========== lx_sync_many_file_dir.sh 启动：$(date '+%F %T') =========="; } >> "$LOG_FILE"

if ! $SINGLE_FILE; then
    log_info "${gl_bai}检查源目录是否存在${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    [[ -d $source_path ]] || { log_error "${gl_bai}源目录不存在：${gl_hong}$source_path${gl_bai}"; exit 1; }
    log_ok "${gl_bai}源目录存在：${gl_huang}$source_path${gl_bai}"
else
    log_info "${gl_bai}检查源文件是否存在${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    [[ -f $source_path ]] || { log_error "${gl_bai}源文件不存在：${gl_hong}$source_path${gl_bai}"; exit 1; }
    log_ok "${gl_bai}源文件存在：${gl_huang}$source_path${gl_bai}"
fi

log_info "${gl_bai}检查 ${gl_huang}rsync${gl_bai} 是否安装${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
if ! command -v rsync &>/dev/null; then
    log_warn "${gl_huang}rsync ${gl_bai}未安装，正在尝试自动安装${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    sudo apt-get update -qq && sudo apt-get install -y rsync || {
        log_error "${gl_huang}rsync${gl_bai} 安装失败，请手动安装后重试"; exit 1
    }
fi
log_ok "${gl_huang}rsync${gl_bai} 已就绪"

sync_and_check(){
    local tgt=$1; local idx=$2
    local tgt_dir=$(dirname "$tgt")

    if [[ ! -d $tgt_dir ]]; then
        log_warn "${gl_bai}目标目录不存在，正在创建：${gl_huang}$tgt_dir${gl_bai}"
        mkdir -p "$tgt_dir" || { log_error "创建失败：$tgt_dir"; return 1; }
    fi

    if $SINGLE_FILE; then
        log_warn "${gl_bai}开始同步文件：${gl_huang}$source_path${gl_bai}  →  ${gl_lv}$tgt${gl_bai}"
        rsync -avh --progress "$source_path" "$tgt" 2>&1 | tee -a "$LOG_FILE"
    else
        log_warn "${gl_bai}开始同步目录：${gl_huang}$source_path/${gl_bai}  →  ${gl_lv}$tgt/${gl_bai}"
        rsync -avhzp --progress --no-links --delete "$source_path/" "$tgt/" 2>&1 | tee -a "$LOG_FILE"
    fi
    local st=${PIPESTATUS[0]}

    if [[ $st -eq 0 ]]; then
        if $SINGLE_FILE; then
            log_ok "${gl_bai}文件同步成功（目标${gl_huang}$idx${gl_bai}）"
        else
            local src_size=$(du -sb "$source_path" | awk '{print $1}')
            local tgt_size=$(du -sb "$tgt"      | awk '{print $1}')
            local comp=$(awk -v s=$src_size -v t=$tgt_size 'BEGIN{printf "%.2f",(t/s)*100}')
            log_ok "${gl_bai}目录同步成功（目标${gl_huang}$idx${gl_bai}）  完成度约 ${gl_lv}${comp}${gl_bai}%"
        fi
    else
        log_error "同步失败（目标${gl_huang}$idx${gl_bai}），请查看日志"
    fi
}

start_time=$(date '+%F %T'); start_ts=$(date +%s)
log_info "${gl_bai}同步开始时间：${gl_lv}$start_time${gl_bai}"

for i in "${!targets[@]}"; do
    echo -e "${gl_bufan}----------------------------------------${gl_bai}"
    sync_and_check "${targets[$i]}" "$((i+1))"
done

end_time=$(date '+%F %T'); end_ts=$(date +%s)
total=$((end_ts - start_ts))
printf -v dur "%d时%02d分%02d秒" $((total/3600)) $(((total%3600)/60)) $((total%60))

echo -e "${gl_bufan}----------------------------------------${gl_bai}"
log_info "${gl_bai}同步结束时间：${gl_hong}$end_time${gl_bai}"
log_info "总用时：${gl_lv}$dur${gl_bai}"
if $SINGLE_FILE; then
    echo -e "${gl_lan}[信息]${gl_bai} 源文件：${gl_huang}$source_path${gl_bai}"
    echo -e "${gl_lan}[信息]${gl_bai} 目标文件列表："
    for target in "${targets[@]}"; do
        echo -e "${gl_lv}  ${target}${gl_bai}"
    done

    {
      echo "[源文件] $source_path"
      echo "[目标文件列表]"
      printf '  %s\n' "${targets[@]}"
    } >> "$LOG_FILE"
else
    echo -e "${gl_lan}[信息]${gl_bai} 源目录：${gl_huang}$source_path${gl_bai}"
    echo -e "${gl_lan}[信息]${gl_bai} 目标目录列表："
    for target in "${targets[@]}"; do
        echo -e "${gl_lv}  ${target}${gl_bai}"
    done

    {
      echo "[源目录] $source_path"
      echo "[目标目录列表]"
      printf '  %s\n' "${targets[@]}"
    } >> "$LOG_FILE"
fi
echo -e "${gl_bufan}----------------------------------------${gl_bai}"
log_ok "完整日志已保存至：${gl_huang}$LOG_FILE${gl_bai}"
echo -e "${gl_bufan}----------------------------------------${gl_bai}"
{ echo "========== lx_sync_many_file_dir.sh 结束：$end_time =========="; echo ""; } >> "$LOG_FILE"
