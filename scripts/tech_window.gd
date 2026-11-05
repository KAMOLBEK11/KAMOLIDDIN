extends PanelContainer
## Tadqiqot oynasi: chapda fuqarolik, o'ngda harbiy texnologiyalar.

const COL_GOOD := Color("#7bd88f")
const COL_BAD := Color("#ff6b6b")
const COL_EVENT := Color("#ffd166")
const COL_INFO := Color("#cfd8e3")
const COL_DIM := Color("#8a97a8")

var cols := {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(880, 560)
	offset_left = -440
	offset_right = 440
	offset_top = -280
	offset_bottom = 280
	visible = false
	var v := VBoxContainer.new()
	add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := _label("TADQIQOT", 22, Color.WHITE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = "  X  "
	close.pressed.connect(func(): visible = false)
	head.add_child(close)
	v.add_child(_label("Ilmiy markazlar har kuni ball beradi (har bir markaz = 1 ball). Har yo'nalishda bir vaqtda bitta tadqiqot.", 13, COL_DIM, true))
	v.add_child(HSeparator.new())
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 14)
	v.add_child(h)
	for b in ["civ", "mil"]:
		var sc := ScrollContainer.new()
		sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		h.add_child(sc)
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation", 8)
		sc.add_child(box)
		cols[b] = box
	Game.changed.connect(_on_changed)
	Tech.researched.connect(func(_id): _on_changed())


func toggle() -> void:
	visible = not visible
	if visible:
		rebuild()


func _on_changed() -> void:
	if visible:
		rebuild()


func _label(text: String, size := 15, color := COL_INFO, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func rebuild() -> void:
	for b in cols:
		var box: VBoxContainer = cols[b]
		for c in box.get_children():
			c.queue_free()
		var pts := Tech.points_per_day(b)
		var title := "FUQAROLIK (iqtisod)" if b == "civ" else "HARBIY"
		box.add_child(_label(title, 18, Color.WHITE))
		var lab := "Fuqarolik ilmiy markazi" if b == "civ" else "Harbiy ilmiy markaz"
		if pts <= 0.0:
			box.add_child(_label("Ball: 0/kun. Provinsiyangizda \"%s\" quring." % lab, 13, COL_BAD, true))
		else:
			box.add_child(_label("Ball: %d/kun (%d ta markaz)" % [int(pts), int(pts)], 13, COL_GOOD, true))
		for id in Tech.TECHS:
			if Tech.TECHS[id]["branch"] == b:
				box.add_child(_card(id))


func _card(id: String) -> PanelContainer:
	var t: Dictionary = Tech.TECHS[id]
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	var why := Tech.why_research(id)
	var is_active: bool = Tech.active[t["branch"]] == id
	if Tech.has(id):
		sb.bg_color = Color("#1f3a2a")
	elif is_active:
		sb.bg_color = Color("#3a3320")
	elif why != "":
		sb.bg_color = Color("#1a1f2a")
	else:
		sb.bg_color = Color("#22304a")
	card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	card.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var name := _label(t["name"], 16, Color.WHITE)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	head.add_child(_label("%d ball" % t["cost"], 13, COL_DIM))
	v.add_child(_label(t["desc"], 13, COL_INFO, true))
	if Tech.has(id):
		v.add_child(_label("TAYYOR", 13, COL_GOOD))
	elif is_active:
		var bar := ProgressBar.new()
		bar.max_value = t["cost"]
		bar.value = Tech.progress.get(id, 0.0)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 10)
		v.add_child(bar)
		var dl := Tech.days_left(id)
		v.add_child(_label("Tadqiq qilinmoqda: %s" % ("yana %d kun" % dl if dl >= 0 else "to'xtagan - ilmiy markaz yo'q"), 13, COL_EVENT))
	else:
		var b := Button.new()
		b.text = "Tadqiqotni boshlash"
		b.disabled = why != ""
		b.pressed.connect(Tech.start.bind(id))
		v.add_child(b)
		if why != "":
			v.add_child(_label(why, 12, COL_DIM))
		elif Tech.active[t["branch"]] != "":
			v.add_child(_label("Joriy tadqiqot (%s) almashtiriladi, to'plangan ball saqlanadi." % Tech.TECHS[Tech.active[t["branch"]]]["name"], 12, COL_DIM, true))
	return card
