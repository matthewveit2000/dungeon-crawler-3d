class_name InventoryMenu
extends MenuScreen
## Character & Inventory screen (time-paused, D-016).
## Tab 1 "Inventory": live 3D portrait of your crawler, equipment slots (click to unequip), filterable &
##   sortable bag grid with icons, hover/click detail card with stat comparison vs. equipped gear,
##   one-click Equip / Use / Off-hand actions, character summary with XP progress.
## Tab 2 "Skills & Perks": attribute point spending, perk cards and Skyrim use-to-improve skill progress.

const SLOT_LAYOUT := [
	["head", "Head"], ["chest", "Chest"], ["hands", "Hands"], ["feet", "Feet"],
	["amulet", "Amulet"], ["ring_1", "Ring"], ["ring_2", "Ring"],
	["right_hand", "Right Hand"], ["left_hand", "Left Hand"],
]

var _player: PlayerController = null
var _close_cb: Callable = Callable()
var _tabs: TabBar = null
const SLOT_SIZE := 72.0
var _inv_page: Control = null
var _skill_page: Control = null
var bestiary_page: BestiaryPage = null  ## Tab 3 (D-049)
var _equip_left: VBoxContainer = null
var _equip_right: VBoxContainer = null
var _hands_row: HBoxContainer = null
var _grid: GridContainer = null
var _detail: VBoxContainer = null
var _actions: HFlowContainer = null
var _summary: VBoxContainer = null
var _gold_lbl: Label = null
var _count_lbl: Label = null
var _filter: String = "all"
var _sort: String = "newest"
var _selected_idx: int = -1
var _selected_slot: String = ""
var _skills_box: VBoxContainer = null
var _perks_box: VBoxContainer = null
var _portrait_vp: SubViewport = null
var _portrait_char: CharacterVisual = null
var _filter_btns: Dictionary = {}
var _points_badge: Label = null
var _margin: MarginContainer = null
var _c1: PanelContainer = null
var _c3: VBoxContainer = null
var _portrait_box: SubViewportContainer = null
var _bag_scroll: ScrollContainer = null


func _ready() -> void:
	build_base(20, true)
	_build_ui()


func setup(p_player: PlayerController, close_cb: Callable, p_bestiary: Bestiary = null) -> void:
	_player = p_player
	_close_cb = close_cb
	if p_bestiary != null:
		set_bestiary(p_bestiary)


func set_bestiary(b: Bestiary) -> void:
	if bestiary_page != null:
		bestiary_page.bestiary = b


## Opens straight onto a tab (0 inventory, 1 skills, 2 bestiary).
func open_tab(i: int) -> void:
	_tabs.current_tab = i
	_show_tab(i)


func open_menu() -> void:
	_selected_idx = -1
	_selected_slot = ""
	_tabs.current_tab = 0
	_show_tab(0)
	refresh()
	show_animated()


func close_menu() -> void:
	hide_now()


func _process(delta: float) -> void:
	if visible and _portrait_char != null and is_instance_valid(_portrait_char):
		_portrait_char.rotation.y += delta * 0.35


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for k in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(k, 34)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 22)
	root.add_child(margin)
	_margin = margin
	root.resized.connect(_fit_layout)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	margin.add_child(outer)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	outer.add_child(header)
	header.add_child(UiTheme.label("CHARACTER", 34, UiTheme.COL_GOLD_BRIGHT, UiTheme.font_title()))
	_tabs = TabBar.new()
	_tabs.add_tab("Inventory")
	_tabs.add_tab("Skills & Perks")
	_tabs.add_tab("Bestiary")
	_tabs.tab_changed.connect(_show_tab)
	_tabs.clip_tabs = false
	_tabs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_tabs)
	_points_badge = UiTheme.label("", 16, UiTheme.COL_GOLD_BRIGHT, UiTheme.font_ui_bold())
	_points_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_points_badge)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(sp)
	var gold_row := HBoxContainer.new()
	gold_row.add_child(UiTheme.icon_rect(UiTheme.tex("icon_coin"), 22, UiTheme.COL_GOLD))
	_gold_lbl = UiTheme.label("", 22, UiTheme.COL_GOLD, UiTheme.font_ui_bold())
	gold_row.add_child(_gold_lbl)
	gold_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(gold_row)
	var close := UiTheme.button("Close  [Tab]", 150, 17)
	close.pressed.connect(func() -> void:
		if _close_cb.is_valid():
			_close_cb.call()
	)
	header.add_child(close)
	outer.add_child(UiTheme.divider())

	_inv_page = HBoxContainer.new()
	(_inv_page as HBoxContainer).add_theme_constant_override("separation", 16)
	_inv_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(_inv_page)

	# --- Column 1: portrait + equipment ---------------------------------------------
	var c1 := PanelContainer.new()
	_c1 = c1
	c1.custom_minimum_size.x = 340
	c1.add_theme_stylebox_override("panel", UiTheme.panel_style("frame"))
	_inv_page.add_child(c1)
	var c1v := VBoxContainer.new()
	c1v.add_theme_constant_override("separation", 6)
	c1.add_child(c1v)
	c1v.add_child(UiTheme.heading("Equipment", 20))
	var doll := HBoxContainer.new()
	doll.add_theme_constant_override("separation", 6)
	doll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c1v.add_child(doll)
	_equip_left = VBoxContainer.new()
	_equip_left.add_theme_constant_override("separation", 6)
	doll.add_child(_equip_left)
	var svc := SubViewportContainer.new()
	_portrait_box = svc
	svc.stretch = true
	svc.custom_minimum_size = Vector2(170, 300)
	svc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	doll.add_child(svc)
	_portrait_vp = SubViewport.new()
	_portrait_vp.transparent_bg = true
	_portrait_vp.own_world_3d = true
	_portrait_vp.size = Vector2i(220, 400)
	_portrait_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	svc.add_child(_portrait_vp)
	_equip_right = VBoxContainer.new()
	_equip_right.add_theme_constant_override("separation", 6)
	doll.add_child(_equip_right)
	_hands_row = HBoxContainer.new()
	_hands_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_hands_row.add_theme_constant_override("separation", 14)
	c1v.add_child(_hands_row)
	_build_portrait_scene()

	# --- Column 2: bag -------------------------------------------------------------
	var c2 := PanelContainer.new()
	c2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c2.add_theme_stylebox_override("panel", UiTheme.panel_style("frame"))
	_inv_page.add_child(c2)
	var c2v := VBoxContainer.new()
	c2v.add_theme_constant_override("separation", 8)
	c2.add_child(c2v)
	var bag_head := HBoxContainer.new()
	bag_head.add_theme_constant_override("separation", 6)
	c2v.add_child(bag_head)
	bag_head.add_child(UiTheme.heading("Pack", 20))
	_count_lbl = UiTheme.label("", 16, UiTheme.COL_MUTED, UiTheme.font_ui())
	_count_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bag_head.add_child(_count_lbl)
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_head.add_child(sp2)
	bag_head.add_child(UiTheme.label("Sort", 16, UiTheme.COL_MUTED, UiTheme.font_ui()))
	var sort := OptionButton.new()
	for pair in [["newest", "Newest"], ["rarity", "Rarity"], ["type", "Type"], ["value", "Value"], ["name", "Name"]]:
		sort.add_item(pair[1])
		sort.set_item_metadata(sort.item_count - 1, pair[0])
	sort.item_selected.connect(func(i: int) -> void:
		_sort = str(sort.get_item_metadata(i))
		refresh()
	)
	bag_head.add_child(sort)
	var filters := HFlowContainer.new()
	filters.add_theme_constant_override("h_separation", 6)
	filters.add_theme_constant_override("v_separation", 6)
	c2v.add_child(filters)
	for pair in [["all", "All"], ["weapons", "Weapons"], ["apparel", "Apparel"], ["magic", "Magic"], ["consumables", "Consumables"]]:
		var fb := UiTheme.button(pair[1], 0, 16)
		fb.toggle_mode = true
		fb.custom_minimum_size.y = 36
		var key: String = pair[0]
		fb.pressed.connect(func() -> void:
			_filter = key
			refresh()
		)
		_filter_btns[key] = fb
		filters.add_child(fb)
	var scroll := ScrollContainer.new()
	_bag_scroll = scroll
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# FB-014: SHOW_NEVER (not DISABLED) so the grid's width never props the menu wider than the screen
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.custom_minimum_size.x = 3 * (SLOT_SIZE + 8.0)
	c2v.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 4
	# Columns follow the available width so the pack never forces the screen wider (720p .. 4K)
	scroll.resized.connect(func() -> void:
		_grid.columns = maxi(3, int((scroll.size.x + 8.0) / (SLOT_SIZE + 8.0)))
	)
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_grid)
	var help := UiTheme.label("Click to inspect  ·  Double-click to equip or use  ·  Right-click to equip in the other hand", 15, UiTheme.COL_FAINT, UiTheme.font_ui())
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size.x = 200
	c2v.add_child(help)

	# --- Column 3: details + summary ----------------------------------------------------
	var c3 := VBoxContainer.new()
	_c3 = c3
	c3.custom_minimum_size.x = 350
	c3.clip_contents = true
	c3.add_theme_constant_override("separation", 12)
	_inv_page.add_child(c3)
	var dp := PanelContainer.new()
	dp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dp.add_theme_stylebox_override("panel", UiTheme.panel_style("frame"))
	c3.add_child(dp)
	var dpv := VBoxContainer.new()
	dpv.add_theme_constant_override("separation", 8)
	dp.add_child(dpv)
	var dscroll := ScrollContainer.new()
	dscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	dscroll.custom_minimum_size.x = 320
	dpv.add_child(dscroll)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dscroll.add_child(_detail)
	_actions = HFlowContainer.new()  # wraps instead of widening the column
	_actions.add_theme_constant_override("h_separation", 8)
	_actions.add_theme_constant_override("v_separation", 8)
	dpv.add_child(_actions)
	var sp3 := PanelContainer.new()
	sp3.add_theme_stylebox_override("panel", UiTheme.panel_style("soft"))
	c3.add_child(sp3)
	_summary = VBoxContainer.new()
	_summary.add_theme_constant_override("separation", 4)
	sp3.add_child(_summary)

	# --- Skills & perks page ----------------------------------------------------------------
	_skill_page = HBoxContainer.new()
	(_skill_page as HBoxContainer).add_theme_constant_override("separation", 16)
	_skill_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(_skill_page)
	bestiary_page = BestiaryPage.new()
	bestiary_page.visible = false
	outer.add_child(bestiary_page)
	var pp := PanelContainer.new()
	pp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pp.add_theme_stylebox_override("panel", UiTheme.panel_style("frame"))
	_skill_page.add_child(pp)
	var ps := ScrollContainer.new()
	ps.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pp.add_child(ps)
	_perks_box = VBoxContainer.new()
	_perks_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_perks_box.add_theme_constant_override("separation", 10)
	ps.add_child(_perks_box)
	var sk := PanelContainer.new()
	sk.custom_minimum_size.x = 460
	sk.add_theme_stylebox_override("panel", UiTheme.panel_style("frame"))
	_skill_page.add_child(sk)
	_skills_box = VBoxContainer.new()
	_skills_box.add_theme_constant_override("separation", 8)
	sk.add_child(_skills_box)


func _build_portrait_scene() -> void:
	var world := Node3D.new()
	_portrait_vp.add_child(world)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.05, 2.9)
	cam.fov = 38
	world.add_child(cam)
	cam.look_at(Vector3(0, 0.95, 0), Vector3.UP)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.35, 0.38, 0.48)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.environment = e
	world.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, 35, 0)
	key.light_color = Color(1.0, 0.82, 0.62)
	key.light_energy = 1.8
	world.add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-1.2, 2.0, -1.5)
	rim.light_color = Color(0.5, 0.65, 1.0)
	rim.light_energy = 2.5
	rim.omni_range = 5
	world.add_child(rim)
	_portrait_char = CharacterVisual.create("crawler")
	_portrait_char.rotation.y = 0.4
	world.add_child(_portrait_char)
	_portrait_char.play_state("idle", 0.0)


func _show_tab(i: int) -> void:
	_inv_page.visible = i == 0
	_skill_page.visible = i == 1
	if bestiary_page != null:
		bestiary_page.visible = i == 2
		if i == 2:
			bestiary_page.refresh()
	if i == 1:
		_refresh_skills()


## FB-014: fit the three columns into whatever width is available (small windows, Interface Scale up to 160%):
## when space is tight the 3D portrait steps aside and the columns use their compact minimums.
func _fit_layout() -> void:
	if root == null or _c1 == null:
		return
	var w := root.size.x if root.size.x > 1.0 else get_viewport().get_visible_rect().size.x
	var compact := w < 1150.0
	_portrait_box.visible = not compact
	_c1.custom_minimum_size.x = 170.0 if compact else 340.0
	_c3.custom_minimum_size.x = 290.0 if compact else 350.0
	_bag_scroll.custom_minimum_size.x = 2.0 * (SLOT_SIZE + 8.0) if compact else 3.0 * (SLOT_SIZE + 8.0)
	# Guarantee: if even the compact layout needs more room than there is, the whole menu scales down to fit
	var avail := Vector2(w, root.size.y if root.size.y > 1.0 else get_viewport().get_visible_rect().size.y)
	var need := _margin.get_combined_minimum_size()
	var k := minf(1.0, minf(avail.x / maxf(need.x, 1.0), avail.y / maxf(need.y, 1.0)))
	_margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_margin.position = Vector2.ZERO
	_margin.scale = Vector2(k, k)
	_margin.size = avail / k


func refresh() -> void:
	_fit_layout()
	if _player == null:
		return
	_gold_lbl.text = "%d" % _player.gold
	for k in _filter_btns.keys():
		(_filter_btns[k] as Button).button_pressed = k == _filter
	var prog := _player.progression
	var pts := (prog.attribute_points + prog.perk_points) if prog != null else 0
	_points_badge.text = ("%d point%s to spend" % [pts, "" if pts == 1 else "s"]) if pts > 0 else ""
	_refresh_equipment()
	_refresh_bag()
	_refresh_detail()
	_refresh_summary()
	if _skill_page.visible:
		_refresh_skills()


func _equip_slot_widget(slot: String, title: String, size: float = 64.0) -> Control:
	var item: Dictionary = _player.equipment.get(slot, {})
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	var w := UiTheme.item_slot(item, size)
	w.mouse_filter = Control.MOUSE_FILTER_STOP
	w.tooltip_text = ("%s\n%s" % [str(item.get("name", "")), ItemInfo.type_line(item)]) if not item.is_empty() else "%s — empty" % title
	w.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			var mb := ev as InputEventMouseButton
			if mb.double_click and not item.is_empty():
				_player.unequip_slot(slot)
				_selected_slot = ""
				refresh()
			elif mb.button_index == MOUSE_BUTTON_LEFT:
				_selected_slot = slot
				_selected_idx = -1
				_refresh_detail()
	)
	v.add_child(w)
	var l := UiTheme.label(title.to_upper(), 12, UiTheme.COL_FAINT, UiTheme.font_ui_bold(), HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(l)
	return v


func _refresh_equipment() -> void:
	for box in [_equip_left, _equip_right, _hands_row]:
		for c in box.get_children():
			c.queue_free()
	for pair in SLOT_LAYOUT:
		var slot: String = pair[0]
		var title: String = pair[1]
		if slot in ["head", "chest", "hands", "feet"]:
			_equip_left.add_child(_equip_slot_widget(slot, title))
		elif slot in ["amulet", "ring_1", "ring_2"]:
			_equip_right.add_child(_equip_slot_widget(slot, title))
		else:
			_hands_row.add_child(_equip_slot_widget(slot, title, 78))


func _visible_entries() -> Array:
	var entries: Array = []
	for i in range(_player.inventory.size()):
		var it: Dictionary = _player.inventory[i]
		if ItemInfo.matches_filter(it, _filter):
			entries.append([i, it])
	ItemInfo.sort_items(entries, _sort)
	return entries


func _refresh_bag() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var entries := _visible_entries()
	_count_lbl.text = "%d items" % _player.inventory.size()
	if entries.is_empty():
		_grid.add_child(UiTheme.body("Nothing here yet. Loot chests, urns and fallen foes.", 17, UiTheme.COL_MUTED, true))
		return
	for e in entries:
		var idx: int = e[0]
		var item: Dictionary = e[1]
		var badge := ""
		if str(item.get("category", "")) == "consumable":
			badge = "%d" % int(item.get("heal_health", item.get("heal_magicka", 0)))
		var w := UiTheme.item_slot(item, SLOT_SIZE, badge)
		w.mouse_filter = Control.MOUSE_FILTER_STOP
		w.tooltip_text = "%s\n%s  ·  %s" % [str(item.get("name", "")), UiTheme.rarity_name(str(item.get("rarity", "common"))), ItemInfo.type_line(item)]
		if idx == _selected_idx:
			w.modulate = Color(1.25, 1.18, 1.0)
		w.mouse_entered.connect(func() -> void:
			if _selected_idx < 0 and _selected_slot.is_empty():
				_show_detail_for(item)
		)
		w.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed:
				var mb := ev as InputEventMouseButton
				if mb.button_index == MOUSE_BUTTON_RIGHT:
					_equip(idx, CombatMath.other_hand(str(item.get("slot", "right_hand"))))
				elif mb.double_click:
					_equip(idx, "")
				elif mb.button_index == MOUSE_BUTTON_LEFT:
					_selected_idx = idx
					_selected_slot = ""
					_refresh_bag()
					_refresh_detail()
		)
		_grid.add_child(w)


func _equip(idx: int, hand: String) -> void:
	if idx < 0 or idx >= _player.inventory.size():
		return
	var item: Dictionary = _player.inventory[idx]
	if str(item.get("category", "")) == "consumable":
		_player.use_consumable(idx)
	else:
		if hand in ["left_hand", "right_hand"] and not CombatMath.is_one_handed(item):
			hand = ""
		_player.equip_from_inventory(idx, hand)
	_selected_idx = -1
	refresh()


func _show_detail_for(item: Dictionary) -> void:
	for c in _detail.get_children():
		c.queue_free()
	var slot := ItemInfo.slot_for(item)
	var compare: Dictionary = _player.equipment.get(slot, {}) if not slot.is_empty() else {}
	_detail.add_child(ItemInfo.build_card(item, compare))


func _refresh_detail() -> void:
	for c in _detail.get_children():
		c.queue_free()
	for c in _actions.get_children():
		c.queue_free()
	if not _selected_slot.is_empty():
		var it: Dictionary = _player.equipment.get(_selected_slot, {})
		_detail.add_child(ItemInfo.build_card(it))
		if not it.is_empty():
			var ub := UiTheme.button("Unequip", 0, 18)
			ub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ub.pressed.connect(func() -> void:
				_player.unequip_slot(_selected_slot)
				_selected_slot = ""
				refresh()
			)
			_actions.add_child(ub)
		return
	if _selected_idx < 0 or _selected_idx >= _player.inventory.size():
		_detail.add_child(ItemInfo.build_card({}))
		return
	var item: Dictionary = _player.inventory[_selected_idx]
	_show_detail_for(item)
	var cons := str(item.get("category", "")) == "consumable"
	var idx := _selected_idx
	if CombatMath.is_one_handed(item) and not cons:
		# D-046: one-handed blades, shields and spells go in either hand
		for pair in [["Right Hand", "right_hand"], ["Left Hand", "left_hand"]]:
			var hb := UiTheme.button(str(pair[0]), 0, 18)
			hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var hand: String = pair[1]
			hb.pressed.connect(func() -> void: _equip(idx, hand))
			_actions.add_child(hb)
	else:
		var b := UiTheme.button("Drink" if cons else "Equip", 0, 18)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void: _equip(idx, ""))
		_actions.add_child(b)


func _refresh_summary() -> void:
	for c in _summary.get_children():
		c.queue_free()
	var prog := _player.progression
	var lvl := prog.level if prog != null else 1
	var head := HBoxContainer.new()
	head.add_child(UiTheme.label("Level %d" % lvl, 24, UiTheme.COL_GOLD_BRIGHT, UiTheme.font_heading()))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	if prog != null:
		head.add_child(UiTheme.label("%d / %d XP" % [int(prog.xp), int(prog.xp_for_next_level())], 16, UiTheme.COL_MUTED, UiTheme.font_ui()))
	_summary.add_child(head)
	if prog != null:
		var xb := ProgressBar.new()
		xb.show_percentage = false
		xb.max_value = maxf(1.0, prog.xp_for_next_level())
		xb.value = prog.xp
		UiTheme.style_progress_bar(xb, UiTheme.COL_GOLD, 10)
		_summary.add_child(xb)
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 10)
	_summary.add_child(g)
	for spec in [["Health", "%d / %d" % [int(_player.health), int(_player.max_health)], UiTheme.COL_HEALTH],
			["Magicka", "%d / %d" % [int(_player.magicka), int(_player.max_magicka)], UiTheme.COL_MAGICKA],
			["Stamina", "%d / %d" % [int(_player.stamina), int(_player.max_stamina)], UiTheme.COL_STAMINA],
			["Armor", "%d" % int(_player.get_total_armor()), UiTheme.COL_GOLD]]:
		g.add_child(UiTheme.label(spec[0], 16, UiTheme.COL_MUTED, UiTheme.font_ui()))
		g.add_child(UiTheme.label(spec[1], 17, spec[2].lightened(0.2), UiTheme.font_ui_bold()))


func _refresh_skills() -> void:
	for c in _perks_box.get_children():
		c.queue_free()
	for c in _skills_box.get_children():
		c.queue_free()
	var prog := _player.progression
	if prog == null:
		return
	_perks_box.add_child(UiTheme.heading("Attributes", 22))
	var ah := UiTheme.label("%d attribute point%s available" % [prog.attribute_points, "" if prog.attribute_points == 1 else "s"], 17,
		UiTheme.COL_GOLD_BRIGHT if prog.attribute_points > 0 else UiTheme.COL_MUTED, UiTheme.font_ui_semibold())
	_perks_box.add_child(ah)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_perks_box.add_child(row)
	for spec in [["health", "Health", "+15 maximum health", UiTheme.COL_HEALTH, "icon_heart"], ["magicka", "Magicka", "+15 maximum magicka", UiTheme.COL_MAGICKA, "icon_bolt"],
			["stamina", "Stamina", "+15 maximum stamina", UiTheme.COL_STAMINA, "icon_flame"]]:
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", UiTheme.panel_style("card"))
		var cv := VBoxContainer.new()
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(cv)
		var ic := UiTheme.icon_rect(UiTheme.tex(spec[4]), 34, spec[3])
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cv.add_child(ic)
		cv.add_child(UiTheme.label(spec[1], 20, spec[3].lightened(0.25), UiTheme.font_heading(), HORIZONTAL_ALIGNMENT_CENTER))
		cv.add_child(UiTheme.label(spec[2], 15, UiTheme.COL_MUTED, UiTheme.font_ui(), HORIZONTAL_ALIGNMENT_CENTER))
		var b := UiTheme.button("Increase", 0, 17)
		b.disabled = prog.attribute_points <= 0
		var key: String = spec[0]
		b.pressed.connect(func() -> void:
			if prog.spend_attribute(key):
				_player.recalculate_vitals(false)
				refresh()
				_refresh_skills()
		)
		cv.add_child(b)
		row.add_child(card)
	_perks_box.add_child(UiTheme.divider())
	_perks_box.add_child(UiTheme.heading("Perks", 22))
	_perks_box.add_child(UiTheme.label("%d perk point%s available" % [prog.perk_points, "" if prog.perk_points == 1 else "s"], 17,
		UiTheme.COL_GOLD_BRIGHT if prog.perk_points > 0 else UiTheme.COL_MUTED, UiTheme.font_ui_semibold()))
	for p in DataLoader.get_progression_pack().get("perks", []):
		var pid := str(p["id"])
		var owned := prog.unlocked_perks.has(pid)
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UiTheme.panel_style("card"))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		card.add_child(h)
		h.add_child(UiTheme.icon_rect(UiTheme.tex("icon_diamond"), 26, UiTheme.COL_GOLD_BRIGHT if owned else UiTheme.COL_FAINT))
		var tv := VBoxContainer.new()
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(UiTheme.label(str(p["name"]), 20, UiTheme.COL_GOLD_BRIGHT if owned else UiTheme.COL_TEXT, UiTheme.font_heading()))
		tv.add_child(UiTheme.body(str(p["description"]), 17, UiTheme.COL_MUTED))
		h.add_child(tv)
		if owned:
			h.add_child(UiTheme.label("LEARNED", 15, UiTheme.COL_GOOD, UiTheme.font_ui_bold()))
		else:
			var ub := UiTheme.button("Learn", 120, 17)
			ub.disabled = prog.perk_points <= 0
			ub.pressed.connect(func() -> void:
				if prog.unlock_perk(pid):
					_player.recalculate_vitals(false)
					refresh()
					_refresh_skills()
			)
			h.add_child(ub)
		_perks_box.add_child(card)
	_skills_box.add_child(UiTheme.heading("Skills", 22))
	_skills_box.add_child(UiTheme.body("Skills improve as you use them — swing, block, cast and shoot.", 17, UiTheme.COL_MUTED, true))
	for s in prog.skill_levels.keys():
		var sname := str(s)
		var slvl := int(prog.skill_levels[s])
		var sxp := float(prog.skill_xp.get(s, 0.0))
		var top := HBoxContainer.new()
		top.add_child(UiTheme.label(sname.replace("_", " ").capitalize(), 19, UiTheme.COL_TEXT, UiTheme.font_ui_semibold()))
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(sp)
		top.add_child(UiTheme.label("Lv %d  ·  +%d%% damage" % [slvl, int(round((prog.get_proficiency_damage_multiplier(sname) - 1.0) * 100.0))], 16, UiTheme.COL_GOLD, UiTheme.font_ui()))
		_skills_box.add_child(top)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.max_value = 100.0
		bar.value = fmod(sxp, 100.0)
		UiTheme.style_progress_bar(bar, UiTheme.COL_CYAN.darkened(0.2), 8)
		_skills_box.add_child(bar)
