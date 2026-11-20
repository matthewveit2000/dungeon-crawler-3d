class_name GameProjectile
extends Area3D
## 3D Projectile for Archery Arrows and Destruction Spells (Firebolt AoE & Chain Spark).

var velocity: Vector3 = Vector3.ZERO
var projectile_gravity: float = 0.0
var damage: float = 15.0
var crit_chance: float = 0.08
var crit_multiplier: float = 1.65
var from_player: bool = true
var skill_name: String = "archery"
var splash_radius: float = 0.0
var chain_radius: float = 0.0
var sponsored_effects: Array = []
## D-049 mastery: on-hit abilities of the item that fired this, the item's instance id (for mastery XP),
## shots that pass through enemies, and seekers that curve toward the nearest enemy
var abilities: Dictionary = {}
var item_uid: String = ""
var pierce_left: int = 0
var homing_turn: float = 0.0
var hit_bodies: Array = []
## Bullet time (Hunter's Focus) slows every projectile except the player's own
static var world_time_scale: float = 1.0
var lifetime: float = 4.5
var _hit_callback: Callable = Callable()
var _expired: bool = false
var _kind: String = "arrow"
var _color: Color = Color(1.0, 0.5, 0.2)


func setup(params: Dictionary, hit_callback: Callable) -> void:
	velocity = params.get("velocity", Vector3.FORWARD * 25.0)
	projectile_gravity = float(params.get("gravity", 0.0))
	damage = float(params.get("damage", 15.0))
	crit_chance = float(params.get("crit_chance", 0.08))
	crit_multiplier = float(params.get("crit_multiplier", 1.65))
	from_player = bool(params.get("from_player", true))
	skill_name = str(params.get("skill_name", "archery"))
	splash_radius = float(params.get("splash_radius", 0.0))
	chain_radius = float(params.get("chain_radius", 0.0))
	sponsored_effects = params.get("sponsored_effects", [])
	abilities = params.get("abilities", {})
	item_uid = str(params.get("item_uid", ""))
	pierce_left = int(params.get("pierce", 0))
	homing_turn = float(params.get("homing", 0.0))
	_hit_callback = hit_callback

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.22
	shape.shape = sphere
	add_child(shape)

	var kind := str(params.get("kind", "arrow"))
	_kind = kind
	if kind == "bomb":
		lifetime = 6.0
	if kind == "arrow":
		var mesh_node := ModelLoader.instantiate_model("res://assets/models/gear/arrow.glb", Vector3(0.03, 0.75, 0.03), Color(0.65, 0.5, 0.35))
		# arrow model points +Y; projectile looks down -Z
		mesh_node.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		add_child(mesh_node)
	else:
		_color = Color.html(str(params.get("color", "#ff6a22")))
		add_child(VfxFactory.make_glow(_color.lightened(0.45), 0.26, 2.6))
		add_child(VfxFactory.make_glow(_color, 0.75, 1.1))
		var aura := VfxFactory.make_magic_aura(_color, 0.12, 30)
		aura.local_coords = false
		add_child(aura)
		var fire := VfxFactory.make_fire(0.35, false)
		fire.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		add_child(fire)
		var light := OmniLight3D.new()
		light.light_color = _color
		light.light_energy = 2.2
		light.omni_range = 7.0
		light.shadow_enabled = false
		add_child(light)

	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _expired:
		return
	lifetime -= delta
	if lifetime <= 0.0:
		_expire()
		return
	if not from_player:
		delta *= world_time_scale
	velocity.y -= projectile_gravity * delta
	if homing_turn > 0.0 and is_inside_tree():
		var best: Node3D = null
		var best_d := 26.0
		for n in get_tree().get_nodes_in_group("enemies"):
			var e := n as Node3D
			if e == null or hit_bodies.has(e):
				continue
			var to := e.global_position + Vector3(0, 1.1, 0) - global_position
			var d := to.length()
			if d < best_d and to.normalized().dot(velocity.normalized()) > 0.2:
				best = e
				best_d = d
		if best != null:
			var want := (best.global_position + Vector3(0, 1.1, 0) - global_position).normalized() * velocity.length()
			velocity = velocity.lerp(want, clampf(homing_turn * delta, 0.0, 1.0))
	global_position += velocity * delta
	if velocity.length_squared() > 0.05:
		look_at(global_position + velocity.normalized(), Vector3.UP)


func _on_body_entered(body: Node3D) -> void:
	if _expired:
		return
	if from_player and body.is_in_group("player"):
		return
	if not from_player and body.is_in_group("enemies"):
		return
	if hit_bodies.has(body):
		return
	hit_bodies.append(body)
	if _hit_callback.is_valid():
		_hit_callback.call(self, body, global_position)
	if from_player and pierce_left > 0 and body.is_in_group("enemies"):
		pierce_left -= 1  # Piercing: keep flying through to the next enemy
		return
	if is_inside_tree() and get_parent() != null:
		var burst := VfxFactory.make_impact_burst(_color if _kind != "arrow" else Color(1.0, 0.8, 0.5), 26 if _kind != "arrow" else 12, 4.0)
		get_parent().add_child(burst)
		burst.global_position = global_position
	_expire()


func _expire() -> void:
	if _expired:
		return
	_expired = true
	queue_free()
