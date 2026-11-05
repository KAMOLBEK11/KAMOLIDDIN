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
	"mosque": "Masjid", "house": "Uylar"}
const ROW1 := ["wall", "tower", "gate", "moat", "barracks", "granary", "well", "smithy", "stable", "mosque", "delete"]
const ROW2 := ["farm", "lumber", "quarry", "market", "mint", "house"]
const MAX_FIG := 160
const ROW_W := 10          # saf kengligi (figura)
const TIPS := {"wall": "Devor: 1-bosish - boshlanish, keyingi bosishlar - devorni davom ettirish. O'ng tugma / Esc - tugatish. Uchlariga minora o'zi qo'yiladi. (%d oltin/m)",
	"moat": "Xandaq: devor tashqarisidan chizing - dushmanni sekinlashtiradi. O'ng tugma / Esc - tugatish. (%d oltin/m)",
	"tower": "Minora: devor burchagi yoki o'rtasiga qo'ying. Minoradagi kamonchilar %d m gacha devorni himoya qiladi.",
	"gate": "Darvoza: mavjud devorni bosing. Darvoza - eng zaif joy, lekin askarlar shu yerdan chiqadi.",
	"delete": "Buzish: obyektni bosing (narxining yarmi qaytadi)."}
const FOOT := {"barracks": Vector2(17, 9), "granary": Vector2(11, 9), "well": Vector2(4, 3), "smithy": Vector2(9, 7),
	"stable": Vector2(15, 8), "keep": Vector2(24, 24), "farm": Vector2(22, 15), "lumber": Vector2(12, 10),
	"quarry": Vector2(14, 12), "market": Vector2(16, 12), "mint": Vector2(11, 11),
	"mosque": Vector2(17, 15), "house": Vector2(7, 8)}
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
	_rebuild()
	Game.changed.connect(_show_army)
	_show_army()


func _p() -> Dictionary:
	return Game.provinces[prov_id]


func _scene(n: String) -> PackedScene:
	if not _scenes.has(n):
		# musulmon davlatlarda O'rta Osiyo uslubidagi gumbazli binolar (models/castle_isl)
		var isl := "res://models/castle_isl/%s.glb" % n
		if (Unit3D.is_muslim(_p()["country"]) or not ResourceLoader.exists("res://models/castle/%s.glb" % n)) and ResourceLoader.exists(isl):
			_scenes[n] = load(isl)
		else:
			_scenes[n] = load("res://models/castle/%s.glb" % n)
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


func _apply_cam() -> void:
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

func _torch(p: Vector3, col := Color(1.0, 0.62, 0.3), rng := 16.0) -> void:
	var l := OmniLight3D.new()
	l.position = p
	l.light_color = col
	l.omni_range = rng
	l.light_energy = 0.0
	l.shadow_enabled = false
	build_root.add_child(l)
	daynight.torches.append(l)


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
			_torch(_v(b["p"]) + Basis(Vector3.UP, r) * Vector3(0, 3, 6.5), Color(1.0, 0.8, 0.5), 18.0)

func _rebuild() -> void:
	for c in build_root.get_children():
		c.queue_free()
	guards.clear()
	var k := _inst("keep")
	k.position = _keep()
	build_root.add_child(k)
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
		build_root.add_child(o)
		# minora tepasida soqchi (1-zamonda kamonchi, 2-zamonda miltiqli sarboz): atrofni kuzatadi
		var u := Unit3D.soldier(Unit3D.faction_for(_p()["country"]), "sarboz" if Game.era == 2 else "kamonchi", Color(Game.countries[_p()["country"]]["color"]))
		if u:
			u.position = o.position + Vector3(0, 11.65, 0)
			var base := atan2(o.position.x - _keep().x, o.position.z - _keep().z) - PI / 2.0
			u.rotation.y = base
			build_root.add_child(u)
			_add_guard(u, base, "tower")
	# devor ustida qorovullar yuradi (devor yo'lagi bo'ylab u yoqdan bu yoqqa)
	var wi := 0
	for w in data["walls"]:
		var a := _v(w["a"])
		var b := _v(w["b"])
		if a.distance_to(b) < 14.0 or wi >= 8:
			continue
		var kind: String = "sarboz" if Game.era == 2 else ["nayzachi", "qilichboz"][wi % 2]
		var u2 := Unit3D.soldier(Unit3D.faction_for(_p()["country"]), kind, Color(Game.countries[_p()["country"]]["color"]))
		if u2:
			build_root.add_child(u2)
			var g0 := {"node": u2, "mode": "patrol", "a": a.lerp(b, 0.12), "b": a.lerp(b, 0.88), "t": randf(), "dir": 1.0, "wait": 0.0}
			guards.append(g0)
			Unit3D.play(u2, "Walk")
		wi += 1
	for g in data["gates"]:
		var o := _inst("gate")
		o.position = _v(g["p"])
		o.rotation.y = float(g["ang"])
		build_root.add_child(o)
		for s in [-1.0, 1.0]:
			var u := Unit3D.soldier(Unit3D.faction_for(_p()["country"]), "nayzachi", Color(Game.countries[_p()["country"]]["color"]))
			if u:
				var outer := Vector3(sin(float(g["ang"])), 0, cos(float(g["ang"])))
				var along := Vector3(cos(float(g["ang"])), 0, -sin(float(g["ang"])))
				u.position = o.position - outer * 3.5 + along * s * 2.2
				u.rotation.y = float(g["ang"]) - PI / 2.0
				build_root.add_child(u)
				_add_guard(u, u.rotation.y, "gate")
	for b in data["buildings"]:
		var o := _inst(b["t"])
		o.position = _v(b["p"])
		o.rotation.y = float(b["rot"])
		build_root.add_child(o)
	_rebuild_lights()
	_analyze()
	_make_slots()
	_refresh_army(true)
	# ko'r nuqtalar: minoradan uzoq devorlar ustida qizil belgi
	for seg in stats.get("blind_segs", []):
		var a: Vector3 = seg[0]
		var b: Vector3 = seg[1]
		var mi := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(maxf(0.5, a.distance_to(b)), 0.6, 3.4)
		mi.mesh = bx
		mi.material_override = _bad_mat
		mi.position = (a + b) * 0.5 + Vector3(0, WALL_H + 1.6, 0)
		mi.rotation.y = atan2(-(b - a).z, (b - a).x)
		build_root.add_child(mi)


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
			_rebuild()


func _delete_at(p: Vector3) -> void:
	var back := {}
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
			_tdist = clampf(_tdist / 1.15, 18.0, MAX_DIST)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if _tdist >= MAX_DIST * 0.98:
				# eng uzoqdan yana uzoqlashtirsa - xaritaga (globusga) silliq ko'tarilamiz
				_leaving = true
				exit_requested.emit()
				return
			_tdist = clampf(_tdist * 1.15, 18.0, MAX_DIST)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_mid = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			# o'ng tugma: sudrasa - kamerani aylantirish, bossa - bekor qilish
			if mb.pressed:
				_rmb = true
				_drag_moved = false
				_press_at = mb.position
			else:
				_rmb = false
				if not _drag_moved:
					_cancel()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			# chap tugma: sudrasa - xaritani surish, bossa - qurish/tanlash
			if mb.pressed:
				_lmb = true
				_drag_moved = false
				_press_at = mb.position
			else:
				_lmb = false
				if not _drag_moved:
					_click(_ground_at(mb.position))
	elif e is InputEventMouseMotion:
		var mm := e as InputEventMouseMotion
		if (_lmb or _rmb) and mm.position.distance_to(_press_at) > 6.0:
			_drag_moved = true
		if _mid or (_lmb and _drag_moved):
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
	if k == KEY_ESCAPE:
		if tool == "" and not has_start and not _leaving:
			_leaving = true
			exit_requested.emit()
		else:
			_cancel()
	elif k == KEY_R:
		rot += PI / 2.0
		_update_ghost()


func _process(delta: float) -> void:
	if cam == null:
		return
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_A): dir.x -= 1
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
	_army_t += delta
	if _army_t > 0.4:
		_army_t = 0.0
		_refresh_army()


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
	side.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	side.offset_left = -330
	side.offset_right = -8
	side.offset_top = 70
	side.offset_bottom = -178
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
	tb.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	tb.offset_left = 8
	tb.offset_right = -8
	tb.offset_top = -170
	tb.offset_bottom = -8
	tb.add_theme_stylebox_override("panel", UIKit.style(Color(0.05, 0.08, 0.12, 0.65), 12, Color(0.6, 0.8, 1.0, 0.22), 10))
	hud.add_child(tb)
	var tv := VBoxContainer.new()
	tb.add_child(tv)
	for rowdef in [["QAL'A", ROW1], ["XO'JALIK", ROW2]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		tv.add_child(row)
		var rl := UIKit.label(rowdef[0], 12, UIKit.DIM)
		rl.custom_minimum_size = Vector2(62, 0)
		row.add_child(rl)
		for t in rowdef[1]:
			if t == "mosque" and not Unit3D.is_muslim(_p()["country"]):
				continue
			var b := Button.new()
			var ct := "" if t == "delete" else CastleEco.cost_text(_cost(t))
			ct = ct.replace(" oltin", "o").replace(" tosh", "t").replace(" yog'och", "y")
			b.text = "%s\n%s%s" % [NAMES[t], ct, "/m" if t in ["wall", "moat"] else ""]
			if CastleEco.ECON.has(t):
				var pr: Dictionary = CastleEco.ECON[t]["prod"]
				b.tooltip_text = "Kuniga: +%d %s" % [pr.values()[0], CastleEco.RES_NAMES[pr.keys()[0]].to_lower()]
			b.toggle_mode = true
			b.focus_mode = Control.FOCUS_NONE
			b.add_theme_font_size_override("font_size", 12)
			b.custom_minimum_size = Vector2(94, 48)
			b.clip_text = true
			b.pressed.connect(_set_tool.bind(t))
			row.add_child(b)
			tool_btns[t] = b
	tip_label = UIKit.label("Asbobni tanlang. G'ildirak - yaqinlashtirish, WASD / o'rta tugma - surish, Q/E - aylantirish, R - binoni burish.", 13, UIKit.INFO)
	tv.add_child(tip_label)
	msg_label = UIKit.label("", 14, UIKit.GOOD)
	msg_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	msg_label.offset_top = 66
	msg_label.offset_left = -300
	msg_label.offset_right = 300
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(msg_label)


func _set_tool(t: String) -> void:
	if tool == t:
		t = ""
	tool = t
	has_start = false
	for k in tool_btns:
		(tool_btns[k] as Button).set_pressed_no_signal(k == tool)
	if t == "":
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
	if Game.changed.is_connected(_show_army):
		Game.changed.disconnect(_show_army)
	if hud:
		hud.queue_free()
	closed.emit()
	queue_free()


# ================================================================ qo'shin: yollash va hovlida saf

func _show_army() -> void:
	if army_box == null:
		return
	UIKit.clear(army_box)
	var p := _p()
	army_box.add_child(UIKit.label("QO'SHIN", 18, Color.WHITE))
	var g := CastleEco.gold(p)
	army_box.add_child(UIKit.label("Jami: %d askar (kuch %d).  Maosh: %d oltin/kun, oziq: %.0f/kun" % [CastleEco.army_total(p),
		int(CastleEco.army_power(p)), int(g["pay"]), _food_per_day()], 12, UIKit.INFO, true))
	for k in CastleEco.units():
		var u: Dictionary = CastleEco.units()[k]
		var row := UIKit.row(army_box, 4)
		var l := UIKit.label("%s: %d" % [u["name"], int(data["army"][k])], 14, Color.WHITE)
		l.custom_minimum_size = Vector2(110, 0)
		row.add_child(l)
		for n in [1, 5, 10]:
			var why := CastleEco.can_recruit(p, k, n)
			var b := UIKit.button(row, "+%d" % n, why, _recruit.bind(k, n))
			b.focus_mode = Control.FOCUS_NONE
		army_box.add_child(UIKit.label("   %d oltin + %d oziq, %d kun (%s)" % [CastleEco.unit_cost(p, k), u["food"], u["days"],
			CastleEco.NEED_NAMES.get(u["needs"], u["needs"])], 11, UIKit.DIM))
	# josuslar: dushman hujumini oldindan bilish, dushman qal'alari haqida ma'lumot
	var srow := UIKit.row(army_box, 4)
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
	army_box.add_child(UIKit.label("   %d oltin, maoshi %.1f oltin/kun. Dushman hujumini %s oldin bilasiz, qal'alarini ko'rasiz." % [SiegeCastle.SPY_COST, SiegeCastle.SPY_PAY,
		"bir necha kun" if Game.spies == 0 else "%d kun ko'proq" % (2 * Game.spies + 2)], 11, UIKit.DIM, true))
	if not data["queue"].is_empty():
		army_box.add_child(UIKit.label("Tayyorlanmoqda:", 13, UIKit.GOLD))
		for q in data["queue"]:
			army_box.add_child(UIKit.label("   %d %s - %d kun qoldi" % [q["count"], CastleEco.units()[q["kind"]]["name"].to_lower(), q["days_left"]], 12, UIKit.INFO))
	var prod := {}
	for b in data["buildings"]:
		if CastleEco.ECON.has(b["t"]):
			var pr: Dictionary = CastleEco.ECON[b["t"]]["prod"]
			for r in pr:
				prod[r] = int(prod.get(r, 0)) + int(pr[r])
	var parts: Array = []
	for r in prod:
		parts.append("+%d %s" % [prod[r], CastleEco.RES_NAMES[r].to_lower()])
	army_box.add_child(UIKit.label("Xo'jalik kuniga: " + (", ".join(parts) if parts.size() else "hali yo'q - pastdagi XO'JALIK qatoridan quring"), 12, UIKit.GOOD if parts.size() else UIKit.GOLD, true))


func _food_per_day() -> float:
	var e := 0.0
	for k in data["army"]:
		e += float(data["army"][k]) * CastleEco.EAT * (2.0 if k == "otliq" else 1.0)
	return e


func _recruit(kind: String, n: int) -> void:
	if CastleEco.recruit(_p(), kind, n):
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
	for k in (["nayzachi", "sarboz", "top", "otliq"] if Game.era == 2 else ["nayzachi", "qilichboz", "kamonchi", "otliq"]):
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
	for k in (["otliq", "top", "sarboz", "nayzachi"] if Game.era == 2 else ["otliq", "kamonchi", "qilichboz", "nayzachi"]):
		# har tur yangi qatordan boshlanadi - alohida bo'linmalar ko'rinadi
		if i % (ROW_W + 1) != 0:
			i += (ROW_W + 1) - i % (ROW_W + 1)
		for f in figs.get(k, []):
			var node: Node3D = f
			var target: Vector3 = slots[mini(i, slots.size() - 1)] if slots.size() > 0 else _keep() + fwd * 20.0
			i += 3 if k == "top" else (2 if k == "otliq" else 1)
			if _initial or not node.get_meta("new", false) and node.position.distance_to(target) < 0.3:
				node.position = target
				node.rotation.y = face
				Unit3D.play(node, "Idle")
				var rd := Unit3D.rider_of(node)
				if rd:
					Unit3D.play(rd, "Ride")
				continue
			# yangi askar: kazarma eshigidan saf joyigacha yurib boradi
			var d := target - node.position
			node.rotation.y = atan2(-d.z, d.x)
			var dur := maxf(0.6, d.length() / (6.0 if k == "otliq" else 3.6))
			Unit3D.play(node, "Run" if k != "otliq" else "Walk")
			var rd2 := Unit3D.rider_of(node)
			if rd2:
				Unit3D.play(rd2, "Ride")
			var tw := node.create_tween()
			tw.tween_property(node, "position", target, dur)
			tw.tween_callback(func():
				node.rotation.y = face
				node.set_meta("new", false)
				Unit3D.play(node, "Idle"))
	_initial = false
	if per > 1:
		_msg("Hovlida: 1 figura = %d askar" % per)
