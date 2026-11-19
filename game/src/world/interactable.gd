class_name InteractableObject
extends StaticBody3D
## Unified Skyrim-style world interactable (Chests, Crates, Urns, Levers, Vendor, Quest Board, Staircase, Corpses).

var interact_id: String = ""
var kind: String = "chest"
var prompt_label: String = "Interact"
var payload: Dictionary = {}
var consumed: bool = false
var _callback: Callable = Callable()


func setup(p_id: String, p_kind: String, p_prompt: String, p_payload: Dictionary, cb: Callable, collider_size: Vector3 = Vector3(1.2, 1.2, 1.2)) -> void:
	interact_id = p_id
	kind = p_kind
	prompt_label = p_prompt
	payload = p_payload.duplicate(true)
	_callback = cb
	add_to_group("interactables")
	collision_layer = 3  # World + Interactable raycast bit
	collision_mask = 1

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = collider_size
	col.shape = box
	col.position.y = collider_size.y * 0.5
	add_child(col)


func get_prompt() -> String:
	if consumed:
		return ""
	return "[E] %s" % prompt_label


func trigger(interactor: Node3D) -> bool:
	if consumed:
		return false
	if _callback.is_valid():
		var ok := bool(_callback.call(self, interactor))
		if ok and kind in ["chest", "crate", "urn", "corpse", "lever"]:
			consumed = true
			_apply_consumed_visual()
		return ok
	return false


func _apply_consumed_visual() -> void:
	# Subtle visual confirmation that container/lever/corpse has been looted or pulled
	if kind == "lever":
		rotation_degrees.x += 22.0
	elif kind in ["chest", "crate", "urn", "corpse"]:
		scale = Vector3(0.95, 0.72, 0.95)
