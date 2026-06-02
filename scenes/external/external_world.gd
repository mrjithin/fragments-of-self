extends Node2D
## The External World view: presents the day's situation as dialogue. At the decision
## point the player "looks inward" (the handoff to the Internal Mind). On return, the
## chosen alter's outcome branch plays, firing the memory + DID-fact beats.

const SITUATION_PATH: String = "res://data/external_situation.json"
const TASKS_PATH: String = "res://data/tasks.json"
const INTERNAL_SCENE: String = "res://scenes/internal/internal_mind.tscn"
const TASK_BOARD_SCENE: String = "res://scenes/external/task_board.tscn"

@onready var _box: DialogueBox = %DialogueBox

var _runner: DialogueRunner
var _situation: Dictionary = {}
var _task: Task


func _ready() -> void:
	# Play the situation the player chose on the task board (fallback to the default).
	var sit_path: String = GameState.current_situation if GameState.current_situation != "" else SITUATION_PATH
	_situation = JsonLoader.load_dict(sit_path)
	_task = _load_task(_situation.get("task_id", ""))

	_runner = DialogueRunner.new()
	add_child(_runner)
	_runner.setup(_situation, _box)
	_runner.action_triggered.connect(_on_action)
	_runner.finished.connect(_on_finished)

	if GameState.assigned_alter_id != "" and not GameState.has_flag("outcome_played"):
		_play_outcome()
	else:
		EventBus.objective_changed.emit("Read what's happening, then look inward.")
		_runner.start(_situation.get("start", ""))

	# Autosave on entering this view so the run can be resumed from the title.
	# Anchor the resume point to the day's task board (the durable hub) rather than
	# this transient mid-task view — resuming there keeps completed tasks, alter
	# stress, bonds, alignment and time intact without replaying a half-finished
	# situation or rebuilding a mid-flight mind→world handoff.
	GameState.current_scene = TASK_BOARD_SCENE
	SaveManager.save()


func _load_task(task_id: String) -> Task:
	if task_id == "":
		return null
	var data := JsonLoader.load_dict(TASKS_PATH)
	var tasks: Dictionary = data.get("tasks", {})
	if not tasks.has(task_id):
		return null
	return Task.from_dict(task_id, tasks[task_id])


func _on_action(action: String) -> void:
	if action == "enter_mind":
		GameState.current_task_id = _task.id if _task else ""
		EventBus.objective_changed.emit("")
		EventBus.enter_mind_requested.emit(GameState.current_task_id)
		SceneFlow.change_scene_to_file(INTERNAL_SCENE)


## Resume the situation on the branch matching the alter chosen in the mind.
func _play_outcome() -> void:
	GameState.set_flag("outcome_played")
	var assigned: String = GameState.assigned_alter_id
	var outcome: Dictionary = _task.outcome_for(assigned) if _task else {}
	var branch: String = outcome.get("branch", _situation.get("start", ""))
	if _task:
		GameClock.spend(_task.time_cost)
	# Relationship-affects-outcome: sending an alter who still has a strained or
	# broken bond costs alignment (you skipped mending it in the mind).
	var rel_mgr := RelationshipManager.new()
	rel_mgr.load_data()
	var penalty: int = rel_mgr.penalty_for(assigned)
	if penalty < 0:
		GameState.last_outcome_penalty = penalty
		GameState.add_alignment(penalty)
	EventBus.objective_changed.emit("")
	_runner.start(branch)


func _on_finished(end_id: String) -> void:
	if end_id == "END_TASK" or end_id == "END_DAY":
		# Task complete — mark it done and hand control back to the day's task board.
		if GameState.current_situation != "" and not GameState.completed_tasks.has(GameState.current_situation):
			GameState.completed_tasks.append(GameState.current_situation)
		GameState.reset_task()
		SceneFlow.change_scene_to_file(TASK_BOARD_SCENE)
