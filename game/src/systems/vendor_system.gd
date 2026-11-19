class_name VendorSystem
extends RefCounted
## Tier 2 Pure System: Safe Room Underground Vendor economy (D-021).

var stock: Array[Dictionary] = []
var _sell_ratio: float = 0.4


func _init(affixes_pack: Dictionary) -> void:
	var v_cfg: Dictionary = affixes_pack.get("vendor", {})
	_sell_ratio = float(v_cfg.get("sell_price_ratio", 0.4))


func refresh_stock(items_pack: Dictionary, affixes_pack: Dictionary, floor_number: int, rng: SeededRng) -> void:
	stock.clear()
	var v_cfg: Dictionary = affixes_pack.get("vendor", {})
	var count := int(v_cfg.get("stock_count", 7))

	# Always stock 2 potions + rolled gear
	for potion_id in ["health_potion", "magicka_potion"]:
		for item in items_pack.get("items", []):
			if str(item["id"]) == potion_id:
				var inst := LootGenerator.make_base_item_instance(item, "%s_v_%d" % [potion_id, stock.size()])
				stock.append(inst)
				break

	while stock.size() < count:
		var rolled := LootGenerator.roll_loot(items_pack, affixes_pack, floor_number, rng, "", true)
		if not rolled.is_empty():
			stock.append(rolled)


func get_buy_price(item: Dictionary) -> int:
	return maxi(5, int(item.get("value", item.get("base_value", 25))))


func get_sell_price(item: Dictionary) -> int:
	return maxi(2, int(round(float(get_buy_price(item)) * _sell_ratio)))


func buy_item(stock_index: int, player_gold: int, player_inventory: Array) -> Dictionary:
	if stock_index < 0 or stock_index >= stock.size():
		return {"ok": false, "gold": player_gold, "reason": "invalid_index"}
	var item: Dictionary = stock[stock_index]
	var price := get_buy_price(item)
	if player_gold < price:
		return {"ok": false, "gold": player_gold, "reason": "insufficient_gold"}
	var bought := item.duplicate(true)
	if str(item.get("category", "")) != "consumable":
		stock.remove_at(stock_index)
	player_inventory.append(bought)
	return {"ok": true, "gold": player_gold - price, "item": bought}


func sell_item(inv_index: int, player_gold: int, player_inventory: Array) -> Dictionary:
	if inv_index < 0 or inv_index >= player_inventory.size():
		return {"ok": false, "gold": player_gold, "reason": "invalid_index"}
	var item: Dictionary = player_inventory[inv_index]
	var payout := get_sell_price(item)
	player_inventory.remove_at(inv_index)
	return {"ok": true, "gold": player_gold + payout, "item": item, "payout": payout}
