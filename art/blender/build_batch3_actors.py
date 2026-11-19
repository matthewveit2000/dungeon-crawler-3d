"""Batch 3: 3rd-Person Crawler, 3 Dungeon Enemies, Safe Room Vendor & Floor Boss."""

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


def build_player_crawler() -> None:
    reset_scene()
    p = palette()
    # Clean stylized Nordic adventurer silhouette (~1.82m tall)
    add_cylinder("LegL", (-0.16, 0, 0.42), 0.10, 0.84, p["leather"], vertices=10)
    add_cylinder("LegR", (0.16, 0, 0.42), 0.10, 0.84, p["leather"], vertices=10)
    add_box("Torso", (0, 0, 1.12), (0.52, 0.30, 0.64), p["iron_dark"], bevel=0.03)
    add_box("CloakBack", (0, 0.18, 0.92), (0.54, 0.08, 0.95), p["cloth_red"], rot=(math.radians(8), 0, 0), bevel=0.02)
    add_sphere("PauldronL", (-0.34, 0, 1.36), 0.16, p["steel"])
    add_sphere("PauldronR", (0.34, 0, 1.36), 0.16, p["steel"])
    add_cylinder("ArmL", (-0.36, 0, 1.02), 0.08, 0.56, p["leather"], vertices=10)
    add_cylinder("ArmR", (0.36, 0, 1.02), 0.08, 0.56, p["leather"], vertices=10)
    add_sphere("Helm", (0, 0, 1.62), 0.19, p["steel"])
    add_cone("HornL", (-0.22, -0.02, 1.74), 0.055, 0.008, 0.24, p["bone"], rot=(0, math.radians(-55), 0))
    add_cone("HornR", (0.22, -0.02, 1.74), 0.055, 0.008, 0.24, p["bone"], rot=(0, math.radians(55), 0))


def build_draugr_raider() -> None:
    reset_scene()
    p = palette()
    # Gaunt undead Nordic raider with glowing cyan draugr eyes (~1.9m tall)
    add_cylinder("LegL", (-0.15, 0, 0.44), 0.08, 0.88, p["stone_dark"], vertices=8)
    add_cylinder("LegR", (0.15, 0, 0.44), 0.08, 0.88, p["stone_dark"], vertices=8)
    add_box("RibTorso", (0, 0, 1.16), (0.48, 0.26, 0.62), p["iron_dark"], bevel=0.025)
    add_box("FurCollar", (0, 0, 1.44), (0.58, 0.34, 0.16), p["leather"], bevel=0.03)
    add_cylinder("ArmL", (-0.34, -0.08, 1.08), 0.07, 0.58, p["bone"], vertices=8, rot=(math.radians(20), 0, 0))
    add_cylinder("ArmR", (0.34, -0.14, 1.10), 0.07, 0.58, p["bone"], vertices=8, rot=(math.radians(38), 0, 0))
    add_box("DraugrBlade", (0.36, -0.45, 1.02), (0.08, 0.68, 0.05), p["steel"], bevel=0.008)
    add_sphere("Skull", (0, 0, 1.64), 0.17, p["bone"])
    add_sphere("EyeL", (-0.06, -0.15, 1.66), 0.032, p["arcane_cyan"])
    add_sphere("EyeR", (0.06, -0.15, 1.66), 0.032, p["arcane_cyan"])
    add_cone("HelmHornL", (-0.20, 0, 1.76), 0.048, 0.008, 0.28, p["iron_dark"], rot=(0, math.radians(-42), 0))
    add_cone("HelmHornR", (0.20, 0, 1.76), 0.048, 0.008, 0.28, p["iron_dark"], rot=(0, math.radians(42), 0))


def build_bone_archer() -> None:
    reset_scene()
    p = palette()
    # Hooded skeleton archer (~1.85m tall)
    add_cylinder("LegL", (-0.13, 0, 0.42), 0.065, 0.84, p["bone"], vertices=8)
    add_cylinder("LegR", (0.13, 0, 0.42), 0.065, 0.84, p["bone"], vertices=8)
    add_box("Tunic", (0, 0, 1.12), (0.42, 0.24, 0.64), p["cloth_dark"], bevel=0.02)
    add_cylinder("Quiver", (0.18, 0.20, 1.24), 0.09, 0.52, p["leather"], vertices=8, rot=(math.radians(12), math.radians(-18), 0))
    add_cylinder("ArmBow", (-0.30, -0.22, 1.22), 0.055, 0.55, p["bone"], vertices=8, rot=(math.radians(72), 0, 0))
    add_box("BowProp", (-0.32, -0.48, 1.22), (0.05, 0.08, 0.96), p["wood_warm"], bevel=0.01)
    add_sphere("Skull", (0, -0.02, 1.60), 0.15, p["bone"])
    add_cone("Hood", (0, 0.03, 1.68), 0.24, 0.05, 0.36, p["cloth_dark"], vertices=10, rot=(math.radians(-18), 0, 0))
    add_sphere("EyeL", (-0.05, -0.14, 1.61), 0.028, p["flame_glow"])
    add_sphere("EyeR", (0.05, -0.14, 1.61), 0.028, p["flame_glow"])


def build_goblin_influencer() -> None:
    reset_scene()
    p = palette()
    # DCC absurd payload! Hunched green goblin with floating neon streamer ring-light halo (~1.35m tall)
    add_cylinder("LegL", (-0.13, 0, 0.26), 0.075, 0.52, p["goblin_skin"], vertices=8)
    add_cylinder("LegR", (0.13, 0, 0.26), 0.075, 0.52, p["goblin_skin"], vertices=8)
    add_box("SponsoredVest", (0, 0, 0.72), (0.44, 0.28, 0.44), p["gold_sponsored"], bevel=0.03)
    add_cylinder("ArmL", (-0.30, -0.08, 0.70), 0.06, 0.42, p["goblin_skin"], vertices=8, rot=(math.radians(30), 0, 0))
    add_cylinder("ArmR", (0.30, -0.16, 0.76), 0.06, 0.42, p["goblin_skin"], vertices=8, rot=(math.radians(58), 0, 0))
    add_sphere("GoblinHead", (0, -0.04, 1.12), 0.20, p["goblin_skin"], scale=(1.05, 0.95, 0.9))
    add_cone("EarL", (-0.26, 0, 1.14), 0.06, 0.008, 0.28, p["goblin_skin"], rot=(0, math.radians(-80), 0))
    add_cone("EarR", (0.26, 0, 1.14), 0.06, 0.008, 0.28, p["goblin_skin"], rot=(0, math.radians(80), 0))
    add_sphere("EyeL", (-0.07, -0.20, 1.15), 0.04, p["flame_glow"])
    add_sphere("EyeR", (0.07, -0.20, 1.15), 0.04, p["flame_glow"])
    # Floating neon ring light!
    add_torus("StreamerHalo", (0, -0.28, 1.46), 0.24, 0.028, p["streamer_ring"], rot=(math.radians(78), 0, 0))


def build_iron_warden_boss() -> None:
    reset_scene()
    p = palette()
    # Towering 2.9m Nordic Iron Juggernaut Boss with glowing ember furnace chest & colossal hammer
    add_cylinder("LegL", (-0.34, 0, 0.64), 0.22, 1.28, p["iron_dark"], vertices=10)
    add_cylinder("LegR", (0.34, 0, 0.64), 0.22, 1.28, p["iron_dark"], vertices=10)
    add_box("Chassis", (0, 0, 1.74), (1.12, 0.68, 1.08), p["iron_dark"], bevel=0.05)
    add_sphere("EmberCore", (0, -0.34, 1.76), 0.26, p["boss_ember"])
    add_sphere("PauldronL", (-0.72, 0, 2.18), 0.34, p["bronze"])
    add_sphere("PauldronR", (0.72, 0, 2.18), 0.34, p["bronze"])
    add_cylinder("ArmL", (-0.78, -0.06, 1.56), 0.16, 0.96, p["iron_dark"], vertices=10)
    add_cylinder("ArmR", (0.78, -0.18, 1.56), 0.16, 0.96, p["iron_dark"], vertices=10, rot=(math.radians(24), 0, 0))
    # Colossal boss warhammer
    add_cylinder("HammerShaft", (0.86, -0.45, 1.32), 0.065, 2.2, p["steel"], vertices=8)
    add_box("HammerHead", (0.86, -0.45, 2.38), (0.48, 0.84, 0.44), p["iron_dark"], bevel=0.04)
    add_box("HammerGlow", (0.86, -0.88, 2.38), (0.34, 0.08, 0.28), p["boss_ember"], bevel=0.01)
    # Horned juggernaut helm
    add_box("BossHelm", (0, 0, 2.54), (0.48, 0.48, 0.52), p["iron_dark"], bevel=0.04)
    add_box("VisorGlow", (0, -0.25, 2.56), (0.34, 0.06, 0.10), p["boss_ember"], bevel=0.01)
    add_cone("CrownHornL", (-0.34, 0, 2.76), 0.10, 0.015, 0.52, p["bronze"], rot=(0, math.radians(-38), 0))
    add_cone("CrownHornR", (0.34, 0, 2.76), 0.10, 0.015, 0.52, p["bronze"], rot=(0, math.radians(38), 0))


def build_vendor_npc() -> None:
    reset_scene()
    p = palette()
    # Friendly Safe Room Merchant with emerald hood & lantern pack (~1.75m)
    add_cone("Robe", (0, 0, 0.68), 0.42, 0.22, 1.36, p["cloth_teal"], vertices=12)
    add_box("Pack", (0, 0.28, 1.05), (0.46, 0.28, 0.56), p["leather"], bevel=0.03)
    add_sphere("LanternPack", (0.28, 0.36, 1.38), 0.12, p["safe_emerald"])
    add_sphere("Head", (0, -0.02, 1.52), 0.16, p["parchment"])
    add_cone("MerchantHood", (0, 0.04, 1.62), 0.24, 0.06, 0.34, p["cloth_teal"], vertices=12, rot=(math.radians(-16), 0, 0))


def build_all_batch3(manifest_entries: list[dict]) -> list[pathlib.Path]:
    builders = [
        ("player_crawler", build_player_crawler),
        ("draugr_raider", build_draugr_raider),
        ("bone_archer", build_bone_archer),
        ("goblin_influencer", build_goblin_influencer),
        ("iron_warden_boss", build_iron_warden_boss),
        ("vendor_npc", build_vendor_npc),
    ]
    paths: list[pathlib.Path] = []
    for name, fn in builders:
        fn()
        paths.append(export_asset("batch3", name, manifest_entries))
    return paths
