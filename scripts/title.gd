extends Control


func _ready() -> void:
	%Face.set_face(Content.LOOKS["dalsu"], "angry")
	%ContinueBtn.visible = Game.has_save() and Game.save_day() > 0
	%ContinueBtn.text = "이어 하기 (%s 아침부터)" % Content.DATES[clampi(Game.save_day(), 1, Content.LAST_DAY) - 1].substr(6)
	%ContinueBtn.pressed.connect(func():
		if Game.load_game():
			get_tree().change_scene_to_file("res://scenes/briefing.tscn"))
	%PracticeBtn.pressed.connect(func():
		Game.new_game()
		Game.tutorial = true
		Game.queue = Tutorial.CASES.duplicate()
		get_tree().change_scene_to_file("res://scenes/office.tscn"))
	%StartBtn.pressed.connect(func():
		Game.new_game()
		get_tree().change_scene_to_file("res://scenes/briefing.tscn"))
	%QuitBtn.pressed.connect(func(): get_tree().quit())
	%QuitBtn.visible = OS.get_name() != "Web"
