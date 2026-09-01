#!/bin/bash
set -euo pipefail


gl_hui='\033[38;5;59m'
gl_hong='\033[38;5;9m'
gl_lv='\033[38;5;10m'
gl_huang='\033[38;5;11m'
gl_lan='\033[38;5;32m'
gl_bai='\033[38;5;15m'
gl_zi='\033[38;5;13m'
gl_bufan='\033[38;5;14m'


log_info()  { echo -e "${gl_lan}[信息]${gl_bai} $*"; }
log_ok()    { echo -e "${gl_lv}[成功]${gl_bai} $*"; }
log_warn()  { echo -e "${gl_huang}[警告]${gl_bai} $*"; }
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


confirm() {
    local prompt="${1:-是否继续？}"
    local timeout=${2:-10}
    echo -ne "${gl_huang}${prompt} (y/N) ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    read -r -t "$timeout" -n 1 ans || ans='n'
    echo ""
    case "$ans" in
        y|Y) return 0 ;;
        *)   return 1 ;;
    esac
}


install_ffmpeg() {
    local pkg_manager=""
    local install_cmd=""
    local update_cmd=""

    # 检测包管理器
    if command -v apt-get &>/dev/null; then
        pkg_manager="apt-get"
        install_cmd="apt-get install -y ffmpeg"
        update_cmd="apt-get update"
    elif command -v apt &>/dev/null; then
        pkg_manager="apt"
        install_cmd="apt install -y ffmpeg"
        update_cmd="apt update"
    elif command -v dnf &>/dev/null; then
        pkg_manager="dnf"
        install_cmd="dnf install -y ffmpeg"
    elif command -v yum &>/dev/null; then
        pkg_manager="yum"
        install_cmd="yum install -y ffmpeg"
    elif command -v zypper &>/dev/null; then
        pkg_manager="zypper"
        install_cmd="zypper install -y ffmpeg"
    elif command -v pacman &>/dev/null; then
        pkg_manager="pacman"
        install_cmd="pacman -S --noconfirm ffmpeg"
    elif command -v apk &>/dev/null; then
        pkg_manager="apk"
        install_cmd="apk add ffmpeg"
    else
        log_error "无法识别包管理器，请手动安装 ffmpeg"
        return 1
    fi

    log_info "检测到包管理器：$pkg_manager，正在尝试安装 ffmpeg ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

    # 决定是否使用 sudo
    local sudo_cmd=""
    if [[ $EUID -ne 0 ]]; then
        if command -v sudo &>/dev/null; then
            sudo_cmd="sudo"
        else
            log_error "需要 root 权限但未找到 sudo，请以 root 用户运行或手动安装"
            return 1
        fi
    fi

    # 对于 apt 系，先更新索引（避免缓存过期）
    if [[ -n "$update_cmd" ]]; then
        log_info "更新软件包索引 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        if ! $sudo_cmd $update_cmd; then
            log_warn "更新索引失败，继续尝试安装 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        fi
    fi

    # 执行安装
    if ! $sudo_cmd $install_cmd; then
        log_error "安装 ffmpeg 失败，请检查网络或手动安装"
        return 1
    fi

    log_ok "ffmpeg 安装完成"
    return 0
}


DRY_RUN=1
if [[ "${1:-}" == "--yes" ]]; then
    DRY_RUN=0
fi


if ! command -v ffmpeg &>/dev/null; then
    log_warn "未找到 ffmpeg，尝试自动安装 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

    # 根据是否 --yes 决定是否询问
    if [[ $DRY_RUN -eq 1 ]]; then
        if confirm "是否安装 ffmpeg（需要 sudo 权限）？" 30; then
            if ! install_ffmpeg; then
                log_error "安装失败，退出"
                exit 1
            fi
        else
            log_error "用户取消安装，无法继续"
            exit 1
        fi
    else
        # --yes 模式，静默安装
        if ! install_ffmpeg; then
            log_error "安装失败，退出"
            exit 1
        fi
    fi

    # 再次检查是否安装成功
    if ! command -v ffmpeg &>/dev/null; then
        log_error "ffmpeg 仍未安装成功，请手动处理"
        exit 1
    fi
    log_ok "ffmpeg 已就绪"
fi


tmp_scan=$(mktemp)
trap 'rm -f "$tmp_scan"' EXIT


clear
echo -e "${gl_zi}>>> 正在扫描当前目录下的图片文件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
find . -type f \( \
    -iname "*.jpg" -o \
    -iname "*.jpeg" -o \
    -iname "*.png" -o \
    -iname "*.gif" -o \
    -iname "*.bmp" -o \
    -iname "*.tiff" -o \
    -iname "*.tif" \) -print0 | while IFS= read -r -d '' src; do
    dst="${src%.*}.webp"
    printf '%s|%s\n' "$src" "$dst" >> "$tmp_scan"
    echo -e "${gl_hui}待转换：${gl_bai}$src  →  $dst"
done


total=$(wc -l < "$tmp_scan" 2>/dev/null || echo 0)
echo -e "\n${gl_lv}扫描完成，总计待处理文件：${total} ${gl_bai}"


if [[ $total -eq 0 ]]; then
    log_warn "没有找到匹配的图片文件，退出"
    exit 0
fi


if [[ $DRY_RUN -eq 1 ]]; then
    echo -e "\n${gl_bufan}>>> 当前为预览模式，未执行任何转换 <<<${gl_bai}"
    if confirm "是否开始转换（质量 q=${QUALITY:-80}）？" 30; then
        DRY_RUN=0
        log_ok "用户确认，开始执行转换"
    else
        log_info "用户取消，退出"
        exit 0
    fi
else
    log_info "已指定 --yes，直接执行转换（质量 q=${QUALITY:-80}）"
fi


QUALITY=${QUALITY:-80}
converted=0
skipped=0
failed=0


echo -e ""
echo -e "${gl_zi}>>> 开始转换 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"


exec 3< "$tmp_scan"
while IFS='|' read -r src dst <&3; do
    [[ -z "$src" ]] && continue
    tmpfile="${dst}.tmp.webp"


    if [[ ! -f "$src" ]]; then
        log_error "文件不存在：$src"
        ((failed++))
        continue
    fi


    ffmpeg -y -i "$src" -q:v "$QUALITY" -compression_level 6 "$tmpfile" \
        -hide_banner -loglevel error 2>/dev/null || true


    if [[ -s "$tmpfile" ]]; then
        orig_size=$(stat -c%s "$src" 2>/dev/null || echo 0)
        new_size=$(stat -c%s "$tmpfile" 2>/dev/null || echo 0)


        orig_kb=$(awk -v s="$orig_size" 'BEGIN{printf "%.1f", s/1024}')
        new_kb=$(awk -v s="$new_size" 'BEGIN{printf "%.1f", s/1024}')


        if (( new_size < orig_size )); then
            mv "$tmpfile" "$dst"
            rm -f "$src"
            echo -e "${gl_lv}✅ 转换完成${gl_bai} $src → $dst | ${gl_hui}${orig_kb}KB → ${new_kb}KB${gl_bai}"
            ((converted++))
        else
            rm -f "$tmpfile"
            echo -e "${gl_huang}⏭️ 跳过${gl_bai} $src | webp(${new_kb}KB) ≥ 原图(${orig_kb}KB)"
            ((skipped++))
        fi
    else
        rm -f "$tmpfile"
        log_error "转换失败：$src，原图保留"
        ((failed++))
    fi
done
exec 3<&-


echo -e "\n${gl_bufan}═══════════════════════════════════════${gl_bai}"
echo -e "${gl_lv}🏁 全部任务结束${gl_bai}"
echo -e "  ${gl_lv}✅ 成功转换：${gl_bai}${converted}"
echo -e "  ${gl_huang}⏭️ 跳过（未缩小）：${gl_bai}${skipped}"
echo -e "  ${gl_hong}❌ 失败：${gl_bai}${failed}"
echo -e "  ${gl_hui}总计处理：${gl_bai}$((converted + skipped + failed)) / ${total}"
echo -e "${gl_bufan}═══════════════════════════════════════${gl_bai}"


exit 0