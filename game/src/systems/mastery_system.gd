class_name MasterySystem
extends RefCounted
## Tier 2 Pure System — Item Mastery (D-049, D-060).
## Every weapon, spell, shield, armor piece and accessory carries its own mastery level and XP on the item
## instance ("mastery_level", "mastery_xp"). Using the item earns XP; each level makes its core stats stronger
## (stat_growth_per_level) and the levels named in the item's own "mastery" track unlock new abilities.
## Lower-rarity items have lower mastery level ceilings and fewer abilities (D-060).

const STAT_KEYS := ["damage", "armor", "heal_amount", "bonus_damage", "bonus_health", "bonus_magicka", "bonus_stamina"]


static func pack() -> Dictionary:
	return DataLoader.get_mastery_pack()


static func max_level(cfg: Dictionary = {}) -> int:
	if cfg.is_empty():
		cfg = pack()
	return int(cfg.get("max_level", 10))


## D-060: Rarity-capped mastery ceiling for a specific item instance or definition.
static func max_level_for(item: Dictionary, cfg: Dictionary = {}) -> int:
	if cfg.is_empty():
		cfg = pack()
	var global_cap := int(cfg.get("max_level", 10))
	if item.is_empty():
		return global_cap
	# Always check the item definition's inherent rarity when available
	var rarity_id := str(item.get("rarity", ""))
	if DataLoader != null and not str(item.get("id", "")).is_empty():
		var def := DataLoader.get_item_def(str(item["id"]))
		if not def.is_empty() and def.has("rarity"):
			rarity_id = str(def["rarity"])
	if rarity_id.is_empty():
		rarity_id = "common"
	return mini(global_cap, RarityTable.mastery_max_level(rarity_id))


## True for items that can be mastered (gear, not consumables/ingredients).
static func is_masterable(item: Dictionary) -> bool:
	return str(item.get("category", "")) in ["weapon", "spell", "shield", "armor", "accessory"]


static func level_of(item: Dictionary) -> int:
	var cap := max_level_for(item) if is_masterable(item) else max_level()
	return clampi(int(item.get("mastery_level", 1)), 1, maxi(1, cap))


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
		# FB-022: the item's power-scale knobs (balance.json item_power x the item's own power_scale)
		return base * stat_multiplier(item) * PowerScale.item(item)
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
	var cap := max_level_for(item)
	var best := -1
	for e in track(item):
		var l := int(e.get("level", 0))
		if l > lvl and l <= cap and (best < 0 or l < best):
			best = l
	return best


## Adds XP to an item (mutates it). Returns {"levels": [new levels], "unlocked": [track entries now unlocked]}.
static func add_xp(item: Dictionary, amount: float, cfg: Dictionary = {}) -> Dictionary:
	var res := {"levels": [], "unlocked": []}
	if item.is_empty() or amount <= 0.0 or not is_masterable(item):
		return res
	if cfg.is_empty():
		cfg = pack()
	var cap := max_level_for(item, cfg)
	var lvl := level_of(item)
	if lvl >= cap:
		item["mastery_level"] = cap
		item["mastery_xp"] = 0.0
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


## FB-022: the uses that earn this item mastery XP, as [event, xp] pairs (in mastery.json "xp" amounts).
static func xp_sources(item: Dictionary, cfg: Dictionary = {}) -> Array:
	if cfg.is_empty():
		cfg = pack()
	var x: Dictionary = cfg.get("xp", {})
	var out: Array = []
	match str(item.get("category", "")):
		"weapon":
			out = [["hit", x.get("hit", 1.0)], ["kill", x.get("kill", 5.0)]]
		"spell":
			if str(item.get("spell_kind", "")) == "heal":
				out = [["cast", x.get("cast", 1.5)]]
			else:
				out = [["hit", x.get("hit", 1.0)], ["kill", x.get("kill", 5.0)]]
		"shield":
			out = [["block", x.get("block", 2.0)]]
		"armor", "accessory":
			out = [["hit_taken", x.get("hit_taken", 1.0)], ["worn_kill", x.get("worn_kill", 1.0)]]
	return out


const XP_EVENT_TEXT := {
	"hit": "land a hit with it", "kill": "finish an enemy with it", "cast": "cast it",
	"block": "block a blow with it raised", "hit_taken": "take a hit while wearing it", "worn_kill": "win a fight while wearing it",
}


const XP_EVENT_NOUN := {"hit": "hits", "kill": "kills", "cast": "casts", "block": "blocks", "hit_taken": "hits taken", "worn_kill": "fights won"}


## FB-022: plain-English instructions for levelling an item: what to do, how much XP each use gives, and how
## much is still needed for the next level.
static func how_to_level(item: Dictionary, cfg: Dictionary = {}) -> String:
	if not is_masterable(item):
		return ""
	if cfg.is_empty():
		cfg = pack()
	var lvl := level_of(item)
	var srcs := xp_sources(item, cfg)
	if srcs.is_empty():
		return ""
	var parts: Array = []
	for sx in srcs:
		parts.append("%s (+%s xp)" % [str(XP_EVENT_TEXT.get(str(sx[0]), str(sx[0]))), _num(float(sx[1]))])
	var text := "To level up: " + " or ".join(parts) + "."
	if lvl >= max_level_for(item, cfg):
		return "Fully mastered (Lv %d cap). " % max_level_for(item, cfg) + text.replace("To level up: ", "It grew by: ")
	var left := maxf(0.0, float(xp_to_next(lvl, cfg)) - float(item.get("mastery_xp", 0.0)))
	var est: Array = []
	for sx in srcs:
		var per := float(sx[1])
		if per > 0.0:
			est.append("%d %s" % [int(ceil(left / per)), str(XP_EVENT_NOUN.get(str(sx[0]), str(sx[0])))])
	text += " %s xp to mastery %d (about %s)." % [_num(left), lvl + 1, " or ".join(est)]
	text += " Higher-level enemies give more."
	return text


static func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, round(v)) else "%.1f" % v
