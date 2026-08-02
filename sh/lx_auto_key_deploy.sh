#!/bin/bash

gl_hui='\e[37m'
gl_hong='\033[31m'
gl_lv='\033[32m'
gl_huang='\033[33m'
gl_lan='\033[34m'
gl_zi='\033[35m'
gl_bufan='\033[96m'
gl_bai='\033[0m'

log_info()  { echo -e "${gl_lan}[信息]${gl_bai} $*"; }
log_ok()    { echo -e "${gl_lv}[成功]${gl_bai} $*"; }
log_warn()  { echo -e "${gl_huang}[警告]${gl_bai} $*"; }
log_error() { echo -e "${gl_hong}[错误]${gl_bai} $*" >&2; }

# 静默模式日志函数
log_info_silent()  { [[ "$SILENT_MODE" != "1" ]] && log_info "$*"; }
log_ok_silent()    { [[ "$SILENT_MODE" != "1" ]] && log_ok "$*"; }
log_warn_silent()  { [[ "$SILENT_MODE" != "1" ]] && log_warn "$*"; }

break_end() {
    [[ "$SILENT_MODE" != "1" ]] && {
        echo -e "${gl_lv}操作完成${gl_bai}"
        echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
        read -r -n 1 -s -r -p ""
        echo ""
        clear
    }
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

exit_script() {
    [[ "$SILENT_MODE" != "1" ]] && {
        local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
        local dots=(
            "${gl_hong}."
            "${gl_huang}."
            "${gl_lv}."
            "${gl_bufan}."
            "${gl_zi}."
            "${gl_cheng}."
        )
        local dot_buffer=""
        local frame_len=${#frames[@]}
        local dot_idx=0
        local total_dots=6

        for ((i=0; i<20; i++)); do
            if (( i > 0 && i % 3 == 0 && dot_idx < total_dots )); then
                dot_buffer+=${dots[$dot_idx]}
                ((dot_idx++))
            fi
            echo -ne "\r\033[K${gl_bufan}${frames[i % frame_len]}${gl_bai} 正在退出 ${dot_buffer}"
            sleep_fractional 0.06
        done
        echo -e "\r\033[K${gl_lv}✓${gl_bai} 成功退出\n"
        clear
    }
    exit 0
}

KEY_PATH="/root/.ssh/id_rsa"
LIST_FILE="/root/.ssh_dist_list.txt"
SUCCESS_IP_LIST=()
CURRENT_USER=""
SILENT_MODE=0

# 显示帮助信息
show_help() {
    cat << EOF
${gl_huang}SSH密钥分发工具${gl_bai}

${gl_bufan}用法：${gl_bai}
  $0 [选项]

${gl_bufan}选项：${gl_bai}
  -u, --user USER     指定SSH用户名
  -p, --pass PASS     指定SSH密码
  -i, --ip IP_LIST    指定目标IP列表（空格分隔）
  -l, --list          显示已分发主机清单
  -d, --delete IP     删除指定IP记录
  -c, --clear         清空所有记录
  -s, --silent        静默模式（不显示冗余信息）
  -h, --help          显示此帮助信息

${gl_bufan}示例：${gl_bai}
  $0 -u root -p password -i "10.10.10.251 10.10.10.252"
  $0 --list
  $0 --delete 10.10.10.254
  $0 --clear
  $0 -s -u root -p pass -i "10.10.10.251"  # 静默模式

${gl_bufan}交互模式：${gl_bai}
  $0                  # 不带参数进入交互菜单

EOF
    exit 0
}

load_list(){
    SUCCESS_IP_LIST=()
    if [[ -f "$LIST_FILE" ]]; then
        while IFS= read -r line; do
            # 去除可能的回车符和空格
            line=$(echo "$line" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            [[ -n "$line" ]] && SUCCESS_IP_LIST+=("$line")
        done < "$LIST_FILE"
    fi
}

save_list(){
    # 使用普通数组进行去重（兼容所有Bash版本）
    local unique_list=()
    local -A seen=()
    
    for ip in "${SUCCESS_IP_LIST[@]}"; do
        # 检查是否已经存在
        if [[ -z "${seen[$ip]:-}" ]]; then
            unique_list+=("$ip")
            seen[$ip]=1
        fi
    done
    
    # 写入文件
    > "$LIST_FILE"
    for ip in "${unique_list[@]}"; do
        echo "$ip" >> "$LIST_FILE"
    done
    SUCCESS_IP_LIST=("${unique_list[@]}")
}

valid_ip() {
    local ip="$1"
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        local a b c d
        IFS='.' read -r a b c d <<< "$ip"
        (( a <= 255 && b <= 255 && c <= 255 && d <= 255 )) && return 0
    fi
    return 1
}

ip_in_list() {
    local target="$1"
    for ip in "${SUCCESS_IP_LIST[@]}"; do
        [[ "$ip" == "$target" ]] && return 0
    done
    return 1
}

add_success_ip() {
    local target_ip="$1"
    load_list
    if ! ip_in_list "$target_ip"; then
        SUCCESS_IP_LIST+=("$target_ip")
        save_list
        log_info_silent "已将 ${target_ip} 存入清单文件"
    fi
}

del_success_ip() {
    local target_ip="$1"
    load_list
    local new_arr=()
    local found=0
    for ip in "${SUCCESS_IP_LIST[@]}"; do
        if [[ "$ip" != "$target_ip" ]]; then
            new_arr+=("$ip")
        else
            found=1
        fi
    done
    
    if [[ $found -eq 1 ]]; then
        SUCCESS_IP_LIST=("${new_arr[@]}")
        save_list
        log_ok_silent "已删除记录：${target_ip}"
        return 0
    else
        log_warn_silent "清单中不存在IP：${target_ip}"
        return 1
    fi
}

print_success_list() {
    local username="$1"
    load_list
    [[ "$SILENT_MODE" != "1" ]] && clear
    echo -e "${gl_huang}>>> 已完成密钥分发主机清单${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    if [[ ${#SUCCESS_IP_LIST[@]} -eq 0 ]]; then
        echo -e "${gl_huang}暂无成功记录${gl_bai}"
    else
        local idx=1
        for ip in "${SUCCESS_IP_LIST[@]}"; do
            echo -e "${gl_lv}${idx}. ${ip}${gl_bai}"
            if [[ -n "$username" ]]; then
                echo -e "     ${gl_bufan}- 测试命令：ssh ${username}@${ip}${gl_bai}"
            else
                echo -e "     ${gl_bufan}- 测试命令：ssh root@${ip}${gl_bai}"
            fi
            ((idx++))
        done
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
}

show_management_menu() {
    echo ""
    echo -e "${gl_zi}>>> SSH密钥分发管理菜单${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bufan}1.${gl_bai} 删除主机记录${gl_bai}"
    echo -e "${gl_bufan}2.${gl_bai} 清空所有记录${gl_bai}"
    echo -e "${gl_bufan}3.${gl_bai} 新增密钥分发${gl_bai}"
    echo -e "${gl_hong}0.${gl_bai} 退出脚本${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
}

diagnose_and_fix_ssh() {
    local host="$1"
    log_info_silent "诊断 ${host} 的SSH连接问题 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    if nc -zv -w3 "$host" 2>&1 | grep -q "refused"; then
        log_warn_silent "${host} SSH端口拒绝连接，服务未运行"
        return 1
    fi
    return 0
}

run_batch_task() {
    local user="$1"
    local pass="$2"
    shift 2
    local ip_list=("$@")
    local success_count=0 fail_count=0 skip_count=0

    # 更新当前用户名
    CURRENT_USER="$user"

    for TARGET_IP in "${ip_list[@]}"; do
        # 去除可能的空格和换行
        TARGET_IP=$(echo "$TARGET_IP" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        if ! valid_ip "$TARGET_IP"; then
            log_error "${TARGET_IP} 非法IP地址，跳过"
            ((fail_count++))
            continue
        fi
        
        # 检查是否已经分发过
        load_list
        if ip_in_list "$TARGET_IP"; then
            log_info_silent "${TARGET_IP} 已经完成密钥分发，跳过"
            ((skip_count++))
            continue
        fi
        
        [[ "$SILENT_MODE" != "1" ]] && echo -e "\n${gl_bufan}————————————————————————${gl_bai}"
        [[ "$SILENT_MODE" != "1" ]] && echo -e "${gl_zi}>>> 正在处理主机: ${TARGET_IP}${gl_bai}"
        log_info_silent "测试网络连通性 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        if ping -c 2 -W 3 "$TARGET_IP" >/dev/null 2>&1; then
            log_ok_silent "${TARGET_IP} 网络可达"
        else
            log_error "${TARGET_IP} 网络不通，跳过"
            ((fail_count++))
            continue
        fi

        diagnose_and_fix_ssh "$TARGET_IP"

        log_info_silent "测试密码SSH连接 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        if sshpass -p "$pass" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "${user}@${TARGET_IP}" "echo ok" 2>/dev/null; then
            log_ok_silent "${TARGET_IP} SSH密码连接成功"
        else
            log_error "${TARGET_IP} SSH登录失败，跳过"
            ((fail_count++))
            continue
        fi

        log_info_silent "推送SSH公钥 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        if sshpass -p "$pass" ssh-copy-id -o StrictHostKeyChecking=no -i "${KEY_PATH}.pub" "${user}@${TARGET_IP}" >/dev/null 2>&1; then
            log_ok_silent "${TARGET_IP} 密钥推送完成"
        else
            log_error "${TARGET_IP} 公钥推送失败"
            ((fail_count++))
            continue
        fi

        log_info_silent "验证免密登录 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        if ssh -o BatchMode=yes -o ConnectTimeout=5 "${user}@${TARGET_IP}" "echo ok" 2>/dev/null; then
            log_ok_silent "${TARGET_IP} 免密登录验证成功"
            add_success_ip "$TARGET_IP"
            ((success_count++))
        else
            log_warn_silent "${TARGET_IP} 密钥已推送，但免密登录校验失败"
            ((fail_count++))
        fi

        [[ "$SILENT_MODE" != "1" ]] && echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        [[ "$SILENT_MODE" != "1" ]] && echo -e "${gl_lv}[测试命令] ssh ${user}@${TARGET_IP}${gl_bai}"
        [[ "$SILENT_MODE" != "1" ]] && echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    done

    echo -e ""
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_zi}>>> 本轮任务汇总${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "  总共处理: ${#ip_list[@]} 台主机"
    [[ $skip_count -gt 0 ]] && echo -e "  已跳过(已分发): ${gl_huang}${skip_count}${gl_bai} 台"
    echo -e "  成功: ${gl_lv}${success_count}${gl_bai} 台"
    echo -e "  失败: ${gl_hong}${fail_count}${gl_bai} 台"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    print_success_list "$CURRENT_USER"
}

delete_ip_interactive() {
    load_list
    if [[ ${#SUCCESS_IP_LIST[@]} -eq 0 ]]; then
        log_warn "清单为空，无需删除"
        return
    fi
    
    print_success_list "$CURRENT_USER"
    echo -e "${gl_huang}请输入要删除的IP地址（输入多个IP用空格分隔）：${gl_bai}"
    read -p $'\033[33m> \033[0m' del_input
    
    if [[ -z "$del_input" ]]; then
        log_info "取消删除操作"
        return
    fi
    
    local del_ips=($del_input)
    local deleted=0
    local not_found=0
    local invalid=0
    
    for ip in "${del_ips[@]}"; do
        if valid_ip "$ip"; then
            load_list
            if ip_in_list "$ip"; then
                del_success_ip "$ip"
                ((deleted++))
            else
                log_warn "清单中不存在IP：${ip}"
                ((not_found++))
            fi
        else
            log_error "IP格式错误：${ip}"
            ((invalid++))
        fi
    done
    
    echo -e "\n${gl_bufan}删除结果：${gl_bai}"
    [[ $deleted -gt 0 ]] && echo -e "  成功删除: ${gl_lv}${deleted}${gl_bai} 个"
    [[ $not_found -gt 0 ]] && echo -e "  未找到: ${gl_huang}${not_found}${gl_bai} 个"
    [[ $invalid -gt 0 ]] && echo -e "  IP格式错误: ${gl_hong}${invalid}${gl_bai} 个"
    
    print_success_list "$CURRENT_USER"
}

interactive_mode() {
    
    load_list
    
    while true; do

        if [[ ${#SUCCESS_IP_LIST[@]} -gt 0 ]]; then
            print_success_list "$CURRENT_USER"
            echo -e "${gl_huang}检测到 ${#SUCCESS_IP_LIST[@]} 台主机已完成密钥分发${gl_bai}"
        else
            echo -e "${gl_huang}当前没有任何已分发的记录${gl_bai}"
        fi

        show_management_menu
        read -p $'\033[33m请输入你的选择: \033[0m' choice
        
        case $choice in
            0)
                exit_script
                ;;
            1)
                delete_ip_interactive
                ;;
            2)
                echo -e "${gl_hong}⚠️  确认清空所有记录吗？[y/N]${gl_bai}"
                read -p $'\033[33m> \033[0m' confirm
                if [[ "${confirm,,}" == "y" ]]; then
                    SUCCESS_IP_LIST=()
                    rm -f "$LIST_FILE"
                    log_ok "所有记录已清空"
                    print_success_list "$CURRENT_USER"
                else
                    log_info "取消清空操作"
                fi
                ;;
            3)
                echo -e ""
                echo -e "${gl_zi}>>> 开始新增密钥分发${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                echo -e "${gl_huang}提示：已分发的IP将被自动跳过${gl_bai}"
                
                read -r -e -p "$(echo -e "${gl_bai}请输入远端SSH用户名: ")" CRED_USER
                [[ -z "$CRED_USER" ]] && log_error "用户名不能为空！" && continue
                read -s -e -p "$(echo -e "${gl_bai}请输入远端SSH密码: ")" CRED_PASS
                echo ""
                [[ -z "$CRED_PASS" ]] && log_error "密码不能为空！" && continue
                log_info "凭证录入完成，登录用户：${CRED_USER}"
                
                # 更新当前用户名
                CURRENT_USER="$CRED_USER"
                
                echo -e "${gl_huang}请输入要分发的主机IP列表（用空格分隔）：${gl_bai}"
                echo -e "${gl_huang}示例：10.10.10.251 10.10.10.252 10.10.10.253${gl_bai}"
                read -p $'\033[33m> \033[0m' ip_input
                
                if [[ -z "$ip_input" ]]; then
                    log_warn "未输入任何IP，返回主菜单"
                    continue
                fi
                
                targets=($ip_input)
                run_batch_task "${CRED_USER}" "${CRED_PASS}" "${targets[@]}"
                break_end
                ;;
            *)
                log_error "无效选项，请选择 0-4"
                ;;
        esac
    done
}

parse_args() {
    local user=""
    local pass=""
    local ip_list=""
    local show_list=0
    local delete_ip=""
    local clear_list=0

    if [[ $# -eq 0 ]]; then
        return 0
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            -u|--user)
                user="$2"
                shift 2
                ;;
            -p|--pass)
                pass="$2"
                shift 2
                ;;
            -i|--ip)
                ip_list="$2"
                shift 2
                ;;
            -l|--list)
                show_list=1
                shift
                ;;
            -d|--delete)
                delete_ip="$2"
                shift 2
                ;;
            -c|--clear)
                clear_list=1
                shift
                ;;
            -s|--silent)
                SILENT_MODE=1
                shift
                ;;
            -h|--help)
                show_help
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                ;;
        esac
    done

    if [[ $show_list -eq 1 ]]; then
        load_list
        print_success_list "$CURRENT_USER"
        exit 0
    fi

    if [[ $clear_list -eq 1 ]]; then
        if [[ "$SILENT_MODE" != "1" ]]; then
            echo -e "${gl_hong}⚠️  确认清空所有记录吗？[y/N]${gl_bai}"
            read -p $'\033[33m> \033[0m' confirm
            if [[ "${confirm,,}" != "y" ]]; then
                log_info "取消清空操作"
                exit 0
            fi
        fi
        SUCCESS_IP_LIST=()
        rm -f "$LIST_FILE"
        log_ok "所有记录已清空"
        print_success_list "$CURRENT_USER"
        exit 0
    fi

    if [[ -n "$delete_ip" ]]; then
        load_list
        del_success_ip "$delete_ip"
        print_success_list "$CURRENT_USER"
        exit 0
    fi

    if [[ -n "$user" && -n "$pass" && -n "$ip_list" ]]; then
        CURRENT_USER="$user"
        # 将IP字符串转换为数组
        IFS=' ' read -r -a ip_array <<< "$ip_list"
        run_batch_task "$user" "$pass" "${ip_array[@]}"
        exit 0
    fi

    if [[ -n "$user" || -n "$pass" || -n "$ip_list" ]]; then
        log_error "参数不完整，需要同时提供 -u, -p 和 -i 参数"
        show_help
    fi

    return 0
}

main() {

    load_list

    if [[ "$SILENT_MODE" != "1" ]]; then
        if [ ! -f "$KEY_PATH" ]; then
            log_info "未检测到密钥，自动生成SSH密钥 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            mkdir -p ~/.ssh
            chmod 700 ~/.ssh
            ssh-keygen -t rsa -b 4096 -f "$KEY_PATH" -N "" -q
            log_ok "密钥生成完成"
        else
            log_info "使用现有密钥: ${KEY_PATH}"
        fi
    else
        if [ ! -f "$KEY_PATH" ]; then
            mkdir -p ~/.ssh
            chmod 700 ~/.ssh
            ssh-keygen -t rsa -b 4096 -f "$KEY_PATH" -N "" -q >/dev/null 2>&1
        fi
    fi

    if ! command -v sshpass &>/dev/null; then
        if [[ "$SILENT_MODE" == "1" ]]; then
            apt update && apt install -y sshpass >/dev/null 2>&1
        else
            log_warn "缺少依赖 sshpass"
            read -p "是否自动安装? [Y/n] " ans
            ans=${ans:-Y}
            if [[ "${ans,,}" == "y" ]]; then
                apt update && apt install -y sshpass
            else
                log_error "缺少sshpass，程序终止"
                exit 1
            fi
        fi
    fi

    parse_args "$@"
    
    if [[ $# -eq 0 ]]; then
        interactive_mode
    fi
}

main "$@"