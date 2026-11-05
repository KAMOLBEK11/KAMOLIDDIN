extends PanelContainer
## Diplomatik xabarlar qutisi: takliflar o'yinni to'xtatmaydi, shu yerda kutib turadi.

var body: VBoxContainer
var _dirty := false


func _ready() -> void:
	var v := UIKit.window(self, "DIPLOMATIK XABARLAR", "res://icons/politic.svg", 760, 560)
	v.add_child(UIKit.label("Takliflar shu yerda %d kun kutadi. Javob bermasangiz, avtomatik rad etiladi." % Diplo.INBOX_DAYS, 13, UIKit.DIM, true))
	body = UIKit.scroll(v)
	Game.changed.connect(func(): _dirty = true)


func _process(_d: float) -> void:
	if _dirty and visible:
		_dirty = false
		rebuild()


func toggle() -> void:
	visible = not visible
	if visible:
		rebuild()


func rebuild() -> void:
	UIKit.clear(body)
	if Diplo.inbox.is_empty():
		body.add_child(UIKit.label("Yangi xabar yo'q.", 16, UIKit.DIM))
		return
	for i in range(Diplo.inbox.size() - 1, -1, -1):
		var m: Dictionary = Diplo.inbox[i]
		var c := UIKit.card(body, UIKit.CARD2)
		var h := UIKit.row(c, 12)
		if m["from"] != "":
			h.add_child(UIKit.flag(m["from"], 54))
		var lines: PackedStringArray = m["text"].split("\n", false)
		var tv := VBoxContainer.new()
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(tv)
		tv.add_child(UIKit.label(lines[0].trim_suffix(":"), 17, Color.WHITE, true))
		var left: int = m["expire"] - Game.day
		tv.add_child(UIKit.label("%s  |  javob uchun %d kun qoldi" % [Game.date_text(), left], 12, UIKit.BAD if left <= 5 else UIKit.DIM))
		var rest := "\n".join(lines.slice(1))
		c.add_child(UIKit.label(rest, 14, UIKit.INFO, true))
		var br := UIKit.row(c)
		UIKit.button(br, "  Qabul qilish  ", "", Diplo.answer.bind(i, true), true)
		UIKit.button(br, "  Rad etish  ", "", Diplo.answer.bind(i, false))
