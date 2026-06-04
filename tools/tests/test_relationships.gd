extends TestCase
## RelationshipManager: thresholds, lookups, penalties, adjust/mend mechanics,
## and the GameState write-through that keeps bonds alive across scene swaps.

var _mgr: RelationshipManager


func before_each() -> void:
	super()
	_mgr = RelationshipManager.new()
	_mgr.load_data()


func test_load_seeds_game_state() -> void:
	check_eq("all authored bonds loaded", _mgr.relationships.size(), 6)
	check_eq("affinity written through", int(GameState.relationship_affinity["iris|rowan"]), 25)


func test_load_restores_live_affinity_over_authored() -> void:
	GameState.relationship_affinity["iris|rowan"] = 70
	var mgr := RelationshipManager.new()
	mgr.load_data()
	var r: Relationship = mgr.get_between("iris", "rowan")
	check_eq("live affinity wins", r.affinity, 70)
	check_eq("status recomputed from live value", r.status, "healthy")


func test_status_thresholds() -> void:
	check_eq("19 is broken", _mgr.status_for(19), "broken")
	check_eq("20 is strained (boundary)", _mgr.status_for(20), "strained")
	check_eq("49 is strained", _mgr.status_for(49), "strained")
	check_eq("50 is healthy (boundary)", _mgr.status_for(50), "healthy")
	check_eq("0 is broken", _mgr.status_for(0), "broken")
	check_eq("100 is healthy", _mgr.status_for(100), "healthy")


func test_lookups() -> void:
	check("get_between order-insensitive",
		_mgr.get_between("rowan", "iris") == _mgr.get_between("iris", "rowan"))
	check("unknown pair is null", _mgr.get_between("iris", "ghost") == null)
	check("has_any_strained sees the authored strain", _mgr.has_any_strained())
	var s: Relationship = _mgr.first_strained_for("iris")
	check("first_strained_for finds iris|rowan", s != null and s.matches_pair("iris", "rowan"))
	check("june has no strained bond", _mgr.first_strained_for("june") == null)


func test_penalty_for() -> void:
	check_eq("strained bond costs -1", _mgr.penalty_for("iris"), -1)
	check_eq("all-healthy alter costs 0", _mgr.penalty_for("june"), 0)
	_mgr.adjust("iris", "rowan", -25)   # 25 -> 0: broken
	check_eq("broken bond costs -2", _mgr.penalty_for("iris"), -2)


func test_adjust_clamps_and_writes_through() -> void:
	_mgr.adjust("iris", "june", 999)
	check_eq("affinity capped at 100", _mgr.get_between("iris", "june").affinity, 100)
	_mgr.adjust("iris", "rowan", -999)
	check_eq("affinity floored at 0", _mgr.get_between("iris", "rowan").affinity, 0)
	check_eq("floor written to GameState", int(GameState.relationship_affinity["iris|rowan"]), 0)
	_mgr.adjust("iris", "ghost", 10)   # unknown pair: no crash, no change
	check("unknown pair adjust is a no-op", _mgr.get_between("iris", "rowan").affinity == 0)


func test_mend_records_and_signals() -> void:
	var resolved: Array = []
	var cb := func(a: String, b: String, _aff: int) -> void: resolved.append([a, b])
	EventBus.conflict_resolved.connect(cb)
	_mgr.adjust("iris", "rowan", 30)   # 25 -> 55: strained -> healthy
	EventBus.conflict_resolved.disconnect(cb)
	check_eq("bonds_mended incremented", GameState.bonds_mended, 1)
	check_eq("relationship_log entry added", GameState.relationship_log.size(), 1)
	check_eq("log captures the transition",
		str(GameState.relationship_log[0].get("from_status")), "strained")
	check_eq("conflict_resolved emitted once", resolved.size(), 1)


func test_partial_mend_does_not_count() -> void:
	_mgr.adjust("iris", "rowan", 10)   # 25 -> 35: still strained
	check_eq("no mend recorded while still strained", GameState.bonds_mended, 0)
	check("no log entry", GameState.relationship_log.is_empty())


func test_healthy_gain_is_not_a_mend() -> void:
	_mgr.adjust("iris", "june", 10)    # 80 -> 90: healthy -> healthy
	check_eq("healthy->healthy not counted", GameState.bonds_mended, 0)


func test_broken_to_healthy_counts_once() -> void:
	_mgr.adjust("iris", "rowan", -25)  # 25 -> 0: broken
	_mgr.adjust("iris", "rowan", 60)   # 0 -> 60: broken -> healthy in one step
	check_eq("broken->healthy is one mend", GameState.bonds_mended, 1)
	check_eq("log records broken origin",
		str(GameState.relationship_log[0].get("from_status")), "broken")


func test_relationship_changed_emitted_on_every_adjust() -> void:
	var changes: Array = []
	var cb := func(_a: String, _b: String, aff: int) -> void: changes.append(aff)
	EventBus.relationship_changed.connect(cb)
	_mgr.adjust("iris", "rowan", 5)
	_mgr.adjust("iris", "rowan", -5)
	EventBus.relationship_changed.disconnect(cb)
	check_eq("two adjusts, two signals", changes.size(), 2)
	check_eq("signal carries new affinity", changes, [30, 25])
