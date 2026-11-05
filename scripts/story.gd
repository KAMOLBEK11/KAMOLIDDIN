extends Node
## Tarixiy sujetlar (13-bosqich): tayyor boshlang'ich holat, kirish hikoyasi, maqsad, g'alaba/mag'lubiyat
## Maqsad turlari:
##   capture - "target" viloyatini "days" kun ichida bosib olish
##   hold    - "target" viloyatini "days" kun ushlab turish (dushman bir necha bor hujum qiladi)

const LIST := {
	"toxtamish": {
		"era": 1, "year": "1395", "title": "Terek jangi: To'xtamishga qarshi",
		"short": "Oltin O'rda xoni To'xtamish Temurga qarshi chiqdi. Sohibqiron Shimolga yurish boshlaydi.",
		"country": "TIM", "start": "Otror", "enemy": "GHO", "type": "capture", "target": "Saroy", "days": 420,
		"money": 2600, "army": {"qilichboz": 45, "nayzachi": 35, "kamonchi": 40, "otliq": 40}, "enemy_def": 140.0,
		"goal_text": "Oltin O'rda poytaxti Saroyni 420 kun ichida egallang.",
		"intro": "1395-yil bahori. Bir vaqtlar Temur yordami bilan taxtga chiqqan To'xtamish endi Movarounnahrga qarshi qilich ko'tardi. Uning qo'shini Darband orqali Shirvonga bostirib kirdi.\n\nSohibqiron Amir Temur katta qo'shin to'plab, Otrordan Shimolga - Oltin O'rda tomon yo'l oldi. Terek daryosi bo'yida hal qiluvchi jang kutmoqda.\n\nQal'angizni mustahkamlang, qo'shin to'plang va dushman yerlari orqali Saroygacha yetib boring.",
		"win": "Tarixda ham shunday bo'lgan: 1395-yil 15-aprelda Terek daryosi bo'yidagi jangda Temur To'xtamishni tor-mor qildi. Saroy va Oltin O'rdaning boshqa shaharlari vayron qilindi, O'rda shundan keyin hech qachon avvalgi qudratiga qaytmadi.",
		"lose": "To'xtamish bu safar omon qoldi. Tarixda esa Temur 1395-yilda Terek jangida g'alaba qozongan va Oltin O'rdaning qudratini sindirgan edi."},
	"dehli": {
		"era": 1, "year": "1398", "title": "Hindiston yurishi: Dehli",
		"short": "Temur Hindukushdan oshib, Dehli sultonligiga yurish qiladi. Sulton Mahmud qo'shinida jangovar fillar bor.",
		"country": "TIM", "start": "Kobul", "enemy": "DEL", "type": "capture", "target": "Dehli", "days": 360,
		"money": 2200, "army": {"qilichboz": 40, "nayzachi": 40, "kamonchi": 35, "otliq": 30}, "enemy_def": 160.0,
		"goal_text": "Dehlini 360 kun ichida egallang.",
		"intro": "1398-yil. Dehli sultonligi ichki nizolardan zaiflashgan. Amir Temur Kobuldan chiqib, Hindukush tog'laridan oshdi va Hind daryosini kechib o'tdi.\n\nDehli ostonasida Sulton Mahmud va vaziri Mallu Iqbol qo'shini - piyodalar, otliqlar va jangovar fillar kutib turibdi.\n\nYo'ldagi qal'alarni oling va Dehliga yeting.",
		"win": "Tarixda: 1398-yil 17-dekabrda Temur Dehli ostonasida Sulton Mahmud qo'shinini yengdi. Fillarga qarshi u tikanli to'siqlar va olov qo'llagan. Dehli egallandi, ko'p boylik va hunarmandlar Samarqandga olib ketildi.",
		"lose": "Dehli bu safar bardosh berdi. Tarixda esa Temur 1398-yil dekabrida Dehli ostonasidagi jangda g'olib chiqqan edi."},
	"anqara": {
		"era": 1, "year": "1402", "title": "Anqara jangi: Boyazid Yildirimga qarshi",
		"short": "Usmonli sultoni Boyazid Yildirim Temur bilan to'qnashadi. Ikki buyuk sarkarda Anqara yaqinida uchrashadi.",
		"country": "TIM", "start": "Tabriz", "enemy": "OTT", "annex": ["KAR", "AYD"], "type": "capture", "target": "Ankara", "days": 380,
		"money": 2800, "army": {"qilichboz": 45, "nayzachi": 40, "kamonchi": 40, "otliq": 45}, "enemy_def": 190.0,
		"goal_text": "Anqarani 380 kun ichida egallang.",
		"intro": "1402-yil. Usmonli sultoni Boyazid Yildirim Konstantinopolni qamal qilmoqda va Anadoluning sharqiy beyliklarini bo'ysundirmoqda. Qochgan beylar Temurdan panoh so'radi.\n\nSohibqiron Sivas orqali Anadoluga kirdi. Boyazid qamalni tashlab, qo'shinini Anqara tomon olib keldi.\n\nUsmonlilar qal'alarini oling va Anqaraga yeting.",
		"win": "Tarixda: 1402-yil 28-iyulda Anqara jangida Temur Boyazid Yildirimni yengdi va asir oldi. Usmonli davlati o'n yildan ortiq ichki urushga botdi, Konstantinopol qamali to'xtadi.",
		"lose": "Boyazid bu safar g'olib chiqdi. Tarixda esa Anqara jangida (1402) Temur Usmonli sultonini asir olgan edi."},
	"toshkent": {
		"era": 2, "year": "1865", "title": "Toshkent mudofaasi",
		"short": "General Chernyayev qo'shini Toshkent devorlari ostida. Qo'qon xonligi shaharni himoya qiladi.",
		"country": "KOK", "start": "Toshkent", "enemy": "RUS", "type": "hold", "target": "Toshkent", "days": 150,
		"money": 1800, "army": {"sarboz": 60, "nayzachi": 40, "otliq": 20, "top": 4}, "enemy_def": 320.0,
		"goal_text": "Toshkentni 150 kun ushlab turing - Rossiya qo'shini bir necha bor hujum qiladi.",
		"intro": "1865-yil bahori. Rossiya imperiyasi Chimkent va Avliyootani egallab, Toshkent tomon yurdi. General Chernyayev qo'shini zamonaviy miltiq va to'plar bilan qurollangan.\n\nToshkent - O'rta Osiyoning eng katta va boy shahri, uzunligi yigirma chaqirimdan ortiq devor bilan o'ralgan. Qo'qon lashkarboshisi Alimqul shaharni himoya qilishga keldi.\n\nDevorlarni mustahkamlang, sarbozlar va to'plarni joylang, josuslar yuboring. Shaharni 150 kun saqlab qoling.",
		"win": "Siz Toshkentni saqlab qoldingiz! Tarixda esa 1865-yil 9-mayda Alimqul jangda halok bo'ldi, 17-iyunda shahar ruslar qo'liga o'tdi va keyinchalik Turkiston general-gubernatorligining markaziga aylandi.",
		"lose": "Toshkent qo'ldan ketdi - tarixda ham shunday bo'lgan: 1865-yil iyunida shahar Rossiya qo'shiniga taslim bo'ldi."},
	"samarqand": {
		"era": 2, "year": "1868", "title": "Samarqand va Zarafshon",
		"short": "Buxoro amiri Muzaffar Rossiyaga qarshi g'azovat e'lon qildi. Samarqand xavf ostida.",
		"country": "BUK", "start": "Samarqand", "enemy": "RUS", "type": "hold", "target": "Samarqand", "days": 160,
		"money": 2000, "army": {"sarboz": 70, "nayzachi": 50, "otliq": 25, "top": 5}, "enemy_def": 350.0,
		"goal_text": "Samarqandni 160 kun ushlab turing.",
		"intro": "1868-yil. Xo'jand va O'ratepani olgan Rossiya qo'shini Zarafshon vodiysiga yaqinlashdi. Amir Muzaffar g'azovat e'lon qilib, Cho'ponota tepaliklarida qo'shin to'pladi.\n\nGeneral Kaufman Samarqandga yurish boshladi. Amir Temur poytaxti, Registon va Bibixonim - bularning barchasi endi sizning qo'lingizda.\n\nQal'ani mustahkamlang, to'plar quying, ittifoqchilar izlang. Samarqandni 160 kun saqlang.",
		"win": "Samarqand omon qoldi! Tarixda esa 1868-yil 2-mayda shahar Kaufmanga taslim bo'ldi, Buxoro amirligi esa o'sha yili Rossiya protektoratiga aylandi.",
		"lose": "Samarqand qo'ldan ketdi. Tarixda ham 1868-yil may oyida shahar Rossiya qo'shiniga o'tgan edi."},
	"xiva": {
		"era": 2, "year": "1873", "title": "Xiva yurishi",
		"short": "Rossiya qo'shini to'rt tomondan cho'lni kesib, Xorazm vohasiga yurdi.",
		"country": "KHI", "start": "Xiva", "enemy": "RUS", "type": "hold", "target": "Xiva", "days": 140,
		"money": 1700, "army": {"sarboz": 45, "nayzachi": 60, "otliq": 40, "top": 3}, "enemy_def": 320.0,
		"goal_text": "Xivani 140 kun ushlab turing.",
		"intro": "1873-yil bahori. General Kaufman boshchiligidagi qo'shin Toshkent, Orenburg, Mang'ishloq va Krasnovodskdan - to'rt tomondan Qizilqum va Qoraqum cho'llarini kesib o'tmoqda.\n\nXiva xoni Muhammad Rahimxon II vohani himoya qilishga tayyorlanmoqda. Cho'l - eng katta ittifoqchingiz: dushman suvsiz qoladi.\n\nXivani 140 kun saqlang.",
		"win": "Xiva bardosh berdi! Tarixda esa 1873-yil 29-mayda Rossiya qo'shini Xivaga kirdi, Gandimiyon shartnomasi bilan xonlik Rossiya protektoratiga aylandi.",
		"lose": "Xiva taslim bo'ldi - tarixda ham 1873-yil may oyida shunday bo'lgan."},
}

var active := ""
var state := {}
var _layer: CanvasLayer
var _goal_label: Label


func _ready() -> void:
	Game.day_passed.connect(_on_day)


func _find_province(name: String, country := "") -> String:
	for id in Game.province_order:
		var p: Dictionary = Game.provinces[id]
		if p["name"] == name and (country == "" or p["country"] == country):
			return id
	for id in Game.province_order:
		if Game.provinces[id]["name"] == name:
			return id
	return ""


func _borders(pid: String, owner: String) -> bool:
	for n in Game.provinces[pid]["neighbors"]:
		if Game.provinces[n]["owner"] == owner:
			return true
	return false


func _nearest_own(country: String, to_id: String) -> String:
	var best := ""
	var bd := 1e18
	var c: Vector2 = Game.provinces[to_id]["center"]
	for id in Game.province_order:
		var p: Dictionary = Game.provinces[id]
		if p["country"] == country and p["owner"] == country:
			var d: float = (p["center"] as Vector2).distance_squared_to(c)
			if d < bd:
				bd = d
				best = id
	return best


func begin(id: String) -> void:
	if not LIST.has(id):
		return
	var s: Dictionary = LIST[id]
	active = id
	var target := _find_province(s["target"])
	var start := _find_province(s["start"], s["country"])
	if start == "" or Game.provinces[start]["country"] != s["country"]:
		start = _nearest_own(s["country"], target) if target != "" else ""
	if start == "":
		push_warning("Sujet boshlang'ich viloyati topilmadi: %s" % id)
		return
	var enemy0: String = s["enemy"]
	# tarixiy holat: dushman bu yerlarni allaqachon bo'ysundirgan (masalan Boyazid - Qoramon va Aydin beyliklarini)
	for ac in s.get("annex", []):
		for pid in Game.province_order:
			if Game.provinces[pid]["owner"] == ac:
				Game.provinces[pid]["owner"] = enemy0
	if s["type"] == "capture" and not _borders(start, enemy0):
		# dushman bilan chegaradosh, nishonga eng yaqin o'z viloyatimizdan boshlaymiz
		var best := ""
		var bd := 1e18
		for pid in Game.province_order:
			var q: Dictionary = Game.provinces[pid]
			if q["owner"] == s["country"] and _borders(pid, enemy0):
				var d: float = (q["center"] as Vector2).distance_squared_to(Game.provinces[target]["center"])
				if d < bd:
					bd = d
					best = pid
		if best != "":
			start = best
	Game.world_year = int(s["year"])
	Game.start_game(start)
	var p: Dictionary = Game.provinces[start]
	Game.money = float(s["money"])
	Game.goods = {"oziq": 700.0, "yogoch": 500.0, "tosh": 700.0}
	Game.spies = 1
	_prebuilt_castle(p, s["army"])
	var enemy: String = s["enemy"]
	# dushman: chegaradagi viloyatlari kuchli, urush boshida e'lon qilingan
	for pid in Game.province_order:
		var q: Dictionary = Game.provinces[pid]
		if q["owner"] == enemy:
			q["max_defense"] = maxf(float(q["max_defense"]), float(s["enemy_def"]) * (1.0 if q["name"] == s["target"] else 0.55))
			q["defense"] = q["max_defense"]
	if s["type"] == "hold" and not _borders(start, enemy):
		# dushman qo'shini allaqachon yaqin qo'shni viloyatda (tarixdagidek)
		var nb := ""
		for n in Game.provinces[start]["neighbors"]:
			if Game.provinces[n]["owner"] != Game.PLAYER and (nb == "" or Game.provinces[n]["country"] != s["country"]):
				nb = n
		if nb != "":
			Game.provinces[nb]["owner"] = enemy
	if s["type"] == "hold":
		for n in Game.provinces[start]["neighbors"]:
			if Game.provinces[n]["owner"] == enemy:
				Game.provinces[n]["max_defense"] = maxf(Game.provinces[n]["max_defense"], float(s["enemy_def"]))
				Game.provinces[n]["defense"] = Game.provinces[n]["max_defense"]
		# dushman tezroq va qayta-qayta hujum qiladi
		War.declare_war(enemy, true)
		War.wars[enemy]["next_attack"] = Game.day + 12
	else:
		War.declare_war(enemy, false)
		War.wars[enemy]["next_attack"] = Game.day + 90
	state = {"start_day": Game.day, "target": target, "done": false}
	Game.select(start)
	_show_panel(s["title"] + "  (" + s["year"] + ")", s["intro"], "MAQSAD: " + s["goal_text"], "Boshladik!", func(): pass)
	_update_goal()
	Game.changed.emit()


func _prebuilt_castle(p: Dictionary, army: Dictionary) -> void:
	## tayyor qal'a: to'rtburchak devor, minoralar, darvoza, xandaq, kazarma, otxona, temirchi, ombor, xo'jalik
	var c := CastleEco.castle(p)
	var pts := [[-38.0, -30.0], [38.0, -30.0], [38.0, 30.0], [-38.0, 30.0]]
	c["walls"] = []
	c["towers"] = []
	for i in 4:
		c["walls"].append({"a": pts[i], "b": pts[(i + 1) % 4], "hp": 1.0})
		c["towers"].append({"p": pts[i]})
	for tp in [[0.0, -30.0], [0.0, 30.0], [38.0, 0.0]]:
		c["towers"].append({"p": tp})
	c["gates"] = [{"p": [-38.0, 0.0], "ang": PI / 2.0}]
	c["moats"] = [{"a": [-48.0, -40.0], "b": [48.0, -40.0], "hp": 1.0}, {"a": [48.0, -40.0], "b": [48.0, 40.0], "hp": 1.0},
		{"a": [48.0, 40.0], "b": [-48.0, 40.0], "hp": 1.0}]
	c["buildings"] = [{"t": "barracks", "p": [14.0, 18.0], "rot": 0.0}, {"t": "stable", "p": [-16.0, 18.0], "rot": 0.0},
		{"t": "smithy", "p": [18.0, -18.0], "rot": 0.0}, {"t": "granary", "p": [-18.0, -18.0], "rot": 0.0},
		{"t": "well", "p": [26.0, 2.0], "rot": 0.0},
		{"t": "farm", "p": [80.0, 20.0], "rot": 0.0}, {"t": "farm", "p": [80.0, -20.0], "rot": 0.0},
		{"t": "market", "p": [-75.0, 30.0], "rot": 0.0}, {"t": "lumber", "p": [70.0, 60.0], "rot": 0.0}, {"t": "quarry", "p": [-70.0, -55.0], "rot": 0.0}]
	c["stats"] = {"closed": true, "capacity": 400, "score": 60.0, "weakest": 3, "sectors": [60.0, 60.0, 60.0, 55.0]}
	c["army"] = {}
	for k in CastleEco.units():
		c["army"][k] = int(army.get(k, 0))
	c["mirror"] = -1.0
	CastleEco.sync(p)


func _on_day(_d: int) -> void:
	if active == "" or state.get("done", true) or not Game.started:
		return
	var s: Dictionary = LIST[active]
	var t: String = state["target"]
	var left: int = int(state["start_day"]) + int(s["days"]) - Game.day
	if Game.player_provinces().is_empty():
		_finish(false)
		return
	if s["type"] == "capture":
		if t != "" and Game.provinces[t]["owner"] == Game.PLAYER:
			_finish(true)
		elif left <= 0:
			_finish(false)
	else:
		if t != "" and Game.provinces[t]["owner"] != Game.PLAYER:
			_finish(false)
		elif left <= 0:
			_finish(true)
		else:
			# dushman tinim bermaydi: urush davom etadi, hujumlar tez-tez
			var enemy: String = s["enemy"]
			if not War.wars.has(enemy):
				War.declare_war(enemy, true)
			elif int(War.wars[enemy]["next_attack"]) > Game.day + 40:
				War.wars[enemy]["next_attack"] = Game.day + 30
	_update_goal()


func _finish(win: bool) -> void:
	state["done"] = true
	var s: Dictionary = LIST[active]
	Game.set_speed(0)
	_show_panel("G'ALABA!" if win else "MAG'LUBIYAT", s["win"] if win else s["lose"],
		"Erkin o'yinni davom ettirishingiz yoki bosh menyuga qaytishingiz mumkin.", "Davom etish", func(): pass, true)
	_update_goal()


func _update_goal() -> void:
	if active == "" or not LIST.has(active):
		if _goal_label:
			_goal_label.get_parent().visible = false
		return
	_ensure_layer()
	var s: Dictionary = LIST[active]
	var left: int = maxi(0, int(state.get("start_day", 0)) + int(s["days"]) - Game.day)
	var txt := ""
	if state.get("done", false):
		txt = "%s - sujet yakunlandi" % s["title"]
	elif s["type"] == "capture":
		txt = "MAQSAD: %s ni oling - %d kun qoldi" % [s["target"], left]
	else:
		txt = "MAQSAD: %s ni ushlab turing - %d kun qoldi" % [s["target"], left]
	_goal_label.text = txt
	_goal_label.get_parent().visible = true


func _ensure_layer() -> void:
	if _layer and is_instance_valid(_layer):
		return
	_layer = CanvasLayer.new()
	_layer.layer = 8
	get_tree().root.add_child(_layer)
	var pc := PanelContainer.new()
	pc.set_anchors_preset(Control.PRESET_CENTER_TOP)
	pc.position = Vector2(-260, 54)
	pc.custom_minimum_size = Vector2(520, 0)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_theme_stylebox_override("panel", UIKit.style(Color(0.35, 0.12, 0.08, 0.82), 10, Color(1, 0.8, 0.4, 0.5), 8))
	_layer.add_child(pc)
	_goal_label = UIKit.label("", 15, Color("#ffe8b0"))
	_goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pc.add_child(_goal_label)


func _show_panel(title: String, text: String, goal: String, btn: String, cb: Callable, menu_btn := false) -> void:
	_ensure_layer()
	var before := Game.speed
	Game.set_speed(0)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.55)
	_layer.add_child(shade)
	var pc := PanelContainer.new()
	pc.set_anchors_preset(Control.PRESET_CENTER)
	pc.custom_minimum_size = Vector2(720, 0)
	pc.position = Vector2(-360, -230)
	pc.add_theme_stylebox_override("panel", UIKit.style(Color(0.07, 0.09, 0.13, 0.96), 14, Color(1, 0.82, 0.4, 0.6), 22))
	shade.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	pc.add_child(v)
	v.add_child(UIKit.label(title, 26, Color("#ffd166")))
	for para in text.split("\n\n"):
		v.add_child(UIKit.label(para, 15, Color("#e6edf5"), true))
	v.add_child(UIKit.label(goal, 15, Color("#9fe0a8"), true))
	var h := UIKit.row(v, 10)
	UIKit.button(h, btn, "", func():
		shade.queue_free()
		Game.set_speed(maxi(1, before) if not menu_btn else 0)
		cb.call(), true)
	if menu_btn:
		UIKit.button(h, "Bosh menyu", "", func():
			shade.queue_free()
			active = ""
			_update_goal()
			Game.story = ""
			get_tree().change_scene_to_file("res://scenes/menu.tscn"))


func to_dict() -> Dictionary:
	return {"active": active, "state": state}


func from_dict(d: Dictionary) -> void:
	active = str(d.get("active", ""))
	state = d.get("state", {})
	_update_goal.call_deferred()
