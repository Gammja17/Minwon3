extends Control
## 1주차 금요일에는 감사 결과(이어서 2주차로), 마지막 금요일에는 인사 평가와 최종 엔딩.


func _ready() -> void:
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
	else:
		Game.clear_save()   # 끝난 게임은 이어 할 수 없다
		%RestartBtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/title.tscn"))
