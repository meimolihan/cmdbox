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

sleep_fractional() {
    local seconds=$1
    if sleep "$seconds" 2>/dev/null; then return 0; fi
    if command -v perl >/dev/null 2>&1; then perl -e "select(undef, undef, undef, $seconds)"; return 0; fi
    if command -v python3 >/dev/null 2>&1; then python3 -c "import time; time.sleep($seconds)"; return 0; fi
    if command -v python >/dev/null 2>&1; then python -c "import time; time.sleep($seconds)"; return 0; fi
    local int_seconds=$(echo "$seconds" | awk '{print int($1+0.999)}')
    sleep "$int_seconds"
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
                opkg update && opkg install "$pkg" && install_success=true
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

scan_git_repos() {
    local root_dir="$1"
    [[ ! -d "$root_dir" ]] && return
    find "$root_dir" -name ".git" -type d 2>/dev/null | awk -F'/.git$' '{print $1}' | sort -u
}

fix_git_safe_directories() {
    install git
    local ARG_DIRS=("$@")
    local INTERACTIVE_MODE=true
    if [[ ${#ARG_DIRS[@]} -gt 0 ]]; then
        INTERACTIVE_MODE=false
    else
        clear
    fi

    local preset_dirs=(
        "/compose"
        "/mnt/compose"
        "/vol1/1000/compose"
        "/vol2/1000/compose"
        "/vol1/1000/GitHub"
        "/vol1/1000/Gitee"
    )

    local safe_dirs_list
    safe_dirs_list=$(git config --global --get-all safe.directory 2>/dev/null || true)

    local scan_targets=()
    if $INTERACTIVE_MODE; then
        scan_targets=("${preset_dirs[@]}")
    else
        scan_targets=("${ARG_DIRS[@]}")
    fi

    local all_git_repos=()
    for t in "${scan_targets[@]}"; do
        while IFS= read -r repo; do
            [[ -n "$repo" ]] && all_git_repos+=("$repo")
        done < <(scan_git_repos "$t")
    done
    readarray -t all_git_repos < <(printf "%s\n" "${all_git_repos[@]}" | sort -u)

    if [[ ${#all_git_repos[@]} -eq 0 ]]; then
        log_warn "未扫描到任何 Git 仓库"
        [[ $INTERACTIVE_MODE == true ]] && sleep_fractional 1
        return
    fi

    if $INTERACTIVE_MODE; then
        echo -e ""
        echo -e "${gl_zi}>>> 修复 Git 仓库安全目录 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        log_info "扫描全部预设目录 Git 仓库完成"
        echo -e "${gl_bai}扫描到以下 Git 仓库:${gl_bai}"
        for repo in "${all_git_repos[@]}"; do
            local repo_name=$(basename "$repo")
            if echo "$safe_dirs_list" | grep -Fxq "$repo"; then
                echo -e "  ${gl_lv}●${gl_bai} ${gl_lv}${repo_name}${gl_bai} ${gl_lv}[已是安全目录]${gl_bai}"
            else
                echo -e "  ${gl_hong}●${gl_bai} ${gl_hong}${repo_name}${gl_bai} ${gl_hong}[未添加]${gl_bai}"
            fi
        done
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        sleep_fractional 1
        clear

        echo -e ""
        echo -e "${gl_huang}>>> 请选择要处理的目录:${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        local menu_options=()
        local option_paths=()

        for preset_dir in "${preset_dirs[@]}"; do
            [[ ! -d "$preset_dir" ]] && continue
            local repos_under=()
            for r in "${all_git_repos[@]}"; do
                [[ "$r" == "${preset_dir}"* ]] && repos_under+=("$r")
            done
            [[ ${#repos_under[@]} -eq 0 ]] && continue

            local all_safe=true
            for r in "${repos_under[@]}"; do
                if ! echo "$safe_dirs_list" | grep -Fxq "$r"; then
                    all_safe=false
                    break
                fi
            done

            local tip
            if $all_safe; then
                tip="${gl_lv}全部已添加${gl_bai}"
            else
                tip="${gl_huang}待修复${gl_bai}"
            fi
            menu_options+=("${gl_huang}$preset_dir ${gl_bai}[${gl_lv}${#repos_under[@]}${gl_bai}个仓库] [${tip}]")
            option_paths+=("$preset_dir")
        done

        for repo in "${all_git_repos[@]}"; do
            local repo_name=$(basename "$repo")
            local tip
            if echo "$safe_dirs_list" | grep -Fxq "$repo"; then
                tip="${gl_lv}已是安全目录${gl_bai}"
            else
                tip="${gl_hong}未添加${gl_bai}"
            fi
            menu_options+=("${gl_huang}$repo_name ${gl_bai}[${tip}]")
            option_paths+=("$repo")
        done

        menu_options+=("手动指定路径")
        option_paths+=("MANUAL_INPUT")

        for i in "${!menu_options[@]}"; do
            echo -e "${gl_bufan}$((i + 1)).${gl_bai} ${menu_options[i]}"
        done
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        local max_choice=${#menu_options[@]}
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择 (${gl_lv}1${gl_bai}-${gl_huang}$max_choice${gl_bai}) (${gl_huang}0${gl_bai}返回): ")" dir_choice

        if [[ "$dir_choice" =~ ^[0-9]+$ ]]; then
            if [[ $dir_choice -eq 0 ]]; then
                return
            elif [[ $dir_choice -le $max_choice ]]; then
                local selected_path="${option_paths[$((dir_choice - 1))]}"
                if [[ "$selected_path" == "MANUAL_INPUT" ]]; then
                    read -r -e -p "$(echo -e "${gl_bai}请输入自定义路径: ")" SCAN_DIR
                else
                    SCAN_DIR="$selected_path"
                fi
            else
                log_error "无效选择"
                return
            fi
        else
            SCAN_DIR="$dir_choice"
        fi

        [[ -z "$SCAN_DIR" ]] && { log_warn "路径不能为空"; return; }
        [[ ! -d "$SCAN_DIR" ]] && { log_warn "目录不存在: $SCAN_DIR"; return; }
        local TARGET_DIRS=("$SCAN_DIR")
    else
        local TARGET_DIRS=("${ARG_DIRS[@]}")
        log_info "批量模式启动，待处理目录：${TARGET_DIRS[*]}"
    fi

    local target_repos=()
    for tdir in "${TARGET_DIRS[@]}"; do
        while IFS= read -r r; do
            [[ -n "$r" ]] && target_repos+=("$r")
        done < <(scan_git_repos "$tdir")
    done
    readarray -t target_repos < <(printf "%s\n" "${target_repos[@]}" | sort -u)

    if [[ ${#target_repos[@]} -eq 0 ]]; then
        log_warn "所选目录内没有找到 Git 仓库"
        return
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_info "开始批量添加安全目录，总计 ${#target_repos[@]} 个仓库"
    local processed_count=0
    local skipped_count=0

    for i in "${!target_repos[@]}"; do
        local repo_dir="${target_repos[i]}"
        local repo_name=$(basename "$repo_dir")
        echo -e "【$((i+1))/${#target_repos[@]}】${gl_huang}$repo_name${gl_bai} | $repo_dir"

        if echo "$safe_dirs_list" | grep -Fxq "$repo_dir"; then
            echo -e "  ${gl_lv}✓${gl_bai} 已是安全目录，跳过"
            ((skipped_count++))
        else
            if git config --global --add safe.directory "$repo_dir" 2>/dev/null; then
                echo -e "  ${gl_lv}✓${gl_bai} 成功添加安全目录"
                ((processed_count++))
                safe_dirs_list+=$'\n'"$repo_dir"
            else
                echo -e "  ${gl_hong}✗${gl_bai} 添加失败"
            fi
        fi
        echo ""
    done

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_ok "处理汇总"
    echo -e "总仓库数量: ${gl_huang}${#target_repos[@]}${gl_bai}"
    echo -e "本次新增目录: ${gl_lv}$processed_count${gl_bai}"
    echo -e "跳过(已存在): ${gl_lv}$skipped_count${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if $INTERACTIVE_MODE; then
        echo -e "${gl_bai}当前所有全局安全目录列表：${gl_bai}"
        git config --global --get-all safe.directory 2>/dev/null | sort -u | while read -r sdir; do
            echo -e "  ${gl_lv}•${gl_bai} $sdir"
        done
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -n 1 -s -r -p "$(echo -e "按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}")"
        echo
    fi

    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -gt 0 ]]; then
        fix_git_safe_directories "$@"
    else
        fix_git_safe_directories
    fi
fi
