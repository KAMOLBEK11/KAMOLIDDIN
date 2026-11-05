extends PanelContainer
## Siyosiy markaz oynasi: davlat, jahon, qurollar, qora bozor, savdo, maxfiy ishlar, yangiliklar.

const COL_GOOD := Color("#7bd88f")
const COL_BAD := Color("#ff6b6b")
const COL_EVENT := Color("#ffd166")
const COL_INFO := Color("#cfd8e3")
const COL_DIM := Color("#8a97a8")
const TABS := ["Davlat", "Jahon", "Qurollar", "Qora bozor", "Savdo", "Maxfiy ishlar", "Yangiliklar"]

var tabs: TabContainer
var boxes := {}
var box: VBoxContainer
var _dirty := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(960, 600)
	offset_left = -480
	offset_right = 480
	offset_top = -300
	offset_bottom = 300
	visible = false
	var v := VBoxContainer.new()
	add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	head.add_child(_icon("res://icons/politic.svg", 30))
	var title := _label("SIYOSIY MARKAZ", 22, Color.WHITE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = "  X  "
	close.pressed.connect(func(): visible = false)
	head.add_child(close)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tabs)
	for t in TABS:
		var sc := ScrollContainer.new()
		sc.name = t
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		tabs.add_child(sc)
		var b := VBoxContainer.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_constant_override("separation", 6)
		sc.add_child(b)
		boxes[t] = b
	tabs.tab_changed.connect(func(_i): rebuild())
	Game.changed.connect(func(): _dirty = true)
	Politics.news_added.connect(func(): _dirty = true)


func _process(_d: float) -> void:
	if _dirty and visible:
		_dirty = false
		rebuild()


func toggle() -> void:
	visible = not visible
	if visible:
		rebuild()


func open_tab(name: String) -> void:
	visible = true
	tabs.current_tab = TABS.find(name)
	rebuild()


# ---------------------------------------------------------------- yordamchilar

func _icon(path: String, px: int) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(px, px)
	return t


func _label(text: String, size := 15, color := COL_INFO, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _text(t: String, size := 14, color := COL_INFO) -> void:
	box.add_child(_label(t, size, color, true))


func _section(t: String) -> void:
	box.add_child(HSeparator.new())
	box.add_child(_label(t, 17, Color.WHITE))


func _btn(text: String, why: String, cb: Callable, parent: Control = null) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = why != ""
	b.tooltip_text = why
	b.clip_text = parent == null
	b.pressed.connect(cb)
	(parent if parent else box).add_child(b)
	return b


func _row() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	box.add_child(h)
	return h


func _rel_col(r: float) -> Color:
	if r >= 20: return COL_GOOD
	if r >= -20: return COL_INFO
	return COL_BAD


func _bar(v: float, col: Color) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.min_value = 0
	pb.max_value = 100
	pb.value = v
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(200, 14)
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	pb.add_theme_stylebox_override("fill", sb)
	return pb


# ---------------------------------------------------------------- qurish

func rebuild() -> void:
	var t: String = TABS[tabs.current_tab]
	box = boxes[t]
	for c in box.get_children():
		c.queue_free()
	if not Politics.has_center() and t != "Jahon" and t != "Yangiliklar":
		_section("Siyosiy markaz qurilmagan")
		_text("Bu bo'limdagi barcha ishlar Siyosiy markaz binosi orqali bajariladi. Uni istalgan provinsiyangizda quring (700 $, 8 kun). Davlatda faqat bitta bo'ladi.", 15, COL_EVENT)
		if Politics.center_planned():
			_text("Markaz qurilmoqda...", 14, COL_DIM)
		_text("\nHozircha 'Jahon' va 'Yangiliklar' bo'limlarini ko'rishingiz mumkin.", 14, COL_DIM)
		return
	match t:
		"Davlat": _tab_state()
		"Jahon": _tab_world()
		"Qurollar": _tab_weapons()
		"Qora bozor": _tab_black()
		"Savdo": _tab_trade()
		"Maxfiy ishlar": _tab_covert()
		"Yangiliklar": _tab_news()


func _tab_state() -> void:
	var P := Politics
	_section("Davlat tuzumi: " + P.ideo_name(P.ideology))
	_text(P.ideo()["desc"], 13, COL_DIM)
	if P.pending_ideology != "":
		_text("O'tish davri: '%s' ga %d kun qoldi (daromad -10%%, norozilik yuqori)." % [P.ideo_name(P.pending_ideology), P.ideology_days], 14, COL_EVENT)
	var h := _row()
	h.add_child(_label("Xalq qo'llovi: %d%%" % int(P.support), 15, COL_GOOD if P.support >= 50 else COL_BAD))
	h.add_child(_bar(P.support, Color("#4fb06d")))
	var h2 := _row()
	h2.add_child(_label("Xorijiy ta'sir: %d%%" % int(P.total_influence()), 15, COL_BAD if P.total_influence() > 30 else COL_INFO))
	h2.add_child(_bar(P.total_influence(), Color("#c0504d")))
	var lst: Array = []
	for p in P.influence:
		if P.influence[p] >= 1.0:
			lst.append("%s %d%%" % [P.pname(p), int(P.influence[p])])
	if lst.size() > 0:
		_text("Muxolifatni moliyalayotganlar: " + ", ".join(lst), 13, COL_BAD)
	if P.total_influence() > 40 and P.support < 45:
		_text("DIQQAT: to'ntarish xavfi yuqori! Qarshi razvedka, targ'ibot yoki bostirish kerak.", 14, COL_BAD)
	if P.ideology == "democracy":
		_text("Keyingi saylov: %d kundan keyin (qo'llov 40%% dan past bo'lsa yutqazasiz)." % maxi(0, P.next_election - Game.day), 13, COL_DIM)

	_section("Ichki siyosat")
	_btn("Milliy targ'ibot kampaniyasi (%d $): 30 kun qo'llov oshadi" % P.PROPAGANDA_COST, P.why_simple(P.PROPAGANDA_COST), P.propaganda)
	var ci_why := "Maksimal daraja" if P.counter_intel >= 3 else P.why_simple(P.COUNTER_INTEL_COST)
	_btn("Qarshi razvedka %d/3 -> oshirish (%d $, kuniga %d $): xorijiy ta'sirni kamaytiradi" % [P.counter_intel, P.COUNTER_INTEL_COST, int(P.COUNTER_INTEL_UPKEEP)], ci_why, P.buy_counter_intel)
	_btn("Muxolifatni bostirish (600 $): ta'sir -60%, qo'llov -10, AQSh va Yevropa norozi", P.why_simple(600), P.crackdown)

	_section("Davlat tuzumini o'zgartirish (%d $, %d kun)" % [P.IDEOLOGY_CHANGE_COST, P.IDEOLOGY_CHANGE_DAYS])
	for i in P.data["ideologies"]:
		var d: Dictionary = P.data["ideologies"][i]
		var fans: Array = []
		var foes: Array = []
		for p in P.powers():
			var lk: int = int(P.data["powers"][p]["likes"].get(i, 0))
			if lk >= 20: fans.append(P.pname(p))
			elif lk <= -20: foes.append(P.pname(p))
		_btn("%s  (daromad x%.2f)" % [d["name"], float(d["income"])], P.why_ideology(i), P.change_ideology.bind(i))
		_text("   Qo'llaydi: %s.   Qarshi: %s." % [", ".join(fans) if fans.size() else "-", ", ".join(foes) if foes.size() else "-"], 12, COL_DIM)


func _tab_world() -> void:
	var P := Politics
	_section("Jahon kuchlari  (%s)" % P.data.get("snapshot", ""))
	_text("Munosabatlar sizning davlat tuzumingiz, savdo va qurol xaridlaringizga qarab o'zgaradi. Raqib davlatdan qurol olsangiz, ikkinchisi xafa bo'ladi.", 13, COL_DIM)
	for p in P.powers():
		var d: Dictionary = P.data["powers"][p]
		var r: float = P.prel[p]
		var h := _row()
		var sw := ColorRect.new()
		sw.color = Color(d["flag"])
		sw.custom_minimum_size = Vector2(16, 16)
		h.add_child(sw)
		var nm := _label("%s" % d["name"], 16, Color.WHITE)
		nm.custom_minimum_size = Vector2(170, 0)
		h.add_child(nm)
		var rl := _label("%s (%+d)" % [P.rel_word(r), int(r)], 14, _rel_col(r))
		rl.custom_minimum_size = Vector2(130, 0)
		h.add_child(rl)
		h.add_child(_label("Harbiy %d  |  Iqtisod %d  |  %s" % [d["military"], d["economy"], P.ideo_name(d["ideology"])], 13, COL_DIM))
		if P.has_center():
			_btn("Yordam (%d $)" % P.AID_COST, P.why_simple(P.AID_COST), P.send_aid.bind(p), h)
		var info: Array = []
		if d["wars"].size():
			info.append("Urushda: " + ", ".join(d["wars"].map(func(x): return P.pname(x))))
		if d["sanctions"].size():
			info.append("Sanksiya qo'ygan: " + ", ".join(d["sanctions"].map(func(x): return P.pname(x))))
		if d["blocs"].size():
			info.append("Bloklar: " + ", ".join(d["blocs"]))
		if P.sanctioned_by(p):
			info.append("SIZGA SANKSIYA: %d kun" % P.psanction[p])
		if P.influence[p] >= 1.0:
			info.append("Ichingizdagi ta'siri: %d%%" % int(P.influence[p]))
		_text("    " + "   ".join(info), 12, COL_EVENT if P.sanctioned_by(p) else COL_INFO)
		_text("    " + d["note"], 12, COL_DIM)

	_section("Mintaqa davlatlari")
	for c in P.data["regional"]:
		var rd: Dictionary = P.data["regional"][c]
		var rr: float = Diplo.rel.get(c, 0.0)
		_text("%s - %s, bloklar: %s. Munosabat: %+d. %s" % [Game.countries[c]["name"], P.ideo_name(rd["ideology"]), ", ".join(rd["blocs"]) if rd["blocs"].size() else "yo'q", int(rr), rd["note"]], 13, _rel_col(rr))


func _tab_weapons() -> void:
	var P := Politics
	_section("Arsenal")
	var parts: Array = []
	for w in P.arsenal:
		parts.append("%s: %d" % [P.weapon(w)["name"], P.arsenal[w]])
	_text(", ".join(parts), 14, Color.WHITE)
	_text("Bonuslar: piyoda x%.2f, tank x%.2f, militsiya +%d" % [P.mult("soldier"), P.mult("tank"), int(P.bonus("militia"))], 13, COL_GOOD)
	for x in P.production:
		_text("Zavodda: %d ta %s - %d kun" % [x["n"], P.weapon(x["weapon"])["name"], x["days"]], 13, COL_EVENT)
	for x in P.imports:
		_text("Yo'lda: %d ta %s (%s) - %d kun" % [x["n"], P.weapon(x["weapon"])["name"], "qora bozor" if x["black"] else P.pname(x["from"]), x["days"]], 13, COL_EVENT)
	_text("Harbiy zavodlar: %d. Litsenziya olsangiz o'zingiz arzon ishlab chiqarasiz; bo'lmasa import qilasiz yoki qora bozordan olasiz." % P.military_factories(), 13, COL_DIM)
	for w in P.data["weapons"]:
		var wd: Dictionary = P.weapon(w)
		_section("%s - %s" % [wd["name"], wd["desc"]])
		if P.licenses.has(w):
			var h := _row()
			h.add_child(_label("Litsenziya: %s.  O'zimiz ishlab chiqaramiz: %d $/dona" % [P.pname(P.licenses[w]), P.produce_cost(w)], 14, COL_GOOD))
			for n in [1, 5]:
				_btn("+%d" % n, P.why_produce(w, n), P.produce.bind(w, n), h)
		for p in P.sellers(w):
			var h2 := _row()
			var l := _label("%s:" % P.pname(p), 14, _rel_col(P.prel[p]))
			l.custom_minimum_size = Vector2(150, 0)
			h2.add_child(l)
			_btn("Import 1 ta (%d $)" % P.import_price(p, w), P.why_import(p, w, 1), P.buy_import.bind(p, w, 1), h2)
			_btn("Import 3 ta (%d $)" % (P.import_price(p, w) * 3), P.why_import(p, w, 3), P.buy_import.bind(p, w, 3), h2)
			if not P.licenses.has(w):
				_btn("Litsenziya (%d $)" % int(wd["license"]), P.why_license(p, w), P.buy_license.bind(p, w), h2)
			var why := P.why_import(p, w, 1)
			if why != "" and why != "Pul yetmaydi":
				h2.add_child(_label(why, 12, COL_DIM))


func _tab_black() -> void:
	var P := Politics
	_section("Qora bozor")
	_text("Hech qanday ruxsatnoma kerak emas, sanksiya ham to'sqinlik qilmaydi - lekin narx 2.5-3 barobar qimmat. Har yuk 20% ehtimol bilan chegarada ushlanadi, 20% ehtimol bilan OAVda fosh bo'ladi (AQSh va Yevropa munosabati tushadi, sanksiya xavfi).", 13, COL_EVENT)
	for w in P.data["weapons"]:
		var wd: Dictionary = P.weapon(w)
		var h := _row()
		var l := _label("%s  -  %d $/dona%s" % [wd["name"], P.black_price(w), "  (CHEGIRMA)" if P.black_disc.has(w) else ""], 14, Color.WHITE)
		l.custom_minimum_size = Vector2(420, 0)
		h.add_child(l)
		for n in [1, 3]:
			_btn("Sotib olish x%d" % n, P.why_black(w, n), P.buy_black.bind(w, n), h)
	_section("Askar va tank kontrabandasi")
	var h2 := _row()
	_btn("10 askar (%d $)" % (Diplo.BLACK_SOLDIER * 10), "" if Game.money >= Diplo.BLACK_SOLDIER * 10 else "Pul yetmaydi", Diplo.black_market.bind(10, 0), h2)
	_btn("1 tank (%d $)" % Diplo.BLACK_TANK, "" if Game.money >= Diplo.BLACK_TANK else "Pul yetmaydi", Diplo.black_market.bind(0, 1), h2)


func _tab_trade() -> void:
	var P := Politics
	_section("Jahon bozori narxlari")
	var parts: Array = []
	for r in Game.RESOURCE_NAMES:
		var m: float = Game.price_mult[r]["mult"] if Game.price_mult.has(r) else 1.0
		parts.append("%s %.1f $ (%s%d%%)" % [Game.RESOURCE_NAMES[r], Game.resource_price(r), "+" if m >= 1.0 else "", int(round((m - 1.0) * 100))])
	_text(", ".join(parts), 13, Color.WHITE)
	for r in P.data.get("markets", {}):
		_text("  - " + P.data["markets"][r]["note"], 12, COL_DIM)
	_section("Eksport shartnomalari (180 kun, resurs daromadi +40%)")
	if P.contracts.is_empty():
		_text("Faol shartnoma yo'q.", 13, COL_DIM)
	for c in P.contracts:
		_text("%s -> %s: kuniga +%d $, %d kun qoldi" % [Game.RESOURCE_NAMES[c["res"]], P.pname(c["power"]), int(P.produced(c["res"]) * Game.resource_price(c["res"]) * 0.4), c["days"]], 14, COL_GOOD)
	_text("Siz qazayotgan resurslar: " + _produced_text(), 13, COL_INFO)
	for p in P.powers():
		var buys: Array = P.data["powers"][p]["buys"]
		if buys.is_empty():
			continue
		var h := _row()
		var l := _label("%s xarid qiladi:" % P.pname(p), 14, _rel_col(P.prel[p]))
		l.custom_minimum_size = Vector2(230, 0)
		h.add_child(l)
		for res in buys:
			var why := P.why_contract(p, res)
			var b := _btn(Game.RESOURCE_NAMES[res], why, P.sign_contract.bind(p, res), h)
			if why != "":
				b.tooltip_text = why
		if p in ["IRN", "RUS", "PRK"]:
			h.add_child(_label("(ikkilamchi sanksiya xavfi)", 12, COL_BAD))


func _produced_text() -> String:
	var out: Array = []
	for r in Game.RESOURCE_NAMES:
		var v := Politics.produced(r)
		if v > 0:
			out.append("%s %d" % [Game.RESOURCE_NAMES[r], int(v)])
	return ", ".join(out) if out.size() else "yo'q (Kon quring)"


func _tab_covert() -> void:
	var P := Politics
	_section("Muxolifatni moliyalash (to'ntarish tayyorlash)")
	_text("Qo'shni davlatda muxolifatni %d kun moliyalasangiz (300 $ + kuniga %d $), uning bir provinsiyasi markazdan ajraladi va zaif holga keladi - uni egallashingiz mumkin. Har kuni fosh bo'lish xavfi bor: fosh bo'lsa munosabat -40." % [P.OP_DAYS, int(P.OP_DAILY)], 13, COL_DIM)
	for o in P.ops:
		_text("Davom etmoqda: %s - %d kun qoldi" % [P.pname(o["country"]), o["days"]], 14, COL_EVENT)
	for c in Game.countries:
		var has := false
		for id in Game.province_order:
			if Game.provinces[id]["owner"] == c:
				has = true
				break
		if not has:
			continue
		var h := _row()
		var l := _label(Game.countries[c]["name"], 14, Color.WHITE)
		l.custom_minimum_size = Vector2(160, 0)
		h.add_child(l)
		_btn("Operatsiya boshlash", P.why_op(c), P.start_op.bind(c), h)
		_btn("Insonparvarlik yordami (%d $)" % P.AID_COST, P.why_simple(P.AID_COST), P.send_aid.bind(c), h)


func _tab_news() -> void:
	var P := Politics
	_section("Yangiliklar lentasi")
	_text("Onlayn: " + ("ulangan - real jahon yangiliklari o'yinga ta'sir qiladi" if P.online_ok else "ulanmagan (internet bo'lsa avtomatik ulanadi). Hozir real voqealar ssenariysi ishlamoqda."), 13, COL_GOOD if P.online_ok else COL_DIM)
	for n in P.news:
		var col := COL_INFO
		match n["kind"]:
			"good": col = COL_GOOD
			"bad": col = COL_BAD
			"event": col = COL_EVENT
		_text("[%s] %s" % [n["tag"], n["text"]], 13, col)
