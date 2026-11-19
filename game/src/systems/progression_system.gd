class_name ProgressionSystem
extends RefCounted
## Tier 2 Pure System: Hybrid Character Progression (D-019).
## Combines XP/Level-Up Attribute + Perk Points with Skyrim-style use-to-improve proficiencies.

var level: int = 1
var xp: float = 0.0
var attribute_points: int = 0
var perk_points: int = 0
var spent_attributes: Dictionary = {"health": 0, "magicka": 0, "stamina": 0}
var unlocked_perks: Array[String] = []
var skill_levels: Dictionary = {}
var skill_xp: Dictionary = {}
var _cfg: Dictionary = {}


func _init(progression_cfg: Dictionary) -> void:
	_cfg = progression_cfg
	reset_to_start()


func reset_to_start() -> void:
	level = 1
	xp = 0.0
	attribute_points = 0
	perk_points = 0
	spent_attributes = {"health": 0, "magicka": 0, "stamina": 0}
	unlocked_perks.clear()
	skill_levels.clear()
	skill_xp.clear()
	var prof_cfg: Dictionary = _cfg.get("proficiencies", {})
	var start_lvl := int(prof_cfg.get("starting_level", 1))
	for s in prof_cfg.get("skills", []):
		skill_levels[str(s)] = start_lvl
		skill_xp[str(s)] = 0.0


func xp_for_next_level() -> float:
	var curve: Dictionary = _cfg["xp_curve"]
	return round(float(curve["base_xp"]) * pow(float(level), float(curve["exponent"])))


func add_xp(amount: float) -> Array[int]:
	var gained_levels: Array[int] = []
	xp += maxf(0.0, amount)
	var rewards: Dictionary = _cfg["level_up_rewards"]
	while xp >= xp_for_next_level():
		xp -= xp_for_next_level()
		level += 1
		attribute_points += int(rewards["attribute_points"])
		perk_points += int(rewards["perk_points"])
		gained_levels.append(level)
	return gained_levels


func record_skill_use(skill_name: String, multiplier: float = 1.0) -> Dictionary:
	var prof_cfg: Dictionary = _cfg["proficiencies"]
	if not skill_levels.has(skill_name):
		return {"skill_leveled_up": false, "new_skill_level": 0, "char_levels_gained": []}
	var max_lvl := int(prof_cfg["max_level"])
	if int(skill_levels[skill_name]) >= max_lvl:
		return {"skill_leveled_up": false, "new_skill_level": max_lvl, "char_levels_gained": []}

	var gain := float(prof_cfg["xp_gain_per_use"].get(skill_name, 10.0)) * multiplier
	skill_xp[skill_name] = float(skill_xp[skill_name]) + gain

	var leveled := false
	var char_levels: Array[int] = []
	while float(skill_xp[skill_name]) >= _xp_for_skill_level(int(skill_levels[skill_name])) and int(skill_levels[skill_name]) < max_lvl:
		skill_xp[skill_name] = float(skill_xp[skill_name]) - _xp_for_skill_level(int(skill_levels[skill_name]))
		skill_levels[skill_name] = int(skill_levels[skill_name]) + 1
		leveled = true
		var gained := add_xp(float(prof_cfg["character_xp_on_skill_up"]))
		for g in gained:
			char_levels.append(g)

	return {
		"skill_leveled_up": leveled,
		"new_skill_level": int(skill_levels[skill_name]),
		"char_levels_gained": char_levels,
	}


func spend_attribute(attr_name: String) -> bool:
	if attribute_points <= 0 or not spent_attributes.has(attr_name):
		return false
	attribute_points -= 1
	spent_attributes[attr_name] = int(spent_attributes[attr_name]) + 1
	return true


func unlock_perk(perk_id: String) -> bool:
	if perk_points <= 0 or unlocked_perks.has(perk_id):
		return false
	for p in _cfg.get("perks", []):
		if str(p["id"]) == perk_id:
			perk_points -= 1
			unlocked_perks.append(perk_id)
			return true
	return false


func get_proficiency_damage_multiplier(skill_name: String) -> float:
	var lvl := int(skill_levels.get(skill_name, 1))
	var per_lvl := float(_cfg["proficiencies"]["damage_bonus_per_level"])
	return 1.0 + float(maxi(0, lvl - 1)) * per_lvl


func get_block_proficiency_bonus() -> float:
	var lvl := int(skill_levels.get("block", 1))
	var per_lvl := float(_cfg["proficiencies"]["block_bonus_per_level"])
	return float(maxi(0, lvl - 1)) * per_lvl


func get_derived_bonuses() -> Dictionary:
	var rewards: Dictionary = _cfg["level_up_rewards"]
	var out := {
		"health_bonus": float(spent_attributes["health"]) * float(rewards["health_per_point"]),
		"magicka_bonus": float(spent_attributes["magicka"]) * float(rewards["magicka_per_point"]),
		"stamina_bonus": float(spent_attributes["stamina"]) * float(rewards["stamina_per_point"]),
		"armor_bonus": 0.0,
		"block_bonus": get_block_proficiency_bonus(),
		"damage_multiplier_bonus": 0.0,
		"spell_multiplier_bonus": 0.0,
	}
	for p in _cfg.get("perks", []):
		if unlocked_perks.has(str(p["id"])):
			out["health_bonus"] += float(p.get("health_bonus", 0.0))
			out["magicka_bonus"] += float(p.get("magicka_bonus", 0.0))
			out["stamina_bonus"] += float(p.get("stamina_bonus", 0.0))
			out["armor_bonus"] += float(p.get("armor_bonus", 0.0))
			out["block_bonus"] += float(p.get("block_bonus", 0.0))
			out["damage_multiplier_bonus"] += float(p.get("damage_multiplier_bonus", 0.0))
			out["spell_multiplier_bonus"] += float(p.get("spell_multiplier_bonus", 0.0))
	return out


func to_dict() -> Dictionary:
	return {
		"level": level,
		"xp": xp,
		"attribute_points": attribute_points,
		"perk_points": perk_points,
		"spent_attributes": spent_attributes.duplicate(true),
		"unlocked_perks": unlocked_perks.duplicate(),
		"skill_levels": skill_levels.duplicate(true),
		"skill_xp": skill_xp.duplicate(true),
	}


func from_dict(data: Dictionary) -> void:
	level = int(data.get("level", 1))
	xp = float(data.get("xp", 0.0))
	attribute_points = int(data.get("attribute_points", 0))
	perk_points = int(data.get("perk_points", 0))
	spent_attributes = data.get("spent_attributes", {"health": 0, "magicka": 0, "stamina": 0}).duplicate(true)
	unlocked_perks.clear()
	for pid in data.get("unlocked_perks", []):
		unlocked_perks.append(str(pid))
	skill_levels = data.get("skill_levels", {}).duplicate(true)
	skill_xp = data.get("skill_xp", {}).duplicate(true)


func _xp_for_skill_level(current_skill_lvl: int) -> float:
	var prof_cfg: Dictionary = _cfg["proficiencies"]
	return float(prof_cfg["base_xp_per_skill_level"]) * pow(float(prof_cfg["skill_xp_growth"]), float(maxi(0, current_skill_lvl - 1)))
