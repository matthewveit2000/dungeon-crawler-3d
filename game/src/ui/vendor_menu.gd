class_name VendorMenu
extends CanvasLayer
## Safe Room Merchant Buy/Sell Menu (pauses simulation while open).

var _player: PlayerController = null
var _vendor: VendorSystem = null
var _on_close_cb: Callable = Callable()
var _gold_lbl: Label = null
var _buy_box: VBoxContainer = null
var _sell_box: VBoxContainer = null


func setup(player: PlayerController, vendor: VendorSystem, on_close: Callable) -> void:
	_player = player
	_vendor = vendor
	_on_close_cb = on_close
	layer = 13
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
	if _player == null or _vendor == null or _buy_box == null:
		return
	_gold_lbl.text = "Your Syndicate Gold: %d" % _player.gold
	for c in _buy_box.get_children():
		c.queue_free()
	for c in _sell_box.get_children():
		c.queue_free()

	for i in range(_vendor.stock.size()):
		var item: Dictionary = _vendor.stock[i]
		var price := _vendor.get_buy_price(item)
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = "%s (%dg)" % [str(item.get("name", "Item")), price]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var btn := Button.new()
		btn.text = "Buy"
		btn.disabled = _player.gold < price
		var idx := i
		btn.pressed.connect(func() -> void:
			var res := _vendor.buy_item(idx, _player.gold, _player.inventory)
			if bool(res["ok"]):
				_player.gold = int(res["gold"])
				_player.emit_stats()
				refresh()
		)
		row.add_child(lbl)
		row.add_child(btn)
		_buy_box.add_child(row)

	for i in range(_player.inventory.size()):
		var item: Dictionary = _player.inventory[i]
		var payout := _vendor.get_sell_price(item)
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = "%s (+%dg)" % [str(item.get("name", "Item")), payout]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var btn := Button.new()
		btn.text = "Sell"
		var idx := i
		btn.pressed.connect(func() -> void:
			var res := _vendor.sell_item(idx, _player.gold, _player.inventory)
			if bool(res["ok"]):
				_player.gold = int(res["gold"])
				_player.emit_stats()
				refresh()
		)
		row.add_child(lbl)
		row.add_child(btn)
		_sell_box.add_child(row)


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.12
	panel.anchor_right = 0.88
	panel.anchor_top = 0.10
	panel.anchor_bottom = 0.88
	add_child(panel)

	var outer := VBoxContainer.new()
	panel.add_child(outer)

	var top := HBoxContainer.new()
	var title := Label.new()
	title.text = "SAFE ROOM MERCHANT (GAME PAUSED)"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gold_lbl = Label.new()
	var close_btn := Button.new()
	close_btn.text = "Leave [Esc]"
	close_btn.pressed.connect(close_menu)
	top.add_child(title)
	top.add_child(_gold_lbl)
	top.add_child(close_btn)
	outer.add_child(top)

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 18)
	outer.add_child(cols)

	var b_col := VBoxContainer.new()
	b_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bh := Label.new()
	bh.text = "MERCHANT STOCK"
	b_col.add_child(bh)
	_buy_box = VBoxContainer.new()
	b_col.add_child(_buy_box)
	cols.add_child(b_col)

	var s_col := VBoxContainer.new()
	s_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sh := Label.new()
	sh.text = "SELL FROM BACKPACK"
	s_col.add_child(sh)
	_sell_box = VBoxContainer.new()
	s_col.add_child(_sell_box)
	cols.add_child(s_col)
