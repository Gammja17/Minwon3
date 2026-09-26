extends Control
## 하루 결산, 어머니 문자, 저녁 선택.

const CHOICES := [
	["rest", "집에 가서 푹 쉰다  (스트레스 -35)"],
	["friend", "복지팀 동기 정다운과 저녁을 먹는다  (스트레스 -20, 2만 원, 동네 소식을 듣는다)"],
	["study", "승진 시험 공부를 한다  (스트레스 +5, 공부 +1)"],
	["overtime", "야근한다  (시간외수당 +3.5만 원, 스트레스 +10)"],
]


func _ready() -> void:
	%Title.text = "%s  업무 종료" % Content.DATES[Game.day - 1]
	%NextBtn.pressed.connect(_next)
	_render_summary()
	if Game.day == Content.WEEK_END:
		%Ask.text = "금요일 저녁. 1주차 감사 결과가 나왔다."
		%NextBtn.text = "1주차 감사 결과 보기"
		%NextBtn.visible = true
	elif Game.day == Content.LAST_DAY:
		%Ask.text = "마지막 금요일 저녁. 인사 평가 결과가 나왔다."
		%NextBtn.text = "인사 평가 결과 보기"
		%NextBtn.visible = true
	elif Game.day == 3 and not Game.flags.has("mom_helped") and not Game.flags.has("mom_declined"):
		%Ask.text = "엄마에게 답장을 보내야 한다."
		_button("50만 원을 보낸다  (잔고 %s → %s)" % [Game.won(Game.money), Game.won(Game.money - 500000)], _mom.bind(true))
		_button("이번 달은 어렵다고 말한다", _mom.bind(false))
	else:
		_show_evening_choices()


func _render_summary() -> void:
	var s: Dictionary = Game.stats
	var t := "응대한 민원인 %d명  ·  잘 처리 %d  ·  실수 %d\n" % [s["served"], s["right"], s["wrong"]]
	t += "평판 %d (%+d)  ·  벌점 %d (%+d)  ·  스트레스 %d\n" % [Game.rep, Game.rep - Game.day_start_rep, Game.pen, Game.pen - Game.day_start_pen, Game.stress]
	t += "잔고 %s  (오늘 점심값·교통비 %s)\n" % [Game.won(Game.money), Game.won(Game.DAILY_COST)]
	if not Game.events.is_empty():
		t += "\n[color=#ffd479]오늘 있었던 일[/color]\n"
		for e in Game.events:
			t += "· %s\n" % e
	var sms := Game.mom_sms()
	if sms != "":
		t += "\n[color=#9fd3ff]엄마의 문자[/color]\n%s\n" % sms
	%Summary.text = DocView.keep_words(t)


func _show_evening_choices() -> void:
	for b in %Choices.get_children():
		b.queue_free()
	%Ask.text = "퇴근 후에는..."
	for ch in CHOICES:
		_button(ch[1], _choose.bind(ch[0]))


func _button(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(cb)
	%Choices.add_child(b)


func _mom(send: bool) -> void:
	%Result.text = DocView.keep_words(Game.mom_choice(send))
	%Result.visible = true
	_render_summary()
	_show_evening_choices()


func _choose(key: String) -> void:
	for b in %Choices.get_children():
		b.disabled = true
	var prev: String = %Result.text + "\n\n" if %Result.visible else ""
	%Result.text = DocView.keep_words(prev + Game.evening(key))
	%Result.visible = true
	%NextBtn.visible = true


func _next() -> void:
	if Game.day == Content.WEEK_END or Game.day == Content.LAST_DAY:
		get_tree().change_scene_to_file("res://scenes/ending.tscn")
		return
	Game.day += 1
	get_tree().change_scene_to_file("res://scenes/briefing.tscn")
