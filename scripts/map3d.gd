extends Node3D
## 3D strategik xarita: relyefli yer (tog'lar, dasht, cho'l, qor), ustida viloyatlar xaritasi (shaffof rang + chegaralar),
## binolar, garnizonlar, chegara postlari, qo'shinlar, samolyot va raketalar - hammasi 3D modellar.
## Mantiq (viloyat chegaralari, bosish, tanlash) eski 2D xaritadan olinadi: u ko'rinmas SubViewport ichida
## chiziladi va tekstura sifatida yer yuzasiga "yopishtiriladi".

const K := 0.1                 # 2D xarita birligi -> 3D metr
const MIN_ZOOM := 0.12            # eng uzoq - kosmosdan Yer shari
const GLOBE_Z := 0.22             # bundan uzoqda - globus rejimi
const FLAT_Z := 0.34              # bundan yaqinda - xarita butunlay tekis
var world_flat: MeshInstance3D
const EARTH_KM := 6371.0
const MAX_ZOOM := 8.0
const GW := 220                # yer to'ri (gorizontal)
const OV_W := 4096             # viloyatlar teksturasi kengligi
const AREA_R := 230.0          # viloyat bazasi radiusi (metr, province3d bilan bir xil)

var map2d                      # map_view.gd (overlay rejimida)
var ovp: SubViewport
var army_layer: Node2D
var air_layer: Node2D
var bounds := Rect2()
var cam: Camera3D
var terrain: MeshInstance3D

var _gw := 0
var _gh := 0
var _heights := PackedFloat32Array()

# kamera
var target := Vector2(-450, 40)
var zoom := 0.75
var _tz := 0.75
var _ttarget := Vector2(-450, 40)
var _anchor := false
var _anchor_screen := Vector2.ZERO
var _anchor_world := Vector2.ZERO
var _vel := Vector2.ZERO
var _dragging := false
var _moved := false
var _press_pos := Vector2.ZERO
var _last_mouse := Vector2.ZERO

# 3D obyektlar
var sites_root: Node3D
var armies_root: Node3D
var air_root: Node3D
var fx_root: Node3D
var labels_country: Array = []
var labels_prov: Array = []
var _army_nodes := {}
var _pool := {}
var _cache := {}
var _sig := ""
var _mats := {}
var _env: Environment
signal dive_requested(pid: String)   # eng yaqin masofada o'z viloyati ustida yana yaqinlashtirildi - qal'aga tushish
var dive_max := MAX_ZOOM           # o'tish paytida kamera odatdagidan pastroq tushadi
var globe: Node3D           # aylanuvchi Yer shari (markazi)
var globe_r := 230.0
var globe_c := Vector3.ZERO
var globe_axis := Vector3.UP
var _spin := 0.0
var stars: MeshInstance3D
var clouds_mat: ShaderMaterial


func _ready() -> void:
	# 1) 2D xarita - ko'rinmas tekstura sifatida
	ovp = SubViewport.new()
	ovp.transparent_bg = true
	ovp.size = Vector2i(OV_W, OV_W)
	ovp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	ovp.disable_3d = true
	ovp.msaa_2d = Viewport.MSAA_2X
	add_child(ovp)
	map2d = preload("res://scripts/map_view.gd").new()
	map2d.overlay = true
	ovp.add_child(map2d)
	army_layer = map2d.army_layer
	air_layer = map2d.air_layer
	bounds = map2d._bounds.grow_individual(80, 80, 80, 80)
	var oh := int(OV_W * bounds.size.y / bounds.size.x)
	ovp.size = Vector2i(OV_W, oh)
	var oz: float = OV_W / bounds.size.x
	map2d.cam.position = bounds.get_center()
	map2d.cam.zoom = Vector2(oz, oz)
	map2d._on_zoom_changed()

	# 2) muhit, quyosh, kamera
	var we := FX.environment(false, Color("#55603a"), Color("#3a6aa3"))
	we.environment.fog_density = 0.00012
	_env = we.environment
	we.environment.tonemap_exposure = 0.9
	if we.environment.volumetric_fog_enabled:
		we.environment.volumetric_fog_density = 0.0008
	add_child(we)
	var sun := FX.sun(900.0)
	sun.rotation_degrees = Vector3(-42, -30, 0)
	add_child(sun)
	cam = Camera3D.new()
	cam.fov = 38.0
	cam.near = 0.5
	cam.far = 30000.0
	add_child(cam)
	cam.make_current()

	# 3) yer
	_build_terrain()
	sites_root = Node3D.new()
	add_child(sites_root)
	armies_root = Node3D.new()
	add_child(armies_root)
	air_root = Node3D.new()
	add_child(air_root)
	fx_root = Node3D.new()
	add_child(fx_root)
	_build_labels()

	Game.changed.connect(_on_changed)
	War.explosion.connect(_explosion)
	War.nuke_flash.connect(func(p): _explosion(p, true, 3.0))
	_on_changed()
	_focus_on(Vector2(-450, 40), 0.75, true)


# ================================================================ koordinatalar

func to3(p: Vector2, extra := 0.0) -> Vector3:
	return Vector3(p.x * K, height(p) + extra, p.y * K)


func height(p: Vector2) -> float:
	if _heights.is_empty():
		return 0.0
	var u := (p.x - bounds.position.x) / bounds.size.x * (_gw - 1)
	var v := (p.y - bounds.position.y) / bounds.size.y * (_gh - 1)
	if u < 0 or v < 0 or u > _gw - 1 or v > _gh - 1:
		return -0.5
	var x0 := int(u)
	var y0 := int(v)
	var x1 := mini(x0 + 1, _gw - 1)
	var y1 := mini(y0 + 1, _gh - 1)
	var fx := u - x0
	var fy := v - y0
	var a := lerpf(_heights[y0 * _gw + x0], _heights[y0 * _gw + x1], fx)
	var b := lerpf(_heights[y1 * _gw + x0], _heights[y1 * _gw + x1], fx)
	return lerpf(a, b, fy)


func ground_at(screen: Vector2) -> Vector2:
	## Ekran nuqtasi -> 2D xarita koordinatasi (relyef balandligini hisobga olib)
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	if d.y > -0.001:
		return Vector2(1e6, 1e6)
	var h := 0.0
	var hit := Vector3.ZERO
	for i in 4:
		var t := (h - o.y) / d.y
		hit = o + d * t
		h = height(Vector2(hit.x, hit.z) / K)
	return Vector2(hit.x, hit.z) / K


func province_at(world: Vector2) -> String:
	return map2d.province_at(world)


func screen_of(p: Vector2, extra := 0.0) -> Vector2:
	return cam.unproject_position(to3(p, extra))


# ================================================================ relyef

const MOUNT := Geo.MOUNT
const DESERT := Geo.DESERT
const LOWLAND := Geo.LOWLAND


func _build_terrain() -> void:
	_gw = GW
	_gh = int(GW * bounds.size.y / bounds.size.x)
	# viloyatlarga qarab tog' va cho'l koeffitsienti (qo'pol to'rda, keyin silliq)
	var cw := 60
	var ch := int(cw * bounds.size.y / bounds.size.x)
	var mgrid := PackedFloat32Array()
	var dgrid := PackedFloat32Array()
	mgrid.resize(cw * ch)
	dgrid.resize(cw * ch)
	var centers: Array = []
	for id in Game.province_order:
		var p: Dictionary = Game.provinces[id]
		var m: float = MOUNT.get(p["country"], 0.3)
		if p["name"] in LOWLAND:
			m *= 0.25
		centers.append([p["center"], m, float(DESERT.get(p["country"], 0.3))])
	for y in ch:
		for x in cw:
			var pt := bounds.position + Vector2((x + 0.5) / cw * bounds.size.x, (y + 0.5) / ch * bounds.size.y)
			var wsum := 0.0
			var ms := 0.0
			var ds := 0.0
			for c in centers:
				var dd: float = pt.distance_squared_to(c[0])
				var w := 1.0 / (dd + 400.0)
				w = w * w
				wsum += w
				ms += w * float(c[1])
				ds += w * float(c[2])
			mgrid[y * cw + x] = ms / wsum
			dgrid[y * cw + x] = ds / wsum
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.004
	noise.fractal_octaves = 5
	var ridge := FastNoiseLite.new()
	ridge.seed = 11
	ridge.frequency = 0.0032
	ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridge.fractal_octaves = 5
	_heights.resize(_gw * _gh)
	var mfac := PackedFloat32Array()
	var dfac := PackedFloat32Array()
	mfac.resize(_gw * _gh)
	dfac.resize(_gw * _gh)
	for y in _gh:
		for x in _gw:
			var u := float(x) / (_gw - 1)
			var v := float(y) / (_gh - 1)
			var pt := bounds.position + Vector2(u * bounds.size.x, v * bounds.size.y)
			var m := _bilinear(mgrid, cw, ch, u, v)
			var dz := _bilinear(dgrid, cw, ch, u, v)
			var h := (noise.get_noise_2dv(pt) * 0.5 + 0.5) * 1.2
			var r := ridge.get_noise_2dv(pt) * 0.5 + 0.5
			h += pow(m, 1.3) * (r * r * 7.5 + r * 2.5 + 1.2)
			# chetlarda pastga tushadi (dengiz/xira hudud)
			var edge := minf(minf(u, 1.0 - u), minf(v, 1.0 - v))
			h *= smoothstep(0.0, 0.04, edge)
			_heights[y * _gw + x] = h
			mfac[y * _gw + x] = m
			dfac[y * _gw + x] = dz
	# keskin qirralarni yumshatish (2 marta 3x3 o'rtacha)
	for it in 2:
		var hb := _heights.duplicate()
		for y in range(1, _gh - 1):
			for x in range(1, _gw - 1):
				var s := 0.0
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						s += hb[(y + dy) * _gw + x + dx]
				_heights[y * _gw + x] = s / 9.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in _gh:
		for x in _gw:
			var u := float(x) / (_gw - 1)
			var v := float(y) / (_gh - 1)
			var pt := bounds.position + Vector2(u * bounds.size.x, v * bounds.size.y)
			st.set_uv(Vector2(u, v))
			st.set_color(Color(mfac[y * _gw + x], dfac[y * _gw + x], 0, 1))
			st.add_vertex(Vector3(pt.x * K, _heights[y * _gw + x], pt.y * K))
	for y in _gh - 1:
		for x in _gw - 1:
			var i := y * _gw + x
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + _gw)
			st.add_index(i + 1)
			st.add_index(i + _gw + 1)
			st.add_index(i + _gw)
	st.generate_normals()
	terrain = MeshInstance3D.new()
	terrain.mesh = st.commit()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/terrain.gdshader")
	sm.set_shader_parameter("overlay", ovp.get_texture())
	sm.set_shader_parameter("antique", 1.0 if Game.era < 4 else 0.0)
	var dt := NoiseTexture2D.new()
	var dn := FastNoiseLite.new()
	dn.frequency = 0.05
	dt.noise = dn
	dt.seamless = true
	dt.width = 256
	dt.height = 256
	sm.set_shader_parameter("detail", dt)
	sm.set_shader_parameter("detail_n", FX.normal_tex())
	terrain.material_override = sm
	terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(terrain)
	_build_globe()


func _build_globe() -> void:
	## Haqiqiy o'lchamdagi Yer shari: xarita uning ustida urinma bo'lib yotadi (1 birlik = 27.7 km)
	globe_r = EARTH_KM / (Geo.KM_PER_UNIT / K)
	var p0 := bounds.get_center()
	var ll := Geo.lonlat(p0)
	var lat := deg_to_rad(ll.y)
	var lon := deg_to_rad(ll.x)
	var up0 := Vector3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon))
	var north0 := Vector3(-sin(lat) * sin(lon), cos(lat), -sin(lat) * cos(lon))
	var east0 := Vector3(cos(lon), 0.0, -sin(lon))
	var L := Basis(east0, up0, north0)
	var W := Basis(Vector3.RIGHT, Vector3.UP, Vector3.FORWARD)
	var B := W * L.transposed()
	globe_c = Vector3(p0.x * K, -globe_r - 0.8, p0.y * K)
	globe_axis = (B * Vector3.UP).normalized()
	globe = Node3D.new()
	globe.position = globe_c
	add_child(globe)
	var earth := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = globe_r
	sm.height = globe_r * 2.0
	sm.radial_segments = 160
	sm.rings = 80
	earth.mesh = sm
	earth.basis = B
	var em := ShaderMaterial.new()
	em.shader = load("res://shaders/globe.gdshader")
	em.set_shader_parameter("day_tex", load("res://pics/earth/earth_atmos_2048.jpg"))
	em.set_shader_parameter("spec_tex", load("res://pics/earth/earth_specular_2048.jpg"))
	em.set_shader_parameter("ov_tex", ovp.get_texture())
	em.set_shader_parameter("geo", Vector4(Geo.LON_A, Geo.LON_B, Geo.LAT_A, Geo.LAT_B))
	em.set_shader_parameter("ov_rect", Vector4(bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y))
	earth.material_override = em
	globe.add_child(earth)
	earth.visible = false        # globusni endi "morph" to'ri chizadi (pastda) - u tekis xaritaga silliq yoyiladi
	_build_morph(B)
	var cl := MeshInstance3D.new()
	var cs := SphereMesh.new()
	cs.radius = globe_r * 1.006
	cs.height = globe_r * 2.012
	cs.radial_segments = 96
	cs.rings = 48
	cl.mesh = cs
	cl.basis = B
	clouds_mat = ShaderMaterial.new()
	clouds_mat.shader = load("res://shaders/clouds.gdshader")
	clouds_mat.set_shader_parameter("cloud_tex", load("res://pics/earth/earth_clouds_1024.png"))
	cl.material_override = clouds_mat
	cl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cl.name = "Clouds"
	globe.add_child(cl)
	var at := MeshInstance3D.new()
	var asm := SphereMesh.new()
	asm.radius = globe_r * 1.06
	asm.height = globe_r * 2.12
	at.mesh = asm
	var am := ShaderMaterial.new()
	am.shader = load("res://shaders/atmosphere.gdshader")
	at.material_override = am
	at.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	at.name = "Atmosphere"
	globe.add_child(at)
	stars = MeshInstance3D.new()
	var ss := SphereMesh.new()
	ss.radius = 20000.0
	ss.height = 40000.0
	stars.mesh = ss
	var stm := ShaderMaterial.new()
	stm.shader = load("res://shaders/stars.gdshader")
	stars.material_override = stm
	stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stars.visible = false
	add_child(stars)
	_build_world_flat()


var morph: MeshInstance3D
var morph_mat: ShaderMaterial
var _terrain_fade_mat: ShaderMaterial
var _terrain_mat: ShaderMaterial


func _build_morph(B: Basis) -> void:
	## Yer shari va tekis dunyo xaritasi - bitta to'r (lon x lat). Har tugunda ikkala o'rin saqlanadi.
	const NX := 256
	const NY := 128
	var R := globe_r
	var ll0 := Geo.lonlat(bounds.get_center())
	var la0 := deg_to_rad(ll0.y)
	var lo0 := deg_to_rad(ll0.x)
	var up0 := Vector3(cos(la0) * sin(lo0), sin(la0), cos(la0) * cos(lo0))
	var verts := PackedVector3Array()
	var cust := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var nrm := PackedVector3Array()
	for j in NY + 1:
		var v := float(j) / NY
		var lat := deg_to_rad(90.0 - v * 180.0)
		for i in NX + 1:
			var u := float(i) / NX
			var lon := deg_to_rad(u * 360.0 - 180.0)
			var dir := Vector3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon))
			var sp: Vector3 = B * (dir * R)
			var x := (rad_to_deg(lon) - Geo.LON_B) / Geo.LON_A
			var y := (rad_to_deg(lat) - Geo.LAT_B) / Geo.LAT_A
			var fl := Vector3(x * K, -0.6, y * K) - globe_c
			verts.append(fl)
			var d := acos(clampf(dir.dot(up0), -1.0, 1.0)) / PI
			cust.append_array([sp.x, sp.y, sp.z, d])
			uvs.append(Vector2(u, v))
			nrm.append(Vector3.UP)
	var idx := PackedInt32Array()
	for j in NY:
		for i in NX:
			var a := j * (NX + 1) + i
			var b := a + 1
			var c := a + NX + 1
			var dd := c + 1
			idx.append_array([a, b, c, b, dd, c])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_CUSTOM0] = cust
	arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {},
		Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	am.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	morph = MeshInstance3D.new()
	morph.mesh = am
	morph_mat = ShaderMaterial.new()
	morph_mat.shader = load("res://shaders/globe_morph.gdshader")
	morph_mat.set_shader_parameter("antique", 1.0 if Game.era < 4 else 0.0)
	morph_mat.set_shader_parameter("day_tex", load("res://pics/earth/earth_atmos_2048.jpg"))
	morph_mat.set_shader_parameter("spec_tex", load("res://pics/earth/earth_specular_2048.jpg"))
	morph_mat.set_shader_parameter("ov_tex", ovp.get_texture())
	morph_mat.set_shader_parameter("geo", Vector4(Geo.LON_A, Geo.LON_B, Geo.LAT_A, Geo.LAT_B))
	morph_mat.set_shader_parameter("ov_rect", Vector4(bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y))
	morph.material_override = morph_mat
	morph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	globe.add_child(morph)


func _build_world_flat() -> void:
	## Butun dunyoning tekis xaritasi: globusdan yaqinlashganda Yer shari shu tekis xaritaga almashadi.
	## Geo proyeksiyasi chiziqli (lon ~ x, lat ~ y), shuning uchun teng burchakli Yer tasviri aniq mos tushadi.
	var x0 := (-180.0 - Geo.LON_B) / Geo.LON_A
	var x1 := (180.0 - Geo.LON_B) / Geo.LON_A
	var y0 := (90.0 - Geo.LAT_B) / Geo.LAT_A
	var y1 := (-90.0 - Geo.LAT_B) / Geo.LAT_A
	var pm := PlaneMesh.new()
	pm.size = Vector2((x1 - x0) * K, (y1 - y0) * K)
	pm.subdivide_width = 8
	pm.subdivide_depth = 8
	world_flat = MeshInstance3D.new()
	world_flat.mesh = pm
	world_flat.position = Vector3((x0 + x1) * 0.5 * K, -0.6, (y0 + y1) * 0.5 * K)
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://pics/earth/earth_atmos_2048.jpg")
	m.roughness = 1.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	world_flat.material_override = m
	world_flat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world_flat.visible = false
	add_child(world_flat)


func _bilinear(g: PackedFloat32Array, w: int, h: int, u: float, v: float) -> float:
	var x := clampf(u * w - 0.5, 0.0, w - 1.001)
	var y := clampf(v * h - 0.5, 0.0, h - 1.001)
	var x0 := int(x)
	var y0 := int(y)
	var fx := x - x0
	var fy := y - y0
	var a := lerpf(g[y0 * w + x0], g[y0 * w + x0 + 1], fx)
	var b := lerpf(g[(y0 + 1) * w + x0], g[(y0 + 1) * w + x0 + 1], fx)
	return lerpf(a, b, fy)


# ================================================================ yozuvlar

func _label(text: String, size: int, col: Color, pos: Vector3, pix := 0.04) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	if Game.era < 4 and ResourceLoader.exists("res://fonts/alegreya_bold.woff2"):
		l.font = load("res://fonts/alegreya_bold.woff2")      # tarixiy xarita yozuvi
	l.outline_size = int(size / 4.0)
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.modulate = col
	if Game.era < 4:
		# eski qo'lyozma xarita: to'q siyoh harflar, pergament rangli hoshiya
		l.modulate = Color(0.24, 0.13, 0.06) if col.v > 0.7 else col.darkened(0.3)
		l.outline_modulate = Color(0.93, 0.86, 0.68, 0.75)
	l.pixel_size = pix
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	l.position = pos
	return l


func _build_labels() -> void:
	var sums := {}
	for id in Game.province_order:
		var p: Dictionary = Game.provinces[id]
		if not sums.has(p["country"]):
			sums[p["country"]] = [Vector2.ZERO, 0]
		sums[p["country"]][0] += p["center"]
		sums[p["country"]][1] += 1
		var l := _label(p["name"], 48, Color(1, 1, 1, 0.95), to3(p["center"], 1.2), 0.012)
		# viloyat nomi ekranda doim o'qiladigan kattalikda (yaqinlashtirganda mayda bo'lib qolmaydi)
		l.fixed_size = true
		l.pixel_size = 0.00062
		l.font_size = 40
		l.outline_size = 12
		l.set_meta("prio", float(p["population"]))
		add_child(l)
		labels_prov.append(l)
		l.set_meta("id", id)
	for c in sums:
		var pos: Vector2 = sums[c][0] / sums[c][1]
		# kichik davlatlar nomi kichikroq yoziladi - Yevropadagi mayda davlatlar bir-birini yopmaydi
		var px := 0.022 + 0.008 * minf(float(sums[c][1]), 8.0)
		var l2 := _label(Game.countries[c]["name"].to_upper(), 96, Color(1, 1, 1, 0.9), to3(pos, 6.0), px)
		l2.set_meta("prio", float(sums[c][1]) * 1000.0)
		add_child(l2)
		labels_country.append(l2)


# ================================================================ modellar

func _model(name: String, size: float) -> Node3D:
	## size - eng katta o'lcham (3D birlik)
	var path := "res://models/" + name + ".glb"
	if not ResourceLoader.exists(path):
		return null
	if not _cache.has(path):
		var sc: PackedScene = load(path)
		var probe: Node3D = sc.instantiate()
		var box := _aabb(probe, Transform3D())
		probe.free()
		_cache[path] = [sc, box]
	var e: Array = _cache[path]
	var box2: AABB = e[1]
	var k: float = size / maxf(0.001, maxf(box2.size.x, maxf(box2.size.y, box2.size.z)))
	var holder := Node3D.new()
	var inst: Node3D = e[0].instantiate()
	inst.scale = Vector3(k, k, k)
	inst.position = Vector3(-(box2.position.x + box2.size.x / 2.0) * k, -box2.position.y * k, -(box2.position.z + box2.size.z / 2.0) * k)
	FX.pbr(inst)
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


func _team(root: Node, col: Color) -> void:
	var key := "team_" + col.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = 0.4
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 0.3
		_mats[key] = m
	for mi in FX._meshes(root, []):
		if String(mi.name).begins_with("TeamColor"):
			mi.material_override = _mats[key]
			continue
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var sm: Material = mi.mesh.surface_get_material(i)
			if sm and sm.resource_name == "TeamColor":
				mi.set_surface_override_material(i, _mats[key])


func _ring(col: Color, r: float) -> MeshInstance3D:
	var key := "ring_" + col.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 1.6
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mats[key] = m
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r * 0.86
	tm.outer_radius = r
	tm.rings = 24
	mi.mesh = tm
	mi.scale = Vector3(1, 0.15, 1)
	mi.material_override = _mats[key]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _prov_radius(id: String) -> float:
	return army_layer.prov_radius(id)


# ================================================================ binolar, garnizonlar, postlar

func _signature() -> String:
	var s := ""
	for id in Game.player_provinces():
		var p: Dictionary = Game.provinces[id]
		s += id + ":"
		for b in p["buildings"]:
			s += "%s%d," % [b["type"], 1 if b["days_left"] <= 0 else 0]
		for st in Game.site_list(p):
			var u := Game.site_units(p, st["key"])
			s += "%s=%d/%d," % [st["key"], roundi(u["soldier"] / 10.0), roundi(u["tank"])]
		s += "|"
	for pair in War.hostile_borders():
		s += "h" + pair[0] + pair[1]
	return s


func _on_changed() -> void:
	var s := _signature()
	if s == _sig:
		return
	_sig = s
	for c in sites_root.get_children():
		c.queue_free()
	var gold := Color("#e8b73a")
	for id in Game.player_provinces():
		var p: Dictionary = Game.provinces[id]
		var c: Vector2 = p["center"]
		var rad := _prov_radius(id)
		var sc := clampf(rad * K / AREA_R * 1.25, 0.003, 0.018)      # metr -> 3D (biroz kattalashtirilgan)
		var ctry: String = p["country"]
		var oldm := func(part: String) -> String: return Unit3D.castle_file(ctry, part).trim_prefix("res://models/").trim_suffix(".glb")
		# eski davrda: hokimiyat o'rnida - shu xalq uslubidagi ark (qal'a), uylar ham o'sha davrniki
		var hq := _model("buildings/hq", 46.0 * sc) if Game.era >= 4 else _model(oldm.call("keep"), 52.0 * sc)
		if hq:
			hq.position = to3(c)
			_team(hq, gold)
			sites_root.add_child(hq)
		# shahar: hokimiyat atrofida uylar va daraxtlar (kichik)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(id)
		var kinds: Array = ["houses/house0", "houses/house1", "houses/house2", "houses/house3", "houses/apt5", "houses/apt9"]
		if Game.era < 4:
			kinds = [oldm.call("house"), oldm.call("house"), oldm.call("house"), oldm.call("market"), oldm.call("smithy"), oldm.call("granary")]
		for k in 14:
			var hp: Vector2 = c + Vector2.from_angle(rng.randf() * TAU) * rad * rng.randf_range(0.12, 0.42)
			var clash := false
			for b in p["buildings"]:
				if b.has("pos") and (c + Vector2(b["pos"][0], b["pos"][1]) / AREA_R * rad).distance_to(hp) < rad * 0.13:
					clash = true
					break
			if clash:
				continue
			var kd: String = kinds[rng.randi() % kinds.size()]
			var hm := _model(kd, (24.0 if kd.contains("apt") else (14.0 if Game.era >= 4 else (10.0 if kd.ends_with("house") else 16.0))) * sc)
			if hm:
				hm.position = to3(hp)
				hm.rotation.y = snappedf(rng.randf() * TAU, PI / 2)
				sites_root.add_child(hm)
		# viloyat nomi garnizon yozuvi bilan ustma-ust tushmasin
		for l in labels_prov:
			if l.get_meta("id", "") == id:
				l.position = to3(c + Vector2(0, -rad * 0.45), 2.2)
		for b in p["buildings"]:
			if not b.has("pos"):
				continue
			var bp: Vector2 = c + Vector2(b["pos"][0], b["pos"][1]) / AREA_R * rad
			var size := float(Game.FOOT.get(b["type"], 22.0)) * 2.0 * sc
			var m := _model("buildings/" + b["type"], size)
			if m == null:
				continue
			m.position = to3(bp)
			m.rotation.y = atan2(-(bp.x - c.x), -(bp.y - c.y)) + PI
			_team(m, gold)
			if b["days_left"] > 0:
				m.scale = Vector3(1, 0.35, 1)
			sites_root.add_child(m)
			if b["days_left"] <= 0 and (b["type"] == "civil" or b["type"] == "military" or b["type"] == "mine"):
				var smk := FX.factory_smoke(size * 0.12)
				smk.position = to3(bp, size * 0.5)
				sites_root.add_child(smk)
		# garnizon nuqtalari
		for st in Game.site_list(p):
			var u := Game.site_units(p, st["key"])
			var mp: Vector2 = army_layer.site_map_pos(id, st["key"])
			if st["type"] == "post" and Game.era < 4:
				# eski davrda chegara posti o'rniga bizning bayrog'imiz hilpirab turadi (Kazaki uslubida)
				var sf := Unit3D.standard(gold, 4.6)
				sf.scale = Vector3.ONE * 0.75
				sf.position = to3(mp)
				sf.set_meta("player_flag", true)
				sites_root.add_child(sf)
			elif st["type"] == "post":
				var pm := _model("buildings/post", 1.6)
				if pm:
					pm.position = to3(mp)
					var dirp: Vector2 = (Game.provinces[st["to"]]["center"] - c).normalized()
					pm.rotation.y = atan2(dirp.x, dirp.y)
					_team(pm, gold)
					sites_root.add_child(pm)
				var rg := _ring(gold, 1.3)
				rg.position = to3(mp, 0.3)
				sites_root.add_child(rg)
			if u["soldier"] + u["tank"] < 1.0:
				continue
			var gp := mp + (Vector2(0, rad * 0.32) if st["type"] == "hq" else Vector2(0, 6))
			_garrison(gp, u, gold)
	# eski xaritada: davlatimiz poytaxtida yuklangan bayrog'imiz hilpirab turadi
	if Game.era < 4 and not Game.player_provinces().is_empty():
		var cap: String = Game.player_provinces()[0]
		for id2 in Game.player_provinces():
			if Game.provinces[id2]["population"] > Game.provinces[cap]["population"]:
				cap = id2
		var cc: Vector2 = Game.provinces[cap]["center"]
		var std := Unit3D.standard(gold, 4.6)
		var fsc := clampf(_prov_radius(cap) * K / AREA_R * 1.25, 0.003, 0.018) * 24.0
		std.scale = Vector3.ONE * fsc
		std.position = to3(cc + Vector2(_prov_radius(cap) * 0.22, -_prov_radius(cap) * 0.18))
		std.set_meta("player_flag", true)
		sites_root.add_child(std)
	for pair in (War.hostile_borders() if Game.era >= 4 else []):
		var ep: Vector2 = Game.border_point(pair[0], pair[1])
		var em := _model("buildings/post", 1.5)
		if em:
			em.position = to3(ep)
			_team(em, Color("#e04848"))
			sites_root.add_child(em)
		var rr := _ring(Color("#e04848"), 1.2)
		rr.position = to3(ep, 0.3)
		sites_root.add_child(rr)


func _garrison(at: Vector2, u: Dictionary, col: Color) -> void:
	var g := Node3D.new()
	g.position = to3(at)
	sites_root.add_child(g)
	var ns := clampi(ceili(u["soldier"] / 40.0), 0, 5)
	if Game.era < 4:
		var fb := Unit3D.flag_bearer(Unit3D.player_faction(), col, null, true)
		fb.scale = Vector3(0.33, 0.33, 0.33)
		fb.position = Vector3(0, 0, -0.2)
		fb.rotation.y = -PI / 2
		g.add_child(fb)
		for i in ns:
			var s2 := Unit3D.soldier(Unit3D.player_faction(), (["sarboz", "nayzachi", "sarboz"] if Game.era == 2 else ["nayzachi", "qilichboz", "kamonchi"])[i % 3], col)
			if s2:
				s2.scale = Vector3(0.33, 0.33, 0.33)
				s2.position = Vector3((i - ns / 2.0) * 0.38, 0, 0.5)
				s2.rotation.y = -PI / 2
				Unit3D.play(s2, "Idle")
				g.add_child(s2)
		ns = 0
	for i in ns:
		var s := _model("units/soldier_rig", 0.55)
		if s:
			s.position = Vector3((i - ns / 2.0) * 0.38, 0, 0.5)
			s.rotation.y = -PI / 2
			_team(s, col)
			_anim(s, "Idle")
			g.add_child(s)
	var nt := clampi(roundi(u["tank"]), 0, 2)
	for i in nt:
		var t := _model("units/tank", 1.1)
		if t:
			t.position = Vector3((i - (nt - 1) / 2.0) * 0.9, 0, -0.4)
			t.rotation.y = -PI / 2
			_team(t, col)
			g.add_child(t)
	var rg := _ring(col, 1.3)
	rg.position.y = 0.3
	g.add_child(rg)
	var txt := "%d" % roundi(u["soldier"])
	if u["tank"] >= 1.0:
		txt += "  |  %d tank" % roundi(u["tank"])
	g.add_child(_label(txt, 36, Color("#ffd166"), Vector3(0, 1.1, 0.6), 0.011))


func _anim(root: Node, name: String) -> void:
	var ap: AnimationPlayer = Unit3D.anim(root)
	if ap and ap.has_animation(name):
		if ap.current_animation == name:
			return
		ap.get_animation(name).loop_mode = Animation.LOOP_LINEAR
		ap.play(name, 0.2)
		ap.seek(randf(), true)


# ================================================================ qo'shinlar, samolyotlar, karvonlar

func _sync_armies() -> void:
	var f: float = army_layer._frac()
	var seen := {}
	for a in War.armies:
		var key: int = a["id"]
		seen[key] = true
		var col := Color("#e8b73a") if a["owner"] == Game.PLAYER else Color("#e04848")
		var ns := clampi(ceili(a["soldiers"] / 25.0), 0, 5) if a["soldiers"] >= 1.0 else 0
		var nt := clampi(roundi(a["tanks"]), 0, 3)
		var comp := "%d_%d_%s" % [ns, nt, a["owner"]]
		var e: Dictionary = _army_nodes.get(key, {})
		if e.is_empty() or e["comp"] != comp:
			if not e.is_empty():
				(e["node"] as Node3D).queue_free()
			e = _make_army(ns, nt, col, Unit3D.player_faction() if a["owner"] == Game.PLAYER else Unit3D.faction_for(a["owner"]), a["owner"] == Game.PLAYER)
			e["comp"] = comp
			_army_nodes[key] = e
		var pos: Vector2 = a["prev_pos"].lerp(a["pos"], f)
		var n: Node3D = e["node"]
		n.position = to3(pos)
		var dir := Vector2.RIGHT
		if not a["path"].is_empty():
			var nxt: Vector2 = Game.provinces[a["path"][0]]["center"]
			if nxt.distance_to(pos) > 0.5:
				dir = (nxt - pos).normalized()
		elif a["state"] == "fight":
			dir = (Game.provinces[a["at"]]["center"] - Game.provinces[a["base"]]["center"]).normalized()
		n.rotation.y = -atan2(dir.y, dir.x)
		var moving: bool = a["state"] == "move" and Game.speed > 0
		var st := "Run" if moving else ("Fire" if a["state"] == "fight" else "Idle")
		if Game.era < 4 and st == "Fire":
			st = "Attack"
		for s in e["soldiers"]:
			if Game.era < 4 and Unit3D.rider_of(s) != null:
				_anim(s, "Gallop" if moving else "Idle")
				_anim(Unit3D.rider_of(s), "Ride" if a["state"] != "fight" else "RideAttack")
			else:
				_anim(s, st)
		(e["label"] as Label3D).text = str(int(ceil(War.power(a))))
		(e["dust"] as GPUParticles3D).emitting = moving and nt > 0
		if a["state"] == "fight" and randf() < 0.04 and Game.era >= 4:
			_explosion(pos + Vector2(randf_range(-8, 8), randf_range(-8, 8)), false, 0.5)
		(e["pulse"] as Node3D).visible = a["state"] == "stage"
		if a["state"] == "stage":
			var k := 1.0 + 0.25 * sin(Time.get_ticks_msec() / 250.0)
			(e["pulse"] as Node3D).scale = Vector3(k, 0.15, k)
	for key in _army_nodes.keys():
		if not seen.has(key):
			(_army_nodes[key]["node"] as Node3D).queue_free()
			_army_nodes.erase(key)


func _make_army(ns: int, nt: int, col: Color, fc := "temur", own := false) -> Dictionary:
	var n := Node3D.new()
	armies_root.add_child(n)
	var soldiers: Array = []
	if Game.era < 4:
		# 1-zamon: oldinda bayroqdor, ortidan askarlar va otliq
		var k := 0.36
		var fb := Unit3D.flag_bearer(fc, col, null, own)
		fb.scale = Vector3(k, k, k)
		fb.position = Vector3(0.5, 0, 0)
		n.add_child(fb)
		if fb.has_meta("body"):
			soldiers.append(fb.get_meta("body"))
		var kinds: Array = ["sarboz", "nayzachi", "sarboz", "sarboz", "nayzachi"] if Game.era == 2 else ["nayzachi", "qilichboz", "kamonchi", "nayzachi", "qilichboz"]
		for i in maxi(ns, 1):
			var s := Unit3D.soldier(fc, kinds[i % kinds.size()], col)
			if s:
				s.scale = Vector3(k, k, k)
				s.position = Vector3(-0.1 - (i / 2) * 0.55, 0, (i % 2) * 0.5 - 0.25)
				n.add_child(s)
				soldiers.append(s)
		if ns >= 3:
			var c := Unit3D.cavalry(fc, "otliq", col)
			if c:
				c.scale = Vector3(k, k, k)
				c.position = Vector3(-0.4 - (ns / 2) * 0.55 - 0.5, 0, 0)
				n.add_child(c)
				soldiers.append(c)
	for i in nt:
		var t := _model("units/tank", 1.3)
		if t:
			t.position = Vector3(-i * 1.5, 0, (i % 2) * 0.6 - 0.3)
			_team(t, col)
			n.add_child(t)
	for i in ns:
		var s := _model("units/soldier_rig", 0.6)
		if s:
			s.position = Vector3(-nt * 1.5 - (i / 2) * 0.55, 0, (i % 2) * 0.5 - 0.25)
			_team(s, col)
			n.add_child(s)
			soldiers.append(s)
	var rg := _ring(col, 1.6)
	rg.position = Vector3(0, 0.3, 0)
	n.add_child(rg)
	var pulse := _ring(Color("#ff3030"), 2.6)
	pulse.visible = false
	n.add_child(pulse)
	var lab := _label("", 44, Color.WHITE, Vector3(0, 2.2, 0), 0.013)
	n.add_child(lab)
	var d := FX.dust(0.35)
	d.position = Vector3(-0.8, 0.2, 0)
	n.add_child(d)
	return {"node": n, "soldiers": soldiers, "label": lab, "dust": d, "pulse": pulse}


func _pooled(kind: String, idx: int, make: Callable) -> Node3D:
	if not _pool.has(kind):
		_pool[kind] = []
	var arr: Array = _pool[kind]
	while arr.size() <= idx:
		var m: Node3D = make.call()
		air_root.add_child(m)
		arr.append(m)
	var node: Node3D = arr[idx]
	node.visible = true
	return node


func _hide_rest(kind: String, used: int) -> void:
	if not _pool.has(kind):
		return
	var arr: Array = _pool[kind]
	for i in range(used, arr.size()):
		(arr[i] as Node3D).visible = false


func _sync_air() -> void:
	var nj := 0
	var nm := 0
	for fl in Tech.flights:
		var fp: Vector2 = Tech.flight_pos(fl)
		var from: Vector2 = fl["from"]
		var to: Vector2 = fl["to"]
		var dir: Vector2 = ((from - to) if fl.get("back", false) else (to - from)).normalized()
		var total := maxf(1.0, from.distance_to(to))
		var k := clampf(from.distance_to(fp) / total, 0.0, 1.0)
		if fl["kind"] == "plane":
			var j := _pooled("jet", nj, func(): return _model("units/jet", 2.4))
			nj += 1
			j.position = to3(fp, 7.0)
			j.rotation = Vector3(0, -atan2(dir.y, dir.x), 0)
		else:
			var m := _pooled("missile", nm, func(): return _model("units/missile", 1.8 if fl["kind"] != "nuke" else 2.6))
			nm += 1
			var alt := sin(k * PI) * total * K * 0.35 + 1.0
			j_set(m, to3(fp, alt), dir, cos(k * PI) * 0.9)
	_hide_rest("jet", nj)
	_hide_rest("missile", nm)
	var na := 0
	for f in air_layer.flights:
		var r: Array = air_layer.flight_pos(f)
		var pl := _pooled("airliner", na, func(): return _model("units/airliner", 2.6))
		na += 1
		var kk: float = r[2]
		var alt2 := 2.0 + minf(kk, 1.0 - kk) * 30.0
		j_set(pl, to3(r[0], minf(alt2, 9.0)), r[1], 0.0)
		var want := "m" if f["mine"] else "f"
		if pl.get_meta("c", "") != want:
			pl.set_meta("c", want)
			_team(pl, Color("#e8b73a") if f["mine"] else Color("#9fb3c8"))
	_hide_rest("airliner", na)
	var nc := 0
	for c in War.convoys:
		var tr := _pooled("truck", nc, func(): return _model("units/truck", 0.9))
		nc += 1
		var p2: Vector2 = c["prev_pos"].lerp(c["pos"], army_layer._frac())
		tr.position = to3(p2)
	_hide_rest("truck", nc)


func j_set(n: Node3D, pos: Vector3, dir: Vector2, pitch: float) -> void:
	n.position = pos
	n.rotation = Vector3(0, -atan2(dir.y, dir.x), pitch)


func _explosion(pos: Vector2, big: bool, scale := 1.0) -> void:
	var k := (2.0 if big else 1.0) * scale
	var n := Node3D.new()
	n.position = to3(pos, 0.3)
	fx_root.add_child(n)
	var fire := FX._particles(int(18 * k), 0.8, Color(1.0, 0.85, 0.4), Color(1.0, 0.3, 0.05), 1.2 * k,
		Vector2(1.5, 4.0) * k, Vector3(0, 1.0, 0), 80.0, Vector3.UP, 2.5)
	fire.one_shot = true
	fire.explosiveness = 0.9
	n.add_child(fire)
	var smoke := FX._particles(int(16 * k), 3.0, Color(0.3, 0.28, 0.26, 0.8), Color(0.25, 0.25, 0.25), 2.0 * k,
		Vector2(0.8, 2.0) * k, Vector3(0.3, 0.8, 0), 50.0, Vector3.UP, 3.0)
	smoke.one_shot = true
	smoke.explosiveness = 0.7
	n.add_child(smoke)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.light_energy = 5.0 * k
	light.omni_range = 6.0 * k
	light.position.y = 1.0
	n.add_child(light)
	light.create_tween().tween_property(light, "light_energy", 0.0, 0.5)
	get_tree().create_timer(3.5).timeout.connect(n.queue_free)


# ================================================================ kamera

func _focus_on(world_pos: Vector2, z: float, instant := false) -> void:
	_anchor = false
	_ttarget = world_pos
	_tz = clampf(z, MIN_ZOOM, maxf(MAX_ZOOM, dive_max))
	_vel = Vector2.ZERO
	if instant:
		target = world_pos
		zoom = _tz
		_apply_cam()


func _cam_dist() -> float:
	return 175.0 / zoom


func _apply_cam() -> void:
	var t := clampf(log(zoom / 0.3) / log(MAX_ZOOM / 0.3), 0.0, 1.0)
	var pitch := deg_to_rad(lerpf(64.0, 46.0, t))
	var d := _cam_dist()
	var g := to3(target)
	g.y = maxf(g.y, 0.0)
	# globus rejimiga silliq o'tish: kamera Yer markaziga qaray boshlaydi
	var gk := smoothstep(0.32, MIN_ZOOM, zoom)
	g = g.lerp(globe_c, gk)
	pitch = lerpf(pitch, deg_to_rad(78.0), gk)
	cam.position = g + Vector3(0, sin(pitch), cos(pitch)) * d
	cam.look_at(g, Vector3.UP)
	_globe_mode(gk)
	_cull_t = 0.0        # yozuvlar ko'rinishi _process da (ustma-ust tushganlari yashiriladi)
	sites_root.visible = zoom >= 0.55


func _globe_mode(gk: float) -> void:
	## gk: 0 - yer relyefi, 1 - kosmosdan globus
	# globusning o'zi siyosiy xarita bilan bo'yalgan; FLAT_Z dan yaqinda u tekis xaritaga almashadi
	# globus -> tekis xarita: Yer shari ko'z oldida yoyiladi (GLOBE_Z..FLAT_Z), keyin relyef silliq paydo bo'ladi
	var flat := smoothstep(GLOBE_Z, FLAT_Z, zoom)
	if morph_mat:
		morph_mat.set_shader_parameter("flatten", flat)
	var fade := smoothstep(FLAT_Z, FLAT_Z + 0.12, zoom)
	var bend := 0.0
	if _terrain_mat == null:
		_terrain_mat = terrain.material_override as ShaderMaterial
		_terrain_fade_mat = _terrain_mat.duplicate() as ShaderMaterial
		var sh := Shader.new()
		sh.code = _terrain_mat.shader.code.replace("render_mode cull_back;", "render_mode cull_back, depth_draw_always;").replace("ALBEDO = col;", "ALBEDO = col;\n\tALPHA = fade;")
		_terrain_fade_mat.shader = sh
	terrain.material_override = _terrain_mat if fade >= 0.999 else _terrain_fade_mat
	var tm := terrain.material_override as ShaderMaterial
	tm.set_shader_parameter("fade", fade)
	tm.set_shader_parameter("bend", bend)
	tm.set_shader_parameter("bend_center", Vector2(globe_c.x, globe_c.z))
	tm.set_shader_parameter("bend_radius", globe_r)
	terrain.visible = fade > 0.0
	# tekis xaritada Yer shari ko'rinmaydi - faqat tekis xarita va osmon qoladi
	if globe:
		globe.visible = true
		for nm in ["Clouds", "Atmosphere"]:
			var n := globe.get_node_or_null(nm)
			if n:
				n.visible = flat < 0.05
	if world_flat:
		world_flat.visible = false
	var space := flat < 0.35
	stars.visible = space
	if _env:
		_env.background_mode = Environment.BG_COLOR if space else Environment.BG_SKY
		_env.background_color = Color(0.0, 0.0, 0.01)
		_env.fog_enabled = not space
		_env.glow_intensity = 0.6 if space else 0.35
	armies_root.visible = bend < 0.15
	air_root.visible = bend < 0.15
	for l in labels_country:
		var base: Vector3 = l.get_meta("base", l.position)
		l.set_meta("base", base)
		var dxz := Vector2(base.x - globe_c.x, base.z - globe_c.z)
		l.position = base - Vector3(0, bend * dxz.length_squared() / (2.0 * globe_r), 0)


var _cull_t := 0.0


func _cull_labels(arr: Array) -> void:
	## bir-birining ustiga chiqqan yozuvlar: kattaroq davlat / viloyat nomi qoladi, kichigi yashiriladi
	var vis: Array = []
	for l in arr:
		if (l as Label3D).visible:
			vis.append(l)
	for l in vis:
		# o'yinchining viloyatlari nomi har doim ko'rinadi
		var lid: String = l.get_meta("id", "")
		var own: bool = lid != "" and Game.provinces.has(lid) and Game.provinces[lid]["owner"] == Game.PLAYER
		l.set_meta("prio2", float(l.get_meta("prio", 0.0)) + (1e12 if own else 0.0))
	vis.sort_custom(func(a, b): return float(a.get_meta("prio2", 0.0)) > float(b.get_meta("prio2", 0.0)))
	var taken: Array = []
	var right := cam.global_transform.basis.x
	for l in vis:
		var lb: Label3D = l
		var p: Vector3 = lb.global_position
		if cam.is_position_behind(p):
			continue
		var sp := cam.unproject_position(p)
		var hw: float
		var hh: float
		if lb.fixed_size:
			var vh := get_viewport().get_visible_rect().size.y
			hw = lb.text.length() * lb.font_size * 0.3 * lb.pixel_size * vh * 2.1 + 6.0
			hh = lb.font_size * lb.pixel_size * vh * 1.25
		else:
			var w3: float = lb.text.length() * lb.font_size * lb.pixel_size * 0.55
			hw = absf(cam.unproject_position(p + right * w3 * 0.5).x - sp.x)
			hw *= 1.15
			hh = hw / maxf(1.0, lb.text.length() * 0.55) * 1.5
		var r := Rect2(sp - Vector2(hw, hh * 0.5), Vector2(hw * 2.0, hh))
		var hit := false
		for t in taken:
			if (t as Rect2).intersects(r):
				hit = true
				break
		if hit:
			lb.visible = false
		else:
			taken.append(r)


func _process(delta: float) -> void:
	_cull_t -= delta
	if _cull_t <= 0.0 and cam:
		_cull_t = 0.2
		var show_prov := zoom >= 1.3
		for l in labels_prov:
			l.visible = show_prov
		for l in labels_country:
			l.visible = not show_prov and zoom >= FLAT_Z
		_cull_labels(labels_prov if show_prov else labels_country)
	# globus aylanishi (faqat kosmosdan qaralganda), yaqinlashganda o'z joyiga qaytadi
	if zoom < GLOBE_Z * 0.85:
		_spin += delta * 0.08
	else:
		_spin = lerp_angle(_spin, 0.0, minf(1.0, delta * 4.0))
	if globe:
		globe.basis = Basis(globe_axis, _spin)
		clouds_mat.set_shader_parameter("spin", Time.get_ticks_msec() / 1000.0 * 0.004)
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): dir.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): dir.y += 1
	if dir != Vector2.ZERO and not get_viewport().gui_get_focus_owner() is LineEdit:
		_ttarget += dir.normalized() * 700.0 * delta / zoom
		_anchor = false
	var k := 1.0 - exp(-10.0 * delta)
	if absf(zoom - _tz) > 0.0005:
		zoom = lerpf(zoom, _tz, k)
		if absf(zoom - _tz) < 0.0005:
			zoom = _tz
		if _anchor:
			_apply_cam()
			var now := ground_at(_anchor_screen)
			if now.x < 1e5:
				target += _anchor_world - now
			_ttarget = target
	else:
		_anchor = false
	if not _dragging and _vel.length() > 5.0:
		_ttarget += _vel * delta
		_vel *= exp(-4.5 * delta)
	_ttarget = _ttarget.clamp(bounds.position, bounds.end)
	if dive_max > MAX_ZOOM:
		_tz = minf(_tz, dive_max)
	if not _anchor:
		target = target.lerp(_ttarget, k)
	target = target.clamp(bounds.position, bounds.end)
	_apply_cam()
	_sync_armies()
	_sync_air()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var up := mb.button_index == MOUSE_BUTTON_WHEEL_UP
			if up and _tz >= MAX_ZOOM * 0.999 and dive_max <= MAX_ZOOM:
				var pid := province_at(ground_at(mb.position))
				if pid != "" and Game.provinces[pid]["owner"] == Game.PLAYER:
					dive_requested.emit(pid)
					return
			var f := 1.25 if mb.factor <= 1.0 else pow(1.25, mb.factor)
			_tz = clampf(_tz * (f if up else 1.0 / f), MIN_ZOOM, MAX_ZOOM)
			var gp := ground_at(mb.position)
			if gp.x < 1e5:
				_anchor = true
				_anchor_screen = mb.position
				_anchor_world = gp
			_vel = Vector2.ZERO
		elif mb.pressed and mb.double_click and mb.button_index == MOUSE_BUTTON_LEFT:
			var bid := province_at(ground_at(mb.position))
			if bid != "" and not War.armies_in(bid).is_empty():
				War.open_battle.emit(War.armies_in(bid)[0]["id"])
			elif bid != "" and Game.provinces[bid]["owner"] == Game.PLAYER:
				Game.open_province.emit(bid)
		elif mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_dragging = true
				_moved = false
				_press_pos = mb.position
				_last_mouse = mb.position
				_vel = Vector2.ZERO
			else:
				_dragging = false
				if not _moved and mb.button_index == MOUSE_BUTTON_LEFT:
					if War.target_from == "":
						var bd := border_at(mb.position)
						if not bd.is_empty():
							Game.open_border.emit(bd[0], bd[1])
							return
					var clicked := province_at(ground_at(mb.position))
					if War.target_from != "":
						War.choose_target(clicked)
					else:
						Game.select(clicked)
				elif not _moved and mb.button_index == MOUSE_BUTTON_RIGHT:
					War.cancel_target()
	elif e is InputEventMouseMotion:
		var mm := e as InputEventMouseMotion
		if _dragging:
			if mm.position.distance_to(_press_pos) > 6.0:
				_moved = true
			if _moved:
				var a := ground_at(_last_mouse)
				var b := ground_at(mm.position)
				if a.x < 1e5 and b.x < 1e5:
					target += a - b
					_ttarget = target
					_anchor = false
					_vel = _vel.lerp((a - b) * 60.0, 0.5)
			_last_mouse = mm.position
		else:
			map2d.set_hover(province_at(ground_at(mm.position)))
	elif e is InputEventMagnifyGesture:
		_tz = clampf(_tz * (e as InputEventMagnifyGesture).factor, MIN_ZOOM, MAX_ZOOM)
	elif e is InputEventPanGesture:
		_ttarget += (e as InputEventPanGesture).delta * 8.0 / zoom


func border_at(screen: Vector2) -> Array:
	for id in Game.player_provinces():
		for n in Game.provinces[id]["neighbors"]:
			if Game.provinces[n]["owner"] == Game.PLAYER:
				continue
			var bp: Vector2 = Game.border_point(id, n)
			if cam.is_position_behind(to3(bp)):
				continue
			if screen_of(bp, 0.5).distance_to(screen) < 18.0:
				return [id, n]
	return []
