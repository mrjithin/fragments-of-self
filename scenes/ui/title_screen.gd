extends Control
## Entry point. Starts a fresh run and hands off to the External World.

const BOARD_SCENE: String = "res://scenes/external/task_board.tscn"

@onready var _new_game: Button = %NewGameButton
@onready var _quit: Button = %QuitButton


func _ready() -> void:
	_new_game.pressed.connect(_on_new_game)
	_quit.pressed.connect(_on_quit)
	if SaveManager.has_save():
		_add_continue_button()
	_add_content_note()


## A short, respectful framing note — important for the subject matter and for anyone
## meeting the game cold.
func _add_content_note() -> void:
	var note := Label.new()
	note.text = "An empathetic portrayal of Dissociative Identity Disorder — a real condition rooted in childhood trauma. A story of coping and care, not horror. Gentle themes of stress and the past throughout."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.custom_minimum_size = Vector2(440, 0)
	note.add_theme_font_size_override("font_size", 12)
	note.modulate = Color(1, 1, 1, 0.6)
	var menu: Node = _new_game.get_parent()
	menu.add_child(note)


## Inserts a Continue button above New Game when a save exists, matching its style.
func _add_continue_button() -> void:
	var cont := Button.new()
	cont.text = "Continue"
	cont.custom_minimum_size = Vector2(0, 44)
	var menu: Node = _new_game.get_parent()
	menu.add_child(cont)
	menu.move_child(cont, _new_game.get_index())
	cont.pressed.connect(_on_continue)


func _on_new_game() -> void:
	GameState.reset_run()
	GameClock.reset_day()
	SceneFlow.change_scene_to_file(BOARD_SCENE)


func _on_continue() -> void:
	if not SaveManager.load():
		return
	var target: String = GameState.current_scene
	if target == "":
		target = BOARD_SCENE
	SceneFlow.change_scene_to_file(target)


func _on_quit() -> void:
	get_tree().quit()
