class_name Tutorial
extends Control
## 연습 창구: 최 팀장이 옆에서 하나씩 짚어 주고, 플레이어가 직접 해 봐야 다음으로 넘어간다.
## 노 주무관이 민원인 역할을 한다. 끝나면 새 게임으로 시작하므로 연습 결과는 기록에 남지 않는다.

const CASES := ["tut_ok", "tut_bad", "tut_transfer", "tut_rude"]
const WANT := {"tut_ok": "process", "tut_bad": "reject:info", "tut_transfer": "transfer:welfare", "tut_rude": "process"}
const WRONG := {
	"tut_ok": "다시 봐요. 이름도 생년월일도 신분증, 전산과 다 맞아요. 이럴 땐 처리 도장이에요.",
	"tut_bad": "잠깐, 신청서 생년월일이 신분증이랑 달라요. 반려하고, 사유는 '이름·생년월일 불일치'예요.",
	"tut_transfer": "기초연금은 복지팀 일이에요. [부서 안내]에서 복지팀 안내문을 뽑아 주세요.",
	"tut_rude": "지금은 소리만 지르는 거라 내보내거나 비상벨을 누를 일은 아니에요. 대꾸하지 말고 기다려 봐요.",
}
const INK := Color("1f2a36")

var o: Node   # 창구 화면(office)
var steps: Array = []
var step := 0
var note := ""   # 방금 틀렸을 때 최 팀장의 한마디
var confirmed := false
var box: PanelContainer
var face: TextureRect
var say: Label
var ok_btn: Button


func setup(office: Node) -> void:
	o = office
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_box()
	_build_steps()
	_show()


func _build_box() -> void:
	box = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fff8e6")
	sb.border_color = Color("8a6a3a")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	box.add_theme_stylebox_override("panel", sb)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 말풍선 밑의 서류도 잡을 수 있게
	box.position = Vector2(16, 600)
	box.custom_minimum_size = Vector2(640, 0)
	add_child(box)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	face = TextureRect.new()
	face.custom_minimum_size = Vector2(88, 88)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(face)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var who := DocView._label("최 팀장 · 연습 창구", 15, Color("8a6a3a"))
	who.add_theme_font_override("font", DocView.BOLD)
	col.add_child(who)
	say = DocView._label("", 17, INK)
	say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	say.custom_minimum_size = Vector2(500, 0)
	col.add_child(say)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_END
	btns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(btns)
	var skip := Button.new()
	skip.text = "연습 건너뛰기"
	skip.add_theme_font_size_override("font_size", 14)
	skip.pressed.connect(finish)
	btns.add_child(skip)
	ok_btn = Button.new()
	ok_btn.add_theme_font_size_override("font_size", 16)
	ok_btn.pressed.connect(func():
		if steps[step].get("finish", false):
			finish()
		else:
			confirmed = true)
	btns.add_child(ok_btn)


func _build_steps() -> void:
	var main := func() -> Control: return o._main_paper()
	var gone := func() -> bool: return o.leaving or not o.serving
	steps = [
		# 1. 이상 없는 서류: 대조하고, 처리 도장, 돌려주기
		{"call": "tut_ok", "at": func(): return o.next_btn,
			"say": "실전 전에 한 번 해 봐요. 노 주무관이 민원인 역할을 해 줄 거예요.\n벽의 [번호 호출]을 누르세요."},
		{"case": "tut_ok", "at": func(): return o.papers_layer, "confirm": true,
			"say": "신분증과 신청서가 책상에 놓였죠? 서류는 끌어서 옮길 수 있어요.\n신청서의 이름·생년월일을 신분증, 그리고 오른쪽 모니터의 전산 기록과 비교해 보세요."},
		{"case": "tut_ok", "at": func(): return o.stamp_ok, "done": func(): return o.holding == "ok" or _stamped("ok"),
			"say": "다 맞네요. 오른쪽 받침대의 [처리 도장]을 집으세요."},
		{"case": "tut_ok", "at": main, "done": func(): return _stamped("ok"),
			"say": "도장을 든 채로 신청서 위를 누르면 쾅 찍혀요."},
		{"case": "tut_ok", "at": func(): return o.slot, "done": gone,
			"say": "이제 서류를 창구 아래 [서류 넣는 곳]으로 돌려주세요. 거기를 누르거나, 서류를 끌어다 놓으면 돼요. 이때 처리가 확정돼요."},
		# 2. 틀린 서류: 돋보기, 반려 도장, 수정테이프, 사유서
		{"call": "tut_bad", "at": func(): return o.next_btn,
			"say": "잘했어요. 다음 분 부르세요."},
		{"case": "tut_bad", "at": func(): return o.inspect_btn, "done": func(): return o.inspecting or o.c.get("_found", false),
			"say": "이번엔 틀린 데를 하나 넣었대요. 책상의 [돋보기]를 켜세요."},
		{"case": "tut_bad", "at": func(): return o.papers_layer, "done": func(): return o.c.get("_found", false),
			"say": "서로 안 맞는 두 곳을 차례로 누르세요.\n신청서의 생년월일, 그리고 신분증의 생년월일이요."},
		{"case": "tut_bad", "at": func(): return o.stamp_no, "done": func(): return _stamped("no"),
			"say": "찾았네요. [반려 도장]을 집어서 신청서에 찍으세요."},
		{"case": "tut_bad", "at": main, "done": func(): return not _stamped("no"),
			"say": "도장을 잘못 찍었을 땐 도장 자국을 오른쪽 클릭하면 수정테이프로 지워져요. 연습 삼아 방금 찍은 도장을 지워 보세요."},
		{"case": "tut_bad", "at": func(): return o.stamp_no, "done": func(): return _stamped("no"),
			"say": "지워졌죠? 다시 반려 도장을 찍으세요."},
		{"case": "tut_bad", "at": func(): return o.reason_paper, "done": func(): return o.reason != "",
			"say": "반려 사유서가 나왔어요. 생년월일이 틀렸으니 '이름·생년월일 불일치'에 체크하세요."},
		{"case": "tut_bad", "at": func(): return o.slot, "done": gone,
			"say": "서류 넣는 곳으로 돌려주세요."},
		# 3. 다른 부서 일: 안내문
		{"call": "tut_transfer", "at": func(): return o.next_btn,
			"say": "다음 분이요."},
		{"case": "tut_transfer", "at": func(): return o.get_node("%TabDept"), "done": func(): return o.tab == "dept",
			"say": "이번엔 서류가 없네요. 기초연금은 우리 창구 일이 아니에요. 모니터의 [부서 안내]를 누르세요."},
		{"case": "tut_transfer", "at": func(): return o.monitor, "done": func(): return o.slip_dept == "welfare",
			"say": "기초연금은 복지팀 일이에요. 복지팀 줄의 [안내문 출력]을 누르세요.\n잘못 뽑은 안내문은 책상 아래쪽 휴지통에 끌어다 버리면 돼요."},
		{"case": "tut_transfer", "at": func(): return o.slot, "done": gone,
			"say": "안내문을 서류 넣는 곳으로 건네주세요."},
		# 4. 소리부터 지르는 사람: 먹금, 비상벨 위치
		{"call": "tut_rude", "at": func(): return o.next_btn,
			"say": "마지막이에요."},
		{"case": "tut_rude", "at": func(): return o.ask_row, "done": func(): return o.c.get("phase") == "calm",
			"say": "이런 분이 제일 흔해요. 말대꾸하지 말고 [(대꾸하지 않는다)]를 몇 번 눌러 보세요."},
		{"case": "tut_rude", "at": func(): return o.guard_btn, "confirm": true,
			"say": "가라앉았죠? 참, 물건을 부수거나 손이 올라가면 그땐 이 [비상벨]로 청원경찰을 불러요. 지금은 누르지 말고요."},
		{"case": "tut_rude", "at": func(): return o.stamp_ok, "done": gone,
			"say": "이제 평소처럼 해 봐요. 서류를 맞춰 보고, 도장 찍고, 서류 넣는 곳으로."},
		{"finish": true, "mood": "happy",
			"say": "연습 끝! 실전도 이렇게만 하면 돼요.\n규정은 날마다 조금씩 늘어나니까, 헷갈리면 책상의 [규정집]을 펴 보세요."},
	]


func _process(_delta: float) -> void:
	var s: Dictionary = steps[step]
	# 번호 호출은 부를 차례에만
	if not s.has("call"):
		o.next_btn.disabled = true
	if _done(s):
		step += 1
		note = ""
		confirmed = false
		_show()
	box.position.y = 712.0 - box.size.y   # 글이 길어지면 위로 자란다
	queue_redraw()


func _done(s: Dictionary) -> bool:
	if s.has("call"):
		return _case() == s["call"]
	if s.get("confirm", false):
		return confirmed
	if s.has("done"):
		return s["done"].call()
	return false


func _show() -> void:
	var s: Dictionary = steps[step]
	var mood: String = s.get("mood", "normal")
	if note != "":
		mood = "angry"
	face.texture = Portrait.texture_for("choi", mood)
	say.text = DocView.keep_words((note + "\n\n" if note != "" else "") + String(s["say"]))
	ok_btn.visible = s.get("confirm", false) or s.get("finish", false)
	ok_btn.text = "1일차 시작" if s.get("finish", false) else "확인했어요"
	box.reset_size()


func _draw() -> void:
	var s: Dictionary = steps[step]
	if not s.has("at"):
		return
	var t: Variant = s["at"].call()
	if not (t is Control) or not is_instance_valid(t) or not t.is_visible_in_tree():
		return
	var r: Rect2 = t.get_global_rect().grow(6)
	r.position -= global_position
	var a := 0.55 + 0.45 * sin(Time.get_ticks_msec() / 160.0)
	draw_rect(r, Color(1, 0.82, 0.2, a), false, 4.0)


func _case() -> String:
	return String(o.c.get("id", "")) if o.serving else ""


func _stamped(kind: String) -> bool:
	var m: Paper = o._main_paper()
	return m != null and m.stamps.has(kind)


## 창구가 결정을 확정하기 전에 묻는다. 틀린 결정이면 확정하지 않고 다시 하게 한다.
func allow(action: String) -> bool:
	var id := _case()
	if not WANT.has(id) or action == WANT[id]:
		return true
	note = WRONG[id]
	# 책상을 되돌린다: 도장 자국, 사유서, 안내문
	for p in o.papers:
		if is_instance_valid(p):
			p.clear_marks()
	for k in ["reason_paper", "slip_paper"]:
		var p: Variant = o.get(k)
		if p and is_instance_valid(p):
			p.queue_free()
		o.set(k, null)
	o.reason = ""
	o.slip_dept = ""
	# 이 민원의 첫 단계로 돌아간다 (이미 해 둔 단계는 저절로 넘어간다)
	for i in steps.size():
		if steps[i].get("case", "") == id:
			step = i
			break
	confirmed = false
	_show()
	return false


func finish() -> void:
	Game.new_game()
	get_tree().change_scene_to_file("res://scenes/briefing.tscn")
