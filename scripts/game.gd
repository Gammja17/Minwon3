extends Node
## 한 주 동안의 상태: 평판, 벌점, 스트레스, 이야기 플래그, 오늘의 대기열.

const DAY_START := 540.0   # 09:00
const DAY_END := 1080.0    # 18:00
const STORY_RUSH := 960.0  # 16:00 이후엔 남은 이야기 민원을 먼저 부른다
const MIN_PER_SEC := 1.5
const ARRIVE_EVERY := 32.0
const ACTION_TIME := 4.0
const DAILY_COST := 15000   # 점심값과 교통비

var rng := RandomNumberGenerator.new()
var day := 1
var rep := 50
var pen := 0
var stress := 20
var study := 0
var flags := {}
var fail_reason := ""
var money := 380000   # 신규 발령이라 첫 월급(20일) 전
var dept := {}        # 구청 부서들과의 관계 0~100
var noh := 50         # 2번 창구 노진수 주무관의 호감
var future := {}      # 날짜 -> 그날 다시 올 민원인들

var clock := DAY_START
var waiting := 0
var ticket := 0
var queue: Array = []
var stats := {}
var events: Array = []
var day_start_rep := 50
var day_start_pen := 0
var _arrive_acc := 0.0
var _press_acc := 0.0
var calls_today := {}
var sos_used := false
var noh_helped := false
var notices: Array = []   # 창구 화면에 띄울 알림
var revisit_chance := 0.6
var later: Array = []      # 전산 장애로 돌려보낸 사람들 (오후에 다시 온다)
var tutorial := false      # 연습 창구 중
var speed := 1.0           # 빨리 감기 중이면 5
var stocks := {}           # 햇살증권 {종목: {price, open, hold, cost}}
var stock_news: Array = []
var stock_profit := 0      # 판 주식에서 번 돈 (잃으면 줄어든다)
var slack_caught := 0      # 딴짓하다 최 팀장에게 들킨 횟수
var _stock_acc := 0.0
var stock_rng := RandomNumberGenerator.new()
var dalsu_used := false    # 박달수 씨 대기실 도우미 (하루 한 번)
var notes: Array = []      # 창구 유리에 붙은 "좀 이따 다시 올게요" 메모 [{id, name, what, time}]
var note_seq := 0

## 저장: 아침마다(업무 메모를 펼 때) 한 번, 고른 서류철(슬롯)에. 웹판에서는 SKEAM이 계정 클라우드에 올린다.
const OLD_SAVE := "user://save.txt"
const SLOTS := 3
var slot := 1
var hints_left := 3      # 옆자리 노 주무관에게 물어볼 수 있는 횟수 (하루)
var hints_used := 0
const SAVE_KEYS := ["day", "rep", "pen", "stress", "study", "flags", "money", "dept", "noh", "future", "notes", "note_seq",
	"stocks", "stock_news", "stock_profit", "slack_caught"]


func new_game() -> void:
	rng.randomize()
	tutorial = false
	day = 1
	rep = 50
	pen = 0
	stress = 20
	study = 0
	flags = {}
	fail_reason = ""
	money = 380000
	dept = {"welfare": 55, "passport": 50, "traffic": 50, "clean": 50, "tax": 50, "police": 50}
	noh = 50
	future = {}
	notes = []
	note_seq = 0
	stocks = {}
	for code in Content.STOCKS:
		stocks[code] = {"price": Content.STOCKS[code]["price"], "open": Content.STOCKS[code]["price"], "hold": 0, "cost": 0}
	stock_news = []
	stock_profit = 0
	slack_caught = 0
	stock_rng.randomize()
	start_day()


func start_day() -> void:
	clock = DAY_START
	waiting = 3 + (day - 1) % 5 + 1
	ticket = 0
	queue = Content.SEQUENCES[day].duplicate()
	if day == 5 and noh <= 30:
		queue.insert(1, "N")
	for r in future.get(day, []):
		queue.insert(rng.randi_range(1, queue.size()), r)
	future.erase(day)
	calls_today = {}
	speed = 1.0
	hints_left = 3
	for code in stocks:
		stocks[code]["open"] = stocks[code]["price"]
	sos_used = false
	noh_helped = false
	notices = []
	later = []
	dalsu_used = false
	if day == Content.PAYDAY:
		money += Content.SALARY
		notices.append(Content.PAYDAY_NOTE)
	stats = {"served": 0, "right": 0, "wrong": 0}
	events = []
	day_start_rep = rep
	day_start_pen = pen
	_arrive_acc = 0.0
	_press_acc = 0.0


func save_path(s: int) -> String:
	return "user://save_%d.txt" % s


func save_game() -> void:
	if tutorial:
		return
	var d := {"rng_seed": rng.seed, "rng_state": rng.state}
	for k in SAVE_KEYS:
		d[k] = get(k)
	var f := FileAccess.open(save_path(slot), FileAccess.WRITE)
	if f:
		f.store_string(var_to_str(d))


func has_save(s := -1) -> bool:
	return FileAccess.file_exists(save_path(slot if s < 0 else s))


func save_day(s := -1) -> int:
	return int(save_info(s).get("day", 0))


## 서류철에 적어 보여 줄 것: 날, 평판, 잔고
func save_info(s := -1) -> Dictionary:
	var d: Variant = _read_save(slot if s < 0 else s)
	return d if d is Dictionary else {}


func load_game(s := -1) -> bool:
	var want := slot if s < 0 else s
	var d: Variant = _read_save(want)
	if not d is Dictionary:
		return false
	new_game()
	slot = want
	for k in SAVE_KEYS:
		if d.has(k):
			set(k, d[k])
	rng.seed = d.get("rng_seed", rng.seed)
	rng.state = d.get("rng_state", rng.state)
	return true   # 하루 시작(start_day)은 업무 메모의 [창구로 가기]에서


func clear_save(s := -1) -> void:
	var want := slot if s < 0 else s
	if has_save(want):
		DirAccess.remove_absolute(save_path(want))


func _read_save(s: int) -> Variant:
	# 슬롯이 생기기 전의 저장은 1번 서류철로 옮긴다
	if s == 1 and not FileAccess.file_exists(save_path(1)) and FileAccess.file_exists(OLD_SAVE):
		DirAccess.rename_absolute(OLD_SAVE, save_path(1))
	if not FileAccess.file_exists(save_path(s)):
		return null
	var f := FileAccess.open(save_path(s), FileAccess.READ)
	return str_to_var(f.get_as_text()) if f else null


func week() -> int:
	return 1 if day <= Content.WEEK_END else 2


## 스트레스가 끝까지 차면 한 주에 한 번은 조퇴로 버틴다
func can_leave_early() -> bool:
	return not flags.has("early_w%d" % week())


func d_day() -> int:
	return Content.EXAM_DATE - int(Content.TODAY[day - 1])


func tick(delta: float) -> void:
	if clock >= DAY_END:
		return
	var m := delta * MIN_PER_SEC * speed
	clock = minf(clock + m, DAY_END)
	_tick_stocks(m)
	_arrive_acc += m
	if _arrive_acc >= ARRIVE_EVERY:
		_arrive_acc -= ARRIVE_EVERY
		waiting += 1
	_press_acc += m
	if _press_acc >= 20.0:
		_press_acc -= 20.0
		if waiting >= 8:
			stress = mini(stress + 1, 100)
	if noh >= 65 and waiting >= 8 and not noh_helped:
		noh_helped = true
		waiting -= 3
		notices.append("노 주무관이 대기자 세 명을 2번 창구로 데려갔다. \"줄이 길다, 이번엔 내가 좀 받아 줄게.\"")
	if day == Content.OUTAGE_DAY and clock >= Content.OUTAGE_END and not flags.has("outage_over"):
		flags["outage_over"] = true
		notices.append(Content.OUTAGE_OVER)


## 수요일 오전 전산 장애
func outage() -> bool:
	return day == Content.OUTAGE_DAY and clock < Content.OUTAGE_END


func pass_time(minutes: float) -> void:
	clock = minf(clock + minutes, DAY_END)


func is_closed() -> bool:
	return clock >= DAY_END


func next_case() -> Dictionary:
	var c: Dictionary = {}
	while c.is_empty():
		if not outage() and not later.is_empty() and (queue.is_empty() or rng.randf() < 0.5):
			c = later.pop_front()
			break
		if queue.is_empty():
			c = Content.make_routine(day, rng, outage())
			break
		var idx := 0
		if clock >= STORY_RUSH:
			for i in queue.size():
				if not (queue[i] is String and queue[i] == "R"):
					idx = i
					break
		var e: Variant = queue.pop_at(idx)
		if e is Dictionary:
			c = e
		elif e == "R":
			c = Content.make_routine(day, rng, outage())
		elif e == "N":
			c = Content.make_dumped(day, rng)
		else:
			c = Content.story(e, flags.merged({"_rep": rep}))
		# 전산 장애 중에는 전산이 필요한 사람(다시 온 사람, 이야기 인물)을 오후로 미룬다
		if outage() and not c.is_empty() and not c.has("_after") and Content.needs_db(c):
			later.append(c)
			c = {}
	waiting = maxi(waiting - 1, 0)
	ticket += 1
	c["ticket"] = day * 100 + ticket
	return c


## 엉뚱한 부서로 보낸 민원인이 잠시 뒤 다시 줄을 선다
func requeue(c: Dictionary, sent_to: String) -> void:
	var r := _returning(c)
	r["intro"] = ["%s에서 여기 일이 아니래요! 괜히 왔다 갔다만 했잖아요." % sent_to]
	if c.has("again"):
		r["intro"].append(c["again"])
	queue.insert(mini(1, queue.size()), r)
	waiting += 1


## 반려 사유를 잘못 들은 민원인이 엉뚱한 걸 알아보고 같은 서류로 다시 온다
func requeue_reason(c: Dictionary, reason_text: String) -> void:
	var r := _returning(c)
	r["returned_reason"] = true
	r["intro"] = ["아까 '%s' 때문이라고 하셨죠? 알아봤는데 그건 문제없다던데요. 다시 봐 주세요." % reason_text]
	queue.insert(mini(1, queue.size()), r)
	waiting += 1


## 부서 관계가 나쁘면 제대로 보낸 민원인도 되돌려 보낸다
func requeue_bounce(c: Dictionary, key: String) -> void:
	var r := _returning(c)
	r["_bounced"] = true
	r["intro"] = ["%s에서 여기서 하라던데요? 자기들 일이 아니래요." % Content.dept_name(key)]
	if c.has("again"):
		r["intro"].append(c["again"])
	queue.insert(mini(1, queue.size()), r)
	waiting += 1


## 맞는 사유로 반려된 민원인이 서류를 고쳐서 다시 온다.
## 금방 챙겨 올 수 있는 것이면 창구 유리에 메모를 붙이고 같은 날 다시 온다(그 메모를 돌려준다). 아니면 하루이틀 뒤.
func schedule_revisit(c: Dictionary) -> Dictionary:
	if not c.has("_valid") or rng.randf() > revisit_chance:
		return {}
	var why: String = c["flaw"]["reason"]
	if Content.SAME_DAY.has(why) and not c.has("note_id") and clock < 960.0 and rng.randf() < 0.65:
		return _note_and_return(c, why)
	var d := day + rng.randi_range(1, 2)
	if d > Content.LAST_DAY:
		return {}
	var r := _revisit_case(c)
	if not future.has(d):
		future[d] = []
	future[d].append(r)
	return {}


func _note_and_return(c: Dictionary, why: String) -> Dictionary:
	note_seq += 1
	var t := int(clock)
	var note := {"id": note_seq, "name": c["name"], "what": Content.SAME_DAY[why][0], "time": "%02d:%02d" % [t / 60, t % 60]}
	notes.append(note)
	var r: Dictionary
	if Content.NOTE_PLEA.has(why) and rng.randf() < 0.25:
		# 챙겨 오지 못하고 사정한다: 그대로 다시 반려해야 한다
		r = _returning(c)
		r.erase("_valid")
		r["intro"] = ["아까 메모 붙여 두고 간 %s예요." % c["name"], Content.NOTE_PLEA[why]]
		r["mood"] = "sad"
	else:
		r = _revisit_case(c)
		r["intro"] = ["아까 메모 붙여 두고 간 %s예요. %s" % [c["name"], Content.NOTE_BACK[why]]]
		r["mood"] = "normal"
	r["note_id"] = note_seq
	queue.insert(mini(rng.randi_range(2, 4), queue.size()), r)
	waiting += 1
	return note


## 이야기 인물이 메모를 붙이고 가고, 그 메모 주인(다른 사람일 수도 있다)이 오늘 늦게 온다
func story_note(ln: Dictionary) -> Dictionary:
	note_seq += 1
	var t := int(clock)
	var note := {"id": note_seq, "name": ln["name"], "what": ln["what"], "time": "%02d:%02d" % [t / 60, t % 60]}
	notes.append(note)
	var r := Content.story(ln["story"], flags.merged({"_rep": rep}))
	r["note_id"] = note_seq
	queue.append(r)
	waiting += 1
	return note


func _revisit_case(c: Dictionary) -> Dictionary:
	var r := _returning(c)
	r.merge(c["_valid"], true)
	for k in ["flaw", "_valid", "returned", "returned_reason"]:
		r.erase(k)
	r["correct"] = "process"
	r["reason"] = ""
	r["mood"] = "normal"
	r["revisit"] = true
	r["intro"] = ["지난번에 말씀하신 거 챙겨 왔어요.", Content.FIX_LINES[c["flaw"]["reason"]]]
	r["thanks"] = "이번엔 됐네요. 감사합니다!"
	r["lookup"] = Content._lookup_names(r)
	r["asks"] = []
	return r


## 전산 장애로 돌려보낸 사람이 오후에 원래 서류를 들고 다시 온다
func after_outage(c: Dictionary) -> Dictionary:
	var r: Dictionary = c["_after"].duplicate(true)
	r["intro"] = ["오전에 전산이 안 된다고 해서 다시 왔어요."] + r["intro"]
	return r


func _returning(c: Dictionary) -> Dictionary:
	var r: Dictionary = c.duplicate(true)
	r["returned"] = true
	r["mood"] = "angry"
	r["phase"] = "calm"
	for k in ["_ig", "_found", "_start", "_nag1", "_nag2", "_looked"]:
		r.erase(k)
	return r


func apply(o: Dictionary) -> void:
	rep = clampi(rep + int(o.get("rep", 0)), 0, 100)
	pen += int(o.get("pen", 0))
	stress = clampi(stress + int(o.get("stress", 0)), 0, 100)
	pass_time(float(o.get("time", 0)))
	var f: String = o.get("flag", "")
	if f != "":
		flags[f] = true
		if Skeam.FLAGS.has(f):
			Skeam.unlock(Skeam.FLAGS[f])
	var e: String = o.get("event", "")
	if e != "":
		events.append(e)
	money += int(o.get("money", 0))
	noh = clampi(noh + int(o.get("noh", 0)), 0, 100)
	if o.get("sos", false):
		sos_used = true
	var dd: Dictionary = o.get("dept", {})
	for key in dd:
		dept[key] = clampi(dept[key] + int(dd[key]), 0, 100)
		if dd[key] < 0 and not calls_today.has(key):
			calls_today[key] = true
			add_stress(2)
			events.append("%s에서 전화가 왔다. \"이런 걸 왜 우리한테 보내요?\"" % Content.dept_name(key))
	match String(o.get("result", "")):
		"right":
			stats["right"] += 1
		"wrong":
			stats["wrong"] += 1


func dept_word(key: String) -> String:
	var v: int = dept.get(key, 50)
	return "좋음" if v >= 70 else ("나쁨" if v <= 30 else "보통")


static func won(v: int) -> String:
	if v % 10000 == 0:
		return "%d만 원" % (v / 10000)
	return "%.1f만 원" % (v / 10000.0)


func add_stress(n: int) -> void:
	stress = clampi(stress + n, 0, 100)


func check_fail() -> bool:
	if stress >= 100 and not can_leave_early():
		fail_reason = "burnout"
	elif rep <= 0:
		fail_reason = "demoted"
	return fail_reason != ""


func remove_note(id: int) -> void:
	notes = notes.filter(func(n): return int(n["id"]) != id)


## 햇살증권: 10분마다 조금씩 오르내리고, 정해진 날에는 뉴스가 터진다
func _tick_stocks(minutes: float) -> void:
	_stock_acc += minutes
	while _stock_acc >= 10.0:
		_stock_acc -= 10.0
		for code in stocks:
			var s: Dictionary = stocks[code]
			s["price"] = maxi(500, int(round(float(s["price"]) * (1.0 + stock_rng.randf_range(-0.018, 0.019)) / 50.0)) * 50)
	for i in Content.STOCK_EVENTS.size():
		var ev: Array = Content.STOCK_EVENTS[i]
		var key := "stock_ev_%d" % i
		if day == int(ev[0]) and clock >= float(ev[1]) and not flags.has(key):
			flags[key] = true
			var s: Dictionary = stocks[ev[2]]
			s["price"] = int(round(float(s["price"]) * (1.0 + float(ev[3]) / 100.0) / 50.0)) * 50
			stock_news.append(ev[4])
			if int(s["hold"]) > 0:
				notices.append("보유 종목 뉴스: " + String(ev[4]))


static func comma(v: int) -> String:
	var t := str(absi(v))
	var out := ""
	while t.length() > 3:
		out = "," + t.right(3) + out
		t = t.left(t.length() - 3)
	return ("-" if v < 0 else "") + t + out


## 업무 종료. 남은 대기 인원을 정산한다.
func close_day() -> void:
	# 메모를 붙이고 간 사람이 마감까지 못 왔으면 내일 아침에 온다
	for e in queue:
		if e is Dictionary and e.has("note_id"):
			if day < Content.LAST_DAY:
				var r: Dictionary = e.duplicate(true)
				r["intro"] = ["어제 메모 붙여 두고 간 %s예요. 어제는 문 닫을 때까지 못 와서요." % r["name"]] + r["intro"].slice(1)
				if not future.has(day + 1):
					future[day + 1] = []
				future[day + 1].append(r)
			else:
				remove_note(int(e["note_id"]))
	money -= DAILY_COST
	if waiting > 0:
		rep = clampi(rep - waiting / 3, 0, 100)
		events.append("마감 때까지 대기 중이던 %d명을 그냥 돌려보냈다." % waiting)
	if pen >= 10:
		fail_reason = "discipline"
	check_fail()


func memo_for_today() -> String:
	var m: String = Content.MEMOS[day]
	if day == 5 and flags.get("scam_done", false):
		m = Content.SCAM_NEWS + m
	if day == 5 and (flags.get("bribe_taken", false) or flags.get("stalker_given", false)):
		m = Content.STALKER_NEWS + m
	if day == 6 and flags.get("dalsu_done", false):
		m += Content.DALSU_HELPER_MEMO
	return m


func new_rules_today() -> Array:
	return Content.RULES.filter(func(r): return r["day"] == day)


func rules_so_far() -> Array:
	return Content._rules_sorted().filter(func(r): return r["day"] <= day)


## 저녁 선택. 결과 문장을 돌려준다.
func evening(choice: String) -> String:
	match choice:
		"rest":
			add_stress(-35)
			return "집에 가서 씻고 일찍 누웠다. 오랜만에 푹 잤다."
		"friend":
			add_stress(-20)
			money -= 20000
			return Content.rumor(day, flags)
		"overtime":
			add_stress(10)
			money += 35000
			return "불 꺼진 사무실에 남아 밀린 서류를 정리했다. 시간외수당 3만 5천 원이 붙는다."
		"date":
			add_stress(-30)
			money -= 25000
			flags["love_dinner"] = true
			return "4번 창구 서하준과 동네 국숫집에 갔다. 창구 얘기, 이상한 민원인 얘기를 하다 보니 국수가 다 불었다. 헤어질 때 하준이 \"내일 마지막 날 잘해요\"라고 했다."
		"study":
			add_stress(5)
			study += 1
			return "책상에 앉아 행정법 기출문제를 풀었다. 피곤하지만 한 발짝 나아간 기분이다."
	return ""


## 저녁에 오는 어머니 문자
func mom_sms() -> String:
	match day:
		2:
			return "다음 주 화요일에 무릎 수술 날짜 잡혔어. 별거 아니래. 걱정 말고 밥 잘 챙겨 먹어."
		3:
			return "병원에 물어보니 보험에서 안 되는 게 좀 있대. 혹시 50만 원만 보태 줄 수 있니? 어려우면 괜찮아."
		4:
			if flags.get("mom_helped", false):
				return "수술 준비 다 됐어. 네 덕분에 병원비 걱정은 덜었다. 고마워."
			return "이모가 좀 보태 준대. 엄마는 괜찮으니까 신경 쓰지 마."
		6:
			return "내일 오전에 수술이야. 엄마 걱정은 말고 네 일 잘해."
		7:
			return "수술 잘 끝났대. 마취 깨니까 네 생각부터 나더라." + ("" if flags.get("mom_helped", false) else " 병원비는 이모가 보태 줬어.")
		8:
			return "오늘부터 재활 시작했어. 아파도 참을 만해."
		9:
			return "주말에 시간 되면 한번 내려올래? 반찬 좀 해 놨어."
	return ""


func mom_choice(send: bool) -> String:
	if send:
		money -= 500000
		flags["mom_helped"] = true
		add_stress(-5)
		return "엄마: 고마워. 첫 월급도 아직일 텐데... 엄마가 나중에 꼭 갚을게."
	flags["mom_declined"] = true
	add_stress(10)
	return "엄마: 그래, 괜찮아. 엄마가 어떻게든 해 볼게. 신경 쓰지 마."


## 1주차 감사 지적 사항. 선물은 이때 벌점으로 바뀐다(한 번만).
func audit_findings() -> Array:
	var out: Array = []
	if flags.get("took_gift", false):
		if not flags.has("gift_counted"):
			flags["gift_counted"] = true
			pen += 1
		out.append("민원인에게서 음료 상자를 받음 (청탁금지 위반, 벌점 +1)")
	if flags.get("vip_favor", false):
		out.append("위임장 없이 인감증명서를 대리 발급함")
	if flags.get("scam_done", false):
		out.append("분실 신고된 인감의 위임장으로 인감증명서를 발급해 사기 피해가 생김")
	if flags.get("audit_fail", false):
		out.append("암행 점검에서 위임장 없는 대리 발급")
	if flags.get("stalker_given", false):
		out.append("교부 제한 대상의 등본을 남에게 발급해 가정폭력 피해자의 주소가 새어 나감")
	return out


## 2주차 인사 평가에 들어가는 일
func final_findings() -> Array:
	var out: Array = []
	if flags.get("noh_favor_done", false):
		out.append("동료 부탁으로 위임장 없이 인감증명서를 발급함")
	if flags.get("councilor_favor", false):
		out.append("구의원 요청으로 위임장 없이 등본을 발급함")
	if flags.get("taemin_done", false):
		out.append("위조 신분증으로 인감증명서를 발급함")
	if flags.get("minjae_erased", false):
		out.append("집주인 말만 듣고 세입자의 전입신고를 빼 줌")
	if slack_caught >= 2:
		out.append("근무 시간 중 딴짓 %d번 적발" % slack_caught)
	if flags.get("changsik_told", false):
		out.append("세입자의 전입 날짜를 집주인에게 알려 줌")
	if flags.get("jaehyuk_filmed", false):
		out.append("촬영 중인 창구에서 서류를 처리해 다른 민원인 정보가 찍힘")
	return out


func _fatal() -> Dictionary:
	match fail_reason:
		"burnout":
			return {"title": "번아웃: 병가", "body": ["어느 날 아침, 몸이 일어나지지 않았다.", "병원에서는 쉬어야 한다고 했다. 3번 창구에는 다른 사람이 앉았다."]}
		"demoted":
			return {"title": "민원 폭주: 전보", "body": ["3번 창구에 대한 민원이 쌓이고 쌓였다.", "월요일자로 구청 문서고 발령이 났다. 이제 민원인을 만날 일은 없다."]}
		"discipline":
			return {"title": "징계위원회", "body": ["잘못 나간 서류가 너무 많았다.", "징계위원회는 감봉 3개월을 의결했다."]}
	if flags.get("bribe_taken", false):
		return {"title": "파면", "body": [
			"경찰이 3번 창구로 찾아왔다. 윤서영 씨 등본이 어떻게 나갔는지 묻는 질문에, 서랍 속 흰 봉투가 대신 대답했다.",
			"윤서영 씨는 그날 밤 다시 짐을 쌌다고 한다.",
			"징계위원회는 파면을 의결했다. 3번 창구 명패에서 이름이 떼어졌다."]}
	return {}


## 1주차 금요일 저녁. 치명적이지 않으면 "continue"로 2주차에 이어진다.
func week_report() -> Dictionary:
	var fatal := _fatal()
	if not fatal.is_empty():
		return fatal
	var findings := audit_findings()
	if pen >= 10:
		fail_reason = "discipline"
		return _fatal()
	var title := "1주차 감사 결과: 이상 없음"
	var body: Array = []
	if pen >= 8:
		title = "1주차 감사 결과: 견책"
		body.append("감사팀은 이번 주 3번 창구에서 나간 서류에 문제가 많았다고 보고했다. 인사 기록에 견책이 남았다. 다음 주에도 이러면 버티기 어렵다.")
	elif pen >= 5:
		title = "1주차 감사 결과: 주의"
		body.append("감사팀은 몇 가지 실수를 지적했다. 크게 문제 삼지는 않았지만, 팀장이 한숨을 쉬었다.")
	else:
		body.append("감사팀은 3번 창구에서 큰 문제를 찾지 못했다. 팀장이 어깨를 한 번 두드려 주고 갔다.")
	if not findings.is_empty():
		body.append("")
		body.append("[감사 지적 사항]")
		for f in findings:
			body.append("- " + f)
	body.append("")
	body.append("[주말]")
	body.append("토요일에는 늦잠을 잤다. 일요일 저녁, 다음 주 출근 가방을 챙겼다.")
	return {"title": title, "body": body, "continue": true}


func weekend() -> void:
	add_stress(-20)
	day = Content.WEEK_END + 1


func ending() -> Dictionary:
	var fatal := _fatal()
	if not fatal.is_empty():
		return fatal
	var findings := final_findings()
	var score := rep - pen * 4 - findings.size() * 8
	var title := ""
	var body: Array = []
	if score >= 70:
		title = "인사 평가 S: 이달의 친절 공무원"
		body.append("구청 게시판에 '햇살동 3번 창구 칭찬합니다'라는 글이 여러 번 올라왔다. 이달의 친절 공무원 명단에 이름이 올랐다.")
	elif score >= 50:
		title = "인사 평가 A: 믿고 맡기는 3번 창구"
		body.append("팀장은 평가서에 '처음 2주 치고는 믿고 맡길 만하다'고 적었다.")
	elif score >= 30:
		title = "인사 평가 B: 무난한 2주"
		body.append("큰 사고도, 큰 칭찬도 없었다. 3번 창구는 다음 주에도 열린다.")
	else:
		title = "인사 평가 C: 관리 대상"
		body.append("평가서에 '업무 숙지 필요'라는 말이 세 번 적혔다. 다음 달부터 팀장이 창구 뒤에 앉는다.")
	if not findings.is_empty():
		body.append("")
		body.append("[인사 평가 지적 사항]")
		for f in findings:
			body.append("- " + f)
	body.append("")
	body.append("[승진 시험]")
	if study >= 5:
		body.append("토요일 시험장에서 문제를 넘길 때마다 저녁마다 풀던 기출문제가 떠올랐다. 합격이다. 8급 승진 후보에 이름이 올랐다.")
	else:
		body.append("토요일 시험장에서 절반쯤은 처음 보는 문제였다. 저녁마다 공부한 날이 %d번뿐이었다. 다음 기회를 노려야 한다." % study)
	body.append("")
	body.append("[그 뒤의 이야기]")
	for line in _epilogue():
		body.append(line)
	body.append("")
	body.append("[집]")
	for line in _home():
		body.append(line)
	return {"title": title, "body": body}


func _epilogue() -> Array:
	var out: Array = []
	if flags.get("dalsu_done", false):
		out.append("박달수 씨는 안내 조끼를 입고 번호표 기계 옆에 선다. 소리 지르는 사람이 오면 먼저 다가가 말을 건다.")
	else:
		out.append("박달수 씨의 등본에는 아직 이정숙 씨의 이름이 남아 있다.")
	if flags.get("grandma_helped", false):
		out.append("박영철 할아버지는 제때 요양병원에 들어갔다. 김순자 할머니는 매일 병문안을 간다.")
	elif flags.get("grandma_rejected", false):
		out.append("박영철 할아버지는 한 달을 더 집에서 기다린 끝에 요양병원에 들어갔다.")
	if flags.get("mee_extended", false) or flags.get("mee_helped", false):
		out.append("이미영 씨네는 긴급지원이 연장됐다. 남편은 지팡이를 짚고 걷기 시작했다.")
	elif flags.get("mee_second", false):
		out.append("이미영 씨는 엿새 늦게 긴급 생계비를 받았다. 그 엿새 동안의 일은 말하지 않는다.")
	elif flags.get("mee_hurt", false):
		out.append("이미영 씨는 그 뒤로 어디에도 다시 신청하지 않았다.")
	if flags.get("scam_caught", false):
		out.append("최만수 할아버지는 새 인감으로 은행 일을 마쳤다. 조카 얘기는 하지 않는다.")
	elif flags.get("taemin_caught", false):
		out.append("정태민은 김도현 씨 명의로 한 번 더 시도하다 3번 창구에서 붙잡혔다. 최만수 할아버지 사건까지 함께 조사받고 있다.")
	elif flags.get("taemin_done", false):
		out.append("김도현 씨는 자기 집이 담보로 잡혔다는 걸 은행 전화를 받고서야 알았다.")
	elif flags.get("scam_escaped", false):
		out.append("정태민은 아직 잡히지 않았다. 그 얼굴을 기억하는 사람은 3번 창구뿐이다.")
	elif flags.get("scam_done", false):
		out.append("최만수 할아버지는 집을 되찾으려고 소송을 시작했다.")
	if flags.get("stalker_given", false):
		out.append("윤서영 씨는 또 이사를 갔다. 이번엔 어디로 갔는지 아무도 모른다.")
	elif flags.get("stalker_caught", false):
		out.append("차동훈은 경찰에 넘겨졌고, 윤서영 씨의 전 남편에게는 접근금지 명령이 내려졌다. 윤서영 씨는 요즘 밤에 창문을 열어 둔다.")
	elif flags.get("envelope_refused", false) or flags.get("envelope_guarded", false):
		out.append("윤서영 씨는 자기 주소를 캐러 왔던 사람이 있었다는 걸 모른다. 그걸로 됐다.")
	if flags.get("love_dinner", false):
		out.append("4번 창구 서하준과는 요즘 퇴근길이 같다. 월요일 아침 책상 위에는 또 드링크가 놓여 있었다.")
	elif flags.get("love_lunch", false):
		out.append("서하준과는 점심 친구가 됐다. 김밥은 번갈아 가며 고른다.")
	elif flags.get("love_friend", false) or flags.get("love_hurt", false):
		out.append("4번 창구 드링크는 이제 노 주무관 책상에 놓인다. 노 주무관은 영문도 모르고 좋아한다.")
	if flags.get("doyun_done", false):
		out.append("윤도윤 어린이는 학교 숙제 '우리 동네 사람들'에 3번 창구를 그렸다. 그림 속 창구 유리에는 노란 메모가 붙어 있다.")
	elif flags.get("doyun_cried", false):
		out.append("윤도윤 어린이는 한동안 주민센터 앞을 지날 때마다 엄마 손을 꼭 잡았다.")
	if flags.get("minjae_saved", false):
		out.append("오민재 씨는 경매에서 보증금을 대부분 돌려받았다. 확정일자 도장이 찍힌 계약서를 액자에 넣어 뒀다고 한다.")
	elif flags.get("minjae_erased", false):
		out.append("오민재 씨는 은행보다 순서가 밀려 보증금의 절반을 잃었다. 집주인 황보창식은 사기 혐의로 조사를 받고 있다.")
	elif flags.get("minjae_turned", false) or flags.get("minjae_no_date", false):
		out.append("오민재 씨는 보증금을 돌려받으려고 소송을 시작했다. 확정일자가 없는 계약서는 힘이 약했다.")
	if flags.get("haneul_ok", false) or flags.get("haneul_rushed", false):
		out.append("김하늘 학생은 원서를 5시 58분에 냈다. 합격 문자를 받으면 3번 창구에 알려 주겠다고 했다.")
	elif flags.get("haneul_missed", false):
		out.append("김하늘 학생은 그 대학 원서를 내지 못했다. 재수 학원 상담을 받았다고 한다.")
	if flags.get("jaehyuk_ok", false):
		out.append("도재혁의 영상 제목은 '생각보다 친절했던 햇살동 3번 창구'로 바뀌었다. 댓글에는 칭찬이 더 많다.")
	elif flags.get("jaehyuk_filmed", false):
		out.append("도재혁의 영상에 3번 창구 모니터가 모자이크 없이 나왔다. 구청 감사실에 민원이 들어갔다.")
	elif flags.get("jaehyuk_angry", false):
		out.append("'햇살동 갑질 공무원' 영상은 조회수 3만을 넘겼다. 구청 게시판이 한동안 시끄러웠다.")
	if flags.get("noh_favor_done", false):
		out.append("노 주무관은 요즘 3번 창구에 커피를 자주 가져다준다. 처제 인감 건은 평가서에 한 줄로 남았다.")
	elif flags.get("noh_refused", false):
		out.append("노 주무관은 한동안 말을 걸지 않았다. 금요일 퇴근길에 \"원칙대로 하는 게 맞긴 하지\" 하고 한마디 하고 갔다.")
	if flags.get("councilor_favor", false):
		out.append("김태식 구의원은 동네 모임에서 3번 창구를 칭찬했다. 인사 평가에는 다르게 적혔다.")
	elif flags.get("councilor_refused", false):
		out.append("김태식 구의원은 순시 보고서에 '3번 창구 융통성 부족'이라고 적었다. 최 팀장은 그 보고서를 서랍에 넣었다.")
	return out


func _home() -> Array:
	var out: Array = []
	if money >= Content.TRIP_COST:
		money -= Content.TRIP_COST
		out.append("토요일 시험이 끝나고 기차를 탔다. 어머니는 지팡이를 짚고 역까지 마중을 나왔다.")
	else:
		out.append("기차표 살 돈이 없어서 전화로 대신했다. 어머니는 \"반찬은 택배로 보낼게\"라고 했다.")
	money -= Content.RENT
	if money < 0:
		out.append("25일, 월세 45만 원이 빠져나가지 못했다. 집주인에게 사정하는 문자를 보냈다.")
	else:
		out.append("25일, 월세 45만 원을 내고 통장에 %s이 남았다." % won(money))
	var held := 0
	for code in stocks:
		held += int(stocks[code]["price"]) * int(stocks[code]["hold"])
	if held > 0:
		out.append("아직 팔지 않은 주식이 %s원어치 있다. 월세 통장에는 들어가지 않는 돈이다." % comma(held))
	elif stock_profit >= 100000:
		out.append("점심시간 몰래 한 주식으로 %s원을 벌었다. 팀장님은 모른다." % comma(stock_profit))
	elif stock_profit <= -100000:
		out.append("점심시간 몰래 한 주식으로 %s원을 날렸다. 다시는 안 한다고 다짐했다." % comma(-stock_profit))
	if flags.get("mom_helped", false):
		out.append("어머니 수술비를 보탠 건 잘한 일이었다. 그건 확실하다.")
	elif flags.get("mom_declined", false):
		out.append("어머니 병원비는 이모가 보탰다. 전화할 때마다 괜찮다고 하시는데, 목소리가 조금 작다.")
	return out
