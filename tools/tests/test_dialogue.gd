extends TestCase
## DialogueRunner's global effects: on_enter (alignment, flags, memory, fact)
## and choice consequences. Exercised directly — no DialogueBox needed.


func _runner() -> DialogueRunner:
	var r := DialogueRunner.new()
	add_child(r)
	return r


func test_on_enter_align_and_flag() -> void:
	var r := _runner()
	r._apply_on_enter({"align": 2, "set_flag": "met_friend"})
	check_eq("alignment applied", GameState.ending_alignment, 2)
	check("flag set", GameState.has_flag("met_friend"))
	r._apply_on_enter({"align": -99})
	check_eq("alignment clamps at 0", GameState.ending_alignment, 0)
	r.queue_free()


func test_on_enter_empty_is_noop() -> void:
	var r := _runner()
	r._apply_on_enter({})
	check_eq("no effects, no change", GameState.ending_alignment, 0)
	r.queue_free()


func test_unlock_memory_records_and_emits() -> void:
	var r := _runner()
	var unlocked: Array = []
	var cb := func(id: String) -> void: unlocked.append(id)
	EventBus.memory_unlocked.connect(cb)
	r._apply_on_enter({"unlock_memory": "m_porch"})
	EventBus.memory_unlocked.disconnect(cb)
	check_eq("memory recorded", GameState.unlocked_memories, ["m_porch"])
	check_eq("memory_unlocked emitted", unlocked, ["m_porch"])
	r.queue_free()


func test_surface_fact_once_only() -> void:
	var r := _runner()
	var surfaced: Array = []
	var cb := func(id: String) -> void: surfaced.append(id)
	EventBus.did_fact_surfaced.connect(cb)
	r._apply_on_enter({"surface_fact": "f_alters"})
	r._apply_on_enter({"surface_fact": "f_alters"})   # same fact on a later node
	r._apply_on_enter({"surface_fact": "f_switching"})
	EventBus.did_fact_surfaced.disconnect(cb)
	check_eq("each fact recorded once", GameState.surfaced_facts, ["f_alters", "f_switching"])
	check_eq("popup emitted once per fact", surfaced, ["f_alters", "f_switching"])
	r.queue_free()


func test_surface_fact_respects_prior_runs() -> void:
	GameState.record_fact("f_alters")   # learned earlier in the run
	var r := _runner()
	var surfaced: Array = []
	var cb := func(id: String) -> void: surfaced.append(id)
	EventBus.did_fact_surfaced.connect(cb)
	r._apply_on_enter({"surface_fact": "f_alters"})
	EventBus.did_fact_surfaced.disconnect(cb)
	check("already-known fact never re-pops", surfaced.is_empty())
	r.queue_free()


func test_consequence_applies_and_emits() -> void:
	var r := _runner()
	var seen: Array = []
	r.consequence_applied.connect(func(c: Dictionary) -> void: seen.append(c))
	r._apply_consequence({"align": 1, "set_flag": "chose_kind", "affinity": {"pair": ["iris", "rowan"], "delta": 10}})
	check_eq("alignment applied", GameState.ending_alignment, 1)
	check("flag set", GameState.has_flag("chose_kind"))
	check_eq("full consequence handed to host scene", seen.size(), 1)
	check("affinity payload passed through untouched", seen[0].has("affinity"))
	r._apply_consequence({})
	check_eq("empty consequence not emitted", seen.size(), 1)
	r.queue_free()
