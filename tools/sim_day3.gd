extends Node
## Headless playthrough of the data-only Day 3 ("A hard conversation"), proving the
## new content is wired correctly through the existing systems with no code changes:
## day config, the rest-loop gate, skill matching, outcome branch, and the memory +
## DID-fact beats. Run: godot --headless res://tools/sim_day3.tscn

const DAYS_PATH: String = "res://data/days.json"
const TASKS_PATH: String = "res://data/tasks.json"
const SITUATION: String = "res://data/external_situation_day3.json"

var _fail: int = 0


func _check(label: String, ok: bool) -> void:
	print(("PASS: " if ok else "FAIL: "), label)
	if not ok:
		_fail += 1


func _ready() -> void:
	print("=== sim_day3: data-only Day 3 ===")
	var days: Array = JsonLoader.load_dict(DAYS_PATH).get("days", [])
	_check("run has at least 3 days configured", days.size() >= 3)

	# --- Boot straight into day 3 and apply its setup (mirrors task_board._ready) ---
	GameState.reset_run()
	GameState.day = 3
	GameClock.reset_day()
	# Live stress carried over from days 1-2 (rowan was rested, everyone else calm).
	# The day-3 setup then layers iris's fresh pressure on top of this baseline.
	GameState.alter_stress = {"manager": 10, "iris": 35, "rowan": 20, "june": 25}
	var alter_mgr := AlterManager.new()
	alter_mgr.load_data()
	var rel_mgr := RelationshipManager.new()
	rel_mgr.load_data()

	var cfg: Dictionary = days[2]
	var setup: Dictionary = cfg.get("setup", {})
	for aid in setup.get("stress", {}):
		alter_mgr.adjust_stress(aid, int(setup["stress"][aid]) - alter_mgr.get_alter(aid).stress)
	_check("day-3 setup leaves iris overwhelmed", alter_mgr.get_alter("iris").is_stressed())

	# --- Task + skill ---
	var situation := JsonLoader.load_dict(SITUATION)
	var task := Task.from_dict(situation.get("task_id", ""),
		JsonLoader.load_dict(TASKS_PATH).get("tasks", {}).get("hard_conversation", {}))
	_check("day-3 board points at hard_conversation", task.id == "hard_conversation")
	_check("task calls for boundaries", task.required_skill == "boundaries")
	_check("iris holds the boundaries skill", alter_mgr.get_alter("iris").has_skill("boundaries"))

	# --- Rest-loop gate: can't send anyone while iris is overwhelmed ---
	_check("assignment blocked while iris overwhelmed", alter_mgr.any_stressed())
	alter_mgr.adjust_stress("iris", -50)
	_check("resting iris clears the block", not alter_mgr.any_stressed())

	# --- Outcome branch + the memory / fact / alignment beats ---
	var outcome: Dictionary = task.outcome_for("iris")
	_check("iris -> best branch d3_out_iris", outcome.get("branch", "") == "d3_out_iris")

	var before_align: int = GameState.ending_alignment
	var node: Dictionary = situation.get("nodes", {}).get("d3_out_iris", {})
	var on_enter: Dictionary = node.get("on_enter", {})
	GameState.add_alignment(int(on_enter.get("align", 0)))
	GameState.record_memory(str(on_enter.get("unlock_memory", "")))
	GameState.record_fact(str(on_enter.get("surface_fact", "")))
	_check("best outcome grants +2 alignment", GameState.ending_alignment == before_align + 2)
	_check("unlocks the m_kitchen memory", GameState.unlocked_memories.has("m_kitchen"))
	_check("surfaces the f_coconscious fact", GameState.surfaced_facts.has("f_coconscious"))
	_check("outcome ends the task (END_TASK)",
		situation.get("nodes", {}).get("d3_done", {}).get("next", "") == "END_TASK")

	# --- Day 3 sits mid-arc; the day-end screen offers "Continue to Day 4" ---
	_check("day 3 is not the finale (more days follow)", GameState.day < days.size())

	print("=== sim_day3 done, failures: %d ===" % _fail)
	await get_tree().process_frame
	get_tree().quit()
