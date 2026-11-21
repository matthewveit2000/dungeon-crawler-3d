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
	var stairs_room_id: int = -1  ## primary (nearest the entrance)
	var safe_room_id: int = -1  ## primary (nearest the entrance)
	var stairs_room_ids: Array[int] = []  ## every hidden stairwell on the floor (D-044)
	var safe_room_ids: Array[int] = []  ## every safe room on the floor (D-044)
	var boss_room_id: int = -1
	var vault_room_id: int = -1
	var boss_gate_tile: Vector2i = Vector2i(-1, -1)
	var vault_gate_tile: Vector2i = Vector2i(-1, -1)
	var chests: Array[Dictionary] = []
	var containers: Array[Dictionary] = []
	var traps: Array[Vector2i] = []
	var enemy_spawns: Array[Dictionary] = []
	var landmarks: Array[Dictionary] = []
	## FB-022 map points of interest (treasure chests, champion lairs) revealed by safe-room area maps:
	## {"kind", "tile", "world_pos", "label", "revealed", "done", "chest_index" | "spawn_index"}
	var pois: Array[Dictionary] = []
	var nav: AStarGrid2D = null  ## tile-level navigation grid (FB-014 pathfinding), built on first use
	var nav_weights: Dictionary = {}  ## Vector2i -> extra path cost (tiles cluttered by props), filled by the builder
	var blocked_corners: Dictionary = {}  ## Vector2i tile-corner (top-left corner of that tile) -> true: a pillar stands there
	const LOS_HALF_WIDTH := 0.16  ## tiles (~0.65 m): half the band swept by has_tile_los
	const CORNER_CLEARANCE := 0.3  ## tiles (~1.2 m): pillar half-width + body radius

	## Tile path from a to b around walls and blocked props (empty if unreachable). Built lazily once per floor.
	func find_path(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
		if nav == null:
			_build_nav()
		var out: Array[Vector2i] = []
		if not nav.is_in_boundsv(a) or not nav.is_in_boundsv(b):
			return out
		var ids := nav.get_id_path(a, b, true)
		for p in ids:
			out.append(p)
		return out

	func _build_nav() -> void:
		nav = AStarGrid2D.new()
		nav.region = Rect2i(0, 0, width, height)
		nav.cell_size = Vector2(1, 1)
		# 4-way moves only: straight segments between tile centres stay clear of pillars on tile corners.
		# FB-022: followers string-pull these paths (has_tile_los) so they still walk in straight lines.
		nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
		nav.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
		nav.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
		nav.update()
		nav.fill_solid_region(nav.region, true)
		for y in range(height):
			for x in range(width):
				if tiles[y * width + x] != TILE_VOID:
					nav.set_point_solid(Vector2i(x, y), false)
		# Chests stand on tile centres and props clutter wall tiles: prefer routes around them
		for c in chests:
			nav_weights[c["tile"]] = maxf(float(nav_weights.get(c["tile"], 1.0)), 6.0)
		for t in nav_weights:
			if nav.is_in_boundsv(t) and not nav.is_point_solid(t):
				nav.set_point_weight_scale(t, float(nav_weights[t]))

	## FB-022: true when a body can walk in a straight line between the centres of tiles a and b. The line is
	## swept as a band about one body wide: every tile it touches must be open floor without prop clutter, and
	## it must keep clear of the pillars that stand on tile corners (blocked_corners).
	func has_tile_los(a: Vector2i, b: Vector2i) -> bool:
		if nav == null:
			_build_nav()
		var pa := Vector2(a) + Vector2(0.5, 0.5)
		var pb := Vector2(b) + Vector2(0.5, 0.5)
		var seg := pb - pa
		var ln := seg.length()
		if ln < 0.01:
			return true
		var dir := seg / ln
		var side := Vector2(-dir.y, dir.x) * LOS_HALF_WIDTH
		var n := int(ceil(ln / 0.3))
		var last := Vector2i(-99999, -99999)
		for i in range(n + 1):
			var p := pa + seg * (float(i) / float(n))
			for off in [Vector2.ZERO, side, -side]:
				var t := Vector2i(floori(p.x + off.x), floori(p.y + off.y))
				if t == a or t == last:
					continue
				if not _tile_open(t):
					return false
			var ct := Vector2i(floori(p.x), floori(p.y))
			if ct != last:
				last = ct
				if not blocked_corners.is_empty():
					for c in [ct, ct + Vector2i(1, 0), ct + Vector2i(0, 1), ct + Vector2i(1, 1)]:
						if blocked_corners.has(c) and Geometry2D.get_closest_point_to_segment(Vector2(c), pa, pb).distance_to(Vector2(c)) < CORNER_CLEARANCE:
							return false
		return true

	func _tile_open(t: Vector2i) -> bool:
		if not nav.is_in_boundsv(t) or nav.is_point_solid(t):
			return false
		return float(nav_weights.get(t, 1.0)) <= 1.0

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

	# --- Vast-floor sector layout (D-044) ---------------------------------------------------------------
	# The map is cut into SEC x SEC-tile sectors holding at most one room each, so rooms are spread evenly
	# over an enormous area at O(rooms) cost. Landmarks are placed by distance so they are sparse:
	# the entrance near a corner, the boss arena + vault far away, several stairwells far from the
	# entrance AND from each other, and one safe room per region so a vendor is never impossibly far.
	var sec := int(lab_cfg.get("sector_tiles", 12))
	var sw := layout.width / sec
	var sh := layout.height / sec
	if sw < 3 or sh < 3:
		return null
	var fill := float(lab_cfg.get("room_fill_chance", 0.8))
	var min_sz := int(lab_cfg["room_min_size"])
	var max_sz := mini(int(lab_cfg["room_max_size"]), sec - 4)
	var boss_sz := int(lab_cfg["boss_room_size"])
	var vault_sz := int(lab_cfg["vault_room_size"])
	var safe_sz := int(lab_cfg["safe_room_size"])
	var sdiag := Vector2(sw, sh).length()

	var role_of: Dictionary = {}  # Vector2i sector -> role
	# Entrance: a sector near a random corner of the map
	var corner := rng.next_int_range("gen", 0, 3)
	var ent_s := Vector2i(rng.next_int_range("gen", 0, 1), rng.next_int_range("gen", 0, 1))
	if corner & 1:
		ent_s.x = sw - 1 - ent_s.x
	if corner & 2:
		ent_s.y = sh - 1 - ent_s.y
	role_of[ent_s] = "entrance"

	# Boss arena (sector b) + treasure vault (sector b + 1 to the east): far from the entrance
	var boss_cands: Array[Vector2i] = []
	var best_bd := 0.0
	for by in range(sh):
		for bx in range(sw - 1):
			best_bd = maxf(best_bd, Vector2(bx + 0.5 - ent_s.x, by - ent_s.y).length())
	var boss_min := best_bd * float(lab_cfg.get("boss_min_distance_frac", 0.7))
	for by in range(sh):
		for bx in range(sw - 1):
			if Vector2(bx + 0.5 - ent_s.x, by - ent_s.y).length() >= boss_min and not role_of.has(Vector2i(bx, by)) \
					and not role_of.has(Vector2i(bx + 1, by)):
				boss_cands.append(Vector2i(bx, by))
	if boss_cands.is_empty():
		return null
	var boss_s: Vector2i = boss_cands[rng.next_int_range("gen", 0, boss_cands.size() - 1)]
	role_of[boss_s] = "boss"
	role_of[boss_s + Vector2i(1, 0)] = "vault"

	# Stairwells: far from the entrance, away from the boss, and spread far apart from each other
	var stairs_count := int(lab_cfg.get("stairs_count", 3))
	var stair_min_ent := sdiag * float(lab_cfg.get("stairs_min_distance_frac", 0.45))
	var stairs_s: Array[Vector2i] = []
	for _k in range(stairs_count):
		var scored: Array = []
		for sy in range(sh):
			for sx in range(sw):
				var s := Vector2i(sx, sy)
				if role_of.has(s) or s.distance_to(ent_s) < stair_min_ent or s.distance_to(boss_s) < 2.5:
					continue
				var md := 1e9
				for o in stairs_s:
					md = minf(md, s.distance_to(o))
				scored.append([md if not stairs_s.is_empty() else s.distance_to(ent_s), s])
		if scored.is_empty():
			break
		scored.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
		var top := maxi(1, scored.size() / 5)
		var pick: Vector2i = scored[rng.next_int_range("gen", 0, top - 1)][1]
		stairs_s.append(pick)
		role_of[pick] = "stairs"
	if stairs_s.is_empty():
		return null

	# Safe rooms: one per region of an R x R macro grid, near each region's middle
	var regions := maxi(1, int(lab_cfg.get("safe_room_regions", 3)))
	var safe_s: Array[Vector2i] = []
	for ry in range(regions):
		for rx in range(regions):
			var x0 := rx * sw / regions
			var x1 := (rx + 1) * sw / regions
			var y0 := ry * sh / regions
			var y1 := (ry + 1) * sh / regions
			var mid := Vector2((x0 + x1 - 1) * 0.5, (y0 + y1 - 1) * 0.5)
			var best := Vector2i(-1, -1)
			var best_d := 1e9
			for sy in range(y0, y1):
				for sx in range(x0, x1):
					var s := Vector2i(sx, sy)
					if role_of.has(s) or s.distance_to(boss_s) < 2.0:
						continue
					var d := Vector2(s).distance_to(mid) + rng.next_float("gen") * 0.9
					if d < best_d:
						best_d = d
						best = s
			if best.x >= 0:
				safe_s.append(best)
				role_of[best] = "safe"
	if safe_s.is_empty():
		return null

	# Room rectangles: boss (id 0), vault (1), then every other sector
	var boss_rect := Rect2i(boss_s.x * sec + sec - boss_sz, boss_s.y * sec + 2 + rng.next_int_range("gen", 0, maxi(0, sec - 4 - boss_sz)), boss_sz, boss_sz)
	var vault_rect := Rect2i(boss_rect.end.x + 1, boss_rect.position.y + (boss_sz - vault_sz) / 2, vault_sz, vault_sz)
	if not _rect_in_bounds(boss_rect, layout) or not _rect_in_bounds(vault_rect, layout):
		return null
	var rects: Array[Rect2i] = [boss_rect, vault_rect]
	var roles: Array[String] = ["boss", "vault"]
	for sy in range(sh):
		for sx in range(sw):
			var s := Vector2i(sx, sy)
			var role := str(role_of.get(s, "combat"))
			if role == "boss" or role == "vault":
				continue
			if role == "combat" and rng.next_float("gen") > fill:
				continue
			var rw := rng.next_int_range("gen", min_sz, max_sz)
			var rh := rng.next_int_range("gen", min_sz, max_sz)
			match role:
				"safe":
					rw = safe_sz
					rh = safe_sz
				"stairs":
					rw = maxi(5, rw)
					rh = maxi(5, rh)
				"entrance":
					rw = maxi(5, rw)
					rh = maxi(5, rh)
			rw = mini(rw, sec - 4)
			rh = mini(rh, sec - 4)
			var r := Rect2i(sx * sec + 2 + rng.next_int_range("gen", 0, sec - 4 - rw), sy * sec + 2 + rng.next_int_range("gen", 0, sec - 4 - rh), rw, rh)
			if not _rect_in_bounds(r, layout):
				continue
			rects.append(r)
			roles.append(role)

	layout.stairs_room_ids.clear()
	layout.safe_room_ids.clear()
	for idx in range(rects.size()):
		var rect: Rect2i = rects[idx]
		layout.rooms.append({
			"id": idx,
			"rect": rect,
			"center": Vector2i(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 2),
			"role": roles[idx],
			"neighbors": [],
			"sector": Vector2i(rect.position.x / sec, rect.position.y / sec),
		})
		match roles[idx]:
			"entrance": layout.entrance_room_id = idx
			"stairs": layout.stairs_room_ids.append(idx)
			"safe": layout.safe_room_ids.append(idx)
	layout.boss_room_id = 0
	layout.vault_room_id = 1
	if layout.entrance_room_id < 0 or layout.stairs_room_ids.is_empty() or layout.safe_room_ids.is_empty():
		return null
	# Primary stairwell / safe room = the nearest to the entrance (debug teleports, tools)
	var ent_c: Vector2i = layout.rooms[layout.entrance_room_id]["center"]
	layout.stairs_room_id = _nearest_room(layout, layout.stairs_room_ids, ent_c)
	layout.safe_room_id = _nearest_room(layout, layout.safe_room_ids, ent_c)
	if rects.size() < 8:
		return null

	# --- Room graph: MST over rooms in nearby sectors (Kruskal), plus loops between sector neighbours ---------
	var by_sector: Dictionary = {}
	for r in layout.rooms:
		by_sector[r["sector"]] = int(r["id"])
	var main_ids: Array[int] = []
	for r in layout.rooms:
		var rid := int(r["id"])
		if rid != layout.boss_room_id and rid != layout.vault_room_id:
			main_ids.append(rid)
	var cand: Array = []
	for u in main_ids:
		var su: Vector2i = layout.rooms[u]["sector"]
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var v := int(by_sector.get(su + Vector2i(dx, dy), -1))
				if v <= u or v == layout.boss_room_id or v == layout.vault_room_id:
					continue
				var cu: Vector2i = layout.rooms[u]["center"]
				var cv: Vector2i = layout.rooms[v]["center"]
				cand.append([cu.distance_squared_to(cv), u, v, maxi(absi(dx), absi(dy))])
	cand.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	var uf := PackedInt32Array()
	uf.resize(layout.rooms.size())
	for i in range(uf.size()):
		uf[i] = i
	var edges: Array[Vector2i] = []
	var edge_set: Dictionary = {}
	var loop_chance := float(lab_cfg.get("loop_connection_chance", 0.3))
	var loops: Array[Vector2i] = []
	for c in cand:
		var u := int(c[1])
		var v := int(c[2])
		var ru := _uf_find(uf, u)
		var rv := _uf_find(uf, v)
		if ru != rv:
			uf[ru] = rv
			edges.append(Vector2i(u, v))
			edge_set[Vector2i(u, v)] = true
		elif int(c[3]) == 1 and rng.next_float("gen") < loop_chance:
			loops.append(Vector2i(u, v))
	# Join any islands left by empty sector clusters (rare): nearest pair between components
	var guard := 0
	while guard < 64:
		guard += 1
		var root0 := _uf_find(uf, main_ids[0])
		var stray := -1
		for rid in main_ids:
			if _uf_find(uf, rid) != root0:
				stray = rid
				break
		if stray == -1:
			break
		var rs := _uf_find(uf, stray)
		var best_pair := Vector2i(-1, -1)
		var best_d := 1 << 30
		for a in main_ids:
			if _uf_find(uf, a) != rs:
				continue
			for b in main_ids:
				if _uf_find(uf, b) == rs:
					continue
				var d: int = (layout.rooms[a]["center"] as Vector2i).distance_squared_to(layout.rooms[b]["center"])
				if d < best_d:
					best_d = d
					best_pair = Vector2i(a, b)
		uf[rs] = _uf_find(uf, best_pair.y)
		edges.append(best_pair)
	for e in loops:
		if not edge_set.has(e):
			edges.append(e)

	# Boss arena joins the labyrinth by exactly ONE corridor (its sealable gate), from the nearest room that is
	# not on the vault side; no other corridor may touch the arena or the vault.
	var b_center: Vector2i = layout.rooms[layout.boss_room_id]["center"]
	var boss_link := -1
	var link_d := 1 << 30
	for rid in main_ids:
		var c: Vector2i = layout.rooms[rid]["center"]
		if c.x >= boss_rect.end.x and absi(c.y - b_center.y) < boss_sz:
			continue
		var d := c.distance_squared_to(b_center)
		if d < link_d:
			link_d = d
			boss_link = rid
	if boss_link < 0:
		return null

	for e in edges:
		layout.rooms[e.x]["neighbors"].append(e.y)
		layout.rooms[e.y]["neighbors"].append(e.x)
	layout.rooms[layout.boss_room_id]["neighbors"].append(boss_link)
	layout.rooms[boss_link]["neighbors"].append(layout.boss_room_id)
	layout.rooms[layout.boss_room_id]["neighbors"].append(layout.vault_room_id)
	layout.rooms[layout.vault_room_id]["neighbors"].append(layout.boss_room_id)

	# --- Carve rooms, corridors and gates ---------------------------------------------------------------
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

	var forbidden := PackedByteArray()
	forbidden.resize(layout.width * layout.height)
	for fr in [boss_rect.grow(1), vault_rect.grow(1)]:
		for y in range(fr.position.y, fr.end.y):
			for x in range(fr.position.x, fr.end.x):
				if x >= 0 and y >= 0 and x < layout.width and y < layout.height:
					forbidden[y * layout.width + x] = 1
	for e in edges:
		_carve_avoiding(layout, layout.rooms[e.x]["center"], layout.rooms[e.y]["center"], forbidden, rng)

	# The single boss doorway: on the arena side facing its linked room (never the vault's east side)
	var lc: Vector2i = layout.rooms[boss_link]["center"]
	var dv := lc - b_center
	var door := Vector2i.ZERO
	if absi(dv.x) >= absi(dv.y) and dv.x < 0:
		door = Vector2i(boss_rect.position.x - 1, b_center.y)
	elif dv.y < 0:
		door = Vector2i(b_center.x, boss_rect.position.y - 1)
	else:
		door = Vector2i(b_center.x, boss_rect.end.y)
	var outside := door + (door - b_center).sign()
	if outside.x >= 0 and outside.y >= 0 and outside.x < layout.width and outside.y < layout.height:
		forbidden[outside.y * layout.width + outside.x] = 0
	if not _carve_avoiding(layout, lc, outside, forbidden, rng):
		return null
	layout.set_tile(outside.x, outside.y, TILE_CORRIDOR)
	layout.boss_gate_tile = door
	layout.set_tile(door.x, door.y, TILE_BOSS_GATE)

	# Sealed doorway between Boss Arena and Treasure Vault
	layout.vault_gate_tile = Vector2i(boss_rect.end.x, vault_rect.position.y + vault_sz / 2)
	layout.set_tile(layout.vault_gate_tile.x, layout.vault_gate_tile.y, TILE_VAULT_GATE)

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
	var theme := FloorTheme.resolve(floor_cfg)
	var regular_enemies: Array = []
	for e in enemies_data.get("enemies", []):
		# D-049 / D-055: eligible by floor level band, FloorTheme tags, and RarityTable spawn weight
		var eff_w := RarityTable.effective_enemy_spawn_weight(e)
		if not bool(e.get("is_boss", false)) and eff_w > 0.0 \
				and EnemyLevels.eligible(e, floor_number, enemies_data) and theme.matches_enemy(e):
			var entry: Dictionary = (e as Dictionary).duplicate()
			entry["spawn_weight"] = eff_w
			regular_enemies.append(entry)

	var chest_chance := float(lab_cfg.get("chest_room_chance", 0.55))
	var combat_rooms: Array[Dictionary] = []

	for r in layout.rooms:
		var role := str(r["role"])
		var rect: Rect2i = r["rect"]
		var center: Vector2i = r["center"]
		if role == "vault":
			layout.chests.append({"tile": center, "tier": "vault_legendary", "room_id": r["id"]})
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

	# FB-022 Champion lairs: boss fights are more common. Some combat rooms away from the entrance are guarded by
	# a promoted, named champion of a regular type (a mini-boss), its escorts and a treasure chest.
	var ch_cfg: Dictionary = PowerScale.cfg().get("champions", {})
	var count_k: float = PowerScale.knob("enemy_count")
	var lair_ids: Dictionary = {}
	if not combat_rooms.is_empty() and not regular_enemies.is_empty() and not ch_cfg.is_empty():
		var ent_c: Vector2i = layout.rooms[layout.entrance_room_id]["center"] if layout.entrance_room_id >= 0 else Vector2i.ZERO
		var cands: Array = []
		for r in combat_rooms:
			var rr: Rect2i = r["rect"]
			var rc: Vector2i = r["center"]
			if rr.size.x >= 4 and rr.size.y >= 4 and absi(rc.x - ent_c.x) + absi(rc.y - ent_c.y) > 14:
				cands.append(r)
		var want := maxi(int(ch_cfg.get("min_lairs", 6)), combat_rooms.size() / maxi(1, int(ch_cfg.get("lair_every_rooms", 12))))
		var titles: Array = ch_cfg.get("titles", ["the Champion"])
		while lair_ids.size() < mini(want, cands.size()):
			var room: Dictionary = cands[rng.next_int_range("gen", 0, cands.size() - 1)]
			if lair_ids.has(int(room["id"])):
				continue
			lair_ids[int(room["id"])] = true
			var rect: Rect2i = room["rect"]
			var picked: Dictionary = rng.pick_weighted("gen", regular_enemies, "spawn_weight")
			layout.pois.append({"kind": "champion", "tile": room["center"], "world_pos": layout.tile_to_world(room["center"]),
				"label": "Champion Lair", "revealed": false, "done": false, "spawn_index": layout.enemy_spawns.size()})
			layout.enemy_spawns.append({
				"enemy_id": str(picked["id"]),
				"tile": room["center"],
				"room_id": int(room["id"]),
				"is_boss": false,
				"champion": true,
				"title": str(titles[rng.next_int_range("gen", 0, titles.size() - 1)]),
			})
			for _e in range(int(round(float(ch_cfg.get("escort_count", 3)) * count_k))):
				var esc: Dictionary = rng.pick_weighted("gen", regular_enemies, "spawn_weight")
				layout.enemy_spawns.append({
					"enemy_id": str(esc["id"]),
					"tile": Vector2i(rng.next_int_range("gen", rect.position.x, rect.end.x - 1), rng.next_int_range("gen", rect.position.y, rect.end.y - 1)),
					"room_id": int(room["id"]),
					"is_boss": false,
				})
			var lair_chest := Vector2i(rect.end.x - 2, rect.position.y + 1)
			var taken := false
			for c in layout.chests:
				taken = taken or c["tile"] == lair_chest
			if not taken:
				layout.chests.append({"tile": lair_chest, "tier": "rare", "room_id": room["id"]})

	# Distribute regular enemies across combat rooms (NEVER in Entrance, Safe Room, or Vault)
	if not combat_rooms.is_empty() and not regular_enemies.is_empty():
		# FB-025: every normal combat room holds 0-7 enemies, averaging `enemies_per_room_mean` (default 4):
		# seven coin flips at p = mean / 7 (a binomial), so the count is always within 0..7.
		var mean_k: float = float(world_data.get("enemies_per_room_mean", 4.0)) * count_k
		var p_each := clampf(mean_k / 7.0, 0.0, 1.0)
		for room in combat_rooms:
			if lair_ids.has(int(room["id"])):
				continue
			var rect: Rect2i = room["rect"]
			var n_room := 0
			for _k in range(7):
				if rng.next_float("gen") < p_each:
					n_room += 1
			for _e in range(n_room):
				var sx := rng.next_int_range("gen", rect.position.x, rect.end.x - 1)
				var sy := rng.next_int_range("gen", rect.position.y, rect.end.y - 1)
				var picked: Dictionary = rng.pick_weighted("gen", regular_enemies, "spawn_weight")
				layout.enemy_spawns.append({
					"enemy_id": str(picked["id"]),
					"tile": Vector2i(sx, sy),
					"room_id": int(room["id"]),
					"is_boss": false,
				})

	# FB-022: every chest is a treasure point of interest a safe-room map can reveal
	for ci in range(layout.chests.size()):
		var ch: Dictionary = layout.chests[ci]
		if str(ch.get("tier", "")) == "vault_legendary":
			continue
		layout.pois.append({"kind": "treasure", "tile": ch["tile"], "world_pos": layout.tile_to_world(ch["tile"]),
			"label": "Treasure", "revealed": false, "done": false, "chest_index": ci})

	# Populate Compass Landmarks (discovered as the player approaches — D-016). On vast floors (D-044) the boss
	# gate and the stairwells are "far-sensed": the compass always hints at the nearest undiscovered one.
	layout.landmarks.clear()
	for sid in layout.safe_room_ids:
		layout.landmarks.append({"id": "safe_room", "label": "Safe Room", "icon": "S",
			"world_pos": layout.tile_to_world(layout.rooms[sid]["center"]), "discovered": false, "far_sense": false})
	layout.landmarks.append({"id": "boss_arena", "label": "Boss Gate", "icon": "B",
		"world_pos": layout.tile_to_world(layout.boss_gate_tile), "discovered": false, "far_sense": false})
	layout.landmarks.append({"id": "vault", "label": "Treasure Vault", "icon": "V",
		"world_pos": layout.tile_to_world(layout.rooms[layout.vault_room_id]["center"]), "discovered": false, "far_sense": false})
	for sid in layout.stairs_room_ids:
		layout.landmarks.append({"id": "stairs", "label": "Stairwell", "icon": "D",
			"world_pos": layout.tile_to_world(layout.rooms[sid]["center"]), "discovered": false, "far_sense": false})


## Test Mode (D-047): a compact floor holding one of every room type (entrance, combat halls, safe room, boss arena +
## vault, stairwell) with no regular enemies, so anything can be spawned and tested close at hand.
static func generate_test_floor(world_data: Dictionary, enemies_data: Dictionary, floor_number: int, run_seed: int) -> FloorLayout:
	var grid_cfg: Dictionary = (world_data["grid"] as Dictionary).duplicate()
	grid_cfg["width_tiles"] = 48
	grid_cfg["height_tiles"] = 48
	var rng := SeededRng.new(int(("%d:test:%d" % [run_seed, floor_number]).hash()))
	var layout := _build_fallback_layout(grid_cfg, world_data, enemies_data, floor_number, run_seed, rng)
	var kept: Array[Dictionary] = []
	for sp in layout.enemy_spawns:
		if bool(sp.get("is_boss", false)):
			kept.append(sp)
	layout.enemy_spawns = kept
	var pois: Array[Dictionary] = []
	for p in layout.pois:
		if str(p["kind"]) != "champion":
			pois.append(p)
	layout.pois = pois
	return layout


static func _validate_connectivity(layout: FloorLayout) -> bool:
	if layout.entrance_room_id < 0 or layout.stairs_room_id < 0 or layout.safe_room_id < 0 or layout.boss_room_id < 0 or layout.vault_room_id < 0:
		return false
	var w := layout.width
	var start: Vector2i = layout.rooms[layout.entrance_room_id]["center"]
	var seen := PackedByteArray()
	seen.resize(w * layout.height)
	seen[start.y * w + start.x] = 1
	var q := PackedInt32Array([start.y * w + start.x])
	var head := 0
	while head < q.size():
		var cur := q[head]
		head += 1
		var cx := cur % w
		var cy := cur / w
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = cx + d.x
			var ny: int = cy + d.y
			if not layout.is_walkable(nx, ny):
				continue
			var ni := ny * w + nx
			if seen[ni] == 1:
				continue
			seen[ni] = 1
			q.append(ni)
	var must: Array[int] = [layout.boss_room_id, layout.vault_room_id]
	must.append_array(layout.stairs_room_ids)
	must.append_array(layout.safe_room_ids)
	for rid in must:
		var target: Vector2i = layout.rooms[rid]["center"]
		if seen[target.y * w + target.x] == 0:
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
	layout.safe_room_ids = [2]
	layout.stairs_room_ids = [4]
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


static func _uf_find(uf: PackedInt32Array, i: int) -> int:
	var r := i
	while uf[r] != r:
		r = uf[r]
	var c := i
	while uf[c] != r:
		var nxt := uf[c]
		uf[c] = r
		c = nxt
	return r


static func _nearest_room(layout: FloorLayout, ids: Array[int], to: Vector2i) -> int:
	var best := -1
	var best_d := 1 << 30
	for rid in ids:
		var d := (layout.rooms[rid]["center"] as Vector2i).distance_squared_to(to)
		if d < best_d:
			best_d = d
			best = rid
	return best


static func _l_path(a: Vector2i, b: Vector2i, horizontal_first: bool) -> Array[Vector2i]:
	var cur := a
	var out: Array[Vector2i] = [cur]
	for leg in range(2):
		var do_x := (leg == 0) == horizontal_first
		if do_x:
			while cur.x != b.x:
				cur.x += 1 if b.x > cur.x else -1
				out.append(cur)
		else:
			while cur.y != b.y:
				cur.y += 1 if b.y > cur.y else -1
				out.append(cur)
	return out


static func _path_clear(layout: FloorLayout, path: Array[Vector2i], forbidden: PackedByteArray) -> bool:
	for pt in path:
		if pt.x < 0 or pt.y < 0 or pt.x >= layout.width or pt.y >= layout.height:
			return false
		if forbidden[pt.y * layout.width + pt.x] == 1:
			return false
	return true


## Carves a corridor from a to b: an L-shape when one stays clear of the forbidden (boss/vault) zone, otherwise a
## breadth-first detour around it. Returns false only if no route exists.
static func _carve_avoiding(layout: FloorLayout, a: Vector2i, b: Vector2i, forbidden: PackedByteArray, rng: SeededRng) -> bool:
	var first := rng.next_float("gen") < 0.5
	var path := _l_path(a, b, first)
	if not _path_clear(layout, path, forbidden):
		path = _l_path(a, b, not first)
	if not _path_clear(layout, path, forbidden):
		path = _bfs_path(layout, a, b, forbidden)
		if path.is_empty():
			return false
	for pt in path:
		if layout.get_tile(pt.x, pt.y) == TILE_VOID:
			layout.set_tile(pt.x, pt.y, TILE_CORRIDOR)
	return true


static func _bfs_path(layout: FloorLayout, a: Vector2i, b: Vector2i, forbidden: PackedByteArray) -> Array[Vector2i]:
	var w := layout.width
	var prev := PackedInt32Array()
	prev.resize(w * layout.height)
	prev.fill(-1)
	var start := a.y * w + a.x
	var goal := b.y * w + b.x
	prev[start] = start
	var q := PackedInt32Array([start])
	var head := 0
	while head < q.size():
		var cur := q[head]
		head += 1
		if cur == goal:
			break
		var cx := cur % w
		var cy := cur / w
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = cx + d.x
			var ny: int = cy + d.y
			if nx < 1 or ny < 1 or nx >= w - 1 or ny >= layout.height - 1:
				continue
			var ni := ny * w + nx
			if prev[ni] != -1 or forbidden[ni] == 1:
				continue
			prev[ni] = cur
			q.append(ni)
	var out: Array[Vector2i] = []
	if prev[goal] == -1:
		return out
	var c := goal
	while c != start:
		out.append(Vector2i(c % w, c / w))
		c = prev[c]
	out.append(a)
	out.reverse()
	return out


static func _rect_in_bounds(rect: Rect2i, layout: FloorLayout) -> bool:
	return rect.position.x >= 1 and rect.position.y >= 1 and rect.end.x < layout.width - 1 and rect.end.y < layout.height - 1


static func _get_floor_cfg(world_data: Dictionary, floor_number: int) -> Dictionary:
	var floors: Array = world_data.get("floors", [])
	for f in floors:
		if int(f.get("floor_number", 0)) == floor_number:
			return f
	return floors[0] if not floors.is_empty() else {}
