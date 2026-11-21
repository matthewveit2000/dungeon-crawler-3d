class_name DeathScreen
extends CanvasLayer
## Dramatic overlay after combat death or floor collapse (D-014 / D-018): title card, Dungeon AI
## snark and a reminder of what the floor-entry snapshot restored. Fades away on its own or on any key.

var _root: Control = null
var _title: Label = null
var _sub: Label = null
var _body: Label = null
var _t: float = 0.0


func _ready() -> void:
	layer = 40
	visible = false
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.get_theme()
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.0, 0.0, 0.9)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)
	var vig := TextureRect.new()
	vig.texture = UiTheme.tex("vignette")
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.modulate = Color(0, 0, 0, 1)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(vig)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(c)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	c.add_child(v)
	_title = UiTheme.label("", 64, Color(0.86, 0.2, 0.14), UiTheme.font_title(), HORIZONTAL_ALIGNMENT_CENTER)
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	_title.add_theme_constant_override("shadow_offset_y", 4)
	v.add_child(_title)
	var d := UiTheme.divider(560)
	d.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(d)
	_sub = UiTheme.label("", 22, UiTheme.COL_GOLD_BRIGHT, UiTheme.font_heading(), HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_sub)
	_body = UiTheme.label("", 20, UiTheme.COL_TEXT, UiTheme.font_italic(), HORIZONTAL_ALIGNMENT_CENTER)
	_body.custom_minimum_size.x = 760
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_body)
	var hint := UiTheme.label("Press any key to continue", 16, UiTheme.COL_MUTED, UiTheme.font_ui(), HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(hint)


func show_reset(reason: String, floor_num: int) -> void:
	match reason:
		"death":
			_title.text = "YOU HAVE FALLEN"
			_sub.text = "The dark spits you back out at the start of the floor"
		"collapse":
			_title.text = "THE FLOOR COLLAPSED"
			_sub.text = "Five days have passed on Floor %d" % floor_num
		_:
			_title.text = "FLOOR RESET"
			_sub.text = "Back to the entrance of Floor %d" % floor_num
	_body.text = "Your floor-entry snapshot has been restored: the level, gear and gold you entered Floor %d with. The labyrinth has rebuilt itself and a fresh five-day clock begins now." % floor_num
	_t = 6.0
	visible = true
	_root.modulate.a = 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_t -= delta
	_root.modulate.a = clampf(minf((6.0 - _t) / 0.5, _t / 1.0), 0.0, 1.0)
	if _t <= 0.0:
		visible = false


func _input(event: InputEvent) -> void:
	if visible and _t < 5.2 and (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		_t = minf(_t, 0.6)
