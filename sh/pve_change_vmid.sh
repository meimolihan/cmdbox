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

log_info() { echo -e "${gl_lan}[信息]${gl_bai} $*"; }
log_ok() { echo -e "${gl_lv}[成功]${gl_bai} $*"; }
log_warn() { echo -e "${gl_huang}[警告]${gl_bai} $*"; }
log_error() { echo -e "${gl_hong}[错误]${gl_bai} $*" >&2; }

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    read -r -n 1 -s -p ""
    echo ""
    clear
}

column_if_available() {
    if command -v column &> /dev/null; then
        column -t -s $'\t'
    else
        cat
    fi
}

list_beautify_pve_qm() {
    {
        printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "VMID" "名称" "状态" "内存" "磁盘" "锁" "$reset"
        printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "----" "----" "----" "----" "----" "----" "$reset"

        data=$(qm list | awk 'NR>1')
        if [ -z "$data" ]; then
            printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_huang" "(无数据)" "(无数据)" "(无数据)" "(无数据)" "(无数据)" "(无数据)" "$reset"
        else
            echo "$data" | while read -r line; do
                vmid=$(echo "$line" | awk '{print $1}')
                status=$(echo "$line" | awk '{print $3}')
                mem=$(echo "$line" | awk '{print $4}')
                disk=$(echo "$line" | awk '{print $5}')
                lock=$(echo "$line" | awk '{print $6}')
                name=$(echo "$line" | sed -E 's/^[ ]+[0-9]+[ ]+//;s/[ ]+(running|stopped).*//')

                if [[ $status == "running" ]]; then
                    stat_color="${gl_lv}"
                else
                    stat_color="${gl_hong}"
                fi

                echo -e "${gl_lan}${vmid}${reset}\t${gl_bufan}${name}${reset}\t${stat_color}${status}${reset}\t${gl_huang}${mem}${reset}\t${gl_zi}${disk}${reset}\t${gl_hui}${lock}${reset}"
            done
        fi
    } | column_if_available
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

exit_script() {
    echo ""
    echo -ne "${gl_hong}感谢使用，再见！ ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    clear
    exit 0
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

# ===== PVE虚拟机修改核心函数 =====
pve_change_vmid() {
    local old_id="$1"
    local new_id="$2"
    local new_name="$3"

    local config_file="/etc/pve/qemu-server/${old_id}.conf"
    local new_config_file="/etc/pve/qemu-server/${new_id}.conf"

    # 1. 备份原配置
    log_info "备份原配置文件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    cp "$config_file" "${config_file}.bak_$(date +%Y%m%d_%H%M%S)" 2>/dev/null || {
        log_error "备份失败，操作终止"
        return 1
    }

    # 2. 重命名配置文件
    log_info "重命名配置文件 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    mv "$config_file" "$new_config_file" || {
        log_error "重命名配置文件失败"
        return 1
    }

    # 3. 更新虚拟机名称
    log_info "更新虚拟机名称 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    if grep -q "^name:" "$new_config_file"; then
        sed -i "s/^name:.*/name: ${new_name}/" "$new_config_file"
    else
        echo "name: ${new_name}" >> "$new_config_file"
    fi

    # 4. 检查并更新磁盘目录
    log_info "检查并更新相关配置 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    if [ -d "/var/lib/vz/images/${old_id}" ]; then
        log_info "发现磁盘镜像目录，准备迁移 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        mv "/var/lib/vz/images/${old_id}" "/var/lib/vz/images/${new_id}" 2>/dev/null || {
            log_warn "磁盘镜像迁移失败，可能需要手动处理"
        }
    fi

    # 5. 验证修改
    log_info "验证修改结果 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    if [ -f "$new_config_file" ] && grep -q "name: ${new_name}" "$new_config_file"; then
        log_ok "虚拟机ID修改成功！"
        echo -e "${gl_lan}新ID: ${gl_lv}${new_id}${gl_bai}"
        echo -e "${gl_lan}新名称: ${gl_zi}${new_name}${gl_bai}"
        echo -e "\n${gl_huang}更新后的配置预览:${gl_bai}"
        grep -E "^(name|vmgenid|smbios1|ide|scsi|net)" "$new_config_file" | head -10
        return 0
    else
        log_error "修改验证失败"
        return 1
    fi
}

# ===== 主交互函数 =====
pve_change_vmid_interactive() {
    root_use || return 1
    clear
    if ! command -v qm &> /dev/null; then
        echo -e ""
        echo -e "${gl_zi}>>> PVE虚拟机ID和名称修改工具${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        log_error "未检测到Proxmox VE环境，请确保脚本在PVE节点上运行"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return 1
    fi
    echo -e "${gl_huang}>>> PVE 虚拟机列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
   
    list_beautify_pve_qm
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    while true; do
    echo ""
    echo -e "${gl_zi}>>> PVE虚拟机ID和名称修改工具${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入要修改的虚拟机旧ID(${gl_hong}0${gl_bai}退出): ")" OLD_ID
        [ "$OLD_ID" = "0" ] && exit_script
        [[ -z "$OLD_ID" ]] && { log_error "ID不能为空"; continue; }
        [[ ! "$OLD_ID" =~ ^[0-9]+$ ]] && { log_error "ID必须是数字"; continue; }
        [[ ! -f "/etc/pve/qemu-server/${OLD_ID}.conf" ]] && {
            log_warn "虚拟机 ${OLD_ID} 的配置文件不存在"
            read -r -e -p "$(echo -e "${gl_bai}是否继续?(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" response
            case "$response" in [Yy]) ;; [Nn]|"") continue ;; *) handle_y_n; continue ;; esac
        }
        log_info "旧ID: ${gl_huang}${OLD_ID}${gl_bai}"
        echo ""
        break
    done

    echo -e "${gl_huang}>>> 关闭虚拟机${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if qm status "$OLD_ID" 2>/dev/null | grep -q "running"; then
        log_info "虚拟机 ${OLD_ID} 正在运行，正在关闭 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo ""
        echo -e "${gl_bai}虚拟机信息:${gl_hui}"
        qm config "$OLD_ID" 2>/dev/null | grep -E "^(name|memory|cores|net|sata|scsi|ide)" | head -10
        echo -e "${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}确认关闭虚拟机 ${gl_huang}${OLD_ID}${gl_bai} 吗?(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm_stop
        case "$confirm_stop" in
            [Yy])
                log_info "正在关闭虚拟机 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                qm stop "$OLD_ID" 2>/dev/null
                echo -ne "${gl_lan}等待虚拟机关闭 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                for i in {1..30}; do
                    if ! qm status "$OLD_ID" 2>/dev/null | grep -q "running"; then
                        echo ""; log_ok "虚拟机已成功关闭"; break
                    fi
                    echo -ne " ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                    sleep_fractional 1
                    if [[ $i -eq 30 ]]; then
                        echo ""
                        log_warn "虚拟机关闭超时，可能仍在运行"
                        read -r -e -p "$(echo -e "${gl_bai}是否强制继续?(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" force_continue
                        case "$force_continue" in [Yy]) ;; [Nn]|"") log_info "操作已取消"; exit_animation; return 1 ;; *) handle_y_n; continue ;; esac
                    fi
                done
                ;;
            [Nn]|"") log_info "操作已取消"; exit_animation; return 1 ;;
            *) handle_y_n; continue ;;
        esac
    else
        log_ok "${gl_bai}虚拟机 ${gl_huang}${OLD_ID}${gl_bai} 已停止或不存在"
    fi
    echo ""

    while true; do
        echo -e "${gl_huang}>>> 修改虚拟机ID${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入新ID: ")" NEW_ID
        [[ -z "$NEW_ID" ]] && { log_error "ID不能为空"; continue; }
        [[ ! "$NEW_ID" =~ ^[0-9]+$ ]] && { log_error "ID必须是数字"; continue; }
        [[ "$OLD_ID" == "$NEW_ID" ]] && { log_error "新旧ID不能相同"; continue; }
        [[ -f "/etc/pve/qemu-server/${NEW_ID}.conf" ]] && { log_error "新ID ${NEW_ID} 已被使用"; continue; }
        log_info "新ID: ${gl_lv}${NEW_ID}${gl_bai}"
        echo ""
        break
    done

    while true; do
        echo -e "${gl_huang}>>> 修改虚拟机名称${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入新虚拟机名称: ")" NEW_NAME
        [[ -z "$NEW_NAME" ]] && { log_error "名称不能为空"; continue; }
        NEW_NAME=$(echo "$NEW_NAME" | xargs)
        log_info "新名称: ${gl_zi}${NEW_NAME}${gl_bai}"
        echo ""
        break
    done

    echo -e "${gl_huang}>>> 修改摘要${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_lan}旧ID: ${gl_huang}${OLD_ID}${gl_bai}"
    echo -e "${gl_lan}新ID: ${gl_lv}${NEW_ID}${gl_bai}"
    echo -e "${gl_lan}新名称: ${gl_zi}${NEW_NAME}${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    read -r -e -p "$(echo -e "${gl_bai}是否确认执行修改?(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" CONFIRM
    case "$CONFIRM" in
        [Yy]) log_info "开始执行修改操作 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}" ;;
        [Nn]|"") log_info "操作已取消"; exit_animation; return 1 ;;
        *) handle_y_n; return 1 ;;
    esac

    if pve_change_vmid "$OLD_ID" "$NEW_ID" "$NEW_NAME"; then
        echo ""
        log_ok "虚拟机修改完成！"
        echo -e "${gl_bai}现在可以使用 ${gl_lv}qm start ${NEW_ID}${gl_bai} 启动虚拟机"
        break_end
    else
        log_error "虚拟机修改失败！"
        echo -e "${gl_bai}原配置文件已备份，如有需要可手动恢复"
        break_end
        return 1
    fi
}

pve_change_vmid_interactive
