class_name Barrier
extends StaticBody3D
## Reusable 3D World Combat Primitive: Temporary Wall & One-Way Shield Barrier (D-051, D-055).
## Supports solid Stone Barricades (IDEA-006) and One-Way Front Shields (IDEA-012) where
## enemy attacks/projectiles are blocked while only the owner's spells and arrows pass through.

var barrier_id: String = ""
var owner_faction: String = CombatActor.FACTION_PLAYER
var one_way_for_owner_projectiles: bool = false
var allowed_projectile_kinds: Array = ["spell", "arrow"]
var duration: float = 6.0
var remaining: float = 6.0
var max_health: float = 120.0
var current_health: float = 120.0
var barrier_size: Vector3 = Vector3(2.8, 2.4, 0.35)
var barrier_color: Color = Color(0.45, 0.78, 1.0, 0.45)

var _on_broken: Callable = Callable()
var _expired: bool = false


func setup(params: Dictionary, on_broken: Callable = Callable()) -> void:
	barrier_id = str(params.get("id", "barrier"))
	owner_faction = str(params.get("owner_faction", CombatActor.FACTION_PLAYER))
	one_way_for_owner_projectiles = bool(params.get("one_way_for_owner_projectiles", false))
	if params.has("allowed_projectile_kinds"):
		allowed_projectile_kinds = (params["allowed_projectile_kinds"] as Array).duplicate()
	duration = maxf(0.1, float(params.get("duration", 6.0)))
	remaining = duration
	max_health = maxf(1.0, float(params.get("max_health", 120.0)))
	current_health = max_health
	if params.has("size"):
		var sv: Variant = params["size"]
		if sv is Vector3:
			barrier_size = sv
		elif sv is Array and (sv as Array).size() >= 3:
			barrier_size = Vector3(float(sv[0]), float(sv[1]), float(sv[2]))
	barrier_color = Color.html(str(params.get("color", "#66c2ff")))
	barrier_color.a = float(params.get("alpha", 0.42 if one_way_for_owner_projectiles else 0.92))
	_on_broken = on_broken

	collision_layer = 1
	collision_mask = 1

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = barrier_size
	col.shape = box
	col.position.y = barrier_size.y * 0.5
	add_child(col)

	var mesh_inst := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = barrier_size
	var mat := StandardMaterial3D.new()
	if one_way_for_owner_projectiles:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = barrier_color
	bm.material = mat
	mesh_inst.mesh = bm
	mesh_inst.position.y = barrier_size.y * 0.5
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if one_way_for_owner_projectiles else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mesh_inst)


func _physics_process(delta: float) -> void:
	step_barrier(delta)


func step_barrier(delta: float) -> void:
	if _expired:
		return
	remaining -= delta
	if remaining <= 0.0:
		_break_barrier("expired")


## True if a projectile should pass straight through this barrier (IDEA-012 One-Way Shield).
func allows_projectile(from_player: bool, projectile_kind: String) -> bool:
	if not one_way_for_owner_projectiles:
		return false
	var is_owner := (owner_faction == CombatActor.FACTION_PLAYER and from_player) \
		or (owner_faction == CombatActor.FACTION_ENEMY and not from_player)
	if not is_owner:
		return false
	return allowed_projectile_kinds.is_empty() or allowed_projectile_kinds.has(projectile_kind)


func take_damage(amount: float) -> bool:
	if _expired or amount <= 0.0:
		return false
	current_health = maxf(0.0, current_health - amount)
	if current_health <= 0.0:
		_break_barrier("destroyed")
		return true
	return false


func _break_barrier(reason: String) -> void:
	if _expired:
		return
	_expired = true
	collision_layer = 0
	if _on_broken.is_valid():
		_on_broken.call(self, reason)
	queue_free()
