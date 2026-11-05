extends PanelContainer
## Diplomatiya oynasi: chapda bayroqli davlatlar ro'yxati (qo'shnilar + jahon kuchlari),
## o'ngda davlat kartasi: kuch ko'rsatkichlari, qurollari rasmlar bilan, shartnomalar, qarz, askar.

var list_box: VBoxContainer
var detail: VBoxContainer
var current := ""     # "" = umumiy holat
var _dirty := false


func _ready() -> void:
	var v := UIKit.window(self, "DIPLOMATIYA", "res://icons/politic.svg", 1080, 640)
	var h := UIKit.row(v, 12)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var lw := VBoxContainer.new()
	lw.custom_minimum_size = Vector2(270, 0)
	h.add_child(lw)
	list_box = UIKit.scroll(lw)
	var rw := VBoxContainer.new()
	rw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(rw)
	detail = UIKit.scroll(rw)
	Game.changed.connect(func(): _dirty = true)
	Diplo.open_window.connect(open_at)


func _process(_d: float) -> void:
	if _dirty and visible:
		_dirty = false
		rebuild()


func open_at(c: String) -> void:
	current = c
	visible = true
	rebuild()


func toggle() -> void:
	if visible:
		visible = false
	else:
		open_at(current)


# ---------------------------------------------------------------- ro'yxat

func _list_item(code: String, name: String, sub: String, col: Color) -> void:
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = current == code
	b.custom_minimum_size = Vector2(0, 46)
	b.pressed.connect(open_at.bind(code))
	list_box.add_child(b)
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 6
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 8)
	b.add_child(h)
	if code != "":
		var f := UIKit.flag(code, 42)
		f.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(f)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", -2)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(v)
	var l1 := UIKit.label(name, 15, Color.WHITE)
	l1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l1)
	var l2 := UIKit.label(sub, 12, col)
	l2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l2)


func rebuild() -> void:
	UIKit.clear(list_box)
	UIKit.clear(detail)
	_list_item("", "Umumiy holat", "ittifoq, savdo, yordam" if Game.era < 4 else "qarzlar, ijara, sanksiya", UIKit.DIM)
	list_box.add_child(UIKit.label("QO'SHNI DAVLATLAR" if Game.era >= 4 else "DAVLATLAR (qo'shnilar avval)", 12, UIKit.GOLD))
	var clist: Array = Game.countries.keys()
	if Game.era < 4:
		# qo'shni va ittifoqchilar tepada
		clist.sort_custom(func(a, b):
			var ka := (0 if Diplo.alliance.has(a) or War.wars.has(a) else (1 if Diplo.borders_player(a) else 2))
			var kb := (0 if Diplo.alliance.has(b) or War.wars.has(b) else (1 if Diplo.borders_player(b) else 2))
			return ka < kb if ka != kb else Diplo.rel[a] > Diplo.rel[b])
	for c in clist:
		if not Diplo.alive(c):
			continue
		var r: float = Diplo.rel[c]
		var col := UIKit.BAD if War.wars.has(c) else UIKit.rel_color(r)
		_list_item(c, War.country_name(c), "%s  %+d" % [Diplo.rel_text(c), roundi(r)], col)
	if Game.era < 4:
		if current == "":
			_overview_old()
		elif Game.countries.has(current) and Diplo.alive(current):
			_country_old(current)
		else:
			_overview_old()
		return
	list_box.add_child(UIKit.label("JAHON KUCHLARI", 12, UIKit.GOLD))
	for p in Politics.powers():
		if Game.countries.has(p):
			continue
		var r2: float = Politics.prel[p]
		var sub := "%s  %+d" % [Politics.rel_word(r2), roundi(r2)]
		if Politics.sanctioned_by(p):
			sub += "  SANKSIYA"
		_list_item(p, Politics.pname(p), sub, UIKit.BAD if Politics.sanctioned_by(p) else UIKit.rel_color(r2))
	if current == "":
		_overview()
	elif Game.countries.has(current):
		if Diplo.alive(current):
			_country(current)
		else:
			_overview()
	else:
		_power(current)


# ---------------------------------------------------------------- 1-2-zamon: oddiy diplomatiya

func _overview_old() -> void:
	var c := UIKit.card(detail)
	c.add_child(UIKit.label("Diplomatiya", 22, Color.WHITE))
	c.add_child(UIKit.label("Chapdagi ro'yxatdan davlatni tanlang. Munosabat 45 dan oshsa - ittifoq tuzish mumkin; savdo shartnomasi har kuni oltin keltiradi va resurs almashishga imkon beradi.", 13, UIKit.DIM, true))
	c.add_child(UIKit.label("Savdodan daromad: +%d oltin/kun" % roundi(Diplo.trade_income()), 14, UIKit.GOOD))
	var al: Array = Diplo.alliance.keys().filter(func(a): return Diplo.alive(a)).map(func(a): return War.country_name(a))
	c.add_child(UIKit.label("Ittifoqchilar: " + (", ".join(al) if al.size() else "yo'q"), 14, Color.WHITE, true))
	var tr: Array = Diplo.trade.keys().map(func(a): return War.country_name(a))
	c.add_child(UIKit.label("Savdo hamkorlari: " + (", ".join(tr) if tr.size() else "yo'q"), 14, Color.WHITE, true))
	var w: Array = War.wars.keys().map(func(a): return War.country_name(a))
	c.add_child(UIKit.label("Urushdagi dushmanlar: " + (", ".join(w) if w.size() else "yo'q"), 14, UIKit.BAD if w.size() else UIKit.DIM, true))
	var d := UIKit.card(detail)
	d.add_child(UIKit.label("Askar almashuvi", 17, Color.WHITE))
	if Diplo.aid_in.is_empty() and Diplo.aid_out.is_empty():
		d.add_child(UIKit.label("Hozir yo'lda hech kim yo'q.", 13, UIKit.DIM))
	for x in Diplo.aid_in:
		d.add_child(UIKit.label("%s dan %d jangchi kelmoqda - %d kun" % [War.country_name(x["country"]), Diplo.army_n(x["army"]), x["days"]], 14, UIKit.GOOD))
	for x in Diplo.aid_out:
		d.add_child(UIKit.label("%s da %d askaringiz - qaytishiga %d kun" % [War.country_name(x["country"]), Diplo.army_n(x["army"]), x["days"]], 14))


func _country_old(c: String) -> void:
	var r: float = Diplo.rel[c]
	var st: Array = []
	if Diplo.borders_player(c): st.append("chegaradosh")
	if Diplo.trade.has(c): st.append("savdo hamkori")
	if Diplo.alliance.has(c): st.append("ittifoqchi")
	var cult: String = Game.countries[c].get("culture", "")
	var hc := _header(c, War.country_name(c), [
		["Munosabat: %s (%+d)%s" % [Diplo.rel_text(c), roundi(r), ("   |   " + ", ".join(st)) if st.size() else ""], UIKit.BAD if War.wars.has(c) else UIKit.rel_color(r)],
		["Viloyatlar: %d   |   Qo'shini: %s" % [Diplo.country_provinces(c).size(), {"temur": "temuriy uslubda", "arab": "arab", "italiya": "yunon-rim uslubida",
			"yevropa": "yevropa ritsarlari", "rus": "rus drujinasi", "xitoy": "xitoy", "ozbek": "o'zbek sarbozlari"}.get(Unit3D.faction_for(c), "")], UIKit.DIM]])
	var def := 0.0
	for id in Diplo.country_provinces(c):
		def += Game.provinces[id].get("defense", 0.0)
	UIKit.stat(hc, "Munosabat", r + 100.0, 200.0, UIKit.rel_color(r), "%+d" % roundi(r))
	UIKit.stat(hc, "Harbiy kuch", def, 1500.0, Color("#c0504d"), "~%d jangchi" % int(def))
	UIKit.stat(hc, "Xazina", Diplo.treasury[c], 5000.0, UIKit.GOLD, "%d oltin" % roundi(Diplo.treasury[c]))
	if War.wars.has(c):
		var wc := UIKit.card(detail, Color("#3a1f22"))
		var days: int = Game.day - War.wars[c]["start"]
		wc.add_child(UIKit.label("URUSH: %d kundan beri. Sulh %d kundan keyin mumkin." % [days, maxi(0, War.PEACE_MIN_DAYS - days)], 16, UIKit.BAD, true))
		UIKit.button(wc, "Sulh taklif qilish", "", War.make_peace.bind(c), true)
		return
	var a := UIKit.card(detail)
	a.add_child(UIKit.label("Shartnomalar", 17, Color.WHITE))
	if Diplo.trade.has(c):
		_act(a, "Savdo shartnomasini bekor qilish", "", Diplo.cancel_trade.bind(c))
	else:
		_act(a, "Savdo (karvon yo'li): +%d oltin/kun" % Diplo.trade_value(c), Diplo.why_trade(c), Diplo.sign_trade.bind(c))
	if not Diplo.alliance.has(c):
		_act(a, "Ittifoq tuzish (bir-biriga yordam)", Diplo.why_alliance(c), Diplo.sign_alliance.bind(c))
	_act(a, "Sovg'a yuborish (%d oltin, munosabat +10)" % Diplo.gift_cost(), "" if Game.money >= Diplo.gift_cost() else "Oltin yetmaydi", Diplo.send_gift.bind(c))
	var h := UIKit.card(detail)
	h.add_child(UIKit.label("Ittifoqchilik", 17, Color.WHITE))
	h.add_child(UIKit.label("Urushda ittifoqchidan qo'shin so'rashingiz mumkin. Ular qiyin kunda sizdan yordam so'rasa, askar yuborsangiz - munosabat oshadi va keyin ular ham ko'proq yordam beradi.", 13, UIKit.DIM, true))
	_act(h, "Yordam so'rash (qal'angizga jangchilar keladi)", Diplo.why_ask_help(c), Diplo.ask_help.bind(c))
	var hh := UIKit.row(h)
	for n in [10, 25]:
		_act(hh, "%d askar yuborish" % n, Diplo.why_send_help(c, n), Diplo.send_help.bind(c, n))
	var g := UIKit.card(detail)
	g.add_child(UIKit.label("Resurs savdosi", 17, Color.WHITE))
	g.add_child(UIKit.label("Omboringizdagi oziq, yog'och va toshni sotish yoki sotib olish (savdo shartnomasi kerak).", 13, UIKit.DIM, true))
	for res in ["oziq", "yogoch", "tosh"]:
		var row := UIKit.row(g)
		var l := UIKit.label("%s (%d)" % [CastleEco.RES_NAMES[res], int(Game.goods.get(res, 0.0))], 14, Color.WHITE)
		l.custom_minimum_size = Vector2(120, 0)
		row.add_child(l)
		_act(row, "Sotish 50 (+%d)" % Diplo.goods_price(res, 50, true), Diplo.why_goods(c, res, 50, true), Diplo.trade_goods.bind(c, res, 50, true))
		_act(row, "Olish 50 (-%d)" % Diplo.goods_price(res, 50, false), Diplo.why_goods(c, res, 50, false), Diplo.trade_goods.bind(c, res, 50, false))


# ---------------------------------------------------------------- umumiy

func _overview() -> void:
	var c := UIKit.card(detail)
	c.add_child(UIKit.label("Umumiy holat", 22, Color.WHITE))
	if Diplo.sanctioned():
		c.add_child(UIKit.label("Siz GLOBAL SANKSIYA ostidasiz: yana %d kun. Savdo yo'q, resurslar yarim narxda." % Diplo.sanction_days, 15, UIKit.BAD, true))
	else:
		c.add_child(UIKit.label("Global sanksiya yo'q. Kredit tarixi: %s" % ("toza" if Diplo.defaulted == 0 else "%d marta defolt" % Diplo.defaulted), 14, UIKit.GOOD if Diplo.defaulted == 0 else UIKit.GOLD, true))
	var sl: Array = []
	for p in Politics.psanction:
		if Politics.psanction[p] > 0:
			sl.append("%s (%d kun)" % [Politics.pname(p), Politics.psanction[p]])
	if sl.size():
		c.add_child(UIKit.label("Sizga sanksiya qo'yganlar: " + ", ".join(sl), 14, UIKit.BAD, true))
	c.add_child(UIKit.label("Savdodan daromad: +%d $/kun" % roundi(Diplo.trade_income() + Politics.contract_income()), 14))

	var d1 := UIKit.card(detail)
	d1.add_child(UIKit.label("Olingan qarzlar", 17, Color.WHITE))
	if Diplo.debts.is_empty():
		d1.add_child(UIKit.label("Qarzingiz yo'q.", 13, UIKit.DIM))
	for i in Diplo.debts.size():
		var d: Dictionary = Diplo.debts[i]
		var left: int = d["due"] - Game.day
		var h := UIKit.row(d1)
		h.add_child(UIKit.flag(d["country"], 30))
		var l := UIKit.label("%s: %d $  (muddati %d kundan keyin)" % [War.country_name(d["country"]), roundi(d["amount"]), left], 14, UIKit.BAD if left < 10 else UIKit.INFO)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		UIKit.button(h, "To'lash", "" if Game.money >= d["amount"] else "Pul yetmaydi", Diplo.repay.bind(i))
	var d2 := UIKit.card(detail)
	d2.add_child(UIKit.label("Berilgan qarzlar va askar ijarasi", 17, Color.WHITE))
	if Diplo.credits.is_empty() and Diplo.leases.is_empty():
		d2.add_child(UIKit.label("Yo'q.", 13, UIKit.DIM))
	for cr in Diplo.credits:
		d2.add_child(UIKit.label("%s: %d $ qaytarishi kerak (%d kundan keyin)" % [War.country_name(cr["country"]), roundi(cr["amount"]), cr["due"] - Game.day], 14))
	for l2 in Diplo.leases:
		var t := "%s dan %d askar olingan" if l2["kind"] == "in" else "%s ga %d askar berilgan"
		d2.add_child(UIKit.label((t % [War.country_name(l2["country"]), l2["soldiers"]]) + "  (%d kun qoldi)" % l2["days"], 14))


# ---------------------------------------------------------------- qo'shni davlat

func _header(code: String, name: String, lines: Array) -> VBoxContainer:
	var c := UIKit.card(detail, UIKit.CARD, Color("#3b4a5c"))
	var h := UIKit.row(c, 16)
	h.add_child(UIKit.flag(code, 120))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UIKit.label(name, 26, Color.WHITE))
	for l in lines:
		v.add_child(UIKit.label(l[0], 14, l[1], true))
	return c


func _country(c: String) -> void:
	var r: float = Diplo.rel[c]
	var reg: Dictionary = Politics.data["regional"].get(c, {})
	var st: Array = []
	if Diplo.borders_player(c): st.append("chegaradosh")
	if Diplo.trade.has(c): st.append("savdo shartnomasi")
	if Diplo.alliance.has(c): st.append("ittifoqchi")
	if Diplo.transit.has(c): st.append("tranzit")
	var hc := _header(c, War.country_name(c), [
		["%s  |  Bloklar: %s" % [Politics.ideo_name(reg.get("ideology", "secular")), ", ".join(reg.get("blocs", [])) if reg.get("blocs", []).size() else "yo'q"], UIKit.DIM],
		["Munosabat: %s (%+d)%s" % [Diplo.rel_text(c), roundi(r), ("   |   " + ", ".join(st)) if st.size() else ""], UIKit.BAD if War.wars.has(c) else UIKit.rel_color(r)],
		[reg.get("note", ""), UIKit.DIM]])
	var def := 0.0
	for id in Diplo.country_provinces(c):
		def += Game.provinces[id]["defense"]
	var pop := Diplo.country_pop(c)
	UIKit.stat(hc, "Munosabat", r + 100.0, 200.0, UIKit.rel_color(r), "%+d" % roundi(r))
	UIKit.stat(hc, "Harbiy kuch", def, 600.0, Color("#c0504d"), str(int(def)))
	UIKit.stat(hc, "Aholi", pop / 1000.0, 60.0, Color("#4f8fc0"), "%.1f mln" % (pop / 1000.0))
	UIKit.stat(hc, "Xazina", Diplo.treasury[c], 20000.0, UIKit.GOLD, "%d $" % roundi(Diplo.treasury[c]))

	var mc := UIKit.card(detail)
	mc.add_child(UIKit.label("Harbiy imkoniyatlari (razvedka bahosi)", 17, Color.WHITE))
	var g := UIKit.grid(mc, 4)
	_unit_cell(g, "soldier", "Askarlar", "~%d" % int(def * 0.6 * 10))
	_unit_cell(g, "mbt", "Tanklar", "~%d" % int(def * 0.4 / War.TANK_POWER))
	if def > 200:
		_unit_cell(g, "sam", "Havo mudofaasi", "bor")
	if c == "CHN":
		_unit_cell(g, "jet", "Qiruvchilar", "ko'p")
		_unit_cell(g, "missile", "Raketalar", "ko'p")

	if War.wars.has(c):
		var wc := UIKit.card(detail, Color("#3a1f22"))
		var days: int = Game.day - War.wars[c]["start"]
		wc.add_child(UIKit.label("URUSH: %d kundan beri. Sulh %d kundan keyin mumkin." % [days, War.PEACE_MIN_DAYS], 16, UIKit.BAD, true))
		UIKit.button(wc, "Sulh taklif qilish", "", War.make_peace.bind(c), true)
		return

	var a := UIKit.card(detail)
	a.add_child(UIKit.label("Shartnomalar", 17, Color.WHITE))
	if Diplo.trade.has(c):
		_act(a, "Savdo shartnomasini bekor qilish", "", Diplo.cancel_trade.bind(c))
	else:
		_act(a, "Savdo shartnomasi (+%d $/kun)" % Diplo.trade_value(c), Diplo.why_trade(c), Diplo.sign_trade.bind(c))
	if not Diplo.alliance.has(c):
		_act(a, "Harbiy ittifoq (hujumda yordam beradi)", Diplo.why_alliance(c), Diplo.sign_alliance.bind(c))
	if not Diplo.transit.has(c):
		_act(a, "Tranzit ruxsati - samolyotlar ustidan uchadi (%d $)" % Diplo.TRANSIT_PRICE, Diplo.why_transit(c), Diplo.buy_transit.bind(c))
	_act(a, "Sovg'a yuborish (%d $, munosabat +10)" % Diplo.GIFT, "" if Game.money >= Diplo.GIFT else "Pul yetmaydi", Diplo.send_gift.bind(c))

	var m := UIKit.card(detail)
	m.add_child(UIKit.label("Moliya", 17, Color.WHITE))
	m.add_child(UIKit.label("Qarz olish: 10%%, %d kun, maksimal %d $. Qarz berish: 15%%, %d kun." % [Diplo.LOAN_DAYS, Diplo.max_loan(c), Diplo.LEND_DAYS], 13, UIKit.DIM, true))
	var mh := UIKit.row(m)
	for amount in [2000, 5000, 10000]:
		_act(mh, "Olish %d $" % amount, Diplo.why_borrow(c, amount), Diplo.borrow.bind(c, amount))
	var mh2 := UIKit.row(m)
	for amount in [2000, 5000]:
		_act(mh2, "Berish %d $" % amount, Diplo.why_lend(c, amount), Diplo.lend.bind(c, amount))

	var s := UIKit.card(detail)
	s.add_child(UIKit.label("Askar va qurol", 17, Color.WHITE))
	var tp := Diplo.target_province()
	if tp != "":
		var tpp: Dictionary = Game.provinces[tp]
		s.add_child(UIKit.label("Viloyat: %s (%d askar, %d tank). Boshqasini xaritadan tanlang." % [tpp["name"], roundi(tpp["units"]["soldier"]), roundi(tpp["units"]["tank"])], 13, UIKit.DIM, true))
	var sh := UIKit.row(s)
	for n in [50, 100]:
		_act(sh, "%d askar ijaraga olish (%d $)" % [n, n * Diplo.RENT_PRICE], Diplo.why_rent(c, n), Diplo.rent_soldiers.bind(c, n))
	var sh2 := UIKit.row(s)
	_act(sh2, "50 askar berish (+%d $)" % (50 * Diplo.LEND_SOLDIER_PRICE), Diplo.why_lend_soldiers(c, 50), Diplo.lend_soldiers.bind(c, 50))
	for n in [1, 5]:
		_act(sh2, "%d tank sotish (+%d $)" % [n, n * Diplo.TANK_SALE_PRICE], Diplo.why_sell_tanks(c, n), Diplo.sell_tanks.bind(c, n))
	if Politics.has_center():
		var op := UIKit.row(s)
		_act(op, "Maxfiy: muxolifatni moliyalash", Politics.why_op(c), Politics.start_op.bind(c))
	if Politics.data["powers"].has(c):
		_power_sections(c)


func _unit_cell(g: GridContainer, pic: String, name: String, val: String) -> void:
	var c := UIKit.card(g, UIKit.CARD2)
	c.add_child(UIKit.weapon_pic(pic, Vector2(160, 96)))
	c.add_child(UIKit.label("%s: %s" % [name, val], 14, Color.WHITE))


func _act(parent: Control, text: String, why: String, cb: Callable) -> void:
	var b := UIKit.button(parent, text, why, cb)
	if why != "" and parent is VBoxContainer:
		parent.add_child(UIKit.label("   " + why, 12, UIKit.DIM, true))


# ---------------------------------------------------------------- jahon kuchi

func _power(p: String) -> void:
	var P := Politics
	var d: Dictionary = P.data["powers"][p]
	var r: float = P.prel[p]
	var lines := [
		["%s  |  Bloklar: %s" % [P.ideo_name(d["ideology"]), ", ".join(d["blocs"]) if d["blocs"].size() else "yo'q"], UIKit.DIM],
		["Munosabat: %s (%+d)" % [P.rel_word(r), roundi(r)], UIKit.rel_color(r)]]
	if d["wars"].size():
		lines.append(["Urushda: " + ", ".join(d["wars"].map(func(x): return P.pname(x))), UIKit.BAD])
	if d["sanctions"].size():
		lines.append(["Sanksiya qo'ygan: " + ", ".join(d["sanctions"].map(func(x): return P.pname(x))), UIKit.GOLD])
	if P.sanctioned_by(p):
		lines.append(["SIZGA SANKSIYA QO'YGAN: %d kun qoldi" % P.psanction[p], UIKit.BAD])
	lines.append([d["note"], UIKit.DIM])
	var hc := _header(p, d["name"], lines)
	UIKit.stat(hc, "Munosabat", r + 100.0, 200.0, UIKit.rel_color(r), "%+d" % roundi(r))
	UIKit.stat(hc, "Harbiy kuch", d["military"], 100.0, Color("#c0504d"))
	UIKit.stat(hc, "Iqtisodiyot", d["economy"], 100.0, UIKit.GOLD)
	if P.influence[p] >= 1.0:
		UIKit.stat(hc, "Ichingizda ta'sir", P.influence[p], 100.0, UIKit.BAD, "%d%%" % int(P.influence[p]))
	_power_sections(p)


func _power_sections(p: String) -> void:
	var P := Politics
	var d: Dictionary = P.data["powers"][p]
	if not P.has_center():
		var nc := UIKit.card(detail, Color("#3a3220"))
		nc.add_child(UIKit.label("Qurol sotib olish, litsenziya va eksport shartnomalari uchun avval Siyosiy markaz quring (700 $).", 15, UIKit.GOLD, true))

	if d["sells"].size():
		var wc := UIKit.card(detail)
		wc.add_child(UIKit.label("Sotadigan qurollari", 17, Color.WHITE))
		wc.add_child(UIKit.label("Import - tayyor qurol %d kunda keladi. Litsenziya - o'z harbiy zavodingizda arzon ishlab chiqarasiz. Raqiblari bundan norozi bo'ladi." % P.IMPORT_DAYS, 13, UIKit.DIM, true))
		var g := UIKit.grid(wc, 3)
		for w in d["sells"]:
			var wd: Dictionary = P.weapon(w)
			var cc := UIKit.card(g, UIKit.CARD2)
			cc.custom_minimum_size = Vector2(240, 0)
			cc.add_child(UIKit.weapon_pic(w, Vector2(220, 130)))
			cc.add_child(UIKit.label(wd["name"], 16, Color.WHITE))
			cc.add_child(UIKit.label(wd["desc"], 12, UIKit.DIM, true))
			cc.add_child(UIKit.label("Narx: %d $ / dona   Sizda: %d" % [P.import_price(p, w), P.arsenal[w]], 13, UIKit.GOLD))
			var bh := UIKit.row(cc, 6)
			UIKit.button(bh, "Import x1", P.why_import(p, w, 1), P.buy_import.bind(p, w, 1), true)
			UIKit.button(bh, "x3", P.why_import(p, w, 3), P.buy_import.bind(p, w, 3))
			if P.licenses.has(w):
				cc.add_child(UIKit.label("Litsenziya bor (%s)" % P.pname(P.licenses[w]), 12, UIKit.GOOD))
			else:
				UIKit.button(cc, "Litsenziya - %d $" % int(wd["license"]), P.why_license(p, w), P.buy_license.bind(p, w))
			var why := P.why_import(p, w, 1)
			if why != "" and why != "Pul yetmaydi":
				cc.add_child(UIKit.label(why, 12, UIKit.BAD, true))

	if d["buys"].size():
		var tc := UIKit.card(detail)
		tc.add_child(UIKit.label("Xarid qiladi (eksport shartnomasi: 180 kun, narx +40%)", 17, Color.WHITE))
		if p in ["IRN", "RUS", "PRK"]:
			tc.add_child(UIKit.label("Diqqat: bu davlat bilan savdo AQSh va Yevropaning ikkilamchi sanksiyasiga olib kelishi mumkin.", 13, UIKit.BAD, true))
		var th := UIKit.row(tc)
		for res in d["buys"]:
			UIKit.button(th, Game.RESOURCE_NAMES[res], P.why_contract(p, res), P.sign_contract.bind(p, res))
		for c in P.contracts:
			if c["power"] == p:
				tc.add_child(UIKit.label("Faol: %s - %d kun qoldi" % [Game.RESOURCE_NAMES[c["res"]], c["days"]], 13, UIKit.GOOD))

	var ac := UIKit.card(detail)
	ac.add_child(UIKit.label("Hamdardlik", 17, Color.WHITE))
	UIKit.button(ac, "Insonparvarlik yordami yuborish (%d $): munosabat +10" % P.AID_COST, P.why_simple(P.AID_COST), P.send_aid.bind(p))
