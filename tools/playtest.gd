extends Node
## 실제 창구 화면으로 2주(10일)를 자동 진행하며 런타임 오류와 이야기 흐름을 확인한다.
## 1회차는 규정대로, 2회차는 1주차를 나쁘게 보낸 뒤 2주차 만회 이야기를 확인한다.
## 실행: godot --headless --path . res://tools/playtest.tscn

const OFFICE := preload("res://scenes/office.tscn")
const EXPECT_GOOD := ["dalsu_served", "grandma_helped", "mee_helped", "declined_gift", "scam_caught", "audit_pass",
	"dalsu_done", "envelope_refused", "noh_asked", "mom_helped",
	"jiwoo_moved", "okja_done", "mansu_thanked", "mee_extended", "noh_refused", "seoyoung_served", "donghun_left", "councilor_refused",
	"minjae_fixed", "changsik_refused", "haneul_ok", "jaehyuk_ok", "minjae_saved"]
const EXPECT_BAD := ["taemin_caught", "mee_second", "dalsu_done", "donghun_left", "seoyoung_served"]

var seen := {}
var wrong_sent := false
var wrong_reason_sent := false
var noh_back_done := false
var ok := true
var ui_decisions := 0   # 도장·안내문·서류 넣는 곳으로 확정한 결정 수


func _ready() -> void:
	Engine.time_scale = 20.0
	Engine.set_meta("skeam_log", [])
	await _run_tutorial()
	var tut_log: Array = Engine.get_meta("skeam_log").duplicate()
	if not tut_log.is_empty():
		print("  [FAIL] 연습 창구에서 도전 과제가 나감: %s" % [tut_log])
		ok = false
	# ── 1회차: 규정대로 ──
	Game.new_game()
	Game.rng.seed = 7
	Game.revisit_chance = 1.0
	await _run_days(1, Content.LAST_DAY)
	var e := Game.ending()
	print("ENDING 1: %s" % e["title"])
	for line in e["body"]:
		print("  " + str(line))
	_expect("1회차", EXPECT_GOOD)
	for k in ["requeue", "escalate", "reason_return", "revisit", "sos", "noh_back", "dumped", "call_ok", "outage_wait", "outage_after", "dalsu_help", "payday", "photo_shown",
			"stage", "note", "fix", "lease", "seal_reg"]:
		if not seen.has(k):
			print("  [MISSING] %s" % k)
			ok = false
	print("seen=%s ui_decisions=%d" % [seen, ui_decisions])
	var got: Array = Engine.get_meta("skeam_log")
	for id in ["first_process", "sharp_eye", "right_dept", "calm_down", "dalsu_served", "scam_caught", "envelope_refused", "councilor_refused", "audit_pass",
			"minjae_saved", "haneul_ok", "jaehyuk_ok", "fix_on_spot", "note_back"]:
		if not got.has(id):
			print("  [MISSING] 도전 과제 %s" % id)
			ok = false
	if ui_decisions < 30:
		print("  [MISSING] 도장·안내문 결정이 너무 적음")
		ok = false

	# ── 2회차: 1주차를 나쁘게 보냈다면 ──
	Game.new_game()
	Game.rng.seed = 11
	Game.flags = {"scam_escaped": true, "mee_hurt": true, "envelope_refused": true, "dalsu_ejected": true}
	Game.day = Content.WEEK_END + 1
	await _run_days(Content.WEEK_END + 1, Content.LAST_DAY)
	print("ENDING 2: %s" % Game.ending()["title"])
	if not Engine.get_meta("skeam_log").has("taemin_caught"):
		print("  [MISSING] 도전 과제 taemin_caught")
		ok = false
	_expect("2회차", EXPECT_BAD)

	# ── 나쁜 길: 봉투를 받으면 금요일 메모에 사고 소식, 엔딩은 파면 ──
	Game.new_game()
	Game.flags["bribe_taken"] = true
	Game.day = 5
	var bad_memo := Game.memo_for_today().begins_with(Content.STALKER_NEWS)
	var fired: bool = Game.week_report()["title"] == "파면"
	print("bribe path: memo=%s fired=%s" % [bad_memo, fired])
	ok = ok and bad_memo and fired

	# ── 저장하고 이어 하기 ──
	Game.new_game()
	Game.day = 4
	Game.flags = {"dalsu_done": true}
	Game.money = 123000
	Game.future = {5: [{"name": "메모 손님", "note_id": 1}]}
	Game.notes = [{"id": 1, "name": "메모 손님", "what": "위임장 받아 오기", "time": "13:20"}]
	Game.save_game()
	Game.new_game()
	var loaded := Game.load_game()
	var same: bool = loaded and Game.day == 4 and Game.flags.has("dalsu_done") and Game.money == 123000 and Game.notes.size() == 1 and Game.future.get(5, []).size() == 1
	print("save/load: %s" % same)
	ok = ok and same
	Game.clear_save()
	ok = ok and not Game.has_save()

	# ── 저녁 화면이 넘치지 않는지 ──
	Game.new_game()
	Game.day = 3
	Game.events = ["긴 사건 한 줄 ".repeat(8), "두 번째 사건 ".repeat(8), "세 번째 사건 ".repeat(8)]
	var ev: Control = load("res://scenes/evening.tscn").instantiate()
	add_child(ev)
	await get_tree().process_frame
	ev._mom(true)
	ev._choose("friend")
	await get_tree().process_frame
	await get_tree().process_frame
	var panel: Control = ev.get_node("Panel")
	var need := panel.get_combined_minimum_size().y
	print("evening panel min height %.0f / %.0f" % [need, panel.size.y])
	ok = ok and need <= panel.size.y + 1
	print("PLAYTEST " + ("OK" if ok else "FAIL"))
	get_tree().quit()


## 연습 창구를 처음부터 끝까지: 틀린 결정은 막히고, 단계가 끝까지 넘어가야 한다
func _run_tutorial() -> void:
	Game.new_game()
	Game.tutorial = true
	Game.queue = Tutorial.CASES.duplicate()
	var o: Node = OFFICE.instantiate()
	add_child(o)
	o.set_process(false)
	await _frames(2)
	var t: Tutorial = o.tutorial
	var m: Paper
	# 1. 정상 서류 (처음엔 일부러 반려해 본다: 막혀야 한다)
	o._on_next()
	await _frames(2)
	o._decide("reject:info")
	var blocked: bool = o.serving and not o.leaving
	t.confirmed = true
	await _frames(2)
	o.pick_stamp("ok")
	await _frames(2)
	o.stamp_paper(o._main_paper(), Vector2(120, 60))
	await _frames(2)
	o.return_papers()
	await _until(func(): return not o.serving)
	# 2. 틀린 서류
	o._on_next()
	await _frames(2)
	o.inspect_btn.button_pressed = true
	o._judge("form.subject_birth", "id.birth")
	await _frames(3)
	m = o._main_paper()
	o.pick_stamp("no")
	o.stamp_paper(m, Vector2(120, 60))
	await _frames(2)
	o._on_paper_erase(m)
	await _frames(2)
	o.pick_stamp("no")
	o.stamp_paper(m, Vector2(120, 60))
	await _frames(2)
	o.reason = "info"
	await _frames(2)
	o.inspect_btn.button_pressed = false
	o.return_papers()
	await _until(func(): return not o.serving)
	# 3. 다른 부서 (잘못 뽑은 안내문은 휴지통에)
	o._on_next()
	await _frames(2)
	o._show_depts()
	await _frames(2)
	o.print_slip("clean")
	o._throw_away(o.slip_paper)
	var trashed: bool = o.slip_paper == null
	o.print_slip("welfare")
	await _frames(2)
	o.return_papers()
	await _until(func(): return not o.serving)
	# 4. 소리 지르는 사람 (비상벨은 막혀야 한다)
	o._on_next()
	await _frames(2)
	o._decide("guard")
	blocked = blocked and o.serving and not o.leaving
	for i in 3:
		o._ignore()
	await _frames(2)
	t.confirmed = true
	await _frames(2)
	o.pick_stamp("ok")
	o.stamp_paper(o._main_paper(), Vector2(120, 60))
	o.return_papers()
	await _until(func(): return not o.serving)
	await _frames(2)
	var at_end: bool = t.steps[t.step].get("finish", false)
	print("tutorial: step %d/%d finished=%s wrong_blocked=%s trash=%s" % [t.step + 1, t.steps.size(), at_end, blocked, trashed])
	ok = ok and at_end and blocked and trashed
	o.queue_free()
	Game.tutorial = false


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _until(cond: Callable) -> void:
	for i in 600:
		if cond.call():
			return
		await get_tree().process_frame


func _expect(tag: String, want: Array) -> void:
	var missing := want.filter(func(f): return not Game.flags.has(f))
	print("%s missing flags=%s" % [tag, missing])
	if not missing.is_empty():
		ok = false


func _run_days(from: int, to: int) -> void:
	for day in range(from, to + 1):
		Game.day = day
		Game.start_day()
		if day == Content.PAYDAY and Game.notices.has(Content.PAYDAY_NOTE):
			seen["payday"] = true
		if day == 4:
			Game.queue.insert(1, "N")   # SOS와 돌려보내기를 모두 거치도록 한 명 더
			Game.dept["welfare"] = maxi(Game.dept["welfare"], 75)   # 부서가 늘어 복지팀 관계가 느리게 오르므로 SOS를 쓸 수 있게
		var office: Node = OFFICE.instantiate()
		add_child(office)
		office.set_process(false)
		await get_tree().process_frame
		for i in 12:
			if day == 3 and i == 4:
				Game.clock = maxf(Game.clock, 720.0)   # 점심때
			if day == Content.OUTAGE_DAY and i == 6:
				Game.clock = maxf(Game.clock, Content.OUTAGE_END)   # 전산 복구
			office._check_events()
			if office.noon_pending:
				office._noon(true)
			office._on_next()
			await _play(office)
		print("day %d: stats=%s rep=%d pen=%d stress=%d money=%d noh=%d" % [day, Game.stats, Game.rep, Game.pen, Game.stress, Game.money, Game.noh])
		office.queue_free()
		Game.close_day()
		if Game.fail_reason != "":
			print("  FAIL REASON: %s" % Game.fail_reason)
			ok = false
			return
		if day == 3:
			Game.mom_choice(true)
		if day == Content.WEEK_END:
			var rep := Game.week_report()
			print("  WEEK REPORT: %s continue=%s" % [rep["title"], rep.get("continue", false)])
			if not rep.get("continue", false):
				ok = false
				return
			Game.weekend()
		elif day < Content.LAST_DAY:
			Game.evening("rest" if Game.stress >= 60 else ("study" if day % 2 == 0 else "friend"))


## 반려 도장을 찍고, 사유서에 체크하고, 서류 넣는 곳으로 돌려준다
func _ui_reject(office: Node, want: String) -> void:
	var m: Paper = office._main_paper()
	if m == null:
		office._decide("reject:" + want)
		return
	office.pick_stamp("no")
	office.stamp_paper(m, Vector2(120, 60))
	office.return_papers()          # 사유를 안 골랐으니 막혀야 한다
	if not office.serving or office.leaving:
		print("  [FAIL] 반려 사유 없이 돌려주기가 통과됨")
		ok = false
	office.reason = want
	office.return_papers()
	ui_decisions += 1


func _play(office: Node) -> void:
	office._show_rules()
	var c0: Dictionary = office.c
	if c0.get("revisit", false):
		seen["revisit"] = true
	if c0.get("dumped", false):
		seen["dumped"] = seen.get("dumped", 0) + 1
	if c0.has("_after"):
		seen["outage_wait"] = true
	if String(c0.get("intro", [""])[0]).begins_with("오전에 전산이"):
		seen["outage_after"] = true
	var guard := 0
	while office.serving and guard < 24:
		if office.leaving:
			await get_tree().process_frame   # 다음 단계로 넘어가는 중이거나 떠나는 중
			continue
		guard += 1
		var c: Dictionary = office.c
		if c.has("next"):
			seen["stage"] = true
		if c.has("note_id"):
			seen["note"] = true
		for d in c.get("docs", []):
			if d["kind"] in ["lease", "seal_reg"]:
				seen[d["kind"]] = true
		if c.get("returned_reason", false):
			seen["reason_return"] = true
		elif c.get("returned", false):
			seen["requeue"] = true
		match String(c.get("phase", "calm")):
			"hostile":
				if c.get("dumped", false) and not noh_back_done and seen.get("dumped", 0) >= 2:
					noh_back_done = true
					seen["noh_back"] = true
					office._decide("noh_back")
				elif office.dalsu_available():
					seen["dalsu_help"] = true
					office._dalsu_help()
				elif office.sos_available():
					seen["sos"] = true
					office._decide("sos")
				else:
					office._ignore()
			"violent":
				seen["escalate"] = true
				office._decide("guard")
			"gift":
				office._decide("decline")
			_:
				office._show_lookup()
				if Game.day > Content.WEEK_END and not Game.outage():
					seen["photo_shown"] = true
				for i in c.get("asks", []).size():
					office._ask(i)
				if c.get("needs_call", false) and not c.get("_called", false) and not Game.outage():
					office._call()
					seen["call_ok"] = true
				var correct: String = c["correct"]
				if c.has("flaw") and not c.get("_found", false) and not c["flaw"]["pairs"].is_empty():
					var pair: Array = c["flaw"]["pairs"][0]
					office._judge(pair[0], pair[1])
				if office._can_fix() and seen.get("fix_tries", 0) < 3:
					# 신청서 오타는 그 자리에서 고쳐 쓰게 해 본다 (그다음엔 처리 도장)
					seen["fix_tries"] = seen.get("fix_tries", 0) + 1
					seen["fix"] = true
					office._fix_on_spot()
					continue
				if correct == "reject":
					var want: String = c["flaw"]["reason"]
					if not wrong_reason_sent and not c.get("story", false) and not c.has("_after"):
						wrong_reason_sent = true
						office._decide("reject:" + ("info" if want != "info" else "photo"))
					else:
						_ui_reject(office, want)
				elif correct.begins_with("transfer:") and not wrong_sent and not c.get("story", false):
					wrong_sent = true
					office._decide("transfer:clean" if correct != "transfer:clean" else "transfer:police")
				elif correct.begins_with("transfer:"):
					office.print_slip(correct.substr(9))
					office.return_papers()
					ui_decisions += 1
				elif correct == "process" and office._main_paper() != null:
					office.pick_stamp("ok")
					office.stamp_paper(office._main_paper(), Vector2(120, 60))
					office.return_papers()
					ui_decisions += 1
				else:
					office._decide(correct)
	while office.serving:
		await get_tree().process_frame
