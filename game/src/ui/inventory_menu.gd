class_name InventoryMenu
extends CanvasLayer
## Skyrim-Style Inventory, Equipment Slots & Hybrid Progression Menu (Tab / I).
## Pauses world simulation and 5-day timer while open (D-016).

var _player: PlayerController = null
var _panel: PanelContainer = null
var _slots_box: VBoxContainer = null
var _bag_box: VBoxContainer = null
var _prog_box: VBoxContainer = null
var _on_close_cb: Callable = Callable()


func setup(player: PlayerController, on_close: Callable) -> void:
	_player = player
	_on_close_cb = on_close
	layer = 12
	visible = false
	_build_ui()


func open_menu() -> void:
	visible = true
	refresh()


func close_menu() -> void:
	visible = false
	if _on_close_cb.is_valid():
		_on_close_cb.call()


func refresh() -> void:
	if _player == null or _slots_box == null:
		return
	for c in _slots_box.get_children():
		c.queue_free()
	for c in _bag_box.get_children():
		c.queue_free()
	for c in _prog_box.get_children():
		c.queue_free()

	# Equipped Skyrim Slots
	for slot in DataLoader.get_items_pack().get("slots", []):
		var item: Dictionary = _player.equipment.get(slot, {})
		var lbl := Label.new()
		var item_name := str(item.get("name", "— Empty —")) if not item.is_empty() else "— Empty —"
		lbl.text = "%s: %s" % [str(slot).replace("_", " ").capitalize(), item_name]
		if not item.is_empty() and item.has("rarity_color"):
			lbl.modulate = Color.html(str(item["rarity_color"]))
		_slots_box.add_child(lbl)

	# Inventory Items
	for idx in range(_player.inventory.size()):
		var item: Dictionary = _player.inventory[idx]
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = "%s (%s)" % [str(item.get("name", "Item")), str(item.get("rarity", "common")).capitalize()]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if item.has("rarity_color"):
			lbl.modulate = Color.html(str(item["rarity_color"]))
		row.add_child(lbl)

		var cat := str(item.get("category", ""))
		if cat == "consumable":
			var use_btn := Button.new()
			use_btn.text = "Use"
			var captured := idx
			use_btn.pressed.connect(func() -> void:
				_player.use_consumable(captured)
				refresh()
			)
			row.add_child(use_btn)
		else:
			var eq_btn := Button.new()
			eq_btn.text = "Equip"
			var captured := idx
			eq_btn.pressed.connect(func() -> void:
				_player.equip_from_inventory(captured)
				refresh()
			)
			row.add_child(eq_btn)
			if bool(item.get("can_offhand", false)):
				var lh_btn := Button.new()
				lh_btn.text = "Equip L"
				lh_btn.pressed.connect(func() -> void:
					_player.equip_from_inventory(captured, "left_hand")
					refresh()
				)
				row.add_child(lh_btn)
		_bag_box.add_child(row)

	# Hybrid Progression Panel (XP/Level + Attributes + Perks + Skyrim Use-to-Improve)
	var prog := _player.progression
	if prog != null:
		var hdr := Label.new()
		hdr.text = "Level %d  |  XP: %.0f / %.0f  |  Gold: %d" % [prog.level, prog.xp, prog.xp_for_next_level(), _player.gold]
		_prog_box.add_child(hdr)

		if prog.attribute_points > 0:
			var attr_row := HBoxContainer.new()
			var albl := Label.new()
			albl.text = "Attr Pts (%d):" % prog.attribute_points
			attr_row.add_child(albl)
			for attr in ["health", "magicka", "stamina"]:
				var b := Button.new()
				b.text = "+%s" % attr.capitalize()
				var a_cap: String = str(attr)
				b.pressed.connect(func() -> void:
					if prog.spend_attribute(a_cap):
						_player.recalculate_vitals(false)
						refresh()
				)
				attr_row.add_child(b)
			_prog_box.add_child(attr_row)

		if prog.perk_points > 0:
			for p in DataLoader.get_progression_pack().get("perks", []):
				var pid := str(p["id"])
				if prog.unlocked_perks.has(pid):
					continue
				var pb := Button.new()
				pb.text = "Unlock Perk: %s — %s" % [str(p["name"]), str(p["description"])]
				pb.pressed.connect(func() -> void:
					if prog.unlock_perk(pid):
						_player.recalculate_vitals(false)
						refresh()
				)
				_prog_box.add_child(pb)

		var skill_hdr := Label.new()
		skill_hdr.text = "Skyrim Use-to-Improve Proficiencies:"
		skill_hdr.modulate = Color(0.75, 0.88, 1.0)
		_prog_box.add_child(skill_hdr)
		for s in prog.skill_levels.keys():
			var sl := Label.new()
			sl.text = "  %s: Lv %d" % [str(s).replace("_", " ").capitalize(), int(prog.skill_levels[s])]
			_prog_box.add_child(sl)


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.08
	_panel.anchor_right = 0.92
	_panel.anchor_top = 0.08
	_panel.anchor_bottom = 0.90
	add_child(_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	_panel.add_child(outer)

	var top := HBoxContainer.new()
	var title := Label.new()
	title.text = "CHARACTER, INVENTORY & SKILLS (GAME PAUSED)"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close_btn := Button.new()
	close_btn.text = "Close [Tab / Esc]"
	close_btn.pressed.connect(close_menu)
	top.add_child(title)
	top.add_child(close_btn)
	outer.add_child(top)

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 18)
	outer.add_child(cols)

	var col1 := VBoxContainer.new()
	col1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h1 := Label.new()
	h1.text = "EQUIPPED SLOTS"
	col1.add_child(h1)
	_slots_box = VBoxContainer.new()
	col1.add_child(_slots_box)
	cols.add_child(col1)

	var col2 := VBoxContainer.new()
	col2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h2 := Label.new()
	h2.text = "BACKPACK"
	col2.add_child(h2)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bag_box = VBoxContainer.new()
	_bag_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_bag_box)
	col2.add_child(scroll)
	cols.add_child(col2)

	var col3 := VBoxContainer.new()
	col3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h3 := Label.new()
	h3.text = "PROGRESSION"
	col3.add_child(h3)
	_prog_box = VBoxContainer.new()
	col3.add_child(_prog_box)
	cols.add_child(col3)
