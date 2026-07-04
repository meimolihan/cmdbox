#!/bin/bash

set -u
set -o pipefail

gl_hui='\033[37m'
gl_hong='\033[31m'
gl_lv='\033[32m'
gl_huang='\033[33m'
gl_lan='\033[34m'
gl_bai='\033[97m'
gl_zi='\033[35m'
gl_bufan='\033[96m'
gl_info='\033[94m'
gl_reset='\033[0m'

TARGET_DIR=""
EXCLUDE_DIRS=()

is_directory() {
    [[ -d "$1" ]] && return 0 || return 1
}

show_help() {
    cat << HELPTEXT
用法: $0 [目标目录] ["排除目录1 排除目录2 ..."]  或  $0 ["排除目录1 排除目录2 ..."] [目标目录]

说明:
  - 两个参数时，自动识别哪个是目录（必须存在），另一个作为空格分隔的排除目录列表
  - 一个参数时，作为目标目录
  - 排除目录相对路径，基于目标目录

示例:
  $0 /vol1/1000/compose "test1 test2 test3"     # 目标目录在前
  $0 "test1 test2 test3" /vol1/1000/compose     # 排除列表在前
  $0 /vol1/1000/compose                         # 仅目标目录
HELPTEXT
}

parse_args() {
    local args=("$@")
    
    if [[ ${#args[@]} -eq 0 ]]; then
        TARGET_DIR="."
        return
    fi
    
    if [[ ${#args[@]} -eq 1 ]]; then
        # 单个参数：作为目标目录
        TARGET_DIR="${args[0]}"
        return
    fi
    
    if [[ ${#args[@]} -eq 2 ]]; then
        if is_directory "${args[0]}"; then
            TARGET_DIR="${args[0]}"
            read -ra EXCLUDE_DIRS <<< "${args[1]}"
        elif is_directory "${args[1]}"; then
            TARGET_DIR="${args[1]}"
            read -ra EXCLUDE_DIRS <<< "${args[0]}"
        else
            echo -e "${gl_hong}❌ 错误: 无法识别目标目录，请确保其中一个参数是存在的目录路径${gl_reset}"
            exit 1
        fi
        return
    fi
    
    echo -e "${gl_huang}⚠️ 参数过多，将使用位置参数解析 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    TARGET_DIR="${args[0]}"
    local combined_excludes="${args[1]}"
    shift 2
    for extra in "$@"; do
        combined_excludes="$combined_excludes $extra"
    done
    read -ra EXCLUDE_DIRS <<< "$combined_excludes"
}

parse_args "$@"

if [[ -d "$TARGET_DIR" ]]; then
    TARGET_DIR=$(realpath "$TARGET_DIR")
else
    echo -e "${gl_hong}❌ 错误: 目标目录不存在: $TARGET_DIR${gl_reset}"
    exit 1
fi

if ! command -v docker &>/dev/null; then
    echo -e "${gl_hong}❌ 未找到 docker 命令，请确保 Docker 已安装。${gl_reset}"
    exit 1
fi
COMPOSE_CMD=$(command -v docker-compose || echo "docker compose")
if ! $COMPOSE_CMD version &>/dev/null; then
    echo -e "${gl_hong}❌ 未找到可用的 docker compose 命令。${gl_reset}"
    exit 1
fi

COUNT=0
SUCCESS=0
FAIL=0
UPDATED_PROJECTS=()
NO_UPDATE_PROJECTS=()

is_excluded() {
    local dir="$1"
    local dir_name=$(basename "$dir")
    for pattern in "${EXCLUDE_DIRS[@]}"; do
        if [[ "$dir_name" == "$pattern" || "$dir" == *"/$pattern" ]]; then
            return 0
        fi
    done
    return 1
}

display_container_status() {
    local container_count running_count
    container_count=$($COMPOSE_CMD ps -q 2>/dev/null | wc -l)
    running_count=$($COMPOSE_CMD ps --filter status=running -q 2>/dev/null | wc -l)
    if [[ $container_count -gt 0 ]]; then
        echo -e "${gl_bai}容器状态: ${gl_lv}✓${gl_bai} 发现 ${gl_bufan}$container_count ${gl_bai}个容器，其中 ${gl_bufan}$running_count ${gl_bai}个在运行"
    else
        echo -e "${gl_bai}容器状态: ${gl_huang}⚠️ 未发现运行中的容器${gl_bai}"
    fi
}

check_for_updates() {
    local pull_exit_code="$1" up_exit_code="$2" pull_output="$3" up_output="$4" project_name="$5"
    local has_update=false update_type=""
    if [[ $pull_exit_code -eq 0 ]] && echo "$pull_output" | grep -q -E "Downloaded newer image|Status: Downloaded newer image"; then
        has_update=true; update_type="镜像更新"
    fi
    if [[ $up_exit_code -eq 0 ]] && echo "$up_output" | grep -q -E "Recreating|Creating|Starting|Started"; then
        if [[ -n "$update_type" ]]; then update_type="镜像+容器更新"; else has_update=true; update_type="容器更新"; fi
    fi
    if [[ "$has_update" == "true" ]]; then
        UPDATED_PROJECTS+=("$project_name")
        echo -e "${gl_lv}✅ 更新成功 ${gl_huang}(${update_type})${gl_bai}"
    else
        NO_UPDATE_PROJECTS+=("$project_name")
        echo -e "${gl_lv}✅ 更新完成 (无变化)${gl_bai}"
    fi
}

get_project_name() {
    local dir="${1:-}"
    if [[ -z "$dir" ]]; then
        echo "unknown"
        return
    fi
    local dir_name
    dir_name=$(basename "$dir")
    local project_name="$dir_name"
    local compose_file=""

    for f in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
        if [[ -f "$dir/$f" ]]; then
            compose_file="$dir/$f"
            break
        fi
    done

    if [[ -n "$compose_file" ]] && grep -q "^name:" "$compose_file" 2>/dev/null; then
        local extracted_name
        extracted_name=$(grep "^name:" "$compose_file" | head -1 | sed 's/^name:[[:space:]]*//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '\r' | tr -d "'\"")
        [[ -n "$extracted_name" ]] && project_name="$extracted_name"
    fi

    if [[ -f "$dir/.env" ]] && grep -q "COMPOSE_PROJECT_NAME" "$dir/.env" 2>/dev/null; then
        local env_name
        env_name=$(grep "COMPOSE_PROJECT_NAME" "$dir/.env" | head -1 | cut -d'=' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '\r' | tr -d "'\"")
        [[ -n "$env_name" ]] && project_name="$env_name"
    fi

    echo "$project_name"
}

echo ""
start_time=$(date '+%F %T'); start_ts=$(date +%s)
echo -e "${gl_bai}开始更新时间：${gl_lv}$start_time${gl_bai}"
echo -e "${gl_bai}目标目录：${gl_huang}$TARGET_DIR${gl_bai}"
if [[ ${#EXCLUDE_DIRS[@]} -gt 0 ]]; then
    echo -e "${gl_bai}排除目录：${gl_huang}${EXCLUDE_DIRS[*]}${gl_bai}"
fi
echo -e "${gl_bai}开始更新直接子目录中的 Docker Compose 项目 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_reset}"
echo -e "${gl_bufan}————————————————————————————————————————————————${gl_reset}"

compose_dirs=()
for subdir in "$TARGET_DIR"/*/; do
    [[ -d "$subdir" ]] || continue
    for f in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
        if [[ -f "$subdir/$f" ]]; then
            compose_dirs+=("$subdir")
            break
        fi
    done
done

if [[ ${#compose_dirs[@]} -eq 0 ]]; then
    echo -e "${gl_huang}⚠️ 在 $TARGET_DIR 的直接子目录下未找到任何 Docker Compose 项目。${gl_reset}"
    exit 0
fi

filtered_dirs=()
for dir in "${compose_dirs[@]}"; do
    if is_excluded "$dir"; then
        echo -e "${gl_hui}⏭️ 跳过已排除目录: $(basename "$dir")${gl_reset}"
    else
        filtered_dirs+=("$dir")
    fi
done

total_projects=${#filtered_dirs[@]}
if [[ $total_projects -eq 0 ]]; then
    echo -e "${gl_huang}⚠️ 所有找到的目录均被排除，无项目可更新。${gl_reset}"
    exit 0
fi

echo -e "${gl_bai}待更新项目数: ${gl_bufan}$total_projects${gl_reset}"
echo ""

for dir in "${filtered_dirs[@]}"; do
    ((COUNT++))

    echo ""
    echo -e "${gl_bai}[${gl_bufan}$COUNT${gl_bai}]${gl_zi} >>> 处理目录: ${gl_huang}$dir${gl_bai}"
    if ! cd "$dir" 2>/dev/null; then
        echo -e "${gl_huang}⚠️ 无法进入目录${gl_reset}"
        ((FAIL++))
        continue
    fi
    PROJECT_NAME=$(get_project_name "$dir")
    echo -e "${gl_bai}项目名称: ${gl_huang}$PROJECT_NAME${gl_bai}"
    echo -e "${gl_bai}正在拉取镜像中 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    PULL_OUTPUT=$($COMPOSE_CMD pull --quiet 2>&1); PULL_EXIT_CODE=$?
    echo -e "${gl_bai}正在更新容器中 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    UP_OUTPUT=$($COMPOSE_CMD up -d --remove-orphans 2>&1); UP_EXIT_CODE=$?
    check_for_updates "$PULL_EXIT_CODE" "$UP_EXIT_CODE" "$PULL_OUTPUT" "$UP_OUTPUT" "$PROJECT_NAME"
    if [[ $PULL_EXIT_CODE -eq 0 ]] && [[ $UP_EXIT_CODE -eq 0 ]]; then
        display_container_status
        ((SUCCESS++))
    else
        echo -e "${gl_hong}❌ 更新失败${gl_reset}"
        [[ $PULL_EXIT_CODE -ne 0 ]] && echo -e "${gl_huang}Pull错误: ${gl_hui}$(echo "$PULL_OUTPUT" | head -5)${gl_reset}"
        [[ $UP_EXIT_CODE -ne 0 ]] && echo -e "${gl_huang}Up错误: ${gl_hui}$(echo "$UP_OUTPUT" | head -5)${gl_reset}"
        ((FAIL++))
    fi
done

echo ""
echo -e "${gl_bai}正在清理无用镜像 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
docker image prune -f >/dev/null 2>&1 && echo -e "${gl_bai}镜像清理: ${gl_lv}♻️ 清理完成${gl_reset}"

echo ""
echo -e "${gl_lv}✅ 批量更新完成！"
echo -e "${gl_bufan}————————————————————————————————————————————————${gl_reset}"
echo -e "  ${gl_bai}统计信息${gl_reset}"
echo -e "    ${gl_bai}总计项目: ${gl_huang}$COUNT${gl_reset}"
echo -e "    ${gl_bai}总计成功: ${gl_lv}$SUCCESS${gl_reset}"
echo -e "    ${gl_bai}总计失败: ${gl_hong}$FAIL${gl_reset}"

if [[ ${#UPDATED_PROJECTS[@]} -gt 0 ]]; then
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_reset}"
    echo -e "  ${gl_bai}有实际更新的项目 (${gl_lv}${#UPDATED_PROJECTS[@]}${gl_bai}个):"
    for i in "${!UPDATED_PROJECTS[@]}"; do
        project_name="${UPDATED_PROJECTS[$i]}"
        [[ -n "$project_name" ]] && [[ "$project_name" != "unknown_project" ]] && \
        echo -e "    ${gl_lv}✓${gl_bai} $((i+1)). $project_name"
    done
else
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_reset}"
    echo -e "  ${gl_hui}无项目更新${gl_reset}"
fi

if [[ ${#NO_UPDATE_PROJECTS[@]} -gt 0 ]]; then
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_reset}"
    echo -e "  ${gl_bai}无更新的项目 (${gl_bufan}${#NO_UPDATE_PROJECTS[@]}${gl_bai}个):"
    for i in "${!NO_UPDATE_PROJECTS[@]}"; do
        project_name="${NO_UPDATE_PROJECTS[$i]}"
        [[ -n "$project_name" ]] && [[ "$project_name" != "unknown_project" ]] && \
        echo -e "    ${gl_lv}○${gl_bai} $((i+1)). $project_name"
    done
fi

echo -e "${gl_bufan}————————————————————————————————————————————————${gl_reset}"
end_time=$(date '+%F %T'); end_ts=$(date +%s)
total=$((end_ts - start_ts))
printf -v dur "%d时%02d分%02d秒" $((total/3600)) $(((total%3600)/60)) $((total%60))
echo -e "${gl_bai}结束更新时间：${gl_hong}$end_time${gl_bai}"
echo -e "${gl_bai}更新用时共计：${gl_lv}$dur${gl_bai}"
echo -e "${gl_bufan}————————————————————————————————————————————————${gl_reset}"
if [[ ${#UPDATED_PROJECTS[@]} -gt 0 ]]; then
    echo -e "${gl_zi}💡 提示: 有 ${gl_lv}${#UPDATED_PROJECTS[@]}${gl_zi} 个项目已更新，建议进行健康检查${gl_bai}"
fi
if [[ $FAIL -gt 0 ]]; then
    echo -e "${gl_huang}⚠️ 注意: 有 ${gl_hong}$FAIL${gl_huang} 个项目更新失败，请检查日志${gl_reset}"
fi
