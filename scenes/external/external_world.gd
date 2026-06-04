extends Node2D
## The External World view: presents the day's situation as dialogue. At the decision
## point the player "looks inward" (the handoff to the Internal Mind). On return, the
## chosen alter's outcome branch plays, firing the memory + DID-fact beats.

const SITUATION_PATH: String = "res://data/external_situation.json"
const TASKS_PATH: String = "res://data/tasks.json"
const INTERNAL_SCENE: String = "res://scenes/internal/internal_mind.tscn"
const TASK_BOARD_SCENE: String = "res://scenes/external/task_board.tscn"
const READ_STEP: int = 4               # time drained per dialogue beat as the player reads
const DEFAULT_BG: String = "res://assets/art/bg_external.png"

@onready var _box: DialogueBox = %DialogueBox
@onready var _bg: TextureRect = $BgLayer/Background
@onready var _leaves: Node2D = $Leaves

var _runner: DialogueRunner
var _situation: Dictionary = {}
var _task: Task
var _task_budget: int = 0              # this task's total time_cost, drained across the read


func _ready() -> void:
	# Play the situation the player chose on the task board (fallback to the default).
	var sit_path: String = GameState.current_situation if GameState.current_situation != "" else SITUATION_PATH
	_situation = JsonLoader.load_dict(sit_path)
	_task = _load_task(_situation.get("task_id", ""))
	_task_budget = _task.time_cost if _task else 0

	# Per-situation pixel art + ambience, so each task looks and sounds like its own place.
	var bg_path: String = str(_situation.get("background", DEFAULT_BG))
	if bg_path != "" and ResourceLoader.exists(bg_path):
		_bg.texture = load(bg_path)
	var music_path: String = str(_situation.get("music", ""))
	if music_path != "":
		Music.play_for_situation(music_path)
	# Falling leaves suit the outdoor autumn fallback; indoor situations (each with
	# its own background) turn them off. A situation can override with a "leaves" flag.
	if _leaves:
		_leaves.visible = bool(_situation.get("leaves", not _situation.has("background")))

	_runner = DialogueRunner.new()
	add_child(_runner)
	_runner.setup(_situation, _box)
	_runner.action_triggered.connect(_on_action)
	_runner.finished.connect(_on_finished)
	_runner.node_shown.connect(_on_node_shown)

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


## Drain the task's time budget a little on each dialogue beat, so the HUD meter
## visibly moves while the player reads instead of jumping only at the outcome.
## Tracked in GameState (not on this node) so it survives the mind round-trip — the
## scene is rebuilt on return, but the total charged still sums to the task's time_cost.
func _on_node_shown(_node_id: String) -> void:
	var step: int = mini(READ_STEP, _task_budget - GameState.task_time_spent)
	if step > 0:
		GameState.task_time_spent += step
		GameClock.spend(step)


func _on_action(action: String) -> void:
	if action == "enter_mind":
		GameState.current_task_id = _task.id if _task else ""
		EventBus.objective_changed.emit("")
		EventBus.enter_mind_requested.emit(GameState.current_task_id)
		SceneFlow.change_scene_to_file(INTERNAL_SCENE)


## Resume on the chosen alter's branch and resolve the consequences. The alter
## usually performs at their APTITUDE for the task, but RISK — high stress, a strained
## bond, or a task that hits their trigger — gives a real, seeded chance to FALTER a
## tier (worse branch, more stress, maybe a breaking point). Safe, suited, calm play
## stays reliable; taking a risk is a genuine gamble. Mirrors that you can't perfectly
## predict how a part will cope — you do your best with what you can see.
func _play_outcome() -> void:
	GameState.set_flag("outcome_played")
	var assigned: String = GameState.assigned_alter_id

	var alter_mgr := AlterManager.new()
	alter_mgr.load_data()
	var alter: Alter = alter_mgr.get_alter(assigned)
	var rel_mgr := RelationshipManager.new()
	rel_mgr.load_data()

	var authored: Dictionary = _task.outcome_for(assigned) if _task else {}
	var aptitude: String = str(authored.get("tier", "ok"))

	var triggered: bool = _task != null and alter != null and _task.trigger != "" and alter.triggers.has(_task.trigger)
	var was_stressed: bool = alter != null and alter.is_stressed()
	var strained: bool = rel_mgr.penalty_for(assigned) < 0

	# The gamble. No risk factors -> p == 0 -> no roll, deterministic safe outcome.
	var p: float = Coping.falter_chance(alter, _task, rel_mgr, false)
	var faltered: bool = p > 0.0 and RNG.randf_unit() < p

	var notes: PackedStringArray = []
	var stress_add: int = 15                          # any task is tiring
	var extra_align: int = 0

	# Mid-situation prep choice: a real tradeoff baked into the stress system.
	if GameState.has_flag("prep_eased"):
		stress_add -= 5
		notes.append("Eased in beforehand — it landed a little softer.")
	elif GameState.has_flag("prep_pushed"):
		stress_add += 5
		extra_align += 1
		notes.append("Pushed hard — sharper now, but it'll cost them later.")
	GameState.flags.erase("prep_eased")
	GameState.flags.erase("prep_pushed")

	var result_tier: String = aptitude
	if faltered:
		result_tier = Coping.demote(aptitude)
		stress_add += 15
		notes.append("It got away from %s." % (alter.name if alter else "them"))
		if triggered:
			stress_add += 25
			notes.append("Their trigger (%s) caught them." % _task.trigger)
		if was_stressed:
			stress_add += 10
	elif triggered or was_stressed or strained:
		notes.append("Risky — but %s held it together." % (alter.name if alter else "they"))

	# You learn a trigger by living it; only then is it revealed on the cards.
	if triggered and _task.trigger != "" and not GameState.discovered_triggers.has(_task.trigger):
		GameState.discovered_triggers.append(_task.trigger)

	var branch: String = _task.branch_for_tier(result_tier) if _task else str(_situation.get("start", ""))
	if branch == "":
		branch = str(authored.get("branch", _situation.get("start", "")))

	# Stress + the breaking-point beat.
	var before: int = alter.stress if alter else 0
	var after: int = clampi(before + stress_add, 0, 100)
	var broke: bool = after >= 100 and before < 100
	if broke:
		extra_align -= 1
		GameState.ever_broke = true
		notes.append("%s hit their breaking point — fragile for days." % alter.name)

	if extra_align != 0:
		GameState.add_alignment(extra_align)
	GameState.last_outcome_penalty = extra_align
	if alter:
		alter_mgr.adjust_stress(assigned, stress_add)  # persists via GameState.alter_stress
		_runner.override_speaker(branch, alter.name)   # tier branches are name-free; voice = who was sent

	# Surface what happened (the branch's authored align lands when it shows).
	var tier_word: Dictionary = {"best": "Strong", "ok": "Okay", "strain": "Faltered"}
	var headline: String = "%s — %s" % [alter.name if alter else "They", tier_word.get(result_tier, "Okay")]
	if alter:
		headline += "  ·  stress %d→%d%s" % [before, after, "  ⚠ BREAKING POINT" if broke else ""]
	EventBus.objective_changed.emit("%s   %s" % [headline, " ".join(notes)])
	_runner.start(branch)


func _on_finished(end_id: String) -> void:
	if end_id == "END_TASK" or end_id == "END_DAY":
		# Charge any of the task's time the read didn't reach, so the full time_cost
		# is always paid (short branches don't get the task done "for free").
		var remainder: int = _task_budget - GameState.task_time_spent
		if remainder > 0:
			GameClock.spend(remainder)
		# Task complete — mark it done and hand control back to the day's task board.
		if GameState.current_situation != "" and not GameState.completed_tasks.has(GameState.current_situation):
			GameState.completed_tasks.append(GameState.current_situation)
		GameState.reset_task()
		SceneFlow.change_scene_to_file(TASK_BOARD_SCENE)
