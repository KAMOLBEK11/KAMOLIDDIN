extends Control
## 3D jang ustidagi 2D qatlam: sog'liq chiziqlari, tanlash to'rtburchagi, buyruq belgilari.

var b: Node   # battle3d


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	if b == null or b.cam == null:
		return
	for u in b.units:
		if not u["alive"]:
			continue
		var h: float = 5.2 if u["type"] == "tank" else 3.6
		var p3: Vector3 = b.to3(u["pos"], h)
		if b.cam.is_position_behind(p3):
			continue
		var sp: Vector2 = b.cam.unproject_position(p3)
		var side_col: Color = b.COL_P if u["side"] == 0 else b.COL_E
		var w := 30.0
		var bp := sp - Vector2(w / 2.0, 0)
		draw_rect(Rect2(bp - Vector2(1, 1), Vector2(w + 2, 6)), Color(0, 0, 0, 0.75))
		var k: float = clampf(u["hp"] / u["maxhp"], 0.0, 1.0)
		var col := Color("#7bd88f") if k > 0.5 else (Color("#ffd166") if k > 0.25 else Color("#ff6b6b"))
		draw_rect(Rect2(bp, Vector2(w * k, 4)), col)
		draw_rect(Rect2(bp + Vector2(-4, 0), Vector2(3, 4)), side_col)
	for f in b.flashes:
		var p3b: Vector3 = b.to3(f["pos"], 0.1)
		if b.cam.is_position_behind(p3b):
			continue
		var sp2: Vector2 = b.cam.unproject_position(p3b)
		var a: float = clampf(f["t"] * 2.0, 0.0, 1.0)
		var col2 := Color(0.5, 1, 0.5, a) if f["kind"] == "move" else Color(1, 0.3, 0.3, a)
		var r := 10.0 + (1.0 - a) * 16.0
		draw_arc(sp2, r, 0, TAU, 24, col2, 2.5)
	if b.dragging and b.drag_start.distance_to(b.drag_now) > 6.0:
		var rr := Rect2(b.drag_start, Vector2.ZERO).expand(b.drag_now)
		draw_rect(rr, Color(0.5, 1, 0.5, 0.12))
		draw_rect(rr, Color(0.5, 1, 0.5, 0.85), false, 1.5)
