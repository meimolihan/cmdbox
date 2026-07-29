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
    if command -v perl >/dev/null 2>&1; then
        perl -e "select(undef, undef, undef, $seconds)"
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c "import time; time.sleep($seconds)"
    elif command -v python >/dev/null 2>&1; then
        python -c "import time; time.sleep($seconds)"
    else
        sleep $(echo "$seconds" | awk '{print int($1+0.999)}')
    fi
}

handle_invalid_input() {
    echo -e "${gl_hong}无效的输入，请重新输入！${gl_bai}"
    sleep_fractional 0.8
}

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n 1 -s -p ""
    echo ""
    clear
}

exit_script() {
    echo -ne "${gl_hong}感谢使用，再见！${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    clear
    exit 0
}

install() {
    [[ $# -eq 0 ]] && {
        log_error "未提供软件包参数!"
        return 1
    }
    declare -A pkg_map=(["7z"]="p7zip" ["7zip"]="p7zip")
    local mgr_order=("apt" "opkg" "apk" "dnf" "yum" "pacman" "zypper" "pkg")
    get_version() {
        local bin="$1"
        local out
        out=$("$bin" --version 2>/dev/null | head -n1 | tr -cd '[:print:]')
        [[ -z "$out" ]] && out=$("$bin" 2>&1)
        echo "$out" | grep -oE '[0-9]+(\.[0-9]+)+' | head -n1
    }
    check_installed() {
        local pkg="$1"
        local real_pkg="${pkg_map[$pkg]:-$pkg}"
        local ver=""
        if command -v "$pkg" &>/dev/null; then
            ver=$(get_version "$pkg")
            echo "true $ver"
            return
        fi
        if command -v opkg &>/dev/null; then
            if opkg list-installed | grep -q "^${real_pkg} "; then
                ver=$(opkg list-installed | grep "^${real_pkg} " | awk '{print $3}' 2>/dev/null)
                echo "true $ver"
                return
            fi
        elif command -v dpkg-query &>/dev/null; then
            if dpkg-query -W -f='${Status}' "$real_pkg" 2>/dev/null | grep -q "install ok installed"; then
                ver=$(dpkg-query -W -f='${Version}' "$real_pkg" 2>/dev/null)
                echo "true $ver"
                return
            fi
        elif command -v rpm &>/dev/null; then
            if rpm -q "$real_pkg" &>/dev/null; then
                ver=$(rpm -q --qf '%{VERSION}' "$real_pkg" 2>/dev/null)
                echo "true $ver"
                return
            fi
        elif command -v apk &>/dev/null; then
            if apk info "$real_pkg" 2>/dev/null | grep -q "^installed"; then
                ver=$(apk info -a "$real_pkg" 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)+' | head -n1)
                echo "true $ver"
                return
            fi
        elif command -v pacman &>/dev/null; then
            if pacman -Qi "$real_pkg" &>/dev/null; then
                ver=$(pacman -Qi "$real_pkg" 2>/dev/null | grep -i "version" | grep -oE '[0-9]+(\.[0-9]+)+' | head -n1)
                echo "true $ver"
                return
            fi
        fi
        echo "false"
    }
    local pkg mgr real_pkg install_success ret installed ver
    for pkg in "$@"; do
        ret=$(check_installed "$pkg")
        installed="${ret% *}"
        ver="${ret#* }"
        if [[ "$installed" == "true" ]]; then
            echo -e "${gl_huang}${pkg}${gl_bai} ${gl_lv}已安装${gl_bai}$([[ $ver != "false" && -n "$ver" ]] && echo " 版本 ${gl_lv}${ver}${gl_bai}")"
            continue
        fi
        real_pkg="${pkg_map[$pkg]:-$pkg}"
        case $mgr in
            apt)
                [[ $pkg == "gzip" || $pkg == "tar" ]] && real_pkg="$pkg"
                ;;
            apk)
                [[ $pkg == "tar" ]] && real_pkg="tar"
                [[ $pkg == "gzip" ]] && real_pkg="gzip"
                ;;
            opkg)
                [[ $pkg == "tar" ]] && real_pkg="tar"
                [[ $pkg == "gzip" ]] && real_pkg="gzip"
                ;;
        esac
        echo ""
        echo -e "${gl_huang}开始安装：${gl_bai}${pkg}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        install_success=false
        for mgr in "${mgr_order[@]}"; do
            command -v "$mgr" &>/dev/null || continue
            case $mgr in
            opkg)
                echo -e "${gl_bai}使用包管理器: ${gl_zi}opkg (OpenWrt/iStoreOS)${gl_bai}"
                opkg update >/dev/null 2>&1 && opkg install "$real_pkg" >/dev/null 2>&1 && install_success=true
                ;;
            dnf)
                echo -e "${gl_bai}使用包管理器: ${gl_zi}dnf (Fedora/RHEL)${gl_bai}"
                dnf -y update >/dev/null 2>&1 && dnf install -y "$real_pkg" >/dev/null 2>&1 && install_success=true
                ;;
            yum)
                echo -e "${gl_bai}使用包管理器: ${gl_zi}yum (CentOS/RHEL)${gl_bai}"
                yum -y update >/dev/null 2>&1 && yum install -y "$real_pkg" >/dev/null 2>&1 && install_success=true
                ;;
            apt)
                echo -e "${gl_bai}使用包管理器: ${gl_zi}apt (Debian/Ubuntu/FnOS)${gl_bai}"
                apt update -y >/dev/null 2>&1 && apt install -y "$real_pkg" >/dev/null 2>&1 && install_success=true
                ;;
            apk)
                echo -e "${gl_bai}使用包管理器: ${gl_zi}apk (Alpine)${gl_bai}"
                apk update >/dev/null 2>&1 && apk add "$real_pkg" >/dev/null 2>&1 && install_success=true
                ;;
            pacman)
                echo -e "${gl_bai}使用包管理器: ${gl_zi}pacman (Arch/Manjaro)${gl_bai}"
                pacman -Syu --noconfirm >/dev/null 2>&1 && pacman -S --noconfirm "$real_pkg" >/dev/null 2>&1 && install_success=true
                ;;
            zypper)
                echo -e "${gl_bai}使用包管理器: ${gl_zi}zypper (openSUSE)${gl_bai}"
                zypper refresh >/dev/null 2>&1 && zypper install -y "$real_pkg" >/dev/null 2>&1 && install_success=true
                ;;
            pkg)
                echo -e "${gl_bai}使用包管理器: ${gl_zi}pkg (FreeBSD)${gl_bai}"
                pkg update >/dev/null 2>&1 && pkg install -y "$real_pkg" >/dev/null 2>&1 && install_success=true
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
    return 0
}

BASE_URL="${1:-}"
TARGET_ROOT="${2:-}"

ask_if_empty() {
    local var_name="$1"
    local prompt="$2"
    local default="${3:-}"

    if [[ -z "${!var_name}" ]]; then
        if [[ -n "$default" ]]; then
            read -r -e -p "$(echo -e "${gl_bai}${prompt}${gl_huang}[$default]${gl_bai}: ")" input
            eval "$var_name=\"${input:-$default}\""
        else
            read -r -e -p "$(echo -e "${gl_bai}${prompt}: ")" input
            eval "$var_name=\"$input\""
        fi
    fi
}

interactive_setup() {
    clear
    echo -e "${gl_zi}>>> 交互式配置【纯远程模式】${gl_bai}"
    echo -e "${gl_bufan}——————————————————————————————————————————————————————————${gl_bai}"

    ask_if_empty BASE_URL      "远程文件服务地址"        "http://10.10.10.251:5000/compose/downloads"
    ask_if_empty TARGET_ROOT   "项目解压根目录"    "/vol1/1000/compose"

    echo ""
    echo -e "${gl_lv}配置完成:${gl_bai}"
    echo -e "远程服务地址 : ${gl_huang}$BASE_URL${gl_bai}"
    echo -e "解压根目录   : ${gl_huang}$TARGET_ROOT${gl_bai}"
    echo ""
    sleep 1
}

if [[ $# -lt 2 ]]; then
    interactive_setup
fi

mkdir -p "$TARGET_ROOT"

TMP_DIR="/tmp/docker_projects_dl_$$"
mkdir -p "$TMP_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT

download_and_extract() {
    local url="$1"
    local dest_dir="$2"
    local filename
    filename=$(basename "$url")

    local tmp_file="$TMP_DIR/$filename"
    rm -f "$tmp_file"

    log_info "下载: $url"

    local dl_ok=0
    if command -v curl >/dev/null 2>&1; then
        curl -L --fail --silent --show-error -o "$tmp_file" "$url" 2>/dev/null && dl_ok=1
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$tmp_file" "$url" 2>/dev/null && dl_ok=1
    else
        log_error "缺少 curl 或 wget，无法下载"
        return 1
    fi

    if [[ "$dl_ok" != "1" ]]; then
        log_error "下载失败: $url"
        return 1
    fi

    if ! gzip -t "$tmp_file" 2>/dev/null; then
        log_error "下载文件非有效gzip压缩包: $filename"
        rm -f "$tmp_file"
        return 1
    fi

    mkdir -p "$dest_dir"
    log_info "解压至: $dest_dir"
    if tar -xzf "$tmp_file" -C "$dest_dir" 2>/dev/null; then
        log_ok "解压完成"
        rm -f "$tmp_file"
        return 0
    else
        log_error "解压失败: $filename"
        rm -f "$tmp_file"
        return 1
    fi
}

declare -A projects

scan_archives() {
    projects=()
    local index=1
    local html

    html=$(curl -s --max-time 3 "$BASE_URL" 2>/dev/null)
    if [[ -z "$html" ]]; then
        log_error "访问远程地址超时/无响应：$BASE_URL"
        return 1
    fi

    mapfile -t tar_files < <(echo "$html" | perl -nle 'print $1 if /href="([^"]+\.tar\.gz)"/' | sort -u)
    if [[ ${#tar_files[@]} -eq 0 ]]; then
        log_error "远程页面未匹配到任何 .tar.gz 项目包"
        return 1
    fi

    log_info "成功读取远程项目列表，共${#tar_files[@]}个项目"
    for f in "${tar_files[@]}"; do
        local name="${f%.tar.gz}"
        projects["$index"]="$name"
        ((index++))
    done
    return 0
}

parse_selection() {
    local input="$1"
    local total="$2"
    local -n out_arr="$3"
    out_arr=()

    local tokens
    read -ra tokens <<< "$input"

    for token in "${tokens[@]}"; do
        if [[ "$token" =~ ^[0-9]+$ ]]; then
            if (( token >= 1 && token <= total )); then
                out_arr+=("$token")
            else
                return 1
            fi
        elif [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            local start="${BASH_REMATCH[1]}"
            local end="${BASH_REMATCH[2]}"
            if (( start < 1 || end > total || start > end )); then
                return 1
            fi
            for ((i=start; i<=end; i++)); do
                out_arr+=("$i")
            done
        else
            return 1
        fi
    done

    if [[ ${#out_arr[@]} -gt 0 ]]; then
        mapfile -t out_arr < <(printf "%s\n" "${out_arr[@]}" | sort -n | uniq)
        return 0
    fi
    return 1
}

IDX_W=0
NAME_W=0
GAP="    "

calc_layout() {
    local max_idx=0
    local max_name=0

    for i in "${!projects[@]}"; do
        (( i > max_idx )) && max_idx=$i
        local n="${projects[$i]}"
        (( ${#n} > max_name )) && max_name=${#n}
    done

    IDX_W=${#max_idx}
    NAME_W=$max_name
}

print_row() {
    local i1=$1
    local i2="${2:-}"

    local fmt_left
    local fmt_right
    fmt_left=$(printf "%%%dd.  %%-%ds" "$IDX_W" "$NAME_W")
    fmt_right=$(printf "%s%%%dd.  %%-%ss" "$GAP" "$IDX_W" "$NAME_W")

    if [[ -n "$i2" ]]; then
        printf "${gl_bufan}${fmt_left}${gl_bai}%s${gl_bufan}${fmt_right}${gl_bai}\n" \
            "$i1" "${projects[$i1]}" \
            "$GAP" \
            "$i2" "${projects[$i2]}"
    else
        printf "${gl_bufan}${fmt_left}${gl_bai}\n" \
            "$i1" "${projects[$i1]}"
    fi
}

batch_download() {
    local -a selected_indices=("$@")
    local ok=0 fail=0 failed_names=()

    echo -e "${gl_huang}开始批量下载（共 ${#selected_indices[@]} 个项目）${gl_bai}"
    echo -e "${gl_bufan}——————————————————————————————————————————————————————————${gl_bai}"

    for idx in "${selected_indices[@]}"; do
        local name="${projects[$idx]}"
        local file="${name}.tar.gz"
        local url="$BASE_URL/$file"

        echo -ne "${gl_huang}[$idx] $name ... ${gl_bai}"
        if download_and_extract "$url" "$TARGET_ROOT" >/dev/null 2>&1; then
            echo -e "${gl_lv}✓ 成功${gl_bai}"
            ((ok++))
        else
            echo -e "${gl_hong}✗ 失败${gl_bai}"
            ((fail++))
            failed_names+=("$name")
        fi
    done

    echo -e "${gl_bufan}——————————————————————————————————————————————————————————${gl_bai}"
    echo -e "批量下载完成: ${gl_lv}成功 $ok${gl_bai}, ${gl_hong}失败 $fail${gl_bai}"

    if [[ ${#failed_names[@]} -gt 0 ]]; then
        echo -e "${gl_hong}失败项目: ${failed_names[*]}${gl_bai}"
    fi
}

main_menu() {
    scan_archives || exit 1
    local total=${#projects[@]}
    calc_layout

    while true; do
        clear
        echo -e "${gl_zi}>>> Compose 纯远程还原工具${gl_bai}"
        echo -e "${gl_bufan}——————————————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bai}远程服务地址 : ${gl_huang}$BASE_URL${gl_bai}"
        echo -e "${gl_bai}解压目标目录 : ${gl_huang}$TARGET_ROOT${gl_bai}"
        echo -e "${gl_bufan}——————————————————————————————————————————————————————————${gl_bai}"

        local i=1
        while (( i <= total )); do
            j=$((i + 1))
            if (( j <= total )); then
                print_row "$i" "$j"
            else
                print_row "$i" ""
            fi
            i=$((i + 2))
        done

        echo -e "${gl_bufan}——————————————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}88. ${gl_bai}自定义URL下载           ${gl_bufan}99. ${gl_bai}下载全部项目${gl_bai}"
        echo -e "${gl_bufan}——————————————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}0.  ${gl_bai}重新配置远程地址        ${gl_hong}00. ${gl_bai}退出脚本${gl_bai}"
        echo -e "${gl_bufan}——————————————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bai}输入规则：单选 1 / 区间 1-5 / 混合多选 1 3-6 10${gl_bai}"
        echo -e "${gl_bufan}——————————————————————————————————————————————————————————${gl_bai}"

        read -r -e -p "$(echo -e "${gl_bai}请输入项目序号: ")" choice

        if [[ -z "$choice" ]]; then
            handle_invalid_input
            continue
        fi

        case "$choice" in
        0)
            interactive_setup
            scan_archives || exit 1
            total=${#projects[@]}
            calc_layout
            ;;
        00) exit_script ;;
        88)
            echo -e "${gl_bufan}——————————————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_bufan}自定义URL下载${gl_bai}"
            echo -e "${gl_bufan}——————————————————————————————————————————————————————————${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bai}输入下载URL(0返回): ")" url
            [[ "$url" == "0" || -z "$url" ]] && continue
            echo -e "${gl_bufan}——————————————————————————————————————————————————————————${gl_bai}"
            if download_and_extract "$url" "$TARGET_ROOT"; then
                log_ok "下载解压成功"
            else
                log_error "下载或解压失败"
            fi
            break_end
            ;;
        99)
            clear
            echo -e "${gl_huang}正在下载全部项目 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}——————————————————————————————————————————————————————————${gl_bai}"
            all_indices=()
            for ((i=1; i<=total; i++)); do
                all_indices+=("$i")
            done
            batch_download "${all_indices[@]}"
            break_end
            ;;
        *)
            selected_indices=()
            if parse_selection "$choice" "$total" selected_indices; then
                if [[ ${#selected_indices[@]} -eq 1 ]]; then
                    idx="${selected_indices[0]}"
                    name="${projects[$idx]}"
                    file="${name}.tar.gz"
                    url="$BASE_URL/$file"
                    echo -e ""
                    echo -e "${gl_huang}处理项目: $name${gl_bai}"
                    echo -e "${gl_bai}下载地址: $url${gl_bai}"
                    echo -e "${gl_bufan}——————————————————————————————————————————————————————————${gl_bai}"
                    if download_and_extract "$url" "$TARGET_ROOT"; then
                        log_ok "$name 还原完成"
                    else
                        log_error "$name 还原失败"
                    fi
                    echo -e "${gl_bufan}——————————————————————————————————————————————————————————${gl_bai}"
                    break_end
                else
                    clear
                    batch_download "${selected_indices[@]}"
                    break_end
                fi
            else
                handle_invalid_input
            fi
            ;;
        esac
    done
}

install curl gzip tar wget

main_menu