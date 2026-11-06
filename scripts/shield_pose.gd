class_name ShieldPose
extends SkeletonModifier3D
## Qalqonli askarning chap qo'li (animatsiya ustidan):
##  - "front" (odatiy): qalqon ko'krak oldida, yuzi oldinga (dushmanga) qaragan - yon tomonga emas
##  - "up" (toshbaqa): qalqon boshi ustida, tom kabi
## Har qanday askar skeletida ishlaydi (UpperArm.L / UpperArm_L ...).

var amount := 0.0            # up kuchi
var target := 0.0
var front := 0.0             # front kuchi
var front_target := 1.0
var _ua := -1
var _fa := -1
var _hd := -1
var _sb := -1                # qalqon bog'langan suyak
var _n_local := Vector3.ZERO # qalqon yuzining normali (shu suyak fazosida)
var _ready_b := false
var _gem := false            # Gemini modeli (qalqon Offhand_Mount suyagida)
var _fwd_cache := Vector3.ZERO


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
	var m := attach(n)
	if m:
		m.target = 1.0 if on else 0.0


static func set_front(n: Node3D, on: bool) -> void:
	var m := _find(n)
	if m:
		m.front_target = 1.0 if on else 0.0
	elif on:
		m = attach(n)


static func _find(n: Node3D) -> ShieldPose:
	for c in n.find_children("ShieldPose", "SkeletonModifier3D", true, false):
		return c
	return null


func _bone_any(sk: Skeleton3D, names: Array) -> int:
	for nm in names:
		var i := sk.find_bone(nm)
		if i >= 0:
			return i
	return -1


func _bones(sk: Skeleton3D) -> void:
	_ready_b = true
	_ua = _bone_any(sk, ["UpperArm.L", "UpperArm_L"])
	_fa = _bone_any(sk, ["ForeArm.L", "Forearm_L", "ForeArm_L"])
	_hd = _bone_any(sk, ["Hand.L", "Hand_L"])
	var f := _fwd(sk)
	var mt := sk.find_bone("Offhand_Mount")
	if mt >= 0:
		_gem = true
		_sb = mt
		_n_local = sk.get_bone_global_rest(mt).basis.inverse() * f
		return
	# Blender modellari: qalqon - suyakka bog'langan alohida tugun (BoneAttachment3D ichida "Shield")
	for ba in sk.get_children():
		if not ba is BoneAttachment3D:
			continue
		for ch in (ba as Node).find_children("Shield*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = ch
			var ab := mi.get_aabb()
			var ax := Vector3(1, 0, 0)
			if ab.size.y < ab.size.x and ab.size.y < ab.size.z:
				ax = Vector3(0, 1, 0)
			elif ab.size.z < ab.size.x and ab.size.z < ab.size.y:
				ax = Vector3(0, 0, 1)
			var rel: Transform3D = (ba as Node3D).global_transform.affine_inverse() * mi.global_transform if mi.is_inside_tree() else mi.transform
			var b := (ba as BoneAttachment3D).bone_idx
			var n := (rel.basis * ax).normalized()
			if (sk.get_bone_global_rest(b).basis * n).dot(f) < 0.0:
				n = -n
			_sb = b
			_n_local = n
			return


func _fwd(sk: Skeleton3D) -> Vector3:
	if _fwd_cache != Vector3.ZERO:
		return _fwd_cache
	var l := _bone_any(sk, ["UpperArm.L", "UpperArm_L"])
	var r := _bone_any(sk, ["UpperArm.R", "UpperArm_R"])
	if l < 0 or r < 0:
		_fwd_cache = Vector3(1, 0, 0)
		return _fwd_cache
	var side := sk.get_bone_global_rest(l).origin - sk.get_bone_global_rest(r).origin
	side.y = 0
	var f := Vector3(-side.z, 0, side.x).normalized()
	_fwd_cache = f if f.length() > 0.1 else Vector3(1, 0, 0)
	return _fwd_cache


func _left(sk: Skeleton3D) -> Vector3:
	var f := _fwd(sk)
	return Vector3(f.z, 0, -f.x)      # oldinga qaraganda chap tomon


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if not _ready_b:
		_bones(sk)
	amount = move_toward(amount, target, 0.06)
	front = move_toward(front, front_target, 0.08)
	if _ua < 0 or _fa < 0:
		return
	var f := _fwd(sk)
	var lft := _left(sk)
	var up := Vector3.UP
	var kf := front * (1.0 - amount)
	if kf > 0.001:
		# qalqon ko'krak oldida: yelka pastga-oldinga, bilak ko'krak bo'ylab, qalqon yuzi oldinga
		_aim(sk, _ua, _fa, (-up * 0.8 + f * 0.45 + lft * 0.25).normalized(), kf)
		_aim(sk, _fa, _hd, (f * 0.75 - lft * 0.55 + up * 0.25).normalized(), kf)
		_face(sk, f, kf)
	if amount > 0.001:
		# toshbaqa: yelka tepaga, bilak boshi ustida ko'ndalang (qalqon tagida) - qo'l qalqondan chiqmaydi
		if not _gem:
			# Blender modellari: qalqon musht oldida (bilak yo'nalishida) - bilak tepaga, qalqon boshi ustida yotadi
			_aim(sk, _ua, _fa, (up + f * 0.15).normalized(), amount)
			_aim(sk, _fa, _hd, (up + f * 0.05).normalized(), amount)
		else:
			_aim(sk, _ua, _fa, (up * 0.8 + f * 0.3 + lft * 0.3).normalized(), amount)
			_aim(sk, _fa, _hd, (-lft * 0.85 + f * 0.3 + up * 0.08).normalized(), amount)
		_face(sk, (up + f * 0.12).normalized(), amount)
		if _gem and _hd >= 0:
			# Gemini: qalqon mushtdan biroz yuqorida turadi - qo'l qalqon tagida qoladi, teshib chiqmaydi
			var g := sk.get_bone_global_pose(_sb)
			var hp := sk.get_bone_global_pose(_hd).origin
			g.origin = g.origin.lerp(hp + up * 0.42, amount)
			sk.set_bone_global_pose(_sb, g)
			sk.force_update_bone_child_transform(_sb)


func _face(sk: Skeleton3D, want: Vector3, k: float) -> void:
	## qalqon yuzini kerakli tomonga burish (qalqon bog'langan suyakni o'z atrofida)
	if _sb < 0 or _n_local == Vector3.ZERO:
		return
	var g := sk.get_bone_global_pose(_sb)
	var cur := (g.basis * _n_local).normalized()
	var q: Quaternion
	if _sb == _fa or _sb == _hd or _sb == _ua:
		# qo'l suyagi: faqat o'z o'qi atrofida buriladi (bilak yo'nalishi o'zgarmaydi)
		var ax := g.basis.y.normalized()
		var c2 := (cur - ax * cur.dot(ax))
		var w2 := (want - ax * want.dot(ax))
		if c2.length() < 0.01 or w2.length() < 0.01:
			return
		c2 = c2.normalized()
		w2 = w2.normalized()
		var ang := atan2(ax.dot(c2.cross(w2)), c2.dot(w2))
		q = Quaternion(ax, ang)
	else:
		q = Quaternion(cur, want) if cur.dot(want) > -0.999 else Quaternion(Vector3.UP, PI)
	var nb := Basis(Quaternion.IDENTITY.slerp(q, k)) * g.basis
	sk.set_bone_global_pose(_sb, Transform3D(nb, g.origin))
	sk.force_update_bone_child_transform(_sb)


func _aim(sk: Skeleton3D, b: int, child: int, want: Vector3, k: float) -> void:
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
	var nb := Basis(Quaternion.IDENTITY.slerp(q, k)) * g.basis
	sk.set_bone_global_pose(b, Transform3D(nb, g.origin))
	sk.force_update_bone_child_transform(b)
