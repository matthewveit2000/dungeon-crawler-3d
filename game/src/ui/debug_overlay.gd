class_name DebugOverlay
extends CanvasLayer
## In-Game Playtest & Audit Console Overlay (Backtick `).
## Executes DebugConsole commands so User milestone verification takes seconds.

var _executor: Callable = Callable()
var _on_close_cb: Callable = Callable()
var _log_box: TextEdit = null
var _input_line: LineEdit = null


func setup(executor: Callable, on_close: Callable) -> void:
	_executor = executor
	_on_close_cb = on_close
	layer = 20
	visible = false
	_build_ui()


func open_console() -> void:
	visible = true
	if _input_line != null:
		_input_line.grab_focus()


func close_console() -> void:
	visible = false
	if _on_close_cb.is_valid():
		_on_close_cb.call()


func _submit(text: String) -> void:
	var cmd := text.strip_edges()
	if cmd.is_empty():
		return
	_input_line.clear()
	_append_log("> " + cmd)
	if _executor.is_valid():
		var out := str(_executor.call(cmd))
		if not out.is_empty():
			_append_log(out)


func _append_log(line: String) -> void:
	if _log_box != null:
		_log_box.text += line + "\n"
		_log_box.scroll_vertical = _log_box.get_line_count()


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.05
	panel.anchor_right = 0.95
	panel.anchor_top = 0.04
	panel.anchor_bottom = 0.46
	add_child(panel)

	var box := VBoxContainer.new()
	panel.add_child(box)

	var top := HBoxContainer.new()
	var title := Label.new()
	title.text = "PLAYTEST / AUDIT CONSOLE (Type 'help' for shortcuts)"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close_btn := Button.new()
	close_btn.text = "Close [` / Esc]"
	close_btn.pressed.connect(close_console)
	top.add_child(title)
	top.add_child(close_btn)
	box.add_child(top)

	_log_box = TextEdit.new()
	_log_box.editable = false
	_log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_box.text = "Audit Console Ready. Type 'help' to see teleport, timer, loot & seed shortcuts.\n"
	box.add_child(_log_box)

	_input_line = LineEdit.new()
	_input_line.placeholder_text = "Enter command (e.g. teleport boss, advance_days 4.9, spawn_loot sponsored)..."
	_input_line.text_submitted.connect(_submit)
	box.add_child(_input_line)
