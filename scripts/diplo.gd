extends Node
## Diplomatiya (autoload: Diplo)
## Munosabatlar, savdo shartnomalari, qarzlar, defolt, global sanksiya, qora bozor,
## askar ijarasi, qurol sotish va bot-davlatlarning o'z takliflari.

signal proposal(text: String, accept: Callable, decline: Callable)   # UI so'rov oynasini ko'rsatadi
signal open_window(country: String)

const LOAN_DAYS := 60
const LOAN_RATE := 0.10           # biz olgan qarz foizi
const LEND_DAYS := 90
const LEND_RATE := 0.15           # biz bergan qarz foizi
const SANCTION_DAYS := 120
const RENT_PRICE := 8             # 1 askar ijarasi (60 kun)
const RENT_DAYS := 60
const LEND_SOLDIER_PRICE := 12    # askar berganda olinadigan pul
const TANK_SALE_PRICE := 450
const GIFT := 500
const BLACK_SOLDIER := 30         # 10 askar = 300 $ (3x)
const BLACK_TANK := 900           # 3x
const BLACK_DAYS := 5
const BLACK_SEIZE := 0.25

var rel := {}            # davlat -> munosabat (-100..100)
var treasury := {}       # davlat -> pul
var trade := {}          # davlat -> true (savdo shartnomasi)
var alliance := {}       # davlat -> true
var transit := {}        # davlat -> true (havo hududidan o'tish ruxsati)
const TRANSIT_PRICE := 300
var debts: Array = []    # biz olgan qarzlar  {country, due, amount, day}
var credits: Array = []  # biz bergan qarzlar {country, due, amount, day}
var leases: Array = []   # {kind: "in"/"out", country, soldiers, province, days}
var black: Array = []    # qora bozor yetkazmalari {province, soldiers, tanks, days}
var sanction_days := 0
var defaulted := 0       # necha marta defolt qilgan
var next_offer := 30
var inbox: Array = []
var border_mode := {}    # davlat -> "open" (vizasiz) / "normal" / "closed" (yopiq)    # diplomatik xabarlar qutisi {text, yes, no, day, expire, from}
const INBOX_DAYS := 20
const URGENT := ["TO'NTARISH", "DEFOLT", "YADRO", "JANG"]
var _rng := RandomNumberGenerator.new()
# 1-2-zamon: ittifoqchilar bilan askar almashuvi
var aid_in: Array = []      # kelayotgan yordam {country, days, army: {tur: son}}
var aid_out: Array = []     # ittifoqchiga yuborilgan askarlar {country, days, army}
var help_cd := {}           # davlat -> qaysi kungacha yana yordam so'rab bo'lmaydi
const OLD_GIFT := 100
const GOODS_PRICE := {"oziq": 0.5, "yogoch": 0.6, "tosh": 0.7}   # 1 birlik narxi (oltin), sotib olish 1.4x


func _ready() -> void:
	_rng.randomize()
	init_world()
	Game.day_passed.connect(_on_day)


func init_world() -> void:
	rel.clear(); treasury.clear(); trade.clear(); alliance.clear(); transit.clear()
	debts.clear(); credits.clear(); leases.clear(); black.clear(); inbox.clear()
	aid_in.clear(); aid_out.clear(); help_cd.clear()
	sanction_days = 0
	next_offer = 30
	for c in Game.countries:
		rel[c] = _rng.randi_range(-10, 25)
		treasury[c] = float(country_pop(c)) * 0.6


func on_game_started(home_country: String) -> void:
	rel[home_country] = 50


# ---------------------------------------------------------------- yordamchi

func country_pop(c: String) -> int:
	var t := 0
	for id in Game.province_order:
		if Game.provinces[id]["owner"] == c:
			t += Game.provinces[id]["population"]
	return t


func country_provinces(c: String) -> Array:
	var out: Array = []
	for id in Game.province_order:
		if Game.provinces[id]["owner"] == c:
			out.append(id)
	return out


func alive(c: String) -> bool:
	return not country_provinces(c).is_empty()


func sanctioned() -> bool:
	return sanction_days > 0


func borders_player(c: String) -> bool:
	for id in country_provinces(c):
		for n in Game.provinces[id]["neighbors"]:
			if Game.provinces[n]["owner"] == Game.PLAYER:
				return true
	return false


func trade_value(c: String) -> float:
	var k := 1.0
	match border_mode.get(c, "normal"):
		"open": k = 1.2
		"closed": k = 0.5
	if Game.era < 4:
		return minf(30.0, roundf((3.0 + sqrt(float(country_pop(c))) * 0.1) * k))
	return minf(180.0, roundf((5.0 + sqrt(float(country_pop(c))) * 0.12) * Tech.mult("trade") * k))


func trade_income() -> float:
	var t := 0.0
	for c in trade:
		t += trade_value(c)
	return t


func why_border_mode(c: String, mode: String) -> String:
	if border_mode.get(c, "normal") == mode: return "Hozirgi rejim"
	if War.wars.has(c) and mode != "closed": return "Urush paytida chegara yopiq"
	if mode == "open" and rel.get(c, 0.0) < 25.0: return "Vizasiz rejim uchun munosabat kamida 25 bo'lishi kerak"
	return ""


func set_border_mode(c: String, mode: String) -> void:
	if why_border_mode(c, mode) != "":
		return
	border_mode[c] = mode
	match mode:
		"open":
			change_rel(c, 10)
			Game.message.emit("%s bilan VIZASIZ rejim: odamlar va yuklar erkin o'tadi. Savdo +20%%, munosabat yaxshilanadi (kontrabanda xavfi oshadi)." % War.country_name(c), "good")
		"closed":
			change_rel(c, -15)
			Game.message.emit("%s bilan chegara YOPILDI: kirib-chiqish to'xtatildi, savdo -50%%, xavfsizlik oshdi." % War.country_name(c), "event")
		_:
			Game.message.emit("%s bilan chegara oddiy rejimga qaytdi." % War.country_name(c), "info")
	Game.changed.emit()


func is_urgent(text: String) -> bool:
	for u in URGENT:
		if text.begins_with(u):
			return true
	return false


func post(text: String, yes: Callable, no: Callable) -> void:
	var sender := ""
	var first := text.split("\n")[0].to_lower()
	for c in Game.countries:
		if first.contains(Game.countries[c]["name"].to_lower().left(5)):
			sender = c
	for p in Politics.powers():
		if first.contains(Politics.pname(p).to_lower().left(5)):
			sender = p
	inbox.append({"text": text, "yes": yes, "no": no, "day": Game.day, "expire": Game.day + INBOX_DAYS, "from": sender})
	Game.message.emit("Yangi diplomatik xabar: " + text.split("\n")[0].trim_suffix(":"), "event")
	Game.changed.emit()


func answer(i: int, accept: bool) -> void:
	if i < 0 or i >= inbox.size():
		return
	var m: Dictionary = inbox[i]
	inbox.remove_at(i)
	var cb: Callable = m["yes"] if accept else m["no"]
	if cb.is_valid():
		cb.call()
	Game.changed.emit()


func change_rel(c: String, d: float) -> void:
	if rel.has(c):
		rel[c] = clampf(rel[c] + d, -100.0, 100.0)


func rel_text(c: String) -> String:
	var r: float = rel[c]
	if War.wars.has(c): return "Urush"
	if alliance.has(c): return "Ittifoqchi"
	if r >= 60: return "Do'st"
	if r >= 25: return "Iliq"
	if r >= -10: return "Betaraf"
	if r >= -50: return "Sovuq"
	return "Dushman"


func max_loan(c: String) -> int:
	if sanctioned() or War.wars.has(c) or rel[c] < 0:
		return 0
	var cap: float = treasury[c] * 0.3 * (1.0 + rel[c] / 100.0)
	if defaulted > 0:
		cap *= 0.3
	cap *= Tech.mult("loan")
	return int(minf(cap, 20000.0) / 500.0) * 500


func debt_total() -> float:
	var t := 0.0
	for d in debts:
		t += d["amount"]
	return t


# ---------------------------------------------------------------- tekshiruvlar (bo'sh satr = mumkin)

func why_trade(c: String) -> String:
	if trade.has(c): return "Shartnoma bor"
	if War.wars.has(c): return "Urush holatidasiz"
	if sanctioned(): return "Sanksiya ostidasiz"
	if rel[c] < 0: return "Munosabat kamida 0 bo'lishi kerak"
	return ""


func why_transit(c: String) -> String:
	if transit.has(c) or alliance.has(c): return "Ruxsat bor"
	if War.wars.has(c): return "Urush holatidasiz"
	if sanctioned(): return "Sanksiya ostidasiz"
	if rel[c] < 10: return "Munosabat kamida 10 bo'lishi kerak"
	if Game.money < TRANSIT_PRICE: return "Pul yetmaydi"
	return ""


func buy_transit(c: String) -> void:
	if why_transit(c) != "":
		return
	Game.money -= TRANSIT_PRICE
	treasury[c] += TRANSIT_PRICE
	transit[c] = true
	Game.message.emit("%s havo hududidan o'tish (tranzit) ruxsati olindi." % War.country_name(c), "good")
	Game.changed.emit()


func why_alliance(c: String) -> String:
	if alliance.has(c): return "Ittifoq bor"
	if War.wars.has(c): return "Urush holatidasiz"
	if rel[c] < (45 if Game.era < 4 else 60): return "Munosabat kamida %d bo'lishi kerak" % (45 if Game.era < 4 else 60)
	return ""


func why_borrow(c: String, amount: int) -> String:
	if sanctioned(): return "Sanksiya ostida hech kim qarz bermaydi"
	if War.wars.has(c): return "Urush holatidasiz"
	if amount > max_loan(c): return "%s bunchalik qarz bermaydi (max %d $)" % [War.country_name(c), max_loan(c)]
	return ""


func why_lend(c: String, amount: int) -> String:
	if War.wars.has(c): return "Urush holatidasiz"
	if Game.money < amount: return "Pul yetmaydi"
	for cr in credits:
		if cr["country"] == c: return "Avvalgi qarz hali qaytarilmagan"
	return ""


func why_rent(c: String, n: int) -> String:
	if War.wars.has(c): return "Urush holatidasiz"
	if sanctioned(): return "Sanksiya ostidasiz"
	if rel[c] < 20: return "Munosabat kamida 20 bo'lishi kerak"
	if Game.money < n * RENT_PRICE: return "Pul yetmaydi"
	if target_province() == "": return "Provinsiya yo'q"
	return ""


func why_lend_soldiers(c: String, n: int) -> String:
	if War.wars.has(c): return "Urush holatidasiz"
	var p := target_province()
	if p == "" or Game.provinces[p]["units"]["soldier"] < n:
		return "Tanlangan provinsiyada %d askar yo'q" % n
	return ""


func why_sell_tanks(c: String, n: int) -> String:
	if War.wars.has(c): return "Urush holatidasiz"
	if sanctioned(): return "Sanksiya: qurol savdosi taqiqlangan"
	if rel[c] < 0: return "Munosabat kamida 0 bo'lishi kerak"
	var p := target_province()
	if p == "" or Game.provinces[p]["units"]["tank"] < n:
		return "Tanlangan provinsiyada %d tank yo'q" % n
	if treasury[c] < n * TANK_SALE_PRICE: return "Ularda pul yo'q"
	return ""


func target_province() -> String:
	## Askar keladigan/ketadigan provinsiya: tanlangan o'z provinsiyangiz, bo'lmasa eng kuchli garnizon
	var sel := Game.selected_id
	if sel != "" and Game.provinces[sel]["owner"] == Game.PLAYER:
		return sel
	var best := ""
	var bp := -1.0
	for id in Game.player_provinces():
		var gp := War.garrison_power(Game.provinces[id])
		if gp > bp:
			bp = gp
			best = id
	return best


# ---------------------------------------------------------------- harakatlar

func sign_trade(c: String) -> void:
	if why_trade(c) != "":
		return
	if rel[c] < 30 and _rng.randf() < 0.3:
		change_rel(c, -3)
		Game.message.emit("%s savdo shartnomasini rad etdi. Munosabatni yaxshilang." % War.country_name(c), "bad")
	else:
		trade[c] = true
		change_rel(c, 5)
		Game.message.emit("%s bilan savdo shartnomasi imzolandi: +%d %s/kun." % [War.country_name(c), trade_value(c), cur()], "good")
	Game.changed.emit()


func cancel_trade(c: String) -> void:
	trade.erase(c)
	change_rel(c, -10)
	Game.message.emit("%s bilan savdo shartnomasi bekor qilindi." % War.country_name(c), "info")
	Game.changed.emit()


func sign_alliance(c: String) -> void:
	if why_alliance(c) != "":
		return
	alliance[c] = true
	change_rel(c, 10)
	Game.message.emit("%s bilan harbiy ittifoq tuzildi! Hujumga uchrasangiz yordam yuboradi." % War.country_name(c), "good")
	Game.changed.emit()


func cur() -> String:
	return "oltin" if Game.era < 4 else "$"


func gift_cost() -> int:
	return OLD_GIFT if Game.era < 4 else GIFT


func send_gift(c: String) -> void:
	var gc := gift_cost()
	if Game.money < gc:
		return
	Game.money -= gc
	treasury[c] += gc
	change_rel(c, 10)
	Game.message.emit("%s ga %d %s sovg'a yuborildi. Munosabat yaxshilandi." % [War.country_name(c), gc, cur()], "good")
	Game.changed.emit()


func borrow(c: String, amount: int) -> void:
	if why_borrow(c, amount) != "":
		return
	treasury[c] -= amount
	Game.money += amount
	var due := roundf(amount * (1.0 + LOAN_RATE))
	debts.append({"country": c, "amount": due, "due": Game.day + LOAN_DAYS, "day": Game.day})
	Game.message.emit("%s dan %d $ qarz olindi. %d kundan keyin %d $ qaytarish kerak." % [War.country_name(c), amount, LOAN_DAYS, int(due)], "info")
	Game.changed.emit()


func repay(i: int) -> void:
	if i < 0 or i >= debts.size():
		return
	var d: Dictionary = debts[i]
	if Game.money < d["amount"]:
		Game.message.emit("Qarzni to'lash uchun pul yetmaydi.", "bad")
		return
	Game.money -= d["amount"]
	treasury[d["country"]] += d["amount"]
	change_rel(d["country"], 5)
	debts.remove_at(i)
	Game.message.emit("%s ga qarz to'liq qaytarildi." % War.country_name(d["country"]), "good")
	Game.changed.emit()


func lend(c: String, amount: int) -> void:
	if why_lend(c, amount) != "":
		return
	Game.money -= amount
	treasury[c] += amount
	change_rel(c, 8)
	credits.append({"country": c, "amount": roundf(amount * (1.0 + LEND_RATE)), "due": Game.day + LEND_DAYS, "day": Game.day})
	Game.message.emit("%s ga %d $ qarz berildi. %d kundan keyin %d $ qaytaradi (yoki provinsiya beradi)." % [War.country_name(c), amount, LEND_DAYS, int(amount * (1.0 + LEND_RATE))], "info")
	Game.changed.emit()


func rent_soldiers(c: String, n: int) -> void:
	if why_rent(c, n) != "":
		return
	var p := target_province()
	Game.money -= n * RENT_PRICE
	treasury[c] += n * RENT_PRICE
	Game.provinces[p]["units"]["soldier"] += n
	leases.append({"kind": "in", "country": c, "soldiers": n, "province": p, "days": RENT_DAYS})
	change_rel(c, 2)
	Game.message.emit("%s dan %d askar ijaraga olindi -> %s (%d kun)." % [War.country_name(c), n, Game.provinces[p]["name"], RENT_DAYS], "good")
	Game.changed.emit()


func lend_soldiers(c: String, n: int) -> void:
	if why_lend_soldiers(c, n) != "":
		return
	var p := target_province()
	Game.provinces[p]["units"]["soldier"] -= n
	Game.money += n * LEND_SOLDIER_PRICE
	leases.append({"kind": "out", "country": c, "soldiers": n, "province": p, "days": RENT_DAYS})
	change_rel(c, 8)
	Game.message.emit("%d askar %s ga ijaraga berildi: +%d $. %d kundan keyin qaytadi." % [n, War.country_name(c), n * LEND_SOLDIER_PRICE, RENT_DAYS], "good")
	Game.changed.emit()


func sell_tanks(c: String, n: int) -> void:
	if why_sell_tanks(c, n) != "":
		return
	var p := target_province()
	Game.provinces[p]["units"]["tank"] -= n
	Game.money += n * TANK_SALE_PRICE
	treasury[c] -= n * TANK_SALE_PRICE
	change_rel(c, 4)
	# sotilgan tanklar o'sha davlat mudofaasini kuchaytiradi
	var provs := country_provinces(c)
	if not provs.is_empty():
		var q: Dictionary = Game.provinces[provs[_rng.randi() % provs.size()]]
		q["defense"] += n * War.TANK_POWER
		q["max_defense"] += n * War.TANK_POWER * 0.5
	Game.message.emit("%s ga %d tank sotildi: +%d $." % [War.country_name(c), n, n * TANK_SALE_PRICE], "good")
	Game.changed.emit()


func black_market(soldiers: int, tanks: int) -> void:
	var cost := soldiers * BLACK_SOLDIER + tanks * BLACK_TANK
	var p := target_province()
	if Game.money < cost or p == "":
		return
	Game.money -= cost
	black.append({"province": p, "soldiers": soldiers, "tanks": tanks, "days": BLACK_DAYS})
	Game.message.emit("Qora bozor: kontrabanda %d kunda %s ga yetkaziladi (himoyasiz!)." % [BLACK_DAYS, Game.provinces[p]["name"]], "event")
	Game.changed.emit()


func on_war_declared(c: String, by_enemy: bool) -> void:
	trade.erase(c)
	transit.erase(c)
	alliance.erase(c)
	rel[c] = -100.0
	if not by_enemy:
		# bosqinchilik boshqalarga yoqmaydi
		for o in rel:
			if o != c:
				change_rel(o, -8)


# ---------------------------------------------------------------- kunlik

func _on_day(_d: int) -> void:
	Game.money += trade_income()
	for c in treasury:
		treasury[c] += country_pop(c) * 0.003
	if sanction_days > 0:
		sanction_days -= 1
		if sanction_days == 0:
			Game.message.emit("Global sanksiyalar bekor qilindi. Savdo yo'llari yana ochiq.", "good")
	_drift()
	if Game.era < 4:
		_old_daily()
	_check_debts()
	_check_credits()
	_check_leases()
	_check_black()
	_bot_initiative()
	for m in inbox.duplicate():
		if Game.day >= m["expire"]:
			inbox.erase(m)
			if m["no"].is_valid():
				m["no"].call()
			Game.message.emit("Javobsiz qolgan xabar rad etildi: " + m["text"].split("\n")[0].trim_suffix(":"), "info")


func _drift() -> void:
	for c in rel:
		if War.wars.has(c):
			continue
		var target := 10.0
		if trade.has(c): target += 25.0
		if alliance.has(c): target += 30.0
		if sanctioned(): target -= 30.0
		target += Politics.regional_bias(c) if Game.era >= 4 else 0.0
		match border_mode.get(c, "normal"):
			"open": target += 12.0
			"closed": target -= 12.0
		rel[c] = move_toward(rel[c], target, 0.15)


func _check_debts() -> void:
	for d in debts.duplicate():
		if Game.day < d["due"]:
			continue
		if Game.money >= d["amount"]:
			Game.money -= d["amount"]
			treasury[d["country"]] += d["amount"]
			change_rel(d["country"], 5)
			debts.erase(d)
			Game.message.emit("%s ga qarz (%d $) avtomatik qaytarildi." % [War.country_name(d["country"]), int(d["amount"])], "info")
		else:
			debts.erase(d)
			_default(d)


func _default(d: Dictionary) -> void:
	var c: String = d["country"]
	defaulted += 1
	var prov := _province_to_give(c)
	var text := "DEFOLT! %s ga %d $ qarzni qaytara olmadingiz.\n\n" % [War.country_name(c), int(d["amount"])]
	if prov != "":
		text += "Kafolat sifatida %s provinsiyasini berasizmi?\n\nRad etsangiz, sizga %d kunlik GLOBAL SANKSIYA qo'llanadi:\n- barcha savdo shartnomalari bekor bo'ladi\n- resurslar yarim narxda sotiladi\n- hech kim qarz va askar bermaydi\n- qurolni faqat qora bozordan 3 barobar qimmatga olasiz" % [Game.provinces[prov]["name"], SANCTION_DAYS]
		proposal.emit(text, _give_province.bind(c, prov), _impose_sanctions.bind(c))
	else:
		_impose_sanctions(c)


func _province_to_give(c: String) -> String:
	var mine := Game.player_provinces()
	if mine.size() <= 1:
		return ""
	var best := ""
	var best_pop := INF
	for id in mine:
		var p: Dictionary = Game.provinces[id]
		var near := false
		for n in p["neighbors"]:
			if Game.provinces[n]["owner"] == c:
				near = true
		var score: float = p["population"] - (100000.0 if near else 0.0)
		if score < best_pop:
			best_pop = score
			best = id
	return best


func _give_province(c: String, prov: String) -> void:
	var p: Dictionary = Game.provinces[prov]
	p["owner"] = c
	p["orders"].clear()
	p["units"] = {"soldier": 0, "tank": 0}
	p["defense"] = p["max_defense"] * 0.5
	change_rel(c, 10)
	Game.message.emit("%s qarz evaziga %s ga o'tkazildi." % [p["name"], War.country_name(c)], "bad")
	if Game.selected_id == prov:
		Game.select(prov)
	Game.changed.emit()


func impose_sanctions_days(days: int, who: String) -> void:
	sanction_days = maxi(sanction_days, days)
	trade.clear()
	transit.clear()
	Game.message.emit("%s GLOBAL SANKSIYA e'lon qildi: %d kun savdo yo'q, resurslar arzon, qarz va tranzit yo'q." % [who, days], "bad")
	Game.changed.emit()


func _impose_sanctions(c: String) -> void:
	sanction_days = SANCTION_DAYS
	transit.clear()
	trade.clear()
	for o in rel:
		change_rel(o, -25)
	change_rel(c, -30)
	Game.message.emit("GLOBAL SANKSIYA! %d kun: savdo to'xtadi, resurslar arzonladi. Qora bozor ochildi." % SANCTION_DAYS, "bad")
	Game.changed.emit()


func _check_credits() -> void:
	for cr in credits.duplicate():
		if Game.day < cr["due"]:
			continue
		credits.erase(cr)
		var c: String = cr["country"]
		if not alive(c):
			continue
		var pay_chance := clampf(treasury[c] / (cr["amount"] * 3.0), 0.3, 0.9)
		if treasury[c] >= cr["amount"] and _rng.randf() < pay_chance:
			treasury[c] -= cr["amount"]
			Game.money += cr["amount"]
			Game.message.emit("%s qarzini foizi bilan qaytardi: +%d $." % [War.country_name(c), int(cr["amount"])], "good")
		else:
			var provs := country_provinces(c)
			# eng kam aholili provinsiya kafolat sifatida beriladi
			var give := ""
			var low := INF
			for id in provs:
				if Game.provinces[id]["population"] < low:
					low = Game.provinces[id]["population"]
					give = id
			if give == "" or provs.size() <= 1:
				change_rel(c, -20)
				Game.message.emit("%s qarzni qaytarmadi va berishga yeri ham yo'q!" % War.country_name(c), "bad")
				continue
			var p: Dictionary = Game.provinces[give]
			p["owner"] = Game.PLAYER
			p["unrest"] = 45.0
			p["defense"] = 0.0
			p["militia"] = 0.0
			change_rel(c, -15)
			Game.message.emit("%s defolt qildi va qarz evaziga %s provinsiyasini sizga berdi!" % [War.country_name(c), p["name"]], "event")
	Game.changed.emit()


func _check_leases() -> void:
	for l in leases.duplicate():
		l["days"] -= 1
		if l["days"] > 0:
			continue
		leases.erase(l)
		var p: Dictionary = Game.provinces[l["province"]]
		if l["kind"] == "in":
			var back := minf(l["soldiers"], p["units"]["soldier"]) if p["owner"] == Game.PLAYER else 0.0
			p["units"]["soldier"] -= back
			Game.message.emit("Ijaradagi %d askar %s ga qaytdi." % [int(back), War.country_name(l["country"])], "info")
		else:
			var survived := roundi(l["soldiers"] * _rng.randf_range(0.7, 1.0))
			var home: String = l["province"] if p["owner"] == Game.PLAYER else target_province()
			if home != "":
				Game.provinces[home]["units"]["soldier"] += survived
			Game.message.emit("Ijaraga berilgan askarlardan %d tasi %s dan qaytdi." % [survived, War.country_name(l["country"])], "info")


func _check_black() -> void:
	for b in black.duplicate():
		b["days"] -= 1
		if b["days"] > 0:
			continue
		black.erase(b)
		var p: Dictionary = Game.provinces[b["province"]]
		if p["owner"] != Game.PLAYER or _rng.randf() < BLACK_SEIZE:
			Game.message.emit("Kontrabanda yuki yo'lda talon-taroj qilindi! Pul qaytmaydi.", "bad")
			War.explosion.emit(p["center"], false)
			continue
		p["units"]["soldier"] += b["soldiers"]
		p["units"]["tank"] += b["tanks"]
		Game.message.emit("Qora bozor yuki %s ga yetib keldi: %d askar, %d tank." % [p["name"], b["soldiers"], b["tanks"]], "good")


func on_player_attacked(target: String) -> void:
	## Ittifoqchilar yordam yuboradi
	if Game.era < 4:
		for c in alliance:
			if alive(c) and _rng.randf() < 0.5 + rel[c] / 200.0:
				var help := roundf(8.0 + rel[c] * 0.15)
				Game.provinces[target]["militia"] += help
				Game.message.emit("Ittifoqchi %s %s himoyasiga %d jangchi yubordi!" % [War.country_name(c), Game.provinces[target]["name"], int(help)], "good")
		return
	for c in alliance:
		if not alive(c):
			continue
		var help := roundf(15.0 + rel[c] * 0.3)
		Game.provinces[target]["militia"] += help
		Game.message.emit("Ittifoqchi %s %s himoyasiga %d kuch yubordi!" % [War.country_name(c), Game.provinces[target]["name"], int(help)], "good")


# ---------------------------------------------------------------- 1-2-zamon: oddiy diplomatiya

func home() -> Dictionary:
	## o'yinchining qal'asi bor asosiy viloyati
	var pp := Game.player_provinces()
	for id in pp:
		if Game.provinces[id].has("castle"):
			return Game.provinces[id]
	return Game.provinces[pp[0]] if not pp.is_empty() else {}


func _take_army(n: int) -> Dictionary:
	## qal'a qo'shinidan n ta piyoda (nayzachi, qilichboz, kamonchi tartibida) oladi
	var p := home()
	var out := {}
	if p.is_empty():
		return out
	var a: Dictionary = CastleEco.castle(p)["army"]
	for k in ["nayzachi", "qilichboz", "kamonchi"]:
		var t := mini(n, int(a[k]))
		if t > 0:
			a[k] = int(a[k]) - t
			out[k] = t
			n -= t
	CastleEco.sync(p)
	return out


func _give_army(army: Dictionary) -> void:
	var p := home()
	if p.is_empty():
		return
	var a: Dictionary = CastleEco.castle(p)["army"]
	for k in army:
		a[k] = int(a.get(k, 0)) + int(army[k])
	CastleEco.sync(p)


static func army_n(army: Dictionary) -> int:
	var t := 0
	for k in army:
		t += int(army[k])
	return t


func why_ask_help(c: String) -> String:
	if not alliance.has(c): return "Faqat ittifoqchidan so'rash mumkin"
	if War.wars.is_empty(): return "Siz hech kim bilan urushmayapsiz"
	if Game.day < int(help_cd.get(c, 0)): return "Yaqinda so'radingiz (%d kundan keyin)" % (int(help_cd[c]) - Game.day)
	return ""


func ask_help(c: String) -> void:
	if why_ask_help(c) != "":
		return
	help_cd[c] = Game.day + 60
	if _rng.randf() > 0.35 + rel[c] / 100.0:
		change_rel(c, -3)
		Game.message.emit("%s hozir yordam bera olmasligini aytdi: \"O'zimizning chegaralarimiz ham xavfli.\"" % War.country_name(c), "bad")
		return
	var n := int(8 + rel[c] * 0.25)
	var army := {"nayzachi": n / 2, "qilichboz": n - n / 2}
	if rel[c] >= 70:
		army["otliq"] = 4
	aid_in.append({"country": c, "days": 8, "army": army})
	Game.message.emit("%s yordamga rozi bo'ldi: %d jangchi 8 kunda qal'angizga yetib keladi." % [War.country_name(c), army_n(army)], "good")
	Game.changed.emit()


func why_send_help(c: String, n: int) -> String:
	if not alliance.has(c) and rel.get(c, 0.0) < 30: return "Faqat ittifoqchi yoki do'st davlatga"
	var p := home()
	if p.is_empty(): return "Qal'angiz yo'q"
	var a: Dictionary = CastleEco.castle(p)["army"]
	if int(a["nayzachi"]) + int(a["qilichboz"]) + int(a["kamonchi"]) < n: return "Qal'ada piyoda askar yetmaydi"
	return ""


func send_help(c: String, n: int) -> void:
	if why_send_help(c, n) != "":
		return
	var army := _take_army(n)
	aid_out.append({"country": c, "days": 30, "army": army})
	change_rel(c, 6 + n * 0.6)
	Game.message.emit("%d askar %s ga yordamga yuborildi. 30 kundan keyin qaytishadi (ba'zilari halok bo'lishi mumkin)." % [n, War.country_name(c)], "good")
	Game.changed.emit()


func why_goods(c: String, res: String, n: int, sell: bool) -> String:
	if not trade.has(c): return "Avval savdo shartnomasi tuzing"
	if sell and float(Game.goods.get(res, 0.0)) < n: return "Omborda yetarli emas"
	if not sell and Game.money < goods_price(res, n, false): return "Oltin yetmaydi"
	return ""


func goods_price(res: String, n: int, sell: bool) -> int:
	return int(round(GOODS_PRICE[res] * n * (1.0 if sell else 1.4)))


func trade_goods(c: String, res: String, n: int, sell: bool) -> void:
	if why_goods(c, res, n, sell) != "":
		return
	var pr := goods_price(res, n, sell)
	if sell:
		Game.goods[res] = float(Game.goods[res]) - n
		Game.money += pr
	else:
		Game.goods[res] = float(Game.goods.get(res, 0.0)) + n
		Game.money -= pr
	change_rel(c, 1)
	Game.message.emit("%s bilan savdo: %d %s %s - %d oltin." % [War.country_name(c), n, CastleEco.RES_NAMES[res].to_lower(), "sotildi" if sell else "olindi", pr], "info")
	Game.changed.emit()


func _old_daily() -> void:
	for x in aid_in.duplicate():
		x["days"] -= 1
		if x["days"] <= 0:
			aid_in.erase(x)
			_give_army(x["army"])
			Game.message.emit("Ittifoqchi %s qo'shini qal'angizga yetib keldi: %d jangchi hovlida saf tortdi." % [War.country_name(x["country"]), army_n(x["army"])], "good")
	for x in aid_out.duplicate():
		x["days"] -= 1
		if x["days"] <= 0:
			aid_out.erase(x)
			var back := {}
			for k in x["army"]:
				back[k] = int(floor(int(x["army"][k]) * _rng.randf_range(0.6, 0.9)))
			_give_army(back)
			var gold := 3 * army_n(x["army"])
			Game.money += gold
			Game.message.emit("%s ga yuborilgan askarlaringiz qaytdi: %d tasi tirik. Minnatdorlik uchun %d oltin." % [War.country_name(x["country"]), army_n(back), gold], "good")


func _bot_initiative_old(c: String) -> void:
	var name := War.country_name(c)
	match _rng.randi_range(0, 4):
		0:
			if alliance.has(c) or rel[c] < 30:
				return
			proposal.emit("%s ELCHISI keldi:\n\n\"Hukmdorimiz siz bilan ittifoq tuzishni istaydi. Bir-birimizga dushman hujum qilsa, yordam beramiz.\"" % name,
				func():
					alliance[c] = true
					change_rel(c, 10)
					Game.message.emit("%s bilan ittifoq tuzildi!" % name, "good")
					Game.changed.emit(),
				func(): change_rel(c, -5))
		1:
			var allies: Array = alliance.keys().filter(func(a): return alive(a))
			if allies.is_empty():
				return
			var ac: String = allies[_rng.randi() % allies.size()]
			var n := 15
			proposal.emit("ITTIFOQCHI %s yordam so'ramoqda:\n\n\"Bizga dushman bostirib kirdi! %d askar yuboring, qarzdor bo'lib qolmaymiz.\"\n\nRad etsangiz, ittifoq buzilishi mumkin." % [War.country_name(ac), n],
				func():
					if why_send_help(ac, n) == "":
						send_help(ac, n)
					else:
						Game.message.emit("Qal'ada yetarli askar yo'q - yordam yubora olmadingiz.", "bad")
						change_rel(ac, -10),
				func():
					change_rel(ac, -20)
					if rel[ac] < 30:
						alliance.erase(ac)
						Game.message.emit("%s ittifoqni bekor qildi: \"Qiyin kunda tashlab ketdingiz.\"" % War.country_name(ac), "bad"))
		2:
			if trade.has(c) or rel[c] < 0:
				return
			proposal.emit("%s KARVONBOSHISI keldi:\n\n\"Shaharlaringiz orqali karvon yo'li ochaylik.\" Har kuni +%d oltin, munosabat yaxshilanadi." % [name, trade_value(c)],
				_accept_trade.bind(c), func(): change_rel(c, -5))
		3:
			if rel[c] > -5 or not borders_player(c):
				return
			var tribute := 120
			proposal.emit("%s O'LPON talab qilmoqda:\n\n\"%d oltin yuboring, aks holda qilichimiz gapiradi!\"\n\nTo'lasangiz munosabat yaxshilanadi. Rad etsangiz, urush boshlanishi mumkin." % [name, tribute],
				func():
					if Game.money >= tribute:
						Game.money -= tribute
						treasury[c] += tribute
						change_rel(c, 15)
						Game.message.emit("%s ga o'lpon to'landi." % name, "info")
					else:
						Game.message.emit("O'lpon uchun oltin yetmadi!", "bad")
						change_rel(c, -10)
					Game.changed.emit(),
				func():
					change_rel(c, -15)
					if _rng.randf() < 0.35:
						War.declare_war(c, true))
		4:
			if not trade.has(c):
				return
			var res: String = ["oziq", "yogoch", "tosh"][_rng.randi() % 3]
			var n2 := 100
			var pr := int(goods_price(res, n2, true) * 0.9)
			proposal.emit("%s savdogari taklif qilmoqda:\n\n%d %s - atigi %d oltinga (bozordan arzon)." % [name, n2, CastleEco.RES_NAMES[res].to_lower(), pr],
				func():
					if Game.money >= pr:
						Game.money -= pr
						Game.goods[res] = float(Game.goods.get(res, 0.0)) + n2
						Game.message.emit("%d %s sotib olindi." % [n2, CastleEco.RES_NAMES[res].to_lower()], "good")
						Game.changed.emit(),
				func(): pass)


func _bot_initiative() -> void:
	if Game.day < next_offer:
		return
	next_offer = Game.day + _rng.randi_range(22, 40)
	var cands: Array = []
	for c in rel:
		if alive(c) and not War.wars.has(c):
			cands.append(c)
	if cands.is_empty():
		return
	var c: String = cands[_rng.randi() % cands.size()]
	var name := War.country_name(c)
	# juda yomon munosabat + chegaradosh -> urush e'lon qilishi mumkin
	if rel[c] <= -50 and borders_player(c) and _rng.randf() < 0.5:
		War.declare_war(c, true)
		return
	if Game.era < 4:
		_bot_initiative_old(c)
		return
	var kind := _rng.randi_range(0, 3)
	match kind:
		0:
			var n := 50
			var pay := n * 15
			var p := target_province()
			if p == "" or Game.provinces[p]["units"]["soldier"] < n:
				return
			proposal.emit("%s taklif qilmoqda:\n\nUlarning chegarasida muammo bor. %d askaringizni %d kunga ijaraga so'rashmoqda.\nTo'lov: %d $ (hozir). Askarlarning bir qismi qaytmasligi mumkin." % [name, n, RENT_DAYS, pay],
				func(): _accept_soldier_request(c, n, pay), func(): change_rel(c, -5))
		1:
			if sanctioned():
				return
			var amount := 3000
			proposal.emit("%s taklif qilmoqda:\n\nSizga %d $ qarz berishga tayyormiz.\nFoiz 10%%, %d kundan keyin %d $ qaytarasiz.\nQaytara olmasangiz - provinsiya yoki sanksiya." % [name, amount, LOAN_DAYS, int(amount * 1.1)],
				func(): _accept_offered_loan(c, amount), func(): pass)
		2:
			var p2 := target_province()
			if p2 == "" or Game.provinces[p2]["units"]["tank"] < 3 or sanctioned():
				return
			var price := 3 * 600
			proposal.emit("%s qurol sotib olmoqchi:\n\n3 ta tankingiz uchun %d $ to'lashga tayyor (bozor narxidan qimmat).\nLekin bu tanklar keyin sizga qarshi ishlatilishi mumkin..." % [name, price],
				func(): _accept_tank_buy(c, 3, price), func(): change_rel(c, -3))
		3:
			if trade.has(c) or sanctioned():
				return
			proposal.emit("%s savdo shartnomasi taklif qilmoqda:\n\nHar kuni +%d $ daromad. Munosabat yaxshilanadi." % [name, trade_value(c)],
				_accept_trade.bind(c),
				func(): change_rel(c, -5))


func _accept_trade(c: String) -> void:
	if War.wars.has(c) or sanctioned():
		return
	trade[c] = true
	change_rel(c, 5)
	Game.message.emit("%s bilan savdo shartnomasi imzolandi: +%d $/kun." % [War.country_name(c), trade_value(c)], "good")
	Game.changed.emit()


func _accept_soldier_request(c: String, n: int, pay: int) -> void:
	var p := target_province()
	if p == "" or Game.provinces[p]["units"]["soldier"] < n:
		return
	Game.provinces[p]["units"]["soldier"] -= n
	Game.money += pay
	leases.append({"kind": "out", "country": c, "soldiers": n, "province": p, "days": RENT_DAYS})
	change_rel(c, 10)
	Game.message.emit("%d askar %s ga yuborildi: +%d $." % [n, War.country_name(c), pay], "good")
	Game.changed.emit()


func _accept_offered_loan(c: String, amount: int) -> void:
	treasury[c] -= amount
	Game.money += amount
	debts.append({"country": c, "amount": roundf(amount * 1.1), "due": Game.day + LOAN_DAYS, "day": Game.day})
	Game.message.emit("%s dan %d $ qarz olindi." % [War.country_name(c), amount], "info")
	Game.changed.emit()


func _accept_tank_buy(c: String, n: int, price: int) -> void:
	var p := target_province()
	if p == "" or Game.provinces[p]["units"]["tank"] < n:
		return
	Game.provinces[p]["units"]["tank"] -= n
	Game.money += price
	change_rel(c, 6)
	var provs := country_provinces(c)
	if not provs.is_empty():
		Game.provinces[provs[0]]["defense"] += n * War.TANK_POWER
	Game.message.emit("%d tank %s ga sotildi: +%d $." % [n, War.country_name(c), price], "good")
	Game.changed.emit()


# ---------------------------------------------------------------- saqlash

func to_dict() -> Dictionary:
	return {"rel": rel, "treasury": treasury, "trade": trade.keys(), "alliance": alliance.keys(), "transit": transit.keys(),
		"debts": debts, "credits": credits, "leases": leases, "black": black,
		"sanction_days": sanction_days, "defaulted": defaulted, "next_offer": next_offer, "border_mode": border_mode,
		"aid_in": aid_in, "aid_out": aid_out, "help_cd": help_cd}


func from_dict(d: Dictionary) -> void:
	border_mode = d.get("border_mode", {})
	if d.is_empty():
		return
	aid_in = d.get("aid_in", [])
	aid_out = d.get("aid_out", [])
	help_cd = d.get("help_cd", {})
	for c in d.get("rel", {}):
		rel[c] = float(d["rel"][c])
	for c in d.get("treasury", {}):
		treasury[c] = float(d["treasury"][c])
	trade = {}
	for c in d.get("trade", []):
		trade[c] = true
	alliance = {}
	for c in d.get("alliance", []):
		alliance[c] = true
	transit = {}
	for c in d.get("transit", []):
		transit[c] = true
	debts = []
	for x in d.get("debts", []):
		debts.append({"country": x["country"], "amount": float(x["amount"]), "due": int(x["due"]), "day": int(x["day"])})
	credits = []
	for x in d.get("credits", []):
		credits.append({"country": x["country"], "amount": float(x["amount"]), "due": int(x["due"]), "day": int(x["day"])})
	leases = []
	for x in d.get("leases", []):
		leases.append({"kind": x["kind"], "country": x["country"], "soldiers": int(x["soldiers"]), "province": x["province"], "days": int(x["days"])})
	black = []
	for x in d.get("black", []):
		black.append({"province": x["province"], "soldiers": int(x["soldiers"]), "tanks": int(x["tanks"]), "days": int(x["days"])})
	sanction_days = int(d.get("sanction_days", 0))
	defaulted = int(d.get("defaulted", 0))
	next_offer = int(d.get("next_offer", Game.day + 30))
