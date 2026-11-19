#!/usr/bin/env python3
"""Validates the 3D art library, materials, textures, icons, UI kit and fonts.

Checks (all must pass in CI):
  * art/manifest.json lists every exported .glb with a valid glTF 2.0 binary header & length
  * per-category triangle budgets and non-degenerate bounding boxes
  * every rigged character ships the required animation clips
  * every material name used by a model exists in game/data/materials.json
  * every textured material has albedo / normal / ORM maps on disk
  * items.json / enemies.json / setpieces.json reference existing models & icons
  * preview sheets exist (PNG), UI kit images exist, fonts ship with their OFL licences
"""

import json
import pathlib
import struct
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent
MANIFEST = REPO / "art" / "manifest.json"
PNG_SIG = b"\x89PNG\r\n\x1a\n"

BUDGETS = {"kit": 20000, "props": 30000, "gear": 12000, "characters": 32000}
REQUIRED_CATEGORIES = {"kit": 12, "props": 20, "gear": 20, "characters": 6}
REQUIRED_CLIPS = {"idle", "walk", "run", "attack", "hit", "death"}
UI_REQUIRED = ["panel_frame", "panel_soft", "card", "button_normal", "button_hover", "button_pressed", "button_disabled",
               "slot_bg", "slot_border", "bar_frame", "bar_fill", "divider", "vignette", "keycap", "compass_bg", "crest",
               "icon_skull", "icon_shield", "icon_stairs", "icon_player", "icon_coin", "check_on", "check_off", "slider_grabber"]


def glb_ok(path: pathlib.Path) -> str:
    raw = path.read_bytes()
    if len(raw) < 20 or raw[:4] != b"glTF":
        return "invalid GLB header"
    version, declared = struct.unpack("<II", raw[4:12])
    if version != 2 or declared != len(raw):
        return "corrupt GLB v2 length/header"
    return ""


def main() -> int:
    errors: list[str] = []
    if not MANIFEST.exists():
        print(f"[ERROR] Missing {MANIFEST}", file=sys.stderr)
        return 1
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    assets = manifest.get("assets", [])
    previews = manifest.get("previews", [])
    mats = json.loads((REPO / "game" / "data" / "materials.json").read_text())["materials"]
    counts: dict[str, int] = {}

    for e in assets:
        batch = e.get("batch", "")
        counts[batch] = counts.get(batch, 0) + 1
        p = REPO / e["path"]
        if not p.exists():
            errors.append(f"Missing exported asset: {e['path']}")
            continue
        msg = glb_ok(p)
        if msg:
            errors.append(f"{msg}: {e['path']}")
        tris = int(e.get("triangles", 0))
        if tris <= 0 or tris > BUDGETS.get(batch, 30000):
            errors.append(f"Triangle budget out of range ({tris} > {BUDGETS.get(batch)}) for {e['path']}")
        if any(float(d) <= 0 for d in e.get("dimensions_xyz_m", [0, 0, 0])):
            errors.append(f"Degenerate bounding box for {e['path']}")
        for m in e.get("materials", []):
            base = m.split(".")[0]
            if base not in mats:
                errors.append(f"{e['path']} uses material '{m}' missing from materials.json")
        if batch == "characters":
            clips = set(e.get("animations", []))
            missing = REQUIRED_CLIPS - clips
            if missing:
                errors.append(f"{e['path']} missing animation clips: {sorted(missing)}")

    for cat, need in REQUIRED_CATEGORIES.items():
        if counts.get(cat, 0) < need:
            errors.append(f"Expected >= {need} '{cat}' assets, found {counts.get(cat, 0)}")

    for name, d in mats.items():
        tex = d.get("tex")
        if not tex:
            continue
        for suffix in ("albedo", "normal", "orm"):
            tp = REPO / "game" / "assets" / "textures" / f"{tex}_{suffix}.webp"
            if not tp.exists():
                errors.append(f"Material '{name}' missing texture {tp.relative_to(REPO)}")

    for rel in previews:
        pp = REPO / rel
        if not pp.exists():
            errors.append(f"Missing preview render: {rel}")
        elif pp.read_bytes()[:8] != PNG_SIG:
            errors.append(f"Invalid PNG preview: {rel}")
    if len(previews) < 4:
        errors.append(f"Expected >= 4 preview sheets, found {len(previews)}")

    for data_name, key in (("items.json", "items"), ("enemies.json", "enemies")):
        pack = json.loads((REPO / "game" / "data" / data_name).read_text())
        for obj in pack.get(key, []):
            for field in ("model", "icon"):
                ref = obj.get(field, "")
                if ref and not (REPO / ref.replace("res://", "game/")).exists():
                    errors.append(f"{data_name} '{obj['id']}' {field} missing: {ref}")
            vis = obj.get("visual", {})
            if vis.get("weapon") and not (REPO / vis["weapon"].replace("res://", "game/")).exists():
                errors.append(f"{data_name} '{obj['id']}' weapon model missing: {vis['weapon']}")
    sp = json.loads((REPO / "game" / "data" / "setpieces.json").read_text())
    for sname, sdef in sp.get("setpieces", {}).items():
        for prop in sdef.get("props", []):
            ref = prop.get("model", "")
            if ref and not (REPO / ref.replace("res://", "game/")).exists():
                errors.append(f"setpiece '{sname}' references missing model {ref}")

    for ui in UI_REQUIRED:
        if not (REPO / "game" / "assets" / "ui" / f"{ui}.png").exists():
            errors.append(f"Missing UI art: game/assets/ui/{ui}.png")
    fonts = REPO / "game" / "assets" / "fonts"
    for fam in ("cinzel", "alegreya", "barlow-condensed", "cinzel-decorative"):
        if not list(fonts.glob(f"{fam}-latin-*.woff2")):
            errors.append(f"Missing font files for {fam}")
        if not (fonts / f"OFL-{fam}.txt").exists():
            errors.append(f"Missing OFL licence for {fam}")

    if errors:
        for e in errors:
            print(f"[ASSET ERROR] {e}", file=sys.stderr)
        return 1
    print(f"[validate-assets] OK: {len(assets)} GLB models ({counts}), {len(mats)} materials, "
          f"{len(previews)} previews, UI kit & fonts verified.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
