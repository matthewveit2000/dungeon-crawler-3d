class_name DungeonBuilder
extends Node3D
## 3D Procedural + Handcrafted Nordic-Ruin Scene Builder (D-015, D-029).
## Turns a DungeonGenerator layout into a lit, dressed, atmospheric 3D floor:
## - Modular kit (floors, coffered ceilings, ashlar walls incl. burial niches & damaged walls,
##   doorway arches, columns) batched into chunked MultiMeshes for performance.
## - Torches with animated fire, embers, smoke and flickering shadow-casting light (nearest N shadowed).
## - Handcrafted setpieces from setpieces.json + seeded procedural room dressing (barrels, crates,
##   sarcophagi, bones, rubble, candles, banners, cobwebs, dust motes).
## - Volumetric fog / SSAO / SSIL / glow environment scaled by GameSettings graphics quality.

const KIT := "res://assets/models/kit/"
const PROPS := "res://assets/models/props/"
const CHUNK_TILES := 6
const SHADOWED_LIGHTS_HIGH := 8
const SHADOWED_LIGHTS_LOW := 3
const COMPAT_MAX_LIGHTS := 6

const WALL_VARIANTS := [["wall_a", 0.3], ["wall_b", 0.3], ["wall_c", 0.24], ["wall_niche", 0.09], ["wall_damaged", 0.07]]
const FLOOR_VARIANTS := ["floor_a", "floor_b", "floor_c"]

var layout: DungeonGenerator.FloorLayout = null
var boss_gate_node: StaticBody3D = null
var vault_gate_node: StaticBody3D = null
var boss_arena_sealed: bool = false
var vault_unlocked: bool = false
var traps_disarmed: bool = false
var spawned_setpiece_props: int = 0
var spawned_dressing_props: int = 0
var torch_count: int = 0
var environment_node: WorldEnvironment = null

var _trap_nodes: Array[Node3D] = []
var _world_root: Node3D = null
var _flicker_lights: Array[Dictionary] = []
var _managed_lights: Array[OmniLight3D] = []
var _light_focus: Node3D = null
var _gate_targets: Dictionary = {}
var _flicker_time: float = 0.0
var _budget_timer: float = 0.0
var _static_world: StaticBody3D = null
var _batches: Dictionary = {}
var _occluder_verts: PackedVector3Array = PackedVector3Array()
var _occluder_idx: PackedInt32Array = PackedInt32Array()
var _reserved_tiles: Dictionary = {}
var _tile_room: Dictionary = {}
var _floor_cfg: Dictionary = {}


func set_light_focus_target(target: Node3D) -> void:
	_light_focus = target
	update_light_budget()


func _is_compat_renderer() -> bool:
	return RenderingServer.get_current_rendering_method() == "gl_compatibility"


## Keeps the nearest torches shadowed (and, on the OpenGL compatibility renderer, visible within
## its per-object light limit) so lighting stays rich without wasting GPU time on distant lights.
func update_light_budget() -> void:
	var valid: Array[OmniLight3D] = []
	for l in _managed_lights:
		if is_instance_valid(l):
			valid.append(l)
	if valid.is_empty():
		return
	var focus := _light_focus.global_position if (_light_focus != null and is_instance_valid(_light_focus) and _light_focus.is_inside_tree()) else Vector3.ZERO
	var ranked: Array = []
	for l in valid:
		var p := l.global_position if l.is_inside_tree() else l.position
		ranked.append([p.distance_squared_to(focus), l])
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var compat := _is_compat_renderer()
	var q := GameSettings.get_quality() if GameSettings != null else 2
	var shadow_n := SHADOWED_LIGHTS_HIGH if q >= 2 else (SHADOWED_LIGHTS_LOW if q == 1 else 0)
	for i in range(ranked.size()):
		var light: OmniLight3D = ranked[i][1]
		if compat:
			light.visible = i < COMPAT_MAX_LIGHTS
			light.shadow_enabled = false
		else:
			light.visible = true
			light.shadow_enabled = i < shadow_n and bool(light.get_meta("can_shadow", true))


func _process(delta: float) -> void:
	_flicker_time += delta
	_budget_timer -= delta
	if _budget_timer <= 0.0:
		_budget_timer = 0.25
		update_light_budget()
	for fl in _flicker_lights:
		var light: OmniLight3D = fl["light"]
		if is_instance_valid(light) and light.visible:
			var base_e: float = float(fl["base"])
			var ph: float = float(fl["phase"])
			var t := _flicker_time
			var wave := sin(t * 7.3 + ph) * 0.06 + sin(t * 13.1 + ph * 1.7) * 0.04 + sin(t * 23.7 + ph * 0.6) * 0.025
			light.light_energy = base_e * (1.0 + wave)
	for gate in _gate_targets.keys():
		if is_instance_valid(gate):
			var visual := (gate as Node3D).get_node_or_null("GateVisual") as Node3D
			if visual != null:
				var target_y: float = float(_gate_targets[gate])
				var speed := 4.0 if target_y > visual.position.y else 11.0
				visual.position.y = move_toward(visual.position.y, target_y, delta * speed)


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

func build_floor(p_layout: DungeonGenerator.FloorLayout, floor_cfg: Dictionary, interact_cb: Callable, rng: SeededRng) -> void:
	clear_floor()
	layout = p_layout
	_floor_cfg = floor_cfg
	boss_arena_sealed = false
	vault_unlocked = false
	traps_disarmed = false
	spawned_setpiece_props = 0
	spawned_dressing_props = 0
	torch_count = 0
	_batches.clear()
	_occluder_verts = PackedVector3Array()
	_occluder_idx = PackedInt32Array()
	_reserved_tiles.clear()
	_tile_room.clear()

	_world_root = Node3D.new()
	_world_root.name = "DungeonGeometry"
	add_child(_world_root)
	_setup_environment(floor_cfg)

	_static_world = StaticBody3D.new()
	_static_world.name = "WorldColliders"
	_static_world.collision_layer = 1
	_static_world.collision_mask = 1
	_world_root.add_child(_static_world)

	var ts := layout.tile_size
	var wall_h := float(DataLoader.get_world()["grid"]["wall_height_meters"])
	var torch_color := Color.html(str(floor_cfg.get("torch_color", "#ffa34d")))

	for room in layout.rooms:
		var rect: Rect2i = room["rect"]
		for yy in range(rect.position.y, rect.end.y):
			for xx in range(rect.position.x, rect.end.x):
				_tile_room[Vector2i(xx, yy)] = room
	for c in layout.chests:
		_reserved_tiles[c["tile"]] = true
	for c in layout.containers:
		_reserved_tiles[c["tile"]] = true
	for t in layout.traps:
		_reserved_tiles[t] = true
	for sp in layout.enemy_spawns:
		_reserved_tiles[sp["tile"]] = true
	var stairs_center := Vector2i(-99, -99)
	if layout.stairs_room_id >= 0:
		stairs_center = layout.rooms[layout.stairs_room_id]["center"]

	var wall_dirs := [
		{"d": Vector2i(0, -1), "rot_y": 0.0, "off": Vector3(0.0, 0.0, -ts * 0.5)},
		{"d": Vector2i(0, 1), "rot_y": PI, "off": Vector3(0.0, 0.0, ts * 0.5)},
		{"d": Vector2i(-1, 0), "rot_y": PI * 0.5, "off": Vector3(-ts * 0.5, 0.0, 0.0)},
		{"d": Vector2i(1, 0), "rot_y": -PI * 0.5, "off": Vector3(ts * 0.5, 0.0, 0.0)},
	]
	var wall_slots: Array[Dictionary] = []

	for y in range(layout.height):
		for x in range(layout.width):
			var tile := layout.get_tile(x, y)
			if tile == DungeonGenerator.TILE_VOID:
				continue
			var t := Vector2i(x, y)
			var pos := layout.tile_to_world(t)
			var spin := float(rng.next_int_range("gen", 0, 3)) * PI * 0.5
			if t != stairs_center:
				_batch(KIT + FLOOR_VARIANTS[rng.next_int_range("gen", 0, 2)] + ".glb", t, Transform3D(Basis(Vector3.UP, spin), pos))
			_add_box_collider(_static_world, pos + Vector3(0.0, -0.25, 0.0), Vector3(ts, 0.5, ts))
			var ceil_name := "ceiling_b" if rng.next_float("gen") < 0.08 else "ceiling_a"
			_batch(KIT + ceil_name + ".glb", t, Transform3D(Basis(Vector3.UP, spin), pos))
			_add_box_collider(_static_world, pos + Vector3(0.0, wall_h + 0.25, 0.0), Vector3(ts, 0.5, ts))

			for wd in wall_dirs:
				var d: Vector2i = wd["d"]
				var n := t + d
				var rot_y: float = float(wd["rot_y"])
				var w_pos: Vector3 = pos + wd["off"]
				var basis := Basis(Vector3.UP, rot_y)
				if not layout.is_walkable(n.x, n.y):
					var inward := Vector3(-float(d.x), 0.0, -float(d.y))
					wall_slots.append({"pos": w_pos, "rot_y": rot_y, "inward": inward, "tile": t, "tile_type": tile,
						"room": _tile_room.get(t, {}), "variant": ""})
					var col_size := Vector3(ts, wall_h, 0.65) if d.y != 0 else Vector3(0.65, wall_h, ts)
					_add_box_collider(_static_world, w_pos + Vector3(0.0, wall_h * 0.5, 0.0), col_size)
					_add_occluder_quad(w_pos + inward * -0.05, basis, ts, wall_h + 0.3)
				elif (d == Vector2i(1, 0) or d == Vector2i(0, 1)) and _is_room_tile(tile) != _is_room_tile(layout.get_tile(n.x, n.y)):
					_place_arch(w_pos, rot_y)

	# Choose wall variants: torch slots stay plain; a few niches & damaged walls add storytelling
	var torch_slots: Array[Dictionary] = []
	for i in range(wall_slots.size()):
		var s: Dictionary = wall_slots[i]
		var t: Vector2i = s["tile"]
		var is_room := _is_room_tile(int(s["tile_type"]))
		var want_torch := false
		if is_room:
			want_torch = (t.x * 3 + t.y * 5 + i) % 3 == 0
		else:
			want_torch = (t.x + t.y) % 3 == 0 and (i % 2 == 0)
		if want_torch and torch_count < 72:
			s["variant"] = ["wall_a", "wall_b", "wall_c"][rng.next_int_range("gen", 0, 2)]
			torch_slots.append(s)
			torch_count += 1
		else:
			s["variant"] = _pick_weighted(WALL_VARIANTS, rng)
		var tf := Transform3D(Basis(Vector3.UP, float(s["rot_y"])), s["pos"])
		_batch(KIT + str(s["variant"]) + ".glb", t, tf)

	for s in torch_slots:
		_place_torch(s, torch_color, rng)

	# Columns in large rooms
	for room in layout.rooms:
		var rect: Rect2i = room["rect"]
		if rect.size.x >= 5 and rect.size.y >= 5 and str(room["role"]) != "boss":
			for px in [rect.position.x + 1, rect.end.x - 2]:
				for py in [rect.position.y + 1, rect.end.y - 2]:
					var pt := Vector2i(px, py)
					var pil_pos := layout.tile_to_world(pt) + Vector3(-ts * 0.5 if px == rect.position.x + 1 else ts * 0.5, 0, -ts * 0.5 if py == rect.position.y + 1 else ts * 0.5)
					_batch(KIT + "pillar.glb", pt, Transform3D(Basis.IDENTITY, pil_pos))
					_add_box_collider(_static_world, pil_pos + Vector3(0.0, wall_h * 0.5, 0.0), Vector3(0.8, wall_h, 0.8))
		elif str(room["role"]) == "boss":
			# Ring of columns framing the crucible
			var c := layout.tile_to_world(room["center"])
			for k in range(6):
				var a := float(k) / 6.0 * TAU + PI / 6.0
				var pp := c + Vector3(cos(a), 0, sin(a)) * 9.2
				_batch(KIT + "pillar.glb", room["center"], Transform3D(Basis.IDENTITY, pp))
				_add_box_collider(_static_world, pp + Vector3(0.0, wall_h * 0.5, 0.0), Vector3(0.8, wall_h, 0.8))

	_flush_batches()
	_build_occluder()

	# Handcrafted setpieces stitched into procedural rooms (D-029)
	var setpieces_map: Dictionary = DataLoader.get_setpieces_pack().get("setpieces", {})
	for room in layout.rooms:
		var role := str(room["role"])
		var center_w := layout.tile_to_world(room["center"])
		var sp_key := role
		if role == "safe":
			sp_key = "safe_room"
		elif role == "boss":
			sp_key = "boss_arena"
		if setpieces_map.has(sp_key):
			_apply_handcrafted_setpiece(setpieces_map[sp_key], center_w, rng)
		match role:
			"safe":
				_build_safe_room_interactables(center_w, Color.html(str(floor_cfg.get("safe_zone_color", "#45e6b8"))), interact_cb)
			"stairs":
				_build_stairs_interactable(center_w, interact_cb)
			"boss":
				# Warm key from above keeps the boss readable; the red crucible glow stays low so it reads
				# as an accent instead of tinting the whole arena through the volumetric fog
				_add_light(_world_root, center_w + Vector3(0.0, 3.9, 0.0), Color(1.0, 0.72, 0.5), 2.0, 16.0, true)
				var glow := _add_light(_world_root, center_w + Vector3(0.0, 0.9, 0.0), Color.html(str(floor_cfg.get("boss_color", "#e04838"))), 1.2, 8.0, false)
				glow.light_volumetric_fog_energy = 0.35
			"entrance":
				_add_light(_world_root, center_w + Vector3(0.0, 3.4, 0.0), Color(1.0, 0.78, 0.55), 1.0, 14.0, false)
		_dress_room(room, wall_slots, rng)
		_add_room_atmosphere(room)

	boss_gate_node = _build_gate(layout.boss_gate_tile, "BossGate", PROPS + "boss_gate.glb", false)
	vault_gate_node = _build_gate(layout.vault_gate_tile, "VaultGate", PROPS + "vault_gate.glb", true)

	for idx in range(layout.chests.size()):
		var c: Dictionary = layout.chests[idx]
		var wpos := layout.tile_to_world(c["tile"])
		var tier := str(c.get("tier", "standard"))
		var label := "Open Vault Treasure Chest" if tier == "vault_sponsored" else "Open Iron-Bound Chest"
		var inter := InteractableObject.new()
		inter.setup("chest_%d" % idx, "chest", label, c, interact_cb, Vector3(1.2, 1.0, 0.85))
		inter.position = wpos
		inter.rotation.y = _face_room_center(c["tile"])
		var model := ModelLoader.instantiate_model(PROPS + "chest.glb", Vector3(1.1, 0.8, 0.7))
		inter.add_child(model)
		inter.visual_root = model
		if tier == "vault_sponsored":
			_add_light(inter, Vector3(0.0, 1.3, 0.6), Color(1.0, 0.8, 0.38), 1.6, 6.0, false)
		_world_root.add_child(inter)

	for idx in range(layout.containers.size()):
		var cont: Dictionary = layout.containers[idx]
		var kind := str(cont.get("kind", "crate"))
		var wpos := layout.tile_to_world(cont["tile"]) + Vector3(-1.1, 0.0, -1.1)
		var inter := InteractableObject.new()
		inter.setup("cont_%d" % idx, kind, "Search %s" % ("Supply Crate" if kind == "crate" else "Burial Urn"), cont, interact_cb, Vector3(0.95, 1.0, 0.95))
		inter.position = wpos
		inter.rotation.y = rng.next_float("gen") * TAU
		var model := ModelLoader.instantiate_model(PROPS + ("crate.glb" if kind == "crate" else "urn.glb"), Vector3(0.9, 0.9, 0.9))
		inter.add_child(model)
		inter.visual_root = model
		_world_root.add_child(inter)

	for idx in range(layout.traps.size()):
		var t_pos := layout.tile_to_world(layout.traps[idx])
		var trap_mesh := ModelLoader.instantiate_model(PROPS + "spike_trap.glb", Vector3(1.8, 0.4, 1.8))
		trap_mesh.position = t_pos + Vector3(0.0, 0.02, 0.0)
		_world_root.add_child(trap_mesh)
		_trap_nodes.append(trap_mesh)
		if idx == 0:
			var lever := InteractableObject.new()
			lever.setup("trap_lever", "lever", "Pull Trap Disarm Lever", {}, interact_cb, Vector3(0.6, 1.4, 0.6))
			lever.position = t_pos + Vector3(1.6, 0.0, 0.0)
			var lm := ModelLoader.instantiate_model(PROPS + "lever.glb", Vector3(0.6, 1.5, 0.6))
			lever.add_child(lm)
			lever.visual_root = lm
			_world_root.add_child(lever)

	update_light_budget()


func _is_room_tile(tile: int) -> bool:
	return tile == DungeonGenerator.TILE_FLOOR or tile == DungeonGenerator.TILE_SAFE_FLOOR \
		or tile == DungeonGenerator.TILE_BOSS_FLOOR or tile == DungeonGenerator.TILE_VAULT_FLOOR


func _pick_weighted(options: Array, rng: SeededRng) -> String:
	var total := 0.0
	for o in options:
		total += float(o[1])
	var r := rng.next_float("gen") * total
	for o in options:
		r -= float(o[1])
		if r <= 0.0:
			return str(o[0])
	return str(options[0][0])


func _face_room_center(tile: Vector2i) -> float:
	var room: Dictionary = _tile_room.get(tile, {})
	if room.is_empty():
		return 0.0
	var c := layout.tile_to_world(room["center"])
	var p := layout.tile_to_world(tile)
	var d := c - p
	if d.length_squared() < 0.01:
		return 0.0
	return atan2(d.x, d.z)


# ---------------------------------------------------------------------------
# Batching (chunked MultiMesh) + occlusion
# ---------------------------------------------------------------------------

func _batch(model_path: String, tile: Vector2i, xf: Transform3D) -> void:
	var chunk := Vector2i(tile.x / CHUNK_TILES, tile.y / CHUNK_TILES)
	if not _batches.has(model_path):
		_batches[model_path] = {}
	var per: Dictionary = _batches[model_path]
	if not per.has(chunk):
		per[chunk] = []
	(per[chunk] as Array).append(xf)


func _flush_batches() -> void:
	var holder := Node3D.new()
	holder.name = "Architecture"
	_world_root.add_child(holder)
	for path in _batches.keys():
		var mesh := ModelLoader.load_mesh(path)
		if mesh == null:
			continue
		var per: Dictionary = _batches[path]
		for chunk in per.keys():
			var xfs: Array = per[chunk]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = xfs.size()
			for i in range(xfs.size()):
				mm.set_instance_transform(i, xfs[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "%s_%d_%d" % [str(path).get_file().get_basename(), chunk.x, chunk.y]
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			holder.add_child(mmi)
	_batches.clear()


func _add_occluder_quad(center_floor: Vector3, basis: Basis, width: float, height: float) -> void:
	var right := basis.x * (width * 0.5)
	var up := Vector3.UP * height
	var base := _occluder_verts.size()
	_occluder_verts.append(center_floor - right)
	_occluder_verts.append(center_floor + right)
	_occluder_verts.append(center_floor + right + up)
	_occluder_verts.append(center_floor - right + up)
	for i in [0, 1, 2, 0, 2, 3]:
		_occluder_idx.append(base + i)


func _build_occluder() -> void:
	if _occluder_verts.is_empty():
		return
	var occ := ArrayOccluder3D.new()
	occ.set_arrays(_occluder_verts, _occluder_idx)
	var oi := OccluderInstance3D.new()
	oi.name = "WallOccluders"
	oi.occluder = occ
	_world_root.add_child(oi)


# ---------------------------------------------------------------------------
# Architecture details
# ---------------------------------------------------------------------------

func _place_arch(edge_pos: Vector3, rot_y: float) -> void:
	var tile := layout.world_to_tile(edge_pos + Vector3(0.01, 0, 0.01))
	var basis := Basis(Vector3.UP, rot_y)
	_batch(KIT + "door_arch.glb", tile, Transform3D(basis, edge_pos))
	var wall_h := float(DataLoader.get_world()["grid"]["wall_height_meters"])
	for sx in [-1.0, 1.0]:
		var jp: Vector3 = edge_pos + basis.x * (sx * 1.78)
		var size := basis * Vector3(0.6, wall_h, 0.9)
		_add_box_collider(_static_world, jp + Vector3(0.0, wall_h * 0.5, 0.0), Vector3(absf(size.x), wall_h, absf(size.z)))


func _place_torch(slot: Dictionary, torch_color: Color, rng: SeededRng) -> void:
	var inward: Vector3 = slot["inward"]
	var mount: Vector3 = slot["pos"] + inward * 0.30 + Vector3(0.0, 2.15, 0.0)
	var sconce := ModelLoader.instantiate_model(PROPS + "torch_sconce.glb", Vector3(0.2, 0.6, 0.3))
	sconce.position = mount
	sconce.rotation.y = float(slot["rot_y"])
	_world_root.add_child(sconce)
	var socket := sconce.find_child("FlameSocket*", true, false) as Node3D
	var flame_local := socket.position if socket != null else Vector3(0.0, 0.55, 0.42)
	var flame_pos := sconce.transform * flame_local
	var fire := VfxFactory.make_fire(0.55)
	fire.position = flame_pos
	_world_root.add_child(fire)
	var col := torch_color
	if int(slot["tile_type"]) == DungeonGenerator.TILE_BOSS_FLOOR:
		col = Color(1.0, 0.5, 0.3)
	var light := _add_light(_world_root, flame_pos + inward * 0.25 + Vector3(0, 0.1, 0), col, 1.55, 9.5, true, rng.next_float("gen") * TAU)
	light.set_meta("can_shadow", true)


func _add_light(parent: Node3D, pos: Vector3, col: Color, energy: float, rng_m: float, flicker: bool, phase: float = 0.0) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng_m
	l.omni_attenuation = 1.15
	l.light_size = 0.06
	l.shadow_enabled = false
	l.shadow_bias = 0.06
	l.shadow_normal_bias = 1.2
	l.light_volumetric_fog_energy = 0.9
	l.light_specular = 0.6
	l.distance_fade_enabled = true
	l.distance_fade_begin = 38.0
	l.distance_fade_length = 10.0
	parent.add_child(l)
	_managed_lights.append(l)
	if flicker:
		_flicker_lights.append({"light": l, "base": energy, "phase": phase})
	return l


# ---------------------------------------------------------------------------
# Setpieces & dressing
# ---------------------------------------------------------------------------

func _apply_handcrafted_setpiece(sp_def: Dictionary, center_w: Vector3, rng: SeededRng) -> void:
	for prop in sp_def.get("props", []):
		var mpath := str(prop.get("model", ""))
		if mpath.is_empty() or mpath.ends_with("merchant_stall.glb"):
			continue
		var off: Array = prop.get("offset", [0.0, 0.0, 0.0])
		var p_node := ModelLoader.instantiate_model(mpath, Vector3.ONE)
		p_node.position = center_w + Vector3(float(off[0]), float(off[1]), float(off[2]))
		p_node.rotation.y = float(prop.get("rot_y", 0.0))
		if prop.has("scale"):
			var sc: Array = prop["scale"]
			p_node.scale = Vector3(float(sc[0]), float(sc[1]), float(sc[2]))
		_world_root.add_child(p_node)
		spawned_setpiece_props += 1
		if prop.has("collider"):
			var cs: Array = prop["collider"]
			_add_box_collider(_static_world, p_node.position + Vector3(0.0, float(cs[1]) * 0.5, 0.0), Vector3(float(cs[0]), float(cs[1]), float(cs[2])))
		var socket := p_node.find_child("FlameSocket*", true, false) as Node3D
		if prop.has("light_color"):
			var fpos := p_node.position + Vector3(0.0, 1.0, 0.0)
			if socket != null:
				fpos = p_node.transform * socket.position
			if bool(prop.get("fire", socket != null)):
				var fire := VfxFactory.make_fire(float(prop.get("fire_scale", 1.2)))
				fire.position = fpos
				_world_root.add_child(fire)
			_add_light(_world_root, fpos + Vector3(0.0, 0.35, 0.0), Color.html(str(prop["light_color"])),
				float(prop.get("light_energy", 2.0)), float(prop.get("light_range", 11.0)), true, rng.next_float("gen") * TAU)


const DRESSING := {
	"combat": [["barrel", 3.0], ["crate", 2.0], ["urn", 2.0], ["rubble_pile", 2.0], ["bone_pile", 2.0], ["candle_cluster", 1.5], ["sarcophagus", 1.2], ["weapon_rack", 0.8]],
	"entrance": [["barrel", 2.0], ["crate", 2.0], ["weapon_rack", 1.5], ["candle_cluster", 1.0], ["table", 1.0]],
	"stairs": [["bone_pile", 2.0], ["rubble_pile", 2.0], ["urn", 2.0], ["candle_cluster", 1.5]],
	"safe": [["barrel", 2.0], ["crate", 1.5], ["table", 1.5], ["candle_cluster", 1.5], ["weapon_rack", 1.0]],
	"boss": [["bone_pile", 3.0], ["rubble_pile", 2.0], ["candle_cluster", 1.0]],
	"vault": [["urn", 3.0], ["candle_cluster", 2.0]],
}
const DRESSING_DEPTH := {"barrel": 0.8, "crate": 0.9, "urn": 0.6, "rubble_pile": 1.0, "bone_pile": 1.1, "candle_cluster": 0.4,
	"sarcophagus": 1.2, "weapon_rack": 0.6, "table": 1.0}
const DRESSING_COLLIDE := {"barrel": Vector3(0.8, 1.0, 0.8), "crate": Vector3(0.9, 0.9, 0.9), "urn": Vector3(0.55, 0.95, 0.55),
	"sarcophagus": Vector3(2.4, 0.9, 1.2), "weapon_rack": Vector3(1.6, 1.6, 0.6), "table": Vector3(2.0, 0.9, 1.0)}


func _dress_room(room: Dictionary, wall_slots: Array[Dictionary], rng: SeededRng) -> void:
	var role := str(room["role"])
	var options: Array = DRESSING.get(role, DRESSING["combat"])
	var rect: Rect2i = room["rect"]
	var chance := 0.42 if role != "boss" else 0.3
	for s in wall_slots:
		var t: Vector2i = s["tile"]
		if not rect.has_point(t) or _reserved_tiles.has(t):
			continue
		if not str(s["variant"]).begins_with("wall_") or str(s["variant"]) == "wall_niche":
			continue
		if _tile_near_opening(t):
			continue
		if rng.next_float("gen") > chance:
			continue
		var kind := _pick_weighted(options, rng)
		var inward: Vector3 = s["inward"]
		var along := Basis(Vector3.UP, float(s["rot_y"])).x
		var depth := float(DRESSING_DEPTH.get(kind, 0.8))
		var p: Vector3 = s["pos"] + inward * (0.32 + depth * 0.5) + along * rng.next_float_range("gen", -0.9, 0.9)
		var rot := float(s["rot_y"])
		if kind in ["barrel", "urn", "crate", "rubble_pile", "bone_pile", "candle_cluster"]:
			rot += rng.next_float_range("gen", -0.6, 0.6)
		_spawn_dressing(kind, p, rot, rng)
		if kind == "barrel" and rng.next_float("gen") < 0.6:
			_spawn_dressing("barrel", p + along * 0.82 + inward * rng.next_float_range("gen", -0.1, 0.15), rot + 1.3, rng)
		elif kind == "crate" and rng.next_float("gen") < 0.4:
			var top := ModelLoader.instantiate_model(PROPS + "crate.glb")
			top.position = p + Vector3(0, 0.87, 0)
			top.rotation.y = rot + rng.next_float_range("gen", -0.4, 0.4)
			top.scale = Vector3.ONE * 0.8
			_world_root.add_child(top)
		_reserved_tiles[t] = true


func _spawn_dressing(kind: String, p: Vector3, rot: float, _rng: SeededRng) -> void:
	var n := ModelLoader.instantiate_model(PROPS + kind + ".glb")
	n.position = p
	n.rotation.y = rot
	_world_root.add_child(n)
	spawned_dressing_props += 1
	if DRESSING_COLLIDE.has(kind):
		var cs: Vector3 = DRESSING_COLLIDE[kind]
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = cs
		col.shape = box
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = p
		body.rotation.y = rot
		col.position.y = cs.y * 0.5
		body.add_child(col)
		_world_root.add_child(body)
	if kind == "candle_cluster":
		var l := _add_light(_world_root, p + Vector3(0, 0.45, 0), Color(1.0, 0.7, 0.4), 0.55, 3.5, true, p.x)
		l.set_meta("can_shadow", false)


func _tile_near_opening(t: Vector2i) -> bool:
	var tt := layout.get_tile(t.x, t.y)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = t + d
		var nt := layout.get_tile(n.x, n.y)
		if nt != DungeonGenerator.TILE_VOID and _is_room_tile(nt) != _is_room_tile(tt):
			return true
	return false


func _add_room_atmosphere(room: Dictionary) -> void:
	var rect: Rect2i = room["rect"]
	var ts := layout.tile_size
	var c := layout.tile_to_world(room["center"])
	var extent := Vector3(float(rect.size.x) * ts - 1.0, 3.2, float(rect.size.y) * ts - 1.0)
	var dust := VfxFactory.make_dust(extent)
	var origin := layout.tile_to_world(rect.position) - Vector3(ts * 0.5, 0, ts * 0.5)
	if dust != null:
		dust.position = origin + Vector3(float(rect.size.x) * ts * 0.5, 2.0, float(rect.size.y) * ts * 0.5)
		_world_root.add_child(dust)
	# cobwebs in inner corners just under the ceiling
	var corners := [
		[rect.position, Vector3(1, 0, 1)],
		[Vector2i(rect.end.x - 1, rect.position.y), Vector3(-1, 0, 1)],
		[Vector2i(rect.position.x, rect.end.y - 1), Vector3(1, 0, -1)],
		[Vector2i(rect.end.x - 1, rect.end.y - 1), Vector3(-1, 0, -1)],
	]
	for cc in corners:
		var tile: Vector2i = cc[0]
		var dir: Vector3 = cc[1]
		var wp := layout.tile_to_world(tile)
		var corner := wp - Vector3(dir.x * (ts * 0.5 - 0.32), 0, dir.z * (ts * 0.5 - 0.32))
		if (tile.x + tile.y) % 2 == 1:
			continue
		var web := VfxFactory.make_cobweb(1.3)
		var dn := dir.normalized()
		var b := Basis.looking_at(-dn, Vector3.UP) * Basis(Vector3.RIGHT, -0.45)
		web.transform = Transform3D(b, corner + dn * 0.2 + Vector3(0, 4.35, 0) - b.x * 0.65)
		_world_root.add_child(web)


# ---------------------------------------------------------------------------
# Interactables & gates
# ---------------------------------------------------------------------------

func _build_safe_room_interactables(center_w: Vector3, ward_color: Color, interact_cb: Callable) -> void:
	_add_light(_world_root, center_w + Vector3(0.0, 3.6, 0.8), Color(1.0, 0.8, 0.55), 1.4, 16.0, false)
	var beacon := ModelLoader.instantiate_model(PROPS + "safe_beacon.glb", Vector3(1.0, 2.0, 1.0))
	beacon.position = center_w + Vector3(0.3, 0.0, -3.1)
	_world_root.add_child(beacon)
	spawned_setpiece_props += 1
	var aura := VfxFactory.make_magic_aura(ward_color, 0.35, 40)
	aura.position = beacon.position + Vector3(0, 1.6, 0)
	_world_root.add_child(aura)
	var glow := VfxFactory.make_glow(ward_color, 1.4, 1.2)
	glow.position = beacon.position + Vector3(0, 1.6, 0)
	_world_root.add_child(glow)
	var bl := _add_light(_world_root, beacon.position + Vector3(0.0, 1.7, 0.0), ward_color, 1.6, 8.0, true)
	bl.set_meta("can_shadow", false)
	_add_box_collider(_static_world, beacon.position + Vector3(0, 0.6, 0), Vector3(1.0, 1.2, 1.0))

	var vendor := InteractableObject.new()
	vendor.setup("safe_vendor", "vendor", "Trade with the Safe Room Merchant", {}, interact_cb, Vector3(2.8, 2.4, 2.0))
	vendor.position = center_w + Vector3(-2.6, 0.0, -2.0)
	vendor.rotation.y = 0.26
	var stall := ModelLoader.instantiate_model(PROPS + "merchant_stall.glb", Vector3(2.8, 2.8, 1.6))
	stall.rotation.y = PI
	vendor.add_child(stall)
	var npc := CharacterVisual.create("vendor")
	npc.position = Vector3(0.0, 0.0, -0.95)
	vendor.add_child(npc)
	npc.play_state("idle")
	var socket := stall.find_child("LanternSocket*", true, false) as Node3D
	if socket != null:
		var ll := _add_light(vendor, Basis(Vector3.UP, PI) * socket.position + Vector3(0, -0.05, 0), Color(1.0, 0.72, 0.4), 1.1, 6.0, true)
		ll.set_meta("can_shadow", false)
	_world_root.add_child(vendor)
	spawned_setpiece_props += 1

	var qboard := InteractableObject.new()
	qboard.setup("safe_quest_board", "quest_board", "Read the Syndicate Quest Board", {}, interact_cb, Vector3(2.2, 2.4, 0.9))
	qboard.position = center_w + Vector3(2.8, 0.0, -2.0)
	qboard.rotation.y = -0.25
	qboard.add_child(ModelLoader.instantiate_model(PROPS + "quest_board.glb", Vector3(2.0, 2.3, 0.6)))
	_world_root.add_child(qboard)


func _build_stairs_interactable(center_w: Vector3, interact_cb: Callable) -> void:
	# D-008: Strictly NO next-floor preview text!
	var stairs := InteractableObject.new()
	stairs.setup("hidden_stairs", "stairs", "Descend the Stairwell", {}, interact_cb, Vector3(3.4, 2.2, 3.4))
	stairs.position = center_w
	stairs.add_child(ModelLoader.instantiate_model(PROPS + "staircase_down.glb", Vector3(3.5, 3.5, 3.5)))
	_world_root.add_child(stairs)
	var l := _add_light(_world_root, center_w + Vector3(0.0, -1.2, 0.6), Color(0.45, 0.65, 1.0), 1.2, 7.0, true)
	l.set_meta("can_shadow", false)


func _build_gate(tile: Vector2i, gate_name: String, model_path: String, closed_initially: bool) -> StaticBody3D:
	var gate := StaticBody3D.new()
	gate.name = gate_name
	gate.position = layout.tile_to_world(tile)
	if layout.is_walkable(tile.x - 1, tile.y) and layout.is_walkable(tile.x + 1, tile.y):
		gate.rotation.y = PI * 0.5
	var mesh := ModelLoader.instantiate_model(model_path, Vector3(3.6, 3.8, 0.45))
	mesh.name = "GateVisual"
	gate.add_child(mesh)
	var col := CollisionShape3D.new()
	col.name = "GateCollider"
	var box := BoxShape3D.new()
	box.size = Vector3(3.8, 4.0, 0.55)
	col.shape = box
	col.position.y = 2.0
	gate.add_child(col)
	_world_root.add_child(gate)
	_set_gate_closed(gate, closed_initially, true)
	return gate


func seal_boss_arena() -> void:
	if boss_arena_sealed or boss_gate_node == null:
		return
	boss_arena_sealed = true
	_set_gate_closed(boss_gate_node, true, false)


func unlock_boss_and_vault() -> void:
	boss_arena_sealed = false
	vault_unlocked = true
	if boss_gate_node != null:
		_set_gate_closed(boss_gate_node, false, false)
	if vault_gate_node != null:
		_set_gate_closed(vault_gate_node, false, false)


func disarm_traps() -> void:
	traps_disarmed = true
	for tn in _trap_nodes:
		if is_instance_valid(tn):
			var tw := tn.create_tween() if tn.is_inside_tree() else null
			if tw != null:
				tw.tween_property(tn, "position:y", tn.position.y - 0.36, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			else:
				tn.position.y -= 0.36


func is_player_on_active_trap(player_pos: Vector3) -> bool:
	if traps_disarmed or layout == null:
		return false
	for t in layout.traps:
		var tp := layout.tile_to_world(t)
		if Vector2(tp.x - player_pos.x, tp.z - player_pos.z).length() <= 1.05:
			return true
	return false


func clear_floor() -> void:
	if _world_root != null and is_instance_valid(_world_root):
		_world_root.queue_free()
	_world_root = null
	environment_node = null
	boss_gate_node = null
	vault_gate_node = null
	_trap_nodes.clear()
	_flicker_lights.clear()
	_managed_lights.clear()
	_gate_targets.clear()


func _set_gate_closed(gate: StaticBody3D, closed: bool, instant: bool) -> void:
	var visual := gate.get_node_or_null("GateVisual") as Node3D
	var col := gate.get_node_or_null("GateCollider") as CollisionShape3D
	var target_y := 0.0 if closed else 3.9
	_gate_targets[gate] = target_y
	if visual != null and instant:
		visual.position.y = target_y
	if col != null:
		col.disabled = not closed


# ---------------------------------------------------------------------------
# Environment (quality-scaled)
# ---------------------------------------------------------------------------

func _setup_environment(floor_cfg: Dictionary) -> void:
	environment_node = WorldEnvironment.new()
	environment_node.name = "DungeonEnvironment"
	environment_node.environment = build_environment(floor_cfg, GameSettings.get_quality() if GameSettings != null else 2)
	_world_root.add_child(environment_node)


func refresh_environment_quality() -> void:
	if environment_node != null and is_instance_valid(environment_node):
		environment_node.environment = build_environment(_floor_cfg, GameSettings.get_quality() if GameSettings != null else 2)
	update_light_budget()


static func build_environment(floor_cfg: Dictionary, quality: int) -> Environment:
	var env := Environment.new()
	var fog_col := Color.html(str(floor_cfg.get("fog_color", "#11151d")))
	env.background_mode = Environment.BG_COLOR
	env.background_color = fog_col.darkened(0.6)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var amb := Color.html(str(floor_cfg.get("ambient_color", "#1a1f28")))
	env.ambient_light_color = amb.lerp(Color(0.30, 0.36, 0.50), 0.6)
	env.ambient_light_energy = 0.22
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0 * (float(GameSettings.get_value("graphics", "brightness")) if GameSettings != null else 1.0)
	env.tonemap_white = 4.0
	# Depth fog keeps distant corridors mysterious on every quality level
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = fog_col.lerp(Color(0.05, 0.06, 0.085), 0.6)
	env.fog_light_energy = 1.0
	env.fog_density = 0.02
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.0
	# Bloom on fire, runes and magic
	env.glow_enabled = true
	env.glow_normalized = false
	env.glow_intensity = 0.45
	env.glow_strength = 1.0
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.1
	env.glow_hdr_scale = 2.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 0.6)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 0.8)
	env.set_glow_level(4, 0.4)
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.04
	if quality >= 1:
		env.ssao_enabled = true
		env.ssao_radius = 1.2
		env.ssao_intensity = 2.2
		env.ssao_power = 1.6
		env.ssao_detail = 0.6
		env.ssao_light_affect = 0.15
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.014
		env.volumetric_fog_albedo = Color(0.55, 0.55, 0.58)
		env.volumetric_fog_emission = Color(0.0, 0.0, 0.0)
		env.volumetric_fog_anisotropy = 0.45
		env.volumetric_fog_length = 40.0
		env.volumetric_fog_detail_spread = 2.0
		env.volumetric_fog_gi_inject = 0.3
		env.volumetric_fog_ambient_inject = 0.0
		env.volumetric_fog_temporal_reprojection_enabled = true
		env.fog_density = 0.01
	if quality >= 2:
		env.ssil_enabled = true
		env.ssil_radius = 4.0
		env.ssil_intensity = 0.9
		env.ssil_sharpness = 0.98
		env.ssr_enabled = false
	if quality >= 3:
		env.sdfgi_enabled = true
		env.sdfgi_use_occlusion = true
		env.sdfgi_cascades = 4
		env.sdfgi_min_cell_size = 0.25
		env.sdfgi_energy = 0.9
		env.sdfgi_bounce_feedback = 0.4
		env.ambient_light_energy = 0.35
	return env


static func _add_box_collider(body: StaticBody3D, pos: Vector3, size: Vector3) -> void:
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position = pos
	body.add_child(col)
