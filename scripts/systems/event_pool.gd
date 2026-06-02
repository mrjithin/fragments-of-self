class_name EventPool
extends RefCounted
## The randomness system's first cut: loads the event-of-the-day pool and rolls one
## weighted random, non-repeating event per day via RNG. Deterministic under the save
## seed, so playthroughs stay reproducible. Seen events are tracked in GameState.

const EVENTS_PATH: String = "res://data/events.json"

var events: Array[GameEvent] = []


func load_data() -> void:
	events.clear()
	for entry in JsonLoader.load_dict(EVENTS_PATH).get("events", []):
		events.append(GameEvent.from_dict(entry as Dictionary))


## Pick one event valid for `day` and not yet seen, weighted by RNG. Records it as seen
## and returns it, or null when the pool is exhausted for this day.
func roll(day: int) -> GameEvent:
	var pool: Array[GameEvent] = []
	for e in events:
		if e.available_on(day) and not GameState.seen_events.has(e.id):
			pool.append(e)
	if pool.is_empty():
		return null
	var weights: Array = []
	for e in pool:
		weights.append(e.weight)
	var idx: int = RNG.weighted_pick(weights)
	if idx < 0:
		return null
	var picked: GameEvent = pool[idx]
	GameState.seen_events.append(picked.id)
	return picked
