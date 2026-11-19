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
var lifetime: float = 4.5
var _hit_callback: Callable = Callable()
var _expired: bool = false


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
	_hit_callback = hit_callback

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.22
	shape.shape = sphere
	add_child(shape)

	var kind := str(params.get("kind", "arrow"))
	if kind == "arrow":
		var mesh_node := ModelLoader.instantiate_model("res://assets/models/batch2/arrow.glb", Vector3(0.08, 0.08, 0.8), Color(0.65, 0.5, 0.35))
		mesh_node.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		add_child(mesh_node)
	else:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.20
		sm.height = 0.40
		var mat := StandardMaterial3D.new()
		var col := Color.html(str(params.get("color", "#ff6a22")))
		mat.albedo_color = col
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = 3.5
		sm.material = mat
		mi.mesh = sm
		add_child(mi)
		var light := OmniLight3D.new()
		light.light_color = col
		light.light_energy = 2.0
		light.omni_range = 6.0
		add_child(light)

	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _expired:
		return
	lifetime -= delta
	if lifetime <= 0.0:
		_expire()
		return
	velocity.y -= projectile_gravity * delta
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
	if _hit_callback.is_valid():
		_hit_callback.call(self, body, global_position)
	_expire()


func _expire() -> void:
	if _expired:
		return
	_expired = true
	queue_free()
