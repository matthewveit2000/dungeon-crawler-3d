class_name PauseMenu
extends CanvasLayer
## Styled Skyrim-Inspired Pause Menu with Save & Quit (D-017), Camera Toggle (D-012),
## Floor-Entry Snapshot Reset (D-014), and Tutorial Mode ON/OFF Toggle (D-030).

var _status_lbl: Label = null
var _tut_toggle_btn: Button = null
var _callbacks: Dictionary = {}


func _ready() -> void:
	layer = 25
	visible = false
	_build_ui()


func setup(callbacks: Dictionary) -> void:
	_callbacks = callbacks


func open_menu(status_text: String = "", tutorial_enabled: bool = true) -> void:
	_status_lbl.text = status_text if not status_text.is_empty() else "Expedition paused — 5-day floor timer frozen."
	_update_tutorial_button(tutorial_enabled)
	visible = true


func close_menu() -> void:
	visible = false


func _update_tutorial_button(enabled: bool) -> void:
	if _tut_toggle_btn != null:
		_tut_toggle_btn.text = "Tutorial Mode: %s  (Walks through new mechanics)" % ("ON" if enabled else "OFF")
		UiTheme.style_button(_tut_toggle_btn, UiTheme.COL_EMERALD if enabled else UiTheme.COL_MUTED, 14)


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.015, 0.02, 0.035, 0.72)
	root.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -245
	panel.offset_right = 245
	panel.offset_top = -230
	panel.offset_bottom = 230
	panel.add_theme_stylebox_override("panel", UiTheme.make_panel_style(UiTheme.COL_BG_DEEP, UiTheme.COL_GOLD, 2, 8, 28, 24))
	root.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var title := Label.new()
	title.text = "DUNGEON CRAWLER 3D"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", UiTheme.COL_GOLD_BRIGHT)
	v.add_child(title)

	var sub := Label.new()
	sub.text = "EXPEDITION PAUSED  •  TIMER FROZEN"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", Color(0.45, 0.94, 0.74))
	v.add_child(sub)

	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(0, 1)
	div.color = UiTheme.COL_GOLD_DIM
	v.add_child(div)

	_status_lbl = Label.new()
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_lbl.add_theme_font_size_override("font_size", 12)
	_status_lbl.add_theme_color_override("font_color", UiTheme.COL_MUTED)
	v.add_child(_status_lbl)

	_add_btn(v, "Resume Expedition  [Esc]", "resume", UiTheme.COL_GOLD_BRIGHT)
	_add_btn(v, "Toggle Camera  (1st / 3rd Person)  [V]", "toggle_camera", UiTheme.COL_GOLD)

	_tut_toggle_btn = Button.new()
	_tut_toggle_btn.custom_minimum_size = Vector2(0, 38)
	_tut_toggle_btn.pressed.connect(func() -> void:
		var cb: Callable = _callbacks.get("toggle_tutorial", Callable())
		if cb.is_valid():
			var now_on := bool(cb.call())
			_update_tutorial_button(now_on)
	)
	v.add_child(_tut_toggle_btn)

	_add_btn(v, "Reset Tutorial Hints", "reset_tutorials", UiTheme.COL_CYAN)
	_add_btn(v, "Save & Quit  (Resumes Exact Position & Clock)", "save_quit", UiTheme.COL_EMERALD)
	_add_btn(v, "Reset Floor to Floor-Entry Snapshot", "reset_floor", UiTheme.COL_CRIMSON)


func _add_btn(parent: Control, label: String, key: String, accent: Color) -> void:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(0, 38)
	UiTheme.style_button(btn, accent, 14)
	btn.pressed.connect(func() -> void:
		var cb: Callable = _callbacks.get(key, Callable())
		if cb.is_valid():
			cb.call()
	)
	parent.add_child(btn)
