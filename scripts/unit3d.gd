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
const CULTURE_FACTION := {"xitoy": "xitoy", "rus": "rus", "fransuz": "yevropa", "turk": "turk", "arab": "arab", "italyan": "italiya", "yunon": "yunon"}
## yangi xalqlar (1400): Afrika (Mali, Kanem-Bornu...), Hindiston (Rajputlar, Dehli...), Angliya ("Winston" qirolligi uslubi)
const AFRICA1 := ["BEN", "ETH", "KAN", "MAK", "MAL", "SWA", "ZIM"]
const INDIA1 := ["DEL", "KAS", "ORI", "PAN", "SIN", "VIJ"]
const ENGLAND1 := ["ENG", "SCO"]
const AFRICA2 := ["SOK", "TUK", "WAD", "KAN", "ETH", "ZAN"]
const INDIA2 := ["NEP"]
## G'arbiy va Markaziy Yevropa davlatlari (ma'lumotda "boshqa" madaniyatli) - Yevropa ritsarlari
const EUROPE := ["ENG", "SCO", "CAS", "ARA", "NAV", "POR", "HRE", "HUN", "POL", "TEU", "KAL", "BOS", "MOL", "WAL"]
const BLENDER_FACTIONS := ["osiyo", "rus", "xitoy", "arabi", "afrika", "hind", "yunon", "angliya", "ozbek", "rus2", "ingliz", "yevropa2", "usmonli", "xitoy2"]   # o'zimiz Blender'da yasagan (+X ga qaragan, otda o'tira oladi)
## Mixamo skeletli yangi askarlar models/era1/mx/ papkasida: 1.8 m, +X ga qaragan,
## animatsiya nomlari allaqachon o'yinnikidek (Idle/Walk/Run/Attack/Block/Hit/Death1/Ride...)
## - burish/miqyoslash kerak emas, qalqon model ichiga qo'shilgan.
const MIXAMO_DIR := "/era1/mx/"
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


## qal'a uslubi (madaniyat va zamonga qarab): isl (O'rta Osiyo, default), rus (kreml), yevropa, xitoy, arab, bastion (1860-70)
const STYLE_TOP := {"isl": 11.65, "rus": 11.65, "yevropa": 11.65, "xitoy": 11.95, "arab": 11.65, "bastion": 7.1}
const EAST_ASIA := ["JAP", "DAI", "KOR", "AVA", "AYU", "CHA", "KHM", "MAJ", "SUK", "ANN", "SIA", "QNG", "MNG", "TIB", "YUA"]


static func castle_style(country: String) -> String:
	if not Game.countries.has(country):
		return "isl"
	var cu: String = Game.countries[country].get("culture", "")
	if Game.era == 2:
		if country in AFRICA2:
			return "afrika"
		if country in INDIA2:
			return "hind"
		if cu in ["rus", "yevropa", "ingliz"]:
			return "bastion"
		if cu == "xitoy" or country in EAST_ASIA:
			return "xitoy"
		if cu in ["ozbek", "usmonli"]:
			return "isl"
		return "isl" if is_muslim(country) else "arab"
	if cu == "rus":
		return "rus"
	if country in AFRICA1:
		return "afrika"
	if country in INDIA1:
		return "hind"
	if cu == "yunon":
		return "yunon"
	if cu == "xitoy" or country in EAST_ASIA:
		return "xitoy" if country != "YUA" else "isl"
	if cu in ["fransuz", "italyan"] or country in EUROPE or country == "GEO":
		return "yevropa"
	if cu == "arab":
		return "arab"
	if is_muslim(country):
		return "isl"
	return "arab"      # Afrika, Hindiston: paxsa/tosh cho'l qal'asi


static func building_style(country: String) -> String:
	## binolar uslubi (zamondan qat'i nazar xalq madaniyati): isl, rus, yevropa, xitoy, arab
	if not Game.countries.has(country):
		return "isl"
	var cu: String = Game.countries[country].get("culture", "")
	if cu == "rus":
		return "rus"
	if country in AFRICA1 or country in AFRICA2:
		return "afrika"
	if country in INDIA1 or country in INDIA2:
		return "hind"
	if cu == "yunon" or country == "GRE":
		return "yunon"
	if cu == "xitoy" or country in EAST_ASIA:
		return "xitoy" if country != "YUA" else "isl"
	if cu in ["fransuz", "italyan", "yevropa", "ingliz"] or country in EUROPE or country == "GEO":
		return "yevropa"
	if cu == "arab" or country in ["ARA", "EGY", "MOR", "OMA"]:
		return "arab"
	if is_muslim(country):
		return "isl"
	return "arab"


static func castle_file(country: String, part: String) -> String:
	## qal'a qismi (wall/tower/gate/keep) yoki bino modelining yo'li - davlat madaniyatiga qarab
	var st := castle_style(country) if part in ["wall", "tower", "gate", "keep"] else building_style(country)
	if part == "moat":
		return "res://models/castle/moat.glb"
	if part == "mosque":
		return "res://models/castle_isl/mosque.glb"
	if st != "isl":
		var p := "res://models/castle_%s/%s.glb" % [st, part]
		if ResourceLoader.exists(p):
			return p
	var q := "res://models/castle_isl/%s.glb" % part
	if ResourceLoader.exists(q) and (st == "isl" or part in ["wall", "tower", "gate", "keep"]):
		return q
	return "res://models/castle/%s.glb" % part


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
	if country in ENGLAND1:
		return "angliya"
	if country in AFRICA1:
		return "afrika"
	if country in INDIA1:
		return "hind"
	if country in EUROPE:
		return "yevropa"
	if country in ["JAP", "DAI"]:
		return "xitoy"
	if country == "YUA":       # Shimoliy Yuan - mo'g'ul otliqlari
		return "temur"
	if Game.countries.has(country):
		return CULTURE_FACTION.get(Game.countries[country].get("culture", ""), "temur")
	return "temur"


## kamonchilar: Blender'da yasalgan haqiqiy otish animatsiyali modellar (o'qdondan o'q oladi, torni yuzgacha tortadi)
const ARCHER := {"temur": "osiyo", "arab": "arabi", "yevropa": "rus", "italiya": "rus"}


static func _model_path(faction: String, kind: String) -> String:
	# Mixamo skeletli yangi askarlar (era1/mx) - bo'lsa shular, bo'lmasa eski modellar
	if not faction in ERA2_FACTIONS:
		var mx := "res://models/era1/mx/%s_%s.glb" % [faction, kind]
		if ResourceLoader.exists(mx):
			return mx
	if kind == "kamonchi" and ARCHER.has(faction) and ResourceLoader.exists("res://models/era1/%s_kamonchi.glb" % ARCHER[faction]):
		return "res://models/era1/%s_kamonchi.glb" % ARCHER[faction]
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
		return cannon(team, faction)
	if kind == "fil":
		return fil(faction, team)
	if kind == "arava":
		return arava(faction, team)
	if kind == "narvonchi":
		# narvonchi: nayzachi, yelkasida yog'och narvon ko'tarib yuradi
		var nv := soldier(faction, "nayzachi", team)
		if nv:
			nv.add_child(_carried_ladder())
		return nv
	var path := _model_path(faction, kind)
	if faction == "yevropa" and kind == "qilichboz" and (knight or randf() < KNIGHT_SHARE):
		path = "res://models/era1/mx/yevropa_ritser.glb"
		if not ResourceLoader.exists(path):
			path = "res://models/era1/yevropa_ritser.glb"
	var sc := _scene(path)
	if sc == null:
		return null
	var inst: Node3D = sc.instantiate()
	var n: Node3D = inst
	var fam := path.get_file().get_slice("_", 0)
	var mixamo := path.contains(MIXAMO_DIR)
	if not mixamo and not fam in BLENDER_FACTIONS:     # o'zimiz Blender'da yasagan modellar allaqachon +X ga qaragan
		# Gemini modellari +Z ga qaragan va kattaroq: o'yindagi askarlar kabi +X ga buriladi
		n = Node3D.new()
		n.add_child(inst)
		inst.rotation.y = PI / 2.0
		inst.scale = Vector3.ONE * float(SCALE.get(faction if path.contains(faction + "_") else "", GEMINI_SCALE))
		_alias_anims(anim(inst), kind)
	recolor(n, team)
	# Mixamo askarlarida qalqon modelga qo'shib yuborilgan - qo'lni dasturiy burish kerak emas
	if not mixamo and kind in ["qilichboz", "nayzachi"] and Game.era < 2:
		ShieldPose.attach(n)        # qalqon doim ko'krak oldida, yuzi oldinga
	var ap := anim(n)
	if ap:
		for a in ["Idle", "Walk", "Run", "Ride", "Cheer", "Aim", "Look"]:
			if ap.has_animation(a):
				ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		if ap.has_animation("Block"):
			# himoya holati: bir marta qalqon/nayzani tutib, shu holatda qotib turadi (turib-o'tirib takrorlanmaydi)
			ap.get_animation("Block").loop_mode = Animation.LOOP_NONE
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


## qamal quroli / to'p jamoasi: [x, z, burilish(rad), vazifa]. Qurol +X ga qaragan.
const CREW := {
	"top": [[-1.4, 1.5, -0.6, "komandir"], [1.7, 0.95, PI, "o'qlovchi"], [-2.3, 0.35, 0.0, "nishonchi"], [-0.7, -1.35, 0.2, "otuvchi"]],
	"taran": [[-1.9, 0.55, 0.0, "itaruvchi"], [-1.9, -0.55, 0.0, "itaruvchi"], [-0.6, 0.55, 0.0, "tebratuvchi"], [-0.6, -0.55, 0.0, "tebratuvchi"],
		[0.7, 0.55, 0.0, "tebratuvchi"], [0.7, -0.55, 0.0, "tebratuvchi"]],
	"manjaniq_xitoy": [[2.6, -1.0, PI, "tortuvchi"], [3.2, -0.6, PI, "tortuvchi"], [2.6, -0.2, PI, "tortuvchi"], [3.2, 0.2, PI, "tortuvchi"],
		[2.6, 0.6, PI, "tortuvchi"], [3.2, 1.0, PI, "tortuvchi"], [-5.0, 0.8, -0.4, "tosh tashuvchi"], [-1.0, 2.0, -1.0, "ilgakchi"]],
	"manjaniq": [[-3.2, 1.9, 0.0, "tortuvchi"], [-3.2, -1.9, 0.0, "tortuvchi"], [-2.5, 2.4, 0.3, "tortuvchi"], [-5.5, 0.8, -0.4, "tosh tashuvchi"],
		[1.5, 2.2, -1.2, "ilgakchi"]],
}


static func add_crew(node: Node3D, faction: String, team: Color, type: String) -> void:
	if faction == "" or not CREW.has(type):
		return
	var crew: Array = []
	for c in CREW[type]:
		var k := "sarboz" if Game.era == 2 else ("nayzachi" if type == "taran" else "qilichboz")
		var s := soldier(faction, k, team)
		if s == null:
			continue
		node.add_child(s)
		s.position = Vector3(c[0], 0, c[1])
		s.rotation.y = c[2]
		s.set_meta("role", c[3])
		if type == "taran":
			s.scale = Vector3.ONE * 0.95
		play(s, "Idle")
		crew.append(s)
	node.set_meta("crew", crew)


static func crew_play(node: Node3D, a: String, role := "", restart := false) -> void:
	for s in node.get_meta("crew", []):
		if is_instance_valid(s) and (role == "" or (s as Node3D).get_meta("role", "") == role):
			var ap := anim(s)
			if ap and ap.has_animation(a):
				if restart:
					ap.stop()
				if restart or ap.current_animation != a:
					ap.play(a, 0.15)


static func cannon(team := Color("#2f7d4a"), faction := "") -> Node3D:
	## 2-zamon to'pi: yog'och lafet, ikki g'ildirak, bronza stvol. Stvol (Barrel) +X ga qaragan.
	var sc := _scene("res://models/siege/top.glb")
	if sc:
		var mo: Node3D = sc.instantiate()
		recolor(mo, team)
		mo.set_meta("cannon", true)
		add_crew(mo, faction, team, "top")
		return mo
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


## ---- zirh (temirchida yasaladi): 1 - charm, 2 - temir (1-zamon). Har qanday skeletga (Chest/UpperArm/Hips) kiydiriladi
static func _mat(c: Color, metal := 0.0, rough := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	return m


static func _bone(sk: Skeleton3D, names: Array) -> int:
	for nm in names:
		var i := sk.find_bone(nm)
		if i >= 0:
			return i
	return -1


static func _attach(sk: Skeleton3D, bi: int, mesh: Mesh, m: Material, xf: Transform3D) -> void:
	var ba := BoneAttachment3D.new()
	ba.bone_idx = bi
	ba.set_meta("armor_piece", true)
	sk.add_child(ba)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	ba.add_child(mi)
	mi.transform = sk.get_bone_global_rest(bi).affine_inverse() * xf


static func equip(n: Node3D, tier: int) -> void:
	if tier <= 0 or n == null or Game.era >= 2:
		return
	var rd := rider_of(n)
	var tgt: Node3D = rd if rd != null else n
	var sk := _skeleton(tgt)
	if sk == null or int(sk.get_meta("armor", 0)) == tier:
		return
	for old in sk.get_children():
		if old is BoneAttachment3D and old.has_meta("armor_piece"):
			old.queue_free()
	sk.set_meta("armor", tier)
	var ch := _bone(sk, ["Chest"])
	var ul := _bone(sk, ["UpperArm.L", "UpperArm_L"])
	var ur := _bone(sk, ["UpperArm.R", "UpperArm_R"])
	var nk := _bone(sk, ["Neck"])
	var hp := _bone(sk, ["Hips"])
	if ch < 0 or ul < 0 or ur < 0 or nk < 0 or hp < 0:
		return
	var pl := sk.get_bone_global_rest(ul).origin
	var pr := sk.get_bone_global_rest(ur).origin
	var pn := sk.get_bone_global_rest(nk).origin
	var ph := sk.get_bone_global_rest(hp).origin
	var pc := sk.get_bone_global_rest(ch).origin
	var xa := (pl - pr).normalized()
	var ya := (pn - ph).normalized()
	var za := xa.cross(ya).normalized()
	var w := pl.distance_to(pr)
	var bas := Basis(xa, ya, za)
	var main := _mat(Color("#6b4a2e"), 0.0, 0.85) if tier == 1 else _mat(Color("#a8adb3"), 0.8, 0.35)
	var band := _mat(Color("#4a3220"), 0.0, 0.9) if tier == 1 else _mat(Color("#c9a03a"), 0.85, 0.3)
	# ko'krak zirhi (qavat-qavat plastinkalar)
	var hgt := pn.distance_to(ph) * 0.62
	var cen := (pc + pn) * 0.5 - ya * hgt * 0.18
	var bx := BoxMesh.new()
	bx.size = Vector3(w * 0.78, hgt, w * 0.5)
	_attach(sk, ch, bx, main, Transform3D(bas, cen))
	for k in 3:
		var bb := BoxMesh.new()
		bb.size = Vector3(w * 0.8, hgt * 0.07, w * 0.52)
		_attach(sk, ch, bb, band, Transform3D(bas, cen + ya * hgt * (-0.36 + k * 0.3)))
	# yelkaliklar
	for pair in [[ul, pl, 1.0], [ur, pr, -1.0]]:
		var sm := SphereMesh.new()
		sm.radius = w * 0.17
		sm.height = w * 0.24
		sm.is_hemisphere = true
		_attach(sk, pair[0], sm, main, Transform3D(bas, pair[1] + xa * pair[2] * w * 0.06 + ya * w * 0.02))
	if tier >= 2:
		# temir halqali etak (kolchuga)
		var cm := CylinderMesh.new()
		cm.top_radius = w * 0.42
		cm.bottom_radius = w * 0.52
		cm.height = hgt * 0.45
		_attach(sk, hp, cm, _mat(Color("#8a8f96"), 0.7, 0.45), Transform3D(bas, ph - ya * hgt * 0.15))


## ---- ot yopinchig'i: har xalq va zamonga o'z rangi
const CAPARISON := {"temur": ["#1f4e8c", "#c9a03a"], "osiyo": ["#1f4e8c", "#c9a03a"], "arab": ["#e8e2d0", "#2f6b4a"], "arabi": ["#e8e2d0", "#2f6b4a"],
	"rus": ["#9a2a24", "#c9a03a"], "xitoy": ["#c9a03a", "#9a2a22"], "yevropa": ["", "#f0ece0"], "italiya": ["", "#f0ece0"],
	"ozbek": ["#8a2a3a", "#c9a03a"], "rus2": ["#1e2a4a", "#b03030"], "ingliz": ["#1e2340", "#b0242a"], "yevropa2": ["#2a3a6a", "#c9a03a"],
	"usmonli": ["#9a2a24", "#e8d8a0"], "xitoy2": ["#c9a03a", "#2a3a7a"],
	"afrika": ["#c9b48a", "#8a3a1e"], "hind": ["#c0392b", "#d8b040"], "yunon": ["#a8282a", "#b08a4a"], "angliya": ["", "#d8b040"]}


# yopinchiq ot tanasiga yopishib turadi - chavandozning oyoqlari uning USTIDAN ko'rinadi
const CAP_HW := 0.25
const CAP_TOP := 1.5


static func caparison(h: Node3D, faction: String, team: Color) -> void:
	var sk := _skeleton(h)
	if sk == null or sk.find_bone("Spine") < 0 or not CAPARISON.has(faction):
		return
	var cols: Array = CAPARISON[faction]
	var main := _mat(team if cols[0] == "" else Color(cols[0]), 0.0, 0.9)
	var trim := _mat(Color(cols[1]), 0.3 if cols[1] == "#c9a03a" else 0.0, 0.6)
	var sp := sk.find_bone("Spine")
	var full: bool = faction in ["temur", "osiyo", "arab", "arabi", "rus", "xitoy", "yevropa", "italiya", "afrika", "hind", "yunon", "angliya"]     # 1400: uzun yopinchiq
	var z0 := -0.72 if full else -0.38
	var z1 := 0.62 if full else 0.28
	var ytop := CAP_TOP
	var ybot := 0.95 if full else 1.18
	# yumshoq yopinchiq: ot beli ustidan egilib, ikki yonga osilib tushadi, pastki cheti to'lqinsimon
	var m2: StandardMaterial3D = main.duplicate()
	m2.cull_mode = BaseMaterial3D.CULL_DISABLED
	_attach(sk, sp, _drape(CAP_HW, ytop, ybot, z0, z1, 0.0), m2, Transform3D())
	var t2: StandardMaterial3D = trim.duplicate()
	t2.cull_mode = BaseMaterial3D.CULL_DISABLED
	_attach(sk, sp, _drape(CAP_HW + 0.015, ybot + 0.1, ybot, z0 - 0.01, z1 + 0.01, 0.07, true), t2, Transform3D())


static func _drape(hw: float, ytop: float, ybot: float, z0: float, z1: float, wave: float, band := false) -> ArrayMesh:
	## mato: ko'ndalang kesimi ellips yoy (tepada) + ikki yonga osilgan qism; z bo'ylab cho'zilgan.
	## band=true - faqat pastki tasma (bezak hoshiyasi)
	var prof: Array = []      # (x, y) ko'ndalang profil
	var arc_c := ytop - 0.16
	if band:
		prof = [Vector2(-hw * 1.07, ytop), Vector2(-hw * 1.1, ybot)]
	else:
		var n := 10
		prof.append(Vector2(-hw * 1.1, ybot))
		prof.append(Vector2(-hw * 1.05, (ybot + arc_c) * 0.5))
		for i in n + 1:
			var t := -PI / 2.0 + PI * float(i) / float(n)
			prof.append(Vector2(hw * sin(t), arc_c + 0.16 * cos(t)))
		prof.append(Vector2(hw * 1.05, (ybot + arc_c) * 0.5))
		prof.append(Vector2(hw * 1.1, ybot))
	var segs := 16
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	var parts: Array = [prof] if not band else [prof, prof.map(func(v): return Vector2(-v.x, v.y))]
	for pr in parts:
		var rows: Array = []
		for j in segs + 1:
			var u := float(j) / float(segs)
			var z := lerpf(z0, z1, u)
			# uchlari biroz yumaloqlangan, pastki chetida to'lqin (burmalar)
			var row: Array = []
			for k in pr.size():
				var v: Vector2 = pr[k]
				var y := v.y
				var x := v.x
				if y < ytop - 0.2 or band:
					var lowness := clampf((ytop - 0.2 - y) / maxf(0.01, ytop - 0.2 - ybot), 0.0, 1.0) if not band else 1.0
					y += (0.035 * sin(u * PI * 9.0) - 0.06 * pow(absf(u * 2.0 - 1.0), 4.0)) * lowness
					x += signf(x) * (0.012 * sin(u * PI * 9.0 + 1.2)) * lowness
				row.append(Vector3(x, y, z))
			rows.append(row)
		for j in segs:
			for k in pr.size() - 1:
				var a: Vector3 = rows[j][k]
				var b: Vector3 = rows[j + 1][k]
				var c: Vector3 = rows[j + 1][k + 1]
				var d: Vector3 = rows[j][k + 1]
				st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)
				st.add_vertex(a); st.add_vertex(c); st.add_vertex(d)
	st.generate_normals()
	return st.commit()


static func horse(team := Color("#2f7d4a"), faction := "") -> Node3D:
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
	if h:
		caparison(h, faction, team)
	# otda o'tirish animatsiyasi (Ride) Blender va Mixamo modellarida bor; boshqalarida yo'q - "osiyo" ishlatiladi
	var can_ride := faction in BLENDER_FACTIONS \
		or ResourceLoader.exists("res://models/era1/mx/%s_%s.glb" % [faction, kind])
	var r := soldier(faction if can_ride else "osiyo", kind, team)
	if r:
		var spm := ShieldPose._find(r)
		if spm:
			spm.front_target = 0.0
			spm.front = 0.0
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


static func _carried_ladder() -> Node3D:
	var root := Node3D.new()
	root.name = "CarriedLadder"
	var wm := _mat(Color("#7a5530"))
	for s in [-0.22, 0.22]:
		var rail := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(4.2, 0.07, 0.07)
		rail.mesh = bm
		rail.material_override = wm
		rail.position = Vector3(0.3, 1.62, s)
		root.add_child(rail)
	for k in 9:
		var rung := MeshInstance3D.new()
		var rb := BoxMesh.new()
		rb.size = Vector3(0.05, 0.05, 0.44)
		rung.mesh = rb
		rung.material_override = wm
		rung.position = Vector3(-1.6 + k * 0.48, 1.62, 0)
		root.add_child(rung)
	root.rotation.z = 0.12
	return root


static func _attach_at(sk: Skeleton3D, bone: String, child: Node3D, pos_skel: Vector3, yaw := 0.0) -> void:
	var bi := sk.find_bone(bone)
	if bi < 0:
		return
	var ba := BoneAttachment3D.new()
	ba.bone_idx = bi
	sk.add_child(ba)
	var holder := Node3D.new()
	ba.add_child(holder)
	holder.add_child(child)
	holder.transform = sk.get_bone_global_rest(bi).affine_inverse() * Transform3D(Basis(Vector3.UP, yaw), pos_skel)


static func fil(faction: String, team: Color) -> Node3D:
	## jangovar fil: havdada 2 kamonchi, bo'ynida filbon. Hind va Afrika uslubi
	var st := "afrika" if faction == "afrika" else "hind"
	var sc := _scene("res://models/beasts/fil_%s.glb" % st)
	if sc == null:
		return null
	var root := Node3D.new()
	var inst: Node3D = sc.instantiate()
	root.add_child(inst)
	recolor(root, team)
	var ap := anim(inst)
	if ap:
		for a in ["Idle", "Walk", "Run"]:
			if ap.has_animation(a):
				ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		ap.play("Idle")
	var sk := _skeleton(inst)
	var archers: Array = []
	if sk:
		var mah := soldier(faction, "qilichboz", team)
		if mah:
			_attach_at(sk, "Mahout", mah, Vector3(1.1, 3.15 - 0.96 + RIDER_DROP, 0))
			play(mah, "Ride")
		for z in [-0.34, 0.34]:
			var ar := soldier(faction, "kamonchi", team)
			if ar:
				# havda ichida, tizzagacha devor orqasida - yon tomonlarga qarab o'q uzadi
				_attach_at(sk, "Howdah", ar, Vector3(-0.1 - z * 0.6, 3.05, z * 0.9), 0.0)
				ar.scale = Vector3.ONE * 0.86
				play(ar, "Block")
				archers.append(ar)
	root.set_meta("fil", true)
	root.set_meta("crew", archers)
	return root


static func howdah_shoot(n: Node3D) -> void:
	for ar in n.get_meta("crew", []):
		if is_instance_valid(ar):
			var ap := anim(ar)
			if ap and ap.has_animation("Attack"):
				ap.stop()
				ap.play("Attack", 0.1)


static func arava(faction: String, team: Color) -> Node3D:
	## yunon jangovar aravasi: ikki ot, aravakash va nayzali jangchi
	var sc := _scene("res://models/beasts/arava_yunon.glb")
	if sc == null:
		return null
	var root := Node3D.new()
	var inst: Node3D = sc.instantiate()
	root.add_child(inst)
	var horses: Array = []
	for z in [-0.5, 0.5]:
		var h := horse(team)
		if h:
			h.position = Vector3(2.35, 0, z)
			h.scale = Vector3.ONE * 0.92
			caparison(h, faction, team)
			root.add_child(h)
			horses.append(h)
	var riders: Array = []
	for pr in [["qilichboz", Vector3(0.15, 0.8, -0.25)], ["nayzachi", Vector3(-0.15, 0.8, 0.25)]]:
		var s := soldier(faction, pr[0], team)
		if s:
			s.position = pr[1]
			s.scale = Vector3.ONE * 0.95
			root.add_child(s)
			play(s, "Idle")
			riders.append(s)
	recolor(root, team)
	root.set_meta("arava", true)
	root.set_meta("horses", horses)
	root.set_meta("riders", riders)
	return root


static func play(n: Node3D, a: String, speed := 1.0, blend := 0.2) -> void:
	if n.has_meta("arava"):
		var ha: String = {"Run": "Gallop", "Walk": "Walk", "Idle": "Idle", "Attack": "Gallop", "Death1": "Death", "Death2": "Death", "Block": "Idle", "Hit": "Idle"}.get(a, "Idle")
		for h in n.get_meta("horses", []):
			var hp := anim(h)
			if hp and hp.has_animation(ha):
				hp.play(ha, blend, speed)
		var rs: Array = n.get_meta("riders", [])
		for i in rs.size():
			var ra := "Attack" if (a == "Attack" and i == 1) else ("Death1" if a.begins_with("Death") else ("Block" if a == "Run" and i == 1 else "Idle"))
			var rp := anim(rs[i])
			if rp and rp.has_animation(ra):
				rp.play(ra, blend, speed)
		return
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
