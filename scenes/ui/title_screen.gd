extends Control
## Entry point. Starts a fresh run and hands off to the External World.

const EXTERNAL_SCENE: String = "res://scenes/external/external_world.tscn"

@onready var _new_game: Button = %NewGameButton
@onready var _quit: Button = %QuitButton


func _ready() -> void:
	_new_game.pressed.connect(_on_new_game)
	_quit.pressed.connect(_on_quit)


func _on_new_game() -> void:
	GameState.reset_run()
	GameClock.reset_day()
	SceneFlow.change_scene_to_file(EXTERNAL_SCENE)


func _on_quit() -> void:
	get_tree().quit()
