extends PanelContainer
## Davlat byudjeti: kunlik daromad/xarajat va resurs zaxiralari (neft, gaz, oltin...).

var body: VBoxContainer
var _dirty := false
const RES_ICON := {"neft": "#3a3a3a", "gaz": "#5ab4d6", "tilla": "#e8c14a", "temir": "#8a8f96",
	"paxta": "#f2f2ec", "bugdoy": "#d8b65a", "mis": "#c4743c", "komir": "#222222"}


func _ready() -> void:
	var v := UIKit.window(self, "DAVLAT BYUDJETI", "res://icons/coin.svg", 820, 600)
	body = UIKit.scroll(v)
	Game.changed.connect(func(): _dirty = true)


func _process(_d: float) -> void:
	if _dirty and visible:
		_dirty = false
		rebuild()


func toggle() -> void:
	visible = not visible
	if visible:
		rebuild()


func rebuild() -> void:
	UIKit.clear(body)
	# --- kunlik hisob
	var tax := 0.0
	var ind := 0.0
	var res := 0.0
	var upk := 0.0
	for id in Game.player_provinces():
		var inc := Game.province_income(Game.provinces[id])
		tax += inc["tax"]; ind += inc["industry"]; res += inc["resources"]; upk += inc["upkeep"]
	var c := UIKit.card(body)
	var h := UIKit.row(c, 16)
	h.add_child(UIKit.pic("res://icons/coin.svg", Vector2(46, 46)))
	var tv := VBoxContainer.new()
	h.add_child(tv)
	tv.add_child(UIKit.label("G'azna: %s $" % _fmt(Game.money), 24, UIKit.GOLD))
	var tot := Game.total_income()
	tv.add_child(UIKit.label("Kunlik sof natija: %+d $" % int(tot), 16, UIKit.GOOD if tot >= 0 else UIKit.BAD))
	var g := UIKit.grid(c, 2)
	for pair in [["Soliqlar", tax], ["Sanoat", ind], ["Resurs savdosi (avto)", res], ["Savdo shartnomalari", Diplo.trade_income()],
			["Eksport shartnomalari", Politics.contract_income()], ["Armiya va binolar xarajati", -upk - War.army_upkeep()],
			["Razvedka va maxfiy ishlar", -(Politics.counter_intel * Politics.COUNTER_INTEL_UPKEEP + Politics.ops.size() * Politics.OP_DAILY)]]:
		g.add_child(UIKit.label(pair[0], 14, UIKit.DIM))
		var v: float = pair[1]
		g.add_child(UIKit.label("%+d $/kun" % int(v), 14, UIKit.GOOD if v >= 0 else UIKit.BAD))
	if not Diplo.debts.is_empty():
		var due := 0.0
		for d in Diplo.debts:
			due += d["amount"]
		c.add_child(UIKit.label("Qarzlar: %d $ qaytarilishi kerak" % int(due), 14, UIKit.BAD))

	# --- zaxiralar
	body.add_child(UIKit.label("Resurs zaxiralari", 19, Color.WHITE))
	body.add_child(UIKit.label("Konlar har kuni resurs qazib oladi. Bir qismi avtomatik sotiladi, qolgani zaxiraga tushadi. Narx oshganda zaxirani soting!", 13, UIKit.DIM, true))
	var out := Game.national_output()
	var any := false
	for r in Game.RESOURCE_NAMES:
		var st: float = Game.stock.get(r, 0.0)
		var o: float = out.get(r, 0.0)
		if st <= 0.0 and o <= 0.0:
			continue
		any = true
		var rc := UIKit.card(body, UIKit.CARD2)
		var rh := UIKit.row(rc, 12)
		var sw := ColorRect.new()
		sw.color = Color(RES_ICON.get(r, "#888888"))
		sw.custom_minimum_size = Vector2(28, 28)
		rh.add_child(sw)
		var nm := UIKit.label(Game.RESOURCE_NAMES[r], 17, Color.WHITE)
		nm.custom_minimum_size = Vector2(90, 0)
		rh.add_child(nm)
		var info := UIKit.label("Zaxira: %s %s   |   qazib olish: %.1f/kun   |   narx %.1f $" % [_fmt(int(st)), Game.RESOURCE_UNIT[r], o, Game.resource_price(r)], 14, UIKit.INFO)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rh.add_child(info)
		var rh2 := UIKit.row(rc)
		rh2.add_child(UIKit.label("Avto-sotish:", 13, UIKit.DIM))
		var cur: float = Game.sell_share.get(r, 0.8)
		for sh in [0.0, 0.5, 0.8, 1.0]:
			var b := UIKit.button(rh2, "%d%%" % int(sh * 100), "", Game.set_share.bind(r, sh), absf(cur - sh) < 0.01)
			b.custom_minimum_size = Vector2(52, 0)
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rh2.add_child(sp)
		UIKit.button(rh2, "Yarmini sotish (+%d $)" % int(st * 0.5 * Game.resource_price(r)), "" if st >= 1 else "Zaxira bo'sh", Game.sell_stock.bind(r, 0.5))
		UIKit.button(rh2, "Hammasini sotish", "" if st >= 1 else "Zaxira bo'sh", Game.sell_stock.bind(r, 1.0), true)
	if not any:
		body.add_child(UIKit.label("Hali resurs qazilmayapti. Viloyatda 'Kon / neft bazasi' quring.", 15, UIKit.GOLD, true))

	# --- harbiy zaxira
	body.add_child(UIKit.label("Harbiy zaxira", 19, Color.WHITE))
	var mg := UIKit.grid(body, 4)
	var u := War.player_unit_totals()
	for item in [["soldier", "Askar", u.get("soldier", 0)], ["mbt", "Tank", u.get("tank", 0)]]:
		_mil_cell(mg, item[0], item[1], int(item[2]))
	for w in Politics.arsenal:
		if Politics.arsenal[w] > 0:
			_mil_cell(mg, w, Politics.weapon(w)["name"], Politics.arsenal[w])


func _mil_cell(g: GridContainer, pic: String, name: String, n: int) -> void:
	var c := UIKit.card(g, UIKit.CARD2)
	c.add_child(UIKit.weapon_pic(pic, Vector2(150, 90)))
	c.add_child(UIKit.label("%s: %d" % [name, n], 14, Color.WHITE))


func _fmt(n: float) -> String:
	var s := str(int(n))
	var out := ""
	while s.length() > 3:
		out = " " + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out
