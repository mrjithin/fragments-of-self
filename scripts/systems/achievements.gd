class_name Achievements
extends RefCounted
## End-of-run badges. Loads display text from data/achievements.json and evaluates
## each id's condition against the final GameState. Returns the earned ones (title +
## desc) for the ending screen to show. Pure read of state — no side effects.

const DATA_PATH: String = "res://data/achievements.json"
const FACTS_PATH: String = "res://data/did_facts.json"
const CORE_MEMORIES: int = 4   # the run's mystery memories (treehouse, porch, kitchen, whole)


## All earned achievements as [{title, desc}], in the data file's order.
static func earned() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var list: Array = JsonLoader.load_dict(DATA_PATH).get("achievements", [])
	for a in list:
		var entry: Dictionary = a as Dictionary
		if _is_earned(str(entry.get("id", ""))):
			out.append({"title": str(entry.get("title", "")), "desc": str(entry.get("desc", ""))})
	return out


static func _is_earned(id: String) -> bool:
	match id:
		"integration":
			var ratio: float = float(GameState.ending_alignment) / float(maxi(1, GameState.ALIGNMENT_MAX))
			return ratio >= 0.6
		"held_together":
			return not GameState.ever_broke
		"whole_picture":
			return GameState.unlocked_memories.size() >= CORE_MEMORIES
		"aware":
			return GameState.surfaced_facts.size() >= _total_facts()
		"mediator":
			return GameState.relationship_log.size() > 0
	return false


static func _total_facts() -> int:
	var facts: Dictionary = JsonLoader.load_dict(FACTS_PATH).get("facts", {})
	return maxi(1, facts.size())
