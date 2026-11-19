class_name CombatMath
extends RefCounted
## Tier 2 Pure System: Skyrim-inspired left/right-hand combat, armor mitigation,
## blocking, power attacks, bow draw scaling, crits, and Sponsored/Mythic triggers.


static func equip_item_in_slots(equipment: Dictionary, item: Dictionary, preferred_hand: String = "") -> Dictionary:
	var updated := equipment.duplicate(true)
	var slot := str(item.get("slot", ""))
	if slot == "consumable" or slot.is_empty():
		return updated

	if bool(item.get("two_handed", false)):
		updated["right_hand"] = item.duplicate(true)
		updated.erase("left_hand")
		return updated

	var target_slot := slot
	if preferred_hand == "left_hand" and (slot == "left_hand" or bool(item.get("can_offhand", false))):
		target_slot = "left_hand"
	elif preferred_hand == "right_hand" and (slot == "right_hand" or bool(item.get("can_mainhand", false))):
		target_slot = "right_hand"

	# Equipping a one-handed/offhand item replaces an equipped two-handed weapon
	if target_slot in ["left_hand", "right_hand"]:
		var rh: Dictionary = updated.get("right_hand", {})
		if not rh.is_empty() and bool(rh.get("two_handed", false)):
			updated.erase("right_hand")

	updated[target_slot] = item.duplicate(true)
	return updated


static func compute_armor_mitigation(armor: float, player_cfg: Dictionary) -> float:
	var combat_cfg: Dictionary = player_cfg["combat"]
	var k := float(combat_cfg["armor_mitigation_k"])
	var cap := float(combat_cfg["max_armor_mitigation"])
	var eff_armor := maxf(0.0, armor)
	return minf(cap, eff_armor / (eff_armor + k))


static func compute_bow_draw_ratio(hold_sec: float, player_cfg: Dictionary) -> float:
	var combat_cfg: Dictionary = player_cfg["combat"]
	var min_s := float(combat_cfg["bow_min_draw_sec"])
	var full_s := float(combat_cfg["bow_full_draw_sec"])
	if hold_sec < min_s:
		return 0.0
	return clampf((hold_sec - min_s) / maxf(0.01, full_s - min_s), 0.15, 1.0)


static func resolve_attack(params: Dictionary, player_cfg: Dictionary, rng: SeededRng) -> Dictionary:
	var base_damage := float(params.get("base_damage", 10.0))
	var bonus_damage := float(params.get("bonus_damage", 0.0))
	var damage_mult := float(params.get("damage_multiplier", 1.0))
	var is_power_attack := bool(params.get("is_power_attack", false))
	var crit_chance := clampf(float(params.get("crit_chance", 0.05)), 0.0, 0.95)
	var crit_mult := float(params.get("crit_multiplier", 1.5))
	var target_armor := float(params.get("target_armor", 0.0))
	var target_blocking := bool(params.get("target_blocking", false))
	var target_block_bonus := float(params.get("target_block_bonus", 0.0))
	var sponsored_effects: Array = params.get("sponsored_effects", [])

	var raw := (base_damage + bonus_damage) * damage_mult
	if is_power_attack:
		raw *= float(player_cfg["combat"]["power_attack_damage_multiplier"])

	var is_crit := rng.next_float("combat") < crit_chance
	if is_crit:
		raw *= crit_mult

	# +/- 8% deterministic combat variance
	var variance := rng.next_float_range("combat", 0.92, 1.08)
	raw *= variance

	var armor_dr := compute_armor_mitigation(target_armor, player_cfg)
	var after_armor := raw * (1.0 - armor_dr)

	var block_stamina_cost := 0.0
	var final_damage := after_armor
	if target_blocking:
		var base_block := float(player_cfg["combat"]["block_damage_reduction_base"])
		var block_dr := clampf(base_block + target_block_bonus, 0.0, 0.85)
		final_damage = after_armor * (1.0 - block_dr)
		block_stamina_cost = after_armor * float(player_cfg["combat"]["block_stamina_cost_per_damage"])

	var explosive_aoe := false
	if is_crit and sponsored_effects.has("explosive_crits"):
		explosive_aoe = true

	return {
		"final_damage": maxf(1.0, snappedf(final_damage, 0.1)),
		"is_crit": is_crit,
		"was_blocked": target_blocking,
		"block_stamina_cost": snappedf(block_stamina_cost, 0.1),
		"trigger_explosive_crits": explosive_aoe,
	}
