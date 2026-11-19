"""Core Blender helpers: scene, mesh assembly, UVs, vertex-colour weathering, shading, export.

Every asset is assembled from many small generated parts, then *joined into a single mesh*
per exported piece (one draw call per material in Godot, MultiMesh friendly), box-UV-mapped in
world metres using the per-material tile size from game/data/materials.json, weathered with
vertex-colour cavity dirt + per-part tint variation, and exported as .glb with material NAMES
only (Godot swaps in the shared high-res material library at runtime).
"""

from __future__ import annotations

import json
import math
import pathlib
import random

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

REPO = pathlib.Path(__file__).resolve().parents[3]
GAME = REPO / "game"
MODELS = GAME / "assets" / "models"
TEXTURES = GAME / "assets" / "textures"
PREVIEWS = REPO / "art" / "previews"
ICONS = GAME / "assets" / "icons"
MATERIALS_JSON = GAME / "data" / "materials.json"
MANIFEST = REPO / "art" / "manifest.json"

_MAT_DEFS: dict | None = None


def mat_defs() -> dict:
    global _MAT_DEFS
    if _MAT_DEFS is None:
        _MAT_DEFS = json.loads(MATERIALS_JSON.read_text())["materials"]
    return _MAT_DEFS


# ---------------------------------------------------------------------------
# Scene
# ---------------------------------------------------------------------------

def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.unit_settings.system = "METRIC"
    sc.render.fps = 30


def link(obj: bpy.types.Object) -> bpy.types.Object:
    if obj.name not in bpy.context.scene.collection.objects:
        bpy.context.scene.collection.objects.link(obj)
    return obj


def select_only(obj: bpy.types.Object) -> None:
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def delete(objs) -> None:
    for o in list(objs):
        if o is None:
            continue
        me = o.data if o.type == "MESH" else None
        bpy.data.objects.remove(o, do_unlink=True)
        if me is not None and me.users == 0:
            bpy.data.meshes.remove(me)


# ---------------------------------------------------------------------------
# Mesh construction
# ---------------------------------------------------------------------------

def obj_from_bmesh(bm: bmesh.types.BMesh, name: str, material: str | None = None) -> bpy.types.Object:
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    link(ob)
    if material:
        set_material(ob, material)
    init_color(ob)
    return ob


def init_color(ob, value=1.0):
    me = ob.data
    if "Col" not in me.color_attributes:
        me.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
        col = me.color_attributes["Col"]
        for d in col.data:
            d.color = (value, value, value, 1.0)
    me.color_attributes.active_color = me.color_attributes["Col"]


def set_material(ob: bpy.types.Object, mat_name: str) -> None:
    from . import materials
    m = materials.get(mat_name)
    ob.data.materials.clear()
    ob.data.materials.append(m)
    for p in ob.data.polygons:
        p.material_index = 0


def apply_transform(ob: bpy.types.Object) -> None:
    me = ob.data
    me.transform(ob.matrix_world)
    ob.matrix_world = Matrix.Identity(4)


def place(ob, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1), apply=True):
    ob.location = Vector(loc)
    ob.rotation_euler = rot
    ob.scale = scale
    if apply:
        bpy.context.view_layer.update()
        apply_transform(ob)
    return ob


def apply_modifiers(ob: bpy.types.Object) -> None:
    select_only(ob)
    for m in list(ob.modifiers):
        try:
            bpy.ops.object.modifier_apply(modifier=m.name)
        except RuntimeError:
            ob.modifiers.remove(m)


def add_bevel(ob, width=0.02, segments=2, angle=40.0, harden=False, profile=0.6):
    m = ob.modifiers.new("Bevel", "BEVEL")
    m.width = width
    m.segments = segments
    m.limit_method = "ANGLE"
    m.angle_limit = math.radians(angle)
    m.profile = profile
    m.harden_normals = harden
    m.use_clamp_overlap = True
    return m


def add_subsurf(ob, levels=1):
    m = ob.modifiers.new("Subsurf", "SUBSURF")
    m.levels = levels
    m.render_levels = levels
    return m


def add_solidify(ob, thickness=0.01, offset=0.0):
    m = ob.modifiers.new("Solidify", "SOLIDIFY")
    m.thickness = thickness
    m.offset = offset
    return m


def join(objs, name: str) -> bpy.types.Object:
    objs = [o for o in objs if o is not None]
    for o in objs:
        if o.modifiers:
            apply_modifiers(o)
        if o.type == "MESH":
            init_color(o)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    ob.data.name = name
    return ob


def displace_noise(ob, amp=0.02, freq=2.0, seed=0, along_normal=True, mask=None):
    """Organic irregularity: offset verts by 3D Perlin noise (deterministic via seed offset)."""
    me = ob.data
    off = Vector((seed * 17.31, seed * 5.77, seed * 11.13))
    me.update()
    for v in me.vertices:
        p = v.co * freq + off
        if mask is not None and not mask(v.co):
            continue
        if along_normal:
            v.co += v.normal * noise.noise(p) * amp
        else:
            v.co += Vector(noise.noise_vector(p)) * amp
    me.update()


def shade_smooth(ob, angle_deg: float = 40.0) -> None:
    me = ob.data
    for p in me.polygons:
        p.use_smooth = True
    try:
        me.set_sharp_from_angle(angle=math.radians(angle_deg))
    except Exception:
        pass


def tris(ob) -> int:
    me = ob.data
    me.calc_loop_triangles()
    return len(me.loop_triangles)


def dims(ob):
    bpy.context.view_layer.update()
    xs = [v.co.x for v in ob.data.vertices]
    ys = [v.co.y for v in ob.data.vertices]
    zs = [v.co.z for v in ob.data.vertices]
    return (max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)), (min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs))


# ---------------------------------------------------------------------------
# UVs (world-metre box projection, per-material tile size)
# ---------------------------------------------------------------------------

def uv_box(ob, seed: int = 0, keep_unit: bool = True, rotate_random: bool = False) -> None:
    """Box-project every face; UV = metres / tile_m(material). Faces whose material uses
    authored 'unit' UVs keep their existing coordinates."""
    me = ob.data
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    uvl = me.uv_layers.active.data
    defs = mat_defs()
    rnd = random.Random(seed)
    offs = (rnd.random() * 7.0, rnd.random() * 7.0)
    tile_by_index = []
    unit_by_index = []
    for m in me.materials:
        d = defs.get(m.name if m else "", {})
        tile_by_index.append(float(d.get("tile_m", 1.0)))
        unit_by_index.append(d.get("uv", "box") == "unit")
    lock = me.attributes.get("uv_lock")
    for p in me.polygons:
        if keep_unit and unit_by_index and unit_by_index[p.material_index]:
            continue
        if lock is not None and lock.data[p.index].value:
            continue
        tile = tile_by_index[p.material_index] if tile_by_index else 1.0
        n = p.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for li in p.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            if ax == 2:
                u, v = co.x * (1 if n.z >= 0 else -1), co.y
            elif ax == 0:
                u, v = co.y * (1 if n.x >= 0 else -1), co.z
            else:
                u, v = co.x * (-1 if n.y >= 0 else 1), co.z
            uvl[li].uv = (u / tile + offs[0], v / tile + offs[1])


def uv_cylinder(ob, axis="z", seed: int = 0) -> None:
    """Cylindrical projection around the given axis (for lathe objects); caps use planar."""
    me = ob.data
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    uvl = me.uv_layers.active.data
    defs = mat_defs()
    tiles = [float(defs.get(m.name if m else "", {}).get("tile_m", 1.0)) for m in me.materials] or [1.0]
    rnd = random.Random(seed)
    o = rnd.random() * 3.0
    lock = me.attributes.get("uv_lock")
    for p in me.polygons:
        if lock is not None and lock.data[p.index].value:
            continue
        tile = tiles[p.material_index]
        n = p.normal
        cap = abs(n.z) > 0.8
        # use face centre angle to keep faces from wrapping across the seam
        c = p.center
        ang_c = math.atan2(c.y, c.x)
        for li in p.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            if cap:
                uvl[li].uv = (co.x / tile + o, co.y / tile + o)
            else:
                ang = math.atan2(co.y, co.x)
                if ang - ang_c > math.pi:
                    ang -= 2 * math.pi
                elif ang_c - ang > math.pi:
                    ang += 2 * math.pi
                r = max(0.05, math.hypot(co.x, co.y))
                uvl[li].uv = (ang * max(r, 0.15) / tile + o, co.z / tile)


def set_unit_uvs(ob, mapping) -> None:
    """mapping(co) -> (u, v) for authored 0..1 UVs (banners, parchment, rugs)."""
    me = ob.data
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    uvl = me.uv_layers.active.data
    for p in me.polygons:
        for li in p.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            uvl[li].uv = mapping(co)


# ---------------------------------------------------------------------------
# Vertex colours: per-part tint variation x cavity dirt
# ---------------------------------------------------------------------------

def ensure_color_layer(ob, name="Col"):
    me = ob.data
    if name not in me.color_attributes:
        init_color(ob)
    me.color_attributes.active_color = me.color_attributes[name]
    try:
        me.color_attributes.render_color_index = me.color_attributes.find(name)
    except Exception:
        pass
    return me.color_attributes[name]


def tint_part(ob, value: float, hue: tuple[float, float, float] = (1.0, 1.0, 1.0)) -> None:
    """Fill an (unjoined) part's vertex colours with a brightness/tint factor."""
    col = ensure_color_layer(ob)
    c = (min(1.0, value * hue[0]), min(1.0, value * hue[1]), min(1.0, value * hue[2]), 1.0)
    for d in col.data:
        d.color = c


def weather(ob, strength: float = 1.0, ground_dirt: float = 0.0, ground_h: float = 0.6, seed: int = 0) -> None:
    """Multiply existing per-part tint by curvature dirt (computed from vertex normals vs neighbours)
    and optional ground-level grime. Produces darker crevices/joints and lighter worn edges."""
    me = ob.data
    col = ensure_color_layer(ob)
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    # concavity per vertex: average dot of edge vectors with vertex normal
    conc = [0.0] * len(bm.verts)
    for v in bm.verts:
        if not v.link_edges:
            continue
        acc = 0.0
        for e in v.link_edges:
            o = e.other_vert(v)
            d = (o.co - v.co)
            ln = d.length
            if ln < 1e-6:
                continue
            acc += d.normalized().dot(v.normal)
        conc[v.index] = acc / len(v.link_edges)  # >0 concave (neighbours above), <0 convex edge
    bm.free()
    off = Vector((seed * 3.1, seed * 7.7, seed * 1.3))
    for p in me.polygons:
        for li in p.loop_indices:
            vi = me.loops[li].vertex_index
            co = me.vertices[vi].co
            c = conc[vi]
            dirt = max(0.0, min(1.0, c * 2.2)) * 0.55 * strength
            edge = max(0.0, min(1.0, -c * 2.0)) * 0.18 * strength
            k = (1.0 - dirt) * (1.0 + edge)
            if ground_dirt > 0.0:
                g = max(0.0, 1.0 - co.z / ground_h) * ground_dirt
                g *= 0.7 + 0.3 * noise.noise(co * 3.0 + off)
                k *= 1.0 - g * 0.45
            blot = 1.0 + 0.06 * noise.noise(co * 1.7 + off)
            k *= blot
            r, g_, b, a = col.data[li].color
            col.data[li].color = (max(0.0, min(1.0, r * k)), max(0.0, min(1.0, g_ * k)), max(0.0, min(1.0, b * k)), 1.0)


# ---------------------------------------------------------------------------
# Finishing + export
# ---------------------------------------------------------------------------

def finalize(ob, smooth_angle=40.0, uv="box", seed=0, weathering=1.0, ground_dirt=0.0, ground_h=0.6):
    if ob.modifiers:
        apply_modifiers(ob)
    shade_smooth(ob, smooth_angle)
    if uv == "box":
        uv_box(ob, seed)
    elif uv == "cyl":
        uv_cylinder(ob, seed=seed)
    ensure_color_layer(ob)
    if weathering > 0 or ground_dirt > 0:
        weather(ob, weathering, ground_dirt, ground_h, seed)
    return ob


def triangulate_ngons(ob) -> None:
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    ngons = [f for f in bm.faces if len(f.verts) > 4]
    if ngons:
        bmesh.ops.triangulate(bm, faces=ngons)
        bm.to_mesh(ob.data)
    bm.free()


_manifest_entries: list[dict] = []


def export_glb(ob_or_objs, rel_path: str, batch: str, extra: dict | None = None, animations: bool = False) -> dict:
    """Export selection to game/assets/models/<rel_path>.glb and record manifest metadata."""
    objs = ob_or_objs if isinstance(ob_or_objs, (list, tuple)) else [ob_or_objs]
    for o in objs + [c for o in objs for c in o.children_recursive]:
        if o.type == "MESH":
            triangulate_ngons(o)
    out = MODELS / f"{rel_path}.glb"
    out.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
        for c in o.children_recursive:
            c.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(
        filepath=str(out),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_image_format="NONE",
        export_materials="EXPORT",
        export_vertex_color="ACTIVE",
        export_all_vertex_colors=False,
        export_normals=True,
        export_tangents=True,
        export_animations=animations,
        export_animation_mode="ACTIONS",
        export_skins=True,
        export_def_bones=False,
        export_leaf_bone=False,
        export_optimize_animation_size=True,
        export_force_sampling=True,
    )
    meshes = [o for o in objs if o.type == "MESH"] + [c for o in objs for c in o.children_recursive if c.type == "MESH"]
    tri = sum(tris(m) for m in meshes)
    xs, ys, zs = [], [], []
    for m in meshes:
        for v in m.data.vertices:
            w = m.matrix_world @ v.co
            xs.append(w.x)
            ys.append(w.y)
            zs.append(w.z)
    entry = {
        "batch": batch,
        "name": pathlib.Path(rel_path).name,
        "path": f"game/assets/models/{rel_path}.glb",
        "dimensions_xyz_m": [round(max(xs) - min(xs), 3), round(max(ys) - min(ys), 3), round(max(zs) - min(zs), 3)],
        "triangles": tri,
        "bytes": out.stat().st_size,
        "materials": sorted({ms.name for m in meshes for ms in m.data.materials if ms}),
    }
    if extra:
        entry.update(extra)
    _manifest_entries.append(entry)
    print(f"[export] {rel_path:38s} tris={tri:6d}  {entry['dimensions_xyz_m']}  {entry['bytes'] // 1024}KB")
    return entry


def write_manifest(batch_prefix: str | None = None) -> None:
    """Merge this run's entries into art/manifest.json (replacing entries with the same path)."""
    data = {"assets": [], "previews": []}
    if MANIFEST.exists():
        data = json.loads(MANIFEST.read_text())
    by_path = {a["path"]: a for a in data.get("assets", [])}
    for e in _manifest_entries:
        by_path[e["path"]] = e
    data["assets"] = sorted(by_path.values(), key=lambda a: (a["batch"], a["name"]))
    MANIFEST.write_text(json.dumps(data, indent=2))


def add_preview(rel: str) -> None:
    data = {"assets": [], "previews": []}
    if MANIFEST.exists():
        data = json.loads(MANIFEST.read_text())
    prev = set(data.get("previews", []))
    prev.add(rel)
    data["previews"] = sorted(prev)
    MANIFEST.write_text(json.dumps(data, indent=2))
