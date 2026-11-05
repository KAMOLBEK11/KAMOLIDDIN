extends Node
## 3D taktik jang sahnasi (Generals uslubida).
## Simulyatsiya tekis maydonda (x, y) hisoblanadi, ko'rinish 3D dunyoda (x, 0, y).
## Sichqoncha: chap - tanlash (sudrab - guruh), o'ng - yurish / hujum, g'ildirak - yaqinlashtirish,
## o'rta tugma bilan sudrash - kamerani surish. Klaviatura: W A S D - surish, Q / E - aylantirish.

signal closed

const S := 0.12                          # 1 maydon birligi = 0.12 metr
const FIELD := Vector2(1280, 720)
const COL_P := Color("#e8b73a")
const COL_E := Color("#e04848")
const STATS := {
	"inf": {"hp": 10.0, "dmg": 0.35, "cd": 0.8, "range": 130.0, "speed": 38.0, "r": 15.0},
	"tank": {"hp": 80.0, "dmg": 7.0, "cd": 2.0, "range": 200.0, "speed": 52.0, "r": 22.0},
}
const SPLASH := 32.0
const FIG_OFFS := [Vector2(0, 0), Vector2(-9, -7), Vector2(9, -7), Vector2(-9, 8), Vector2(9, 8)]

var army_id := -1
var player_attacking := true
var prov_id := ""
var units: Array = []
var shots: Array = []
var flashes: Array = []          # ekrandagi belgilar (yurish/hujum nuqtasi)
var finished := false
var player_won := false
var time_scale := 1.0
var _sup := 1.0
var ground := Color("#4f6b3a")
var ground2 := Color("#64824a")
var desert := false

# kamera
var cam: Camera3D
var cam_target := Vector3.ZERO
var cam_dist := 85.0
var cam_yaw := 0.0
var _mid_drag := false

# tanlash
var drag_start := Vector2.ZERO
var drag_now := Vector2.ZERO
var dragging := false

# sahna tugunlari
var hud: Control
var vp: SubViewport
var world: Node3D
var overlay: Control
var info_label: Label
var result_panel: PanelContainer
var result_label: Label
var retreat_btn: Button
var _mats := {}
var _meshes := {}
var _anim_t := 0.0
var debris: Array = []           # uchib ketayotgan bo'laklar (minora, temir parchalari)
var deploying := true            # jangdan oldin joylashtirish bosqichi
var deploy_panel: PanelContainer
var zone_node: MeshInstance3D
const ZONE_X := 0.38             # o'z zonamiz: maydonning chap 38% qismi


# ================================================================ tayyorlash

func setup(aid: int) -> void:
	army_id = aid
	var a := War.get_army(aid)
	prov_id = a["at"]
	var p: Dictionary = Game.provinces[prov_id]
	player_attacking = a["owner"] == Game.PLAYER
	_sup = War.supply_factor(a) if player_attacking else 1.0
	match p["country"]:
		"TKM", "AFG":
			ground = Color("#8a6f45"); ground2 = Color("#a3875a"); desert = true
		"MNG", "KAZ":
			ground = Color("#5e6a34"); ground2 = Color("#76823f")
		_:
			ground = Color("#34502a"); ground2 = Color("#4a6a34")
	var left := Rect2(90, 120, FIELD.x * 0.22, FIELD.y - 240)
	var right := Rect2(FIELD.x * 0.71, 120, FIELD.x * 0.22, FIELD.y - 240)
	if player_attacking:
		_spawn_side(0, a["soldiers"], a["tanks"], 0.0, left, 1.0)
		var d: float = p["defense"]
		var et := floorf(d * 0.3 / War.TANK_POWER)
		_spawn_side(1, d - et * War.TANK_POWER, et, 0.0, right, 1.15)
	else:
		_spawn_side(0, p["units"]["soldier"], p["units"]["tank"], p["militia"], left, 1.15)
		_spawn_side(1, a["soldiers"], a["tanks"], 0.0, right, 1.0)
	_build_hud(p)
	_build_world()
	for u in units:
		_make_unit_node(u)
	_build_cover()
	_start_deploy()
	_update_camera()


func _spawn_side(side: int, soldiers: float, tanks: float, militia: float, area: Rect2, hp_mult: float) -> void:
	var list: Array = []
	if soldiers >= 0.5:
		var n := clampi(ceili(soldiers / 10.0), 1, 30)
		for i in n:
			list.append(["inf", soldiers / n, false])
	if militia >= 0.5:
		var m := clampi(ceili(militia / 5.0), 1, 6)
		for i in m:
			list.append(["inf", militia / m, true])
	if tanks >= 0.5:
		var t := clampi(roundi(tanks), 1, 12)
		for i in t:
			list.append(["tank", tanks / t, false])
	var cols := maxi(1, ceili(sqrt(list.size() / 2.0)))
	var rows := ceili(float(list.size()) / cols)
	for i in list.size():
		var cx := i % cols
		var cy := i / cols
		var fxp := (cx + 0.5) / cols
		if side == 1:
			fxp = 1.0 - fxp
		var pos := area.position + Vector2(area.size.x * fxp, area.size.y * (cy + 0.5) / rows)
		pos += Vector2(randf_range(-8, 8), randf_range(-8, 8))
		var type: String = list[i][0]
		var men: float = list[i][1]
		var hp: float = STATS[type]["hp"] * men * hp_mult
		units.append({"side": side, "type": type, "pos": pos, "men": men, "men0": men, "hp": hp, "maxhp": hp,
			"hp_per_man": STATS[type]["hp"] * hp_mult, "militia": list[i][2], "alive": true, "sel": false,
			"order": null, "target": null, "cd": randf() * 1.0,
			"face": Vector2.RIGHT if side == 0 else Vector2.LEFT,
			"turret": Vector2.RIGHT if side == 0 else Vector2.LEFT,
			"node": null, "dead_done": false})


func to3(p: Vector2, h := 0.0) -> Vector3:
	return Vector3((p.x - FIELD.x / 2.0) * S, h, (p.y - FIELD.y / 2.0) * S)


func to2(v: Vector3) -> Vector2:
	return Vector2(v.x / S + FIELD.x / 2.0, v.z / S + FIELD.y / 2.0)


func _yaw(dir: Vector2) -> float:
	## Modellar +X tomonga qaragan holda yasalgan
	return -atan2(dir.y, dir.x)


# ================================================================ materiallar va shakllar

func _mat(key: String, col: Color, emit := false, rough := 0.85) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	if emit:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 2.5
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats[key] = m
	return m


func _mesh(key: String) -> Mesh:
	if _meshes.has(key):
		return _meshes[key]
	var m: Mesh
	match key:
		"body":
			var c := CapsuleMesh.new(); c.radius = 0.24; c.height = 1.15; m = c
		"head":
			var s := SphereMesh.new(); s.radius = 0.17; s.height = 0.34; m = s
		"helmet":
			var s2 := SphereMesh.new(); s2.radius = 0.21; s2.height = 0.21; s2.is_hemisphere = true; m = s2
		"gun":
			var b := BoxMesh.new(); b.size = Vector3(0.75, 0.08, 0.08); m = b
		"hull":
			var b2 := BoxMesh.new(); b2.size = Vector3(4.2, 1.0, 2.5); m = b2
		"track":
			var b3 := BoxMesh.new(); b3.size = Vector3(4.5, 0.8, 0.6); m = b3
		"turret":
			var b4 := BoxMesh.new(); b4.size = Vector3(1.9, 0.75, 1.7); m = b4
		"stripe":
			var b5 := BoxMesh.new(); b5.size = Vector3(1.2, 0.08, 1.3); m = b5
		"barrel":
			var cy := CylinderMesh.new(); cy.top_radius = 0.12; cy.bottom_radius = 0.14; cy.height = 2.8; m = cy
		"ring":
			var t := TorusMesh.new(); t.inner_radius = 0.9; t.outer_radius = 1.05; m = t
		"trunk":
			var cy2 := CylinderMesh.new(); cy2.top_radius = 0.18; cy2.bottom_radius = 0.25; cy2.height = 1.6; m = cy2
		"crown":
			var cy3 := CylinderMesh.new(); cy3.top_radius = 0.0; cy3.bottom_radius = 1.6; cy3.height = 4.0; m = cy3
		"rock":
			var s3 := BoxMesh.new(); s3.size = Vector3(1.6, 1.0, 1.3); m = s3
		"bullet":
			var b6 := BoxMesh.new(); b6.size = Vector3(2.6, 0.06, 0.06); m = b6
		"shell":
			var s4 := SphereMesh.new(); s4.radius = 0.2; s4.height = 0.4; m = s4
		"flash":
			var s5 := SphereMesh.new(); s5.radius = 0.35; s5.height = 0.7; m = s5
		"decal":
			var cy4 := CylinderMesh.new(); cy4.top_radius = 1.2; cy4.bottom_radius = 1.2; cy4.height = 0.04; m = cy4
	_meshes[key] = m
	return m


func _mi(parent: Node3D, mesh_key: String, mat: Material, pos := Vector3.ZERO, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh(mesh_key)
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


# ================================================================ dunyo

func _build_world() -> void:
	world = Node3D.new()
	vp.add_child(world)

	world.add_child(FX.environment(desert, ground))
	world.add_child(FX.sun(300.0))

	cam = Camera3D.new()
	cam.fov = 50.0
	cam.far = 900.0
	world.add_child(cam)
	cam.make_current()

	# yer
	var gm := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(FIELD.x * S * 3.0, FIELD.y * S * 4.0)
	gm.mesh = plane
	gm.material_override = FX.ground_material(ground.darkened(0.12), ground2, hash(prov_id))
	gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(gm)

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(prov_id) + 7
	# atrofdagi tepaliklar
	for i in 18:
		var hill := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 1.0
		sp.height = 2.0
		hill.mesh = sp
		hill.material_override = _mat("hill", ground.darkened(0.2))
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(115.0, 170.0)
		hill.position = Vector3(cos(ang) * dist * 1.3, -2.0, sin(ang) * dist * 0.9)
		var sc := rng.randf_range(18, 40)
		hill.scale = Vector3(sc, rng.randf_range(6, 16), sc * rng.randf_range(0.7, 1.3))
		world.add_child(hill)
	# daraxtlar / toshlar (asosan o'rtadagi "neytral" hududda va chetlarda)
	var trunk := _mat("trunk", Color("#5a4630"))
	var crown := _mat("crown", Color("#2f5226") if not desert else Color("#6b7a3a"))
	var rock := _mat("rock", Color("#6e6352"))
	for i in 70:
		var fp := Vector2(rng.randf_range(-0.3, 1.3) * FIELD.x, rng.randf_range(-0.3, 1.3) * FIELD.y)
		var central := fp.x > FIELD.x * 0.36 and fp.x < FIELD.x * 0.64 and fp.y > 0 and fp.y < FIELD.y
		var outside := fp.x < 0 or fp.x > FIELD.x or fp.y < 0 or fp.y > FIELD.y
		if not central and not outside:
			continue
		var n := Node3D.new()
		n.position = to3(fp)
		n.rotation.y = rng.randf() * TAU
		var k := rng.randf_range(0.8, 1.5)
		n.scale = Vector3(k, k, k)
		world.add_child(n)
		var tree_set: Array = ["nature/dead_tree", "nature/bush_dry", "nature/bush_dry"] if desert else \
			["nature/oak1", "nature/oak2", "nature/pine1", "nature/pine2", "nature/bush1"]
		var pick: String = tree_set[rng.randi() % tree_set.size()]
		var tsize := 1.8 if pick.contains("bush") else (9.0 if pick.contains("pine") else (5.5 if pick.contains("dead") else 7.5))
		var tm: Node3D = null if rng.randf() < 0.2 else _model(pick, tsize)
		if tm:
			n.scale = Vector3.ONE * rng.randf_range(0.8, 1.25)
			n.add_child(tm)
		elif desert or rng.randf() < 0.5:
			var r := _mi(n, "rock", rock, Vector3(0, 0.3, 0))
			r.scale = Vector3(rng.randf_range(0.8, 1.6), rng.randf_range(0.5, 1.0), rng.randf_range(0.8, 1.6))
			r.rotation = Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4))
		else:
			_mi(n, "trunk", trunk, Vector3(0, 0.8, 0))
			_mi(n, "crown", crown, Vector3(0, 3.3, 0))
	# shtablar
	_hq(Vector2(40, FIELD.y / 2.0), 0)
	_hq(Vector2(FIELD.x - 40, FIELD.y / 2.0), 1)
	# shtab yonida turgan texnika (Blender modellari)
	for side in [0, 1]:
		var acc := _mat("acc%d" % side, COL_P if side == 0 else COL_E)
		var x0 := 40.0 if side == 0 else FIELD.x - 40.0
		var dir := 1.0 if side == 0 else -1.0
		var parked := [["units/missile_truck", 7.5, Vector2(x0 + dir * 10, FIELD.y / 2.0 - 120)],
			["units/aa", 7.0, Vector2(x0 + dir * 15, FIELD.y / 2.0 + 120)],
			["units/apc", 7.2, Vector2(x0 + dir * 5, FIELD.y / 2.0 + 230)]]
		for pk in parked:
			var m := _model(pk[0], pk[1])
			if m == null:
				continue
			m.position = to3(pk[2])
			m.rotation.y = 0.0 if side == 0 else PI
			_team_paint(m, acc)
			world.add_child(m)


func _hq(fp: Vector2, side: int) -> void:
	var col := COL_P if side == 0 else COL_E
	var n := Node3D.new()
	n.position = to3(fp)
	n.rotation.y = 0.0 if side == 0 else PI
	world.add_child(n)
	var tent := _model("survival/Tent", 8.0)
	if tent:
		tent.rotation.y = PI / 2.0
		n.add_child(tent)
	else:
		var tm := MeshInstance3D.new()
		var pr := PrismMesh.new()
		pr.size = Vector3(5.0, 3.2, 6.0)
		tm.mesh = pr
		tm.material_override = _mat("tent", Color("#6b6a4a"))
		tm.position = Vector3(0, 1.6, 0)
		n.add_child(tm)
	# shtab atrofidagi buyumlar (Quaternius Survival Pack)
	var props := [["survival/Bonfire_Fire", 1.6, Vector3(5.5, 0, 1.5)], ["survival/GasCan", 0.9, Vector3(-3.2, 0, 3.6)],
		["survival/GasCan", 0.9, Vector3(-2.5, 0, 4.0)], ["survival/WoodLog", 2.2, Vector3(6.5, 0, -2.5)],
		["survival/PropaneTank", 1.1, Vector3(-3.8, 0, -3.2)], ["survival/Radio", 0.7, Vector3(4.0, 0, -1.4)],
		["survival/Backpack", 0.8, Vector3(-2.0, 0, -3.8)], ["survival/Shovel", 1.3, Vector3(-4.2, 0, 1.0)]]
	for pr2 in props:
		var m := _model(pr2[0], pr2[1])
		if m:
			m.position = pr2[2]
			m.rotation.y = randf() * TAU
			n.add_child(m)
			if String(pr2[0]).begins_with("survival/Bonfire"):
				var fire := _particles(12, 0.9, Color(1.0, 0.75, 0.3), Color(1.0, 0.3, 0.05), 0.7, 1.5, 2.5, 15.0)
				fire.one_shot = false
				fire.explosiveness = 0.0
				fire.position = Vector3(0, 0.4, 0)
				m.add_child(fire)
				var fl := OmniLight3D.new()
				fl.light_color = Color(1.0, 0.6, 0.25)
				fl.light_energy = 1.5
				fl.omni_range = 6.0
				fl.position = Vector3(0, 1.0, 0)
				m.add_child(fl)
	var pole := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.08; cy.bottom_radius = 0.08; cy.height = 7.0
	pole.mesh = cy
	pole.material_override = _mat("pole", Color("#2a2a2a"))
	pole.position = Vector3(2.0, 3.5, 3.6)
	n.add_child(pole)
	var flag := MeshInstance3D.new()
	var fb := BoxMesh.new()
	fb.size = Vector3(2.2, 1.3, 0.06)
	flag.mesh = fb
	flag.material_override = _mat("flag%d" % side, col)
	flag.position = Vector3(3.15, 6.3, 3.6)
	n.add_child(flag)
	# general
	var gen := Node3D.new()
	gen.position = Vector3(3.2, 0, -1.0)
	gen.scale = Vector3(1.4, 1.4, 1.4)
	n.add_child(gen)
	_mi(gen, "body", _mat("genbody", Color("#3b4a2c")), Vector3(0, 0.75, 0))
	_mi(gen, "head", _mat("skin", Color("#d9b48c")), Vector3(0, 1.45, 0))
	_mi(gen, "helmet", _mat("acc%d" % side, col), Vector3(0, 1.52, 0))


var _model_cache := {}


func _model(name: String, max_size: float) -> Node3D:
	## models/ papkasidagi FBX/GLB modelni yuklab, kerakli o'lchamga keltiradi.
	## Model topilmasa null qaytaradi (unda oddiy shakl ishlatiladi).
	var path := ""
	for ext in [".glb", ".gltf", ".fbx"]:
		if ResourceLoader.exists("res://models/" + name + ext):
			path = "res://models/" + name + ext
			break
	if path == "":
		return null
	if not _model_cache.has(path):
		var sc: PackedScene = load(path)
		if sc == null:
			return null
		var probe: Node3D = sc.instantiate()
		var box := _aabb(probe, Transform3D())
		probe.free()
		_model_cache[path] = [sc, box]
	var entry: Array = _model_cache[path]
	var box2: AABB = entry[1]
	var k: float = max_size / maxf(0.001, maxf(box2.size.x, maxf(box2.size.y, box2.size.z)))
	var holder := Node3D.new()
	var inst: Node3D = entry[0].instantiate()
	FX.pbr(inst)
	inst.scale = Vector3(k, k, k)
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


func _meshes_of(root: Node, out: Array) -> Array:
	if root is MeshInstance3D:
		out.append(root)
	for c in root.get_children():
		_meshes_of(c, out)
	return out


func _team_paint(root: Node, m: Material) -> void:
	## "TeamColor" nomli qismlarni jamoa rangiga bo'yaydi (Blender modellarida)
	var t := _find(root, "TeamColor")
	if t:
		for mi in _meshes_of(t, []):
			mi.material_override = m
	# materiali "TeamColor" deb nomlangan sirtlar (skeletli askarda)
	for mi in _meshes_of(root, []):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var sm: Material = mi.mesh.surface_get_material(i)
			if sm and sm.resource_name == "TeamColor":
				mi.set_surface_override_material(i, m)


func _tint(root: Node, k: Color) -> void:
	## Dushman texnikasini biroz to'qroq qilish (TeamColor dan tashqari)
	for mi in _meshes_of(root, []):
		if mi.name == "TeamColor" or mi.material_override != null:
			continue
		var cnt: int = mi.mesh.get_surface_count()
		for i in cnt:
			var src: Material = mi.mesh.surface_get_material(i)
			if src is StandardMaterial3D:
				var key := "tint_%d_%s" % [src.get_instance_id(), k.to_html()]
				if not _mats.has(key):
					var m2: StandardMaterial3D = src.duplicate()
					m2.albedo_color = src.albedo_color * k
					_mats[key] = m2
				mi.set_surface_override_material(i, _mats[key])


func _paint_all(root: Node, m: Material) -> void:
	for mi in _meshes_of(root, []):
		mi.material_override = m


func _make_unit_node(u: Dictionary) -> void:
	var side: int = u["side"]
	var acc := _mat("acc%d" % side, COL_P if side == 0 else COL_E)
	var n := Node3D.new()
	world.add_child(n)
	u["node"] = n
	var ring := _mi(n, "ring", _mat("sel", Color(0.4, 1.0, 0.4), true), Vector3(0, 0.08, 0), false)
	ring.scale = Vector3(1.0, 0.3, 1.0) * (1.6 if u["type"] == "inf" else 2.8)
	ring.visible = false
	u["ring"] = ring
	var tank_model: Node3D = _model("units/tank", 6.2) if u["type"] == "tank" else null
	if tank_model:
		n.add_child(tank_model)
		_team_paint(tank_model, acc)
		if side == 1:
			_tint(tank_model, Color(0.82, 0.8, 0.78))
		var tn := _find(tank_model, "Turret")
		u["turret_node"] = tn if tn else Node3D.new()
		u["wreck_root"] = tank_model
		_setup_tank_anim(u, tank_model)
	elif u["type"] == "tank":
		var body := _mat("tbody%d" % side, Color("#5f6b3a") if side == 0 else Color("#545a48"))
		var dark := _mat("track", Color("#262622"))
		_mi(n, "hull", body, Vector3(0, 0.95, 0))
		_mi(n, "track", dark, Vector3(0, 0.45, 1.2))
		_mi(n, "track", dark, Vector3(0, 0.45, -1.2))
		var tur := Node3D.new()
		tur.position = Vector3(-0.2, 1.8, 0)
		n.add_child(tur)
		_mi(tur, "turret", _mat("tturret%d" % side, (Color("#5f6b3a") if side == 0 else Color("#545a48")).lightened(0.1)))
		_mi(tur, "stripe", acc, Vector3(0, 0.4, 0))
		var bar := _mi(tur, "barrel", _mat("barrel", Color("#2b2b28")), Vector3(2.2, 0.05, 0))
		bar.rotation.z = PI / 2.0
		u["turret_node"] = tur
	else:
		var uni := _mat("uni%d" % side, (Color("#4f5a34") if side == 0 else Color("#4d4a40")).darkened(0.3 if u["militia"] else 0.0))
		var skin := _mat("skin", Color("#d9b48c"))
		var gunm := _mat("gun", Color("#1e1e1e"))
		var figs: Array = []
		for o in FIG_OFFS:
			var sm := _model("units/soldier_rig", 2.3)
			if sm == null:
				sm = _model("units/soldier", 2.3)
			if sm:
				# askarlar har xil joyda va biroz boshqa yo'nalishda turadi
				sm.position = Vector3(o.x * S * 1.3 + randf_range(-0.4, 0.4), 0, o.y * S * 1.3 + randf_range(-0.4, 0.4))
				sm.rotation.y = randf_range(-0.25, 0.25)
				_setup_soldier_anim(sm)
				_team_paint(sm, acc)
				if u["militia"]:
					_tint(sm, Color(0.7, 0.7, 0.7))
				n.add_child(sm)
				figs.append(sm)
				continue
			var f := Node3D.new()
			f.position = Vector3(o.x * S * 1.3, 0, o.y * S * 1.3)
			f.scale = Vector3(1.5, 1.5, 1.5)
			n.add_child(f)
			_mi(f, "body", uni, Vector3(0, 0.6, 0))
			_mi(f, "head", skin, Vector3(0, 1.3, 0))
			_mi(f, "helmet", acc, Vector3(0, 1.37, 0))
			_mi(f, "gun", gunm, Vector3(0.3, 0.85, 0.18))
			figs.append(f)
		u["figs"] = figs
	_sync_unit(u)


# ================================================================ interfeys

func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func _build_hud(p: Dictionary) -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_parent().add_child(hud)

	var cont := SubViewportContainer.new()
	cont.set_anchors_preset(Control.PRESET_FULL_RECT)
	cont.stretch = true
	cont.mouse_filter = Control.MOUSE_FILTER_STOP
	cont.gui_input.connect(_field_input)
	hud.add_child(cont)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.handle_input_locally = false
	cont.add_child(vp)

	overlay = preload("res://scripts/battle_overlay.gd").new()
	overlay.b = self
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(overlay)

	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 8
	bar.offset_right = -8
	bar.offset_top = 8
	hud.add_child(bar)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	bar.add_child(h)
	var title := Label.new()
	title.text = "JANG: " + p["name"]
	title.add_theme_font_size_override("font_size", 18)
	h.add_child(title)
	info_label = Label.new()
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_label.clip_text = true
	h.add_child(info_label)
	h.add_child(_btn("Hammasini tanlash", _select_all))
	h.add_child(_btn("Hujum!", _all_attack))
	var sp := Button.new()
	sp.text = "1x"
	sp.focus_mode = Control.FOCUS_NONE
	sp.custom_minimum_size = Vector2(44, 0)
	sp.pressed.connect(func():
		time_scale = 2.0 if time_scale == 1.0 else 1.0
		sp.text = "%dx" % int(time_scale))
	h.add_child(sp)
	h.add_child(_btn("Avtomatik", _auto))
	retreat_btn = _btn("Chekinish", _retreat)
	retreat_btn.visible = player_attacking
	h.add_child(retreat_btn)

	var tip := Label.new()
	tip.text = "Chap: tanlash (sudrab - guruh)   O'ng: yurish / hujum   G'ildirak: yaqinlashtirish   W A S D: surish   Q / E: aylantirish"
	tip.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	tip.offset_left = 14
	tip.offset_top = -34
	tip.add_theme_font_size_override("font_size", 14)
	tip.add_theme_color_override("font_outline_color", Color.BLACK)
	tip.add_theme_constant_override("outline_size", 4)
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(tip)

	result_panel = PanelContainer.new()
	result_panel.set_anchors_preset(Control.PRESET_CENTER)
	result_panel.offset_left = -220
	result_panel.offset_right = 220
	result_panel.offset_top = -90
	result_panel.offset_bottom = 90
	result_panel.visible = false
	hud.add_child(result_panel)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	result_panel.add_child(v)
	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.add_theme_font_size_override("font_size", 22)
	v.add_child(result_label)
	v.add_child(_btn("Xaritaga qaytish", _close))


func _select_all() -> void:
	for u in units:
		u["sel"] = u["alive"] and u["side"] == 0


func _all_attack() -> void:
	for u in units:
		if u["alive"] and u["side"] == 0:
			u["order"] = null
			u["target"] = null
			u["hold"] = false
	if deploying:
		_begin_fight()


# ================================================================ kamera va sichqoncha

func _update_camera() -> void:
	var pitch := deg_to_rad(52.0)
	var off := Vector3(0, sin(pitch), cos(pitch)) * cam_dist
	off = Basis(Vector3.UP, cam_yaw) * off
	cam.position = cam_target + off
	cam.look_at(cam_target, Vector3.UP)


func ground_at(screen: Vector2) -> Vector2:
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	if absf(d.y) < 0.0001:
		return Vector2(-9999, -9999)
	var t := -o.y / d.y
	return to2(o + d * t)


func screen_of(fp: Vector2, h := 0.0) -> Vector2:
	return cam.unproject_position(to3(fp, h))


func _field_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = clampf(cam_dist / 1.15, 25.0, 170.0)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = clampf(cam_dist * 1.15, 25.0, 170.0)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_mid_drag = mb.pressed
		elif finished:
			return
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				dragging = true
				drag_start = mb.position
				drag_now = mb.position
			elif dragging:
				dragging = false
				_select(drag_start, mb.position, mb.shift_pressed)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_command(mb.position)
	elif e is InputEventMouseMotion:
		var mm := e as InputEventMouseMotion
		if dragging:
			drag_now = mm.position
		if _mid_drag:
			var k := cam_dist * 0.0022
			cam_target += Basis(Vector3.UP, cam_yaw) * Vector3(-mm.relative.x * k, 0, -mm.relative.y * k)
	elif e is InputEventMagnifyGesture:
		cam_dist = clampf(cam_dist / (e as InputEventMagnifyGesture).factor, 25.0, 170.0)
	elif e is InputEventPanGesture:
		var pg := e as InputEventPanGesture
		cam_target += Basis(Vector3.UP, cam_yaw) * Vector3(pg.delta.x, 0, pg.delta.y) * cam_dist * 0.01


func _select(a: Vector2, b: Vector2, add: bool) -> void:
	if not add:
		for u in units:
			u["sel"] = false
	if a.distance_to(b) < 6.0:
		var best := {}
		var bd := 28.0
		for u in units:
			if u["alive"] and u["side"] == 0:
				var d: float = screen_of(u["pos"], 1.0).distance_to(b)
				if d < bd:
					bd = d
					best = u
		if not best.is_empty():
			best["sel"] = true
		return
	var r := Rect2(a, Vector2.ZERO).expand(b)
	for u in units:
		if u["alive"] and u["side"] == 0 and r.has_point(screen_of(u["pos"], 1.0)):
			u["sel"] = true


func _enemy_at_screen(sp: Vector2) -> Dictionary:
	var best := {}
	var bd := 34.0
	for u in units:
		if u["alive"] and u["side"] == 1:
			var d: float = screen_of(u["pos"], 1.0).distance_to(sp)
			if d < bd:
				bd = d
				best = u
	return best


func _command(sp: Vector2) -> void:
	var sel: Array = units.filter(func(u): return u["alive"] and u["sel"])
	if sel.is_empty():
		return
	var enemy := _enemy_at_screen(sp)
	if not enemy.is_empty():
		for u in sel:
			u["target"] = enemy
			u["order"] = null
		flashes.append({"pos": enemy["pos"], "t": 0.5, "kind": "atk"})
		return
	var pos := ground_at(sp).clamp(Vector2(10, 10), FIELD - Vector2(10, 10))
	if deploying:
		pos.x = minf(pos.x, FIELD.x * ZONE_X - 20.0)
		var cols0 := ceili(sqrt(sel.size()))
		for i in sel.size():
			var off0 := Vector2((i % cols0) - (cols0 - 1) / 2.0, (i / cols0) - (cols0 - 1) / 2.0) * 42.0
			var np: Vector2 = (pos + off0).clamp(Vector2(15, 15), Vector2(FIELD.x * ZONE_X - 10.0, FIELD.y - 15))
			sel[i]["pos"] = np
			sel[i]["face"] = Vector2.RIGHT
			sel[i]["turret"] = Vector2.RIGHT
		flashes.append({"pos": pos, "t": 0.5, "kind": "move"})
		return
	var cols := ceili(sqrt(sel.size()))
	for i in sel.size():
		var off := Vector2((i % cols) - (cols - 1) / 2.0, (i / cols) - (cols - 1) / 2.0) * 40.0
		sel[i]["order"] = pos + off
		sel[i]["target"] = null
	flashes.append({"pos": pos, "t": 0.5, "kind": "move"})


# ================================================================ simulyatsiya

func _process(delta: float) -> void:
	_camera_keys(delta)
	_update_camera()
	if not finished and not deploying:
		_simulate(delta * time_scale)
	for f in flashes.duplicate():
		f["t"] -= delta
		if f["t"] <= 0.0:
			flashes.erase(f)
	_anim_t += delta
	for u in units:
		_sync_unit(u)
	_sync_shots()
	_update_debris(delta)


func _camera_keys(delta: float) -> void:
	var mv := Vector3.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): mv.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): mv.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): mv.z -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): mv.z += 1
	if mv != Vector3.ZERO:
		cam_target += Basis(Vector3.UP, cam_yaw) * mv.normalized() * cam_dist * 0.8 * delta
	if Input.is_key_pressed(KEY_Q): cam_yaw += 1.2 * delta
	if Input.is_key_pressed(KEY_E): cam_yaw -= 1.2 * delta
	var lim := Vector3(FIELD.x * S * 0.7, 0, FIELD.y * S * 0.7)
	cam_target = cam_target.clamp(-lim, lim)


func _simulate(dt: float) -> void:
	for u in units:
		if not u["alive"]:
			continue
		var st: Dictionary = STATS[u["type"]]
		u["cd"] -= dt
		var enemy: Dictionary = u["target"] if u["target"] != null and u["target"]["alive"] else _nearest_enemy(u)
		var dist := INF
		if not enemy.is_empty():
			dist = u["pos"].distance_to(enemy["pos"])
		var move_to = null
		if u["order"] != null:
			move_to = u["order"]
			if u["pos"].distance_to(u["order"]) < 4.0:
				u["order"] = null
				move_to = null
		elif not enemy.is_empty() and dist > st["range"] * 0.85 and not (u.get("hold", false) and dist > st["range"] * 1.6):
			move_to = enemy["pos"]
		if move_to != null:
			var dir: Vector2 = (move_to - u["pos"]).normalized()
			u["pos"] += dir * st["speed"] * dt
			u["face"] = u["face"].lerp(dir, minf(1.0, 6.0 * dt)).normalized()
		if not enemy.is_empty():
			var aim: Vector2 = (enemy["pos"] - u["pos"]).normalized()
			u["turret"] = u["turret"].lerp(aim, minf(1.0, 8.0 * dt)).normalized()
			if u["type"] == "inf" and move_to == null:
				u["face"] = u["face"].lerp(aim, minf(1.0, 6.0 * dt)).normalized()
			if dist <= st["range"] and u["cd"] <= 0.0:
				_fire(u, enemy)
				u["cd"] = st["cd"] * randf_range(0.85, 1.15)
		u["pos"] = u["pos"].clamp(Vector2(10, 10), FIELD - Vector2(10, 10))
	_separate()
	_update_shots(dt)
	_update_info()
	_check_end()


func _nearest_enemy(u: Dictionary) -> Dictionary:
	var best := {}
	var bd := INF
	for o in units:
		if o["alive"] and o["side"] != u["side"]:
			var d: float = u["pos"].distance_squared_to(o["pos"])
			if d < bd:
				bd = d
				best = o
	return best


func _separate() -> void:
	for i in units.size():
		var a: Dictionary = units[i]
		if not a["alive"]:
			continue
		for j in range(i + 1, units.size()):
			var b: Dictionary = units[j]
			if not b["alive"]:
				continue
			var min_d: float = STATS[a["type"]]["r"] + STATS[b["type"]]["r"]
			var d: Vector2 = b["pos"] - a["pos"]
			var l := d.length()
			if l < min_d and l > 0.01:
				var push := d / l * (min_d - l) * 0.5
				a["pos"] -= push
				b["pos"] += push


func _fire(u: Dictionary, enemy: Dictionary) -> void:
	var st: Dictionary = STATS[u["type"]]
	var dmg: float = st["dmg"] * u["men"] * (_sup if u["side"] == 0 and player_attacking else 1.0)
	if u["side"] == 0:
		dmg *= Tech.mult("tank" if u["type"] == "tank" else "soldier")
	var muzzle: Vector2 = u["pos"] + u["turret"] * (36.0 if u["type"] == "tank" else 10.0)
	if u["type"] == "tank" and u.has("anim"):
		_tank_fire_fx(u)
	elif u["type"] == "inf" and u.has("figs"):
		_inf_fire_fx(u)
	else:
		_muzzle_flash(to3(muzzle, 1.9 if u["type"] == "tank" else 1.3), u["type"] == "tank")
	if u["type"] == "tank":
		var dest: Vector2 = enemy["pos"] + Vector2(randf_range(-12, 12), randf_range(-12, 12))
		shots.append({"kind": "shell", "pos": muzzle, "start": muzzle, "dest": dest, "dmg": dmg,
			"side": u["side"], "speed": 420.0, "target": enemy, "node": null})
	else:
		if enemy["type"] == "tank":
			dmg *= 0.5
		shots.append({"kind": "bullet", "pos": muzzle, "start": muzzle, "dest": enemy["pos"], "dmg": dmg,
			"side": u["side"], "speed": 700.0, "target": enemy, "node": null})


func _update_shots(dt: float) -> void:
	for s in shots.duplicate():
		var t: Dictionary = s["target"]
		if s["kind"] == "bullet" and t["alive"]:
			s["dest"] = t["pos"]
		var step: float = s["speed"] * dt
		if s["pos"].distance_to(s["dest"]) <= step:
			shots.erase(s)
			if s["node"] != null:
				s["node"].queue_free()
			if s["kind"] == "bullet":
				if randf() < 0.35:
					_dirt(s["dest"] + Vector2(randf_range(-10, 10), randf_range(-10, 10)))
				if t["alive"]:
					_damage(t, s["dmg"])
			else:
				_boom(s["dest"], false)
				for o in units:
					if o["alive"] and o["side"] != s["side"]:
						if o["pos"].distance_to(s["dest"]) <= SPLASH:
							_damage(o, s["dmg"] * (1.0 if o == t else 0.5))
		else:
			s["pos"] = s["pos"].move_toward(s["dest"], step)


func _damage(u: Dictionary, d: float) -> void:
	u["hp"] -= d
	if u["type"] == "inf" and u.has("figs") and randf() < 0.35:
		var alive: Array = u["figs"].filter(func(f): return f.has_meta("ap") and not f.has_meta("fallen"))
		if not alive.is_empty():
			var f: Node3D = alive[randi() % alive.size()]
			f.set_meta("hit_t", 0.5)
			var ap: AnimationPlayer = f.get_meta("ap")
			ap.play("Hit")
	u["men"] = maxf(0.0, u["hp"] / u["hp_per_man"])
	if u["hp"] <= 0.0:
		u["alive"] = false
		u["sel"] = false
		u["men"] = 0.0
		_boom(u["pos"], u["type"] == "tank")


# ================================================================ 3D ko'rinishni yangilash

func _sync_unit(u: Dictionary) -> void:
	var n: Node3D = u["node"]
	if n == null:
		return
	n.position = to3(u["pos"])
	if not u["alive"]:
		if not u["dead_done"]:
			u["dead_done"] = true
			u["ring"].visible = false
			if u["type"] == "tank" and u.has("anim"):
				_tank_destroy(u)
			elif u["type"] == "tank" and u.has("wreck_root"):
				_paint_all(u["wreck_root"], _mat("wreck", Color("#1c1b19")))
				u["turret_node"].rotation.z = 0.2
				n.add_child(_smoke_column())
			elif u["type"] == "tank":
				var wreck := _mat("wreck", Color("#1c1b19"))
				for c in n.get_children():
					if c is MeshInstance3D:
						c.material_override = wreck
				for c in u["turret_node"].get_children():
					if c is MeshInstance3D:
						c.material_override = wreck
				u["turret_node"].rotation.z = 0.25
				n.add_child(_smoke_column())
			else:
				for f in u["figs"]:
					if f.visible and not f.has_meta("fallen"):
						_fall(f)
				_mi(n, "decal", _mat("decal", Color(0.18, 0.14, 0.1)), Vector3(0, 0.03, 0), false)
		return
	n.rotation.y = _yaw(u["face"])
	u["ring"].visible = u["sel"]
	if u["type"] == "tank":
		u["turret_node"].rotation.y = _yaw(u["turret"]) - n.rotation.y
		if not u.has("dust"):
			var d := FX.dust(0.9)
			d.position = Vector3(-3.0, 0.4, 0)
			n.add_child(d)
			u["dust"] = d
		var mv: float = u["pos"].distance_to(u.get("last_pos", u["pos"]))
		u["last_pos"] = u["pos"]
		(u["dust"] as GPUParticles3D).emitting = mv > 0.05 and not deploying
		if u.has("anim"):
			_tank_anim(u)
	else:
		var alive_figs := clampi(ceili(u["men"] / maxf(0.01, u["men0"]) * 5.0), 1, 5)
		var figs: Array = u["figs"]
		var moved: float = u["pos"].distance_to(u.get("last_pos", u["pos"]))
		u["last_pos"] = u["pos"]
		u["walk"] = lerpf(u.get("walk", 0.0), 1.0 if moved > 0.05 else 0.0, 0.15)
		for i in figs.size():
			var f: Node3D = figs[i]
			if f.has_meta("fallen"):
				continue
			if i >= alive_figs:
				_fall(f)
				continue
			if f.has_meta("ap"):
				_soldier_state(u, f, moved > 0.05)
				continue
			# yurganda chayqalish (eski model uchun)
			var ph := _anim_t * 11.0 + i * 1.7
			f.position.y = absf(sin(ph)) * 0.12 * u["walk"]
			f.rotation.x = sin(ph) * 0.08 * u["walk"]


func _sync_shots() -> void:
	for s in shots:
		if s["node"] == null:
			var mi := MeshInstance3D.new()
			if s["kind"] == "bullet":
				mi.mesh = _mesh("bullet")
				mi.material_override = _mat("tracer", Color(1.0, 0.85, 0.35), true)
			else:
				mi.mesh = _mesh("shell")
				mi.material_override = _mat("shellm", Color(1.0, 0.6, 0.2), true)
				var trail := _particles(24, 0.9, Color(0.8, 0.78, 0.74, 0.6), Color(0.7, 0.7, 0.7), 0.7, 0.3, 0.6, 180.0)
				trail.one_shot = false
				trail.explosiveness = 0.0
				trail.local_coords = false
				mi.add_child(trail)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			world.add_child(mi)
			s["node"] = mi
		var total: float = maxf(1.0, s["start"].distance_to(s["dest"]))
		var k: float = 1.0 - s["pos"].distance_to(s["dest"]) / total
		var h := 1.3
		if s["kind"] == "shell":
			h = 1.9 + sin(clampf(k, 0.0, 1.0) * PI) * total * S * 0.12
		var p3 := to3(s["pos"], h)
		s["node"].position = p3
		var dir3 := to3(s["dest"], 0.5) - p3
		if dir3.length() > 0.01:
			s["node"].rotation.y = -atan2(dir3.z, dir3.x)


func _muzzle_flash(p: Vector3, big: bool) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh("flash")
	mi.material_override = _mat("muzzle", Color(1.0, 0.8, 0.35), true)
	mi.position = p
	mi.scale = Vector3.ONE * (1.4 if big else 0.6)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	get_tree().create_timer(0.06).timeout.connect(mi.queue_free)


func _particles(amount: int, life: float, color_a: Color, color_b: Color, size: float, speed: float, up: float, spread: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.9
	p.emitting = true
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft_tex()
	q.material = m
	p.mesh = q
	p.direction = Vector3.UP
	p.spread = spread
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, up, 0)
	p.damping_min = 1.5
	p.damping_max = 3.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = size * 0.3
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.4))
	sc.add_point(Vector2(0.3, 1.0))
	sc.add_point(Vector2(1, 1.3))
	p.scale_amount_curve = sc
	var g := Gradient.new()
	g.set_color(0, color_a)
	g.set_color(1, Color(color_b.r, color_b.g, color_b.b, 0.0))
	p.color_ramp = g
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


var _soft: Texture2D


func _soft_tex() -> Texture2D:
	## Zarrachalar uchun yumshoq dumaloq tekstura
	if _soft == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.55, Color(1, 1, 1, 0.75))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_soft = t
	return _soft


func _boom(fp: Vector2, big: bool) -> void:
	_crater(fp, 1.4 if big else 0.9)
	var n := Node3D.new()
	n.position = to3(fp, 0.6)
	world.add_child(n)
	var k := 1.8 if big else 1.0
	n.add_child(_particles(int(18 * k), 0.7, Color(1.0, 0.9, 0.5), Color(1.0, 0.35, 0.05), 1.6 * k, 9.0 * k, 3.0, 70.0))
	n.add_child(_particles(int(14 * k), 2.2, Color(0.35, 0.33, 0.3, 0.85), Color(0.2, 0.2, 0.2), 2.4 * k, 4.0 * k, 1.5, 50.0))
	n.add_child(_particles(int(10 * k), 1.0, Color(0.35, 0.28, 0.2), Color(0.25, 0.2, 0.15), 0.4 * k, 12.0 * k, -18.0, 60.0))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.65, 0.3)
	light.light_energy = 6.0 * k
	light.omni_range = 9.0 * k
	light.position = Vector3(0, 1.5, 0)
	n.add_child(light)
	var tw := light.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.35)
	get_tree().create_timer(3.0).timeout.connect(n.queue_free)


func _smoke_column() -> CPUParticles3D:
	var p := _particles(10, 3.0, Color(0.2, 0.2, 0.2, 0.7), Color(0.3, 0.3, 0.3), 1.8, 1.5, 1.2, 15.0)
	p.one_shot = false
	p.explosiveness = 0.0
	p.position = Vector3(0, 1.5, 0)
	return p


# ================================================================ hisob va natija

func _totals(side: int) -> Dictionary:
	var out := {"soldiers": 0.0, "tanks": 0.0, "militia": 0.0, "units": 0}
	for u in units:
		if u["side"] != side or not u["alive"]:
			continue
		out["units"] += 1
		if u["type"] == "tank":
			out["tanks"] += u["men"]
		elif u["militia"]:
			out["militia"] += u["men"]
		else:
			out["soldiers"] += u["men"]
	return out


func _update_info() -> void:
	var a := _totals(0)
	var b := _totals(1)
	info_label.text = "  Siz: %d askar, %d tank%s  |  Dushman: %d askar, %d tank" % [
		roundi(a["soldiers"] + a["militia"]), roundi(a["tanks"]),
		("  (zaxira %d%%)" % roundi(_sup * 100)) if player_attacking and _sup < 1.0 else "",
		roundi(b["soldiers"]), roundi(b["tanks"])]


func _check_end() -> void:
	var a := _totals(0)
	var b := _totals(1)
	if a["units"] > 0 and b["units"] > 0:
		return
	finished = true
	player_won = b["units"] == 0
	_apply()
	# g'oliblar quvonadi
	var win_side := 0 if player_won else 1
	for u in units:
		if u["alive"] and u["side"] == win_side and u.has("figs"):
			for f in u["figs"]:
				if f.has_meta("ap") and not f.has_meta("fallen"):
					var ap: AnimationPlayer = f.get_meta("ap")
					ap.play("Cheer")
					ap.seek(randf() * 1.0, true)
	if player_won:
		result_label.text = "G'ALABA!\n" + ("%s bosib olindi." % Game.provinces[prov_id]["name"] if player_attacking else "Hujum qaytarildi.")
		result_label.add_theme_color_override("font_color", Color("#7bd88f"))
	else:
		result_label.text = "MAG'LUBIYAT\n" + ("Qo'shiningiz yo'q qilindi." if player_attacking else "%s qo'ldan ketdi." % Game.provinces[prov_id]["name"])
		result_label.add_theme_color_override("font_color", Color("#ff6b6b"))
	result_panel.visible = true


func _apply() -> void:
	## Jang natijasini xaritadagi qo'shin va provinsiyaga yozadi
	var a := War.get_army(army_id)
	if a.is_empty():
		return
	var p: Dictionary = Game.provinces[prov_id]
	var mine := _totals(0)
	var them := _totals(1)
	if player_attacking:
		a["soldiers"] = mine["soldiers"]
		a["tanks"] = mine["tanks"]
		p["defense"] = them["soldiers"] + them["tanks"] * War.TANK_POWER
		if p["defense"] < 0.5:
			War.capture_by_player(a, prov_id)
		elif War.power(a) < 0.5:
			War.armies.erase(a)
			Game.message.emit("Qo'shiningiz %s da tor-mor bo'ldi!" % p["name"], "bad")
	else:
		a["soldiers"] = them["soldiers"]
		a["tanks"] = them["tanks"]
		p["units"]["soldier"] = mine["soldiers"]
		p["units"]["tank"] = mine["tanks"]
		p["militia"] = mine["militia"]
		if War.power(a) < 0.5:
			War.armies.erase(a)
			Game.message.emit("%s himoyachilari dushman hujumini qaytardi!" % p["name"], "good")
		elif War.garrison_power(p) + p["militia"] < 0.5:
			War.bot_capture(a, prov_id)
	Game.changed.emit()


func _auto() -> void:
	if not finished:
		finished = true
		_apply()
	_close()


func _retreat() -> void:
	if not finished:
		finished = true
		_apply()
		if not War.get_army(army_id).is_empty():
			War.retreat(army_id)
	_close()


func _close() -> void:
	hud.queue_free()
	closed.emit()
	queue_free()


# ================================================================ animatsiyalar

func _setup_tank_anim(u: Dictionary, model: Node3D) -> void:
	var inst: Node3D = model.get_child(0)
	var k: float = inst.scale.x
	var wheels: Array = []
	for mi in _all_nodes(model, []):
		var nm := String(mi.name)
		if nm.begins_with("Wheel_") and "_r" in nm:
			var r := float(nm.rsplit("_r", true, 1)[1].replace("_", "."))
			wheels.append([mi, maxf(0.05, r)])
	var barrel := _find(model, "Barrel")
	var dust := _particles(14, 1.6, Color(0.55, 0.48, 0.36, 0.55), Color(0.5, 0.45, 0.35), 2.2, 2.0, 0.6, 30.0)
	dust.one_shot = false
	dust.explosiveness = 0.0
	dust.emitting = false
	dust.local_coords = false
	dust.position = Vector3(-2.6, 0.4, 0)
	model.add_child(dust)
	u["anim"] = {"k": k, "wheels": wheels, "trackA": _find(model, "TrackA"), "trackB": _find(model, "TrackB"),
		"barrel": barrel, "barrel_rest": barrel.position if barrel else Vector3.ZERO, "muzzle": _find(model, "Muzzle"),
		"model": model, "model_rest": model.position, "dust": dust, "phase": 0.0, "recoil": 0.0, "move": 0.0,
		"last": u["pos"]}


func _all_nodes(root: Node, out: Array) -> Array:
	if root is Node3D:
		out.append(root)
	for c in root.get_children():
		_all_nodes(c, out)
	return out


func _tank_anim(u: Dictionary) -> void:
	var a: Dictionary = u["anim"]
	var dt := get_process_delta_time()
	var dist_world: float = u["pos"].distance_to(a["last"]) * S
	a["last"] = u["pos"]
	var dist_model: float = dist_world / maxf(0.001, a["k"])
	a["move"] = lerpf(a["move"], clampf(dist_world / maxf(0.001, dt) / 5.0, 0.0, 1.0), 0.1)
	# g'ildiraklar tezlikka mos aylanadi
	for w in a["wheels"]:
		w[0].rotation.z -= dist_model / w[1]
	# gusenitsa: ikki faza navbat bilan - lenta harakatlanayotgandek
	a["phase"] += dist_model / 0.085
	var even := int(a["phase"]) % 2 == 0
	if a["trackA"]:
		a["trackA"].visible = even
	if a["trackB"]:
		a["trackB"].visible = not even or a["trackA"] == null
	# korpus tebranishi va otishdagi silkinish
	a["recoil"] = maxf(0.0, a["recoil"] - dt * 2.8)
	var r: float = a["recoil"]
	var model: Node3D = a["model"]
	var bob: float = sin(_anim_t * 9.0) * 0.02 * a["move"]
	model.position = a["model_rest"] + Vector3(-r * r * 0.25, bob, 0)
	model.rotation.z = r * r * 0.07 + sin(_anim_t * 4.5) * 0.008 * a["move"]
	model.rotation.x = sin(_anim_t * 3.1) * 0.006 * a["move"]
	if a["barrel"]:
		# stvol tez orqaga tepadi va sekin qaytadi
		var kick := clampf((r - 0.75) * 4.0, 0.0, 1.0) if r > 0.75 else r / 0.75 * 0.3
		a["barrel"].position = a["barrel_rest"] - Vector3(maxf(kick, r * 0.4) * 0.9, 0, 0)
	a["dust"].emitting = a["move"] > 0.25


func _tank_fire_fx(u: Dictionary) -> void:
	var a: Dictionary = u["anim"]
	a["recoil"] = 1.0
	var mz: Node3D = a["muzzle"]
	var p3: Vector3 = mz.global_position if mz else to3(u["pos"], 2.0)
	var fwd := Vector3(u["turret"].x, 0, u["turret"].y).normalized()
	var n := Node3D.new()
	n.position = p3
	world.add_child(n)
	# olov
	var fire := _particles(16, 0.25, Color(1.0, 0.95, 0.6), Color(1.0, 0.4, 0.05), 1.3, 14.0, 0.0, 12.0)
	fire.direction = fwd
	n.add_child(fire)
	# tutun halqasi
	var smoke := _particles(18, 1.8, Color(0.75, 0.72, 0.68, 0.7), Color(0.6, 0.6, 0.6), 1.8, 6.0, 0.8, 35.0)
	smoke.direction = fwd
	n.add_child(smoke)
	# yer changi (dulo ostida)
	var dust := _particles(14, 1.2, Color(0.6, 0.52, 0.4, 0.6), Color(0.5, 0.45, 0.35), 2.0, 5.0, 0.3, 80.0)
	dust.position = Vector3(0, -1.5, 0)
	n.add_child(dust)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.4)
	light.light_energy = 8.0
	light.omni_range = 12.0
	n.add_child(light)
	light.create_tween().tween_property(light, "light_energy", 0.0, 0.15)
	_muzzle_flash(p3, true)
	get_tree().create_timer(2.5).timeout.connect(n.queue_free)


func _inf_fire_fx(u: Dictionary) -> void:
	var figs: Array = u["figs"]
	u["fire_t"] = 1.2
	for f in figs:
		if f.visible and not f.has_meta("fallen") and randf() < 0.6:
			if f.has_meta("ap"):
				var ap: AnimationPlayer = f.get_meta("ap")
				var anim := "CrouchFire" if f.get_meta("crouch") else "Fire"
				ap.play(anim)
				ap.seek(0.0, true)
				if f.has_meta("rifle"):
					var rf: Node3D = f.get_meta("rifle")
					_muzzle_flash(rf.global_transform * Vector3(0.72, 0, 0), false)
					_casings(rf.global_transform * Vector3(0.1, 0, 0), rf.global_transform.basis.z.normalized())
					continue
			var fwd := Vector3(u["turret"].x, 0, u["turret"].y).normalized()
			_muzzle_flash(f.global_position + fwd * 1.3 + Vector3(0, 1.45, 0), false)


func _fall(f: Node3D) -> void:
	## Askar yiqiladi va maydonda qoladi
	f.set_meta("fallen", true)
	var gt := f.global_transform
	f.get_parent().remove_child(f)
	world.add_child(f)
	f.global_transform = gt
	if f.has_meta("ap"):
		var ap: AnimationPlayer = f.get_meta("ap")
		ap.play("Death1" if randf() < 0.5 else "Death2")
		ap.speed_scale = randf_range(0.9, 1.2)
		return
	var side := 1.0 if randf() < 0.5 else -1.0
	var tw := f.create_tween()
	tw.tween_property(f, "rotation:z", f.rotation.z + PI / 2.0 * 0.95, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(f, "rotation:y", f.rotation.y + side * randf_range(0.0, 0.6), 0.45)
	tw.parallel().tween_property(f, "position:y", 0.05, 0.45)
	_tint(f, Color(0.6, 0.6, 0.6))


func _tank_destroy(u: Dictionary) -> void:
	var a: Dictionary = u["anim"]
	var model: Node3D = a["model"]
	var wreck := _mat("wreck", Color("#1c1b19"))
	_paint_all(model, wreck)
	a["dust"].emitting = false
	var center: Vector3 = model.global_position + Vector3(0, 1.5, 0)
	# katta portlash
	var n := Node3D.new()
	n.position = center
	world.add_child(n)
	n.add_child(_particles(40, 0.9, Color(1.0, 0.9, 0.5), Color(1.0, 0.3, 0.05), 3.2, 16.0, 4.0, 80.0))
	n.add_child(_particles(30, 3.0, Color(0.25, 0.23, 0.2, 0.9), Color(0.15, 0.15, 0.15), 4.0, 6.0, 2.0, 60.0))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.light_energy = 14.0
	light.omni_range = 22.0
	n.add_child(light)
	light.create_tween().tween_property(light, "light_energy", 0.0, 0.6)
	get_tree().create_timer(4.0).timeout.connect(n.queue_free)
	# minora havoga uchadi
	var tn: Node3D = u["turret_node"]
	if tn and tn.is_inside_tree():
		var gt := tn.global_transform
		tn.get_parent().remove_child(tn)
		world.add_child(tn)
		tn.global_transform = gt
		var dir := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		debris.append({"node": tn, "vel": dir * randf_range(3.0, 6.0) + Vector3(0, randf_range(10.0, 14.0), 0),
			"ang": Vector3(randf_range(-3, 3), randf_range(-4, 4), randf_range(-3, 3)), "rest_y": 1.0})
	# temir parchalari
	for i in 10:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(randf_range(0.3, 0.9), randf_range(0.1, 0.3), randf_range(0.3, 0.7))
		mi.mesh = bm
		mi.material_override = wreck if i % 2 == 0 else _mat("tbody0", Color("#5f6b3a"))
		mi.position = center
		world.add_child(mi)
		var d2 := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		debris.append({"node": mi, "vel": d2 * randf_range(4.0, 11.0) + Vector3(0, randf_range(6.0, 12.0), 0),
			"ang": Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8)), "rest_y": 0.1})
	# yonayotgan korpus: olov + tutun ustuni
	var fire := _particles(18, 1.1, Color(1.0, 0.7, 0.2), Color(0.9, 0.2, 0.02), 1.6, 2.5, 3.5, 20.0)
	fire.one_shot = false
	fire.explosiveness = 0.0
	fire.position = Vector3(0, 1.4, 0)
	model.add_child(fire)
	var col := _smoke_column()
	col.amount = 18
	model.add_child(col)
	var fl := OmniLight3D.new()
	fl.light_color = Color(1.0, 0.55, 0.2)
	fl.light_energy = 2.5
	fl.omni_range = 8.0
	fl.position = Vector3(0, 2.0, 0)
	model.add_child(fl)
	# kuyik iz
	var sc := _mi(u["node"], "decal", _mat("scorch", Color(0.08, 0.07, 0.06)), Vector3(0, 0.03, 0), false)
	sc.scale = Vector3(2.0, 1.0, 2.0)
	# o'q-dorilar ketma-ket portlaydi
	for i in 3:
		var t := randf_range(0.5, 2.5)
		var off := Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
		get_tree().create_timer(t).timeout.connect(func():
			if is_instance_valid(model):
				_boom(to2(model.global_position + off), i == 2))


func _update_debris(dt: float) -> void:
	for d in debris.duplicate():
		var node: Node3D = d["node"]
		if not is_instance_valid(node):
			debris.erase(d)
			continue
		d["vel"].y -= 22.0 * dt
		node.position += d["vel"] * dt
		node.rotation += d["ang"] * dt
		if node.position.y <= d["rest_y"] and d["vel"].y < 0.0:
			node.position.y = d["rest_y"]
			d["vel"] *= Vector3(0.35, -0.25, 0.35)
			d["ang"] *= 0.4
			if d["rest_y"] > 0.5 and d["vel"].length() > 2.0:
				_boom(to2(node.position), false)
			if d["vel"].length() < 1.5:
				if d["rest_y"] > 0.5:
					node.rotation.x = clampf(node.rotation.x, -0.4, 0.4)
					node.rotation.z = clampf(node.rotation.z, -0.4, 0.4)
				debris.erase(d)


# ================================================================ skeletli askar animatsiyalari

const LOOP_ANIMS := ["Idle", "Walk", "Run", "Aim", "Fire", "CrouchFire", "Cheer"]


func _setup_soldier_anim(holder: Node3D) -> void:
	var ap: AnimationPlayer = holder.find_child("AnimationPlayer", true, false)
	if ap == null:
		return
	for nm in LOOP_ANIMS:
		if ap.has_animation(nm):
			ap.get_animation(nm).loop_mode = Animation.LOOP_LINEAR
	holder.set_meta("ap", ap)
	holder.set_meta("crouch", randf() < 0.4)
	var rifle := _find(holder, "Rifle")
	if rifle and rifle.get_child_count() > 0 and rifle.get_child(0) is Node3D:
		rifle = rifle.get_child(0)
	if rifle:
		holder.set_meta("rifle", rifle)
	ap.play("Idle")
	ap.seek(randf() * 1.5, true)


func _soldier_state(u: Dictionary, f: Node3D, moving: bool) -> void:
	var ap: AnimationPlayer = f.get_meta("ap")
	var dt := get_process_delta_time()
	if finished:
		return
	if f.has_meta("hit_t"):
		var ht: float = f.get_meta("hit_t") - dt
		if ht > 0.0:
			f.set_meta("hit_t", ht)
			return
		f.remove_meta("hit_t")
	u["fire_t"] = maxf(0.0, u.get("fire_t", 0.0) - dt * 0.2)
	var want := "Idle"
	if moving:
		want = "Run"
	elif u.get("fire_t", 0.0) > 0.0:
		want = "CrouchFire" if f.get_meta("crouch") else "Fire"
	elif u["target"] != null or not _nearest_enemy(u).is_empty():
		want = "CrouchFire" if f.get_meta("crouch") else "Aim"
	if ap.current_animation != want and not (want.ends_with("Fire") and ap.current_animation.ends_with("Fire")):
		ap.play(want, 0.2)
	ap.speed_scale = 1.0



# ================================================================ joylashtirish bosqichi va effektlar

func _start_deploy() -> void:
	deploying = true
	# o'z zonamiz - ko'k shaffof maydon
	zone_node = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(FIELD.x * ZONE_X * S, FIELD.y * S)
	zone_node.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.25, 0.55, 1.0, 0.16)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	zone_node.material_override = m
	zone_node.position = to3(Vector2(FIELD.x * ZONE_X / 2.0, FIELD.y / 2.0), 0.08)
	world.add_child(zone_node)
	var edge := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.4, 0.1, FIELD.y * S)
	edge.mesh = bm
	edge.material_override = _mat("zone_edge", Color(0.4, 0.75, 1.0), true)
	edge.position = to3(Vector2(FIELD.x * ZONE_X, FIELD.y / 2.0), 0.1)
	zone_node.add_child(edge)
	edge.position = Vector3(FIELD.x * ZONE_X * S / 2.0, 0.02, 0)
	# panel
	deploy_panel = PanelContainer.new()
	deploy_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	deploy_panel.offset_left = -360
	deploy_panel.offset_right = 360
	deploy_panel.offset_top = 64
	deploy_panel.add_theme_stylebox_override("panel", UIKit.style(Color(0.05, 0.08, 0.12, 0.55), 16, Color(0.45, 0.7, 1.0, 0.5), 12))
	hud.add_child(deploy_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	deploy_panel.add_child(v)
	var t := UIKit.label("JANGGA TAYYORGARLIK - QO'SHINNI JOYLASHTIRING", 18, Color.WHITE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var hint := UIKit.label("Askar/tanklarni tanlang (chap tugma, sudrash) va o'ng tugma bilan ko'k zonada joyini ko'rsating. Yoki tayyor saflardan birini tanlang. Dushman joylashuvi razvedka orqali ko'rinib turibdi.", 13, UIKit.DIM, true)
	v.add_child(hint)
	var h := UIKit.row(v, 6)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	for f in [["Hujum safi", "line"], ["Mudofaa", "defense"], ["Qanotlar", "flanks"], ["Tanklar oldinda", "wedge"]]:
		var b := UIKit.button(h, f[0], "", _formation.bind(f[1]))
		b.focus_mode = Control.FOCUS_NONE
	var go := UIKit.button(v, "  JANGNI BOSHLASH  ", "", _begin_fight, true)
	go.focus_mode = Control.FOCUS_NONE
	go.add_theme_font_size_override("font_size", 18)
	_formation("line")
	cam_target = to3(Vector2(FIELD.x * 0.42, FIELD.y / 2.0))
	cam_dist = 120.0


func _formation(kind: String) -> void:
	var mine: Array = units.filter(func(u): return u["alive"] and u["side"] == 0)
	var tanks: Array = mine.filter(func(u): return u["type"] == "tank")
	var inf: Array = mine.filter(func(u): return u["type"] == "inf")
	var zx := FIELD.x * ZONE_X
	var H := FIELD.y
	match kind:
		"line":
			_place_row(tanks, zx - 40.0, 0.15 * H, 0.85 * H)
			_place_row(inf, zx - 95.0, 0.1 * H, 0.9 * H)
		"wedge":
			for i in tanks.size():
				var k := float(i) / maxf(1.0, tanks.size() - 1) - 0.5
				tanks[i]["pos"] = Vector2(zx - 30.0 - absf(k) * 120.0, H / 2.0 + k * H * 0.55)
			_place_row(inf, zx - 160.0, 0.2 * H, 0.8 * H)
		"defense":
			_place_row(inf, zx * 0.45, 0.2 * H, 0.8 * H)
			_place_row(tanks, zx * 0.3, 0.3 * H, 0.7 * H)
		"flanks":
			var all: Array = tanks + inf
			for i in all.size():
				var top := i % 2 == 0
				var j := i / 2
				all[i]["pos"] = Vector2(zx - 40.0 - (j % 3) * 45.0, (0.18 if top else 0.82) * H + ((j / 3) * 40.0) * (1 if top else -1))
	for u in mine:
		u["hold"] = kind == "defense"
		u["face"] = Vector2.RIGHT
		u["turret"] = Vector2.RIGHT
		u["order"] = null


func _place_row(list: Array, x: float, y0: float, y1: float) -> void:
	var n := list.size()
	if n == 0:
		return
	var per := maxi(1, int((y1 - y0) / 40.0))
	for i in n:
		var row := i / per
		var col := i % per
		var cnt := mini(per, n - row * per)
		var y := lerpf(y0, y1, (col + 0.5) / cnt)
		list[i]["pos"] = Vector2(x - row * 45.0, y)


func _begin_fight() -> void:
	if not deploying:
		return
	deploying = false
	if deploy_panel:
		deploy_panel.queue_free()
	if zone_node:
		var tw := zone_node.create_tween()
		tw.tween_property(zone_node.material_override, "albedo_color:a", 0.0, 1.0)
		tw.tween_callback(zone_node.queue_free)
	flashes.append({"pos": Vector2(FIELD.x / 2.0, FIELD.y / 2.0), "t": 0.8, "kind": "atk"})


func _casings(p: Vector3, side: Vector3) -> void:
	## Avtomatdan uchib chiqqan gilzalar
	var c := _particles(3, 0.7, Color(0.85, 0.65, 0.25), Color(0.7, 0.5, 0.2), 0.09, 3.0, -14.0, 25.0)
	c.direction = (side + Vector3(0, 0.8, 0)).normalized()
	c.position = p
	c.damping_min = 0.0
	c.damping_max = 0.2
	var sc := Curve.new()
	sc.add_point(Vector2(0, 1))
	sc.add_point(Vector2(1, 1))
	c.scale_amount_curve = sc
	world.add_child(c)
	get_tree().create_timer(1.2).timeout.connect(c.queue_free)


func _dirt(fp: Vector2) -> void:
	var d := _particles(6, 0.6, Color(0.45, 0.38, 0.28, 0.8), Color(0.4, 0.35, 0.25), 0.35, 4.0, -10.0, 25.0)
	d.position = to3(fp, 0.1)
	world.add_child(d)
	get_tree().create_timer(1.0).timeout.connect(d.queue_free)


func _crater(fp: Vector2, k: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh("decal")
	var m := _mats.get("crater") as StandardMaterial3D
	if m == null:
		m = StandardMaterial3D.new()
		m.albedo_color = Color(0.12, 0.1, 0.08, 0.75)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = _soft_tex()
		_mats["crater"] = m
	mi.material_override = m
	mi.position = to3(fp, 0.02 + randf() * 0.01)
	mi.scale = Vector3(k, 1, k) * randf_range(0.9, 1.4)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)


func _build_cover() -> void:
	## Jang maydonidagi pana joylar: qum qoplari, tikanli sim, xandaqlar
	var bag := _mat("sandbag", Color("#7d6a48"))
	var bag2 := _mat("sandbag2", Color("#6c5b3e"))
	var wire := _mat("wire", Color("#4a4a48"))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(prov_id) + 99
	var spots: Array = []
	for side in [0, 1]:
		var x := FIELD.x * (0.22 if side == 0 else 0.78)
		for k in 4:
			spots.append([Vector2(x + rng.randf_range(-40, 40), FIELD.y * (0.15 + k * 0.23) + rng.randf_range(-20, 20)), side])
	for i in 5:
		spots.append([Vector2(FIELD.x * rng.randf_range(0.42, 0.58), FIELD.y * rng.randf_range(0.1, 0.9)), 2])
	for sp in spots:
		var n := Node3D.new()
		n.position = to3(sp[0])
		n.rotation.y = (0.0 if sp[1] != 1 else PI) + rng.randf_range(-0.3, 0.3)
		world.add_child(n)
		# yarim doira qum qoplari (g'isht kabi terilgan)
		var bm := BoxMesh.new()
		bm.size = Vector3(0.95, 0.38, 0.5)
		for layer in 3:
			var cnt := 11 - layer
			for j in cnt:
				var a := -1.0 + (j + 0.5 * (layer % 2)) * (2.0 / 11.0)
				var b := MeshInstance3D.new()
				b.mesh = bm
				b.material_override = bag if (j + layer) % 3 != 0 else bag2
				b.position = Vector3(cos(a) * 3.2, 0.19 + layer * 0.36, sin(a) * 3.2)
				b.rotation.y = -a + PI / 2 + rng.randf_range(-0.08, 0.08)
				n.add_child(b)
		if sp[1] == 2:
			# tikanli sim
			for j in 5:
				var w := MeshInstance3D.new()
				var tm := TorusMesh.new()
				tm.inner_radius = 0.42
				tm.outer_radius = 0.5
				w.mesh = tm
				w.material_override = wire
				w.rotation = Vector3(0, 0, PI / 2)
				w.position = Vector3(-6.0 - j * 0.9, 0.5, 0)
				n.add_child(w)
