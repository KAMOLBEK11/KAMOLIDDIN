extends Node
## Ovozlar (autoload: Sfx). Barcha ovozlar res://sounds/sfx/ da (sounds/synth.py bilan noldan sintez qilingan).
## Bir xil nomli bir nechta variant (qilich_0..4) bo'lsa - har gal tasodifiy biri va biroz boshqa balandlikda chalinadi.
##   Sfx.play("tugma")                         - interfeys ovozi (makonsiz)
##   Sfx.at("qilich", pos, world)              - 3D makonda (kameradan uzoqlashgan sari pasayadi)
##   Sfx.loop("qadam", "qadam", -12.0)         - uzluksiz fon ovozi; Sfx.loop_vol("qadam", -6.0) - silliq o'zgartirish

const DIR := "res://audio/sfx/"
const MAX_ONESHOT := 28          # bir vaqtda eng ko'p chalinadigan qisqa ovozlar
const MIN_GAP := 0.06            # bir xil ovoz shuncha soniyadan tez-tez takrorlanmaydi

var streams := {}                # asosiy nom -> [AudioStream, ...]
var volume_db := 0.0             # umumiy sozlama (ovoz balandligi)
var muted := false
var _last := {}
var _busy := 0
var _loops := {}                 # kalit -> {"p": AudioStreamPlayer, "target": db}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_scan()
	get_tree().node_added.connect(_on_node)


func _scan() -> void:
	var d := DirAccess.open(DIR)
	if d == null:
		return
	var seen := {}
	for f in d.get_files():
		var fn := f.trim_suffix(".import").trim_suffix(".remap")
		if not (fn.ends_with(".ogg") or fn.ends_with(".wav")) or seen.has(fn):
			continue
		seen[fn] = true
		var st: AudioStream = load(DIR + fn)
		if st == null:
			continue
		var stem := fn.get_basename()
		var base := stem
		var parts := stem.rsplit("_", true, 1)
		if parts.size() == 2 and parts[1].is_valid_int():
			base = parts[0]
		if not streams.has(base):
			streams[base] = []
		streams[base].append(st)


func has(name: String) -> bool:
	return streams.has(name)


func _pick(name: String) -> AudioStream:
	var arr: Array = streams.get(name, [])
	if arr.is_empty():
		return null
	return arr[_rng.randi() % arr.size()]


func _ok(name: String, gap: float) -> bool:
	if muted or _busy >= MAX_ONESHOT:
		return false
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(name, -10.0)) < gap:
		return false
	_last[name] = now
	return true


func play(name: String, vol := 0.0, pitch_var := 0.05, gap := MIN_GAP) -> void:
	## makonsiz ovoz (interfeys, umumiy signal)
	var st := _pick(name)
	if st == null or not _ok(name, gap):
		return
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.volume_db = vol + volume_db
	p.pitch_scale = 1.0 + _rng.randf_range(-pitch_var, pitch_var)
	add_child(p)
	_start(p)


func at(name: String, pos: Vector3, parent: Node, vol := 0.0, pitch_var := 0.08, gap := MIN_GAP, unit := 22.0) -> void:
	## 3D ovoz: parent - 3D dunyodagi tugun (jang/qal'a "world"); ovoz kameradan uzoqlashgan sari pasayadi
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var st := _pick(name)
	if st == null:
		return
	var cam := parent.get_viewport().get_camera_3d()
	if cam:
		# juda uzoqdagi ovozlar umuman chalinmaydi (ko'p askarli jangda shovqin bo'lmasin)
		var dist := cam.global_position.distance_to(pos)
		if dist > unit * 14.0:
			return
	if not _ok(name, gap):
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = st
	p.volume_db = vol + volume_db
	p.unit_size = unit
	p.max_db = 3.0
	p.max_distance = unit * 16.0
	p.panning_strength = 0.6
	p.attenuation_filter_cutoff_hz = 9000.0
	p.attenuation_filter_db = -12.0
	p.pitch_scale = 1.0 + _rng.randf_range(-pitch_var, pitch_var)
	parent.add_child(p)
	p.global_position = pos
	_start(p)


func _start(p: Node) -> void:
	_busy += 1
	p.finished.connect(func():
		_busy -= 1
		p.queue_free())
	p.tree_exiting.connect(func():
		if p.playing:
			_busy -= 1)
	p.call("play")


# ------------------------------------------------------------------ uzluksiz fon ovozlari

func loop(key: String, name: String, vol := 0.0, fade_in := 1.0) -> void:
	if _loops.has(key):
		if (_loops[key]["name"] as String) == name:
			loop_vol(key, vol)
			return
		stop_loop(key, 0.6)
	var st := _pick(name)
	if st == null:
		return
	st = st.duplicate()
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = true
	elif st is AudioStreamWAV:
		(st as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(st as AudioStreamWAV).loop_end = int((st as AudioStreamWAV).get_length() * (st as AudioStreamWAV).mix_rate)
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.volume_db = -60.0
	add_child(p)
	p.play(_rng.randf_range(0.0, maxf(0.0, st.get_length() - 0.5)))
	_loops[key] = {"p": p, "target": vol, "name": name, "speed": 60.0 / maxf(0.05, fade_in)}


func loop_vol(key: String, vol: float, fade := 0.6) -> void:
	if _loops.has(key):
		_loops[key]["target"] = vol
		_loops[key]["speed"] = 30.0 / maxf(0.05, fade)


func stop_loop(key: String, fade := 0.8) -> void:
	if not _loops.has(key):
		return
	var p: AudioStreamPlayer = _loops[key]["p"]
	_loops.erase(key)
	var tw := p.create_tween()
	tw.tween_property(p, "volume_db", -60.0, fade)
	tw.tween_callback(p.queue_free)


func stop_loops(prefix := "") -> void:
	for k in _loops.keys():
		if prefix == "" or (k as String).begins_with(prefix):
			stop_loop(k)


func _process(delta: float) -> void:
	for k in _loops:
		var L: Dictionary = _loops[k]
		var p: AudioStreamPlayer = L["p"]
		var tgt: float = (-60.0 if muted else float(L["target"]) + volume_db)
		p.volume_db = move_toward(p.volume_db, tgt, float(L["speed"]) * delta)


# ------------------------------------------------------------------ interfeys: har tugma bosilganda "chiq"

func _on_node(n: Node) -> void:
	if n is BaseButton and not n.has_meta("snd"):
		n.set_meta("snd", true)
		(n as BaseButton).pressed.connect(func(): play("tugma", -8.0, 0.08, 0.03))


# ------------------------------------------------------------------ tugmalar: F8 - ovozni o'chirish/yoqish, F9 - pasaytirish, F10 - balandlatish

func _unhandled_key_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	match (e as InputEventKey).keycode:
		KEY_F8:
			muted = not muted
		KEY_F9:
			volume_db = maxf(-30.0, volume_db - 3.0)
		KEY_F10:
			volume_db = minf(6.0, volume_db + 3.0)
