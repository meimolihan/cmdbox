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

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n 1 -s
    echo ""
    clear
}

sleep_fractional() {
    local seconds=$1
    if sleep "$seconds" 2>/dev/null; then return 0; fi
    if command -v perl >/dev/null 2>&1; then perl -e "select(undef, undef, undef, $seconds)"; return 0; fi
    if command -v python3 >/dev/null 2>&1; then python3 -c "import time; time.sleep($seconds)"; return 0; fi
    if command -v python >/dev/null 2>&1; then python -c "import time; time.sleep($seconds)"; return 0; fi
    local int_seconds=$(awk -v s="$seconds" 'BEGIN{print int(s+0.999)}')
    sleep "$int_seconds"
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
    echo -ne "${gl_lv}即将退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo ""
    clear
}

unmount_partition() {
    clear
    if [[ $(hostname | tr '[:upper:]' '[:lower:]') != "fnos" ]]; then
            echo -e ""
            echo -e "${gl_zi}>>> FnOS 卸载分区${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            log_error "当前并非 FNOS 系统，脚本仅支持在 FNOS 环境下运行"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            return 1
    fi
    echo -e "${gl_zi}>>> FnOS 卸载分区"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local DEV_ARR=()
    local MP_ARR=()
    local FS_ARR=()
    local SIZE_ARR=()
    local i=1

    printf "${gl_hui}%-2s    %-14s    %-11s    %-38s    %s${gl_bai}\n" \
      "序号" "设备路径" "容量" "挂载点" "文件系统"

    printf "${gl_hui}%-4s    %-10s    %-8s    %-35s    %s${gl_bai}\n" \
      "----" "----------" "---------" "----------------------------------" "----------"

    while read -r dev mp fs; do
        [[ "$dev" != /dev/sd* ]] && continue
        [[ "$mp" == "/" ]] && continue
        [[ "$mp" =~ ^/vol[0-9]?$ ]] && continue
        [[ -z "$mp" ]] && continue

        size=$(lsblk -dno SIZE "$dev" | tr -d ' ')

        DEV_ARR[$i]="$dev"
        MP_ARR[$i]="$mp"
        FS_ARR[$i]="$fs"
        SIZE_ARR[$i]="$size"

        printf "${gl_huang}%-4s${gl_bai}    %-10s    %-9s    %-35s    %s\n" \
          "${i}." "$dev" "$size" "$mp" "$fs"

        ((i++))
    done < <(mount | grep ^/dev/ | grep -v loop | sort | awk '{print $1,$3,$5}')

    if [ ${#DEV_ARR[@]} -eq 0 ]; then
        log_warn "没有可卸载的分区！"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}请选择卸载序号 (${gl_huang}1-${#DEV_ARR[@]}${gl_bai}) 或 输入设备路径(如/dev/sdd1) (${gl_hong}0${gl_bai}退出): ")" sel

    [ "$sel" = "0" ] && exit_script

    local target_dev=""
    if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -le ${#DEV_ARR[@]} ]; then
        target_dev="${DEV_ARR[$sel]}"
    elif [[ -b "$sel" ]]; then
        target_dev="$sel"
    else
        log_error "输入无效！"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return
    fi

    local target_mp=$(mount | grep -w "$target_dev" | awk '{print $3}')
    if [ -z "$target_mp" ]; then
        log_warn "该设备未挂载！"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return
    fi

    echo -e ""
    echo -e "${gl_huang}将要卸载：${gl_lv}$target_dev${gl_bai}"
    echo -e "${gl_huang}挂载点：${gl_lv}$target_mp${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -p "$(echo -e "${gl_bai}确认卸载？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    log_info "已取消"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    exit_animation
    return
    fi

    echo ""
    umount "$target_dev" 2>/dev/null

    if [ $? -eq 0 ]; then
        log_ok "卸载成功：$target_mp"
        rmdir "$target_mp" 2>/dev/null
    else
        log_error "卸载失败！设备忙或权限不足"
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

unmount_partition
