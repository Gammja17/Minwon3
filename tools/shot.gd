extends Node
## 주요 화면을 PNG로 찍는다. 실행: godot --path . res://tools/shot.tscn -- <출력 폴더>

var out := "user://"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out = args[0]
	Game.new_game()
	await _snap_scene("res://scenes/title.tscn", "1_title")
	await _snap_scene("res://scenes/briefing.tscn", "2_briefing")
	# 연습 창구
	Game.new_game()
	Game.tutorial = true
	Game.queue = Tutorial.CASES.duplicate()
	var tut: Node = await _open("res://scenes/office.tscn")
	await _wait(0.3)
	await _save("t1_call")
	tut._on_next()
	await _wait(1.0)
	await _save("t2_compare")
	tut.tutorial.confirmed = true
	await _wait(0.2)
	tut.pick_stamp("ok")
	tut.stamp_paper(tut._main_paper(), Vector2(170, 90))
	await _wait(0.3)
	tut.return_papers()
	await _wait(0.2)
	await _save("t3_hand_back")
	await _wait(2.5)
	tut._on_next()
	await _wait(1.0)
	tut._decide("process")
	await _wait(0.3)
	await _save("t4_wrong")
	tut.queue_free()
	Game.tutorial = false
	Game.new_game()
	Game.start_day()
	var office: Node = await _open("res://scenes/office.tscn")
	office._on_next()
	await _wait(1.0)
	await _save("3_office_first")
	office.pick_stamp("ok")
	office.stamp_paper(office._main_paper(), Vector2(170, 90))
	await _wait(0.2)
	await _save("3b_stamped")
	office.return_papers()
	await _wait(2.5)
	office._on_next()   # 무작위
	await _wait(1.0)
	office._decide("reject")
	await _wait(2.5)
	office._on_next()   # 박달수 (소란)
	await _wait(1.0)
	await _save("4_office_hostile")
	office._ignore()
	office._ignore()
	office._ignore()
	await _wait(0.6)
	await _save("5_office_calmed")
	office._show_rules()
	await _wait(0.3)
	await _save("6_rules")
	office.queue_free()
	# 지적하기: 사진이 다른 최준호
	Game.queue = ["d1_photo"]
	office = await _open("res://scenes/office.tscn")
	office._on_next()
	await _wait(1.0)
	office.inspect_btn.button_pressed = true
	office._on_pick("id.look", _find_fid(office, "id.look"), "click")
	await _wait(0.2)
	await _save("12_inspect_select")
	office._on_pick("face", office.portrait, "click")
	await _wait(0.4)
	await _save("13_inspect_found")
	office.pick_stamp("no")
	office.stamp_paper(office._main_paper(), Vector2(160, 110))
	await _wait(0.4)
	await _save("14_reason_slip")
	office.reason = "photo"
	office.return_papers()
	await _wait(0.4)
	await _save("15_stamp")
	office.queue_free()
	# 2일째 김순자 할머니 + 전산 조회
	Game.day = 2
	Game.start_day()
	Game.queue = ["d2_grandma"]
	office = await _open("res://scenes/office.tscn")
	office._on_next()
	await _wait(1.0)
	await _save("7_grandma")
	office._show_lookup()
	await _wait(0.3)
	await _save("8_lookup")
	office.queue_free()
	# 4일째 사기범
	Game.day = 4
	Game.start_day()
	Game.queue = ["d4_scam"]
	office = await _open("res://scenes/office.tscn")
	office._on_next()
	await _wait(1.0)
	await _save("9_scam")
	office.queue_free()
	# 2주차 화요일: 위조 신분증을 들고 온 정태민 + 전산 사진
	Game.day = 7
	Game.flags = {"scam_escaped": true}
	Game.start_day()
	Game.queue = ["w2_taemin", "R"]
	office = await _open("res://scenes/office.tscn")
	office._on_next()
	await _wait(1.0)
	await _save("16_w2_taemin")
	office._show_lookup()
	await _wait(0.3)
	await _save("17_w2_lookup")
	office._decide("guard")
	await _wait(2.5)
	office._on_next()   # 2주차 무작위 민원인
	await _wait(1.0)
	await _save("18_w2_random")
	office.queue_free()
	# 여러 단계: 오민재 (전입신고 → 확정일자)
	Game.new_game()
	Game.day = 6
	Game.start_day()
	Game.queue = ["w2_minjae"]
	office = await _open("res://scenes/office.tscn")
	office._on_next()
	await _wait(1.0)
	await _save("19_minjae_move")
	office.pick_stamp("ok")
	office.stamp_paper(office._main_paper(), Vector2(170, 90))
	office.return_papers()
	await _wait(1.8)
	await _save("20_minjae_lease")
	office.queue_free()
	# 메모와 그 자리 정정: 틀린 곳이 있는 무작위 민원을 골라 온다
	Game.new_game()
	Game.day = 3
	Game.start_day()
	var note_case := _find_case(3, func(c): return c.has("_valid") and c["flaw"]["reason"] == "proxy")
	var fix_case := _find_case(3, func(c): return c.has("_valid") and c["flaw"]["reason"] == "info" and c["docs"][1]["kind"] == "form")
	Game.queue = [note_case, fix_case]
	Game.revisit_chance = 1.0
	office = await _open("res://scenes/office.tscn")
	for i in 20:
		Game.notes = []
		office._on_next()
		await _wait(0.6)
		var pr: Array = office.c["flaw"]["pairs"][0]
		office._judge(pr[0], pr[1])
		office._decide("reject:proxy")
		await _wait(0.4)
		if not Game.notes.is_empty():
			break
		await _wait(2.2)
		Game.queue.push_front(note_case.duplicate(true))
	await _save("21_note")
	await _wait(2.5)
	Game.queue = [fix_case]
	office._on_next()
	await _wait(0.8)
	var fp: Array = office.c["flaw"]["pairs"][0]
	office._judge(fp[0], fp[1])
	await _wait(0.3)
	await _save("22_fix_button")
	office._fix_on_spot()
	await _wait(0.8)
	await _save("23_fixed")
	office.queue_free()
	Game.revisit_chance = 0.6
	# 수험생과 유튜버
	Game.new_game()
	Game.day = 4
	Game.start_day()
	Game.queue = ["d4_haneul"]
	office = await _open("res://scenes/office.tscn")
	office._on_next()
	await _wait(1.0)
	await _save("24_haneul")
	office.queue_free()
	Game.day = 8
	Game.start_day()
	Game.clock = 800.0
	Game.queue = ["w2_jaehyuk"]
	office = await _open("res://scenes/office.tscn")
	office._on_next()
	await _wait(1.0)
	await _save("25_jaehyuk")
	office.queue_free()
	Game.flags = {}
	Game.day = 1
	Game.events = ["박달수 씨가 국민신문고에 '3번 창구 직원이 노인을 내쫓았다'는 민원을 올렸다."]
	await _snap_scene("res://scenes/evening.tscn", "10_evening")
	Game.day = 5
	Game.flags = {"dalsu_done": true, "grandma_helped": true, "mee_helped": true, "scam_caught": true, "took_gift": true}
	await _snap_scene("res://scenes/ending.tscn", "11_ending")
	get_tree().quit()


func _find_case(day: int, want: Callable) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 5000:
		var c := Content.make_routine(day, rng)
		if c.get("phase") == "calm" and c.has("flaw") and want.call(c):
			return c
	return {}


func _find_fid(n: Node, fid: String) -> Control:
	if n.has_meta("fid") and n.get_meta("fid") == fid:
		return n
	for ch in n.get_children():
		var r := _find_fid(ch, fid)
		if r:
			return r
	return null


func _open(path: String) -> Node:
	var n: Node = load(path).instantiate()
	add_child(n)
	await _wait(0.2)
	return n


func _snap_scene(path: String, name: String) -> void:
	var n := await _open(path)
	await _wait(0.3)
	await _save(name)
	n.queue_free()
	await get_tree().process_frame


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
