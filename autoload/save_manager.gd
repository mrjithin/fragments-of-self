extends Node
## Persistence. Serializes the run's single source of truth (GameState) plus the
## RNG seed to a versioned JSON file, so a playthrough can be resumed and stays
## reproducible. Matches the public API described in ARCHITECTURE.md.

const SAVE_PATH: String = "user://fragments_save.json"
const SAVE_VERSION: int = 1


func save() -> bool:
	var data := {
		"version": SAVE_VERSION,
		"rng_seed": RNG.seed_value,
		"state": GameState.to_dict(),
		"clock": {
			"total": GameClock.budget_total,
			"remaining": GameClock.budget_remaining,
		},
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager.save(): cannot open %s (err %d)" % [SAVE_PATH, FileAccess.get_open_error()])
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true


func load() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_error("SaveManager.load(): cannot open %s (err %d)" % [SAVE_PATH, FileAccess.get_open_error()])
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		push_error("SaveManager.load(): invalid save data")
		return false
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != SAVE_VERSION:
		push_warning("SaveManager.load(): unexpected save version, ignoring save")
		return false
	RNG.set_seed(int(data.get("rng_seed", RNG.DEFAULT_SEED)))
	GameState.from_dict(data.get("state", {}))
	var clock: Dictionary = data.get("clock", {})
	GameClock.load_state(
		int(clock.get("total", GameClock.DEFAULT_BUDGET)),
		int(clock.get("remaining", GameClock.DEFAULT_BUDGET)))
	return true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
