extends Node
## Headless playthrough of the data-only Day 4 ("The appointment"), the arc finale.
## Proves the new content wires through existing systems: day config + strain setup,
## the listening skill, outcome branch, memory/fact beats, and the END boundary.
## Run: godot --headless res://tools/sim_day4.tscn

const DAYS_PATH: String = "res://data/days.json"
const TASKS_PATH: String = "res://data/tasks.json"
const SITUATION: String = "res://data/external_situation_day4.json"

var _fail: int = 0


func _check(label: String, ok: bool) -> void:
	print(("PASS: " if ok else "FAIL: "), label)
	if not ok:
		_fail += 1


func _ready() -> void:
	print("=== sim_day4: data-only Day 4 (finale) ===")
	var days: Array = JsonLoader.load_dict(DAYS_PATH).get("days", [])
	_check("run has at least 5 days configured", days.size() >= 5)

	GameState.reset_run()
	GameState.day = 4
	GameClock.reset_day()
	GameState.alter_stress = {"manager": 10, "iris": 35, "rowan": 20, "june": 25}
	var alter_mgr := AlterManager.new()
	alter_mgr.load_data()
	var rel_mgr := RelationshipManager.new()
	rel_mgr.load_data()

	# Day-4 setup re-strains the iris<->rowan bond (a Talk opportunity, not required).
	var setup: Dictionary = (days[3] as Dictionary).get("setup", {})
	for key in setup.get("strain", {}):
		GameState.relationship_affinity[key] = int(setup["strain"][key])
	rel_mgr.load_data()
	_check("day-4 setup strains iris<->rowan", rel_mgr.get_between("iris", "rowan").status == "strained")
	_check("nobody overwhelmed -> can assign right away", not alter_mgr.any_stressed())

	var situation := JsonLoader.load_dict(SITUATION)
	var task := Task.from_dict(situation.get("task_id", ""),
		JsonLoader.load_dict(TASKS_PATH).get("tasks", {}).get("the_appointment", {}))
	_check("day-4 board points at the_appointment", task.id == "the_appointment")
	_check("task calls for listening", task.required_skill == "listening")
	_check("june holds the listening skill", alter_mgr.get_alter("june").has_skill("listening"))

	var outcome: Dictionary = task.outcome_for("june")
	_check("june -> best branch d4_out_june", outcome.get("branch", "") == "d4_out_june")

	var node: Dictionary = situation.get("nodes", {}).get("d4_out_june", {})
	var on_enter: Dictionary = node.get("on_enter", {})
	GameState.add_alignment(int(on_enter.get("align", 0)))
	GameState.record_memory(str(on_enter.get("unlock_memory", "")))
	GameState.record_fact(str(on_enter.get("surface_fact", "")))
	_check("best outcome grants +2 alignment", GameState.ending_alignment == 2)
	_check("unlocks the m_first_words memory", GameState.unlocked_memories.has("m_first_words"))
	_check("surfaces the f_treatment fact", GameState.surfaced_facts.has("f_treatment"))
	_check("outcome ends the task (END_TASK)",
		situation.get("nodes", {}).get("d4_done", {}).get("next", "") == "END_TASK")

	_check("day 4 is no longer the finale (Day 5 follows)", GameState.day < days.size())

	print("=== sim_day4 done, failures: %d ===" % _fail)
	get_tree().quit()
