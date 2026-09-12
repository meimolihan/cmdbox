#!/bin/bash
set -u
shopt -s nullglob

install_deps() {
  if [[ "${SKIP_DEPS:-0}" == "1" ]]; then
    echo "SKIP_DEPS=1，跳过依赖安装检查"
    return 0
  fi
  local need_install=0
  if ! command -v ffmpeg &/dev/null; then
    need_install=1
  fi
  if ! command -v ffprobe &/dev/null; then
    need_install=1
  fi
  if [[ $need_install -eq 0 ]]; then
    echo "✅ ffmpeg / ffprobe 已安装，无需处理"
    return 0
  fi
  echo "⚠️ 检测缺失 ffmpeg/ffprobe，开始静默安装..."
  if command -v apt &/dev/null; then
    apt update -qq >/dev/null 2>&1
    apt install -y -qq ffmpeg >/dev/null 2>&1
  elif command -v dnf &/dev/null; then
    dnf install -y ffmpeg >/dev/null 2>&1
  elif command -v yum &/dev/null; then
    yum install -y ffmpeg >/dev/null 2>&1
  elif command -v pacman &/dev/null; then
    pacman -S --noconfirm ffmpeg >/dev/null 2>&1
  else
    echo "❌ 不支持当前系统包管理器，请手动安装 ffmpeg"
    exit 1
  fi
  if ! command -v ffmpeg &/dev/null || ! command -v ffprobe &/dev/null; then
    echo "❌ 依赖安装失败，请手动安装 ffmpeg"
    exit 1
  fi
  echo "✅ ffmpeg 安装完成"
}

MODE="copy"
MAXDEPTH=1
STOP_FILE="./.highlight.stop"
OUTPUT="${OUTPUT:-timeline}"
MAX_CLIPS="${MAX_CLIPS:-8}"
SEC_PER_CLIP="${SEC_PER_CLIP:-30}"
FORCE="${FORCE:-0}"
THUMB="${THUMB:-webp}"
THUMB_WIDTH="${THUMB_WIDTH:-720}"
THUMB_QUALITY="${THUMB_QUALITY:-80}"
THUMB_TIME="${THUMB_TIME:-3}"
THUMB_FORCE="${THUMB_FORCE:-0}"
PURGE="${PURGE:-0}"

parse_args() {
  for arg in "$@"; do
    if [[ "$arg" =~ ^[0-9]+$ ]]; then
      MAXDEPTH="$arg"
    elif [[ "$arg" == "copy" || "$arg" == "exact" ]]; then
      MODE="$arg"
    fi
  done
}

process_single_dir() {
  local dir="$1"
  echo -e "\n===== 进入目录：$dir ====="
  (
    cd "$dir" || exit 1
    echo "== 配置: OUTPUT=$OUTPUT MODE=$MODE THUMB=$THUMB FORCE=$FORCE THUMB_FORCE=$THUMB_FORCE =="
    mkdir -p .highlights

    # 检测webp支持
    if [ "$THUMB" = "webp" ] || [ "$THUMB" = "both" ]; then
      if ! ffmpeg -hide_banner -encoders 2>/dev/null | grep -q libwebp; then
        echo "警告: ffmpeg 不支持 libwebp，改用 jpg"
        THUMB="jpg"
      fi
    fi

    ok=0; fail=0; skip=0
    thumb_ok=0; thumb_fail=0; thumb_skip=0

    for video in *.mp4; do
      [ -f "$video" ] || continue
      stem="${video%.*}"
      dur_s=$(ffprobe -v error -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 "$video" 2>/dev/null)
      case "$dur_s" in ''|*[!0-9.]*) echo "跳过 ${video}"; continue;; esac
      dur=${dur_s%%.*}

      if [ "$dur" -lt 15 ]; then
        n=1; clip="$dur_s"
      else
        n=$(( dur / SEC_PER_CLIP + 1 ))
        [ "$n" -gt "$MAX_CLIPS" ] && n="$MAX_CLIPS"
        clip=$(( dur / n ))
        [ "$clip" -gt "$SEC_PER_CLIP" ] && clip="$SEC_PER_CLIP"
      fi

      echo "${stem}: 时长 ${dur}s → ${n} 段 × ${clip}s"
      i=0
      while [ "$i" -lt "$n" ]; do
        idx=$(printf "%02d" $((i+1)))
        if [ "$dur" -lt 15 ]; then
          start=0; title="完整片段"
        else
          start=$(awk -v i="$i" -v d="$dur_s" -v nn="$n" -v cl="$clip" \
            'BEGIN{s=(i+0.5)/nn*d-cl/2;if(s<0)s=0;m=d-cl;if(s>m)s=(m>0?m:0);printf "%.0f",s}')
          title=$(awk -v i="$i" -v nn="$n" 'BEGIN{
            r=(i+0.5)*100/nn
            if(r<12)t="开场高能"; else if(r>85)t="结局高潮";
            else if(r>62)t="后期转折"; else if(r>=50)t="中点高潮";
            else if(r<32)t="前期精彩"; else t="精彩片段"; print t}')
        fi

        base=".highlights/${stem}_${idx}_${title}"
        out="${base}.mp4"
        rebuilt=0

        if [ "$OUTPUT" = "clip" ]; then
          if [ -e "$out" ] && [ "$FORCE" != 1 ]; then
            echo "  跳过 $(basename "$out")"
            skip=$((skip+1))
          else
            if [ "$MODE" = "exact" ]; then
              ffmpeg -hide_banner -loglevel error -y -ss "$start" -i "$video" -t "$clip" \
                -c:v libx264 -preset veryfast -crf 23 -c:a aac -b:a 128k \
                -avoid_negative_ts make_zero -movflags +faststart "$out" \
                && { ok=$((ok+1)); rebuilt=1; echo "  ↳ $(basename "$out") @${start}s"; } \
                || { fail=$((fail+1)); echo "  失败: $out"; }
            else
              ffmpeg -hide_banner -loglevel error -ss "$start" -i "$video" -t "$clip" -c copy \
                -avoid_negative_ts make_zero -movflags +faststart -y "$out" \
                && { ok=$((ok+1)); rebuilt=1; echo "  ↳ $(basename "$out") @${start}s"; } \
                || { fail=$((fail+1)); echo "  失败: $out"; }
            fi
          fi
        fi

        st=$start
        cdur=""
        if [ "$OUTPUT" = "clip" ] && [ -e "$out" ]; then
          cdur=$(ffprobe -v error -show_entries format=duration \
            -of default=noprint_wrappers=1:nokey=1 "$out" 2>/dev/null)
          case "$cdur" in ''|*[!0-9.]*) cdur="";; esac
        fi
        if [ -n "$cdur" ]; then
          endt=$(awk -v s="$st" -v d="$cdur" 'BEGIN{printf "%.3f", s+d}')
        else
          endt=$(awk -v s="$st" -v cl="$clip" 'BEGIN{printf "%.3f", s+cl}')
        fi

        # 生成JSON元数据
        if [ ! -e "$base.json" ] || [ "$rebuilt" = 1 ]; then
          cat > "$base.json" <<EOF
{
  "title": "$title",
  "start_time": $st,
  "end_time": $endt,
  "score": 8.5
}
EOF
          echo "  元数据 $(basename "$base.json") ($st → ${endt}s)"
          [ "$OUTPUT" = "timeline" ] && ok=$((ok+1))
        else
          [ "$OUTPUT" = "timeline" ] && skip=$((skip+1))
        fi

        if [ "$OUTPUT" = "timeline" ] && [ "$PURGE" = 1 ] && [ -e "$out" ]; then
          rm -f "$out"
          echo "  清理 $(basename "$out")"
        fi

        if [ "$THUMB" != "0" ]; then
          need=0
          if [ "$rebuilt" = 1 ] || [ "$THUMB_FORCE" = 1 ]; then
            need=1
          else
            case "$THUMB" in
              webp) [ ! -e "${base}.thumb.webp" ] && need=1 ;;
              jpg)  [ ! -e "${base}.thumb.jpg" ]  && need=1 ;;
              both) { [ ! -e "${base}.thumb.webp" ] || [ ! -e "${base}.thumb.jpg" ]; } && need=1 ;;
            esac
          fi

          if [ "$need" = 1 ]; then
            if [ "$OUTPUT" = "clip" ]; then
              thumb_src="$out"
              if [ -n "$cdur" ] && awk -v d="$cdur" -v t="$THUMB_TIME" \
                   'BEGIN{exit !(d+0>=t+0)}'; then
                ss="$THUMB_TIME"
              else
                ss=$(awk -v d="${cdur:-0}" 'BEGIN{printf "%.0f",d/2}')
              fi
            else
              thumb_src="$video"
              ss=$(awk -v s="$st" -v t="$THUMB_TIME" -v d="$dur_s" \
                'BEGIN{x=s+t;if(x>=d-1)x=(d-1>0?d-1:0);printf "%.0f",x}')
            fi

            if [ "$THUMB" = "webp" ] || [ "$THUMB" = "both" ]; then
              ffmpeg -hide_banner -loglevel error -ss "$ss" -i "$thumb_src" -frames:v 1 \
                -vf "scale=${THUMB_WIDTH}:-2" -c:v libwebp -quality "$THUMB_QUALITY" \
                -y "${base}.thumb.webp" \
                && { thumb_ok=$((thumb_ok+1)); echo "    ✓ $(basename "$base").thumb.webp"; } \
                || { thumb_fail=$((thumb_fail+1)); echo "    ✗ webp 失败"; }
            fi
            
            if [ "$THUMB" = "jpg" ] || [ "$THUMB" = "both" ]; then
              ffmpeg -hide_banner -loglevel error -ss "$ss" -i "$thumb_src" -frames:v 1 \
                -vf "scale=${THUMB_WIDTH}:-2" -q:v 3 -y "${base}.thumb.jpg" \
                && { thumb_ok=$((thumb_ok+1)); echo "    ✓ $(basename "$base").thumb.jpg"; } \
                || { thumb_fail=$((thumb_fail+1)); echo "    ✗ jpg 失败"; }
            fi
          else
            thumb_skip=$((thumb_skip+1))
            case "$THUMB" in
              webp) echo "    - 缩略图已存在" ;;
              jpg)  echo "    - 缩略图已存在" ;;
              both) echo "    - 缩略图已存在" ;;
            esac
          fi
        fi
        i=$((i+1))
      done
    done

    echo
    echo "完成：$([ "$OUTPUT" = "timeline" ] && echo "成功 ${ok}（时间线片段），跳过 ${skip}" || echo "成功 ${ok}，失败 ${fail}，跳过 ${skip}")"
    [ "$THUMB" != "0" ] && \
      echo "缩略图：成功 ${thumb_ok}，失败 ${thumb_fail}，跳过 ${thumb_skip}"
  )
}

main() {
  install_deps
  parse_args "$@"
  echo "===== 全局配置：MODE=$MODE MAXDEPTH=$MAXDEPTH ====="

  if compgen -G "./*.mp4" >/dev/null; then
    process_single_dir "."
  fi

  find . -mindepth 1 -maxdepth "$MAXDEPTH" -type d -print0 | while IFS= read -r -d '' dir; do
    if [[ -f "$STOP_FILE" ]]; then
      echo -e "\n【检测到停止标记，终止任务】"
      rm -f "$STOP_FILE"
      return 0
    fi
    compgen -G "$dir/*.mp4" >/dev/null || continue
    process_single_dir "$dir"
  done
}

main "$@"
