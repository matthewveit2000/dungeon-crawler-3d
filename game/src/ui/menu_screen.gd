class_name MenuScreen
extends CanvasLayer
## Shared base for full-screen menus: blurred & darkened game backdrop, themed root, fade transitions.

const BLUR_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur_lod = 2.5;
uniform float darken = 0.55;
uniform float desat = 0.45;
void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, blur_lod).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l), desat);
	vec2 d = SCREEN_UV - 0.5;
	float vig = smoothstep(0.85, 0.2, length(d * vec2(1.2, 1.0)));
	c *= (1.0 - darken) * mix(0.55, 1.0, vig);
	c = mix(c, c * vec3(1.05, 0.97, 0.88), 0.4);
	COLOR = vec4(c, 1.0);
}
"""

var root: Control = null
var backdrop: ColorRect = null
var _fade_tw: Tween = null


func _init() -> void:
	visible = false


func build_base(p_layer: int = 20, blur: bool = true) -> void:
	layer = p_layer
	if blur:
		backdrop = ColorRect.new()
		backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
		backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
		var sh := Shader.new()
		sh.code = BLUR_SHADER
		var m := ShaderMaterial.new()
		m.shader = sh
		backdrop.material = m
		add_child(backdrop)
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.get_theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE if not blur else Control.MOUSE_FILTER_PASS
	add_child(root)


func show_animated() -> void:
	visible = true
	if root == null or not is_inside_tree():
		return
	if _fade_tw != null and _fade_tw.is_valid():
		_fade_tw.kill()
	root.modulate.a = 0.0
	root.position.y = 10.0
	_fade_tw = create_tween().set_parallel(true)
	_fade_tw.tween_property(root, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_fade_tw.tween_property(root, "position:y", 0.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func hide_now() -> void:
	visible = false


## A titled ornate frame panel centred on screen.
func make_frame(min_size: Vector2, title: String = "") -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var pc := PanelContainer.new()
	pc.custom_minimum_size = min_size
	pc.add_theme_stylebox_override("panel", UiTheme.panel_style("frame"))
	center.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pc.add_child(v)
	if not title.is_empty():
		v.add_child(UiTheme.heading(title, 30, UiTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER))
		var d := UiTheme.divider(0)
		v.add_child(d)
	return v


## Modal yes/no confirmation over the current menu (QoL: protects destructive actions).
static func confirm(parent: Node, title: String, body: String, yes_text: String, on_yes: Callable) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	parent.add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.theme = UiTheme.get_theme()
	layer.add_child(center)
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(520, 0)
	pc.add_theme_stylebox_override("panel", UiTheme.panel_style("frame"))
	center.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	pc.add_child(v)
	v.add_child(UiTheme.heading(title, 26, UiTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UiTheme.divider())
	var b := UiTheme.body(body, 19, UiTheme.COL_TEXT)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(b)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	var no := UiTheme.button("Cancel", 170)
	var yes := UiTheme.button(yes_text, 170)
	yes.add_theme_color_override("font_color", UiTheme.COL_DANGER)
	row.add_child(no)
	row.add_child(yes)
	no.pressed.connect(layer.queue_free)
	yes.pressed.connect(func() -> void:
		layer.queue_free()
		on_yes.call()
	)
	no.grab_focus()
