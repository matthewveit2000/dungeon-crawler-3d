class_name ActorLocomotion
extends RefCounted
## Modular Actor Locomotion component (D-055).
## Supports pluggable movement modes for enemies, bosses, summons, and companions:
## - MODE_GROUND: A* tile pathfinding around walls/props + shoulder-sweep walk-clear + stuck sidestep + room wander.
## - MODE_FLYING: 3D hover & direct aerial dive (ready for Flying Exploders & Slappy the Bat).
## - MODE_KITER:  Panic-radius sprint-away along clear/A* escape paths (ready for Crag Goblin Skirmishers).

const MODE_GROUND := "ground"
const MODE_FLYING := "flying"
const MODE_KITER := "kiter"

var mode: String = MODE_GROUND
var hover_height: float = 1.8
var panic_radius: float = 7.0
var kiter_flee_mult: float = 1.35

# Pathfinding & unstick state (FB-014)
var path: Array[Vector2i] = []
var path_i: int = 0
var path_goal: Vector2i = Vector2i(-9999, -9999)
var repath_t: float = 0.0
var stuck_t: float = 0.0
var sidestep_t: float = 0.0
var sidestep_dir: Vector3 = Vector3.ZERO
var last_pos: Vector3 = Vector3.ZERO
var walk_timer: float = 0.0
var walk_cached: bool = true

# Idle wander state (D-046)
var wander_target: Vector3 = Vector3.INF
var wander_pause: float = 0.0


func reset_wander(pause_sec: float = 0.0) -> void:
	wander_target = Vector3.INF
	wander_pause = pause_sec


func clear_path() -> void:
	path.clear()


## Computes movement direction toward `target` using direct clear-view movement or A* tile pathfinding,
## with stuck detection & sidestep unsticking (preserves exact FB-014 ground steering).
func steer_toward(
	actor: CharacterBody3D,
	target: Vector3,
	dist: float,
	delta: float,
	move_speed: float,
	body_radius: float,
	layout: DungeonGenerator.FloorLayout,
	target_ref: Node3D,
	rng: SeededRng
) -> Vector3:
	if mode == MODE_FLYING:
		var desired := target + Vector3(0.0, hover_height, 0.0) - actor.global_position
		return desired.normalized() if desired.length_squared() > 0.0004 else Vector3.ZERO

	var flat := Vector3(target.x - actor.global_position.x, 0.0, target.z - actor.global_position.z)
	var moved := Vector2(actor.global_position.x - last_pos.x, actor.global_position.z - last_pos.z).length()
	last_pos = actor.global_position
	stuck_t = stuck_t + delta if moved < move_speed * delta * 0.25 else maxf(0.0, stuck_t - delta * 2.0)
	if sidestep_t > 0.0:
		sidestep_t -= delta
		return sidestep_dir
	if stuck_t > 0.8:
		stuck_t = 0.0
		sidestep_t = 0.45
		var side := Vector3(-flat.z, 0.0, flat.x).normalized()
		sidestep_dir = side * (1.0 if (rng == null or rng.next_float("ai") < 0.5) else -1.0)
		path.clear()
		return sidestep_dir
	var my_t := layout.world_to_tile(actor.global_position) if layout != null else Vector2i.ZERO
	var goal_t := layout.world_to_tile(target) if layout != null else Vector2i.ZERO
	var tile_gap := absi(goal_t.x - my_t.x) + absi(goal_t.y - my_t.y)
	if layout == null or tile_gap > 40 or (dist < 9.0 and is_walk_clear(actor, target, delta, body_radius, target_ref)):
		path.clear()
		return flat.normalized() if flat.length() > 0.01 else Vector3.ZERO
	repath_t -= delta
	if path.is_empty() or goal_t != path_goal or repath_t <= 0.0:
		path = layout.find_path(my_t, goal_t)
		path_i = 1
		path_goal = goal_t
		repath_t = 0.6 + (float(actor.get_instance_id() % 7) * 0.03)
	while path_i < path.size():
		var wp := layout.tile_to_world(path[path_i])
		if Vector2(wp.x - actor.global_position.x, wp.z - actor.global_position.z).length() > 0.7:
			var d := Vector3(wp.x - actor.global_position.x, 0.0, wp.z - actor.global_position.z)
			return d.normalized()
		path_i += 1
	return flat.normalized() if flat.length() > 0.01 else Vector3.ZERO


## Computes an escape direction away from `threat_pos` for kiter actors (prefers open tiles when layout exists).
func steer_away(actor: CharacterBody3D, threat_pos: Vector3, layout: DungeonGenerator.FloorLayout) -> Vector3:
	var away := Vector3(actor.global_position.x - threat_pos.x, 0.0, actor.global_position.z - threat_pos.z)
	if away.length_squared() < 0.001:
		away = Vector3.FORWARD
	away = away.normalized()
	if layout == null:
		return away
	var best_dir := away
	var best_score := -INF
	for ang in [0.0, 0.55, -0.55, 1.1, -1.1]:
		var cand := away.rotated(Vector3.UP, ang)
		var probe := actor.global_position + cand * layout.tile_size
		var pt := layout.world_to_tile(probe)
		if layout.is_walkable(pt.x, pt.y) and not layout.is_world_in_safe_room(probe):
			var score := cand.dot(away)
			if score > best_score:
				best_score = score
				best_dir = cand
	return best_dir


## True when a body-height sweep (centre + both shoulders) to `target` hits no wall or prop.
func is_walk_clear(actor: CharacterBody3D, target: Vector3, delta: float, body_radius: float, target_ref: Node3D) -> bool:
	walk_timer -= delta
	if walk_timer > 0.0:
		return walk_cached
	walk_timer = 0.25
	if not actor.is_inside_tree():
		walk_cached = true
		return true
	var space := actor.get_world_3d().direct_space_state
	var to := Vector3(target.x, actor.global_position.y, target.z) - actor.global_position
	var side := Vector3(-to.z, 0.0, to.x).normalized() * maxf(0.3, body_radius * 0.85)
	var ex: Array[RID] = [actor.get_rid()]
	if target_ref is CollisionObject3D:
		ex.append((target_ref as CollisionObject3D).get_rid())
	walk_cached = true
	for off in [Vector3.ZERO, side, -side]:
		var a: Vector3 = actor.global_position + Vector3(0.0, 0.45, 0.0) + off
		var q := PhysicsRayQueryParameters3D.create(a, a + to, 1)
		q.exclude = ex
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and not (hit.get("collider") is CombatActor):
			walk_cached = false
			break
	return walk_cached


## Steps idle room wandering (exact D-046 behavior). Returns desired facing direction (Vector3.ZERO if idle).
func step_wander(
	actor: CharacterBody3D,
	delta: float,
	move_speed: float,
	room_id: int,
	spawn_pos: Vector3,
	layout: DungeonGenerator.FloorLayout,
	rng: SeededRng
) -> Vector3:
	var speed := 0.0
	var face_vec := Vector3.ZERO
	if wander_pause > 0.0:
		wander_pause -= delta
		actor.velocity.x = 0.0
		actor.velocity.z = 0.0
	else:
		if wander_target == Vector3.INF:
			wander_target = pick_wander_target(actor.global_position.y, room_id, spawn_pos, layout, rng)
		var to_t := wander_target - actor.global_position
		to_t.y = 0.0
		if to_t.length() < 0.6:
			wander_target = Vector3.INF
			wander_pause = rng.next_float_range("ai", 1.2, 3.8) if rng != null else 2.0
			actor.velocity.x = 0.0
			actor.velocity.z = 0.0
		else:
			speed = move_speed * 0.38
			var dir := to_t.normalized()
			actor.velocity.x = dir.x * speed
			actor.velocity.z = dir.z * speed
			face_vec = to_t
	actor.velocity.y = 0.0 if mode == MODE_FLYING else (-4.0 if not actor.is_on_floor() else 0.0)
	actor.move_and_slide()
	if speed > 0.0 and actor.get_real_velocity().length() < speed * 0.2:
		wander_target = Vector3.INF
		wander_pause = 0.6
	return face_vec


func pick_wander_target(y_height: float, room_id: int, spawn_pos: Vector3, layout: DungeonGenerator.FloorLayout, rng: SeededRng) -> Vector3:
	if layout == null:
		return spawn_pos
	var room := layout.get_room(room_id)
	if room.is_empty():
		return spawn_pos
	var rect: Rect2i = room["rect"]
	var inner := rect.grow(-1) if rect.size.x > 2 and rect.size.y > 2 else rect
	var tx := rng.next_int_range("ai", inner.position.x, inner.end.x - 1) if rng != null else inner.position.x
	var ty := rng.next_int_range("ai", inner.position.y, inner.end.y - 1) if rng != null else inner.position.y
	var jitter := Vector3(rng.next_float_range("ai", -1.2, 1.2), 0.0, rng.next_float_range("ai", -1.2, 1.2)) if rng != null else Vector3.ZERO
	return layout.tile_to_world(Vector2i(tx, ty)) + jitter + Vector3(0.0, y_height, 0.0)
