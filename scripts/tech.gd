extends Node
## Tadqiqot va havo zarbalari (autoload: Tech)
## Ikki yo'nalish: fuqarolik (iqtisod) va harbiy. Ilmiy markazlar kuniga ball beradi.
## Samolyot va raketalar xaritada uchib boradi; begona havo hududida PVO urib tushirishi mumkin.

signal researched(id: String)

const TECHS := {
	# --- fuqarolik
	"c_auto": {"branch": "civ", "name": "Avtomatlashtirish", "cost": 20, "req": [],
		"desc": "Fuqarolik zavodlari daromadi +30%"},
	"c_build": {"branch": "civ", "name": "Tez qurilish", "cost": 20, "req": [],
		"desc": "Binolar 30% tezroq quriladi"},
	"c_mine": {"branch": "civ", "name": "Chuqur qazish", "cost": 35, "req": ["c_auto"],
		"desc": "Resurslardan daromad +40%"},
	"c_log": {"branch": "civ", "name": "Logistika", "cost": 35, "req": ["c_build"],
		"desc": "Karvonlar 50% tez va 30% arzon, qo'shin zaxirasi sekinroq tugaydi"},
	"c_social": {"branch": "civ", "name": "Ijtimoiy dasturlar", "cost": 50, "req": ["c_auto"],
		"desc": "Barcha provinsiyalarda norozilik -10"},
	"c_bank": {"branch": "civ", "name": "Xalqaro bank", "cost": 60, "req": ["c_mine"],
		"desc": "Savdo daromadi +50%, qarz limiti +50%"},
	# --- harbiy
	"m_inf": {"branch": "mil", "name": "Zamonaviy piyoda", "cost": 20, "req": [],
		"desc": "Askarlaringiz kuchi +25%"},
	"m_armor": {"branch": "mil", "name": "Og'ir tanklar", "cost": 30, "req": ["m_inf"],
		"desc": "Tanklaringiz kuchi +25%"},
	"m_air": {"branch": "mil", "name": "Aviatsiya", "cost": 40, "req": ["m_inf"],
		"desc": "Aerodrom va bombardimonchi samolyotlar ochiladi"},
	"m_aa": {"branch": "mil", "name": "Havo mudofaasi (PVO)", "cost": 35, "req": ["m_air"],
		"desc": "Har bir provinsiyada mahalliy mudofaa +15"},
	"m_rocket": {"branch": "mil", "name": "Raketa texnologiyasi", "cost": 60, "req": ["m_air"],
		"desc": "Ballistik raketalar (harbiy zavodda). Urib tushirib bo'lmaydi"},
	"m_nuke": {"branch": "mil", "name": "Yadro quroli", "cost": 120, "req": ["m_rocket"],
		"desc": "Yadro raketasi: provinsiyani butunlay yakson qiladi. Butun dunyo sizga qarshi chiqadi"},
}

const PLANE_RANGE := 450.0
const MISSILE_RANGE := 900.0
const PLANE_DMG := 14.0
const MISSILE_DMG := 45.0
const FLIGHT_DAYS := {"plane": 1.0, "missile": 0.8, "nuke": 1.2}

var done := {}                          # id -> true
var active := {"civ": "", "mil": ""}    # yo'nalish -> joriy tadqiqot
var progress := {}                      # id -> to'plangan ball
var flights: Array = []                 # havodagi samolyot/raketalar
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	Game.day_passed.connect(_on_day)


# ---------------------------------------------------------------- effektlar

func has(id: String) -> bool:
	return done.has(id)


func mult(kind: String) -> float:
	return _base_mult(kind) * Politics.mult(kind)


func _base_mult(kind: String) -> float:
	match kind:
		"industry": return 1.3 if has("c_auto") else 1.0
		"build_time": return 0.7 if has("c_build") else 1.0
		"resources": return 1.4 if has("c_mine") else 1.0
		"convoy_speed": return 1.5 if has("c_log") else 1.0
		"convoy_cost": return 0.7 if has("c_log") else 1.0
		"supply_drain": return 0.7 if has("c_log") else 1.0
		"trade": return 1.5 if has("c_bank") else 1.0
		"loan": return 1.5 if has("c_bank") else 1.0
		"soldier": return 1.25 if has("m_inf") else 1.0
		"tank": return 1.25 if has("m_armor") else 1.0
	return 1.0


func bonus(kind: String) -> float:
	return _base_bonus(kind) + Politics.bonus(kind)


func _base_bonus(kind: String) -> float:
	match kind:
		"unrest": return 10.0 if has("c_social") else 0.0
		"militia": return 15.0 if has("m_aa") else 0.0
	return 0.0


# ---------------------------------------------------------------- tadqiqot

func points_per_day(branch: String) -> float:
	var n := 0
	var b := "lab_civ" if branch == "civ" else "lab_mil"
	for id in Game.player_provinces():
		n += Game.count_buildings(Game.provinces[id], b)
	return float(n) * Politics.mult("research")


func why_research(id: String) -> String:
	if has(id): return "Tayyor"
	for r in TECHS[id]["req"]:
		if not has(r):
			return "Avval: " + TECHS[r]["name"]
	if active[TECHS[id]["branch"]] == id: return "Tadqiq qilinmoqda"
	return ""


func start(id: String) -> void:
	if why_research(id) != "":
		return
	active[TECHS[id]["branch"]] = id
	if points_per_day(TECHS[id]["branch"]) <= 0.0:
		Game.message.emit("%s tanlandi, lekin ilmiy markaz yo'q - tadqiqot to'xtab turadi." % TECHS[id]["name"], "bad")
	else:
		Game.message.emit("Tadqiqot boshlandi: %s." % TECHS[id]["name"], "info")
	Game.changed.emit()


func days_left(id: String) -> int:
	var pts := points_per_day(TECHS[id]["branch"])
	if pts <= 0.0:
		return -1
	return ceili((TECHS[id]["cost"] - progress.get(id, 0.0)) / pts)


func _on_day(_d: int) -> void:
	for branch in active:
		var id: String = active[branch]
		if id == "":
			continue
		progress[id] = progress.get(id, 0.0) + points_per_day(branch)
		if progress[id] >= TECHS[id]["cost"]:
			done[id] = true
			active[branch] = ""
			Game.message.emit("KASHFIYOT! %s: %s" % [TECHS[id]["name"], TECHS[id]["desc"]], "good")
			researched.emit(id)


# ---------------------------------------------------------------- havo zarbalari

func why_strike(from_id: String, to_id: String, kind: String) -> String:
	var p: Dictionary = Game.provinces[from_id]
	if Game.units_of(p, kind) < 1.0:
		return "Bu provinsiyada %s yo'q" % Game.UNITS[kind]["name"].to_lower()
	var t: Dictionary = Game.provinces[to_id]
	if t["owner"] == Game.PLAYER:
		return "O'z provinsiyangizga zarba berib bo'lmaydi"
	var rng := PLANE_RANGE if kind == "plane" else MISSILE_RANGE
	if p["center"].distance_to(t["center"]) > rng:
		return "Nishon juda uzoq (masofa %d, maksimal %d)" % [int(p["center"].distance_to(t["center"])), int(rng)]
	return ""


func crossed_countries(a: Vector2, b: Vector2, exclude: Array) -> Array:
	## Uchish chizig'i qaysi davlatlar ustidan o'tadi
	var out: Array = []
	var steps := maxi(2, int(a.distance_to(b) / 15.0))
	for i in range(1, steps):
		var id := Game.province_at(a.lerp(b, float(i) / steps))
		if id == "":
			continue
		var o: String = Game.provinces[id]["owner"]
		if o == Game.PLAYER or o == Game.REBEL or exclude.has(o) or out.has(o):
			continue
		out.append(o)
	return out


func launch(from_id: String, to_id: String, kind: String) -> void:
	if why_strike(from_id, to_id, kind) != "":
		Game.message.emit(why_strike(from_id, to_id, kind), "bad")
		return
	if kind == "nuke":
		Diplo.proposal.emit("YADRO ZARBASI: %s\n\nBu provinsiya yakson bo'ladi, aholining katta qismi halok bo'ladi.\nButun dunyo sizga qarshi chiqadi: munosabatlar keskin yomonlashadi va 180 kunlik global sanksiya qo'llanadi.\n\nRostdan ham uchirasizmi?" % Game.provinces[to_id]["name"],
			_do_launch.bind(from_id, to_id, kind), func(): pass)
		return
	_do_launch(from_id, to_id, kind)


func _do_launch(from_id: String, to_id: String, kind: String) -> void:
	var p: Dictionary = Game.provinces[from_id]
	var t: Dictionary = Game.provinces[to_id]
	var count := 1
	if kind == "plane":
		count = int(Game.units_of(p, "plane"))
	p["units"][kind] = Game.units_of(p, kind) - count
	var owner: String = t["owner"]
	var crossed := crossed_countries(p["center"], t["center"], [owner])
	var f := {"kind": kind, "from": p["center"], "to": t["center"], "t": 0.0, "count": count,
		"from_id": from_id, "to_id": to_id, "back": false, "trail": [], "events": []}
	# begona havo hududi: tranzit ruxsati bo'lmasa PVO otadi
	for c in crossed:
		if Diplo.transit.has(c) or Diplo.alliance.has(c):
			continue
		Diplo.change_rel(c, -6)
		var lost := 0
		if kind == "plane":
			for i in f["count"]:
				if _rng.randf() < 0.3:
					lost += 1
		f["events"].append({"at": _rng.randf_range(0.2, 0.45), "country": c, "lost": lost, "fired": false})
	flights.append(f)
	var what := "%d ta bombardimonchi" % count if kind == "plane" else ("Raketa" if kind == "missile" else "YADRO RAKETASI")
	Game.message.emit("%s %s ga uchirildi!" % [what, t["name"]], "event" if kind != "nuke" else "bad")
	Game.changed.emit()


func _process(delta: float) -> void:
	if flights.is_empty() or Game.speed == 0:
		return
	var step := delta * Game.speed / Game.SECONDS_PER_DAY
	for f in flights.duplicate():
		f["t"] += step / FLIGHT_DAYS[f["kind"]]
		var pos := flight_pos(f)
		if f["kind"] != "plane":
			f["trail"].append(pos)
			if f["trail"].size() > 40:
				f["trail"].pop_front()
		for ev in f["events"]:
			if not ev["fired"] and not f["back"] and f["t"] >= ev["at"]:
				ev["fired"] = true
				if ev["lost"] > 0:
					f["count"] -= ev["lost"]
					War.explosion.emit(pos, false)
					Game.message.emit("%s havo mudofaasi %d ta samolyotingizni urib tushirdi! (tranzit ruxsati yo'q)" % [War.country_name(ev["country"]), ev["lost"]], "bad")
				else:
					Game.message.emit("%s havo hududini buzdingiz - munosabat yomonlashdi." % War.country_name(ev["country"]), "info")
				if f["count"] <= 0:
					flights.erase(f)
					break
		if not flights.has(f):
			continue
		if f["t"] >= 1.0:
			if f["back"]:
				var home: Dictionary = Game.provinces[f["from_id"]]
				if home["owner"] == Game.PLAYER:
					home["units"]["plane"] = Game.units_of(home, "plane") + f["count"]
				else:
					Game.message.emit("Samolyotlar qaytadigan aerodrom yo'q - ular yo'qotildi.", "bad")
				flights.erase(f)
				Game.changed.emit()
				continue
			_impact(f)
			if f["kind"] == "plane" and f["count"] > 0:
				f["back"] = true
				f["t"] = 0.0
			else:
				flights.erase(f)


func flight_pos(f: Dictionary) -> Vector2:
	var a: Vector2 = f["to"] if f["back"] else f["from"]
	var b: Vector2 = f["from"] if f["back"] else f["to"]
	var k: float = clampf(f["t"], 0.0, 1.0)
	var pos := a.lerp(b, k)
	if f["kind"] != "plane":
		# raketa yoy bo'ylab uchadi
		var n := (b - a).orthogonal().normalized()
		pos += n * sin(k * PI) * a.distance_to(b) * 0.15
	return pos


func _impact(f: Dictionary) -> void:
	var id: String = f["to_id"]
	var t: Dictionary = Game.provinces[id]
	var c: Vector2 = t["center"]
	match f["kind"]:
		"plane":
			var shot := 0
			var aa := 0.03 if t["owner"] == Game.REBEL else (0.18 if t["owner"] == "CHN" else 0.08)
			for i in f["count"]:
				if _rng.randf() < aa:
					shot += 1
			f["count"] -= shot
			var dmg: float = PLANE_DMG * (f["count"] + shot * 0.5)
			t["defense"] = maxf(0.0, t["defense"] - dmg)
			_hit_armies(id, dmg * 0.5)
			for i in mini(6, 2 + f["count"]):
				War.explosion.emit(c + Vector2(_rng.randf_range(-30, 30), _rng.randf_range(-20, 20)), i % 2 == 0)
			var txt := "Bombardimon: %s mudofaasi -%d." % [t["name"], int(dmg)]
			if shot > 0:
				txt += " Dushman PVO %d samolyotni urib tushirdi." % shot
			Game.message.emit(txt, "good")
		"missile":
			t["defense"] = maxf(0.0, t["defense"] - MISSILE_DMG)
			_hit_armies(id, MISSILE_DMG * 0.6)
			for i in 3:
				War.explosion.emit(c + Vector2(_rng.randf_range(-15, 15), _rng.randf_range(-10, 10)), true)
			Game.message.emit("Raketa nishonga tegdi: %s mudofaasi -%d." % [t["name"], int(MISSILE_DMG)], "good")
		"nuke":
			t["defense"] = 0.0
			t["max_defense"] = roundf(t["max_defense"] * 0.5)
			t["population"] = int(t["population"] * 0.6)
			for a in War.armies.duplicate():
				if a["at"] == id:
					War.armies.erase(a)
			for i in 14:
				var r := _rng.randf_range(0, 60)
				War.explosion.emit(c + Vector2.from_angle(_rng.randf() * TAU) * r, true)
			War.nuke_flash.emit(c)
			for o in Diplo.rel:
				Diplo.change_rel(o, -60)
			Diplo.impose_sanctions_days(180, "Yadro qurolidan foydalanganingiz uchun BMT")
			Game.message.emit("YADRO PORTLASHI! %s yakson qilindi. Dunyo sizni qoraladi." % t["name"], "bad")
	Game.changed.emit()


func _hit_armies(id: String, dmg: float) -> void:
	for a in War.armies.duplicate():
		if a["at"] == id and a["owner"] != Game.PLAYER:
			War._take_losses(a, dmg)
			if War.power(a) < 0.5:
				War.armies.erase(a)


# ---------------------------------------------------------------- saqlash

func to_dict() -> Dictionary:
	return {"done": done.keys(), "active": active, "progress": progress}


func from_dict(d: Dictionary) -> void:
	flights.clear()
	done = {}
	for id in d.get("done", []):
		done[id] = true
	var a: Dictionary = d.get("active", {})
	active = {"civ": a.get("civ", ""), "mil": a.get("mil", "")}
	progress = {}
	var pr: Dictionary = d.get("progress", {})
	for id in pr:
		progress[id] = float(pr[id])
