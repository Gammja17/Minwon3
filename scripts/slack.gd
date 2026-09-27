class_name Slack
extends Node
## 딴짓: 모니터의 [딴짓] 탭. 수다방, 햇살동 이야기, 지뢰찾기, 햇살증권.
## 딴짓하는 동안 스트레스가 조금씩 내려간다. 최 팀장이 뒤로 지나갈 때
## 1.5초 안에 다른 탭으로 돌리지 않으면 들킨다. 손님 앞에서 하면 손님이 먼저 알아챈다.

const PATROL_EVERY := 35.0   # 평균 몇 초에 한 번 지나가나
const PATROL_WARN := 1.5
const MINE_W := 10
const MINE_H := 5
const MINE_N := 8
const INK := Color("1f2a36")
const DIM := Color("4a5561")
const UP := Color("c0392b")     # 오르면 빨강, 내리면 파랑
const DOWN := Color("2c5aa0")

var o: Node   # 창구 화면(office)
var app := "home"
var patrol := 0.0
var calm_acc := 0.0
var banner: Label
# 지뢰찾기
var mine: Array = []       # true = 지뢰
var shown: Array = []      # 0 닫힘, 1 열림, 2 깃발
var mine_over := ""        # "", "win", "lose"
var mine_cells: Array = []


func setup(office: Node) -> void:
	o = office
	banner = Label.new()
	banner.text = "뒤에서 구두 소리가 다가온다!"
	banner.add_theme_font_override("font", DocView.BOLD)
	banner.add_theme_font_size_override("font_size", 18)
	banner.add_theme_color_override("font_color", Color.WHITE)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("b3261e")
	sb.set_content_margin_all(8)
	banner.add_theme_stylebox_override("normal", sb)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.position = Vector2(26, 250)
	banner.size = Vector2(516, 40)
	banner.visible = false
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o.monitor.add_child(banner)
	_new_mines()


func slacking() -> bool:
	return o.tab == "slack" and not o.ending_started


func _process(delta: float) -> void:
	if not slacking():
		if patrol > 0.0:
			patrol = 0.0
			banner.visible = false
			o._sys("(최 팀장이 뒤를 지나간다. ......휴.)")
		return
	calm_acc += delta
	if calm_acc >= 3.0:
		calm_acc = 0.0
		Game.add_stress(-1)
	if patrol > 0.0:
		patrol -= delta
		banner.modulate.a = 0.6 + 0.4 * sin(Time.get_ticks_msec() / 60.0)
		if patrol <= 0.0:
			_caught()
	elif randf() < delta / PATROL_EVERY:
		patrol = PATROL_WARN
		banner.visible = true
		Sfx.steps(4, "heel", 0.3, -4.0)


func _caught() -> void:
	banner.visible = false
	Game.slack_caught += 1
	Game.apply({"rep": -2, "stress": 6})
	Skeam.unlock("slack_caught")
	o._slip("최 팀장 메모: 근무 시간에 딴짓은 곤란해요. 뒤에서 모니터 다 보여요.", o.SLIP_BAD)
	Sfx.play("warn")
	o._show_lookup()
	o._refresh_top()


# ─────────────────────────── 화면 ───────────────────────────

func build() -> void:
	var body: VBoxContainer = o.screen_body
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	body.add_child(bar)
	for pair in [["home", "바탕 화면"], ["chat", "수다방"], ["board", "햇살동 이야기"], ["mine", "지뢰찾기"], ["stock", "햇살증권"]]:
		var b := Button.new()
		b.text = pair[1]
		b.add_theme_font_size_override("font_size", 13)
		b.modulate = Color(1, 1, 1) if app == pair[0] else Color(0.78, 0.8, 0.84)
		b.pressed.connect(func():
			app = pair[0]
			o._show_slack())
		bar.add_child(b)
	match app:
		"home":
			_home(body)
		"chat":
			_chat(body)
		"board":
			_board(body)
		"mine":
			_mines(body)
		"stock":
			_stocks(body)


func _t(text: String, size := 15, color := INK, bold := false, width := 470) -> Label:
	return o._text(text, size, color, bold, width)


func _home(body: VBoxContainer) -> void:
	body.add_child(_t("몰래 하는 딴짓은 스트레스를 풀어 준다. 대신 최 팀장이 뒤로 지나갈 때 발소리가 들리면 얼른 [전산 조회] 같은 업무 화면으로 돌려야 한다.", 15, DIM))
	body.add_child(_t("스트레스 %d" % Game.stress, 16, INK, true))


# ── 수다방: 오늘의 잡담. 곧 올 사람 얘기가 섞여 있다 ──
func _chat(body: VBoxContainer) -> void:
	var ch: Dictionary = Content.CHATS.get(Game.day, {})
	if ch.is_empty():
		body.add_child(_t("아무도 말이 없다.", 15, DIM))
		return
	for line in ch["lines"]:
		body.add_child(_t("%s  %s" % [ch["who"], line], 15))
	var key := "chat_%d" % Game.day
	if Game.flags.has(key):
		var pick: Array = ch["choices"][int(Game.flags[key])]
		body.add_child(_t("나  " + String(pick[0]), 15, Color("2c5a8a"), true))
		body.add_child(_t("%s  %s" % [ch["who"], pick[1]], 15))
		return
	for i in ch["choices"].size():
		var pick: Array = ch["choices"][i]
		var b := Button.new()
		b.text = "› " + String(pick[0])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(func():
			Game.flags[key] = i
			Game.apply(pick[2])
			if pick[2].has("desk"):
				# 수다방에서 말한 간식을 잠시 뒤 누가 책상에 두고 간다
				get_tree().create_timer(2.5).timeout.connect(o.add_desk_item.bind(String(pick[2]["desk"]),
					"(%s이 책상 귀퉁이에 %s를 두고 간다)" % [ch["who"], Content.DESK_ITEMS[pick[2]["desk"]][0]]))
			Game.pass_time(3)
			Sfx.play("chat", -6.0)
			o._refresh_top()
			o._show_slack())
		body.add_child(b)


# ── 햇살동 이야기: 동네 게시판. 내가 한 일이 올라온다 ──
func _board(body: VBoxContainer) -> void:
	var key := "board_%d" % Game.day
	if not Game.flags.has(key):
		Game.flags[key] = true
		Game.add_stress(-2)
		o._refresh_top()
	for p in Content.board_posts(Game.day, Game.flags):
		body.add_child(_t(p[0], 15, INK, true))
		body.add_child(_t(p[1], 14, DIM))


# ── 지뢰찾기 ──
func _new_mines() -> void:
	mine = []
	shown = []
	mine_over = ""
	for i in MINE_W * MINE_H:
		mine.append(false)
		shown.append(0)
	var placed := 0
	while placed < MINE_N:
		var k := randi() % (MINE_W * MINE_H)
		if not mine[k]:
			mine[k] = true
			placed += 1


func _around(k: int) -> Array:
	var x := k % MINE_W
	var y := k / MINE_W
	var out: Array = []
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var nx: int = x + dx
			var ny: int = y + dy
			if (dx != 0 or dy != 0) and nx >= 0 and ny >= 0 and nx < MINE_W and ny < MINE_H:
				out.append(ny * MINE_W + nx)
	return out


func _count(k: int) -> int:
	var n := 0
	for a in _around(k):
		if mine[a]:
			n += 1
	return n


func open_cell(k: int) -> void:
	if mine_over != "" or shown[k] != 0:
		return
	Sfx.play("tick", -8.0)
	if mine[k]:
		mine_over = "lose"
		Game.add_stress(2)
		Sfx.play("glass", -6.0)
	else:
		var stack := [k]
		while not stack.is_empty():
			var c: int = stack.pop_back()
			if shown[c] != 0 or mine[c]:
				continue
			shown[c] = 1
			if _count(c) == 0:
				stack += _around(c)
		var closed := 0
		for i in shown.size():
			if shown[i] != 1:
				closed += 1
		if closed == MINE_N:
			mine_over = "win"
			Game.add_stress(-8)
			Skeam.unlock("mine_clear")
			Sfx.play("bell", -6.0)
	o._refresh_top()
	o._show_slack()


func _mines(body: VBoxContainer) -> void:
	var head := HBoxContainer.new()
	head.add_child(_t({"": "왼쪽 클릭 열기, 오른쪽 클릭 깃발", "win": "다 찾았다! 스트레스가 확 풀린다.", "lose": "펑! 들킬 뻔했다."}[mine_over], 14, DIM, false, 380))
	var again := Button.new()
	again.text = "새 판"
	again.add_theme_font_size_override("font_size", 13)
	again.pressed.connect(func():
		_new_mines()
		o._show_slack())
	head.add_child(again)
	body.add_child(head)
	var grid := GridContainer.new()
	grid.columns = MINE_W
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	body.add_child(grid)
	for k in MINE_W * MINE_H:
		var b := Button.new()
		b.custom_minimum_size = Vector2(28, 22)
		b.add_theme_font_size_override("font_size", 13)
		b.focus_mode = Control.FOCUS_NONE
		if shown[k] == 1:
			var n := _count(k)
			b.text = str(n) if n > 0 else ""
			b.disabled = true
		elif shown[k] == 2:
			b.text = "▲"
		elif mine_over != "" and mine[k]:
			b.text = "●"
		b.pressed.connect(open_cell.bind(k))
		b.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT and shown[k] != 1 and mine_over == "":
				shown[k] = 2 if shown[k] == 0 else 0
				o._show_slack())
		grid.add_child(b)


# ── 햇살증권: 가상의 동네 주식. 소문을 들으면 먼저 움직일 수 있다 ──
func _stocks(body: VBoxContainer) -> void:
	var value := 0
	for code in Game.stocks:
		value += int(Game.stocks[code]["price"]) * int(Game.stocks[code]["hold"])
	body.add_child(_t("잔고 %s원    주식 평가액 %s원" % [Game.comma(Game.money), Game.comma(value)], 15, INK, true))
	var hint: String = Content.STOCK_HINTS.get(Game.day, "")
	if not Game.stock_news.is_empty():
		body.add_child(_t(String(Game.stock_news[-1]), 14, UP, true))
	elif hint != "":
		body.add_child(_t("지라시: " + hint, 14, DIM))
	for code in Content.STOCK_ORDER:
		var s: Dictionary = Game.stocks[code]
		var price := int(s["price"])
		var pct := (float(price) / float(s["open"]) - 1.0) * 100.0
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var name := _t(Content.STOCKS[code]["name"], 15, INK, true)
		name.custom_minimum_size.x = 92
		row.add_child(name)
		var pl := _t("%s원 %+.1f%%" % [Game.comma(price), pct], 14, UP if pct > 0.05 else (DOWN if pct < -0.05 else DIM))
		pl.custom_minimum_size.x = 132
		row.add_child(pl)
		var hl := _t("%d주" % int(s["hold"]), 14, DIM)
		hl.custom_minimum_size.x = 44
		row.add_child(hl)
		for act in [["1주 사기", 1], ["10주 사기", 10], ["다 팔기", -1]]:
			var b := Button.new()
			b.text = act[0]
			b.add_theme_font_size_override("font_size", 12)
			b.disabled = (act[1] > 0 and Game.money < price * int(act[1])) or (act[1] < 0 and int(s["hold"]) == 0)
			b.pressed.connect(trade.bind(code, act[1]))
			row.add_child(b)
		body.add_child(row)


func trade(code: String, qty: int) -> void:
	var s: Dictionary = Game.stocks[code]
	var price := int(s["price"])
	if qty > 0:
		if not Game.can_spend(price * qty):
			o._sys("(잔고가 모자라다)")
			return
		s["cost"] = (int(s["cost"]) * int(s["hold"]) + price * qty) / (int(s["hold"]) + qty)
		s["hold"] = int(s["hold"]) + qty
		Game.money -= price * qty
		Sfx.play("coin", -6.0)
	else:
		var n := int(s["hold"])
		if n == 0:
			return
		var gain := (price - int(s["cost"])) * n
		Game.money += price * n
		Game.stock_profit += gain
		s["hold"] = 0
		Game.add_stress(-3 if gain > 0 else 3)
		o._sys("(%s %d주를 팔았다. %s %s원)" % [Content.STOCKS[code]["name"], n, "벌었다" if gain >= 0 else "잃었다", Game.comma(absi(gain))])
		if Game.stock_profit >= 100000:
			Skeam.unlock("stock_profit")
		Sfx.play("coin")
	Game.pass_time(1)
	o._refresh_top()
	o._show_slack()
