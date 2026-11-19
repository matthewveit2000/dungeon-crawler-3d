#!/usr/bin/env python3
"""Validates all Blender-exported .glb assets, preview PNGs, and art/manifest.json."""

import json
import pathlib
import struct
import sys

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
MANIFEST_PATH = REPO_ROOT / "art" / "manifest.json"
PNG_SIG = b"\x89PNG\r\n\x1a\n"


def main() -> int:
    errors: list[str] = []
    if not MANIFEST_PATH.exists():
        print(f"[ERROR] Missing {MANIFEST_PATH}", file=sys.stderr)
        return 1

    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    assets = manifest.get("assets", [])
    previews = manifest.get("previews", [])

    if len(assets) < 25:
        errors.append(f"Expected >= 25 Blender assets across 3 batches, found {len(assets)}")
    if len(previews) < 3:
        errors.append(f"Expected 3 batch preview PNGs, found {len(previews)}")

    for entry in assets:
        fpath = REPO_ROOT / entry["path"]
        if not fpath.exists():
            errors.append(f"Missing exported asset: {entry['path']}")
            continue
        raw = fpath.read_bytes()
        if len(raw) < 20 or raw[:4] != b"glTF":
            errors.append(f"Invalid GLB binary header: {entry['path']}")
            continue
        version, declared_len = struct.unpack("<II", raw[4:12])
        if version != 2 or declared_len != len(raw):
            errors.append(f"Corrupt GLB v2 length/header in {entry['path']}")
        tris = int(entry.get("triangles", 0))
        if tris <= 0 or tris > 25000:
            errors.append(f"Triangle budget out of range ({tris}) for {entry['path']}")
        dims = entry.get("dimensions_xyz_m", [0, 0, 0])
        if any(d <= 0 for d in dims):
            errors.append(f"Zero/negative bounding box {dims} for {entry['path']}")

    for rel_png in previews:
        ppath = REPO_ROOT / rel_png
        if not ppath.exists():
            errors.append(f"Missing batch preview render: {rel_png}")
            continue
        head = ppath.read_bytes()[:8]
        if head != PNG_SIG:
            errors.append(f"Invalid PNG preview file: {rel_png}")

    # Cross-check model references inside items.json and enemies.json
    for data_name in ("items.json", "enemies.json"):
        pack = json.loads((REPO_ROOT / "game" / "data" / data_name).read_text(encoding="utf-8"))
        key = "items" if data_name == "items.json" else "enemies"
        for obj in pack.get(key, []):
            model_res = obj.get("model", "")
            if model_res:
                rel = model_res.replace("res://", "game/")
                if not (REPO_ROOT / rel).exists():
                    errors.append(f"{data_name} '{obj['id']}' references missing model: {rel}")

    if errors:
        for e in errors:
            print(f"[ASSET ERROR] {e}", file=sys.stderr)
        return 1

    print(f"[validate-assets] OK: {len(assets)} GLB models & {len(previews)} studio PNG previews verified.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
