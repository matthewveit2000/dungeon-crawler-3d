class_name InventoryStacks
extends RefCounted
## Tier 2 Pure System — stacking bag entries (FB-022).
## Consumables and ingredients stack: one bag entry per kind (same item id and rarity) carrying a "count".
## Gear never stacks (every weapon/armor piece has its own mastery, so each one is unique).

const STACK_CATEGORIES := ["consumable", "ingredient"]


static func is_stackable(item: Dictionary) -> bool:
	return str(item.get("category", "")) in STACK_CATEGORIES


## How many the entry holds (1 for gear).
static func count(item: Dictionary) -> int:
	return maxi(1, int(item.get("count", 1))) if is_stackable(item) else 1


static func _key(item: Dictionary) -> String:
	return "%s|%s" % [str(item.get("id", "")), str(item.get("rarity", "common"))]


## Puts `n` of `item` in the bag (n <= 0: the item's own count). Stackables join an existing stack.
## Returns the bag entry that now holds them.
static func add(inv: Array, item: Dictionary, n: int = 0) -> Dictionary:
	if item.is_empty():
		return {}
	if not is_stackable(item):
		inv.append(item)
		return item
	var amount := n if n > 0 else count(item)
	var key := _key(item)
	for e in inv:
		if is_stackable(e) and _key(e) == key:
			e["count"] = count(e) + amount
			return e
	var c := item.duplicate(true)
	c["count"] = amount
	inv.append(c)
	return c


## Removes `n` from the entry at `idx` (the whole entry for gear). Returns what was taken (with its count),
## or {} if the index is invalid.
static func take(inv: Array, idx: int, n: int = 1) -> Dictionary:
	if idx < 0 or idx >= inv.size():
		return {}
	var e: Dictionary = inv[idx]
	if not is_stackable(e):
		inv.remove_at(idx)
		return e
	var have := count(e)
	var amount := clampi(n, 1, have)
	var out := e.duplicate(true)
	out["count"] = amount
	if amount >= have:
		inv.remove_at(idx)
	else:
		e["count"] = have - amount
	return out


## Index of the first bag entry with this item id (-1 if none).
static func find(inv: Array, item_id: String) -> int:
	for i in range(inv.size()):
		if str(inv[i].get("id", "")) == item_id:
			return i
	return -1


## Total number of this item id in the bag (all stacks and rarities).
static func total(inv: Array, item_id: String) -> int:
	var n := 0
	for e in inv:
		if str(e.get("id", "")) == item_id:
			n += count(e)
	return n


## Merges loose duplicates into stacks (older saves stored one entry per potion). Order of first appearance kept.
static func normalize(inv: Array) -> void:
	var merged: Array = []
	for e in inv:
		add(merged, e, count(e))
	inv.clear()
	for e in merged:
		inv.append(e)
