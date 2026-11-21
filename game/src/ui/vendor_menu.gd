class_name VendorMenu
extends MenuScreen
## Safe Room merchant trading screen: merchant stock and your pack as icon grids, detail card with
## price and comparison vs. equipped gear, Buy / Sell actions, and a one-click "Sell all Common" QoL.

var _player: PlayerController = null
var _vendor: VendorSystem = null
var _close_cb: Callable = Callable()
var _gold_lbl: Label = null
var _stock_grid: GridContainer = null
var _bag_grid: GridContainer = null
var _detail: VBoxContainer = null
var _action_row: HBoxContainer = null
var _status_lbl: Label = null
var _sel_side: String = ""
var _sel_idx: int = -1
var _qty: int = 1  ## FB-022: how many of a stack to buy / sell
var _qty_spin: SpinBox = null

const GREETINGS := [
	"\"Coin first, questions never. The dark takes its cut either way.\"",
	"\"Everything here is guaranteed authentic, wanderer. Mostly.\"",
	"\"Sanctuary rates apply. Monsters pay double.\"",
]


func _ready() -> void:
	build_base(20, true)
	_build_ui()


func setup(p_player: PlayerController, p_vendor: VendorSystem, close_cb: Callable) -> void:
	_player = p_player
	_vendor = p_vendor
	_close_cb = close_cb


func open_menu() -> void:
	_sel_side = ""
	_sel_idx = -1
	_status_lbl.text = GREETINGS[Time.get_ticks_msec() % GREETINGS.size()] if is_inside_tree() else GREETINGS[0]
	refresh()
	show_animated()


func close_menu() -> void:
	hide_now()


func _grid_panel(parent: Control, title: String, subtitle: String) -> GridContainer:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_theme_stylebox_override("panel", UiTheme.panel_style("frame"))
	parent.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pc.add_child(v)
	v.add_child(UiTheme.heading(title, 22))
	v.add_child(UiTheme.label(subtitle, 15, UiTheme.COL_MUTED, UiTheme.font_ui()))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	sc.add_child(g)
	return g


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	root.add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	margin.add_child(outer)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	outer.add_child(header)
	header.add_child(UiTheme.label("SANCTUARY MERCHANT", 32, UiTheme.COL_GOLD_BRIGHT, UiTheme.font_title()))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(sp)
	header.add_child(UiTheme.icon_rect(UiTheme.tex("icon_coin"), 24, UiTheme.COL_GOLD))
	_gold_lbl = UiTheme.label("", 24, UiTheme.COL_GOLD, UiTheme.font_ui_bold())
	header.add_child(_gold_lbl)
	var close := UiTheme.button("Leave  [Esc]", 150, 17)
	close.pressed.connect(func() -> void:
		if _close_cb.is_valid():
			_close_cb.call()
	)
	header.add_child(close)
	_status_lbl = UiTheme.body("", 19, UiTheme.COL_MUTED, true)
	outer.add_child(_status_lbl)
	outer.add_child(UiTheme.divider())
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 14)
	outer.add_child(row)
	_stock_grid = _grid_panel(row, "For Sale", "Click an item to inspect  ·  Double-click to buy")
	var mid := PanelContainer.new()
	mid.custom_minimum_size.x = 400
	mid.add_theme_stylebox_override("panel", UiTheme.panel_style("frame"))
	row.add_child(mid)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 10)
	mid.add_child(mv)
	var ds := ScrollContainer.new()
	ds.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ds.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mv.add_child(ds)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ds.add_child(_detail)
	_action_row = HBoxContainer.new()
	_action_row.add_theme_constant_override("separation", 8)
	mv.add_child(_action_row)
	_bag_grid = _grid_panel(row, "Your Pack", "Click an item to inspect  ·  Double-click to sell")
	var foot := HBoxContainer.new()
	outer.add_child(foot)
	var junk := UiTheme.button("Sell All Common Items", 280, 17)
	junk.tooltip_text = "Sells every unequipped Common-rarity weapon and armor piece (never consumables)."
	junk.pressed.connect(_sell_commons)
	foot.add_child(junk)


func refresh() -> void:
	if _player == null or _vendor == null:
		return
	_gold_lbl.text = "%d" % _player.gold
	for g in [_stock_grid, _bag_grid]:
		for c in g.get_children():
			c.queue_free()
	for i in range(_vendor.stock.size()):
		_stock_grid.add_child(_slot("stock", i, _vendor.stock[i], _vendor.get_buy_price(_vendor.stock[i])))
	for i in range(_player.inventory.size()):
		_bag_grid.add_child(_slot("bag", i, _player.inventory[i], _vendor.get_sell_price(_player.inventory[i])))
	if _vendor.stock.is_empty():
		_stock_grid.add_child(UiTheme.body("Sold out.", 17, UiTheme.COL_MUTED, true))
	if _player.inventory.is_empty():
		_bag_grid.add_child(UiTheme.body("Your pack is empty.", 17, UiTheme.COL_MUTED, true))
	_refresh_detail()


func _slot(side: String, idx: int, item: Dictionary, price: int) -> Control:
	var badge := "%dg" % price
	if side == "bag" and InventoryStacks.is_stackable(item):
		badge = "×%d  %dg" % [InventoryStacks.count(item), price]
	var w := UiTheme.item_slot(item, 76, badge)
	w.mouse_filter = Control.MOUSE_FILTER_STOP
	w.tooltip_text = "%s\n%s gold" % [str(item.get("name", "")), price]
	if side == "stock" and price > _player.gold:
		w.modulate = Color(0.6, 0.55, 0.5)
	if side == _sel_side and idx == _sel_idx:
		w.modulate = Color(1.25, 1.18, 1.0)
	w.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			var mb := ev as InputEventMouseButton
			if mb.double_click:
				_transact(side, idx)
			elif mb.button_index == MOUSE_BUTTON_LEFT:
				if side != _sel_side or idx != _sel_idx:
					_qty = 1
				_sel_side = side
				_sel_idx = idx
				refresh()
	)
	return w


func _refresh_detail() -> void:
	for c in _detail.get_children():
		c.queue_free()
	for c in _action_row.get_children():
		_action_row.remove_child(c)
		c.queue_free()
	var item: Dictionary = {}
	var price := 0
	if _sel_side == "stock" and _sel_idx >= 0 and _sel_idx < _vendor.stock.size():
		item = _vendor.stock[_sel_idx]
		price = _vendor.get_buy_price(item)
	elif _sel_side == "bag" and _sel_idx >= 0 and _sel_idx < _player.inventory.size():
		item = _player.inventory[_sel_idx]
		price = _vendor.get_sell_price(item)
	var slot := ItemInfo.slot_for(item) if not item.is_empty() else ""
	var compare: Dictionary = _player.equipment.get(slot, {}) if not slot.is_empty() else {}
	var price_txt := ""
	if not item.is_empty():
		price_txt = ("Price %d gold" % price) if _sel_side == "stock" else ("Sells for %d gold" % price)
	_detail.add_child(ItemInfo.build_card(item, compare, price_txt))
	if item.is_empty():
		return
	# FB-022: stacks are bought / sold in any amount
	var max_q := _max_qty(item)
	_qty = clampi(_qty, 1, maxi(1, max_q))
	var b := UiTheme.button("", 0, 18)
	b.name = "TradeButton"
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var upd := func() -> void:
		var total := price * _qty
		var verb := "Buy" if _sel_side == "stock" else "Sell"
		b.text = ("%s %d for %d" % [verb, _qty, total]) if InventoryStacks.is_stackable(item) else ("%s for %d" % [verb, total])
		b.disabled = (_sel_side == "stock" and total > _player.gold) or max_q <= 0
	if InventoryStacks.is_stackable(item) and max_q > 1:
		var minus := UiTheme.button("−", 0, 18)
		minus.custom_minimum_size = Vector2(36, 0)
		_action_row.add_child(minus)
		_qty_spin = SpinBox.new()
		_qty_spin.name = "Quantity"
		_qty_spin.min_value = 1
		_qty_spin.max_value = max_q
		_qty_spin.value = _qty
		_qty_spin.custom_minimum_size = Vector2(84, 0)
		_qty_spin.tooltip_text = "How many to %s (max %d)" % ["buy" if _sel_side == "stock" else "sell", max_q]
		_action_row.add_child(_qty_spin)
		var plus := UiTheme.button("+", 0, 18)
		plus.custom_minimum_size = Vector2(36, 0)
		_action_row.add_child(plus)
		var all := UiTheme.button("Max", 0, 16)
		_action_row.add_child(all)
		_qty_spin.value_changed.connect(func(v: float) -> void:
			_qty = int(v)
			upd.call())
		minus.pressed.connect(func() -> void: _qty_spin.value = maxf(1.0, _qty_spin.value - 1.0))
		plus.pressed.connect(func() -> void: _qty_spin.value = minf(float(max_q), _qty_spin.value + 1.0))
		all.pressed.connect(func() -> void: _qty_spin.value = float(max_q))
	upd.call()
	b.pressed.connect(func() -> void: _transact(_sel_side, _sel_idx, _qty))
	_action_row.add_child(b)


## Most of the selected entry that can be traded right now (gold for buying, stack size for selling).
func _max_qty(item: Dictionary) -> int:
	if _sel_side == "stock":
		return _vendor.max_affordable(_sel_idx, _player.gold)
	return InventoryStacks.count(item)


## Sets how many to trade (also used by tests / Test Mode).
func set_quantity(q: int) -> void:
	_qty = maxi(1, q)
	_refresh_detail()


func _transact(side: String, idx: int, qty: int = 1) -> void:
	if side == "stock":
		var res := _vendor.buy_item(idx, _player.gold, _player.inventory, qty)
		if bool(res["ok"]):
			_player.gold = int(res["gold"])
			_status_lbl.text = ("Purchased %d × %s." % [int(res["qty"]), str(res["item"]["name"])]) if int(res["qty"]) > 1 else "Purchased %s." % str(res["item"]["name"])
			if EventBus != null:
				EventBus.sfx_requested.emit("chest_open")
		else:
			_status_lbl.text = str(res.get("reason", "You can't afford that."))
	else:
		var res2 := _vendor.sell_item(idx, _player.gold, _player.inventory, qty)
		if bool(res2["ok"]):
			_player.gold = int(res2["gold"])
			_status_lbl.text = "Sold %d for %d gold." % [int(res2.get("qty", 1)), int(res2.get("payout", 0))]
	_player.emit_stats()
	# keep a stack selected after a partial sale so the next sale is one click away
	if not (side == "bag" and idx < _player.inventory.size() and InventoryStacks.is_stackable(_player.inventory[idx])) and side != "stock":
		_sel_side = ""
		_sel_idx = -1
	elif side == "stock" and (idx >= _vendor.stock.size() or not InventoryStacks.is_stackable(_vendor.stock[idx])):
		_sel_side = ""
		_sel_idx = -1
	_qty = 1
	refresh()


func _sell_commons() -> void:
	var total := 0
	var i := _player.inventory.size() - 1
	while i >= 0:
		var it: Dictionary = _player.inventory[i]
		var cat := str(it.get("category", ""))
		if str(it.get("rarity", "common")) == "common" and cat in ["weapon", "armor", "shield", "accessory"]:
			var res := _vendor.sell_item(i, _player.gold, _player.inventory)
			if bool(res["ok"]):
				_player.gold = int(res["gold"])
				total += int(res.get("payout", 0))
		i -= 1
	_status_lbl.text = ("Sold common gear for %d gold." % total) if total > 0 else "No common gear to sell."
	_player.emit_stats()
	refresh()
