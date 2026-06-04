extends Node
## Headless check of the run achievements (scripts/systems/achievements.gd):
## progress badges are earnable mid-run, whole-run badges only on the final
## evaluation, and every earned badge is sticky — it survives day advances and
## live state regressing underneath it.
## Run: godot --headless res://tools/sim_achievements.tscn

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
	# --- Fresh run: nothing is earned, and whole-run badges stay locked mid-run.
	GameState.reset_run()
	_check("nothing earned on a fresh run", _earned_titles().is_empty())

	GameState.advance_day()
	GameState.ending_alignment = 6
	var mid: Dictionary = _earned_titles()
	_check("mid-run, 'Held Together' stays locked", not mid.has("Held Together"))
	_check("mid-run, high alignment does not earn 'Integration'", not mid.has("Integration"))

	# --- Final evaluation of a clean, high-alignment run earns both whole-run badges.
	var fin: Dictionary = _earned_titles(true)
	_check("a clean finished run earns 'Held Together'", fin.has("Held Together"))
	_check("high final alignment earns 'Integration'", fin.has("Integration"))

	# --- Sticky: once recorded, a badge survives the state regressing.
	GameState.ending_alignment = 2
	_check("'Integration' stays earned after alignment drops", _earned_titles().has("Integration"))
	GameState.advance_day()
	_check("whole-run badges survive a day advance", _earned_titles().has("Held Together"))

	# --- A breaking point blocks 'Held Together' when it has not been earned yet.
	GameState.reset_run()
	GameState.ever_broke = true
	_check("a breaking point loses 'Held Together'", not _earned_titles(true).has("Held Together"))

	# --- Progress badges: earnable mid-run from run-wide, monotonic state.
	GameState.reset_run()
	for m in ["m_treehouse", "m_porch", "m_kitchen", "m_whole"]:
		GameState.record_memory(m)
	_check("core memories earn 'The Whole Picture'", _earned_titles().has("The Whole Picture"))

	for f in ["f_alters", "f_switching", "f_origin", "f_coconscious", "f_treatment", "f_recovery"]:
		GameState.record_fact(f)
	_check("every fact earns 'Aware'", _earned_titles().has("Aware"))

	GameState.bonds_mended += 1
	_check("mending a bond earns 'Mediator'", _earned_titles().has("Mediator"))
	GameState.advance_day()
	_check("'Mediator' stays earned the next day", _earned_titles().has("Mediator"))

	# --- Reset wipes the sticky store along with everything else.
	GameState.reset_run()
	_check("reset clears all badges (fresh run earns nothing)",
		_earned_titles().is_empty())

	print("=== sim_achievements done, failures: ", _failures, " ===")
	get_tree().quit(_failures)
