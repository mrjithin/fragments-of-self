extends Node
## Headless check of the end-of-run achievements (scripts/systems/achievements.gd):
## each badge's condition is earned exactly when its state holds, evaluated on the fly
## against GameState. Run: godot --headless res://tools/sim_achievements.tscn

var _failures: int = 0


func _check(label: String, condition: bool) -> void:
	if condition:
		print("PASS: ", label)
	else:
		print("FAIL: ", label)
		_failures += 1


## The set of earned achievement titles for the current GameState.
## `final` mirrors the ending screen's end-of-run evaluation.
func _earned_titles(final: bool = false) -> Dictionary:
	var out: Dictionary = {}
	for e in Achievements.earned(final):
		out[str((e as Dictionary).get("title", ""))] = true
	return out


func _ready() -> void:
	GameState.reset_run()

	# Fresh run: nothing is earned yet — "Held Together" is an end-of-run badge,
	# so a brand-new game shows zero badges.
	var t: Dictionary = _earned_titles()
	_check("a fresh run has not earned 'Held Together'", not t.has("Held Together"))
	_check("nothing earned on a fresh run", t.is_empty())

	# Mid-run (day 2+) it stays locked; only the final evaluation can earn it.
	GameState.advance_day()
	_check("mid-run, 'Held Together' stays locked", not _earned_titles().has("Held Together"))
	_check("a clean finished run earns 'Held Together'", _earned_titles(true).has("Held Together"))

	# Integration: high final alignment.
	GameState.ending_alignment = 6
	_check("high alignment earns 'Integration'", _earned_titles().has("Integration"))

	# The Whole Picture: the core memories recovered.
	for m in ["m_treehouse", "m_porch", "m_kitchen", "m_whole"]:
		GameState.record_memory(m)
	_check("core memories earn 'The Whole Picture'", _earned_titles().has("The Whole Picture"))

	# Aware: every DID fact surfaced.
	for f in ["f_alters", "f_switching", "f_origin", "f_coconscious", "f_treatment", "f_recovery"]:
		GameState.record_fact(f)
	_check("every fact earns 'Aware'", _earned_titles().has("Aware"))

	# Mediator: a bond mended (a relationship_log entry).
	GameState.relationship_log.append({"pair": "iris|rowan", "from_status": "strained", "to_status": "healthy"})
	_check("mending a bond earns 'Mediator'", _earned_titles().has("Mediator"))

	# A breaking point this run revokes 'Held Together' even at the end.
	GameState.ever_broke = true
	_check("a breaking point loses 'Held Together'", not _earned_titles(true).has("Held Together"))

	# With everything met (minus Held Together), the other four are all earned.
	_check("all four progress badges earned", _earned_titles(true).size() == 4)

	GameState.reset_run()
	_check("reset clears all badges (fresh run earns nothing)",
		_earned_titles().is_empty())

	print("=== sim_achievements done, failures: ", _failures, " ===")
	get_tree().quit(_failures)
