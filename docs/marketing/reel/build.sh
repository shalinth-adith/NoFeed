#!/usr/bin/env bash
#
# Assemble the 9:16 Reel — the 3D device cut. Every app screen plays inside one
# iPhone held at a fixed 3/4 perspective, with a slow dolly that alternates
# push-in / pull-out per shot and a faint parallax drift — the "product ad"
# camera move. The device is identical in every frame, so the dissolves change
# only the screen behind the glass.
#
#   docs/marketing/reel/build.sh            → docs/marketing/reel/nofeed-reel.mp4
#
# Layers, so the motion never touches the type: captions/phone.swift draws the
# device on the brand ground (bezel, rounded screen, shadow, radial lift, glare)
# at 1080×1920. Here the WHOLE composed frame is tilted by `perspective` and
# moved by `zoompan` — then the caption is overlaid AFTER, flat and crisp, in
# the safe band on the ground below the device. compose.swift makes the caption
# PNGs and the end-card ground. Homebrew ffmpeg has no freetype, so type is
# never drawn in the filtergraph.
#
# Every shot is a real screen from the app; see phone.swift for provenance.

set -euo pipefail
cd "$(dirname "$0")"

W=1080; H=1920; FPS=30
CAPTION_Y=1102
TILT=52                  # right edge recedes by this many px → gentle 3/4 on a big device
OUT=nofeed-reel.mp4
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
ENC=(-r $FPS -c:v libx264 -preset medium -crf 17 -pix_fmt yuv420p)
frames() { python3 -c "print(int(round($1*$FPS)))"; }
PERSP="perspective=0:0:${W}:${TILT}:0:${H}:${W}:$((H-TILT)):sense=destination"

# One 3D device shot.
#   $1 frame_png  $2 dur  $3 caption|""  $4 dir(in|out)  $5 drift(px, signed)  $6 out
# The dolly runs 1.00..1.055: the whole device is visible at the wide end, and
# the push-in never reaches far enough to crop screen content. The phone is
# narrower than the frame, so the parallax drift pans it against the ground
# rather than off an edge.
phoneshot() {
  local png=$1 dur=$2 cap=$3 dir=$4 drift=$5 out=$6 n; n=$(frames "$dur")
  local zexpr
  if [ "$dir" = "in" ]; then zexpr="min(1.00+0.0011*on,1.055)"; else zexpr="max(1.055-0.0011*on,1.00)"; fi
  # centred zoom + a small linear x drift for parallax across the tilt
  local xexpr="iw/2-(iw/zoom/2)+(${drift})*on/${n}"
  local move="[0:v]${PERSP},scale=$((W*2)):$((H*2)),\
zoompan=z='${zexpr}':d=${n}:x='${xexpr}':y='ih/2-(ih/zoom/2)':s=${W}x${H}:fps=${FPS}[b]"
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

# End card: no tilt (a logo card leaning would look like a mistake), gentle
# push-in only. Staggered fade-ins.
end_card() {  # $1 dur  $2 out
  local dur=$1 out=$2 n; n=$(frames "$dur")
  ffmpeg -v error -y -loop 1 -i frames/ground.png -loop 1 -i captions/icon-rounded.png \
    -loop 1 -i captions/e-name.png -loop 1 -i captions/e-store.png -t "$dur" -filter_complex "\
[0:v]scale=$((W*2)):$((H*2)),zoompan=z='min(1+0.00028*on,1.03)':d=${n}:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s=${W}x${H}:fps=${FPS}[g];\
[1:v]format=rgba,fade=t=in:st=0.05:d=0.7:alpha=1[icon];\
[2:v]format=rgba,fade=t=in:st=0.55:d=0.6:alpha=1[name];\
[3:v]format=rgba,fade=t=in:st=0.95:d=0.6:alpha=1[store];\
[g][icon]overlay=(W-w)/2:'400+10*(1-min(max(t-0.05\,0)/0.7\,1))':shortest=1[a];\
[a][name]overlay=0:'890+10*(1-min(max(t-0.55\,0)/0.6\,1))':shortest=1[c];\
[c][store]overlay=0:'1050+8*(1-min(max(t-0.95\,0)/0.6\,1))':shortest=1,format=yuv420p[v]" \
    -map "[v]" "${ENC[@]}" "$TMP/$out"
}

D=(1.7 2.6 2.0 1.8 2.2 2.4 2.4)
T=(0.45 0.5 0.5 0.5 0.5 0.5)

echo "▸ 1  hook — countdown"; phoneshot p-session.png ${D[0]} ""        in   18  s1.mp4
echo "▸ 2  the door";       phoneshot p-door.png     ${D[1]} ""        out  -15 s2.mp4
echo "▸ 3  Lock Screen";    phoneshot p-lock.png     ${D[2]} ""        in   15  s3.mp4
echo "▸ 4  Dynamic Island"; phoneshot p-island.png   ${D[3]} ""        out  -15 s4.mp4
echo "▸ 5  the week";       phoneshot p-insights.png ${D[4]} ""        in   15  s5.mp4
echo "▸ 6  the proof";      phoneshot p-recap.png    ${D[5]} ""        out  -15 s6.mp4
echo "▸ 7  end card";       end_card                 ${D[6]}                   s7.mp4

read -r FILTER TOTAL < <(python3 - "${D[@]}" -- "${T[@]}" <<'PY'
import sys
a = sys.argv[1:]; d = list(map(float, a[:a.index('--')])); t = list(map(float, a[a.index('--')+1:]))
parts, prev, off = [], "[0:v]", 0.0
for i in range(1, len(d)):
    off += d[i-1] - t[i-1]
    parts.append(f"{prev}[{i}:v]xfade=transition=fade:duration={t[i-1]}:offset={off:.3f}[x{i}]"); prev=f"[x{i}]"
total = off + d[-1]
parts.append(f"{prev}fade=t=out:st={total-0.6:.3f}:d=0.6,format=yuv420p[v]")
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
