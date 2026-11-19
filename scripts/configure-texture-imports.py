#!/usr/bin/env python3
"""Pins Godot import settings for the generated texture library & VFX sprites.

Godot creates default .import files (lossless, no mipmaps) the first time it sees an image.
For 3D materials we want VRAM compression + mipmaps (and RGTC for normal maps); VFX sprites keep
lossless alpha with mipmaps. Run after adding textures, then re-run `godot --headless --import`.
"""
import pathlib
import re
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent
RULES = [
    ("game/assets/textures", lambda n: n.endswith("_normal.webp"), {"compress/mode": "2", "compress/normal_map": "1", "mipmaps/generate": "true", "detect_3d/compress_to": "0"}),
    ("game/assets/textures", lambda n: n.endswith(".webp"), {"compress/mode": "2", "compress/normal_map": "2", "mipmaps/generate": "true", "detect_3d/compress_to": "0"}),
    ("game/assets/vfx", lambda n: n.endswith(".webp"), {"compress/mode": "0", "mipmaps/generate": "true", "detect_3d/compress_to": "0"}),
]


def patch(path: pathlib.Path, params: dict) -> bool:
    txt = path.read_text()
    orig = txt
    for k, v in params.items():
        pat = re.compile(rf"^{re.escape(k)}=.*$", re.M)
        if pat.search(txt):
            txt = pat.sub(f"{k}={v}", txt)
        else:
            txt = txt.rstrip("\n") + f"\n{k}={v}\n"
    if txt != orig:
        path.write_text(txt)
        return True
    return False


def main() -> int:
    changed = 0
    missing = 0
    for folder, match, params in RULES:
        d = REPO / folder
        if not d.exists():
            continue
        for img in sorted(d.iterdir()):
            if not match(img.name):
                continue
            imp = img.with_name(img.name + ".import")
            if not imp.exists():
                missing += 1
                continue
            already = getattr(main, "_done", set())
            if imp in already:
                continue
            already.add(imp)
            main._done = already
            if patch(imp, params):
                changed += 1
    print(f"[texture-imports] patched {changed} .import files ({missing} images not yet imported)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
