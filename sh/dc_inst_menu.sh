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

sleep_fractional() {
    local seconds=$1
    if sleep "$seconds" 2>/dev/null; then return 0; fi
    if command -v perl >/dev/null 2>&1; then perl -e "select(undef, undef, undef, $seconds)"; return 0; fi
    if command -v python3 >/dev/null 2>&1; then python3 -c "import time; time.sleep($seconds)"; return 0; fi
    if command -v python >/dev/null 2>&1; then python -c "import time; time.sleep($seconds)"; return 0; fi
    local int_seconds=$(echo "$seconds" | awk '{print int($1+0.999)}')
    sleep "$int_seconds"
}

handle_invalid_input() {
    echo -ne "\r\033[K${gl_huang}无效的输入,请重新输入! ${gl_zi} 1 ${gl_huang} 秒后返回"
    sleep_fractional 1
    echo -ne "\r\033[K${gl_lv}无效的输入,请重新输入! ${gl_zi}0${gl_lv} 秒后返回"
    sleep_fractional 0.5
    echo -ne "\r\033[K"
    continue
}

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n 1 -s -r -p ""
    echo ""
    clear
}

cancel_return() {
    local menu_name="${1:-上一级选单}"
    echo -ne "${gl_lv}即将返回 ${gl_huang}${menu_name}${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.5
    echo -ne "${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    sleep_fractional 0.6
    echo ""
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

run_compose() {
    local script_name="$1"
    local desc="$2"
    local port_args="$3"
    local default_dir="$4"
    local user_port=""
    local user_dir=""

    echo -e "${gl_bufan}─────────────────────────────────────────────────────${reset}"
    echo -e "${gl_lv}  已选择: ${gl_bai}${desc}${reset}"
    echo -e "${gl_lv}  脚本:   ${gl_bai}dc_inst_${script_name}.sh${reset}"
    echo -e "${gl_bufan}─────────────────────────────────────────────────────${reset}"

    if [ -n "$port_args" ]; then
        local port_arr=($port_args)
        local port_count=${#port_arr[@]}
        if (( port_count == 1 )); then
            read -r -e -p "$(echo -e "${gl_bai}映射端口 (回车默认 ${gl_huang}${port_args}${gl_bai}): ")" user_port
            user_port="${user_port:-${port_args}}"
        elif (( port_count == 2 )); then
            read -r -e -p "$(echo -e "${gl_bai}Web 端口 (回车默认 ${gl_huang}${port_arr[0]}${gl_bai}): ")" p1
            p1="${p1:-${port_arr[0]}}"
            read -r -e -p "$(echo -e "${gl_bai}SSH 端口 (回车默认 ${gl_huang}${port_arr[1]}${gl_bai}): ")" p2
            p2="${p2:-${port_arr[1]}}"
            user_port="${p1} ${p2}"
        fi
    fi

    read -r -e -p "$(echo -e "${gl_bai}部署目录 (回车默认 ${gl_huang}${default_dir}${gl_bai}): ")" user_dir
    user_dir="${user_dir:-${default_dir}}"

    echo ""
    echo -e "${gl_huang}即将执行:${reset}"
    local cmd="bash <(curl -sSL gitee.com/meimolihan/cmdbox/raw/master/sh/dc_inst_${script_name}.sh)"
    [ -n "$user_port" ] && cmd+=" $user_port"
    cmd+=" $user_dir"
    echo -e "  ${gl_lan}${cmd}${reset}"
    echo ""
    read -r -e -p "$(echo -e "${gl_bai}确认执行? (${gl_lv}Y${gl_bai}/${gl_hong}n${gl_bai}): ")" confirm
    confirm="${confirm:-y}"
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "已取消"
        sleep 1
        return
    fi

    echo ""
    eval "$cmd"
}

dc_inst_allinssl() { run_compose "allinssl" "AllinSSL 证书管理工具" "7979" "/vol1/1000/compose/allinssl"; }
dc_inst_caddy() { run_compose "caddy" "Caddy Web 服务器" "8080" "/vol1/1000/compose/caddy"; }
dc_inst_chrome() { run_compose "chrome" "Chromium 网页版浏览器" "3000" "/vol1/1000/compose/chrome"; }
dc_inst_daoliyu-music() { run_compose "daoliyu-music" "道理鱼音乐" "4000" "/vol1/1000/compose/daoliyu-music"; }
dc_inst_dpanel() { run_compose "dpanel" "DPanel Docker 管理面板" "8807" "/vol1/1000/compose/dpanel"; }
dc_inst_dufs() { run_compose "dufs" "Dufs 私有网盘" "5000" "/vol1/1000/compose/dufs"; }
dc_inst_easyvoice() { run_compose "easyvoice" "EasyVoice 智能文本转语音" "9549" "/vol1/1000/compose/easyvoice"; }
dc_inst_emby() { run_compose "emby" "Emby 媒体服务器" "8996" "/vol1/1000/compose/emby"; }
dc_inst_filebrowser() { run_compose "filebrowser" "FileBrowser 网页文件管理器" "8880" "/vol1/1000/compose/filebrowser"; }
dc_inst_gitea() { run_compose "gitea" "Gitea 代码托管平台" "3033 2233" "/vol1/1000/compose/gitea"; }
dc_inst_gopeed() { run_compose "gopeed" "Gopeed 高速下载器" "6600" "/vol1/1000/compose/gopeed"; }
dc_inst_halo() { run_compose "halo" "Halo 建站工具" "8090" "/vol1/1000/compose/halo"; }
dc_inst_hd-icons() { run_compose "hd-icons" "高清图标库" "50560" "/vol1/1000/compose/hd-icons"; }
dc_inst_ittools() { run_compose "ittools" "IT 工具箱" "8808" "/vol1/1000/compose/it-tools"; }
dc_inst_jellyfin() { run_compose "jellyfin" "Jellyfin 媒体服务器" "8096" "/vol1/1000/compose/jellyfin"; }
dc_inst_kspeeder() { run_compose "kspeeder" "KSpeeder 私有加速代理" "5003" "/vol1/1000/compose/kspeeder"; }
dc_inst_litepan() { run_compose "litepan" "Litepan 网盘聚合工具" "5211" "/vol1/1000/compose/litepan"; }
dc_inst_lucky() { run_compose "lucky" "Lucky 全能内网工具" "" "/vol1/1000/compose/lucky"; }
dc_inst_lxserver() { run_compose "lxserver" "落雪音乐服务" "9526" "/vol1/1000/compose/lxserver"; }
dc_inst_mindoc() { run_compose "mindoc" "MinDoc 文档管理系统" "8181" "/vol1/1000/compose/mindoc"; }
dc_inst_moontv() { run_compose "moontv" "LunaTV 电视直播服务" "3808" "/vol1/1000/compose/moontv"; }
dc_inst_music-tag() { run_compose "music-tag" "Music Tag Web 音乐标签编辑器" "8001" "/vol1/1000/compose/music-tag"; }
dc_inst_nastools() { run_compose "nastools" "NASTools 媒体管理套件" "3000" "/vol1/1000/compose/nastools"; }
dc_inst_nginx-file() { run_compose "nginx-file" "Nginx 轻量级文件服务" "18080" "/vol1/1000/compose/nginx-file"; }
dc_inst_opencode() { run_compose "opencode" "OpenCode 在线代码编辑器" "3005" "/vol1/1000/compose/opencode"; }
dc_inst_openlist() { run_compose "openlist" "Openlist 媒体目录服务" "5244" "/vol1/1000/compose/openlist"; }
dc_inst_pansou() { run_compose "pansou" "PanSou 私人网盘搜索引擎" "8110" "/vol1/1000/compose/pansou"; }
dc_inst_portainer() { run_compose "portainer" "Portainer 容器管理面板" "9000" "/vol1/1000/compose/portainer"; }
dc_inst_qbittorrent() { run_compose "qbittorrent" "qBittorrent 下载工具" "8081" "/vol1/1000/compose/qbittorrent"; }
dc_inst_random-pic-api() { run_compose "random-pic-api" "随机图片 API 接口" "8588" "/vol1/1000/compose/random-pic-api"; }
dc_inst_reubah() { run_compose "reubah" "Reubah 图片文档格式转换" "8681" "/vol1/1000/compose/reubah"; }
dc_inst_safeline() { run_compose "safeline" "雷池 SafeLine WAF 安全防护" "9443" "/vol1/1000/compose/safeline"; }
dc_inst_siyuan() { run_compose "siyuan" "思源笔记" "6806" "/vol1/1000/compose/siyuan"; }
dc_inst_speedtest() { run_compose "speedtest" "Speedtest Go 中文版网速测试" "7878" "/vol1/1000/compose/speedtest"; }
dc_inst_sun-panel() { run_compose "sun-panel" "Sun-Panel 导航面板" "3002" "/vol1/1000/compose/sun-panel"; }
dc_inst_taosync() { run_compose "taosync" "TaoSync 云盘同步工具" "8023" "/vol1/1000/compose/taosync"; }
dc_inst_transmission() { run_compose "transmission" "Transmission 下载工具" "9091" "/vol1/1000/compose/transmission"; }
dc_inst_tvhelper() { run_compose "tvhelper" "悟空盒子助手" "2288" "/vol1/1000/compose/tvhelper"; }
dc_inst_vscode() { run_compose "vscode" "VS Code 网页版" "8443" "/vol1/1000/compose/vscode"; }
dc_inst_xiaomusic() { run_compose "xiaomusic" "XiaoMusic 小爱音箱服务" "58090" "/vol1/1000/compose/xiaomusic"; }
dc_inst_xunlei() { run_compose "xunlei" "迅雷下载服务" "2345" "/vol1/1000/compose/xunlei"; }
dc_inst_zfile() { run_compose "zfile" "ZFile 在线文件管理系统" "8080" "/vol1/1000/compose/zfile"; }
dc_inst_iptv() { run_compose "iptv" "IPTV 直播流代理服务" "1905" "/vol1/1000/compose/iptv"; }
dc_inst_ddns-go() { run_compose "ddns-go" "DDNS-GO 动态域名解析" "9876" "/vol1/1000/compose/ddns-go"; }
dc_inst_bujic-panel() { run_compose "bujic-panel" "Bujic Panel 布吉岛导航" "3000" "/vol1/1000/compose/bujic-panel"; }
dc_inst_arcane() { run_compose "arcane" "Arcane 应用管理器" "3552" "/vol1/1000/compose/arcane"; }
dc_inst_bark() { run_compose "bark" "Bark 推送服务" "8380" "/vol1/1000/compose/bark"; }
dc_inst_dufs-zh() { run_compose "dufs-zh" "Dufs-ZH 中文版私有网盘" "5000" "/vol1/1000/compose/dufs-zh"; }
dc_inst_easynode() { run_compose "easynode" "EasyNode 远程管理工具" "8082" "/vol1/1000/compose/easynode"; }
dc_inst_mediamaster() { run_compose "mediamaster" "MediaMaster 媒资管理" "1688" "/vol1/1000/compose/mediamaster"; }
dc_inst_metube-zh() { run_compose "metube-zh" "MeTube-ZH 中文版视频下载器" "8081" "/vol1/1000/compose/metube-zh"; }
dc_inst_nginx() { run_compose "nginx" "Nginx Web 服务器" "80" "/vol1/1000/compose/nginx"; }
dc_inst_studybuddy() { run_compose "studybuddy" "StudyBuddy 刷题自测系统" "8658" "/vol1/1000/compose/studybuddy"; }
dc_inst_uptime-kuma() { run_compose "uptime-kuma" "Uptime Kuma 监控工具" "3001" "/vol1/1000/compose/uptime-kuma"; }

show_menu() {
    clear
    echo -e "${gl_zi}>>> Compose 一键安装菜单${reset}"
    echo -e "${gl_bufan}─────────────────────────────────────────────────────${reset}"
    echo -e "${gl_bufan}1.  ${gl_bai}AllinSSL证书管理工具   ${gl_bufan}2.  ${gl_bai}Caddy Web服务器"
    echo -e "${gl_bufan}3.  ${gl_bai}Chromium网页版浏览器   ${gl_bufan}4.  ${gl_bai}道理鱼音乐"
    echo -e "${gl_bufan}5.  ${gl_bai}DPanel Docker管理面板  ${gl_bufan}6.  ${gl_bai}Dufs私有网盘"
    echo -e "${gl_bufan}7.  ${gl_bai}EasyVoice文本转语音    ${gl_bufan}8.  ${gl_bai}Emby媒体服务器"
    echo -e "${gl_bufan}9.  ${gl_bai}FileBrowser文件管理器  ${gl_bufan}10. ${gl_bai}Gitea代码托管平台"
    echo -e "${gl_bufan}─────────────────────────────────────────────────────${reset}"
    echo -e "${gl_bufan}11. ${gl_bai}Gopeed高速下载器       ${gl_bufan}12. ${gl_bai}Halo建站工具"
    echo -e "${gl_bufan}13. ${gl_bai}高清图标库             ${gl_bufan}14. ${gl_bai}IT工具箱"
    echo -e "${gl_bufan}15. ${gl_bai}Jellyfin媒体服务器     ${gl_bufan}16. ${gl_bai}KSpeeder私有加速代理"
    echo -e "${gl_bufan}17. ${gl_bai}Litepan网盘聚合工具    ${gl_bufan}18. ${gl_bai}Lucky全能内网工具"
    echo -e "${gl_bufan}19. ${gl_bai}落雪音乐服务"
    echo -e "${gl_bufan}─────────────────────────────────────────────────────${reset}"
    echo -e "${gl_bufan}20. ${gl_bai}MinDo文档管理系统      ${gl_bufan}21. ${gl_bai}LunaTV电视直播服务"
    echo -e "${gl_bufan}22. ${gl_bai}MusicTag音乐标签编辑   ${gl_bufan}23. ${gl_bai}NASTools媒体管理套件"
    echo -e "${gl_bufan}24. ${gl_bai}Nginx轻量级文件服务    ${gl_bufan}25. ${gl_bai}OpenCode在线代码编辑器"
    echo -e "${gl_bufan}26. ${gl_bai}Openlist媒体目录服务   ${gl_bufan}27. ${gl_bai}PanSou私人网盘搜索引擎"
    echo -e "${gl_bufan}28. ${gl_bai}Portainer容器管理面板  ${gl_bufan}29. ${gl_bai}qBittorrent下载工具"
    echo -e "${gl_bufan}─────────────────────────────────────────────────────${reset}"
    echo -e "${gl_bufan}30. ${gl_bai}随机图片 API接口       ${gl_bufan}31. ${gl_bai}Reubah图片文档格式转换"
    echo -e "${gl_bufan}32. ${gl_bai}雷池WAF安全防护        ${gl_bufan}33. ${gl_bai}思源笔记"
    echo -e "${gl_bufan}34. ${gl_bai}Speedtest中文网速测试  ${gl_bufan}35. ${gl_bai}Sun-Panel导航面板"
    echo -e "${gl_bufan}36. ${gl_bai}TaoSync云盘同步工具    ${gl_bufan}37. ${gl_bai}Transmission下载工具"
    echo -e "${gl_bufan}38. ${gl_bai}悟空盒子助手           ${gl_bufan}39. ${gl_bai}VSCode网页版"
    echo -e "${gl_bufan}─────────────────────────────────────────────────────${reset}"
    echo -e "${gl_bufan}40. ${gl_bai}XiaoMusic小爱音箱服务  ${gl_bufan}41. ${gl_bai}迅雷下载服务"
    echo -e "${gl_bufan}42. ${gl_bai}ZFile在线文件管理系统  ${gl_bufan}43. ${gl_bai}IPTV直播流代理服务"
    echo -e "${gl_bufan}44. ${gl_bai}DDNS-GO动态域名解析    ${gl_bufan}45. ${gl_bai}Bujic Panel布吉岛导航"
    echo -e "${gl_bufan}46. ${gl_bai}Arcane应用管理器       ${gl_bufan}47. ${gl_bai}Bark推送服务"
    echo -e "${gl_bufan}48. ${gl_bai}Dufs-ZH中文版私有网盘  ${gl_bufan}49. ${gl_bai}EasyNode远程管理工具"
    echo -e "${gl_bufan}50. ${gl_bai}MediaMaster媒资管理    ${gl_bufan}51. ${gl_bai}MeTube-ZH视频下载器"
    echo -e "${gl_bufan}52. ${gl_bai}Nginx Web服务器        ${gl_bufan}53. ${gl_bai}StudyBuddy刷题自测"
    echo -e "${gl_bufan}54. ${gl_bai}Uptime Kuma监控工具"
    echo -e "${gl_bufan}─────────────────────────────────────────────────────${reset}"
    echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单         ${gl_hong}00. ${gl_bai}退出脚本"
}

main() {
    while true; do
        show_menu
        echo -e "${gl_bufan}─────────────────────────────────────────────────────${reset}"
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" choice
        choice="${choice:-0}"

        if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
            handle_invalid_input
            continue
        fi

        if (( choice < 0 || choice > 54 )); then
            handle_invalid_input
            continue
        fi

        case "$choice" in
            1) dc_inst_allinssl ;;
            2) dc_inst_caddy ;;
            3) dc_inst_chrome ;;
            4) dc_inst_daoliyu-music ;;
            5) dc_inst_dpanel ;;
            6) dc_inst_dufs ;;
            7) dc_inst_easyvoice ;;
            8) dc_inst_emby ;;
            9) dc_inst_filebrowser ;;
            10) dc_inst_gitea ;;
            11) dc_inst_gopeed ;;
            12) dc_inst_halo ;;
            13) dc_inst_hd-icons ;;
            14) dc_inst_ittools ;;
            15) dc_inst_jellyfin ;;
            16) dc_inst_kspeeder ;;
            17) dc_inst_litepan ;;
            18) dc_inst_lucky ;;
            19) dc_inst_lxserver ;;
            20) dc_inst_mindoc ;;
            21) dc_inst_moontv ;;
            22) dc_inst_music-tag ;;
            23) dc_inst_nastools ;;
            24) dc_inst_nginx-file ;;
            25) dc_inst_opencode ;;
            26) dc_inst_openlist ;;
            27) dc_inst_pansou ;;
            28) dc_inst_portainer ;;
            29) dc_inst_qbittorrent ;;
            30) dc_inst_random-pic-api ;;
            31) dc_inst_reubah ;;
            32) dc_inst_safeline ;;
            33) dc_inst_siyuan ;;
            34) dc_inst_speedtest ;;
            35) dc_inst_sun-panel ;;
            36) dc_inst_taosync ;;
            37) dc_inst_transmission ;;
            38) dc_inst_tvhelper ;;
            39) dc_inst_vscode ;;
            40) dc_inst_xiaomusic ;;
            41) dc_inst_xunlei ;;
            42) dc_inst_zfile ;;
            43) dc_inst_iptv ;;
            44) dc_inst_ddns-go ;;
            45) dc_inst_bujic-panel ;;
            46) dc_inst_arcane ;;
            47) dc_inst_bark ;;
            48) dc_inst_dufs-zh ;;
            49) dc_inst_easynode ;;
            50) dc_inst_mediamaster ;;
            51) dc_inst_metube-zh ;;
            52) dc_inst_nginx ;;
            53) dc_inst_studybuddy ;;
            54) dc_inst_uptime-kuma ;;
            0)  cancel_return "已是主菜单" || continue ;;
            00 | 000 | 0000) exit_script ;;
        esac
    done
}

main "$@"
