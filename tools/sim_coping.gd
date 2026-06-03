extends Node
## Verifies the coping-uncertainty system: safe play is reliable, risk is a real
## (seeded) gamble, the odds band hides a not-yet-learned trigger, and a trigger is
## discovered by living it. Run: godot --headless res://tools/sim_coping.tscn

const EXTERNAL: String = "res://scenes/external/external_world.tscn"
const SITUATION: String = "res://data/external_situation.json"   # job_interview, trigger=deadlines

var _fail: int = 0


func _check(label: String, ok: bool) -> void:
	print(("PASS: " if ok else "FAIL: "), label)
	if not ok:
		_fail += 1


func _ready() -> void:
	print("=== sim_coping: real uncertainty ===")
	GameState.reset_run()
	var alter_mgr := AlterManager.new()
	alter_mgr.load_data()
	var rel_mgr := RelationshipManager.new()
	rel_mgr.load_data()
	var task := Task.from_dict("job_interview",
		JsonLoader.load_dict("res://data/tasks.json").get("tasks", {}).get("job_interview", {}))

	var iris := alter_mgr.get_alter("iris")     # composure, calm(35), trigger=raised voices
	var rowan := alter_mgr.get_alter("rowan")   # focus, stressed(80), trigger=deadlines

	# An at-risk alter is a real gamble: rowan is stressed(80) + hit by his trigger
	# (deadlines) + in a strained bond (iris-rowan starts at 25) -> capped 0.9.
	_check("stressed + triggered + strained -> 0.9 falter chance", Coping.falter_chance(rowan, task, rel_mgr) == 0.9)
	# Safe play is reliable: mend iris's bond, and calm+suited iris can't falter.
	rel_mgr.adjust("iris", "rowan", 60)
	_check("calm, suited, mended -> 0 falter chance", Coping.falter_chance(iris, task, rel_mgr) == 0.0)

	# The band hides a not-yet-learned trigger: rowan's true risk is 0.9, but with the
	# trigger undiscovered the visible band only reflects stress (+strain) -> not "very risky".
	_check("rowan's trigger is unknown at first", not GameState.discovered_triggers.has("deadlines"))
	var hidden_band: Dictionary = Coping.band(rowan, task, rel_mgr)
	_check("band understates hidden-trigger risk", hidden_band.get("key", "") != "bad")
	_check("calm alter reads as reliable", Coping.band(iris, task, rel_mgr).get("key", "") == "good")

	_check("demote: best -> ok", Coping.demote("best") == "ok")
	_check("demote: ok -> strain", Coping.demote("ok") == "strain")
	_check("demote: strain stays strain (floors)", Coping.demote("strain") == "strain")

	# Living a trigger reveals it. Send rowan into his 'deadlines' task.
	GameState.reset_run()
	GameClock.reset_day()
	GameState.alter_stress = {"manager": 10, "iris": 35, "rowan": 80, "june": 25}
	GameState.current_situation = SITUATION
	GameState.assigned_alter_id = "rowan"
	var inst: Node = load(EXTERNAL).instantiate()
	add_child(inst)
	await get_tree().process_frame
	_check("trigger discovered after living it", GameState.discovered_triggers.has("deadlines"))
	inst.queue_free()
	await get_tree().process_frame

	print("=== sim_coping done, failures: %d ===" % _fail)
	get_tree().quit(_fail)
