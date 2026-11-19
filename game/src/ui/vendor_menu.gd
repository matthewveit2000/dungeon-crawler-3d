class_name VendorMenu
extends CanvasLayer
## Styled Safe Room Merchant Trading Menu (pauses 5-day floor timer while open — D-016).

var _gold_lbl: Label = null
var _stock_box: VBoxContainer = null
var _bag_box: VBoxContainer = null
var _status_lbl: Label = null
var _player: PlayerController = null
var _vendor: VendorSystem = null
var _close_cb: Callable = Callable()


func _ready() -> void:
	layer = 22
	visible = false
	_build_ui()


func setup(p_player: PlayerController, p_vendor: VendorSystem, close_cb: Callable) -> void:
	_player = p_player
	_vendor = p_vendor
	_close_cb = close_cb


func open_menu() -> void:
	refresh()
	visible = true


func close_menu() -> void:
	visible = false


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.015, 0.02, 0.035, 0.74)
	root.add_child(dim)

	var frame := PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.offset_left = -520
	frame.offset_right = 520
	frame.offset_top = -300
	frame.offset_bottom = 300
	frame.add_theme_stylebox_override("panel", UiTheme.make_panel_style(UiTheme.COL_BG_DEEP, UiTheme.COL_GOLD, 2, 8, 22, 18))
	root.add_child(frame)

	var main_v := VBoxContainer.new()
	main_v.add_theme_constant_override("separation", 12)
	frame.add_child(main_v)

	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 12)
	main_v.add_child(hdr)

	var title := Label.new()
	title.text = "SAFE ROOM MERCHANT  •  SYNDICATE EXCHANGE"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", UiTheme.COL_GOLD_BRIGHT)
	hdr.add_child(title)

	var gold_pill := PanelContainer.new()
	gold_pill.add_theme_stylebox_override("panel", UiTheme.make_panel_style(Color(0.16, 0.13, 0.06, 0.94), UiTheme.COL_GOLD_BRIGHT, 1, 10, 14, 4))
	_gold_lbl = Label.new()
	_gold_lbl.add_theme_font_size_override("font_size", 13)
	_gold_lbl.add_theme_color_override("font_color", UiTheme.COL_GOLD_BRIGHT)
	gold_pill.add_child(_gold_lbl)
	hdr.add_child(gold_pill)

	var close_btn := Button.new()
	close_btn.text = "Leave Stall [Esc]"
	UiTheme.style_button(close_btn, UiTheme.COL_GOLD, 13)
	close_btn.pressed.connect(func() -> void:
		if _close_cb.is_valid():
			_close_cb.call()
	)
	hdr.add_child(close_btn)

	_status_lbl = Label.new()
	_status_lbl.text = "\"Browse all you like, crawler — monsters can't touch you in here, and the clock is paused.\""
	_status_lbl.add_theme_font_size_override("font_size", 12)
	_status_lbl.add_theme_color_override("font_color", Color(0.54, 0.92, 0.78))
	main_v.add_child(_status_lbl)

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 16)
	main_v.add_child(cols)

	_stock_box = _make_col(cols, "Merchant Wares (Buy)")
	_bag_box = _make_col(cols, "Your Backpack (Sell)")


func _make_col(parent: Control, heading: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UiTheme.make_panel_style(UiTheme.COL_BG_PANEL, UiTheme.COL_GOLD_DIM, 1, 6, 12, 10))
	parent.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	v.add_child(UiTheme.make_section_header(heading, 14))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	sc.add_child(content)
	return content


func refresh() -> void:
	if _player == null or _vendor == null:
		return
	_gold_lbl.text = "✦ %d Gold" % _player.gold
	for box in [_stock_box, _bag_box]:
		for c in box.get_children():
			c.queue_free()

	for i in range(_vendor.stock.size()):
		var item: Dictionary = _vendor.stock[i]
		var price := _vendor.get_buy_price(item)
		var rarity := str(item.get("rarity", "common"))
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UiTheme.make_panel_style(UiTheme.COL_BG_CARD, UiTheme.rarity_color(rarity), 1, 5, 10, 7))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		card.add_child(row)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nm := Label.new()
		nm.text = str(item.get("name", "Item"))
		nm.add_theme_font_size_override("font_size", 13)
		nm.add_theme_color_override("font_color", UiTheme.rarity_color(rarity))
		info.add_child(nm)
		var sub := Label.new()
		sub.text = "[%s]  %s" % [rarity.to_upper(), str(item.get("slot", "")).replace("_", " ").capitalize()]
		sub.add_theme_font_size_override("font_size", 11)
		sub.add_theme_color_override("font_color", UiTheme.COL_MUTED)
		info.add_child(sub)
		row.add_child(info)

		var btn := Button.new()
		btn.text = "Buy • %dg" % price
		btn.disabled = _player.gold < price
		UiTheme.style_button(btn, UiTheme.COL_GOLD if _player.gold >= price else UiTheme.COL_MUTED, 12)
		var idx_cap: int = i
		btn.pressed.connect(func() -> void:
			var res := _vendor.buy_item(idx_cap, _player.gold, _player.inventory)
			if bool(res["ok"]):
				_player.gold = int(res["gold"])
				_player.emit_stats()
				_status_lbl.text = "Purchased %s!" % str(res["item"]["name"])
			else:
				_status_lbl.text = str(res["reason"])
			refresh()
		)
		row.add_child(btn)
		_stock_box.add_child(card)

	for i in range(_player.inventory.size()):
		var item: Dictionary = _player.inventory[i]
		var price := _vendor.get_sell_price(item)
		var rarity := str(item.get("rarity", "common"))
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UiTheme.make_panel_style(UiTheme.COL_BG_CARD, UiTheme.rarity_color(rarity), 1, 5, 10, 7))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		card.add_child(row)

		var nm := Label.new()
		nm.text = str(item.get("name", "Item"))
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.add_theme_font_size_override("font_size", 13)
		nm.add_theme_color_override("font_color", UiTheme.rarity_color(rarity))
		row.add_child(nm)

		var btn := Button.new()
		btn.text = "Sell • +%dg" % price
		UiTheme.style_button(btn, UiTheme.COL_EMERALD, 12)
		var idx_cap: int = i
		btn.pressed.connect(func() -> void:
			var res := _vendor.sell_item(idx_cap, _player.gold, _player.inventory)
			if bool(res["ok"]):
				_player.gold = int(res["gold"])
				_player.emit_stats()
				_status_lbl.text = "Sold item for +%dg!" % int(res["gained"])
			refresh()
		)
		row.add_child(btn)
		_bag_box.add_child(card)
