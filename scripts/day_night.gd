class_name DayNight
extends Node3D
## Qal'a sahnasi uchun kecha-kunduz, ob-havo va azon.
##  - Soat (0..24) o'yin tezligiga qarab yuradi: 1x da bir sutka = REAL_DAY soniya (pauzada to'xtaydi).
##  - Quyosh aylanadi, osmon/yorug'lik rangi o'zgaradi, tunda oy nuri va mash'alalar.
##  - Ob-havo: ochiq, bulutli, yomg'ir, qor (qishda), chang bo'roni (yozda) - har bir necha soatda almashadi.
##  - Musulmon davlatlarda namoz vaqtlarida azon: sounds/azon.ogg yoki sounds/azon.mp3 fayli bo'lsa ijro etiladi.

signal prayer(name: String)

const REAL_DAY := 300.0         # 1x tezlikda bir sutka (soniya)
const PRAYERS := [[5.0, "Bomdod"], [12.5, "Peshin"], [16.0, "Asr"], [18.6, "Shom"], [20.2, "Xufton"]]
const W_NAMES := {"ochiq": "Ochiq havo", "bulut": "Bulutli", "yomgir": "Yomg'ir", "qor": "Qor", "chang": "Chang bo'roni"}

var hour := 8.0
var weather := "ochiq"
var _wmix := 0.0               # 0..1 - yomon ob-havo kuchi (silliq o'tish)
var _wnext := 0.0              # ob-havo almashguncha qolgan soat
var env: Environment
var sky: ProceduralSkyMaterial
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var cam: Camera3D
var muslim := false
var minaret_pos = null          # Vector3 yoki null - azon tovushi shu yerdan keladi
var torches: Array = []         # tunda yonadigan OmniLight3D lar
var _rain: CPUParticles3D
var _snow: CPUParticles3D
var _dust: CPUParticles3D
var _azan: AudioStreamPlayer3D
var _last_prayer := -1
var _base_fog := 0.0006
var _rng := RandomNumberGenerator.new()


func setup(world_env: WorldEnvironment, s: DirectionalLight3D, camera: Camera3D, is_muslim: bool) -> void:
	env = world_env.environment
	sky = env.sky.sky_material as ProceduralSkyMaterial
	sun = s
	cam = camera
	muslim = is_muslim
	_base_fog = env.fog_density
	_rng.randomize()
	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 0.9)
	moon.light_energy = 0.0
	moon.shadow_enabled = false
	moon.rotation_degrees = Vector3(-55, 140, 0)
	add_child(moon)
	_rain = _particles(Color(0.75, 0.8, 0.9, 0.7), Vector3(0.06, 1.8, 0.06), 3500, 26.0, Vector3(0, -1, 0.08), 1.2)
	_snow = _particles(Color(1, 1, 1, 0.95), Vector3(0.22, 0.22, 0.22), 2400, 3.0, Vector3(0.2, -1, 0.1), 6.0)
	_dust = _particles(Color(0.78, 0.66, 0.46, 0.35), Vector3(0.6, 0.6, 0.6), 900, 14.0, Vector3(1, -0.05, 0.3), 4.0)
	_azan = AudioStreamPlayer3D.new()
	_azan.unit_size = 60.0
	_azan.max_distance = 2000.0
	_azan.volume_db = 2.0
	add_child(_azan)
	var st := _load_azan()
	if st != null:
		_azan.stream = st
	_pick_weather()
	_apply()


func _particles(col: Color, sz: Vector3, n: int, speed: float, dir: Vector3, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var m := BoxMesh.new()
	m.size = sz
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = col
	m.material = mat
	p.mesh = m
	p.amount = n
	p.lifetime = life
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(90, 2, 90)
	p.direction = dir
	p.spread = 6.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = speed * 0.85
	p.initial_velocity_max = speed * 1.15
	p.local_coords = false
	p.emitting = false
	add_child(p)
	return p


func _load_azan() -> AudioStream:
	for ext in ["ogg", "mp3", "wav"]:
		var path := ProjectSettings.globalize_path("res://sounds/azon.%s" % ext)
		if not FileAccess.file_exists(path):
			continue
		if ext == "ogg":
			return AudioStreamOggVorbis.load_from_file(path)
		if ext == "mp3":
			var s := AudioStreamMP3.new()
			s.data = FileAccess.get_file_as_bytes(path)
			return s
		if ResourceLoader.exists("res://sounds/azon.wav"):
			return load("res://sounds/azon.wav")
	return null


func _pick_weather() -> void:
	var month := _month()
	var r := _rng.randf()
	var winter := month in [12, 1, 2]
	var summer := month in [6, 7, 8]
	if winter:
		weather = "qor" if r < 0.3 else ("bulut" if r < 0.55 else ("yomgir" if r < 0.62 else "ochiq"))
	elif summer:
		weather = "chang" if r < 0.12 else ("bulut" if r < 0.25 else "ochiq")
	else:
		weather = "yomgir" if r < 0.22 else ("bulut" if r < 0.45 else "ochiq")
	_wnext = _rng.randf_range(5.0, 14.0)


func _month() -> int:
	var dt := Time.get_datetime_dict_from_unix_time(Game.start_unix + Game.day * 86400)
	return int(dt["month"])


func time_text() -> String:
	var h := int(hour)
	var m := int((hour - h) * 60.0)
	return "%02d:%02d  %s" % [h, m, W_NAMES[weather]]


func _process(delta: float) -> void:
	if env == null:
		return
	var sp := float(Game.speed)
	if sp > 0.0:
		var dh := delta * 24.0 / REAL_DAY * sp
		hour += dh
		_wnext -= dh
		if hour >= 24.0:
			hour -= 24.0
			_last_prayer = -1
		if _wnext <= 0.0:
			_pick_weather()
		_check_prayer()
	var target := 0.0 if weather == "ochiq" else (0.45 if weather == "bulut" else 1.0)
	_wmix = move_toward(_wmix, target, delta * 0.15)
	_apply()


func _check_prayer() -> void:
	if not muslim:
		return
	for i in PRAYERS.size():
		var t: float = PRAYERS[i][0]
		if i > _last_prayer and hour >= t and hour < t + 0.5:
			_last_prayer = i
			prayer.emit(PRAYERS[i][1])
			if _azan.stream != null:
				if minaret_pos != null:
					_azan.global_position = minaret_pos
				elif cam != null:
					_azan.global_position = cam.global_position
				_azan.play()


func _apply() -> void:
	# quyosh balandligi: 5:30 - chiqish, 12:30 - tepada, 19:30 - botish
	var day_a := (hour - 5.5) / 14.0 * PI            # 0..PI kunduzi (5:30 - 19:30)
	var elev := sin(day_a)                            # -1..1
	var up := clampf(elev * 3.0, 0.0, 1.0)            # kunduzgi kuch (tong/shomda tez o'sadi)
	var dusk := clampf(1.0 - absf(elev) * 4.0, 0.0, 1.0)   # tong va shom
	var bad := _wmix
	sun.rotation_degrees = Vector3(-clampf(rad_to_deg(asin(clampf(elev, -1, 1))), 4.0, 80.0), -90.0 + rad_to_deg(day_a) * 0.9, 0)
	sun.light_energy = (1.25 * up) * (1.0 - bad * 0.6)
	sun.light_color = Color(1.0, 0.95, 0.86).lerp(Color(1.0, 0.55, 0.3), dusk * 0.8)
	sun.visible = up > 0.01
	moon.light_energy = (1.0 - up) * 0.28 * (1.0 - bad * 0.5)
	moon.visible = moon.light_energy > 0.01
	var night := 1.0 - up
	var top_day := Color("#3a6aa3").lerp(Color("#6d747c"), bad)
	var hor_day := Color("#c9d6e2").lerp(Color("#9aa0a6"), bad)
	if weather == "chang":
		top_day = Color("#3a6aa3").lerp(Color("#a08a62"), bad)
		hor_day = Color("#c9d6e2").lerp(Color("#c8a874"), bad)
	var top := top_day.lerp(Color("#060a18"), night).lerp(Color("#3a3a6a"), dusk * 0.5)
	var hor := hor_day.lerp(Color("#121a2c"), night).lerp(Color("#e8935a"), dusk * 0.7)
	sky.sky_top_color = top
	sky.sky_horizon_color = hor
	sky.ground_horizon_color = hor.darkened(0.1)
	env.ambient_light_energy = lerpf(0.12, 0.55, up) * (1.0 - bad * 0.25)
	env.fog_light_color = hor
	var fog_mul := 1.0 + bad * (6.0 if weather == "chang" else (3.0 if weather in ["yomgir", "qor"] else 1.0))
	env.fog_density = _base_fog * fog_mul
	for t in torches:
		if is_instance_valid(t):
			(t as OmniLight3D).light_energy = clampf(night * 1.4 - 0.1, 0.0, 1.3)
			(t as OmniLight3D).visible = night > 0.15
	# ob-havo zarrachalari kamera atrofida
	if cam != null:
		var c := cam.global_position
		var base := Vector3(c.x, 0.0, c.z)
		_rain.global_position = base + Vector3(0, 60, 0)
		_snow.global_position = base + Vector3(0, 60, 0)
		_dust.global_position = base + Vector3(-60, 6, 0)
	_rain.emitting = weather == "yomgir" and bad > 0.3
	_snow.emitting = weather == "qor" and bad > 0.3
	_dust.emitting = weather == "chang" and bad > 0.3
