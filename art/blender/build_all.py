"""Master headless Blender 4.5 LTS asset & preview generator for dungeon-crawler-3d.
Generates procedural PBR textures, exports all 38 .glb assets across Batches 1–3,
writes art/manifest.json, and renders denoised Cycles studio preview sheets.
"""

from __future__ import annotations

import json
import sys
import pathlib

SCRIPT_DIR = pathlib.Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import build_batch1_dungeon
import build_batch2_gear
import build_batch3_actors
from common import MANIFEST_PATH, PREVIEWS_DIR, init_textures, render_batch_preview


def main() -> None:
    init_textures()
    manifest_entries: list[dict] = []

    b1 = build_batch1_dungeon.build_all(manifest_entries)
    b2 = build_batch2_gear.build_all(manifest_entries)
    b3 = build_batch3_actors.build_all(manifest_entries)

    preview_paths = [
        PREVIEWS_DIR / "batch1_dungeon_kit.png",
        PREVIEWS_DIR / "batch2_weapons_gear.png",
        PREVIEWS_DIR / "batch3_characters_enemies.png",
    ]

    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.write_text(
        json.dumps(
            {
                "assets": manifest_entries,
                "previews": [str(p.relative_to(MANIFEST_PATH.parent.parent)) for p in preview_paths],
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"[blender] Wrote manifest with {len(manifest_entries)} textured stylized assets & 3 previews -> {MANIFEST_PATH}")

    render_batch_preview(
        "Batch 1: Nordic-Ruin Modular Dungeon Kit & Setpiece Props",
        b1,
        preview_paths[0],
        spacing=4.8,
        cam_dist=29.5,
        cam_height=17.5,
    )
    render_batch_preview(
        "Batch 2: Weapons, Shield, Bow, Arcane Focus & First-Person Gauntlets",
        b2,
        preview_paths[1],
        spacing=1.65,
        cam_dist=7.0,
        cam_height=2.9,
        single_row=False,
    )
    render_batch_preview(
        "Batch 3: Characters, Enemies, Goblin Streamer, Vendor & Iron Warden Boss",
        b3,
        preview_paths[2],
        spacing=2.35,
        cam_dist=16.5,
        cam_height=3.6,
        single_row=True,
    )


if __name__ == "__main__":
    main()
