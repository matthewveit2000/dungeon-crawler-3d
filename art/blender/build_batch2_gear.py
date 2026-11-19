"""Batch 2: Sculpted Skyrim-Grade Weapons, Nordic Shield, Recurve Bow, Arcane Focus,
Mythic Gauntlets, and First-Person Armored Forearms/Gauntlets (10 .glb assets).
"""

from __future__ import annotations

import math
import pathlib
from common import (
    add_box,
    add_cone,
    add_curved_tube,
    add_cylinder,
    add_lathe,
    add_sphere,
    add_tapered_blade,
    add_torus,
    export_asset,
    palette,
    reset_scene,
)


def _build_fp_gauntlet(is_right: bool) -> None:
    """Sculpts a compact first-person armored Nordic forearm + leather bracer + steel gauntlet
    oriented forward along -Y (Godot -Z) gripping near the origin (0,0,0).
    """
    p = palette()
    sign = 1.0 if is_right else -1.0
    # Padded leather cuff extending back toward elbow (+Y in Blender -> +Z in Godot)
    add_cylinder("ForearmSleeve", (0.0, 0.24, -0.02), 0.068, 0.34, p["leather"], vertices=14, rot=(math.radians(90), 0, 0))
    # Hammered steel vambrace armor plate on outer forearm
    add_box("Vambrace", (sign * 0.015, 0.22, 0.01), (0.125, 0.26, 0.115), p["iron_dark"], bevel=0.018)
    add_torus("CuffTrim", (0.0, 0.09, 0.0), 0.072, 0.014, p["bronze"], rot=(math.radians(90), 0, 0), major_seg=18)
    add_torus("ElbowTrim", (0.0, 0.35, -0.02), 0.078, 0.014, p["bronze"], rot=(math.radians(90), 0, 0), major_seg=18)
    # Armored back-of-hand & curled gauntlet fingers gripping handle at origin
    add_box("HandBack", (0.0, 0.02, 0.01), (0.105, 0.11, 0.075), p["steel"], bevel=0.016)
    for i, off in enumerate((-0.036, -0.012, 0.012, 0.036)):
        add_box(f"Finger{i}", (off, -0.045, -0.005), (0.022, 0.065, 0.048), p["iron_dark"], rot=(math.radians(38), 0, 0), bevel=0.006)
    add_box("Thumb", (-sign * 0.056, -0.01, 0.018), (0.032, 0.06, 0.032), p["iron_dark"], rot=(0, 0, sign * 0.45), bevel=0.006)


def build_all(manifest: list[dict]) -> list[pathlib.Path]:
    exported: list[pathlib.Path] = []
    batch = "batch2"

    # 1. iron_sword (razor-crisp diamond-ridged Nordic longsword with swept guard & leather grip)
    reset_scene()
    p = palette()
    add_lathe("Pommel", [(0.025, -0.22), (0.052, -0.18), (0.042, -0.14), (0.024, -0.11)], p["bronze"], segments=12)
    add_cylinder("Grip", (0, 0, -0.02), 0.025, 0.20, p["leather"], vertices=12, bevel=0.004)
    for z in (-0.07, -0.02, 0.03):
        add_torus("GripWrap", (0, 0, z), 0.027, 0.006, p["bronze"], major_seg=14)
    # Swept Nordic horned crossguard
    add_box("GuardCenter", (0, 0, 0.09), (0.11, 0.055, 0.052), p["iron_dark"], bevel=0.012)
    for sx in (-1.0, 1.0):
        add_box("GuardWing", (sx * 0.125, 0, 0.105), (0.16, 0.042, 0.036), p["iron_dark"], rot=(0, sx * math.radians(-16), 0), bevel=0.01)
    add_sphere("GuardStud", (0, 0.026, 0.09), 0.022, p["bronze"])
    # Sharp diamond-cross-section tapered steel blade with central dark fuller
    add_tapered_blade("Blade", length=0.92, width_base=0.088, width_tip=0.036, thickness=0.028, z_start=0.11, mat=p["steel"])
    add_box("Fuller", (0, 0, 0.44), (0.020, 0.024, 0.56), p["iron_dark"], bevel=0.004)
    exported.append(export_asset(batch, "iron_sword", manifest))

    # 2. iron_shield (PROPERLY PROPORTIONED Nordic Round War Shield — faces +Y outward, NO inverted cone!)
    reset_scene()
    p = palette()
    # Slightly domed wooden plank body (radius 0.36m — sleek & Skyrim-proportioned!)
    add_cylinder("ShieldWood", (0, 0.0, 0.0), 0.35, 0.042, p["wood_warm"], vertices=24, rot=(math.radians(90), 0, 0), bevel=0.01)
    # Forged iron outer rim ring
    add_torus("ShieldRim", (0, 0.008, 0.0), 0.355, 0.030, p["iron_dark"], rot=(math.radians(90), 0, 0), major_seg=28, minor_seg=12)
    # Crossed iron reinforcement straps
    add_box("StrapH", (0, 0.024, 0.0), (0.66, 0.022, 0.052), p["iron_dark"], bevel=0.007)
    add_box("StrapV", (0, 0.024, 0.0), (0.052, 0.022, 0.66), p["iron_dark"], bevel=0.007)
    # Sculpted steel dome boss (umbo) + bronze ring collar + 8 perimeter rivets
    add_sphere("BossDome", (0, 0.035, 0.0), 0.115, p["steel"], scale=(1.0, 0.55, 1.0))
    add_torus("BossRing", (0, 0.028, 0.0), 0.12, 0.016, p["bronze"], rot=(math.radians(90), 0, 0), major_seg=20)
    for i in range(8):
        ang = i * (math.tau / 8.0) + math.radians(22.5)
        add_sphere(f"Rivet{i}", (math.cos(ang) * 0.31, 0.030, math.sin(ang) * 0.31), 0.018, p["bronze"])
    # Rear wooden grip bar (so 1st-person inner side looks crafted too!)
    add_cylinder("BackHandle", (0, -0.055, 0.0), 0.020, 0.28, p["leather"], vertices=10)
    exported.append(export_asset(batch, "iron_shield", manifest))

    # 3. steel_greatsword (imposing two-handed Nordic Claymore)
    reset_scene()
    p = palette()
    add_lathe("Pommel", [(0.03, -0.34), (0.068, -0.28), (0.05, -0.22), (0.028, -0.18)], p["bronze"], segments=12)
    add_cylinder("LongGrip", (0, 0, -0.04), 0.028, 0.34, p["leather"], vertices=12, bevel=0.005)
    add_box("GuardHub", (0, 0, 0.14), (0.14, 0.068, 0.065), p["iron_dark"], bevel=0.014)
    for sx in (-1.0, 1.0):
        add_box("GuardArm", (sx * 0.20, 0, 0.175), (0.28, 0.048, 0.044), p["steel"], rot=(0, sx * math.radians(-22), 0), bevel=0.012)
        add_sphere("GuardQuillon", (sx * 0.34, 0, 0.225), 0.036, p["bronze"])
    add_tapered_blade("GreatBlade", length=1.28, width_base=0.125, width_tip=0.048, thickness=0.036, z_start=0.16, mat=p["steel"])
    add_box("GreatFuller", (0, 0, 0.62), (0.028, 0.032, 0.80), p["iron_dark"], bevel=0.005)
    exported.append(export_asset(batch, "steel_greatsword", manifest))

    # 4. hunting_bow (ONE-PIECE smooth sculpted recurve bow via add_curved_tube — zero gaps!)
    reset_scene()
    p = palette()
    bow_pts = []
    bow_rads = []
    for i in range(19):
        t = (i / 18.0) * 2.0 - 1.0  # -1..+1 along Z
        z = t * 0.68
        # Classic Nordic recurve belly + graceful outward tips
        y = -0.24 * (1.0 - t * t) + 0.07 * (t ** 4)
        rad = 0.026 * (1.0 - 0.42 * abs(t))
        bow_pts.append((0.0, y, z))
        bow_rads.append(rad)
    add_curved_tube("RecurveLimbs", bow_pts, bow_rads, p["wood_warm"], sides=12)
    # Leather grip wrap at center + bronze limb tips
    add_cylinder("BowGrip", (0, -0.24, 0.0), 0.032, 0.16, p["leather"], vertices=14)
    for sz in (-0.67, 0.67):
        add_sphere("HornTip", (0, 0.065, sz), 0.022, p["bronze"])
    # Taut bowstring spanning cleanly between tips
    add_cylinder("BowString", (0, 0.065, 0.0), 0.005, 1.34, p["parchment"], vertices=8, bevel=0.0)
    exported.append(export_asset(batch, "hunting_bow", manifest))

    # 5. arrow (slim ashwood shaft + diamond steel arrowhead + 3 crimson feathers)
    reset_scene()
    p = palette()
    add_cylinder("Shaft", (0, 0, 0.36), 0.011, 0.72, p["wood_warm"], vertices=10, bevel=0.0)
    add_cone("ArrowHead", (0, 0, 0.78), 0.026, 0.002, 0.12, p["steel"], vertices=4)
    for ang in (0, 120, 240):
        rad = math.radians(ang)
        add_box("Fletch", (math.cos(rad) * 0.022, math.sin(rad) * 0.022, 0.08), (0.040, 0.005, 0.13), p["cloth_red"], rot=(0, 0, rad), bevel=0.001)
    exported.append(export_asset(batch, "arrow", manifest))

    # 6. spell_orb (COMPACT ornate floating arcane crystal & orbiting bronze astrolabe sigil rings)
    reset_scene()
    p = palette()
    add_cone("GemTop", (0, 0, 0.09), 0.085, 0.005, 0.14, p["spell_fire"], vertices=6)
    add_cone("GemBot", (0, 0, -0.05), 0.005, 0.085, 0.14, p["spell_fire"], vertices=6)
    add_torus("SigilRingA", (0, 0, 0.02), 0.135, 0.012, p["bronze"], rot=(math.radians(52), math.radians(24), 0), major_seg=24)
    add_torus("SigilRingB", (0, 0, 0.02), 0.165, 0.009, p["gold_sponsored"], rot=(math.radians(-48), math.radians(-30), 0), major_seg=24)
    exported.append(export_asset(batch, "spell_orb", manifest))

    # 7. health_potion (smooth lathe-blown alchemy vial with glowing ruby liquid & cork)
    reset_scene()
    p = palette()
    add_lathe("Flask", [(0.08, 0.0), (0.14, 0.08), (0.13, 0.19), (0.055, 0.28), (0.055, 0.36), (0.075, 0.38)], p["potion_red"], segments=18)
    add_torus("NeckCollar", (0, 0, 0.31), 0.062, 0.012, p["bronze"], major_seg=16)
    add_cylinder("Cork", (0, 0, 0.41), 0.044, 0.08, p["wood_warm"], vertices=12, bevel=0.006)
    exported.append(export_asset(batch, "health_potion", manifest))

    # 8. mythic_gloves (pair of sculpted Sponsored gilded-steel war gauntlets)
    reset_scene()
    p = palette()
    for sx in (-0.17, 0.17):
        add_cylinder("Cuff", (sx, 0, 0.14), 0.095, 0.24, p["iron_dark"], vertices=12, bevel=0.012)
        add_torus("GoldBand", (sx, 0, 0.06), 0.10, 0.016, p["gold_sponsored"], major_seg=18)
        add_box("Palm", (sx, 0.01, 0.30), (0.15, 0.09, 0.15), p["steel"], bevel=0.018)
        add_box("KnuckleCrest", (sx, 0.05, 0.36), (0.14, 0.04, 0.045), p["gold_sponsored"], bevel=0.008)
        for fi, fx in enumerate((-0.048, -0.016, 0.016, 0.048)):
            add_box(f"F{fi}", (sx + fx, 0.02, 0.43), (0.025, 0.045, 0.10), p["steel"], bevel=0.006)
        add_box("Thumb", (sx + (-0.085 if sx > 0 else 0.085), 0.03, 0.32), (0.038, 0.045, 0.09), p["iron_dark"], rot=(0, 0.4 if sx > 0 else -0.4, 0), bevel=0.006)
    exported.append(export_asset(batch, "mythic_gloves", manifest))

    # 9. fp_gauntlet_right (First-person sculpted armored right hand & forearm!)
    reset_scene()
    _build_fp_gauntlet(is_right=True)
    exported.append(export_asset(batch, "fp_gauntlet_right", manifest))

    # 10. fp_gauntlet_left (First-person sculpted armored left hand & forearm!)
    reset_scene()
    _build_fp_gauntlet(is_right=False)
    exported.append(export_asset(batch, "fp_gauntlet_left", manifest))

    return exported
