class_name DebugOverlay
extends CanvasLayer
## Styled Built-in Playtest & Audit Console Overlay (toggled with ` / ~).

var _output: RichTextLabel = null
var _input: LineEdit = null
var _exec_cb: Callable = Callable()


var _close_cb: Callable = Callable()


func _ready() -> void:
	layer = 30
	visible = false
	_build_ui()


func setup(exec_cb: Callable, close_cb: Callable = Callable()) -> void:
	_exec_cb = exec_cb
	_close_cb = close_cb


func open_console() -> void:
	visible = true
	if _input != null:
		_input.grab_focus()


func close_console() -> void:
	visible = false


func toggle_console() -> bool:
	visible = not visible
	if visible and _input != null:
		_input.grab_focus()
	return visible


func append_line(text: String) -> void:
	if _output != null:
		_output.append_text(text + "\n")


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 18
	panel.offset_right = -18
	panel.offset_top = -255
	panel.offset_bottom = -16
	panel.add_theme_stylebox_override("panel", UiTheme.make_panel_style(Color(0.04, 0.048, 0.068, 0.94), UiTheme.COL_CYAN, 2, 6, 14, 12))
	add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)

	var hdr := Label.new()
	hdr.text = "PLAYTEST AUDIT CONSOLE  •  TYPE 'help' FOR SHORTCUTS  (PRESS ` TO CLOSE)"
	hdr.add_theme_font_size_override("font_size", 12)
	hdr.add_theme_color_override("font_color", UiTheme.COL_CYAN)
	v.add_child(hdr)

	_output = RichTextLabel.new()
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.scroll_following = true
	_output.add_theme_color_override("default_color", UiTheme.COL_TEXT)
	_output.append_text("Ready. Try: teleport safe | teleport boss | kill_boss | advance_days 5.1 | spawn_loot legendary\n")
	v.add_child(_output)

	_input = LineEdit.new()
	_input.placeholder_text = "Enter command (e.g. teleport boss, spawn_loot legendary, advance_days 4.9)..."
	_input.text_submitted.connect(func(cmd: String) -> void:
		if cmd.strip_edges().is_empty():
			return
		append_line("> " + cmd)
		if _exec_cb.is_valid():
			append_line(str(_exec_cb.call(cmd)))
		_input.text = ""
	)
	v.add_child(_input)
