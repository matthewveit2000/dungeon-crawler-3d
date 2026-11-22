class_name VendorSystem
extends RefCounted
## Tier 2 Pure System: Safe Room Underground Vendor economy (D-021, D-060).

var stock: Array[Dictionary] = []
var _sell_ratio: float = 0.4
var _vendor_cfg: Dictionary = {}


func _init(balance_or_cfg: Dictionary = {}) -> void:
	_vendor_cfg = balance_or_cfg.get("vendor", balance_or_cfg)
	_sell_ratio = float(_vendor_cfg.get("sell_price_ratio", 0.4))


func refresh_stock(
	items_pack: Dictionary,
	rarities_pack: Dictionary,
	floor_number: int,
	rng: SeededRng,
	excluded_ids: Dictionary = {}
) -> void:
	stock.clear()
	var v_cfg: Dictionary = _vendor_cfg
	if v_cfg.is_empty() and DataLoader != null:
		v_cfg = DataLoader.get_balance_pack().get("vendor", {})
	var count := int(v_cfg.get("stock_count", 11))

	# Always stock the staple consumables/ingredients (unlimited, bought by the stack)
	for potion_id in v_cfg.get("staples", ["health_potion", "magicka_potion"]):
		for item in items_pack.get("items", []):
			if str(item["id"]) == potion_id:
				var inst := LootGenerator.make_base_item_instance(item, "%s_v_%d" % [potion_id, stock.size()])
				stock.append(inst)
				break

	# D-060: Exclude already-owned gear and avoid stocking duplicate gear in the shop
	var local_excluded := excluded_ids.duplicate()
	var safety := 0
	while stock.size() < count and safety < count * 3:
		safety += 1
		var rolled := LootGenerator.roll_loot(items_pack, rarities_pack, floor_number, rng, "", true, "", "vendor", local_excluded)
		if rolled.is_empty() or InventoryStacks.is_stackable(rolled):
			break
		local_excluded[str(rolled["id"])] = true
		stock.append(rolled)


## Price of ONE (a stack is priced per item). FB-022: balance.json "vendor_prices" knob.
func get_buy_price(item: Dictionary) -> int:
	return maxi(2, int(round(float(item.get("value", item.get("base_value", 25))) * PowerScale.knob("vendor_prices"))))


func get_sell_price(item: Dictionary) -> int:
	return maxi(2, int(round(float(get_buy_price(item)) * _sell_ratio)))


## Most of this stock entry the player can buy with `player_gold` (stacks; 1 for gear).
func max_affordable(stock_index: int, player_gold: int) -> int:
	if stock_index < 0 or stock_index >= stock.size():
		return 0
	var item: Dictionary = stock[stock_index]
	var n := player_gold / maxi(1, get_buy_price(item))
	return mini(n, 99) if InventoryStacks.is_stackable(item) else mini(n, 1)


## Buys `qty` (stackables come by the stack; gear is always 1). Returns {"ok", "gold", "item", "qty"}.
func buy_item(stock_index: int, player_gold: int, player_inventory: Array, qty: int = 1) -> Dictionary:
	if stock_index < 0 or stock_index >= stock.size():
		return {"ok": false, "gold": player_gold, "reason": "invalid_index"}
	var item: Dictionary = stock[stock_index]
	var stackable := InventoryStacks.is_stackable(item)
	var n := clampi(qty, 1, 99) if stackable else 1
	var price := get_buy_price(item) * n
	if player_gold < price:
		return {"ok": false, "gold": player_gold, "reason": "You can't afford that."}
	var bought := item.duplicate(true)
	if not stackable:
		stock.remove_at(stock_index)
	var entry := InventoryStacks.add(player_inventory, bought, n)
	return {"ok": true, "gold": player_gold - price, "item": entry, "qty": n}


## Sells `qty` from the bag entry (a stack, or the single gear piece). Returns {"ok", "gold", "item", "payout", "qty"}.
## Selling a non-stackable item removes it from player_inventory, immediately returning it to the loot pool (D-060).
func sell_item(inv_index: int, player_gold: int, player_inventory: Array, qty: int = 1) -> Dictionary:
	if inv_index < 0 or inv_index >= player_inventory.size():
		return {"ok": false, "gold": player_gold, "reason": "invalid_index"}
	var item: Dictionary = player_inventory[inv_index]
	var n := clampi(qty, 1, InventoryStacks.count(item))
	var payout := get_sell_price(item) * n
	var taken := InventoryStacks.take(player_inventory, inv_index, n)
	return {"ok": true, "gold": player_gold + payout, "item": taken, "payout": payout, "qty": n}
