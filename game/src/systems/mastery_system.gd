class_name MasterySystem
extends RefCounted
## Tier 2 Pure System — Item Mastery (D-049).
## Every weapon, spell, shield, armor piece and accessory carries its own mastery level and XP on the item
## instance ("mastery_level", "mastery_xp"). Using the item earns XP; each level makes its core stats stronger
## (stat_growth_per_level) and the levels named in the item's own "mastery" track unlock new abilities, so two
## items of the same kind grow in completely different directions. Abilities are generic mechanics from the
## ability library in mastery.json; a later entry for the same ability on the same item upgrades it.

const STAT_KEYS := ["damage", "armor", "heal_amount", "bonus_damage", "bonus_health", "bonus_magicka", "bonus_stamina"]


static func pack() -> Dictionary:
	return DataLoader.get_mastery_pack()


static func max_level(cfg: Dictionary = {}) -> int:
	if cfg.is_empty():
		cfg = pack()
	return int(cfg.get("max_level", 10))


## True for items that can be mastered (gear, not potions).
static func is_masterable(item: Dictionary) -> bool:
	return str(item.get("category", "")) in ["weapon", "spell", "shield", "armor", "accessory"]


static func level_of(item: Dictionary) -> int:
	return maxi(1, int(item.get("mastery_level", 1)))


## XP needed to go from `level` to `level + 1`.
static func xp_to_next(level: int, cfg: Dictionary = {}) -> int:
	if cfg.is_empty():
		cfg = pack()
	return int(round(float(cfg.get("xp_base", 18.0)) * pow(float(level), float(cfg.get("xp_growth", 1.45)))))


## Multiplier applied to the item's core stats at its current mastery level.
static func stat_multiplier(item: Dictionary, cfg: Dictionary = {}) -> float:
	if cfg.is_empty():
		cfg = pack()
	return 1.0 + float(cfg.get("stat_growth_per_level", 0.07)) * float(level_of(item) - 1)


## A core stat of the item including its mastery growth (e.g. "damage", "armor").
static func stat(item: Dictionary, key: String, default_value: float = 0.0) -> float:
	var base := float(item.get(key, default_value))
	if key in STAT_KEYS:
		return base * stat_multiplier(item)
	return base


## The item's mastery track (falls back to the item definition, so old saves pick up track changes).
static func track(item: Dictionary) -> Array:
	var def := DataLoader.get_item_def(str(item.get("id", "")))
	var t: Array = def.get("mastery", item.get("mastery", []))
	return t


## Unlocked abilities: id -> params (the highest unlocked entry of each ability wins, so later levels upgrade it).
static func abilities(item: Dictionary) -> Dictionary:
	var out := {}
	if item.is_empty():
		return out
	var lvl := level_of(item)
	for e in track(item):
		if int(e.get("level", 99)) <= lvl:
			var params: Dictionary = e.duplicate()
			params.erase("level")
			out[str(e["ability"])] = params
	return out


static func has_ability(item: Dictionary, ability_id: String) -> bool:
	return abilities(item).has(ability_id)


## Next level that unlocks something new (-1 when the track is complete).
static func next_unlock_level(item: Dictionary) -> int:
	var lvl := level_of(item)
	var best := -1
	for e in track(item):
		var l := int(e.get("level", 0))
		if l > lvl and (best < 0 or l < best):
			best = l
	return best


## Adds XP to an item (mutates it). Returns {"levels": [new levels], "unlocked": [track entries now unlocked]}.
static func add_xp(item: Dictionary, amount: float, cfg: Dictionary = {}) -> Dictionary:
	var res := {"levels": [], "unlocked": []}
	if item.is_empty() or amount <= 0.0 or not is_masterable(item):
		return res
	if cfg.is_empty():
		cfg = pack()
	var cap := max_level(cfg)
	var lvl := level_of(item)
	if lvl >= cap:
		item["mastery_level"] = cap
		return res
	var xp := float(item.get("mastery_xp", 0.0)) + amount
	while lvl < cap and xp >= float(xp_to_next(lvl, cfg)):
		xp -= float(xp_to_next(lvl, cfg))
		lvl += 1
		res["levels"].append(lvl)
		for e in track(item):
			if int(e.get("level", 0)) == lvl:
				res["unlocked"].append(e)
	if lvl >= cap:
		xp = 0.0
	item["mastery_level"] = lvl
	item["mastery_xp"] = snappedf(xp, 0.01)
	return res


## XP for one use of an item: event is "hit", "kill", "block", "hit_taken", "cast" or "worn_kill".
static func xp_for(event: String, enemy_level: int = 1, cfg: Dictionary = {}) -> float:
	if cfg.is_empty():
		cfg = pack()
	var x: Dictionary = cfg.get("xp", {})
	var base := float(x.get(event, 0.0))
	return base * (1.0 + float(x.get("enemy_level_bonus", 0.15)) * float(maxi(0, enemy_level - 1)))


static func ability_def(ability_id: String) -> Dictionary:
	return pack().get("abilities", {}).get(ability_id, {})


static func ability_name(ability_id: String) -> String:
	return str(ability_def(ability_id).get("name", ability_id.capitalize()))


## Fills an ability description's {param} / {param%} placeholders from a track entry.
static func describe(ability_id: String, params: Dictionary) -> String:
	var text := str(ability_def(ability_id).get("description", ability_id))
	for k in params.keys():
		var v: Variant = params[k]
		if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
			continue
		var f := float(v)
		text = text.replace("{%s%%}" % k, "%d%%" % int(round(f * 100.0)))
		text = text.replace("{%s}" % k, str(int(f)) if is_equal_approx(f, round(f)) else "%.1f" % f)
	return text


## Sums the numeric parameters of every passive ability on the given items (worn armor & accessories).
static func aggregate_passives(items: Array) -> Dictionary:
	var out := {}
	for it in items:
		if typeof(it) != TYPE_DICTIONARY or it.is_empty():
			continue
		var unlocked := abilities(it)
		for id in unlocked.keys():
			var acc: Dictionary = out.get(id, {})
			var p: Dictionary = unlocked[id]
			for k in p.keys():
				if k == "ability":
					continue
				if k == "cooldown" and id == "second_wind":
					acc[k] = minf(float(acc.get(k, 1e9)), float(p[k]))
				elif typeof(p[k]) == TYPE_FLOAT or typeof(p[k]) == TYPE_INT:
					acc[k] = float(acc.get(k, 0.0)) + float(p[k])
			out[id] = acc
	return out
