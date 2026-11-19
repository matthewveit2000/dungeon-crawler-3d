class_name SettingsPanel
extends VBoxContainer
## Tabbed settings editor (Graphics / Audio / Controls / Gameplay / Accessibility) bound live to
## GameSettings. Includes key rebinding with conflict swap, per-tab reset and contextual help text.

signal closed

var _tabs: TabBar = null
var _pages: Array[Control] = []
var _help: Label = null
var _rebind_action: String = ""
var _rebind_btn: Button = null
var _bind_buttons: Dictionary = {}

const TAB_KEYS := ["graphics", "audio", "controls", "gameplay", "accessibility"]
const TAB_TITLES := ["Graphics", "Audio", "Controls", "Gameplay", "Accessibility"]


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_tabs = TabBar.new()
	for t in TAB_TITLES:
		_tabs.add_tab(t)
	_tabs.tab_changed.connect(_show_tab)
	add_child(_tabs)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	add_child(body)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(stack)
	for i in range(TAB_KEYS.size()):
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", 6)
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stack.add_child(page)
		_pages.append(page)
	var side := PanelContainer.new()
	side.custom_minimum_size = Vector2(250, 0)
	side.add_theme_stylebox_override("panel", UiTheme.panel_style("card"))
	body.add_child(side)
	var sv := VBoxContainer.new()
	side.add_child(sv)
	sv.add_child(UiTheme.label("ABOUT THIS SETTING", 14, UiTheme.COL_GOLD, UiTheme.font_ui_bold()))
	_help = UiTheme.body("Hover over any option to learn what it does.", 17, UiTheme.COL_MUTED, true)
	sv.add_child(_help)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	add_child(foot)
	var reset := UiTheme.button("Reset Tab to Defaults", 240)
	reset.pressed.connect(func() -> void:
		var key: String = TAB_KEYS[_tabs.current_tab]
		GameSettings.reset_section(key)
		_rebuild()
	)
	foot.add_child(reset)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(spacer)
	var done := UiTheme.button("Done", 160)
	done.pressed.connect(func() -> void: closed.emit())
	foot.add_child(done)
	_rebuild()
	_show_tab(0)


func _show_tab(i: int) -> void:
	for k in range(_pages.size()):
		_pages[k].visible = k == i


func _rebuild() -> void:
	for p in _pages:
		for c in p.get_children():
			c.queue_free()
	_bind_buttons.clear()
	var g := _pages[0]
	_option(g, "graphics", "quality", "Graphics Quality", ["Low", "Medium", "High", "Ultra"], [0, 1, 2, 3],
		"Low: fastest, no fog or ambient occlusion. Medium: volumetric fog + SSAO. High: + indirect light & more shadowed torches. Ultra: + real-time global illumination (SDFGI).")
	_option(g, "graphics", "window_mode", "Display Mode", ["Windowed", "Borderless Fullscreen", "Exclusive Fullscreen"], ["windowed", "borderless", "fullscreen"],
		"Exclusive fullscreen usually gives the best performance; borderless makes alt-tab instant.")
	_toggle(g, "graphics", "vsync", "Vertical Sync", "Prevents screen tearing. Turn off for the lowest input latency.")
	_option(g, "graphics", "max_fps", "Frame Rate Limit", ["Unlimited", "30", "60", "120", "144"], [0, 30, 60, 120, 144], "Caps frame rate to reduce heat, noise and power use.")
	_slider(g, "graphics", "fov", "Field of View", 60.0, 110.0, 1.0, "%.0f°", "Wider view shows more of the dungeon; narrower feels more intimate. Default 78°.")
	_slider(g, "graphics", "render_scale", "Render Scale", 0.5, 1.0, 0.05, "%.0f%%", "Renders the 3D world at a lower resolution for speed; the HUD stays sharp.", 100.0)
	_toggle(g, "graphics", "fsr", "AMD FSR 2 Upscaling", "High-quality upscaling when Render Scale is below 100%.")
	_slider(g, "graphics", "brightness", "Brightness", 0.6, 1.6, 0.05, "%.2f", "Adjust if the darkest corridors are too hard (or too easy) to read.")
	_toggle(g, "graphics", "show_fps", "Show FPS Counter", "Displays frames per second in the top-left corner.")

	var a := _pages[1]
	for spec in [["master", "Master Volume"], ["music", "Music"], ["sfx", "Combat & Effects"], ["ambience", "Dungeon Ambience"], ["ui", "Interface"]]:
		_slider(a, "audio", spec[0], spec[1], 0.0, 1.0, 0.05, "%.0f%%", "Volume for %s." % str(spec[1]).to_lower(), 100.0)

	var c := _pages[2]
	_slider(c, "controls", "mouse_sensitivity", "Mouse Sensitivity", 0.2, 3.0, 0.05, "%.2fx", "How fast the camera turns with the mouse.")
	_toggle(c, "controls", "invert_y", "Invert Vertical Look", "Moving the mouse up looks down.")
	c.add_child(UiTheme.heading("Key Bindings", 18, UiTheme.COL_GOLD))
	c.add_child(UiTheme.label("Click a binding, then press the new key or mouse button. Esc cancels. Conflicting bindings swap automatically.", 15, UiTheme.COL_MUTED, UiTheme.font_ui()))
	for pair in GameSettings.REBINDABLE_ACTIONS:
		_binding_row(c, pair[0], pair[1])
	var rb := UiTheme.button("Restore Default Bindings", 280)
	rb.pressed.connect(func() -> void:
		GameSettings.reset_bindings()
		_refresh_bindings()
	)
	c.add_child(rb)

	var gp := _pages[3]
	_slider(gp, "gameplay", "head_bob", "Head Bob", 0.0, 1.0, 0.05, "%.0f%%", "Camera sway while walking. Lower it if you are prone to motion sickness.", 100.0)
	_slider(gp, "gameplay", "camera_shake", "Camera Shake", 0.0, 1.0, 0.05, "%.0f%%", "Impact shake on hits, blocks and heavy blows.", 100.0)
	_toggle(gp, "gameplay", "show_damage_numbers", "Floating Damage Numbers", "Shows the damage of each hit above enemies (critical hits in gold).")
	_option(gp, "gameplay", "enemy_health_bars", "Enemy Health Bars", ["When Damaged", "Always", "Never"], ["damaged", "always", "never"], "Bosses always use the large top-of-screen bar.")
	_option(gp, "gameplay", "crosshair", "Crosshair", ["Dot", "Cross", "Hidden"], ["dot", "cross", "none"], "The bow draw ring and hit markers always appear when relevant.")
	_toggle(gp, "gameplay", "compass", "Compass Bar", "The Skyrim-style compass with landmark icons.")
	_slider(gp, "gameplay", "hud_opacity", "HUD Opacity", 0.3, 1.0, 0.05, "%.0f%%", "Fade the whole HUD for a more immersive view.", 100.0)
	_toggle(gp, "gameplay", "confirm_destructive", "Confirm Destructive Actions", "Asks before resetting the floor or quitting without saving.")

	var ac := _pages[4]
	_slider(ac, "accessibility", "ui_scale", "Interface Scale", 0.8, 1.5, 0.05, "%.0f%%", "Makes every menu and HUD element larger or smaller.", 100.0)
	_option(ac, "accessibility", "colorblind", "Colour-Blind Filter", ["Off", "Protanopia", "Deuteranopia", "Tritanopia"], ["off", "protanopia", "deuteranopia", "tritanopia"],
		"Re-maps colours so rarity, health and magic hues stay distinguishable.")
	_toggle(ac, "accessibility", "subtitles", "Announcement Text", "Shows the full text of Dungeon AI broadcasts.")
	_toggle(ac, "accessibility", "reduce_flashing", "Reduce Flashing", "Softens damage flashes and the low-health pulse.")


func _row(parent: Control, label_text: String, help: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size.y = 46
	var l := UiTheme.label(label_text, 20, UiTheme.COL_TEXT, UiTheme.font_ui_semibold())
	l.custom_minimum_size.x = 300
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	row.mouse_entered.connect(func() -> void: _help.text = help)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(row)
	return row


func _toggle(parent: Control, section: String, key: String, label_text: String, help: String) -> void:
	var row := _row(parent, label_text, help)
	var cb := CheckBox.new()
	cb.button_pressed = bool(GameSettings.get_value(section, key))
	cb.text = "On" if cb.button_pressed else "Off"
	cb.toggled.connect(func(on: bool) -> void:
		cb.text = "On" if on else "Off"
		GameSettings.set_value(section, key, on)
	)
	cb.mouse_entered.connect(func() -> void: _help.text = help)
	row.add_child(cb)


func _option(parent: Control, section: String, key: String, label_text: String, names: Array, values: Array, help: String) -> void:
	var row := _row(parent, label_text, help)
	var ob := OptionButton.new()
	ob.custom_minimum_size.x = 260
	for n in names:
		ob.add_item(str(n))
	var cur: Variant = GameSettings.get_value(section, key)
	var idx := values.find(cur)
	if idx < 0 and cur is float:
		idx = values.find(int(cur))
	ob.selected = maxi(0, idx)
	ob.item_selected.connect(func(i: int) -> void: GameSettings.set_value(section, key, values[i]))
	ob.mouse_entered.connect(func() -> void: _help.text = help)
	row.add_child(ob)


func _slider(parent: Control, section: String, key: String, label_text: String, lo: float, hi: float, step: float, fmt: String, help: String, display_mult: float = 1.0) -> void:
	var row := _row(parent, label_text, help)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(GameSettings.get_value(section, key))
	s.custom_minimum_size = Vector2(240, 28)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var vl := UiTheme.label(fmt % (s.value * display_mult), 18, UiTheme.COL_GOLD_BRIGHT, UiTheme.font_ui_semibold())
	vl.custom_minimum_size.x = 64
	s.value_changed.connect(func(v: float) -> void:
		vl.text = fmt % (v * display_mult)
		GameSettings.set_value(section, key, v)
	)
	s.mouse_entered.connect(func() -> void: _help.text = help)
	row.add_child(s)
	row.add_child(vl)


func _binding_row(parent: Control, action: String, label_text: String) -> void:
	var row := _row(parent, label_text, "Click to rebind %s." % label_text)
	var b := UiTheme.button(GameSettings.action_label(action), 180, 18)
	b.pressed.connect(func() -> void:
		if _rebind_btn != null:
			_rebind_btn.text = GameSettings.action_label(_rebind_action)
		_rebind_action = action
		_rebind_btn = b
		b.text = "Press a key…"
	)
	_bind_buttons[action] = b
	row.add_child(b)


func _refresh_bindings() -> void:
	for a in _bind_buttons.keys():
		(_bind_buttons[a] as Button).text = GameSettings.action_label(a)


func _input(event: InputEvent) -> void:
	if _rebind_btn == null or not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			_rebind_btn.text = GameSettings.action_label(_rebind_action)
		else:
			var conflict := GameSettings.rebind(_rebind_action, event)
			if not conflict.is_empty():
				_help.text = 'Swapped with "%s".' % conflict.replace("_", " ").capitalize()
			_refresh_bindings()
		_rebind_btn = null
		_rebind_action = ""
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			return
		if mb.button_index == MOUSE_BUTTON_LEFT and _rebind_btn.get_global_rect().has_point(mb.global_position):
			return
		get_viewport().set_input_as_handled()
		GameSettings.rebind(_rebind_action, event)
		_refresh_bindings()
		_rebind_btn = null
		_rebind_action = ""
