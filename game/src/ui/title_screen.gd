class_name TitleScreen
extends Node3D
## Title screen: a live, torch-lit Nordic-ruin hall (built from the real dungeon kit) with a slow
## cinematic camera drift and a lurking draugr, under an ornate menu: Continue (with save summary),
## New Expedition (confirms before overwriting), Settings, Credits and Quit.

const GAME_SCENE := "res://scenes/main.tscn"
const TIPS := [
	"Hold attack to wind up a power attack that staggers foes.",
	"Safe Rooms are sanctuaries — nothing hostile may follow you inside.",
	"Your floor-entry snapshot means death costs the floor, never the run.",
	"The compass reveals landmarks as you draw near them.",
	"Legendary relics have opinions. Equip them anyway.",
	"Press M to open your hand-inked dungeon map.",
]

var builder: DungeonBuilder = null
var cam: Camera3D = null
var _t: float = 0.0
var _cam_base: Vector3 = Vector3.ZERO
var _cam_target: Vector3 = Vector3.ZERO
var _ui: CanvasLayer = null
var _menu_box: VBoxContainer = null
var _settings_wrap: Control = null
var _credits_wrap: Control = null
var _fade: ColorRect = null
var _continue_btn: Button = null


func _ready() -> void:
	DataLoader.ensure_loaded()
	_build_backdrop()
	_build_ui()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if AudioManager != null:
		AudioManager.start_ambience("dungeon_ambience")


func _build_backdrop() -> void:
	# The backdrop only needs a small corner of dungeon, not a vast floor (D-044)
	var world_pack: Dictionary = DataLoader.get_world().duplicate(true)
	world_pack["grid"]["width_tiles"] = 60
	world_pack["grid"]["height_tiles"] = 60
	world_pack["labyrinth"]["stairs_count"] = 1
	world_pack["labyrinth"]["safe_room_regions"] = 1
	var layout := DungeonGenerator.generate(world_pack, DataLoader.get_enemies_pack(), 1, 7331)
	builder = DungeonBuilder.new()
	add_child(builder)
	builder.build_floor(layout, DataLoader.get_floor_config(1), func(_i: InteractableObject, _a: Node3D) -> bool: return false, SeededRng.new(99))
	var room: Dictionary = layout.rooms[layout.entrance_room_id]
	var c := layout.tile_to_world(room["center"])
	cam = Camera3D.new()
	cam.fov = 62.0
	add_child(cam)
	_cam_base = c + Vector3(-3.2, 1.75, 4.6)
	_cam_target = c + Vector3(0.6, 1.4, -3.0)
	cam.position = _cam_base
	cam.look_at(_cam_target, Vector3.UP)
	cam.current = true
	builder.set_light_focus_target(cam)
	var d := CharacterVisual.create("draugr")
	d.position = c + Vector3(2.4, 0.0, -4.2)
	d.rotation.y = -0.4
	add_child(d)
	d.play_state("idle_combat", 0.0)
	var axe := ModelLoader.instantiate_model("res://assets/models/gear/battleaxe.glb")
	var grip := d.model.find_child("GripR*", true, false) as Node3D
	if grip != null:
		grip.add_child(axe)


func _process(delta: float) -> void:
	_t += delta
	if cam != null:
		var off := Vector3(sin(_t * 0.07) * 1.4, sin(_t * 0.11) * 0.18, cos(_t * 0.05) * 0.8)
		cam.position = _cam_base + off
		cam.look_at(_cam_target + Vector3(sin(_t * 0.09) * 0.6, 0.0, 0.0), Vector3.UP)


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.get_theme()
	_ui.add_child(root)
	# left-side darkening gradient for legibility
	var grad := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0.88), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.0)])
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	grad.texture = gt
	grad.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	grad.offset_right = 760
	grad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(grad)
	var vig := TextureRect.new()
	vig.texture = UiTheme.tex("vignette")
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.modulate = Color(0, 0, 0, 0.75)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vig)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	col.offset_left = 90
	col.offset_right = 600
	col.offset_top = 40
	col.offset_bottom = -26
	col.add_theme_constant_override("separation", 2)
	root.add_child(col)
	var crest := UiTheme.icon_rect(UiTheme.tex("crest"), 96)
	crest.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(crest)
	var t1 := UiTheme.label("DUNGEON", 60, UiTheme.COL_GOLD_BRIGHT, UiTheme.font_title())
	t1.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	t1.add_theme_constant_override("shadow_offset_y", 4)
	col.add_child(t1)
	var t2 := UiTheme.label("CRAWLER", 60, UiTheme.COL_GOLD, UiTheme.font_title())
	t2.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	t2.add_theme_constant_override("shadow_offset_y", 4)
	col.add_child(t2)
	col.add_child(UiTheme.label("THE NORDIC DESCENT", 20, UiTheme.COL_TEXT, UiTheme.font_heading()))
	var dv := UiTheme.divider(420)
	dv.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(dv)
	var sp := Control.new()
	sp.custom_minimum_size.y = 10
	col.add_child(sp)
	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", 8)
	_menu_box.custom_minimum_size.x = 380
	_menu_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(_menu_box)
	var has_save := FileAccess.file_exists(SnapshotManager.DEFAULT_SAVE_PATH)
	if has_save:
		_continue_btn = _menu_btn("Continue Expedition", _on_continue)
		var summary := _save_summary()
		if not summary.is_empty():
			_menu_box.add_child(UiTheme.label(summary, 16, UiTheme.COL_MUTED, UiTheme.font_ui()))
	_menu_btn("New Expedition", _on_new)
	# D-047: sandbox with every room type, spawners for anything and all test switches (F1 in game)
	_menu_btn("Test Mode", func() -> void:
		GameMain.launch_test_mode = true
		_start_game(false))
	_menu_btn("Settings", func() -> void: _show("settings"))
	_menu_btn("Credits", func() -> void: _show("credits"))
	_menu_btn("Quit", func() -> void: get_tree().quit())
	var spc := Control.new()
	spc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spc)
	var tip := UiTheme.label("Tip  ·  " + TIPS[int(Time.get_unix_time_from_system()) % TIPS.size()], 17, UiTheme.COL_MUTED, UiTheme.font_italic())
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(tip)
	col.add_child(UiTheme.label("v0.1 Vertical Slice  ·  Free & open source  ·  Made with Godot & Blender", 14, UiTheme.COL_FAINT, UiTheme.font_ui()))

	_settings_wrap = _overlay_panel(root, "Settings")
	var sp_panel := SettingsPanel.new()
	sp_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sp_panel.closed.connect(func() -> void: _show("menu"))
	(_settings_wrap.get_meta("body") as VBoxContainer).add_child(sp_panel)
	_credits_wrap = _overlay_panel(root, "Credits")
	var cb := _credits_wrap.get_meta("body") as VBoxContainer
	for line in [
		["Design & Direction", "The Dungeon Crawler 3D project owner"],
		["Engine", "Godot 4.7 (MIT License)"],
		["3D Art, Animation & VFX", "100% original — procedurally modelled, rigged and animated in Blender 4.5 LTS via the scripts in art/blender/"],
		["Textures & UI Art", "100% original — generated by art/pipeline/ (NumPy + Pillow)"],
		["Typography", "Cinzel, Cinzel Decorative, Alegreya & Barlow Condensed — SIL Open Font License 1.1"],
		["Audio", "Procedurally synthesised SFX & ambience (scripts/generate-sfx.py)"],
		["Inspiration", "Skyrim's dungeons, dark fantasy, and monsters who take themselves far too seriously"],
	]:
		cb.add_child(UiTheme.label(line[0].to_upper(), 15, UiTheme.COL_GOLD, UiTheme.font_ui_bold()))
		var bl := UiTheme.body(line[1], 19, UiTheme.COL_TEXT)
		cb.add_child(bl)
	var back := UiTheme.button("Back", 160)
	back.pressed.connect(func() -> void: _show("menu"))
	cb.add_child(back)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 1.2).set_trans(Tween.TRANS_SINE)
	_show("menu")


func _overlay_panel(root: Control, title: String) -> Control:
	var wrap := MarginContainer.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.add_theme_constant_override("margin_left", 560)
	wrap.add_theme_constant_override("margin_right", 60)
	wrap.add_theme_constant_override("margin_top", 60)
	wrap.add_theme_constant_override("margin_bottom", 60)
	root.add_child(wrap)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiTheme.panel_style("frame"))
	wrap.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pc.add_child(v)
	v.add_child(UiTheme.heading(title, 28))
	v.add_child(UiTheme.divider())
	wrap.set_meta("body", v)
	return wrap


func _show(which: String) -> void:
	_settings_wrap.visible = which == "settings"
	_credits_wrap.visible = which == "credits"
	if which == "menu" and _menu_box.get_child_count() > 0:
		(_menu_box.get_child(0) as Control).call_deferred("grab_focus")


func _menu_btn(text: String, cb: Callable) -> Button:
	var b := UiTheme.button(text, 380, 21)
	b.custom_minimum_size.y = 46
	b.pressed.connect(cb)
	_menu_box.add_child(b)
	return b


func _save_summary() -> String:
	var f := FileAccess.open(SnapshotManager.DEFAULT_SAVE_PATH, FileAccess.READ)
	if f == null:
		return ""
	var d: Variant = JSON.parse_string(f.get_as_text())
	if not (d is Dictionary):
		return ""
	var dd: Dictionary = d
	var lvl := int(dd.get("progression", {}).get("level", 1))
	return "Floor %d  ·  Level %d  ·  %d gold" % [int(dd.get("floor_number", 1)), lvl, int(dd.get("gold", 0))]


func _on_continue() -> void:
	_start_game(false)


func _on_new() -> void:
	if FileAccess.file_exists(SnapshotManager.DEFAULT_SAVE_PATH):
		MenuScreen.confirm(self, "Begin a new expedition?", "Your current saved expedition will be overwritten.", "Start Fresh", func() -> void: _start_game(true))
	else:
		_start_game(true)


func _start_game(fresh: bool) -> void:
	if fresh:
		SnapshotManager.delete_save_file(SnapshotManager.DEFAULT_SAVE_PATH)
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var loading := UiTheme.label("Descending…", 28, UiTheme.COL_GOLD_BRIGHT, UiTheme.font_heading(), HORIZONTAL_ALIGNMENT_CENTER)
	loading.set_anchors_preset(Control.PRESET_CENTER)
	loading.offset_left = -300
	loading.offset_right = 300
	loading.modulate.a = 0.0
	_fade.add_child(loading)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.6)
	tw.parallel().tween_property(loading, "modulate:a", 1.0, 0.6)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(GAME_SCENE))
