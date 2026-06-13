#!/bin/bash
set -euo pipefail

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

handle_invalid_input() {
    echo -ne "\r${gl_huang}无效的输入,请重新输入! ${gl_zi} 1 ${gl_huang} 秒后返回"
    sleep 1
    echo -e "\r${gl_lv}无效的输入,请重新输入! ${gl_zi}0${gl_lv} 秒后返回"
    sleep 0.5
    return 2
}

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n 1 -s -r -p ""
    echo ""
    clear
}

exit_script() {
    echo ""
    echo -ne "${gl_hong}感谢使用，再见！${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    clear
    exit 0
}

cancel_return() {
    local menu_name="${1:-上一级选单}"
    echo -ne "${gl_lv}即将返回 ${gl_huang}${menu_name}${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo ""
    clear
}

REMOTE_BASE="https://gitee.com/meimolihan/cmdbox/raw/master/sh"

SERVICES=(
    "git_branch_menu|Git 分支管理|none"
    "git_ssh_key|SSH 密钥配置|platform"
    "git_tag_menu|Git 标签管理|none"
    "git_clone|克隆远程仓库|url"
    "git_pull|拉取项目更新|dir"
    "git_push|推送项目更新|dir"
    "git_all_push|批量推送所有仓库|batch_push"
    "git_all_pull|批量拉取所有仓库|batch_pull"
    "git_new_project|初始化新项目|url"
    "git_apply_ignore|应用 .gitignore 规则|none"
    "git_url_switch|切换远程协议|protocol"
)
SERVICE_COUNT=${#SERVICES[@]}

show_menu() {
    clear
    echo -e "${gl_zi}>>> Git 一键操作菜单${reset}"
    echo -e "${gl_bufan}─────────────────────────────────────────────────────${reset}"
    echo -e "${gl_bufan}1.  ${gl_bai}Git 分支管理     ${gl_bufan}2.  ${gl_bai}SSH 密钥配置"
    echo -e "${gl_bufan}3.  ${gl_bai}Git 标签管理     ${gl_bufan}4.  ${gl_bai}克隆远程仓库"
    echo -e "${gl_bufan}5.  ${gl_bai}拉取项目更新     ${gl_bufan}6.  ${gl_bai}推送项目更新"
    echo -e "${gl_bufan}7.  ${gl_bai}批量推送所有仓库 ${gl_bufan}8.  ${gl_bai}批量拉取所有仓库"
    echo -e "${gl_bufan}9.  ${gl_bai}初始化新项目     ${gl_bufan}10. ${gl_bai}应用 .gitignore"
    echo -e "${gl_bufan}11. ${gl_bai}切换远程协议"
    echo -e "${gl_bufan}─────────────────────────────────────────────────────${reset}"
    echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单   ${gl_hong}00. ${gl_bai}退出脚本"
}

confirm_and_run() {
    local script_name="$1"
    local desc="$2"
    local param_type="$3"

    echo -e "${gl_zi}>>> ${desc}${reset}"
    echo -e "${gl_bufan}─────────────────────────────────────────────────────${reset}"
    # echo -e "${gl_bai}  脚本:   ${gl_lv}${script_name}.sh${reset}"

    read -r -e -p "$(echo -e "${gl_bai}请输入工作目录 (回车默认 ${gl_lv}.${gl_bai}): ")" work_dir
    work_dir="${work_dir:-.}"

    local base="mkdir -p \"$work_dir\" && cd \"$work_dir\""

    case "$param_type" in
        url)
            read -r -e -p "$(echo -e "${gl_bai}请输入仓库地址: ")" repo_url
            if [ -z "$repo_url" ]; then
                log_error "地址不能为空"
                sleep 1
                return
            fi
            local preamble; preamble=$(printf '%s && set -- "%s"' "$base" "$repo_url")
            ;;
        dir)
            local preamble; preamble=$(printf '%s && set -- "%s"' "$base" "$work_dir")
            ;;
        protocol)
            while true; do
                echo -e "${gl_bai}请选择目标协议:${reset}"
                echo -e "${gl_lv}  1${gl_bai}) SSH"
                echo -e "${gl_lv}  2${gl_bai}) HTTPS"
                read -r -e -p "$(echo -e "${gl_bai}请输入编号 (${gl_lv}1-2${gl_bai}): ")" proto_choice
                case "$proto_choice" in
                    1) local proto="ssh"; break ;;
                    2) local proto="https"; break ;;
                    *) handle_invalid_input ;;
                esac
            done
            local preamble; preamble=$(printf '%s && set -- "%s" "%s"' "$base" "$proto" "$work_dir")
            ;;
        batch_push)
            read -r -e -p "$(echo -e "${gl_bai}提交信息 (回车默认 ${gl_huang}update${gl_bai}): ")" commit_msg
            commit_msg="${commit_msg:-update}"
            read -r -e -p "$(echo -e "${gl_bai}排除目录 (空格分隔, 留空无排除): ")" exclude_dirs
            local preamble; preamble=$(printf '%s && set -- "%s" "%s" "%s"' "$base" "$work_dir" "$commit_msg" "$exclude_dirs")
            ;;
        batch_pull)
            read -r -e -p "$(echo -e "${gl_bai}排除目录 (空格分隔, 留空无排除): ")" exclude_dirs
            local preamble; preamble=$(printf '%s && set -- "%s" "%s"' "$base" "$work_dir" "$exclude_dirs")
            ;;
        *)
            local preamble="$base"
            ;;
    esac

    echo ""
    echo -e "${gl_bufan}─────────────────────────────────────────────────────${reset}"
    read -r -e -p "$(echo -e "${gl_bai}确认执行 ${gl_huang}${desc} ${gl_bai}吗? (${gl_lv}Y${gl_bai}/${gl_hong}n${gl_bai}): ")" confirm
    confirm="${confirm:-y}"
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        cancel_return
        return
    fi

    echo ""
    local tmp_script
    tmp_script=$(mktemp)
    printf '%s\n' "$preamble" > "$tmp_script"
    printf '\n' >> "$tmp_script"
    if ! curl -sL "${REMOTE_BASE}/${script_name}.sh" >> "$tmp_script"; then
        log_error "下载脚本失败"
        rm -f "$tmp_script"
        sleep 1
        return
    fi
    bash "$tmp_script"
    rm -f "$tmp_script"

}

main() {
    while true; do
        show_menu
        echo -e "${gl_bufan}─────────────────────────────────────────────────────${reset}"
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" choice

        case "${choice}" in
            0)
                cancel_return "上一级选单"
                break
                ;;
            00 | 000 | 0000)
                exit_script
                ;;
            *)
                if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
                    handle_invalid_input
                    continue
                fi
                local idx=$((choice - 1))
                if (( idx < 0 || idx >= SERVICE_COUNT )); then
                    handle_invalid_input
                    continue
                fi
                local IFS_BAK="$IFS"; IFS='|'
                local parts=(${SERVICES[$idx]})
                IFS="$IFS_BAK"
                clear
                confirm_and_run "${parts[0]}" "${parts[1]}" "${parts[2]}"
                ;;
        esac
    done
}

main "$@"
