class_name CastleEco
## 1-zamon xo'jaligi va qo'shini: resurslar (oltin, oziq, yog'och, tosh), xo'jalik binolari ishlab chiqarishi,
## askar yollash navbati, ta'minot (askarlar ovqat va maosh oladi).
## Oltin = Game.money. Qolgan resurslar Game.goods da.

# narxlar: [oltin, tosh, yog'och]
const BUILD := {
	"wall": [8, 2, 0], "moat": [4, 0, 0], "tower": [150, 60, 0], "gate": [250, 80, 40],
	"barracks": [300, 60, 80], "granary": [180, 20, 60], "well": [60, 30, 0], "smithy": [220, 40, 40], "stable": [260, 20, 100],
	"farm": [120, 0, 40], "lumber": [100, 0, 0], "quarry": [140, 0, 40], "market": [250, 40, 60], "mint": [400, 80, 40],
	"mosque": [450, 120, 60], "house": [60, 10, 20],
}
const ECON := {
	"farm": {"name": "Bug'doy maydoni", "prod": {"oziq": 10}, "foot": Vector2(22, 15)},
	"lumber": {"name": "O'tinxona", "prod": {"yogoch": 7}, "foot": Vector2(12, 10)},
	"quarry": {"name": "Tosh koni", "prod": {"tosh": 6}, "foot": Vector2(14, 12)},
	"market": {"name": "Bozor", "prod": {"oltin": 14}, "foot": Vector2(16, 12)},
	"mint": {"name": "Zarbxona", "prod": {"oltin": 26}, "foot": Vector2(11, 11)},
	"house": {"name": "Uylar", "prod": {"oltin": 3}, "foot": Vector2(7, 8)},
}
const RES_NAMES := {"oltin": "Oltin", "oziq": "Oziq", "yogoch": "Yog'och", "tosh": "Tosh"}
const UNITS1 := {
	"qilichboz": {"name": "Qilichboz", "cost": 25, "food": 4, "days": 3, "needs": "barracks", "power": 1.0},
	"nayzachi": {"name": "Nayzachi", "cost": 18, "food": 3, "days": 2, "needs": "barracks", "power": 0.9},
	"kamonchi": {"name": "Kamonchi", "cost": 30, "food": 3, "days": 3, "needs": "barracks", "power": 1.1},
	"otliq": {"name": "Otliq", "cost": 70, "food": 8, "days": 4, "needs": "stable", "power": 2.2},
}
## 2-zamon (1865): miltiqli sarboz, nayzachi, otliq, to'p
const UNITS2 := {
	"sarboz": {"name": "Sarboz (miltiq)", "cost": 35, "food": 4, "days": 3, "needs": "barracks", "power": 1.6},
	"nayzachi": {"name": "Nayzachi", "cost": 15, "food": 3, "days": 2, "needs": "barracks", "power": 0.8},
	"otliq": {"name": "Otliq", "cost": 65, "food": 8, "days": 4, "needs": "stable", "power": 2.2},
	"top": {"name": "To'p", "cost": 160, "food": 6, "days": 6, "needs": "smithy", "power": 6.0},
}
const NEED_NAMES := {"barracks": "kazarma", "stable": "otxona", "smithy": "temirchi (quyuvxona)"}
## 1 askar ekvivalenti (xarita urushidagi "soldier" soni, maosh va oziq uchun)
const EQ := {"otliq": 2.0, "top": 4.0}


static func units() -> Dictionary:
	return UNITS2 if Game.era == 2 else UNITS1


const BATCH := 5          # bir partiya askar
const PAY := 0.12         # har askarga kunlik maosh (oltin)
const EAT := 0.08         # har askarga kunlik oziq (otliq 2 baravar)


static func castle(p: Dictionary) -> Dictionary:
	if not p.has("castle"):
		p["castle"] = {"keep": [0.0, 0.0], "walls": [], "towers": [], "gates": [], "moats": [], "buildings": []}
	var c: Dictionary = p["castle"]
	if not c.has("army"):
		c["army"] = {}
		for k in units():
			c["army"][k] = 0
	if not c.has("queue"):
		c["queue"] = []
	return c


static func count(p: Dictionary, t: String) -> int:
	var n := 0
	for b in castle(p)["buildings"]:
		if b["t"] == t:
			n += 1
	return n


static func cap(res: String, p: Dictionary) -> float:
	var g := count(p, "granary")
	match res:
		"oziq": return 400.0 + g * 600.0
		"yogoch", "tosh": return 500.0 + g * 400.0
	return 1e12


static func have(res: String) -> float:
	return Game.money if res == "oltin" else float(Game.goods.get(res, 0.0))


static func cost_of(kind: String, mult := 1.0) -> Dictionary:
	var c: Array = BUILD.get(kind, [0, 0, 0])
	return {"oltin": int(ceil(c[0] * mult)), "tosh": int(ceil(c[1] * mult)), "yogoch": int(ceil(c[2] * mult))}


static func can_pay(cost: Dictionary) -> String:
	## bo'sh qator = yetadi, aks holda nima yetmasligi
	var miss: Array = []
	for r in cost:
		if cost[r] > 0 and have(r) < cost[r]:
			miss.append("%s %d (bor %d)" % [RES_NAMES[r], cost[r], int(have(r))])
	return ", ".join(miss)


static func pay(cost: Dictionary) -> void:
	for r in cost:
		if r == "oltin":
			Game.money -= cost[r]
		else:
			Game.goods[r] = float(Game.goods.get(r, 0.0)) - cost[r]
	Game.changed.emit()


static func cost_text(cost: Dictionary) -> String:
	var parts: Array = []
	for r in ["oltin", "tosh", "yogoch"]:
		if cost.get(r, 0) > 0:
			parts.append("%d %s" % [cost[r], RES_NAMES[r].to_lower()])
	return " + ".join(parts)


static func army_total(p: Dictionary) -> int:
	var a: Dictionary = castle(p)["army"]
	var t := 0
	for k in a:
		t += int(a[k])
	return t


static func army_power(p: Dictionary) -> float:
	var a: Dictionary = castle(p)["army"]
	var s := 0.0
	for k in a:
		if units().has(k):
			s += float(a[k]) * float(units()[k]["power"])
	return s


static func queued(p: Dictionary) -> int:
	var n := 0
	for q in castle(p)["queue"]:
		n += int(q["count"])
	return n


static func unit_cost(p: Dictionary, kind: String) -> int:
	var c := float(units()[kind]["cost"])
	if count(p, "smithy") > 0:
		c *= 0.8      # temirchi qurolni arzonlashtiradi
	return int(ceil(c))


static func can_recruit(p: Dictionary, kind: String, n: int) -> String:
	var u: Dictionary = units()[kind]
	if count(p, u["needs"]) == 0:
		return "Avval %s quring" % NEED_NAMES.get(u["needs"], u["needs"])
	var c: Dictionary = castle(p)
	var capacity := int(c.get("stats", {}).get("capacity", 0))
	if not c.get("stats", {}).get("closed", false):
		capacity = 60     # devor bilan o'ralmagan qarorgohda kam askar sig'adi
	if army_total(p) + queued(p) + n > capacity:
		return "Hovliga sig'maydi (joy %d)" % capacity
	if Game.money < unit_cost(p, kind) * n:
		return "Oltin yetmaydi"
	if have("oziq") < u["food"] * n:
		return "Oziq yetmaydi"
	return ""


static func recruit(p: Dictionary, kind: String, n: int) -> bool:
	if can_recruit(p, kind, n) != "":
		return false
	Game.money -= unit_cost(p, kind) * n
	Game.goods["oziq"] = have("oziq") - units()[kind]["food"] * n
	var builds := maxi(1, count(p, units()[kind]["needs"]))
	var days := int(ceil(float(units()[kind]["days"]) * ceil(float(n) / BATCH) / builds))
	castle(p)["queue"].append({"kind": kind, "count": n, "days_left": days, "days_total": days})
	Game.changed.emit()
	return true


static func daily(p: Dictionary) -> void:
	## Har kuni: xo'jalik ishlab chiqaradi, navbatdagi askarlar tayyor bo'ladi, qo'shin oziq va maosh oladi
	var c := castle(p)
	for b in c["buildings"]:
		if ECON.has(b["t"]):
			var prod: Dictionary = ECON[b["t"]]["prod"]
			for r in prod:
				if r != "oltin":      # oltin Game.province_income orqali kunlik daromadga qo'shiladi
					Game.goods[r] = minf(cap(r, p), have(r) + prod[r])
	if not c["queue"].is_empty():
		var q: Dictionary = c["queue"][0]
		q["days_left"] = int(q["days_left"]) - 1
		if q["days_left"] <= 0:
			c["army"][q["kind"]] = int(c["army"][q["kind"]]) + int(q["count"])
			c["queue"].pop_front()
			Game.message.emit("%s: %d %s tayyor - hovlida saf tortdi." % [p["name"], q["count"], units()[q["kind"]]["name"].to_lower()], "good")
	var a: Dictionary = c["army"]
	var eat := 0.0
	var pay_ := 0.0
	for k in a:
		var m: float = EQ.get(k, 1.0)
		eat += float(a[k]) * EAT * m
		pay_ += float(a[k]) * PAY * m
	Game.goods["oziq"] = have("oziq") - eat
	if have("oziq") < 0.0:
		Game.goods["oziq"] = 0.0
		# ochlik: askarlarning bir qismi qochib ketadi
		for k in a:
			var lost := int(ceil(float(a[k]) * 0.05))
			a[k] = maxi(0, int(a[k]) - lost)
		Game.message.emit("%s: OZIQ TUGADI! Askarlar qochmoqda - bug'doy maydoni quring." % p["name"], "bad")
	sync(p)


static func gold(p: Dictionary) -> Dictionary:
	## kunlik oltin: xo'jalikdan tushum va qo'shin maoshi
	var c := castle(p)
	var prod := 0.0
	for b in c["buildings"]:
		if ECON.has(b["t"]):
			prod += float(ECON[b["t"]]["prod"].get("oltin", 0))
	var pay_ := 0.0
	for k in c["army"]:
		pay_ += float(c["army"][k]) * PAY * float(EQ.get(k, 1.0))
	return {"prod": prod, "pay": pay_}


static func sync(p: Dictionary) -> void:
	## Xarita urush tizimi "soldier" sonini ishlatadi: qal'a qo'shini shu songa ko'zguday ko'chiriladi.
	## Agar askarlar urushga jo'natilib kamaygan bo'lsa, qal'a qo'shini ham mutanosib kamayadi.
	var c := castle(p)
	var a: Dictionary = c["army"]
	var cur: float = p["units"].get("soldier", 0.0)
	var last: float = float(c.get("mirror", -1.0))
	if last >= 0.0 and cur < last - 0.5 and last > 0.0:
		var ratio := clampf(cur / last, 0.0, 1.0)
		for k in a:
			a[k] = int(floor(float(a[k]) * ratio))
	elif last >= 0.0 and cur > last + 0.5:
		var base_k := "sarboz" if a.has("sarboz") else "qilichboz"
		a[base_k] = int(a.get(base_k, 0)) + int(cur - last)
	var eq := 0.0
	for k in a:
		eq += float(a[k]) * float(EQ.get(k, 1.0))
	p["units"]["soldier"] = eq
	c["mirror"] = eq
