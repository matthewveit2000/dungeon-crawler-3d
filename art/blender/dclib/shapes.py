"""Procedural modelling generators used across the kit, props, gear and characters.

All functions return a linked bpy Object (mesh) with the requested material assigned.
Organic irregularity comes from deterministic Perlin displacement (seeded offsets).
"""

from __future__ import annotations

import math
import random

import bmesh
import bpy
from mathutils import Matrix, Vector, noise
from mathutils.bvhtree import BVHTree

from .core import (add_bevel, add_solidify, add_subsurf, apply_modifiers, apply_transform, link,
                   obj_from_bmesh, set_material, tint_part)


# ---------------------------------------------------------------------------
# Primitives
# ---------------------------------------------------------------------------

def box(size, loc=(0, 0, 0), mat="stone_block", name="Box", bevel=0.0, seg=2, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    ob = obj_from_bmesh(bm, name, mat)
    if bevel > 0:
        add_bevel(ob, bevel, seg, 30)
        apply_modifiers(ob)
    ob.rotation_euler = rot
    ob.location = loc
    bpy.context.view_layer.update()
    apply_transform(ob)
    return ob


def grid_box(size, cuts=2, name="GBox", mat="stone_block"):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    if cuts > 0:
        bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=cuts, use_grid_fill=True)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    return obj_from_bmesh(bm, name, mat)


def stone(size, loc=(0, 0, 0), seed=0, mat="stone_block", bevel=0.035, irregular=0.018, freq=2.2,
          chip=0.45, cuts=2, rot=(0, 0, 0), tint=None, name="Stone", bevel_segments=2):
    """Hand-cut stone block: beveled, softly lumpy faces, chipped corners, random tint."""
    rnd = random.Random(seed)
    sx, sy, sz = size
    ob = grid_box((sx, sy, sz), cuts=cuts, name=name, mat=mat)
    me = ob.data
    # chip a few corners
    corners = [Vector((cx * sx / 2, cy * sy / 2, cz * sz / 2)) for cx in (-1, 1) for cy in (-1, 1) for cz in (-1, 1)]
    chipped = [c for c in corners if rnd.random() < chip]
    cr = min(sx, sy, sz) * 0.45
    for v in me.vertices:
        for c in chipped:
            d = (v.co - c).length
            if d < cr:
                k = (1.0 - d / cr) ** 2 * 0.35 * cr
                v.co += (-c.normalized()) * k
    add_bevel(ob, bevel, bevel_segments, 30, profile=0.55)
    apply_modifiers(ob)
    me.update()
    off = Vector((seed * 1.37, seed * 2.11, seed * 0.73))
    for v in me.vertices:
        p = Vector((v.co.x * freq, v.co.y * freq, v.co.z * freq)) + off
        n = noise.noise(p) + 0.45 * noise.noise(p * 2.7)
        v.co += v.normal * n * irregular
    me.update()
    ob.rotation_euler = rot
    ob.location = loc
    bpy.context.view_layer.update()
    apply_transform(ob)
    warm = rnd.uniform(-0.05, 0.06)
    val = rnd.uniform(0.80, 1.08) if tint is None else tint
    tint_part(ob, val, (1.0 + warm, 1.0, 1.0 - warm * 1.2))
    return ob


def lathe(profile, segments=24, name="Lathe", mat="iron_dark", loc=(0, 0, 0), cap_bottom=True, cap_top=True,
          smooth_profile=False):
    """Revolve a list of (radius, z) points around Z. Radii of 0 collapse to the axis."""
    bm = bmesh.new()
    rings = []
    for (r, z) in profile:
        ring = []
        for i in range(segments):
            a = 2 * math.pi * i / segments
            ring.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, z)))
        rings.append(ring)
    for k in range(len(rings) - 1):
        a, b = rings[k], rings[k + 1]
        for i in range(segments):
            j = (i + 1) % segments
            try:
                bm.faces.new((a[i], a[j], b[j], b[i]))
            except ValueError:
                pass
    if cap_bottom and profile[0][0] > 1e-4:
        bm.faces.new(list(reversed(rings[0])))
    if cap_top and profile[-1][0] > 1e-4:
        bm.faces.new(rings[-1])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = obj_from_bmesh(bm, name, mat)
    ob.location = loc
    bpy.context.view_layer.update()
    apply_transform(ob)
    return ob


def cylinder(r, h, loc=(0, 0, 0), segments=16, mat="iron_dark", name="Cyl", rot=(0, 0, 0), bevel=0.0, r_top=None):
    rt = r if r_top is None else r_top
    ob = lathe([(r, -h / 2), (rt, h / 2)], segments, name, mat)
    if bevel > 0:
        add_bevel(ob, bevel, 2, 40)
        apply_modifiers(ob)
    ob.rotation_euler = rot
    ob.location = loc
    bpy.context.view_layer.update()
    apply_transform(ob)
    return ob


def sphere(r, loc=(0, 0, 0), seg=16, rings=10, mat="iron_dark", name="Sphere", scale=(1, 1, 1)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=r)
    ob = obj_from_bmesh(bm, name, mat)
    ob.scale = scale
    ob.location = loc
    bpy.context.view_layer.update()
    apply_transform(ob)
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def cone(r, h, loc=(0, 0, 0), seg=12, mat="iron_dark", name="Cone", rot=(0, 0, 0), r_top=0.0):
    ob = lathe([(r, 0.0), (max(r_top, 0.0005), h)], seg, name, mat, cap_top=r_top > 0)
    ob.rotation_euler = rot
    ob.location = loc
    bpy.context.view_layer.update()
    apply_transform(ob)
    return ob


def torus(R, r, loc=(0, 0, 0), major=32, minor=10, mat="iron_dark", name="Torus", rot=(0, 0, 0), scale=(1, 1, 1)):
    bm = bmesh.new()
    verts = []
    for i in range(major):
        a = 2 * math.pi * i / major
        ring = []
        for j in range(minor):
            b = 2 * math.pi * j / minor
            x = (R + r * math.cos(b)) * math.cos(a)
            y = (R + r * math.cos(b)) * math.sin(a)
            z = r * math.sin(b)
            ring.append(bm.verts.new((x, y, z)))
        verts.append(ring)
    for i in range(major):
        for j in range(minor):
            a = verts[i][j]
            b = verts[(i + 1) % major][j]
            c = verts[(i + 1) % major][(j + 1) % minor]
            d = verts[i][(j + 1) % minor]
            bm.faces.new((a, b, c, d))
    ob = obj_from_bmesh(bm, name, mat)
    ob.scale = scale
    ob.rotation_euler = rot
    ob.location = loc
    bpy.context.view_layer.update()
    apply_transform(ob)
    return ob


def tube(points, radius=0.02, seg=8, mat="iron_dark", name="Tube", radii=None, closed=False, resolution=4,
         cap=True, bezier=True, twist=0.0):
    """Sweep a circle along a (smooth) path. radii: optional per-point radius multipliers (taper)."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.resolution_u = resolution
    cu.bevel_depth = radius
    cu.bevel_resolution = max(1, seg // 4)
    cu.use_fill_caps = cap
    if bezier:
        sp = cu.splines.new("BEZIER")
        sp.bezier_points.add(len(points) - 1)
        for i, p in enumerate(points):
            bp = sp.bezier_points[i]
            bp.co = Vector(p)
            bp.handle_left_type = "AUTO"
            bp.handle_right_type = "AUTO"
            bp.radius = radii[i] if radii else 1.0
            bp.tilt = twist * i
    else:
        sp = cu.splines.new("POLY")
        sp.points.add(len(points) - 1)
        for i, p in enumerate(points):
            sp.points[i].co = (*p, 1.0)
            sp.points[i].radius = radii[i] if radii else 1.0
    sp.use_cyclic_u = closed
    ob = bpy.data.objects.new(name, cu)
    link(ob)
    bpy.context.view_layer.objects.active = ob
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    ob.select_set(True)
    bpy.ops.object.convert(target="MESH")
    ob = bpy.context.view_layer.objects.active
    set_material(ob, mat)
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def prism_from_outline(outline, depth, name="Prism", mat="iron_dark", bevel=0.0, bevel_seg=2, axis="y"):
    """Extrude a closed 2D outline [(x, z), ...] along Y (thickness centred on 0)."""
    bm = bmesh.new()
    front = [bm.verts.new((x, -depth / 2, z)) for (x, z) in outline]
    back = [bm.verts.new((x, depth / 2, z)) for (x, z) in outline]
    n = len(outline)
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[i], back[i], back[j], front[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = obj_from_bmesh(bm, name, mat)
    if bevel > 0:
        add_bevel(ob, bevel, bevel_seg, 30)
        apply_modifiers(ob)
    return ob


def plank(length, width, thick, loc=(0, 0, 0), rot=(0, 0, 0), seed=0, mat="wood_oak", bevel=0.006, warp=0.004,
          name="Plank", tint=None, cuts=3):
    """Board along X with chamfered edges, slight warp and irregular ends."""
    rnd = random.Random(seed)
    ob = grid_box((length, width, thick), cuts=cuts, name=name, mat=mat)
    me = ob.data
    off = Vector((seed * 0.7, seed * 1.9, seed * 0.3))
    for v in me.vertices:
        t = v.co.x / max(length, 1e-3)
        v.co.z += math.sin(t * math.pi) * warp * (1 if rnd.random() < 0.5 else -1)
        v.co += Vector(noise.noise_vector(v.co * 3.0 + off)) * warp * 0.5
    add_bevel(ob, bevel, 1, 30)
    apply_modifiers(ob)
    lock_uvs_along_x(ob, seed)
    ob.rotation_euler = rot
    ob.location = loc
    bpy.context.view_layer.update()
    apply_transform(ob)
    tint_part(ob, rnd.uniform(0.82, 1.08) if tint is None else tint)
    return ob


def lock_uvs_along_x(ob, seed=0, axis="x"):
    """Authored UVs with the texture's U (wood grain) running along the part's long axis, then mark
    the faces 'uv_lock' so the global box projection keeps them (grain follows every board)."""
    from .core import mat_defs
    me = ob.data
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    uvl = me.uv_layers.active.data
    tile = 1.0
    if me.materials:
        tile = float(mat_defs().get(me.materials[0].name, {}).get("tile_m", 1.0))
    rnd = random.Random(seed)
    ou, ov = rnd.random() * 5.0, rnd.random() * 5.0
    for p in me.polygons:
        n = p.normal
        for li in p.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            if axis == "x":
                along, a, b = co.x, co.y, co.z
                nn = (abs(n.y), abs(n.z), abs(n.x))
            else:
                along, a, b = co.z, co.x, co.y
                nn = (abs(n.x), abs(n.y), abs(n.z))
            if nn[2] > 0.7:
                u, v = a, b
            elif nn[0] > nn[1]:
                u, v = along, b
            else:
                u, v = along, a
            uvl[li].uv = (u / tile + ou, v / tile + ov)
    attr = me.attributes.get("uv_lock") or me.attributes.new("uv_lock", "BOOLEAN", "FACE")
    for i in range(len(me.polygons)):
        attr.data[i].value = True


def wedge_stone(r_in, r_out, a0, a1, depth, seed=0, mat="stone_block", bevel=0.02, irregular=0.01, name="Voussoir"):
    """Arch voussoir between angles a0..a1 (radians, 0 = +X, pi/2 = +Z), centred on Y=0."""
    bm = bmesh.new()
    steps = 3
    inner_f, outer_f, inner_b, outer_b = [], [], [], []
    for k in range(steps + 1):
        a = a0 + (a1 - a0) * k / steps
        ca, sa = math.cos(a), math.sin(a)
        inner_f.append(bm.verts.new((ca * r_in, -depth / 2, sa * r_in)))
        outer_f.append(bm.verts.new((ca * r_out, -depth / 2, sa * r_out)))
        inner_b.append(bm.verts.new((ca * r_in, depth / 2, sa * r_in)))
        outer_b.append(bm.verts.new((ca * r_out, depth / 2, sa * r_out)))
    for k in range(steps):
        bm.faces.new((inner_f[k], inner_f[k + 1], outer_f[k + 1], outer_f[k]))
        bm.faces.new((inner_b[k + 1], inner_b[k], outer_b[k], outer_b[k + 1]))
        bm.faces.new((inner_f[k + 1], inner_f[k], inner_b[k], inner_b[k + 1]))
        bm.faces.new((outer_f[k], outer_f[k + 1], outer_b[k + 1], outer_b[k]))
    bm.faces.new((inner_f[0], outer_f[0], outer_b[0], inner_b[0]))
    bm.faces.new((outer_f[-1], inner_f[-1], inner_b[-1], outer_b[-1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = obj_from_bmesh(bm, name, mat)
    add_bevel(ob, bevel, 2, 30)
    apply_modifiers(ob)
    rnd = random.Random(seed)
    off = Vector((seed * 1.1, seed * 0.3, seed * 2.3))
    for v in ob.data.vertices:
        v.co += v.normal * noise.noise(v.co * 2.5 + off) * irregular
    ob.data.update()
    tint_part(ob, rnd.uniform(0.82, 1.06))
    return ob


def cloth_panel(width, height, cols=14, rows=20, folds=3, fold_amp=0.04, seed=0, mat="cloth_crimson",
                bottom="straight", name="Cloth", thickness=0.006, sway=0.0):
    """Hanging fabric in the XZ plane (top edge at z=0, hanging down -Z), with vertical folds.
    bottom: 'straight' | 'swallowtail' | 'points' | 'frayed'. UVs 0..1 across the panel."""
    rnd = random.Random(seed)
    bm = bmesh.new()
    grid = []
    for j in range(rows + 1):
        row = []
        t = j / rows
        for i in range(cols + 1):
            s = i / cols
            x = (s - 0.5) * width
            z = -t * height
            # bottom profile
            if bottom == "swallowtail":
                cut = abs(s - 0.5) * 2.0
                z = -t * (height - (1.0 - cut) * height * 0.18)
            elif bottom == "points":
                tooth = abs(((s * 3.0) % 1.0) - 0.5) * 2.0
                z = -t * (height - (1.0 - tooth) * height * 0.12)
            elif bottom == "frayed":
                z = -t * (height * (0.96 + 0.04 * noise.noise(Vector((s * 9.0, seed * 0.37, 0.0)))))
            amp = fold_amp * (0.35 + 0.65 * t)
            y = math.sin(s * math.pi * 2.0 * folds + rnd.random() * 0.0 + seed) * amp
            y += noise.noise(Vector((s * 4.0, t * 3.0, seed * 0.17))) * amp * 0.6
            y += sway * t * t
            row.append(bm.verts.new((x, y, z)))
        grid.append(row)
    uv_coords = {}
    for j in range(rows):
        for i in range(cols):
            f = bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
            uv_coords[f] = [(i / cols, 1 - j / rows), ((i + 1) / cols, 1 - j / rows),
                            ((i + 1) / cols, 1 - (j + 1) / rows), (i / cols, 1 - (j + 1) / rows)]
    uvl = bm.loops.layers.uv.new("UVMap")
    for f, uvs in uv_coords.items():
        for loop, uv in zip(f.loops, uvs):
            loop[uvl].uv = uv
    ob = obj_from_bmesh(bm, name, mat)
    for p in ob.data.polygons:
        p.use_smooth = True
    if thickness > 0:
        add_solidify(ob, thickness, 0.0)
        apply_modifiers(ob)
    return ob


def rivet_row(p0, p1, count, normal, r=0.012, mat="iron_dark", name="Rivets"):
    objs = []
    n = Vector(normal).normalized()
    rot = n.to_track_quat("Z", "Y").to_euler()
    for i in range(count):
        t = (i + 0.5) / count
        p = Vector(p0).lerp(Vector(p1), t)
        ob = sphere(r, seg=8, rings=5, mat=mat, name=name, scale=(1, 1, 0.55))
        ob.rotation_euler = rot
        ob.location = p
        bpy.context.view_layer.update()
        apply_transform(ob)
        objs.append(ob)
    return objs


def strap(points, width=0.04, thick=0.006, mat="iron_dark", name="Strap"):
    """Flat band following a path (e.g. iron band around a curved chest lid). points in order."""
    bm = bmesh.new()
    pts = [Vector(p) for p in points]
    vs = []
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        side = Vector((1, 0, 0)) if abs(d.x) < 0.9 else Vector((0, 1, 0))
        side = (side - d * side.dot(d)).normalized() * (width / 2)
        vs.append((bm.verts.new(p - side), bm.verts.new(p + side)))
    for i in range(len(vs) - 1):
        a0, a1 = vs[i]
        b0, b1 = vs[i + 1]
        bm.faces.new((a0, a1, b1, b0))
    ob = obj_from_bmesh(bm, name, mat)
    add_solidify(ob, thick, 0.0)
    apply_modifiers(ob)
    return ob


def chain(p0, p1, link_len=0.06, wire=0.008, mat="iron_dark", name="Chain", sag=0.0):
    """Interlocking oval links from p0 to p1 (with optional catenary sag)."""
    a, b = Vector(p0), Vector(p1)
    total = (b - a).length
    n = max(2, int(total / (link_len * 0.78)))
    objs = []
    for i in range(n):
        t0 = i / n
        t1 = (i + 1) / n
        q0 = a.lerp(b, t0)
        q1 = a.lerp(b, t1)
        q0.z -= sag * 4 * t0 * (1 - t0)
        q1.z -= sag * 4 * t1 * (1 - t1)
        mid = (q0 + q1) / 2
        d = (q1 - q0).normalized()
        ob = torus(link_len * 0.32, wire, mat=mat, major=12, minor=6, scale=(1.0, 1.6, 1.0), name=name)
        rot = d.to_track_quat("Y", "Z").to_matrix().to_4x4()
        twist = Matrix.Rotation(math.pi / 2 if i % 2 else 0.0, 4, "Y")
        ob.matrix_world = Matrix.Translation(mid) @ rot @ twist @ Matrix.Rotation(math.pi / 2, 4, "X")
        bpy.context.view_layer.update()
        apply_transform(ob)
        objs.append(ob)
    return objs


# ---------------------------------------------------------------------------
# Ambient occlusion baked into vertex colours (ray-cast hemisphere)
# ---------------------------------------------------------------------------

def bake_vertex_ao(ob, rays=20, dist=0.8, strength=0.85, bias=0.004, extra_occluders=None):
    """Multiply the 'Col' corner colours by true ray-cast hemisphere occlusion."""
    me = ob.data
    me.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    bvh = BVHTree.FromObject(ob, depsgraph)
    occ_trees = [bvh]
    for e in extra_occluders or []:
        occ_trees.append(BVHTree.FromObject(e, depsgraph))
    rnd = random.Random(7)
    dirs = []
    # cosine-weighted hemisphere samples around +Z (rotated per vertex normal)
    for i in range(rays):
        u1 = (i + 0.5) / rays
        u2 = rnd.random()
        r = math.sqrt(u1)
        th = 2 * math.pi * (u2 + i * 0.618)
        dirs.append(Vector((r * math.cos(th), r * math.sin(th), math.sqrt(max(0.0, 1 - u1)))))
    mw = ob.matrix_world
    occl = [1.0] * len(me.vertices)
    for v in me.vertices:
        n = v.normal
        if n.length < 0.5:
            continue
        q = n.to_track_quat("Z", "Y")
        origin = v.co + n * bias
        hits = 0
        for d in dirs:
            wd = q @ d
            for t in occ_trees:
                hit = t.ray_cast(origin, wd, dist)
                if hit[0] is not None:
                    hits += 1
                    break
        occl[v.index] = 1.0 - strength * hits / rays
    col = me.color_attributes.get("Col")
    if col is None:
        from .core import ensure_color_layer
        col = ensure_color_layer(ob)
    for p in me.polygons:
        for li in p.loop_indices:
            k = occl[me.loops[li].vertex_index]
            r, g, b, a = col.data[li].color
            col.data[li].color = (r * k, g * k, b * k, a)
