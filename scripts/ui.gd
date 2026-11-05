extends CanvasLayer
## Interfeys: yuqori panel, provinsiya paneli, xabarlar.

const COL_GOOD := Color("#7bd88f")
const COL_BAD := Color("#ff6b6b")
const COL_EVENT := Color("#ffd166")
const COL_INFO := Color("#cfd8e3")
const COL_DIM := Color("#8a97a8")

var money_label: Label
var income_label: Label
var date_label: Label
var army_label: Label
var speed_buttons := {}
var side_panel: PanelContainer
var side_box: VBoxContainer
var log_box: VBoxContainer
var hint: PanelContainer
var hint_label: Label
var war_label: Label
var confirm: ConfirmationDialog
var _pending := []   # [country, from, to]
var diplo_win: PanelContainer
var tech_win: PanelContainer
var offer: ConfirmationDialog
var pol_win: PanelContainer
var inbox_win: PanelContainer
var budget_win: PanelContainer
var border_win: PanelContainer
var inbox_btn: Button
var _offer_yes := Callable()
var _offer_no := Callable()
var _speed_before := 1


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)
	_build_top_bar(root)
	_build_side_panel(root)
	_build_log(root)
	_build_hint(root)
	Game.changed.connect(_refresh)
	Game.selected.connect(func(_id): _rebuild_panel())
	Game.message.connect(_on_message)
	War.target_mode_changed.connect(func(_f): _refresh())
	War.need_confirm.connect(_ask_war)
	confirm = ConfirmationDialog.new()
	confirm.title = "Urush e'lon qilish"
	confirm.ok_button_text = "Ha, hujum!"
	confirm.cancel_button_text = "Yo'q"
	confirm.exclusive = false
	confirm.confirmed.connect(_on_war_confirmed)
	root.add_child(confirm)
	diplo_win = preload("res://scripts/diplo_window.gd").new()
	root.add_child(diplo_win)
	tech_win = preload("res://scripts/tech_window.gd").new()
	root.add_child(tech_win)
	pol_win = preload("res://scripts/politics_window.gd").new()
	root.add_child(pol_win)
	inbox_win = preload("res://scripts/inbox_window.gd").new()
	root.add_child(inbox_win)
	budget_win = preload("res://scripts/budget_window.gd").new()
	root.add_child(budget_win)
	border_win = preload("res://scripts/border_window.gd").new()
	root.add_child(border_win)
	offer = ConfirmationDialog.new()
	offer.title = "Diplomatik xabar"
	offer.ok_button_text = "Qabul qilish"
	offer.cancel_button_text = "Rad etish"
	offer.dialog_autowrap = true
	offer.exclusive = false
	offer.min_size = Vector2i(520, 0)
	offer.confirmed.connect(func(): _resolve_offer(true))
	offer.canceled.connect(func(): _resolve_offer(false))
	root.add_child(offer)
	Diplo.proposal.connect(_on_proposal)
	War.battle_choice.connect(_on_battle_choice)
	_refresh()


func _ask_war(country: String, from_id: String, to_id: String) -> void:
	_pending = [country, from_id, to_id]
	confirm.dialog_text = "%s ga hujum qilish uchun urush e'lon qilishingiz kerak.\n\n%s ning boshqa provinsiyalari ham qarshi hujumga o'tishi mumkin.\nKamida %d kun sulh tuzib bo'lmaydi.\n\nUrush e'lon qilasizmi?" % [War.country_name(country), War.country_name(country), War.PEACE_MIN_DAYS]
	confirm.popup_centered()


var _queue: Array = []


func _on_proposal(text: String, yes: Callable, no: Callable) -> void:
	if not Diplo.is_urgent(text):
		Diplo.post(text, yes, no)   # o'yinni to'xtatmaydi - Xabarlar qutisiga tushadi
		return
	_urgent(text, yes, no)


func _urgent(text: String, yes: Callable, no: Callable, ok := "Qabul qilish", cancel := "Rad etish") -> void:
	if offer.visible or _offer_yes.is_valid() or _offer_no.is_valid():
		# oldingi xabar javobini kutyapmiz - navbatga qo'yamiz
		_queue.append([text, yes, no, ok, cancel])
		return
	_offer_yes = yes
	_offer_no = no
	offer.dialog_text = text
	offer.ok_button_text = ok
	offer.cancel_button_text = cancel
	if Game.speed != 0:
		_speed_before = Game.speed
	Game.set_speed(0)
	offer.popup_centered()


func _resolve_offer(yes: bool) -> void:
	var cb := _offer_yes if yes else _offer_no
	_offer_yes = Callable()
	_offer_no = Callable()
	if cb.is_valid():
		cb.call()
	if not _queue.is_empty():
		var nxt: Array = _queue.pop_front()
		_urgent.call_deferred(nxt[0], nxt[1], nxt[2], nxt[3], nxt[4])
		return
	Game.set_speed(_speed_before)


func _on_battle_choice(army_id: int) -> void:
	var a := War.get_army(army_id)
	if a.is_empty() or War.battle_open:
		return
	var p: Dictionary = Game.provinces[a["at"]]
	var mine: bool = a["owner"] == Game.PLAYER
	var text := "JANG BOSHLANDI: %s\n\n%s\n\nJangni o'zingiz boshqarasizmi (3D maydon: %%s) yoki qo'mondonlarga topshirasizmi (avtomatik hisob)?" % [
		p["name"], ("Qo'shiningiz %s hududiga kirdi." % War.country_name(p["owner"])) if mine else ("%s qo'shini hududingizga bostirib kirdi." % War.country_name(a["owner"]))]
	text = text % ("askar va tanklarni joylashtirasiz, nishon berasiz" if Game.era >= 4 else
		(("qal'angiz devorida himoyalanasiz - dushman narvon, taran va manjaniq bilan keladi" if not SiegeCastle.player_spec(p).is_empty() else
		"qal'angiz devor bilan o'ralmagan - ochiq maydonda jang qilasiz") if not mine else "bo'linmalarni joylab, buyruq berasiz"))
	_urgent(text, func(): War.open_battle.emit(army_id), func(): pass, "Boshqaraman (3D)", "Avto jang")


func _on_war_confirmed() -> void:
	if _pending.is_empty():
		return
	War.declare_war(_pending[0])
	War.execute(_pending[1], _pending[2], War.confirm_kind)
	_pending = []


# ---------------------------------------------------------------- mavzu

func _style(bg: Color, radius := 8, border := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	if border.a > 0:
		s.border_color = border
		s.set_border_width_all(1)
	return s


func _make_theme() -> Theme:
	if Game.era < 4:
		return _make_hist_theme()
	return _make_glass_theme()


func _hist_box(bg: Color, border: Color, radius := 4, bw := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	return s


func _make_hist_theme() -> Theme:
	## Tarixiy mavzu (1400 / 1865): yong'oq yog'och panellar, oltin (jez) hoshiya, lojuvard va oltin tugmalar,
	## Alegreya matn shrifti va Cinzel sarlavhalar
	var t := Theme.new()
	if ResourceLoader.exists("res://fonts/alegreya.woff2"):
		t.default_font = load("res://fonts/alegreya.woff2")
	t.default_font_size = 16
	var panel := _hist_box(UIKit.WOOD, UIKit.BRASS, 5, 2)
	panel.shadow_color = Color(0, 0, 0, 0.4)
	panel.shadow_size = 6
	panel.content_margin_left = 12
	panel.content_margin_right = 12
	panel.content_margin_top = 8
	panel.content_margin_bottom = 8
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("normal", "Button", _hist_box(UIKit.WOOD2, Color(0.55, 0.4, 0.2, 0.9)))
	t.set_stylebox("hover", "Button", _hist_box(Color(0.33, 0.23, 0.13, 0.98), Color(0.95, 0.76, 0.38)))
	t.set_stylebox("pressed", "Button", _hist_box(Color("#c9a03a"), Color("#f3dc9a")))
	t.set_stylebox("hover_pressed", "Button", _hist_box(Color("#d8b04a"), Color("#fff0b8")))
	t.set_stylebox("disabled", "Button", _hist_box(Color(0.12, 0.09, 0.06, 0.7), Color(0.35, 0.27, 0.16, 0.5)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Color("#f1e4c8"))
	t.set_color("font_hover_color", "Button", Color("#fff6dc"))
	t.set_color("font_pressed_color", "Button", Color("#24180c"))
	t.set_color("font_hover_pressed_color", "Button", Color("#24180c"))
	t.set_color("font_disabled_color", "Button", Color(0.95, 0.88, 0.75, 0.32))
	t.set_color("font_color", "Label", Color("#efe2c6"))
	t.set_constant("icon_max_width", "Button", 26)
	t.set_font_size("font_size", "Label", 15)
	t.set_font_size("font_size", "Button", 15)
	t.set_stylebox("background", "ProgressBar", _hist_box(Color(0, 0, 0, 0.35), Color(0.5, 0.38, 0.2, 0.6), 3, 1))
	t.set_stylebox("fill", "ProgressBar", _hist_box(Color("#b8462e"), Color(0, 0, 0, 0), 3, 0))
	t.set_stylebox("panel", "PopupPanel", panel)
	t.set_stylebox("panel", "AcceptDialog", panel)
	t.set_stylebox("panel", "TooltipPanel", _hist_box(Color(0.93, 0.86, 0.7, 0.97), Color(0.45, 0.32, 0.16), 3, 1))
	t.set_color("font_color", "TooltipLabel", Color("#2a1c0e"))
	t.set_stylebox("panel", "TabContainer", _style(Color(0, 0, 0, 0.0), 4))
	t.set_stylebox("tab_selected", "TabContainer", _hist_box(Color(0.36, 0.25, 0.13), UIKit.BRASS))
	t.set_stylebox("tab_unselected", "TabContainer", _hist_box(UIKit.WOOD2, Color(0.45, 0.33, 0.18, 0.7)))
	t.set_stylebox("tab_hovered", "TabContainer", _hist_box(Color(0.3, 0.21, 0.12), Color(0.9, 0.7, 0.35)))
	t.set_stylebox("slider", "HSlider", _hist_box(Color(0, 0, 0, 0.35), Color(0.5, 0.38, 0.2, 0.6), 3, 1))
	t.set_stylebox("grabber_area", "HSlider", _hist_box(Color("#c9a03a"), Color(0, 0, 0, 0), 3, 0))
	t.set_stylebox("grabber_area_highlight", "HSlider", _hist_box(Color("#e0b850"), Color(0, 0, 0, 0), 3, 0))
	var sep := StyleBoxLine.new()
	sep.color = Color(0.78, 0.6, 0.3, 0.45)
	sep.thickness = 2
	t.set_stylebox("separator", "HSeparator", sep)
	return t


func _make_glass_theme() -> Theme:
	## Glassmorphism mavzusi: shaffof to'q panellar, nozik yorug' chegaralar, yumshoq burchaklar
	var t := Theme.new()
	var panel := _style(Color(0.06, 0.09, 0.13, 0.55), 14, Color(0.6, 0.8, 1.0, 0.22))
	panel.shadow_color = Color(0, 0, 0, 0.25)
	panel.shadow_size = 6
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("normal", "Button", _style(Color(1, 1, 1, 0.07), 9, Color(1, 1, 1, 0.12)))
	t.set_stylebox("hover", "Button", _style(Color(0.35, 0.6, 1.0, 0.22), 9, Color(0.55, 0.8, 1.0, 0.55)))
	t.set_stylebox("pressed", "Button", _style(Color(0.91, 0.72, 0.23, 0.9), 9, Color(1, 0.9, 0.6, 0.8)))
	t.set_stylebox("hover_pressed", "Button", _style(Color(0.95, 0.76, 0.28, 0.95), 9, Color(1, 0.9, 0.6, 0.9)))
	t.set_stylebox("disabled", "Button", _style(Color(1, 1, 1, 0.03), 9, Color(1, 1, 1, 0.05)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Color("#e6edf5"))
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color("#1a1a1a"))
	t.set_color("font_hover_pressed_color", "Button", Color("#1a1a1a"))
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.3))
	t.set_constant("icon_max_width", "Button", 26)
	t.set_font_size("font_size", "Label", 15)
	t.set_font_size("font_size", "Button", 15)
	t.set_stylebox("background", "ProgressBar", _style(Color(1, 1, 1, 0.08), 6))
	t.set_stylebox("fill", "ProgressBar", _style(Color("#e07a5f"), 6))
	t.set_stylebox("panel", "PopupPanel", panel)
	t.set_stylebox("panel", "AcceptDialog", panel)
	t.set_stylebox("panel", "TabContainer", _style(Color(0, 0, 0, 0.0), 10))
	t.set_stylebox("tab_selected", "TabContainer", _style(Color(0.35, 0.6, 1.0, 0.3), 8, Color(0.55, 0.8, 1.0, 0.5)))
	t.set_stylebox("tab_unselected", "TabContainer", _style(Color(1, 1, 1, 0.05), 8))
	t.set_stylebox("tab_hovered", "TabContainer", _style(Color(1, 1, 1, 0.12), 8))
	var grab := _style(Color("#ffd166"), 8)
	t.set_stylebox("slider", "HSlider", _style(Color(1, 1, 1, 0.12), 4))
	t.set_stylebox("grabber_area", "HSlider", _style(Color(0.35, 0.6, 1.0, 0.6), 4))
	t.set_stylebox("grabber_area_highlight", "HSlider", _style(Color(0.45, 0.7, 1.0, 0.8), 4))
	return t


func _label(text: String, size := 15, color := COL_INFO) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _wrap(n: Node) -> void:
	if n is Button:
		n.clip_text = true
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if n is Label:
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _icon(path: String, px := 24) -> TextureRect:
	var r := TextureRect.new()
	r.texture = load(path)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(px, px)
	return r


# ---------------------------------------------------------------- yuqori panel

func _pick_flag() -> void:
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Rasmlar"])
	fd.title = "Bayroq rasmini tanlang"
	fd.use_native_dialog = true
	fd.file_selected.connect(func(path: String):
		var err := Unit3D.set_flag_image(path)
		if err != "":
			Game.message.emit(err, "bad")
		else:
			Game.message.emit("Yangi bayroq o'rnatildi! U qo'shinlaringiz, qal'angiz va qo'mondoningiz bayrog'ida ko'rinadi.", "good")
			Game.changed.emit()
		fd.queue_free())
	fd.canceled.connect(fd.queue_free)
	add_child(fd)
	fd.popup_centered_ratio(0.6)


func _old_panel(id: String, p: Dictionary) -> void:
	## 1-2-zamon: viloyat paneli - qal'a, qo'shin, xo'jalik (zamonaviy zavod/tank bo'limlarisiz)
	side_box.add_child(HSeparator.new())
	var unrest: float = p["unrest"]
	side_box.add_child(_label("Norozilik: %d%%" % int(unrest), 15, COL_BAD if unrest >= 70 else (COL_EVENT if unrest >= 40 else COL_GOOD)))
	var c := CastleEco.castle(p)
	var g := CastleEco.gold(p)
	side_box.add_child(HSeparator.new())
	side_box.add_child(_label("Qal'a", 17, Color.WHITE))
	var st: Dictionary = c.get("stats", {})
	side_box.add_child(_label(("Devor bilan o'ralgan - dushman hujumida qamal jangi bo'ladi." if st.get("closed", false) else "Devor bilan o'ralmagan - dushman bilan ochiq maydonda jang qilasiz.") , 13, COL_GOOD if st.get("closed", false) else COL_EVENT))
	side_box.add_child(_label("Xo'jalikdan: +%d oltin/kun   Qo'shin maoshi: -%d oltin/kun" % [int(g["prod"]), int(g["pay"])], 13))
	side_box.add_child(_label("Qo'shin", 17, Color.WHITE))
	for k in CastleEco.units():
		side_box.add_child(_label("   %s: %d" % [CastleEco.units()[k]["name"], int(c["army"].get(k, 0))], 14))
	side_box.add_child(_label("Josuslar: %d   |   Mahalliy mudofaa: %d" % [Game.spies, roundi(p["militia"])], 13, COL_DIM))
	side_box.add_child(_label("Qurish, askar yollash va josuslar - QAL'A (3D) oynasida.", 13, COL_DIM))
	if War.garrison_power(p) >= 1.0:
		var go := Button.new()
		go.text = "Qo'shinni yuborish (hujum / ko'chirish)"
		go.alignment = HORIZONTAL_ALIGNMENT_LEFT
		go.custom_minimum_size = Vector2(0, 40)
		go.pressed.connect(War.begin_target.bind(id))
		side_box.add_child(go)
	_armies_here(id)


func _build_top_bar(root: Control) -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 8
	bar.offset_right = -8
	bar.offset_top = 8
	root.add_child(bar)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	bar.add_child(h)

	h.add_child(_icon("res://icons/coin.svg", 26))
	money_label = _label("", 18, Color("#ffd166"))
	h.add_child(money_label)
	income_label = _label("", 14, COL_GOOD)
	h.add_child(income_label)
	h.add_child(VSeparator.new())
	h.add_child(_icon("res://icons/soldier.svg", 24))
	army_label = _label("", 15)
	h.add_child(army_label)
	if Game.era < 4:
		var fl := Button.new()
		fl.text = "Bayroq"
		fl.tooltip_text = "O'z bayrog'ingiz rasmini yuklang (PNG/JPG). U qo'shin bayroqdorlarida, qal'a ustida va qo'mondon yonida hilpillaydi."
		fl.pressed.connect(_pick_flag)
		h.add_child(fl)
	var dip := Button.new()
	dip.text = "Diplomatiya"
	dip.pressed.connect(func(): diplo_win.toggle())
	h.add_child(dip)
	var tb := Button.new()
	tb.text = "Tadqiqot"
	tb.visible = Game.era >= 4
	tb.pressed.connect(func(): tech_win.toggle())
	h.add_child(tb)
	var pb := Button.new()
	pb.text = "Siyosat"
	pb.visible = Game.era >= 4
	pb.pressed.connect(func(): pol_win.toggle())
	h.add_child(pb)
	var bb := Button.new()
	bb.text = "Byudjet"
	bb.visible = Game.era >= 4
	bb.pressed.connect(func(): budget_win.toggle())
	h.add_child(bb)
	inbox_btn = Button.new()
	inbox_btn.text = "Xabarlar"
	inbox_btn.pressed.connect(func(): inbox_win.toggle())
	h.add_child(inbox_btn)

	war_label = _label("", 14, COL_BAD)
	war_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	war_label.clip_text = true
	war_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	war_label.custom_minimum_size = Vector2(40, 0)
	h.add_child(war_label)

	date_label = _label("", 15)
	h.add_child(date_label)
	var group := ButtonGroup.new()
	for s in [0, 1, 2, 5]:
		var b := Button.new()
		b.text = "||" if s == 0 else "%dx" % s
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(38, 0)
		b.pressed.connect(Game.set_speed.bind(s))
		h.add_child(b)
		speed_buttons[s] = b
	h.add_child(VSeparator.new())
	var menu := MenuButton.new()
	menu.text = "Menyu"
	menu.flat = false
	menu.get_popup().add_item("Saqlash", 0)
	menu.get_popup().add_item("Yuklash", 1)
	menu.get_popup().id_pressed.connect(func(mid): Game.save_game() if mid == 0 else Game.load_game())
	h.add_child(menu)
	# yuqori panel sig'ishi uchun tugmalar ixchamroq
	for ch in h.get_children():
		if ch is Button:
			ch.add_theme_font_size_override("font_size", 13)
		if ch is VSeparator:
			ch.visible = false
	h.add_theme_constant_override("separation", 5)


# ---------------------------------------------------------------- yon panel

func _build_side_panel(root: Control) -> void:
	side_panel = PanelContainer.new()
	side_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	side_panel.offset_left = -350
	side_panel.offset_right = -8
	side_panel.offset_top = 64
	side_panel.offset_bottom = -8
	root.add_child(side_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_panel.add_child(scroll)
	side_box = VBoxContainer.new()
	side_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_box.add_theme_constant_override("separation", 6)
	scroll.add_child(side_box)
	side_box.child_entered_tree.connect(_wrap)
	side_panel.visible = false


func _rebuild_panel() -> void:
	for c in side_box.get_children():
		c.queue_free()
	var id := Game.selected_id
	side_panel.visible = id != ""
	if id == "":
		return
	var p: Dictionary = Game.provinces[id]
	var mine: bool = p["owner"] == Game.PLAYER

	side_box.add_child(_label(p["name"], 24, Color.WHITE))
	var owner_text: String
	match p["owner"]:
		Game.PLAYER: owner_text = "Sizning provinsiyangiz"
		Game.REBEL: owner_text = "Isyonchilar nazoratida"
		_: owner_text = Game.countries[p["owner"]]["name"]
	side_box.add_child(_label(owner_text, 15, Color("#e8b73a") if mine else COL_DIM))
	side_box.add_child(HSeparator.new())
	if mine and Game.started:
		var b3 := Button.new()
		b3.text = "QAL'A (3D)" if Game.era < 4 else "VILOYAT BAZASI (3D)"
		b3.icon = load("res://icons/politic.svg")
		b3.expand_icon = false
		b3.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b3.custom_minimum_size = Vector2(0, 44)
		b3.add_theme_color_override("font_color", Color("#ffd166"))
		b3.pressed.connect(func(): Game.open_province.emit(id))
		side_box.add_child(b3)
	if mine and Game.started and War.garrison_power(p) >= 1.0:
		var go_top := Button.new()
		go_top.text = ("Qo'shinni yuborish  (kuch %d)" % roundi(War.garrison_power(p))) if Game.era >= 4 else ("Qo'shinni yurishga chiqarish  (%d askar)" % roundi(p["units"].get("soldier", 0.0)))
		go_top.icon = _army_icon()
		go_top.alignment = HORIZONTAL_ALIGNMENT_LEFT
		go_top.custom_minimum_size = Vector2(0, 40)
		go_top.pressed.connect(War.begin_target.bind(id))
		side_box.add_child(go_top)

	var pop: int = p["population"]
	var pop_text := ("%.1f mln" % (pop / 1000.0)) if pop >= 1000 else ("%d ming" % pop)
	side_box.add_child(_label("Aholi: " + pop_text))
	var res_parts: Array = []
	for r in p["resources"]:
		var price := Game.resource_price(r)
		var mark := ""
		if Game.price_mult.has(r):
			mark = " ^" if Game.price_mult[r]["mult"] > 1.0 else " v"
		if Game.era < 4:
			res_parts.append("%s %d" % [Game.RESOURCE_NAMES.get(r, r), p["resources"][r]])
		else:
			res_parts.append("%s %d (%.0f$%s)" % [Game.RESOURCE_NAMES.get(r, r), p["resources"][r], price, mark])
	side_box.add_child(_label("Resurslar: " + ", ".join(res_parts)))

	if not Game.started:
		side_box.add_child(HSeparator.new())
		side_box.add_child(_label("Shu viloyatdan boshlaysizmi? Boshlang'ich xazina: %d %s" % [int(Game.START_MONEY), "oltin" if Game.era < 4 else "$"], 14, COL_DIM))
		var b := Button.new()
		b.text = "Shu yerdan boshlash"
		b.custom_minimum_size = Vector2(0, 44)
		b.pressed.connect(func(): Game.start_game(id); _rebuild_panel())
		side_box.add_child(b)
		return

	if not mine:
		_foreign_panel(id, p)
		return
	if Game.era < 4:
		_old_panel(id, p)
		return

	# --- norozilik
	side_box.add_child(HSeparator.new())
	var unrest: float = p["unrest"]
	side_box.add_child(_label("Norozilik: %d%%" % int(unrest), 15,
		COL_BAD if unrest >= 70 else (COL_EVENT if unrest >= 40 else COL_GOOD)))
	var bar := ProgressBar.new()
	bar.value = unrest
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	side_box.add_child(bar)
	side_box.add_child(_label("Ish o'rinlari: %d / %d kerak" % [Game.jobs(p), Game.jobs_needed(p)], 13, COL_DIM))

	# --- daromad
	var inc := Game.province_income(p)
	side_box.add_child(HSeparator.new())
	side_box.add_child(_label("Kunlik byudjet", 17, Color.WHITE))
	side_box.add_child(_label("Soliq: +%.0f   Sanoat: +%.0f   Resurs: +%.0f" % [inc["tax"], inc["industry"], inc["resources"]], 13))
	side_box.add_child(_label("Xarajat (qo'shin, zavod): -%.0f" % inc["upkeep"], 13, COL_BAD))
	side_box.add_child(_label("Jami: %+.0f $/kun" % inc["total"], 15, COL_GOOD if inc["total"] >= 0 else COL_BAD))

	# --- binolar
	side_box.add_child(HSeparator.new())
	side_box.add_child(_label("Binolar (%d/%d)" % [p["buildings"].size(), Game.MAX_BUILDINGS], 17, Color.WHITE))
	if p["buildings"].is_empty():
		side_box.add_child(_label("Hali hech narsa qurilmagan.", 13, COL_DIM))
	for bl in p["buildings"]:
		var row := HBoxContainer.new()
		row.add_child(_icon(Game.BUILDINGS[bl["type"]]["icon"], 26))
		var txt: String = Game.BUILDINGS[bl["type"]]["name"]
		if bl["days_left"] > 0:
			txt += "  (qurilmoqda: %d kun)" % bl["days_left"]
		var rl := _label(txt, 14, COL_DIM if bl["days_left"] > 0 else COL_INFO)
		_wrap(rl)
		row.add_child(rl)
		side_box.add_child(row)

	side_box.add_child(_label("Qurish:", 15, Color.WHITE))
	for t in Game.BUILDINGS:
		var def: Dictionary = Game.BUILDINGS[t]
		var b := Button.new()
		b.text = "%s  -  %d $, %d kun" % [def["name"], def["cost"], def["days"]]
		b.icon = load(def["icon"])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.tooltip_text = def["desc"]
		var why := Game.can_build(id, t)
		b.disabled = why != ""
		if why != "":
			b.tooltip_text += "\n" + why
		b.pressed.connect(Game.build.bind(id, t))
		side_box.add_child(b)

	# --- harbiy
	side_box.add_child(HSeparator.new())
	side_box.add_child(_label("Garnizon: %d askar, %d tank  (kuch %d)" % [roundi(p["units"]["soldier"]), roundi(p["units"]["tank"]), roundi(War.garrison_power(p))], 15, Color.WHITE))
	side_box.add_child(_label("Mahalliy mudofaa: %d" % roundi(p["militia"]), 13, COL_DIM))
	if War.garrison_power(p) >= 1.0:
		var go := Button.new()
		go.text = "Qo'shinni yuborish (hujum / ko'chirish)"
		go.icon = _army_icon()
		go.alignment = HORIZONTAL_ALIGNMENT_LEFT
		go.custom_minimum_size = Vector2(0, 40)
		go.pressed.connect(War.begin_target.bind(id))
		side_box.add_child(go)
	_armies_here(id)
	side_box.add_child(_label("Buyurtma (zavod/aerodromga):", 14))
	for u in Game.UNITS:
		var def: Dictionary = Game.UNITS[u]
		var tq: String = def.get("tech", "")
		if tq != "" and not Tech.has(tq):
			continue
		var b := Button.new()
		b.text = "%d ta %s  -  %d $, %d kun" % [def["batch"], def["name"].to_lower(), def["cost"], def["days"]]
		b.icon = load(def["icon"])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var why := Game.can_order(id, u)
		b.disabled = why != ""
		b.tooltip_text = why
		b.pressed.connect(Game.order_unit.bind(id, u))
		side_box.add_child(b)
		if why != "" and why != "Pul yetmaydi":
			side_box.add_child(_label("   " + why, 12, COL_DIM))
	for i in p["orders"].size():
		var o: Dictionary = p["orders"][i]
		var def2: Dictionary = Game.UNITS[o["unit"]]
		var state := "ishlanmoqda" if Game.order_active(p, i) else "navbatda"
		side_box.add_child(_label("- %d %s: %d kun (%s)" % [def2["batch"] * int(o.get("count", 1)), def2["name"].to_lower(), o["days_left"], state], 13, COL_DIM))
	_posts_section(id, p)
	_air_section(id, p)


func _posts_section(id: String, p: Dictionary) -> void:
	var foreign: Array = []
	for n in p["neighbors"]:
		if Game.provinces[n]["owner"] != Game.PLAYER:
			foreign.append(n)
	if foreign.is_empty():
		return
	side_box.add_child(HSeparator.new())
	side_box.add_child(_label("Chegara postlari", 17, Color.WHITE))
	side_box.add_child(_label("Post: mahalliy mudofaa +6, dushman hujumi 25%% zaif, dushman to'planishini oldinroq sezadi. %d $, %d kun." % [Game.POST_COST, Game.POST_DAYS], 12, COL_DIM))
	for n in foreign:
		var q: Dictionary = Game.provinces[n]
		var who: String = War.country_name(q["owner"])
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		var state := ""
		for po in p.get("posts", []):
			if po["to"] == n:
				state = "bor" if po["days_left"] <= 0 else "%d kun" % po["days_left"]
		if state != "":
			b.text = "%s (%s) - post %s" % [q["name"], who, state]
			b.disabled = true
		else:
			b.text = "%s (%s) - post qurish" % [q["name"], who]
			var why := Game.can_post(id, n)
			b.disabled = why != ""
			b.tooltip_text = why
			b.pressed.connect(Game.build_post.bind(id, n))
		side_box.add_child(b)
		var ob := Button.new()
		ob.text = "   Chegarani ochish: qo'shin, rejim, hujum"
		ob.alignment = HORIZONTAL_ALIGNMENT_LEFT
		ob.add_theme_font_size_override("font_size", 12)
		ob.pressed.connect(func(): Game.open_border.emit(id, n))
		side_box.add_child(ob)


func _air_section(id: String, p: Dictionary) -> void:
	var pl := roundi(Game.units_of(p, "plane"))
	var mi := roundi(Game.units_of(p, "missile"))
	var nu := roundi(Game.units_of(p, "nuke"))
	if pl + mi + nu == 0:
		return
	side_box.add_child(HSeparator.new())
	side_box.add_child(_label("Havo kuchlari: %d samolyot, %d raketa, %d yadro" % [pl, mi, nu], 15, Color.WHITE))
	if pl > 0:
		var b := Button.new()
		b.text = "Bombardimon (%d samolyot, radius %d)" % [pl, int(Tech.PLANE_RANGE)]
		b.icon = load("res://icons/plane.svg")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(War.begin_target.bind(id, "plane"))
		side_box.add_child(b)
	if mi > 0:
		var b2 := Button.new()
		b2.text = "Raketa uchirish (radius %d)" % int(Tech.MISSILE_RANGE)
		b2.icon = load("res://icons/missile.svg")
		b2.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b2.pressed.connect(War.begin_target.bind(id, "missile"))
		side_box.add_child(b2)
	if nu > 0:
		var b3 := Button.new()
		b3.text = "YADRO RAKETASI"
		b3.icon = load("res://icons/nuke.svg")
		b3.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b3.pressed.connect(War.begin_target.bind(id, "nuke"))
		side_box.add_child(b3)


func _foreign_panel(id: String, p: Dictionary) -> void:
	side_box.add_child(HSeparator.new())
	var owner: String = p["owner"]
	if owner != Game.REBEL:
		var r: float = Diplo.rel[owner]
		side_box.add_child(_label("Munosabat: %+d (%s)" % [roundi(r), Diplo.rel_text(owner)], 15, COL_GOOD if r >= 25 else (COL_BAD if r < -10 or War.wars.has(owner) else COL_INFO)))
		var db := Button.new()
		db.text = "Diplomatiya: %s" % War.country_name(owner)
		db.pressed.connect(func(): Diplo.open_window.emit(owner))
		side_box.add_child(db)
	side_box.add_child(_label("Mudofaa kuchi: %d / %d" % [roundi(p["defense"]), roundi(p["max_defense"])], 15, Color.WHITE))
	var bar := ProgressBar.new()
	bar.value = 100.0 * p["defense"] / maxf(1.0, p["max_defense"])
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	side_box.add_child(bar)
	# eng kuchli qo'shni garnizondan hujum
	var src := ""
	var best := 0.0
	for n in p["neighbors"]:
		var q: Dictionary = Game.provinces[n]
		if q["owner"] == Game.PLAYER and War.garrison_power(q) > best:
			best = War.garrison_power(q)
			src = n
	if src != "":
		var atk := Button.new()
		atk.text = ("HUJUM  (%s dan, kuch %d)" % [Game.provinces[src]["name"], roundi(best)]) if Game.era >= 4 else ("Yurish: %s qo'shini bilan bosib olish  (%d askar)" % [Game.provinces[src]["name"], roundi(Game.provinces[src]["units"].get("soldier", 0.0))])
		atk.icon = _army_icon()
		atk.alignment = HORIZONTAL_ALIGNMENT_LEFT
		atk.custom_minimum_size = Vector2(0, 44)
		atk.pressed.connect(func(): War.begin_target(src); War.choose_target(id))
		side_box.add_child(atk)
	else:
		side_box.add_child(_label("Hujum uchun qo'shni provinsiyangizda qo'shin bo'lishi kerak.", 13, COL_DIM))
	if owner == Game.REBEL:
		side_box.add_child(_label("Isyonchilarga urush e'lon qilish shart emas - qo'shni provinsiyadan qo'shin yuboring.", 13, COL_DIM))
	elif War.wars.has(owner):
		var days: int = Game.day - War.wars[owner]["start"]
		side_box.add_child(_label("%s bilan URUSH holatidasiz (%d kun)." % [War.country_name(owner), days], 15, COL_BAD))
		var peace := Button.new()
		peace.text = "Sulh taklif qilish"
		peace.pressed.connect(War.make_peace.bind(owner))
		side_box.add_child(peace)
	else:
		side_box.add_child(_label("%s bilan tinchlik. Hujum qilsangiz, urush e'lon qilinadi." % War.country_name(owner), 13, COL_DIM))
	_armies_here(id)


func _armies_here(id: String) -> void:
	var list := War.armies_in(id)
	if list.is_empty():
		return
	side_box.add_child(HSeparator.new())
	side_box.add_child(_label("Bu yerda jang ketmoqda!", 16, COL_EVENT))
	for a in list:
		var mine: bool = a["owner"] == Game.PLAYER
		var who: String = "Sizning qo'shiningiz" if mine else War.country_name(a["owner"]) + " qo'shini"
		var txt := ("%s: %d askar, %d tank (kuch %d)" % [who, roundi(a["soldiers"]), roundi(a["tanks"]), roundi(War.power(a))]) if Game.era >= 4 else ("%s: %d askar" % [who, roundi(a["soldiers"])])
		if mine:
			txt += "\nZaxira: %d%%" % roundi(a["supply"])
		side_box.add_child(_label(txt, 14, COL_GOOD if mine else COL_BAD))
		var fb := Button.new()
		fb.text = "JANGNI BOSHQARISH (3D)"
		fb.icon = _army_icon()
		fb.custom_minimum_size = Vector2(0, 42)
		fb.pressed.connect(func(): War.open_battle.emit(a["id"]))
		side_box.add_child(fb)
		if mine:
			var r := Button.new()
			r.text = "Chekinish"
			r.pressed.connect(War.retreat.bind(a["id"]))
			side_box.add_child(r)


# ---------------------------------------------------------------- xabarlar

func _build_log(root: Control) -> void:
	log_box = VBoxContainer.new()
	log_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	log_box.offset_left = 12
	log_box.offset_bottom = -12
	log_box.offset_top = -200
	log_box.offset_right = 560
	log_box.alignment = BoxContainer.ALIGNMENT_END
	log_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(log_box)


func _army_icon() -> Texture2D:
	## qadimiy davrda tank o'rniga kesishgan qilichlar
	return load("res://icons/tank.svg") if Game.era >= 4 else load("res://icons/qilich.svg")


func _on_message(text: String, kind: String) -> void:
	if Game.era < 4:
		text = text.replace(" $", " oltin").replace("$", " oltin").replace("Byudjet", "Xazina").replace("byudjet", "xazina")
	var col := COL_INFO
	match kind:
		"good": col = COL_GOOD
		"bad": col = COL_BAD
		"event": col = COL_EVENT
	var l := _label(text, 14, col)
	_wrap(l)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_box.add_child(l)
	while log_box.get_child_count() > 6:
		var old := log_box.get_child(0)
		log_box.remove_child(old)
		old.queue_free()
	var tw := l.create_tween()
	tw.tween_interval(15.0)
	tw.tween_property(l, "modulate:a", 0.0, 2.0)
	tw.tween_callback(l.queue_free)


func _build_hint(root: Control) -> void:
	hint = PanelContainer.new()
	hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hint.offset_top = 70
	hint.offset_left = -260
	hint.offset_right = 260
	hint_label = _label("", 16, Color.WHITE)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_child(hint_label)
	root.add_child(hint)


# ---------------------------------------------------------------- yangilash

func _refresh() -> void:
	money_label.text = "%s $" % _fmt(int(Game.money)) if Game.era >= 4 else "%s oltin   Oziq %d   Yog'och %d   Tosh %d" % [
		_fmt(int(Game.money)), int(Game.goods.get("oziq", 0)), int(Game.goods.get("yogoch", 0)), int(Game.goods.get("tosh", 0))]
	money_label.add_theme_color_override("font_color", COL_BAD if Game.money < 0 else Color("#ffd166"))
	var inc := Game.total_income()
	income_label.text = "(%+.0f/kun)" % inc
	income_label.add_theme_color_override("font_color", COL_GOOD if inc >= 0 else COL_BAD)
	var u := War.player_unit_totals()
	army_label.text = "%d askar  |  %d tank" % [roundi(u["soldier"]), roundi(u["tank"])] if Game.era >= 4 else "%d askar" % roundi(u["soldier"])
	var n := Diplo.inbox.size()
	inbox_btn.text = "Xabarlar (%d)" % n if n > 0 else "Xabarlar"
	inbox_btn.add_theme_color_override("font_color", Color("#ffd166") if n > 0 else Color.WHITE)
	var wl: Array = []
	for c in War.wars:
		var wn: String = War.country_name(c)
		if wn.strip_edges() != "":
			wl.append(wn)
	war_label.text = ("Urush: " + ", ".join(wl)) if not wl.is_empty() else ""
	if Diplo.sanctioned():
		war_label.text += ("   " if war_label.text != "" else "") + "SANKSIYA (%d kun)" % Diplo.sanction_days
	date_label.text = Game.date_text() if Game.started else "O'yin boshlanmagan"
	if speed_buttons.has(Game.speed):
		speed_buttons[Game.speed].button_pressed = true
	if War.target_from != "":
		var what := {"army": "Qo'shin qayerga borsin?", "plane": "Samolyotlar qaysi provinsiyani bombardimon qilsin?",
			"missile": "Raketa qayerga uchirilsin?", "nuke": "YADRO raketasi nishonini tanlang!"}
		hint_label.text = what.get(War.target_kind, "") + " Xaritadan nishonni bosing\n(o'ng tugma yoki Esc - bekor qilish)"
		hint.visible = true
	elif not Game.started:
		hint_label.text = "Xaritadan boshlang'ich provinsiyangizni tanlang\n(sichqoncha g'ildiragi - yaqinlashtirish, sudrash - surish)"
		hint.visible = true
	else:
		hint.visible = false
	if Game.selected_id != "":
		_rebuild_panel()


func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


func _unhandled_key_input(e: InputEvent) -> void:
	if War.battle_open:
		return
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_SPACE:
		Game.set_speed(1 if Game.speed == 0 else 0)
	elif e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		War.cancel_target()
