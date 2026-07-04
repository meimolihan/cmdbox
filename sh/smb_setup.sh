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
    export gl_cheng=$'\033[38;5;208m'
    export reset=$'\033[0m'
}
list_color_init

log_info()  { echo -e "${gl_lan}[信息]${gl_bai} $*"; }
log_ok()    { echo -e "${gl_lv}[成功]${gl_bai} $*"; }
log_warn()  { echo -e "${gl_huang}[警告]${gl_bai} $*"; }
log_error() { echo -e "${gl_hong}[错误]${gl_bai} $*" >&2; }

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    read -r -n 1 -s -r -p ""
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

exit_animation() {
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

config_samba_share() {
    local share_dir samba_user samba_pass share_name
    local ip_address user_created
    local samba_pass_confirm

    install_samba() {
        log_info "正在检查并安装 Samba 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        if command -v smbd &>/dev/null && command -v nmbd &>/dev/null; then
            log_ok "Samba 已安装，跳过安装步骤"
            return 0
        fi
        if command -v apt &>/dev/null; then
            apt update && apt install samba samba-common-bin -y
        elif command -v yum &>/dev/null; then
            yum install samba samba-client samba-common -y
        elif command -v dnf &>/dev/null; then
            dnf install samba samba-client samba-common -y
        elif command -v pacman &>/dev/null; then
            pacman -S samba --noconfirm
        elif command -v zypper &>/dev/null; then
            zypper install samba samba-client -y
        else
            log_error "不支持的包管理器，请手动安装 Samba"
            return 1
        fi
        clear
        echo -e "${gl_zi}>>> 检查Samba配置${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        if [ $? -eq 0 ]; then
            log_ok "Samba 服务安装完成"
            return 0
        else
            log_error "Samba 安装失败"
            return 1
        fi
    }

    check_samba_config() {
        log_info "检查Samba配置完整性 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        if [ ! -f "/etc/samba/smb.conf.bak" ]; then
            cp -f /etc/samba/smb.conf /etc/samba/smb.conf.bak 2>/dev/null
        fi
        if ! testparm -s /etc/samba/smb.conf 2>&1 | grep -q "Loaded services file OK"; then
            log_warn "Samba配置存在问题，创建基本配置"
            cat >/etc/samba/smb.conf <<'EOF'
[global]
    workgroup = WORKGROUP
    log file = /var/log/samba/log.%m
    max log size = 1000
    logging = file
    panic action = /usr/share/samba/panic-action %d
    server role = standalone server
    obey pam restrictions = yes
    unix password sync = yes
    passwd program = /usr/bin/passwd %u
    passwd chat = *Enter\snew\s*\spassword:* %n\n *Retype\snew\s*\spassword:* %n\n *password\supdated\ssuccessfully* .
    pam password change = yes
    map to guest = bad user
    usershare allow guests = yes
[homes]
    comment = Home Directories
    browseable = no
    read only = yes
    create mask = 0700
    directory mask = 0700
    valid users = %S
[printers]
    comment = All Printers
    browseable = no
    path = /var/tmp
    printable = yes
    guest ok = no
    read only = yes
    create mask = 0700
[print$]
    comment = Printer Drivers
    path = /var/lib/samba/printers
    browseable = yes
    read only = yes
    guest ok = no
EOF
            log_ok "已创建基本Samba配置"
        fi
        if testparm -s /etc/samba/smb.conf &>/dev/null; then
            log_ok "Samba配置语法正确"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            return 0
        else
            log_error "无法修复Samba配置，请手动检查"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            return 1
        fi
    }

    init_samba_db() {
        log_info "初始化Samba用户数据库 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        mkdir -p /var/lib/samba/private
        mkdir -p /var/log/samba
        if command -v systemctl &>/dev/null; then
            systemctl restart smbd nmbd 2>/dev/null
        fi
        sleep_fractional 2
        return 0
    }

    set_samba_password() {
        local user="$1"
        local pass_set=false
        if ! id "$user" &>/dev/null; then
            log_error "系统用户 '$user' 不存在"
            return 1
        fi
        if ! check_samba_config; then
            return 1
        fi
        init_samba_db
        while true; do
            echo
            read -r -s -p "$(echo -e "${gl_bai}为 ${gl_huang}$user${gl_bai} 设置Samba密码: ")" samba_pass
            echo
            if [[ -z "$samba_pass" ]]; then
                read -r -p "$(echo -e "${gl_huang}密码为空，是否继续? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" empty_pass
                [[ $empty_pass =~ ^[Yy]$ ]] && {
                    samba_pass=""
                    break
                }
                continue
            fi
            read -r -s -p "$(echo -e "${gl_bai}请确认密码: ")" samba_pass_confirm
            echo
            if [[ "$samba_pass" != "$samba_pass_confirm" ]]; then
                log_error "两次输入的密码不一致，请重新输入！"
            elif [[ ${#samba_pass} -lt 3 ]]; then
                log_error "密码长度至少3位！"
            else
                pass_set=true
                break
            fi
        done
        if $pass_set; then
            log_info "正在设置Samba用户密码 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            local password_set=false
            if [[ -n "$samba_pass" ]]; then
                if echo -e "$samba_pass\n$samba_pass" | smbpasswd -a -s "$user" 2>/dev/null; then
                    password_set=true
                elif command -v pdbedit &>/dev/null; then
                    if (
                        echo "$samba_pass"
                        echo "$samba_pass"
                    ) | pdbedit -a -u "$user" 2>/dev/null; then
                        password_set=true
                    fi
                else
                    if smbpasswd -a "$user" <<EOF; then
$samba_pass
$samba_pass
EOF
                        password_set=true
                    fi
                fi
                if $password_set; then
                    log_ok "Samba 用户 '${gl_lv}$user${gl_bai}' 密码已设置"
                else
                    log_warn "标准方法失败，尝试修复数据库"
                    systemctl stop smbd nmbd 2>/dev/null
                    rm -f /var/lib/samba/private/passdb.tdb
                    systemctl start smbd nmbd 2>/dev/null
                    sleep_fractional 2
                    if echo -e "$samba_pass\n$samba_pass" | smbpasswd -a -s "$user" 2>/dev/null; then
                        log_ok "Samba 用户 '${gl_lv}$user${gl_bai}' 密码已设置（修复后）"
                        password_set=true
                    else
                        log_error "设置Samba密码失败"
                        echo -e "${gl_bai}请手动执行以下命令:"
                        echo -e "${gl_huang}  smbpasswd -a $user${gl_bai}"
                        return 1
                    fi
                fi
            else
                if smbpasswd -a "$user" <<<$'\n\n' 2>/dev/null; then
                    smbpasswd -n "$user" 2>/dev/null
                    log_warn "Samba 用户 '${gl_lv}$user${gl_bai}' 已设置为空密码访问（不推荐）"
                    password_set=true
                fi
            fi
            if $password_set; then
                if pdbedit -L 2>/dev/null | grep -q "^$user:" || smbpasswd -e "$user" 2>/dev/null; then
                    log_ok "Samba 用户 '${gl_lv}$user${gl_bai}' 已成功添加到数据库"
                    return 0
                else
                    log_warn "用户可能未正确添加，但继续配置"
                    return 0
                fi
            else
                return 1
            fi
        fi
        return 0
    }

    configure_firewall() {
        if command -v ufw &>/dev/null && ufw status | grep -q "active"; then
            log_info "配置 UFW 防火墙规则"
            ufw allow samba 2>/dev/null && log_ok "UFW 规则已添加"
            ufw reload 2>/dev/null && log_ok "UFW 规则已重新载入"
        elif command -v firewall-cmd &>/dev/null && systemctl is-active firewalld &>/dev/null; then
            log_info "配置 firewalld 防火墙规则"
            firewall-cmd --permanent --add-service=samba 2>/dev/null &&
                firewall-cmd --reload 2>/dev/null &&
                log_ok "firewalld 规则已添加"
        elif command -v iptables &>/dev/null; then
            log_info "添加 iptables 规则"
            iptables -A INPUT -p tcp --dport 139 -j ACCEPT 2>/dev/null
            iptables -A INPUT -p tcp --dport 445 -j ACCEPT 2>/dev/null
            iptables -A INPUT -p udp --dport 137 -j ACCEPT 2>/dev/null
            iptables -A INPUT -p udp --dport 138 -j ACCEPT 2>/dev/null
            log_ok "iptables 规则已添加"
        fi
    }

    if ! install_samba; then
        return 1
    fi
    if ! check_samba_config; then
        log_error "Samba配置检查失败"
        return 1
    fi
    clear
    echo -e "${gl_zi}>>> 设置共享目录${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    while true; do
        read -r -p "$(echo -e "${gl_bai}请输入共享目录路径 (默认为${gl_lv}/mnt${gl_bai})(${gl_huang}0${gl_bai}返回) : ")" share_dir
        [[ "$share_dir" == "0" ]] && { cancel_return; return 1; }
        share_dir=${share_dir:-/mnt}
        share_dir=$(realpath -m "$share_dir" 2>/dev/null || echo "$share_dir")
        if [[ ! $share_dir =~ ^/ ]]; then
            log_error "目录必须以 / 开头"
            continue
        fi
        if [ -e "$share_dir" ] && [ ! -d "$share_dir" ]; then
            log_error "$share_dir 已存在但不是目录"
            continue
        fi
        break
    done
    mkdir -p "$share_dir" 2>/dev/null || {
        log_error "无法创建目录 $share_dir，请检查权限"
        return 1
    }
    chmod 2775 "$share_dir" 2>/dev/null
    log_ok "共享目录已创建: $share_dir"
    echo -e ""
    echo -e "${gl_zi}>>> 设置Samba用户${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    while true; do
        read -r -p "$(echo -e "${gl_bai}请输入Samba用户名 (默认为${gl_lv}$(whoami)${gl_bai})(${gl_huang}0${gl_bai}返回) : ")" samba_user
        [[ "$samba_user" == "0" ]] && { cancel_return; return 1; }
        samba_user=${samba_user:-$(whoami)}
        if [[ ! $samba_user =~ ^[a-z_][a-z0-9_-]*$ ]]; then
            log_error "用户名只能包含小写字母、数字、下划线和连字符，且必须以字母或下划线开头"
            continue
        fi
        break
    done
    user_created=false
    if ! id "$samba_user" &>/dev/null; then
        read -r -p "$(echo -e "${gl_bai}用户 '$samba_user' 不存在，是否创建? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" create_user
        if [[ $create_user =~ ^[Yy]$ ]]; then
            if useradd -m -s /sbin/nologin "$samba_user" 2>/dev/null; then
                user_created=true
                log_ok "系统用户 '$samba_user' 已创建"
            else
                log_error "创建用户失败，请检查权限或使用现有用户"
                return 1
            fi
        else
            log_error "用户不存在，操作取消"
            return 1
        fi
    else
        log_ok "使用现有系统用户: $samba_user"
    fi
    echo -e ""
    echo -e "${gl_zi}>>> 设置Samba密码${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    is_samba_user() {
        pdbedit -L 2>/dev/null | grep -q "^$1:" || smbpasswd -e "$1" 2>&1 | grep -q "Enabled"
    }
    if is_samba_user "$samba_user"; then
        read -r -p "$(echo -e "${gl_bai}用户 '$samba_user' 已经是Samba用户，是否重置密码? (${gl_hong}y${gl_bai}/${gl_lv}N${gl_bai}): ")" reset_pass
        if [[ $reset_pass =~ ^[Yy]$ ]]; then
            if ! set_samba_password "$samba_user"; then
                log_warn "密码重置失败，继续使用原有密码"
            fi
        else
            smbpasswd -e "$samba_user" 2>/dev/null && log_ok "Samba 用户 '${gl_lv}$samba_user${gl_bai}' 已启用，跳过密码设置"
        fi
    else
        if ! set_samba_password "$samba_user"; then
            log_error "密码设置失败，但继续配置（可以稍后手动设置）"
            read -r -p "$(echo -e "${gl_bai}是否继续配置共享? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" continue_setup
            if [[ ! $continue_setup =~ ^[Yy]$ ]]; then
                return 1
            fi
        fi
    fi
    echo -e ""
    echo -e "${gl_zi}>>> 修复共享目录 $share_dir 读写权限${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_huang}共享目录 $share_dir 中文件多，需要更多的时间修复，请耐心等待 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    chown -R "$samba_user":"$samba_user" "$share_dir" 2>/dev/null
    chmod -R 2770 "$share_dir" 2>/dev/null
    if command -v setfacl &>/dev/null; then
        setfacl -R -m "u:$samba_user:rwx" "$share_dir" 2>/dev/null
        setfacl -R -d -m "u:$samba_user:rwx" "$share_dir" 2>/dev/null
    fi
    echo -e "${gl_lv}共享目录 $share_dir 读写权限修复完成${gl_bai}"
    echo -e ""
    echo -e "${gl_zi}>>> 设置共享名称${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    default_share_name=$(basename "$share_dir")
    [[ -z $default_share_name || $default_share_name == "/" ]] && default_share_name="share"
    while true; do
        read -r -p "$(echo -e "${gl_bai}请输入共享名称 (默认为 ${gl_huang}$default_share_name${gl_bai}): ")" input_share
        share_name=${input_share:-$default_share_name}
        if [[ -z "$share_name" ]]; then
            log_error "共享名称不能为空"
            continue
        fi
        if grep -q "\[$share_name\]" /etc/samba/smb.conf 2>/dev/null; then
            read -r -p "$(echo -e "${gl_huang}共享名 '$share_name' 已存在，是否覆盖? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" overwrite
            if [[ $overwrite =~ ^[Yy]$ ]]; then
                sed -i "/^\[$share_name\]/,/^\[/ { /^\[$share_name\]/d; /^\[/q; d; }" /etc/samba/smb.conf 2>/dev/null
                break
            else
                continue
            fi
        else
            break
        fi
    done
    log_ok "共享名称设置为: $share_name"
    echo -e ""
    echo -e "${gl_zi}>>> 配置Samba服务${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_info "正在更新Samba配置 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    cp /etc/samba/smb.conf /etc/samba/smb.conf.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null
    cat >>/etc/samba/smb.conf <<EOF

[$share_name]
    comment = Samba Share Directory
    path = $share_dir
    browseable = yes
    writable = yes
    read only = no
    guest ok = no
    valid users = $samba_user
    force user = $samba_user
    force group = $samba_user
    create mask = 0775
    directory mask = 0775
    inherit permissions = yes
    inherit acls = yes
    ea support = yes
    store dos attributes = yes
EOF
    if testparm -s /etc/samba/smb.conf &>/dev/null; then
        log_ok "Samba 配置语法正确"
    else
        log_error "Samba 配置有误，使用备份恢复"
        cp /etc/samba/smb.conf.backup.* /etc/samba/smb.conf 2>/dev/null
        return 1
    fi
    log_info "正在启动Samba服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    configure_firewall
    if command -v systemctl &>/dev/null; then
        systemctl enable smbd nmbd 2>/dev/null
        if systemctl restart smbd nmbd 2>/dev/null; then
            log_ok "Samba 服务启动成功"
        else
            log_warn "Samba 服务重启失败，尝试直接启动"
            systemctl start smbd nmbd 2>/dev/null || {
                log_error "Samba 服务启动失败，请检查日志: journalctl -u smbd"
                return 1
            }
        fi
    elif command -v service &>/dev/null; then
        service smbd restart 2>/dev/null && service nmbd restart 2>/dev/null
        log_ok "Samba 服务重启完成"
    else
        log_warn "无法重启Samba服务，请手动执行:"
        echo -e "${gl_bai}  systemctl restart smbd nmbd${gl_bai}"
    fi
    ip_address=$(hostname -I 2>/dev/null | awk '{print $1}')
    [[ -z "$ip_address" ]] && ip_address=$(ip route get 1 2>/dev/null | awk '{print $7; exit}')
    [[ -z "$ip_address" ]] && ip_address=$(curl -s ifconfig.me 2>/dev/null || echo "服务器IP")
    echo -e ""
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_ok "Samba 共享配置完成！"
    echo -e "${gl_huang}Samba 共享信息${gl_bai}"
    echo -e "${gl_bai} 服务器IP:   ${gl_lv}$ip_address${gl_bai}"
    echo -e "${gl_bai} 共享目录:   ${gl_lv}$share_dir${gl_bai}"
    echo -e "${gl_bai} 共享名称:   ${gl_lv}$share_name${gl_bai}"
    echo -e "${gl_bai} 用户名:     ${gl_lv}$samba_user${gl_bai}"
    echo -e "${gl_bai} 工作组:     ${gl_lv}WORKGROUP${gl_bai}"
    echo -e ""
    echo -e "${gl_bai} Windows访问:    ${gl_lv}\\\\\\\\${ip_address}\\\\$share_name${gl_bai}"
    echo -e "${gl_bai} Linux/Mac访问: ${gl_lv}smb://${ip_address}/$share_name${gl_bai}"
    echo -e "${gl_bai} 命令行测试:    ${gl_lv}smbclient //${ip_address}/$share_name -U $samba_user${gl_bai}"
    echo -e ""
    echo -e "${gl_bai} 如果密码设置失败，请手动执行:"
    echo -e "   ${gl_huang}smbpasswd -a $samba_user${gl_bai}"
    echo -e "   ${gl_huang}pdbedit -L  ${gl_bai}(查看用户列表)"
    echo -e ""
    echo -e "${gl_bai}提示: 如果无法连接，请检查防火墙设置${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

config_samba_share