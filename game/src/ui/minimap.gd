class_name MiniMap
extends Control
## Corner minimap locked onto the player (D-046): explored tiles within RADIUS tiles around the crawler, inked on
## parchment like the full map, with the crawler arrow always at the centre and discovered landmark icons.

const RADIUS := 22

var layout: DungeonGenerator.FloorLayout = null
var seen: Dictionary = {}
var player_tile_f: Vector2 = Vector2.ZERO
var player_yaw: float = 0.0


func refresh(p_layout: DungeonGenerator.FloorLayout, p_seen: Dictionary, player_pos: Vector3, yaw: float) -> void:
	layout = p_layout
	seen = p_seen
	if layout != null:
		player_tile_f = Vector2(player_pos.x, player_pos.z) / layout.tile_size
	player_yaw = yaw
	queue_redraw()


## Screen position of a tile-space point (the player is always the centre of the minimap).
func tile_to_screen(t: Vector2) -> Vector2:
	var cell := minf(size.x, size.y) / float(RADIUS * 2 + 1)
	return size * 0.5 + (t - player_tile_f) * cell


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.62, 0.52, 0.36, 0.92))
	if layout == null:
		return
	var cell := minf(size.x, size.y) / float(RADIUS * 2 + 1)
	var pt := Vector2i(floori(player_tile_f.x), floori(player_tile_f.y))
	var ink := Color(0.16, 0.1, 0.05, 0.95)
	for dy in range(-RADIUS, RADIUS + 1):
		for dx in range(-RADIUS, RADIUS + 1):
			var t := pt + Vector2i(dx, dy)
			if not seen.has(t):
				continue
			var tt := layout.get_tile(t.x, t.y)
			if tt == DungeonGenerator.TILE_VOID:
				continue
			var p := tile_to_screen(Vector2(t))
			var fill := Color(0.42, 0.33, 0.22, 0.6) if tt == DungeonGenerator.TILE_CORRIDOR else Color(0.5, 0.4, 0.27, 0.7)
			if tt == DungeonGenerator.TILE_SAFE_FLOOR:
				fill = Color(0.3, 0.5, 0.42, 0.75)
			elif tt == DungeonGenerator.TILE_BOSS_FLOOR:
				fill = Color(0.55, 0.25, 0.18, 0.75)
			elif tt == DungeonGenerator.TILE_VAULT_FLOOR:
				fill = Color(0.65, 0.5, 0.18, 0.75)
			draw_rect(Rect2(p, Vector2(cell, cell)), fill, true)
			for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				var n: Vector2i = t + d
				if layout.is_walkable(n.x, n.y):
					continue
				var a := p if d.x >= 0 and d.y >= 0 else p
				var b := p
				match d:
					Vector2i(0, -1):
						b = p + Vector2(cell, 0)
					Vector2i(0, 1):
						a = p + Vector2(0, cell)
						b = p + Vector2(cell, cell)
					Vector2i(-1, 0):
						b = p + Vector2(0, cell)
					Vector2i(1, 0):
						a = p + Vector2(cell, 0)
						b = p + Vector2(cell, cell)
				draw_line(a, b, ink, maxf(1.0, cell * 0.14))
	for lm in layout.landmarks:
		if not bool(lm.get("discovered", false)):
			continue
		var wp: Vector3 = lm["world_pos"]
		var lp := tile_to_screen(Vector2(wp.x, wp.z) / layout.tile_size)
		if not r.has_point(lp):
			continue
		var tex := UiTheme.tex(str(UiTheme.map_mark(str(lm.get("id", "")))[0]))
		if tex != null:
			draw_texture_rect(tex, Rect2(lp - Vector2(9, 9), Vector2(18, 18)), false, ink)
	# FB-022: points of interest revealed by safe-room maps (crossed off once looted / slain)
	for poi in layout.pois:
		if not bool(poi.get("revealed", false)):
			continue
		var pw: Vector3 = poi["world_pos"]
		var pp := tile_to_screen(Vector2(pw.x, pw.z) / layout.tile_size)
		if not r.has_point(pp):
			continue
		var mk := UiTheme.map_mark(str(poi["kind"]))
		var ptex := UiTheme.tex(str(mk[0]))
		var pc: Color = mk[2]
		if bool(poi.get("done", false)):
			pc.a = 0.3
		if ptex != null:
			draw_texture_rect(ptex, Rect2(pp - Vector2(7, 7), Vector2(14, 14)), false, pc)
	var c := size * 0.5
	var pt_tex := UiTheme.tex("icon_player")
	draw_set_transform(c, player_yaw, Vector2.ONE)
	if pt_tex != null:
		draw_texture_rect(pt_tex, Rect2(Vector2(-10, -10), Vector2(20, 20)), false, Color(0.75, 0.1, 0.06))
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(0, -9), Vector2(6, 7), Vector2(-6, 7)]), Color(0.75, 0.1, 0.06))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(r, Color(0.35, 0.26, 0.12, 0.9), false, 2.0)
