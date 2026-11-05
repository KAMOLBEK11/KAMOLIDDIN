extends Node2D
## Taktik jang sahnasi (tepadan 2D, Generals uslubida).
## Chap tugma - tanlash (sudrab - guruh tanlash), o'ng tugma - yurish yoki nishonga hujum.
## Har bir birlik bir nechta askar yoki tankni ifodalaydi. Jang tugagach natija xaritaga qaytadi.

signal closed

const EXPLOSION := preload("res://scripts/explosion.gd")
const TOP := 70.0
const COL_P := Color("#e8b73a")
const COL_E := Color("#e04848")
const STATS := {
	"inf": {"hp": 10.0, "dmg": 0.35, "cd": 0.8, "range": 130.0, "speed": 38.0, "r": 13.0},
	"tank": {"hp": 80.0, "dmg": 7.0, "cd": 2.0, "range": 200.0, "speed": 52.0, "r": 16.0},
}
const SPLASH := 32.0

var army_id := -1
var player_attacking := true
var prov_id := ""
var units: Array = []
var shots: Array = []
var flashes: Array = []
var decor: Array = []
var ground := Color("#4f6b3a")
var ground2 := Color("#5d7a44")
var finished := false
var player_won := false
var time_scale := 1.0
var _sup := 1.0

var _drag_start := Vector2.ZERO
var _dragging := false
var _drag_now := Vector2.ZERO

var hud: Control
var info_label: Label
var result_panel: PanelContainer
var result_label: Label
var retreat_btn: Button
var fx: Node2D


# ---------------------------------------------------------------- tayyorlash

func setup(aid: int) -> void:
	army_id = aid
	var a := War.get_army(aid)
	prov_id = a["at"]
	var p: Dictionary = Game.provinces[prov_id]
	player_attacking = a["owner"] == Game.PLAYER
	_sup = War.supply_factor(a) if player_attacking else 1.0
	match p["country"]:
		"TKM", "AFG":
			ground = Color("#a68b5b"); ground2 = Color("#b89c68")
		"MNG", "KAZ":
			ground = Color("#7d8a4a"); ground2 = Color("#8d9a56")
		_:
			ground = Color("#4f6b3a"); ground2 = Color("#5d7a44")
	var size := get_viewport_rect().size
	var left := Rect2(60, TOP + 60, size.x * 0.25, size.y - TOP - 120)
	var right := Rect2(size.x * 0.7, TOP + 60, size.x * 0.25, size.y - TOP - 120)
	if player_attacking:
		_spawn_side(0, a["soldiers"], a["tanks"], 0.0, left, 1.0)
		var d: float = p["defense"]
		var et := floorf(d * 0.3 / War.TANK_POWER)
		_spawn_side(1, d - et * War.TANK_POWER, et, 0.0, right, 1.15)
	else:
		_spawn_side(0, p["units"]["soldier"], p["units"]["tank"], p["militia"], left, 1.15)
		_spawn_side(1, a["soldiers"], a["tanks"], 0.0, right, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(prov_id)
	for i in 70:
		decor.append({"kind": "patch", "pos": Vector2(rng.randf() * size.x, TOP + rng.randf() * (size.y - TOP)), "r": rng.randf_range(30, 90)})
	for i in 45:
		decor.append({"kind": "tree" if ground.g > ground.r else "rock", "pos": Vector2(rng.randf_range(0.3, 0.68) * size.x, TOP + 20 + rng.randf() * (size.y - TOP - 40)), "r": rng.randf_range(7, 14)})
	fx = Node2D.new()
	fx.z_index = 5
	add_child(fx)
	_build_hud(p)


func _spawn_side(side: int, soldiers: float, tanks: float, militia: float, area: Rect2, hp_mult: float) -> void:
	var list: Array = []
	if soldiers >= 0.5:
		var n := clampi(ceili(soldiers / 10.0), 1, 30)
		for i in n:
			list.append(["inf", soldiers / n, false])
	if militia >= 0.5:
		var m := clampi(ceili(militia / 5.0), 1, 6)
		for i in m:
			list.append(["inf", militia / m, true])
	if tanks >= 0.5:
		var t := clampi(roundi(tanks), 1, 12)
		for i in t:
			list.append(["tank", tanks / t, false])
	var cols := maxi(1, ceili(sqrt(list.size() / 2.0)))
	var rows := ceili(float(list.size()) / cols)
	for i in list.size():
		var cx := i % cols
		var cy := i / cols
		var fxp := (cx + 0.5) / cols
		if side == 1:
			fxp = 1.0 - fxp
		var pos := area.position + Vector2(area.size.x * fxp, area.size.y * (cy + 0.5) / rows)
		pos += Vector2(randf_range(-8, 8), randf_range(-8, 8))
		var type: String = list[i][0]
		var men: float = list[i][1]
		var hp: float = STATS[type]["hp"] * men * hp_mult
		units.append({"side": side, "type": type, "pos": pos, "men": men, "hp": hp, "maxhp": hp,
			"hp_per_man": STATS[type]["hp"] * hp_mult, "militia": list[i][2], "alive": true, "sel": false,
			"order": null, "target": null, "cd": randf() * 1.0, "face": Vector2.RIGHT if side == 0 else Vector2.LEFT,
			"turret": Vector2.RIGHT if side == 0 else Vector2.LEFT})


# ---------------------------------------------------------------- interfeys

func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	return b


func _build_hud(p: Dictionary) -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.gui_input.connect(_field_input)
	get_parent().add_child(hud)
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 8
	bar.offset_right = -8
	bar.offset_top = 8
	hud.add_child(bar)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	bar.add_child(h)
	var title := Label.new()
	title.text = "JANG: " + p["name"]
	title.add_theme_font_size_override("font_size", 18)
	h.add_child(title)
	info_label = Label.new()
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_label.clip_text = true
	h.add_child(info_label)
	h.add_child(_btn("Hammasini tanlash", _select_all))
	h.add_child(_btn("Hujum!", _all_attack))
	var sp := Button.new()
	sp.text = "1x"
	sp.custom_minimum_size = Vector2(44, 0)
	sp.pressed.connect(func():
		time_scale = 2.0 if time_scale == 1.0 else 1.0
		sp.text = "%dx" % int(time_scale))
	h.add_child(sp)
	h.add_child(_btn("Avtomatik", _auto))
	retreat_btn = _btn("Chekinish", _retreat)
	retreat_btn.visible = player_attacking
	h.add_child(retreat_btn)

	var tip := Label.new()
	tip.text = "Chap tugma: tanlash (sudrab - guruh).  O'ng tugma: yurish yoki dushmanga hujum."
	tip.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	tip.offset_left = 14
	tip.offset_top = -34
	tip.add_theme_color_override("font_outline_color", Color.BLACK)
	tip.add_theme_constant_override("outline_size", 4)
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(tip)

	result_panel = PanelContainer.new()
	result_panel.set_anchors_preset(Control.PRESET_CENTER)
	result_panel.offset_left = -220
	result_panel.offset_right = 220
	result_panel.offset_top = -90
	result_panel.offset_bottom = 90
	result_panel.visible = false
	hud.add_child(result_panel)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	result_panel.add_child(v)
	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.add_theme_font_size_override("font_size", 22)
	v.add_child(result_label)
	v.add_child(_btn("Xaritaga qaytish", _close))


func _select_all() -> void:
	for u in units:
		u["sel"] = u["alive"] and u["side"] == 0


func _all_attack() -> void:
	for u in units:
		if u["alive"] and u["side"] == 0:
			u["order"] = null
			u["target"] = null


# ---------------------------------------------------------------- sichqoncha

func _field_input(e: InputEvent) -> void:
	if finished:
		return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				_drag_start = mb.position
				_drag_now = mb.position
			elif _dragging:
				_dragging = false
				_select(_drag_start, mb.position, mb.shift_pressed)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_command(mb.position)
	elif e is InputEventMouseMotion and _dragging:
		_drag_now = (e as InputEventMouseMotion).position


func _select(a: Vector2, b: Vector2, add: bool) -> void:
	if not add:
		for u in units:
			u["sel"] = false
	if a.distance_to(b) < 6.0:
		var u := _unit_at(b, 0)
		if not u.is_empty():
			u["sel"] = true
		return
	var r := Rect2(a, Vector2.ZERO).expand(b)
	for u in units:
		if u["alive"] and u["side"] == 0 and r.has_point(u["pos"]):
			u["sel"] = true


func _unit_at(pos: Vector2, side: int) -> Dictionary:
	var best := {}
	var bd := 24.0
	for u in units:
		if u["alive"] and u["side"] == side:
			var d: float = u["pos"].distance_to(pos)
			if d < bd:
				bd = d
				best = u
	return best


func _command(pos: Vector2) -> void:
	var sel: Array = units.filter(func(u): return u["alive"] and u["sel"])
	if sel.is_empty():
		return
	var enemy := _unit_at(pos, 1)
	if not enemy.is_empty():
		for u in sel:
			u["target"] = enemy
			u["order"] = null
		flashes.append({"pos": enemy["pos"], "t": 0.4, "kind": "mark_atk"})
		return
	# guruh shaklida tarqatib joylashtirish
	var cols := ceili(sqrt(sel.size()))
	for i in sel.size():
		var off := Vector2((i % cols) - (cols - 1) / 2.0, (i / cols) - (cols - 1) / 2.0) * 34.0
		sel[i]["order"] = pos + off
		sel[i]["target"] = null
	flashes.append({"pos": pos, "t": 0.4, "kind": "mark_move"})


# ---------------------------------------------------------------- simulyatsiya

func _process(delta: float) -> void:
	if finished:
		queue_redraw()
		return
	var dt := delta * time_scale
	var size := get_viewport_rect().size
	for u in units:
		if not u["alive"]:
			continue
		var st: Dictionary = STATS[u["type"]]
		u["cd"] -= dt
		var enemy: Dictionary = u["target"] if u["target"] != null and u["target"]["alive"] else _nearest_enemy(u)
		var dist := INF
		if not enemy.is_empty():
			dist = u["pos"].distance_to(enemy["pos"])
		var move_to = null
		if u["order"] != null:
			move_to = u["order"]
			if u["pos"].distance_to(u["order"]) < 4.0:
				u["order"] = null
				move_to = null
		elif not enemy.is_empty() and dist > st["range"] * 0.85:
			move_to = enemy["pos"]
		if move_to != null:
			var dir: Vector2 = (move_to - u["pos"]).normalized()
			u["pos"] += dir * st["speed"] * dt
			u["face"] = u["face"].lerp(dir, 0.15).normalized()
		if not enemy.is_empty():
			var aim: Vector2 = (enemy["pos"] - u["pos"]).normalized()
			u["turret"] = u["turret"].lerp(aim, 0.2).normalized()
			if dist <= st["range"] and u["cd"] <= 0.0:
				_fire(u, enemy)
				u["cd"] = st["cd"] * randf_range(0.85, 1.15)
		u["pos"] = u["pos"].clamp(Vector2(10, TOP + 10), size - Vector2(10, 10))
	_separate()
	_update_shots(dt)
	for f in flashes.duplicate():
		f["t"] -= dt
		if f["t"] <= 0.0:
			flashes.erase(f)
	_update_info()
	_check_end()
	queue_redraw()


func _nearest_enemy(u: Dictionary) -> Dictionary:
	var best := {}
	var bd := INF
	for o in units:
		if o["alive"] and o["side"] != u["side"]:
			var d: float = u["pos"].distance_squared_to(o["pos"])
			if d < bd:
				bd = d
				best = o
	return best


func _separate() -> void:
	for i in units.size():
		var a: Dictionary = units[i]
		if not a["alive"]:
			continue
		for j in range(i + 1, units.size()):
			var b: Dictionary = units[j]
			if not b["alive"]:
				continue
			var min_d: float = STATS[a["type"]]["r"] + STATS[b["type"]]["r"]
			var d: Vector2 = b["pos"] - a["pos"]
			var l := d.length()
			if l < min_d and l > 0.01:
				var push := d / l * (min_d - l) * 0.5
				a["pos"] -= push
				b["pos"] += push


func _fire(u: Dictionary, enemy: Dictionary) -> void:
	var st: Dictionary = STATS[u["type"]]
	var dmg: float = st["dmg"] * u["men"] * (_sup if u["side"] == 0 and player_attacking else 1.0)
	if u["side"] == 0:
		dmg *= Tech.mult("tank" if u["type"] == "tank" else "soldier")
	var muzzle: Vector2 = u["pos"] + u["turret"] * (20.0 if u["type"] == "tank" else 8.0)
	flashes.append({"pos": muzzle, "t": 0.07, "kind": "muzzle", "big": u["type"] == "tank"})
	if u["type"] == "tank":
		var dest: Vector2 = enemy["pos"] + Vector2(randf_range(-12, 12), randf_range(-12, 12))
		shots.append({"kind": "shell", "pos": muzzle, "dest": dest, "dmg": dmg, "side": u["side"], "speed": 420.0, "target": enemy})
	else:
		if enemy["type"] == "tank":
			dmg *= 0.5
		shots.append({"kind": "bullet", "pos": muzzle, "dest": enemy["pos"], "dmg": dmg, "side": u["side"], "speed": 700.0, "target": enemy})


func _update_shots(dt: float) -> void:
	for s in shots.duplicate():
		var t: Dictionary = s["target"]
		if s["kind"] == "bullet" and t["alive"]:
			s["dest"] = t["pos"]
		var step: float = s["speed"] * dt
		if s["pos"].distance_to(s["dest"]) <= step:
			shots.erase(s)
			if s["kind"] == "bullet":
				if t["alive"]:
					_damage(t, s["dmg"])
			else:
				_boom(s["dest"], false, 0.55)
				for o in units:
					if o["alive"] and o["side"] != s["side"]:
						var d: float = o["pos"].distance_to(s["dest"])
						if d <= SPLASH:
							_damage(o, s["dmg"] * (1.0 if o == t else 0.5))
		else:
			s["pos"] = s["pos"].move_toward(s["dest"], step)


func _damage(u: Dictionary, d: float) -> void:
	u["hp"] -= d
	u["men"] = maxf(0.0, u["hp"] / u["hp_per_man"])
	if u["hp"] <= 0.0:
		u["alive"] = false
		u["sel"] = false
		u["men"] = 0.0
		_boom(u["pos"], u["type"] == "tank", 1.0 if u["type"] == "tank" else 0.6)


func _boom(pos: Vector2, big: bool, scale_k: float) -> void:
	var e := EXPLOSION.new()
	e.big = big
	e.position = pos
	e.scale = Vector2.ONE * scale_k
	fx.add_child(e)


# ---------------------------------------------------------------- hisob va natija

func _totals(side: int) -> Dictionary:
	var out := {"soldiers": 0.0, "tanks": 0.0, "militia": 0.0, "units": 0}
	for u in units:
		if u["side"] != side or not u["alive"]:
			continue
		out["units"] += 1
		if u["type"] == "tank":
			out["tanks"] += u["men"]
		elif u["militia"]:
			out["militia"] += u["men"]
		else:
			out["soldiers"] += u["men"]
	return out


func _update_info() -> void:
	var a := _totals(0)
	var b := _totals(1)
	info_label.text = "  Siz: %d askar, %d tank%s  |  Dushman: %d askar, %d tank" % [
		roundi(a["soldiers"] + a["militia"]), roundi(a["tanks"]),
		("  (zaxira %d%%)" % roundi(_sup * 100)) if player_attacking and _sup < 1.0 else "",
		roundi(b["soldiers"]), roundi(b["tanks"])]


func _check_end() -> void:
	var a := _totals(0)
	var b := _totals(1)
	if a["units"] > 0 and b["units"] > 0:
		return
	finished = true
	player_won = b["units"] == 0
	_apply()
	if player_won:
		result_label.text = "G'ALABA!\n" + ("%s bosib olindi." % Game.provinces[prov_id]["name"] if player_attacking else "Hujum qaytarildi.")
		result_label.add_theme_color_override("font_color", Color("#7bd88f"))
	else:
		result_label.text = "MAG'LUBIYAT\n" + ("Qo'shiningiz yo'q qilindi." if player_attacking else "%s qo'ldan ketdi." % Game.provinces[prov_id]["name"])
		result_label.add_theme_color_override("font_color", Color("#ff6b6b"))
	result_panel.visible = true


func _apply() -> void:
	## Jang natijasini xaritadagi qo'shin va provinsiyaga yozadi
	var a := War.get_army(army_id)
	if a.is_empty():
		return
	var p: Dictionary = Game.provinces[prov_id]
	var mine := _totals(0)
	var them := _totals(1)
	if player_attacking:
		a["soldiers"] = mine["soldiers"]
		a["tanks"] = mine["tanks"]
		p["defense"] = them["soldiers"] + them["tanks"] * War.TANK_POWER
		if p["defense"] < 0.5:
			War.capture_by_player(a, prov_id)
		elif War.power(a) < 0.5:
			War.armies.erase(a)
			Game.message.emit("Qo'shiningiz %s da tor-mor bo'ldi!" % p["name"], "bad")
	else:
		a["soldiers"] = them["soldiers"]
		a["tanks"] = them["tanks"]
		p["units"]["soldier"] = mine["soldiers"]
		p["units"]["tank"] = mine["tanks"]
		p["militia"] = mine["militia"]
		if War.power(a) < 0.5:
			War.armies.erase(a)
			Game.message.emit("%s himoyachilari dushman hujumini qaytardi!" % p["name"], "good")
		elif War.garrison_power(p) + p["militia"] < 0.5:
			War.bot_capture(a, prov_id)
	Game.changed.emit()


func _auto() -> void:
	if not finished:
		finished = true
		_apply()
	_close()


func _retreat() -> void:
	if not finished:
		finished = true
		_apply()
		if not War.get_army(army_id).is_empty():
			War.retreat(army_id)
	_close()


func _close() -> void:
	hud.queue_free()
	closed.emit()
	queue_free()


# ---------------------------------------------------------------- chizish

func _draw() -> void:
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), ground)
	for d in decor:
		if d["kind"] == "patch":
			draw_circle(d["pos"], d["r"], ground2)
	# shtab chodirlari (generallar)
	_hq(Vector2(30, size.y / 2.0), COL_P)
	_hq(Vector2(size.x - 30, size.y / 2.0), COL_E)
	for d in decor:
		if d["kind"] == "tree":
			draw_circle(d["pos"] + Vector2(3, 3), d["r"], Color(0, 0, 0, 0.25))
			draw_circle(d["pos"], d["r"], Color("#2f4a24"))
			draw_circle(d["pos"] - Vector2(2, 2), d["r"] * 0.6, Color("#3d5e2e"))
		elif d["kind"] == "rock":
			draw_circle(d["pos"], d["r"] * 0.8, Color("#7a6a52"))
			draw_circle(d["pos"] - Vector2(2, 2), d["r"] * 0.5, Color("#8f7f66"))
	# halok bo'lganlar izi
	for u in units:
		if not u["alive"]:
			if u["type"] == "tank":
				draw_set_transform(u["pos"], u["face"].angle())
				draw_rect(Rect2(-13, -9, 26, 18), Color(0.12, 0.12, 0.12, 0.85))
				draw_set_transform(Vector2.ZERO)
			else:
				draw_circle(u["pos"], 5, Color(0.25, 0.1, 0.08, 0.5))
	for u in units:
		if u["alive"]:
			_unit(u)
	for s in shots:
		if s["kind"] == "bullet":
			var dir: Vector2 = (s["dest"] - s["pos"]).normalized()
			draw_line(s["pos"] - dir * 7.0, s["pos"], Color(1, 0.9, 0.4), 1.5)
		else:
			draw_circle(s["pos"], 3.0, Color(0.15, 0.15, 0.15))
	for f in flashes:
		match f["kind"]:
			"muzzle":
				draw_circle(f["pos"], 6.0 if f["big"] else 3.0, Color(1, 0.85, 0.4, 0.9))
			"mark_move":
				draw_arc(f["pos"], 14.0 * (1.0 - f["t"]) + 4.0, 0, TAU, 20, Color(0.5, 1, 0.5, f["t"] * 2.0), 2.0)
			"mark_atk":
				draw_arc(f["pos"], 18.0 * (1.0 - f["t"]) + 6.0, 0, TAU, 20, Color(1, 0.3, 0.3, f["t"] * 2.0), 2.5)
	if _dragging and _drag_start.distance_to(_drag_now) > 6.0:
		var r := Rect2(_drag_start, Vector2.ZERO).expand(_drag_now)
		draw_rect(r, Color(0.5, 1, 0.5, 0.12))
		draw_rect(r, Color(0.5, 1, 0.5, 0.8), false, 1.5)


func _hq(pos: Vector2, col: Color) -> void:
	draw_rect(Rect2(pos - Vector2(18, 16), Vector2(36, 32)), Color("#4a4a3a"))
	draw_colored_polygon(PackedVector2Array([pos + Vector2(-20, -16), pos + Vector2(0, -28), pos + Vector2(20, -16)]), Color("#5e5e48"))
	draw_line(pos + Vector2(14, -16), pos + Vector2(14, -44), Color.BLACK, 2.0)
	draw_colored_polygon(PackedVector2Array([pos + Vector2(14, -44), pos + Vector2(32, -38), pos + Vector2(14, -32)]), col)
	draw_circle(pos + Vector2(0, 4), 5, Color("#d9b48c"))   # general
	draw_circle(pos + Vector2(0, 1), 5, Color("#3b4a2c"))


func _unit(u: Dictionary) -> void:
	var col := COL_P if u["side"] == 0 else COL_E
	var pos: Vector2 = u["pos"]
	if u["sel"]:
		draw_arc(pos, STATS[u["type"]]["r"] + 5.0, 0, TAU, 24, Color(0.5, 1, 0.5), 2.0)
	if u["type"] == "tank":
		var body := col.darkened(0.35) if u["side"] == 0 else col.darkened(0.3)
		draw_set_transform(pos + Vector2(3, 3), u["face"].angle())
		draw_rect(Rect2(-13, -9, 26, 18), Color(0, 0, 0, 0.3))
		draw_set_transform(pos, u["face"].angle())
		draw_rect(Rect2(-13, -10, 26, 5), Color(0.15, 0.15, 0.15))
		draw_rect(Rect2(-13, 5, 26, 5), Color(0.15, 0.15, 0.15))
		draw_rect(Rect2(-11, -7, 22, 14), body)
		draw_set_transform(pos, u["turret"].angle())
		draw_rect(Rect2(4, -1.5, 16, 3), Color(0.2, 0.2, 0.18))
		draw_circle(Vector2.ZERO, 6.0, body.lightened(0.15))
		draw_circle(Vector2.ZERO, 6.0, col, false, 1.2)
		draw_set_transform(Vector2.ZERO)
	else:
		var n := clampi(ceili(u["men"] / maxf(0.01, u["maxhp"] / u["hp_per_man"]) * 5.0), 1, 5)
		var offs := [Vector2(0, 0), Vector2(-7, -5), Vector2(7, -5), Vector2(-7, 6), Vector2(7, 6)]
		var side: Vector2 = u["face"].orthogonal()
		for i in n:
			var o: Vector2 = offs[i]
			var p2: Vector2 = pos + u["face"] * o.x * 0.2 + side * o.x + u["face"] * -o.y
			draw_circle(p2 + Vector2(1.5, 1.5), 4.0, Color(0, 0, 0, 0.3))
			draw_circle(p2, 4.0, col.darkened(0.45) if u["militia"] else col.darkened(0.2))
			draw_circle(p2, 2.2, Color("#3b4a2c") if u["side"] == 0 else Color("#4a2c2c"))
			draw_line(p2, p2 + u["turret"] * 6.0, Color(0.1, 0.1, 0.1), 1.2)
	if u["hp"] < u["maxhp"]:
		var w := 26.0
		var bp := pos + Vector2(-w / 2.0, -STATS[u["type"]]["r"] - 7.0)
		draw_rect(Rect2(bp, Vector2(w, 3.5)), Color(0, 0, 0, 0.7))
		var k: float = clampf(u["hp"] / u["maxhp"], 0.0, 1.0)
		draw_rect(Rect2(bp, Vector2(w * k, 3.5)), Color("#7bd88f") if k > 0.5 else (Color("#ffd166") if k > 0.25 else Color("#ff6b6b")))
