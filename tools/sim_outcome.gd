extends Node
## Exercises the REAL external_world._play_outcome (by instantiating the scene) to
## prove the alter choice now has teeth: matching strengths + a calm, unfraught alter
## does well; sending the wrong, triggered, overwhelmed alter with a strained bond is
## punished — alignment drops and their stress spikes and persists.
## Run: godot --headless res://tools/sim_outcome.tscn

const EXTERNAL: String = "res://scenes/external/external_world.tscn"
const SITUATION: String = "res://data/external_situation.json"   # job_interview, trigger=deadlines

var _fail: int = 0


func _check(label: String, ok: bool) -> void:
	print(("PASS: " if ok else "FAIL: "), label)
	if not ok:
		_fail += 1


func _play(assigned: String, stress_seed: Dictionary, mend: bool, base_align: int) -> void:
	GameState.reset_run()
	GameClock.reset_day()
	GameState.ending_alignment = base_align
	GameState.alter_stress = stress_seed.duplicate()
	if mend:
		GameState.relationship_affinity["iris|rowan"] = 80   # healthy, no bond penalty
	GameState.current_situation = SITUATION
	GameState.assigned_alter_id = assigned
	# external_world._ready() sees assigned + no outcome_played flag -> runs _play_outcome.
	var inst: Node = load(EXTERNAL).instantiate()
	add_child(inst)
	await get_tree().process_frame
	inst.queue_free()
	await get_tree().process_frame


func _ready() -> void:
	print("=== sim_outcome: choices have consequences ===")
	var calm := {"manager": 10, "iris": 35, "rowan": 20, "june": 25}

	# A) Right call: iris (composure), calm, not triggered by 'deadlines', bond mended.
	await _play("iris", calm, true, 0)
	_check("right alter: alignment rewarded (+2)", GameState.ending_alignment == 2)
	_check("right alter: only modest stress (+15 -> 50)", GameState.alter_stress["iris"] == 50)

	# B) Wrong call: rowan, overwhelmed (80), hit by his 'deadlines' trigger, bond strained.
	# Risk p clamps to 0.9 -> he falters (seeded): demoted to the strain branch (align 0),
	# stress spikes past 100 (breaking point, -1). From base 6: 6 + 0 - 1 = 5.
	await _play("rowan", {"manager": 10, "iris": 35, "rowan": 80, "june": 25}, false, 6)
	_check("wrong alter: faltered, alignment drops (6 + 0 - 1 = 5)", GameState.ending_alignment == 5)
	_check("wrong alter: stress spikes and clamps to 100", GameState.alter_stress["rowan"] == 100)
	_check("wrong alter: breaking-point penalty recorded (-1)", GameState.last_outcome_penalty == -1)

	# C) Prep choice feeds the stress system: 'drill' lands harder than 'calm'.
	await _play("june", calm, true, 0)
	var june_neutral: int = GameState.alter_stress["june"]
	GameState.reset_run(); GameState.set_flag("prep_pushed")
	GameClock.reset_day()
	GameState.alter_stress = calm.duplicate()
	GameState.relationship_affinity["iris|rowan"] = 80
	GameState.current_situation = SITUATION
	GameState.assigned_alter_id = "june"
	var inst: Node = load(EXTERNAL).instantiate()
	add_child(inst)
	await get_tree().process_frame
	_check("prep 'push' adds more stress than neutral", GameState.alter_stress["june"] == june_neutral + 5)
	inst.queue_free()

	print("=== sim_outcome done, failures: %d ===" % _fail)
	await get_tree().process_frame
	get_tree().quit()
