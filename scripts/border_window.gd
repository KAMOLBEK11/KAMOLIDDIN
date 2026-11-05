extends PanelContainer
## Chegara oynasi: ikki viloyat orasidagi chegara. Post qurish, qo'shin to'plash / qaytarish,
## qo'shni davlat bilan chegara rejimi (vizasiz / oddiy / yopiq), narigi tomondagi dushman kuchlari va hujum.

var body: VBoxContainer
var id := ""
var nb := ""
var _dirty := false
var _ss: HSlider
var _st: HSlider


func _ready() -> void:
	var v := UIKit.window(self, "CHEGARA", "res://pics/buildings/post.png", 760, 620)
	body = UIKit.scroll(v)
	Game.changed.connect(func(): _dirty = true)
	Game.open_border.connect(open_at)


func _process(_d: float) -> void:
	if _dirty and visible:
		_dirty = false
		rebuild()


func open_at(a: String, b: String) -> void:
	id = a
	nb = b
	visible = true
	rebuild()


func rebuild() -> void:
	UIKit.clear(body)
	if id == "" or not Game.provinces.has(id):
		return
	var p: Dictionary = Game.provinces[id]
	var q: Dictionary = Game.provinces[nb]
	if p["owner"] != Game.PLAYER:
		visible = false
		return
	var c: String = q["owner"]
	var foreign := c != Game.PLAYER and c != Game.REBEL
	# sarlavha: ikki bayroq
	var hc := UIKit.card(body, UIKit.CARD, Color("#3b4a5c"))
	var h := UIKit.row(hc, 14)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(UIKit.flag(p["country"], 72))
	h.add_child(UIKit.label(p["name"], 20, UIKit.GOLD))
	h.add_child(UIKit.pic("res://pics/buildings/post.png", Vector2(64, 64)))
	h.add_child(UIKit.label(q["name"], 20, UIKit.BAD if War.wars.has(c) else Color.WHITE))
	if foreign:
		h.add_child(UIKit.flag(c, 72))
	var status := "Isyonchilar hududi" if c == Game.REBEL else ("%s  |  munosabat %+d  |  %s" % [War.country_name(c), roundi(Diplo.rel.get(c, 0.0)), "URUSH" if War.wars.has(c) else Diplo.rel_text(c)]) if foreign else "Ichki chegara"
	var sl := UIKit.label(status, 14, UIKit.BAD if War.wars.has(c) else UIKit.INFO)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hc.add_child(sl)

	# post
	var pc := UIKit.card(body)
	pc.add_child(UIKit.label("Chegara posti", 17, Color.WHITE))
	var has_done := Game.has_post(id, nb)
	var has_any := Game.has_post(id, nb, false)
	if has_done:
		pc.add_child(UIKit.label("Post ishlamoqda: mahalliy mudofaa +6, bu tomondan kelgan dushman 25% zaif, dushman to'planishi 5 kun oldin seziladi.", 13, UIKit.GOOD, true))
	elif has_any:
		var left := 0
		for po in p.get("posts", []):
			if po["to"] == nb: left = po["days_left"]
		pc.add_child(UIKit.label("Post qurilmoqda: %d kun qoldi." % left, 14, UIKit.GOLD))
	else:
		pc.add_child(UIKit.label("Post yo'q. Qo'shinni chegarada to'plash va hujum qilish uchun avval post kerak.", 13, UIKit.DIM, true))
		UIKit.button(pc, "Post qurish (%d $, %d kun)" % [Game.POST_COST, Game.POST_DAYS], Game.can_post(id, nb), Game.build_post.bind(id, nb), true)

	# qo'shin
	if has_done:
		var key := "post:" + nb
		var at := Game.site_units(p, key)
		var tc := UIKit.card(body)
		tc.add_child(UIKit.label("Chegaradagi qo'shin", 17, Color.WHITE))
		var g := UIKit.grid(tc, 4)
		g.add_child(UIKit.weapon_pic("soldier", Vector2(80, 60)))
		g.add_child(UIKit.label("%d askar" % roundi(at["soldier"]), 18, UIKit.GOLD))
		g.add_child(UIKit.weapon_pic("mbt", Vector2(90, 60)))
		g.add_child(UIKit.label("%d tank" % roundi(at["tank"]), 18, UIKit.GOLD))
		var free_s := int(p["units"]["soldier"] - at["soldier"])
		var free_t := int(p["units"]["tank"] - at["tank"])
		tc.add_child(UIKit.label("Viloyatning boshqa joylarida: %d askar, %d tank. Qanchasini chegaraga yuborasiz?" % [free_s, free_t], 13, UIKit.DIM, true))
		var r1 := UIKit.row(tc)
		r1.add_child(UIKit.label("Askar", 13))
		_ss = HSlider.new()
		_ss.max_value = maxi(0, free_s)
		_ss.step = 10 if free_s >= 20 else 1
		_ss.value = free_s
		_ss.custom_minimum_size = Vector2(260, 22)
		r1.add_child(_ss)
		var ls := UIKit.label(str(free_s), 13, UIKit.GOLD)
		r1.add_child(ls)
		_ss.value_changed.connect(func(v): ls.text = str(int(v)))
		var r2 := UIKit.row(tc)
		r2.add_child(UIKit.label("Tank  ", 13))
		_st = HSlider.new()
		_st.max_value = maxi(0, free_t)
		_st.step = 1
		_st.value = free_t
		_st.custom_minimum_size = Vector2(260, 22)
		r2.add_child(_st)
		var lt := UIKit.label(str(free_t), 13, UIKit.GOLD)
		r2.add_child(lt)
		_st.value_changed.connect(func(v): lt.text = str(int(v)))
		var br := UIKit.row(tc)
		UIKit.button(br, "Chegaraga jo'natish", "" if free_s + free_t > 0 else "Bo'sh qo'shin yo'q", func(): Game.gather_to(id, key, int(_ss.value), int(_st.value)), true)
		UIKit.button(br, "Hammasini qaytarish", "" if at["soldier"] + at["tank"] >= 1 else "Chegarada qo'shin yo'q",
			func(): Game.move_units(id, key, Game.home_site(p, "soldier"), int(at["soldier"]), 0); Game.move_units(id, key, Game.home_site(p, "tank"), 0, int(at["tank"])))

	# narigi tomon
	if foreign or c == Game.REBEL:
		var ec := UIKit.card(body, Color("#2a1f22"))
		ec.add_child(UIKit.label("Narigi tomon (razvedka)", 17, Color.WHITE))
		var staged := 0.0
		for a in War.armies:
			if a["owner"] == c and a["at"] == nb and a["state"] == "stage" and not a["path"].is_empty() and a["path"][0] == id:
				staged += War.power(a)
		ec.add_child(UIKit.label("%s mudofaasi: ~%d kuch" % [q["name"], int(q["defense"])], 14))
		if staged > 0:
			ec.add_child(UIKit.label("DIQQAT: chegarada %d kuchli dushman qo'shini to'planmoqda!" % int(staged), 15, UIKit.BAD, true))
		elif War.wars.has(c) or Diplo.rel.get(c, 0.0) < -25.0:
			ec.add_child(UIKit.label("Dushman ham bu chegarani mustahkamlagan (qizil post).", 13, UIKit.GOLD, true))
		else:
			ec.add_child(UIKit.label("Chegarada tinchlik.", 13, UIKit.GOOD))
		if War.wars.has(c) or c == Game.REBEL:
			var at2 := Game.site_units(p, "post:" + nb)
			UIKit.button(ec, "HUJUM - chegaradagi %d askar va %d tank bilan" % [roundi(at2["soldier"]), roundi(at2["tank"])],
				"" if has_done and at2["soldier"] + at2["tank"] >= 1 else "Avval chegaraga qo'shin to'plang", _attack, true)
		elif foreign:
			UIKit.button(ec, "Urush e'lon qilish va hujum", "" if has_done else "Avval chegara posti kerak", _attack)

	# chegara rejimi
	if foreign:
		var mc := UIKit.card(body)
		mc.add_child(UIKit.label("%s bilan chegara rejimi (butun davlat bo'ylab)" % War.country_name(c), 17, Color.WHITE))
		var cur: String = Diplo.border_mode.get(c, "normal")
		for m in [["open", "Vizasiz rejim", "Odamlar erkin kirib-chiqadi: savdo +20%, munosabat yaxshilanadi. Kontrabanda xavfi."],
				["normal", "Oddiy rejim", "Viza va bojxona nazorati."],
				["closed", "Yopiq chegara", "Kirish-chiqish to'xtaydi: savdo -50%, munosabat yomonlashadi, xavfsizlik oshadi."]]:
			var rr := UIKit.row(mc)
			var b := UIKit.button(rr, ("● " if cur == m[0] else "") + m[1], Diplo.why_border_mode(c, m[0]) if cur != m[0] else "Hozirgi rejim", Diplo.set_border_mode.bind(c, m[0]), cur == m[0])
			b.custom_minimum_size = Vector2(170, 0)
			rr.add_child(UIKit.label(m[2], 12, UIKit.DIM, true))


func _attack() -> void:
	visible = false
	War.begin_target(id, "army")
	War.choose_target(nb)
