extends Node
## 효과음 (Kenney CC0 등)과 배경 음악. 이름으로 부르면 같은 종류 중 하나를 골라 재생한다.
## 화면의 모든 버튼은 누를 때 딸깍 소리가 난다.
## 웹에서 탭을 숨기면 소리와 게임을 멈춘다 (휴대폰 배터리).

const SOUNDS := {
	"call": ["dingdong.ogg"],
	"stamp": ["stamp1.ogg", "stamp2.ogg"],
	"paper": ["paper1.ogg", "paper2.ogg", "paper3.ogg"],
	"leave": ["cloth1.ogg", "cloth2.ogg"],
	"glass": ["glass1.ogg", "glass2.ogg"],
	"coin": ["coin.ogg"],
	"warn": ["warn.ogg"],
	"bell": ["bell.ogg"],
	"phone": ["phone.ogg"],
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

const MUSIC := "res://assets/music/bgm.ogg"

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _fps := 30
var _vis_cb: JavaScriptObject


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music = AudioStreamPlayer.new()
	_music.volume_db = -80.0
	add_child(_music)
	if OS.has_feature("web"):
		_vis_cb = JavaScriptBridge.create_callback(_on_visibility_change)
		JavaScriptBridge.get_interface("document").addEventListener("visibilitychange", _vis_cb)
	for key in SOUNDS:
		_streams[key] = SOUNDS[key].map(func(f): return load("res://assets/sfx/" + f))
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	get_tree().node_added.connect(_on_node_added)


## 화면이 바뀔 때: 음악 크기와 초당 그리는 장수 (민원실만 60, 나머지 화면은 30)
func enter(office: bool) -> void:
	_fps = 60 if office else 30
	Engine.max_fps = _fps
	if _music.stream == null and ResourceLoader.exists(MUSIC):
		var st: AudioStreamOggVorbis = load(MUSIC)
		st.loop = true
		_music.stream = st
	if _music.stream == null:
		return
	if not _music.playing:
		_music.play()
	# 민원실에서는 손님 말이 묻히지 않게 더 작게
	create_tween().tween_property(_music, "volume_db", -24.0 if office else -17.0, 1.2)


func _on_visibility_change(_args: Array) -> void:
	var hidden := bool(JavaScriptBridge.eval("document.hidden", true))
	get_tree().paused = hidden
	AudioServer.set_bus_mute(0, hidden)
	Engine.max_fps = 5 if hidden else _fps


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
