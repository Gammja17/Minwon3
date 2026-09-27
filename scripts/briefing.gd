extends Control
## 아침마다 팀장이 남기는 업무 메모. 왼쪽에 오늘의 핵심, 오른쪽에 메모 본문과 새 규정 카드.

const INK := Color("2b2723")
const KEY_COLOR := "#8a3b12"
const TERM_COLOR := "#2c5a8a"
## 메모 속에서 굵게 짚어 줄 말
const KEYWORDS := ["위임장", "세대원", "인감도장", "유효기간", "청원경찰", "전산 사진", "확정일자", "지문 스캐너",
	"전산 장애", "확인 전화", "사망진단서", "교부 제한", "위조 신분증", "같은 날"]


func _ready() -> void:
	%Paper.add_theme_stylebox_override("panel", _box(Color("f3eee2"), Color("f3eee2"), 28))
	%Keys.add_theme_stylebox_override("panel", _box(Color("fff4c7"), Color("e0c56a"), 14))
	%News.add_theme_stylebox_override("panel", _box(Color("a8322a"), Color("a8322a"), 14))
	%Header.text = Content.DATES[Game.day - 1]
	%Face.texture = Portrait.texture_for("choi", "happy" if Game.day in [1, 5, 10] else "normal")
	var text := Game.memo_for_today()
	# 급한 소식은 빨간 상자로 따로
	var news := ""
	for n in [Content.STALKER_NEWS, Content.SCAM_NEWS]:
		if text.begins_with(n):
			news += n
			text = text.substr(n.length())
	if news != "":
		%News.visible = true
		%NewsText.text = DocView.keep_words("급한 소식\n" + news.strip_edges())
		%Face.texture = Portrait.texture_for("choi", "sad")
	%Memo.text = DocView.keep_words(_emphasize(text))
	_build_keys()
	_build_rules()
	Game.save_game()
	%StartBtn.pressed.connect(func():
		Game.start_day()
		get_tree().change_scene_to_file("res://scenes/office.tscn"))


func _box(bg: Color, border: Color, margin: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2 if border != bg else 0)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(margin)
	return sb


## [버튼 이름]은 파란 굵은 글씨, 중요한 말은 붉은 굵은 글씨
func _emphasize(t: String) -> String:
	var re := RegEx.create_from_string("\\[([가-힣 ]+)\\]")
	t = re.sub(t, "[b][color=%s][lb]$1[rb][/color][/b]" % TERM_COLOR, true)
	for kw in KEYWORDS:
		t = t.replace(kw, "[b][color=%s]%s[/color][/b]" % [KEY_COLOR, kw])
	return t


## 왼쪽: 오늘의 핵심 서너 줄
func _build_keys() -> void:
	%KeyList.add_child(_label("오늘의 핵심", 18, Color(KEY_COLOR), true))
	for k in Content.MEMO_KEYS.get(Game.day, []):
		%KeyList.add_child(_label("■ " + String(k), 16, INK, false))


## 오른쪽 아래: 오늘부터 바뀌는 규정 카드
func _build_rules() -> void:
	var rules := Game.new_rules_today()
	if Game.day <= 1 or rules.is_empty():
		return
	%Rules.add_child(_label("오늘부터 바뀌는 규정", 17, Color(KEY_COLOR), true))
	for r in rules:
		var card := PanelContainer.new()
		var sb := _box(Color("fffaf0"), Color("d9c7a3"), 12)
		sb.border_width_left = 6
		sb.border_color = Color(KEY_COLOR)
		card.add_theme_stylebox_override("panel", sb)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		v.add_child(_label(r["title"], 17, INK, true))
		v.add_child(_label(r["text"], 16, Color("4a4238"), false))
		card.add_child(v)
		%Rules.add_child(card)


func _label(text: String, size: int, color: Color, bold: bool) -> Label:
	var l := Label.new()
	l.text = DocView.keep_words(text)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", DocView.BOLD)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
