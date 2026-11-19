#!/usr/bin/env bash
# Master local & CI automated verification entrypoint.
# Runs:
#   1. Tier 3 JSON data pack schema & cross-reference validation
#   2. Multi-AI & architecture hygiene checks
#   3. Exported Blender .glb asset validation (when manifest/assets exist)
#   4. Godot 4 headless resource import + full GUT unit & integration test suite

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-${REPO_ROOT}/.tools/bin/godot}"

if [[ ! -x "${GODOT_BIN}" ]]; then
  if command -v godot >/dev/null 2>&1; then
    GODOT_BIN="$(command -v godot)"
  else
    echo "[run-tests] Godot binary not found. Run ./scripts/setup-tools.sh first." >&2
    exit 1
  fi
fi

echo "=== [1/5] Validating Tier 3 JSON Data Packs ==="
python3 "${REPO_ROOT}/scripts/validate-data.py"

echo "=== [2/5] Running Repo & Architecture Hygiene Checks ==="
python3 "${REPO_ROOT}/scripts/check-repo-hygiene.py"

if [[ -f "${REPO_ROOT}/scripts/validate-assets.py" && -f "${REPO_ROOT}/art/manifest.json" ]]; then
  echo "=== [3/5] Validating Blender .glb Assets & Previews ==="
  python3 "${REPO_ROOT}/scripts/validate-assets.py"
else
  echo "=== [3/5] Asset manifest not present yet (skipping until Phase 2) ==="
fi

echo "=== [4/5] Running Godot 4 Headless Import & Main Scene Boot Smoke Check ==="
"${GODOT_BIN}" --headless --path "${REPO_ROOT}/game" --import --quit >/dev/null 2>&1 || true
BOOT_OUT="$("${GODOT_BIN}" --headless --path "${REPO_ROOT}/game" --quit-after 20 res://scenes/main.tscn 2>&1)"
echo "${BOOT_OUT}"
if echo "${BOOT_OUT}" | grep -E "SCRIPT ERROR|Parse Error|Compile Error|^ERROR:" >/dev/null; then
  echo "[run-tests] FAIL: Godot reported errors while booting res://scenes/main.tscn!" >&2
  exit 1
fi
echo "[boot-smoke] OK: res://scenes/main.tscn booted headlessly for 20 frames with zero errors."

echo "=== [5/5] Running Full GUT Unit & Headless 3D Integration Test Suite ==="
GUT_LOG="$(mktemp)"
trap 'rm -f "${GUT_LOG}"' EXIT
"${GODOT_BIN}" --headless --path "${REPO_ROOT}/game" -s addons/gut/gut_cmdln.gd -gexit 2>&1 | tee "${GUT_LOG}"
GUT_EXIT="${PIPESTATUS[0]}"
if [[ "${GUT_EXIT}" -ne 0 ]]; then
  exit "${GUT_EXIT}"
fi
if grep -E "SCRIPT ERROR|Parse Error|Compile Error|Failed to load script|Ignoring script" "${GUT_LOG}" >/dev/null; then
  echo "[run-tests] FAIL: GUT reported script parse/load errors or ignored a test file!" >&2
  exit 1
fi

echo "=== ALL AUTOMATED CHECKS PASSED ==="
