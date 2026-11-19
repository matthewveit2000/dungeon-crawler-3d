"""Batch 1A — Nordic-ruin modular architecture kit (4 m grid, 4.5 m nominal wall height).

Conventions (Blender, Z-up; exported Y-up so Blender -Y == Godot +Z):
  * Floor tile: 4 x 4 m, walking surface at z = 0, centred on origin.
  * Wall segment: spans x in [-2, 2] on the tile EDGE (y = 0); its stone face looks toward -Y
    (into the room) at y ~ -0.30, masonry body extends back to y = +0.32. Height 0 .. 4.75 m.
  * Ceiling tile: coffered stone vault; beams' underside at 4.3 m, coffer crown ~5.35 m.
  * Pillar: centred, 0 .. 4.35 m.  Door arch: spans the tile edge (like a wall) with a 2.7 m opening.

Run: blender -b --python art/blender/build_environment.py -- [--only name,...] [--preview]
"""

from __future__ import annotations

import math
import random
import sys
import pathlib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

from dclib import core, shapes, render  # noqa: E402

W = 4.0
H_WALL = 4.75
FACE_Y = -0.30
BACK_Y = 0.32
BEAM_Z = 4.30


# ---------------------------------------------------------------------------
# Masonry helpers
# ---------------------------------------------------------------------------

def _course_widths(rnd, total, lo, hi):
    ws = []
    acc = 0.0
    while acc < total - 1e-6:
        w = rnd.uniform(lo, hi)
        if total - (acc + w) < lo * 0.6:
            w = total - acc
        ws.append(w)
        acc += w
    return ws


def masonry_wall(seed, x0=-W / 2, x1=W / 2, z0=0.0, z1=H_WALL, face_y=FACE_Y, skip=None, base=True,
                 cornice=True, mat="stone_block", trim="stone_trim", gap=0.03):
    """Returns list of stone objects forming an ashlar wall face. skip(x, z, w, h) -> True to omit a stone."""
    rnd = random.Random(seed)
    parts = []
    z = z0
    width = x1 - x0
    if base:
        bh = 0.46
        x = x0
        for w in _course_widths(rnd, width, 0.9, 1.6):
            d = 0.42
            c = (x + w / 2, face_y - 0.06 + d / 2, z + bh / 2)
            if not (skip and skip(c[0], c[2], w, bh)):
                parts.append(shapes.stone((w - gap, d, bh - gap), c, seed=rnd.randrange(1 << 30), mat=trim,
                                          bevel=0.04, irregular=0.012, cuts=1))
            x += w
        z += bh
    top = z1 - (0.62 if cornice else 0.0)
    while z < top - 1e-3:
        h = rnd.choice([rnd.uniform(0.30, 0.42), rnd.uniform(0.42, 0.62), rnd.uniform(0.55, 0.78)])
        if top - (z + h) < 0.28:
            h = top - z
        x = x0
        for w in _course_widths(rnd, width, 0.42, 1.65):
            d = rnd.uniform(0.30, 0.42)
            inset = rnd.uniform(-0.03, 0.03)
            # occasional split stone: two half-height stones stacked inside one course slot
            split = h > 0.5 and w < 0.9 and rnd.random() < 0.22
            sub = [(z + h * 0.25, h * 0.5), (z + h * 0.75, h * 0.5)] if split else [(z + h / 2, h)]
            for (zc, hh) in sub:
                c = (x + w / 2, face_y + inset + d / 2, zc)
                if skip and skip(c[0], c[2], w, hh):
                    continue
                rot = (rnd.uniform(-0.02, 0.02), rnd.uniform(-0.015, 0.015), rnd.uniform(-0.012, 0.012))
                tone = rnd.uniform(0.68, 1.1)
                parts.append(shapes.stone((w - gap * rnd.uniform(0.7, 1.4), d, hh - gap * rnd.uniform(0.7, 1.4)), c,
                                          seed=rnd.randrange(1 << 30), mat=mat,
                                          bevel=rnd.uniform(0.018, 0.034), irregular=rnd.uniform(0.014, 0.028),
                                          freq=rnd.uniform(1.4, 2.6), chip=0.6, cuts=2 if w > 1.0 else 1, rot=rot,
                                          tint=tone))
            x += w
        z += h
    if cornice:
        ch = 0.30
        x = x0
        for w in _course_widths(rnd, width, 1.2, 2.2):
            c = (x + w / 2, face_y - 0.10 + 0.25, z + ch / 2)
            parts.append(shapes.stone((w - gap * 0.6, 0.5, ch), c, seed=rnd.randrange(1 << 30), mat=trim,
                                      bevel=0.07, irregular=0.008, cuts=1, bevel_segments=3))
            x += w
        z += ch
        # plain upper course up to the ceiling beams
        x = x0
        uh = z1 - z
        for w in _course_widths(rnd, width, 0.8, 1.5):
            c = (x + w / 2, face_y + 0.04 + 0.2, z + uh / 2)
            parts.append(shapes.stone((w - gap, 0.4, uh - gap * 0.5), c, seed=rnd.randrange(1 << 30), mat=mat,
                                      bevel=0.03, irregular=0.01, cuts=1))
            x += w
    return parts


def mortar_backing(x0=-W / 2, x1=W / 2, z0=0.0, z1=H_WALL, face_y=FACE_Y + 0.06):
    ob = shapes.box((x1 - x0, BACK_Y - face_y, z1 - z0), ((x0 + x1) / 2, (face_y + BACK_Y) / 2, (z0 + z1) / 2),
                    mat="mortar", name="Mortar")
    return ob


def finish(parts, name, seed, ao=True, ground=0.5, smooth=38.0, ao_dist=0.6, rays=18):
    ob = core.join(parts, name)
    core.finalize(ob, smooth_angle=smooth, uv="box", seed=seed, weathering=0.9, ground_dirt=ground, ground_h=0.9)
    if ao:
        shapes.bake_vertex_ao(ob, rays=rays, dist=ao_dist, strength=0.8)
    return ob


# ---------------------------------------------------------------------------
# Pieces
# ---------------------------------------------------------------------------

def build_wall(variant: str):
    seeds = {"a": 101, "b": 202, "c": 303, "niche": 404, "damaged": 505, "banner": 606}
    seed = seeds[variant]
    parts = []
    skip = None
    if variant == "niche":
        def skip(x, z, w, h):
            return abs(x) < 0.85 + w / 2 - 0.05 and 0.75 < z < 2.65
    if variant == "damaged":
        rnd = random.Random(seed)
        holes = [(rnd.uniform(-1.2, 1.2), rnd.uniform(1.0, 3.2)) for _ in range(3)]

        def skip(x, z, w, h):
            return any(abs(x - hx) < 0.45 and abs(z - hz) < 0.35 for hx, hz in holes)
    parts += masonry_wall(seed, skip=skip)
    parts.append(mortar_backing())
    if variant == "niche":
        parts += _niche(seed)
    if variant == "damaged":
        parts += _rubble_pile(seed, (0.4, FACE_Y - 0.35, 0.0), count=14, spread=0.9)
    return finish(parts, f"wall_{variant}", seed)


def _niche(seed):
    """Arched burial alcove: framed recess with a slab shelf, skull, bones and a votive candle."""
    rnd = random.Random(seed + 9)
    parts = []
    r = 0.62
    spring = 1.95
    depth_back = FACE_Y + 0.5
    # back + sides of recess (dark trim stone)
    parts.append(shapes.box((1.5, 0.08, 1.9), (0, depth_back + 0.04, 0.75 + 0.95), mat="stone_trim", name="NicheBack"))
    for sx in (-1, 1):
        parts.append(shapes.box((0.12, 0.55, 1.25), (sx * 0.68, FACE_Y + 0.27, 0.75 + 0.62), mat="stone_trim"))
    # arch voussoirs framing the top
    n = 7
    for i in range(n):
        a0 = math.pi * i / n
        a1 = math.pi * (i + 1) / n
        v = shapes.wedge_stone(r, r + 0.24, a0 + 0.004, a1 - 0.004, 0.5, seed=seed + i, mat="stone_trim")
        v.location = (0, FACE_Y + 0.2, spring)
        bpy.context.view_layer.update()
        core.apply_transform(v)
        parts.append(v)
    # vault fill behind the arch
    vault = shapes.lathe([(0.0, 0.0), (r * 0.98, 0.0)], 16, "NicheVault", "stone_trim")
    vault.rotation_euler = (math.pi / 2, 0, 0)
    vault.location = (0, depth_back, spring)
    bpy.context.view_layer.update()
    core.apply_transform(vault)
    parts.append(vault)
    # jamb stones
    for sx in (-1, 1):
        for k in range(3):
            parts.append(shapes.stone((0.26, 0.5, 0.38), (sx * (r + 0.12), FACE_Y + 0.2, 0.95 + k * 0.4),
                                      seed=seed + 20 + k * 3 + sx, mat="stone_trim", bevel=0.03, cuts=1))
    # shelf slab
    parts.append(shapes.stone((1.6, 0.62, 0.14), (0, FACE_Y + 0.18, 0.8), seed=seed + 40, mat="stone_trim", bevel=0.03))
    from build_props import make_skull, make_bone, make_candle
    sk = make_skull(seed)
    sk.rotation_euler = (0, 0, rnd.uniform(-0.4, 0.4) + math.pi)
    sk.location = (-0.2, FACE_Y + 0.3, 0.87)
    bpy.context.view_layer.update()
    core.apply_transform(sk)
    parts.append(sk)
    for k in range(3):
        b = make_bone(seed + k, length=rnd.uniform(0.28, 0.42))
        b.rotation_euler = (0, math.pi / 2, rnd.uniform(-1.2, 1.2))
        b.location = (rnd.uniform(0.0, 0.45), FACE_Y + rnd.uniform(0.15, 0.45), 0.9)
        bpy.context.view_layer.update()
        core.apply_transform(b)
        parts.append(b)
    c = make_candle(seed, height=0.16)
    c.location = (0.42, FACE_Y + 0.18, 0.87)
    bpy.context.view_layer.update()
    core.apply_transform(c)
    parts.append(c)
    return parts


def _rubble_pile(seed, center, count=12, spread=0.8, max_size=0.32):
    rnd = random.Random(seed + 77)
    parts = []
    for i in range(count):
        s = rnd.uniform(0.08, max_size)
        dx, dy = rnd.gauss(0, spread * 0.45), rnd.gauss(0, spread * 0.3)
        p = (center[0] + dx, center[1] + dy * 0.6, center[2] + s * 0.35)
        parts.append(shapes.stone((s * rnd.uniform(0.8, 1.6), s * rnd.uniform(0.7, 1.3), s * rnd.uniform(0.5, 0.9)),
                                  p, seed=seed + i * 13, mat="stone_block", bevel=s * 0.12, irregular=s * 0.08,
                                  rot=(rnd.uniform(-0.5, 0.5), rnd.uniform(-0.5, 0.5), rnd.uniform(0, 3.14)), cuts=1))
    return parts


def build_floor(variant: str):
    seeds = {"a": 11, "b": 22, "c": 33}
    seed = seeds[variant]
    rnd = random.Random(seed)
    parts = []
    gap = 0.035
    y = -W / 2
    while y < W / 2 - 1e-6:
        h = rnd.uniform(0.62, 1.05)
        if W / 2 - (y + h) < 0.45:
            h = W / 2 - y
        x = -W / 2
        for w in _course_widths(rnd, W, 0.7, 1.5):
            t = 0.16
            tilt = (rnd.uniform(-0.008, 0.008), rnd.uniform(-0.008, 0.008), 0.0)
            zc = -t / 2 + rnd.uniform(-0.012, 0.006)
            parts.append(shapes.stone((w - gap, h - gap, t), (x + w / 2, y + h / 2, zc), seed=rnd.randrange(1 << 30),
                                      mat="stone_floor", bevel=0.025, irregular=0.006, freq=1.4, chip=0.35, cuts=2,
                                      rot=tilt))
            x += w
        y += h
    grout = shapes.box((W, W, 0.12), (0, 0, -0.1), mat="dirt", name="Grout")
    parts.append(grout)
    ob = core.join(parts, f"floor_{variant}")
    core.finalize(ob, smooth_angle=35, uv="box", seed=seed, weathering=0.8)
    shapes.bake_vertex_ao(ob, rays=14, dist=0.25, strength=0.7)
    return ob


def build_ceiling(variant: str):
    seed = {"a": 71, "b": 72}[variant]
    rnd = random.Random(seed)
    parts = []
    beam_h = 0.4
    half = 0.21
    # half-beams along the four tile edges (adjacent tiles complete each beam)
    for k in range(4):
        ang = k * math.pi / 2
        b = shapes.stone((W + 0.02, half * 2 - 0.02, beam_h), (0, 0, 0), seed=seed + k, mat="stone_trim",
                         bevel=0.06, irregular=0.006, cuts=2, bevel_segments=3)
        b.location = (0, -W / 2, BEAM_Z + beam_h / 2)
        b.rotation_euler = (0, 0, ang)
        bpy.context.view_layer.update()
        # rotate around tile centre
        from mathutils import Matrix
        b.matrix_world = Matrix.Rotation(ang, 4, "Z") @ Matrix.Translation((0, -W / 2, BEAM_Z + beam_h / 2))
        bpy.context.view_layer.update()
        core.apply_transform(b)
        parts.append(b)
    # corner corbels where beams cross
    for cx in (-1, 1):
        for cy in (-1, 1):
            parts.append(shapes.stone((0.52, 0.52, 0.5), (cx * W / 2, cy * W / 2, BEAM_Z + 0.2), seed=seed + 10 + cx + cy * 3,
                                      mat="stone_trim", bevel=0.06, cuts=1))
    # shallow domical coffer vault: ring of curved stone panels
    inner = W / 2 - half + 0.06
    rows = 5
    segs = 16
    crown = 1.0
    vault_parts = []
    import bmesh
    bm = bmesh.new()
    grid = []
    n = 12
    for j in range(n + 1):
        row = []
        for i in range(n + 1):
            x = -inner + 2 * inner * i / n
            y = -inner + 2 * inner * j / n
            # dome height from a squircle radius so edges meet beams flat
            rx, ry = abs(x) / inner, abs(y) / inner
            r = max(rx, ry) ** 2 * 0.6 + (rx * rx + ry * ry) * 0.2
            z = BEAM_Z + beam_h + crown * (1.0 - min(1.0, r)) ** 1.2
            row.append(bm.verts.new((x, y, z)))
        grid.append(row)
    for j in range(n):
        for i in range(n):
            bm.faces.new((grid[j][i], grid[j + 1][i], grid[j + 1][i + 1], grid[j][i + 1]))
    vault = core.obj_from_bmesh(bm, "Vault", "stone_ashlar")
    core.add_solidify(vault, 0.08, 1.0)
    core.add_subsurf(vault, 1)
    core.apply_modifiers(vault)
    parts.append(vault)
    # ribs: two diagonal ribs + a ring rib for a carved, Romanesque feel
    for sgn in (-1, 1):
        pts = []
        for t in [i / 10 for i in range(11)]:
            x = -inner + 2 * inner * t
            y = sgn * x
            rx, ry = abs(x) / inner, abs(y) / inner
            r = max(rx, ry) ** 2 * 0.6 + (rx * rx + ry * ry) * 0.2
            z = BEAM_Z + beam_h + crown * (1.0 - min(1.0, r)) ** 1.2 - 0.06
            pts.append((x * 0.98, y * 0.98, z))
        parts.append(shapes.tube(pts, radius=0.09, seg=8, mat="stone_trim", name="Rib", resolution=3))
    # central carved boss
    boss = shapes.lathe([(0.0, -0.22), (0.12, -0.2), (0.2, -0.12), (0.24, 0.0), (0.18, 0.06), (0.0, 0.08)], 16,
                        "Boss", "stone_trim")
    boss.location = (0, 0, BEAM_Z + beam_h + crown - 0.02)
    bpy.context.view_layer.update()
    core.apply_transform(boss)
    parts.append(boss)
    if variant == "b":
        # iron ring + hanging chain from the boss
        ring = shapes.torus(0.07, 0.012, (0, 0, BEAM_Z + beam_h + crown - 0.3), mat="iron_dark", rot=(math.pi / 2, 0, 0))
        parts.append(ring)
        parts += shapes.chain((0, 0, BEAM_Z + beam_h + crown - 0.36), (0, 0, BEAM_Z - 0.4), link_len=0.07, wire=0.011)
    ob = core.join(parts, f"ceiling_{variant}")
    core.finalize(ob, smooth_angle=40, uv="box", seed=seed, weathering=0.8)
    shapes.bake_vertex_ao(ob, rays=14, dist=0.9, strength=0.75)
    return ob


def build_pillar():
    seed = 900
    parts = []
    r = 0.36
    # plinth
    parts.append(shapes.stone((1.0, 1.0, 0.28), (0, 0, 0.14), seed=seed, mat="stone_trim", bevel=0.05, cuts=1))
    base = shapes.lathe([(0.47, 0.28), (0.47, 0.34), (0.44, 0.38), (0.45, 0.42), (0.42, 0.48), (0.39, 0.52),
                         (0.40, 0.56), (r, 0.6)], 32, "Base", "stone_trim", cap_bottom=False, cap_top=False)
    parts.append(base)
    # shaft built from drums for masonry joints
    z = 0.6
    top = 3.62
    drums = 5
    dh = (top - z) / drums
    for i in range(drums):
        prof = []
        steps = 6
        for k in range(steps + 1):
            t = k / steps
            zz = z + i * dh + t * dh
            # slight entasis
            g = (zz - 0.6) / (top - 0.6)
            rr = r * (1.0 - 0.06 * g) + 0.012 * math.sin(g * math.pi)
            edge = 0.012 if (k == 0 or k == steps) else 0.0
            prof.append((rr - edge, zz))
        d = shapes.lathe(prof, 32, "Drum", "stone_block", cap_bottom=True, cap_top=True)
        core.tint_part(d, random.Random(seed + i).uniform(0.85, 1.05))
        core.displace_noise(d, amp=0.006, freq=3.0, seed=seed + i)
        parts.append(d)
    # carved interlace band near the top (torus braid)
    for k in range(2):
        parts.append(shapes.torus(r * 0.97, 0.03, (0, 0, 3.28 + k * 0.1), major=40, minor=8, mat="stone_trim"))
    # cushion capital + abacus
    cap = shapes.lathe([(r * 0.95, top), (0.42, top + 0.08), (0.5, top + 0.22), (0.56, top + 0.36), (0.0, top + 0.36)],
                       32, "Capital", "stone_trim", cap_bottom=False)
    parts.append(cap)
    parts.append(shapes.stone((1.1, 1.1, 0.34), (0, 0, top + 0.36 + 0.17), seed=seed + 50, mat="stone_trim", bevel=0.05, cuts=1))
    ob = core.join(parts, "pillar")
    core.finalize(ob, smooth_angle=50, uv="cyl", seed=seed, weathering=0.9, ground_dirt=0.6, ground_h=1.0)
    shapes.bake_vertex_ao(ob, rays=12, dist=0.4, strength=0.7)
    return ob


def build_door_arch():
    """Portal frame on a tile edge: jambs, voussoir arch with keystone, spandrel masonry above."""
    seed = 777
    rnd = random.Random(seed)
    parts = []
    span = 2.7
    r_in = span / 2
    r_out = r_in + 0.42
    spring = 2.75
    depth = 0.86  # protrudes into both tiles
    # jambs (stacked stones) — fill from opening edge to tile corner
    for sx in (-1, 1):
        z = 0.0
        k = 0
        while z < spring - 1e-3:
            h = 0.46 if k % 2 == 0 else 0.4
            h = min(h, spring - z)
            w = 0.62 if k % 2 == 0 else 0.5
            cx = sx * (r_in + w / 2)
            parts.append(shapes.stone((w, depth, h - 0.025), (cx, 0.0, z + h / 2), seed=seed + k * 7 + sx,
                                      mat="stone_trim", bevel=0.04, cuts=1))
            k += 1
            z += h
        # filler from jamb to tile corner (behind adjacent walls)
        parts.append(shapes.box((W / 2 - r_in - 0.45, 0.62, H_WALL), (sx * (W / 2 + r_in + 0.45) / 2 + sx * 0.0, 0.0, H_WALL / 2),
                                mat="stone_block", name="JambFill"))
        # imposts (projecting springer blocks)
        parts.append(shapes.stone((0.72, depth + 0.1, 0.22), (sx * (r_in + 0.3), 0.0, spring + 0.08), seed=seed + 90 + sx,
                                  mat="stone_trim", bevel=0.05, cuts=1, bevel_segments=3))
    # voussoirs
    n = 11
    for i in range(n):
        a0 = math.pi * i / n
        a1 = math.pi * (i + 1) / n
        extra = 0.14 if i == n // 2 else 0.0  # keystone
        v = shapes.wedge_stone(r_in, r_out + extra, a0 + 0.006, a1 - 0.006, depth + (0.08 if extra else 0.0),
                               seed=seed + i, mat="stone_trim", bevel=0.03)
        v.location = (0, 0, spring + 0.19)
        bpy.context.view_layer.update()
        core.apply_transform(v)
        parts.append(v)
    # intrados soffit (smooth underside of arch)
    soffit = shapes.lathe([(r_in - 0.01, -depth / 2 + 0.03), (r_in - 0.01, depth / 2 - 0.03)], 24, "Soffit", "stone_trim",
                          cap_bottom=False, cap_top=False)
    soffit.rotation_euler = (math.pi / 2, 0, 0)
    soffit.location = (0, 0, spring + 0.19)
    bpy.context.view_layer.update()
    core.apply_transform(soffit)
    # keep only the upper half of the soffit cylinder
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(soffit.data)
    kill = [v for v in bm.verts if v.co.z < spring + 0.18]
    bmesh.ops.delete(bm, geom=kill, context="VERTS")
    bm.to_mesh(soffit.data)
    bm.free()
    for p in soffit.data.polygons:
        p.use_smooth = True
    soffit.data.flip_normals() if hasattr(soffit.data, "flip_normals") else None
    parts.append(soffit)
    # spandrels: masonry above/around the arch up to the wall top, on both faces
    def skip(x, z, w, h):
        rr = math.hypot(x, z - (spring + 0.19))
        return z < spring + 0.19 + 0.05 and abs(x) < r_out + 0.2 or rr < r_out + 0.12 + max(w, h) * 0.45
    for face in (-1, 1):
        sp = masonry_wall(seed + 31 + face, z0=spring + 0.2, z1=H_WALL, base=False, cornice=False, skip=skip,
                          face_y=face * 0.43 if face < 0 else 0.43 - 0.36)
        parts += sp
    parts.append(shapes.box((W, 0.5, H_WALL - (spring + r_out + 0.15)), (0, 0, (H_WALL + spring + r_out + 0.15) / 2),
                            mat="mortar", name="SpandrelCore"))
    ob = finish(parts, "door_arch", seed, ground=0.4, ao_dist=0.5)
    return ob


def build_stair_well():
    """Descending stairwell: balustraded opening, steps sinking into darkness (interactable centre)."""
    seed = 515
    rnd = random.Random(seed)
    parts = []
    # surrounding floor ring (the builder skips the regular floor tile here)
    for (cx, cy, sx, sy) in [(-1.6, 0, 0.8, 4.0), (1.6, 0, 0.8, 4.0), (0, 1.6, 2.4, 0.8)]:
        parts.append(shapes.stone((sx - 0.03, sy - 0.03, 0.16), (cx, cy, -0.08), seed=rnd.randrange(1 << 20),
                                  mat="stone_floor", bevel=0.02, cuts=2))
    # steps descending toward -Y (entry side at -Y)
    steps = 9
    for i in range(steps):
        z = -0.2 - i * 0.24
        y = -1.7 + i * 0.36 + 0.3
        parts.append(shapes.stone((2.3, 0.4, 0.24), (0, y, z), seed=seed + i, mat="stone_trim", bevel=0.03, cuts=1))
    # side walls of the well
    for sx in (-1, 1):
        parts += masonry_wall(seed + 40 + sx, x0=-2.0, x1=2.0, z0=-3.4, z1=-0.05, base=False, cornice=False,
                              face_y=0.0)
        for o in parts[-12:]:
            pass
    well_walls = []
    for sx in (-1, 1):
        ws = masonry_wall(seed + 60 + sx, x0=-2.0, x1=1.8, z0=-3.2, z1=0.0, base=False, cornice=False, face_y=-0.02)
        for o in ws:
            o.rotation_euler = (0, 0, sx * math.pi / 2)
            o.location = (sx * -1.18 * -1, 0, 0)
            bpy.context.view_layer.update()
            core.apply_transform(o)
        well_walls += ws
    parts = [p for p in parts if p.location is not None]
    parts += well_walls
    # back wall
    bw = masonry_wall(seed + 70, x0=-1.2, x1=1.2, z0=-3.2, z1=0.0, base=False, cornice=False, face_y=-0.0)
    for o in bw:
        o.location = (0, 1.25, 0)
        o.rotation_euler = (0, 0, math.pi)
        bpy.context.view_layer.update()
        core.apply_transform(o)
    parts += bw
    # balustrade on three sides
    for (x0, y0, x1, y1) in [(-1.25, -1.9, -1.25, 1.25), (1.25, -1.9, 1.25, 1.25), (-1.25, 1.25, 1.25, 1.25)]:
        length = math.hypot(x1 - x0, y1 - y0)
        ang = math.atan2(y1 - y0, x1 - x0)
        cxm, cym = (x0 + x1) / 2, (y0 + y1) / 2
        rail = shapes.stone((length + 0.2, 0.32, 0.16), (0, 0, 0), seed=seed + int(length * 10), mat="stone_trim", bevel=0.04)
        rail.rotation_euler = (0, 0, ang)
        rail.location = (cxm, cym, 0.92)
        bpy.context.view_layer.update()
        core.apply_transform(rail)
        parts.append(rail)
        nb = max(2, int(length / 0.42))
        for i in range(nb + 1):
            t = i / nb
            px, py = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            bal = shapes.lathe([(0.1, 0.0), (0.1, 0.08), (0.06, 0.14), (0.085, 0.42), (0.05, 0.7), (0.09, 0.76), (0.09, 0.84)],
                               12, "Baluster", "stone_trim")
            bal.location = (px, py, 0.0)
            bpy.context.view_layer.update()
            core.apply_transform(bal)
            parts.append(bal)
    # darkness at the bottom
    parts.append(shapes.box((2.6, 3.0, 0.05), (0, 0.2, -3.3), mat="void_black", name="Abyss"))
    ob = core.join(parts, "staircase_down")
    core.finalize(ob, smooth_angle=40, uv="box", seed=seed, weathering=0.9)
    shapes.bake_vertex_ao(ob, rays=12, dist=0.8, strength=0.8)
    return ob


# ---------------------------------------------------------------------------
# Preview vignette: assemble a small room from the kit
# ---------------------------------------------------------------------------

def preview_room(pieces):
    from mathutils import Matrix
    lib = {k: v for k, v in pieces.items()}
    for o in lib.values():
        o.hide_render = True
    inst = []

    def put(key, x, y, rot=0.0):
        src = lib[key]
        o = src.copy()
        o.data = src.data
        o.hide_render = False
        core.link(o)
        o.matrix_world = Matrix.Translation((x, y, 0)) @ Matrix.Rotation(rot, 4, "Z")
        inst.append(o)
        return o
    # 3 x 3 room centred at origin, open toward the camera side (-Y)
    for i in (-1, 0, 1):
        for j in (-1, 0, 1, 2):
            put("floor_" + "abc"[(i + j) % 3], i * W, j * W)
            put("ceiling_" + ("b" if (i, j) == (0, 1) else "a"), i * W, j * W)
    walls = ["a", "b", "niche", "c", "damaged", "a", "b", "c"]
    k = 0
    for i in (-1, 0, 1):  # back wall (+Y side), faces -Y
        put("wall_" + walls[k % len(walls)], i * W, 2 * W + W / 2, 0.0)
        k += 1
    for j in (-1, 0, 1, 2):  # side walls
        put("wall_" + walls[k % len(walls)], -1.5 * W, j * W, math.pi / 2)
        k += 1
        put("wall_" + walls[k % len(walls)], 1.5 * W, j * W, -math.pi / 2)
        k += 1
    put("pillar", -W, W * 0.5)
    put("pillar", W, W * 0.5)
    # lights: warm torches + cool ambient
    for (x, y, z, e) in [(-5.1, 3.0, 2.5, 220), (5.1, 6.0, 2.5, 220), (-2.0, 9.1, 2.5, 240), (0.0, 0.0, 3.6, 90)]:
        render._light("POINT", (x, y, z), e, (1.0, 0.62, 0.32), 0.12, name="Torch")
    render._light("SUN", (0, 0, 10), 0.25, (0.55, 0.65, 0.9), 2.0, rot=(0.6, 0.2, 0.0), name="Moon")
    render.render_scene((0.6, -5.6, 1.75), (0.0, 6.0, 2.1), "batch1_kit_room", lens=22, samples=48, w=1280, h=720)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = set()
    preview = "--preview" in argv
    for i, a in enumerate(argv):
        if a == "--only":
            only = set(argv[i + 1].split(","))
    core.reset_scene()
    builders = {
        "wall_a": lambda: build_wall("a"),
        "wall_b": lambda: build_wall("b"),
        "wall_c": lambda: build_wall("c"),
        "wall_niche": lambda: build_wall("niche"),
        "wall_damaged": lambda: build_wall("damaged"),
        "floor_a": lambda: build_floor("a"),
        "floor_b": lambda: build_floor("b"),
        "floor_c": lambda: build_floor("c"),
        "ceiling_a": lambda: build_ceiling("a"),
        "ceiling_b": lambda: build_ceiling("b"),
        "pillar": build_pillar,
        "door_arch": build_door_arch,
    }
    pieces = {}
    for name, fn in builders.items():
        if only and name not in only:
            continue
        ob = fn()
        ob.name = name
        core.export_glb(ob, f"kit/{name}", "kit")
        pieces[name] = ob
    core.write_manifest()
    if preview and all(k in pieces for k in ("wall_a", "floor_a", "ceiling_a", "pillar")):
        preview_room(pieces)


if __name__ == "__main__":
    main()
