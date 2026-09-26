class_name Paper
extends PanelContainer
## 책상 위 종이 한 장. 끌어서 옮기고, 누르면 맨 위로 오고, 도장 자국을 받는다.
## 오른쪽 클릭은 수정테이프(도장 자국 지우기).

signal pressed(paper: Paper, at: Vector2)
signal released(paper: Paper)
signal erase_requested(paper: Paper)
signal lifted(paper: Paper)   # 끌기 시작: 실제로 움직였을 때만

var doc: Dictionary = {}
var stampable := false
var stamps: Array = []   # "ok" / "no"
var bounds := Rect2()
var _drag := false
var _lifted := false
var _marks: Control


func setup(d: Dictionary, card: Control, can_stamp: bool, area: Rect2) -> void:
	doc = d
	stampable = can_stamp
	bounds = area
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_child(card)
	_marks = Control.new()
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_marks)
	# 컨테이너 밖에 놓인 컨트롤은 저절로 줄어들지 않으므로, 내용이 정해지면 크기를 맞춘다
	minimum_size_changed.connect(reset_size)
	reset_size.call_deferred()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				pressed.emit(self, get_local_mouse_position())
			elif _drag:
				_drag = false
				_lifted = false
				scale = Vector2.ONE
				released.emit(self)
		elif e.button_index == MOUSE_BUTTON_RIGHT and e.pressed and not stamps.is_empty():
			erase_requested.emit(self)
	elif e is InputEventMouseMotion and _drag:
		if not _lifted:
			_lifted = true
			lifted.emit(self)
		position = (position + e.relative).clamp(bounds.position, bounds.end - size)


func start_drag() -> void:
	_drag = true
	move_to_front()
	pivot_offset = size * 0.5
	scale = Vector2(1.03, 1.03)


func dragging() -> bool:
	return _drag


func add_mark(kind: String, text: String, at: Vector2) -> void:
	stamps.append(kind)
	var s := DocView.stamp(text)
	_marks.add_child(s)
	s.size = s.get_combined_minimum_size()
	s.pivot_offset = s.size * 0.5
	s.position = (at - s.size * 0.5).clamp(Vector2.ZERO, (size - s.size).max(Vector2.ZERO))
	s.rotation_degrees = randf_range(-12.0, 6.0)
	s.scale = Vector2(1.8, 1.8)
	s.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(s, "scale", Vector2.ONE, 0.09).set_ease(Tween.EASE_IN)
	tw.tween_property(s, "modulate:a", 0.92, 0.06)


func clear_marks() -> void:
	stamps.clear()
	for m in _marks.get_children():
		m.queue_free()
