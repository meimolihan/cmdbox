#!/bin/bash
set -uo pipefail

: "${GH_TOKEN:=}"
: "${DOCKERHUB_USERNAME:=mobufan}"
: "${DOCKERHUB_TOKEN:=}"
: "${EXTRA_TRIGGER_WORKFLOW:=0}"
: "${SHOW_DOCKERHUB_INFO:=1}"
: "${PRE_CLEAN_REMOTE_TAG:=1}"
: "${LOCAL_DOCKER_LOGIN:=1}"

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
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
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
    local int_seconds
    int_seconds=$(echo "$seconds" | awk '{print int($1+0.999)}')
    sleep "$int_seconds"
}

cancel_return() {
    local menu_name="${1:-退出脚本}"
    echo -ne "${gl_lv}即将返回 ${gl_huang}${menu_name} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
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
            dot_buffer+="${dots[$dot_idx]}"
            ((dot_idx++))
        fi
        echo -ne "\r\033[K${gl_bufan}${frames[i % frame_len]}${gl_bai} 正在退出 ${dot_buffer}"
        sleep_fractional 0.06
    done
    echo -e "\r\033[K${gl_lv}✓${gl_bai} ${gl_lv}[成功]${gl_bai}退出\n"
    clear
    exit 0
}

handle_y_n() {
    echo -ne "\r${gl_hong}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai}) ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.3
    echo -ne "\r${gl_huang}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai}) ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.3
    echo -ne "\r${gl_lv}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai}) ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo ""
    return 2
}

exit_animation() {
    echo -ne "\r${gl_lv}即将退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.8
    echo ""
    clear
}

cancel_empty() {
    local menu_name="${1:-上一级选单}"
    echo -e "${gl_hong}空输入，返回 ${gl_huang}${menu_name} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.8
    echo ""
    clear
}

handle_invalid_input() {
    echo -ne "\r\033[K${gl_huang}无效的输入,请重新输入! ${gl_zi} 1 ${gl_huang} 秒后返回"
    sleep_fractional 1
    echo -ne "\r\033[K${gl_lv}无效的输入,请重新输入! ${gl_zi}0${gl_lv} 秒后返回"
    sleep_fractional 0.5
    echo -ne "\r\033[K"
    return 2
}

get_git_latest_tag() {
    local repo_path="$1"
    if [[ -z "$repo_path" ]]; then
        repo_path="."
    fi
    local tag
    tag=$(
        cd "${repo_path}" || return
        git tag --sort=-v:refname 2>/dev/null \
            | grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+$' \
            | head -n 1
    )
    if [[ -z "$tag" ]]; then
        echo -e "${gl_huang}无版本标签${gl_bai}"
    else
        echo "$tag"
    fi
}

next_version() {
    local cur="$1"
    cur=$(echo "$cur" | sed -E 's/\x1b\[[0-9;]*m//g' | tr -d '\r')
    if [[ -z "$cur" || "$cur" == *"无版本标签"* ]]; then
        echo "v1.0.0"
        return
    fi
    if [[ "$cur" =~ ^(v?)([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
        echo "${BASH_REMATCH[1]}${BASH_REMATCH[2]}.${BASH_REMATCH[3]}.$((BASH_REMATCH[4] + 1))"
    else
        echo "$cur"
    fi
}

get_repo_slug() {
    local repo_path="${1:-.}"
    local url
    url=$(cd "$repo_path" 2>/dev/null && git remote get-url origin 2>/dev/null) || return 1
    [[ -z "$url" ]] && return 1
    echo "$url" | sed -E 's#^https?://[^/]+/##; s#^git@[^:]+:##; s#\.git$##'
}

git_push() {
    local msg="${1:-自动更新 $(date '+%Y-%m-%d %H:%M:%S')}"
    local branch
    branch=$(git rev-parse --abbrev-ref HEAD)

    if [ "$branch" = "HEAD" ]; then
        log_error "当前处于游离HEAD状态，无法执行推送"
        return 1
    fi

    log_info "当前分支：$branch"
    log_info "开始拉取远端最新代码"
    git pull origin "$branch"
    if [ $? -ne 0 ]; then
        log_error "拉取代码失败，请手动处理冲突"
        return 1
    fi

    log_info "添加所有变更文件"
    git add .

    log_info "提交代码，提交信息：$msg"
    git commit -m "$msg"
    if [ $? -ne 0 ]; then
        if git status | grep -q "nothing to commit"; then
            log_warn "没有文件改动，无需提交推送"
            return 0
        fi
        log_error "代码提交失败"
        return 1
    fi

    log_info "推送到远端 origin/$branch"
    git push origin "$branch"
    if [ $? -eq 0 ]; then
        log_ok "代码推送完成"
    else
        log_error "代码推送失败"
        return 1
    fi
}

check_tokens() {
    local fail=0
    if [[ -z "$GH_TOKEN" ]]; then
        log_error "环境变量 GH_TOKEN 未设置"
        echo -e "       ${gl_huang}export GH_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx${gl_bai}"
        echo -e "       ${gl_hui}（需要 repo + workflow 权限）${gl_bai}"
        fail=1
    fi
    if [[ -z "$DOCKERHUB_TOKEN" ]]; then
        log_warn "环境变量 DOCKERHUB_TOKEN 未设置，将跳过 Actions secret 与本地 docker login"
    fi
    return "$fail"
}

pkg_install() {
    local pkgs=("$@")
    local need_install=()
    if [[ $EUID -ne 0 ]]; then
        log_error "需要root权限才能安装软件包，请使用sudo运行脚本！"
        return 2
    fi
    log_info "检查依赖包: ${pkgs[*]}"
    for pkg in "${pkgs[@]}"; do
        if ! command -v "${pkg}" &>/dev/null; then
            need_install+=("${pkg}")
        fi
    done
    if [[ ${#need_install[@]} -eq 0 ]]; then
        log_ok "所有依赖已安装，无需操作"
        return 0
    fi
    log_warn "待安装软件包: ${need_install[*]}"
    log_info "开始更新软件源并安装依赖 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    if apt update >/dev/null 2>&1 && apt install -y "${need_install[@]}"; then
        log_ok "依赖安装完成"
        return 0
    else
        log_error "软件包安装失败，请检查网络或软件源"
        return 1
    fi
}

column_if_available() {
    if command -v column >/dev/null 2>&1; then
        column -t
    else
        cat
    fi
}

compose_ps_beautify() {
    if [[ ! -f "docker-compose.yml" && ! -f "compose.yml" ]]; then
        echo -e "${gl_hong}❌ 当前目录未找到 docker-compose.yml / compose.yml${gl_bai}"
        return 1
    fi

    {
        # 表头，使用 -- 隔离参数，防止 -- 开头解析错误
        printf -- "容器ID\t名称\t状态\t端口\t创建时间\t镜像\n"
        printf -- "----------\t----------\t----------\t----------\t----------\t----------\n"
        docker compose ps --format "{{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.RunningFor}}\t{{.Image}}"
    } | awk -v green="$gl_lv" -v red="$gl_hong" -v yellow="$gl_huang" -v blue="$gl_lan" -v cyan="$gl_bufan" -v white="$gl_bai" -v hui="$gl_hui" -v reset="$reset" '
    BEGIN {FS="\t"; OFS="\t"}
    {
        if(NR == 1){
            print hui $0 reset
            next
        }
        if(NR == 2){
            print hui $0 reset
            next
        }

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
        gsub(/[0-9]+/, green "&" reset, time)

        if (length(ports) > 35) {
            ports = substr(ports,1,35) "..."
        }
        print cyan id reset, green name reset, yellow status reset, blue ports reset, white time reset, white image reset
    }' | column_if_available
}

pre_clean_remote_tag() {
    local repo_path="$1"
    local tag="$2"

    if [[ "${PRE_CLEAN_REMOTE_TAG}" != "1" ]]; then
        return 0
    fi
    if [[ -z "$repo_path" || -z "$tag" ]]; then
        return 0
    fi

    pushd "$repo_path" >/dev/null 2>&1 || return 0

    local repo_slug
    repo_slug=$(get_repo_slug "$repo_path")

    local release_deleted=0

    if [[ -n "$repo_slug" ]] && command -v gh >/dev/null 2>&1; then
        if gh release view "$tag" -R "$repo_slug" >/dev/null 2>&1; then
            log_warn "远端已存在 Release ${tag}，删除 Release + tag"
            if gh release delete "$tag" -R "$repo_slug" --yes --cleanup-tag >/dev/null 2>&1; then
                log_ok "Release ${tag} 及远端 tag 已删除"
                release_deleted=1
            else
                if gh release delete "$tag" -R "$repo_slug" --yes >/dev/null 2>&1; then
                    log_ok "Release ${tag} 已删除"
                    release_deleted=1
                else
                    log_warn "Release ${tag} 删除失败（继续尝试清理 tag）"
                fi
            fi
        else
            log_info "远端无同名 Release ${tag}"
        fi
    fi

    if [[ "$release_deleted" != "1" ]]; then
        local remote_has_tag
        remote_has_tag=$(git ls-remote --tags origin "refs/tags/${tag}" 2>/dev/null)
        if [[ -n "$remote_has_tag" ]]; then
            log_warn "远端已存在 tag ${tag}，主动删除"
            if git push origin --delete "$tag" >/dev/null 2>&1; then
                log_ok "远端 tag ${tag} 已删除"
            elif git push origin ":refs/tags/${tag}" >/dev/null 2>&1; then
                log_ok "远端 tag ${tag} 已删除（refs 形式）"
            else
                log_warn "远端 tag ${tag} 删除失败（可能需要手动处理）"
            fi
        else
            log_info "远端无同名 tag ${tag}"
        fi
    fi

    if git rev-parse --verify "refs/tags/${tag}" >/dev/null 2>&1; then
        git tag -d "$tag" >/dev/null 2>&1 && log_ok "本地 tag ${tag} 已删除" || true
    fi

    popd >/dev/null 2>&1

    return 0
}

show_dockerhub_info() {
    local repo="$1"

    if [[ "${SHOW_DOCKERHUB_INFO}" != "1" ]]; then
        return 0
    fi

    if [[ -z "$repo" ]]; then
        log_error "用法: show_dockerhub_info <dockerhub_repo>"
        return 1
    fi

    echo -e "${gl_zi}>>> Docker Hub 信息：${gl_huang}${repo}${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if [[ -n "$DOCKERHUB_USERNAME" ]]; then
        echo -e "${gl_bai}Docker Hub 用户名：${gl_lv}${DOCKERHUB_USERNAME}${gl_bai}"
    else
        echo -e "${gl_bai}Docker Hub 用户名：${gl_hong}未设置${gl_bai}"
    fi

    if [[ -n "$DOCKERHUB_TOKEN" ]]; then
        echo -e "${gl_bai}Docker Hub Token ：${gl_lv}已设置${gl_bai}（长度 ${#DOCKERHUB_TOKEN}）"
    else
        echo -e "${gl_bai}Docker Hub Token ：${gl_hong}未设置${gl_bai}"
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

ensure_gh_auth() {
    local repo_path="${1:-.}"

    if [[ -z "$GH_TOKEN" ]]; then
        log_error "环境变量 GH_TOKEN 未设置，无法认证 GitHub CLI"
        echo -e "       ${gl_huang}export GH_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx${gl_bai}"
        return 1
    fi

    if ! command -v gh >/dev/null 2>&1; then
        pkg_install gh || return 1
    fi

    if gh auth status -h github.com >/dev/null 2>&1; then
        log_ok "GitHub CLI 已登录，跳过认证"
    else
        if ! echo "$GH_TOKEN" | gh auth login --with-token; then
            log_error "GitHub CLI Token 登录失败（请检查 Token 是否有效/未过期）"
            return 1
        fi
        log_ok "GitHub CLI 登录完成"
    fi

    local repo_slug
    repo_slug=$(get_repo_slug "$repo_path")
    if [[ -z "$repo_slug" ]]; then
        log_error "无法从 git remote 解析 GitHub 仓库地址（owner/repo）"
        return 1
    fi

    if gh repo set-default "$repo_slug" >/dev/null 2>&1; then
        log_ok "默认仓库已设置为 ${repo_slug}"
    else
        log_warn "set-default 未成功（不影响后续，后续命令已显式使用 -R）"
    fi

    return 0
}

ensure_cnb_token() {
    if [[ "${ENABLE_CNB_CHECK:-}" != "1" ]]; then
        log_info "ENABLE_CNB_CHECK=0，跳过CNB_ACCESS_TOKEN校验"
        return 0
    fi

    if [[ -z "${CNB_ACCESS_TOKEN:-}" ]]; then
        log_warn "CNB_ACCESS_TOKEN 未设置"
        return 1
    fi

    log_ok "CNB_ACCESS_TOKEN 环境变量已配置"
    return 0
}

ensure_dockerhub_auth() {
    if [[ "${LOCAL_DOCKER_LOGIN}" != "1" ]]; then
        log_info "LOCAL_DOCKER_LOGIN=0，跳过本地 docker login"
        return 0
    fi

    if ! command -v docker >/dev/null 2>&1; then
        log_warn "未检测到 docker 命令，跳过本地 docker login"
        return 0
    fi

    if [[ -z "$DOCKERHUB_USERNAME" || -z "$DOCKERHUB_TOKEN" ]]; then
        log_warn "DOCKERHUB_USERNAME 或 DOCKERHUB_TOKEN 未设置，跳过本地 docker login"
        return 0
    fi

    local current_user=""
    local cfg="${HOME}/.docker/config.json"
    if [[ -f "$cfg" ]]; then
        if command -v jq >/dev/null 2>&1; then
            current_user=$(jq -r '.auths["https://index.docker.io/v1/"].auth // empty' "$cfg" 2>/dev/null \
                | base64 -d 2>/dev/null | cut -d: -f1)
        elif command -v python3 >/dev/null 2>&1; then
            current_user=$(python3 -c "
import json,base64,os
try:
    with open(os.path.expanduser('~/.docker/config.json')) as f:
        d = json.load(f)
    a = d.get('auths', {}).get('https://index.docker.io/v1/', {}).get('auth')
    if a:
        print(base64.b64decode(a).decode().split(':',1)[0])
except Exception:
    pass
" 2>/dev/null)
        fi
    fi

    if [[ -n "$current_user" && "$current_user" == "$DOCKERHUB_USERNAME" ]]; then
        log_ok "Docker Hub 已登录为 ${current_user}，跳过认证"
        return 0
    fi

    echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin >/dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        log_ok "Docker Hub 登录完成（用户名：${DOCKERHUB_USERNAME}）"
        return 0
    else
        log_error "Docker Hub 登录失败（请检查 Token 是否有效/未过期）"
        return 1
    fi
}

trigger_release_workflow() {
    local repo_path="$1"
    local version="${2:-}"

    if [[ -z "$repo_path" ]]; then
        log_error "用法: trigger_release_workflow <仓库绝对路径> [版本号]"
        return 99
    fi
    if [[ ! -d "${repo_path}/.git" ]]; then
        log_error "${repo_path} 不是 Git 仓库"
        return 98
    fi
    if [[ -z "$GH_TOKEN" ]]; then
        log_error "环境变量 GH_TOKEN 未设置，无法调用 GitHub API"
        return 96
    fi

    local repo_slug
    repo_slug=$(get_repo_slug "$repo_path")
    if [[ -z "$repo_slug" ]]; then
        log_error "无法从 git remote 解析 GitHub 仓库地址（owner/repo）"
        return 95
    fi

    pushd "${repo_path}" >/dev/null || {
        log_error "无法进入目录 ${repo_path}"
        return 97
    }

    if ! gh auth status -h github.com >/dev/null 2>&1; then
        if ! echo "$GH_TOKEN" | gh auth login --with-token; then
            log_error "GitHub CLI Token 登录失败"
            popd >/dev/null
            return 10
        fi
    fi

    echo -e "${gl_bai}【第 ${gl_huang}1${gl_bai} 步】设置 Actions 密钥 DOCKERHUB_USERNAME"
    if [[ -n "$DOCKERHUB_USERNAME" ]]; then
        if gh secret set DOCKERHUB_USERNAME -R "$repo_slug" --body "$DOCKERHUB_USERNAME" >/dev/null; then
            log_ok "DOCKERHUB_USERNAME 已设置"
        else
            log_error "设置 DOCKERHUB_USERNAME 失败"
            popd >/dev/null
            return 1
        fi
    else
        log_warn "DOCKERHUB_USERNAME 未配置，跳过"
    fi

    echo -e "${gl_bai}【第 ${gl_huang}2${gl_bai} 步】设置 Actions 密钥 DOCKERHUB_TOKEN"
    if [[ -n "$DOCKERHUB_TOKEN" ]]; then
        if gh secret set DOCKERHUB_TOKEN -R "$repo_slug" --body "$DOCKERHUB_TOKEN" >/dev/null; then
            log_ok "DOCKERHUB_TOKEN 已设置"
        else
            log_error "设置 DOCKERHUB_TOKEN 失败"
            popd >/dev/null
            return 2
        fi
    else
        log_warn "DOCKERHUB_TOKEN 未配置，跳过"
    fi

    if [[ "${EXTRA_TRIGGER_WORKFLOW}" == "1" ]]; then
        echo -e "${gl_bai}【第 ${gl_huang}3${gl_bai} 步】手动触发 release workflow（main 分支）"
        if ! gh workflow run release --ref main -R "$repo_slug"; then
            log_error "启动 release workflow 失败"
            popd >/dev/null
            return 3
        fi
        log_ok "release workflow 已触发"
    else
        echo -e "${gl_bai}【第 ${gl_huang}3${gl_bai} 步】跳过手动触发（tag push 已自动触发 workflow）"
        echo -e "       ${gl_hui}如需强制手动触发，请设置 EXTRA_TRIGGER_WORKFLOW=1${gl_bai}"
    fi

    echo
    echo -e "${gl_lv}🎉 Workflow 处理完成！${gl_bai}"
    if [[ -n "$version" ]]; then
        echo -e "${gl_hui}💡 查看本次 tag 触发的运行记录：gh run list --workflow=release.yml -R ${repo_slug} --limit 5${gl_bai}"
        echo -e "${gl_hui}💡 查看发布结果：gh release view ${version} -R ${repo_slug}${gl_bai}"
    fi
    popd >/dev/null
    return 0
}

build_and_push() {
    local project_root="$1"
    local version="${2:-}"
    local msg="${3:-}"

    if [[ -z "$project_root" ]]; then
        log_error "项目根目录为空，无法继续（应由菜单传入）"
        echo -e "${col43}43.${gl_bai} FanVideoCT 视频剪切       ${col44}44.${gl_bai} FanNginx 反向代理"
        break_end
        return 1
    fi

    local script_path="${project_root}/scripts/build-and-push.sh"
    if [[ ! -d "$project_root" ]]; then
        log_error "目录不存在：$project_root"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return 1
    fi
    if [[ ! -f "$script_path" ]]; then
        echo -e "${gl_huang}❌ 脚本不存在：$script_path${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return 1
    fi
    if [[ ! -x "$script_path" ]]; then
        echo -e "${gl_huang}⚠️ 脚本缺少执行权限，自动执行 chmod +x${gl_bai}"
        chmod +x "$script_path"
    fi

    local cur_ver next_ver
    cur_ver=$(get_git_latest_tag "$project_root")
    next_ver=$(next_version "$cur_ver")

    if [[ -z "$version" ]]; then
        echo -e ""
        echo -e "${gl_huang}>>> 添加版本号 ${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "当前版本：${gl_lv}${cur_ver}${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "  ${gl_bufan}1.${gl_bai} 将作为 GitHub 标签/发布 版本号"
        echo -e "  ${gl_bufan}2.${gl_bai} 输入后回车开始构建、提交、推送（默认递增，如 ${gl_lv}${next_ver}${gl_bai}）"
        echo -e "  ${gl_huang}0.${gl_bai} 返回上一级选单"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        while true; do
            read -r -e -p "请输入版本号（回车默认 ${gl_huang}${next_ver}${gl_bai}）： " version

            if [[ -z "$version" ]]; then
                version="$next_ver"
                echo -ne "\r\033[K"
                break
            fi

            if [[ "$version" == "0" ]]; then
                echo -e "\r\033[K${gl_huang}📤 返回上级${gl_bai}"
                sleep_fractional 0.5
                return 2
            fi

            echo -ne "\r\033[K"
            break
        done
    fi

    if [[ -z "$msg" ]]; then
        while true; do
            read -r -e -p "请输入提交注释 (回车默认 ${gl_huang}日常更新${gl_bai}）： " msg

            if [[ -z "$msg" ]]; then
                msg="日常更新"
                echo -ne "\r\033[K"
                break
            fi

            if [[ "$msg" == "0" ]]; then
                echo -e "\r\033[K${gl_huang}📤 返回上级${gl_bai}"
                sleep_fractional 0.5
                return 2
            fi

            echo -ne "\r\033[K"
            break
        done
    fi

    echo
    echo -e "项目目录:   ${gl_lv}$project_root${gl_bai}"
    echo -e "脚本路径:   ${gl_lv}$script_path${gl_bai}"
    echo -e "版 本 号:   ${gl_lv}$version${gl_bai}"
    echo -e "注释内容:   ${gl_lv}$msg${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local confirm=""
    local c_prompt="确认开始构建推送？ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai})："
    while true; do
        read -r -e -p "$c_prompt " confirm

        case "$confirm" in
            "")
                echo -ne "\033[1A\r\033[K"
                c_prompt="${gl_hong}❌ 不能为空${gl_bai} → 确认开始构建推送？ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai})："
                continue
                ;;
            "0")
                echo -e "\r\033[K${gl_huang}📤 返回上级${gl_bai}"
                sleep_fractional 0.5
                return 2
                ;;
            [Yy])
                echo -ne "\r\033[K"
                break
                ;;
            [Nn])
                echo -e "\r\033[K${gl_huang}✅ 已取消操作${gl_bai}"
                sleep_fractional 0.5
                return 2
                ;;
            *)
                echo -ne "\033[1A\r\033[K"
                c_prompt="${gl_hong}❌ 无效输入${gl_bai} → 确认开始构建推送？ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai})："
                continue
                ;;
        esac
    done

    echo
    echo -e "${gl_zi}>>> 第 1/5 步：确保 GitHub CLI 认证 ${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    if ! ensure_gh_auth "$project_root"; then
        log_error "GitHub CLI 认证失败，中止后续步骤"
        return 1
    fi

    echo
    echo -e "${gl_zi}>>> 第 2/5 步：确保 Docker Hub 认证 ${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    if ! ensure_dockerhub_auth; then
        log_warn "Docker Hub 认证失败，继续执行（如不需要本地推送镜像可忽略）"
    fi

    export ENABLE_CNB_CHECK=1
    if ! ensure_cnb_token; then
        log_warn "CNB_TOKEN 校验失败，继续执行（如不需要CNB能力可忽略）"
    fi


    echo
    echo -e "${gl_zi}>>> 第 3/5 步：清理远端 Release / tag & 推送未提交改动 ${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    pre_clean_remote_tag "$project_root" "$version"

    echo
    echo -e "${gl_hui} 提交并推送工作区的未提交改动（保证构建脚本遇到干净工作区）${gl_bai}"
    pushd "$project_root" >/dev/null 2>&1 || {
        log_error "无法进入目录 $project_root"
        return 1
    }
    git_push "$msg"
    local push_rc=$?
    popd >/dev/null 2>&1
    if [[ "$push_rc" -ne 0 ]]; then
        log_error "git_push 失败，中止后续步骤"
        return 1
    fi

    echo
    echo -e "${gl_zi}>>> 第 4/5 步：执行项目构建脚本 ${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    if ! "$script_path" "$version" --yes -m "$msg"; then
        log_error "构建脚本执行失败，中止后续步骤"
        return 1
    fi

    echo
    echo -e "${gl_zi}>>> 第 5/5 步：处理 Release Workflow ${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    if ! trigger_release_workflow "$project_root" "$version"; then
        log_error "Release Workflow 处理失败"
        return 1
    fi
}

function count_md_docs {
    cd /vol1/1000/GitHub/cmdbox-main
    local cmd_count
    local ops_count
    local win_count
    local total_count
    cmd_count=$(find "./command" -type f -name "*.md" -print0 | grep -zc .)
    ops_count=$(find "./ops-script" -type f -name "*.md" -print0 | grep -zc .)
    win_count=$(find "./windows" -type f -name "*.md" -print0 | grep -zc .)
    total_count=$((cmd_count + ops_count + win_count))

    echo
    echo -e "${gl_huang}>>> CmdBox 文章统计${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo "- 命令文章：${gl_lv}${cmd_count}${reset} 篇"
    echo "- 运维脚本：${gl_lv}${ops_count}${reset} 篇"
    echo "- Win 脚本：${gl_lv}${win_count}${reset} 篇"
    echo "- 合计文章：${gl_huang}${total_count}${reset} 篇"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
}

project_push() {
    local proj_name="$1"
    local proj_dir="$2"
    local docker_filter="$3"
    local dockerhub_repo="$4"

    echo -e ""
    echo -e "${gl_zi}>>> ${proj_name} 项目推送 ${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if [[ -n "${docker_filter}" ]]; then
        compose_ps_beautify
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    fi

    build_and_push "${proj_dir}"
    local rc=$?

    if [[ "$rc" -eq 2 ]]; then
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        return 0
    fi

    if [[ "$rc" -ne 0 ]]; then
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        return 0
    fi

    if [[ -n "$dockerhub_repo" ]]; then
        echo
        show_dockerhub_info "$dockerhub_repo" 5
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
}

fan_panel_push()  { project_push "Fan Panel"   "/vol1/1000/GitHub/fan-panel"   "fan-panel"  "mobufan/fan-panel"; }
fan_video_push()  { project_push "Fan Video"   "/vol1/1000/GitHub/fan-video"   "fan-video"  "mobufan/fan-video"; }
fan_md_push()     { project_push "Fan MD"      "/vol1/1000/GitHub/fan-md"      "fan-md"  "mobufan/fan-md"; }
dufs-zh_push()    { project_push "Dufs-zh"     "/vol1/1000/GitHub/dufs-zh"     "dufs-zh" "mobufan/dufs-zh"; }
2panel_push()    { project_push "2Panel"     "/vol1/1000/GitHub/2panel"     "" "mobufan/2panel"; }
fan-shop_push()    { project_push "Fan Shop"     "/vol1/1000/GitHub/fan-shop"     "fan-shop" "mobufan/fan-shop"; }
fan-files_push()    { project_push "Fan Files"     "/vol1/1000/GitHub/fan-files"     "" "mobufan/fan-files"; }
fan-reubah_push()    { project_push "Fan Reubah"     "/vol1/1000/GitHub/fan-reubah"     "fan-reubah" "mobufan/fan-reubah"; }
cmdbox-main_push()    { project_push "CmdBox"     "/vol1/1000/GitHub/cmdbox-main"     "cmdbox" "mobufan/cmdbox"; }
fan-webssh_push()    { project_push "Fan WebSSH"     "/vol1/1000/GitHub/fan-webssh"     "fan-webssh" "mobufan/fan-webssh"; }
fan_random_push()    { project_push "Fan Random"     "/vol1/1000/GitHub/fan-random"     "fan-random" "mobufan/fan-random"; }
fan_video_dl_push()  { project_push "Fan Video DL"   "/vol1/1000/GitHub/fan-video-dl"   "fan-video-dl" "mobufan/fan-video-dl"; }
fan_video_ct_push()  { project_push "Fan Video CT"   "/vol1/1000/GitHub/fan-video-ct"   "fan-video-ct" "mobufan/fan-video-ct"; }
fan_nginx_push()  { project_push "Fan Nginx"   "/vol1/1000/GitHub/fan-nginx"   "fan-nginx" "mobufan/fan-nginx"; }

git_project_menu() {
    check_tokens || true

    while true; do
        clear
        echo -e "${gl_zi}>>> Git 项目构建并推送${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}FanPanel 导航页       ${gl_bufan}2.  ${gl_bai}FanVideo 影视库"
        echo -e "${gl_bufan}3.  ${gl_bai}FanMD 云文档          ${gl_bufan}4.  ${gl_bai}Dufs-zh 文件服务"
        echo -e "${gl_bufan}5.  ${gl_bai}2Panel 计划任务       ${gl_bufan}6.  ${gl_bai}FanShop 容器管理"
        echo -e "${gl_bufan}7.  ${gl_bai}FanFiles 文件管理     ${gl_bufan}8.  ${gl_bai}FanReubah 格式转换"
        echo -e "${gl_bufan}9.  ${gl_bai}CmdBox 命令           ${gl_bufan}10. ${gl_bai}FanWebSSH 终端面板"
        echo -e "${gl_bufan}11. ${gl_bai}FanRandom 随机壁纸    ${gl_bufan}12. ${gl_bai}FanVideoDL 视频下载"
        echo -e "${gl_bufan}13. ${gl_bai}FanVideoCT 视频剪切   ${gl_bufan}14. ${gl_bai}FanNginx 反向代理"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单        ${gl_hong}00.  ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" action
        case "$action" in
            1)  fan_panel_push ;;
            2)  fan_video_push ;;
            3)  fan_md_push ;;
            4)  dufs-zh_push ;;
            5)  2panel_push ;;
            6)  fan-shop_push ;;
            7)  fan-files_push ;;
            8)  fan-reubah_push ;;
            9)  count_md_docs; cmdbox-main_push ;;
            10) fan-webssh_push ;;
            11) fan_random_push ;;
            12) fan_video_dl_push ;;
            13) fan_video_ct_push ;;
            14) fan_nginx_push ;;
            0)
                proj_mgmt_tool
                ;;
            00 | 000 | 0000)
                exit_script
                ;;
            "")
                echo -ne "\033[1A\r\033[K"
                echo -e "${gl_hong}❌ 不能为空${gl_bai}，请重新选择"
                sleep_fractional 0.6
                echo -ne "\033[1A\r\033[K"
                continue
                ;;
            *)
                handle_invalid_input
                ;;
        esac
    done
}

show_service_url() {
    local service="${1:-fan-video}"
    local url=""
    local port=""
    local ip
    ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    [ -z "$ip" ] && ip=$(ip route get 1 2>/dev/null | awk '{print $7}' | head -1)
    [ -z "$ip" ] && ip=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -1)
    [ -z "$ip" ] && ip="127.0.0.1"

    port=$(journalctl -u "$service" --no-pager -n 200 -o cat 2>/dev/null \
        | grep -E 'msg":"fan-video 启动于 :[0-9]+|Listening at: http://0\.0\.0\.0:[0-9]+|Server\(http\) is running on: http://localhost:[0-9]+' \
        | grep -oE ':[0-9]+$' | sed 's/^://' | head -1)

    if [ -z "$port" ];then
        port=$(grep -E '^PORT=' "/etc/${service}.conf" 2>/dev/null | head -1 | cut -d= -f2)
    fi

    if [ -z "$port" ];then
        local exec_cmd
        exec_cmd=$(systemctl show -p ExecStart "$service" 2>/dev/null | cut -d= -f2-)
        port=$(echo "$exec_cmd" | grep -oE ' -{1,2}port[ =]+[0-9]+' | grep -oE '[0-9]+' | head -1)
        [ -z "$port" ] && port=$(echo "$exec_cmd" | grep -oE -e '--bind 0\.0\.0\.0:[0-9]+' | grep -oE '[0-9]+$' | head -1)
    fi

    if [ -z "$port" ] && command -v ss >/dev/null 2>&1;then
        local pid
        pid=$(systemctl show -p MainPID "$service" 2>/dev/null | cut -d= -f2-)
        if [[ "$pid" =~ ^[0-9]+$ && "$pid" -gt 0 ]];then
            port=$(ss -tlnp 2>/dev/null | grep ",pid=$pid," | grep -oE ':[0-9]+' | sed 's/^://' | head -1)
        fi
    fi

    if [ -z "$port" ] && command -v docker >/dev/null 2>&1;then
        local dports
        dports=$(docker port "$service" 2>/dev/null | head -1)
        if [ -n "$dports" ];then
            port=$(echo "$dports" | grep -oE '0\.0\.0\.0:[0-9]+|\[::\]:[0-9]+' | grep -oE '[0-9]+$' | head -1)
        fi
    fi

    if [ -z "$port" ];then
        port=$(grep -E "ports:" -A5 "/vol1/1000/compose/${service}/docker-compose.yml" 2>/dev/null \
            | grep -oE '"[0-9]+:[0-9]+"|[0-9]+:[0-9]+' | head -1 | cut -d: -f1 | tr -d '"')
    fi

    if [ -n "$port" ]; then
        url="http://${ip}:${port}"
    fi

    if [ -n "$url" ]; then
        echo -e "访问地址：${gl_lv}${url}${gl_bai}"
    else
        echo -e "访问地址：${gl_hong}无法获取访问地址${gl_bai}"
        return 1
    fi
}

show_service_status() {
    local service="${1:-opencode}"
    local version=""
    local ver_regex='\b(v[0-9]+\.[0-9]+\.[0-9]+|[0-9]+\.[0-9]+\.[0-9]+)\b'
    if command -v "$service" &>/dev/null; then
        version=$("$service" --version 2>/dev/null | grep -vE '[_#]{3,}' | grep -oE "$ver_regex" | head -1)
        [ -z "$version" ] && version=$("$service" version 2>/dev/null | grep -vE '[_#]{3,}' | grep -oE "$ver_regex" | head -1)
    fi
    if [ -z "$version" ]; then
        local exec_path
        exec_path=$(systemctl show -p ExecStart "$service" 2>/dev/null | cut -d= -f2 | awk '{print $1}')
        if [ -n "$exec_path" ] && [ -x "$exec_path" ]; then
            version=$("$exec_path" --version 2>/dev/null | grep -vE '[_#]{3,}' | grep -oE "$ver_regex" | head -1)
            [ -z "$version" ] && version=$("$exec_path" version 2>/dev/null | grep -vE '[_#]{3,}' | grep -oE "$ver_regex" | head -1)
        fi
    fi
    if [ -z "$version" ] && command -v journalctl &>/dev/null; then
        version=$(journalctl -u "$service" --no-pager -n 50 -o cat 2>/dev/null | grep -oE "$ver_regex" | head -1)
    fi
    if [[ ! "$version" =~ $ver_regex ]]; then
        version=""
    fi
    if systemctl is-active --quiet "$service"; then
        echo -e "运行状态：${gl_lv}$service 正在运行${gl_bai}"
    else
        echo -e "运行状态：${gl_hong}$service 未运行${gl_bai}"
    fi
    if [ -n "$version" ]; then
        echo -e "版本信息：${gl_huang}$version${gl_bai}"
    else
        echo -e "版本信息：${gl_huang}无法获取${gl_bai}"
    fi
}

docker_compose_manager() {
    local FWORK_DIR="${1:-$PWD}"
    if ! cd "$FWORK_DIR" 2>/dev/null; then
        echo -e ""
        log_error "无法进入目录: ${gl_huang}$FWORK_DIR${gl_bai}"
        exit_animation
        return 1
    fi
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
        echo -ne "\r\033[K${gl_huang}无效的输入,请重新输入! ${gl_zi} 1 ${gl_huang} 秒后"
        sleep_fractional 1
        echo -ne "\r\033[K"
        sleep_fractional 1
        echo -ne "\r\033[K${gl_lv}无效的输入,请重新输入! ${gl_zi}0${gl_lv} 秒后"
        sleep_fractional 1
        echo -ne "\r\033[K"
        sleep_fractional 0.5
        echo -ne "\r\033[K"
        return 2
    }
    
    column_if_available() {
        if command -v column &> /dev/null; then
            column -t -s $'\t'
        else
            cat
        fi
    }

    list_beautify_compose_images() {
        if [[ ! -f "docker-compose.yml" && ! -f "compose.yml" ]]; then
            echo -e "${gl_hong}❌ 当前目录未找到 docker-compose.yml / compose.yml${gl_bai}"
            return 1
        fi

        {
            printf "%s%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "服务名" "完整镜像名" "镜像ID" "大小" "架构" "$reset"
            printf "%s%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "----------" "----------" "----------" "----------" "----------" "$reset"

            docker compose config | awk '
            BEGIN { in_svc=0; svc_name="" }
            /^services:/ { in_svc=1; next }
            in_svc == 1 && /^  [^ ]/ {
                sub(/:$/,"");
                svc_name=$0;
                gsub(/^[ \t]+/,"",svc_name); # 移除服务名开头空格
                next
            }
            in_svc ==1 && /^    image:/ {
                sub(/^    image:[ \t]*/,"");
                print svc_name "\t" $0;
            }' | while IFS=$'\t' read -r svc img; do
                if [[ -z "$svc" || -z "$img" ]]; then
                    continue
                fi
                if ! docker image inspect "$img" &>/dev/null; then
                    img_id="${gl_hong}镜像不存在${reset}"
                    size=""
                    platform=""
                else
                    img_id=$(docker image inspect --format '{{.Id}}' "$img" | sed 's/^sha256://' | cut -c1-12)
                    size_raw=$(docker image inspect --format '{{.Size}}' "$img")
                    if [[ "$size_raw" -gt 1073741824 ]]; then
                        size=$(awk -v s="$size_raw" 'BEGIN{printf "%.2f GB", s/1073741824}')
                    elif [[ "$size_raw" -gt 1048576 ]]; then
                        size=$(awk -v s="$size_raw" 'BEGIN{printf "%.2f MB", s/1048576}')
                    elif [[ "$size_raw" -gt 1024 ]]; then
                        size=$(awk -v s="$size_raw" 'BEGIN{printf "%.2f KB", s/1024}')
                    else
                        size="${size_raw} B"
                    fi
                    platform=$(docker image inspect --format '{{.Os}}/{{.Architecture}}' "$img")
                fi

                printf "%s\t%s\t%s\t%s\t%s\n" \
                    "${gl_lv}${svc}${reset}" \
                    "${gl_huang}${img}${reset}" \
                    "${gl_bufan}${img_id}${reset}" \
                    "${gl_lan}${size}${reset}" \
                    "${gl_bai}${platform}${reset}"
            done
        } | column_if_available
    }

    list_beautify_all() {
        echo
        echo -e "${gl_zi}>>> 当前 ${gl_huang}$current_dir_name${gl_zi} 项目镜像详情${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        list_beautify_compose_images
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
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
            echo -e "未检测到 http 端口映射"
            return 2
        }
        local ip=$(hostname -I | awk '{print $1}')
        echo -e "服务访问链接：${gl_lv}http://${ip}:${port}${gl_bai}"
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
        echo -e "${gl_zi}>>> 创建文件 ${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        if [[ -z $file_name ]]; then
            read -r -e -p "$(echo -e "${gl_bai}请输入文件名 (${gl_huang}0${gl_bai}返回): ")" file_name
            [[ -z "$file_name" ]] && { cancel_return "上一级选单"; return 1; }
            [[ "$file_name" == "0" ]] && { cancel_return "上一级选单"; return 1; }
        fi
        if [[ -e $file_name ]]; then
            echo -e "${gl_hong}文件已存在：$file_name${gl_bai}"
            local overwrite
            read -r -e -p "$(echo -e "${gl_bai}是否覆盖？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}，${gl_huang}0${gl_bai}返回): ")" overwrite
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
            read -r -e -p "$(echo -e "${gl_bai}检测到脚本文件，是否添加执行权限？ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}，${gl_huang}0${gl_bai}返回): ")" add_exec
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
        echo -e "${gl_zi}>>> 选择服务 ${gl_bai}"
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
            echo -e "${gl_bufan}$((i + 1)). ${gl_bai}${container_color}${service}${gl_bai} $status_text"
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

    view_compose_logs() {
        echo -e ""
        echo -e "${gl_bai}正在实时跟踪 ${gl_huang}$current_dir_name${gl_bai} 项目日志 ${gl_hong}(Ctrl+C 退出日志查看)${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        docker compose logs -f -t --tail 100
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    }
    
    show_compose_commands_menu() {
        local WORK_DIR="${1:-.}"
        if ! cd "$WORK_DIR" 2>/dev/null; then
            echo -e ""
            log_error "无法进入目录: ${gl_huang}$WORK_DIR${gl_bai}"
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
            echo -e "${gl_zi}>>> Compose项目菜单 ${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_bai}当前工作目录: ${gl_huang}$current_dir${gl_bai}"
            echo -e "${gl_bai}当前项目名称: ${gl_huang}$current_dir_name${gl_bai}"
            echo -e "${gl_bai}内网 IP 地址: ${gl_huang}$(get_internal_ip)${gl_bai}"
            docker inspect -f \
                '{{if .State.Running}}'"$gl_lv"'已启动'"$gl_bai"'{{else}}'"$gl_hui"'[已停止]'"$gl_bai"'{{end}}' \
                "$MAIN_SERVICE" >/dev/null 2>&1 && {
                echo -e "${gl_bai}主要容器状态：$(docker inspect -f \
                    '{{if .State.Running}}'"$gl_lv"'已启动'"$gl_bai"'{{else}}'"$gl_hui"'[已停止]'"$gl_bai"'{{end}}' \
                    "$MAIN_SERVICE")"
            } || {
                printf "${gl_bai}主要容器状态：${gl_hui}容器 ${gl_huang}%s${gl_hui} [不存在]${gl_bai}\n" "$MAIN_SERVICE"
            }
            show_inner_url
            local container_color=$(check_container_status "$MAIN_SERVICE")
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            compose_ps_beautify
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            list_beautify_compose_images
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_bufan}1.  ${gl_bai}停止${container_color}$current_dir_name${gl_bai}服务      ${gl_bufan}2.  ${gl_bai}启动${container_color}$current_dir_name${gl_bai}服务"
            echo -e "${gl_bufan}3.  ${gl_bai}重启${container_color}$current_dir_name${gl_bai}服务      ${gl_bufan}4.  ${gl_bai}更新${container_color}$current_dir_name${gl_bai}容器"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_bufan}5.  ${gl_bai}查看${container_color}$current_dir_name${gl_bai}配置文件  ${gl_bufan}6.  ${gl_bai}编辑${container_color}$current_dir_name${gl_bai}配置"
            echo -e "${gl_bufan}7.  ${gl_bai}创建${container_color}$current_dir_name${gl_bai}配置文件  ${gl_bufan}8.  ${gl_bai}查看${container_color}$current_dir_name${gl_bai}最终配置"
            echo -e "${gl_bufan}9.  ${container_color}$current_dir_name${gl_bai}服务日志      ${gl_bufan}10. ${gl_bai}跟踪${container_color}$current_dir_name${gl_bai}日志"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_bufan}11. ${gl_bai}查看${container_color}$current_dir_name${gl_bai}服务状态  ${gl_bufan}12. ${gl_bai}查看${container_color}$current_dir_name${gl_bai}镜像详情"
            echo -e "${gl_bufan}13. ${gl_bai}查看${container_color}$current_dir_name${gl_bai}资源占用  ${gl_bufan}14. ${gl_bai}拉取${container_color}$current_dir_name${gl_bai}镜像（不启动）"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_bufan}23. ${gl_bai}开放${container_color}$current_dir_name${gl_bai}访问端口  ${gl_bufan}24. ${gl_bai}重新构建${container_color}$current_dir_name${gl_bai}"
            echo -e "${gl_bufan}25. ${gl_bai}进入${container_color}$MAIN_SERVICE${gl_bai}服务终端  ${gl_bufan}26. ${gl_bai}修改${container_color}$MAIN_SERVICE${gl_bai}重启策略"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_huang}88. ${gl_huang}停止并清理${container_color}$current_dir_name${gl_bai}    ${gl_hong}99. ${gl_hong}彻底清理${container_color}$current_dir_name${gl_bai}"
            echo -e "${gl_huang}0.  ${gl_bai}返回${container_color}$MAIN_SERVICE${gl_bai}上一级    ${gl_hong}00. ${gl_bai}退出脚本"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

            read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" cmd_choice
            case $cmd_choice in
            1)
                echo -e ""
                echo -e "${gl_bai}正在停止并删除 ${gl_huang}$current_dir_name${gl_bai} 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                docker-compose down
                echo -e "\n"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
                ;;
            2)
                echo -e ""
                echo -e "正在启动 ${gl_huang}$current_dir_name${gl_bai} 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                docker-compose up -d --remove-orphans
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
                    echo -e "${gl_hong}[错误]: docker-compose.yml 文件不存在${gl_bai}"
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
                    echo -e "${gl_hong}[错误]: docker-compose.yml 文件不存在${gl_bai}"
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
                echo
                echo -e "${gl_bai}正在创建${gl_huang}$current_dir_name${gl_bai}配置文件"
                create_file docker-compose.yml
                ;;
            8)
                echo -e ""
                echo -e "${gl_bai}正在查看 ${gl_huang}$current_dir_name${gl_bai} 服务最终生效配置 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                docker-compose config
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
                ;;
            9)
                echo -e ""
                echo -e "${gl_bai}正在显示 ${gl_huang}$current_dir_name${gl_bai} 服务日志 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                docker-compose logs
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
                ;;
            10)
                view_compose_logs
                ;;
            11)
                echo -e ""
                echo -e "${gl_bai}正在显示 ${gl_huang}$current_dir_name${gl_bai} 服务状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                docker-compose ps
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
                ;;
            12)
                # docker-compose images
                list_beautify_all
                ;;
            13)
                echo
                echo -e "${gl_huang}$current_dir_name${gl_bai}服务列表 & 实时资源占用（Ctrl-C 退出）"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                bash <(curl -sL https://cmdbox.meimolihan.eu.org/sh/docker_occupy_find.sh) $current_dir_name
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

            23)
                echo -e ""
                echo -e "${gl_zi}>>> 开放$current_dir_name访问端口 ${gl_bai}"
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
                00|000|0000) exit_script; return 0 ;;
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
            88)
                echo -e ""
                echo -e "${gl_bai}正在停止并删除 ${gl_huang}$current_dir_name${gl_bai} 服务及相关资源 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                echo -e "${gl_hong}⚠️  警告: 此操作将删除容器、网络和卷、删除项目镜像！${gl_bai}"
                echo -e "${gl_bai}数据卷不会被删除，但网络和相关资源将被清理${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                read -r -e -p "$(echo -e "${gl_bai}确认执行？ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    # ⚠️ 警告: 此操作将删除当前项目容器、网络、项目数据卷；同时全局清理所有闲置镜像和闲置数据卷！
                    # docker-compose down --volumes --remove-orphans && docker system prune -af --volumes
                    # 停止容器、网络、删除项目镜像，同时清理孤儿容器 + 全部未使用镜像、全部未使用网络、全部未使用卷、悬空构建缓存
                    docker compose down --rmi all --remove-orphans && docker system prune -af --volumes
                    echo -e ""
                    echo -e "${gl_lv}✓ 服务、网络和卷已清理完成${gl_bai}"
                else
                    echo -e "${gl_huang}已取消操作${gl_bai}"
                fi
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
                ;;
            99)
                echo -e ""
                echo -e "${gl_bai}正在停止并删除 ${gl_huang}$current_dir_name${gl_bai} 服务及相关资源 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                echo -e "${gl_hong}⚠️  警告: 此操作将删除容器、网络、卷、镜像，并且【删除整个项目目录】！${gl_bai}"
                echo -e "${gl_hong}项目目录路径：${gl_huang}${current_dir}${gl_bai}"
                echo -e "${gl_bai}目录内所有文件都会被永久删除！${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                read -r -e -p "$(echo -e "${gl_hong}确认要执行吗？ ${gl_bai}(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    docker compose down --rmi all --remove-orphans && docker system prune -af --volumes
                    echo -e "${gl_lv}✓ Compose容器、网络、卷已清理${gl_bai}"

                    local parent_dir=$(dirname "${current_dir}")
                    cd "${parent_dir}" || {
                        log_error "无法切换到上级目录 ${parent_dir}"
                        read -r
                        break_end
                    }

                    echo -e "${gl_huang}正在删除项目目录：${current_dir}${gl_bai}"
                    rm -rf "${current_dir}"
                    echo -e "${gl_lv}✓ 项目目录已彻底删除${gl_bai}"

                    return 0
                else
                    echo -e "${gl_huang}已取消操作${gl_bai}"
                fi
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
                ;;
        0)
            proj_mgmt_tool
            ;;
        00 | 000 | 0000)
            exit_script
            ;;
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
        return 0
    }
    
    check_docker() {
        if ! docker info &>/dev/null; then
            log_error "Docker 服务未运行"
            return 1
        fi
        if ! command -v docker-compose &>/dev/null && ! docker compose version &>/dev/null; then
            log_error "未找到 docker-compose 命令"
            echo -e "${gl_bai}请安装 docker-compose 或使用 docker compose${gl_bai}"
            return 1
        fi
    }
    
    main() {
        local WORK_DIR="."
        while [[ $# -gt 0 ]]; do
            case "$1" in
                -h|--help)
                    show_help
                    return 0
                    ;;
                *)
                    WORK_DIR="$1"
                    shift
                    ;;
            esac
        done
        check_docker || return 1
        if [[ ! -d "$WORK_DIR" ]]; then
            log_error "目录不存在: $WORK_DIR"
            return 1
        fi
        if [[ ! -f "$WORK_DIR/docker-compose.yml" ]] && [[ ! -f "$WORK_DIR/docker-compose.yaml" ]]; then
            echo -e "${gl_huang}警告: 在 $WORK_DIR 中未找到 docker-compose.yml 文件${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bai}是否创建新的 docker-compose.yml 文件？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" create_choice
            if [[ "$create_choice" =~ ^[Yy]$ ]]; then
                if ! cd "$WORK_DIR" 2>/dev/null; then
                    log_error "无法进入目录: $WORK_DIR"
                    return 1
                fi
                create_file docker-compose.yml
            else
                echo -e "${gl_huang}已取消${gl_bai}"
                return 0
            fi
        fi
        show_compose_commands_menu "$WORK_DIR"
        return 0
    }
    main "$@"
    return $?
}

manage_fan_video() {
    SERVICE="fan-video"
    INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-video/main/scripts/install.sh"
    UNINSTALL_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-video/main/scripts/uninstall.sh"
    BACKUP_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-video/main/scripts/fan-video_backup.sh"
    RECOVER_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-video/main/scripts/fan-video_recover.sh"
    while true; do
        clear
        echo -e ""
        echo -e "${gl_zi}>>> fan-video 管理工具${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        show_service_status fan-video
        show_service_url fan-video
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}停止 fan-video       ${gl_bufan}2.  ${gl_bai}启动 fan-video"
        echo -e "${gl_bufan}3.  ${gl_bai}重启 fan-video       ${gl_bufan}4.  ${gl_bai}查看服务状态"
        echo -e "${gl_bufan}5.  ${gl_bai}查看开机自启状态     ${gl_bufan}6.  ${gl_bai}开启开机自启"
        echo -e "${gl_bufan}7.  ${gl_bai}禁用开机自启         ${gl_bufan}8.  ${gl_bai}查看日志(100行)"
        echo -e "${gl_bufan}9.  ${gl_bai}实时跟踪日志"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_lv}66. ${gl_bai}安装/升级 fan-video  ${gl_huang}77. ${gl_bai}备份数据"
        echo -e "${gl_lv}88. ${gl_bai}恢复数据             ${gl_hong}99. ${gl_bai}卸载 fan-video"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单       ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" action
        case "$action" in
        1)
            echo -e ""
            echo -e "${gl_zi}>>> 正在停止 fan-video 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl stop ${SERVICE}
            log_ok "fan-video 服务已停止"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        2)
            echo -e ""
            echo -e "${gl_zi}>>> 正在启动 fan-video 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl start ${SERVICE}
            log_ok "fan-video 服务已启动"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        3)
            echo -e ""
            echo -e "${gl_zi}>>> 正在重启 fan-video 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl restart ${SERVICE}
            log_ok "fan-video 服务已重启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        4)
            echo -e ""
            echo -e "${gl_zi}>>> fan-video 服务状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl status ${SERVICE}
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        5)
            echo -e ""
            echo -e "${gl_zi}>>> fan-video 开机自启状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            local status=$(sudo systemctl is-enabled ${SERVICE} 2>/dev/null)
            case "$status" in
                enabled)   echo -e "${gl_lv}已启用${gl_bai}" ;;
                disabled)  echo -e "${gl_hong}已禁用${gl_bai}" ;;
                static)    echo "静态（非服务单元）" ;;
                indirect)  echo "间接（依赖其他单元）" ;;
                *)         echo "$status" ;;
            esac
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        6)
            echo -e ""
            echo -e "${gl_zi}>>> 正在开启 fan-video 开机自启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl enable ${SERVICE}
            log_ok "已开启 fan-video 开机自启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        7)
            echo -e ""
            echo -e "${gl_zi}>>> 正在禁用 fan-video 开机自启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl disable ${SERVICE}
            log_ok "已禁用 fan-video 开机自启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        8)
            echo -e ""
            echo -e "${gl_zi}>>> fan-video 日志（最近100行）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo journalctl -u ${SERVICE} -n 100
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        9)
            echo -e ""
            echo -e "${gl_zi}>>> 实时跟踪 fan-video 日志（按 Ctrl+C 退出）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo journalctl -u ${SERVICE} -f
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        66)
            bash -c "$(curl -sSL ${INSTALL_SCRIPT_URL})"
            break_end
            continue
            ;;
        77)
            bash <(curl -sL ${BACKUP_SCRIPT_URL}) "/vol2/1000/file/backup/fan-video-backup" 6
            break_end
            continue
            ;;
        88)
            bash <(curl -sL ${RECOVER_SCRIPT_URL}) "/vol2/1000/file/backup/fan-video-backup"
            break_end
            continue
            ;;
        99)
            bash <(curl -sSL ${UNINSTALL_SCRIPT_URL})
            break_end
            continue
            ;;
        0)
            proj_mgmt_tool
            ;;
        00 | 000 | 0000)
            exit_script
            ;;
        *)
            handle_invalid_input
            ;;
        esac
    done
}

manage_opencode() {
    while true; do
        clear
        echo -e ""
        echo -e "${gl_zi}>>> OpenCode 管理工具${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        show_service_status opencode
        show_service_url opencode
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}停止 OpenCode          ${gl_bufan}2.  ${gl_bai}启动 OpenCode"
        echo -e "${gl_bufan}3.  ${gl_bai}重启 OpenCode          ${gl_bufan}4.  ${gl_bai}查看服务状态"
        echo -e "${gl_bufan}5.  ${gl_bai}查看开机自启状态       ${gl_bufan}6.  ${gl_bai}禁用开机自启"
        echo -e "${gl_bufan}7.  ${gl_bai}查看日志               ${gl_bufan}8.  ${gl_bai}实时跟踪日志"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_lv}66. ${gl_bai}安装 OpenCode          ${gl_hong}99. ${gl_bai}卸载 OpenCode"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单         ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" action
        case "$action" in
        1)
            echo -e ""
            echo -e "${gl_zi}>>> 正在停止 OpenCode 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl stop opencode
            log_ok "OpenCode 服务已停止"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        2)
            echo -e ""
            echo -e "${gl_zi}>>> 正在启动 OpenCode 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl start opencode
            log_ok "OpenCode 服务已启动"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        3)
            echo -e ""
            echo -e "${gl_zi}>>> 正在重启 OpenCode 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl restart opencode
            log_ok "OpenCode 服务已重启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        4)
            echo -e ""
            echo -e "${gl_zi}>>> OpenCode 服务状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl status opencode
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        5)
            echo -e ""
            echo -e "${gl_zi}>>> OpenCode 开机自启状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            local status=$(sudo systemctl is-enabled opencode 2>/dev/null)
            case "$status" in
                enabled)   echo -e "已启用" ;;
                disabled)  echo -e "已禁用" ;;
                static)    echo "静态（非服务单元）" ;;
                indirect)  echo "间接（依赖其他单元）" ;;
                *)         echo "$status" ;;
            esac
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        6)
            echo -e ""
            echo -e "${gl_zi}>>> 正在禁用 OpenCode 开机自启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl disable opencode
            log_ok "已禁用 OpenCode 开机自启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        7)
            echo -e ""
            echo -e "${gl_zi}>>> OpenCode 日志（最近100行）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo journalctl -u opencode -n 100
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        8)
            echo -e ""
            echo -e "${gl_zi}>>> 实时跟踪 OpenCode 日志（按 Ctrl+C 退出）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo journalctl -u opencode -f
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        66)
            bash <(curl -sL gitee.com/meimolihan/cmdbox/raw/master/sh/lx_install_opencode.sh)
            ;;
        99)
            bash <(curl -sL gitee.com/meimolihan/cmdbox/raw/master/sh/lx_uninstall_opencode.sh)
            ;;
        0)
            proj_mgmt_tool
            ;;
        00 | 000 | 0000)
            exit_script
            ;;
        *)
            handle_invalid_input
            ;;
        esac
    done
}

manage_2panel() {
    SERVICE="2panel"
    INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/2Panel/main/scripts/install.sh"
    UNINSTALL_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/2Panel/main/scripts/uninstall.sh"
    BACKUP_SCRIPT_URL="gitee.com/meimolihan/cmdbox/raw/master/sh/2panel_backup.sh"
    RECOVER_SCRIPT_URL="gitee.com/meimolihan/cmdbox/raw/master/sh/2panel_recover.sh"
    while true; do
        clear
        echo -e ""
        echo -e "${gl_zi}>>> 2Panel 管理工具${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        show_service_status 2panel
        show_service_url 2panel
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}停止 2Panel         ${gl_bufan}2.  ${gl_bai}启动 2Panel"
echo -e "${gl_bufan}3.  ${gl_bai}重启 2Panel         ${gl_bufan}4.  ${gl_bai}查看服务状态"
        echo -e "${gl_bufan}5.  ${gl_bai}查看开机自启状态    ${gl_bufan}6.  ${gl_bai}开启开机自启"
        echo -e "${gl_bufan}7.  ${gl_bai}禁用开机自启        ${gl_bufan}8.  ${gl_bai}查看日志(100行)"
        echo -e "${gl_bufan}9.  ${gl_bai}实时跟踪日志"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_lv}66. ${gl_bai}安装/升级 2Panel    ${gl_huang}77. ${gl_bai}备份数据"
        echo -e "${gl_lv}88. ${gl_bai}恢复数据            ${gl_hong}99. ${gl_bai}卸载 2Panel"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单      ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" action
        case "$action" in
        1)
            echo -e ""
            echo -e "${gl_zi}>>> 正在停止 2Panel 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl stop ${SERVICE}
            log_ok "2Panel 服务已停止"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        2)
            echo -e ""
            echo -e "${gl_zi}>>> 正在启动 2Panel 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl start ${SERVICE}
            log_ok "2Panel 服务已启动"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        3)
            echo -e ""
            echo -e "${gl_zi}>>> 正在重启 2Panel 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl restart ${SERVICE}
            log_ok "2Panel 服务已重启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        4)
            echo -e ""
            echo -e "${gl_zi}>>> 2Panel 服务状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl status ${SERVICE}
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        5)
            echo -e ""
            echo -e "${gl_zi}>>> 2Panel 开机自启状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            local status=$(sudo systemctl is-enabled ${SERVICE} 2>/dev/null)
            case "$status" in
                enabled)   echo -e "${gl_lv}已启用${gl_bai}" ;;
                disabled)  echo -e "${gl_hong}已禁用${gl_bai}" ;;
                static)    echo "静态（非服务单元）" ;;
                indirect)  echo "间接（依赖其他单元）" ;;
                *)         echo "$status" ;;
            esac
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        6)
            echo -e ""
            echo -e "${gl_zi}>>> 正在开启 2Panel 开机自启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl enable ${SERVICE}
            log_ok "已开启 2Panel 开机自启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        7)
            echo -e ""
            echo -e "${gl_zi}>>> 正在禁用 2Panel 开机自启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl disable ${SERVICE}
            log_ok "已禁用 2Panel 开机自启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        8)
            echo -e ""
            echo -e "${gl_zi}>>> 2Panel 日志（最近100行）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo journalctl -u ${SERVICE} -n 100
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        9)
            echo -e ""
            echo -e "${gl_zi}>>> 实时跟踪 2Panel 日志（按 Ctrl+C 退出）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo journalctl -u ${SERVICE} -f
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        66)
            bash -c "$(curl -sSL ${INSTALL_SCRIPT_URL})"
            ;;
        77)
            bash <(curl -sL ${BACKUP_SCRIPT_URL}) "/vol2/1000/file/backup/2panel-backup" 6
            break_end
            ;;
        88)
            bash <(curl -sL ${RECOVER_SCRIPT_URL}) /vol2/1000/file/backup/2panel-backup
            break_end
            ;;
        99)
            bash <(curl -sSL ${UNINSTALL_SCRIPT_URL})
            ;;
        0)
            proj_mgmt_tool
            ;;
        00 | 000 | 0000)
            exit_script
            ;;
        *)
            handle_invalid_input
            ;;
        esac
    done
}

is_compose_running() {
    local dir="$1"

    if [[ ! -d "$dir" ]]; then
        return 1
    fi
    if [[ ! -f "$dir/docker-compose.yml" ]] && [[ ! -f "$dir/docker-compose.yaml" ]]; then
        return 1
    fi

    (
        cd "$dir" 2>/dev/null || exit 1
        # 优先使用 docker-compose（旧版）
        if command -v docker-compose &>/dev/null; then
            docker-compose ps -q 2>/dev/null | grep -q .
        # 其次使用 docker compose（新版）
        elif docker compose version &>/dev/null 2>&1; then
            docker compose ps -q 2>/dev/null | grep -q .
        else
            # 兜底：通过 docker ps 过滤项目标签
            local project_name
            project_name=$(basename "$dir")
            docker ps --filter "label=com.docker.compose.project=$project_name" -q 2>/dev/null | grep -q .
        fi
    )
}

monitor_tool() {

    monitor_status_show() {
        local SERVICE="monitor.service"
        local STATUS
        STATUS=$(systemctl status "$SERVICE" --no-pager --lines=5 2>/dev/null)
        if [ $? -ne 0 ]; then
            log_error "服务 ${SERVICE} 不存在或未安装"
            return 1
        fi

        local ACTIVE=$(echo "$STATUS" | awk '/Active:/ {print $2}')
        local STATE
        if [[ "$ACTIVE" == "active" ]]; then
            STATE="${gl_lv}运行中 ✅${gl_bai}"
        else
            STATE="${gl_hong}已停止 ❌${gl_bai}"
        fi

        local PID=$(echo "$STATUS" | awk '/Main PID:/ {print $3}')
        local MEM=$(echo "$STATUS" | awk '/Memory:/ {print $2}')
        local CPU=$(echo "$STATUS" | awk '/CPU:/ {print $2}')

        local LAST_LOG
        LAST_LOG=$(echo "$STATUS" | grep -E "^[[:space:]]*[A-Za-z]{3} [0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}" | tail -1 | sed 's/^[[:space:]]*//' | cut -d' ' -f4-)
        [[ -z "${LAST_LOG:-}" ]] && LAST_LOG="暂无日志输出"

        local TV_STATUS
        if echo "$LAST_LOG" | grep -q "电视上线\|检测到电视上线"; then
            TV_STATUS="${gl_lv}电视已上线 📺${gl_bai}"
        elif echo "$LAST_LOG" | grep -q "电视离线"; then
            TV_STATUS="${gl_huang}电视离线 💤${gl_bai}"
        elif echo "$LAST_LOG" | grep -q "启动成功"; then
            TV_STATUS="${gl_lv}APP 已启动 🚀${gl_bai}"
        elif echo "$LAST_LOG" | grep -q "启动失败\|请求失败"; then
            TV_STATUS="${gl_hong}启动失败 ❌${gl_bai}"
        else
            TV_STATUS="${gl_hui}未知状态${gl_bai}"
        fi

        echo ""
        echo -e "${gl_zi}>>> 电视自动启动监控服务状态${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bai}服务状态  : $STATE"
        echo -e "${gl_bai}主进程 PID: ${PID:-—}"
        echo -e "${gl_bai}内存占用  : ${MEM:-—}"
        echo -e "${gl_bai}CPU 耗时  : ${CPU:-—}"
        echo -e "${gl_bai}电视状态  : $TV_STATUS"
        echo -e "${gl_bai}最近活动  : ${LAST_LOG}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
    }

    check_dependencies() {
        if ! command -v androguard &>/dev/null && ! command -v aapt &>/dev/null; then
            log_warn "未检测到 androguard 或 aapt，尝试自动安装 androguard ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            if command -v apt &>/dev/null; then
                apt update && apt install androguard -y
                if [ $? -eq 0 ]; then
                    log_ok "androguard 安装成功"
                    return 0
                else
                    log_error "apt 安装 androguard 失败，请手动安装"
                    return 1
                fi
            else
                log_error "当前系统不是 Debian/Ubuntu，请手动安装 androguard 或 aapt"
                return 1
            fi
        fi
        return 0
    }

    extract_package_name() {
        local apk_path="$1"
        local pkg_name=""

        if command -v androguard &>/dev/null; then
            if command -v python3 &>/dev/null; then
                pkg_name=$(androguard apkid "${apk_path}" 2>/dev/null | python3 -c "import json,sys; data=json.load(sys.stdin); print(list(data.values())[0][0])" 2>/dev/null)
            else
                pkg_name=$(androguard apkid "${apk_path}" 2>/dev/null | grep -o '"[^"]*"' | head -1 | tr -d '"')
            fi
        elif command -v aapt &>/dev/null; then
            pkg_name=$(aapt dump badging "${apk_path}" 2>/dev/null | grep -E '^package:' | sed -n "s/.*name='\([^']*\)'.*/\1/p")
        fi

        echo "$pkg_name" | tr -d '\n\r'
    }

    monitor_install() {
        echo ""
        echo -e "${gl_zi}>>> 开始安装 monitor 监控服务${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        if ! check_dependencies; then
            log_error "依赖安装失败，请手动安装 androguard 或 aapt"
            return 1
        fi

        local apk_path=""
        while true; do
            read -r -e -p "$(echo -e "${gl_bai}请输入APK完整路径: ")" apk_path
            apk_path="${apk_path// /}"
            if [[ -z "$apk_path" ]]; then
                log_warn "路径不能为空，请重新输入"
                continue
            fi
            if [[ ! -f "$apk_path" ]]; then
                log_error "文件不存在：${apk_path}"
                continue
            fi
            break
        done

        log_info "正在解析包名 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        local pkg_name=""
        pkg_name=$(extract_package_name "$apk_path")
        if [[ -z "$pkg_name" ]]; then
            log_warn "自动解析包名失败，请手动输入包名（例如 com.trim.tv）"
            read -r -e -p "$(echo -e "${gl_bai}请输入应用包名: ")" pkg_name
            pkg_name="${pkg_name// /}"
            if [[ -z "$pkg_name" ]]; then
                log_error "包名不能为空"
                return 1
            fi
        else
            log_ok "解析得到应用包名：${gl_lv}${pkg_name}${gl_bai}"
            echo -e "${gl_hui}如需修改，可在此输入新包名（直接回车使用自动提取的）${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bai}确认包名（直接回车使用）: ")" manual_pkg
            if [[ -n "$manual_pkg" ]]; then
                pkg_name="$manual_pkg"
                log_info "使用手动输入的包名：${gl_lv}${pkg_name}${gl_bai}"
            fi
        fi

        local tv_ip=""
        while true; do
            read -r -e -p "$(echo -e "${gl_bai}请输入电视IP地址: ")" tv_ip
            tv_ip="${tv_ip// /}"
            if [[ -z "$tv_ip" ]]; then
                log_warn "IP不能为空，请重新输入"
                continue
            fi
            break
        done
        log_ok "电视IP设置为：${gl_lv}${tv_ip}${gl_bai}"

        mkdir -p /opt/scripts
        log_info "生成 /opt/scripts/monitor.sh"
        cat > /opt/scripts/monitor.sh <<'EOF'
#!/bin/sh
# ============================================================
# Xiaomi TV Auto Start APP
# fnOS / Linux 常驻监控脚本
# ============================================================
# 配置区（可自行修改）
# ============================================================
TV_IP="__TV_IP__"
APP_PACKAGE="__PKG_NAME__"
CHECK_INTERVAL=5
TV_PORT=6095
START_APP_URL="http://${TV_IP}:${TV_PORT}/controller?action=startapp&&type=packagename&packagename=${APP_PACKAGE}"
# ============================================================
# 状态变量
# ============================================================
TV_ONLINE=0
APP_STARTED=0
# ============================================================
# 启动日志输出
# ============================================================
echo "========================================================"
echo "         Xiaomi TV Auto Start APP"
echo "========================================================"
echo
echo "TV IP       : ${TV_IP}"
echo "APP Package : ${APP_PACKAGE}"
echo "Check       : ${CHECK_INTERVAL} 秒"
echo "URL         : ${START_APP_URL}"
echo
echo "========================================================"
echo "开始监控 ..."
echo "按 Ctrl+C 停止。"
echo "========================================================"
echo
# ============================================================
# 依赖检测
# ============================================================
if ! command -v ping >/dev/null 2>&1; then
    echo "错误：系统中没有 ping 命令。"
    exit 1
fi
if ! command -v curl >/dev/null 2>&1; then
    echo "错误：系统中没有 curl 命令。"
    exit 1
fi
# ============================================================
# APP 启动函数
# ============================================================
start_app()
{
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 正在尝试启动 APP ..."
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 包名: ${APP_PACKAGE}"
    RESPONSE=$(curl \
        --silent \
        --show-error \
        --max-time 5 \
        "${START_APP_URL}" 2>/dev/null)
    CURL_RESULT=$?
    if [ ${CURL_RESULT} -ne 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 请求失败。5秒后重试。"
        return 1
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 请求发送成功。"
    echo "${RESPONSE}" | grep -qi "success"
    if [ $? -eq 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] APP 启动成功，本次开机不再重复启动。"
        APP_STARTED=1
        return 0
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] APP 未启动成功，返回内容: ${RESPONSE}"
        return 1
    fi
}

while true
do
    ping -c 1 -W 1 "${TV_IP}" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        if [ "${TV_ONLINE}" -eq 1 ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] 电视离线，重置启动状态。"
            TV_ONLINE=0
            APP_STARTED=0
        fi
        sleep ${CHECK_INTERVAL}
        continue
    fi

    if [ "${TV_ONLINE}" -eq 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 检测到电视上线。"
        TV_ONLINE=1
    fi

    if [ "${APP_STARTED}" -eq 0 ]; then
        start_app
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 电视在线，APP 已启动。"
    fi

    sleep ${CHECK_INTERVAL}
done
EOF

        tv_ip_clean=$(echo "$tv_ip" | tr -d '\n\r')
        pkg_name_clean=$(echo "$pkg_name" | tr -d '\n\r')

        if ! sed -i "s|__TV_IP__|${tv_ip_clean}|g" /opt/scripts/monitor.sh 2>/dev/null; then
            log_error "替换 TV_IP 失败，请手动编辑 /opt/scripts/monitor.sh"
            return 1
        fi
        if ! sed -i "s|__PKG_NAME__|${pkg_name_clean}|g" /opt/scripts/monitor.sh 2>/dev/null; then
            log_error "替换 PKG_NAME 失败，请手动编辑 /opt/scripts/monitor.sh"
            return 1
        fi
        chmod +x /opt/scripts/monitor.sh

        log_info "生成 /etc/systemd/system/monitor.service"
        cat > /etc/systemd/system/monitor.service <<'EOF'
[Unit]
Description=TV App AutoStart Monitor
After=network.target

[Service]
Type=simple
ExecStart=/opt/scripts/monitor.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

        systemctl daemon-reload
        systemctl enable monitor.service
        systemctl start monitor.service

        log_ok "monitor.service 安装完成，已设置开机自启并启动服务"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        return 0
    }

    monitor_simple_status() {
        local SERVICE="monitor.service"
        local STATUS_OUT
        STATUS_OUT=$(systemctl status "$SERVICE" --no-pager --lines=0 2>/dev/null)
        if [ $? -ne 0 ]; then
            log_error "服务 ${SERVICE} 不存在或未安装"
            return 1
        fi

        local ACTIVE=$(echo "$STATUS_OUT" | awk '/Active:/ {print $2}')
        local STATE
        if [[ "$ACTIVE" == "active" ]]; then
            STATE="${gl_lv}运行中 ✅${gl_bai}"
        else
            STATE="${gl_hong}已停止 ❌${gl_bai}"
        fi

        local LOG_LINES
        LOG_LINES=$(journalctl -u "${SERVICE}" --no-pager -n 10 -o cat 2>/dev/null | tac 2>/dev/null || tail -r 2>/dev/null)
        if [[ -z "$LOG_LINES" ]]; then
            LOG_LINES=$(systemctl status "$SERVICE" --no-pager --lines=10 2>/dev/null | grep -E "^[[:space:]]*[A-Za-z]{3} [0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}" | sed 's/^[[:space:]]*//' | cut -d' ' -f4- | tac 2>/dev/null || tail -r 2>/dev/null)
        fi

        local LAST_LOG=""
        local TV_STATUS="${gl_hui}暂无有效状态 ⚠️${gl_bai}"

        if [[ -n "$LOG_LINES" ]]; then
            while IFS= read -r line; do
                if [[ -z "$line" ]]; then continue; fi

                if echo "$line" | grep -qE "电视上线|检测到电视上线|电视在线"; then
                    TV_STATUS="${gl_lv}电视已上线 📺${gl_bai}"
                    LAST_LOG="$line"
                    break
                fi

                if echo "$line" | grep -q "电视离线"; then
                    TV_STATUS="${gl_huang}电视离线 💤${gl_bai}"
                    LAST_LOG="$line"
                    break
                fi

                if echo "$line" | grep -qE "启动成功|APP 已启动"; then
                    TV_STATUS="${gl_lv}APP 已启动 🚀${gl_bai}"
                    LAST_LOG="$line"
                    break
                fi

                if echo "$line" | grep -qE "启动失败|请求失败"; then
                    TV_STATUS="${gl_hong}启动失败 ❌${gl_bai}"
                    LAST_LOG="$line"
                    break
                fi
            done <<< "$LOG_LINES"
        fi

        if [[ -z "$LAST_LOG" && -n "$LOG_LINES" ]]; then
            LAST_LOG=$(echo "$LOG_LINES" | head -n1)
            TV_STATUS="${gl_hui}最近日志: ${LAST_LOG}${gl_bai}"
        fi

        echo -e "${gl_bai}服务状态 : $STATE"
        echo -e "${gl_bai}电视状态 : $TV_STATUS"
        if [[ -n "$LAST_LOG" ]]; then
            echo -e "${gl_hui}最新活动 : ${LAST_LOG}${gl_bai}"
        fi
    }

    monitor_menu() {
        while true; do
            clear
            echo -e "${gl_zi}>>> TV monitor 服务管理${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            monitor_simple_status
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_bufan}1.  ${gl_bai}停止 monitor           ${gl_bufan}2.  ${gl_bai}启动 monitor"
            echo -e "${gl_bufan}3.  ${gl_bai}重启 monitor           ${gl_bufan}4.  ${gl_bai}查看服务状态"
            echo -e "${gl_bufan}5.  ${gl_bai}查看开机自启状态       ${gl_bufan}6.  ${gl_bai}禁用开机自启"
            echo -e "${gl_bufan}7.  ${gl_bai}查看日志               ${gl_bufan}8.  ${gl_bai}实时跟踪日志"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_lv}66. ${gl_bai}安装 monitor           ${gl_hong}99. ${gl_bai}卸载 monitor 全套"
echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单         ${gl_hong}00. ${gl_bai}退出脚本"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

            read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" action

            case "$action" in
            1)
                echo ""
                echo -e "${gl_zi}>>> 停止 monitor${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                log_info "正在停止 monitor.service"
                systemctl stop monitor.service 2>/dev/null
                log_ok "monitor.service 已停止"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
                ;;
            2)
                echo ""
                echo -e "${gl_zi}>>> 启动 monitor${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                log_info "正在启动 monitor.service"
                systemctl start monitor.service 2>/dev/null
                log_ok "monitor.service 已启动"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
                ;;
            3)
                echo ""
                echo -e "${gl_zi}>>> 重启 monitor${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                log_info "正在重启 monitor.service"
                systemctl restart monitor.service 2>/dev/null
                log_ok "monitor.service 已重启"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
                ;;
            4)
                monitor_status_show
                ;;
            5)
                echo ""
                echo -e "${gl_zi}>>> monitor 开机自启状态${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                local ena_stat=$(systemctl is-enabled monitor.service 2>/dev/null || echo "未安装")
                case "$ena_stat" in
                    enabled)   echo -e "${gl_lv}已启用${gl_bai}" ;;
                    disabled)  echo -e "${gl_huang}已禁用${gl_bai}" ;;
                    static)    echo -e "${gl_hui}静态单元${gl_bai}" ;;
                    indirect)  echo -e "${gl_hui}间接依赖${gl_bai}" ;;
                    *)         echo "$ena_stat" ;;
                esac
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
                ;;
            6)
                echo ""
                echo -e "${gl_zi}>>> 禁用 monitor 开机自启${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                log_info "正在禁用 monitor 开机自启"
                systemctl disable monitor.service 2>/dev/null
                log_ok "已禁用 monitor 开机自启"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
                ;;
            7)
                echo ""
                echo -e "${gl_zi}>>> monitor 日志（最近100行）${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                journalctl -u monitor.service -n 100
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
                ;;
            8)
                echo ""
                echo -e "${gl_zi}>>> 实时跟踪日志（按 Ctrl+C 返回）${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                journalctl -u monitor.service -f
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
                ;;
            66)
                monitor_install
                break_end
                ;;
            99)
                echo ""
                echo -e "${gl_zi}>>> 彻底卸载 monitor.service${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                read -r -e -p "$(echo -e "${gl_bai}即将彻底卸载 monitor.service，确认继续？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" ans
                if [[ "${ans,,}" == "y" ]]; then
                    systemctl stop monitor.service 2>/dev/null
                    systemctl disable monitor.service 2>/dev/null
                    rm -f /etc/systemd/system/monitor.service
                    systemctl daemon-reload
                    rm -f /opt/scripts/monitor.sh
                    rmdir /opt/scripts 2>/dev/null
                    log_ok "monitor.service 全套卸载完成"
                else
                    log_info "已取消卸载"
                fi
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
                ;;
            0)
                proj_mgmt_tool
                ;;
            00 | 000 | 0000)
                exit_script
                ;;
            *)
                handle_invalid_input
                ;;
            esac
        done
    }

    monitor_menu
}

fan_files_vars() {
    cat <<'EOF'
SERVICE="fan-files"
INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-files/main/scripts/install.sh"
UNINSTALL_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-files/main/scripts/uninstall.sh"
BACKUP_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-files/main/scripts/fan-files_backup.sh"
RECOVER_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-files/main/scripts/fan-files_recover.sh"
EOF
}

fan_files_show_service_url() {
    local service="${1:-fan-files}"
    local url=""
    local port=""
    local ip
    ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    [ -z "$ip" ] && ip=$(ip route get 1 2>/dev/null | awk '{print $7}' | head -1)
    [ -z "$ip" ] && ip=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -1)
    [ -z "$ip" ] && ip="127.0.0.1"
    port=$(journalctl -u "$service" --no-pager -n 200 -o cat 2>/dev/null \
        | grep -E 'fan-files 启动于 :[0-9]+' \
        | grep -oE ':[0-9]+$' | sed 's/^://' | head -1)
    if [ -z "$port" ];then
        local exec_cmd
        exec_cmd=$(systemctl show -p ExecStart "$service" 2>/dev/null | cut -d= -f2-)
        port=$(echo "$exec_cmd" | grep -oE ' -{1,2}port[ =]+[0-9]+' | grep -oE '[0-9]+' | head -1)
    fi
    if [ -z "$port" ] && command -v ss >/dev/null 2>&1;then
        local pid
        pid=$(systemctl show -p MainPID "$service" 2>/dev/null | cut -d= -f2-)
        if [[ "$pid" =~ ^[0-9]+$ && "$pid" -gt 0 ]];then
            port=$(ss -tlnp 2>/dev/null | grep ",pid=$pid," | grep -oE ':[0-9]+' | sed 's/^://' | head -1)
        fi
    fi
    if [ -n "$port" ]; then
        url="http://${ip}:${port}"
    fi
    if [ -n "$url" ]; then
        echo -e "访问地址：${gl_lv}${url}${gl_bai}"
    else
        echo -e "访问地址：${gl_hong}无法获取访问地址${gl_bai}"
        return 1
    fi
}

fan_files_show_service_status() {
    local service="${1:-fan-files}"
    local version=""
    local ver_regex='\b(v[0-9]+\.[0-9]+\.[0-9]+|[0-9]+\.[0-9]+\.[0-9]+)\b'
    if command -v "$service" &>/dev/null; then
        version=$("$service" --version 2>/dev/null | grep -vE '[_#]{3,}' | grep -oE "$ver_regex" | head -1)
        [ -z "$version" ] && version=$("$service" version 2>/dev/null | grep -vE '[_#]{3,}' | grep -oE "$ver_regex" | head -1)
    fi
    if [ -z "$version" ]; then
        local exec_path
        exec_path=$(systemctl show -p ExecStart "$service" 2>/dev/null | cut -d= -f2 | awk '{print $1}')
        if [ -n "$exec_path" ] && [ -x "$exec_path" ]; then
            version=$("$exec_path" --version 2>/dev/null | grep -vE '[_#]{3,}' | grep -oE "$ver_regex" | head -1)
            [ -z "$version" ] && version=$("$exec_path" version 2>/dev/null | grep -vE '[_#]{3,}' | grep -oE "$ver_regex" | head -1)
        fi
    fi
    if [ -z "$version" ] && command -v journalctl &>/dev/null; then
        version=$(journalctl -u "$service" --no-pager -n 50 -o cat 2>/dev/null | grep -oE "$ver_regex" | head -1)
    fi
    if [[ ! "$version" =~ $ver_regex ]]; then
        version=""
    fi
    if systemctl is-active --quiet "$service"; then
        echo -e "运行状态：${gl_lv}$service 正在运行${gl_bai}"
    else
        echo -e "运行状态：${gl_hong}$service 未运行${gl_bai}"
    fi
    if [ -n "$version" ]; then
        echo -e "版本信息：${gl_huang}$version${gl_bai}"
    else
        echo -e "版本信息：${gl_huang}无法获取${gl_bai}"
    fi
}

manage_fan_files() {
    eval "$(fan_files_vars)"
    while true; do
        clear
        echo -e ""
        echo -e "${gl_zi}>>> fan-files 管理工具${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        fan_files_show_service_status fan-files
        fan_files_show_service_url fan-files
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}停止 fan-files       ${gl_bufan}2.  ${gl_bai}启动 fan-files"
        echo -e "${gl_bufan}3.  ${gl_bai}重启 fan-files       ${gl_bufan}4.  ${gl_bai}查看服务状态"
        echo -e "${gl_bufan}5.  ${gl_bai}查看开机自启状态     ${gl_bufan}6.  ${gl_bai}开启开机自启"
        echo -e "${gl_bufan}7.  ${gl_bai}禁用开机自启         ${gl_bufan}8.  ${gl_bai}查看日志(100行)"
        echo -e "${gl_bufan}9.  ${gl_bai}实时跟踪日志"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_lv}66. ${gl_bai}安装/升级 fan-files  ${gl_huang}77. ${gl_bai}备份数据"
        echo -e "${gl_lv}88. ${gl_bai}恢复数据             ${gl_hong}99. ${gl_bai}卸载 fan-files"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单       ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" action
        case "$action" in
        1)
            echo -e ""
            echo -e "${gl_zi}>>> 正在停止 fan-files 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl stop ${SERVICE}
            log_ok "fan-files 服务已停止"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        2)
            echo -e ""
            echo -e "${gl_zi}>>> 正在启动 fan-files 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl start ${SERVICE}
            log_ok "fan-files 服务已启动"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        3)
            echo -e ""
            echo -e "${gl_zi}>>> 正在重启 fan-files 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl restart ${SERVICE}
            log_ok "fan-files 服务已重启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        4)
            echo -e ""
            echo -e "${gl_zi}>>> fan-files 服务状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl status ${SERVICE}
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        5)
            echo -e ""
            echo -e "${gl_zi}>>> fan-files 开机自启状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            local status=$(sudo systemctl is-enabled ${SERVICE} 2>/dev/null)
            case "$status" in
                enabled)   echo -e "${gl_lv}已启用${gl_bai}" ;;
                disabled)  echo -e "${gl_hong}已禁用${gl_bai}" ;;
                static)    echo "静态（非服务单元）" ;;
                indirect)  echo "间接（依赖其他单元）" ;;
                *)         echo "$status" ;;
            esac
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        6)
            echo -e ""
            echo -e "${gl_zi}>>> 正在开启 fan-files 开机自启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl enable ${SERVICE}
            log_ok "已开启 fan-files 开机自启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        7)
            echo -e ""
            echo -e "${gl_zi}>>> 正在禁用 fan-files 开机自启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl disable ${SERVICE}
            log_ok "已禁用 fan-files 开机自启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        8)
            echo -e ""
            echo -e "${gl_zi}>>> fan-files 日志（最近100行）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo journalctl -u ${SERVICE} -n 100
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        9)
            echo -e ""
            echo -e "${gl_zi}>>> 实时跟踪 fan-files 日志（按 Ctrl+C 退出）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo journalctl -u ${SERVICE} -f
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        66)
            bash -c "$(curl -sSL ${INSTALL_SCRIPT_URL})"
            break_end
            continue
            ;;
        77)
            bash <(curl -sL ${BACKUP_SCRIPT_URL}) 6
            break_end
            continue
            ;;
        88)
            bash <(curl -sL ${RECOVER_SCRIPT_URL})
            break_end
            continue
            ;;
        99)
            bash <(curl -sSL ${UNINSTALL_SCRIPT_URL})
            break_end
            continue
            ;;
        0)
            proj_mgmt_tool
            ;;
        00 | 000 | 0000)
            exit_script
            ;;
        *)
            handle_invalid_input
            ;;
        esac
    done
}

manage_fan_shop() {

    SERVICE="fan-shop"
    INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-shop/main/scripts/install.sh"
    UNINSTALL_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-shop/main/scripts/uninstall.sh"

    while true; do
        clear
        echo -e ""
        echo -e "${gl_zi}>>> fan-shop 管理工具${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        show_service_status fan-shop
        show_service_url fan-shop
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}停止 fan-shop        ${gl_bufan}2.  ${gl_bai}启动 fan-shop"
        echo -e "${gl_bufan}3.  ${gl_bai}重启 fan-shop        ${gl_bufan}4.  ${gl_bai}查看服务状态"
        echo -e "${gl_bufan}5.  ${gl_bai}查看开机自启状态     ${gl_bufan}6.  ${gl_bai}开启开机自启"
        echo -e "${gl_bufan}7.  ${gl_bai}禁用开机自启         ${gl_bufan}8.  ${gl_bai}查看日志(100行)"
        echo -e "${gl_bufan}9.  ${gl_bai}实时跟踪日志"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_lv}66. ${gl_bai}安装/升级 fan-shop   ${gl_hong}99. ${gl_bai}卸载 fan-shop"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单       ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" action


        case "$action" in
        1)
            echo -e ""
            echo -e "${gl_zi}>>> 正在停止 fan-shop 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl stop ${SERVICE}
            log_ok "fan-shop 服务已停止"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        2)
            echo -e ""
            echo -e "${gl_zi}>>> 正在启动 fan-shop 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl start ${SERVICE}
            log_ok "fan-shop 服务已启动"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        3)
            echo -e ""
            echo -e "${gl_zi}>>> 正在重启 fan-shop 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl restart ${SERVICE}
            log_ok "fan-shop 服务已重启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        4)
            echo -e ""
            echo -e "${gl_zi}>>> fan-shop 服务状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl status ${SERVICE}
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        5)
            echo -e ""
            echo -e "${gl_zi}>>> fan-shop 开机自启状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            local status=$(sudo systemctl is-enabled ${SERVICE} 2>/dev/null)
            case "$status" in
                enabled)   echo -e "${gl_lv}已启用${gl_bai}" ;;
                disabled)  echo -e "${gl_hong}已禁用${gl_bai}" ;;
                static)    echo "静态（非服务单元）" ;;
                indirect)  echo "间接（依赖其他单元）" ;;
                *)         echo "$status" ;;
            esac
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        6)
            echo -e ""
            echo -e "${gl_zi}>>> 正在开启 fan-shop 开机自启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl enable ${SERVICE}
            log_ok "已开启 fan-shop 开机自启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        7)
            echo -e ""
            echo -e "${gl_zi}>>> 正在禁用 fan-shop 开机自启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl disable ${SERVICE}
            log_ok "已禁用 fan-shop 开机自启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        8)
            echo -e ""
            echo -e "${gl_zi}>>> fan-shop 日志（最近100行）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo journalctl -u ${SERVICE} -n 100
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        9)
            echo -e ""
            echo -e "${gl_zi}>>> 实时跟踪 fan-shop 日志（按 Ctrl+C 退出）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo journalctl -u ${SERVICE} -f
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        66)
            bash -c "$(curl -sSL ${INSTALL_SCRIPT_URL})"
            break_end
            continue
            ;;
        99)
            bash <(curl -sSL ${UNINSTALL_SCRIPT_URL})
            break_end
            continue
            ;;
        0)
            proj_mgmt_tool
            ;;
        00 | 000 | 0000)
            exit_script
            ;;
        *)
            handle_invalid_input
            ;;
        esac
    done
}

manage_fan_reubah() {

    SERVICE="fan-reubah"
    INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-reubah/main/scripts/install.sh"
    UNINSTALL_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-reubah/main/scripts/uninstall.sh"

    while true; do
        clear
        echo -e ""
        echo -e "${gl_zi}>>> fan-reubah 管理工具${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        show_service_status fan-reubah
        show_service_url fan-reubah
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}停止 fan-reubah      ${gl_bufan}2.  ${gl_bai}启动 fan-reubah"
        echo -e "${gl_bufan}3.  ${gl_bai}重启 fan-reubah      ${gl_bufan}4.  ${gl_bai}查看服务状态"
        echo -e "${gl_bufan}5.  ${gl_bai}查看开机自启状态     ${gl_bufan}6.  ${gl_bai}开启开机自启"
        echo -e "${gl_bufan}7.  ${gl_bai}禁用开机自启         ${gl_bufan}8.  ${gl_bai}查看日志(100行)"
        echo -e "${gl_bufan}9.  ${gl_bai}实时跟踪日志"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_lv}66. ${gl_bai}安装/升级 fan-reubah ${gl_hong}99. ${gl_bai}卸载 fan-reubah"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单       ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" action

        case "$action" in
        1)
            echo -e ""
            echo -e "${gl_zi}>>> 正在停止 fan-reubah 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl stop ${SERVICE}
            log_ok "fan-reubah 服务已停止"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        2)
            echo -e ""
            echo -e "${gl_zi}>>> 正在启动 fan-reubah 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl start ${SERVICE}
            log_ok "fan-reubah 服务已启动"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        3)
            echo -e ""
            echo -e "${gl_zi}>>> 正在重启 fan-reubah 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl restart ${SERVICE}
            log_ok "fan-reubah 服务已重启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        4)
            echo -e ""
            echo -e "${gl_zi}>>> fan-reubah 服务状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl status ${SERVICE}
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        5)
            echo -e ""
            echo -e "${gl_zi}>>> fan-reubah 开机自启状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            local status=$(sudo systemctl is-enabled ${SERVICE} 2>/dev/null)
            case "$status" in
                enabled)   echo -e "${gl_lv}已启用${gl_bai}" ;;
                disabled)  echo -e "${gl_hong}已禁用${gl_bai}" ;;
                static)    echo "静态（非服务单元）" ;;
                indirect)  echo "间接（依赖其他单元）" ;;
                *)         echo "$status" ;;
            esac
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        6)
            echo -e ""
            echo -e "${gl_zi}>>> 正在开启 fan-reubah 开机自启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl enable ${SERVICE}
            log_ok "已开启 fan-reubah 开机自启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        7)
            echo -e ""
            echo -e "${gl_zi}>>> 正在禁用 fan-reubah 开机自启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl disable ${SERVICE}
            log_ok "已禁用 fan-reubah 开机自启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        8)
            echo -e ""
            echo -e "${gl_zi}>>> fan-reubah 日志（最近100行）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo journalctl -u ${SERVICE} -n 100
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        9)
            echo -e ""
            echo -e "${gl_zi}>>> 实时跟踪 fan-reubah 日志（按 Ctrl+C 退出）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo journalctl -u ${SERVICE} -f
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        66)
            bash -c "$(curl -sSL ${INSTALL_SCRIPT_URL})"
            break_end
            continue
            ;;
        99)
            bash <(curl -sSL ${UNINSTALL_SCRIPT_URL})
            break_end
            continue
            ;;
        0)
            proj_mgmt_tool
            ;;
        00 | 000 | 0000)
            exit_script
            ;;
        *)
            handle_invalid_input
            ;;
        esac
    done
}

manage_fan_random() {

    SERVICE="fan-random"
    INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-random/main/scripts/install.sh"
    UNINSTALL_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-random/main/scripts/uninstall.sh"

    while true; do
        clear
        echo -e ""
        echo -e "${gl_zi}>>> fan-random 管理工具${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        show_service_status fan-random
        show_service_url fan-random
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}停止 fan-random      ${gl_bufan}2.  ${gl_bai}启动 fan-random"
        echo -e "${gl_bufan}3.  ${gl_bai}重启 fan-random      ${gl_bufan}4.  ${gl_bai}查看服务状态"
        echo -e "${gl_bufan}5.  ${gl_bai}查看开机自启状态     ${gl_bufan}6.  ${gl_bai}开启开机自启"
        echo -e "${gl_bufan}7.  ${gl_bai}禁用开机自启         ${gl_bufan}8.  ${gl_bai}查看日志(100行)"
        echo -e "${gl_bufan}9.  ${gl_bai}实时跟踪日志"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_lv}66. ${gl_bai}安装/升级 fan-random ${gl_hong}99. ${gl_bai}卸载 fan-random"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单       ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" action

        case "$action" in
        1)
            echo -e ""
            echo -e "${gl_zi}>>> 正在停止 fan-random 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl stop ${SERVICE}
            log_ok "fan-random 服务已停止"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        2)
            echo -e ""
            echo -e "${gl_zi}>>> 正在启动 fan-random 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl start ${SERVICE}
            log_ok "fan-random 服务已启动"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        3)
            echo -e ""
            echo -e "${gl_zi}>>> 正在重启 fan-random 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl restart ${SERVICE}
            log_ok "fan-random 服务已重启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        4)
            echo -e ""
            echo -e "${gl_zi}>>> fan-random 服务状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl status ${SERVICE}
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        5)
            echo -e ""
            echo -e "${gl_zi}>>> fan-random 开机自启状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            local status=$(sudo systemctl is-enabled ${SERVICE} 2>/dev/null)
            case "$status" in
                enabled)   echo -e "${gl_lv}已启用${gl_bai}" ;;
                disabled)  echo -e "${gl_hong}已禁用${gl_bai}" ;;
                static)    echo "静态（非服务单元）" ;;
                indirect)  echo "间接（依赖其他单元）" ;;
                *)         echo "$status" ;;
            esac
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        6)
            echo -e ""
            echo -e "${gl_zi}>>> 正在开启 fan-random 开机自启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl enable ${SERVICE}
            log_ok "已开启 fan-random 开机自启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        7)
            echo -e ""
            echo -e "${gl_zi}>>> 正在禁用 fan-random 开机自启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl disable ${SERVICE}
            log_ok "已禁用 fan-random 开机自启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        8)
            echo -e ""
            echo -e "${gl_zi}>>> fan-random 日志（最近100行）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo journalctl -u ${SERVICE} -n 100
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        9)
            echo -e ""
            echo -e "${gl_zi}>>> 实时跟踪 fan-random 日志（按 Ctrl+C 退出）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo journalctl -u ${SERVICE} -f
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        66)
            bash -c "$(curl -sSL ${INSTALL_SCRIPT_URL})"
            break_end
            continue
            ;;
        99)
            bash -c "$(curl -sSL ${UNINSTALL_SCRIPT_URL})"
            break_end
            continue
            ;;
        0)
            proj_mgmt_tool
            ;;
        00 | 000 | 0000)
            exit_script
            ;;
        *)
            handle_invalid_input
            ;;
        esac
    done
}

manage_fan_video_dl() {

    SERVICE="fan-video-dl"
    INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-video-dl/main/scripts/install.sh"
    UNINSTALL_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-video-dl/main/scripts/uninstall.sh"
    BACKUP_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-video-dl/main/scripts/fan-video-dl_backup.sh"
    RECOVER_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-video-dl/main/scripts/fan-video-dl_recover.sh"

    while true; do
        clear
        echo -e ""
        echo -e "${gl_zi}>>> fan-video-dl 管理工具${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        show_service_status fan-video-dl
        show_service_url fan-video-dl
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}停止 fan-video-dl      ${gl_bufan}2.  ${gl_bai}启动 fan-video-dl"
        echo -e "${gl_bufan}3.  ${gl_bai}重启 fan-video-dl      ${gl_bufan}4.  ${gl_bai}查看服务状态"
        echo -e "${gl_bufan}5.  ${gl_bai}查看开机自启状态       ${gl_bufan}6.  ${gl_bai}开启开机自启"
        echo -e "${gl_bufan}7.  ${gl_bai}禁用开机自启           ${gl_bufan}8.  ${gl_bai}查看日志(100行)"
        echo -e "${gl_bufan}9.  ${gl_bai}实时跟踪日志"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_lv}66. ${gl_bai}安装/升级 fan-video-dl ${gl_huang}77. ${gl_bai}备份数据"
        echo -e "${gl_lv}88. ${gl_bai}恢复数据               ${gl_hong}99. ${gl_bai}卸载 fan-video-dl"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单         ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" action

        case "$action" in
        1)
            echo -e ""
            echo -e "${gl_zi}>>> 正在停止 fan-video-dl 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl stop ${SERVICE}
            log_ok "fan-video-dl 服务已停止"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        2)
            echo -e ""
            echo -e "${gl_zi}>>> 正在启动 fan-video-dl 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl start ${SERVICE}
            log_ok "fan-video-dl 服务已启动"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        3)
            echo -e ""
            echo -e "${gl_zi}>>> 正在重启 fan-video-dl 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl restart ${SERVICE}
            log_ok "fan-video-dl 服务已重启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        4)
            echo -e ""
            echo -e "${gl_zi}>>> fan-video-dl 服务状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl status ${SERVICE}
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        5)
            echo -e ""
            echo -e "${gl_zi}>>> fan-video-dl 开机自启状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            local status=$(sudo systemctl is-enabled ${SERVICE} 2>/dev/null)
            case "$status" in
                enabled)   echo -e "${gl_lv}已启用${gl_bai}" ;;
                disabled)  echo -e "${gl_hong}已禁用${gl_bai}" ;;
                static)    echo "静态（非服务单元）" ;;
                indirect)  echo "间接（依赖其他单元）" ;;
                *)         echo "$status" ;;
            esac
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        6)
            echo -e ""
            echo -e "${gl_zi}>>> 正在开启 fan-video-dl 开机自启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl enable ${SERVICE}
            log_ok "已开启 fan-video-dl 开机自启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        7)
            echo -e ""
            echo -e "${gl_zi}>>> 正在禁用 fan-video-dl 开机自启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl disable ${SERVICE}
            log_ok "已禁用 fan-video-dl 开机自启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        8)
            echo -e ""
            echo -e "${gl_zi}>>> fan-video-dl 日志（最近100行）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo journalctl -u ${SERVICE} -n 100
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        9)
            echo -e ""
            echo -e "${gl_zi}>>> 实时跟踪 fan-video-dl 日志（按 Ctrl+C 退出）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo journalctl -u ${SERVICE} -f
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        66)
            bash -c "$(curl -sSL ${INSTALL_SCRIPT_URL})"
            break_end
            continue
            ;;
        77)
            bash <(curl -sL ${BACKUP_SCRIPT_URL}) "/var/lib/fan-video-dl/backup" 6
            break_end
            continue
            ;;
        88)
            bash <(curl -sL ${RECOVER_SCRIPT_URL}) "/var/lib/fan-video-dl/backup"
            break_end
            continue
            ;;
        99)
            bash <(curl -sSL ${UNINSTALL_SCRIPT_URL}) -y
            break_end
            continue
            ;;
        0)
            proj_mgmt_tool
            ;;
        00 | 000 | 0000)
            exit_script
            ;;
        *)
            handle_invalid_input
            ;;
        esac
    done
}

manage_fan_video_ct() {

    SERVICE="fan-video-ct"
    INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-video-ct/main/scripts/install.sh"
    UNINSTALL_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-video-ct/main/scripts/uninstall.sh"

    while true; do
        clear
        echo -e ""
        echo -e "${gl_zi}>>> fan-video-ct 管理工具${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        show_service_status fan-video-ct
        show_service_url fan-video-ct
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}停止 fan-video-ct      ${gl_bufan}2.  ${gl_bai}启动 fan-video-ct"
        echo -e "${gl_bufan}3.  ${gl_bai}重启 fan-video-ct      ${gl_bufan}4.  ${gl_bai}查看服务状态"
        echo -e "${gl_bufan}5.  ${gl_bai}查看开机自启状态       ${gl_bufan}6.  ${gl_bai}开启开机自启"
        echo -e "${gl_bufan}7.  ${gl_bai}禁用开机自启           ${gl_bufan}8.  ${gl_bai}查看日志(100行)"
        echo -e "${gl_bufan}9.  ${gl_bai}实时跟踪日志"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_lv}66. ${gl_bai}安装/升级 fan-video-ct ${gl_hong}99. ${gl_bai}卸载 fan-video-ct"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单         ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" action

        case "$action" in
        1)
            echo -e ""
            echo -e "${gl_zi}>>> 正在停止 fan-video-ct 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl stop ${SERVICE}
            log_ok "fan-video-ct 服务已停止"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        2)
            echo -e ""
            echo -e "${gl_zi}>>> 正在启动 fan-video-ct 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl start ${SERVICE}
            log_ok "fan-video-ct 服务已启动"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        3)
            echo -e ""
            echo -e "${gl_zi}>>> 正在重启 fan-video-ct 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl restart ${SERVICE}
            log_ok "fan-video-ct 服务已重启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        4)
            echo -e ""
            echo -e "${gl_zi}>>> fan-video-ct 服务状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl status ${SERVICE}
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        5)
            echo -e ""
            echo -e "${gl_zi}>>> fan-video-ct 开机自启状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            local status=$(sudo systemctl is-enabled ${SERVICE} 2>/dev/null)
            case "$status" in
                enabled)   echo -e "${gl_lv}已启用${gl_bai}" ;;
                disabled)  echo -e "${gl_hong}已禁用${gl_bai}" ;;
                static)    echo "静态（非服务单元）" ;;
                indirect)  echo "间接（依赖其他单元）" ;;
                *)         echo "$status" ;;
            esac
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        6)
            echo -e ""
            echo -e "${gl_zi}>>> 正在开启 fan-video-ct 开机自启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl enable ${SERVICE}
            log_ok "已开启 fan-video-ct 开机自启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        7)
            echo -e ""
            echo -e "${gl_zi}>>> 正在禁用 fan-video-ct 开机自启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl disable ${SERVICE}
            log_ok "已禁用 fan-video-ct 开机自启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        8)
            echo -e ""
            echo -e "${gl_zi}>>> fan-video-ct 日志（最近100行）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo journalctl -u ${SERVICE} -n 100
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        9)
            echo -e ""
            echo -e "${gl_zi}>>> 实时跟踪 fan-video-ct 日志（按 Ctrl+C 退出）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo journalctl -u ${SERVICE} -f
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        66)
            bash -c "$(curl -sSL ${INSTALL_SCRIPT_URL})" -p 8788 -d /var/lib/fan-video-ct
            break_end
            continue
            ;;
        99)
            bash <(curl -sSL ${UNINSTALL_SCRIPT_URL}) -y
            break_end
            continue
            ;;
        0)
            proj_mgmt_tool
            ;;
        00 | 000 | 0000)
            exit_script
            ;;
        *)
            handle_invalid_input
            ;;
        esac
    done
}

manage_fan_webssh() {

    SERVICE="fan-webssh"
    INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-webssh/main/scripts/install.sh"
    UNINSTALL_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-webssh/main/scripts/uninstall.sh"
    BACKUP_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-webssh/main/scripts/fan-webssh_backup.sh"
    RECOVER_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-webssh/main/scripts/fan-webssh_recover.sh"

    while true; do
        clear
        echo -e ""
        echo -e "${gl_zi}>>> fan-webssh 管理工具${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        show_service_status fan-webssh
        show_service_url fan-webssh
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}停止 fan-webssh       ${gl_bufan}2.  ${gl_bai}启动 fan-webssh"
        echo -e "${gl_bufan}3.  ${gl_bai}重启 fan-webssh       ${gl_bufan}4.  ${gl_bai}查看服务状态"
        echo -e "${gl_bufan}5.  ${gl_bai}查看开机自启状态      ${gl_bufan}6.  ${gl_bai}开启开机自启"
        echo -e "${gl_bufan}7.  ${gl_bai}禁用开机自启          ${gl_bufan}8.  ${gl_bai}查看日志(100行)"
        echo -e "${gl_bufan}9.  ${gl_bai}实时跟踪日志"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_lv}66. ${gl_bai}安装/升级 fan-webssh  ${gl_huang}77. ${gl_bai}备份数据"
        echo -e "${gl_lv}88. ${gl_bai}恢复数据              ${gl_hong}99. ${gl_bai}卸载 fan-webssh"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单        ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" action

        case "$action" in
        1)
            echo -e ""
            echo -e "${gl_zi}>>> 正在停止 fan-webssh 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl stop ${SERVICE}
            log_ok "fan-webssh 服务已停止"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        2)
            echo -e ""
            echo -e "${gl_zi}>>> 正在启动 fan-webssh 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl start ${SERVICE}
            log_ok "fan-webssh 服务已启动"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        3)
            echo -e ""
            echo -e "${gl_zi}>>> 正在重启 fan-webssh 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl restart ${SERVICE}
            log_ok "fan-webssh 服务已重启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        4)
            echo -e ""
            echo -e "${gl_zi}>>> fan-webssh 服务状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl status ${SERVICE}
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        5)
            echo -e ""
            echo -e "${gl_zi}>>> fan-webssh 开机自启状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            local status=$(sudo systemctl is-enabled ${SERVICE} 2>/dev/null)
            case "$status" in
                enabled)   echo -e "${gl_lv}已启用${gl_bai}" ;;
                disabled)  echo -e "${gl_hong}已禁用${gl_bai}" ;;
                static)    echo "静态（非服务单元）" ;;
                indirect)  echo "间接（依赖其他单元）" ;;
                *)         echo "$status" ;;
            esac
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        6)
            echo -e ""
            echo -e "${gl_zi}>>> 正在开启 fan-webssh 开机自启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl enable ${SERVICE}
            log_ok "已开启 fan-webssh 开机自启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        7)
            echo -e ""
            echo -e "${gl_zi}>>> 正在禁用 fan-webssh 开机自启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl disable ${SERVICE}
            log_ok "已禁用 fan-webssh 开机自启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        8)
            echo -e ""
            echo -e "${gl_zi}>>> fan-webssh 日志（最近100行）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo journalctl -u ${SERVICE} -n 100
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        9)
            echo -e ""
            echo -e "${gl_zi}>>> 实时跟踪 fan-webssh 日志（按 Ctrl+C 退出）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo journalctl -u ${SERVICE} -f
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        66)
            bash -c "$(curl -sSL ${INSTALL_SCRIPT_URL})"
            break_end
            continue
            ;;
        77)
            bash <(curl -sL ${BACKUP_SCRIPT_URL}) "/var/lib/fan-webssh/backup" 6
            break_end
            continue
            ;;
        88)
            bash <(curl -sL ${RECOVER_SCRIPT_URL}) "/var/lib/fan-webssh/backup"
            break_end
            continue
            ;;
        99)
            bash <(curl -sSL ${UNINSTALL_SCRIPT_URL})
            break_end
            continue
            ;;
        0)
            proj_mgmt_tool
            ;;
        00 | 000 | 0000)
            exit_script
            ;;
        *)
            handle_invalid_input
            ;;
        esac
    done
}

svc_status() {
    local name="$1"
    if [ -f "/etc/systemd/system/${name}.service" ]; then
        if systemctl is-active --quiet "$name" 2>/dev/null; then
            echo active
            return 0
        fi
        echo inactive
        return 1
    fi
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$name"; then
        echo active
        return 0
    fi
    echo inactive
    return 1
}

manage_fan_panel() {
    SERVICE="fan-panel"
    INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-panel/main/scripts/install.sh"
    UNINSTALL_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-panel/main/scripts/uninstall.sh"
    BACKUP_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-panel/main/scripts/backup.sh"
    RECOVER_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-panel/main/scripts/restore.sh"
    while true; do
        clear
        echo -e ""
        echo -e "${gl_zi}>>> fan-panel 管理工具${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        show_service_status fan-panel
        show_service_url fan-panel
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}停止 fan-panel       ${gl_bufan}2.  ${gl_bai}启动 fan-panel"
        echo -e "${gl_bufan}3.  ${gl_bai}重启 fan-panel       ${gl_bufan}4.  ${gl_bai}查看服务状态"
        echo -e "${gl_bufan}5.  ${gl_bai}查看开机自启状态     ${gl_bufan}6.  ${gl_bai}开启开机自启"
        echo -e "${gl_bufan}7.  ${gl_bai}禁用开机自启         ${gl_bufan}8.  ${gl_bai}查看日志(100行)"
        echo -e "${gl_bufan}9.  ${gl_bai}实时跟踪日志"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_lv}66. ${gl_bai}安装/升级 fan-panel  ${gl_huang}77. ${gl_bai}备份数据"
        echo -e "${gl_lv}88. ${gl_bai}恢复数据             ${gl_hong}99. ${gl_bai}卸载 fan-panel"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单       ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" action


        case "$action" in
        1)
            echo -e ""
            echo -e "${gl_zi}>>> 正在停止 fan-panel 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl stop ${SERVICE}
            log_ok "fan-panel 服务已停止"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        2)
            echo -e ""
            echo -e "${gl_zi}>>> 正在启动 fan-panel 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl start ${SERVICE}
            log_ok "fan-panel 服务已启动"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        3)
            echo -e ""
            echo -e "${gl_zi}>>> 正在重启 fan-panel 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl restart ${SERVICE}
            log_ok "fan-panel 服务已重启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        4)
            echo -e ""
            echo -e "${gl_zi}>>> fan-panel 服务状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl status ${SERVICE}
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        5)
            echo -e ""
            echo -e "${gl_zi}>>> fan-panel 开机自启状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            local status=$(sudo systemctl is-enabled ${SERVICE} 2>/dev/null)
            case "$status" in
                enabled)   echo -e "${gl_lv}已启用${gl_bai}" ;;
                disabled)  echo -e "${gl_hong}已禁用${gl_bai}" ;;
                static)    echo "静态（非服务单元）" ;;
                indirect)  echo "间接（依赖其他单元）" ;;
                *)         echo "$status" ;;
            esac
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        6)
            echo -e ""
            echo -e "${gl_zi}>>> 正在开启 fan-panel 开机自启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl enable ${SERVICE}
            log_ok "已开启 fan-panel 开机自启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        7)
            echo -e ""
            echo -e "${gl_zi}>>> 正在禁用 fan-panel 开机自启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl disable ${SERVICE}
            log_ok "已禁用 fan-panel 开机自启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        8)
            echo -e ""
            echo -e "${gl_zi}>>> fan-panel 日志（最近100行）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo journalctl -u ${SERVICE} -n 100
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        9)
            echo -e ""
            echo -e "${gl_zi}>>> 实时跟踪 fan-panel 日志（按 Ctrl+C 退出）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo journalctl -u ${SERVICE} -f
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        66)
            bash -c "$(curl -sSL ${INSTALL_SCRIPT_URL})"
            break_end
            continue
            ;;
        77)
            bash <(curl -sL ${BACKUP_SCRIPT_URL})
            break_end
            continue
            ;;
        88)
            local latest_backup
            latest_backup=$(ls -t ./fan-panel-backup-*.tar.gz 2>/dev/null | head -1)
            if [ -n "${latest_backup}" ]; then
                bash <(curl -sL ${RECOVER_SCRIPT_URL}) "${latest_backup}"
            else
                log_error "当前目录未找到 fan-panel-backup-*.tar.gz 备份文件"
            fi
            break_end
            continue
            ;;
        99)
            bash <(curl -sSL ${UNINSTALL_SCRIPT_URL})
            break_end
            continue
            ;;
        0)
            proj_mgmt_tool
            ;;
        00 | 000 | 0000)
            exit_script
            ;;
        *)
            handle_invalid_input
            ;;
        esac
    done
}

manage_dufs_zh() {
    SERVICE="dufs"
    INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/dufs-zh/main/scripts/install.sh"
    UNINSTALL_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/dufs-zh/main/scripts/uninstall.sh"
    while true; do
        clear
        echo -e ""
        echo -e "${gl_zi}>>> dufs-zh 文件服务器管理工具${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        show_service_status dufs
        show_service_url dufs
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}停止 dufs-zh           ${gl_bufan}2.  ${gl_bai}启动 dufs-zh"
        echo -e "${gl_bufan}3.  ${gl_bai}重启 dufs-zh           ${gl_bufan}4.  ${gl_bai}查看服务状态"
echo -e "${gl_bufan}5.  ${gl_bai}查看开机自启状态       ${gl_bufan}6.  ${gl_bai}开启开机自启"
        echo -e "${gl_bufan}7.  ${gl_bai}禁用开机自启           ${gl_bufan}8.  ${gl_bai}查看日志(100行)"
        echo -e "${gl_bufan}9.  ${gl_bai}实时跟踪日志"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_lv}66. ${gl_bai}安装/升级 dufs-zh"
        echo -e "${gl_hong}99. ${gl_bai}卸载 dufs-zh"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单         ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" action


        case "$action" in
        1)
            echo -e ""
            echo -e "${gl_zi}>>> 正在停止 dufs-zh 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl stop ${SERVICE}
            log_ok "dufs-zh 服务已停止"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        2)
            echo -e ""
            echo -e "${gl_zi}>>> 正在启动 dufs-zh 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl start ${SERVICE}
            log_ok "dufs-zh 服务已启动"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        3)
            echo -e ""
            echo -e "${gl_zi}>>> 正在重启 dufs-zh 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl restart ${SERVICE}
            log_ok "dufs-zh 服务已重启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        4)
            echo -e ""
            echo -e "${gl_zi}>>> dufs-zh 服务状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl status ${SERVICE}
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        5)
            echo -e ""
            echo -e "${gl_zi}>>> dufs-zh 开机自启状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            local status=$(sudo systemctl is-enabled ${SERVICE} 2>/dev/null)
            case "$status" in
                enabled)   echo -e "${gl_lv}已启用${gl_bai}" ;;
                disabled)  echo -e "${gl_hong}已禁用${gl_bai}" ;;
                static)    echo "静态（非服务单元）" ;;
                indirect)  echo "间接（依赖其他单元）" ;;
                *)         echo "$status" ;;
            esac
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        6)
            echo -e ""
            echo -e "${gl_zi}>>> 正在开启 dufs-zh 开机自启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl enable ${SERVICE}
            log_ok "已开启 dufs-zh 开机自启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        7)
            echo -e ""
            echo -e "${gl_zi}>>> 正在禁用 dufs-zh 开机自启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl disable ${SERVICE}
            log_ok "已禁用 dufs-zh 开机自启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        8)
            echo -e ""
            echo -e "${gl_zi}>>> dufs-zh 日志（最近100行）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo journalctl -u ${SERVICE} -n 100
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        9)
            echo -e ""
            echo -e "${gl_zi}>>> 实时跟踪 dufs-zh 日志（按 Ctrl+C 退出）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo journalctl -u ${SERVICE} -f
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        66)
            bash -c "$(curl -sSL ${INSTALL_SCRIPT_URL})"
            break_end
            continue
            ;;
        99)
            bash <(curl -sSL ${UNINSTALL_SCRIPT_URL})
            break_end
            continue
            ;;
        0)
            proj_mgmt_tool
            ;;
        00 | 000 | 0000)
            exit_script
            ;;
        *)
            handle_invalid_input
            ;;
        esac
    done
}

manage_fan_nginx() {

    SERVICE="fan-nginx"
    INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-nginx/main/scripts/install.sh"
    UNINSTALL_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-nginx/main/scripts/uninstall.sh"
    BACKUP_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-nginx/main/scripts/fan-nginx_backup.sh"
    RECOVER_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-nginx/main/scripts/fan-nginx_recover.sh"

    while true; do
        clear
        echo -e ""
        echo -e "${gl_zi}>>> fan-nginx 管理工具${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        show_service_status fan-nginx
        show_service_url fan-nginx
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}停止 fan-nginx       ${gl_bufan}2.  ${gl_bai}启动 fan-nginx"
        echo -e "${gl_bufan}3.  ${gl_bai}重启 fan-nginx       ${gl_bufan}4.  ${gl_bai}查看服务状态"
        echo -e "${gl_bufan}5.  ${gl_bai}查看开机自启状态      ${gl_bufan}6.  ${gl_bai}开启开机自启"
        echo -e "${gl_bufan}7.  ${gl_bai}禁用开机自启          ${gl_bufan}8.  ${gl_bai}查看日志(100行)"
        echo -e "${gl_bufan}9.  ${gl_bai}实时跟踪日志"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_lv}66. ${gl_bai}安装/升级 fan-nginx  ${gl_huang}77. ${gl_bai}备份数据"
        echo -e "${gl_lv}88. ${gl_bai}恢复数据              ${gl_hong}99. ${gl_bai}卸载 fan-nginx"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单        ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" action

        case "$action" in
        1)
            echo -e ""
            echo -e "${gl_zi}>>> 正在停止 fan-nginx 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl stop ${SERVICE}
            log_ok "fan-nginx 服务已停止"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        2)
            echo -e ""
            echo -e "${gl_zi}>>> 正在启动 fan-nginx 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl start ${SERVICE}
            log_ok "fan-nginx 服务已启动"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        3)
            echo -e ""
            echo -e "${gl_zi}>>> 正在重启 fan-nginx 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl restart ${SERVICE}
            log_ok "fan-nginx 服务已重启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        4)
            echo -e ""
            echo -e "${gl_zi}>>> fan-nginx 服务状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl status ${SERVICE}
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        5)
            echo -e ""
            echo -e "${gl_zi}>>> fan-nginx 开机自启状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            local status=$(sudo systemctl is-enabled ${SERVICE} 2>/dev/null)
            case "$status" in
                enabled)   echo -e "${gl_lv}已启用${gl_bai}" ;;
                disabled)  echo -e "${gl_hong}已禁用${gl_bai}" ;;
                static)    echo "静态（非服务单元）" ;;
                indirect)  echo "间接（依赖其他单元）" ;;
                *)         echo "$status" ;;
            esac
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        6)
            echo -e ""
            echo -e "${gl_zi}>>> 正在开启 fan-nginx 开机自启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl enable ${SERVICE}
            log_ok "已开启 fan-nginx 开机自启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        7)
            echo -e ""
            echo -e "${gl_zi}>>> 正在禁用 fan-nginx 开机自启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl disable ${SERVICE}
            log_ok "已禁用 fan-nginx 开机自启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        8)
            echo -e ""
            echo -e "${gl_zi}>>> fan-nginx 日志（最近100行）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo journalctl -u ${SERVICE} -n 100
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        9)
            echo -e ""
            echo -e "${gl_zi}>>> 实时跟踪 fan-nginx 日志（按 Ctrl+C 退出）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo journalctl -u ${SERVICE} -f
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        66)
            bash -c "$(curl -sSL ${INSTALL_SCRIPT_URL})"
            break_end
            continue
            ;;
        77)
            bash <(curl -sL ${BACKUP_SCRIPT_URL}) "/var/lib/fan-nginx/backup" 6
            break_end
            continue
            ;;
        88)
            bash <(curl -sL ${RECOVER_SCRIPT_URL}) "/var/lib/fan-nginx/backup"
            break_end
            continue
            ;;
        99)
            bash <(curl -sSL ${UNINSTALL_SCRIPT_URL})
            break_end
            continue
            ;;
        0)
            proj_mgmt_tool
            ;;
        00 | 000 | 0000)
            exit_script
            ;;
        *)
            handle_invalid_input
            ;;
        esac
    done
}

svc_status() {
    local name="$1"
    if [ -f "/etc/systemd/system/${name}.service" ]; then
        if systemctl is-active --quiet "$name" 2>/dev/null; then
            echo active
            return 0
        fi
        echo inactive
        return 1
    fi
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$name"; then
        echo active
        return 0
    fi
    echo inactive
    return 1
}

manage_fan_panel() {
    SERVICE="fan-panel"
    INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-panel/main/scripts/install.sh"
    UNINSTALL_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-panel/main/scripts/uninstall.sh"
    BACKUP_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-panel/main/scripts/backup.sh"
    RECOVER_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-panel/main/scripts/restore.sh"
    while true; do
        clear
        echo -e ""
        echo -e "${gl_zi}>>> fan-panel 管理工具${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        show_service_status fan-panel
        show_service_url fan-panel
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}停止 fan-panel       ${gl_bufan}2.  ${gl_bai}启动 fan-panel"
        echo -e "${gl_bufan}3.  ${gl_bai}重启 fan-panel       ${gl_bufan}4.  ${gl_bai}查看服务状态"
        echo -e "${gl_bufan}5.  ${gl_bai}查看开机自启状态     ${gl_bufan}6.  ${gl_bai}开启开机自启"
        echo -e "${gl_bufan}7.  ${gl_bai}禁用开机自启         ${gl_bufan}8.  ${gl_bai}查看日志(100行)"
        echo -e "${gl_bufan}9.  ${gl_bai}实时跟踪日志"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_lv}66. ${gl_bai}安装/升级 fan-panel  ${gl_huang}77. ${gl_bai}备份数据"
        echo -e "${gl_lv}88. ${gl_bai}恢复数据             ${gl_hong}99. ${gl_bai}卸载 fan-panel"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单       ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" action


        case "$action" in
        1)
            echo -e ""
            echo -e "${gl_zi}>>> 正在停止 fan-panel 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl stop ${SERVICE}
            log_ok "fan-panel 服务已停止"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        2)
            echo -e ""
            echo -e "${gl_zi}>>> 正在启动 fan-panel 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl start ${SERVICE}
            log_ok "fan-panel 服务已启动"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        3)
            echo -e ""
            echo -e "${gl_zi}>>> 正在重启 fan-panel 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl restart ${SERVICE}
            log_ok "fan-panel 服务已重启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        4)
            echo -e ""
            echo -e "${gl_zi}>>> fan-panel 服务状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl status ${SERVICE}
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        5)
            echo -e ""
            echo -e "${gl_zi}>>> fan-panel 开机自启状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            local status=$(sudo systemctl is-enabled ${SERVICE} 2>/dev/null)
            case "$status" in
                enabled)   echo -e "${gl_lv}已启用${gl_bai}" ;;
                disabled)  echo -e "${gl_hong}已禁用${gl_bai}" ;;
                static)    echo "静态（非服务单元）" ;;
                indirect)  echo "间接（依赖其他单元）" ;;
                *)         echo "$status" ;;
            esac
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        6)
            echo -e ""
            echo -e "${gl_zi}>>> 正在开启 fan-panel 开机自启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl enable ${SERVICE}
            log_ok "已开启 fan-panel 开机自启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        7)
            echo -e ""
            echo -e "${gl_zi}>>> 正在禁用 fan-panel 开机自启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl disable ${SERVICE}
            log_ok "已禁用 fan-panel 开机自启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        8)
            echo -e ""
            echo -e "${gl_zi}>>> fan-panel 日志（最近100行）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo journalctl -u ${SERVICE} -n 100
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        9)
            echo -e ""
            echo -e "${gl_zi}>>> 实时跟踪 fan-panel 日志（按 Ctrl+C 退出）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo journalctl -u ${SERVICE} -f
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        66)
            bash -c "$(curl -sSL ${INSTALL_SCRIPT_URL})"
            break_end
            continue
            ;;
        77)
            bash <(curl -sL ${BACKUP_SCRIPT_URL})
            break_end
            continue
            ;;
        88)
            local latest_backup
            latest_backup=$(ls -t ./fan-panel-backup-*.tar.gz 2>/dev/null | head -1)
            if [ -n "${latest_backup}" ]; then
                bash <(curl -sL ${RECOVER_SCRIPT_URL}) "${latest_backup}"
            else
                log_error "当前目录未找到 fan-panel-backup-*.tar.gz 备份文件"
            fi
            break_end
            continue
            ;;
        99)
            bash <(curl -sSL ${UNINSTALL_SCRIPT_URL})
            break_end
            continue
            ;;
        0)
            proj_mgmt_tool
            ;;
        00 | 000 | 0000)
            exit_script
            ;;
        *)
            handle_invalid_input
            ;;
        esac
    done
}

manage_dufs_zh() {
    SERVICE="dufs"
    INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/dufs-zh/main/scripts/install.sh"
    UNINSTALL_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/dufs-zh/main/scripts/uninstall.sh"
    while true; do
        clear
        echo -e ""
        echo -e "${gl_zi}>>> dufs-zh 文件服务器管理工具${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        show_service_status dufs
        show_service_url dufs
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}停止 dufs-zh           ${gl_bufan}2.  ${gl_bai}启动 dufs-zh"
        echo -e "${gl_bufan}3.  ${gl_bai}重启 dufs-zh           ${gl_bufan}4.  ${gl_bai}查看服务状态"
echo -e "${gl_bufan}5.  ${gl_bai}查看开机自启状态       ${gl_bufan}6.  ${gl_bai}开启开机自启"
        echo -e "${gl_bufan}7.  ${gl_bai}禁用开机自启           ${gl_bufan}8.  ${gl_bai}查看日志(100行)"
        echo -e "${gl_bufan}9.  ${gl_bai}实时跟踪日志"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_lv}66. ${gl_bai}安装/升级 dufs-zh"
        echo -e "${gl_hong}99. ${gl_bai}卸载 dufs-zh"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单         ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" action


        case "$action" in
        1)
            echo -e ""
            echo -e "${gl_zi}>>> 正在停止 dufs-zh 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl stop ${SERVICE}
            log_ok "dufs-zh 服务已停止"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        2)
            echo -e ""
            echo -e "${gl_zi}>>> 正在启动 dufs-zh 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl start ${SERVICE}
            log_ok "dufs-zh 服务已启动"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        3)
            echo -e ""
            echo -e "${gl_zi}>>> 正在重启 dufs-zh 服务 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl restart ${SERVICE}
            log_ok "dufs-zh 服务已重启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        4)
            echo -e ""
            echo -e "${gl_zi}>>> dufs-zh 服务状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl status ${SERVICE}
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        5)
            echo -e ""
            echo -e "${gl_zi}>>> dufs-zh 开机自启状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            local status=$(sudo systemctl is-enabled ${SERVICE} 2>/dev/null)
            case "$status" in
                enabled)   echo -e "${gl_lv}已启用${gl_bai}" ;;
                disabled)  echo -e "${gl_hong}已禁用${gl_bai}" ;;
                static)    echo "静态（非服务单元）" ;;
                indirect)  echo "间接（依赖其他单元）" ;;
                *)         echo "$status" ;;
            esac
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        6)
            echo -e ""
            echo -e "${gl_zi}>>> 正在开启 dufs-zh 开机自启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl enable ${SERVICE}
            log_ok "已开启 dufs-zh 开机自启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        7)
            echo -e ""
            echo -e "${gl_zi}>>> 正在禁用 dufs-zh 开机自启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo systemctl disable ${SERVICE}
            log_ok "已禁用 dufs-zh 开机自启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        8)
            echo -e ""
            echo -e "${gl_zi}>>> dufs-zh 日志（最近100行）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo journalctl -u ${SERVICE} -n 100
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        9)
            echo -e ""
            echo -e "${gl_zi}>>> 实时跟踪 dufs-zh 日志（按 Ctrl+C 退出）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            sudo journalctl -u ${SERVICE} -f
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        66)
            bash -c "$(curl -sSL ${INSTALL_SCRIPT_URL})"
            break_end
            continue
            ;;
        99)
            bash <(curl -sSL ${UNINSTALL_SCRIPT_URL})
            break_end
            continue
            ;;
        0)
            proj_mgmt_tool
            ;;
        00 | 000 | 0000)
            exit_script
            ;;
        *)
            handle_invalid_input
            ;;
        esac
    done
}

manage_fan_md() {
    SERVICE="fan-md"
    INSTALL_SCRIPT_URL="gitee.com/meimolihan/cmdbox/raw/master/sh/dc_inst_fan-md.sh"
    BACKUP_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-md/main/scripts/fan-md_backup.sh"
    RECOVER_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/fan-md/main/scripts/fan-md_recover.sh"
    while true; do
        clear
        echo -e ""
        echo -e "${gl_zi}>>> fan-md 管理工具${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        show_service_status fan-md
        show_service_url fan-md
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}停止 fan-md          ${gl_bufan}2.  ${gl_bai}启动 fan-md"
        echo -e "${gl_bufan}3.  ${gl_bai}重启 fan-md          ${gl_bufan}4.  ${gl_bai}查看容器状态"
        echo -e "${gl_bufan}5.  ${gl_bai}查看端口映射         ${gl_bufan}6.  ${gl_bai}设置开机自启"
        echo -e "${gl_bufan}7.  ${gl_bai}取消开机自启         ${gl_bufan}8.  ${gl_bai}查看日志(100行)"
        echo -e "${gl_bufan}9.  ${gl_bai}实时跟踪日志"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_lv}66. ${gl_bai}部署/升级 fan-md     ${gl_huang}77. ${gl_bai}备份数据"
        echo -e "${gl_lv}88. ${gl_bai}恢复数据             ${gl_hong}99. ${gl_bai}卸载 fan-md"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单       ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" action


        case "$action" in
        1)
            echo -e ""
            echo -e "${gl_zi}>>> 正在停止 fan-md 容器 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker stop ${SERVICE}
            log_ok "fan-md 容器已停止"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        2)
            echo -e ""
            echo -e "${gl_zi}>>> 正在启动 fan-md 容器 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker start ${SERVICE}
            log_ok "fan-md 容器已启动"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        3)
            echo -e ""
            echo -e "${gl_zi}>>> 正在重启 fan-md 容器 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker restart ${SERVICE}
            log_ok "fan-md 容器已重启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        4)
            echo -e ""
            echo -e "${gl_zi}>>> fan-md 容器状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker ps -a --filter "name=^/${SERVICE}$"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        5)
            echo -e ""
            echo -e "${gl_zi}>>> fan-md 端口映射 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker port ${SERVICE}
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        6)
            echo -e ""
            echo -e "${gl_zi}>>> 设置 fan-md 开机自启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker update --restart always ${SERVICE}
            log_ok "已设置 fan-md 开机自启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        7)
            echo -e ""
            echo -e "${gl_zi}>>> 取消 fan-md 开机自启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker update --restart no ${SERVICE}
            log_ok "已取消 fan-md 开机自启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        8)
            echo -e ""
            echo -e "${gl_zi}>>> fan-md 日志（最近100行）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker logs -n 100 ${SERVICE}
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        9)
            echo -e ""
            echo -e "${gl_zi}>>> 实时跟踪 fan-md 日志（按 Ctrl+C 退出）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker logs -f ${SERVICE}
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        66)
            bash <(curl -sL ${INSTALL_SCRIPT_URL})
            break_end
            continue
            ;;
        77)
            bash <(curl -sL ${BACKUP_SCRIPT_URL})
            break_end
            continue
            ;;
        88)
            bash <(curl -sL ${RECOVER_SCRIPT_URL})
            break_end
            continue
            ;;
        99)
            docker rm -f ${SERVICE} && docker rmi -f mobufan/fan-md:latest
            break_end
            continue
            ;;
        0)
            proj_mgmt_tool
            ;;
        00 | 000 | 0000)
            exit_script
            ;;
        *)
            handle_invalid_input
            ;;
        esac
    done
}

manage_cmdbox() {
    SERVICE="cmdbox"
    INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/meimolihan/cmdbox/main/template/sh/cmdbox_docker_build.sh"
    while true; do
        clear
        echo -e ""
        echo -e "${gl_zi}>>> cmdbox 管理工具${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        show_service_status cmdbox
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}停止 cmdbox          ${gl_bufan}2.  ${gl_bai}启动 cmdbox"
        echo -e "${gl_bufan}3.  ${gl_bai}重启 cmdbox          ${gl_bufan}4.  ${gl_bai}查看容器状态"
        echo -e "${gl_bufan}5.  ${gl_bai}查看端口映射         ${gl_bufan}6.  ${gl_bai}设置开机自启"
        echo -e "${gl_bufan}7.  ${gl_bai}取消开机自启         ${gl_bufan}8.  ${gl_bai}查看日志(100行)"
        echo -e "${gl_bufan}9.  ${gl_bai}实时跟踪日志"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_lv}66. ${gl_bai}部署/升级 cmdbox"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单       ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" action


        case "$action" in
        1)
            echo -e ""
            echo -e "${gl_zi}>>> 正在停止 cmdbox 容器 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker stop ${SERVICE}
            log_ok "cmdbox 容器已停止"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        2)
            echo -e ""
            echo -e "${gl_zi}>>> 正在启动 cmdbox 容器 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker start ${SERVICE}
            log_ok "cmdbox 容器已启动"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        3)
            echo -e ""
            echo -e "${gl_zi}>>> 正在重启 cmdbox 容器 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker restart ${SERVICE}
            log_ok "cmdbox 容器已重启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        4)
            echo -e ""
            echo -e "${gl_zi}>>> cmdbox 容器状态 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker ps -a --filter "name=^/${SERVICE}$"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        5)
            echo -e ""
            echo -e "${gl_zi}>>> cmdbox 端口映射 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker port ${SERVICE}
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        6)
            echo -e ""
            echo -e "${gl_zi}>>> 设置 cmdbox 开机自启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker update --restart always ${SERVICE}
            log_ok "已设置 cmdbox 开机自启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        7)
            echo -e ""
            echo -e "${gl_zi}>>> 取消 cmdbox 开机自启 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker update --restart no ${SERVICE}
            log_ok "已取消 cmdbox 开机自启"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        8)
            echo -e ""
            echo -e "${gl_zi}>>> cmdbox 日志（最近100行）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker logs -n 100 ${SERVICE}
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        9)
            echo -e ""
            echo -e "${gl_zi}>>> 实时跟踪 cmdbox 日志（按 Ctrl+C 退出）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            docker logs -f ${SERVICE}
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
        66)
            bash <(curl -sL ${INSTALL_SCRIPT_URL})
            break_end
            continue
            ;;
        0)
            proj_mgmt_tool
            ;;
        00 | 000 | 0000)
            exit_script
            ;;
        *)
            handle_invalid_input
            ;;
        esac
    done
}

git_push_all() {
    local start_dir="${1:-$(pwd)}"
    local commit_msg="${2:-日常更新}"
    local exclude_dirs="${3:-}"
    clear
    echo -e "${gl_zi}>>> 批量Git仓库同步（先pull，后提交推送）${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_info "目标根目录：${gl_lv}$start_dir${gl_bai}"
    cd "$start_dir" || {
        log_error "无法进入根目录：$start_dir"
        exit_animation
        return 1
    }
    log_info "开始扫描目录下所有Git仓库 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    find . -type d -name ".git" ${exclude_dirs:+ $(for e in $exclude_dirs; do echo -n "-not -path */$e/* "; done)} | while read -r git_dir; do
        repo_dir=$(dirname "$git_dir")
        if [[ ! -f "${git_dir}/config" ]]; then
            log_warn "跳过损坏git目录：${repo_dir}"
            continue
        fi
        echo
        echo -e "${gl_huang}正在处理仓库：${gl_lv}$repo_dir${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        (
            log_info "[1] 拉取远程更新 git pull"
            git -C "$repo_dir" pull
            if [[ -n $(git -C "$repo_dir" status --porcelain) ]]; then
                log_info "[2] 检测到本地变更，执行 add/commit"
                git -C "$repo_dir" add .
                git -C "$repo_dir" commit -m "$commit_msg"
                log_info "[3] 推送至远程 git push"
                git -C "$repo_dir" push
                log_ok "✅ 当前仓库提交推送完成"
            else
                log_info "✅ 本地无变更，跳过提交推送"
            fi
        )
        local ret=$?
        if [[ ${ret} -eq 0 ]]; then
            log_ok "仓库处理成功: ${repo_dir}"
        else
            log_error "仓库处理失败: ${repo_dir} 返回码: ${ret}"
        fi
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    done
    break_end
}

proj_mgmt_tool() {
    while true; do
        clear
        echo -e "${gl_zi}>>> 个人项目管理工具${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        # ============ 二进制/Docker 项目运行统计 ============
        local bin_run=0 bin_stop=0
        local svc_name
        for svc_name in fan-panel fan-video fan-md dufs 2panel fan-shop fan-files fan-reubah cmdbox fan-webssh fan-random fan-video-dl fan-video-ct fan-nginx; do
            if svc_status "$svc_name" >/dev/null; then
                bin_run=$((bin_run + 1))
            else
                bin_stop=$((bin_stop + 1))
            fi
        done
        local dck_run=0 dck_stop=0
        local compose_dir
        for compose_dir in fan-panel fan-video fan-md dufs-zh 2panel fan-shop fan-files fan-reubah cmdbox fan-webssh fan-random fan-video-dl fan-video-ct fan-nginx; do
            if is_compose_running "/vol1/1000/compose/$compose_dir"; then
                dck_run=$((dck_run + 1))
            else
                dck_stop=$((dck_stop + 1))
            fi
        done
        echo -e "二进制项目：${gl_lv}已运行 $(printf '%2d' "$bin_run") 个${gl_bai}   ${gl_hong}未运行 $(printf '%2d' "$bin_stop") 个${gl_bai}"
        echo -e "Docker项目：${gl_lv}已运行 $(printf '%2d' "$dck_run") 个${gl_bai}   ${gl_hong}未运行 $(printf '%2d' "$dck_stop") 个${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

        # ============ 公共项目 ============
        # 1. opencode
        if svc_status opencode >/dev/null; then
            col1="${gl_lv}"
        else
            col1="${gl_hong}"
        fi

        # 2. TVmonitor（monitor.service）
        if systemctl is-active --quiet monitor.service 2>/dev/null; then
            col2="${gl_lv}"
        else
            col2="${gl_hong}"
        fi

        # ============ 二进制项目（GitHub 仓库部署系统服务） ============
        # 11. Fan-Panel
        if svc_status fan-panel >/dev/null; then
            col11="${gl_lv}"
        else
            col11="${gl_hong}"
        fi

        # 12. Fan-Video
        if svc_status fan-video >/dev/null; then
            col12="${gl_lv}"
        else
            col12="${gl_hong}"
        fi

        # 13. Fan-MD
        if svc_status fan-md >/dev/null; then
            col13="${gl_lv}"
        else
            col13="${gl_hong}"
        fi

        # 14. Dufs-zh
        if svc_status dufs >/dev/null; then
            col14="${gl_lv}"
        else
            col14="${gl_hong}"
        fi

        # 15. 2Panel
        if svc_status 2panel >/dev/null; then
            col15="${gl_lv}"
        else
            col15="${gl_hong}"
        fi

        # 16. Fan-Shop
        if svc_status fan-shop >/dev/null; then
            col16="${gl_lv}"
        else
            col16="${gl_hong}"
        fi

        # 17. Fan-Files
        if svc_status fan-files >/dev/null; then
            col17="${gl_lv}"
        else
            col17="${gl_hong}"
        fi

        # 18. Fan-Reubah
        if svc_status fan-reubah >/dev/null; then
            col18="${gl_lv}"
        else
            col18="${gl_hong}"
        fi

        # 19. CmdBox
        if svc_status cmdbox >/dev/null; then
            col19="${gl_lv}"
        else
            col19="${gl_hong}"
        fi

        # 20. Fan-WebSSH
        if svc_status fan-webssh >/dev/null; then
            col20="${gl_lv}"
        else
            col20="${gl_hong}"
        fi

        # 21. Fan-Random
        if svc_status fan-random >/dev/null; then
            col21="${gl_lv}"
        else
            col21="${gl_hong}"
        fi

        # 22. Fan-Video-DL
        if svc_status fan-video-dl >/dev/null; then
            col22="${gl_lv}"
        else
            col22="${gl_hong}"
        fi

        # 23. Fan-Video-CT
        if svc_status fan-video-ct >/dev/null; then
            col23="${gl_lv}"
            col24="${gl_lv}"
        else
            col23="${gl_hong}"
            col24="${gl_hong}"
        fi

        # ============ Dccker 项目（/vol1/1000/compose 目录） ============
        # 31. Fan-Panel
        if is_compose_running "/vol1/1000/compose/fan-panel"; then
            col31="${gl_lv}"
        else
            col31="${gl_hong}"
        fi

        # 32. Fan-Video
        if is_compose_running "/vol1/1000/compose/fan-video"; then
            col32="${gl_lv}"
        else
            col32="${gl_hong}"
        fi

        # 33. Fan-MD
        if is_compose_running "/vol1/1000/compose/fan-md"; then
            col33="${gl_lv}"
        else
            col33="${gl_hong}"
        fi

        # 34. Dufs-zh
        if is_compose_running "/vol1/1000/compose/dufs-zh"; then
            col34="${gl_lv}"
        else
            col34="${gl_hong}"
        fi

        # 35. 2Panel
        if is_compose_running "/vol1/1000/compose/2panel"; then
            col35="${gl_lv}"
        else
            col35="${gl_hong}"
        fi

        # 36. Fan-Shop
        if is_compose_running "/vol1/1000/compose/fan-shop"; then
            col36="${gl_lv}"
        else
            col36="${gl_hong}"
        fi

        # 37. Fan-Files
        if is_compose_running "/vol1/1000/compose/fan-files"; then
            col37="${gl_lv}"
        else
            col37="${gl_hong}"
        fi

        # 38. Fan-Reubah
        if is_compose_running "/vol1/1000/compose/fan-reubah"; then
            col38="${gl_lv}"
        else
            col38="${gl_hong}"
        fi

        # 39. CmdBox
        if is_compose_running "/vol1/1000/compose/cmdbox"; then
            col39="${gl_lv}"
        else
            col39="${gl_hong}"
        fi

        # 40. Fan-WebSSH
        if is_compose_running "/vol1/1000/compose/fan-webssh"; then
            col40="${gl_lv}"
        else
            col40="${gl_hong}"
        fi

        # 41. Fan-Random
        if is_compose_running "/vol1/1000/compose/fan-random"; then
            col41="${gl_lv}"
        else
            col41="${gl_hong}"
        fi

        # 42. Fan-Video-DL
        if is_compose_running "/vol1/1000/compose/fan-video-dl"; then
            col42="${gl_lv}"
        else
            col42="${gl_hong}"
        fi

        # 43. Fan-Video-CT
        if is_compose_running "/vol1/1000/compose/fan-video-ct"; then
            col43="${gl_lv}"
            col44="${gl_lv}"
        else
            col43="${gl_hong}"
            col44="${gl_hong}"
        fi

        echo -e "${gl_lan}公共项目${gl_bai}"
        echo -e "${col1}1.${gl_bai}  OpenCode 智能代理    ${col2}2.${gl_bai}  TVmonitor 软件自启"
        echo -e ""
        echo -e "${gl_huang}二进制项目${gl_bai}"
        echo -e "${col11}11.${gl_bai} FanPanel 导航页      ${col12}12.${gl_bai} FanVideo 影视库"
        echo -e "${col13}13.${gl_bai} FanMD 云文档         ${col14}14.${gl_bai} Dufs-zh 文件服务"
        echo -e "${col15}15.${gl_bai} 2Panel 定时任务      ${col16}16.${gl_bai} FanShop 容器管理"
        echo -e "${col17}17.${gl_bai} FanFiles 文件管理    ${col18}18.${gl_bai} FanReubah 格式转换"
        echo -e "${col19}19.${gl_bai} CmdBox 命令          ${col20}20.${gl_bai} FanWebSSH 终端面板"
        echo -e "${col21}21.${gl_bai} FanRandom 随机壁纸   ${col22}22.${gl_bai} FanVideoDL 视频下载"
        echo -e "${col23}23.${gl_bai} FanVideoCT 视频剪切  ${col24}24.${gl_bai} FanNginx 反向代理"
        echo -e ""
        echo -e "${gl_huang}Dccker 项目${gl_bai}"
        echo -e "${col31}31.${gl_bai} FanPanel 导航页      ${col32}32.${gl_bai} FanVideo 影视库"
        echo -e "${col33}33.${gl_bai} FanMD 云文档         ${col34}34.${gl_bai} Dufs-zh 文件服务"
        echo -e "${col35}35.${gl_bai} 2Panel 定时任务      ${col36}36.${gl_bai} FanShop 容器管理"
        echo -e "${col37}37.${gl_bai} FanFiles 文件管理    ${col38}38.${gl_bai} FanReubah 格式转换"
        echo -e "${col39}39.${gl_bai} CmdBox 命令          ${col40}40.${gl_bai} FanWebSSH 终端面板"
        echo -e "${col41}41.${gl_bai} FanRandom 随机壁纸   ${col42}42.${gl_bai} FanVideoDL 视频下载"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_lv}66.${gl_bai} 构建并推送           ${gl_lv}77.${gl_bai} 推送所有更新"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单       ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" action

        case "$action" in
        1)
            manage_opencode
            ;;
        2)
            monitor_tool
            ;;
        11)
            manage_fan_panel
            ;;
        12)
            manage_fan_video
            ;;
        13)
            manage_fan_md
            ;;
        14)
            manage_dufs_zh
            ;;
        15)
            manage_2panel
            ;;
        16)
            manage_fan_shop
            ;;
        17)
            manage_fan_files
            ;;
        18)
            manage_fan_reubah
            ;;
        19)
            manage_cmdbox
            ;;
        20)
            manage_fan_webssh
            ;;
        21)
            manage_fan_random
            ;;
        22)
            manage_fan_video_dl
            ;;
        23)
            manage_fan_video_ct
            ;;
        24)
            manage_fan_nginx
            ;;
        31)
            docker_compose_manager /vol1/1000/compose/fan-panel
            ;;
        32)
            docker_compose_manager /vol1/1000/compose/fan-video
            ;;
        33)
            docker_compose_manager /vol1/1000/compose/fan-md
            ;;
        34)
            docker_compose_manager /vol1/1000/compose/dufs-zh
            ;;
        35)
            docker_compose_manager /vol1/1000/compose/2panel
            ;;
        36)
            docker_compose_manager /vol1/1000/compose/fan-shop
            ;;
        37)
            docker_compose_manager /vol1/1000/compose/fan-files
            ;;
        38)
            docker_compose_manager /vol1/1000/compose/fan-reubah
            ;;
        39)
            docker_compose_manager /vol1/1000/compose/cmdbox
            ;;
        40)
            docker_compose_manager /vol1/1000/compose/fan-webssh
            ;;
        41)
            docker_compose_manager /vol1/1000/compose/fan-random
            ;;
        42)
            docker_compose_manager /vol1/1000/compose/fan-video-dl
            ;;
        43)
            docker_compose_manager /vol1/1000/compose/fan-video-ct
            ;;
        44)
            docker_compose_manager /vol1/1000/compose/fan-nginx
            ;;
        66)
            git_project_menu
            ;;
        77)
            git_push_all "/vol1/1000/GitHub" "日常更新" ""
            ;;
        0)
            cancel_return "已是主菜单"
            continue
            ;;
        00 | 000 | 0000)
            exit_script
            ;;
        *)
            handle_invalid_input
            ;;
        esac
    done
}

proj_mgmt_tool

