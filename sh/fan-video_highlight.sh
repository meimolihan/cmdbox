#!/bin/bash
# 精彩片段智能生成器
set -u
shopt -s nullglob

MODE="${1:-copy}"
MAX_CLIPS="${MAX_CLIPS:-8}"
SEC_PER_CLIP="${SEC_PER_CLIP:-30}"
FORCE="${FORCE:-0}"
THUMB="${THUMB:-webp}"
THUMB_WIDTH="${THUMB_WIDTH:-720}"
THUMB_QUALITY="${THUMB_QUALITY:-80}"
THUMB_TIME="${THUMB_TIME:-3}"
THUMB_FORCE="${THUMB_FORCE:-0}"

echo "== 配置: MODE=$MODE THUMB=$THUMB FORCE=$FORCE THUMB_FORCE=$THUMB_FORCE =="

mkdir -p .highlights
command -v ffmpeg >/dev/null || { echo "需要 ffmpeg"; exit 1; }
command -v ffprobe >/dev/null || { echo "需要 ffprobe"; exit 1; }

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

    out=".highlights/${stem}_${idx}_${title}.mp4"
    base="${out%.mp4}"
    rebuilt=0

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

    # ---- 缩略图 ----
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
        cdur=$(ffprobe -v error -show_entries format=duration \
          -of default=noprint_wrappers=1:nokey=1 "$out" 2>/dev/null)
        if [ -n "$cdur" ] && awk -v d="$cdur" -v t="$THUMB_TIME" \
             'BEGIN{exit !(d+0>=t+0)}'; then
          ss="$THUMB_TIME"
        else
          ss=$(awk -v d="${cdur:-0}" 'BEGIN{printf "%.0f",d/2}')
        fi

        if [ "$THUMB" = "webp" ] || [ "$THUMB" = "both" ]; then
          ffmpeg -hide_banner -loglevel error -ss "$ss" -i "$out" -frames:v 1 \
            -vf "scale=${THUMB_WIDTH}:-2" -c:v libwebp -quality "$THUMB_QUALITY" \
            -y "${base}.thumb.webp" \
            && { thumb_ok=$((thumb_ok+1)); echo "    ✓ $(basename "$out" .mp4).thumb.webp"; } \
            || { thumb_fail=$((thumb_fail+1)); echo "    ✗ webp 失败: $(basename "$out")"; }
        fi
        if [ "$THUMB" = "jpg" ] || [ "$THUMB" = "both" ]; then
          ffmpeg -hide_banner -loglevel error -ss "$ss" -i "$out" -frames:v 1 \
            -vf "scale=${THUMB_WIDTH}:-2" -q:v 3 -y "${base}.thumb.jpg" \
            && { thumb_ok=$((thumb_ok+1)); echo "    ✓ $(basename "$out" .mp4).thumb.jpg"; } \
            || { thumb_fail=$((thumb_fail+1)); echo "    ✗ jpg 失败: $(basename "$out")"; }
        fi
      else
        # 缩略图已存在，跳过
        thumb_skip=$((thumb_skip+1))
        case "$THUMB" in
          webp) echo "    - $(basename "$out" .mp4).thumb.webp 已存在" ;;
          jpg)  echo "    - $(basename "$out" .mp4).thumb.jpg 已存在" ;;
          both) echo "    - $(basename "$out" .mp4).thumb.webp/.jpg 已存在" ;;
        esac
      fi
    fi

    i=$((i+1))
  done
done

echo
echo "完成：成功 ${ok}，失败 ${fail}，跳过 ${skip}"
[ "$THUMB" != "0" ] && \
  echo "缩略图：成功 ${thumb_ok}，失败 ${thumb_fail}，跳过 ${thumb_skip}"