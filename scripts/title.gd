extends Control


func _ready() -> void:
	%Face.set_face(Content.LOOKS["dalsu"], "angry")
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
