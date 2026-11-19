"""Master headless Blender 4.5 LTS build script.
Builds all 3 v0.1 asset batches into game/assets/models/, renders Cycles studio
preview sheets to art/previews/, and writes art/manifest.json.

Run via:
  .tools/bin/blender --background --python art/blender/build_all.py
"""

import pathlib
import sys

SCRIPT_DIR = pathlib.Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from common import PREVIEWS_DIR, render_batch_preview, save_manifest
from build_batch1_dungeon import build_all_batch1
from build_batch2_gear import build_all_batch2
from build_batch3_actors import build_all_batch3


def main() -> None:
    manifest_entries: list[dict] = []

    b1_paths = build_all_batch1(manifest_entries)
    b2_paths = build_all_batch2(manifest_entries)
    b3_paths = build_all_batch3(manifest_entries)

    preview_files = [
        PREVIEWS_DIR / "batch1_dungeon_kit.png",
        PREVIEWS_DIR / "batch2_weapons_gear.png",
        PREVIEWS_DIR / "batch3_characters_enemies.png",
    ]

    render_batch_preview("Batch 1: Modular Nordic-Ruin Dungeon Kit", b1_paths, preview_files[0], spacing=5.2, cam_dist=26.0, cam_height=13.5)
    render_batch_preview("Batch 2: Weapons, Shield, Spells & Loot", b2_paths, preview_files[1], spacing=2.0, cam_dist=7.5, cam_height=3.6)
    render_batch_preview("Batch 3: Crawler, Enemies, Boss & Vendor", b3_paths, preview_files[2], spacing=2.3, cam_dist=13.5, cam_height=3.6, single_row=True)

    rel_previews = [f"art/previews/{p.name}" for p in preview_files]
    save_manifest(manifest_entries, rel_previews)


if __name__ == "__main__":
    main()
