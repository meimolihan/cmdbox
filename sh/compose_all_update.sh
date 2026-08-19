#!/bin/bash

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
            echo -e "${gl_hong}❌ 错误: 无法识别目标目录，请确保其中一个参数是存在的目录路径${gl_bai}"
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
    echo -e "${gl_hong}❌ 错误: 目标目录不存在: $TARGET_DIR${gl_bai}"
    exit 1
fi

if ! command -v docker &>/dev/null; then
    echo -e "${gl_hong}❌ 未找到 docker 命令，请确保 Docker 已安装。${gl_bai}"
    exit 1
fi
COMPOSE_CMD=$(command -v docker-compose || echo "docker compose")
if ! $COMPOSE_CMD version &>/dev/null; then
    echo -e "${gl_hong}❌ 未找到可用的 docker compose 命令。${gl_bai}"
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

# 扫描 /vol1/1000/compose 下所有 Docker Compose 项目，生成简化状态报告到 /tmp/compose-status.txt
OUTPUT_FILE="/tmp/compose-status.txt"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

cnt_running=0
cnt_stopped=0
cnt_removed=0
cnt_total=0

tmp_running=$(mktemp)
tmp_stopped=$(mktemp)
tmp_removed=$(mktemp)
trap 'rm -f "$tmp_running" "$tmp_stopped" "$tmp_removed"' EXIT

if [ ! -d "$TARGET_DIR" ]; then
    echo -e "${gl_hong}❌ 目录不存在: $TARGET_DIR${gl_bai}"
    exit 1
fi

echo -e "${gl_hui}🔍 正在扫描 $TARGET_DIR ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

for project_dir in "$TARGET_DIR"/*/; do
    [ -d "$project_dir" ] || continue

    project_name=$(basename "$project_dir")
    project_abs="${project_dir%/}"

    compose_file=""
    for f in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
        if [ -f "$project_dir/$f" ]; then
            compose_file="$f"
            break
        fi
    done

    if [ -z "$compose_file" ]; then
        continue
    fi

    cnt_total=$((cnt_total + 1))

    cd "$project_dir" || continue

    containers=$(docker compose ps -a --format '{{.Name}}|{{.State}}' 2>/dev/null)

    if [ -z "$containers" ]; then
        cnt_removed=$((cnt_removed + 1))
        echo "$project_name|$project_abs|$compose_file|-|无容器" >> "$tmp_removed"
    else
        has_running=0
        state_detail=""
        while IFS='|' read -r cname cstate; do
            [ -z "$cname" ] && continue
            if [ "$cstate" = "running" ]; then
                has_running=1
            fi
            state_detail="${state_detail}${cname}:${cstate}, "
        done <<< "$containers"
        state_detail=${state_detail%, }

        if [ "$has_running" -eq 1 ]; then
            cnt_running=$((cnt_running + 1))
            echo "$project_name|$project_abs|$compose_file|running|$state_detail" >> "$tmp_running"
        else
            cnt_stopped=$((cnt_stopped + 1))
            echo "$project_name|$project_abs|$compose_file|stopped|$state_detail" >> "$tmp_stopped"
        fi
    fi

    cd - >/dev/null 2>&1 || true
done

{
    echo "Docker Compose 项目状态报告"
    echo "扫描时间: $TIMESTAMP"
    echo "扫描目录: $TARGET_DIR"
    echo "项目总数: $cnt_total"
    echo "运行中: $cnt_running"
    echo "已停止: $cnt_stopped"
    echo "已删除: $cnt_removed"
    echo ""
    echo "运行中项目:"
    if [ -s "$tmp_running" ]; then
        while IFS='|' read -r pname ppath pfile pstate pdetail; do
            echo "$pname $ppath $pfile $pstate $pdetail"
        done < "$tmp_running"
    else
        echo "(无)"
    fi
    echo ""
    echo "已停止项目:"
    if [ -s "$tmp_stopped" ]; then
        while IFS='|' read -r pname ppath pfile pstate pdetail; do
            echo "$pname $ppath $pfile $pstate $pdetail"
        done < "$tmp_stopped"
    else
        echo "(无)"
    fi
    echo ""
    echo "已删除项目:"
    if [ -s "$tmp_removed" ]; then
        while IFS='|' read -r pname ppath pfile pstate pdetail; do
            echo "$pname $ppath $pfile $pstate $pdetail"
        done < "$tmp_removed"
    else
        echo "(无)"
    fi
    echo ""
    echo "报告生成完毕"
} > "$OUTPUT_FILE"

echo -e "${gl_lv}✅ 报告已生成: $OUTPUT_FILE${gl_bai}"
echo -e "${gl_hui}📊 总计: ${gl_huang}$cnt_total ${gl_bai}个项目 | 运行: ${gl_lv}$cnt_running${gl_bai} | 停止: ${gl_hong}$cnt_stopped${gl_bai} | 删除: ${gl_zi}$cnt_removed${gl_bai}"

# 扫描 /vol1/1000/compose 下所有 Docker Compose 项目，生成简化状态报告到 /tmp/compose-status.txt

echo -e "${gl_bai}开始更新直接子目录中的 Docker Compose 项目 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

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
    echo -e "${gl_huang}⚠️ 在 $TARGET_DIR 的直接子目录下未找到任何 Docker Compose 项目。${gl_bai}"
    exit 0
fi

filtered_dirs=()
for dir in "${compose_dirs[@]}"; do
    if is_excluded "$dir"; then
        echo -e "${gl_hui}⏭️ 跳过已排除目录: $(basename "$dir")${gl_bai}"
    else
        filtered_dirs+=("$dir")
    fi
done

total_projects=${#filtered_dirs[@]}
if [[ $total_projects -eq 0 ]]; then
    echo -e "${gl_huang}⚠️ 所有找到的目录均被排除，无项目可更新。${gl_bai}"
    exit 0
fi

echo -e "${gl_bai}待更新项目数: ${gl_bufan}$total_projects${gl_bai}"
echo ""

for dir in "${filtered_dirs[@]}"; do
    ((COUNT++))

    echo ""
    echo -e "${gl_bai}[${gl_bufan}$COUNT${gl_bai}]${gl_zi} >>> 处理目录: ${gl_huang}$dir${gl_bai}"
    if ! cd "$dir" 2>/dev/null; then
        echo -e "${gl_huang}⚠️ 无法进入目录${gl_bai}"
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
        echo -e "${gl_hong}❌ 更新失败${gl_bai}"
        [[ $PULL_EXIT_CODE -ne 0 ]] && echo -e "${gl_huang}Pull错误: ${gl_hui}$(echo "$PULL_OUTPUT" | head -5)${gl_bai}"
        [[ $UP_EXIT_CODE -ne 0 ]] && echo -e "${gl_huang}Up错误: ${gl_hui}$(echo "$UP_OUTPUT" | head -5)${gl_bai}"
        ((FAIL++))
    fi
done

echo ""
echo -e "${gl_bai}正在清理无用镜像 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
docker image prune -f >/dev/null 2>&1 && echo -e "${gl_bai}镜像清理: ${gl_lv}♻️ 清理完成${gl_bai}"

echo ""
echo -e "${gl_lv}✅ 批量更新完成！"
echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
echo -e "  ${gl_bai}统计信息${gl_bai}"
echo -e "    ${gl_bai}总计项目: ${gl_huang}$COUNT${gl_bai}"
echo -e "    ${gl_bai}总计成功: ${gl_lv}$SUCCESS${gl_bai}"
echo -e "    ${gl_bai}总计失败: ${gl_hong}$FAIL${gl_bai}"

if [[ ${#UPDATED_PROJECTS[@]} -gt 0 ]]; then
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "  ${gl_bai}有实际更新的项目 (${gl_lv}${#UPDATED_PROJECTS[@]}${gl_bai}个):"
    for i in "${!UPDATED_PROJECTS[@]}"; do
        project_name="${UPDATED_PROJECTS[$i]}"
        [[ -n "$project_name" ]] && [[ "$project_name" != "unknown_project" ]] && \
        echo -e "    ${gl_lv}✓${gl_bai} $((i+1)). $project_name"
    done
else
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "  ${gl_hui}无项目更新${gl_bai}"
fi

if [[ ${#NO_UPDATE_PROJECTS[@]} -gt 0 ]]; then
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "  ${gl_bai}无更新的项目 (${gl_bufan}${#NO_UPDATE_PROJECTS[@]}${gl_bai}个):"
    for i in "${!NO_UPDATE_PROJECTS[@]}"; do
        project_name="${NO_UPDATE_PROJECTS[$i]}"
        [[ -n "$project_name" ]] && [[ "$project_name" != "unknown_project" ]] && \
        echo -e "    ${gl_lv}○${gl_bai} $((i+1)). $project_name"
    done
fi

#########################################################
DRY_RUN=0

[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

if [ ! -f "$OUTPUT_FILE" ]; then
    echo -e "${gl_hong}❌ 状态文件不存在: $OUTPUT_FILE${gl_bai}"
    exit 1
fi

current_section=""
cnt_stop=0
cnt_down=0
cnt_skip=0
cnt_ignore=0

run_cmd() {
    if [ "$DRY_RUN" -eq 1 ]; then
        echo -e "  ${gl_bufan}[DRY-RUN]${gl_bai} $*"
    else
        echo -e "  ${gl_hui}→${gl_bai} $*"
        "$@" >/dev/null 2>&1   # 丢弃所有输出
    fi
}

echo ""
echo -e "${gl_zi} >>> 还原项目状态${gl_bai}"
echo -e "${gl_huang}📄 正在解析 ${gl_lv}$OUTPUT_FILE ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

while IFS= read -r line; do
    case "$line" in
        *"运行中项目"*)   current_section="running"; continue ;;
        *"已停止项目"*)   current_section="stopped"; continue ;;
        *"已删除项目"*)   current_section="removed"; continue ;;
        *"查询超时项目"*) current_section="timeout"; continue ;;
    esac

    echo "$line" | grep -q '/vol1/1000/compose/' || continue

    if [ "$current_section" = "running" ]; then
        cnt_ignore=$((cnt_ignore + 1))
        continue
    fi

    pname=$(echo "$line" | awk '{print $1}')
    ppath=$(echo "$line" | awk '{print $2}')
    pfile=$(echo "$line" | awk '{print $3}')
    compose_full="${ppath}/${pfile}"

    if [ ! -f "$compose_full" ]; then
        echo -e "  ${gl_hong}⚠ 跳过(文件不存在): $compose_full${gl_bai}"
        cnt_skip=$((cnt_skip + 1))
        continue
    fi

    case "$current_section" in
        stopped)
            echo -e "${gl_bufan}【已停止】${gl_bai} $pname"
            run_cmd docker compose -f "$compose_full" stop
            cnt_stop=$((cnt_stop + 1))
            ;;
        removed)
            echo -e "${gl_hong}【已删除】${gl_bai} $pname"
            run_cmd docker compose -f "$compose_full" down
            cnt_down=$((cnt_down + 1))
            ;;
        timeout)
            echo -e "${gl_hong}【超时跳过】${gl_bai} $pname (状态查询超时，需手动确认)"
            cnt_skip=$((cnt_skip + 1))
            ;;
    esac
    echo ""
done < "$OUTPUT_FILE"

echo -e "${gl_lv}执行完毕${gl_bai}: 停止项目：${gl_hong}${cnt_stop}  ${gl_bai}删除项目：${gl_zi}${cnt_down}  ${gl_bai}忽略(运行中)：${gl_huang}${cnt_ignore}  ${gl_bai}跳过：${gl_lv}${cnt_skip}${gl_bai}"

rm -f "$OUTPUT_FILE"
echo -e "${gl_hui}已删除状态文件: $OUTPUT_FILE${gl_bai}"
#########################################################

echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
end_time=$(date '+%F %T'); end_ts=$(date +%s)
total=$((end_ts - start_ts))
printf -v dur "%d时%02d分%02d秒" $((total/3600)) $(((total%3600)/60)) $((total%60))
echo -e "${gl_bai}结束更新时间：${gl_hong}$end_time${gl_bai}"
echo -e "${gl_bai}更新用时共计：${gl_lv}$dur${gl_bai}"
echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
if [[ ${#UPDATED_PROJECTS[@]} -gt 0 ]]; then
    echo -e "${gl_zi}💡 提示: 有 ${gl_lv}${#UPDATED_PROJECTS[@]}${gl_zi} 个项目已更新，建议进行健康检查${gl_bai}"
fi
if [[ $FAIL -gt 0 ]]; then
    echo -e "${gl_huang}⚠️ 注意: 有 ${gl_hong}$FAIL${gl_huang} 个项目更新失败，请检查日志${gl_bai}"
fi