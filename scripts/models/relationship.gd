class_name Relationship
extends RefCounted
## A bond between two alters. Affinity drives a status (broken/strained/healthy)
## which colours the graph edge and affects external-world function.

var from_id: String = ""
var to_id: String = ""
var affinity: int = 0
var status: String = "healthy"


static func from_dict(d: Dictionary) -> Relationship:
	var r := Relationship.new()
	r.from_id = d.get("from", "")
	r.to_id = d.get("to", "")
	r.affinity = int(d.get("affinity", 0))
	r.status = d.get("status", "healthy")
	return r


func involves(alter_id: String) -> bool:
	return from_id == alter_id or to_id == alter_id


func key() -> String:
	return "%s:%s" % [from_id, to_id]


## True if this relationship connects the given (unordered) pair.
func matches_pair(a: String, b: String) -> bool:
	return (from_id == a and to_id == b) or (from_id == b and to_id == a)
