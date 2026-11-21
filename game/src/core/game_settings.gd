extends Node
## Tier 1 Autoload: Persistent player settings (graphics, audio, controls, gameplay, accessibility).
## Saved to user://settings.cfg; every change is applied live and broadcast via `changed`.

signal changed(section: String, key: String, value: Variant)

const SETTINGS_PATH := "user://settings.cfg"
const QUALITY_NAMES := ["Low", "Medium", "High", "Ultra"]
const REBINDABLE_ACTIONS := [
	["move_forward", "Move Forward"], ["move_backward", "Move Backward"], ["move_left", "Strafe Left"],
	["move_right", "Strafe Right"], ["jump", "Jump"], ["sprint", "Sprint"], ["interact", "Interact / Loot"],
	["right_hand_action", "Right Hand (Attack / Draw Bow)"], ["left_hand_action", "Left Hand (Block / Cast)"],
	["toggle_camera", "Toggle 1st / 3rd Person"], ["toggle_inventory", "Inventory & Character"],
	["toggle_map", "Dungeon Map"], ["quick_potion", "Quick Health Potion"],
	["hotbar_1", "Hotbar Slot 1"], ["hotbar_2", "Hotbar Slot 2"], ["hotbar_3", "Hotbar Slot 3"], ["hotbar_4", "Hotbar Slot 4"],
	["hotbar_5", "Hotbar Slot 5"], ["hotbar_6", "Hotbar Slot 6"], ["hotbar_7", "Hotbar Slot 7"], ["hotbar_8", "Hotbar Slot 8"],
	["dismiss_hint", "Dismiss Tutorial Hint"], ["toggle_console", "Playtest Console"],
]

const DEFAULTS := {
	"graphics": {
		"quality": 2,
		"window_mode": "windowed",
		"vsync": true,
		"max_fps": 0,
		"render_scale": 1.0,
		"fsr": false,
		"brightness": 1.0,
		"fov": 78.0,
		"show_fps": false,
	},
	"audio": {
		"master": 0.85,
		"music": 0.7,
		"sfx": 0.9,
		"ambience": 0.75,
		"ui": 0.8,
	},
	"controls": {
		"mouse_sensitivity": 1.0,
		"invert_y": false,
		"toggle_sprint": false,
		"bindings": {},
	},
	"gameplay": {
		"head_bob": 1.0,
		"camera_shake": 1.0,
		"show_damage_numbers": true,
		"enemy_health_bars": "damaged",
		"hud_opacity": 1.0,
		"crosshair": "dot",
		"compass": true,
		"confirm_destructive": true,
		"auto_save_on_quit": true,
	},
	"accessibility": {
		"ui_scale": 1.0,
		"colorblind": "off",
		"subtitles": true,
		"reduce_flashing": false,
		"high_contrast": false,
	},
}

var _data: Dictionary = {}
var _default_bindings: Dictionary = {}
var _colorblind_layer: CanvasLayer = null


func _ready() -> void:
	_ensure_extra_actions()
	_capture_default_bindings()
	load_settings()
	call_deferred("apply_all")


func _ensure_extra_actions() -> void:
	# Actions added by the UI/QoL overhaul (kept out of project.godot so defaults live in one place)
	var extra := {
		"toggle_map": [KEY_M],
		"dismiss_hint": [KEY_H],
		"ui_quick_save": [KEY_F5],
	}
	for action in extra.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
			for kc in extra[action]:
				var ev := InputEventKey.new()
				ev.physical_keycode = kc
				InputMap.action_add_event(action, ev)


func _capture_default_bindings() -> void:
	for pair in REBINDABLE_ACTIONS:
		var a: String = pair[0]
		if InputMap.has_action(a):
			_default_bindings[a] = InputMap.action_get_events(a).duplicate()


# ---------------------------------------------------------------------------
# Access
# ---------------------------------------------------------------------------

func get_value(section: String, key: String) -> Variant:
	if _data.has(section) and (_data[section] as Dictionary).has(key):
		return _data[section][key]
	return DEFAULTS.get(section, {}).get(key, null)


func set_value(section: String, key: String, value: Variant, save: bool = true) -> void:
	if not _data.has(section):
		_data[section] = {}
	_data[section][key] = value
	_apply(section, key)
	changed.emit(section, key, value)
	if save:
		save_settings()


func get_quality() -> int:
	return int(get_value("graphics", "quality"))


func reset_section(section: String) -> void:
	_data[section] = (DEFAULTS.get(section, {}) as Dictionary).duplicate(true)
	if section == "controls":
		reset_bindings()
	for key in (_data[section] as Dictionary).keys():
		_apply(section, key)
		changed.emit(section, key, _data[section][key])
	save_settings()


# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

func load_settings() -> void:
	_data = DEFAULTS.duplicate(true)
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) != OK:
		return
	for section in DEFAULTS.keys():
		for key in (DEFAULTS[section] as Dictionary).keys():
			if cf.has_section_key(section, key):
				_data[section][key] = cf.get_value(section, key)
	_restore_bindings()


func save_settings() -> void:
	var cf := ConfigFile.new()
	for section in _data.keys():
		for key in (_data[section] as Dictionary).keys():
			cf.set_value(section, key, _data[section][key])
	cf.save(SETTINGS_PATH)


# ---------------------------------------------------------------------------
# Key rebinding
# ---------------------------------------------------------------------------

static func event_to_dict(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		var k := ev as InputEventKey
		return {"type": "key", "code": int(k.physical_keycode if k.physical_keycode != 0 else k.keycode)}
	if ev is InputEventMouseButton:
		return {"type": "mouse", "button": int((ev as InputEventMouseButton).button_index)}
	return {}


static func dict_to_event(d: Dictionary) -> InputEvent:
	match str(d.get("type", "")):
		"key":
			var k := InputEventKey.new()
			k.physical_keycode = int(d.get("code", 0))
			return k
		"mouse":
			var m := InputEventMouseButton.new()
			m.button_index = int(d.get("button", 1))
			return m
	return null


static func event_label(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var k := ev as InputEventKey
		var code := k.physical_keycode if k.physical_keycode != 0 else k.keycode
		var label := OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(code)) if DisplayServer.get_name() != "headless" else OS.get_keycode_string(code)
		if label.is_empty():
			label = OS.get_keycode_string(code)
		return label
	if ev is InputEventMouseButton:
		match (ev as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT: return "LMB"
			MOUSE_BUTTON_RIGHT: return "RMB"
			MOUSE_BUTTON_MIDDLE: return "MMB"
			MOUSE_BUTTON_XBUTTON1: return "Mouse 4"
			MOUSE_BUTTON_XBUTTON2: return "Mouse 5"
		return "Mouse %d" % (ev as InputEventMouseButton).button_index
	return "?"


func action_label(action: String) -> String:
	if not InputMap.has_action(action):
		return "?"
	var evs := InputMap.action_get_events(action)
	if evs.is_empty():
		return "—"
	return event_label(evs[0])


## Rebinds `action` to `ev`. Returns the name of an action that previously used the same input
## (that conflicting binding is swapped to this action's old input so nothing is left unbound).
func rebind(action: String, ev: InputEvent) -> String:
	if not InputMap.has_action(action):
		return ""
	var new_d := event_to_dict(ev)
	var old_evs := InputMap.action_get_events(action)
	var conflict := ""
	for pair in REBINDABLE_ACTIONS:
		var other: String = pair[0]
		if other == action or not InputMap.has_action(other):
			continue
		for oe in InputMap.action_get_events(other):
			if event_to_dict(oe) == new_d:
				conflict = other
				InputMap.action_erase_event(other, oe)
				if not old_evs.is_empty():
					InputMap.action_add_event(other, old_evs[0])
				break
		if not conflict.is_empty():
			break
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, dict_to_event(new_d))
	_store_bindings()
	return conflict


func reset_bindings() -> void:
	for a in _default_bindings.keys():
		InputMap.action_erase_events(a)
		for ev in _default_bindings[a]:
			InputMap.action_add_event(a, ev)
	_store_bindings()


func _store_bindings() -> void:
	var out := {}
	for pair in REBINDABLE_ACTIONS:
		var a: String = pair[0]
		if InputMap.has_action(a):
			var arr: Array = []
			for ev in InputMap.action_get_events(a):
				var d := event_to_dict(ev)
				if not d.is_empty():
					arr.append(d)
			out[a] = arr
	if not _data.has("controls"):
		_data["controls"] = {}
	_data["controls"]["bindings"] = out
	save_settings()


func _restore_bindings() -> void:
	var b: Dictionary = _data.get("controls", {}).get("bindings", {})
	for a in b.keys():
		if not InputMap.has_action(a):
			continue
		var arr: Array = b[a]
		if arr.is_empty():
			continue
		InputMap.action_erase_events(a)
		for d in arr:
			var ev := dict_to_event(d)
			if ev != null:
				InputMap.action_add_event(a, ev)


# ---------------------------------------------------------------------------
# Live application
# ---------------------------------------------------------------------------

func apply_all() -> void:
	for section in _data.keys():
		for key in (_data[section] as Dictionary).keys():
			_apply(section, key)


func _headless() -> bool:
	return DisplayServer.get_name() == "headless"


func _apply(section: String, key: String) -> void:
	var v: Variant = get_value(section, key)
	match section:
		"graphics":
			_apply_graphics(key, v)
		"audio":
			_apply_audio(key, float(v))
		"accessibility":
			_apply_accessibility(key, v)


func _apply_graphics(key: String, v: Variant) -> void:
	if _headless() or not is_inside_tree():
		if key == "quality":
			VfxFactory.quality = clampi(int(v), 0, 2)
		return
	var vp := get_tree().root
	match key:
		"quality":
			VfxFactory.quality = clampi(int(v), 0, 2)
			var q := int(v)
			RenderingServer.directional_shadow_atlas_set_size(2048 if q <= 1 else 4096, true)
			vp.positional_shadow_atlas_size = 2048 if q <= 1 else 4096
			vp.msaa_3d = Viewport.MSAA_DISABLED if q == 0 else (Viewport.MSAA_2X if q == 1 else Viewport.MSAA_4X)
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q >= 1 else Viewport.SCREEN_SPACE_AA_DISABLED
			vp.use_taa = false
			RenderingServer.environment_set_volumetric_fog_volume_size(64 if q <= 1 else 96, 64 if q <= 1 else 96)
			RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_LOW if q <= 1 else RenderingServer.ENV_SSAO_QUALITY_MEDIUM, true, 0.5, 2, 50, 300)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW if q <= 1 else RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
		"window_mode":
			match str(v):
				"fullscreen":
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
				"borderless":
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
				_:
					if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
						DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		"vsync":
			var want := DisplayServer.VSYNC_ENABLED if bool(v) else DisplayServer.VSYNC_DISABLED
			if DisplayServer.window_get_vsync_mode() != want:
				DisplayServer.window_set_vsync_mode(want)
		"max_fps":
			Engine.max_fps = int(v)
		"render_scale", "fsr":
			vp.scaling_3d_scale = float(get_value("graphics", "render_scale"))
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2 if bool(get_value("graphics", "fsr")) and float(get_value("graphics", "render_scale")) < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR


func _apply_audio(key: String, v: float) -> void:
	var bus_map: Dictionary = {"master": "Master", "music": "Music", "sfx": "SFX", "ambience": "Ambience", "ui": "UI"}
	var bus_name: String = str(bus_map.get(key, ""))
	if bus_name.is_empty():
		return
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(0.0001, v)))
	AudioServer.set_bus_mute(idx, v <= 0.001)


func _apply_accessibility(key: String, v: Variant) -> void:
	if _headless() or not is_inside_tree():
		return
	match key:
		"ui_scale":
			get_tree().root.content_scale_factor = clampf(float(v), 0.75, 1.6)
		"colorblind":
			_set_colorblind(str(v))


func _set_colorblind(mode: String) -> void:
	if _colorblind_layer == null:
		_colorblind_layer = CanvasLayer.new()
		_colorblind_layer.layer = 120
		var rect := ColorRect.new()
		rect.name = "Filter"
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sh := Shader.new()
		sh.code = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform int mode = 0;
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	// Daltonization: simulate the deficiency, then shift the lost information into visible channels.
	mat3 sim;
	if (mode == 1) { sim = mat3(vec3(0.152, 0.115, -0.004), vec3(1.053, 0.786, -0.048), vec3(-0.205, 0.099, 1.052)); }
	else if (mode == 2) { sim = mat3(vec3(0.367, 0.280, -0.012), vec3(0.861, 0.673, 0.043), vec3(-0.228, 0.047, 0.969)); }
	else { sim = mat3(vec3(1.256, -0.078, 0.005), vec3(-0.077, 0.931, 0.691), vec3(-0.179, 0.148, 0.304)); }
	vec3 s = sim * c;
	vec3 err = c - s;
	vec3 shift = vec3(0.0, err.r * 0.7 + err.g, err.r * 0.7 + err.b);
	COLOR = vec4(clamp(c + shift * 0.9, 0.0, 1.0), 1.0);
}
"""
		var mat := ShaderMaterial.new()
		mat.shader = sh
		rect.material = mat
		_colorblind_layer.add_child(rect)
		add_child(_colorblind_layer)
	var r := _colorblind_layer.get_node("Filter") as ColorRect
	var modes: Dictionary = {"protanopia": 1, "deuteranopia": 2, "tritanopia": 3}
	var m: int = int(modes.get(mode, 0))
	_colorblind_layer.visible = m != 0
	(r.material as ShaderMaterial).set_shader_parameter("mode", m)
