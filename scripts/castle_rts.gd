class_name CastleRTS
extends Node
## Qal'ada askarlarni "Kazaki" uslubida boshqarish:
##  - sichqoncha bilan bitta askarni bosib yoki ramka chizib ko'p askarni belgilash (Shift - qo'shish, ikki marta bosish - shu turdagilarning hammasi)
##  - belgilangan askarlarni yerga bosib yurgizish (chap yoki o'ng tugma) - devor, bino, minora, ark ichidan o'tmaydi, faqat ochiq darvozadan chiqadi
##  - devorga chiqish: askar minora tagidagi eshikka boradi, ichkariga kirib devor yo'lagiga chiqadi
##  - buyruqlar paneli: saflar (qator, to'rtburchak, qalqon devori, qo'mondon atrofida halqa), qalqon bilan himoya, hujum holati,
##    kamonchilarga nishon ko'rsatish, to'xtash, joyiga qaytish, darvozani ochish/yopish

const CS := 1.5                 # yo'l topish to'ri katakchasi (m)
const B := 240.0                # to'r chegarasi (markazdan)
const WALK_SP := 2.1
const RUN_SP := 4.8

var c                            # castle3d
var astar := AStarGrid2D.new()
var N := 0
var sel: Array = []              # tanlangan Node3D lar
var aim_mode := false            # keyingi bosish - kamonchilar uchun nishon
var arrows: Array = []
var panel: PanelContainer
var info: Label
var cmd_box: HBoxContainer
var gate_btn: Button
var box_rect: Panel
var _box_from := Vector2.ZERO
var _last_click_ms := 0
var _guard_t := 0.0
var _rng := RandomNumberGenerator.new()


func setup(castle) -> void:
	c = castle
	_rng.randomize()
	_build_ui()


# ================================================================ yo'l topish to'ri

func rebuild_nav() -> void:
	N = int(B * 2.0 / CS)
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, N, N)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	var open := gates_open()
	var gates: Array = []
	for g in c.data["gates"]:
		gates.append(g)
	# devorlar
	for w in c.data["walls"]:
		var a: Vector3 = c._v(w["a"])
		var b: Vector3 = c._v(w["b"])
		var L := a.distance_to(b)
		var n := maxi(1, int(L / 0.7))
		for i in n + 1:
			var p := a.lerp(b, float(i) / float(n))
			if open and _in_gate_passage(p, gates):
				continue
			_solid_disc(p, 2.0)
	# xandaq (darvoza oldida ko'prik)
	for m in c.data["moats"]:
		var a2: Vector3 = c._v(m["a"])
		var b2: Vector3 = c._v(m["b"])
		var n2 := maxi(1, int(a2.distance_to(b2) / 0.7))
		for i in n2 + 1:
			var p2 := a2.lerp(b2, float(i) / float(n2))
			if c._gate_near(p2, 6.0):
				continue
			_solid_disc(p2, 2.4)
	# minoralar, ark, binolar
	for t in c.data["towers"]:
		_solid_disc(c._v(t["p"]), 4.3)
	var kf: Vector2 = c.FOOT["keep"]
	_solid_rect(c._keep(), kf * 0.5 + Vector2(0.4, 0.4), 0.0)
	for bd in c.data["buildings"]:
		var f: Vector2 = c.FOOT.get(bd["t"], Vector2(8, 8))
		_solid_rect(c._v(bd["p"]), f * 0.5 + Vector2(0.3, 0.3), float(bd["rot"]))
	if open:
		# darvoza yo'lagi doim ochiq (yon minoralarga qaramay)
		for g in gates:
			var ang := float(g["ang"])
			var outer := Vector3(sin(ang), 0, cos(ang))
			var along := Vector3(cos(ang), 0, -sin(ang))
			for k in range(-6, 7):
				for s in [-1.2, 0.0, 1.2]:
					var q: Vector3 = c._v(g["p"]) + outer * float(k) + along * s
					var ci := _cell(q)
					if _okc(ci):
						astar.set_point_solid(ci, false)


func gates_open() -> bool:
	return bool(c.data.get("gate_open", true))


func _in_gate_passage(p: Vector3, gates: Array) -> bool:
	for g in gates:
		var gp: Vector3 = c._v(g["p"])
		var ang := float(g["ang"])
		var along := Vector3(cos(ang), 0, -sin(ang))
		var d := p - gp
		if absf(d.dot(along)) < 2.6 and Vector2(d.x, d.z).length() < 5.0:
			return true
	return false


func _cell(p: Vector3) -> Vector2i:
	return Vector2i(int(floor((p.x + B) / CS)), int(floor((p.z + B) / CS)))


func _okc(ci: Vector2i) -> bool:
	return ci.x >= 0 and ci.y >= 0 and ci.x < N and ci.y < N


func _world(ci: Vector2i) -> Vector3:
	return Vector3((ci.x + 0.5) * CS - B, 0, (ci.y + 0.5) * CS - B)


func _solid_disc(p: Vector3, r: float) -> void:
	var c0 := _cell(p - Vector3(r, 0, r))
	var c1 := _cell(p + Vector3(r, 0, r))
	for x in range(c0.x, c1.x + 1):
		for y in range(c0.y, c1.y + 1):
			var ci := Vector2i(x, y)
			if _okc(ci) and _world(ci).distance_to(Vector3(p.x, 0, p.z)) <= r:
				astar.set_point_solid(ci, true)


func _solid_rect(p: Vector3, half: Vector2, rot: float) -> void:
	var r := half.length()
	var c0 := _cell(p - Vector3(r, 0, r))
	var c1 := _cell(p + Vector3(r, 0, r))
	var inv := Basis(Vector3.UP, -rot)
	for x in range(c0.x, c1.x + 1):
		for y in range(c0.y, c1.y + 1):
			var ci := Vector2i(x, y)
			if not _okc(ci):
				continue
			var l: Vector3 = inv * (_world(ci) - Vector3(p.x, 0, p.z))
			if absf(l.x) <= half.x and absf(l.z) <= half.y:
				astar.set_point_solid(ci, true)


func _free_near(ci: Vector2i, rmax := 8) -> Vector2i:
	if _okc(ci) and not astar.is_point_solid(ci):
		return ci
	for r in range(1, rmax + 1):
		for dx in range(-r, r + 1):
			for dy in [-r, r]:
				for q in [Vector2i(ci.x + dx, ci.y + dy), Vector2i(ci.x + dy, ci.y + dx)]:
					if _okc(q) and not astar.is_point_solid(q):
						return q
	return Vector2i(-1, -1)


func _los(a: Vector3, b: Vector3) -> bool:
	var d := a.distance_to(b)
	var n := maxi(1, int(d / (CS * 0.5)))
	for i in n + 1:
		var ci := _cell(a.lerp(b, float(i) / float(n)))
		if not _okc(ci) or astar.is_point_solid(ci):
			return false
	return true


func path(from: Vector3, to: Vector3) -> Array:
	## yo'l: [Vector3...] (bo'sh - yo'l yo'q)
	if N == 0:
		return [to]
	var a := _free_near(_cell(from))
	var b := _free_near(_cell(to))
	if a.x < 0 or b.x < 0:
		return []
	var ids: Array = astar.get_id_path(a, b)
	if ids.is_empty():
		return []
	var pts: Array = []
	for ci in ids:
		pts.append(_world(ci))
	pts[pts.size() - 1] = Vector3(to.x, 0, to.z) if not astar.is_point_solid(_cell(to)) else pts[pts.size() - 1]
	# yo'lni tekislash: ko'rinib turgan eng uzoq nuqtaga to'g'ri boriladi
	var out: Array = [Vector3(from.x, 0, from.z)]
	var i := 0
	while i < pts.size() - 1:
		var j := mini(pts.size() - 1, i + 40)
		while j > i + 1 and not _los(out[out.size() - 1], pts[j]):
			j -= 1
		out.append(pts[j])
		i = j
	if out.size() == 1:
		out.append(pts[pts.size() - 1])
	out.remove_at(0)
	return out


# ================================================================ tanlash

func units() -> Array:
	var res: Array = []
	for n in c._all_figs():
		var nd: Node3D = n
		if nd.visible and nd.get_meta("kind", "") != "top":
			res.append(nd)
	return res


func pick(screen: Vector2) -> Node3D:
	var best: Node3D = null
	var bd := 26.0
	for n in units():
		var nd: Node3D = n
		var p := nd.global_position + Vector3(0, 1.0, 0)
		if c.cam.is_position_behind(p):
			continue
		var d: float = c.cam.unproject_position(p).distance_to(screen)
		if d < bd:
			bd = d
			best = nd
	return best


func select_list(list: Array, add := false) -> void:
	if not add:
		for n in sel:
			_ring(n, false)
		sel.clear()
	for n in list:
		if not sel.has(n):
			sel.append(n)
			_ring(n, true)
	aim_mode = false
	_refresh_ui()


func clear_sel() -> void:
	select_list([])


func _ring(n: Node3D, on: bool) -> void:
	if not is_instance_valid(n):
		return
	var r: Node3D = n.get_node_or_null("SelRing")
	if on and r == null:
		var mi := MeshInstance3D.new()
		mi.name = "SelRing"
		var tm := TorusMesh.new()
		var big := 1.6 if n.get_meta("kind", "") in ["otliq", "fil", "arava"] else 1.0
		tm.inner_radius = 0.48 * big
		tm.outer_radius = 0.6 * big
		mi.mesh = tm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.4, 1.0, 0.45)
		mi.material_override = m
		mi.position.y = 0.06
		mi.scale = Vector3(1, 0.15, 1)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(mi)
	elif not on and r != null:
		r.queue_free()


func box_select(a: Vector2, b: Vector2, add: bool) -> void:
	var r := Rect2(a, Vector2.ZERO).expand(b)
	var list: Array = []
	for n in units():
		var nd: Node3D = n
		var p := nd.global_position + Vector3(0, 1.0, 0)
		if c.cam.is_position_behind(p):
			continue
		if r.has_point(c.cam.unproject_position(p)):
			list.append(nd)
	select_list(list, add)
	if not list.is_empty():
		c._msg("%d askar belgilandi - yerni bosib yurgizing" % sel.size())


# ================================================================ sichqoncha (castle3d dan)

func on_press(pos: Vector2) -> void:
	_box_from = pos


func on_drag(pos: Vector2) -> void:
	box_rect.visible = true
	var r := Rect2(_box_from, Vector2.ZERO).expand(pos)
	box_rect.position = r.position
	box_rect.size = r.size


func on_release(pos: Vector2, dragged: bool, shift: bool, double: bool) -> bool:
	## true - bosish RTS tomonidan ishlatildi
	box_rect.visible = false
	if dragged:
		box_select(_box_from, pos, shift)
		return true
	var u := pick(pos)
	if u != null:
		if double:
			var k: String = u.get_meta("kind", "")
			var same: Array = []
			for n in units():
				var p: Vector3 = (n as Node3D).global_position
				if (n as Node3D).get_meta("kind", "") == k and not c.cam.is_position_behind(p):
					var sp: Vector2 = c.cam.unproject_position(p)
					if c.vp.get_visible_rect().has_point(sp):
						same.append(n)
			select_list(same, shift)
		else:
			if shift and sel.has(u):
				sel.erase(u)
				_ring(u, false)
				_refresh_ui()
			else:
				select_list([u], shift)
		return true
	var gp: Vector3 = c._ground_at(pos)
	if gp == Vector3.INF:
		return true
	if aim_mode and not sel.is_empty():
		order_shoot(gp)
		return true
	if move_mode and not sel.is_empty():
		move_mode = false
		order_move(gp)
		return true
	# bino / ark / darvoza bosildi - pastda o'shaning paneli
	var bd: Dictionary = c.building_at(gp)
	if not bd.is_empty():
		c.open_ctx(bd["t"])
		return true
	if sel.is_empty():
		c.open_ctx("")
		return true
	order_move(gp)
	return true


var move_mode := false


func on_right_click(pos: Vector2) -> bool:
	if sel.is_empty():
		return false
	var gp: Vector3 = c._ground_at(pos)
	if aim_mode:
		order_shoot(gp)
	else:
		order_move(gp)
	return true


# ================================================================ buyruqlar

func _valid_sel() -> Array:
	var out: Array = []
	for n in sel:
		if is_instance_valid(n) and (n as Node3D).is_inside_tree():
			out.append(n)
	sel = out
	return out


func _center(list: Array) -> Vector3:
	var s := Vector3.ZERO
	for n in list:
		s += Vector3((n as Node3D).position.x, 0, (n as Node3D).position.z)
	return s / maxf(1.0, list.size())


func _yaw(d: Vector3) -> float:
	return atan2(-d.z, d.x)


func _slots(n: int, at: Vector3, fwd: Vector3, shape: String) -> Array:
	## saf joylari: "line" - keng qator, "square" - to'rtburchak, "ring" - halqa (tashqariga qarab)
	fwd = Vector3(fwd.x, 0, fwd.z).normalized()
	if fwd.length() < 0.1:
		fwd = Vector3(0, 0, 1)
	var right := Vector3(-fwd.z, 0, fwd.x)
	var res: Array = []
	if shape == "ring":
		var r := maxf(2.6, float(n) * 1.5 / TAU)
		for i in n:
			var a := TAU * float(i) / float(n)
			var dir := fwd.rotated(Vector3.UP, a)
			res.append([at + dir * r, _yaw(dir)])
		return res
	var w := mini(n, 14) if shape == "line" else maxi(1, int(ceil(sqrt(float(n)))))
	var face := _yaw(fwd)
	for i in n:
		var row := i / w
		var col := i % w
		var in_row := mini(w, n - row * w)
		var x := (float(col) - (in_row - 1) * 0.5) * 1.45
		res.append([at + right * x - fwd * float(row) * 1.7, face])
	return res


func order_move(gp: Vector3, shape := "") -> void:
	var list := _valid_sel()
	if list.is_empty():
		return
	var cen := _center(list)
	var fwd: Vector3 = gp - cen
	if fwd.length() < 1.0:
		fwd = -c.cam.global_transform.basis.z
	# toshbaqa bo'lib turgan guruh - toshbaqa holicha birga yuradi (qalqonlar tushmaydi)
	var tb := true
	for n in list:
		var r0 = (n as Node3D).get_meta("rts", null)
		if r0 == null or not str(r0["stance"]).begins_with("tb_"):
			tb = false
			break
	var sl: Array = _tb_slots(list.size(), Vector3(gp.x, 0, gp.z), fwd, false) if tb else _slots(list.size(), Vector3(gp.x, 0, gp.z), fwd, shape if shape != "" else ("square" if list.size() > 14 else "line"))
	# kim qaysi joyga: oldingi qatordagilar oldinga (yaqin joyga yaqin askar)
	var order := list.duplicate()
	order.sort_custom(func(a, b): return (a as Node3D).position.distance_to(gp) < (b as Node3D).position.distance_to(gp))
	var fails := 0
	# saf bo'lib yurish: butun guruh uchun bitta yo'l topiladi, har askar o'z joyi bilan unga parallel yuradi
	# (bitta ilondek qator bo'lib ketmaydi)
	var lead := path(cen, Vector3(gp.x, 0, gp.z))
	var grun := _plen(cen, lead) > 18.0 and not tb      # guruh bir xil tezlikda yuradi
	if tb:
		order = list.duplicate()
		order.sort_custom(func(a, b): return int((a as Node3D).get_meta("fidx", 0)) < int((b as Node3D).get_meta("fidx", 0)))
	for i in order.size():
		var nd: Node3D = order[i]
		var stc: String = ("tb_out" if sl[i][2] else "tb_in") if tb else "idle"
		if lead.size() <= 1 or nd.get_meta("onwall", false):
			if not _send(nd, sl[i][0], sl[i][1], stc):
				fails += 1
			continue
		var off: Vector3 = nd.position - cen
		off.y = 0
		off = off.limit_length(8.0)
		var pts: Array = []
		var prev := Vector3(nd.position.x, 0, nd.position.z)
		var ok := true
		for k in lead.size() - 1:
			var w: Vector3 = lead[k] + off * (1.0 - float(k + 1) / float(lead.size()))
			var ci := _cell(w)
			if not _okc(ci) or astar.is_point_solid(ci):
				w = lead[k]
			if not _los(prev, w):
				var sub := path(prev, w)
				if sub.is_empty():
					ok = false
					break
				pts += sub
			else:
				pts.append(w)
			prev = w
		if ok:
			if not _los(prev, sl[i][0]):
				var sub2 := path(prev, sl[i][0])
				if sub2.is_empty():
					ok = false
				else:
					pts += sub2
			else:
				pts.append(sl[i][0])
		if not ok:
			if not _send(nd, sl[i][0], sl[i][1], stc):
				fails += 1
			continue
		var keep_up: bool = tb and nd.get_meta("sp_up", false)
		_start(nd, [{"k": "walk", "pts": pts, "run": grun}, {"k": "face", "yaw": sl[i][1]}, {"k": "stance", "s": stc}])
		if tb:
			nd.set_meta("fidx", i)
			if keep_up:
				nd.set_meta("sp_up", true)
				ShieldPose.set_up(nd, true)
	if fails > 0:
		var outside: bool = c.stats.get("closed", false) and not c._inside(gp)
		if outside and not gates_open():
			c._msg("DARVOZA YOPIQ! Tashqariga chiqish uchun chapdagi panelda 'Darvozani ochish' tugmasini bosing.", true)
		else:
			c._msg("%d askar u yerga borolmaydi (devor yoki bino to'sib turibdi)" % fails, true)
	else:
		c._msg("%d askar yo'lga chiqdi" % list.size())
	Sfx.play("qadam", -18.0, 0.05, 0.5)


func _send(n: Node3D, to: Vector3, face: float, stance: String, extra_after: Array = []) -> bool:
	## askarni yo'l topib yurgizish; devorda bo'lsa avval minora orqali tushadi
	var steps: Array = []
	var start := n.position
	if n.get_meta("onwall", false):
		var dn := _descend_steps(n)
		steps += dn
		start = dn[dn.size() - 1].get("land", start) if not dn.is_empty() else start
	var pts := path(start, to)
	if pts.is_empty():
		if steps.is_empty():
			return false
		pts = []
	if not pts.is_empty():
		steps.append({"k": "walk", "pts": pts, "run": _plen(start, pts) > 14.0})
	steps.append({"k": "face", "yaw": face})
	steps.append({"k": "stance", "s": stance})
	steps += extra_after
	_start(n, steps)
	return true


func _plen(a: Vector3, pts: Array) -> float:
	var L := 0.0
	var p := a
	for q in pts:
		L += Vector2(q.x - p.x, q.z - p.z).length()
		p = q
	return L


func _start(n: Node3D, steps: Array) -> void:
	n.visible = true          # minora ichida (zinada) bo'lgan askar yangi buyruqda ko'rinmay qolib ketmasin
	if n.has_meta("sp_up"):
		n.remove_meta("sp_up")
		ShieldPose.set_up(n, false)
	n.set_meta("follow", false)
	if n.has_meta("tw"):
		var t = n.get_meta("tw")
		if t is Tween and (t as Tween).is_valid():
			(t as Tween).kill()
	n.set_meta("manual", true)
	n.set_meta("post", false)
	n.set_meta("rts", {"steps": steps, "i": 0, "anim": "", "t": 0.0, "stance": "", "target": Vector3.ZERO})


func release(n: Node3D) -> void:
	n.visible = true
	n.set_meta("manual", false)
	n.remove_meta("rts")


func order_stance(s: String) -> void:
	for n in _valid_sel():
		var nd: Node3D = n
		if not nd.has_meta("rts"):
			_start(nd, [])
		var r: Dictionary = nd.get_meta("rts")
		r["steps"] = []
		r["i"] = 0
		r["stance"] = s
		r["t"] = 0.0
		_apply_stance(nd, s)
	c._msg({"block": "Qalqonlar ko'tarildi - himoya holati", "attack": "Hujumga shay - qurollar ko'tarildi", "idle": "To'xtadi"}.get(s, ""))


func order_form(shape: String) -> void:
	var list := _valid_sel()
	if list.is_empty():
		return
	var cen := _center(list)
	var fwd: Vector3 = -c.cam.global_transform.basis.z
	var st := "block" if shape == "shield" else "idle"
	var sl := _slots(list.size(), cen, fwd, "line" if shape == "shield" else shape)
	var order := list.duplicate()
	if shape != "ring":
		order.sort_custom(func(a, b): return _kind_rank(a) < _kind_rank(b))
	for i in order.size():
		_send(order[i], sl[i][0], sl[i][1], st)
	c._msg({"line": "Qator bo'lib saflandi", "square": "To'rtburchak saf", "shield": "QALQON DEVORI: qalqonlar bir-biriga ulandi", "ring": "Halqa saf - har tomonga qarab himoya"}.get(shape, ""))


func _kind_rank(n) -> int:
	## oldinda nayzachi va qilichboz, orqada kamonchi, chetda otliq
	return {"nayzachi": 0, "qilichboz": 1, "sarboz": 1, "kamonchi": 2, "otliq": 3, "fil": 4, "arava": 4}.get((n as Node3D).get_meta("kind", ""), 2)


func order_guard() -> void:
	## qo'mondon atrofida halqa bo'lib uni himoya qiladi (qo'mondon yursa - ergashadi)
	if c.cmdr == null or not is_instance_valid(c.cmdr):
		c._msg("Qo'mondon yo'q", true)
		return
	var list := _valid_sel()
	var at: Vector3 = c.cmdr.position
	var sl := _slots(list.size(), Vector3(at.x, 0, at.z), Vector3(0, 0, 1), "ring")
	for i in list.size():
		_send(list[i], sl[i][0], sl[i][1], "guard")
		(list[i] as Node3D).set_meta("follow", true)
		(list[i] as Node3D).set_meta("fidx", i)
		(list[i] as Node3D).set_meta("fshape", "ring")
	_guard_from = at
	c._msg("%d askar qo'mondonni o'rab, himoya qilmoqda" % list.size())


var _guard_from := Vector3.ZERO


func _tb_slots(n: int, at: Vector3, fwd: Vector3, hole: bool) -> Array:
	## toshbaqa: zich to'rtburchak. [joy, yuz burchagi, chetdami]. hole - o'rtada qo'mondon uchun joy
	fwd = Vector3(fwd.x, 0, fwd.z).normalized()
	if fwd.length() < 0.1:
		fwd = Vector3(0, 0, 1)
	var right := Vector3(-fwd.z, 0, fwd.x)
	var cols := maxi(2, int(ceil(sqrt(float(n + (1 if hole else 0))))))
	var rows := int(ceil(float(n + (1 if hole else 0)) / cols))
	if hole and cols % 2 == 0:
		cols += 1
		rows = int(ceil(float(n + 1) / cols))
	if hole and rows < 3:
		rows = 3
	var sp := tb_gap         # jips (1.08) - qalqonlar chetma-chet; oddiy 1.3; tarqoq 1.8
	var res: Array = []
	var cr := rows / 2
	var cc := cols / 2
	for r in rows:
		for col in cols:
			if hole and r == cr and col == cc:
				continue
			var pos := at + fwd * ((float(rows - 1) * 0.5 - r) * sp) + right * ((col - (cols - 1) * 0.5) * sp)
			var outer := r == 0 or col == 0 or col == cols - 1 or r == rows - 1
			var face := fwd
			if r == 0:
				face = fwd
			elif r == rows - 1:
				face = -fwd
			elif col == 0:
				face = -right
			elif col == cols - 1:
				face = right
			res.append([pos, _yaw(face), outer])
	# chet joylarni avval to'ldiramiz (askar kam bo'lsa ham atrof yopiq bo'lsin)
	res.sort_custom(func(a, b): return int(a[2]) > int(b[2]))
	return res.slice(0, n)


var tb_gap := 1.3


func testudo_gap(g: float) -> void:
	## toshbaqa safini jipslash / tarqatish (belgilangan askarlar qayta saflanadi)
	tb_gap = g
	var list := _valid_sel()
	if list.is_empty():
		c._msg("Avval askarlarni belgilang", true)
		return
	var around := false
	for n in list:
		if (n as Node3D).get_meta("follow", false):
			around = true
	order_testudo(around, list)


func order_testudo(around_cmd := false, list: Array = []) -> void:
	## "QALQON!" - askarlar zich to'planib qalqonlarni boshi ustiga va atrofga ko'taradi
	if list.is_empty():
		list = _valid_sel()
	var inf: Array = list.filter(func(x): return (x as Node3D).get_meta("kind", "") in ["nayzachi", "qilichboz", "sarboz"])
	if inf.is_empty():
		c._msg("Qalqonli askar (nayzachi, qilichboz) yo'q", true)
		return
	var at := _center(inf)
	var fwd: Vector3 = -c.cam.global_transform.basis.z
	var cm_ok: bool = around_cmd and c.cmdr != null and is_instance_valid(c.cmdr)
	if cm_ok:
		at = Vector3(c.cmdr.position.x, 0, c.cmdr.position.z)
		fwd = Vector3(cos(c.cmdr.rotation.y), 0, -sin(c.cmdr.rotation.y))
	var sl := _tb_slots(inf.size(), at, fwd, cm_ok)
	var order := inf.duplicate()
	order.sort_custom(func(a, b): return (a as Node3D).position.distance_to(at) < (b as Node3D).position.distance_to(at))
	# eng yaqin askar - chetdagi joyga
	for i in order.size():
		var nd: Node3D = order[i]
		_send(nd, sl[i][0], sl[i][1], "tb_out" if sl[i][2] else "tb_in")
		nd.set_meta("follow", cm_ok)
		nd.set_meta("fidx", i)
		nd.set_meta("fshape", "testudo")
	_guard_from = at
	Sfx.play("qalqon", -6.0, 0.05, 0.3)
	c._msg("QALQON! %d askar toshbaqa bo'lib qalqonlarni ko'tardi%s" % [inf.size(), " - qo'mondonni o'rab oldi" if cm_ok else ""])


func near_cmd(r: float, kinds: Array) -> Array:
	var out: Array = []
	if c.cmdr == null or not is_instance_valid(c.cmdr):
		return out
	for n in units():
		var nd: Node3D = n
		if nd.position.distance_to(c.cmdr.position) < r and (kinds.is_empty() or nd.get_meta("kind", "") in kinds) and not nd.get_meta("onwall", false):
			out.append(nd)
	return out


func order_charge(list: Array) -> void:
	## "OLG'A!" - qo'mondon qaragan tomonga yugurib hujumga
	if c.cmdr == null or list.is_empty():
		return
	var fwd := Vector3(cos(c.cmdr.rotation.y), 0, -sin(c.cmdr.rotation.y))
	var at: Vector3 = c.cmdr.position + fwd * 16.0
	var sl := _slots(list.size(), Vector3(at.x, 0, at.z), fwd, "line")
	for i in list.size():
		_send(list[i], sl[i][0], sl[i][1], "attack")
	c._msg("OLG'A! %d askar hujumga tashlandi" % list.size())


func order_follow(list: Array) -> void:
	## "ORTIMDAN!" - askarlar qo'mondon atrofida halqa bo'lib unga ergashadi
	if c.cmdr == null or list.is_empty():
		return
	sel = list
	order_guard()
	for i in list.size():
		(list[i] as Node3D).set_meta("fshape", "ring")


func order_aim() -> void:
	var has_arch := false
	for n in _valid_sel():
		if (n as Node3D).get_meta("kind", "") in ["kamonchi", "sarboz"]:
			has_arch = true
	if not has_arch:
		c._msg("Belgilanganlar orasida kamonchi yo'q", true)
		return
	aim_mode = true
	c._msg("NISHON: kamonchilar o'q uzadigan joyni bosing")


func order_shoot(gp: Vector3) -> void:
	aim_mode = false
	var n_ok := 0
	for n in _valid_sel():
		var nd: Node3D = n
		if not nd.get_meta("kind", "") in ["kamonchi", "sarboz"]:
			continue
		if not nd.has_meta("rts"):
			_start(nd, [])
		var r: Dictionary = nd.get_meta("rts")
		r["steps"] = []
		r["i"] = 0
		r["stance"] = "shoot"
		r["target"] = gp
		r["t"] = _rng.randf_range(0.0, 1.5)
		nd.rotation.y = _yaw(gp - nd.position)
		Unit3D.play(nd, "Block")
		n_ok += 1
	c._msg("%d kamonchi nishonga qarab o'q uzmoqda" % n_ok)


func order_home() -> void:
	## joyiga qaytish: hovlidagi saf joyiga (yoki vazifasiga) qaytadi
	var fwd: Vector3 = c._muster_dir()
	var face := _yaw(fwd)
	for n in _valid_sel():
		var nd: Node3D = n
		if nd.has_meta("slot"):
			_send(nd, nd.get_meta("slot"), face, "idle", [{"k": "release"}])
		else:
			release(nd)
	c._msg("Askarlar saf joyiga qaytmoqda")


func order_wall() -> void:
	## devorga chiqish: minora tagidagi eshik -> minora ichi -> devor yo'lagi
	var posts: Array = c._wall_posts()
	if posts.is_empty():
		c._msg("Devor yo'q - avval devor quring", true)
		return
	var taken := {}
	for n in c._all_figs():
		if (n as Node3D).get_meta("onwall", false) or (n as Node3D).get_meta("post", false):
			taken[_key((n as Node3D).get_meta("wallpos", (n as Node3D).position))] = true
	var sent := 0
	for n in _valid_sel():
		var nd: Node3D = n
		if nd.get_meta("kind", "") in ["otliq", "fil", "arava", "top"]:
			continue
		var best := -1
		var bd := 1e9
		for i in posts.size():
			if taken.has(_key(posts[i][0])):
				continue
			var d: float = (posts[i][0] as Vector3).distance_to(nd.position)
			if d < bd:
				bd = d
				best = i
		if best < 0:
			break
		taken[_key(posts[best][0])] = true
		var post: Vector3 = posts[best][0]
		var steps := _climb_steps(nd, post, float(posts[best][1]))
		if steps.is_empty():
			continue
		_start(nd, steps)
		sent += 1
	if sent == 0:
		c._msg("Devorda bo'sh joy yo'q yoki minoraga yo'l topilmadi", true)
	else:
		c._msg("%d askar minora orqali devorga chiqmoqda" % sent)


func _key(p: Vector3) -> String:
	return "%d_%d" % [int(round(p.x)), int(round(p.z))]


func _tower_for(p: Vector3) -> Vector3:
	var best := Vector3.INF
	var bd := 1e9
	for t in c.data["towers"]:
		var tp: Vector3 = c._v(t["p"])
		var d := tp.distance_to(Vector3(p.x, 0, p.z))
		if d < bd:
			bd = d
			best = tp
	return best


func tower_door(tp: Vector3) -> Vector3:
	## minora eshigi - ichki hovli tomonda
	var dir: Vector3 = (c._keep() - tp)
	dir.y = 0
	dir = dir.normalized() if dir.length() > 0.1 else Vector3(0, 0, 1)
	return tp + dir * 5.0


func _access(p: Vector3) -> Dictionary:
	## devorga chiqish joyi: eng yaqin minora yoki darvoza (darvoza minorasidagi zina). {} - yo'q
	var best := {}
	var bd := 1e9
	var q := Vector3(p.x, 0, p.z)
	for t in c.data["towers"]:
		var tp: Vector3 = c._v(t["p"])
		var d := tp.distance_to(q)
		if d < bd:
			bd = d
			var edge := tp + (q - tp).normalized() * 4.4 if (q - tp).length() > 0.1 else tp
			edge.y = c.WALL_H + 0.05
			best = {"door": tower_door(tp), "edge": edge}
	for g in c.data["gates"]:
		var gp: Vector3 = c._v(g["p"])
		var d2 := gp.distance_to(q)
		if d2 < bd:
			bd = d2
			var ang := float(g["ang"])
			var outer := Vector3(sin(ang), 0, cos(ang))
			var along := Vector3(cos(ang), 0, -sin(ang))
			var sg := 1.0 if along.dot(q - gp) >= 0.0 else -1.0
			var edge2 := gp + along * sg * 5.6
			edge2.y = c.WALL_H + 0.05
			best = {"door": gp - outer * 4.5 + along * sg * 2.6, "edge": edge2}
	return best


func _climb_steps(nd: Node3D, post: Vector3, yaw: float) -> Array:
	var steps: Array = []
	var start := nd.position
	if nd.get_meta("onwall", false):
		var dn := _descend_steps(nd)
		steps += dn
		start = dn[dn.size() - 1].get("land", start) if not dn.is_empty() else start
	var ac := _access(post)
	if ac.is_empty():
		# minora yo'q - devor tagidagi narvon/zinadan chiqadi
		var foot: Vector3 = Vector3(post.x, 0, post.z) + (c._keep() - Vector3(post.x, 0, post.z)).normalized() * 2.6
		var p0 := path(start, foot)
		if p0.is_empty():
			return []
		steps.append({"k": "walk", "pts": p0, "run": _plen(start, p0) > 14.0})
		steps.append({"k": "hide", "t": 0.8, "to": post})
	else:
		var p1 := path(start, ac["door"])
		if p1.is_empty():
			return []
		steps.append({"k": "walk", "pts": p1, "run": _plen(start, p1) > 14.0})
		steps.append({"k": "hide", "t": 1.0, "to": ac["edge"]})          # minora/darvoza ichidagi zinadan ko'tariladi
		steps.append({"k": "walk", "pts": [post], "run": true, "wall": true})
	steps.append({"k": "face", "yaw": yaw})
	steps.append({"k": "onwall", "pos": post})
	steps.append({"k": "stance", "s": "idle"})
	return steps


func _descend_steps(nd: Node3D) -> Array:
	var ac := _access(nd.position)
	if ac.is_empty():
		var down: Vector3 = Vector3(nd.position.x, 0, nd.position.z) + (c._keep() - Vector3(nd.position.x, 0, nd.position.z)).normalized() * 2.6
		return [{"k": "hide", "t": 0.8, "to": down, "land": down, "off": true}]
	return [{"k": "walk", "pts": [ac["edge"]], "run": true, "wall": true},
		{"k": "hide", "t": 1.0, "to": ac["door"], "land": ac["door"], "off": true}]


func toggle_gate() -> void:
	c.data["gate_open"] = not gates_open()
	rebuild_nav()
	c.animate_gates()
	Sfx.play("taran", -16.0, 0.1, 0.5)
	c._msg("Darvoza OCHILDI - askarlar tashqariga chiqa oladi" if gates_open() else "Darvoza YOPILDI - qal'adan chiqib bo'lmaydi")
	_refresh_ui()


# ================================================================ har kadr

func update(delta: float) -> void:
	for n in c._all_figs():
		var nd: Node3D = n
		if nd.has_meta("rts"):
			_step(nd, delta)
	_update_arrows(delta)
	# qo'mondonni qo'riqlovchilar unga ergashadi
	_guard_t -= delta
	if _guard_t <= 0.0:
		_guard_t = 0.8
		if c.cmdr != null and is_instance_valid(c.cmdr) and c.cmdr.position.distance_to(_guard_from) > 2.5:
			for shape in ["ring", "testudo"]:
				var gl: Array = []
				for n in c._all_figs():
					var nd: Node3D = n
					if nd.get_meta("follow", false) and nd.get_meta("fshape", "") == shape and nd.has_meta("rts"):
						gl.append(nd)
				if gl.is_empty():
					continue
				gl.sort_custom(func(a, b): return int((a as Node3D).get_meta("fidx", 0)) < int((b as Node3D).get_meta("fidx", 0)))
				var at := Vector3(c.cmdr.position.x, 0, c.cmdr.position.z)
				var fwd := Vector3(cos(c.cmdr.rotation.y), 0, -sin(c.cmdr.rotation.y))
				var sl: Array = _slots(gl.size(), at, Vector3(0, 0, 1), "ring") if shape == "ring" else _tb_slots(gl.size(), at, fwd, true)
				for k in gl.size():
					var nd2: Node3D = gl[k]
					var pts := path(nd2.position, sl[k][0])
					if pts.is_empty():
						continue
					var r2: Dictionary = nd2.get_meta("rts")
					var st: String = r2["stance"] if shape == "ring" else ("tb_out" if sl[k][2] else "tb_in")
					r2["steps"] = [{"k": "walk", "pts": pts, "run": shape == "ring" and _plen(nd2.position, pts) > 6.0}, {"k": "face", "yaw": sl[k][1]}, {"k": "stance", "s": st}]
					r2["i"] = 0
			_guard_from = c.cmdr.position


func _play(nd: Node3D, r: Dictionary, a: String) -> void:
	if r["anim"] == a:
		return
	r["anim"] = a
	var rd := Unit3D.rider_of(nd)
	if rd:
		Unit3D.play(nd, {"Run": "Gallop", "Walk": "Walk", "Idle": "Idle"}.get(a, "Idle"))
		Unit3D.play(rd, "Ride")
	else:
		Unit3D.play(nd, a)


func _step(nd: Node3D, delta: float) -> void:
	var r: Dictionary = nd.get_meta("rts")
	var steps: Array = r["steps"]
	if r["i"] >= steps.size():
		_stance_tick(nd, r, delta)
		return
	var s: Dictionary = steps[r["i"]]
	match s["k"]:
		"walk":
			var pts: Array = s["pts"]
			if pts.is_empty():
				r["i"] += 1
				return
			var tgt: Vector3 = pts[0]
			var y: float = (c.WALL_H + 0.05) if s.get("wall", false) else 0.0
			var cur := Vector3(nd.position.x, y, nd.position.z)
			var d := Vector3(tgt.x, y, tgt.z) - cur
			var horse: bool = nd.get_meta("kind", "") in ["otliq", "fil", "arava"]
			var sp := (RUN_SP if s.get("run", false) else WALK_SP) * (1.9 if horse else 1.0) * (0.8 if nd.get_meta("sp_up", false) else 1.0)
			var stepd := sp * delta
			if d.length() <= stepd:
				nd.position = Vector3(tgt.x, y, tgt.z)
				pts.remove_at(0)
			else:
				nd.position = cur + d.normalized() * stepd
				nd.rotation.y = lerp_angle(nd.rotation.y, _yaw(d), minf(1.0, delta * 10.0))
			_play(nd, r, "Run" if s.get("run", false) else "Walk")
		"hide":
			# minora ichiga kirib zinadan chiqadi / tushadi
			if r["t"] <= 0.0:
				nd.visible = false
			r["t"] += delta
			if r["t"] >= float(s["t"]):
				r["t"] = 0.0
				nd.position = s["to"]
				nd.visible = true
				if s.get("off", false):
					nd.set_meta("onwall", false)
				r["i"] += 1
		"face":
			nd.rotation.y = float(s["yaw"])
			r["i"] += 1
		"onwall":
			nd.set_meta("onwall", true)
			nd.set_meta("wallpos", s["pos"])
			r["i"] += 1
		"stance":
			r["stance"] = s["s"]
			r["t"] = 0.0
			r["anim"] = ""
			_apply_stance(nd, s["s"])
			r["i"] += 1
		"release":
			release(nd)
		_:
			r["i"] += 1


func _apply_stance(nd: Node3D, s: String) -> void:
	var rd := Unit3D.rider_of(nd)
	if s == "tb_in":
		Unit3D.play(nd, "Idle")
		nd.set_meta("sp_up", true)
		ShieldPose.set_up(nd, true)
		return
	if s == "tb_out":
		Unit3D.play(nd, "Idle")            # chetdagilar ham tik turadi, qalqon ko'krak oldida (hammasi bir xil)
		if nd.has_meta("sp_up"):
			nd.remove_meta("sp_up")
			ShieldPose.set_up(nd, false)
		return
	match s:
		"block", "guard":
			if rd:
				Unit3D.play(nd, "Idle")
				Unit3D.play(rd, "Ride")
			else:
				Unit3D.play(nd, "Block")
		"attack":
			if rd:
				Unit3D.play(rd, "RideAttack")
			else:
				Unit3D.play(nd, "Attack")
		_:
			Unit3D.play(nd, "Idle")
			if rd:
				Unit3D.play(rd, "Ride")


func _stance_tick(nd: Node3D, r: Dictionary, delta: float) -> void:
	match r["stance"]:
		"attack":
			r["t"] += delta
			if r["t"] > 1.4:
				r["t"] = _rng.randf_range(-0.3, 0.0)
				var rd := Unit3D.rider_of(nd)
				if rd:
					c._act(rd, "RideAttack")
				else:
					c._act(nd, "Attack")
		"shoot":
			r["t"] += delta
			var tgt: Vector3 = r["target"]
			nd.rotation.y = lerp_angle(nd.rotation.y, _yaw(tgt - nd.position), minf(1.0, delta * 6.0))
			if r["t"] > 2.6:
				r["t"] = _rng.randf_range(-0.4, 0.0)
				var gun: bool = nd.get_meta("kind", "") == "sarboz"
				c._act(nd, "Fire" if gun else "Attack")
				var from: Vector3 = nd.global_position + Vector3(0, 1.45, 0) + (tgt - nd.position).normalized() * 0.75
				var aim := tgt + Vector3(_rng.randf_range(-1.5, 1.5), 0, _rng.randf_range(-1.5, 1.5))
				get_tree().create_timer(0.2 if gun else 1.18).timeout.connect(func():
					if is_instance_valid(nd):
						_fire(from, aim, gun))


# ================================================================ mashq o'qlari

func _fire(from: Vector3, to: Vector3, gun: bool) -> void:
	if gun:
		Sfx.play("miltiq", -14.0, 0.08, 0.1)
		return
	Sfx.play("kamon", -12.0, 0.08, 0.06)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.012
	cm.bottom_radius = 0.012
	cm.height = 0.8
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#6b4a2a")
	mi.material_override = m
	c.world.add_child(mi)
	mi.position = from
	var d := from.distance_to(to)
	arrows.append({"n": mi, "a": from, "b": to, "t": 0.0, "dur": maxf(0.4, d / 40.0), "h": d * clampf(0.05 + d / 500.0, 0.06, 0.2)})


func _update_arrows(delta: float) -> void:
	for ar in arrows.duplicate():
		ar["t"] += delta
		var k: float = minf(1.0, ar["t"] / ar["dur"])
		var a: Vector3 = ar["a"]
		var b: Vector3 = ar["b"]
		var h: float = ar["h"]
		var p := a.lerp(b, k) + Vector3(0, h * 4.0 * k * (1.0 - k), 0)
		var k2 := minf(1.0, k + 0.02)
		var p2 := a.lerp(b, k2) + Vector3(0, h * 4.0 * k2 * (1.0 - k2), 0)
		var mi: MeshInstance3D = ar["n"]
		mi.position = p
		if p2.distance_to(p) > 0.001:
			mi.look_at(p2, Vector3.UP)
			mi.rotate_object_local(Vector3.RIGHT, PI / 2.0)
		if k >= 1.0:
			arrows.erase(ar)
			Sfx.play("oq_tegish", -18.0, 0.1, 0.08)
			get_tree().create_timer(3.0).timeout.connect(mi.queue_free)


# ================================================================ interfeys

func _build_ui() -> void:
	box_rect = Panel.new()
	box_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.4, 1.0, 0.45, 0.12)
	sb.border_color = Color(0.5, 1.0, 0.55, 0.9)
	sb.set_border_width_all(2)
	box_rect.add_theme_stylebox_override("panel", sb)
	box_rect.visible = false
	c.hud.add_child(box_rect)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.style(Color(0.05, 0.08, 0.12, 0.7), 12, Color(0.6, 0.8, 1.0, 0.22), 10))
	panel.visible = false
	c.hud.add_child(panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	panel.add_child(hb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	hb.add_child(v)
	info = UIKit.label("", 13, Color("#f3d58a"), true)
	info.custom_minimum_size = Vector2(250, 0)
	v.add_child(info)
	gate_btn = _btn(v, "", toggle_gate)
	gate_btn.visible = false
	# askar turlari: bosilsa - shu turdagi hammasi belgilanadi (qo'mondon rejimida ham)
	kinds_box = HFlowContainer.new()
	kinds_box.custom_minimum_size = Vector2(250, 0)
	v.add_child(kinds_box)
	cmd_box = HBoxContainer.new()
	cmd_box.add_theme_constant_override("separation", 12)
	hb.add_child(cmd_box)
	var g1 := _grid(cmd_box, "SAF")
	_btn(g1, "Qator", func(): order_form("line"))
	_btn(g1, "To'rtburchak", func(): order_form("square"))
	_btn(g1, "Qalqon devori", func(): order_form("shield"))
	_btn(g1, "Halqa", func(): order_form("ring"))
	_btn(g1, "TOSHBAQA", func(): order_testudo(false))
	_btn(g1, "Qo'mondon toshbaqada", func(): order_testudo(true))
	_btn(g1, "Jipslash", func(): testudo_gap(1.08))
	_btn(g1, "Tarqatish", func(): testudo_gap(1.8))
	var g2 := _grid(cmd_box, "HOLAT")
	_btn(g2, "Qalqon bilan himoya", func(): order_stance("block"))
	_btn(g2, "Hujumga shay", func(): order_stance("attack"))
	_btn(g2, "Qo'mondonni qo'riqla", order_guard)
	_btn(g2, "Nishonga o'q uz", order_aim)
	_btn(g2, "Ortimdan yur", func(): order_follow(_valid_sel()))
	_btn(g2, "Olg'a (hujum)", func(): order_charge(_valid_sel()))
	var g3 := _grid(cmd_box, "JOY")
	_btn(g3, "Shu yerga yur", func():
		move_mode = true
		c._msg("Boriladigan joyni bosing"))
	_btn(g3, "Devorga chiq", order_wall)
	_btn(g3, "To'xta", func(): order_stance("idle"))
	_btn(g3, "Safga qayt", order_home)
	_btn(g3, "Belgini olish", clear_sel)
	_refresh_ui()


var kinds_box: HFlowContainer
var _kinds_t := 0.0


var _kinds_sig := ""


func _refresh_kinds(force := true) -> void:
	if kinds_box == null:
		return
	var cnt := {}
	for n in units():
		var k: String = (n as Node3D).get_meta("kind", "")
		cnt[k] = int(cnt.get(k, 0)) + 1
	var sig := str(cnt)
	if not force and sig == _kinds_sig:
		return
	_kinds_sig = sig
	UIKit.clear(kinds_box)
	for k in cnt:
		var nm: String = str(CastleEco.units().get(k, {"name": k})["name"])
		var b := _btn(kinds_box, "%s (%d)" % [nm, cnt[k]], func():
			var lst: Array = units().filter(func(x): return (x as Node3D).get_meta("kind", "") == k)
			select_list(lst, Input.is_key_pressed(KEY_SHIFT)))
		b.custom_minimum_size = Vector2(118, 28)
	if not cnt.is_empty():
		_btn(kinds_box, "HAMMASI (%d)" % units().size(), func(): select_list(units())).custom_minimum_size = Vector2(118, 28)


func _grid(parent: Control, title: String) -> GridContainer:
	parent.add_child(UIKit.label(title, 12, Color("#c9b98a")))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	parent.add_child(g)
	return g


func _btn(parent: Control, t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(120, 30)
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _refresh_ui() -> void:
	if info == null:
		return
	_refresh_kinds()
	gate_btn.text = "Darvozani yopish" if gates_open() else "Darvozani ochish"
	gate_btn.visible = false
	var list := _valid_sel()
	cmd_box.visible = not list.is_empty()
	if list.is_empty():
		info.text = "ASKARLAR: turini tanlang (pastdagi tugmalar) yoki askarni bosing / ramka chizing."
		return
	var cnt := {}
	for n in list:
		var k: String = (n as Node3D).get_meta("kind", "")
		cnt[k] = int(cnt.get(k, 0)) + 1
	var parts: Array = []
	for k in cnt:
		parts.append("%d %s" % [cnt[k], str(CastleEco.units().get(k, {"name": k})["name"]).to_lower()])
	info.text = "BELGILANDI: %s" % ", ".join(parts)
