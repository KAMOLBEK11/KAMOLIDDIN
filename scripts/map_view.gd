extends Node2D
## Global xarita: provinsiyalarni chizish, kamera (surish/yaqinlashtirish), bosish va ikonkalar.

const MIN_ZOOM := 0.3
const MAX_ZOOM := 8.0
const PLAYER_COLOR := Color("#e8b73a")
const REBEL_COLOR := Color("#5a5a5a")

var cam: Camera2D
var fills := {}          # id -> Array[Polygon2D]
var hit := {}            # id -> Array[[Rect2, PackedVector2Array]]
var border_lines: Array = []
var labels := {}         # id -> Node2D (yozuv)
var country_labels: Array = []
var icon_nodes := {}     # id -> Node2D
var select_lines: Array = []
var hover_id := ""
var air_layer: Node2D
var _bounds := Rect2()
var army_layer: Node2D
var fx_layer: Node2D
const EXPLOSION := preload("res://scripts/explosion.gd")

var overlay := false       # true: 3D xarita uchun tekstura sifatida chiziladi (kamera qotirilgan, kiritish yo'q)
var _dragging := false
# silliq kamera
var _tz := 0.75            # maqsad masshtab
var _tpos := Vector2.ZERO  # maqsad joy
var _anchor := false
var _anchor_screen := Vector2.ZERO
var _anchor_world := Vector2.ZERO
var _vel := Vector2.ZERO   # sudrashdan keyingi inersiya
var _moved := false
var _press_pos := Vector2.ZERO
var _textures := {}
var country_lines: Array = []
var _border_root: Node2D
var _last_owner_sig := ""


func _ready() -> void:
	cam = Camera2D.new()
	add_child(cam)
	cam.make_current()
	_build()
	Game.changed.connect(_refresh_all)
	Game.selected.connect(_on_selected)
	War.explosion.connect(_spawn_explosion)
	War.nuke_flash.connect(_spawn_nuke)
	army_layer = preload("res://scripts/armies_layer.gd").new()
	army_layer.cam = cam
	army_layer.z_index = 5
	add_child(army_layer)
	air_layer = preload("res://scripts/air_traffic.gd").new()
	air_layer.cam = cam
	army_layer.overlay = overlay
	air_layer.overlay = overlay
	air_layer.z_index = 7
	add_child(air_layer)
	fx_layer = Node2D.new()
	fx_layer.z_index = 6
	add_child(fx_layer)
	_focus_on(Vector2(-450, 40), 0.75)  # Markaziy Osiyo atrofi


func _tex(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path)
	return _textures[path]


# ---------------------------------------------------------------- chizish

func _build() -> void:
	var fill_layer := Node2D.new()
	var border_layer := Node2D.new()
	var icon_layer := Node2D.new()
	var label_layer := Node2D.new()
	add_child(fill_layer)
	add_child(border_layer)
	add_child(label_layer)
	add_child(icon_layer)

	for id in Game.province_order:
		var p: Dictionary = Game.provinces[id]
		fills[id] = []
		hit[id] = []
		for pts in p["polys"]:
			var poly := Polygon2D.new()
			poly.polygon = pts
			poly.antialiased = true
			fill_layer.add_child(poly)
			fills[id].append(poly)
			var r := Rect2(pts[0] as Vector2, Vector2.ZERO)
			for v in pts:
				r = r.expand(v)
			hit[id].append([r, pts])
			var line := Line2D.new()
			var closed: PackedVector2Array = pts.duplicate()
			closed.append(pts[0])
			line.points = closed
			line.default_color = Color(0.05, 0.07, 0.1, 0.85)
			line.joint_mode = Line2D.LINE_JOINT_ROUND
			line.antialiased = true
			border_layer.add_child(line)
			border_lines.append(line)

		var lab := _make_label(p["name"], 13)
		lab.position = p["center"]
		label_layer.add_child(lab)
		labels[id] = lab

		var icons := Node2D.new()
		icons.position = p["center"] + Vector2(0, 10)
		icon_layer.add_child(icons)
		icon_nodes[id] = icons

	# davlat nomlari (uzoqdan ko'rinadi)
	var sums := {}
	for id in Game.province_order:
		var p: Dictionary = Game.provinces[id]
		var c: String = p["country"]
		if not sums.has(c):
			sums[c] = [Vector2.ZERO, 0]
		sums[c][0] += p["center"]
		sums[c][1] += 1
	for c in sums:
		var lab := _make_label(Game.countries[c]["name"].to_upper(), 22)
		lab.position = sums[c][0] / sums[c][1]
		label_layer.add_child(lab)
		country_labels.append(lab)

	_refresh_all()
	_bounds = Rect2(Game.provinces[Game.province_order[0]]["center"], Vector2.ZERO)
	for id in Game.province_order:
		for pts in Game.provinces[id]["polys"]:
			for v in pts:
				_bounds = _bounds.expand(v)
	_on_zoom_changed()


func _make_label(text: String, size: int) -> Node2D:
	var holder := Node2D.new()
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = Vector2(300, 30)
	l.position = Vector2(-150, -15)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(l)
	return holder


func province_color(id: String) -> Color:
	var p: Dictionary = Game.provinces[id]
	var col: Color
	match p["owner"]:
		Game.PLAYER:
			col = PLAYER_COLOR
		Game.REBEL:
			col = REBEL_COLOR
		_:
			col = Color(Game.countries[p["owner"]]["color"]).darkened(0.15)
			if War.wars.has(p["owner"]):
				col = col.lerp(Color(0.75, 0.12, 0.12), 0.35)
	# (viloyatlar bir xil rangda - davlat bir butun ko'rinadi, ichki chegaralar nozik chiziq)
	if id == hover_id:
		col = col.lightened(0.2)
	if overlay:
		col.a = 0.78 if p["owner"] == Game.PLAYER else (0.62 if id == hover_id else 0.5)
	return col


func _owner_sig() -> String:
	var s := ""
	for id in Game.province_order:
		s += Game.provinces[id]["owner"].left(3)
	return s


func _build_country_lines() -> void:
	## davlatlar chegarasi: viloyat qirrasining narigi tomoni boshqa egaga tegishli bo'lsa - qalin to'q chiziq
	for l in country_lines:
		l.queue_free()
	country_lines.clear()
	if _border_root == null:
		_border_root = Node2D.new()
		add_child(_border_root)
	for id in Game.province_order:
		var p: Dictionary = Game.provinces[id]
		for pts in p["polys"]:
			var n: int = pts.size()
			var run := PackedVector2Array()
			for i in n + 1:
				var a: Vector2 = pts[i % n]
				var b: Vector2 = pts[(i + 1) % n]
				var mid := (a + b) * 0.5
				var nrm := (b - a).orthogonal().normalized()
				# qirraning ikki tomonidagi nuqtani tekshiramiz; tashqi tomondagi viloyat egasi boshqami?
				var other := ""
				for q in [mid + nrm * 1.5, mid - nrm * 1.5]:
					if Geometry2D.is_point_in_polygon(q, pts):
						continue
					for nb in p["neighbors"]:
						for npts in Game.provinces[nb]["polys"]:
							if Geometry2D.is_point_in_polygon(q, npts):
								other = Game.provinces[nb]["owner"]
								break
						if other != "":
							break
				var is_border: bool = i < n and other != p["owner"]
				if is_border:
					if run.is_empty():
						run.append(a)
					run.append(b)
				elif run.size() > 1:
					_add_country_line(run)
					run = PackedVector2Array()
				else:
					run = PackedVector2Array()
			if run.size() > 1:
				_add_country_line(run)


func _add_country_line(pts: PackedVector2Array) -> void:
	var line := Line2D.new()
	line.points = pts
	line.default_color = Color(0.02, 0.03, 0.05, 0.85)
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	_border_root.add_child(line)
	country_lines.append(line)


func _refresh_all() -> void:
	var sig := _owner_sig()
	if sig != _last_owner_sig:
		_last_owner_sig = sig
		_build_country_lines()
		_on_zoom_changed()
	for id in Game.province_order:
		var col := province_color(id)
		for poly in fills[id]:
			poly.color = col
		_refresh_icons(id)


func _refresh_icons(id: String) -> void:
	## Eski ikonkalar olib tashlandi: binolar endi xaritada o'z joyida zamonaviy rasm bo'lib chiziladi (armies_layer)
	var holder: Node2D = icon_nodes[id]
	for ch in holder.get_children():
		ch.queue_free()


func _on_selected(id: String) -> void:
	for l in select_lines:
		l.queue_free()
	select_lines.clear()
	if id == "":
		return
	for pts in Game.provinces[id]["polys"]:
		var line := Line2D.new()
		var closed: PackedVector2Array = pts.duplicate()
		closed.append(pts[0])
		line.points = closed
		line.default_color = Color(1, 1, 1, 0.95)
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.antialiased = true
		add_child(line)
		select_lines.append(line)
	_on_zoom_changed()


# ---------------------------------------------------------------- kamera

func _focus_on(world_pos: Vector2, zoom: float, instant := false) -> void:
	## Kamerani silliq uchib borib joylashtiradi
	_anchor = false
	_tpos = world_pos
	_tz = clampf(zoom, MIN_ZOOM, MAX_ZOOM)
	_vel = Vector2.ZERO
	if instant or cam.position == Vector2.ZERO:
		cam.position = world_pos
		cam.zoom = Vector2(_tz, _tz)
		_on_zoom_changed()


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var vs := get_viewport_rect().size
	return cam.position + (screen_pos - vs / 2.0) / cam.zoom.x


func zoom_at(factor: float, screen_pos: Vector2) -> void:
	## Silliq yaqinlashish: sichqoncha ostidagi nuqta joyida qoladi
	_tz = clampf(_tz * factor, MIN_ZOOM, MAX_ZOOM)
	_anchor = true
	_anchor_screen = screen_pos
	_anchor_world = _screen_to_world(screen_pos)
	_vel = Vector2.ZERO


func _on_zoom_changed() -> void:
	var z := cam.zoom.x
	if overlay:
		for l in border_lines:
			l.width = 1.3 / z
			l.default_color = Color(0.05, 0.06, 0.08, 0.28)
		for l in country_lines:
			l.width = 3.4 / z
		for l in select_lines:
			l.width = 5.0 / z
		for id in labels:
			labels[id].visible = false
		for l in country_labels:
			l.visible = false
		for id in icon_nodes:
			icon_nodes[id].visible = false
		return
	var w := 1.2 / z
	for l in border_lines:
		l.width = w
	for l in country_lines:
		l.width = w * 2.6
	for l in select_lines:
		l.width = 3.0 / z
	var inv := Vector2.ONE / z
	var show_prov := z >= 1.3
	for id in labels:
		labels[id].scale = inv
		labels[id].visible = show_prov
	for l in country_labels:
		l.scale = inv
		l.visible = not show_prov
	var icon_scale := inv * clampf(z / 1.5, 0.6, 1.0)
	for id in icon_nodes:
		icon_nodes[id].scale = icon_scale
		icon_nodes[id].visible = z >= 0.6


func _process(delta: float) -> void:
	if overlay:
		return
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): dir.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): dir.y += 1
	if dir != Vector2.ZERO:
		_tpos += dir.normalized() * 700.0 * delta / cam.zoom.x
		_anchor = false
	var k := 1.0 - exp(-11.0 * delta)
	# masshtab
	if absf(cam.zoom.x - _tz) > 0.0005:
		var z := lerpf(cam.zoom.x, _tz, k)
		if absf(z - _tz) < 0.0005:
			z = _tz
		cam.zoom = Vector2(z, z)
		if _anchor:
			var vs := get_viewport_rect().size
			cam.position = _anchor_world - (_anchor_screen - vs / 2.0) / z
			_tpos = cam.position
		_on_zoom_changed()
	else:
		_anchor = false
	# inersiya
	if not _dragging and _vel.length() > 5.0:
		_tpos += _vel * delta
		_vel *= exp(-4.5 * delta)
	if _bounds.size != Vector2.ZERO:
		# kamera xaritadan chiqib ketmasin
		_tpos = _tpos.clamp(_bounds.position, _bounds.end)
	if not _anchor:
		cam.position = cam.position.lerp(_tpos, k)


# ---------------------------------------------------------------- sichqoncha / sensor

func set_hover(id: String) -> void:
	if id == hover_id:
		return
	var old := hover_id
	hover_id = id
	for pid in [old, id]:
		if pid != "":
			for poly in fills[pid]:
				poly.color = province_color(pid)


func province_at(world: Vector2) -> String:
	for id in Game.province_order:
		for h in hit[id]:
			if h[0].has_point(world) and Geometry2D.is_point_in_polygon(world, h[1]):
				return id
	return ""


func _unhandled_input(e: InputEvent) -> void:
	if overlay:
		return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			if _tz >= MAX_ZOOM * 0.999:
				# eng yaqin masshtabda yana yaqinlashtirish - viloyat 3D bazasiga kirish
				var pid := province_at(_screen_to_world(mb.position))
				if pid != "" and Game.provinces[pid]["owner"] == Game.PLAYER:
					Game.open_province.emit(pid)
					return
			zoom_at(1.3 if mb.factor <= 1.0 else pow(1.3, mb.factor), mb.position)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_at(1.0 / (1.3 if mb.factor <= 1.0 else pow(1.3, mb.factor)), mb.position)
		elif mb.pressed and mb.double_click and mb.button_index == MOUSE_BUTTON_LEFT:
			# jang ketayotgan provinsiyani ikki marta bosish - 3D jang sahnasiga kirish
			var bid := province_at(_screen_to_world(mb.position))
			if bid != "" and not War.armies_in(bid).is_empty():
				War.open_battle.emit(War.armies_in(bid)[0]["id"])
			elif bid != "" and Game.provinces[bid]["owner"] == Game.PLAYER:
				Game.open_province.emit(bid)
		elif mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_dragging = true
				_moved = false
				_vel = Vector2.ZERO
				_press_pos = mb.position
			else:
				_dragging = false
				if not _moved and mb.button_index == MOUSE_BUTTON_LEFT:
					if War.target_from == "":
						var bd: Array = army_layer.border_at(mb.position)
						if not bd.is_empty():
							Game.open_border.emit(bd[0], bd[1])
							return
					var clicked := province_at(_screen_to_world(mb.position))
					if War.target_from != "":
						War.choose_target(clicked)
					else:
						Game.select(clicked)
				elif not _moved and mb.button_index == MOUSE_BUTTON_RIGHT:
					War.cancel_target()
	elif e is InputEventMouseMotion:
		var mm := e as InputEventMouseMotion
		if _dragging:
			if mm.position.distance_to(_press_pos) > 6.0:
				_moved = true
			if _moved:
				cam.position -= mm.relative / cam.zoom.x
				_tpos = cam.position
				_anchor = false
				_vel = _vel.lerp(-mm.relative / cam.zoom.x * 60.0, 0.5)
		else:
			var id := province_at(_screen_to_world(mm.position))
			if id != hover_id:
				var old := hover_id
				hover_id = id
				for pid in [old, id]:
					if pid != "":
						for poly in fills[pid]:
							poly.color = province_color(pid)
	elif e is InputEventMagnifyGesture:
		var mg := e as InputEventMagnifyGesture
		zoom_at(mg.factor, mg.position)
	elif e is InputEventPanGesture:
		var pg := e as InputEventPanGesture
		_tpos += pg.delta * 8.0 / cam.zoom.x


func _spawn_explosion(pos: Vector2, big: bool) -> void:
	if overlay:
		return
	var e := EXPLOSION.new()
	e.big = big
	e.position = pos
	e.scale = Vector2.ONE / cam.zoom.x * clampf(cam.zoom.x / 1.5, 0.7, 1.4)
	fx_layer.add_child(e)


func _spawn_nuke(pos: Vector2) -> void:
	if overlay:
		return
	var e := EXPLOSION.new()
	e.nuke = true
	e.position = pos
	e.scale = Vector2.ONE / cam.zoom.x * clampf(cam.zoom.x / 1.5, 0.7, 1.4)
	fx_layer.add_child(e)
