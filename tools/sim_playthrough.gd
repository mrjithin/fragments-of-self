extends Node
## Headless logic simulation of the full Day-1 slice using the REAL managers and
## GameState, mirroring exactly what the scenes do on each player action. Verifies the
## state machine and content produce the intended end-of-day numbers (clicks can't be
## simulated headless, so this checks the logic underneath the UI).
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

	# --- Internal: resolve the iris-rowan conflict (the 'good' choice: +30) ---
	rel_mgr.adjust("iris", "rowan", 30)
	# adjust() emits conflict_resolved when it flips to healthy; internal_mind's handler
	# sets the flag and spends time. Emulate that side effect (no scene mounted):
	if rel_mgr.get_between("iris", "rowan").status == "healthy":
		GameState.set_flag("conflict_resolved")
		GameClock.spend(20)
	_check("conflict now healthy", rel_mgr.get_between("iris", "rowan").status == "healthy")
	_check("conflict_resolved flag set", GameState.has_flag("conflict_resolved"))
	_check("relationship_log recorded mend", GameState.relationship_log.size() == 1)

	# --- Internal: rest the stressed alter (rowan) ---
	alter_mgr.adjust_stress("rowan", -50)
	GameClock.spend(15)
	GameState.set_flag("rested")
	_check("rowan no longer stressed after rest", not alter_mgr.get_alter("rowan").is_stressed())
	_check("rested flag set", GameState.has_flag("rested"))

	# --- Internal: assign the calm, composure-skilled alter (iris) ---
	var assign_ready: bool = GameState.has_flag("conflict_resolved") and GameState.has_flag("rested")
	_check("assignment gated until conflict + rest done", assign_ready)
	GameState.assigned_alter_id = "iris"
	_check("iris has the required skill (composure)",
		alter_mgr.get_alter("iris").has_skill(task.required_skill))

	# --- External return: play the chosen alter's outcome branch ---
	var outcome := task.outcome_for(GameState.assigned_alter_id)
	_check("iris -> best outcome branch", outcome.get("branch", "") == "ext_outcome_iris")
	GameClock.spend(task.time_cost)
	# on_enter effects of ext_outcome_iris (applied by DialogueRunner):
	var node_data: Dictionary = situation.get("nodes", {}).get("ext_outcome_iris", {})
	var on_enter: Dictionary = node_data.get("on_enter", {})
	GameState.add_alignment(int(on_enter.get("align", 0)))   # +2
	GameState.record_memory(on_enter.get("unlock_memory", ""))
	GameState.record_fact(on_enter.get("surface_fact", ""))
	# Plus the +1 alignment from the good conflict choice:
	GameState.add_alignment(1)

	# --- Day end ---
	var summary := GameState.build_day_summary()
	_check("time spent == 20+15+40 == 75", summary.get("time_spent", 0) == 75)
	_check("alignment == 3 (conflict +1, outcome +2)", summary.get("alignment", 0) == 3)
	_check("memory recovered", summary.get("unlocked_memories", []).has("m_treehouse"))
	_check("DID fact surfaced", summary.get("surfaced_facts", []).has("f_switching"))
	_check("assigned alter recorded", summary.get("assigned_alter_id", "") == "iris")

	# --- Save / load round-trip (persistence) ---
	GameState.current_scene = "res://scenes/external/external_world.tscn"
	var saved_align: int = GameState.ending_alignment
	var saved_mems: int = GameState.unlocked_memories.size()
	var saved_iris_aff: int = rel_mgr.get_between("iris", "rowan").affinity
	var saved_rowan_stress: int = alter_mgr.get_alter("rowan").stress
	_check("save() writes a file", SaveManager.save())
	_check("has_save() true after save", SaveManager.has_save())

	GameState.reset_run()
	_check("reset cleared alignment", GameState.ending_alignment == 0)
	_check("reset cleared live state", GameState.alter_stress.is_empty() and GameState.relationship_affinity.is_empty())

	_check("load() succeeds", SaveManager.load())
	_check("load restored alignment", GameState.ending_alignment == saved_align)
	_check("load restored memories", GameState.unlocked_memories.size() == saved_mems)
	_check("load restored conflict flag", GameState.has_flag("conflict_resolved"))
	_check("load restored resume scene", GameState.current_scene == "res://scenes/external/external_world.tscn")

	# Managers rehydrate from the restored GameState rather than the JSON defaults.
	var alter_mgr2 := AlterManager.new()
	alter_mgr2.load_data()
	var rel_mgr2 := RelationshipManager.new()
	rel_mgr2.load_data()
	_check("reloaded rowan stress matches save (rested persisted)",
		alter_mgr2.get_alter("rowan").stress == saved_rowan_stress)
	_check("reloaded iris-rowan affinity matches save (mend persisted)",
		rel_mgr2.get_between("iris", "rowan").affinity == saved_iris_aff)

	SaveManager.delete_save()
	_check("delete_save() removes the file", not SaveManager.has_save())

	print("=== sim complete, failures: ", _failures, " ===")
	get_tree().quit(_failures)
