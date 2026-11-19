"""Deterministic procedural PBR texture generator (Albedo + Normal + Roughness)
using NumPy + Blender's native Image writer. Produces rich stylized dark-fantasy
surfaces (Nordic ashlar stone, carved flagstones, aged oak planks, hammered forged
steel, antique bronze/gold, and woven crimson cloth) embedded cleanly into every .glb.
"""

from __future__ import annotations

import pathlib
import bpy
import numpy as np

TEX_DIR = pathlib.Path(__file__).resolve().parent.parent / "textures"


def _fbm(size: int, seed: int, octaves: int = 4, base_freq: int = 4) -> np.ndarray:
    """Fast tileable periodic fractal value noise in [0, 1]."""
    rng = np.random.default_rng(seed)
    acc = np.zeros((size, size), dtype=np.float32)
    amp = 0.5
    norm = 0.0
    for o in range(octaves):
        freq = base_freq * (2 ** o)
        grid = rng.random((freq, freq), dtype=np.float32)
        ys = np.linspace(0.0, freq, size, endpoint=False)
        xs = np.linspace(0.0, freq, size, endpoint=False)
        yi = np.floor(ys).astype(np.int32)
        xi = np.floor(xs).astype(np.int32)
        yf = (ys - yi)[:, None]
        xf = (xs - xi)[None, :]
        # Smoothstep interpolation
        u = xf * xf * (3.0 - 2.0 * xf)
        v = yf * yf * (3.0 - 2.0 * yf)
        y0 = yi % freq
        y1 = (yi + 1) % freq
        x0 = xi % freq
        x1 = (xi + 1) % freq
        c00 = grid[np.ix_(y0, x0)]
        c10 = grid[np.ix_(y0, x1)]
        c01 = grid[np.ix_(y1, x0)]
        c11 = grid[np.ix_(y1, x1)]
        interp = (c00 * (1.0 - u) + c10 * u) * (1.0 - v) + (c01 * (1.0 - u) + c11 * u) * v
        acc += interp * amp
        norm += amp
        amp *= 0.5
    return np.clip(acc / max(norm, 1e-6), 0.0, 1.0)


def _height_to_normal(height: np.ndarray, strength: float = 3.0) -> np.ndarray:
    """Convert periodic heightmap [0,1] into tangent-space RGB normal map [0,1]."""
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5 * strength
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5 * strength
    nx = -dx
    ny = -dy
    nz = np.ones_like(height)
    length = np.sqrt(nx * nx + ny * ny + nz * nz) + 1e-6
    r = (nx / length) * 0.5 + 0.5
    g = (ny / length) * 0.5 + 0.5
    b = (nz / length) * 0.5 + 0.5
    return np.stack([r, g, b], axis=-1).astype(np.float32)


def _save_png(rgb_or_gray: np.ndarray, path: pathlib.Path, non_color: bool = False) -> pathlib.Path:
    h, w = rgb_or_gray.shape[:2]
    if rgb_or_gray.ndim == 2:
        rgba = np.stack([rgb_or_gray, rgb_or_gray, rgb_or_gray, np.ones_like(rgb_or_gray)], axis=-1)
    else:
        rgba = np.concatenate([rgb_or_gray, np.ones((h, w, 1), dtype=np.float32)], axis=-1)
    rgba = np.clip(rgba, 0.0, 1.0).astype(np.float32)

    img_name = path.name
    old = bpy.data.images.get(img_name)
    if old is not None:
        bpy.data.images.remove(old)
    img = bpy.data.images.new(img_name, width=w, height=h, alpha=False, float_buffer=False)
    img.colorspace_settings.name = "Non-Color" if non_color else "sRGB"
    img.pixels.foreach_set(rgba.ravel())
    img.filepath_raw = str(path)
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    return path


def _build_nordic_stone(size: int = 256) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Carved Nordic ashlar masonry blocks with bevelled mortar seams, stone grain & subtle moss."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    rows = 6
    cols = 3
    row_id = np.floor(y * rows)
    x_shift = (x + (row_id % 2) * 0.5 / cols) % 1.0
    u_local = (x_shift * cols) % 1.0
    v_local = (y * rows) % 1.0

    # Organic wobble on mortar seams
    wobble = (_fbm(size, 101, 3, 6) - 0.5) * 0.03
    edge_u = np.minimum(u_local, 1.0 - u_local) + wobble
    edge_v = np.minimum(v_local, 1.0 - v_local) + wobble * 0.7
    mortar = np.clip(np.minimum(edge_u / 0.055, edge_v / 0.075), 0.0, 1.0)
    mortar = mortar * mortar * (3.0 - 2.0 * mortar)

    # Per-stone tonal variation
    col_id = np.floor(x_shift * cols).astype(np.int32)
    block_hash = ((row_id.astype(np.int32) * 37 + col_id * 91) % 17) / 17.0
    grain = _fbm(size, 102, 5, 8)
    fine = _fbm(size, 103, 3, 24)
    moss_mask = np.clip((_fbm(size, 104, 3, 5) - 0.62) * 3.0, 0.0, 1.0) * (1.0 - mortar * 0.55)

    height = mortar * (0.62 + 0.25 * grain + 0.13 * fine)
    # Rich cool-warm dark slate granite (bright enough to catch torchlight & rim lights!)
    base_r = (0.27 + 0.12 * block_hash + 0.12 * grain) * (0.38 + 0.62 * mortar)
    base_g = (0.28 + 0.11 * block_hash + 0.11 * grain) * (0.40 + 0.60 * mortar)
    base_b = (0.32 + 0.10 * block_hash + 0.12 * grain) * (0.42 + 0.58 * mortar)

    # Subtle weathered moss in crevices
    r = base_r * (1.0 - moss_mask * 0.45) + 0.18 * moss_mask * 0.45
    g = base_g * (1.0 - moss_mask * 0.45) + 0.29 * moss_mask * 0.45
    b = base_b * (1.0 - moss_mask * 0.45) + 0.19 * moss_mask * 0.45

    albedo = np.stack([r, g, b], axis=-1)
    rough = np.clip(0.88 - 0.28 * mortar * (0.4 + 0.6 * fine) + 0.10 * moss_mask, 0.42, 0.96)
    return albedo, _height_to_normal(height, 4.2), rough


def _build_flagstone_floor(size: int = 256) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Large worn Nordic flagstones with carved diamond center medallion & warm dust crevices."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    u = (x * 2.0) % 1.0
    v = (y * 2.0) % 1.0
    wob = (_fbm(size, 201, 3, 6) - 0.5) * 0.025
    eu = np.minimum(u, 1.0 - u) + wob
    ev = np.minimum(v, 1.0 - v) + wob
    seam = np.clip(np.minimum(eu / 0.045, ev / 0.045), 0.0, 1.0)
    seam = seam * seam * (3.0 - 2.0 * seam)

    # Subtle carved border inset groove
    inset = np.abs(np.minimum(eu, ev) - 0.12)
    carve = np.clip(inset / 0.018, 0.55, 1.0)

    grain = _fbm(size, 202, 5, 8)
    wear = _fbm(size, 203, 3, 4)
    height = seam * carve * (0.65 + 0.35 * grain)

    r = (0.30 + 0.13 * grain + 0.05 * wear) * (0.34 + 0.66 * seam) * (0.82 + 0.18 * carve)
    g = (0.30 + 0.12 * grain + 0.04 * wear) * (0.35 + 0.65 * seam) * (0.82 + 0.18 * carve)
    b = (0.33 + 0.12 * grain + 0.04 * wear) * (0.38 + 0.62 * seam) * (0.82 + 0.18 * carve)

    albedo = np.stack([r, g, b], axis=-1)
    # Foot-worn centers slightly glossier to reflect warm torchlight!
    rough = np.clip(0.84 - 0.32 * seam * wear, 0.38, 0.94)
    return albedo, _height_to_normal(height, 3.8), rough


def _build_aged_oak(size: int = 256) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Warm weathered Nordic oak planks with elongated wood grain & dark iron plank joints."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    n1 = _fbm(size, 301, 4, 4)
    # Stretched rings along Y for vertical wood grain
    rings = np.sin((x * 18.0 + n1 * 4.2) * np.pi * 2.0) * 0.5 + 0.5
    fine = _fbm(size, 302, 3, 16)
    planks = 5
    pu = (x * planks) % 1.0
    seam = np.clip(np.minimum(pu, 1.0 - pu) / 0.04, 0.0, 1.0)
    seam = seam * seam * (3.0 - 2.0 * seam)

    wood_val = 0.55 * rings + 0.30 * n1 + 0.15 * fine
    height = seam * (0.55 + 0.45 * wood_val)

    r = (0.28 + 0.24 * wood_val) * (0.35 + 0.65 * seam)
    g = (0.17 + 0.16 * wood_val) * (0.35 + 0.65 * seam)
    b = (0.09 + 0.08 * wood_val) * (0.35 + 0.65 * seam)
    albedo = np.stack([r, g, b], axis=-1)
    rough = np.clip(0.76 - 0.22 * wood_val, 0.44, 0.88)
    return albedo, _height_to_normal(height, 3.2), rough


def _build_forged_steel(size: int = 256) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Hammered brushed Nordic iron-steel with subtle pitting & gleaming edge sheen."""
    hammer = _fbm(size, 401, 4, 10)
    fine = _fbm(size, 402, 4, 24)
    # Subtle directional grind scratches
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    brush = np.sin((y * 42.0 + fine * 3.0) * np.pi) * 0.5 + 0.5
    val = 0.48 * hammer + 0.32 * fine + 0.20 * brush

    r = 0.48 + 0.26 * val
    g = 0.51 + 0.26 * val
    b = 0.56 + 0.27 * val
    albedo = np.stack([r, g, b], axis=-1)
    rough = np.clip(0.46 - 0.22 * val, 0.18, 0.58)
    return albedo, _height_to_normal(val, 2.2), rough


def _build_antique_gold(size: int = 256) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Hammered antique Nordic bronze-gold with engraved warm patina."""
    hammer = _fbm(size, 501, 4, 8)
    fine = _fbm(size, 502, 3, 20)
    val = 0.65 * hammer + 0.35 * fine

    r = 0.72 + 0.24 * val
    g = 0.52 + 0.24 * val
    b = 0.19 + 0.16 * val
    albedo = np.stack([r, g, b], axis=-1)
    rough = np.clip(0.42 - 0.20 * val, 0.16, 0.52)
    return albedo, _height_to_normal(val, 2.0), rough


def _build_woven_crimson(size: int = 256) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Rich woven dark-crimson banner/cloak/rug wool with warm gold border trim."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    weave = (np.sin(x * 96.0 * np.pi) * np.sin(y * 96.0 * np.pi)) * 0.5 + 0.5
    wear = _fbm(size, 601, 4, 6)
    border = ((x < 0.09) | (x > 0.91)).astype(np.float32)
    inner_line = (((x > 0.11) & (x < 0.14)) | ((x > 0.86) & (x < 0.89))).astype(np.float32)
    gold_mask = np.clip(border * 0.75 + inner_line, 0.0, 1.0)

    cloth_r = 0.46 + 0.16 * wear + 0.05 * weave
    cloth_g = 0.08 + 0.05 * wear + 0.02 * weave
    cloth_b = 0.10 + 0.05 * wear + 0.02 * weave

    r = cloth_r * (1.0 - gold_mask) + (0.84 + 0.10 * wear) * gold_mask
    g = cloth_g * (1.0 - gold_mask) + (0.64 + 0.10 * wear) * gold_mask
    b = cloth_b * (1.0 - gold_mask) + (0.24 + 0.08 * wear) * gold_mask
    albedo = np.stack([r, g, b], axis=-1)
    height = 0.5 * weave + 0.3 * wear + 0.2 * gold_mask
    rough = np.clip(0.88 - 0.35 * gold_mask - 0.08 * weave, 0.42, 0.95)
    return albedo, _height_to_normal(height, 2.4), rough


def ensure_textures(size: int = 256) -> dict[str, dict[str, pathlib.Path]]:
    """Generates and caches all 6 procedural PBR texture sets on disk."""
    TEX_DIR.mkdir(parents=True, exist_ok=True)
    builders = {
        "nordic_stone": _build_nordic_stone,
        "flagstone_floor": _build_flagstone_floor,
        "aged_oak": _build_aged_oak,
        "forged_steel": _build_forged_steel,
        "antique_gold": _build_antique_gold,
        "woven_crimson": _build_woven_crimson,
    }
    out: dict[str, dict[str, pathlib.Path]] = {}
    for name, fn in builders.items():
        albedo_p = TEX_DIR / f"{name}_albedo.png"
        normal_p = TEX_DIR / f"{name}_normal.png"
        rough_p = TEX_DIR / f"{name}_rough.png"
        albedo, normal, rough = fn(size)
        _save_png(albedo, albedo_p, non_color=False)
        _save_png(normal, normal_p, non_color=True)
        _save_png(rough, rough_p, non_color=True)
        out[name] = {"albedo": albedo_p, "normal": normal_p, "roughness": rough_p}
    print(f"[blender-tex] Generated {len(out)} seamless PBR texture sets ({size}x{size}) in {TEX_DIR}")
    return out
