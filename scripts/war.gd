extends Node
## Urush tizimi (autoload: War)
## Qo'shinlar xaritada chiziq bo'ylab yuradi, dushman provinsiyasiga kirsa jang boshlanadi.
## Chet eldagi qo'shin zaxirasi kamayadi - uni karvonlar to'ldiradi. Karvonlar pistirmaga tushishi mumkin.
## Urush e'lon qilingan davlat vaqti-vaqti bilan qarshi hujumga o'tadi.

signal explosion(pos: Vector2, big: bool)
signal target_mode_changed(from_id: String)
signal need_confirm(country: String, from_id: String, to_id: String)
signal open_battle(army_id: int)
signal nuke_flash(pos: Vector2)
signal battle_choice(army_id: int)   # jang boshlandi: avto yoki boshqarish

var battle_open := false

const SOLDIER_POWER := 1.0
const TANK_POWER := 8.0
const ARMY_SPEED := 14.0        # xarita birligi / kun (real: qo'shin sekin yuradi)
const CONVOY_SPEED := 30.0
const FIGHT_RATE := 0.06         # kunlik jang shiddati (ilgari 0.12)
const STAGE_DAYS := 12           # dushman hujumdan oldin chegarada to'planadi
const CONVOY_COST := 60
const CONVOY_SUPPLY := 45.0
const PEACE_MIN_DAYS := 30
const MILITIA := 10.0           # har bir provinsiyada mahalliy mudofaa

var armies: Array = []          # Dictionary ro'yxati
var convoys: Array = []
var wars := {}                  # davlat kodi -> {"start": kun, "next_attack": kun}
var target_from := ""           # nishon tanlash rejimi (qaysi provinsiyadan)
var target_kind := "army"       # army / plane / missile / nuke
var confirm_kind := "army"
var send_count := {}            # qisman jo'natish: {"soldier": n, "tank": m}
var _next_id := 1
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	init_world()
	Game.day_passed.connect(_on_day)


func init_world() -> void:
	armies.clear()
	convoys.clear()
	wars.clear()
	for id in Game.province_order:
		var p: Dictionary = Game.provinces[id]
		p["max_defense"] = roundf(15.0 + p["population"] * 0.012)
		p["defense"] = p["max_defense"]
		p["militia"] = MILITIA


# ---------------------------------------------------------------- yordamchi

func power(a: Dictionary) -> float:
	if a.get("owner", "") == Game.PLAYER:
		return a["soldiers"] * SOLDIER_POWER * Tech.mult("soldier") + a["tanks"] * TANK_POWER * Tech.mult("tank")
	return a["soldiers"] * SOLDIER_POWER + a["tanks"] * TANK_POWER


func garrison_power(p: Dictionary) -> float:
	var k1 := Tech.mult("soldier") if p["owner"] == Game.PLAYER else 1.0
	var k2 := Tech.mult("tank") if p["owner"] == Game.PLAYER else 1.0
	return p["units"]["soldier"] * SOLDIER_POWER * k1 + p["units"]["tank"] * TANK_POWER * k2


func militia_cap(p: Dictionary = {}) -> float:
	var extra := 0.0
	if not p.is_empty():
		extra = float(p.get("fort", 0.0)) + (15.0 if Game.count_buildings(p, "barracks") > 0 else 0.0) + Game.posts_done(p) * 6.0
	return MILITIA + Tech.bonus("militia") + extra


func supply_factor(a: Dictionary) -> float:
	if a["owner"] != Game.PLAYER:
		return 1.0
	return clampf(0.3 + a["supply"] / 40.0, 0.3, 1.0)


func hostile_borders() -> Array:
	## Dushman (urushdagi yoki munosabati yomon) davlat chegaradagi postlari: [bot_viloyat, bizning_viloyat]
	var out: Array = []
	for id in Game.player_provinces():
		for n in Game.provinces[id]["neighbors"]:
			var o: String = Game.provinces[n]["owner"]
			if o == Game.PLAYER or o == Game.REBEL:
				continue
			if wars.has(o) or Diplo.rel.get(o, 0.0) < -25.0:
				out.append([n, id])
	return out


func at_war_with(owner: String) -> bool:
	return owner == Game.REBEL or wars.has(owner)


func get_army(id: int) -> Dictionary:
	for a in armies:
		if a["id"] == id:
			return a
	return {}


func armies_in(prov_id: String) -> Array:
	var out: Array = []
	for a in armies:
		if a["at"] == prov_id and a["state"] == "fight":
			out.append(a)
	return out


func army_upkeep() -> float:
	var t := 0.0
	for a in armies:
		if a["owner"] == Game.PLAYER:
			t += a["soldiers"] * Game.UNITS["soldier"]["upkeep"] + a["tanks"] * Game.UNITS["tank"]["upkeep"]
	return t


func player_unit_totals() -> Dictionary:
	var out: Dictionary = Game.total_units()
	for a in armies:
		if a["owner"] == Game.PLAYER:
			out["soldier"] += a["soldiers"]
			out["tank"] += a["tanks"]
	return out


func _center(id: String) -> Vector2:
	return Game.provinces[id]["center"]


func _name(id: String) -> String:
	return Game.provinces[id]["name"]


func country_name(c: String) -> String:
	if c == Game.REBEL:
		return "Isyonchilar"
	return Game.countries[c]["name"]


# ---------------------------------------------------------------- nishon tanlash

func begin_target(from_id: String, kind := "army", counts := {}) -> void:
	send_count = counts
	target_from = from_id
	target_kind = kind
	target_mode_changed.emit(from_id)


func cancel_target() -> void:
	if target_from != "":
		target_from = ""
		target_mode_changed.emit("")


func choose_target(to_id: String) -> void:
	var from := target_from
	var kind := target_kind
	cancel_target()
	if to_id == "" or to_id == from:
		return
	if kind != "army":
		var why := Tech.why_strike(from, to_id, kind)
		if why != "":
			Game.message.emit(why, "bad")
			return
	var owner: String = Game.provinces[to_id]["owner"]
	if owner != Game.PLAYER and owner != Game.REBEL and not wars.has(owner):
		confirm_kind = kind
		need_confirm.emit(owner, from, to_id)
		return
	execute(from, to_id, kind)


func execute(from: String, to_id: String, kind: String) -> void:
	if kind == "army":
		send_army(from, to_id)
	else:
		Tech.launch(from, to_id, kind)


func find_path(from_id: String, to_id: String) -> Array:
	## O'z hududingiz orqali yuradi; oxirgi qadam - nishon (qo'shni bo'lishi kerak).
	var prev := {from_id: ""}
	var queue: Array = [from_id]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		for n in Game.provinces[cur]["neighbors"]:
			if prev.has(n):
				continue
			if n == to_id:
				prev[n] = cur
				var path: Array = [n]
				var back: String = cur
				while back != from_id:
					path.push_front(back)
					back = prev[back]
				return path
			if Game.provinces[n]["owner"] == Game.PLAYER:
				prev[n] = cur
				queue.append(n)
	return []


# ---------------------------------------------------------------- buyruqlar

func declare_war(c: String, by_enemy := false) -> void:
	if wars.has(c):
		return
	wars[c] = {"start": Game.day, "next_attack": Game.day + (_rng.randi_range(4, 8) if by_enemy else _rng.randi_range(20, 30))}
	if by_enemy:
		Game.message.emit("%s sizga URUSH e'lon qildi!" % country_name(c), "bad")
	else:
		Game.message.emit("Siz %s ga urush e'lon qildingiz!" % country_name(c), "bad")
	Diplo.on_war_declared(c, by_enemy)
	Game.changed.emit()


func send_army(from_id: String, to_id: String) -> void:
	var p: Dictionary = Game.provinces[from_id]
	var ns := float(p["units"]["soldier"])
	var nt := float(p["units"]["tank"])
	var site := ""
	if Game.provinces[to_id]["owner"] != Game.PLAYER:
		# HUJUM: faqat chegaradosh viloyatdan, chegara postida to'plangan qo'shin bilan
		if not (to_id in p["neighbors"]):
			Game.message.emit("Hujum faqat chegaradosh viloyatdan boshlanadi. Avval qo'shinni %s chegarasiga yaqin viloyatga olib boring." % _name(to_id), "bad")
			send_count = {}
			return
		if not Game.has_post(from_id, to_id):
			Game.message.emit("%s - %s chegarasida post yo'q. Avval chegara posti quring va u yerga qo'shin to'plang." % [_name(from_id), _name(to_id)], "bad")
			send_count = {}
			return
		site = "post:" + to_id
		var at_post := Game.site_units(p, site)
		ns = at_post["soldier"]
		nt = at_post["tank"]
		if ns + nt < 1.0:
			Game.message.emit("Chegara postida qo'shin yo'q. Avval %s chegarasiga askar va tank to'plang (chegarani bosing)." % _name(to_id), "bad")
			send_count = {}
			return
	if not send_count.is_empty():
		ns = minf(ns, float(send_count.get("soldier", ns)))
		nt = minf(nt, float(send_count.get("tank", nt)))
		send_count = {}
	if ns + nt <= 0.0:
		Game.message.emit("%s da qo'shin yo'q." % _name(from_id), "info")
		return
	var path := find_path(from_id, to_id)
	if path.is_empty():
		Game.message.emit("%s ga yo'l yo'q. Qo'shin faqat o'z hududingiz orqali qo'shni provinsiyaga bora oladi." % _name(to_id), "bad")
		return
	var a := {
		"id": _next_id, "owner": Game.PLAYER,
		"soldiers": ns, "tanks": nt,
		"pos": _center(from_id), "prev_pos": _center(from_id),
		"at": from_id, "base": from_id, "path": path, "state": "move",
		"supply": 100.0, "warned": false,
	}
	_next_id += 1
	if site != "":
		Game.take_units(p, site, ns, nt)
	p["units"]["soldier"] = p["units"]["soldier"] - ns
	p["units"]["tank"] = p["units"]["tank"] - nt
	Game.normalize_sites(p)
	armies.append(a)
	var days := ceili(_path_length(a) / ARMY_SPEED)
	Game.message.emit("Qo'shin %s dan %s ga yo'lga chiqdi (~%d kun)." % [_name(from_id), _name(to_id), days], "info")
	Game.changed.emit()


func retreat(army_id: int) -> void:
	var a := get_army(army_id)
	if a.is_empty():
		return
	var home := _nearest_own(a["at"], a["base"])
	if home == "":
		Game.message.emit("Chekinish uchun yaqin o'z provinsiyangiz yo'q!", "bad")
		return
	a["path"] = [home]
	a["state"] = "move"
	Game.message.emit("Qo'shin %s ga chekinmoqda." % _name(home), "info")
	Game.changed.emit()


func make_peace(c: String) -> void:
	if not wars.has(c):
		return
	var days: int = Game.day - wars[c]["start"]
	if days < PEACE_MIN_DAYS:
		Game.message.emit("%s sulhni rad etdi. Urush kamida %d kun davom etishi kerak (yana %d kun)." % [country_name(c), PEACE_MIN_DAYS, PEACE_MIN_DAYS - days], "bad")
		return
	wars.erase(c)
	for a in armies.duplicate():
		if a["owner"] == c:
			armies.erase(a)
		elif a["owner"] == Game.PLAYER and a["state"] == "fight" and Game.provinces[a["at"]]["owner"] == c:
			retreat(a["id"])
	Game.message.emit("%s bilan sulh tuzildi. Bosib olingan yerlar sizda qoladi." % country_name(c), "good")
	Game.changed.emit()


# ---------------------------------------------------------------- kunlik hisob

func _on_day(_d: int) -> void:
	for a in armies:
		a["prev_pos"] = a["pos"]
	for c in convoys:
		c["prev_pos"] = c["pos"]
	for a in armies.duplicate():
		if not armies.has(a):
			continue
		if a["state"] == "stage":
			a["stage"] = int(a.get("stage", 0)) - 1
			if Game.era < 4 and a["stage"] == 3 and not a.get("intel", false):
				# josus yo'q - faqat chegaradagi qorovullar oxirgi kunlarda sezib qoladi
				Game.message.emit("QOROVUL: %s tomonda ko'p gulxan va otlar ko'rindi. Dushman bir necha kunda hujum qilishi mumkin! (Josus yollasangiz, oldindan bilasiz.)" % _name(a["at"]), "bad")
			if a["stage"] <= 0:
				a["state"] = "move"
				Game.message.emit("%s qo'shini chegarani kesib o'tdi va %s tomon yurdi!" % [country_name(a["owner"]), _name(a["path"][0])], "bad")
				if Game.era < 4:
					Game.set_speed(0)
					Game.message.emit("DIQQAT! Dushman yo'lda - o'yin to'xtatildi. Qal'angizga askar yollang yoki qo'shin yuboring, keyin davom eting.", "event")
		elif a["state"] == "move":
			_move(a)
		elif a["state"] == "fight":
			_fight(a)
	for a in armies:
		if a["owner"] == Game.PLAYER:
			_supply(a)
	_move_convoys()
	_regenerate()
	_bot_attacks()
	money_upkeep()


func money_upkeep() -> void:
	Game.money -= army_upkeep()


func _path_length(a: Dictionary) -> float:
	var total := 0.0
	var last: Vector2 = a["pos"]
	for id in a["path"]:
		total += last.distance_to(_center(id))
		last = _center(id)
	return total


func _move(a: Dictionary) -> void:
	var left := ARMY_SPEED
	while left > 0.0 and not a["path"].is_empty():
		var next: String = a["path"][0]
		var dest := _center(next)
		var d: float = a["pos"].distance_to(dest)
		if d > left:
			a["pos"] = a["pos"].move_toward(dest, left)
			return
		a["pos"] = dest
		left -= d
		a["path"].pop_front()
		a["at"] = next
		if _arrive(a, next):
			return


func _arrive(a: Dictionary, id: String) -> bool:
	## true qaytaradi - harakat to'xtadi
	var p: Dictionary = Game.provinces[id]
	if a["owner"] == Game.PLAYER:
		if p["owner"] == Game.PLAYER:
			a["base"] = id
			a["supply"] = 100.0
			if a["path"].is_empty():
				_merge_into(a, p)
				Game.message.emit("Qo'shin %s ga yetib keldi va garnizonga qo'shildi." % p["name"], "good")
				return true
			return false
		if not at_war_with(p["owner"]):
			# yo'lda sulh tuzilgan bo'lishi mumkin
			retreat(a["id"])
			return true
		a["path"].clear()
		a["state"] = "fight"
		Game.message.emit("Qo'shiningiz %s ga bostirib kirdi!" % p["name"], "event")
		battle_choice.emit(a["id"])
		return true
	# bot qo'shini
	if p["owner"] == Game.PLAYER:
		a["path"].clear()
		a["state"] = "fight"
		Game.message.emit("DIQQAT: %s qo'shini %s ga hujum qildi!" % [country_name(a["owner"]), p["name"]], "bad")
		Diplo.on_player_attacked(id)
		battle_choice.emit(a["id"])
		return true
	p["defense"] += power(a)
	armies.erase(a)
	return true


func _merge_into(a: Dictionary, p: Dictionary) -> void:
	p["units"]["soldier"] = roundi(p["units"]["soldier"] + a["soldiers"])
	p["units"]["tank"] = roundi(p["units"]["tank"] + a["tanks"])
	armies.erase(a)


func _take_losses(a: Dictionary, loss: float) -> void:
	## Yo'qotishni askar va tanklar orasida kuchiga qarab taqsimlaydi
	var total := power(a)
	if total <= 0.0:
		return
	loss = minf(loss, total)
	var tank_share: float = a["tanks"] * TANK_POWER / total
	a["tanks"] = maxf(0.0, a["tanks"] - loss * tank_share / TANK_POWER)
	a["soldiers"] = maxf(0.0, a["soldiers"] - loss * (1.0 - tank_share) / SOLDIER_POWER)


func _boom(id: String, count: int, big := false) -> void:
	var c := _center(id)
	for i in count:
		explosion.emit(c + Vector2(_rng.randf_range(-25, 25), _rng.randf_range(-18, 18)), big)


func _fight(a: Dictionary) -> void:
	var id: String = a["at"]
	var p: Dictionary = Game.provinces[id]
	if a["owner"] == Game.PLAYER:
		if p["owner"] == Game.PLAYER:
			# provinsiya allaqachon bizniki (masalan boshqa qo'shin oldi)
			_merge_into(a, p)
			return
		var att := power(a) * supply_factor(a)
		var dmg_def := att * FIGHT_RATE * _rng.randf_range(0.8, 1.2)
		var dmg_att: float = p["defense"] * FIGHT_RATE * 1.15 * _rng.randf_range(0.8, 1.2)
		p["defense"] = maxf(0.0, p["defense"] - dmg_def)
		_take_losses(a, dmg_att)
		_boom(id, 3)
		if p["defense"] <= 0.5:
			_capture(a, id)
		elif power(a) < 0.5:
			armies.erase(a)
			Game.message.emit("Qo'shiningiz %s da tor-mor bo'ldi!" % p["name"], "bad")
		return
	# bot hujumi
	if p["owner"] != Game.PLAYER:
		p["defense"] += power(a)
		armies.erase(a)
		return
	var g: float = garrison_power(p) + p["militia"]
	var dmg_g := power(a) * FIGHT_RATE * _rng.randf_range(0.8, 1.2)
	if Game.has_post(id, a["base"]):
		dmg_g *= 0.75   # chegara posti dushmanni sekinlashtiradi
	var dmg_b := g * FIGHT_RATE * 1.15 * _rng.randf_range(0.8, 1.2)
	if Game.era < 4 and not SiegeCastle.player_spec(p).is_empty():
		# devor bilan o'ralgan qal'a: himoyachilar ko'proq yo'qotish beradi, kamroq yo'qotadi
		dmg_b *= 1.8
		dmg_g *= 0.6
		# devorni qo'riqlayotgan va mashq qilgan qo'shin
		var cc: Dictionary = p.get("castle", {})
		if cc.get("task", "") == "devor":
			dmg_b *= 1.2
			dmg_g *= 0.85
		dmg_b *= 1.0 + float(cc.get("drill", 0.0)) / 250.0
		dmg_b *= CastleEco.hunger_penalty(cc)
		dmg_g *= 1.0 - 0.12 * float(cc.get("armor", 0))
	_take_losses(a, dmg_b)
	# avval mahalliy mudofaa, keyin garnizon
	var from_militia := minf(p["militia"], dmg_g)
	p["militia"] -= from_militia
	var rest := dmg_g - from_militia
	if rest > 0.0:
		var tmp := {"soldiers": float(p["units"]["soldier"]), "tanks": float(p["units"]["tank"])}
		_take_losses(tmp, rest)
		p["units"]["soldier"] = tmp["soldiers"]
		p["units"]["tank"] = tmp["tanks"]
	_boom(id, 3)
	if power(a) < 0.5:
		armies.erase(a)
		Game.message.emit("%s himoyachilari dushman hujumini qaytardi!" % p["name"], "good")
	elif garrison_power(p) + p["militia"] < 0.5:
		bot_capture(a, id)


func bot_capture(a: Dictionary, id: String) -> void:
	var p: Dictionary = Game.provinces[id]
	p["owner"] = a["owner"]
	p["orders"].clear()
	p["unrest"] = 20.0
	p["defense"] = power(a)
	p["militia"] = 0.0
	p["units"] = {"soldier": 0, "tank": 0}
	p["sites"] = {}
	p["posts"] = []
	armies.erase(a)
	_boom(id, 5, true)
	Game.message.emit("%s ni %s bosib oldi! Binolaringiz dushman qo'liga o'tdi." % [p["name"], country_name(p["owner"])], "bad")
	if Game.player_provinces().is_empty():
		Game.game_over = true
		Game.message.emit("Sizda provinsiya qolmadi. O'yin tugadi.", "bad")
	Game.changed.emit()


func capture_by_player(a: Dictionary, id: String) -> void:
	_capture(a, id)
	Game.changed.emit()


func _capture(a: Dictionary, id: String) -> void:
	var p: Dictionary = Game.provinces[id]
	var old: String = p["owner"]
	p["owner"] = Game.PLAYER
	p["unrest"] = 60.0
	p["defense"] = 0.0
	p["militia"] = 0.0
	_merge_into(a, p)
	_boom(id, 6, true)
	Game.message.emit("G'ALABA! %s bosib olindi. Aholi norozi - ish o'rinlari yarating." % p["name"], "good")
	if Game.era < 4:
		_take_captives(p, old)
	if old != Game.REBEL:
		var left := 0
		for pid in Game.province_order:
			if Game.provinces[pid]["owner"] == old:
				left += 1
		if left == 0:
			wars.erase(old)
			Game.message.emit("%s to'liq bosib olindi! Urush tugadi." % country_name(old), "good")


func _take_captives(p: Dictionary, old: String) -> void:
	## bosib olingan joyning asir askarlari xizmatga o'tadi: ular o'z xalqi kiyimida, o'z qal'asida qoladi
	## (masalan Rossiyani bossangiz - rus askarlari, rus uslubidagi qal'ada)
	CastleEco.sync(p)
	var c := CastleEco.castle(p)
	var n := clampi(int(float(p["population"]) / 12000.0), 10, 50)
	var mix: Dictionary = {"sarboz": 0.6, "nayzachi": 0.4} if Game.era == 2 else {"nayzachi": 0.4, "qilichboz": 0.3, "kamonchi": 0.3}
	for k in mix:
		c["army"][k] = int(c["army"].get(k, 0)) + int(round(n * float(mix[k])))
	CastleEco.sync(p)
	var who := country_name(p["country"]) if Game.countries.has(p["country"]) else country_name(old)
	Game.message.emit("%s: %d asir askar (%s) sizga xizmat qilishga rozi bo'ldi. Ular o'z qal'asida - u yerda shu xalq askarlarini yollash va shu uslubda qurish mumkin." % [p["name"], n, who], "good")


func _nearest_own(from_id: String, prefer: String) -> String:
	if prefer != "" and Game.provinces[prefer]["owner"] == Game.PLAYER:
		return prefer
	for n in Game.provinces[from_id]["neighbors"]:
		if Game.provinces[n]["owner"] == Game.PLAYER:
			return n
	return ""


# ---------------------------------------------------------------- zaxira va karvonlar

func _supply(a: Dictionary) -> void:
	var here: Dictionary = Game.provinces[a["at"]]
	if a["state"] != "fight" and here["owner"] == Game.PLAYER:
		a["supply"] = 100.0
		a["warned"] = false
		return
	a["supply"] = maxf(0.0, a["supply"] - (4.0 + a["tanks"] * 0.15) * Tech.mult("supply_drain"))
	if a["supply"] < 25.0 and not a["warned"]:
		a["warned"] = true
		Game.message.emit("Qo'shiningiz zaxirasi tugayapti (%d%%)! Jang kuchi pasaymoqda." % int(a["supply"]), "bad")
	var cost := roundf(CONVOY_COST * Tech.mult("convoy_cost"))
	if a["supply"] < 70.0 and not _has_convoy(a["id"]) and Game.money >= cost:
		var base := _nearest_own(a["at"], a["base"])
		if base == "":
			return
		Game.money -= cost
		convoys.append({"id": _next_id, "army": a["id"], "pos": _center(base),
			"prev_pos": _center(base), "start": _center(base), "rolled": false})
		_next_id += 1


func _has_convoy(army_id: int) -> bool:
	for c in convoys:
		if c["army"] == army_id:
			return true
	return false


func _move_convoys() -> void:
	for c in convoys.duplicate():
		var a := get_army(c["army"])
		if a.is_empty():
			convoys.erase(c)
			continue
		var dest: Vector2 = a["pos"]
		var total: float = c["start"].distance_to(dest)
		c["pos"] = c["pos"].move_toward(dest, CONVOY_SPEED * Tech.mult("convoy_speed"))
		var here: Dictionary = Game.provinces[a["at"]]
		# yarim yo'lda dushman hududiga kirganda pistirma xavfi
		if not c["rolled"] and here["owner"] != Game.PLAYER and c["pos"].distance_to(dest) < total * 0.5 + 1.0:
			c["rolled"] = true
			var chance := 0.12 + 0.2 * clampf(here["defense"] / maxf(1.0, here["max_defense"]), 0.0, 1.0)
			if _rng.randf() < chance:
				convoys.erase(c)
				explosion.emit(c["pos"], false)
				Game.message.emit("Karvoningiz %s yaqinida pistirmaga tushdi va yo'q qilindi!" % here["name"], "bad")
				continue
		if c["pos"].distance_to(dest) < 0.5:
			a["supply"] = minf(100.0, a["supply"] + CONVOY_SUPPLY)
			if a["supply"] >= 25.0:
				a["warned"] = false
			convoys.erase(c)


# ---------------------------------------------------------------- dushman

func _regenerate() -> void:
	var fighting := {}
	for a in armies:
		if a["state"] == "fight":
			fighting[a["at"]] = true
	for id in Game.province_order:
		var p: Dictionary = Game.provinces[id]
		if fighting.has(id):
			continue
		if p["owner"] == Game.PLAYER:
			p["militia"] = minf(militia_cap(p), p["militia"] + 0.5)
		elif at_war_with(p["owner"]) and p["defense"] < p["max_defense"]:
			p["defense"] = minf(p["max_defense"], p["defense"] + p["max_defense"] * 0.015)


func _bot_attacks() -> void:
	for c in wars:
		var w: Dictionary = wars[c]
		if Game.day < w["next_attack"]:
			continue
		w["next_attack"] = Game.day + _rng.randi_range(35, 55)
		var best_from := ""
		var best_to := ""
		var best_def := 25.0
		for id in Game.province_order:
			var p: Dictionary = Game.provinces[id]
			if p["owner"] != c or p["defense"] < best_def:
				continue
			for n in p["neighbors"]:
				if Game.provinces[n]["owner"] == Game.PLAYER:
					best_from = id
					best_to = n
					best_def = p["defense"]
					break
		if best_from == "":
			continue
		var p2: Dictionary = Game.provinces[best_from]
		var strength: float = p2["defense"] * 0.5
		p2["defense"] -= strength
		var tanks := floorf(strength * 0.3 / TANK_POWER)
		armies.append({
			"id": _next_id, "owner": c,
			"soldiers": strength - tanks * TANK_POWER, "tanks": tanks,
			"pos": _center(best_from), "prev_pos": _center(best_from),
			"at": best_from, "base": best_from, "path": [best_to], "state": "stage",
			"supply": 100.0, "warned": false, "stage": STAGE_DAYS + _rng.randi_range(-3, 3),
		})
		# qo'shin chegaraga yaqinlashib to'planadi
		var last: Dictionary = armies[armies.size() - 1]
		if Game.has_post(best_to, best_from):
			last["stage"] += 5
		last["pos"] = _center(best_from).lerp(_center(best_to), 0.45)
		last["prev_pos"] = _center(best_from)
		_next_id += 1
		if Game.era < 4:
			last["intel"] = Game.spies > 0
			if Game.spies > 0:
				last["stage"] += 2 * Game.spies
				var tgt: Dictionary = Game.provinces[best_to]
				var sp := SiegeCastle.player_spec(tgt)
				Game.message.emit("JOSUS xabari: %s %s dan %s ga hujumga tayyorlanmoqda - taxminan %d askar, narvonlar, taran va manjaniqlar bilan. Hujumgacha ~%d kun. %s" % [country_name(c), _name(best_from), _name(best_to), int(strength), last["stage"],
					"Qal'angiz devor bilan o'ralgan - qamalga tayyorlaning." if not sp.is_empty() else "Qal'angiz devor bilan o'ralmagan - jang ochiq maydonda bo'ladi!"], "bad")
			continue
		if Game.has_post(best_to, best_from):
			Game.message.emit("CHEGARA POSTI xabar berdi: dushman %s tomonda to'planmoqda. Tayyorgarlik uchun qo'shimcha vaqt bor." % _name(best_from), "event")
		Game.message.emit("RAZVEDKA: %s %s chegarasida qo'shin to'playapti (%d kuch). Taxminan %d kundan keyin hujum! Garnizonni kuchaytiring." % [country_name(c), _name(best_to), int(strength), last["stage"]], "bad")


# ---------------------------------------------------------------- saqlash

func to_dict() -> Dictionary:
	var arm: Array = []
	for a in armies:
		var d: Dictionary = a.duplicate(true)
		d["pos"] = [a["pos"].x, a["pos"].y]
		d.erase("prev_pos")
		arm.append(d)
	var con: Array = []
	for c in convoys:
		con.append({"id": c["id"], "army": c["army"], "pos": [c["pos"].x, c["pos"].y],
			"start": [c["start"].x, c["start"].y], "rolled": c["rolled"]})
	return {"armies": arm, "convoys": con, "wars": wars, "next_id": _next_id}


func from_dict(d: Dictionary) -> void:
	target_from = ""
	armies.clear()
	convoys.clear()
	for a in d.get("armies", []):
		var pos := Vector2(a["pos"][0], a["pos"][1])
		armies.append({
			"id": int(a["id"]), "owner": a["owner"],
			"soldiers": float(a["soldiers"]), "tanks": float(a["tanks"]),
			"pos": pos, "prev_pos": pos, "at": a["at"], "base": a["base"],
			"path": Array(a["path"]), "state": a["state"],
			"supply": float(a["supply"]), "warned": bool(a["warned"]), "stage": int(a.get("stage", 0)),
		})
	for c in d.get("convoys", []):
		var pos2 := Vector2(c["pos"][0], c["pos"][1])
		convoys.append({"id": int(c["id"]), "army": int(c["army"]), "pos": pos2, "prev_pos": pos2,
			"start": Vector2(c["start"][0], c["start"][1]), "rolled": bool(c["rolled"])})
	wars = {}
	var wd: Dictionary = d.get("wars", {})
	for c in wd:
		wars[c] = {"start": int(wd[c]["start"]), "next_attack": int(wd[c]["next_attack"])}
	_next_id = int(d.get("next_id", 1))
