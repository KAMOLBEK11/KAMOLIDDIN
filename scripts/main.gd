extends Node2D
## Asosiy sahna: xarita, interfeys va (kerak bo'lganda) taktik jang sahnasi.

var ui: CanvasLayer
var battle_layer: CanvasLayer
var _speed_before := 1


func _ready() -> void:
	# 3D relyefli strategik xarita (eski 2D xarita uning ichida tekstura sifatida ishlaydi)
	var map := preload("res://scripts/map3d.gd").new()
	map.name = "Map"
	add_child(map)
	ui = preload("res://scripts/ui.gd").new()
	ui.name = "UI"
	add_child(ui)
	War.open_battle.connect(_open_battle)
	Game.open_province.connect(_dive_in)
	map.dive_requested.connect(_dive_in)
	# xarita <-> qal'a o'tishida ekranni bir zum bulut/tuman qoplaydi (kamera harakati to'xtamaydi)
	var hl := CanvasLayer.new()
	hl.layer = 30
	add_child(hl)
	haze = ColorRect.new()
	haze.set_anchors_preset(Control.PRESET_FULL_RECT)
	haze.color = Color(0.86, 0.9, 0.95, 0.0)
	haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hl.add_child(haze)
	if Game.pending_load:
		Game.pending_load = false
		Game.load_game.call_deferred()
	elif Game.story != "" and not Game.started:
		Story.begin.call_deferred(Game.story)


var prov_layer: CanvasLayer
var haze: ColorRect
var _busy := false


func _dive_in(id: String) -> void:
	## xaritadan qal'aga: kamera viloyat markaziga pastlab tushadi, tuman qoplaydi, qal'a osmondan ochiladi
	if _busy or prov_layer != null or not Game.provinces.has(id) or Game.provinces[id]["owner"] != Game.PLAYER:
		return
	_busy = true
	var map = get_node("Map")
	map.dive_max = map.MAX_ZOOM * 2.6
	map._focus_on(Game.provinces[id]["center"], map.MAX_ZOOM * 2.6)
	var tw := create_tween()
	tw.tween_property(haze, "color:a", 1.0, 0.5).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		_open_province(id)
		if prov_layer:
			var v = prov_layer.get_node_or_null("Province")
			if v and v.has_method("intro_dive"):
				v.intro_dive()
		map.dive_max = map.MAX_ZOOM
		map._focus_on(Game.provinces[id]["center"], map.MAX_ZOOM * 0.8, true))
	tw.tween_property(haze, "color:a", 0.0, 0.7).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): _busy = false)


func _rise_out() -> void:
	## qal'adan xaritaga: kamera osmonga ko'tariladi, tuman, xarita yuqoridan ochiladi va uzoqlashadi
	if prov_layer == null:
		return
	var v = prov_layer.get_node_or_null("Province")
	var id: String = v.prov_id if v else ""
	if v and v.has_method("rise_out"):
		v.rise_out()
	var map = get_node("Map")
	var tw := create_tween()
	tw.tween_property(haze, "color:a", 1.0, 0.5).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if v:
			v._close()
		if id != "":
			map.dive_max = map.MAX_ZOOM * 2.6
			map._focus_on(Game.provinces[id]["center"], map.MAX_ZOOM * 2.4, true)
			map.dive_max = map.MAX_ZOOM
			map._focus_on(Game.provinces[id]["center"], map.MAX_ZOOM * 0.45))
	tw.tween_property(haze, "color:a", 0.0, 0.7).set_ease(Tween.EASE_OUT)


func _open_province(id: String) -> void:
	if prov_layer != null or not Game.provinces.has(id) or Game.provinces[id]["owner"] != Game.PLAYER:
		return
	prov_layer = CanvasLayer.new()
	prov_layer.layer = 9
	add_child(prov_layer)
	# 1-2-zamonda viloyat = qal'a quruvchi, zamonaviy zamonda = harbiy baza
	var v = preload("res://scripts/castle3d.gd").new() if Game.era < 4 else preload("res://scripts/province3d.gd").new()
	v.name = "Province"
	prov_layer.add_child(v)
	v.setup(id)
	v.hud.theme = ui.get_child(0).theme
	v.closed.connect(func():
		if prov_layer:
			prov_layer.queue_free()
			prov_layer = null)
	if v.has_signal("exit_requested"):
		v.exit_requested.connect(_rise_out)


func _open_battle(army_id: int) -> void:
	if War.battle_open or War.get_army(army_id).is_empty():
		return
	War.battle_open = true
	_speed_before = Game.speed if Game.speed != 0 else 1
	Game.set_speed(0)
	battle_layer = CanvasLayer.new()
	battle_layer.layer = 10
	add_child(battle_layer)
	# 1-2-zamon: qilich-kamonli jang maydoni, zamonaviy: tank va avtomatli jang
	var b = preload("res://scripts/battle_era1.gd").new() if Game.era < 4 else preload("res://scripts/battle3d.gd").new()
	b.name = "Battle"
	battle_layer.add_child(b)
	b.setup(army_id)
	b.hud.theme = ui.get_child(0).theme
	b.closed.connect(_close_battle)


func _close_battle() -> void:
	War.battle_open = false
	if battle_layer:
		battle_layer.queue_free()
		battle_layer = null
	Game.set_speed(_speed_before)
