#!/usr/bin/env bash
# Captures live Player-POV screenshots and a combat motion MP4 of the actual running game (D-028).
# Default renderer: Vulkan Forward+ (the desktop target). Without a GPU it runs on Mesa lavapipe inside
# Xvfb (slow but faithful). RENDER=opengl3 captures the Compatibility fallback renderer instead.
# QA_ONLY=fp,menus limits the capture to selected groups (title, fp, tp, enemies, corridor, safe, boss, menus, motion).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-${REPO_ROOT}/.tools/bin/godot}"
OUT_DIR="${REPO_ROOT}/art/visual_qa"
RENDER="${RENDER:-vulkan}"

rm -rf "${OUT_DIR}"
mkdir -p "${OUT_DIR}/frames"

echo "[visual-qa] Running live capture (1280x720, ${RENDER})..."
xvfb-run -a -s "-screen 0 1280x720x24" \
  "${GODOT_BIN}" --path "${REPO_ROOT}/game" \
  --rendering-driver "${RENDER}" \
  --resolution 1280x720 \
  --windowed \
  res://scenes/visual_qa_capture.tscn

if command -v ffmpeg >/dev/null 2>&1 && ls "${OUT_DIR}/frames/frame_"*.png >/dev/null 2>&1; then
  ffmpeg -y -framerate 12 -i "${OUT_DIR}/frames/frame_%03d.png" \
    -c:v libx264 -pix_fmt yuv420p -crf 20 "${OUT_DIR}/combat_motion.mp4" >/dev/null 2>&1
  echo "[visual-qa] Encoded motion video: ${OUT_DIR}/combat_motion.mp4"
fi

ls -lh "${OUT_DIR}"/*.png "${OUT_DIR}"/*.mp4 2>/dev/null || true
