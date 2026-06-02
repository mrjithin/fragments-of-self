extends CanvasLayer
## Global pause + settings overlay, available in every scene (Esc to toggle).
## Pauses the tree and offers Resume, a working Sound toggle (wires the otherwise
## unused Music.set_muted), Return to Title, and Quit. Built in code so it needs no
## scene file and lives above gameplay on its own canvas layer.

const TITLE_SCENE: String = "res://scenes/ui/title_screen.tscn"

var _root: Control
var _sound_btn: Button
var _muted: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep working while the tree is paused
	layer = 80
	_build()
	_set_open(false)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.16, 0.12, 0.10, 0.78)   # warm dark, matches the fade
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(320, 0)
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	box.add_child(_make_button("Resume", _on_resume))
	_sound_btn = _make_button("Sound: On", _on_toggle_sound)
	box.add_child(_sound_btn)
	box.add_child(_make_button("Return to Title", _on_title))
	box.add_child(_make_button("Quit", _on_quit))


func _make_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 42)
	b.pressed.connect(cb)
	return b


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	_set_open(not _root.visible)


func _set_open(open: bool) -> void:
	_root.visible = open
	get_tree().paused = open


func _on_resume() -> void:
	_set_open(false)


func _on_toggle_sound() -> void:
	_muted = not _muted
	Music.set_muted(_muted)
	_sound_btn.text = "Sound: Off" if _muted else "Sound: On"


func _on_title() -> void:
	_set_open(false)
	GameState.reset_run()
	GameClock.reset_day()
	SceneFlow.change_scene_to_file(TITLE_SCENE)


func _on_quit() -> void:
	get_tree().quit()
