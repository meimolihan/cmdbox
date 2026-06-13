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

exit_animation() {
    echo -ne "${gl_lv}即将退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
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

cancel_return() {
    local menu_name="${1:-上一级选单}"
    echo -e "${gl_lv}即将返回到 ${gl_huang}${menu_name}${gl_lv} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    sleep_fractional 0.6
    echo ""
    clear
}

break_end() {
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n 1 -s -r -p ""
    echo ""
    clear
}

safe_read() {
    local prompt="$1"
    local var_name="$2"
    local type="${3:-"string"}"
    local default_value="${4:-}"
    local min_value="${5:-}"
    local max_value="${6:-}"
    local max_retry=3
    local retry_count=0
    
    while [[ $retry_count -lt $max_retry ]]; do
        if [[ -n "$default_value" ]]; then
            read -r -e -p "$(echo -e "${gl_bai}$prompt (${gl_huang}默认: $default_value${gl_bai}): ")" "$var_name"
            [[ -z "${!var_name}" ]] && eval "$var_name=\"\$default_value\""
        else
            read -r -e -p "$(echo -e "${gl_bai}$prompt: ")" "$var_name"
        fi
        
        if [[ -z "${!var_name}" ]]; then
            if [[ -n "$default_value" ]]; then
                eval "$var_name=\"\$default_value\""
                return 0
            else
                log_error "输入不能为空"
                retry_count=$((retry_count + 1))
                continue
            fi
        fi
        
        case "$type" in
            "number")
                if ! [[ "${!var_name}" =~ ^[0-9]+$ ]]; then
                    log_error "请输入数字"
                    retry_count=$((retry_count + 1))
                    continue
                fi
                
                if [[ -n "$min_value" ]] && [[ "${!var_name}" -lt "$min_value" ]]; then
                    log_error "输入值不能小于 $min_value"
                    retry_count=$((retry_count + 1))
                    continue
                fi
                
                if [[ -n "$max_value" ]] && [[ "${!var_name}" -gt "$max_value" ]]; then
                    log_error "输入值不能大于 $max_value"
                    retry_count=$((retry_count + 1))
                    continue
                fi
                ;;
            "y/n")
                if ! [[ "${!var_name}" =~ ^[YyNn]$ ]]; then
                    log_error "请输入 y 或 n"
                    retry_count=$((retry_count + 1))
                    continue
                fi
                ;;
        esac
        
        return 0
    done
    
    log_error "输入尝试次数过多，返回上一级"
    return 1
}

handle_invalid_input() {
    echo -ne "\r${gl_hong}无效的输入，请重新输入 ${gl_zi} 2 ${gl_hong}秒后返回 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.3
    echo -ne "\r${gl_huang}无效的输入，请重新输入 ${gl_zi} 1 ${gl_huang}秒后返回 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.3
    echo -e "\r${gl_lv}无效的输入，请重新输入 ${gl_zi} 0 ${gl_lv}秒后返回 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    return 2
}

column_if_available() {
    if command -v column &> /dev/null; then
        column -t -s $'\t'
    else
        cat
    fi
}

docker-ps-find() {
    {
        local filters=("$@")

        printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "容器ID" "名称" "状态" "端口" "创建时间" "镜像" "$reset"
        printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "----------" "----------" "----------" "----------" "----------" "----------" "$reset"

        docker ps --format "{{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.RunningFor}}\t{{.Image}}" | \
        
        if [ $# -gt 0 ]; then
            awk -v filters="${filters[*]}" '
            BEGIN {
                split(filters, arr, " ")
                for (i in arr) pattern[arr[i]] = 1
            }
            {
                for (p in pattern) {
                    if ($2 ~ p) {
                        print
                        next
                    }
                }
            }'
        else
            cat
        fi | \

        awk -v green="$gl_lv" -v red="$gl_hong" -v yellow="$gl_huang" -v cyan="$gl_bufan" -v blue="$gl_lan" -v white="$gl_bai" -v reset="$reset" '
        BEGIN {FS="\t"; OFS="\t"}
        {
            id = substr($1, 1, 12)
            name = $2
            status = $3
            ports = $4
            time = $5
            image = $6

            gsub(/healthy/, "健康", status)
            gsub(/unhealthy/, "不健康", status)
            gsub(/starting/, "启动中", status)
            gsub(/Up /, "已运行 ", status)
            gsub(/days/, "天", status)
            gsub(/hours/, "小时", status)
            gsub(/minutes/, "分钟", status)
            gsub(/seconds/, "秒", status)

            if (status !~ /健康|不健康|启动中/) {
                status = status " (正常)"
            }

            gsub(/[0-9]+/, green "&" reset, status)

            gsub(/健康/, green "&" reset, status)
            gsub(/不健康/, red "&" reset, status)
            gsub(/启动中/, yellow "&" reset, status)
            gsub(/正常/, blue "&" reset, status)

            gsub(/ years ago/, "年前", time)
            gsub(/ year ago/, "年前", time)
            gsub(/ months ago/, "个月前", time)
            gsub(/ month ago/, "个月前", time)
            gsub(/ weeks ago/, "周前", time)
            gsub(/ week ago/, "周前", time)
            gsub(/ days ago/, "天前", time)
            gsub(/ day ago/, "天前", time)
            gsub(/ hours ago/, "小时前", time)
            gsub(/ hour ago/, "小时前", time)
            gsub(/ minutes ago/, "分钟前", time)
            gsub(/ minute ago/, "分钟前", time)
            gsub(/ seconds ago/, "秒前", time)
            gsub(/About /, "", time)
            
            gsub(/[0-9]+/, green "&" reset, time)

            print cyan id reset, green name reset, yellow status reset, blue ports reset, white time reset, white image reset
        }'
    } | column_if_available
}

get_internal_ip() {
	local ip=""
	if command -v hostname >/dev/null 2>&1; then
		ip=$(hostname -I | awk '{print $1}')
	elif command -v ip >/dev/null 2>&1; then
		ip=$(ip route get 1 2>/dev/null | awk '{print $7}' | head -1)
	elif command -v ifconfig >/dev/null 2>&1; then
		ip=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -1)
	fi
	echo "$ip"
}

show_inner_url() {
    local yml="docker-compose.yml"
    [[ -f $yml ]] || {
        echo -e "当前目录没有 $yml"
        return 1
    }

    local port
    port=$(awk '
    match($0, /-[[:space:]]*"?([0-9]+):[0-9]+/) {
      split(substr($0, RSTART, RLENGTH), a, /:/);
      gsub(/[^0-9]/, "", a[1]);
      print a[1]; exit
    }' "$yml")

    [[ -z $port ]] && {
        echo -e "服务访问链接：未检测到 http 端口映射"
        return 2
    }

    local ip=$(hostname -I | awk '{print $1}')
    echo -e "${gl_bai}服务访问链接：${gl_lv}http://${ip}:${port}${gl_bai}"
}

check_container_status() {
    local container_name="$1"
    if docker inspect "$container_name" &>/dev/null; then
        if docker inspect -f '{{.State.Running}}' "$container_name" 2>/dev/null | grep -q "true"; then
            echo "${gl_lv}"
        else
            echo "${gl_hong}"
        fi
    else
        echo "${gl_hui}"
    fi
}

create_file() {
    local file_name=${1:-}

    echo -e ""
    echo -e "${gl_zi}>>> 创建文件${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if [[ -z $file_name ]]; then
        read -r -e -p "$(echo -e "${gl_bai}请输入文件名(${gl_huang}0${gl_bai}返回): ")" file_name || return
        [[ -z "$file_name" ]] && { cancel_empty "上一级选单"; return 1; }
        [[ "$file_name" == "0" ]] && { cancel_return "上一级选单"; return 1; }
    fi

    if [[ -e $file_name ]]; then
        echo -e "${gl_hong}文件已存在：$file_name${gl_bai}"
        local overwrite
        read -r -e -p "$(echo -e "${gl_bai}是否覆盖？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}，${gl_huang}0${gl_bai}返回): ")" overwrite || return
        [[ "$overwrite" == "0" ]] && { cancel_return "上一级选单"; return 1; }
        [[ "$overwrite" != [yY] ]] && { echo -e "${gl_huang}已取消操作 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"; sleep_fractional 0.6; return; }
    fi

    echo -e "${gl_huang}将创建文件：$file_name${gl_bai}"
    echo -e "${gl_bufan}按回车键开始用 nano 编辑文件(${gl_huang}Ctrl+X${gl_bai}退出nano)${gl_bai}"
    read -r -n 1 -s

    local tmp line_count=0
    tmp=$(mktemp)

    if nano "$tmp"; then
        if [[ -s $tmp ]]; then
            line_count=$(wc -l < "$tmp" 2>/dev/null || echo 0)
            mv "$tmp" "$file_name"
            echo -e "${gl_huang}文件创建成功，共写入 $line_count 行${gl_bai}"
            [[ -s $file_name ]] && cat -n "$file_name"
        else
            touch "$file_name"
            echo -e "${gl_bufan}创建空文件完成${gl_bai}"
        fi
    else
        echo -e "${gl_hong}nano 编辑失败或已取消${gl_bai}"
        rm -f "$tmp"
        return
    fi

    if [[ $file_name =~ \.(sh|py|pl)$ ]]; then
        local add_exec
        echo -e ""
        read -r -e -p "$(echo -e "${gl_bai}检测到脚本文件，是否添加执行权限？ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}，${gl_huang}0${gl_bai}返回): ")" add_exec || return
        [[ "$add_exec" == "0" ]] && { echo -e "${gl_huang}已跳过权限设置${gl_bai}"; }
        [[ "$add_exec" == [yY] ]] && chmod +x "$file_name"
        new_oct=$(stat -c "%a" "$file_name")
        new_sym=$(stat -c "%A" "$file_name")
        echo -e ""
        log_ok "权限已修改！"
        echo -e ""
        echo -e "${gl_bai}修改后 ${gl_huang}${file_name}${gl_bai} 权限: ${gl_lv}${new_sym}${gl_bai}  (${gl_huang}${new_oct}${gl_bai})"
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
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
            echo -e "${gl_huang}${pkg}${gl_bai} ${gl_lv}已安装${gl_bai}" \
                "$([[ -n "$ver" ]] && echo "版本 ${gl_lv}${ver}${gl_bai}")"
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

get_main_service() {
    local compose_file="${1:-docker-compose.yml}"
    local service_name=""
    
    if [[ ! -f "$compose_file" ]]; then
        compose_file="docker-compose.yaml"
    fi
    
    if [[ ! -f "$compose_file" ]]; then
        echo ""
        return
    fi
    
    if command -v yq &>/dev/null; then
        service_name=$(yq e '.services | keys | .[0]' "$compose_file" 2>/dev/null)
    elif command -v docker-compose &>/dev/null; then
        service_name=$(docker-compose config --services 2>/dev/null | head -1)
    elif docker compose version &>/dev/null; then
        service_name=$(docker compose config --services 2>/dev/null | head -1)
    else
        service_name=$(grep -A 5 "^services:" "$compose_file" | grep -E "^  [a-zA-Z0-9_-]+:" | head -1 | tr -d ': ' 2>/dev/null)
    fi
    
    if [[ -z "$service_name" ]]; then
        service_name=$(basename "$(pwd)")
    fi
    
    echo "$service_name"
}

select_service() {
    local compose_file="${1:-docker-compose.yml}"
    local services=()
    
    if [[ ! -f "$compose_file" ]]; then
        compose_file="docker-compose.yaml"
    fi
    
    if [[ ! -f "$compose_file" ]]; then
        echo ""
        return
    fi
    
    if command -v yq &>/dev/null; then
        mapfile -t services < <(yq e '.services | keys | .[]' "$compose_file" 2>/dev/null)
    elif command -v docker-compose &>/dev/null; then
        mapfile -t services < <(docker-compose config --services 2>/dev/null)
    elif docker compose version &>/dev/null; then
        mapfile -t services < <(docker compose config --services 2>/dev/null)
    else
        mapfile -t services < <(grep -A 20 "^services:" "$compose_file" | grep -E "^  [a-zA-Z0-9_-]+:" | tr -d ': ' 2>/dev/null)
    fi
    
    if [[ ${#services[@]} -eq 0 ]]; then
        echo ""
        return
    fi
    
    if [[ ${#services[@]} -eq 1 ]]; then
        echo "${services[0]}"
        return
    fi
    
    clear
    echo -e ""
    echo -e "${gl_zi}>>> 选择服务${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}检测到多个服务，请选择要操作的服务：${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    for i in "${!services[@]}"; do
        local service="${services[$i]}"
        local container_color=$(check_container_status "$service")
        local status_text=""
        
        if [[ "$container_color" == "${gl_lv}" ]]; then
            status_text="${gl_lv}[运行中]${gl_bai}"
        elif [[ "$container_color" == "${gl_hong}" ]]; then
            status_text="${gl_hong}[已停止]${gl_bai}"
        else
            status_text="${gl_hui}[不存在]${gl_bai}"
        fi
        
        echo -e "${gl_bufan}$((i + 1)). ${gl_bai}${container_color}$service${gl_bai} $status_text"
    done
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_huang}0. ${gl_bai}返回上一级选单"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    read -r -e -p "$(echo -e "${gl_bai}请输入你的选择 (${gl_huang}0${gl_bai}-${gl_hong}${#services[@]}${gl_bai}): ")" service_choice
    
    if [[ "$service_choice" =~ ^[0-9]+$ ]]; then
        if [[ $service_choice -eq 0 ]]; then
            echo ""
            return
        elif [[ $service_choice -le ${#services[@]} ]]; then
            echo "${services[$((service_choice - 1))]}"
            return
        fi
    fi
    
    echo ""
}

show_compose_commands_menu() {
    local WORK_DIR="${1:-.}"
    
    if ! cd "$WORK_DIR" 2>/dev/null; then
        log_error "无法进入目录: $WORK_DIR"
        exit_animation
        return 1
    fi
    
    local current_dir="$(pwd)"
    local current_dir_name=$(basename "$PWD")
    
    local MAIN_SERVICE=$(get_main_service)
    [[ -z "$MAIN_SERVICE" ]] && MAIN_SERVICE="$current_dir_name"
    
    while true; do
        clear
        echo -e ""
        echo -e "${gl_zi}>>> Compose项目菜单${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bai}当前工作目录: ${gl_huang}$current_dir${gl_bai}"
        echo -e "${gl_bai}当前项目名称: ${gl_huang}$current_dir_name${gl_bai}"
        echo -e "${gl_bai}主要服务名称: ${gl_huang}$MAIN_SERVICE${gl_bai}"
        echo -e "${gl_bai}内网 IP 地址: ${gl_huang}$(get_internal_ip)${gl_bai}"

        docker inspect -f \
            '{{if .State.Running}}'"$gl_lv"'已启动'"$gl_bai"'{{else}}'"$gl_hui"'已停止'"$gl_bai"'{{end}}' \
            "$MAIN_SERVICE" >/dev/null 2>&1 && {
            echo -e "${gl_bai}主要容器状态：$(docker inspect -f \
                '{{if .State.Running}}'"$gl_lv"'已启动'"$gl_bai"'{{else}}'"$gl_hui"'已停止'"$gl_bai"'{{end}}' \
                "$MAIN_SERVICE")"
        } || {
            printf "${gl_bai}主要容器状态：${gl_hui}容器 ${gl_huang}%s${gl_hui} 不存在${gl_bai}\n" "$MAIN_SERVICE"
        }

        show_inner_url

        local container_color=$(check_container_status "$MAIN_SERVICE")
        
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        docker-ps-find "$current_dir_name"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}启动${container_color}$current_dir_name${gl_bai}服务      ${gl_bufan}2.  ${gl_bai}停止${container_color}$current_dir_name${gl_bai}服务"
        echo -e "${gl_bufan}3.  ${gl_bai}重启${container_color}$current_dir_name${gl_bai}服务      ${gl_bufan}4.  ${gl_bai}更新${container_color}$current_dir_name${gl_bai}容器"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}5.  ${gl_bai}查看${container_color}$current_dir_name${gl_bai}配置      ${gl_bufan}6.  ${gl_bai}编辑${container_color}$current_dir_name${gl_bai}配置"
        echo -e "${gl_bufan}7.  ${container_color}$current_dir_name${gl_bai}服务状态      ${gl_bufan}8.  ${container_color}$current_dir_name${gl_bai}服务日志"
        echo -e "${gl_bufan}9.  ${gl_hong}停止并清理${container_color}$current_dir_name${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}11. ${gl_bai}查看${container_color}$current_dir_name${gl_bai}最终配置  ${gl_bufan}12. ${gl_bai}打印${container_color}$current_dir_name${gl_bai}服务依赖拓扑图"
        echo -e "${gl_bufan}13. ${gl_bai}查看${container_color}$current_dir_name${gl_bai}资源占用  ${gl_bufan}14. ${gl_bai}仅拉取${container_color}$current_dir_name${gl_bai}镜像（不启动）"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}21. ${gl_bai}创建${container_color}$current_dir_name${gl_bai}配置文件"
        echo -e "${gl_bufan}23. ${gl_bai}开放${container_color}$current_dir_name${gl_bai}访问端口  ${gl_bufan}24. ${gl_bai}重新构建${container_color}$current_dir_name${gl_bai}"
        echo -e "${gl_bufan}25. ${gl_bai}进入${container_color}$MAIN_SERVICE${gl_bai}服务      ${gl_bufan}26. ${gl_bai}修改${container_color}$MAIN_SERVICE${gl_bai}重启策略"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_hong}0.  ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" cmd_choice

        case $cmd_choice in
        1)
            echo -e ""
            echo -e "正在启动 ${gl_huang}$current_dir_name${gl_bai} 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker-compose up -d --remove-orphans
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        2)
            echo -e ""
            echo -e "${gl_bai}正在停止并删除 ${gl_huang}$current_dir_name${gl_bai} 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker-compose down
            echo -e "\n"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        3)
            echo -e ""
            echo -e "${gl_bai}正在重启 ${gl_huang}$current_dir_name${gl_bai} 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker-compose down && docker-compose up -d --remove-orphans
            echo -e "\n"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        4)
            echo -e ""
            echo -e "${gl_bai}正在更新 ${gl_huang}$current_dir_name${gl_bai} 容器 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker-compose pull && docker-compose up -d --remove-orphans && docker image prune -f
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        5)
            echo -e ""
            echo -e "${gl_bai}正在显示 ${gl_huang}$current_dir_name${gl_bai} 配置文件内容 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            if [ -f "docker-compose.yml" ]; then
                cat docker-compose.yml | sed '/^$/d'
            else
                echo -e "${gl_hong}错误: docker-compose.yml 文件不存在${gl_bai}"
            fi
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        6)
            echo -e ""
            echo -e "${gl_bai}正在打开 ${gl_huang}$current_dir_name${gl_bai} 配置文件编辑器 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            if [ -f "docker-compose.yml" ]; then
                nano docker-compose.yml
            else
                echo -e "${gl_hong}错误: docker-compose.yml 文件不存在${gl_bai}"
                read -r -e -p "$(echo -e "${gl_bai}docker-compose.yml 不存在，要创建吗？ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" create_choice
                if [[ "$create_choice" =~ ^[Yy]$ ]]; then
                    echo -e "${gl_lv}正在创建 docker-compose.yml ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                    create_file docker-compose.yml
                else
                    echo -e "${gl_huang}已取消创建${gl_bai}"
                fi
            fi
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        7)
            echo -e ""
            echo -e "${gl_bai}正在显示 ${gl_huang}$current_dir_name${gl_bai} 服务状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker-compose ps
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        8)
            echo -e ""
            echo -e "${gl_bai}正在显示 ${gl_huang}$current_dir_name${gl_bai} 服务日志 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker-compose logs
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        9)
            echo -e ""
            echo -e "${gl_bai}正在停止并删除 ${gl_huang}$current_dir_name${gl_bai} 服务及相关资源 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_hong}⚠️  警告: 此操作将删除容器、网络和卷！${gl_bai}"
            echo -e "${gl_bai}数据卷不会被删除，但网络和相关资源将被清理${gl_bai}"
            echo -e ""
            read -r -e -p "$(echo -e "${gl_bai}确认执行？ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                docker-compose down --volumes --remove-orphans && docker system prune -af --volumes
                echo -e ""
                echo -e "${gl_lv}✓ 服务、网络和卷已清理完成${gl_bai}"
            else
                echo -e "${gl_huang}已取消操作${gl_bai}"
            fi
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        11)
            echo -e ""
            echo -e "${gl_bai}正在查看 ${gl_huang}$current_dir_name${gl_bai} 服务最终生效配置 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker-compose config
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        12)
            echo
            echo -e "${gl_bai}正在打印 ${gl_huang}$current_dir_name${gl_bai} 服务依赖拓扑图 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker-compose images
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        13)
            echo
            echo -e "${gl_huang}$current_dir_name${gl_bai}服务列表 & 实时资源占用（Ctrl-C 退出）"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            bash <(curl -sL gitee.com/meimolihan/cmdbox/raw/master/sh/docker_occupy_find.sh) $current_dir_name
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            ;;
        14)
            echo
            echo -e "${gl_bai}仅拉取${gl_huang}$current_dir_name${gl_bai}镜像（不启动）"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker-compose pull
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        21)
            echo
            echo -e "${gl_bai}正在创建${gl_huang}$current_dir_name${gl_bai}配置文件"
            create_file docker-compose.yml
            ;;
        23)
            echo -e ""
            echo -e "${gl_zi}>>> 开放$current_dir_name访问端口${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

            default_port=$(
                awk '
                match($0, /-[[:space:]]*([0-9]+):[0-9]+/) {
                print substr($0, RSTART+1, RLENGTH-1) + 0;
                exit
                }
            ' docker-compose.yml 2>/dev/null
            )
            
            [[ -z $default_port ]] && default_port=""

            if [[ -n "$default_port" ]]; then
                echo -e "${gl_bai}默认端口: ${gl_lv}${default_port}${gl_bai} (直接回车使用此端口)"
                read -r -e -p "$(echo -e "${gl_bai}请输入要放行的端口号 (${gl_huang}0${gl_bai}返回): ")" port
                [[ -z "$port" ]] && port="$default_port"
            else
                read -r -e -p "$(echo -e "${gl_bai}请输入要放行的端口号 (${gl_huang}0${gl_bai}返回): ")" port
            fi

            [ "$port" == "0" ] && { cancel_return "上一级选单"; continue; }

            if [[ $port =~ ^[0-9]+$ && $port -ge 1 && $port -le 65535 ]]; then
                iptables -A INPUT -p tcp --dport "$port" -j ACCEPT
                echo -e ""
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                log_ok "已放行 TCP 端口 $port"
            else
                echo -e ""
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                log_error "端口号非法，已跳过"
            fi
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        24)
            echo -e ""
            echo -e "${gl_bai}正在重新构建 ${gl_huang}$current_dir_name${gl_bai} 并启动服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker-compose up -d --build
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        25)
            local TARGET_SERVICE="$MAIN_SERVICE"
            if [[ -f "docker-compose.yml" ]] || [[ -f "docker-compose.yaml" ]]; then
                local selected_service=$(select_service)
                [[ -n "$selected_service" ]] && TARGET_SERVICE="$selected_service"
            fi
            
            if [[ -z "$TARGET_SERVICE" ]]; then
                echo -e "${gl_hong}未找到可进入的服务${gl_bai}"
                break_end
                continue
            fi
            
            echo -e ""
            echo -e "${gl_bai}进入 ${gl_huang}$TARGET_SERVICE${gl_bai} 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            
            if ! docker inspect "$TARGET_SERVICE" &>/dev/null; then
                echo -e "${gl_hong}容器 $TARGET_SERVICE 不存在${gl_bai}"
                read -r -e -p "$(echo -e "${gl_bai}是否启动容器？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" start_choice
                if [[ "$start_choice" =~ ^[Yy]$ ]]; then
                    docker-compose up -d "$TARGET_SERVICE"
                    sleep 2
                else
                    break_end
                    continue
                fi
            fi
            
            if ! docker inspect -f '{{.State.Running}}' "$TARGET_SERVICE" 2>/dev/null | grep -q "true"; then
                echo -e "${gl_hong}容器 $TARGET_SERVICE 未运行${gl_bai}"
                read -r -e -p "$(echo -e "${gl_bai}是否启动容器？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" start_choice
                if [[ "$start_choice" =~ ^[Yy]$ ]]; then
                    docker-compose up -d "$TARGET_SERVICE"
                    sleep 2
                else
                    break_end
                    continue
                fi
            fi
            
            if ! docker exec -it "$TARGET_SERVICE" bash 2>/dev/null; then
                echo -e "${gl_hong}bash 不可用，尝试使用 sh ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                docker exec -it "$TARGET_SERVICE" sh
            fi
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        26)
            local TARGET_SERVICE="$MAIN_SERVICE"
            if [[ -f "docker-compose.yml" ]] || [[ -f "docker-compose.yaml" ]]; then
                local selected_service=$(select_service)
                [[ -n "$selected_service" ]] && TARGET_SERVICE="$selected_service"
            fi
            
            if [[ -z "$TARGET_SERVICE" ]]; then
                echo -e "${gl_hong}未找到可修改的服务${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
                continue
            fi
            
            install yq
            clear
            echo -e ""
            echo -e "${gl_zi}>>> 永久修改重启策略 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

            if [ ! -f "docker-compose.yml" ] && [ ! -f "docker-compose.yaml" ]; then
                echo -e "${gl_hong}❌ 未找到 docker-compose.yml 文件${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
                continue
            fi

            compose_file="docker-compose.yml"
            if [ ! -f "$compose_file" ]; then
                compose_file="docker-compose.yaml"
            fi

            echo -e "${gl_bai}配置文件: ${gl_huang}$compose_file${gl_bai}"
            echo -e "${gl_bai}目标服务: ${gl_huang}$TARGET_SERVICE${gl_bai}"
            echo -e ""

            echo -e "${gl_huang}当前配置:${gl_bai}"

            if command -v yq &>/dev/null; then
                yq e ".services.$TARGET_SERVICE" "$compose_file" 2>/dev/null || {
                    echo -e "${gl_bai}使用grep过滤注释行:${gl_bai}"
                    grep -A 20 "^\s*$TARGET_SERVICE:" "$compose_file" | grep -v "^\s*#" | head -15
                }
            else
                echo -e "${gl_bai}服务 $TARGET_SERVICE 的配置:${gl_bai}"
                grep -A 20 "^\s*$TARGET_SERVICE:" "$compose_file" | grep -v "^\s*#" | head -15
            fi

            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e ""

            current_restart=$(grep -A 10 "^\s*$TARGET_SERVICE:" "$compose_file" | grep "^\s*restart:" | head -1 | sed 's/^\s*restart:\s*//' || echo "未设置")
            echo -e "${gl_bai}当前重启策略: ${gl_lv}${current_restart:-未设置}${gl_bai}"

            echo -e "${gl_huang}>>> 请选择重启策略:${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_bufan}1.  ${gl_lv}no${gl_bai} - 不自动重启 (默认)"
            echo -e "${gl_bufan}2.  ${gl_lv}always${gl_bai} - 总是重启"
            echo -e "${gl_bufan}3.  ${gl_lv}on-failure${gl_bai} - 失败时重启"
            echo -e "${gl_bufan}4.  ${gl_lv}unless-stopped${gl_bai} - 除非手动停止，否则总是重启"
            echo -e "${gl_bufan}5.  ${gl_huang}自定义策略 (如: on-failure:3)${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单"
            echo -e "${gl_hong}00. ${gl_bai}退出脚本"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

            read -p "请输入选择 [0-5]: " policy_choice

            case $policy_choice in
            1) new_policy="no" ;;
            2) new_policy="always" ;;
            3) new_policy="on-failure" ;;
            4) new_policy="unless-stopped" ;;
            5)
                read -r -e -p "$(echo -e "${gl_bai}请输入自定义策略${gl_huang}on-failure:3${gl_bai}(${gl_huang}0${gl_bai}返回): ")" new_policy
                [ "$new_policy" == "0" ] && { cancel_return "上一级选单"; continue; }
                ;;
            0) cancel_return; continue ;;
            00|000|0000) exit_script ;;
            *) handle_invalid_input ;;
            esac

            echo -e ""
            if grep -q "^\s*restart:" "$compose_file"; then
                if sed -i "s/^\(\s*\)restart:.*/\1restart: $new_policy/" "$compose_file"; then
                    echo -e "${gl_lv}✓ 已更新重启策略${gl_bai}"
                else
                    echo -e "${gl_hong}✗ 更新重启策略失败${gl_bai}"
                fi
            else
                if grep -q "^\s*$TARGET_SERVICE:" "$compose_file"; then
                    line_num=$(grep -n "^\s*$TARGET_SERVICE:" "$compose_file" | head -1 | cut -d: -f1)
                    if [ -n "$line_num" ]; then
                        sed -i "${line_num}a\ \ \ \ restart: $new_policy" "$compose_file"
                        echo -e "${gl_lv}✓ 已添加重启策略${gl_bai}"
                    else
                        echo -e "${gl_hong}✗ 未找到 $TARGET_SERVICE 服务定义${gl_bai}"
                    fi
                else
                    echo -e "${gl_hong}✗ 未找到 $TARGET_SERVICE 服务定义${gl_bai}"
                fi
            fi

            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

            echo -e "${gl_huang}修改后的配置:${gl_bai}"
            if command -v yq &>/dev/null; then
                yq e ".services.$TARGET_SERVICE" "$compose_file" 2>/dev/null || {
                    echo -e "${gl_bai}使用grep显示修改后的配置:${gl_bai}"
                    grep -A 20 "^\s*$TARGET_SERVICE:" "$compose_file" | grep -v "^\s*#" | head -20
                }
            else
                echo -e "${gl_bai}服务 $TARGET_SERVICE 的配置:${gl_bai}"
                grep -A 20 "^\s*$TARGET_SERVICE:" "$compose_file" | grep -v "^\s*#" | head -20
            fi

            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

            if docker inspect "$TARGET_SERVICE" >/dev/null 2>&1; then
                echo -e ""
                echo -e "${gl_huang}检测到容器 $TARGET_SERVICE 正在运行${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                read -r -e -p "$(echo -e "${gl_bai}是否立即更新容器的重启策略？ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" update_now

                if [[ "$update_now" =~ ^[Yy]$ ]]; then
                    echo -e "${gl_bai}更新容器重启策略 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                    if docker update --restart="$new_policy" "$TARGET_SERVICE" >/dev/null 2>&1; then
                        echo -e "${gl_lv}✓ 容器重启策略已更新${gl_bai}"
                    else
                        echo -e "${gl_hong}✗ 容器重启策略更新失败${gl_bai}"
                    fi
                else
                    echo -e "${gl_huang}注意: 配置文件已修改，但容器重启策略未更新${gl_bai}"
                    echo -e "${gl_bai}如需应用到容器，请手动执行:${gl_bai}"
                    echo -e "${gl_lv}docker update --restart=$new_policy $TARGET_SERVICE${gl_bai}"
                fi

                echo -e ""
                echo -e "${gl_huang}是否重新创建容器以应用配置？${gl_bai}"
                echo -e "${gl_bai}重新创建容器会停止并重新启动容器，但会保留数据卷${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                read -r -e -p "$(echo -e "输入 ${gl_bufan}y${gl_bai} 重新创建，其他键跳过:")" recreate_choice

                if [ "$recreate_choice" = "y" ] || [ "$recreate_choice" = "Y" ]; then
                    echo -e "${gl_bai}重新创建容器 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                    if command -v docker-compose &>/dev/null; then
                        docker-compose down && docker-compose up -d
                    elif command -v docker &>/dev/null && docker compose version &>/dev/null; then
                        docker compose down && docker compose up -d
                    else
                        echo -e "${gl_hong}未找到 docker-compose 或 docker compose 命令${gl_bai}"
                    fi
                    echo -e "${gl_lv}✓ 容器已重新创建${gl_bai}"
                else
                    echo -e "${gl_huang}注意: 需要重新创建容器以使配置文件完全生效${gl_bai}"
                    echo -e "${gl_bai}手动执行: ${gl_lv}docker-compose down && docker-compose up -d${gl_bai}"
                fi
            else
                echo -e "${gl_huang}容器 $TARGET_SERVICE 未运行${gl_bai}"
                echo -e "${gl_bai}下次启动容器时会应用新的重启策略${gl_bai}"
            fi

            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        0) exit_script ;;
        *) handle_invalid_input ;;
        esac
    done
}

show_help() {
    echo -e "${gl_lv}使用说明:${gl_bai}"
    echo -e "  ${gl_bai}$0 ${gl_lan}[项目目录]${gl_bai}"
    echo -e ""
    echo -e "${gl_lv}参数:${gl_bai}"
    echo -e "  ${gl_lan}[项目目录]${gl_bai}  Docker Compose 项目目录路径"
    echo -e ""
    echo -e "${gl_lv}示例:${gl_bai}"
    echo -e "  ${gl_bai}$0 ${gl_lan}/compose/myapp${gl_bai}    # 管理指定目录的 Compose 项目"
    echo -e "  ${gl_bai}$0${gl_bai}                       # 管理当前目录的 Compose 项目"
    echo -e "  ${gl_bai}$0 ${gl_lan}-h${gl_bai}             # 显示帮助信息"
    echo -e ""
    exit 0
}


check_docker() {
    if ! docker info &>/dev/null; then
        log_error "Docker 服务未运行"
        exit 1
    fi
    
    if ! command -v docker-compose &>/dev/null && ! docker compose version &>/dev/null; then
        log_error "未找到 docker-compose 命令"
        echo -e "${gl_bai}请安装 docker-compose 或使用 docker compose${gl_bai}"
        exit 1
    fi
}

main() {
    local WORK_DIR="."
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                ;;
            *)
                WORK_DIR="$1"
                shift
                ;;
        esac
    done
    
    check_docker
    
    if [[ ! -d "$WORK_DIR" ]]; then
        log_error "目录不存在: $WORK_DIR"
        exit 1
    fi
    
    if [[ ! -f "$WORK_DIR/docker-compose.yml" ]] && [[ ! -f "$WORK_DIR/docker-compose.yaml" ]]; then
        echo -e "${gl_huang}警告: 在 $WORK_DIR 中未找到 docker-compose.yml 文件${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}是否创建新的 docker-compose.yml 文件？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" create_choice
        if [[ "$create_choice" =~ ^[Yy]$ ]]; then
            if ! cd "$WORK_DIR" 2>/dev/null; then
                log_error "无法进入目录: $WORK_DIR"
                exit 1
            fi
            create_file docker-compose.yml
        else
            echo -e "${gl_huang}已取消${gl_bai}"
            exit 0
        fi
    fi
    
    show_compose_commands_menu "$WORK_DIR"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi