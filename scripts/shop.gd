class_name Shop
extends Control
## 편의점: 출근길이나 퇴근길에 간식을 산다. 산 것은 다음에 앉을 때 책상 위에 놓여 있다.
## 잔고가 모자라면 살 수 없다 (마이너스 통장이 있으면 한도까지).

const INK := Color("2b2723")

var when := "출근길"
var money_lbl: Label
var buttons: Array = []   # [버튼, 값]


static func open(parent: Node, when_text: String) -> Shop:
	var s := Shop.new()
	s.when = when_text
	parent.add_child(s)
	return s


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("f3eee2")
	sb.border_color = Color("b9ae98")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(24)
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 8
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(250, 96)
	panel.custom_minimum_size = Vector2(780, 0)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var head := _label("%s 편의점" % when, 26, INK)
	head.add_theme_font_override("font", DocView.BOLD)
	v.add_child(head)
	money_lbl = _label("", 17, Color("5a4f40"))
	v.add_child(money_lbl)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	for it in Content.SHOP:
		row.add_child(_item_card(it))
	v.add_child(_label("산 물건은 책상 위에 둔다. 먹고 나면 껍데기가 남으니 휴지통에 치워야 한다.", 15, Color("6b6152")))
	var close := Button.new()
	close.text = "다 샀어요"
	close.custom_minimum_size = Vector2(200, 48)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.add_theme_font_size_override("font_size", 18)
	close.pressed.connect(queue_free)
	v.add_child(close)
	_refresh()
	Sfx.play("ff_off", -10.0)


func _item_card(it: Array) -> Control:
	var k: String = it[0]
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fffaf0")
	sb.border_color = Color("d9c7a3")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", sb)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var path := "res://assets/ui/desk_%s.png" % k
	if ResourceLoader.exists(path):
		var tex := TextureRect.new()
		tex.texture = load(path)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.custom_minimum_size = Vector2(0, 96)
		v.add_child(tex)
	var name_lbl := _label("%s  %s원" % [Content.DESK_ITEMS[k][0], Game.comma(int(it[1]))], 18, INK)
	name_lbl.add_theme_font_override("font", DocView.BOLD)
	v.add_child(name_lbl)
	var desc := _label(String(it[2]), 14, Color("5a4f40"))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = 200
	v.add_child(desc)
	var b := Button.new()
	b.text = "사기"
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(_buy.bind(k, int(it[1])))
	v.add_child(b)
	buttons.append([b, int(it[1])])
	return card


func _buy(k: String, price: int) -> void:
	if Game.desk_items.size() >= Content.DESK_CAP or not Game.spend(price):
		return
	Game.desk_items.append({"kind": k, "x": randf_range(24.0, 860.0), "y": randf_range(150.0, 230.0)})
	Sfx.play("coin", -6.0)
	_refresh()


func _refresh() -> void:
	var t := "지갑: %s" % Game.money_text()
	if Game.overdraft > 0:
		t += "   (마이너스 통장 한도 %s)" % Game.won(Game.overdraft)
	if Game.desk_items.size() >= Content.DESK_CAP:
		t += "   책상에 더 둘 자리가 없다"
	money_lbl.text = DocView.keep_words(t)
	for pair in buttons:
		pair[0].disabled = not Game.can_spend(pair[1]) or Game.desk_items.size() >= Content.DESK_CAP
		pair[0].text = "사기" if Game.can_spend(pair[1]) else "잔고 부족"


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = DocView.keep_words(text)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
