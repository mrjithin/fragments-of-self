extends TestCase
## GameState: run/day/task lifecycle, recording helpers, and save serialization.


func test_reset_run_clears_everything() -> void:
	GameState.day = 4
	GameState.ending_alignment = 7
	GameState.set_flag("x")
	GameState.ever_broke = true
	GameState.bonds_mended = 2
	GameState.earned_badges.append("mediator")
	GameState.record_memory("m_porch")
	GameState.record_fact("f_alters")
	GameState.seen_events.append("ev_quiet_morning")
	GameState.alter_stress["iris"] = 80
	GameState.reset_run()
	check_eq("day back to 1", GameState.day, 1)
	check_eq("alignment zeroed", GameState.ending_alignment, 0)
	check("flags cleared", GameState.flags.is_empty())
	check("ever_broke cleared", not GameState.ever_broke)
	check_eq("bonds_mended zeroed", GameState.bonds_mended, 0)
	check("earned_badges cleared", GameState.earned_badges.is_empty())
	check("memories cleared", GameState.unlocked_memories.is_empty())
	check("facts cleared", GameState.surfaced_facts.is_empty())
	check("seen events cleared", GameState.seen_events.is_empty())
	check("stress cleared", GameState.alter_stress.is_empty())


func test_add_alignment_clamps() -> void:
	GameState.add_alignment(99)
	check_eq("clamped to ALIGNMENT_MAX", GameState.ending_alignment, GameState.ALIGNMENT_MAX)
	GameState.add_alignment(-99)
	check_eq("clamped to 0", GameState.ending_alignment, 0)
	GameState.add_alignment(3)
	GameState.add_alignment(-1)
	check_eq("deltas accumulate", GameState.ending_alignment, 2)


func test_record_memory_and_fact_dedup() -> void:
	GameState.record_memory("m_porch")
	GameState.record_memory("m_porch")
	GameState.record_memory("")
	check_eq("memory recorded once, empty ignored", GameState.unlocked_memories, ["m_porch"])
	GameState.record_fact("f_alters")
	GameState.record_fact("f_alters")
	GameState.record_fact("")
	check_eq("fact recorded once, empty ignored", GameState.surfaced_facts, ["f_alters"])


func test_flags() -> void:
	check("unset flag is false", not GameState.has_flag("nope"))
	GameState.set_flag("a")
	check("set flag is true", GameState.has_flag("a"))
	GameState.set_flag("a", false)
	check("flag can be set false", not GameState.has_flag("a"))


func test_advance_day_clears_per_day_keeps_cumulative() -> void:
	# Per-day state…
	GameState.set_flag("day_setup_done")
	GameState.current_task_id = "t"
	GameState.assigned_alter_id = "iris"
	GameState.current_situation = "res://data/x.json"
	GameState.task_time_spent = 10
	GameState.current_event_text = "ev"
	GameState.completed_tasks.append("res://data/x.json")
	GameState.day_tasks.append("res://data/x.json")
	GameState.relationship_log.append({"pair": "a & b"})
	GameState.stress_before["iris"] = 10
	# …and cumulative state.
	GameState.ending_alignment = 5
	GameState.ever_broke = true
	GameState.bonds_mended = 1
	GameState.earned_badges.append("mediator")
	GameState.record_memory("m_porch")
	GameState.record_fact("f_alters")
	GameState.seen_events.append("ev_quiet_morning")
	GameState.used_secondaries.append("res://data/errand_situation.json")
	GameState.alter_stress["iris"] = 50
	GameState.relationship_affinity["iris|rowan"] = 40

	GameState.advance_day()

	check_eq("day bumped", GameState.day, 2)
	check("flags cleared", GameState.flags.is_empty())
	check("task handoff cleared", GameState.current_task_id == "" and GameState.assigned_alter_id == "")
	check("situation cleared", GameState.current_situation == "" and GameState.task_time_spent == 0)
	check("event text cleared", GameState.current_event_text == "")
	check("completed tasks cleared", GameState.completed_tasks.is_empty())
	check("day tasks cleared", GameState.day_tasks.is_empty())
	check("relationship log cleared", GameState.relationship_log.is_empty())
	check("stress snapshot cleared", GameState.stress_before.is_empty())

	check_eq("alignment kept", GameState.ending_alignment, 5)
	check("ever_broke kept", GameState.ever_broke)
	check_eq("bonds_mended kept", GameState.bonds_mended, 1)
	check_eq("earned badges kept", GameState.earned_badges, ["mediator"])
	check_eq("memories kept", GameState.unlocked_memories, ["m_porch"])
	check_eq("facts kept", GameState.surfaced_facts, ["f_alters"])
	check_eq("seen events kept", GameState.seen_events, ["ev_quiet_morning"])
	check_eq("used secondaries kept", GameState.used_secondaries, ["res://data/errand_situation.json"])
	check_eq("stress kept", int(GameState.alter_stress["iris"]), 50)
	check_eq("affinity kept", int(GameState.relationship_affinity["iris|rowan"]), 40)


func test_reset_task_clears_handoff_only() -> void:
	GameState.current_task_id = "t"
	GameState.assigned_alter_id = "iris"
	GameState.current_situation = "res://data/x.json"
	GameState.task_time_spent = 15
	GameState.set_flag("outcome_played")
	GameState.set_flag("day_event_done")
	GameState.completed_tasks.append("res://data/x.json")
	GameState.reset_task()
	check("handoff cleared", GameState.current_task_id == "" and GameState.assigned_alter_id == "")
	check("situation + reading time cleared", GameState.current_situation == "" and GameState.task_time_spent == 0)
	check("outcome_played flag erased", not GameState.has_flag("outcome_played"))
	check("other day flags survive", GameState.has_flag("day_event_done"))
	check_eq("completed tasks survive", GameState.completed_tasks.size(), 1)


func test_serialization_roundtrip() -> void:
	GameState.day = 3
	GameState.ending_alignment = 6
	GameState.set_flag("day_setup_done")
	GameState.ever_broke = true
	GameState.bonds_mended = 2
	GameState.earned_badges.append("mediator")
	GameState.record_memory("m_porch")
	GameState.record_fact("f_alters")
	GameState.seen_events.append("ev_quiet_morning")
	GameState.used_secondaries.append("res://data/errand_situation.json")
	GameState.discovered_triggers.append("deadlines")
	GameState.alter_stress["iris"] = 55
	GameState.relationship_affinity["iris|rowan"] = 35
	GameState.relationship_log.append({"pair": "iris & rowan", "from_status": "strained", "to_status": "healthy"})

	# JSON roundtrip mimics the save file: numbers come back as floats, arrays untyped.
	var json: String = JSON.stringify(GameState.to_dict())
	var parsed: Dictionary = JSON.parse_string(json)
	GameState.reset_run()
	GameState.from_dict(parsed)

	check_eq("day restored", GameState.day, 3)
	check_eq("alignment restored", GameState.ending_alignment, 6)
	check("flag restored", GameState.has_flag("day_setup_done"))
	check("ever_broke restored", GameState.ever_broke)
	check_eq("bonds_mended restored", GameState.bonds_mended, 2)
	check_eq("earned badges restored", GameState.earned_badges, ["mediator"])
	check_eq("memories restored", GameState.unlocked_memories, ["m_porch"])
	check_eq("facts restored", GameState.surfaced_facts, ["f_alters"])
	check_eq("seen events restored", GameState.seen_events, ["ev_quiet_morning"])
	check_eq("used secondaries restored", GameState.used_secondaries, ["res://data/errand_situation.json"])
	check_eq("triggers restored", GameState.discovered_triggers, ["deadlines"])
	check("stress restored as int", GameState.alter_stress["iris"] is int and int(GameState.alter_stress["iris"]) == 55)
	check("affinity restored as int", GameState.relationship_affinity["iris|rowan"] is int and int(GameState.relationship_affinity["iris|rowan"]) == 35)
	check_eq("relationship log restored", GameState.relationship_log.size(), 1)


func test_from_dict_defaults_on_missing_keys() -> void:
	GameState.from_dict({})
	check_eq("day defaults to 1", GameState.day, 1)
	check_eq("alignment defaults to 0", GameState.ending_alignment, 0)
	check("collections default empty", GameState.unlocked_memories.is_empty() and GameState.earned_badges.is_empty())
	check("ever_broke defaults false", not GameState.ever_broke)


func test_total_days_from_data() -> void:
	check_eq("five-day run", GameState.total_days(), 5)


func test_build_day_summary_shape() -> void:
	GameState.day = 2
	GameState.ending_alignment = 4
	GameState.record_memory("m_porch")
	var s: Dictionary = GameState.build_day_summary()
	check_eq("summary day", int(s.get("day", 0)), 2)
	check_eq("summary alignment", int(s.get("alignment", -1)), 4)
	check_eq("summary alignment max", int(s.get("alignment_max", 0)), GameState.ALIGNMENT_MAX)
	check_eq("summary memories", s.get("unlocked_memories"), ["m_porch"])
	check("summary carries time budget", int(s.get("time_total", 0)) > 0)
