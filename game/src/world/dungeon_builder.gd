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
const CHUNK_TILES := 8
## Vast floors (D-044): decor (torches, braziers, room lights, dressing, dust) is spawned per STREAM_CHUNK_TILES
## chunk while the player is within STREAM_RADIUS chunks and freed behind them; far architecture is not drawn.
const STREAM_CHUNK_TILES := 8
const STREAM_RADIUS := 2
const ARCH_VISIBILITY_RANGE := 170.0
const SHADOWED_LIGHTS_HIGH := 8
const SHADOWED_LIGHTS_LOW := 3
const COMPAT_MAX_LIGHTS := 16

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
var brazier_count: int = 0
var environment_node: WorldEnvironment = null

var _trap_nodes: Array[Node3D] = []
var _world_root: Node3D = null
var _flicker_lights: Array[Dictionary] = []
var _managed_lights: Array[OmniLight3D] = []
var _light_focus: Node3D = null
var _gate_targets: Dictionary = {}
var _gate_vels: Dictionary = {}
var _beacon_crystal: Node3D = null
var _beacon_base_y: float = 1.58
var vendor_visual: CharacterVisual = null
var _flicker_time: float = 0.0
var _budget_timer: float = 0.0
var _static_world: StaticBody3D = null
var _batches: Dictionary = {}
var _occluder_verts: PackedVector3Array = PackedVector3Array()
var _occluder_idx: PackedInt32Array = PackedInt32Array()
var _reserved_tiles: Dictionary = {}
var _tile_room: Dictionary = {}
var _floor_cfg: Dictionary = {}
var _stream_specs: Dictionary = {}  ## chunk -> Array[Callable] that spawn that chunk's decor and return the nodes
var _stream_live: Dictionary = {}  ## chunk -> Array[Node] currently spawned
var _stream_center := Vector2i(-99999, -99999)
var _hwall_runs: Dictionary = {}  ## boundary line y -> Array[int] tile x with a wall on that line
var _vwall_runs: Dictionary = {}  ## boundary line x -> Array[int] tile y with a wall on that line


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
		if is_instance_valid(l) and not l.is_queued_for_deletion():
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


func _stream_key(p: Vector3) -> Vector2i:
	var cs := layout.tile_size * float(STREAM_CHUNK_TILES)
	return Vector2i(floori(p.x / cs), floori(p.z / cs))


## Registers decor to be spawned only while the player is near `p`. `spawner` returns the nodes it created.
func _stream_add(p: Vector3, spawner: Callable) -> void:
	var k := _stream_key(p)
	if not _stream_specs.has(k):
		_stream_specs[k] = []
	(_stream_specs[k] as Array).append(spawner)


## Spawns decor in chunks within STREAM_RADIUS of `focus` and frees chunks beyond STREAM_RADIUS + 1.
func update_streaming(focus: Vector3, force: bool = false) -> void:
	if layout == null or _world_root == null or not is_instance_valid(_world_root):
		return
	var c := _stream_key(focus)
	if c == _stream_center and not force:
		return
	_stream_center = c
	for k in _stream_live.keys():
		var kk: Vector2i = k
		if maxi(absi(kk.x - c.x), absi(kk.y - c.y)) > STREAM_RADIUS + 1:
			for n in _stream_live[kk]:
				if is_instance_valid(n):
					n.queue_free()
			_stream_live.erase(kk)
	for dy in range(-STREAM_RADIUS, STREAM_RADIUS + 1):
		for dx in range(-STREAM_RADIUS, STREAM_RADIUS + 1):
			var k := c + Vector2i(dx, dy)
			if _stream_live.has(k) or not _stream_specs.has(k):
				continue
			var live: Array = []
			for sp in _stream_specs[k]:
				live.append_array((sp as Callable).call())
			_stream_live[k] = live
	_prune_lights()
	update_light_budget()


func _prune_lights() -> void:
	_managed_lights = _managed_lights.filter(func(l: OmniLight3D) -> bool: return is_instance_valid(l) and not l.is_queued_for_deletion())
	_flicker_lights = _flicker_lights.filter(func(f: Dictionary) -> bool:
		var l: OmniLight3D = f["light"]
		return is_instance_valid(l) and not l.is_queued_for_deletion())


func streamed_chunk_count() -> int:
	return _stream_live.size()


func _process(delta: float) -> void:
	if _light_focus != null and is_instance_valid(_light_focus) and _light_focus.is_inside_tree():
		update_streaming(_light_focus.global_position)
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
	# Floating sanctuary ward crystal gently hovers and rotates inside its bronze cradle
	if _beacon_crystal != null and is_instance_valid(_beacon_crystal):
		_beacon_crystal.position.y = _beacon_base_y + sin(_flicker_time * 1.8) * 0.055
		_beacon_crystal.rotation.y = fmod(_beacon_crystal.rotation.y + delta * 0.55, TAU)
	# Safe Room merchant greets nearby players with his expressive talk animation
	if vendor_visual != null and is_instance_valid(vendor_visual) and _light_focus != null and is_instance_valid(_light_focus):
		var vdist := vendor_visual.global_position.distance_to(_light_focus.global_position)
		vendor_visual.play_state("talk" if vdist <= 4.8 else "idle", 0.35)
	# Physics-driven gates: heavy gravity slam + metallic bounce on close; weighted winch ease on open
	for gate in _gate_targets.keys():
		if is_instance_valid(gate):
			var visual := (gate as Node3D).get_node_or_null("GateVisual") as Node3D
			if visual != null:
				var target_y: float = float(_gate_targets[gate])
				var vel: float = float(_gate_vels.get(gate, 0.0))
				var diff := target_y - visual.position.y
				if target_y <= 0.05:
					# Slamming down under gravity with a small damped iron floor bounce
					if absf(diff) > 0.002 or absf(vel) > 0.05:
						vel -= 28.0 * delta
						visual.position.y += vel * delta
						if visual.position.y <= target_y:
							visual.position.y = target_y
							if absf(vel) > 1.8:
								vel = -vel * 0.22
							else:
								vel = 0.0
				else:
					# Heavy iron chain winch raising smoothly with inertia ramp & ease-out
					if absf(diff) > 0.003:
						var desired_spd := clampf(diff * 2.6, 0.4, 3.8)
						vel = move_toward(vel, desired_spd, delta * 9.0)
						visual.position.y = minf(target_y, visual.position.y + vel * delta)
					else:
						visual.position.y = target_y
						vel = 0.0
				_gate_vels[gate] = vel


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
	brazier_count = 0
	_batches.clear()
	_occluder_verts = PackedVector3Array()
	_occluder_idx = PackedInt32Array()
	_reserved_tiles.clear()
	_tile_room.clear()
	_stream_specs.clear()
	_stream_live.clear()
	_stream_center = Vector2i(-99999, -99999)
	_hwall_runs.clear()
	_vwall_runs.clear()

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
	# One infinite floor plane and one ceiling plane replace per-tile slabs: walls enclose every walkable tile,
	# so nothing can reach the void around the labyrinth (vast floors would otherwise need ~30k slab colliders)
	for plane_def in [[Plane(Vector3.UP, 0.0), "FloorPlane"], [Plane(Vector3.DOWN, -wall_h), "CeilingPlane"]]:
		var pcol := CollisionShape3D.new()
		pcol.name = str(plane_def[1])
		var wb := WorldBoundaryShape3D.new()
		wb.plane = plane_def[0]
		pcol.shape = wb
		_static_world.add_child(pcol)
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
	var stairs_centers: Dictionary = {}
	for sid in layout.stairs_room_ids:
		stairs_centers[layout.rooms[sid]["center"]] = true
	if layout.stairs_room_id >= 0:
		stairs_centers[layout.rooms[layout.stairs_room_id]["center"]] = true

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
			if not stairs_centers.has(t):
				_batch(KIT + FLOOR_VARIANTS[rng.next_int_range("gen", 0, 2)] + ".glb", t, Transform3D(Basis(Vector3.UP, spin), pos))
			var ceil_name := "ceiling_b" if rng.next_float("gen") < 0.08 else "ceiling_a"
			_batch(KIT + ceil_name + ".glb", t, Transform3D(Basis(Vector3.UP, spin), pos))

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
					# Wall colliders are merged into long runs per boundary line after the loop
					if d.y != 0:
						var line_y := t.y + (1 if d.y > 0 else 0)
						if not _hwall_runs.has(line_y):
							_hwall_runs[line_y] = []
						(_hwall_runs[line_y] as Array).append(t.x)
					else:
						var line_x := t.x + (1 if d.x > 0 else 0)
						if not _vwall_runs.has(line_x):
							_vwall_runs[line_x] = []
						(_vwall_runs[line_x] as Array).append(t.y)
					_add_occluder_quad(w_pos + inward * -0.05, basis, ts, wall_h + 0.3)
				elif (d == Vector2i(1, 0) or d == Vector2i(0, 1)) and _is_room_tile(tile) != _is_room_tile(layout.get_tile(n.x, n.y)):
					_place_arch(w_pos, rot_y)

	_build_wall_colliders(ts, wall_h)

	# Choose wall variants: torch slots stay plain; a few niches & damaged walls add storytelling
	var torch_slots: Array[Dictionary] = []
	for i in range(wall_slots.size()):
		var s: Dictionary = wall_slots[i]
		var t: Vector2i = s["tile"]
		var is_room := _is_room_tile(int(s["tile_type"]))
		var want_torch := false
		# Dense torch lines (brighter dungeon pass): roughly every other wall in rooms and corridors
		if is_room:
			want_torch = (t.x * 3 + t.y * 5 + i) % 2 == 0
		else:
			want_torch = (t.x + t.y) % 2 == 0
		if want_torch:
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
					layout.blocked_corners[Vector2i(px if px == rect.position.x + 1 else px + 1, py if py == rect.position.y + 1 else py + 1)] = true
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

	# Brighter dungeon pass: standing fire braziers in room corners and a soft overhead fill in every room
	for room in layout.rooms:
		_light_room(room, torch_color, rng)

	# Index wall slots by room once (each room used to scan every slot on the floor: O(rooms x walls))
	var slots_by_room: Dictionary = {}
	for ws in wall_slots:
		var wr: Dictionary = ws["room"]
		if wr.is_empty():
			continue
		var wid := int(wr["id"])
		if not slots_by_room.has(wid):
			slots_by_room[wid] = []
		(slots_by_room[wid] as Array).append(ws)

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
		var room_slots: Array[Dictionary] = []
		room_slots.assign(slots_by_room.get(int(room["id"]), []))
		_dress_room(room, room_slots, rng)
		_add_room_atmosphere(room)

	boss_gate_node = _build_gate(layout.boss_gate_tile, "BossGate", PROPS + "boss_gate.glb", false)
	vault_gate_node = _build_gate(layout.vault_gate_tile, "VaultGate", PROPS + "vault_gate.glb", true)

	for idx in range(layout.chests.size()):
		var c: Dictionary = layout.chests[idx]
		var wpos := layout.tile_to_world(c["tile"])
		var tier := str(c.get("tier", "standard"))
		var label := "Open Vault Treasure Chest" if tier == "vault_legendary" else "Open Iron-Bound Chest"
		var inter := InteractableObject.new()
		inter.setup("chest_%d" % idx, "chest", label, c, interact_cb, Vector3(1.2, 1.0, 0.85))
		inter.position = wpos
		inter.rotation.y = _face_room_center(c["tile"])
		var model := ModelLoader.instantiate_model(PROPS + "chest.glb", Vector3(1.1, 0.8, 0.7))
		inter.add_child(model)
		inter.visual_root = model
		if tier == "vault_legendary":
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


## One box per straight run of wall along each tile boundary line (instead of one box per 4 m segment).
func _build_wall_colliders(ts: float, wall_h: float) -> void:
	for horizontal in [true, false]:
		var runs: Dictionary = _hwall_runs if horizontal else _vwall_runs
		for line in runs.keys():
			var cells: Array = runs[line]
			cells.sort()
			var i := 0
			while i < cells.size():
				var j := i
				while j + 1 < cells.size() and int(cells[j + 1]) == int(cells[j]) + 1:
					j += 1
				var a := float(cells[i])
				var n := float(int(cells[j]) - int(cells[i]) + 1)
				var mid := (a + n * 0.5) * ts
				var edge := float(line) * ts
				if horizontal:
					_add_box_collider(_static_world, Vector3(mid, wall_h * 0.5, edge), Vector3(n * ts, wall_h, 0.65))
				else:
					_add_box_collider(_static_world, Vector3(edge, wall_h * 0.5, mid), Vector3(0.65, wall_h, n * ts))
				i = j + 1


# ---------------------------------------------------------------------------
# Test Mode spawning (D-047)
# ---------------------------------------------------------------------------
const TEST_OBJECTS := ["chest", "rare_chest", "vault_chest", "crate", "urn", "lever", "spike_trap", "brazier",
	"torch_light", "stairs", "safe_room_kit", "setpiece:entrance", "setpiece:safe_room", "setpiece:boss_arena",
	"setpiece:vault", "setpiece:stairs"]
var _test_counter: int = 0


## Spawns any world object / room kit at `pos` (Test Mode). Returns the main node created.
func spawn_test_object(kind: String, pos: Vector3, yaw: float, interact_cb: Callable) -> Node3D:
	_test_counter += 1
	var tid := "test_%s_%d" % [kind.replace(":", "_"), _test_counter]
	match kind:
		"chest", "rare_chest", "vault_chest":
			var tier: String = {"chest": "standard", "rare_chest": "rare", "vault_chest": "vault_legendary"}[kind]
			var inter := InteractableObject.new()
			inter.setup(tid, "chest", "Open Vault Treasure Chest" if tier == "vault_legendary" else "Open Iron-Bound Chest",
				{"tier": tier}, interact_cb, Vector3(1.2, 1.0, 0.85))
			inter.position = pos
			inter.rotation.y = yaw
			var model := ModelLoader.instantiate_model(PROPS + "chest.glb", Vector3(1.1, 0.8, 0.7))
			inter.add_child(model)
			inter.visual_root = model
			_world_root.add_child(inter)
			return inter
		"crate", "urn":
			var c := InteractableObject.new()
			c.setup(tid, kind, "Search %s" % ("Supply Crate" if kind == "crate" else "Burial Urn"), {}, interact_cb, Vector3(0.95, 1.0, 0.95))
			c.position = pos
			c.rotation.y = yaw
			var cm := ModelLoader.instantiate_model(PROPS + kind + ".glb", Vector3(0.9, 0.9, 0.9))
			c.add_child(cm)
			c.visual_root = cm
			_world_root.add_child(c)
			return c
		"lever":
			var lv := InteractableObject.new()
			lv.setup(tid, "lever", "Pull Trap Disarm Lever", {}, interact_cb, Vector3(0.6, 1.4, 0.6))
			lv.position = pos
			lv.rotation.y = yaw
			var lm := ModelLoader.instantiate_model(PROPS + "lever.glb", Vector3(0.6, 1.5, 0.6))
			lv.add_child(lm)
			lv.visual_root = lm
			_world_root.add_child(lv)
			return lv
		"spike_trap":
			var tile := layout.world_to_tile(pos)
			layout.traps.append(tile)
			var trap := ModelLoader.instantiate_model(PROPS + "spike_trap.glb", Vector3(1.8, 0.4, 1.8))
			trap.position = layout.tile_to_world(tile) + Vector3(0.0, 0.02, 0.0)
			_world_root.add_child(trap)
			_trap_nodes.append(trap)
			traps_disarmed = false
			return trap
		"brazier":
			var nodes := _spawn_brazier(pos, yaw, Color(1.0, 0.62, 0.3), 0.0)
			_add_box_collider(_static_world, pos + Vector3(0.0, 0.5, 0.0), Vector3(0.9, 1.0, 0.9))
			update_light_budget()
			return nodes[0]
		"torch_light":
			var l := _add_light(_world_root, pos + Vector3(0.0, 2.4, 0.0), Color(1.0, 0.7, 0.4), 2.2, 11.5, true)
			update_light_budget()
			return l
		"stairs":
			_build_stairs_interactable(pos, interact_cb)
			return _world_root.get_child(_world_root.get_child_count() - 2) as Node3D
		"safe_room_kit":
			_build_safe_room_interactables(pos, Color.html(str(_floor_cfg.get("safe_zone_color", "#45e6b8"))), interact_cb)
			return _world_root.get_child(_world_root.get_child_count() - 1) as Node3D
	if kind.begins_with("setpiece:"):
		var key := kind.substr(9)
		var map: Dictionary = DataLoader.get_setpieces_pack().get("setpieces", {})
		if map.has(key):
			_apply_handcrafted_setpiece(map[key], pos, SeededRng.new(_test_counter))
			update_light_budget()
			return _world_root.get_child(_world_root.get_child_count() - 1) as Node3D
	return null


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
			var cc := Vector3((float(chunk.x) + 0.5) * CHUNK_TILES * layout.tile_size, 0.0, (float(chunk.y) + 0.5) * CHUNK_TILES * layout.tile_size)
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = xfs.size()
			for i in range(xfs.size()):
				var xf: Transform3D = xfs[i]
				mm.set_instance_transform(i, Transform3D(xf.basis, xf.origin - cc))
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "%s_%d_%d" % [str(path).get_file().get_basename(), chunk.x, chunk.y]
			mmi.multimesh = mm
			mmi.position = cc
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			# Vast floors: chunks far beyond the fog are not drawn at all
			mmi.visibility_range_end = ARCH_VISIBILITY_RANGE
			mmi.visibility_range_end_margin = 12.0
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


## Lights a room: a soft, shadowless overhead fill so the middle never sinks to black, plus fire braziers in the
## corners of ordinary rooms (two in small rooms, four in larger ones; corners next to a doorway or already
## reserved are skipped). Setpiece rooms (entrance, safe, boss, vault, stairs) keep their handcrafted braziers.
func _light_room(room: Dictionary, torch_color: Color, rng: SeededRng) -> void:
	var role := str(room["role"])
	var rect: Rect2i = room["rect"]
	var center_w := layout.tile_to_world(room["center"])
	var area := rect.size.x * rect.size.y
	var fill_e := 0.9 if area >= 25 else 0.7
	_stream_add(center_w, _spawn_room_fill.bind(center_w + Vector3(0.0, 3.7, 0.0), torch_color.lerp(Color(1.0, 0.9, 0.78), 0.5), fill_e,
		maxf(10.0, float(maxi(rect.size.x, rect.size.y)) * 2.6)))
	if role in ["safe", "boss", "vault", "entrance", "stairs"]:
		return  # these rooms have handcrafted setpieces with their own braziers
	var ts := layout.tile_size
	var corners := [rect.position, Vector2i(rect.end.x - 1, rect.end.y - 1)]
	if rect.size.x >= 4 and rect.size.y >= 4:
		corners += [Vector2i(rect.end.x - 1, rect.position.y), Vector2i(rect.position.x, rect.end.y - 1)]
	for c in corners:
		var t: Vector2i = c
		if _reserved_tiles.has(t) or _tile_near_opening(t):
			continue
		var dx := -1.0 if t.x == rect.position.x else 1.0
		var dz := -1.0 if t.y == rect.position.y else 1.0
		var pos := layout.tile_to_world(t) + Vector3(dx, 0.0, dz) * (ts * 0.5 - 0.95)
		_add_box_collider(_static_world, pos + Vector3(0.0, 0.5, 0.0), Vector3(0.9, 1.0, 0.9))
		_stream_add(pos, _spawn_brazier.bind(pos, rng.next_float("gen") * TAU, torch_color, rng.next_float("gen") * TAU))
		_reserved_tiles[t] = true
		brazier_count += 1


func _spawn_room_fill(pos: Vector3, col: Color, energy: float, rng_m: float) -> Array:
	var fill := _add_light(_world_root, pos, col, energy, rng_m, false)
	fill.set_meta("can_shadow", false)
	fill.light_volumetric_fog_energy = 0.3
	return [fill]


func _spawn_brazier(pos: Vector3, rot_y: float, col: Color, phase: float) -> Array:
	var braz := ModelLoader.instantiate_model(PROPS + "brazier.glb", Vector3(1.0, 1.0, 1.0))
	braz.position = pos
	braz.rotation.y = rot_y
	_world_root.add_child(braz)
	var socket := braz.find_child("FlameSocket*", true, false) as Node3D
	var fpos := braz.transform * socket.position if socket != null else pos + Vector3(0.0, 1.0, 0.0)
	var fire := VfxFactory.make_fire(1.1)
	fire.position = fpos
	_world_root.add_child(fire)
	var bl := _add_light(_world_root, fpos + Vector3(0.0, 0.35, 0.0), col, 2.0, 11.0, true, phase)
	bl.set_meta("can_shadow", false)
	return [braz, fire, bl]


func _place_torch(slot: Dictionary, torch_color: Color, rng: SeededRng) -> void:
	var col := torch_color
	if int(slot["tile_type"]) == DungeonGenerator.TILE_BOSS_FLOOR:
		col = Color(1.0, 0.5, 0.3)
	var inward: Vector3 = slot["inward"]
	_stream_add(slot["pos"], _spawn_torch.bind(slot["pos"] + inward * 0.30 + Vector3(0.0, 2.15, 0.0), float(slot["rot_y"]), inward, col,
		rng.next_float("gen") * TAU))


func _spawn_torch(mount: Vector3, rot_y: float, inward: Vector3, col: Color, phase: float) -> Array:
	var sconce := ModelLoader.instantiate_model(PROPS + "torch_sconce.glb", Vector3(0.2, 0.6, 0.3))
	sconce.position = mount
	sconce.rotation.y = rot_y
	_world_root.add_child(sconce)
	var socket := sconce.find_child("FlameSocket*", true, false) as Node3D
	var flame_local := socket.position if socket != null else Vector3(0.0, 0.55, 0.42)
	var flame_pos := sconce.transform * flame_local
	var fire := VfxFactory.make_fire(0.55)
	fire.position = flame_pos
	_world_root.add_child(fire)
	var light := _add_light(_world_root, flame_pos + inward * 0.25 + Vector3(0, 0.1, 0), col, 2.2, 11.5, true, phase)
	light.set_meta("can_shadow", true)
	return [sconce, fire, light]


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
	var density := float(DataLoader.get_world().get("labyrinth", {}).get("ambient_prop_density", 0.42))
	var chance := density if role != "boss" else density * 0.6
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
		if DRESSING_COLLIDE.has(kind):
			layout.nav_weights[t] = maxf(float(layout.nav_weights.get(t, 1.0)), 3.0 if kind in ["sarcophagus", "table", "weapon_rack"] else 2.0)
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
	_stream_add(p, _spawn_dressing_visual.bind(kind, p, rot))
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


func _spawn_dressing_visual(kind: String, p: Vector3, rot: float) -> Array:
	var n := ModelLoader.instantiate_model(PROPS + kind + ".glb")
	n.position = p
	n.rotation.y = rot
	_world_root.add_child(n)
	var out: Array = [n]
	if kind == "candle_cluster":
		var l := _add_light(_world_root, p + Vector3(0, 0.45, 0), Color(1.0, 0.7, 0.4), 0.55, 3.5, true, p.x)
		l.set_meta("can_shadow", false)
		out.append(l)
	return out


func _tile_near_opening(t: Vector2i) -> bool:
	var tt := layout.get_tile(t.x, t.y)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = t + d
		var nt := layout.get_tile(n.x, n.y)
		if nt != DungeonGenerator.TILE_VOID and _is_room_tile(nt) != _is_room_tile(tt):
			return true
	return false


func _add_room_atmosphere(room: Dictionary) -> void:
	_stream_add(layout.tile_to_world(room["center"]), _spawn_room_atmosphere.bind(room))


func _spawn_room_atmosphere(room: Dictionary) -> Array:
	var out: Array = []
	var rect: Rect2i = room["rect"]
	var ts := layout.tile_size
	var c := layout.tile_to_world(room["center"])
	var extent := Vector3(float(rect.size.x) * ts - 1.0, 3.2, float(rect.size.y) * ts - 1.0)
	var dust := VfxFactory.make_dust(extent)
	var origin := layout.tile_to_world(rect.position) - Vector3(ts * 0.5, 0, ts * 0.5)
	if dust != null:
		dust.position = origin + Vector3(float(rect.size.x) * ts * 0.5, 2.0, float(rect.size.y) * ts * 0.5)
		_world_root.add_child(dust)
		out.append(dust)
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
		out.append(web)
	return out


# ---------------------------------------------------------------------------
# Interactables & gates
# ---------------------------------------------------------------------------

func _build_safe_room_interactables(center_w: Vector3, ward_color: Color, interact_cb: Callable) -> void:
	_add_light(_world_root, center_w + Vector3(0.0, 3.6, 0.8), Color(1.0, 0.8, 0.55), 1.4, 16.0, false)
	var beacon := ModelLoader.instantiate_model(PROPS + "safe_beacon.glb", Vector3(1.0, 2.0, 1.0))
	beacon.position = center_w + Vector3(0.3, 0.0, -3.1)
	_world_root.add_child(beacon)
	_beacon_crystal = beacon.find_child("Crystal*", true, false) as Node3D
	if _beacon_crystal != null:
		_beacon_base_y = _beacon_crystal.position.y
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
	vendor_visual = npc
	var socket := stall.find_child("LanternSocket*", true, false) as Node3D
	if socket != null:
		var ll := _add_light(vendor, Basis(Vector3.UP, PI) * socket.position + Vector3(0, -0.05, 0), Color(1.0, 0.72, 0.4), 1.1, 6.0, true)
		ll.set_meta("can_shadow", false)
	_world_root.add_child(vendor)
	spawned_setpiece_props += 1

	var qboard := InteractableObject.new()
	# FB-022: the board is the safe room's map of the surrounding area (studying it updates the player's map)
	qboard.setup("safe_area_map", "area_map", "Study the Map of the Surrounding Area", {}, interact_cb, Vector3(2.2, 2.4, 0.9))
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
				tw.tween_property(tn, "position:y", tn.position.y - 0.36, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
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
	_beacon_crystal = null
	vendor_visual = null
	_trap_nodes.clear()
	_flicker_lights.clear()
	_managed_lights.clear()
	_gate_targets.clear()
	_gate_vels.clear()
	_stream_specs.clear()
	_stream_live.clear()
	_stream_center = Vector2i(-99999, -99999)


func _set_gate_closed(gate: StaticBody3D, closed: bool, instant: bool) -> void:
	var visual := gate.get_node_or_null("GateVisual") as Node3D
	var col := gate.get_node_or_null("GateCollider") as CollisionShape3D
	var target_y := 0.0 if closed else 3.9
	_gate_targets[gate] = target_y
	_gate_vels[gate] = 0.0
	if visual != null and instant:
		visual.position.y = target_y
	if col != null:
		col.disabled = not closed
	# Belt and braces: an open gate also leaves every collision layer, so no physics backend can keep it solid
	gate.collision_layer = 1 if closed else 0


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
	env.ambient_light_color = amb.lerp(Color(0.46, 0.42, 0.40), 0.7)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.2 * (float(GameSettings.get_value("graphics", "brightness")) if GameSettings != null else 1.0)
	env.tonemap_white = 4.0
	# Depth fog keeps distant corridors mysterious on every quality level
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = fog_col.lerp(Color(0.05, 0.06, 0.085), 0.6)
	env.fog_light_energy = 1.0
	env.fog_density = 0.011
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
		env.volumetric_fog_density = 0.008
		env.volumetric_fog_albedo = Color(0.55, 0.55, 0.58)
		env.volumetric_fog_emission = Color(0.0, 0.0, 0.0)
		env.volumetric_fog_anisotropy = 0.45
		env.volumetric_fog_length = 40.0
		env.volumetric_fog_detail_spread = 2.0
		env.volumetric_fog_gi_inject = 0.3
		env.volumetric_fog_ambient_inject = 0.0
		env.volumetric_fog_temporal_reprojection_enabled = true
		env.fog_density = 0.005
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
		env.ambient_light_energy = 0.65
	return env


static func _add_box_collider(body: StaticBody3D, pos: Vector3, size: Vector3) -> void:
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position = pos
	body.add_child(col)
