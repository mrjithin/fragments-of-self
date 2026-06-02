class_name RelationshipManager
extends RefCounted
## Loads alter↔alter bonds, derives status from affinity, and mends them via dialogue.
## Status changes route through EventBus so graph edges recolour live.

const RELATIONSHIPS_PATH: String = "res://data/relationships.json"

var relationships: Array[Relationship] = []
var thresholds: Dictionary = {"broken": 20, "strained": 50, "healthy": 100}


func load_data() -> void:
	relationships.clear()
	var data := JsonLoader.load_dict(RELATIONSHIPS_PATH)
	thresholds = data.get("status_thresholds", thresholds)
	for entry in data.get("relationships", []):
		var r := Relationship.from_dict(entry as Dictionary)
		# Restore live affinity carried in GameState (across scene swaps / saves);
		# otherwise seed it from the authored JSON value.
		var k := _pair_key(r.from_id, r.to_id)
		if GameState.relationship_affinity.has(k):
			r.affinity = int(GameState.relationship_affinity[k])
			r.status = status_for(r.affinity)
		else:
			GameState.relationship_affinity[k] = r.affinity
		relationships.append(r)


static func _pair_key(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]


func status_for(affinity: int) -> String:
	if affinity < int(thresholds.get("broken", 20)):
		return "broken"
	if affinity < int(thresholds.get("strained", 50)):
		return "strained"
	return "healthy"


func get_between(a: String, b: String) -> Relationship:
	for r in relationships:
		if r.matches_pair(a, b):
			return r
	return null


func first_strained_for(alter_id: String) -> Relationship:
	for r in relationships:
		if r.involves(alter_id) and r.status != "healthy":
			return r
	return null


## Apply an affinity delta to a pair, recompute status, and emit change signals.
func adjust(a: String, b: String, delta: int) -> void:
	var r: Relationship = get_between(a, b)
	if r == null:
		return
	var old_status: String = r.status
	r.affinity = clampi(r.affinity + delta, 0, 100)
	r.status = status_for(r.affinity)
	GameState.relationship_affinity[_pair_key(r.from_id, r.to_id)] = r.affinity
	EventBus.relationship_changed.emit(r.from_id, r.to_id, r.affinity)
	if old_status != "healthy" and r.status == "healthy":
		EventBus.conflict_resolved.emit(r.from_id, r.to_id, r.affinity)
		GameState.relationship_log.append({
			"pair": "%s & %s" % [r.from_id, r.to_id],
			"from_status": old_status,
			"to_status": r.status,
		})
