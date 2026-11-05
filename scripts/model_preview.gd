class_name ModelPreview
## Panellar uchun 3D ko'rinishlar:
##  - thumb(path, rect): binoning .glb modelidan kichik rasm (bir marta yashirin studiyada chiziladi, keshlanadi)
##  - unit_view(faction, kind, team): askarning jonli 3D oynasi (nafas oladi, sekin buriladi, sichqoncha ustiga kelsa hujum qiladi)

static var _cache := {}          # path -> Texture2D
static var _studio: Node = null


static func thumb(path: String, rect: TextureRect, team := Color("#2f7d4a")) -> void:
	if _cache.has(path):
		rect.texture = _cache[path]
		return
	if _studio == null or not is_instance_valid(_studio):
		_studio = _Studio.new()
		(Engine.get_main_loop() as SceneTree).root.add_child(_studio)
	(_studio as _Studio).jobs.append([path, rect, team])


class _Studio extends Node:
	## yashirin SubViewport: navbatdagi modellarni birma-bir chizib, rasmini oladi
	var jobs: Array = []
	var vp: SubViewport
	var cam: Camera3D
	var holder: Node3D
	var _cur = null
	var _wait := 0

	func _ready() -> void:
		vp = SubViewport.new()
		vp.size = Vector2i(192, 128)
		vp.own_world_3d = true
		vp.transparent_bg = true
		vp.msaa_3d = Viewport.MSAA_4X
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(vp)
		var env := WorldEnvironment.new()
		var e := Environment.new()
		e.background_mode = Environment.BG_CLEAR_COLOR
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color(0.85, 0.82, 0.78)
		e.ambient_light_energy = 0.7
		e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.environment = e
		vp.add_child(env)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-42, -35, 0)
		sun.light_energy = 1.3
		sun.light_color = Color(1.0, 0.94, 0.84)
		vp.add_child(sun)
		cam = Camera3D.new()
		cam.fov = 30
		cam.far = 2000
		vp.add_child(cam)
		holder = Node3D.new()
		vp.add_child(holder)

	func _process(_d: float) -> void:
		if _cur != null:
			_wait -= 1
			if _wait > 0:
				return
			var img := vp.get_texture().get_image()
			var tex := ImageTexture.create_from_image(img)
			ModelPreview._cache[_cur[0]] = tex
			for j in [_cur] + jobs.filter(func(x): return x[0] == _cur[0]):
				if is_instance_valid(j[1]):
					(j[1] as TextureRect).texture = tex
			jobs = jobs.filter(func(x): return x[0] != _cur[0])
			_cur = null
			for c in holder.get_children():
				c.queue_free()
			vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		if jobs.is_empty():
			return
		_cur = jobs.pop_front()
		if ModelPreview._cache.has(_cur[0]):
			if is_instance_valid(_cur[1]):
				(_cur[1] as TextureRect).texture = ModelPreview._cache[_cur[0]]
			_cur = null
			return
		var sc: PackedScene = load(_cur[0]) if ResourceLoader.exists(_cur[0]) else null
		if sc == null:
			_cur = null
			return
		var o: Node3D = sc.instantiate()
		holder.add_child(o)
		FX.pbr(o)
		Unit3D.recolor(o, _cur[2])
		var bb := _bounds(o)
		var c := bb.get_center()
		var r := maxf(bb.size.length() * 0.5, 0.5)
		var dir := Vector3(0.62, 0.55, 0.85).normalized()
		cam.position = c + dir * r / tan(deg_to_rad(cam.fov * 0.5)) * 0.92
		cam.look_at(c, Vector3.UP)
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_wait = 3

	func _bounds(n: Node3D) -> AABB:
		var out := AABB()
		var first := true
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m.mesh == null:
				continue
			var b: AABB = m.global_transform * m.get_aabb()
			out = b if first else out.merge(b)
			first = false
		return out


static func unit_view(faction: String, kind: String, team: Color, size := Vector2(104, 124)) -> SubViewportContainer:
	var v := _UnitView.new()
	v.custom_minimum_size = size
	v.stretch = true
	v.setup(faction, kind, team)
	return v


class _UnitView extends SubViewportContainer:
	## askarning jonli ko'rinishi
	var vp: SubViewport
	var model: Node3D
	var kind := ""
	var _t := 0.0
	var _act := 0.0

	func setup(faction: String, k: String, team: Color) -> void:
		kind = k
		vp = SubViewport.new()
		vp.own_world_3d = true
		vp.transparent_bg = true
		vp.msaa_3d = Viewport.MSAA_4X
		add_child(vp)
		var env := WorldEnvironment.new()
		var e := Environment.new()
		e.background_mode = Environment.BG_CLEAR_COLOR
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color(0.9, 0.85, 0.78)
		e.ambient_light_energy = 0.75
		e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.environment = e
		vp.add_child(env)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-35, 30, 0)
		sun.light_energy = 1.4
		sun.light_color = Color(1.0, 0.92, 0.8)
		vp.add_child(sun)
		# yer: kichik doira (soya uchun)
		var g := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = {"otliq": 1.8, "top": 1.8, "fil": 3.0, "arava": 3.0}.get(k, 0.9)
		cm.bottom_radius = cm.top_radius
		cm.height = 0.04
		g.mesh = cm
		var gm := StandardMaterial3D.new()
		gm.albedo_color = Color(0.32, 0.26, 0.18)
		gm.roughness = 1.0
		g.material_override = gm
		g.position.y = -0.02
		vp.add_child(g)
		var cam := Camera3D.new()
		cam.fov = 32
		vp.add_child(cam)
		if k == "otliq":
			model = Unit3D.cavalry(faction, k, team)
			cam.position = Vector3(4.6, 2.1, 2.9)
			cam.look_at_from_position(cam.position, Vector3(0, 1.35, 0))
		elif k == "fil" or k == "arava":
			model = Unit3D.soldier(faction, k, team)
			cam.position = Vector3(9.0, 4.4, 6.4) if k == "fil" else Vector3(7.0, 3.0, 5.0)
			cam.look_at_from_position(cam.position, Vector3(0.3, 2.0 if k == "fil" else 0.9, 0))
		elif k == "top":
			model = Unit3D.cannon(team)
			cam.position = Vector3(3.6, 2.0, 3.0)
			cam.look_at_from_position(cam.position, Vector3(0, 0.6, 0))
		else:
			model = Unit3D.soldier(faction, k, team)
			cam.position = Vector3(3.0, 1.45, 1.45)
			cam.look_at_from_position(cam.position, Vector3(0, 0.95, 0))
		if model != null:
			vp.add_child(model)
			FX.pbr(model)
			_idle()
		mouse_entered.connect(_attack)

	func _idle() -> void:
		if model == null:
			return
		if kind == "otliq":
			Unit3D.play(model, "Idle")
			var rd := Unit3D.rider_of(model)
			if rd:
				Unit3D.play(rd, "Ride")
		else:
			Unit3D.play(model, "Idle")

	func _attack() -> void:
		if model == null or _act > 0.0:
			return
		_act = 1.6
		if kind == "otliq":
			Unit3D.play(model, "Walk")
			var rd := Unit3D.rider_of(model)
			if rd:
				Unit3D.play(rd, "RideAttack")
			return
		var ap := Unit3D.anim(model)
		if ap == null:
			return
		for a in ["Fire", "Attack", "Attack2"] if kind in ["kamonchi", "sarboz", "miltiqchi"] else ["Attack", "Attack2"]:
			if ap.has_animation(a):
				ap.play(a, 0.15)
				_act = maxf(ap.get_animation(a).length, 0.8)
				return

	func _process(delta: float) -> void:
		if model == null or not is_visible_in_tree():
			return
		_t += delta
		model.rotation.y = sin(_t * 0.45) * 0.55
		if _act > 0.0:
			_act -= delta
			if _act <= 0.0:
				_idle()
