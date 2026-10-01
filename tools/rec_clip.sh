#!/usr/bin/env bash
# Uso: tools/rec_clip.sh 06_perro   -> trailer/clips/06_perro.mp4 (1920x1080, 30 fps, sin audio)
set -e
cd "$(dirname "$0")/.."
name="$1"
tmp="${CLAUDE_JOB_DIR:-/tmp}/tmp/rec_$name"
rm -rf "$tmp"; mkdir -p "$tmp" trailer/clips
# override.cfg temporal: ventana de 1080p (el viewport del juego sigue en 1280x720 y se escala)
printf '[display]\n\nwindow/size/window_width_override=1920\nwindow/size/window_height_override=1080\n' > override.cfg
trap 'rm -f override.cfg' EXIT
if godot --headless --path . tools/rec.tscn --quit-after 2 2>&1 | grep -q "Parse Error"; then echo "ERROR: tools/rec.gd no compila"; exit 1; fi
godot --path . tools/rec.tscn --write-movie "$tmp/f.png" --fixed-fps 30 -- clip="$name" 2>&1 | grep -E "SCRIPT ERROR|Parse Error|clip desconocido" || true
ffmpeg -y -loglevel error -framerate 30 -i "$tmp/f%08d.png" -c:v libx264 -crf 14 -preset slow -pix_fmt yuv420p "trailer/clips/$name.mp4"
rm -rf "$tmp"
echo "OK $name: $(ffprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate,duration -of csv=p=0 trailer/clips/$name.mp4)"
