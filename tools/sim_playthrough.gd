extends Node
## Headless logic simulation of the slice using the REAL managers and GameState,
## mirroring exactly what the scenes do on each player action. Verifies the state
## machine and content produce the intended numbers (clicks can't be simulated
## headless, so this checks the logic underneath the UI).
## Run: godot --headless res://tools/sim_playthrough.tscn

var _failures: int = 0


func _check(label: String, condition: bool) -> void:
	if condition:
		print("PASS: ", label)
	else:
		print("FAIL: ", label)
		_failures += 1


func _ready() -> void:
	GameState.reset_run()
	GameClock.reset_day()

	var alter_mgr := AlterManager.new()
	alter_mgr.load_data()
	var rel_mgr := RelationshipManager.new()
	rel_mgr.load_data()

	_check("4 alters loaded", alter_mgr.order.size() == 4)
	_check("iris-rowan starts strained",
		rel_mgr.get_between("iris", "rowan").status == "strained")
	_check("rowan starts stressed (>=65)", alter_mgr.get_alter("rowan").is_stressed())

	# --- External: situation loads, has the enter_mind handoff ---
	var situation := JsonLoader.load_dict("res://data/external_situation.json")
	var task := Task.from_dict(situation.get("task_id", ""),
		JsonLoader.load_dict("res://data/tasks.json").get("tasks", {}).get("job_interview", {}))
	_check("task loaded with composure skill", task.required_skill == "composure")
	GameState.current_task_id = task.id

	# --- #3 relationship penalty exists while the bond is strained ---
	_check("strained bond → penalty -1 for iris", rel_mgr.penalty_for("iris") == -1)
	_check("strained bond → penalty -1 for rowan", rel_mgr.penalty_for("rowan") == -1)
	_check("healthy june → no penalty", rel_mgr.penalty_for("june") == 0)

	# --- Internal: gate is 'no overwhelmed alter'; mending is optional ---
	_check("assignment blocked while rowan is overwhelmed", alter_mgr.any_stressed())

	# Resolve the iris-rowan conflict (good choice: +30 affinity, +1 alignment).
	rel_mgr.adjust("iris", "rowan", 30)
	if rel_mgr.get_between("iris", "rowan").status == "healthy":
		GameClock.spend(20)               # internal_mind._on_conflict_resolved
	GameState.add_alignment(1)            # the +1 from the good conflict choice
	_check("conflict now healthy", rel_mgr.get_between("iris", "rowan").status == "healthy")
	_check("relationship_log recorded mend", GameState.relationship_log.size() == 1)
	_check("mended bond → penalty cleared for iris", rel_mgr.penalty_for("iris") == 0)

	# Rest the overwhelmed alter (rowan) — this unlocks assignment.
	alter_mgr.adjust_stress("rowan", -50)
	GameClock.spend(15)
	_check("rowan no longer stressed after rest", not alter_mgr.get_alter("rowan").is_stressed())
	_check("assignment unblocked once nobody is overwhelmed", not alter_mgr.any_stressed())

	# Assign the calm, composure-skilled alter (iris).
	GameState.assigned_alter_id = "iris"
	_check("iris has the required skill (composure)",
		alter_mgr.get_alter("iris").has_skill(task.required_skill))

	# --- External return: play the chosen alter's outcome branch ---
	var outcome := task.outcome_for(GameState.assigned_alter_id)
	_check("iris -> best outcome branch", outcome.get("branch", "") == "ext_outcome_iris")
	GameClock.spend(task.time_cost)
	GameState.add_alignment(rel_mgr.penalty_for("iris"))   # 0 (mended) — the #3 hook
	var node_data: Dictionary = situation.get("nodes", {}).get("ext_outcome_iris", {})
	var on_enter: Dictionary = node_data.get("on_enter", {})
	GameState.add_alignment(int(on_enter.get("align", 0)))   # +2
	GameState.record_memory(on_enter.get("unlock_memory", ""))
	GameState.record_fact(on_enter.get("surface_fact", ""))

	# --- Day end ---
	var summary := GameState.build_day_summary()
	_check("time spent == 20+15+40 == 75", summary.get("time_spent", 0) == 75)
	_check("alignment == 3 (conflict +1, outcome +2, no penalty)", summary.get("alignment", 0) == 3)
	_check("memory recovered", summary.get("unlocked_memories", []).has("m_treehouse"))
	_check("DID fact surfaced", summary.get("surfaced_facts", []).has("f_switching"))
	_check("assigned alter recorded", summary.get("assigned_alter_id", "") == "iris")

	# --- Save / load round-trip (persistence) ---
	GameState.current_scene = "res://scenes/external/external_world.tscn"
	var saved_align: int = GameState.ending_alignment
	var saved_iris_aff: int = rel_mgr.get_between("iris", "rowan").affinity
	var saved_rowan_stress: int = alter_mgr.get_alter("rowan").stress
	_check("save() writes a file", SaveManager.save())
	GameState.reset_run()
	_check("reset cleared live state", GameState.alter_stress.is_empty())
	_check("load() succeeds", SaveManager.load())
	_check("load restored alignment", GameState.ending_alignment == saved_align)
	_check("load restored conflict mend", GameState.relationship_affinity.get("iris|rowan", 0) == saved_iris_aff)

	# managers rehydrate from restored GameState, not the JSON defaults
	var am2 := AlterManager.new()
	am2.load_data()
	var rel2 := RelationshipManager.new()
	rel2.load_data()
	_check("reloaded rowan stress persisted", am2.get_alter("rowan").stress == saved_rowan_stress)
	_check("reloaded iris-rowan now healthy", rel2.get_between("iris", "rowan").status == "healthy")

	# --- #1 multi-day loop ---
	var days: Array = JsonLoader.load_dict("res://data/days.json").get("days", [])
	_check("run has 2 days configured", days.size() == 2)

	GameState.advance_day()
	_check("advanced to day 2", GameState.day == 2)
	_check("alignment carries across days", GameState.ending_alignment == saved_align)
	_check("memories carry across days", GameState.unlocked_memories.has("m_treehouse"))
	_check("per-day flags cleared on new day", not GameState.has_flag("outcome_played"))

	# Day-2 setup (external_world applies this once): june becomes overwhelmed.
	GameState.alter_stress["june"] = 72
	GameClock.reset_day()
	var am3 := AlterManager.new()
	am3.load_data()
	_check("day-2 june is overwhelmed (setup)", am3.get_alter("june").is_stressed())
	_check("day-2 rowan stayed calm (persisted rest)", not am3.get_alter("rowan").is_stressed())

	var t2 := Task.from_dict("friend_crisis",
		JsonLoader.load_dict("res://data/tasks.json").get("tasks", {}).get("friend_crisis", {}))
	_check("day-2 task needs empathy", t2.required_skill == "empathy")
	_check("june has empathy", am3.get_alter("june").has_skill("empathy"))

	_check("day-2 assignment blocked while june overwhelmed", am3.any_stressed())
	am3.adjust_stress("june", -50)
	GameClock.spend(15)
	_check("day-2 assignment unblocked after resting june", not am3.any_stressed())
	GameState.assigned_alter_id = "june"
	_check("june -> best outcome on day 2", t2.outcome_for("june").get("branch", "") == "d2_out_june")
	GameState.add_alignment(2)
	GameState.record_memory("m_porch")
	_check("day-2 alignment accumulates (3 + 2 = 5)", GameState.ending_alignment == 5)
	_check("day-2 memory adds to the mystery", GameState.unlocked_memories.size() == 2)

	SaveManager.delete_save()
	_check("delete_save() removes the file", not SaveManager.has_save())

	print("=== sim complete, failures: ", _failures, " ===")
	get_tree().quit(_failures)
