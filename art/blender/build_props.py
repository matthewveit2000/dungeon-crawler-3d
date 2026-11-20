"""Batch 1B — Dungeon props, dressing & interactables.

Run: blender -b --python art/blender/build_props.py -- [--only name,...] [--preview]
"""

from __future__ import annotations

import math
import pathlib
import random
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

from dclib import core, render, shapes  # noqa: E402


def _xf(ob, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    ob.matrix_world = Matrix.Translation(loc) @ Matrix(Euler_to_mat(rot)) @ Matrix.Diagonal((*scale, 1.0))
    bpy.context.view_layer.update()
    core.apply_transform(ob)
    return ob


def Euler_to_mat(rot):
    from mathutils import Euler
    return Euler(rot, "XYZ").to_matrix().to_4x4()


def boolean(target, cutter, op="DIFFERENCE"):
    m = target.modifiers.new("Bool", "BOOLEAN")
    m.operation = op
    m.solver = "EXACT"
    m.object = cutter
    core.apply_modifiers(target)
    core.delete([cutter])
    return target


# ---------------------------------------------------------------------------
# Small dressing parts (also reused by the wall niche & characters)
# ---------------------------------------------------------------------------

def make_skull(seed=0, scale=1.0, mat="bone", jaw=True):
    rnd = random.Random(seed)
    cran = shapes.sphere(0.1, (0, 0.01, 0.02), seg=24, rings=16, mat=mat, name="Cranium", scale=(0.82, 1.0, 0.92))
    face = shapes.sphere(0.075, (0, -0.045, -0.035), seg=20, rings=12, mat=mat, name="Face", scale=(0.95, 0.75, 0.85))
    cran = boolean(cran, face, "UNION")
    # brow ridge
    brow = shapes.tube([(-0.065, -0.07, 0.005), (0.0, -0.09, 0.012), (0.065, -0.07, 0.005)], radius=0.017, seg=8,
                       mat=mat, name="Brow")
    cran = boolean(cran, brow, "UNION")
    for sx in (-1, 1):
        sock = shapes.sphere(0.028, (sx * 0.034, -0.088, -0.022), seg=14, rings=8, mat=mat, name="Socket",
                             scale=(1.0, 1.1, 0.9))
        cran = boolean(cran, sock)
    nose = shapes.cone(0.016, 0.045, (0, -0.1, -0.075), seg=3, mat=mat, rot=(0, 0, 0))
    cran = boolean(cran, nose)
    parts = [cran]
    # cheekbones
    for sx in (-1, 1):
        parts.append(shapes.sphere(0.02, (sx * 0.058, -0.07, -0.05), seg=10, rings=6, mat=mat, scale=(1.2, 1.0, 0.7)))
    # upper teeth
    for i in range(8):
        a = (i - 3.5) / 3.5 * 0.9
        x = math.sin(a) * 0.035
        y = -0.085 + (1 - math.cos(a)) * 0.03
        parts.append(shapes.box((0.009, 0.008, 0.016), (x, y, -0.09), mat="teeth", bevel=0.002, seg=1))
    if jaw:
        jw = shapes.tube([(-0.055, -0.02, -0.07), (-0.05, -0.065, -0.11), (0.0, -0.088, -0.122), (0.05, -0.065, -0.11),
                          (0.055, -0.02, -0.07)], radius=0.014, seg=8, mat=mat, name="Jaw", radii=[0.9, 1.1, 1.3, 1.1, 0.9])
        parts.append(jw)
        for i in range(6):
            a = (i - 2.5) / 2.5 * 0.8
            parts.append(shapes.box((0.008, 0.007, 0.012), (math.sin(a) * 0.032, -0.083 + (1 - math.cos(a)) * 0.026, -0.104),
                                    mat="teeth", bevel=0.002, seg=1))
    ob = core.join(parts, "Skull")
    core.displace_noise(ob, amp=0.002, freq=30.0, seed=seed)
    ob.scale = (scale, scale, scale)
    ob.location = (0, 0, 0.135 * scale)
    bpy.context.view_layer.update()
    core.apply_transform(ob)
    core.tint_part(ob, rnd.uniform(0.85, 1.0))
    return ob


def make_bone(seed=0, length=0.36, mat="bone"):
    L = length
    prof = [(0.0, 0.0), (0.02, 0.003), (0.03, 0.018), (0.024, 0.04), (0.014, 0.09), (0.012, L * 0.5),
            (0.014, L - 0.09), (0.024, L - 0.04), (0.03, L - 0.018), (0.02, L - 0.003), (0.0, L)]
    ob = shapes.lathe(prof, 10, "Bone", mat)
    ob.scale = (1.0, 0.8, 1.0)
    ob.location = (0, 0, -L / 2)
    bpy.context.view_layer.update()
    core.apply_transform(ob)
    core.displace_noise(ob, amp=0.004, freq=12.0, seed=seed)
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def make_candle(seed=0, height=0.2, radius=0.028, flame=True):
    rnd = random.Random(seed)
    prof = [(0.0, 0.0), (radius, 0.0), (radius * 1.04, height * 0.2), (radius, height * 0.9), (radius * 0.85, height),
            (radius * 0.4, height - 0.006), (0.0, height - 0.01)]
    c = shapes.lathe(prof, 14, "Candle", "wax")
    core.displace_noise(c, amp=radius * 0.12, freq=40.0, seed=seed)
    parts = [c]
    # wax drips
    for i in range(3):
        a = rnd.uniform(0, math.tau)
        z0 = height * rnd.uniform(0.6, 0.95)
        parts.append(shapes.tube([(math.cos(a) * radius, math.sin(a) * radius, z0),
                                  (math.cos(a) * radius * 1.05, math.sin(a) * radius * 1.05, z0 - rnd.uniform(0.03, 0.08))],
                                 radius=0.005, seg=6, mat="wax", radii=[1.0, 0.6], name="Drip"))
    parts.append(shapes.cylinder(0.002, 0.02, (0, 0, height + 0.004), segments=6, mat="plastic_black", name="Wick"))
    if flame:
        fl = shapes.lathe([(0.0, 0.0), (0.008, 0.006), (0.009, 0.016), (0.004, 0.03), (0.0, 0.042)], 10, "Flame", "flame_glow")
        fl.location = (0, 0, height + 0.01)
        bpy.context.view_layer.update()
        core.apply_transform(fl)
        parts.append(fl)
    return core.join(parts, "CandleSet")


# ---------------------------------------------------------------------------
# Export helpers
# ---------------------------------------------------------------------------

def socket(parent, name, loc):
    e = bpy.data.objects.new(name, None)
    core.link(e)
    e.empty_display_size = 0.1
    e.location = loc
    e.parent = parent
    return e


def finish(parts, name, seed, uv="box", ao=True, ao_dist=0.35, rays=14, smooth=40, ground=0.0):
    ob = core.join(parts, name) if isinstance(parts, list) else parts
    ob.name = name
    core.finalize(ob, smooth_angle=smooth, uv=uv, seed=seed, weathering=0.8, ground_dirt=ground, ground_h=0.5)
    if ao:
        shapes.bake_vertex_ao(ob, rays=rays, dist=ao_dist, strength=0.75)
    return ob


# ---------------------------------------------------------------------------
# Lighting props
# ---------------------------------------------------------------------------

def build_torch_sconce():
    """Wall-mounted iron sconce holding a pitch torch. Mount point at origin on the wall face (faces -Y)."""
    parts = []
    plate = shapes.box((0.13, 0.03, 0.28), (0, 0.0, 0.0), mat="iron_dark", bevel=0.008)
    parts.append(plate)
    parts += shapes.rivet_row((0, -0.016, 0.11), (0, -0.016, -0.11), 2, (0, -1, 0), r=0.014)
    # scrolled bracket arm
    parts.append(shapes.tube([(0, -0.01, -0.06), (0, -0.12, -0.05), (0, -0.22, 0.02), (0, -0.27, 0.12)], radius=0.016,
                             seg=8, mat="iron_dark", name="Arm"))
    parts.append(shapes.tube([(0, -0.01, 0.09), (0, -0.08, 0.13), (0, -0.16, 0.1), (0, -0.2, 0.05)], radius=0.011,
                             seg=8, mat="iron_dark", name="Scroll"))
    # holder ring + cup
    ring = shapes.torus(0.045, 0.011, (0, -0.28, 0.13), major=20, minor=8, mat="iron_dark")
    parts.append(ring)
    cup = shapes.lathe([(0.03, 0.0), (0.05, 0.05), (0.058, 0.09), (0.054, 0.095), (0.0, 0.03)], 16, "Cup", "iron_dark")
    cup.location = (0, -0.28, 0.1)
    bpy.context.view_layer.update()
    core.apply_transform(cup)
    parts.append(cup)
    # torch: tapered handle tilted outward, wrapped pitch head
    tilt = math.radians(14)
    handle = shapes.lathe([(0.018, 0.0), (0.024, 0.08), (0.028, 0.38), (0.0, 0.38)], 10, "Handle", "wood_beam")
    _xf(handle, (0, -0.28, 0.02), (-tilt, 0, 0))
    parts.append(handle)
    head = shapes.lathe([(0.0, 0.0), (0.036, 0.0), (0.046, 0.04), (0.05, 0.1), (0.044, 0.15), (0.03, 0.17), (0.0, 0.175)],
                        14, "Head", "cloth_burlap")
    core.displace_noise(head, amp=0.006, freq=30.0, seed=3)
    core.tint_part(head, 0.32)
    _xf(head, (0, -0.28 - math.sin(tilt) * 0.34, 0.02 + math.cos(tilt) * 0.34), (-tilt, 0, 0))
    parts.append(head)
    for k in range(3):
        band = shapes.torus(0.049 - k * 0.002, 0.005, (0, 0, 0.03 + k * 0.05), major=16, minor=5, mat="rope")
        _xf(band, (0, -0.28 - math.sin(tilt) * 0.34, 0.02 + math.cos(tilt) * 0.34), (-tilt, 0, 0))
        parts.append(band)
    embers = shapes.sphere(0.035, (0, 0, 0.0), seg=12, rings=6, mat="embers", scale=(1, 1, 0.45))
    _xf(embers, (0, -0.28 - math.sin(tilt) * 0.51, 0.02 + math.cos(tilt) * 0.51), (-tilt, 0, 0))
    parts.append(embers)
    ob = finish(parts, "torch_sconce", 31, ao_dist=0.12)
    socket(ob, "FlameSocket", (0, -0.28 - math.sin(tilt) * 0.53, 0.02 + math.cos(tilt) * 0.55))
    return ob


def build_brazier():
    parts = []
    rnd = random.Random(5)
    bowl = shapes.lathe([(0.0, 0.62), (0.12, 0.6), (0.3, 0.66), (0.42, 0.76), (0.47, 0.86), (0.5, 0.88), (0.46, 0.89),
                         (0.43, 0.84), (0.0, 0.8)], 32, "Bowl", "iron_dark")
    parts.append(bowl)
    parts.append(shapes.torus(0.48, 0.022, (0, 0, 0.885), major=40, minor=8, mat="iron_dark"))
    # decorative rim spikes
    for i in range(12):
        a = i / 12 * math.tau
        sp = shapes.cone(0.022, 0.09, (math.cos(a) * 0.48, math.sin(a) * 0.48, 0.88), seg=6, mat="iron_dark")
        parts.append(sp)
    # three curved legs with claw feet
    for i in range(3):
        a = i / 3 * math.tau + 0.3
        ca, sa = math.cos(a), math.sin(a)
        pts = [(ca * 0.2, sa * 0.2, 0.68), (ca * 0.42, sa * 0.42, 0.5), (ca * 0.46, sa * 0.46, 0.22), (ca * 0.36, sa * 0.36, 0.04)]
        parts.append(shapes.tube(pts, radius=0.03, seg=8, mat="iron_dark", radii=[1.0, 1.1, 0.9, 1.2], name="Leg"))
        foot = shapes.sphere(0.055, (ca * 0.36, sa * 0.36, 0.03), seg=12, rings=8, mat="iron_dark", scale=(1.3, 1.3, 0.55))
        parts.append(foot)
        for t in (-0.4, 0.0, 0.4):
            b = a + t
            parts.append(shapes.cone(0.016, 0.07, (ca * 0.36 + math.cos(b) * 0.05, sa * 0.36 + math.sin(b) * 0.05, 0.02),
                                     seg=6, mat="iron_dark", rot=(0, math.radians(80), b)))
    # ring brace
    parts.append(shapes.torus(0.43, 0.014, (0, 0, 0.32), major=36, minor=6, mat="iron_dark"))
    # heaped coals & charred logs
    coal = shapes.sphere(0.4, (0, 0, 0.82), seg=24, rings=10, mat="embers", scale=(1, 1, 0.22))
    core.displace_noise(coal, amp=0.04, freq=8.0, seed=2)
    parts.append(coal)
    for i in range(4):
        a = rnd.uniform(0, math.tau)
        log = shapes.cylinder(0.045, 0.55, (math.cos(a) * 0.05, math.sin(a) * 0.05, 0.9), segments=8, mat="wood_dark",
                              rot=(math.radians(rnd.uniform(70, 85)), 0, a))
        core.tint_part(log, 0.25)
        parts.append(log)
    ob = finish(parts, "brazier", 41, ao_dist=0.25, ground=0.5)
    socket(ob, "FlameSocket", (0, 0, 0.95))
    return ob


def build_candle_cluster():
    rnd = random.Random(8)
    parts = []
    pool = shapes.sphere(0.2, (0, 0, 0.0), seg=20, rings=8, mat="wax", scale=(1.0, 0.8, 0.06))
    core.displace_noise(pool, amp=0.01, freq=12, seed=4)
    parts.append(pool)
    for i in range(5):
        h = rnd.uniform(0.08, 0.3)
        c = make_candle(i, height=h, radius=rnd.uniform(0.018, 0.032))
        _xf(c, (rnd.uniform(-0.13, 0.13), rnd.uniform(-0.09, 0.09), 0.005))
        parts.append(c)
    ob = finish(parts, "candle_cluster", 81, ao_dist=0.1)
    return ob


# ---------------------------------------------------------------------------
# Containers
# ---------------------------------------------------------------------------

def build_chest():
    """Iron-banded oak chest. Lid is a separate child object 'Lid' with its pivot on the hinge axis."""
    rnd = random.Random(12)
    W_, D_, H_ = 1.0, 0.62, 0.48
    body = []
    # plank walls
    for side in (-1, 1):
        for k in range(3):
            body.append(shapes.plank(W_, 0.03, H_ / 3 - 0.006, (0, side * (D_ / 2 - 0.015), 0.06 + H_ / 6 + k * H_ / 3),
                                     (math.pi / 2, 0, 0), seed=k + side * 5, mat="wood_oak"))
        for k in range(3):
            body.append(shapes.plank(D_ - 0.06, 0.03, H_ / 3 - 0.006, (side * (W_ / 2 - 0.015), 0, 0.06 + H_ / 6 + k * H_ / 3),
                                     (math.pi / 2, 0, math.pi / 2), seed=20 + k + side, mat="wood_oak"))
    body.append(shapes.box((W_ - 0.04, D_ - 0.04, 0.04), (0, 0, 0.08), mat="wood_oak"))
    # feet / skids
    for sx in (-1, 1):
        body.append(shapes.box((0.12, D_ + 0.02, 0.07), (sx * (W_ / 2 - 0.08), 0, 0.035), mat="wood_dark", bevel=0.01))
    # iron corner brackets & bands
    for sx in (-1, 1):
        for sy in (-1, 1):
            body.append(shapes.box((0.09, 0.09, H_ + 0.01), (sx * (W_ / 2 - 0.03), sy * (D_ / 2 - 0.03), 0.06 + H_ / 2),
                                   mat="iron_dark", bevel=0.008))
    for bx in (-0.28, 0.28):
        body.append(shapes.box((0.07, D_ + 0.016, H_ + 0.005), (bx, 0, 0.06 + H_ / 2), mat="iron_dark", bevel=0.006))
        body += shapes.rivet_row((bx, -D_ / 2 - 0.01, 0.12), (bx, -D_ / 2 - 0.01, 0.06 + H_ - 0.04), 4, (0, -1, 0), r=0.011)
    # lock plate
    body.append(shapes.box((0.16, 0.02, 0.2), (0, -D_ / 2 - 0.012, 0.06 + H_ - 0.1), mat="iron_dark", bevel=0.01))
    body.append(shapes.box((0.02, 0.01, 0.05), (0, -D_ / 2 - 0.024, 0.06 + H_ - 0.12), mat="void_black"))
    # side handles
    for sx in (-1, 1):
        body.append(shapes.torus(0.06, 0.012, (sx * (W_ / 2 + 0.03), 0, 0.06 + H_ * 0.6), mat="iron_dark",
                                 rot=(0, math.pi / 2, 0), scale=(1, 1, 1)))
    body_ob = finish(body, "chest", 12, ao_dist=0.2)
    # lid: half-cylinder of planks with bands; pivot at back top edge
    lid = []
    r = D_ / 2
    n = 6
    for i in range(n):
        a0 = math.pi * i / n
        a1 = math.pi * (i + 1) / n
        am = (a0 + a1) / 2
        wseg = 2 * r * math.sin((a1 - a0) / 2)
        p = shapes.plank(W_ - 0.02, wseg - 0.006, 0.035, (0, math.cos(am) * (r - 0.017), math.sin(am) * (r - 0.017) * 0.7),
                         (am - math.pi / 2, 0, 0), seed=40 + i, mat="wood_oak")
        lid.append(p)
    for sx in (-1, 1):
        cap = shapes.lathe([(0.0, 0.0), (r, 0.0), (r, 0.03), (0.0, 0.03)], 20, "LidCap", "wood_oak")
        _xf(cap, (sx * (W_ / 2 - 0.01) - (0.03 if sx > 0 else 0), 0, 0), (0, math.pi / 2, 0), (1, 1, 0.7))
        bm = bmesh.new()
        bm.from_mesh(cap.data)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -0.001], context="VERTS")
        bm.to_mesh(cap.data)
        bm.free()
        lid.append(cap)
    for bx in (-0.28, 0.28, -W_ / 2 + 0.03, W_ / 2 - 0.03):
        pts = [(bx, math.cos(a) * (r + 0.006), math.sin(a) * (r + 0.006) * 0.7) for a in [math.pi * k / 12 for k in range(13)]]
        lid.append(shapes.strap(pts, width=0.07 if abs(bx) < 0.4 else 0.06, thick=0.008))
    lid.append(shapes.box((0.12, 0.02, 0.1), (0, -r - 0.012, 0.0), mat="iron_dark", bevel=0.008))
    lid_ob = core.join(lid, "Lid")
    core.finalize(lid_ob, smooth_angle=40, uv="box", seed=13, weathering=0.8)
    shapes.bake_vertex_ao(lid_ob, rays=10, dist=0.2)
    # move so pivot (hinge) sits at origin: hinge line is the back top edge
    hinge = Vector((0, D_ / 2, 0.06 + H_))
    lid_ob.location = (0, 0, 0.06 + H_)
    bpy.context.view_layer.update()
    core.apply_transform(lid_ob)
    lid_ob.data.transform(Matrix.Translation(-hinge))
    lid_ob.location = hinge
    lid_ob.parent = body_ob
    return body_ob


def build_crate(seed=3):
    rnd = random.Random(seed)
    S = 0.86
    parts = []
    for face in range(6):
        for k in range(4):
            w = S / 4
            off = -S / 2 + w / 2 + k * w
            if face < 4:
                ang = face * math.pi / 2
                pl = shapes.plank(S - 0.12, w - 0.008, 0.028, (0, 0, 0), (0, 0, 0), seed=seed * 10 + face * 4 + k, mat="wood_rough")
                M = Matrix.Rotation(ang, 4, "Z") @ Matrix.Translation((0, -S / 2 + 0.014, S / 2)) @ \
                    Matrix.Rotation(math.pi / 2, 4, "X") @ Matrix.Translation((0, off, 0))
            else:
                pl = shapes.plank(S - 0.12, w - 0.008, 0.028, (0, 0, 0), (0, 0, 0), seed=seed * 10 + face * 4 + k, mat="wood_rough")
                M = Matrix.Translation((0, off, (S - 0.014) if face == 4 else 0.014))
            pl.matrix_world = M
            bpy.context.view_layer.update()
            core.apply_transform(pl)
            parts.append(pl)
    # frame battens
    t = 0.06
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(shapes.plank(S, t, t, (sx * (S / 2 - t / 2 + 0.006), sy * (S / 2 - t / 2 + 0.006), S / 2),
                                      (0, math.pi / 2, 0), seed=seed + sx * 3 + sy, mat="wood_beam", bevel=0.008))
    for z in (t / 2, S - t / 2):
        for sy in (-1, 1):
            parts.append(shapes.plank(S, t, t, (0, sy * (S / 2 - t / 2 + 0.008), z), (0, 0, 0), seed=seed + int(z * 10) + sy,
                                      mat="wood_beam", bevel=0.008))
            parts.append(shapes.plank(S, t, t, (sy * (S / 2 - t / 2 + 0.008), 0, z), (0, 0, math.pi / 2), seed=seed + 7 + sy,
                                      mat="wood_beam", bevel=0.008))
    # diagonal braces on two faces
    for ang in (0, math.pi):
        br = shapes.plank(S * 1.25, 0.07, 0.025, (0, 0, 0), (0, 0, 0), seed=seed + 99, mat="wood_beam")
        br.matrix_world = Matrix.Rotation(ang, 4, "Z") @ Matrix.Translation((0, -S / 2 - 0.004, S / 2)) @ \
            Matrix.Rotation(math.pi / 2, 4, "X") @ Matrix.Rotation(math.pi / 4, 4, "Z")
        bpy.context.view_layer.update()
        core.apply_transform(br)
        parts.append(br)
    return finish(parts, "crate", seed, ao_dist=0.18, ground=0.3)


def build_barrel():
    rnd = random.Random(17)
    parts = []
    Hb = 1.0
    staves = 18

    def radius(z):
        t = z / Hb
        return 0.33 + 0.07 * math.sin(t * math.pi)
    for i in range(staves):
        a0 = i / staves * math.tau + 0.004
        a1 = (i + 1) / staves * math.tau - 0.004
        bm = bmesh.new()
        rows = 8
        verts = []
        for j in range(rows + 1):
            z = Hb * j / rows
            r = radius(z)
            row = []
            for a in (a0, a1):
                row.append((bm.verts.new((math.cos(a) * r, math.sin(a) * r, z)), bm.verts.new((math.cos(a) * (r - 0.03), math.sin(a) * (r - 0.03), z))))
            verts.append(row)
        for j in range(rows):
            (o0, i0), (o1, i1) = verts[j]
            (p0, q0), (p1, q1) = verts[j + 1]
            bm.faces.new((o0, o1, p1, p0))
            bm.faces.new((i1, i0, q0, q1))
            bm.faces.new((o0, p0, q0, i0))
            bm.faces.new((o1, i1, q1, p1))
        for j in (0, rows):
            (o0, i0), (o1, i1) = verts[j]
            if j == 0:
                bm.faces.new((o0, i0, i1, o1))
            else:
                bm.faces.new((o1, i1, i0, o0))
        st = core.obj_from_bmesh(bm, "Stave", "wood_oak")
        shapes.lock_uvs_along_x(st, i, axis="z")
        core.tint_part(st, rnd.uniform(0.75, 1.05))
        parts.append(st)
    for z in (0.08, 0.26, 0.74, 0.92):
        r = radius(z) + 0.006
        band = shapes.lathe([(r, z - 0.03), (r + 0.004, z), (r, z + 0.03)], 36, "Hoop", "iron_dark", cap_bottom=False, cap_top=False)
        parts.append(band)
    for z in (0.04, Hb - 0.04):
        lid = shapes.cylinder(radius(z) - 0.02, 0.03, (0, 0, z), segments=28, mat="wood_oak")
        parts.append(lid)
    ob = finish(parts, "barrel", 17, uv="cyl", ao_dist=0.2, ground=0.3)
    return ob


def build_urn():
    prof = [(0.0, 0.0), (0.13, 0.0), (0.15, 0.03), (0.13, 0.06), (0.2, 0.18), (0.27, 0.34), (0.28, 0.44), (0.24, 0.56),
            (0.15, 0.64), (0.12, 0.68), (0.14, 0.72), (0.16, 0.74), (0.15, 0.76)]
    body = shapes.lathe(prof, 32, "Urn", "stone_trim", cap_top=False)
    lid = shapes.lathe([(0.15, 0.75), (0.16, 0.78), (0.12, 0.83), (0.05, 0.86), (0.06, 0.9), (0.04, 0.93), (0.0, 0.94)], 24,
                       "UrnLid", "stone_trim")
    parts = [body, lid]
    for z, r in ((0.3, 0.272), (0.48, 0.272), (0.62, 0.18)):
        parts.append(shapes.torus(r, 0.012, (0, 0, z), major=40, minor=6, mat="bronze"))
    for sx in (-1, 1):
        parts.append(shapes.torus(0.05, 0.012, (sx * 0.22, 0, 0.56), mat="bronze", rot=(math.pi / 2, 0, 0)))
    return finish(parts, "urn", 23, uv="cyl", ao_dist=0.15)


# ---------------------------------------------------------------------------
# Fabric
# ---------------------------------------------------------------------------

def build_wall_banner():
    """Hanging war banner; mount point at origin on the wall face, hangs down -Z, faces -Y."""
    parts = []
    rod = shapes.cylinder(0.018, 1.3, (0, -0.12, 0.0), segments=10, mat="iron_dark", rot=(0, math.pi / 2, 0))
    parts.append(rod)
    for sx in (-1, 1):
        parts.append(shapes.sphere(0.035, (sx * 0.66, -0.12, 0.0), seg=12, rings=8, mat="gold_antique"))
        parts.append(shapes.cone(0.025, 0.07, (sx * 0.7, -0.12, 0.0), seg=8, mat="gold_antique", rot=(0, sx * math.pi / 2, 0)))
        parts.append(shapes.tube([(sx * 0.45, -0.12, 0.0), (sx * 0.3, -0.06, 0.25), (0, -0.02, 0.38)], radius=0.007,
                                 seg=6, mat="rope", name="Cord"))
    parts.append(shapes.box((0.12, 0.06, 0.08), (0, -0.02, 0.38), mat="iron_dark", bevel=0.01))
    cloth = shapes.cloth_panel(1.1, 2.1, cols=16, rows=24, folds=2.5, fold_amp=0.035, seed=4, mat="banner_crimson",
                               bottom="swallowtail", thickness=0.008)
    _xf(cloth, (0, -0.1, -0.03))
    parts.append(cloth)
    # gold fringe along the top hem
    for i in range(14):
        x = -0.5 + i / 13 * 1.0
        parts.append(shapes.cylinder(0.006, 0.06, (x, -0.13, -0.05), segments=5, mat="gold_antique"))
    ob = core.join(parts, "wall_banner")
    core.finalize(ob, smooth_angle=60, uv="box", seed=5, weathering=0.5)
    return ob


def build_rug():
    """Floor rug 2.4 x 3.4 m with gentle wrinkles and tasselled ends (authored UVs)."""
    w, l = 2.4, 3.4
    bm = bmesh.new()
    nx, ny = 24, 34
    grid = []
    for j in range(ny + 1):
        row = []
        for i in range(nx + 1):
            x = (i / nx - 0.5) * w
            y = (j / ny - 0.5) * l
            from mathutils import noise as mn
            z = 0.012 + max(0.0, mn.noise(Vector((x * 0.9, y * 0.9, 3.3)))) * 0.03
            if abs(abs(x) - w / 2) < 0.06 or abs(abs(y) - l / 2) < 0.06:
                z = 0.008
            row.append(bm.verts.new((x, y, z)))
        grid.append(row)
    uvl = bm.loops.layers.uv.new("UVMap")
    for j in range(ny):
        for i in range(nx):
            f = bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
            for loop, (a, b) in zip(f.loops, [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]):
                loop[uvl].uv = (a / nx, b / ny)
    rug = core.obj_from_bmesh(bm, "Rug", "rug_crimson")
    core.add_solidify(rug, 0.01, -1.0)
    core.apply_modifiers(rug)
    parts = [rug]
    for sy in (-1, 1):
        for i in range(30):
            x = (i / 29 - 0.5) * (w - 0.1)
            parts.append(shapes.tube([(x, sy * l / 2, 0.01), (x + 0.01, sy * (l / 2 + 0.06), 0.004), (x - 0.005, sy * (l / 2 + 0.11), 0.004)],
                                     radius=0.006, seg=5, mat="cloth_linen", name="Tassel"))
    ob = core.join(parts, "sanctuary_rug")
    core.finalize(ob, smooth_angle=60, uv="box", seed=9, weathering=0.3)
    return ob


# ---------------------------------------------------------------------------
# Setpieces
# ---------------------------------------------------------------------------

def build_boss_dais():
    parts = []
    rnd = random.Random(61)
    # two octagonal tiers built from stone segments
    for tier, (r0, r1, z0, z1) in enumerate([(3.0, 2.25, 0.0, 0.22), (2.25, 1.6, 0.22, 0.44)]):
        for i in range(8):
            a0 = i / 8 * math.tau + math.pi / 8
            a1 = (i + 1) / 8 * math.tau + math.pi / 8
            am = (a0 + a1) / 2
            # trapezoid slab between r1 (inner) and r0 (outer)
            bm = bmesh.new()
            pts = [(math.cos(a0) * r1, math.sin(a0) * r1), (math.cos(a0) * r0, math.sin(a0) * r0),
                   (math.cos(a1) * r0, math.sin(a1) * r0), (math.cos(a1) * r1, math.sin(a1) * r1)]
            bot = [bm.verts.new((x * 0.995, y * 0.995, z0)) for x, y in pts]
            top = [bm.verts.new((x * 0.995, y * 0.995, z1)) for x, y in pts]
            bm.faces.new(list(reversed(bot)))
            bm.faces.new(top)
            for k in range(4):
                bm.faces.new((bot[k], bot[(k + 1) % 4], top[(k + 1) % 4], top[k]))
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            seg = core.obj_from_bmesh(bm, "Tier", "stone_trim")
            core.add_bevel(seg, 0.03, 2, 30)
            core.apply_modifiers(seg)
            core.tint_part(seg, rnd.uniform(0.8, 1.02))
            parts.append(seg)
    # central glowing rune disc + iron ring
    disc = shapes.cylinder(1.6, 0.05, (0, 0, 0.465), segments=48, mat="rune_stone_red")
    parts.append(disc)
    parts.append(shapes.torus(1.6, 0.04, (0, 0, 0.47), major=64, minor=8, mat="iron_dark"))
    parts.append(shapes.torus(0.9, 0.03, (0, 0, 0.495), major=48, minor=8, mat="iron_dark"))
    for i in range(8):
        a = i / 8 * math.tau
        parts.append(shapes.box((0.12, 0.34, 0.06), (math.cos(a) * 1.25, math.sin(a) * 1.25, 0.49), mat="iron_dark",
                                bevel=0.01, rot=(0, 0, a)))
    return finish(parts, "boss_dais", 61, ao_dist=0.4, ground=0.0)


def build_safe_beacon():
    parts = []
    ped = shapes.lathe([(0.0, 0.0), (0.55, 0.0), (0.55, 0.12), (0.46, 0.18), (0.36, 0.24), (0.3, 0.4), (0.27, 0.8),
                        (0.33, 0.9), (0.42, 0.98), (0.44, 1.06), (0.0, 1.06)], 32, "Pedestal", "stone_trim")
    parts.append(ped)
    parts.append(shapes.cylinder(0.36, 0.04, (0, 0, 1.08), segments=40, mat="rune_stone"))
    for z, r in ((0.3, 0.33), (0.86, 0.33)):
        parts.append(shapes.torus(r, 0.02, (0, 0, z), major=40, minor=6, mat="bronze"))
    # cradle arms
    for i in range(3):
        a = i / 3 * math.tau
        pts = [(math.cos(a) * 0.3, math.sin(a) * 0.3, 1.05), (math.cos(a) * 0.42, math.sin(a) * 0.42, 1.35),
               (math.cos(a) * 0.32, math.sin(a) * 0.32, 1.75), (math.cos(a) * 0.14, math.sin(a) * 0.14, 1.95)]
        parts.append(shapes.tube(pts, radius=0.022, seg=8, mat="bronze", radii=[1.2, 1.0, 0.8, 0.5]))
    ob = core.join(parts, "safe_beacon")
    core.finalize(ob, smooth_angle=30, uv="box", seed=3, weathering=0.6)
    shapes.bake_vertex_ao(ob, rays=10, dist=0.2)
    # floating crystal (elongated octahedron with facets) as a separate child for gentle hover/spin
    bm = bmesh.new()
    ring = []
    n = 6
    for i in range(n):
        a = i / n * math.tau
        ring.append(bm.verts.new((math.cos(a) * 0.16, math.sin(a) * 0.16, -0.03)))
    top = bm.verts.new((0, 0, 0.34))
    bot = bm.verts.new((0, 0, -0.30))
    for i in range(n):
        bm.faces.new((ring[i], ring[(i + 1) % n], top))
        bm.faces.new((ring[(i + 1) % n], ring[i], bot))
    crystal = core.obj_from_bmesh(bm, "Crystal", "crystal_teal")
    core.finalize(crystal, smooth_angle=15, uv="box", seed=4, weathering=0.2)
    crystal.location = (0, 0, 1.58)
    crystal.parent = ob
    socket(ob, "GlowSocket", (0, 0, 1.6))
    return ob


def build_merchant_stall():
    rnd = random.Random(44)
    parts = []
    Wd, D = 2.6, 1.2
    # posts
    for sx in (-1, 1):
        for sy in (-1, 1):
            h = 2.5 if sy > 0 else 2.15
            parts.append(shapes.plank(h, 0.12, 0.12, (sx * Wd / 2, sy * D / 2, h / 2), (0, math.pi / 2, 0), seed=sx + sy * 3,
                                      mat="wood_beam", bevel=0.012))
    # counter
    for k in range(4):
        parts.append(shapes.plank(Wd + 0.1, 0.3, 0.05, (0, -D / 2 + 0.15 + k * 0.3, 0.95), (0, 0, 0), seed=10 + k, mat="wood_oak"))
    for k in range(4):
        parts.append(shapes.plank(Wd, 0.22, 0.03, (0, -D / 2 - 0.01, 0.12 + k * 0.22), (math.pi / 2, 0, 0), seed=20 + k, mat="wood_oak"))
    # back shelf
    for z in (1.35, 1.75):
        parts.append(shapes.plank(Wd - 0.1, 0.3, 0.04, (0, D / 2 - 0.15, z), (0, 0, 0), seed=int(z * 10), mat="wood_dark"))
    # canopy: alternating crimson / linen stripes, sloped
    stripes = 8
    for i in range(stripes):
        x0 = -Wd / 2 - 0.15 + i * (Wd + 0.3) / stripes
        cl = shapes.cloth_panel((Wd + 0.3) / stripes + 0.01, D + 0.6, cols=3, rows=10, folds=0.5, fold_amp=0.02, seed=i,
                                mat="cloth_crimson" if i % 2 == 0 else "cloth_linen", bottom="points", thickness=0.006)
        _xf(cl, (x0 + (Wd + 0.3) / stripes / 2, D / 2 + 0.15, 2.55), (math.radians(-90 + 14), 0, 0))
        parts.append(cl)
    # wares: bottles, sacks, small crates
    for i in range(7):
        x = -Wd / 2 + 0.25 + i * 0.33
        hb = rnd.uniform(0.18, 0.3)
        mat = rnd.choice(["glass_red", "glass_blue", "glass_green"])
        bottle = shapes.lathe([(0.0, 0.0), (0.06, 0.0), (0.065, hb * 0.6), (0.03, hb * 0.8), (0.02, hb), (0.024, hb + 0.02), (0.0, hb + 0.02)],
                              14, "Bottle", mat)
        _xf(bottle, (x, D / 2 - 0.15, 1.375))
        parts.append(bottle)
        parts.append(shapes.cylinder(0.022, 0.03, (x, D / 2 - 0.15, 1.375 + hb + 0.03), segments=8, mat="wood_oak"))
    for i in range(3):
        sack = shapes.sphere(0.22, (Wd / 2 - 0.3 - i * 0.45, -D / 2 - 0.35, 0.2), seg=16, rings=10, mat="cloth_burlap",
                             scale=(1.0, 0.9, 1.15))
        core.displace_noise(sack, amp=0.03, freq=6, seed=i)
        parts.append(sack)
        parts.append(shapes.tube([(Wd / 2 - 0.3 - i * 0.45 - 0.06, -D / 2 - 0.35, 0.44), (Wd / 2 - 0.3 - i * 0.45 + 0.06, -D / 2 - 0.35, 0.45)],
                                 radius=0.012, mat="rope"))
    # hanging lantern
    lx, ly, lz = -Wd / 2 + 0.25, -D / 2 - 0.05, 1.8
    parts += shapes.chain((lx, ly, 2.2), (lx, ly, lz + 0.18), link_len=0.05, wire=0.006)
    cage = shapes.lathe([(0.0, lz + 0.2), (0.07, lz + 0.17), (0.09, lz + 0.12), (0.09, lz - 0.08), (0.06, lz - 0.12), (0.0, lz - 0.12)], 6,
                        "LanternGlass", "glass_clear")
    _xf(cage, (lx, ly, 0))
    parts.append(cage)
    for i in range(6):
        a = i / 6 * math.tau
        parts.append(shapes.cylinder(0.008, 0.22, (lx + math.cos(a) * 0.092, ly + math.sin(a) * 0.092, lz + 0.02), segments=5, mat="iron_dark"))
    parts.append(shapes.sphere(0.03, (lx, ly, lz), seg=10, rings=6, mat="flame_glow", scale=(0.8, 0.8, 1.4)))
    ob = finish(parts, "merchant_stall", 44, ao_dist=0.4, ground=0.4)
    socket(ob, "LanternSocket", (lx, ly, lz))
    return ob


def build_quest_board():
    rnd = random.Random(55)
    parts = []
    for sx in (-1, 1):
        parts.append(shapes.plank(2.3, 0.12, 0.12, (sx * 0.95, 0, 1.15), (0, math.pi / 2, 0), seed=sx, mat="wood_beam", bevel=0.012))
    for k in range(6):
        parts.append(shapes.plank(1.8, 0.2, 0.04, (0, -0.07, 0.75 + k * 0.2), (math.pi / 2, 0, 0), seed=10 + k, mat="wood_oak"))
    # little roof
    for sy in (-1, 1):
        for k in range(5):
            pl = shapes.plank(2.3, 0.16, 0.025, (0, sy * (0.08 + k * 0.14), 2.32 - k * 0.07), (sy * math.radians(-27), 0, 0),
                              seed=30 + k + sy, mat="wood_rough")
            parts.append(pl)
    # parchment notices (authored UV) pinned with nails
    for i in range(6):
        w, h = rnd.uniform(0.32, 0.42), rnd.uniform(0.38, 0.52)
        x = -0.65 + (i % 3) * 0.62 + rnd.uniform(-0.05, 0.05)
        z = 1.55 - (i // 3) * 0.55 + rnd.uniform(-0.05, 0.05)
        paper = shapes.cloth_panel(w, h, cols=4, rows=5, folds=0.5, fold_amp=0.006, seed=i, mat="parchment", thickness=0.0)
        _xf(paper, (x, -0.1, z + h / 2), (0, rnd.uniform(-0.12, 0.12), 0))
        parts.append(paper)
        parts.append(shapes.cylinder(0.01, 0.02, (x, -0.112, z + h / 2 - 0.03), segments=6, mat="iron_dark", rot=(math.pi / 2, 0, 0)))
    # a dagger stuck through one notice (a dungeon greeting)
    blade = shapes.prism_from_outline([(0.0, 0.0), (0.02, 0.04), (0.018, 0.22), (0.0, 0.26), (-0.018, 0.22), (-0.02, 0.04)], 0.006,
                                      mat="steel_blade")
    _xf(blade, (0.55, -0.2, 1.3), (math.radians(80), 0, math.radians(20)))
    parts.append(blade)
    parts.append(shapes.cylinder(0.014, 0.1, (0.6, -0.3, 1.32), segments=8, mat="leather_dark", rot=(math.radians(80), 0, math.radians(20))))
    return finish(parts, "quest_board", 55, ao_dist=0.3, ground=0.4)


def build_boss_gate():
    """Spiked iron portcullis 3.6 x 3.8 m, centred on X, standing on z=0, thickness along Y."""
    parts = []
    Wg, Hg = 3.6, 3.8
    nb = 9
    for i in range(nb):
        x = -Wg / 2 + 0.2 + i * (Wg - 0.4) / (nb - 1)
        parts.append(shapes.box((0.07, 0.07, Hg - 0.2), (x, 0, 0.2 + (Hg - 0.2) / 2), mat="iron_dark", bevel=0.01))
        parts.append(shapes.cone(0.05, 0.22, (x, 0, 0.0), seg=4, mat="iron_dark", rot=(math.pi, 0, math.pi / 4)))
        _ = parts[-1]
        parts[-1].location = (0, 0, 0.2)
        bpy.context.view_layer.update()
        core.apply_transform(parts[-1])
    for k in range(6):
        z = 0.55 + k * 0.6
        parts.append(shapes.box((Wg, 0.05, 0.09), (0, 0.05, z), mat="iron_dark", bevel=0.01))
        for i in range(nb):
            x = -Wg / 2 + 0.2 + i * (Wg - 0.4) / (nb - 1)
            parts.append(shapes.sphere(0.03, (x, 0.08, z), seg=8, rings=5, mat="iron_dark", scale=(1, 0.6, 1)))
    parts.append(shapes.box((Wg + 0.1, 0.14, 0.16), (0, 0.02, Hg - 0.05), mat="iron_dark", bevel=0.02))
    return finish(parts, "boss_gate", 66, ao_dist=0.15)


def build_vault_gate():
    parts = []
    Wg, Hg = 3.6, 3.8
    for sx in (-1, 1):
        cx = sx * Wg / 4
        for k in range(5):
            parts.append(shapes.plank(Hg - 0.3, Wg / 2 / 5 - 0.01, 0.08, (cx - Wg / 4 + (k + 0.5) * Wg / 10, 0, (Hg - 0.3) / 2),
                                      (0, math.pi / 2, 0), seed=sx * 7 + k, mat="wood_dark"))
        for z in (0.5, 1.6, 2.7):
            parts.append(shapes.box((Wg / 2 - 0.06, 0.03, 0.12), (cx, -0.055, z), mat="gold_antique", bevel=0.01))
            parts += shapes.rivet_row((cx - Wg / 4 + 0.15, -0.075, z), (cx + Wg / 4 - 0.15, -0.075, z), 6, (0, -1, 0), r=0.018,
                                      mat="gold_antique")
        # ring pull
        parts.append(shapes.torus(0.1, 0.018, (sx * 0.22, -0.09, 1.35), mat="gold_antique", rot=(math.pi / 2, 0, 0)))
        parts.append(shapes.sphere(0.06, (sx * 0.22, -0.06, 1.45), seg=12, rings=8, mat="gold_antique", scale=(1, 0.5, 1)))
    # gilded arch frame
    parts.append(shapes.box((0.16, 0.2, Hg), (-Wg / 2 - 0.05, 0, Hg / 2), mat="gold_antique", bevel=0.02))
    parts.append(shapes.box((0.16, 0.2, Hg), (Wg / 2 + 0.05, 0, Hg / 2), mat="gold_antique", bevel=0.02))
    parts.append(shapes.box((Wg + 0.3, 0.22, 0.18), (0, 0, Hg - 0.2), mat="gold_antique", bevel=0.02))
    parts.append(shapes.sphere(0.16, (0, -0.1, Hg - 0.2), seg=16, rings=10, mat="crystal_gold", scale=(1, 0.5, 1)))
    return finish(parts, "vault_gate", 67, ao_dist=0.2)


def build_spike_trap():
    parts = []
    S = 1.8
    parts.append(shapes.box((S, S, 0.06), (0, 0, -0.02), mat="iron_dark", bevel=0.01))
    for i in range(7):
        for j in range(7):
            x = -S / 2 + 0.15 + i * (S - 0.3) / 6
            y = -S / 2 + 0.15 + j * (S - 0.3) / 6
            parts.append(shapes.cylinder(0.055, 0.03, (x, y, 0.015), segments=8, mat="void_black"))
            parts.append(shapes.cone(0.035, 0.32, (x, y, 0.0), seg=6, mat="iron_dark"))
    return finish(parts, "spike_trap", 71, ao_dist=0.1)


def build_lever():
    base_parts = []
    base_parts.append(shapes.stone((0.5, 0.4, 0.5), (0, 0, 0.25), seed=3, mat="stone_trim", bevel=0.04, cuts=1))
    base_parts.append(shapes.box((0.34, 0.26, 0.04), (0, 0, 0.52), mat="iron_dark", bevel=0.01))
    # Iron fulcrum bracket with side ears holding the pivot pin
    for sx in (-0.055, 0.055):
        base_parts.append(shapes.box((0.025, 0.20, 0.12), (sx, 0, 0.58), mat="iron_dark", bevel=0.006))
    base_parts.append(shapes.cylinder(0.018, 0.14, (0, 0, 0.58), segments=10, mat="iron_dark", rot=(0, math.pi / 2, 0)))
    base_ob = finish(base_parts, "lever", 72, ao_dist=0.15, ground=0.3)

    # Separate iron lever arm + grip pivoted cleanly at the fulcrum (0, 0, 0.58)
    pivot = Vector((0, 0, 0.58))
    handle_parts = []
    arm = shapes.cylinder(0.022, 0.75, (0, 0, 0.0), segments=8, mat="iron_dark")
    _xf(arm, (0, -0.15, 0.90), (math.radians(-25), 0, 0))
    handle_parts.append(arm)
    grip = shapes.cylinder(0.035, 0.16, (0, 0, 0.0), segments=10, mat="leather_dark")
    _xf(grip, (0, -0.30, 1.22), (math.radians(-25), 0, 0))
    handle_parts.append(grip)
    handle_parts.append(shapes.sphere(0.045, (0, -0.34, 1.31), seg=10, rings=6, mat="iron_dark"))
    handle_ob = core.join(handle_parts, "Handle")
    core.finalize(handle_ob, smooth_angle=40, uv="box", seed=73, weathering=0.6)
    shapes.bake_vertex_ao(handle_ob, rays=10, dist=0.12)
    handle_ob.data.transform(Matrix.Translation(-pivot))
    handle_ob.location = pivot
    handle_ob.parent = base_ob
    return base_ob


def build_rubble_pile():
    from build_environment import _rubble_pile
    parts = _rubble_pile(91, (0, 0, 0), count=22, spread=1.2, max_size=0.36)
    return finish(parts, "rubble_pile", 91, ao_dist=0.25)


def build_bone_pile():
    rnd = random.Random(92)
    parts = []
    for i in range(14):
        b = make_bone(i, length=rnd.uniform(0.25, 0.45))
        _xf(b, (rnd.gauss(0, 0.22), rnd.gauss(0, 0.2), 0.03 + i * 0.006), (math.pi / 2 + rnd.uniform(-0.2, 0.2), 0, rnd.uniform(0, math.tau)))
        parts.append(b)
    for i in range(3):
        sk = make_skull(i)
        _xf(sk, (rnd.uniform(-0.25, 0.25), rnd.uniform(-0.2, 0.2), 0.02 + rnd.uniform(0, 0.05)),
            (rnd.uniform(-0.4, 0.3), rnd.uniform(-0.3, 0.3), rnd.uniform(0, math.tau)))
        parts.append(sk)
    return finish(parts, "bone_pile", 92, ao_dist=0.15)


def build_sarcophagus():
    rnd = random.Random(93)
    parts = []
    L, Wd, Hs = 2.3, 1.0, 0.8
    parts.append(shapes.stone((L, Wd, Hs - 0.15), (0, 0, (Hs - 0.15) / 2 + 0.08), seed=1, mat="stone_trim", bevel=0.04, cuts=2))
    parts.append(shapes.stone((L + 0.14, Wd + 0.14, 0.12), (0, 0, 0.06), seed=2, mat="stone_trim", bevel=0.03))
    lid = shapes.stone((L + 0.08, Wd + 0.08, 0.16), (0.04, 0.02, Hs - 0.05), seed=3, mat="stone_trim", bevel=0.05, cuts=2,
                       rot=(0, 0, 0.03))
    parts.append(lid)
    # carved effigy: crossed sword relief + shield on the lid
    parts.append(shapes.box((1.5, 0.08, 0.04), (0.05, 0.02, Hs + 0.05), mat="stone_trim", bevel=0.015))
    parts.append(shapes.box((0.06, 0.4, 0.04), (-0.45, 0.02, Hs + 0.05), mat="stone_trim", bevel=0.015))
    sh = shapes.cylinder(0.24, 0.05, (0.35, 0.02, Hs + 0.06), segments=24, mat="stone_trim", bevel=0.01)
    parts.append(sh)
    # carved knot panels on the side
    for sx in (-0.7, 0.0, 0.7):
        parts.append(shapes.torus(0.16, 0.025, (sx, -Wd / 2 - 0.01, 0.45), mat="stone_trim", rot=(math.pi / 2, 0, 0), scale=(1, 1, 0.8)))
    return finish(parts, "sarcophagus", 93, ao_dist=0.3, ground=0.6)


def build_weapon_rack():
    parts = []
    for sx in (-1, 1):
        parts.append(shapes.plank(1.6, 0.1, 0.1, (sx * 0.7, 0, 0.8), (0, math.pi / 2, 0), seed=sx, mat="wood_beam"))
        parts.append(shapes.plank(0.6, 0.12, 0.1, (sx * 0.7, 0, 0.05), (0, 0, math.pi / 2), seed=sx + 4, mat="wood_beam"))
    for z in (0.35, 1.35):
        parts.append(shapes.plank(1.55, 0.08, 0.06, (0, 0, z), (0, 0, 0), seed=int(z * 10), mat="wood_oak"))
    rnd = random.Random(3)
    for i in range(4):
        x = -0.45 + i * 0.3
        blade = shapes.prism_from_outline([(0.0, 0.0), (0.03, 0.05), (0.028, 0.75), (0.0, 0.85), (-0.028, 0.75), (-0.03, 0.05)],
                                          0.008, mat="steel_blade")
        _xf(blade, (x, 0.03, 0.42), (0, rnd.uniform(-0.05, 0.05), 0))
        parts.append(blade)
        parts.append(shapes.box((0.2, 0.03, 0.03), (x, 0.03, 0.42), mat="iron_dark", bevel=0.005))
        parts.append(shapes.cylinder(0.018, 0.18, (x, 0.03, 0.32), segments=8, mat="leather_dark"))
    return finish(parts, "weapon_rack", 94, ao_dist=0.2)


def build_table():
    parts = []
    for k in range(5):
        parts.append(shapes.plank(2.0, 0.19, 0.06, (0, -0.38 + k * 0.19, 0.82), (0, 0, 0), seed=k, mat="wood_oak"))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(shapes.plank(0.8, 0.1, 0.1, (sx * 0.85, sy * 0.35, 0.4), (0, math.pi / 2, 0), seed=sx * 2 + sy, mat="wood_beam"))
        parts.append(shapes.plank(0.75, 0.08, 0.06, (sx * 0.85, 0, 0.18), (0, 0, math.pi / 2), seed=sx + 9, mat="wood_beam"))
    parts.append(shapes.plank(1.7, 0.08, 0.06, (0, 0, 0.18), (0, 0, 0), seed=11, mat="wood_beam"))
    # tankard, plate and candle
    tank = shapes.lathe([(0.0, 0.0), (0.05, 0.0), (0.055, 0.14), (0.05, 0.15), (0.0, 0.15)], 14, "Tankard", "wood_dark")
    _xf(tank, (0.4, 0.1, 0.85))
    parts.append(tank)
    parts.append(shapes.torus(0.035, 0.01, (0.46, 0.1, 0.92), mat="iron_dark", rot=(math.pi / 2, 0, 0)))
    parts.append(shapes.cylinder(0.14, 0.015, (-0.3, -0.05, 0.86), segments=20, mat="iron_dark"))
    c = make_candle(5, 0.18)
    _xf(c, (-0.7, 0.2, 0.85))
    parts.append(c)
    return finish(parts, "table", 95, ao_dist=0.25, ground=0.3)


def build_staircase_down():
    from build_environment import masonry_wall
    rnd = random.Random(515)
    parts = []
    # floor ring around the opening (regular floor tile is skipped here)
    for (cx, cy, sx, sy) in [(-1.6, 0.0, 0.8, 4.0), (1.6, 0.0, 0.8, 4.0), (0.0, 1.6, 2.4, 0.8)]:
        parts.append(shapes.stone((sx - 0.03, sy - 0.03, 0.16), (cx, cy, -0.08), seed=rnd.randrange(1 << 20), mat="stone_floor",
                                  bevel=0.02, cuts=2))
    # steps descending away from the entry side (-Y) toward +Y
    for i in range(10):
        parts.append(shapes.stone((2.36, 0.42, 0.26), (0, -1.75 + i * 0.32, -0.13 - i * 0.26), seed=rnd.randrange(1 << 20),
                                  mat="stone_trim", bevel=0.03, cuts=1))
    # shaft walls
    for sx in (-1, 1):
        ws = masonry_wall(600 + sx, x0=-2.0, x1=1.25, z0=-3.4, z1=0.0, base=False, cornice=False, face_y=-0.0)
        for o in ws:
            o.matrix_world = Matrix.Translation((sx * 1.2, 0, 0)) @ Matrix.Rotation(-sx * math.pi / 2, 4, "Z") @ o.matrix_world
            bpy.context.view_layer.update()
            core.apply_transform(o)
        parts += ws
    bw = masonry_wall(620, x0=-1.2, x1=1.2, z0=-3.4, z1=0.0, base=False, cornice=False, face_y=0.0)
    for o in bw:
        o.matrix_world = Matrix.Translation((0, 1.22, 0)) @ Matrix.Rotation(math.pi, 4, "Z") @ o.matrix_world
        bpy.context.view_layer.update()
        core.apply_transform(o)
    parts += bw
    # balustrade around three sides
    for (x0, y0, x1, y1) in [(-1.3, -1.95, -1.3, 1.3), (1.3, -1.95, 1.3, 1.3), (-1.3, 1.3, 1.3, 1.3)]:
        length = math.hypot(x1 - x0, y1 - y0)
        ang = math.atan2(y1 - y0, x1 - x0)
        rail = shapes.stone((length + 0.24, 0.3, 0.14), (0, 0, 0), seed=int(length * 100), mat="stone_trim", bevel=0.04)
        _xf(rail, ((x0 + x1) / 2, (y0 + y1) / 2, 0.92), (0, 0, ang))
        parts.append(rail)
        nbal = max(2, int(length / 0.4))
        for i in range(nbal + 1):
            t = i / nbal
            bal = shapes.lathe([(0.1, 0.0), (0.1, 0.08), (0.06, 0.14), (0.085, 0.42), (0.05, 0.7), (0.09, 0.76), (0.09, 0.85)],
                               12, "Baluster", "stone_trim")
            _xf(bal, (x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, 0.0))
            parts.append(bal)
    parts.append(shapes.box((2.4, 3.4, 0.05), (0, 0.2, -3.0), mat="void_black", name="Abyss"))
    return finish(parts, "staircase_down", 515, ao_dist=0.6)


PROPS = {
    "torch_sconce": build_torch_sconce,
    "brazier": build_brazier,
    "candle_cluster": build_candle_cluster,
    "chest": build_chest,
    "crate": build_crate,
    "barrel": build_barrel,
    "urn": build_urn,
    "wall_banner": build_wall_banner,
    "sanctuary_rug": build_rug,
    "boss_dais": build_boss_dais,
    "safe_beacon": build_safe_beacon,
    "merchant_stall": build_merchant_stall,
    "quest_board": build_quest_board,
    "boss_gate": build_boss_gate,
    "vault_gate": build_vault_gate,
    "spike_trap": build_spike_trap,
    "lever": build_lever,
    "rubble_pile": build_rubble_pile,
    "bone_pile": build_bone_pile,
    "sarcophagus": build_sarcophagus,
    "weapon_rack": build_weapon_rack,
    "table": build_table,
    "staircase_down": build_staircase_down,
}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = set()
    for i, a in enumerate(argv):
        if a == "--only":
            only = set(argv[i + 1].split(","))
    core.reset_scene()
    built = []
    for name, fn in PROPS.items():
        if only and name not in only:
            continue
        ob = fn()
        core.export_glb(ob, f"props/{name}", "props")
        built.append(ob)
    core.write_manifest()
    if "--preview" in argv and built:
        for o in built:
            o.hide_render = True
        rows = [built[i:i + 6] for i in range(0, len(built), 6)]
        y = 0.0
        for r in rows:
            vis = []
            for o in r:
                c = o.copy()
                c.data = o.data
                core.link(c)
                c.hide_render = False
                for ch in o.children:
                    cc = ch.copy()
                    core.link(cc)
                    cc.parent = c
                vis.append(c)
            render.layout_row(vis, gap=0.5, y=y)
            y += 3.6
        render.render_sheet([o for o in bpy.data.objects if o.type == "MESH" and not o.hide_render and o.name != "PreviewFloor"],
                            "batch1_props", cam_dist=0.85, elev=0.55, lens=35, samples=48, target_z_frac=0.2, yaw=0.0)


if __name__ == "__main__":
    main()
