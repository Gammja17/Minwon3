extends Control
## 3번 창구 자리. 창구 유리(민원인과 대화), 모니터(행정정보시스템), 책상(서류·도장·전화·비상벨·규정집·돋보기).
## 서류를 살피고 신청서에 도장을 찍은 뒤 서류 넣는 곳으로 돌려주면 결정이 확정된다.

const C_THEM := "#f2d7a0"
const C_ME := "#8fc1ff"
const C_SYS := "#a8aeb8"
const C_ACT := "#bcb6aa"
const SLIP_BAD := Color("8a2c24")
const SLIP_GOOD := Color("2f6a3e")
const BOLD: Font = preload("res://assets/fonts/Pretendard-SemiBold.woff2")
const INK := Color("1f2a36")
const PAINT := {
	"hover": [Color(1, 0.85, 0.2, 0.22), Color(0, 0, 0, 0)],
	"select": [Color(1, 0.8, 0.1, 0.45), Color("d9a400")],
	"flaw": [Color(0.9, 0.2, 0.15, 0.22), Color("c0392b")],
}
const MAIN_KINDS := ["form", "move", "death_form", "reissue", "lease", "seal_reg"]
## 다음 단계로 넘어갈 때 앞 단계에서 지우는 것
const STAGE_DROP := ["flaw", "_valid", "_found", "_asked", "needs_call", "_called", "guard_warn", "reason", "custom", "outcomes",
	"reject_say", "thanks", "again", "asks", "win_flag", "fail_flag", "win_event", "fail_event", "verified_by"]
const NOTE_SPOTS := [Vector2(34, 26), Vector2(212, 24), Vector2(36, 104), Vector2(210, 106)]
const NOTE_TEX := preload("res://assets/ui/sticky.png")
const SPOTS := [Vector2(16, 12), Vector2(360, 12), Vector2(704, 12), Vector2(40, 168), Vector2(384, 168), Vector2(690, 150)]
const PAPER_AREA := Rect2(0, -34, 1040, 380)   # 책상 위(서류 넣는 곳까지 끌어 올릴 수 있게)

@onready var date_label: Label = %DateLabel
@onready var clock_label: Label = %ClockLabel
@onready var queue_label: Label = %QueueLabel
@onready var ticket_label: Label = %Ticket
@onready var next_btn: Button = %NextBtn
@onready var inspect_hint: Label = %InspectHint
@onready var window: Control = %Window
@onready var portrait: Portrait = %Portrait
@onready var portrait_box: SubViewportContainer = %PortraitBox
@onready var slot: Panel = %Slot
@onready var slot_label: Label = %SlotLabel
@onready var log_box: RichTextLabel = %Log
@onready var ask_row: VBoxContainer = %AskRow
@onready var monitor: Control = %Monitor
@onready var screen_body: VBoxContainer = %ScreenBody
@onready var toast: PanelContainer = %Toast
@onready var toast_label: Label = %ToastLabel
@onready var rep_label: Label = %RepLabel
@onready var pen_label: Label = %PenLabel
@onready var money_label: Label = %MoneyLabel
@onready var stress_bar: ProgressBar = %StressBar
@onready var desk: Panel = %Desk
@onready var desk_hint: Label = %DeskHint
@onready var papers_layer: Control = %Papers
@onready var stamp_ok: Button = %StampOk
@onready var stamp_no: Button = %StampNo
@onready var phone_btn: MenuButton = %PhoneBtn
@onready var guard_btn: Button = %GuardBtn
@onready var rules_btn: Button = %RulesBtn
@onready var inspect_btn: Button = %InspectBtn
@onready var overlay: PanelContainer = %Overlay
@onready var overlay_title: Label = %OverlayTitle
@onready var overlay_body: VBoxContainer = %OverlayBody
@onready var stamp_cursor: Control = %StampCursor

var c: Dictionary = {}
var serving := false
var leaving := false
var closed_notice := false
var ending_started := false
var portrait_x := 0.0
var toast_tween: Tween
var inspecting := false
var picked: Array = []      # [[fid, node], ...]
var papers: Array = []      # 민원인이 낸 서류 (Paper)
var reason_paper: Paper = null
var slip_paper: Paper = null
var reason := ""
var slip_dept := ""
var holding := ""           # 손에 든 도장 "ok" / "no"
var noon_pending := false   # 수요일 점심, 노 주무관의 부탁
var tab := "lookup"
var messages: Array = []    # [시각, 보낸 사람, 내용, 색]
var unread := 0
var tutorial: Tutorial = null   # 연습 창구일 때만
var notes_layer: Control       # 창구 유리에 붙은 메모들
var slack: Slack               # 모니터 딴짓
var vignette: TextureRect      # 스트레스가 높으면 화면 가장자리가 붉어진다
var exam_label: Label          # 승진 시험 D-데이
var drink: TextureButton       # 책상 위 쪽지 붙은 드링크
var leaving_early := false
var drag_from := Vector2.ZERO  # 서류를 집은 곳


func _ready() -> void:
	portrait_x = portrait_box.position.x
	_style()
	next_btn.pressed.connect(_on_next_btn)
	# 빈 창구를 눌러도 다음 번호를 부른다 (휴대폰에서 작은 버튼 대신)
	portrait_box.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT \
				and not serving and not next_btn.disabled and next_btn.text == "번호 호출":
			_on_next())
	stamp_ok.pressed.connect(pick_stamp.bind("ok"))
	stamp_no.pressed.connect(pick_stamp.bind("no"))
	guard_btn.pressed.connect(func(): _decide("guard"))
	rules_btn.pressed.connect(_show_rules)
	inspect_btn.toggled.connect(_set_inspect)
	%CloseBtn.pressed.connect(func():
		overlay.visible = false
		Sfx.play("book_close", -6.0))
	phone_btn.about_to_popup.connect(_build_phone_menu)
	phone_btn.get_popup().id_pressed.connect(_on_phone)
	phone_btn.get_popup().add_theme_font_size_override("font_size", 16)
	%TabLookup.pressed.connect(_show_lookup)
	%TabDept.pressed.connect(_show_depts)
	%TabMsg.pressed.connect(_show_messages)
	%TabSlack.pressed.connect(_show_slack)
	slot.gui_input.connect(_on_slot_input)
	desk.gui_input.connect(_on_desk_input)
	date_label.mouse_filter = Control.MOUSE_FILTER_STOP
	date_label.gui_input.connect(_pick_input.bind("today", date_label))
	portrait.gui_input.connect(_pick_input.bind("face", portrait))
	date_label.text = Content.DATES[Game.day - 1]
	portrait_box.modulate.a = 0.0
	stamp_cursor.add_child(DocView.stamp("도장"))
	_show_lookup()
	_build_docs()
	_refresh_all()
	_refresh_top()
	slack = Slack.new()
	add_child(slack)
	slack.setup(self)
	_build_vignette()
	_build_exam_label()
	_build_drink()
	%TabSlack.visible = not Game.tutorial
	notes_layer = Control.new()
	notes_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	notes_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.add_child(notes_layer)
	window.move_child(notes_layer, portrait_box.get_index() + 1)
	for n in Game.notes:
		_add_note_view(n, false)
	if Game.tutorial:
		tutorial = Tutorial.new()
		add_child(tutorial)
		tutorial.setup(self)


## 벽·책상·창구 틀·모니터 틀은 그림(assets/ui). 화면 속 UI와 말풍선 판만 코드로 칠한다.
func _style() -> void:
	desk.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	%Screen.add_theme_stylebox_override("panel", _box(Color("eef2f6"), Color("eef2f6"), 0))
	%Header.add_theme_stylebox_override("panel", _box(Color("2c5a8a"), Color("2c5a8a"), 0, 6))
	%Taskbar.add_theme_stylebox_override("panel", _box(Color("2b2f36"), Color("2b2f36"), 0, 4))
	%Board.add_theme_stylebox_override("panel", _box(Color("0d0f12"), Color("3b3f46"), 4, 8))
	slot.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var pad := StyleBoxEmpty.new()   # 모니터 글자가 화면 가장자리에 붙지 않게
	pad.set_content_margin_all(10)
	%ScreenScroll.add_theme_stylebox_override("panel", pad)
	%Talk.add_theme_stylebox_override("panel", _box(Color(0.1, 0.11, 0.14, 0.93), Color("3b3f46"), 4, 10))
	for b in [stamp_ok, stamp_no, phone_btn, guard_btn, rules_btn, inspect_btn]:
		_prop(b)


## 책상 위 소품 버튼: 판 없이 그림과 이름표만. 마우스를 올리면 살짝 커진다.
func _prop(b: Button) -> void:
	for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.add_theme_font_override("font", BOLD)
	b.add_theme_font_size_override("font_size", 15)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(st, Color("fff3dc"))
	b.add_theme_color_override("font_outline_color", Color(0.16, 0.09, 0.04))
	b.add_theme_constant_override("outline_size", 5)
	b.add_theme_color_override("icon_disabled_color", Color(0.62, 0.6, 0.58))   # 못 쓸 때는 비치지 않고 흐리게
	b.mouse_entered.connect(func():
		b.pivot_offset = b.size * 0.5
		if not b.disabled:
			create_tween().tween_property(b, "scale", Vector2(1.07, 1.07), 0.08))
	b.mouse_exited.connect(func(): create_tween().tween_property(b, "scale", Vector2.ONE, 0.08))


func _box(bg: Color, border: Color, radius: int, margin := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2 if border != bg else 0)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


func _process(delta: float) -> void:
	if ending_started:
		return
	Game.tick(delta)
	_refresh_top()
	if Game.is_closed() and not closed_notice:
		closed_notice = true
		if serving:
			_sys("18:00 마감 시간이에요. 지금 앞에 계신 분까지만 처리하세요.")
		_refresh_all()
	_check_patience()
	_check_events()
	if holding != "":
		stamp_cursor.global_position = get_global_mouse_position() - Vector2(70, 30)
	_update_slot()
	_update_next_btn()
	if notes_layer:
		_pulse_note()
	_update_stress_look()
	if Game.stress >= 100 and not leaving_early:
		if Game.can_leave_early() and not Game.tutorial:
			_leave_early()
		else:
			_go_ending()


func _unhandled_input(e: InputEvent) -> void:
	if holding != "" and (e.is_action_pressed("ui_cancel") or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT)):
		_drop_stamp()


## 창구 밖에서 일어나는 일: 노 주무관의 도움, 수요일 점심 부탁
func _check_events() -> void:
	while not Game.notices.is_empty():
		var n: String = Game.notices.pop_front()
		_sys(n)
		_slip(n, SLIP_GOOD)
	if Game.day == 3 and Game.clock >= 720.0 and not serving and not noon_pending and not Game.flags.has("noh_asked"):
		noon_pending = true
		Game.flags["noh_asked"] = true
		log_box.clear()
		_log("[b][color=%s]노 주무관[/color][/b]  저기, 3번. 내가 오늘 점심에 은행 볼일이 있어서 좀 길게 다녀와야 하거든. 그동안 2번 창구 대기하는 분들 좀 같이 봐 줄 수 있어?\n" % C_THEM)
		_refresh_all()


func _noon(accept: bool) -> void:
	noon_pending = false
	if accept:
		Game.waiting += 4
		Game.noh = clampi(Game.noh + 15, 0, 100)
		Game.flags["noh_lunch_helped"] = true
		_say_me("네, 다녀오세요. 제가 볼게요.")
		_log("[b][color=%s]노 주무관[/color][/b]  고마워! 이 은혜는 꼭 갚을게.\n" % C_THEM)
		_slip("2번 창구 대기자 네 명이 3번으로 넘어왔다.", SLIP_GOOD)
	else:
		Game.noh = clampi(Game.noh - 10, 0, 100)
		_say_me("죄송해요, 저도 대기가 밀려서요.")
		_log("[b][color=%s]노 주무관[/color][/b]  ......그래, 알았어. (서운한 얼굴로 자리로 돌아간다)\n" % C_THEM)
	_refresh_top()
	_refresh_all()


## 오래 붙잡고 있으면 민원인이 재촉한다. 이야기 인물은 재촉하지 않는다.
func _check_patience() -> void:
	if not serving or leaving or c.get("story", false) or c.get("phase") != "calm":
		return
	var waited := Game.clock - float(c.get("_start", Game.clock))
	if waited > 60.0 and not c.has("_nag1"):
		c["_nag1"] = true
		_say_them(Content.NAGS.pick_random())
		Game.add_stress(2)
	elif waited > 100.0 and not c.has("_nag2"):
		c["_nag2"] = true
		_say_them(Content.NAGS_2.pick_random())
		portrait.set_face(c["look"], "angry")
		Game.apply({"rep": -1})


func _refresh_top() -> void:
	var t := int(Game.clock)
	clock_label.text = "%02d:%02d" % [t / 60, t % 60]
	queue_label.text = "대기 %d명" % Game.waiting
	money_label.text = "잔고 %s" % Game.won(Game.money)
	money_label.add_theme_color_override("font_color", Color("ff8a7a") if Game.money < 0 else Color.WHITE)
	rep_label.text = "평판 %d" % Game.rep
	pen_label.text = "벌점 %d" % Game.pen
	pen_label.add_theme_color_override("font_color", Color("ff8a7a") if Game.pen >= 5 else Color.WHITE)
	stress_bar.value = Game.stress
	stress_bar.modulate = Color(1, 0.45, 0.4) if Game.stress >= 70 else Color.WHITE


# ─────────────────────────── 번호표 ───────────────────────────

func _on_next() -> void:
	if Game.is_closed():
		_end_day()
		return
	overlay.visible = false
	c = Game.next_case()
	c["_start"] = Game.clock
	picked.clear()
	for n in [portrait, date_label]:
		n.set_meta("mark", "none")
		_paint(n, "none")
	serving = true
	log_box.clear()
	_sys("딩동! %d번 고객님, 3번 창구로 오세요." % c["ticket"])
	ticket_label.text = "%d" % c["ticket"]
	portrait.set_face(c["look"], c.get("mood", "normal"))
	portrait_box.position.x = portrait_x - 260
	portrait_box.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(portrait_box, "position:x", portrait_x, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(portrait_box, "modulate:a", 1.0, 0.25)
	Sfx.play("call")
	get_tree().create_timer(0.3).timeout.connect(Sfx.play.bind("door", -10.0))
	get_tree().create_timer(0.55).timeout.connect(Sfx.steps.bind(3))
	for line in c["intro"]:
		_say_them(line)
	_build_docs()
	if tab == "lookup":
		_show_lookup()
	elif tab == "dept":
		_show_depts()
	_refresh_all()


## 기다리는 사람이 없으면 번호를 부를 수 없다. 대신 다음 손님이 올 때까지 시간을 빨리 감는다.
func _idle() -> bool:
	return not serving and not noon_pending and not Game.is_closed() and Game.waiting <= 0 and not Game.tutorial


func _on_next_btn() -> void:
	if _idle():
		Game.speed = 1.0 if Game.speed > 1.0 else 5.0
		Sfx.play("ff_on" if Game.speed > 1.0 else "ff_off", -6.0)
		_update_next_btn()
		return
	_on_next()


func _update_next_btn() -> void:
	if Game.speed > 1.0 and not _idle():
		# 손님이 왔거나 마감·점심 일이 생기면 멈춘다
		Game.speed = 1.0
		if Game.waiting > 0 and not serving:
			Sfx.play("call")
	if Game.is_closed():
		next_btn.text = "업무 종료"
	elif _idle():
		next_btn.text = "■ 멈춤" if Game.speed > 1.0 else "▶▶ 빨리 감기"
	else:
		next_btn.text = "번호 호출"
	if not serving and desk_hint.visible:
		if Game.is_closed():
			desk_hint.text = "업무가 끝났어요. 벽의 [업무 종료]를 누르세요."
		elif _idle():
			desk_hint.text = "기다리는 사람이 없어요.\n[▶▶ 빨리 감기]를 누르면 다음 손님이 올 때까지 시간이 빨리 가요." if Game.speed <= 1.0 else "시간을 빨리 감는 중... 손님이 오면 멈춰요."
		else:
			desk_hint.text = "벽의 [번호 호출]을 눌러 민원인을 부르세요."


## 민원인이 낸 서류를 서류 넣는 곳에서 책상 위로 밀어 넣는다
func _build_docs() -> void:
	_clear_papers()
	var docs: Array = c.get("docs", []) if serving else []
	var from := slot.global_position - papers_layer.global_position
	for i in docs.size():
		var d: Dictionary = docs[i]
		var card := DocView.make(d, _on_pick)
		card.custom_minimum_size.x = 332
		var p := _new_paper(d, card, d["kind"] in MAIN_KINDS)
		papers.append(p)
		p.position = from
		p.modulate.a = 0.0
		var tw := create_tween().set_parallel()
		tw.tween_property(p, "position", SPOTS[i % SPOTS.size()], 0.35 + i * 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 1.0, 0.2)
	if not docs.is_empty():
		get_tree().create_timer(0.3).timeout.connect(Sfx.play.bind("paper"))
	if not serving:
		desk_hint.text = "업무가 끝났어요. 벽의 [업무 종료]를 누르세요." if Game.is_closed() else "벽의 [번호 호출]을 눌러 민원인을 부르세요."
	elif c.get("phase") != "calm" and c.get("phase") != "gift":
		desk_hint.text = "민원인이 아직 서류를 내밀지 않았다."
	elif docs.is_empty():
		desk_hint.text = "건네받은 서류가 없다.\n용건을 듣고, 우리 일이 아니면 모니터 [부서 안내]에서 안내문을 뽑아 주자."
	else:
		desk_hint.text = ""
	desk_hint.visible = desk_hint.text != ""


func _new_paper(d: Dictionary, card: Control, can_stamp: bool) -> Paper:
	var p := Paper.new()
	papers_layer.add_child(p)
	p.setup(d, card, can_stamp, PAPER_AREA)
	p.pressed.connect(_on_paper_pressed)
	p.released.connect(_on_paper_released)
	p.erase_requested.connect(_on_paper_erase)
	return p


func _clear_papers() -> void:
	for p in papers_layer.get_children():
		p.queue_free()
	papers.clear()
	reason_paper = null
	slip_paper = null
	reason = ""
	slip_dept = ""
	_drop_stamp()


# ─────────────────────────── 도장 ───────────────────────────

## 받침대에서 도장을 집는다. 도장이 마우스를 따라다닌다.
func pick_stamp(kind: String) -> void:
	if not serving or leaving:
		return
	overlay.visible = false
	holding = kind
	var s: Control = stamp_cursor.get_child(0)
	s.get_child(0).text = "반려" if kind == "no" else "처리"
	stamp_cursor.visible = true
	stamp_cursor.global_position = get_global_mouse_position() - Vector2(70, 30)


func _drop_stamp() -> void:
	holding = ""
	if stamp_cursor:
		stamp_cursor.visible = false


func _on_desk_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and holding != "":
		_drop_stamp()   # 빈 책상을 누르면 도장을 내려놓는다


func _on_paper_pressed(p: Paper, at: Vector2) -> void:
	if holding != "":
		stamp_paper(p, at)
		return
	if inspecting:
		return
	drag_from = get_global_mouse_position()
	p.start_drag()


## 쾅!
func stamp_paper(p: Paper, at: Vector2) -> void:
	if not p.stampable:
		_sys("(도장은 신청서에 찍는다)")
		return
	var kind := holding
	var k: String = p.doc.get("kind", "")
	var text := "반려" if kind == "no" else _ok_word(k)
	p.add_mark(kind, text, at)
	_drop_stamp()
	Sfx.play("stamp")
	_shake(desk, 5)
	Game.pass_time(1)
	if kind == "no":
		_show_reason_slip()


## 오른쪽 클릭: 수정테이프로 도장 자국을 지운다
func _on_paper_erase(p: Paper) -> void:
	p.clear_marks()
	if reason_paper:
		reason_paper.queue_free()
		reason_paper = null
		reason = ""
	Game.pass_time(1)
	_sys("(수정테이프로 도장 자국을 지웠다)")


func _show_reason_slip() -> void:
	if reason_paper:
		return
	var group := ButtonGroup.new()
	var rows: Array = []
	for key in Content.REASON_ORDER:
		var b := Button.new()
		b.text = "□ " + Content.REASONS[key]
		b.toggle_mode = true
		b.button_group = group
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 16)
		b.toggled.connect(func(on: bool):
			b.text = ("■ " if on else "□ ") + Content.REASONS[key]
			if on:
				reason = key)
		rows.append(b)
	var card := DocView._paper("반려 사유서", rows)
	card.custom_minimum_size.x = 250
	reason_paper = _new_paper({"kind": "reason"}, card, false)
	reason_paper.position = Vector2(780, 2)


## 모니터 [부서 안내]에서 안내문을 뽑는다
func print_slip(key: String) -> void:
	if not serving or leaving:
		return
	if slip_paper:
		slip_paper.queue_free()
	var d: Dictionary = Content.DEPTS[key]
	var rows := [DocView._row("담당", d["name"]), DocView._row("위치", d["where"]), DocView._row("업무", d["jobs"])]
	var card := DocView._paper("민원 안내문", rows, null, Color("fffbe6"))
	card.custom_minimum_size.x = 300
	slip_paper = _new_paper({"kind": "slip"}, card, false)
	slip_dept = key
	slip_paper.position = Vector2(700, -20)
	create_tween().tween_property(slip_paper, "position", Vector2(700, 170), 0.3)
	Sfx.play("paper")
	Game.pass_time(1)


func _main_paper() -> Paper:
	for p in papers:
		if is_instance_valid(p) and p.stampable:
			return p
	return null


func _decision_ready() -> bool:
	var m := _main_paper()
	return (m != null and not m.stamps.is_empty()) or slip_paper != null


func _update_slot() -> void:
	var ready := serving and not leaving and _decision_ready()
	slot_label.text = "▲ 여기로 서류를 돌려주기" if ready else "서류 넣는 곳"
	var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 200.0)
	# 서류를 끌고 범위 안에 들어오면 밝게 켜서, 놓아도 된다는 걸 알려 준다
	var over := _in_return_zone() and papers_layer.get_children().any(func(q): return q is Paper and q._drag)
	if over:
		slot_label.add_theme_color_override("font_color", Color(1, 0.95, 0.6))
	else:
		slot_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3, pulse) if ready else Color(0.7, 0.72, 0.75))


## 서류 넣는 곳 둘레를 넉넉히 (옆과 위 40, 책상 쪽 80)
func _in_return_zone() -> bool:
	return slot.get_global_rect().grow_individual(40, 40, 40, 80).has_point(get_global_mouse_position())


func _on_paper_released(p: Paper) -> void:
	var at := get_global_mouse_position()
	if %Trash.get_global_rect().grow(8).has_point(at):
		_throw_away(p)
	elif _in_return_zone() and at.distance_to(drag_from) > 20.0:
		return_papers()


## 휴지통: 내가 만든 종이(안내문·반려 사유서)만 버린다. 민원인이 낸 서류는 버릴 수 없다.
func _throw_away(p: Paper) -> void:
	var k: String = p.doc.get("kind", "")
	if not k in ["slip", "reason", "love_note"]:
		_sys("(민원인이 낸 서류는 버릴 수 없다)")
		create_tween().tween_property(p, "position:y", p.position.y - 70, 0.2).set_ease(Tween.EASE_OUT)
		return
	if p == slip_paper:
		slip_paper = null
		slip_dept = ""
	if p == reason_paper:
		reason_paper = null
		reason = ""
	var center: Vector2 = %Trash.global_position + %Trash.size * Vector2(0.5, 0.3) - papers_layer.global_position
	p.pivot_offset = p.size * 0.5
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween().set_parallel()
	tw.tween_property(p, "position", center - p.size * 0.5, 0.2)
	tw.tween_property(p, "scale", Vector2(0.12, 0.12), 0.2)
	tw.tween_property(p, "rotation_degrees", 220.0, 0.2)
	tw.chain().tween_callback(p.queue_free)
	Sfx.play("paper")


func _on_slot_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		return_papers()


## 서류를 서류 넣는 곳으로 돌려준다. 여기서 결정이 확정된다.
func return_papers() -> void:
	if not serving or leaving:
		return
	var m := _main_paper()
	var ok := m != null and m.stamps.has("ok")
	var no := m != null and m.stamps.has("no")
	if ok and no:
		_sys("(신청서에 도장이 두 개 찍혀 있다. 오른쪽 클릭으로 하나를 지우자)")
		return
	if (ok or no) and slip_paper:
		_sys("(도장도 찍고 안내문도 뽑았다. 하나만 하자)")
		return
	if ok:
		_decide("process")
	elif no:
		if reason == "":
			if reason_paper == null:
				_show_reason_slip()
			_sys("(반려 사유서에 사유를 체크해야 한다)")
			return
		_decide("reject:" + reason)
	elif slip_paper:
		_decide("transfer:" + slip_dept)
	else:
		_sys("(아직 처리하지 않았다. 신청서에 도장을 찍거나, 모니터에서 안내문을 뽑자)")


# ─────────────────────────── 대화와 반응 ───────────────────────────

func _refresh_all() -> void:
	_refresh_props()
	_refresh_responses()


func _refresh_props() -> void:
	var s := serving and not leaving
	var phase: String = c.get("phase", "calm") if s else ""
	stamp_ok.disabled = not s or phase != "calm"
	stamp_no.disabled = not s or phase != "calm"
	guard_btn.disabled = not s or phase == "gift"
	inspect_btn.disabled = not (s and phase == "calm") and not inspecting
	next_btn.disabled = serving or noon_pending
	_update_next_btn()


func _refresh_responses() -> void:
	for ch in ask_row.get_children():
		ch.queue_free()
	if noon_pending:
		_response("봐 준다", _noon.bind(true))
		_response("거절한다", _noon.bind(false))
		return
	if not serving or leaving:
		return
	var phase: String = c.get("phase", "calm")
	if phase == "calm":
		var asks: Array = c.get("asks", [])
		for i in asks.size():
			if not c.get("_asked", []).has(i):
				var b := _response(asks[i]["q"], _ask.bind(i))
				b.set_meta("ask", i)
	if phase == "calm" and _can_fix():
		_response("그 자리에서 고쳐 쓰게 한다", _fix_on_spot, true)
	if phase in ["calm", "hostile", "gift"]:
		for pair in c.get("custom", []):
			_response(pair[1], _decide.bind(pair[0]), true)
	if dalsu_available():
		_response("(대기석의 박달수 씨가 다가온다)", _dalsu_help, true)
	if phase != "gift":
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		ask_row.add_child(row)
		_response("(대꾸하지 않는다)", _ignore, false, row)
		_response("나가 주세요", _decide.bind("eject"), false, row)


func _response(text: String, cb: Callable, special := false, parent: Control = null) -> Button:
	var b := Button.new()
	b.text = "› " + text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 15)
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.clip_text = true
	if special:
		b.add_theme_font_override("font", BOLD)
		b.modulate = Color(1, 0.86, 0.62)
	b.pressed.connect(cb)
	(parent if parent else ask_row).add_child(b)
	return b


func _ask(i: int) -> void:
	var a: Dictionary = c["asks"][i]
	_say_me(a["q"])
	_say_them(a["a"])
	Game.pass_time(1)
	var asked: Array = c.get("_asked", [])
	asked.append(i)
	c["_asked"] = asked
	_refresh_responses()


## 1주차에 사망신고를 끝낸 박달수 씨가 2주차부터 대기실 안내를 맡는다. 하루 한 번, 떼쓰는 민원인을 달래 준다.
func dalsu_available() -> bool:
	return serving and not leaving and c.get("phase") == "hostile" and Game.day > Content.WEEK_END \
		and Game.flags.get("dalsu_done", false) and not Game.dalsu_used \
		and c.get("ignore", {}).get("result", "") == "calm"


func _dalsu_help() -> void:
	Game.dalsu_used = true
	_log("[color=%s][i](대기석에서 안내 조끼를 입은 박달수 씨가 다가온다)[/i][/color]\n" % C_ACT)
	_log("[b][color=%s]박달수[/color][/b]  이봐요, 젊은 사람 일하는 데서 그렇게 소리 지르면 쓰나. 나도 여기서 소리 좀 질러 봤는데, 아무 소용 없어. 저기 앉아서 숨 좀 돌리고 와요.\n" % C_THEM)
	Game.pass_time(2)
	_calm(c["ignore"]["then"])


## 복지팀과 사이가 좋으면 하루 한 번, 소리만 지르는 민원인을 정다운이 데려간다. 위험한 사람에게는 못 쓴다.
func sos_available() -> bool:
	return serving and not leaving and c.get("phase") == "hostile" and c.get("correct") != "guard" \
		and Game.dept["welfare"] >= 70 and not Game.sos_used


# ─────────────────────────── 전화 ───────────────────────────

func _build_phone_menu() -> void:
	var pop := phone_btn.get_popup()
	pop.clear()
	var any := false
	if serving and not leaving and c.get("phase") == "calm" and c.get("needs_call", false) and not c.get("_called", false):
		if Game.outage():
			pop.add_item("위임자 확인 전화 (전산 장애로 번호 조회 불가)", 9)
			pop.set_item_disabled(pop.item_count - 1, true)
		else:
			pop.add_item("위임자에게 확인 전화", 0)
		any = true
	if sos_available():
		pop.add_item("2층 복지팀에 SOS", 1)
		any = true
	if serving and not leaving and not Game.tutorial:
		pop.add_item("옆자리 노 주무관에게 슬쩍 묻기 (오늘 %d번 남음)" % Game.hints_left, 2)
		pop.set_item_disabled(pop.item_count - 1, Game.hints_left <= 0)
		any = true
	if not any:
		pop.add_item("지금은 걸 곳이 없다", 9)
		pop.set_item_disabled(pop.item_count - 1, true)


func _on_phone(id: int) -> void:
	match id:
		0:
			_call()
		1:
			_decide("sos")
		2:
			_hint()


## 인감 대리 발급 때 위임자에게 확인 전화를 건다
func _call() -> void:
	var grantor := ""
	for d in c.get("docs", []):
		if d["kind"] == "proxy":
			grantor = d["grantor"]
	var rec: Dictionary = c.get("records", {}).get(grantor, {})
	c["_called"] = true
	Game.pass_time(3)
	Sfx.play("phone")
	_sys("(전산에 있는 %s 씨 번호 %s로 전화를 건다)" % [grantor, rec.get("phone", "?")])
	var key := "ok"
	if rec.get("phone_denies", false):
		key = "deny"
	elif String(rec.get("lost", "")) != "":
		key = "lost"
	_log("[b][color=#9fd3ff]전화[/color][/b]  %s\n" % Content.PHONE[key])
	if key != "ok" and c.has("flaw"):
		_say_them(c["flaw"]["reply"])
		if not c.get("_found", false):
			c["_found"] = true
			_slip("확인: " + c["flaw"].get("label", "위임자가 위임을 부인함"), SLIP_GOOD)
	_refresh_top()
	_refresh_all()


# ─────────────────────────── 결정 ───────────────────────────

func _my_line(action: String) -> String:
	if action.begins_with("reject:"):
		return "죄송하지만 처리해 드릴 수 없어요. 사유는 '%s'예요." % Content.REASONS[action.substr(7)]
	if action.begins_with("transfer:"):
		var d: Dictionary = Content.DEPTS[action.substr(9)]
		return "이 일은 %s %s에서 담당해요. 안내문 드릴게요." % [d["where"], d["name"]]
	match action:
		"process":
			return "처리됐습니다. 여기 있습니다."
		"reject":
			return "죄송하지만 이 서류로는 처리해 드릴 수 없어요."
		"eject":
			return "다른 분들 업무에 방해가 되니 나가 주세요."
		"guard":
			return "(책상 밑 비상벨을 누른다) 청원경찰님, 3번 창구요!"
		"accept":
			return "(상자를 받는다) 아이고, 감사합니다."
		"decline":
			return "마음만 받을게요. 규정상 받을 수가 없어서요."
		"bribe":
			return "(봉투를 서랍에 슬쩍 넣는다) ......처리해 드릴게요."
		"noh_back":
			return "죄송하지만 2번 창구에서 뽑으신 번호표라서요. 그쪽으로 가 주세요."
		"sos":
			return "(내선 전화를 든다) 다운 씨, 3번 창구에 좀 내려와 줄 수 있어?"
	return ""


func _decide(action: String) -> void:
	if not serving or leaving:
		return
	if action == "process" and not Content.is_ours(c):
		_sys("[전산] 3번 창구에서 처리할 수 없는 업무입니다. 모니터 [부서 안내]를 확인하세요.")
		Game.pass_time(3)
		return
	if tutorial and not tutorial.allow(action):
		return
	overlay.visible = false
	_drop_stamp()
	var o := Content.resolve(c, action)
	var line := _my_line(action)
	if line != "":
		_say_me(line)
	if o.has("say"):
		_say_them(o["say"])
	if o.has("mood"):
		portrait.set_face(c["look"], o["mood"])
	if o.get("escalate", false):
		_escalate(c["ignore"])
		return
	Game.apply(o)
	if o.has("leave_note"):
		_add_note_view(Game.story_note(o["leave_note"]), true)
	match action:
		"guard":
			Sfx.play("bell")
		"bribe":
			Sfx.play("coin")
	if o.get("keep", false) and action != "guard":
		Sfx.play("glass", -4.0)
	if not o.get("keep", false):
		Game.pass_time(Game.ACTION_TIME)
	if o.has("warn"):
		var extra := "  [벌점 +%d]" % o["pen"] if int(o.get("pen", 0)) > 0 else ""
		_slip(o["warn"] + extra, SLIP_BAD)
		Sfx.play("warn")
	elif o.has("note"):
		_slip(o["note"], SLIP_GOOD)
	_refresh_top()
	if o.get("keep", false):
		_shake(window, 8)
		_refresh_all()
		return
	_auto_stamp(action)
	if c.get("dumped", false) and action != "noh_back":
		Game.noh = clampi(Game.noh + 5, 0, 100)
	if o.get("result") == "right" and action.begins_with("reject:") and not c.get("story", false):
		var note := Game.schedule_revisit(c)
		if not note.is_empty():
			_say_them(Content.SAME_DAY[c["flaw"]["reason"]][1])
			_add_note_view(note, true)
	if o.get("result") == "right" and action.begins_with("transfer:") and not c.get("_bounced", false):
		var key := action.substr(9)
		if Game.dept[key] <= 30 and Game.rng.randf() < 0.4:
			Game.requeue_bounce(c, key)
			_slip("관계가 나쁜 %s에서 이 민원인을 되돌려 보낼 것 같다." % Content.dept_name(key), SLIP_BAD)
	if o.get("after", false):
		Game.later.append(Game.after_outage(c))
	if o.get("requeue", false):
		Game.requeue(c, o["sent_to"])
	if o.has("requeue_reason"):
		Game.requeue_reason(c, o["requeue_reason"])
	if o.get("result") == "right":
		if action == "process":
			Skeam.unlock("first_process")
			if c.get("_fixed", false):
				Skeam.unlock("fix_on_spot")
			if c.has("note_id"):
				Skeam.unlock("note_back")
		elif action.begins_with("transfer:"):
			Skeam.unlock("right_dept")
		if c.has("next"):
			_next_stage()
			return
	Game.stats["served"] += 1
	_leave()


## 도장 없이 결정된 경우(봉투, 자동 검사 등)에도 신청서에 도장 자국을 남긴다
func _ok_word(kind: String) -> String:
	match kind:
		"form":
			return "발급"
		"lease":
			return "확정"
	return "접수"


func _auto_stamp(action: String) -> void:
	var m := _main_paper()
	if m == null or not m.stamps.is_empty():
		return
	if action == "process" or action == "bribe":
		m.add_mark("ok", _ok_word(m.doc.get("kind", "")), m.size * 0.5)
		Sfx.play("stamp")
	elif action.begins_with("reject:"):
		m.add_mark("no", "반려", m.size * 0.5)
		Sfx.play("stamp")


func _ignore() -> void:
	if not serving or leaving:
		return
	if c.get("phase") == "violent":
		_say_me("(대꾸하지 않고 모니터만 본다)")
		_decide("ignore")
		return
	var ig: Dictionary = c.get("ignore", Content.DEFAULT_IGNORE)
	var lines: Array = ig["lines"]
	var i: int = c.get("_ig", 0)
	_say_me("(대꾸하지 않고 모니터만 본다)")
	if i < lines.size():
		_say_them(lines[i])
		Game.add_stress(int(ig.get("stress", 3)))
		Game.pass_time(2)
		i += 1
		c["_ig"] = i
	_refresh_top()
	if i < lines.size():
		return
	match String(ig["result"]):
		"calm":
			_calm(ig["then"])
		"leave":
			_decide("ignore_end")
		"escalate":
			_escalate(ig)


func _calm(then: Dictionary) -> void:
	for k in then:
		c[k] = then[k]
	c.erase("ignore")
	c.erase("_ig")
	c["lookup"] = Content._lookup_names(c)
	Skeam.unlock("calm_down")
	portrait.set_face(c["look"], c.get("mood", "normal"))
	_slip("먹금 성공. 민원인이 진정하고 용건을 말한다.", SLIP_GOOD)
	for line in c["intro"]:
		_say_them(line)
	_build_docs()
	if tab == "lookup":
		_show_lookup()
	_refresh_all()


func _escalate(ig: Dictionary) -> void:
	_say_them(ig.get("escalate", "(고함을 지른다)"))
	Game.add_stress(12)
	c["phase"] = "violent"
	c["outcomes"] = ig.get("violent", {})
	c.erase("ignore")
	portrait.set_face(c["look"], "angry")
	_slip("상황이 험악해졌다. 이제 말로는 안 된다. 책상의 비상벨!", SLIP_BAD)
	Sfx.play("glass")
	_shake(window, 8)
	_refresh_top()
	_refresh_all()


func _leave() -> void:
	leaving = true
	if c.has("note_id"):
		_peel_note(int(c["note_id"]))
	_refresh_all()
	_hand_back()
	await get_tree().create_timer(1.6).timeout
	var tw := create_tween().set_parallel()
	tw.tween_property(portrait_box, "position:x", portrait_x + 260, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(portrait_box, "modulate:a", 0.0, 0.3)
	Sfx.steps(4, "step", 0.2, -12.0)
	await tw.finished
	serving = false
	leaving = false
	c = {}
	ticket_label.text = "---"
	_build_docs()
	if tab == "lookup":
		_show_lookup()
	_refresh_all()
	if Game.check_fail():
		_go_ending()


## 책상 위 서류를 한데 모아 민원인 쪽으로 돌려서, 창구 밑 서류 넣는 곳으로 밀어 넣는다
func _hand_back() -> void:
	var kids := papers_layer.get_children()
	if kids.is_empty():
		return
	var to := slot.global_position + slot.size * 0.5 - papers_layer.global_position
	Sfx.play("paper")
	for i in kids.size():
		var p: Control = kids[i]
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.pivot_offset = p.size * 0.5
		var t := create_tween()
		t.tween_interval(i * 0.04)
		# 모으면서 민원인 쪽으로 돌린다
		t.tween_property(p, "position", to - p.size * 0.5 + Vector2(0, 70), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(p, "rotation_degrees", 180.0, 0.22)
		t.parallel().tween_property(p, "scale", Vector2(0.45, 0.45), 0.22)
		# 창구 밑으로 쏙
		t.tween_property(p, "position:y", to.y - p.size.y * 0.5 - 8, 0.14).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(p, "scale:y", 0.0, 0.14)
		t.parallel().tween_property(p, "modulate:a", 0.0, 0.14)


# ─────────────────────────── 여러 단계 · 그 자리 정정 · 메모 ───────────────────────────

## 한 가지 일이 끝나면 같은 사람이 다음 일을 내민다. 서류가 바뀌면 돌려주고 새로 받는다.
func _next_stage() -> void:
	var nx: Dictionary = c["next"]
	c.erase("next")
	leaving = true
	_refresh_all()
	if nx.has("docs"):
		_hand_back()
		await get_tree().create_timer(0.8).timeout
	else:
		await get_tree().create_timer(0.4).timeout
	if not serving:
		return
	for k in STAGE_DROP:
		c.erase(k)
	for k in nx:
		c[k] = nx[k]
	if not c.has("phase"):
		c["phase"] = "calm"
	c["lookup"] = Content._lookup_names(c)
	c["_start"] = Game.clock
	picked.clear()
	for n in [portrait, date_label]:
		n.set_meta("mark", "none")
		_paint(n, "none")
	leaving = false
	portrait.set_face(c["look"], c.get("mood", "normal"))
	for line in c.get("intro", []):
		_say_them(line)
	if nx.has("docs"):
		_build_docs()
	if tab == "lookup":
		_show_lookup()
	_refresh_all()


## 신청서 이름과 생년월일을 잘못 쓴 사람: 틀린 곳을 짚었으면 반려 대신 그 자리에서 고쳐 쓰게 할 수 있다
func _can_fix() -> bool:
	return c.get("_found", false) and c.has("_valid") and not c.get("_fixed", false) \
		and String(c.get("flaw", {}).get("reason", "")) == "info"


func _fix_on_spot() -> void:
	var v: Dictionary = c["_valid"]
	c["docs"] = v["docs"].duplicate(true)
	for d in c["docs"]:
		if d["kind"] in ["form", "move"]:
			d["corrected"] = true
	c["records"] = v["records"].duplicate(true)
	for k in ["flaw", "_valid", "reason"]:
		c.erase(k)
	c["correct"] = "process"
	c["_fixed"] = true
	c["thanks"] = "다시 안 와도 돼서 다행이네요. 감사합니다."
	_say_me("여기 두 줄 긋고 바로 고쳐 써 주세요. 옆에 서명하시고요.")
	_say_them("아, 네. (펜을 받아 고쳐 쓰고 서명한다)")
	Game.pass_time(2)
	Sfx.play("paper")
	_build_docs()
	_refresh_all()


## 창구 유리에 붙은 메모 한 장
func _add_note_view(n: Dictionary, fresh: bool) -> void:
	var v := Control.new()
	v.set_meta("note_id", int(n["id"]))
	v.size = Vector2(86, 78)
	v.pivot_offset = v.size * 0.5
	var i := notes_layer.get_child_count()
	v.position = NOTE_SPOTS[i % NOTE_SPOTS.size()] + Vector2(4, 6) * float(i / NOTE_SPOTS.size())
	v.rotation_degrees = [-4.0, 3.0, 2.0, -3.0][i % 4]
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	v.tooltip_text = "%s  %s\n%s" % [n["time"], n["name"], n["what"]]
	var tex := TextureRect.new()
	tex.texture = NOTE_TEX
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tex)
	var box := VBoxContainer.new()
	box.position = Vector2(7, 12)
	box.size = Vector2(72, 60)
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(box)
	for line in [[String(n["name"]), 13, true], [String(n["what"]), 12, false], [String(n["time"]), 11, false]]:
		var l := Label.new()
		l.text = DocView.keep_words(line[0])
		l.add_theme_font_size_override("font_size", line[1])
		l.add_theme_color_override("font_color", Color("3a2a12"))
		if line[2]:
			l.add_theme_font_override("font", BOLD)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 72
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(l)
	notes_layer.add_child(v)
	if fresh:
		v.scale = Vector2(1.6, 1.6)
		v.modulate.a = 0.0
		var tw := create_tween().set_parallel()
		tw.tween_property(v, "scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT)
		tw.tween_property(v, "modulate:a", 1.0, 0.12)
		Sfx.play("pop", -4.0)


## 메모 주인이 다녀가면 떼어 낸다
func _peel_note(id: int) -> void:
	Game.remove_note(id)
	for v in notes_layer.get_children():
		if int(v.get_meta("note_id", -1)) == id:
			var tw := create_tween().set_parallel()
			tw.tween_property(v, "position:y", v.position.y - 40, 0.35).set_ease(Tween.EASE_IN)
			tw.tween_property(v, "rotation_degrees", v.rotation_degrees + 25, 0.35)
			tw.tween_property(v, "modulate:a", 0.0, 0.35)
			tw.chain().tween_callback(v.queue_free)


func _pulse_note() -> void:
	var id := int(c.get("note_id", -1)) if serving else -1
	for v in notes_layer.get_children():
		var on := int(v.get_meta("note_id", -2)) == id
		v.modulate = Color(1.2, 1.15, 0.8) * (0.8 + 0.2 * sin(Time.get_ticks_msec() / 150.0)) if on else Color.WHITE


# ─────────────────────────── 힌트 · 스트레스 · 드링크 ───────────────────────────

## 옆자리 노 주무관에게 슬쩍 묻는다. 하루 세 번, 자꾸 물으면 투덜대고 호감이 준다.
func _hint() -> void:
	if Game.hints_left <= 0 or not serving or leaving:
		return
	var n := 3 - Game.hints_left   # 오늘 몇 번째인지 (0부터)
	if Game.noh < 25:
		_log("[b][color=%s]노 주무관[/color][/b]  ......알아서 해. 나도 바빠.\n" % C_THEM)
		Sfx.play("warn", -8.0)
		return
	Game.hints_left -= 1
	Game.hints_used += 1
	Sfx.play("hint", -6.0)
	Game.pass_time(1)
	var grumble: String = ["", "또? ......알았어, 봐 줄게. ", "3번, 이번이 진짜 마지막이다. 커피 한 잔 사. "][n]
	Game.noh = clampi(Game.noh - [0, 2, 4][n], 0, 100)
	_log("[color=%s][i](옆자리 노 주무관이 의자를 슬쩍 밀고 와서 서류를 넘겨다본다)[/i][/color]\n" % C_ACT)
	var say := ""
	var flash := ""
	var correct: String = c.get("correct", "")
	if c.get("phase") == "hostile":
		say = "저런 분은 그냥 둬. 대꾸하면 길어져. 손이 올라가면 비상벨이고."
	elif c.has("hint"):
		say = c["hint"]
	elif correct.begins_with("transfer:"):
		say = "그거 우리 일 아니야. 모니터 [부서 안내] 봐."
	elif c.get("needs_call", false) and not c.get("_called", false):
		say = "인감 대리 발급이면 위임자한테 전화부터 해야지."
	elif correct == "guard":
		say = "뭔가 쎄한데. 전산 사진이나 빨간 [주의] 칸 잘 봐. 이상하면 반려 말고 비상벨이야."
	elif c.has("flaw") and not c["flaw"].get("pairs", []).is_empty():
		say = Content.HINTS.get(String(c["flaw"]["reason"]), "뭔가 안 맞는 데가 있어. 잘 봐.")
		flash = String(c["flaw"]["pairs"][0][0])
	elif c.has("custom") and not correct in ["process", "reject"]:
		say = "그건 규정집에 나와. 한번 펴 봐."
	else:
		say = "내가 보기엔 문제없어 보이는데? 도장 찍어."
	_log("[b][color=%s]노 주무관[/color][/b]  %s%s\n" % [C_THEM, grumble, say])
	if flash != "":
		var node := _find_node_fid(self, flash)
		if node:
			_paint(node, "select")
			get_tree().create_timer(2.5).timeout.connect(func():
				if is_instance_valid(node):
					_paint(node, node.get_meta("mark", "none")))
	_refresh_top()


func _find_node_fid(n: Node, fid: String) -> Control:
	if n.has_meta("fid") and n.get_meta("fid") == fid:
		return n
	for ch in n.get_children():
		var r := _find_node_fid(ch, fid)
		if r:
			return r
	return null


## 스트레스가 80을 넘으면 가장자리가 붉게 물들고, 하루 한 번 최 팀장이 걱정한다
func _build_vignette() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0.7, 0.05, 0.05, 0.0))
	g.set_color(1, Color(0.7, 0.05, 0.05, 0.85))
	g.set_offset(0, 0.55)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 1.0)
	tex.width = 128
	tex.height = 72
	vignette = TextureRect.new()
	vignette.texture = tex
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.modulate.a = 0.0
	add_child(vignette)


func _update_stress_look() -> void:
	if not vignette:
		return
	var t := clampf((Game.stress - 75.0) / 25.0, 0.0, 1.0)
	vignette.modulate.a = t * (0.75 + 0.25 * sin(Time.get_ticks_msec() / 300.0))
	var key := "stress_warn_%d" % Game.day
	if Game.stress >= 80 and not Game.flags.has(key) and not Game.tutorial:
		Game.flags[key] = true
		Sfx.play("alarm", -4.0)
		var extra := "" if Game.can_leave_early() else " 이번 주는 이미 한 번 조퇴했어요. 한 번 더 쓰러지면 병가예요."
		_slip("최 팀장 메모: 얼굴이 너무 안 좋아요. 잠깐 숨 돌려요. 모니터 딴짓 정도는 못 본 척할게요." + extra, SLIP_BAD)


## 스트레스가 끝까지 찼다: 이번 주 처음이면 최 팀장이 조퇴시켜 준다
func _leave_early() -> void:
	leaving_early = true
	Game.flags["early_w%d" % Game.week()] = true
	Sfx.play("alarm")
	_log("[color=%s][i](눈앞이 핑 돈다. 최 팀장이 다가와 어깨를 짚는다)[/i][/color]\n" % C_ACT)
	_log("[b][color=%s]최 팀장[/color][/b]  오늘은 들어가요. 남은 분들은 제가 볼게요. 대신 이번 주에 또 이러면 저도 못 막아요.\n" % C_THEM)
	Game.apply({"rep": -3})
	Game.stress = 60
	Game.waiting = 0
	Game.events.append("스트레스로 쓰러질 뻔해서 조퇴했다. 남은 민원은 최 팀장이 받았다.")
	await get_tree().create_timer(2.5).timeout
	if not is_inside_tree():
		return
	Game.clock = Game.DAY_END
	_end_day()


## 벽: 승진 시험 D-데이와 공부 횟수
func _build_exam_label() -> void:
	exam_label = Label.new()
	exam_label.position = Vector2(810, 17)
	exam_label.size = Vector2(460, 26)
	exam_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	exam_label.add_theme_font_override("font", BOLD)
	exam_label.add_theme_font_size_override("font_size", 16)
	exam_label.add_theme_color_override("font_color", Color("c7d2de"))
	exam_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	exam_label.text = "승진 시험 D-%d   공부 %d/%d" % [Game.d_day(), Game.study, Content.EXAM_STUDY]
	%Wall.add_child(exam_label)


## 아침 책상 위에 쪽지 붙은 드링크가 놓인 날
func _build_drink() -> void:
	if Game.tutorial:
		return
	var note := ""
	for n in Content.LOVE_NOTES:
		if int(n[0]) == Game.day and (String(n[2]) == "" or Game.flags.has(n[2])):
			note = n[1]
	if note == "" or Game.flags.has("drink_%d" % Game.day):
		return
	drink = TextureButton.new()
	drink.texture_normal = preload("res://assets/ui/drink.png")
	drink.ignore_texture_size = true
	drink.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	drink.position = Vector2(226, 268)
	drink.size = Vector2(56, 72)
	drink.tooltip_text = "누가 놓고 간 드링크"
	drink.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	desk.add_child(drink)
	desk.move_child(drink, papers_layer.get_index())
	drink.pressed.connect(_open_drink.bind(note))


func _open_drink(note: String) -> void:
	Game.flags["drink_%d" % Game.day] = true
	Sfx.play("bottle")
	Game.add_stress(-5)
	drink.queue_free()
	var rows := [DocView._label(note, 17, Color("3a2a12"))]
	rows[0].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows[0].text = DocView.keep_words(note)
	var card := DocView._paper("드링크에 붙은 노란 쪽지", rows, null, Color("fff3a8"))
	card.custom_minimum_size.x = 300
	var p := _new_paper({"kind": "love_note"}, card, false)
	p.position = Vector2(300, 150)
	_sys("(드링크를 마셨다. 조금 힘이 난다)")
	_refresh_top()


func _end_day() -> void:
	Game.close_day()
	if Game.fail_reason != "":
		_go_ending()
	else:
		get_tree().change_scene_to_file("res://scenes/evening.tscn")


func _go_ending() -> void:
	if ending_started:
		return
	ending_started = true
	if Game.stress >= 100:
		Game.fail_reason = "burnout"
	get_tree().change_scene_to_file("res://scenes/ending.tscn")


# ─────────────────────────── 모니터 ───────────────────────────

func _clear_screen(name: String) -> void:
	tab = name
	for ch in screen_body.get_children():
		ch.queue_free()
	for pair in [["lookup", %TabLookup], ["dept", %TabDept], ["msg", %TabMsg], ["slack", %TabSlack]]:
		pair[1].modulate = Color(1, 1, 1) if pair[0] == name else Color(0.75, 0.78, 0.82)
	%TabMsg.text = "메신저" + (" (%d)" % unread if unread > 0 else "")


func _show_lookup() -> void:
	_clear_screen("lookup")
	if Game.outage():
		screen_body.add_child(_text("[전산 장애] 구청 서버 교체 작업 중입니다. 12:00 이후 다시 시도하세요.", 17, Color("b3261e"), true, 470))
		return
	if not serving or c.get("lookup", []).is_empty():
		screen_body.add_child(_text("민원인이 서류를 내면 서류에 적힌 이름을 자동으로 조회합니다.", 16, Color("4a5561"), false, 470))
		return
	if not c.get("_looked", false):
		c["_looked"] = true
		Game.pass_time(2)
	var records: Dictionary = c.get("records", {})
	for n in c.get("lookup", []):
		var card := DocView.record_card(n, records.get(n), _on_pick, Game.day > Content.WEEK_END)
		screen_body.add_child(card)


func _show_depts() -> void:
	_clear_screen("dept")
	var can: bool = serving and not leaving and c.get("phase") == "calm"
	for key in Content.DEPT_ORDER:
		var d: Dictionary = Content.DEPTS[key]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var word := Game.dept_word(key)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(_text("%s, %s, 관계 %s" % [d["name"], d["where"], word], 16, INK, true, 360))
		info.add_child(_text(d["jobs"], 15, Color("3a444f"), false, 360))
		row.add_child(info)
		var b := Button.new()
		b.text = "안내문 출력"
		b.add_theme_font_size_override("font_size", 15)
		b.disabled = not can
		b.pressed.connect(print_slip.bind(key))
		row.add_child(b)
		screen_body.add_child(row)
		screen_body.add_child(HSeparator.new())


func _show_slack() -> void:
	_clear_screen("slack")
	slack.build()


func _show_messages() -> void:
	unread = 0
	_clear_screen("msg")
	if messages.is_empty():
		screen_body.add_child(_text("새 메시지가 없습니다.", 16, Color("4a5561"), false, 470))
		return
	for i in range(messages.size() - 1, -1, -1):
		var m: Array = messages[i]
		screen_body.add_child(_text("%s  %s" % [m[0], m[1]], 14, m[3], true, 470))
		screen_body.add_child(_text(m[2], 16, INK, false, 470))


func _msg(who: String, text: String, color: Color) -> void:
	var t := int(Game.clock)
	messages.append(["%02d:%02d" % [t / 60, t % 60], who, text, color])
	if tab == "msg":
		_show_messages()
	else:
		unread += 1
		%TabMsg.text = "메신저 (%d)" % unread


## 팀장 메모와 알림: 모니터 위에 잠깐 띄우고 메신저에 남긴다
func _slip(text: String, color: Color) -> void:
	var who := "알림"
	var body := text
	if text.begins_with("최 팀장 메모"):
		who = "최 팀장"
		body = text.substr(text.find(":") + 1).strip_edges()
	_msg(who, body, Color("b3261e") if color == SLIP_BAD else Color("2f6a3e"))
	if color == SLIP_GOOD:
		Sfx.play("notify", -10.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_content_margin_all(8)
	toast.add_theme_stylebox_override("panel", sb)
	toast_label.text = DocView.keep_words(("%s: %s" % [who, body]) if who != "알림" else body)
	toast.visible = true
	toast.modulate.a = 1.0
	if toast_tween:
		toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.tween_interval(5.0)
	toast_tween.tween_property(toast, "modulate:a", 0.0, 0.6)
	toast_tween.tween_callback(func(): toast.visible = false)


# ─────────────────────────── 규정집 바인더 ───────────────────────────

func _show_rules() -> void:
	Sfx.play("book_open", -6.0)
	_clear_overlay("규정집")
	for r in Game.rules_so_far():
		var is_new: bool = r["day"] == Game.day and Game.day > 1
		var head := _text(("[새 규정] " if is_new else "") + r["title"], 19, Color("ffd479") if is_new else Color("f2ede2"), true, 940)
		var card := _card(Color("ffd479") if is_new else Color("5b6270"))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		v.add_child(DocView.pickable(head, "rule:" + r["title"], _on_pick))
		v.add_child(_text(r["text"], 17, Color("e6e1d6"), false, 940))
		card.add_child(v)
		overlay_body.add_child(card)
	overlay.visible = true


func _card(accent: Color) -> PanelContainer:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.05)
	sb.border_color = accent
	sb.border_width_left = 4
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 14
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", sb)
	return card


func _clear_overlay(title: String) -> void:
	overlay_title.text = title
	for ch in overlay_body.get_children():
		ch.queue_free()


func _text(t: String, font_size: int, color: Color, bold := false, width := 680) -> Label:
	var l := Label.new()
	l.text = DocView.keep_words(t)
	if bold:
		l.add_theme_font_override("font", BOLD)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


# ─────────────────────────── 돋보기(지적하기) ───────────────────────────

func _set_inspect(on: bool) -> void:
	inspecting = on
	inspect_hint.visible = on
	if exam_label:
		exam_label.visible = not on
	inspect_btn.modulate = Color(1.25, 1.15, 0.6) if on else Color.WHITE
	portrait.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	if on:
		_drop_stamp()
	else:
		for p in picked:
			_set_mark(p[1], "none")
		picked.clear()


func _pick_input(e: InputEvent, fid: String, node: Control) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_on_pick(fid, node, "click")


func _on_pick(fid: String, node: Control, ev: String) -> void:
	if not inspecting or holding != "" or not serving or leaving or c.get("phase") != "calm":
		return
	match ev:
		"enter":
			if node.get_meta("mark", "none") == "none":
				_paint(node, "hover")
		"exit":
			_paint(node, node.get_meta("mark", "none"))
		"click":
			for i in picked.size():
				if picked[i][0] == fid:
					_set_mark(node, "none")
					picked.remove_at(i)
					return
			picked.append([fid, node])
			_set_mark(node, "select")
			if picked.size() == 2:
				var ok := _judge(picked[0][0], picked[1][0])
				for p in picked:
					_set_mark(p[1], "flaw" if ok else "none")
				picked.clear()
				_refresh_top()


## 두 칸이 이 민원의 틀린 곳이면 민원인이 반응한다
func _judge(a: String, b: String) -> bool:
	Game.pass_time(1)
	var f := Content.find_flaw(c, a, b)
	if f.is_empty():
		_sys("두 항목 사이에 문제는 없어 보인다.")
		return false
	_say_me("여기 이 두 부분이 서로 안 맞는데요?")
	_say_them(f["reply"])
	if not c.get("_found", false):
		c["_found"] = true
		Skeam.unlock("sharp_eye")
		_slip("지적: " + f.get("label", Content.REASONS[f["reason"]]), SLIP_GOOD)
		_refresh_responses()   # 신청서 오타면 '그 자리에서 고쳐 쓰게 한다'가 나타난다
	return true


func _set_mark(node: Control, kind: String) -> void:
	if not is_instance_valid(node):
		return
	if node.get_meta("mark", "none") == "flaw" and kind != "flaw":
		kind = "flaw"
	node.set_meta("mark", kind)
	_paint(node, kind)


func _paint(node: Control, kind: String) -> void:
	if not is_instance_valid(node):
		return
	if node is PanelContainer:
		if kind == "none":
			node.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			return
		var sb := StyleBoxFlat.new()
		sb.bg_color = PAINT[kind][0]
		sb.border_color = PAINT[kind][1]
		sb.set_border_width_all(2 if kind != "hover" else 0)
		sb.set_corner_radius_all(3)
		node.add_theme_stylebox_override("panel", sb)
	elif node is Portrait:
		node.frame = Color(0, 0, 0, 0) if kind == "none" else PAINT[kind][1] if kind != "hover" else Color(1, 0.85, 0.2, 0.6)
		node.queue_redraw()
	else:
		node.modulate = {"none": Color.WHITE, "hover": Color(1, 1, 0.8), "select": Color(1, 0.85, 0.4), "flaw": Color(1, 0.55, 0.5)}[kind]


# ─────────────────────────── 말풍선·연출 ───────────────────────────

func _say_them(line: String) -> void:
	if line.begins_with("("):
		# "(행동) 말"이면 행동과 말을 나눠 적는다
		var close := line.find(")")
		var rest := line.substr(close + 1).strip_edges() if close > 0 else ""
		if line.left(close).contains("정다운") or line.left(close).contains("최 팀장"):
			rest = ""   # 다른 사람이 끼어들어 하는 말은 나누지 않는다
		_log("[color=%s][i]%s[/i][/color]\n" % [C_ACT, line.substr(0, close + 1) if rest != "" else line])
		if rest != "":
			_log("[b][color=%s]민원인[/color][/b]  %s\n" % [C_THEM, rest])
	else:
		_log("[b][color=%s]민원인[/color][/b]  %s\n" % [C_THEM, line])


func _say_me(line: String) -> void:
	_log("[b][color=%s]나[/color][/b]  %s\n" % [C_ME, line])


func _log(t: String) -> void:
	log_box.append_text(DocView.keep_words(t))


func _sys(line: String) -> void:
	_log("[color=%s]%s[/color]\n" % [C_SYS, line])


func _shake(node: Control, amount: float) -> void:
	var base := node.position
	var tw := create_tween()
	for i in 5:
		tw.tween_property(node, "position", base + Vector2(randf_range(-amount, amount), randf_range(-amount * 0.6, amount * 0.6)), 0.035)
	tw.tween_property(node, "position", base, 0.035)
