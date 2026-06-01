extends Node
## Persistent ambient music. Lives in an autoload so the track plays continuously and
## does NOT restart on scene transitions. Soothing, low, always-on for the demo.

const TRACK: AudioStream = preload("res://assets/audio/ambient_piano.ogg")
const VOLUME_DB: float = -14.0

var _player: AudioStreamPlayer


func _ready() -> void:
	# Loop the stream if the format supports it (Ogg/MP3 expose a `loop` property).
	if "loop" in TRACK:
		TRACK.set("loop", true)
	_player = AudioStreamPlayer.new()
	_player.stream = TRACK
	_player.volume_db = VOLUME_DB
	_player.autoplay = false
	add_child(_player)
	# Fallback restart in case the stream doesn't loop natively.
	_player.finished.connect(func() -> void: _player.play())
	_player.play()


func set_muted(muted: bool) -> void:
	_player.stream_paused = muted
