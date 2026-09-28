
#!/bin/bash
set -uo pipefail

# ====================== 【可自定义配置区】 在这里修改所有默认参数 ======================
# 项目标题
DEFAULT_TITLE="fan-image-tr 图片批量处理工具 一键部署"

# 部署目录（不传参时的默认路径）
DEFAULT_COMPOSE_DIR="/vol1/1000/compose/fan-image-tr"

# 默认访问端口（不传参时使用）
DEFAULT_PORT="8791"

# 默认容器名称（可自定义）
DEFAULT_CONTAINER_NAME="fan-image-tr"

# 源码仓库地址（项目当前未发布公共镜像，默认拉取源码本地构建）
DEFAULT_REPO_URL="https://github.com/meimolihan/fan-image-tr.git"

# 镜像名：留空 = 从源码仓库拉取并本地构建（推荐，amd64/arm64 通用）
# 若日后发布了公共镜像，可直接填写镜像名跳过构建，例如 mobufan/fan-image-tr:latest
DEFAULT_IMAGE=""

# 图片库挂载目录（只读挂载到容器 /photos，供浏览与转码读取）
DEFAULT_MEDIA_DIR="/vol2/1000/mydisk/Photo"

# 转换并发数（QSV/NVENC 等硬编码流水线建议不超过显卡并行能力）
DEFAULT_WORKER="2"
# ====================================================================================

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
    read -r -n 1 -s -p ""
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

exit_animation() {
    echo -ne "${gl_lv}即将退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo ""
    clear
}

exit_script() {
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local dots=(
        "${gl_hong}."
        "${gl_huang}."
        "${gl_lv}."
        "${gl_bufan}."
        "${gl_zi}."
    )
    local dot_buffer=""
    local frame_len=${#frames[@]}
    local dot_idx=0
    local total_dots=${#dots[@]}


    for ((i=0; i<20; i++)); do
        if (( i > 0 && i % 3 == 0 && dot_idx < total_dots )); then
            dot_buffer+=${dots[$dot_idx]}
            ((dot_idx++))
        fi
        echo -ne "\r\033[K${gl_bufan}${frames[i % frame_len]}${gl_bai} 正在部署 ${dot_buffer}"
        sleep_fractional 0.06
    done
    echo -e "\r\033[K${gl_lv}✓${gl_bai} 成功退出\n"
    clear
    exit 0
}

column_if_available() {
    if command -v column &> /dev/null; then
        column -t -s $'\t'
    else
        cat
    fi
}

root_use() {
    clear
    if [ "$EUID" -ne 0 ]; then
        echo -e "\n${gl_zi}>>> ROOT登录检查 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}提示: ${gl_bai}该功能需要root用户才能运行！"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return 1
    fi
    return 0
}

check_and_open_port() {
    local PORT="$1"
    if [[ -z "$PORT" ]]; then
        log_error "未指定端口"
        return 1
    fi

    log_info "检查端口 ${gl_huang}${PORT}${gl_bai} 是否放行 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

    # 检查端口是否已放行
    if iptables -L INPUT -n 2>/dev/null | grep -qE "dpt:${PORT}[[:space:]]|dpt:${PORT}$" 2>/dev/null; then
        log_ok "端口 ${PORT} 已放行，无需操作"
        return 0
    fi

    log_warn "端口 ${gl_hong}${PORT}${gl_bai} 未放行，正在开放 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

    # 开放端口
    iptables -I INPUT -p tcp --dport "${PORT}" -j ACCEPT 2>/dev/null
    iptables -I INPUT -p udp --dport "${PORT}" -j ACCEPT 2>/dev/null

    log_info "保存防火墙规则 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

    # 方法1: 使用 iptables-save 保存到文件（最可靠，不会卡住）
    local SAVED=0
    if command -v iptables-save >/dev/null 2>&1; then
        mkdir -p /etc/iptables 2>/dev/null
        if iptables-save > /etc/iptables/rules.v4 2>/dev/null; then
            log_ok "IPv4 规则已保存到 /etc/iptables/rules.v4"
            SAVED=1
        fi
        if command -v ip6tables-save >/dev/null 2>&1; then
            ip6tables-save > /etc/iptables/rules.v6 2>/dev/null
        fi
    fi

    # 方法2: 尝试使用 netfilter-persistent（带超时，避免卡住）
    if command -v netfilter-persistent >/dev/null 2>&1; then
        log_info "尝试 netfilter-persistent 保存..."
        (
            timeout 5 netfilter-persistent save >/dev/null 2>&1
        ) &
        local SAVE_PID=$!
        local WAIT=0
        while kill -0 $SAVE_PID 2>/dev/null && [ $WAIT -lt 6 ]; do
            sleep 1
            WAIT=$((WAIT + 1))
        done
        if kill -0 $SAVE_PID 2>/dev/null; then
            kill -9 $SAVE_PID 2>/dev/null
            log_warn "netfilter-persistent 保存超时，已跳过"
        else
            wait $SAVE_PID 2>/dev/null
            if [ $? -eq 0 ]; then
                log_ok "netfilter-persistent 保存成功"
                SAVED=1
            fi
        fi
    fi

    # 方法3: 尝试使用 service iptables save（带超时）
    if [ $SAVED -eq 0 ] && command -v service >/dev/null 2>&1; then
        if service iptables status >/dev/null 2>&1; then
            log_info "尝试 service iptables save..."
            (
                timeout 5 service iptables save >/dev/null 2>&1
            ) &
            local SAVE_PID=$!
            local WAIT=0
            while kill -0 $SAVE_PID 2>/dev/null && [ $WAIT -lt 6 ]; do
                sleep 1
                WAIT=$((WAIT + 1))
            done
            if kill -0 $SAVE_PID 2>/dev/null; then
                kill -9 $SAVE_PID 2>/dev/null
                log_warn "service iptables save 超时"
            else
                wait $SAVE_PID 2>/dev/null
                if [ $? -eq 0 ]; then
                    log_ok "service iptables save 成功"
                    SAVED=1
                fi
            fi
        fi
    fi

    # 方法4: 尝试使用 iptables-persistent（Debian/Ubuntu）
    if [ $SAVED -eq 0 ] && command -v iptables-save >/dev/null 2>&1 && [ -f /etc/iptables/rules.v4 ]; then
        log_info "iptables 规则已通过文件备份: /etc/iptables/rules.v4"
        log_info "重启后如需恢复规则，可执行: iptables-restore < /etc/iptables/rules.v4"
        SAVED=1
    fi

    if [ $SAVED -eq 0 ]; then
        log_warn "无法自动持久化保存规则，但端口已临时开放"
        log_info "如需永久保存，请手动执行: iptables-save > /etc/iptables/rules.v4"
    fi

    log_ok "端口 ${gl_lv}${PORT}${gl_bai} 已开放"
}

check_port_available() {
    local PORT="$1"
    if ss -tuln | grep -q ":${PORT} "; then
        return 1
    elif netstat -tuln 2>/dev/null | grep -q ":${PORT} "; then
        return 1
    else
        return 0
    fi
}

get_free_port() {
    local start_port=$1
    local port=$start_port
    while ! check_port_available $port; do
        port=$((port + 1))
        if [ $port -gt $((start_port + 100)) ]; then
            echo ""
            return 1
        fi
    done
    echo $port
}

docker-ps-cn() {
    {
        local filter_name="$1"
        local docker_filter=""

        if [ -n "$filter_name" ]; then
            docker_filter="--filter name=${filter_name}"
        fi

        printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "容器ID" "名称" "状态" "端口" "创建时间" "镜像" "$reset"
        printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "----------" "----------" "----------" "----------" "----------" "----------" "$reset"

        docker ps ${docker_filter} --format "{{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.RunningFor}}\t{{.Image}}" | \
        awk -v green="$gl_lv" -v yellow="$gl_huang" -v cyan="$gl_bufan" -v blue="$gl_lan" -v white="$gl_bai" -v reset="$reset" -v gl_bai="$gl_bai" '
        BEGIN {FS="\t"; OFS="\t"}
        {
            id = substr($1, 1, 12)
            name = $2
            status = $3
            ports = $4
            time = $5
            image = $6

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
            gsub(/ second ago/, "秒前", time)
            gsub(/About /, "", time)

            print cyan id reset, green name reset, yellow status reset, blue ports reset, white time reset, gl_bai image reset
        }'
    } | column_if_available
}

git_check_env() {
    if ! command -v git &>/dev/null; then
        log_warn "Git 未安装，尝试安装 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        if command -v apt-get &>/dev/null; then
            apt-get update -qq >/dev/null 2>&1
            apt-get install -y -qq git >/dev/null 2>&1
        elif command -v dnf &>/dev/null; then
            dnf install -y -q git >/dev/null 2>&1
        elif command -v yum &>/dev/null; then
            yum install -y -q git >/dev/null 2>&1
        elif command -v apk &>/dev/null; then
            apk add --no-cache git >/dev/null 2>&1
        fi
    fi
    if ! command -v git &>/dev/null; then
        log_error "Git 安装失败，请手动安装后重试！"
        return 1
    fi
    log_ok "Git 环境就绪"
}

docker_check_env() {
    if ! command -v docker &>/dev/null; then
        log_info "正在检查 Docker 运行环境 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        log_warn "Docker 未安装，即将自动安装 Docker 环境 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        bash <(curl -sL gitee.com/meimolihan/cmdbox/raw/master/sh/lx_install_docker.sh)

        if ! command -v docker &>/dev/null; then
            log_error "Docker 安装失败，请手动安装后重试！"
            sleep 1
            exit 1
        fi
        log_ok "Docker 安装成功！"
    fi

    if ! command -v docker-compose &>/dev/null; then
        echo -e ""
        log_info "正在检查 Docker Compose 环境 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        log_warn "Docker Compose 未安装，即将自动安装 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        bash <(curl -sL gitee.com/meimolihan/cmdbox/raw/master/sh/lx_install_compose.sh)

        if ! command -v docker-compose &>/dev/null; then
            log_error "Docker Compose 安装失败，请手动安装后重试！"
            sleep 1
            exit 1
        fi
        log_ok "Docker Compose 安装成功！"
    fi
}

# sync_repo 同步源码仓库：已有克隆则快进更新，否则浅克隆最新代码
sync_repo() {
    local SRC_DIR="$1"

    if [ -d "${SRC_DIR}/.git" ]; then
        log_info "检测到已有源码，正在更新到最新版本 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        if git -C "${SRC_DIR}" pull --ff-only >/dev/null 2>&1; then
            log_ok "源码更新完成"
        else
            log_warn "源码更新失败（可能有本地改动），继续使用现有源码"
        fi
        return 0
    fi

    if [ -d "${SRC_DIR}" ] && [ -n "$(ls -A "${SRC_DIR}" 2>/dev/null)" ]; then
        log_warn "目录 ${gl_huang}${SRC_DIR}${gl_bai} 已存在且非 Git 仓库，跳过源码拉取"
        return 0
    fi

    log_info "正在拉取源码：${gl_huang}${DEFAULT_REPO_URL}${gl_bai}"
    if git clone --depth 1 "${DEFAULT_REPO_URL}" "${SRC_DIR}"; then
        log_ok "源码拉取完成"
        return 0
    fi

    log_error "源码拉取失败，请检查网络或手动放置源码到 ${gl_huang}${SRC_DIR}${gl_bai}"
    return 1
}

clean_old_container() {
    if [ $# -eq 0 ]; then
        log_warn "未传入任何容器名称参数，跳过清理"
        return 1
    fi

    local targets=("$@")

    echo -e ""
    echo -e "${gl_huang}>>> 清理容器与相关镜像（目标：${targets[*]}）${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    for container_name in "${targets[@]}"; do
        if docker ps -a --filter "name=^/${container_name}$" --format "{{.Names}}" | grep -q "^${container_name}$"; then
            log_info "检测到容器 ${gl_huang}${container_name}${gl_bai}，正在停止并删除 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            docker rm -f "${container_name}" >/dev/null 2>&1
            log_ok "容器 ${container_name} 清理完成"
        else
            log_ok "容器 ${container_name} 不存在，跳过"
        fi
    done

    log_info "开始模糊清理相关镜像（关键词：${targets[*]}） ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    local image_ids=$(docker images --format "{{.ID}}" | grep -f <(printf "%s\n" "${targets[@]}" | sed 's/^/-i /;s/ / -i /g'))
    if [ -n "$image_ids" ]; then
        echo "$image_ids" | xargs docker rmi -f >/dev/null 2>&1
        log_ok "相关镜像已全部删除"
    else
        log_ok "未找到相关镜像"
    fi

    log_info "清理悬空镜像与未使用镜像 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    docker image prune -a -f >/dev/null 2>&1
    log_ok "未使用镜像清理完成"

    log_info "清理Docker无用资源（容器/网络/卷/构建缓存） ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    docker system prune -a -f --volumes >/dev/null 2>&1
    docker builder prune -af >/dev/null 2>&1
    log_ok "Docker系统资源清理完成"

    log_info "验证清理结果 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    local remain=0
    for name in "${targets[@]}"; do
        docker ps -a --filter "name=^/${name}$" --format "{{.Names}}" | grep -q "^${name}$" && remain=$((remain+1))
    done

    if [ "$remain" -eq 0 ]; then
        log_ok "所有指定容器、镜像、残留资源已彻底清理，无名称冲突"
    else
        log_warn "仍有 ${gl_huang}${remain}${gl_bai} 个相关容器未清理，请手动检查"
    fi
}

deploy_app() {
    local COMPOSE_DIR=""
    local HOST_PORT=""

    root_use || return 1
    clear
    echo -e "${gl_zi}>>> ${DEFAULT_TITLE}${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    docker_check_env

    # 先解析参数：数字视为端口，其余视为目录
    for arg in "$@"; do
        if [[ "$arg" =~ ^[0-9]+$ ]]; then
            HOST_PORT="$arg"
        else
            COMPOSE_DIR="$arg"
        fi
    done

    if [ -z "${COMPOSE_DIR}" ]; then
        read -r -e -p "${gl_bai}请输入 docker-compose 存放路径（回车默认：${gl_huang}${DEFAULT_COMPOSE_DIR}${gl_bai}）(${gl_hong}0${gl_bai} 退出安装)：" input_dir
        COMPOSE_DIR=${input_dir:-$DEFAULT_COMPOSE_DIR}
    else
        log_info "已通过传参指定部署目录：${gl_huang}${COMPOSE_DIR}${gl_bai}"
    fi

    if [ "$COMPOSE_DIR" = "0" ]; then
        exit_script
        return 1
    fi

    log_info "部署目录：${gl_huang}${COMPOSE_DIR}${gl_bai}"
    mkdir -p "${COMPOSE_DIR}" || { log_error "目录创建失败"; break_end; return 1; }
    cd "${COMPOSE_DIR}" || { log_error "进入目录失败"; break_end; return 1; }

    if [ -z "${HOST_PORT}" ]; then
        read -r -e -p "${gl_bai}请输入映射端口（回车默认：${gl_huang}${DEFAULT_PORT}${gl_bai}）(${gl_hong}0${gl_bai} 退出安装)：" input_port
        HOST_PORT=${input_port:-$DEFAULT_PORT}
    else
        log_info "已通过传参指定端口：${gl_lv}${HOST_PORT}${gl_bai}"
    fi

    if [ "$HOST_PORT" = "0" ]; then
        exit_script
        rm -rf "${COMPOSE_DIR}"
        return 1
    fi

    log_info "使用端口：${gl_lv}${HOST_PORT}${gl_bai}"

    if ! check_port_available $HOST_PORT; then
        log_warn "端口 ${gl_hong}${HOST_PORT}${gl_bai} 已被占用"
        NEW_PORT=$(get_free_port $((HOST_PORT + 1)))
        if [ -n "$NEW_PORT" ]; then
            log_info "自动分配新端口：${gl_lv}${NEW_PORT}${gl_bai}"
            HOST_PORT=$NEW_PORT
        else
            log_error "无法找到可用端口，请手动指定"
            break_end
            return 1
        fi
    fi

    check_and_open_port ${HOST_PORT}
    clean_old_container "${DEFAULT_CONTAINER_NAME}"

    # 图片库目录校验：不存在时自动创建（避免只读挂载失败导致容器起不来）
    if [ ! -d "${DEFAULT_MEDIA_DIR}" ]; then
        log_warn "图片目录 ${gl_huang}${DEFAULT_MEDIA_DIR}${gl_bai} 不存在，正在自动创建"
        mkdir -p "${DEFAULT_MEDIA_DIR}" || { log_error "图片目录创建失败，请修改脚本顶部 DEFAULT_MEDIA_DIR"; break_end; return 1; }
    fi
    log_info "图片库目录：${gl_huang}${DEFAULT_MEDIA_DIR}${gl_bai}（只读挂载到容器 /photos）"

    # 源码同步：DEFAULT_IMAGE 留空表示本地构建
    local SRC_DIR="${COMPOSE_DIR}/src"
    local BUILD_FROM_SOURCE=1
    if [ -n "${DEFAULT_IMAGE}" ]; then
        log_info "使用公共镜像：${gl_huang}${DEFAULT_IMAGE}${gl_bai}（跳过源码构建）"
        BUILD_FROM_SOURCE=0
    else
        git_check_env
        if ! sync_repo "${SRC_DIR}"; then
            break_end
            return 1
        fi
    fi

    # 数据目录：容器内以 uid 1000 运行，这里同步修正属主
    mkdir -p "${COMPOSE_DIR}/data"
    chown -R 1000:1000 "${COMPOSE_DIR}/data" 2>/dev/null || log_warn "数据目录属主修正失败，若容器无写权限请手动执行: chown -R 1000:1000 ${COMPOSE_DIR}/data"

    # 检测硬件加速设备 /dev/dri（Intel/AMD 核显，QSV/VAAPI 需要），存在则挂载，否则跳过
    local DRI_DEVICES=""
    if [ -e "/dev/dri" ]; then
        log_info "检测到 /dev/dri 硬件加速设备，将挂载进容器（QSV / VAAPI 可用）"
        DRI_DEVICES="      devices:
         - /dev/dri:/dev/dri"
    else
        log_warn "未检测到 /dev/dri，跳过硬件加速挂载（软件编码兜底）"
    fi

    local BUILD_BLOCK=""
    if [ "$BUILD_FROM_SOURCE" -eq 1 ]; then
        BUILD_BLOCK="      build:
         context: ./src
         args:
            VERSION: latest"
    else
        BUILD_BLOCK="      image: ${DEFAULT_IMAGE}"
    fi

    echo -e ""
    echo -e "${gl_huang}>>> 生成 ${gl_lv}docker-compose.yml${gl_huang} 文件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    cat > docker-compose.yml << EOF
services:
   ${DEFAULT_CONTAINER_NAME}:
${BUILD_BLOCK}
      image: ${DEFAULT_CONTAINER_NAME}:latest
      container_name: ${DEFAULT_CONTAINER_NAME}
      network_mode: bridge
      restart: unless-stopped
      environment:
         - TZ=Asia/Shanghai
         # 转换并发；QSV/NVENC 等硬编码流水线建议不超过显卡并行能力
         - FIT_APP_WORKER=${DEFAULT_WORKER}
         # 硬件加速后端：auto / qsv / nvenc / vaapi / none
         - FIT_FFMPEG_ACCEL=auto
         - FIT_APP_DEBUG=false
      volumes:
         # 数据目录：任务快照 tasks.json、预设 profiles.json、上传与产物
         - ./data:/data
         # 图片库只读挂载，仅浏览与转码读取（如需修改请编辑本行或上方 DEFAULT_MEDIA_DIR）
         - ${DEFAULT_MEDIA_DIR}:/photos:ro
      ports:
         - ${HOST_PORT}:8791
      healthcheck:
         test: ["CMD", "curl", "-fsS", "http://127.0.0.1:8791/api/health"]
         interval: 30s
         timeout: 5s
         retries: 3
         start_period: 10s
${DRI_DEVICES}
      deploy:
         resources:
            limits:
               cpus: "4"
               memory: 4G
EOF

    if [ -f "docker-compose.yml" ]; then
        log_ok "配置文件创建成功"
    else
        log_error "配置文件创建失败"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return 1
    fi

    local UP_ARGS="up -d"
    if [ "$BUILD_FROM_SOURCE" -eq 1 ]; then
        UP_ARGS="up -d --build"
        log_info "首次构建需拉取 golang:1.25 基础镜像，耗时较长 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    fi

    echo -e ""
    echo -e "${gl_huang}>>> 尝试启动容器 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    if docker-compose ${UP_ARGS}; then
        log_ok "容器启动成功"
    else
        log_warn "docker-compose 启动失败，尝试兼容版 docker compose ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        if docker compose ${UP_ARGS}; then
            log_ok "容器启动成功"
        else
            log_error "容器启动失败"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            return 1
        fi
    fi

    echo -e ""
    echo -e "${gl_huang}>>> 容器运行状态${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    docker-ps-cn ${DEFAULT_CONTAINER_NAME}
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    log_info "部署完成！"
    log_info "访问地址：${gl_lv}http://${LOCAL_IP}:${HOST_PORT}${gl_bai}（无账号体系，打开即用）"
    log_info "部署目录：${gl_huang}${COMPOSE_DIR}${gl_bai}"
    if [ "$BUILD_FROM_SOURCE" -eq 1 ]; then
        log_info "源码目录：${gl_huang}${SRC_DIR}${gl_bai}（重跑本脚本即可升级到最新代码）"
    fi
    log_info "数据目录：${gl_huang}${COMPOSE_DIR}/data${gl_bai}（tasks.json 任务快照 / profiles.json 预设 / uploads / output）"
    log_info "图片目录：${gl_huang}${DEFAULT_MEDIA_DIR}${gl_bai} → 容器 ${gl_huang}/photos${gl_bai}（只读）"
    log_info "健康检查：${gl_huang}docker exec ${DEFAULT_CONTAINER_NAME} fan-image-tr check${gl_bai}（查看格式与硬件加速自检结果）"
    log_info "查看日志：${gl_huang}docker logs -f ${DEFAULT_CONTAINER_NAME}${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

deploy_app "$@"
