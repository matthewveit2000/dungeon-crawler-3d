#!/usr/bin/env python3
"""Generates the shared PBR material texture library for Dungeon Crawler 3D.

Outputs (per material) into game/assets/textures/:
  <name>_albedo.png  (sRGB base colour)
  <name>_normal.png  (OpenGL tangent-space normal)
  <name>_orm.png     (R = ambient occlusion, G = roughness, B = metallic)
  <name>_height.png  (optional, for parallax on floors/walls)
  <name>_emission.png (optional, emissive mask/colour)

Run:  python3 art/pipeline/generate_textures.py [--only name1,name2] [--size 1024] [--preview]
Requires only NumPy + Pillow. Fully deterministic.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys
import time

import numpy as np
from PIL import Image

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import texgen as tg  # noqa: E402

REPO = pathlib.Path(__file__).resolve().parents[2]
OUT_DIR = REPO / "game" / "assets" / "textures"
PREVIEW_DIR = REPO / "art" / "previews"

RECIPES = {}


def recipe(name, size=1024, normal_strength=1.0, height_out=False):
    def deco(fn):
        RECIPES[name] = {"fn": fn, "size": size, "ns": normal_strength, "height": height_out}
        return fn
    return deco


# ---------------------------------------------------------------------------
# STONE
# ---------------------------------------------------------------------------

def _rock_surface(s, seed, stops, pit_count=300, pit_depth=0.14, chisel=0.05, lichen=0.0, warm="#6a5b4c", warm_amt=0.35):
    base = tg.fbm(s, seed, 2.4, 1.0)
    mid = tg.fbm(s, seed + 1, 1.8, 5.0)
    fine = tg.fbm(s, seed + 2, 1.15, 40.0)
    grain = tg.fbm(s, seed + 3, 0.5, 220.0)
    # Sedimentary strata: faint horizontal banding, warped
    strata = tg.fbm(s, seed + 11, 1.6, 3.0, sx=1.0, sy=0.07)
    strata = tg.warp(strata, seed + 12, 0.03, 2.0)
    # Pits & chips with varied size/depth and soft rims
    f1, f2, cid = tg.voronoi(s, seed + 4, pit_count)
    radii = tg.cell_values(cid, seed + 5, pit_count) ** 2 * 0.011 + 0.0015
    depth = tg.cell_values(cid, seed + 6, pit_count)
    pits = tg.smoothstep(0.0, 1.0, 1.0 - f1 / radii) * tg.smoothstep(0.3, 0.9, depth)
    pits = tg.blur(pits.astype(np.float32), 1.2)
    # Chisel / tool marks: soft anisotropic streaks
    chis = tg.fbm(s, seed + 7, 1.3, 16.0, sx=0.15, sy=1.0)
    chis = 1.0 - np.abs(chis - 0.5) * 2.0
    height = 0.38 * base + 0.27 * mid + 0.17 * fine + 0.06 * grain + 0.08 * strata - pit_depth * pits - chisel * chis
    height = tg.normalize(height)
    tone = tg.normalize(0.45 * base + 0.25 * mid + 0.15 * fine + 0.15 * strata)
    alb = tg.colorize(tone, stops)
    # Warm iron-stained patches vs cool slate
    warm_m = tg.smoothstep(0.45, 0.8, tg.fbm(s, seed + 13, 2.6, 1.0)) * warm_amt
    warm_col = alb * (tg.hex_rgb(warm) / max(1e-3, float(tg.hex_rgb(warm).mean())))
    alb = tg.blend(alb, np.clip(warm_col, 0, 1), warm_m)
    # Mineral speckle: tiny light/dark flecks
    spk = tg.fbm(s, seed + 8, 0.15, 260.0)
    alb = tg.overlay_tint(alb, tg.smoothstep(0.3, 0.7, spk), 0.12)
    alb = tg.blend(alb, alb * 1.35, (spk > 0.9).astype(np.float32) * 0.35)
    ao = tg.cavity_ao(height, 4.0, 2.2)
    grime = np.clip((1.0 - ao) * 1.3 + pits * 0.55, 0.0, 1.0)
    alb = tg.blend(alb, alb * np.array([0.5, 0.46, 0.42], np.float32), grime)
    if lichen > 0:
        lm = tg.smoothstep(0.66, 0.80, tg.fbm(s, seed + 9, 2.6, 2.0)) * tg.smoothstep(0.45, 0.7, fine)
        lich = tg.colorize(tg.fbm(s, seed + 10, 1.5, 30.0), [(0.0, "#454c3a"), (1.0, "#727a5c")])
        alb = tg.blend(alb, lich, lm * lichen)
    rough = np.clip(0.78 + 0.10 * (fine - 0.5) + 0.10 * (1.0 - ao) - 0.06 * (base - 0.5), 0.55, 0.97)
    return alb, height, rough, ao


@recipe("stone_block", normal_strength=1.6, height_out=True)
def stone_block(s, seed):
    alb, h, r, ao = _rock_surface(s, seed, [(0.0, "#3b3d42"), (0.35, "#55565a"), (0.7, "#6d6b67"), (1.0, "#86827b")],
                                  lichen=0.35)
    return {"albedo": alb, "height": h, "rough": r, "ao": ao}


@recipe("stone_trim", normal_strength=1.0)
def stone_trim(s, seed):
    alb, h, r, ao = _rock_surface(s, seed, [(0.0, "#2e3034"), (0.5, "#45474c"), (1.0, "#5f5f61")],
                                  pit_count=160, pit_depth=0.12, chisel=0.02)
    r = np.clip(r - 0.08, 0.4, 1.0)
    return {"albedo": alb, "height": h, "rough": r, "ao": ao}


@recipe("stone_floor", normal_strength=1.2, height_out=True)
def stone_floor(s, seed):
    """Foot-worn slab surface: smoother centre, scratches, dirt film."""
    alb, h, r, ao = _rock_surface(s, seed, [(0.0, "#38393c"), (0.4, "#4e4e50"), (0.8, "#67645e"), (1.0, "#7a756c")],
                                  pit_count=260, pit_depth=0.16, chisel=0.015)
    scratches = tg.fbm(s, seed + 20, 0.5, 90.0, sx=1.0, sy=0.06)
    sc = tg.smoothstep(0.78, 0.92, scratches)
    h = np.clip(h - sc * 0.05, 0, 1)
    alb = tg.blend(alb, alb * 1.18, sc * 0.35)
    wear = tg.fbm(s, seed + 21, 2.4, 1.0)
    r = np.clip(r - 0.18 * tg.smoothstep(0.45, 0.85, wear), 0.35, 1.0)
    dirt = tg.smoothstep(0.55, 0.85, tg.fbm(s, seed + 22, 2.0, 2.0))
    alb = tg.blend(alb, alb * np.array([0.62, 0.55, 0.47], np.float32), dirt * 0.55)
    return {"albedo": alb, "height": h, "rough": r, "ao": ao}


@recipe("flagstone", normal_strength=2.2, height_out=True)
def flagstone(s, seed):
    """Dressed flagstone floor: large rectangular-ish slabs with chipped, irregular edges."""
    lay = tg.ashlar_layout(s, seed, rows=4, min_w=0.22, max_w=0.5, row_jitter=0.3)
    u, v = tg.grid(s)
    edge = lay["edge"]
    edge = tg.warp(edge, seed + 3, 0.006, 6.0)
    chip = tg.smoothstep(0.62, 0.8, tg.fbm(s, seed + 4, 1.5, 10.0)) * 0.012
    edge = edge - chip
    groove = 1.0 - tg.smoothstep(0.002, 0.009, edge)
    bevel = tg.smoothstep(0.002, 0.035, edge)
    surf_a, surf_h, surf_r, _ = _rock_surface(s, seed + 5, [(0.0, "#36373a"), (0.45, "#4c4c4d"), (0.8, "#646059"), (1.0, "#77716a")],
                                              pit_count=220, pit_depth=0.1, chisel=0.015)
    n = lay["count"]
    tilt_u = (tg.cell_values(lay["sid"], seed + 9, n) - 0.5) * 0.2
    tilt_v = (tg.cell_values(lay["sid"], seed + 19, n) - 0.5) * 0.2
    slope = tilt_u * (lay["lu"] - 0.5) + tilt_v * (lay["lv"] - 0.5)
    h = bevel * (0.72 + slope + 0.22 * surf_h) - groove * 0.12
    h = tg.normalize(h)
    per = tg.cell_values(lay["sid"], seed + 10, n)
    alb = tg.overlay_tint(surf_a, per, 0.2)
    # foot polish: lighter, smoother centres of slabs
    polish = np.sin(np.pi * lay["lu"]) * np.sin(np.pi * lay["lv"])
    alb = tg.blend(alb, np.minimum(alb * 1.12, 1), polish * 0.4)
    mortar = tg.colorize(tg.fbm(s, seed + 11, 1.0, 60.0), [(0.0, "#1a1816"), (1.0, "#312d28")])
    alb = tg.blend(alb, mortar, groove)
    ao = tg.cavity_ao(h, 6.0, 2.0)
    alb = alb * (0.62 + 0.38 * ao[..., None])
    r = np.clip(surf_r * (1 - groove) + 0.95 * groove - polish * 0.15, 0.35, 1.0)
    return {"albedo": alb, "height": h, "rough": r, "ao": ao}


@recipe("stone_ashlar", normal_strength=2.4, height_out=True)
def stone_ashlar(s, seed):
    lay = tg.ashlar_layout(s, seed, rows=5)
    noise_edge = (tg.fbm(s, seed + 3, 2.0, 8.0) - 0.5) * 0.010
    edge = lay["edge"] + noise_edge
    mortar = 1.0 - tg.smoothstep(0.003, 0.010, edge)
    bevel = tg.smoothstep(0.003, 0.030, edge)
    surf_a, surf_h, surf_r, _ = _rock_surface(s, seed + 7, [(0.0, "#3a3c41"), (0.4, "#525357"), (0.75, "#6a6864"), (1.0, "#807b73")])
    stone_tone = tg.cell_values(lay["sid"], seed + 8, lay["count"])
    pillow = np.sin(np.pi * lay["lu"]) * np.sin(np.pi * lay["lv"])
    h = bevel * (0.62 + 0.18 * pillow + 0.2 * surf_h) - 0.1 * mortar
    h = tg.normalize(h)
    alb = tg.overlay_tint(surf_a, stone_tone, 0.25)
    mort_col = tg.colorize(tg.fbm(s, seed + 11, 1.0, 50.0), [(0.0, "#25221f"), (1.0, "#3c3833")])
    alb = tg.blend(alb, mort_col, mortar)
    ao = tg.cavity_ao(h, 5.0, 2.0)
    alb = alb * (0.6 + 0.4 * ao[..., None])
    r = np.clip(surf_r * (1 - mortar) + 0.96 * mortar, 0.5, 1.0)
    return {"albedo": alb, "height": h, "rough": r, "ao": ao}


@recipe("mortar", size=512, normal_strength=1.2)
def mortar_tex(s, seed):
    h = tg.normalize(0.5 * tg.fbm(s, seed, 1.2, 8.0) + 0.5 * tg.fbm(s, seed + 1, 0.4, 90.0))
    alb = tg.colorize(h, [(0.0, "#1e1b18"), (0.6, "#2f2b26"), (1.0, "#46413a")])
    return {"albedo": alb, "height": h, "rough": np.full_like(h, 0.95), "ao": tg.cavity_ao(h, 3.0, 1.5)}


@recipe("dirt", normal_strength=1.8, height_out=True)
def dirt(s, seed):
    base = tg.fbm(s, seed, 2.0, 2.0)
    f1, f2, cid = tg.voronoi(s, seed + 1, 700)
    peb_r = tg.cell_values(cid, seed + 2, 700) * 0.012 + 0.003
    pebble = tg.smoothstep(0.0, 1.0, 1.0 - f1 / peb_r) * (tg.cell_values(cid, seed + 3, 700) > 0.5)
    fine = tg.fbm(s, seed + 4, 0.8, 120.0)
    h = tg.normalize(0.4 * base + 0.35 * np.sqrt(np.clip(pebble, 0, 1)) + 0.25 * fine)
    alb = tg.colorize(tg.normalize(0.6 * base + 0.4 * fine), [(0.0, "#1f1a16"), (0.5, "#3a3029"), (1.0, "#54493d")])
    peb_col = tg.colorize(tg.cell_values(cid, seed + 5, 700), [(0.0, "#2a2826"), (0.6, "#43403b"), (1.0, "#57524a")])
    alb = tg.blend(alb, peb_col, np.clip(pebble * 1.2, 0, 1) * 0.85)
    ao = tg.cavity_ao(h, 4.0, 2.5)
    r = np.clip(0.92 - 0.15 * pebble, 0.6, 1.0)
    return {"albedo": alb * (0.7 + 0.3 * ao[..., None]), "height": h, "rough": r, "ao": ao}


# ---------------------------------------------------------------------------
# WOOD
# ---------------------------------------------------------------------------

def _wood(s, seed, stops, planks=4, gap=0.003, weather=0.0, knots=3, min_len=0.8, max_len=1.0, lines=46):
    lay = tg.plank_layout(s, seed, planks=planks, min_len=min_len, max_len=max_len)
    u, v = tg.grid(s)
    n = lay["count"]
    pid_off = tg.cell_values(lay["pid"], seed + 2, n)
    # Grain lines run along u. Offset per plank, wobble with low-frequency noise stretched along u.
    wob = (tg.fbm(s, seed + 1, 2.4, 1.0, sx=6.0, sy=1.0) - 0.5) * 0.05
    wob2 = (tg.fbm(s, seed + 3, 2.0, 3.0, sx=5.0, sy=1.0) - 0.5) * 0.01
    # Knots: grain bends around elongated knots
    f1, _, kc = tg.voronoi(s, seed + 4, knots, aspect=(3.0, 1.0))
    kr = 0.016
    knot = tg.smoothstep(0.0, 1.0, 1.0 - f1 / kr)
    swirl = tg.smoothstep(0.0, 1.0, 1.0 - f1 / (kr * 4.0)) * 0.03
    coord = (v + wob + wob2 + swirl + pid_off * 0.37) * lines
    phase = coord - np.floor(coord)
    late = tg.smoothstep(0.55, 0.75, phase) * (1.0 - tg.smoothstep(0.8, 0.98, phase))  # dark latewood band
    pores = tg.fbm(s, seed + 6, 0.4, 260.0, sx=1.0, sy=0.03)
    streak = tg.fbm(s, seed + 7, 1.2, 10.0, sx=1.0, sy=0.05)
    tone = np.clip(0.66 - 0.46 * late + 0.26 * (streak - 0.5) + 0.14 * (pores - 0.5) + 0.2 * (pid_off - 0.5), 0, 1)
    tone = tone * (1 - knot * 0.45)
    alb = tg.colorize(tone, stops)
    e = np.minimum(lay["edge_u"], lay["edge_v"])
    seam = 1.0 - tg.smoothstep(gap * 0.3, gap * 1.6, e)
    edge_bevel = tg.smoothstep(0.0, gap * 5.0, e)
    h = tg.normalize(edge_bevel * (0.8 - 0.06 * late + 0.06 * pores + 0.05 * streak) - knot * 0.05)
    if weather > 0:
        cracks = tg.smoothstep(0.86, 0.95, tg.fbm(s, seed + 8, 1.1, 8.0, sx=1.0, sy=0.03))
        h = np.clip(h - cracks * 0.3 * weather, 0, 1)
        grey = np.dot(alb, np.array([0.3, 0.59, 0.11], np.float32))[..., None] * np.array([0.98, 0.95, 0.9], np.float32)
        wmask = tg.smoothstep(0.3, 0.8, tg.fbm(s, seed + 9, 2.0, 2.0)) * weather
        alb = tg.blend(alb, grey * 1.1, wmask * 0.55)
        alb = tg.blend(alb, alb * 0.35, cracks * weather)
    alb = tg.blend(alb, np.zeros_like(alb) + 0.025, seam * 0.92)
    ao = tg.cavity_ao(h, 4.0, 2.0)
    r = np.clip(0.62 + 0.14 * late + 0.12 * weather + 0.2 * seam, 0.4, 1.0)
    return {"albedo": alb * (0.8 + 0.2 * ao[..., None]), "height": h, "rough": r, "ao": ao}


@recipe("wood_oak", normal_strength=1.3)
def wood_oak(s, seed):
    return _wood(s, seed, [(0.0, "#2a1d14"), (0.45, "#4f3826"), (0.8, "#6b5038"), (1.0, "#7f6346")], planks=3,
                 gap=0.00001, min_len=2.0, max_len=2.0)


@recipe("wood_dark", normal_strength=1.3)
def wood_dark(s, seed):
    return _wood(s, seed, [(0.0, "#140d09"), (0.5, "#2c1d14"), (1.0, "#4a3323")], planks=2, weather=0.25,
                 gap=0.00001, min_len=2.0, max_len=2.0)


@recipe("wood_rough", normal_strength=1.8)
def wood_rough(s, seed):
    return _wood(s, seed, [(0.0, "#2a2119"), (0.5, "#4f4233"), (1.0, "#75644d")], planks=3, weather=0.8, knots=4,
                 gap=0.00001, min_len=2.0, max_len=2.0, lines=38)


@recipe("wood_beam", normal_strength=1.5)
def wood_beam(s, seed):
    """Single continuous timber (no plank seams) for beams, handles, bows."""
    return _wood(s, seed, [(0.0, "#23160d"), (0.5, "#4a3020"), (1.0, "#6e4a2f")], planks=1, gap=0.00001,
                 weather=0.3, min_len=2.0, max_len=2.0)


# ---------------------------------------------------------------------------
# METALS
# ---------------------------------------------------------------------------

@recipe("iron_dark", normal_strength=1.4)
def iron_dark(s, seed):
    f1, f2, cid = tg.voronoi(s, seed, 420)
    hammer = tg.normalize(np.sqrt(f1))
    facet = tg.cell_values(cid, seed + 9, 420)
    base = tg.fbm(s, seed + 1, 2.0, 2.0)
    fine = tg.fbm(s, seed + 2, 0.8, 140.0)
    h = tg.normalize(0.5 * hammer + 0.25 * base + 0.17 * fine + 0.08 * facet)
    cav = 1 - tg.cavity_ao(h, 4, 3)
    rust_m = tg.smoothstep(0.55, 0.78, tg.fbm(s, seed + 3, 1.8, 3.0) * 0.75 + cav * 0.9)
    rust_spots = tg.smoothstep(0.72, 0.85, tg.fbm(s, seed + 6, 1.2, 24.0))
    rust_m = np.clip(rust_m + rust_spots * 0.6, 0, 1)
    metal_col = tg.colorize(tg.normalize(0.55 * base + 0.3 * fine + 0.15 * facet),
                            [(0.0, "#232428"), (0.5, "#3a3b40"), (0.85, "#54565c"), (1.0, "#6a6c72")])
    rust_col = tg.colorize(tg.fbm(s, seed + 4, 1.0, 40.0), [(0.0, "#2e170c"), (0.4, "#5c2c14"), (0.8, "#874521"), (1.0, "#a06536")])
    alb = tg.blend(metal_col, rust_col, rust_m)
    metal = np.clip(0.9 - rust_m * 0.85, 0.0, 1.0)
    rough = np.clip(0.42 + 0.18 * fine + 0.45 * rust_m + 0.1 * hammer, 0.2, 1.0)
    h = np.clip(h + rust_m * 0.1 * tg.fbm(s, seed + 5, 0.5, 200.0), 0, 1)
    ao = tg.cavity_ao(h, 4.0, 1.8)
    return {"albedo": alb, "height": h, "rough": rough, "metal": metal, "ao": ao}


@recipe("steel_blade", normal_strength=0.35)
def steel_blade(s, seed):
    brushed = tg.fbm(s, seed, 0.7, 30.0, sx=1.0, sy=0.02)
    fine = tg.fbm(s, seed + 1, 0.5, 200.0, sx=1.0, sy=0.03)
    scratch = tg.smoothstep(0.86, 0.96, tg.fbm(s, seed + 2, 0.4, 120.0, sx=0.2, sy=1.0))
    stain = tg.smoothstep(0.55, 0.85, tg.fbm(s, seed + 3, 2.2, 2.0))
    h = tg.normalize(0.6 * brushed + 0.4 * fine - scratch * 0.3)
    alb = tg.colorize(tg.normalize(0.7 * brushed + 0.3 * fine), [(0.0, "#8d9198"), (1.0, "#c4c8ce")])
    alb = tg.blend(alb, alb * np.array([0.72, 0.68, 0.62], np.float32), stain * 0.5)
    rough = np.clip(0.22 + 0.10 * fine + 0.18 * stain + 0.12 * scratch, 0.1, 0.8)
    return {"albedo": alb, "height": h, "rough": rough, "metal": np.full_like(h, 1.0), "ao": np.ones_like(h)}


@recipe("steel_armor", normal_strength=0.7)
def steel_armor(s, seed):
    f1, f2, cid = tg.voronoi(s, seed, 160)
    hammer = tg.normalize(np.sqrt(f1)) * 0.5
    brushed = tg.fbm(s, seed + 1, 0.9, 20.0, sx=1.0, sy=0.04)
    scratch = tg.smoothstep(0.88, 0.97, tg.fbm(s, seed + 2, 0.4, 100.0, sx=0.15, sy=1.0))
    grime = tg.smoothstep(0.62, 0.9, tg.fbm(s, seed + 3, 1.6, 4.0)) * 0.7
    h = tg.normalize(0.45 * hammer + 0.45 * brushed - scratch * 0.2)
    alb = tg.colorize(tg.normalize(0.55 * brushed + 0.45 * hammer), [(0.0, "#62666d"), (1.0, "#979ca4")])
    alb = tg.blend(alb, alb * np.array([0.5, 0.47, 0.43], np.float32), grime)
    alb = tg.blend(alb, np.minimum(alb * 1.3, 1.0), scratch * 0.6)
    rough = np.clip(0.34 + 0.25 * grime + 0.1 * brushed - 0.08 * scratch, 0.15, 0.9)
    return {"albedo": alb, "height": h, "rough": rough, "metal": np.clip(0.96 - grime * 0.3, 0, 1), "ao": tg.cavity_ao(h, 4, 1.2)}


@recipe("gold_antique", normal_strength=0.5)
def gold_antique(s, seed):
    base = tg.fbm(s, seed, 2.2, 2.0)
    fine = tg.fbm(s, seed + 1, 0.9, 60.0)
    scratch = tg.smoothstep(0.88, 0.97, tg.fbm(s, seed + 3, 0.4, 100.0, sx=0.15, sy=1.0))
    h = tg.normalize(0.7 * base + 0.3 * fine)
    patina = tg.smoothstep(0.62, 0.9, tg.fbm(s, seed + 2, 1.8, 3.0))
    gold = tg.colorize(tg.normalize(0.75 * base + 0.25 * fine), [(0.0, "#9c7230"), (0.6, "#c99a48"), (1.0, "#e2bb6a")])
    alb = tg.blend(gold, gold * np.array([0.45, 0.36, 0.22], np.float32), patina * 0.65)
    alb = tg.blend(alb, np.minimum(alb * 1.2, 1), scratch * 0.5)
    rough = np.clip(0.26 + 0.08 * fine + 0.3 * patina, 0.12, 0.9)
    return {"albedo": alb, "height": h, "rough": rough, "metal": np.clip(1.0 - patina * 0.35, 0, 1), "ao": np.ones_like(h)}


@recipe("bronze", normal_strength=0.6)
def bronze(s, seed):
    base = tg.fbm(s, seed, 2.2, 2.0)
    fine = tg.fbm(s, seed + 1, 0.9, 60.0)
    h = tg.normalize(0.7 * base + 0.3 * fine)
    verd = tg.smoothstep(0.6, 0.85, tg.fbm(s, seed + 2, 1.6, 4.0))
    bron = tg.colorize(tg.normalize(0.75 * base + 0.25 * fine), [(0.0, "#5e3d1d"), (0.6, "#8a5d2e"), (1.0, "#a87843")])
    verdigris = tg.colorize(fine, [(0.0, "#2f5246"), (1.0, "#5a8a76")])
    alb = tg.blend(bron, verdigris, verd * 0.7)
    rough = np.clip(0.34 + 0.1 * fine + 0.45 * verd, 0.15, 0.95)
    return {"albedo": alb, "height": h, "rough": rough, "metal": np.clip(0.95 - verd, 0, 1), "ao": np.ones_like(h)}


# ---------------------------------------------------------------------------
# ORGANICS & FABRICS
# ---------------------------------------------------------------------------

def _leather(s, seed, stops):
    # Crinkled hide: ridged-noise crease network at two scales + soft wrinkles
    c1 = 1.0 - np.abs(tg.fbm(s, seed, 1.2, 40.0) - 0.5) * 2.0
    c2 = 1.0 - np.abs(tg.fbm(s, seed + 4, 1.0, 90.0) - 0.5) * 2.0
    creases = tg.smoothstep(0.82, 0.97, c1) * 0.7 + tg.smoothstep(0.85, 0.98, c2) * 0.5
    wr = tg.fbm(s, seed + 1, 1.6, 6.0)
    wrinkles = 1.0 - np.abs(tg.fbm(s, seed + 2, 1.8, 8.0, sx=0.4, sy=1.0) - 0.5) * 2
    h = tg.normalize(0.55 - 0.35 * creases + 0.25 * wr - 0.15 * tg.smoothstep(0.85, 1.0, wrinkles))
    wear = tg.smoothstep(0.62, 0.9, tg.fbm(s, seed + 3, 2.0, 3.0))
    alb = tg.colorize(tg.normalize(0.6 * wr + 0.4 * h), stops)
    alb = tg.blend(alb, np.minimum(alb * 1.45, 1), wear * 0.35)
    alb = tg.blend(alb, alb * 0.6, creases * 0.5)
    ao = tg.cavity_ao(h, 3.0, 2.0)
    rough = np.clip(0.6 + 0.18 * creases - 0.2 * wear, 0.35, 0.95)
    return {"albedo": alb, "height": h, "rough": rough, "ao": ao}


@recipe("leather_brown", normal_strength=1.2)
def leather_brown(s, seed):
    return _leather(s, seed, [(0.0, "#2a170c"), (0.5, "#4f2e18"), (1.0, "#764a2a")])


@recipe("leather_dark", normal_strength=1.2)
def leather_dark(s, seed):
    return _leather(s, seed, [(0.0, "#120c09"), (0.5, "#241913"), (1.0, "#3b2a1f")])


def _woven(s, seed, stops, weave=128, fuzz=0.35, pattern=None):
    u, v = tg.grid(s)
    wu = np.sin(u * weave * 2 * np.pi)
    wv = np.sin(v * weave * 2 * np.pi)
    over = (np.sin(u * weave * np.pi) * np.sin(v * weave * np.pi)) > 0
    thread = np.where(over, (wv * 0.5 + 0.5), (wu * 0.5 + 0.5)).astype(np.float32)
    fib = tg.fbm(s, seed, 0.5, 220.0)
    blot = tg.fbm(s, seed + 1, 2.0, 2.0)
    h = tg.normalize(0.7 * thread + 0.3 * fib)
    tone = tg.normalize(0.5 * blot + 0.3 * fib + 0.2 * thread)
    alb = tg.colorize(tone, stops)
    if pattern is not None:
        alb = pattern(alb, u, v)
    dirt = tg.smoothstep(0.55, 0.85, tg.fbm(s, seed + 2, 2.2, 2.0))
    alb = tg.blend(alb, alb * 0.55, dirt * 0.5)
    rough = np.clip(0.86 + 0.1 * fib, 0.6, 1.0)
    return {"albedo": alb, "height": h, "rough": rough, "ao": tg.cavity_ao(h, 1.5, 1.0) * 0.5 + 0.5}


@recipe("cloth_crimson", normal_strength=0.9)
def cloth_crimson(s, seed):
    return _woven(s, seed, [(0.0, "#3a0a0a"), (0.5, "#6e1414"), (1.0, "#93221b")])


@recipe("cloth_linen", normal_strength=1.0)
def cloth_linen(s, seed):
    return _woven(s, seed, [(0.0, "#5a4a36"), (0.5, "#8a7556"), (1.0, "#ab9673")], weave=96)


@recipe("cloth_dark", normal_strength=0.9)
def cloth_dark(s, seed):
    return _woven(s, seed, [(0.0, "#121315"), (0.5, "#22242a"), (1.0, "#363841")])


@recipe("cloth_teal", normal_strength=0.9)
def cloth_teal(s, seed):
    return _woven(s, seed, [(0.0, "#0b2324"), (0.5, "#164447"), (1.0, "#22625f")])


@recipe("cloth_burlap", normal_strength=1.6)
def cloth_burlap(s, seed):
    return _woven(s, seed, [(0.0, "#3b2e1f"), (0.5, "#5f4c34"), (1.0, "#7d6847")], weave=48)


@recipe("fur", normal_strength=2.0)
def fur(s, seed):
    strands = tg.fbm(s, seed, 0.9, 30.0, sx=0.06, sy=1.0)
    clumps = tg.fbm(s, seed + 1, 2.0, 6.0)
    h = tg.normalize(0.7 * strands + 0.3 * clumps)
    alb = tg.colorize(tg.normalize(0.5 * strands + 0.5 * clumps), [(0.0, "#1c140e"), (0.5, "#3e2f22"), (0.85, "#6a5541"), (1.0, "#8e7a61")])
    return {"albedo": alb, "height": h, "rough": np.full_like(h, 0.92), "ao": tg.cavity_ao(h, 2.0, 2.0)}


@recipe("bone", normal_strength=1.0)
def bone(s, seed):
    base = tg.fbm(s, seed, 2.0, 2.0)
    pores = tg.fbm(s, seed + 1, 0.4, 220.0)
    streak = tg.fbm(s, seed + 2, 1.0, 10.0, sx=0.08, sy=1.0)
    h = tg.normalize(0.5 * base + 0.2 * pores + 0.3 * streak)
    ao = tg.cavity_ao(h, 3.0, 2.0)
    alb = tg.colorize(tg.normalize(0.6 * base + 0.4 * streak), [(0.0, "#6d6150"), (0.5, "#a69676"), (1.0, "#cbbf9f")])
    stain = tg.smoothstep(0.55, 0.85, tg.fbm(s, seed + 3, 2.2, 3.0))
    alb = tg.blend(alb, alb * np.array([0.55, 0.45, 0.32], np.float32), np.clip(stain * 0.7 + (1 - ao) * 1.2, 0, 1))
    return {"albedo": alb, "height": h, "rough": np.clip(0.55 + 0.25 * pores, 0.3, 0.9), "ao": ao}


def _skin(s, seed, stops, pores=0.4, mottle_cols=None):
    base = tg.fbm(s, seed, 2.2, 2.0)
    mottle = tg.fbm(s, seed + 1, 1.5, 8.0)
    f1, f2, _ = tg.voronoi(s, seed + 2, 2200)
    pore = tg.smoothstep(0.0, 0.004, f1)
    wr = np.abs(tg.fbm(s, seed + 3, 1.8, 12.0) - 0.5) * 2
    h = tg.normalize(0.4 * base + 0.25 * pore * pores + 0.35 * (1 - wr))
    alb = tg.colorize(tg.normalize(0.5 * base + 0.5 * mottle), stops)
    if mottle_cols:
        m = tg.smoothstep(0.6, 0.85, tg.fbm(s, seed + 4, 1.8, 6.0))
        alb = tg.blend(alb, tg.colorize(mottle, mottle_cols), m * 0.5)
    ao = tg.cavity_ao(h, 2.0, 1.8)
    return {"albedo": alb * (0.8 + 0.2 * ao[..., None]), "height": h, "rough": np.clip(0.55 + 0.2 * (1 - pore) + 0.1 * wr, 0.3, 0.9), "ao": ao}


@recipe("skin_goblin", normal_strength=1.0)
def skin_goblin(s, seed):
    return _skin(s, seed, [(0.0, "#2a3220"), (0.5, "#4a5732"), (1.0, "#68744a")],
                 mottle_cols=[(0.0, "#5a3a2a"), (1.0, "#7a5040")])


@recipe("skin_draugr", normal_strength=1.6)
def skin_draugr(s, seed):
    d = _skin(s, seed, [(0.0, "#1f1c18"), (0.5, "#3e3a31"), (1.0, "#5e584b")],
              mottle_cols=[(0.0, "#2a2e33"), (1.0, "#4a5058")])
    d["rough"] = np.clip(d["rough"] + 0.2, 0, 1)
    return d


@recipe("skin_human", normal_strength=0.6)
def skin_human(s, seed):
    return _skin(s, seed, [(0.0, "#6b4434"), (0.5, "#a06b52"), (1.0, "#c08a6c")], pores=0.25,
                 mottle_cols=[(0.0, "#8a4a3c"), (1.0, "#b06650")])


@recipe("rope", size=512, normal_strength=2.0)
def rope(s, seed):
    u, v = tg.grid(s)
    twist = np.sin((u * 6.0 + v * 2.0) * 2 * np.pi) * 0.5 + 0.5
    fib = tg.fbm(s, seed, 0.6, 120.0, sx=0.2, sy=1.0)
    h = tg.normalize(0.75 * twist + 0.25 * fib)
    alb = tg.colorize(tg.normalize(0.6 * twist + 0.4 * fib), [(0.0, "#2e2416"), (0.6, "#6a5636"), (1.0, "#8e7650")])
    return {"albedo": alb, "height": h, "rough": np.full_like(h, 0.9), "ao": tg.cavity_ao(h, 2.0, 2.0)}


@recipe("wax", size=512, normal_strength=0.6)
def wax(s, seed):
    drips = tg.fbm(s, seed, 1.6, 4.0, sx=0.2, sy=1.0)
    h = tg.normalize(drips)
    alb = tg.colorize(h, [(0.0, "#b9a582"), (1.0, "#e7dcc0")])
    return {"albedo": alb, "height": h, "rough": np.full_like(h, 0.45), "ao": np.ones_like(h)}


@recipe("parchment", normal_strength=0.8)
def parchment(s, seed):
    base = tg.fbm(s, seed, 2.0, 2.0)
    fib = tg.fbm(s, seed + 1, 0.6, 160.0)
    stains = tg.smoothstep(0.55, 0.85, tg.fbm(s, seed + 2, 2.4, 3.0))
    alb = tg.colorize(tg.normalize(0.7 * base + 0.3 * fib), [(0.0, "#8a7350"), (0.5, "#b9a277"), (1.0, "#d6c49b")])
    alb = tg.blend(alb, alb * np.array([0.7, 0.55, 0.38], np.float32), stains * 0.6)
    # Scribbled handwriting rows (illegible, procedural)
    u, v = tg.grid(s)
    rows = 18
    row = (v * rows) % 1.0
    line = tg.smoothstep(0.35, 0.45, row) * (1 - tg.smoothstep(0.55, 0.65, row))
    ink_noise = tg.fbm(s, seed + 3, 0.2, 260.0, sx=1.0, sy=0.15)
    words = tg.smoothstep(0.35, 0.55, tg.fbm(s, seed + 4, 1.0, 24.0, sx=1.0, sy=0.02))
    margin = tg.smoothstep(0.08, 0.1, u) * (1 - tg.smoothstep(0.9, 0.92, u)) * tg.smoothstep(0.08, 0.1, v) * (1 - tg.smoothstep(0.9, 0.92, v))
    ink = line * tg.smoothstep(0.45, 0.62, ink_noise) * words * margin
    alb = tg.blend(alb, np.array([0.12, 0.08, 0.05], np.float32) + np.zeros_like(alb), ink * 0.85)
    h = tg.normalize(0.7 * base + 0.3 * fib)
    return {"albedo": alb, "height": h, "rough": np.full_like(h, 0.88), "ao": np.ones_like(h)}


# ---------------------------------------------------------------------------
# EMISSIVE / SPECIAL
# ---------------------------------------------------------------------------

def _rune_glyphs(s, seed, count=26):
    """Procedural angular rune strokes (original glyphs) on a periodic canvas."""
    from PIL import ImageDraw
    img = Image.new("L", (s, s), 0)
    d = ImageDraw.Draw(img)
    r = tg.rng(seed)
    cell = s // 6
    for gy in range(6):
        for gx in range(6):
            if r.random() < 0.15:
                continue
            cx = gx * cell + cell // 2
            cy = gy * cell + cell // 2
            hgt = cell * 0.36
            w = max(2, s // 220)
            # stave
            d.line([(cx, cy - hgt), (cx, cy + hgt)], fill=255, width=w)
            for _ in range(int(r.integers(1, 4))):
                y0 = cy + float(r.uniform(-hgt, hgt * 0.6))
                side = 1 if r.random() < 0.5 else -1
                ln = float(r.uniform(0.3, 0.7)) * hgt
                d.line([(cx, y0), (cx + side * ln, y0 + float(r.uniform(-0.6, 0.6)) * ln)], fill=255, width=w)
    a = np.asarray(img, dtype=np.float32) / 255.0
    return a


@recipe("rune_stone", normal_strength=1.4)
def rune_stone(s, seed):
    alb, h, r, ao = _rock_surface(s, seed, [(0.0, "#24262b"), (0.5, "#383a40"), (1.0, "#4d4f55")], pit_count=200)
    glyph = _rune_glyphs(s, seed + 50)
    glow = tg.blur(glyph, 1.2)
    h = np.clip(h - glyph * 0.35, 0, 1)
    emit = np.clip(glow * 1.4, 0, 1)
    alb = tg.blend(alb, alb * 0.3, glyph)
    return {"albedo": alb, "height": h, "rough": r, "ao": ao, "emission": np.stack([emit, emit, emit], -1)}


@recipe("embers", size=512, normal_strength=1.5)
def embers(s, seed):
    f1, f2, cid = tg.voronoi(s, seed, 160)
    coal = tg.smoothstep(0.0, 0.02, f2 - f1)
    heat = tg.fbm(s, seed + 1, 1.8, 4.0)
    h = tg.normalize(coal * (0.6 + 0.4 * tg.cell_values(cid, seed + 2, 160)))
    alb = tg.colorize(heat, [(0.0, "#0c0908"), (1.0, "#2a1c16")])
    emit_t = np.clip((1 - coal) * 1.6 + tg.smoothstep(0.55, 0.85, heat) * 0.6, 0, 1)
    emis = tg.colorize(emit_t, [(0.0, "#000000"), (0.4, "#5a1204"), (0.75, "#e0480c"), (1.0, "#ffb347")])
    return {"albedo": alb, "height": h, "rough": np.full_like(h, 0.9), "ao": np.ones_like(h), "emission": emis}


@recipe("banner_crimson", size=1024, normal_strength=0.8)
def banner_crimson(s, seed):
    """Unique (non-tiling) war banner: crimson field, gold border, original crowned-skull-and-axes sigil."""
    from PIL import ImageDraw
    d = _woven(s, seed, [(0.0, "#3a0909"), (0.5, "#6a1313"), (1.0, "#8e2019")])
    sig = Image.new("L", (s, s), 0)
    dr = ImageDraw.Draw(sig)
    b = int(s * 0.05)
    dr.rectangle([b, b, s - b, s - b], outline=255, width=int(s * 0.018))
    dr.rectangle([b * 2, b * 2, s - b * 2, s - b * 2], outline=255, width=int(s * 0.006))
    cx, cy = s // 2, int(s * 0.45)
    R = int(s * 0.17)
    # skull dome
    dr.ellipse([cx - R, cy - R, cx + R, cy + int(R * 0.9)], fill=255)
    dr.rectangle([cx - int(R * 0.62), cy + int(R * 0.5), cx + int(R * 0.62), cy + int(R * 1.2)], fill=255)
    # eye sockets & nose (cut out)
    er = int(R * 0.28)
    dr.ellipse([cx - int(R * 0.55) - er, cy - er // 2, cx - int(R * 0.55) + er, cy + int(er * 1.4)], fill=0)
    dr.ellipse([cx + int(R * 0.55) - er, cy - er // 2, cx + int(R * 0.55) + er, cy + int(er * 1.4)], fill=0)
    dr.polygon([(cx, cy + int(R * 0.45)), (cx - int(R * 0.14), cy + int(R * 0.75)), (cx + int(R * 0.14), cy + int(R * 0.75))], fill=0)
    for i in range(-2, 3):
        x = cx + i * int(R * 0.24)
        dr.line([(x, cy + int(R * 0.9)), (x, cy + int(R * 1.2))], fill=0, width=max(2, s // 180))
    # crown
    pts = [(cx - R, cy - int(R * 0.8))]
    for i in range(5):
        x0 = cx - R + i * (2 * R) // 5
        pts += [(x0 + R // 5, cy - int(R * 1.55)), (x0 + 2 * R // 5, cy - int(R * 0.95))]
    pts += [(cx + R, cy - int(R * 0.8))]
    dr.polygon(pts, fill=255)
    # crossed axes
    for sgn in (-1, 1):
        dr.line([(cx - sgn * int(R * 2.1), cy + int(R * 2.2)), (cx + sgn * int(R * 1.9), cy - int(R * 1.6))], fill=255, width=int(s * 0.02))
        hx, hy = cx + sgn * int(R * 1.75), cy - int(R * 1.35)
        dr.pieslice([hx - int(R * 0.6), hy - int(R * 0.6), hx + int(R * 0.6), hy + int(R * 0.6)],
                    start=(200 if sgn > 0 else -20), end=(340 if sgn > 0 else 120), fill=255)
    # knotwork band
    for k in range(10):
        x = int(s * 0.1) + k * int(s * 0.08)
        dr.arc([x, int(s * 0.80), x + int(s * 0.08), int(s * 0.86)], 0, 180, fill=255, width=max(2, s // 160))
        dr.arc([x, int(s * 0.83), x + int(s * 0.08), int(s * 0.89)], 180, 360, fill=255, width=max(2, s // 160))
    m = np.asarray(sig, dtype=np.float32) / 255.0
    m = tg.blur(m, 0.8)
    gold = tg.colorize(tg.fbm(s, seed + 9, 1.0, 40.0), [(0.0, "#8a6424"), (1.0, "#d4a548")])
    d["albedo"] = tg.blend(d["albedo"], gold, m)
    d["height"] = np.clip(d["height"] * 0.7 + m * 0.3, 0, 1)
    d["rough"] = np.clip(d["rough"] - m * 0.25, 0, 1)
    return d


@recipe("rug_crimson", size=1024, normal_strength=0.8)
def rug_crimson(s, seed):
    """Unique woven rug: crimson field, interlaced gold/indigo borders, central diamond medallions."""
    def pattern(alb, u, v):
        cu = np.abs(u - 0.5)
        cv = np.abs(v - 0.5)
        border = np.maximum(cu, cv)
        out = alb.copy()
        band1 = (border > 0.42) & (border < 0.47)
        band2 = (border > 0.36) & (border < 0.38)
        gold = np.array([0.62, 0.45, 0.16], np.float32)
        indigo = np.array([0.08, 0.10, 0.22], np.float32)
        out[band1] = out[band1] * 0.3 + indigo * 0.9
        zig = (np.sin((u + v) * 80.0) > 0.4) & band1
        out[zig] = gold
        out[band2] = gold * 0.9
        diamond = (cu + cv * 0.6)
        med = (diamond < 0.16) & (diamond > 0.12)
        out[med] = gold
        inner = diamond < 0.08
        out[inner] = indigo * 1.3
        dots = (np.sin(u * 60) * np.sin(v * 60) > 0.92) & (border < 0.34)
        out[dots] = gold * 0.8
        edge = border > 0.485
        out[edge] = out[edge] * 0.4
        return out
    return _woven(s, seed, [(0.0, "#3d0b0b"), (0.5, "#6a1616"), (1.0, "#86201a")], weave=160, pattern=pattern)


# ---------------------------------------------------------------------------
# VFX sprites (RGBA, premultiplied-friendly, used with additive/mix blending)
# ---------------------------------------------------------------------------

def vfx_flame(frames=8, cell=128, seed=7):
    """8x8 looping flame flipbook: teardrop body with rising, licking tongues (loops seamlessly)."""
    s = cell
    n1 = tg.fbm(256, seed, 1.7, 2.0)
    n2 = tg.fbm(256, seed + 1, 1.4, 5.0)
    n3 = tg.fbm(256, seed + 2, 1.2, 9.0)
    yy, xx = np.meshgrid((np.arange(s) + 0.5) / s, (np.arange(s) + 0.5) / s, indexing="ij")
    y = 1.0 - yy            # 0 bottom .. 1 top
    x = (xx - 0.5) * 2.0    # -1 .. 1
    sheet = np.zeros((s * frames, s * frames, 4), np.float32)
    total = frames * frames
    H = 0.92
    for i in range(total):
        t = i / total
        # Rising turbulence (periodic in t so the flipbook loops)
        na = tg.sample_wrap(n1, xx * 0.7, yy * 0.6 + t)
        nb = tg.sample_wrap(n2, xx * 1.0 + 0.31, yy * 0.9 + t * 2.0)
        nc = tg.sample_wrap(n3, xx * 1.4 + 0.71, yy * 1.2 + t * 3.0)
        turb = 0.5 * na + 0.32 * nb + 0.18 * nc
        yn = np.clip(y / H, 0.0, 1.0)
        sway = (tg.sample_wrap(n1, np.full_like(xx, 0.21), yy * 0.35 + t) - 0.5) * 0.55 * yn ** 1.5
        xd = np.abs(x - sway - (turb - 0.5) * 0.35 * yn)
        radius = 0.95 * np.power(yn + 0.03, 0.42) * np.power(np.clip(1.0 - yn, 0, 1), 0.9)
        body = 1.0 - tg.smoothstep(radius * 0.45, radius + 0.02, xd)
        # erosion grows with height -> tongues at top, solid at base
        thresh = 0.18 + 0.62 * yn ** 1.3
        erode = tg.smoothstep(thresh - 0.08, thresh + 0.10, turb + 0.25)
        dens = np.clip(body * erode * 1.25, 0.0, 1.0)
        # hot core: inner, lower part
        core = (1.0 - tg.smoothstep(0.0, radius * 0.55 + 0.01, xd)) * (1.0 - tg.smoothstep(0.15, 0.6, yn))
        heat = np.clip(dens * (0.55 - 0.35 * yn) + core * 0.6, 0, 1)
        col = tg.colorize(heat, [(0.0, "#2a0500"), (0.22, "#9c2304"), (0.45, "#e8640f"), (0.7, "#ffad3d"), (0.9, "#ffe7a8"), (1.0, "#fffaf0")])
        a = np.clip(dens * (0.85 + 0.15 * core), 0, 1)
        fy, fx = divmod(i, frames)
        sheet[fy * s:(fy + 1) * s, fx * s:(fx + 1) * s, :3] = col
        sheet[fy * s:(fy + 1) * s, fx * s:(fx + 1) * s, 3] = a
    return sheet


def vfx_smoke(frames=4, cell=256, seed=21):
    s = cell
    sheet = np.zeros((s * frames, s * frames, 4), np.float32)
    yy, xx = np.meshgrid((np.arange(s) + 0.5) / s, (np.arange(s) + 0.5) / s, indexing="ij")
    r = np.sqrt((xx - 0.5) ** 2 + (yy - 0.5) ** 2)
    for i in range(frames * frames):
        n = tg.fbm(s, seed + i, 1.8, 2.0)
        m = (1.0 - tg.smoothstep(0.15, 0.5, r + (n - 0.5) * 0.3)) * tg.smoothstep(0.25, 0.75, n + 0.2)
        g = 0.55 + 0.45 * n
        fy, fx = divmod(i, frames)
        sheet[fy * s:(fy + 1) * s, fx * s:(fx + 1) * s, 0] = g
        sheet[fy * s:(fy + 1) * s, fx * s:(fx + 1) * s, 1] = g
        sheet[fy * s:(fy + 1) * s, fx * s:(fx + 1) * s, 2] = g
        sheet[fy * s:(fy + 1) * s, fx * s:(fx + 1) * s, 3] = np.clip(m, 0, 1)
    return sheet


def vfx_radial(size=128, power=2.2, core=0.0):
    yy, xx = np.meshgrid((np.arange(size) + 0.5) / size, (np.arange(size) + 0.5) / size, indexing="ij")
    r = np.clip(np.sqrt((xx - 0.5) ** 2 + (yy - 0.5) ** 2) * 2.0, 0, 1)
    a = np.power(1.0 - r, power)
    if core > 0:
        a = np.clip(a + core * (1.0 - tg.smoothstep(0.0, 0.15, r)), 0, 1)
    out = np.ones((size, size, 4), np.float32)
    out[..., 3] = a
    return out


def vfx_spark(size=64):
    yy, xx = np.meshgrid((np.arange(size) + 0.5) / size, (np.arange(size) + 0.5) / size, indexing="ij")
    d = np.sqrt(((xx - 0.5) * 4.0) ** 2 + ((yy - 0.5) * 1.0) ** 2) * 2.0
    a = np.clip(1.0 - d, 0, 1) ** 1.5
    out = np.ones((size, size, 4), np.float32)
    out[..., 3] = a
    return out


def vfx_cobweb(size=512, seed=33):
    from PIL import ImageDraw
    img = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(img)
    r = tg.rng(seed)
    # corner-anchored web: radial spokes from top-left corner + sagging catenary threads
    ox, oy = 0, 0
    spokes = 9
    angles = np.linspace(0.02, np.pi / 2 - 0.02, spokes) + r.uniform(-0.04, 0.04, spokes)
    lens = r.uniform(0.75, 1.0, spokes) * size * 1.05
    ends = [(ox + np.cos(a) * l, oy + np.sin(a) * l) for a, l in zip(angles, lens)]
    for e in ends:
        d.line([(ox, oy), e], fill=200, width=2)
    rings = 11
    for k in range(1, rings + 1):
        frac = k / (rings + 1)
        pts = []
        for j, (a, l) in enumerate(zip(angles, lens)):
            rr = frac * l * r.uniform(0.95, 1.05)
            pts.append((ox + np.cos(a) * rr, oy + np.sin(a) * rr))
        for j in range(len(pts) - 1):
            (x0, y0), (x1, y1) = pts[j], pts[j + 1]
            mx, my = (x0 + x1) / 2, (y0 + y1) / 2
            sag = 0.12 * frac * size * 0.1
            d.line([(x0, y0), (mx + sag * 0.7, my + sag * 0.7), (x1, y1)], fill=170, width=1)
    a = np.asarray(img, np.float32) / 255.0
    a = np.clip(tg.blur(a, 0.6) * 1.6, 0, 1)
    dust = tg.fbm(size, seed + 1, 2.0, 2.0)
    out = np.ones((size, size, 4), np.float32) * np.array([0.82, 0.8, 0.76, 1.0], np.float32)
    out[..., 3] = a * (0.55 + 0.45 * dust)
    return out


def vfx_caustic_glow(size=256, seed=41):
    """Soft volumetric light-shaft card texture (vertical gradient with wisps)."""
    n = tg.fbm(size, seed, 1.4, 2.0, sx=1.0, sy=0.15)
    yy, xx = np.meshgrid((np.arange(size) + 0.5) / size, (np.arange(size) + 0.5) / size, indexing="ij")
    edge = 1.0 - np.abs(xx - 0.5) * 2.0
    a = np.clip(edge ** 1.5 * (1.0 - yy) ** 1.2 * (0.6 + 0.4 * n), 0, 1)
    out = np.ones((size, size, 4), np.float32)
    out[..., 3] = a
    return out


def build_vfx():
    vdir = REPO / "game" / "assets" / "vfx"
    vdir.mkdir(parents=True, exist_ok=True)
    save_rgba(vdir / "flame_flipbook.webp", vfx_flame())
    save_rgba(vdir / "smoke_flipbook.webp", vfx_smoke())
    save_rgba(vdir / "soft_glow.webp", vfx_radial(128, 2.4))
    save_rgba(vdir / "hot_core.webp", vfx_radial(128, 3.0, core=0.8))
    save_rgba(vdir / "spark.webp", vfx_spark())
    save_rgba(vdir / "dust_mote.webp", vfx_radial(32, 1.6))
    save_rgba(vdir / "cobweb.webp", vfx_cobweb())
    save_rgba(vdir / "light_shaft.webp", vfx_caustic_glow())
    print("[textures] vfx sprites ->", vdir)


# ---------------------------------------------------------------------------
# Writer
# ---------------------------------------------------------------------------

WEBP_Q = 88


def save_rgb(path, arr):
    Image.fromarray(tg.to_u8(arr), "RGB").save(path, "WEBP", quality=WEBP_Q, method=6)


def save_l(path, arr):
    Image.fromarray(tg.to_u8(arr), "L").convert("RGB").save(path, "WEBP", quality=WEBP_Q, method=6)


def save_rgba(path, arr):
    Image.fromarray(tg.to_u8(arr), "RGBA").save(path, "WEBP", lossless=True, method=6)


def build(name, size_override=None, write=True):
    spec = RECIPES[name]
    size = size_override or spec["size"]
    seed = abs(hash(name)) % 100000 if False else sum(ord(c) * (i + 7) for i, c in enumerate(name)) * 131
    t0 = time.time()
    d = spec["fn"](size, seed)
    alb = np.clip(d["albedo"], 0, 1)
    h = np.clip(d["height"], 0, 1)
    rough = np.clip(d.get("rough", np.full_like(h, 0.8)), 0, 1)
    metal = np.clip(d.get("metal", np.zeros_like(h)), 0, 1)
    ao = np.clip(d.get("ao", np.ones_like(h)), 0, 1)
    normal = tg.height_to_normal(h, spec["ns"])
    orm = np.stack([ao, rough, metal], -1)
    if write:
        save_rgb(OUT_DIR / f"{name}_albedo.webp", alb)
        save_rgb(OUT_DIR / f"{name}_normal.webp", normal)
        save_rgb(OUT_DIR / f"{name}_orm.webp", orm)
        if spec["height"]:
            save_l(OUT_DIR / f"{name}_height.webp", h)
        if "emission" in d:
            save_rgb(OUT_DIR / f"{name}_emission.webp", d["emission"])
    print(f"[textures] {name:16s} {size}px  {time.time() - t0:5.1f}s")
    return alb, normal, orm


def preview(names):
    tiles = []
    for n in names:
        p = OUT_DIR / f"{n}_albedo.webp"
        if not p.exists():
            continue
        a = Image.open(p).convert("RGB").resize((256, 256))
        nm = Image.open(OUT_DIR / f"{n}_normal.webp").convert("RGB").resize((256, 256))
        o = Image.open(OUT_DIR / f"{n}_orm.webp").convert("RGB").resize((256, 256))
        strip = Image.new("RGB", (768, 256))
        strip.paste(a, (0, 0))
        strip.paste(nm, (256, 0))
        strip.paste(o, (512, 0))
        tiles.append((n, strip))
    cols = 2
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new("RGB", (768 * cols, 276 * rows), (20, 20, 24))
    from PIL import ImageDraw
    dr = ImageDraw.Draw(sheet)
    for i, (n, st) in enumerate(tiles):
        x = (i % cols) * 768
        y = (i // cols) * 276
        sheet.paste(st, (x, y + 20))
        dr.text((x + 6, y + 4), n, fill=(230, 210, 160))
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    out = PREVIEW_DIR / "texture_library.png"
    sheet.save(out)
    print(f"[textures] preview -> {out}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--size", type=int, default=0)
    ap.add_argument("--preview", action="store_true")
    ap.add_argument("--vfx", action="store_true")
    args = ap.parse_args()
    if args.vfx:
        build_vfx()
        if not args.only:
            return
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    names = [n for n in RECIPES if not args.only or n in args.only.split(",")]
    for n in names:
        build(n, args.size or None)
    manifest = {n: {"size": args.size or RECIPES[n]["size"], "height": RECIPES[n]["height"]} for n in RECIPES}
    (OUT_DIR / "texture_manifest.json").write_text(json.dumps(manifest, indent=1))
    if args.preview:
        preview(list(RECIPES.keys()))


if __name__ == "__main__":
    main()
