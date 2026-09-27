extends Node
## 효과음 (Kenney CC0). 이름으로 부르면 같은 종류 중 하나를 골라 재생한다.
## 화면의 모든 버튼은 누를 때 딸깍 소리가 난다.

const SOUNDS := {
	"call": ["call.ogg"],
	"stamp": ["stamp1.ogg", "stamp2.ogg"],
	"paper": ["paper1.ogg", "paper2.ogg", "paper3.ogg"],
	"leave": ["cloth1.ogg", "cloth2.ogg"],
	"glass": ["glass1.ogg", "glass2.ogg"],
	"coin": ["coin.ogg"],
	"warn": ["warn.ogg"],
	"bell": ["bell.ogg"],
	"phone": ["phone.ogg"],
	"door": ["door1.ogg", "door2.ogg"],
	"step": ["step0.ogg", "step1.ogg", "step2.ogg", "step3.ogg"],
	"heel": ["heel0.ogg", "heel1.ogg", "heel2.ogg"],
	"click": ["click1.ogg", "click2.ogg"],
	"pop": ["pop.ogg"],
	"notify": ["notify.ogg"],
	"hint": ["hint.ogg"],
	"ff_on": ["ff_on.ogg"],
	"ff_off": ["ff_off.ogg"],
	"tick": ["tick.ogg"],
	"alarm": ["alarm.ogg"],
	"book_open": ["book_open.ogg"],
	"book_close": ["book_close.ogg"],
	"bottle": ["bottle.ogg"],
	"chat": ["chat.ogg"],
}

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for key in SOUNDS:
		_streams[key] = SOUNDS[key].map(func(f): return load("res://assets/sfx/" + f))
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(n: Node) -> void:
	if n is BaseButton:
		n.pressed.connect(play.bind("click", -14.0))


func play(key: String, volume_db := 0.0) -> void:
	if not _streams.has(key):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[key].pick_random()
	p.volume_db = volume_db
	p.pitch_scale = randf_range(0.95, 1.05)
	p.play()


## 발소리 여러 번 (다가오거나 멀어질 때)
func steps(count: int, key := "step", gap := 0.22, volume_db := -10.0) -> void:
	for i in count:
		get_tree().create_timer(gap * i).timeout.connect(play.bind(key, volume_db))
