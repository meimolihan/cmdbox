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
    read -r -n 1 -s -r -p ""
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

list_beautify_pve_backup() {
    local storage_name="$1"
    local filter_vmid="$2"

    if ! command -v pvesm &> /dev/null; then
        clear
        echo ""
        echo -e "${gl_zi}>>> PVE 存储备份列表${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        log_error "未检测到 Proxmox VE 环境，请确保脚本在 PVE 节点上运行"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return 1
    fi

    if ! pvesm status | awk '{print $1}' | grep -q "^${storage_name}$"; then
        clear
        echo ""
        echo -e "${gl_zi}>>> PVE 存储备份列表${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        log_error "存储ID【${storage_name}】不存在！"
        log_info "可用存储列表:"
        pvesm status | awk 'NR>1{print " - "$1}'
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return 1
    fi

    if [[ -n "${filter_vmid}" && ! "${filter_vmid}" =~ ^[0-9]+$ ]]; then
        clear
        echo ""
        echo -e "${gl_zi}>>> PVE 存储备份列表${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        log_error "VMID 必须为数字！"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return 1
    fi

    local storage_path
    storage_path=$(pvesm path "${storage_name}")
    local dump_base="${storage_path}/dump"

    clear
    if [[ -n "${filter_vmid}" ]]; then
        echo -e "${gl_zi}>>> PVE 存储【${storage_name}】备份列表，仅显示 VMID=${filter_vmid}${gl_bai}"
    else
        echo -e "${gl_zi}>>> PVE 存储【${storage_name}】全部备份列表${gl_bai}"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    {
        printf "%s%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "类型" "VMID" "备份文件名" "大小" "备注" "$reset"
        printf "%s%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "----" "----" "----------" "----" "----" "$reset"

        local raw
        raw=$(pvesm list "${storage_name}" --content backup 2>/dev/null)
        local data
        data=$(echo "$raw" | tail -n +2)
        if [ -n "$data" ]; then
            echo "$data" | while read -r line; do
                local volid
                volid=$(echo "$line" | awk '{print $1}')
                local bk_type
                bk_type=$(echo "$line" | awk '{print $2}')
                local size_byte
                size_byte=$(echo "$line" | awk '{print $4}')
                local vmid
                vmid=$(echo "$line" | awk '{print $5}')

                [[ ! "$bk_type" =~ ^vma ]] && continue
                [[ -n "${filter_vmid}" && "${vmid}" != "${filter_vmid}" ]] && continue

                local bk_filename="${volid#*${storage_name}:backup/}"
                local note_file="${dump_base}/${bk_filename}.notes"
                local notes=""
                if [[ -f "$note_file" ]]; then
                    notes=$(cat "$note_file" | xargs)
                else
                    notes="(无备注)"
                fi

                local size_mb=$(( size_byte / 1024 / 1024 ))
                echo -e "${gl_huang}备份${reset}\t${gl_lan}${vmid}${reset}\t${gl_bufan}${bk_filename}${reset}\t${gl_zi}${size_mb} MB${reset}\t${gl_lv}${notes}${reset}"
            done
        fi
    } | column_if_available

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

# 参数解析：支持互换位置（存储名/VMID 任意顺序）
storage_name="local"
filter_vmid=""

for arg in "$@"; do
    if [[ "$arg" =~ ^[0-9]+$ ]]; then
        filter_vmid="$arg"
    else
        storage_name="$arg"
    fi
done

list_beautify_pve_backup "${storage_name}" "${filter_vmid}"
