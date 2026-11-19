"""Batch 2: Skyrim Weapons, Shield, Bow, Arrow, Spell Focus, Potion & Sponsored Mythic Gear."""

import math
import pathlib
from common import (
    add_box,
    add_cone,
    add_cylinder,
    add_sphere,
    add_torus,
    export_asset,
    palette,
    reset_scene,
)


def build_iron_sword() -> None:
    reset_scene()
    p = palette()
    add_cylinder("Grip", (0, 0, 0.14), 0.028, 0.28, p["leather"], vertices=10)
    add_sphere("Pommel", (0, 0, 0.0), 0.055, p["bronze"])
    add_box("Crossguard", (0, 0, 0.30), (0.34, 0.06, 0.055), p["iron_dark"], bevel=0.01)
    add_box("BladeBase", (0, 0, 0.72), (0.095, 0.024, 0.82), p["steel"], bevel=0.008)
    add_cone("BladeTip", (0, 0, 1.24), 0.055, 0.004, 0.24, p["steel"], vertices=4)


def build_war_axe() -> None:
    reset_scene()
    p = palette()
    add_cylinder("Haft", (0, 0, 0.68), 0.032, 1.38, p["wood_dark"], vertices=10)
    add_cylinder("ButtCap", (0, 0, 0.02), 0.044, 0.08, p["iron_dark"], vertices=10)
    add_box("AxeSocket", (0, 0, 1.18), (0.14, 0.12, 0.22), p["iron_dark"], bevel=0.015)
    add_box("AxeBladeR", (0.24, 0, 1.14), (0.36, 0.045, 0.42), p["steel"], rot=(0, math.radians(-10), 0), bevel=0.012)
    add_box("AxeBladeL", (-0.24, 0, 1.14), (0.36, 0.045, 0.42), p["steel"], rot=(0, math.radians(10), 0), bevel=0.012)
    add_cone("TopSpike", (0, 0, 1.46), 0.055, 0.005, 0.22, p["steel"], vertices=6)


def build_kite_shield() -> None:
    reset_scene()
    p = palette()
    add_box("ShieldUpper", (0, 0, 0.56), (0.68, 0.08, 0.58), p["wood_dark"], bevel=0.02)
    add_cone("ShieldLower", (0, 0, 0.16), 0.36, 0.04, 0.44, p["wood_dark"], vertices=4, rot=(math.radians(180), 0, math.radians(45)))
    add_box("RimTop", (0, 0, 0.85), (0.72, 0.10, 0.07), p["iron_dark"], bevel=0.015)
    add_sphere("CenterBoss", (0, -0.06, 0.54), 0.12, p["bronze"], scale=(1.0, 0.55, 1.0))
    add_box("CrossStrapV", (0, -0.04, 0.48), (0.08, 0.04, 0.68), p["steel"], bevel=0.008)
    add_box("CrossStrapH", (0, -0.04, 0.54), (0.64, 0.04, 0.08), p["steel"], bevel=0.008)


def build_hunting_bow() -> None:
    reset_scene()
    p = palette()
    # Continuous smooth parabolic recurve arc made of overlapping beveled stave segments
    num_segs = 10
    z_min, z_max = 0.08, 1.38
    z_mid = (z_min + z_max) * 0.5
    half_h = (z_max - z_min) * 0.5
    for i in range(num_segs):
        t0 = -1.0 + 2.0 * (i / num_segs)
        t1 = -1.0 + 2.0 * ((i + 1) / num_segs)
        tm = 0.5 * (t0 + t1)
        z0 = z_mid + t0 * half_h
        z1 = z_mid + t1 * half_h
        y0 = -0.28 * (t0 * t0)
        y1 = -0.28 * (t1 * t1)
        dz = z1 - z0
        dy = y1 - y0
        seg_len = math.hypot(dz, dy) + 0.025
        pitch = math.atan2(-dy, dz)
        thickness = 0.048 - 0.016 * abs(tm)
        mat = p["leather"] if abs(tm) < 0.22 else p["wood_warm"]
        add_box(f"BowSeg_{i}", (0, 0.5 * (y0 + y1), 0.5 * (z0 + z1)), (thickness, thickness * 1.1, seg_len), mat, rot=(pitch, 0, 0), bevel=0.008)
    # Taut bowstring connecting limb tips
    add_cylinder("Bowstring", (0, -0.28, z_mid), 0.007, z_max - z_min, p["parchment"], vertices=6, bevel=0.0)


def build_arrow() -> None:
    reset_scene()
    p = palette()
    add_cylinder("Shaft", (0, 0, 0.45), 0.012, 0.85, p["wood_warm"], vertices=8, bevel=0.0)
    add_cone("Arrowhead", (0, 0, 0.92), 0.035, 0.003, 0.14, p["steel"], vertices=4)
    add_box("Fletch1", (0, 0, 0.09), (0.09, 0.008, 0.15), p["cloth_red"], bevel=0.0)
    add_box("Fletch2", (0, 0, 0.09), (0.008, 0.09, 0.15), p["cloth_red"], bevel=0.0)


def build_spell_orb() -> None:
    reset_scene()
    p = palette()
    add_sphere("CoreOrb", (0, 0, 0.38), 0.18, p["arcane_cyan"])
    add_torus("OrbitRing1", (0, 0, 0.38), 0.28, 0.025, p["bronze"], rot=(math.radians(55), math.radians(20), 0))
    add_torus("OrbitRing2", (0, 0, 0.38), 0.26, 0.022, p["flame_glow"], rot=(math.radians(-45), math.radians(60), 0))


def build_health_potion() -> None:
    reset_scene()
    p = palette()
    add_sphere("FlaskBody", (0, 0, 0.20), 0.18, p["potion_red"], scale=(1.0, 1.0, 0.95))
    add_cylinder("FlaskNeck", (0, 0, 0.38), 0.065, 0.14, p["steel"], vertices=12, bevel=0.005)
    add_cylinder("Cork", (0, 0, 0.48), 0.055, 0.09, p["wood_warm"], vertices=10, bevel=0.005)


def build_mythic_gloves() -> None:
    reset_scene()
    p = palette()
    for side, sx in (("L", -0.24), ("R", 0.24)):
        add_cone(f"ForearmCuff_{side}", (sx, 0, 0.16), 0.12, 0.095, 0.30, p["iron_dark"], vertices=8)
        add_box(f"PalmPlate_{side}", (sx, 0, 0.36), (0.19, 0.11, 0.18), p["gold_sponsored"], bevel=0.02)
        for fi in range(4):
            fx = sx + (-0.066 + fi * 0.044)
            add_box(f"Finger_{side}_{fi}", (fx, -0.02, 0.50), (0.034, 0.05, 0.14), p["steel"], rot=(math.radians(15), 0, 0), bevel=0.006)
        thumb_dir = 1.0 if side == "L" else -1.0
        add_box(f"Thumb_{side}", (sx + thumb_dir * 0.11, -0.04, 0.40), (0.045, 0.05, 0.11), p["steel"], rot=(0, math.radians(-30 * thumb_dir), 0), bevel=0.006)
        add_sphere(f"KnuckleGem_{side}", (sx, -0.06, 0.38), 0.045, p["boss_ember"])


def build_all_batch2(manifest_entries: list[dict]) -> list[pathlib.Path]:
    builders = [
        ("iron_sword", build_iron_sword),
        ("war_axe", build_war_axe),
        ("kite_shield", build_kite_shield),
        ("hunting_bow", build_hunting_bow),
        ("arrow", build_arrow),
        ("spell_orb", build_spell_orb),
        ("health_potion", build_health_potion),
        ("mythic_gloves", build_mythic_gloves),
    ]
    paths: list[pathlib.Path] = []
    for name, fn in builders:
        fn()
        paths.append(export_asset("batch2", name, manifest_entries))
    return paths
