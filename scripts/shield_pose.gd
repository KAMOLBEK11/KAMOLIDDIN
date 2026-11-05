class_name ShieldPose
extends SkeletonModifier3D
## Qalqonni boshi ustiga ko'tarish ("toshbaqa" safi): chap qo'l animatsiya ustidan yuqoriga buriladi.
## amount 0..1 - silliq ko'tarish/tushirish. Har qanday askar skeletida ishlaydi (UpperArm.L / UpperArm_L ...).

var amount := 0.0
var target := 0.0
var _ua := -1
var _fa := -1
var _hd := -1
var _mt := -1                 # Offhand_Mount (qalqon shu suyakka bog'langan modellarda)
var _n_local := Vector3.ZERO  # qalqon yuzining normali (suyak fazosida)
var _ready_b := false


static func attach(n: Node3D) -> ShieldPose:
	var sk: Skeleton3D = null
	for c in n.find_children("*", "Skeleton3D", true, false):
		sk = c
		break
	if sk == null:
		return null
	for c in sk.get_children():
		if c is ShieldPose:
			return c
	var m := ShieldPose.new()
	m.name = "ShieldPose"
	sk.add_child(m)
	return m


static func set_up(n: Node3D, on: bool) -> void:
	var m := attach(n) if on else _find(n)
	if m:
		m.target = 1.0 if on else 0.0


static func _find(n: Node3D) -> ShieldPose:
	for c in n.find_children("ShieldPose", "SkeletonModifier3D", true, false):
		return c
	return null


func _bones(sk: Skeleton3D) -> void:
	_ready_b = true
	for nm in ["UpperArm.L", "UpperArm_L", "upperarm.L"]:
		if sk.find_bone(nm) >= 0:
			_ua = sk.find_bone(nm)
	for nm in ["ForeArm.L", "Forearm_L", "ForeArm_L", "forearm.L"]:
		if sk.find_bone(nm) >= 0:
			_fa = sk.find_bone(nm)
	for nm in ["Hand.L", "Hand_L", "hand.L"]:
		if sk.find_bone(nm) >= 0:
			_hd = sk.find_bone(nm)
	_mt = sk.find_bone("Offhand_Mount")
	if _mt >= 0:
		# tinch holatda qalqon oldinga qaragan: normal = oldinga
		_n_local = sk.get_bone_global_rest(_mt).basis.inverse() * _fwd(sk)


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if not _ready_b:
		_bones(sk)
	amount = move_toward(amount, target, 0.06)
	if amount <= 0.001 or _ua < 0 or _fa < 0:
		return
	# skelet fazosida: askar +X ga qaraydi (Blender modellari) yoki +Z (Gemini) - oldinga yo'nalishni sonlardan topamiz
	var up := Vector3.UP
	_aim(sk, _ua, _fa, (up + _fwd(sk) * 0.15).normalized())
	_aim(sk, _fa, _hd if _hd >= 0 else -1, (up + _fwd(sk) * 0.05).normalized())
	if _mt >= 0 and _n_local != Vector3.ZERO:
		# qalqon yuzi tepaga qarasin (tom kabi yotib tursin)
		var g := sk.get_bone_global_pose(_mt)
		var cur := (g.basis * _n_local).normalized()
		var want := (Vector3.UP + _fwd(sk) * 0.25).normalized()
		var q := Quaternion(cur, want) if cur.dot(want) > -0.999 else Quaternion(_fwd(sk), PI)
		var nb := Basis(Quaternion.IDENTITY.slerp(q, amount)) * g.basis
		sk.set_bone_global_pose(_mt, Transform3D(nb, g.origin))


var _fwd_cache := Vector3.ZERO


func _fwd(sk: Skeleton3D) -> Vector3:
	if _fwd_cache != Vector3.ZERO:
		return _fwd_cache
	# chap va o'ng yelka orasidagi chiziqqa tik gorizontal yo'nalish (+ ko'krak tomoni noma'lum - +X/+Z dan tanlanadi)
	var l := sk.find_bone("UpperArm.L") if sk.find_bone("UpperArm.L") >= 0 else sk.find_bone("UpperArm_L")
	var r := sk.find_bone("UpperArm.R") if sk.find_bone("UpperArm.R") >= 0 else sk.find_bone("UpperArm_R")
	if l < 0 or r < 0:
		_fwd_cache = Vector3(1, 0, 0)
		return _fwd_cache
	var side := sk.get_bone_global_rest(l).origin - sk.get_bone_global_rest(r).origin
	side.y = 0
	var f := Vector3(-side.z, 0, side.x).normalized()      # chap -> o'ng ga tik (o'ng qo'l qoidasi bo'yicha oldinga)
	_fwd_cache = f if f.length() > 0.1 else Vector3(1, 0, 0)
	return _fwd_cache


func _aim(sk: Skeleton3D, b: int, child: int, want: Vector3) -> void:
	var g := sk.get_bone_global_pose(b)
	var tip: Vector3
	if child >= 0:
		tip = sk.get_bone_global_pose(child).origin
	else:
		tip = g.origin + g.basis.y.normalized() * 0.25
	var cur := (tip - g.origin)
	if cur.length() < 0.0001:
		return
	cur = cur.normalized()
	var q := Quaternion(cur, want) if cur.dot(want) > -0.999 else Quaternion(Vector3.FORWARD, PI)
	var qa := Quaternion.IDENTITY.slerp(q, amount)
	var nb := Basis(qa) * g.basis
	sk.set_bone_global_pose(b, Transform3D(nb, g.origin))
