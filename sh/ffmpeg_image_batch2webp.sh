#!/bin/bash
set -euo pipefail

# 颜色定义
gl_hui='\033[38;5;59m'
gl_hong='\033[38;5;9m'
gl_lv='\033[38;5;10m'
gl_huang='\033[38;5;11m'
gl_lan='\033[38;5;32m'
gl_bai='\033[38;5;15m'
gl_zi='\033[38;5;13m'
gl_bufan='\033[38;5;14m'

# 日志函数
log_info()  { echo -e "${gl_lan}[信息]${gl_bai} $*"; }
log_ok()    { echo -e "${gl_lv}[成功]${gl_bai} $*"; }
log_warn()  { echo -e "${gl_huang}[警告]${gl_bai} $*"; }
log_error() { echo -e "${gl_hong}[错误]${gl_bai} $*" >&2; }

# 确认函数
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

# 安装 ffmpeg
install_ffmpeg() {
    local pkg_manager=""
    local install_cmd=""
    local update_cmd=""

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

    local sudo_cmd=""
    if [[ $EUID -ne 0 ]]; then
        if command -v sudo &>/dev/null; then
            sudo_cmd="sudo"
        else
            log_error "需要 root 权限但未找到 sudo，请以 root 用户运行或手动安装"
            return 1
        fi
    fi

    if [[ -n "$update_cmd" ]]; then
        log_info "更新软件包索引 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        if ! $sudo_cmd $update_cmd; then
            log_warn "更新索引失败，继续尝试安装 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        fi
    fi

    if ! $sudo_cmd $install_cmd; then
        log_error "安装 ffmpeg 失败，请检查网络或手动安装"
        return 1
    fi

    log_ok "ffmpeg 安装完成"
    return 0
}

# 批量转换函数
convert_batch() {
    local quality=${1:-80}
    local parallel=${2:-4}  # 并行数量
    
    local temp_dir=$(mktemp -d)
    trap 'rm -rf "$temp_dir"' RETURN
    
    local file_list="$temp_dir/files.txt"
    local success_list="$temp_dir/success.txt"
    local skip_list="$temp_dir/skip.txt"
    local fail_list="$temp_dir/fail.txt"
    
    touch "$success_list" "$skip_list" "$fail_list"
    
    # 收集所有图片文件
    find . -type f \( \
        -iname "*.jpg" -o \
        -iname "*.jpeg" -o \
        -iname "*.png" -o \
        -iname "*.gif" -o \
        -iname "*.bmp" -o \
        -iname "*.tiff" -o \
        -iname "*.tif" \) -print0 > "$file_list"
    
    local total=$(grep -zc '.' "$file_list" 2>/dev/null || echo 0)
    
    if [[ $total -eq 0 ]]; then
        log_warn "没有找到匹配的图片文件"
        return 0
    fi
    
    echo -e "\n${gl_zi}>>> 扫描完成，总计待处理文件：${total}${gl_bai}"
    
    # 显示文件列表（最多显示10个）
    echo -e "\n${gl_hui}文件列表（显示前10个）：${gl_bai}"
    head -n 10 "$file_list" | while IFS= read -r -d '' file; do
        echo -e "  ${gl_hui}•${gl_bai} $file"
    done
    if [[ $total -gt 10 ]]; then
        echo -e "  ${gl_hui}... 还有 $((total - 10)) 个文件${gl_bai}"
    fi
    
    # 确认
    if [[ $DRY_RUN -eq 1 ]]; then
        if ! confirm "是否开始批量转换 ${total} 个文件（质量 q=${quality}）？" 30; then
            log_info "用户取消，退出"
            return 1
        fi
    fi
    
    echo -e "\n${gl_zi}>>> 开始批量转换（并行数：${parallel}）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    local processed=0
    
    # 使用 xargs 进行并行处理
    convert_one() {
        local src="$1"
        local quality="$2"
        local dst="${src%.*}.webp"
        local tmpfile="${dst}.tmp.webp"
        
        if [[ ! -f "$src" ]]; then
            echo "FAIL|$src|文件不存在" >> "$fail_list"
            return 1
        fi
        
        # 转换
        ffmpeg -y -i "$src" -q:v "$quality" -compression_level 6 "$tmpfile" \
            -hide_banner -loglevel error 2>/dev/null || true
        
        if [[ -s "$tmpfile" ]]; then
            local orig_size=$(stat -c%s "$src" 2>/dev/null || echo 0)
            local new_size=$(stat -c%s "$tmpfile" 2>/dev/null || echo 0)
            
            if (( new_size < orig_size )); then
                mv "$tmpfile" "$dst"
                rm -f "$src"
                local orig_kb=$(awk -v s="$orig_size" 'BEGIN{printf "%.1f", s/1024}')
                local new_kb=$(awk -v s="$new_size" 'BEGIN{printf "%.1f", s/1024}')
                echo "SUCCESS|$src|$dst|${orig_kb}KB→${new_kb}KB" >> "$success_list"
                return 0
            else
                rm -f "$tmpfile"
                local orig_kb=$(awk -v s="$orig_size" 'BEGIN{printf "%.1f", s/1024}')
                local new_kb=$(awk -v s="$new_size" 'BEGIN{printf "%.1f", s/1024}')
                echo "SKIP|$src|${orig_kb}KB→${new_kb}KB (未缩小)" >> "$skip_list"
                return 0
            fi
        else
            rm -f "$tmpfile"
            echo "FAIL|$src|转换失败" >> "$fail_list"
            return 1
        fi
    }
    
    export -f convert_one
    export success_list skip_list fail_list
    
    # 使用 xargs 并行处理
    cat "$file_list" | xargs -0 -P "$parallel" -I {} bash -c 'convert_one "{}" "'"$quality"'"' || true
    
    # 统计结果
    local success_count=$(wc -l < "$success_list" 2>/dev/null || echo 0)
    local skip_count=$(wc -l < "$skip_list" 2>/dev/null || echo 0)
    local fail_count=$(wc -l < "$fail_list" 2>/dev/null || echo 0)
    
    # 显示详细结果
    echo -e "\n${gl_bufan}═══════════════════════════════════════${gl_bai}"
    
    if [[ $success_count -gt 0 ]]; then
        echo -e "${gl_lv}✅ 成功转换（${success_count} 个）：${gl_bai}"
        head -n 5 "$success_list" | while IFS='|' read -r _ src dst size; do
            echo -e "  ${gl_lv}•${gl_bai} $src → $dst ${gl_hui}($size)${gl_bai}"
        done
        if [[ $success_count -gt 5 ]]; then
            echo -e "  ${gl_hui}... 还有 $((success_count - 5)) 个${gl_bai}"
        fi
    fi
    
    if [[ $skip_count -gt 0 ]]; then
        echo -e "\n${gl_huang}⏭️ 跳过（${skip_count} 个，未缩小）：${gl_bai}"
        head -n 3 "$skip_list" | while IFS='|' read -r _ src size; do
            echo -e "  ${gl_huang}•${gl_bai} $src ${gl_hui}($size)${gl_bai}"
        done
        if [[ $skip_count -gt 3 ]]; then
            echo -e "  ${gl_hui}... 还有 $((skip_count - 3)) 个${gl_bai}"
        fi
    fi
    
    if [[ $fail_count -gt 0 ]]; then
        echo -e "\n${gl_hong}❌ 失败（${fail_count} 个）：${gl_bai}"
        head -n 3 "$fail_list" | while IFS='|' read -r _ src reason; do
            echo -e "  ${gl_hong}•${gl_bai} $src ${gl_hui}($reason)${gl_bai}"
        done
        if [[ $fail_count -gt 3 ]]; then
            echo -e "  ${gl_hui}... 还有 $((fail_count - 3)) 个${gl_bai}"
        fi
    fi
    
    echo -e "\n${gl_bufan}═══════════════════════════════════════${gl_bai}"
    echo -e "${gl_lv}🏁 全部任务结束${gl_bai}"
    echo -e "  ${gl_lv}✅ 成功转换：${gl_bai}${success_count}"
    echo -e "  ${gl_huang}⏭️ 跳过（未缩小）：${gl_bai}${skip_count}"
    echo -e "  ${gl_hong}❌ 失败：${gl_bai}${fail_count}"
    echo -e "  ${gl_hui}总计处理：${gl_bai}$((success_count + skip_count + fail_count)) / ${total}"
    echo -e "${gl_bufan}═══════════════════════════════════════${gl_bai}"
    
    return 0
}

# 主程序开始
DRY_RUN=1
PARALLEL=4  # 默认并行数
QUALITY=80

# 解析参数
while [[ $# -gt 0 ]]; do
    case "$1" in
        --yes|-y)
            DRY_RUN=0
            shift
            ;;
        --parallel|-p)
            PARALLEL="$2"
            shift 2
            ;;
        --quality|-q)
            QUALITY="$2"
            shift 2
            ;;
        --help|-h)
            echo "用法: $0 [选项]"
            echo "选项:"
            echo "  --yes, -y        跳过确认直接执行"
            echo "  --parallel N, -p N  并行处理数量（默认4）"
            echo "  --quality N, -q N   转换质量（默认80）"
            echo "  --help, -h       显示帮助信息"
            exit 0
            ;;
        *)
            echo "未知参数: $1"
            echo "使用 --help 查看帮助"
            exit 1
            ;;
    esac
done

# 检查 ffmpeg
if ! command -v ffmpeg &>/dev/null; then
    log_warn "未找到 ffmpeg，尝试自动安装 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    
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
        if ! install_ffmpeg; then
            log_error "安装失败，退出"
            exit 1
        fi
    fi
    
    if ! command -v ffmpeg &>/dev/null; then
        log_error "ffmpeg 仍未安装成功，请手动处理"
        exit 1
    fi
    log_ok "ffmpeg 已就绪"
fi

# 执行批量转换
clear
echo -e "${gl_zi}>>> 图片批量转换为 WebP 格式${gl_bai}"
echo -e "${gl_bufan}质量：${QUALITY}，并行数：${PARALLEL}${gl_bai}"

convert_batch "$QUALITY" "$PARALLEL"
exit_code=$?

exit $exit_code