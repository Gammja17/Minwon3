extends Control
## 1주차 금요일에는 감사 결과(이어서 2주차로), 마지막 금요일에는 인사 평가와 최종 엔딩.


func _ready() -> void:
	Sfx.enter(false)
	var e := Game.week_report() if Game.day == Content.WEEK_END and Game.fail_reason == "" else Game.ending()
	%Title.text = e["title"]
	var title: String = e["title"]
	if title == "파면":
		Skeam.unlock("fired")
	elif title.begins_with("인사 평가"):
		Skeam.unlock("two_weeks")
		if title.begins_with("인사 평가 S"):
			Skeam.unlock("grade_s")
	var t := ""
	for line in e["body"]:
		if String(line).begins_with("["):
			t += "[color=#ffd479]%s[/color]\n" % String(line).trim_prefix("[").trim_suffix("]")
		else:
			t += "%s\n" % line
	t += "\n[color=#8a8f98]평판 %d   /   벌점 %d   /   스트레스 %d   /   공부 %d   /   잔고 %s[/color]" % [Game.rep, Game.pen, Game.stress, Game.study, Game.won(Game.money)]
	%Body.text = DocView.keep_words(t)
	if e.get("continue", false):
		%RestartBtn.text = "주말을 보내고 월요일 출근"
		%RestartBtn.pressed.connect(func():
			Game.weekend()
			get_tree().change_scene_to_file("res://scenes/briefing.tscn"))
	elif title.begins_with("인사 평가"):
		Game.clear_save()   # 2주를 끝낸 게임은 이어 할 수 없다
		%RestartBtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/title.tscn"))
	else:
		# 병가, 징계 같은 중간 엔딩: 그날 아침 저장으로 돌아갈 수 있다
		%RestartBtn.text = "처음 화면으로"
		%RestartBtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/title.tscn"))
		if Game.has_save():
			var retry := Button.new()
			retry.text = "%s 아침부터 다시" % Content.DATES[clampi(Game.save_day(), 1, Content.LAST_DAY) - 1].substr(6)
			retry.custom_minimum_size = Vector2(0, 52)
			retry.add_theme_font_size_override("font_size", 20)
			retry.pressed.connect(func():
				if Game.load_game():
					get_tree().change_scene_to_file("res://scenes/briefing.tscn"))
			%RestartBtn.get_parent().add_child(retry)
			%RestartBtn.get_parent().move_child(retry, %RestartBtn.get_index())
