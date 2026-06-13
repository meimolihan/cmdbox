#!/bin/bash
set -uo pipefail

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
}
list_color_init

log_info()  { echo -e "${gl_lan}[信息]${gl_bai} $*"; }
log_ok()    { echo -e "${gl_lv}[成功]${gl_bai} $*"; }
log_warn()  { echo -e "${gl_huang}[警告]${gl_bai} $*"; }
log_error() { echo -e "${gl_hong}[错误]${gl_bai} $*" >&2; }

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n 1 -s
    echo ""
    clear
}

sleep_fractional() {
    local seconds=$1
    if sleep "$seconds" 2>/dev/null; then return 0; fi
    if command -v perl >/dev/null 2>&1; then perl -e "select(undef, undef, undef, $seconds)"; return 0; fi
    if command -v python3 >/dev/null 2>&1; then python3 -c "import time; time.sleep($seconds)"; return 0; fi
    if command -v python >/dev/null 2>&1; then python -c "import time; time.sleep($seconds)"; return 0; fi
    local int_seconds=$(echo "$seconds" | awk '{print int($1+0.999)}')
    sleep "$int_seconds"
}

exit_animation() {
    echo -ne "\r${gl_lv}即将退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo ""
}

install() {
    [[ $# -eq 0 ]] && {
        log_error "未提供软件包参数!"
        return 1
    }
    local pkg mgr ver cmd_ver installed=false
    for pkg in "$@"; do
        installed=false
        ver=""
        if command -v "$pkg" &>/dev/null; then
            cmd_ver=$("$pkg" --version 2>/dev/null|head -n1|tr -cd '[:print:]'|grep -oE '[0-9]+(\.[0-9]+)+'|head -n1||echo "")
            [[ -n "$cmd_ver" ]] && ver="$cmd_ver"
            installed=true
        fi
        if [[ "$pkg" == "7zip" || "$pkg" == "7z" ]]; then
            if command -v 7z &>/dev/null; then
                ver=$(7z 2>&1|grep -oE '[0-9]+(\.[0-9]+)+'|head -n1||echo "")
                [[ -n "$ver" ]] && installed=true
            fi
        fi
        if [[ "$installed" == false ]]; then
            if command -v opkg &>/dev/null; then
                if opkg list-installed|grep -q "^${pkg} "; then
                    installed=true
                    ver=$(opkg list-installed|grep "^${pkg} "|awk '{print $3}' 2>/dev/null||echo "")
                fi
            elif command -v dpkg-query &>/dev/null; then
                if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null|grep -q "install ok installed"; then
                    installed=true
                    ver=$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null||echo "")
                fi
            elif command -v rpm &>/dev/null; then
                if rpm -q "$pkg" &>/dev/null; then
                    installed=true
                    ver=$(rpm -q --qf '%{VERSION}' "$pkg" 2>/dev/null||echo "")
                fi
            elif command -v apk &>/dev/null; then
                if apk info "$pkg" 2>/dev/null|grep -q "^installed"; then
                    installed=true
                    ver=$(apk info -a "$pkg" 2>/dev/null|grep -oE '[0-9]+(\.[0-9]+)+'|head -n1||echo "")
                fi
            elif command -v pacman &>/dev/null; then
                if pacman -Qi "$pkg" &>/dev/null; then
                    installed=true
                    ver=$(pacman -Qi "$pkg" 2>/dev/null|grep -i "version"|grep -oE '[0-9]+(\.[0-9]+)+'|head -n1||echo "")
                fi
            fi
        fi
        if [[ "$installed" == true ]]; then
            echo -e "${gl_huang}${pkg}${gl_bai} ${gl_lv}已安装${gl_bai} $([[ -n "$ver" ]] && echo "版本 ${gl_lv}${ver}${gl_bai}")"
            continue
        fi
        echo -e ""
        echo -e "${gl_huang}开始安装：${gl_bai}${pkg}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        local install_success=false
        for mgr in opkg dnf yum apt apk pacman zypper pkg; do
            if ! command -v "$mgr" &>/dev/null; then continue; fi
            case $mgr in
            opkg)
                echo -e "${gl_bai}使用包管理器: ${gl_zi}opkg (OpenWrt/iStoreOS)${gl_bai}"
                if [[ "$pkg" == "7zip" || "$pkg" == "7z" ]]; then
                    opkg update && opkg install p7zip && install_success=true
                else
                    opkg update && opkg install "$pkg" && install_success=true
                fi
                ;;
            dnf)
                dnf -y update && dnf install -y "$pkg" && install_success=true
                ;;
            yum)
                yum -y update && yum install -y "$pkg" && install_success=true
                ;;
            apt)
                apt update -y && apt install -y "$pkg" && install_success=true
                ;;
            apk)
                apk update && apk add "$pkg" && install_success=true
                ;;
            pacman)
                pacman -Syu --noconfirm && pacman -S --noconfirm "$pkg" && install_success=true
                ;;
            zypper)
                zypper refresh && zypper install -y "$pkg" && install_success=true
                ;;
            pkg)
                pkg update && pkg install -y "$pkg" && install_success=true
                ;;
            esac
            [[ "$install_success" == true ]] && break
        done
        if [[ "$install_success" == true ]]; then
            echo -e "${gl_lv}✓ ${pkg} 安装成功${gl_bai}"
        else
            echo -e "${gl_hong}✗ ${pkg} 安装失败${gl_bai}"
        fi
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    done
}

fix_nano_config() {
    local nano_version nano_vendor
    local distro_id distro_version
    local env_files_updated="0"

    echo -e ""
    echo -e "${gl_zi}开始修复 nano 配置 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        distro_id="${ID:-unknown}"
        distro_version="${VERSION_ID:-unknown}"
        echo -e "${gl_lv}检测到系统: $PRETTY_NAME${gl_bai}"
    else
        distro_id=$(uname -s)
        distro_version=$(uname -r)
        echo -e "${gl_huang}警告: 无法检测发行版，使用通用配置${gl_bai}"
    fi

    if command -v nano &>/dev/null; then
        nano_version=$(nano --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-7]+)?' | head -n1)
        echo -e "${gl_lv}nano 版本: ${nano_version:-未知}${gl_bai}"
    else
        echo -e "${gl_hong}错误: nano 未安装${gl_bai}"
        exit_animation
        return 1
    fi

    echo -e ""
    echo -e "${gl_huang}>>> 设置中文环境变量 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    touch ~/.profile ~/.bash_profile ~/.bashrc

    sed -i '/^export LANG=.*/d' ~/.profile 2>/dev/null
    sed -i '/^export LANGUAGE=.*/d' ~/.profile 2>/dev/null
    sed -i '/^export LC_ALL=.*/d' ~/.profile 2>/dev/null
    sed -i '/^# Nano.*/d' ~/.profile 2>/dev/null

    sed -i '/^export LANG=.*/d' ~/.bash_profile 2>/dev/null
    sed -i '/^export LANGUAGE=.*/d' ~/.bash_profile 2>/dev/null
    sed -i '/^export LC_ALL=.*/d' ~/.bash_profile 2>/dev/null
    sed -i '/^# Nano.*/d' ~/.bash_profile 2>/dev/null

    sed -i '/^export LANG=.*/d' ~/.bashrc 2>/dev/null
    sed -i '/^export LANGUAGE=.*/d' ~/.bashrc 2>/dev/null
    sed -i '/^export LC_ALL=.*/d' ~/.bashrc 2>/dev/null
    sed -i '/^# Nano.*/d' ~/.bashrc 2>/dev/null

    echo -e "" >>~/.profile
    echo -e "# Nano 中文环境设置（由 fix_nano_config 添加）" >>~/.profile
    echo 'export LANG=zh_CN.UTF-8' >>~/.profile
    echo 'export LANGUAGE=zh_CN:zh' >>~/.profile
    echo 'export LC_ALL=zh_CN.UTF-8' >>~/.profile

    echo -e "" >>~/.bash_profile
    echo -e "# Nano 中文环境设置（由 fix_nano_config 添加）" >>~/.bash_profile
    echo 'export LANG=zh_CN.UTF-8' >>~/.bash_profile
    echo 'export LANGUAGE=zh_CN:zh' >>~/.bash_profile
    echo 'export LC_ALL=zh_CN.UTF-8' >>~/.bash_profile

    echo -e "" >>~/.bashrc
    echo -e "# Nano 中文环境设置（由 fix_nano_config 添加）" >>~/.bashrc
    echo 'export LANG=zh_CN.UTF-8' >>~/.bashrc
    echo 'export LANGUAGE=zh_CN:zh' >>~/.bashrc
    echo 'export LC_ALL=zh_CN.UTF-8' >>~/.bashrc

    if ! grep -q "\. ~/.bashrc" ~/.profile 2>/dev/null && ! grep -q "source ~/.bashrc" ~/.profile 2>/dev/null; then
        echo 'if [ -n "$BASH_VERSION" ]; then' >>~/.profile
        echo '    if [ -f "$HOME/.bashrc" ]; then' >>~/.profile
        echo '        . "$HOME/.bashrc"' >>~/.profile
        echo '    fi' >>~/.profile
        echo 'fi' >>~/.profile
    fi

    if ! grep -q "\. ~/.bashrc" ~/.bash_profile 2>/dev/null && ! grep -q "source ~/.bashrc" ~/.bash_profile 2>/dev/null; then
        echo 'if [ -f ~/.bashrc ]; then' >>~/.bash_profile
        echo '    . ~/.bashrc' >>~/.bash_profile
        echo 'fi' >>~/.bash_profile
    fi

    export LANG=zh_CN.UTF-8
    export LANGUAGE=zh_CN:zh
    export LC_ALL=zh_CN.UTF-8

    echo -e "${gl_lv}✓ 中文环境变量已写入配置文件${gl_bai}"
    echo -e "${gl_huang}注意: 需要手动执行以下命令使环境变量立即生效:${gl_bai}"
    echo -e "  ${gl_lv}source ~/.bashrc${gl_bai}"

    echo -e ""
    echo -e "${gl_huang}>>> 创建 nano 配置 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    echo -e "${gl_lv}正在创建 nano 配置文件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    cat >~/.nanorc <<EOF
# Nano 配置 - 自动修复版
# 生成时间: $(date +"%Y-%m-%d %H:%M:%S")
# 系统: $distro_id $distro_version
# Nano版本: $nano_version

# 关闭自动缩进（解决粘贴问题）
unset autoindent

# 基本编辑设置
set tabsize 4
set tabstospaces
set nowrap
set mouse
EOF

    if [[ -n "$nano_version" ]]; then
        if [[ $(echo "$nano_version 2.7.0" | tr ' ' '\n' | sort -V | head -n1) == "2.7.0" ]]; then
            cat >>~/.nanorc <<'EOF'
# 高级功能（nano >= 2.7.0）
set linenumbers
set constantshow
set indicator
set smarthome
EOF
        else
            cat >>~/.nanorc <<'EOF'
# 基本功能（旧版 nano）
# 注释掉可能导致错误的选项
# set linenumbers
# set constantshow
# set indicator
# set smarthome
EOF
        fi
    else
        cat >>~/.nanorc <<'EOF'
# 尝试启用高级功能（如果支持）
set linenumbers
# set constantshow
# set indicator
# set smarthome
EOF
    fi

    cat >>~/.nanorc <<'EOF'
# 功能设置
set historylog
set backup
EOF

    add_syntax_highlight() {
        local syntax_paths=(
            "/usr/share/nano"
            "/usr/share/nano/extra"
            "/etc/nano"
            "/usr/local/share/nano"
            "/opt/nano/share/nano"
        )

        local syntax_added=0
        for path in "${syntax_paths[@]}"; do
            if [[ -d "$path" ]] && ls "$path"/*.nanorc &>/dev/null; then
                if ! grep -q "include.*$path" ~/.nanorc 2>/dev/null; then
                    echo "include \"$path/*.nanorc\"" >>~/.nanorc
                    echo -e "${gl_lv}已添加语法高亮: $path${gl_bai}"
                    syntax_added=$((syntax_added + 1))
                fi
            fi
        done

        if [[ $syntax_added -eq 0 ]]; then
            echo "# 未找到语法高亮文件" >>~/.nanorc
            echo -e "${gl_huang}警告: 未找到语法高亮文件${gl_bai}"
        fi
    }

    add_syntax_highlight

    echo -e ""
    echo -e "${gl_huang}>>> 验证配置 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if nano --rcfile=~/.nanorc --version &>/dev/null; then
        echo -e "${gl_lv}✓ 配置语法检查通过${gl_bai}"
    else
        echo -e "${gl_hong}✗ 配置有错误，创建最小配置 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        cat >~/.nanorc <<'EOF'
# 最小安全配置
unset autoindent
set tabsize 4
set nowrap
set mouse
EOF
    fi

    echo -e ""
    echo -e "${gl_huang}>>> 配置摘要:${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_lv}✓ nano 配置文件已创建: ~/.nanorc${gl_bai}"
    echo -e "${gl_lv}✓ 文件大小: $(wc -l <~/.nanorc) 行${gl_bai}"

    sed -i '/^# Nano 别名/d' ~/.bashrc 2>/dev/null
    sed -i '/^alias nano=/d' ~/.bashrc 2>/dev/null
    sed -i '/^alias nanopaste=/d' ~/.bashrc 2>/dev/null
    sed -i '/^alias nanoraw=/d' ~/.bashrc 2>/dev/null
    sed -i '/^# 中文环境测试命令/d' ~/.bashrc 2>/dev/null
    sed -i '/^alias nano-zh=/d' ~/.bashrc 2>/dev/null

    cat >>~/.bashrc <<'EOF'

# Nano 别名（由 fix_nano_config 添加）
alias nano='nano -i'  # 默认关闭自动缩进
alias nanopaste='nano -i -w'  # 适合粘贴的模式
alias nanoraw='nano -I'  # 忽略所有配置文件

alias nano-zh='LANG=zh_CN.UTF-8 LANGUAGE=zh_CN:zh LC_ALL=zh_CN.UTF-8 nano'
EOF

    echo -e "${gl_lv}✓ Nano 别名已添加到 ~/.bashrc${gl_bai}"
    echo -e "${gl_lv}✓ 中文测试命令已添加：nano-zh${gl_bai}"

    echo -e ""
    echo -e "${gl_huang}>>> 修复完成 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_lv}✓ nano 配置修复完成！${gl_bai}"
    echo -e ""
    echo -e "${gl_huang}重要提示:${gl_bai}"
    echo -e "  1. ${gl_lv}请手动执行以下命令使配置立即生效:${gl_bai}"
    echo -e "     ${gl_zi}source ~/.bashrc${gl_bai}"
    echo -e "  2. 重启终端后配置将自动生效"
    echo -e "  3. 测试中文显示: ${gl_lv}nano-zh 文件名${gl_bai}"
    echo -e "  4. 测试粘贴功能: ${gl_lv}nanopaste 文件名${gl_bai}"
    echo -e "  5. 如果仍有问题: ${gl_lv}nanoraw 文件名${gl_bai}（忽略所有配置）"
    echo -e ""
    echo -e "${gl_huang}配置已应用到以下文件:${gl_bai}"
    echo -e "  ${gl_lv}~/.nanorc${gl_bai} - nano 主配置文件"
    echo -e "  ${gl_lv}~/.bashrc${gl_bai} - 环境变量和别名"
    echo -e "  ${gl_lv}~/.profile${gl_bai} - 登录环境变量"
    echo -e "  ${gl_lv}~/.bash_profile${gl_bai} - 登录环境变量"
    echo -e ""
    echo -e "${gl_huang}如需在新终端中生效，请执行:${gl_bai}"
    echo -e "  ${gl_zi}source ~/.bashrc${gl_bai}"
    echo -e ""
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    return 0
}

tools_install_nano() {
    clear
    echo -e "${gl_zi}>>> 安装 nano文本编辑器 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    install nano
    fix_nano_config
    echo ""
    echo -e "${gl_huang}>>> 工具已安装，使用方法如下："
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_lv}Ctrl + G：${gl_bai}显示帮助文档"
    echo -e "${gl_lv}Ctrl + X：${gl_bai}退出nano（会提示保存）"
    echo -e "${gl_lv}Ctrl + O：${gl_bai}保存文件（Write Out）"
    echo -e "${gl_lv}Ctrl + R：${gl_bai}插入其他文件内容"
    echo -e "${gl_lv}Ctrl + W：${gl_bai}搜索文本"
    echo -e "${gl_lv}Ctrl + \\：${gl_bai}替换文本"
    echo -e "${gl_lv}Ctrl + K：${gl_bai}剪切当前行（删除行）"
    echo -e "${gl_lv}Ctrl + U：${gl_bai}粘贴剪切的内容"
    echo -e "${gl_lv}Ctrl + J：${gl_bai}对齐段落"
    echo -e "${gl_lv}Ctrl + T：${gl_bai}检查拼写（需要拼写检查器）"
    echo -e "${gl_lv}Ctrl + C：${gl_bai}显示光标位置（行/列）"
    echo -e "${gl_lv}Ctrl + _：${gl_bai}跳转到指定行号"
    echo -e "${gl_lv}Ctrl + A：${gl_bai}移动到行首"
    echo -e "${gl_lv}Ctrl + E：${gl_bai}移动到行尾"
    echo -e "${gl_lv}Ctrl + Y：${gl_bai}向上翻页"
    echo -e "${gl_lv}Ctrl + V：${gl_bai}向下翻页"
    echo -e "${gl_lv}Ctrl + 6：${gl_bai}标记文本开始（用于复制/剪切）"
    echo -e "${gl_lv}Alt + A：${gl_bai}开始标记文本块"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

tools_install_nano