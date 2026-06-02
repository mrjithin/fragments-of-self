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
