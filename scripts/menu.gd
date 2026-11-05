extends Control
## Bosh menyu: zamon tanlash (1400 / 1865), tarixiy sujetlar, saqlangan o'yin

var info: VBoxContainer
var stories_box: VBoxContainer
var sel_era := 1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var ui = preload("res://scripts/ui.gd").new()
	theme = ui._make_theme()
	ui.free()
	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists("res://pics/menu_bg.jpg"):
		bg.texture = load("res://pics/menu_bg.jpg")
	add_child(bg)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.03, 0.05, 0.08, 0.45)
	add_child(shade)

	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 48
	root.offset_top = 40
	root.offset_right = -48
	root.offset_bottom = -40
	root.add_theme_constant_override("separation", 28)
	add_child(root)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(380, 0)
	left.add_theme_constant_override("separation", 10)
	root.add_child(left)
	var t := UIKit.label("GLOBAL STRATEGIYA", 40, Color("#ffd166"))
	t.add_theme_constant_override("outline_size", 8)
	t.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	left.add_child(t)
	left.add_child(UIKit.label("Qal'a qur, qo'shin to'pla, dunyoni zabt et", 16, Color.WHITE))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 18)
	left.add_child(sp)
	_big(left, "1-ZAMON  -  Amir Temur davri (1400)", func(): _show_era(1))
	_big(left, "2-ZAMON  -  Xonliklar davri (1865)", func(): _show_era(2))
	_big(left, "TARIXIY SUJETLAR", _show_stories)
	var lb := _big(left, "Saqlangan o'yinni davom ettirish", _continue)
	lb.disabled = not Game.has_save()
	_big(left, "Chiqish", func(): get_tree().quit())

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(panel)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(sc)
	info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 10)
	sc.add_child(info)
	_show_era(1)


func _big(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 54)
	b.add_theme_font_size_override("font_size", 18)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _show_era(n: int) -> void:
	sel_era = n
	UIKit.clear(info)
	var d: Dictionary = ERA_INFO[n]
	info.add_child(UIKit.label(d["title"], 28, Color.WHITE))
	info.add_child(UIKit.label(d["sub"], 15, Color("#ffd166"), true))
	for line in d["lines"]:
		info.add_child(UIKit.label("•  " + line, 15, Color("#d8e2ec"), true))
	info.add_child(UIKit.label("Xalqlar: " + d["nations"], 14, Color("#9fb3c8"), true))
	var b := UIKit.button(info, "BOSHLASH  -  xaritadan viloyatingizni tanlang", "", func(): _start(n, ""), true)
	b.custom_minimum_size = Vector2(0, 50)


func _show_stories() -> void:
	UIKit.clear(info)
	info.add_child(UIKit.label("Tarixiy sujetlar", 28, Color.WHITE))
	info.add_child(UIKit.label("Haqiqiy tarixiy voqealar: tayyor boshlang'ich holat, aniq maqsad va g'alaba sharti.", 15, Color("#ffd166"), true))
	for id in Story.LIST:
		var s: Dictionary = Story.LIST[id]
		var c := UIKit.card(info)
		c.add_child(UIKit.label("%s  (%s)" % [s["title"], s["year"]], 20, Color.WHITE))
		c.add_child(UIKit.label(s["short"], 14, Color("#d8e2ec"), true))
		c.add_child(UIKit.label("Maqsad: " + s["goal_text"], 13, Color("#9fe0a8"), true))
		UIKit.button(c, "Boshlash", "", func(): _start(int(s["era"]), id), true)


func _start(era: int, story: String) -> void:
	Game.set_era(era)
	Game.story = story
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _continue() -> void:
	var f := FileAccess.open(Game.SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		Game.set_era(int(data.get("era", 1)))
	Game.pending_load = true
	get_tree().change_scene_to_file("res://scenes/main.tscn")


const ERA_INFO := {
	1: {"title": "1-zamon: Amir Temur davri", "sub": "Yil 1400. Temuriylar, Oltin O'rda, Usmonlilar, Min imperiyasi, Yevropa qirolliklari.",
		"lines": ["Butun dunyo: 71 davlat, 336 viloyat - globusdan tekis xaritagacha.",
			"Bitta strategik qal'a qurasiz: devor, minora, darvoza, xandaq.",
			"Xo'jalik: bug'doy, o'tin, tosh, bozor, zarbxona.",
			"Qo'shin: qilichboz, nayzachi, kamonchi, otliq.",
			"3D jang: tepadan boshqarish yoki qo'mondon bo'lib otda jang qilish.",
			"Qamal: narvon, arqon, taran, manjaniq. Dushman ham qal'angizga hujum qiladi.",
			"Diplomatiya: ittifoq, karvon savdosi, yordam so'rash, o'lpon.",
			"Josuslar va o'z bayrog'ingiz."],
		"nations": "temuriy, arab, yunon-rim, yevropa ritsarlari, rus drujinasi, xitoy"},
	2: {"title": "2-zamon: Xonliklar davri", "sub": "Yil 1865. Buxoro amirligi, Xiva va Qo'qon xonliklari; Rossiya imperiyasi janubga yurmoqda.",
		"lines": ["44 davlat, 339 viloyat: O'rta Osiyo, Eron, Afg'oniston, Usmonlilar, Tsin, Britaniya Hindistoni, Yevropa.",
			"Qo'shin: sarboz (fitilli miltiq), nayzachi, otliq va to'p.",
			"Miltiqchilar nishonga olib otadi, porox va shompol bilan qayta o'qlaydi.",
			"To'plar dushman safiga va qal'a devoriga o'q uzadi.",
			"Qal'a, xo'jalik, diplomatiya va josuslar 1-zamondagidek."],
		"nations": "o'zbek sarbozlari, rus askarlari, ingliz, yevropa, usmonli-eron, tsin"},
}
