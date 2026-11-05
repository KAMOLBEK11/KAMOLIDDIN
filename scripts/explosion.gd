extends Node2D
## Oddiy animatsion portlash: chaqnash, olov sharlari va tutun.

var big := false
var nuke := false
var life := 0.9
var _t := 0.0
var _parts: Array = []


func _ready() -> void:
	if nuke:
		life = 3.0
	var n := 8 if big else 4
	var spread := 16.0 if big else 9.0
	for i in n:
		_parts.append({
			"off": Vector2(randf_range(-1, 1), randf_range(-1, 1)) * spread,
			"r": randf_range(6.0, 11.0) * (1.6 if big else 1.0),
			"delay": randf_range(0.0, 0.3),
		})


func _process(delta: float) -> void:
	_t += delta
	if _t > life + 0.35:
		queue_free()
	queue_redraw()


func _draw() -> void:
	if nuke:
		_draw_nuke()
		return
	if _t < 0.12:
		draw_circle(Vector2.ZERO, (34.0 if big else 20.0), Color(1, 1, 0.85, 0.7 * (1.0 - _t / 0.12)))
	for p in _parts:
		var k: float = (_t - p["delay"]) / life
		if k < 0.0 or k > 1.0:
			continue
		var r: float = p["r"] * (0.4 + k * 1.3)
		var o: Vector2 = p["off"] * (1.0 + k) + Vector2(0, -10.0 * k)
		draw_circle(o, r * 1.35, Color(0.22, 0.22, 0.22, 0.55 * (1.0 - k)))
		draw_circle(o, r, Color(1.0, 0.45 + 0.35 * (1.0 - k), 0.08, 1.0 - k))
		draw_circle(o, r * 0.45, Color(1.0, 0.95, 0.65, 1.0 - k))


func _draw_nuke() -> void:
	var k := clampf(_t / life, 0.0, 1.0)
	# oq chaqnash
	if _t < 0.4:
		draw_circle(Vector2.ZERO, 260.0, Color(1, 1, 0.95, 0.85 * (1.0 - _t / 0.4)))
	# zarba to'lqini
	draw_arc(Vector2.ZERO, 30.0 + k * 220.0, 0, TAU, 64, Color(1, 0.9, 0.7, 0.8 * (1.0 - k)), 6.0 * (1.0 - k) + 1.0)
	# olovli shar va qo'ziqorin buluti
	var r := 30.0 + 40.0 * minf(1.0, k * 3.0)
	draw_circle(Vector2(0, -k * 40.0), r * 1.3, Color(0.3, 0.28, 0.26, 0.7 * (1.0 - k)))
	draw_circle(Vector2(0, -k * 40.0), r, Color(1.0, 0.45, 0.1, 1.0 - k))
	draw_circle(Vector2(0, -k * 40.0), r * 0.5, Color(1.0, 0.95, 0.6, 1.0 - k))
	draw_rect(Rect2(-8, -k * 40.0, 16, k * 40.0), Color(0.35, 0.3, 0.28, 0.8 * (1.0 - k)))
