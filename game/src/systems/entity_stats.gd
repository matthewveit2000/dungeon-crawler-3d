class_name EntityStats
extends RefCounted
## Tier 2 Pure System: Unified Entity Stat & Resistance Sheet (D-051, D-055).
## Shared by the player, enemies, floor bosses, and future summons/companions so damage types,
## knockback, crowd control, and buffs resolve cleanly without hardcoded per-entity checks.

const POWER_TIER_RANK := {
	"minion": 0,
	"standard": 1,
	"elite": 2,
	"miniboss": 3,
	"boss": 4,
}

const DEFAULT_BASE := {
	"max_health": 100.0,
	"health_regen": 0.0,
	"max_magicka": 0.0,
	"magicka_regen": 0.0,
	"max_stamina": 100.0,
	"stamina_regen": 10.0,
	"armor": 0.0,
	"block_mitigation": 0.0,
	"evasion_chance": 0.0,
	"fire_res": 0.0,
	"frost_res": 0.0,
	"shock_res": 0.0,
	"poison_res": 0.0,
	"bleed_res": 0.0,
	"arcane_res": 0.0,
	"paralysis_res": 0.0,
	"stun_res": 0.0,
	"slow_res": 0.0,
	"knockback_res": 0.0,
	"poise": 100.0,
	"mass": 1.0,
	"move_speed": 4.0,
	"sprint_mult": 1.5,
	"attack_speed": 1.0,
	"cast_speed": 1.0,
	"crit_chance": 0.05,
	"crit_mult": 1.5,
	"ability_power": 1.0,
	"cooldown_reduction": 0.0,
}

const DAMAGE_TYPE_TO_RES := {
	"fire": "fire_res",
	"burn": "fire_res",
	"frost": "frost_res",
	"cold": "frost_res",
	"shock": "shock_res",
	"lightning": "shock_res",
	"poison": "poison_res",
	"bleed": "bleed_res",
	"arcane": "arcane_res",
}

const CONTROL_KIND_TO_RES := {
	"stun": "stun_res",
	"freeze": "stun_res",
	"paralyze": "paralysis_res",
	"chill": "slow_res",
	"slow": "slow_res",
	"root": "slow_res",
}

var base: Dictionary = {}
var modifiers: Dictionary = {}  ## mod_id -> {"stat": String, "add": float, "mult": float, "t": float}
var power_tier: String = "standard"


func _init(initial_base: Dictionary = {}, p_power_tier: String = "standard") -> void:
	base = DEFAULT_BASE.duplicate()
	for k in initial_base.keys():
		base[k] = float(initial_base[k])
	power_tier = p_power_tier


static func from_player_cfg(player_cfg: Dictionary) -> EntityStats:
	var s: Dictionary = player_cfg.get("stats", {})
	var m: Dictionary = player_cfg.get("movement", {})
	var walk := maxf(0.1, float(m.get("walk_speed", 5.4)))
	var sprint := float(m.get("sprint_speed", 8.6))
	var init_vals := {
		"max_health": float(s.get("base_max_health", 120.0)),
		"health_regen": float(s.get("health_regen_per_sec", 1.2)),
		"max_magicka": float(s.get("base_max_magicka", 100.0)),
		"magicka_regen": float(s.get("magicka_regen_per_sec", 7.5)),
		"max_stamina": float(s.get("base_max_stamina", 100.0)),
		"stamina_regen": float(s.get("stamina_regen_per_sec", 16.0)),
		"armor": float(s.get("base_armor", 10.0)),
		"crit_chance": float(s.get("base_crit_chance", 0.08)),
		"crit_mult": float(s.get("base_crit_multiplier", 1.65)),
		"move_speed": walk,
		"sprint_mult": sprint / walk,
	}
	var custom_res: Dictionary = s.get("resistances", {})
	for k in custom_res.keys():
		init_vals[k] = float(custom_res[k])
	return EntityStats.new(init_vals, "standard")


static func from_enemy_def(enemy_def: Dictionary, level_scale: Dictionary = {}) -> EntityStats:
	var is_boss := bool(enemy_def.get("is_boss", false))
	var tier := str(enemy_def.get("power_tier", "boss" if is_boss else "standard"))
	var hp_s := float(level_scale.get("health", 1.0))
	var arm_add := float(level_scale.get("armor", 0.0))
	var init_vals := {
		"max_health": snappedf(float(enemy_def.get("max_health", 60.0)) * hp_s, 1.0),
		"armor": float(enemy_def.get("armor", 5.0)) + arm_add,
		"move_speed": float(enemy_def.get("move_speed", 3.6)),
		"max_magicka": float(enemy_def.get("max_magicka", 0.0)),
		"magicka_regen": float(enemy_def.get("magicka_regen", 0.0)),
		"max_stamina": float(enemy_def.get("max_stamina", 100.0)),
		"stamina_regen": float(enemy_def.get("stamina_regen", 12.0)),
		# Preserve exact existing boss knockback/stun resistance (0.35x impulse/duration = 0.65 resistance)
		"knockback_res": float(enemy_def.get("knockback_res", 0.65 if is_boss else 0.0)),
		"stun_res": float(enemy_def.get("stun_res", 0.65 if is_boss else 0.0)),
		"paralysis_res": float(enemy_def.get("paralysis_res", 0.75 if is_boss else 0.0)),
		"slow_res": float(enemy_def.get("slow_res", 0.0)),
		"mass": float(enemy_def.get("mass", 1.0)),
		"poise": float(enemy_def.get("poise", 250.0 if is_boss else 100.0)),
	}
	var res_map: Dictionary = enemy_def.get("resistances", {})
	for k in res_map.keys():
		init_vals[k] = float(res_map[k])
	var extra_stats: Dictionary = enemy_def.get("stats", {})
	for k in extra_stats.keys():
		init_vals[k] = float(extra_stats[k])
	return EntityStats.new(init_vals, tier)


func set_base(stat: String, value: float) -> void:
	base[stat] = value


func get_base(stat: String) -> float:
	return float(base.get(stat, DEFAULT_BASE.get(stat, 0.0)))


func get_stat(stat: String) -> float:
	var add_total := 0.0
	var mult_total := 1.0
	for mod in modifiers.values():
		if str(mod["stat"]) == stat:
			add_total += float(mod["add"])
			mult_total *= float(mod["mult"])
	return (get_base(stat) + add_total) * mult_total


func add_modifier(mod_id: String, stat: String, add_val: float = 0.0, mult_val: float = 1.0, duration: float = -1.0) -> void:
	modifiers[mod_id] = {"stat": stat, "add": add_val, "mult": mult_val, "t": duration}


func remove_modifier(mod_id: String) -> void:
	modifiers.erase(mod_id)


func clear_modifiers() -> void:
	modifiers.clear()


func tick(delta: float) -> void:
	var expired: Array[String] = []
	for mid in modifiers.keys():
		var m: Dictionary = modifiers[mid]
		var t := float(m["t"])
		if t >= 0.0:
			t -= delta
			m["t"] = t
			if t <= 0.0:
				expired.append(str(mid))
	for mid in expired:
		modifiers.erase(mid)


func power_tier_rank() -> int:
	return int(POWER_TIER_RANK.get(power_tier, 1))


## Resolves elemental or typed damage against the matching resistance (-1.0 = double, 0.0 = neutral, 1.0 = immune).
func resolve_elemental_damage(raw_damage: float, damage_type: String) -> float:
	if damage_type.is_empty() or damage_type == "physical":
		return raw_damage
	var res_key := str(DAMAGE_TYPE_TO_RES.get(damage_type, ""))
	if res_key.is_empty():
		return raw_damage
	var res := clampf(get_stat(res_key), -1.0, 1.0)
	return maxf(0.0, raw_damage * (1.0 - res))


## Resolves a knockback impulse against knockback_res and mass.
## Legacy calls omit knockback_power (< 0): behaves identically to pre-refactor shove/boss resistance.
func resolve_knockback(force: float, knockback_power: float = -1.0) -> Dictionary:
	var res := clampf(get_stat("knockback_res"), 0.0, 1.0)
	var mass := maxf(0.1, get_stat("mass"))
	if knockback_power < 0.0:
		var impulse := (force * (1.0 - res)) / mass
		return {
			"impulse": impulse,
			"resisted": impulse <= 0.0,
			"interrupts": power_tier != "boss" and impulse > 0.0,
		}
	if knockback_power < res:
		return {"impulse": 0.0, "resisted": true, "interrupts": false}
	var scale := clampf(1.0 - maxf(0.0, res - knockback_power * 0.25), 0.2, 1.0)
	var eff := (force * scale) / mass
	return {
		"impulse": eff,
		"resisted": eff <= 0.0,
		"interrupts": eff > 0.5 and (power_tier != "boss" or knockback_power >= 0.9),
	}


## Resolves crowd-control duration (stun, freeze, paralyze, slow, root) against entity resistances.
## Legacy calls omit control_power (< 0): behaves identically to pre-refactor stun/freeze/chill.
func resolve_control(kind: String, duration: float, control_power: float = -1.0) -> Dictionary:
	var res_key := str(CONTROL_KIND_TO_RES.get(kind, ""))
	var res := clampf(get_stat(res_key), 0.0, 1.0) if not res_key.is_empty() else 0.0
	if control_power < 0.0:
		var eff_dur := duration * (1.0 - res)
		return {"duration": eff_dur, "resisted": eff_dur <= 0.0}
	if control_power < res:
		return {"duration": 0.0, "resisted": true}
	var scale := clampf(1.0 - maxf(0.0, res - control_power * 0.25), 0.25, 1.0)
	var dur := duration * scale
	return {"duration": dur, "resisted": dur <= 0.0}
