extends Node
## Headless reproduction of the title-screen "Continue" (resume save) path.
## Plays into the external world (which autosaves), simulates a fresh app boot
## (in-memory reset, save file left on disk), then runs exactly what
## title_screen._on_continue does and instantiates the resumed scene.
## Run: godot --headless res://tools/sim_continue.tscn

const BOARD: String = "res://scenes/external/task_board.tscn"
const EXTERNAL: String = "res://scenes/external/external_world.tscn"

var _fail: int = 0


func _check(label: String, ok: bool) -> void:
	print(("PASS: " if ok else "FAIL: "), label)
	if not ok:
		_fail += 1


func _ready() -> void:
	print("=== sim_continue: title Continue (resume) ===")

	# --- Phase 1: enter a task, spend time, let the scene autosave ---
	GameState.reset_run()
	GameClock.reset_day()
	GameState.current_situation = "res://data/external_situation.json"
	GameState.set_flag("day_setup_done")
	GameClock.spend(40)                                  # 60 of 100 left
	GameState.add_alignment(2)

	var ext: Node = load(EXTERNAL).instantiate()
	add_child(ext)
	await get_tree().process_frame
	_check("autosave anchors resume to the task board (not mid-situation)",
		GameState.current_scene == BOARD)
	ext.queue_free()
	await get_tree().process_frame

	# --- Phase 2: simulate a fresh boot: memory cleared, file on disk intact ---
	GameState.reset_run()
	GameClock.reset_day()                                # fresh clock = 100
	_check("a save exists for Continue to offer", SaveManager.has_save())

	# --- Phase 3: exactly what title_screen._on_continue() does ---
	if not SaveManager.load():
		_check("load() succeeds", false)
		_done()
		return
	var target: String = GameState.current_scene
	if target == "":
		target = BOARD
	_check("resume target is the task board", target == BOARD)
	_check("alignment restored (2)", GameState.ending_alignment == 2)
	# Spent 40 entering, then the first narration beat drains READ_STEP (4) on _ready
	# before the autosave — so the restored budget is 56, not a reset-to-100.
	_check("time budget restored (56, was the bug: reset to 100)",
		GameClock.budget_remaining == 56)

	# --- Phase 4: instantiate the resumed scene to catch _ready errors ---
	var inst: Node = load(target).instantiate()
	add_child(inst)
	await get_tree().process_frame
	_check("resumed scene builds without crashing", is_instance_valid(inst))
	_done()


func _done() -> void:
	print("=== sim_continue done, failures: %d ===" % _fail)
	await get_tree().process_frame
	get_tree().quit()
