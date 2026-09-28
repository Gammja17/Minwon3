extends Control
## 2주차 토요일 승진 시험. 창구에서 겪은 상황 다섯 문제를 고른다.
## 저녁에 공부한 만큼 앞 문제부터 "기출에서 본 문제" 표시가 붙고 틀린 보기 하나가 지워진다.

const INK := Color("2b2723")
const RED := Color("a8322a")

var questions: Array = []
var index := 0
var score := 0
var box: VBoxContainer


func _ready() -> void:
	Sfx.enter(false)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.11, 0.16)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var paper := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("f3eee2")
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(36)
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 10
	paper.add_theme_stylebox_override("panel", sb)
	paper.position = Vector2(190, 40)
	paper.custom_minimum_size = Vector2(900, 640)
	add_child(paper)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	paper.add_child(box)
	questions = Game.exam_questions()
	_show()


func _clear() -> void:
	for ch in box.get_children():
		ch.queue_free()


func _show() -> void:
	_clear()
	var head := _label("2026년 지방공무원 8급 승진 시험   (%d / 5)" % (index + 1), 22, INK, true)
	box.add_child(head)
	box.add_child(_label("10월 24일 토요일, 구청 대강당. 창구에서 겪은 일을 떠올리며 맞는 처리를 고른다. 세 문제를 맞히면 합격.", 15, Color("6b6152"), false))
	var q: Array = questions[index]
	var seen := index < mini(Game.study, Content.EXAM_STUDY)
	if seen:
		box.add_child(_label("기출에서 본 문제 (저녁에 공부한 덕분에 틀린 보기 하나가 떠오른다)", 16, Color("2c5a8a"), true))
	box.add_child(_label("%d. %s" % [index + 1, q[0]], 20, INK, true))
	# 공부한 문제는 틀린 보기 하나를 지운다 (어느 것을 지울지는 문제마다 정해져 있다)
	var drop := -1
	if seen:
		drop = (int(q[2]) + 1 + index % 3) % 4
	for i in 4:
		var b := Button.new()
		b.text = "%s  %s" % [["①", "②", "③", "④"][i], q[1][i]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 52)
		b.add_theme_font_size_override("font_size", 18)
		if i == drop:
			b.disabled = true
			b.text += "   (아닌 걸 안다)"
		b.pressed.connect(_answer.bind(i))
		box.add_child(b)


func _answer(i: int) -> void:
	var q: Array = questions[index]
	var right := i == int(q[2])
	if right:
		score += 1
		Sfx.play("stamp", -6.0)
	else:
		Sfx.play("warn", -8.0)
	_clear()
	box.add_child(_label("%d. %s" % [index + 1, q[0]], 20, INK, true))
	box.add_child(_label("맞았다." if right else "틀렸다. 답은 '%s'." % q[1][int(q[2])], 20, Color("2f6a3e") if right else RED, true))
	var rule: Array = Content.RULES.filter(func(r): return r["title"] == q[3])
	if not rule.is_empty():
		box.add_child(_label("[%s] %s" % [rule[0]["title"], rule[0]["text"]], 16, Color("4a4238"), false))
	var next := Button.new()
	next.text = "다음 문제" if index < 4 else "답안지 내기"
	next.custom_minimum_size = Vector2(240, 52)
	next.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	next.add_theme_font_size_override("font_size", 18)
	next.pressed.connect(_next)
	box.add_child(next)


func _next() -> void:
	index += 1
	if index < questions.size():
		_show()
		return
	Game.finish_exam(score)
	_clear()
	var passed := Game.flags.has("exam_pass")
	box.add_child(_label("승진 시험 결과", 24, INK, true))
	box.add_child(_label("다섯 문제 중 %d문제를 맞혔다." % score, 20, INK, false))
	if passed:
		box.add_child(_label("합격! 11월 인사 때 8급으로 올라간다. 월요일부터는 판단하기 어려운 민원을 하루 한 번 최 팀장에게 결재 올릴 수 있다.", 19, Color("2f6a3e"), true))
	else:
		box.add_child(_label("불합격. 수습 평가표에 시험 결과가 한 줄 들어간다. 남은 한 주의 창구 기록으로 만회해야 한다.", 19, RED, true))
	box.add_child(_label("[일요일]", 17, Color("8a3b12"), true))
	for line in Game.weekend_two():
		box.add_child(_label(line, 16, Color("4a4238"), false))
	var go := Button.new()
	go.text = "월요일 출근"
	go.custom_minimum_size = Vector2(240, 52)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.add_theme_font_size_override("font_size", 18)
	go.pressed.connect(func():
		Game.weekend()
		get_tree().change_scene_to_file("res://scenes/briefing.tscn"))
	box.add_child(go)
	Sfx.play("bell" if passed else "warn", -4.0)


func _label(text: String, size: int, color: Color, bold: bool) -> Label:
	var l := Label.new()
	l.text = DocView.keep_words(text)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", DocView.BOLD)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
