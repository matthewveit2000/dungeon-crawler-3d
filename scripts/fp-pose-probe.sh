#!/usr/bin/env bash
# Fast first-person viewmodel pose probe: renders sampled frames of every first-person move as
# [player view | side view | top view] strips for animation iteration (much faster than a full capture).
# Usage: ./scripts/fp-pose-probe.sh [out_dir] [only_csv]   (sequences: sword,axe,spell,bow,shield,dual)
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-${REPO_ROOT}/.tools/bin/godot}"
OUT_DIR="${1:-${REPO_ROOT}/art/fp_probe}"
rm -rf "${OUT_DIR}"
mkdir -p "${OUT_DIR}"
PROBE_OUT="${OUT_DIR}" PROBE_ONLY="${2:-}" xvfb-run -a -s "-screen 0 640x360x24" \
  "${GODOT_BIN}" --path "${REPO_ROOT}/game" --audio-driver Dummy --rendering-driver opengl3 \
  --resolution 640x360 --windowed res://scenes/fp_pose_probe.tscn
