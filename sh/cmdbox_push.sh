#!/bin/bash
set -e

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
log_error() { echo -e "${gl_hong}[错误]${gl_bai} $*" >&2; }

root_use() {
    clear
    if [ "$EUID" -ne 0 ]; then
        echo -e "\n${gl_zi}>>> ROOT登录检查${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}提示: ${gl_bai}该功能需要root用户才能运行！"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return 1
    fi
    return 0
}

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n 1 -s -p ""
    echo ""
    clear
}

sleep_fractional() {
    local seconds=$1
    if sleep "$seconds" 2>/dev/null; then return 0; fi
    if command -v python3 >/dev/null 2>&1; then python3 -c "import time; time.sleep($seconds)"; return 0; fi
    sleep "$seconds"
}

# ==============================================
# 接收命令行参数：第1个参数=源码目录，第2个参数=目标目录
# 不传参则使用默认路径
# ==============================================
SOURCE_DIR="${1:-/home/mobufan/桌面/cmdbox-main}"
TARGET_DIR="${2:-/home/mobufan/桌面/cmdbox}"
GIT_PUSH_URL="https://gitee.com/meimolihan/cmdbox/raw/master/sh/git_push.sh"

clear
root_use
echo -e "${gl_zi}>>> CmdBox 自动部署工具${gl_bai}"
echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
echo -e "  ${gl_bai}源码仓库：${gl_huang}${SOURCE_DIR} ${gl_bai} "
echo -e "  ${gl_bai}项目仓库：${gl_lv}${TARGET_DIR}${gl_bai}"
echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    log_info "Node.js & npm 已安装，跳过安装步骤"
else
    log_info "开始安装 Node.js & npm 依赖"
    sudo apt update -y
    sudo apt install -y nodejs npm
    log_ok "Node 环境安装完成"
fi

echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
log_info "进入项目目录：${gl_huang}$SOURCE_DIR${gl_bai}"
cd "${SOURCE_DIR}" || {
    log_error "源码目录不存在，部署终止"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
    exit 1
}

log_info "执行项目构建：${gl_lv}npm install${gl_bai} && ${gl_lv}npm run build${gl_bai}"
npm install
npm run build
log_ok "项目构建完成"

echo -e ""
echo -e "${gl_huang}>>> 清理目标目录旧文件${gl_bai}"
echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
cd "${TARGET_DIR}" || {
    log_error "目标目录不存在，部署终止"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
    exit 1
}
rm -rf 404.html all.html c contributors.html css hot.html img index.html js list.html script-list.html
log_ok "旧文件清理完成"

echo -e ""
echo -e "${gl_huang}>>> 复制新构建产物${gl_bai}"
echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
cd "${SOURCE_DIR}/.deploy"
cp -r ./* "${TARGET_DIR}/"
log_ok "文件复制完成"

echo -e ""
echo -e "${gl_huang}>>> 执行 Git 自动推送${gl_bai}"
echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
bash <(curl -sL "${GIT_PUSH_URL}") "${TARGET_DIR}"
