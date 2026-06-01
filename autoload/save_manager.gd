extends Node
## Persistence. STUBBED for the pitch demo — a guided one-day slice never reloads —
## but the public API is here so the architecture matches ARCHITECTURE.md and real
## serialization can drop in later without touching callers.

const SAVE_PATH: String = "user://fragments_save.json"


func save() -> bool:
	# TODO: serialize GameState + per-system data (incl. RNG.seed_value) to SAVE_PATH.
	push_warning("SaveManager.save() is a demo stub — no data written.")
	return false


func load() -> bool:
	# TODO: deserialize and restore GameState + systems.
	push_warning("SaveManager.load() is a demo stub — nothing restored.")
	return false


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
