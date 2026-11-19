"""Batch 3: Sculpted Stylized Characters, Skyrim-Inspired Enemies, Sponsored Goblin Streamer,
Safe Room Vendor, and Towering Iron Warden Floor Boss (6 .glb assets).
All actors face -Y in Blender (+Z / forward cleanly oriented in Godot) with balanced proportions,
beveled armor plates, sculpted limbs, and dramatic glowing eyes/runes (no blocky Lego shapes!).
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


def _add_armored_legs(p: dict, scale: float, boot_mat, greave_mat, thigh_mat) -> None:
    for sx in (-0.15 * scale, 0.15 * scale):
        # Boot
        add_box("Boot", (sx, -0.04 * scale, 0.08 * scale), (0.16 * scale, 0.28 * scale, 0.16 * scale), boot_mat, bevel=0.02 * scale)
        # Tapered Greave (shin)
        add_cone("Greave", (sx, 0.0, 0.34 * scale), 0.085 * scale, 0.105 * scale, 0.42 * scale, greave_mat, vertices=12)
        # Knee cop
        add_sphere("Knee", (sx, -0.07 * scale, 0.54 * scale), 0.072 * scale, p["bronze"])
        # Thigh
        add_cone("Thigh", (sx, 0.0, 0.72 * scale), 0.10 * scale, 0.125 * scale, 0.36 * scale, thigh_mat, vertices=12)


def build_all(manifest: list[dict]) -> list[pathlib.Path]:
    exported: list[pathlib.Path] = []
    batch = "batch3"

    # 1. player_crawler (Skyrim-inspired Nordic adventurer for 3rd-person view!)
    reset_scene()
    p = palette()
    _add_armored_legs(p, 1.0, p["leather"], p["iron_dark"], p["cloth_dark"])
    # Tunic skirt / tassets + leather belt with bronze buckle
    add_cone("TunicSkirt", (0, 0, 0.86), 0.29, 0.22, 0.30, p["cloth_dark"], vertices=12)
    add_cylinder("Belt", (0, 0, 0.96), 0.24, 0.10, p["leather"], vertices=16)
    add_box("Buckle", (0, -0.23, 0.96), (0.11, 0.06, 0.10), p["bronze"], bevel=0.012)
    # Sculpted steel breastplate (tapered heroic V-chest!)
    add_cone("Cuirass", (0, 0, 1.24), 0.22, 0.30, 0.48, p["steel"], vertices=12)
    add_box("ChestPlate", (0, -0.15, 1.26), (0.36, 0.16, 0.38), p["iron_dark"], bevel=0.03)
    add_box("ChestTrim", (0, -0.23, 1.32), (0.10, 0.04, 0.28), p["bronze"], bevel=0.01)
    # Layered rounded pauldrons + arms + gauntlets
    for sx in (-1.0, 1.0):
        add_sphere("Pauldron", (sx * 0.34, 0, 1.44), 0.145, p["steel"], scale=(1.1, 1.0, 0.88))
        add_torus("PauldronTrim", (sx * 0.34, 0, 1.40), 0.14, 0.02, p["bronze"], rot=(0, sx * 0.35, 0), major_seg=16)
        add_cone("UpperArm", (sx * 0.36, 0, 1.24), 0.078, 0.095, 0.32, p["leather"], vertices=12, rot=(0, sx * 0.10, 0))
        add_cone("Forearm", (sx * 0.39, -0.04, 0.98), 0.068, 0.082, 0.28, p["iron_dark"], vertices=12, rot=(0.22, 0, 0))
    # Flowing sculpted crimson-and-gold traveler cape on back (+Y)
    add_box("CapeUpper", (0, 0.22, 1.26), (0.50, 0.06, 0.56), p["cloth_red"], rot=(math.radians(12), 0, 0), bevel=0.018)
    add_box("CapeLower", (0, 0.30, 0.72), (0.58, 0.05, 0.62), p["cloth_red"], rot=(math.radians(10), 0, 0), bevel=0.018)
    # Nordic Horned Iron Helmet (classic Skyrim silhouette!)
    add_lathe("HelmDome", [(0.14, 1.54), (0.165, 1.64), (0.17, 1.76), (0.14, 1.88), (0.05, 1.94)], p["steel"], segments=18)
    add_box("NoseGuard", (0, -0.17, 1.68), (0.045, 0.05, 0.18), p["iron_dark"], bevel=0.008)
    add_torus("HelmBrow", (0, 0, 1.72), 0.172, 0.022, p["bronze"], major_seg=20)
    for sx in (-1.0, 1.0):
        add_curved_tube(
            "NordicHorn",
            [(sx * 0.14, -0.02, 1.80), (sx * 0.26, -0.06, 1.84), (sx * 0.33, -0.14, 1.76), (sx * 0.30, -0.22, 1.66)],
            [0.036, 0.028, 0.018, 0.006],
            p["bone"],
            sides=10,
        )
    # Sheathed longsword angled across back
    add_box("BackScabbard", (-0.08, 0.28, 1.16), (0.09, 0.05, 0.92), p["leather"], rot=(0, math.radians(24), 0), bevel=0.012)
    add_box("BackHilt", (-0.28, 0.29, 1.66), (0.22, 0.05, 0.05), p["bronze"], rot=(0, math.radians(24), 0), bevel=0.01)
    exported.append(export_asset(batch, "player_crawler", manifest))

    # 2. draugr_raider (Skyrim-style hunched ancient Nordic Draugr with glowing ice-blue eyes, battle-axe & buckler!)
    reset_scene()
    p = palette()
    _add_armored_legs(p, 0.98, p["iron_dark"], p["draugr_skin"], p["cloth_dark"])
    add_cone("TatteredKilt", (0, 0, 0.82), 0.31, 0.21, 0.36, p["cloth_dark"], vertices=12)
    add_cylinder("DraugrBelt", (0, 0, 0.95), 0.23, 0.08, p["leather"], vertices=14)
    add_box("DraugrBuckle", (0, -0.22, 0.95), (0.10, 0.05, 0.09), p["bronze"], bevel=0.01)
    # Gaunt armored ribcage torso (hunched predatory forward lean along -Y)
    add_cone("DraugrTorso", (0, -0.05, 1.22), 0.20, 0.30, 0.50, p["draugr_skin"], vertices=12, rot=(math.radians(-12), 0, 0))
    add_torus("FurMantle", (0, -0.05, 1.46), 0.29, 0.068, p["leather"], rot=(math.radians(-12), 0, 0), major_seg=18)
    for z in (1.10, 1.22, 1.34):
        add_torus("RibPlate", (0, -0.07, z), 0.23, 0.026, p["iron_dark"], rot=(math.radians(-12), 0, 0), major_seg=14)
    for sx in (-1.0, 1.0):
        add_sphere("RustPauldron", (sx * 0.35, -0.04, 1.44), 0.145, p["iron_dark"], scale=(1.15, 0.95, 0.85))
        add_cone("ArmUpper", (sx * 0.37, -0.08, 1.22), 0.062, 0.078, 0.34, p["draugr_skin"], vertices=10, rot=(0.35, sx * -0.15, 0))
        add_cone("ArmLower", (sx * 0.39, -0.24, 0.99), 0.056, 0.070, 0.30, p["iron_dark"], vertices=10, rot=(0.82, 0, 0))
    # Skull-visage head + corroded horned Nordic war helm + piercing ice-blue eyes!
    add_sphere("DraugrSkull", (0, -0.11, 1.66), 0.145, p["bone"], scale=(0.90, 1.05, 1.12))
    add_lathe("DraugrHelm", [(0.158, 1.68), (0.168, 1.78), (0.12, 1.90), (0.04, 1.95)], p["iron_dark"], loc=(0, -0.11, 0), segments=14)
    for sx in (-0.055, 0.055):
        add_sphere("IceEye", (sx, -0.24, 1.68), 0.025, p["eye_ice"])
    for sx in (-1.0, 1.0):
        add_curved_tube(
            "DraugrHorn",
            [(sx * 0.14, -0.11, 1.80), (sx * 0.27, -0.16, 1.90), (sx * 0.30, -0.26, 2.04)],
            [0.034, 0.024, 0.007],
            p["bone"],
            sides=8,
        )
    # Bearded Nordic Battle-Axe raised in right hand + scarred buckler on left forearm
    add_cylinder("AxeHaft", (0.40, -0.40, 1.16), 0.024, 1.15, p["wood_dark"], vertices=10, rot=(math.radians(-32), 0, 0))
    add_box("AxeBlade", (0.40, -0.66, 1.54), (0.04, 0.32, 0.38), p["steel"], rot=(math.radians(-32), 0, 0), bevel=0.012)
    add_cylinder("Buckler", (-0.44, -0.34, 1.02), 0.22, 0.036, p["wood_dark"], vertices=16, rot=(0, math.radians(78), math.radians(-18)), bevel=0.008)
    add_sphere("BucklerBoss", (-0.47, -0.35, 1.02), 0.065, p["iron_dark"])
    exported.append(export_asset(batch, "draugr_raider", manifest))

    # 3. bone_archer (lean hooded dark-fantasy crypt marksman with flared ranger cloak, quiver & recurve bow)
    reset_scene()
    p = palette()
    _add_armored_legs(p, 0.94, p["leather"], p["bone"], p["cloth_dark"])
    # Sculpted flared ranger cloak (wide hem, cinched waist, layered shoulder capelet!)
    add_cone("CloakSkirt", (0, 0.02, 0.62), 0.38, 0.20, 0.72, p["cloth_dark"], vertices=14)
    add_cylinder("RangerBelt", (0, 0.0, 0.96), 0.21, 0.08, p["leather"], vertices=14)
    add_box("RangerBuckle", (0, -0.20, 0.96), (0.09, 0.04, 0.08), p["bronze"], bevel=0.01)
    add_cone("CloakTorso", (0, 0.0, 1.22), 0.20, 0.27, 0.46, p["cloth_dark"], vertices=14)
    add_cone("ShoulderCapelet", (0, 0.02, 1.44), 0.36, 0.16, 0.22, p["cloth_red"], vertices=14)
    add_box("BoneRibs", (0, -0.14, 1.24), (0.24, 0.10, 0.30), p["bone"], bevel=0.018)
    # Left bow arm extended forward, right draw arm pulled near chin
    add_cylinder("BowArm", (-0.28, -0.24, 1.32), 0.048, 0.48, p["cloth_dark"], vertices=10, rot=(math.radians(80), 0, math.radians(-12)))
    add_cylinder("DrawArm", (0.28, -0.16, 1.30), 0.048, 0.38, p["cloth_dark"], vertices=10, rot=(math.radians(65), 0, math.radians(24)))
    # Deep draped overhanging hood + dark skull face + glowing emerald eyes
    add_lathe("DeepHood", [(0.23, 1.48), (0.24, 1.66), (0.19, 1.82), (0.06, 1.92)], p["cloth_dark"], loc=(0, 0.01, 0), rot=(math.radians(-14), 0, 0), segments=14)
    add_sphere("SkullFace", (0, -0.05, 1.63), 0.115, p["bone"], scale=(0.9, 1.0, 1.1))
    for sx in (-0.045, 0.045):
        add_sphere("EyeGlow", (sx, -0.16, 1.64), 0.022, p["safe_emerald"])
    # Quiver with 3 crimson-fletched arrows slung across back
    add_cylinder("Quiver", (0.12, 0.23, 1.24), 0.072, 0.56, p["leather"], vertices=10, rot=(0, math.radians(-22), 0))
    for off in (-0.03, 0.0, 0.03):
        add_cylinder("QArrow", (0.06 + off, 0.24, 1.56), 0.010, 0.22, p["cloth_red"], vertices=6, rot=(0, math.radians(-22), 0))
    # Held recurve bow in extended left hand
    bpts = [(-0.34, -0.46 - 0.16 * (1.0 - (t * t)), 1.32 + t * 0.52) for t in [i / 8.0 * 2.0 - 1.0 for i in range(9)]]
    add_curved_tube("HeldBow", bpts, [0.018] * 9, p["wood_warm"], sides=8)
    add_cylinder("BowStr", (-0.34, -0.46, 1.32), 0.005, 1.02, p["parchment"], vertices=6, bevel=0.0)
    exported.append(export_asset(batch, "bone_archer", manifest))

    # 4. goblin_streamer (DCC "Dark Baseline, Goofy Payload": sneaky Goblin + Sleek Neon Ring-Light & Hovering Camera Drone!)
    reset_scene()
    p = palette()
    for sx in (-0.13, 0.13):
        add_box("GobFoot", (sx, -0.06, 0.06), (0.13, 0.24, 0.11), p["leather"], bevel=0.015)
        add_cone("GobLeg", (sx, 0, 0.30), 0.062, 0.084, 0.42, p["goblin_skin"], vertices=10)
    add_cone("GobTunic", (0, -0.04, 0.72), 0.21, 0.24, 0.46, p["leather"], vertices=12, rot=(math.radians(-14), 0, 0))
    add_box("SponsoredBib", (0, -0.23, 0.75), (0.20, 0.05, 0.28), p["gold_sponsored"], bevel=0.01)
    # Expressive goblin head, snout, huge swept ears & mischievous glowing amber eyes
    add_sphere("GobHead", (0, -0.11, 1.12), 0.19, p["goblin_skin"], scale=(1.05, 1.12, 0.94))
    add_cone("GobNose", (0, -0.33, 1.10), 0.055, 0.014, 0.18, p["goblin_skin"], vertices=8, rot=(math.radians(-98), 0, 0))
    for sx in (-1.0, 1.0):
        add_cone("GobEar", (sx * 0.31, -0.08, 1.17), 0.065, 0.01, 0.30, p["goblin_skin"], vertices=8, rot=(0, sx * math.radians(78), sx * -0.25))
        add_sphere("GobEye", (sx * 0.072, -0.28, 1.16), 0.028, p["flame_glow"])
        add_cone("GobArm", (sx * 0.28, -0.14, 0.76), 0.05, 0.068, 0.36, p["goblin_skin"], vertices=10, rot=(0.55, 0, sx * -0.2))
    # Jagged dagger gripped in right hand
    add_tapered_blade("GobDagger", 0.38, 0.065, 0.02, 0.02, 0.62, p["steel"])
    # SIGNATURE DCC PAYLOAD: Sleek metallic studio Ring-Light mounted on backpack + Hovering Camera Drone!
    add_box("StreamPack", (0, 0.16, 0.80), (0.26, 0.14, 0.30), p["iron_dark"], bevel=0.02)
    add_cylinder("RingStand", (0, 0.19, 1.08), 0.018, 0.42, p["iron_dark"], vertices=8)
    add_torus("RingMount", (0, 0.19, 1.44), 0.31, 0.026, p["iron_dark"], rot=(math.radians(82), 0, 0), major_seg=28)
    add_torus("RingLightHalo", (0, 0.175, 1.44), 0.31, 0.018, p["streamer_ring"], rot=(math.radians(82), 0, 0), major_seg=28)
    add_box("MiniDrone", (0.44, -0.18, 1.44), (0.15, 0.17, 0.10), p["iron_dark"], bevel=0.018)
    add_sphere("DroneLens", (0.44, -0.27, 1.44), 0.044, p["arcane_cyan"])
    for rx in (-0.11, 0.11):
        add_cylinder("Rotor", (0.44 + rx, -0.18, 1.52), 0.065, 0.008, p["bronze"], vertices=12, bevel=0.0)
    exported.append(export_asset(batch, "goblin_streamer", manifest))

    # 5. iron_warden_boss (JAW-DROPPING 3.0m SCULPTED NORDIC IRON JUGGERNAUT — rich metallic plates, furnace grate, warhammer!)
    reset_scene()
    p = palette()
    _add_armored_legs(p, 1.48, p["iron_dark"], p["steel"], p["iron_dark"])
    # Heavy segmented war-skirt tassets + bronze belt
    add_cone("BossTassets", (0, 0, 1.24), 0.56, 0.44, 0.46, p["iron_dark"], vertices=8)
    add_torus("BossBelt", (0, 0, 1.44), 0.46, 0.065, p["bronze"], major_seg=18)
    # Massive sculpted armored chestplate (steel + dark iron + gilded bevel ribs — catches light dramatically!)
    add_cone("BossCuirass", (0, 0, 1.88), 0.44, 0.62, 0.88, p["steel"], vertices=8)
    add_box("ChestFront", (0, -0.34, 1.92), (0.78, 0.32, 0.72), p["iron_dark"], bevel=0.045)
    # Recessed molten furnace grate (bronze bars over warm amber core — NEVER a blinding white circle!)
    add_torus("FurnaceRing", (0, -0.50, 1.94), 0.24, 0.042, p["bronze"], rot=(math.radians(90), 0, 0), major_seg=20)
    add_sphere("FurnaceCore", (0, -0.46, 1.94), 0.20, p["boss_ember"], scale=(1.0, 0.45, 1.0))
    for bx in (-0.09, 0.0, 0.09):
        add_box("GrateBar", (bx, -0.52, 1.94), (0.028, 0.04, 0.38), p["iron_dark"], bevel=0.005)
    # Crimson war-cape sweeping down back
    add_box("BossCape", (0, 0.46, 1.38), (1.06, 0.09, 1.76), p["cloth_red"], rot=(math.radians(10), 0, 0), bevel=0.025)
    # Towering spiked layered pauldrons + massive armored arms
    for sx in (-1.0, 1.0):
        add_sphere("BossPauldron", (sx * 0.70, 0, 2.24), 0.30, p["steel"], scale=(1.15, 1.0, 0.92))
        add_torus("PauldronTrim", (sx * 0.70, 0, 2.18), 0.30, 0.036, p["bronze"], rot=(0, sx * 0.32, 0), major_seg=18)
        add_cone("PauldronSpike", (sx * 0.86, 0, 2.48), 0.075, 0.008, 0.34, p["steel"], vertices=8, rot=(0, sx * math.radians(32), 0))
        add_cone("BossUpperArm", (sx * 0.76, -0.04, 1.84), 0.14, 0.18, 0.56, p["iron_dark"], vertices=10)
        add_cone("BossGauntlet", (sx * 0.80, -0.18, 1.40), 0.13, 0.17, 0.48, p["steel"], vertices=10, rot=(0.35, 0, 0))
    # Crowned Horned Greathelm + glowing molten visor slit!
    add_lathe("GreatHelm", [(0.24, 2.38), (0.28, 2.52), (0.28, 2.74), (0.20, 2.90), (0.06, 2.98)], p["steel"], segments=12)
    add_torus("CrownBand", (0, 0, 2.74), 0.28, 0.036, p["gold_sponsored"], major_seg=16)
    add_box("VisorSlit", (0, -0.27, 2.60), (0.26, 0.06, 0.065), p["boss_ember"], bevel=0.01)
    for sx in (-1.0, 1.0):
        add_curved_tube(
            "BossHorn",
            [(sx * 0.24, -0.04, 2.76), (sx * 0.48, -0.10, 2.92), (sx * 0.60, -0.18, 3.16)],
            [0.065, 0.048, 0.012],
            p["bronze"],
            sides=10,
        )
    # Colossal Rune-Forged Nordic Warhammer gripped in right hand!
    add_cylinder("HammerShaft", (0.84, -0.44, 1.50), 0.055, 2.45, p["iron_dark"], vertices=12, rot=(math.radians(-18), 0, 0))
    add_box("HammerHead", (0.84, -0.82, 2.54), (0.44, 0.76, 0.48), p["steel"], rot=(math.radians(-18), 0, 0), bevel=0.04)
    add_box("HammerTrim", (0.84, -0.82, 2.54), (0.48, 0.24, 0.52), p["bronze"], rot=(math.radians(-18), 0, 0), bevel=0.025)
    add_box("HammerCore", (0.84, -1.18, 2.66), (0.28, 0.06, 0.30), p["boss_ember"], rot=(math.radians(-18), 0, 0), bevel=0.015)
    exported.append(export_asset(batch, "iron_warden_boss", manifest))

    # 6. safe_room_vendor (characterful robed sanctuary merchant with gold-trimmed mantle & brass lantern staff)
    reset_scene()
    p = palette()
    add_cone("RobeLower", (0, 0, 0.56), 0.40, 0.26, 1.12, p["cloth_teal"], vertices=14)
    add_cone("RobeUpper", (0, 0, 1.24), 0.28, 0.24, 0.46, p["cloth_teal"], vertices=14)
    add_torus("GoldSash", (0, 0, 1.00), 0.28, 0.04, p["gold_sponsored"], major_seg=18)
    add_cone("ShoulderMantle", (0, 0, 1.44), 0.38, 0.18, 0.26, p["cloth_red"], vertices=14)
    add_cone("VendorHood", (0, 0.02, 1.72), 0.24, 0.06, 0.40, p["cloth_teal"], vertices=14, rot=(math.radians(12), 0, 0))
    add_sphere("VendorFace", (0, -0.04, 1.64), 0.13, p["parchment"])
    add_cone("VendorBeard", (0, -0.14, 1.48), 0.09, 0.02, 0.22, p["bone"], vertices=8, rot=(math.radians(180), 0, 0))
    for sx in (-1.0, 1.0):
        add_cone("Sleeve", (sx * 0.32, -0.10, 1.24), 0.10, 0.075, 0.44, p["cloth_teal"], vertices=10, rot=(0.45, 0, sx * -0.15))
    # Brass lantern staff
    add_cylinder("Staff", (0.44, -0.26, 1.04), 0.032, 2.08, p["wood_warm"], vertices=10)
    add_torus("LanternCage", (0.44, -0.26, 1.94), 0.14, 0.022, p["bronze"], major_seg=16)
    add_sphere("LanternGlow", (0.44, -0.26, 1.94), 0.11, p["flame_glow"])
    exported.append(export_asset(batch, "safe_room_vendor", manifest))

    return exported
