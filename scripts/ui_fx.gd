extends Node
## Interfeys effektlari (autoload: UIFx):
## - barcha asosiy panellar Glassmorphism (orqa fon xira-shaffof shisha)
## - tugmalar: sichqoncha kelganda silliq kattalashish va yorishish, bosilganda "bosilish" animatsiyasi
## - oynalar ochilganda silliq paydo bo'lish

var glass: ShaderMaterial


func _ready() -> void:
	glass = ShaderMaterial.new()
	glass.shader = load("res://shaders/glass.gdshader")
	get_tree().node_added.connect(_on_node)


func _on_node(n: Node) -> void:
	if n is Button:
		_hook_button(n)
	elif n is PanelContainer:
		_maybe_glass.call_deferred(n)


func _hook_button(b: Button) -> void:
	if b.has_meta("fx"):
		return
	b.set_meta("fx", true)
	b.resized.connect(func(): b.pivot_offset = b.size / 2.0)
	b.mouse_entered.connect(func(): _tween(b, 1.04, 1.15, 0.12))
	b.mouse_exited.connect(func(): _tween(b, 1.0, 1.0, 0.18))
	b.button_down.connect(func(): _tween(b, 0.95, 0.9, 0.06))
	b.button_up.connect(func(): _tween(b, 1.04 if b.is_hovered() else 1.0, 1.1 if b.is_hovered() else 1.0, 0.14))


func _tween(c: Control, sc: float, bright: float, t: float) -> void:
	if not is_instance_valid(c) or not c.is_inside_tree():
		return
	if c.has_meta("tw"):
		var old: Tween = c.get_meta("tw")
		if old and old.is_valid():
			old.kill()
	var tw := c.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2(sc, sc), t)
	tw.tween_property(c, "self_modulate", Color(bright, bright, bright, 1.0), t)
	c.set_meta("tw", tw)


func _maybe_glass(p: PanelContainer) -> void:
	if not is_instance_valid(p) or p.has_meta("glass"):
		return
	# faqat eng tashqi panellar (ichki kartalar shaffof qoladi)
	var a := p.get_parent()
	while a:
		if a is PanelContainer:
			return
		a = a.get_parent()
	p.set_meta("glass", true)
	p.material = glass
	p.resized.connect(func(): p.pivot_offset = p.size / 2.0)
	p.visibility_changed.connect(func():
		if p.visible:
			p.modulate.a = 0.0
			p.scale = Vector2(0.97, 0.97)
			var tw := p.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(p, "modulate:a", 1.0, 0.18)
			tw.tween_property(p, "scale", Vector2.ONE, 0.22))
