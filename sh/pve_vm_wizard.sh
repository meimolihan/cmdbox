#!/bin/bash

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

exit_animation() {
    echo -ne "${gl_lv}即将退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
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

handle_invalid_input() {
    echo -ne "\r\033[K${gl_huang}无效的输入,请重新输入! ${gl_zi} 1 ${gl_huang} 秒后返回"
    sleep_fractional 1
    echo -ne "\r\033[K${gl_lv}无效的输入,请重新输入! ${gl_zi}0${gl_lv} 秒后返回"
    sleep_fractional 0.5
    echo -ne "\r\033[K"
    return 2
}

handle_y_n() {
    echo -e "${gl_hong}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai})${gl_hong}。${gl_bai}"
    sleep 1
    echo -e "${gl_huang}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai})${gl_huang}。${gl_bai}"
    sleep 1
    echo -e "${gl_lv}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai})${gl_lv}。${gl_bai}"
    sleep 0.5
    return 2
}

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n 1 -s -r -p ""
    echo ""
    clear
}

cancel_return() {
    local menu_name="${1:-上一级选单}"
    echo -e "${gl_lv}即将返回到 ${gl_huang}${menu_name}${gl_lv}${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    sleep 0.6
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
        mobufan
        return 1
    fi
    return 0
}

TMP_FILE=$(mktemp)
CLEANUP_VMID=""
cleanup() {
    if [ -n "$CLEANUP_VMID" ] && qm status "$CLEANUP_VMID" &>/dev/null; then
        echo ""
        log_warn "检测到未完成创建的虚拟机 VMID=$CLEANUP_VMID"
        read -r -e -p "$(echo -e "${gl_bai}是否删除该虚拟机？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
        case "$confirm" in
            [Yy])
                qm destroy "$CLEANUP_VMID" --purge &>/dev/null
                log_ok "已删除虚拟机 $CLEANUP_VMID"
                ;;
            *)
                log_info "保留虚拟机 $CLEANUP_VMID，请手动处理"
                ;;
        esac
    fi
    [ -f "$TMP_FILE" ] && rm -f "$TMP_FILE"
}
trap cleanup EXIT INT TERM

select_mirror() {
    local img_dir="/var/lib/vz/template/iso"
    if [ ! -d "$img_dir" ]; then
        log_error "镜像目录不存在: $img_dir"
        exit_script
    fi
    mapfile -t images < <(find "$img_dir" -maxdepth 1 -type f \( -iname "*.qcow2" -o -iname "*.raw" -o -iname "*.img" -o -iname "*.iso" \) | sort)
    if [ ${#images[@]} -eq 0 ]; then
        log_error "镜像目录下没有找到支持的镜像文件"
        exit_script
    fi
    
    while true; do
        echo -e ""
        echo -e "${gl_huang}>>> 选择镜像文件${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        for i in "${!images[@]}"; do
            local fname=$(basename "${images[$i]}")
            echo -e "${gl_bufan}$((i+1)). ${gl_bai}$fname"
        done
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        local original_dir="$PWD"
        cd "$img_dir" || { log_error "无法进入目录 $img_dir"; exit_script; }
        read -r -e -p "$(echo -e "${gl_bai}请选择镜像序号，或输入文件名(可Tab补全，${gl_hong}0${gl_bai}退出): ")" choice
        cd "$original_dir" || exit_script
        
        if [[ "$choice" == "0" ]]; then
            exit_script
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#images[@]} ]; then
            IMAGE_PATH="${images[$((choice-1))]}"
            log_ok "已选择镜像: $(basename "$IMAGE_PATH")"
            break
        else
            local test_path="$img_dir/$choice"
            if [ -f "$test_path" ]; then
                IMAGE_PATH="$test_path"
                log_ok "已选择镜像: $(basename "$IMAGE_PATH")"
                break
            else
                log_warn "文件不存在: $test_path"
                sleep 1
            fi
        fi
    done

    local ext="${IMAGE_PATH##*.}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
    if [ "$ext" = "iso" ]; then
        MIRROR_TYPE="iso"
        log_info "检测到 ISO 镜像，将作为安装光盘处理（自动创建空硬盘并设置光驱启动）"
    else
        MIRROR_TYPE="disk"
        log_info "检测到磁盘镜像，将直接导入为系统盘"
    fi
}

get_vmid() {
    while true; do
        read -r -e -p "$(echo -e "${gl_bai}请输入虚拟机ID (VMID) (${gl_hong}0${gl_bai}退出): ")" vmid
        if [[ "$vmid" == "0" ]]; then
            exit_script
        elif [[ "$vmid" =~ ^[0-9]+$ ]] && [ "$vmid" -ge 100 ] && [ "$vmid" -le 999999999 ]; then
            if qm status "$vmid" &>/dev/null; then
                log_warn "VMID $vmid 已存在，请重新输入"
                continue
            fi
            VMID=$vmid
            echo "$VMID" > "$TMP_FILE"
            CLEANUP_VMID=$VMID
            log_ok "使用 VMID: $VMID"
            break
        else
            log_warn "VMID 必须是 100~999999999 的数字"
        fi
    done
}

get_name() {
    while true; do
        read -r -e -p "$(echo -e "${gl_bai}请输入虚拟机名称 (${gl_hong}0${gl_bai}退出): ")" name
        if [[ "$name" == "0" ]]; then
            exit_script
        elif [[ -n "$name" ]]; then
            VM_NAME="$name"
            log_ok "虚拟机名称: $VM_NAME"
            break
        else
            log_warn "名称不能为空"
        fi
    done
}

get_memory() {
    while true; do
        read -r -e -p "$(echo -e "${gl_bai}请输入内存大小(MB，例如 4096) (${gl_hong}0${gl_bai}退出): ")" mem
        if [[ "$mem" == "0" ]]; then
            exit_script
        elif [[ "$mem" =~ ^[0-9]+$ ]] && [ "$mem" -ge 512 ]; then
            MEMORY=$mem
            log_ok "内存: ${MEMORY}MB"
            break
        else
            log_warn "请输入至少 512 的数字"
        fi
    done
}

get_cores() {
    while true; do
        read -r -e -p "$(echo -e "${gl_bai}请输入CPU核心数 (${gl_hong}0${gl_bai}退出): ")" cores
        if [[ "$cores" == "0" ]]; then
            exit_script
        elif [[ "$cores" =~ ^[0-9]+$ ]] && [ "$cores" -ge 1 ]; then
            CORES=$cores
            log_ok "CPU核心数: $CORES"
            break
        else
            log_warn "请输入正整数"
        fi
    done
}

get_storage() {
    mapfile -t storages < <(pvesm status -content images 2>/dev/null | awk 'NR>1 {print $1}')
    if [ ${#storages[@]} -eq 0 ]; then
        log_warn "未找到可用的存储池，将使用默认 local-lvm"
        STORAGE="local-lvm"
        log_ok "存储池: $STORAGE"
        return
    fi
    while true; do
        echo -e ""
        echo -e "${gl_huang}>>> 可用存储池${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        for i in "${!storages[@]}"; do
            echo -e "${gl_bufan}$((i+1)). ${gl_bai}${storages[$i]}"
        done
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入序号或存储池名称 (${gl_hong}0${gl_bai}退出): ")" storage_choice
        if [[ "$storage_choice" == "0" ]]; then
            exit_script
        elif [[ "$storage_choice" =~ ^[0-9]+$ ]] && [ "$storage_choice" -ge 1 ] && [ "$storage_choice" -le ${#storages[@]} ]; then
            STORAGE="${storages[$((storage_choice-1))]}"
            break
        else
            if pvesm status -content images 2>/dev/null | awk '{print $1}' | grep -qx "$storage_choice"; then
                STORAGE="$storage_choice"
                break
            else
                log_warn "无效的存储池名称或序号"
                continue
            fi
        fi
    done
    log_ok "存储池: $STORAGE"
}

get_bridge() {
    mapfile -t bridges < <(ip -br link show type bridge | awk '{print $1}')
    if [ ${#bridges[@]} -eq 0 ]; then
        log_warn "未找到网桥，将使用默认 vmbr0"
        BRIDGE="vmbr0"
        log_ok "网桥: $BRIDGE"
        return
    fi
    while true; do
        echo -e ""
        echo -e "${gl_huang}>>> 可用网桥${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        for i in "${!bridges[@]}"; do
            echo -e "${gl_bufan}$((i+1)). ${gl_bai}${bridges[$i]}"
        done
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入序号或网桥名称 (${gl_hong}0${gl_bai}退出): ")" bridge_choice
        if [[ "$bridge_choice" == "0" ]]; then
            exit_script
        elif [[ "$bridge_choice" =~ ^[0-9]+$ ]] && [ "$bridge_choice" -ge 1 ] && [ "$bridge_choice" -le ${#bridges[@]} ]; then
            BRIDGE="${bridges[$((bridge_choice-1))]}"
            break
        else
            if ip -br link show type bridge | awk '{print $1}' | grep -qx "$bridge_choice"; then
                BRIDGE="$bridge_choice"
                break
            else
                log_warn "无效的网桥名称或序号"
                continue
            fi
        fi
    done
    log_ok "网桥: $BRIDGE"
}

get_bios() {
    while true; do
        echo -e ""
        echo -e "${gl_huang}>>> BIOS 类型${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1. ${gl_bai}seabios (传统BIOS)"
        echo -e "${gl_bufan}2. ${gl_bai}ovmf (UEFI)"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择 (${gl_hong}0${gl_bai}退出): ")" bios_choice
        case "$bios_choice" in
            0) exit_script ;;
            1) BIOS="seabios"; MACHINE="pc"; break ;;
            2) BIOS="ovmf"; MACHINE="q35"; break ;;
            *) handle_invalid_input ;;
        esac
    done
    log_ok "BIOS: $BIOS, 机器类型: $MACHINE"
}

get_disk_size() {
    if [ "$MIRROR_TYPE" != "iso" ]; then
        return
    fi
    while true; do
        read -r -e -p "$(echo -e "${gl_bai}请输入系统盘大小(GB，例如 32) (${gl_hong}0${gl_bai}退出): ")" size
        if [[ "$size" == "0" ]]; then
            exit_script
        elif [[ "$size" =~ ^[0-9]+$ ]] && [ "$size" -ge 1 ]; then
            DISK_SIZE_GB="$size"
            log_ok "系统盘大小: ${DISK_SIZE_GB}GB"
            break
        else
            log_warn "请输入至少 1 的正整数"
        fi
    done
}

create_vm() {
    echo -e ""
    echo -e "${gl_zi}>>> 开始创建虚拟机${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    if ! qm create "$VMID" \
        --name "$VM_NAME" \
        --memory "$MEMORY" \
        --cores "$CORES" \
        --cpu host \
        --net0 "virtio,bridge=$BRIDGE" \
        --bios "$BIOS" \
        --machine "$MACHINE" \
        --scsihw virtio-scsi-single; then
        log_error "创建虚拟机基础配置失败"
        return 1
    fi
    log_ok "基础配置完成"

    if [ "$MIRROR_TYPE" = "iso" ]; then
        log_info "处理 ISO 镜像：挂载为光驱，并创建空硬盘"
        
        if ! qm set "$VMID" --ide2 "$IMAGE_PATH,media=cdrom"; then
            log_error "挂载 ISO 到光驱失败"
            return 1
        fi
        log_ok "ISO 已挂载为光驱 (ide2)"
        
        local disk_vol="${STORAGE}:${DISK_SIZE_GB},format=qcow2"
        if ! qm set "$VMID" --scsi0 "$disk_vol"; then
            log_error "创建并附加空硬盘失败"
            return 1
        fi
        log_ok "空硬盘已创建并附加到 scsi0 (${DISK_SIZE_GB}GB)"
        
        if ! qm set "$VMID" --boot order=ide2;scsi0; then
            log_error "设置启动顺序失败"
            return 1
        fi
        log_ok "启动顺序: 光驱(ide2) -> 硬盘(scsi0)"
    else
        log_info "导入磁盘镜像: $IMAGE_PATH -> 存储 $STORAGE"
        local import_output
        import_output=$(qm importdisk "$VMID" "$IMAGE_PATH" "$STORAGE" 2>&1)
        if [ $? -ne 0 ]; then
            log_error "导入磁盘失败: $import_output"
            return 1
        fi
        log_ok "磁盘导入成功"
        
        local disk_vol
        disk_vol=$(echo "$import_output" | grep -oP "imported as '\K[^']+")
        if [ -z "$disk_vol" ]; then
            disk_vol=$(qm config "$VMID" | grep -oP "unused0:\s*\K\S+")
            if [ -z "$disk_vol" ]; then
                log_error "无法获取导入的磁盘卷名"
                return 1
            fi
        fi
        log_info "磁盘卷: $disk_vol"
        
        if ! qm set "$VMID" --scsi0 "$disk_vol"; then
            log_error "附加磁盘失败"
            return 1
        fi
        log_ok "磁盘已附加到 scsi0"
        
        if ! qm set "$VMID" --boot order=scsi0; then
            log_error "设置启动顺序失败"
            return 1
        fi
        log_ok "启动顺序: 硬盘(scsi0)"
    fi

    if [ "$BIOS" = "ovmf" ]; then
        log_info "添加 EFI 磁盘 (4MB)"
        if ! qm set "$VMID" --efidisk0 "${STORAGE}:1,format=raw,efitype=4m"; then
            log_warn "添加 EFI 磁盘失败，您稍后可手动添加"
        else
            log_ok "EFI 磁盘已添加"
        fi
    fi

    if ! qm set "$VMID" --serial0 socket; then
        log_warn "添加串口控制台失败"
    else
        log_ok "串口控制台已启用"
    fi

    if ! qm set "$VMID" --agent enabled=1; then
        log_warn "启用 QEMU Guest Agent 失败"
    else
        log_ok "QEMU Guest Agent 已启用"
    fi

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    log_ok "虚拟机 $VM_NAME (VMID: $VMID) 创建成功！"
    if [ "$MIRROR_TYPE" = "iso" ]; then
        echo -e "${gl_lv}提示: 虚拟机将从 ISO 光驱启动，请完成操作系统安装。安装后系统将自动从硬盘启动。${gl_bai}"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    CLEANUP_VMID=""
    return 0
}

main() {
    clear
    root_use
    if ! command -v qm &> /dev/null; then
        echo -e ""
        echo -e "${gl_huang}>>> Proxmox VE 交互式虚拟机创建工具${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        log_error "未检测到Proxmox VE环境，请确保脚本在PVE节点上运行"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return 1
    fi
    echo -e "${gl_zi}>>> Proxmox VE 交互式虚拟机创建工具${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    for cmd in qm pvesm ip; do
        if ! command -v "$cmd" &>/dev/null; then
            log_error "命令 $cmd 未找到，请在 Proxmox VE 环境中运行"
            exit_script
        fi
    done

    select_mirror
    get_vmid
    get_name
    get_memory
    get_cores
    get_storage
    get_bridge
    get_bios
    if [ "$MIRROR_TYPE" = "iso" ]; then
        get_disk_size
    fi

    echo -e ""
    echo -e "${gl_huang}>>> 配置确认${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}镜像类型:   ${gl_lv}$MIRROR_TYPE"
    echo -e "${gl_bai}镜像路径:   ${gl_lv}$IMAGE_PATH"
    echo -e "${gl_bai}VMID:       ${gl_lv}$VMID"
    echo -e "${gl_bai}名称:       ${gl_lv}$VM_NAME"
    echo -e "${gl_bai}内存:       ${gl_lv}${MEMORY}MB"
    echo -e "${gl_bai}CPU核心:    ${gl_lv}$CORES"
    echo -e "${gl_bai}存储池:     ${gl_lv}$STORAGE"
    echo -e "${gl_bai}网桥:       ${gl_lv}$BRIDGE"
    echo -e "${gl_bai}BIOS:       ${gl_lv}$BIOS"
    echo -e "${gl_bai}机器类型:   ${gl_lv}$MACHINE"
    if [ "$MIRROR_TYPE" = "iso" ]; then
        echo -e "${gl_bai}系统盘大小: ${gl_lv}${DISK_SIZE_GB}GB"
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    read -r -e -p "$(echo -e "${gl_bai}确认以上信息并开始创建? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
    case "$confirm" in
        [Yy]) create_vm ;;
        [Nn]) 
            log_info "已取消创建"
            exit_animation
            exit 0
            ;;
        *) handle_y_n; main ;;
    esac

    if [ $? -eq 0 ]; then
        break_end
    else
        log_error "创建过程中出现错误，请检查日志"
        read -r -e -p "$(echo -e "${gl_bai}按回车键退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}${gl_bai}")"
    fi
    exit_script
}

main "$@"
