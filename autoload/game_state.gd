extends Node
## The single source of truth for the demo run. Lives in an autoload so it survives
## scene swaps between the External World and Internal Mind views.

const ALIGNMENT_MAX: int = 10
const DAYS_PATH: String = "res://data/days.json"

# Progression
var day: int = 1
var _total_days_cache: int = 0         # lazily filled from days.json
var ending_alignment: int = 0          # nudged by choices; drives the day-end meter
var flags: Dictionary = {}             # arbitrary scripted flags, e.g. "conflict_resolved"

# Handoff state
var current_task_id: String = ""       # task the player went inward to handle
var assigned_alter_id: String = ""     # alter chosen in the mind to handle it
var current_scene: String = ""         # last gameplay scene, for resume-on-Continue
var last_outcome_penalty: int = 0      # alignment lost to a strained assigned alter (per day)
var current_situation: String = ""     # situation chosen from the task board
var task_time_spent: int = 0           # reading time already charged for the current task (persists across the mind round-trip)
var completed_tasks: Array[String] = [] # situation paths finished today
var day_tasks: Array[String] = []      # the situations actually offered today (main + randomly-drawn secondaries); resolved once per day
var used_secondaries: Array[String] = [] # secondary-pool situations already drawn this run (keeps days varied, non-repeating)
var ever_broke: bool = false           # did any alter hit a breaking point this run (drives the "Held Together" achievement)
var current_event_text: String = ""    # the day's rolled random event line (shown on board)

# Live mutable system state. Centralised here (the documented single source of truth)
# so it survives the External↔Internal scene swaps and can be serialized for saves.
# The managers seed these on first load and write through on every change.
var alter_stress: Dictionary = {}          # alter_id -> int
var relationship_affinity: Dictionary = {} # "a|b" (sorted) -> int

# Per-run deltas, captured for the day-end summary
var stress_before: Dictionary = {}     # alter_id -> int (snapshot when first seen)
var relationship_log: Array[Dictionary] = []   # [{pair, from_status, to_status}]
var unlocked_memories: Array[String] = []
var surfaced_facts: Array[String] = []
var seen_events: Array[String] = []    # random events already rolled (no-repeat, persists)
var discovered_triggers: Array[String] = [] # triggers learned by hitting them (revealed on cards)
var unlocked_achievements: Array[String] = [] # achievement ids earned this run


func reset_run() -> void:
	day = 1
	ending_alignment = 0
	flags.clear()
	current_task_id = ""
	assigned_alter_id = ""
	current_scene = ""
	last_outcome_penalty = 0
	current_situation = ""
	task_time_spent = 0
	current_event_text = ""
	completed_tasks.clear()
	day_tasks.clear()
	used_secondaries.clear()
	ever_broke = false
	alter_stress.clear()
	relationship_affinity.clear()
	stress_before.clear()
	relationship_log.clear()
	unlocked_memories.clear()
	surfaced_facts.clear()
	seen_events.clear()
	discovered_triggers.clear()
	unlocked_achievements.clear()


## Total days in the run (from days.json, cached). Lets the HUD show "Day N of M".
func total_days() -> int:
	if _total_days_cache <= 0:
		var days: Array = JsonLoader.load_dict(DAYS_PATH).get("days", [])
		_total_days_cache = maxi(1, days.size())
	return _total_days_cache


## Move to the next day: bump the counter and clear per-day state, while keeping
## cumulative progress (alignment, mystery, and live alter/relationship state).
func advance_day() -> void:
	day += 1
	flags.clear()
	current_task_id = ""
	assigned_alter_id = ""
	last_outcome_penalty = 0
	current_situation = ""
	task_time_spent = 0
	current_event_text = ""
	completed_tasks.clear()
	day_tasks.clear()
	relationship_log.clear()
	stress_before.clear()


## Clears per-task handoff state between tasks in the same day, while keeping the
## day's live alter/relationship state and its list of completed tasks.
func reset_task() -> void:
	assigned_alter_id = ""
	current_task_id = ""
	current_situation = ""
	task_time_spent = 0
	flags.erase("outcome_played")


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


## --- Serialization (used by SaveManager) ---

func to_dict() -> Dictionary:
	return {
		"day": day,
		"ending_alignment": ending_alignment,
		"flags": flags,
		"current_task_id": current_task_id,
		"assigned_alter_id": assigned_alter_id,
		"current_scene": current_scene,
		"last_outcome_penalty": last_outcome_penalty,
		"current_situation": current_situation,
		"current_event_text": current_event_text,
		"completed_tasks": completed_tasks,
		"day_tasks": day_tasks,
		"used_secondaries": used_secondaries,
		"ever_broke": ever_broke,
		"alter_stress": alter_stress,
		"relationship_affinity": relationship_affinity,
		"stress_before": stress_before,
		"relationship_log": relationship_log,
		"unlocked_memories": unlocked_memories,
		"surfaced_facts": surfaced_facts,
		"seen_events": seen_events,
		"discovered_triggers": discovered_triggers,
		"unlocked_achievements": unlocked_achievements,
	}


## Restores from a parsed save dict, rebuilding typed containers so the static
## types hold (JSON gives untyped Array/Dictionary with float numbers).
func from_dict(d: Dictionary) -> void:
	day = int(d.get("day", 1))
	ending_alignment = int(d.get("ending_alignment", 0))
	current_task_id = str(d.get("current_task_id", ""))
	assigned_alter_id = str(d.get("assigned_alter_id", ""))
	current_scene = str(d.get("current_scene", ""))
	last_outcome_penalty = int(d.get("last_outcome_penalty", 0))
	current_situation = str(d.get("current_situation", ""))
	current_event_text = str(d.get("current_event_text", ""))

	ever_broke = bool(d.get("ever_broke", false))

	completed_tasks.clear()
	for p in d.get("completed_tasks", []):
		completed_tasks.append(str(p))

	day_tasks.clear()
	for p in d.get("day_tasks", []):
		day_tasks.append(str(p))

	used_secondaries.clear()
	for p in d.get("used_secondaries", []):
		used_secondaries.append(str(p))

	flags.clear()
	for k in d.get("flags", {}):
		flags[k] = bool(d["flags"][k])

	alter_stress = _to_int_dict(d.get("alter_stress", {}))
	relationship_affinity = _to_int_dict(d.get("relationship_affinity", {}))
	stress_before = _to_int_dict(d.get("stress_before", {}))

	relationship_log.clear()
	for e in d.get("relationship_log", []):
		relationship_log.append(e as Dictionary)

	unlocked_memories.clear()
	for m in d.get("unlocked_memories", []):
		unlocked_memories.append(str(m))

	surfaced_facts.clear()
	for f in d.get("surfaced_facts", []):
		surfaced_facts.append(str(f))

	seen_events.clear()
	for ev in d.get("seen_events", []):
		seen_events.append(str(ev))

	discovered_triggers.clear()
	for tg in d.get("discovered_triggers", []):
		discovered_triggers.append(str(tg))

	unlocked_achievements.clear()
	for ach in d.get("unlocked_achievements", []):
		unlocked_achievements.append(str(ach))


func _to_int_dict(src: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in src:
		out[k] = int(src[k])
	return out


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
