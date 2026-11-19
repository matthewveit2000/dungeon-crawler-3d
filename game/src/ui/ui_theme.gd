class_name UiTheme
extends RefCounted
## Unified Skyrim-Meets-DCC Dark Fantasy UI Theme Builder.
## Replaces bare default Godot gray widgets with obsidian translucent glass panels,
## antique-gold bevel borders, carved inset cards, rarity badges, and sculpted gold-hover buttons.

const COL_BG_DEEP := Color(0.055, 0.062, 0.085, 0.94)
const COL_BG_PANEL := Color(0.085, 0.095, 0.125, 0.92)
const COL_BG_CARD := Color(0.115, 0.128, 0.165, 0.94)
const COL_BG_HUD := Color(0.045, 0.052, 0.070, 0.78)
const COL_GOLD := Color(0.84, 0.68, 0.36, 1.0)
const COL_GOLD_DIM := Color(0.56, 0.45, 0.25, 0.82)
const COL_GOLD_BRIGHT := Color(0.98, 0.85, 0.52, 1.0)
const COL_TEXT := Color(0.93, 0.91, 0.86, 1.0)
const COL_MUTED := Color(0.65, 0.69, 0.76, 1.0)
const COL_CRIMSON := Color(0.82, 0.22, 0.20, 1.0)
const COL_SAPPHIRE := Color(0.24, 0.54, 0.96, 1.0)
const COL_EMERALD := Color(0.24, 0.78, 0.46, 1.0)
const COL_CYAN := Color(0.32, 0.88, 0.98, 1.0)


static func make_panel_style(
	bg: Color = COL_BG_DEEP,
	border: Color = COL_GOLD_DIM,
	border_w: int = 2,
	radius: int = 6,
	pad_h: int = 14,
	pad_v: int = 10
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 3)
	return sb


static func style_button(btn: Button, accent: Color = COL_GOLD, font_size: int = 14) -> void:
	var normal := make_panel_style(Color(0.13, 0.145, 0.185, 0.95), Color(accent.r, accent.g, accent.b, 0.55), 1, 5, 12, 7)
	normal.shadow_size = 3
	var hover := make_panel_style(Color(0.20, 0.18, 0.15, 0.98), accent, 2, 5, 12, 7)
	hover.shadow_size = 5
	var pressed := make_panel_style(Color(0.26, 0.21, 0.13, 1.0), COL_GOLD_BRIGHT, 2, 5, 12, 7)
	pressed.shadow_size = 1
	var disabled := make_panel_style(Color(0.09, 0.095, 0.11, 0.7), Color(0.3, 0.3, 0.35, 0.4), 1, 5, 12, 7)
	disabled.shadow_size = 0

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", COL_TEXT)
	btn.add_theme_color_override("font_hover_color", COL_GOLD_BRIGHT)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", font_size)


static func style_progress_bar(bar: ProgressBar, fill_col: Color, height: float = 16.0) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.055, 0.075, 0.90)
	bg.border_color = COL_GOLD_DIM
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(3)

	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_col
	fill.border_color = Color(minf(1.0, fill_col.r + 0.22), minf(1.0, fill_col.g + 0.22), minf(1.0, fill_col.b + 0.22), 0.9)
	fill.border_width_top = 1
	fill.set_corner_radius_all(2)

	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	bar.custom_minimum_size.y = height


static func make_section_header(title_text: String, font_size: int = 16) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var lbl := Label.new()
	lbl.text = title_text.to_upper()
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	box.add_child(lbl)
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 1)
	rule.color = COL_GOLD_DIM
	box.add_child(rule)
	return box


static func rarity_color(rarity_id: String) -> Color:
	match rarity_id:
		"uncommon": return Color(0.36, 0.88, 0.48)
		"rare": return Color(0.38, 0.68, 1.0)
		"epic": return Color(0.78, 0.46, 1.0)
		"sponsored": return Color(1.0, 0.78, 0.24)
		_: return COL_TEXT
