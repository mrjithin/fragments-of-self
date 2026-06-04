extends TestCase
## The reproducibility spine: seeded RNG, the weighted event pool, the day clock,
## and SaveManager's versioned roundtrip. Save tests preserve and restore any real
## save file so running the suite never eats a player's progress.


func test_weighted_pick_edges() -> void:
	check_eq("empty list -> -1", RNG.weighted_pick([]), -1)
	check_eq("all-zero weights -> -1", RNG.weighted_pick([0, 0.0, 0]), -1)
	check_eq("negative weights treated as zero", RNG.weighted_pick([-3, -1]), -1)
	check_eq("single positive weight always picked", RNG.weighted_pick([5]), 0)


func test_weighted_pick_skips_zero() -> void:
	var ok: bool = true
	for i in 50:
		if RNG.weighted_pick([0, 1, 0]) != 1:
			ok = false
	check("zero-weight options never picked over 50 rolls", ok)


func test_rng_determinism() -> void:
	RNG.set_seed(123)
	var a: Array = [RNG.randf_unit(), RNG.randi_range_inclusive(1, 100), RNG.weighted_pick([1, 2, 3])]
	RNG.set_seed(123)
	var b: Array = [RNG.randf_unit(), RNG.randi_range_inclusive(1, 100), RNG.weighted_pick([1, 2, 3])]
	check_eq("identical sequence under the same seed", a, b)
	RNG.set_seed(456)
	var c: float = RNG.randf_unit()
	check("different seed diverges", not is_equal_approx(c, float(a[0])))


func test_event_pool_gating_and_no_repeat() -> void:
	var pool := EventPool.new()
	pool.load_data()
	check_eq("authored pool size", pool.events.size(), 4)
	var day1_ids: Array[String] = []
	for i in 2:
		var e: GameEvent = pool.roll(1)
		if e != null:
			day1_ids.append(e.id)
	check_eq("two events valid on day 1", day1_ids.size(), 2)
	check("later-gated events never rolled on day 1",
		not day1_ids.has("ev_calendar_date") and not day1_ids.has("ev_good_sleep"))
	check("exhausted pool yields null", pool.roll(1) == null)
	check_eq("seen events recorded", GameState.seen_events.size(), 2)
	var d3a: GameEvent = pool.roll(3)
	var d3b: GameEvent = pool.roll(3)
	check("day 3 unlocks the remaining two events", d3a != null and d3b != null)
	check("calendar event reachable by day 3", GameState.seen_events.has("ev_calendar_date"))


func test_event_pool_deterministic() -> void:
	var pool := EventPool.new()
	pool.load_data()
	RNG.set_seed(99)
	var a: GameEvent = pool.roll(1)
	GameState.seen_events.clear()
	RNG.set_seed(99)
	var b: GameEvent = pool.roll(1)
	check("same seed, same first event", a != null and b != null and a.id == b.id)


func test_game_clock() -> void:
	GameClock.reset_day(50)
	check("reset applies the custom budget", GameClock.budget_total == 50 and GameClock.budget_remaining == 50)
	GameClock.spend(20)
	check_eq("spend deducts", GameClock.budget_remaining, 30)
	GameClock.spend(999)
	check_eq("spend floors at 0", GameClock.budget_remaining, 0)
	GameClock.load_state(100, 250)
	check_eq("loaded remaining clamped to total", GameClock.budget_remaining, 100)
	GameClock.load_state(0, 10)
	check_eq("loaded total floored to 1", GameClock.budget_total, 1)


func test_save_roundtrip() -> void:
	var backup: String = _read_save()
	GameState.day = 3
	GameState.ending_alignment = 6
	GameState.bonds_mended = 1
	GameState.earned_badges.append("mediator")
	RNG.set_seed(777)
	GameClock.reset_day()
	GameClock.spend(40)
	check("save writes", SaveManager.save())
	check("save file exists", SaveManager.has_save())

	# Trash the live state, then restore from disk.
	GameState.reset_run()
	RNG.set_seed(RNG.DEFAULT_SEED)
	GameClock.reset_day()
	check("load succeeds", SaveManager.load())
	check_eq("day restored", GameState.day, 3)
	check_eq("alignment restored", GameState.ending_alignment, 6)
	check_eq("badges restored", GameState.earned_badges, ["mediator"])
	check_eq("seed restored", RNG.seed_value, 777)
	check_eq("clock restored", GameClock.budget_remaining, 60)
	_restore_save(backup)


func test_save_version_guard() -> void:
	var backup: String = _read_save()
	var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 999, "state": {"day": 4}}))
	f.close()
	GameState.day = 2
	check("future-version save rejected", not SaveManager.load())
	check_eq("state untouched on rejection", GameState.day, 2)
	_restore_save(backup)


func test_save_corrupt_guard() -> void:
	var backup: String = _read_save()
	var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string("not json {")
	f.close()
	check("corrupt save rejected", not SaveManager.load())
	_restore_save(backup)


func test_delete_save() -> void:
	var backup: String = _read_save()
	SaveManager.save()
	SaveManager.delete_save()
	check("deleted save is gone", not SaveManager.has_save())
	check("load on missing save fails cleanly", not SaveManager.load())
	_restore_save(backup)


# --- Save-file preservation helpers ---

func _read_save() -> String:
	if not FileAccess.file_exists(SaveManager.SAVE_PATH):
		return ""
	var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.READ)
	var text: String = f.get_as_text()
	f.close()
	return text


func _restore_save(backup: String) -> void:
	if backup == "":
		SaveManager.delete_save()
		return
	var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string(backup)
	f.close()
