class_name PowerScale
extends RefCounted
## Tier 2 Pure System — power-scale knobs (FB-022).
## One easy place to make the game harder or easier. Every number is a multiplier (1.0 = the tuned default) and
## three layers multiply together:
##   1. global knobs in data/balance.json ("enemy_health", "item_power", ...)
##   2. a floor's own "power_scale" in data/world.json (enemies on that floor)
##   3. every enemy and item's own "power_scale" in data/enemies.json / data/items.json
## Item multipliers are read from the item *definition*, so turning a knob also rescales gear already in the bag.


static func cfg() -> Dictionary:
	return DataLoader.get_pack("balance")


## A global knob from balance.json (1.0 when missing).
static func knob(knob_name: String) -> float:
	return float(cfg().get("global", {}).get(knob_name, 1.0))


## An entity's own power_scale (enemy def, item def or instance).
static func own(def: Dictionary) -> float:
	return float(def.get("power_scale", 1.0))


static func floor_scale(floor_number: int) -> float:
	return float(DataLoader.get_floor_config(floor_number).get("power_scale", 1.0))


## Enemy multiplier for "health", "damage", "xp" or "gold". Bosses and champions use their own health/damage knobs.
static func enemy(edef: Dictionary, stat: String, floor_number: int, rank: String = "") -> float:
	var r := rank if not rank.is_empty() else ("boss" if bool(edef.get("is_boss", false)) else "enemy")
	var k := knob("enemy_" + stat)
	if stat in ["health", "damage"] and r != "enemy":
		k = knob("%s_%s" % [r, stat])
	var m := k
	if stat in ["health", "damage"]:
		m *= own(edef) * floor_scale(floor_number)
	return m


## Multiplier on an item's core stats (damage, armor, healing, bonuses).
static func item(it: Dictionary) -> float:
	var def := DataLoader.get_item_def(str(it.get("id", "")))
	var k := knob("consumable_power") if str(it.get("category", "")) in ["consumable", "ingredient"] else knob("item_power")
	return k * own(def if not def.is_empty() else it)


## A consumable's effect value (e.g. "heal_health") with its power scale applied.
static func consumable_value(it: Dictionary, key: String) -> float:
	return float(it.get(key, 0.0)) * item(it)
