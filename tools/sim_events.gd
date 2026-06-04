extends Node
## Headless check of the randomness / event-of-the-day system: weighted picking,
## day-gating, no-repeat, and determinism under the RNG seed.
## Run: godot --headless res://tools/sim_events.tscn

var _fail: int = 0


func _check(label: String, ok: bool) -> void:
	print(("PASS: " if ok else "FAIL: "), label)
	if not ok:
		_fail += 1


func _ready() -> void:
	print("=== sim_events: randomness system ===")

	# Weighted pick: zero-weight options never chosen; empty -> -1.
	_check("weighted_pick skips zero weight", RNG.weighted_pick([0, 1, 0]) == 1)
	_check("weighted_pick empty -> -1", RNG.weighted_pick([]) == -1)

	var pool := EventPool.new()
	pool.load_data()
	_check("event pool loaded", pool.events.size() == 4)

	# Day gating: day-3-only event is never rolled on day 1.
	GameState.reset_run()
	RNG.set_seed(RNG.DEFAULT_SEED)
	var seen_day1: Array[String] = []
	for i in 3:                                  # 3 events valid on day 1
		var e: GameEvent = pool.roll(1)
		if e != null:
			seen_day1.append(e.id)
	_check("day 1 rolls only min_day<=1 events", not seen_day1.has("ev_calendar_date"))
	_check("no-repeat exhausts the day-1 pool", pool.roll(1) == null)
	_check("rolled events recorded as seen", GameState.seen_events.size() == seen_day1.size())

	# Determinism: same seed + same state -> same first pick.
	GameState.reset_run()
	RNG.set_seed(RNG.DEFAULT_SEED)
	var a: GameEvent = pool.roll(1)
	GameState.reset_run()
	RNG.set_seed(RNG.DEFAULT_SEED)
	var b: GameEvent = pool.roll(1)
	_check("deterministic under the seed", a != null and b != null and a.id == b.id)

	# Day-3 event becomes available later.
	GameState.reset_run()
	var day3_ids: Array[String] = []
	for i in 4:
		var e3: GameEvent = pool.roll(3)
		if e3 != null:
			day3_ids.append(e3.id)
	_check("day 3 can roll the calendar-date event", day3_ids.has("ev_calendar_date"))

	# Events are flavor only — rolling one never surfaces a DID fact.
	GameState.reset_run()
	RNG.set_seed(RNG.DEFAULT_SEED)
	var ev: GameEvent = pool.roll(1)
	_check("rolling an event surfaces no fact", ev != null and GameState.surfaced_facts.is_empty())

	print("=== sim_events done, failures: %d ===" % _fail)
	get_tree().quit()
