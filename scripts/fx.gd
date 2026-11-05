class_name FX
## Realistik grafika uchun umumiy yordamchilar:
## - muhit (SDFGI global yoritish, SSAO, SSIL, glow, hajmli tuman, ACES tonemap)
## - quyosh (yumshoq chuqur soyalar, 4 bo'lakli PSSM)
## - PBR materiallar (metallik, yaltirash, triplanar normal tekstura)
## - GPUParticles3D tutun va chang
## Forward+ bo'lmagan (eski videokarta, OpenGL) holatda og'ir effektlar avtomatik o'chiriladi.

static var _noise_normal: Texture2D
static var _noise_rough: Texture2D
static var _soft: Texture2D
static var _mat_cache := {}


static func high_end() -> bool:
	# Vulkan/D3D12 (Forward+) ishlayotgan bo'lsa RenderingDevice mavjud; OpenGL rejimida null
	return RenderingServer.get_rendering_device() != null


static func environment(desert: bool, ground: Color, sky_top := Color("#3a6aa3")) -> WorldEnvironment:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = sky_top
	sm.sky_horizon_color = Color("#c9d6e2") if not desert else Color("#e2d6bd")
	sm.sky_curve = 0.12
	sm.ground_horizon_color = sm.sky_horizon_color.darkened(0.05)
	sm.ground_bottom_color = ground.darkened(0.45)
	sm.sun_angle_max = 25.0
	sm.sun_curve = 0.12
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.55
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 0.95
	e.tonemap_white = 6.0
	e.glow_enabled = true
	e.glow_intensity = 0.35
	e.glow_bloom = 0.04
	e.glow_hdr_threshold = 1.2
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.06
	e.adjustment_saturation = 1.08
	e.fog_enabled = true
	e.fog_light_color = sm.sky_horizon_color
	e.fog_density = 0.0006
	e.fog_sky_affect = 0.25
	if high_end():
		e.sdfgi_enabled = true
		e.sdfgi_use_occlusion = true
		e.sdfgi_bounce_feedback = 0.6
		e.sdfgi_cascades = 4
		e.sdfgi_min_cell_size = 0.4
		e.sdfgi_energy = 1.1
		e.ssao_enabled = true
		e.ssao_radius = 1.6
		e.ssao_intensity = 2.2
		e.ssil_enabled = true
		e.ssil_intensity = 0.8
		e.ssr_enabled = true
		e.volumetric_fog_enabled = true
		e.volumetric_fog_density = 0.004
		e.volumetric_fog_albedo = sm.sky_horizon_color
		e.volumetric_fog_length = 300.0
		e.ambient_light_energy = 0.35
	env.environment = e
	return env


static func sun(max_dist := 400.0) -> DirectionalLight3D:
	var s := DirectionalLight3D.new()
	s.rotation_degrees = Vector3(-48, -38, 0)
	s.light_energy = 1.35 if high_end() else 1.05
	s.light_color = Color(1.0, 0.95, 0.86)
	s.light_angular_distance = 1.2          # yumshoq soya chetlari
	s.shadow_enabled = true
	s.shadow_bias = 0.04
	s.shadow_normal_bias = 1.2
	s.shadow_blur = 1.4
	s.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	s.directional_shadow_max_distance = max_dist
	s.directional_shadow_blend_splits = true
	return s


# ---------------------------------------------------------------- teksturalar

static func normal_tex() -> Texture2D:
	if _noise_normal == null:
		var t := NoiseTexture2D.new()
		var n := FastNoiseLite.new()
		n.frequency = 0.06
		n.fractal_octaves = 4
		t.noise = n
		t.seamless = true
		t.as_normal_map = true
		t.bump_strength = 6.0
		t.width = 256
		t.height = 256
		_noise_normal = t
	return _noise_normal


static func rough_tex() -> Texture2D:
	if _noise_rough == null:
		var t := NoiseTexture2D.new()
		var n := FastNoiseLite.new()
		n.frequency = 0.09
		t.noise = n
		t.seamless = true
		t.width = 128
		t.height = 128
		_noise_rough = t
	return _noise_rough


static func soft_tex() -> Texture2D:
	if _soft == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.5, Color(1, 1, 1, 0.6))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_soft = t
	return _soft


static func ground_material(c1: Color, c2: Color, seed := 0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var tex := NoiseTexture2D.new()
	var noise := FastNoiseLite.new()
	noise.frequency = 0.012
	noise.fractal_octaves = 5
	noise.seed = seed
	tex.noise = noise
	tex.seamless = true
	tex.width = 512
	tex.height = 512
	var grad := Gradient.new()
	grad.set_color(0, c1)
	grad.set_color(1, c2)
	grad.add_point(0.55, c1.lerp(c2, 0.6).darkened(0.05))
	tex.color_ramp = grad
	m.albedo_texture = tex
	m.uv1_scale = Vector3(14, 14, 1)
	m.normal_enabled = true
	m.normal_texture = normal_tex()
	m.normal_scale = 0.6
	m.roughness = 0.95
	m.roughness_texture = rough_tex()
	m.detail_enabled = false
	return m


# ---------------------------------------------------------------- PBR

static func pbr(root: Node) -> void:
	## Blender modellaridagi materiallarni realistik PBR ga o'tkazadi (nomiga qarab)
	for mi in _meshes(root, []):
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var src: Material = mi.get_surface_override_material(i)
			if src == null:
				src = mesh.surface_get_material(i)
			if not (src is StandardMaterial3D):
				continue
			var key := src.get_instance_id()
			if not _mat_cache.has(key):
				_mat_cache[key] = _upgrade(src as StandardMaterial3D)
			mi.set_surface_override_material(i, _mat_cache[key])


static func _upgrade(src: StandardMaterial3D) -> StandardMaterial3D:
	var m: StandardMaterial3D = src.duplicate()
	var n := src.resource_name.to_lower()
	m.normal_enabled = true
	m.normal_texture = normal_tex()
	m.uv1_triplanar = true
	m.uv1_world_triplanar = false
	m.uv1_scale = Vector3(0.6, 0.6, 0.6)
	m.normal_scale = 0.25
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	if n.contains("glass") or n.contains("win") or n.contains("canopy") or n.contains("water"):
		m.metallic = 0.7
		m.roughness = 0.06
		m.normal_scale = 0.0
		m.metallic_specular = 0.9
	elif n.contains("metal") or n.contains("chrome") or n.contains("engine") or n.contains("gold") or n.contains("exhaust"):
		m.metallic = 0.85
		m.roughness = 0.28
	elif n.contains("olive") or n.contains("tank") or n.contains("track") or n.contains("art") or n.contains("jet") \
			or n.contains("truck") or n.contains("cab") or n.contains("carbody") or n.contains("fus") or n.contains("wing") or n.contains("missile"):
		m.metallic = 0.35          # bo'yalgan metall
		m.roughness = 0.5
		m.clearcoat_enabled = n.contains("carbody") or n.contains("fus")
		m.clearcoat = 0.5
	elif n.contains("team"):
		m.metallic = 0.2
		m.roughness = 0.35
	elif n.contains("concrete") or n.contains("wall") or n.contains("pad") or n.contains("asphalt") or n.contains("brick") or n.contains("roof"):
		m.metallic = 0.0
		m.roughness = 0.92
		m.normal_scale = 0.55
		m.roughness_texture = rough_tex()
	elif n.contains("tyre") or n.contains("dark") or n.contains("rubber"):
		m.metallic = 0.0
		m.roughness = 0.85
	elif n.contains("bark") or n.contains("leaf") or n.contains("needle") or n.contains("bush"):
		m.metallic = 0.0
		m.roughness = 0.9
		m.normal_scale = 0.5
	elif n.contains("skin"):
		m.roughness = 0.6
		m.normal_scale = 0.05
	else:
		m.roughness = clampf(src.roughness, 0.4, 0.9)
	return m


static func _meshes(root: Node, out: Array) -> Array:
	if root is MeshInstance3D:
		out.append(root)
	for c in root.get_children():
		_meshes(c, out)
	return out


# ---------------------------------------------------------------- GPU zarrachalar

static func _particles(amount: int, life: float, col_a: Color, col_b: Color, size: float, vel: Vector2, gravity: Vector3,
		spread: float, dir := Vector3.UP, grow := 2.2) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	p.visibility_aabb = AABB(Vector3(-40, -5, -40), Vector3(80, 80, 80))
	var pm := ParticleProcessMaterial.new()
	pm.direction = dir
	pm.spread = spread
	pm.initial_velocity_min = vel.x
	pm.initial_velocity_max = vel.y
	pm.gravity = gravity
	pm.damping_min = 0.4
	pm.damping_max = 1.2
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.angular_velocity_min = -25.0
	pm.angular_velocity_max = 25.0
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = size * 0.25
	var sc := CurveTexture.new()
	var c := Curve.new()
	c.add_point(Vector2(0, 0.35))
	c.add_point(Vector2(1, 1.0))
	sc.curve = c
	pm.scale_curve = sc
	pm.scale_min = 0.8
	pm.scale_max = 1.2 * grow / 2.2
	var g := Gradient.new()
	g.set_color(0, col_a)
	g.add_point(0.15, col_a)
	g.set_color(1, Color(col_b.r, col_b.g, col_b.b, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = soft_tex()
	m.proximity_fade_enabled = high_end()
	m.proximity_fade_distance = 1.5
	q.material = m
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


static func factory_smoke(scale := 1.0) -> GPUParticles3D:
	## Zavod mo'risidan ko'tariladigan quyuq-oq tutun
	var p := _particles(36, 7.0, Color(0.82, 0.82, 0.8, 0.55), Color(0.6, 0.6, 0.62), 4.0 * scale,
		Vector2(2.0, 3.5) * scale, Vector3(1.4, 0.7, 0.5) * scale, 10.0, Vector3.UP, 4.0)
	return p


static func dust(scale := 1.0) -> GPUParticles3D:
	## Tank / mashina orqasidan ko'tariladigan chang
	var p := _particles(28, 1.8, Color(0.62, 0.54, 0.42, 0.5), Color(0.55, 0.5, 0.4), 3.0 * scale,
		Vector2(0.8, 2.0) * scale, Vector3(0, 0.5, 0), 70.0, Vector3.UP, 3.0)
	p.emitting = false
	return p
