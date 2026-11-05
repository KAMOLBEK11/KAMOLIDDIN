extends Node
## 1-zamon 3D jangi: tog'li-tepalikli maydon, daryo (ikki kechuv bilan), archazorlar.
## Qo'shinlar bo'linmalarga ajralgan (nayzachi, qilichboz, kamonchi, otliq). Yuqoridan boshqariladi:
##   bo'linmani bosing -> tanlanadi; o'ng tugma yerga -> o'sha joyga yuradi; o'ng tugma dushmanga -> hujum.
## Kamonchilar uzoqdan o'q uzadi, otliqlar tez va zarbasi kuchli, nayzachilar otliqqa qarshi kuchli.
## Bo'linma ko'p askar yo'qotsa ruhi tushadi va qochadi. Daryodan faqat kechuvda tez o'tiladi.

signal closed

const W := 360.0
const H := 240.0
const GW := 120
const GH := 80
const MAX_FIGS := 110
const REG_SIZE := 14
const KIND_ORDER1 := ["nayzachi", "qilichboz", "kamonchi", "otliq"]
const KIND_ORDER2 := ["nayzachi", "sarboz", "top", "otliq"]
## 2-zamon: sarboz - fitilli miltiq (uzoq masofa, sekin o'qlash, nayza-shtik bilan yaqin jang); to'p - zambarak
const STAT2 := {
	"nayzachi": {"hp": 1.0, "dmg": 0.26, "reach": 2.2, "speed": 3.4, "cd": 1.1, "vs_cav": 2.0},
	"sarboz": {"hp": 1.0, "dmg": 0.22, "reach": 2.0, "speed": 3.4, "cd": 1.15, "vs_cav": 1.4, "range": 125.0, "shot": 6.2,
		"bullet": 0.6, "chance": 0.27, "fire": "Fire"},
	"top": {"hp": 3.5, "dmg": 0.0, "reach": 1.5, "speed": 1.4, "cd": 3.0, "vs_cav": 1.0, "range": 260.0, "shot": 8.5, "cannon": true},
	"otliq": {"hp": 1.7, "dmg": 0.42, "reach": 2.4, "speed": 8.5, "cd": 1.1, "vs_cav": 1.0},
}
const NAMES2 := {"nayzachi": "Nayzachilar", "sarboz": "Sarbozlar", "top": "To'plar", "otliq": "Otliqlar"}
var KIND_ORDER: Array = KIND_ORDER2 if Game.era == 2 else KIND_ORDER1
var STAT: Dictionary = STAT2 if Game.era == 2 else STAT1
var NAMES: Dictionary = NAMES2 if Game.era == 2 else NAMES1
const STAT1 := {
	"nayzachi": {"hp": 1.0, "dmg": 0.26, "reach": 2.2, "speed": 3.4, "cd": 1.1, "vs_cav": 2.0},
	"qilichboz": {"hp": 1.15, "dmg": 0.34, "reach": 1.6, "speed": 3.4, "cd": 1.0, "vs_cav": 1.0},
	"kamonchi": {"hp": 0.8, "dmg": 0.14, "reach": 1.6, "speed": 3.6, "cd": 1.2, "vs_cav": 1.0, "range": 78.0, "shot": 2.3},
	"otliq": {"hp": 1.7, "dmg": 0.42, "reach": 2.4, "speed": 8.5, "cd": 1.1, "vs_cav": 1.0},
}
const NAMES1 := {"nayzachi": "Nayzachilar", "qilichboz": "Qilichbozlar", "kamonchi": "Kamonchilar", "otliq": "Otliqlar"}

var army_id := -1
var prov_id := ""
var castle_country := ""      # qal'a egasi - qal'a uslubi shunga qarab (kreml, ritsar qal'asi, ...)
var player_attacking := true
var finished := false
var player_won := false
var phase := "deploy"
var hud: Control
var vp: SubViewport
var world: Node3D
var cam: Camera3D
var cam_target := Vector3(W * 0.5, 0, H * 0.5)
var cam_dist := 210.0
var cam_yaw := 0.0
var _mid := false
var sim_speed := 1.0
var heights := PackedFloat32Array()
var figs: Array = []
var regs: Array = []
var arrows: Array = []
var sel := -1
var men_per_fig := 1.0
var start_eq := [0.0, 0.0]
var colors := [Color("#2f7d4a"), Color("#b8463a")]
var fac := ["temur", "temur"]      # tomonlar askar modellari (madaniyatga qarab: temur, arab, italiya)
var info_label: Label
var reg_box: VBoxContainer
var result_panel: PanelContainer
var result_label: Label
var start_btn: Button
var tip_label: Label
var _retarget := 0.0
var _ui_t := 0.0
var _rng := RandomNumberGenerator.new()
var _disc_mats := []
var _arrow_mesh: BoxMesh
var _arrow_mat: StandardMaterial3D
var _sel_mat: StandardMaterial3D
# ---- qo'mondon rejimi
var cmd := -1                # qo'mondon figurasi indeksi
var cmd_mode := false        # true - o'yinchi qo'mondonni o'zi boshqaradi (orqasidan kamera)
var cmd_weapon := "qilich"   # qilich | kamon | nayza
var cmd_mounted := true
var cmd_cd := 0.0
var cmd_cam_yaw := 0.0
var cmd_cam_dist := 7.0
var fps := true              # ko'z darajasidan ko'rish (ikki qo'l ko'rinadi); V - almashtirish
var fps_pitch := 0.0
var vm: Node3D               # ko'z oldidagi qo'llar va qurol
var vm_r: Node3D
var vm_l: Node3D
var vm_weapon: Node3D
var _bob := 0.0
const CMD_SCALE := 1.15
var _rmb := false
var _lmb := false
var _lmoved := false
var _lpress := Vector2.ZERO
var shout_cd := {"olga": 0.0, "turing": 0.0, "qalqon": 0.0, "yomgir": 0.0}
var shield_t := 0.0
var cmd_panel: PanelContainer
var cmd_label: Label
var cross: Label
var shout_label: Label3D
var cmd_btn: Button
var reg_panel: PanelContainer
# ---- qamal
var siege := false
var def_side := 1             # qal'ani himoya qilayotgan tomon (o'yinchi hujumida 1, dushman hujumida 0)
var att_side := 0
var spec := {}                # qal'a tavsifi (SiegeCastle)
var cs := {}                  # qal'a: x0 x1 z0 z1 cx cz gz, segs, gate
var engines: Array = []
var sel_eng := -1
var stones: Array = []
var climbed := 0
var _eng_mat: StandardMaterial3D
const SHOUTS := {
	"olga": {"key": "Q", "text": "OLG'A!", "cd": 14.0, "desc": "yaqin bo'linmalar hujumga, ruh +25"},
	"turing": {"key": "E", "text": "TURINGLAR!", "cd": 16.0, "desc": "qochganlar qaytadi, saf mustahkam, ruh +20"},
	"qalqon": {"key": "R", "text": "QALQON!", "cd": 18.0, "desc": "8 soniya zarba 40% kam o'tadi"},
	"yomgir": {"key": "G", "text": "O'Q YOMG'IRI!", "cd": 12.0, "desc": "hamma kamonchilar siz qaragan dushmanga otadi"},
}
var CMD_KIND: Dictionary = {"qilich": "qomondon", "kamon": "sarboz", "nayza": "nayzachi"} if Game.era == 2 else {"qilich": "qilichboz", "kamon": "kamonchi", "nayza": "nayzachi"}
var CMD_KIND_RIDE: Dictionary = {"qilich": "otliq", "kamon": "otliq", "nayza": "otliq"} if Game.era == 2 else {"qilich": "otliq", "kamon": "kamonchi", "nayza": "nayzachi"}


func _ranged(k: String) -> bool:
	return STAT.has(k) and STAT[k].has("range")


func _ratio(siege_def: bool, siege_att: bool) -> Dictionary:
	## AI qo'shini tarkibi
	if Game.era == 2:
		if siege_def:
			return {"nayzachi": 0.25, "sarboz": 0.6, "top": 0.15, "otliq": 0.0}
		if siege_att:
			return {"nayzachi": 0.3, "sarboz": 0.55, "top": 0.1, "otliq": 0.05}
		return {"nayzachi": 0.25, "sarboz": 0.5, "top": 0.1, "otliq": 0.15}
	if siege_def:
		return {"nayzachi": 0.3, "qilichboz": 0.3, "kamonchi": 0.4, "otliq": 0.0}
	if siege_att:
		return {"nayzachi": 0.4, "qilichboz": 0.35, "kamonchi": 0.2, "otliq": 0.05}
	return {"nayzachi": 0.35, "qilichboz": 0.3, "kamonchi": 0.25, "otliq": 0.1}


# ================================================================ tayyorlash

func setup(aid: int) -> void:
	army_id = aid
	var a := War.get_army(aid)
	prov_id = a["at"]
	var p: Dictionary = Game.provinces[prov_id]
	player_attacking = a["owner"] == Game.PLAYER
	_rng.seed = hash(prov_id) + Game.day
	var mine_eq: float
	var them_eq: float
	if player_attacking:
		mine_eq = a["soldiers"] + a.get("tanks", 0.0) * 2.0
		them_eq = p["defense"]
		colors[1] = Color(Game.countries[p["owner"] if Game.countries.has(p["owner"]) else p["country"]]["color"])
	else:
		mine_eq = p["units"]["soldier"] + p.get("militia", 0.0)
		them_eq = a["soldiers"] + a.get("tanks", 0.0) * 2.0
		var oc: String = a["owner"]
		colors[1] = Color(Game.countries[oc]["color"]) if Game.countries.has(oc) else Color("#b8463a")
	var pc: String = Game.provinces[Game.player_provinces()[0]]["country"] if not Game.player_provinces().is_empty() else "TIM"
	colors[0] = Color(Game.countries[pc]["color"]) if Game.countries.has(pc) else Color("#2f7d4a")
	# ikki tomon rangi bir-biriga o'xshasa (masalan ikkalasi yashil), dushman qizil bo'ladi
	var dh := absf(colors[0].h - colors[1].h)
	if minf(dh, 1.0 - dh) < 0.22:
		colors[1] = Color("#b8463a") if absf(colors[0].h - 0.0) > 0.1 else Color("#3a5ab8")
	start_eq = [mine_eq, them_eq]
	fac[0] = Unit3D.player_faction()
	fac[1] = Unit3D.faction_for(p["owner"] if Game.countries.has(p["owner"]) else p["country"]) if player_attacking else Unit3D.faction_for(a["owner"])
	men_per_fig = maxf(1.0, ceilf(maxf(mine_eq, them_eq) / MAX_FIGS))
	# hujum qilsangiz - dushman qal'asi qamali; dushman hujumida - o'zingiz qurgan qal'ani himoya qilasiz
	# (qal'angiz devor bilan to'liq o'ralmagan bo'lsa - ochiq maydon jangi)
	if player_attacking:
		siege = not p.get("no_castle", false)
		if siege:
			spec = SiegeCastle.ai_spec(prov_id)
	else:
		spec = SiegeCastle.player_spec(p)
		siege = not spec.is_empty()
		if siege:
			def_side = 0
			att_side = 1
	castle_country = (p["owner"] if Game.countries.has(p["owner"]) else p["country"]) if player_attacking else p["country"]
	if siege:
		var hx: float = spec["hx"]
		var hz: float = spec["hz"]
		cs = {"x0": W * 0.76 - hx, "x1": W * 0.76 + hx, "z0": H * 0.5 - hz, "z1": H * 0.5 + hz,
			"cx": W * 0.76, "cz": H * 0.5, "segs": [], "gate": -1, "moat": spec["moat"]}
	_build_hud()
	_build_world()
	_spawn_side(0, mine_eq, _player_ratio())
	_spawn_side(1, them_eq, _ratio(siege and def_side == 1, siege and att_side == 1))
	_auto_deploy()
	if siege:
		_build_castle()
		_siege_deploy()
		_spawn_engines()
	_spawn_commander()
	cam_target = Vector3(W * 0.36, 0, H * 0.5) if def_side != 0 or not siege else Vector3(W * 0.6, 0, H * 0.5)
	cam_dist = 150.0
	cam_yaw = -0.35
	_apply_cam()
	_refresh_ui()
	if siege:
		if player_attacking:
			tip_label.text = SiegeCastle.describe(spec, Game.spies > 0) + "  Qamal qurollarini va bo'linmalarni joylab, BOSHLASH ni bosing."
		else:
			tip_label.text = "QAMAL! Dushman qal'angizga bostirib kelmoqda: narvonlar, taran va manjaniqlar bilan. Kamonchilar devorda, piyodalar darvoza ortida. Taranni kamonchilar bilan yo'q qiling!"


func _player_ratio() -> Dictionary:
	var sum := {}
	for k in KIND_ORDER:
		sum[k] = 0.0
	var tot := 0.0
	for id in Game.player_provinces():
		var c: Dictionary = Game.provinces[id].get("castle", {})
		for k in c.get("army", {}):
			if not sum.has(k):
				continue
			var eq := float(c["army"][k]) * float(CastleEco.EQ.get(k, 1.0))
			sum[k] += eq
			tot += eq
	if tot < 1.0:
		return _ratio(false, false)
	for k in sum:
		sum[k] /= tot
	return sum


func _spawn_side(side: int, eq: float, ratio: Dictionary) -> void:
	var nfig := clampi(int(round(eq / men_per_fig)), 0, MAX_FIGS + 10)
	if eq >= 0.5 and nfig == 0:
		nfig = 1
	var counts := {}
	var left := nfig
	for k in KIND_ORDER:
		var w := int(CastleEco.EQ.get(k, 1.0))
		var c := int(round(nfig * float(ratio.get(k, 0.0)) / float(w)))
		c = mini(c, left / w)
		counts[k] = c
		left -= c * w
	counts[KIND_ORDER[1]] += maxi(0, left)
	for k in KIND_ORDER:
		var n: int = counts[k]
		while n > 0:
			var m := mini(n, REG_SIZE)
			n -= m
			var reg := {"id": regs.size(), "side": side, "kind": k, "figs": [], "anchor": Vector3.ZERO, "face": 0.0,
				"target": -1, "morale": 100.0, "routed": false, "order": "hold"}
			var lab := Label3D.new()
			lab.fixed_size = true
			lab.pixel_size = 0.0011
			lab.font_size = 22
			lab.outline_size = 8
			lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lab.no_depth_test = true
			lab.modulate = colors[side].lightened(0.45)
			world.add_child(lab)
			reg["label"] = lab
			regs.append(reg)
			for i in m:
				_make_fig(reg)


func _make_fig(reg: Dictionary) -> void:
	var k: String = reg["kind"]
	var col: Color = colors[reg["side"]]
	var node: Node3D = Unit3D.cavalry(fac[reg["side"]], "otliq", col) if k == "otliq" else Unit3D.soldier(fac[reg["side"]], k, col)
	if node == null:
		return
	world.add_child(node)
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.9 if k != "otliq" else 1.5
	if k == "top":
		cm.top_radius = 1.8
	cm.bottom_radius = cm.top_radius
	cm.height = 0.05
	disc.mesh = cm
	disc.material_override = _disc_mats[reg["side"]]
	disc.position.y = 0.08
	node.add_child(disc)
	var st: Dictionary = STAT[k]
	var f := {"node": node, "disc": disc, "reg": reg["id"], "side": reg["side"], "kind": k, "hp": float(st["hp"]),
		"alive": true, "pos": Vector3.ZERO, "cd": _rng.randf() * 1.0, "target": -1, "anim": "", "escaped": false}
	if reg["side"] == 0 and Game.era < 4:
		f["hp"] *= 1.0 + CastleEco.best_drill() / 200.0      # mashq qilgan askar chidamliroq
	f["i"] = figs.size()
	figs.append(f)
	reg["figs"].append(f["i"])


func _auto_deploy() -> void:
	## Boshlang'ich saf: oldinda nayzachi va qilichboz, orqada kamonchi, qanotlarda otliq
	for side in 2:
		var west := (side == att_side) if siege else (side == 0)
		var x_front := W * 0.22 if west else W * 0.78
		var dir := 1.0 if west else -1.0
		var lines := {"nayzachi": 0.0, "qilichboz": 0.0, "kamonchi": -22.0, "otliq": -14.0, "sarboz": 0.0, "top": -30.0}
		var placed := {"front": 0, "kamonchi": 0, "otliq": 0}
		var fronts: Array = []
		for r in regs:
			if r["side"] == side and (r["kind"] in ["nayzachi", "qilichboz"] or (r["kind"] == "sarboz")):
				fronts.append(r)
		var nf := fronts.size()
		for i in nf:
			var r: Dictionary = fronts[i]
			r["anchor"] = Vector3(x_front, 0, H * 0.5 + (i - (nf - 1) * 0.5) * 26.0)
		var archers: Array = regs.filter(func(r): return r["side"] == side and r["kind"] in ["kamonchi", "top"])
		for i in archers.size():
			archers[i]["anchor"] = Vector3(x_front + lines[archers[i]["kind"]] * dir, 0, H * 0.5 + (i - (archers.size() - 1) * 0.5) * 26.0)
		var cav: Array = regs.filter(func(r): return r["side"] == side and r["kind"] == "otliq")
		for i in cav.size():
			var s := -1.0 if i % 2 == 0 else 1.0
			cav[i]["anchor"] = Vector3(x_front + lines["otliq"] * dir, 0, H * 0.5 + s * (nf * 13.0 + 24.0 + (i / 2) * 22.0))
		for r in regs:
			if r["side"] == side:
				r["face"] = 0.0 if west else PI
				r["anchor"].z = clampf(r["anchor"].z, 14.0, H - 14.0)
				_place_reg(r, true)


func _spawn_commander() -> void:
	var c_at := Vector3(W * 0.22 - 34.0, 0, H * 0.5) if not (siege and def_side == 0) else Vector3(cs["cx"] + 4.0, 0, cs["cz"] + 8.0)
	var reg := {"id": regs.size(), "side": 0, "kind": "otliq", "figs": [], "anchor": c_at, "face": 0.0 if def_side != 0 or not siege else PI,
		"target": -1, "morale": 100.0, "routed": false, "order": "hold", "title": "QO'MONDON"}
	var lab := Label3D.new()
	lab.fixed_size = true
	lab.pixel_size = 0.0013
	lab.font_size = 24
	lab.outline_size = 10
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.no_depth_test = true
	lab.modulate = Color("#ffd166")
	world.add_child(lab)
	reg["label"] = lab
	regs.append(reg)
	_make_fig(reg)
	cmd = reg["figs"][0]
	var f: Dictionary = figs[cmd]
	(f["node"] as Node3D).scale = Vector3.ONE * CMD_SCALE
	# qo'mondon yonida o'yinchi bayrog'i (hilpillaydi)
	var std := Unit3D.standard(colors[0], 4.2)
	std.position = Vector3(-0.6, 0.0, -0.5)
	std.name = "Standard"
	(f["node"] as Node3D).add_child(std)
	f["hp"] = 6.0
	f["cmd"] = true
	_place_reg(reg, true)
	shout_label = Label3D.new()
	shout_label.fixed_size = true
	shout_label.pixel_size = 0.0022
	shout_label.font_size = 40
	shout_label.outline_size = 14
	shout_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shout_label.no_depth_test = true
	shout_label.modulate = Color("#ffd166")
	shout_label.visible = false
	world.add_child(shout_label)


func _cmd_alive() -> bool:
	return cmd >= 0 and figs[cmd]["alive"]


func _cmd_swap() -> void:
	## qurol yoki otga minish o'zgarganda qo'mondon modelini almashtiradi
	var f: Dictionary = figs[cmd]
	var old: Node3D = f["node"]
	var col: Color = colors[0]
	var node: Node3D
	if cmd_mounted:
		node = Unit3D.cavalry(fac[0], CMD_KIND_RIDE[cmd_weapon], col)
		f["kind"] = "otliq"
	else:
		node = Unit3D.soldier(fac[0], CMD_KIND[cmd_weapon], col, true)
		f["kind"] = CMD_KIND[cmd_weapon]
	world.add_child(node)
	node.position = old.position
	node.rotation = old.rotation
	node.scale = Vector3.ONE * CMD_SCALE
	var disc: Node3D = f["disc"]
	disc.get_parent().remove_child(disc)
	node.add_child(disc)
	old.queue_free()
	f["node"] = node
	f["anim"] = ""
	_anim(f, "Idle")
	_build_vm()
	_fps_body()


func _toggle_cmd() -> void:
	if not _cmd_alive():
		tip_label.text = "Qo'mondon halok bo'lgan."
		return
	cmd_mode = not cmd_mode
	cmd_panel.visible = cmd_mode
	cross.visible = cmd_mode
	reg_panel.visible = not cmd_mode
	cmd_btn.text = "  Yuqoridan ko'rish (Tab)  " if cmd_mode else "  QO'MONDON BO'LISH (Tab)  "
	_fps_body()
	if cmd_mode:
		cmd_cam_yaw = (figs[cmd]["node"] as Node3D).rotation.y
		if vm == null:
			_build_vm()
		tip_label.text = "QO'MONDON: V - ko'z / orqadan ko'rish, W/S - yurish, A/D - burilish, Shift - tez, sichqoncha chap - zarba/otish, o'ng tugma bilan sudrash - atrofga qarash. 1/2/3 - qilich/kamon/nayza, F - otga minish/tushish. Chaqiriqlar: Q/E/R/G."
	else:
		_apply_cam()


func _cmd_control(delta: float) -> void:
	var f: Dictionary = figs[cmd]
	var node: Node3D = f["node"]
	var turn := 0.0
	if Input.is_key_pressed(KEY_A): turn += 1
	if Input.is_key_pressed(KEY_D): turn -= 1
	node.rotation.y += turn * (1.6 if cmd_mounted else 2.4) * delta
	var fwd := 0.0
	if Input.is_key_pressed(KEY_W): fwd += 1
	if Input.is_key_pressed(KEY_S): fwd -= 0.5
	var sprint := Input.is_key_pressed(KEY_SHIFT)
	var sp := (11.0 if sprint else 6.0) if cmd_mounted else (5.5 if sprint else 3.2)
	if fwd != 0.0:
		var dir := Vector3(cos(node.rotation.y), 0, -sin(node.rotation.y))
		var np: Vector3 = f["pos"] + dir * fwd * sp * delta
		if absf(np.x - river_x(np.z)) < 9.0 and not is_ford(np.z):
			np = f["pos"] + dir * fwd * sp * 0.3 * delta
		np.x = clampf(np.x, 2.0, W - 2.0)
		np.z = clampf(np.z, 2.0, H - 2.0)
		np.y = h_at(np.x, np.z)
		f["pos"] = np
		node.position = np
		f["charge"] = f.get("charge", 0.0) + delta if sprint and cmd_mounted else 0.0
		if f["anim"] != "Attack" or cmd_cd < 0.3:
			_anim(f, ("Run" if sprint else "Walk") if not cmd_mounted else ("Run" if sprint else "Walk"))
	elif cmd_cd <= 0.2 and f["anim"] in ["Run", "Walk", "Gallop"]:
		_anim(f, "Idle")
	cmd_cd -= delta
	if fps:
		_fps_cam(f, node, delta, fwd != 0.0)
		_refresh_cmd_hud()
		return
	# kamera orqada
	cmd_cam_yaw = lerp_angle(cmd_cam_yaw, node.rotation.y, 0.08) if not _rmb else cmd_cam_yaw
	var back := Vector3(-cos(cmd_cam_yaw), 0, sin(cmd_cam_yaw))
	var h := 4.2 if cmd_mounted else 3.2
	var cp: Vector3 = f["pos"] + back * cmd_cam_dist + Vector3(0, h, 0)
	cp.y = maxf(cp.y, h_at(cp.x, cp.z) + 1.5)
	cam.position = cam.position.lerp(cp, 0.25)
	cam.look_at(f["pos"] + Vector3(0, 2.2, 0) - back * 6.0, Vector3.UP)
	_refresh_cmd_hud()


func _cmd_attack() -> void:
	if cmd_cd > 0.0 or not _cmd_alive():
		return
	_vm_attack()
	var f: Dictionary = figs[cmd]
	var node: Node3D = f["node"]
	var fwd := Vector3(cos(node.rotation.y), 0, -sin(node.rotation.y))
	var rd := Unit3D.rider_of(node)
	if rd:
		Unit3D.play(rd, "RideAttack")
	else:
		_anim(f, "Attack", true)
	if cmd_weapon == "qilich":
		cmd_cd = 0.9
		var hits := 0
		for e in figs:
			if not e["alive"] or e["side"] == 0:
				continue
			var d: Vector3 = e["pos"] - f["pos"]
			d.y = 0
			if d.length() < (3.4 if cmd_mounted else 2.6) and d.normalized().dot(fwd) > 0.2:
				_hit(e, (1.4 if cmd_mounted and f.get("charge", 0.0) > 1.0 else 0.85) * _rng.randf_range(0.8, 1.2))
				hits += 1
				if hits >= 2:
					break
	else:
		# nishon: qaragan tomondagi eng yaqin dushman (ozgina avto-nishon)
		var rng := 110.0 if cmd_weapon == "kamon" else 40.0
		var best := -1
		var bd := 1e9
		for e in figs:
			if not e["alive"] or e["side"] == 0:
				continue
			var d: Vector3 = e["pos"] - f["pos"]
			d.y = 0
			var L := d.length()
			if L < rng and L > 1.0 and d.normalized().dot(fwd) > 0.93 and L < bd:
				bd = L
				best = e["i"]
		cmd_cd = 1.4 if cmd_weapon == "kamon" else 2.4
		var to: Vector3 = figs[best]["pos"] if best >= 0 else f["pos"] + fwd * rng * 0.7
		var a := MeshInstance3D.new()
		if cmd_weapon == "nayza":
			var bm := BoxMesh.new()
			bm.size = Vector3(2.4, 0.06, 0.06)
			a.mesh = bm
		else:
			a.mesh = _arrow_mesh
		a.material_override = _arrow_mat
		world.add_child(a)
		var from: Vector3 = f["pos"] + Vector3(0, 2.2 if cmd_mounted else 1.6, 0)
		var tgt := to + Vector3(0, 1.0, 0)
		arrows.append({"node": a, "from": from, "to": tgt, "t": 0.0, "dur": from.distance_to(tgt) / (55.0 if cmd_weapon == "kamon" else 30.0),
			"target": best, "chance": 0.85, "dmg": 1.2 if cmd_weapon == "kamon" else 1.8})


func _shout(k: String) -> void:
	if not _cmd_alive() or phase != "fight":
		return
	if shout_cd[k] > 0.0:
		tip_label.text = "%s hali tayyor emas (%d s)" % [SHOUTS[k]["text"], int(ceil(shout_cd[k]))]
		return
	shout_cd[k] = SHOUTS[k]["cd"]
	var c: Vector3 = figs[cmd]["pos"]
	shout_label.text = SHOUTS[k]["text"]
	shout_label.position = c + Vector3(0, 7.0, 0)
	shout_label.visible = true
	shout_label.modulate.a = 1.0
	var tw := shout_label.create_tween()
	tw.tween_property(shout_label, "position:y", c.y + 11.0, 1.8)
	tw.parallel().tween_property(shout_label, "modulate:a", 0.0, 1.8)
	var near: Array = []
	for r in regs:
		if r["side"] == 0 and r.get("title", "") == "" and _alive(r) > 0 and _center(r).distance_to(c) < 45.0:
			near.append(r)
	match k:
		"olga":
			for r in near:
				r["morale"] = minf(100.0, r["morale"] + 25.0)
				r["order"] = "attack"
				r["target"] = -1
			tip_label.text = "\"OLG'A!\" - %d bo'linma hujumga tashlandi!" % near.size()
		"turing":
			for r in near:
				r["morale"] = minf(100.0, r["morale"] + 20.0)
				if r["routed"]:
					r["routed"] = false
					r["morale"] = maxf(r["morale"], 55.0)
					r["anchor"] = _center(r)
				r["order"] = "hold"
			tip_label.text = "\"TURINGLAR!\" - %d bo'linma safni tikladi." % near.size()
		"qalqon":
			shield_t = 8.0
			for r in near:
				for fi in r["figs"]:
					if figs[fi]["alive"] and not _ranged(figs[fi]["kind"]) and figs[fi]["kind"] != "otliq":
						_anim(figs[fi], "Block", true)
			tip_label.text = "\"QALQON!\" - 8 soniya zarbalar kuchsiz o'tadi."
		"yomgir":
			var node: Node3D = figs[cmd]["node"]
			var aim: Vector3 = c + Vector3(cos(node.rotation.y), 0, -sin(node.rotation.y)) * 50.0
			var tr := -1
			var bd := 1e9
			for r in regs:
				if r["side"] == 1 and not r["routed"] and _alive(r) > 0:
					var d := _center(r).distance_to(aim)
					if d < bd:
						bd = d
						tr = r["id"]
			var n := 0
			for f in figs:
				if f["alive"] and f["side"] == 0 and _ranged(f["kind"]) and f["kind"] != "top" and not f.get("cmd", false) and tr >= 0:
					var tgt: Dictionary = figs[regs[tr]["figs"][_rng.randi() % regs[tr]["figs"].size()]]
					if tgt["alive"]:
						_shoot(f, tgt)
						n += 1
			tip_label.text = "\"O'Q YOMG'IRI!\" - %d ta o'q uchdi." % n


func _refresh_cmd_hud() -> void:
	if cmd_label == null or not _cmd_alive():
		return
	var f: Dictionary = figs[cmd]
	var lines: Array = []
	lines.append("QO'MONDON  -  jon: %d%%" % int(f["hp"] / 6.0 * 100.0))
	lines.append("Qurol: %s   (1 Qilich  2 Kamon  3 Nayza)" % {"qilich": "QILICH", "kamon": "KAMON", "nayza": "NAYZA"}[cmd_weapon])
	lines.append(("Otda" if cmd_mounted else "Piyoda") + "   (F - %s)" % ("otdan tushish" if cmd_mounted else "otga minish"))
	lines.append("Ko'rinish: %s   (V)" % ("KO'Z DARAJASI" if fps else "ORQADAN"))
	for k in SHOUTS:
		var cdv: float = shout_cd[k]
		lines.append("%s  %s  %s" % [SHOUTS[k]["key"], SHOUTS[k]["text"], ("tayyor" if cdv <= 0.0 else "%d s" % int(ceil(cdv)))])
	cmd_label.text = "\n".join(lines)


func _slot(r: Dictionary, idx: int) -> Vector3:
	var cols := 7
	var sp := 2.8 if r["kind"] == "otliq" else (4.5 if r["kind"] == "top" else 1.7)
	var row := idx / cols
	var col := idx % cols
	var fwd := Vector3(cos(r["face"]), 0, -sin(r["face"]))
	var right := Vector3(sin(r["face"]), 0, cos(r["face"]))
	return r["anchor"] - fwd * row * sp + right * (col - (cols - 1) * 0.5) * sp


func _place_reg(r: Dictionary, instant: bool) -> void:
	var i := 0
	for fi in r["figs"]:
		var f: Dictionary = figs[fi]
		if not f["alive"]:
			continue
		if instant:
			f["pos"] = _slot(r, i)
			f["pos"].y = h_at(f["pos"].x, f["pos"].z)
			(f["node"] as Node3D).position = f["pos"]
			(f["node"] as Node3D).rotation.y = r["face"]
			_anim(f, "Idle")
		i += 1


# ================================================================ maydon (relyef, daryo, o'rmon)

func river_x(z: float) -> float:
	return W * 0.52 + sin(z * 0.021) * 16.0 + sin(z * 0.05) * 5.0


func is_ford(z: float) -> bool:
	return absf(z - H * 0.27) < 11.0 or absf(z - H * 0.73) < 11.0


func _raw_h(x: float, z: float, n: FastNoiseLite, amp: float) -> float:
	var h := (n.get_noise_2d(x, z) * 0.5 + 0.5) * amp
	h += maxf(0.0, n.get_noise_2d(x * 0.4 + 300.0, z * 0.4)) * amp * 1.3
	# saf tortish zonalari tekisroq
	var flat := minf(smoothstep(W * 0.36, W * 0.12, x), 1.0) + minf(smoothstep(W * 0.64, W * 0.88, x), 1.0)
	h *= 1.0 - 0.65 * clampf(flat, 0.0, 1.0)
	# daryo o'zani
	var d := absf(x - river_x(z))
	var bed := -1.6 if is_ford(z) else -3.4
	h = lerpf(h, bed, smoothstep(13.0, 4.0, d))
	if not cs.is_empty():
		var ox := maxf(maxf(cs["x0"] - x, x - cs["x1"]), 0.0)
		var oz := maxf(maxf(cs["z0"] - z, z - cs["z1"]), 0.0)
		h = lerpf(1.0, h, smoothstep(4.0, 26.0, Vector2(ox, oz).length()))
	return h


func h_at(x: float, z: float) -> float:
	var gx := clampf(x / W * (GW - 1), 0.0, GW - 1.001)
	var gz := clampf(z / H * (GH - 1), 0.0, GH - 1.001)
	var ix := int(gx)
	var iz := int(gz)
	var fx := gx - ix
	var fz := gz - iz
	var a := heights[iz * GW + ix]
	var b := heights[iz * GW + ix + 1]
	var c := heights[(iz + 1) * GW + ix]
	var d := heights[(iz + 1) * GW + ix + 1]
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fz)


func _build_world() -> void:
	world = Node3D.new()
	vp.add_child(world)
	var p: Dictionary = Game.provinces[prov_id]
	var mount := Geo.mountain(p)
	world.add_child(FX.environment(false, Color("#6a6a40")))
	world.add_child(FX.sun(420.0))
	for side in 2:
		var dm := StandardMaterial3D.new()
		dm.albedo_color = colors[side].lightened(0.25)
		dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dm.albedo_color.a = 0.45
		_disc_mats.append(dm)
	_sel_mat = StandardMaterial3D.new()
	_sel_mat.albedo_color = Color(1.0, 0.85, 0.2, 0.9)
	_sel_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_sel_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var n := FastNoiseLite.new()
	n.seed = hash(prov_id) % 100000
	n.frequency = 0.009
	n.fractal_octaves = 4
	var amp := 3.0 + mount * 20.0
	heights.resize(GW * GH)
	for iz in GH:
		for ix in GW:
			heights[iz * GW + ix] = _raw_h(ix * W / (GW - 1), iz * H / (GH - 1), n, amp)
	# relyef mesh: rang - balandlik va qiyalikka qarab
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grass := Color("#46562a")
	var grass2 := Color("#5e6234")
	var rock := Color("#6e665a")
	var sand := Color("#8a7a58")
	for iz in GH:
		for ix in GW:
			var x := ix * W / (GW - 1)
			var z := iz * H / (GH - 1)
			var h := heights[iz * GW + ix]
			var hx := heights[iz * GW + mini(ix + 1, GW - 1)] - heights[iz * GW + maxi(ix - 1, 0)]
			var hz := heights[mini(iz + 1, GH - 1) * GW + ix] - heights[maxi(iz - 1, 0) * GW + ix]
			var slope := clampf(Vector2(hx, hz).length() / (2.0 * W / (GW - 1)), 0.0, 1.0)
			var c := grass.lerp(grass2, clampf(n.get_noise_2d(x * 3.0, z * 3.0) * 0.5 + 0.5, 0.0, 1.0))
			c = c.lerp(rock, smoothstep(0.25, 0.6, slope) + smoothstep(amp * 0.9, amp * 1.6, h) * 0.5)
			c = c.lerp(sand, smoothstep(0.2, -1.2, h))
			st.set_color(c)
			st.set_normal(Vector3(-hx, 2.0 * W / (GW - 1), -hz).normalized())
			st.add_vertex(Vector3(x, h, z))
	for iz in GH - 1:
		for ix in GW - 1:
			var i := iz * GW + ix
			st.add_index(i); st.add_index(i + 1); st.add_index(i + GW)
			st.add_index(i + 1); st.add_index(i + GW + 1); st.add_index(i + GW)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var gm := StandardMaterial3D.new()
	gm.vertex_color_use_as_albedo = true
	gm.roughness = 1.0
	gm.metallic_specular = 0.0
	mi.material_override = gm
	world.add_child(mi)
	# tashqi yer (maydondan tashqari)
	var outer := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(W * 6, H * 6)
	outer.mesh = pm
	var om := StandardMaterial3D.new()
	om.albedo_color = Color("#56603a")
	om.roughness = 1.0
	outer.material_override = om
	outer.position = Vector3(W * 0.5, -0.3, H * 0.5)
	world.add_child(outer)
	# daryo suvi
	var water := MeshInstance3D.new()
	var wst := SurfaceTool.new()
	wst.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for k in 61:
		var z := -20.0 + k * (H + 40.0) / 60.0
		var rx := river_x(z)
		wst.add_vertex(Vector3(rx - 11.0, -0.9, z))
		wst.add_vertex(Vector3(rx + 11.0, -0.9, z))
	water.mesh = wst.commit()
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.18, 0.36, 0.42, 0.82)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.08
	wm.metallic_specular = 0.9
	water.material_override = wm
	world.add_child(water)
	# kechuv belgilari (toshlar)
	for fz in [H * 0.27, H * 0.73]:
		var lab := Label3D.new()
		lab.text = "KECHUV"
		lab.font_size = 64
		lab.pixel_size = 0.05
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.modulate = Color(1, 1, 1, 0.75)
		lab.position = Vector3(river_x(fz), 6.0, fz)
		world.add_child(lab)
	# archazor va daraxtlar tepaliklarda
	var trees := ["pine1", "pine2", "pine1", "oak1"]
	for i in 140:
		var x := _rng.randf_range(-40, W + 40)
		var z := _rng.randf_range(-40, H + 40)
		var inside := x > 0 and x < W and z > 0 and z < H
		if inside:
			if absf(x - river_x(z)) < 16.0 or (x > W * 0.1 and x < W * 0.3) or (x > W * 0.7 and x < W * 0.9):
				continue
			if not cs.is_empty() and x > cs["x0"] - 30.0 and x < cs["x1"] + 30.0 and z > cs["z0"] - 30.0 and z < cs["z1"] + 30.0:
				continue
			if n.get_noise_2d(x * 1.7, z * 1.7) < 0.05 and _rng.randf() < 0.7:
				continue
		var path := "res://models/nature/%s.glb" % trees[i % trees.size()]
		if not ResourceLoader.exists(path):
			continue
		var t: Node3D = load(path).instantiate()
		var s := _rng.randf_range(2.2, 3.8)
		t.scale = Vector3(s, s, s)
		t.position = Vector3(x, h_at(x, z) if inside else -0.3, z)
		t.rotation.y = _rng.randf() * TAU
		world.add_child(t)
	_arrow_mesh = BoxMesh.new()
	_arrow_mesh.size = Vector3(0.9, 0.04, 0.04)
	_arrow_mat = StandardMaterial3D.new()
	_arrow_mat.albedo_color = Color("#3a2a18")
	cam = Camera3D.new()
	cam.fov = 50
	cam.far = 4000
	world.add_child(cam)


# ================================================================ kamera va kiritish

func _apply_cam() -> void:
	var pitch := deg_to_rad(lerpf(25.0, 60.0, clampf((cam_dist - 20.0) / 300.0, 0.0, 1.0)))
	var off := Vector3(sin(cam_yaw) * cos(pitch), sin(pitch), cos(cam_yaw) * cos(pitch)) * cam_dist
	var ty := h_at(cam_target.x, cam_target.z) if heights.size() > 0 else 0.0
	cam.position = cam_target + Vector3(0, ty, 0) + off
	cam.look_at(cam_target + Vector3(0, ty + 2.0, 0), Vector3.UP)


func ground_at(sp: Vector2) -> Vector3:
	var o := cam.project_ray_origin(sp)
	var d := cam.project_ray_normal(sp)
	var t := 0.0
	for i in 200:
		var p := o + d * t
		if p.y <= h_at(p.x, p.z):
			return p
		t += 3.0
	return o + d * (-o.y / minf(-0.001, d.y))


func _fig_at(p: Vector3, side: int, r: float) -> int:
	var best := -1
	var bd := r
	for f in figs:
		if not f["alive"] or (side >= 0 and f["side"] != side):
			continue
		var d := Vector2(f["pos"].x - p.x, f["pos"].z - p.z).length()
		if d < bd:
			bd = d
			best = f["i"]
	return best


func _input_3d(e: InputEvent) -> void:
	if cmd_mode:
		if e is InputEventMouseButton:
			var b := e as InputEventMouseButton
			if b.button_index == MOUSE_BUTTON_LEFT and b.pressed:
				_cmd_attack()
			elif b.button_index == MOUSE_BUTTON_RIGHT:
				_rmb = b.pressed
			elif b.pressed and b.button_index == MOUSE_BUTTON_WHEEL_UP:
				cmd_cam_dist = clampf(cmd_cam_dist - 1.0, 4.0, 20.0)
			elif b.pressed and b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				cmd_cam_dist = clampf(cmd_cam_dist + 1.0, 4.0, 20.0)
		elif e is InputEventMouseMotion and _rmb:
			var mm := e as InputEventMouseMotion
			if fps:
				# ko'z rejimida sichqoncha bilan burilish va yuqori-pastga qarash
				(figs[cmd]["node"] as Node3D).rotation.y -= mm.relative.x * 0.005
				fps_pitch = clampf(fps_pitch - mm.relative.y * 0.004, -1.1, 0.9)
			else:
				cmd_cam_yaw -= mm.relative.x * 0.006
		return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = clampf(cam_dist / 1.12, 15.0, 360.0)
			_apply_cam()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = clampf(cam_dist * 1.12, 15.0, 360.0)
			_apply_cam()
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_mid = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			# chap tugma: bosib sudrasa - maydonni surish; qo'yib yuborganda siljimagan bo'lsa - tanlash
			_lmb = true
			_lmoved = false
			_lpress = mb.position
		elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and _lmb:
			_lmb = false
			if _lmoved:
				return
			var gp := ground_at(mb.position)
			var ei := _engine_at(gp) if att_side == 0 else -1
			if ei >= 0:
				_select(-1)
				_select_engine(ei)
				return
			_select_engine(-1)
			var fi := _fig_at(gp, 0, 4.0)
			_select(figs[fi]["reg"] if fi >= 0 else -1)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and sel_eng >= 0:
			_order_engine(ground_at(mb.position))
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and sel >= 0:
			_order(ground_at(mb.position))
	elif e is InputEventMouseMotion:
		var mm := e as InputEventMouseMotion
		if _lmb and mm.position.distance_to(_lpress) > 6.0:
			_lmoved = true
		if _mid or (_lmb and _lmoved):
			var a := ground_at(mm.position - mm.relative)
			var b := ground_at(mm.position)
			if a.distance_to(b) < 120.0:
				cam_target += Vector3(a.x - b.x, 0, a.z - b.z)
			else:
				cam_target -= Basis(Vector3.UP, cam_yaw) * Vector3(mm.relative.x, 0, mm.relative.y) * cam_dist * 0.002
			cam_target = cam_target.clamp(Vector3(-40, 0, -40), Vector3(W + 40, 0, H + 40))
			_apply_cam()


func _select(rid: int) -> void:
	if sel >= 0:
		for fi in regs[sel]["figs"]:
			(figs[fi]["disc"] as MeshInstance3D).material_override = _disc_mats[figs[fi]["side"]]
	sel = rid
	if sel >= 0:
		for fi in regs[sel]["figs"]:
			(figs[fi]["disc"] as MeshInstance3D).material_override = _sel_mat
		tip_label.text = "%s tanlandi (%d). O'ng tugma: yerga - yurish, dushmanga - hujum." % [NAMES[regs[sel]["kind"]], _alive(regs[sel])]
	_refresh_ui()


func _order(gp: Vector3) -> void:
	var r: Dictionary = regs[sel]
	if r["routed"]:
		return
	# qamal: devorni bossangiz - narvon (nayzachi) yoki ilmoqli arqon (qilichboz) bilan chiqish
	if siege and att_side == 0 and phase == "fight" and r["kind"] in ["nayzachi", "qilichboz"] and _wall_dist(gp) < 5.0 and _outside(gp, 0.0):
		_order_climb(r, gp)
		return
	# o'z qal'angizni himoya qilish: devorni bossangiz - bo'linma zinadan devor ustiga chiqadi
	if siege and def_side == 0 and r["side"] == 0 and not r["kind"] in ["otliq", "top"] and _wall_dist(gp) < 4.0 and not r.has("title"):
		_order_man_wall(r, gp, phase == "deploy")
		return
	# devordagi bo'linmani hovliga tushirish
	if siege and def_side == 0 and r["side"] == 0 and _inside(gp) and _wall_dist(gp) >= 4.0:
		for fi in r["figs"]:
			var wf: Dictionary = figs[fi]
			if wf["alive"] and (wf.get("layer", "ground") == "wall" or wf.get("state", "") == "to_wall"):
				wf["state"] = ""
				wf["layer"] = "ground"
				wf.erase("post")
				var wd := _wall_point(wf["pos"]) - _outward(_wall_point(wf["pos"])) * 3.0
				wf["pos"] = Vector3(wd.x, h_at(wd.x, wd.z), wd.z)
				(wf["node"] as Node3D).position = wf["pos"]
	var ef := _fig_at(gp, 1, 5.0)
	if ef >= 0 and phase == "fight":
		r["target"] = figs[ef]["reg"]
		r["order"] = "attack"
		tip_label.text = "%s hujumga: %s" % [NAMES[r["kind"]], NAMES[regs[r["target"]]["kind"]].to_lower()]
		return
	if phase == "deploy" and not (siege and def_side == 0):
		var lim := W * 0.36
		gp.x = clampf(gp.x, 8.0, lim)
	gp.z = clampf(gp.z, 8.0, H - 8.0)
	gp.x = clampf(gp.x, 6.0, W - 6.0)
	var d := gp - _center(r)
	if d.length() > 2.0:
		r["face"] = atan2(-d.z, d.x)
	r["anchor"] = Vector3(gp.x, 0, gp.z)
	r["target"] = -1
	r["order"] = "move"
	if phase == "deploy":
		_place_reg(r, true)


func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed:
		var k := (e as InputEventKey).keycode
		if k == KEY_TAB:
			_toggle_cmd()
			return
		if cmd_mode:
			match k:
				KEY_1: cmd_weapon = "qilich"; _cmd_swap()
				KEY_2: cmd_weapon = "kamon"; _cmd_swap()
				KEY_3: cmd_weapon = "nayza"; _cmd_swap()
				KEY_F: cmd_mounted = not cmd_mounted; _cmd_swap()
				KEY_Q: _shout("olga")
				KEY_E: _shout("turing")
				KEY_R: _shout("qalqon")
				KEY_G: _shout("yomgir")
				KEY_V:
					fps = not fps
					_fps_body()
				KEY_ESCAPE: _toggle_cmd()
			return
		if k == KEY_ESCAPE:
			_select(-1)
		elif k == KEY_SPACE and phase == "deploy":
			_begin()


# ================================================================ jang mantiqi

func _alive(r: Dictionary) -> int:
	var n := 0
	for fi in r["figs"]:
		if figs[fi]["alive"]:
			n += 1
	return n


func _center(r: Dictionary) -> Vector3:
	var c := Vector3.ZERO
	var n := 0
	for fi in r["figs"]:
		if figs[fi]["alive"]:
			c += figs[fi]["pos"]
			n += 1
	return c / n if n > 0 else r["anchor"]


func _begin() -> void:
	if phase != "deploy":
		return
	phase = "fight"
	start_btn.visible = false
	for r in regs:
		if r["side"] == 1:
			r["order"] = "attack" if player_attacking == false or not _ranged(r["kind"]) else "hold"
	tip_label.text = "Jang boshlandi! Bo'linmani bosib, o'ng tugma bilan buyruq bering."
	if siege and att_side == 1:
		_ai_storm()
	_refresh_ui()


func _all_attack() -> void:
	if phase == "deploy":
		_begin()
	for r in regs:
		if r["side"] == 0 and not r["routed"] and not r.has("title"):
			r["order"] = "attack"
			r["target"] = -1


func _process(delta: float) -> void:
	if cam == null:
		return
	for k in shout_cd:
		shout_cd[k] = maxf(0.0, shout_cd[k] - delta * sim_speed)
	shield_t = maxf(0.0, shield_t - delta * sim_speed)
	if cmd_mode and not _cmd_alive():
		_toggle_cmd()
	var dir := Vector3.ZERO
	if cmd_mode:
		_cmd_control(delta)
	if Input.is_key_pressed(KEY_A): dir.x -= 1
	if Input.is_key_pressed(KEY_D): dir.x += 1
	if Input.is_key_pressed(KEY_W): dir.z -= 1
	if Input.is_key_pressed(KEY_S): dir.z += 1
	var yaw := 0.0
	if Input.is_key_pressed(KEY_Q): yaw -= 1
	if Input.is_key_pressed(KEY_E): yaw += 1
	if (dir != Vector3.ZERO or yaw != 0.0) and not cmd_mode:
		cam_target += Basis(Vector3.UP, cam_yaw) * dir.normalized() * cam_dist * 0.9 * delta
		cam_target = cam_target.clamp(Vector3(-40, 0, -40), Vector3(W + 40, 0, H + 40))
		cam_yaw += yaw * 1.4 * delta
		_apply_cam()
	if phase == "fight" and not finished:
		var dt := minf(delta, 0.05) * sim_speed
		_simulate(dt)
		_update_arrows(dt)
		_check_end()
	for r in regs:
		var lab: Label3D = r["label"]
		var n := _alive(r)
		lab.visible = n > 0
		if cmd_mode and n > 0 and r.has("title"):
			lab.visible = false
		elif cmd_mode and n > 0:
			lab.visible = _center(r).distance_to(cam.position) < 70.0
		if n > 0:
			lab.position = _center(r) + Vector3(0, 5.5, 0)
			lab.text = r["title"] if r.has("title") else "%s %d%s" % [NAMES[r["kind"]], n, " (qochmoqda)" if r["routed"] else ""]
	_ui_t += delta
	if _ui_t > 0.5:
		_ui_t = 0.0
		_refresh_ui()


func _ai_target(r: Dictionary) -> int:
	## bo'linma uchun eng yaqin dushman bo'linmasi (otliq kamonchilarni afzal ko'radi)
	var best := -1
	var bd := 1e9
	var c := _center(r)
	for o in regs:
		if o["side"] == r["side"] or o["routed"] or _alive(o) == 0:
			continue
		var d := c.distance_to(_center(o))
		if r["kind"] == "otliq" and _ranged(o["kind"]):
			d *= 0.6
		if d < bd:
			bd = d
			best = o["id"]
	return best


func _simulate(dt: float) -> void:
	_retarget -= dt
	var re := _retarget <= 0.0
	if re:
		_retarget = 0.4
		for r in regs:
			if r["routed"] or _alive(r) == 0:
				continue
			# dushman yaqinlashsa, kutib turgan bo'linma ham jangga kiradi
			if r["order"] != "attack" and r["order"] != "climb":
				var t := _ai_target(r)
				if t >= 0 and _center(r).distance_to(_center(regs[t])) < (STAT[r["kind"]]["range"] + 8.0 if _ranged(r["kind"]) else 42.0):
					if not _ranged(r["kind"]) or r["side"] == 1:
						r["order"] = "attack"
			if r["order"] == "attack" and (r["target"] < 0 or regs[r["target"]]["routed"] or _alive(regs[r["target"]]) == 0):
				r["target"] = _ai_target(r)
	# qo'mondon atrofidagi bo'linmalarning ruhi tiklanib turadi
	if re and _cmd_alive():
		for r in regs:
			if r["side"] == 0 and not r["routed"] and _center(r).distance_to(figs[cmd]["pos"]) < 30.0:
				r["morale"] = minf(100.0, r["morale"] + 0.8)
	for f in figs:
		if not f["alive"]:
			continue
		if cmd_mode and f.get("cmd", false):
			continue
		var r: Dictionary = regs[f["reg"]]
		var st: Dictionary = STAT[f["kind"]]
		f["cd"] -= dt
		var node: Node3D = f["node"]
		if r["routed"] and siege and f["side"] == def_side:
			# qal'a himoyachilari arkka qochib yashirinadi
			if f.get("layer", "ground") == "wall":
				f["layer"] = "ground"
				var w0 := _wall_point(f["pos"]) - _outward(_wall_point(f["pos"])) * 3.0
				f["pos"] = Vector3(w0.x, h_at(w0.x, w0.z), w0.z)
				node.position = f["pos"]
			_move(f, Vector3(cs["cx"] + 6.0, 0, cs["cz"]), st["speed"], dt)
			_anim(f, "Run")
			continue
		if r["routed"]:
			# qochish: o'z maydon chetiga
			var ex := -20.0 if f["side"] == 0 else W + 20.0
			var goal := Vector3(ex, 0, f["pos"].z)
			_move(f, goal, st["speed"] * 1.2, dt)
			_anim(f, "Run" if f["kind"] != "otliq" else "Gallop")
			if absf(f["pos"].x - ex) < 4.0:
				f["alive"] = false
				f["escaped"] = true
				node.visible = false
			continue
		if siege and _siege_fig(f, r, st, dt, re):
			continue
		if re or f["target"] < 0 or not figs[f["target"]]["alive"]:
			f["target"] = _pick_target(f, r)
		var tgt: int = f["target"]
		if tgt >= 0:
			var e: Dictionary = figs[tgt]
			var d := Vector2(e["pos"].x - f["pos"].x, e["pos"].z - f["pos"].z).length()
			# kamonchi: dushman uzoqda bo'lsa, turib o'q uzadi
			var rk := _ranged(f["kind"])
			if rk and d > 9.0 and d < st["range"] + maxf(0.0, f["pos"].y - e["pos"].y) * 2.0:
				_face(f, e["pos"])
				if f["cd"] <= 0.0:
					f["cd"] = st["shot"] * _rng.randf_range(0.85, 1.2)
					if st.has("cannon"):
						_cannon_shot(f, e["pos"], -1)
					else:
						_shoot(f, e)
					_anim(f, st.get("fire", "Attack"), true)
				elif st.has("bullet"):
					# o'q uzgandan keyin: porox, o'q, shompol - qayta o'qlash; tayyor bo'lsa nishonga oladi
					if f["cd"] < st["shot"] - 0.9:
						_anim(f, "Reload" if f["cd"] > 1.0 else "Aim")
				elif not st.has("cannon") and f["anim"] != "Attack":
					_anim(f, "Block")
				continue
			if rk and d >= st["range"] and r["order"] == "attack":
				_move(f, e["pos"], st["speed"], dt)
				_anim(f, "Run" if not st.has("cannon") else "Idle")
				continue
			if rk and (d >= 9.0 or st.has("cannon")):
				pass
			elif r["order"] == "attack" or d < 6.0:
				if d > st["reach"]:
					_move(f, e["pos"], st["speed"], dt)
					_anim(f, "Run" if f["kind"] != "otliq" else "Gallop")
					f["charge"] = f.get("charge", 0.0) + dt
				else:
					_face(f, e["pos"])
					if f["cd"] <= 0.0:
						f["cd"] = st["cd"] * _rng.randf_range(0.8, 1.25)
						var dmg: float = st["dmg"]
						if e["kind"] == "otliq":
							dmg *= st["vs_cav"]
						if f["kind"] == "otliq" and f.get("charge", 0.0) > 2.0:
							dmg *= 2.2      # otliq zarbasi (chopib kelib urish)
						if e["pos"].y > f["pos"].y + 2.0:
							dmg *= 0.8      # tepaga hujum qiyin
						f["charge"] = 0.0
						_hit(e, dmg * _rng.randf_range(0.7, 1.3))
						_anim(f, "Attack" if f["kind"] != "otliq" else "Idle", true)
						if f["kind"] == "otliq":
							var rd := Unit3D.rider_of(node)
							if rd:
								Unit3D.play(rd, "RideAttack")
					elif f["anim"] in ["Run", "Gallop", "Walk"]:
						_anim(f, "Block" if f["kind"] != "otliq" else "Idle")
				continue
		# buyruq yo'q: o'z safidagi joyiga boradi
		var idx: int = r["figs"].find(f["i"])
		var slot := _slot(r, idx)
		if Vector2(slot.x - f["pos"].x, slot.z - f["pos"].z).length() > 0.8:
			_move(f, slot, st["speed"] * (0.6 if r["order"] == "hold" else 1.0), dt)
			_anim(f, "Walk" if r["order"] != "move" or f["kind"] == "otliq" else "Run")
		else:
			node.rotation.y = lerp_angle(node.rotation.y, r["face"], 0.1)
			_anim(f, "Idle")
	if siege:
		_update_engines(dt)
	_update_stones(dt)
	_separate()


func _pick_target(f: Dictionary, r: Dictionary) -> int:
	var best := -1
	var bd := 1e9
	var pref: int = r["target"]
	for e in figs:
		if not e["alive"] or e["side"] == f["side"] or regs[e["reg"]]["routed"]:
			continue
		# qamalda: piyoda yerdan devor ustidagini ura olmaydi (kamonchi otadi)
		# (qal'a ichiga kirganlar zinadan devor ustidagilarga yeta oladi)
		if siege and not _ranged(f["kind"]) and e.get("layer", "ground") != f.get("layer", "ground") \
				and not (e.get("layer", "ground") == "wall" and _inside(f["pos"])):
			continue
		if siege and e.get("state", "") == "climbing" and not _ranged(f["kind"]):
			continue
		var d := Vector2(e["pos"].x - f["pos"].x, e["pos"].z - f["pos"].z).length_squared()
		if pref >= 0 and e["reg"] == pref:
			d *= 0.35
		if d < bd:
			bd = d
			best = e["i"]
	return best


func _ford_route(p: Vector3, goal: Vector3) -> Vector3:
	## daryoning narigi tomoniga borish kerak bo'lsa - eng yaqin kechuvdan o'tadi
	var rx := river_x(p.z)
	var gx := river_x(goal.z)
	if signf(p.x - rx) == signf(goal.x - gx) or is_ford(p.z):
		return goal
	var fz := H * 0.27 if absf(p.z - H * 0.27) + absf(goal.z - H * 0.27) < absf(p.z - H * 0.73) + absf(goal.z - H * 0.73) else H * 0.73
	var side := signf(p.x - rx)
	var wp := Vector3(river_x(fz) + side * 4.0, 0, fz)
	return wp


func _move(f: Dictionary, goal: Vector3, speed: float, dt: float) -> void:
	goal = _ford_route(f["pos"], goal)
	var d := Vector2(goal.x - f["pos"].x, goal.z - f["pos"].z)
	var L := d.length()
	if L < 0.05:
		return
	var sp := speed
	# daryoda (kechuvdan boshqa joyda) juda sekin
	if absf(f["pos"].x - river_x(f["pos"].z)) < 9.0 and not is_ford(f["pos"].z):
		sp *= 0.3
	if in_moat(f["pos"]):
		sp *= 0.35
	var step := d / L * minf(L, sp * dt)
	var np: Vector3 = f["pos"] + Vector3(step.x, 0, step.y)
	if siege and f.get("layer", "ground") == "ground" and _blocked(f["pos"], np):
		return
	f["pos"].x = np.x
	f["pos"].z = np.z
	f["pos"].y = h_at(f["pos"].x, f["pos"].z)
	var node: Node3D = f["node"]
	node.position = f["pos"]
	node.rotation.y = lerp_angle(node.rotation.y, atan2(-d.y, d.x), 0.25)


func _face(f: Dictionary, p: Vector3) -> void:
	var node: Node3D = f["node"]
	node.rotation.y = lerp_angle(node.rotation.y, atan2(-(p.z - f["pos"].z), p.x - f["pos"].x), 0.3)


func _separate() -> void:
	var n := figs.size()
	for i in n:
		var a: Dictionary = figs[i]
		if not a["alive"]:
			continue
		for j in range(i + 1, n):
			var b: Dictionary = figs[j]
			if not b["alive"]:
				continue
			if a.get("layer", "ground") != b.get("layer", "ground"):
				continue
			var dx: float = b["pos"].x - a["pos"].x
			var dz: float = b["pos"].z - a["pos"].z
			var r := 1.0 if a["kind"] != "otliq" and b["kind"] != "otliq" else 1.8
			if a["kind"] == "top" or b["kind"] == "top":
				r = 2.6
			var d2 := dx * dx + dz * dz
			if d2 < r * r and d2 > 0.0001:
				var d := sqrt(d2)
				var push := (r - d) * 0.5 / d
				a["pos"].x -= dx * push
				a["pos"].z -= dz * push
				b["pos"].x += dx * push
				b["pos"].z += dz * push
				if a.get("layer", "ground") == "ground" and a.get("state", "") == "":
					(a["node"] as Node3D).position = Vector3(a["pos"].x, h_at(a["pos"].x, a["pos"].z), a["pos"].z)
				if b.get("layer", "ground") == "ground" and b.get("state", "") == "":
					(b["node"] as Node3D).position = Vector3(b["pos"].x, h_at(b["pos"].x, b["pos"].z), b["pos"].z)


func _hit(e: Dictionary, dmg: float) -> void:
	if not e["alive"]:
		return
	if e["side"] == 0 and shield_t > 0.0 and e["kind"] in ["nayzachi", "qilichboz"]:
		dmg *= 0.6
	e["hp"] -= dmg
	if e["hp"] > 0.0:
		if _rng.randf() < 0.3 and e["kind"] != "otliq":
			_anim(e, "Hit", true)
		return
	e["alive"] = false
	(e["disc"] as Node3D).visible = false
	if e.get("layer", "ground") == "wall" or e.get("state", "") == "climbing":
		var nd: Node3D = e["node"]
		var tw := nd.create_tween()
		tw.tween_property(nd, "position:y", h_at(nd.position.x, nd.position.z), 0.6)
	_anim(e, ("Death" if e["kind"] == "otliq" else ("Death1" if _rng.randf() < 0.5 else "Death2")), true)
	if e["kind"] == "otliq":
		var rd := Unit3D.rider_of(e["node"])
		if rd:
			Unit3D.play(rd, "Death1")
	var r: Dictionary = regs[e["reg"]]
	if e.get("cmd", false):
		# qo'mondon halok bo'ldi - butun qo'shinda vahima
		for o in regs:
			if o["side"] == 0:
				o["morale"] -= 35.0
		tip_label.text = "QO'MONDON HALOK BO'LDI! Qo'shinda vahima."
	r["morale"] -= 100.0 / maxf(4.0, r["figs"].size()) * 0.9
	# yon atrofdagi bo'linmalarning ham ruhi biroz tushadi
	for o in regs:
		if o["side"] == e["side"] and o["id"] != r["id"] and _center(o).distance_to(e["pos"]) < 30.0:
			o["morale"] -= 1.0
	var brave: bool = _cmd_alive() and r["side"] == 0 and _center(r).distance_to(figs[cmd]["pos"]) < 30.0
	if r["morale"] < (15.0 if brave else 30.0) and not r["routed"] and _alive(r) > 0 and r.get("title", "") == "":
		r["routed"] = true
		if r["side"] == 0:
			tip_label.text = "%s qochmoqda! Ruhi tushib ketdi." % NAMES[r["kind"]]


func _shoot(f: Dictionary, e: Dictionary) -> void:
	var a := MeshInstance3D.new()
	a.mesh = _arrow_mesh
	a.material_override = _arrow_mat
	world.add_child(a)
	var from: Vector3 = f["pos"] + Vector3(0, 1.5, 0)
	var to: Vector3 = e["pos"] + Vector3(_rng.randf_range(-1.5, 1.5), 1.0, _rng.randf_range(-1.5, 1.5))
	var st: Dictionary = STAT.get(f["kind"], {})
	if st.has("bullet"):
		# miltiq o'qi: tez va to'g'ri uchadi, og'izdan oq tutun chiqadi
		a.scale = Vector3(0.25, 0.25, 0.25)
		var muzzle: Vector3 = from + (to - from).normalized() * 1.3
		_smoke(muzzle)
		arrows.append({"node": a, "from": muzzle, "to": to, "t": 0.0, "dur": from.distance_to(to) / 220.0, "target": e["i"],
			"flat": true, "dmg": st["bullet"], "chance": st["chance"]})
		return
	var dur := from.distance_to(to) / 48.0
	arrows.append({"node": a, "from": from, "to": to, "t": 0.0, "dur": dur, "target": e["i"]})


func _smoke(p: Vector3, big := false) -> void:
	## porox tutuni: oq shar kengayib, tarqalib yo'qoladi
	for k in (3 if big else 1):
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		mi.mesh = sm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.92, 0.92, 0.9, 0.65)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = p + Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf_range(0, 0.5), _rng.randf_range(-0.6, 0.6)) * float(k)
		mi.scale = Vector3.ONE * (1.4 if big else 0.6)
		world.add_child(mi)
		var tw := mi.create_tween()
		tw.set_parallel(true)
		tw.tween_property(mi, "scale", Vector3.ONE * (4.5 if big else 2.4), 2.2)
		tw.tween_property(mi, "position:y", mi.position.y + 1.6, 2.2)
		tw.tween_property(m, "albedo_color:a", 0.0, 2.2)
		tw.chain().tween_callback(mi.queue_free)


func _cannon_shot(f: Dictionary, to: Vector3, seg: int) -> void:
	## to'p o'qi: past yoy bilan uchadi, tushgan joyda bir nechta askarni uradi (seg >= 0 - qal'a devori)
	var node: Node3D = f["node"]
	var barrel: Node3D = node.get_node_or_null("Barrel")
	if barrel:
		var tw := barrel.create_tween()
		tw.tween_property(barrel, "position:x", 0.15 - 0.45, 0.08)
		tw.tween_property(barrel, "position:x", 0.15, 0.9)
	var dir := Vector3(to.x - f["pos"].x, 0, to.z - f["pos"].z).normalized()
	var muzzle: Vector3 = f["pos"] + Vector3(0, 1.0, 0) + dir * 1.6
	_smoke(muzzle, true)
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.18
	sm.height = 0.36
	ball.mesh = sm
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color("#202022")
	ball.material_override = bm
	world.add_child(ball)
	var tgt := to + Vector3(_rng.randf_range(-4, 4), h_at(to.x, to.z) - to.y + 0.5, _rng.randf_range(-4, 4))
	stones.append({"node": ball, "from": muzzle, "to": tgt, "t": 0.0, "dur": muzzle.distance_to(tgt) / 110.0, "seg": seg, "arc": 6.0, "dmg": 2.0, "r": 4.0})


func _update_arrows(dt: float) -> void:
	for ar in arrows.duplicate():
		ar["t"] += dt
		var k: float = ar["t"] / ar["dur"]
		var a: Vector3 = ar["from"]
		var b: Vector3 = ar["to"]
		var arc := 0.0 if ar.get("flat", false) else a.distance_to(b) * 0.22
		var p := a.lerp(b, k) + Vector3(0, arc * 4.0 * k * (1.0 - k), 0)
		var p2 := a.lerp(b, minf(1.0, k + 0.02)) + Vector3(0, arc * 4.0 * minf(1.0, k + 0.02) * (1.0 - minf(1.0, k + 0.02)), 0)
		var node: MeshInstance3D = ar["node"]
		node.position = p
		if p2.distance_to(p) > 0.001:
			node.look_at(p2, Vector3.UP)
			node.rotate_object_local(Vector3.UP, PI / 2.0)
		if k >= 1.0:
			arrows.erase(ar)
			if ar["target"] >= 0:
				var e: Dictionary = figs[ar["target"]]
				var cover := 0.5 if e.get("layer", "ground") == "wall" else 1.0
				if e.get("layer", "ground") == "wall" and not _ranged(e["kind"]) and e.get("state", "") == "":
					cover = 0.12      # devordagi piyoda tishli parapet ortiga yashirinadi
				# qalqonli piyodaga o'q kamroq o'tadi
				if e["kind"] in ["nayzachi", "qilichboz"] and not ar.has("dmg"):
					cover *= 0.55
				if e["alive"] and _rng.randf() < float(ar.get("chance", 0.36)) * cover:
					_hit(e, float(ar.get("dmg", 0.336)) * (0.6 if e["kind"] == "otliq" else 1.0))
			# yerga sanchilgan o'q bir oz turadi
			node.get_tree().create_timer(4.0).timeout.connect(node.queue_free)


func _anim(f: Dictionary, a: String, restart := false) -> void:
	if f["anim"] == a and not restart:
		return
	f["anim"] = a
	var node: Node3D = f["node"]
	var ap := Unit3D.anim(node)
	if ap == null:
		if a.begins_with("Death") and node.has_meta("cannon"):
			# to'p yo'q qilindi: ag'darilib, tutab qoladi
			var tw0 := node.create_tween()
			tw0.tween_property(node, "rotation:x", 0.6, 0.6)
			_smoke(node.position + Vector3(0, 1, 0), true)
		return
	var name := a
	if f["kind"] == "otliq":
		name = {"Run": "Gallop", "Walk": "Walk", "Attack": "Idle", "Block": "Idle", "Hit": "Idle"}.get(a, a)
		var rd := Unit3D.rider_of(node)
		if rd and a in ["Run", "Walk", "Idle", "Gallop"]:
			Unit3D.play(rd, "Ride")
	if not ap.has_animation(name) and name.begins_with("Death"):
		var tw := node.create_tween()
		tw.tween_property(node, "rotation:z", -PI / 2.0 * 0.95, 0.5)
		tw.parallel().tween_property(node, "position:y", node.position.y + 0.3, 0.5)
		ap.stop()
		return
	if ap.has_animation(name):
		var an := ap.get_animation(name)
		an.loop_mode = Animation.LOOP_LINEAR if name in ["Idle", "Walk", "Run", "Gallop", "Block", "Aim"] else Animation.LOOP_NONE
		ap.play(name, 0.15, sim_speed)
		if restart:
			ap.seek(0.0, true)


# ================================================================ natija

func _eq(side: int) -> float:
	var s := 0.0
	for f in figs:
		if f["side"] == side and (f["alive"] or f["escaped"]):
			s += men_per_fig * float(CastleEco.EQ.get(f["kind"], 1.0))
	return minf(s, start_eq[side])


func _fighting(side: int) -> int:
	var n := 0
	for r in regs:
		if r["side"] == side and not r["routed"] and not r.has("title") and r["kind"] != "top":
			n += _alive(r)      # to'plar yolg'iz jang qila olmaydi
	return n


func _check_end() -> void:
	var a := _fighting(0)
	var b := _fighting(1)
	if a > 0 and b > 0:
		return
	finished = true
	player_won = b == 0 and a > 0
	_apply()
	for f in figs:
		if f["alive"] and f["side"] == (0 if player_won else 1) and f["kind"] != "otliq":
			_anim(f, "Cheer", true)
	var p: Dictionary = Game.provinces[prov_id]
	if player_won:
		result_label.text = "G'ALABA!\n" + ("%s olindi." % p["name"] if player_attacking else "Hujum qaytarildi.")
		result_label.add_theme_color_override("font_color", UIKit.GOOD)
	else:
		result_label.text = "MAG'LUBIYAT\n" + ("Qo'shiningiz chekindi." if player_attacking else "%s qo'ldan ketdi." % p["name"])
		result_label.add_theme_color_override("font_color", UIKit.BAD)
	result_panel.visible = true


func _apply() -> void:
	var a := War.get_army(army_id)
	if a.is_empty():
		return
	var p: Dictionary = Game.provinces[prov_id]
	var mine := _eq(0)
	var them := _eq(1)
	if player_attacking:
		a["soldiers"] = mine
		a["tanks"] = 0.0
		p["defense"] = them if _fighting(1) > 0 else 0.0
		if p["defense"] < 0.5:
			War.capture_by_player(a, prov_id)
		elif War.power(a) < 0.5:
			War.armies.erase(a)
			Game.message.emit("Qo'shiningiz %s da tor-mor bo'ldi!" % p["name"], "bad")
	else:
		a["soldiers"] = them if _fighting(1) > 0 else 0.0
		a["tanks"] = 0.0
		p["units"]["soldier"] = mine
		p["militia"] = 0.0
		if War.power(a) < 0.5:
			War.armies.erase(a)
			Game.message.emit("%s himoyachilari dushman hujumini qaytardi!" % p["name"], "good")
		elif War.garrison_power(p) < 0.5:
			War.bot_capture(a, prov_id)
	Game.changed.emit()


func _auto() -> void:
	## avtomatik natija: kuchlar nisbati bo'yicha
	if not finished:
		var m := maxf(0.1, start_eq[0])
		var t := maxf(0.1, start_eq[1])
		var win := m * _rng.randf_range(0.8, 1.2) > t
		for f in figs:
			if f["side"] == (1 if win else 0):
				f["alive"] = false
				f["escaped"] = _rng.randf() < 0.25
			elif _rng.randf() < minf(0.8, (t if win else m) / (m if win else t) * 0.5):
				f["alive"] = false
		finished = true
		_apply()
	_close()


func _retreat() -> void:
	if not finished:
		finished = true
		for f in figs:
			if f["side"] == 0 and f["alive"]:
				f["escaped"] = true
		_apply()
		if not War.get_army(army_id).is_empty() and player_attacking:
			War.retreat(army_id)
	_close()


func _close() -> void:
	if hud:
		hud.queue_free()
	closed.emit()
	queue_free()


# ================================================================ HUD

func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_parent().add_child(hud)
	var cont := SubViewportContainer.new()
	cont.set_anchors_preset(Control.PRESET_FULL_RECT)
	cont.stretch = true
	cont.mouse_filter = Control.MOUSE_FILTER_STOP
	cont.gui_input.connect(_input_3d)
	hud.add_child(cont)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.handle_input_locally = false
	cont.add_child(vp)
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 8
	bar.offset_right = -8
	bar.offset_top = 8
	bar.add_theme_stylebox_override("panel", UIKit.style(Color(0.05, 0.08, 0.12, 0.6), 12, Color(0.6, 0.8, 1.0, 0.22), 10))
	hud.add_child(bar)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	bar.add_child(h)
	h.add_child(UIKit.label("JANG: " + Game.provinces[prov_id]["name"], 19, Color.WHITE))
	info_label = UIKit.label("", 15, UIKit.GOLD)
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(info_label)
	for s in [1.0, 2.0, 3.0]:
		var b := Button.new()
		b.text = "%dx" % int(s)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): sim_speed = s)
		h.add_child(b)
	UIKit.button(h, " Avto natija ", "", _auto).focus_mode = Control.FOCUS_NONE
	UIKit.button(h, " Chekinish ", "", _retreat).focus_mode = Control.FOCUS_NONE
	# chap panel: bo'linmalar
	var side := PanelContainer.new()
	side.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	side.offset_left = 8
	side.offset_right = 250
	side.offset_top = 70
	side.offset_bottom = -90
	reg_panel = side
	side.add_theme_stylebox_override("panel", UIKit.style(Color(0.05, 0.08, 0.12, 0.55), 12, Color(0.6, 0.8, 1.0, 0.2), 10))
	hud.add_child(side)
	var sv := UIKit.scroll(side)
	sv.add_child(UIKit.label("BO'LINMALARINGIZ", 15, Color.WHITE))
	reg_box = VBoxContainer.new()
	reg_box.add_theme_constant_override("separation", 4)
	sv.add_child(reg_box)
	# pastki panel
	var bot := PanelContainer.new()
	bot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bot.offset_left = 8
	bot.offset_right = -8
	bot.offset_top = -80
	bot.offset_bottom = -8
	bot.add_theme_stylebox_override("panel", UIKit.style(Color(0.05, 0.08, 0.12, 0.6), 12, Color(0.6, 0.8, 1.0, 0.22), 10))
	hud.add_child(bot)
	var bv := VBoxContainer.new()
	bot.add_child(bv)
	var br := UIKit.row(bv, 8)
	start_btn = UIKit.button(br, "  JANGNI BOSHLASH (Probel)  ", "", _begin, true)
	start_btn.focus_mode = Control.FOCUS_NONE
	UIKit.button(br, "  Hammasi hujumga!  ", "", _all_attack).focus_mode = Control.FOCUS_NONE
	cmd_btn = UIKit.button(br, "  QO'MONDON BO'LISH (Tab)  ", "", _toggle_cmd, true)
	cmd_btn.focus_mode = Control.FOCUS_NONE
	cmd_panel = PanelContainer.new()
	cmd_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	cmd_panel.offset_left = -330
	cmd_panel.offset_right = -10
	cmd_panel.offset_top = 64
	cmd_panel.offset_bottom = 250
	cmd_panel.add_theme_stylebox_override("panel", UIKit.style(Color(0.08, 0.06, 0.02, 0.7), 12, Color(1.0, 0.82, 0.4, 0.4), 12))
	cmd_panel.visible = false
	hud.add_child(cmd_panel)
	cmd_label = UIKit.label("", 14, Color("#ffe6a8"))
	cmd_panel.add_child(cmd_label)
	cross = UIKit.label("+", 34, Color(1, 1, 1, 0.8))
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.offset_left = -10
	cross.offset_top = -40
	cross.visible = false
	hud.add_child(cross)
	tip_label = UIKit.label(("QAMAL: Taranni bosib darvozaga, manjaniqni bosib devorga o'ng tugma bilan buyruq bering. Nayzachi/qilichbozni tanlab devorni o'ng tugma bilan bossangiz - narvon/arqon bilan chiqadi. " if siege else "") + "SAF TORTISH: bo'linmani bosing, o'ng tugma bilan joyini o'zgartiring. Daryodan faqat KECHUV orqali tez o'tiladi.", 13, UIKit.INFO, true)
	bv.add_child(tip_label)
	result_panel = PanelContainer.new()
	result_panel.set_anchors_preset(Control.PRESET_CENTER)
	result_panel.offset_left = -220
	result_panel.offset_right = 220
	result_panel.offset_top = -90
	result_panel.offset_bottom = 90
	result_panel.add_theme_stylebox_override("panel", UIKit.style(Color(0.05, 0.08, 0.12, 0.85), 16, Color(0.6, 0.8, 1.0, 0.3), 18))
	result_panel.visible = false
	hud.add_child(result_panel)
	var rv := VBoxContainer.new()
	result_panel.add_child(rv)
	result_label = UIKit.label("", 26, Color.WHITE)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rv.add_child(result_label)
	UIKit.button(rv, "  Xaritaga qaytish  ", "", _close, true)


func _refresh_ui() -> void:
	if info_label == null:
		return
	info_label.text = "Siz: %d askar   |   Dushman: %d askar   (1 figura = %d)" % [int(_eq_alive(0)), int(_eq_alive(1)), int(men_per_fig)]
	UIKit.clear(reg_box)
	if siege:
		reg_box.add_child(UIKit.label("QAMAL QUROLLARI" if att_side == 0 else "DUSHMAN QAMAL QUROLLARI (kamonchilar bilan yo'q qiling)", 13, UIKit.GOLD if att_side == 0 else UIKit.BAD, true))
		for en in engines:
			var eb := Button.new()
			eb.focus_mode = Control.FOCUS_NONE
			eb.alignment = HORIZONTAL_ALIGNMENT_LEFT
			eb.text = "%s  - %s" % [en["name"], ("buzildi" if en["hp"] <= 0.0 else "butunligi %d%%" % int(en["hp"] / en["max"] * 100.0))]
			eb.disabled = en["hp"] <= 0.0 or att_side != 0
			if en["i"] == sel_eng:
				eb.add_theme_color_override("font_color", UIKit.GOLD)
			eb.pressed.connect(_select_engine.bind(en["i"]))
			reg_box.add_child(eb)
		var g: Dictionary = cs["segs"][cs["gate"]]
		reg_box.add_child(UIKit.label("Darvoza: %s" % ("BUZILDI" if g["hp"] <= 0 else "%d/%d" % [int(ceil(g["hp"])), int(ceil(g["max"]))]), 12, UIKit.INFO))
		var br := 0
		for sg in cs["segs"]:
			if sg["hp"] <= 0 and not sg["gate"]:
				br += 1
		reg_box.add_child(UIKit.label("Devordagi teshiklar: %d" % br, 12, UIKit.INFO))
		reg_box.add_child(HSeparator.new())
	for r in regs:
		if r["side"] != 0 or r.has("title"):
			continue
		var n := _alive(r)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var state := "QOCHMOQDA" if r["routed"] else ("hujumda" if r["order"] == "attack" else "safda")
		b.text = "%s  %d  - ruh %d%%  (%s)" % [NAMES[r["kind"]], n, int(maxf(0.0, r["morale"])), state if n > 0 else "qirildi"]
		b.disabled = n == 0
		if r["id"] == sel:
			b.add_theme_color_override("font_color", UIKit.GOLD)
		b.pressed.connect(_select.bind(r["id"]))
		reg_box.add_child(b)


func _eq_alive(side: int) -> float:
	var s := 0.0
	for f in figs:
		if f["side"] == side and f["alive"]:
			s += men_per_fig * float(CastleEco.EQ.get(f["kind"], 1.0))
	return s


# ================================================================ ko'z darajasidan ko'rish: qo'llar va qurol

func _fps_body() -> void:
	## ko'z rejimida qo'mondonning o'z tanasi yashiriladi (otda bo'lsa ot ko'rinib turadi)
	if cmd < 0:
		return
	var node: Node3D = figs[cmd]["node"]
	var on := cmd_mode and fps
	var rd := Unit3D.rider_of(node)
	if rd:
		node.visible = true
		rd.visible = not on
	else:
		node.visible = not on
	if vm:
		vm.visible = on


func _fps_cam(f: Dictionary, node: Node3D, delta: float, moving: bool) -> void:
	var yaw := node.rotation.y
	var fwd := Vector3(cos(yaw), 0, -sin(yaw))
	var eye := (2.55 if cmd_mounted else 1.68) * CMD_SCALE
	_bob += delta * (9.0 if moving else 1.5)
	var bob := sin(_bob) * (0.05 if moving else 0.01)
	if cmd_mounted:
		bob += sin(_bob * 0.5) * (0.06 if moving else 0.0)
	cam.position = f["pos"] + Vector3(0, eye + bob, 0) + fwd * (0.25 if cmd_mounted else 0.18)
	cam.rotation = Vector3(fps_pitch, yaw - PI / 2.0, 0)
	cam.near = 0.04
	if vm:
		vm.position = Vector3(0, sin(_bob * 0.5) * (0.012 if moving else 0.004), 0)


func _arm(parent: Node3D, shoulder: Vector3, hand_at: Vector3, sleeve: Material, skin: Material) -> Node3D:
	## yelkadan kaftgacha: yeng, bilakuzuk va kaft. -Z o'qi kaft tomonga qaratiladi.
	var sh := Node3D.new()
	parent.add_child(sh)
	# kamera (lokal) fazosida: -Z kaft tomonga
	sh.transform = Transform3D(Basis.looking_at(hand_at - shoulder, Vector3.UP), shoulder)
	var length := shoulder.distance_to(hand_at)
	var arm := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.034
	cm.bottom_radius = 0.05
	cm.height = length
	arm.mesh = cm
	arm.material_override = sleeve
	arm.rotation.x = -PI / 2.0
	arm.position = Vector3(0, 0, -length * 0.5)
	sh.add_child(arm)
	var br := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.038
	bm.bottom_radius = 0.04
	bm.height = 0.1
	br.mesh = bm
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color("#5a3a22")
	br.material_override = lm
	br.rotation.x = -PI / 2.0
	br.position = Vector3(0, 0, -length + 0.07)
	sh.add_child(br)
	var hand := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.04
	sm.height = 0.07
	hand.mesh = sm
	hand.material_override = skin
	hand.position = Vector3(0, 0, -length - 0.015)
	sh.add_child(hand)
	sh.set_meta("len", length)
	return sh


func _mat(c: String, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c)
	m.metallic = metal
	m.roughness = 0.4 if metal > 0.0 else 0.85
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _build_vm() -> void:
	if vm:
		vm.queue_free()
	vm = Node3D.new()
	cam.add_child(vm)
	var sleeve := _mat("#7a2f2a")
	var skin := _mat("#c8956c")
	var steel := _mat("#b8bec4", 0.8)
	var wood := _mat("#6e4a2c")
	var gold := _mat("#c9a03a", 0.8)
	var team := StandardMaterial3D.new()
	team.albedo_color = colors[0]
	for m in [sleeve, skin, steel, wood, gold, team]:
		(m as StandardMaterial3D).no_depth_test = false
	match cmd_weapon:
		"qilich":
			vm_r = _arm(vm, Vector3(0.3, -0.4, 0.0), Vector3(0.14, -0.13, -0.5), sleeve, skin)
			vm_l = _arm(vm, Vector3(-0.3, -0.42, 0.0), Vector3(-0.16, -0.17, -0.5), sleeve, skin)
			# egri qilich: kaftdan yuqoriga-oldinga
			vm_weapon = Node3D.new()
			vm_weapon.position = Vector3(0, 0, -float(vm_r.get_meta("len")) - 0.02)
			vm_r.add_child(vm_weapon)
			var blade := Node3D.new()
			blade.rotation = Vector3(deg_to_rad(-55), 0, deg_to_rad(-10))
			blade.scale = Vector3.ONE * 0.8
			vm_weapon.add_child(blade)
			_box(blade, Vector3(0.024, 0.1, 0.024), Vector3(0, -0.01, 0), wood)
			_box(blade, Vector3(0.12, 0.016, 0.024), Vector3(0, 0.045, 0), gold)
			for k in 7:
				var t := float(k) / 6.0
				_box(blade, Vector3(0.009, 0.085, 0.026 - t * 0.016), Vector3(0, 0.09 + k * 0.08, -t * t * 0.09), steel, Vector3(-0.05 - t * 0.3, 0, 0))
			if not cmd_mounted:
				var shd := MeshInstance3D.new()
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.22
				cyl.bottom_radius = 0.22
				cyl.height = 0.025
				shd.mesh = cyl
				shd.material_override = team
				shd.rotation.x = PI / 2.0
				shd.position = Vector3(0.0, 0.0, -float(vm_l.get_meta("len")) + 0.05)
				vm_l.add_child(shd)
			else:
				_box(vm_l, Vector3(0.01, 0.01, 0.5), Vector3(0.1, -0.03, -float(vm_l.get_meta("len")) - 0.2), _mat("#3a2414"), Vector3(0, 0.4, 0))
		"kamon":
			vm_l = _arm(vm, Vector3(-0.28, -0.4, 0.0), Vector3(-0.05, -0.06, -0.72), sleeve, skin)
			vm_r = _arm(vm, Vector3(0.3, -0.4, 0.0), Vector3(0.03, -0.08, -0.42), sleeve, skin)
			# kamon chap kaftda, vertikal (kamera fazosida tik turadi)
			vm_weapon = Node3D.new()
			vm.add_child(vm_weapon)
			vm_weapon.position = Vector3(-0.05, -0.06, -0.76)
			for k in 11:
				var t := float(k) / 10.0 * 2.0 - 1.0
				_box(vm_weapon, Vector3(0.04, 0.065, 0.022), Vector3(0, t * 0.32, 0.07 * (1.0 - t * t) - 0.04), wood, Vector3(t * 0.6, 0, 0))
			_box(vm_weapon, Vector3(0.003, 0.62, 0.003), Vector3(0.0, 0, 0.0), _mat("#e8e2d0"))
			# o'q: o'ng kaftdan kamongacha
			var arrow := _box(vm, Vector3(0.008, 0.008, 0.46), Vector3(0.0, -0.06, -0.44), wood)
			arrow.transform = Transform3D(Basis.looking_at(Vector3(-0.08, 0.01, -0.36), Vector3.UP), Vector3(-0.01, -0.07, -0.6))
			arrow.name = "Arrow"
		"nayza":
			vm_r = _arm(vm, Vector3(0.3, -0.42, 0.0), Vector3(0.13, -0.16, -0.42), sleeve, skin)
			vm_l = _arm(vm, Vector3(-0.28, -0.42, 0.0), Vector3(-0.04, -0.15, -0.7), sleeve, skin)
			vm_weapon = Node3D.new()
			vm.add_child(vm_weapon)
			var shaft := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.014
			cm.bottom_radius = 0.014
			cm.height = 2.2
			shaft.mesh = cm
			shaft.material_override = wood
			vm_weapon.add_child(shaft)
			vm_weapon.transform = Transform3D(Basis.looking_at(Vector3(-0.17, 0.01, -0.28), Vector3.UP), Vector3(0.13, -0.16, -0.42))
			shaft.rotation.x = PI / 2.0
			shaft.position = Vector3(0, 0, -0.6)
			_box(vm_weapon, Vector3(0.04, 0.01, 0.18), Vector3(0, 0, -1.78), steel)
	vm.set_meta("r_rest", vm_r.rotation)
	vm.set_meta("l_rest", vm_l.rotation)
	vm.set_meta("rp", vm_r.position)
	vm.set_meta("wp", vm_weapon.position)
	_fps_body()


func _vm_attack() -> void:
	## ko'z oldidagi qo'llarning zarba / otish harakati
	if vm == null or not fps:
		return
	var rr: Vector3 = vm.get_meta("r_rest")
	var tw := vm.create_tween()
	match cmd_weapon:
		"qilich":
			# o'ng tomondan ko'tarib, chap pastga urish
			tw.tween_property(vm_r, "rotation", rr + Vector3(0.9, -0.35, 0.5), 0.12)
			tw.tween_property(vm_r, "rotation", rr + Vector3(-0.55, 0.75, -0.7), 0.13)
			tw.tween_property(vm_r, "rotation", rr, 0.3)
		"kamon":
			var rp: Vector3 = vm.get_meta("rp")
			var arrow: Node3D = vm.get_node_or_null("Arrow")
			tw.tween_property(vm_r, "position", rp + Vector3(0.03, 0.02, 0.12), 0.3)
			tw.tween_callback(func():
				if arrow: arrow.visible = false)
			tw.tween_property(vm_r, "position", rp + Vector3(0.06, 0.0, 0.16), 0.05)
			tw.tween_property(vm_r, "position", rp, 0.35)
			tw.tween_callback(func():
				if arrow: arrow.visible = true)
		"nayza":
			var rp2: Vector3 = vm.get_meta("rp")
			var wp: Vector3 = vm.get_meta("wp")
			tw.tween_property(vm_r, "position", rp2 + Vector3(0, 0.1, 0.12), 0.22)
			tw.parallel().tween_property(vm_weapon, "position", wp + Vector3(0, 0.1, 0.12), 0.22)
			tw.tween_property(vm_r, "position", rp2 + Vector3(0, 0.04, -0.35), 0.09)
			tw.parallel().tween_property(vm_weapon, "position", wp + Vector3(0, 0.04, -0.6), 0.09)
			tw.tween_callback(func(): vm_weapon.visible = false)
			tw.tween_property(vm_r, "position", rp2, 0.35)
			tw.tween_property(vm_weapon, "position", wp, 0.01)
			tw.tween_interval(1.5)
			tw.tween_callback(func(): vm_weapon.visible = true)


# ================================================================ QAMAL: dushman qal'asi, narvon, arqon, taran, manjaniq

func _inside(p: Vector3) -> bool:
	return p.x > cs["x0"] and p.x < cs["x1"] and p.z > cs["z0"] and p.z < cs["z1"]


func _outside(p: Vector3, m: float) -> bool:
	return p.x < cs["x0"] - m or p.x > cs["x1"] + m or p.z < cs["z0"] - m or p.z > cs["z1"] + m


func _wall_point(p: Vector3) -> Vector3:
	## p ga eng yaqin devor nuqtasi (to'rtburchak chegarasida)
	var x := clampf(p.x, cs["x0"], cs["x1"])
	var z := clampf(p.z, cs["z0"], cs["z1"])
	var dl := absf(x - cs["x0"])
	var dr := absf(cs["x1"] - x)
	var dt := absf(z - cs["z0"])
	var db := absf(cs["z1"] - z)
	var m := minf(minf(dl, dr), minf(dt, db))
	if m == dl: x = cs["x0"]
	elif m == dr: x = cs["x1"]
	elif m == dt: z = cs["z0"]
	else: z = cs["z1"]
	return Vector3(x, 0, z)


func _wall_dist(p: Vector3) -> float:
	var w := _wall_point(p)
	return Vector2(w.x - p.x, w.z - p.z).length()


func _outward(w: Vector3) -> Vector3:
	if absf(w.x - cs["x0"]) < 0.01: return Vector3(-1, 0, 0)
	if absf(w.x - cs["x1"]) < 0.01: return Vector3(1, 0, 0)
	if absf(w.z - cs["z0"]) < 0.01: return Vector3(0, 0, -1)
	return Vector3(0, 0, 1)


func _openings() -> Array:
	var o: Array = []
	for sg in cs["segs"]:
		if sg["hp"] <= 0:
			o.append(sg["center"])
	return o


func _blocked(a: Vector3, b: Vector3) -> bool:
	## a -> b qadam devordan o'tadimi (ochiq darvoza / teshikdan o'tish mumkin)
	if _inside(a) == _inside(b):
		return false
	var c := _wall_point(a.lerp(b, 0.5))
	for op in _openings():
		if Vector2(op.x - c.x, op.z - c.z).length() < 4.0:
			return false
	return true


func _build_castle() -> void:
	## dushman qal'asi: devor bo'laklari (har biri 8 m, buziladi), burchak minoralari, g'arbda darvoza, markazda ark
	var col: Color = colors[def_side]
	var sides := [[Vector3(cs["x0"], 0, cs["z0"]), Vector3(cs["x1"], 0, cs["z0"])], [Vector3(cs["x1"], 0, cs["z0"]), Vector3(cs["x1"], 0, cs["z1"])],
		[Vector3(cs["x1"], 0, cs["z1"]), Vector3(cs["x0"], 0, cs["z1"])], [Vector3(cs["x0"], 0, cs["z1"]), Vector3(cs["x0"], 0, cs["z0"])]]
	var gz: float = cs["cz"]
	for si in 4:
		var a: Vector3 = sides[si][0]
		var b: Vector3 = sides[si][1]
		var L := a.distance_to(b)
		var dir := (b - a) / L
		var ang := atan2(-dir.z, dir.x)
		var outer := Vector3(sin(ang), 0, cos(ang))
		if outer.dot(Vector3(cs["cx"], 0, cs["cz"]) - (a + b) * 0.5) > 0.0:
			ang += PI
		var t := 4.0
		while t < L - 4.0:
			var seglen := minf(8.0, L - 4.0 - t)
			var c := a + dir * (t + seglen * 0.5)
			var is_gate: bool = si == 3 and absf(c.z - gz) < 6.0 and cs["gate"] < 0
			if is_gate:
				seglen = 10.0
				c = Vector3(cs["x0"], 0, gz)
				t = absf(c.z - a.z) - 5.0
			var hp0: float = float(spec.get("gate_hp", 14.0)) if is_gate else float(spec.get("wall_hp", 4.0))
			var sg := {"center": Vector3(c.x, 0, c.z), "hp": hp0, "max": hp0, "gate": is_gate, "nodes": [], "ang": ang}
			var gy := h_at(c.x, c.z)
			if is_gate:
				var o: Node3D = load(Unit3D.castle_file(castle_country, "gate")).instantiate()
				o.position = Vector3(c.x, gy, c.z)
				o.rotation.y = ang
				FX.pbr(o)
				Unit3D.recolor(o, col)
				world.add_child(o)
				sg["nodes"].append(o)
				cs["gate"] = cs["segs"].size()
				t += 10.0
			else:
				var n := int(ceil(seglen / 4.0))
				for k in n:
					var mc := a + dir * (t + (k + 0.5) * seglen / n)
					var o: Node3D = load(Unit3D.castle_file(castle_country, "wall")).instantiate()
					o.position = Vector3(mc.x, h_at(mc.x, mc.z), mc.z)
					o.rotation.y = ang
					o.scale = Vector3(seglen / n / 4.0 * 1.01, 1, 1)
					FX.pbr(o)
					world.add_child(o)
					sg["nodes"].append(o)
				t += seglen
			cs["segs"].append(sg)
	var tpos: Array = [Vector3(cs["x0"], 0, cs["z0"]), Vector3(cs["x1"], 0, cs["z0"]), Vector3(cs["x1"], 0, cs["z1"]), Vector3(cs["x0"], 0, cs["z1"])]
	var nm: int = int(spec.get("mid", 1))
	for k in nm:
		var t := float(k + 1) / float(nm + 1)
		var xm: float = lerpf(cs["x0"], cs["x1"], t)
		var zm: float = lerpf(cs["z0"], cs["z1"], t)
		tpos.append_array([Vector3(xm, 0, cs["z0"]), Vector3(xm, 0, cs["z1"]), Vector3(cs["x1"], 0, zm)])
		if absf(zm - cs["cz"]) > 9.0:
			tpos.append(Vector3(cs["x0"], 0, zm))
	if cs.get("moat", false):
		_build_moat()
	for c in tpos:
		var tw: Node3D = load(Unit3D.castle_file(castle_country, "tower")).instantiate()
		tw.position = Vector3(c.x, h_at(c.x, c.z), c.z)
		if Unit3D.castle_style(castle_country) == "bastion":
			tw.rotation.y = atan2(c.x - cs["cx"], c.z - cs["cz"])
		FX.pbr(tw)
		Unit3D.recolor(tw, col)
		world.add_child(tw)
	var kp: Node3D = load(Unit3D.castle_file(castle_country, "keep")).instantiate()
	kp.position = Vector3(cs["cx"] + 6.0, h_at(cs["cx"] + 6.0, cs["cz"]), cs["cz"])
	kp.rotation.y = -PI / 2.0
	kp.scale = Vector3(0.8, 0.8, 0.8)
	FX.pbr(kp)
	Unit3D.recolor(kp, col)
	world.add_child(kp)
	_eng_mat = StandardMaterial3D.new()
	_eng_mat.albedo_color = Color("#6e4a2c")
	_eng_mat.roughness = 0.9


func in_moat(p: Vector3) -> bool:
	## xandaq: devordan 3..9 m tashqarida halqa; darvoza oldida ko'prik
	if not siege or not cs.get("moat", false):
		return false
	if not _outside(p, 3.0) or _outside(p, 9.0):
		return false
	return not (p.x < cs["x0"] and absf(p.z - cs["cz"]) < 5.0)


func _build_moat() -> void:
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color("#3d6a78")
	wm.roughness = 0.15
	wm.metallic = 0.3
	var x0: float = cs["x0"] - 9.0
	var x1: float = cs["x1"] + 9.0
	var z0: float = cs["z0"] - 9.0
	var z1: float = cs["z1"] + 9.0
	var parts := [[Vector3((x0 + x1) * 0.5, 0, z0 + 3.0), Vector2(x1 - x0, 6.0)], [Vector3((x0 + x1) * 0.5, 0, z1 - 3.0), Vector2(x1 - x0, 6.0)],
		[Vector3(x1 - 3.0, 0, (z0 + z1) * 0.5), Vector2(6.0, z1 - z0 - 12.0)],
		[Vector3(x0 + 3.0, 0, (z0 + 6.0 + cs["cz"] - 5.0) * 0.5), Vector2(6.0, cs["cz"] - 5.0 - z0 - 6.0)],
		[Vector3(x0 + 3.0, 0, (cs["cz"] + 5.0 + z1 - 6.0) * 0.5), Vector2(6.0, z1 - 6.0 - cs["cz"] - 5.0)]]
	for pt in parts:
		var c: Vector3 = pt[0]
		var sz: Vector2 = pt[1]
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = sz
		mi.mesh = pm
		mi.material_override = wm
		mi.position = Vector3(c.x, h_at(c.x, c.z) + 0.25, c.z)
		world.add_child(mi)
	# darvoza oldidagi yog'och ko'prik
	var br := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(7.0, 0.3, 7.5)
	br.mesh = bm
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("#6e4a2c")
	br.material_override = wood
	br.position = Vector3(x0 + 3.0, h_at(x0 + 3.0, cs["cz"]) + 0.4, cs["cz"])
	world.add_child(br)


func _ai_storm() -> void:
	## dushman qal'angizga hujum qiladi: nayzachilar narvon bilan, qilichbozlarning yarmi arqon bilan devorga chiqadi,
	## qolganlari darvoza oldida kutadi; taran darvozaga, manjaniqlar devorga
	var climbers: Array = regs.filter(func(r): return r["side"] == att_side and not r.has("title") and r["kind"] in ["nayzachi", "qilichboz"])
	var k := 0
	for r in climbers:
		if r["kind"] == "qilichboz" and k % 2 == 1:
			k += 1
			continue
		var zz: float = lerpf(cs["z0"] + 6.0, cs["z1"] - 6.0, _rng.randf())
		if absf(zz - cs["cz"]) < 8.0:
			zz += 12.0 * signf(zz - cs["cz"] + 0.01)
		var tip: String = tip_label.text
		_order_climb(r, Vector3(cs["x0"] - 2.0, 0, zz))
		tip_label.text = tip
		k += 1
	if Game.era == 2 and not engines.is_empty():
		engines[0]["type"] = "top"
	for e in engines:
		e["go"] = true
		if e["type"] == "top" and e["i"] == 0:
			e["target"] = cs["gate"]
		elif e["type"] != "taran":
			var best := -1
			var bd := 1e9
			for si in cs["segs"].size():
				var sg: Dictionary = cs["segs"][si]
				if sg["gate"]:
					continue
				var d: float = absf(sg["center"].x - cs["x0"]) + absf(sg["center"].z - cs["cz"]) * 0.5 + _rng.randf() * 20.0
				if d < bd:
					bd = d
					best = si
			e["target"] = best


func _siege_deploy() -> void:
	## himoyachilar: kamonchilar devor ustida, piyodalar ichkarida darvoza ortida
	var wall_slots: Array = []
	for sg in cs["segs"]:
		if sg["gate"]:
			continue
		var c: Vector3 = sg["center"]
		var w := _wall_point(c)
		var inward := -_outward(w)
		var along := Vector3(inward.z, 0, -inward.x)
		for k in [-1.5, 1.5]:
			var p: Vector3 = c + inward * 0.4 + along * k
			# g'arbiy (hujum) tomonga ko'proq
			wall_slots.append([(0 if absf(w.x - cs["x0"]) < 0.1 else 1), p, atan2(-(-inward.z), -inward.x)])
	wall_slots.sort_custom(func(a, b): return a[0] < b[0])
	var wi := 0
	var gate_c: Vector3 = cs["segs"][cs["gate"]]["center"]
	var inner := 0
	for r in regs:
		if r["side"] != def_side or r.has("title"):
			continue
		r["order"] = "hold"
		for fi in r["figs"]:
			var f: Dictionary = figs[fi]
			var node: Node3D = f["node"]
			if _ranged(f["kind"]) and f["kind"] != "top" and wi < wall_slots.size():
				var ws: Array = wall_slots[wi]
				wi += 1
				var p: Vector3 = ws[1]
				f["layer"] = "wall"
				f["pos"] = Vector3(p.x, h_at(p.x, p.z) + 7.1, p.z)
				node.position = f["pos"]
				node.rotation.y = ws[2]
				_anim(f, "Idle")
			else:
				var row := inner / 9
				var col := inner % 9
				inner += 1
				var p2 := gate_c + Vector3(10.0 + row * 1.8, 0, (col - 4) * 1.7)
				f["pos"] = Vector3(p2.x, h_at(p2.x, p2.z), p2.z)
				node.position = f["pos"]
				node.rotation.y = PI
				_anim(f, "Idle")
		r["anchor"] = _center(r)
		r["face"] = PI
		r["in_castle"] = true
	# "devorni qo'riqlash" vazifasida barcha piyodalar devorda; aks holda bitta bo'linma
	if def_side == 0 and _player_task() == "devor":
		var k := 0
		var sides := [Vector3(cs["x0"], 0, cs["cz"]), Vector3(cs["cx"], 0, cs["z0"]), Vector3(cs["cx"], 0, cs["z1"])]
		for r in regs:
			if r["side"] == 0 and not r.has("title") and r["kind"] in ["nayzachi", "qilichboz"] and _alive(r) > 0:
				var c: Vector3 = sides[0] + Vector3(0, 0, (k - 1) * 14.0) if k < 3 else sides[mini(k - 2, 2)]
				_order_man_wall(r, c, true)
				k += 1
	# bitta piyoda bo'linma (nayzachi, bo'lmasa qilichboz) hujum tomonidagi devor ustida turadi
	for want in (["nayzachi", "qilichboz"] if not (def_side == 0 and _player_task() == "devor") else []):
		var done := false
		for r in regs:
			if r["side"] == def_side and not r.has("title") and r["kind"] == want and _alive(r) > 0:
				_order_man_wall(r, Vector3(cs["x0"], 0, cs["cz"]), true)
				done = true
				break
		if done:
			break


func _siege_fig(f: Dictionary, r: Dictionary, st: Dictionary, dt: float, re: bool) -> bool:
	## qamal maxsus holatlari. true - figura bu kadrda shu yerda boshqarildi
	var node: Node3D = f["node"]
	var state: String = f.get("state", "")
	if state == "to_wall":
		# hovlidan devor ichki tagiga borib, zinadan ko'tariladi
		var post: Vector3 = f["post"]
		var foot := _wall_point(post) - _outward(_wall_point(post)) * 2.6
		foot.y = h_at(foot.x, foot.z)
		if f.get("stair_t", 0.0) <= 0.0 and Vector2(foot.x - f["pos"].x, foot.z - f["pos"].z).length() > 0.8:
			_move(f, foot, st["speed"], dt)
			_anim(f, "Run")
			return true
		f["stair_t"] = f.get("stair_t", 0.0) + dt
		var k := clampf(f["stair_t"] / 1.6, 0.0, 1.0)
		f["pos"] = foot.lerp(post, k)
		node.position = f["pos"]
		_anim(f, "Walk")
		if k >= 1.0:
			f["state"] = ""
			f["layer"] = "wall"
		return true
	if f.get("layer", "ground") == "wall" and f["side"] == def_side and not _ranged(f["kind"]):
		return _wall_melee(f, r, st, dt)
	if state == "climbing":
		f["climb_t"] = f["climb_t"] + dt
		var k := clampf(f["climb_t"] / f["climb_dur"], 0.0, 1.0)
		var base: Vector3 = f["climb_base"]
		f["pos"] = Vector3(base.x, base.y + k * 7.1, base.z)
		node.position = f["pos"]
		_anim(f, "Run")
		if k >= 1.0:
			# devor ustiga chiqdi: bir zum turib, ichkariga tushadi
			var top: Vector3 = f["climb_top"]
			f["state"] = "on_wall"
			climbed += 1
			f["layer"] = "wall"
			f["wall_t"] = 0.0
			f["pos"] = top
			node.position = top
		return true
	if state == "on_wall":
		f["wall_t"] = f["wall_t"] + dt
		# devor ustidagi himoyachi bilan olishadi
		for e in figs:
			if e["alive"] and e["side"] != f["side"] and e.get("layer", "ground") == "wall" and e["pos"].distance_to(f["pos"]) < 2.2:
				_face(f, e["pos"])
				if f["cd"] <= 0.0:
					f["cd"] = st["cd"]
					_hit(e, st["dmg"] * _rng.randf_range(0.8, 1.3))
					_anim(f, "Attack", true)
				return true
		# yaqinda devor himoyachisi bo'lsa - unga qarab boradi va olishadi
		var foe: Dictionary = {}
		var fd := 9.0
		for e in figs:
			if e["alive"] and e["side"] != f["side"] and e.get("layer", "ground") == "wall":
				var dd: float = e["pos"].distance_to(f["pos"])
				if dd < fd:
					fd = dd
					foe = e
		if not foe.is_empty():
			_wall_walk(f, foe["pos"], st["speed"] * 0.8, dt)
			_anim(f, "Run")
			f["wall_t"] = 0.0
			return true
		if f["wall_t"] > 1.2:
			var w := _wall_point(f["pos"])
			var down := w - _outward(w) * 3.0
			f["state"] = ""
			f["layer"] = "ground"
			f["pos"] = Vector3(down.x, h_at(down.x, down.z), down.z)
			node.position = f["pos"]
			r["order"] = "attack"
		return true
	if f.get("layer", "ground") == "wall":
		# devor ustidagi himoyachi kamonchi: joyidan qimirlamaydi, o'q uzadi; yonida dushman bo'lsa olishadi
		for e in figs:
			if e["alive"] and e["side"] != f["side"] and e.get("layer", "ground") == "wall" and e["pos"].distance_to(f["pos"]) < 2.0:
				_face(f, e["pos"])
				if f["cd"] <= 0.0:
					f["cd"] = st["cd"]
					_hit(e, st["dmg"] * 1.5)
					_anim(f, "Attack", true)
				return true
		if re or f["target"] < 0 or not figs[f["target"]]["alive"]:
			var best := -1
			var bd := 82.0
			for e in figs:
				if e["alive"] and e["side"] != f["side"]:
					var d := Vector2(e["pos"].x - f["pos"].x, e["pos"].z - f["pos"].z).length()
					if d < bd:
						bd = d
						best = e["i"]
			f["target"] = best
		if f["target"] >= 0:
			var e2: Dictionary = figs[f["target"]]
			_face(f, e2["pos"])
			if f["cd"] <= 0.0:
				f["cd"] = st.get("shot", 2.3) * _rng.randf_range(0.85, 1.2)
				_shoot(f, e2)
				_anim(f, "Attack", true)
		elif f["anim"] != "Attack":
			_anim(f, "Idle")
		return true
	if r["order"] == "climb" and f["side"] == att_side and _outside(f["pos"], -0.5):
		# devor tagiga borib, narvon/arqondan navbat bilan chiqish
		var spots: Array = r["climb_spots"]
		var my: Vector3 = spots[r["figs"].find(f["i"]) % spots.size()]
		var foot: Vector3 = my + _outward(_wall_point(my)) * 1.3
		if Vector2(foot.x - f["pos"].x, foot.z - f["pos"].z).length() > 1.0:
			_move(f, foot, st["speed"], dt)
			_anim(f, "Run")
			return true
		var climbing := 0
		for fi in r["figs"]:
			if figs[fi]["alive"] and figs[fi].get("state", "") == "climbing":
				climbing += 1
		if climbing < spots.size():
			f["state"] = "climbing"
			f["climb_t"] = 0.0
			f["climb_dur"] = 4.5 if r["kind"] == "nayzachi" else 3.2
			f["climb_base"] = Vector3(foot.x, h_at(foot.x, foot.z), foot.z)
			var w2 := _wall_point(my)
			f["climb_top"] = Vector3(w2.x, h_at(w2.x, w2.z) + 7.1, w2.z)
			node.rotation.y = atan2(-(w2.z - foot.z), w2.x - foot.x)
		else:
			_anim(f, "Block")
		return true
	# piyoda: nishon devorning narigi tomonida - teshik/darvozaga boradi yoki devor tagida kutadi
	if not _ranged(f["kind"]) and f["target"] >= 0 and figs[f["target"]]["alive"]:
		var e3: Dictionary = figs[f["target"]]
		if _inside(f["pos"]) != _inside(e3["pos"]):
			var ops := _openings()
			if ops.is_empty():
				if f["side"] == att_side and r["order"] == "attack":
					var foot2 := _wall_point(e3["pos"])
					foot2 += _outward(foot2) * 2.0
					if Vector2(foot2.x - f["pos"].x, foot2.z - f["pos"].z).length() > 1.5:
						_move(f, foot2, st["speed"], dt)
						_anim(f, "Run")
						return true
				_anim(f, "Block" if f["kind"] != "otliq" else "Idle")
				return true
			var best_op: Vector3 = ops[0]
			for op in ops:
				if (op as Vector3).distance_to(f["pos"]) < best_op.distance_to(f["pos"]):
					best_op = op
			var w3 := _wall_point(best_op)
			var side_out := _outward(w3) * (3.5 if not _inside(f["pos"]) else -3.5)
			var approach := best_op + side_out
			if Vector2(approach.x - f["pos"].x, approach.z - f["pos"].z).length() > 2.0 and Vector2(best_op.x - f["pos"].x, best_op.z - f["pos"].z).length() > 3.0:
				_move(f, approach, st["speed"], dt)
				_anim(f, "Run" if f["kind"] != "otliq" else "Gallop")
				return true
			# himoyachilar tashqariga chiqmaydi - teshik/darvoza ichida saf tortib turadi
			if f["side"] == def_side and _inside(f["pos"]):
				_face(f, best_op)
				_anim(f, "Block")
				return true
			# teshikdan o'tish
			_move(f, best_op - side_out, st["speed"], dt)
			_anim(f, "Run" if f["kind"] != "otliq" else "Gallop")
			return true
	return false


func _player_task() -> String:
	for id in Game.player_provinces():
		var c: Dictionary = Game.provinces[id].get("castle", {})
		if c.get("task", "") != "":
			return c["task"]
	return ""


func _wall_top(p: Vector3) -> Vector3:
	var w := _wall_point(p)
	return Vector3(w.x, h_at(w.x, w.z) + 7.1, w.z)


func _wall_slots_near(gp: Vector3, n: int, gap := 1.7) -> Array:
	## devor bo'ylab gp atrofida n ta joy (devor ustida, biroz ichkariroqda)
	var w := _wall_point(gp)
	var out := _outward(w)
	var along := Vector3(out.z, 0, -out.x)
	var res: Array = []
	for i in n:
		var k := (float(i) - float(n - 1) * 0.5) * gap
		var q := _wall_point(w + along * k)
		res.append(_wall_top(q) - _outward(q) * 0.4)
	return res


func _order_man_wall(r: Dictionary, gp: Vector3, instant: bool) -> void:
	var live: Array = r["figs"].filter(func(fi): return figs[fi]["alive"])
	var slots := _wall_slots_near(gp, live.size())
	var out := _outward(_wall_point(gp))
	for i in live.size():
		var f: Dictionary = figs[live[i]]
		f["post"] = slots[i]
		f["target"] = -1
		if instant:
			f["layer"] = "wall"
			f["state"] = ""
			f["pos"] = slots[i]
			(f["node"] as Node3D).position = f["pos"]
			(f["node"] as Node3D).rotation.y = atan2(-out.z, out.x)
			_anim(f, "Idle")
		elif f.get("layer", "ground") != "wall":
			f["state"] = "to_wall"
			f["stair_t"] = 0.0
		else:
			f["state"] = ""
	r["order"] = "hold"
	r["on_wall"] = true
	if tip_label and not instant:
		tip_label.text = "%s devorga chiqmoqda - narvon bilan chiqayotgan dushmanni yuqoridan qaytaradi." % NAMES[r["kind"]]


func _wall_walk(f: Dictionary, goal: Vector3, speed: float, dt: float) -> void:
	## devor ustida yurish (devor chizig'idan chiqmaydi)
	var d := Vector2(goal.x - f["pos"].x, goal.z - f["pos"].z)
	var L := d.length()
	if L < 0.05:
		return
	var step := d / L * minf(L, speed * dt)
	var np: Vector3 = f["pos"] + Vector3(step.x, 0, step.y)
	var top := _wall_top(np) - _outward(_wall_point(np)) * 0.4
	f["pos"] = top
	var node: Node3D = f["node"]
	node.position = top
	node.rotation.y = atan2(-step.y, step.x)


func _wall_melee(f: Dictionary, r: Dictionary, st: Dictionary, dt: float) -> bool:
	## devor ustidagi piyoda himoyachi: devorga chiqqan dushman bilan olishadi, narvondagilarni urib tushiradi
	var best: Dictionary = {}
	var bd := 18.0
	for e in figs:
		if not e["alive"] or e["side"] == f["side"]:
			continue
		var on_w: bool = e.get("layer", "ground") == "wall"
		var climbing: bool = e.get("state", "") == "climbing" and float(e["climb_t"]) / float(e["climb_dur"]) > 0.45
		if not on_w and not climbing:
			continue
		var d := Vector2(e["pos"].x - f["pos"].x, e["pos"].z - f["pos"].z).length()
		if d < bd:
			bd = d
			best = e
	if not best.is_empty():
		var reach := 2.6 if best.get("state", "") == "climbing" else 1.9
		if bd > reach:
			_wall_walk(f, best["pos"], st["speed"] * 0.9, dt)
			_anim(f, "Run")
			return true
		_face(f, best["pos"])
		if f["cd"] <= 0.0:
			f["cd"] = st["cd"]
			var dmg: float = st["dmg"] * _rng.randf_range(0.9, 1.3)
			if best.get("state", "") == "climbing":
				dmg *= 1.8        # narvonda turgan dushman himoyasiz
				if _rng.randf() < 0.18:
					dmg = 999.0       # narvondan itarib tushirdi
					tip_label.text = "Himoyachi dushmanni narvondan itarib tushirdi!"
			_hit(best, dmg)
			_anim(f, "Attack", true)
		elif f["anim"] != "Attack":
			_anim(f, "Block")
		return true
	# dushman yo'q - o'z joyiga qaytib, tashqariga qarab turadi
	var post: Vector3 = f.get("post", f["pos"])
	if Vector2(post.x - f["pos"].x, post.z - f["pos"].z).length() > 0.4:
		_wall_walk(f, post, st["speed"] * 0.6, dt)
		_anim(f, "Walk")
		return true
	var o := _outward(_wall_point(f["pos"]))
	(f["node"] as Node3D).rotation.y = lerp_angle((f["node"] as Node3D).rotation.y, atan2(-o.z, o.x), 0.1)
	if f["anim"] != "Idle" and f["anim"] != "Look":
		_anim(f, "Idle")
	return true


func _order_climb(r: Dictionary, gp: Vector3) -> void:
	var w := _wall_point(gp)
	var out := _outward(w)
	var along := Vector3(out.z, 0, -out.x)
	var n := 3 if r["kind"] == "nayzachi" else 2
	var spots: Array = []
	for k in n:
		var p: Vector3 = w + along * (k - (n - 1) * 0.5) * 2.6
		spots.append(p)
		# narvon yoki arqon modeli
		var gy := h_at(p.x, p.z)
		var foot := p + out * 1.3
		if r["kind"] == "nayzachi":
			var lad := Node3D.new()
			for sx in [-0.3, 0.3]:
				var rail := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.08, 7.8, 0.08)
				rail.mesh = bm
				rail.material_override = _eng_mat
				rail.position = Vector3(sx, 3.9, 0)
				lad.add_child(rail)
			for k2 in 12:
				var rung := MeshInstance3D.new()
				var rm := BoxMesh.new()
				rm.size = Vector3(0.6, 0.05, 0.05)
				rung.mesh = rm
				rung.material_override = _eng_mat
				rung.position = Vector3(0, 0.5 + k2 * 0.6, 0)
				lad.add_child(rung)
			world.add_child(lad)
			lad.position = Vector3(foot.x, gy, foot.z)
			lad.basis = Basis.looking_at(-out, Vector3.UP) * Basis(Vector3.RIGHT, -0.17)
		else:
			var rope := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.03
			cm.bottom_radius = 0.03
			cm.height = 7.4
			rope.mesh = cm
			var rmat := StandardMaterial3D.new()
			rmat.albedo_color = Color("#c8b48a")
			rope.material_override = rmat
			world.add_child(rope)
			rope.position = Vector3(p.x + out.x * 0.6, gy + 3.7, p.z + out.z * 0.6)
	r["order"] = "climb"
	r["climb_spots"] = spots
	tip_label.text = "%s %s bilan devorga chiqmoqda!" % [NAMES[r["kind"]], "narvonlar" if r["kind"] == "nayzachi" else "ilmoqli arqonlar"]


# ---------------------------------------------------------------- taran va manjaniq

func _spawn_engines() -> void:
	var defs := [["top", "To'p 1"], ["top", "To'p 2"], ["top", "To'p 3"]] if Game.era == 2 else [["taran", "Taran"], ["manjaniq", "Manjaniq 1"], ["manjaniq", "Manjaniq 2"]]
	for i in defs.size():
		var t: String = defs[i][0]
		var node := _engine_model(t)
		world.add_child(node)
		var p := Vector3(W * 0.17 - (0.0 if t == "taran" else 16.0), 0, H * 0.5 + (i - 1) * 24.0)
		p.y = h_at(p.x, p.z)
		node.position = p
		var disc := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 3.6
		cm.bottom_radius = 3.6
		cm.height = 0.05
		disc.mesh = cm
		disc.material_override = _disc_mats[att_side]
		disc.position.y = 0.1
		node.add_child(disc)
		engines.append({"i": i, "type": t, "name": defs[i][1], "node": node, "pos": p, "hp": 10.0 if t == "taran" else 8.0,
			"max": 10.0 if t == "taran" else 8.0, "target": cs["gate"] if t == "taran" else -1, "cd": 3.0, "disc": disc, "go": false})


func _engine_model(t: String) -> Node3D:
	if t == "top":
		var cn := Unit3D.cannon(colors[att_side])
		cn.scale = Vector3.ONE * 1.3
		return cn
	var root := Node3D.new()
	var wood := _eng_mat
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("#3a2a1a")
	var add := func(size: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = size
		mi.mesh = b
		mi.material_override = m
		mi.position = pos
		mi.rotation = rot
		root.add_child(mi)
		return mi
	if t == "taran":
		add.call(Vector3(5.0, 0.3, 2.2), Vector3(0, 0.9, 0), wood)
		for sx in [-2.2, 2.2]:
			for sz in [-1.0, 1.0]:
				add.call(Vector3(0.2, 2.2, 0.2), Vector3(sx, 2.0, sz), wood)
		add.call(Vector3(5.4, 0.15, 1.6), Vector3(0, 3.3, 0.7), dark, Vector3(deg_to_rad(35), 0, 0))
		add.call(Vector3(5.4, 0.15, 1.6), Vector3(0, 3.3, -0.7), dark, Vector3(deg_to_rad(-35), 0, 0))
		var log := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.3
		cm.bottom_radius = 0.3
		cm.height = 6.4
		log.mesh = cm
		log.material_override = dark
		log.rotation.z = PI / 2.0
		log.position = Vector3(0.8, 1.9, 0)
		log.name = "Log"
		root.add_child(log)
	else:
		add.call(Vector3(4.2, 0.5, 3.0), Vector3(0, 0.8, 0), wood)
		for sz in [-1.2, 1.2]:
			add.call(Vector3(0.3, 5.0, 0.3), Vector3(0, 3.3, sz), wood, Vector3(0, 0, deg_to_rad(8)))
		var arm := Node3D.new()
		arm.position = Vector3(0.3, 5.6, 0)
		arm.name = "Arm"
		root.add_child(arm)
		var beam := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(8.0, 0.25, 0.25)
		beam.mesh = bm
		beam.material_override = dark
		beam.position = Vector3(-2.0, 0, 0)
		arm.add_child(beam)
		var cw := MeshInstance3D.new()
		var cbm := BoxMesh.new()
		cbm.size = Vector3(1.2, 1.4, 1.4)
		cw.mesh = cbm
		cw.material_override = wood
		cw.position = Vector3(1.8, -0.8, 0)
		arm.add_child(cw)
		arm.rotation.z = deg_to_rad(-35)
	for sx in [-1.6, 1.6]:
		for sz in [-1.3, 1.3]:
			var wh := MeshInstance3D.new()
			var wm := CylinderMesh.new()
			wm.top_radius = 0.55
			wm.bottom_radius = 0.55
			wm.height = 0.2
			wh.mesh = wm
			wh.material_override = dark
			wh.rotation.x = PI / 2.0
			wh.position = Vector3(sx, 0.55, sz)
			root.add_child(wh)
	return root


func _engine_at(p: Vector3) -> int:
	for e in engines:
		if e["hp"] > 0.0 and Vector2(e["pos"].x - p.x, e["pos"].z - p.z).length() < 4.0:
			return e["i"]
	return -1


func _select_engine(i: int) -> void:
	if sel_eng >= 0:
		(engines[sel_eng]["disc"] as MeshInstance3D).material_override = _disc_mats[att_side]
	sel_eng = i
	if i >= 0:
		(engines[i]["disc"] as MeshInstance3D).material_override = _sel_mat
		var e: Dictionary = engines[i]
		tip_label.text = ("%s tanlandi. O'ng tugma bilan darvozani bosing - taran unga boradi va uradi." if e["type"] == "taran"
			else ("%s tanlandi. O'ng tugma bilan devor yoki darvozani bosing - to'p uni o'qqa tutadi (masofa 250 m gacha)." if e["type"] == "top"
			else "%s tanlandi. O'ng tugma bilan devorni bosing - manjaniq tosh otib uni buzadi (masofa 60-200 m).")) % e["name"]
		_refresh_ui()


func _order_engine(gp: Vector3) -> void:
	var e: Dictionary = engines[sel_eng]
	if e["hp"] <= 0.0:
		return
	if phase == "deploy":
		_begin()
	if e["type"] == "taran":
		e["target"] = cs["gate"]
		e["go"] = true
		tip_label.text = "Taran darvozaga yo'l oldi!"
		return
	var best := -1
	var bd := 12.0
	for si in cs["segs"].size():
		var sg: Dictionary = cs["segs"][si]
		var d := Vector2(sg["center"].x - gp.x, sg["center"].z - gp.z).length()
		if sg["hp"] > 0 and d < bd:
			bd = d
			best = si
	if best < 0:
		tip_label.text = "Manjaniq uchun devor ustini bosing."
		return
	e["target"] = best
	e["go"] = true
	tip_label.text = "%s devorni o'qqa tutmoqda." % e["name"]


func _update_engines(dt: float) -> void:
	for e in engines:
		if e["hp"] <= 0.0:
			continue
		var node: Node3D = e["node"]
		# devordagi kamonchilar qamal qurollarini o'qqa tutadi
		var archers := 0
		for f in figs:
			if f["alive"] and f["side"] == def_side and _ranged(f["kind"]) and Vector2(f["pos"].x - e["pos"].x, f["pos"].z - e["pos"].z).length() < 70.0:
				archers += 1
		e["hp"] -= archers * 0.012 * dt
		if e["hp"] <= 0.0:
			var tw := node.create_tween()
			tw.tween_property(node, "rotation:z", 0.5, 0.8)
			(e["disc"] as Node3D).visible = false
			tip_label.text = "%s yo'q qilindi!" % e["name"]
			continue
		if not e["go"] or e["target"] < 0:
			continue
		var sg: Dictionary = cs["segs"][e["target"]]
		if sg["hp"] <= 0.0:
			e["go"] = false
			continue
		var c: Vector3 = sg["center"]
		var out := _outward(_wall_point(c))
		e["cd"] -= dt
		if e["type"] == "taran":
			var goal: Vector3 = c + out * 3.8
			var d := Vector2(goal.x - e["pos"].x, goal.z - e["pos"].z)
			var rg := _ford_route(e["pos"], goal)
			if rg != goal:
				d = Vector2(rg.x - e["pos"].x, rg.z - e["pos"].z) + d.normalized() * 0.7
			if d.length() > 0.6:
				var sp := 2.2 * (0.35 if absf(e["pos"].x - river_x(e["pos"].z)) < 9.0 and not is_ford(e["pos"].z) else 1.0)
				var step := d.normalized() * minf(d.length(), sp * dt)
				e["pos"] += Vector3(step.x, 0, step.y)
				e["pos"].y = h_at(e["pos"].x, e["pos"].z)
				node.position = e["pos"]
				node.rotation.y = atan2(-d.y, d.x)
			elif e["cd"] <= 0.0:
				e["cd"] = 2.0
				sg["hp"] -= 1.0
				var lg: Node3D = node.get_node_or_null("Log")
				if lg:
					var tw2 := lg.create_tween()
					tw2.tween_property(lg, "position:x", 2.0, 0.12)
					tw2.tween_property(lg, "position:x", 0.8, 0.5)
				if sg["hp"] <= 0.0:
					_breach(sg)
					tip_label.text = "DARVOZA BUZILDI! Askarlarni ichkariga yuboring."
		elif e["type"] == "top":
			var d3 := Vector2(c.x - e["pos"].x, c.z - e["pos"].z)
			if d3.length() > 240.0:
				var step3 := d3.normalized() * minf(d3.length() - 235.0, 1.6 * dt)
				e["pos"] += Vector3(step3.x, 0, step3.y)
				e["pos"].y = h_at(e["pos"].x, e["pos"].z)
				node.position = e["pos"]
			node.rotation.y = lerp_angle(node.rotation.y, atan2(-d3.y, d3.x), 0.1)
			if d3.length() <= 250.0 and e["cd"] <= 0.0:
				e["cd"] = 5.0 * _rng.randf_range(0.85, 1.2)
				var fake := {"node": node, "pos": e["pos"]}
				_cannon_shot(fake, c + Vector3(0, h_at(c.x, c.z) + 3.0, 0), e["target"])
				var last: Dictionary = stones[stones.size() - 1]
				last["to"] = c + Vector3(_rng.randf_range(-2.5, 2.5), h_at(c.x, c.z) + 3.0, _rng.randf_range(-2.5, 2.5))
		else:
			var d2 := Vector2(c.x - e["pos"].x, c.z - e["pos"].z)
			if d2.length() > 190.0:
				var step2 := d2.normalized() * minf(d2.length() - 185.0, 1.4 * dt)
				e["pos"] += Vector3(step2.x, 0, step2.y)
				e["pos"].y = h_at(e["pos"].x, e["pos"].z)
				node.position = e["pos"]
			node.rotation.y = lerp_angle(node.rotation.y, atan2(-d2.y, d2.x), 0.1)
			if d2.length() <= 200.0 and e["cd"] <= 0.0:
				e["cd"] = 6.5
				var arm: Node3D = node.get_node_or_null("Arm")
				if arm:
					var tw3 := arm.create_tween()
					tw3.tween_property(arm, "rotation:z", deg_to_rad(80), 0.35)
					tw3.tween_property(arm, "rotation:z", deg_to_rad(-35), 2.5)
				var stone := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 0.45
				sm.height = 0.9
				stone.mesh = sm
				var stm := StandardMaterial3D.new()
				stm.albedo_color = Color("#8a8278")
				stone.material_override = stm
				world.add_child(stone)
				var to := c + Vector3(_rng.randf_range(-3, 3), h_at(c.x, c.z) + 4.0, _rng.randf_range(-3, 3))
				stones.append({"node": stone, "from": e["pos"] + Vector3(0, 8.0, 0), "to": to, "t": 0.0, "dur": 3.0, "seg": e["target"]})


func _update_stones(dt: float) -> void:
	for st in stones.duplicate():
		st["t"] += dt
		var k: float = st["t"] / st["dur"]
		var a: Vector3 = st["from"]
		var b: Vector3 = st["to"]
		(st["node"] as Node3D).position = a.lerp(b, k) + Vector3(0, float(st.get("arc", 55.0)) * 4.0 * k * (1.0 - k), 0)
		if k >= 1.0:
			stones.erase(st)
			(st["node"] as Node3D).queue_free()
			if int(st["seg"]) < 0 or not siege:
				for f in figs:
					if f["alive"] and f["pos"].distance_to(b) < float(st.get("r", 3.5)):
						_hit(f, float(st.get("dmg", 1.5)) * _rng.randf_range(0.6, 1.2))
				_dust_puff(b)
				continue
			var sg: Dictionary = cs["segs"][st["seg"]]
			if _rng.randf() < 0.8 and sg["hp"] > 0.0:
				sg["hp"] -= 1.0
				for n in sg["nodes"]:
					var nd: Node3D = n
					var tw := nd.create_tween()
					tw.tween_property(nd, "position:x", nd.position.x + 0.15, 0.05)
					tw.tween_property(nd, "position:x", nd.position.x, 0.1)
				if sg["hp"] <= 0.0:
					_breach(sg)
					tip_label.text = "DEVOR TESHILDI! Askarlar teshikdan kirishi mumkin."
			# yaqin turgan himoyachilar halok bo'ladi
			for f in figs:
				if f["alive"] and f["pos"].distance_to(b) < 3.5:
					_hit(f, 1.5)
			_dust_puff(b)


func _breach(sg: Dictionary) -> void:
	## devor bo'lagi / darvoza qulaydi: modellar yerga cho'kadi, o'rnida xarsang uyumi
	sg["hp"] = 0.0
	for n in sg["nodes"]:
		var nd: Node3D = n
		var tw := nd.create_tween()
		tw.tween_property(nd, "position:y", nd.position.y - 6.6, 1.2)
		tw.tween_callback(func(): nd.visible = false)
	var c: Vector3 = sg["center"]
	for k in 7:
		var rb := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(_rng.randf_range(0.8, 1.8), _rng.randf_range(0.5, 1.2), _rng.randf_range(0.8, 1.6))
		rb.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("#b49a72").darkened(_rng.randf() * 0.3)
		rb.material_override = m
		rb.position = c + Vector3(_rng.randf_range(-3.5, 3.5), h_at(c.x, c.z) + 0.3, _rng.randf_range(-3.5, 3.5))
		rb.rotation = Vector3(_rng.randf(), _rng.randf(), _rng.randf())
		world.add_child(rb)
	_dust_puff(c + Vector3(0, 2, 0))
	_refresh_ui()


func _dust_puff(p: Vector3) -> void:
	var d := FX.dust(2.5)
	d.position = p
	d.one_shot = true
	d.emitting = true
	world.add_child(d)
	get_tree().create_timer(4.0).timeout.connect(d.queue_free)
