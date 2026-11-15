#!/bin/bash
# ============================================================
# 脚本名称: pve_igpu_passthru_info.sh
# 功能描述: 检测 PVE 核显直通方式（整卡 VFIO / SR-IOV / GVT-g / 未直通）
# 检测内容: 内核启动参数、IOMMU、VFIO 模块、PCI 当前驱动、xe/i915 黑名单、
#           SR-IOV、mdev/GVT-g、虚拟机 hostpci 绑定，最后给出直通方式判定
# 适用环境: Proxmox VE 8.x（其它 Linux 也可运行，PVE 专属项自动跳过）
# 远程执行: bash <(curl -sSL gitee.com/meimolihan/cmdbox/raw/master/sh/pve_igpu_passthru_info.sh)
# 本地执行: bash pve_igpu_passthru_info.sh [选项] [PCI地址]
# 注意事项: 只读检测，不修改任何系统配置；建议以 root 运行
# ============================================================
set -uo pipefail

SH_VERSION="1.0.0"
DEFAULT_ADDR="0000:00:02.0"

# ====================== 终端配色（全脚本共用，勿改函数名/变量名） ======================
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

# ====================== 日志函数（错误走 stderr） ======================
log_info()  { echo -e "${gl_lan}[信息]${gl_bai} $*"; }
log_ok()    { echo -e "${gl_lv}[成功]${gl_bai} $*"; }
log_warn()  { echo -e "${gl_huang}[警告]${gl_bai} $*"; }
log_error() { echo -e "${gl_hong}[错误]${gl_bai} $*" >&2; }

# ====================== 工具函数（核心集，与共有函数库保持一致） ======================
# 小数秒休眠：部分系统 sleep 不支持小数，逐级回退到 perl / python / awk 取整
sleep_fractional() {
    local seconds=$1
    if sleep "$seconds" 2>/dev/null; then return 0; fi
    if command -v perl >/dev/null 2>&1; then perl -e "select(undef, undef, undef, $seconds)"; return 0; fi
    if command -v python3 >/dev/null 2>&1; then python3 -c "import time; time.sleep($seconds)"; return 0; fi
    if command -v python >/dev/null 2>&1; then python -c "import time; time.sleep($seconds)"; return 0; fi
    local int_seconds=$(echo "$seconds" | awk '{print int($1+0.999)}')
    sleep "$int_seconds"
}

# 操作完成后的按任意键继续（交互场景备用）
break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n 1 -s -r -p ""
    echo ""
    clear
}

# 正常退出统一入口：spinner 动画 + exit 0，禁止裸 exit 0
# 检测脚本默认不调用，避免清屏导致检测结果丢失
exit_script() {
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local dots=(
        "${gl_hong}."
        "${gl_huang}."
        "${gl_lv}."
        "${gl_bufan}."
        "${gl_zi}."
    )
    local dot_buffer=""
    local frame_len=${#frames[@]}
    local dot_idx=0
    local total_dots=${#dots[@]}

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

# ====================== 全局检测结果（统一初始化，兼容 set -u） ======================
PCI_ADDR="$DEFAULT_ADDR"
MATCH_KEY="00:02"
SRIOV_PATH=""
TOTALVFS_PATH=""
MDEV_DIR="/sys/bus/mdev/devices"
CMDLINE=""
DMESG_LOG=""
LSMOD_OUT=""
LSPCI_OUT=""
KDRV=""
KMODS=""
IOMMU_ENABLED=0
IOMMU_SOURCE="未检测到"
VFIO_LOADED=0
BL_XE=0
BL_I915=0
BL_SRC="无"
VFS=0
TOTAL_VFS=""
MDEV_LIST=""
GVT_TYPES=""
HOSTPCI_MATCH=""
PVE_NODE=0

# ====================== 输出排版 ======================
print_line() {
    echo -e "${gl_bufan}————————————————————————————————————————————————————————————————————————${gl_bai}"
}

section() {
    echo -e "\n${gl_lv}[$1] $2${reset}"
}

print_banner() {
    local kernel_ver
    kernel_ver=$(uname -r 2>/dev/null || true)
    [ -n "$kernel_ver" ] || kernel_ver="未知"
    echo -e "${gl_zi}>>> PVE 核显直通检测 v${SH_VERSION}${gl_bai}"
    print_line
    log_info "检测对象 : ${gl_lan}${PCI_ADDR}${gl_bai}"
    log_info "内核版本 : ${gl_lan}${kernel_ver}${gl_bai}"
    if [ "$EUID" -eq 0 ]; then
        log_info "运行身份 : ${gl_lv}root${gl_bai}"
    else
        log_info "运行身份 : ${gl_huang}非 root${gl_bai}"
    fi
    print_line
}

show_help() {
    echo -e "${gl_zi}>>> PVE 核显直通检测 v${SH_VERSION}${gl_bai}"
    print_line
    echo -e "${gl_bai}用法  : bash pve_igpu_passthru_info.sh [选项] [PCI地址]${reset}"
    echo -e "${gl_bai}参数  : ${gl_lan}-a, --addr${gl_bai}    指定核显 PCI 地址（默认 ${DEFAULT_ADDR}）${reset}"
    echo -e "${gl_bai}        ${gl_lan}-h, --help${gl_bai}    显示本帮助${reset}"
    echo -e "${gl_bai}        ${gl_lan}-v, --version${gl_bai} 显示版本号${reset}"
    echo -e "${gl_bai}示例  : bash pve_igpu_passthru_info.sh${reset}"
    echo -e "${gl_bai}        bash pve_igpu_passthru_info.sh -a 0000:00:02.0${reset}"
    echo -e "${gl_bai}        bash pve_igpu_passthru_info.sh 00:02.0${reset}"
    echo -e "${gl_bai}远程  : bash <(curl -sSL gitee.com/meimolihan/cmdbox/raw/master/sh/pve_igpu_passthru_info.sh)${reset}"
    print_line
}

# ====================== 参数与环境 ======================
# 规范化 PCI 地址：支持 0000:00:02.0 与简写 00:02.0
normalize_addr() {
    local addr="${1:-$DEFAULT_ADDR}"
    if [[ ! "$addr" =~ ^([0-9a-fA-F]{4}:)?[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\.[0-7]$ ]]; then
        log_error "PCI 地址格式无效：${addr}（示例：0000:00:02.0）"
        return 1
    fi
    [[ "$addr" =~ ^[0-9a-fA-F]{4}: ]] || addr="0000:${addr}"
    PCI_ADDR="${addr,,}"
    MATCH_KEY="${PCI_ADDR#0000:}"
    MATCH_KEY="${MATCH_KEY%.*}"
    SRIOV_PATH="/sys/bus/pci/devices/${PCI_ADDR}/sriov_numvfs"
    TOTALVFS_PATH="/sys/bus/pci/devices/${PCI_ADDR}/sriov_totalvfs"
    return 0
}

# 运行环境预检：只读脚本不因缺命令而中断，逐项降级提示
check_env() {
    local cmd
    for cmd in lspci dmesg lsmod; do
        if ! command -v "$cmd" &>/dev/null; then
            log_warn "未检测到 ${cmd} 命令，相关检测项将降级显示"
        fi
    done
    if command -v qm &>/dev/null || [ -d /etc/pve/qemu-server ]; then
        PVE_NODE=1
    else
        log_warn "未检测到 PVE 环境，虚拟机 hostpci 核对项将跳过"
    fi
    if [ "$EUID" -ne 0 ]; then
        log_warn "建议以 root 运行，否则 dmesg / lspci -k 信息可能不完整"
    fi
    print_line
}

# 判断内核参数中是否存在某个完整键值，避免 intel_iommu=on 被误判为 iommu=pt
has_cmdline_param() {
    local key="$1" item
    for item in $CMDLINE; do
        [ "$item" = "$key" ] && return 0
    done
    return 1
}

# ====================== 信息采集 ======================
# 黑名单来源有二：内核参数 module_blacklist= 与 /etc/modprobe.d/*.conf
parse_blacklist() {
    local mods_csv="" item line kw mod rest
    local src_cmdline=0 src_modprobe=0

    for item in $CMDLINE; do
        case "$item" in
            module_blacklist=*)
                mods_csv+="${item#*=},"
                src_cmdline=1
                ;;
        esac
    done

    local conf_lines
    conf_lines=$(grep -hE '^[[:space:]]*(blacklist|install)[[:space:]]+(xe|i915)([[:space:]]|$)' /etc/modprobe.d/*.conf 2>/dev/null || true)
    if [ -n "$conf_lines" ]; then
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            read -r kw mod rest <<< "$line"
            case "$mod" in
                xe|i915) mods_csv+="${mod},"; src_modprobe=1 ;;
            esac
        done <<< "$conf_lines"
    fi

    if [ "$src_cmdline" -eq 1 ] && [ "$src_modprobe" -eq 1 ]; then
        BL_SRC="内核参数 + modprobe.d"
    elif [ "$src_cmdline" -eq 1 ]; then
        BL_SRC="内核参数"
    elif [ "$src_modprobe" -eq 1 ]; then
        BL_SRC="modprobe.d"
    fi

    # 逗号拆分放在最后，避免局部 IFS 影响上面的按空格分词
    local IFS=','
    for mod in $mods_csv; do
        case "$mod" in
            xe)   BL_XE=1 ;;
            i915) BL_I915=1 ;;
        esac
    done
}

collect_info() {
    CMDLINE=$(cat /proc/cmdline 2>/dev/null || true)

    # 先整体捕获再做匹配，规避 pipefail 下 grep -q 提前退出导致 dmesg SIGPIPE 的误判
    DMESG_LOG=$(dmesg 2>/dev/null || true)
    if [ -z "$DMESG_LOG" ] && command -v journalctl &>/dev/null; then
        DMESG_LOG=$(journalctl -k -b --no-pager 2>/dev/null || true)
    fi
    if grep -Eqi 'DMAR: IOMMU enabled|AMD-Vi: IOMMU enabled|IOMMU enabled|DMAR:.*DRHD' <<< "$DMESG_LOG"; then
        IOMMU_ENABLED=1
        IOMMU_SOURCE="内核日志"
    fi
    # sysfs 是更可靠的兜底：存在 /sys/class/iommu/* 说明内核已枚举 IOMMU 组
    if [ -d /sys/class/iommu ] && [ -n "$(ls -A /sys/class/iommu 2>/dev/null || true)" ]; then
        IOMMU_ENABLED=1
        IOMMU_SOURCE="sysfs / dmesg"
    fi

    LSMOD_OUT=$(lsmod 2>/dev/null || true)
    if grep -qE '^vfio' <<< "$LSMOD_OUT" || [ -d /sys/module/vfio_pci ]; then
        VFIO_LOADED=1
    fi

    if command -v lspci &>/dev/null; then
        LSPCI_OUT=$(lspci -nnk -s "$PCI_ADDR" 2>/dev/null || true)
    fi
    KMODS=$(awk '/Kernel modules:/ {sub(/^.*Kernel modules: /, ""); print; exit}' <<< "$LSPCI_OUT")
    # 驱动以 sysfs 软链接为准，lspci -k 作为兜底
    local drv_link="/sys/bus/pci/devices/${PCI_ADDR}/driver"
    if [ -L "$drv_link" ]; then
        KDRV=$(basename "$(readlink -f "$drv_link" 2>/dev/null || true)")
        if [ "$KDRV" = "." ] || [ "$KDRV" = "/" ]; then
            KDRV=""
        fi
    else
        KDRV=$(awk '/Kernel driver in use:/ {sub(/^.*Kernel driver in use: /, ""); print; exit}' <<< "$LSPCI_OUT")
    fi

    parse_blacklist

    if [ -f "$SRIOV_PATH" ]; then
        local raw_vfs
        raw_vfs=$(cat "$SRIOV_PATH" 2>/dev/null || true)
        if [[ "$raw_vfs" =~ ^[0-9]+$ ]]; then
            VFS=$((10#$raw_vfs))
        fi
    fi
    if [ -f "$TOTALVFS_PATH" ]; then
        TOTAL_VFS=$(cat "$TOTALVFS_PATH" 2>/dev/null || true)
    fi

    if [ -d "$MDEV_DIR" ]; then
        MDEV_LIST=$(ls -A "$MDEV_DIR" 2>/dev/null || true)
    fi
    local gvt_dir="/sys/bus/pci/devices/${PCI_ADDR}/mdev_supported_types"
    if [ -d "$gvt_dir" ]; then
        GVT_TYPES=$(ls -A "$gvt_dir" 2>/dev/null | tr '\n' ' ' || true)
    fi

    if [ -d /etc/pve/qemu-server ]; then
        local all_hostpci
        all_hostpci=$(grep -H '^hostpci[0-9]*:' /etc/pve/qemu-server/*.conf 2>/dev/null || true)
        HOSTPCI_MATCH=$(grep -F "$MATCH_KEY" <<< "$all_hostpci" || true)
    fi
}

# ====================== 分段检测输出 ======================
show_cmdline() {
    section 1 "内核启动参数"
    echo -e "${gl_bai}${CMDLINE:-无法读取 /proc/cmdline}${reset}"
}

show_iommu() {
    section 2 "IOMMU 状态"
    if [ "$IOMMU_ENABLED" -eq 1 ]; then
        log_ok "IOMMU（Intel VT-d / AMD-Vi）已启用 · 依据：${IOMMU_SOURCE}"
    else
        log_error "IOMMU 未启用，请先开启 VT-d / AMD-Vi 并配置内核参数"
    fi
    if has_cmdline_param "iommu=pt"; then
        log_ok "包含 iommu=pt（直通模式）"
    else
        log_warn "缺少 iommu=pt 参数"
    fi
    if has_cmdline_param "intel_iommu=on"; then
        log_info "已显式设置 intel_iommu=on"
    elif has_cmdline_param "amd_iommu=on"; then
        log_info "已显式设置 amd_iommu=on"
    fi
}

show_vfio() {
    section 3 "VFIO 模块"
    if [ "$VFIO_LOADED" -eq 1 ]; then
        log_ok "VFIO 模块已加载"
        local line
        while IFS= read -r line; do
            case "$line" in
                vfio*|iommufd*) echo -e "  ${gl_hui}${line}${reset}" ;;
            esac
        done <<< "$LSMOD_OUT"
    else
        log_error "VFIO 模块未加载（整卡直通需要 vfio-pci 接管设备）"
    fi
}

show_pci() {
    section 4 "核显 PCI 与当前驱动"
    if [ -n "$LSPCI_OUT" ]; then
        echo -e "${gl_bai}${LSPCI_OUT}${reset}"
    else
        log_warn "lspci 未查询到 ${PCI_ADDR}，请确认地址或用 -a 指定"
    fi
    log_info "当前驱动 : ${gl_lv}${KDRV:-未绑定}${reset}"
    [ -n "$KMODS" ] && log_info "可用模块 : ${gl_bai}${KMODS}${reset}"
}

show_blacklist() {
    section 5 "xe / i915 黑名单检查"
    if [ "$BL_XE" -eq 1 ] && [ "$BL_I915" -eq 1 ]; then
        log_ok "内核参数或 modprobe.d 已拉黑 xe + i915（来源：${BL_SRC}）"
    elif [ "$BL_XE" -eq 1 ]; then
        log_warn "仅拉黑 xe（来源：${BL_SRC}），i915 仍可能抢占核显"
    elif [ "$BL_I915" -eq 1 ]; then
        log_warn "仅拉黑 i915（来源：${BL_SRC}），xe 仍可能抢占核显"
    else
        log_info "未拉黑 xe / i915"
    fi
}

show_sriov() {
    section 6 "SR-IOV 检测"
    if [ -f "$SRIOV_PATH" ]; then
        log_info "sriov_numvfs = ${gl_lan}${VFS}${gl_bai}"
        [ -n "$TOTAL_VFS" ] && log_info "sriov_totalvfs（硬件上限） = ${gl_lan}${TOTAL_VFS}${gl_bai}"
        if [ "$VFS" -gt 0 ]; then
            log_ok "SR-IOV 虚拟功能 VF 已开启"
        else
            log_info "SR-IOV 已关闭（VFs=0）"
        fi
    else
        log_info "不存在 sriov_numvfs 配置项 / 未启用 SR-IOV"
    fi
}

show_mdev() {
    section 7 "mdev / GVT-g 媒介直通检测"
    if [ -n "$MDEV_LIST" ]; then
        log_ok "检测到 mdev 设备（可能是 GVT-g）"
        local uuid
        while IFS= read -r uuid; do
            [ -n "$uuid" ] && echo -e "  ${gl_hui}${uuid}${reset}"
        done <<< "$MDEV_LIST"
    else
        log_info "没有 mdev 媒介设备"
    fi
    if [ -n "$GVT_TYPES" ]; then
        log_info "GVT-g 支持类型 : ${gl_bai}${GVT_TYPES}${reset}"
    fi
}

show_vm_hostpci() {
    section 8 "PVE 虚拟机 hostpci 绑定"
    if [ "$PVE_NODE" -ne 1 ] && [ ! -d /etc/pve/qemu-server ]; then
        log_info "非 PVE 节点，跳过该检测项"
        return 0
    fi
    if [ -n "$HOSTPCI_MATCH" ]; then
        log_ok "以下虚拟机配置引用了 ${MATCH_KEY}（含 VF）"
        local line file vmid rest
        while IFS= read -r line; do
            [ -n "$line" ] || continue
            file="${line%%:*}"
            vmid=$(basename "$file" .conf)
            rest="${line#*:}"
            rest="${rest#*:}"
            echo -e "  ${gl_lan}VM ${vmid}${reset} ${gl_hui}${rest}${reset}"
        done <<< "$HOSTPCI_MATCH"
    else
        log_info "没有虚拟机配置引用 ${MATCH_KEY}"
    fi
}

# ====================== 最终判定 ======================
judge_passthru() {
    echo -e "\n${gl_hong}====== 最终判定 ======${reset}"
    local verdict="" detail=""

    case "$KDRV" in
        vfio-pci)
            if [ "$BL_XE" -eq 1 ] && [ "$BL_I915" -eq 1 ]; then
                verdict="整块核显 VFIO PCI 直通（非 SR-IOV、非 GVT-g）"
            else
                verdict="设备已绑定 vfio-pci，但未拉黑 xe/i915"
                detail="建议补 module_blacklist=xe,i915 并 update-initramfs -u，避免驱动抢占"
            fi
            ;;
        i915|xe)
            if [ "$VFS" -gt 0 ]; then
                verdict="SR-IOV PF 模式（宿主机持有主设备，VF 可分配给虚拟机）"
                [ -n "$MDEV_LIST" ] && detail="同时检测到 mdev 设备，请核对是否混用了 GVT-g"
            elif [ -n "$MDEV_LIST" ]; then
                verdict="GVT-g / mdev 媒介直通"
            else
                verdict="核显由宿主机 ${KDRV} 驱动占用，未做直通"
            fi
            ;;
        "")
            verdict="设备未绑定任何内核驱动（可能已 unbind，等待 vfio-pci 接管）"
            ;;
        *)
            verdict="直通方式未知，当前驱动：${KDRV}"
            ;;
    esac

    echo -e "${gl_zi}👉 直通方式：${gl_lv}${verdict}${reset}"
    [ -n "$detail" ] && log_warn "$detail"
    if [ "$IOMMU_ENABLED" -eq 0 ]; then
        log_warn "IOMMU 未启用，以上任何直通方式都无法正常工作"
    fi
    if [ "$KDRV" = "vfio-pci" ] && [ "$VFIO_LOADED" -eq 0 ]; then
        log_warn "驱动显示 vfio-pci 但 lsmod 未见 vfio 模块，请复核采集权限"
    fi
}

# ====================== 主入口 ======================
main() {
    local addr=""

    while [ "$#" -gt 0 ]; do
        case "$1" in
            -a|--addr)
                if [ "$#" -lt 2 ]; then
                    log_error "--addr 缺少参数值"
                    return 1
                fi
                addr="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                return 0
                ;;
            -v|--version)
                echo -e "${gl_bufan}pve_igpu_passthru_info.sh${gl_bai} 版本 ${gl_lv}v${SH_VERSION}${gl_bai}"
                return 0
                ;;
            -*)
                log_error "未知参数：$1"
                show_help
                return 1
                ;;
            *)
                if [ -z "$addr" ]; then
                    addr="$1"
                else
                    log_warn "忽略多余参数：$1"
                fi
                shift
                ;;
        esac
    done

    normalize_addr "$addr" || return 1

    print_banner
    check_env
    collect_info
    show_cmdline
    show_iommu
    show_vfio
    show_pci
    show_blacklist
    show_sriov
    show_mdev
    show_vm_hostpci
    judge_passthru
    print_line
    log_ok "检测完成（只读检测，未修改任何系统配置）"
    return 0
}

main "$@"
