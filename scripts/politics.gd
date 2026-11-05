extends Node
## Siyosat (autoload: Politics)
## Real dunyo holati (data/geopolitics.json): yirik davlatlar, mafkura, sanksiyalar, urushlar,
## qurol litsenziyalari, qora bozor, eksport shartnomalari, xorijiy ta'sir va to'ntarish,
## maxfiy operatsiyalar, real yangiliklar (oflayn ssenariy + onlayn RSS).

signal news_added

const CENTER_TYPE := "politic"
const IDEOLOGY_CHANGE_COST := 2000
const IDEOLOGY_CHANGE_DAYS := 60
const COUNTER_INTEL_COST := 800
const COUNTER_INTEL_UPKEEP := 10.0
const PROPAGANDA_COST := 400
const AID_COST := 500
const OP_DAILY := 15.0
const OP_DAYS := 60
const IMPORT_DAYS := 10
const BLACK_DAYS := 8
const SANCTION_DAYS := 180
const FEEDS := [
	"https://feeds.bbci.co.uk/news/world/rss.xml",
	"https://www.aljazeera.com/xml/rss/all.xml",
]
const FEED_INTERVAL := 1800.0   # real soniya (30 daqiqa)

var data := {}
var ideology := "secular"
var pending_ideology := ""
var ideology_days := 0
var support := 60.0
var influence := {}        # yirik davlat -> ichimizdagi ta'siri (0..100)
var counter_intel := 0     # 0..3
var prel := {}             # yirik davlat -> munosabat (-100..100)
var psanction := {}        # yirik davlat -> sanksiya kunlari
var licenses := {}         # qurol -> qaysi davlatdan
var arsenal := {}          # qurol -> soni
var production: Array = [] # {weapon, n, days}
var imports: Array = []    # {weapon, n, days, from, black}
var contracts: Array = []  # {power, res, days}
var ops: Array = []        # {country, days}
var news: Array = []       # {day, text, kind, tag}
var timeline_idx := 0
var black_disc := {}
var next_offer := 20
var next_hostile := 30
var next_election := 365
var coup_cooldown := 60
var propaganda_days := 0
var online_ok := false
var _seen := {}
var _feed_timer := 5.0
var _http: HTTPRequest
var _feed_i := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var f := FileAccess.open("res://data/geopolitics.json", FileAccess.READ)
	if f:
		data = JSON.parse_string(f.get_as_text())
	for p in powers():
		prel[p] = float(data["powers"][p]["likes"].get(ideology, 0)) + 5.0
		influence[p] = 0.0
	for w in data.get("weapons", {}):
		arsenal[w] = 0
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	add_child(_http)
	_http.request_completed.connect(_on_feed)
	Game.day_passed.connect(_on_day)


func on_game_started(home_country: String) -> void:
	if Game.era < 4:
		return   # zamonaviy siyosat (sanksiya, real yangiliklar) faqat 4-zamonda
	var reg: Dictionary = data["regional"].get(home_country, {})
	ideology = reg.get("ideology", "secular")
	if ideology == "communist":
		ideology = "authoritarian"   # viloyat rahbari Xitoy partiyasi emas
	for p in powers():
		prel[p] = _target_rel(p)
	for res in data.get("markets", {}):
		var m: Dictionary = data["markets"][res]
		Game.price_mult[res] = {"mult": float(m["mult"]), "days": 120}
	_add_news("Siz boshqaradigan hudud: %s. Davlat tuzumi: %s." % [Game.countries[home_country]["name"], ideo_name(ideology)], "info", "Davlat")
	_run_timeline()


# ---------------------------------------------------------------- yordamchilar

func powers() -> Array:
	return data.get("powers", {}).keys()


func pname(p: String) -> String:
	if data["powers"].has(p):
		return data["powers"][p]["name"]
	if Game.countries.has(p):
		return Game.countries[p]["name"]
	return p


func ideo_name(i: String) -> String:
	return data["ideologies"][i]["name"]


func ideo() -> Dictionary:
	return data["ideologies"][ideology]


func weapon(w: String) -> Dictionary:
	return data["weapons"][w]


func has_center() -> bool:
	for id in Game.player_provinces():
		for b in Game.provinces[id]["buildings"]:
			if b["type"] == CENTER_TYPE and b["days_left"] <= 0:
				return true
	return false


func center_planned() -> bool:
	for id in Game.player_provinces():
		for b in Game.provinces[id]["buildings"]:
			if b["type"] == CENTER_TYPE:
				return true
	return false


func military_factories() -> int:
	var n := 0
	for id in Game.player_provinces():
		n += Game.count_buildings(Game.provinces[id], "military")
	return n


func total_influence() -> float:
	var t := 0.0
	for p in influence:
		t += influence[p]
	return minf(t, 100.0)


func top_influencer() -> String:
	var best := ""
	var v := 0.0
	for p in influence:
		if influence[p] > v:
			v = influence[p]
			best = p
	return best


func sanctioned_by(p: String) -> bool:
	return psanction.get(p, 0) > 0


func rel_word(r: float) -> String:
	if r >= 50: return "Do'st"
	if r >= 20: return "Iliq"
	if r >= -20: return "Betaraf"
	if r >= -50: return "Sovuq"
	return "Dushman"


func _add_news(text: String, kind := "event", tag := "Jahon") -> void:
	news.push_front({"day": Game.day, "text": text, "kind": kind, "tag": tag})
	if news.size() > 120:
		news.pop_back()
	Game.message.emit("[%s] %s" % [tag, text], kind)
	news_added.emit()


# ---------------------------------------------------------------- o'yinga ta'sir (Tech orqali ulangan)

func mult(kind: String) -> float:
	match kind:
		"soldier":
			var k := 0.0
			for w in arsenal:
				k += arsenal[w] * float(weapon(w).get("inf", 0.0))
			return 1.0 + minf(k, 0.5)
		"tank":
			var k2 := 0.0
			for w in arsenal:
				k2 += arsenal[w] * float(weapon(w).get("attack", 0.0))
			return 1.0 + minf(k2, 0.6)
		"income":
			var m: float = ideo()["income"]
			if pending_ideology != "":
				m *= 0.9
			for p in psanction:
				if psanction[p] > 0:
					m -= float(data["powers"][p]["economy"]) * 0.0009
			return maxf(m, 0.4)
		"research":
			return float(ideo()["research"])
	return 1.0


func bonus(kind: String) -> float:
	match kind:
		"unrest":
			# musbat = norozilik kamayadi
			var b: float = float(ideo()["unrest"]) + (support - 50.0) * 0.2 - total_influence() * 0.25
			if pending_ideology != "":
				b -= 10.0
			return b
		"militia":
			var air := 0.0
			for w in arsenal:
				air += arsenal[w] * float(weapon(w).get("air", 0.0))
			return float(ideo()["militia"]) + minf(air * 4.0, 40.0)
	return 0.0


func regional_bias(c: String) -> float:
	## Diplo uchun: qo'shni davlat bizning tuzumimizni qanday ko'radi
	var reg: Dictionary = data["regional"].get(c, {})
	var their: String = reg.get("ideology", "secular")
	var b := 0.0
	if their == ideology:
		b += 12.0
	if ideology == "islamic":
		b += 20.0 if their == "islamic" else -15.0
	elif their == "islamic":
		b -= 5.0
	return b


func _target_rel(p: String) -> float:
	var d: Dictionary = data["powers"][p]
	var t: float = float(d["likes"].get(ideology, 0))
	var home := ""
	for id in Game.player_provinces():
		home = Game.provinces[id]["country"]
		break
	var reg: Dictionary = data["regional"].get(home, {})
	if p in reg.get("partners", []):
		t += 12.0
	for c in contracts:
		if c["power"] == p:
			t += 15.0
	if sanctioned_by(p):
		t -= 20.0
	return clampf(t, -90.0, 80.0)


func change_prel(p: String, d: float) -> void:
	if prel.has(p):
		prel[p] = clampf(prel[p] + d, -100.0, 100.0)


func _anger_rivals(seller: String, amount: float) -> void:
	for p in powers():
		if seller in data["powers"][p]["rivals"]:
			change_prel(p, -amount)


# ---------------------------------------------------------------- kunlik

func _on_day(_d: int) -> void:
	if not Game.started or Game.era < 4:
		return
	_run_timeline()
	# mafkura almashuvi
	if pending_ideology != "":
		ideology_days -= 1
		if ideology_days <= 0:
			ideology = pending_ideology
			pending_ideology = ""
			_add_news("Yangi davlat tuzumi e'lon qilindi: %s." % ideo_name(ideology), "event", "Davlat")
	# munosabatlar asta maqsadga intiladi
	for p in powers():
		prel[p] = move_toward(prel[p], _target_rel(p), 0.5)
	# xorijiy ta'sir (muxolifatni moliyalash)
	for p in powers():
		var r: float = prel[p]
		var sub: float = data["powers"][p]["subversion"]
		if r < -15.0 and sub > 0.0:
			influence[p] += sub * (-r - 15.0) / 40.0 * 0.5
		else:
			influence[p] -= 0.4
		influence[p] = clampf(influence[p] - counter_intel * 0.35, 0.0, 100.0)
	Game.money -= counter_intel * COUNTER_INTEL_UPKEEP
	# xalq qo'llovi
	var avg := 0.0
	var mine := Game.player_provinces()
	for id in mine:
		avg += Game.provinces[id]["unrest"]
	avg = avg / maxf(1.0, mine.size())
	var target := 75.0 - avg * 0.5 - total_influence() * 0.3
	if ideology == "authoritarian":
		target -= 8.0
	if propaganda_days > 0:
		propaganda_days -= 1
		target += 12.0
	support = clampf(move_toward(support, target, 0.3), 0.0, 100.0)
	# sanksiyalar
	for p in powers():
		if psanction.get(p, 0) > 0:
			psanction[p] -= 1
			if psanction[p] == 0:
				_add_news("%s sizga qarshi sanksiyalarni bekor qildi." % pname(p), "good")
		elif prel[p] <= -45.0 and float(data["powers"][p]["economy"]) >= 40.0 and _rng.randf() < 0.02:
			_impose(p, "munosabatlar keskin yomonlashgani uchun")
	_tick_supply()
	_tick_contracts()
	_tick_ops()
	_check_coup()
	_check_election()
	next_hostile -= 1
	if next_hostile <= 0:
		next_hostile = _rng.randi_range(15, 30)
		_hostile_action()
	next_offer -= 1
	if next_offer <= 0 and has_center():
		next_offer = _rng.randi_range(25, 45)
		_power_offer()


func _impose(p: String, why: String) -> void:
	psanction[p] = SANCTION_DAYS
	for c in contracts.duplicate():
		if c["power"] == p:
			contracts.erase(c)
	_add_news("%s sizga SANKSIYA qo'ydi (%s): %d kun savdo va qurol yo'q, daromad kamayadi." % [pname(p), why, SANCTION_DAYS], "bad")


func _run_timeline() -> void:
	var tl: Array = data.get("timeline", [])
	while timeline_idx < tl.size() and int(tl[timeline_idx]["day"]) <= Game.day:
		var e: Dictionary = tl[timeline_idx]
		timeline_idx += 1
		_add_news(e["text"], e.get("kind", "event"), "Real voqea")
		_apply_effect(e.get("effect", {}))
		if e.has("choice"):
			_choice(e["choice"])


func _apply_effect(ef: Dictionary) -> void:
	if ef.has("price"):
		var res: String = ef["price"]
		Game.price_mult[res] = {"mult": float(ef["mult"]), "days": int(ef.get("days", 30))}
	if ef.has("rel_power"):
		change_prel(ef["rel_power"][0], float(ef["rel_power"][1]))
	if ef.has("black_discount"):
		black_disc[ef["black_discount"]] = 0.6
	if ef.has("unrest_country"):
		var c: String = ef["unrest_country"]
		for id in Game.province_order:
			var p: Dictionary = Game.provinces[id]
			if p["owner"] == c:
				p["defense"] = p["max_defense"] * 0.85


func _choice(kind: String) -> void:
	match kind:
		"iran_deal":
			Diplo.proposal.emit("ERON-AQSh MUZOKARASI\n\nQatar sizdan ham muzokaralarni qo'llab-quvvatlovchi bayonot so'rayapti.\n\nQabul qilsangiz: AQSh +8, Eron +8, neft narxi biroz tushadi (urush xavfi kamayadi).\nRad etsangiz: hech narsa o'zgarmaydi, lekin Eron va AQSh sizga befarq.",
				func():
					change_prel("USA", 8); change_prel("IRN", 8)
					if Game.price_mult.has("neft"):
						Game.price_mult["neft"]["mult"] = maxf(1.0, Game.price_mult["neft"]["mult"] - 0.2)
					_add_news("Siz Eron-AQSh muzokaralarini qo'llab-quvvatladingiz. Neft narxi biroz pasaydi.", "good", "Diplomatiya"),
				func(): pass)
		"trade_truce":
			if _rng.randf() < 0.6:
				_add_news("AQSh va Xitoy savdo sulhini uzaytirdi. Mis va temir narxi o'sdi.", "good", "Real voqea")
				Game.price_mult["mis"] = {"mult": 1.25, "days": 40}
			else:
				_add_news("AQSh-Xitoy sulhi uzilib, bojlar qaytdi. Xitoy xom ashyo xaridini kamaytirdi.", "bad", "Real voqea")
				Game.price_mult["mis"] = {"mult": 0.8, "days": 40}
				Game.price_mult["temir"] = {"mult": 0.85, "days": 40}
		"iran_npt":
			Diplo.proposal.emit("ERON NPT DAN CHIQMOQCHI\n\nBMT da qaror loyihasi: Eronga qo'shimcha sanksiyalar. Ovoz berasizmi?\n\nQabul (qarshi ovoz - sanksiyani qo'llash): AQSh +12, Yevropa +10, Isroil +10, Eron -30.\nRad (betaraf qolish): Eron +10, Rossiya +5, AQSh -6.",
				func():
					change_prel("USA", 12); change_prel("EU", 10); change_prel("ISR", 10); change_prel("IRN", -30),
				func():
					change_prel("IRN", 10); change_prel("RUS", 5); change_prel("USA", -6))


# ---------------------------------------------------------------- mafkura va ichki siyosat

func why_ideology(i: String) -> String:
	if not has_center(): return "Siyosiy markaz kerak"
	if i == ideology: return "Hozirgi tuzum"
	if pending_ideology != "": return "O'tish davri davom etmoqda"
	if Game.money < IDEOLOGY_CHANGE_COST: return "Pul yetmaydi (%d $)" % IDEOLOGY_CHANGE_COST
	return ""


func change_ideology(i: String) -> void:
	if why_ideology(i) != "":
		return
	Game.money -= IDEOLOGY_CHANGE_COST
	pending_ideology = i
	ideology_days = IDEOLOGY_CHANGE_DAYS
	support = maxf(0.0, support - 15.0)
	for id in Game.player_provinces():
		Game.provinces[id]["unrest"] = minf(100.0, Game.provinces[id]["unrest"] + 10.0)
	var tmp := ideology
	ideology = i
	var react: Array = []
	for p in powers():
		var t := _target_rel(p)
		if t > prel[p] + 10.0:
			react.append("%s qo'llab-quvvatlaydi" % pname(p))
		elif t < prel[p] - 10.0:
			react.append("%s qarshi" % pname(p))
	ideology = tmp
	_add_news("Davlat tuzumini '%s' ga o'zgartirish boshlandi (%d kun o'tish davri). %s." % [ideo_name(i), IDEOLOGY_CHANGE_DAYS, ", ".join(react)], "event", "Davlat")
	Game.changed.emit()


func why_simple(cost: int) -> String:
	if not has_center(): return "Siyosiy markaz kerak"
	if Game.money < cost: return "Pul yetmaydi"
	return ""


func propaganda() -> void:
	if why_simple(PROPAGANDA_COST) != "": return
	Game.money -= PROPAGANDA_COST
	propaganda_days = 30
	support = minf(100.0, support + 6.0)
	_add_news("Milliy targ'ibot kampaniyasi boshlandi (30 kun): xalq qo'llovi oshadi.", "good", "Davlat")
	Game.changed.emit()


func buy_counter_intel() -> void:
	if counter_intel >= 3 or why_simple(COUNTER_INTEL_COST) != "": return
	Game.money -= COUNTER_INTEL_COST
	counter_intel += 1
	_add_news("Qarshi razvedka %d-darajaga ko'tarildi: xorijiy agentlar ushlanmoqda." % counter_intel, "good", "Davlat")
	Game.changed.emit()


func crackdown() -> void:
	## Muxolifatni bostirish: xorijiy ta'sir keskin tushadi, lekin qo'llov va G'arb munosabati tushadi
	if why_simple(600) != "": return
	Game.money -= 600
	for p in influence:
		influence[p] *= 0.4
	support = maxf(0.0, support - 10.0)
	change_prel("USA", -10); change_prel("EU", -12)
	_add_news("Muxolifat yetakchilari hibsga olindi. G'arb inson huquqlari buzilganini qoraladi.", "bad", "Davlat")
	Game.changed.emit()


func _check_coup() -> void:
	if coup_cooldown > 0:
		coup_cooldown -= 1
		return
	var infl := total_influence()
	if infl < 55.0 or support > 40.0 or _rng.randf() > 0.06:
		return
	coup_cooldown = 90
	var who := top_influencer()
	var army := 0.0
	for id in Game.player_provinces():
		army += War.garrison_power(Game.provinces[id])
	var chance := clampf(0.35 + army / 600.0 + support / 200.0 - infl / 300.0, 0.15, 0.9)
	var text := "TO'NTARISHGA URINISH!\n\n%s qo'llab-quvvatlayotgan muxolifat poytaxtda harbiylar bilan qo'zg'olon boshladi.\nXalq qo'llovi: %d%%, xorijiy ta'sir: %d%%.\n\nBOSTIRISH: pulning 30%% i sarflanadi, muvaffaqiyat ehtimoli ~%d%%. Muvaffaqiyatsiz bo'lsa eng katta provinsiyangiz isyonchilarga o'tadi.\n\nMUROSA: davlat tuzumi 'Dunyoviy respublika'ga qaytariladi, ta'sir yo'qoladi, %s munosabati yaxshilanadi." % [pname(who), int(support), int(infl), int(chance * 100), pname(who)]
	Diplo.proposal.emit(text, _coup_fight.bind(who, chance), _coup_yield.bind(who))


func _coup_fight(who: String, chance: float) -> void:
	Game.money *= 0.7
	if _rng.randf() < chance:
		for p in influence:
			influence[p] *= 0.3
		support = minf(100.0, support + 10.0)
		change_prel(who, -25)
		_add_news("To'ntarish bostirildi! Fitnachilar %s bilan aloqada ekani fosh bo'ldi." % pname(who), "good", "Davlat")
	else:
		var best := ""
		var pop := -1
		for id in Game.player_provinces():
			if Game.provinces[id]["population"] > pop and Game.player_provinces().size() > 1:
				pop = Game.provinces[id]["population"]
				best = id
		if best != "":
			Game._rebellion(Game.provinces[best])
		for p in influence:
			influence[p] *= 0.5
		_add_news("To'ntarishni bostirib bo'lmadi. Muxolifat hududni egalladi.", "bad", "Davlat")
	Game.changed.emit()


func _coup_yield(who: String) -> void:
	ideology = "secular"
	pending_ideology = ""
	for p in influence:
		influence[p] = 0.0
	support = maxf(0.0, support - 5.0)
	change_prel(who, 25)
	_add_news("Murosaga kelindi: davlat dunyoviy respublikaga qaytdi. %s mamnun." % pname(who), "event", "Davlat")
	Game.changed.emit()


func _check_election() -> void:
	if ideology != "democracy":
		next_election = Game.day + 365
		return
	if Game.day < next_election:
		return
	next_election = Game.day + 365
	if support >= 40.0:
		support = minf(100.0, support + 5.0)
		_add_news("Saylovda g'alaba! Xalq qo'llovi %d%%. G'arb saylovni tan oldi." % int(support), "good", "Davlat")
		change_prel("USA", 5); change_prel("EU", 5)
	else:
		Game.money *= 0.7
		for id in Game.player_provinces():
			Game.provinces[id]["unrest"] = minf(100.0, Game.provinces[id]["unrest"] + 15.0)
		support = 45.0
		_add_news("Saylovda yutqazdingiz: koalitsiya hukumati tuzildi, byudjetning 30%% i yo'qoldi, norozilik oshdi.", "bad", "Davlat")


# ---------------------------------------------------------------- qurollar: import, litsenziya, qora bozor

func sellers(w: String) -> Array:
	var out: Array = []
	for p in powers():
		if w in data["powers"][p]["sells"]:
			out.append(p)
	return out


func import_price(p: String, w: String) -> int:
	var k := 1.0 if prel[p] >= 50.0 else 1.25
	return int(weapon(w)["price"] * k)


func why_import(p: String, w: String, n: int) -> String:
	if not has_center(): return "Siyosiy markaz kerak"
	if sanctioned_by(p): return "%s sanksiya qo'ygan" % pname(p)
	if Diplo.sanctioned(): return "Global sanksiya ostidasiz"
	if prel[p] < float(weapon(w)["min_rel"]): return "Munosabat kamida %d bo'lishi kerak" % int(weapon(w)["min_rel"])
	if Game.money < import_price(p, w) * n: return "Pul yetmaydi"
	return ""


func buy_import(p: String, w: String, n: int) -> void:
	if why_import(p, w, n) != "": return
	Game.money -= import_price(p, w) * n
	imports.append({"weapon": w, "n": n, "days": IMPORT_DAYS, "from": p, "black": false})
	change_prel(p, 2.0 * n)
	_anger_rivals(p, minf(3.0 * n, 12.0))
	_add_news("%s dan %d ta %s sotib olindi (%d kunda yetadi). Raqiblari norozi." % [pname(p), n, weapon(w)["name"], IMPORT_DAYS], "info", "Qurol")
	Game.changed.emit()


func why_license(p: String, w: String) -> String:
	if not has_center(): return "Siyosiy markaz kerak"
	if licenses.has(w): return "Litsenziya bor (%s)" % pname(licenses[w])
	if sanctioned_by(p): return "%s sanksiya qo'ygan" % pname(p)
	if prel[p] < float(weapon(w)["min_rel"]) + 15.0: return "%s ruxsat bermaydi: munosabat kamida %d kerak" % [pname(p), int(weapon(w)["min_rel"]) + 15]
	if Game.money < int(weapon(w)["license"]): return "Pul yetmaydi"
	return ""


func buy_license(p: String, w: String) -> void:
	if why_license(p, w) != "": return
	Game.money -= int(weapon(w)["license"])
	licenses[w] = p
	change_prel(p, 10)
	_anger_rivals(p, 8)
	_add_news("%s %s ishlab chiqarishga litsenziya berdi. Endi harbiy zavodlaringizda yasay olasiz." % [pname(p), weapon(w)["name"]], "good", "Qurol")
	Game.changed.emit()


func produce_cost(w: String) -> int:
	var k := 0.55 if ideology == "communist" else 0.65
	return int(weapon(w)["price"] * k)


func why_produce(w: String, n: int) -> String:
	if not licenses.has(w): return "Litsenziya yo'q"
	if military_factories() == 0: return "Harbiy zavod kerak"
	if Game.money < produce_cost(w) * n: return "Pul yetmaydi"
	return ""


func produce(w: String, n: int) -> void:
	if why_produce(w, n) != "": return
	Game.money -= produce_cost(w) * n
	var days := maxi(2, int(ceil(float(weapon(w)["days"]) * n / military_factories())))
	production.append({"weapon": w, "n": n, "days": days})
	Game.message.emit("Ishlab chiqarish: %d ta %s (%d kun)." % [n, weapon(w)["name"], days], "info")
	Game.changed.emit()


func black_price(w: String) -> int:
	return int(weapon(w)["black"] * black_disc.get(w, 1.0))


func why_black(w: String, n: int) -> String:
	if not has_center(): return "Siyosiy markaz kerak"
	if Game.money < black_price(w) * n: return "Pul yetmaydi"
	return ""


func buy_black(w: String, n: int) -> void:
	if why_black(w, n) != "": return
	Game.money -= black_price(w) * n
	imports.append({"weapon": w, "n": n, "days": BLACK_DAYS, "from": "", "black": true})
	Game.message.emit("Qora bozor: %d ta %s kontrabanda yo'lida (%d kun). Ushlanib qolish xavfi bor!" % [n, weapon(w)["name"], BLACK_DAYS], "event")
	Game.changed.emit()


func _tick_supply() -> void:
	for x in production.duplicate():
		x["days"] -= 1
		if x["days"] <= 0:
			production.erase(x)
			arsenal[x["weapon"]] += int(x["n"])
			Game.message.emit("Tayyor: %d ta %s arsenalga qo'shildi." % [x["n"], weapon(x["weapon"])["name"]], "good")
	for x in imports.duplicate():
		x["days"] -= 1
		if x["days"] > 0:
			continue
		imports.erase(x)
		if x["black"]:
			var r := _rng.randf()
			if r < 0.2:
				_add_news("Kontrabanda chegarada ushlandi: %d ta %s musodara qilindi!" % [x["n"], weapon(x["weapon"])["name"]], "bad", "Qora bozor")
				continue
			arsenal[x["weapon"]] += int(x["n"])
			if r < 0.4:
				change_prel("USA", -8); change_prel("EU", -8)
				_add_news("Xalqaro OAV qora bozordan qurol olganingizni fosh qildi. AQSh va Yevropa norozi.", "bad", "Qora bozor")
				if prel["USA"] < -40.0 and not sanctioned_by("USA"):
					_impose("USA", "noqonuniy qurol savdosi")
			else:
				Game.message.emit("Qora bozor yuki yetib keldi: %d ta %s." % [x["n"], weapon(x["weapon"])["name"]], "good")
		else:
			arsenal[x["weapon"]] += int(x["n"])
			Game.message.emit("%s dan %d ta %s yetib keldi." % [pname(x["from"]), x["n"], weapon(x["weapon"])["name"]], "good")


func arsenal_power() -> int:
	var t := 0
	for w in arsenal:
		t += arsenal[w]
	return t


# ---------------------------------------------------------------- resurs eksporti

func produced(res: String) -> float:
	var t := 0.0
	for id in Game.player_provinces():
		var p: Dictionary = Game.provinces[id]
		if Game.count_buildings(p, "mine") > 0 and p["resources"].has(res):
			t += float(p["resources"][res]) * Game.count_buildings(p, "mine")
	return t


func why_contract(p: String, res: String) -> String:
	if not has_center(): return "Siyosiy markaz kerak"
	if produced(res) <= 0.0: return "Bu resursni qazmayapsiz (kon kerak)"
	if sanctioned_by(p): return "%s sanksiya qo'ygan" % pname(p)
	if prel[p] < 0.0: return "Munosabat salbiy"
	for c in contracts:
		if c["res"] == res:
			return "Bu resurs allaqachon %s ga sotilmoqda" % pname(c["power"])
	return ""


func sign_contract(p: String, res: String) -> void:
	if why_contract(p, res) != "": return
	contracts.append({"power": p, "res": res, "days": 180})
	change_prel(p, 6)
	var warn := ""
	if p in ["IRN", "RUS", "PRK"]:
		warn = " AQSh va Yevropa ikkilamchi sanksiya bilan tahdid qilmoqda."
	_add_news("%s bilan %s eksport shartnomasi imzolandi (180 kun, narx +40%%).%s" % [pname(p), Game.RESOURCE_NAMES[res], warn], "good", "Savdo")
	Game.changed.emit()


func contract_income() -> float:
	var t := 0.0
	for c in contracts:
		t += produced(c["res"]) * Game.resource_price(c["res"]) * 0.4 * Tech.mult("resources")
	return t


func _tick_contracts() -> void:
	Game.money += contract_income()
	for c in contracts.duplicate():
		c["days"] -= 1
		if c["power"] in ["IRN", "RUS", "PRK"]:
			change_prel("USA", -0.12); change_prel("EU", -0.12)
		if c["days"] <= 0:
			contracts.erase(c)
			Game.message.emit("%s bilan %s shartnomasi tugadi." % [pname(c["power"]), Game.RESOURCE_NAMES[c["res"]]], "info")


# ---------------------------------------------------------------- yumshoq kuch va maxfiy operatsiyalar

func send_aid(p: String) -> void:
	if why_simple(AID_COST) != "": return
	Game.money -= AID_COST
	if prel.has(p):
		change_prel(p, 10)
	else:
		Diplo.change_rel(p, 12)
	_add_news("%s ga insonparvarlik yordami yuborildi. Hamdardlik oshdi." % pname(p), "good", "Diplomatiya")
	Game.changed.emit()


func why_op(c: String) -> String:
	if not has_center(): return "Siyosiy markaz kerak"
	for o in ops:
		if o["country"] == c: return "Operatsiya davom etmoqda (%d kun)" % o["days"]
	if Game.money < 300: return "Pul yetmaydi (boshlash 300 $)"
	return ""


func start_op(c: String) -> void:
	if why_op(c) != "": return
	Game.money -= 300
	ops.append({"country": c, "days": OP_DAYS})
	Game.message.emit("Maxfiy operatsiya: %s hududida muxolifat moliyalashtirilmoqda (%d kun, kuniga %d $)." % [pname(c), OP_DAYS, int(OP_DAILY)], "event")
	Game.changed.emit()


func _tick_ops() -> void:
	for o in ops.duplicate():
		Game.money -= OP_DAILY
		o["days"] -= 1
		var c: String = o["country"]
		if _rng.randf() < 0.012:
			ops.erase(o)
			Diplo.change_rel(c, -40)
			_add_news("FOSH BO'LDI: %s razvedkasi sizning agentlaringizni qo'lga oldi! Munosabat keskin yomonlashdi." % pname(c), "bad", "Maxfiy")
			continue
		if o["days"] <= 0:
			ops.erase(o)
			var cand: Array = []
			for id in Game.province_order:
				if Game.provinces[id]["owner"] == c:
					cand.append(id)
			if cand.size() <= 1:
				continue
			var id2: String = cand[_rng.randi() % cand.size()]
			var p: Dictionary = Game.provinces[id2]
			p["owner"] = Game.REBEL
			p["defense"] = p["max_defense"] * 0.35
			_add_news("%s hududida qo'zg'olon: %s markaziy hukumatdan ajraldi! Hudud zaif - egallash imkoniyati." % [pname(c), p["name"]], "event", "Maxfiy")
			Game.changed.emit()


func _hostile_action() -> void:
	## Tuzumimizni yoqtirmagan yirik davlatlar faol bosim o'tkazadi
	var foes: Array = []
	for p in powers():
		if prel[p] < -25.0 and float(data["powers"][p]["subversion"]) > 0.2:
			foes.append(p)
	var mine := Game.player_provinces()
	if foes.is_empty() or mine.is_empty():
		return
	var p: String = foes[_rng.randi() % foes.size()]
	var prov: Dictionary = Game.provinces[mine[_rng.randi() % mine.size()]]
	match _rng.randi_range(0, 3):
		0:
			prov["unrest"] = minf(100.0, prov["unrest"] + 12.0)
			influence[p] = minf(100.0, influence[p] + 5.0)
			_add_news("%s: xorijdan moliyalashtirilgan namoyishlar boshlandi. Ortida %s turgani aytilmoqda (norozilik +12)." % [prov["name"], pname(p)], "bad", "Bosim")
		1:
			support = maxf(0.0, support - 6.0)
			_add_news("%s OAVlari hukumatingizga qarshi axborot kampaniyasi boshladi (xalq qo'llovi -6)." % pname(p), "bad", "Bosim")
		2:
			for c in contracts.duplicate():
				if c["power"] != p:
					contracts.erase(c)
					_add_news("%s bosimi ostida %s shartnomani bekor qildi." % [pname(p), pname(c["power"])], "bad", "Bosim")
					return
			influence[p] = minf(100.0, influence[p] + 8.0)
			_add_news("%s muxolifat yetakchilarini o'z poytaxtida qabul qildi va 'surgundagi hukumat'ni tan oldi." % pname(p), "bad", "Bosim")
		3:
			if float(data["powers"][p]["economy"]) >= 40.0 and not sanctioned_by(p):
				_impose(p, "davlat tuzumi va inson huquqlari")
			else:
				Game.money -= minf(Game.money * 0.1, 800.0)
				_add_news("%s xorijdagi aktivlaringizni muzlatdi." % pname(p), "bad", "Bosim")


# ---------------------------------------------------------------- yirik davlatlarning takliflari

func _power_offer() -> void:
	var opts: Array = []
	if prel["USA"] > 10.0 and not sanctioned_by("USA") and not licenses.has("drone"):
		opts.append("usa")
	if prel["RUS"] > 0.0:
		opts.append("rus")
	if prel["CHN"] > -10.0:
		opts.append("chn")
	if prel["IRN"] > -10.0:
		opts.append("irn")
	if prel["TUR"] > 0.0 and not licenses.has("apc"):
		opts.append("tur")
	if ideology in ["islamic", "secular"] and prel["SAU"] > 0.0:
		opts.append("sau")
	if ideology != "democracy" and pending_ideology == "" and prel["EU"] > -30.0:
		opts.append("eu")
	if opts.is_empty():
		return
	match opts[_rng.randi() % opts.size()]:
		"usa":
			Diplo.proposal.emit("AQSh TAKLIFI\n\nVashington Rossiyadan qurol sotib olmaslik va'dasi evaziga zarba droni ishlab chiqarish litsenziyasini BEPUL beradi.\n\nQabul: dron litsenziyasi, AQSh +15, Rossiya -20.",
				func():
					licenses["drone"] = "USA"; change_prel("USA", 15); change_prel("RUS", -20)
					_add_news("AQSh bilan mudofaa memorandumi: dron litsenziyasi olindi.", "good", "Diplomatiya"),
				func(): change_prel("USA", -3))
		"rus":
			Diplo.proposal.emit("ROSSIYA TAKLIFI\n\nMoskva hududingizda harbiy baza joylashtirishni so'rayapti. Evaziga: 3 ta zenit-raketa majmuasi va 2000 $.\n\nQabul: Rossiya +20, AQSh -20, Yevropa -15.\nRad: Rossiya -8.",
				func():
					arsenal["sam"] += 3; Game.money += 2000
					change_prel("RUS", 20); change_prel("USA", -20); change_prel("EU", -15)
					_add_news("Rossiya harbiy bazasi ochildi. G'arb xavotirda.", "event", "Diplomatiya"),
				func(): change_prel("RUS", -8))
		"chn":
			Diplo.proposal.emit("XITOY TAKLIFI ('Kamar va yo'l')\n\nPekin temir yo'l va zavodlar uchun 3000 $ kredit beradi. 120 kundan keyin 3600 $ qaytarasiz. To'lay olmasangiz - hudud yoki sanksiya.\n\nQabul: +3000 $, Xitoy +10.",
				func():
					Game.money += 3000
					Diplo.debts.append({"country": "CHN", "amount": 3600.0, "due": Game.day + 120, "day": Game.day})
					change_prel("CHN", 10)
					_add_news("Xitoy bilan infratuzilma krediti imzolandi (3000 $).", "info", "Diplomatiya"),
				func(): change_prel("CHN", -4))
		"irn":
			Diplo.proposal.emit("ERON TAKLIFI\n\nTehron blokadani chetlab o'tish uchun bug'doy evaziga arzon neft almashuvini taklif qilmoqda. Sizga +1500 $ foyda.\n\nOgohlantirish: AQSh sanksiyalari ostidagi davlat bilan savdo. AQSh -18, 35% ehtimol bilan AQSh sanksiyasi.",
				func():
					Game.money += 1500; change_prel("IRN", 15); change_prel("USA", -18)
					if _rng.randf() < 0.35:
						_impose("USA", "Eron bilan savdo")
					else:
						_add_news("Eron bilan yashirin neft almashuvi amalga oshdi.", "event", "Savdo"),
				func(): change_prel("IRN", -5))
		"tur":
			Diplo.proposal.emit("TURKIYA TAKLIFI\n\nTurkiy davlatlar tashkiloti doirasida qo'shma mashg'ulot va BTR ishlab chiqarish litsenziyasi (750 $, yarim narx).\n\nQabul: BTR litsenziyasi, Turkiya +12.",
				func():
					if Game.money >= 750:
						Game.money -= 750; licenses["apc"] = "TUR"; change_prel("TUR", 12)
						_add_news("Turkiya bilan mudofaa sanoati hamkorligi: BTR litsenziyasi.", "good", "Diplomatiya"),
				func(): pass)
		"sau":
			Diplo.proposal.emit("SAUDIYA ARABISTONI TAKLIFI\n\nAr-Riyod masjidlar, maktablar va kasalxonalar qurish uchun 2000 $ grant taklif qilmoqda.\n\nQabul: +2000 $, Saudiya +10, xalq qo'llovi +5, AQSh -3.",
				func():
					Game.money += 2000; change_prel("SAU", 10); change_prel("USA", -3)
					support = minf(100.0, support + 5.0)
					_add_news("Saudiya granti qabul qilindi.", "good", "Diplomatiya"),
				func(): pass)
		"eu":
			Diplo.proposal.emit("YEVROPA ITTIFOQI TAKLIFI\n\nBryussel demokratik islohotlar evaziga 2500 $ yordam beradi. Shart: davlat tuzumi Demokratiyaga o'zgaradi (60 kun o'tish davri, bepul).\n\nQabul: +2500 $, Yevropa +15, AQSh +10, Rossiya va Xitoy -10.",
				func():
					Game.money += 2500
					pending_ideology = "democracy"; ideology_days = IDEOLOGY_CHANGE_DAYS
					change_prel("EU", 15); change_prel("USA", 10); change_prel("RUS", -10); change_prel("CHN", -10)
					_add_news("Yevropa Ittifoqi bilan islohot shartnomasi: demokratiyaga o'tish boshlandi.", "event", "Diplomatiya"),
				func(): change_prel("EU", -3))
	Game.changed.emit()


# ---------------------------------------------------------------- onlayn yangiliklar (RSS)

const RULES := [
	{"k": ["iran", "hormuz", "tehran"], "res": "neft", "d": 0.08, "note": "Neft narxi ko'tarildi"},
	{"k": ["ceasefire", "truce", "peace deal", "peace talks"], "res": "neft", "d": -0.06, "note": "Tinchlik umidi: neft arzonladi"},
	{"k": ["gold"], "res": "tilla", "d": 0.06, "note": "Oltin narxi o'zgardi"},
	{"k": ["gas", "lng", "pipeline"], "res": "gaz", "d": 0.06, "note": "Gaz narxi ko'tarildi"},
	{"k": ["wheat", "grain", "famine"], "res": "bugdoy", "d": 0.06, "note": "Don narxi ko'tarildi"},
	{"k": ["copper", "tariff", "trade war"], "res": "mis", "d": -0.04, "note": "Savdo urushi: mis arzonladi"},
	{"k": ["taliban", "afghanistan", "kabul"], "country": "AFG", "note": "Afg'oniston beqaror"},
	{"k": ["uzbekistan", "kazakhstan", "tajikistan", "kyrgyz", "turkmen", "central asia"], "note": "Mintaqa yangiligi"},
	{"k": ["russia", "ukraine", "kremlin", "putin"], "note": "Rossiya-Ukraina"},
	{"k": ["sanction"], "note": "Sanksiyalar"},
	{"k": ["china", "beijing", "xi jinping"], "note": "Xitoy"},
]


func _process(delta: float) -> void:
	if not Game.started or Game.era < 4:
		return
	_feed_timer -= delta
	if _feed_timer <= 0.0:
		_feed_timer = FEED_INTERVAL
		_feed_i = 0
		_fetch_next()


func _fetch_next() -> void:
	if _feed_i >= FEEDS.size():
		return
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_http.cancel_request()
	var err := _http.request(FEEDS[_feed_i])
	if err != OK:
		_feed_i += 1
		_fetch_next()


func _on_feed(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	_feed_i += 1
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		if not online_ok:
			online_ok = true
			_add_news("Real dunyo yangiliklariga ulandi - o'yin jahon voqealariga qarab o'zgaradi.", "good", "Onlayn")
		parse_feed(body.get_string_from_utf8(), 6)
	_fetch_next()


func parse_feed(xml: String, limit: int) -> int:
	var re := RegEx.new()
	re.compile("<item>[\\s\\S]*?<title>(?:<!\\[CDATA\\[)?([\\s\\S]*?)(?:\\]\\]>)?</title>")
	var n := 0
	for m in re.search_all(xml):
		if n >= limit:
			break
		var title := m.get_string(1).strip_edges().replace("&amp;", "&").replace("&#39;", "'").replace("&quot;", "\"")
		if title == "" or _seen.has(title):
			continue
		_seen[title] = true
		n += 1
		_apply_headline(title)
	return n


func _apply_headline(title: String) -> void:
	var low := title.to_lower()
	var notes: Array = []
	for r in RULES:
		var hit := false
		for k in r["k"]:
			if low.contains(k):
				hit = true
				break
		if not hit:
			continue
		notes.append(r["note"])
		if r.has("res"):
			var res: String = r["res"]
			var cur: float = Game.price_mult[res]["mult"] if Game.price_mult.has(res) else 1.0
			Game.price_mult[res] = {"mult": clampf(cur + float(r["d"]), 0.5, 2.5), "days": 30}
		if r.has("country"):
			for id in Game.province_order:
				var p: Dictionary = Game.provinces[id]
				if p["owner"] == r["country"]:
					p["defense"] = maxf(p["max_defense"] * 0.7, p["defense"] - p["max_defense"] * 0.05)
	if notes.is_empty():
		return
	news.push_front({"day": Game.day, "text": title + "  ->  " + ", ".join(notes), "kind": "event", "tag": "Onlayn"})
	news_added.emit()


# ---------------------------------------------------------------- saqlash

func to_dict() -> Dictionary:
	return {"ideology": ideology, "pending": pending_ideology, "idays": ideology_days, "support": support,
		"influence": influence, "ci": counter_intel, "prel": prel, "psanction": psanction, "licenses": licenses,
		"arsenal": arsenal, "production": production, "imports": imports, "contracts": contracts, "ops": ops,
		"news": news.slice(0, 40), "tl": timeline_idx, "black_disc": black_disc, "next_offer": next_offer,
		"next_election": next_election, "next_hostile": next_hostile, "coup_cd": coup_cooldown, "prop": propaganda_days}


func from_dict(d: Dictionary) -> void:
	if d.is_empty():
		return
	ideology = d["ideology"]
	pending_ideology = d["pending"]
	ideology_days = int(d["idays"])
	support = float(d["support"])
	counter_intel = int(d["ci"])
	for p in d["influence"]: influence[p] = float(d["influence"][p])
	for p in d["prel"]: prel[p] = float(d["prel"][p])
	psanction = {}
	for p in d["psanction"]: psanction[p] = int(d["psanction"][p])
	licenses = d["licenses"]
	for w in d["arsenal"]: arsenal[w] = int(d["arsenal"][w])
	production = []
	for x in d["production"]: production.append({"weapon": x["weapon"], "n": int(x["n"]), "days": int(x["days"])})
	imports = []
	for x in d["imports"]: imports.append({"weapon": x["weapon"], "n": int(x["n"]), "days": int(x["days"]), "from": x["from"], "black": bool(x["black"])})
	contracts = []
	for x in d["contracts"]: contracts.append({"power": x["power"], "res": x["res"], "days": int(x["days"])})
	ops = []
	for x in d["ops"]: ops.append({"country": x["country"], "days": int(x["days"])})
	news = d["news"]
	timeline_idx = int(d["tl"])
	black_disc = d["black_disc"]
	next_offer = int(d["next_offer"])
	next_election = int(d["next_election"])
	next_hostile = int(d.get("next_hostile", 30))
	coup_cooldown = int(d["coup_cd"])
	propaganda_days = int(d["prop"])
