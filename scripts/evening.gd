extends Control
## 하루 결산, 어머니 문자, 저녁 선택. 밤의 원룸을 배경으로, 저녁에 할 일을 그림 카드로 고른다.
## 돈이 드는 선택은 잔고가 모자라면 고를 수 없다. 햇살은행 앱에서 마이너스 통장을 열 수 있다.

const BOLD: Font = preload("res://assets/fonts/Pretendard-SemiBold.woff2")
const CHOICES := [
	["rest", "집에서 푹 쉰다", "스트레스 -35", "res://assets/ui/ev_rest.png", 0],
	["friend", "동기 정다운과 한잔", "스트레스 -20, 2만 원\n동네 소식을 듣는다", "res://assets/ui/ev_friend.png", 20000],
	["study", "승진 시험 공부", "스트레스 +5, 공부 +1
시험에 아는 문제가 는다", "res://assets/ui/ev_study.png", 0],
	["overtime", "남아서 야근", "수당 +3.5만 원, 스트레스 +10", "res://assets/ui/ev_overtime.png", 0],
]
const MOM_MONEY := 500000

var bank_btn: Button
var chose := false


func _ready() -> void:
	Sfx.enter(false)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.11, 0.86)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(22)
	%Panel.add_theme_stylebox_override("panel", sb)
	%Title.text = "%s  업무 종료" % Content.DATES[Game.day - 1].substr(6)
	_update_exam()
	%NextBtn.pressed.connect(_next)
	_render_summary()
	_build_wallet()
	if Game.day == Content.WEEK_END:
		%Ask.text = "금요일 저녁. 1주차 감사 결과가 나왔다."
		%NextBtn.text = "1주차 감사 결과 보기"
		%NextBtn.visible = true
	elif Game.day == Content.WEEK2_END:
		%Ask.text = "2주차 금요일 저녁. 중간 점검 결과가 나왔다."
		%NextBtn.text = "중간 점검 결과 보기"
		%NextBtn.visible = true
	elif Game.day == Content.LAST_DAY:
		%Ask.text = "수습 마지막 금요일 저녁. 수습 평가 결과가 나왔다."
		%NextBtn.text = "수습 평가 결과 보기"
		%NextBtn.visible = true
	elif Game.day == 3 and not Game.flags.has("mom_helped") and not Game.flags.has("mom_declined"):
		_show_mom()
	else:
		_show_evening_choices()


func _show_mom() -> void:
	for b in %Choices.get_children():
		b.queue_free()
	%Ask.text = "엄마에게 답장을 보내야 한다."
	var ok := Game.can_spend(MOM_MONEY)
	var detail := "잔고 %s에서 보낸다" % Game.money_text() if ok else "잔고가 모자란다. 마이너스 통장이 있으면 보낼 수 있다."
	_card("50만 원을 보낸다", detail, null, _mom.bind(true), ok)
	_card("이번 달은 어렵다고 말한다", "엄마는 괜찮다고 하겠지만...", null, _mom.bind(false))


## 왼쪽 판 아래: 퇴근길 편의점, 햇살은행 앱(마이너스 통장)
func _build_wallet() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var shop := Button.new()
	shop.text = "퇴근길 편의점"
	shop.custom_minimum_size = Vector2(0, 40)
	shop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop.pressed.connect(func():
		var s := Shop.open(self, "퇴근길")
		s.tree_exited.connect(_money_changed))
	row.add_child(shop)
	bank_btn = Button.new()
	bank_btn.custom_minimum_size = Vector2(0, 40)
	bank_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bank_btn.pressed.connect(_bank)
	row.add_child(bank_btn)
	%NextBtn.get_parent().add_child(row)
	%NextBtn.get_parent().move_child(row, %NextBtn.get_index())
	_update_bank()


func _update_bank() -> void:
	if Game.overdraft > 0:
		bank_btn.text = "마이너스 통장 (한도 %s)" % Game.won(Game.overdraft)
		bank_btn.disabled = true
	elif bank_btn.has_meta("confirm"):
		bank_btn.text = "정말 만들까요? (연 7%)"
	else:
		bank_btn.text = "햇살은행: 마이너스 통장"


## 공무원 신용대출: 신규라도 바로 나온다. 한 번 만들면 한도까지 끌어다 쓸 수 있고, 쓴 만큼 이자가 붙는다.
func _bank() -> void:
	if not bank_btn.has_meta("confirm"):
		bank_btn.set_meta("confirm", true)
		_update_bank()
		return
	Game.open_overdraft()
	Sfx.play("coin", -4.0)
	var t := "햇살은행 앱으로 공무원 마이너스 통장을 만들었다. 한도 200만 원, 연 7%. 공무원이라 심사가 5분 만에 끝났다. 쓴 만큼 이자가 붙는다."
	%Result.text = DocView.keep_words((%Result.text + "\n\n" if %Result.visible else "") + t)
	%Result.visible = true
	_money_changed()


## 잔고가 바뀌면 돈이 드는 카드를 다시 본다
func _money_changed() -> void:
	_update_bank()
	_render_summary()
	if chose:
		return
	if Game.day == 3 and not Game.flags.has("mom_helped") and not Game.flags.has("mom_declined"):
		_show_mom()
	elif not %NextBtn.visible:
		_show_evening_choices()


func _update_exam() -> void:
	%Exam.text = Game.exam_text()


func _render_summary() -> void:
	var s: Dictionary = Game.stats
	var t := "응대 %d명   /   잘 처리 %d   /   실수 %d\n" % [s["served"], s["right"], s["wrong"]]
	t += "평판 %d (%+d)   /   벌점 %d (%+d)   /   스트레스 %d\n" % [Game.rep, Game.rep - Game.day_start_rep, Game.pen, Game.pen - Game.day_start_pen, Game.stress]
	t += "잔고 %s  (오늘 점심값과 교통비 %s)\n" % [Game.money_text(), Game.won(Game.DAILY_COST)]
	if not Game.events.is_empty():
		t += "\n[color=#ffd479]오늘 있었던 일[/color]\n"
		for e in Game.events:
			t += "■ %s\n" % e
	var sms := Game.mom_sms()
	if sms != "":
		t += "\n[color=#9fd3ff]엄마의 문자[/color]\n%s\n" % sms
	%Summary.text = DocView.keep_words(t)


func _show_evening_choices() -> void:
	for b in %Choices.get_children():
		b.queue_free()
	%Ask.text = "퇴근 후에는..."
	for ch in CHOICES:
		if ch[0] == "study" and Game.day > Content.WEEK2_END:
			# 시험이 끝난 3주차에는 공부 대신 산책
			_card("동네 한 바퀴 산책", "스트레스 -15", load("res://assets/ui/ev_rest.png"), _choose.bind("walk"))
			continue
		var cost: int = ch[4]
		_card(ch[1], ch[2] if Game.can_spend(cost) else "잔고가 모자란다", load(ch[3]), _choose.bind(ch[0]), Game.can_spend(cost))
	# 서하준과 점심을 먹은 사이라면, 2주차 목요일 저녁 약속
	if Game.day == 9 and Game.flags.has("love_lunch"):
		var ok := Game.can_spend(25000)
		_card("서하준과 저녁", "스트레스 -30, 2.5만 원\n쪽지에 답한다" if ok else "잔고가 모자란다", Portrait.texture_for("hajun", "happy"), _choose.bind("date"), ok)


## 그림 카드 한 장
func _card(title: String, detail: String, icon: Texture2D, cb: Callable, enabled := true) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(292, 186 if icon else 110)
	b.icon = icon
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.text = "%s\n%s" % [title, detail]
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_override("font", BOLD)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_constant_override("icon_max_width", 110)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = {"normal": Color(0.96, 0.93, 0.86, 0.94), "hover": Color(1, 0.98, 0.9, 1), "pressed": Color(0.85, 0.8, 0.7, 1),
			"disabled": Color(0.5, 0.5, 0.52, 0.7), "focus": Color(0.96, 0.93, 0.86, 0.94)}[st]
		sb.border_color = Color("ffdb8c") if st == "hover" else Color(0, 0, 0, 0)
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(10)
		b.add_theme_stylebox_override(st, sb)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, Color("2b2723"))
	b.pressed.connect(cb)
	b.disabled = not enabled
	%Choices.add_child(b)


func _mom(send: bool) -> void:
	%Result.text = DocView.keep_words(Game.mom_choice(send))
	%Result.visible = true
	_render_summary()
	_show_evening_choices()


func _choose(key: String) -> void:
	chose = true
	for b in %Choices.get_children():
		b.disabled = true
	var prev: String = %Result.text + "\n\n" if %Result.visible else ""
	%Result.text = DocView.keep_words(prev + Game.evening(key))
	%Result.visible = true
	%NextBtn.visible = true
	_update_exam()


func _next() -> void:
	if Game.day in [Content.WEEK_END, Content.WEEK2_END, Content.LAST_DAY]:
		get_tree().change_scene_to_file("res://scenes/ending.tscn")
		return
	Game.day += 1
	get_tree().change_scene_to_file("res://scenes/briefing.tscn")
