class_name PauseMenu
extends CanvasLayer
## Classic Skyrim Pause Menu with Resume, Save & Quit (D-017), Reset Floor, and Controls Reference.

var _callbacks: Dictionary = {}
var _status_lbl: Label = null


func setup(callbacks: Dictionary) -> void:
	_callbacks = callbacks
	layer = 15
	visible = false
	_build_ui()


func open_menu() -> void:
	visible = true
	if _status_lbl != null:
		_status_lbl.text = ""


func close_menu() -> void:
	visible = false
	var cb: Callable = _callbacks.get("resume", Callable())
	if cb.is_valid():
		cb.call()


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.30
	panel.anchor_right = 0.70
	panel.anchor_top = 0.18
	panel.anchor_bottom = 0.82
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = "DUNGEON CRAWLER 3D — PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var resume_btn := Button.new()
	resume_btn.text = "Resume Crawl [Esc]"
	resume_btn.pressed.connect(close_menu)
	box.add_child(resume_btn)

	var save_btn := Button.new()
	save_btn.text = "Save Session Now"
	save_btn.pressed.connect(func() -> void:
		var cb: Callable = _callbacks.get("save", Callable())
		if cb.is_valid() and bool(cb.call()):
			_status_lbl.text = "Session auto-saved! Exact position, timer & snapshot preserved."
	)
	box.add_child(save_btn)

	var save_quit_btn := Button.new()
	save_quit_btn.text = "Save & Quit"
	save_quit_btn.pressed.connect(func() -> void:
		var cb: Callable = _callbacks.get("save_and_quit", Callable())
		if cb.is_valid():
			cb.call()
	)
	box.add_child(save_quit_btn)

	var reset_btn := Button.new()
	reset_btn.text = "Reset to Floor-Entry Snapshot"
	reset_btn.pressed.connect(func() -> void:
		var cb: Callable = _callbacks.get("reset_floor", Callable())
		if cb.is_valid():
			cb.call()
		close_menu()
	)
	box.add_child(reset_btn)

	_status_lbl = Label.new()
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.modulate = Color(0.55, 0.95, 0.65)
	box.add_child(_status_lbl)

	var help := Label.new()
	help.text = "Controls:\nWASD + Mouse: Move & Look | Shift: Sprint | Space: Jump\nLMB: Right Hand (Hold for Power Attack / Draw Bow)\nRMB: Left Hand (Hold Shield to Block / Cast Spell)\n1-4: Quick Loadouts | Q: Health Potion | V: 1st/3rd Person\nE: Interact / Loot / Descend | Tab / I: Inventory & Skills\n` (Backtick): Built-In Playtest Audit Console"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(help)
