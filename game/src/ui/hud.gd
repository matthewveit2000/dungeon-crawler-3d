class_name GameHud
extends CanvasLayer
## Skyrim-Inspired Dark-Fantasy HUD (v0.1 Visual Polish + Low-Friction Tutorial Card D-030).
## Features scrolling compass ticks & landmark markers, sleek floor clock pill, boss HP bar,
## subtle upper-right Dungeon AI broadcast toast, Skyrim bottom vitals cluster, dynamic crosshair,
## and unobtrusive bottom-right Tutorial Mode card.

var _compass_canvas: Control = null
var _compass_data: Array = []
var _compass_yaw: float = 0.0

var _floor_lbl: Label = null
var _zone_pill: PanelContainer = null
var _zone_lbl: Label = null

var _boss_panel: PanelContainer = null
var _boss_name_lbl: Label = null
var _boss_bar: ProgressBar = null

var _reticle_lbl: Label = null
var _prompt_pill: PanelContainer = null
var _prompt_lbl: Label = null

var _hp_bar: ProgressBar = null
var _hp_lbl: Label = null
var _mp_bar: ProgressBar = null
var _mp_lbl: Label = null
var _sp_bar: ProgressBar = null
var _sp_lbl: Label = null

var _left_hand_lbl: Label = null
var _right_hand_lbl: Label = null
var _gold_lbl: Label = null

var _ai_panel: PanelContainer = null
var _ai_accent: ColorRect = null
var _ai_title: Label = null
var _ai_body: Label = null
var _ai_timer: float = 0.0

var _tut_panel: PanelContainer = null
var _tut_title: Label = null
var _tut_body: Label = null
var _tut_action: Label = null
var _tut_progress: Label = null

var _hit_flash_timer: float = 0.0
var _damage_vignette: ColorRect = null
var _damage_flash: float = 0.0


class CompassStrip extends Control:
	var yaw_rad: float = 0.0
	var markers: Array = []

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var cx := w * 0.5
		var fov_span := PI * 0.85

		# Top & bottom engraved antique gold hairlines
		draw_line(Vector2(16, 2), Vector2(w - 16, 2), Color(0.76, 0.60, 0.30, 0.65), 1.5)
		draw_line(Vector2(16, h - 2), Vector2(w - 16, h - 2), Color(0.76, 0.60, 0.30, 0.45), 1.0)

		# Center pointer diamond
		var tri := PackedVector2Array([Vector2(cx, 1), Vector2(cx - 5, 7), Vector2(cx + 5, 7)])
		draw_colored_polygon(tri, Color(0.98, 0.84, 0.48, 0.95))

		# Minor degree ticks every 15 degrees
		var font := ThemeDB.fallback_font
		for deg in range(0, 360, 15):
			var ang := deg_to_rad(float(deg))
			var diff := wrapf(ang - yaw_rad, -PI, PI)
			if absf(diff) > fov_span * 0.5:
				continue
			var x := cx + (diff / (fov_span * 0.5)) * (w * 0.45)
			var is_card := (deg % 45 == 0)
			var tick_h := 7.0 if is_card else 4.0
			draw_line(Vector2(x, h - 3), Vector2(x, h - 3 - tick_h), Color(0.84, 0.72, 0.46, 0.75 if is_card else 0.35), 1.2)

			if is_card:
				var labels := {0: "N", 45: "NE", 90: "E", 135: "SE", 180: "S", 225: "SW", 270: "W", 315: "NW"}
				var txt: String = labels.get(deg, "")
				var is_main := (deg % 90 == 0)
				var col := Color(0.98, 0.88, 0.62, 0.96) if is_main else Color(0.74, 0.72, 0.66, 0.72)
				var fsize := 13 if is_main else 10
				var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize).x
				draw_string(font, Vector2(x - tw * 0.5, 22), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)

		# Landmarks (SAFE, BOSS, STAIRS — hide pill once already standing inside the room!)
		for m in markers:
			if m.has("distance") and float(m["distance"]) < 4.5:
				continue
			var bx := clampf(float(m.get("bearing_norm", 0.0)), -1.0, 1.0)
			var x := cx + bx * (w * 0.44)
			var kind := str(m.get("kind", ""))
			var tag := str(m.get("label", "*"))
			var col := Color(0.98, 0.84, 0.36)
			if kind == "safe_room":
				col = Color(0.32, 0.94, 0.74)
				tag = "◆ SAFE"
			elif kind == "boss_arena":
				col = Color(1.0, 0.36, 0.28)
				tag = "☠ BOSS"
			elif kind == "stairs":
				col = Color(0.56, 0.84, 1.0)
				tag = "▼ STAIRS"
			var tw := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_CENTER, -1, 11).x
			draw_rect(Rect2(x - tw * 0.5 - 4, 7, tw + 8, 17), Color(0.05, 0.06, 0.09, 0.86), true)
			draw_string(font, Vector2(x - tw * 0.5, 20), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)


func _ready() -> void:
	layer = 10
	_build_ui()
	if EventBus != null:
		EventBus.player_stats_changed.connect(update_stats)
		EventBus.interaction_prompt_changed.connect(set_interact_prompt)
		EventBus.dungeon_ai_announcement.connect(show_ai_announcement)
		EventBus.safe_room_entered.connect(func() -> void:
			set_zone_banner("◆ SAFE ROOM SANCTUARY — NO COMBAT", Color(0.32, 0.94, 0.74))
		)
		EventBus.safe_room_exited.connect(func() -> void:
			set_zone_banner("", Color.WHITE)
		)
		EventBus.boss_arena_sealed.connect(func(bname: String) -> void:
			set_zone_banner("☠ BOSS ARENA SEALED — %s" % bname, Color(1.0, 0.36, 0.28))
		)
		EventBus.boss_defeated.connect(func(_bname: String) -> void:
			set_zone_banner("✦ TREASURE VAULT UNLOCKED!", UiTheme.COL_GOLD_BRIGHT)
			update_boss_bar(false)
		)
		EventBus.skill_improved.connect(func(sname: String, lvl: int) -> void:
			show_ai_announcement("SKILL IMPROVED", "%s reached Level %d!" % [sname.replace("_", " ").capitalize(), lvl], "warning")
		)


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Subtle red edge vignette flash when player takes damage
	_damage_vignette = ColorRect.new()
	_damage_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_damage_vignette.color = Color(0.75, 0.06, 0.04, 0.0)
	_damage_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_damage_vignette)

	# === TOP CENTER: SKYRIM COMPASS + FLOOR CLOCK + OPTIONAL ZONE/BOSS BAR ===
	var top_box := VBoxContainer.new()
	top_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top_box.offset_left = -330
	top_box.offset_right = 330
	top_box.offset_top = 12
	top_box.add_theme_constant_override("separation", 6)
	top_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_box)

	var compass_panel := PanelContainer.new()
	var cstyle := UiTheme.make_panel_style(UiTheme.COL_BG_HUD, Color(0, 0, 0, 0), 0, 4, 0, 0)
	cstyle.shadow_size = 4
	compass_panel.add_theme_stylebox_override("panel", cstyle)
	compass_panel.custom_minimum_size = Vector2(620, 34)
	compass_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_box.add_child(compass_panel)

	var strip := CompassStrip.new()
	strip.custom_minimum_size = Vector2(620, 34)
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	compass_panel.add_child(strip)
	_compass_canvas = strip

	# Floor & 5-Day Countdown pill
	var clock_pill := PanelContainer.new()
	var kstyle := UiTheme.make_panel_style(Color(0.05, 0.058, 0.08, 0.76), UiTheme.COL_GOLD_DIM, 1, 12, 16, 4)
	kstyle.shadow_size = 3
	clock_pill.add_theme_stylebox_override("panel", kstyle)
	clock_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	clock_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_box.add_child(clock_pill)

	_floor_lbl = Label.new()
	_floor_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_floor_lbl.add_theme_font_size_override("font_size", 12)
	_floor_lbl.add_theme_color_override("font_color", UiTheme.COL_GOLD_BRIGHT)
	_floor_lbl.text = "FLOOR 1  •  DAY 1 / 5  |  5.00d UNTIL COLLAPSE"
	clock_pill.add_child(_floor_lbl)

	# Zone Pill (Safe Room / Boss Lockdown)
	_zone_pill = PanelContainer.new()
	_zone_pill.add_theme_stylebox_override("panel", UiTheme.make_panel_style(Color(0.05, 0.14, 0.12, 0.84), Color(0.32, 0.92, 0.72), 1, 10, 14, 3))
	_zone_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_zone_pill.visible = false
	_zone_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_box.add_child(_zone_pill)

	_zone_lbl = Label.new()
	_zone_lbl.add_theme_font_size_override("font_size", 12)
	_zone_pill.add_child(_zone_lbl)

	# Boss Health Bar (dramatic Skyrim/Souls style — only visible during Boss engagement!)
	_boss_panel = PanelContainer.new()
	_boss_panel.add_theme_stylebox_override("panel", UiTheme.make_panel_style(Color(0.08, 0.04, 0.05, 0.88), Color(0.86, 0.30, 0.22), 2, 5, 14, 8))
	_boss_panel.custom_minimum_size = Vector2(520, 48)
	_boss_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_boss_panel.visible = false
	_boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_box.add_child(_boss_panel)

	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 4)
	_boss_panel.add_child(bv)
	_boss_name_lbl = Label.new()
	_boss_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name_lbl.add_theme_font_size_override("font_size", 13)
	_boss_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.56))
	bv.add_child(_boss_name_lbl)
	_boss_bar = ProgressBar.new()
	_boss_bar.show_percentage = false
	UiTheme.style_progress_bar(_boss_bar, Color(0.84, 0.18, 0.14), 12.0)
	bv.add_child(_boss_bar)

	# === TOP-RIGHT: DUNGEON AI BROADCAST TOAST (non-blocking, cleanly below top clock pill!) ===
	_ai_panel = PanelContainer.new()
	_ai_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_ai_panel.offset_left = -360
	_ai_panel.offset_right = -18
	_ai_panel.offset_top = 74
	_ai_panel.add_theme_stylebox_override("panel", UiTheme.make_panel_style(Color(0.06, 0.075, 0.11, 0.90), UiTheme.COL_CYAN, 1, 6, 12, 10))
	_ai_panel.visible = false
	_ai_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_ai_panel)

	var ai_row := HBoxContainer.new()
	ai_row.add_theme_constant_override("separation", 10)
	_ai_panel.add_child(ai_row)

	_ai_accent = ColorRect.new()
	_ai_accent.custom_minimum_size = Vector2(4, 0)
	_ai_accent.color = UiTheme.COL_CYAN
	ai_row.add_child(_ai_accent)

	var ai_v := VBoxContainer.new()
	ai_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ai_v.add_theme_constant_override("separation", 3)
	ai_row.add_child(ai_v)

	_ai_title = Label.new()
	_ai_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ai_title.add_theme_font_size_override("font_size", 12)
	_ai_title.add_theme_color_override("font_color", UiTheme.COL_CYAN)
	ai_v.add_child(_ai_title)

	_ai_body = Label.new()
	_ai_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ai_body.add_theme_font_size_override("font_size", 12)
	_ai_body.add_theme_color_override("font_color", UiTheme.COL_TEXT)
	ai_v.add_child(_ai_body)

	# === CENTER: MINIMAL SKYRIM CROSSHAIR & FLOATING [E] INTERACT PROMPT ===
	_reticle_lbl = Label.new()
	_reticle_lbl.text = "+"
	_reticle_lbl.set_anchors_preset(Control.PRESET_CENTER)
	_reticle_lbl.offset_left = -24
	_reticle_lbl.offset_right = 24
	_reticle_lbl.offset_top = -14
	_reticle_lbl.offset_bottom = 14
	_reticle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reticle_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_reticle_lbl.add_theme_font_size_override("font_size", 18)
	_reticle_lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.88, 0.85))
	_reticle_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_reticle_lbl)

	_prompt_pill = PanelContainer.new()
	_prompt_pill.set_anchors_preset(Control.PRESET_CENTER)
	_prompt_pill.offset_left = -165
	_prompt_pill.offset_right = 165
	_prompt_pill.offset_top = 34
	_prompt_pill.add_theme_stylebox_override("panel", UiTheme.make_panel_style(Color(0.05, 0.058, 0.08, 0.86), UiTheme.COL_GOLD, 1, 6, 14, 6))
	_prompt_pill.visible = false
	_prompt_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_prompt_pill)

	_prompt_lbl = Label.new()
	_prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_lbl.add_theme_font_size_override("font_size", 14)
	_prompt_lbl.add_theme_color_override("font_color", UiTheme.COL_GOLD_BRIGHT)
	_prompt_pill.add_child(_prompt_lbl)

	# === BOTTOM-RIGHT: LOW-FRICTION TUTORIAL MODE CARD (D-030) ===
	_tut_panel = PanelContainer.new()
	_tut_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_tut_panel.offset_left = -360
	_tut_panel.offset_right = -18
	_tut_panel.offset_top = -205
	_tut_panel.offset_bottom = -84
	_tut_panel.add_theme_stylebox_override("panel", UiTheme.make_panel_style(Color(0.07, 0.075, 0.10, 0.90), UiTheme.COL_GOLD, 2, 6, 14, 10))
	_tut_panel.visible = false
	_tut_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_tut_panel)

	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 4)
	_tut_panel.add_child(tv)

	var tut_hdr := HBoxContainer.new()
	tv.add_child(tut_hdr)
	_tut_title = Label.new()
	_tut_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tut_title.add_theme_font_size_override("font_size", 13)
	_tut_title.add_theme_color_override("font_color", UiTheme.COL_GOLD_BRIGHT)
	tut_hdr.add_child(_tut_title)
	_tut_progress = Label.new()
	_tut_progress.add_theme_font_size_override("font_size", 11)
	_tut_progress.add_theme_color_override("font_color", UiTheme.COL_MUTED)
	tut_hdr.add_child(_tut_progress)

	_tut_body = Label.new()
	_tut_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tut_body.add_theme_font_size_override("font_size", 12)
	_tut_body.add_theme_color_override("font_color", UiTheme.COL_TEXT)
	tv.add_child(_tut_body)

	_tut_action = Label.new()
	_tut_action.add_theme_font_size_override("font_size", 11)
	_tut_action.add_theme_color_override("font_color", Color(0.45, 0.90, 0.72))
	tv.add_child(_tut_action)

	# === BOTTOM: SKYRIM-STYLE FRAMED VITALS & CORNER LOADOUT CHIPS ===
	var bot_bar := HBoxContainer.new()
	bot_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bot_bar.offset_left = 20
	bot_bar.offset_right = -20
	bot_bar.offset_top = -70
	bot_bar.offset_bottom = -16
	bot_bar.add_theme_constant_override("separation", 16)
	bot_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bot_bar)

	# Left hand loadout chip
	var lh_panel := PanelContainer.new()
	lh_panel.add_theme_stylebox_override("panel", UiTheme.make_panel_style(UiTheme.COL_BG_HUD, UiTheme.COL_GOLD_DIM, 1, 5, 10, 6))
	lh_panel.custom_minimum_size = Vector2(215, 48)
	bot_bar.add_child(lh_panel)
	_left_hand_lbl = Label.new()
	_left_hand_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_left_hand_lbl.add_theme_font_size_override("font_size", 12)
	_left_hand_lbl.add_theme_color_override("font_color", UiTheme.COL_TEXT)
	lh_panel.add_child(_left_hand_lbl)

	# Center Skyrim 3-bar cluster inside sleek obsidian pill for high contrast over any floor!
	var vitals_wrap := CenterContainer.new()
	vitals_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot_bar.add_child(vitals_wrap)

	var vitals_panel := PanelContainer.new()
	vitals_panel.add_theme_stylebox_override("panel", UiTheme.make_panel_style(Color(0.045, 0.052, 0.072, 0.80), UiTheme.COL_GOLD_DIM, 1, 6, 14, 6))
	vitals_wrap.add_child(vitals_panel)

	var vitals_row := HBoxContainer.new()
	vitals_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vitals_row.add_theme_constant_override("separation", 16)
	vitals_panel.add_child(vitals_row)

	var mp_pair := _make_vital_bar("MAGICKA", UiTheme.COL_SAPPHIRE, 165.0)
	_mp_bar = mp_pair["bar"]
	_mp_lbl = mp_pair["label"]
	vitals_row.add_child(mp_pair["root"])

	var hp_pair := _make_vital_bar("HEALTH", UiTheme.COL_CRIMSON, 220.0)
	_hp_bar = hp_pair["bar"]
	_hp_lbl = hp_pair["label"]
	vitals_row.add_child(hp_pair["root"])

	var sp_pair := _make_vital_bar("STAMINA", UiTheme.COL_EMERALD, 165.0)
	_sp_bar = sp_pair["bar"]
	_sp_lbl = sp_pair["label"]
	vitals_row.add_child(sp_pair["root"])

	# Right hand + Gold chip
	var rh_panel := PanelContainer.new()
	rh_panel.add_theme_stylebox_override("panel", UiTheme.make_panel_style(UiTheme.COL_BG_HUD, UiTheme.COL_GOLD_DIM, 1, 5, 10, 6))
	rh_panel.custom_minimum_size = Vector2(225, 48)
	bot_bar.add_child(rh_panel)
	var rh_v := VBoxContainer.new()
	rh_v.add_theme_constant_override("separation", 1)
	rh_panel.add_child(rh_v)
	_right_hand_lbl = Label.new()
	_right_hand_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_right_hand_lbl.add_theme_font_size_override("font_size", 12)
	_right_hand_lbl.add_theme_color_override("font_color", UiTheme.COL_TEXT)
	rh_v.add_child(_right_hand_lbl)
	_gold_lbl = Label.new()
	_gold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_gold_lbl.add_theme_font_size_override("font_size", 11)
	_gold_lbl.add_theme_color_override("font_color", UiTheme.COL_GOLD_BRIGHT)
	rh_v.add_child(_gold_lbl)


func _make_vital_bar(title: String, col: Color, width: float) -> Dictionary:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(width, 34)
	box.alignment = BoxContainer.ALIGNMENT_END
	box.add_theme_constant_override("separation", 3)

	var top := HBoxContainer.new()
	box.add_child(top)
	var name_l := Label.new()
	name_l.text = title
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.add_theme_font_size_override("font_size", 10)
	name_l.add_theme_color_override("font_color", Color(0.84, 0.80, 0.72))
	top.add_child(name_l)

	var val_l := Label.new()
	val_l.add_theme_font_size_override("font_size", 10)
	val_l.add_theme_color_override("font_color", UiTheme.COL_TEXT)
	top.add_child(val_l)

	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(width, 13)
	UiTheme.style_progress_bar(bar, col, 13.0)
	box.add_child(bar)
	return {"root": box, "bar": bar, "label": val_l}


func _process(delta: float) -> void:
	if _ai_timer > 0.0:
		_ai_timer -= delta
		if _ai_timer <= 0.0:
			_ai_panel.visible = false
	if _hit_flash_timer > 0.0:
		_hit_flash_timer -= delta
		_reticle_lbl.add_theme_color_override("font_color", UiTheme.COL_GOLD_BRIGHT if _hit_flash_timer > 0.0 else Color(1.0, 0.96, 0.88, 0.85))
	if _damage_flash > 0.0:
		_damage_flash = maxf(0.0, _damage_flash - delta * 2.2)
		_damage_vignette.color = Color(0.75, 0.06, 0.04, _damage_flash * 0.28)


func trigger_hit_marker() -> void:
	_hit_flash_timer = 0.16


func trigger_damage_flash() -> void:
	_damage_flash = 1.0


func update_stats(stats: Dictionary) -> void:
	var hp := float(stats.get("health", 100.0))
	var mhp := maxf(1.0, float(stats.get("max_health", 100.0)))
	var mp := float(stats.get("magicka", 100.0))
	var mmp := maxf(1.0, float(stats.get("max_magicka", 100.0)))
	var sp := float(stats.get("stamina", 100.0))
	var msp := maxf(1.0, float(stats.get("max_stamina", 100.0)))

	_hp_bar.max_value = mhp
	_hp_bar.value = hp
	_hp_lbl.text = "%.0f / %.0f" % [hp, mhp]

	_mp_bar.max_value = mmp
	_mp_bar.value = mp
	_mp_lbl.text = "%.0f / %.0f" % [mp, mmp]

	_sp_bar.max_value = msp
	_sp_bar.value = sp
	_sp_lbl.text = "%.0f / %.0f" % [sp, msp]

	var lh := str(stats.get("left_hand_name", "Empty"))
	var rh := str(stats.get("right_hand_name", "Empty"))
	var armor := float(stats.get("armor", 0.0))
	var gold := int(stats.get("gold", 0))
	_left_hand_lbl.text = "[RMB] %s\nArmor: %.0f  •  [1–4] Loadout" % [lh, armor]
	_right_hand_lbl.text = "[LMB] %s" % rh
	_gold_lbl.text = "%d Gold  •  [I] Bag  •  [Q] Potion" % gold

	var draw_r := float(stats.get("bow_draw_ratio", 0.0))
	if draw_r > 0.05:
		_reticle_lbl.text = "[ + ]" if draw_r < 0.72 else "»+«"
	elif bool(stats.get("is_blocking", false)):
		_reticle_lbl.text = "◈"
	else:
		_reticle_lbl.text = "+"


func update_clock(floor_num: int, floor_name: String, formatted_clock: String) -> void:
	_floor_lbl.text = "FLOOR %d • %s   |   %s" % [floor_num, floor_name.to_upper(), formatted_clock.to_upper()]


func update_compass(player_yaw_rad: float, markers: Array) -> void:
	var strip := _compass_canvas as CompassStrip
	if strip != null:
		strip.yaw_rad = player_yaw_rad
		strip.markers = markers
		strip.queue_redraw()


func update_boss_bar(visible_flag: bool, boss_name: String = "", hp: float = 0.0, max_hp: float = 1.0) -> void:
	_boss_panel.visible = visible_flag
	if visible_flag:
		_boss_name_lbl.text = "%s   (%.0f / %.0f HP)" % [boss_name.to_upper(), maxf(0.0, hp), maxf(1.0, max_hp)]
		_boss_bar.max_value = maxf(1.0, max_hp)
		_boss_bar.value = maxf(0.0, hp)


func set_zone_banner(text: String, col: Color) -> void:
	if text.is_empty():
		_zone_pill.visible = false
	else:
		_zone_pill.visible = true
		_zone_pill.add_theme_stylebox_override("panel", UiTheme.make_panel_style(Color(0.06, 0.07, 0.09, 0.88), col, 1, 10, 14, 3))
		_zone_lbl.text = text.to_upper()
		_zone_lbl.add_theme_color_override("font_color", col)


func set_interact_prompt(prompt_text: String) -> void:
	if prompt_text.is_empty():
		_prompt_pill.visible = false
	else:
		_prompt_pill.visible = true
		_prompt_lbl.text = prompt_text


func show_ai_announcement(title: String, body: String, severity: String = "info") -> void:
	_ai_title.text = "⚡ SYNDICATE AI • %s" % title.to_upper()
	_ai_body.text = body
	var col := UiTheme.COL_CYAN
	if severity == "warning":
		col = UiTheme.COL_GOLD_BRIGHT
	elif severity == "danger":
		col = Color(1.0, 0.36, 0.30)
	_ai_accent.color = col
	_ai_title.add_theme_color_override("font_color", col)
	_ai_panel.add_theme_stylebox_override("panel", UiTheme.make_panel_style(Color(0.055, 0.068, 0.10, 0.92), col, 1, 6, 12, 10))
	_ai_panel.visible = true
	_ai_timer = 5.8


func update_tutorial_hint(hint: Dictionary) -> void:
	if hint.is_empty():
		_tut_panel.visible = false
		return
	_tut_panel.visible = true
	_tut_title.text = "✦ %s" % str(hint.get("title", "Tip")).to_upper()
	_tut_progress.text = "%d/%d • [H] Hide" % [int(hint.get("completed_count", 0)), int(hint.get("total_count", 9))]
	_tut_body.text = str(hint.get("body", ""))
	_tut_action.text = "▸ %s" % str(hint.get("action_hint", ""))
