#!/usr/bin/env bash
# Captures deterministic 24-FPS MP4 video clips of EVERY animation in the game
# for thorough visual review of timing, physics, weight, and silhouettes.
#
# Usage:
#   ./scripts/record-anim-review.sh [out_dir] [only_csv]
# Example:
#   ./scripts/record-anim-review.sh /tmp/anim_before
#   ANIM_QUALITY=1 ./scripts/record-anim-review.sh /tmp/anim_iter char_draugr,fp_sword_shield
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-${REPO_ROOT}/.tools/bin/godot}"
OUT_DIR="${1:-${REPO_ROOT}/art/anim_review}"
ONLY="${2:-${ANIM_ONLY:-}}"
FPS="${ANIM_FPS:-24}"
if [[ -z "${RENDER:-}" ]]; then
  if ls /usr/share/vulkan/icd.d/*.json >/dev/null 2>&1; then
    RENDER="vulkan"
  else
    RENDER="opengl3"
  fi
fi
RES="${ANIM_RES:-960x540}"

rm -rf "${OUT_DIR}"
mkdir -p "${OUT_DIR}"

# Ensure newly exported Blender .glb animations/meshes are freshly imported into .godot/imported/
"${GODOT_BIN}" --headless --path "${REPO_ROOT}/game" --import >/dev/null 2>&1 || true

echo "[anim-review] Capturing (${RES} @ ${FPS}fps, ${RENDER}, only='${ONLY:-ALL}') -> ${OUT_DIR}"
ANIM_OUT="${OUT_DIR}" ANIM_ONLY="${ONLY}" ANIM_FPS="${FPS}" \
  xvfb-run -a -s "-screen 0 ${RES}x24" \
  "${GODOT_BIN}" --path "${REPO_ROOT}/game" \
  --audio-driver Dummy \
  --rendering-driver "${RENDER}" \
  --resolution "${RES}" \
  --windowed \
  --fixed-fps "${FPS}" \
  res://scenes/anim_review.tscn

for d in "${OUT_DIR}"/*/; do
  [[ -d "${d}" ]] || continue
  name="$(basename "${d}")"
  if ls "${d}/frame_"*.png >/dev/null 2>&1; then
    ffmpeg -y -framerate "${FPS}" -i "${d}/frame_%04d.png" \
      -c:v libx264 -pix_fmt yuv420p -crf 20 -movflags +faststart \
      "${OUT_DIR}/${name}.mp4" >/dev/null 2>&1
    rm -rf "${d}"
    echo "[anim-review] Encoded: ${OUT_DIR}/${name}.mp4"
  fi
done

ls -lh "${OUT_DIR}"/*.mp4 2>/dev/null || true
