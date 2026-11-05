class_name BattleFX
## Jang effektlari: miltiq/to'p og'zidan chiqadigan olov va tutun, uchqunlar, o'q tekkan joydagi chang,
## to'p o'qining portlashi (olov shari, qora tutun, tuproq parchalari, chuqurcha), devordan tosh parchalari,
## olovli o'q alangasi.

static var _mats := {}


static func _m(key: String, col: Color, emit := 0.0, alpha := false) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if emit > 0.0 else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	if alpha or col.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	_mats[key] = m
	return m


static func _burst(parent: Node, pos: Vector3, n: int, col: Color, size: float, speed: Vector2, life: float,
		dir := Vector3.UP, spread := 60.0, gravity := Vector3(0, -9.8, 0), emissive := false, box := false) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var mesh: Mesh
	if box:
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE * size
		mesh = bm
	else:
		var qm := QuadMesh.new()
		qm.size = Vector2(size, size)
		mesh = qm
	mesh.surface_set_material(0, _m("p%s%s" % [col.to_html(), emissive], col, 1.0 if emissive else 0.0, true))
	p.mesh = mesh
	p.amount = n
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.95
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = speed.x
	p.initial_velocity_max = speed.y
	p.gravity = gravity
	p.particle_flag_align_y = false
	if not box:
		var pm := p.mesh.surface_get_material(0) as StandardMaterial3D
		pm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = g
	p.position = pos
	p.emitting = true
	parent.add_child(p)
	parent.get_tree().create_timer(life + 0.5).timeout.connect(p.queue_free)
	return p


static func _ball(parent: Node, pos: Vector3, col: Color, r0: float, r1: float, t: float, rise := 0.0) -> void:
	## kengayib, xiralashib yo'qoladigan shar (olov yoki tutun)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 20
	sm.rings = 10
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.scale = Vector3.ONE * r0 * 2.0
	parent.add_child(mi)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * r1 * 2.0, t).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color:a", 0.0, t).set_ease(Tween.EASE_IN)
	if rise != 0.0:
		tw.tween_property(mi, "position:y", pos.y + rise, t)
	tw.chain().tween_callback(mi.queue_free)


static func _light(parent: Node, pos: Vector3, col: Color, energy: float, rng: float, t: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.position = pos
	parent.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, t)
	tw.tween_callback(l.queue_free)


static func muzzle(parent: Node, pos: Vector3, dir: Vector3, big := false) -> void:
	## og'izdan olov tili, uchqunlar va oq porox tutuni
	var s := 2.6 if big else 1.0
	_ball(parent, pos + dir * 0.25 * s, Color(1.0, 0.9, 0.5, 1.0), 0.15 * s, 0.5 * s, 0.22)
	_ball(parent, pos + dir * 0.7 * s, Color(1.0, 0.55, 0.15, 0.95), 0.12 * s, 0.42 * s, 0.2)
	_ball(parent, pos + dir * 1.1 * s, Color(1.0, 0.4, 0.1, 0.8), 0.08 * s, 0.3 * s, 0.16)
	_light(parent, pos, Color(1.0, 0.7, 0.35), 3.0 * s, 6.0 * s, 0.12)
	_burst(parent, pos, int(14 * s), Color(1.0, 0.75, 0.3), 0.06 * s, Vector2(6, 14) * (1.0 + s * 0.2), 0.45, dir, 18.0, Vector3(0, -6, 0), true)
	for k in (4 if big else 2):
		_ball(parent, pos + dir * (0.4 + k * 0.5) * s + Vector3(0, 0.1 * k, 0), Color(0.9, 0.9, 0.88, 0.45) if not big else Color(0.62, 0.6, 0.58, 0.5),
			0.25 * s, (0.9 + k * 0.3) * s, 2.2 + k * 0.4, 0.8 * s)


static func bullet_hit(parent: Node, pos: Vector3) -> void:
	## miltiq o'qi tekkan joy: kichik chang va bir nechta uchqun
	_burst(parent, pos, 8, Color(0.62, 0.54, 0.42, 0.8), 0.18, Vector2(1.5, 3.5), 0.7, Vector3.UP, 45.0, Vector3(0, -6, 0))
	_burst(parent, pos, 5, Color(1.0, 0.8, 0.4), 0.05, Vector2(3, 6), 0.3, Vector3.UP, 70.0, Vector3(0, -9, 0), true)


static func explosion(parent: Node, pos: Vector3, big := true) -> void:
	## to'p o'qi (granata) portlashi: olov shari, qora tutun ustuni, tuproq va tosh parchalari, uchqunlar, chuqurcha
	var s := 1.0 if big else 0.6
	_light(parent, pos + Vector3(0, 1, 0), Color(1.0, 0.6, 0.25), 6.0 * s, 18.0 * s, 0.35)
	_ball(parent, pos + Vector3(0, 0.6, 0), Color(1.0, 0.9, 0.5, 1.0), 0.3 * s, 2.2 * s, 0.25)
	_ball(parent, pos + Vector3(0, 0.9, 0), Color(1.0, 0.5, 0.12, 0.95), 0.4 * s, 2.8 * s, 0.45, 1.2)
	for k in 5:
		_ball(parent, pos + Vector3(randf_range(-1, 1), 0.8 + k * 0.4, randf_range(-1, 1)) * s, Color(0.16, 0.14, 0.12, 0.85),
			0.6 * s, (2.0 + k * 0.3) * s, 3.0 + k * 0.5, (3.0 + k) * s)
	_burst(parent, pos + Vector3(0, 0.3, 0), int(26 * s), Color(0.42, 0.33, 0.22), 0.22 * s, Vector2(6, 13) * s, 1.6, Vector3.UP, 55.0, Vector3(0, -14, 0), false, true)
	_burst(parent, pos + Vector3(0, 0.4, 0), int(30 * s), Color(1.0, 0.7, 0.25), 0.07, Vector2(8, 18) * s, 0.9, Vector3.UP, 75.0, Vector3(0, -9, 0), true)
	_burst(parent, pos, int(14 * s), Color(0.62, 0.54, 0.42, 0.7), 1.2 * s, Vector2(1, 3), 2.5, Vector3.UP, 85.0, Vector3(0, -0.5, 0))
	crater(parent, pos, 1.6 * s)


static func crater(parent: Node, pos: Vector3, r: float) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.04
	cm.radial_segments = 14
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.13, 0.1, 0.08, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.position = pos + Vector3(0, 0.04, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var tw := mi.create_tween()
	tw.tween_interval(40.0)
	tw.tween_property(m, "albedo_color:a", 0.0, 5.0)
	tw.tween_callback(mi.queue_free)


static func wall_hit(parent: Node, pos: Vector3, out: Vector3) -> void:
	## tosh/to'p o'qi devorga tegdi: tosh parchalari va oq-sariq chang
	_burst(parent, pos, 22, Color(0.72, 0.64, 0.52), 0.3, Vector2(4, 10), 1.8, out + Vector3(0, 0.6, 0), 50.0, Vector3(0, -12, 0), false, true)
	_burst(parent, pos, 14, Color(0.82, 0.76, 0.64, 0.7), 1.4, Vector2(1, 3), 2.8, out + Vector3(0, 0.3, 0), 70.0, Vector3(0, -0.4, 0))


static func flame(parent: Node3D, pos: Vector3, scale := 1.0, amount := 14) -> CPUParticles3D:
	## doimiy alanga (mash'ala, olovli o'q, yonayotgan qamal quroli)
	var p := CPUParticles3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.22, 0.22) * scale
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.material = m
	p.mesh = qm
	p.amount = amount
	p.lifetime = 0.55
	p.direction = Vector3.UP
	p.spread = 15.0
	p.initial_velocity_min = 0.6 * scale
	p.initial_velocity_max = 1.4 * scale
	p.gravity = Vector3(0, 1.5, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.4, 0.95))
	g.add_point(0.5, Color(1.0, 0.45, 0.1, 0.7))
	g.set_color(g.get_point_count() - 1, Color(0.3, 0.3, 0.3, 0.0))
	p.color_ramp = g
	p.position = pos
	parent.add_child(p)
	return p
