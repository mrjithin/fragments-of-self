extends Node
## The single source of truth for the demo run. Lives in an autoload so it survives
## scene swaps between the External World and Internal Mind views.

const ALIGNMENT_MAX: int = 10

# Progression
var day: int = 1
var ending_alignment: int = 0          # nudged by choices; drives the day-end meter
var flags: Dictionary = {}             # arbitrary scripted flags, e.g. "conflict_resolved"

# Handoff state
var current_task_id: String = ""       # task the player went inward to handle
var assigned_alter_id: String = ""     # alter chosen in the mind to handle it

# Per-run deltas, captured for the day-end summary
var stress_before: Dictionary = {}     # alter_id -> int (snapshot when first seen)
var relationship_log: Array[Dictionary] = []   # [{pair, from_status, to_status}]
var unlocked_memories: Array[String] = []
var surfaced_facts: Array[String] = []


func reset_run() -> void:
	day = 1
	ending_alignment = 0
	flags.clear()
	current_task_id = ""
	assigned_alter_id = ""
	stress_before.clear()
	relationship_log.clear()
	unlocked_memories.clear()
	surfaced_facts.clear()


func set_flag(flag: String, value: bool = true) -> void:
	flags[flag] = value


func has_flag(flag: String) -> bool:
	return flags.get(flag, false)


func add_alignment(amount: int) -> void:
	ending_alignment = clampi(ending_alignment + amount, 0, ALIGNMENT_MAX)


func record_memory(memory_id: String) -> void:
	if memory_id != "" and not unlocked_memories.has(memory_id):
		unlocked_memories.append(memory_id)


func record_fact(fact_id: String) -> void:
	if fact_id != "" and not surfaced_facts.has(fact_id):
		surfaced_facts.append(fact_id)


## Assembled by the day-end screen. Pulls live values from the managers via the
## passed-in snapshots so this stays a pure data container.
func build_day_summary() -> Dictionary:
	return {
		"day": day,
		"time_spent": GameClock.budget_total - GameClock.budget_remaining,
		"time_total": GameClock.budget_total,
		"alignment": ending_alignment,
		"alignment_max": ALIGNMENT_MAX,
		"assigned_alter_id": assigned_alter_id,
		"relationship_log": relationship_log,
		"unlocked_memories": unlocked_memories,
		"surfaced_facts": surfaced_facts,
	}
