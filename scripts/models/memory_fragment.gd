class_name MemoryFragment
extends RefCounted
## A recovered piece of the protagonist's past — the mystery loop payoff.

var id: String = ""
var title: String = ""
var text: String = ""
var mystery_tag: String = ""


static func from_dict(mem_id: String, d: Dictionary) -> MemoryFragment:
	var m := MemoryFragment.new()
	m.id = mem_id
	m.title = d.get("title", "")
	m.text = d.get("text", "")
	m.mystery_tag = d.get("mystery_tag", "")
	return m
