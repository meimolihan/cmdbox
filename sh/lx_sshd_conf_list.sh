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

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    read -r -n 1 -s -r -p ""
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

list_beautify_linux_sshd_config() {
    {
        grep -vE '^#|^$' /etc/ssh/sshd_config | awk -v gray="$gl_hui" -v green="$gl_lv" \
            -v yellow="$gl_huang" -v blue="$gl_lan" -v purple="$gl_zi" -v reset="$reset" '
        BEGIN {
            info["Port"] = "SSH服务端口"
            info["ListenAddress"] = "监听IP地址"
            info["Protocol"] = "SSH协议版本"
            info["HostKey"] = "主机密钥文件路径"
            info["PermitRootLogin"] = "是否允许root登录"
            info["PasswordAuthentication"] = "是否开启密码认证"
            info["PubkeyAuthentication"] = "是否开启公钥认证"
            info["AuthorizedKeysFile"] = "公钥授权文件位置"
            info["Subsystem"] = "系统子服务（一般为SFTP）"
            info["UsePAM"] = "是否启用PAM认证"
            info["X11Forwarding"] = "是否开启图形界面转发"
            info["PrintMotd"] = "登录是否显示提示信息"
            info["ClientAliveInterval"] = "客户端心跳检测间隔(秒)"
            info["ClientAliveCountMax"] = "客户端最大心跳超时次数"
            info["AllowUsers"] = "允许登录的用户列表"
            info["DenyUsers"] = "禁止登录的用户列表"
            info["AllowGroups"] = "允许登录的用户组"
            info["DenyGroups"] = "禁止登录的用户组"
            info["ChallengeResponseAuthentication"] = "挑战响应式认证"
            info["GSSAPIAuthentication"] = "GSSAPI统一认证"
            info["KerberosAuthentication"] = "Kerberos票据认证"
            info["LogLevel"] = "日志记录级别"
            info["MaxAuthTries"] = "最大密码错误次数"
            info["MaxSessions"] = "最大同时连接会话数"
            info["TCPKeepAlive"] = "是否开启TCP连接保活"
            info["PermitEmptyPasswords"] = "是否允许空密码登录"
            info["StrictModes"] = "是否开启权限严格检查"
            info["AcceptEnv"] = "允许接收的客户端环境变量"
            info["Ciphers"] = "SSH加密算法套件"
            info["MACs"] = "消息校验算法"
            info["KexAlgorithms"] = "密钥交换算法"
            info["Match"] = "条件匹配规则配置"

            print gray "配置项名称\t参数值\t中文说明" reset
            print gray "----------\t--------\t-------------------------" reset
        }
        {
            key = $1
            val = substr($0, index($0, $2))
            gsub(/^[ \t]+|[ \t]+$/, "", val)

            if (key == "Port" || key == "ListenAddress") color = purple
            else color = green

            desc = (key in info) ? info[key] : "其他SSH配置项"

            print color key "\t" yellow val "\t" blue desc reset
        }' | column_if_available
    }
}

list_beautify_all() {
    clear
    echo -e "${gl_zi}>>> 美化SSH配置列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_linux_sshd_config
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all