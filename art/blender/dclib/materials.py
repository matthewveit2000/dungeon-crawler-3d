"""Blender-side mirror of game/data/materials.json for faithful Cycles previews & icons.

Materials are named exactly like the library keys; the .glb export carries only the names,
so Godot's MaterialLibrary can bind the shared high-res textures at runtime.
"""

from __future__ import annotations

import bpy

from .core import TEXTURES, mat_defs


def _hex(h: str, a: float = 1.0):
    h = h.lstrip("#")
    srgb = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb]
    return (*lin, a)


def _img(name: str, non_color: bool):
    path = TEXTURES / name
    if not path.exists():
        return None
    img = bpy.data.images.load(str(path), check_existing=True)
    img.colorspace_settings.name = "Non-Color" if non_color else "sRGB"
    return img


def get(name: str) -> bpy.types.Material:
    m = bpy.data.materials.get(name)
    if m is not None:
        return m
    d = mat_defs().get(name)
    if d is None:
        raise KeyError(f"Material '{name}' missing from game/data/materials.json")
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nodes, links = nt.nodes, nt.links
    bsdf = nodes.get("Principled BSDF")
    out = nodes.get("Material Output")
    tex = d.get("tex")
    if tex:
        uv = nodes.new("ShaderNodeUVMap")
        alb = nodes.new("ShaderNodeTexImage")
        alb.image = _img(f"{tex}_albedo.webp", False)
        nrm = nodes.new("ShaderNodeTexImage")
        nrm.image = _img(f"{tex}_normal.webp", True)
        orm = nodes.new("ShaderNodeTexImage")
        orm.image = _img(f"{tex}_orm.webp", True)
        for n in (alb, nrm, orm):
            links.new(uv.outputs["UV"], n.inputs["Vector"])
        base = alb.outputs["Color"]
        sep = nodes.new("ShaderNodeSeparateColor")
        links.new(orm.outputs["Color"], sep.inputs["Color"])
        # AO into base colour (preview only; Godot uses AO channel natively)
        ao_mix = nodes.new("ShaderNodeMix")
        ao_mix.data_type = "RGBA"
        ao_mix.blend_type = "MULTIPLY"
        ao_mix.inputs["Factor"].default_value = 0.8
        links.new(base, ao_mix.inputs[6])
        links.new(sep.outputs["Red"], ao_mix.inputs[7])
        base = ao_mix.outputs[2]
        if d.get("vertex_color", False):
            vc = nodes.new("ShaderNodeVertexColor")
            vc.layer_name = "Col"
            vmix = nodes.new("ShaderNodeMix")
            vmix.data_type = "RGBA"
            vmix.blend_type = "MULTIPLY"
            vmix.inputs["Factor"].default_value = 1.0
            links.new(base, vmix.inputs[6])
            links.new(vc.outputs["Color"], vmix.inputs[7])
            base = vmix.outputs[2]
        links.new(base, bsdf.inputs["Base Color"])
        links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
        links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
        nm = nodes.new("ShaderNodeNormalMap")
        nm.inputs["Strength"].default_value = float(d.get("normal_scale", 1.0))
        links.new(nrm.outputs["Color"], nm.inputs["Color"])
        links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
        if d.get("emission_tex"):
            em = nodes.new("ShaderNodeTexImage")
            em.image = _img(f"{tex}_emission.webp", False)
            links.new(uv.outputs["UV"], em.inputs["Vector"])
            links.new(em.outputs["Color"], bsdf.inputs["Emission Color"])
            bsdf.inputs["Emission Strength"].default_value = float(d.get("emission_energy", 1.0))
        elif "emission" in d:
            if tex == "rune_stone":
                em = nodes.new("ShaderNodeTexImage")
                em.image = _img("rune_stone_emission.webp", True)
                links.new(uv.outputs["UV"], em.inputs["Vector"])
                tint = nodes.new("ShaderNodeMix")
                tint.data_type = "RGBA"
                tint.blend_type = "MULTIPLY"
                tint.inputs["Factor"].default_value = 1.0
                links.new(em.outputs["Color"], tint.inputs[6])
                tint.inputs[7].default_value = _hex(d["emission"])
                links.new(tint.outputs[2], bsdf.inputs["Emission Color"])
            else:
                bsdf.inputs["Emission Color"].default_value = _hex(d["emission"])
            bsdf.inputs["Emission Strength"].default_value = float(d.get("emission_energy", 1.0))
    else:
        bsdf.inputs["Base Color"].default_value = _hex(d.get("color", "#808080"))
        bsdf.inputs["Roughness"].default_value = float(d.get("roughness", 0.5))
        bsdf.inputs["Metallic"].default_value = float(d.get("metallic", 0.0))
        if "emission" in d:
            bsdf.inputs["Emission Color"].default_value = _hex(d["emission"])
            bsdf.inputs["Emission Strength"].default_value = float(d.get("emission_energy", 1.0))
        if "alpha" in d:
            a = float(d["alpha"])
            bsdf.inputs["Alpha"].default_value = max(0.25, a)
            bsdf.inputs["Transmission Weight"].default_value = 0.6
            bsdf.inputs["IOR"].default_value = 1.45
            m.blend_method = "BLEND" if hasattr(m, "blend_method") else m.blend_method
    if d.get("double_sided"):
        m.use_backface_culling = False
    return m
