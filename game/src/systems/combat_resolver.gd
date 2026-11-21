class_name CombatResolver
extends RefCounted
## Tier 2/World Coordinator: Extracted Combat Resolution Engine (D-055).
## Owns player melee swings, projectile hits, damage & status application, enemy-to-player hits,
## chain lightning, and floating damage feedback — cleanly decoupled from GameMain.

var game: Node = null  ## GameMain reference


func _init(p_game: Node) -> void:
	game = p_game


func resolve_player_melee_swing(swing: Dictionary) -> void:
	var player: PlayerController = game.player
	var weapon: Dictionary = swing["weapon"]
	var abil: Dictionary = swing.get("abilities", {})
	var is_power := bool(swing["is_power_attack"])
	var reach := float(weapon.get("range_meters", 2.6)) + float(swing.get("dash_distance", 0.0))
	var arc := float(DataLoader.get_player()["combat"]["melee_arc_degrees"])
	if abil.has("cleave"):
		arc = maxf(arc, float(abil["cleave"].get("arc", 150.0)))
	if is_power and abil.has("whirlwind"):
		arc = 360.0
	var half_arc_cos := cos(deg_to_rad(arc * 0.5)) if arc < 359.0 else -2.0
	var fwd := player.get_forward_vector()
	fwd.y = 0.0
	fwd = fwd.normalized()

	var hit_any := false
	for child in game.enemies_root.get_children():
		if not (child is EnemyActor):
			continue
		var enemy := child as EnemyActor
		var delta := enemy.global_position - player.global_position
		delta.y = 0.0
		var dist := delta.length()
		# Reach is measured to the target's body edge, so big enemies (the boss) can't out-range the player
		if dist > reach + maxf(0.6, enemy.body_radius + 0.1):
			continue
		if dist > 0.2 and fwd.dot(delta.normalized()) < half_arc_cos:
			continue
		apply_player_hit_to_enemy(enemy, {
			"base_damage": MasterySystem.stat(weapon, "damage", 16.0),
			"bonus_damage": float(swing["bonus_damage"]),
			"damage_multiplier": float(swing["damage_multiplier"]),
			"is_power_attack": is_power,
			"crit_chance": float(swing["crit_chance"]),
			"crit_multiplier": float(swing["crit_multiplier"]),
			"legendary_effects": swing["legendary_effects"],
			"abilities": abil,
			"item": swing.get("item", {}),
			"melee": true,
			"passives": swing.get("passives", {}),
			"from_dir": delta.normalized(),
		}, str(swing["skill_name"]))
		if is_power and abil.has("knockback") and is_instance_valid(enemy):
			enemy.apply_knockback(delta, float(abil["knockback"].get("force", 6.0)), float(abil["knockback"].get("power", -1.0)))
		hit_any = true

	# Earthbreaker: power attacks shatter the ground around you
	if is_power and abil.has("ground_slam"):
		var gs: Dictionary = abil["ground_slam"]
		var r := float(gs.get("radius", 3.5))
		var burst := VfxFactory.make_impact_burst(Color(0.7, 0.6, 0.45), 46, r)
		game.projectiles_root.add_child(burst)
		burst.global_position = player.global_position + Vector3(0, 0.2, 0)
		for child in game.enemies_root.get_children():
			var e := child as EnemyActor
			if e != null and is_instance_valid(e) and e.global_position.distance_to(player.global_position) <= r:
				apply_player_hit_to_enemy(e, {
					"base_damage": MasterySystem.stat(weapon, "damage", 16.0) * float(gs.get("damage", 0.6)),
					"damage_multiplier": float(swing["damage_multiplier"]),
					"crit_chance": 0.0,
					"item": swing.get("item", {}),
				}, str(swing["skill_name"]))
				if is_instance_valid(e):
					e.apply_knockback(e.global_position - player.global_position, 4.0)
				hit_any = true
		player.add_shake(0.6)

	if hit_any:
		if abil.has("frenzy"):
			player.register_frenzy_hit(abil["frenzy"])
		elif swing.get("passives", {}).has("frenzy"):
			player.register_frenzy_hit(swing["passives"]["frenzy"])
		player.on_melee_hit(bool(swing["is_power_attack"]))
		if EventBus != null:
			EventBus.sfx_requested.emit("sword_hit")


func resolve_projectile_hit(proj: GameProjectile, body: Node3D, hit_pos: Vector3) -> void:
	var player: PlayerController = game.player
	if proj.from_player:
		var abil: Dictionary = proj.abilities
		var item := player.find_item_by_uid(proj.item_uid)
		var hit_params := {
			"base_damage": proj.damage,
			"crit_chance": proj.crit_chance,
			"crit_multiplier": proj.crit_multiplier,
			"legendary_effects": proj.legendary_effects,
			"abilities": abil,
			"item": item,
		}
		if body is EnemyActor:
			var target := body as EnemyActor
			apply_player_hit_to_enemy(target, hit_params, proj.skill_name)
			if abil.has("power_shot") and proj.get_meta("full_draw", false) and is_instance_valid(target):
				target.apply_knockback(proj.velocity, float(abil["power_shot"].get("force", 4.0)))
			# Arc Chain: leap to the nearest enemies not yet struck
			if abil.has("chain") or proj.chain_radius > 0.0:
				var ch: Dictionary = abil.get("chain", {"jumps": 1, "radius": proj.chain_radius, "falloff": 0.65})
				chain_lightning(target, hit_pos, proj.damage, ch, hit_params, proj.skill_name, Color.html("#58c8ff"))
		var splash_r := proj.splash_radius
		var splash_k := 0.55
		if abil.has("explode"):
			splash_r = maxf(splash_r, float(abil["explode"].get("radius", 3.5)))
			splash_k = float(abil["explode"].get("damage", 0.6))
		if splash_r > 0.0:
			var boom := VfxFactory.make_impact_burst(proj._color, 40, splash_r * 1.2)
			game.projectiles_root.add_child(boom)
			boom.global_position = hit_pos
			var sp := hit_params.duplicate()
			sp["base_damage"] = proj.damage * splash_k
			for other in game.enemies_root.get_children():
				if other is EnemyActor and other != body and is_instance_valid(other):
					if (other as EnemyActor).global_position.distance_to(hit_pos) <= splash_r + 0.5:
						apply_player_hit_to_enemy(other as EnemyActor, sp, proj.skill_name)
	else:
		var shooter: Variant = proj.get_meta("shooter", null)
		var sh: EnemyActor = shooter as EnemyActor if is_instance_valid(shooter) else null
		if body == player:
			resolve_enemy_hit_player(sh, proj.damage, false)
		# Goblin bombs burst wherever they land
		elif proj.splash_radius > 0.0 and player.global_position.distance_to(hit_pos) <= proj.splash_radius:
			resolve_enemy_hit_player(sh, proj.damage, false)


func apply_player_hit_to_enemy(enemy: EnemyActor, params: Dictionary, skill_name: String) -> void:
	if enemy == null or not is_instance_valid(enemy) or enemy.state == EnemyActor.AiState.DEAD:
		return
	var player: PlayerController = game.player
	var abil: Dictionary = params.get("abilities", {})
	var item: Dictionary = params.get("item", {})
	var attack_params := params.duplicate(false)
	attack_params.erase("abilities")
	attack_params.erase("item")
	attack_params.erase("passives")
	attack_params["target_armor"] = enemy.effective_armor()
	# Executioner
	if abil.has("execute") and enemy.current_health / maxf(1.0, enemy.max_health) <= float(abil["execute"].get("threshold", 0.3)):
		attack_params["damage_multiplier"] = float(attack_params.get("damage_multiplier", 1.0)) * (1.0 + float(abil["execute"].get("bonus", 0.5)))
	var res := CombatMath.resolve_attack(attack_params, DataLoader.get_player(), game.rng)
	var dmg := float(res["final_damage"])
	var damage_type := str(params.get("damage_type", "physical"))
	if damage_type != "physical":
		dmg = enemy.entity_stats.resolve_elemental_damage(dmg, damage_type)
	# Draugr Shieldwarden: frontal hits glance off the shield unless it is a power attack (D-049 trait)
	if enemy.traits.has("shield_front") and not bool(params.get("is_power_attack", false)):
		var to_player := player.global_position - enemy.global_position
		var facing := enemy.global_transform.basis.z
		if Vector2(facing.x, facing.z).normalized().dot(Vector2(to_player.x, to_player.z).normalized()) > 0.3:
			dmg *= 1.0 - float(enemy.traits["shield_front"].get("reduction", 0.7))
			if EventBus != null:
				EventBus.sfx_requested.emit("shield_block")
	var hit_pos := enemy.global_position + Vector3(0.0, 1.2 if not enemy.is_boss else 2.0, 0.0)
	enemy.set_meta("last_hit_uid", str(item.get("instance_id", "")))
	game._bestiary_sighting(enemy)
	var enemy_level := enemy.level
	enemy.take_damage(dmg)
	# On-hit mastery effects (only while the target lives)
	if is_instance_valid(enemy) and enemy.state != EnemyActor.AiState.DEAD:
		for k in ["bleed", "burn", "poison", "chill", "sunder"]:
			if abil.has(k):
				enemy.apply_status(k, abil[k])
		if abil.has("fire_arrows"):
			enemy.apply_status("burn", abil["fire_arrows"])
		for k in ["freeze", "stun"]:
			if abil.has(k) and game.rng.next_float("combat") < float(abil[k].get("chance", 0.15)):
				enemy.apply_status(k, abil[k])
		var pas: Dictionary = params.get("passives", {})
		if bool(params.get("melee", false)) and pas.has("ember_touch"):
			enemy.apply_status("burn", pas["ember_touch"])
	var heal_frac := float(abil.get("lifesteal", {}).get("fraction", 0.0)) + float(abil.get("siphon", {}).get("fraction", 0.0))
	if bool(params.get("melee", false)):
		heal_frac += float(params.get("passives", {}).get("blood_pact", {}).get("fraction", 0.0))
	if heal_frac > 0.0:
		player.health = minf(player.max_health, player.health + dmg * heal_frac)
	if not item.is_empty():
		game.grant_item_xp(item, "hit", enemy_level)
	if game.hud != null:
		game.hud.trigger_hit_marker()
	spawn_hit_feedback(hit_pos, dmg, bool(res.get("is_crit", false)))

	# Skyrim use-to-improve proficiency gain on landing a hit!
	var s_res: Dictionary = game.progression.record_skill_use(skill_name)
	if bool(s_res.get("skill_leveled_up", false)) and EventBus != null:
		EventBus.skill_improved.emit(skill_name, int(s_res["new_skill_level"]))
	for lvl in s_res.get("char_levels_gained", []):
		if EventBus != null:
			EventBus.level_up_occurred.emit(int(lvl))

	# Legendary Blast Wave on critical hits
	if bool(res["trigger_explosive_crits"]):
		var eff := DataLoader.get_legendary_effect_def("explosive_crits")
		var aoe_r := float(eff.get("aoe_radius", 3.5))
		var aoe_d := float(eff.get("bonus_aoe_damage", 14.0))
		for other in game.enemies_root.get_children():
			if other is EnemyActor and is_instance_valid(other):
				if (other as EnemyActor).global_position.distance_to(enemy.global_position) <= aoe_r:
					(other as EnemyActor).take_damage(aoe_d)


## An enemy's blow or shot reaching the crawler: blocks, shield & armor mastery effects and enemy traits (D-049).
func resolve_enemy_hit_player(e: EnemyActor, dmg: float, melee: bool) -> void:
	var player: PlayerController = game.player
	var res := player.take_damage(dmg)
	if bool(res.get("dodged", false)):
		return
	var alive := e != null and is_instance_valid(e) and e.state != EnemyActor.AiState.DEAD
	var guard := player.blocking_item() if bool(res.get("was_blocked", false)) else {}
	if not guard.is_empty():
		game.grant_item_xp(guard, "block", e.level if alive else 1)
		var ga := MasterySystem.abilities(guard)
		if alive and melee and ga.has("bash"):
			e.apply_status("stun", {"duration": float(ga["bash"].get("duration", 0.8))})
		if alive and melee and ga.has("reflect"):
			e.take_damage(dmg * float(ga["reflect"].get("fraction", 0.3)))
	else:
		for slot in player.equipment.keys():
			if not str(slot).ends_with("_hand"):
				game.grant_item_xp(player.equipment[slot], "hit_taken", e.level if alive else 1)
	alive = e != null and is_instance_valid(e) and e.state != EnemyActor.AiState.DEAD
	if not alive:
		return
	var pas: Dictionary = LootGenerator.aggregate_equipment_stats(player.equipment).get("passives", {})
	if melee and pas.has("thorns"):
		e.take_damage(float(pas["thorns"].get("damage", 5.0)))
	if not is_instance_valid(e) or e.state == EnemyActor.AiState.DEAD:
		return
	var taken := float(res.get("final_damage", 0.0))
	if e.traits.has("frost_strike") and taken > 0.0:
		player.apply_slow(float(e.traits["frost_strike"].get("slow", 0.4)), float(e.traits["frost_strike"].get("duration", 2.5)))
	if e.traits.has("hex_bolt") and taken > 0.0:
		player.apply_slow(float(e.traits["hex_bolt"].get("slow", 0.3)), float(e.traits["hex_bolt"].get("duration", 2.5)))
	if e.traits.has("lifedrain") and taken > 0.0:
		e.current_health = minf(e.max_health, e.current_health + taken * float(e.traits["lifedrain"].get("fraction", 0.5)))


## Arc Chain: lightning leaps from `first` to up to `jumps` nearby enemies, losing `falloff` each jump.
func chain_lightning(first: EnemyActor, from_pos: Vector3, damage: float, ch: Dictionary, hit_params: Dictionary, skill_name: String, col: Color) -> int:
	var struck: Array = [first]
	var cur_pos := from_pos
	var dmg := damage
	var hits := 0
	for _j in range(int(ch.get("jumps", 1))):
		dmg *= float(ch.get("falloff", 0.7))
		var best: EnemyActor = null
		var best_d := float(ch.get("radius", 6.0))
		for other in game.enemies_root.get_children():
			var o := other as EnemyActor
			if o == null or not is_instance_valid(o) or struck.has(o) or o.state == EnemyActor.AiState.DEAD:
				continue
			var d := o.global_position.distance_to(cur_pos)
			if d <= best_d:
				best = o
				best_d = d
		if best == null:
			break
		struck.append(best)
		var to := best.global_position + Vector3(0, 1.2, 0)
		var arc := VfxFactory.make_impact_burst(col, 16, 2.0)
		game.projectiles_root.add_child(arc)
		arc.global_position = to
		var p := hit_params.duplicate()
		p["base_damage"] = dmg
		apply_player_hit_to_enemy(best, p, skill_name)
		cur_pos = to
		hits += 1
	return hits


func spawn_hit_feedback(pos: Vector3, dmg: float, crit: bool) -> void:
	if not game.is_inside_tree():
		return
	var burst := VfxFactory.make_impact_burst(Color(1.0, 0.75, 0.4) if not crit else Color(1.0, 0.9, 0.3), 18 if not crit else 34, 3.6)
	game.projectiles_root.add_child(burst)
	burst.global_position = pos
	if GameSettings != null and not bool(GameSettings.get_value("gameplay", "show_damage_numbers")):
		return
	var lbl := Label3D.new()
	lbl.text = ("%d!" if crit else "%d") % int(round(dmg))
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.font_size = 64 if crit else 44
	lbl.pixel_size = 0.004
	lbl.outline_size = 12
	lbl.modulate = Color(1.0, 0.86, 0.3) if crit else Color(1.0, 0.95, 0.88)
	lbl.outline_modulate = Color(0.1, 0.02, 0.0, 0.9)
	if UiTheme.font_heading() != null:
		lbl.font = UiTheme.font_heading()
	game.projectiles_root.add_child(lbl)
	var jitter := Vector3(game.rng.next_float_range("ai", -0.3, 0.3), 0.0, game.rng.next_float_range("ai", -0.3, 0.3))
	lbl.global_position = pos + jitter
	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position", lbl.global_position + Vector3(0, 0.9, 0), 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.9).set_delay(0.35)
	tw.chain().tween_callback(lbl.queue_free)
