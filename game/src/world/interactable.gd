class_name InteractableObject
extends StaticBody3D
## Unified Skyrim-style world interactable (Chests, Crates, Urns, Levers, Vendor, Quest Board, Staircase, Corpses).
## Visual feedback: chest lids swing open, levers throw, urns tip, searched containers dim slightly.

var interact_id: String = ""
var kind: String = "chest"
var prompt_label: String = "Interact"
var payload: Dictionary = {}
var consumed: bool = false
var visual_root: Node3D = null
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


## Short verb + noun for the HUD interaction prompt (e.g. "Open" / "Iron-Bound Chest").
func get_prompt_parts() -> Dictionary:
	if consumed:
		return {}
	var words := prompt_label.split(" ", false, 1)
	if words.size() == 2:
		return {"verb": words[0], "target": words[1], "kind": kind}
	return {"verb": "Use", "target": prompt_label, "kind": kind}


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
	var root := visual_root if visual_root != null else self
	var lid := root.find_child("Lid*", true, false) as Node3D if root != null else null
	var animate := is_inside_tree()
	match kind:
		"chest":
			if lid != null:
				if animate:
					var tw := create_tween()
					tw.tween_property(lid, "rotation:x", deg_to_rad(-108.0), 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				else:
					lid.rotation.x = deg_to_rad(-108.0)
		"lever":
			var target := root
			if animate:
				var tw2 := create_tween()
				tw2.tween_property(target, "rotation:x", target.rotation.x + deg_to_rad(40.0), 0.35).set_trans(Tween.TRANS_CUBIC)
			else:
				target.rotation.x += deg_to_rad(40.0)
		"urn":
			if animate:
				var tw3 := create_tween()
				tw3.tween_property(root, "rotation:z", deg_to_rad(9.0), 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			else:
				root.rotation.z = deg_to_rad(9.0)
		_:
			pass
