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

echo "=== [1/4] Validating Tier 3 JSON Data Packs ==="
python3 "${REPO_ROOT}/scripts/validate-data.py"

echo "=== [2/4] Running Repo & Architecture Hygiene Checks ==="
python3 "${REPO_ROOT}/scripts/check-repo-hygiene.py"

if [[ -f "${REPO_ROOT}/scripts/validate-assets.py" && -f "${REPO_ROOT}/art/manifest.json" ]]; then
  echo "=== [3/4] Validating Blender .glb Assets & Previews ==="
  python3 "${REPO_ROOT}/scripts/validate-assets.py"
else
  echo "=== [3/4] Asset manifest not present yet (skipping until Phase 2) ==="
fi

echo "=== [4/4] Running Godot 4 Headless Import & Full GUT Test Suite ==="
"${GODOT_BIN}" --headless --path "${REPO_ROOT}/game" --import --quit >/dev/null 2>&1 || true
"${GODOT_BIN}" --headless --path "${REPO_ROOT}/game" -s addons/gut/gut_cmdln.gd -gexit

echo "=== ALL AUTOMATED CHECKS PASSED ==="
