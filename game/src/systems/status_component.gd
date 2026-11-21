class_name StatusComponent
extends RefCounted
## Tier 2 Pure System: Unified Status Effect runner shared by player, enemies, bosses, and summons (D-055).
## Supports existing statuses (bleed, burn, poison stacks, chill, freeze, stun, sunder, rally, ward, regen, slow)
## and future-ready statuses (paralyze, haste, enrage, invulnerable, root), all resolved against EntityStats.

var entries: Dictionary = {}
var stun_t: float = 0.0
var paralyze_t: float = 0.0


func clear() -> void:
	entries.clear()
	stun_t = 0.0
	paralyze_t = 0.0


## Applies a status effect, respecting EntityStats resistances when provided.
## Returns {"applied": bool, "resisted": bool, "kind": String}.
func apply(kind: String, params: Dictionary, stats: EntityStats = null) -> Dictionary:
	var control_power := float(params.get("control_power", -1.0))
	match kind:
		"bleed", "burn":
			if stats != null and stats.resolve_elemental_damage(1.0, kind) <= 0.0:
				return {"applied": false, "resisted": true, "kind": kind}
			var cur: Dictionary = entries.get(kind, {})
			entries[kind] = {
				"dps": maxf(float(cur.get("dps", 0.0)), float(params.get("dps", 3.0))),
				"t": maxf(float(cur.get("t", 0.0)), float(params.get("duration", 3.0))),
			}
			return {"applied": true, "resisted": false, "kind": kind}
		"poison":
			if stats != null and stats.resolve_elemental_damage(1.0, "poison") <= 0.0:
				return {"applied": false, "resisted": true, "kind": kind}
			var cur: Dictionary = entries.get("poison", {"stacks": []})
			var stacks: Array = cur["stacks"]
			stacks.append({"dps": float(params.get("dps", 4.0)), "t": float(params.get("duration", 5.0))})
			while stacks.size() > maxi(1, int(params.get("stacks", 1))):
				stacks.pop_front()
			entries["poison"] = {"stacks": stacks}
			return {"applied": true, "resisted": false, "kind": kind}
		"chill":
			var dur := float(params.get("duration", 3.0))
			if stats != null:
				var ctrl := stats.resolve_control("chill", dur, control_power)
				if bool(ctrl["resisted"]):
					return {"applied": false, "resisted": true, "kind": kind}
				dur = float(ctrl["duration"])
			var cur: Dictionary = entries.get("chill", {})
			entries["chill"] = {
				"slow": maxf(float(cur.get("slow", 0.0)), float(params.get("slow", 0.3))),
				"t": maxf(float(cur.get("t", 0.0)), dur),
			}
			return {"applied": true, "resisted": false, "kind": kind}
		"slow":
			var dur := float(params.get("duration", 2.5))
			if stats != null:
				var ctrl := stats.resolve_control("slow", dur, control_power)
				if bool(ctrl["resisted"]):
					return {"applied": false, "resisted": true, "kind": kind}
				dur = float(ctrl["duration"])
			var cur: Dictionary = entries.get("slow", {})
			var cur_amt := float(cur.get("amount", 0.0)) if float(cur.get("t", 0.0)) > 0.0 else 0.0
			entries["slow"] = {
				"amount": clampf(maxf(cur_amt, float(params.get("amount", 0.3))), 0.0, 0.8),
				"t": maxf(float(cur.get("t", 0.0)), dur),
			}
			return {"applied": true, "resisted": false, "kind": kind}
		"freeze", "stun":
			var dur := float(params.get("duration", 1.0))
			if stats != null:
				var ctrl := stats.resolve_control(kind, dur, control_power)
				if bool(ctrl["resisted"]):
					return {"applied": false, "resisted": true, "kind": kind}
				dur = float(ctrl["duration"])
			stun_t = maxf(stun_t, dur)
			return {"applied": true, "resisted": false, "kind": kind}
		"paralyze":
			var dur := float(params.get("duration", 2.0))
			if stats != null:
				var ctrl := stats.resolve_control("paralyze", dur, control_power)
				if bool(ctrl["resisted"]):
					return {"applied": false, "resisted": true, "kind": kind}
				dur = float(ctrl["duration"])
			paralyze_t = maxf(paralyze_t, dur)
			return {"applied": true, "resisted": false, "kind": kind}
		"root":
			var dur := float(params.get("duration", 2.0))
			if stats != null:
				var ctrl := stats.resolve_control("root", dur, control_power)
				if bool(ctrl["resisted"]):
					return {"applied": false, "resisted": true, "kind": kind}
				dur = float(ctrl["duration"])
			entries["root"] = {"t": maxf(float(entries.get("root", {}).get("t", 0.0)), dur)}
			return {"applied": true, "resisted": false, "kind": kind}
		"sunder":
			entries["sunder"] = {
				"armor": maxf(float(entries.get("sunder", {}).get("armor", 0.0)), float(params.get("armor", 5.0))),
				"t": float(params.get("duration", 5.0)),
			}
			return {"applied": true, "resisted": false, "kind": kind}
		"rally":
			entries["rally"] = {
				"haste": float(params.get("haste", 1.3)),
				"damage": float(params.get("damage", 1.25)),
				"t": float(params.get("duration", 6.0)),
			}
			return {"applied": true, "resisted": false, "kind": kind}
		"haste":
			entries["haste"] = {
				"speed": float(params.get("speed", 1.25)),
				"attack_speed": float(params.get("attack_speed", 1.0)),
				"t": maxf(float(entries.get("haste", {}).get("t", 0.0)), float(params.get("duration", 6.0))),
			}
			return {"applied": true, "resisted": false, "kind": kind}
		"enrage":
			entries["enrage"] = {
				"damage": float(params.get("damage", 1.35)),
				"haste": float(params.get("haste", 1.25)),
				"speed": float(params.get("speed", 1.15)),
				"t": maxf(float(entries.get("enrage", {}).get("t", 0.0)), float(params.get("duration", 8.0))),
			}
			return {"applied": true, "resisted": false, "kind": kind}
		"ward":
			entries["ward"] = {
				"reduction": float(params.get("reduction", 0.2)),
				"t": float(params.get("duration", 5.0)),
			}
			return {"applied": true, "resisted": false, "kind": kind}
		"regen":
			entries["regen"] = {
				"hps": float(params.get("hps", 3.0)),
				"t": float(params.get("duration", 6.0)),
			}
			return {"applied": true, "resisted": false, "kind": kind}
		"invulnerable":
			entries["invulnerable"] = {
				"t": maxf(float(entries.get("invulnerable", {}).get("t", 0.0)), float(params.get("duration", 2.5))),
			}
			return {"applied": true, "resisted": false, "kind": kind}
	return {"applied": false, "resisted": false, "kind": kind}


func has(kind: String) -> bool:
	if kind in ["stun", "freeze"]:
		return stun_t > 0.0
	if kind == "paralyze":
		return paralyze_t > 0.0
	return entries.has(kind)


func get_status(kind: String) -> Dictionary:
	return entries.get(kind, {})


func is_incapacitated() -> bool:
	return stun_t > 0.0 or paralyze_t > 0.0


func is_rooted() -> bool:
	return entries.has("root")


func is_invulnerable() -> bool:
	return entries.has("invulnerable")


func tick_control(delta: float) -> void:
	if stun_t > 0.0:
		stun_t = maxf(0.0, stun_t - delta)
	if paralyze_t > 0.0:
		paralyze_t = maxf(0.0, paralyze_t - delta)


## Ticks DoTs, HoTs, and timed status entries. Returns {"dot_damage": float, "heal": float}.
func tick(delta: float, stats: EntityStats = null) -> Dictionary:
	var dot := 0.0
	var heal := 0.0
	for k in ["bleed", "burn"]:
		if entries.has(k):
			var st: Dictionary = entries[k]
			var raw := float(st["dps"]) * delta
			dot += stats.resolve_elemental_damage(raw, k) if stats != null else raw
			st["t"] = float(st["t"]) - delta
			if float(st["t"]) <= 0.0:
				entries.erase(k)
	if entries.has("poison"):
		var stacks: Array = entries["poison"]["stacks"]
		for i in range(stacks.size() - 1, -1, -1):
			var raw := float(stacks[i]["dps"]) * delta
			dot += stats.resolve_elemental_damage(raw, "poison") if stats != null else raw
			stacks[i]["t"] = float(stacks[i]["t"]) - delta
			if float(stacks[i]["t"]) <= 0.0:
				stacks.remove_at(i)
		if stacks.is_empty():
			entries.erase("poison")
	if entries.has("regen"):
		heal += float(entries["regen"].get("hps", 0.0)) * delta
	for k in ["chill", "slow", "root", "sunder", "rally", "haste", "enrage", "ward", "regen", "invulnerable"]:
		if entries.has(k):
			entries[k]["t"] = float(entries[k]["t"]) - delta
			if float(entries[k]["t"]) <= 0.0:
				entries.erase(k)
	return {"dot_damage": dot, "heal": heal}


func armor_reduction() -> float:
	return float(entries.get("sunder", {}).get("armor", 0.0))


func damage_taken_mult() -> float:
	if is_invulnerable():
		return 0.0
	if entries.has("ward"):
		return maxf(0.0, 1.0 - float(entries["ward"].get("reduction", 0.0)))
	return 1.0


func speed_mult() -> float:
	if is_rooted():
		return 0.0
	var m := 1.0 - float(entries.get("chill", {}).get("slow", 0.0))
	if entries.has("slow"):
		m *= 1.0 - float(entries["slow"].get("amount", 0.0))
	m *= float(entries.get("rally", {}).get("haste", 1.0))
	m *= float(entries.get("haste", {}).get("speed", 1.0))
	m *= float(entries.get("enrage", {}).get("speed", 1.0))
	return maxf(0.2, m)


func attack_haste_mult() -> float:
	var h := float(entries.get("rally", {}).get("haste", 1.0))
	h *= float(entries.get("haste", {}).get("attack_speed", 1.0))
	h *= float(entries.get("enrage", {}).get("haste", 1.0))
	return h * (1.0 - float(entries.get("chill", {}).get("slow", 0.0)) * 0.5)


func damage_mult() -> float:
	var m := float(entries.get("rally", {}).get("damage", 1.0))
	m *= float(entries.get("enrage", {}).get("damage", 1.0))
	return m
