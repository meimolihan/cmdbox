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

log_info() { echo -e "${gl_lan}[信息]${gl_bai} $*"; }
log_ok() { echo -e "${gl_lv}[成功]${gl_bai} $*"; }
log_warn() { echo -e "${gl_huang}[警告]${gl_bai} $*"; }
log_error() { echo -e "${gl_hong}[错误]${gl_bai} $*" >&2; }

sleep_fractional() {
    local seconds=$1
    if sleep "$seconds" 2>/dev/null; then return 0; fi
    if command -v perl >/dev/null 2>&1; then perl -e "select(undef, undef, undef, $seconds)"; return 0; fi
    if command -v python3 >/dev/null 2>&1; then python3 -c "import time; time.sleep($seconds)"; return 0; fi
    if command -v python >/dev/null 2>&1; then python -c "import time; time.sleep($seconds)"; return 0; fi
    local int_seconds=$(echo "$seconds" | awk '{print int($1+0.999)}')
    sleep "$int_seconds"
}

collect_tree() {
    local pids=("$@")
    local all=("${pids[@]}")
    local children
    for pid in "${pids[@]}"; do
        if [[ -r "/proc/$pid/task/$pid/children" ]]; then
            read -ra children < "/proc/$pid/task/$pid/children"
            if [[ ${#children[@]} -gt 0 ]]; then
                all+=("${children[@]}")
                all+=($(collect_tree "${children[@]}"))
            fi
        fi
    done
    echo "${all[@]}"
}

kill_ffmpeg_tree() {
    log_info "开始查找所有 ffmpeg 进程"
    FFMPEG_PIDS=($(pidof ffmpeg || true))
    if [[ ${#FFMPEG_PIDS[@]} -eq 0 ]]; then
        log_ok "未检测到任何 ffmpeg 进程，无需处理"
        return 0
    fi
    log_info "检测到 ffmpeg PID列表: ${FFMPEG_PIDS[*]}"

    TREE_PIDS=()
    for fp in "${FFMPEG_PIDS[@]}"; do
        TREE_PIDS+=("$fp")
        log_info "正在获取 ffmpeg[$fp] 的父进程信息"
        pp=$(ps -o ppid= -p "$fp" | tr -d ' ')
        if [[ "$pp" != "1" && -n "$pp" ]]; then
            TREE_PIDS+=("$pp")
            log_info "ffmpeg[$fp] 父进程 PID: $pp，递归收集完整进程树"
            TREE_PIDS+=($(collect_tree "$pp"))
        fi
    done

    UNIQ_PIDS=($(printf "%s\n" "${TREE_PIDS[@]}" | sort -nu))
    log_info "汇总待清理进程PID列表: ${UNIQ_PIDS[*]}"

    log_info "第一步：发送 SIGTERM 优雅终止进程"
    kill "${UNIQ_PIDS[@]}" 2>/dev/null
    log_info "等待2秒，等待进程正常退出"
    sleep_fractional 2

    REMAIN=()
    for p in "${UNIQ_PIDS[@]}"; do
        if ps -p "$p" >/dev/null 2>&1; then
            REMAIN+=("$p")
        fi
    done

    if [[ ${#REMAIN[@]} -gt 0 ]]; then
        log_warn "存在未能正常退出的残留进程: ${REMAIN[*]}，执行强制 kill -9"
        kill -9 "${REMAIN[@]}" 2>/dev/null
        log_ok "残留进程强制终止完成"
    else
        log_ok "所有进程已收到SIGTERM并正常退出，无残留"
    fi

    log_info "二次校验 ffmpeg 进程状态"
    CHECK_FFMPEG=($(pidof ffmpeg || true))
    if [[ ${#CHECK_FFMPEG[@]} -eq 0 ]]; then
        log_ok "✅ 校验通过：ffmpeg 进程已全部清除"
        return 0
    else
        log_error "❌ 校验失败，仍存在ffmpeg进程：${CHECK_FFMPEG[*]}"
        return 1
    fi
}

# 免交互直接执行入口
kill_ffmpeg_tree
exit $?