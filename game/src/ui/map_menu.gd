class_name MapMenu
extends MenuScreen
## Time-paused dungeon map (D-016): explored rooms & corridors inked on aged parchment with fog of war,
## discovered landmark icons, the player's position & heading, mouse-wheel zoom, drag to pan and a legend.

class MapCanvas extends Control:
	var layout: DungeonGenerator.FloorLayout = null
	var seen: Dictionary = {}
	var player_tile_f: Vector2 = Vector2.ZERO
	var player_yaw: float = 0.0
	var landmarks: Array = []
	var pois: Array = []
	var zoom: float = 1.0
	var pan: Vector2 = Vector2.ZERO
	const VIEW_TILES := 70  ## tiles across the shorter side at zoom 1
	var _drag: bool = false
	var paper: Texture2D = null

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton:
			var mb := ev as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
				zoom = clampf(zoom * 1.15, 0.6, 4.0)
				queue_redraw()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
				zoom = clampf(zoom / 1.15, 0.25, 4.0)
				queue_redraw()
			elif mb.button_index == MOUSE_BUTTON_LEFT:
				_drag = mb.pressed
		elif ev is InputEventKey and (ev as InputEventKey).pressed and (ev as InputEventKey).keycode == KEY_SPACE:
			pan = Vector2.ZERO
			queue_redraw()
		elif ev is InputEventMouseMotion and _drag:
			pan += (ev as InputEventMouseMotion).relative
			queue_redraw()

	## Screen position of a tile-space point; the player's tile maps to the centre (plus any drag offset).
	func tile_to_screen(t: Vector2) -> Vector2:
		var cell := clampf(minf(size.x, size.y) / float(VIEW_TILES) * zoom, 3.0, 64.0)
		return size * 0.5 - (player_tile_f + Vector2(0.5, 0.5)) * cell + pan + t * cell

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if paper != null:
			draw_texture_rect(paper, r, true, Color(0.95, 0.88, 0.72))
		else:
			draw_rect(r, Color(0.72, 0.62, 0.45))
		draw_rect(r, Color(0.25, 0.18, 0.1, 0.25), true)
		if layout == null:
			return
		# D-046: the map is locked onto the player (centred on the crawler; drag to look around, Space to snap back)
		var cell := clampf(minf(size.x, size.y) / float(VIEW_TILES) * zoom, 3.0, 64.0)
		var origin := size * 0.5 - (player_tile_f + Vector2(0.5, 0.5)) * cell + pan
		var ink := Color(0.16, 0.1, 0.05, 0.95)
		var room_fill := Color(0.5, 0.4, 0.27, 0.55)
		var corr_fill := Color(0.42, 0.33, 0.22, 0.45)
		for t in seen.keys():
			var tt := layout.get_tile(t.x, t.y)
			if tt == DungeonGenerator.TILE_VOID:
				continue
			var p := origin + Vector2(t) * cell
			var fill := corr_fill if tt == DungeonGenerator.TILE_CORRIDOR else room_fill
			if tt == DungeonGenerator.TILE_SAFE_FLOOR:
				fill = Color(0.3, 0.5, 0.42, 0.55)
			elif tt == DungeonGenerator.TILE_BOSS_FLOOR:
				fill = Color(0.55, 0.25, 0.18, 0.55)
			elif tt == DungeonGenerator.TILE_VAULT_FLOOR:
				fill = Color(0.65, 0.5, 0.18, 0.55)
			draw_rect(Rect2(p, Vector2(cell, cell)), fill, true)
			for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				var n: Vector2i = t + d
				if not layout.is_walkable(n.x, n.y):
					var a := p
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
					draw_line(a, b, ink, maxf(1.5, cell * 0.12))
		for lm in landmarks:
			if not bool(lm.get("discovered", false)):
				continue
			var wp: Vector3 = lm["world_pos"]
			var tp := Vector2(wp.x, wp.z) / layout.tile_size
			var pos := origin + tp * cell
			var mk := UiTheme.map_mark(str(lm.get("id", "")))
			var col: Color = mk[2]
			var t := UiTheme.tex(str(mk[0]))
			var s := clampf(cell * 1.4, 18.0, 40.0)
			if t != null:
				draw_texture_rect(t, Rect2(pos - Vector2(s, s) * 0.5, Vector2(s, s)), false, col)
		# FB-022: treasure and champion lairs revealed by safe-room maps (faded once looted / slain)
		for poi in pois:
			if not bool(poi.get("revealed", false)):
				continue
			var pw: Vector3 = poi["world_pos"]
			var ppos := origin + Vector2(pw.x, pw.z) / layout.tile_size * cell
			var pm := UiTheme.map_mark(str(poi["kind"]))
			var pcol: Color = pm[2]
			if bool(poi.get("done", false)):
				pcol.a = 0.3
			var ptex := UiTheme.tex(str(pm[0]))
			var ps2 := clampf(cell * 1.1, 14.0, 30.0)
			if ptex != null:
				draw_texture_rect(ptex, Rect2(ppos - Vector2(ps2, ps2) * 0.5, Vector2(ps2, ps2)), false, pcol)
		var pp := origin + player_tile_f * cell
		var pt := UiTheme.tex("icon_player")
		var ps := clampf(cell * 1.2, 16.0, 34.0)
		draw_set_transform(pp, player_yaw, Vector2.ONE)
		if pt != null:
			draw_texture_rect(pt, Rect2(Vector2(-ps, -ps) * 0.5, Vector2(ps, ps)), false, Color(0.75, 0.1, 0.06))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var vig := UiTheme.tex("vignette")
		if vig != null:
			draw_texture_rect(vig, r, false, Color(0.15, 0.08, 0.02, 0.85))


var _canvas: MapCanvas = null
var _floor_lbl: Label = null
var _stats_lbl: Label = null
var _close_cb: Callable = Callable()


func _ready() -> void:
	build_base(20, true)
	_build_ui()


func setup(close_cb: Callable) -> void:
	_close_cb = close_cb


func open_map(layout: DungeonGenerator.FloorLayout, seen: Dictionary, player_pos: Vector3, player_yaw: float, floor_title: String, status: String) -> void:
	_canvas.layout = layout
	_canvas.seen = seen
	_canvas.landmarks = layout.landmarks if layout != null else []
	_canvas.pois = layout.pois if layout != null else []
	_canvas.player_tile_f = Vector2(player_pos.x, player_pos.z) / (layout.tile_size if layout != null else 4.0)
	_canvas.player_yaw = player_yaw
	_canvas.pan = Vector2.ZERO
	_canvas.zoom = 1.0
	_floor_lbl.text = floor_title
	_stats_lbl.text = status
	_canvas.queue_redraw()
	show_animated()


func close_menu() -> void:
	hide_now()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for k in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(k, 40)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	root.add_child(margin)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	margin.add_child(h)
	var mp := PanelContainer.new()
	mp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mp.add_theme_stylebox_override("panel", UiTheme.panel_style("frame"))
	h.add_child(mp)
	_canvas = MapCanvas.new()
	_canvas.clip_contents = true
	_canvas.paper = load("res://assets/ui/map_paper.webp") as Texture2D if ResourceLoader.exists("res://assets/ui/map_paper.webp") else null
	mp.add_child(_canvas)
	var side := PanelContainer.new()
	side.custom_minimum_size.x = 320
	side.add_theme_stylebox_override("panel", UiTheme.panel_style("frame"))
	h.add_child(side)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	side.add_child(v)
	v.add_child(UiTheme.label("MAP", 34, UiTheme.COL_GOLD_BRIGHT, UiTheme.font_title()))
	_floor_lbl = UiTheme.heading("", 18, UiTheme.COL_GOLD)
	_floor_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_floor_lbl)
	_stats_lbl = UiTheme.label("", 17, UiTheme.COL_TEXT, UiTheme.font_ui())
	_stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_stats_lbl)
	v.add_child(UiTheme.divider())
	v.add_child(UiTheme.label("LEGEND", 15, UiTheme.COL_GOLD, UiTheme.font_ui_bold()))
	var legend: Array = [["icon_player", "You", Color(0.9, 0.3, 0.2)]]
	for k in ["safe_room", "boss_arena", "vault", "stairs", "champion", "treasure"]:
		var mk := UiTheme.map_mark(k)
		legend.append([mk[0], mk[3], mk[1]])
	for spec in legend:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 10)
		r.add_child(UiTheme.icon_rect(UiTheme.tex(spec[0]), 22, spec[2]))
		r.add_child(UiTheme.label(spec[1], 18, UiTheme.COL_TEXT, UiTheme.font_ui()))
		v.add_child(r)
	v.add_child(UiTheme.body("Only places you have explored are inked. Landmarks appear once discovered.", 16, UiTheme.COL_MUTED, true))
	var spc := Control.new()
	spc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spc)
	v.add_child(UiTheme.label("Centred on you\nMouse wheel  ·  zoom\nDrag  ·  look around  ·  Space  ·  re-centre", 15, UiTheme.COL_FAINT, UiTheme.font_ui()))
	var close := UiTheme.button("Close  [M]", 0, 18)
	close.pressed.connect(func() -> void:
		if _close_cb.is_valid():
			_close_cb.call()
	)
	v.add_child(close)
