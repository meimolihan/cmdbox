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
    local int_seconds=$(awk -v s="$seconds" 'BEGIN{print int(s+0.999)}')
    sleep "$int_seconds"
}

exit_animation() {
    echo -ne "\r${gl_lv}即将退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo ""
}

cancel_empty() {
    local menu_name="${1:-上一级选单}"
    echo -e "${gl_hong}空输入，返回 ${gl_huang}${menu_name} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo ""
    clear
}

cancel_return() {
    local menu_name="${1:-上一级选单}"
    echo -ne "${gl_lv}即将返回 ${gl_huang}${menu_name} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo ""
    clear
}

column_if_available() {
    if command -v column &> /dev/null; then
        column -t -s $'\t'
    else
        cat
    fi
}

list_beautify_docker_system() {
    {
        docker system df | awk -v gray="$gl_hui" -v green="$gl_lv" -v yellow="$gl_huang" \
            -v blue="$gl_lan" -v cyan="$gl_bufan" -v reset="$reset" '
        BEGIN {
            print gray "类型\t总数\t活跃\t大小\t可回收" reset
            print gray "----------\t--------\t--------\t----------\t----------" reset
        }
        NR > 1 {
            type = $1
            total = $2
            active = $3
            size = $4
            reclaim = $5
            if (type == "Local") {
                type = $1 " " $2
                total = $3
                active = $4
                size = $5
                reclaim = $6
            }
            if (type == "Images") color = green
            else if (type == "Containers") color = yellow
            else if (type == "Local Volumes") color = blue
            else if (type == "Build Cache") color = cyan
            else color = reset
            print color type "\t" total "\t" active "\t" size "\t" reclaim reset
        }' | column_if_available
    }
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

exit_script() {
    echo ""
    echo -ne "${gl_hong}感谢使用，再见！ ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
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

column_if_available() {
    if command -v column &> /dev/null; then
        column -t -s $'\t'
    else
        cat
    fi
}

list_beautify_iptables_all() {
    {
        if ! iptables -L -n --line-numbers &>/dev/null; then
            echo -e "${gl_hong}错误: 需要 root 权限运行 iptables${reset}"
            return 1
        fi
        
        output=$(iptables -L -n --line-numbers 2>/dev/null)
        if [ -z "$output" ]; then
            echo -e "${gl_huang}iptables 规则为空${reset}"
            return 0
        fi
        
        echo "$output" | awk -v green="$gl_lv" -v red="$gl_hong" -v yellow="$gl_huang" \
            -v cyan="$gl_bufan" -v blue="$gl_lan" -v reset="$reset" '
        /^Chain / {
            chain = $2
            policy = ""
            for (i=4; i<=NF; i++) {
                if ($i == "(policy") {
                    policy = $(i+1)
                    gsub(/[()]/, "", policy)
                    break
                }
            }
            if (policy == "") {
                for (i=4; i<=NF; i++) {
                    if ($i == "references" || $i ~ /^[0-9]+$/) {
                        policy = "自定义"
                        break
                    }
                }
            }
            if (chain == "INPUT") {
                chain_display = "入站"
                chain_color = blue
            } else if (chain == "OUTPUT") {
                chain_display = "出站"
                chain_color = blue
            } else if (chain == "FORWARD") {
                chain_display = "转发"
                chain_color = blue
            } else if (chain ~ /^f2b-/) {
                chain_display = "⛓" chain
                chain_color = red
            } else if (chain ~ /^DOCKER/) {
                chain_display = "🐳" chain
                chain_color = cyan
            } else {
                chain_display = "🔗" chain
                chain_color = blue
            }
            if (policy == "ACCEPT") {
                policy_display = "允许"
                policy_color = green
            } else if (policy == "DROP") {
                policy_display = "丢弃"
                policy_color = red
            } else if (policy == "REJECT") {
                policy_display = "拒绝"
                policy_color = red
            } else if (policy == "1" || policy == "references" || policy == "自定义") {
                policy_display = "自定义"
                policy_color = yellow
            } else {
                policy_display = policy
                policy_color = yellow
            }
            printf "%s%s%s  策略: %s%s%s\n\n", chain_color, chain_display, reset, policy_color, policy_display, reset
        }
        
        /^[0-9]/ && NF >= 6 {
            num = $1
            target = $2
            source = $5
            dest = $6
            
            ports = ""
            for (i=7; i<=NF; i++) {
                if ($i ~ /dpt:[0-9]+/) {
                    match($i, /dpt:[0-9]+/)
                    ports = substr($i, RSTART+4, RLENGTH-4)
                    break
                } else if ($i ~ /multiport/) {
                    ports = "多端口"
                    break
                }
            }
            
            if (source == "0.0.0.0/0" && dest == "0.0.0.0/0" && ports == "" && target == "ACCEPT") {
                next
            }
            
            if (target == "ACCEPT") {
                target_display = "✓允许"
                target_color = green
            } else if (target == "DROP") {
                target_display = "✗丢弃"
                target_color = red
            } else if (target == "REJECT") {
                target_display = "✗拒绝"
                target_color = red
            } else if (target == "LOG") {
                target_display = "📋日志"
                target_color = cyan
            } else if (target == "RETURN") {
                target_display = "↩返回"
                target_color = yellow
            } else if (target ~ /DNAT|SNAT|MASQUERADE/) {
                target_display = "↔NAT"
                target_color = cyan
            } else if (target ~ /^f2b-/) {
                target_display = "⛓封禁"
                target_color = red
            } else if (target ~ /^DOCKER-/) {
                target_display = "🐳Docker"
                target_color = cyan
            } else {
                target_display = "•" target
                target_color = yellow
            }
            
            if (source == "0.0.0.0/0") source = ""
            if (dest == "0.0.0.0/0") dest = ""
            if (source != "" && dest != "") {
                addr = source "→" dest
            } else if (source != "") {
                addr = source
            } else if (dest != "") {
                addr = "→" dest
            } else {
                addr = ""
            }
            
            if (ports != "") {
                ports_display = "端口:" ports
            } else {
                ports_display = ""
            }
            
            printf "  %s%2s%s\t", yellow, num, reset
            printf "%s%-8s%s\t", target_color, target_display, reset
            printf "%s%s%s\t", cyan, addr, reset
            if (ports_display != "") {
                printf "%s%s%s", yellow, ports_display, reset
            } else {
                printf "%s", reset
            }
            printf "\n"
        }'
        
    } | column_if_available
}

list_beautify_iptables_input() {
    local chain="${1:-INPUT}"
    if ! iptables -L "$chain" -n --line-numbers &>/dev/null; then
        echo -e "\033[1;31m错误: 需要 root 权限或链 $chain 不存在\033[0m" >&2
        return 1
    fi
    local policy_line policy policy_display policy_color
    policy_line=$(iptables -L "$chain" -n 2>/dev/null | head -n1)
    if [[ "$policy_line" =~ \(policy\ ([A-Z]+)\) ]]; then
        policy="${BASH_REMATCH[1]}"
    else
        policy="自定义"
    fi
    case "$policy" in
        ACCEPT) policy_display="允许"; policy_color="\033[1;32m" ;;
        DROP)   policy_display="丢弃"; policy_color="\033[1;31m" ;;
        REJECT) policy_display="拒绝"; policy_color="\033[1;31m" ;;
        自定义) policy_display="自定义"; policy_color="\033[1;33m" ;;
        *)      policy_display="$policy"; policy_color="\033[1;33m" ;;
    esac
    echo -e "\033[1;34m链: $chain\033[0m  策略: ${policy_color}${policy_display}\033[0m\n"

    iptables -L "$chain" -n --line-numbers 2>/dev/null | awk -v green="\033[1;32m" -v red="\033[1;31m" -v yellow="\033[1;33m" -v cyan="\033[1;36m" -v blue="\033[1;34m" -v reset="\033[0m" '
    /^[0-9]/ {
        num = $1; target = $2; prot = $3; source = $5; dest = $6
        port_info = ""
        for (i=7; i<=NF; i++) {
            if ($i ~ /^dpt:/) { port_info = $i; break }
            else if ($i ~ /^spt:/) { port_info = $i; break }
            else if ($i ~ /^multiport/) { port_info = $i; break }
        }
        if (port_info ~ /^dpt:/) port = "→" substr(port_info,4)
        else if (port_info ~ /^spt:/) port = "←" substr(port_info,4)
        else if (port_info ~ /^multiport/) port = "多端口"
        else port = ""

        if (target == "ACCEPT") { t = "允许"; c = green }
        else if (target == "DROP") { t = "丢弃"; c = red }
        else if (target == "REJECT") { t = "拒绝"; c = red }
        else if (target ~ /^f2b-/) { t = "⛓封禁(" substr(target,5) ")"; c = red }
        else { t = target; c = yellow }

        if (prot == "tcp") proto = "TCP"
        else if (prot == "udp") proto = "UDP"
        else if (prot == "all") proto = "全部"
        else proto = prot

        s = (source == "0.0.0.0/0") ? "任意" : source
        d = (dest == "0.0.0.0/0") ? "任意" : dest

        printf "%s%2d%s|%s%-14s%s|%s%-6s%s|%s%-18s%s|%s%-18s%s|%s%-10s%s\n",
            yellow, num, reset,
            c, t, reset,
            cyan, proto, reset,
            blue, s, reset,
            blue, d, reset,
            yellow, port, reset
    }' | sed 's/|/\t/g' | column_if_available
}

f2b_status() {
    fail2ban-client reload
    sleep_fractional 3
    fail2ban-client status
}

check_f2b_status() {
    if command -v fail2ban-client >/dev/null 2>&1; then
        check_f2b_status="${gl_lv}已安装${gl_bai}"
    else
        check_f2b_status="${gl_hui}未安装${gl_bai}"
    fi
}

f2b_install_sshd() {
    docker rm -f fail2ban >/dev/null 2>&1
    install fail2ban
    systemctl start fail2ban
    enable fail2ban

    if command -v dnf &>/dev/null; then
        cd /etc/fail2ban/jail.d/
        curl -sS -O https://gitee.com/meimolihan/sh/raw/master/f2b/centos-ssh.conf
    fi
}

f2b_sshd() {
    local jail
    if grep -qi 'Alpine' /etc/issue 2>/dev/null; then
        jail=alpine-sshd
    else
        jail=sshd
    fi
    fail2ban-client status "$jail"
}

f2b_autostart() {
    status=$(systemctl is-enabled fail2ban 2>/dev/null || echo "unknown")

    if [[ $status == "enabled" ]]; then
        echo -e "\n[${gl_lv}✔${gl_bai}] 无需重复操作，${gl_huang}fail2ban ${gl_lv}已是开机自启状态。${gl_bai}"
    else
        echo -e "\n${gl_bai}正在设置 ${gl_huang}fail2ban${gl_bai} 开机自启，请稍候 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        if systemctl enable fail2ban >/dev/null 2>&1; then
            echo -e "\n[${gl_lv}✔${gl_bai}] 设置成功！fail2ban 已设为开机自启。"
        else
            echo -e "\n[${gl_hong}✔${gl_bai}] 设置失败，请检查是否安装 fail2ban 或以 root 身份运行。"
        fi
    fi
}

update_fail2ban() {
    local DISTRO LOG_FILE CURRENT_VERSION NEW_VERSION

    LOG_FILE="/var/log/fail2ban_update.log"

    sudo mkdir -p "$(dirname "$LOG_FILE")"

    echo ""
    echo -e "${gl_huang}>>> 开始更新 fail2ban ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}" | sudo tee -a "$LOG_FILE"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        DISTRO="$ID"
    else
        echo "错误：无法检测系统发行版" | sudo tee -a "$LOG_FILE"
        return 1
    fi

    echo -e "${gl_bai}检测到系统: ${gl_lv}$DISTRO" | sudo tee -a "$LOG_FILE${gl_bai}"

    if ! command -v fail2ban-server &>/dev/null && ! systemctl is-active --quiet fail2ban; then
        echo -e "错误：fail2ban 未安装或未运行" | sudo tee -a "$LOG_FILE"
        return 1
    fi

    CURRENT_VERSION=$(fail2ban-client --version 2>/dev/null || echo "未知")
    echo -e "${gl_bai}当前fail2ban版本: ${gl_lv}$CURRENT_VERSION" | sudo tee -a "$LOG_FILE${gl_bai}"

    backup_fail2ban_config() {
        local BACKUP_DIR="/etc/fail2ban/backup_$(date +%Y%m%d_%H%M%S)"
        echo -e "${gl_bai}备份配置到: ${gl_lv}$BACKUP_DIR" | sudo tee -a "$LOG_FILE${gl_bai}"

        sudo mkdir -p "$BACKUP_DIR"
        sudo cp -r /etc/fail2ban/*.conf /etc/fail2ban/*.local "$BACKUP_DIR/" 2>/dev/null
        sudo cp -r /etc/fail2ban/jail.d/ "$BACKUP_DIR/" 2>/dev/null
    }

    update_via_package_manager() {
        case "$DISTRO" in
        ubuntu | debian)
            echo -e "${gl_bai}使用 ${gl_huang}apt ${gl_bai}更新 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}" | sudo tee -a "$LOG_FILE"
            sudo apt update || return 1
            sudo apt upgrade -y fail2ban || return 1
            ;;
        centos | rhel | fedora | rocky | almalinux)
            if [[ "$DISTRO" == "fedora" ]]; then
                echo -e "${gl_bai}使用 ${gl_huang}dnf${gl_bai} 更新 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}" | sudo tee -a "$LOG_FILE"
                sudo dnf update -y fail2ban || return 1
            else
                echo "${gl_bai}使用 ${gl_huang}yum ${gl_bai}更新 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}" | sudo tee -a "$LOG_FILE"
                if ! yum repolist | grep -q epel; then
                    sudo yum install -y epel-release || return 1
                fi
                sudo yum update -y fail2ban || return 1
            fi
            ;;
        *)
            echo "不支持的发行版: $DISTRO" | sudo tee -a "$LOG_FILE"
            return 1
            ;;
        esac
    }

    echo -e "${gl_bai}停止 fail2ban 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}" | sudo tee -a "$LOG_FILE"
    sudo systemctl stop fail2ban || {
        echo -e "${gl_huang}错误：无法停止 fail2ban 服务${gl_bai}" | sudo tee -a "$LOG_FILE"
        exit_animation
        return 1
    }

    if ! update_via_package_manager; then
        echo -e "${gl_huang}错误：包管理器更新失败${gl_bai}" | sudo tee -a "$LOG_FILE"
        sudo systemctl start fail2ban
        exit_animation
        return 1
    fi

    NEW_VERSION=$(fail2ban-client --version 2>/dev/null || echo "未知")
    echo "更新后 fail2ban 版本: $NEW_VERSION" | sudo tee -a "$LOG_FILE"

    echo ""
    echo -e "${gl_huang}>>> 启动 fail2ban 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}" | sudo tee -a "$LOG_FILE${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    fail2ban-client -t && systemctl restart fail2ban

    sleep_fractional 3
    
    systemctl status fail2ban

    if [[ "$CURRENT_VERSION" != "$NEW_VERSION" ]]; then
        echo -e "${gl_lv}✓ 版本已更新: $CURRENT_VERSION → $NEW_VERSION" | sudo tee -a "$LOG_FILE${gl_bai}"
    else
        echo -e "${gl_huang}ℹ 版本未变更，可能已是最新版本" | sudo tee -a "$LOG_FILE${gl_bai}"
    fi

    echo ""
    echo -e "${gl_huang}>>> 更新摘要${gl_bai}" | sudo tee -a "$LOG_FILE${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}系统: ${gl_lv}$DISTRO${gl_bai}" | sudo tee -a "$LOG_FILE"
    echo -e "${gl_bai}旧版本: ${gl_lv}$CURRENT_VERSION${gl_bai}" | sudo tee -a "$LOG_FILE"
    echo -e "${gl_bai}新版本: ${gl_lv}$NEW_VERSION${gl_bai}" | sudo tee -a "$LOG_FILE"
    echo -e "${gl_bai}服务状态: ${gl_lv}$(systemctl is-active fail2ban)${gl_bai}" | sudo tee -a "$LOG_FILE"
    echo -e "${gl_bai}日志文件: ${gl_lv}$LOG_FILE${gl_bai}" | sudo tee -a "$LOG_FILE"

    echo -e "${gl_bai}当前被封禁的 IP：${gl_huang}" | sudo tee -a "$LOG_FILE"
    sudo fail2ban-client status | grep "Jail list" | sudo tee -a "$LOG_FILE${gl_bai}"

    return 0
}

check_directory_empty() {
    local dir="${1:-.}"
    local title="${2:-检查目录}"
    local exit_on_empty="${3:-true}"
    
    if [ ! -d "$dir" ]; then
        echo -e ""
        echo -e "${gl_zi}>>> ${title}${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_hong}错误：目录不存在 ${gl_huang}${dir}${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_lv}即将退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
        sleep_fractional 0.8
        echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
        sleep_fractional 1
        return 2
    fi
    
    if [ -z "$(ls -A "$dir" 2>/dev/null)" ]; then
        if [ "$exit_on_empty" != "true" ] && [ "$exit_on_empty" != "1" ]; then
            echo -e "${gl_huang}当前目录为空：${gl_bai}(${gl_lv}$(pwd)${gl_bai})"
            return 0
        fi
        
        echo ""
        echo -e "${gl_zi}>>> ${title}${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}当前目录为空：${gl_bai}(${gl_lv}$(pwd)${gl_bai})"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_lv}即将退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
        sleep_fractional 1
        echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
        sleep_fractional 1
        return 1
    fi
    return 0
}

iptables_init() {
    echo -e ""
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_huang}核心功能：${gl_bai}"
    echo -e "${gl_huang}  1. ${gl_bai}备份现有规则（含 Docker 链）"
    echo -e "${gl_huang}  2. ${gl_bai}仅清空 INPUT 链 & 自定义链，保留 Docker 相关链"
    echo -e "${gl_huang}  3. ${gl_bai}设置默认安全策略（DROP INPUT/FORWARD，ACCEPT OUTPUT）"
    echo -e "${gl_huang}  4. ${gl_bai}放行本地回环、已建立连接、关键端口"
    echo -e "${gl_huang}  5. ${gl_bai}自动保存新配置"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}确定要初始化 ${gl_huang}iptables ${gl_bai}吗？ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")"
    [ "$REPLY" = "0" ] && { cancel_return "上一级选单"; return 1; }
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${gl_huang}已取消操作 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
        exit_animation
        return
    fi

    clear
    echo -e ""
    echo -e "${gl_zi}>>> 正在初始化iptables（Docker 兼容） ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    mkdir -p /etc/iptables
    local bak_file
    bak_file="/etc/iptables/rules.v4.bak.$(date +%F_%T)"
    if iptables-save >"$bak_file" 2>/dev/null; then
        log_ok "已备份当前规则到 $bak_file"
    else
        log_warn "备份失败，继续初始化"
    fi

    iptables -F INPUT
    log_ok "已清空 INPUT 链"

    local custom_chains
    custom_chains=$(iptables -t filter -S | grep '^-N' | awk '{print $2}' 2>/dev/null || true)

    for chain in $custom_chains; do
        if [[ $chain =~ ^DOCKER ]]; then
            continue
        fi

        if [[ $chain == "INPUT" || $chain == "FORWARD" || $chain == "OUTPUT" ]]; then
            continue
        fi

        if iptables -t filter -L "$chain" &>/dev/null; then
            iptables -F "$chain" 2>/dev/null
            iptables -X "$chain" 2>/dev/null
        fi
    done
    log_ok "已清理自定义链，Docker 链保留"

    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT
    log_ok "默认策略已设置"

    iptables -A INPUT -i lo -j ACCEPT
    log_ok "已放行本地回环"

    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    log_ok "已放行已建立及关联连接"

    for port in 22 80 443 445 139 666; do
        iptables -A INPUT -p tcp --dport "$port" -j ACCEPT
        log_ok "已放行 TCP 端口 $port"
    done

    if iptables -t filter -L DOCKER-USER &>/dev/null; then
        iptables -A DOCKER-USER -j RETURN
        log_ok "已配置 DOCKER-USER 链"
    fi

    if iptables -t filter -L DOCKER-ISOLATION &>/dev/null; then
        if ! iptables -C FORWARD -j DOCKER-ISOLATION &>/dev/null; then
            iptables -A FORWARD -j DOCKER-ISOLATION
        fi
        log_ok "已配置 DOCKER-ISOLATION 链"
    fi

    if command -v iptables-save &>/dev/null; then
        mkdir -p /etc/iptables
        if iptables-save >/etc/iptables/rules.v4 2>/dev/null; then
            log_ok "规则已保存至 /etc/iptables/rules.v4"
        else
            log_error "保存规则失败"
        fi
    else
        log_error "未找到 iptables-save，请手动保存"
    fi

    if command -v docker &>/dev/null && systemctl is-active --quiet docker 2>/dev/null; then
        echo -e "${gl_huang}正在重新加载 Docker 规则 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        systemctl restart docker
        sleep_fractional 2
        if systemctl is-active --quiet docker; then
            log_ok "Docker 重启完成"
        else
            log_warn "Docker 重启后未运行"
        fi
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

iptables_on() {
    clear
    echo -e "${gl_zi}>>> 开启iptables防火墙${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    log_info "正在安装必要的软件包 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y iptables-persistent
        local service_name="netfilter-persistent"
    elif command -v yum >/dev/null 2>&1 || command -v dnf >/dev/null 2>&1; then
        yum install -y iptables-services || dnf install -y iptables-services
        local service_name="iptables"
    else
        log_error "不支持的Linux发行版，无法确定包管理器。"
        return 1
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    log_info "加载必要的内核模块 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    modprobe -a iptable_filter iptable_nat iptable_mangle iptable_raw 2>/dev/null

    log_info "正在启动并设置开机启动 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

    local max_attempts=3
    local attempt=1
    local service_started=0

    while [ $attempt -le $max_attempts ]; do
        if systemctl start "$service_name" 2>/dev/null; then
            systemctl enable "$service_name" 2>/dev/null
            log_ok "iptables 服务启动命令已执行（尝试 ${gl_lv}$attempt${gl_bai}/${gl_huang}$max_attempts${gl_bai}）"

            sleep_fractional 2
            if systemctl is-active "$service_name" >/dev/null 2>&1; then
                log_ok "iptables 服务确认已运行"
                service_started=1
                break
            else
                log_warn "服务启动但状态检查未通过，重试 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            fi
        else
            log_warn "无法通过systemctl启动服务（尝试 ${gl_lv}$attempt${gl_bai}/${gl_huang}$max_attempts${gl_bai}）"

            if service "$service_name" start 2>/dev/null; then
                log_ok "通过传统service命令启动成功"
                service_started=1
                break
            fi
        fi

        attempt=$((attempt + 1))
        sleep_fractional 2
    done

    log_info "正在保存当前防火墙规则 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

    mkdir -p /etc/iptables 2>/dev/null

    if iptables-save >/etc/iptables/rules.v4 2>/dev/null; then
        log_ok "IPv4 防火墙规则已保存"
    else
        echo "# Generated by iptables_on function" >/etc/iptables/rules.v4
        echo "*filter" >>/etc/iptables/rules.v4
        echo ":INPUT ACCEPT [0:0]" >>/etc/iptables/rules.v4
        echo ":FORWARD ACCEPT [0:0]" >>/etc/iptables/rules.v4
        echo ":OUTPUT ACCEPT [0:0]" >>/etc/iptables/rules.v4
        echo "COMMIT" >>/etc/iptables/rules.v4
        log_ok "创建基本防火墙规则文件"
    fi

    if command -v ip6tables-save >/dev/null 2>&1; then
        ip6tables-save >/etc/iptables/rules.v6 2>/dev/null && log_ok "IPv6 防火墙规则已保存"
    fi

    sleep_fractional 2

    log_info "进行最终验证 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

    local final_check_passed=0

    if systemctl is-active "$service_name" >/dev/null 2>&1; then
        log_ok "✓ 服务状态验证通过"
        final_check_passed=$((final_check_passed + 1))
    fi

    if lsmod | grep -q iptable_filter; then
        log_ok "✓ 内核模块验证通过"
        final_check_passed=$((final_check_passed + 1))
    fi

    if [ -s "/etc/iptables/rules.v4" ]; then
        log_ok "✓ 规则文件验证通过"
        final_check_passed=$((final_check_passed + 1))
    fi

    if [ $final_check_passed -ge 2 ]; then
        log_ok "iptables 防火墙已成功启用并运行正常"
    else
        log_warn "iptables 部分组件就绪，建议检查详细状态"
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

iptables_off() {
    clear
    echo -e "${gl_zi}>>> 关闭iptables防火墙（保活22端口）${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    log_info "默认策略已临时设为 ACCEPT"

    iptables -F
    iptables -X
    iptables -t nat -F && iptables -t nat -X
    iptables -t mangle -F && iptables -t mangle -X
    log_warn "已清空所有规则"

    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    log_ok "已保留 TCP 22 端口"

    systemctl stop iptables 2>/dev/null || service iptables stop 2>/dev/null
    systemctl disable iptables 2>/dev/null || chkconfig iptables off 2>/dev/null
    log_warn "iptables 服务已停止并取消开机启动"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

show_port_rules() {
    local total=0
    local allowed=0
    local blocked=0

    printf "%-8s %-10s %-10s %-10s %-8s\n" "规则" "协议" "端口" "状态" "动作"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    iptables -nL INPUT --line-numbers | while read -r line; do
        if echo "$line" | grep -q "dpt:"; then
            rule_num=$(echo "$line" | awk '{print $1}')
            action=$(echo "$line" | awk '{print $2}')
            protocol=$(echo "$line" | awk '{print $3}')

            port=$(echo "$line" | grep -o "dpt:[0-9]\+" | cut -d: -f2)
            if [ -z "$port" ]; then
                port=$(echo "$line" | awk '{for(i=1;i<=NF;i++) if($i ~ /dpt:/) {split($i,a,":"); print a[2]; break}}')
            fi

            case "$action" in
            "ACCEPT")
                status="允许"
                color="${gl_lv}"
                ;;
            "DROP")
                status="禁止"
                color="${gl_hong}"
                ;;
            "REJECT")
                status="拒绝"
                color="${gl_hong}"
                ;;
            *)
                status="未知"
                color="${gl_bai}"
                ;;
            esac

            printf "${color}%-6s %-8s %-8s %-10s %-12s${gl_bai}\n" \
                "#$rule_num" "$protocol" "$port" "$status" "$action"
        fi
    done

    total=$(iptables -nL INPUT --line-numbers | grep -c "dpt:")
    allowed=$(iptables -nL INPUT --line-numbers | grep "dpt:" | grep -c "ACCEPT")
    blocked=$(iptables -nL INPUT --line-numbers | grep "dpt:" | grep -E -c "DROP|REJECT")

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    local policy
    policy=$(iptables -L INPUT -n | grep -oP 'policy \K[^)]+')
    echo -e "${gl_bai}规则总计:${gl_zi}${total} ${gl_hong}|${gl_bai}允许:${gl_lv}${allowed} ${gl_hong}|${gl_bai}禁止/拒绝:${gl_hong}${blocked}${gl_hong} |${gl_bai}默认策略:${gl_zi}$policy${gl_bai}"

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
}

check_iptables_status_enhanced() {
    local status=0
    local rule_count=0
    local service_status=""
    local active_method=""

    sleep_fractional 1

    if systemctl is-active iptables &>/dev/null; then
        service_status="${gl_lv}服务运行中(systemctl-iptables)${gl_bai}"
        active_method="iptables"
        status=0
    elif systemctl is-active netfilter-persistent &>/dev/null; then
        service_status="${gl_lv}服务运行中(netfilter-persistent)${gl_bai}"
        active_method="netfilter-persistent"
        status=0
    elif systemctl status iptables 2>/dev/null | grep -q "active (exited)"; then
        service_status="${gl_lv}服务运行中(active-exited)${gl_bai}"
        active_method="iptables"
        status=0
    elif service iptables status &>/dev/null; then
        service_status="${gl_lv}服务运行中(service)${gl_bai}"
        active_method="service"
        status=0
    else
        rule_count=$(iptables-save 2>/dev/null | grep -c '^-A' || echo 0)
        if [ $rule_count -gt 0 ]; then
            service_status="${gl_huang}服务未运行但规则已加载${gl_bai}"
            status=1
        else
            service_status="${gl_huang}服务未运行${gl_bai}"
            status=1
        fi
    fi

    rule_count=$(iptables-save 2>/dev/null | grep -c '^-A' || echo 0)

    local persisted_rules=0
    local config_file=""

    for config in "/etc/iptables/rules.v4" "/etc/sysconfig/iptables" "/etc/iptables/rules"; do
        if [ -f "$config" ]; then
            config_file="$config"
            persisted_rules=$(grep -c '^-A' "$config" 2>/dev/null || echo 0)
            break
        fi
    done

    echo -e "${gl_bai}防火墙状态: $service_status ${gl_hong}|${gl_bai} 内存规则: ${gl_huang}$rule_count${gl_bai}"
    if [ -n "$config_file" ]; then
        echo -e "${gl_bai}配置文件: ${gl_huang}$config_file${gl_bai} ${gl_hong}|${gl_bai} 持久化规则: ${gl_huang}$persisted_rules${gl_bai}"
    else
        echo -e "${gl_huang}未找到持久化配置文件${gl_bai}"
    fi

    if [ $rule_count -ne $persisted_rules ] && [ $persisted_rules -gt 0 ]; then
        echo -e "${gl_huang}警告: 内存规则($rule_count)与持久化规则($persisted_rules)数量不一致${gl_bai}"
        status=2
    fi

    local input_policy output_policy forward_policy
    input_policy=$(iptables -L INPUT -n 2>/dev/null | grep -oP 'policy \K\S+' || echo "未知")
    forward_policy=$(iptables -L FORWARD -n 2>/dev/null | grep -oP 'policy \K\S+' || echo "未知")
    output_policy=$(iptables -L OUTPUT -n 2>/dev/null | grep -oP 'policy \K\S+' || echo "未知")

    echo -e "${gl_bai}默认策略: INPUT[${gl_huang}$input_policy${gl_bai}] FORWARD[${gl_huang}$forward_policy${gl_bai}] OUTPUT[${gl_huang}$output_policy${gl_bai}]"

    return $status
}

iptables_manager() {
    while true; do
        root_use
        clear
        echo -e "${gl_huang}>>> 当前iptables规则${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        check_iptables_status_enhanced
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        list_beautify_iptables_input INPUT
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e ""
        echo -e "${gl_zi}>>> iptables规则管理${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}开启防火墙          ${gl_bufan}2.  ${gl_bai}关闭防火墙"
        echo -e "${gl_bufan}3.  ${gl_bai}允许指定端口        ${gl_bufan}4.  ${gl_bai}删除指定端口规则"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}5.  ${gl_bai}封禁指定端口        ${gl_bufan}6.  ${gl_bai}解封指定端口并允许"
        echo -e "${gl_bufan}7.  ${gl_bai}所有端口规则        ${gl_bufan}8.  ${gl_bai}初始化iptables"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}9.  ${gl_bai}当前规则列表        ${gl_bufan}10. ${gl_bai}高级防火墙管理"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单      ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "请输入你的选择: " choice

        case $choice in
        1) iptables_on ;;
        2) iptables_off ;;
        3)
            echo -e ""
            echo -e "${gl_zi}>>> 允许指定端口${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

            read -r -e -p "$(echo -e "${gl_bai}请输入要放行的端口号 (${gl_huang}0${gl_bai}返回): ")" port

            [[ -z "$port" ]] && { cancel_empty "上一级选单"; continue; }
            [[ "$port" == "0" ]] && { cancel_return "上一级选单"; continue; }

            if ! [[ $port =~ ^[0-9]+$ && $port -ge 1 && $port -le 65535 ]]; then
                echo -e ""
                log_warn "端口号非法，请输入 ${gl_hong}1-65535${gl_bai} 之间的数字"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                exit_animation
                continue
            fi

            if iptables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null; then
                echo -e ""
                log_info "端口 ${gl_huang}$port${gl_bai} 的允许规则已存在，无需重复添加"
            else
                conflict=$(iptables -nL INPUT --line-numbers | grep "dpt:$port" | head -1)
                if [ -n "$conflict" ]; then
                    echo -e ""
                    log_info "端口 ${gl_huang}$port${gl_bai} 已有其他防火墙规则"
                    echo -e "${gl_bai}现有规则: ${gl_zi}$conflict${gl_bai}"
                    echo -e ""
                    read -r -e -p "$(echo -e "${gl_bai}是否继续添加允许规则？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
                    if [[ $confirm =~ ^[Yy]$ ]]; then
                        iptables -A INPUT -p tcp --dport "$port" -j ACCEPT
                        log_ok "已放行 TCP 端口 ${gl_lv}$port${gl_bai}"
                    else
                        log_info "已取消操作"
                    fi
                else
                    iptables -A INPUT -p tcp --dport "$port" -j ACCEPT
                    echo -e ""
                    log_ok "已放行 TCP 端口 ${gl_lv}$port${gl_bai}"
                fi
            fi

            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        4)
            clear
            echo -e "${gl_bufan}"
            echo -e "${gl_huang}>>> 当前规则列表${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            if iptables -L -n --line-numbers; then
                log_ok "规则列表显示完成"
            else
                log_error "规则列表显示失败"
            fi
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e ""
            echo -e "${gl_zi}>>> 删除指定端口规则${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bai}请输入要删除的端口号 (${gl_huang}0${gl_bai}返回): ")" port

            [[ -z "$port" ]] && { cancel_empty "上一级选单"; continue; }
            [[ "$port" == "0" ]] && { cancel_return "上一级选单"; continue; }

            if [[ $port =~ ^[0-9]+$ && $port -ge 1 && $port -le 65535 ]]; then
                if iptables -D INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null ||
                    iptables -D INPUT -p tcp --dport "$port" -j DROP 2>/dev/null; then
                    echo -e ""
                    log_ok "已删除 TCP 端口 $port 相关规则"
                else
                    echo -e ""
                    log_warn "未找到 TCP 端口 $port 相关规则"
                fi
            else
                log_error "端口号非法，已跳过"
            fi
            echo -e ""
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_lv}>>> 修改后的规则列表${gl_bai}"
            if iptables -L -n --line-numbers; then
                log_ok "规则列表显示完成"
            else
                log_error "规则列表显示失败"
            fi
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        5)
            clear
            echo -e ""
            echo -e "${gl_huang}>>> 当前所有端口规则列表${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            show_port_rules
            echo -e ""
            echo -e "${gl_zi}>>> 封禁指定端口（TCP）${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bai}请输入要封禁的端口号 (${gl_huang}0${gl_bai}返回): ")" port

            [[ -z "$port" ]] && { cancel_empty "上一级选单"; continue; }
            [[ "$port" == "0" ]] && { cancel_return "上一级选单"; continue; }

            if [[ $port =~ ^[0-9]+$ && $port -ge 1 && $port -le 65535 ]]; then
                if iptables -C INPUT -p tcp --dport "$port" -j DROP 2>/dev/null; then
                    echo -e ""
                    log_warn "端口 $port 已存在封禁规则，无需重复添加"
                    exit_animation
                    continue
                fi

                while iptables -D INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null; do
                    echo -e "${gl_huang}删除端口 $port 的允许规则 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                done

                local insert_position=3
                local accept_rules_count
                accept_rules_count=$(iptables -L INPUT -n --line-numbers | grep -c "ACCEPT")
                if [[ $accept_rules_count -gt 0 ]]; then
                    insert_position=$((accept_rules_count + 1))
                fi

                iptables -I INPUT $insert_position -p tcp --dport "$port" -j DROP

                if [[ -f /etc/redhat-release ]]; then
                    if systemctl is-active --quiet firewalld; then
                        firewall-cmd --permanent --remove-port="$port"/tcp >/dev/null 2>&1
                        firewall-cmd --permanent --add-rich-rule="rule family='ipv4' port port='$port' protocol='tcp' reject" >/dev/null 2>&1
                        firewall-cmd --reload >/dev/null 2>&1
                        echo -e "${gl_lv}检测到使用 firewalld，已通过 firewalld 添加封禁规则${gl_bai}"
                    else
                        iptables-save >/etc/sysconfig/iptables 2>/dev/null
                        if command -v systemctl >/dev/null 2>&1; then
                            systemctl enable iptables --now 2>/dev/null || true
                        fi
                    fi
                elif [[ -f /etc/debian_version ]]; then
                    mkdir -p /etc/iptables 2>/dev/null
                    iptables-save >/etc/iptables/rules.v4 2>/dev/null

                    if systemctl is-enabled netfilter-persistent >/dev/null 2>&1; then
                        systemctl restart netfilter-persistent 2>/dev/null || true
                    else
                        if command -v apt-get >/dev/null 2>&1; then
                            apt-get update >/dev/null 2>&1
                            DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent >/dev/null 2>&1
                            systemctl enable netfilter-persistent 2>/dev/null || true
                            systemctl start netfilter-persistent 2>/dev/null || true
                        fi
                    fi
                else
                    echo -e "${gl_huang}警告：未识别发行版，请手动保存规则${gl_bai}"
                fi

                echo -e ""
                log_ok "已封禁 TCP 端口 ${gl_huang}$port${gl_bai} 并已保存，重启仍生效"
            else
                echo -e ""
                log_error "端口号非法，请输入 ${gl_huang}1-65535${gl_bai} 之间的数字"
            fi
            echo -e ""
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_lv}>>> 修改后的规则列表${gl_bai}"
            show_port_rules
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        6)
            clear
            echo -e "${gl_huang}>>> 当前所有端口规则列表${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            show_port_rules
            echo -e ""
            echo -e "${gl_zi}>>> 解除端口封禁并允许指定端口${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bai}请输入要解除封禁的端口号 (${gl_huang}0${gl_bai}返回): ")" port

            [[ -z "$port" ]] && { cancel_empty "上一级选单"; continue; }
            [[ "$port" == "0" ]] && { cancel_return "上一级选单"; continue; }

            if [[ $port =~ ^[0-9]+$ && $port -ge 1 && $port -le 65535 ]]; then
                local deleted_rules=0

                while iptables -D INPUT -p tcp --dport "$port" -j DROP 2>/dev/null; do
                    deleted_rules=$((deleted_rules + 1))
                done

                while iptables -D INPUT -p tcp --dport "$port" -j REJECT 2>/dev/null; do
                    deleted_rules=$((deleted_rules + 1))
                done

                if iptables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null; then
                    echo -e ""
                    log_warn "端口 $port 已存在允许规则，无需重复添加"
                else
                    echo -e ""
                    read -r -e -p "$(echo -e "${gl_bai}是否要允许该端口 (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai})? ")" allow_port
                    allow_port=${allow_port:-N}

                    if [[ $allow_port =~ ^[Yy]$ ]]; then
                        local insert_position=3
                        local accept_rules_count
                        accept_rules_count=$(iptables -L INPUT -n --line-numbers | grep -c "ACCEPT")
                        if [[ $accept_rules_count -gt 0 ]]; then
                            insert_position=$((accept_rules_count + 1))
                        fi

                        iptables -I INPUT $insert_position -p tcp --dport "$port" -j ACCEPT
                        echo -e "${gl_lv}已添加端口 $port 的允许规则${gl_bai}"
                    else
                        echo -e "${gl_huang}未添加允许规则，仅解除封禁${gl_bai}"
                    fi
                fi

                if [[ $deleted_rules -gt 0 ]] || [[ $allow_port =~ ^[Yy]$ ]]; then
                    if [[ -f /etc/redhat-release ]]; then
                        if systemctl is-active --quiet firewalld; then
                            firewall-cmd --permanent --remove-rich-rule="rule family='ipv4' port port='$port' protocol='tcp' reject" >/dev/null 2>&1

                            if [[ $allow_port =~ ^[Yy]$ ]]; then
                                firewall-cmd --permanent --add-port="$port"/tcp >/dev/null 2>&1
                            fi

                            firewall-cmd --reload >/dev/null 2>&1
                            echo -e "${gl_lv}检测到使用 firewalld，已通过 firewalld 更新规则${gl_bai}"
                        else
                            iptables-save >/etc/sysconfig/iptables 2>/dev/null
                            if command -v systemctl >/dev/null 2>&1; then
                                systemctl enable iptables --now 2>/dev/null || true
                            fi
                        fi
                    elif [[ -f /etc/debian_version ]]; then
                        mkdir -p /etc/iptables 2>/dev/null
                        iptables-save >/etc/iptables/rules.v4 2>/dev/null

                        if systemctl is-enabled netfilter-persistent >/dev/null 2>&1; then
                            systemctl restart netfilter-persistent 2>/dev/null || true
                        else
                            if command -v apt-get >/dev/null 2>&1; then
                                apt-get update >/dev/null 2>&1
                                DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent >/dev/null 2>&1
                                systemctl enable netfilter-persistent 2>/dev/null || true
                                systemctl start netfilter-persistent 2>/dev/null || true
                            fi
                        fi
                    else
                        echo -e "${gl_huang}警告：未识别发行版，请手动保存规则${gl_bai}"
                    fi
                fi

                echo -e ""
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                if [[ $deleted_rules -gt 0 ]]; then
                    log_ok "已删除 $deleted_rules 条封禁规则，端口 $port 已解除封禁"
                    if [[ $allow_port =~ ^[Yy]$ ]]; then
                        log_ok "并已添加允许规则，重启仍生效"
                    else
                        log_ok "请手动添加允许规则以开放该端口"
                    fi
                else
                    log_warn "未找到端口 $port 的封禁规则"
                fi
            else
                echo -e ""
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                log_error "端口号非法，请输入 1-65535 之间的数字"
            fi
            echo -e ""
            echo -e "${gl_lv}>>> 修改后的规则列表${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            show_port_rules
            break_end
            ;;
        7)
            show_port_rules
            break_end
            ;;
        8) iptables_init ;;
        9)
            clear
            echo -e "${gl_zi}>>> 当前规则列表${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            list_beautify_iptables_all
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        10) linux_iptables_panel "iptables规则管理" ;;
        0)  cancel_return "安全防御"; break ;;
        00 | 000 | 0000) exit_script ;;
        *) handle_invalid_input ;;
        esac
    done
}

fail2ban_stop() {
    echo -e ""
    echo -e "${gl_zi}>>> 停止防御程序${gl_bai}"
    echo -e "${gl_bufan}———————————————————————————————————————————————${gl_bai}"
    systemctl stop fail2ban
    log_ok "防御程序已停止"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

fail2ban_start() {
    echo -e ""
    echo -e "${gl_zi}>>> 启动防御程序${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    systemctl start fail2ban
    log_ok "防御程序已启动"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

fail2ban_restart() {
    echo -e ""
    echo -e "${gl_zi}>>> 重启防御程序${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    fail2ban-client -t && systemctl restart fail2ban
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

fail2ban_status() {
    clear
    echo -e ""
    echo -e "${gl_zi}>>> 查看防御程序服务状态${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    systemctl status fail2ban
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

fail2ban_ssh_logs() {
    echo -e ""
    echo -e "${gl_zi}>>> 查看SSH拦截记录${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    f2b_sshd
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

fail2ban_web_logs() {
    clear
    echo -e ""
    echo -e "${gl_zi}>>> 查看网站拦截记录${gl_bai}"
    local jails=(
        fail2ban-nginx-cc
        nginx-418
        nginx-bad-request
        nginx-badbots
        nginx-botsearch
        nginx-deny
        nginx-http-auth
        nginx-unauthorized
        php-url-fopen
        nginx-pve
        nginx-403
    )

    for jail in "${jails[@]}"; do
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        fail2ban-client status "$jail"
    done
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

fail2ban_rules_list() {
    echo -e ""
    echo -e "${gl_zi}>>> 查看防御规则列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    fail2ban-client status
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

fail2ban_edit_blacklist() {
    install nano
    clear
    nano /etc/fail2ban/jail.d/nginx-cc.conf
    echo -e ""
    echo -e "${gl_zi}>>> 重启防御程序${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_huang}修改配置文件后需要重启防御程序生效${gl_bai}"
    echo -e "${gl_huang}未修改配置文件不必重启防御程序${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}是否要重启防御程序？ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
    [ "$confirm" = "0" ] && { cancel_return "上一级选单"; return 1; }
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        echo -e ""
        echo -e "${gl_bai}正在重启防御程序 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        fail2ban-client -t && systemctl restart fail2ban
        f2b_status
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_lv}防御程序已重启${gl_bai}"
        exit_animation
        clear
    else
        echo -e "${gl_huang}已取消重启防御程序${gl_bai}"
        exit_animation
        clear
    fi
}

fail2ban_view_banned_ips() {
    clear
    echo -e ""
    echo -e "${gl_zi}>>> 常规查看所有封禁的IP${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    fail2ban-client status recidive
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e ""
    echo -e "${gl_zi}>>> 详细查看所有封禁的IP${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    for j in $(fail2ban-client status | awk -F: '/Jail list/ {gsub(/,/,""); print $2}'); do
        echo -e "${gl_bufan} $j ${gl_bai}"
        sudo fail2ban-client get "$j" banip --with-time
    done
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

fail2ban_ban_ip_manual() {
    echo -e ""
    echo -e "${gl_zi}>>> 手动永久封禁IP${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "请输入要批量封禁的 IP（空格分隔，输入 q 或回车返回）: " ips

    [ "$ips" = "0" ] && { cancel_return "上一级选单"; return 1; }
    [[ -z "$ips" || "$ips" == "q" ]] && echo -e "${gl_hui}已取消操作，返回主菜单。${gl_bai}" && return

    fail2ban-client set recidive banip "$ips"
    fail2ban-client -t && systemctl restart fail2ban
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

fail2ban_unban_ip_manual() {
    echo -e ""
    echo -e "${gl_zi}>>> 手动永久解封 IP${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "请输入要永久解封的 IP（输入 q 或回车返回）: " ip

    [ "$ip" = "0" ] && { cancel_return "上一级选单"; return 1; }
    [[ -z "$ip" || "$ip" == "q" ]] && echo -e "${gl_hui}已取消操作，返回主菜单。${gl_bai}" && return

    fail2ban-client set recidive unbanip "$ip"
    fail2ban-client unban "$ip"
    fail2ban-client -t && systemctl restart fail2ban
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

fail2ban_clear_all_bans() {
    echo -e ""
    echo -e "${gl_zi}>>> 清空所有封禁的IP${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}确定清空所有封禁？ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" sure
    [[ $sure != y ]] && continue
    for jail in $(fail2ban-client status 2>/dev/null |
        sed -n '/Jail list:/ {s/.*Jail list://; s/,//g; p;}'); do
        for ip in $(fail2ban-client status "$jail" 2>/dev/null |
            awk '/Banned IP list:/ {for(i=4;i<=NF;i++) if($i~/[0-9]/) print $i}'); do
            fail2ban-client set "$jail" unbanip "$ip" >/dev/null 2>&1
        done
    done
    log_info "已解封所有 jail 的所有 IP"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

fail2ban_config_manager() {
    check_directory_empty "/etc/fail2ban" "网站防御配置文件管理" "true" || return 1
    clear
    echo -e "${gl_zi}>>> 网站防御配置文件管理${gl_bai}"
    bash <(curl -sL gitee.com/meimolihan/cmdbox/raw/master/sh/linux_file_menu.sh)  "/etc/fail2ban"
}

fail2ban_edit_whitelist() {
    install nano
    clear
    nano /etc/fail2ban/jail.d/nginx-cc.conf
    echo -e ""
    echo -e "${gl_zi}>>> 重启防御程序${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_huang}修改配置文件后需要重启防御程序生效${gl_bai}"
    echo -e "${gl_huang}未修改配置文件不必重启防御程序${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}是否要重启防御程序？ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        echo -e ""
        echo -e "${gl_bai}正在重启防御程序 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        fail2ban-client -t && systemctl restart fail2ban
        f2b_status
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_lv}防御程序已重启${gl_bai}"
        exit_animation
        clear
    else
        echo -e "${gl_huang}已取消重启防御程序${gl_bai}"
        exit_animation
        clear
    fi
}

fail2ban_view_whitelist() {
    clear
    echo -e "${gl_zi}>>> 所有监狱的白名单${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    for j in $(fail2ban-client status | awk -F: '/Jail list/ {gsub(/,/,""); print $2}'); do
        echo "=== $j ==="
        sudo fail2ban-client get "$j" ignoreip
    done
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

fail2ban_config_cloudflare() {
    echo "到cf后台右上角我的个人资料，选择左侧API令牌，获取Global API Key"
    echo "https://dash.cloudflare.com/login"
    read -r -e -p "输入CF的账号: " cfuser
    read -r -e -p "输入CF的Global API Key: " cftoken

    wget -O /etc/nginx/conf.d/default.conf ${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/default11.conf
    docker exec nginx nginx -s reload

    cd /etc/fail2ban/jail.d/
    curl -sS -O https://gitee.com/meimolihan/fail2ban/raw/master/nginx-docker-cc.conf

    cd /etc/fail2ban/action.d
    curl -sS -O ${gh_proxy}raw.githubusercontent.com/kejilion/config/main/fail2ban/cloudflare-docker.conf

    sed -i "s/kejilion@outlook.com/$cfuser/g" /etc/fail2ban/action.d/cloudflare-docker.conf
    sed -i "s/APIKEY00000/$cftoken/g" /etc/fail2ban/action.d/cloudflare-docker.conf
    f2b_status

    echo "已配置cloudflare模式，可在cf后台，站点-安全性-事件中查看拦截记录"
}

fail2ban_auto_under_attack() {
    echo -e "${gl_huang}网站每5分钟自动检测，当达检测到高负载会自动开盾，低负载也会自动关闭5秒盾。${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo "获取CF参数: "
    echo -e "到cf后台右上角我的个人资料，选择左侧API令牌，获取${gl_huang}Global API Key${gl_bai}"
    echo -e "到cf后台域名概要页面右下方获取${gl_huang}区域ID${gl_bai}"
    echo "https://dash.cloudflare.com/login"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "输入CF的账号: " cfuser
    [ "$cfuser" = "0" ] && { cancel_return "上一级选单"; return 1; }
    [ -z "$cfuser" ] && { cancel_empty "上一级选单"; return 1; }

    read -r -e -p "输入CF的Global API Key: " cftoken
    [ "$cftoken" = "0" ] && { cancel_return "上一级选单"; return 1; }
    [ -z "$cftoken" ] && { cancel_empty "上一级选单"; return 1; }

    read -r -e -p "输入CF中域名的区域ID: " cfzonID
    [ "$cfzonID" = "0" ] && { cancel_return "上一级选单"; return 1; }
    [ -z "$cfzonID" ] && { cancel_empty "上一级选单"; return 1; }

    cd ~
    install jq bc
    check_crontab_installed
    curl -sS -O ${gh_proxy}raw.githubusercontent.com/kejilion/sh/main/CF-Under-Attack.sh
    chmod +x CF-Under-Attack.sh
    sed -i "s/AAAA/$cfuser/g" ~/CF-Under-Attack.sh
    sed -i "s/BBBB/$cftoken/g" ~/CF-Under-Attack.sh
    sed -i "s/CCCC/$cfzonID/g" ~/CF-Under-Attack.sh

    local cron_job="*/5 * * * * ~/CF-Under-Attack.sh"

    local existing_cron
    existing_cron=$(crontab -l 2>/dev/null | grep -F "$cron_job")

    if [ -z "$existing_cron" ]; then
        (
            crontab -l 2>/dev/null
            echo "$cron_job"
        ) | crontab -
        echo "高负载自动开盾脚本已添加"
    else
        echo "自动开盾脚本已存在，无需添加"
    fi
}

fail2ban_nginx_waf_on() {
    nginx_waf on
    echo "站点WAF已开启"
}

fail2ban_nginx_waf_off() {
    nginx_waf off
    echo "站点WAF已关闭"
}

fail2ban_backup_config() {
    while true; do
        clear
        echo -e ""
        echo -e "${gl_zi}>>> 备份 Fail2Ban 配置${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        local backup_filename
        backup_filename="fail2ban_$(date +"%Y%m%d%H%M%S").tar.gz"
        echo -e "${gl_huang}正在备份 fail2ban ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        tar czf "/$backup_filename" \
            --absolute-names \
            /etc/fail2ban /var/log/fail2ban.log 2>/dev/null
        echo -e "${gl_lv}备份文件已创建: /$backup_filename${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        read -r -e -p "$(echo -e "${gl_bai}要传送到远程服务器吗？ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" choice

        case "$choice" in
        [Yy])
            while true; do
                read -r -e -p "请输入远端服务器IP: " remote_ip
                read -r -e -p "目标SSH端口 [默认22]: " TARGET_PORT
                TARGET_PORT=${TARGET_PORT:-22}

                if [[ -z "$remote_ip" ]]; then
                    echo -e "${gl_hong}错误: 请输入远端服务器IP${gl_bai}"
                    read -r -e -p "$(echo -e "${gl_hong}是否重新输入？ (${gl_lv}y${gl_bai}/${gl_hong}n${gl_bai}返回上级): ")" retry_choice
                    if [[ "$retry_choice" =~ [Nn] ]]; then
                        break
                    fi
                    continue
                fi

                echo -e ""
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                ssh-keygen -f "/root/.ssh/known_hosts" -R "$remote_ip" 2>/dev/null
                scp -P "$TARGET_PORT" -o StrictHostKeyChecking=no "/$backup_filename" "root@$remote_ip:/"
                echo -e "${gl_lv}文件已传送至远程服务器根目录${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                echo -e ""
                break 2
            done
            ;;
        [Nn] | "")
            break
            ;;
        0) cancel_return; return ;;
        *)
            echo -e "${gl_hong}无效输入，3秒后重新开始${gl_bai}"
            sleep_fractional 3
            continue
            ;;
        esac
    done
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

fail2ban_restore_config() {
    root_use
    echo -e ""
    echo -e "${gl_zi}>>> 恢复 Fail2Ban 配置${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo ""
    echo -e "${gl_bai}可用的 Fail2Ban 备份${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo ""
    ls -lt /fail2ban_*.tar.gz 2>/dev/null | awk '{print $NF}'
    echo ""
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    read -r -e -p "$(echo -e "输入文件名还原指定备份，${gl_bufan}回车${gl_bai}还原最新备份，${gl_huang}0${gl_bai}返回: ")" filename

    [[ -z "$filename" ]] && { cancel_empty "上一级选单"; return 1; } 
    [[ "$filename" == "0" ]] && { cancel_return "上一级选单"; return 1; }

    [[ -z "$filename" ]] && filename=$(ls -t /fail2ban_*.tar.gz 2>/dev/null | head -1)
    if [[ -f "$filename" ]]; then
        echo ""
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bai}正在还原 ${gl_huang}$filename ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        systemctl stop fail2ban
        tar -xzf "$filename" -C /
        systemctl start fail2ban
        echo -e "${gl_lv}fail2ban 配置 & 日志已还原，服务已重启${gl_bai}"
    else
        echo -e "${gl_hong}未找到备份文件${gl_bai}"
    fi

    f2b_status
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

fail2ban_install() {
    clear
    echo -e "${gl_zi}>>> 安装防御程序${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    f2b_install_sshd
    echo -e ""
    log_info "正在下载依赖文件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_info "下载 ${gl_bufan}Fail2Ban${gl_bai} 过滤器文件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    log_warn "保存至： ${gl_bufan}/etc/fail2ban/filter.d${gl_bai} "
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    cd /etc/fail2ban/filter.d
    wget -c https://gitee.com/meimolihan/sh/raw/master/f2b/filter.d/fail2ban-nginx-cc.conf
    wget -c https://gitee.com/meimolihan/sh/raw/master/f2b/filter.d/nginx-418.conf
    wget -c https://gitee.com/meimolihan/sh/raw/master/f2b/filter.d/nginx-403.conf
    wget -c https://gitee.com/meimolihan/sh/raw/master/f2b/filter.d/nginx-deny.conf
    wget -c https://gitee.com/meimolihan/sh/raw/master/f2b/filter.d/nginx-unauthorized.conf
    wget -c https://gitee.com/meimolihan/sh/raw/master/f2b/filter.d/nginx-bad-request.conf
    wget -c https://gitee.com/meimolihan/sh/raw/master/f2b/filter.d/nginx-pve.conf

    mkdir -p /var/log/nginx && touch /var/log/nginx/access.log /var/log/nginx/error.log
    mkdir -p /etc/nginx && touch /etc/nginx/nginx.conf

    echo -e ""
    log_info "下载 ${gl_bufan}Fail2Ban${gl_bai} 的"监狱"配置文件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    log_warn "保存至： ${gl_bufan}/etc/fail2ban/jail.d${gl_bai} "
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    cd /etc/fail2ban/jail.d
    wget -c https://gitee.com/meimolihan/sh/raw/master/f2b/jail.d/sshd.local
    wget -c https://gitee.com/meimolihan/sh/raw/master/f2b/jail.d/nginx-cc.conf
    sed -i "/cloudflare/d" /etc/fail2ban/jail.d/nginx-cc.conf

    echo -e ""
    log_info "配置 ${gl_bufan}Fail2Ban${gl_bai} 开机自启动 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    f2b_status
    f2b_autostart
    echo -e ""
    log_info "当前${gl_bufan}Fail2Ban${gl_bai} 服务状态"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    fail2ban-client -t && systemctl restart fail2ban && systemctl status fail2ban
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

fail2ban_update() {
    clear
    echo -e "${gl_zi}>>> 更新防御程序${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    update_fail2ban
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

remove() {
    if [ $# -eq 0 ]; then
        echo "未提供软件包参数!"
        return 1
    fi

    for package in "$@"; do
        echo -e ""
        echo -e "${gl_huang}>>> 正在卸载： ${gl_huang}$package ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        if command -v dnf &>/dev/null; then
            dnf remove -y "$package"
        elif command -v yum &>/dev/null; then
            yum remove -y "$package"
        elif command -v apt &>/dev/null; then
            apt purge -y "$package"
        elif command -v apk &>/dev/null; then
            apk del "$package"
        elif command -v pacman &>/dev/null; then
            pacman -Rns --noconfirm "$package"
        elif command -v zypper &>/dev/null; then
            zypper remove -y "$package"
        elif command -v opkg &>/dev/null; then
            opkg remove "$package"
        elif command -v pkg &>/dev/null; then
            pkg delete -y "$package"
        else
            echo -e "${gl_huang}未知的包管理器!${gl_bai}"
            return 1
        fi
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    done
}

fail2ban_uninstall() {
    echo -e ""
    echo -e "${gl_zi}>>> 卸载防御程序 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}确定要卸载 Fail2Ban 防御程序吗？ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" yn
    case "$yn" in
    [Yy]) 
        clear
        echo -e ""
        remove fail2ban
        rm -rf /etc/fail2ban
        crontab -l | grep -v "CF-Under-Attack.sh" | crontab - 2>/dev/null
        log_ok "Fail2Ban防御程序已卸载"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        ;;
    0) cancel_return; return ;;
    *)
        echo -e "${gl_huang}已取消卸载${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        exit_animation
        return
        ;;
    esac
}

web_security() {
    while true; do
        root_use
        check_f2b_status
        check_waf_status
        check_cf_mode
        f2b_autostart
        clear
        echo -e "${gl_zi}>>> Fail2Ban 安全防御管理${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        boot_en=$(systemctl is-enabled fail2ban 2>/dev/null)
        case "$boot_en" in
        enabled) boot_zh="${gl_lv}已开启" ;;
        disabled) boot_zh="${gl_hui}已禁用" ;;
        *) boot_zh="${gl_hui}未知" ;;
        esac
        echo -e "${gl_bai}网站防御程序自启动：${boot_zh}"

        fb_ver=$(fail2ban-client version 2>/dev/null || echo -e "${gl_hui}未安装")
        echo -e "${gl_bai}网站防御程序版本号：${gl_lv}${fb_ver}"

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}停止防御程序          ${gl_bufan}2.  ${gl_bai}启动防御程序"
        echo -e "${gl_bufan}3.  ${gl_bai}重启防御程序          ${gl_bufan}4.  ${gl_bai}检查服务状态"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}5.  ${gl_bai}查看SSH拦截记录       ${gl_bufan}6.  ${gl_bai}查看网站拦截记录"
        echo -e "${gl_bufan}7.  ${gl_bai}查看防御规则列表      ${gl_bufan}8.  ${gl_bai}查看日志实时监控"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}11. ${gl_bai}配置黑名单            ${gl_bufan}12. ${gl_bai}查看所有封禁的IP"
        echo -e "${gl_bufan}13. ${gl_bai}手动永久封禁IP        ${gl_bufan}14. ${gl_bai}手动解除封禁的IP"
        echo -e "${gl_bufan}15. ${gl_bai}清空所有封禁的IP      ${gl_bufan}16. ${gl_bai}配置文件管理器"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}17. ${gl_bai}配置白名单            ${gl_bufan}18. ${gl_bai}查看所有解封的IP"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}21. ${gl_bai}cloudflare模式        ${gl_bufan}22. ${gl_bai}高负载开启5秒盾"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}31. ${gl_bai}开启WAF               ${gl_bufan}32. ${gl_bai}关闭WAF"
        echo -e "${gl_bufan}33. ${gl_bai}开启DDOS防御          ${gl_bufan}34. ${gl_bai}关闭DDOS防御"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}41. ${gl_bai}更新防御程序          ${gl_bufan}42. ${gl_bai}防火墙管理"
        echo -e "${gl_bufan}b.  ${gl_bai}备份防御程序          ${gl_bufan}r.  ${gl_bai}恢复防御程序"
        echo -e "${gl_lv}66. ${gl_bai}安装防御程序          ${gl_hong}99. ${gl_bai}卸载防御程序"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单        ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "请输入你的选择: " sub_choice

        case $sub_choice in
        1)  fail2ban_stop ;;
        2)  fail2ban_start ;;
        3)  fail2ban_restart ;;
        4)  fail2ban_status ;;
        5)  fail2ban_ssh_logs ;;
        6)  fail2ban_web_logs ;;
        7)  fail2ban_rules_list ;;
        8)  tail -f /var/log/fail2ban.log ;;
        11) fail2ban_edit_blacklist ;;
        12) fail2ban_view_banned_ips ;;
        13) fail2ban_ban_ip_manual ;;
        14) fail2ban_unban_ip_manual ;;
        15) fail2ban_clear_all_bans ;;
        16) fail2ban_config_manager ;;
        17) fail2ban_edit_whitelist ;;
        18) fail2ban_view_whitelist ;;
        21) fail2ban_config_cloudflare ;;
        22) fail2ban_auto_under_attack ;;
        31) fail2ban_nginx_waf_on ;;
        32) fail2ban_nginx_waf_off ;;
        33) enable_ddos_defense ;;
        34) disable_ddos_defense ;;
        41) fail2ban_update ;;
        42) iptables_manager ;;
        b | B)  fail2ban_backup_config ;;
        r | R)  fail2ban_restore_config ;;
        66) fail2ban_install ;;
        99) fail2ban_uninstall ;;
        0) cancel_return "已经是主菜单"; web_security ;;
        00 | 000 | 0000) exit_script ;;
        *) handle_invalid_input ;;
        esac
    done
}

web_security