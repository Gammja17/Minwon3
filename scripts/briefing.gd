extends Control
## 아침마다 팀장이 남기는 업무 메모. 새 규정도 여기서 알린다.


func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("f3eee2")
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(28)
	%Paper.add_theme_stylebox_override("panel", sb)
	%Header.text = "%s  업무 메모" % Content.DATES[Game.day - 1]
	var text := Game.memo_for_today()
	var rules := Game.new_rules_today()
	if Game.day > 1 and not rules.is_empty():
		text += "\n\n[color=#8a3b12]오늘부터 바뀌는 규정[/color]"
		for r in rules:
			text += "\n· %s: %s" % [r["title"], r["text"]]
	text += "\n\n[color=#756c60]규정 전체와 부서 안내표는 창구의 [규정집]에서 언제든 볼 수 있어요.[/color]"
	%Memo.text = DocView.keep_words(text)
	Game.save_game()
	%StartBtn.pressed.connect(func():
		Game.start_day()
		get_tree().change_scene_to_file("res://scenes/office.tscn"))
