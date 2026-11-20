class_name CharacterVisual
extends Node3D
## Animated character presentation wrapper around a rigged Blender .glb
## (game/assets/models/characters/<kind>.glb). Provides smooth cross-faded locomotion states,
## one-shot actions (attacks, hits, casts, deaths), bone attachments for weapons, hit flashes,
## and a graceful procedural fallback if a model has no animations.

const CHAR_DIR := "res://assets/models/characters/"
const LOOPING := ["idle", "walk", "run", "block", "draw_hold", "idle_combat", "cast_hold", "dormant", "talk"]

var kind: String = ""
var model: Node3D = null
var anim: AnimationPlayer = null
var skeleton: Skeleton3D = null
var state: String = ""
var oneshot: String = ""
var speed_scale: float = 1.0
var _flash_t: float = 0.0
## Additive hit-flash strength (linear light: 0.08 already reads as a clear warm pulse on dark models;
## 0.2+ turns them into pale silhouettes)
const FLASH_ALPHA := 0.08
var _flash_mats: Array = []
var _fallback_t: float = 0.0
var _dead: bool = false


static func create(p_kind: String) -> CharacterVisual:
	var cv := CharacterVisual.new()
	cv.name = "Visual_%s" % p_kind
	cv.kind = p_kind
	cv.model = ModelLoader.instantiate_model(CHAR_DIR + p_kind + ".glb", Vector3(0.7, 1.8, 0.5), Color(0.5, 0.45, 0.4))
	cv.add_child(cv.model)
	cv.anim = cv.model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	cv.skeleton = _find_skeleton(cv.model)
	if cv.anim != null:
		for an in cv.anim.get_animation_list():
			var a := cv.anim.get_animation(an)
			if a == null:
				continue
			var base := str(an).get_slice("/", str(an).get_slice_count("/") - 1)
			a.loop_mode = Animation.LOOP_LINEAR if base in LOOPING else Animation.LOOP_NONE
		cv.anim.animation_finished.connect(cv._on_anim_finished)
		cv.anim.playback_default_blend_time = 0.18
	return cv


static func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var s := _find_skeleton(c)
		if s != null:
			return s
	return null


func has_anim(anim_name: String) -> bool:
	return anim != null and anim.has_animation(anim_name)


## Looping state (idle / walk / run / block / ...), cross-faded.
func play_state(new_state: String, blend: float = 0.2, p_speed: float = 1.0) -> void:
	if _dead:
		return
	speed_scale = p_speed
	if anim != null and oneshot.is_empty():
		anim.speed_scale = p_speed
	if new_state == state:
		return
	state = new_state
	if not oneshot.is_empty():
		return
	if has_anim(new_state):
		anim.play(new_state, blend)


## One-shot action (attack / hit / cast / death). Returns false if the clip is missing.
func play_action(action: String, blend: float = 0.08, p_speed: float = 1.0) -> bool:
	if _dead and action != "death":
		return false
	if not has_anim(action):
		return false
	oneshot = action
	anim.speed_scale = p_speed
	if anim.current_animation == action:
		anim.stop()
	anim.play(action, blend)
	if action == "death":
		_dead = true
	return true


func is_playing_action() -> bool:
	return not oneshot.is_empty()


func action_progress() -> float:
	if anim == null or oneshot.is_empty():
		return 1.0
	var a := anim.get_animation(oneshot)
	if a == null or a.length <= 0.0:
		return 1.0
	return clampf(anim.current_animation_position / a.length, 0.0, 1.0)


func _on_anim_finished(anim_name: StringName) -> void:
	if str(anim_name) == "death":
		return
	if str(anim_name) == oneshot:
		oneshot = ""
		if has_anim(state):
			anim.speed_scale = speed_scale
			anim.play(state, 0.22)


## Advance animation manually (used by deterministic visual-QA capture & headless tests).
func advance(delta: float) -> void:
	if anim != null:
		anim.advance(delta)
	_tick_flash(delta)
	if anim == null and model != null:
		_fallback_t += delta
		model.position.y = absf(sin(_fallback_t * 6.0)) * 0.04 if state in ["walk", "run"] else sin(_fallback_t * 2.0) * 0.01


func _process(delta: float) -> void:
	_tick_flash(delta)
	if anim == null and model != null:
		_fallback_t += delta
		model.position.y = absf(sin(_fallback_t * 6.0)) * 0.04 if state in ["walk", "run"] else sin(_fallback_t * 2.0) * 0.01


## Attaches `node` to the named bone (e.g. "hand_r") so weapons follow the animation.
func attach_to_bone(bone_name: String, node: Node3D) -> BoneAttachment3D:
	if skeleton == null:
		model.add_child(node)
		return null
	var idx := skeleton.find_bone(bone_name)
	if idx < 0:
		model.add_child(node)
		return null
	var ba := BoneAttachment3D.new()
	ba.name = "Attach_%s" % bone_name
	ba.bone_name = bone_name
	skeleton.add_child(ba)
	ba.add_child(node)
	return ba


func clear_attachments() -> void:
	if skeleton == null:
		return
	for c in skeleton.get_children():
		if c is BoneAttachment3D:
			c.queue_free()


var _tint_mat: StandardMaterial3D = null


## Permanent colour wash over the whole body (D-049: enemy variants share a rig but never look alike).
func set_tint(col: Color, strength: float) -> void:
	if _flash_mats.is_empty():
		_collect_flash_targets(model)
	if strength <= 0.0:
		_tint_mat = null
	else:
		_tint_mat = StandardMaterial3D.new()
		_tint_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_tint_mat.albedo_color = Color(col.r, col.g, col.b, clampf(strength, 0.0, 0.9))
		_tint_mat.roughness = 0.6
		_tint_mat.metallic_specular = 0.3
	for entry in _flash_mats:
		var mi: MeshInstance3D = entry
		if is_instance_valid(mi):
			mi.material_overlay = _tint_mat


## Brief red/white hit flash using an overlay next_pass on every surface.
func flash(col: Color = Color(1.0, 0.25, 0.2), duration: float = 0.16) -> void:
	_flash_t = duration
	if _flash_mats.is_empty():
		_collect_flash_targets(model)
	for entry in _flash_mats:
		var mi: MeshInstance3D = entry
		if is_instance_valid(mi):
			var ov := StandardMaterial3D.new()
			ov.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			ov.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			ov.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			ov.albedo_color = Color(col.r, col.g, col.b, FLASH_ALPHA)
			mi.material_overlay = ov


func _collect_flash_targets(n: Node) -> void:
	if n is MeshInstance3D:
		_flash_mats.append(n)
	for c in n.get_children():
		_collect_flash_targets(c)


func _tick_flash(delta: float) -> void:
	if _flash_t <= 0.0:
		return
	_flash_t -= delta
	var k := clampf(_flash_t / 0.16, 0.0, 1.0)
	for entry in _flash_mats:
		var mi: MeshInstance3D = entry
		if is_instance_valid(mi) and mi.material_overlay != null:
			var m := mi.material_overlay as StandardMaterial3D
			m.albedo_color.a = FLASH_ALPHA * k
			if _flash_t <= 0.0:
				mi.material_overlay = _tint_mat
