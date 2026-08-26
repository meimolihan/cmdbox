#!/usr/bin/env bash

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


sep_line() {
  printf '%s' "$gl_bufan"
  printf '—%.0s' {1..32}
  printf '%s\n' "$reset"
}


section() {
  printf "  %s %s\n" "${gl_zi}▶${reset}" "$1"
}


ok() {
  printf "  %s %s\n" "${gl_lv}>>>${reset}" "$1"
}


warn() {
  printf "  %s %s\n" "${gl_huang}[警告]${reset}" "$1"
}


error() { printf "  %s %s\n" "${gl_hong}[错误]${reset}" "$1" >&2; exit 1; }


print_banner() {
  local z="$gl_zi" r="$reset" b="$gl_bai"
  printf '%s\n' \
    "${z}  ___  ___   ___  ___  _   _  ___ ___${r}" \
    "${z} / _ \\/ __| / __|| __|| | | || __| _ \\${r}" \
    "${z}| | | | (__ | (__ | _| | |_| || _||   /${r}" \
    "${z}|_| |_|\\___| \\___||___| \\___/ |___|_|\\_\\${r}" \
    "" \
    "${b}OpenCode${r} - ${gl_hong}卸载工具${r}" \
    ""
}


[ "$(id -u)" != "0" ] && error "请以 root 身份运行（sudo bash <(curl ...)）"


print_banner
sep_line


section "停止并清理 systemd 服务"
if command -v systemctl >/dev/null 2>&1; then
  systemctl stop opencode 2>/dev/null || true
  ok "已停止 opencode 服务"


  systemctl disable opencode 2>/dev/null || true
  ok "已禁用 opencode 开机自启"


  rm -f /etc/systemd/system/opencode.service
  ok "已删除 systemd 服务单元文件"


  systemctl daemon-reload 2>/dev/null || true
  ok "已重载 systemd"
else
  warn "未检测到 systemd，跳过服务单元清理"
fi


section "终止残留进程"
if command -v pkill >/dev/null 2>&1; then
  pkill -9 opencode 2>/dev/null || true
  ok "已终止残留 opencode 进程"
fi


section "删除程序与数据目录"
rm -rf /root/.opencode
ok "已删除 /root/.opencode"


rm -rf /usr/local/bin/opencode
ok "已删除 /usr/local/bin/opencode"


rm -rf /root/.config/opencode
ok "已删除 /root/.config/opencode"


rm -rf /root/.local/share/opencode
ok "已删除 /root/.local/share/opencode"


rm -rf /root/.cache/opencode
ok "已删除 /root/.cache/opencode"


sep_line
printf "  %s\n" "${gl_lv}✔ OpenCode 卸载完成！${reset}"
warn "提示：脚本不会自动关闭防火墙端口，如需关闭请手动操作防火墙。"
sep_line
