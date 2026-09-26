class_name Portrait
extends Control
## 민원인 얼굴을 도형으로 그린다. 신분증 사진(photo)도 같은 그림을 쓴다.

const SKINS := [Color("f5d7bd"), Color("e9c09c"), Color("d2a07a"), Color("a97a57")]
const HAIRS := [Color("1d1b1b"), Color("3a2a20"), Color("6a4128"), Color("8d8a86"), Color("dcdad6"), Color("5a2320")]
const SHIRTS := [Color("4a6fa5"), Color("6f8a52"), Color("a5574a"), Color("4d4f5e"), Color("c9a24a"), Color("7d62a0"), Color("3f7f7a"), Color("2f3542")]
const LINE := Color("2a211c")
const PORTRAIT_DIR := "res://assets/portraits/"

static var _textures := {}

@export var photo := false
var look: Dictionary = {}
var mood := "normal"
var frame := Color(0, 0, 0, 0)   # 지적하기에서 고른 표시


func _init() -> void:
	clip_contents = true


## 이야기 인물은 그림 파일이 있다 (assets/portraits/<이름>_<기분>.png). 없으면 null.
static func texture_for(img: String, mood: String) -> Texture2D:
	var key := "%s_%s" % [img, mood]
	if not _textures.has(key):
		var path := PORTRAIT_DIR + key + ".png"
		_textures[key] = load(path) if ResourceLoader.exists(path) else null
	return _textures[key]


func set_face(l: Dictionary, m := "normal") -> void:
	look = l
	mood = m
	queue_redraw()


func _draw() -> void:
	if look.is_empty():
		return
	var w := size.x
	var h := size.y
	if photo:
		draw_rect(Rect2(Vector2.ZERO, size), Color("c9d6e2"))
	var m := "normal" if photo else mood
	if look.has("img"):
		var tex := texture_for(look["img"], m)
		if tex == null:
			tex = texture_for(look["img"], "normal")
		if tex:
			var side := minf(w, h * 1.1)
			draw_texture_rect(tex, Rect2((w - side) * 0.5, h - side, side, side), false)
			_draw_frame()
			return
	var u := minf(w, h) / 10.0
	var cx := w * 0.5
	var shape: int = look.get("shape", 0)
	var rx: float = u * [2.3, 2.1, 2.5][shape]
	var ry: float = u * [2.8, 3.05, 2.7][shape]
	var hc := Vector2(cx, h * 0.42)
	var skin: Color = SKINS[int(look.get("skin", 0)) % SKINS.size()]
	if m == "angry":
		skin = skin.lerp(Color("e0604a"), 0.16)
	var hair: Color = HAIRS[int(look.get("hair", 0)) % HAIRS.size()]
	var shirt: Color = SHIRTS[int(look.get("shirt", 0)) % SHIRTS.size()]
	var style: int = look.get("style", 0)
	var age: int = look.get("age", 0)

	if style == 2:
		_ellipse(hc + Vector2(0, ry * 0.45), rx * 1.28, ry * 1.12, hair)
	_ellipse(Vector2(cx, h + u * 1.4), u * 4.6, u * 3.6, shirt)
	draw_colored_polygon(PackedVector2Array([Vector2(cx - u * 0.9, h - u * 2.1), Vector2(cx + u * 0.9, h - u * 2.1), Vector2(cx, h - u * 0.9)]), skin.darkened(0.06))
	draw_rect(Rect2(cx - u * 0.8, hc.y + ry * 0.55, u * 1.6, h - u * 2.1 - hc.y - ry * 0.55), skin.darkened(0.08))
	_ellipse(hc + Vector2(-rx, u * 0.25), u * 0.45, u * 0.7, skin.darkened(0.05))
	_ellipse(hc + Vector2(rx, u * 0.25), u * 0.45, u * 0.7, skin.darkened(0.05))
	_ellipse(hc, rx, ry, skin)
	_hair(hc, rx, ry, style, hair, u)

	# 눈썹과 눈
	var ey := hc.y + ry * 0.02
	var brow := hair.darkened(0.35) if age < 2 else Color("6d6a66")
	for s in [-1.0, 1.0]:
		var ex: float = cx + s * rx * 0.42
		var inner := 0.0
		if m == "angry":
			inner = u * 0.35
		elif m == "sad":
			inner = -u * 0.3
		draw_line(Vector2(ex + s * rx * 0.28, ey - u * 0.8), Vector2(ex - s * rx * 0.22, ey - u * 0.8 + inner), brow, u * 0.24)
		if m == "happy":
			draw_arc(Vector2(ex, ey + u * 0.1), u * 0.3, PI, TAU, 8, LINE, u * 0.16)
		else:
			_ellipse(Vector2(ex, ey), u * 0.2, u * 0.26, LINE)
		if age >= 2:
			draw_line(Vector2(ex - u * 0.3, ey + u * 0.45), Vector2(ex + u * 0.3, ey + u * 0.5), skin.darkened(0.2), u * 0.08)
	if look.get("flush", false):
		_ellipse(Vector2(cx - rx * 0.55, hc.y + ry * 0.3), u * 0.5, u * 0.3, Color(0.9, 0.35, 0.3, 0.55))
		_ellipse(Vector2(cx + rx * 0.55, hc.y + ry * 0.3), u * 0.5, u * 0.3, Color(0.9, 0.35, 0.3, 0.55))
	if look.get("glasses", false):
		for s in [-1.0, 1.0]:
			draw_arc(Vector2(cx + s * rx * 0.42, ey), u * 0.62, 0, TAU, 20, LINE, u * 0.13)
		draw_line(Vector2(cx - rx * 0.42 + u * 0.62, ey), Vector2(cx + rx * 0.42 - u * 0.62, ey), LINE, u * 0.12)
	# 코
	draw_line(Vector2(cx, hc.y + ry * 0.18), Vector2(cx - u * 0.2, hc.y + ry * 0.36), skin.darkened(0.22), u * 0.12)
	# 입
	var my := hc.y + ry * 0.58
	var mw := rx * 0.42
	var curve := u * 0.1
	match m:
		"happy":
			curve = u * 0.5
		"angry":
			curve = -u * 0.3
			mw = rx * 0.34
		"sad":
			curve = -u * 0.35
	var pts := PackedVector2Array()
	for i in 9:
		var t := -1.0 + i / 4.0
		pts.append(Vector2(cx + t * mw, my + curve * (1.0 - t * t)))
	draw_polyline(pts, Color("7a3b30"), u * 0.16)
	if age >= 1:
		draw_line(Vector2(cx - rx * 0.45, hc.y + ry * 0.3), Vector2(cx - rx * 0.55, hc.y + ry * 0.55), skin.darkened(0.12), u * 0.08)
		draw_line(Vector2(cx + rx * 0.45, hc.y + ry * 0.3), Vector2(cx + rx * 0.55, hc.y + ry * 0.55), skin.darkened(0.12), u * 0.08)
	_draw_frame()


func _draw_frame() -> void:
	if frame.a > 0.0:
		draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), frame, false, 3.0)


func _hair(c: Vector2, rx: float, ry: float, style: int, col: Color, u: float) -> void:
	var pts := PackedVector2Array()
	var hx := rx * 1.08
	var hy := ry * 1.07
	var fringe := c.y - ry * 0.42
	if style == 3:
		fringe = c.y - ry * 0.8
	for i in 25:
		var a := lerpf(PI * 0.94, PI * 2.06, i / 24.0)
		pts.append(c + Vector2(cos(a) * hx, sin(a) * hy))
	# 앞머리 선. 머리 윤곽 안쪽에 머물러야 다각형이 꼬이지 않는다.
	for i in 13:
		var t := i / 12.0
		var x := lerpf(rx, -rx, t)
		var y := fringe
		match style:
			1:
				y = fringe + (x / rx) * ry * 0.14
			2:
				y = fringe + absf(x / rx) * ry * 0.22 - ry * 0.06
			4:
				y = fringe - ry * 0.05
		var dy := clampf((y - c.y) / hy, -1.0, 1.0)
		var lim := hx * sqrt(1.0 - dy * dy) * 0.95
		pts.append(Vector2(c.x + clampf(x, -lim, lim), y))
	draw_colored_polygon(pts, col)
	if style == 4:
		for i in 9:
			var a := lerpf(PI * 1.0, PI * 2.0, i / 8.0)
			_ellipse(c + Vector2(cos(a) * rx * 1.08, sin(a) * ry * 1.02), u * 0.55, u * 0.55, col)


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)
