#!/usr/bin/env bash
# Captures live Player-POV screenshots and a 2-second motion MP4 video of the actual
# running 3D Godot game inside Xvfb + OpenGL3 (no physical monitor/GPU required).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-${REPO_ROOT}/.tools/bin/godot}"
OUT_DIR="${REPO_ROOT}/art/visual_qa"

rm -rf "${OUT_DIR}"
mkdir -p "${OUT_DIR}/frames"

echo "[visual-qa] Running Godot 4.7 live visual capture (1280x720, OpenGL3 via Xvfb)..."
xvfb-run -a -s "-screen 0 1280x720x24" \
  "${GODOT_BIN}" --path "${REPO_ROOT}/game" \
  --rendering-driver opengl3 \
  --resolution 1280x720 \
  --windowed \
  res://scenes/visual_qa_capture.tscn

if command -v ffmpeg >/dev/null 2>&1 && ls "${OUT_DIR}/frames/frame_"*.png >/dev/null 2>&1; then
  ffmpeg -y -framerate 12 -i "${OUT_DIR}/frames/frame_%03d.png" \
    -c:v libx264 -pix_fmt yuv420p -crf 20 "${OUT_DIR}/combat_motion.mp4" >/dev/null 2>&1
  echo "[visual-qa] Encoded motion video: ${OUT_DIR}/combat_motion.mp4"
fi

ls -lh "${OUT_DIR}"/*.png "${OUT_DIR}"/*.mp4 2>/dev/null || true
