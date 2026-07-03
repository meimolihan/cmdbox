#!/bin/bash
set -uo pipefail

# 1. 颜色变量定义
list_color_init() {
    export gl_hui=$'\033[38;5;59m'   # 灰色
    export gl_hong=$'\033[38;5;9m'   # 红色
    export gl_lv=$'\033[38;5;10m'    # 绿色
    export gl_huang=$'\033[38;5;11m' # 黄色
    export gl_lan=$'\033[38;5;32m'   # 蓝色
    export gl_bai=$'\033[38;5;15m'   # 白色
    export gl_zi=$'\033[38;5;13m'    # 紫色
    export gl_bufan=$'\033[38;5;14m' # 亮青色
    export reset=$'\033[0m'          # 重置
}
list_color_init

# 2. 日志函数
log_info()  { echo -e "${gl_lan}[信息]${gl_bai} $*"; }
log_ok()    { echo -e "${gl_lv}[成功]${gl_bai} $*"; }
log_warn()  { echo -e "${gl_huang}[警告]${gl_bai} $*"; }
log_error() { echo -e "${gl_hong}[错误]${gl_bai} $*" >&2; }

# 6. 公共函数
handle_invalid_input() {
    echo -ne "\r\033[K${gl_huang}无效的输入,请重新输入! ${gl_zi} 1 ${gl_huang} 秒后返回"
    sleep_fractional 1
    echo -ne "\r\033[K${gl_lv}无效的输入,请重新输入! ${gl_zi}0${gl_lv} 秒后返回"
    sleep_fractional 0.5
    echo -ne "\r\033[K"
    return 2
}

handle_y_n() {
    echo -e "${gl_hong}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai})${gl_hong}。${gl_bai}"
    sleep 1
    echo -e "${gl_huang}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai})${gl_huang}。${gl_bai}"
    sleep 1
    echo -e "${gl_lv}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai})${gl_lv}。${gl_bai}"
    sleep 0.5
    return 2
}

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n 1 -s -r -p ""
    echo ""
    clear
}

sleep_fractional() {
    local seconds=$1
    if sleep "$seconds" 2>/dev/null; then
        return 0
    fi
    
    if command -v perl >/dev/null 2>&1; then
        perl -e "select(undef, undef, undef, $seconds)"
        return 0
    fi
    
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "import time; time.sleep($seconds)"
        return 0
    elif command -v python >/dev/null 2>&1; then
        python -c "import time; time.sleep($seconds)"
        return 0
    fi
    
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

cancel_return() {
    local menu_name="${1:-上一级选单}"
    echo -e "${gl_lv}即将返回到 ${gl_huang}${menu_name}${gl_lv} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    sleep 0.6
    echo ""
    clear
}

exit_script() {
    echo ""
    echo -ne "${gl_hong}感谢使用，再见！ ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    clear
    exit 0
}

# 安装工具函数
install() {
    [[ $# -eq 0 ]] && {
        log_error "未提供软件包参数!"
        return 1
    }

    local pkg mgr ver cmd_ver pkg_ver installed=false
    for pkg in "$@"; do
        installed=false
        ver=""

        if command -v "$pkg" &>/dev/null; then
            cmd_ver=$("$pkg" --version 2>/dev/null | head -n1 | tr -cd '[:print:]' | grep -oE '[0-9]+(\.[0-9]+)+' | head -n1 || echo "")
            [[ -n "$cmd_ver" ]] && ver="$cmd_ver"
            installed=true
        fi

        if [[ "$pkg" == "7zip" || "$pkg" == "7z" ]]; then
            if command -v 7z &>/dev/null; then
                ver=$(7z 2>&1 | grep -oE '[0-9]+(\.[0-9]+)+' | head -n1 || echo "")
                [[ -n "$ver" ]] && installed=true
            fi
        fi

        if [[ "$installed" == false ]]; then
            if command -v opkg &>/dev/null; then
                if opkg list-installed | grep -q "^${pkg} "; then
                    installed=true
                    ver=$(opkg list-installed | grep "^${pkg} " | awk '{print $3}' 2>/dev/null || echo "")
                fi
            elif command -v dpkg-query &>/dev/null; then
                if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
                    installed=true
                    ver=$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null || echo "")
                fi
            elif command -v rpm &>/dev/null; then
                if rpm -q "$pkg" &>/dev/null; then
                    installed=true
                    ver=$(rpm -q --qf '%{VERSION}' "$pkg" 2>/dev/null || echo "")
                fi
            elif command -v apk &>/dev/null; then
                if apk info "$pkg" 2>/dev/null | grep -q "^installed"; then
                    installed=true
                    ver=$(apk info -a "$pkg" 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)+' | head -n1 || echo "")
                fi
            elif command -v pacman &>/dev/null; then
                if pacman -Qi "$pkg" &>/dev/null; then
                    installed=true
                    ver=$(pacman -Qi "$pkg" 2>/dev/null | grep -i "version" | grep -oE '[0-9]+(\.[0-9]+)+' | head -n1 || echo "")
                fi
            fi
        fi

        if [[ "$installed" == true ]]; then
            continue
        fi

        echo -e ""
        echo -e "${gl_huang}开始安装：${gl_bai}${pkg}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        local install_success=false

        for mgr in opkg dnf yum apt apk pacman zypper pkg; do
            if ! command -v "$mgr" &>/dev/null; then
                continue
            fi

            case $mgr in
            opkg)
                echo -e "${gl_bai}使用包管理器: ${gl_zi}opkg (OpenWrt/iStoreOS)${gl_bai}"
                if [[ "$pkg" == "7zip" || "$pkg" == "7z" ]]; then
                    echo -e "${gl_bai}正在安装: ${gl_lv}p7zip${gl_bai}"
                    opkg update && opkg install p7zip && install_success=true
                else
                    opkg update && opkg install "$pkg" && install_success=true
                fi
                ;;
            dnf)
                echo -e "${gl_bai}使用包管理器: ${gl_zi}dnf (Fedora/RHEL)${gl_bai}"
                dnf -y update && dnf install -y "$pkg" && install_success=true
                ;;
            yum)
                echo -e "${gl_bai}使用包管理器: ${gl_zi}yum (CentOS/RHEL)${gl_bai}"
                yum -y update && yum install -y "$pkg" && install_success=true
                ;;
            apt)
                echo -e "${gl_bai}使用包管理器: ${gl_zi}apt (Debian/Ubuntu)${gl_bai}"
                apt update -y && apt install -y "$pkg" && install_success=true
                ;;
            apk)
                echo -e "${gl_bai}使用包管理器: ${gl_zi}apk (Alpine)${gl_bai}"
                apk update && apk add "$pkg" && install_success=true
                ;;
            pacman)
                echo -e "${gl_bai}使用包管理器: ${gl_zi}pacman (Arch/Manjaro)${gl_bai}"
                pacman -Syu --noconfirm && pacman -S --noconfirm "$pkg" && install_success=true
                ;;
            zypper)
                echo -e "${gl_bai}使用包管理器: ${gl_zi}zypper (openSUSE)${gl_bai}"
                zypper refresh && zypper install -y "$pkg" && install_success=true
                ;;
            pkg)
                echo -e "${gl_bai}使用包管理器: ${gl_zi}pkg (FreeBSD)${gl_bai}"
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

# 主推送函数
git_push() {
    local target_dir="${1:-.}"

    if [[ ! -d "$target_dir" ]]; then
        log_error "目录不存在：$target_dir"
        exit_animation
        return 1
    fi

    cd "$target_dir" || {
        log_error "无法进入目录：$target_dir"
        exit_animation
        return 1
    }

    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        log_error "当前目录不是 Git 仓库"
        exit_animation
        return 1
    fi

    install git

    if [[ -z $(git config user.name) || -z $(git config user.email) ]]; then
        log_error "Git 用户名或邮箱未配置，请先配置。"
        echo -e "       ${gl_huang}git config --global user.name \"Your Name\"${gl_bai}"
        echo -e "       ${gl_huang}git config --global user.email \"your.email@example.com\"${gl_bai}"
        return 2
    fi

    echo -e ""
    echo -e "${gl_zi}>>> 推送当前项目更新${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}当前工作目录: ${gl_huang}$(pwd)${gl_bai}"
    repo_dir=$(basename "$(pwd)")
    echo -e "${gl_bai}当前项目名称: ${gl_huang}${repo_dir} ${gl_bai}仓库${gl_bai}"
    echo -e "${gl_bai}当前分支: ${gl_lv}$(git branch --show-current 2>/dev/null)${gl_bai}"
    
    if ! git remote | grep -q .; then
        log_error "没有配置远程仓库"
        echo -e "       ${gl_huang}请先添加远程仓库: git remote add origin <repository-url>${gl_bai}"
        exit_animation
        return 1
    fi
    
    echo -e "${gl_bai}远程仓库: ${gl_lv}$(git remote -v | head -1)${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    log_info "检查当前 Git 状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bai}状态:${gl_bai}"
    git status --short 2>/dev/null || echo -e "  ${gl_huang}无法获取 Git 状态${gl_bai}"
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    # 1. 检查是否有任何更改（包括已暂存和未暂存）
    local status_output
    status_output=$(git status --porcelain 2>/dev/null)
    
    if [[ -z "$status_output" ]]; then
        # 2. 没有本地更改，检查是否有未推送的提交
        local ahead_count=0
        if git rev-parse @{u} >/dev/null 2>&1; then
            ahead_count=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0)
        fi
        
        if [[ "$ahead_count" -gt 0 ]]; then
            log_info "有 ${gl_huang}${ahead_count}${gl_lan} 个已提交但未推送的更改"
        else
            log_ok "无变更，无需提交"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            return 0
        fi
    else
        # 3. 有本地更改，分析更改类型
        local has_staged_changes=false
        local has_unstaged_changes=false
        local has_untracked_files=false
        
        # 逐行分析状态
        while IFS= read -r line; do
            if [[ -z "$line" ]]; then
                continue
            fi
            
            # 获取状态标记
            local staged="${line:0:1}"
            local unstaged="${line:1:1}"
            
            # 检查是否有已暂存的更改
            if [[ "$staged" != " " ]] && [[ "$staged" != "?" ]]; then
                has_staged_changes=true
            fi
            
            # 检查是否有未暂存的更改
            if [[ "$unstaged" != " " ]] && [[ "$unstaged" != "?" ]]; then
                has_unstaged_changes=true
            fi
            
            # 检查是否有未跟踪的文件
            if [[ "$staged" == "?" ]] && [[ "$unstaged" == "?" ]]; then
                has_untracked_files=true
            fi
        done <<< "$status_output"
        
        # 4. 处理不同类型的更改
        if [[ "$has_unstaged_changes" == true ]] || [[ "$has_untracked_files" == true ]]; then
            log_info "正在添加所有未跟踪/修改的文件到暂存区 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            git add .
            
            if [[ $? -ne 0 ]]; then
                log_error "添加文件失败"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
                return 1
            fi
            
            # 重新检查是否有已暂存的更改
            has_staged_changes=true
        fi
        
        # 5. 提交更改
        if [[ "$has_staged_changes" == true ]]; then
            # 显示将要提交的更改
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            log_info "将要提交的更改:${gl_bai}"
            git status --short
            
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            log_info "正在提交更改 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            git commit -m "update $(date '+%Y-%m-%d %H:%M:%S')"
            
            if [[ $? -ne 0 ]]; then
                log_error "提交失败，请检查 Git 状态。"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
                return 1
            fi
        fi
    fi
    
    # 6. 检查是否有未推送的提交
    local ahead_count=0
    if git rev-parse @{u} >/dev/null 2>&1; then
        ahead_count=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0)
    fi
    
    # 7. 推送更改
    if [[ "$ahead_count" -gt 0 ]]; then
        log_info "正在推送到远程仓库 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        
        if git push; then
            log_ok "推送成功！"
        else
            log_warn "推送失败，尝试使用 SSH 方式或检查网络连接"
            
            local remote_url=$(git remote get-url origin 2>/dev/null || echo "")
            if [[ -n "$remote_url" ]]; then
                if [[ "$remote_url" == https://* ]]; then
                    echo -e "${gl_huang}当前使用 HTTPS 协议，尝试切换到 SSH 协议${gl_bai}"
                    read -r -e -p "$(echo -e "${gl_bai}是否切换到 SSH 协议? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" switch_to_ssh
                    
                    if [[ "$switch_to_ssh" =~ ^[Yy]$ ]]; then
                        local ssh_url=$(echo "$remote_url" | sed -E 's|^https://([^/]+)/(.+)$|git@\1:\2|')
                        echo -e "${gl_bai}新的 SSH URL: ${gl_huang}$ssh_url${gl_bai}"
                        
                        read -r -e -p "$(echo -e "${gl_bai}确认更新远程 URL? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm_update
                        
                        if [[ "$confirm_update" =~ ^[Yy]$ ]]; then
                            git remote set-url origin "$ssh_url"
                            log_info "已更新远程 URL，正在尝试推送 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                            
                            if git push; then
                                log_ok "使用 SSH 协议推送成功！"
                            else
                                log_error "SSH 推送也失败，请检查 SSH 密钥配置和网络连接"
                            fi
                        fi
                    fi
                fi
            fi
        fi
    else
        log_ok "已是最新，无需推送"
    fi
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
    return 0
}

# 命令行帮助
show_help() {
    echo -e ""
    echo -e "${gl_zi}>>> Git 自动推送工具${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}用法: $0 [目录路径]${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}功能:${gl_bai}"
    echo -e "${gl_lv}  • 自动添加、提交和推送 Git 更改${gl_bai}"
    echo -e "${gl_lv}  • 支持 HTTPS 自动切换到 SSH${gl_bai}"
    echo -e "${gl_lv}  • 自动安装缺失的 Git${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}示例:${gl_bai}"
    echo -e "${gl_huang}  $0            ${gl_bai}# 推送当前目录"
    echo -e "${gl_huang}  $0 /path/to/repo ${gl_bai}# 推送指定目录"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
}

# 主程序入口
main() {
    # 如果第一个参数是 help 或 --help 或 -h，显示帮助
    if [[ $# -eq 1 ]] && [[ "$1" == "help" || "$1" == "--help" || "$1" == "-h" ]]; then
        show_help
        return 0
    fi
    
    # 否则执行推送
    git_push "$@"
}

# 检查是否直接运行脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
