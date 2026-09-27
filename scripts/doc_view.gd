class_name DocView
extends RefCounted
## 서류와 전산 기록을 종이 카드로 만든다.
## pick이 주어지면 각 칸을 누를 수 있다(지적하기). pick(fid, node, ev) — ev는 "click", "enter", "exit".

const INK := Color("2b2723")
const MUTED := Color("3d352c")
const BOLD: Font = preload("res://assets/fonts/Pretendard-SemiBold.woff2")
const PIXEL: Font = preload("res://assets/fonts/Mulmaru.woff2")
const PAPER := Color("f3eee2")
const RED := Color("c0392b")


static func make(doc: Dictionary, pick := Callable()) -> Control:
	var k: String = doc["kind"]
	match k:
		"id":
			return _id_card(doc, pick)
		"form":
			return _paper(doc["title"], _rows(k, doc, [["subject", "대상자"], ["subject_birth", "대상자 생년월일"],
				["applicant", "신청인"], ["relation", "대상자와의 관계"]], pick), _corrected(doc))
		"move":
			return _paper("전입신고서", _rows(k, doc, [["name", "성명"], ["birth", "생년월일"],
				["old_addr", "이전 주소"], ["new_addr", "새 주소"]], pick), _corrected(doc))
		"lease":
			return _paper("주택 임대차 계약서", _rows(k, doc, [["landlord", "임대인"], ["tenant", "임차인"], ["tenant_birth", "임차인 생년월일"],
				["addr", "임대 주택"], ["deposit", "보증금"], ["date", "계약일"]], pick), _note("임대인과 임차인 도장 날인"), Color("f7f1dc"))
		"seal_reg":
			return _paper("인감 신고서", _rows(k, doc, [["name", "성명"], ["birth", "생년월일"], ["addr", "주소"], ["seal", "신고할 도장"]], pick))
		"proxy":
			return _paper("위임장", _rows(k, doc, [["grantor", "위임하는 사람"], ["grantor_birth", "생년월일"],
				["grantee", "위임받는 사람"], ["purpose", "맡기는 일"]], pick), _wrap(_seal_row(doc["grantor"], doc["seal"]), "proxy.seal", pick))
		"death_form":
			return _paper("사망신고서", _rows(k, doc, [["deceased", "사망자"], ["deceased_birth", "사망자 생년월일"],
				["date", "사망 일자"], ["reporter", "신고인"], ["relation", "사망자와의 관계"]], pick))
		"reissue":
			return _paper("주민등록증 재발급 신청서", _rows(k, doc, [["name", "성명"], ["birth", "생년월일"],
				["addr", "주소"], ["cause", "재발급 사유"]], pick))
		"death_cert":
			return _paper("사망진단서", _rows(k, doc, [["deceased", "사망자"], ["deceased_birth", "생년월일"],
				["date", "사망 일자"], ["place", "발행 기관"]], pick))
		"judgment":
			return _paper("%s (%s)" % [doc["title"], doc["court"]], _rows(k, doc, [["no", "사건 번호"], ["creditor", "채권자"],
				["debtor", "채무자"], ["debtor_birth", "채무자 생년월일"], ["amount", "갚을 돈"]], pick), _note("법원 직인"), Color("eef0f4"))
		"iou":
			return _paper("차용증", _rows(k, doc, [["lender", "빌려준 사람"], ["borrower", "빌린 사람"], ["amount", "금액"], ["date", "쓴 날"]], pick),
				_note("두 사람 도장 날인 (법원 서류 아님)"), Color("fbf6e6"))
		"birth_form":
			return _paper("출생신고서", _rows(k, doc, [["child", "아이 이름"], ["child_birth", "태어난 날"], ["father", "부"],
				["mother", "모"], ["reporter", "신고인"]], pick), _corrected(doc))
		"birth_cert":
			return _paper("출생증명서", _rows(k, doc, [["child_birth", "태어난 날"], ["time", "시각"], ["sex", "성별"],
				["mother", "산모"], ["place", "발행 기관"]], pick))
		"wanted":
			return _wanted(doc, pick)
	var rows: Array = []
	var i := 0
	for r in doc.get("rows", []):
		rows.append(_wrap(_row(r[0], r[1]), "paper.%d" % i, pick))
		i += 1
	return _paper(doc.get("title", "서류"), rows)


## 그 자리에서 고쳐 쓴 신청서에는 정정 표시가 남는다
static func _corrected(doc: Dictionary) -> Control:
	if not doc.get("corrected", false):
		return null
	var l := _label("정정 1곳, 두 줄 긋고 신청인 서명", 14, RED)
	l.add_theme_font_override("font", BOLD)
	return l


static func _note(text: String) -> Control:
	return _label(text, 14, MUTED)


static func record_card(name: String, rec: Variant, pick := Callable(), show_photo := false) -> Control:
	var bg := Color("e6edf2")
	var pre := "rec:%s." % name
	if rec == null:
		return _paper("전산 조회: " + name, [_wrap(_row("결과", "조회되는 주민이 없습니다."), pre + "none", pick)], null, bg)
	var members: Array = rec["members"]
	var others: Array = []
	for m in members.slice(1):
		others.append("%s(%s)" % [m[0], m[1]])
	var rows: Array = [
		_wrap(_row("생년월일", rec["birth"]), pre + "birth", pick),
		_wrap(_row("주소", rec["addr"]), pre + "addr", pick),
		_wrap(_row("세대주", members[0][0]), pre + "head", pick),
		_wrap(_row("세대원", ", ".join(PackedStringArray(others)) if not others.is_empty() else "없음"), pre + "members", pick),
		_wrap(_row("인감 등록", "등록됨" if rec["seal"] else "미등록"), pre + "seal", pick),
	]
	if rec.has("phone"):
		rows.append(_wrap(_row("연락처", rec["phone"]), pre + "phone", pick))
	if String(rec.get("lost", "")) != "":
		rows.append(_wrap(_warn_label("[주의] " + rec["lost"]), pre + "lost", pick))
	if String(rec.get("restrict", "")) != "":
		rows.append(_wrap(_warn_label("[주의] " + rec["restrict"]), pre + "restrict", pick))
	if show_photo and rec.has("look"):
		# 사진은 오른쪽에 둔다 (모니터가 작아서 사진을 한 줄로 두면 기록이 밀려 잘린다)
		var side := HBoxContainer.new()
		side.mouse_filter = Control.MOUSE_FILTER_IGNORE
		side.add_theme_constant_override("separation", 10)
		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 3)
		for r in rows:
			col.add_child(r)
		side.add_child(col)
		var pcol := VBoxContainer.new()
		pcol.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pcol.add_child(_wrap(photo(rec["look"], Vector2(72, 88)), pre + "photo", pick))
		var cap := _label("전산 사진", 14, MUTED)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pcol.add_child(cap)
		side.add_child(pcol)
		rows = [side]
	return _paper("전산 조회: " + name, rows, null, bg)


## 누를 수 있는 칸으로 감싼다. pick이 없으면 그대로 돌려준다.
static func _wrap(inner: Control, fid: String, pick: Callable) -> Control:
	if not pick.is_valid():
		return inner
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	p.set_meta("fid", fid)
	p.mouse_filter = Control.MOUSE_FILTER_PASS   # 아래 종이(Paper)도 눌림을 받아 끌 수 있게
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	p.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			pick.call(fid, p, "click"))
	p.mouse_entered.connect(func(): pick.call(fid, p, "enter"))
	p.mouse_exited.connect(func(): pick.call(fid, p, "exit"))
	p.add_child(inner)
	return p


static func pickable(inner: Control, fid: String, pick: Callable) -> Control:
	return _wrap(inner, fid, pick)


## 처리·반려 도장
static func stamp(text: String) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.12)
	sb.border_color = RED
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", sb)
	var l := _label(text, 36, RED)
	l.add_theme_font_override("font", PIXEL)
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## 이관할 때 책상에 붙이는 쪽지
static func note(text: String) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("f7e27a")
	sb.set_content_margin_all(12)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 4
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(_label(text, 20, INK))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func _rows(kind: String, doc: Dictionary, spec: Array, pick: Callable) -> Array:
	var out: Array = []
	for s in spec:
		out.append(_wrap(_row(s[1], doc[s[0]]), "%s.%s" % [kind, s[0]], pick))
	return out


static func _id_card(doc: Dictionary, pick: Callable) -> Control:
	var license: bool = doc["type"] == "운전면허증"
	var p := _panel(Color("f0e6cc") if license else Color("dde8f0"), Color("9a8b6a") if license else Color("7e97aa"))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var head := _label(doc["type"], 19, Color("6a4b1c") if license else Color("274a66"))
	head.add_theme_font_override("font", BOLD)
	v.add_child(head)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	v.add_child(hb)
	hb.add_child(_wrap(photo(doc["look"], Vector2(86, 106)), "id.look", pick))
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(rows)
	rows.add_child(_wrap(_row("이름", doc["name"], 64), "id.name", pick))
	rows.add_child(_wrap(_row("생년월일", doc["birth"], 64), "id.birth", pick))
	rows.add_child(_wrap(_row("주소", doc["addr"], 64), "id.addr", pick))
	rows.add_child(_wrap(_row("유효기간" if license else "발급일", doc["date"], 64), "id.date", pick))
	return p


## 경찰서 회람: 사진과 수법. 책상 위에 두고 창구 앞 얼굴과 짚어 볼 수 있다.
static func _wanted(doc: Dictionary, pick: Callable) -> Control:
	var p := _panel(Color("fbfaf6"), Color("8a2c24"))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	p.add_child(v)
	var head := _label("경찰 회람: 명의 도용 사기 피의자", 17, RED)
	head.add_theme_font_override("font", BOLD)
	v.add_child(head)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	v.add_child(hb)
	hb.add_child(_wrap(photo(doc["look"], Vector2(76, 94)), "wanted.look", pick))
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(rows)
	rows.add_child(_wrap(_row("이름", doc["name"], 44), "wanted.name", pick))
	rows.add_child(_wrap(_row("나이", doc["age"], 44), "wanted.age", pick))
	rows.add_child(_wrap(_row("수법", doc["how"], 44), "wanted.how", pick))
	v.add_child(_note("보면 신고: " + String(doc["call"])))
	p.custom_minimum_size.x = 300
	return p


## 증명사진. 창구의 얼굴과 같은 픽셀 크기로 보이도록 절반 해상도로 그렸다가 키운다.
static func photo(look: Dictionary, sz: Vector2) -> Control:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.stretch_shrink = 2
	box.custom_minimum_size = sz
	box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.transparent_bg = true
	box.add_child(vp)
	var ph := Portrait.new()
	ph.photo = true
	ph.set_anchors_preset(Control.PRESET_FULL_RECT)
	ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph.set_face(look)
	vp.add_child(ph)
	return box


static func _seal_row(who: String, seal: String) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.alignment = BoxContainer.ALIGNMENT_END
	hb.add_child(_label("위임하는 사람  %s" % who, 15, INK))
	if seal == "없음":
		hb.add_child(_label("(날인 없음)", 16, MUTED))
		return hb
	var st := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = RED
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(24 if seal == "인감" else 3)
	sb.set_content_margin_all(6)
	st.add_theme_stylebox_override("panel", sb)
	st.add_child(_label("인감도장" if seal == "인감" else "일반 도장", 14, RED))
	st.rotation_degrees = -6
	st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(st)
	return hb


static func _paper(title: String, rows: Array, footer: Control = null, bg := PAPER) -> Control:
	var p := _panel(bg, Color("b9ae98"))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	p.add_child(v)
	var t := _label(title, 19, INK)
	t.add_theme_font_override("font", BOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var line := ColorRect.new()
	line.color = Color("b9ae98")
	line.custom_minimum_size = Vector2(0, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(line)
	for r in rows:
		v.add_child(r)
	if footer:
		v.add_child(footer)
	return p


static func _panel(bg: Color, border: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(5)
	sb.set_content_margin_all(12)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(2, 3)
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func _row(key: String, value: String, key_width := 112) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var k := _label(key, 16, MUTED)
	k.custom_minimum_size = Vector2(key_width, 0)
	hb.add_child(k)
	var v := _label(value, 18, INK)
	v.add_theme_font_override("font", BOLD)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hb.add_child(v)
	return hb


static func _warn_label(text: String) -> Label:
	var l := _label(text, 16, RED)
	l.add_theme_font_override("font", BOLD)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## 한글 음절 사이에 줄바꿈 금지 문자(U+2060)를 넣는다. 줄은 띄어쓰기에서만 바뀐다.
static func keep_words(s: String) -> String:
	var out := ""
	for i in s.length():
		out += s[i]
		if i + 1 < s.length() and _hangul(s.unicode_at(i)) and _hangul(s.unicode_at(i + 1)):
			out += char(0x2060)
	return out


static func _hangul(c: int) -> bool:
	return c >= 0xAC00 and c <= 0xD7A3


static func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = keep_words(text)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
