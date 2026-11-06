extends Node
## 1-zamon: QAL'A QURUVCHI (3D).
## O'yinchi qal'ani o'zi loyihalaydi: devorni sichqoncha bilan chizadi, minora, darvoza, xandaq va ichki binolarni qo'yadi.
## Har o'zgarishdan keyin "Mudofaa tahlili" hisoblanadi: qal'a yopiqmi, ichki maydon va sig'adigan askar soni,
## minorasiz "ko'r" devorlar va qaysi tomon (shimol / sharq / janub / g'arb) eng zaif.

signal closed
signal exit_requested        # o'yinchi uzoqlashib ketdi - xaritaga silliq qaytish

const GRID := 2.0
const AREA := 150.0                 # qurish mumkin bo'lgan hudud (markazdan har tomonga, metr)
const WALL_H := 7.0
const TOWER_COVER := 24.0           # minoradagi kamonchilar devorni shu masofagacha yondan o'qqa tutadi
const NAMES := {"wall": "Devor", "moat": "Xandaq", "tower": "Minora", "gate": "Darvoza", "barracks": "Kazarma",
	"granary": "Ombor", "well": "Quduq", "smithy": "Temirchi", "stable": "Otxona", "delete": "Buzish",
	"farm": "Bug'doy", "lumber": "O'tinxona", "quarry": "Tosh koni", "market": "Bozor", "mint": "Zarbxona",
	"mosque": "Masjid", "house": "Uylar", "torch": "Mash'al", "ustaxona": "Qamal ustaxonasi"}
const ROW1 := ["wall", "tower", "gate", "moat", "barracks", "granary", "well", "smithy", "stable", "ustaxona", "mosque", "torch", "delete"]
const ROW2 := ["farm", "lumber", "quarry", "market", "mint", "house"]
const MAX_FIG := 160
const ROW_W := 10          # saf kengligi (figura)
const TIPS := {"wall": "Devor: 1-bosish - boshlanish, keyingi bosishlar - devorni davom ettirish. O'ng tugma / Esc - tugatish. Uchlariga minora o'zi qo'yiladi. (%d oltin/m)",
	"moat": "Xandaq: devor tashqarisidan chizing - dushmanni sekinlashtiradi. O'ng tugma / Esc - tugatish. (%d oltin/m)",
	"tower": "Minora: devor burchagi yoki o'rtasiga qo'ying. Minoradagi kamonchilar %d m gacha devorni himoya qiladi.",
	"gate": "Darvoza: mavjud devorni bosing. Darvoza - eng zaif joy, lekin askarlar shu yerdan chiqadi.",
	"delete": "Buzish: obyektni bosing (narxining yarmi qaytadi).",
	"torch": "Mash'al (gulxan): istalgan joyni bosing - kechasi atrofni yoritadi. Minora, devor va binolar oldida mash'allar o'zi yonadi."}
const FOOT := {"barracks": Vector2(17, 9), "granary": Vector2(11, 9), "well": Vector2(4, 3), "smithy": Vector2(9, 7),
	"stable": Vector2(15, 8), "keep": Vector2(24, 24), "farm": Vector2(22, 15), "lumber": Vector2(12, 10),
	"quarry": Vector2(14, 12), "market": Vector2(16, 12), "mint": Vector2(11, 11),
	"mosque": Vector2(17, 15), "house": Vector2(7, 8), "ustaxona": Vector2(15, 11)}
const SECT := ["Shimol", "Sharq", "Janub", "G'arb"]

var prov_id := ""
var data: Dictionary
var hud: Control
var vp: SubViewport
var world: Node3D
var build_root: Node3D
var ghost_root: Node3D
var cam: Camera3D
var daynight: DayNight
var cam_target := Vector3(0, 0, 10)
var cam_dist := 150.0
var _tdist := 150.0             # silliq yaqinlashish uchun maqsad masofa
var cam_yaw := 0.4
var _mid := false
var _lmb := false               # chap tugma bosilgan (sudrash yoki bosish)
var _rmb := false
var _drag_moved := false
var _press_at := Vector2.ZERO
var _leaving := false
const MAX_DIST := 420.0
var tool := ""
var has_start := false
var chain_start := Vector3.ZERO
var rot := 0.0
var mouse_pt := Vector3.ZERO
var stats := {}
var _scenes := {}
var tool_btns := {}
var money_label: Label
var tip_label: Label
var stats_box: VBoxContainer
var msg_label: Label
var _ghost_mat: StandardMaterial3D
var _bad_mat: StandardMaterial3D
var army_root: Node3D
var army_box: VBoxContainer
var figs := {}            # tur -> [Node3D]
var slots: Array = []
var _army_t := 0.0
var guards: Array = []        # devor va minoradagi soqchilar (jonli harakat)
var _initial := true
var _g_out := PackedByteArray()
var _g_blk := PackedByteArray()
var _g_n := 0
var _g_half := 0
var rts: CastleRTS             # askarlarni sichqoncha bilan boshqarish
var _gate_doors: Array = []
var _bld_box: Array = []       # binolarning haqiqiy o'lchami (lokal AABB)
var _bld_pts: Array = []       # binolar yuzasidagi nuqtalar (lokal) - mash'alni devorga yopishtirish uchun


# ================================================================ boshlash

func setup(id: String) -> void:
	prov_id = id
	var p: Dictionary = Game.provinces[id]
	if not p.has("castle"):
		p["castle"] = {"keep": [0.0, 0.0], "walls": [], "towers": [], "gates": [], "moats": [], "buildings": []}
	data = CastleEco.castle(p)
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.albedo_color = Color(0.4, 1.0, 0.5, 0.35)
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bad_mat = _ghost_mat.duplicate()
	_bad_mat.albedo_color = Color(1.0, 0.3, 0.25, 0.45)
	_build_hud()
	_build_world()
	army_root = Node3D.new()
	world.add_child(army_root)
	rts = CastleRTS.new()
	add_child(rts)
	rts.setup(self)
	_build_ctx()
	_rebuild()
	Game.changed.connect(_show_army)
	_show_army()


func _p() -> Dictionary:
	return Game.provinces[prov_id]


func _model_file(n: String) -> String:
	## davlat madaniyatiga xos qal'a (kreml, ritsar qal'asi, xitoy, arab, bastion) va binolar
	if n == "ustaxona":
		return "res://models/castle/ustaxona.glb" if ResourceLoader.exists("res://models/castle/ustaxona.glb") else Unit3D.castle_file(_p()["country"], "lumber")
	return Unit3D.castle_file(_p()["country"], n)


func _scene(n: String) -> PackedScene:
	if not _scenes.has(n):
		_scenes[n] = load(_model_file(n))
	return _scenes[n]


func _inst(n: String) -> Node3D:
	var s := _scene(n)
	var o: Node3D = s.instantiate()
	FX.pbr(o)
	Unit3D.recolor(o, Color(Game.countries[_p()["country"]]["color"]))
	return o


func _build_world() -> void:
	world = Node3D.new()
	vp.add_child(world)
	var wenv := FX.environment(false, Color("#8a8a5a"))
	world.add_child(wenv)
	var wsun := FX.sun(500.0)
	world.add_child(wsun)
	daynight = DayNight.new()
	world.add_child(daynight)
	daynight.set_meta("env", wenv)
	daynight.set_meta("sun", wsun)
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(14000, 14000)
	pm.subdivide_width = 4
	pm.subdivide_depth = 4
	g.mesh = pm
	var gm := FX.ground_material(Color("#5f6236"), Color("#7a7046"), 3)
	gm.roughness = 1.0
	gm.metallic_specular = 0.05
	g.material_override = gm
	world.add_child(g)
	# qurish hududi chegarasi (ingichka chiziq)
	var edge := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	var em := StandardMaterial3D.new()
	em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	em.albedo_color = Color(1, 1, 1, 0.35)
	em.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, em)
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1)]:
		im.surface_add_vertex(Vector3(c.x * AREA, 0.15, c.y * AREA))
	im.surface_end()
	edge.mesh = im
	world.add_child(edge)
	# atrofdagi tepaliklar (viloyat tog'liligiga qarab) va daraxtlar
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(prov_id)
	var mount := Geo.mountain(_p())
	var hill_mat := FX.ground_material(Color("#5a5a34"), Color("#746a45"), 5)
	hill_mat.roughness = 1.0
	hill_mat.metallic_specular = 0.05
	for i in 26:
		var a := rng.randf() * TAU
		var r := rng.randf_range(AREA + 90, 600)
		var h := MeshInstance3D.new()
		var sm := SphereMesh.new()
		var rad := rng.randf_range(40, 110)
		sm.radius = rad
		sm.height = rad * 2.0
		h.mesh = sm
		h.material_override = hill_mat
		h.scale = Vector3(1, (0.12 + mount * 0.9) * rng.randf_range(0.6, 1.3), 1)
		h.position = Vector3(cos(a) * r, -rad * h.scale.y * 0.35, sin(a) * r)
		world.add_child(h)
	for i in 60:
		var a := rng.randf() * TAU
		var r := rng.randf_range(AREA + 25, 420)
		var nm: String = ["oak1", "oak2", "pine1", "bush1", "bush_dry"][rng.randi() % 5]
		var path := "res://models/nature/%s.glb" % nm
		if ResourceLoader.exists(path):
			var t: Node3D = load(path).instantiate()
			t.position = Vector3(cos(a) * r, 0, sin(a) * r)
			var s := rng.randf_range(3.0, 6.0)
			t.scale = Vector3(s, s, s)
			t.rotation.y = rng.randf() * TAU
			world.add_child(t)
	build_root = Node3D.new()
	world.add_child(build_root)
	ghost_root = Node3D.new()
	world.add_child(ghost_root)
	cam = Camera3D.new()
	cam.fov = 50
	cam.far = 9000
	world.add_child(cam)
	_apply_cam()
	daynight.setup(daynight.get_meta("env"), daynight.get_meta("sun"), cam, Unit3D.is_muslim(_p()["country"]))
	daynight.prayer.connect(func(n: String): _msg("Azon: %s namozi vaqti" % n))
	_rebuild_lights()


var _fp_pitch := 0.0
var _fps := false
var _base_fov := 50.0


func _apply_cam() -> void:
	# qo'mondon: juda yaqinlashtirilsa - uning ko'zi bilan (birinchi shaxs) ko'rinish
	var fps := walk_mode and cam_dist < 2.6 and cmdr != null and is_instance_valid(cmdr)
	if fps != _fps:
		_fps = fps
		if cmdr != null and is_instance_valid(cmdr):
			cmdr.visible = not fps
	if fps:
		var fwd := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
		var horse := Unit3D.rider_of(cmdr) != null
		cam.position = cmdr.position + Vector3(0, 2.75 if horse else 1.68, 0) + fwd * 0.2
		cam.look_at(cam.position + fwd + Vector3(0, tan(_fp_pitch), 0), Vector3.UP)
		cam.fov = 70.0
		return
	cam.fov = _base_fov
	var pitch := deg_to_rad(lerpf(30.0, 62.0, clampf((cam_dist - 20.0) / 380.0, 0.0, 1.0)))
	var off := Vector3(sin(cam_yaw) * cos(pitch), sin(pitch), cos(cam_yaw) * cos(pitch)) * cam_dist
	cam.position = cam_target + off
	cam.look_at(cam_target + Vector3(0, 2, 0), Vector3.UP)


# ================================================================ geometriya

func _v(a: Array) -> Vector3:
	return Vector3(float(a[0]), 0.0, float(a[1]))


func _keep() -> Vector3:
	return _v(data["keep"])


func _snap(p: Vector3) -> Vector3:
	# mavjud devor uchlari va minoralarga yopishadi, bo'lmasa 2 m to'rga
	var best := Vector3.INF
	var bd := 4.0
	for w in data["walls"]:
		for e in [_v(w["a"]), _v(w["b"])]:
			var d: float = (e as Vector3).distance_to(p)
			if d < bd:
				bd = d
				best = e
	for t in data["towers"]:
		var d := _v(t["p"]).distance_to(p)
		if d < bd:
			bd = d
			best = _v(t["p"])
	if best != Vector3.INF:
		return best
	return Vector3(snappedf(p.x, GRID), 0, snappedf(p.z, GRID))


func _in_area(p: Vector3) -> bool:
	return absf(p.x) <= AREA and absf(p.z) <= AREA


func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(0.0001, ab.length_squared()), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _orient(a: Vector3, b: Vector3) -> float:
	## modulning +X o'qi a->b bo'ylab, tashqi tomoni (+Z) arkdan uzoqqa qaraydigan burchak
	var d := (b - a).normalized()
	var ang := atan2(-d.z, d.x)
	var outer := Vector3(sin(ang), 0, cos(ang))
	if outer.dot((a + b) * 0.5 - _keep()) < 0.0:
		ang += PI
	return ang


func _gate_near(p: Vector3, r: float) -> bool:
	for g in data["gates"]:
		if _v(g["p"]).distance_to(p) < r:
			return true
	return false


# ================================================================ chizish

func _torch(p: Vector3, col := Color(1.0, 0.62, 0.3), rng := 16.0, flame := 1.0) -> void:
	## mash'al yorug'ligi: kechasi yonadi (alanga va nur), kunduzi o'chadi
	if daynight.torches.size() >= 90:
		return
	var l := OmniLight3D.new()
	l.position = p
	l.light_color = col
	l.omni_range = rng
	l.light_energy = 0.0
	l.shadow_enabled = false
	build_root.add_child(l)
	daynight.torches.append(l)
	if flame > 0.0:
		l.add_child(_flame(flame))


var _flame_mat: StandardMaterial3D


func _flame(s: float) -> CPUParticles3D:
	## jonli alanga: yuqoriga ko'tarilib so'nadigan yorqin zarrachalar
	var p := CPUParticles3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.34, 0.42) * s
	if _flame_mat == null:
		_flame_mat = StandardMaterial3D.new()
		_flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flame_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_flame_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_flame_mat.vertex_color_use_as_albedo = true
		var gt := GradientTexture2D.new()
		var gr := Gradient.new()
		gr.set_color(0, Color(1, 1, 1, 1))
		gr.set_color(1, Color(1, 1, 1, 0))
		gt.gradient = gr
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(0.5, 0.0)
		_flame_mat.albedo_texture = gt
	qm.material = _flame_mat
	p.mesh = qm
	p.amount = 12
	p.lifetime = 0.5
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.1 * s
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0, 1.6, 0)
	p.initial_velocity_min = 0.5 * s
	p.initial_velocity_max = 0.9 * s
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.8))
	sc.add_point(Vector2(0.3, 1.0))
	sc.add_point(Vector2(1, 0.15))
	p.scale_amount_curve = sc
	var cg := Gradient.new()
	cg.set_color(0, Color(1.0, 0.72, 0.28, 0.75))
	cg.add_point(0.35, Color(1.0, 0.42, 0.08, 0.6))
	cg.set_color(cg.get_point_count() - 1, Color(0.7, 0.15, 0.05, 0.0))
	p.color_ramp = cg
	p.position = Vector3(0, -0.15, 0)
	return p


func _door_mesh(at: Vector3, yaw: float, w: float, h: float) -> void:
	## yog'och eshik (temir tasmalar bilan) va uning ustidagi tosh ravoq
	var root := Node3D.new()
	root.position = at
	root.rotation.y = yaw
	build_root.add_child(root)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("#5a3a1e")
	var leaf := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, h, 0.18)
	leaf.mesh = bm
	leaf.material_override = wood
	leaf.position.y = h * 0.5
	root.add_child(leaf)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color("#2a2826")
	iron.metallic = 0.7
	for yy in [0.25, 0.75]:
		var band := MeshInstance3D.new()
		var bb := BoxMesh.new()
		bb.size = Vector3(w + 0.04, 0.1, 0.22)
		band.mesh = bb
		band.material_override = iron
		band.position.y = h * yy
		root.add_child(band)
	var arch := MeshInstance3D.new()
	var ab := BoxMesh.new()
	ab.size = Vector3(w + 0.5, 0.35, 0.3)
	arch.mesh = ab
	var am := StandardMaterial3D.new()
	am.albedo_color = Color("#9a8a6a")
	arch.material_override = am
	arch.position.y = h + 0.17
	root.add_child(arch)


func _tower_doors(tp: Vector3) -> void:
	## minora: pastda hovli tomonga eshik; tepada devor yo'laklariga chiqadigan eshiklar
	var r := 3.25
	var inn := _keep() - tp
	inn.y = 0
	inn = inn.normalized() if inn.length() > 0.1 else Vector3(0, 0, 1)
	_door_mesh(tp + inn * r, atan2(inn.x, inn.z), 1.6, 2.6)
	for w in data["walls"]:
		var a := _v(w["a"])
		var b := _v(w["b"])
		var other := Vector3.INF
		if a.distance_to(tp) < 3.5:
			other = b
		elif b.distance_to(tp) < 3.5:
			other = a
		if other == Vector3.INF:
			continue
		var d := (other - tp)
		d.y = 0
		d = d.normalized()
		_door_mesh(tp + d * r + Vector3(0, WALL_H + 0.05, 0), atan2(d.x, d.z), 1.4, 2.2)


func _pole_torch(p: Vector3) -> void:
	## yerga qoqilgan mash'al ustuni: yog'och ustun, temir savatcha, alanga
	var root := Node3D.new()
	root.position = p
	build_root.add_child(root)
	var pole := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.07
	cm.bottom_radius = 0.1
	cm.height = 2.6
	pole.mesh = cm
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color("#4a2e18")
	pole.material_override = wm
	pole.position.y = 1.3
	root.add_child(pole)
	var cage := MeshInstance3D.new()
	var cc := CylinderMesh.new()
	cc.top_radius = 0.2
	cc.bottom_radius = 0.1
	cc.height = 0.3
	cage.mesh = cc
	var im := StandardMaterial3D.new()
	im.albedo_color = Color("#262422")
	im.metallic = 0.7
	cage.material_override = im
	cage.position.y = 2.7
	root.add_child(cage)
	_torch(p + Vector3(0, 3.0, 0), Color(1.0, 0.62, 0.3), 14.0, 0.9)


func _brazier(p: Vector3) -> void:
	## temir qozonli gulxan (yerda yoki minora tepasida)
	var sc := _scene("torch")
	if sc:
		var o: Node3D = sc.instantiate()
		o.position = p
		build_root.add_child(o)
	_torch(p + Vector3(0, 1.55, 0), Color(1.0, 0.6, 0.28), 18.0, 0.95)


func _local_points(o: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	var inv := o.global_transform.affine_inverse()
	for mi in o.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if m.mesh == null:
			continue
		var xf: Transform3D = inv * m.global_transform
		var faces := m.mesh.get_faces()
		for i in range(0, faces.size(), 3):
			# uchburchak markazi va uchlari
			var a: Vector3 = xf * faces[i]
			var b: Vector3 = xf * faces[i + 1]
			var c2: Vector3 = xf * faces[i + 2]
			out.append(a)
			out.append((a + b + c2) / 3.0)
	return out


func _surface_z(pts: PackedVector3Array, x: float, y: float, fallback: float) -> float:
	## binoning old yuzasi: shu (x, y) atrofidagi eng oldingi nuqta (lokal +Z)
	var best := -1e9
	for q in pts:
		if absf(q.x - x) < 0.7 and absf(q.y - y) < 0.7:
			best = maxf(best, q.z)
	return best if best > -1e8 else fallback


func _wall_torch(p: Vector3, yaw: float) -> void:
	## devorga osilgan mash'al: temir ilgak va tayoq uchida alanga
	var root := Node3D.new()
	root.position = p
	root.rotation.y = yaw
	build_root.add_child(root)
	var stick := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.06
	cm.bottom_radius = 0.04
	cm.height = 0.7
	stick.mesh = cm
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color("#4a2e18")
	stick.material_override = wm
	stick.rotation.z = -0.35
	stick.position = Vector3(0.12, 0, 0)
	root.add_child(stick)
	# devorga qoqilgan temir taglik va ilgak (mash'al devorga yopishib turadi)
	var im0 := StandardMaterial3D.new()
	im0.albedo_color = Color("#2a2826")
	im0.metallic = 0.7
	for part in [[Vector3(0.04, 0.34, 0.16), Vector3(0.0, -0.05, 0)], [Vector3(0.16, 0.04, 0.04), Vector3(0.07, -0.12, 0)]]:
		var br := MeshInstance3D.new()
		var bbm := BoxMesh.new()
		bbm.size = part[0]
		br.mesh = bbm
		br.material_override = im0
		br.position = part[1]
		root.add_child(br)
	var head := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.1
	hm.bottom_radius = 0.07
	hm.height = 0.16
	head.mesh = hm
	var im := StandardMaterial3D.new()
	im.albedo_color = Color("#2a2826")
	im.metallic = 0.7
	head.material_override = im
	head.position = Vector3(0.24, 0.34, 0)
	root.add_child(head)
	_torch(p + Basis(Vector3.UP, yaw) * Vector3(0.24, 0.55, 0), Color(1.0, 0.62, 0.3), 12.0, 0.8)


func _rebuild_lights() -> void:
	## tungi mash'alalar (darvoza, ark, masjid) va azon aytiladigan minora joyi
	if daynight == null or build_root == null:
		return
	daynight.torches.clear()
	daynight.minaret_pos = null
	_torch(_keep() + Vector3(0, 4, 13))
	for g in data["gates"]:
		var outer := Vector3(sin(float(g["ang"])), 0, cos(float(g["ang"])))
		_torch(_v(g["p"]) + outer * 3.0 + Vector3(0, 4.5, 0))
	for b in data["buildings"]:
		if b["t"] == "mosque":
			var r := float(b["rot"])
			var off := Basis(Vector3.UP, r) * Vector3(6.8, 0, 3.4)
			daynight.minaret_pos = _v(b["p"]) + off + Vector3(0, 20, 0)
	# o'yinchi qo'ygan gulxanlar
	for t in data.get("torches", []):
		_brazier(_v(t))
	# darvozaning ikki tomonida (ichkari va tashqarida) tik mash'al ustunlari
	for g in data["gates"]:
		var ang := float(g["ang"])
		var outer := Vector3(sin(ang), 0, cos(ang))
		var along := Vector3(cos(ang), 0, -sin(ang))
		for sgn in [-1.0, 1.0]:
			for side in [-1.0, 1.0]:
				_pole_torch(_v(g["p"]) + outer * 4.2 * side + along * 3.6 * sgn)
	# ark eshigi oldida ikki ustun
	var kf: Vector2 = FOOT["keep"]
	for sgn in [-1.0, 1.0]:
		_pole_torch(_keep() + Vector3(sgn * 3.2, 0, kf.y * 0.5 + 1.5))
	# minoralar tepasida gulxan
	var top := float(Unit3D.STYLE_TOP.get(Unit3D.castle_style(_p()["country"]), 11.65))
	for t in data["towers"]:
		var tp := _v(t["p"])
		var out := (tp - _keep())
		out.y = 0
		out = out.normalized() if out.length() > 0.1 else Vector3(1, 0, 0)
		_brazier(tp + out.rotated(Vector3.UP, 1.2) * 1.8 + Vector3(0, top, 0))
	# devor ichki tomonida har ~22 m da mash'al
	var kp := _keep()
	var nwt := 0
	for w in data["walls"]:
		var a := _v(w["a"])
		var b := _v(w["b"])
		var L := a.distance_to(b)
		var dir := (b - a) / maxf(0.1, L)
		var nrm := Vector3(-dir.z, 0, dir.x)
		if nrm.dot(kp - (a + b) * 0.5) < 0.0:
			nrm = -nrm
		var n := int(L / 22.0)
		for i in n:
			if nwt >= 18:
				break
			var q := a + dir * (L * (float(i) + 0.5) / float(n))
			if _gate_near(q, 6.0):
				continue
			_wall_torch(q + nrm * 1.62 + Vector3(0, 4.6, 0), atan2(-nrm.z, nrm.x))
			nwt += 1
	# binolar eshigi oldida ikki tomonda mash'al
	for bi in data["buildings"].size():
		var b: Dictionary = data["buildings"][bi]
		if not b["t"] in ["barracks", "mosque", "smithy", "stable", "granary", "market", "mint", "house"]:
			continue
		var r2 := float(b["rot"])
		var bs: Basis = Basis(Vector3.UP, r2)
		var fwd := bs * Vector3(0, 0, 1)
		var f: Vector2 = FOOT.get(b["t"], Vector2(8, 8))
		var front := f.y * 0.5
		var hx := f.x * 0.3
		var hy := 2.4
		if bi < _bld_box.size() and (_bld_box[bi] as AABB).size.x > 0.5:
			var bx: AABB = _bld_box[bi]
			front = bx.end.z
			hx = minf(2.4, bx.size.x * 0.28)
			hy = clampf(bx.size.y * 0.45, 1.6, 3.2)
		for s in ([-1.0, 1.0] if b["t"] != "house" else [1.0]):
			var fz := front
			if bi < _bld_pts.size():
				fz = _surface_z(_bld_pts[bi], s * hx, hy, front)
			# ilgak devorga tegib turadi: mash'al tayog'i devordan 0.25 m chiqadi
			_wall_torch(_v(b["p"]) + bs * Vector3(s * hx, hy, fz + 0.02), atan2(-fwd.z, fwd.x))

func _rebuild() -> void:
	for c in build_root.get_children():
		c.queue_free()
	guards.clear()
	var k := _inst("keep")
	k.position = _keep()
	build_root.add_child(k)
	_live_flags(k, false)
	# ark tepasida o'yinchi bayrog'i
	var top := 0.0
	for mi in k.find_children("*", "MeshInstance3D", true, false):
		var bb: AABB = (mi as MeshInstance3D).get_aabb()
		top = maxf(top, bb.end.y * (mi as Node3D).global_transform.basis.get_scale().y if (mi as Node3D).is_inside_tree() else bb.end.y)
	var std := Unit3D.standard(Color(Game.countries[_p()["country"]]["color"]) if Game.countries.has(_p()["country"]) else Color.GREEN, 6.0)
	std.scale = Vector3.ONE * 1.5
	std.position = _keep() + Vector3(0, maxf(top, 6.0), 0)
	build_root.add_child(std)
	for w in data["walls"]:
		_draw_wall(_v(w["a"]), _v(w["b"]), "wall", 4.0)
	for m in data["moats"]:
		_draw_wall(_v(m["a"]), _v(m["b"]), "moat", 4.0)
	for t in data["towers"]:
		var o := _inst("tower")
		o.position = _v(t["p"])
		var away := o.position - _keep()
		if Unit3D.castle_style(_p()["country"]) == "bastion" and away.length() > 0.5:
			o.rotation.y = atan2(away.x, away.z)        # bastion uchi tashqariga qaraydi
		build_root.add_child(o)
		_live_flags(o)
		_tower_doors(o.position)
		# minora tepasida soqchi (1-zamonda kamonchi, 2-zamonda miltiqli sarboz): atrofni kuzatadi
		var u := Unit3D.soldier(Unit3D.faction_for(_p()["country"]), "sarboz" if Game.era == 2 else "kamonchi", Color(Game.countries[_p()["country"]]["color"]))
		if u:
			var ttop := float(Unit3D.STYLE_TOP.get(Unit3D.castle_style(_p()["country"]), 11.65))
			var base := atan2(o.position.x - _keep().x, o.position.z - _keep().z) - PI / 2.0
			u.rotation.y = base
			build_root.add_child(u)
			_add_guard(u, base, "tower")
			var gd: Dictionary = guards[guards.size() - 1]
			gd["c"] = o.position + Vector3(0, ttop, 0)
			gd["ang"] = randf() * TAU
			gd["walk"] = 0.0
			u.position = gd["c"] + Vector3(cos(gd["ang"]), 0, sin(gd["ang"])) * 2.1
	# devor ustida qorovullar yuradi (devor yo'lagi bo'ylab u yoqdan bu yoqqa)
	var wi := 0
	for w in data["walls"]:
		var a := _v(w["a"])
		var b := _v(w["b"])
		var Lw := a.distance_to(b)
		if Lw < 10.0 or wi >= 30:
			continue
		# devor uzunligiga qarab 2-3 qorovul, har biri o'z bo'lagida u yoqdan bu yoqqa yuradi
		var ng := clampi(int(Lw / 18.0) + 1, 2, 3) if Lw >= 20.0 else 1
		for gi in ng:
			var kind: String = "sarboz" if Game.era == 2 else ["nayzachi", "qilichboz", "kamonchi"][(wi + gi) % 3]
			var u2 := Unit3D.soldier(Unit3D.faction_for(_p()["country"]), kind, Color(Game.countries[_p()["country"]]["color"]))
			if u2:
				build_root.add_child(u2)
				var t0 := 0.08 + 0.84 * float(gi) / float(ng)
				var t1 := 0.08 + 0.84 * float(gi + 1) / float(ng)
				var g0 := {"node": u2, "mode": "patrol", "a": a.lerp(b, t0), "b": a.lerp(b, t1), "t": randf(), "dir": 1.0 if randf() < 0.5 else -1.0, "wait": randf() * 2.0}
				guards.append(g0)
				Unit3D.play(u2, "Walk")
			wi += 1
	for g in data["gates"]:
		var o := _inst("gate")
		o.position = _v(g["p"])
		o.rotation.y = float(g["ang"])
		build_root.add_child(o)
		_live_flags(o)
		for s in [-1.0, 1.0]:
			var u := Unit3D.soldier(Unit3D.faction_for(_p()["country"]), "nayzachi", Color(Game.countries[_p()["country"]]["color"]))
			if u:
				var outer := Vector3(sin(float(g["ang"])), 0, cos(float(g["ang"])))
				var along := Vector3(cos(float(g["ang"])), 0, -sin(float(g["ang"])))
				u.position = o.position - outer * 3.5 + along * s * 2.2
				u.rotation.y = float(g["ang"]) - PI / 2.0
				build_root.add_child(u)
				_add_guard(u, u.rotation.y, "gate")
	_bld_box.clear()
	_bld_pts.clear()
	for b in data["buildings"]:
		var o := _inst(b["t"])
		o.position = _v(b["p"])
		o.rotation.y = float(b["rot"])
		build_root.add_child(o)
		# modelning haqiqiy o'lchami (mash'allar devorga yopishib tursin)
		var bx := AABB()
		var first := true
		var inv := o.global_transform.affine_inverse()
		for mi in o.find_children("*", "MeshInstance3D", true, false):
			var ab: AABB = inv * (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			bx = ab if first else bx.merge(ab)
			first = false
		_bld_box.append(bx)
		_bld_pts.append(_local_points(o))
		_live_flags(o)
	_rebuild_lights()
	_analyze()
	_make_slots()
	_refresh_army(true)
	if rts:
		rts.rebuild_nav()
		rts._refresh_ui()
	_rebuild_gate_doors()


func _rebuild_gate_doors() -> void:
	## darvoza tavaqalari: ikki qanot, ilgaklarda ichkariga ochiladi / yopiladi
	for d in _gate_doors:
		if is_instance_valid(d):
			d.queue_free()
	_gate_doors.clear()
	var open := bool(data.get("gate_open", true))
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("#5a3a1e")
	wood.roughness = 0.9
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color("#2a2a2c")
	iron.metallic = 0.7
	for g in data["gates"]:
		var root := Node3D.new()
		root.position = _v(g["p"])
		root.rotation.y = float(g["ang"])
		build_root.add_child(root)
		_gate_doors.append(root)
		for sgn in [-1.0, 1.0]:
			var pivot := Node3D.new()
			pivot.name = "L" if sgn < 0 else "R"
			pivot.position = Vector3(sgn * 2.3, 0, -0.1)
			root.add_child(pivot)
			var leaf := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(2.28, 5.2, 0.28)
			leaf.mesh = bm
			leaf.material_override = wood
			leaf.position = Vector3(-sgn * 1.14, 2.6, 0)
			pivot.add_child(leaf)
			for yy in [-1.7, 0.0, 1.7]:
				var band := MeshInstance3D.new()
				var bb := BoxMesh.new()
				bb.size = Vector3(2.3, 0.2, 0.34)
				band.mesh = bb
				band.material_override = iron
				band.position = Vector3(0, yy, 0)
				leaf.add_child(band)
			pivot.rotation.y = (-sgn * PI * 0.47) if open else 0.0


func animate_gates() -> void:
	## darvozani ochish/yopish animatsiyasi (qanotlar sekin buriladi)
	var open := bool(data.get("gate_open", true))
	for root in _gate_doors:
		if not is_instance_valid(root):
			continue
		for nm in ["L", "R"]:
			var pv: Node3D = (root as Node3D).get_node_or_null(nm)
			if pv == null:
				continue
			var sgn := -1.0 if nm == "L" else 1.0
			var tw := pv.create_tween()
			tw.tween_property(pv, "rotation:y", (-sgn * PI * 0.47) if open else 0.0, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


var _flag_cache := {}         # asl mesh -> [bayroqsiz mesh, bayroq to'rtburchaklari]


func _live_flags(o: Node3D, replace := true) -> void:
	## modeldagi qotib turgan (quti) bayroqlarni olib tashlab, o'rniga shamolda hilpiraydigan
	## o'yinchi bayrog'ini qo'yadi (o'yinchi yuklagan rasm bilan). replace=false - faqat olib tashlash
	var col := Color(Game.countries[_p()["country"]]["color"]) if Game.countries.has(_p()["country"]) else Color.GREEN
	for mi in o.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if not (m.mesh is ArrayMesh):
			continue
		var key := m.mesh.get_rid().get_id()
		if not _flag_cache.has(key):
			_flag_cache[key] = _strip_flags(m.mesh as ArrayMesh)
		var e: Array = _flag_cache[key]
		if (e[1] as Array).is_empty():
			continue
		m.mesh = e[0]
		if not replace:
			continue
		for r in e[1]:
			var ab: AABB = r
			var f := Unit3D.flag(col, Unit3D.flag_tex(), Vector2(maxf(0.6, ab.size.x), maxf(0.4, ab.size.y)))
			f.position = Vector3(ab.position.x, ab.end.y, ab.position.z + ab.size.z * 0.5)
			m.add_child(f)


func _strip_flags(mesh: ArrayMesh) -> Array:
	var out := ArrayMesh.new()
	var rects: Array = []
	for si in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(si)
		var mat := mesh.surface_get_material(si)
		var is_team := mat != null and mat.resource_name.contains("TeamColor")
		if is_team and arr[Mesh.ARRAY_INDEX] != null:
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			# uchburchaklarni bir-biriga ulangan bo'laklarga ajratish (umumiy nuqta bo'yicha)
			var parent := {}
			var keyof := func(v: Vector3) -> String: return "%.3f_%.3f_%.3f" % [v.x, v.y, v.z]
			var find := func(a):
				var x = a
				while parent[x] != x:
					x = parent[x]
				return x
			for i in vs.size():
				var k: String = keyof.call(vs[i])
				if not parent.has(k):
					parent[k] = k
			for t in range(0, ix.size(), 3):
				var ka: String = find.call(keyof.call(vs[ix[t]]))
				for q in [1, 2]:
					var kb: String = find.call(keyof.call(vs[ix[t + q]]))
					if ka != kb:
						parent[kb] = ka
			var groups := {}
			for t in range(0, ix.size(), 3):
				var g: String = find.call(keyof.call(vs[ix[t]]))
				if not groups.has(g):
					groups[g] = []
				groups[g].append(t)
			var keep_ix := PackedInt32Array()
			for g in groups:
				var ab := AABB(vs[ix[groups[g][0]]], Vector3.ZERO)
				for t in groups[g]:
					for q in 3:
						ab = ab.expand(vs[ix[t + q]])
				var dims := [ab.size.x, ab.size.y, ab.size.z]
				dims.sort()
				var is_flag: bool = dims[0] < 0.12 and dims[1] > 0.35 and dims[2] < 3.5 and ab.size.y > 0.3
				if is_flag:
					rects.append(ab)
				else:
					for t in groups[g]:
						keep_ix.append(ix[t]); keep_ix.append(ix[t + 1]); keep_ix.append(ix[t + 2])
			if keep_ix.is_empty():
				continue
			arr[Mesh.ARRAY_INDEX] = keep_ix
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_material(out.get_surface_count() - 1, mat)
	return [out, rects]


func _add_guard(u: Node3D, base: float, mode: String) -> void:
	guards.append({"node": u, "mode": mode, "base": base, "yaw": base, "next": randf_range(1.0, 5.0), "aim": 0.0})
	Unit3D.play(u, "Idle")
	var ap := Unit3D.anim(u)
	if ap and ap.current_animation != "":
		ap.seek(randf() * ap.current_animation_length, true)


func _update_guards(delta: float) -> void:
	## soqchilar jonli: atrofga qarab buriladi, ba'zan kamon/miltiqni ko'tarib nishonga oladi; devordagilar yurib turadi
	for g in guards:
		var u: Node3D = g["node"]
		if not is_instance_valid(u):
			continue
		if g["mode"] == "patrol":
			if g["wait"] > 0.0:
				g["wait"] -= delta
				if g["wait"] <= 0.0:
					Unit3D.play(u, "Walk")
				continue
			var a: Vector3 = g["a"]
			var b: Vector3 = g["b"]
			var L := maxf(1.0, a.distance_to(b))
			g["t"] = float(g["t"]) + float(g["dir"]) * delta * 1.25 / L
			if g["t"] >= 1.0 or g["t"] <= 0.0:
				g["t"] = clampf(g["t"], 0.0, 1.0)
				g["dir"] = -float(g["dir"])
				g["wait"] = randf_range(2.0, 4.0)
				Unit3D.play(u, "Look" if Unit3D.anim(u) and Unit3D.anim(u).has_animation("Look") else "Idle")
			var p := a.lerp(b, g["t"])
			u.position = p + Vector3(0, WALL_H + 0.05, 0)
			var d := (b - a) * float(g["dir"])
			u.rotation.y = lerp_angle(u.rotation.y, atan2(-d.z, d.x), minf(1.0, delta * 5.0))
			continue
		if g["mode"] == "tower" and g.has("c"):
			# minora tepasida aylana bo'ylab sekin yuradi, ba'zan to'xtab tashqariga qaraydi / kamonni tortadi
			if float(g["walk"]) > 0.0:
				g["walk"] = float(g["walk"]) - delta
				g["ang"] = float(g["ang"]) + delta * 0.45
				var cp: Vector3 = g["c"]
				var np := cp + Vector3(cos(g["ang"]), 0, sin(g["ang"])) * 2.1
				var mv := np - u.position
				u.position = np
				if mv.length() > 0.0005:
					u.rotation.y = atan2(-mv.z, mv.x)
				if float(g["walk"]) <= 0.0:
					var outd := Vector3(cos(g["ang"]), 0, sin(g["ang"]))
					g["yaw"] = atan2(-outd.z, outd.x)
					g["base"] = g["yaw"]
					g["next"] = randf_range(2.5, 6.0)
					Unit3D.play(u, "Idle")
				continue
			elif float(g["next"]) - delta <= 0.0 and float(g["aim"]) <= 0.0 and randf() < 0.55:
				g["walk"] = randf_range(2.0, 5.0)
				g["next"] = 1.0
				Unit3D.play(u, "Walk")
				continue
		g["next"] = float(g["next"]) - delta
		if g["aim"] > 0.0:
			g["aim"] = float(g["aim"]) - delta
			if g["aim"] <= 0.0:
				Unit3D.play(u, "Idle")
		if g["next"] <= 0.0:
			g["next"] = randf_range(3.5, 8.0)
			var spread := 1.1 if g["mode"] == "tower" else 0.5
			g["yaw"] = float(g["base"]) + randf_range(-spread, spread)
			var ap := Unit3D.anim(u)
			if g["mode"] == "tower" and randf() < 0.3 and ap:
				# ba'zan kamonni tortib (miltiqni yelkaga qo'yib) nishonga oladi
				var an := "Aim" if ap.has_animation("Aim") else "Block"
				Unit3D.play(u, an)
				g["aim"] = randf_range(2.5, 4.0)
			elif ap and ap.has_animation("Look") and randf() < 0.5:
				Unit3D.play(u, "Look")
			else:
				Unit3D.play(u, "Idle")
		u.rotation.y = lerp_angle(u.rotation.y, float(g["yaw"]), minf(1.0, delta * 0.9))


func _draw_wall(a: Vector3, b: Vector3, kind: String, module: float) -> void:
	var L := a.distance_to(b)
	if L < 0.5:
		return
	var n := maxi(1, int(ceil(L / module)))
	var ang := _orient(a, b)
	var sx := L / (n * module)
	for i in n:
		var c := a.lerp(b, (i + 0.5) / n)
		if kind == "wall" and _gate_near(c, 5.2):
			continue
		var o := _inst(kind)
		o.position = c
		o.rotation.y = ang
		o.scale = Vector3(sx * 1.01, 1, 1)
		build_root.add_child(o)


# ================================================================ mudofaa tahlili

func _analyze() -> void:
	var walls: Array = []
	for w in data["walls"]:
		walls.append([_v(w["a"]), _v(w["b"])])
	var towers: Array = []
	for t in data["towers"]:
		towers.append(_v(t["p"]))
	var gates: Array = []
	for g in data["gates"]:
		gates.append(_v(g["p"]))
	# 1) yopiqlik: to'r ustida tashqaridan to'ldirish
	var cell := 2.0
	var half := int((AREA + 20.0) / cell)
	var N := half * 2 + 1
	var blocked := PackedByteArray()
	blocked.resize(N * N)
	var mark := func(p: Vector3, r: int) -> void:
		var cx := int(round(p.x / cell)) + half
		var cz := int(round(p.z / cell)) + half
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				var x := cx + dx
				var z := cz + dz
				if x >= 0 and z >= 0 and x < N and z < N:
					blocked[z * N + x] = 1
	for w in walls:
		var a: Vector3 = w[0]
		var b: Vector3 = w[1]
		var steps := int(a.distance_to(b) / 0.5) + 1
		for i in steps + 1:
			mark.call(a.lerp(b, float(i) / steps), 1)
	for t in towers:
		mark.call(t, 2)
	var outside := PackedByteArray()
	outside.resize(N * N)
	var q := PackedInt32Array()
	for i in N:
		for idx in [i, (N - 1) * N + i, i * N, i * N + N - 1]:
			if blocked[idx] == 0 and outside[idx] == 0:
				outside[idx] = 1
				q.append(idx)
	var head := 0
	while head < q.size():
		var idx := q[head]
		head += 1
		var x := idx % N
		var z := idx / N
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = x + d.x
			var nz: int = z + d.y
			if nx < 0 or nz < 0 or nx >= N or nz >= N:
				continue
			var ni := nz * N + nx
			if blocked[ni] == 0 and outside[ni] == 0:
				outside[ni] = 1
				q.append(ni)
	_g_out = outside
	_g_blk = blocked
	_g_n = N
	_g_half = half
	var kc := (int(round(_keep().z / cell)) + half) * N + int(round(_keep().x / cell)) + half
	var closed_ok := outside[kc] == 0 and walls.size() > 0
	var inside := 0
	if closed_ok:
		for i in N * N:
			if outside[i] == 0 and blocked[i] == 0:
				inside += 1
	var area := inside * cell * cell
	var used := 0.0
	for b in data["buildings"]:
		if CastleEco.ECON.has(b["t"]):
			continue
		var f: Vector2 = FOOT.get(b["t"], Vector2(8, 8))
		used += f.x * f.y
	used += FOOT["keep"].x * FOOT["keep"].y
	var free := maxf(0.0, area - used)
	# 2) ko'r nuqtalar va tomonlar
	var sect := []
	for i in 4:
		sect.append({"wall": 0.0, "towers": 0, "gates": 0, "moat": 0.0, "blind": 0.0})
	var blind_segs: Array = []
	var total := 0.0
	var blind_total := 0.0
	for w in walls:
		var a: Vector3 = w[0]
		var b: Vector3 = w[1]
		var L := a.distance_to(b)
		total += L
		var n := maxi(1, int(L / 2.0))
		var run_start := Vector3.INF
		for i in n + 1:
			var p := a.lerp(b, float(i) / n)
			var covered := false
			for t in towers:
				if (t as Vector3).distance_to(p) <= TOWER_COVER:
					covered = true
					break
			if not covered:
				for g in gates:
					if (g as Vector3).distance_to(p) <= TOWER_COVER * 0.6:
						covered = true
						break
			var s := _sector(p)
			if i < n:
				sect[s]["wall"] += L / n
				if not covered:
					sect[s]["blind"] += L / n
					blind_total += L / n
			if not covered and run_start == Vector3.INF:
				run_start = p
			elif covered and run_start != Vector3.INF:
				blind_segs.append([run_start, p])
				run_start = Vector3.INF
		if run_start != Vector3.INF:
			blind_segs.append([run_start, b])
	for t in towers:
		sect[_sector(t)]["towers"] += 1
	for g in gates:
		sect[_sector(g)]["gates"] += 1
	for m in data["moats"]:
		var a := _v(m["a"])
		var b := _v(m["b"])
		sect[_sector((a + b) * 0.5)]["moat"] += a.distance_to(b)
	var weakest := -1
	var wscore := 1e9
	for i in 4:
		var s: Dictionary = sect[i]
		var sc: float = 0.0
		if s["wall"] > 0.0:
			sc = 25.0 + s["towers"] * 18.0 + s["wall"] * 0.15 + s["moat"] * 0.25 - s["gates"] * 22.0 - s["blind"] * 0.5
		s["score"] = clampf(sc, 0.0, 100.0)
		if s["score"] < wscore:
			wscore = s["score"]
			weakest = i
	stats = {"closed": closed_ok, "area": area, "free": free, "capacity": int(free / 5.0), "wall_len": total,
		"towers": towers.size(), "gates": gates.size(), "blind": blind_total, "sectors": sect, "weakest": weakest,
		"blind_segs": blind_segs}
	var avg := 0.0
	for s in sect:
		avg += s["score"]
	data["stats"] = {"closed": closed_ok, "capacity": stats["capacity"], "score": avg / 4.0, "weakest": weakest,
		"sectors": sect.map(func(s): return s["score"])}
	_show_stats()


func _sector(p: Vector3) -> int:
	## 0 shimol (-Z), 1 sharq (+X), 2 janub (+Z), 3 g'arb (-X)
	var d := p - _keep()
	if absf(d.x) > absf(d.z):
		return 1 if d.x > 0 else 3
	return 2 if d.z > 0 else 0


# ================================================================ qurish amallari

func _cost(kind: String, mult := 1.0) -> Dictionary:
	return CastleEco.cost_of(kind, mult)


func _sum(a: Dictionary, b: Dictionary) -> Dictionary:
	var o := a.duplicate()
	for k in b:
		o[k] = int(o.get(k, 0)) + int(b[k])
	return o


func _pay(cost: Dictionary) -> bool:
	var miss := CastleEco.can_pay(cost)
	if miss != "":
		_msg("Yetmaydi: " + miss, true)
		return false
	CastleEco.pay(cost)
	return true


func _refund(cost: Dictionary) -> String:
	var half := {}
	for k in cost:
		half[k] = -int(cost[k] / 2)
	CastleEco.pay(half)
	return CastleEco.cost_text(_neg(half))


func _neg(d: Dictionary) -> Dictionary:
	var o := {}
	for k in d:
		o[k] = -int(d[k])
	return o


func _add_tower_if_needed(p: Vector3) -> int:
	for t in data["towers"]:
		if _v(t["p"]).distance_to(p) < 3.5:
			return 0
	data["towers"].append({"p": [p.x, p.z]})
	return 1


func _click(p: Vector3) -> void:
	if tool == "":
		return
	var sp := _snap(p)
	if tool == "torch":
		if not _in_area(sp):
			_msg("Qurish hududidan tashqarida", true)
			return
		if _pay(_cost("torch")):
			if not data.has("torches"):
				data["torches"] = []
			data["torches"].append([p.x, p.z])
			Sfx.play("olov", -14.0, 0.05, 0.3)
			_msg("Mash'al o'rnatildi")
			_rebuild()
		return
	if tool in ["wall", "moat"]:
		if not _in_area(sp):
			_msg("Qurish hududidan tashqarida", true)
			return
		if not has_start:
			has_start = true
			chain_start = sp
			return
		var L := chain_start.distance_to(sp)
		if L < 3.0:
			return
		var cost := _cost(tool, L)
		var tw := 0
		if tool == "wall":
			# uchlarida minora bo'lmasa, minora ham qo'shiladi
			for e in [chain_start, sp]:
				var near := false
				for t in data["towers"]:
					if _v(t["p"]).distance_to(e) < 3.5:
						near = true
				if not near:
					tw += 1
		if not _pay(_sum(cost, _cost("tower", tw)) if tw > 0 else cost):
			return
		var key := "walls" if tool == "wall" else "moats"
		data[key].append({"a": [chain_start.x, chain_start.z], "b": [sp.x, sp.z], "hp": 1.0})
		if tool == "wall":
			_add_tower_if_needed(chain_start)
			_add_tower_if_needed(sp)
		chain_start = sp
		_msg("%s qurildi: %d m%s" % [NAMES[tool], int(L), (", +%d minora" % tw) if tw > 0 else ""])
		Sfx.play("qurilish", -5.0)
		_rebuild()
	elif tool == "tower":
		if not _in_area(sp):
			return
		for t in data["towers"]:
			if _v(t["p"]).distance_to(sp) < 7.0:
				_msg("Bu yerda allaqachon minora bor", true)
				return
		if _pay(_cost("tower")):
			data["towers"].append({"p": [sp.x, sp.z]})
			Sfx.play("qurilish", -5.0)
			_rebuild()
	elif tool == "gate":
		var best := -1
		var bd := 5.0
		for i in data["walls"].size():
			var w: Dictionary = data["walls"][i]
			var d := _seg_dist(p, _v(w["a"]), _v(w["b"]))
			if d < bd:
				bd = d
				best = i
		if best < 0:
			_msg("Darvozani devor ustiga qo'ying", true)
			return
		var w: Dictionary = data["walls"][best]
		var a := _v(w["a"])
		var b := _v(w["b"])
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var gp := a + ab * t
		if a.distance_to(gp) < 7.0 or b.distance_to(gp) < 7.0:
			_msg("Darvoza minoradan kamida 7 m uzoqda bo'lishi kerak", true)
			return
		if _gate_near(gp, 14.0):
			_msg("Yaqinda boshqa darvoza bor", true)
			return
		if _pay(_cost("gate")):
			data["gates"].append({"p": [gp.x, gp.z], "ang": _orient(a, b)})
			Sfx.play("qurilish", -5.0)
			_rebuild()
	elif tool == "delete":
		_delete_at(p)
	elif tool in FOOT:
		if not _in_area(sp):
			return
		var f: Vector2 = FOOT[tool]
		if sp.distance_to(_keep()) < 16.0 + f.x * 0.5:
			_msg("Arkka juda yaqin", true)
			return
		if _pay(_cost(tool)):
			data["buildings"].append({"t": tool, "p": [sp.x, sp.z], "rot": rot})
			Sfx.play("qurilish", -5.0)
			_rebuild()


func _delete_at(p: Vector3) -> void:
	var back := {}
	var tl: Array = data.get("torches", [])
	for i in tl.size():
		if _v(tl[i]).distance_to(p) < 2.5:
			tl.remove_at(i)
			back = _cost("torch")
			break
	for i in data["gates"].size():
		if _v(data["gates"][i]["p"]).distance_to(p) < 6.0:
			data["gates"].remove_at(i)
			back = _cost("gate")
			break
	if back.is_empty():
		for i in data["towers"].size():
			if _v(data["towers"][i]["p"]).distance_to(p) < 4.5:
				data["towers"].remove_at(i)
				back = _cost("tower")
				break
	if back.is_empty():
		for i in data["buildings"].size():
			var b: Dictionary = data["buildings"][i]
			if _v(b["p"]).distance_to(p) < FOOT[b["t"]].x * 0.5:
				back = _cost(b["t"])
				data["buildings"].remove_at(i)
				break
	if back.is_empty():
		for key in ["walls", "moats"]:
			for i in data[key].size():
				var w: Dictionary = data[key][i]
				if _seg_dist(p, _v(w["a"]), _v(w["b"])) < 3.0:
					back = _cost("wall" if key == "walls" else "moat", _v(w["a"]).distance_to(_v(w["b"])))
					data[key].remove_at(i)
					break
			if not back.is_empty():
				break
	if not back.is_empty():
		_msg("Buzildi, qaytdi: " + _refund(back))
		_rebuild()


func _update_ghost() -> void:
	for c in ghost_root.get_children():
		c.queue_free()
	if tool == "" or tool == "delete":
		return
	var sp := _snap(mouse_pt)
	var ok := _in_area(sp)
	if tool in ["wall", "moat"]:
		var marker := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 1.2
		cm.bottom_radius = 1.2
		cm.height = 0.4
		marker.mesh = cm
		marker.material_override = _ghost_mat if ok else _bad_mat
		marker.position = sp + Vector3(0, 0.2, 0)
		ghost_root.add_child(marker)
		if has_start:
			var L := chain_start.distance_to(sp)
			if L > 0.5:
				var mi := MeshInstance3D.new()
				var bx := BoxMesh.new()
				bx.size = Vector3(L, WALL_H if tool == "wall" else 0.6, 3.0 if tool == "wall" else 6.0)
				mi.mesh = bx
				mi.material_override = _ghost_mat if ok else _bad_mat
				mi.position = (chain_start + sp) * 0.5 + Vector3(0, bx.size.y * 0.5, 0)
				mi.rotation.y = atan2(-(sp - chain_start).z, (sp - chain_start).x)
				ghost_root.add_child(mi)
				tip_label.text = "%s: %d m  -  %s   (o'ng tugma: tugatish)" % [NAMES[tool], int(L), CastleEco.cost_text(_cost(tool, L))]
	elif tool in ["tower", "gate"]:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 3.4 if tool == "tower" else 2.0
		cm.bottom_radius = cm.top_radius
		cm.height = 11.0 if tool == "tower" else 9.0
		mi.mesh = cm
		mi.material_override = _ghost_mat
		mi.position = sp + Vector3(0, cm.height * 0.5, 0)
		ghost_root.add_child(mi)
		if tool == "tower":
			# himoya radiusi
			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = TOWER_COVER - 0.4
			tm.outer_radius = TOWER_COVER
			ring.mesh = tm
			ring.material_override = _ghost_mat
			ring.position = sp + Vector3(0, 0.3, 0)
			ghost_root.add_child(ring)
	elif tool in FOOT:
		var f: Vector2 = FOOT[tool]
		var mi := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(f.x, 4.0, f.y)
		mi.mesh = bx
		mi.material_override = _ghost_mat if ok else _bad_mat
		mi.position = sp + Vector3(0, 2.0, 0)
		mi.rotation.y = rot
		ghost_root.add_child(mi)


# ================================================================ kiritish

func _ground_at(screen: Vector2) -> Vector3:
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	if absf(d.y) < 0.0001:
		return Vector3.ZERO
	var t := -o.y / d.y
	return o + d * t


func _input_3d(e: InputEvent) -> void:
	if _leaving:
		return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			if walk_mode:
				# qo'mondonga yaqinlashish: oxirida uning ko'zi bilan ko'rish
				_tdist = 1.0 if _tdist < 4.0 else clampf(_tdist / 1.25, 3.0, 60.0)
				return
			_tdist = clampf(_tdist / 1.15, 18.0, MAX_DIST)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if walk_mode:
				_tdist = 4.0 if _tdist < 3.0 else clampf(_tdist * 1.25, 3.0, 60.0)
				return
			if _tdist >= MAX_DIST * 0.98:
				# eng uzoqdan yana uzoqlashtirsa - xaritaga (globusga) silliq ko'tarilamiz
				_leaving = true
				exit_requested.emit()
				return
			_tdist = clampf(_tdist * 1.15, 18.0, MAX_DIST)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_mid = mb.pressed
		elif walk_mode and mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_walk_mouse(mb)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			# o'ng tugma: sudrasa - kamerani aylantirish, bossa - belgilangan askarlarni yurgizish yoki bekor qilish
			if mb.pressed:
				_rmb = true
				_drag_moved = false
				_press_at = mb.position
			else:
				_rmb = false
				if not _drag_moved:
					if tool == "" and rts and rts.on_right_click(mb.position):
						return
					_cancel()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			# chap tugma: asbob tanlangan bo'lsa - qurish (sudrash - xaritani surish);
			# asbobsiz - askarni bosish/ramka chizib belgilash, yerni bosish - belgilanganlarni yurgizish
			if mb.pressed:
				_lmb = true
				_drag_moved = false
				_press_at = mb.position
				_dbl = mb.double_click
				if tool == "" and rts:
					rts.on_press(mb.position)
			else:
				_lmb = false
				if tool == "" and rts:
					rts.on_release(mb.position, _drag_moved, mb.shift_pressed, _dbl)
				elif not _drag_moved:
					_click(_ground_at(mb.position))
	elif e is InputEventMouseMotion:
		var mm := e as InputEventMouseMotion
		if (_lmb or _rmb) and mm.position.distance_to(_press_at) > 6.0:
			_drag_moved = true
		if walk_mode and _lmb and _drag_moved:
			# qo'mondon: chap tugmani bosib turib sudrash - atrofga 360 gradus qarash
			cam_yaw -= mm.relative.x * 0.006
			_fp_pitch = clampf(_fp_pitch - mm.relative.y * 0.004, -1.1, 0.9)
			_walk_drag = true
			_apply_cam()
		elif tool == "" and _lmb and _drag_moved and rts and not walk_mode:
			rts.on_drag(mm.position)
		elif _mid or (_lmb and _drag_moved):
			var a := _ground_at(mm.position - mm.relative)
			var b := _ground_at(mm.position)
			if a != Vector3.INF and b != Vector3.INF and a.distance_to(b) < 200.0:
				cam_target += a - b
			else:
				cam_target -= Basis(Vector3.UP, cam_yaw) * Vector3(mm.relative.x, 0, mm.relative.y) * cam_dist * 0.002
			cam_target = cam_target.clamp(Vector3(-AREA * 1.6, 0, -AREA * 1.6), Vector3(AREA * 1.6, 0, AREA * 1.6))
			_apply_cam()
		elif _rmb and _drag_moved:
			cam_yaw -= mm.relative.x * 0.006
			_apply_cam()
		mouse_pt = _ground_at(mm.position)
		_update_ghost()


func _cancel() -> void:
	if has_start:
		has_start = false
	else:
		_set_tool("")
	_update_ghost()


func _unhandled_key_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed):
		return
	var k := (e as InputEventKey).keycode
	if k == KEY_TAB:
		_toggle_walk()
		return
	if walk_mode and k in [KEY_1, KEY_2, KEY_3]:
		_walk_weapon = [KEY_1, KEY_2, KEY_3].find(k)
		_make_cmdr_model()
		return
	if walk_mode and k == KEY_F:
		_inspect()
		return
	if walk_mode and rts and k in [KEY_G, KEY_V, KEY_C, KEY_X]:
		_cmd_shout(k)
		return
	if k == KEY_ESCAPE and walk_mode:
		_toggle_walk()
		return
	if k == KEY_ESCAPE and rts and not rts.sel.is_empty():
		rts.clear_sel()
		return
	if k == KEY_ESCAPE:
		if tool == "" and not has_start and not _leaving:
			_leaving = true
			exit_requested.emit()
		else:
			_cancel()
	elif k == KEY_R:
		rot += PI / 2.0
		_update_ghost()


var _amb_t := 0.0
var _bell_h := -1
var _dbl := false
var _walk_drag := false
var _cmd_act := ""          # qo'mondon: "attack" / "block"
var _cmd_act_t := 0.0


func _ambience(delta: float) -> void:
	## qal'a atrofidagi tabiat: kunduzi qushlar, kechasi chigirtkalar va boyqush, doim yengil shamol, yomg'ir
	_amb_t -= delta
	if _amb_t > 0.0 or daynight == null:
		return
	_amb_t = 1.0
	var h: float = daynight.hour
	var night := h < 5.5 or h > 20.0
	Sfx.loop("c_amb", "tun" if night else "kunduz", -10.0 if night else -12.0, 2.0)
	Sfx.loop("c_wind", "shamol", -20.0 if daynight.weather in ["ochiq", "bulut"] else -9.0, 2.0)
	if daynight.weather == "yomgir":
		Sfx.loop("c_rain", "yomgir", -8.0, 3.0)
	else:
		Sfx.stop_loop("c_rain", 3.0)
	# temirchi bo'lsa vaqti-vaqti bilan sandon ovozi
	if not night and CastleEco.count(_p(), "smithy") > 0 and randf() < 0.08:
		Sfx.play("sandon", -22.0, 0.1, 2.0)
	# bozor shovqini (kunduzi), masjid hovlisi, kechasi mash'allar chirsillashi
	if not night and CastleEco.count(_p(), "market") > 0:
		Sfx.loop("c_bozor", "bozor", -16.0, 3.0)
	else:
		Sfx.stop_loop("c_bozor", 3.0)
	if CastleEco.count(_p(), "mosque") > 0 and not night:
		Sfx.loop("c_masjid", "masjid", -14.0, 3.0)
	else:
		Sfx.stop_loop("c_masjid", 3.0)
	if night:
		Sfx.loop("c_olov", "olov", -24.0, 3.0)
	else:
		Sfx.stop_loop("c_olov", 3.0)
	# nasroniy qal'alarda cherkov qo'ng'irog'i (ertalab, tushda, kechqurun)
	var bst := Unit3D.building_style(_p()["country"])
	if bst in ["rus", "yevropa", "yunon"] and Unit3D.castle_style(_p()["country"]) != "isl":
		var hh := int(h)
		if hh in [8, 12, 18] and _bell_h != hh:
			_bell_h = hh
			Sfx.play("qongiroq", -12.0, 0.02, 30.0)
	if CastleEco.count(_p(), "stable") > 0 and randf() < 0.05:
		Sfx.play("ot_pishqirish" if randf() < 0.8 else "ot_kishnash", -24.0, 0.1, 3.0)


func _process(delta: float) -> void:
	if cam == null:
		return
	_ambience(delta)
	if walk_mode:
		_walk(delta)
	var dir := Vector3.ZERO
	if walk_mode:
		pass
	elif Input.is_key_pressed(KEY_A): dir.x -= 1
	if not walk_mode:
		if Input.is_key_pressed(KEY_D): dir.x += 1
		if Input.is_key_pressed(KEY_W): dir.z -= 1
		if Input.is_key_pressed(KEY_S): dir.z += 1
	var yaw := 0.0
	if Input.is_key_pressed(KEY_Q): yaw -= 1
	if Input.is_key_pressed(KEY_E): yaw += 1
	if absf(cam_dist - _tdist) > 0.05:
		cam_dist = lerpf(cam_dist, _tdist, 1.0 - exp(-8.0 * delta))
		_apply_cam()
	if dir != Vector3.ZERO or yaw != 0.0:
		cam_target += Basis(Vector3.UP, cam_yaw) * dir.normalized() * cam_dist * 0.9 * delta
		cam_target = cam_target.clamp(Vector3(-AREA * 1.6, 0, -AREA * 1.6), Vector3(AREA * 1.6, 0, AREA * 1.6))
		cam_yaw += yaw * 1.4 * delta
		_apply_cam()
	if money_label:
		money_label.text = "Oltin %d   Oziq %d   Yog'och %d   Tosh %d   |   %s" % [int(Game.money), int(CastleEco.have("oziq")),
			int(CastleEco.have("yogoch")), int(CastleEco.have("tosh")), Game.date_text()]
		if daynight != null:
			money_label.text += "   " + daynight.time_text()
	_update_guards(delta)
	if rts:
		rts.update(delta)
	if _ctx_panel:
		_ctx_tick(delta)
	_update_drill(delta)
	_army_t += delta
	if _army_t > 0.4:
		_army_t = 0.0
		_refresh_army()


# ================================================================ qo'mondon bo'lib yurish
## Tab - qo'mondonning o'zi bo'lib qal'ada yayov (yoki otda) yurish. WASD - yurish, Shift - yugurish,
## sichqonchaning o'ng tugmasi / Q-E - kamerani aylantirish, 1 - nayza va qalqon, 2 - qilich, 3 - otda, F - askarlarni ko'zdan kechirish.
const WALK_KINDS := ["nayzachi", "qilichboz", "otliq"]
const WALK_NAMES := ["Nayza va qalqon", "Qilich", "Otda"]
var walk_mode := false
var _side_panel: Control
var _tool_panel: Control
var _walk_weapon := 1
var _walk_hint: Label
var _walk_anim := ""
var _saved_cam := []


func _toggle_walk() -> void:
	if not walk_mode:
		_ensure_cmdr()
		if cmdr == null or not is_instance_valid(cmdr):
			# askar yo'q bo'lsa ham qo'mondon bor
			var col := Color(Game.countries[_p()["country"]]["color"]) if Game.countries.has(_p()["country"]) else Color("#2f7d4a")
			cmdr = Unit3D.soldier(Unit3D.faction_for(_p()["country"]), "qilichboz", col)
			army_root.add_child(cmdr)
			cmdr.position = _keep() + _muster_dir() * 14.0
			cmdr.set_meta("cmd", true)
	walk_mode = not walk_mode
	_set_tool("")
	if _side_panel:
		_side_panel.visible = false
	open_ctx("")
	if rts and rts.panel:
		rts.clear_sel()
		rts.panel.visible = walk_mode      # qo'mondon: pastda askar turlari va buyruqlar
	if walk_mode:
		_saved_cam = [cam_target, cam_dist, _tdist, cam_yaw]
		if cmdr.has_meta("tw") and (cmdr.get_meta("tw") as Tween).is_valid():
			(cmdr.get_meta("tw") as Tween).kill()
		_make_cmdr_model()
		cam_dist = 9.0
		_tdist = 9.0
		cam_yaw = cmdr.rotation.y - PI / 2.0
		if _walk_hint == null:
			_walk_hint = UIKit.label("", 14, Color("#f3d58a"))
			_walk_hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
			_walk_hint.offset_top = 92
			_walk_hint.offset_left = -420
			_walk_hint.offset_right = 420
			_walk_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_walk_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			hud.add_child(_walk_hint)
		_walk_hint.visible = false        # ekranda yozuv chiqmaydi (o'yinchi iltimosi)
	else:
		if cmdr != null and is_instance_valid(cmdr):
			cmdr.visible = true
		if _walk_hint:
			_walk_hint.visible = false
		if _saved_cam.size() == 4:
			cam_target = _saved_cam[0]
			cam_dist = _saved_cam[1]
			_tdist = _saved_cam[2]
			cam_yaw = _saved_cam[3]
		_task_mode = ""        # qo'mondon yana saf oldiga qaytadi
	_apply_cam()


func _make_cmdr_model() -> void:
	## qo'mondonni tanlangan qurol bilan qayta yasash (nayza+qalqon / qilich / otda)
	if cmdr == null or not is_instance_valid(cmdr):
		return
	var pos := cmdr.position
	var rot := cmdr.rotation.y
	cmdr.queue_free()
	var col := Color(Game.countries[_p()["country"]]["color"]) if Game.countries.has(_p()["country"]) else Color("#2f7d4a")
	var fac := Unit3D.faction_for(_p()["country"])
	var k: String = WALK_KINDS[_walk_weapon]
	if Game.era == 2 and k == "nayzachi":
		k = "sarboz"
	cmdr = Unit3D.cavalry(fac, "otliq", col) if k == "otliq" else Unit3D.soldier(fac, k, col)
	cmdr.scale = Vector3.ONE * 1.08
	army_root.add_child(cmdr)
	Unit3D.equip(cmdr, CastleEco.gear(_p()))
	cmdr.position = pos
	cmdr.rotation.y = rot
	cmdr.set_meta("cmd", true)
	_walk_anim = ""
	_msg("Qo'mondon qurolini almashtirdi: " + WALK_NAMES[_walk_weapon])


func _walk_play(a: String) -> void:
	if _walk_anim == a:
		return
	_walk_anim = a
	var horse := Unit3D.rider_of(cmdr) != null
	if horse:
		Unit3D.play(cmdr, {"Idle": "Idle", "Walk": "Walk", "Run": "Gallop"}.get(a, a))
		var rd := Unit3D.rider_of(cmdr)
		if rd:
			Unit3D.play(rd, "Ride")
	else:
		Unit3D.play(cmdr, a)


func _walk_mouse(mb: InputEventMouseButton) -> void:
	## qo'mondon: chap tugma - qurol bilan zarba (bosib turib sudrasa - atrofga qarash), o'ng tugma - qalqon bilan himoya
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_lmb = true
			_drag_moved = false
			_walk_drag = false
			_press_at = mb.position
		else:
			_lmb = false
			if not _walk_drag:
				if rts and rts.aim_mode:
					rts.order_shoot(_ground_at(mb.position))
					rts.sel = []
				elif rts and rts.move_mode and not rts.sel.is_empty():
					rts.move_mode = false
					rts.order_move(_ground_at(mb.position))
				else:
					_cmd_attack()
			_walk_drag = false
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		if mb.pressed and rts and rts.aim_mode:
			rts.aim_mode = false
			rts.sel = []
			_msg("O'q yomg'iri bekor qilindi")
			return
		if mb.pressed:
			_cmd_act = "block"
			var rd := Unit3D.rider_of(cmdr)
			if rd:
				Unit3D.play(rd, "Ride")
			else:
				Unit3D.play(cmdr, "Block")
			_walk_anim = "Block"
			Sfx.play("qalqon", -14.0, 0.1, 0.3)
		else:
			_cmd_act = ""
			_walk_anim = ""


func _cmd_shout(k: int) -> void:
	## qo'mondon buyruqlari (videodagidek): qo'mondon qo'lini ko'tarib baqiradi, askarlar bajaradi
	var rd := Unit3D.rider_of(cmdr)
	_act(rd if rd else cmdr, "Cheer")
	_walk_anim = "Cheer"
	Sfx.play("qomondon", -4.0, 0.05, 0.4)
	match k:
		KEY_G:
			rts.order_testudo(true, rts.near_cmd(30.0, ["nayzachi", "qilichboz", "sarboz"]))
		KEY_V:
			var arch := rts.near_cmd(45.0, ["kamonchi", "sarboz"])
			if arch.is_empty():
				_msg("Yaqinda kamonchi yo'q", true)
				return
			rts.sel = arch
			rts.aim_mode = true
			_msg("O'Q YOMG'IRI! Nishonni chap tugma bilan bosing (o'ng tugma - bekor)")
		KEY_C:
			rts.order_charge(rts.near_cmd(30.0, []))
		KEY_X:
			rts.order_follow(rts.near_cmd(30.0, []))
			_msg("ORTIMDAN! Askarlar qo'mondonga ergashmoqda")


func _cmd_attack() -> void:
	if cmdr == null or not is_instance_valid(cmdr) or _cmd_act == "block":
		return
	_cmd_act = "attack"
	_cmd_act_t = 0.9
	_walk_anim = "Attack"
	var rd := Unit3D.rider_of(cmdr)
	if rd:
		_act(rd, "RideAttack")
	else:
		_act(cmdr, "Attack")
	Sfx.play("silkish", -10.0, 0.1, 0.2)


func _walk(delta: float) -> void:
	if cmdr == null or not is_instance_valid(cmdr):
		walk_mode = false
		return
	if _cmd_act == "attack":
		_cmd_act_t -= delta
		if _cmd_act_t <= 0.0:
			_cmd_act = ""
			_walk_anim = ""
	var inp := Vector2.ZERO
	if Input.is_key_pressed(KEY_A): inp.x -= 1
	if Input.is_key_pressed(KEY_D): inp.x += 1
	if Input.is_key_pressed(KEY_W): inp.y -= 1
	if Input.is_key_pressed(KEY_S): inp.y += 1
	var horse := Unit3D.rider_of(cmdr) != null
	var run := Input.is_key_pressed(KEY_SHIFT)
	if inp != Vector2.ZERO:
		var mv := Basis(Vector3.UP, cam_yaw) * Vector3(inp.x, 0, inp.y).normalized()
		var sp := ((9.0 if run else 4.0) if horse else (4.2 if run else 1.8)) * (0.5 if _cmd_act == "block" else 1.0)
		var np := cmdr.position + mv * sp * delta
		np = np.clamp(Vector3(-AREA * 1.5, 0, -AREA * 1.5), Vector3(AREA * 1.5, 0, AREA * 1.5))
		# binolar ichidan o'tmaydi
		var ok := true
		for b in data["buildings"]:
			var f: Vector2 = FOOT.get(b["t"], Vector2(8, 8))
			if _v(b["p"]).distance_to(np) < minf(f.x, f.y) * 0.45 and _v(b["p"]).distance_to(np) < _v(b["p"]).distance_to(cmdr.position):
				ok = false
		if _keep().distance_to(np) < FOOT["keep"].x * 0.5 and _keep().distance_to(np) < _keep().distance_to(cmdr.position):
			ok = false
		# devor, minora, ark ichidan ham o'tmaydi (yo'l to'ri bo'yicha)
		if ok and rts and rts.N > 0 and np.y < 1.0:
			var ci := rts._cell(np)
			if rts._okc(ci) and rts.astar.is_point_solid(ci) and not rts.astar.is_point_solid(rts._cell(cmdr.position)):
				ok = false
		if ok:
			cmdr.position = np
		cmdr.rotation.y = lerp_angle(cmdr.rotation.y, atan2(-mv.z, mv.x), 1.0 - exp(-10.0 * delta))
		if _cmd_act == "":
			_walk_play("Run" if run else "Walk")
	elif _cmd_act == "" and (_walk_anim != "Cheer" or not (Unit3D.anim(cmdr) and Unit3D.anim(cmdr).is_playing())):
		_walk_play("Idle")
	cam_target = cam_target.lerp(cmdr.position + Vector3(0, 1.0, 0), 1.0 - exp(-8.0 * delta))
	if _fps:
		cmdr.rotation.y = atan2(cos(cam_yaw), -sin(cam_yaw))     # qo'mondon qaragan tomonga buriladi
	var yaw := 0.0
	if Input.is_key_pressed(KEY_Q): yaw -= 1
	if Input.is_key_pressed(KEY_E): yaw += 1
	cam_yaw += yaw * 1.6 * delta
	_apply_cam()
	# yaqin askarlar qo'mondonga qarab turadi
	var near := 0
	for n in _all_figs():
		var nd: Node3D = n
		if nd.position.distance_to(cmdr.position) < 6.0 and not nd.get_meta("post", false):
			near += 1
	if _walk_hint:
		_walk_hint.text = "QO'MONDON: %s%s\nWASD yurish, Shift yugurish  |  chap tugma - zarba, o'ng tugma - qalqon, chap tugmani bosib sudrash - atrofga qarash  |  1 nayza+qalqon, 2 qilich, 3 otda\nG - QALQON! (toshbaqa)  |  V - O'Q YOMG'IRI!  |  C - OLG'A!  |  X - ORTIMDAN!  |  F ko'zdan kechirish  |  Tab chiqish" % [
			WALK_NAMES[_walk_weapon], "  -  yaqinda %d askar" % near if near > 0 else ""]


func _inspect() -> void:
	## qo'mondon yaqinidagi askarlarni ko'zdan kechiradi: ular qaddini rostlab salom beradi, ruhi ko'tariladi
	if cmdr == null:
		return
	var n_ok := 0
	for n in _all_figs():
		var nd: Node3D = n
		if nd.position.distance_to(cmdr.position) < 9.0:
			var d := cmdr.position - nd.position
			nd.rotation.y = atan2(-d.z, d.x)
			_act(nd, "Cheer")
			n_ok += 1
	_walk_play("Cheer")
	_act(cmdr, "Cheer")
	if n_ok > 0:
		data["drill"] = minf(100.0, float(data.get("drill", 0.0)) + 0.3)
		_msg("%d askar qo'mondonni olqishladi - ruhi ko'tarildi" % n_ok)
	else:
		_msg("Yaqinda askar yo'q - saf oldiga boring", true)


# ================================================================ qo'mondon va mashq

func _all_figs() -> Array:
	var out: Array = []
	for k in figs:
		for n in figs[k]:
			if is_instance_valid(n):
				out.append(n)
	return out


func _wall_posts() -> Array:
	## devor ustidagi qo'riqlash joylari: [pozitsiya, tashqariga qarash burchagi]
	var res: Array = []
	var kp := _keep()
	for w in data["walls"]:
		var a := _v(w["a"])
		var b := _v(w["b"])
		var L := a.distance_to(b)
		if L < 4.0:
			continue
		var dir := (b - a) / L
		var nrm := Vector3(-dir.z, 0, dir.x)
		if nrm.dot(kp - (a + b) * 0.5) < 0.0:
			nrm = -nrm         # ichkariga
		var n := int(L / 3.2)
		for i in n:
			var q := a + dir * (L * (float(i) + 0.5) / float(n))
			var near_gate := false
			for g in data["gates"]:
				if _v(g["p"]).distance_to(q) < 5.0:
					near_gate = true
			if near_gate:
				continue
			var pos := q + nrm * 0.6 + Vector3(0, WALL_H + 0.05, 0)
			res.append([pos, atan2(nrm.z, -nrm.x)])
	return res


func _act(n: Node3D, a: String) -> void:
	var ap := Unit3D.anim(n)
	if ap and ap.has_animation(a):
		ap.stop()
		ap.play(a, 0.1)


func _ensure_cmdr() -> void:
	if walk_mode:
		return
	var total := _all_figs().size()
	if total == 0:
		if cmdr != null and is_instance_valid(cmdr):
			cmdr.queue_free()
		cmdr = null
		return
	if cmdr != null and is_instance_valid(cmdr):
		return
	var col := Color(Game.countries[_p()["country"]]["color"]) if Game.countries.has(_p()["country"]) else Color("#2f7d4a")
	cmdr = Unit3D.soldier(Unit3D.faction_for(_p()["country"]), "qilichboz", col)
	if cmdr == null:
		return
	cmdr.scale = Vector3.ONE * 1.08
	army_root.add_child(cmdr)
	cmdr.position = _cmd_home()
	cmdr.set_meta("cmd", true)


func _cmd_home() -> Vector3:
	var fwd := _muster_dir()
	var s0: Vector3 = slots[0] if slots.size() > 0 else _keep() + fwd * 17.0
	return s0 + fwd * 4.5


func _go(n: Node3D, to: Vector3, face: float, run := false, via = null) -> void:
	## figurani yurgizib olib borish: devor/bino ichidan o'tmaydi (yo'l topiladi); devorga - minora eshigi orqali
	if rts and rts.N > 0 and not n.get_meta("cmd", false):
		if via != null:
			var st := rts._climb_steps(n, to, face)
			if not st.is_empty():
				st.append({"k": "release"})
				rts._start(n, st)
				n.set_meta("post", true)
				return
		elif rts._send(n, to, face, "idle", [{"k": "release"}]):
			return
	if n.has_meta("tw"):
		var old = n.get_meta("tw")
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	var d := to - n.position
	if d.length() < 0.2:
		n.position = to
		n.rotation.y = face
		return
	var flat := Vector3(d.x, 0, d.z)
	if flat.length() > 0.1:
		n.rotation.y = atan2(-flat.z, flat.x)
	var horse := Unit3D.rider_of(n) != null
	Unit3D.play(n, "Run" if run and not horse else "Walk")
	var tw := n.create_tween()
	var sp := 5.0 if run else 1.9
	if via != null:
		# avval devor tagidagi zinaga yuguradi, keyin zinadan ko'tariladi
		var v: Vector3 = via
		tw.tween_property(n, "position", v, maxf(0.5, n.position.distance_to(v) / sp))
		tw.tween_callback(func(): Unit3D.play(n, "Walk"))
		tw.tween_property(n, "position", to, 1.4)
	else:
		tw.tween_property(n, "position", to, maxf(0.5, d.length() / sp))
	tw.tween_callback(func():
		n.rotation.y = face
		Unit3D.play(n, "Idle"))
	n.set_meta("tw", tw)


func _switch_task(t: String) -> void:
	_task_mode = t
	_drill_t = 0.0
	_beat = 0
	_ensure_cmdr()
	var fwd := _muster_dir()
	var face := atan2(-fwd.z, fwd.x)
	var posts: Array = _wall_posts() if t == "devor" else []
	# askarlar barcha devorlar bo'ylab teng taqsimlanadi
	var elig := _all_figs().filter(func(x): return (x as Node3D).get_meta("kind", "") in ["nayzachi", "qilichboz", "kamonchi", "sarboz"]).size()
	var stepf := float(posts.size()) / float(maxi(1, elig)) if posts.size() > elig else 1.0
	var pi := 0
	var used := 0
	for n in _all_figs():
		var node: Node3D = n
		var k: String = node.get_meta("kind", "")
		pi = int(float(used) * stepf)
		if node.get_meta("manual", false):
			continue
		if t == "devor" and k in ["nayzachi", "qilichboz", "kamonchi", "sarboz"] and pi < posts.size():
			var post: Vector3 = posts[pi][0]
			var foot := Vector3(post.x, 0, post.z) + Vector3(cos(posts[pi][1] + PI), 0, -sin(posts[pi][1] + PI)) * 2.5
			_go(node, post, posts[pi][1], true, foot)
			node.set_meta("post", true)
			used += 1
			continue
		var was_up: bool = node.position.y > 1.0
		node.set_meta("post", false)
		if node.get_meta("manual", false):
			continue
		if node.has_meta("slot"):
			if was_up and rts:
				_go(node, node.get_meta("slot"), face)
			elif was_up:
				var down := Vector3(node.position.x, 0, node.position.z) + (_keep() - node.position).normalized() * 2.5
				down.y = 0.0
				var tw0 := node.create_tween()
				tw0.tween_property(node, "position", down, 1.2)
				tw0.tween_callback(func(): _go(node, node.get_meta("slot"), face))
				node.set_meta("tw", tw0)
			else:
				_go(node, node.get_meta("slot"), face)
	if cmdr != null and is_instance_valid(cmdr) and not walk_mode:
		_go(cmdr, _cmd_home(), face + PI)


func _update_drill(delta: float) -> void:
	if army_root == null:
		return
	var t: String = data.get("task", "dam")
	if t != _task_mode:
		_switch_task(t)
		return
	_drill_t += delta
	var fwd := _muster_dir()
	var right := Vector3(-fwd.z, 0, fwd.x)
	var face := atan2(-fwd.z, fwd.x)
	var c_ok := cmdr != null and is_instance_valid(cmdr)
	match t:
		"mashq":
			# ritm: har 1.8 soniyada qo'mondon buyrug'i - butun saf birga zarba beradi / qalqon ko'taradi
			if _drill_t >= 1.8:
				_drill_t = 0.0
				_beat += 1
				for n in _all_figs():
					var node: Node3D = n
					if node.get_meta("manual", false):
						continue
					if node.has_meta("tw") and (node.get_meta("tw") as Tween).is_valid() and (node.get_meta("tw") as Tween).is_running():
						continue
					var k: String = node.get_meta("kind", "")
					var row: int = node.get_meta("row", 0)
					var a := ""
					if k == "otliq":
						var rd := Unit3D.rider_of(node)
						if rd:
							_act(rd, "RideAttack" if _beat % 2 == 0 else "Ride")
						continue
					elif k == "top":
						continue
					elif k == "sarboz":
						a = ["Aim", "Fire", "Reload"][_beat % 3]
					elif k == "kamonchi":
						a = "Attack" if _beat % 2 == 0 else "Idle"
					else:
						a = "Attack" if _beat % 2 == 0 else "Block"
					# qatorlar ketma-ket (to'lqin kabi) bajaradi
					if row == 0:
						_act(node, a)
					else:
						get_tree().create_timer(row * 0.07).timeout.connect(func():
							if is_instance_valid(node):
								_act(node, a))
			# qo'mondon saf oldida u yoqdan-bu yoqqa yuradi, ba'zan to'xtab buyruq beradi
			if c_ok:
				_cmd_walk(delta, fwd, right, face)
		"saf":
			# saf bo'lib oldinga 6 m yurib, to'xtab, orqaga qaytadi (10 soniyalik sikl)
			var cyc := fmod(_drill_t, 12.0)
			var off := 0.0
			var moving := true
			if cyc < 4.5:
				off = 6.0 * smoothstep(0.0, 4.5, cyc)
			elif cyc < 6.0:
				off = 6.0
				moving = false
			elif cyc < 10.5:
				off = 6.0 * (1.0 - smoothstep(6.0, 10.5, cyc))
			else:
				moving = false
			for n in _all_figs():
				var node: Node3D = n
				if not node.has_meta("slot") or node.get_meta("kind", "") == "top" or node.get_meta("manual", false):
					continue
				if node.has_meta("tw") and (node.get_meta("tw") as Tween).is_valid() and (node.get_meta("tw") as Tween).is_running():
					continue
				node.position = (node.get_meta("slot") as Vector3) + fwd * off
				node.rotation.y = face
				var want := "Walk" if moving else "Idle"
				if node.get_meta("anim", "") != want:
					node.set_meta("anim", want)
					Unit3D.play(node, want)
					var rd := Unit3D.rider_of(node)
					if rd:
						Unit3D.play(rd, "Ride")
			if c_ok and not walk_mode:
				var home := _cmd_home() + right * 3.0
				if not (cmdr.has_meta("tw") and (cmdr.get_meta("tw") as Tween).is_valid() and (cmdr.get_meta("tw") as Tween).is_running()):
					cmdr.position = home + fwd * off
					cmdr.rotation.y = face + PI
					var cw := "Walk" if moving else "Cheer"
					if cmdr.get_meta("anim", "") != cw:
						cmdr.set_meta("anim", cw)
						Unit3D.play(cmdr, cw if cw == "Walk" else "Cheer")
		"devor":
			# devordagi askarlar tashqariga qarab turadi, ba'zan atrofga qaraydi
			if _drill_t > 3.0:
				_drill_t = 0.0
				for n in _all_figs():
					var node: Node3D = n
					if node.get_meta("post", false) and randf() < 0.25:
						Unit3D.play(node, "Look" if randf() < 0.6 else "Idle")
		_:
			pass


func _cmd_walk(delta: float, fwd: Vector3, right: Vector3, face: float) -> void:
	if walk_mode:
		return
	if cmdr.has_meta("tw") and (cmdr.get_meta("tw") as Tween).is_valid() and (cmdr.get_meta("tw") as Tween).is_running():
		return
	if _cmd_pause > 0.0:
		_cmd_pause -= delta
		if _cmd_pause <= 0.0:
			cmdr.set_meta("anim", "")
		return
	var home := _cmd_home()
	var span := float(ROW_W) * 0.75
	var ph: float = cmdr.get_meta("ph", 0.0) + delta * 0.32
	cmdr.set_meta("ph", ph)
	var x := sin(ph) * span
	var prev: Vector3 = cmdr.position
	cmdr.position = home + right * x
	var mv := cmdr.position - prev
	if mv.length() > 0.0005:
		cmdr.rotation.y = atan2(-mv.z, mv.x)
	if cmdr.get_meta("anim", "") != "Walk":
		cmdr.set_meta("anim", "Walk")
		Unit3D.play(cmdr, "Walk")
	# har 4-zarbada to'xtab, askarlarga qarab baqiradi
	if _beat % 4 == 3 and _drill_t < 0.05:
		_cmd_pause = 1.6
		cmdr.rotation.y = face + PI
		cmdr.set_meta("anim", "Cheer")
		Unit3D.play(cmdr, "Cheer")


# ================================================================ HUD

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
	vp.audio_listener_enable_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.handle_input_locally = false
	cont.add_child(vp)
	# yuqori panel
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 8
	bar.offset_right = -8
	bar.offset_top = 8
	bar.add_theme_stylebox_override("panel", UIKit.style(Color(0.05, 0.08, 0.12, 0.6), 12, Color(0.6, 0.8, 1.0, 0.22), 10))
	hud.add_child(bar)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	bar.add_child(h)
	h.add_child(UIKit.label("QAL'A: " + _p()["name"], 20, Color.WHITE))
	money_label = UIKit.label("", 16, UIKit.GOLD)
	money_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(money_label)
	var wb := UIKit.button(h, "Qo'mondon bo'lish (Tab)", "", _toggle_walk, true)
	wb.focus_mode = Control.FOCUS_NONE
	var grp := ButtonGroup.new()
	for sp in [0, 1, 2, 5]:
		var b := Button.new()
		b.text = "||" if sp == 0 else "%dx" % sp
		b.toggle_mode = true
		b.button_group = grp
		b.button_pressed = Game.speed == sp
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(Game.set_speed.bind(sp))
		h.add_child(b)
	var back := UIKit.button(h, "  Xaritaga qaytish  ", "", func():
		if not _leaving:
			_leaving = true
			exit_requested.emit(), true)
	back.focus_mode = Control.FOCUS_NONE
	# o'ng panel: mudofaa tahlili
	var side := PanelContainer.new()
	_side_panel = side
	side.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	side.offset_left = -330
	side.offset_right = -8
	side.offset_top = 70
	side.offset_bottom = -186
	side.add_theme_stylebox_override("panel", UIKit.style(Color(0.05, 0.08, 0.12, 0.6), 12, Color(0.6, 0.8, 1.0, 0.22), 12))
	hud.add_child(side)
	var sv := UIKit.scroll(side)
	army_box = VBoxContainer.new()
	army_box.add_theme_constant_override("separation", 6)
	sv.add_child(army_box)
	sv.add_child(HSeparator.new())
	sv.add_child(UIKit.label("MUDOFAA TAHLILI", 18, Color.WHITE))
	stats_box = VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 6)
	sv.add_child(stats_box)
	# pastki asboblar paneli
	var tb := PanelContainer.new()
	_tool_panel = tb
	tb.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	tb.offset_left = 8
	tb.offset_right = -8
	tb.offset_top = -176
	tb.offset_bottom = -8
	tb.add_theme_stylebox_override("panel", UIKit.style(Color(0.05, 0.08, 0.12, 0.65), 12, Color(0.6, 0.8, 1.0, 0.22), 10))
	hud.add_child(tb)
	var tv := VBoxContainer.new()
	tb.add_child(tv)
	# chap: bo'lim tugmalari, o'ng: binolar 3D rasmlari bilan
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	tv.add_child(hb)
	var tabs := VBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	hb.add_child(tabs)
	var tgrp := ButtonGroup.new()
	var rows: Array = []
	for ri in 3:
		var rowdef: Array = [["QAL'A", ROW1], ["XO'JALIK", ROW2], ["QO'SHIN", []]][ri]
		var tbn := Button.new()
		tbn.text = rowdef[0]
		tbn.toggle_mode = true
		tbn.button_group = tgrp
		tbn.button_pressed = ri == 0
		tbn.focus_mode = Control.FOCUS_NONE
		tbn.custom_minimum_size = Vector2(104, 34)
		if UIKit.title_font() != null:
			tbn.add_theme_font_override("font", UIKit.title_font())
		tbn.add_theme_font_size_override("font_size", 14)
		tabs.add_child(tbn)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.visible = ri == 0
		hb.add_child(row)
		rows.append(row)
		tbn.pressed.connect(func():
			for i in rows.size():
				(rows[i] as Control).visible = i == ri)
		if ri == 2:
			_build_army_tab(row)
		for t in rowdef[1]:
			if t == "mosque" and not Unit3D.is_muslim(_p()["country"]):
				continue
			row.add_child(_tool_card(t))
	tip_label = UIKit.label("Asbobni tanlang. G'ildirak - yaqinlashtirish, WASD / o'rta tugma - surish, Q/E - aylantirish, R - binoni burish.", 13, UIKit.INFO)
	tv.add_child(tip_label)
	msg_label = UIKit.label("", 14, UIKit.GOOD)
	msg_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	msg_label.offset_top = 66
	msg_label.offset_left = -300
	msg_label.offset_right = 300
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(msg_label)


func _tool_card(t: String) -> Button:
	## qurilish tugmasi: binoning 3D rasmi, nomi va narxi
	var b := Button.new()
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(84, 114)
	b.add_theme_stylebox_override("pressed", UIKit.style(Color(0.42, 0.29, 0.1, 0.98), 5, Color(1.0, 0.84, 0.4), 4))
	b.add_theme_stylebox_override("hover_pressed", UIKit.style(Color(0.48, 0.34, 0.12, 0.98), 5, Color(1.0, 0.9, 0.55), 4))
	b.add_theme_stylebox_override("normal", UIKit.style(UIKit.WOOD2, 5, Color(0.55, 0.4, 0.2, 0.9), 4))
	b.add_theme_stylebox_override("hover", UIKit.style(Color(0.33, 0.23, 0.13, 0.98), 5, Color(0.95, 0.76, 0.38), 4))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 3
	v.offset_right = -3
	v.offset_top = 3
	v.offset_bottom = -3
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	if t == "delete":
		var x := UIKit.label("×", 44, Color("#e0644a"))
		x.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		x.custom_minimum_size = Vector2(84, 60)
		x.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		v.add_child(x)
	else:
		var img := TextureRect.new()
		img.custom_minimum_size = Vector2(84, 60)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(img)
		var col := Color(Game.countries[_p()["country"]]["color"]) if Game.countries.has(_p()["country"]) else Color("#2f7d4a")
		ModelPreview.thumb(_model_file(t), img, col)
	var nl := UIKit.label(NAMES[t], 14, Color("#f6e7c4"))
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(nl)
	var ct := "" if t == "delete" else CastleEco.cost_text(_cost(t))
	ct = ct.replace(" oltin", "o").replace(" tosh", "t").replace(" yog'och", "y").replace(" + ", " ")
	if t in ["wall", "moat"]:
		ct += " /m"
	var cl := UIKit.label(ct if t != "delete" else "yarmi qaytadi", 11, Color("#d9b870"))
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.clip_text = true
	v.add_child(cl)
	if CastleEco.ECON.has(t):
		var pr: Dictionary = CastleEco.ECON[t]["prod"]
		b.tooltip_text = "%s: kuniga +%d %s" % [NAMES[t], pr.values()[0], CastleEco.RES_NAMES[pr.keys()[0]].to_lower()]
	else:
		b.tooltip_text = NAMES[t]
	b.pressed.connect(_set_tool.bind(t))
	tool_btns[t] = b
	return b


func _set_tool(t: String) -> void:
	if tool == t:
		t = ""
	tool = t
	has_start = false
	for k in tool_btns:
		(tool_btns[k] as Button).set_pressed_no_signal(k == tool)
	if t == "":
		if tip_label == null:
			return
		tip_label.text = "Asbobni tanlang. G'ildirak - yaqinlashtirish, WASD / o'rta tugma - surish, Q/E - aylantirish, R - binoni burish."
	elif TIPS.has(t):
		var s: String = TIPS[t]
		tip_label.text = (s % TOWER_COVER) if t == "tower" else s.replace("(%d oltin/m)", "(%s /m)" % CastleEco.cost_text(_cost(t)))
	elif CastleEco.ECON.has(t):
		var pr: Dictionary = CastleEco.ECON[t]["prod"]
		tip_label.text = "%s: joyni bosing (%s). Kuniga +%d %s. Odatda qal'a tashqarisiga qo'yiladi. R - burish." % [
			NAMES[t], CastleEco.cost_text(_cost(t)), pr.values()[0], CastleEco.RES_NAMES[pr.keys()[0]].to_lower()]
	elif t == "mosque":
		tip_label.text = "Masjid: joyni bosing (%s). Xalq noroziligi kamayadi, namoz vaqtlarida azon aytiladi. R - burish." % CastleEco.cost_text(_cost(t))
	else:
		tip_label.text = "%s: joyni bosing (%s). R - burish. Bino ichki hovlidan joy oladi." % [NAMES[t], CastleEco.cost_text(_cost(t))]
	_update_ghost()


func _msg(t: String, bad := false) -> void:
	if walk_mode and not bad:
		return          # qo'mondon bo'lib yurganda ekranda yozuv chiqmaydi
	msg_label.text = t
	msg_label.add_theme_color_override("font_color", UIKit.BAD if bad else UIKit.GOOD)
	var tw := msg_label.create_tween()
	msg_label.modulate.a = 1.0
	tw.tween_interval(2.5)
	tw.tween_property(msg_label, "modulate:a", 0.0, 0.8)


func _show_stats() -> void:
	if stats_box == null:
		return
	UIKit.clear(stats_box)
	var s := stats
	if s["closed"]:
		stats_box.add_child(UIKit.label("Qal'a YOPIQ - dushman faqat darvoza yoki devorni buzib kiradi", 14, UIKit.GOOD, true))
	elif data["walls"].is_empty():
		stats_box.add_child(UIKit.label("Hali devor yo'q. Devor asbobini tanlab arkni o'rab chiqing.", 14, UIKit.GOLD, true))
	else:
		stats_box.add_child(UIKit.label("Qal'a OCHIQ - devorda bo'shliq bor, dushman bemalol kiradi!", 14, UIKit.BAD, true))
	stats_box.add_child(UIKit.label("Ichki hovli: %d m²   (bo'sh: %d m²)" % [int(s["area"]), int(s["free"])], 13, UIKit.INFO))
	stats_box.add_child(UIKit.label("Hovliga sig'adigan askar: %d" % s["capacity"], 14, Color.WHITE))
	stats_box.add_child(UIKit.label("Devor: %d m   Minora: %d   Darvoza: %d" % [int(s["wall_len"]), s["towers"], s["gates"]], 13, UIKit.INFO))
	var bc := UIKit.BAD if s["blind"] > 0.5 else UIKit.GOOD
	stats_box.add_child(UIKit.label("Ko'r devor (minora yetmaydi): %d m  - qizil belgilangan" % int(s["blind"]), 13, bc, true))
	stats_box.add_child(HSeparator.new())
	stats_box.add_child(UIKit.label("TOMONLAR KUCHI", 15, Color.WHITE))
	for i in 4:
		var sc: Dictionary = s["sectors"][i]
		var col := UIKit.GOOD if sc["score"] >= 60 else (UIKit.GOLD if sc["score"] >= 30 else UIKit.BAD)
		UIKit.stat(stats_box, SECT[i], sc["score"], 100.0, col, "%d" % int(sc["score"]))
		stats_box.add_child(UIKit.label("   devor %d m, minora %d, darvoza %d, xandaq %d m" % [int(sc["wall"]), sc["towers"], sc["gates"], int(sc["moat"])], 11, UIKit.DIM))
	if s["weakest"] >= 0 and not data["walls"].is_empty():
		var w: Dictionary = s["sectors"][s["weakest"]]
		var why: Array = []
		if w["wall"] <= 0.0:
			why.append("devor yo'q")
		if w["towers"] < 2:
			why.append("minora kam")
		if w["gates"] > 0:
			why.append("darvoza bor")
		if w["blind"] > 0.5:
			why.append("ko'r devor %d m" % int(w["blind"]))
		if w["moat"] <= 0.0:
			why.append("xandaq yo'q")
		stats_box.add_child(HSeparator.new())
		stats_box.add_child(UIKit.label("ENG ZAIF TOMON: %s" % SECT[s["weakest"]].to_upper(), 15, UIKit.BAD))
		stats_box.add_child(UIKit.label("Sababi: " + ", ".join(why) + ". Dushman ayg'oqchilari aynan shu tomonni topadi.", 12, UIKit.INFO, true))


func intro_dive() -> void:
	## xaritadan tushib kelish: kamera baland osmondan qal'aga silliq tushadi
	cam_dist = 950.0
	_tdist = 160.0
	_apply_cam()


func rise_out() -> void:
	## xaritaga qaytish: kamera osmonga ko'tariladi
	_tdist = 1300.0


func _close() -> void:
	Sfx.stop_loops("c_")
	if Game.changed.is_connected(_show_army):
		Game.changed.disconnect(_show_army)
	if hud:
		hud.queue_free()
	closed.emit()
	queue_free()


# ================================================================ qo'shin: yollash va hovlida saf

const TASK_TIPS := {"dam": "askarlar hovlida dam oladi",
	"mashq": "askarlar qilich, nayza va kamon bilan mashq qiladi - tayyorgarlik oshadi",
	"saf": "askarlar saf bo'lib oldinga-orqaga yurishni o'rganadi",
	"devor": "piyodalar devorga chiqib qo'riqlaydi - dushman hujumida darrov devordan qaytaradi"}
var _task_btns := {}
var _drill_bar: ProgressBar
var _drill_lbl: Label
var _gear_lbl: Label
var _gear_btn: Button
var _task_mode := ""
var _drill_t := 0.0
var _beat := 0
var _cmd_pause := 0.0
var cmdr: Node3D
var _army_cards := {}       # tur -> {"count": Label, "btns": {n: Button}, "cost": Label}
var _army_sum: Label
var _army_dyn: VBoxContainer


func _build_army_cards() -> void:
	## yollash kartalari bir marta quriladi (har birida askarning jonli 3D ko'rinishi)
	UIKit.clear(army_box)
	_army_cards.clear()
	army_box.add_child(UIKit.label("QO'SHIN", 20, Color("#f3d58a")))
	_army_sum = UIKit.label("", 12, UIKit.INFO, true)
	army_box.add_child(_army_sum)
	# qo'mondon vazifasi
	army_box.add_child(UIKit.label("Qo'mondon buyrug'i:", 13, Color("#f3d58a")))
	var tg := GridContainer.new()
	tg.columns = 2
	tg.add_theme_constant_override("h_separation", 4)
	tg.add_theme_constant_override("v_separation", 4)
	army_box.add_child(tg)
	var grp := ButtonGroup.new()
	_task_btns.clear()
	for t in CastleEco.TASKS:
		var b := Button.new()
		b.text = CastleEco.TASKS[t]
		b.toggle_mode = true
		b.button_group = grp
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 13)
		b.tooltip_text = TASK_TIPS[t]
		b.button_pressed = data.get("task", "dam") == t
		b.pressed.connect(func():
			for nd in _all_figs():
				if rts:
					rts.release(nd)
			if rts:
				rts.clear_sel()
			_task_mode = ""
			data["task"] = t
			_msg("Qo'mondon: " + TASK_TIPS[t])
			_show_army())
		tg.add_child(b)
		_task_btns[t] = b
	_drill_bar = ProgressBar.new()
	_drill_bar.max_value = 100
	_drill_bar.show_percentage = false
	_drill_bar.custom_minimum_size = Vector2(0, 10)
	army_box.add_child(_drill_bar)
	_drill_lbl = UIKit.label("", 11, UIKit.DIM, true)
	army_box.add_child(_drill_lbl)
	# temirchi: zirh / miltiq yaxshilash
	var gr := UIKit.row(army_box, 6)
	_gear_lbl = UIKit.label("", 13, Color("#f3d58a"), true)
	gr.add_child(_gear_lbl)
	_gear_btn = UIKit.button(gr, "Yasash", "", func():
		var e := CastleEco.upgrade_gear(_p())
		if e != "":
			_msg(e, true)
		else:
			Sfx.play("sandon", -4.0)
			for nd in _all_figs():
				Unit3D.equip(nd, CastleEco.gear(_p()))
			_army_cards.clear()
			_msg("Temirchilar yangi %s tayyorladi" % ("miltiqlarni" if Game.era == 2 else "zirhlarni"))
		_show_army())
	_gear_btn.focus_mode = Control.FOCUS_NONE
	var fac := Unit3D.faction_for(_p()["country"])
	var col := Color(Game.countries[_p()["country"]]["color"]) if Game.countries.has(_p()["country"]) else Color("#2f7d4a")
	var bst := Unit3D.building_style(_p()["country"])
	for k in CastleEco.units():
		var u: Dictionary = CastleEco.units()[k]
		if u.has("only") and not (bst in u["only"]):
			continue
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", UIKit.style(Color(0.09, 0.065, 0.045, 0.75), 5, Color(0.55, 0.4, 0.2, 0.7), 4))
		army_box.add_child(pc)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		pc.add_child(h)
		var view := ModelPreview.unit_view(fac, k, col, Vector2(92, 112))
		view.tooltip_text = "%s - sichqonchani olib keling" % u["name"]
		var vm = view.get("model")
		if vm is Node3D:
			Unit3D.equip(vm, CastleEco.gear(_p()))
		h.add_child(view)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		var nm := UIKit.label(u["name"], 18, Color("#f6e7c4"))
		nm.add_theme_font_size_override("font_size", 15)
		v.add_child(nm)
		var cnt := UIKit.label("", 13, Color.WHITE)
		v.add_child(cnt)
		var cost := UIKit.label("", 11, Color("#d9b870"), true)
		v.add_child(cost)
		var br := UIKit.row(v, 4)
		var btns := {}
		for n in [1, 5, 10]:
			var b := UIKit.button(br, "+%d" % n, "", _recruit.bind(k, n))
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(44, 28)
			btns[n] = b
		_army_cards[k] = {"count": cnt, "btns": btns, "cost": cost}
	_army_dyn = VBoxContainer.new()
	_army_dyn.add_theme_constant_override("separation", 6)
	army_box.add_child(_army_dyn)


func _show_army() -> void:
	if army_box == null:
		return
	if _army_cards.is_empty() or not is_instance_valid(_army_sum):
		_build_army_cards()
	var p := _p()
	var g := CastleEco.gold(p)
	for t in _task_btns:
		(_task_btns[t] as Button).set_pressed_no_signal(data.get("task", "dam") == t)
	var gl := CastleEco.gear(_p())
	var defs := CastleEco.gear_defs()
	var cur_name: String = defs[gl]["name"] if defs.has(gl) else ("Oddiy kiyim" if Game.era == 1 else "Fitilli miltiq")
	if defs.has(gl + 1):
		_gear_lbl.text = "Temirchi: %s -> %s (%s)" % [cur_name, defs[gl + 1]["name"], CastleEco.cost_text(defs[gl + 1]["cost"])]
		var why := "Avval temirchi quring" if CastleEco.count(_p(), "smithy") == 0 else CastleEco.can_pay(defs[gl + 1]["cost"])
		_gear_btn.disabled = why != ""
		_gear_btn.tooltip_text = why if why != "" else defs[gl + 1]["info"]
		_gear_btn.visible = true
	else:
		_gear_lbl.text = "Temirchi: %s (eng yaxshisi)" % cur_name
		_gear_btn.visible = false
	var dr := float(data.get("drill", 0.0))
	_drill_bar.value = dr
	_drill_lbl.text = "Tayyorgarlik: %d%%  (jangda askarlar %d%% chidamliroq). %s" % [int(dr), int(dr / 2.0),
		"Mashq kuniga +1.5%, oziq ko'proq ketadi." if data.get("task", "dam") == "mashq" else ("Saf mashqi kuniga +0.6%." if data.get("task", "dam") == "saf" else "Mashqsiz asta pasayadi.")]
	_army_sum.text = "Jami: %d askar (kuch %d).  Maosh: %d oltin/kun, oziq: %.0f/kun" % [CastleEco.army_total(p),
		int(CastleEco.army_power(p)), int(g["pay"]), _food_per_day()]
	if float(data.get("hunger", 0.0)) > 0.0:
		_army_sum.text += "\nOCH! Oziq yo'q - ruh va jang kuchi %d%%." % int(CastleEco.hunger_penalty(data) * 100.0)
		_army_sum.add_theme_color_override("font_color", UIKit.BAD)
	else:
		_army_sum.add_theme_color_override("font_color", UIKit.INFO)
	for k in _army_cards:
		var u: Dictionary = CastleEco.units()[k]
		var c: Dictionary = _army_cards[k]
		(c["count"] as Label).text = "Qal'ada: %d" % int(data["army"].get(k, 0))
		(c["cost"] as Label).text = "%d oltin, %d oziq, %d kun  (%s)" % [CastleEco.unit_cost(p, k), u["food"], u["days"],
			CastleEco.NEED_NAMES.get(u["needs"], u["needs"])]
		for n in c["btns"]:
			var why := CastleEco.can_recruit(p, k, n)
			var b: Button = c["btns"][n]
			b.disabled = why != ""
			b.tooltip_text = why if why != "" else "%d ta yollash" % n
	UIKit.clear(_army_dyn)
	var ab := _army_dyn
	# josuslar: dushman hujumini oldindan bilish, dushman qal'alari haqida ma'lumot
	var srow := UIKit.row(ab, 4)
	var sl := UIKit.label("Josuslar: %d" % Game.spies, 14, Color.WHITE)
	sl.custom_minimum_size = Vector2(110, 0)
	srow.add_child(sl)
	var why_s := "" if Game.spies < SiegeCastle.MAX_SPIES and Game.money >= SiegeCastle.SPY_COST else ("Yetarli" if Game.spies >= SiegeCastle.MAX_SPIES else "Oltin yetmaydi")
	var sb := UIKit.button(srow, "Yollash", why_s, func():
		var e := SiegeCastle.hire_spy()
		if e != "":
			_msg(e, true)
		_show_army())
	sb.focus_mode = Control.FOCUS_NONE
	ab.add_child(UIKit.label("   %d oltin, maoshi %.1f oltin/kun. Dushman hujumini %s oldin bilasiz, qal'alarini ko'rasiz." % [SiegeCastle.SPY_COST, SiegeCastle.SPY_PAY,
		"bir necha kun" if Game.spies == 0 else "%d kun ko'proq" % (2 * Game.spies + 2)], 11, UIKit.DIM, true))
	if not data["queue"].is_empty():
		ab.add_child(UIKit.label("Tayyorlanmoqda:", 13, UIKit.GOLD))
		for q in data["queue"]:
			ab.add_child(UIKit.label("   %d %s - %d kun qoldi" % [q["count"], CastleEco.units()[q["kind"]]["name"].to_lower(), q["days_left"]], 12, UIKit.INFO))
	var prod := {}
	for b in data["buildings"]:
		if CastleEco.ECON.has(b["t"]):
			var pr: Dictionary = CastleEco.ECON[b["t"]]["prod"]
			for r in pr:
				prod[r] = int(prod.get(r, 0)) + int(pr[r])
	var parts: Array = []
	for r in prod:
		parts.append("+%d %s" % [prod[r], CastleEco.RES_NAMES[r].to_lower()])
	ab.add_child(UIKit.label("Xo'jalik kuniga: " + (", ".join(parts) if parts.size() else "hali yo'q - pastdagi XO'JALIK qatoridan quring"), 12, UIKit.GOOD if parts.size() else UIKit.GOLD, true))


func _food_per_day() -> float:
	var e := 0.0
	for k in data["army"]:
		e += float(data["army"][k]) * CastleEco.EAT * {"otliq": 2.0, "fil": 6.0, "arava": 3.0}.get(k, 1.0)
	return e


func _recruit(kind: String, n: int) -> void:
	if CastleEco.recruit(_p(), kind, n):
		Sfx.play("tanga", -4.0)
		_msg("%d %s yollandi - kazarmada tayyorlanmoqda" % [n, CastleEco.units()[kind]["name"].to_lower()])
	_show_army()


func _inside(p: Vector3) -> bool:
	if _g_n == 0:
		return true
	var x := int(round(p.x / 2.0)) + _g_half
	var z := int(round(p.z / 2.0)) + _g_half
	if x < 0 or z < 0 or x >= _g_n or z >= _g_n:
		return false
	var i := z * _g_n + x
	return _g_out[i] == 0 and _g_blk[i] == 0


func _muster_dir() -> Vector3:
	if not data["gates"].is_empty():
		var d := _v(data["gates"][0]["p"]) - _keep()
		if d.length() > 1.0:
			return d.normalized()
	return Vector3(0, 0, 1)


func _make_slots() -> void:
	## hovlida saf joylari: arkdan darvoza tomonga qatorlar
	slots.clear()
	var fwd := _muster_dir()
	var right := Vector3(-fwd.z, 0, fwd.x)
	var closed_ok: bool = stats.get("closed", false)
	var cand: Array = []
	for r in 60:
		for c in range(-ROW_W / 2, ROW_W / 2 + 1):
			var pos := _keep() + fwd * (17.0 + r * 1.8) + right * (c * 1.5)
			if closed_ok and not _inside(pos):
				continue
			if not closed_ok and pos.distance_to(_keep()) > 70.0:
				continue
			var ok := true
			for b in data["buildings"]:
				var f: Vector2 = FOOT[b["t"]]
				if _v(b["p"]).distance_to(pos) < maxf(f.x, f.y) * 0.6:
					ok = false
					break
			if ok:
				cand.append([r * 100 + absi(c), pos])
	cand.sort_custom(func(a, b): return a[0] < b[0])
	for c in cand:
		slots.append(c[1])
		if slots.size() >= MAX_FIG + 20:
			break


func _door(kind: String) -> Vector3:
	var need: String = CastleEco.units()[kind]["needs"]
	for b in data["buildings"]:
		if b["t"] == need:
			return _v(b["p"]) + Basis(Vector3.UP, float(b["rot"])) * Vector3(0, 0, 6.0)
	return _keep() + _muster_dir() * 14.0


func _refresh_army(force := false) -> void:
	if army_root == null:
		return
	var a: Dictionary = data["army"]
	var total := 0
	for k in a:
		total += int(a[k])
	var per := maxi(1, int(ceil(float(total) / MAX_FIG)))
	var want := {}
	for k in (["nayzachi", "sarboz", "top", "otliq"] if Game.era == 2 else ["nayzachi", "qilichboz", "kamonchi", "otliq", "fil", "arava"]):
		want[k] = int(ceil(float(a.get(k, 0)) / per))
	var changed := force
	for k in want:
		var arr: Array = figs.get(k, [])
		while arr.size() > want[k]:
			(arr.pop_back() as Node3D).queue_free()
			changed = true
		while arr.size() < want[k]:
			var col := Color(Game.countries[_p()["country"]]["color"])
			var f: Node3D = Unit3D.cavalry(Unit3D.faction_for(_p()["country"]), "otliq", col) if k == "otliq" else Unit3D.soldier(Unit3D.faction_for(_p()["country"]), k, col)
			if f == null:
				break
			army_root.add_child(f)
			Unit3D.equip(f, CastleEco.gear(_p()))
			f.position = _keep() if _initial else _door(k)
			f.set_meta("new", not _initial)
			arr.append(f)
			changed = true
		figs[k] = arr
	if not changed:
		return
	# saflarga joylash (darvoza tomonga qarab): eng oldinda nayzachilar, keyin qilichbozlar, kamonchilar, orqada otliqlar
	var fwd := _muster_dir()
	var face := atan2(-fwd.z, fwd.x)
	var i := 0
	for k in (["otliq", "top", "sarboz", "nayzachi"] if Game.era == 2 else ["fil", "arava", "otliq", "kamonchi", "qilichboz", "nayzachi"]):
		# har tur yangi qatordan boshlanadi - alohida bo'linmalar ko'rinadi
		if i % (ROW_W + 1) != 0:
			i += (ROW_W + 1) - i % (ROW_W + 1)
		for f in figs.get(k, []):
			var node: Node3D = f
			var target: Vector3 = slots[mini(i, slots.size() - 1)] if slots.size() > 0 else _keep() + fwd * 20.0
			node.set_meta("slot", target)
			node.set_meta("row", i / (ROW_W + 1))
			node.set_meta("kind", k)
			i += 3 if k in ["top", "fil", "arava"] else (2 if k == "otliq" else 1)
			if node.get_meta("manual", false):
				continue
			if _initial or not node.get_meta("new", false) and node.position.distance_to(target) < 0.3:
				node.position = target
				node.rotation.y = face
				Unit3D.play(node, "Idle")
				var rd := Unit3D.rider_of(node)
				if rd:
					Unit3D.play(rd, "Ride")
				continue
			# yangi askar: kazarma eshigidan saf joyigacha yurib boradi (devor va binolarni aylanib)
			if rts and rts.N > 0:
				node.set_meta("new", false)
				if rts._send(node, target, face, "idle", [{"k": "release"}]):
					continue
			var d := target - node.position
			node.rotation.y = atan2(-d.z, d.x)
			var dur := maxf(0.6, d.length() / (6.0 if k == "otliq" else 3.6))
			Unit3D.play(node, "Run" if k != "otliq" else "Walk")
			var rd2 := Unit3D.rider_of(node)
			if rd2:
				Unit3D.play(rd2, "Ride")
			var tw := node.create_tween()
			tw.tween_property(node, "position", target, dur)
			node.set_meta("tw", tw)
			tw.tween_callback(func():
				node.rotation.y = face
				node.set_meta("new", false)
				Unit3D.play(node, "Idle"))
	_initial = false
	_task_mode = ""          # vazifa ko'rinishi qayta quriladi (yangi askarlar ham qo'shiladi)
	if per > 1:
		_msg("Hovlida: 1 figura = %d askar" % per)


func _exit_tree() -> void:
	Sfx.stop_loops("c_")


func _tower_floor(o: Node3D) -> void:
	## minora tepasidagi maydoncha: ichi bo'sh "teshik" bo'lib ko'rinmasin - tosh pol yotqiziladi
	var top := float(Unit3D.STYLE_TOP.get(Unit3D.castle_style(_p()["country"]), 11.65))
	var box := AABB()
	var first := true
	var inv := o.global_transform.affine_inverse()
	for mi in o.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		var ab: AABB = inv * m.global_transform * m.get_aabb()
		box = ab if first else box.merge(ab)
		first = false
	if first:
		return
	var r := minf(box.size.x, box.size.z) * 0.5 * 0.82
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.25
	cm.radial_segments = 28
	var f := MeshInstance3D.new()
	f.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.55, 0.45)
	mat.roughness = 0.95
	f.material_override = mat
	f.position = Vector3(0, top - 0.14, 0)
	o.add_child(f)


# ================================================================ pastki kontekst paneli (Kazaki uslubida)
## Yon panellar yo'q. Nimani bossangiz - pastda o'shaning paneli chiqadi:
##   ark - qurilish (qal'a, xo'jalik) va qo'shin buyrug'i; kazarma - piyoda askar yollash; otxona - otliq;
##   temirchi - zirh; darvoza - ochish/yopish; askarlar - buyruqlar; bo'sh joy - panel yopiladi.

var ctx := ""
var _ctx_panel: PanelContainer
var _ctx_box: HBoxContainer
var _ctx_title: Label
var _ctx_cards := {}         # tur -> {"count": Label, "btn": Button}
var _ctx_army_row: HBoxContainer
var _ctx_t := 0.0


func _build_ctx() -> void:
	_side_panel.visible = false
	_tool_panel.visible = false
	_ctx_panel = PanelContainer.new()
	_ctx_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_ctx_panel.offset_left = 8
	_ctx_panel.offset_right = -8
	_ctx_panel.offset_top = -176
	_ctx_panel.offset_bottom = -8
	_ctx_panel.add_theme_stylebox_override("panel", UIKit.style(Color(0.05, 0.08, 0.12, 0.7), 12, Color(0.6, 0.8, 1.0, 0.22), 10))
	_ctx_panel.visible = false
	hud.add_child(_ctx_panel)
	var v := VBoxContainer.new()
	_ctx_panel.add_child(v)
	_ctx_title = UIKit.label("", 15, Color("#f3d58a"))
	v.add_child(_ctx_title)
	var sc := ScrollContainer.new()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, 128)
	v.add_child(sc)
	_ctx_box = HBoxContainer.new()
	_ctx_box.add_theme_constant_override("separation", 8)
	sc.add_child(_ctx_box)
	if rts and rts.panel:
		# askar buyruqlari paneli ham pastda
		rts.panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		rts.panel.offset_left = 8
		rts.panel.offset_right = -8
		rts.panel.offset_top = -176
		rts.panel.offset_bottom = -8
	tip_label.text = "Arkni bossangiz - qurilish; kazarma / otxonani bossangiz - askar yollash; askarni bossangiz - buyruqlar."


func building_at(p: Vector3) -> Dictionary:
	## sichqoncha ostidagi qal'a qismi: {"t": "keep"/bino turi/"gate"/"tower", "i": indeks}
	if p == Vector3.INF:
		return {}
	var q := Vector3(p.x, 0, p.z)
	var kf: Vector2 = FOOT["keep"]
	var kd := q - _keep()
	if absf(kd.x) < kf.x * 0.5 + 1.0 and absf(kd.z) < kf.y * 0.5 + 1.0:
		return {"t": "keep", "i": 0}
	for i in data["buildings"].size():
		var b: Dictionary = data["buildings"][i]
		var f: Vector2 = FOOT.get(b["t"], Vector2(8, 8))
		var l: Vector3 = Basis(Vector3.UP, -float(b["rot"])) * (q - _v(b["p"]))
		if absf(l.x) < f.x * 0.5 + 0.5 and absf(l.z) < f.y * 0.5 + 0.5:
			return {"t": b["t"], "i": i}
	for i in data["gates"].size():
		if _v(data["gates"][i]["p"]).distance_to(q) < 5.5:
			return {"t": "gate", "i": i}
	return {}


func open_ctx(t: String) -> void:
	## panelni ochish (t = "" - yopish)
	ctx = t
	if rts:
		rts.clear_sel()
	_tool_panel.visible = t == "keep" and not walk_mode
	_ctx_panel.visible = t != "" and t != "keep"
	UIKit.clear(_ctx_box)
	_ctx_cards.clear()
	match t:
		"barracks", "stable", "ustaxona":
			var need := t
			_ctx_title.text = {"barracks": "KAZARMA - piyoda askar yollash (kartani bosing: +1, Shift bilan +5)",
				"stable": "OTXONA - otliq askar yollash (kartani bosing: +1, Shift bilan +5)",
				"ustaxona": "QAMAL USTAXONASI - narvonchi, taran va manjaniq (jangga faqat shu yerda yasalganlari chiqadi)"}[t]
			var bst := Unit3D.building_style(_p()["country"])
			var fac := Unit3D.faction_for(_p()["country"])
			var col := Color(Game.countries[_p()["country"]]["color"]) if Game.countries.has(_p()["country"]) else Color("#2f7d4a")
			for k in CastleEco.units():
				var u: Dictionary = CastleEco.units()[k]
				if u["needs"] != need or (u.has("only") and not (bst in u["only"])):
					continue
				_ctx_unit_card(k, u, fac, col)
		"smithy":
			_ctx_title.text = "TEMIRCHI - askarlar zirhi va qurollari"
			var gl := CastleEco.gear(_p())
			var defs := CastleEco.gear_defs()
			var cur_name: String = defs[gl]["name"] if defs.has(gl) else "Oddiy kiyim"
			var vb := VBoxContainer.new()
			_ctx_box.add_child(vb)
			vb.add_child(UIKit.label("Hozir: " + cur_name, 15, Color.WHITE))
			if defs.has(gl + 1):
				vb.add_child(UIKit.label("Keyingisi: %s (%s)\n%s" % [defs[gl + 1]["name"], CastleEco.cost_text(defs[gl + 1]["cost"]), defs[gl + 1]["info"]], 13, UIKit.INFO, true))
				UIKit.button(vb, "Yasash", "", func():
					var e := CastleEco.upgrade_gear(_p())
					if e != "":
						_msg(e, true)
					else:
						Sfx.play("sandon", -4.0)
						for nd in _all_figs():
							Unit3D.equip(nd, CastleEco.gear(_p()))
					open_ctx("smithy"))
			else:
				vb.add_child(UIKit.label("Eng yaxshi zirh tayyor.", 13, UIKit.GOOD))
		"gate":
			_ctx_title.text = "DARVOZA"
			var b := Button.new()
			b.text = "Darvozani yopish" if rts.gates_open() else "Darvozani ochish"
			b.custom_minimum_size = Vector2(220, 60)
			b.focus_mode = Control.FOCUS_NONE
			b.pressed.connect(func():
				rts.toggle_gate()
				open_ctx("gate"))
			_ctx_box.add_child(b)
			_ctx_box.add_child(UIKit.label("Darvoza: %s. Yopiq bo'lsa askarlar qal'adan chiqa olmaydi." % ("OCHIQ" if rts.gates_open() else "YOPIQ"), 14, UIKit.INFO, true))
		"keep":
			pass
		"":
			pass
		_:
			_ctx_title.text = NAMES.get(t, t)
			_ctx_box.add_child(UIKit.label(TIPS.get(t, "Bu bino ishlamoqda."), 13, UIKit.INFO, true))
	_refresh_ctx()


func _ctx_unit_card(k: String, u: Dictionary, fac: String, col: Color) -> void:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(150, 124)
	b.add_theme_stylebox_override("normal", UIKit.style(UIKit.WOOD2, 5, Color(0.55, 0.4, 0.2, 0.9), 4))
	b.add_theme_stylebox_override("hover", UIKit.style(Color(0.33, 0.23, 0.13, 0.98), 5, Color(0.95, 0.76, 0.38), 4))
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var view := ModelPreview.unit_view(fac, k, col, Vector2(64, 118))
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(view)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(vb)
	var nm := UIKit.label(u["name"], 14, Color("#f6e7c4"))
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(nm)
	var cnt := UIKit.label("", 22, Color.WHITE)
	cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(cnt)
	var cost := UIKit.label("%d oltin\n%d oziq, %d kun" % [CastleEco.unit_cost(_p(), k), u["food"], u["days"]], 11, Color("#d9b870"))
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(cost)
	b.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			var n := 5 if (e as InputEventMouseButton).shift_pressed else 1
			var why := CastleEco.can_recruit(_p(), k, n)
			if why != "":
				_msg(why, true)
			else:
				_recruit(k, n)
			_refresh_ctx())
	_ctx_box.add_child(b)
	_ctx_cards[k] = {"count": cnt, "btn": b}


func _refresh_ctx() -> void:
	for k in _ctx_cards:
		var q := 0
		for it in data["queue"]:
			if it["kind"] == k:
				q += int(it["count"])
		(_ctx_cards[k]["count"] as Label).text = "%d%s" % [int(data["army"].get(k, 0)), ("  (+%d)" % q) if q > 0 else ""]
		var why := CastleEco.can_recruit(_p(), k, 1)
		(_ctx_cards[k]["btn"] as Button).tooltip_text = why if why != "" else "Bosing: +1 askar (Shift: +5)"
		(_ctx_cards[k]["btn"] as Button).modulate = Color(1, 1, 1, 1) if why == "" else Color(0.7, 0.7, 0.7, 1)


func _build_army_tab(row: HBoxContainer) -> void:
	## arkdagi "QO'SHIN" bo'limi: qo'mondon buyrug'i (dam, mashq, saf, devor) va josuslar
	_ctx_army_row = row
	var grid := GridContainer.new()
	grid.columns = 2
	row.add_child(grid)
	var grp := ButtonGroup.new()
	for t in CastleEco.TASKS:
		var b := Button.new()
		b.text = CastleEco.TASKS[t]
		b.toggle_mode = true
		b.button_group = grp
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(150, 40)
		b.tooltip_text = TASK_TIPS[t]
		b.button_pressed = data.get("task", "dam") == t
		b.pressed.connect(func():
			for nd in _all_figs():
				if rts:
					rts.release(nd)
			if rts:
				rts.clear_sel()
			_task_mode = ""
			data["task"] = t
			_msg("Qo'mondon: " + TASK_TIPS[t])
			_show_army())
		grid.add_child(b)
	var vb := VBoxContainer.new()
	row.add_child(vb)
	var info := UIKit.label("", 13, UIKit.INFO, true)
	info.custom_minimum_size = Vector2(420, 0)
	vb.add_child(info)
	row.set_meta("info", info)
	UIKit.button(vb, "Josus yollash (%d oltin)" % SiegeCastle.SPY_COST, "", func():
		var e := SiegeCastle.hire_spy()
		if e != "":
			_msg(e, true)
		_show_army())


func _ctx_tick(delta: float) -> void:
	_ctx_t += delta
	if _ctx_t < 0.5:
		return
	_ctx_t = 0.0
	if not _ctx_cards.is_empty():
		_refresh_ctx()
	if _ctx_army_row and _ctx_army_row.has_meta("info"):
		var p := _p()
		var g := CastleEco.gold(p)
		var dr := float(data.get("drill", 0.0))
		(_ctx_army_row.get_meta("info") as Label).text = "Jami: %d askar (kuch %d). Maosh: %d oltin/kun, oziq: %.0f/kun.\nTayyorgarlik: %d%%. Josuslar: %d.%s" % [
			CastleEco.army_total(p), int(CastleEco.army_power(p)), int(g["pay"]), _food_per_day(), int(dr), Game.spies,
			"\nOCH! Oziq yo'q." if float(data.get("hunger", 0.0)) > 0.0 else ""]
	# askar belgilanganda pastda buyruqlar, bino paneli yopiladi
	if rts and rts.panel:
		var has_sel := not rts.sel.is_empty()
		rts.panel.visible = has_sel or walk_mode
		if rts.panel.visible:
			rts._refresh_kinds(false)
		if has_sel and ctx != "":
			ctx = ""
			_ctx_panel.visible = false
			_tool_panel.visible = false
