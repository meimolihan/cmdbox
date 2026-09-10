#!/bin/bash

# ============================================================================
# 颜色定义
# ============================================================================
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

# ============================================================================
# 全局变量
# ============================================================================
TARGET_DIR=""
EXCLUDE_DIRS=()
DRY_RUN=0
OUTPUT_FILE="/tmp/compose-status.txt"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

# 统计变量
SUCCESS=0
FAIL=0
UPDATED_PROJECTS=()
NO_UPDATE_PROJECTS=()

# ============================================================================
# 辅助函数
# ============================================================================
is_directory() { [[ -d "$1" ]] && return 0 || return 1; }

show_help() {
    cat << HELPTEXT
用法: $0 [选项] [目标目录] ["排除目录1 排除目录2 ..."]  或  $0 [选项] ["排除目录1 排除目录2 ..."] [目标目录]

选项:
  --dry-run    模拟执行，不实际修改容器状态
  --help       显示此帮助

说明:
  - 目标目录和排除目录的顺序可以互换，脚本会自动识别存在的目录作为目标目录。
  - 排除目录用空格分隔的字符串表示，支持相对路径（相对于目标目录）或目录名。

示例:
  $0 /vol1/1000/compose "test1 test2 test3"     # 目标目录在前
  $0 "test1 test2 test3" /vol1/1000/compose     # 排除列表在前
  $0 /vol1/1000/compose                         # 仅目标目录
  $0 --dry-run /vol1/1000/compose               # 模拟运行
HELPTEXT
}

# ============================================================================
# 参数解析（支持 --dry-run 和 --help）
# ============================================================================
parse_args() {
    local args=()
    for arg in "$@"; do
        case "$arg" in
            --dry-run) DRY_RUN=1 ;;
            --help)    show_help; exit 0 ;;
            *)         args+=("$arg") ;;
        esac
    done

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

# ============================================================================
# 基础检查
# ============================================================================
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

# ============================================================================
# 函数：判断项目是否被排除
# ============================================================================
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

# ============================================================================
# 函数：获取 Compose 项目名称（优先从 compose 文件或 .env 读取）
# ============================================================================
get_project_name() {
    local dir="${1:-}"
    if [[ -z "$dir" ]]; then
        echo "unknown"
        return
    fi
    local dir_name=$(basename "$dir")
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

# ============================================================================
# 函数：显示容器状态
# ============================================================================
display_container_status() {
    local compose_path="$1"
    local container_count running_count
    container_count=$($COMPOSE_CMD -f "$compose_path" ps -q 2>/dev/null | wc -l)
    running_count=$($COMPOSE_CMD -f "$compose_path" ps --filter status=running -q 2>/dev/null | wc -l)
    if [[ $container_count -gt 0 ]]; then
        echo -e "${gl_bai}容器状态: ${gl_lv}✓${gl_bai} 发现 ${gl_bufan}$container_count ${gl_bai}个容器，其中 ${gl_bufan}$running_count ${gl_bai}个在运行"
    else
        echo -e "${gl_bai}容器状态: ${gl_huang}⚠️ 未发现运行中的容器${gl_bai}"
    fi
}

# ============================================================================
# 函数：更新单个项目（串行），并记录更新状态
# ============================================================================
update_project() {
    local dir="$1"
    local index="$2"
    local project_name=$(get_project_name "$dir")
    local ret=0

    echo -e "${gl_bai}[${gl_bufan}$index${gl_bai}]${gl_zi} >>> 处理目录: ${gl_huang}$dir${gl_bai}"
    echo -e "${gl_bai}项目名称: ${gl_huang}$project_name${gl_bai}"

    # 找到 compose 文件
    local compose_file=""
    for f in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
        if [[ -f "$dir/$f" ]]; then
            compose_file="$f"
            break
        fi
    done

    if [[ -z "$compose_file" ]]; then
        echo -e "${gl_hong}❌ 未找到 compose 文件${gl_bai}"
        return 1
    fi

    local compose_path="$dir/$compose_file"

    if [[ $DRY_RUN -eq 1 ]]; then
        echo -e "  ${gl_bufan}[DRY-RUN]${gl_bai} $COMPOSE_CMD -f $compose_path pull --quiet"
        echo -e "  ${gl_bufan}[DRY-RUN]${gl_bai} $COMPOSE_CMD -f $compose_path up -d --remove-orphans"
        return 0
    fi

    echo -e "${gl_bai}正在拉取镜像中 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    local pull_output
    pull_output=$($COMPOSE_CMD -f "$compose_path" pull --quiet 2>&1)
    local pull_exit=$?

    echo -e "${gl_bai}正在更新容器中 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    local up_output
    up_output=$($COMPOSE_CMD -f "$compose_path" up -d --remove-orphans 2>&1)
    local up_exit=$?

    # 判断是否有实际更新
    local has_update=false update_type=""
    if [[ $pull_exit -eq 0 ]] && echo "$pull_output" | grep -q -E "Downloaded newer image|Status: Downloaded newer image"; then
        has_update=true; update_type="镜像更新"
    fi
    if [[ $up_exit -eq 0 ]] && echo "$up_output" | grep -q -E "Recreating|Creating|Starting|Started"; then
        if [[ -n "$update_type" ]]; then update_type="镜像+容器更新"; else has_update=true; update_type="容器更新"; fi
    fi

    if [[ "$has_update" == "true" ]]; then
        echo -e "${gl_lv}✅ 更新成功 ${gl_huang}(${update_type})${gl_bai}"
        UPDATED_PROJECTS+=("$project_name")
    else
        echo -e "${gl_lv}✅ 更新完成 (无变化)${gl_bai}"
        NO_UPDATE_PROJECTS+=("$project_name")
    fi

    if [[ $pull_exit -ne 0 ]] || [[ $up_exit -ne 0 ]]; then
        echo -e "${gl_hong}❌ 更新失败${gl_bai}"
        [[ $pull_exit -ne 0 ]] && echo -e "${gl_huang}Pull错误: ${gl_hui}$(echo "$pull_output" | head -5)${gl_bai}"
        [[ $up_exit -ne 0 ]] && echo -e "${gl_huang}Up错误: ${gl_hui}$(echo "$up_output" | head -5)${gl_bai}"
        ret=1
    else
        display_container_status "$compose_path"
    fi

    return $ret
}

# ============================================================================
# 主流程
# ============================================================================
echo ""
start_time=$(date '+%F %T'); start_ts=$(date +%s)
echo -e "${gl_bai}开始更新时间：${gl_lv}$start_time${gl_bai}"
echo -e "${gl_bai}目标目录：${gl_huang}$TARGET_DIR${gl_bai}"

if [[ ${#EXCLUDE_DIRS[@]} -gt 0 ]]; then
    echo -e "${gl_bai}排除目录：${gl_huang}${EXCLUDE_DIRS[*]}${gl_bai}"
fi
if [[ $DRY_RUN -eq 1 ]]; then
    echo -e "${gl_bufan}🔍 模拟运行模式 (--dry-run)${gl_bai}"
fi

# ----------------------------------------------------------------------------
# 第一步：扫描所有项目，收集信息并生成状态报告
# ----------------------------------------------------------------------------
echo -e "${gl_hui}🔍 正在扫描 $TARGET_DIR ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

declare -a project_infos=()
cnt_running=0
cnt_stopped=0
cnt_removed=0
cnt_total=0

tmp_running=$(mktemp)
tmp_stopped=$(mktemp)
tmp_removed=$(mktemp)
trap 'rm -f "$tmp_running" "$tmp_stopped" "$tmp_removed" "$OUTPUT_FILE" 2>/dev/null' EXIT

for project_dir in "$TARGET_DIR"/*/; do
    [[ -d "$project_dir" ]] || continue
    project_abs="${project_dir%/}"
    compose_file=""
    for f in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
        if [[ -f "$project_dir/$f" ]]; then
            compose_file="$f"
            break
        fi
    done
    [[ -z "$compose_file" ]] && continue

    cnt_total=$((cnt_total + 1))
    project_name=$(get_project_name "$project_abs")
    containers=$($COMPOSE_CMD -f "$project_dir/$compose_file" ps -a --format '{{.Name}}|{{.State}}' 2>/dev/null)
    if [[ -z "$containers" ]]; then
        cnt_removed=$((cnt_removed + 1))
        status="removed"
        detail="无容器"
        echo "$project_name|$project_abs|$compose_file|$status|$detail" >> "$tmp_removed"
    else
        has_running=0
        state_detail=""
        while IFS='|' read -r cname cstate; do
            [[ -z "$cname" ]] && continue
            if [[ "$cstate" == "running" ]]; then
                has_running=1
            fi
            state_detail="${state_detail}${cname}:${cstate}, "
        done <<< "$containers"
        state_detail=${state_detail%, }
        if [[ $has_running -eq 1 ]]; then
            cnt_running=$((cnt_running + 1))
            status="running"
            echo "$project_name|$project_abs|$compose_file|$status|$state_detail" >> "$tmp_running"
        else
            cnt_stopped=$((cnt_stopped + 1))
            status="stopped"
            echo "$project_name|$project_abs|$compose_file|$status|$state_detail" >> "$tmp_stopped"
        fi
    fi
    project_infos+=("$project_abs|$compose_file|$project_name|$status")
done

# 生成状态报告文件
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
    if [[ -s "$tmp_running" ]]; then
        while IFS='|' read -r pname ppath pfile pstate pdetail; do
            echo "$pname $ppath $pfile $pstate $pdetail"
        done < "$tmp_running"
    else
        echo "(无)"
    fi
    echo ""
    echo "已停止项目:"
    if [[ -s "$tmp_stopped" ]]; then
        while IFS='|' read -r pname ppath pfile pstate pdetail; do
            echo "$pname $ppath $pfile $pstate $pdetail"
        done < "$tmp_stopped"
    else
        echo "(无)"
    fi
    echo ""
    echo "已删除项目:"
    if [[ -s "$tmp_removed" ]]; then
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

# 如果没有项目，退出
if [[ $cnt_total -eq 0 ]]; then
    echo -e "${gl_huang}⚠️ 未找到任何项目，退出。${gl_bai}"
    exit 0
fi

# ----------------------------------------------------------------------------
# 第二步：过滤出需要更新的项目（排除已排除的）
# ----------------------------------------------------------------------------
echo -e "${gl_bai}开始更新直接子目录中的 Docker Compose 项目 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

filtered_projects=()
for info in "${project_infos[@]}"; do
    IFS='|' read -r dir compose_file pname status <<< "$info"
    if is_excluded "$dir"; then
        echo -e "${gl_hui}⏭️ 跳过已排除目录: $(basename "$dir")${gl_bai}"
    else
        filtered_projects+=("$dir|$compose_file|$pname")
    fi
done

total_projects=${#filtered_projects[@]}
if [[ $total_projects -eq 0 ]]; then
    echo -e "${gl_huang}⚠️ 所有找到的目录均被排除，无项目可更新。${gl_bai}"
else
    echo -e "${gl_bai}待更新项目数: ${gl_bufan}$total_projects${gl_bai}"
    echo ""

    # 串行更新每个项目
    job_index=0
    for entry in "${filtered_projects[@]}"; do
        IFS='|' read -r dir compose_file pname <<< "$entry"
        ((job_index++))
        if update_project "$dir" "$job_index"; then
            ((SUCCESS++))
        else
            ((FAIL++))
        fi
        echo ""  # 空行分隔
    done
fi

# ----------------------------------------------------------------------------
# 第三步：清理无用镜像（只删除 dangling）
# ----------------------------------------------------------------------------
echo ""
echo -e "${gl_bai}正在清理无用镜像 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
if [[ $DRY_RUN -eq 1 ]]; then
    echo -e "  ${gl_bufan}[DRY-RUN]${gl_bai} docker image prune -f --filter 'dangling=true'"
else
    docker image prune -f --filter "dangling=true" >/dev/null 2>&1 && echo -e "${gl_bai}镜像清理: ${gl_lv}♻️ 清理完成${gl_bai}"
fi

# ----------------------------------------------------------------------------
# 第四步：还原项目状态（根据状态文件）
# ----------------------------------------------------------------------------
echo ""
echo -e "${gl_zi} >>> 还原项目状态${gl_bai}"
echo -e "${gl_huang}📄 正在解析 ${gl_lv}$OUTPUT_FILE ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

if [[ ! -f "$OUTPUT_FILE" ]]; then
    echo -e "${gl_hong}❌ 状态文件不存在: $OUTPUT_FILE${gl_bai}"
else
    current_section=""
    cnt_stop=0
    cnt_down=0
    cnt_skip=0
    cnt_ignore=0

    run_cmd() {
        if [[ $DRY_RUN -eq 1 ]]; then
            echo -e "  ${gl_bufan}[DRY-RUN]${gl_bai} $*"
        else
            echo -e "  ${gl_hui}→${gl_bai} $*"
            "$@" >/dev/null 2>&1
        fi
    }

    while IFS= read -r line; do
        case "$line" in
            *"运行中项目"*)   current_section="running"; continue ;;
            *"已停止项目"*)   current_section="stopped"; continue ;;
            *"已删除项目"*)   current_section="removed"; continue ;;
            *"查询超时项目"*) current_section="timeout"; continue ;;
        esac

        echo "$line" | grep -q '/vol1/1000/compose/' || continue

        if [[ "$current_section" == "running" ]]; then
            cnt_ignore=$((cnt_ignore + 1))
            continue
        fi

        pname=$(echo "$line" | awk '{print $1}')
        ppath=$(echo "$line" | awk '{print $2}')
        pfile=$(echo "$line" | awk '{print $3}')
        compose_full="${ppath}/${pfile}"

        if [[ ! -f "$compose_full" ]]; then
            echo -e "  ${gl_hong}⚠ 跳过(文件不存在): $compose_full${gl_bai}"
            cnt_skip=$((cnt_skip + 1))
            continue
        fi

        case "$current_section" in
            stopped)
                echo -e "${gl_bufan}【已停止】${gl_bai} $pname"
                run_cmd $COMPOSE_CMD -f "$compose_full" stop
                cnt_stop=$((cnt_stop + 1))
                ;;
            removed)
                echo -e "${gl_hong}【已删除】${gl_bai} $pname"
                run_cmd $COMPOSE_CMD -f "$compose_full" down
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
fi

# ============================================================================
# 最终统计与打印更新/无更新项目列表
# ============================================================================
echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
echo -e "  ${gl_bai}统计信息${gl_bai}"
echo -e "    ${gl_bai}总计成功: ${gl_lv}$SUCCESS${gl_bai}"
echo -e "    ${gl_bai}总计失败: ${gl_hong}$FAIL${gl_bai}"

if [[ ${#UPDATED_PROJECTS[@]} -gt 0 ]]; then
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "  ${gl_bai}有实际更新的项目 (${gl_lv}${#UPDATED_PROJECTS[@]}${gl_bai}个):"
    for i in "${!UPDATED_PROJECTS[@]}"; do
        project_name="${UPDATED_PROJECTS[$i]}"
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
        echo -e "    ${gl_lv}○${gl_bai} $((i+1)). $project_name"
    done
fi

# 结束时间
echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
end_time=$(date '+%F %T'); end_ts=$(date +%s)
total=$((end_ts - start_ts))
printf -v dur "%d时%02d分%02d秒" $((total/3600)) $(((total%3600)/60)) $((total%60))
echo -e "${gl_bai}结束更新时间：${gl_hong}$end_time${gl_bai}"
echo -e "${gl_bai}更新用时共计：${gl_lv}$dur${gl_bai}"
echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

if [[ $DRY_RUN -eq 0 ]]; then
    if [[ ${#UPDATED_PROJECTS[@]} -gt 0 ]]; then
        echo -e "${gl_zi}💡 提示: 有 ${gl_lv}${#UPDATED_PROJECTS[@]}${gl_zi} 个项目已更新，建议进行健康检查${gl_bai}"
    fi
    if [[ $FAIL -gt 0 ]]; then
        echo -e "${gl_huang}⚠️ 注意: 有 ${gl_hong}$FAIL${gl_huang} 个项目更新失败，请检查日志${gl_bai}"
    fi
fi