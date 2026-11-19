class_name GameHud
extends CanvasLayer
## Skyrim-Inspired In-Game HUD: Top Compass Bar, 5-Day Collapse Clock,
## Health/Magicka/Stamina Bars, Crosshair & Interact Prompt, Equipped Hands,
## and Snarky Dungeon AI Announcement Banners.

var _compass_panel: Panel = null
var _compass_markers_root: Control = null
var _clock_label: Label = null
var _zone_label: Label = null
var _hp_bar: ProgressBar = null
var _mp_bar: ProgressBar = null
var _sp_bar: ProgressBar = null
var _hands_label: Label = null
var _prompt_label: Label = null
var _crosshair: Label = null
var _ai_banner: PanelContainer = null
var _ai_title: Label = null
var _ai_body: Label = null
var _ai_banner_timer: float = 0.0
var _controls_hint: Label = null


func _ready() -> void:
	layer = 5
	_build_ui()
	if EventBus != null:
		EventBus.player_stats_changed.connect(_on_stats_changed)
		EventBus.interaction_prompt_changed.connect(_on_prompt_changed)
		EventBus.dungeon_ai_announcement.connect(_on_ai_announcement)
		EventBus.safe_room_entered.connect(func() -> void: _set_zone_text("SAFE ROOM — ENEMIES BARRED BY SYNDICATE LAW", Color(0.42, 0.92, 0.76)))
		EventBus.safe_room_exited.connect(func() -> void: _set_zone_text("", Color.WHITE))
		EventBus.boss_arena_sealed.connect(func(bname: String) -> void: _set_zone_text("BOSS LOCKDOWN: %s" % bname.to_upper(), Color(1.0, 0.35, 0.25)))
		EventBus.boss_defeated.connect(func(_bname: String) -> void: _set_zone_text("TREASURE VAULT UNSEALED!", Color(1.0, 0.82, 0.25)))


func _process(delta: float) -> void:
	if _ai_banner_timer > 0.0:
		_ai_banner_timer -= delta
		if _ai_banner_timer <= 0.0 and _ai_banner != null:
			_ai_banner.visible = false


func update_compass(cardinals: Array[Dictionary], landmarks: Array[Dictionary]) -> void:
	if _compass_markers_root == null:
		return
	for c in _compass_markers_root.get_children():
		c.queue_free()

	var bar_w := 440.0
	var half_w := bar_w * 0.5
	for card in cardinals:
		var lbl := Label.new()
		lbl.text = str(card["label"])
		lbl.modulate = Color(0.78, 0.82, 0.88)
		lbl.position = Vector2(half_w + float(card["normalized_x"]) * (half_w - 18.0) - 6.0, 4.0)
		_compass_markers_root.add_child(lbl)

	for lm in landmarks:
		var lbl := Label.new()
		var disc := bool(lm.get("discovered", false))
		lbl.text = "[%s]" % str(lm["icon"]) if disc else "[?]"
		lbl.modulate = Color(1.0, 0.78, 0.25) if disc else Color(0.7, 0.74, 0.8)
		lbl.position = Vector2(half_w + float(lm["normalized_x"]) * (half_w - 22.0) - 12.0, 4.0)
		_compass_markers_root.add_child(lbl)


func update_clock(floor_num: int, floor_name: String, clock_text: String) -> void:
	if _clock_label != null:
		_clock_label.text = "Floor %d: %s  •  %s" % [floor_num, floor_name, clock_text]


func _on_stats_changed(stats: Dictionary) -> void:
	if _hp_bar == null:
		return
	_hp_bar.max_value = float(stats["max_health"])
	_hp_bar.value = float(stats["health"])
	_mp_bar.max_value = float(stats["max_magicka"])
	_mp_bar.value = float(stats["magicka"])
	_sp_bar.max_value = float(stats["max_stamina"])
	_sp_bar.value = float(stats["stamina"])

	var blk := " [BLOCKING]" if bool(stats.get("is_blocking", false)) else ""
	var draw_r := float(stats.get("bow_draw_ratio", 0.0))
	if _crosshair != null:
		_crosshair.text = "(+)" if draw_r > 0.2 else "+"
	_hands_label.text = "L: %s%s   |   R: %s   |   Gold: %d   |   Armor: %.0f" % [
		str(stats.get("left_hand_name", "Empty")),
		blk,
		str(stats.get("right_hand_name", "Empty")),
		int(stats.get("gold", 0)),
		float(stats.get("armor", 0.0)),
	]


func _on_prompt_changed(prompt_text: String) -> void:
	if _prompt_label != null:
		_prompt_label.text = prompt_text
		_prompt_label.visible = not prompt_text.is_empty()


func _on_ai_announcement(title: String, body: String, severity: String) -> void:
	if _ai_banner == null:
		return
	_ai_title.text = "⚡ DUNGEON AI: %s" % title
	_ai_body.text = body
	_ai_title.modulate = Color(1.0, 0.35, 0.25) if severity == "danger" else (Color(1.0, 0.78, 0.22) if severity == "warning" else Color(0.55, 0.92, 1.0))
	_ai_banner.visible = true
	_ai_banner_timer = 6.5


func _set_zone_text(txt: String, col: Color) -> void:
	if _zone_label != null:
		_zone_label.text = txt
		_zone_label.modulate = col
		_zone_label.visible = not txt.is_empty()


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Top Compass Bar (Skyrim style)
	_compass_panel = Panel.new()
	_compass_panel.custom_minimum_size = Vector2(440, 32)
	_compass_panel.anchor_left = 0.5
	_compass_panel.anchor_right = 0.5
	_compass_panel.offset_left = -220
	_compass_panel.offset_right = 220
	_compass_panel.offset_top = 12
	_compass_panel.offset_bottom = 44
	_compass_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_compass_panel)

	_compass_markers_root = Control.new()
	_compass_markers_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_compass_markers_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_compass_panel.add_child(_compass_markers_root)

	# 5-Day Clock Label
	_clock_label = Label.new()
	_clock_label.anchor_left = 0.5
	_clock_label.anchor_right = 0.5
	_clock_label.offset_left = -320
	_clock_label.offset_right = 320
	_clock_label.offset_top = 48
	_clock_label.offset_bottom = 72
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock_label.modulate = Color(0.92, 0.88, 0.78)
	root.add_child(_clock_label)

	# Zone Indicator (Safe Room / Boss Lockdown)
	_zone_label = Label.new()
	_zone_label.anchor_left = 0.5
	_zone_label.anchor_right = 0.5
	_zone_label.offset_left = -280
	_zone_label.offset_right = 280
	_zone_label.offset_top = 74
	_zone_label.offset_bottom = 98
	_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zone_label.visible = false
	root.add_child(_zone_label)

	# Snarky Dungeon AI Banner
	_ai_banner = PanelContainer.new()
	_ai_banner.anchor_left = 0.5
	_ai_banner.anchor_right = 0.5
	_ai_banner.offset_left = -330
	_ai_banner.offset_right = 330
	_ai_banner.offset_top = 104
	_ai_banner.offset_bottom = 178
	_ai_banner.visible = false
	_ai_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ai_box := VBoxContainer.new()
	_ai_title = Label.new()
	_ai_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ai_body = Label.new()
	_ai_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ai_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ai_box.add_child(_ai_title)
	ai_box.add_child(_ai_body)
	_ai_banner.add_child(ai_box)
	root.add_child(_ai_banner)

	# Center Crosshair & Interact Prompt
	_crosshair = Label.new()
	_crosshair.text = "+"
	_crosshair.anchor_left = 0.5
	_crosshair.anchor_top = 0.5
	_crosshair.anchor_right = 0.5
	_crosshair.anchor_bottom = 0.5
	_crosshair.offset_left = -16
	_crosshair.offset_right = 16
	_crosshair.offset_top = -14
	_crosshair.offset_bottom = 14
	_crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_crosshair)

	_prompt_label = Label.new()
	_prompt_label.anchor_left = 0.5
	_prompt_label.anchor_top = 0.5
	_prompt_label.anchor_right = 0.5
	_prompt_label.anchor_bottom = 0.5
	_prompt_label.offset_left = -200
	_prompt_label.offset_right = 200
	_prompt_label.offset_top = 26
	_prompt_label.offset_bottom = 54
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.modulate = Color(1.0, 0.92, 0.65)
	_prompt_label.visible = false
	root.add_child(_prompt_label)

	# Bottom Skyrim Resource Bars (Magicka | Health | Stamina)
	var bars_row := HBoxContainer.new()
	bars_row.anchor_left = 0.5
	bars_row.anchor_right = 0.5
	bars_row.anchor_top = 1.0
	bars_row.anchor_bottom = 1.0
	bars_row.offset_left = -360
	bars_row.offset_right = 360
	bars_row.offset_top = -62
	bars_row.offset_bottom = -38
	bars_row.add_theme_constant_override("separation", 18)
	root.add_child(bars_row)

	_mp_bar = _make_bar(Color(0.2, 0.52, 0.95))
	_hp_bar = _make_bar(Color(0.82, 0.16, 0.18))
	_sp_bar = _make_bar(Color(0.22, 0.78, 0.36))
	bars_row.add_child(_mp_bar)
	bars_row.add_child(_hp_bar)
	bars_row.add_child(_sp_bar)

	_hands_label = Label.new()
	_hands_label.anchor_left = 0.5
	_hands_label.anchor_right = 0.5
	_hands_label.anchor_top = 1.0
	_hands_label.anchor_bottom = 1.0
	_hands_label.offset_left = -460
	_hands_label.offset_right = 460
	_hands_label.offset_top = -32
	_hands_label.offset_bottom = -8
	_hands_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hands_label.modulate = Color(0.86, 0.88, 0.92)
	root.add_child(_hands_label)

	_controls_hint = Label.new()
	_controls_hint.text = "[WASD] Move  [LMB/RMB] Hands  [E] Interact  [V] 1st/3rd Cam  [1-4] Loadouts  [Q] Potion  [Tab] Inventory  [`] Audit Console  [Esc] Menu"
	_controls_hint.anchor_top = 1.0
	_controls_hint.anchor_bottom = 1.0
	_controls_hint.offset_left = 12
	_controls_hint.offset_top = -90
	_controls_hint.offset_bottom = -68
	_controls_hint.modulate = Color(0.62, 0.66, 0.74, 0.85)
	root.add_child(_controls_hint)


static func _make_bar(fill_col: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.show_percentage = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill_col
	bar.add_theme_stylebox_override("fill", sb)
	return bar
