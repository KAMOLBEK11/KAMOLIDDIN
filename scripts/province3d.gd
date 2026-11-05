extends Node
## Viloyat bazasi - 3D ko'rinish (Generals uslubida).
## Markazda hokimiyat. Uni bosing - qurilish menyusi ochiladi, binoni xohlagan joyga qo'yasiz.
## Binolar 3D modellar, qurilish jarayoni ko'rinadi. Askar va tanklar maydonda turadi -
## ularni bosib, kerakli sonini tanlab boshqa viloyatga jo'natasiz.
## Harbiy zavod / aerodromni bossangiz - ishlab chiqarish paneli (navbat va soni bilan).

signal closed

const HQ_R := 24.0
const FOOT := {"hq": 24.0, "civil": 24.0, "mine": 21.0, "military": 27.0, "lab_civ": 16.0, "lab_mil": 18.0,
	"airbase": 56.0, "airport": 56.0, "barracks": 23.0, "depot": 24.0, "shipyard": 26.0, "politic": 16.0}
const AREA_R := 230.0
const SOLDIER_SCALE := 1.7
const TANK_SIZE := 9.5

var prov_id := ""
var hud: Control
var vp: SubViewport
var world: Node3D
var cam: Camera3D
var cam_target := Vector3(0, 0, 25)
var cam_dist := 190.0
var cam_yaw := 0.0
var cam_pitch := 50.0
var _mid_drag := false
var _rmb_drag := false

var ground_col := Color("#4f6b3a")
var ground_col2 := Color("#64824a")
var desert := false

var static_root: Node3D        # yer, daraxt, uylar
var bld_root: Node3D           # binolar
var unit_root: Node3D          # askar va tanklar
var fx_root: Node3D            # samolyot, mashina
var bld_nodes: Array = []      # {node, b, index, model, scaffold, label, anim}
var groups := {}               # "soldier"/"tank" -> {node, pos, count}
var trucks: Array = []
var flights: Array = []
var _flight_t := 8.0
var _sig := ""
var _anim_t := 0.0
var _model_cache := {}
var _mats := {}

# tanlash / joylashtirish
var placing := ""
var ghost: Node3D
var ghost_ok := false
var selected := ""              # "hq", "b:<index>", "soldier", "tank"
var sel_ring: MeshInstance3D

# HUD
var top_label: Label
var money_label: Label
var panel: PanelContainer
var panel_box: VBoxContainer
var tip: Label
var _panel_dirty := true
var _speed_btns := {}


# ================================================================ tayyorlash

func setup(id: String) -> void:
	prov_id = id
	var p: Dictionary = Game.provinces[id]
	match p["country"]:
		"TKM", "AFG":
			ground_col = Color("#9a7e52"); ground_col2 = Color("#b39466"); desert = true
		"MNG", "KAZ":
			ground_col = Color("#6a743c"); ground_col2 = Color("#83904a")
		_:
			ground_col = Color("#2f4a24"); ground_col2 = Color("#44612f")
	_assign_positions()
	_build_hud()
	_build_world()
	_rebuild_dynamic(true)
	_update_camera()
	Game.changed.connect(_on_changed)
	Game.units_moved.connect(_on_units_moved)
	Game.units_produced.connect(_on_units_produced)


func _p() -> Dictionary:
	return Game.provinces[prov_id]


func _assign_positions() -> void:
	## Eski saqlangan o'yinlarda binolarning joyi yo'q - hokimiyat atrofiga avtomatik joylashtiramiz
	var p := _p()
	var i := 0
	for b in p["buildings"]:
		if not b.has("pos"):
			var pos := _free_spot(b["type"], i)
			b["pos"] = [pos.x, pos.y]
		i += 1


func _free_spot(type: String, seed_i: int) -> Vector2:
	var r: float = FOOT.get(type, 22.0)
	for ring in 6:
		for k in 12:
			var ang := (k + seed_i * 5 + ring * 0.5) * TAU / 12.0
			var dist := 70.0 + ring * 45.0 + r * 0.6
			var c := Vector2(cos(ang), sin(ang)) * dist
			if _spot_free(c, r, -1):
				return c
	return Vector2(randf_range(-150, 150), randf_range(-150, 150))


func _spot_free(c: Vector2, r: float, ignore: int) -> bool:
	if c.length() > AREA_R:
		return false
	if c.length() < HQ_R + r + 8.0:
		return false
	var p := _p()
	for i in p["buildings"].size():
		if i == ignore:
			continue
		var b: Dictionary = p["buildings"][i]
		if not b.has("pos"):
			continue
		var bp := Vector2(b["pos"][0], b["pos"][1])
		if bp.distance_to(c) < r + float(FOOT.get(b["type"], 22.0)) + 6.0:
			return false
	return true


# ================================================================ materiallar va modellar

func _mat(key: String, col: Color, rough := 0.9) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = rough
		_mats[key] = m
	return _mats[key]


func _box(parent: Node3D, size: Vector3, pos: Vector3, m: Material, rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	return mi


func _load(name: String) -> Array:
	var path := ""
	for ext in [".glb", ".gltf", ".fbx"]:
		if ResourceLoader.exists("res://models/" + name + ext):
			path = "res://models/" + name + ext
			break
	if path == "":
		return []
	if not _model_cache.has(path):
		var sc: PackedScene = load(path)
		var probe: Node3D = sc.instantiate()
		var box := _aabb(probe, Transform3D())
		probe.free()
		_model_cache[path] = [sc, box]
	return _model_cache[path]


func _model(name: String, max_size: float) -> Node3D:
	## max_size <= 0 - modelning asl o'lchami (metr)
	var entry := _load(name)
	if entry.is_empty():
		return null
	var box2: AABB = entry[1]
	var k := 1.0
	if max_size > 0.0:
		k = max_size / maxf(0.001, maxf(box2.size.x, maxf(box2.size.y, box2.size.z)))
	var holder := Node3D.new()
	var inst: Node3D = entry[0].instantiate()
	FX.pbr(inst)
	inst.scale = Vector3(k, k, k)
	if max_size > 0.0:
		inst.position = Vector3(-(box2.position.x + box2.size.x / 2.0) * k, -box2.position.y * k, -(box2.position.z + box2.size.z / 2.0) * k)
	holder.add_child(inst)
	return holder


func _aabb(n: Node, xf: Transform3D) -> AABB:
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	var out := AABB()
	var has := false
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		out = t * (n as MeshInstance3D).mesh.get_aabb()
		has = true
	for c in n.get_children():
		var b := _aabb(c, t)
		if b.size != Vector3.ZERO:
			out = b if not has else out.merge(b)
			has = true
	return out


func _find(root: Node, name: String) -> Node3D:
	if root.name == name and root is Node3D:
		return root
	for c in root.get_children():
		var r := _find(c, name)
		if r:
			return r
	return null


func _find_prefix(root: Node, prefix: String, out: Array) -> Array:
	if root is Node3D and String(root.name).begins_with(prefix):
		out.append(root)
	for c in root.get_children():
		_find_prefix(c, prefix, out)
	return out


func _meshes_of(root: Node, out: Array) -> Array:
	if root is MeshInstance3D:
		out.append(root)
	for c in root.get_children():
		_meshes_of(c, out)
	return out


func _team_paint(root: Node) -> void:
	var tm := _mat("team", Color("#e8b73a"), 0.5)
	for mi in _meshes_of(root, []):
		if String(mi.name).begins_with("TeamColor"):
			mi.material_override = tm
			continue
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var sm: Material = mi.mesh.surface_get_material(i)
			if sm and sm.resource_name == "TeamColor":
				mi.set_surface_override_material(i, tm)


var _soft: Texture2D


func _soft_tex() -> Texture2D:
	if _soft == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_soft = t
	return _soft


func _smoke(_col: Color, size: float) -> GPUParticles3D:
	return FX.factory_smoke(size / 3.5)


# ================================================================ dunyo

# ================================================================ kengaytirilgan viloyat: relyef, tumanlar, magistrallar

const REGION_R := 1500.0
const LAND_N := 170
var districts: Array = []       # {pos, name}
var highways: Array = []        # [[a, b], ...] - kesmalar
var _hgrid := PackedFloat32Array()
var _mf := 0.3


func _plan_region() -> void:
	## Tumanlar joyi (pasttekisliklarda), magistrallar va temir yo'l yo'nalishi
	var p := _p()
	_mf = Geo.mountain(p)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(prov_id) + 77
	var ra := rng.randf() * PI
	var rdir := Vector2(cos(ra), sin(ra))
	var roff := rdir.orthogonal() * AREA_R * 0.62
	rail_a = roff - rdir * (REGION_R + 200.0)
	rail_b = roff + rdir * (REGION_R + 200.0)
	districts.clear()
	highways.clear()
	var n := 5
	var a0 := rng.randf() * TAU
	for k in n:
		var ang := a0 + k * TAU / n + rng.randf_range(-0.25, 0.25)
		var pos := Vector2.from_angle(ang) * rng.randf_range(650.0, 1000.0)
		var nm: String = Geo.DISTRICTS[(hash(prov_id) + k * 7) % Geo.DISTRICTS.size()]
		districts.append({"pos": pos, "name": nm})
	for k in n:
		var dp: Vector2 = districts[k]["pos"]
		var start := dp.normalized() * (AREA_R + 20.0)
		var mid := start.lerp(dp, 0.5) + dp.orthogonal().normalized() * rng.randf_range(-90.0, 90.0)
		highways.append([start, mid])
		highways.append([mid, dp])
		# halqa yo'l: qo'shni tumanlar o'rtasida
		var nx: Vector2 = districts[(k + 1) % n]["pos"]
		highways.append([dp, nx])


func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _raw_h(pt: Vector2, noise: FastNoiseLite, ridge: FastNoiseLite) -> float:
	var r := pt.length()
	var hills := (noise.get_noise_2dv(pt) * 0.5 + 0.5) * (18.0 + 40.0 * _mf)
	var rg := ridge.get_noise_2dv(pt) * 0.5 + 0.5
	var mountains := rg * rg * (60.0 + 300.0 * _mf) * smoothstep(380.0, 1100.0, r)
	var h := hills + mountains
	# baza tekis, tumanlar va yo'llar atrofi vodiy
	var flat := smoothstep(AREA_R + 60.0, AREA_R + 280.0, r)
	for d in districts:
		flat = minf(flat, smoothstep(110.0, 260.0, pt.distance_to(d["pos"])))
	for hw in highways:
		flat = minf(flat, smoothstep(18.0, 110.0, _seg_dist(pt, hw[0], hw[1])) * 0.85 + 0.15 * flat)
	flat = minf(flat, smoothstep(16.0, 120.0, _seg_dist(pt, rail_a, rail_b)))
	return h * flat


func h_at(pt: Vector2) -> float:
	if _hgrid.is_empty():
		return 0.0
	var size := REGION_R * 2.0 + 400.0
	var u := (pt.x + size / 2.0) / size * (LAND_N - 1)
	var v := (pt.y + size / 2.0) / size * (LAND_N - 1)
	if u < 0 or v < 0 or u >= LAND_N - 1 or v >= LAND_N - 1:
		return 0.0
	var x0 := int(u)
	var y0 := int(v)
	var fx := u - x0
	var fy := v - y0
	var a := lerpf(_hgrid[y0 * LAND_N + x0], _hgrid[y0 * LAND_N + x0 + 1], fx)
	var b := lerpf(_hgrid[(y0 + 1) * LAND_N + x0], _hgrid[(y0 + 1) * LAND_N + x0 + 1], fx)
	return lerpf(a, b, fy)


func _build_land() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = hash(prov_id)
	noise.frequency = 0.0028
	noise.fractal_octaves = 4
	var ridge := FastNoiseLite.new()
	ridge.seed = hash(prov_id) + 5
	ridge.frequency = 0.0016
	ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridge.fractal_octaves = 5
	var size := REGION_R * 2.0 + 400.0
	_hgrid.resize(LAND_N * LAND_N)
	for y in LAND_N:
		for x in LAND_N:
			var pt := Vector2(x, y) / (LAND_N - 1) * size - Vector2(size, size) / 2.0
			_hgrid[y * LAND_N + x] = _raw_h(pt, noise, ridge)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in LAND_N:
		for x in LAND_N:
			var pt2 := Vector2(x, y) / (LAND_N - 1) * size - Vector2(size, size) / 2.0
			st.set_uv(Vector2(x, y) / (LAND_N - 1))
			st.add_vertex(Vector3(pt2.x, _hgrid[y * LAND_N + x] - 0.05, pt2.y))
	for y in LAND_N - 1:
		for x in LAND_N - 1:
			var i := y * LAND_N + x
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + LAND_N)
			st.add_index(i + 1)
			st.add_index(i + LAND_N + 1)
			st.add_index(i + LAND_N)
	st.generate_normals()
	var gm := MeshInstance3D.new()
	gm.mesh = st.commit()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/land.gdshader")
	var dt := NoiseTexture2D.new()
	var dn := FastNoiseLite.new()
	dn.frequency = 0.05
	dt.noise = dn
	dt.seamless = true
	dt.width = 256
	dt.height = 256
	sm.set_shader_parameter("detail", dt)
	sm.set_shader_parameter("detail_n", FX.normal_tex())
	sm.set_shader_parameter("grass", ground_col)
	sm.set_shader_parameter("dry", ground_col2.lerp(Color("#8a7a4a"), 0.5))
	sm.set_shader_parameter("desert", Geo.desert(_p()) if not desert else 0.9)
	gm.material_override = sm
	gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	static_root.add_child(gm)
	# tog' o'rmonlari (MultiMesh - minglab archalar tez chiziladi)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 4.0
	cone.height = 13.0
	cone.radial_segments = 7
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cone
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(prov_id) + 9
	var xs: Array = []
	for i in 2600:
		var pt3 := Vector2(rng.randf_range(-REGION_R, REGION_R), rng.randf_range(-REGION_R, REGION_R))
		if pt3.length() < AREA_R + 120.0:
			continue
		var hh := h_at(pt3)
		if hh < 25.0 or hh > 160.0 or desert:
			continue
		var k := rng.randf_range(0.7, 1.5)
		xs.append(Transform3D(Basis.from_scale(Vector3(k, k * rng.randf_range(0.9, 1.4), k)), Vector3(pt3.x, hh + 6.0 * k, pt3.y)))
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _mat("forest", Color("#24402a"), 0.9)
	static_root.add_child(mmi)
	# magistrallar (relyef ustidan)
	for hw in highways:
		_highway(hw[0], hw[1])


func _highway(a: Vector2, b: Vector2) -> void:
	## Asfalt avtomobil magistrali: 2 tasma, o'rtada chiziq, yoqasida tuproq; relyefga yopishgan bo'laklar
	var L := a.distance_to(b)
	var dir := (b - a) / L
	var yaw := atan2(dir.x, dir.y)
	var seg := 24.0
	var n := int(ceil(L / seg))
	for i in n:
		var p0 := a + dir * (i * seg)
		var p1 := a + dir * minf(L, (i + 1) * seg)
		var h0 := h_at(p0)
		var h1 := h_at(p1)
		var mid := (p0 + p1) / 2.0
		var len := p0.distance_to(p1) + 0.6
		var pitch := atan2(h1 - h0, len)
		var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -pitch)
		var sh := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(17.0, 0.1, len)
		sh.mesh = bm
		sh.material_override = _mat("dirt", Color("#8a7454"), 0.98)
		sh.transform = Transform3D(basis, Vector3(mid.x, (h0 + h1) / 2.0 + 0.04, mid.y))
		static_root.add_child(sh)
		var rd := MeshInstance3D.new()
		var bm2 := BoxMesh.new()
		bm2.size = Vector3(10.0, 0.14, len)
		rd.mesh = bm2
		rd.material_override = _mat("asphalt", Color("#3a3d40"), 0.9)
		rd.transform = Transform3D(basis, Vector3(mid.x, (h0 + h1) / 2.0 + 0.1, mid.y))
		static_root.add_child(rd)
		if i % 2 == 0:
			var ln := MeshInstance3D.new()
			var bm3 := BoxMesh.new()
			bm3.size = Vector3(0.3, 0.16, 8.0)
			ln.mesh = bm3
			ln.material_override = _mat("lane", Color("#e8e2c8"), 0.6)
			ln.transform = Transform3D(basis, Vector3(mid.x, (h0 + h1) / 2.0 + 0.12, mid.y))
			static_root.add_child(ln)


func _build_districts() -> void:
	## Tumanlar: pasttekislikdagi qishloq/shaharchalar (uylar, daraxtlar, nomi)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(prov_id) + 31
	var kinds := ["houses/house0", "houses/house1", "houses/house2", "houses/house3", "houses/house0", "houses/apt5", "houses/shop"]
	var trees: Array = ["nature/dead_tree", "nature/bush_dry"] if desert else ["nature/oak1", "nature/oak2", "nature/pine1", "nature/bush1"]
	for d in districts:
		var c: Vector2 = d["pos"]
		var placed: Array = []
		for k in 22:
			var hp := c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(15.0, 105.0)
			var ok := true
			for q in placed:
				if hp.distance_to(q) < 22.0:
					ok = false
					break
			for hw in highways:
				if _seg_dist(hp, hw[0], hw[1]) < 16.0:
					ok = false
			if not ok:
				continue
			var kd: String = kinds[rng.randi() % kinds.size()]
			var m := _model(kd, 0.0)
			if m == null:
				continue
			m.position = Vector3(hp.x, h_at(hp), hp.y)
			m.rotation.y = atan2((c - hp).x, (c - hp).y) + rng.randf_range(-0.2, 0.2)
			static_root.add_child(m)
			placed.append(hp)
		for k in 14:
			var tp := c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(90.0, 170.0)
			var pick: String = trees[rng.randi() % trees.size()]
			var t := _model(pick, 3.5 if pick.contains("bush") else rng.randf_range(10.0, 15.0))
			if t:
				t.position = Vector3(tp.x, h_at(tp), tp.y)
				static_root.add_child(t)
		var lbl := Label3D.new()
		lbl.text = String(d["name"]).to_upper() + " TUMANI"
		lbl.font_size = 110
		lbl.outline_size = 28
		lbl.pixel_size = 0.12
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.modulate = Color(1, 1, 1, 0.92)
		lbl.position = Vector3(c.x, h_at(c) + 45.0, c.y)
		static_root.add_child(lbl)


func add_child_env(we: WorldEnvironment) -> void:
	world.add_child(we)


func _build_world() -> void:
	world = Node3D.new()
	vp.add_child(world)
	var we := FX.environment(desert, ground_col)
	we.environment.fog_density = 0.00007
	add_child_env(we)
	world.add_child(FX.sun(1400.0))
	cam = Camera3D.new()
	cam.fov = 48.0
	cam.far = 9000.0
	world.add_child(cam)
	cam.make_current()

	static_root = Node3D.new()
	world.add_child(static_root)
	bld_root = Node3D.new()
	world.add_child(bld_root)
	unit_root = Node3D.new()
	world.add_child(unit_root)
	fx_root = Node3D.new()
	world.add_child(fx_root)

	# yer: kengaytirilgan viloyat relyefi (tog'li qirlar, pasttekislik tumanlari, yo'llar va temir yo'l)
	_plan_region()
	_build_land()
	_build_districts()
	# baza maydoni chegarasi (yengil halqa)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = AREA_R - 1.0
	tm.outer_radius = AREA_R + 1.0
	ring.mesh = tm
	ring.scale = Vector3(1, 0.05, 1)
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(1, 1, 1, 0.18)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = rm
	static_root.add_child(ring)

	# hokimiyat
	var hq := _model("buildings/hq", 0.0)
	if hq:
		_team_paint(hq)
		hq.rotation.y = 0.0
		static_root.add_child(hq)
	var lbl := Label3D.new()
	lbl.text = "HOKIMIYAT\n" + _p()["name"]
	lbl.font_size = 96
	lbl.outline_size = 24
	lbl.pixel_size = 0.05
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.position = Vector3(0, 32, 0)
	lbl.modulate = Color("#ffd166")
	static_root.add_child(lbl)



# ================================================================ o'zgaruvchan qism: binolar, yo'llar, uylar, qo'shin

func _signature() -> String:
	var p := _p()
	var s := ""
	for b in p["buildings"]:
		s += "%s%d|" % [b["type"], 1 if b["days_left"] <= 0 else 0]
	for st in Game.site_list(p):
		var u := Game.site_units(p, st["key"])
		s += "%s:%d,%d|" % [st["key"], roundi(u["soldier"] / 10.0), roundi(u["tank"])]
	return s


func _on_changed() -> void:
	_panel_dirty = true
	if not Game.provinces.has(prov_id) or _p()["owner"] != Game.PLAYER:
		_close()
		return
	_assign_positions()
	var s := _signature()
	if s != _sig:
		_rebuild_dynamic(false)


func _rebuild_dynamic(first: bool) -> void:
	_sig = _signature()
	for n in [bld_root, unit_root]:
		for c in n.get_children():
			c.queue_free()
	bld_nodes.clear()
	trucks.clear()
	var p := _p()
	var road_m := _mat("road", Color("#55575a"), 0.95)
	var houses_ok: Array = []
	for i in p["buildings"].size():
		var b: Dictionary = p["buildings"][i]
		var bp := Vector2(b["pos"][0], b["pos"][1])
		var node := Node3D.new()
		node.position = Vector3(bp.x, 0, bp.y)
		# binolar hokimiyatga qarab turadi
		node.rotation.y = atan2(bp.x, bp.y) + PI
		bld_root.add_child(node)
		var model := _model("buildings/" + b["type"], 0.0)
		if model:
			_team_paint(model)
			node.add_child(model)
		var entry := {"node": node, "b": b, "index": i, "model": model, "scaffold": null, "label": null}
		_setup_anims(entry)
		# yo'l
		var dir := bp.normalized()
		var a := dir * (HQ_R + 4.0)
		var c := bp - dir * (float(FOOT.get(b["type"], 22.0)) * 0.8)
		var len := a.distance_to(c)
		if len > 2.0:
			var mid := (a + c) / 2.0
			var yaw := atan2(dir.x, dir.y)
			var sh := _box(bld_root, Vector3(13.0, 0.08, len + 4.0), Vector3(mid.x, 0.04, mid.y), _mat("dirt", Color("#8a7454"), 0.98), yaw)
			sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var road := _box(bld_root, Vector3(7.5, 0.12, len), Vector3(mid.x, 0.07, mid.y), _mat("asphalt", Color("#3f4245"), 0.9), yaw)
			road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var dash := 0.0
			while dash < len - 3.0:
				var dp: Vector2 = a + dir * (dash + 1.5)
				_box(bld_root, Vector3(0.25, 0.14, 3.0), Vector3(dp.x, 0.08, dp.y), _mat("lane", Color("#e8e2c8"), 0.6), yaw)
				dash += 7.0
			if b["days_left"] <= 0:
				_spawn_truck(a, c)
				if randf() < 0.6:
					_spawn_truck(a, c)
		bld_nodes.append(entry)
	_update_construction()
	_build_town()
	_build_units()
	_place_sel_ring()


func _setup_anims(entry: Dictionary) -> void:
	var m: Node3D = entry["model"]
	if m == null:
		return
	entry["beam"] = _find(m, "Beam")
	entry["dish"] = _find(m, "Dish")
	entry["crane"] = _find(m, "Crane")
	var smokes: Array = _find_prefix(m, "Smoke", [])
	entry["smokes"] = []
	for s in smokes:
		var sp := _smoke(Color(0.85, 0.85, 0.85, 0.55), 3.5)
		sp.emitting = false
		s.add_child(sp)
		entry["smokes"].append(sp)


func _update_construction() -> void:
	for e in bld_nodes:
		var b: Dictionary = e["b"]
		var done: bool = b["days_left"] <= 0
		var total: float = maxf(1.0, float(b.get("days_total", Game.BUILDINGS[b["type"]]["days"])))
		var prog := clampf(1.0 - float(b["days_left"]) / total, 0.0, 1.0)
		if e["model"]:
			(e["model"] as Node3D).scale = Vector3(1, lerpf(0.12, 1.0, prog) if not done else 1.0, 1)
		for s in e.get("smokes", []):
			(s as GPUParticles3D).emitting = done
		if not done:
			if e["scaffold"] == null:
				e["scaffold"] = _scaffold(e["node"], float(FOOT.get(b["type"], 22.0)))
				var l := Label3D.new()
				l.font_size = 80
				l.outline_size = 20
				l.pixel_size = 0.06
				l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				l.no_depth_test = true
				l.position = Vector3(0, 24, 0)
				(e["node"] as Node3D).add_child(l)
				e["label"] = l
			(e["label"] as Label3D).text = "%s\nqurilmoqda %d%%  (%d kun)" % [Game.BUILDINGS[b["type"]]["name"], int(prog * 100), b["days_left"]]
		else:
			if e["scaffold"]:
				(e["scaffold"] as Node3D).queue_free()
				e["scaffold"] = null
			if e["label"]:
				(e["label"] as Node3D).queue_free()
				e["label"] = null


func _scaffold(parent: Node3D, r: float) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	var m := _mat("scaf", Color("#c8a040"), 0.7)
	var h := 12.0
	var s := r * 0.75
	for x in [-s, s]:
		for z in [-s, s]:
			_box(n, Vector3(0.5, h, 0.5), Vector3(x, h / 2, z), m)
	for y in [4.0, 8.0, 12.0]:
		_box(n, Vector3(s * 2, 0.4, 0.4), Vector3(0, y, -s), m)
		_box(n, Vector3(s * 2, 0.4, 0.4), Vector3(0, y, s), m)
		_box(n, Vector3(0.4, 0.4, s * 2), Vector3(-s, y, 0), m)
		_box(n, Vector3(0.4, 0.4, s * 2), Vector3(s, y, 0), m)
	# kran
	_box(n, Vector3(0.8, h + 10, 0.8), Vector3(s + 3, (h + 10) / 2, 0), _mat("crane", Color("#e0b030")))
	_box(n, Vector3(18, 0.8, 0.8), Vector3(s + 3 - 7, h + 10, 0), _mat("crane", Color("#e0b030")))
	n.set_meta("crane", true)
	return n


var town_root: Node3D
var _town_sig := ""
var rail_a := Vector2.ZERO
var rail_b := Vector2.ZERO
var train: Array = []
var _train_t := 0.0


func _build_town() -> void:
	## Shahar: yo'llar bo'ylab hovli uylar va ko'p qavatli uylar, do'konlar, baza ichida daraxtlar,
	## temir yo'l va poyezd, kon va zavod orasida quvurlar. Faqat binolar o'zgarganda qayta quriladi.
	var p := _p()
	var sig := ""
	for b in p["buildings"]:
		sig += "%s%.0f%.0f%d|" % [b["type"], b["pos"][0], b["pos"][1], 1 if b["days_left"] <= 0 else 0]
	for po in p.get("posts", []):
		sig += po["to"]
	if sig == _town_sig and town_root:
		return
	_town_sig = sig
	if town_root:
		town_root.queue_free()
	town_root = Node3D.new()
	world.add_child(town_root)
	train.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(prov_id) + 11
	# temir yo'l: viloyat bo'ylab (relyefda unga vodiy ochilgan)
	rng.randf()
	_build_rail(rail_a, rail_b)
	var placed: Array = []      # [joy, radius]
	for b in p["buildings"]:
		placed.append([Vector2(b["pos"][0], b["pos"][1]), float(FOOT.get(b["type"], 22.0)) + 6.0])
	placed.append([Vector2.ZERO, HQ_R + 10.0])
	# quvurlar: kon -> zavod (yo'llar yoqasi bo'ylab, hokimiyat atrofidan aylanib)
	var mines: Array = []
	var plants: Array = []
	for b in p["buildings"]:
		if b["days_left"] > 0:
			continue
		if b["type"] == "mine":
			mines.append([Vector2(b["pos"][0], b["pos"][1]), float(FOOT["mine"])])
		elif b["type"] == "civil" or b["type"] == "military":
			plants.append([Vector2(b["pos"][0], b["pos"][1]), float(FOOT[b["type"]])])
	for mm in mines:
		var best: Array = []
		var bd := INF
		for pl in plants:
			var dd: float = absf(angle_difference(mm[0].angle(), pl[0].angle()))
			if dd < bd:
				bd = dd
				best = pl
		if best.is_empty():
			continue
		var path := _pipe_path(mm[0], mm[1], best[0], best[1])
		for k in path.size() - 1:
			_pipe_seg(path[k], path[k + 1])
			var q: Vector2 = path[k]
			var steps := int(q.distance_to(path[k + 1]) / 8.0) + 1
			for t in steps:
				placed.append([q.lerp(path[k + 1], float(t) / steps), 5.0])
	# yo'llar bo'ylab uylar
	var roads: Array = []
	for b in p["buildings"]:
		roads.append(Vector2(b["pos"][0], b["pos"][1]))
	for po in p.get("posts", []):
		roads.append(_post_pos(po["to"]))
	var houses := ["houses/house0", "houses/house1", "houses/house2", "houses/house3"]
	for r in roads:
		var dir: Vector2 = r.normalized()
		var side := dir.orthogonal()
		var L: float = r.length()
		var t := HQ_R + 22.0
		while t < L - 30.0:
			for sgn in [-1.0, 1.0]:
				var c: Vector2 = dir * t + side * sgn * rng.randf_range(15.0, 19.0)
				var d0: float = c.length()
				var kind: String
				if d0 < 85.0:
					kind = "houses/apt9" if rng.randf() < 0.5 else "houses/apt5"
				elif rng.randf() < 0.08:
					kind = "houses/shop"
				elif rng.randf() < 0.06:
					kind = "houses/warehouse"
				else:
					kind = houses[rng.randi() % houses.size()]
				var rad := 15.0 if kind.contains("apt") else 9.0
				if not _free_for(c, rad, placed, roads):
					continue
				var m := _model(kind, 0.0)
				if m == null:
					continue
				m.position = Vector3(c.x, 0, c.y)
				# old tomoni yo'lga qaragan (model old tomoni -Y = Godot +Z)
				var face: Vector2 = -side * float(sgn)
				m.rotation.y = atan2(face.x, face.y)
				town_root.add_child(m)
				placed.append([c, rad])
			t += rng.randf_range(20.0, 27.0)
	# yo'llar orasidagi mahallalar: hovli uylar guruhlari
	var tries := 0
	var extra := 0
	while extra < 45 and tries < 900:
		tries += 1
		var hc := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(70.0, AREA_R + 10.0)
		if not _free_for(hc, 10.0, placed, roads):
			continue
		var kind2: String = houses[rng.randi() % houses.size()] if hc.length() > 95.0 or rng.randf() < 0.6 else "houses/apt5"
		var m2 := _model(kind2, 0.0)
		if m2 == null:
			continue
		m2.position = Vector3(hc.x, 0, hc.y)
		# uylar markazga (hokimiyatga) qarab, ko'chalar bo'ylab tekis turadi
		var ang := atan2(-hc.x, -hc.y)
		m2.rotation.y = snappedf(ang, PI / 2.0) + rng.randf_range(-0.05, 0.05)
		town_root.add_child(m2)
		placed.append([hc, 10.0 if not kind2.contains("apt") else 15.0])
		extra += 1
	# baza ichidagi va atrofidagi daraxtlar (guruh-guruh)
	var trees: Array = ["nature/dead_tree", "nature/bush_dry"] if desert else ["nature/oak1", "nature/oak2", "nature/pine1", "nature/pine2", "nature/bush1"]
	for g in 14:
		var gc := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(60.0, AREA_R)
		for k in rng.randi_range(3, 7):
			var tc := gc + Vector2(rng.randf_range(-16, 16), rng.randf_range(-16, 16))
			if not _free_for(tc, 4.0, placed, roads):
				continue
			var pick: String = trees[rng.randi() % trees.size()]
			var tm := _model(pick, (3.5 if pick.contains("bush") else rng.randf_range(10.0, 15.0)))
			if tm:
				tm.position = Vector3(tc.x, 0, tc.y)
				tm.rotation.y = rng.randf() * TAU
				town_root.add_child(tm)
	# ko'chalar chirog'i (hokimiyat atrofida)
	var lamp := _mat("lamp", Color("#3a3d42"), 0.5)
	for k in 12:
		var lp := Vector2.from_angle(k * TAU / 12.0 + 0.13) * (HQ_R + 7.0)
		_box(town_root, Vector3(0.3, 7.0, 0.3), Vector3(lp.x, 3.5, lp.y), lamp)
		_box(town_root, Vector3(1.6, 0.25, 0.4), Vector3(lp.x, 7.0, lp.y), lamp)


func _free_for(c: Vector2, r: float, placed: Array, roads: Array) -> bool:
	if c.length() > AREA_R + 25.0:
		return false
	for pl in placed:
		if c.distance_to(pl[0]) < r + float(pl[1]):
			return false
	for rd in roads:
		var dir: Vector2 = rd.normalized()
		var proj := c.dot(dir)
		if proj > 0.0 and proj < rd.length() and absf(c.dot(dir.orthogonal())) < r + 5.0:
			return false
	# temir yo'l ustiga qurmaslik
	var rd2 := (rail_b - rail_a).normalized()
	if absf((c - rail_a).dot(rd2.orthogonal())) < r + 8.0:
		return false
	return true


func _build_rail(a: Vector2, b: Vector2) -> void:
	var dir := (b - a).normalized()
	var L := a.distance_to(b)
	var yaw := atan2(dir.x, dir.y)
	var mid := (a + b) / 2.0
	# shag'al uyumi
	_box(town_root, Vector3(5.0, 0.35, L), Vector3(mid.x, 0.17, mid.y), _mat("ballast", Color("#6e6a62"), 0.95), yaw)
	# relslar
	var steel := _mat("rail", Color("#8a8d90"), 0.3)
	for s in [-0.75, 0.75]:
		var o: Vector2 = dir.orthogonal() * float(s)
		_box(town_root, Vector3(0.12, 0.18, L), Vector3(mid.x + o.x, 0.48, mid.y + o.y), steel, yaw)
	# shpallar (MultiMesh - tez chiziladi)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var sl := BoxMesh.new()
	sl.size = Vector3(2.6, 0.18, 0.3)
	mm.mesh = sl
	var n := int(L / 1.6)
	mm.instance_count = n
	for i in n:
		var pt := a + dir * (i * 1.6)
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw), Vector3(pt.x, 0.38, pt.y)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _mat("sleeper", Color("#4a3a2c"), 0.9)
	town_root.add_child(mmi)
	# poyezd: lokomotiv + 5 ta sisterna
	var loco := _model("units/locomotive", 0.0)
	if loco:
		town_root.add_child(loco)
		train.append(loco)
	for i in 5:
		var w := _model("units/wagon", 0.0)
		if w:
			town_root.add_child(w)
			train.append(w)


func _pipe_path(a: Vector2, ra: float, b: Vector2, rb: float) -> Array:
	## Quvur yo'li: kon yo'li yoqasidan ichkariga -> hokimiyat atrofida yoy -> zavod yo'li yoqasidan tashqariga
	var R := HQ_R + 16.0
	var da := a.normalized()
	var db := b.normalized()
	var oa := da.orthogonal() * 9.0
	var ob := db.orthogonal() * -9.0
	var pts: Array = [a - da * (ra + 2.0) + oa, da * R + oa]
	var a0 := (da * R + oa).angle()
	var a1 := (db * R + ob).angle()
	var diff := angle_difference(a0, a1)
	var n := maxi(2, int(absf(diff) * R / 10.0))
	for k in range(1, n):
		pts.append(Vector2.from_angle(a0 + diff * k / n) * R)
	pts.append(db * R + ob)
	pts.append(b - db * (rb + 2.0) + ob)
	return pts


func _pipe_seg(s0: Vector2, e0: Vector2) -> void:
	var L := s0.distance_to(e0)
	if L < 0.5:
		return
	var dir := (e0 - s0) / L
	var mid := (s0 + e0) / 2.0
	var pm := _mat("pipe", Color("#9aa3aa"), 0.35)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.6
	cm.bottom_radius = 0.6
	cm.height = L + 0.6
	mi.mesh = cm
	mi.material_override = pm
	mi.position = Vector3(mid.x, 2.2, mid.y)
	mi.rotation = Vector3(PI / 2, atan2(dir.x, dir.y), 0)
	town_root.add_child(mi)
	_box(town_root, Vector3(0.3, 2.2, 0.3), Vector3(s0.x, 1.1, s0.y), pm)


func _tick_train(delta: float) -> void:
	if train.is_empty():
		return
	_train_t += delta * 9.0
	var dir := (rail_b - rail_a).normalized()
	var L := rail_a.distance_to(rail_b)
	var head := fmod(_train_t, L + 200.0)
	for i in train.size():
		var d := head - i * 16.5
		var n: Node3D = train[i]
		n.visible = d > 0.0 and d < L
		var pt := rail_a + dir * clampf(d, 0.0, L)
		n.position = Vector3(pt.x, 0.5, pt.y)
		n.rotation.y = -atan2(dir.y, dir.x)


func _post_pos(nb: String) -> Vector2:
	## Chegara posti baza chetida - qo'shni viloyat tomonida (xaritadagi yo'nalish bo'yicha)
	var d: Vector2 = (Game.provinces[nb]["center"] - _p()["center"]).normalized()
	return d * (AREA_R + 18.0)


func site_pos(key: String) -> Vector2:
	## Garnizon nuqtasining 3D dagi joyi (qo'shin shu yerda turadi)
	var p := _p()
	if key.begins_with("post:"):
		var pp := _post_pos(key.substr(5))
		return pp - pp.normalized() * 34.0
	if key.begins_with("b"):
		var uid := int(key.substr(1))
		for b in p["buildings"]:
			if b.get("uid", -1) == uid:
				var bp := Vector2(b["pos"][0], b["pos"][1])
				return bp - bp.normalized() * (float(FOOT.get(b["type"], 22.0)) + 16.0)
	return Vector2(0, HQ_R + 26.0)


func _factory_pos() -> Vector2:
	for b in _p()["buildings"]:
		if b["type"] == "military" and b["days_left"] <= 0:
			var bp := Vector2(b["pos"][0], b["pos"][1])
			return bp - bp.normalized() * (float(FOOT["military"]) + 4.0)
	return Vector2(0, HQ_R + 10.0)


func _soldier_fig(anim: String) -> Node3D:
	var f := _model("units/soldier_rig", 1.8 * SOLDIER_SCALE)
	if f == null:
		f = _model("units/soldier", 1.8 * SOLDIER_SCALE)
	if f == null:
		return null
	_team_paint(f)
	var ap: AnimationPlayer = f.find_child("AnimationPlayer", true, false)
	if ap and ap.has_animation(anim):
		ap.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
		ap.play(anim)
		ap.seek(randf() * 1.2, true)
	return f


func _build_units() -> void:
	groups.clear()
	patrols.clear()
	var p := _p()
	# chegara postlari (baza chetida)
	for po in p.get("posts", []):
		var pp := _post_pos(po["to"])
		var pm := _model("buildings/post", 0.0)
		if pm:
			_team_paint(pm)
			pm.position = Vector3(pp.x, 0, pp.y)
			pm.rotation.y = atan2(pp.x, pp.y)
			if po["days_left"] > 0:
				pm.scale = Vector3(1, 0.3, 1)
			unit_root.add_child(pm)
		var road := pp.normalized()
		var a := road * (AREA_R - 4.0)
		var len := a.distance_to(pp - road * 14.0)
		_box(unit_root, Vector3(7.0, 0.12, len), Vector3((a.x + pp.x - road.x * 14.0) / 2.0, 0.06, (a.y + pp.y - road.y * 14.0) / 2.0), _mat("road", Color("#55575a"), 0.95), atan2(road.x, road.y))
		_group_label(unit_root, "CHEGARA: " + Game.provinces[po["to"]]["name"] + ("" if po["days_left"] <= 0 else " (quriladi)"), Vector3(pp.x, 22, pp.y))
		if po["days_left"] <= 0:
			_add_patrol(pp + road.orthogonal() * 12.0, pp - road.orthogonal() * 12.0)
	for st in Game.site_list(p):
		var u := Game.site_units(p, st["key"])
		var ns: float = u["soldier"]
		var nt: float = u["tank"]
		if st["type"] == "barracks":
			var bp := site_pos(st["key"])
			_add_patrol(bp + bp.normalized().orthogonal() * 18.0, bp - bp.normalized().orthogonal() * 18.0)
		if ns < 1.0 and nt < 1.0:
			continue
		var c := site_pos(st["key"])
		var g := Node3D.new()
		g.position = Vector3(c.x, 0, c.y)
		g.rotation.y = atan2(-c.x, -c.y) if st["type"] != "post" else atan2(c.x, c.y)
		unit_root.add_child(g)
		var figs := clampi(ceili(ns / 10.0), 0, 30)
		var cols := mini(8, maxi(1, figs))
		for i in figs:
			var f := _soldier_fig("Idle")
			if f == null:
				break
			f.position = Vector3((i % cols - cols / 2.0) * 3.2, 0, (i / cols) * 3.6)
			f.rotation.y = -PI / 2 + randf_range(-0.1, 0.1)
			g.add_child(f)
		var cnt := clampi(roundi(nt), 0, 12)
		var cols2 := mini(4, maxi(1, cnt))
		for i in cnt:
			var tk := _model("units/tank", TANK_SIZE)
			if tk == null:
				break
			tk.position = Vector3((i % cols2 - (cols2 - 1) / 2.0) * 7.0 + 30.0, 0, (i / cols2) * 12.0)
			tk.rotation.y = -PI / 2
			_team_paint(tk)
			g.add_child(tk)
		var txt := "%d askar" % roundi(ns) if ns >= 1.0 else ""
		if nt >= 1.0:
			txt += ("  |  " if txt != "" else "") + "%d tank" % roundi(nt)
		_group_label(g, txt, Vector3(8 if nt >= 1.0 else 0, 10, 4))
		groups["g:" + st["key"]] = {"node": g, "pos": c + (Vector2(c.normalized().orthogonal() * 8.0) if nt >= 1.0 else Vector2.ZERO), "site": st["key"], "r": 26.0 if nt >= 1.0 else 20.0}
	# milliy arsenal (faqat birinchi viloyatda ko'rinadi)
	if Game.player_provinces().size() > 0 and Game.player_provinces()[0] == prov_id:
		var base := Vector2(-70, HQ_R + 50.0)
		var k := 0
		for w in ["sam", "artillery", "apc", "drone"]:
			var n: int = Politics.arsenal.get(w, 0)
			if n <= 0:
				continue
			var nm: String = {"sam": "units/aa", "artillery": "units/artillery", "apc": "units/apc", "drone": "units/drone"}[w]
			for i in mini(n, 4):
				var m := _model(nm, 8.0)
				if m:
					m.position = Vector3(base.x + i * 9.0, 0, base.y + k * 13.0)
					m.rotation.y = -PI / 2
					_team_paint(m)
					unit_root.add_child(m)
			k += 1


# ---------------------------------------------------------------- yuruvchi askarlar, patrullar

var walkers: Array = []
var patrols: Array = []


func _add_patrol(a: Vector2, b: Vector2) -> void:
	for k in 2:
		var f := _soldier_fig("Walk")
		if f == null:
			return
		unit_root.add_child(f)
		patrols.append({"node": f, "a": a, "b": b, "t": k * 0.5, "dir": 1.0 if k == 0 else -1.0})


func _on_units_moved(id: String, from_key: String, to_key: String, s: int, t: int) -> void:
	if id != prov_id:
		return
	_spawn_walkers(site_pos(from_key), site_pos(to_key), s, t)


func _on_units_produced(id: String, unit: String, site: String) -> void:
	if id != prov_id:
		return
	_spawn_walkers(_factory_pos(), site_pos(site), 10 if unit == "soldier" else 0, 1 if unit == "tank" else 0)


func _spawn_walkers(a: Vector2, b: Vector2, s: int, t: int) -> void:
	## Zavoddan kazarmaga / kazarmadan chegaraga yurib boradigan askarlar va tanklar
	var n := clampi(ceili(s / 10.0), 0, 14)
	var dir := (b - a).normalized()
	var side := dir.orthogonal()
	for i in n:
		var f := _soldier_fig("Run" if a.distance_to(b) > 120.0 else "Walk")
		if f == null:
			break
		fx_root.add_child(f)
		var off := side * ((i % 3) - 1) * 3.0 - dir * (i / 3) * 3.5
		walkers.append({"node": f, "a": a + off, "b": b + off, "t": 0.0, "speed": 7.0 if a.distance_to(b) > 120.0 else 4.5, "kind": "s"})
	for i in mini(t, 6):
		var tk := _model("units/tank", TANK_SIZE)
		if tk == null:
			break
		_team_paint(tk)
		fx_root.add_child(tk)
		var off2 := side * 6.0 - dir * (14.0 + i * 13.0)
		walkers.append({"node": tk, "a": a + off2, "b": b + off2, "t": 0.0, "speed": 8.0, "kind": "t"})


func _tick_walkers(delta: float) -> void:
	for w in walkers.duplicate():
		var n: Node3D = w["node"]
		if not is_instance_valid(n):
			walkers.erase(w)
			continue
		var a: Vector2 = w["a"]
		var b: Vector2 = w["b"]
		var L := maxf(1.0, a.distance_to(b))
		w["t"] += delta * float(w["speed"]) / L
		var pos := a.lerp(b, minf(1.0, w["t"]))
		n.position = Vector3(pos.x, 0, pos.y)
		var d := b - a
		# modellar +X tomonga qaragan
		n.rotation.y = -atan2(d.y, d.x)
		if w["t"] >= 1.0:
			n.queue_free()
			walkers.erase(w)
	for pt in patrols:
		var n2: Node3D = pt["node"]
		if not is_instance_valid(n2):
			continue
		var a2: Vector2 = pt["a"]
		var b2: Vector2 = pt["b"]
		pt["t"] += delta * 2.2 / maxf(1.0, a2.distance_to(b2)) * pt["dir"]
		if pt["t"] > 1.0 or pt["t"] < 0.0:
			pt["dir"] *= -1.0
			pt["t"] = clampf(pt["t"], 0.0, 1.0)
		var pos2 := a2.lerp(b2, pt["t"])
		n2.position = Vector3(pos2.x, 0, pos2.y)
		var d2: Vector2 = (b2 - a2) * float(pt["dir"])
		n2.rotation.y = -atan2(d2.y, d2.x)


func _group_label(parent: Node3D, text: String, pos: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 90
	l.outline_size = 22
	l.pixel_size = 0.05
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.modulate = Color("#ffd166")
	l.position = pos
	parent.add_child(l)


# ================================================================ jonlantirish: mashinalar, samolyotlar, animatsiyalar

func _spawn_truck(a: Vector2, b: Vector2) -> void:
	var n := Node3D.new()
	unit_root.add_child(n)
	var veh := _model("units/truck" if randf() < 0.55 else "units/car", 0.0)
	if veh:
		# model +X tomonga qaragan, harakat +Z bo'ylab hisoblanadi
		veh.rotation.y = -PI / 2
		n.add_child(veh)
		var d := FX.dust(0.8)
		d.position = Vector3(0, 0.4, -4.0)
		d.emitting = true
		n.add_child(d)
	else:
		_box(n, Vector3(2.5, 2.8, 8.0), Vector3(0, 1.9, 0), _mat("truck", Color("#6a6f4a")))
	trucks.append({"node": n, "a": a, "b": b, "t": randf(), "dir": 1.0 if randf() < 0.5 else -1.0, "speed": 0.05 + randf() * 0.03})


func _spawn_flight() -> void:
	var cands: Array = []
	for e in bld_nodes:
		var b: Dictionary = e["b"]
		if b["days_left"] <= 0 and (b["type"] == "airport" or b["type"] == "airbase"):
			cands.append(e)
	if cands.is_empty():
		return
	var e2: Dictionary = cands[randi() % cands.size()]
	var node: Node3D = e2["node"]
	var plane: Node3D
	if e2["b"]["type"] == "airbase":
		plane = _model("units/jet", 15.0)
	else:
		plane = _airliner()
	if plane == null:
		return
	_team_paint(plane)
	fx_root.add_child(plane)
	var landing := randf() < 0.4
	flights.append({"node": plane, "base": node, "t": 0.0, "landing": landing})


func _airliner() -> Node3D:
	var m := _model("units/airliner", 0.0)
	if m:
		return m
	var n := Node3D.new()
	var w := _mat("white", Color("#eeeeea"), 0.5)
	var f := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.6
	cm.bottom_radius = 1.6
	cm.height = 28.0
	f.mesh = cm
	f.material_override = w
	f.rotation.z = PI / 2
	f.position.y = 3.0
	n.add_child(f)
	_box(n, Vector3(5, 0.4, 30), Vector3(-1, 2.6, 0), w)
	_box(n, Vector3(3, 0.3, 10), Vector3(-12.5, 3.6, 0), w)
	var fin := _box(n, Vector3(4, 6, 0.4), Vector3(-12.5, 6.5, 0), _mat("team", Color("#e8b73a"), 0.5))
	fin.name = "TeamColor"
	return n


func _process(delta: float) -> void:
	_anim_t += delta
	_camera_keys(delta)
	_update_camera()
	if money_label:
		money_label.text = "%s $   |   %s" % [_fmt(int(Game.money)), Game.date_text()]
	# animatsiyalar
	for e in bld_nodes:
		if e["b"]["days_left"] > 0:
			if e["scaffold"]:
				(e["scaffold"] as Node3D).rotation.y = sin(_anim_t * 0.3) * 0.03
			continue
		if e.get("beam"):
			(e["beam"] as Node3D).rotation.z = sin(_anim_t * 1.6) * 0.32
		if e.get("dish"):
			(e["dish"] as Node3D).rotation.y = _anim_t * 0.8
		if e.get("crane"):
			(e["crane"] as Node3D).rotation.y = sin(_anim_t * 0.25) * 0.9
	if Engine.get_process_frames() % 30 == 0:
		_update_construction()
	_tick_walkers(delta)
	_tick_train(delta)
	# mashinalar
	for t in trucks:
		if not is_instance_valid(t["node"]):
			continue
		t["t"] += t["dir"] * delta * t["speed"]
		if t["t"] > 1.0 or t["t"] < 0.0:
			t["dir"] *= -1.0
			t["t"] = clampf(t["t"], 0.0, 1.0)
		var a: Vector2 = t["a"]
		var b: Vector2 = t["b"]
		var side: Vector2 = (b - a).normalized().orthogonal() * (1.9 * float(t["dir"]))
		var pos: Vector2 = a.lerp(b, t["t"]) + side
		var n: Node3D = t["node"]
		n.position = Vector3(pos.x, 0, pos.y)
		var d: Vector2 = (b - a) * t["dir"]
		n.rotation.y = atan2(d.x, d.y)
	# samolyotlar
	_flight_t -= delta
	if _flight_t <= 0.0:
		_flight_t = randf_range(14.0, 26.0)
		_spawn_flight()
	for f in flights.duplicate():
		f["t"] += delta
		if not is_instance_valid(f["base"]) or not is_instance_valid(f["node"]):
			if is_instance_valid(f["node"]):
				f["node"].queue_free()
			flights.erase(f)
			continue
		var base: Node3D = f["base"]
		var plane: Node3D = f["node"]
		var t2: float = f["t"]
		var tt := t2 if not f["landing"] else maxf(0.0, 14.0 - t2)
		# uchish: uchish yo'lagi bo'ylab tezlanish, keyin ko'tarilish
		var x := -45.0 + 3.0 * tt * tt
		var y := 0.3 + maxf(0.0, x - 25.0) * 0.28
		var local := Vector3(x, y, 0)
		plane.global_transform = Transform3D(base.global_transform.basis, base.global_transform * local)
		plane.rotate_object_local(Vector3(0, 0, 1), clampf((y - 0.3) * 0.02, 0.0, 0.18) * (1.0 if not f["landing"] else 1.0))
		if t2 > 14.0:
			plane.queue_free()
			flights.erase(f)


# ================================================================ kamera va sichqoncha

func _update_camera() -> void:
	var pitch := deg_to_rad(cam_pitch)
	var off := Vector3(0, sin(pitch), cos(pitch)) * cam_dist
	off = Basis(Vector3.UP, cam_yaw) * off
	cam.position = cam_target + off
	cam.look_at(cam_target, Vector3.UP)


func _camera_keys(delta: float) -> void:
	var mv := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): mv.z -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): mv.z += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): mv.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): mv.x += 1
	if mv != Vector3.ZERO:
		cam_target += Basis(Vector3.UP, cam_yaw) * mv.normalized() * cam_dist * 0.9 * delta
	if Input.is_key_pressed(KEY_Q): cam_yaw += 1.2 * delta
	if Input.is_key_pressed(KEY_E): cam_yaw -= 1.2 * delta
	cam_target.x = clampf(cam_target.x, -REGION_R, REGION_R)
	cam_target.z = clampf(cam_target.z, -REGION_R, REGION_R)
	cam_target.y = h_at(Vector2(cam_target.x, cam_target.z))


func ground_at(screen: Vector2) -> Vector2:
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	if absf(d.y) < 0.0001:
		return Vector2(1e6, 1e6)
	var t := -o.y / d.y
	var v := o + d * t
	return Vector2(v.x, v.z)


func _input_3d(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = clampf(cam_dist / 1.12, 30.0, 1900.0)
			cam_pitch = lerpf(28.0, 62.0, clampf((cam_dist - 30.0) / 900.0, 0.0, 1.0))
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = clampf(cam_dist * 1.12, 30.0, 1900.0)
			cam_pitch = lerpf(28.0, 62.0, clampf((cam_dist - 30.0) / 900.0, 0.0, 1.0))
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_mid_drag = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if placing != "":
				_cancel_place()
			else:
				_select("")
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_click(mb.position)
	elif e is InputEventMouseMotion:
		var mm := e as InputEventMouseMotion
		if _mid_drag:
			cam_target -= Basis(Vector3.UP, cam_yaw) * Vector3(mm.relative.x, 0, mm.relative.y) * cam_dist * 0.0022
		if placing != "" and ghost:
			_move_ghost(mm.position)


func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		if placing != "":
			_cancel_place()
		elif selected != "":
			_select("")
		else:
			_close()


func _click(sp: Vector2) -> void:
	var g := ground_at(sp)
	if placing != "":
		if ghost_ok:
			Game.build(prov_id, placing, g)
			_cancel_place()
		return
	# qaysi obyekt bosildi
	if g.length() < HQ_R + 4.0:
		_select("hq")
		return
	for k in groups:
		var gr: Dictionary = groups[k]
		if g.distance_to(gr["pos"]) < gr["r"]:
			_select(k)
			return
	var p := _p()
	for i in p["buildings"].size():
		var b: Dictionary = p["buildings"][i]
		var bp := Vector2(b["pos"][0], b["pos"][1])
		if g.distance_to(bp) < float(FOOT.get(b["type"], 22.0)):
			_select("b:%d" % i)
			return
	_select("")


func _select(s: String) -> void:
	selected = s
	_place_sel_ring()
	_panel_dirty = true


func _place_sel_ring() -> void:
	if sel_ring == null:
		sel_ring = MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.94
		tm.outer_radius = 1.0
		sel_ring.mesh = tm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("#ffd166")
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sel_ring.material_override = m
		fx_root.add_child(sel_ring)
	var pos := Vector2.ZERO
	var r := 0.0
	if selected == "hq":
		r = HQ_R + 4.0
	elif groups.has(selected):
		pos = groups[selected]["pos"]
		r = groups[selected]["r"]
	elif selected.begins_with("b:"):
		var i := int(selected.substr(2))
		var p := _p()
		if i < p["buildings"].size():
			var b: Dictionary = p["buildings"][i]
			pos = Vector2(b["pos"][0], b["pos"][1])
			r = float(FOOT.get(b["type"], 22.0)) + 3.0
	sel_ring.visible = r > 0.0
	sel_ring.position = Vector3(pos.x, 0.4, pos.y)
	sel_ring.scale = Vector3(r, 1.0, r)


# ================================================================ joylashtirish (ghost)

func _start_place(type: String) -> void:
	if Game.can_build(prov_id, type) != "":
		return
	_cancel_place()
	placing = type
	ghost = _model("buildings/" + type, 0.0)
	if ghost == null:
		ghost = Node3D.new()
		_box(ghost, Vector3(30, 10, 30), Vector3(0, 5, 0), _mat("g", Color.WHITE))
	world.add_child(ghost)
	_ghost_mat(ghost, Color(0.4, 1.0, 0.5, 0.45))
	tip.text = "Binoni joylashtiring: chap tugma - qurish, o'ng tugma / Esc - bekor qilish"


func _ghost_mat(root: Node, col: Color) -> void:
	var m := _mats.get("ghost_%s" % col.to_html()) as StandardMaterial3D
	if m == null:
		m = StandardMaterial3D.new()
		m.albedo_color = col
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mats["ghost_%s" % col.to_html()] = m
	for mi in _meshes_of(root, []):
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _move_ghost(sp: Vector2) -> void:
	var g := ground_at(sp)
	ghost.position = Vector3(g.x, 0.2, g.y)
	ghost.rotation.y = atan2(g.x, g.y) + PI
	var ok := _spot_free(g, float(FOOT.get(placing, 22.0)), -1)
	if ok != ghost_ok:
		ghost_ok = ok
		_ghost_mat(ghost, Color(0.4, 1.0, 0.5, 0.45) if ok else Color(1.0, 0.3, 0.3, 0.45))


func _cancel_place() -> void:
	placing = ""
	ghost_ok = false
	if ghost:
		ghost.queue_free()
		ghost = null
	tip.text = TIP


# ================================================================ HUD

const TIP := "Hokimiyatni bosing - qurilish.  Binoni / qo'shinni bosing - boshqarish.  G'ildirak: yaqinlashtirish   O'rta tugma / WASD: surish   Q/E: aylantirish   Esc: chiqish"


func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_parent().add_child(hud)
	var cont := SubViewportContainer.new()
	cont.set_anchors_preset(Control.PRESET_FULL_RECT)
	cont.stretch = true
	cont.mouse_filter = Control.MOUSE_FILTER_STOP
	cont.gui_input.connect(_input_3d)
	hud.add_child(cont)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.handle_input_locally = false
	cont.add_child(vp)

	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 8
	bar.offset_right = -8
	bar.offset_top = 8
	bar.add_theme_stylebox_override("panel", UIKit.style(Color(0.05, 0.08, 0.12, 0.55), 12, Color(0.6, 0.8, 1.0, 0.22), 10))
	hud.add_child(bar)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	bar.add_child(h)
	var p := _p()
	h.add_child(UIKit.flag(p["country"], 36))
	top_label = UIKit.label("VILOYAT BAZASI: " + p["name"], 19, Color.WHITE)
	h.add_child(top_label)
	money_label = UIKit.label("", 15, UIKit.GOLD)
	money_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(money_label)
	var grp := ButtonGroup.new()
	for s in [0, 1, 2, 5]:
		var b := Button.new()
		b.text = "||" if s == 0 else "%dx" % s
		b.toggle_mode = true
		b.button_group = grp
		b.button_pressed = Game.speed == s
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(Game.set_speed.bind(s))
		h.add_child(b)
	var back := UIKit.button(h, "  Xaritaga qaytish  ", "", _close, true)
	back.focus_mode = Control.FOCUS_NONE

	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -400
	panel.offset_right = -8
	panel.offset_top = 70
	panel.offset_bottom = -48
	panel.add_theme_stylebox_override("panel", UIKit.style(Color(0.05, 0.08, 0.12, 0.55), 16, Color(0.6, 0.8, 1.0, 0.22), 12))
	hud.add_child(panel)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(sc)
	panel_box = VBoxContainer.new()
	panel_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_box.add_theme_constant_override("separation", 8)
	sc.add_child(panel_box)

	tip = Label.new()
	tip.text = TIP
	tip.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	tip.offset_left = 14
	tip.offset_top = -34
	tip.add_theme_font_size_override("font_size", 14)
	tip.add_theme_color_override("font_outline_color", Color.BLACK)
	tip.add_theme_constant_override("outline_size", 5)
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(tip)
	set_process_internal(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_INTERNAL_PROCESS and _panel_dirty and panel_box:
		_panel_dirty = false
		_rebuild_panel()


func _rebuild_panel() -> void:
	UIKit.clear(panel_box)
	var p := _p()
	if selected == "hq":
		_panel_hq(p)
	elif selected.begins_with("g:"):
		_panel_army(p)
	elif selected.begins_with("b:"):
		var i := int(selected.substr(2))
		if i < p["buildings"].size():
			_panel_building(p, i)
		else:
			_panel_overview(p)
	else:
		_panel_overview(p)


func _panel_overview(p: Dictionary) -> void:
	panel_box.add_child(UIKit.label(p["name"], 22, Color.WHITE))
	var inc := Game.province_income(p)
	panel_box.add_child(UIKit.label("Aholi: %.1f mln   |   Norozilik: %d%%" % [p["population"] / 1000.0, int(p["unrest"])], 14))
	panel_box.add_child(UIKit.label("Ish o'rinlari: %d / %d" % [Game.jobs(p), Game.jobs_needed(p)], 14, UIKit.GOOD if Game.jobs(p) >= Game.jobs_needed(p) else UIKit.BAD))
	panel_box.add_child(UIKit.label("Kunlik: %+d $" % int(inc["total"]), 15, UIKit.GOOD if inc["total"] >= 0 else UIKit.BAD))
	panel_box.add_child(UIKit.label("Binolar: %d / %d" % [p["buildings"].size(), Game.MAX_BUILDINGS], 14))
	panel_box.add_child(UIKit.label("Qo'shin: %d askar, %d tank   |   mahalliy mudofaa %d / %d" % [roundi(p["units"]["soldier"]), roundi(p["units"]["tank"]), int(p["militia"]), int(War.militia_cap(p))], 14))
	panel_box.add_child(HSeparator.new())
	panel_box.add_child(UIKit.label("Hokimiyat binosini bosing - yangi bino qurish menyusi ochiladi. Bino joyini o'zingiz tanlaysiz.", 14, UIKit.GOLD, true))
	panel_box.add_child(UIKit.label("Askar yoki tanklar ustiga bosing - kerakli sonini tanlab boshqa viloyatga jo'natasiz.", 14, UIKit.DIM, true))
	UIKit.button(panel_box, "Qurilish menyusi", "", _select.bind("hq"), true)


func _panel_hq(p: Dictionary) -> void:
	panel_box.add_child(UIKit.label("HOKIMIYAT - qurilish", 20, Color.WHITE))
	panel_box.add_child(UIKit.label("Binoni tanlang, keyin xaritada joyini ko'rsating. Pul: %s $" % _fmt(int(Game.money)), 13, UIKit.DIM, true))
	for t in Game.BUILDINGS:
		var d: Dictionary = Game.BUILDINGS[t]
		var why := Game.can_build(prov_id, t)
		var c := UIKit.card(panel_box, UIKit.CARD2)
		var h := UIKit.row(c, 10)
		h.add_child(UIKit.pic(d["icon"], Vector2(38, 38)))
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		v.add_child(UIKit.label(d["name"], 15, Color.WHITE))
		v.add_child(UIKit.label("%d $  |  %d kun  |  %+d $/kun  |  %d ish o'rni" % [d["cost"], d["days"], int(d["income"]), d["jobs"]], 12, UIKit.GOLD))
		c.add_child(UIKit.label(d["desc"], 12, UIKit.DIM, true))
		var b := UIKit.button(c, "Joylashtirish" if why == "" else why, why, _start_place.bind(t), why == "")
		b.focus_mode = Control.FOCUS_NONE


func _panel_building(p: Dictionary, i: int) -> void:
	var b: Dictionary = p["buildings"][i]
	var d: Dictionary = Game.BUILDINGS[b["type"]]
	var h := UIKit.row(panel_box, 10)
	h.add_child(UIKit.pic(d["icon"], Vector2(44, 44)))
	h.add_child(UIKit.label(d["name"], 21, Color.WHITE))
	panel_box.add_child(UIKit.label(d["desc"], 13, UIKit.DIM, true))
	if b["days_left"] > 0:
		panel_box.add_child(UIKit.label("Qurilmoqda: %d kun qoldi" % b["days_left"], 15, UIKit.GOLD))
		return
	panel_box.add_child(UIKit.label("Daromad: %+d $/kun   Ish o'rni: %d" % [int(d["income"]), d["jobs"]], 14))
	if b["type"] == "mine":
		var o := Game.output(p)
		var parts: Array = []
		for r in o:
			parts.append("%s %.1f %s" % [Game.RESOURCE_NAMES[r], o[r], Game.RESOURCE_UNIT[r]])
		panel_box.add_child(UIKit.label("Kunlik qazib olish: " + (", ".join(parts) if parts.size() else "resurs yo'q"), 14, UIKit.GOOD, true))
	# ishlab chiqarish
	var units_here: Array = []
	for u in Game.UNITS:
		if Game.unit_building(u) == b["type"]:
			units_here.append(u)
	if units_here.size() > 0 or b["type"] == "military":
		_production(p, b["type"], units_here)
	if (b["type"] == "barracks" or b["type"] == "depot") and b.has("uid") and groups.has("g:b%d" % b["uid"]):
		UIKit.button(panel_box, "Bu yerdagi qo'shinni boshqarish", "", _select.bind("g:b%d" % b["uid"]), true)


const UNIT_PIC := {"soldier": "soldier", "guard": "soldier", "para": "soldier", "tank": "mbt", "plane": "jet", "missile": "missile", "nuke": "missile"}
const SECTIONS := [["Piyoda qo'shin", ["soldier", "guard", "para"]], ["Tanklar", ["tank"]], ["Havo kuchlari", ["plane"]], ["Raketalar", ["missile", "nuke"]]]


func _production(p: Dictionary, btype: String, units_here: Array) -> void:
	# navbat (Generals uslubida: belgi + soni + jarayon)
	panel_box.add_child(HSeparator.new())
	panel_box.add_child(UIKit.label("Ishlab chiqarish navbati", 17, Color.WHITE))
	var q := UIKit.row(panel_box, 6)
	var any := false
	for i in p["orders"].size():
		var o: Dictionary = p["orders"][i]
		if Game.unit_building(o["unit"]) != btype:
			continue
		any = true
		var def: Dictionary = Game.UNITS[o["unit"]]
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		q.add_child(cell)
		var pic := UIKit.weapon_pic(UNIT_PIC.get(o["unit"], "soldier"), Vector2(64, 42))
		cell.add_child(pic)
		var badge := UIKit.label("x%d" % (int(def["batch"]) * int(o.get("count", 1))), 14, UIKit.GOLD)
		badge.add_theme_color_override("font_outline_color", Color.BLACK)
		badge.add_theme_constant_override("outline_size", 4)
		badge.position = Vector2(2, 0)
		pic.add_child(badge)
		var pb := ProgressBar.new()
		pb.show_percentage = false
		pb.custom_minimum_size = Vector2(64, 6)
		var tot := maxf(1.0, float(o.get("days_total", def["days"])))
		pb.value = 100.0 * (1.0 - float(o["days_left"]) / tot) if Game.order_active(p, i) else 0.0
		cell.add_child(pb)
	if not any:
		panel_box.add_child(UIKit.label("Navbat bo'sh", 12, UIKit.DIM))
	if btype == "military":
		for sec in SECTIONS:
			var list: Array = []
			for u in sec[1]:
				if u in units_here:
					list.append(u)
			if list.is_empty():
				continue
			panel_box.add_child(UIKit.label(sec[0], 16, UIKit.GOLD))
			for u in list:
				_unit_card(u)
		# litsenziyali qurollar (Siyosat orqali)
		var lic: Array = Politics.licenses.keys()
		if lic.size() > 0:
			panel_box.add_child(UIKit.label("Litsenziyali qurollar", 16, UIKit.GOLD))
			for w in lic:
				var wd: Dictionary = Politics.weapon(w)
				var c := UIKit.card(panel_box, UIKit.CARD2)
				var h := UIKit.row(c, 8)
				h.add_child(UIKit.weapon_pic(w, Vector2(110, 68)))
				var v := VBoxContainer.new()
				v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				h.add_child(v)
				v.add_child(UIKit.label(wd["name"], 14, Color.WHITE))
				v.add_child(UIKit.label("%d $/dona  |  arsenalda %d" % [Politics.produce_cost(w), Politics.arsenal[w]], 12, UIKit.GOLD))
				var bh := UIKit.row(v, 4)
				for n in [1, 5]:
					var bb := UIKit.button(bh, "+%d" % n, Politics.why_produce(w, n), Politics.produce.bind(w, n), n == 1)
					bb.focus_mode = Control.FOCUS_NONE
	else:
		for u in units_here:
			_unit_card(u)


func _unit_card(u: String) -> void:
	var def: Dictionary = Game.UNITS[u]
	var c := UIKit.card(panel_box, UIKit.CARD2)
	var h := UIKit.row(c, 8)
	h.add_child(UIKit.weapon_pic(UNIT_PIC.get(u, "soldier"), Vector2(110, 68)))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UIKit.label(def["name"], 15, Color.WHITE))
	var extra := ""
	if def.has("fort"): extra = "  mudofaa +%d" % int(def["fort"])
	if def.has("mult"): extra = "  kuch x%.1f" % float(def["mult"])
	v.add_child(UIKit.label("%d $ / %d ta  |  %d kun%s" % [def["cost"], def["batch"], def["days"], extra], 12, UIKit.GOLD))
	var bh := UIKit.row(v, 4)
	var opts := [[1, "x%d" % def["batch"]], [10, "x%d" % (def["batch"] * 10)]] if def["batch"] >= 10 else [[1, "x1"], [5, "x5"]]
	for o in opts:
		var why := Game.can_order(prov_id, u, o[0])
		var b := UIKit.button(bh, o[1], why, Game.order_unit.bind(prov_id, u, o[0]), o[0] == 1)
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(60, 0)
	var why1 := Game.can_order(prov_id, u, 1)
	if why1 != "" and why1 != "Pul yetmaydi":
		c.add_child(UIKit.label(why1, 12, UIKit.BAD, true))


var _send_s: HSlider
var _send_t: HSlider
var _send_lbl: Label


func _panel_army(p: Dictionary) -> void:
	var key: String = groups[selected]["site"] if groups.has(selected) else "hq"
	var u := Game.site_units(p, key)
	var ns := roundi(u["soldier"])
	var nt := roundi(u["tank"])
	panel_box.add_child(UIKit.label(Game.site_name(p, key).to_upper(), 20, Color.WHITE))
	panel_box.add_child(UIKit.label("Bu yerda: %d askar, %d tank. Viloyat bo'yicha jami: %d askar, %d tank." % [ns, nt, roundi(p["units"]["soldier"]), roundi(p["units"]["tank"])], 13, UIKit.DIM, true))
	var g := UIKit.grid(panel_box, 2)
	g.add_child(UIKit.weapon_pic("soldier", Vector2(80, 60)))
	var v1 := VBoxContainer.new()
	v1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_child(v1)
	v1.add_child(UIKit.label("Askar", 14, Color.WHITE))
	_send_s = HSlider.new()
	_send_s.max_value = ns
	_send_s.step = 10 if ns >= 20 else 1
	_send_s.value = ns
	_send_s.custom_minimum_size = Vector2(200, 24)
	_send_s.value_changed.connect(func(_v): _upd_send())
	v1.add_child(_send_s)
	g.add_child(UIKit.weapon_pic("mbt", Vector2(90, 60)))
	var v2 := VBoxContainer.new()
	v2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_child(v2)
	v2.add_child(UIKit.label("Tank", 14, Color.WHITE))
	_send_t = HSlider.new()
	_send_t.max_value = nt
	_send_t.step = 1
	_send_t.value = nt
	_send_t.custom_minimum_size = Vector2(200, 24)
	_send_t.value_changed.connect(func(_v): _upd_send())
	v2.add_child(_send_t)
	_send_lbl = UIKit.label("", 16, UIKit.GOLD)
	panel_box.add_child(_send_lbl)
	_upd_send()
	panel_box.add_child(HSeparator.new())
	panel_box.add_child(UIKit.label("Viloyat ichida jo'natish (askarlar yurib boradi):", 15, Color.WHITE))
	for st in Game.site_list(p):
		if st["key"] == key:
			continue
		var b := UIKit.button(panel_box, "-> " + st["name"], "" if ns + nt > 0 else "Qo'shin yo'q",
			func(): Game.move_units(prov_id, key, st["key"], int(_send_s.value), int(_send_t.value)), st["type"] == "post")
		b.focus_mode = Control.FOCUS_NONE
	if Game.site_list(p).size() <= 1:
		panel_box.add_child(UIKit.label("Boshqa joy yo'q: kazarma, tank parki yoki chegara posti quring.", 13, UIKit.GOLD, true))
	panel_box.add_child(HSeparator.new())
	if key.begins_with("post:"):
		var nb := key.substr(5)
		panel_box.add_child(UIKit.label("Chegara orqali %s ga hujum (urush holatida) yoki chegara rejimi:" % Game.provinces[nb]["name"], 13, UIKit.DIM, true))
		UIKit.button(panel_box, "Chegara oynasini ochish", "", func(): Game.open_border.emit(prov_id, nb), true)
	else:
		UIKit.button(panel_box, "Boshqa viloyatga (xaritada tanlash)", "" if ns + nt > 0 else "Qo'shin yo'q", _send_go)
		panel_box.add_child(UIKit.label("Eslatma: chet davlatga hujum faqat chegara postida to'plangan qo'shin bilan.", 12, UIKit.DIM, true))


func _upd_send() -> void:
	if _send_lbl:
		_send_lbl.text = "Jo'natiladi: %d askar, %d tank" % [int(_send_s.value), int(_send_t.value)]


func _send_go() -> void:
	var s := int(_send_s.value)
	var t := int(_send_t.value)
	if s + t <= 0:
		return
	var id := prov_id
	_close()
	Game.select(id)
	War.begin_target(id, "army", {"soldier": s, "tank": t})
	Game.message.emit("%d askar va %d tank: xaritada boradigan viloyatni bosing (Esc - bekor qilish)." % [s, t], "info")


func _close() -> void:
	if Game.changed.is_connected(_on_changed):
		Game.changed.disconnect(_on_changed)
	if Game.units_moved.is_connected(_on_units_moved):
		Game.units_moved.disconnect(_on_units_moved)
		Game.units_produced.disconnect(_on_units_produced)
	if hud:
		hud.queue_free()
	closed.emit()
	queue_free()


func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = " " + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if n < 0 else "") + s + out
