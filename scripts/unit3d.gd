class_name Unit3D
## 1-zamon askarlari va otlar (Blender'da yasalgan GLB modellar) uchun yordamchi.
## Har askar modelida bir xil animatsiyalar bor:
##   Idle, Walk, Run, Attack, Block, Hit, Death1, Death2, Cheer, Ride, RideAttack
## Otda: Idle, Walk, Gallop, Rear, Death

const KINDS := ["qilichboz", "nayzachi", "kamonchi", "otliq"]
const RIDER_DROP := -0.03   # yangi otda chavandoz tos suyagi egar suyagidan qancha pastda
const SEAT_Y := 0.48        # egar balandligi (1.42) - chavandoz tosi balandligi (0.96)

static var _cache := {}


static func _scene(path: String) -> PackedScene:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


const GEMINI_SCALE := 0.86     # Gemini modellari ~2.1 m - bizning 1.8 m askarlarga moslash
## madaniyat -> askar modellari to'plami
const CULTURE_FACTION := {"xitoy": "xitoy", "rus": "rus", "fransuz": "yevropa", "turk": "temur", "arab": "arab", "italyan": "italiya", "yunon": "italiya"}
## G'arbiy va Markaziy Yevropa davlatlari (ma'lumotda "boshqa" madaniyatli) - Yevropa ritsarlari
const EUROPE := ["ENG", "SCO", "CAS", "ARA", "NAV", "POR", "HRE", "HUN", "POL", "TEU", "KAL", "BOS", "MOL", "WAL"]
const BLENDER_FACTIONS := ["osiyo", "rus", "xitoy", "ozbek", "rus2", "ingliz", "yevropa2", "usmonli", "xitoy2"]   # o'zimiz Blender'da yasagan (+X ga qaragan, otda o'tira oladi)
const ERA2_FACTIONS := ["ozbek", "rus2", "ingliz", "yevropa2", "usmonli", "xitoy2"]       # 1850-1880 askarlari models/era2 papkasida
## 2-zamon: madaniyat -> qo'shin modellari
const CULTURE_FACTION2 := {"ozbek": "ozbek", "rus": "rus2", "ingliz": "ingliz", "yevropa": "yevropa2", "usmonli": "usmonli", "xitoy": "xitoy2", "boshqa": "usmonli"}
const SCALE := {"yevropa": 0.96}     # Yevropa modellari ~1.88 m
const KNIGHT_SHARE := 0.3            # Yevropa qilichbozlarining qancha qismi ritser zirhida
const FALLBACK := {"italiya": {"nayzachi": "italiya_qilichboz", "kamonchi": "temur_kamonchi"}}


## musulmon davlatlar (masjid quriladi, binolar gumbazli)
const MUSLIM1 := ["DEL", "KAS", "KAN", "MAL", "GRA"]
const MUSLIM2 := ["MLY", "SOK", "TUK", "WAD", "ZAN", "KAN"]


static func is_muslim(country: String) -> bool:
	if not Game.countries.has(country):
		return true
	var cu: String = Game.countries[country].get("culture", "")
	if Game.era == 2:
		return cu in ["ozbek", "usmonli"] or country in MUSLIM2
	return cu in ["turk", "arab"] or country in MUSLIM1


static func player_faction() -> String:
	var pp: Array = Game.player_provinces()
	return faction_for(Game.provinces[pp[0]]["country"]) if not pp.is_empty() else default_faction()


static func default_faction() -> String:
	return "ozbek" if Game.era == 2 else "temur"


static func faction_for(country: String) -> String:
	if Game.era == 2:
		if Game.countries.has(country):
			return CULTURE_FACTION2.get(Game.countries[country].get("culture", ""), "ozbek")
		return "ozbek"
	if country in EUROPE:
		return "yevropa"
	if country in ["JAP", "DAI"]:
		return "xitoy"
	if country == "YUA":       # Shimoliy Yuan - mo'g'ul otliqlari
		return "temur"
	if Game.countries.has(country):
		return CULTURE_FACTION.get(Game.countries[country].get("culture", ""), "temur")
	return "temur"


static func _model_path(faction: String, kind: String) -> String:
	var p := "res://models/%s/%s_%s.glb" % ["era2" if faction in ERA2_FACTIONS else "era1", faction, kind]
	if ResourceLoader.exists(p):
		return p
	if faction in ERA2_FACTIONS:
		# 2-zamon: yo'q tur -> shu xalqning sarbozi -> o'zbek modeli
		for alt in ["%s_sarboz" % faction if kind in ["nayzachi", "miltiqchi", "qilichboz"] else "", "ozbek_%s" % kind, "%s_sarboz" % faction]:
			if alt != "" and ResourceLoader.exists("res://models/era2/%s.glb" % alt):
				return "res://models/era2/%s.glb" % alt
	var fb: String = FALLBACK.get(faction, {}).get(kind, "")
	if fb != "" and ResourceLoader.exists("res://models/era1/%s.glb" % fb):
		return "res://models/era1/%s.glb" % fb
	if ResourceLoader.exists("res://models/era1/temur_%s.glb" % kind):
		return "res://models/era1/temur_%s.glb" % kind
	return "res://models/era1/osiyo_%s.glb" % kind


static func soldier(faction: String, kind: String, team := Color("#2f7d4a"), knight := false) -> Node3D:
	if kind == "top":
		return cannon(team)
	var path := _model_path(faction, kind)
	if faction == "yevropa" and kind == "qilichboz" and (knight or randf() < KNIGHT_SHARE):
		path = "res://models/era1/yevropa_ritser.glb"
	var sc := _scene(path)
	if sc == null:
		return null
	var inst: Node3D = sc.instantiate()
	var n: Node3D = inst
	if not path.get_file().get_slice("_", 0) in BLENDER_FACTIONS:     # o'zimiz Blender'da yasagan modellar allaqachon +X ga qaragan
		# Gemini modellari +Z ga qaragan va kattaroq: o'yindagi askarlar kabi +X ga buriladi
		n = Node3D.new()
		n.add_child(inst)
		inst.rotation.y = PI / 2.0
		inst.scale = Vector3.ONE * float(SCALE.get(faction if path.contains(faction + "_") else "", GEMINI_SCALE))
		_alias_anims(anim(inst), kind)
	recolor(n, team)
	var ap := anim(n)
	if ap:
		for a in ["Idle", "Walk", "Run", "Block", "Ride", "Cheer", "Aim", "Look"]:
			if ap.has_animation(a):
				ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	return n


static func _alias_anims(ap: AnimationPlayer, kind: String) -> void:
	## Gemini animatsiya nomlarini o'yindagi umumiy nomlarga bog'laydi (Idle, Walk, Run, Attack, Block, Death1...)
	if ap == null:
		return
	var names: PackedStringArray = ap.get_animation_list()
	var find := func(keys: Array) -> String:
		for k in keys:
			for nm in names:
				if (nm as String).to_lower().contains((k as String).to_lower()):
					return nm
		return ""
	var archer := kind == "kamonchi"
	var map := {
		"Idle": find.call(["Idle"]),
		"Walk": find.call(["Walk", "Advance", "March"]),
		"Run": find.call(["Run"]),
		"Attack": find.call(["Fire_And_Reload", "Fire"]) if archer else find.call(["Overhead_Strike", "Forward_Thrust", "Overhead_Slash", "Strike", "Thrust"]),
		"Attack2": find.call(["Kneeling"]) if archer else find.call(["Horizontal", "Impale", "Cleave"]),
		"Block": find.call(["Draw_And_Aim", "Aim"]) if archer else find.call(["Block", "Brace"]),
		"Death1": find.call(["Death"]),
	}
	map["Death2"] = map["Death1"]
	map["Hit"] = map["Block"]
	map["Cheer"] = map["Attack2"] if map["Attack2"] != "" else map["Attack"]
	var lib := ap.get_animation_library("")
	for our in map:
		var src: String = map[our]
		if src != "" and not ap.has_animation(our):
			lib.add_animation(our, ap.get_animation(src))


static func cannon(team := Color("#2f7d4a")) -> Node3D:
	## 2-zamon to'pi: yog'och lafet, ikki g'ildirak, bronza stvol. Stvol (Barrel) +X ga qaragan.
	var root := Node3D.new()
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("#5a3b22")
	wood.roughness = 0.85
	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = Color("#8a6a3a")
	bronze.metallic = 0.75
	bronze.roughness = 0.35
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color("#2a2a2c")
	iron.metallic = 0.6
	var trail := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(2.4, 0.18, 0.34)
	trail.mesh = tb
	trail.material_override = wood
	trail.position = Vector3(-0.7, 0.45, 0)
	trail.rotation.z = deg_to_rad(-14)
	root.add_child(trail)
	var axle := MeshInstance3D.new()
	var am := CylinderMesh.new()
	am.top_radius = 0.06
	am.bottom_radius = 0.06
	am.height = 1.5
	axle.mesh = am
	axle.material_override = iron
	axle.rotation.x = PI / 2.0
	axle.position = Vector3(0.1, 0.62, 0)
	root.add_child(axle)
	for sz in [-0.68, 0.68]:
		var wh := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.5
		tm.outer_radius = 0.62
		wh.mesh = tm
		wh.material_override = wood
		wh.rotation.x = PI / 2.0
		wh.position = Vector3(0.1, 0.62, sz)
		root.add_child(wh)
		for k in 6:
			var sp := MeshInstance3D.new()
			var sm := BoxMesh.new()
			sm.size = Vector3(1.0, 0.05, 0.05)
			sp.mesh = sm
			sp.material_override = wood
			sp.position = Vector3(0.1, 0.62, sz)
			sp.rotation.z = k * PI / 6.0
			root.add_child(sp)
	var barrel := Node3D.new()
	barrel.name = "Barrel"
	barrel.position = Vector3(0.15, 0.95, 0)
	root.add_child(barrel)
	var bm := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.1
	bc.bottom_radius = 0.17
	bc.height = 1.9
	bm.mesh = bc
	bm.material_override = bronze
	bm.rotation.z = -PI / 2.0
	bm.position = Vector3(0.45, 0, 0)
	barrel.add_child(bm)
	var band := MeshInstance3D.new()
	var bnm := CylinderMesh.new()
	bnm.top_radius = 0.19
	bnm.bottom_radius = 0.19
	bnm.height = 0.1
	band.mesh = bnm
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = team
	band.material_override = tmat
	band.rotation.z = -PI / 2.0
	band.position = Vector3(-0.3, 0, 0)
	barrel.add_child(band)
	root.set_meta("cannon", true)
	return root


static func horse(team := Color("#2f7d4a")) -> Node3D:
	## Yangi ot (ot.glb, Gemini): +Z ga qaragan, "Rider_Mount" suyagi bor. Bo'lmasa eski horse.glb.
	var n: Node3D
	var sc := _scene("res://models/era1/ot.glb")
	if sc:
		var inst: Node3D = sc.instantiate()
		n = Node3D.new()
		n.add_child(inst)
		inst.rotation.y = PI / 2.0
		var hp := anim(inst)
		if hp:
			var lib := hp.get_animation_library("")
			for pair in [["Gallop", "Run"], ["Death", "Death1"], ["Rear", "Cheer"]]:
				if not hp.has_animation(pair[0]) and hp.has_animation(pair[1]):
					lib.add_animation(pair[0], hp.get_animation(pair[1]))
	else:
		sc = _scene("res://models/era1/horse.glb")
		if sc == null:
			return null
		n = sc.instantiate()
	recolor(n, team)
	var ap := anim(n)
	if ap:
		for a in ["Idle", "Walk", "Gallop", "Run", "Trot"]:
			if ap.has_animation(a):
				ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	return n


static func cavalry(faction: String, kind: String, team := Color("#2f7d4a")) -> Node3D:
	## Ot + chavandoz: chavandoz ot "Root" suyagiga bog'lanadi, ot bilan birga tebranadi.
	var h := horse(team)
	var r := soldier(faction if faction in BLENDER_FACTIONS else "osiyo", kind, team)     # otda o'tirish animatsiyasi faqat Blender modellarida bor
	if h == null or r == null:
		return h if h else r
	var sk := _skeleton(h)
	if sk and sk.find_bone("Rider_Mount") >= 0:
		# yangi ot: chavandoz egar suyagiga bog'lanadi; ot skeleti +Z ga qaragan, chavandoz +X ga - -90 gradus buriladi
		var ba := BoneAttachment3D.new()
		ba.bone_name = "Rider_Mount"
		sk.add_child(ba)
		var holder := Node3D.new()
		ba.add_child(holder)
		holder.add_child(r)
		var rest := sk.get_bone_global_rest(sk.find_bone("Rider_Mount"))
		var seat := rest.origin + Vector3(0, -0.96 + RIDER_DROP, 0)
		holder.transform = rest.affine_inverse() * Transform3D(Basis(Vector3.UP, -PI / 2.0), seat)
	elif sk:
		var ba := BoneAttachment3D.new()
		ba.bone_name = "Root"
		sk.add_child(ba)
		var holder := Node3D.new()
		ba.add_child(holder)
		holder.add_child(r)
		# chavandozni skelet fazosida egar ustiga qo'yamiz (tik turgan holda), keyin Root suyagiga nisbatan ifodalaymiz
		var idx := sk.find_bone("Root")
		var rest := sk.get_bone_global_rest(idx)
		holder.transform = rest.affine_inverse() * Transform3D(Basis(), Vector3(0.02, SEAT_Y, 0.0))
	else:
		h.add_child(r)
		r.position = Vector3(0.1, 0.48, 0)
	h.set_meta("rider", r)
	return h


static func rider_of(n: Node3D) -> Node3D:
	return n.get_meta("rider") if n.has_meta("rider") else null


static func anim(n: Node) -> AnimationPlayer:
	## eng yaqin AnimationPlayer (kenglik bo'yicha qidiruv) - otdagi chavandozning pleyeri bilan adashmaydi
	var q: Array = [n]
	while not q.is_empty():
		var c: Node = q.pop_front()
		if c is AnimationPlayer:
			return c
		q.append_array(c.get_children())
	return null


static func _skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var s := _skeleton(c)
		if s:
			return s
	return null


static func play(n: Node3D, a: String, speed := 1.0, blend := 0.2) -> void:
	var ap := anim(n)
	if ap and ap.has_animation(a):
		ap.play(a, blend, speed)


static func recolor(root: Node, team: Color) -> void:
	## "TeamColor" materialini (belbog', qalqon, ot yopinchig'i) davlat rangiga bo'yaydi
	if root is MeshInstance3D:
		var mi := root as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m and m.resource_name == "TeamColor":
				var nm := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
				nm.albedo_color = team
				mi.set_surface_override_material(i, nm)
	for c in root.get_children():
		recolor(c, team)


static func flag(team: Color, tex: Texture2D = null, size := Vector2(1.4, 0.9)) -> MeshInstance3D:
	## Shamolda hilpillovchi bayroq (mato). Chap cheti (0,0,0) nuqtada - dastaga ulanadi.
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	pm.subdivide_width = 14
	pm.subdivide_depth = 6
	pm.orientation = PlaneMesh.FACE_Z
	pm.center_offset = Vector3(size.x * 0.5, -size.y * 0.5, 0)
	mi.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/flag.gdshader")
	m.set_shader_parameter("color", team)
	if tex:
		m.set_shader_parameter("tex", tex)
		m.set_shader_parameter("use_tex", true)
	m.set_shader_parameter("amp", size.x * 0.09)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


const FLAG_FILE := "user://player_flag.png"


static func load_flag_file() -> void:
	## o'yinchi yuklagan bayroq (oldingi o'yinlardan ham saqlanadi)
	if FileAccess.file_exists(FLAG_FILE):
		var img := Image.load_from_file(FLAG_FILE)
		if img:
			Game.set_meta("flag_tex", ImageTexture.create_from_image(img))


static func set_flag_image(path: String) -> String:
	## rasm faylidan bayroq: 256 px kenglikka keltiriladi va saqlanadi. Bo'sh qator - muvaffaqiyat
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return "Rasmni ochib bo'lmadi (PNG, JPG yoki WEBP tanlang)."
	var w := 256
	var h := clampi(int(round(256.0 * img.get_height() / maxf(1.0, img.get_width()))), 96, 256)
	img.convert(Image.FORMAT_RGBA8)
	img.resize(w, h, Image.INTERPOLATE_LANCZOS)
	img.generate_mipmaps()
	img.save_png(FLAG_FILE)
	Game.set_meta("flag_tex", ImageTexture.create_from_image(img))
	return ""


static func standard(team: Color, height := 4.6) -> Node3D:
	## o'yinchi bayrog'i dastada (qal'a, qo'mondon uchun)
	var root := Node3D.new()
	var pole := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.03
	cm.bottom_radius = 0.04
	cm.height = height
	pole.mesh = cm
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color("#5a3b22")
	pole.material_override = pm
	pole.position.y = height * 0.5
	root.add_child(pole)
	var f := flag(team, flag_tex(), Vector2(1.5, 1.0))
	f.position = Vector3(0.03, height - 0.05, 0)
	f.rotation.y = PI
	root.add_child(f)
	return root


static func flag_tex() -> Texture2D:
	## o'yinchi yuklagan bayroq rasmi (bo'lsa)
	if Game.has_meta("flag_tex"):
		return Game.get_meta("flag_tex")
	return null


static func flag_bearer(faction: String, team: Color, tex: Texture2D = null, own := false) -> Node3D:
	## Bayroqdor: nayzachi qo'lida uzun dasta, tepasida hilpillovchi bayroq
	var root := Node3D.new()
	var s := soldier(faction, "qilichboz", team)
	if s:
		root.add_child(s)
		root.set_meta("body", s)
	var pole := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.025
	cm.bottom_radius = 0.03
	cm.height = 3.6
	pole.mesh = cm
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color("#5a3b22")
	pole.material_override = pm
	pole.position = Vector3(0.28, 1.8, -0.22)
	root.add_child(pole)
	var top := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	top.mesh = sm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("#d4aa3a")
	gm.metallic = 0.8
	top.material_override = gm
	top.position = Vector3(0.28, 3.62, -0.22)
	root.add_child(top)
	var f := flag(team, tex if tex else (flag_tex() if own else null))
	f.position = Vector3(0.3, 3.5, -0.22)
	f.rotation.y = PI      # bayroq orqaga (yurish yo'nalishiga teskari) hilpillaydi
	root.add_child(f)
	return root
