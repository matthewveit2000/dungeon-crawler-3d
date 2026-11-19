"""Shared Blender 4.5 LTS helpers for high-craft Clean Stylized Dark Fantasy assets,
seamless PBR textures + normal maps, box UV projection, glTF (.glb) exporting,
manifest recording, and dramatic studio Cycles preview renders.
"""

from __future__ import annotations

import math
import pathlib
import bmesh
import bpy
from mathutils import Vector

from textures import ensure_textures

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
MODELS_DIR = REPO_ROOT / "game" / "assets" / "models"
PREVIEWS_DIR = REPO_ROOT / "art" / "previews"
MANIFEST_PATH = REPO_ROOT / "art" / "manifest.json"

_TEX_PATHS: dict[str, dict[str, pathlib.Path]] = {}


def init_textures() -> None:
    global _TEX_PATHS
    if not _TEX_PATHS:
        _TEX_PATHS = ensure_textures(256)


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _load_img(path: pathlib.Path, non_color: bool = False) -> bpy.types.Image:
    img = bpy.data.images.load(str(path), check_existing=True)
    img.colorspace_settings.name = "Non-Color" if non_color else "sRGB"
    img.pack()
    return img


def make_material(
    name: str,
    color: tuple[float, float, float],
    metallic: float = 0.0,
    roughness: float = 0.72,
    emission: tuple[float, float, float] | None = None,
    emission_strength: float = 0.0,
    tex_set: str | None = None,
    tex_scale: float = 1.0,
    tint_mix: float = 0.28,
    normal_strength: float = 0.85,
) -> bpy.types.Material:
    mat = bpy.data.materials.get(name)
    if mat is not None:
        return mat
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness

    if tex_set is not None:
        init_textures()
        tinfo = _TEX_PATHS.get(tex_set)
        if tinfo is not None:
            tex_coord = nt.nodes.new("ShaderNodeTexCoord")
            mapping = nt.nodes.new("ShaderNodeMapping")
            mapping.inputs["Scale"].default_value = (tex_scale, tex_scale, tex_scale)
            nt.links.new(tex_coord.outputs["UV"], mapping.inputs["Vector"])

            # Albedo image tinted gently with material color for palette cohesion
            alb_node = nt.nodes.new("ShaderNodeTexImage")
            alb_node.image = _load_img(tinfo["albedo"], non_color=False)
            nt.links.new(mapping.outputs["Vector"], alb_node.inputs["Vector"])

            if tint_mix > 0.01:
                mix = nt.nodes.new("ShaderNodeMix")
                mix.data_type = "RGBA"
                mix.blend_type = "MIX"
                mix.inputs["Factor"].default_value = tint_mix
                mix.inputs["B"].default_value = (*color, 1.0)
                nt.links.new(alb_node.outputs["Color"], mix.inputs["A"])
                nt.links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
            else:
                nt.links.new(alb_node.outputs["Color"], bsdf.inputs["Base Color"])

            # Roughness map
            rough_node = nt.nodes.new("ShaderNodeTexImage")
            rough_node.image = _load_img(tinfo["roughness"], non_color=True)
            nt.links.new(mapping.outputs["Vector"], rough_node.inputs["Vector"])
            nt.links.new(rough_node.outputs["Color"], bsdf.inputs["Roughness"])

            # Normal map
            norm_tex = nt.nodes.new("ShaderNodeTexImage")
            norm_tex.image = _load_img(tinfo["normal"], non_color=True)
            nt.links.new(mapping.outputs["Vector"], norm_tex.inputs["Vector"])
            norm_map = nt.nodes.new("ShaderNodeNormalMap")
            norm_map.inputs["Strength"].default_value = normal_strength
            nt.links.new(norm_tex.outputs["Color"], norm_map.inputs["Color"])
            nt.links.new(norm_map.outputs["Normal"], bsdf.inputs["Normal"])

    if emission is not None and emission_strength > 0.0:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    return mat


def palette() -> dict[str, bpy.types.Material]:
    return {
        "stone_dark": make_material("StoneDark", (0.24, 0.26, 0.31), 0.0, 0.80, tex_set="nordic_stone", tex_scale=0.35, tint_mix=0.25, normal_strength=1.0),
        "stone_mid": make_material("StoneMid", (0.36, 0.38, 0.43), 0.0, 0.74, tex_set="flagstone_floor", tex_scale=0.38, tint_mix=0.18, normal_strength=0.95),
        "stone_trim": make_material("StoneTrim", (0.48, 0.49, 0.53), 0.05, 0.64, tex_set="nordic_stone", tex_scale=0.55, tint_mix=0.35, normal_strength=0.8),
        "stone_obsidian": make_material("StoneObsidian", (0.16, 0.17, 0.22), 0.18, 0.42, tex_set="flagstone_floor", tex_scale=0.45, tint_mix=0.55, normal_strength=0.9),
        "stone_moss": make_material("StoneMoss", (0.24, 0.34, 0.24), 0.0, 0.82, tex_set="nordic_stone", tex_scale=0.5, tint_mix=0.40, normal_strength=0.9),
        "wood_dark": make_material("WoodDark", (0.28, 0.17, 0.10), 0.0, 0.72, tex_set="aged_oak", tex_scale=0.8, tint_mix=0.35, normal_strength=0.85),
        "wood_warm": make_material("WoodWarm", (0.46, 0.28, 0.15), 0.0, 0.64, tex_set="aged_oak", tex_scale=0.9, tint_mix=0.15, normal_strength=0.85),
        "leather": make_material("Leather", (0.30, 0.18, 0.11), 0.0, 0.56, tex_set="aged_oak", tex_scale=1.6, tint_mix=0.55, normal_strength=0.45),
        "iron_dark": make_material("IronDark", (0.30, 0.33, 0.38), 0.78, 0.38, tex_set="forged_steel", tex_scale=1.1, tint_mix=0.42, normal_strength=0.75),
        "steel": make_material("Steel", (0.72, 0.76, 0.82), 0.88, 0.24, tex_set="forged_steel", tex_scale=1.4, tint_mix=0.22, normal_strength=0.65),
        "bronze": make_material("Bronze", (0.72, 0.52, 0.24), 0.82, 0.30, tex_set="antique_gold", tex_scale=1.2, tint_mix=0.22, normal_strength=0.65),
        "gold_sponsored": make_material("GoldSponsored", (0.96, 0.76, 0.24), 0.90, 0.20, (0.95, 0.68, 0.14), 0.45, tex_set="antique_gold", tex_scale=1.4, tint_mix=0.25, normal_strength=0.55),
        "cloth_red": make_material("ClothRed", (0.58, 0.11, 0.13), 0.0, 0.82, tex_set="woven_crimson", tex_scale=0.75, tint_mix=0.10, normal_strength=0.75),
        "cloth_teal": make_material("ClothTeal", (0.16, 0.44, 0.42), 0.0, 0.78, tex_set="woven_crimson", tex_scale=0.9, tint_mix=0.65, normal_strength=0.6),
        "cloth_dark": make_material("ClothDark", (0.18, 0.20, 0.25), 0.0, 0.82, tex_set="woven_crimson", tex_scale=1.1, tint_mix=0.72, normal_strength=0.55),
        "parchment": make_material("Parchment", (0.82, 0.75, 0.58), 0.0, 0.80),
        "bone": make_material("Bone", (0.78, 0.73, 0.61), 0.0, 0.58, tex_set="nordic_stone", tex_scale=1.5, tint_mix=0.68, normal_strength=0.45),
        "draugr_skin": make_material("DraugrSkin", (0.28, 0.32, 0.35), 0.05, 0.68, tex_set="nordic_stone", tex_scale=1.6, tint_mix=0.55, normal_strength=0.6),
        "goblin_skin": make_material("GoblinSkin", (0.34, 0.54, 0.24), 0.0, 0.58, tex_set="nordic_stone", tex_scale=1.8, tint_mix=0.68, normal_strength=0.35),
        "flame_glow": make_material("FlameGlow", (1.0, 0.60, 0.16), 0.0, 0.25, (1.0, 0.50, 0.10), 3.6),
        "ember_bed": make_material("EmberBed", (0.95, 0.34, 0.08), 0.0, 0.45, (1.0, 0.32, 0.06), 2.4),
        "arcane_cyan": make_material("ArcaneCyan", (0.30, 0.86, 1.0), 0.1, 0.2, (0.24, 0.82, 1.0), 2.4),
        "spell_fire": make_material("SpellFire", (1.0, 0.56, 0.16), 0.05, 0.2, (1.0, 0.45, 0.08), 2.8),
        "safe_emerald": make_material("SafeEmerald", (0.26, 0.90, 0.70), 0.1, 0.25, (0.24, 0.86, 0.66), 2.2),
        "boss_ember": make_material("BossEmber", (1.0, 0.44, 0.10), 0.15, 0.22, (1.0, 0.38, 0.06), 2.8),
        "eye_ice": make_material("EyeIce", (0.45, 0.92, 1.0), 0.0, 0.15, (0.42, 0.92, 1.0), 3.4),
        "potion_red": make_material("PotionRed", (0.68, 0.03, 0.06), 0.06, 0.08, (0.62, 0.02, 0.05), 0.65),
        "streamer_ring": make_material("StreamerRing", (0.96, 0.14, 0.78), 0.1, 0.2, (0.96, 0.12, 0.76), 2.1),
    }


def apply_box_uv(obj: bpy.types.Object, uv_scale: float = 1.0) -> None:
    """Fast deterministic tri-planar/box UV projection using bmesh so PBR textures
    and normal maps wrap cleanly on every beveled mesh with zero stretching.
    """
    mesh = obj.data
    if not isinstance(mesh, bpy.types.Mesh) or len(mesh.polygons) == 0:
        return
    bm = bmesh.new()
    bm.from_mesh(mesh)
    uv_layer = bm.loops.layers.uv.verify()
    for face in bm.faces:
        n = face.normal
        ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
        for loop in face.loops:
            co = loop.vert.co
            if az >= ax and az >= ay:
                u, v = co.x * uv_scale, co.y * uv_scale
            elif ax >= ay:
                u, v = co.y * uv_scale, co.z * uv_scale
            else:
                u, v = co.x * uv_scale, co.z * uv_scale
            loop[uv_layer].uv = (u, v)
    bm.to_mesh(mesh)
    bm.free()


def apply_stylized_finish(obj: bpy.types.Object, mat: bpy.types.Material, bevel_width: float = 0.025, segments: int = 2) -> bpy.types.Object:
    if obj.data.materials:
        obj.data.materials[0] = mat
    else:
        obj.data.materials.append(mat)
    if bevel_width > 0.0:
        mod = obj.modifiers.new(name="Bevel", type="BEVEL")
        mod.width = bevel_width
        mod.segments = segments
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(32.0)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def add_box(name: str, loc: tuple[float, float, float], size: tuple[float, float, float], mat: bpy.types.Material, rot: tuple[float, float, float] = (0, 0, 0), bevel: float = 0.02) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return apply_stylized_finish(obj, mat, bevel_width=bevel)


def add_cylinder(name: str, loc: tuple[float, float, float], radius: float, depth: float, mat: bpy.types.Material, vertices: int = 16, rot: tuple[float, float, float] = (0, 0, 0), bevel: float = 0.012) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    return apply_stylized_finish(obj, mat, bevel_width=bevel)


def add_cone(name: str, loc: tuple[float, float, float], r1: float, r2: float, depth: float, mat: bpy.types.Material, vertices: int = 16, rot: tuple[float, float, float] = (0, 0, 0)) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    return apply_stylized_finish(obj, mat, bevel_width=0.0)


def add_sphere(name: str, loc: tuple[float, float, float], radius: float, mat: bpy.types.Material, scale: tuple[float, float, float] = (1, 1, 1), rot: tuple[float, float, float] = (0, 0, 0)) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, radius=radius, location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    if scale != (1, 1, 1):
        obj.scale = scale
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return apply_stylized_finish(obj, mat, bevel_width=0.0)


def add_torus(name: str, loc: tuple[float, float, float], major_r: float, minor_r: float, mat: bpy.types.Material, rot: tuple[float, float, float] = (0, 0, 0), major_seg: int = 28, minor_seg: int = 12) -> bpy.types.Object:
    bpy.ops.mesh.primitive_torus_add(
        major_segments=major_seg,
        minor_segments=minor_seg,
        major_radius=major_r,
        minor_radius=minor_r,
        location=loc,
        rotation=rot,
    )
    obj = bpy.context.active_object
    obj.name = name
    return apply_stylized_finish(obj, mat, bevel_width=0.0)


def add_lathe(name: str, profile_rz: list[tuple[float, float]], mat: bpy.types.Material, loc: tuple[float, float, float] = (0, 0, 0), rot: tuple[float, float, float] = (0, 0, 0), segments: int = 20) -> bpy.types.Object:
    """Revolves a (radius, z) profile into a smooth sculpted 3D mesh (urns, braziers, helms, potions, goblets)."""
    bm = bmesh.new()
    rings: list[list[bmesh.types.BMVert]] = []
    for r, z in profile_rz:
        ring = []
        rr = max(0.002, r)
        for s in range(segments):
            ang = (s / segments) * math.tau
            ring.append(bm.verts.new((math.cos(ang) * rr, math.sin(ang) * rr, z)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        r0, r1 = rings[i], rings[i + 1]
        for s in range(segments):
            sn = (s + 1) % segments
            bm.faces.new((r0[s], r0[sn], r1[sn], r1[s]))
    # Cap bottom & top
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = loc
    obj.rotation_euler = rot
    return apply_stylized_finish(obj, mat, bevel_width=0.0)


def add_curved_tube(name: str, points: list[tuple[float, float, float]], radii: list[float], mat: bpy.types.Material, sides: int = 12) -> bpy.types.Object:
    """Sweeps a smooth continuous organic tube along 3D control points (zero gaps/segments — ideal for recurve bows, horns, handles!)."""
    bm = bmesh.new()
    rings: list[list[bmesh.types.BMVert]] = []
    n_pts = len(points)
    for i, pt in enumerate(points):
        p = Vector(pt)
        if i == 0:
            tangent = (Vector(points[1]) - p).normalized()
        elif i == n_pts - 1:
            tangent = (p - Vector(points[i - 1])).normalized()
        else:
            tangent = (Vector(points[i + 1]) - Vector(points[i - 1])).normalized()
        up = Vector((0, 0, 1)) if abs(tangent.z) < 0.92 else Vector((1, 0, 0))
        side = tangent.cross(up).normalized()
        normal = side.cross(tangent).normalized()
        rad = radii[i]
        ring = []
        for s in range(sides):
            ang = (s / sides) * math.tau
            offset = (side * math.cos(ang) + normal * math.sin(ang)) * rad
            ring.append(bm.verts.new(p + offset))
        rings.append(ring)
    for i in range(len(rings) - 1):
        r0, r1 = rings[i], rings[i + 1]
        for s in range(sides):
            sn = (s + 1) % sides
            bm.faces.new((r0[s], r0[sn], r1[sn], r1[s]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return apply_stylized_finish(obj, mat, bevel_width=0.0)


def add_tapered_blade(name: str, length: float, width_base: float, width_tip: float, thickness: float, z_start: float, mat: bpy.types.Material) -> bpy.types.Object:
    """Sculpts a crisp diamond-cross-section tapered sword blade with central ridge and sharp tip."""
    bm = bmesh.new()
    slices = [
        (z_start, width_base * 0.5, thickness * 0.5),
        (z_start + length * 0.55, width_base * 0.44, thickness * 0.45),
        (z_start + length * 0.84, width_tip * 0.5, thickness * 0.34),
    ]
    rings = []
    for z, hw, ht in slices:
        v0 = bm.verts.new((-hw, 0.0, z))
        v1 = bm.verts.new((0.0, ht, z))
        v2 = bm.verts.new((hw, 0.0, z))
        v3 = bm.verts.new((0.0, -ht, z))
        rings.append([v0, v1, v2, v3])
    tip = bm.verts.new((0.0, 0.0, z_start + length))
    for i in range(len(rings) - 1):
        r0, r1 = rings[i], rings[i + 1]
        for k in range(4):
            kn = (k + 1) % 4
            bm.faces.new((r0[k], r0[kn], r1[kn], r1[k]))
    last = rings[-1]
    for k in range(4):
        kn = (k + 1) % 4
        bm.faces.new((last[k], last[kn], tip))
    bm.faces.new(list(reversed(rings[0])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    # Keep blade edge crisp (flat-faceted diamond ridge looks razor-sharp!)
    if obj.data.materials:
        obj.data.materials[0] = mat
    else:
        obj.data.materials.append(mat)
    for poly in obj.data.polygons:
        poly.use_smooth = False
    return obj


def compute_scene_bounds() -> tuple[list[float], int]:
    depsgraph = bpy.context.evaluated_depsgraph_get()
    min_v = Vector((1e9, 1e9, 1e9))
    max_v = Vector((-1e9, -1e9, -1e9))
    tri_count = 0
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        eval_obj = obj.evaluated_get(depsgraph)
        mesh = eval_obj.to_mesh()
        tri_count += sum(max(1, len(p.vertices) - 2) for p in mesh.polygons)
        for v in mesh.vertices:
            world_co = obj.matrix_world @ v.co
            min_v.x = min(min_v.x, world_co.x)
            min_v.y = min(min_v.y, world_co.y)
            min_v.z = min(min_v.z, world_co.z)
            max_v.x = max(max_v.x, world_co.x)
            max_v.y = max(max_v.y, world_co.y)
            max_v.z = max(max_v.z, world_co.z)
        eval_obj.to_mesh_clear()
    size = max_v - min_v
    return [round(size.x, 3), round(size.y, 3), round(size.z, 3)], tri_count


def export_asset(batch: str, asset_name: str, manifest_entries: list[dict]) -> pathlib.Path:
    out_dir = MODELS_DIR / batch
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{asset_name}.glb"

    for obj in list(bpy.context.scene.objects):
        if obj.type == "MESH":
            bpy.context.view_layer.objects.active = obj
            for mod in list(obj.modifiers):
                bpy.ops.object.modifier_apply(modifier=mod.name)
            apply_box_uv(obj, uv_scale=1.0)

    dims, tris = compute_scene_bounds()

    bpy.ops.export_scene.gltf(
        filepath=str(out_path),
        export_format="GLB",
        use_selection=False,
        export_apply=True,
        export_materials="EXPORT",
        export_yup=True,
    )

    manifest_entries.append(
        {
            "batch": batch,
            "name": asset_name,
            "path": str(out_path.relative_to(REPO_ROOT)),
            "dimensions_xyz_m": dims,
            "triangles": tris,
            "bytes": out_path.stat().st_size,
        }
    )
    print(f"[blender] Exported {batch}/{asset_name}.glb ({tris} tris, {dims} m)")
    return out_path


def render_batch_preview(
    batch_title: str,
    glb_paths: list[pathlib.Path],
    output_png: pathlib.Path,
    spacing: float = 3.2,
    cam_dist: float = 12.0,
    cam_height: float = 5.5,
    single_row: bool = False,
) -> None:
    """Imports all exported .glb models from a batch onto a rich stone studio plinth
    and renders a denoised Cycles CPU preview image for User art review.
    """
    reset_scene()
    PREVIEWS_DIR.mkdir(parents=True, exist_ok=True)
    p = palette()

    cols = len(glb_paths) if single_row else max(1, math.ceil(math.sqrt(len(glb_paths))))
    rows = 1 if single_row else max(1, math.ceil(len(glb_paths) / cols))

    for idx, glb in enumerate(glb_paths):
        r = idx // cols
        c = idx % cols
        x = (c - (cols - 1) * 0.5) * spacing
        y = ((rows - 1) * 0.5 - r) * spacing

        before = set(bpy.context.scene.objects)
        bpy.ops.import_scene.gltf(filepath=str(glb))
        imported = [o for o in bpy.context.scene.objects if o not in before]
        bpy.context.view_layer.update()
        min_z = 1e9
        for obj in imported:
            if obj.type == "MESH":
                for v in obj.bound_box:
                    wz = (obj.matrix_world @ Vector(v)).z
                    if wz < min_z:
                        min_z = wz
        z_lift = (-min_z + 0.012) if min_z < 1e8 else 0.0
        for obj in imported:
            if obj.parent is None:
                obj.location.x += x
                obj.location.y += y
                obj.location.z += z_lift
                obj.rotation_euler.z += math.radians(-20.0)

    # Studio backdrop plinth
    plinth = add_box("StudioPlinth", (0, 0, -0.25), (cols * spacing + 16.0, rows * spacing + 16.0, 0.5), p["stone_mid"], bevel=0.05)
    apply_box_uv(plinth, 0.5)

    # Three-point studio lighting (warm torch key, cool rim, soft fill)
    def add_light(name: str, ltype: str, loc: tuple[float, float, float], energy: float, color: tuple[float, float, float], size: float = 4.0) -> None:
        ld = bpy.data.lights.new(name=name, type=ltype)
        ld.energy = energy
        ld.color = color
        if ltype == "AREA":
            ld.size = size
        lo = bpy.data.objects.new(name=name, object_data=ld)
        lo.location = loc
        direction = Vector((0, 0, 1.0)) - Vector(loc)
        lo.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        bpy.context.collection.objects.link(lo)

    add_light("KeyWarm", "AREA", (cam_dist * 0.75, -cam_dist * 0.85, cam_height + 4.5), 2200.0, (1.0, 0.86, 0.68), 6.0)
    add_light("RimCool", "AREA", (-cam_dist * 0.9, cam_dist * 0.75, cam_height + 3.5), 1400.0, (0.64, 0.80, 1.0), 5.0)
    add_light("FillSoft", "AREA", (0.0, -cam_dist * 1.15, cam_height * 0.65), 750.0, (0.86, 0.90, 0.96), 8.0)

    world = bpy.data.worlds.new("StudioWorld")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.045, 0.052, 0.072, 1.0)
    bg.inputs["Strength"].default_value = 0.75

    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.lens = 38.0
    cam_obj = bpy.data.objects.new("PreviewCam", cam_data)
    cam_obj.location = (0.0, -cam_dist, cam_height)
    look = Vector((0.0, 0.0, 0.9)) - cam_obj.location
    cam_obj.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()
    bpy.context.collection.objects.link(cam_obj)
    bpy.context.scene.camera = cam_obj

    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 28
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(output_png)
    bpy.ops.render.render(write_still=True)
    print(f"[blender] Rendered preview {batch_title} -> {output_png.relative_to(REPO_ROOT)}")
