extends Node
## Headless check of the achievements engine: each data-driven condition awards exactly
## when met, awards are idempotent, and the EventBus signal path triggers a re-evaluation.
## Run: godot --headless res://tools/sim_achievements.tscn

var _failures: int = 0
var _emitted: Array[String] = []


func _check(label: String, condition: bool) -> void:
	if condition:
		print("PASS: ", label)
	else:
		print("FAIL: ", label)
		_failures += 1


func _ready() -> void:
	EventBus.achievement_unlocked.connect(func(id): _emitted.append(id))
	GameState.reset_run()

	Achievements.evaluate()
	_check("nothing earned on a fresh run", GameState.unlocked_achievements.is_empty())

	# Recovering a memory should award the first-memory milestone via the signal path.
	GameState.record_memory("m_treehouse")
	EventBus.memory_unlocked.emit("m_treehouse")
	_check("first memory awards 'A Door Opens'", GameState.unlocked_achievements.has("a_first_memory"))
	_check("the award emitted on the bus", _emitted.has("a_first_memory"))

	# Idempotent — re-evaluating doesn't double-award.
	var count_before: int = GameState.unlocked_achievements.size()
	Achievements.evaluate()
	_check("re-evaluating doesn't double-award", GameState.unlocked_achievements.size() == count_before)

	# Recover every memory -> the whole-story milestone.
	for mid in ["m_porch", "m_kitchen", "m_first_words", "m_whole"]:
		GameState.record_memory(mid)
	Achievements.evaluate()
	_check("all memories award 'The Whole of It'", GameState.unlocked_achievements.has("a_all_memories"))

	# Facts: three for the curiosity milestone, all of them for awareness.
	for fid in ["f_alters", "f_switching", "f_origin"]:
		GameState.record_fact(fid)
	Achievements.evaluate()
	_check("three facts award 'Willing to Understand'", GameState.unlocked_achievements.has("a_curious"))
	for fid in ["f_coconscious", "f_treatment", "f_recovery"]:
		GameState.record_fact(fid)
	Achievements.evaluate()
	_check("every fact awards 'Awareness'", GameState.unlocked_achievements.has("a_informed"))

	# Living through a trigger.
	GameState.discovered_triggers.append("deadlines")
	Achievements.evaluate()
	_check("a discovered trigger awards 'Learned the Hard Way'", GameState.unlocked_achievements.has("a_lived_it"))

	# Alignment threshold and reaching the final day.
	GameState.ending_alignment = 6
	GameState.day = 5
	Achievements.evaluate()
	_check("high alignment awards 'Together'", GameState.unlocked_achievements.has("a_together"))
	_check("reaching day 5 awards 'All the Way Through'", GameState.unlocked_achievements.has("a_through_it"))

	_check("every one of the 7 milestones earned", GameState.unlocked_achievements.size() == 7)

	GameState.reset_run()
	_check("reset clears earned milestones", GameState.unlocked_achievements.is_empty())

	print("=== sim_achievements done, failures: ", _failures, " ===")
	get_tree().quit(_failures)
