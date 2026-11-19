"""Batch 1: High-Craft Nordic-Ruin Modular Dungeon Kit + Handcrafted Setpiece Props (22 .glb assets)."""

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
    add_torus,
    export_asset,
    palette,
    reset_scene,
)


def build_all(manifest: list[dict]) -> list[pathlib.Path]:
    exported: list[pathlib.Path] = []
    batch = "batch1"

    # 1. floor_tile (4x4m carved Nordic flagstones with stone border inlay)
    reset_scene()
    p = palette()
    add_box("FloorBase", (0, 0, -0.16), (4.0, 4.0, 0.32), p["stone_mid"], bevel=0.025)
    # Recessed border trim strips
    for pos, sz in [
        ((0, 1.9, 0.012), (3.85, 0.16, 0.024)),
        ((0, -1.9, 0.012), (3.85, 0.16, 0.024)),
        ((1.9, 0, 0.012), (0.16, 3.85, 0.024)),
        ((-1.9, 0, 0.012), (0.16, 3.85, 0.024)),
    ]:
        add_box("FloorBorder", pos, sz, p["stone_trim"], bevel=0.01)
    # Carved Nordic center diamond medallion
    add_box("MedallionOuter", (0, 0, 0.010), (0.85, 0.85, 0.02), p["stone_trim"], rot=(0, 0, math.radians(45)), bevel=0.01)
    add_box("MedallionInner", (0, 0, 0.018), (0.42, 0.42, 0.016), p["stone_dark"], rot=(0, 0, math.radians(45)), bevel=0.008)
    exported.append(export_asset(batch, "floor_tile", manifest))

    # 2. ceiling_tile (4x4m vaulted Nordic ceiling with crossed timber-iron ribs)
    reset_scene()
    p = palette()
    add_box("CeilSlab", (0, 0, 0.16), (4.0, 4.0, 0.32), p["stone_dark"], bevel=0.02)
    add_box("RibX", (0, 0, -0.08), (4.0, 0.34, 0.24), p["stone_trim"], bevel=0.02)
    add_box("RibY", (0, 0, -0.08), (0.34, 4.0, 0.24), p["stone_trim"], bevel=0.02)
    add_box("BossKey", (0, 0, -0.14), (0.62, 0.62, 0.16), p["bronze"], rot=(0, 0, math.radians(45)), bevel=0.015)
    exported.append(export_asset(batch, "ceiling_tile", manifest))

    # 3. wall_segment (4x4m Nordic ashlar stone wall with plinth, pilaster buttresses, cornice & iron wall-strap)
    reset_scene()
    p = palette()
    add_box("WallCore", (0, 0, 2.0), (4.0, 0.46, 4.0), p["stone_dark"], bevel=0.025)
    add_box("BasePlinth", (0, 0, 0.26), (4.0, 0.64, 0.52), p["stone_trim"], bevel=0.03)
    add_box("MidCourse", (0, 0, 2.15), (4.0, 0.54, 0.18), p["stone_trim"], bevel=0.02)
    add_box("TopCornice", (0, 0, 3.80), (4.0, 0.66, 0.40), p["stone_trim"], bevel=0.03)
    for x in (-1.75, 1.75):
        add_box("Buttress", (x, 0, 2.0), (0.42, 0.62, 3.55), p["stone_mid"], bevel=0.025)
        add_box("IronStrap", (x, 0, 2.15), (0.46, 0.66, 0.10), p["iron_dark"], bevel=0.01)
    # Recessed gothic/Nordic relief panel in center
    add_box("ReliefFrame", (0, 0, 1.30), (1.85, 0.52, 1.15), p["stone_mid"], bevel=0.02)
    add_box("ReliefCarve", (0, 0, 3.00), (1.40, 0.52, 0.95), p["stone_mid"], bevel=0.02)
    exported.append(export_asset(batch, "wall_segment", manifest))

    # 4. door_arch (4x4m grand carved stone doorway with stepped voussoirs & keystone)
    reset_scene()
    p = palette()
    for sx in (-1.52, 1.52):
        add_box("ArchJamb", (sx, 0, 1.85), (0.96, 0.68, 3.70), p["stone_mid"], bevel=0.03)
        add_box("JambPlinth", (sx, 0, 0.26), (1.12, 0.80, 0.52), p["stone_trim"], bevel=0.03)
        add_box("JambCap", (sx, 0, 3.15), (1.10, 0.80, 0.24), p["stone_trim"], bevel=0.025)
    add_box("Lintel", (0, 0, 3.60), (4.0, 0.72, 0.80), p["stone_dark"], bevel=0.03)
    add_box("Keystone", (0, 0, 3.42), (0.64, 0.86, 0.74), p["stone_trim"], bevel=0.03)
    add_box("BronzeRune", (0, 0, 3.42), (0.28, 0.90, 0.38), p["bronze"], bevel=0.015)
    exported.append(export_asset(batch, "door_arch", manifest))

    # 5. pillar (ornate octagonal carved Nordic column with bronze collar bands)
    reset_scene()
    p = palette()
    add_box("PillarBase", (0, 0, 0.24), (1.16, 1.16, 0.48), p["stone_trim"], bevel=0.035)
    add_box("PillarPlinth", (0, 0, 0.56), (0.94, 0.94, 0.22), p["stone_mid"], bevel=0.025)
    add_cylinder("PillarShaft", (0, 0, 2.02), 0.38, 2.84, p["stone_mid"], vertices=8, bevel=0.02)
    for z in (1.15, 2.85):
        add_cylinder("BronzeBand", (0, 0, z), 0.42, 0.14, p["bronze"], vertices=8, bevel=0.012)
    add_box("PillarNeck", (0, 0, 3.52), (0.96, 0.96, 0.24), p["stone_mid"], bevel=0.025)
    add_box("PillarCap", (0, 0, 3.80), (1.20, 1.20, 0.40), p["stone_trim"], bevel=0.035)
    exported.append(export_asset(batch, "pillar", manifest))

    # 6. torch_sconce (forged iron wall bracket + ornate cage + sculpted multi-tongue flame)
    reset_scene()
    p = palette()
    add_box("WallPlate", (0, -0.04, 0.0), (0.20, 0.06, 0.46), p["iron_dark"], bevel=0.012)
    add_box("BracketArm", (0, 0.14, -0.04), (0.07, 0.34, 0.07), p["iron_dark"], rot=(math.radians(-20), 0, 0), bevel=0.01)
    add_lathe("TorchCup", [(0.04, -0.10), (0.05, 0.08), (0.12, 0.20), (0.15, 0.26), (0.12, 0.28)], p["iron_dark"], loc=(0, 0.28, 0.02), segments=10)
    add_torus("CageRing", (0, 0.28, 0.30), 0.13, 0.018, p["bronze"])
    add_cone("FlameCore", (0, 0.28, 0.44), 0.11, 0.01, 0.32, p["flame_glow"], vertices=10)
    add_cone("FlameLick", (0.03, 0.29, 0.50), 0.06, 0.005, 0.24, p["flame_glow"], vertices=8, rot=(0.12, 0.18, 0))
    exported.append(export_asset(batch, "torch_sconce", manifest))

    # 7. chest (heavy arched-lid Nordic iron-banded treasure chest with ornate brass clasp)
    reset_scene()
    p = palette()
    add_box("ChestBody", (0, 0, 0.32), (1.12, 0.68, 0.56), p["wood_warm"], bevel=0.025)
    add_cylinder("ChestLid", (0, 0, 0.60), 0.34, 1.12, p["wood_warm"], vertices=14, rot=(0, math.radians(90), 0), bevel=0.018)
    for x in (-0.42, 0.0, 0.42):
        add_box("IronStrap", (x, 0, 0.46), (0.09, 0.74, 0.72), p["iron_dark"], bevel=0.01)
    add_box("RimTrim", (0, 0, 0.58), (1.18, 0.74, 0.07), p["bronze"], bevel=0.012)
    add_box("LockPlate", (0, 0.36, 0.54), (0.20, 0.07, 0.24), p["gold_sponsored"], bevel=0.012)
    exported.append(export_asset(batch, "chest", manifest))

    # 8. crate (reinforced slatted supply crate with corner iron brackets)
    reset_scene()
    p = palette()
    add_box("CrateInner", (0, 0, 0.45), (0.86, 0.86, 0.86), p["wood_dark"], bevel=0.015)
    for z in (0.08, 0.84):
        add_box("CrateRim", (0, 0, z), (0.94, 0.94, 0.12), p["wood_warm"], bevel=0.015)
    for sx in (-0.42, 0.42):
        for sy in (-0.42, 0.42):
            add_box("Post", (sx, sy, 0.46), (0.12, 0.12, 0.92), p["wood_warm"], bevel=0.012)
    add_box("Diag", (0, 0.45, 0.46), (0.96, 0.06, 0.10), p["wood_warm"], rot=(0, math.radians(42), 0), bevel=0.01)
    add_box("IronCorner", (0, 0, 0.46), (0.96, 0.96, 0.06), p["iron_dark"], bevel=0.008)
    exported.append(export_asset(batch, "crate", manifest))

    # 9. urn (smooth lathe-sculpted Nordic burial amphora with twin bronze handles)
    reset_scene()
    p = palette()
    add_lathe(
        "UrnVessel",
        [(0.18, 0.0), (0.24, 0.08), (0.19, 0.18), (0.34, 0.44), (0.32, 0.68), (0.17, 0.86), (0.23, 0.96), (0.19, 1.02)],
        p["stone_trim"],
        segments=20,
    )
    add_torus("UrnCollar", (0, 0, 0.78), 0.24, 0.028, p["bronze"])
    for sx in (-1.0, 1.0):
        add_curved_tube(
            "Handle",
            [(sx * 0.22, 0, 0.82), (sx * 0.36, 0, 0.76), (sx * 0.38, 0, 0.56), (sx * 0.31, 0, 0.46)],
            [0.025, 0.03, 0.03, 0.025],
            p["bronze"],
            sides=8,
        )
    exported.append(export_asset(batch, "urn", manifest))

    # 10. safe_beacon (sculpted Nordic sanctuary runestone obelisk + floating emerald-gold ward rings)
    reset_scene()
    p = palette()
    add_cylinder("StepBase", (0, 0, 0.12), 1.05, 0.24, p["stone_trim"], vertices=8, bevel=0.025)
    add_cylinder("AltarMid", (0, 0, 0.48), 0.72, 0.54, p["stone_mid"], vertices=8, bevel=0.025)
    add_torus("FloorRuneRing", (0, 0, 0.25), 0.94, 0.035, p["safe_emerald"])
    add_cone("CrystalTop", (0, 0, 1.65), 0.34, 0.02, 0.82, p["safe_emerald"], vertices=6)
    add_cone("CrystalBot", (0, 0, 1.02), 0.02, 0.34, 0.48, p["safe_emerald"], vertices=6)
    add_torus("OrbitBronze1", (0, 0, 1.38), 0.56, 0.032, p["gold_sponsored"], rot=(math.radians(55), math.radians(22), 0))
    add_torus("OrbitBronze2", (0, 0, 1.38), 0.66, 0.024, p["safe_emerald"], rot=(math.radians(-42), math.radians(-30), 0))
    exported.append(export_asset(batch, "safe_beacon", manifest))

    # 11. quest_board (handcrafted timber bounty board with shingled roof, pinned parchment notices & hanging lantern)
    reset_scene()
    p = palette()
    for sx in (-0.82, 0.82):
        add_box("Post", (sx, 0, 1.10), (0.14, 0.14, 2.20), p["wood_dark"], bevel=0.015)
        add_box("Foot", (sx, 0, 0.12), (0.30, 0.44, 0.24), p["stone_trim"], bevel=0.02)
    add_box("BoardBacking", (0, 0, 1.36), (1.60, 0.10, 1.12), p["wood_warm"], bevel=0.02)
    add_box("RoofFront", (0, 0.14, 2.18), (2.05, 0.56, 0.10), p["wood_dark"], rot=(math.radians(24), 0, 0), bevel=0.015)
    add_box("RoofBack", (0, -0.14, 2.18), (2.05, 0.56, 0.10), p["wood_dark"], rot=(math.radians(-24), 0, 0), bevel=0.015)
    # Pinned bounty scrolls with crimson wax seals
    for px, pz, r in [(-0.46, 1.54, 0.07), (0.04, 1.44, -0.05), (0.48, 1.56, 0.09), (-0.22, 1.08, -0.06), (0.34, 1.12, 0.04)]:
        add_box("Notice", (px, 0.07, pz), (0.34, 0.02, 0.40), p["parchment"], rot=(0, r, 0), bevel=0.004)
        add_sphere("WaxSeal", (px, 0.085, pz + 0.14), 0.028, p["cloth_red"])
    add_sphere("BoardLantern", (0.94, 0.18, 1.92), 0.10, p["flame_glow"])
    exported.append(export_asset(batch, "quest_board", manifest))

    # 12. boss_gate (forged heavy iron portcullis with spiked bottom teeth & crimson ember rune crest)
    reset_scene()
    p = palette()
    add_box("TopBeam", (0, 0, 3.30), (3.40, 0.26, 0.30), p["iron_dark"], bevel=0.02)
    add_box("MidBeam", (0, 0, 1.75), (3.40, 0.22, 0.22), p["iron_dark"], bevel=0.018)
    add_box("BotBeam", (0, 0, 0.32), (3.40, 0.22, 0.20), p["iron_dark"], bevel=0.018)
    for i in range(-4, 5):
        x = i * 0.38
        add_cylinder("GateBar", (x, 0, 1.76), 0.055, 3.30, p["steel"], vertices=10, bevel=0.008)
        add_cone("BarSpike", (x, 0, 0.10), 0.065, 0.005, 0.24, p["steel"], vertices=8, rot=(math.radians(180), 0, 0))
    add_torus("BossCrestRing", (0, 0.12, 2.45), 0.42, 0.05, p["bronze"], rot=(math.radians(90), 0, 0))
    add_box("BossRuneCore", (0, 0.14, 2.45), (0.28, 0.08, 0.46), p["boss_ember"], bevel=0.015)
    exported.append(export_asset(batch, "boss_gate", manifest))

    # 13. vault_gate (ornate gilded double vault doors with Nordic sun-wheel lock)
    reset_scene()
    p = palette()
    add_box("VaultFrameL", (-1.50, 0, 1.75), (0.34, 0.42, 3.50), p["stone_obsidian"], bevel=0.025)
    add_box("VaultFrameR", (1.50, 0, 1.75), (0.34, 0.42, 3.50), p["stone_obsidian"], bevel=0.025)
    add_box("VaultDoorL", (-0.68, 0, 1.70), (1.30, 0.26, 3.35), p["iron_dark"], bevel=0.02)
    add_box("VaultDoorR", (0.68, 0, 1.70), (1.30, 0.26, 3.35), p["iron_dark"], bevel=0.02)
    add_torus("SunWheel", (0, 0.16, 1.75), 0.68, 0.075, p["gold_sponsored"], rot=(math.radians(90), 0, 0))
    for ang in range(0, 180, 45):
        add_box("Spoke", (0, 0.16, 1.75), (1.28, 0.08, 0.09), p["gold_sponsored"], rot=(0, math.radians(ang), 0), bevel=0.01)
    add_sphere("CenterGem", (0, 0.20, 1.75), 0.22, p["arcane_cyan"])
    exported.append(export_asset(batch, "vault_gate", manifest))

    # 14. staircase_down (carved Nordic descending stairwell with flanking stone balustrades & lanterns)
    reset_scene()
    p = palette()
    for i in range(7):
        y = -1.35 + i * 0.44
        z = -0.06 - i * 0.22
        add_box("Step", (0, y, z), (2.40, 0.48, 0.24), p["stone_mid"], bevel=0.02)
    for sx in (-1.45, 1.45):
        add_box("Balustrade", (sx, 0.0, 0.52), (0.44, 3.30, 1.04), p["stone_trim"], bevel=0.03)
        add_box("NewelPost", (sx, -1.52, 0.78), (0.58, 0.58, 1.56), p["stone_trim"], bevel=0.03)
        add_sphere("NewelFlame", (sx, -1.52, 1.72), 0.14, p["flame_glow"])
    add_box("DescentVoid", (0, 0.55, -1.65), (2.40, 2.20, 0.20), p["stone_obsidian"], bevel=0.01)
    exported.append(export_asset(batch, "staircase_down", manifest))

    # 15. spike_trap (recessed forged iron grate with steel floor spikes)
    reset_scene()
    p = palette()
    add_box("TrapPlate", (0, 0, 0.03), (2.20, 2.20, 0.06), p["iron_dark"], bevel=0.015)
    for ix in (-0.65, 0.0, 0.65):
        for iy in (-0.65, 0.0, 0.65):
            add_cone("Spike", (ix, iy, 0.30), 0.08, 0.006, 0.54, p["steel"], vertices=8)
    exported.append(export_asset(batch, "spike_trap", manifest))

    # 16. lever (carved stone mechanism pedestal with forged iron switch lever)
    reset_scene()
    p = palette()
    add_box("LeverBase", (0, 0, 0.38), (0.56, 0.56, 0.76), p["stone_trim"], bevel=0.025)
    add_cylinder("Pivot", (0, 0, 0.78), 0.11, 0.34, p["iron_dark"], rot=(0, math.radians(90), 0))
    add_cylinder("Rod", (0, 0.16, 1.10), 0.04, 0.76, p["steel"], rot=(math.radians(-24), 0, 0))
    add_sphere("Knob", (0, 0.32, 1.46), 0.10, p["bronze"])
    exported.append(export_asset(batch, "lever", manifest))

    # === NEW HANDCRAFTED SETPIECE PROPS (D-029) ===

    # 17. brazier (forged iron tripod floor brazier with glowing ember bed & sculptural flame)
    reset_scene()
    p = palette()
    add_lathe("Bowl", [(0.16, 0.58), (0.38, 0.72), (0.48, 0.90), (0.52, 0.98), (0.44, 0.98), (0.34, 0.78)], p["iron_dark"], segments=12)
    add_torus("BowlRing", (0, 0, 0.94), 0.49, 0.032, p["bronze"], major_seg=20)
    for ang in (0, 120, 240):
        rad = math.radians(ang)
        add_curved_tube(
            "Leg",
            [(math.cos(rad) * 0.42, math.sin(rad) * 0.42, 0.0),
             (math.cos(rad) * 0.32, math.sin(rad) * 0.32, 0.38),
             (math.cos(rad) * 0.34, math.sin(rad) * 0.34, 0.76)],
            [0.045, 0.04, 0.045],
            p["iron_dark"],
            sides=8,
        )
    add_sphere("Embers", (0, 0, 0.92), 0.36, p["ember_bed"], scale=(1.0, 1.0, 0.45))
    add_cone("FireMain", (0, 0, 1.24), 0.24, 0.015, 0.62, p["flame_glow"], vertices=10)
    add_cone("FireSide", (0.09, -0.06, 1.18), 0.14, 0.01, 0.44, p["flame_glow"], vertices=8, rot=(0.15, 0.22, 0))
    exported.append(export_asset(batch, "brazier", manifest))

    # 18. wall_banner (tattered crimson-and-gold Syndicate war banner on forged crossbar)
    reset_scene()
    p = palette()
    add_cylinder("Crossbar", (0, 0.08, 2.38), 0.035, 1.38, p["iron_dark"], rot=(0, math.radians(90), 0))
    for sx in (-0.70, 0.70):
        add_sphere("Finial", (sx, 0.08, 2.38), 0.065, p["bronze"])
    add_box("BannerCloth", (0, 0.07, 1.35), (1.06, 0.03, 1.98), p["cloth_red"], bevel=0.008)
    add_cone("BannerTip", (0, 0.07, 0.22), 0.53, 0.02, 0.36, p["cloth_red"], vertices=4, rot=(math.radians(180), 0, math.radians(45)))
    add_box("GoldCrest", (0, 0.095, 1.60), (0.34, 0.02, 0.34), p["gold_sponsored"], rot=(0, math.radians(45), 0), bevel=0.008)
    exported.append(export_asset(batch, "wall_banner", manifest))

    # 19. sanctuary_rug (ornate woven crimson-and-gold floor carpet for Safe Room & Vault)
    reset_scene()
    p = palette()
    add_box("RugMain", (0, 0, 0.016), (3.40, 2.20, 0.028), p["cloth_red"], bevel=0.008)
    add_box("GoldInlay", (0, 0, 0.022), (2.90, 1.70, 0.020), p["gold_sponsored"], bevel=0.005)
    add_box("InnerCloth", (0, 0, 0.026), (2.74, 1.54, 0.020), p["cloth_red"], bevel=0.005)
    exported.append(export_asset(batch, "sanctuary_rug", manifest))

    # 20. merchant_stall (handcrafted timber canopy vendor booth with counter, wares & lanterns)
    reset_scene()
    p = palette()
    add_box("Counter", (0, 0.36, 0.52), (2.50, 0.76, 1.04), p["wood_warm"], bevel=0.025)
    add_box("CounterTop", (0, 0.36, 1.06), (2.68, 0.90, 0.09), p["wood_dark"], bevel=0.02)
    for sx in (-1.22, 1.22):
        for sy in (-0.52, 0.62):
            add_box("Post", (sx, sy, 1.28), (0.14, 0.14, 2.56), p["wood_dark"], bevel=0.015)
    # Pitched crimson-striped fabric awning
    add_box("Awning", (0, 0.06, 2.66), (2.88, 1.65, 0.12), p["cloth_red"], rot=(math.radians(16), 0, 0), bevel=0.02)
    add_box("AwningTrim", (0, 0.80, 2.40), (2.88, 0.10, 0.18), p["gold_sponsored"], bevel=0.01)
    # Display potions & gold coins on counter
    for i, px in enumerate((-0.82, -0.56, 0.72)):
        add_lathe("DisplayVial", [(0.06, 0.0), (0.09, 0.08), (0.04, 0.22), (0.055, 0.26)], p["potion_red"] if i < 2 else p["arcane_cyan"], loc=(px, 0.45, 1.10), segments=12)
    for sx in (-1.16, 1.16):
        add_sphere("StallLantern", (sx, 0.78, 2.18), 0.12, p["flame_glow"])
    exported.append(export_asset(batch, "merchant_stall", manifest))

    # 21. barrel (iron-hooped curved oak barrel)
    reset_scene()
    p = palette()
    add_lathe("BarrelBody", [(0.26, 0.0), (0.34, 0.24), (0.36, 0.48), (0.34, 0.72), (0.26, 0.94)], p["wood_warm"], segments=16)
    for z, r in [(0.18, 0.335), (0.76, 0.335)]:
        add_torus("Hoop", (0, 0, z), r, 0.022, p["iron_dark"], major_seg=20)
    exported.append(export_asset(batch, "barrel", manifest))

    # 22. boss_dais (raised stepped octagonal obsidian & bronze runic Boss Arena pedestal)
    reset_scene()
    p = palette()
    add_cylinder("DaisStep1", (0, 0, 0.12), 2.85, 0.24, p["stone_obsidian"], vertices=8, bevel=0.03)
    add_cylinder("DaisStep2", (0, 0, 0.34), 2.15, 0.22, p["stone_trim"], vertices=8, bevel=0.025)
    add_torus("DaisRuneOuter", (0, 0, 0.46), 1.88, 0.042, p["bronze"], major_seg=32)
    add_torus("DaisRuneInner", (0, 0, 0.46), 1.24, 0.030, p["boss_ember"], major_seg=32)
    exported.append(export_asset(batch, "boss_dais", manifest))

    return exported
