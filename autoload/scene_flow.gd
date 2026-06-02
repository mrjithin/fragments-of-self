extends Node
## Owns scene transitions and the full-screen fade overlay. The single source of
## pitch-grade smoothness between views. In-scene element fades use their own Tweens.

@onready var _fade: ColorRect = $Overlay/Fade

const DEFAULT_FADE: float = 0.45


func _ready() -> void:
	_fade.color = Color("2a1f1a")   # warm dark, not pure black
	_fade.modulate.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Fade out, swap to the packed scene, fade back in.
func change_scene(target: PackedScene, fade_time: float = DEFAULT_FADE) -> void:
	await _fade_to(1.0, fade_time)
	get_tree().change_scene_to_packed(target)
	# Wait one frame so the new scene is in the tree before fading in.
	await get_tree().process_frame
	await _fade_to(0.0, fade_time)


func change_scene_to_file(path: String, fade_time: float = DEFAULT_FADE) -> void:
	var packed: PackedScene = load(path)
	if packed == null:
		push_error("SceneFlow: could not load scene %s" % path)
		return
	EventBus.scene_changed.emit(path)   # let Music swap ambience under the fade
	await change_scene(packed, fade_time)


func _fade_to(alpha: float, fade_time: float) -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP if alpha > 0.0 else Control.MOUSE_FILTER_IGNORE
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", alpha, fade_time).set_trans(Tween.TRANS_SINE)
	await tween.finished
	if alpha == 0.0:
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
