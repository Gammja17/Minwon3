extends SceneTree
## 무작위·이야기 민원이 규정집과 어긋나지 않는지 검사한다.
## 실행: godot --headless --path . --script res://tools/sim.gd

const CT := preload("res://scripts/content.gd")

const STORY_DAYS := {"d1_first": 1, "d1_dalsu": 1, "d1_passport": 1, "d1_photo": 1, "d2_grandma": 2, "d2_vip": 2,
	"d2_drunk": 2, "d3_dalsu": 3, "d3_mee": 3, "d3_license": 3, "d4_death": 4, "d4_mee": 4, "d4_scam": 4, "d4_envelope": 4,
	"d5_auditor": 5, "d5_dalsu": 5,
	"w2_jiwoo": 6, "w2_reissue": 6, "w2_mansu": 6, "w2_taemin": 7, "w2_mee_again": 7, "w2_mee": 8, "w2_noh_favor": 8,
	"w2_seoyoung": 9, "w2_dalsu": 9, "w2_donghun": 9, "w2_councilor": 10,
	"d4_haneul": 4, "w2_minjae": 6, "w2_changsik": 7, "w2_jaehyuk": 8, "w2_minjae2": 10}
const FLAG_SETS := [
	{},
	{"dalsu_ejected": true, "mee_helped": true, "scam_caught": true, "envelope_refused": true, "dalsu_done": true,
		"_rep": 80, "vip_favor": true, "noh_lunch_helped": true},
	{"scam_escaped": true, "mee_hurt": true, "envelope_guarded": true},
	{"scam_done": true, "stalker_given": true, "_rep": 30},
	{"minjae_fixed": true, "minjae_erased": true},
	{"minjae_fixed": true, "changsik_told": true},
]
const STAGE_DROP := ["flaw", "_valid", "_found", "_asked", "needs_call", "_called", "guard_warn", "reason", "custom", "outcomes",
	"reject_say", "thanks", "again", "asks", "win_flag", "fail_flag", "win_event", "fail_event", "verified_by"]

var fails := 0
var revisits := 0
var story_seen := {}
var stages := 0


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261012
	for day in range(1, CT.LAST_DAY + 1):
		var counts := {}
		for outage in ([false, true] if day == CT.OUTAGE_DAY else [false]):
			for i in 3000:
				var c := _calm(CT.make_routine(day, rng, outage))
				var tag := "day%d%s routine #%d" % [day, " 장애" if outage else "", i]
				_check(c, day, tag)
				var key: String = c["correct"] + (":system" if c.has("_after") else "")
				counts[key] = counts.get(key, 0) + 1
				if c.has("_valid"):
					# 고쳐서 다시 올 때의 서류는 규정을 통과해야 한다
					var v := c.duplicate(true)
					v.merge(c["_valid"], true)
					v["lookup"] = CT._lookup_names(v)
					var got := _expected(v, mini(day + 1, CT.LAST_DAY))
					if got != "process":
						_fail(tag + " revisit", "고친 서류가 %s로 판정됨: %s" % [got, v["docs"]])
					revisits += 1
		if day >= 2:
			for i in 300:
				var d := _calm(CT.make_dumped(day, rng))
				if not d.get("dumped", false) or not d.get("outcomes", {}).has("noh_back"):
					_fail("dumped #%d" % i, "떠넘긴 민원인에게 돌려보내기 선택지가 없음")
				_check(d, day, "day%d dumped #%d" % [day, i])
		print("day %d: %s" % [day, counts])
	for flags in FLAG_SETS:
		for id in STORY_DAYS:
			var c: Dictionary = CT.story(id, flags)
			if c.is_empty():
				continue
			story_seen[id] = true
			_check(_calm(c), STORY_DAYS[id], id)
	for id in STORY_DAYS:
		if not story_seen.has(id):
			_fail(id, "어떤 플래그 조합에서도 나오지 않음")
	print("story cases checked: %d, revisits checked: %d, next stages checked: %d" % [story_seen.size(), revisits, stages])
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)


func _calm(c: Dictionary) -> Dictionary:
	var r := c.duplicate(true)
	if r.get("phase") == "hostile" and r.has("ignore") and r["ignore"]["result"] == "calm":
		for k in r["ignore"]["then"]:
			r[k] = r["ignore"]["then"][k]
		r["lookup"] = CT._lookup_names(r)
	return r


func _check(c: Dictionary, day: int, tag: String) -> void:
	if c.has("next"):
		if c["correct"] in ["reject", "guard"] or String(c["correct"]).begins_with("transfer:"):
			_fail(tag, "다음 단계가 있는데 첫 단계 정답이 %s" % c["correct"])
		var n := c.duplicate(true)
		n.erase("next")
		for k in STAGE_DROP:
			n.erase(k)
		for k in c["next"]:
			n[k] = c["next"][k]
		if not n.has("phase"):
			n["phase"] = "calm"
		n["lookup"] = CT._lookup_names(n)
		stages += 1
		_check(n, day, tag + " (다음 단계)")
		c = c.duplicate()
		c.erase("next")
	var correct: String = c["correct"]
	if c.has("_after"):
		# 전산 장애 중: '전산 장애'로 반려하면 오후에 원래 서류로 다시 온다
		if correct != "reject" or c["flaw"]["reason"] != "system":
			_fail(tag, "전산 장애 대기 민원의 정답이 '전산 장애' 반려가 아님")
		if not CT.resolve(c, "reject:system").get("after", false):
			_fail(tag, "'전산 장애' 반려 뒤 오후 재방문이 없음")
		_check_flaw(c, day, tag)
		_check(_calm(c["_after"]), day, tag + " (오후)")
		return
	if (correct == "reject" or correct == "guard") and not c.get("docs", []).is_empty():
		_check_flaw(c, day, tag)
	if correct == "reject" and c.has("flaw"):
		var want: String = c["flaw"]["reason"]
		if CT.resolve(c, "reject:" + want).get("result") != "right":
			_fail(tag, "맞는 사유 반려가 right가 아님")
		var other: String = "info" if want != "info" else "photo"
		var o2 := CT.resolve(c, "reject:" + other)
		if not c.get("story", false) and (o2.get("result") != "wrong" or not o2.has("requeue_reason")):
			_fail(tag, "틀린 사유 반려가 재방문으로 이어지지 않음: %s" % o2)
	elif c.get("phase") == "calm" or c.get("phase") == "gift" or correct == "guard":
		var called := c.duplicate()
		called["_called"] = true
		var o := CT.resolve(called, correct)
		if o.get("result") != "right" and c.get("phase") != "gift":
			_fail(tag, "정답 행동(%s)이 right가 아님: %s" % [correct, o])
		if correct == "process" and c.get("needs_call", false) and CT.resolve(c, "process").get("result") != "wrong":
			_fail(tag, "확인 전화 없이 떼 줘도 벌점이 없음")
	if c.get("phase") != "calm":
		return
	if not correct in ["process", "reject", "guard"] and not correct.begins_with("transfer:"):
		var mine := false
		for pair in c.get("custom", []):
			mine = mine or pair[0] == correct
		if not mine:
			_fail(tag, "정답(%s)을 고를 버튼이 없음" % correct)
		return
	if correct.begins_with("transfer:"):
		if not CT.DEPTS.has(correct.substr(9)):
			_fail(tag, "없는 부서: " + correct)
		return
	var expect := _expected(c, day)
	if expect != correct:
		_fail(tag, "생성기=%s 검사기=%s 이유=%s\n  docs=%s\n  records=%s" % [correct, expect, c.get("reason", ""), c["docs"], c["records"]])


## 규정집만 보고 판단하는 별도 검사기
func _expected(c: Dictionary, day: int) -> String:
	var id: Dictionary = {}
	var main: Dictionary = {}
	var proxy: Dictionary = {}
	var cert: Dictionary = {}
	for d in c["docs"]:
		match String(d["kind"]):
			"id": id = d
			"form", "move", "death_form", "reissue", "lease", "seal_reg": main = d
			"proxy": proxy = d
			"death_cert": cert = d
	var R: Dictionary = c["records"]
	var face := JSON.stringify(c["look"])
	if main.is_empty():
		return "reject"
	if main["kind"] == "reissue":
		# 신분증이 없으니 전산 사진이 유일한 본인 확인
		if not R.has(main["name"]) or R[main["name"]]["birth"] != main["birth"]:
			return "reject"
		if JSON.stringify(R[main["name"]].get("look", {})) != face:
			return "guard"
		return "process"
	if id.is_empty() and c.get("verified_by", "") == "finger" and main.has("applicant") and R.has(main["applicant"]):
		# 신분증 대신 지문으로 본인 확인을 마쳤다
		id = {"name": main["applicant"], "birth": R[main["applicant"]]["birth"], "look": c["look"], "type": "주민등록증", "date": "2020.01.01"}
	if id.is_empty():
		return "reject"
	if JSON.stringify(id["look"]) != face:
		return "reject"
	if id["type"] == "운전면허증" and CT.date_num(id["date"]) < CT.TODAY[day - 1]:
		if day >= 3:
			return "reject"
		_fail("day%d" % day, "3일째 전에 만료 면허증이 나옴")
	if not R.has(id["name"]) or R[id["name"]]["birth"] != id["birth"]:
		return "reject"
	if day >= 6 and R[id["name"]].has("look") and JSON.stringify(R[id["name"]]["look"]) != face:
		return "guard"   # 사진은 본인인데 전산 사진이 다르다: 위조 신분증
	match String(main["kind"]):
		"lease":
			if main["tenant"] != id["name"] or main["tenant_birth"] != id["birth"]:
				return "reject"
			if not String(main["addr"]).begins_with(CT.OUR_DONG):
				return "reject"
			return "process"
		"seal_reg":
			if main["name"] != id["name"] or main["birth"] != id["birth"]:
				return "reject"
			return "process"
		"move":
			if main["name"] != id["name"] or main["birth"] != id["birth"]:
				return "reject"
			if not String(main["new_addr"]).begins_with(CT.OUR_DONG):
				return "reject"
			return "process"
		"death_form":
			if cert.is_empty() or cert["deceased"] != main["deceased"] or cert["deceased_birth"] != main["deceased_birth"]:
				return "reject"
			if main["reporter"] != id["name"]:
				return "reject"
			if not R.has(main["deceased"]) or R[main["deceased"]]["birth"] != main["deceased_birth"]:
				return "reject"
			return "process"
	var subj: String = main["subject"]
	var appl: String = main["applicant"]
	var seal := String(main["title"]).begins_with("인감")
	if appl != id["name"] or not R.has(subj) or R[subj]["birth"] != main["subject_birth"]:
		return "reject"
	if appl != subj and day >= 4 and String(R[subj].get("restrict", "")) != "":
		return "reject"
	if appl != subj:
		var in_house := false
		for m in R[subj]["members"]:
			if m[0] == appl:
				in_house = true
		if seal or not in_house:
			if proxy.is_empty():
				return "reject"
			if proxy["grantor"] != subj or proxy["grantee"] != appl or proxy["grantor_birth"] != R[subj]["birth"]:
				return "reject"
			if seal and proxy["seal"] != "인감":
				return "reject"
			if proxy["seal"] == "없음":
				return "reject"
			if day >= 4 and String(R[subj].get("lost", "")) != "":
				return "guard"
			if day >= 7 and seal and R[subj].get("phone_denies", false):
				return "guard"
	if seal and day >= 3 and not R[subj]["seal"]:
		return "reject"
	return "process"


## 짚을 쌍의 칸이 모두 실제 화면(서류·전산·규정집·얼굴·날짜)에 있는지
func _check_flaw(c: Dictionary, day: int, tag: String) -> void:
	var f: Dictionary = c.get("flaw", {})
	if f.is_empty():
		_fail(tag, "틀린 곳(flaw)이 없음: reason=%s" % c.get("reason", ""))
		return
	if f.get("via", "") == "phone":
		if not c.get("needs_call", false):
			_fail(tag, "전화로만 알 수 있는데 전화 버튼이 없음")
		return
	if f.get("pairs", []).is_empty():
		_fail(tag, "짚을 쌍이 없음: reason=%s" % c.get("reason", ""))
		return
	if not CT.REASONS.has(f["reason"]) or String(f.get("reply", "")) == "":
		_fail(tag, "flaw 사유나 반응이 잘못됨: %s" % f)
	var have := {"face": true, "today": true}
	for d in c.get("docs", []):
		for k in d:
			if not k in ["kind", "type", "title"]:
				have["%s.%s" % [d["kind"], k]] = true
	var R: Dictionary = c.get("records", {})
	for n in c.get("lookup", []):
		if R.has(n):
			for k in ["birth", "addr", "head", "members", "seal"]:
				have["rec:%s.%s" % [n, k]] = true
			for k in ["lost", "restrict"]:
				if String(R[n].get(k, "")) != "":
					have["rec:%s.%s" % [n, k]] = true
			if R[n].has("phone"):
				have["rec:%s.phone" % n] = true
			if R[n].has("look") and day > CT.WEEK_END:
				have["rec:%s.photo" % n] = true
		else:
			have["rec:%s.none" % n] = true
	for r in CT.RULES:
		if r["day"] <= day:
			have["rule:" + r["title"]] = true
	for p in f["pairs"]:
		for fid in p:
			if not have.has(fid):
				_fail(tag, "화면에 없는 칸을 짚어야 함: %s (pairs=%s)" % [fid, f["pairs"]])


func _fail(tag: String, msg: String) -> void:
	fails += 1
	if fails <= 15:
		print("[FAIL] %s: %s" % [tag, msg])
