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

column_if_available() {
    if command -v column &> /dev/null; then
        column -t -s $'\t'
    else
        cat
    fi
}

list_beautify_pve_pct() {
    {
        printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "CTID" "名称" "状态" "内存" "磁盘" "锁" "$reset"
        printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "----" "----" "----" "----" "----" "----" "$reset"

        local data
        data=$(pct list | tail -n +2)
        if [ -z "$data" ]; then
            printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_huang" "(无数据)" "(无数据)" "(无数据)" "(无数据)" "(无数据)" "(无数据)" "$reset"
        else
            echo "$data" | while read -r line; do
                ctid=$(echo "$line" | awk '{print $1}')
                status=$(echo "$line" | awk '{print $3}')
                mem=$(echo "$line" | awk '{print $4}')
                disk=$(echo "$line" | awk '{print $5}')
                lock=$(echo "$line" | awk '{print $6}')
                name=$(echo "$line" | sed -E 's/^[ ]*'${ctid}'[ ]+//; s/[ ]+'${status}'.*$//' | xargs)

                if [[ "$status" == "running" ]]; then
                    stat_color="${gl_lv}"
                else
                    stat_color="${gl_hong}"
                fi

                echo -e "${gl_lan}${ctid}${reset}\t${gl_bufan}${name}${reset}\t${stat_color}${status}${reset}\t${gl_huang}${mem}${reset}\t${gl_zi}${disk}${reset}\t${gl_hui}${lock}${reset}"
            done
        fi
    } | column_if_available
}

# ===== 界面辅助函数 =====
break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    read -r -n 1 -s -p ""
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

handle_y_n() {
    echo -ne "\r${gl_hong}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai}) ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.3
    echo -ne "\r${gl_huang}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai}) ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.3
    echo -ne "\r${gl_lv}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai}) ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    return 2
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

cancel_return() {
    local menu_name="${1:-上一级选单}"
    echo -ne "${gl_lv}即将 ${gl_huang}${menu_name} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo ""
    clear
}

exit_animation() {
    echo -ne "${gl_hong}正在退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.3
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.4
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.3
    echo ""
    clear
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

# ===== LXC 容器修改核心函数 =====
lxc_change_ctid() {
    local OLD_ID="$1"
    local NEW_ID="$2"
    local NEW_HOSTNAME="$3"

    # 参数检查
    if [[ -z "$OLD_ID" || -z "$NEW_ID" || -z "$NEW_HOSTNAME" ]]; then
        log_error "缺少参数"
        exit_animation
        return 1
    fi

    if [[ "$OLD_ID" == "$NEW_ID" ]]; then
        log_error "新旧ID不能相同"
        exit_animation
        return 1
    fi

    if [[ -f "/etc/pve/lxc/${NEW_ID}.conf" ]]; then
        log_error "新ID ${NEW_ID} 已被使用"
        exit_animation
        return 1
    fi

    echo -e ""
    echo -e "${gl_huang}>>> 开始修改容器配置${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}旧ID: ${gl_huang}${OLD_ID}${gl_bai}"
    echo -e "${gl_bai}新ID: ${gl_lv}${NEW_ID}${gl_bai}"
    echo -e "${gl_bai}新主机名: ${gl_zi}${NEW_HOSTNAME}${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    # 1. 备份配置
    log_info "[1/6] 备份配置文件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    local TIMESTAMP
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    local BACKUP_DIR="/root/backup_ct_${OLD_ID}_${TIMESTAMP}"

    mkdir -p "$BACKUP_DIR"

    if [[ -f "/etc/pve/lxc/${OLD_ID}.conf" ]]; then
        cp "/etc/pve/lxc/${OLD_ID}.conf" "${BACKUP_DIR}/"
        log_ok "配置文件已备份到: ${gl_huang}${BACKUP_DIR}/${OLD_ID}.conf${gl_bai}"
    else
        log_warn "配置文件 /etc/pve/lxc/${OLD_ID}.conf 不存在"
    fi

    if [[ -d "/var/lib/vz/images/${OLD_ID}" ]]; then
        log_info "正在备份磁盘目录 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        mkdir -p "${BACKUP_DIR}/disk_backup"
        cp -r "/var/lib/vz/images/${OLD_ID}" "${BACKUP_DIR}/disk_backup/"
        log_ok "磁盘目录已备份到: ${gl_huang}${BACKUP_DIR}/disk_backup/${gl_bai}"
    else
        log_warn "磁盘目录 /var/lib/vz/images/${OLD_ID} 不存在"
    fi

    # 2. 检查其他配置文件中的引用
    log_info "[2/6] 检查其他配置文件中的引用 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bai}请检查以下文件中是否包含对容器 ${gl_huang}${OLD_ID}${gl_bai} 的引用:"
    local config_files=(
        "/etc/pve/jobs.cfg"
        "/etc/pve/alerting.cfg"
        "/etc/pve/user.cfg"
    )

    local found_refs=false
    for file in "${config_files[@]}"; do
        if [[ -f "$file" ]]; then
            if grep -q "$OLD_ID" "$file"; then
                found_refs=true
                log_warn "注意: 在 ${gl_huang}$file${gl_bai} 中找到对 ${OLD_ID} 的引用:"
                grep -n "$OLD_ID" "$file" 2>/dev/null
                echo ""
            fi
        fi
    done

    if [[ "$found_refs" == false ]]; then
        log_ok "未在其他配置文件中找到引用"
    fi

    # 3. 修改配置文件
    log_info "[3/6] 修改配置文件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    if [[ ! -f "/etc/pve/lxc/${OLD_ID}.conf" ]]; then
        log_error "配置文件不存在"
        exit_animation
        return 1
    fi

    mv "/etc/pve/lxc/${OLD_ID}.conf" "/etc/pve/lxc/${NEW_ID}.conf"

    if [[ ! -f "/etc/pve/lxc/${NEW_ID}.conf" ]]; then
        log_error "重命名配置文件失败"
        exit_animation
        return 1
    fi

    sed -i "s/^hostname:.*/hostname: ${NEW_HOSTNAME}/" "/etc/pve/lxc/${NEW_ID}.conf"
    sed -i "s:${OLD_ID}/:${NEW_ID}/:g" "/etc/pve/lxc/${NEW_ID}.conf"
    sed -i "s/local:${OLD_ID}/local:${NEW_ID}/g" "/etc/pve/lxc/${NEW_ID}.conf"
    sed -i "s/local-lvm:${OLD_ID}/local-lvm:${NEW_ID}/g" "/etc/pve/lxc/${NEW_ID}.conf"

    log_ok "配置文件已修改: ${gl_huang}/etc/pve/lxc/${NEW_ID}.conf${gl_bai}"

    # 4. 重命名磁盘目录
    log_info "[4/6] 处理容器文件系统 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    if [[ -d "/var/lib/vz/images/${OLD_ID}" ]]; then
        if [[ -d "/var/lib/vz/images/${NEW_ID}" ]]; then
            log_error "目标目录 /var/lib/vz/images/${NEW_ID} 已存在"
            return 1
        fi

        mv "/var/lib/vz/images/${OLD_ID}" "/var/lib/vz/images/${NEW_ID}"

        if [[ ! -d "/var/lib/vz/images/${NEW_ID}" ]]; then
            log_error "重命名容器目录失败"
            return 1
        fi

        log_ok "容器目录已重命名"

        # 5. 重命名磁盘文件
        log_info "[5/6] 重命名容器文件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        cd "/var/lib/vz/images/${NEW_ID}" || {
            log_error "无法进入目录 /var/lib/vz/images/${NEW_ID}"
            exit_animation
            return 1
        }

        local renamed_files=0
        for file in *${OLD_ID}*; do
            if [[ -e "$file" ]]; then
                new_file=$(echo "$file" | sed "s/${OLD_ID}/${NEW_ID}/g")
                mv "$file" "$new_file"
                log_ok "已重命名: ${gl_hui}$file${gl_bai} -> ${gl_lv}$new_file${gl_bai}"
                renamed_files=$((renamed_files + 1))
            fi
        done

        if [[ $renamed_files -eq 0 ]]; then
            log_warn "未找到需要重命名的容器文件"
        else
            log_ok "共重命名了 ${gl_lv}${renamed_files}${gl_bai} 个容器文件"
        fi
    else
        log_warn "容器目录 /var/lib/vz/images/${OLD_ID} 不存在，跳过容器文件处理"
    fi

    # 6. 验证修改
    log_info "[6/6] 验证修改 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo ""
    echo -e "${gl_lv}✅ 修改完成!${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_lan}新配置文件:${gl_bai} ${gl_huang}/etc/pve/lxc/${NEW_ID}.conf${gl_bai}"
    echo -e "${gl_lan}新容器目录:${gl_bai} ${gl_lv}/var/lib/vz/images/${NEW_ID}/${gl_bai}"
    echo -e "${gl_lan}新容器主机名:${gl_bai} ${gl_zi}${NEW_HOSTNAME}${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_lan}备份文件位于:${gl_bai} ${gl_huang}${BACKUP_DIR}/${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if [[ -f "/etc/pve/lxc/${NEW_ID}.conf" ]]; then
        echo ""
        echo -e "${gl_huang}>>> 新配置文件内容预览:${gl_hui}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        head -20 "/etc/pve/lxc/${NEW_ID}.conf"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    fi

    echo -e "${gl_huang}重要提示:${gl_bai}"
    echo -e "${gl_bai}1. 请检查以下项目是否需要手动更新:${gl_hui}"
    echo -e "   - 备份任务 (pve 调度任务)"
    echo -e "   - 监控和告警配置"
    echo -e "   - 权限设置"
    echo -e "   - 网络配置中的引用${gl_bai}"
    echo ""
    echo -e "${gl_bai}2. 如果之前有快照，需要手动处理快照文件${gl_bai}"
    echo ""
    echo -e "${gl_bai}3. 修改完成后可以使用以下命令启动容器:"
    echo -e "${gl_lv}   pct start ${NEW_ID}${gl_bai}"
    echo ""

    echo -e "${gl_huang}>>> 启动新容器${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}是否现在启动容器?(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" start_response
    case "$start_response" in
        [Yy])
            log_info "正在启动容器 ${gl_lv}${NEW_ID}${gl_bai} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            pct start "$NEW_ID" 2>/dev/null

            echo -ne "${gl_lan}等待容器启动 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            for i in {1..20}; do
                sleep_fractional 2
                echo -ne " ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

                if pct status "$NEW_ID" 2>/dev/null | grep -q "running"; then
                    echo ""
                    log_ok "容器 ${gl_lv}${NEW_ID}${gl_bai} 启动成功"

                    read -r -e -p "$(echo -e "${gl_bai}容器是否运行正常?(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" ct_status
                    case "$ct_status" in
                        [Yy])
                            echo ""
                            echo -e "${gl_huang}>>> 删除所有备份文件${gl_bai}"
                            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                            read -r -e -p "$(echo -e "${gl_bai}是否删除所有备份文件?(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" delete_backup
                            case "$delete_backup" in
                                [Yy])
                                    if [[ -d "$BACKUP_DIR" ]]; then
                                        rm -rf "$BACKUP_DIR"
                                        log_ok "备份文件已删除: ${gl_hui}${BACKUP_DIR}${gl_bai}"
                                    else
                                        log_warn "备份目录不存在: ${gl_hui}${BACKUP_DIR}${gl_bai}"
                                    fi
                                    ;;
                                [Nn]|"")
                                    log_info "已保留备份文件: ${gl_huang}${BACKUP_DIR}${gl_bai}"
                                    echo -e "${gl_bai}确认容器正常工作后，可手动删除备份:${gl_hui}"
                                    echo -e "   rm -rf ${BACKUP_DIR}${gl_bai}"
                                    ;;
                                *) handle_y_n ;;
                            esac
                            ;;
                        [Nn]|"")
                            log_warn "容器运行可能不正常，已保留备份文件: ${gl_huang}${BACKUP_DIR}${gl_bai}"
                            echo -e "${gl_bai}请检查容器问题，修复后可手动删除备份:${gl_hui}"
                            echo -e "   rm -rf ${BACKUP_DIR}${gl_bai}"
                            ;;
                        *) handle_y_n ;;
                    esac
                    break
                fi

                if [[ $i -eq 20 ]]; then
                    echo ""
                    log_warn "容器启动超时，请手动检查"
                    log_info "已保留备份文件: ${gl_huang}${BACKUP_DIR}${gl_bai}"
                    echo -e "${gl_bai}请检查容器状态，确认正常后可手动删除备份:${gl_hui}"
                    echo -e "   rm -rf ${BACKUP_DIR}${gl_bai}"
                fi
            done
            ;;
        [Nn]|"")
            log_info "已跳过启动容器"
            echo ""
            echo -e "${gl_lan}备份文件位于:${gl_bai} ${gl_huang}${BACKUP_DIR}/${gl_bai}"
            echo -e "${gl_bai}验证容器正常工作后，可手动删除备份:${gl_hui}"
            echo -e "   rm -rf ${BACKUP_DIR}${gl_bai}"
            ;;
        *) handle_y_n ;;
    esac
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
    return 0
}

lxc_change_ctid_interactive() {
    root_use || return 1
    clear
    if ! command -v qm &> /dev/null; then
        echo -e ""
        echo -e "${gl_zi}>>> PVE容器ID和名称修改工具${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        log_error "未检测到Proxmox VE环境，请确保脚本在PVE节点上运行"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return 1
    fi
    echo -e "${gl_huang}>>> LXC容器列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_pve_pct
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e ""
    echo -e "${gl_zi}>>> LXC容器ID和主机名修改工具${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    while true; do
        read -r -e -p "$(echo -e "${gl_bai}请输入要修改的容器旧ID(${gl_hong}0${gl_bai}退出): ")" OLD_ID

        [ "$OLD_ID" = "0" ] && exit_script

        if [[ -z "$OLD_ID" ]]; then
            log_error "ID不能为空"
            continue
        fi

        if [[ ! "$OLD_ID" =~ ^[0-9]+$ ]]; then
            log_error "ID必须是数字"
            continue
        fi

        if [[ ! -f "/etc/pve/lxc/${OLD_ID}.conf" ]]; then
            log_warn "容器 ${OLD_ID} 的配置文件不存在"
            read -r -e -p "$(echo -e "${gl_bai}是否继续?(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" response
            case "$response" in
                [Yy]) ;;
                [Nn]|"") continue ;;
                *) handle_y_n ;;
            esac
        fi

        log_info "旧ID: ${gl_huang}${OLD_ID}${gl_bai}"
        echo ""
        break
    done

    echo -e "${gl_huang}>>> 关闭容器${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if pct status "$OLD_ID" 2>/dev/null | grep -q "running"; then
        log_info "容器 ${OLD_ID} 正在运行，正在关闭 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo ""

        echo -e "${gl_bai}容器信息:${gl_hui}"
        pct config "$OLD_ID" 2>/dev/null | grep -E "^(hostname|memory|cores|net|rootfs|mp)" | head -10
        echo -e "${gl_bai}"

        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}确认关闭容器 ${gl_huang}${OLD_ID}${gl_bai} 吗?(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm_stop

        case "$confirm_stop" in
            [Yy])
                log_info "正在关闭容器 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                pct stop "$OLD_ID" 2>/dev/null

                echo -ne "${gl_lan}等待容器关闭 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                for i in {1..30}; do
                    if ! pct status "$OLD_ID" 2>/dev/null | grep -q "running"; then
                        echo ""
                        log_ok "容器已成功关闭"
                        break
                    fi
                    echo -ne " ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                    sleep_fractional 1

                    if [[ $i -eq 30 ]]; then
                        echo ""
                        log_warn "容器关闭超时，可能仍在运行"
                        read -r -e -p "$(echo -e "${gl_bai}是否强制继续?(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" force_continue
                        case "$force_continue" in
                            [Yy]) ;;
                            [Nn]|"")
                                log_info "操作已取消"
                                return 1
                                ;;
                            *) handle_y_n ;;
                        esac
                    fi
                done
                ;;
            [Nn]|"")
                log_info "操作已取消"
                return 1
                ;;
            *)
                handle_y_n
                continue
                ;;
        esac
    else
        log_ok "${gl_bai}容器 ${gl_huang}${OLD_ID}${gl_bai} 已停止或不存在"
    fi

    echo ""

    while true; do
        echo -e "${gl_huang}>>> 修改容器ID${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入新ID: ")" NEW_ID

        if [[ -z "$NEW_ID" ]]; then
            log_error "ID不能为空"
            continue
        fi

        if [[ ! "$NEW_ID" =~ ^[0-9]+$ ]]; then
            log_error "ID必须是数字"
            continue
        fi

        if [[ "$OLD_ID" == "$NEW_ID" ]]; then
            log_error "新旧ID不能相同"
            continue
        fi

        if [[ -f "/etc/pve/lxc/${NEW_ID}.conf" ]]; then
            log_error "新ID ${NEW_ID} 已被使用"
            continue
        fi

        log_info "新ID: ${gl_lv}${NEW_ID}${gl_bai}"
        echo ""
        break
    done

    while true; do
        echo -e "${gl_huang}>>> 修改容器主机名${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入新主机名: ")" NEW_HOSTNAME

        if [[ -z "$NEW_HOSTNAME" ]]; then
            log_error "主机名不能为空"
            continue
        fi

        NEW_HOSTNAME=$(echo "$NEW_HOSTNAME" | xargs)

        log_info "新主机名: ${gl_zi}${NEW_HOSTNAME}${gl_bai}"
        echo ""
        break
    done

    echo -e "${gl_huang}>>> 修改摘要${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_lan}旧ID: ${gl_huang}${OLD_ID}${gl_bai}"
    echo -e "${gl_lan}新ID: ${gl_lv}${NEW_ID}${gl_bai}"
    echo -e "${gl_lan}新主机名: ${gl_zi}${NEW_HOSTNAME}${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    read -r -e -p "$(echo -e "${gl_bai}是否确认执行修改?(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" CONFIRM

    case "$CONFIRM" in
        [Yy])
            log_info "开始执行修改操作 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            ;;
        [Nn]|"")
            log_info "操作已取消"
            return 1
            ;;
        *) handle_y_n; return 1 ;;
    esac

    lxc_change_ctid "$OLD_ID" "$NEW_ID" "$NEW_HOSTNAME"
}

# ===== 主入口 =====
lxc_change_ctid_interactive
