extends Node
## 효과음 (Kenney CC0). 이름으로 부르면 같은 종류 중 하나를 골라 재생한다.

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
}

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for key in SOUNDS:
		_streams[key] = SOUNDS[key].map(func(f): return load("res://assets/sfx/" + f))
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func play(key: String, volume_db := 0.0) -> void:
	if not _streams.has(key):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[key].pick_random()
	p.volume_db = volume_db
	p.pitch_scale = randf_range(0.95, 1.05)
	p.play()
