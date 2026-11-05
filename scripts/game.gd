extends Node
## O'yinning asosiy holati va mantig'i (autoload: Game)
## Iqtisodiyot, vaqt, binolar, buyurtmalar, norozilik va tasodifiy voqealar shu yerda.

signal changed                       # holat o'zgardi -> UI yangilansin
signal day_passed(day: int)
signal message(text: String, kind: String)   # kind: info / good / bad / event
signal selected(id: String)
signal open_province(id: String)        # viloyat 3D bazasini ochish
signal open_border(id: String, nb: String)  # chegara oynasi
signal units_moved(id: String, from_key: String, to_key: String, soldiers: int, tanks: int)
signal units_produced(id: String, unit: String, site: String)

const PLAYER := "PLAYER"
const REBEL := "REBEL"
const SECONDS_PER_DAY := 2.0         # 1x tezlikda 1 kun = 2 soniya
const START_MONEY := 1500.0
const MAX_BUILDINGS := 14

const BUILDINGS := {
	"civil": {"name": "Fuqarolik zavodi", "cost": 500, "days": 10, "icon": "res://pics/buildings/civil.png",
		"income": 40.0, "jobs": 2000, "desc": "Har kuni daromad beradi va ish o'rinlari yaratadi"},
	"mine": {"name": "Kon / neft bazasi", "cost": 400, "days": 8, "icon": "res://pics/buildings/mine.png",
		"income": 0.0, "jobs": 1000, "desc": "Provinsiya resurslarini qazib sotadi"},
	"military": {"name": "Harbiy zavod", "cost": 800, "days": 15, "icon": "res://pics/buildings/military.png",
		"income": -15.0, "jobs": 1500, "desc": "Askar, tank va raketalar ishlab chiqaradi"},
	"lab_civ": {"name": "Fuqarolik ilmiy markazi", "cost": 900, "days": 20, "icon": "res://pics/buildings/lab_civ.png",
		"income": -10.0, "jobs": 800, "desc": "Iqtisodiy texnologiyalar uchun kuniga 1 ilmiy ball"},
	"lab_mil": {"name": "Harbiy ilmiy markaz", "cost": 1000, "days": 20, "icon": "res://pics/buildings/lab_mil.png",
		"income": -15.0, "jobs": 800, "desc": "Harbiy texnologiyalar uchun kuniga 1 ilmiy ball"},
	"politic": {"name": "Siyosiy markaz", "cost": 700, "days": 8, "icon": "res://pics/buildings/politic.png",
		"income": -10.0, "jobs": 600, "desc": "Davlatda bitta bo'ladi: mafkura, litsenziyalar, qora bozor, eksport, razvedka"},
	"barracks": {"name": "Kazarma", "cost": 600, "days": 8, "icon": "res://pics/buildings/barracks.png",
		"income": -8.0, "jobs": 500, "desc": "Askarlar maskani: viloyat mudofaasi (militsiya) +15, askar tayyorlash 30% tez"},
	"depot": {"name": "Tank parki", "cost": 700, "days": 10, "icon": "res://pics/buildings/depot.png",
		"income": -6.0, "jobs": 400, "desc": "Tanklar saqlanadigan joy: tank xarajati 40% kam, tank yasash 30% tez"},
	"airport": {"name": "Fuqarolik aeroporti", "cost": 1500, "days": 18, "icon": "res://pics/buildings/airport.png",
		"income": 35.0, "jobs": 1800, "desc": "Yo'lovchi reyslari: daromad, barcha davlatlar bilan munosabat asta yaxshilanadi"},
	"shipyard": {"name": "Kema zavodi", "cost": 1400, "days": 20, "icon": "res://pics/buildings/shipyard.png",
		"income": 10.0, "jobs": 1600, "desc": "Faqat dengiz/ko'l bo'yidagi viloyatda. Patrul kemalari va yuk tashish", "coast": true},
	"airbase": {"name": "Aerodrom", "cost": 1200, "days": 20, "icon": "res://pics/buildings/airbase.png",
		"income": -20.0, "jobs": 1000, "desc": "Bombardimonchi samolyotlar ishlab chiqaradi", "tech": "m_air"},
}

const UNITS := {
	"soldier": {"name": "O'qotar askar", "batch": 10, "cost": 100, "days": 3, "icon": "res://icons/soldier.svg", "upkeep": 0.3},
	"guard": {"name": "Chegarachi", "batch": 10, "cost": 130, "days": 4, "icon": "res://icons/soldier.svg", "upkeep": 0.3,
		"adds": "soldier", "fort": 4.0},
	"para": {"name": "Desantchi", "batch": 10, "cost": 220, "days": 5, "icon": "res://icons/soldier.svg", "upkeep": 0.3,
		"adds": "soldier", "mult": 1.6, "tech": "m_air"},
	"tank": {"name": "Tank", "batch": 1, "cost": 300, "days": 7, "icon": "res://icons/tank.svg", "upkeep": 3.0},
	"plane": {"name": "Bombardimonchi", "batch": 1, "cost": 600, "days": 10, "icon": "res://icons/plane.svg",
		"upkeep": 4.0, "building": "airbase", "tech": "m_air"},
	"missile": {"name": "Raketa", "batch": 1, "cost": 900, "days": 12, "icon": "res://icons/missile.svg",
		"upkeep": 0.5, "tech": "m_rocket"},
	"nuke": {"name": "Yadro raketasi", "batch": 1, "cost": 6000, "days": 40, "icon": "res://icons/nuke.svg",
		"upkeep": 5.0, "tech": "m_nuke"},
}

const COASTAL := ["Balkan", "Mangystau", "Atyrau", "Qoraqalpog'iston"]   # Kaspiy / Orol bo'yi

const RESOURCE_NAMES := {"neft": "Neft", "tilla": "Tilla", "temir": "Temir", "paxta": "Paxta",
	"bugdoy": "Bug'doy", "mis": "Mis", "komir": "Ko'mir", "gaz": "Gaz"}
const RESOURCE_PRICE := {"neft": 12.0, "tilla": 15.0, "temir": 8.0, "paxta": 6.0,
	"bugdoy": 5.0, "mis": 9.0, "komir": 6.0, "gaz": 10.0}

var countries := {}
var provinces := {}          # id -> Dictionary
var province_order: Array = []
var started := false
var game_over := false
var day := 0
var next_uid := 1
var start_unix := 1793491200   # 2026-11-01; yangi o'yinda real bugungi sana olinadi
var money := START_MONEY
var speed := 1               # 0 = pauza
var selected_id := ""
var price_mult := {}
var stock := {}              # resurs zaxirasi (sotilmagan qism)
var goods := {"oziq": 300.0, "yogoch": 300.0, "tosh": 400.0}
var spies := 0               # 1-2-zamon: josuslar soni (dushman hujumi va qal'alari haqida ma'lumot)   # 1-2-zamon resurslari (oltin = money)
var sell_share := {}         # resurs -> avtomatik sotish ulushi (0..1)
const RESOURCE_UNIT := {"neft": "ming barrel", "gaz": "mln m3", "tilla": "kg", "temir": "ming t",
	"paxta": "ming t", "bugdoy": "ming t", "mis": "t", "komir": "ming t"}         # resurs -> {mult, days}
var next_event_day := 25
var _acc := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_load_world()
	Unit3D.load_flag_file.call_deferred()


## 1 - Amir Temur davri (1400), 2 - 1850-1880, 4 - zamonaviy (keyinga qoldirilgan)
var era := 1
const WORLD_FILES := {1: "res://data/world_1400.json", 2: "res://data/world_1865.json", 4: "res://data/world.json"}
const ERA_NAMES := {1: "1-zamon: Amir Temur davri (1400)", 2: "2-zamon: O'rta Osiyo xonliklari (1865)", 4: "Zamonaviy davr"}
var pending_load := false     # menyudan "yuklash" - asosiy sahna ochilgach saqlangan o'yin yuklanadi
var story := ""               # tanlangan tarixiy sujet (bo'sh - erkin o'yin)


func set_era(n: int) -> void:
	## zamonni almashtiradi: dunyo xaritasi, davlatlar va barcha holat yangidan yuklanadi
	era = n
	countries = {}
	provinces.clear()
	province_order.clear()
	started = false
	game_over = false
	day = 0
	money = START_MONEY
	goods = {"oziq": 300.0, "yogoch": 300.0, "tosh": 400.0}
	spies = 0
	story = ""
	start_unix = 0 if n < 4 else start_unix
	Story.active = ""
	Story.state = {}
	_load_world()
	War.init_world()
	Diplo.init_world()
var world_year := 2026


func _load_world() -> void:
	var f := FileAccess.open(WORLD_FILES.get(era, "res://data/world_1400.json"), FileAccess.READ)
	if f == null:
		push_error("world.json topilmadi")
		return
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	countries = data["countries"]
	world_year = int(data.get("year", 2026))
	for p in data["provinces"]:
		var polys: Array = []
		for ring in p["polys"]:
			var pts := PackedVector2Array()
			for xy in ring:
				pts.append(Vector2(xy[0], xy[1]))
			polys.append(pts)
		var prov := {
			"id": p["id"], "name": p["name"], "country": p["country"],
			"center": Vector2(p["center"][0], p["center"][1]),
			"polys": polys, "population": int(p["population"]),
			"resources": p["resources"], "neighbors": p["neighbors"],
			"owner": p["country"], "buildings": [], "orders": [],
			"unrest": 20.0, "units": {"soldier": 0, "tank": 0},
			"mount": float(p.get("mount", -1.0)),
		}
		provinces[prov["id"]] = prov
		province_order.append(prov["id"])


# ---------------------------------------------------------------- vaqt

func _process(delta: float) -> void:
	if not started or game_over or speed == 0:
		return
	_acc += delta * speed
	while _acc >= SECONDS_PER_DAY:
		_acc -= SECONDS_PER_DAY
		_next_day()


func set_speed(s: int) -> void:
	speed = s
	changed.emit()


func _next_day() -> void:
	day += 1
	var total := 0.0
	for id in player_provinces():
		var p: Dictionary = provinces[id]
		total += province_income(p)["total"]
		_progress_buildings(p)
		_progress_orders(p)
		if era < 4:
			CastleEco.daily(p)
		for po in p.get("posts", []):
			if po["days_left"] > 0:
				po["days_left"] -= 1
				if po["days_left"] == 0:
					message.emit("%s: %s chegarasidagi post qurib bitkazildi." % [p["name"], provinces[po["to"]]["name"]], "good")
	money += total
	if era < 4:
		money -= spies * SiegeCastle.SPY_PAY
		if day % 30 == 0:
			SiegeCastle.grow()
	_stockpile()
	for id in player_provinces():
		_update_unrest(provinces[id])
	_tick_prices()
	if day % 30 == 0:
		_income_advice()
	if day >= next_event_day:
		_random_event()
		next_event_day = day + _rng.randi_range(20, 40)
	day_passed.emit(day)
	changed.emit()


func _income_advice() -> void:
	## Daromad juda kam bo'lsa - sababini va yechimini aytadi
	var inc := total_income()
	if inc >= 40.0 or player_provinces().is_empty():
		return
	var army: float = War.army_upkeep()
	var upk := 0.0
	var jobs_short := 0
	for id in player_provinces():
		var p: Dictionary = provinces[id]
		upk += province_income(p)["upkeep"]
		if jobs(p) < jobs_needed(p):
			jobs_short += 1
	var tips: Array = []
	if upk + army > 60.0:
		tips.append("armiya va binolar xarajati kuniga %d $ - ortiqcha qo'shinni kamaytiring yoki zavod quring" % int(upk + army))
	if jobs_short > 0:
		tips.append("%d ta viloyatda ish o'rni yetmaydi - Fuqarolik zavodi quring (+40 $/kun)" % jobs_short)
	if Diplo.trade.is_empty():
		tips.append("hech kim bilan savdo shartnomasi yo'q - Diplomatiya oynasidan savdo qiling")
	if War.wars.size() > 0:
		tips.append("urush holati savdoni to'xtatadi - sulh imkonini ko'ring")
	if tips.is_empty():
		tips.append("Kon / neft bazasi quring va Byudjet oynasida resurslarni soting")
	message.emit("MASLAHAT (daromad %+d $/kun): %s." % [int(inc), "; ".join(tips)], "event")


func date_text() -> String:
	## O'yin real bugungi sanadan boshlanadi (1 o'yin kuni = 1 kalendar kun)
	var months := ["Yanvar", "Fevral", "Mart", "Aprel", "May", "Iyun", "Iyul",
		"Avgust", "Sentabr", "Oktabr", "Noyabr", "Dekabr"]
	var dt := Time.get_datetime_dict_from_unix_time(start_unix + day * 86400)
	var y: int = dt["year"] if era >= 4 else world_year + int(dt["year"]) - 1970
	return "%d-%s, %d" % [dt["day"], months[dt["month"] - 1], y]


# ---------------------------------------------------------------- iqtisodiyot

func player_provinces() -> Array:
	var out: Array = []
	for id in province_order:
		if provinces[id]["owner"] == PLAYER:
			out.append(id)
	return out


func resource_price(res: String) -> float:
	var base: float = RESOURCE_PRICE.get(res, 5.0)
	if price_mult.has(res):
		base *= price_mult[res]["mult"]
	if Diplo.sanctioned():
		base *= 0.5
	return base


func province_income(p: Dictionary) -> Dictionary:
	var tax: float = p["population"] * 0.01
	var industry := 0.0
	var resources := 0.0
	var upkeep := 0.0
	for b in p["buildings"]:
		if b["days_left"] > 0:
			continue
		var def: Dictionary = BUILDINGS[b["type"]]
		if def["income"] >= 0:
			industry += def["income"]
		else:
			upkeep -= def["income"]
		if b["type"] == "mine":
			for r in p["resources"]:
				resources += p["resources"][r] * resource_price(r) * sell_share.get(r, 0.8)
	industry *= Tech.mult("industry")
	resources *= Tech.mult("resources")
	var pm := Politics.mult("income")
	tax *= pm
	industry *= pm
	resources *= pm
	if era < 4:
		# 1-2-zamon: xo'jalik binolari tushumi, askarlar maoshi qal'a qo'shinidan
		var g := CastleEco.gold(p)
		industry += g["prod"]
		tax *= 1.0 - p["unrest"] / 200.0
		return {"tax": tax, "industry": industry, "resources": 0.0, "upkeep": g["pay"], "total": tax + industry - g["pay"]}
	for u in p["units"]:
		var uk: float = p["units"][u] * UNITS[u]["upkeep"]
		if u == "tank" and count_buildings(p, "depot") > 0:
			uk *= 0.6
		upkeep += uk
	# norozilik yuqori bo'lsa soliq yig'ish qiyinlashadi
	tax *= 1.0 - p["unrest"] / 200.0
	return {"tax": tax, "industry": industry, "resources": resources,
		"upkeep": upkeep, "total": tax + industry + resources - upkeep}


# ---------------------------------------------------------------- qo'shin joylashuvi (garnizon nuqtalari)
## p["sites"]: kalit -> {"soldier": n, "tank": m}. "hq" - qolgan hamma (hokimiyat maydoni).
## kalitlar: "b<uid>" (kazarma / tank parki), "post:<qo'shni id>" (chegara posti)

func site_list(p: Dictionary) -> Array:
	var out: Array = [{"key": "hq", "name": "Hokimiyat maydoni", "type": "hq"}]
	var nb := 0
	var nd := 0
	for b in p["buildings"]:
		if b["days_left"] > 0 or not b.has("uid"):
			continue
		if b["type"] == "barracks":
			nb += 1
			out.append({"key": "b%d" % b["uid"], "name": "Kazarma #%d" % nb, "type": "barracks", "b": b})
		elif b["type"] == "depot":
			nd += 1
			out.append({"key": "b%d" % b["uid"], "name": "Tank parki #%d" % nd, "type": "depot", "b": b})
	for po in p.get("posts", []):
		if po["days_left"] <= 0:
			out.append({"key": "post:" + po["to"], "name": "Chegara: " + provinces[po["to"]]["name"], "type": "post", "to": po["to"]})
	return out


func normalize_sites(p: Dictionary) -> void:
	if not p.has("sites"):
		p["sites"] = {}
	var valid := {}
	for s in site_list(p):
		valid[s["key"]] = true
	for k in p["sites"].keys():
		if not valid.has(k):
			p["sites"].erase(k)
	for u in ["soldier", "tank"]:
		var sum := 0.0
		for k in p["sites"]:
			sum += float(p["sites"][k].get(u, 0.0))
		var tot: float = p["units"].get(u, 0.0)
		if sum > tot and sum > 0.0:
			var f := tot / sum
			for k in p["sites"]:
				p["sites"][k][u] = float(p["sites"][k].get(u, 0.0)) * f


func site_units(p: Dictionary, key: String) -> Dictionary:
	normalize_sites(p)
	if key == "hq":
		var s := float(p["units"].get("soldier", 0.0))
		var t := float(p["units"].get("tank", 0.0))
		for k in p["sites"]:
			s -= float(p["sites"][k].get("soldier", 0.0))
			t -= float(p["sites"][k].get("tank", 0.0))
		return {"soldier": maxf(0.0, s), "tank": maxf(0.0, t)}
	var d: Dictionary = p["sites"].get(key, {})
	return {"soldier": float(d.get("soldier", 0.0)), "tank": float(d.get("tank", 0.0))}


func _site_add(p: Dictionary, key: String, u: String, n: float) -> void:
	if key == "hq":
		return
	if not p.has("sites"):
		p["sites"] = {}
	if not p["sites"].has(key):
		p["sites"][key] = {"soldier": 0.0, "tank": 0.0}
	p["sites"][key][u] = maxf(0.0, float(p["sites"][key].get(u, 0.0)) + n)


func home_site(p: Dictionary, u: String) -> String:
	## Yangi qo'shin boradigan joy: askar - kazarmaga, tank - tank parkiga
	var want := "barracks" if u == "soldier" else "depot"
	for s in site_list(p):
		if s["type"] == want:
			return s["key"]
	return "hq"


func move_units(id: String, from_key: String, to_key: String, soldiers: int, tanks: int) -> void:
	var p: Dictionary = provinces[id]
	var have := site_units(p, from_key)
	var s := mini(soldiers, int(have["soldier"]))
	var t := mini(tanks, int(have["tank"]))
	if s + t <= 0 or from_key == to_key:
		return
	_site_add(p, from_key, "soldier", -s)
	_site_add(p, from_key, "tank", -t)
	_site_add(p, to_key, "soldier", s)
	_site_add(p, to_key, "tank", t)
	units_moved.emit(id, from_key, to_key, s, t)
	message.emit("%s: %d askar, %d tank %s ga yo'l oldi." % [p["name"], s, t, site_name(p, to_key)], "info")
	changed.emit()


func gather_to(id: String, key: String, soldiers: int, tanks: int) -> void:
	## Viloyatdagi boshqa nuqtalardan (avval hokimiyat maydoni, keyin kazarmalar) qo'shinni bitta nuqtaga yig'adi
	var p: Dictionary = provinces[id]
	var need := {"soldier": soldiers, "tank": tanks}
	var order: Array = ["hq"]
	for st in site_list(p):
		if st["key"] != "hq" and st["key"] != key and not String(st["key"]).begins_with("post:"):
			order.append(st["key"])
	for st in site_list(p):
		if String(st["key"]).begins_with("post:") and st["key"] != key:
			order.append(st["key"])
	var moved_s := 0
	var moved_t := 0
	for src in order:
		var have := site_units(p, src)
		var s := mini(need["soldier"], int(have["soldier"]))
		var t := mini(need["tank"], int(have["tank"]))
		if s + t <= 0:
			continue
		_site_add(p, src, "soldier", -s)
		_site_add(p, src, "tank", -t)
		_site_add(p, key, "soldier", s)
		_site_add(p, key, "tank", t)
		need["soldier"] -= s
		need["tank"] -= t
		moved_s += s
		moved_t += t
		units_moved.emit(id, src, key, s, t)
	if moved_s + moved_t > 0:
		message.emit("%s: %d askar, %d tank %s ga jo'natildi." % [p["name"], moved_s, moved_t, site_name(p, key)], "info")
	changed.emit()


func site_name(p: Dictionary, key: String) -> String:
	for s in site_list(p):
		if s["key"] == key:
			return s["name"]
	return key


func take_units(p: Dictionary, key: String, soldiers: float, tanks: float) -> void:
	## Qo'shin viloyatdan chiqib ketganda (jo'natish) shu nuqtadan ayiriladi
	_site_add(p, key, "soldier", -soldiers)
	_site_add(p, key, "tank", -tanks)


# ---------------------------------------------------------------- chegara postlari

const POST_COST := 300
const POST_DAYS := 5
var _border_cache := {}


func has_post(id: String, toward: String, done_only := true) -> bool:
	for po in provinces[id].get("posts", []):
		if po["to"] == toward and (po["days_left"] <= 0 or not done_only):
			return true
	return false


func posts_done(p: Dictionary) -> int:
	var n := 0
	for po in p.get("posts", []):
		if po["days_left"] <= 0:
			n += 1
	return n


func can_post(id: String, nb: String) -> String:
	var p: Dictionary = provinces[id]
	if p["owner"] != PLAYER: return "Viloyat sizniki emas"
	if provinces[nb]["owner"] == PLAYER: return "Ichki chegara"
	if has_post(id, nb, false): return "Post bor"
	if money < POST_COST: return "Pul yetmaydi"
	return ""


func build_post(id: String, nb: String) -> void:
	if can_post(id, nb) != "":
		return
	money -= POST_COST
	var p: Dictionary = provinces[id]
	if not p.has("posts"):
		p["posts"] = []
	p["posts"].append({"to": nb, "days_left": POST_DAYS})
	message.emit("%s: %s chegarasida post qurilmoqda (%d kun)." % [p["name"], provinces[nb]["name"], POST_DAYS], "info")
	changed.emit()


func border_point(id: String, nb: String) -> Vector2:
	## Ikki viloyat umumiy chegarasining o'rtasi (taxminan)
	var key := id + ">" + nb
	if _border_cache.has(key):
		return _border_cache[key]
	var sum := Vector2.ZERO
	var n := 0
	var other: Array = []
	for poly in provinces[nb]["polys"]:
		for v in poly:
			other.append(v)
	for poly in provinces[id]["polys"]:
		for v in poly:
			for w in other:
				if v.distance_squared_to(w) < 4.0:
					sum += v
					n += 1
					break
	var pt: Vector2 = provinces[id]["center"].lerp(provinces[nb]["center"], 0.5)
	if n > 0:
		pt = sum / n
		# chiziqdan biroz o'z tomonimizga
		pt = pt.lerp(provinces[id]["center"], 0.12)
	_border_cache[key] = pt
	return pt


func output(p: Dictionary) -> Dictionary:
	## Provinsiya konlari bir kunda qazib oladigan resurs miqdori
	var out := {}
	var mines := count_buildings(p, "mine")
	if mines == 0:
		return out
	for r in p["resources"]:
		out[r] = float(p["resources"][r]) * mines * Tech.mult("resources")
	return out


func _stockpile() -> void:
	for id in player_provinces():
		var o := output(provinces[id])
		for r in o:
			stock[r] = stock.get(r, 0.0) + o[r] * (1.0 - sell_share.get(r, 0.8))


func national_output() -> Dictionary:
	var t := {}
	for id in player_provinces():
		var o := output(provinces[id])
		for r in o:
			t[r] = t.get(r, 0.0) + o[r]
	return t


func sell_stock(r: String, frac: float) -> void:
	var amt: float = stock.get(r, 0.0) * frac
	if amt <= 0.0:
		return
	stock[r] -= amt
	var got := amt * resource_price(r)
	money += got
	message.emit("Zaxiradan %d %s %s sotildi: +%d $." % [int(amt), RESOURCE_UNIT[r], RESOURCE_NAMES[r], int(got)], "good")
	changed.emit()


func set_share(r: String, v: float) -> void:
	sell_share[r] = v
	changed.emit()


func total_income() -> float:
	var t := 0.0
	for id in player_provinces():
		t += province_income(provinces[id])["total"]
	return t - War.army_upkeep() + Diplo.trade_income() + Politics.contract_income() \
		- Politics.counter_intel * Politics.COUNTER_INTEL_UPKEEP - Politics.ops.size() * Politics.OP_DAILY


func total_units() -> Dictionary:
	var out := {"soldier": 0, "tank": 0}
	for id in player_provinces():
		for u in out:
			out[u] += provinces[id]["units"][u]
	return out


func garrison_power_of(p: Dictionary) -> float:
	return p["units"]["soldier"] + p["units"]["tank"] * 8.0


func jobs(p: Dictionary) -> int:
	var j := 0
	for b in p["buildings"]:
		if b["days_left"] <= 0:
			j += BUILDINGS[b["type"]]["jobs"]
	return j


func jobs_needed(p: Dictionary) -> int:
	return 1500 + int(p["population"] * 0.4)


func _update_unrest(p: Dictionary) -> void:
	var r := clampf(float(jobs(p)) / jobs_needed(p), 0.0, 1.0)
	var target := 10.0 + 45.0 * (1.0 - r) - Tech.bonus("unrest")
	# masjid xalqni tinchlantiradi
	for b in p.get("castle", {}).get("buildings", []):
		if b.get("t", "") == "mosque":
			target -= 15.0
			break
	if money < 0:
		target += 40.0
	var old: float = p["unrest"]
	p["unrest"] = clampf(move_toward(old, target, 0.5), 0.0, 100.0)
	if old < 80.0 and p["unrest"] >= 80.0:
		message.emit("%s: norozilik 80%% ga yetdi! Ish o'rni yarating yoki byudjetni tiklang." % p["name"], "bad")
	if p["unrest"] >= 100.0:
		_rebellion(p)


func _rebellion(p: Dictionary) -> void:
	p["owner"] = REBEL
	p["orders"].clear()
	p["unrest"] = 100.0
	p["defense"] = p["max_defense"] * 0.5 + garrison_power_of(p)
	p["units"] = {"soldier": 0, "tank": 0}
	p["sites"] = {}
	p["posts"] = []
	message.emit("ISYON! %s mustaqillik e'lon qildi. Zavodlar va qo'shin yo'qotildi." % p["name"], "bad")
	if player_provinces().is_empty():
		game_over = true
		message.emit("Sizda provinsiya qolmadi. O'yin tugadi.", "bad")


# ---------------------------------------------------------------- qurilish

func can_build(id: String, type: String) -> String:
	## Bo'sh satr = qurish mumkin, aks holda sabab
	var p: Dictionary = provinces[id]
	if p["owner"] != PLAYER:
		return "Bu provinsiya sizniki emas"
	if p["buildings"].size() >= MAX_BUILDINGS:
		return "Joy qolmadi (max %d)" % MAX_BUILDINGS
	if BUILDINGS[type].get("coast", false) and not (p["name"] in COASTAL):
		return "Faqat dengiz bo'yidagi viloyatda (Kaspiy / Orol)"
	if type == "politic" and Politics.center_planned():
		return "Siyosiy markaz davlatda faqat bitta bo'ladi"
	var t: String = BUILDINGS[type].get("tech", "")
	if t != "" and not Tech.has(t):
		return "Tadqiqot kerak: " + Tech.TECHS[t]["name"]
	if money < BUILDINGS[type]["cost"]:
		return "Pul yetmaydi"
	return ""


const FOOT := {"civil": 24.0, "mine": 21.0, "military": 27.0, "lab_civ": 16.0, "lab_mil": 18.0,
	"airbase": 56.0, "airport": 56.0, "barracks": 23.0, "depot": 24.0, "shipyard": 26.0, "politic": 16.0}


func auto_pos(p: Dictionary, type: String) -> Vector2:
	## Bino uchun hokimiyat atrofida bo'sh joy (viloyat bazasi koordinatalari, metr)
	var r: float = FOOT.get(type, 22.0)
	var seed_i: int = p["buildings"].size()
	for ring in 6:
		for k in 12:
			var ang := (k + seed_i * 5 + ring * 0.5) * TAU / 12.0
			var c := Vector2(cos(ang), sin(ang)) * (70.0 + ring * 45.0 + r * 0.6)
			if c.length() > 230.0:
				continue
			var ok := true
			for b in p["buildings"]:
				if b.has("pos") and Vector2(b["pos"][0], b["pos"][1]).distance_to(c) < r + float(FOOT.get(b["type"], 22.0)) + 6.0:
					ok = false
					break
			if ok:
				return c
	return Vector2(_rng.randf_range(-150, 150), _rng.randf_range(-150, 150))


func build(id: String, type: String, pos = null) -> void:
	if can_build(id, type) != "":
		return
	var def: Dictionary = BUILDINGS[type]
	money -= def["cost"]
	var days := maxi(1, roundi(def["days"] * Tech.mult("build_time")))
	next_uid += 1
	var b := {"type": type, "days_left": days, "days_total": days, "uid": next_uid}
	if pos == null:
		pos = auto_pos(provinces[id], type)
	b["pos"] = [pos.x, pos.y]
	provinces[id]["buildings"].append(b)
	message.emit("%s: %s qurilishi boshlandi (%d kun)." % [provinces[id]["name"], def["name"], days], "info")
	changed.emit()


func _progress_buildings(p: Dictionary) -> void:
	for b in p["buildings"]:
		if b["days_left"] > 0:
			b["days_left"] -= 1
			if b["days_left"] == 0:
				message.emit("%s: %s qurib bitkazildi!" % [p["name"], BUILDINGS[b["type"]]["name"]], "good")


func military_factories(p: Dictionary) -> int:
	return count_buildings(p, "military")


func count_buildings(p: Dictionary, type: String) -> int:
	var n := 0
	for b in p["buildings"]:
		if b["type"] == type and b["days_left"] <= 0:
			n += 1
	return n


func unit_building(unit: String) -> String:
	return UNITS[unit].get("building", "military")


func units_of(p: Dictionary, unit: String) -> float:
	return float(p["units"].get(unit, 0))


func province_at(world: Vector2) -> String:
	for id in province_order:
		for pts in provinces[id]["polys"]:
			if Geometry2D.is_point_in_polygon(world, pts):
				return id
	return ""


# ---------------------------------------------------------------- buyurtmalar

func can_order(id: String, unit: String, count := 1) -> String:
	var p: Dictionary = provinces[id]
	if p["owner"] != PLAYER:
		return "Bu provinsiya sizniki emas"
	var t: String = UNITS[unit].get("tech", "")
	if t != "" and not Tech.has(t):
		return "Tadqiqot kerak: " + Tech.TECHS[t]["name"]
	var bt := unit_building(unit)
	if count_buildings(p, bt) == 0:
		return "Avval %s quring" % BUILDINGS[bt]["name"].to_lower()
	if money < UNITS[unit]["cost"] * count:
		return "Pul yetmaydi"
	return ""


func order_unit(id: String, unit: String, count := 1) -> void:
	if can_order(id, unit, count) != "":
		return
	var def: Dictionary = UNITS[unit]
	money -= def["cost"] * count
	var p: Dictionary = provinces[id]
	var k := 1.0
	if count_buildings(p, "barracks") > 0 and def.get("adds", unit) == "soldier":
		k = 0.7
	if count_buildings(p, "depot") > 0 and unit == "tank":
		k = 0.7
	var days := maxi(1, roundi(def["days"] * (1.0 + 0.15 * (count - 1)) * k))
	p["orders"].append({"unit": unit, "days_left": days, "days_total": days, "count": count})
	changed.emit()


func order_active(p: Dictionary, index: int) -> bool:
	## Buyurtma hozir ishlanyaptimi (har bir bino bir vaqtda bitta buyurtma bajaradi)
	var o: Dictionary = p["orders"][index]
	var bt := unit_building(o["unit"])
	var before := 0
	for i in index:
		if unit_building(p["orders"][i]["unit"]) == bt:
			before += 1
	return before < count_buildings(p, bt)


func _progress_orders(p: Dictionary) -> void:
	var active: Array = []
	for i in p["orders"].size():
		if order_active(p, i):
			active.append(p["orders"][i])
	for o in active:
		o["days_left"] -= 1
		if o["days_left"] <= 0:
			var def: Dictionary = UNITS[o["unit"]]
			var cnt: int = int(o.get("count", 1))
			var key: String = def.get("adds", o["unit"])
			var made: float = def["batch"] * cnt * def.get("mult", 1.0)
			p["units"][key] = units_of(p, key) + made
			# tayyor qo'shin kazarma / tank parkiga yo'l oladi
			if key == "soldier" or key == "tank":
				var dest := home_site(p, key)
				if dest != "hq":
					_site_add(p, dest, key, made)
				units_produced.emit(p["id"], key, dest)
			if def.has("fort"):
				p["fort"] = float(p.get("fort", 0.0)) + def["fort"] * cnt
			message.emit("%s: %d ta %s tayyor." % [p["name"], def["batch"] * cnt, def["name"].to_lower()], "good")
			p["orders"].erase(o)


# ---------------------------------------------------------------- tasodifiy voqealar

func _tick_prices() -> void:
	for r in price_mult.keys():
		price_mult[r]["days"] -= 1
		if price_mult[r]["days"] <= 0:
			price_mult.erase(r)
			message.emit("%s narxi odatiy holga qaytdi." % RESOURCE_NAMES[r], "info")


func _random_event() -> void:
	var mine := player_provinces()
	if mine.is_empty():
		return
	var pick := _rng.randi_range(0, 4)
	match pick:
		0:
			price_mult["neft"] = {"mult": 2.0, "days": 20}
			message.emit("JAHON: Yaqin Sharqdagi inqiroz tufayli neft narxi 2 barobar oshdi (20 kun).", "event")
		1:
			price_mult["tilla"] = {"mult": 0.5, "days": 15}
			message.emit("JAHON: Tilla bozori qulab tushdi, narx 2 barobar arzonladi (15 kun).", "event")
		2:
			var p: Dictionary = provinces[mine[_rng.randi() % mine.size()]]
			p["unrest"] = minf(100.0, p["unrest"] + 15.0)
			message.emit("%s: ishchilar ish tashlash e'lon qildi! Norozilik +15%%." % p["name"], "bad")
		3:
			var bonus := 200.0 + _rng.randi_range(0, 300)
			money += bonus
			message.emit("Hosil mo'l bo'ldi! Byudjetga +%d $ tushdi." % int(bonus), "good")
		4:
			var p2: Dictionary = provinces[mine[_rng.randi() % mine.size()]]
			var done: Array = []
			for b in p2["buildings"]:
				if b["days_left"] <= 0:
					done.append(b)
			if done.is_empty():
				price_mult["temir"] = {"mult": 1.5, "days": 20}
				message.emit("JAHON: Qurilish bumi - temir narxi 1.5 barobar oshdi (20 kun).", "event")
			else:
				var b2: Dictionary = done[_rng.randi() % done.size()]
				b2["days_left"] = 5
				message.emit("%s: zilzila! %s shikastlandi, ta'mir 5 kun." % [p2["name"], BUILDINGS[b2["type"]]["name"]], "bad")


# ---------------------------------------------------------------- tanlash va boshlash

func select(id: String) -> void:
	selected_id = id
	selected.emit(id)


func start_game(id: String) -> void:
	provinces[id]["owner"] = PLAYER
	provinces[id]["unrest"] = 25.0
	started = true
	Diplo.on_game_started(provinces[id]["country"])
	start_unix = int(Time.get_unix_time_from_system() / 86400.0) * 86400 if era >= 4 else 0
	Politics.on_game_started(provinces[id]["country"])
	message.emit("Siz %s provinsiyasining rahbari bo'ldingiz. Omad!" % provinces[id]["name"], "good")
	if era < 4:
		message.emit("Maslahat: QAL'A (3D) oynasida devor, kazarma va xo'jalik binolarini quring, keyin askar yollang.", "info")
	else:
		message.emit("Maslahat: avval Kon yoki Fuqarolik zavodi quring - ular daromad va ish o'rni beradi.", "info")
	changed.emit()


# ---------------------------------------------------------------- saqlash

const SAVE_PATH := "user://save.json"

func save_game() -> void:
	var provs := {}
	for id in province_order:
		var p: Dictionary = provinces[id]
		provs[id] = {"owner": p["owner"], "buildings": p["buildings"], "orders": p["orders"],
			"unrest": p["unrest"], "units": p["units"], "defense": p["defense"], "militia": p["militia"], "fort": p.get("fort", 0.0), "posts": p.get("posts", []), "sites": p.get("sites", {}), "castle": p.get("castle", {}), "ai_castle": p.get("ai_castle", {})}
	var data := {"day": day, "money": money, "started": started, "game_over": game_over,
		"price_mult": price_mult, "next_event_day": next_event_day, "provinces": provs,
		"war": War.to_dict(), "diplo": Diplo.to_dict(), "tech": Tech.to_dict(),
		"politics": Politics.to_dict(), "start_unix": start_unix, "stock": stock, "goods": goods, "spies": spies, "era": era, "story": story, "story_state": Story.to_dict(), "sell_share": sell_share, "next_uid": next_uid}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	message.emit("O'yin saqlandi.", "info")


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_game() -> void:
	if not has_save():
		return
	var data: Dictionary = JSON.parse_string(FileAccess.open(SAVE_PATH, FileAccess.READ).get_as_text())
	if int(data.get("era", 1)) != era:
		# boshqa zamon saqlangan - avval o'sha zamon dunyosini yuklab, sahnani qayta ochamiz
		set_era(int(data.get("era", 1)))
		pending_load = true
		get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
		return
	story = str(data.get("story", ""))
	next_uid = int(data.get("next_uid", 5000))
	day = int(data["day"])
	money = float(data["money"])
	started = bool(data["started"])
	game_over = bool(data["game_over"])
	price_mult = data["price_mult"]
	next_event_day = int(data["next_event_day"])
	for id in data["provinces"]:
		if not provinces.has(id):
			continue
		var s: Dictionary = data["provinces"][id]
		var p: Dictionary = provinces[id]
		p["owner"] = s["owner"]
		p["unrest"] = float(s["unrest"])
		p["buildings"] = []
		for b in s["buildings"]:
			var nb := {"type": b["type"], "days_left": int(b["days_left"]), "days_total": int(b.get("days_total", b["days_left"]))}
			if b.has("pos"):
				nb["pos"] = [float(b["pos"][0]), float(b["pos"][1])]
			if not nb.has("pos"):
				nb["pos"] = [0.0, 0.0]
				var ap := auto_pos(p, b["type"])
				nb["pos"] = [ap.x, ap.y]
			if b.has("uid"):
				nb["uid"] = int(b["uid"])
			else:
				next_uid += 1
				nb["uid"] = next_uid
			p["buildings"].append(nb)
		p["orders"] = []
		for o in s["orders"]:
			p["orders"].append({"unit": o["unit"], "days_left": int(o["days_left"]), "days_total": int(o.get("days_total", o["days_left"])), "count": int(o.get("count", 1))})
		p["units"] = {}
		for u in s["units"]:
			p["units"][u] = float(s["units"][u])
		p["defense"] = float(s.get("defense", p["max_defense"]))
		p["militia"] = float(s.get("militia", 10.0))
		p["fort"] = float(s.get("fort", 0.0))
		p["sites"] = {}
		var sd: Dictionary = s.get("sites", {})
		for k in sd:
			p["sites"][k] = {"soldier": float(sd[k].get("soldier", 0.0)), "tank": float(sd[k].get("tank", 0.0))}
		if s.get("castle", {}) is Dictionary and not (s.get("castle", {}) as Dictionary).is_empty():
			p["castle"] = s["castle"]
		if not (s.get("ai_castle", {}) as Dictionary).is_empty():
			p["ai_castle"] = s["ai_castle"]
		p["posts"] = []
		for po in s.get("posts", []):
			p["posts"].append({"to": po["to"], "days_left": int(po["days_left"])})
	War.from_dict(data.get("war", {}))
	Diplo.from_dict(data.get("diplo", {}))
	Tech.from_dict(data.get("tech", {}))
	Politics.from_dict(data.get("politics", {}))
	start_unix = int(data.get("start_unix", start_unix))
	stock = data.get("stock", {})
	goods = data.get("goods", goods)
	spies = int(data.get("spies", 0))
	Story.from_dict(data.get("story_state", {}))
	next_uid = maxi(next_uid, int(data.get("next_uid", next_uid)))
	sell_share = data.get("sell_share", {})
	message.emit("Saqlangan o'yin yuklandi.", "info")
	changed.emit()
