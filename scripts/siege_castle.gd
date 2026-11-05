class_name SiegeCastle
## 1-zamon qamal qal'alari:
##  - har bir dushman viloyatining o'z qal'asi (darajasi aholi, poytaxtlik va vaqt o'tishi bilan o'sadi)
##  - o'yinchi o'zi qurgan qal'a (castle3d) qamal jangi uchun to'rtburchak shaklga keltiriladi
##  - josuslar: dushman hujumini oldindan bilish va dushman qal'asi haqida ma'lumot
## Qal'a tavsifi (spec): lvl, hx, hz (yarim o'lcham, m), mid (har devordagi o'rta minoralar), moat,
##   wall_hp, gate_hp, towers (jami), name

const LVL_NAMES := ["", "Qo'rg'oncha", "Qal'a", "Mustahkam qal'a", "Shahar qal'asi"]
const SPY_COST := 60
const SPY_PAY := 0.6          # har josusga kunlik maosh (oltin)
const MAX_SPIES := 5


static func ai_spec(id: String) -> Dictionary:
	var p: Dictionary = Game.provinces[id]
	if not p.has("ai_castle"):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(id + "qal'a")
		# poytaxt (davlatning eng katta shahri) va katta shaharlar mustahkamroq
		var biggest := true
		for pid in Game.province_order:
			var q: Dictionary = Game.provinces[pid]
			if q["country"] == p["country"] and q["population"] > p["population"]:
				biggest = false
				break
		var lvl := 1
		if p["population"] > 150000:
			lvl += 1
		if p["population"] > 400000:
			lvl += 1
		if biggest:
			lvl += 1
		if rng.randf() < 0.25:
			lvl += 1
		p["ai_castle"] = {"lvl": clampi(lvl, 1, 4), "seed": rng.randi() % 1000}
	return _spec_from(p["ai_castle"])


static func _spec_from(c: Dictionary) -> Dictionary:
	var lvl: int = int(c["lvl"])
	var sd: int = int(c.get("seed", 0))
	var hx := 26.0 + lvl * 6.0 + float(sd % 7)
	return {"lvl": lvl, "name": LVL_NAMES[lvl], "hx": hx, "hz": hx * (0.75 + float(sd % 5) * 0.05),
		"mid": 0 if lvl <= 1 else (1 if lvl <= 3 else 2), "moat": lvl >= 3 or (lvl == 2 and sd % 3 == 0),
		"wall_hp": 3.0 + lvl, "gate_hp": 10.0 + lvl * 3.0, "towers": 4 + 4 * (0 if lvl <= 1 else (1 if lvl <= 3 else 2)),
		"player": false}


static func player_spec(p: Dictionary) -> Dictionary:
	## o'yinchi qurgan qal'a: devor bilan to'liq o'ralgan bo'lsa - qamal jangi, aks holda ochiq maydon
	var c: Dictionary = p.get("castle", {})
	if c.is_empty() or not c.get("stats", {}).get("closed", false) or c.get("walls", []).is_empty():
		return {}
	var mn := Vector2(1e9, 1e9)
	var mx := Vector2(-1e9, -1e9)
	for w in c["walls"]:
		for k in ["a", "b"]:
			var v := Vector2(float(w[k][0]), float(w[k][1]))
			mn = Vector2(minf(mn.x, v.x), minf(mn.y, v.y))
			mx = Vector2(maxf(mx.x, v.x), maxf(mx.y, v.y))
	var sz := (mx - mn) * 0.5
	var score := float(c["stats"].get("score", 40.0))
	var towers: int = c.get("towers", []).size()
	return {"lvl": 0, "name": "Sizning qal'angiz", "hx": clampf(sz.x, 18.0, 60.0), "hz": clampf(sz.y, 16.0, 55.0),
		"mid": clampi((towers - 4) / 4, 0, 2), "moat": not c.get("moats", []).is_empty(),
		"wall_hp": 3.0 + score / 25.0, "gate_hp": 10.0 + score / 8.0, "towers": towers, "player": true}


static func describe(s: Dictionary, detailed: bool) -> String:
	if s.is_empty():
		return ""
	if not detailed:
		return "Qal'a haqida aniq ma'lumot yo'q (josus yo'q). Ko'rinishidan: %s." % s["name"].to_lower()
	return "%s: %d x %d m, %d minora%s, devor mustahkamligi %d, darvoza %d." % [s["name"], int(s["hx"] * 2.0), int(s["hz"] * 2.0),
		s["towers"], ", xandaq bor" if s["moat"] else ", xandaq yo'q", int(s["wall_hp"]), int(s["gate_hp"])]


static func grow() -> void:
	## Har 30 kunda: o'yinchi bilan urushayotgan davlatlar chegaradagi qal'alarini mustahkamlaydi
	for id in Game.province_order:
		var p: Dictionary = Game.provinces[id]
		if p["owner"] == Game.PLAYER or not War.at_war_with(p["owner"]):
			continue
		var border := false
		for n in p["neighbors"]:
			if Game.provinces[n]["owner"] == Game.PLAYER:
				border = true
				break
		if not border:
			continue
		ai_spec(id)
		var c: Dictionary = p["ai_castle"]
		if int(c["lvl"]) < 4 and randf() < 0.35:
			c["lvl"] = int(c["lvl"]) + 1
			if Game.spies > 0:
				Game.message.emit("JOSUS: %s qal'asini mustahkamladi - endi %s." % [p["name"], LVL_NAMES[c["lvl"]].to_lower()], "event")


static func hire_spy() -> String:
	if Game.spies >= MAX_SPIES:
		return "Josuslar yetarli (%d ta)" % MAX_SPIES
	if Game.money < SPY_COST:
		return "Oltin yetmaydi (%d kerak)" % SPY_COST
	Game.money -= SPY_COST
	Game.spies += 1
	Game.message.emit("Josus yollandi. Endi dushman hujumi va qal'alari haqida oldindan bilasiz (josuslar: %d)." % Game.spies, "good")
	Game.changed.emit()
	return ""
