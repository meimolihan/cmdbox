#!/bin/bash

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
    export gl_cheng=$'\033[38;5;214m'
    export gl_tian=$'\033[38;5;117m'
    export gl_qing=$'\033[38;5;51m'
    export gl_ok=$'\033[38;5;46m'
    export gl_reset=$'\033[0m'
}

list_color_init

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
    local int_seconds
    int_seconds=$(echo "$seconds" | awk '{print int($1+0.999)}')
    sleep "$int_seconds"
}

# 退出动画函数
exit_animation() {
    sleep_fractional 0.8
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local dots=(
        "${gl_hong}."
        "${gl_huang}."
        "${gl_lv}."
        "${gl_bufan}."
        "${gl_zi}."
        "${gl_cheng}."
    )
    local dot_buffer=""
    local frame_len=${#frames[@]}
    local dot_idx=0
    local total_dots=6

    for ((i=0; i<20; i++)); do
        if (( i > 0 && i % 3 == 0 && dot_idx < total_dots )); then
            dot_buffer+=${dots[$dot_idx]}
            ((dot_idx++))
        fi
        echo -ne "\r\033[K${gl_bufan}${frames[i % frame_len]}${gl_bai} 正在退出 ${dot_buffer}"
        sleep_fractional 0.06
    done
    echo -e "\r\033[K${gl_lv}✓${gl_bai} 成功退出\n"
    clear
}

# 按任意键继续...
break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    read -r -n 1 -s -r -p ""
    echo ""
    clear
}

# 无效的输入,请重新输入!
handle_invalid_input() {
    echo -ne "\r${gl_hong}无效的输入，请重新输入 ${gl_zi} 2 ${gl_hong}秒后返回 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.3
    echo -ne "\r${gl_huang}无效的输入，请重新输入 ${gl_zi} 1 ${gl_huang}秒后返回 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.3
    echo -e "\r${gl_lv}无效的输入，请重新输入 ${gl_zi} 0 ${gl_lv}秒后返回 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    return 2 # 2 表示“输入非法”
}

# 无效的输入,请输入(y或N)。
handle_y_n() {
    echo -ne "\r${gl_hong}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai}) ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.3
    echo -ne "\r${gl_huang}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai}) ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.3
    echo -ne "\r${gl_lv}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai}) ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    return 2 # 2 表示“输入非法”
}

# 退出脚本
exit_script() {
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local dots=(
        "${gl_hong}."
        "${gl_huang}."
        "${gl_lv}."
        "${gl_bufan}."
        "${gl_zi}."
        "${gl_cheng}."
    )
    local dot_buffer=""
    local frame_len=${#frames[@]}
    local dot_idx=0
    local total_dots=6

    for ((i=0; i<20; i++)); do
        if (( i > 0 && i % 3 == 0 && dot_idx < total_dots )); then
            dot_buffer+=${dots[$dot_idx]}
            ((dot_idx++))
        fi
        echo -ne "\r\033[K${gl_bufan}${frames[i % frame_len]}${gl_bai} 正在退出 ${dot_buffer}"
        sleep_fractional 0.06
    done
    echo -e "\r\033[K${gl_lv}✓${gl_bai} 成功退出\n"
    clear
    exit 0
}

# 返回上一级
cancel_empty() {
    local menu_name="${1:-上一级选单}"
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local dots=(
        "${gl_hong}."
        "${gl_huang}."
        "${gl_lv}."
        "${gl_bufan}."
        "${gl_zi}."
        "${gl_cheng}."
    )
    local dot_buffer=""
    local frame_len=${#frames[@]}
    local dot_idx=0
    local total_dots=6

    for ((i=0; i<20; i++)); do
        if (( i > 0 && i % 3 == 0 && dot_idx < total_dots )); then
            dot_buffer+=${dots[$dot_idx]}
            ((dot_idx++))
        fi
        echo -ne "\r\033[K${gl_bufan}${frames[i % frame_len]}${gl_bai}空输入，返回 ${gl_huang}${menu_name} ${dot_buffer}"
        sleep_fractional 0.06
    done
    echo -e "\r\033[K${gl_lv}✓${gl_bai}成功返回${gl_huang}${menu_name}${gl_bai} \n"
    clear
}


cancel_return() {
    local menu_name="${1:-上一级选单}"
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local dots=(
        "${gl_hong}."
        "${gl_huang}."
        "${gl_lv}."
        "${gl_bufan}."
        "${gl_zi}."
        "${gl_cheng}."
    )
    local dot_buffer=""
    local frame_len=${#frames[@]}
    local dot_idx=0
    local total_dots=6

    for ((i=0; i<20; i++)); do
        if (( i > 0 && i % 3 == 0 && dot_idx < total_dots )); then
            dot_buffer+=${dots[$dot_idx]}
            ((dot_idx++))
        fi
        echo -ne "\r\033[K${gl_bufan}${frames[i % frame_len]}${gl_bai}即将返回 ${gl_huang}${menu_name} ${dot_buffer}"
        sleep_fractional 0.06
    done
    echo -e "\r\033[K${gl_lv}✓${gl_bai} 成功返回${gl_huang}${menu_name}${gl_bai} \n"
    clear
}

############################## 列表美化 ##############################

# 用于替代 column 命令的函数
column_if_available() {
    if command -v column &> /dev/null; then
        column -t -s $'\t'
    else
        cat
    fi
}

# Linux计划任务
# 显示cron任务列表（不含标题和边框，用于菜单集成）
show_crontab_list() {
    if ! command -v crontab &>/dev/null; then
        echo -e "${gl_hong}错误：crontab命令不存在${gl_bai}"
        exit_animation
        return 1
    fi

    local crontab_content
    crontab_content=$(crontab -l 2>/dev/null)

    if [[ -n "$crontab_content" ]]; then
        local valid_tasks
        valid_tasks=$(echo "$crontab_content" | grep -v '^#' | grep -v '^[[:space:]]*$')

        if [[ -n "$valid_tasks" ]]; then

            local line_number=1
            while IFS= read -r line; do
                if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]]; then
                    echo -e "${gl_huang}$(printf "%d" $line_number). ${gl_lv}$line${gl_bai}"
                    ((line_number++))
                fi
            done <<<"$crontab_content"

            local total_valid_tasks
            total_valid_tasks=$(echo "$valid_tasks" | wc -l)
            return 0
        else
            echo -e "${gl_huang}当前用户没有有效的${gl_bufan}crontab${gl_huang}任务${gl_bai}（${gl_lv}只有注释和空行${gl_bai}）"
            return 0
        fi
    else
        echo -e "${gl_huang}当前用户没有${gl_bufan}crontab${gl_huang}任务${gl_bai}"
        return 0
    fi
}


# 编辑crontab（使用默认编辑器）
edit_crontab() {
    clear
    echo -e "${gl_zi}>>> 编辑cron文件${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if ! command -v crontab &>/dev/null; then
        log_error "crontab命令不存在，请检查系统"
        exit_animation
        return 1
    fi

    echo -e "${gl_bai}正在打开${gl_lv}crontab${gl_bai}编辑器 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    log_warn "请谨慎编辑，保存后更改将立即生效"

    if crontab -e; then
        log_ok "crontab编辑完成"
    else
        log_error "crontab编辑失败"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

# 添加新cron任务
add_crontab() {
    clear
    echo -e "${gl_zi}>>> 添加新的cron任务${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if ! command -v crontab &>/dev/null; then
        log_error "crontab命令不存在，请检查系统"
        exit_animation
        return 1
    fi

    show_crontab_list

    local temp_file
    temp_file=$(mktemp)

    crontab -l 2>/dev/null >"$temp_file"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e ""
    echo -e "${gl_bufan}请按以下格式输入cron表达式和命令：${gl_bai}"
    echo -e "${gl_bufan}*   *   *   *   *   ${gl_huang}要执行的命令${gl_bai}/${gl_hong}脚本路径${gl_bai}\n\
${gl_zi}|   ${gl_lan}|   ${gl_huang}|   ${gl_lv}|   ${gl_hong}|${gl_bai}\n\
${gl_zi}|   ${gl_lan}|   ${gl_huang}|   ${gl_lv}|   ${gl_hong}└── ${gl_hong}星期 (0-7, 0和7都代表周日)${gl_bai}\n\
${gl_zi}|   ${gl_lan}|   ${gl_huang}|   ${gl_lv}└────── ${gl_lv}月份 (1-12)${gl_bai}\n\
${gl_zi}|  ${gl_lan} |   ${gl_huang}└────────── ${gl_huang}日期 (1-31)${gl_bai}\n\
${gl_zi}|   ${gl_lan}└────────────── ${gl_lan}小时 (0-23)${gl_bai}\n\
${gl_zi}└────────────────── ${gl_zi}分钟 (0-59)${gl_bai}"
    echo -e ""
    echo -e "${gl_bai}任务示例: ${gl_lv}0 1 * * * /path/to/script.sh${gl_bai}"
    echo -e "${gl_bai}示例说明: 表达式 ${gl_lv}0 1 * * *${gl_bai} 精准匹配 “每天凌晨 ${gl_huang}1 ${gl_bai}点整” 执行任务"

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    read -r -e -p "$(echo -e "${gl_bai}请输入cron任务 (${gl_huang}0${gl_bai}返回): ")" new_cron

    if [[ "$new_cron" == "0" ]]; then
        rm -f "$temp_file"
        cancel_return
        return
    fi

    if [[ -n "$new_cron" ]]; then
        echo "$new_cron" >>"$temp_file"

        if crontab "$temp_file" 2>/dev/null; then
            log_ok "任务添加成功"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_lv}已添加的任务：${gl_bai}"
            echo -e "${gl_hui}$new_cron${gl_bai}"
        else
            log_error "任务添加失败，请检查cron表达式格式"
        fi
    else
        log_warn "输入为空，未添加任何任务"
    fi

    rm -f "$temp_file"
    break_end
}

# 删除cron任务（基于有效任务行号）
delete_crontab() {
    clear
    echo -e "${gl_zi}>>> 删除cron任务${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if ! command -v crontab &>/dev/null; then
        log_error "crontab命令不存在，请检查系统"
        exit_animation
        return 1
    fi

    local crontab_content
    crontab_content=$(crontab -l 2>/dev/null)

    local valid_tasks
    valid_tasks=$(echo "$crontab_content" | grep -v '^#' | grep -v '^[[:space:]]*$')

    if [[ -z "$valid_tasks" ]]; then
        echo -e "${gl_huang}当前用户没有有效的${gl_bufan}crontab${gl_huang}任务可删除${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation
        return
    fi

    echo -e "${gl_lv}当前crontab有效任务列表：${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local line_number=1
    local task_lines=()

    while IFS= read -r line; do
        if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]]; then
            echo -e "${gl_bufan}$(printf "%2d" $line_number). ${gl_bai}$line"
            task_lines+=("$line")
            ((line_number++))
        fi
    done <<<"$crontab_content"

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    read -r -e -p "$(echo -e "${gl_bai}请输入要删除的任务行号 (${gl_huang}0${gl_bai}返回): ")" line_num

    [[ "$line_num" == "0" ]] && return 1

    if [[ ! "$line_num" =~ ^[0-9]+$ ]]; then
        log_error "请输入有效的数字"
        exit_animation
        return
    fi

    local total_tasks=${#task_lines[@]}

    if [[ "$line_num" -gt 0 && "$line_num" -le "$total_tasks" ]]; then
        local temp_file
        temp_file=$(mktemp)

        echo "$crontab_content" >"$temp_file"

        local target_task="${task_lines[$((line_num - 1))]}"
        local task_deleted=0

        while IFS= read -r line; do
            if [[ "$line" == "$target_task" && "$task_deleted" -eq 0 ]]; then
                task_deleted=1
                continue
            fi
            echo "$line" >>"${temp_file}.tmp"
        done <"$temp_file"

        mv "${temp_file}.tmp" "$temp_file"

        if crontab "$temp_file" 2>/dev/null; then
            log_ok "第 ${line_num} 行任务已删除"
            log_info "删除的任务: ${target_task}"
        else
            log_error "删除任务失败"
        fi

        rm -f "$temp_file" "${temp_file}.tmp"
    else
        log_error "行号超出范围 (1-${total_tasks})"
    fi

    break_end
}

# 清空所有cron任务（修复核心错误+优化体验）
clear_crontab() {
    clear
    echo -e "${gl_zi}>>> 清空所有crontab任务（含注释/空行）${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if ! command -v crontab &>/dev/null; then
        log_error "crontab命令不存在，请安装cron/crontabs组件"
        exit_animation
        return 1
    fi

    show_crontab_list

    echo -e "${gl_hong}⚠️  警告：这将彻底删除crontab文件（包括所有注释、空行、任务）！${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}确认要彻底清空吗？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
    confirm=${confirm:-N} # 回车默认取消

    case "$confirm" in
    [yY] | [yY][eE][sS])
        local current_user
        if command -v whoami &>/dev/null; then
            current_user=$(whoami)
        elif command -v id &>/dev/null; then
            current_user=$(id -un)
        else
            current_user="root"
        fi

        echo -e "${gl_lan}正在清空crontab（用户: $current_user） ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

        echo -e "${gl_lan}正在执行方法1: 强制删除crontab ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

        crontab -r 2>/dev/null || true

        local temp_crontab
        temp_crontab=$(mktemp /tmp/crontab_empty_XXXXXX)

        printf '\n' >"$temp_crontab"

        if crontab "$temp_crontab" 2>/dev/null; then
            log_ok "方法1成功: 已设置空白crontab"
        else
            log_warn "方法1设置失败"
        fi

        rm -f "$temp_crontab"

        crontab -r 2>/dev/null || true

        echo -e "${gl_lan}正在执行方法2: 直接删除crontab文件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

        local crontab_paths=(
            "/var/spool/cron/crontabs/$current_user"
            "/var/spool/cron/$current_user"
        )

        local file_deleted=0
        for crontab_path in "${crontab_paths[@]}"; do
            if [ -f "$crontab_path" ]; then
                echo -e "${gl_lan}找到crontab文件: $crontab_path${gl_bai}"

                echo -e "${gl_huang}文件内容:${gl_bai}"
                head -20 "$crontab_path" 2>/dev/null || echo "无法读取文件"
                echo ""

                if rm -f "$crontab_path" 2>/dev/null; then
                    log_ok "成功删除: $crontab_path"
                    file_deleted=1
                elif sudo rm -f "$crontab_path" 2>/dev/null; then
                    log_ok "使用sudo成功删除: $crontab_path"
                    file_deleted=1
                else
                    log_warn "无法删除: $crontab_path"
                fi
            fi
        done

        echo -e "${gl_lan}正在执行方法3: 创建空白crontab ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

        local temp_script
        temp_script=$(mktemp /tmp/cron_clear_XXXXXX.sh)

        cat >"$temp_script" <<'EOF'
#!/bin/bash
# 尝试多种方法清空crontab

USERNAME="$1"

# 方法1: 使用/dev/null作为输入
crontab /dev/null 2>/dev/null || true

# 方法2: 创建一个只有一个换行符的文件
TEMP_FILE=$(mktemp /tmp/cron_empty_XXXXXX)
printf '\n' > "$TEMP_FILE"
crontab "$TEMP_FILE" 2>/dev/null || true
rm -f "$TEMP_FILE"

# 方法3: 使用echo -n设置空内容
echo -n | crontab - 2>/dev/null || true

# 方法4: 使用python清空
python3 -c "
import sys
import os

# 尝试删除当前用户的crontab
try:
    import subprocess
    subprocess.run(['crontab', '-r'], check=False)
except:
    pass

# 创建一个完全空的crontab
temp_file = '/tmp/empty_cron'
with open(temp_file, 'w') as f:
    f.write('')
try:
    subprocess.run(['crontab', temp_file], check=False)
except:
    pass
os.unlink(temp_file)
" 2>/dev/null || true
EOF

        chmod +x "$temp_script"

        if "$temp_script" "$current_user" 2>/dev/null; then
            log_ok "方法3: 脚本执行完成"
        else
            log_warn "方法3: 脚本执行可能失败"
        fi

        rm -f "$temp_script"

        if [ "$(id -u)" -eq 0 ]; then
            echo -e "${gl_lan}正在执行方法4: 系统级清理 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

            if [ -f "/etc/crontab" ]; then
                cp -f "/etc/crontab" "/etc/crontab.backup.$(date +%s)" 2>/dev/null

                printf '\n' >/etc/crontab
                log_ok "已清空/etc/crontab"
            fi

            if [ -d "/etc/cron.d" ]; then
                for file in /etc/cron.d/*; do
                    if [ -f "$file" ] && [[ "$file" != *".placeholder" ]]; then
                        printf '\n' >"$file" 2>/dev/null || true
                    fi
                done
                log_ok "已清空/etc/cron.d/目录中的文件"
            fi
        fi

        echo -e "${gl_lan}正在执行方法5: 创建真正的空任务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

        if command -v python3 &>/dev/null; then
            python3 -c "
import os
import tempfile

# 创建一个完全空的文件
with tempfile.NamedTemporaryFile(mode='w', delete=False) as f:
    f.write('')
    temp_file = f.name

try:
    try:
        from crontab import CronTab
        cron = CronTab(user=True)
        cron.remove_all()
        cron.write()
        print('使用python-crontab模块清空成功')
    except ImportError:
        os.system('crontab -r 2>/dev/null')
        os.system(f'crontab {temp_file} 2>/dev/null')
        print('使用系统命令清空成功')
except Exception as e:
    print(f'清空失败: {e}')
finally:
    if os.path.exists(temp_file):
        os.unlink(temp_file)
" 2>/dev/null || log_warn "Python清理失败"
        else
            true | crontab - 2>/dev/null || :
        fi

        echo -e "${gl_lv}正在验证crontab是否已清空 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

        sleep_fractional 0.5

        if crontab -l &>/dev/null; then
            local content
            content=$(crontab -l 2>/dev/null || true)

            local clean_content
            clean_content=$(echo "$content" | sed '/^#/d' | sed '/^$/d')

            if [ -z "$clean_content" ]; then
                if [ -z "$content" ]; then
                    log_ok "✅ 验证通过: crontab已完全清空（无任何内容）"
                else
                    log_ok "✅ 验证通过: crontab已清空（仅剩注释，无有效任务）"
                    echo -e "${gl_huang}注意: 系统保留了默认注释模板${gl_bai}"
                    echo -e "${gl_huang}如需完全删除，请手动删除相关文件${gl_bai}"
                fi
            else
                log_warn "⚠️  验证失败: 仍有内容存在"
                echo -e "${gl_hong}剩余内容:${gl_bai}"
                echo "$content"

                echo -e "\n${gl_huang}建议手动删除以下文件:${gl_bai}"
                for path in "/var/spool/cron/crontabs/$current_user" "/var/spool/cron/$current_user"; do
                    if [ -f "$path" ]; then
                        echo "  rm -f $path"
                    fi
                done
            fi
        else
            log_ok "✅ 验证通过: crontab文件不存在或已清空"
        fi

        echo -e "\n${gl_zi}清理完成！${gl_bai}"
        echo -e "${gl_huang}如果仍有注释显示，可能是由于:${gl_bai}"
        echo -e "1. 系统默认模板被crontab命令自动生成"
        echo -e "2. crontab缓存未更新（可重启cron服务: systemctl restart cron）"
        echo -e "3. 可尝试直接删除文件: rm -f /var/spool/cron/crontabs/$current_user"
        ;;
    *)
        log_info "已取消清空crontab操作"
        ;;
    esac

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

# 查看crontab原始内容（包含注释）
view_raw_crontab() {
    clear
    echo -e "${gl_zi}>>> 查看crontab原始内容（包含注释）${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if ! command -v crontab &>/dev/null; then
        log_error "crontab命令不存在，请检查系统"
        exit_animation
        return 1
    fi

    local crontab_content
    crontab_content=$(crontab -l 2>/dev/null)

    if [[ -n "$crontab_content" ]]; then
        echo -e "${gl_lv}当前用户的crontab原始内容：${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "$crontab_content" | awk '{printf "%2d    %s\n", NR, $0}'
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        local total_lines
        total_lines=$(echo "$crontab_content" | wc -l)

        local valid_tasks
        valid_tasks=$(echo "$crontab_content" | grep -v '^#' | grep -v '^[[:space:]]*$' | wc -l)

        echo -e "${gl_bai}总行数: ${gl_huang}$total_lines${gl_bai}，有效任务数: ${gl_lv}$valid_tasks${gl_bai}"
    else
        echo -e "${gl_huang}当前用户没有${gl_bufan}crontab${gl_huang}任务${gl_bai}"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

# 显示crontab服务状态（精简版）
show_crontab_status() {
    if ! command -v crontab &>/dev/null; then
        echo -e "${gl_hong}✗ crontab命令不可用${gl_bai}"
        exit_animation
        return 1
    fi

    local cron_process_found=0
    local pid=""
    local cmd=""

    if ps aux | grep -v grep | grep -E "(cron|crond|CRON)" >/dev/null 2>&1; then
        cron_process_found=1
        pid=$(ps aux | grep -v grep | grep -E "(cron|crond|CRON)" | head -1 | awk '{print $2}')
        cmd=$(ps aux | grep -v grep | grep -E "(cron|crond|CRON)" | head -1 | awk '{for(i=11;i<=NF;i++) printf $i " "}')
        echo -e "${gl_bai}进程状态:${gl_bai} ${gl_lv}✓ cron守护进程正在运行 ${gl_bai}(PID: ${gl_huang}$pid, ${gl_bai}命令: ${gl_huang}$cmd${gl_bai})"
    else
        echo -e "${gl_bai}进程状态:${gl_bai} ${gl_hong}✗ cron守护进程未运行${gl_bai}"
    fi

    local service_status_found=0
    local service_status=""

    if command -v systemctl &>/dev/null; then
        local service_name=""
        for service in cron crond cronie; do
            if systemctl list-unit-files --type=service 2>/dev/null | grep -q "^${service}.service"; then
                service_name="$service"
                break
            fi
        done

        if [ -n "$service_name" ]; then
            service_status_found=1
            local status
            status=$(systemctl is-active "$service_name" 2>/dev/null || echo "unknown")
            service_status="$service_name.service: $status"
            if [ "$status" = "active" ]; then
                echo -e "${gl_bai}服务状态:${gl_bai} ${gl_lv}$service_status${gl_bai}"
            elif [ "$status" = "inactive" ]; then
                echo -e "${gl_bai}服务状态:${gl_bai} ${gl_hong}$service_status${gl_bai}"
            else
                echo -e "${gl_bai}服务状态:${gl_bai} ${gl_huang}$service_status${gl_bai}"
            fi
        else
            echo -e "${gl_bai}服务状态:${gl_bai} ${gl_huang}未找到cron服务${gl_bai}"
        fi

    elif command -v service &>/dev/null; then
        local service_name=""
        for service in cron crond; do
            if service --status-all 2>/dev/null | grep -q "\s${service}" ||
                ls /etc/init.d/ 2>/dev/null | grep -q "^${service}$"; then
                service_name="$service"
                break
            fi
        done

        if [ -n "$service_name" ]; then
            service_status_found=1
            local status
            if service "$service_name" status 2>/dev/null | grep -qi "running\|active"; then
                status="运行中"
                echo -e "${gl_bai}服务状态:${gl_bai} ${gl_lv}$service_name: $status${gl_bai}"
            else
                status="停止"
                echo -e "${gl_bai}服务状态:${gl_bai} ${gl_hong}$service_name: $status${gl_bai}"
            fi
        else
            echo -e "${gl_bai}服务状态:${gl_bai} ${gl_huang}未找到cron服务${gl_bai}"
        fi
    else
        echo -e "${gl_bai}服务状态:${gl_bai} ${gl_huang}无法检测服务状态${gl_bai}"
    fi

}

# 检测cron服务信息
detect_cron_service() {
    service_command=""
    cron_service_name=""

    current_user=$(whoami 2>/dev/null || echo "$USER")

    if command -v systemctl &>/dev/null; then
        service_command="systemctl"
        for service in cron crond cronie; do
            if systemctl list-unit-files --type=service 2>/dev/null | grep -q "^${service}.service"; then
                cron_service_name="$service"
                break
            fi
        done

    elif command -v service &>/dev/null; then
        service_command="service"
        for service in cron crond; do
            if service --status-all 2>/dev/null | grep -q "\s${service}" ||
                ls /etc/init.d/ 2>/dev/null | grep -q "^${service}$"; then
                cron_service_name="$service"
                break
            fi
        done

    elif command -v rc-service &>/dev/null; then
        service_command="rc-service"
        cron_service_name="cron"

    elif [ -f "/etc/init.d/cron" ] || [ -f "/etc/init.d/crond" ]; then
        service_command="init.d"
        if [ -f "/etc/init.d/cron" ]; then
            cron_service_name="cron"
        else
            cron_service_name="crond"
        fi
    fi

    echo -e "${gl_huang}检测到: ${service_command:-未知}, 服务名: ${cron_service_name:-未知}${gl_bai}"
}

# 停止cron服务
stop_cron_service() {
    echo -e ""
    echo -e "${gl_zi}>>> 正在停止cron服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    detect_cron_service

    if [ -n "$service_command" ] && [ -n "$cron_service_name" ]; then
        case "$service_command" in
        "systemctl")
            sudo systemctl stop "$cron_service_name" &&
                log_ok "cron服务已停止" ||
                log_error "停止cron服务失败"
            ;;
        "service")
            sudo service "$cron_service_name" stop &&
                log_ok "cron服务已停止" ||
                log_error "停止cron服务失败"
            ;;
        "rc-service")
            sudo rc-service cron stop &&
                log_ok "cron服务已停止" ||
                log_error "停止cron服务失败"
            ;;
        "init.d")
            sudo "/etc/init.d/$cron_service_name" stop &&
                log_ok "cron服务已停止" ||
                log_error "停止cron服务失败"
            ;;
        esac
    else
        log_error "无法确定如何停止cron服务"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

# 启动cron服务
start_cron_service() {
    echo -e ""
    echo -e "${gl_zi}>>> 正在启动cron服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    detect_cron_service

    if [ -n "$service_command" ] && [ -n "$cron_service_name" ]; then
        case "$service_command" in
        "systemctl")
            sudo systemctl start "$cron_service_name" &&
                log_ok "cron服务已启动" ||
                log_error "启动cron服务失败"
            ;;
        "service")
            sudo service "$cron_service_name" start &&
                log_ok "cron服务已启动" ||
                log_error "启动cron服务失败"
            ;;
        "rc-service")
            sudo rc-service cron start &&
                log_ok "cron服务已启动" ||
                log_error "启动cron服务失败"
            ;;
        "init.d")
            sudo "/etc/init.d/$cron_service_name" start &&
                log_ok "cron服务已启动" ||
                log_error "启动cron服务失败"
            ;;
        esac
    else
        log_error "无法确定如何启动cron服务"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

# 重启cron服务
restart_cron_service() {
    echo -e ""
    echo -e "${gl_zi}>>> 正在重启cron服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    detect_cron_service

    if [ -n "$service_command" ]; then
        case "$service_command" in
        "systemctl")
            if [ -n "$cron_service_name" ]; then
                if sudo systemctl restart "$cron_service_name"; then
                    log_ok "cron服务重启成功"
                    sleep_fractional 1
                    sudo systemctl status "$cron_service_name" --no-pager --lines=3
                else
                    log_error "cron服务重启失败"
                fi
            else
                log_error "未找到cron服务名，尝试通用方法 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                sudo systemctl restart cron crond cronie 2>/dev/null ||
                    log_warn "无法重启服务，可能需要手动操作"
            fi
            ;;
        "service")
            if [ -n "$cron_service_name" ]; then
                if sudo service "$cron_service_name" restart; then
                    log_ok "cron服务重启成功"
                    sleep_fractional 1
                    sudo service "$cron_service_name" status 2>/dev/null || true
                else
                    log_error "cron服务重启失败"
                fi
            else
                log_error "未找到cron服务名"
            fi
            ;;
        "rc-service")
            if sudo rc-service cron restart; then
                log_ok "cron服务重启成功"
            else
                log_error "cron服务重启失败"
            fi
            ;;
        "init.d")
            if [ -f "/etc/init.d/cron" ]; then
                sudo /etc/init.d/cron restart &&
                    log_ok "cron服务重启成功" ||
                    log_error "cron服务重启失败"
            elif [ -f "/etc/init.d/crond" ]; then
                sudo /etc/init.d/crond restart &&
                    log_ok "crond服务重启成功" ||
                    log_error "crond服务重启失败"
            else
                log_error "找不到init.d脚本"
            fi
            ;;
        esac
    else
        log_warn "未找到服务管理器，尝试直接重启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

        local cron_pids
        cron_pids=$(pgrep -x "cron\|crond\|cronie" 2>/dev/null)

        if [ -n "$cron_pids" ]; then
            echo -e "${gl_lan}停止cron进程 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            sudo kill $cron_pids 2>/dev/null
            sleep_fractional 1
        fi

        echo -e "${gl_lan}启动cron进程 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

        if command -v cron &>/dev/null; then
            sudo cron && log_ok "cron启动成功" || log_error "cron启动失败"
        elif command -v crond &>/dev/null; then
            sudo crond && log_ok "crond启动成功" || log_error "crond启动失败"
        else
            log_error "找不到cron守护进程"
        fi
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

# 重新加载cron配置（不重启服务）
reload_cron_config() {
    echo -e ""
    echo -e "${gl_zi}>>> 重新加载cron配置 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    detect_cron_service

    if [ "$service_command" = "systemctl" ] && [ -n "$cron_service_name" ]; then
        if sudo systemctl reload "$cron_service_name" 2>/dev/null; then
            log_ok "cron配置重新加载成功"
        elif sudo systemctl reload-or-restart "$cron_service_name" 2>/dev/null; then
            log_ok "cron配置已重新加载"
        else
            log_warn "systemd重新加载失败，尝试其他方法 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        fi
    fi

    local cron_pids
    cron_pids=$(pgrep -x "cron\|crond\|cronie" 2>/dev/null)

    if [ -n "$cron_pids" ]; then
        echo -e "${gl_lan}向cron进程发送重载信号 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        if sudo kill -HUP $cron_pids 2>/dev/null; then
            log_ok "已发送重载信号给cron进程"
        else
            log_error "无法发送重载信号"
        fi
    else
        log_warn "未找到运行的cron进程"
    fi

    echo -e "${gl_lan}通过crontab命令触发重载 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    if crontab -l >/dev/null 2>&1; then
        crontab -l | crontab - 2>/dev/null &&
            log_ok "当前用户crontab已重新加载" ||
            log_warn "重新加载当前用户crontab失败"
    fi

    echo -e "${gl_huang}提示：要重新加载系统crontab（/etc/crontab），需要重启服务${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

# 函数_创建脚本文件
create_script_in_opt() {
    echo -e ""
    echo -e "${gl_zi}>>> 在${gl_huang}/opt/scripts${gl_zi}创建脚本文件并用${gl_lv}nano${gl_zi}打开${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    mf_pkg_install nano

    local target_dir="/opt/scripts"

    if [ ! -d "$target_dir" ]; then
        log_info "目录 ${gl_lv}$target_dir${gl_bai} 不存在，正在创建 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        if mkdir -p "$target_dir"; then
            log_ok "目录创建成功。"
        else
            log_error "目录创建失败。"
            return 1
        fi
    fi

    while true; do
        read -r -e -p "$(echo -e "${gl_bai}请输入脚本名称 (直接回车使用 ${gl_lv}test${gl_bai}, ${gl_huang}0${gl_bai}返回): ")" script_name

        case "$script_name" in
        0) cancel_return; return 0 ;;
        "") script_name="test" ;;
        *)
            ;;
        esac

        if [[ ! "$script_name" =~ \.sh$ ]]; then
            script_name="${script_name}.sh"
        fi

        local file_path="$target_dir/$script_name"

        if [ -f "$file_path" ]; then
            log_warn "文件 $file_path 已存在。是否覆盖？"
            read -r -e -p "$(echo -e "${gl_bai}确认覆盖吗? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
            case "$confirm" in
            [Yy] | [Yy][Ee][Ss])
                log_info "将覆盖现有文件。"
                ;;
            *)
                log_info "跳过创建。"
                continue
                ;;
            esac
        fi

        if touch "$file_path"; then
            echo -e "${gl_bai}文件 ${gl_huang}$file_path ${gl_bai}创建成功。"

            chmod +x "$file_path"

            nano "$file_path"

            local nano_exit_code=$?

            echo -e ""
            echo -e "${gl_zi}>>> 脚本文件使用说明${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_bufan}请按以下格式输入cron表达式和命令：${gl_bai}"
            echo -e "${gl_bufan}*   *   *   *   *   ${gl_huang}要执行的命令${gl_bai}/${gl_hong}脚本路径${gl_bai}\n\
${gl_zi}|   ${gl_lan}|   ${gl_huang}|   ${gl_lv}|   ${gl_hong}|${gl_bai}\n\
${gl_zi}|   ${gl_lan}|   ${gl_huang}|   ${gl_lv}|   ${gl_hong}└── ${gl_hong}星期 (0-7, 0和7都代表周日)${gl_bai}\n\
${gl_zi}|   ${gl_lan}|   ${gl_huang}|   ${gl_lv}└────── ${gl_lv}月份 (1-12)${gl_bai}\n\
${gl_zi}|  ${gl_lan} |   ${gl_huang}└────────── ${gl_huang}日期 (1-31)${gl_bai}\n\
${gl_zi}|   ${gl_lan}└────────────── ${gl_lan}小时 (0-23)${gl_bai}\n\
${gl_zi}└────────────────── ${gl_zi}分钟 (0-59)${gl_bai}"
            echo -e ""
            echo -e "${gl_bai}任务示例: ${gl_zi}0 ${gl_lan}1 ${gl_huang}* ${gl_lv}* ${gl_hong}* ${gl_bufan}$file_path${gl_bai}"
            echo -e "${gl_bai}示例说明: 表达式 ${gl_lv}0 1 * * *${gl_bai} 精准匹配 “每天凌晨 ${gl_huang}1 ${gl_bai}点整” 执行任务"

            if [ $nano_exit_code -eq 0 ]; then
                echo -e "${gl_bai}脚本文件：${gl_lv}$file_path${gl_bai} 编辑完成。"
                chmod +x "$file_path"

                filename=$(stat -c "%n" "$file_path")
                perm=$(stat -c "(%a/%A)" "$file_path")

                echo -e "文件：${gl_lv}${filename}${gl_bai}  权限：${gl_huang}${perm}${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
            else
                log_error "nano 编辑异常退出 (退出码: $nano_exit_code)，但文件已创建。"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
            fi

            return 0
        else
            log_error "文件创建失败。"
            read -r -e -p "$(echo -e "${gl_bai}是否重试? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" retry
            case "$retry" in
            [Yy] | [Yy][Ee][Ss])
                continue
                ;;
            *)
                return 1
                ;;
            esac
        fi
    done
}

# 主菜单函数
linux_crontab_management() {
    while true; do
        clear
        echo -e "${gl_zi}>>> cron 计划任务管理器${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        show_crontab_status
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        show_crontab_list

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}停止cron服务            ${gl_bufan}2.  ${gl_bai}启动cron服务"
        echo -e "${gl_bufan}3.  ${gl_bai}重启cron服务            ${gl_bufan}4.  ${gl_bai}重载cron配置"
        echo -e "${gl_bufan}5.  ${gl_bai}创建脚本文件            ${gl_bufan}6.  ${gl_bai}删除脚本文件"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}7.  ${gl_bai}添加cron任务            ${gl_bufan}8.  ${gl_bai}删除cron任务"
        echo -e "${gl_bufan}9.  ${gl_bai}编辑cron文件            ${gl_bufan}10. ${gl_bai}查看cron文件"
        echo -e "${gl_bufan}11. ${gl_bai}刷新任务列表            ${gl_bufan}12. ${gl_bai}清空cron任务"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单          ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" choice

        case "$choice" in
        1)  stop_cron_service ;;                        # 停止cron服务
        2)  start_cron_service ;;                       # 启动cron服务
        3)  restart_cron_service ;;                     # 重启cron服务
        4)  reload_cron_config ;;                       # 重载cron配置
        5)  create_script_in_opt ;;                     # 创建脚本文件
        6)  cd /opt/scripts && interactive_delete ;;    # 删除脚本文件
        7)  add_crontab; continue ;;                    # 添加cron任务
        8)  delete_crontab; continue ;;                 # 删除cron任务
        9)  edit_crontab; continue ;;                   # 编辑cron文件
        10) view_raw_crontab ;;                         # 查看cron文件
        11) continue ;;                                 # 刷新任务列表
        12) clear_crontab; continue ;;                  # 清空cron任务
        0)  cancel_return "已是主菜单"; continue ;;
        00 | 000 | 0000) exit_script ;;
        *) handle_invalid_input ;;
        esac
    done
}

linux_crontab_management
