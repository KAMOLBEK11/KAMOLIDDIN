extends Node2D
## Fuqarolik aviatsiyasi: aeroportlaringizdan boshqa davlatlarga va ulardan sizga reyslar xaritada uchadi.
## Har bir reys kichik daromad va munosabat beradi. Xorijiy davlatlar o'rtasidagi reyslar ham ko'rinadi.

var cam: Camera2D
var flights: Array = []
var _rng := RandomNumberGenerator.new()
var _points := {}
var _tex: Texture2D


func _enter_tree() -> void:
	if ResourceLoader.exists("res://pics/sprites/top_airliner.png"):
		_tex = load("res://pics/sprites/top_airliner.png")


func _ready() -> void:
	_rng.randomize()
	Game.day_passed.connect(_on_day)


func _now() -> float:
	return Game.day + Game._acc / Game.SECONDS_PER_DAY


func _capital(c: String) -> Vector2:
	if _points.has(c):
		return _points[c]
	var best := -1
	var pos := Vector2.ZERO
	for id in Game.province_order:
		var p: Dictionary = Game.provinces[id]
		if p["country"] == c and p["population"] > best:
			best = p["population"]
			pos = p["center"]
	if best < 0:
		# xaritadan tashqaridagi yirik davlatlar - yo'nalish nuqtalari
		var r := Rect2(Game.provinces[Game.province_order[0]]["center"], Vector2.ZERO)
		for id in Game.province_order:
			r = r.expand(Game.provinces[id]["center"])
		var cx := r.get_center()
		match c:
			"USA": pos = Vector2(r.position.x - 1400, r.position.y - 300)
			"EU": pos = Vector2(r.position.x - 900, r.position.y - 150)
			"UKR": pos = Vector2(r.position.x - 700, r.position.y - 60)
			"RUS": pos = Vector2(cx.x - 200, r.position.y - 700)
			"TUR": pos = Vector2(r.position.x - 700, cx.y + 100)
			"ISR": pos = Vector2(r.position.x - 650, r.end.y + 50)
			"IRN": pos = Vector2(r.position.x - 200, r.end.y + 150)
			"SAU": pos = Vector2(r.position.x - 500, r.end.y + 450)
			"PAK": pos = Vector2(cx.x - 50, r.end.y + 350)
			"IND": pos = Vector2(cx.x + 250, r.end.y + 650)
			"PRK": pos = Vector2(r.end.x + 600, cx.y - 100)
			_: pos = cx + Vector2(0, 900)
	_points[c] = pos
	return pos


func _partners() -> Array:
	var out: Array = []
	for c in Game.countries:
		if Diplo.alive(c) and not War.wars.has(c) and Diplo.rel.get(c, 0.0) > -30.0:
			out.append(c)
	for p in Politics.powers():
		if not Game.countries.has(p) and Politics.prel.get(p, 0.0) > -30.0 and not Politics.sanctioned_by(p):
			out.append(p)
	return out


func _on_day(_d: int) -> void:
	if Game.era < 3:
		return   # qadimiy zamonda samolyot yo'q
	var airports: Array = []
	for id in Game.player_provinces():
		for b in Game.provinces[id]["buildings"]:
			if b["type"] == "airport" and b["days_left"] <= 0:
				airports.append(id)
	var partners := _partners()
	for id in airports:
		if partners.is_empty() or _rng.randf() > 0.6:
			continue
		var c: String = partners[_rng.randi() % partners.size()]
		var a: Vector2 = Game.provinces[id]["center"]
		var b := _capital(c)
		var incoming := _rng.randf() < 0.5
		_add(b if incoming else a, a if incoming else b, c, true)
	# xorijiy davlatlar orasidagi reyslar (fon)
	var all: Array = Game.countries.keys() + Politics.powers()
	for i in 2:
		if _rng.randf() < 0.55:
			var c1: String = all[_rng.randi() % all.size()]
			var c2: String = all[_rng.randi() % all.size()]
			if c1 != c2:
				_add(_capital(c1), _capital(c2), "", false)


func _add(a: Vector2, b: Vector2, partner: String, mine: bool) -> void:
	var dur := clampf(a.distance_to(b) / 260.0, 0.8, 4.0)
	flights.append({"a": a, "b": b, "t0": _now(), "dur": dur, "partner": partner, "mine": mine})


func _process(_d: float) -> void:
	var now := _now()
	for f in flights.duplicate():
		if now - f["t0"] >= f["dur"]:
			flights.erase(f)
			if f["mine"] and f["partner"] != "":
				Game.money += 6.0
				if Diplo.rel.has(f["partner"]):
					Diplo.change_rel(f["partner"], 0.15)
				elif Politics.prel.has(f["partner"]):
					Politics.change_prel(f["partner"], 0.15)
	queue_redraw()


var overlay := false


func flight_pos(f: Dictionary) -> Array:
	## 3D xarita uchun: [joy, yo'nalish, k]
	var k := clampf((_now() - f["t0"]) / f["dur"], 0.0, 1.0)
	var a: Vector2 = f["a"]
	var b: Vector2 = f["b"]
	var mid := a.lerp(b, 0.5) + (b - a).orthogonal().normalized() * a.distance_to(b) * 0.08
	var pos := _bez(a, mid, b, k)
	var pos2 := _bez(a, mid, b, minf(1.0, k + 0.01))
	return [pos, (pos2 - pos).normalized(), k]


func _draw() -> void:
	if cam == null or overlay:
		return
	var s := 1.0 / cam.zoom.x
	var now := _now()
	for f in flights:
		var k := clampf((now - f["t0"]) / f["dur"], 0.0, 1.0)
		var a: Vector2 = f["a"]
		var b: Vector2 = f["b"]
		# biroz egri yo'l (katta aylana kabi)
		var mid := a.lerp(b, 0.5) + (b - a).orthogonal().normalized() * a.distance_to(b) * 0.08
		var pos := _bez(a, mid, b, k)
		var pos2 := _bez(a, mid, b, minf(1.0, k + 0.01))
		var dir := (pos2 - pos).normalized()
		# iz (kondensatsion chiziq)
		var tail := PackedVector2Array()
		for i in 12:
			tail.append(_bez(a, mid, b, maxf(0.0, k - i * 0.012)))
		for i in tail.size() - 1:
			draw_line(tail[i], tail[i + 1], Color(1, 1, 1, 0.35 * (1.0 - i / 12.0)), 2.0 * s)
		var col := Color("#ffffff") if f["mine"] else Color("#c9d3de")
		var sc := 0.9 if f["mine"] else 0.65
		if _tex:
			var sz := 40.0 * sc
			draw_set_transform(pos + Vector2(6, 9) * s, dir.angle(), Vector2(s, s))
			draw_texture_rect(_tex, Rect2(-sz / 2, -sz / 2, sz, sz), false, Color(0, 0, 0, 0.25))
			draw_set_transform(pos, dir.angle(), Vector2(s, s))
			draw_texture_rect(_tex, Rect2(-sz / 2, -sz / 2, sz, sz), false, col)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			continue
		draw_set_transform(pos + Vector2(5, 7) * s, dir.angle(), Vector2(s, s) * sc)
		draw_colored_polygon(_shape(), Color(0, 0, 0, 0.22))
		draw_set_transform(pos, dir.angle(), Vector2(s, s) * sc)
		draw_colored_polygon(_shape(), col)
		draw_polyline(_shape(), Color("#3a4a60"), 1.0)
		if f["mine"]:
			draw_colored_polygon(PackedVector2Array([Vector2(-13, -1), Vector2(-17, -7), Vector2(-15, -1)]), Color("#e8b73a"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _bez(a: Vector2, m: Vector2, b: Vector2, t: float) -> Vector2:
	return a.lerp(m, t).lerp(m.lerp(b, t), t)


func _shape() -> PackedVector2Array:
	return PackedVector2Array([Vector2(18, 0), Vector2(14, -2), Vector2(2, -2), Vector2(-4, -15), Vector2(-7, -15), Vector2(-4, -2),
		Vector2(-13, -2), Vector2(-16, -6), Vector2(-18, -6), Vector2(-16, 0), Vector2(-18, 6), Vector2(-16, 6),
		Vector2(-13, 2), Vector2(-4, 2), Vector2(-7, 15), Vector2(-4, 15), Vector2(2, 2), Vector2(14, 2), Vector2(18, 0)])
