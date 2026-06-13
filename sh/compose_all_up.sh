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

start_all_compose_projects() {
    local COMPOSE_WORK_DIR="$1"
    local SKIP_CONFIRM="${2:-false}"
    
    clear
    echo -e ""
    echo -e "${gl_zi}>>> 启动所有 Compose 项目 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if ! docker info &>/dev/null; then
        log_error "Docker 服务未运行"
        exit_animation
        return 1
    fi

    if [[ ! -d "$COMPOSE_WORK_DIR" ]]; then
        log_error "目录不存在: $COMPOSE_WORK_DIR"
        exit_animation
        return 1
    fi

    echo -e "${gl_bai}工作目录: ${gl_huang}$COMPOSE_WORK_DIR${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if [[ "$SKIP_CONFIRM" != "true" ]]; then
        read -r -e -p "$(echo -e "${gl_hong}警告: ${gl_bai}确定启动 ${gl_huang}$COMPOSE_WORK_DIR${gl_bai} 下的所有 Compose 项目吗？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm

        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo -e "${gl_huang}已取消${gl_bai}"
            exit_animation
            return
        fi
    fi

    if ! cd "$COMPOSE_WORK_DIR" 2>/dev/null; then
        log_error "无法进入目录: $COMPOSE_WORK_DIR"
        exit_animation
        return
    fi

    local started_count=0
    local total_count=0

    echo -e "${gl_bai}正在扫描 ${gl_huang}$COMPOSE_WORK_DIR${gl_bai} 下的 Compose 项目 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if [[ -f "docker-compose.yml" ]] || [[ -f "docker-compose.yaml" ]]; then
        local current_dir_name=$(basename "$(pwd)")
        echo -e ""
        echo -e "${gl_huang}>>> 启动项目: ${gl_lv}$current_dir_name${gl_bai} (当前目录)"

        if command -v docker-compose &>/dev/null; then
            docker-compose up -d
        elif docker compose version &>/dev/null; then
            docker compose up -d
        else
            log_error "未找到 docker-compose 命令"
            return
        fi

        if [[ $? -eq 0 ]]; then
            echo -e "${gl_lv}✓ 已启动: $current_dir_name${gl_bai}"
            started_count=$((started_count + 1))
        else
            echo -e "${gl_hong}✗ 启动失败: $current_dir_name${gl_bai}"
        fi
        total_count=$((total_count + 1))
    fi

    for dir in */; do
        if [[ -d "$dir" ]]; then
            cd "$dir" 2>/dev/null || continue

            if [[ -f "docker-compose.yml" ]] || [[ -f "docker-compose.yaml" ]]; then
                local project_name=$(basename "$dir")
                echo -e ""
                echo -e "${gl_huang}>>> 启动项目: ${gl_lv}$project_name${gl_bai}"

                if command -v docker-compose &>/dev/null; then
                    docker-compose up -d
                elif docker compose version &>/dev/null; then
                    docker compose up -d
                else
                    log_error "未找到 docker-compose 命令"
                    cd ..
                    continue
                fi

                if [[ $? -eq 0 ]]; then
                    echo -e "${gl_lv}✓ 已启动: $project_name${gl_bai}"
                    started_count=$((started_count + 1))
                else
                    echo -e "${gl_hong}✗ 启动失败: $project_name${gl_bai}"
                fi
                total_count=$((total_count + 1))
            fi

            cd .. 2>/dev/null
        fi
    done

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if [[ $total_count -eq 0 ]]; then
        echo -e "${gl_huang}在 ${gl_hong}$COMPOSE_WORK_DIR${gl_huang} 中没有找到 Compose 项目${gl_bai}"
    else
        echo -e "${gl_bai}启动完成${gl_bai}"
        echo -e "${gl_bai}总计项目: ${gl_huang}$total_count${gl_bai}"
        echo -e "${gl_bai}成功启动: ${gl_lv}$started_count${gl_bai}"
        if [[ $started_count -lt $total_count ]]; then
            echo -e "${gl_hong}启动失败: $((total_count - started_count))${gl_bai}"
        fi
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    if [[ "$SKIP_CONFIRM" == "true" ]]; then
        return
    fi
    
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n 1 -s -r -p ""
    echo ""
    clear
}

interactive_start() {
    clear
    echo -e ""
    echo -e "${gl_zi}>>> 启动所有 Compose 项目 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if ! docker info &>/dev/null; then
        log_error "Docker 服务未运行"
        exit_animation
        return 1
    fi

    local preset_dirs=(
        "/compose"
        "/mnt/compose"
        "/vol1/1000/compose"
        "/vol2/1000/compose"
    )

    log_info "正在扫描所有 docker-compose 项目 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

    local all_projects=()
    for preset_dir in "${preset_dirs[@]}"; do
        if [[ -d "$preset_dir" ]]; then
            if [[ -f "$preset_dir/docker-compose.yml" ]] || [[ -f "$preset_dir/docker-compose.yaml" ]]; then
                all_projects+=("$preset_dir")
            fi

            for dir in "$preset_dir"/*/; do
                if [[ -d "$dir" ]] && ([[ -f "$dir/docker-compose.yml" ]] || [[ -f "$dir/docker-compose.yaml" ]]); then
                    all_projects+=("$(realpath "$dir")")
                fi
            done
        fi
    done

    all_projects=($(printf "%s\n" "${all_projects[@]}" | sort -u))

    local running_projects=()
    if command -v docker &>/dev/null && docker info &>/dev/null; then
        while IFS= read -r dir; do
            [[ -z "$dir" ]] && continue
            [[ ! -d "$dir" ]] && continue
            running_projects+=("$(realpath "$dir")")
        done < <(
            docker ps --format '{{.Names}}' 2>/dev/null |
                xargs -I{} sh -c 'docker inspect {} 2>/dev/null | jq -r ".[0].Config.Labels[\"com.docker.compose.project.working_dir\"]" 2>/dev/null || echo ""' |
                sort -u
        )
    fi

    local recommended_dirs=()
    for preset_dir in "${preset_dirs[@]}"; do
        local has_projects=false
        for project in "${all_projects[@]}"; do
            if [[ "$project" == "$preset_dir" ]] || [[ "$project" == "$preset_dir"* ]]; then
                has_projects=true
                break
            fi
        done

        if $has_projects; then
            local all_running=true
            for project in "${all_projects[@]}"; do
                if [[ "$project" == "$preset_dir" ]] || [[ "$project" == "$preset_dir"* ]]; then
                    local is_running=false
                    for running_dir in "${running_projects[@]}"; do
                        if [[ "$running_dir" == "$project" ]]; then
                            is_running=true
                            break
                        fi
                    done

                    if ! $is_running; then
                        all_running=false
                        break
                    fi
                fi
            done

            if ! $all_running; then
                recommended_dirs+=("$preset_dir")
            fi
        fi
    done

    if [[ ${#all_projects[@]} -gt 0 ]]; then
        echo -e "${gl_bai}扫描到的 docker-compose 项目目录:${gl_bai}"
        for dir in "${all_projects[@]}"; do
            local is_running=""
            for running_dir in "${running_projects[@]}"; do
                if [[ "$running_dir" == "$dir" ]]; then
                    is_running=" ${gl_lv}[运行中]${gl_bai}"
                    break
                fi
            done
            [[ -z "$is_running" ]] && is_running=" ${gl_huang}[已停止]${gl_bai}"

            echo -e "  ${gl_lv}•${gl_bai} ${dir}$is_running"
        done

        if [[ ${#recommended_dirs[@]} -gt 0 ]]; then
            echo -e "${gl_bai}推荐的工作目录（有未运行的项目）:${gl_bai}"
            for dir in "${recommended_dirs[@]}"; do
                echo -e "  ${gl_hong}★${gl_bai} ${dir}"
            done
        fi
    else
        echo -e "${gl_huang}未找到任何 docker-compose 项目${gl_bai}"
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    echo -e ""
    echo -e "${gl_huang}>>> 请选择要启动的工作目录:${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    for i in "${!preset_dirs[@]}"; do
        local marker=""
        local dir_status=""

        for rd in "${recommended_dirs[@]}"; do
            if [[ "${preset_dirs[i]}" == "$rd" ]]; then
                marker=" ${gl_hong}(推荐)${gl_bai}"
                break
            fi
        done

        if [[ -d "${preset_dirs[i]}" ]]; then
            local compose_count=$(find "${preset_dirs[i]}" -maxdepth 2 -type f \( -name "docker-compose.yml" -o -name "docker-compose.yaml" \) 2>/dev/null | wc -l)
            if [[ $compose_count -gt 0 ]]; then
                local running_count=0
                for project in "${running_projects[@]}"; do
                    if [[ "$project" == "${preset_dirs[i]}" ]] || [[ "$project" == "${preset_dirs[i]}"/* ]]; then
                        running_count=$((running_count + 1))
                    fi
                done

                if [[ $running_count -eq 0 ]]; then
                    dir_status="${gl_huang}[${compose_count}个项目，均未运行]${gl_bai}"
                elif [[ $running_count -eq $compose_count ]]; then
                    dir_status="${gl_lv}[${compose_count}个项目，全部运行中]${gl_bai}"
                else
                    dir_status="${gl_huang}[${compose_count}个项目，${running_count}个运行中]${gl_bai}"
                fi
            else
                dir_status="${gl_huang}[无 compose 项目]${gl_bai}"
            fi
        else
            dir_status="${gl_huang}[目录不存在]${gl_bai}"
        fi

        echo -e "${gl_bufan}$((i + 1)).${gl_bai} ${preset_dirs[i]} $dir_status$marker"
    done
    echo -e "${gl_bufan}$((${#preset_dirs[@]} + 1)).${gl_bai} 手动指定路径"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_huang}0.${gl_bai} 返回上一级选单"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    read -r -e -p "$(echo -e "${gl_bai}请输入你的选择 (${gl_huang}0${gl_bai}-${gl_hong}$((${#preset_dirs[@]} + 1))${gl_bai}): ")" dir_choice

    local COMPOSE_WORK_DIR=""

    if [[ -z "$dir_choice" ]] && [[ ${#recommended_dirs[@]} -gt 0 ]]; then
        COMPOSE_WORK_DIR="${recommended_dirs[0]}"
        echo -e "${gl_bai}使用推荐目录: ${gl_huang}$COMPOSE_WORK_DIR${gl_bai}"
    elif [[ "$dir_choice" =~ ^[0-9]+$ ]]; then
        if [[ $dir_choice -eq 0 ]]; then
            cancel_return "Compose 项目管理"
            return
        elif [[ $dir_choice -le ${#preset_dirs[@]} ]]; then
            COMPOSE_WORK_DIR="${preset_dirs[$((dir_choice - 1))]}"
        elif [[ $dir_choice -eq $((${#preset_dirs[@]} + 1)) ]]; then
            read -r -e -p "$(echo -e "${gl_bai}请输入自定义路径: ")" COMPOSE_WORK_DIR
        else
            log_error "无效选择"
            exit_animation
            return
        fi
    else
        COMPOSE_WORK_DIR="$dir_choice"
    fi

    if [[ -z "$COMPOSE_WORK_DIR" ]]; then
        log_warn "路径不能为空"
        exit_animation
        return
    fi

    if [[ ! -d "$COMPOSE_WORK_DIR" ]]; then
        log_warn "目录不存在: $COMPOSE_WORK_DIR"
        exit_animation
        return
    fi

    start_all_compose_projects "$COMPOSE_WORK_DIR" "false"
}

show_help() {
    echo -e "${gl_lv}使用说明:${gl_bai}"
    echo -e "  ${gl_bai}$0 ${gl_huang}[选项] ${gl_lan}[目录]${gl_bai}"
    echo -e ""
    echo -e "${gl_lv}选项:${gl_bai}"
    echo -e "  ${gl_huang}-y, --yes${gl_bai}      自动确认，跳过提示"
    echo -e "  ${gl_huang}-h, --help${gl_bai}    显示此帮助信息"
    echo -e ""
    echo -e "${gl_lv}示例:${gl_bai}"
    echo -e "  ${gl_bai}$0 ${gl_lan}/compose${gl_bai}         # 交互式确认后启动指定目录"
    echo -e "  ${gl_bai}$0 ${gl_lan}-y /compose${gl_bai}     # 自动确认启动指定目录"
    echo -e "  ${gl_bai}$0${gl_bai}                     # 交互式选择目录"
    echo -e ""
    exit 0
}

main() {
    local TARGET_DIR=""
    local SKIP_CONFIRM="false"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -y|--yes)
                SKIP_CONFIRM="true"
                shift
                ;;
            -h|--help)
                show_help
                ;;
            *)
                if [[ -z "$TARGET_DIR" ]]; then
                    TARGET_DIR="$1"
                else
                    log_error "未知参数: $1"
                    echo -e "${gl_bai}使用 ${gl_huang}$0 -h ${gl_bai}查看帮助${gl_bai}"
                    exit 1
                fi
                shift
                ;;
        esac
    done

    if [[ -n "$TARGET_DIR" ]]; then
        start_all_compose_projects "$TARGET_DIR" "$SKIP_CONFIRM"
    else
        interactive_start
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
