class_name UIKit
## Oynalar uchun umumiy chiroyli elementlar: bayroq, karta, ko'rsatkich, rasm.

const GOOD := Color("#7bd88f")
const BAD := Color("#ff6b6b")
const GOLD := Color("#ffd166")
const INFO := Color("#cfd8e3")
const DIM := Color("#8a97a8")
const CARD := Color(0.10, 0.14, 0.19, 0.55)
const CARD2 := Color(1, 1, 1, 0.06)
const ACCENT := Color(0.24, 0.47, 0.75, 0.85)


static func flag(code: String, w := 60.0) -> TextureRect:
	var t := TextureRect.new()
	var path := "res://icons/flags/%s.svg" % code
	var pp: Array = Game.player_provinces() if Game.started else []
	if not pp.is_empty() and Game.provinces[pp[0]]["country"] == code and Unit3D.flag_tex() != null:
		t.texture = Unit3D.flag_tex()        # o'yinchi yuklagan bayroq
	elif ResourceLoader.exists(path):
		t.texture = load(path)
	elif Game.countries.has(code):
		# tarixiy davlatlar uchun: davlat rangidagi oddiy bayroq
		var img := Image.create(6, 4, false, Image.FORMAT_RGBA8)
		var col := Color(Game.countries[code]["color"])
		img.fill(col)
		for x in 6:
			img.set_pixel(x, 0, col.darkened(0.35))
			img.set_pixel(x, 3, col.darkened(0.35))
		t.texture = ImageTexture.create_from_image(img)
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.custom_minimum_size = Vector2(w, w * 2.0 / 3.0)
	return t


static func pic(path: String, size: Vector2) -> TextureRect:
	var t := TextureRect.new()
	if ResourceLoader.exists(path):
		t.texture = load(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = size
	return t


static func weapon_pic(w: String, size := Vector2(150, 94)) -> TextureRect:
	return pic("res://pics/weapons/%s.png" % w, size)


static func label(text: String, size := 15, color := INFO, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func style(bg: Color, radius := 10, border := Color(0, 0, 0, 0), pad := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if border.a > 0.0:
		s.set_border_width_all(2)
		s.border_color = border
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.7
	s.content_margin_bottom = pad * 0.7
	return s


static func card(parent: Control, bg := CARD, border := Color(0, 0, 0, 0)) -> VBoxContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", style(bg, 10, border))
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	pc.add_child(v)
	return v


static func row(parent: Control, sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	parent.add_child(h)
	return h


static func grid(parent: Control, cols: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	parent.add_child(g)
	return g


static func stat(parent: Control, name: String, v: float, maxv: float, col: Color, txt := "") -> void:
	var h := row(parent)
	var l := label(name, 13, DIM)
	l.custom_minimum_size = Vector2(110, 0)
	h.add_child(l)
	var pb := ProgressBar.new()
	pb.min_value = 0
	pb.max_value = maxv
	pb.value = clampf(v, 0, maxv)
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(160, 12)
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var f := StyleBoxFlat.new()
	f.bg_color = col
	f.set_corner_radius_all(4)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.08)
	bg.set_corner_radius_all(4)
	pb.add_theme_stylebox_override("fill", f)
	pb.add_theme_stylebox_override("background", bg)
	h.add_child(pb)
	h.add_child(label(txt if txt != "" else str(int(v)), 13, INFO))


static func button(parent: Control, text: String, why: String, cb: Callable, accent := false) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = why != ""
	b.tooltip_text = why
	if accent:
		b.add_theme_stylebox_override("normal", style(ACCENT, 8, Color(0, 0, 0, 0), 8))
		b.add_theme_stylebox_override("hover", style(Color(0.35, 0.6, 1.0, 0.95), 8, Color(0.7, 0.85, 1.0, 0.7), 8))
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


static func rel_color(r: float) -> Color:
	if r >= 20: return GOOD
	if r >= -20: return INFO
	return BAD


static func window(node: PanelContainer, title: String, icon: String, w: float, h: float) -> VBoxContainer:
	## Markazdagi oyna: sarlavha + yopish tugmasi. Ichki VBox qaytaradi.
	node.set_anchors_preset(Control.PRESET_CENTER)
	node.custom_minimum_size = Vector2(w, h)
	node.offset_left = -w / 2
	node.offset_right = w / 2
	node.offset_top = -h / 2
	node.offset_bottom = h / 2
	node.add_theme_stylebox_override("panel", style(Color(0.05, 0.08, 0.12, 0.6), 16, Color(0.6, 0.8, 1.0, 0.25), 14))
	node.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	node.add_child(v)
	var head := row(v)
	if icon != "":
		head.add_child(pic(icon, Vector2(30, 30)))
	var t := label(title, 22, Color.WHITE)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := Button.new()
	close.text = "  X  "
	close.pressed.connect(func(): node.visible = false)
	head.add_child(close)
	return v


static func scroll(parent: Control) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	sc.add_child(v)
	return v


static func clear(n: Node) -> void:
	for c in n.get_children():
		c.queue_free()
