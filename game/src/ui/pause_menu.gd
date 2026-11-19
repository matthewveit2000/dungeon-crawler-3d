class_name PauseMenu
extends MenuScreen
## Pause menu over a blurred game view: left column of actions, right column with run status,
## controls reference and the full settings editor. Destructive actions ask for confirmation.

var _callbacks: Dictionary = {}
var _status_lbl: Label = null
var _sub_lbl: Label = null
var _tut_btn: Button = null
var _content: Control = null
var _settings: SettingsPanel = null
var _controls_box: VBoxContainer = null
var _info_box: VBoxContainer = null
var _saved_lbl: Label = null
var _first_btn: Button = null


func _ready() -> void:
	build_base(20, true)
	_build_ui()


func setup(callbacks: Dictionary) -> void:
	_callbacks = callbacks


func open_menu(status_text: String = "", tutorial_enabled: bool = true) -> void:
	_status_lbl.text = status_text
	_update_tutorial_button(tutorial_enabled)
	_saved_lbl.text = ""
	_show_section("info")
	show_animated()
	if _first_btn != null:
		_first_btn.call_deferred("grab_focus")


func close_menu() -> void:
	hide_now()


func is_settings_open() -> bool:
	return _settings != null and _settings.visible


func back() -> bool:
	## Returns true if the press was consumed (closing a sub-panel instead of the menu).
	if _settings.visible or _controls_box.visible:
		_show_section("info")
		return true
	return false


func _update_tutorial_button(enabled: bool) -> void:
	if _tut_btn != null:
		_tut_btn.text = "Tutorial Hints: %s" % ("On" if enabled else "Off")


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 70)
	margin.add_theme_constant_override("margin_right", 70)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 60)
	root.add_child(margin)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 46)
	margin.add_child(h)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 330
	left.add_theme_constant_override("separation", 8)
	h.add_child(left)
	var crest := UiTheme.icon_rect(UiTheme.tex("crest"), 120)
	crest.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	left.add_child(crest)
	left.add_child(UiTheme.label("PAUSED", 40, UiTheme.COL_GOLD_BRIGHT, UiTheme.font_title(), HORIZONTAL_ALIGNMENT_CENTER))
	_sub_lbl = UiTheme.label("The floor clock is frozen", 17, UiTheme.COL_MUTED, UiTheme.font_italic(), HORIZONTAL_ALIGNMENT_CENTER)
	left.add_child(_sub_lbl)
	left.add_child(UiTheme.divider())
	_first_btn = _btn(left, "Resume", func() -> void: _cb("resume"))
	_btn(left, "Settings", func() -> void: _show_section("settings"))
	_btn(left, "Controls", func() -> void: _show_section("controls"))
	_btn(left, "Toggle 1st / 3rd Person", func() -> void: _cb("toggle_camera"))
	_tut_btn = _btn(left, "Tutorial Hints: On", func() -> void:
		var cb: Callable = _callbacks.get("toggle_tutorial", Callable())
		if cb.is_valid():
			_update_tutorial_button(bool(cb.call()))
	)
	_btn(left, "Replay Tutorial Hints", func() -> void: _cb("reset_tutorials"))
	_btn(left, "Save Game", func() -> void:
		var cb: Callable = _callbacks.get("save", Callable())
		var ok := bool(cb.call()) if cb.is_valid() else false
		_saved_lbl.text = "Progress saved." if ok else "Could not save."
	)
	_btn(left, "Reset Floor", func() -> void:
		_confirm_then("Reset this floor?", "You return to the floor entrance with the gear and level you entered with. Anything found since will be lost.", "Reset Floor", "reset_floor")
	)
	_btn(left, "Save & Quit to Title", func() -> void: _cb("quit_to_title"))
	_btn(left, "Save & Quit to Desktop", func() -> void: _cb("save_and_quit"))
	_saved_lbl = UiTheme.label("", 16, UiTheme.COL_GOOD, UiTheme.font_ui(), HORIZONTAL_ALIGNMENT_CENTER)
	left.add_child(_saved_lbl)

	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_stylebox_override("panel", UiTheme.panel_style("frame"))
	h.add_child(right)
	_content = VBoxContainer.new()
	right.add_child(_content)

	_info_box = VBoxContainer.new()
	_info_box.add_theme_constant_override("separation", 12)
	_content.add_child(_info_box)
	_info_box.add_child(UiTheme.heading("Expedition Status", 26))
	_info_box.add_child(UiTheme.divider())
	_status_lbl = UiTheme.label("", 22, UiTheme.COL_TEXT, UiTheme.font_ui_semibold())
	_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_box.add_child(_status_lbl)
	_info_box.add_child(UiTheme.body("The Syndicate's broadcast is on hold. While paused, the five-day collapse timer, enemies and traps are frozen. Your game saves your exact position and remaining time whenever you save or quit.", 19, UiTheme.COL_MUTED, true))
	_info_box.add_child(UiTheme.heading("Crawler's Field Notes", 20, UiTheme.COL_GOLD))
	for tip in [
		"Hold Attack to wind up a power attack — it staggers and deals heavy damage.",
		"Blocking with a shield costs stamina but negates most of a blow.",
		"Safe Rooms are true sanctuaries: monsters will not follow you inside.",
		"Sealed Boss Arenas guard the Treasure Vault — weigh the risk against the clock.",
		"Floor collapse or death returns you to your floor-entry snapshot, not the very start.",
	]:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 10)
		r.add_child(UiTheme.icon_rect(UiTheme.tex("icon_diamond"), 14, UiTheme.COL_GOLD))
		var l := UiTheme.body(tip, 18, UiTheme.COL_TEXT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(l)
		_info_box.add_child(r)

	_settings = SettingsPanel.new()
	_settings.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_settings.closed.connect(func() -> void: _show_section("info"))
	_content.add_child(_settings)

	_controls_box = VBoxContainer.new()
	_controls_box.add_theme_constant_override("separation", 6)
	_content.add_child(_controls_box)


func _show_section(which: String) -> void:
	_info_box.visible = which == "info"
	_settings.visible = which == "settings"
	_controls_box.visible = which == "controls"
	if which == "controls":
		_build_controls()


func _build_controls() -> void:
	for c in _controls_box.get_children():
		c.queue_free()
	_controls_box.add_child(UiTheme.heading("Controls", 26))
	_controls_box.add_child(UiTheme.divider())
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 6)
	_controls_box.add_child(grid)
	var mv := [GameSettings.action_label("move_forward"), GameSettings.action_label("move_left"), GameSettings.action_label("move_backward"), GameSettings.action_label("move_right")]
	var rows := [
		["%s %s %s %s" % mv, "Move"], ["Mouse", "Look around"], [GameSettings.action_label("sprint"), "Sprint"],
		[GameSettings.action_label("jump"), "Jump"], [GameSettings.action_label("right_hand_action"), "Attack — hold for a power attack / draw the bow"],
		[GameSettings.action_label("left_hand_action"), "Block with shield / cast off-hand spell"], [GameSettings.action_label("interact"), "Open, loot, talk, pull levers"],
		["1  2  3  4", "Quick loadouts"], [GameSettings.action_label("quick_potion"), "Drink a health draught"],
		[GameSettings.action_label("toggle_inventory"), "Inventory, character & perks"], [GameSettings.action_label("toggle_map"), "Dungeon map"],
		[GameSettings.action_label("toggle_camera"), "Switch 1st / 3rd person"], [GameSettings.action_label("dismiss_hint"), "Hide tutorial hint"],
		["Esc", "Pause / back"],
	]
	for r in rows:
		var kc := HBoxContainer.new()
		kc.custom_minimum_size.x = 220
		for k in str(r[0]).split("  "):
			kc.add_child(UiTheme.keycap(k.strip_edges(), 16))
		grid.add_child(kc)
		grid.add_child(UiTheme.label(str(r[1]), 19, UiTheme.COL_TEXT, UiTheme.font_ui()))
	var tip := UiTheme.label("Every binding can be changed under Settings → Controls.", 16, UiTheme.COL_MUTED, UiTheme.font_italic())
	_controls_box.add_child(tip)
	var back_b := UiTheme.button("Back", 160)
	back_b.pressed.connect(func() -> void: _show_section("info"))
	_controls_box.add_child(back_b)


func _btn(parent: Control, text: String, cb: Callable) -> Button:
	var b := UiTheme.button(text, 0, 20)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _cb(key: String) -> void:
	var cb: Callable = _callbacks.get(key, Callable())
	if key == "save_quit" and not cb.is_valid():
		cb = _callbacks.get("save_and_quit", Callable())
	if cb.is_valid():
		cb.call()


func _confirm_then(title: String, body_text: String, yes: String, key: String) -> void:
	if GameSettings != null and not bool(GameSettings.get_value("gameplay", "confirm_destructive")):
		_cb(key)
		return
	MenuScreen.confirm(self, title, body_text, yes, func() -> void: _cb(key))
