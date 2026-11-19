class_name InventoryMenu
extends CanvasLayer
## Skyrim-Inspired Dark-Fantasy Inventory, Equipment & Hybrid Progression Screen.
## Opening completely pauses world simulation & the 5-day floor collapse clock (D-016).

var _root: Control = null
var _header_stats: Label = null
var _equip_box: VBoxContainer = null
var _bag_box: VBoxContainer = null
var _prog_box: VBoxContainer = null
var _player: PlayerController = null
var _close_cb: Callable = Callable()


func _ready() -> void:
	layer = 20
	visible = false
	_build_ui()


func setup(p_player: PlayerController, close_cb: Callable) -> void:
	_player = p_player
	_close_cb = close_cb


func open_menu() -> void:
	refresh()
	visible = true


func close_menu() -> void:
	visible = false


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.015, 0.02, 0.035, 0.74)
	_root.add_child(dim)

	var frame := PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.offset_left = -590
	frame.offset_right = 590
	frame.offset_top = -318
	frame.offset_bottom = 318
	frame.add_theme_stylebox_override("panel", UiTheme.make_panel_style(UiTheme.COL_BG_DEEP, UiTheme.COL_GOLD, 2, 8, 22, 18))
	_root.add_child(frame)

	var main_v := VBoxContainer.new()
	main_v.add_theme_constant_override("separation", 14)
	frame.add_child(main_v)

	# Header Row
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 12)
	main_v.add_child(hdr)

	var title_v := VBoxContainer.new()
	title_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_v.add_theme_constant_override("separation", 2)
	hdr.add_child(title_v)

	var title := Label.new()
	title.text = "CHARACTER, GEAR & SKYRIM PROFICIENCIES"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", UiTheme.COL_GOLD_BRIGHT)
	title_v.add_child(title)

	_header_stats = Label.new()
	_header_stats.add_theme_font_size_override("font_size", 12)
	_header_stats.add_theme_color_override("font_color", UiTheme.COL_MUTED)
	title_v.add_child(_header_stats)

	var pause_pill := PanelContainer.new()
	pause_pill.add_theme_stylebox_override("panel", UiTheme.make_panel_style(Color(0.08, 0.22, 0.16, 0.9), UiTheme.COL_EMERALD, 1, 10, 12, 4))
	var plbl := Label.new()
	plbl.text = "⏸ 5-DAY CLOCK PAUSED"
	plbl.add_theme_font_size_override("font_size", 11)
	plbl.add_theme_color_override("font_color", Color(0.45, 0.96, 0.72))
	pause_pill.add_child(plbl)
	hdr.add_child(pause_pill)

	var close_btn := Button.new()
	close_btn.text = "Close [Tab]"
	UiTheme.style_button(close_btn, UiTheme.COL_GOLD, 13)
	close_btn.pressed.connect(func() -> void:
		if _close_cb.is_valid():
			_close_cb.call()
	)
	hdr.add_child(close_btn)

	# Divider
	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(0, 1)
	div.color = UiTheme.COL_GOLD_DIM
	main_v.add_child(div)

	# 3-Column Layout
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 16)
	main_v.add_child(cols)

	_equip_box = _make_column(cols, "Equipped Slots (Skyrim)", 0.92)
	_bag_box = _make_column(cols, "Backpack & Gear", 1.18)
	_prog_box = _make_column(cols, "Level, Perks & Skills", 1.15)


func _make_column(parent: Control, heading: String, stretch: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = stretch
	panel.add_theme_stylebox_override("panel", UiTheme.make_panel_style(UiTheme.COL_BG_PANEL, UiTheme.COL_GOLD_DIM, 1, 6, 12, 10))
	parent.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	panel.add_child(outer)
	outer.add_child(UiTheme.make_section_header(heading, 14))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	scroll.add_child(content)
	return content


func refresh() -> void:
	if _player == null:
		return
	for box in [_equip_box, _bag_box, _prog_box]:
		for c in box.get_children():
			c.queue_free()

	var prog := _player.progression
	var lvl := prog.level if prog != null else 1
	_header_stats.text = "Level %d  •  HP %.0f/%.0f  •  MP %.0f/%.0f  •  SP %.0f/%.0f  •  Armor %.0f  •  %d Syndicate Gold" % [
		lvl, _player.health, _player.max_health, _player.magicka, _player.max_magicka,
		_player.stamina, _player.max_stamina, _player.get_total_armor(), _player.gold
	]

	# 1. Skyrim Equipment Slots
	var slot_names := ["right_hand", "left_hand", "head", "chest", "hands", "feet", "ring_1", "ring_2", "amulet"]
	for slot in slot_names:
		var item: Dictionary = _player.equipment.get(slot, {})
		var rarity := str(item.get("rarity", "common")) if not item.is_empty() else ""
		var border := UiTheme.rarity_color(rarity) if not item.is_empty() else Color(0.28, 0.30, 0.36, 0.5)
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UiTheme.make_panel_style(UiTheme.COL_BG_CARD, border, 1, 5, 10, 6))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		card.add_child(v)

		var top := HBoxContainer.new()
		v.add_child(top)
		var sl := Label.new()
		sl.text = slot.replace("_", " ").capitalize()
		sl.add_theme_font_size_override("font_size", 11)
		sl.add_theme_color_override("font_color", UiTheme.COL_MUTED)
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(sl)
		if not item.is_empty():
			var rtag := Label.new()
			rtag.text = rarity.to_upper()
			rtag.add_theme_font_size_override("font_size", 10)
			rtag.add_theme_color_override("font_color", UiTheme.rarity_color(rarity))
			top.add_child(rtag)

		var name_l := Label.new()
		if item.is_empty():
			name_l.text = "— Empty —"
			name_l.add_theme_color_override("font_color", Color(0.45, 0.48, 0.54))
		else:
			name_l.text = str(item.get("name", "Item"))
			name_l.add_theme_color_override("font_color", UiTheme.rarity_color(rarity))
		name_l.add_theme_font_size_override("font_size", 13)
		v.add_child(name_l)

		if not item.is_empty():
			var stat_str := _format_item_stats(item)
			if not stat_str.is_empty():
				var st_l := Label.new()
				st_l.text = stat_str
				st_l.add_theme_font_size_override("font_size", 11)
				st_l.add_theme_color_override("font_color", UiTheme.COL_TEXT)
				v.add_child(st_l)
		_equip_box.add_child(card)

	# 2. Backpack Items
	if _player.inventory.is_empty():
		var empty_l := Label.new()
		empty_l.text = "Your pack is empty. Loot chests and fallen foes!"
		empty_l.add_theme_color_override("font_color", UiTheme.COL_MUTED)
		_bag_box.add_child(empty_l)
	else:
		for idx in range(_player.inventory.size()):
			var item: Dictionary = _player.inventory[idx]
			var rarity := str(item.get("rarity", "common"))
			var card := PanelContainer.new()
			card.add_theme_stylebox_override("panel", UiTheme.make_panel_style(UiTheme.COL_BG_CARD, UiTheme.rarity_color(rarity), 1, 5, 10, 7))
			var v := VBoxContainer.new()
			v.add_theme_constant_override("separation", 4)
			card.add_child(v)

			var top := HBoxContainer.new()
			v.add_child(top)
			var nm := Label.new()
			nm.text = str(item.get("name", "Item"))
			nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nm.add_theme_font_size_override("font_size", 13)
			nm.add_theme_color_override("font_color", UiTheme.rarity_color(rarity))
			top.add_child(nm)

			var val := Label.new()
			val.text = "%dg" % int(item.get("value", item.get("base_value", 0)))
			val.add_theme_font_size_override("font_size", 12)
			val.add_theme_color_override("font_color", UiTheme.COL_GOLD)
			top.add_child(val)

			var stats_l := Label.new()
			stats_l.text = _format_item_stats(item)
			stats_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			stats_l.add_theme_font_size_override("font_size", 11)
			stats_l.add_theme_color_override("font_color", UiTheme.COL_MUTED)
			v.add_child(stats_l)

			var btn_row := HBoxContainer.new()
			btn_row.add_theme_constant_override("separation", 6)
			v.add_child(btn_row)
			var captured_idx: int = idx
			if str(item.get("category", "")) == "consumable":
				var use_btn := Button.new()
				use_btn.text = "Drink"
				UiTheme.style_button(use_btn, UiTheme.COL_EMERALD, 12)
				use_btn.pressed.connect(func() -> void:
					_player.use_consumable(captured_idx)
					refresh()
				)
				btn_row.add_child(use_btn)
			else:
				var eq_btn := Button.new()
				eq_btn.text = "Equip"
				UiTheme.style_button(eq_btn, UiTheme.COL_GOLD, 12)
				eq_btn.pressed.connect(func() -> void:
					_player.equip_from_inventory(captured_idx)
					refresh()
				)
				btn_row.add_child(eq_btn)
				if str(item.get("slot", "")) in ["right_hand", "left_hand"] and not bool(item.get("two_handed", false)):
					var lh_btn := Button.new()
					lh_btn.text = "Off-Hand [L]"
					UiTheme.style_button(lh_btn, UiTheme.COL_CYAN, 12)
					lh_btn.pressed.connect(func() -> void:
						_player.equip_from_inventory(captured_idx, "left_hand")
						refresh()
					)
					btn_row.add_child(lh_btn)
			_bag_box.add_child(card)

	# 3. Hybrid Progression (XP/Attributes/Perks + Skyrim Use-to-Improve Skills)
	if prog != null:
		var xp_card := PanelContainer.new()
		xp_card.add_theme_stylebox_override("panel", UiTheme.make_panel_style(UiTheme.COL_BG_CARD, UiTheme.COL_GOLD_DIM, 1, 5, 10, 8))
		var xv := VBoxContainer.new()
		xv.add_theme_constant_override("separation", 5)
		xp_card.add_child(xv)
		var lvl_l := Label.new()
		lvl_l.text = "Crawler Level %d   •   XP %.0f / %.0f" % [prog.level, prog.xp, prog.xp_for_next_level()]
		lvl_l.add_theme_font_size_override("font_size", 13)
		lvl_l.add_theme_color_override("font_color", UiTheme.COL_GOLD_BRIGHT)
		xv.add_child(lvl_l)
		var xp_bar := ProgressBar.new()
		xp_bar.show_percentage = false
		xp_bar.max_value = maxf(1.0, prog.xp_for_next_level())
		xp_bar.value = prog.xp
		UiTheme.style_progress_bar(xp_bar, UiTheme.COL_GOLD, 10.0)
		xv.add_child(xp_bar)
		_prog_box.add_child(xp_card)

		if prog.attribute_points > 0:
			var attr_card := PanelContainer.new()
			attr_card.add_theme_stylebox_override("panel", UiTheme.make_panel_style(Color(0.14, 0.12, 0.08, 0.95), UiTheme.COL_GOLD_BRIGHT, 1, 5, 10, 8))
			var av := VBoxContainer.new()
			av.add_theme_constant_override("separation", 6)
			attr_card.add_child(av)
			var albl := Label.new()
			albl.text = "✦ LEVEL UP! Spend Attribute Points (%d)" % prog.attribute_points
			albl.add_theme_font_size_override("font_size", 12)
			albl.add_theme_color_override("font_color", UiTheme.COL_GOLD_BRIGHT)
			av.add_child(albl)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			av.add_child(row)
			var attr_specs := [
				{"key": "health", "lbl": "+15 HP", "col": UiTheme.COL_CRIMSON},
				{"key": "magicka", "lbl": "+15 MP", "col": UiTheme.COL_SAPPHIRE},
				{"key": "stamina", "lbl": "+15 SP", "col": UiTheme.COL_EMERALD},
			]
			for spec in attr_specs:
				var a_cap: String = str(spec["key"])
				var b := Button.new()
				b.text = str(spec["lbl"])
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				UiTheme.style_button(b, spec["col"], 12)
				b.pressed.connect(func() -> void:
					if prog.spend_attribute(a_cap):
						_player.recalculate_vitals(false)
						refresh()
				)
				row.add_child(b)
			_prog_box.add_child(attr_card)

		if prog.perk_points > 0:
			var p_hdr := Label.new()
			p_hdr.text = "✦ UNLOCK PERKS (%d AVAILABLE)" % prog.perk_points
			p_hdr.add_theme_font_size_override("font_size", 12)
			p_hdr.add_theme_color_override("font_color", UiTheme.COL_GOLD_BRIGHT)
			_prog_box.add_child(p_hdr)
			for p in DataLoader.get_progression_pack().get("perks", []):
				var pid := str(p["id"])
				if prog.unlocked_perks.has(pid):
					continue
				var pb := Button.new()
				pb.text = "%s — %s" % [str(p["name"]), str(p["description"])]
				pb.alignment = HORIZONTAL_ALIGNMENT_LEFT
				pb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				UiTheme.style_button(pb, UiTheme.COL_GOLD, 11)
				pb.pressed.connect(func() -> void:
					if prog.unlock_perk(pid):
						_player.recalculate_vitals(false)
						refresh()
				)
				_prog_box.add_child(pb)

		var sh := Label.new()
		sh.text = "SKYRIM USE-TO-IMPROVE SKILLS"
		sh.add_theme_font_size_override("font_size", 12)
		sh.add_theme_color_override("font_color", UiTheme.COL_CYAN)
		_prog_box.add_child(sh)
		for s in prog.skill_levels.keys():
			var sname := str(s)
			var slvl := int(prog.skill_levels[s])
			var sxp := float(prog.skill_xp.get(s, 0.0))
			var srow := VBoxContainer.new()
			srow.add_theme_constant_override("separation", 2)
			var sl := Label.new()
			sl.text = "%s   Lv %d   (+%.0f%%)" % [sname.replace("_", " ").capitalize(), slvl, (prog.get_proficiency_damage_multiplier(sname) - 1.0) * 100.0]
			sl.add_theme_font_size_override("font_size", 12)
			sl.add_theme_color_override("font_color", UiTheme.COL_TEXT)
			srow.add_child(sl)
			var sbar := ProgressBar.new()
			sbar.show_percentage = false
			sbar.max_value = 100.0
			sbar.value = fmod(sxp, 100.0)
			UiTheme.style_progress_bar(sbar, UiTheme.COL_CYAN, 7.0)
			srow.add_child(sbar)
			_prog_box.add_child(srow)


func _format_item_stats(item: Dictionary) -> String:
	var parts: Array[String] = []
	if float(item.get("damage", 0.0)) > 0.0:
		parts.append("DMG %.0f" % float(item["damage"]))
	if float(item.get("armor", 0.0)) > 0.0:
		parts.append("ARM %.0f" % float(item["armor"]))
	if float(item.get("heal_health", 0.0)) > 0.0:
		parts.append("RESTORE +%.0f HP" % float(item["heal_health"]))
	if float(item.get("heal_magicka", 0.0)) > 0.0:
		parts.append("RESTORE +%.0f MP" % float(item["heal_magicka"]))
	if float(item.get("heal_amount", 0.0)) > 0.0:
		parts.append("HEAL +%.0f" % float(item["heal_amount"]))
	if float(item.get("magicka_cost", 0.0)) > 0.0:
		parts.append("MP %.0f" % float(item["magicka_cost"]))
	var se := str(item.get("sponsored_effect", ""))
	if not se.is_empty():
		parts.append("★ %s" % se.replace("_", " ").to_upper())
	return "  •  ".join(parts)
