class_name AbilityExecutor
extends RefCounted
## Tier 2 Pure System: Data-driven Active Ability & Composable Skill Executor (D-051, D-055).
## Drives cooldowns, resource checks, and composable effect dispatch for future Active Abilities
## (Enrage, Shockwave Fling, Brief Invulnerability), Ground Zones, Barriers, Summons, and multi-missile casts.

var cooldowns: Dictionary = {}  ## ability_id -> remaining seconds


func tick(delta: float) -> void:
	var done: Array[String] = []
	for aid in cooldowns.keys():
		var left := float(cooldowns[aid]) - delta
		if left <= 0.0:
			done.append(str(aid))
		else:
			cooldowns[aid] = left
	for aid in done:
		cooldowns.erase(aid)


func cooldown_remaining(ability_id: String) -> float:
	return float(cooldowns.get(ability_id, 0.0))


func can_execute(ability_def: Dictionary, cur_magicka: float, cur_stamina: float) -> Dictionary:
	var aid := str(ability_def.get("id", ""))
	if aid.is_empty():
		return {"ok": false, "reason": "missing_id"}
	if cooldown_remaining(aid) > 0.0:
		return {"ok": false, "reason": "on_cooldown"}
	if cur_magicka < float(ability_def.get("magicka_cost", 0.0)):
		return {"ok": false, "reason": "insufficient_magicka"}
	if cur_stamina < float(ability_def.get("stamina_cost", 0.0)):
		return {"ok": false, "reason": "insufficient_stamina"}
	return {"ok": true, "reason": ""}


## Executes a data-driven ability definition against `ctx` and `callbacks`.
## `ctx` keys:
##   magicka (float), stamina (float), stats (EntityStats), status_comp (StatusComponent),
##   origin (Vector3), forward (Vector3), targets (Array of CombatActor/Node3D)
## Optional `callbacks`:
##   "spawn_ground_zone", "spawn_barrier", "spawn_summon", "spawn_projectile", "damage_target"
func execute(ability_def: Dictionary, ctx: Dictionary, callbacks: Dictionary = {}) -> Dictionary:
	var check := can_execute(ability_def, float(ctx.get("magicka", 0.0)), float(ctx.get("stamina", 0.0)))
	if not bool(check["ok"]):
		return check

	var aid := str(ability_def["id"])
	var stats: EntityStats = ctx.get("stats", null)
	var cdr := clampf(stats.get_stat("cooldown_reduction"), 0.0, 0.65) if stats != null else 0.0
	var cd := maxf(0.0, float(ability_def.get("cooldown_sec", 0.0)) * (1.0 - cdr))
	if cd > 0.0:
		cooldowns[aid] = cd

	var kind := str(ability_def.get("kind", ""))
	var affected := 0
	var origin: Vector3 = ctx.get("origin", Vector3.ZERO)

	match kind:
		"self_buff":
			var sc: StatusComponent = ctx.get("status_comp", null)
			if sc != null:
				sc.apply(str(ability_def.get("status", "")), ability_def.get("params", {}), stats)
				affected = 1
		"radial_knockback":
			var r := float(ability_def.get("radius", 6.0))
			var force := float(ability_def.get("knockback_force", 10.0))
			var kb_power := float(ability_def.get("knockback_power", 1.0))
			var dmg := float(ability_def.get("damage", 0.0))
			var dtype := str(ability_def.get("damage_type", "physical"))
			var dmg_cb: Callable = callbacks.get("damage_target", Callable())
			for t in ctx.get("targets", []):
				if not is_instance_valid(t) or not (t is Node3D):
					continue
				var tn := t as Node3D
				var delta_v := tn.global_position - origin
				delta_v.y = 0.0
				if delta_v.length() > r:
					continue
				var dir := delta_v.normalized() if delta_v.length() > 0.01 else Vector3.FORWARD
				if tn is EnemyActor:
					var ea := tn as EnemyActor
					if not ea.is_alive():
						continue
					ea.apply_knockback(dir, force, kb_power)
					if dmg > 0.0:
						if dmg_cb.is_valid():
							dmg_cb.call(ea, dmg, dtype)
						else:
							var eff := ea.entity_stats.resolve_elemental_damage(dmg, dtype)
							if eff > 0.0:
								ea.take_damage(eff)
					affected += 1
		"ground_zone":
			var cb: Callable = callbacks.get("spawn_ground_zone", Callable())
			if cb.is_valid():
				cb.call(ability_def, origin)
				affected = 1
		"barrier":
			var cb: Callable = callbacks.get("spawn_barrier", Callable())
			if cb.is_valid():
				cb.call(ability_def, origin, ctx.get("forward", Vector3.FORWARD))
				affected = 1
		"summon":
			var cb: Callable = callbacks.get("spawn_summon", Callable())
			if cb.is_valid():
				var qty := maxi(1, int(ability_def.get("quantity", 1)))
				for i in range(qty):
					cb.call(ability_def, i, qty)
				affected = qty
		"projectile_volley":
			var cb: Callable = callbacks.get("spawn_projectile", Callable())
			if cb.is_valid():
				var missiles: Array = ability_def.get("missiles", [{}])
				for i in range(missiles.size()):
					cb.call(ability_def, missiles[i], i, missiles.size())
				affected = missiles.size()

	return {
		"ok": true,
		"ability_id": aid,
		"kind": kind,
		"affected": affected,
		"magicka_spent": float(ability_def.get("magicka_cost", 0.0)),
		"stamina_spent": float(ability_def.get("stamina_cost", 0.0)),
		"cooldown": cd,
	}
