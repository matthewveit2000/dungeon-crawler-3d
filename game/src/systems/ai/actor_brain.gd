class_name ActorBrain
extends RefCounted
## Modular Actor AI Brain component (D-055).
## Owns awareness/LOS caching, aggro/leash evaluation, and a data-driven Utility-Scoring selector
## ready for Adaptive Random-Spell Casters (Runebound Arcanist) and smart Summons/Companions.

const BRAIN_STANDARD := "standard"
const BRAIN_KITER := "kiter"
const BRAIN_UTILITY := "utility"

const HEARING_RADIUS := 6.0
const LOSE_SIGHT_SEC := 4.0
const LEASH_MULT := 2.2

var brain_kind: String = BRAIN_STANDARD
var unseen_t: float = 0.0
var los_timer: float = 0.0
var los_cached: bool = false


## Line of sight from `actor` to `target_ref` through world geometry (cached for 0.2 s, exact D-046 behavior).
func sees_target(actor: CharacterBody3D, target_ref: Node3D, delta: float) -> bool:
	los_timer -= delta
	if los_timer > 0.0:
		return los_cached
	los_timer = 0.2
	if not actor.is_inside_tree() or target_ref == null:
		los_cached = false
		return false
	var from := actor.global_position + Vector3(0.0, 1.5, 0.0)
	var to := target_ref.global_position + Vector3(0.0, 1.3, 0.0)
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	q.exclude = [actor.get_rid(), (target_ref as CollisionObject3D).get_rid()] if target_ref is CollisionObject3D else [actor.get_rid()]
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(q)
	los_cached = hit.is_empty() or hit.get("collider") == target_ref
	return los_cached


func should_engage(dist: float, aggro_radius: float, actor: CharacterBody3D, target_ref: Node3D, delta: float) -> bool:
	if dist <= HEARING_RADIUS:
		return true
	return dist <= aggro_radius and sees_target(actor, target_ref, delta)


func should_disengage(dist: float, aggro_radius: float, is_boss: bool, actor: CharacterBody3D, target_ref: Node3D, delta: float) -> bool:
	if is_boss:
		return false
	unseen_t = 0.0 if sees_target(actor, target_ref, delta) else unseen_t + delta
	return unseen_t > LOSE_SIGHT_SEC or dist > aggro_radius * LEASH_MULT


## Utility-Scoring Decision Engine (D-051 / D-052): evaluates candidate spells/abilities against combat context
## and returns the highest-scoring executable action (or {} if none can be used).
##
## `context` keys:
##   hp_ratio (float), magicka (float), target_dist (float), target_in_los (bool),
##   hurt_ally_nearby (bool), cooldowns (Dictionary: action_id -> remaining sec)
## Each candidate in `actions`:
##   {"id": String, "role": "offense"|"heal"|"ward"|"escape"|"control"|"zone"|"ally_heal",
##    "magicka_cost": float, "min_range": float, "max_range": float, "priority": float}
static func pick_utility_action(context: Dictionary, actions: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_score := 0.0
	var hp_ratio := float(context.get("hp_ratio", 1.0))
	var magicka := float(context.get("magicka", 0.0))
	var dist := float(context.get("target_dist", 10.0))
	var los := bool(context.get("target_in_los", true))
	var hurt_ally := bool(context.get("hurt_ally_nearby", false))
	var cds: Dictionary = context.get("cooldowns", {})

	for raw in actions:
		var a: Dictionary = raw
		var aid := str(a.get("id", ""))
		if float(cds.get(aid, 0.0)) > 0.0:
			continue
		if float(a.get("magicka_cost", 0.0)) > magicka:
			continue
		var min_r := float(a.get("min_range", 0.0))
		var max_r := float(a.get("max_range", 999.0))
		var role := str(a.get("role", "offense"))
		if role in ["offense", "control", "zone"] and (not los or dist < min_r or dist > max_r):
			continue
		var score := float(a.get("priority", 1.0))
		match role:
			"heal":
				score *= (1.0 - hp_ratio) * 2.8 if hp_ratio < 0.65 else 0.05
			"ward":
				score *= 1.8 if hp_ratio < 0.75 else 0.3
			"escape":
				score *= 2.5 if dist <= maxf(4.5, min_r + 2.0) else 0.0
			"control":
				score *= 1.6 if dist <= 10.0 else 0.7
			"zone":
				score *= 1.35 if dist >= 3.0 and dist <= max_r else 0.3
			"ally_heal":
				score *= 2.2 if hurt_ally else 0.0
			_:
				score *= 1.15
		if score > best_score:
			best_score = score
			best = a
	return best
