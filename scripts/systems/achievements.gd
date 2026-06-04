class_name Achievements
extends RefCounted
## Run badges. Loads display text from data/achievements.json and evaluates each
## id's condition against GameState. Earned badges are STICKY: the first time a
## condition holds, the id is recorded in GameState.earned_badges (persisted with
## the save) and stays earned even if the underlying state later regresses —
## live values like alignment can drop, per-day logs are cleared, etc.
## `final` marks the end-of-run evaluation (the ending screen): whole-run badges
## ("reached the integration path", "no alter ever broke") are only judgeable
## there, so the mid-run Journal can't show them as earned in advance.

const DATA_PATH: String = "res://data/achievements.json"
const FACTS_PATH: String = "res://data/did_facts.json"
const CORE_MEMORIES: int = 4   # the run's mystery memories (treehouse, porch, kitchen, whole)


## All earned achievements as [{title, desc}], in the data file's order.
## Records newly-satisfied ids into GameState.earned_badges as a side effect.
static func earned(final: bool = false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var list: Array = JsonLoader.load_dict(DATA_PATH).get("achievements", [])
	for a in list:
		var entry: Dictionary = a as Dictionary
		var id: String = str(entry.get("id", ""))
		if GameState.earned_badges.has(id) or _check_and_record(id, final):
			out.append({"title": str(entry.get("title", "")), "desc": str(entry.get("desc", ""))})
	return out


## Evaluates the id's live condition; on success, records it so it stays earned.
static func _check_and_record(id: String, final: bool) -> bool:
	if not _condition_holds(id, final):
		return false
	GameState.earned_badges.append(id)
	return true


static func _condition_holds(id: String, final: bool) -> bool:
	match id:
		"integration":
			# "Reached the integration path" — a path is only reached at the end.
			var ratio: float = float(GameState.ending_alignment) / float(maxi(1, GameState.ALIGNMENT_MAX))
			return final and ratio >= 0.6
		"held_together":
			# "Made it through the run" — only judgeable once the run is done.
			return final and not GameState.ever_broke
		"whole_picture":
			return GameState.unlocked_memories.size() >= CORE_MEMORIES
		"aware":
			return GameState.surfaced_facts.size() >= _total_facts()
		"mediator":
			# relationship_log is per-day (cleared by advance_day for the summary);
			# the run-wide counter keeps the badge once it's earned.
			return GameState.bonds_mended > 0
	return false


static func _total_facts() -> int:
	var facts: Dictionary = JsonLoader.load_dict(FACTS_PATH).get("facts", {})
	return maxi(1, facts.size())
