#!/usr/bin/env bash
# Installs pinned open-source toolchain locally into .tools/ (gitignored)
# and ensures GUT (Godot Unit Test) addon is present in game/addons/gut/.
#
# Usage:
#   ./scripts/setup-tools.sh              # Install Godot + GUT + Blender
#   ./scripts/setup-tools.sh --godot-only # Install Godot + GUT only (fast CI mode)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="${REPO_ROOT}/.tools"
GODOT_VERSION="4.7.2-stable"
GUT_VERSION="9.7.1"
BLENDER_MAJOR_MINOR="4.5"
BLENDER_VERSION="4.5.9"

INSTALL_BLENDER=1
for arg in "$@"; do
  case "$arg" in
    --godot-only) INSTALL_BLENDER=0 ;;
    *) echo "Unknown flag: $arg" >&2; exit 1 ;;
  esac
done

mkdir -p "${TOOLS_DIR}/bin"

# 1. Godot 4.7.2-stable (Linux x86_64)
GODOT_BIN="${TOOLS_DIR}/godot/Godot_v${GODOT_VERSION}_linux.x86_64"
if [[ ! -x "${GODOT_BIN}" ]]; then
  echo "[setup-tools] Downloading Godot ${GODOT_VERSION}..."
  mkdir -p "${TOOLS_DIR}/godot"
  GODOT_ZIP="${TOOLS_DIR}/godot.zip"
  curl -fsSL "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip" -o "${GODOT_ZIP}"
  python3 -c "import zipfile, sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "${GODOT_ZIP}" "${TOOLS_DIR}/godot"
  rm -f "${GODOT_ZIP}"
  chmod +x "${GODOT_BIN}"
fi
ln -sf "${GODOT_BIN}" "${TOOLS_DIR}/bin/godot"
echo "[setup-tools] Godot ready: $("${TOOLS_DIR}/bin/godot" --headless --version)"

# 2. GUT (Godot Unit Test) v9.7.1
GUT_DIR="${REPO_ROOT}/game/addons/gut"
if [[ ! -f "${GUT_DIR}/gut_cmdln.gd" ]]; then
  echo "[setup-tools] Installing GUT v${GUT_VERSION} into game/addons/gut/..."
  mkdir -p "${REPO_ROOT}/game/addons"
  GUT_ZIP="${TOOLS_DIR}/gut.zip"
  curl -fsSL "https://github.com/bitwes/Gut/archive/refs/tags/v${GUT_VERSION}.zip" -o "${GUT_ZIP}"
  python3 -c "
import zipfile, shutil, pathlib, sys
zip_path, dst_dir = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
tmp = zip_path.parent / 'gut_extract'
if tmp.exists(): shutil.rmtree(tmp)
zipfile.ZipFile(zip_path).extractall(tmp)
src = next(tmp.glob('Gut-*/addons/gut'))
if dst_dir.exists(): shutil.rmtree(dst_dir)
shutil.copytree(src, dst_dir)
shutil.rmtree(tmp)
" "${GUT_ZIP}" "${GUT_DIR}"
  rm -f "${GUT_ZIP}"
fi
echo "[setup-tools] GUT v${GUT_VERSION} ready at game/addons/gut/"

# 3. Blender 4.5.9 LTS (Linux x64)
if [[ "${INSTALL_BLENDER}" -eq 1 ]]; then
  BLENDER_BIN="${TOOLS_DIR}/blender/blender-${BLENDER_VERSION}-linux-x64/blender"
  if [[ ! -x "${BLENDER_BIN}" ]]; then
    echo "[setup-tools] Downloading Blender ${BLENDER_VERSION} LTS..."
    mkdir -p "${TOOLS_DIR}/blender"
    BLENDER_TAR="${TOOLS_DIR}/blender.tar.xz"
    curl -fsSL "https://download.blender.org/release/Blender${BLENDER_MAJOR_MINOR}/blender-${BLENDER_VERSION}-linux-x64.tar.xz" -o "${BLENDER_TAR}"
    tar -xf "${BLENDER_TAR}" -C "${TOOLS_DIR}/blender"
    rm -f "${BLENDER_TAR}"
  fi
  ln -sf "${BLENDER_BIN}" "${TOOLS_DIR}/bin/blender"
  echo "[setup-tools] Blender ready: $("${TOOLS_DIR}/bin/blender" --version | head -n 1)"
fi

echo "[setup-tools] All tools verified."
