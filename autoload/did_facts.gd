extends Node
## The information loop: surfaces context-appropriate, real-world DID facts.
## Facts are data-driven from data/did_facts.json.

const FACTS_PATH: String = "res://data/did_facts.json"

var _facts: Dictionary = {}   # id -> {title, text}


func _ready() -> void:
	var data := JsonLoader.load_dict(FACTS_PATH)
	_facts = data.get("facts", {})


func get_fact(fact_id: String) -> Dictionary:
	return _facts.get(fact_id, {})


func has_fact(fact_id: String) -> bool:
	return _facts.has(fact_id)
