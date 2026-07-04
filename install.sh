#!/bin/bash

# 自动安装到系统
auto_install() {

    
    echo "正在自动安装命令收藏夹..."
    
    # 检查是否已经安装
    if command -v cb >/dev/null 2>&1; then
        echo "命令收藏夹已安装，正在更新..."
    fi
    
    # 获取脚本路径
    local script_path=""
    if [[ "${BASH_SOURCE[0]}" == "/dev/fd/"* ]] || [[ "${BASH_SOURCE[0]}" == "/proc/self/fd/"* ]]; then
        # 如果是通过 curl 下载的，需要特殊处理
        script_path="/tmp/cmdbox_install_$$.sh"
        cat > "$script_path" << 'EOF'
#!/bin/bash
# 这里是 cb.sh 的完整内容
EOF
        # 将当前脚本内容复制到临时文件
        cat "$0" >> "$script_path"
        chmod +x "$script_path"
    else
        script_path="$0"
    fi
    
    # 尝试自动安装
    if cp "$script_path" /usr/local/bin/cb 2>/dev/null; then
        chmod +x /usr/local/bin/cb
        echo -e "${gl_lv}${SUCCESS} 安装成功！${gl_bai}"
        echo "现在可以使用 'cb' 命令启动脚本"
        
        # 清理临时文件
        if [[ -f "/tmp/cmdbox_install_$$.sh" ]]; then
            rm -f "/tmp/cmdbox_install_$$.sh"
        fi
        
        # 检查是否是传参同步模式
        if [[ -n "${CMDBOX_ARGS[*]}" && "${CMDBOX_ARGS[0]}" == "--sync" && -n "${CMDBOX_ARGS[1]}" && -n "${CMDBOX_ARGS[2]}" ]]; then
            # 传参同步模式，直接运行新安装的脚本并传递参数
            exec env -i PATH="$PATH" HOME="$HOME" TERM="$TERM" cb "${CMDBOX_ARGS[@]}"
        else
            # 普通模式，直接运行新安装的脚本
            exec env -i PATH="$PATH" HOME="$HOME" TERM="$TERM" cb "${@:-}"
        fi
    else
        # 如果直接复制失败，尝试使用 sudo
        if sudo cp "$script_path" /usr/local/bin/cb 2>/dev/null; then
            sudo chmod +x /usr/local/bin/cb
            echo -e "${gl_lv}${SUCCESS} 安装成功！${gl_bai}"
            echo "现在可以使用 'cb' 命令启动脚本"
            
            # 清理临时文件
            if [[ -f "/tmp/cmdbox_install_$$.sh" ]]; then
                rm -f "/tmp/cmdbox_install_$$.sh"
            fi
            
            # 检查是否是传参同步模式
            if [[ -n "${CMDBOX_ARGS[*]}" && "${CMDBOX_ARGS[0]}" == "--sync" && -n "${CMDBOX_ARGS[1]}" && -n "${CMDBOX_ARGS[2]}" ]]; then
                # 传参同步模式，直接运行新安装的脚本并传递参数
                exec env -i PATH="$PATH" HOME="$HOME" TERM="$TERM" cb "${CMDBOX_ARGS[@]}"
            else
                # 普通模式，直接运行新安装的脚本
                exec env -i PATH="$PATH" HOME="$HOME" TERM="$TERM" cb "${@:-}"
            fi
        else
            echo -e "${gl_hong}${ERROR} 自动安装失败，可能需要管理员权限${gl_bai}"
            echo "请手动安装："
            echo "sudo cp $script_path /usr/local/bin/cb"
            echo "sudo chmod +x /usr/local/bin/cb"
            echo ""
            echo "或者直接运行："
            echo "bash $script_path"
            
            # 清理临时文件
            if [[ -f "/tmp/cmdbox_install_$$.sh" ]]; then
                rm -f "/tmp/cmdbox_install_$$.sh"
            fi
        fi
    fi
}

# 如果脚本是通过 curl 下载运行的，自动安装
if [[ "${BASH_SOURCE[0]}" == "/dev/fd/"* ]] || [[ "${BASH_SOURCE[0]}" == "/proc/self/fd/"* ]]; then
    # 保存参数到环境变量
    export CMDBOX_ARGS=("$@")
    auto_install
    exit 0
fi

# 命令收藏夹 v1.0.0
# 作者: Joey
# GitHub: https://github.com/byjoey/cmdbox
# 博客: https://joeyblog.net
# Telegram: https://t.me/+ft-zI76oovgwNmRh

# 清除可能干扰的环境变量
unset BOX_H BOX_V BOX_TL BOX_TR BOX_BL BOX_BR 2>/dev/null || true

CONFIG_DIR="$HOME/.cmdbox"
CONFIG_FILE="$CONFIG_DIR/config"
COMMANDS_FILE="$CONFIG_DIR/commands.json"
TEMP_FILE="$CONFIG_DIR/temp.json"

# 暂停函数
break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo "按任意键继续..."
    read -n 1 -s -r -p ""
    echo ""
    clear
}

# 静默同步（不显示错误信息）
sync_from_github_silent() {
    if [[ "$SYNC_MODE" != "github" || -z "$GITHUB_REPO" || -z "$GITHUB_TOKEN" ]]; then
        return 1
    fi
    
    local response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$GITHUB_REPO/contents/commands.json")
    
    if echo "$response" | jq -e '.content' >/dev/null 2>&1; then
        local content=$(echo "$response" | jq -r '.content')
        echo "$content" | base64 -d > "$COMMANDS_FILE" 2>/dev/null || echo "$content" | base64 -d > "$COMMANDS_FILE"
        return 0
    else
        return 1
    fi
}



# 颜色
gl_hui='\e[37m'
gl_hong='\033[31m'
gl_lv='\033[32m'
gl_huang='\033[33m'
gl_lan='\033[34m'
gl_bai='\033[0m'
gl_zi='\033[35m'
gl_kjlan='\033[96m'
BOLD='\033[1m'
DIM='\033[2m'
UNDERLINE='\033[4m'



#

# 框线
BOX_H='━'
BOX_V='┃'
BOX_TL='┏'
BOX_TR='┓'
BOX_BL='┗'
BOX_BR='┛'

print_header() {
    clear
    echo -e "${gl_kjlan}"

    echo -e "命令收藏夹 v1.0.3"
    echo -e "命令行输入${gl_huang}cb${gl_kjlan}可快速启动脚本${gl_bai}"
    echo -e "${gl_kjlan}------------------------${gl_bai}"
    echo -e "${gl_kjlan}作者:${gl_bai} Joey                    ${gl_kjlan}Telegram:${gl_bai} ${UNDERLINE}t.me/+ft-zI76oovgwNmRh${gl_bai}"
    echo -e "${gl_kjlan}GitHub:${gl_bai} ${UNDERLINE}github.com/byjoey/cmdbox${gl_bai}     ${gl_kjlan}Blog:${gl_bai} ${UNDERLINE}joeyblog.net${gl_bai}"
    echo -e "${gl_kjlan}------------------------${gl_bai}"
}

init_config() {
    local is_first_run=false
    
    if [[ ! -d "$CONFIG_DIR" ]]; then
        mkdir -p "$CONFIG_DIR"
        is_first_run=true
    fi
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        is_first_run=true
    fi
    
    if [[ ! -f "$COMMANDS_FILE" ]]; then
        echo '{"commands": []}' > "$COMMANDS_FILE"
    fi
    
    if [[ "$is_first_run" == true ]]; then
        show_welcome
    elif [[ ! -f "$CONFIG_FILE" ]]; then
        create_default_config
    fi
}

show_welcome() {
    print_header
    
    echo -e "${BOLD}${ROCKET} 欢迎使用命令收藏夹！${gl_bai}"
    echo ""
    echo -e "${gl_kjlan}这是一个强大的命令收藏工具，可以帮你：${gl_bai}"
    echo -e "  ${LIGHTNING} 存储和整理常用命令"
    echo -e "  ${ROCKET} 用数字快速执行命令"
    echo -e "  ${CLOUD} 通过GitHub云同步"
    echo -e "  ${STAR} 再也不会忘记有用的命令"
    echo ""
    
    echo -e "${BOLD}${GEAR} 选择你的使用模式：${gl_bai}"
    echo ""
    echo -e "${gl_lv}[1] 本地收藏模式${gl_bai}"
    echo -e "    • 命令只保存在本地"
    echo -e "    • 简单快速，无需配置"
    echo -e "    • 适合单机使用"
    echo ""
    echo -e "${gl_lan}[2] GitHub云同步模式${gl_bai}"
    echo -e "    • 命令自动同步到GitHub"
    echo -e "    • 多设备共享命令库"
    echo -e "    • 需要GitHub仓库和Token"
    echo ""
    
    while true; do
        read -e -p "请选择模式 [1/2]: " choice
        
        case "$choice" in
            1)
                setup_local_mode
                break
                ;;
            2)
                setup_github_mode
                break
                ;;
            *)
                echo ""
                echo -e "${gl_huang}${WARNING} 让我帮你选择...${gl_bai}"
                echo ""
                echo -e "${gl_lv}选择本地模式如果你：${gl_bai}"
                echo -e "  • 只在一台电脑上使用"
                echo -e "  • 不熟悉GitHub操作"
                echo -e "  • 希望简单快速开始"
                echo ""
                echo -e "${gl_lan}选择GitHub模式如果你：${gl_bai}"
                echo -e "  • 需要在多台设备同步"
                echo -e "  • 希望备份到云端"
                echo -e "  • 愿意花几分钟配置"
                echo ""
                echo -e "${gl_huang}${WARNING} 自动选择本地模式...${gl_bai}"
                setup_local_mode
                break
                ;;
        esac
    done
    
    echo ""
    echo -e "${gl_lv}${SUCCESS} 配置完成！正在启动命令收藏夹...${gl_bai}"
    sleep 2
}

setup_local_mode() {
    cat > "$CONFIG_FILE" << 'EOF'
SYNC_MODE=local
GITHUB_REPO=""
GITHUB_TOKEN=""
EOF
    
    echo -e "${gl_lv}${SUCCESS} 本地模式配置完成！${gl_bai}"
    echo -e "    ${DIM}命令将保存在: $CONFIG_DIR${gl_bai}"
}

setup_github_mode() {
    echo ""
    echo -e "${gl_kjlan}${BOLD}${GEAR} GitHub云同步配置向导${gl_bai}"
    echo ""
    echo -e "${gl_huang}${BOLD}准备工作：${gl_bai}"
    echo "1. 创建GitHub账号 (github.com)"
    echo "2. 创建新仓库用于存储命令"
    echo "3. 生成Personal Access Token"
    echo ""
    echo -e "${gl_huang}${BOLD}详细步骤：${gl_bai}"
    echo ""
    echo -e "${BOLD}Step 1: 创建仓库${gl_bai}"
    echo "• 登录GitHub → 点击'+' → New repository"
    echo "• 仓库名建议: cmdbox-commands"
    echo "• 可设为Private保护隐私"
    echo ""
    echo -e "${BOLD}Step 2: 生成Token${gl_bai}"
    echo "• 头像 → Settings → Developer settings"
    echo "• Personal access tokens → Tokens (classic)"
    echo "• Generate new token → 选择repo权限"
    echo "• ${gl_hong}${BOLD}重要: 复制生成的token（只显示一次）${gl_bai}"
    echo ""
    
    read -e -p "是否已完成准备工作？[y/n]: " ready
    
    if [[ "$ready" != "y" && "$ready" != "Y" ]]; then
        echo ""
        echo -e "${gl_huang}稍后可通过 'cb --reset' 重新配置${gl_bai}"
        setup_local_mode
        break_end
        show_main_interface
        return
    fi
    
    start_github_config
}

start_github_config() {
    echo ""
    echo -e "${gl_lv}${ROCKET} 开始GitHub配置${gl_bai}"
    echo ""
    
    local repo=""
    while true; do
        read -e -p "GitHub仓库 (格式: 用户名/仓库名): " repo
        
        if [[ "$repo" =~ ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$ ]]; then
            break
        else
            echo -e "${gl_hong}${ERROR} 格式错误，请使用: 用户名/仓库名${gl_bai}"
        fi
    done
    
    local token=""
    while true; do
        read -rs -p "Personal Access Token: " token
        echo ""
        
        if [[ -n "$token" ]]; then
            break
        else
            echo -e "${gl_hong}${ERROR} Token不能为空${gl_bai}"
        fi
    done
    
    test_github_connection "$repo" "$token"
}

test_github_connection() {
    local repo="$1"
    local token="$2"
    
    echo ""
    echo -e "${gl_huang}正在测试GitHub连接...${gl_bai}"
    
    local test_response=$(curl -s -H "Authorization: token $token" \
        "https://api.github.com/repos/$repo" 2>/dev/null)
    
    if echo "$test_response" | jq -e '.id' >/dev/null 2>&1; then
        echo -e "${gl_lv}${SUCCESS} GitHub连接成功！${gl_bai}"
        
        cat > "$CONFIG_FILE" << EOF
SYNC_MODE=github
GITHUB_REPO="$repo"
GITHUB_TOKEN="$token"
EOF
        
        read -e -p "是否从GitHub同步现有命令？[y/N]: " sync_choice
        
        if [[ "$sync_choice" == "y" || "$sync_choice" == "Y" ]]; then
            load_config
            sync_from_github
        fi
        
        break_end
        show_main_interface
        
    else
        echo -e "${gl_hong}${ERROR} 连接失败${gl_bai}"
        echo "可能原因: 仓库不存在、Token权限不足或网络问题"
        echo -e "${gl_huang}将使用本地模式，稍后可重新配置${gl_bai}"
        setup_local_mode
        break_end
        show_main_interface
    fi
}

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    fi
}

create_default_config() {
    cat > "$CONFIG_FILE" << 'EOF'
SYNC_MODE=local
GITHUB_REPO=""
GITHUB_TOKEN=""
EOF
}

show_main_interface() {
    local search_term="$1"
    
    print_header
    
    local mode_icon mode_text
    if [[ "$SYNC_MODE" == "github" ]]; then
        mode_icon="${CLOUD}"
        mode_text="GitHub同步"
    else
        mode_icon="${LOCAL}"
        mode_text="本地模式"
    fi
    
    echo -e "${gl_kjlan}状态: ${mode_icon} ${mode_text} | 命令数: $(jq -r '.commands | if type == "array" then length else 0 end' "$COMMANDS_FILE" 2>/dev/null || echo "0")${gl_bai}"
    echo -e "  • 输入关键词搜索命令"
    echo ""
    
    
    
    if [[ ! -f "$COMMANDS_FILE" ]] || [[ "$(jq -r '.commands | if type == "array" then length else 0 end' "$COMMANDS_FILE" 2>/dev/null || echo "0")" -eq 0 ]]; then
        show_empty_state
        return
    fi
    
    display_commands "$search_term"
    
    echo ""
    echo -e "${gl_kjlan}命令管理${gl_bai}"
    echo -e "${gl_kjlan}01.  ${gl_bai}添加命令"
    echo -e "${gl_kjlan}02.  ${gl_bai}编辑命令"
    echo -e "${gl_kjlan}03.  ${gl_bai}删除命令"
    echo -e "${gl_kjlan}04.  ${gl_bai}同步管理"
    echo -e "${gl_kjlan}05.  ${gl_bai}配置设置"
    echo -e "${gl_kjlan}06.  ${gl_bai}导入/导出"
    echo -e "${gl_kjlan}------------------------${gl_bai}"
    echo -e "${gl_kjlan}0.   ${gl_bai}退出程序"
    echo -e "${gl_kjlan}------------------------${gl_bai}"
    read -e -p "请输入你的选择: " input
    
    handle_input "$input" "$search_term"
}

show_empty_state() {
    echo -e "${gl_huang}${BOLD}暂无收藏的命令${gl_bai}"
    echo ""
    echo -e "${gl_kjlan}${ROCKET} 快速开始：${gl_bai}"
    echo "1. 输入 '01' 添加第一个命令"
    echo "2. 返回主界面用数字直接执行命令 (无需确认)"
    echo ""
    echo -e "${gl_lv}${BOLD}推荐命令：${gl_bai}"
    echo -e "  • ${gl_kjlan}系统监控${gl_bai}: htop"
    echo -e "  • ${gl_kjlan}查看端口${gl_bai}: netstat -tlnp"
    echo -e "  • ${gl_kjlan}Docker状态${gl_bai}: docker ps -a"
    echo -e "  • ${gl_kjlan}磁盘使用${gl_bai}: df -h"
    echo ""
    echo -e "${gl_kjlan}命令管理${gl_bai}"
    echo -e "${gl_kjlan}01.  ${gl_bai}添加命令"
    echo -e "${gl_kjlan}02.  ${gl_bai}编辑命令"
    echo -e "${gl_kjlan}03.  ${gl_bai}删除命令"
    echo -e "${gl_kjlan}04.  ${gl_bai}同步管理"
    echo -e "${gl_kjlan}05.  ${gl_bai}配置设置"
    echo -e "${gl_kjlan}06.  ${gl_bai}导入/导出"
    echo -e "${gl_kjlan}------------------------${gl_bai}"
    echo -e "${gl_kjlan}0.   ${gl_bai}退出程序"
    echo -e "${gl_kjlan}------------------------${gl_bai}"
    read -e -p "请输入你的选择: " input
    handle_input "$input"
}

display_commands() {
    local search_term="$1"
    local commands
    
    # 先检查文件是否有效
    if ! jq empty "$COMMANDS_FILE" 2>/dev/null; then
        echo -e "${gl_hong}${ERROR} 命令文件格式错误${gl_bai}"
        return
    fi
    
    if [[ -n "$search_term" ]]; then
        echo -e "${gl_huang}搜索结果: \"$search_term\"${gl_bai}"
        commands=$(jq -r --arg keyword "$search_term" '
            if .commands and (.commands | type == "array") then
                .commands | to_entries | 
                map(select(
                    (.value | type == "object") and
                    ((.value.name // "" | ascii_downcase | contains($keyword | ascii_downcase)) or 
                     (.value.command // "" | ascii_downcase | contains($keyword | ascii_downcase)) or 
                     (.value.description // "" | ascii_downcase | contains($keyword | ascii_downcase)))
                )) |
                if length > 0 then
                    to_entries | .[] | "\(.key + 1). \(.value.value.name // .value.value.command // .value.value.description // "未命名")"
                else
                    empty
                end
            else
                empty
            end
        ' "$COMMANDS_FILE" 2>/dev/null)
    else
        commands=$(jq -r '
            if .commands and (.commands | type == "array") then
                .commands | to_entries | 
                if length > 0 then
                    .[] | "\(.key + 1). \(.value.name // .value.command // .value.description // "未命名")"
                else
                    empty
                end
            else
                empty
            end
        ' "$COMMANDS_FILE" 2>/dev/null)
    fi
    
    if [[ -z "$commands" ]]; then
        echo -e "${gl_huang}没有找到匹配的命令${gl_bai}"
        return
    fi
    
    echo -e "$commands"
}

handle_input() {
    local input="$1"
    local search_term="$2"
    
    case "$input" in
        q|quit|exit|0)
            echo -e "${gl_lv}再见！${gl_bai}"
            exit 0
            ;;
        01)
            add_command
            ;;
        02)
            edit_command
            ;;
        03)
            delete_command
            ;;
        04)
            sync_menu
            ;;
        05)
            config_menu
            ;;
        06)
            import_export_menu
            ;;
        '')
            show_main_interface
            ;;
        *[0-9]*)
            if [[ "$input" =~ ^[0-9]+$ ]]; then
                execute_command "$input" "$search_term"
            else
                show_main_interface "$input"
            fi
            ;;
        *)
            show_main_interface "$input"
            ;;
    esac
}

execute_command() {
    local num="$1"
    local search_term="$2"
    
    local search_result command_data name command
    
    # 先检查文件格式
    if ! jq empty "$COMMANDS_FILE" 2>/dev/null; then
        echo -e "${gl_hong}${ERROR} 命令文件格式错误${gl_bai}"
        return
    fi
    
    if [[ -n "$search_term" ]]; then
        search_result=$(jq -r --arg keyword "$search_term" --arg num "$num" '
            if .commands and (.commands | type == "array") then
                .commands | to_entries | 
                map(select(
                    (.value | type == "object") and
                    ((.value.name // "" | ascii_downcase | contains($keyword | ascii_downcase)) or 
                     (.value.command // "" | ascii_downcase | contains($keyword | ascii_downcase)) or 
                     (.value.description // "" | ascii_downcase | contains($keyword | ascii_downcase)))
                )) |
                if length >= ($num | tonumber) and ($num | tonumber) > 0 then
                    .[($num | tonumber) - 1].value
                else
                    null
                end
            else
                null
            end
        ' "$COMMANDS_FILE" 2>/dev/null)
        
        if [[ "$search_result" == "null" || -z "$search_result" ]]; then
            echo -e "${gl_hong}${ERROR} 无效的命令编号${gl_bai}"
            echo ""
            show_main_interface "$search_term"
            return
        fi
        
        name=$(echo "$search_result" | jq -r '.name // "未命名"')
        command=$(echo "$search_result" | jq -r '.command // ""')
    else
        local total_commands=$(jq -r '.commands | if type == "array" then length else 0 end' "$COMMANDS_FILE" 2>/dev/null || echo "0")
        if [[ "$num" -gt "$total_commands" || "$num" -lt 1 ]]; then
            echo -e "${gl_hong}${ERROR} 无效的命令编号${gl_bai}"
            echo ""
            show_main_interface
            return
        fi
        
        command_data=$(jq -r --arg num "$num" '
            if .commands and (.commands | type == "array") and (.commands | length >= ($num | tonumber)) then
                .commands[($num | tonumber) - 1]
            else
                null
            end
        ' "$COMMANDS_FILE" 2>/dev/null)
        
        if [[ "$command_data" == "null" || -z "$command_data" ]]; then
            echo -e "${gl_hong}${ERROR} 无效的命令编号${gl_bai}"
            echo ""
            show_main_interface
            return
        fi
        
        name=$(echo "$command_data" | jq -r '.name // "未命名"')
        command=$(echo "$command_data" | jq -r '.command // ""')
    fi
    
    if [[ -z "$command" ]]; then
        echo -e "${gl_hong}${ERROR} 命令内容为空${gl_bai}"
        echo ""
        show_main_interface "$search_term"
        return
    fi
    
    echo ""
    echo -e "${gl_lv}${LIGHTNING} 执行命令: ${BOLD}$name${gl_bai}"
    echo -e "${gl_kjlan}$command${gl_bai}"
    echo ""
    
    echo -e "${gl_huang}正在执行...${gl_bai}"
    echo ""
    
    eval "$command"
    local exit_code=$?
    
    echo ""
    if [[ $exit_code -eq 0 ]]; then
        echo -e "${gl_lv}${SUCCESS} 命令执行完成${gl_bai}"
    else
        echo -e "${gl_hong}${ERROR} 命令执行失败 (退出码: $exit_code)${gl_bai}"
    fi
    
    break_end
    show_main_interface "$search_term"
}



add_command() {
    print_header
    echo -e "${gl_lv}${BOLD}添加新命令${gl_bai}"
    echo ""
    
    read -e -p "命令名称: " name
    
    if [[ -z "$name" ]]; then
        echo -e "${gl_hong}${ERROR} 命令名称不能为空${gl_bai}"
        break_end
        return
    fi
    
    read -e -p "命令内容: " command
    
    if [[ -z "$command" ]]; then
        echo -e "${gl_hong}${ERROR} 命令内容不能为空${gl_bai}"
        break_end
        return
    fi
    
    read -e -p "描述 (可选): " description
    
    local id=$(date +%s%N | cut -b1-13)
    local timestamp=$(date -Iseconds)
    
    local new_command=$(jq -n \
        --arg id "$id" \
        --arg name "$name" \
        --arg command "$command" \
        --arg description "$description" \
        --arg timestamp "$timestamp" \
        '{
            id: ($id | tonumber),
            name: $name,
            command: $command,
            description: $description,
            created_at: $timestamp,
            updated_at: $timestamp
        }')
    
    jq --argjson new_command "$new_command" '.commands += [$new_command]' "$COMMANDS_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$COMMANDS_FILE"
    
    echo ""
    echo -e "${gl_lv}${SUCCESS} 命令添加成功！${gl_bai}"
    
    echo ""
    echo -e "${gl_kjlan}${BOLD}推荐添加的命令：${gl_bai}"
    echo -e "  • ${gl_kjlan}系统监控${gl_bai}: htop"
    echo -e "  • ${gl_kjlan}查看端口${gl_bai}: netstat -tlnp"
    echo -e "  • ${gl_kjlan}Docker状态${gl_bai}: docker ps -a"
    echo -e "  • ${gl_kjlan}磁盘使用${gl_bai}: df -h"
    echo ""
    
    if [[ "$SYNC_MODE" == "github" ]]; then
        echo "正在自动同步..."
        sync_to_github
    fi
    
    break_end
    show_main_interface
}

edit_command() {
    print_header
    echo -e "${gl_huang}${BOLD}编辑命令${gl_bai}"
    echo ""
    
    local commands=$(jq -r '.commands | to_entries | .[] | "\(.key + 1). \(.value.name) - \(.value.command)"' "$COMMANDS_FILE")
    
    if [[ -z "$commands" ]]; then
        echo -e "${gl_huang}暂无命令可编辑${gl_bai}"
        break_end
        return
    fi
    
    echo "现有命令:"
    echo "$commands"
    echo ""
    
    read -e -p "请输入要编辑的命令编号: " num
    
    if ! [[ "$num" =~ ^[0-9]+$ ]]; then
        echo -e "${gl_hong}${ERROR} 请输入有效的数字${gl_bai}"
        break_end
        return
    fi
    
    local total_commands=$(jq '.commands | length' "$COMMANDS_FILE")
    if [[ "$num" -gt "$total_commands" || "$num" -lt 1 ]]; then
        echo -e "${gl_hong}${ERROR} 无效的命令编号${gl_bai}"
        break_end
        return
    fi
    
    local current=$(jq --arg num "$num" '.commands[($num | tonumber) - 1]' "$COMMANDS_FILE")
    
    echo ""
    echo "当前命令信息:"
    echo "$current" | jq -r '"名称: \(.name)\n命令: \(.command)\n描述: \(.description)"'
    echo ""
    
    echo "请输入新值 (直接回车保持原值):"
    read -e -p "新名称: " new_name
    read -e -p "新命令: " new_command
    read -e -p "新描述: " new_description
    
    local timestamp=$(date -Iseconds)
    local update_data=$(echo "$current" | jq \
        --arg name "$new_name" \
        --arg command "$new_command" \
        --arg description "$new_description" \
        --arg timestamp "$timestamp" '
        .name = (if $name == "" then .name else $name end) |
        .command = (if $command == "" then .command else $command end) |
        .description = (if $description == "" then .description else $description end) |
        .updated_at = $timestamp
    ')
    
    jq --arg num "$num" --argjson update_data "$update_data" \
        '.commands[($num | tonumber) - 1] = $update_data' \
        "$COMMANDS_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$COMMANDS_FILE"
    
    echo ""
    echo -e "${gl_lv}${SUCCESS} 命令更新成功！${gl_bai}"
    
    if [[ "$SYNC_MODE" == "github" ]]; then
        echo "正在自动同步..."
        sync_to_github
    fi
    
    break_end
    show_main_interface
}

delete_command() {
    print_header
    echo -e "${gl_hong}${BOLD}删除命令${gl_bai}"
    echo ""
    
    local commands=$(jq -r '.commands | to_entries | .[] | "\(.key + 1). \(.value.name) - \(.value.command)"' "$COMMANDS_FILE")
    
    if [[ -z "$commands" ]]; then
        echo -e "${gl_huang}暂无命令可删除${gl_bai}"
        break_end
        return
    fi
    
    echo "现有命令:"
    echo "$commands"
    echo ""
    
    read -e -p "请输入要删除的命令编号: " num
    
    if ! [[ "$num" =~ ^[0-9]+$ ]]; then
        echo -e "${gl_hong}${ERROR} 请输入有效的数字${gl_bai}"
        break_end
        return
    fi
    
    local total_commands=$(jq '.commands | length' "$COMMANDS_FILE")
    if [[ "$num" -gt "$total_commands" || "$num" -lt 1 ]]; then
        echo -e "${gl_hong}${ERROR} 无效的命令编号${gl_bai}"
        break_end
        return
    fi
    
    echo ""
    echo "要删除的命令:"
    jq --arg num "$num" '.commands[($num | tonumber) - 1]' "$COMMANDS_FILE" | jq -r '"名称: \(.name)\n命令: \(.command)\n描述: \(.description)"'
    echo ""
    
    read -e -p "确认删除？[y/N]: " confirm
    
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        jq --arg num "$num" 'del(.commands[($num | tonumber) - 1])' "$COMMANDS_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$COMMANDS_FILE"
        echo -e "${gl_lv}${SUCCESS} 命令删除成功！${gl_bai}"
        
        if [[ "$SYNC_MODE" == "github" ]]; then
            echo "正在自动同步..."
            sync_to_github
        fi

    else
        echo "取消删除"
    fi
    
    break_end
    show_main_interface
}

sync_menu() {
    print_header
    echo -e "${gl_lan}${BOLD}同步管理${gl_bai}"
    echo ""
    echo -e "当前模式: ${BOLD}$SYNC_MODE${gl_bai}"
    echo ""
    
    if [[ "$SYNC_MODE" == "github" ]]; then
        echo -e "${gl_kjlan}1.   ${gl_bai}同步到GitHub"
        echo -e "${gl_kjlan}2.   ${gl_bai}从GitHub同步"
        echo -e "${gl_kjlan}3.   ${gl_bai}切换到本地模式"
        echo -e "${gl_kjlan}------------------------${gl_bai}"
        echo -e "${gl_kjlan}0.   ${gl_bai}返回主界面"
        echo -e "${gl_kjlan}------------------------${gl_bai}"
        read -e -p "请输入你的选择: " choice
        
        case $choice in
            1) sync_to_github ;;
            2) sync_from_github ;;
            3) 
                sed -i "s/SYNC_MODE=.*/SYNC_MODE=local/" "$CONFIG_FILE"
                load_config
                echo -e "${gl_lv}${SUCCESS} 已切换到本地模式${gl_bai}"
                ;;
            0) show_main_interface; return ;;
            *) echo -e "${gl_hong}${ERROR} 无效选择${gl_bai}" ;;
        esac
    else
        echo -e "${gl_kjlan}1.   ${gl_bai}切换到GitHub同步模式"
        echo -e "${gl_kjlan}------------------------${gl_bai}"
        echo -e "${gl_kjlan}0.   ${gl_bai}返回主界面"
        echo -e "${gl_kjlan}------------------------${gl_bai}"
        read -e -p "请输入你的选择: " choice
        
        case $choice in
            1) setup_github_mode ;;
            0) show_main_interface; return ;;
            *) echo -e "${gl_hong}${ERROR} 无效选择${gl_bai}" ;;
        esac
    fi
    

    break_end
    show_main_interface
}

sync_to_github() {
    if [[ "$SYNC_MODE" != "github" || -z "$GITHUB_REPO" || -z "$GITHUB_TOKEN" ]]; then
        echo -e "${gl_hong}${ERROR} GitHub配置不完整${gl_bai}"
        return
    fi
    
    echo "正在同步到GitHub..."
    
    local content=$(base64 -w 0 "$COMMANDS_FILE" 2>/dev/null || base64 -b 0 "$COMMANDS_FILE" 2>/dev/null || base64 -i "$COMMANDS_FILE" 2>/dev/null || base64 "$COMMANDS_FILE")
    
    local sha_response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$GITHUB_REPO/contents/commands.json")
    
    local sha=""
    if echo "$sha_response" | jq -e '.sha' >/dev/null 2>&1; then
        sha=$(echo "$sha_response" | jq -r '.sha')
    fi
    
    local api_data=$(jq -n \
        --arg message "更新命令 $(date -Iseconds)" \
        --arg content "$content" \
        --arg sha "$sha" \
        'if $sha == "" then {message: $message, content: $content} else {message: $message, content: $content, sha: $sha} end')
    
    local response=$(curl -s -X PUT \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$api_data" \
        "https://api.github.com/repos/$GITHUB_REPO/contents/commands.json")
    
    if echo "$response" | jq -e '.content' >/dev/null 2>&1; then
        echo -e "${gl_lv}${SUCCESS} 同步到GitHub成功！${gl_bai}"
    else
        echo -e "${gl_hong}${ERROR} 同步失败: $(echo "$response" | jq -r '.message // "未知错误"')${gl_bai}"
    fi
}

sync_from_github() {
    if [[ "$SYNC_MODE" != "github" || -z "$GITHUB_REPO" || -z "$GITHUB_TOKEN" ]]; then
        echo -e "${gl_hong}${ERROR} GitHub配置不完整${gl_bai}"
        return
    fi
    
    echo "正在从GitHub同步..."
    
    local response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$GITHUB_REPO/contents/commands.json")
    
    if echo "$response" | jq -e '.content' >/dev/null 2>&1; then
        echo "$response" | jq -r '.content' | base64 -d > "$COMMANDS_FILE"
        echo -e "${gl_lv}${SUCCESS} 从GitHub同步成功！${gl_bai}"
    else
        echo -e "${gl_hong}${ERROR} 同步失败: $(echo "$response" | jq -r '.message // "文件不存在"')${gl_bai}"
    fi
}

config_menu() {
    print_header
    echo -e "${gl_kjlan}${BOLD}配置设置${gl_bai}"
    echo ""
    echo -e "${gl_kjlan}1.   ${gl_bai}查看当前配置"
    echo -e "${gl_kjlan}2.   ${gl_bai}重新配置GitHub"
    echo -e "${gl_kjlan}3.   ${gl_bai}导出快速连接"
    echo -e "${gl_kjlan}------------------------${gl_bai}"
    echo -e "${gl_kjlan}0.   ${gl_bai}返回主界面"
    echo -e "${gl_kjlan}------------------------${gl_bai}"
    read -e -p "请输入你的选择: " choice
    
    case $choice in
        1)
            echo ""
            echo -e "${gl_kjlan}${BOLD}当前配置:${gl_bai}"
            echo "同步模式: $SYNC_MODE"
            echo "GitHub仓库: ${GITHUB_REPO:-"未设置"}"
            echo "Token状态: $([ -n "$GITHUB_TOKEN" ] && echo "已设置" || echo "未设置")"
            ;;
        2)
            setup_github_mode
            ;;
        3)
            export_quick_connect
            ;;
        0)
            show_main_interface
            return
            ;;
        *)
            echo -e "${gl_hong}${ERROR} 无效选择${gl_bai}"
            ;;
    esac
    

    break_end
    show_main_interface
}

import_export_menu() {
    print_header
    echo -e "${gl_zi}${BOLD}导入/导出${gl_bai}"
    echo ""
    echo -e "${gl_kjlan}1.   ${gl_bai}导出命令到文件"
    echo -e "${gl_kjlan}2.   ${gl_bai}从文件导入命令"
    echo -e "${gl_kjlan}------------------------${gl_bai}"
    echo -e "${gl_kjlan}0.   ${gl_bai}返回主界面"
    echo -e "${gl_kjlan}------------------------${gl_bai}"
    read -e -p "请输入你的选择: " choice
    
    case $choice in
        1) export_commands ;;
        2) import_commands ;;
        0) show_main_interface; return ;;
        *) echo -e "${gl_hong}${ERROR} 无效选择${gl_bai}" ;;
    esac
    

    break_end
    show_main_interface
}

export_commands() {
    echo ""
    read -e -p "导出文件路径 (默认: ./命令备份_$(date +%Y%m%d_%H%M%S).json): " export_path
    
    if [[ -z "$export_path" ]]; then
        export_path="./命令备份_$(date +%Y%m%d_%H%M%S).json"
    fi
    
    cp "$COMMANDS_FILE" "$export_path"
    echo -e "${gl_lv}${SUCCESS} 命令已导出到: $export_path${gl_bai}"
    break_end
    show_main_interface
}

import_commands() {
    echo ""
    read -e -p "导入文件路径: " import_path
    
    if [[ ! -f "$import_path" ]]; then
        echo -e "${gl_hong}${ERROR} 文件不存在: $import_path${gl_bai}"
        break_end
        return
    fi
    
    if ! jq empty "$import_path" 2>/dev/null; then
        echo -e "${gl_hong}${ERROR} 无效的JSON文件${gl_bai}"
        break_end
        return
    fi
    
    echo ""
    echo "导入模式:"
    echo -e "${gl_kjlan}1.   ${gl_bai}合并 (保留现有命令并添加新命令)"
    echo -e "${gl_kjlan}2.   ${gl_bai}替换 (删除现有命令并使用导入的命令)"
    read -e -p "请选择: " mode
    
    case $mode in
        1)
            jq -s '.[0].commands + .[1].commands | {"commands": .}' "$COMMANDS_FILE" "$import_path" > "$TEMP_FILE" && mv "$TEMP_FILE" "$COMMANDS_FILE"
            echo -e "${gl_lv}${SUCCESS} 命令合并成功！${gl_bai}"
            ;;
        2)
            cp "$import_path" "$COMMANDS_FILE"
            echo -e "${gl_lv}${SUCCESS} 命令替换成功！${gl_bai}"
            ;;
        *)
            echo -e "${gl_hong}${ERROR} 无效选择${gl_bai}"
            break_end
            return
            ;;
    esac
    
    if [[ "$SYNC_MODE" == "github" ]]; then
        echo "正在自动同步..."
        sync_to_github
    fi
    
    break_end
    show_main_interface
}

# 导出快速连接
export_quick_connect() {
    print_header
    echo -e "${gl_lan}${BOLD}导出快速连接${gl_bai}"
    echo ""
    
    if [[ "$SYNC_MODE" != "github" || -z "$GITHUB_REPO" || -z "$GITHUB_TOKEN" ]]; then
        echo -e "${gl_hong}${ERROR} 当前不是GitHub模式或配置不完整${gl_bai}"
        echo "请先配置GitHub同步"
        break_end
        return
    fi
    
    echo -e "${gl_kjlan}${BOLD}当前GitHub配置：${gl_bai}"
    echo "仓库: $GITHUB_REPO"
    echo "Token: $GITHUB_TOKEN"
    echo ""
    
    echo -e "${gl_kjlan}${BOLD}传参同步命令：${gl_bai}"
    echo ""
    echo -e "${gl_lv}./install.sh --sync \"$GITHUB_REPO\" \"$GITHUB_TOKEN\"${gl_bai}"
    echo ""
    echo -e "${gl_kjlan}${BOLD}一键安装并同步命令：${gl_bai}"
    echo ""
    echo -e "${gl_lv}bash <(curl -l -s https://raw.githubusercontent.com/byJoey/cmdbox/refs/heads/main/install.sh) --sync \"$GITHUB_REPO\" \"$GITHUB_TOKEN\"${gl_bai}"
    echo ""
    echo -e "${gl_kjlan}${BOLD}使用说明：${gl_bai}"
    echo "• 复制上面的命令到新机器执行"
    echo "• 会自动安装并同步到GitHub"
    echo "• 无需手动配置GitHub信息"
    echo ""
    echo -e "${gl_huang}${BOLD}注意：${gl_bai}"
    echo "• Token 包含敏感信息，请妥善保管"
    echo "• 建议在安全环境下使用"
    echo ""
}

show_help() {
    echo -e "${gl_kjlan}命令收藏夹 - 高级命令收藏与快速启动器${gl_bai}"
    echo ""
    echo "用法: cb [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help     显示帮助信息"
    echo "  -v, --version  显示版本信息"
    echo "  -m, --manage   直接进入管理模式"
    echo "  -s, --sync     手动同步到GitHub"
    echo "  --sync <repo> <token>  传参同步到GitHub"
    echo "  --reset        重置配置（重新选择模式）"
    echo ""
    echo "传参同步示例:"
    echo "  cb --sync \"username/repo\" \"your_token\""
    echo "  bash <(curl -l -s https://raw.githubusercontent.com/byJoey/cmdbox/refs/heads/main/install.sh) --sync \"username/repo\" \"your_token\""
    echo ""
    echo "使用说明:"
    echo "  - 直接运行显示命令列表，输入数字直接执行命令 (无需确认)"
    echo "  - 输入关键词搜索命令"
    echo "  - 输入 'm' 进入管理模式添加/编辑命令"
    echo "  - 支持本地模式和GitHub云同步"
    echo "  - 支持传参快速同步到GitHub"
    echo ""
    echo "链接:"
    echo "  GitHub: https://github.com/byjoey/cmdbox"
    echo "  博客: https://joeyblog.net"
    echo "  Telegram: https://t.me/+ft-zI76oovgwNmRh"
}

show_version() {
    echo "命令收藏夹 v1.0.0 - 高级命令收藏与快速启动器"
    echo "作者: Joey"
}

main() {
    # 检查命令行参数
    if [[ "$1" == "--sync" && -n "$2" && -n "$3" ]]; then
        # 传参同步模式
        local repo="$2"
        local token="$3"
        echo -e "${gl_kjlan}正在使用传参同步到GitHub...${gl_bai}"
        
        # 确保配置目录存在
        mkdir -p "$CONFIG_DIR"
        
        # 设置GitHub配置
        cat > "$CONFIG_FILE" << EOF
SYNC_MODE=github
GITHUB_REPO="$repo"
GITHUB_TOKEN="$token"
EOF
        
        # 确保命令文件存在
        if [[ ! -f "$COMMANDS_FILE" ]]; then
            echo '{"commands": []}' > "$COMMANDS_FILE"
        fi
        
        # 从GitHub同步
        SYNC_MODE="github"
        GITHUB_REPO="$repo"
        GITHUB_TOKEN="$token"
        sync_from_github
        exit 0
    fi
    
    # 检查jq依赖
    if ! command -v jq &> /dev/null; then
        echo -e "${gl_hong}${ERROR} 错误: 需要安装 jq${gl_bai}"
        echo "Ubuntu/Debian: sudo apt install jq"
        echo "CentOS/RHEL: sudo yum install jq"
        echo "macOS: brew install jq"
        exit 1
    fi
    
    # 自动安装功能
    auto_install
    
    init_config
    load_config
    
    # 如果是GitHub模式，每次运行都同步
    if [[ "$SYNC_MODE" == "github" ]]; then
        echo -e "${gl_kjlan}正在从GitHub同步命令...${gl_bai}"
        if ! sync_from_github_silent; then
            echo -e "${gl_lv}${SUCCESS} 初始化成功！${gl_bai}"
        else
            echo -e "${gl_lv}${SUCCESS} 同步成功！${gl_bai}"
        fi
    fi
    
    case "${1:-}" in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--version)
            show_version
            exit 0
            ;;
        -m|--manage)
            show_main_interface
            exit 0
            ;;
        -s|--sync)
            if [[ "$SYNC_MODE" == "github" ]]; then
                sync_to_github
            else
                echo -e "${gl_huang}当前为本地模式，请先配置GitHub同步${gl_bai}"
            fi
            exit 0
            ;;
        --reset)
            echo -e "${gl_huang}正在重置配置...${gl_bai}"
            rm -f "$CONFIG_FILE"
            show_welcome
            exit 0
            ;;
        "")
            clear
            show_main_interface
            ;;
        *)
            echo -e "${gl_hong}${ERROR} 未知参数: $1${gl_bai}"
            show_help
            exit 1
            ;;
    esac
}

auto_install() {
    # 检查是否已经安装
    if command -v cb &> /dev/null && [[ "$(realpath "$(which cb)")" == "$(realpath "$0")" ]]; then
        return  # 已经安装且是当前脚本
    fi
    
    # 检查是否在系统路径中
    local script_path="$(realpath "$0")"
    if [[ "$script_path" == "/usr/local/bin/cb" ]] || [[ "$script_path" == "/usr/bin/cb" ]]; then
        return  # 已经在系统路径中
    fi
    
    # 自动安装到系统
    local install_path="/usr/local/bin/cb"
    local script_path="$(realpath "$0")"
    
    echo -e "${gl_huang}正在自动安装命令收藏夹...${gl_bai}"
    
    # 尝试复制到系统路径
    if sudo cp "$script_path" "$install_path" 2>/dev/null; then
        sudo chmod +x "$install_path"
        echo -e "${gl_lv}${SUCCESS} 安装成功！${gl_bai}"
        echo ""
        echo -e "${gl_kjlan}现在你可以在任何地方使用以下命令：${gl_bai}"
        echo -e "  ${gl_lv}${BOLD}cb${gl_bai}           # 启动命令收藏夹"
        echo -e "  ${gl_lv}${BOLD}cb -m${gl_bai}        # 直接进入管理模式"
        echo -e "  ${gl_lv}${BOLD}cb -h${gl_bai}        # 显示帮助信息"
        echo ""
        
        # 自动使用安装的版本启动
        echo -e "${gl_kjlan}正在启动安装的版本...${gl_bai}"
        sleep 1
        # 清除环境变量，只传递位置参数
        env -i PATH="$PATH" HOME="$HOME" TERM="$TERM" cb "${@:-}"
        exit $?
    else
        echo -e "${gl_hong}${ERROR} 自动安装失败，可能需要管理员权限${gl_bai}"
        echo -e "${gl_huang}请手动安装：${gl_bai}"
        echo -e "  ${gl_lv}sudo cp $(basename "$0") /usr/local/bin/cb${gl_bai}"
        echo -e "  ${gl_lv}sudo chmod +x /usr/local/bin/cb${gl_bai}"
        echo -e "${DIM}继续使用当前脚本...${gl_bai}"
        echo ""
    fi
}

install_to_system() {
    local install_path="/usr/local/bin/cb"
    local script_path="$(realpath "$0")"
    
    echo -e "${gl_huang}正在安装命令收藏夹...${gl_bai}"
    
    # 检查sudo权限
    if ! sudo -n true 2>/dev/null; then
        echo -e "${gl_hong}${ERROR} 需要管理员权限进行安装${gl_bai}"
        echo -e "${gl_huang}请尝试以下方法之一：${gl_bai}"
        echo -e "  1. 使用 ${gl_lv}sudo ./$(basename "$0")${gl_bai} 运行脚本"
        echo -e "  2. 手动安装: ${gl_lv}sudo cp $(basename "$0") /usr/local/bin/cb${gl_bai}"
        echo -e "  3. 继续使用当前脚本: ${gl_lv}./$(basename "$0")${gl_bai}"
        echo ""
        return 1
    fi
    
    # 尝试复制到系统路径
    if sudo cp "$script_path" "$install_path" 2>/dev/null; then
        sudo chmod +x "$install_path"
        echo -e "${gl_lv}${SUCCESS} 安装成功！${gl_bai}"
        echo ""
        echo -e "${gl_kjlan}现在你可以在任何地方使用以下命令：${gl_bai}"
        echo -e "  ${gl_lv}${BOLD}cb${gl_bai}           # 启动命令收藏夹"
        echo -e "  ${gl_lv}${BOLD}cb -m${gl_bai}        # 直接进入管理模式"
        echo -e "  ${gl_lv}${BOLD}cb -h${gl_bai}        # 显示帮助信息"
        echo ""
        
        # 询问是否立即使用安装的版本
        read -e -p "是否现在使用安装的版本启动？[Y/n]: " use_installed
        
        if [[ "$use_installed" != "n" && "$use_installed" != "N" ]]; then
            echo -e "${gl_kjlan}正在启动安装的版本...${gl_bai}"
            sleep 1
            # 清除环境变量，只传递位置参数
            env -i PATH="$PATH" HOME="$HOME" TERM="$TERM" cb
            exit $?
        fi
    else
        echo -e "${gl_hong}${ERROR} 安装失败，可能需要管理员权限${gl_bai}"
        echo -e "${gl_huang}请尝试手动安装：${gl_bai}"
        echo -e "  ${gl_lv}sudo cp $(basename "$0") /usr/local/bin/cb${gl_bai}"
        echo -e "  ${gl_lv}sudo chmod +x /usr/local/bin/cb${gl_bai}"
        echo -e "${DIM}你仍可以直接运行此脚本: ./$(basename "$0")${gl_bai}"
    fi
    
    echo ""
}

# 过滤掉环境变量，只传递位置参数
# 检查是否有位置参数，如果没有则传递空字符串
if [[ $# -eq 0 ]]; then
    main ""
else
    main "$@"
fi
