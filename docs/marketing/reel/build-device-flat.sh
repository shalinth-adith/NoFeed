#!/usr/bin/env bash
#
# Assemble the 9:16 Reel — the device cut. Every app screen plays INSIDE a
# single iPhone that stays locked in place while the screens dissolve within it,
# so it reads as real hardware rather than a swapping rectangle.
#
#   docs/marketing/reel/build.sh            → docs/marketing/reel/nofeed-reel.mp4
#
# Pipeline split, unchanged in spirit from before: captions/phone.swift draws
# each screen inside the device on the brand ground, at the final 1080×1920, in
# AppKit (bezel, rounded screen, drop shadow, radial lift, glass glare — all
# first-class there). captions/compose.swift draws the caption PNGs and the
# end-card ground. This script only adds motion (a slow push-in), the caption
# fade-and-rise, the dissolves, and the fade in from / out to black.
#
# Layout: the device floats in y≈180..1115 with the caption on the ground at
# CAPTION_Y (~1150) — both clear of the Reels UI zones (text out of the top 14%
# and bottom 35%). Because the device is identical in every frame, a dissolve
# changes only the screen. Every shot here is a real screen from the app; see
# phone.swift and the shots/ note for provenance.

set -euo pipefail
cd "$(dirname "$0")"

W=1080; H=1920; FPS=30
CAPTION_Y=1102          # png top; text baseline lands ~1150, above the 1248 line
OUT=nofeed-reel.mp4
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
ENC=(-r $FPS -c:v libx264 -preset medium -crf 17 -pix_fmt yuv420p)
frames() { python3 -c "print(int(round($1*$FPS)))"; }

# One phone-framed screen: a very gentle push-in on the whole composition, then
# the caption fades in with a 14px rise and fades out before the dissolve.
# $1 frame_png  $2 dur  $3 caption|""  $4 out
phoneshot() {
  local png=$1 dur=$2 cap=$3 out=$4 n; n=$(frames "$dur")
  local move="[0:v]scale=$((W*2)):$((H*2)),\
zoompan=z='min(1+0.00030*on,1.032)':d=$n:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s=${W}x${H}:fps=${FPS}[b]"
  if [ -n "$cap" ]; then
    local out_st; out_st=$(python3 -c "print(max(0.0,$dur-0.55))")
    ffmpeg -v error -y -loop 1 -i "frames/$png" -loop 1 -i "captions/$cap.png" -t "$dur" -filter_complex "\
${move};\
[1:v]format=rgba,fade=t=in:st=0.35:d=0.45:alpha=1,fade=t=out:st=${out_st}:d=0.4:alpha=1[cap];\
[b][cap]overlay=0:'${CAPTION_Y}+14*(1-min(max(t-0.35\,0)/0.45\,1))':shortest=1,format=yuv420p[v]" \
      -map "[v]" "${ENC[@]}" "$TMP/$out"
  else
    ffmpeg -v error -y -loop 1 -i "frames/$png" -t "$dur" \
      -filter_complex "${move};[b]format=yuv420p[v]" -map "[v]" "${ENC[@]}" "$TMP/$out"
  fi
}

# End card: icon, name, store line — staggered fade-ins on the ground.
end_card() {  # $1 dur  $2 out
  local dur=$1 out=$2
  ffmpeg -v error -y -loop 1 -i frames/ground.png -loop 1 -i captions/icon-rounded.png \
    -loop 1 -i captions/e-name.png -loop 1 -i captions/e-store.png -t "$dur" -filter_complex "\
[1:v]format=rgba,fade=t=in:st=0.05:d=0.7:alpha=1[icon];\
[2:v]format=rgba,fade=t=in:st=0.55:d=0.6:alpha=1[name];\
[3:v]format=rgba,fade=t=in:st=0.95:d=0.6:alpha=1[store];\
[0:v][icon]overlay=(W-w)/2:'400+10*(1-min(max(t-0.05\,0)/0.7\,1))':shortest=1[a];\
[a][name]overlay=0:'890+10*(1-min(max(t-0.55\,0)/0.6\,1))':shortest=1[c];\
[c][store]overlay=0:'1050+8*(1-min(max(t-0.95\,0)/0.6\,1))':shortest=1,format=yuv420p[v]" \
    -map "[v]" "${ENC[@]}" "$TMP/$out"
}

D=(1.7 2.6 2.0 1.8 2.2 2.2 2.4)
T=(0.45 0.5 0.5 0.5 0.5 0.5)

echo "▸ 1  hook";              phoneshot p-focus.png    ${D[0]} ""        s1.mp4
echo "▸ 2  the door";          phoneshot p-door.png     ${D[1]} c-holds   s2.mp4
echo "▸ 3  Lock Screen";       phoneshot p-lock.png     ${D[2]} c-lock    s3.mp4
echo "▸ 4  Dynamic Island";    phoneshot p-island.png   ${D[3]} c-island  s4.mp4
echo "▸ 5  the week";          phoneshot p-insights.png ${D[4]} c-sticks  s5.mp4
echo "▸ 6  the proof";         phoneshot p-recap.png    ${D[5]} ""        s6.mp4
echo "▸ 7  end card";          end_card                 ${D[6]}           s7.mp4

read -r FILTER TOTAL < <(python3 - "${D[@]}" -- "${T[@]}" <<'PY'
import sys
a = sys.argv[1:]; d = list(map(float, a[:a.index('--')])); t = list(map(float, a[a.index('--')+1:]))
parts, prev, off = [], "[0:v]", 0.0
for i in range(1, len(d)):
    off += d[i-1] - t[i-1]
    parts.append(f"{prev}[{i}:v]xfade=transition=fade:duration={t[i-1]}:offset={off:.3f}[x{i}]"); prev=f"[x{i}]"
total = off + d[-1]
parts.append(f"{prev}fade=t=in:st=0:d=0.5,fade=t=out:st={total-0.6:.3f}:d=0.6,format=yuv420p[v]")
print(";".join(parts), f"{total:.2f}")
PY
)
echo "▸ assembling — ${TOTAL}s"
ffmpeg -v error -y \
  -i "$TMP/s1.mp4" -i "$TMP/s2.mp4" -i "$TMP/s3.mp4" -i "$TMP/s4.mp4" -i "$TMP/s5.mp4" -i "$TMP/s6.mp4" -i "$TMP/s7.mp4" \
  -f lavfi -i anullsrc=r=48000:cl=stereo \
  -filter_complex "$FILTER" -map "[v]" -map 7:a -t "$TOTAL" \
  -c:v libx264 -preset slow -crf 17 -pix_fmt yuv420p -r $FPS -c:a aac -b:a 64k -movflags +faststart "$OUT"
ffprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate:format=duration -of default=nw=1 "$OUT"
echo "✓ $OUT"
