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

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    read -r -n 1 -s -r -p ""
    echo ""
    clear
}

hms_to_sec() {
    local hms="$1"
    awk -v t="$hms" 'BEGIN{
        gsub(/,/,"",t);
        split(t,a,":");
        h=a[1]+0; m=a[2]+0; s=a[3]+0;
        print int(h*3600 + m*60 + s + 0.5)
    }'
}

sec_to_human() {
    local sec="$1"
    [[ -z "$sec" || ! "$sec" =~ ^[0-9]+$ ]] && { echo "未知"; return; }

    local h m s
    h=$((sec / 3600))
    m=$(( (sec % 3600) / 60 ))
    s=$((sec % 60))

    if (( h > 0 )); then
        printf "%02d时%02d分%02d秒" "$h" "$m" "$s"
    else
        printf "%02d分%02d秒" "$m" "$s"
    fi
}

file_size_human() {
    local fpath="$1"
    local size_bytes
    size_bytes=$(stat -c%s "$fpath" 2>/dev/null || stat -f%z "$fpath" 2>/dev/null)
    if [[ -z "$size_bytes" ]]; then
        echo "未知"
        return
    fi

    if (( size_bytes >= 1073741824 )); then
        awk -v b="$size_bytes" 'BEGIN{printf "%.2f GB", b/1073741824}'
    else
        awk -v b="$size_bytes" 'BEGIN{printf "%.2f MB", b/1048576}'
    fi
}

get_video_meta() {
    local fpath="$1"
    if [[ ! -f "$fpath" ]]; then
        echo "FILE_NOT_EXIST"
        return
    fi

    local codec_name profile bit_depth codectag res_w res_h fps color_space
    codec_name=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$fpath")
    profile=$(ffprobe -v error -select_streams v:0 -show_entries stream=profile -of default=noprint_wrappers=1:nokey=1 "$fpath")
    bit_depth=$(ffprobe -v error -select_streams v:0 -show_entries stream=bit_depth -of default=noprint_wrappers=1:nokey=1 "$fpath")
    codectag=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_tag_string -of default=noprint_wrappers=1:nokey=1 "$fpath")
    res_w=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=noprint_wrappers=1:nokey=1 "$fpath")
    res_h=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=noprint_wrappers=1:nokey=1 "$fpath")
    fps=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=noprint_wrappers=1:nokey=1 "$fpath")
    color_space=$(ffprobe -v error -select_streams v:0 -show_entries stream=color_space -of default=noprint_wrappers=1:nokey=1 "$fpath")

    if [[ "$fps" == *"/"* ]]; then
        fps=$(awk -v f="$fps" 'BEGIN{split(f,a,"/");if(a[2]!=0)printf "%.2f",a[1]/a[2];else print f}')
    fi

    local a_codec a_sample a_channels a_bitrate
    a_codec=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$fpath")
    a_sample=$(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate -of default=noprint_wrappers=1:nokey=1 "$fpath")
    a_channels=$(ffprobe -v error -select_streams a:0 -show_entries stream=channels -of default=noprint_wrappers=1:nokey=1 "$fpath")
    a_bitrate=$(ffprobe -v error -select_streams a:0 -show_entries stream=bit_rate -of default=noprint_wrappers=1:nokey=1 "$fpath")

    local duration_sec=""

    duration_sec=$(ffprobe -v error \
        -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 "$fpath")

    if [[ -z "$duration_sec" || "$duration_sec" == "N/A" ]]; then
        duration_sec=$(ffprobe -v error -select_streams v:0 \
            -show_entries stream=duration \
            -of default=noprint_wrappers=1:nokey=1 "$fpath")
    fi

    if [[ -z "$duration_sec" || "$duration_sec" == "N/A" ]]; then
        duration_sec=$(ffprobe -v error -select_streams a:0 \
            -show_entries stream=duration \
            -of default=noprint_wrappers=1:nokey=1 "$fpath")
    fi

    if [[ -z "$duration_sec" || "$duration_sec" == "N/A" ]]; then
        local hms_raw
        hms_raw=$(ffmpeg -v error -i "$fpath" 2>&1 \
            | grep -m1 "Duration:" \
            | awk '{print $2}' \
            | tr -d ',')
        if [[ -n "$hms_raw" ]]; then
            duration_sec=$(hms_to_sec "$hms_raw")
        fi
    fi

    if [[ "$duration_sec" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        duration_sec=$(awk -v d="$duration_sec" 'BEGIN{printf "%d",d+0.5}')
    else
        duration_sec=""
    fi

    local total_bitrate v_bitrate
    total_bitrate=$(ffprobe -v error -show_entries format=bit_rate -of default=noprint_wrappers=1:nokey=1 "$fpath")
    v_bitrate=$(ffprobe -v error -select_streams v:0 -show_entries stream=bit_rate -of default=noprint_wrappers=1:nokey=1 "$fpath")

    local v_bitrate_k="" a_bitrate_k="" total_bitrate_k=""
    [[ "$v_bitrate" =~ ^[0-9]+$ ]] && v_bitrate_k=$((v_bitrate/1000))
    [[ "$a_bitrate" =~ ^[0-9]+$ ]] && a_bitrate_k=$((a_bitrate/1000))
    [[ "$total_bitrate" =~ ^[0-9]+$ ]] && total_bitrate_k=$((total_bitrate/1000))
    [[ -z "$bit_depth" ]] && bit_depth="8"

    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
        "$codec_name" "$profile" "$bit_depth" "$codectag" \
        "$res_w" "$res_h" "$fps" "$color_space" \
        "$a_codec" "$a_sample" "$a_channels" \
        "$v_bitrate_k" "$a_bitrate_k" "$total_bitrate_k" "$duration_sec"
}

print_video_info() {
    local fpath="$1"
    clear
    echo -e "${gl_zi}>>> 视频文件信息查看器${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_hui}文件路径:${gl_bai} ${gl_lan}${fpath}${reset}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local raw
    raw=$(get_video_meta "$fpath")
    if [[ "$raw" == "FILE_NOT_EXIST" ]]; then
        echo -e "${gl_hong}错误：文件不存在！${reset}"
        break_end
        return
    fi

    IFS=$'\t' read -r codec_name profile bit_depth codectag res_w res_h fps color_space \
        a_codec a_sample a_channels v_bitrate_k a_bitrate_k total_bitrate_k duration_sec \
        <<< "$raw"

    local mark_ok="${gl_lv}✔${reset}"

    local disp_vcodec="${codec_name^^} ${profile} ${bit_depth}bit"
    echo -e "${gl_hui}视频编码  ${gl_bai}${disp_vcodec} ${mark_ok}"

    if [[ "$codectag" == "hvc1" ]]; then
        echo -e "${gl_hui}封装标签  ${gl_bai}${codectag} ${mark_ok}${gl_bai}（苹果全系原生支持 + 秒开 + 缩略图 + 编辑友好 + 流媒体合规 + 零质量损失）"
    elif [[ "$codectag" == "hev1" ]]; then
        echo -e "${gl_hui}封装标签  ${gl_bai}${gl_huang}${codectag}${reset} ${gl_huang}⚠${reset}${gl_bai}（⚠苹果/部分电视存在兼容风险，建议修复为hvc1）"
    else
        echo -e "${gl_hui}封装标签  ${gl_bai}${codectag} ${mark_ok}"
    fi

    echo -e "${gl_hui}分 辨 率  ${gl_bai}${res_w}×${res_h} ${fps}fps ${mark_ok}"
    echo -e "${gl_hui}色彩空间  ${gl_bai}${color_space} ${mark_ok}"

    local disp_audio="${a_codec^^} ${a_sample}Hz "
    (( a_channels == 2 )) && disp_audio+="立体声" || disp_audio+="${a_channels}声道"
    [[ -n "$a_bitrate_k" ]] && disp_audio+=" ${a_bitrate_k}kbps"
    echo -e "${gl_hui}音频信息  ${gl_bai}${disp_audio} ${mark_ok}"

    local disp_br=""
    [[ -n "$v_bitrate_k" ]] && disp_br+="视频≈${v_bitrate_k}kbps"
    [[ -n "$a_bitrate_k" ]] && disp_br+="，音频 ${a_bitrate_k}kbps"
    [[ -n "$total_bitrate_k" ]] && disp_br+="，总 ${total_bitrate_k}kbps"
    echo -e "${gl_hui}码率信息  ${gl_bai}${disp_br} ${mark_ok}"

    local fsize
    fsize=$(file_size_human "$fpath")
    echo -e "${gl_hui}文件体积  ${gl_bai}${fsize} ${mark_ok}"

    local dur_human
    dur_human=$(sec_to_human "$duration_sec")
    echo -e "${gl_hui}视频时长  ${gl_bai}${dur_human} ${mark_ok}"

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

interactive_select() {
    clear
    echo -e "${gl_zi}>>> 视频文件选择模式${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    mapfile -t file_list < <(ls -1 ./*.{mp4,MP4,mkv,MKV,mov,MOV,avi,AVI} 2>/dev/null)
    local cnt=${#file_list[@]}
    if (( cnt == 0 )); then
        echo -e "${gl_huang}当前目录未找到视频文件${reset}"
    else
        for ((i=0;i<cnt;i++)); do
            printf "${gl_bufan}[%${#cnt}d]${gl_bai} %s\n" "$((i+1))" "${file_list[$i]}"
        done
    fi
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}请输入序号选择，或直接输入文件路径/文件名: ")" input

    local target=""
    if [[ "$input" =~ ^[0-9]+$ ]]; then
        local idx=$((input-1))
        if (( idx >= 0 && idx < cnt )); then
            target="${file_list[$idx]}"
        else
            echo -e "${gl_hong}序号超出范围${reset}"
            return 1
        fi
    else
        target="$input"
    fi
    [[ -z "$target" ]] && return 1
    print_video_info "$target"
}

main() {
    if [[ $# -ge 1 ]]; then
        print_video_info "$1"
    else
        interactive_select
    fi
}

main "$@"