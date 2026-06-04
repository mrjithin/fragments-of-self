extends Node
## Awards achievements as the run earns them. Definitions live in data (condition-based,
## see data/achievements.json); this autoload re-evaluates them whenever progress changes
## and records newly-earned ones in GameState, emitting EventBus.achievement_unlocked.
## Read-only over GameState — it never drives gameplay, only recognises it.

const DEFS_PATH: String = "res://data/achievements.json"
const MEMORIES_PATH: String = "res://data/memories.json"
const FACTS_PATH: String = "res://data/did_facts.json"

var _defs: Array = []


func _ready() -> void:
	_defs = JsonLoader.load_dict(DEFS_PATH).get("achievements", [])
	# Any of these can move the needle, so re-check after each.
	EventBus.memory_unlocked.connect(func(_id): evaluate())
	EventBus.did_fact_surfaced.connect(func(_id): evaluate())
	EventBus.day_ended.connect(func(_s): evaluate())


## The full ordered list of definitions (for the Codex achievements tab).
func all_defs() -> Array:
	return _defs


## Check every definition against current state; award any newly-met ones.
func evaluate() -> void:
	for d in _defs:
		var def: Dictionary = d as Dictionary
		var id: String = str(def.get("id", ""))
		if id == "" or GameState.unlocked_achievements.has(id):
			continue
		if _met(def.get("condition", {})):
			GameState.unlocked_achievements.append(id)
			EventBus.achievement_unlocked.emit(id)


func _met(cond: Dictionary) -> bool:
	var kind: String = str(cond.get("kind", ""))
	var value: int = int(cond.get("value", 0))
	match kind:
		"memories_at_least":
			return GameState.unlocked_memories.size() >= value
		"memories_all":
			var total_mem: int = JsonLoader.load_dict(MEMORIES_PATH).get("memories", {}).size()
			return total_mem > 0 and GameState.unlocked_memories.size() >= total_mem
		"facts_at_least":
			return GameState.surfaced_facts.size() >= value
		"facts_all":
			var total_facts: int = JsonLoader.load_dict(FACTS_PATH).get("facts", {}).size()
			return total_facts > 0 and GameState.surfaced_facts.size() >= total_facts
		"trigger_discovered":
			return GameState.discovered_triggers.size() >= maxi(1, value)
		"alignment_at_least":
			return GameState.ending_alignment >= value
		"day_at_least":
			return GameState.day >= value
	return false
