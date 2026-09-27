extends Control
## 첫 화면. [출근하기]를 누르면 서류철(저장 칸) 세 개 중 하나를 고른다.

const BOLD: Font = preload("res://assets/fonts/Pretendard-SemiBold.woff2")
const PIXEL: Font = preload("res://assets/fonts/Mulmaru.woff2")
const INK := Color("2b2723")

var slots: Control
var confirm := {}   # 덮어쓰기 확인 중인 칸


func _ready() -> void:
	Sfx.enter(false)
	var g := Gradient.new()
	g.set_color(0, Color(0.06, 0.05, 0.05, 0.92))
	g.set_color(1, Color(0.06, 0.05, 0.05, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0.35, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	%Shade.texture = tex
	for b in [%StartBtn, %PracticeBtn, %QuitBtn]:
		_ticket(b)
	%StartBtn.pressed.connect(_open_slots)
	%PracticeBtn.pressed.connect(func():
		Game.new_game()
		Game.tutorial = true
		Game.queue = Tutorial.CASES.duplicate()
		get_tree().change_scene_to_file("res://scenes/office.tscn"))
	%QuitBtn.pressed.connect(func(): get_tree().quit())
	%QuitBtn.visible = OS.get_name() != "Web"
	# 개발용: 주소 끝에 #evening 을 붙이면 저녁 화면을 바로 본다
	if OS.has_feature("web") and str(JavaScriptBridge.eval("location.hash")) == "#evening":
		Game.new_game()
		Game.day = 9
		Game.flags = {"love_lunch": true}
		Game.events = ["박달수 씨가 대기실 안내를 도와줬다.", "스트레스로 쓰러질 뻔해서 조퇴했다."]
		get_tree().change_scene_to_file.call_deferred("res://scenes/evening.tscn")


## 크림색 종이 버튼
func _ticket(b: Button) -> void:
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = {"normal": Color("f3ead6"), "hover": Color("fff7e4"), "pressed": Color("e2d6bd"), "focus": Color("f3ead6")}[st]
		sb.border_color = Color("9c8a66")
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 4
		sb.shadow_offset = Vector2(2, 3)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_font_override("font", BOLD)
	b.add_theme_font_size_override("font_size", 22)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, INK)


func _open_slots() -> void:
	if slots:
		slots.queue_free()
	confirm = {}
	slots = Control.new()
	slots.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(slots)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	slots.add_child(dim)
	var box := VBoxContainer.new()
	box.position = Vector2(150, 110)
	box.size = Vector2(980, 500)
	box.add_theme_constant_override("separation", 18)
	slots.add_child(box)
	var head := Label.new()
	head.text = "어느 서류철로 할까요?"
	head.add_theme_font_override("font", PIXEL)
	head.add_theme_font_size_override("font_size", 32)
	head.add_theme_color_override("font_color", Color("ffdb8c"))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	for s in range(1, Game.SLOTS + 1):
		row.add_child(_slot_card(s))
	var close := Button.new()
	close.text = "닫기"
	close.custom_minimum_size = Vector2(160, 44)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func():
		slots.queue_free()
		slots = null)
	box.add_child(close)


## 서류철 한 권: 위에 이름 탭, 안에 며칠째인지, 평판과 잔고, 공부
func _slot_card(s: int) -> Control:
	var info := Game.save_info(s)
	var paper := Color("e8d49a") if not info.is_empty() else Color("cfc6b0")
	var folder := VBoxContainer.new()
	folder.add_theme_constant_override("separation", 0)
	var tab := PanelContainer.new()
	tab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = paper
	tsb.border_color = Color("9c7b3c")
	tsb.set_border_width_all(3)
	tsb.border_width_bottom = 0
	tsb.corner_radius_top_left = 6
	tsb.corner_radius_top_right = 6
	tsb.set_content_margin_all(8)
	tsb.content_margin_left = 16
	tsb.content_margin_right = 16
	tab.add_theme_stylebox_override("panel", tsb)
	tab.add_child(_label("서류철 %d" % s, 24, INK, PIXEL))
	folder.add_child(tab)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(300, 270)
	var sb := StyleBoxFlat.new()
	sb.bg_color = paper
	sb.border_color = Color("9c7b3c")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sb.corner_radius_top_left = 0
	sb.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", sb)
	folder.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	if info.is_empty():
		var empty := _label("비어 있음", 20, Color("6b6152"), BOLD)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(empty)
	else:
		var d := clampi(int(info.get("day", 1)), 1, Content.LAST_DAY)
		v.add_child(_label("%s 아침" % Content.DATES[d - 1].substr(6), 20, INK, BOLD))
		v.add_child(_label("%d일째 근무" % d, 17, Color("5a4f40"), BOLD))
		v.add_child(_label("평판 %d   벌점 %d" % [int(info.get("rep", 0)), int(info.get("pen", 0))], 17, Color("5a4f40"), BOLD))
		v.add_child(_label("잔고 %s" % Game.won(int(info.get("money", 0))), 17, Color("5a4f40"), BOLD))
		v.add_child(_label("공부 %d/%d" % [int(info.get("study", 0)), Content.EXAM_STUDY], 17, Color("5a4f40"), BOLD))
		var gap := Control.new()
		gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(gap)
		var go := Button.new()
		go.text = "이어 하기"
		go.custom_minimum_size = Vector2(0, 46)
		go.pressed.connect(func():
			if Game.load_game(s):
				get_tree().change_scene_to_file("res://scenes/briefing.tscn"))
		v.add_child(go)
	var fresh := Button.new()
	fresh.text = "새로 시작"
	fresh.custom_minimum_size = Vector2(0, 42)
	fresh.pressed.connect(func():
		if not info.is_empty() and not confirm.has(s):
			confirm[s] = true
			fresh.text = "정말 덮어쓸까요?"
			return
		Game.new_game()
		Game.slot = s
		get_tree().change_scene_to_file("res://scenes/briefing.tscn"))
	v.add_child(fresh)
	return folder


func _label(text: String, size: int, color: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
