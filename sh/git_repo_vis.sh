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
}
list_color_init

log_info()  { echo -e "${gl_lan}[信息]${gl_bai} $*"; }
log_ok()    { echo -e "${gl_lv}[成功]${gl_bai} $*"; }
log_warn()  { echo -e "${gl_huang}[警告]${gl_bai} $*"; }
log_error() { echo -e "${gl_hong}[错误]${gl_bai} $*" >&2; }

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

handle_invalid_input() {
    echo -ne "\r\033[K${gl_huang}无效输入，1秒后返回${gl_bai}"
    sleep_fractional 1
    echo -ne "\r\033[K"
    return 2
}

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续${gl_bai} \c"
    read -r -n 1 -s -r
    echo ""
    clear
}

exit_animation() {
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local dots=("${gl_hong}." "${gl_huang}." "${gl_lv}." "${gl_bufan}." "${gl_zi}.")
    local dot_buffer=""
    local frame_len=${#frames[@]}
    local dot_idx=0
    for ((i=0; i<20; i++)); do
        if (( i > 0 && i % 3 == 0 && dot_idx < ${#dots[@]} )); then
            dot_buffer+=${dots[$dot_idx]}
            ((dot_idx++))
        fi
        echo -ne "\r\033[K${gl_bufan}${frames[$((i%frame_len))]}${gl_bai} 正在退出 ${dot_buffer}${gl_bai}"
        sleep_fractional 0.06
    done
    echo -e "\r\033[K${gl_lv}✓${gl_bai} 成功退出\n${gl_bai}"
    clear
    exit 0
}

cancel_return() {
    local menu_name="${1:-上一级菜单}"
    echo -ne "${gl_lv}即将返回 ${gl_huang}${menu_name}${gl_lv} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    sleep_fractional 0.6
    echo ""
    clear
}

install_deps() {
    local pkg_list=("$@")
    if [[ $EUID -ne 0 ]]; then
        log_error "安装依赖需要root权限，请使用root或sudo执行"
        return 1
    fi
    if command -v apt >/dev/null 2>&1; then
        log_info "检测到Debian/Ubuntu系列，使用apt安装依赖"
        apt update -qq >/dev/null 2>&1
        apt install -y "${pkg_list[@]}"
    elif command -v dnf >/dev/null 2>&1; then
        log_info "检测到RHEL/CentOS/Fedora系列，使用dnf安装依赖"
        dnf install -y "${pkg_list[@]}"
    elif command -v yum >/dev/null 2>&1; then
        log_info "检测到CentOS7系列，使用yum安装依赖"
        yum install -y "${pkg_list[@]}"
    elif command -v pacman >/dev/null 2>&1; then
        log_info "检测到Arch系列，使用pacman安装依赖"
        pacman -Syu --noconfirm "${pkg_list[@]}"
    else
        log_error "不识别当前系统包管理器，请手动安装: ${pkg_list[*]}"
        return 1
    fi
}

api_query_private_status() {
    local platform="$1"
    local token="$2"
    local api_url="$3"
    local curl_args=()
    curl_args+=(-s -X GET)
    if [[ "${platform}" == "github" ]];then
        curl_args+=(-H "Authorization: token ${token}")
    elif [[ "${platform}" == "gitee" ]];then
        curl_args+=(-H "Authorization: Bearer ${token}")
    fi
    curl_args+=(-H "Accept: application/json")
    curl_args+=("${api_url}")
    local out
    out=$(curl "${curl_args[@]}" 2>/dev/null)
    echo "$out" | jq -r '.private' 2>/dev/null
}

change_repo_visibility() {
    local platform="$1"
    local token="$2"
    local api_url="$3"
    local private_flag="$4"
    local curl_args=()
    curl_args+=(-s -X PATCH)
    if [[ "${platform}" == "github" ]];then
        curl_args+=(-H "Authorization: token ${token}")
    elif [[ "${platform}" == "gitee" ]];then
        curl_args+=(-H "Authorization: Bearer ${token}")
    fi
    curl_args+=(-H "Accept: application/json")
    curl_args+=(-H "Content-Type: application/json")
    curl_args+=(-d "{\"private\":${private_flag}}")
    curl_args+=("${api_url}")
    local resp
    resp=$(curl "${curl_args[@]}" 2>/dev/null)
    echo "$resp"
}

local_git_check_status() {
    if [[ ! -d .git ]];then
        echo "NOTGIT"
        return
    fi
    local remote_url
    remote_url=$(git remote get-url origin 2>/dev/null || true)
    echo "${remote_url}"
}

main_work() {
    local GH_TOKEN="${GH_TOKEN:-}"
    local REPO_LOCAL_PATH="${REPO_LOCAL_PATH:-}"
    local REPO_API_URL="${REPO_API_URL:-}"
    local ACTION="${ACTION:-}"
    local PLATFORM="${PLATFORM:-}"

    log_info "DEBUG GH_TOKEN=[${GH_TOKEN}]"
    log_info "DEBUG REPO_API_URL=[${REPO_API_URL}]"
    log_info "DEBUG ACTION=[${ACTION}]"
    log_info "DEBUG PLATFORM=[${PLATFORM}]"

    if [[ -n "${GH_TOKEN}" && -n "${REPO_API_URL}" && -n "${ACTION}" && -n "${PLATFORM}" ]]; then
        log_info "检测到环境变量，启用免交互模式"
        local private_target
        if [[ "${ACTION}" == "public2private" ]]; then
            private_target="true"
        elif [[ "${ACTION}" == "private2public" ]]; then
            private_target="false"
        else
            log_error "ACTION参数仅支持 public2private / private2public"
            return 1
        fi
        if [[ "${PLATFORM}" != "github" && "${PLATFORM}" != "gitee" ]]; then
            log_error "PLATFORM仅支持 github / gitee"
            return 1
        fi
        if [[ -n "${REPO_LOCAL_PATH}" ]]; then
            if [[ -d "${REPO_LOCAL_PATH}" ]]; then
                cd "${REPO_LOCAL_PATH}" || true
            fi
        fi
        log_info "执行修改仓库可见性，平台:${PLATFORM}"
        local res
        res=$(change_repo_visibility "${PLATFORM}" "${GH_TOKEN}" "${REPO_API_URL}" "${private_target}")
        if echo "$res" | jq -e '.id' >/dev/null 2>&1; then
            log_ok "API请求执行完成"
            local cur
            cur=$(api_query_private_status "${PLATFORM}" "${GH_TOKEN}" "${REPO_API_URL}")
            local cn_status
            if [[ "${cur}" == "true" ]];then
                cn_status="私有仓库"
            elif [[ "${cur}" == "false" ]];then
                cn_status="公开仓库"
            else
                cn_status="未知(${cur})"
            fi
            log_info "当前仓库状态: ${cn_status}"
        else
            log_error "API调用失败，返回: ${res}"
            return 1
        fi
        return 0
    fi

    clear
    local git_ret
    git_ret=$(local_git_check_status)
    echo -e "${gl_huang}>>> 当前仓库的状态${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————${gl_bai}"
    if [[ "${git_ret}" == "NOTGIT" ]];then
        echo -e "${gl_hong}非 Git 仓库${gl_bai}"
    else
        echo -e "${gl_lv}本地Git仓库${gl_bai}"
    fi
    echo ""

    while true; do
        echo -e "${gl_zi}>>> 仓库可见性切换工具${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1. GitHub${gl_bai}"
        echo -e "${gl_bufan}2. Gitee${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————${gl_bai}"
        echo -e "${gl_hong}00. 退出脚本${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————${gl_bai}"
        read -r -p "$(echo -e "${gl_bai}请选择代码平台: ${gl_bai}")" plat_opt
        case "${plat_opt}" in
        1)
            PLATFORM="github"
            break
            ;;
        2)
            PLATFORM="gitee"
            break
            ;;
        00)
            exit_animation
            ;;
        *)
            handle_invalid_input
            ;;
        esac
    done

    clear
    echo -e "${gl_zi}>>> 输入配置信息 ${gl_huang}[${PLATFORM}]${gl_bai}"
    read -r -p "$(echo -e "${gl_bai}请输入平台个人令牌: ${gl_bai}")" GH_TOKEN
    if [[ -z "${GH_TOKEN}" ]]; then
        log_error "令牌不能为空"
        break_end
        return 1
    fi

    read -r -p "$(echo -e "${gl_bai}仓库本地绝对路径(回车使用当前目录): ${gl_bai}")" REPO_LOCAL_PATH
    if [[ -z "${REPO_LOCAL_PATH}" ]]; then
        REPO_LOCAL_PATH=$(pwd)
    fi
    if [[ -n "${REPO_LOCAL_PATH}" ]]; then
        if [[ -d "${REPO_LOCAL_PATH}" ]]; then
            cd "${REPO_LOCAL_PATH}" || log_warn "切换目录失败"
        else
            log_warn "本地目录 ${REPO_LOCAL_PATH} 不存在，跳过cd，不影响API调用"
        fi
    fi

    read -r -p "$(echo -e "${gl_bai}输入仓库API地址: ${gl_bai}")" REPO_API_URL
    if [[ -z "${REPO_API_URL}" ]]; then
        log_error "API地址不能为空"
        break_end
        return 1
    fi

    clear
    local cur_status_raw
    cur_status_raw=$(api_query_private_status "${PLATFORM}" "${GH_TOKEN}" "${REPO_API_URL}")
    local cur_cn
    if [[ "${cur_status_raw}" == "true" ]];then
        cur_cn="私有仓库"
    elif [[ "${cur_status_raw}" == "false" ]];then
        cur_cn="公开仓库"
    else
        cur_cn="未知(${cur_status_raw})"
    fi

    echo -e "${gl_huang}>>> 当前仓库的状态${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————${gl_bai}"
    echo -e "${gl_lv}${cur_cn}${gl_bai}"
    echo ""

    while true; do
        echo -e "${gl_zi}>>> 选择操作 ${gl_huang}[${PLATFORM}]${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1. 公开仓库 → 私有仓库${gl_bai}"
        echo -e "${gl_bufan}2. 私有仓库 → 公开仓库${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}0. 返回上一级${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————${gl_bai}"
        read -r -p "$(echo -e "${gl_bai}请输入你的选择: ${gl_bai}")" opt
        case "${opt}" in
        1)
            ACTION="public2private"
            private_target="true"
            break
            ;;
        2)
            ACTION="private2public"
            private_target="false"
            break
            ;;
        0)
            cancel_return
            main_work
            return 0
            ;;
        *)
            handle_invalid_input
            ;;
        esac
    done

    log_info "开始调用接口修改仓库属性，平台:${PLATFORM}"
    local api_resp
    api_resp=$(change_repo_visibility "${PLATFORM}" "${GH_TOKEN}" "${REPO_API_URL}" "${private_target}")
    if echo "${api_resp}" | jq -e '.id' >/dev/null 2>&1; then
        log_ok "接口调用成功"
        local now_status
        now_status=$(api_query_private_status "${PLATFORM}" "${GH_TOKEN}" "${REPO_API_URL}")
        local cn_now
        if [[ "${now_status}" == "true" ]];then
            cn_now="私有仓库"
        elif [[ "${now_status}" == "false" ]];then
            cn_now="公开仓库"
        else
            cn_now="未知(${now_status})"
        fi
        log_info "仓库当前状态: ${cn_now}"
    else
        log_error "接口调用失败，返回内容: ${api_resp}"
    fi

    break_end
}

main() {
    if ! command -v jq >/dev/null 2>&1; then
        log_warn "依赖 jq 未安装，尝试自动安装"
        install_deps jq
        if ! command -v jq >/dev/null 2>&1; then
            log_error "jq安装失败，请手动安装jq"
            exit 1
        fi
    fi
    main_work
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi