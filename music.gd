extends Node
## 全局背景音乐：双播放器交叉淡入淡出，切场景时不会硬切。
##
## 曲目由 tools/make_music.py 离线合成，循环点在渲染时就已咬合。
## 按 M 可以静音 / 恢复背景音乐（不影响音效）。

const FADE := 0.9
const BUS := "Music"

## 曲目名 -> [资源路径, 循环时使用的音量(dB)]
const TRACKS := {
	"market": ["res://music/market.ogg", -16.0],
	"cooking": ["res://music/cooking.ogg", -13.0],
	"night": ["res://music/night.ogg", -16.0],
	"school": ["res://music/school.ogg", -14.0],
	"battle": ["res://music/battle.ogg", -11.0],
	"classroom": ["res://music/classroom.ogg", -15.0],
}

var current := ""
var muted := false

var _players: Array[AudioStreamPlayer] = []
var _index := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bus_index := _ensure_bus()
	for _i in range(2):
		var player := AudioStreamPlayer.new()
		player.bus = BUS if bus_index >= 0 else "Master"
		player.volume_db = -80.0
		add_child(player)
		_players.append(player)


func _ensure_bus() -> int:
	var index := AudioServer.get_bus_index(BUS)
	if index >= 0:
		return index
	AudioServer.add_bus()
	index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, BUS)
	AudioServer.set_bus_send(index, "Master")
	return index


## 无头 / CI 环境下 Godot 用 Dummy 驱动，此时不必真正播放。
func _can_play() -> bool:
	return AudioServer.get_driver_name() != "Dummy"


func play(track: String) -> void:
	if track == current or not TRACKS.has(track):
		return
	var path: String = TRACKS[track][0]
	if not ResourceLoader.exists(path):
		push_warning("Music: 找不到曲目文件 %s" % path)
		return
	var stream := load(path) as AudioStream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	current = track
	_index = 1 - _index
	var incoming := _players[_index]
	var outgoing := _players[1 - _index]
	var target: float = TRACKS[track][1]
	incoming.stream = stream
	incoming.volume_db = -80.0
	if _can_play():
		incoming.play()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(incoming, "volume_db", target, FADE)
	if outgoing.playing:
		tween.tween_property(outgoing, "volume_db", -60.0, FADE)
		var timer := get_tree().create_timer(FADE + 0.05)
		timer.timeout.connect(func() -> void:
			if outgoing != _players[_index] and outgoing.playing:
				outgoing.stop()
		)


func stop(fade: float = FADE) -> void:
	current = ""
	for player in _players:
		if not player.playing:
			continue
		var tween := create_tween()
		tween.tween_property(player, "volume_db", -60.0, fade)
		tween.tween_callback(player.stop)


func toggle_mute() -> void:
	muted = not muted
	var index := AudioServer.get_bus_index(BUS)
	if index >= 0:
		AudioServer.set_bus_mute(index, muted)
	else:
		for player in _players:
			player.stream_paused = muted


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_M:
			toggle_mute()
