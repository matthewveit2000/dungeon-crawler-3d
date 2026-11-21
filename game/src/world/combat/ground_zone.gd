class_name GroundZone
extends Area3D
## Reusable 3D World Combat Primitive: Persistent Floor Hazard / Buff Zone (D-051, D-055).
## Powers future Poison Ground, Glue Floor, Firebomb puddles, and Exploder hazard residue
## using the shared EntityStats & StatusComponent framework.

var zone_id: String = ""
var radius: float = 2.5
var duration: float = 5.0
var remaining: float = 5.0
var tick_interval: float = 0.5
var damage_per_tick: float = 0.0
var damage_type: String = "poison"
var status_kind: String = ""
var status_params: Dictionary = {}
var affects_factions: Array = ["enemy"]
var zone_color: Color = Color(0.28, 0.85, 0.25, 0.55)

var _tick_accum: float = 0.0
var _on_tick_target: Callable = Callable()
var _expired: bool = false


func setup(params: Dictionary, on_tick_target: Callable = Callable()) -> void:
	zone_id = str(params.get("id", "ground_zone"))
	radius = maxf(0.4, float(params.get("radius", 2.5)))
	duration = maxf(0.1, float(params.get("duration", 5.0)))
	remaining = duration
	tick_interval = maxf(0.05, float(params.get("tick_interval", 0.5)))
	damage_per_tick = float(params.get("damage", 0.0))
	damage_type = str(params.get("damage_type", "poison"))
	status_kind = str(params.get("status_kind", ""))
	status_params = (params.get("status_params", {}) as Dictionary).duplicate(true)
	affects_factions = (params.get("affects_factions", ["enemy"]) as Array).duplicate()
	zone_color = Color.html(str(params.get("color", "#48d840")))
	zone_color.a = float(params.get("alpha", 0.5))
	_on_tick_target = on_tick_target

	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 1

	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = 1.2
	col.shape = cyl
	col.position.y = 0.6
	add_child(col)

	var disc := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.06
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = zone_color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = mat
	disc.mesh = mesh
	disc.position.y = 0.04
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)


func _physics_process(delta: float) -> void:
	step_zone(delta)


## Ticks the ground zone. Optional `explicit_targets` allows deterministic headless testing without physics overlap.
func step_zone(delta: float, explicit_targets: Array = []) -> int:
	if _expired:
		return 0
	remaining -= delta
	if remaining <= 0.0:
		_expired = true
		queue_free()
		return 0

	_tick_accum += delta
	if _tick_accum < tick_interval:
		return 0
	_tick_accum -= tick_interval

	var candidates: Array = explicit_targets
	if candidates.is_empty() and is_inside_tree():
		candidates = get_overlapping_bodies()

	var hits := 0
	for body in candidates:
		if not is_instance_valid(body) or not (body is Node3D):
			continue
		var n := body as Node3D
		var flat_dist := Vector2(n.global_position.x - global_position.x, n.global_position.z - global_position.z).length()
		if flat_dist > radius + 0.5:
			continue
		if not _matches_faction(n):
			continue
		_apply_to_target(n)
		hits += 1
	return hits


func _matches_faction(target: Node3D) -> bool:
	if target is CombatActor:
		return affects_factions.has((target as CombatActor).faction)
	if target.is_in_group("player"):
		return affects_factions.has(CombatActor.FACTION_PLAYER)
	if target.is_in_group("enemies"):
		return affects_factions.has(CombatActor.FACTION_ENEMY)
	return false


func _apply_to_target(target: Node3D) -> void:
	if _on_tick_target.is_valid():
		_on_tick_target.call(self, target)
		return
	if target is EnemyActor:
		var ea := target as EnemyActor
		if not ea.is_alive():
			return
		if not status_kind.is_empty():
			ea.apply_status(status_kind, status_params)
		if damage_per_tick > 0.0:
			var eff := ea.entity_stats.resolve_elemental_damage(damage_per_tick, damage_type)
			if eff > 0.0:
				ea.take_damage(eff)
	elif target is PlayerController:
		var pc := target as PlayerController
		if not status_kind.is_empty():
			pc.apply_status(status_kind, status_params)
		if damage_per_tick > 0.0:
			var eff := pc.entity_stats.resolve_elemental_damage(damage_per_tick, damage_type)
			if eff > 0.0:
				pc.take_damage(eff)
