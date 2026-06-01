class_name DialogueBox
extends Control
## Shared dialogue presenter. Used by both the external situation and the internal
## conflict dialogue. Typewriter reveal + click-to-advance + choice buttons.

signal advance_requested
signal choice_selected(index: int)

const TYPE_CHARS_PER_SEC: float = 45.0

@onready var _speaker: Label = %SpeakerLabel
@onready var _body: RichTextLabel = %BodyLabel
@onready var _choices: VBoxContainer = %ChoiceList
@onready var _hint: Label = %ContinueHint

var _typing: bool = false
var _current: DialogueNode
var _type_tween: Tween


func _ready() -> void:
	_clear_choices()
	_hint.visible = false


func show_node(node: DialogueNode) -> void:
	_current = node
	visible = true
	_clear_choices()
	_hint.visible = false
	_speaker.text = node.speaker
	_speaker.visible = node.speaker != ""
	_body.text = node.text
	_start_typewriter()


func _start_typewriter() -> void:
	_typing = true
	_body.visible_ratio = 0.0
	if _type_tween and _type_tween.is_running():
		_type_tween.kill()
	var char_count: int = maxi(1, _body.get_total_character_count())
	var duration: float = float(char_count) / TYPE_CHARS_PER_SEC
	_type_tween = create_tween()
	_type_tween.tween_property(_body, "visible_ratio", 1.0, duration)
	_type_tween.finished.connect(_reveal_done)


func _reveal_done() -> void:
	_typing = false
	if _current.has_choices():
		_build_choices()
	else:
		_hint.visible = true


func _build_choices() -> void:
	for i in _current.choices.size():
		var choice: Dictionary = _current.choices[i]
		var btn := Button.new()
		btn.text = choice.get("text", "…")
		btn.focus_mode = Control.FOCUS_NONE
		var idx: int = i
		btn.pressed.connect(func() -> void: choice_selected.emit(idx))
		_choices.add_child(btn)
	_choices.visible = true


func _clear_choices() -> void:
	for child in _choices.get_children():
		child.queue_free()
	_choices.visible = false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_click()


func _on_click() -> void:
	if _current == null:
		return
	if _typing:
		# First click skips the typewriter to the full line.
		if _type_tween and _type_tween.is_running():
			_type_tween.kill()
		_body.visible_ratio = 1.0
		_reveal_done()
		return
	if not _current.has_choices():
		advance_requested.emit()
