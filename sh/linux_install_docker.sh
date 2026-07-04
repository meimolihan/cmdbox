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

install_add_docker_cn() {
    local country
    country=$(curl -s ipinfo.io/country 2>/dev/null || echo "US")
    
    # 修复：先创建目录，防止写入失败
    mkdir -p /etc/docker

    if [ "$country" = "CN" ]; then
        log_info "检测到中国地区，配置国内镜像加速"
        cat >/etc/docker/daemon.json <<EOF
{
  "registry-mirrors": [
    "https://docker.1ms.run",
    "https://docker.m.ixdev.cn",
    "https://hub.rat.dev",
    "https://dockerproxy.net",
    "https://docker-registry.nmqu.com",
    "https://docker.amingg.com",
    "https://docker.hlmirror.com",
    "https://hub1.nat.tf",
    "https://hub2.nat.tf",
    "https://hub3.nat.tf",
    "https://docker.m.daocloud.io",
    "https://docker.kejilion.pro",
    "https://docker.367231.xyz",
    "https://hub.1panel.dev",
    "https://dockerproxy.cool",
    "https://docker.apiba.cn",
    "https://proxy.vvvv.ee"
  ]
}
EOF
    else
        log_info "非中国地区，不配置国内镜像"
        rm -f /etc/docker/daemon.json 2>/dev/null
    fi

    echo -e ""
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    if command -v systemctl &>/dev/null; then
        systemctl enable docker >/dev/null 2>&1
        systemctl daemon-reload >/dev/null 2>&1
        systemctl restart docker >/dev/null 2>&1
        log_ok "Docker 已设置开机自启并重启完成"
    else
        log_warn "无 systemctl，跳过服务自启设置"
    fi
}

install_add_docker_guanfang() {
    local country
    country=$(curl -s ipinfo.io/country 2>/dev/null || echo "US")
    
    if [ "$country" = "CN" ]; then
        log_info "中国地区使用阿里云镜像安装 ${gl_huang}Docker${gl_bai}"
        cd ~ || return 1
        curl -sS -O https://raw.githubusercontent.com/kejilion/docker/main/install
        chmod +x install
        sh install --mirror Aliyun
        rm -f install
    else
        log_info "海外地区使用官方脚本安装"
        curl -fsSL https://get.docker.com | sh
    fi
    
    # 修复：安装后等待一下，让命令生效
    sleep_fractional 1
    install_add_docker_cn
}

install_add_docker() {
    clear
    echo -e "${gl_zi}>>> 安装 ${gl_huang}docker${gl_zi} 环境 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    read -r -e -p "${gl_bai}确定要安装 ${gl_huang}docker${gl_bai} 环境吗？ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): " confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${gl_huang}已取消安装操作${gl_bai}"
        exit_animation
        return
    fi

    log_info "开始检测系统并安装 ${gl_huang}Docker ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if [ -f /etc/os-release ] && grep -q "Fedora" /etc/os-release; then
        log_info "检测到 ${gl_huang}Fedora${gl_bai} 系统"
        install_add_docker_guanfang

    elif command -v dnf &>/dev/null; then
        log_info "检测到 ${gl_huang}RHEL 系系统${gl_bai} (dnf)"
        dnf update -y
        dnf install -y yum-utils device-mapper-persistent-data lvm2
        rm -f /etc/yum.repos.d/docker*.repo 2>/dev/null
        
        country=$(curl -s ipinfo.io/country 2>/dev/null || echo "US")
        if [ "$country" = "CN" ]; then
            curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo | tee /etc/yum.repos.d/docker-ce.repo >/dev/null
        else
            yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo >/dev/null
        fi
        
        dnf install -y docker-ce docker-ce-cli containerd.io
        install_add_docker_cn

    elif [ -f /etc/os-release ] && grep -q "Kali" /etc/os-release; then
        log_info "检测到 ${gl_huang}Kali Linux${gl_bai} 系统"
        apt update
        apt upgrade -y
        apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
        mkdir -p /etc/apt/keyrings
        
        country=$(curl -s ipinfo.io/country 2>/dev/null || echo "US")
        arch=$(uname -m)
        
        if [ "$country" = "CN" ]; then
            curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker-archive-keyring.gpg >/dev/null
            if [ "$arch" = "x86_64" ]; then
                echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker-archive-keyring.gpg] https://mirrors.aliyun.com/docker-ce/linux/debian bullseye stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null
            elif [ "$arch" = "aarch64" ]; then
                echo "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker-archive-keyring.gpg] https://mirrors.aliyun.com/docker-ce/linux/debian bullseye stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null
            fi
        else
            curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker-archive-keyring.gpg >/dev/null
            if [ "$arch" = "x86_64" ]; then
                echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian bullseye stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null
            elif [ "$arch" = "aarch64" ]; then
                echo "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian bullseye stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null
            fi
        fi
        
        apt update
        apt install -y docker-ce docker-ce-cli containerd.io
        install_add_docker_cn

    elif command -v apt &>/dev/null || command -v yum &>/dev/null; then
        log_info "检测到 ${gl_huang}Debian/Ubuntu/CentOS${gl_bai} 通用系统"
        install_add_docker_guanfang

    else
        log_warn "未知系统，尝试直接安装 Docker"
        apt install -y docker.io docker-compose || yum install -y docker docker-compose
        install_add_docker_cn
    fi

    # 修复：检查是否安装成功
    if ! command -v docker &>/dev/null; then
        log_error "Docker 安装失败！"
        return 1
    fi

    local ver
    ver=$(docker --version | awk '{print $3}' | sed 's/,//g')
    log_ok "Docker 版本：${gl_lv}$ver${gl_bai}"
    log_ok "Docker 环境安装完成！"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
}

install_add_docker
