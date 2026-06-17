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
    export gl_cheng=$'\033[38;5;208m'
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
    read -r -n 1 -s -r -p ""
    echo ""
    clear
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
        echo -ne "\r\033[K${gl_bufan}${frames[i % frame_len]}${gl_bai}即将返回 ${gl_huang}${menu_name} ${dot_buffer}"
        sleep_fractional 0.06
    done
    echo -e "\r\033[K${gl_lv}✓${gl_bai} 成功返回${gl_huang}${menu_name}${gl_bai} \n"
    clear
}

exit_animation() {
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

exit_script() {
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
    exit 0
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

handle_invalid_input() {
    echo -e "${gl_huang}[提示]${gl_bai} 输入无效，请输入正确的序号"
}

unmount_samba_shares() {
    local mounted_shares target_mount choice

    root_use
    clear
    echo -e "${gl_zi}>>> 卸载Samba/CIFS共享${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    get_mounted_cifs() {
        if command -v findmnt &>/dev/null; then
            mapfile -t mounted_shares < <(findmnt -t cifs -o TARGET --noheadings 2>/dev/null | grep -v '^$' | sort)
        else
            mapfile -t mounted_shares < <(mount -t cifs 2>/dev/null | awk '{print $3}' | sort)
        fi
    }

    cleanup_fstab() {
        local mount_pattern="$1"
        mount_pattern=$(echo "$mount_pattern" | sed 's/[\/&]/\\&/g')

        cp /etc/fstab /etc/fstab.bak.unmount.$(date +%Y%m%d_%H%M%S) 2>/dev/null

        if grep -q "^[^#].*$mount_pattern.*cifs" /etc/fstab; then
            local fstab_line
            fstab_line=$(grep "^[^#].*$mount_pattern.*cifs" /etc/fstab)

            if echo "$fstab_line" | grep -q "credentials="; then
                local cred_path
                cred_path=$(echo "$fstab_line" | grep -o "credentials=[^, ]*" | cut -d= -f2)
                if [[ -f "$cred_path" ]]; then
                    read -r -e -p "$(echo -e "${gl_bai}是否删除凭据文件 ${gl_huang}$cred_path${gl_bai}? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" del_cred
                    if [[ $del_cred =~ ^[Yy]$ ]]; then
                        rm -f "$cred_path" && log_ok "已删除凭据文件"
                    fi
                fi
            fi

            sed -i "\|^[^#].*$mount_pattern.*cifs|d" /etc/fstab
            log_ok "已从 /etc/fstab 移除挂载项"
        fi
    }

    log_info "正在扫描已挂载的 Samba/CIFS 共享 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

    get_mounted_cifs

    if [ ${#mounted_shares[@]} -eq 0 ]; then
        log_ok "当前没有挂载任何 Samba/CIFS 共享"
        return 0
    fi

    echo -e "${gl_huang}发现以下挂载点:${gl_bai}"
    for idx in "${!mounted_shares[@]}"; do
        local share_info=""
        if command -v findmnt &>/dev/null; then
            share_info=$(findmnt -n -o SOURCE --target "${mounted_shares[$idx]}" 2>/dev/null)
        else
            share_info=$(mount | grep "on ${mounted_shares[$idx]} " | head -1 | awk '{print $1}')
        fi
        echo -e "  ${gl_bufan}$((idx + 1)).${gl_bai} ${mounted_shares[$idx]} ${gl_huang}($share_info)${gl_bai}"
    done

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    while true; do
        read -r -e -p "$(echo -e "${gl_bai}请选择要卸载的序号 (${gl_hong}0${gl_bai}退出) : ")" choice

        case $choice in
        0) exit_script ;;
        *[0-9]*)
            if ((choice > 0 && choice <= ${#mounted_shares[@]})); then
                target_mount="${mounted_shares[$((choice - 1))]}"

                read -r -e -p "$(echo -e "${gl_bai}确定要卸载 ${gl_huang}$target_mount${gl_bai} 吗? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
                if [[ $confirm =~ ^[Yy]$ ]]; then
                    break
                else
                    log_info "操作取消"
                    continue
                fi
            else
                handle_invalid_input
            fi
            ;;
        *)
            handle_invalid_input
            ;;
        esac
    done

    if lsof "$target_mount" &>/dev/null; then
        log_warn "挂载点 $target_mount 正在被使用"
        echo -e "${gl_bai}使用进程:"
        lsof "$target_mount" | head -5
        read -r -e -p "$(echo -e "${gl_bai}是否强制卸载? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" force_unmount
        if [[ $force_unmount =~ ^[Yy]$ ]]; then
            log_info "正在强制卸载 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            if fuser -km "$target_mount" 2>/dev/null; then
                sleep_fractional 2
            fi
        else
            log_info "操作取消"
            return 0
        fi
    fi

    log_info "正在卸载: $target_mount"
    if umount "$target_mount" 2>/dev/null; then
        log_ok "卸载成功"

        cleanup_fstab "$target_mount"

        if [ -d "$target_mount" ] && [ -z "$(ls -A "$target_mount" 2>/dev/null)" ]; then
            read -r -e -p "$(echo -e "${gl_bai}是否删除空目录 ${gl_huang}$target_mount${gl_bai}? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" del_dir
            if [[ $del_dir =~ ^[Yy]$ ]]; then
                rmdir "$target_mount" 2>/dev/null && log_ok "已删除空目录"
            fi
        fi
    else
        log_warn "普通卸载失败，尝试强制卸载 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        if umount -l "$target_mount" 2>/dev/null; then
            log_ok "强制卸载完成"
            cleanup_fstab "$target_mount"
        else
            log_error "卸载失败，挂载点可能仍在被使用"
            echo -e "${gl_bai}尝试以下命令手动解决:"
            echo -e "${gl_huang}  fuser -m -v \"$target_mount\"${gl_bai}  # 查看使用进程"
            echo -e "${gl_huang}  umount -f \"$target_mount\"${gl_bai}   # 强制卸载"
            return 1
        fi
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

unmount_samba_shares
