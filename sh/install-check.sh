#!/bin/bash

gl_hui='\e[37m'
gl_hong='\033[31m'
gl_lv='\033[32m'
gl_huang='\033[33m'
gl_lan='\033[34m'
gl_bai='\033[0m'
gl_zi='\033[35m'
gl_bufan='\033[96m'

sh_download() {
    local script_path="/etc/profile.d/linux-check.sh"
    local link_path="/usr/local/bin/g"
    
    if [ -s /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            istoreos) ISTOREOS=1 ;;
            *)        ISTOREOS=0 ;;
        esac
    else
        ISTOREOS=0
    fi
    
    if [ "$ISTOREOS" = 1 ]; then
        echo "检测到 iStoreOS 系统"
    else
        echo "检测到非 iStoreOS 系统"
    fi
    
    if [ "$ISTOREOS" = 1 ]; then
        URL="https://gitee.com/meimolihan/cmdbox/raw/master/sh/istoreos-check.sh"
    else
        URL="https://gitee.com/meimolihan/cmdbox/raw/master/sh/linux-check.sh"
    fi
    
    if [ -f "/etc/profile.d/istoreos-check.sh" ]; then
        echo -e "清理旧别名文件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        rm -f /etc/profile.d/istoreos-check.sh
    fi
    
    echo -e "正在下载脚本 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    if ! curl -sS -o "$script_path" "$URL"; then
        echo "错误：下载失败，请检查网络连接"
        return 1
    fi
    
    if [ ! -s "$script_path" ]; then
        echo "错误：下载的文件为空或无效"
        return 1
    fi
    
    chmod +x "$script_path"
    echo "脚本已保存到: $script_path"
    
    echo -e "创建快捷命令 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    
    if [ -L "$link_path" ] || [ -f "$link_path" ]; then
        rm -f "$link_path"
    fi
    
    if ln -sf "$script_path" "$link_path"; then
        echo "快捷命令已创建: 'g' -> $script_path"
    else
        echo -e "警告：创建软链接失败，尝试其他路径 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        if ln -sf "$script_path" "/usr/local/bin/g"; then
            link_path="/usr/local/bin/g"
            echo "快捷命令已创建: '/usr/local/bin/g' -> $script_path"
        else
            echo "错误：无法创建软链接，请手动执行: $script_path"
        fi
    fi
    
    local link_dir=$(dirname "$link_path")
    if ! echo "$PATH" | tr ':' '\n' | grep -q "^$(echo "$link_dir" | sed 's/[\/&]/\\&/g')$"; then
        echo "注意：$link_dir 不在 PATH 中，可能需要添加到 PATH 或使用完整路径"
    else
        echo "检查: 'g' 命令已在 PATH 中"
    fi
    
    echo -e "\n测试快捷命令 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    if command -v g >/dev/null 2>&1; then
        echo "✓ 快捷命令 'g' 已可用"
    else
        echo "⚠  'g' 命令未找到，可能需要重新登录或执行: source /etc/profile"
        echo "   或者直接使用: $script_path"
    fi
    
    echo -e "\n执行脚本 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    if [ -x "$script_path" ]; then
        "$script_path" "$@"
    else
        echo "错误：脚本不可执行"
        return 1
    fi
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    sh_download "$@"
fi