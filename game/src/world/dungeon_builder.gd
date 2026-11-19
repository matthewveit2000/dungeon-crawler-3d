class_name DungeonBuilder
extends Node3D
## 3D Procedural + Handcrafted Setpiece Nordic-Ruin Scene Builder (Phase 4, 6 & D-029).
## Stitches procedural dungeon layouts with curated handcrafted setpiece rooms from
## game/data/setpieces.json (Entrance Arrival Hall, Warm Safe Room Sanctuary,
## Iron Warden Boss Crucible with Dais & Braziers, Gilded Treasure Vault, Hidden Stairwell),
## complete with ACES Filmic lighting, flickering firelight, hanging crimson banners,
## and smoothly animated iron/gilded gates.

var layout: DungeonGenerator.FloorLayout = null
var boss_gate_node: StaticBody3D = null
var vault_gate_node: StaticBody3D = null
var boss_arena_sealed: bool = false
var vault_unlocked: bool = false
var traps_disarmed: bool = false
var spawned_setpiece_props: int = 0

var _trap_nodes: Array[Node3D] = []
var _world_root: Node3D = null
var _flicker_lights: Array[Dictionary] = []
var _managed_lights: Array[OmniLight3D] = []
var _light_focus: Node3D = null
var _gate_targets: Dictionary = {}
var _flicker_time: float = 0.0
const MAX_ACTIVE_WORLD_OMNI_LIGHTS: int = 6


func set_light_focus_target(target: Node3D) -> void:
	_light_focus = target
	update_light_budget()


func update_light_budget() -> void:
	# OpenGL3 Compatibility allows at most 8 OmniLight3D nodes per surface.
	# Reserve 2 slots for player camera/spell lights and activate the 6 closest world lights!
	var valid_lights: Array[OmniLight3D] = []
	for l in _managed_lights:
		if is_instance_valid(l):
			valid_lights.append(l)
	if valid_lights.size() <= MAX_ACTIVE_WORLD_OMNI_LIGHTS:
		for l in valid_lights:
			l.visible = true
		return
	var focus_pos := _light_focus.global_position if (_light_focus != null and is_instance_valid(_light_focus)) else Vector3.ZERO
	var ranked: Array[Dictionary] = []
	for l in valid_lights:
		var d2 := l.global_position.distance_squared_to(focus_pos)
		ranked.append({"light": l, "d2": d2})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["d2"]) < float(b["d2"]))
	for i in range(ranked.size()):
		var light_node: OmniLight3D = ranked[i]["light"]
		light_node.visible = (i < MAX_ACTIVE_WORLD_OMNI_LIGHTS)


func _process(delta: float) -> void:
	_flicker_time += delta
	update_light_budget()
	# Subtle atmospheric torch & brazier firelight flicker
	for fl in _flicker_lights:
		var light: OmniLight3D = fl["light"]
		if is_instance_valid(light) and light.visible:
			var base_e: float = float(fl["base"])
			var ph: float = float(fl["phase"])
			var wave := sin(_flicker_time * 6.4 + ph) * 0.055 + sin(_flicker_time * 13.7 + ph * 1.9) * 0.035
			light.light_energy = base_e * (1.0 + wave)

	# Smoothly animate portcullis & gilded vault doors
	for gate in _gate_targets.keys():
		if is_instance_valid(gate):
			var visual := (gate as Node3D).get_node_or_null("GateVisual") as Node3D
			if visual != null:
				var target_y: float = float(_gate_targets[gate])
				visual.position.y = lerpf(visual.position.y, target_y, clampf(delta * 7.5, 0.0, 1.0))


func build_floor(
	p_layout: DungeonGenerator.FloorLayout,
	floor_cfg: Dictionary,
	interact_cb: Callable,
	rng: SeededRng
) -> void:
	clear_floor()
	layout = p_layout
	boss_arena_sealed = false
	vault_unlocked = false
	traps_disarmed = false
	spawned_setpiece_props = 0
	_trap_nodes.clear()
	_flicker_lights.clear()
	_managed_lights.clear()
	_gate_targets.clear()

	_world_root = Node3D.new()
	_world_root.name = "DungeonGeometry"
	add_child(_world_root)

	_setup_environment(floor_cfg)

	var ts := layout.tile_size
	var wall_h := float(DataLoader.get_world()["grid"]["wall_height_meters"])
	var torch_color := Color.html(str(floor_cfg.get("torch_color", "#ffa34d")))
	var safe_ward_color := Color.html(str(floor_cfg.get("safe_zone_color", "#45e6b8")))
	var boss_rim_color := Color.html(str(floor_cfg.get("boss_color", "#e04838")))

	# Single static body for fast floor/ceiling/wall collision
	var static_world := StaticBody3D.new()
	static_world.name = "WorldColliders"
	static_world.collision_layer = 1
	static_world.collision_mask = 1
	_world_root.add_child(static_world)

	var floor_visuals := Node3D.new()
	floor_visuals.name = "Tiles"
	_world_root.add_child(floor_visuals)

	var wall_dirs := [
		{"d": Vector2i(0, -1), "rot_y": 0.0, "off": Vector3(0.0, 0.0, -ts * 0.5)},
		{"d": Vector2i(0, 1), "rot_y": PI, "off": Vector3(0.0, 0.0, ts * 0.5)},
		{"d": Vector2i(-1, 0), "rot_y": PI * 0.5, "off": Vector3(-ts * 0.5, 0.0, 0.0)},
		{"d": Vector2i(1, 0), "rot_y": -PI * 0.5, "off": Vector3(ts * 0.5, 0.0, 0.0)},
	]

	var torch_count := 0
	var banner_count := 0
	for y in range(layout.height):
		for x in range(layout.width):
			var tile := layout.get_tile(x, y)
			if tile == DungeonGenerator.TILE_VOID:
				continue
			var pos := layout.tile_to_world(Vector2i(x, y))

			# Carved flagstone floor + collider
			var f_mesh := ModelLoader.instantiate_model("res://assets/models/batch1/floor_tile.glb", Vector3(ts, 0.2, ts))
			f_mesh.position = pos
			floor_visuals.add_child(f_mesh)
			_add_box_collider(static_world, pos + Vector3(0.0, -0.25, 0.0), Vector3(ts, 0.5, ts))

			# Vaulted stone ceiling seated flush against top wall cornice (zero dark seam!)
			var c_mesh := ModelLoader.instantiate_model("res://assets/models/batch1/ceiling_tile.glb", Vector3(ts, 0.3, ts))
			c_mesh.position = pos + Vector3(0.0, wall_h - 0.08, 0.0)
			floor_visuals.add_child(c_mesh)
			_add_box_collider(static_world, pos + Vector3(0.0, wall_h + 0.25, 0.0), Vector3(ts, 0.5, ts))

			# Perimeter Nordic ashlar walls wherever neighbor is void
			for wd in wall_dirs:
				var d: Vector2i = wd["d"]
				if not layout.is_walkable(x + d.x, y + d.y):
					var w_pos: Vector3 = pos + wd["off"]
					var rot_y: float = float(wd["rot_y"])
					var w_mesh := ModelLoader.instantiate_model("res://assets/models/batch1/wall_segment.glb", Vector3(ts, wall_h, 0.55))
					w_mesh.position = w_pos
					w_mesh.rotation.y = rot_y
					w_mesh.scale = Vector3(1.0, 1.12, 1.0)
					floor_visuals.add_child(w_mesh)

					var col_size := Vector3(ts, wall_h, 0.65) if d.y != 0 else Vector3(0.65, wall_h, ts)
					_add_box_collider(static_world, w_pos + Vector3(0.0, wall_h * 0.5, 0.0), col_size)

					var inward := Vector3(-float(d.x), 0.0, -float(d.y))
					# Warm flickering wall torch sconces
					if (x + y) % 4 == 0 and torch_count < 24 and rng.next_float("gen") < 0.45:
						var sconce := ModelLoader.instantiate_model("res://assets/models/batch1/torch_sconce.glb", Vector3(0.3, 0.8, 0.3))
						sconce.position = w_pos + inward * 0.34 + Vector3(0.0, 2.35, 0.0)
						sconce.rotation.y = rot_y
						floor_visuals.add_child(sconce)
						var t_col := torch_color
						if tile == DungeonGenerator.TILE_BOSS_FLOOR:
							t_col = Color(1.0, 0.72, 0.42)
						var light := _add_flicker_light(
							floor_visuals,
							w_pos + inward * 0.85 + Vector3(0.0, 2.75, 0.0),
							t_col,
							2.5,
							12.0,
							rng.next_float("gen") * TAU
						)
						light.shadow_enabled = false
						torch_count += 1
					# Hanging crimson & gold Nordic banners on major walls for architectural grandeur
					elif (x * 3 + y * 5) % 9 == 0 and banner_count < 16 and rng.next_float("gen") < 0.55:
						var banner := ModelLoader.instantiate_model("res://assets/models/batch1/wall_banner.glb", Vector3(1.2, 2.2, 0.2))
						banner.position = w_pos + inward * 0.36 + Vector3(0.0, 0.85, 0.0)
						banner.rotation.y = rot_y + PI
						floor_visuals.add_child(banner)
						banner_count += 1

	# Handcrafted Setpieces stitched into procedural rooms (D-029)
	var setpieces_pack := DataLoader.get_setpieces_pack()
	var setpieces_map: Dictionary = setpieces_pack.get("setpieces", {})

	for room in layout.rooms:
		var role := str(room["role"])
		var rect: Rect2i = room["rect"]
		var center_w := layout.tile_to_world(room["center"])

		# Corner Nordic octagonal pillars in large rooms
		if rect.size.x >= 5 and rect.size.y >= 5:
			for px in [rect.position.x + 1, rect.end.x - 2]:
				for py in [rect.position.y + 1, rect.end.y - 2]:
					var pil_pos := layout.tile_to_world(Vector2i(px, py))
					var pil := ModelLoader.instantiate_model("res://assets/models/batch1/pillar.glb", Vector3(1.0, wall_h, 1.0))
					pil.position = pil_pos
					floor_visuals.add_child(pil)
					_add_box_collider(static_world, pil_pos + Vector3(0.0, wall_h * 0.5, 0.0), Vector3(0.95, wall_h, 0.95))

		# Map room role -> handcrafted setpiece blueprint ID
		var sp_key := role
		if role == "safe":
			sp_key = "safe_room"
		elif role == "boss":
			sp_key = "boss_arena"
		if setpieces_map.has(sp_key):
			_apply_handcrafted_setpiece(setpieces_map[sp_key], center_w, rng)

		if role == "safe":
			_build_safe_room_interactables(center_w, safe_ward_color, interact_cb)
		elif role == "stairs":
			_build_stairs_interactable(center_w, interact_cb)
		elif role == "boss":
			# Dramatic 3-point Boss Crucible lighting so the towering 3m Iron Warden steel gleams!
			_add_managed_light(_world_root, center_w + Vector3(0.0, 3.55, 3.4), Color(1.0, 0.84, 0.62), 4.6, 22.0)
			_add_managed_light(_world_root, center_w + Vector3(-3.6, 3.1, 0.6), Color(1.0, 0.66, 0.34), 3.0, 16.0)
			_add_managed_light(_world_root, center_w + Vector3(3.6, 3.1, 0.6), Color(1.0, 0.66, 0.34), 3.0, 16.0)
			_add_managed_light(_world_root, center_w + Vector3(0.0, 3.3, -4.0), boss_rim_color, 3.2, 18.0)
		elif role == "entrance":
			_add_managed_light(_world_root, center_w + Vector3(0.0, 3.55, 0.0), Color(1.0, 0.86, 0.66), 3.2, 18.0)

	# Boss Gate (iron portcullis — open initially, slams shut on threshold!)
	boss_gate_node = _build_gate(layout.boss_gate_tile, "BossGate", "res://assets/models/batch1/boss_gate.glb", false)
	# Treasure Vault Gate (ornate gilded doors — sealed until Boss defeated!)
	vault_gate_node = _build_gate(layout.vault_gate_tile, "VaultGate", "res://assets/models/batch1/vault_gate.glb", true)

	# Interactive Chests
	for idx in range(layout.chests.size()):
		var c: Dictionary = layout.chests[idx]
		var wpos := layout.tile_to_world(c["tile"])
		var tier := str(c.get("tier", "standard"))
		var label := "Open Vault Treasure Chest" if tier == "vault_sponsored" else "Open Nordic Chest"
		var inter := InteractableObject.new()
		inter.setup("chest_%d" % idx, "chest", label, c, interact_cb, Vector3(1.3, 1.0, 0.9))
		inter.position = wpos
		inter.add_child(ModelLoader.instantiate_model("res://assets/models/batch1/chest.glb", Vector3(1.1, 0.8, 0.7)))
		if tier == "vault_sponsored":
			_add_managed_light(inter, Vector3(0.0, 1.4, 0.0), Color(1.0, 0.82, 0.34), 2.4, 9.0)
		_world_root.add_child(inter)

	# Interactive Crates & Urns
	for idx in range(layout.containers.size()):
		var cont: Dictionary = layout.containers[idx]
		var kind := str(cont.get("kind", "crate"))
		var wpos := layout.tile_to_world(cont["tile"]) + Vector3(-1.1, 0.0, -1.1)
		var inter := InteractableObject.new()
		inter.setup("cont_%d" % idx, kind, "Search %s" % kind.capitalize(), cont, interact_cb, Vector3(0.95, 1.0, 0.95))
		inter.position = wpos
		var mpath := "res://assets/models/batch1/crate.glb" if kind == "crate" else "res://assets/models/batch1/urn.glb"
		inter.add_child(ModelLoader.instantiate_model(mpath, Vector3(0.9, 0.9, 0.9)))
		_world_root.add_child(inter)

	# Spike Traps + Disarm Lever
	for idx in range(layout.traps.size()):
		var t_pos := layout.tile_to_world(layout.traps[idx])
		var trap_mesh := ModelLoader.instantiate_model("res://assets/models/batch1/spike_trap.glb", Vector3(1.8, 0.4, 1.8))
		trap_mesh.position = t_pos
		_world_root.add_child(trap_mesh)
		_trap_nodes.append(trap_mesh)

		if idx == 0:
			var lever := InteractableObject.new()
			lever.setup("trap_lever", "lever", "Pull Trap Disarm Lever", {}, interact_cb, Vector3(0.8, 1.5, 0.8))
			lever.position = t_pos + Vector3(1.5, 0.0, 0.0)
			lever.add_child(ModelLoader.instantiate_model("res://assets/models/batch1/lever.glb", Vector3(0.6, 1.5, 0.6)))
			_world_root.add_child(lever)

	update_light_budget()


func _apply_handcrafted_setpiece(sp_def: Dictionary, center_w: Vector3, rng: SeededRng) -> void:
	var props: Array = sp_def.get("props", [])
	for prop in props:
		var mpath := str(prop.get("model", ""))
		if mpath.is_empty():
			continue
		# Safe Room merchant stall is spawned inside _build_safe_room_interactables with its Vendor collider
		if mpath.ends_with("merchant_stall.glb"):
			continue
		var off: Array = prop.get("offset", [0.0, 0.0, 0.0])
		var p_node := ModelLoader.instantiate_model(mpath, Vector3(1.0, 1.0, 1.0))
		p_node.position = center_w + Vector3(float(off[0]), float(off[1]), float(off[2]))
		p_node.rotation.y = float(prop.get("rot_y", 0.0))
		if prop.has("scale"):
			var sc: Array = prop["scale"]
			p_node.scale = Vector3(float(sc[0]), float(sc[1]), float(sc[2]))
		_world_root.add_child(p_node)
		spawned_setpiece_props += 1

		if prop.has("light_color"):
			_add_flicker_light(
				_world_root,
				p_node.position + Vector3(0.0, 1.75, 0.0),
				Color.html(str(prop["light_color"])),
				float(prop.get("light_energy", 2.6)),
				float(prop.get("light_range", 13.0)),
				rng.next_float("gen") * TAU
			)


func _add_managed_light(parent: Node3D, pos: Vector3, col: Color, energy: float, rng_m: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng_m
	l.shadow_enabled = false
	parent.add_child(l)
	_managed_lights.append(l)
	return l


func _add_flicker_light(parent: Node3D, pos: Vector3, col: Color, energy: float, rng_m: float, phase: float) -> OmniLight3D:
	var l := _add_managed_light(parent, pos, col, energy, rng_m)
	_flicker_lights.append({"light": l, "base": energy, "phase": phase})
	return l


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
			tn.position.y = -0.38


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
	boss_gate_node = null
	vault_gate_node = null
	_trap_nodes.clear()
	_flicker_lights.clear()
	_managed_lights.clear()
	_gate_targets.clear()


func _build_safe_room_interactables(center_w: Vector3, ward_color: Color, interact_cb: Callable) -> void:
	# Warm cozy hearth key light + stall lantern + emerald sanctuary ward beacon (zero cyan wash!)
	_add_managed_light(_world_root, center_w + Vector3(0.0, 3.55, 1.2), Color(1.0, 0.86, 0.66), 4.0, 20.0)
	_add_managed_light(_world_root, center_w + Vector3(-2.1, 2.75, -0.5), Color(1.0, 0.80, 0.50), 2.8, 12.0)

	# Glowing Safe Room Sanctuary Ward Pedestal
	var beacon := ModelLoader.instantiate_model("res://assets/models/batch1/safe_beacon.glb", Vector3(1.6, 2.0, 1.6))
	beacon.position = center_w + Vector3(0.3, 0.0, -3.1)
	_world_root.add_child(beacon)
	spawned_setpiece_props += 1
	_add_managed_light(_world_root, beacon.position + Vector3(0.0, 1.85, 0.0), ward_color, 2.2, 9.5)

	# Handcrafted Merchant Stall + Friendly Robed Vendor NPC (counter faces into room!)
	var vendor := InteractableObject.new()
	vendor.setup("safe_vendor", "vendor", "Trade with Safe Room Merchant", {}, interact_cb, Vector3(2.8, 2.4, 2.0))
	vendor.position = center_w + Vector3(-2.6, 0.0, -2.0)
	vendor.rotation.y = PI + 0.26
	vendor.add_child(ModelLoader.instantiate_model("res://assets/models/batch1/merchant_stall.glb", Vector3(2.8, 2.8, 1.6)))
	var npc := ModelLoader.instantiate_model("res://assets/models/batch3/safe_room_vendor.glb", Vector3(0.9, 2.0, 0.9))
	npc.position = Vector3(0.0, 0.0, 0.38)
	npc.rotation.y = PI
	vendor.add_child(npc)
	_world_root.add_child(vendor)
	spawned_setpiece_props += 1

	# Syndicate Quest Board
	var qboard := InteractableObject.new()
	qboard.setup("safe_quest_board", "quest_board", "Inspect Syndicate Quest Board", {}, interact_cb, Vector3(2.0, 2.3, 0.9))
	qboard.position = center_w + Vector3(2.8, 0.0, -2.0)
	qboard.rotation.y = -0.25
	qboard.add_child(ModelLoader.instantiate_model("res://assets/models/batch1/quest_board.glb", Vector3(2.0, 2.3, 0.6)))
	_world_root.add_child(qboard)


func _build_stairs_interactable(center_w: Vector3, interact_cb: Callable) -> void:
	# D-008: Strictly NO next-floor preview text!
	var stairs := InteractableObject.new()
	stairs.setup("hidden_stairs", "stairs", "Descend Stairwell to Next Floor", {}, interact_cb, Vector3(3.4, 2.2, 3.4))
	stairs.position = center_w
	stairs.add_child(ModelLoader.instantiate_model("res://assets/models/batch1/staircase_down.glb", Vector3(3.5, 3.5, 3.5)))
	_world_root.add_child(stairs)
	_add_managed_light(_world_root, center_w + Vector3(0.0, 2.6, 0.0), Color(0.45, 0.80, 1.0), 2.8, 13.0)


func _build_gate(tile: Vector2i, gate_name: String, model_path: String, closed_initially: bool) -> StaticBody3D:
	var gate := StaticBody3D.new()
	gate.name = gate_name
	var wpos := layout.tile_to_world(tile)
	gate.position = wpos
	var left_open := layout.is_walkable(tile.x - 1, tile.y)
	var right_open := layout.is_walkable(tile.x + 1, tile.y)
	if left_open and right_open:
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


func _set_gate_closed(gate: StaticBody3D, closed: bool, instant: bool) -> void:
	var visual := gate.get_node_or_null("GateVisual") as Node3D
	var col := gate.get_node_or_null("GateCollider") as CollisionShape3D
	var target_y := 0.0 if closed else 3.85
	_gate_targets[gate] = target_y
	if visual != null and instant:
		visual.position.y = target_y
	if col != null:
		col.disabled = not closed


func _setup_environment(floor_cfg: Dictionary) -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.html(str(floor_cfg.get("fog_color", "#141824")))
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.18
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Rich cool-slate ambient fill so stone relief & steel armor stay clearly legible everywhere
	var base_amb := Color.html(str(floor_cfg.get("ambient_color", "#2d3548")))
	env.ambient_light_color = base_amb.lerp(Color(0.36, 0.40, 0.52), 0.62)
	env.ambient_light_energy = 0.96
	env.fog_enabled = true
	env.fog_light_color = Color.html(str(floor_cfg.get("fog_color", "#161b28")))
	env.fog_density = minf(0.009, float(floor_cfg.get("fog_density", 0.009)))
	env.glow_enabled = true
	env.glow_intensity = 0.38
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 1.15
	env_node.environment = env
	_world_root.add_child(env_node)

	# Soft overhead directional sculpt light — guarantees crisp metallic highlights & stonework
	# in EVERY room on both Vulkan Forward+ and OpenGL3 Compatibility!
	var dir_l := DirectionalLight3D.new()
	dir_l.name = "DungeonSculptFill"
	dir_l.rotation_degrees = Vector3(-52.0, 28.0, 0.0)
	dir_l.light_color = Color(0.86, 0.90, 0.98)
	dir_l.light_energy = 0.54
	dir_l.shadow_enabled = false
	_world_root.add_child(dir_l)


static func _add_box_collider(body: StaticBody3D, pos: Vector3, size: Vector3) -> void:
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position = pos
	body.add_child(col)
