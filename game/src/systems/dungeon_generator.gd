class_name DungeonGenerator
extends RefCounted
## Tier 2 Pure System: Deterministic procedural 3D Nordic-ruin labyrinth generator.
## Produces a connected grid + room graph with guaranteed Entrance, discoverable Safe Room,
## optional sealed Boss Arena + adjoining Treasure Vault, and hidden distant Exit Staircase.

const TILE_VOID := 0
const TILE_FLOOR := 1
const TILE_CORRIDOR := 2
const TILE_SAFE_FLOOR := 3
const TILE_BOSS_FLOOR := 4
const TILE_VAULT_FLOOR := 5
const TILE_BOSS_GATE := 6
const TILE_VAULT_GATE := 7

class FloorLayout:
	var seed_value: int = 0
	var floor_number: int = 1
	var width: int = 48
	var height: int = 48
	var tile_size: float = 4.0
	var tiles: PackedByteArray = PackedByteArray()
	var rooms: Array[Dictionary] = []
	var entrance_room_id: int = -1
	var stairs_room_id: int = -1
	var safe_room_id: int = -1
	var boss_room_id: int = -1
	var vault_room_id: int = -1
	var boss_gate_tile: Vector2i = Vector2i(-1, -1)
	var vault_gate_tile: Vector2i = Vector2i(-1, -1)
	var chests: Array[Dictionary] = []
	var containers: Array[Dictionary] = []
	var traps: Array[Vector2i] = []
	var enemy_spawns: Array[Dictionary] = []
	var landmarks: Array[Dictionary] = []

	func get_tile(x: int, y: int) -> int:
		if x < 0 or y < 0 or x >= width or y >= height:
			return TILE_VOID
		return tiles[y * width + x]

	func set_tile(x: int, y: int, val: int) -> void:
		if x < 0 or y < 0 or x >= width or y >= height:
			return
		tiles[y * width + x] = val

	func is_walkable(x: int, y: int) -> bool:
		return get_tile(x, y) != TILE_VOID

	func tile_to_world(tile: Vector2i) -> Vector3:
		return Vector3((float(tile.x) + 0.5) * tile_size, 0.0, (float(tile.y) + 0.5) * tile_size)

	func world_to_tile(pos: Vector3) -> Vector2i:
		return Vector2i(int(floor(pos.x / tile_size)), int(floor(pos.z / tile_size)))

	func get_room(room_id: int) -> Dictionary:
		for r in rooms:
			if int(r["id"]) == room_id:
				return r
		return {}

	func is_world_in_safe_room(pos: Vector3) -> bool:
		var t := world_to_tile(pos)
		return get_tile(t.x, t.y) == TILE_SAFE_FLOOR

	func is_world_in_boss_arena(pos: Vector3) -> bool:
		var t := world_to_tile(pos)
		return get_tile(t.x, t.y) == TILE_BOSS_FLOOR


static func generate(world_data: Dictionary, enemies_data: Dictionary, floor_number: int, run_seed: int) -> FloorLayout:
	var grid_cfg: Dictionary = world_data["grid"]
	var lab_cfg: Dictionary = world_data["labyrinth"]
	var max_attempts: int = int(lab_cfg.get("max_generation_attempts", 12))

	for attempt in range(max_attempts):
		var attempt_seed := int(("%d:floor:%d:try:%d" % [run_seed, floor_number, attempt]).hash())
		var rng := SeededRng.new(attempt_seed)
		var layout := _try_generate(grid_cfg, lab_cfg, world_data, enemies_data, floor_number, run_seed, rng)
		if layout != null and _validate_connectivity(layout):
			return layout

	# Guaranteed deterministic fallback labyrinth so generation can NEVER fail
	var fb_rng := SeededRng.new(int(("%d:fallback:%d" % [run_seed, floor_number]).hash()))
	return _build_fallback_layout(grid_cfg, world_data, enemies_data, floor_number, run_seed, fb_rng)


static func _try_generate(
	grid_cfg: Dictionary,
	lab_cfg: Dictionary,
	world_data: Dictionary,
	enemies_data: Dictionary,
	floor_number: int,
	run_seed: int,
	rng: SeededRng
) -> FloorLayout:
	var layout := FloorLayout.new()
	layout.seed_value = run_seed
	layout.floor_number = floor_number
	layout.width = int(grid_cfg["width_tiles"])
	layout.height = int(grid_cfg["height_tiles"])
	layout.tile_size = float(grid_cfg["tile_size_meters"])
	layout.tiles.resize(layout.width * layout.height)
	layout.tiles.fill(TILE_VOID)

	var target_rooms := rng.next_int_range("gen", int(lab_cfg["room_count_min"]), int(lab_cfg["room_count_max"]))
	var min_sz := int(lab_cfg["room_min_size"])
	var max_sz := int(lab_cfg["room_max_size"])
	var boss_sz := int(lab_cfg["boss_room_size"])
	var vault_sz := int(lab_cfg["vault_room_size"])
	var safe_sz := int(lab_cfg["safe_room_size"])

	var rects: Array[Rect2i] = []

	# 1. Place Boss Arena + adjoining Treasure Vault pair first so they always fit cleanly
	var boss_placed := false
	for _i in range(80):
		var bx := rng.next_int_range("gen", 3, layout.width - boss_sz - vault_sz - 5)
		var by := rng.next_int_range("gen", 3, layout.height - boss_sz - 4)
		var boss_rect := Rect2i(bx, by, boss_sz, boss_sz)
		var vault_x := bx + boss_sz + 1
		var vault_y := by + (boss_sz - vault_sz) / 2
		var vault_rect := Rect2i(vault_x, vault_y, vault_sz, vault_sz)
		if _rect_in_bounds(boss_rect, layout) and _rect_in_bounds(vault_rect, layout):
			rects.append(boss_rect)
			rects.append(vault_rect)
			boss_placed = true
			break
	if not boss_placed:
		return null

	# 2. Place Safe Room
	var safe_placed := false
	for _i in range(100):
		var sx := rng.next_int_range("gen", 2, layout.width - safe_sz - 3)
		var sy := rng.next_int_range("gen", 2, layout.height - safe_sz - 3)
		var r := Rect2i(sx, sy, safe_sz, safe_sz)
		if not _overlaps_any(r, rects, 2):
			rects.append(r)
			safe_placed = true
			break
	if not safe_placed:
		return null

	# 3. Place remaining Nordic-ruin chambers & halls
	for _attempt in range(target_rooms * 25):
		if rects.size() >= target_rooms:
			break
		var rw := rng.next_int_range("gen", min_sz, max_sz)
		var rh := rng.next_int_range("gen", min_sz, max_sz)
		var rx := rng.next_int_range("gen", 2, layout.width - rw - 3)
		var ry := rng.next_int_range("gen", 2, layout.height - rh - 3)
		var cand := Rect2i(rx, ry, rw, rh)
		if not _overlaps_any(cand, rects, 2):
			rects.append(cand)

	if rects.size() < 6:
		return null

	# Build room metadata
	for idx in range(rects.size()):
		var rect: Rect2i = rects[idx]
		var center := Vector2i(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 2)
		var role := "combat"
		if idx == 0:
			role = "boss"
		elif idx == 1:
			role = "vault"
		elif idx == 2:
			role = "safe"
		layout.rooms.append({
			"id": idx,
			"rect": rect,
			"center": center,
			"role": role,
			"neighbors": [],
		})

	layout.boss_room_id = 0
	layout.vault_room_id = 1
	layout.safe_room_id = 2

	# 4. Build Prim's MST over all rooms EXCEPT Vault (Vault connects ONLY to Boss Arena!)
	var main_ids: Array[int] = []
	for idx in range(layout.rooms.size()):
		if idx != layout.vault_room_id:
			main_ids.append(idx)

	var in_tree: Dictionary = {main_ids[0]: true}
	var edges: Array[Vector2i] = []
	while in_tree.size() < main_ids.size():
		var best_dist := 1e12
		var best_u := -1
		var best_v := -1
		for u in in_tree.keys():
			var cu: Vector2i = layout.rooms[u]["center"]
			for v in main_ids:
				if in_tree.has(v):
					continue
				var cv: Vector2i = layout.rooms[v]["center"]
				var d := cu.distance_squared_to(cv)
				if d < best_dist:
					best_dist = d
					best_u = u
					best_v = v
		if best_u == -1:
			break
		in_tree[best_v] = true
		edges.append(Vector2i(best_u, best_v))

	# Add loop corridors (skipping Boss Arena & Vault so Boss Arena remains a single sealable entrance!)
	var loop_chance := float(lab_cfg.get("loop_connection_chance", 0.28))
	for i in range(main_ids.size()):
		var u := main_ids[i]
		if u == layout.boss_room_id:
			continue
		for j in range(i + 1, main_ids.size()):
			var v := main_ids[j]
			if v == layout.boss_room_id:
				continue
			if _has_edge(edges, u, v):
				continue
			var cu: Vector2i = layout.rooms[u]["center"]
			var cv: Vector2i = layout.rooms[v]["center"]
			if cu.distance_to(cv) <= 14.0 and rng.next_float("gen") < loop_chance:
				edges.append(Vector2i(u, v))

	# Record room graph adjacency
	for e in edges:
		layout.rooms[e.x]["neighbors"].append(e.y)
		layout.rooms[e.y]["neighbors"].append(e.x)
	layout.rooms[layout.boss_room_id]["neighbors"].append(layout.vault_room_id)
	layout.rooms[layout.vault_room_id]["neighbors"].append(layout.boss_room_id)

	# 5. Choose Entrance (furthest non-special room from Boss) and Hidden Staircase (furthest BFS room from Entrance)
	var dist_from_boss := _bfs_room_distances(layout.rooms, layout.boss_room_id)
	var best_ent := -1
	var best_ent_d := -1
	for r in layout.rooms:
		var rid := int(r["id"])
		if rid in [layout.boss_room_id, layout.vault_room_id, layout.safe_room_id]:
			continue
		var d := int(dist_from_boss.get(rid, 0))
		if d > best_ent_d:
			best_ent_d = d
			best_ent = rid
	if best_ent == -1:
		return null
	layout.entrance_room_id = best_ent
	layout.rooms[best_ent]["role"] = "entrance"

	var dist_from_ent := _bfs_room_distances(layout.rooms, layout.entrance_room_id)
	var best_stairs := -1
	var best_stairs_d := -1
	for r in layout.rooms:
		var rid := int(r["id"])
		if rid in [layout.boss_room_id, layout.vault_room_id, layout.safe_room_id, layout.entrance_room_id]:
			continue
		var d := int(dist_from_ent.get(rid, 0))
		if d > best_stairs_d:
			best_stairs_d = d
			best_stairs = rid
	if best_stairs == -1:
		return null
	layout.stairs_room_id = best_stairs
	layout.rooms[best_stairs]["role"] = "stairs"

	# 6. Carve rooms into grid
	for r in layout.rooms:
		var rect: Rect2i = r["rect"]
		var tile_type := TILE_FLOOR
		match str(r["role"]):
			"safe": tile_type = TILE_SAFE_FLOOR
			"boss": tile_type = TILE_BOSS_FLOOR
			"vault": tile_type = TILE_VAULT_FLOOR
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				layout.set_tile(x, y, tile_type)

	# 7. Carve L-shaped corridors for all edges, capturing Boss Arena entrance gate tile
	for e in edges:
		var a: Vector2i = layout.rooms[e.x]["center"]
		var b: Vector2i = layout.rooms[e.y]["center"]
		var path_tiles := _carve_corridor(layout, a, b, rng)
		if e.x == layout.boss_room_id or e.y == layout.boss_room_id:
			var boss_rect: Rect2i = layout.rooms[layout.boss_room_id]["rect"]
			for pt in path_tiles:
				if not boss_rect.has_point(pt) and _is_adjacent_to_rect(pt, boss_rect):
					layout.boss_gate_tile = pt
					layout.set_tile(pt.x, pt.y, TILE_BOSS_GATE)
					break

	# Carve sealed doorway between Boss Arena and Treasure Vault
	var b_rect: Rect2i = layout.rooms[layout.boss_room_id]["rect"]
	var v_rect: Rect2i = layout.rooms[layout.vault_room_id]["rect"]
	var gate_x := b_rect.end.x
	var gate_y := v_rect.position.y + v_rect.size.y / 2
	layout.vault_gate_tile = Vector2i(gate_x, gate_y)
	layout.set_tile(gate_x, gate_y, TILE_VAULT_GATE)

	if layout.boss_gate_tile == Vector2i(-1, -1):
		return null

	_populate_contents(layout, lab_cfg, world_data, enemies_data, floor_number, rng)
	return layout


static func _populate_contents(
	layout: FloorLayout,
	lab_cfg: Dictionary,
	world_data: Dictionary,
	enemies_data: Dictionary,
	floor_number: int,
	rng: SeededRng
) -> void:
	var floor_cfg := _get_floor_cfg(world_data, floor_number)
	var enemy_budget := int(floor_cfg.get("enemy_budget", 14))
	var regular_enemies: Array = []
	for e in enemies_data.get("enemies", []):
		if not bool(e.get("is_boss", false)):
			regular_enemies.append(e)

	var chest_chance := float(lab_cfg.get("chest_room_chance", 0.55))
	var combat_rooms: Array[Dictionary] = []

	for r in layout.rooms:
		var role := str(r["role"])
		var rect: Rect2i = r["rect"]
		var center: Vector2i = r["center"]
		if role == "vault":
			layout.chests.append({"tile": center, "tier": "vault_sponsored", "room_id": r["id"]})
			layout.chests.append({"tile": center + Vector2i(1, 0), "tier": "rare", "room_id": r["id"]})
		elif role == "combat":
			combat_rooms.append(r)
			if rng.next_float("gen") < chest_chance:
				var ct := Vector2i(
					rng.next_int_range("gen", rect.position.x + 1, maxi(rect.position.x + 1, rect.end.x - 2)),
					rng.next_int_range("gen", rect.position.y + 1, maxi(rect.position.y + 1, rect.end.y - 2))
				)
				layout.chests.append({"tile": ct, "tier": "standard", "room_id": r["id"]})
			# Crates & urns tucked into room corners (denser floors: up to containers_per_room_max)
			var corners := [rect.position, Vector2i(rect.end.x - 1, rect.position.y), Vector2i(rect.position.x, rect.end.y - 1),
				Vector2i(rect.end.x - 1, rect.end.y - 1)]
			var n_cont := rng.next_int_range("gen", 1, int(lab_cfg.get("containers_per_room_max", 1)))
			for ci in range(mini(n_cont, corners.size())):
				layout.containers.append({
					"tile": corners[ci],
					"kind": "crate" if rng.next_float("gen") < 0.5 else "urn",
				})
			if rng.next_float("gen") < float(lab_cfg.get("trap_corridor_chance", 0.12)) * 2.0:
				layout.traps.append(center)
		elif role == "stairs":
			layout.chests.append({"tile": Vector2i(rect.position.x, rect.position.y), "tier": "rare", "room_id": r["id"]})

	# Place Floor Boss in Boss Arena center
	var boss_room: Dictionary = layout.rooms[layout.boss_room_id]
	layout.enemy_spawns.append({
		"enemy_id": str(floor_cfg.get("boss_id", "iron_warden_boss")),
		"tile": boss_room["center"],
		"room_id": layout.boss_room_id,
		"is_boss": true,
	})

	# Distribute regular enemies across combat rooms (NEVER in Entrance, Safe Room, or Vault)
	if not combat_rooms.is_empty() and not regular_enemies.is_empty():
		for i in range(enemy_budget):
			var room: Dictionary = combat_rooms[i % combat_rooms.size()]
			var rect: Rect2i = room["rect"]
			var sx := rng.next_int_range("gen", rect.position.x, rect.end.x - 1)
			var sy := rng.next_int_range("gen", rect.position.y, rect.end.y - 1)
			var picked: Dictionary = rng.pick_weighted("gen", regular_enemies, "spawn_weight")
			layout.enemy_spawns.append({
				"enemy_id": str(picked["id"]),
				"tile": Vector2i(sx, sy),
				"room_id": int(room["id"]),
				"is_boss": false,
			})

	# Populate Compass Landmarks (discovered as the player approaches — D-016)
	layout.landmarks = [
		{
			"id": "safe_room",
			"label": "Safe Room",
			"icon": "S",
			"world_pos": layout.tile_to_world(layout.rooms[layout.safe_room_id]["center"]),
			"discovered": false,
		},
		{
			"id": "boss_arena",
			"label": "Boss Gate",
			"icon": "B",
			"world_pos": layout.tile_to_world(layout.boss_gate_tile),
			"discovered": false,
		},
		{
			"id": "vault",
			"label": "Treasure Vault",
			"icon": "V",
			"world_pos": layout.tile_to_world(layout.rooms[layout.vault_room_id]["center"]),
			"discovered": false,
		},
		{
			"id": "stairs",
			"label": "Stairwell",
			"icon": "D",
			"world_pos": layout.tile_to_world(layout.rooms[layout.stairs_room_id]["center"]),
			"discovered": false,
		},
	]


static func _carve_corridor(layout: FloorLayout, a: Vector2i, b: Vector2i, rng: SeededRng) -> Array[Vector2i]:
	var carved: Array[Vector2i] = []
	var horizontal_first := rng.next_float("gen") < 0.5
	var cur := a
	if horizontal_first:
		while cur.x != b.x:
			cur.x += 1 if b.x > cur.x else -1
			carved.append(cur)
		while cur.y != b.y:
			cur.y += 1 if b.y > cur.y else -1
			carved.append(cur)
	else:
		while cur.y != b.y:
			cur.y += 1 if b.y > cur.y else -1
			carved.append(cur)
		while cur.x != b.x:
			cur.x += 1 if b.x > cur.x else -1
			carved.append(cur)

	for pt in carved:
		if layout.get_tile(pt.x, pt.y) == TILE_VOID:
			layout.set_tile(pt.x, pt.y, TILE_CORRIDOR)
	return carved


static func _validate_connectivity(layout: FloorLayout) -> bool:
	if layout.entrance_room_id < 0 or layout.stairs_room_id < 0 or layout.safe_room_id < 0 or layout.boss_room_id < 0 or layout.vault_room_id < 0:
		return false
	var start: Vector2i = layout.rooms[layout.entrance_room_id]["center"]
	var visited: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d in dirs:
			var nxt: Vector2i = cur + d
			if visited.has(nxt):
				continue
			if layout.is_walkable(nxt.x, nxt.y):
				visited[nxt] = true
				queue.append(nxt)

	for rid in [layout.stairs_room_id, layout.safe_room_id, layout.boss_room_id, layout.vault_room_id]:
		var target: Vector2i = layout.rooms[rid]["center"]
		if not visited.has(target):
			return false
	return true


static func _build_fallback_layout(
	grid_cfg: Dictionary,
	world_data: Dictionary,
	enemies_data: Dictionary,
	floor_number: int,
	run_seed: int,
	rng: SeededRng
) -> FloorLayout:
	var layout := FloorLayout.new()
	layout.seed_value = run_seed
	layout.floor_number = floor_number
	layout.width = int(grid_cfg["width_tiles"])
	layout.height = int(grid_cfg["height_tiles"])
	layout.tile_size = float(grid_cfg["tile_size_meters"])
	layout.tiles.resize(layout.width * layout.height)
	layout.tiles.fill(TILE_VOID)

	var defs := [
		{"rect": Rect2i(3, 18, 5, 5), "role": "entrance"},
		{"rect": Rect2i(11, 18, 5, 5), "role": "combat"},
		{"rect": Rect2i(19, 18, 5, 5), "role": "safe"},
		{"rect": Rect2i(27, 18, 5, 5), "role": "combat"},
		{"rect": Rect2i(35, 18, 5, 5), "role": "stairs"},
		{"rect": Rect2i(18, 6, 7, 7), "role": "boss"},
		{"rect": Rect2i(26, 7, 4, 4), "role": "vault"},
	]
	for idx in range(defs.size()):
		var rect: Rect2i = defs[idx]["rect"]
		var center := Vector2i(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 2)
		var role := str(defs[idx]["role"])
		layout.rooms.append({"id": idx, "rect": rect, "center": center, "role": role, "neighbors": []})
		var t := TILE_FLOOR
		if role == "safe": t = TILE_SAFE_FLOOR
		elif role == "boss": t = TILE_BOSS_FLOOR
		elif role == "vault": t = TILE_VAULT_FLOOR
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				layout.set_tile(x, y, t)

	layout.entrance_room_id = 0
	layout.safe_room_id = 2
	layout.stairs_room_id = 4
	layout.boss_room_id = 5
	layout.vault_room_id = 6

	for x in range(5, 38):
		if layout.get_tile(x, 20) == TILE_VOID:
			layout.set_tile(x, 20, TILE_CORRIDOR)
	for y in range(13, 19):
		if layout.get_tile(21, y) == TILE_VOID:
			layout.set_tile(21, y, TILE_CORRIDOR)
	layout.boss_gate_tile = Vector2i(21, 13)
	layout.set_tile(21, 13, TILE_BOSS_GATE)
	layout.vault_gate_tile = Vector2i(25, 9)
	layout.set_tile(25, 9, TILE_VAULT_GATE)

	_populate_contents(layout, world_data.get("labyrinth", {}), world_data, enemies_data, floor_number, rng)
	return layout


static func _rect_in_bounds(rect: Rect2i, layout: FloorLayout) -> bool:
	return rect.position.x >= 1 and rect.position.y >= 1 and rect.end.x < layout.width - 1 and rect.end.y < layout.height - 1


static func _overlaps_any(rect: Rect2i, rects: Array[Rect2i], padding: int) -> bool:
	var padded := rect.grow(padding)
	for other in rects:
		if padded.intersects(other):
			return true
	return false


static func _has_edge(edges: Array[Vector2i], u: int, v: int) -> bool:
	for e in edges:
		if (e.x == u and e.y == v) or (e.x == v and e.y == u):
			return true
	return false


static func _is_adjacent_to_rect(pt: Vector2i, rect: Rect2i) -> bool:
	var expanded := rect.grow(1)
	if not expanded.has_point(pt):
		return false
	var on_x := pt.x >= rect.position.x and pt.x < rect.end.x
	var on_y := pt.y >= rect.position.y and pt.y < rect.end.y
	return on_x or on_y


static func _bfs_room_distances(rooms: Array[Dictionary], start_id: int) -> Dictionary:
	var dist: Dictionary = {start_id: 0}
	var q: Array[int] = [start_id]
	while not q.is_empty():
		var cur: int = q.pop_front()
		var d := int(dist[cur])
		for nxt in rooms[cur]["neighbors"]:
			if not dist.has(nxt):
				dist[nxt] = d + 1
				q.append(nxt)
	return dist


static func _get_floor_cfg(world_data: Dictionary, floor_number: int) -> Dictionary:
	var floors: Array = world_data.get("floors", [])
	for f in floors:
		if int(f.get("floor_number", 0)) == floor_number:
			return f
	return floors[0] if not floors.is_empty() else {}
