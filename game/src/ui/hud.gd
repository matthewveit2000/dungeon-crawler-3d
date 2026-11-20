class_name GameHud
extends CanvasLayer
## Skyrim-inspired dark-fantasy HUD: gilded compass with landmark icons, slim vitals with damage
## trails that fade when full, contextual crosshair (hit markers, block, bow-draw ring), key-cap
## interaction prompts, equipped-item icons, Dungeon-AI announcement cards, loot toasts, area
## titles, level-up banner, boss bar with enrage marker, tutorial card and damage/low-health vignettes.

const VITAL_FADE_DELAY := 6.0


class CompassStrip extends Control:
	var yaw_rad: float = 0.0
	var markers: Array = []
	var bg: Texture2D = null

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var cx := w * 0.5
		if bg != null:
			draw_texture_rect(bg, Rect2(Vector2.ZERO, size), false)
		var fov_span := deg_to_rad(110.0)
		var font_c := UiTheme.font_heading()
		var font_s := UiTheme.font_ui_semibold()
		if font_c == null:
			font_c = ThemeDB.fallback_font
		if font_s == null:
			font_s = ThemeDB.fallback_font
		for deg in range(0, 360, 5):
			var ang := deg_to_rad(float(deg))
			var diff := wrapf(ang - yaw_rad, -PI, PI)
			if absf(diff) > fov_span * 0.5:
				continue
			var x := cx + (diff / (fov_span * 0.5)) * (w * 0.46)
			var edge := 1.0 - absf(diff) / (fov_span * 0.5)
			var a := clampf(edge * 1.6, 0.0, 1.0)
			if deg % 45 == 0:
				var labels := {0: "N", 45: "NE", 90: "E", 135: "SE", 180: "S", 225: "SW", 270: "W", 315: "NW"}
				var txt: String = labels.get(deg, "")
				var main := deg % 90 == 0
				var fnt := font_c if main else font_s
				var fs := 20 if main else 14
				var tw := fnt.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var col := Color(0.98, 0.86, 0.56, a) if main else Color(0.82, 0.78, 0.7, a * 0.85)
				draw_string(fnt, Vector2(x - tw * 0.5 + 1, h * 0.5 + fs * 0.36 + 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, a * 0.7))
				draw_string(fnt, Vector2(x - tw * 0.5, h * 0.5 + fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
			elif deg % 15 == 0:
				draw_line(Vector2(x, h * 0.5 - 4), Vector2(x, h * 0.5 + 4), Color(0.84, 0.72, 0.46, a * 0.55), 1.4)
			else:
				draw_circle(Vector2(x, h * 0.5), 1.1, Color(0.84, 0.72, 0.46, a * 0.3))
		for m in markers:
			if float(m.get("distance", 99.0)) < 4.0:
				continue
			var nx := clampf(float(m.get("normalized_x", 0.0)), -1.0, 1.0)
			var x := cx + nx * (w * 0.46)
			var id := str(m.get("id", ""))
			var disc := bool(m.get("discovered", false))
			var icon_name := "diamond"
			var col := Color(0.8, 0.78, 0.72)
			if disc:
				match id:
					"safe_room":
						icon_name = "shield"
						col = Color(0.36, 0.95, 0.78)
					"boss_arena":
						icon_name = "skull"
						col = Color(1.0, 0.38, 0.3)
					"vault":
						icon_name = "chest"
						col = Color(1.0, 0.82, 0.36)
					"stairs":
						icon_name = "stairs"
						col = Color(0.55, 0.78, 1.0)
			var t := UiTheme.tex("icon_" + icon_name)
			var s := 22.0
			var dist := float(m.get("distance", 30.0))
			col.a = clampf(1.15 - dist / 70.0, 0.45, 1.0) * clampf((1.0 - absf(nx)) * 3.0, 0.0, 1.0)
			if t != null:
				draw_texture_rect(t, Rect2(x - s * 0.5, h * 0.5 - s * 0.5, s, s), false, col)
		# centre notch
		var gold := Color(0.98, 0.84, 0.48, 0.95)
		draw_colored_polygon(PackedVector2Array([Vector2(cx, h - 2), Vector2(cx - 6, h + 6), Vector2(cx + 6, h + 6)]), gold)
		draw_colored_polygon(PackedVector2Array([Vector2(cx, 2), Vector2(cx - 5, -5), Vector2(cx + 5, -5)]), gold)


class VitalBar extends Control:
	var value: float = 1.0
	var lag: float = 1.0
	var fill_col: Color = Color.RED
	var flash: float = 0.0
	var pulse: float = 0.0
	var reverse: bool = false

	func _process(delta: float) -> void:
		if lag > value:
			lag = maxf(value, lag - delta * 0.35)
		else:
			lag = value
		flash = maxf(0.0, flash - delta * 2.5)
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var inner := r.grow_individual(-7, -5, -7, -5)
		var ft := UiTheme.tex("bar_fill")
		var lag_w := inner.size.x * clampf(lag, 0.0, 1.0)
		var val_w := inner.size.x * clampf(value, 0.0, 1.0)
		var lag_rect := Rect2(inner.position + Vector2((inner.size.x - lag_w) * 0.5 if reverse else 0.0, 0), Vector2(lag_w, inner.size.y))
		var val_rect := Rect2(inner.position + Vector2((inner.size.x - val_w) * 0.5 if reverse else 0.0, 0), Vector2(val_w, inner.size.y))
		var bk := UiTheme.tex("bar_back")
		if bk != null:
			draw_style_box(_nine(bk), r)
		draw_rect(inner, Color(0.02, 0.018, 0.016, 0.6), true)
		if ft != null:
			draw_texture_rect(ft, lag_rect, false, Color(1.0, 0.92, 0.75, 0.75))
			var c := fill_col.lerp(Color.WHITE, flash * 0.5)
			c = c.lightened(pulse * 0.25)
			draw_texture_rect(ft, val_rect, false, c)
		var fr := UiTheme.tex("bar_frame")
		if fr != null:
			draw_style_box(_nine(fr), r)

	func _nine(t: Texture2D) -> StyleBoxTexture:
		var sb := StyleBoxTexture.new()
		sb.texture = t
		sb.texture_margin_left = 12
		sb.texture_margin_right = 12
		sb.texture_margin_top = 8
		sb.texture_margin_bottom = 8
		return sb


class Crosshair extends Control:
	var style: String = "dot"
	var hit_t: float = 0.0
	var draw_ratio: float = 0.0
	var blocking: bool = false
	var interact: bool = false

	func _process(delta: float) -> void:
		hit_t = maxf(0.0, hit_t - delta)
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var col := Color(1.0, 0.96, 0.88, 0.9) if not interact else Color(0.98, 0.85, 0.5, 1.0)
		if style == "none" and draw_ratio <= 0.0:
			return
		if blocking:
			var sh := UiTheme.tex("icon_shield")
			if sh != null:
				draw_texture_rect(sh, Rect2(c - Vector2(10, 10), Vector2(20, 20)), false, Color(0.95, 0.85, 0.6, 0.85))
		elif draw_ratio > 0.02:
			var rad := lerpf(26.0, 7.0, clampf(draw_ratio, 0.0, 1.0))
			var full := draw_ratio >= 0.98
			draw_arc(c, rad, 0, TAU, 40, Color(0.98, 0.85, 0.5, 0.35 + 0.5 * draw_ratio), 1.6 if not full else 2.4, true)
			draw_circle(c, 1.8, Color(1, 1, 1, 0.95))
		elif style == "cross":
			for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				draw_line(c + d * 4.0, c + d * 11.0, Color(0, 0, 0, 0.6), 3.0)
				draw_line(c + d * 4.0, c + d * 11.0, col, 1.6)
		else:
			draw_circle(c, 3.4, Color(0, 0, 0, 0.55))
			draw_circle(c, 2.2 if not interact else 3.0, col)
		if hit_t > 0.0:
			var a := hit_t / 0.18
			for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
				var dn: Vector2 = d.normalized()
				draw_line(c + dn * 8.0, c + dn * 15.0, Color(1.0, 0.86, 0.5, a), 2.2)


var _root: Control = null
var _compass: CompassStrip = null
var _floor_lbl: Label = null
var _test_tag: Label = null
var minimap: MiniMap = null
var _clock_lbl: Label = null
var _zone_pill: PanelContainer = null
var _zone_lbl: Label = null
var _zone_icon: TextureRect = null

var _boss_box: Control = null
var _boss_name_lbl: Label = null
var _boss_sub: Label = null
var _boss_bar: VitalBar = null

var _hp: VitalBar = null
var _mp: VitalBar = null
var _sp: VitalBar = null
var _vitals_box: Control = null
var _vitals_idle: float = 0.0
var _vitals_alpha: float = 1.0
var _hp_ratio: float = 1.0

var _crosshair: Crosshair = null
var _prompt_box: HBoxContainer = null
var _prompt_key: PanelContainer = null
var _prompt_verb: Label = null
var _prompt_target: Label = null
var _prompt_alpha: float = 0.0
var _prompt_want: bool = false

var _left_icon: TextureRect = null
var _left_name: Label = null
var _right_icon: TextureRect = null
var _right_name: Label = null
var _left_hint: Label = null
var _right_hint: Label = null
var _gold_lbl: Label = null
var _potion_lbl: Label = null

var _ai_card: PanelContainer = null
var _ai_kicker: Label = null
var _ai_title: Label = null
var _ai_body: Label = null
var _ai_stripe: ColorRect = null
var _ai_timer: float = 0.0
var _ai_queue: Array = []

var _toast_box: VBoxContainer = null
var _area_box: VBoxContainer = null
var _area_title: Label = null
var _area_sub: Label = null
var _area_t: float = 0.0
var _levelup_box: VBoxContainer = null
var _levelup_lbl: Label = null
var _levelup_t: float = 0.0

var _tut_panel: PanelContainer = null
var _tut_kicker: Label = null
var _tut_title: Label = null
var _tut_body: Label = null
var _tut_action: Label = null

var _vignette: TextureRect = null
var _damage_flash: float = 0.0
var _heal_flash: float = 0.0
var _lowhp_phase: float = 0.0
var _fps_lbl: Label = null


func _ready() -> void:
	layer = 10
	_build_ui()
	if EventBus != null:
		EventBus.player_stats_changed.connect(update_stats)
		EventBus.interaction_prompt_changed.connect(set_interact_prompt)
		EventBus.dungeon_ai_announcement.connect(show_ai_announcement)
		EventBus.safe_room_entered.connect(func() -> void:
			set_zone_banner("Sanctuary — No Combat", Color(0.36, 0.95, 0.78))
			show_area_title("Safe Room Sanctuary", "Monsters cannot follow you here", Color(0.62, 0.98, 0.86))
		)
		EventBus.safe_room_exited.connect(func() -> void:
			set_zone_banner("", Color.WHITE)
		)
		EventBus.boss_arena_sealed.connect(func(bname: String) -> void:
			set_zone_banner("Arena Sealed", Color(1.0, 0.4, 0.32))
			show_area_title(bname, "The gate slams shut behind you", Color(1.0, 0.55, 0.45))
		)
		EventBus.boss_defeated.connect(func(_bname: String) -> void:
			set_zone_banner("", Color.WHITE)
			show_area_title("Treasure Vault Unlocked", "The Iron Warden has fallen", UiTheme.COL_GOLD_BRIGHT)
			update_boss_bar(false)
		)
		EventBus.skill_improved.connect(func(sname: String, lvl: int) -> void:
			show_toast(null, "%s increased to %d" % [sname.replace("_", " ").capitalize(), lvl], UiTheme.COL_CYAN)
		)
		EventBus.item_acquired.connect(func(item: Dictionary) -> void:
			show_toast(UiTheme.item_icon(item), str(item.get("name", "Item")), UiTheme.rarity_color(str(item.get("rarity", "common"))))
		)
		EventBus.level_up_occurred.connect(show_level_up)
		EventBus.floor_entered.connect(func(fnum: int, fname: String, _seed: int) -> void:
			show_area_title(fname, "Floor %d  ·  The floor collapses in 5 days" % fnum, UiTheme.COL_GOLD_BRIGHT)
		)
	if GameSettings != null:
		GameSettings.changed.connect(func(_s: String, _k: String, _v: Variant) -> void: _apply_settings())
	_apply_settings()


func _apply_settings() -> void:
	if GameSettings == null:
		return
	_root.modulate.a = clampf(float(GameSettings.get_value("gameplay", "hud_opacity")), 0.25, 1.0)
	_crosshair.style = str(GameSettings.get_value("gameplay", "crosshair"))
	_compass.get_parent().visible = bool(GameSettings.get_value("gameplay", "compass"))
	_fps_lbl.visible = bool(GameSettings.get_value("graphics", "show_fps"))


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.get_theme()
	add_child(_root)

	_vignette = TextureRect.new()
	_vignette.texture = UiTheme.tex("vignette")
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate = Color(0, 0, 0, 0.38)
	_root.add_child(_vignette)

	# --- Minimap locked onto the player (D-046) ---------------------------------
	minimap = MiniMap.new()
	minimap.name = "MiniMap"
	minimap.position = Vector2(18, 18)
	minimap.size = Vector2(190, 190)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap.modulate.a = 0.92
	_root.add_child(minimap)
	_test_tag = UiTheme.label("TEST MODE  ·  F1 tools", 15, UiTheme.COL_GOLD_BRIGHT, UiTheme.font_heading())
	_test_tag.position = Vector2(20, 214)
	_test_tag.visible = false
	_test_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_test_tag)

	# --- Compass & floor clock -------------------------------------------------
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.offset_left = -300
	top.offset_right = 300
	top.offset_top = 12
	top.add_theme_constant_override("separation", 2)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top)
	_compass = CompassStrip.new()
	_compass.bg = UiTheme.tex("compass_bg")
	_compass.custom_minimum_size = Vector2(600, 40)
	_compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_compass)
	_floor_lbl = UiTheme.label("", 14, Color(0.9, 0.8, 0.6, 0.9), UiTheme.font_heading(), HORIZONTAL_ALIGNMENT_CENTER)
	top.add_child(_floor_lbl)
	_clock_lbl = UiTheme.label("", 16, UiTheme.COL_MUTED, UiTheme.font_ui(), HORIZONTAL_ALIGNMENT_CENTER)
	top.add_child(_clock_lbl)
	var zone_row := CenterContainer.new()
	zone_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(zone_row)
	_zone_pill = PanelContainer.new()
	_zone_pill.add_theme_stylebox_override("panel", UiTheme.panel_style("soft"))
	zone_row.add_child(_zone_pill)
	var zh := HBoxContainer.new()
	zh.add_theme_constant_override("separation", 6)
	_zone_pill.add_child(zh)
	_zone_icon = UiTheme.icon_rect(UiTheme.tex("icon_shield"), 16)
	zh.add_child(_zone_icon)
	_zone_lbl = UiTheme.label("", 15, Color.WHITE, UiTheme.font_ui_bold())
	zh.add_child(_zone_lbl)
	_zone_pill.visible = false

	# --- Boss bar ------------------------------------------------------------------
	_boss_box = VBoxContainer.new()
	_boss_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_box.offset_left = -300
	_boss_box.offset_right = 300
	_boss_box.offset_top = 128
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_box.add_theme_constant_override("separation", 2)
	_root.add_child(_boss_box)
	_boss_name_lbl = UiTheme.label("", 24, Color(1.0, 0.82, 0.62), UiTheme.font_heading(), HORIZONTAL_ALIGNMENT_CENTER)
	_boss_box.add_child(_boss_name_lbl)
	_boss_bar = VitalBar.new()
	_boss_bar.custom_minimum_size = Vector2(600, 22)
	_boss_bar.fill_col = Color(0.78, 0.14, 0.1)
	_boss_bar.reverse = true
	_boss_box.add_child(_boss_bar)
	_boss_sub = UiTheme.label("", 15, UiTheme.COL_MUTED, UiTheme.font_ui(), HORIZONTAL_ALIGNMENT_CENTER)
	_boss_box.add_child(_boss_sub)
	_boss_box.visible = false

	# --- Crosshair & prompt ----------------------------------------------------------
	_crosshair = Crosshair.new()
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.offset_left = -40
	_crosshair.offset_right = 40
	_crosshair.offset_top = -40
	_crosshair.offset_bottom = 40
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_crosshair)

	var pc := CenterContainer.new()
	pc.set_anchors_preset(Control.PRESET_CENTER)
	pc.offset_left = -300
	pc.offset_right = 300
	pc.offset_top = 46
	pc.offset_bottom = 110
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(pc)
	_prompt_box = HBoxContainer.new()
	_prompt_box.add_theme_constant_override("separation", 10)
	_prompt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(_prompt_box)
	_prompt_key = UiTheme.keycap("E", 18)
	_prompt_box.add_child(_prompt_key)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", -4)
	_prompt_box.add_child(pv)
	_prompt_verb = UiTheme.label("", 15, UiTheme.COL_GOLD, UiTheme.font_ui_bold())
	pv.add_child(_prompt_verb)
	_prompt_target = UiTheme.label("", 22, UiTheme.COL_TEXT, UiTheme.font_heading())
	pv.add_child(_prompt_target)
	_prompt_box.modulate.a = 0.0

	# --- Vitals ------------------------------------------------------------------------
	_vitals_box = HBoxContainer.new()
	_vitals_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_vitals_box.offset_left = -400
	_vitals_box.offset_right = 400
	_vitals_box.offset_top = -46
	_vitals_box.offset_bottom = -22
	_vitals_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_vitals_box.add_theme_constant_override("separation", 26)
	_vitals_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_vitals_box)
	_mp = _make_vital(UiTheme.COL_MAGICKA, 210)
	_hp = _make_vital(UiTheme.COL_HEALTH, 260)
	_hp.reverse = true
	_sp = _make_vital(UiTheme.COL_STAMINA, 210)

	# --- Equipped hands (bottom corners) -------------------------------------------------
	var lb := _make_hand_box(true)
	_root.add_child(lb)
	var rb := _make_hand_box(false)
	_root.add_child(rb)

	# --- AI announcement card --------------------------------------------------------------
	_ai_card = PanelContainer.new()
	_ai_card.add_theme_stylebox_override("panel", UiTheme.panel_style("soft"))
	_ai_card.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_ai_card.offset_left = -420
	_ai_card.offset_right = -22
	_ai_card.offset_top = 22
	_ai_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_ai_card)
	var ah := HBoxContainer.new()
	ah.add_theme_constant_override("separation", 12)
	_ai_card.add_child(ah)
	_ai_stripe = ColorRect.new()
	_ai_stripe.custom_minimum_size = Vector2(3, 0)
	_ai_stripe.color = UiTheme.COL_CYAN
	ah.add_child(_ai_stripe)
	var av := VBoxContainer.new()
	av.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	av.add_theme_constant_override("separation", 1)
	ah.add_child(av)
	_ai_kicker = UiTheme.label("SYNDICATE AI  ·  BROADCAST", 13, UiTheme.COL_CYAN, UiTheme.font_ui_bold())
	av.add_child(_ai_kicker)
	_ai_title = UiTheme.label("", 18, UiTheme.COL_GOLD_BRIGHT, UiTheme.font_heading())
	_ai_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	av.add_child(_ai_title)
	_ai_body = UiTheme.body("", 17, UiTheme.COL_TEXT)
	av.add_child(_ai_body)
	_ai_card.visible = false

	# --- Loot toasts -------------------------------------------------------------------------
	_toast_box = VBoxContainer.new()
	_toast_box.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_toast_box.offset_left = 26
	_toast_box.offset_right = 420
	_toast_box.offset_top = -40
	_toast_box.offset_bottom = 200
	_toast_box.add_theme_constant_override("separation", 6)
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toast_box)

	# --- Area title & level-up banner ---------------------------------------------------------
	_area_box = VBoxContainer.new()
	_area_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_area_box.offset_left = -480
	_area_box.offset_right = 480
	_area_box.offset_top = 190
	_area_box.add_theme_constant_override("separation", 2)
	_area_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_area_box)
	_area_title = UiTheme.label("", 44, UiTheme.COL_GOLD_BRIGHT, UiTheme.font_heading(), HORIZONTAL_ALIGNMENT_CENTER)
	_area_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_area_title.add_theme_constant_override("shadow_offset_y", 3)
	_area_box.add_child(_area_title)
	var dv := UiTheme.divider(520)
	dv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_area_box.add_child(dv)
	_area_sub = UiTheme.label("", 20, UiTheme.COL_TEXT, UiTheme.font_italic(), HORIZONTAL_ALIGNMENT_CENTER)
	_area_box.add_child(_area_sub)
	_area_box.modulate.a = 0.0

	_levelup_box = VBoxContainer.new()
	_levelup_box.set_anchors_preset(Control.PRESET_CENTER)
	_levelup_box.offset_left = -400
	_levelup_box.offset_right = 400
	_levelup_box.offset_top = -170
	_levelup_box.offset_bottom = -60
	_levelup_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_levelup_box)
	var lu := UiTheme.label("LEVEL UP", 52, UiTheme.COL_GOLD_BRIGHT, UiTheme.font_title(), HORIZONTAL_ALIGNMENT_CENTER)
	_levelup_box.add_child(lu)
	_levelup_lbl = UiTheme.label("", 20, UiTheme.COL_TEXT, UiTheme.font_ui(), HORIZONTAL_ALIGNMENT_CENTER)
	_levelup_box.add_child(_levelup_lbl)
	_levelup_box.modulate.a = 0.0

	# --- Tutorial card -------------------------------------------------------------------------
	_tut_panel = PanelContainer.new()
	_tut_panel.add_theme_stylebox_override("panel", UiTheme.panel_style("soft"))
	_tut_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_tut_panel.offset_left = -400
	_tut_panel.offset_right = -22
	_tut_panel.offset_top = -270
	_tut_panel.offset_bottom = -112
	_tut_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_tut_panel)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 3)
	_tut_panel.add_child(tv)
	_tut_kicker = UiTheme.label("", 13, UiTheme.COL_GOLD, UiTheme.font_ui_bold())
	tv.add_child(_tut_kicker)
	_tut_title = UiTheme.label("", 19, UiTheme.COL_GOLD_BRIGHT, UiTheme.font_heading())
	tv.add_child(_tut_title)
	_tut_body = UiTheme.body("", 17, UiTheme.COL_TEXT)
	tv.add_child(_tut_body)
	_tut_action = UiTheme.label("", 16, UiTheme.COL_CYAN, UiTheme.font_ui_semibold())
	_tut_action.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(_tut_action)
	_tut_panel.visible = false

	_fps_lbl = UiTheme.label("", 14, UiTheme.COL_MUTED, UiTheme.font_ui())
	_fps_lbl.position = Vector2(12, 8)
	_root.add_child(_fps_lbl)


func _make_vital(col: Color, w: float) -> VitalBar:
	var b := VitalBar.new()
	b.fill_col = col
	b.custom_minimum_size = Vector2(w, 22)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vitals_box.add_child(b)
	return b


func _make_hand_box(left: bool) -> Control:
	var box := HBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT if left else Control.PRESET_BOTTOM_RIGHT)
	if left:
		box.offset_left = 24
		box.offset_right = 400
	else:
		box.offset_left = -400
		box.offset_right = -24
		box.alignment = BoxContainer.ALIGNMENT_END
	box.offset_top = -86
	box.offset_bottom = -18
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := TextureRect.new()
	ic.custom_minimum_size = Vector2(60, 60)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -2)
	v.alignment = BoxContainer.ALIGNMENT_END
	var nm := UiTheme.label("", 18, UiTheme.COL_TEXT, UiTheme.font_ui_semibold(), HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT)
	nm.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	var hint := UiTheme.label("RMB  ·  Block / Cast" if left else "LMB  ·  Attack (hold for power)", 13, UiTheme.COL_MUTED, UiTheme.font_ui(),
		HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT)
	v.add_child(nm)
	v.add_child(hint)
	if left:
		_left_icon = ic
		_left_name = nm
		_left_hint = hint
		box.add_child(ic)
		box.add_child(v)
	else:
		_right_icon = ic
		_right_name = nm
		_right_hint = hint
		_gold_lbl = UiTheme.label("", 15, UiTheme.COL_GOLD, UiTheme.font_ui_semibold(), HORIZONTAL_ALIGNMENT_RIGHT)
		v.add_child(_gold_lbl)
		box.add_child(v)
		box.add_child(ic)
	if left:
		_potion_lbl = UiTheme.label("", 14, UiTheme.COL_MUTED, UiTheme.font_ui(), HORIZONTAL_ALIGNMENT_LEFT)
		v.add_child(_potion_lbl)
	return box


func _process(delta: float) -> void:
	# Announcements
	if _ai_timer > 0.0:
		_ai_timer -= delta
		_ai_card.modulate.a = clampf(_ai_timer / 0.4, 0.0, 1.0)
		if _ai_timer <= 0.0:
			_ai_card.visible = false
			if not _ai_queue.is_empty():
				var n: Array = _ai_queue.pop_front()
				_show_ai_now(n[0], n[1], n[2])
	# Prompt fade
	_prompt_alpha = move_toward(_prompt_alpha, 1.0 if _prompt_want else 0.0, delta * 8.0)
	_prompt_box.modulate.a = _prompt_alpha
	# Area title
	if _area_t > 0.0:
		_area_t -= delta
		var a := clampf(minf((4.6 - _area_t) / 0.6, _area_t / 1.0), 0.0, 1.0)
		_area_box.modulate.a = a
	if _levelup_t > 0.0:
		_levelup_t -= delta
		_levelup_box.modulate.a = clampf(minf((3.6 - _levelup_t) / 0.3, _levelup_t / 0.8), 0.0, 1.0)
		_levelup_box.scale = Vector2.ONE * (1.0 + maxf(0.0, _levelup_t - 3.3) * 0.3)
	# Vital fade when full & idle (Skyrim-style), always visible in combat or when hurt
	var full := _hp.value >= 0.999 and _mp.value >= 0.999 and _sp.value >= 0.999
	_vitals_idle = _vitals_idle + delta if full else 0.0
	var target_a := 0.6 if _vitals_idle > VITAL_FADE_DELAY else 1.0
	_vitals_alpha = move_toward(_vitals_alpha, target_a, delta * 1.5)
	_vitals_box.modulate.a = _vitals_alpha
	# Damage / heal / low-health vignettes
	var reduce := GameSettings != null and bool(GameSettings.get_value("accessibility", "reduce_flashing"))
	_damage_flash = maxf(0.0, _damage_flash - delta * 2.0)
	_heal_flash = maxf(0.0, _heal_flash - delta * 1.5)
	var low := clampf((0.3 - _hp_ratio) / 0.3, 0.0, 1.0)
	_lowhp_phase += delta * (2.0 + low * 3.0)
	var pulse := (0.5 + 0.5 * sin(_lowhp_phase)) * low * (0.35 if reduce else 0.6)
	var red := maxf(_damage_flash * (0.4 if reduce else 0.85), pulse)
	var col := Color(0, 0, 0, 0.38).lerp(Color(0.55, 0.02, 0.0, 0.95), clampf(red, 0.0, 1.0))
	if _heal_flash > 0.0:
		col = col.lerp(Color(0.25, 0.75, 0.45, 0.7), _heal_flash * 0.5)
	_vignette.modulate = col
	_hp.pulse = pulse
	for t in _toast_box.get_children():
		var age := float(t.get_meta("age", 0.0)) + delta
		t.set_meta("age", age)
		t.modulate.a = clampf(minf(age / 0.25, (4.5 - age) / 0.6), 0.0, 1.0)
		if age > 4.5:
			t.queue_free()
	if _fps_lbl.visible:
		_fps_lbl.text = "%d FPS" % Engine.get_frames_per_second()


# --- Public API ---------------------------------------------------------------------------

func trigger_hit_marker() -> void:
	_crosshair.hit_t = 0.18


func trigger_damage_flash() -> void:
	_damage_flash = 1.0
	_hp.flash = 1.0


func trigger_heal_flash() -> void:
	_heal_flash = 1.0


func update_stats(stats: Dictionary) -> void:
	var hp := float(stats.get("health", 100.0))
	var mhp := maxf(1.0, float(stats.get("max_health", 100.0)))
	var mp := float(stats.get("magicka", 100.0))
	var mmp := maxf(1.0, float(stats.get("max_magicka", 100.0)))
	var sp := float(stats.get("stamina", 100.0))
	var msp := maxf(1.0, float(stats.get("max_stamina", 100.0)))
	var new_hp := hp / mhp
	if new_hp > _hp_ratio + 0.02:
		_heal_flash = maxf(_heal_flash, 0.6)
	_hp_ratio = new_hp
	_hp.value = new_hp
	_mp.value = mp / mmp
	_sp.value = sp / msp
	var rh := str(stats.get("right_hand_name", "Empty"))
	var lh := str(stats.get("left_hand_name", "Empty"))
	var rh_item: Dictionary = stats.get("right_hand_item", {})
	var is_bow := str(rh_item.get("weapon_type", "")) == "archery"
	var both_hands := is_bow or bool(rh_item.get("two_handed", false))
	_right_name.text = rh
	_right_hint.text = "LMB  ·  Hold to draw, release to loose" if is_bow else (
		"LMB  ·  Cast" if str(rh_item.get("category", "")) == "spell" else "LMB  ·  Attack (hold for power)")
	if stats.has("right_hand_item"):
		_right_icon.texture = UiTheme.item_icon(rh_item)
	if both_hands and lh == "Empty":
		# Two-handed weapons and bows occupy the off hand too: say so instead of "Empty"
		_left_name.text = "Both hands"
		_left_hint.text = "Bow held in the off hand" if is_bow else "Two-handed grip"
		_left_icon.texture = UiTheme.item_icon(rh_item)
		_left_icon.modulate = Color(1, 1, 1, 0.45)
	else:
		_left_name.text = lh
		var lcat := str(stats.get("left_hand_item", {}).get("category", ""))
		_left_hint.text = "RMB  ·  Cast" if lcat == "spell" else ("RMB  ·  Attack" if lcat == "weapon" else "RMB  ·  Block")
		_left_icon.modulate = Color.WHITE
		if stats.has("left_hand_item"):
			_left_icon.texture = UiTheme.item_icon(stats["left_hand_item"])
	_gold_lbl.text = "%d gold  ·  Armor %d" % [int(stats.get("gold", 0)), int(stats.get("armor", 0.0))]
	var pots := int(stats.get("health_potions", -1))
	_potion_lbl.text = ("Q  ·  Health Draught ×%d" % pots) if pots >= 0 else ""
	_crosshair.draw_ratio = float(stats.get("bow_draw_ratio", 0.0))
	_crosshair.blocking = bool(stats.get("is_blocking", false))


func update_clock(floor_num: int, floor_name: String, formatted_clock: String) -> void:
	_floor_lbl.text = "FLOOR %d  ·  %s" % [floor_num, floor_name.to_upper()]
	_clock_lbl.text = formatted_clock.replace("|", "·")
	var days_left := 99.0
	var parts := formatted_clock.split("|")
	if parts.size() > 1:
		days_left = parts[1].strip_edges().to_float()
	var urgent := days_left < 1.0
	_clock_lbl.add_theme_color_override("font_color", UiTheme.COL_DANGER if urgent else UiTheme.COL_MUTED)


func set_test_mode(on: bool) -> void:
	if _test_tag != null:
		_test_tag.visible = on


func update_minimap(layout: DungeonGenerator.FloorLayout, seen: Dictionary, player_pos: Vector3, yaw: float) -> void:
	if minimap != null:
		minimap.refresh(layout, seen, player_pos, yaw)


func update_compass(player_yaw_rad: float, markers: Array) -> void:
	_compass.yaw_rad = player_yaw_rad
	_compass.markers = markers
	_compass.queue_redraw()


func update_boss_bar(visible_flag: bool, boss_name: String = "", hp: float = 0.0, max_hp: float = 1.0) -> void:
	_boss_box.visible = visible_flag
	if visible_flag:
		var enraged := boss_name.find("[ENRAGED]") >= 0
		_boss_name_lbl.text = boss_name.replace(" [ENRAGED]", "")
		_boss_sub.text = "ENRAGED  ·  FURNACE CORE OVERDRIVE" if enraged else "FLOOR BOSS"
		_boss_sub.add_theme_color_override("font_color", UiTheme.COL_DANGER if enraged else UiTheme.COL_MUTED)
		_boss_bar.value = clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)
		_boss_bar.fill_col = Color(0.95, 0.3, 0.08) if enraged else Color(0.78, 0.14, 0.1)


## Drops queued/visible broadcasts, toasts and the area title (e.g. after a floor change or teleport).
func clear_transient_messages() -> void:
	if _ai_card == null:
		return
	_ai_queue.clear()
	_ai_timer = 0.0
	_ai_card.visible = false
	_area_t = 0.0
	_area_box.modulate.a = 0.0
	for t in _toast_box.get_children():
		t.queue_free()


func set_zone_banner(text: String, col: Color) -> void:
	if text.is_empty():
		_zone_pill.visible = false
		return
	_zone_pill.visible = true
	_zone_lbl.text = text.to_upper()
	_zone_lbl.add_theme_color_override("font_color", col)
	_zone_icon.texture = UiTheme.tex("icon_skull" if col.r > col.g else "icon_shield")
	_zone_icon.modulate = col


func set_interact_prompt(prompt_text: String) -> void:
	if prompt_text.is_empty():
		_prompt_want = false
		_crosshair.interact = false
		return
	var txt := prompt_text
	var key := "E"
	if txt.begins_with("["):
		var close := txt.find("]")
		if close > 0:
			key = txt.substr(1, close - 1)
			txt = txt.substr(close + 1).strip_edges()
	if GameSettings != null:
		key = GameSettings.action_label("interact")
	var parts := txt.split(" ", false, 1)
	_prompt_verb.text = (parts[0] if parts.size() > 1 else "Use").to_upper()
	_prompt_target.text = parts[1] if parts.size() > 1 else txt
	(_prompt_key.get_child(0) as Label).text = key
	_prompt_want = true
	_crosshair.interact = true


func show_ai_announcement(title: String, body: String, severity: String = "info") -> void:
	if _ai_card.visible and _ai_timer > 0.8:
		if _ai_queue.size() < 3:
			_ai_queue.append([title, body, severity])
		return
	_show_ai_now(title, body, severity)


func _show_ai_now(title: String, body: String, severity: String) -> void:
	var col := UiTheme.COL_CYAN
	if severity == "warning":
		col = UiTheme.COL_GOLD_BRIGHT
	elif severity == "danger":
		col = UiTheme.COL_DANGER
	_ai_stripe.color = col
	_ai_kicker.add_theme_color_override("font_color", col)
	_ai_title.text = title.capitalize() if title == title.to_upper() else title
	_ai_body.text = body
	_ai_card.visible = true
	_ai_card.modulate.a = 1.0
	var subs := GameSettings == null or bool(GameSettings.get_value("accessibility", "subtitles"))
	_ai_body.visible = subs
	_ai_timer = 6.5


func show_toast(icon: Texture2D, text: String, col: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon != null:
		row.add_child(UiTheme.icon_rect(icon, 36))
	else:
		row.add_child(UiTheme.icon_rect(UiTheme.tex("icon_diamond"), 18, col))
	var l := UiTheme.label(text, 19, col, UiTheme.font_ui_semibold())
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	row.add_child(l)
	row.set_meta("age", 0.0)
	_toast_box.add_child(row)
	while _toast_box.get_child_count() > 5:
		_toast_box.get_child(0).free()


func show_area_title(title: String, subtitle: String, col: Color = UiTheme.COL_GOLD_BRIGHT) -> void:
	_area_title.text = title.to_upper()
	_area_title.add_theme_color_override("font_color", col)
	_area_sub.text = subtitle
	_area_t = 4.6


func show_level_up(new_level: int) -> void:
	_levelup_lbl.text = "Level %d  ·  New attribute & perk points — open your character menu [%s]" % [new_level,
		GameSettings.action_label("toggle_inventory") if GameSettings != null else "Tab"]
	_levelup_box.pivot_offset = _levelup_box.size * 0.5
	_levelup_t = 3.6


func update_tutorial_hint(hint: Dictionary) -> void:
	if hint.is_empty():
		_tut_panel.visible = false
		return
	_tut_panel.visible = true
	_tut_kicker.text = "FIELD GUIDE  ·  %d OF %d  ·  [%s] HIDE" % [int(hint.get("completed_count", 0)) + 1, int(hint.get("total_count", 9)),
		GameSettings.action_label("dismiss_hint") if GameSettings != null else "H"]
	_tut_title.text = str(hint.get("title", "Tip"))
	_tut_body.text = str(hint.get("body", ""))
	_tut_action.text = str(hint.get("action_hint", ""))
