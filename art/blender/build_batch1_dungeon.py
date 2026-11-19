"""Batch 1: Modular 4m Nordic-Ruin Dungeon Kit & Interactive Props."""

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


def build_floor_tile() -> None:
    reset_scene()
    p = palette()
    add_box("BaseSlab", (0, 0, -0.15), (4.0, 4.0, 0.3), p["stone_dark"], bevel=0.02)
    # 2x2 large beveled flagstone tiles on top
    offsets = [(-1.0, -1.0), (1.0, -1.0), (-1.0, 1.0), (1.0, 1.0)]
    for i, (ox, oy) in enumerate(offsets):
        mat = p["stone_mid"] if i % 2 == 0 else p["stone_dark"]
        add_box(f"Flagstone_{i}", (ox, oy, 0.03), (1.92, 1.92, 0.08), mat, bevel=0.03)
    add_box("CenterRuneInset", (0, 0, 0.05), (0.65, 0.65, 0.06), p["stone_trim"], rot=(0, 0, math.radians(45)), bevel=0.02)


def build_ceiling_tile() -> None:
    reset_scene()
    p = palette()
    add_box("CeilingSlab", (0, 0, 0.2), (4.0, 4.0, 0.4), p["stone_dark"], bevel=0.02)
    add_box("BeamX", (0, 0, -0.15), (4.0, 0.42, 0.35), p["stone_trim"], bevel=0.03)
    add_box("BeamY", (0, 0, -0.15), (0.42, 4.0, 0.35), p["stone_trim"], bevel=0.03)


def build_wall_segment() -> None:
    reset_scene()
    p = palette()
    # 4.0m wide x 0.55m thick x 4.5m tall Nordic stone wall
    add_box("WallCore", (0, 0, 2.25), (4.0, 0.52, 4.5), p["stone_dark"], bevel=0.02)
    add_box("BasePlinth", (0, 0, 0.32), (4.0, 0.66, 0.64), p["stone_trim"], bevel=0.03)
    add_box("MidBand", (0, 0, 2.35), (4.0, 0.60, 0.28), p["stone_trim"], bevel=0.025)
    add_box("TopCornice", (0, 0, 4.30), (4.0, 0.68, 0.40), p["stone_trim"], bevel=0.03)
    # Stylized masonry relief blocks
    for bx in (-1.3, 0.0, 1.3):
        add_box(f"BlockLow_{bx}", (bx, 0, 1.3), (1.15, 0.57, 0.85), p["stone_mid"], bevel=0.025)
        add_box(f"BlockHigh_{bx}", (bx, 0, 3.3), (1.15, 0.57, 0.95), p["stone_mid"], bevel=0.025)


def build_pillar() -> None:
    reset_scene()
    p = palette()
    add_box("PlinthBase", (0, 0, 0.28), (1.05, 1.05, 0.56), p["stone_trim"], bevel=0.04)
    add_cylinder("Shaft", (0, 0, 2.25), 0.36, 3.6, p["stone_mid"], vertices=8, bevel=0.02)
    add_cylinder("MidRing", (0, 0, 2.25), 0.44, 0.22, p["iron_dark"], vertices=8, bevel=0.02)
    add_box("Capital", (0, 0, 4.22), (1.1, 1.1, 0.56), p["stone_trim"], bevel=0.04)


def build_archway() -> None:
    reset_scene()
    p = palette()
    add_box("LeftJamb", (-1.55, 0, 1.9), (0.9, 0.72, 3.8), p["stone_mid"], bevel=0.03)
    add_box("RightJamb", (1.55, 0, 1.9), (0.9, 0.72, 3.8), p["stone_mid"], bevel=0.03)
    add_box("Lintel", (0, 0, 4.05), (4.0, 0.82, 0.9), p["stone_trim"], bevel=0.04)
    add_box("Keystone", (0, 0, 3.85), (0.65, 0.92, 0.78), p["bronze"], bevel=0.03)


def build_stairs_down() -> None:
    reset_scene()
    p = palette()
    # Recessed Nordic stairwell frame + descending steps
    add_box("RimNorth", (0, 1.75, 0.35), (3.8, 0.42, 0.7), p["stone_trim"], bevel=0.03)
    add_box("RimWest", (-1.75, 0, 0.35), (0.42, 3.8, 0.7), p["stone_trim"], bevel=0.03)
    add_box("RimEast", (1.75, 0, 0.35), (0.42, 3.8, 0.7), p["stone_trim"], bevel=0.03)
    for i in range(6):
        add_box(f"Step_{i}", (0, -1.2 + i * 0.45, 0.02 - i * 0.26), (3.0, 0.52, 0.24), p["stone_mid"], bevel=0.02)
    # Glowing mysterious descent portal below (no preview!)
    add_box("DescentVoid", (0, 0.4, -1.45), (2.9, 2.6, 0.15), p["arcane_cyan"], bevel=0.01)
    # Corner torch posts
    for sx in (-1.65, 1.65):
        add_cylinder(f"Post_{sx}", (sx, -1.65, 1.15), 0.12, 2.3, p["iron_dark"], vertices=8)
        add_sphere(f"Beacon_{sx}", (sx, -1.65, 2.4), 0.2, p["arcane_cyan"])


def build_boss_gate() -> None:
    reset_scene()
    p = palette()
    # Heavy iron portcullis gate (3.6m wide x 3.8m tall)
    add_box("TopBeam", (0, 0, 3.65), (3.6, 0.32, 0.35), p["iron_dark"], bevel=0.02)
    add_box("MidBeam", (0, 0, 1.9), (3.6, 0.26, 0.26), p["iron_dark"], bevel=0.02)
    add_box("BottomBeam", (0, 0, 0.25), (3.6, 0.3, 0.3), p["iron_dark"], bevel=0.02)
    for i in range(-4, 5):
        add_cylinder(f"Bar_{i}", (i * 0.38, 0, 1.9), 0.065, 3.6, p["steel"], vertices=8, bevel=0.005)
    add_box("BossSealEmblem", (0, 0.16, 1.95), (0.65, 0.12, 0.65), p["boss_ember"], rot=(0, math.radians(45), 0), bevel=0.02)


def build_torch_sconce() -> None:
    reset_scene()
    p = palette()
    add_box("WallPlate", (0, 0, 0.35), (0.24, 0.08, 0.44), p["iron_dark"], bevel=0.01)
    add_cylinder("Handle", (0, 0.22, 0.45), 0.045, 0.56, p["wood_dark"], vertices=8, rot=(math.radians(24), 0, 0))
    add_torus("IronRing", (0, 0.22, 0.48), 0.07, 0.018, p["iron_dark"], rot=(math.radians(24), 0, 0))
    add_cone("Flame", (0, 0.32, 0.84), 0.10, 0.01, 0.32, p["flame_glow"], vertices=10)


def build_chest() -> None:
    reset_scene()
    p = palette()
    add_box("ChestBody", (0, 0, 0.32), (1.15, 0.68, 0.62), p["wood_dark"], bevel=0.02)
    add_cylinder("ChestLid", (0, 0, 0.64), 0.34, 1.15, p["wood_warm"], vertices=14, rot=(0, math.radians(90), 0), bevel=0.01)
    for sx in (-0.42, 0.42):
        add_box(f"IronStrap_{sx}", (sx, 0, 0.48), (0.10, 0.72, 0.84), p["iron_dark"], bevel=0.01)
    add_box("LockPlate", (0, -0.35, 0.54), (0.18, 0.08, 0.22), p["bronze"], bevel=0.01)


def build_crate() -> None:
    reset_scene()
    p = palette()
    add_box("CrateBody", (0, 0, 0.45), (0.86, 0.86, 0.86), p["wood_warm"], bevel=0.02)
    add_box("FrameTop", (0, 0, 0.86), (0.92, 0.92, 0.1), p["wood_dark"], bevel=0.015)
    add_box("FrameBot", (0, 0, 0.05), (0.92, 0.92, 0.1), p["wood_dark"], bevel=0.015)
    add_box("DiagBrace", (0, -0.44, 0.45), (0.92, 0.06, 0.12), p["wood_dark"], rot=(0, math.radians(42), 0), bevel=0.01)


def build_urn() -> None:
    reset_scene()
    p = palette()
    add_cylinder("UrnFoot", (0, 0, 0.08), 0.2, 0.16, p["stone_dark"], vertices=12)
    add_sphere("UrnBelly", (0, 0, 0.46), 0.36, p["stone_mid"], scale=(1.0, 1.0, 1.25))
    add_cylinder("UrnNeck", (0, 0, 0.88), 0.16, 0.22, p["stone_trim"], vertices=12)
    add_torus("UrnRim", (0, 0, 0.98), 0.19, 0.04, p["bronze"])


def build_lever() -> None:
    reset_scene()
    p = palette()
    add_box("Pedestal", (0, 0, 0.45), (0.55, 0.55, 0.9), p["stone_mid"], bevel=0.03)
    add_box("SlotPlate", (0, 0, 0.92), (0.32, 0.42, 0.08), p["iron_dark"], bevel=0.01)
    add_cylinder("LeverArm", (0, 0.14, 1.22), 0.035, 0.72, p["steel"], vertices=8, rot=(math.radians(28), 0, 0))
    add_sphere("LeverKnob", (0, 0.30, 1.54), 0.085, p["bronze"])


def build_spike_trap() -> None:
    reset_scene()
    p = palette()
    add_box("GrateBase", (0, 0, 0.04), (1.8, 1.8, 0.08), p["iron_dark"], bevel=0.015)
    for gx in (-0.55, 0.0, 0.55):
        for gy in (-0.55, 0.0, 0.55):
            add_cone(f"Spike_{gx}_{gy}", (gx, gy, 0.32), 0.08, 0.008, 0.52, p["steel"], vertices=6)


def build_vendor_stall() -> None:
    reset_scene()
    p = palette()
    add_box("Counter", (0, 0, 0.52), (2.4, 0.95, 1.04), p["wood_dark"], bevel=0.025)
    add_box("CounterTop", (0, 0, 1.08), (2.55, 1.08, 0.12), p["wood_warm"], bevel=0.02)
    for sx in (-1.1, 1.1):
        add_cylinder(f"Post_{sx}", (sx, -0.35, 1.3), 0.07, 2.6, p["wood_dark"], vertices=8)
        add_cylinder(f"PostBack_{sx}", (sx, 0.35, 1.4), 0.07, 2.8, p["wood_dark"], vertices=8)
    add_box("Awning", (0, 0, 2.65), (2.7, 1.45, 0.14), p["cloth_teal"], rot=(math.radians(14), 0, 0), bevel=0.02)
    add_sphere("SafeLantern", (1.1, -0.5, 2.25), 0.16, p["safe_emerald"])


def build_quest_board() -> None:
    reset_scene()
    p = palette()
    for sx in (-0.85, 0.85):
        add_box(f"Post_{sx}", (sx, 0, 1.15), (0.14, 0.14, 2.3), p["wood_dark"], bevel=0.015)
    add_box("BoardPanel", (0, 0, 1.55), (1.75, 0.12, 1.15), p["wood_warm"], bevel=0.02)
    add_box("RoofCap", (0, 0, 2.22), (2.05, 0.48, 0.16), p["stone_trim"], bevel=0.02)
    for px, pz in [(-0.45, 1.65), (0.05, 1.55), (0.48, 1.72), (-0.15, 1.25)]:
        add_box(f"Notice_{px}_{pz}", (px, -0.08, pz), (0.34, 0.02, 0.42), p["parchment"], bevel=0.004)


def build_all_batch1(manifest_entries: list[dict]) -> list[pathlib.Path]:
    builders = [
        ("floor_tile", build_floor_tile),
        ("ceiling_tile", build_ceiling_tile),
        ("wall_segment", build_wall_segment),
        ("pillar", build_pillar),
        ("archway", build_archway),
        ("stairs_down", build_stairs_down),
        ("boss_gate", build_boss_gate),
        ("torch_sconce", build_torch_sconce),
        ("chest", build_chest),
        ("crate", build_crate),
        ("urn", build_urn),
        ("lever", build_lever),
        ("spike_trap", build_spike_trap),
        ("vendor_stall", build_vendor_stall),
        ("quest_board", build_quest_board),
    ]
    paths: list[pathlib.Path] = []
    for name, fn in builders:
        fn()
        paths.append(export_asset("batch1", name, manifest_entries))
    return paths
