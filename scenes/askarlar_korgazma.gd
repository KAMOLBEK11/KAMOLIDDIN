extends Node3D
## 1-zamon askarlari va otlari ko'rgazmasi: kamera atrofida aylanadi.
## Ochish: Godot'da scenes/askarlar_korgazma.tscn ni tanlab F6 bosing.
var units: Array = []
var riders: Array = []
var t := 0.0

func _ready() -> void:
	add_child(FX.environment(false, Color("#6f7d4a")))
	add_child(FX.sun())
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(80, 80)
	g.mesh = pm
	g.material_override = FX.ground_material(Color("#6f7d4a"), Color("#8a8a5a"))
	add_child(g)
	var kinds := ["qilichboz", "nayzachi", "kamonchi"]
	var anims := {"qilichboz": ["Attack", "Block", "Walk", "Idle", "Cheer", "Attack"], "nayzachi": ["Attack", "Block", "Walk", "Idle", "Run", "Attack"],
		"kamonchi": ["Attack", "Block", "Walk", "Idle", "Attack", "Block"]}
	for r in kinds.size():
		for c in 6:
			var u := Unit3D.soldier("osiyo", kinds[r], Color("#2f7d4a"))
			add_child(u)
			u.position = Vector3(-r * 1.6, 0, (c - 2.5) * 1.1)
			Unit3D.play(u, anims[kinds[r]][c])
			units.append(u)
	for i in 3:
		var h := Unit3D.cavalry("osiyo", "otliq", Color("#2f7d4a"))
		add_child(h)
		h.position = Vector3(3.5, 0, (i - 1) * 2.4)
		Unit3D.play(h, "Gallop" if i != 1 else "Idle")
		var rd := Unit3D.rider_of(h)
		if rd: Unit3D.play(rd, "RideAttack" if i != 1 else "Ride")
	var d := Unit3D.soldier("osiyo", "qilichboz")
	add_child(d); d.position = Vector3(-6, 0, 3); Unit3D.play(d, "Death1")
	cam = Camera3D.new()
	cam.fov = 45
	add_child(cam)


var cam: Camera3D
var ang := 0.6


func _process(delta: float) -> void:
	ang += delta * 0.15
	if cam:
		cam.position = Vector3(cos(ang) * 11.0, 3.2, sin(ang) * 11.0)
		cam.look_at(Vector3(0, 0.9, 0))
	# otliqlar aylana bo'ylab chopadi
	for c in get_children():
		if c.has_meta("rider") and Unit3D.anim(c).current_animation == "Gallop":
			var a: float = c.get_meta("a", randf() * TAU) + delta * 0.35
			c.set_meta("a", a)
			c.position = Vector3(cos(a) * 7.0, 0, sin(a) * 7.0)
			c.rotation.y = -a - PI / 2.0
