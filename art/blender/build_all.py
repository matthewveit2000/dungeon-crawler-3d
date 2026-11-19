"""Rebuilds the entire 100% original 3D art library headlessly (deterministic).

  ./.tools/bin/blender --background --python art/blender/build_all.py            # models only
  ./.tools/bin/blender --background --python art/blender/build_all.py -- --full  # + preview sheets & icons

Batches (each also runnable on its own with --only / --preview):
  build_environment.py  kit/       modular walls, floors, coffered ceilings, columns, doorway arches
  build_props.py        props/     torches, braziers, chest (animated lid), barrels, gates, setpieces, dressing
  build_gear.py         gear/      weapons, shield, bow (pullable string), tomes, potions, armour, 1st-person arms
  build_characters.py   characters/ rigged & animated player, enemies, boss and vendor

Textures (art/pipeline/generate_textures.py) and UI art (art/pipeline/generate_ui.py) are generated with
NumPy + Pillow outside Blender. Stale manifest entries are pruned at the end.
"""

from __future__ import annotations

import json
import pathlib
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parents[1]
BLENDER = pathlib.Path(sys.argv[0]) if sys.argv and sys.argv[0].endswith("blender") else REPO / ".tools" / "bin" / "blender"


def run(script: str, extra: list[str]) -> None:
    cmd = [str(BLENDER), "--background", "--python", str(HERE / script), "--"] + extra
    print("[build_all]", " ".join(cmd[-3:]))
    subprocess.run(cmd, check=True)


def prune_manifest() -> None:
    mf = REPO / "art" / "manifest.json"
    data = json.loads(mf.read_text())
    data["assets"] = [a for a in data.get("assets", []) if (REPO / a["path"]).exists()]
    data["previews"] = [p for p in data.get("previews", []) if (REPO / p).exists() and "_strip_" not in p]
    mf.write_text(json.dumps(data, indent=2))
    print(f"[build_all] manifest: {len(data['assets'])} assets, {len(data['previews'])} previews")


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    full = "--full" in argv
    run("build_environment.py", ["--preview"] if full else [])
    run("build_props.py", ["--preview"] if full else [])
    run("build_gear.py", (["--preview", "--icons"] if full else []))
    run("build_characters.py", ["--preview"] if full else [])
    prune_manifest()


if __name__ == "__main__":
    main()
