class_name VfxFactory
extends RefCounted
## Builds reusable visual-effect nodes (fire, embers, smoke, dust motes, magic, impact sparks).
## Every effect uses original procedural sprites from game/assets/vfx/ (art/pipeline/generate_textures.py).

const VFX_DIR := "res://assets/vfx/"

static var _tex: Dictionary = {}
static var _mats: Dictionary = {}
## 0 = low (fewer particles), 1 = medium, 2 = high.
static var quality: int = 2


static func tex(file_name: String) -> Texture2D:
	if _tex.has(file_name):
		return _tex[file_name]
	var path := VFX_DIR + file_name
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path) as Texture2D
	else:
		var gp := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(gp):
			var img := Image.load_from_file(gp)
			if img != null:
				img.generate_mipmaps()
				t = ImageTexture.create_from_image(img)
	_tex[file_name] = t
	return t


static func _sprite_material(key: String, texture_file: String, additive: bool, h_frames: int = 1, v_frames: int = 1,
		tint: Color = Color.WHITE, energy: float = 1.0, soft: bool = true) -> StandardMaterial3D:
	var cache_key := "%s|%s|%s" % [key, str(tint), str(energy)]
	if _mats.has(cache_key):
		return _mats[cache_key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex(texture_file)
	m.albedo_color = Color(tint.r * energy, tint.g * energy, tint.b * energy, tint.a)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.disable_receive_shadows = true
	if h_frames > 1 or v_frames > 1:
		m.particles_anim_h_frames = h_frames
		m.particles_anim_v_frames = v_frames
		m.particles_anim_loop = true
	if soft:
		m.proximity_fade_enabled = true
		m.proximity_fade_distance = 0.12
	_mats[cache_key] = m
	return m


static func _quad(size: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	return q


static func _gradient(stops: Array) -> GradientTexture1D:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for s in stops:
		offs.append(float(s[0]))
		cols.append(s[1])
	g.offsets = offs
	g.colors = cols
	var gt := GradientTexture1D.new()
	gt.gradient = g
	return gt


static func _curve(points: Array) -> CurveTexture:
	var c := Curve.new()
	for p in points:
		c.add_point(Vector2(float(p[0]), float(p[1])))
	var ct := CurveTexture.new()
	ct.curve = c
	return ct


## Living flame: flipbook fire core + rising embers + faint smoke + soft glow halo.
static func make_fire(scale: float = 1.0, with_smoke: bool = true) -> Node3D:
	var root := Node3D.new()
	root.name = "Fire"
	var counts := [6, 10, 14]
	var flames := GPUParticles3D.new()
	flames.name = "Flames"
	flames.amount = int(counts[clampi(quality, 0, 2)] * maxf(1.0, scale))
	flames.lifetime = 0.75
	flames.preprocess = 0.8
	flames.randomness = 0.4
	flames.local_coords = false
	flames.visibility_aabb = AABB(Vector3(-0.6, -0.2, -0.6) * scale, Vector3(1.2, 1.6, 1.2) * scale)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.05 * scale
	pm.direction = Vector3.UP
	pm.spread = 8.0
	pm.initial_velocity_min = 0.25 * scale
	pm.initial_velocity_max = 0.5 * scale
	pm.gravity = Vector3(0, 0.9 * scale, 0)
	pm.damping_min = 0.4
	pm.damping_max = 0.8
	pm.angle_min = -12.0
	pm.angle_max = 12.0
	pm.scale_min = 0.75
	pm.scale_max = 1.15
	pm.scale_curve = _curve([[0.0, 0.55], [0.25, 1.0], [1.0, 0.25]])
	pm.color_ramp = _gradient([[0.0, Color(1, 1, 1, 0.0)], [0.12, Color(1, 1, 1, 1.0)], [0.7, Color(1, 0.9, 0.8, 0.85)], [1.0, Color(1, 0.6, 0.4, 0.0)]])
	pm.anim_speed_min = 1.0
	pm.anim_speed_max = 1.4
	pm.anim_offset_min = 0.0
	pm.anim_offset_max = 1.0
	pm.turbulence_enabled = quality >= 2
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 1.6
	pm.turbulence_influence_min = 0.03
	pm.turbulence_influence_max = 0.08
	flames.process_material = pm
	var fq := _quad(0.42 * scale)
	fq.material = _sprite_material("flame", "flame_flipbook.webp", true, 8, 8, Color(1.0, 0.92, 0.85), 1.8)
	flames.draw_pass_1 = fq
	root.add_child(flames)

	var embers := GPUParticles3D.new()
	embers.name = "Embers"
	embers.amount = [3, 6, 10][clampi(quality, 0, 2)]
	embers.lifetime = 1.6
	embers.preprocess = 1.0
	embers.randomness = 0.8
	embers.visibility_aabb = AABB(Vector3(-1, -0.2, -1) * scale, Vector3(2, 3, 2) * scale)
	var em := ParticleProcessMaterial.new()
	em.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	em.emission_sphere_radius = 0.08 * scale
	em.direction = Vector3.UP
	em.spread = 25.0
	em.initial_velocity_min = 0.4 * scale
	em.initial_velocity_max = 1.1 * scale
	em.gravity = Vector3(0, 0.25, 0)
	em.turbulence_enabled = true
	em.turbulence_noise_strength = 2.0
	em.turbulence_noise_scale = 2.4
	em.turbulence_influence_min = 0.1
	em.turbulence_influence_max = 0.25
	em.scale_min = 0.5
	em.scale_max = 1.0
	em.color_ramp = _gradient([[0.0, Color(1.0, 0.85, 0.5, 1.0)], [0.6, Color(1.0, 0.45, 0.1, 0.9)], [1.0, Color(0.6, 0.1, 0.0, 0.0)]])
	embers.process_material = em
	var eq := _quad(0.035 * scale)
	eq.material = _sprite_material("ember", "spark.webp", true, 1, 1, Color(1.0, 0.7, 0.35), 3.0, false)
	embers.draw_pass_1 = eq
	root.add_child(embers)

	if with_smoke and quality >= 1:
		var smoke := GPUParticles3D.new()
		smoke.name = "Smoke"
		smoke.amount = 5
		smoke.lifetime = 2.6
		smoke.preprocess = 2.0
		smoke.visibility_aabb = AABB(Vector3(-1.5, 0, -1.5) * scale, Vector3(3, 4, 3) * scale)
		var sm := ParticleProcessMaterial.new()
		sm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		sm.emission_sphere_radius = 0.06 * scale
		sm.direction = Vector3.UP
		sm.spread = 12.0
		sm.initial_velocity_min = 0.3 * scale
		sm.initial_velocity_max = 0.5 * scale
		sm.gravity = Vector3(0, 0.15, 0)
		sm.angle_min = -180.0
		sm.angle_max = 180.0
		sm.angular_velocity_min = -20.0
		sm.angular_velocity_max = 20.0
		sm.scale_curve = _curve([[0.0, 0.3], [1.0, 1.6]])
		sm.color_ramp = _gradient([[0.0, Color(0.2, 0.18, 0.16, 0.0)], [0.25, Color(0.16, 0.14, 0.13, 0.22)], [1.0, Color(0.1, 0.1, 0.1, 0.0)]])
		smoke.process_material = sm
		var sq := _quad(0.5 * scale)
		sq.material = _sprite_material("smoke", "smoke_flipbook.webp", false, 4, 4, Color(1, 1, 1), 1.0)
		smoke.draw_pass_1 = sq
		smoke.position.y = 0.25 * scale
		root.add_child(smoke)

	# Warm halo billboard so the flame reads even where volumetric fog is disabled
	var halo := MeshInstance3D.new()
	halo.name = "Halo"
	var hq := _quad(0.9 * scale)
	var hm := _sprite_material("halo", "soft_glow.webp", true, 1, 1, Color(1.0, 0.55, 0.22, 0.55), 1.0)
	hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	hq.material = hm
	halo.mesh = hq
	halo.position.y = 0.12 * scale
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(halo)
	return root


## Slow floating dust motes filling a room volume — catches torchlight beautifully.
static func make_dust(extent: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "DustMotes"
	p.amount = [0, 40, 90][clampi(quality, 0, 2)]
	if p.amount == 0:
		p.emitting = false
		p.amount = 1
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.visibility_aabb = AABB(-extent * 0.5 - Vector3.ONE, extent + Vector3.ONE * 2.0)
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = extent * 0.5
	m.direction = Vector3(0.2, 1, 0.1)
	m.spread = 180.0
	m.initial_velocity_min = 0.02
	m.initial_velocity_max = 0.08
	m.gravity = Vector3(0, -0.005, 0)
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.4
	m.turbulence_noise_scale = 4.0
	m.turbulence_influence_min = 0.02
	m.turbulence_influence_max = 0.05
	m.scale_min = 0.4
	m.scale_max = 1.0
	m.color_ramp = _gradient([[0.0, Color(1, 0.95, 0.85, 0.0)], [0.2, Color(1, 0.95, 0.85, 0.5)], [0.8, Color(1, 0.95, 0.85, 0.5)], [1.0, Color(1, 0.95, 0.85, 0.0)]])
	p.process_material = m
	var q := _quad(0.018)
	var mat := _sprite_material("dust", "dust_mote.webp", false, 1, 1, Color(1.0, 0.92, 0.8, 0.7), 1.0, false)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.emission_enabled = true
	mat.emission = Color(0.25, 0.2, 0.15)
	q.material = mat
	p.draw_pass_1 = q
	return p


## Magic: swirling glowing motes around a point (hands, beacon crystal, spell projectiles).
static func make_magic_aura(col: Color, radius: float = 0.12, amount: int = 24) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "MagicAura"
	p.amount = maxi(4, int(amount * [0.4, 0.7, 1.0][clampi(quality, 0, 2)]))
	p.lifetime = 0.9
	p.preprocess = 0.9
	p.local_coords = true
	p.visibility_aabb = AABB(Vector3.ONE * -1.0, Vector3.ONE * 2.0)
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	m.emission_sphere_radius = radius
	m.direction = Vector3.UP
	m.spread = 180.0
	m.initial_velocity_min = 0.05
	m.initial_velocity_max = 0.2
	m.orbit_velocity_min = 0.6
	m.orbit_velocity_max = 1.2
	m.radial_accel_min = -0.6
	m.radial_accel_max = -0.2
	m.gravity = Vector3(0, 0.3, 0)
	m.scale_min = 0.5
	m.scale_max = 1.2
	m.color_ramp = _gradient([[0.0, Color(col.r, col.g, col.b, 0.0)], [0.2, Color(col.r, col.g, col.b, 1.0)], [1.0, Color(col.r, col.g, col.b, 0.0)]])
	p.process_material = m
	var q := _quad(0.05)
	q.material = _sprite_material("magic", "hot_core.webp", true, 1, 1, Color(1, 1, 1), 2.4, false)
	p.draw_pass_1 = q
	return p


## Single bright billboard glow (spell cores, crystals, eyes).
static func make_glow(col: Color, size: float = 0.4, energy: float = 1.6) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Glow"
	var q := _quad(size)
	var m := _sprite_material("glow", "soft_glow.webp", true, 1, 1, col, energy, false)
	m = m.duplicate()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = m
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## One-shot burst of sparks/embers (sword hits, spell impacts). Frees itself.
static func make_impact_burst(col: Color, count: int = 22, speed: float = 3.5) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "ImpactBurst"
	p.amount = count
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 0.55
	p.visibility_aabb = AABB(Vector3.ONE * -3.0, Vector3.ONE * 6.0)
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.06
	m.direction = Vector3.UP
	m.spread = 180.0
	m.initial_velocity_min = speed * 0.4
	m.initial_velocity_max = speed
	m.gravity = Vector3(0, -6.0, 0)
	m.damping_min = 1.0
	m.damping_max = 2.5
	m.scale_min = 0.5
	m.scale_max = 1.2
	m.color_ramp = _gradient([[0.0, Color(1, 1, 1, 1)], [0.3, Color(col.r, col.g, col.b, 1.0)], [1.0, Color(col.r * 0.5, col.g * 0.3, col.b * 0.2, 0.0)]])
	p.process_material = m
	var q := _quad(0.05)
	q.material = _sprite_material("spark", "spark.webp", true, 1, 1, Color(1, 1, 1), 3.0, false)
	p.draw_pass_1 = q
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p


## Vertical cobweb card for room/corridor corners.
static func make_cobweb(size: float = 1.1) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Cobweb"
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.center_offset = Vector3(size * 0.5, -size * 0.5, 0)
	var key := "cobweb_mat"
	var m: StandardMaterial3D = _mats.get(key, null)
	if m == null:
		m = StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = tex("cobweb.webp")
		m.albedo_color = Color(0.85, 0.83, 0.8, 0.75)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 1.0
		m.disable_receive_shadows = true
		_mats[key] = m
	q.material = m
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
