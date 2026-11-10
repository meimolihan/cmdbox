#!/bin/bash
set -uo pipefail

# ============================================================
# PVE 一键构建带 Cloud-Init 的 Ubuntu 24.04 云镜像模板
# 运行位置：Proxmox VE 7.x / 8.x 宿主机，必须 root
# 运行契约：自包含、不 source 外部库、不依赖工作目录、拉取即用
# 主要流程：下载 cloud image -> qm create -> qm importdisk -> qm set
#           -> Cloud-Init 注入用户/公钥/网络 -> qm template -> 可选克隆
# ============================================================

# ==== BOILERPLATE:FUNCS:START ====
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

# ====================== 工具函数 ======================
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

# 表格输出：有 column 命令就对齐，没有就原样输出
column_if_available() {
    if command -v column &> /dev/null; then
        column -t -s $'\t'
    else
        cat
    fi
}

# 操作完成后的按任意键继续
break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n 1 -s -r -p ""
    echo ""
    clear
}

# 返回上一级选单的过渡提示
cancel_return() {
    local menu_name="${1:-上一级选单}"
    echo -ne "${gl_lv}即将返回到 ${gl_huang}${menu_name}${gl_lv} ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    sleep_fractional 0.6
    echo ""
    clear
}

# 短退场动画（不退出进程，用于函数内返回）
exit_animation() {
    echo -ne "${gl_lv}即将退出 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo ""
    clear
}

# 正常退出统一入口：spinner 动画 + exit 0，禁止裸 exit 0
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

# 非法输入提示（内部用 continue，只能在 while/case 循环中调用）
handle_invalid_input() {
    echo -ne "\r\033[K${gl_huang}无效的输入,请重新输入! ${gl_zi} 1 ${gl_huang} 秒后返回"
    sleep_fractional 1
    echo -ne "\r\033[K${gl_lv}无效的输入,请重新输入! ${gl_zi}0${gl_lv} 秒后返回"
    sleep_fractional 0.5
    echo -ne "\r\033[K"
    continue
}

# y/N 输入非法提示（返回 2，由调用方重来）
handle_y_n() {
    echo -e "${gl_hong}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai})${gl_hong}。${gl_bai}"
    sleep 1
    echo -e "${gl_huang}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai})${gl_huang}。${gl_bai}"
    sleep 1
    echo -e "${gl_lv}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai})${gl_lv}。${gl_bai}"
    sleep 0.5
    return 2
}

# ====================== Docker Compose 统一调用（先旧命令，后插件） ======================
# 不要写死 docker-compose 或 docker compose：两类环境都要能跑。
docker_compose_run() {
    local yml_file="$1"; shift
    local out ret
    if command -v docker-compose &>/dev/null; then
        out=$(docker-compose -f "$yml_file" "$@" 2>&1); ret=$?
    elif docker compose version &>/dev/null 2>&1; then
        out=$(docker compose -f "$yml_file" "$@" 2>&1); ret=$?
    else
        log_error "未找到 docker-compose / docker compose 命令"
        return 1
    fi
    [[ -n "$out" ]] && echo "$out"
    return $ret
}
# ==== BOILERPLATE:FUNCS:END ====

# ====================== 默认参数 ======================
TPL_ID=9000
TPL_NAME="tpl-ubuntu2404"
STORAGE="local-lvm"                   # 默认值；pvesm 探测到不存在时自动切换
STORAGE_EXPLICIT=0                    # 是否用 --storage 显式指定
STORAGE_NOTE=""                       # 存储来源说明，打印在结果摘要里
BRIDGE="vmbr0"
MEMORY=2048
CORES=2
IMAGE_DIR="/var/lib/vz/template/iso"
IMAGE_FILE="noble-server-cloudimg-amd64.img"
IMAGE_URL="https://cloud-images.ubuntu.com/noble/current/${IMAGE_FILE}"
CI_USER="ubuntu"
SSH_PUBKEY="${HOME}/.ssh/id_ed25519.pub"
IPCONFIG="ip=dhcp"
CLONE_ID=""
CLONE_NAME=""
CLONE_IP="ip=dhcp"
LINKED_CLONE=0
ASSUME_YES=0
CLEANUP=0                            # 是否允许清理上次导入失败留下的空壳 VM
IMG_PATH=""
KEY_EXPLICIT=0                        # 是否用 --key 显式指定了公钥路径
NO_KEY_GEN=0                          # 是否禁止自动生成密钥对
KEY_NOTE=""                           # 公钥来源说明，打印在结果摘要里

# ====================== 帮助信息 ======================
usage() {
    cat <<'EOF'
用法：bash pve_cloud_init_tpl.sh [选项]

在 PVE 宿主机上一键构建 Ubuntu 24.04 (Noble) Cloud-Init 模板。
版本标记：storage-fix-20261110 / cleanup-fix-20261110（含存储自动探测 + 半成品清理）

  --id <VM_ID>            模板 VMID（默认 9000）
  --name <NAME>           模板名称（默认 tpl-ubuntu2404）
  --storage <STORAGE>     磁盘目标存储（默认自动探测：优先 local-lvm；
                          单盘 / 已把 local-lvm 合并进 local 的宿主机自动切到 local）
  --bridge <BRIDGE>       网卡桥接（默认 vmbr0）
  --memory <MB>           内存 MB（默认 2048）
  --cores <N>             CPU 核数（默认 2）
  --image-dir <DIR>       cloud image 存放目录
  --image <FILE>          cloud image 文件名
  --user <USER>           Cloud-Init 默认用户（默认 ubuntu）
  --key <PUBKEY>          SSH 公钥文件路径（默认 ~/.ssh/id_ed25519.pub）
                          缺失时自动生成一对 ed25519；推荐换成自己工作站的公钥
  --no-key-gen            禁止自动生成密钥对，公钥缺失直接报错
  --cleanup               VMID 被上次导入失败的空壳 VM 占用时，核实配置后清理再继续
                          仅删「无任何磁盘且名称匹配」的半成品，正常 VM 一律拒绝
  --ipconfig <CFG>        模板网络配置，勿写死 IP（默认 ip=dhcp）
  --clone <VM_ID>         构建后顺带克隆出一台实例
  --clone-name <NAME>     克隆实例名称（默认 vm-<VM_ID>）
  --clone-ip <CFG>        克隆实例 IP / 网关（默认 ip=dhcp）
  --linked                链接克隆（默认完整克隆 --full 1）
  -y, --yes               跳过二次确认，适合批量脚本
  -h, --help              显示本帮助

示例：
  bash pve_cloud_init_tpl.sh -y
  # 单盘安装，或已把 local-lvm 合并进 local 的宿主机
  bash pve_cloud_init_tpl.sh -y --storage local
  # 上次 importdisk 失败留下空壳 VM 9000，核实后自动清理再继续
  bash pve_cloud_init_tpl.sh -y --storage local --cleanup
  bash pve_cloud_init_tpl.sh -y --clone 101 --clone-name web01 \
       --clone-ip ip=10.0.0.21/24,gw=10.0.0.1
EOF
}

# ====================== 参数解析 ======================
need_val() {
    if [[ $# -lt 2 || -z "${2:-}" ]]; then
        log_error "参数 $1 缺少取值"
        return 1
    fi
    return 0
}

parse_args() {
    while (($#)); do
        case "$1" in
            --id)         need_val "$@" || return 1; TPL_ID="$2";         shift 2 ;;
            --name)       need_val "$@" || return 1; TPL_NAME="$2";       shift 2 ;;
            --storage)    need_val "$@" || return 1; STORAGE="$2"; STORAGE_EXPLICIT=1; shift 2 ;;
            --bridge)     need_val "$@" || return 1; BRIDGE="$2";         shift 2 ;;
            --memory)     need_val "$@" || return 1; MEMORY="$2";         shift 2 ;;
            --cores)      need_val "$@" || return 1; CORES="$2";          shift 2 ;;
            --image-dir)  need_val "$@" || return 1; IMAGE_DIR="$2";      shift 2 ;;
            --image)      need_val "$@" || return 1; IMAGE_FILE="$2";     shift 2 ;;
            --user)       need_val "$@" || return 1; CI_USER="$2";        shift 2 ;;
            --key)        need_val "$@" || return 1; SSH_PUBKEY="$2"; KEY_EXPLICIT=1; shift 2 ;;
            --no-key-gen) NO_KEY_GEN=1; shift ;;
            --cleanup)    CLEANUP=1; shift ;;
            --ipconfig)   need_val "$@" || return 1; IPCONFIG="$2";       shift 2 ;;
            --clone)      need_val "$@" || return 1; CLONE_ID="$2";       shift 2 ;;
            --clone-name) need_val "$@" || return 1; CLONE_NAME="$2";     shift 2 ;;
            --clone-ip)   need_val "$@" || return 1; CLONE_IP="$2";       shift 2 ;;
            --linked)     LINKED_CLONE=1; shift ;;
            -y|--yes)     ASSUME_YES=1; shift ;;
            -h|--help)    usage; return 2 ;;
            *)            log_error "未知参数：$1"; usage; return 1 ;;
        esac
    done
    if [[ ! "$TPL_ID" =~ ^[0-9]+$ ]]; then
        log_error "模板 VMID 必须是数字：$TPL_ID"
        return 1
    fi
    if [[ -n "$CLONE_ID" && ! "$CLONE_ID" =~ ^[0-9]+$ ]]; then
        log_error "克隆 VMID 必须是数字：$CLONE_ID"
        return 1
    fi
    # 自定义镜像文件名时同步推导下载地址，避免仍拉 Noble 默认镜像
    if [[ "$IMAGE_FILE" != "noble-server-cloudimg-amd64.img" ]]; then
        IMAGE_URL="https://cloud-images.ubuntu.com/noble/current/${IMAGE_FILE}"
    fi
    return 0
}

# ====================== 危险操作二次确认（y/N，默认否） ======================
confirm() {
    local prompt="$1" answer="" i=0
    if [[ "$ASSUME_YES" -eq 1 ]]; then
        log_info "${prompt}（-y 已跳过确认）"
        return 0
    fi
    while (( i < 3 )); do
        read -r -e -p "${gl_huang}${prompt}${gl_bai} (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}) " answer
        case "${answer,,}" in
            y|yes)     return 0 ;;
            n|no|"")   return 1 ;;
            *)         handle_y_n || true; ((i++)) ;;
        esac
    done
    return 1
}

# ====================== 准备 SSH 公钥 ======================
# PVE 宿主机（尤其新装的 root）通常没有 ~/.ssh/id_ed25519.pub，
# 而 qm set --sshkeys <filepath> 必须指向一个真实存在的公钥文件。
# 三级兜底：现有公钥 -> 从同名私钥导出 -> 生成一对新密钥（仅默认路径允许）。
prepare_ssh_pubkey() {
    local priv="" key_dir

    # 1. 公钥已存在且非空：只做形态提示，不因首行格式不同就误判为无效
    if [[ -s "$SSH_PUBKEY" ]]; then
        if ! grep -qE '^(ssh-|ecdsa-|sk-)' "$SSH_PUBKEY"; then
            log_warn "${SSH_PUBKEY} 内容不像 OpenSSH 公钥，仍按原文件交给 qm set"
        fi
        KEY_NOTE="现有公钥 ${SSH_PUBKEY}"
        log_ok "使用现有 SSH 公钥：${SSH_PUBKEY}"
        return 0
    fi

    # 空文件会挡住 ssh-keygen 生成 .pub，先清掉（只删零字节文件）
    if [[ -e "$SSH_PUBKEY" ]]; then
        rm -f "$SSH_PUBKEY"
    fi

    # 2. 公钥丢了但私钥还在：ssh-keygen -y 从私钥导出，不动私钥本身
    [[ "$SSH_PUBKEY" == *.pub ]] && priv="${SSH_PUBKEY%.pub}"
    if [[ -n "$priv" && -r "$priv" ]]; then
        log_info "公钥缺失，但发现私钥 ${priv}，尝试导出公钥"
        if command -v ssh-keygen >/dev/null 2>&1 \
            && ssh-keygen -y -f "$priv" </dev/null > "$SSH_PUBKEY" 2>/dev/null \
            && grep -qE '^(ssh-|ecdsa-|sk-)' "$SSH_PUBKEY"; then
            chmod 644 "$SSH_PUBKEY" 2>/dev/null || true
            KEY_NOTE="由私钥导出的公钥 ${SSH_PUBKEY}"
            log_ok "已从私钥导出公钥：${SSH_PUBKEY}"
            return 0
        fi
        log_warn "从私钥导出失败（可能带口令），改走生成新密钥对"
    fi

    # 3. 显式 --key 指向的路径不该被脚本偷偷改写，直接报错更可预期
    if [[ "$KEY_EXPLICIT" -eq 1 ]]; then
        log_error "--key 指定的公钥不存在：${SSH_PUBKEY}"
        log_error "请把公钥放到该路径，或去掉 --key 让脚本自动生成"
        return 1
    fi
    if [[ "$NO_KEY_GEN" -eq 1 ]]; then
        log_error "公钥缺失且已启用 --no-key-gen；请用 --key 指定一个公钥文件"
        return 1
    fi
    if ! command -v ssh-keygen >/dev/null 2>&1; then
        log_error "缺少 ssh-keygen 且没有可用公钥；请用 --key 指定公钥文件"
        return 1
    fi
    if [[ -e "$priv" ]]; then
        log_error "私钥 ${priv} 存在但无法导出公钥（可能带口令），为避免覆盖，请用 --key 指定公钥"
        return 1
    fi
    # 默认路径必以 .pub 结尾；这里兜底，保证 key_dir / -f 永远有值
    [[ -z "$priv" ]] && priv="${SSH_PUBKEY}_key"

    key_dir=$(dirname "$priv")
    mkdir -p "$key_dir" && chmod 700 "$key_dir" || {
        log_error "无法创建密钥目录 ${key_dir}"; return 1
    }
    if ! confirm "未找到 ${SSH_PUBKEY}，是否生成一对新的 ed25519 密钥？"; then
        log_error "已取消；请把你的公钥放到 ${SSH_PUBKEY}，或用 --key 指定"
        return 1
    fi
    # -N "" 空口令 + -q 静默；</dev/null 避免任何意外交互卡住
    if ! ssh-keygen -t ed25519 -f "$priv" -N "" -q \
        -C "pve-cloudinit@$(hostname)" </dev/null; then
        log_error "生成密钥对失败：${priv}"
        return 1
    fi
    chmod 600 "$priv" 2>/dev/null || true
    chmod 644 "$SSH_PUBKEY" 2>/dev/null || true
    if [[ ! -s "$SSH_PUBKEY" ]]; then
        log_error "密钥已生成但公钥文件为空：${SSH_PUBKEY}"
        return 1
    fi
    KEY_NOTE="新生成的密钥对 ${priv}（私钥在 PVE 宿主机上）"
    log_ok "已生成密钥对：${priv} / ${SSH_PUBKEY}"
    log_warn "模板注入的是宿主机新公钥：从工作站直连需改用 --key 指向自己的公钥，或用 ssh -i ${priv} <USER>@<IP> 登录"
    return 0
}

# ====================== 存储探测与卷名解析 ======================
# pvesm status --content images 只列支持 VM 磁盘映像的存储（PVE 手册 --content 选项）。
# 老版本不支持该选项、或返回空表时，退回全量 pvesm status；第一列是存储名，NR>1 跳过表头。
list_image_storages() {
    local out names
    out=$(pvesm status --content images 2>/dev/null) || out=""
    names=$(printf '%s\n' "$out" | awk 'NR>1 && $1 != "" {print $1}' | sort -u)
    if [[ -z "$names" ]]; then
        out=$(pvesm status 2>/dev/null) || out=""
        names=$(printf '%s\n' "$out" | awk 'NR>1 && $1 != "" {print $1}' | sort -u)
    fi
    printf '%s\n' "$names"
}

# 默认 local-lvm 在「local-lvm 合并进 local」的单盘宿主机上并不存在。
# 显式 --storage 校验失败必须硬中止，避免 qm create 成功却导入失败留下残留 VM。
resolve_storage() {
    STORAGE_NOTE="显式指定 ${STORAGE}"
    if ! command -v pvesm >/dev/null 2>&1; then
        log_warn "未找到 pvesm，跳过存储校验：${STORAGE}"
        STORAGE_NOTE="未校验（pvesm 不可用）${STORAGE}"
        return 0
    fi
    local avail picked images_out
    avail=$(list_image_storages)
    if [[ -z "$avail" ]]; then
        log_warn "pvesm status 未返回任何存储，跳过校验：${STORAGE}（请自行确认存储名）"
        STORAGE_NOTE="未校验（pvesm 无输出）${STORAGE}"
        return 0
    fi
    if grep -qxF "$STORAGE" <<< "$avail"; then
        log_ok "目标存储可用：${STORAGE}"
        STORAGE_NOTE="探测确认 ${STORAGE}"
    elif [[ "$STORAGE_EXPLICIT" -eq 1 ]]; then
        log_error "存储 ${STORAGE} 不存在（--storage 显式指定，不自动替换）"
        log_warn "当前可用存储：$(echo "$avail" | tr '\n' ' ')"
        return 1
    else
        # 优先级：local（合并后的 dir 存储）> local-zfs > local-lvm > 列表第一个
        for picked in local local-zfs local-lvm; do
            grep -qxF "$picked" <<< "$avail" && break
        done
        grep -qxF "$picked" <<< "$avail" || picked=$(echo "$avail" | head -1)
        log_warn "默认存储 ${STORAGE} 不存在，自动切换到 ${picked}"
        log_warn "可用存储：$(echo "$avail" | tr '\n' ' ')；如需固定请显式 --storage ${picked}"
        STORAGE="$picked"
        STORAGE_NOTE="自动探测 ${STORAGE}（原默认 local-lvm 不存在）"
    fi
    # 合并存储常忘记给 local 补 images 内容类型，提前提示，别等 importdisk 才报错
    images_out=$(pvesm status --content images 2>/dev/null | awk 'NR>1 && $1 != "" {print $1}')
    if [[ -n "$images_out" ]] && ! grep -qxF "$STORAGE" <<< "$images_out"; then
        log_warn "存储 ${STORAGE} 未启用 images 内容类型；若导入报 content type 错，请在 /etc/pve/storage.cfg 补 images"
    fi
    return 0
}

# qm importdisk 的真实卷 ID 因存储类型而异，绝不能硬拼：
#   lvmthin / lvm / zfs : 'local-lvm:vm-9000-disk-0'
#   dir（合并后的 local）: 'local:9000/vm-9000-disk-0.raw' —— 带子目录和扩展名
extract_imported_vol() {
    local out="$1" vol=""
    vol=$(printf '%s\n' "$out" | sed -n "s/.*Successfully imported disk as '\([^']*\)'.*/\1/p" | tail -1)
    if [[ -n "$vol" ]]; then printf '%s\n' "$vol"; return 0; fi
    # 输出里的卷 ID 优先于 pvesm list 查表：后者可能返回同 VMID 的旧卷
    vol=$(printf '%s\n' "$out" | grep -oE "[A-Za-z0-9_.+-]+:[^ '\"]*vm-${TPL_ID}-disk-[0-9]+[^ '\"]*" | tail -1)
    if [[ -n "$vol" ]]; then printf '%s\n' "$vol"; return 0; fi
    if command -v pvesm >/dev/null 2>&1; then
        vol=$(pvesm list "$STORAGE" 2>/dev/null | awk -v id="vm-${TPL_ID}-disk-" 'index($1,id) {print $1; exit}')
    fi
    if [[ -n "$vol" ]]; then printf '%s\n' "$vol"; return 0; fi
    printf '%s\n' "${STORAGE}:vm-${TPL_ID}-disk-0"
    log_warn "未能解析导入卷名，回退使用 ${STORAGE}:vm-${TPL_ID}-disk-0（dir 存储请确认卷 ID 是否带子目录）" >&2
    return 1
}

# ====================== 半成品 VM 清理 ======================
# qm importdisk 失败时 qm create 已经成功，VMID 被一个「没有任何磁盘」的空壳占用。
# 严格判据：qm config 里不能出现任何磁盘类键。注意 scsihw 是控制器类型，不算磁盘。
is_empty_shell_vm() {
    local cfg="$1" line key
    while IFS= read -r line; do
        key="${line%%:*}"
        key="${key//[[:space:]]/}"
        if [[ "$key" =~ ^(scsi[0-9]+|sata[0-9]+|virtio[0-9]+|ide[0-9]+|efidisk[0-9]+|tpmstate[0-9]+|unused[0-9]+)$ ]]; then
            return 1
        fi
    done <<< "$cfg"
    return 0
}

# 只删脚本自己上次留下的空壳：打印完整配置 -> 双判据核实 -> 二次确认 -> 最小化 qm destroy。
# 按 qm(1) 手册，qm destroy 默认已清理 used/owned volumes；不加 --destroy-unreferenced-disks
# （会扫描所有 enabled storages 删同 VMID 的未引用磁盘，最容易误删数据），也不加 --skiplock。
cleanup_stale_vm() {
    local cfg
    cfg=$(qm config "$TPL_ID" --current 1 2>/dev/null) || cfg=$(qm config "$TPL_ID" 2>/dev/null) || {
        log_error "无法读取 VM ${TPL_ID} 配置，拒绝清理"
        return 1
    }
    log_warn "VMID ${TPL_ID} 已存在，当前配置如下（请核实）："
    printf '%s\n' "$cfg" | sed 's/^/    /'
    if ! is_empty_shell_vm "$cfg"; then
        log_error "该 VM 已挂有磁盘，不是导入失败的半成品，拒绝清理"
        log_warn "请改用 --id <其它 VMID>，或自行确认后手工处理"
        return 1
    fi
    if ! grep -qF "name: ${TPL_NAME}" <<< "$cfg"; then
        log_error "VM 名称与模板名 ${TPL_NAME} 不符，拒绝清理"
        log_warn "请改用 --id <其它 VMID>，或自行确认后手工处理"
        return 1
    fi
    confirm "确认这是上次导入失败的空壳 VM ${TPL_ID}，删除它并继续？" || return 1
    qm destroy "$TPL_ID" || { log_error "qm destroy ${TPL_ID} 失败，请手工检查"; return 1; }
    log_ok "已清理半成品 VM ${TPL_ID}，继续构建"
    return 0
}

# ====================== 前置检查 ======================
preflight() {
    if [[ "$(id -u)" -ne 0 ]]; then
        log_error "请在 PVE 宿主机上以 root 运行"
        return 1
    fi
    if ! command -v qm >/dev/null 2>&1; then
        log_error "未找到 qm 命令，本脚本只能在 Proxmox VE 宿主机执行"
        return 1
    fi
    if qm status "$TPL_ID" >/dev/null 2>&1; then
        log_error "VMID ${TPL_ID} 已被占用（脚本不会覆盖已有虚拟机）"
        if [[ "$CLEANUP" -eq 1 ]]; then
            cleanup_stale_vm || return 1
        else
            # 上一次 importdisk 失败会留下半成品 VM，用户重跑时最容易卡在这一关
            log_warn "若是上次导入失败的残留：qm config ${TPL_ID} 核实后 qm destroy ${TPL_ID}"
            log_warn "或加 --cleanup，脚本核实为「无磁盘空壳」后自动清理再继续"
            return 1
        fi
    fi
    resolve_storage || return 1
    log_ok "前置检查通过（root / qm 就绪、VMID ${TPL_ID} 空闲、存储 ${STORAGE}）"
    return 0
}

# ====================== 下载 cloud image ======================
download_image() {
    IMG_PATH="${IMAGE_DIR}/${IMAGE_FILE}"
    mkdir -p "$IMAGE_DIR" || { log_error "无法创建目录 ${IMAGE_DIR}"; return 1; }
    if [[ -s "$IMG_PATH" ]]; then
        log_ok "cloud image 已存在，跳过下载：${IMG_PATH}"
        return 0
    fi
    log_info "开始下载 ${IMAGE_URL}"
    if command -v wget >/dev/null 2>&1; then
        wget -c -O "$IMG_PATH" "$IMAGE_URL" || { log_error "cloud image 下载失败"; return 1; }
    elif command -v curl >/dev/null 2>&1; then
        curl -fL -o "$IMG_PATH" "$IMAGE_URL" || { log_error "cloud image 下载失败"; return 1; }
    else
        log_error "缺少 wget / curl，请先安装或手动把镜像放到 ${IMG_PATH}"
        return 1
    fi
    [[ -s "$IMG_PATH" ]] || { log_error "下载得到的镜像为空文件：${IMG_PATH}"; return 1; }
    log_ok "cloud image 下载完成：${IMG_PATH}"
    return 0
}

# ====================== 构建模板 ======================
build_template() {
    log_info "即将创建模板 VM ${TPL_ID} (${TPL_NAME})，磁盘写入 ${STORAGE}"
    if ! confirm "确认创建模板虚拟机并导入磁盘？"; then
        log_warn "已取消，未做任何改动"
        return 1
    fi

    # 1. 创建空壳 VM：VirtIO 网卡 + virtio-scsi-pci 控制器
    qm create "$TPL_ID" \
        --name "$TPL_NAME" \
        --memory "$MEMORY" \
        --cores "$CORES" \
        --net0 "virtio,bridge=${BRIDGE}" \
        --scsihw virtio-scsi-pci \
        --ostype l26 || { log_error "qm create 失败"; return 1; }

    # 2. 导入 cloud image；卷 ID 从输出解析（dir 存储带子目录，不能硬拼）
    local imported vol
    imported=$(qm importdisk "$TPL_ID" "$IMG_PATH" "$STORAGE" 2>&1) || {
        log_error "qm importdisk 失败：${imported}"
        log_warn "VM ${TPL_ID} 已创建但未挂载磁盘；重跑前请先清理：qm destroy ${TPL_ID}"
        return 1
    }
    log_info "${imported}"
    vol=$(extract_imported_vol "$imported")
    log_info "解析到导入卷：${vol}"

    # 3. 挂载磁盘（discard + SSD 标记）、Cloud-Init 配置盘、设定启动顺序
    qm set "$TPL_ID" \
        --scsi0 "${vol},discard=on,ssd=1" \
        --ide2 "${STORAGE}:cloudinit" \
        --boot order=scsi0 || { log_error "qm set 磁盘 / 启动顺序失败"; return 1; }

    # 4. 串口控制台：cloud 镜像无图形界面
    qm set "$TPL_ID" --serial0 socket --vga serial0 || { log_error "qm set 串口控制台失败"; return 1; }

    # 5. Cloud-Init 注入用户名 / SSH 公钥 / 网络（模板里不写死 IP）
    qm set "$TPL_ID" \
        --ciuser "$CI_USER" \
        --sshkeys "$SSH_PUBKEY" \
        --ipconfig0 "$IPCONFIG" || { log_error "qm set Cloud-Init 参数失败"; return 1; }

    # 6. 标记 guest agent（旧版 PVE 不支持时只告警，不中断构建）
    if ! qm set "$TPL_ID" --agent enabled=1 >/dev/null 2>&1; then
        log_warn "当前 PVE 版本不支持 --agent enabled=1，已跳过；需在镜像内自行安装 qemu-guest-agent"
    fi

    # 7. 转为模板；模板本身不要启动，它只是母镜像
    qm template "$TPL_ID" || { log_error "qm template 失败"; return 1; }
    log_ok "模板已生成：${TPL_ID} (${TPL_NAME})"
    return 0
}

# ====================== 可选：克隆并启动一台实例 ======================
clone_from_template() {
    [[ -z "$CLONE_ID" ]] && return 0
    if qm status "$CLONE_ID" >/dev/null 2>&1; then
        log_error "目标 VMID ${CLONE_ID} 已被占用，跳过克隆"
        return 1
    fi
    local full=1 clone_name="${CLONE_NAME:-vm-${CLONE_ID}}"
    [[ "$LINKED_CLONE" -eq 1 ]] && full=0

    qm clone "$TPL_ID" "$CLONE_ID" --name "$clone_name" --full "$full" || {
        log_error "qm clone 失败"; return 1
    }
    qm set "$CLONE_ID" --ipconfig0 "$CLONE_IP" || { log_error "设置克隆机 IP 失败"; return 1; }
    qm start "$CLONE_ID" || { log_error "启动克隆机失败"; return 1; }
    log_ok "已启动克隆机 ${CLONE_ID} (${clone_name})，等待 cloud-init 首启完成后即可 SSH"
    return 0
}

# ====================== 结果摘要 ======================
print_summary() {
    echo ""
    echo -e "${gl_zi}>>> 模板信息${gl_bai}"
    echo -e "${gl_bufan}——————————————————————————————${gl_bai}"
    echo -e "  VMID / 名称 : ${gl_lan}${TPL_ID}${gl_bai} / ${TPL_NAME}"
    echo -e "  存储 / 网桥 : ${STORAGE} / ${BRIDGE}"
    echo -e "  存储来源    : ${STORAGE_NOTE}"
    echo -e "  默认用户    : ${CI_USER}"
    echo -e "  公钥        : ${SSH_PUBKEY}"
    echo -e "  公钥来源    : ${KEY_NOTE}"
    echo -e "  网络配置    : ${IPCONFIG}"
    echo ""
    echo -e "${gl_zi}>>> 克隆示例${gl_bai}"
    echo -e "${gl_bufan}——————————————————————————————${gl_bai}"
    echo -e "  qm clone ${TPL_ID} 101 --name web01 --full 1"
    echo -e "  qm set 101 --ipconfig0 ip=10.0.0.21/24,gw=10.0.0.1"
    echo -e "  qm start 101"
    echo -e "  ssh ${CI_USER}@10.0.0.21"
    echo ""
    log_warn "模板保持关机；链接克隆依赖母盘，母盘不可删除"
}

# ====================== 主流程 ======================
main() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        usage
        return 0
    fi
    parse_args "$@" || return 1
    preflight || return 1
    prepare_ssh_pubkey || return 1     # 公钥三级兜底，必须在 qm set --sshkeys 之前
    download_image || return 1
    build_template || return 1
    clone_from_template || return 1
    print_summary
    # 正常结束用 return 0：避免 exit_script 的清屏动画吞掉上面的构建摘要
    return 0
}

main "$@"
