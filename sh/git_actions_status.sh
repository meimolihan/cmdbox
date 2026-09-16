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
    echo -e "\n${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    read -r -n 1 -s -r -p ""
    echo ""
    clear
    exit 0
}

# 获取最新 release.yaml workflow 运行记录
get_gh_run_info() {
    gh run list --workflow=release.yml --limit 1 --json status,displayTitle,headBranch,event,databaseId,startedAt
}

calc_elapsed() {
    local start_iso="$1"
    local start_ts
    start_ts=$(date -d "${start_iso}" +%s 2>/dev/null)
    if [[ -z "$start_ts" ]]; then
        echo "时间解析失败"
        return
    fi
    local now_ts=$(date +%s)
    local diff=$(( now_ts - start_ts ))

    if (( diff < 60 )); then
        echo "${diff} 秒"
    elif (( diff < 3600 )); then
        echo "$((diff / 60)) 分 $((diff % 60)) 秒"
    else
        echo "$((diff / 3600)) 时 $(((diff % 3600)/60)) 分"
    fi
}

beautify_gh_run() {
    clear
    echo -e "${gl_zi}>>> GitHub Actions Release 流水线信息${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    json_data=$(get_gh_run_info)
    if [[ -z "$json_data" || "$json_data" == "[]" ]]; then
        echo -e "${gl_hong}[错误] 未找到 release.yaml 流水线运行记录${reset}"
        echo -e "${gl_bai}检查：gh auth status 确认gh已登录，仓库目录正确${reset}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
    fi

    # jq 解析合法字段
    status=$(echo "$json_data" | jq -r '.[0].status')
    title=$(echo "$json_data" | jq -r '.[0].displayTitle')
    branch=$(echo "$json_data" | jq -r '.[0].headBranch')
    event=$(echo "$json_data" | jq -r '.[0].event')
    run_id=$(echo "$json_data" | jq -r '.[0].databaseId')
    started_at=$(echo "$json_data" | jq -r '.[0].startedAt')

    # 计算运行耗时
    elapsed=$(calc_elapsed "$started_at")

    # 状态翻译 + 颜色
    case "$status" in
        in_progress)
            status_text="${gl_huang}运行中${reset}"
            ;;
        completed)
            # 拉取本次run的最终结果 conclusion
            conclusion=$(gh run view "$run_id" --json conclusion | jq -r '.conclusion')
            case "$conclusion" in
                success) status_text="${gl_lv}成功${reset}";;
                failure) status_text="${gl_hong}失败${reset}";;
                cancelled) status_text="${gl_hui}已取消${reset}";;
                skipped) status_text="${gl_huang}已跳过${reset}";;
                *) status_text="${gl_huang}已完成(${conclusion})${reset}";;
            esac
            ;;
        *)
            status_text="${gl_hui}${status}${reset}"
            ;;
    esac

    printf "%-14s%s\n" "${gl_hui}[运行状态]：${reset}" "$status_text"
    printf "%-14s%s\n" "${gl_hui}[提交标题]：${reset}" "${gl_huang}$title${reset}"
    printf "%-14s%s\n" "${gl_hui}[触发分支]：${reset}" "${gl_lan}$branch${reset}"
    printf "%-14s%s\n" "${gl_hui}[触发事件]：${reset}" "${gl_bai}$event${reset}"
    printf "%-14s%s\n" "${gl_hui}[Run ID]：${reset}" "${gl_bufan}$run_id${reset}"
    printf "%-14s%s\n" "${gl_hui}[已耗时]：${reset}" "${gl_bai}$elapsed${reset}"

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e ""
    echo -e "${gl_huang}>>> 快捷操作命令${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_lv}实时跟踪流水线：${reset}gh run watch $run_id"
    echo -e "${gl_lv}查看详细信息：${reset}gh run view $run_id"
    echo -e "${gl_lv}查看完整日志：${reset}gh run view $run_id --log"
    echo -e "${gl_lv}查看失败日志：${reset}gh run view $run_id --log-failed"
    echo -e "${gl_lv}取消本次构建：${reset}gh run cancel $run_id"
    echo -e "${gl_lv}重新运行流水线：${reset}gh run rerun $run_id"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
}

beautify_gh_run