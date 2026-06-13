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

handle_invalid_input() {
    echo -ne "\r${gl_huang}无效的输入,请重新输入! ${gl_zi} 1 ${gl_huang} 秒后返回"
    sleep 1
    echo -e "\r${gl_lv}无效的输入,请重新输入! ${gl_zi}0${gl_lv} 秒后返回"
    sleep 0.5
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
    read -r -n 1 -s -p ""
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

check_git_repository() {
    local target_dir="${1:-.}"
    
    if ! cd "$target_dir" 2>/dev/null; then
        log_error "无法进入目录: ${gl_huang}$target_dir${gl_bai}"
        return 1
    fi
    
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        log_error "目录 ${gl_huang}$target_dir${gl_bai} 不是 Git 仓库"
        cd - >/dev/null
        return 1
    fi
    
    cd - >/dev/null
    return 0
}

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
                ver=$(7z 2>&1 | grep -oE '[0-9]+(\.[0-5]+)+' | head -n1 || echo "")
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

git_pull() {
    local work_dir="${1:-.}"
    local remote="${2:-origin}"
    local branch="${3:-}"
    local local_commit remote_commit base_commit upstream_branch

    if [[ ! -d "$work_dir" ]]; then
        log_error "工作目录不存在: ${gl_huang}$work_dir${gl_bai}"
        return 1
    fi
    
    cd "$work_dir" || {
        log_error "无法进入工作目录: ${gl_huang}$work_dir${gl_bai}"
        return 1
    }
    
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        log_error "当前目录不是 Git 仓库: ${gl_huang}$(pwd)${gl_bai}"
        return 1
    fi
    
    install git >/dev/null 2>&1

    if [[ -z $branch ]]; then
        branch=$(git symbolic-ref --short HEAD 2>/dev/null) || {
            log_error "无法获取当前分支，请切换到一个有效分支后重试"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            return 2
        }
    fi

    echo -e ""
    echo -e "${gl_zi}>>> 拉取当前项目更新${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    echo -e "${gl_bai}工作目录: ${gl_huang}$(pwd)${gl_bai}"
    repo_dir=$(basename "$(pwd)")
    echo -e "${gl_bai}项目名称: ${gl_huang}${repo_dir} ${gl_bai}仓库${gl_bai}"
    echo -e "${gl_bai}当前分支: ${gl_lv}${branch}${gl_bai}"
    
    if git rev-parse --abbrev-ref "@{upstream}" >/dev/null 2>&1; then
        upstream_branch=$(git rev-parse --abbrev-ref "@{upstream}")
        echo -e "${gl_bai}上游分支: ${gl_lv}${upstream_branch}${gl_bai}"
    else
        echo -e "${gl_bai}上游分支: ${gl_huang}未设置，正在自动关联 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        git branch --set-upstream-to="$remote/$branch" "$branch" >/dev/null 2>&1
        upstream_branch=$(git rev-parse --abbrev-ref "@{upstream}" 2>/dev/null || echo "关联失败")
        echo -e "${gl_bai}已关联: ${gl_lv}${upstream_branch}${gl_bai}"
    fi
    
    echo -e "${gl_bai}远程名称: ${gl_lv}${remote}${gl_bai}"
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_info "检查远程仓库信息 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    
    if git remote get-url "$remote" &>/dev/null; then
        echo -e "${gl_bai}远程仓库URL: ${gl_lv}$(git remote get-url "$remote")${gl_bai}"
    else
        log_error "远程仓库 $remote 未配置"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return 9
    fi
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_info "工作目录内容预览:${gl_bai}"
    ls --color=auto -lha | head -20
    echo -e "${gl_huang}(显示前20个文件/目录)${gl_bai}"
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    log_info "检查工作目录状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    local status_output=$(git status --short 2>/dev/null)
    if [[ -n "$status_output" ]]; then
        echo -e "${gl_bai}当前有未提交的更改:${gl_bai}"
        echo -e "${status_output}" | while IFS= read -r line; do
            echo -e "  ${gl_huang}${line}${gl_bai}"
        done
        
        read -r -e -p "$(echo -e "${gl_huang}有未提交的更改，是否继续拉取? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" continue_pull
        
        if [[ ! "$continue_pull" =~ ^[Yy]$ ]]; then
            log_warn "已取消拉取操作"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            return 0
        fi
    else
        log_ok "工作目录干净，可以安全拉取"
    fi
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    log_info "正在拉取最新的远程信息 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bai}执行: git fetch ${gl_huang}${remote}${gl_bai}"
    
    if git fetch "$remote"; then
        log_ok "远程信息获取成功"
    else
        log_error "git fetch 失败"
        echo -e "${gl_bai}可能原因：网络问题 / 权限不足 / 仓库不存在${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return 3
    fi

    local_commit=$(git rev-parse @ 2>/dev/null)
    remote_commit=$(git rev-parse "$remote/$branch" 2>/dev/null)
    base_commit=$(git merge-base @ "$remote/$branch" 2>/dev/null)

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_info "版本对比信息:${gl_bai}"
    echo -e "${gl_bai}本地提交: ${gl_lv}$(git log --oneline -1 @ 2>/dev/null || echo "未知")${gl_bai}"
    echo -e "${gl_bai}远程提交: ${gl_lv}$(git log --oneline -1 "$remote/$branch" 2>/dev/null || echo "未知")${gl_bai}"

    if [[ "$local_commit" == "$remote_commit" ]]; then
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        log_ok "当前分支已是最新版本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return 0
    fi

    if [[ "$local_commit" == "$base_commit" ]]; then
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        log_warn "检测到远程更新，开始拉取 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        
        echo -e "${gl_bai}执行: git pull ${gl_huang}${remote} ${branch}${gl_bai}"
        if git pull "$remote" "$branch"; then
            log_ok "代码拉取更新成功！"
        else
            log_error "拉取失败！存在冲突或权限问题"
            git status --short | grep -E "UU|AA|DD" && echo -e "${gl_huang}检测到冲突文件，请手动解决${gl_bai}"
        fi
        
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return 0
    else
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        log_warn "本地有未推送提交，与远程存在分歧"
        log_info "建议：先 git push，再运行本脚本拉取"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return 8
    fi
}

show_help() {
    echo -e ""
    echo -e "${gl_zi}>>> Git 拉取工具${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}用法: $0 [工作目录] [远程名称] [分支名称]${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}参数说明:${gl_bai}"
    echo -e "${gl_lv}  工作目录  ${gl_bai}要拉取的 Git 仓库路径 (默认: 当前目录)"
    echo -e "${gl_lv}  远程名称  ${gl_bai}远程仓库名称 (默认: origin)"
    echo -e "${gl_lv}  分支名称  ${gl_bai}要拉取的分支名称 (默认: 当前分支)"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}示例:${gl_bai}"
    echo -e "${gl_huang}  $0                     ${gl_bai}# 拉取当前目录的仓库"
    echo -e "${gl_huang}  $0 /path/to/repo       ${gl_bai}# 拉取指定目录的仓库"
    echo -e "${gl_huang}  $0 /path/to/repo origin ${gl_bai}# 拉取指定目录，使用 origin 远程"
    echo -e "${gl_huang}  $0 . origin main        ${gl_bai}# 拉取当前目录的 main 分支"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}注意: 如果目录不是 Git 仓库，脚本会自动退出${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
}

main() {
    if [[ $# -eq 1 ]] && [[ "$1" == "help" || "$1" == "--help" || "$1" == "-h" ]]; then
        show_help
        return 0
    fi
    
    local work_dir="${1:-.}"
    local remote="${2:-origin}"
    local branch="${3:-}"
    
    git_pull "$work_dir" "$remote" "$branch"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi