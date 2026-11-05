extends Node2D
## Qo'shin va karvonlarni xaritada chizadi. Harakat kunlar orasida silliq ko'rinadi.

const PLAYER_RING := Color("#e8b73a")
const ENEMY_RING := Color("#e04848")

var cam: Camera2D
var overlay := false     # 3D xarita: faqat yo'llar va harakat chiziqlari chiziladi (modellar 3D da)
var tex_soldier: Texture2D = preload("res://icons/soldier.svg")
var tex_tank: Texture2D = preload("res://icons/tank.svg")
var tex_truck: Texture2D = preload("res://icons/truck.svg")
var font: Font = ThemeDB.fallback_font
var sold_tex := {"p": [], "e": []}
var tank_tex := {}
var bpics := {}
var top := {}
var _rad := {}
const AREA_R := 230.0


func _ready() -> void:
	for t in ["p", "e"]:
		for i in 8:
			var path := "res://pics/sprites/sold_%s_%d.png" % [t, i]
			if ResourceLoader.exists(path):
				sold_tex[t].append(load(path))
		var tp := "res://pics/sprites/tank_%s.png" % t
		if ResourceLoader.exists(tp):
			tank_tex[t] = load(tp)
	for n in ["hq", "politic", "civil", "mine", "military", "lab_civ", "lab_mil", "airbase", "airport", "barracks", "depot", "shipyard", "post"]:
		var bp := "res://pics/buildings/%s.png" % n
		if ResourceLoader.exists(bp):
			bpics[n] = load(bp)
	for n in ["jet", "airliner", "missile"]:
		var tp2 := "res://pics/sprites/top_%s.png" % n
		if ResourceLoader.exists(tp2):
			top[n] = load(tp2)


func prov_radius(id: String) -> float:
	if not _rad.has(id):
		var p: Dictionary = Game.provinces[id]
		var r := Rect2(p["center"], Vector2.ZERO)
		for poly in p["polys"]:
			for v in poly:
				r = r.expand(v)
		_rad[id] = clampf(minf(r.size.x, r.size.y) * 0.33, 8.0, 70.0)
	return _rad[id]


func site_map_pos(id: String, key: String) -> Vector2:
	var p: Dictionary = Game.provinces[id]
	if key.begins_with("post:"):
		return Game.border_point(id, key.substr(5))
	if key.begins_with("b"):
		var uid := int(key.substr(1))
		for b in p["buildings"]:
			if b.get("uid", -1) == uid and b.has("pos"):
				return p["center"] + Vector2(b["pos"][0], b["pos"][1]) / AREA_R * prov_radius(id)
	return p["center"]


func _txt(pos: Vector2, text: String, s: float, col: Color, size := 13) -> void:
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_set_transform(pos - Vector2(tw / 2.0, 0) * s, 0.0, Vector2(s, s))
	draw_string_outline(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color.BLACK)
	draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _pic(tex: Texture2D, center: Vector2, size: float, alpha := 1.0) -> void:
	if tex == null:
		return
	draw_texture_rect(tex, Rect2(center - Vector2(size, size) / 2.0, Vector2(size, size)), false, Color(1, 1, 1, alpha))


func _ring(pos: Vector2, r: float, col: Color, s: float) -> void:
	draw_set_transform(pos, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, r, Color(col.r, col.g, col.b, 0.28))
	draw_arc(Vector2.ZERO, r, 0, TAU, 28, col, 2.2 * s)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_sites(s: float) -> void:
	## Davlat ichidagi binolar o'z joyida (3D modeldan olingan zamonaviy rasmlar), garnizon va chegaralar
	var z := cam.zoom.x
	for id in Game.player_provinces():
		var p: Dictionary = Game.provinces[id]
		var c: Vector2 = p["center"]
		var rad := prov_radius(id)
		var bs := maxf(clampf(rad * 0.45, 8.0, 26.0), 20.0 * s)
		if z >= 0.9:
			# yo'llar: hokimiyatdan har bir binoga
			for b in p["buildings"]:
				if b.has("pos"):
					var bp: Vector2 = c + Vector2(b["pos"][0], b["pos"][1]) / AREA_R * rad
					draw_line(c, bp, Color(0.13, 0.14, 0.16, 0.85), 5.0 * s)
					draw_line(c, bp, Color(0.42, 0.44, 0.47, 0.95), 3.0 * s)
			_pic(bpics.get("hq"), c, bs * 1.15)
			for b in p["buildings"]:
				if not b.has("pos"):
					continue
				var mp: Vector2 = c + Vector2(b["pos"][0], b["pos"][1]) / AREA_R * rad
				_pic(bpics.get(b["type"]), mp, bs, 0.45 if b["days_left"] > 0 else 1.0)
		# garnizon nuqtalari (hokimiyat maydoni, kazarmalar, postlar)
		for st in Game.site_list(p):
			var u := Game.site_units(p, st["key"])
			var tot: float = u["soldier"] + u["tank"]
			var mp2 := site_map_pos(id, st["key"])
			if st["type"] == "post":
				_ring(mp2, 10.0 * s, PLAYER_RING, s)
				_pic(bpics.get("post"), mp2 + Vector2(0, -6) * s, 26.0 * s)
			if tot < 1.0:
				continue
			var gp := mp2 + (Vector2(0, bs * 0.75) if st["type"] == "hq" else Vector2(0, 10.0 * s))
			if z < 0.9 and st["type"] != "hq" and st["type"] != "post":
				continue
			_ring(gp, 9.0 * s, PLAYER_RING, s)
			var tex: Texture2D = tank_tex.get("p") if u["tank"] >= 1.0 and u["soldier"] < 1.0 else (sold_tex["p"][0] if not sold_tex["p"].is_empty() else null)
			_pic(tex, gp + Vector2(0, -7) * s, 24.0 * s)
			var lab := "%d" % roundi(u["soldier"])
			if u["tank"] >= 1.0:
				lab += " | %dT" % roundi(u["tank"])
			_txt(gp + Vector2(0, 14) * s, lab, s, Color("#ffd166"), 12)
		# ochiq (postsiz) chegaralar - bosish mumkin bo'lgan belgilar
		if z >= 1.3 and Game.era >= 4:
			for n in p["neighbors"]:
				if Game.provinces[n]["owner"] != Game.PLAYER and not Game.has_post(id, n, false):
					var bp2 := Game.border_point(id, n)
					draw_set_transform(bp2, PI / 4, Vector2(s, s))
					draw_rect(Rect2(-4, -4, 8, 8), Color(1, 1, 1, 0.75))
					draw_rect(Rect2(-4, -4, 8, 8), Color(0, 0, 0, 0.8), false, 1.2)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# dushman chegara postlari
	for pair in War.hostile_borders():
		var ep := Game.border_point(pair[0], pair[1])
		_ring(ep, 9.0 * s, ENEMY_RING, s)
		_pic(bpics.get("post"), ep + Vector2(0, -6) * s, 22.0 * s, 0.9)


var _hw: Array = []      # avtomagistrallar [a, b]
var _rail: Array = []    # temir yo'llar [a, b]


func _build_network() -> void:
	## Viloyat markazlarini bog'lovchi magistrallar (qo'shni viloyatlar) va temir yo'l (har davlat ichida eng qisqa daraxt)
	var seen := {}
	var by_country := {}
	for id in Game.province_order:
		var p: Dictionary = Game.provinces[id]
		if not by_country.has(p["country"]):
			by_country[p["country"]] = []
		by_country[p["country"]].append(id)
		for n in p["neighbors"]:
			var key: String = id + n if id < n else n + id
			if seen.has(key):
				continue
			seen[key] = true
			var q: Dictionary = Game.provinces[n]
			if p["center"].distance_to(q["center"]) < 420.0:
				_hw.append([p["center"], q["center"]])
	for c in by_country:
		var ids: Array = by_country[c]
		if ids.size() < 2:
			continue
		var inside := {ids[0]: true}
		while inside.size() < ids.size():
			var best := []
			var bd := INF
			for a in inside:
				for b in ids:
					if inside.has(b):
						continue
					var d: float = Game.provinces[a]["center"].distance_to(Game.provinces[b]["center"])
					if d < bd:
						bd = d
						best = [a, b]
			if best.is_empty():
				break
			inside[best[1]] = true
			if bd < 520.0:
				_rail.append([Game.provinces[best[0]]["center"], Game.provinces[best[1]]["center"]])


func _overlay_draw(s: float, f: float) -> void:
	## 3D xarita yer teksturasiga: magistrallar, temir yo'llar, viloyat yo'llari va qo'shin harakat yo'nalishlari
	if _hw.is_empty() and Game.era >= 3:
		_build_network()
	for e in _hw:
		draw_line(e[0], e[1], Color(0.1, 0.1, 0.11, 0.85), 3.6 * s)
		draw_line(e[0], e[1], Color(0.36, 0.37, 0.39, 1.0), 2.2 * s)
	for e in _rail:
		var a: Vector2 = e[0] + Vector2(6, 6)
		var b: Vector2 = e[1] + Vector2(6, 6)
		draw_line(a, b, Color(0.15, 0.12, 0.1, 0.95), 1.8 * s)
		var L := a.distance_to(b)
		var dir := (b - a) / maxf(L, 0.001)
		var t := 0.0
		while t < L:
			var pt := a + dir * t
			draw_line(pt - dir.orthogonal() * 2.0 * s, pt + dir.orthogonal() * 2.0 * s, Color(0.15, 0.12, 0.1, 0.95), 1.0 * s)
			t += 5.0 * s
	for id in Game.player_provinces():
		var p: Dictionary = Game.provinces[id]
		var c: Vector2 = p["center"]
		var rad := prov_radius(id)
		for b in p["buildings"]:
			if b.has("pos"):
				var bp: Vector2 = c + Vector2(b["pos"][0], b["pos"][1]) / AREA_R * rad
				draw_line(c, bp, Color(0.13, 0.14, 0.16, 0.9), 4.0 * s)
				draw_line(c, bp, Color(0.5, 0.5, 0.52, 1.0), 2.4 * s)
		for po in p.get("posts", []):
			var pp := Game.border_point(id, po["to"])
			draw_line(c, pp, Color(0.13, 0.14, 0.16, 0.9), 3.5 * s)
			draw_line(c, pp, Color(0.55, 0.5, 0.42, 1.0), 2.0 * s)
		# postsiz chegaralar - bosiladigan belgilar (faqat zamonaviy davrda; eski xaritada yo'q)
		for n in (p["neighbors"] if Game.era >= 4 else []):
			if Game.provinces[n]["owner"] != Game.PLAYER and not Game.has_post(id, n, false):
				var bp2 := Game.border_point(id, n)
				draw_set_transform(bp2, PI / 4, Vector2(s, s))
				draw_rect(Rect2(-5, -5, 10, 10), Color(1, 1, 1, 1))
				draw_rect(Rect2(-5, -5, 10, 10), Color(0, 0, 0, 1), false, 2.0)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for a in War.armies:
		if a["path"].is_empty():
			continue
		var pts := PackedVector2Array()
		pts.append(a["prev_pos"].lerp(a["pos"], f))
		for id in a["path"]:
			pts.append(Game.provinces[id]["center"])
		var col := PLAYER_RING if a["owner"] == Game.PLAYER else ENEMY_RING
		_dashed(pts, col, 3.0 * s, 9.0 * s)
		draw_circle(pts[pts.size() - 1], 5.0 * s, col)


func border_at(screen: Vector2) -> Array:
	## Ekrandagi nuqta chegara belgisiga tushdimi: [bizning viloyat, qo'shni]
	var vs := get_viewport_rect().size
	for id in Game.player_provinces():
		for n in Game.provinces[id]["neighbors"]:
			if Game.provinces[n]["owner"] == Game.PLAYER:
				continue
			var wp := Game.border_point(id, n)
			var sp := (wp - cam.position) * cam.zoom.x + vs / 2.0
			if sp.distance_to(screen) < 16.0:
				return [id, n]
	return []


func _column(a: Dictionary, head: Vector2, s: float) -> void:
	## Qo'shinni xaritada yurayotgan askar va tanklar qatori qilib chizadi
	var team := "p" if a["owner"] == Game.PLAYER else "e"
	var tcol := PLAYER_RING if team == "p" else ENEMY_RING
	if cam.zoom.x < 0.85 and not sold_tex[team].is_empty():
		# uzoqdan - ixcham belgi
		_ring(head, 14.0 * s, tcol, s)
		var tx: Texture2D = tank_tex.get(team) if a["tanks"] >= 1.0 else sold_tex[team][0]
		_pic(tx, head + Vector2(0, -8) * s, 30.0 * s)
		return
	if sold_tex[team].is_empty():
		var tex0 := tex_tank if a["tanks"] >= 1.0 else tex_soldier
		draw_texture_rect(tex0, Rect2(head - Vector2(16, 16) * s, Vector2(32, 32) * s), false)
		return
	var dir := Vector2.RIGHT
	if not a["path"].is_empty():
		var nxt: Vector2 = Game.provinces[a["path"][0]]["center"]
		if nxt.distance_to(head) > 0.5:
			dir = (nxt - head).normalized()
	elif a["state"] == "fight" and a["owner"] != Game.PLAYER:
		dir = (Game.provinces[a["at"]]["center"] - Game.provinces[a["base"]]["center"]).normalized()
	var moving: bool = a["state"] == "move" and Game.speed > 0
	var fighting: bool = a["state"] == "fight"
	var flip := dir.x < 0.0
	var nt := clampi(roundi(a["tanks"]), 0, 4)
	var ns := clampi(ceili(a["soldiers"] / 25.0), 0, 7) if a["soldiers"] >= 1.0 else 0
	var items: Array = []
	for i in nt:
		items.append("t")
	for i in ns:
		items.append("s")
	var side := dir.orthogonal()
	var back := 0.0
	var ms := Time.get_ticks_msec()
	for i in items.size():
		var it: String = items[i]
		var lat := (8.0 if i % 2 == 0 else -8.0) * s
		var pos: Vector2
		if fighting:
			# jangda - keng saf bo'lib turadi
			pos = head + side * ((i - items.size() / 2.0) * 13.0 * s) - dir * (6.0 * s if it == "s" else 0.0)
		else:
			pos = head - dir * back + side * lat
		back += (26.0 if it == "t" else 13.0) * s
		var w := (40.0 if it == "t" else 24.0) * s
		draw_set_transform(pos + Vector2(0, w * 0.3), 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, w * 0.36, Color(tcol.r, tcol.g, tcol.b, 0.45))
		draw_arc(Vector2.ZERO, w * 0.36, 0, TAU, 20, tcol, 1.6 * s)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var tex: Texture2D
		if it == "t":
			tex = tank_tex.get(team)
			if moving:
				pos.y += sin(ms / 60.0 + i) * 0.6 * s
		else:
			var frame := 0
			if moving or fighting:
				frame = int(ms / 85.0 + i * 3) % sold_tex[team].size()
			tex = sold_tex[team][frame]
		if tex == null:
			continue
		var rect := Rect2(pos - Vector2(w / 2.0, w * 0.62), Vector2(w, w))
		if flip:
			_flipped(tex, rect)
		else:
			draw_texture_rect(tex, rect, false)
		if fighting and randf() < 0.08:
			var mz := pos + Vector2((w * 0.45) * (-1.0 if flip else 1.0), -w * 0.15)
			draw_circle(mz, 3.0 * s, Color(1.0, 0.85, 0.3, 0.9))


func _post(pos: Vector2, s: float, building: bool) -> void:
	## Kichik chegara posti: devor, ikki minora, bayroq
	draw_set_transform(pos, 0.0, Vector2(s, s))
	var a := 0.45 if building else 1.0
	draw_rect(Rect2(-11, -6, 22, 10), Color(0, 0, 0, 0.35 * a))
	draw_rect(Rect2(-10, -8, 20, 9), Color(0.55, 0.5, 0.4, a))
	draw_rect(Rect2(-12, -15, 6, 16), Color(0.45, 0.42, 0.35, a))
	draw_rect(Rect2(6, -15, 6, 16), Color(0.45, 0.42, 0.35, a))
	draw_rect(Rect2(-10, -8, 20, 9), Color(0.1, 0.1, 0.1, a), false, 1.0)
	draw_line(Vector2(0, -8), Vector2(0, -24), Color(0.2, 0.2, 0.2, a), 1.2)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -24), Vector2(9, -21), Vector2(0, -18)]), Color(0.91, 0.72, 0.23, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _flipped(tex: Texture2D, rect: Rect2) -> void:
	draw_texture_rect(tex, Rect2(rect.position + Vector2(rect.size.x, 0), Vector2(-rect.size.x, rect.size.y)), false)


func _process(_d: float) -> void:
	queue_redraw()


func _frac() -> float:
	return clampf(Game._acc / Game.SECONDS_PER_DAY, 0.0, 1.0)


func _draw() -> void:
	if cam == null:
		return
	var s := 1.0 / cam.zoom.x
	var f := _frac()
	if overlay:
		_overlay_draw(s, f)
		return
	_draw_sites(s)
	# yo'llar
	for a in War.armies:
		if a["path"].is_empty():
			continue
		var pts := PackedVector2Array()
		pts.append(a["prev_pos"].lerp(a["pos"], f))
		for id in a["path"]:
			pts.append(Game.provinces[id]["center"])
		var col := PLAYER_RING if a["owner"] == Game.PLAYER else ENEMY_RING
		col.a = 0.75
		_dashed(pts, col, 2.5 * s, 10.0 * s)
		var end: Vector2 = pts[pts.size() - 1]
		draw_circle(end, 5.0 * s, col)
	# karvonlar
	for c in War.convoys:
		var p: Vector2 = c["prev_pos"].lerp(c["pos"], f)
		var sz := 22.0 * s
		draw_texture_rect(tex_truck, Rect2(p - Vector2(sz, sz) / 2.0, Vector2(sz, sz)), false)
	# samolyot va raketalar
	for fl in Tech.flights:
		var fp := Tech.flight_pos(fl)
		if fl["kind"] == "plane" and top.has("jet"):
			var dir: Vector2 = (fl["from"] - fl["to"]) if fl["back"] else (fl["to"] - fl["from"])
			for k in mini(fl["count"], 3):
				var off := dir.normalized().orthogonal() * ((k - (mini(fl["count"], 3) - 1) / 2.0) * 16.0 * s) - dir.normalized() * (absf(k - 1) * 10.0 * s)
				draw_set_transform(fp + off + Vector2(6, 9) * s, dir.angle(), Vector2(s, s))
				draw_texture_rect(top["jet"], Rect2(-18, -18, 36, 36), false, Color(0, 0, 0, 0.3))
				draw_set_transform(fp + off, dir.angle(), Vector2(s, s))
				draw_texture_rect(top["jet"], Rect2(-18, -18, 36, 36), false)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			if fl["count"] > 1:
				_txt(fp + Vector2(0, -22) * s, "x%d" % fl["count"], s, Color.WHITE)
		elif fl["kind"] == "plane":
			var dir2: Vector2 = (fl["from"] - fl["to"]) if fl["back"] else (fl["to"] - fl["from"])
			_plane(fp, dir2.angle(), s, fl["count"])
		else:
			var tr: Array = fl["trail"]
			for i in range(1, tr.size()):
				var k := float(i) / tr.size()
				draw_line(tr[i - 1], tr[i], Color(0.85, 0.85, 0.85, 0.6 * k), (3.0 + 4.0 * (1.0 - k)) * s)
			var prev: Vector2 = tr[tr.size() - 2] if tr.size() >= 2 else fl["from"]
			var ang := (fp - prev).angle()
			var big: bool = fl["kind"] == "nuke"
			if top.has("missile"):
				var L2 := 30.0 if big else 22.0
				draw_set_transform(fp, ang, Vector2(s, s))
				draw_texture_rect(top["missile"], Rect2(-L2, -L2, L2 * 2, L2 * 2), false, Color(1, 0.85, 0.5) if big else Color.WHITE)
				draw_circle(Vector2(-L2 * 0.95, 0), 3.5, Color(1, 0.6, 0.1))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				continue
			draw_set_transform(fp, ang, Vector2(s, s))
			var L := 16.0 if big else 11.0
			draw_rect(Rect2(-L, -2.5, L * 1.6, 5.0), Color("#e8e8e8") if not big else Color("#ffd166"))
			draw_colored_polygon(PackedVector2Array([Vector2(L * 0.6, -2.5), Vector2(L * 0.6 + 6, 0), Vector2(L * 0.6, 2.5)]), Color("#e04848"))
			draw_circle(Vector2(-L - 2, 0), 3.5, Color(1, 0.6, 0.1))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# qo'shinlar
	for a in War.armies:
		var p2: Vector2 = a["prev_pos"].lerp(a["pos"], f)
		if a["state"] == "fight":
			p2 += Vector2(0, -26.0 * s)
		var ring := PLAYER_RING if a["owner"] == Game.PLAYER else ENEMY_RING
		var r := 12.0 * s
		_column(a, p2, s)
		if a["state"] == "stage":
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 250.0)
			draw_arc(p2, (34.0 + 8.0 * pulse) * s, 0, TAU, 40, Color(1, 0.2, 0.2, 0.4 + 0.4 * pulse), 3.0 * s)
		draw_arc(p2, r, 0, TAU, 24, ring, 2.5 * s)
		var txt := str(int(ceil(War.power(a))))
		var fs := int(14)
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * s
		var tp := p2 + Vector2(-tw / 2.0, r + 15.0 * s)
		draw_set_transform(tp, 0.0, Vector2(s, s))
		draw_string_outline(font, Vector2.ZERO, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color.BLACK)
		draw_string(font, Vector2.ZERO, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if a["owner"] == Game.PLAYER:
			# zaxira chizig'i
			var w := 34.0 * s
			var bar := Rect2(p2 + Vector2(-w / 2.0, -r - 9.0 * s), Vector2(w, 4.0 * s))
			draw_rect(bar, Color(0, 0, 0, 0.7))
			var k: float = a["supply"] / 100.0
			var bc := Color("#7bd88f") if k > 0.5 else (Color("#ffd166") if k > 0.25 else Color("#ff6b6b"))
			draw_rect(Rect2(bar.position, Vector2(w * k, bar.size.y)), bc)


func _dashed(pts: PackedVector2Array, col: Color, width: float, dash: float) -> void:
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var len := a.distance_to(b)
		if len < 0.01:
			continue
		var dir := (b - a) / len
		var t := 0.0
		while t < len:
			var e := minf(t + dash, len)
			draw_line(a + dir * t, a + dir * e, col, width)
			t += dash * 2.0


func _plane(pos: Vector2, ang: float, s: float, count: int) -> void:
	draw_set_transform(pos + Vector2(6, 8) * s, ang, Vector2(s, s))
	draw_colored_polygon(_plane_shape(), Color(0, 0, 0, 0.25))
	draw_set_transform(pos, ang, Vector2(s, s))
	draw_colored_polygon(_plane_shape(), Color("#d9e2ec"))
	draw_polyline(_plane_shape(), Color("#2a3550"), 1.2)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if count > 1:
		var txt := "x%d" % count
		draw_set_transform(pos + Vector2(14, -12) * s, 0.0, Vector2(s, s))
		draw_string_outline(font, Vector2.ZERO, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color.BLACK)
		draw_string(font, Vector2.ZERO, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _plane_shape() -> PackedVector2Array:
	return PackedVector2Array([Vector2(16, 0), Vector2(6, -2), Vector2(0, -14), Vector2(-4, -14), Vector2(-2, -3),
		Vector2(-10, -3), Vector2(-14, -8), Vector2(-16, -8), Vector2(-14, 0), Vector2(-16, 8), Vector2(-14, 8),
		Vector2(-10, 3), Vector2(-2, 3), Vector2(-4, 14), Vector2(0, 14), Vector2(6, 2), Vector2(16, 0)])
