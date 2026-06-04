class_name MemoryFragment
extends RefCounted
## A recovered piece of the protagonist's past — the mystery loop payoff.

var id: String = ""
var title: String = ""
var text: String = ""
var fragments: Array[String] = []   # the memory in ordered pieces, for the reassembly mini-game
var image: String = ""              # optional image path, for the jigsaw mini-game
var mystery_tag: String = ""


static func from_dict(mem_id: String, d: Dictionary) -> MemoryFragment:
	var m := MemoryFragment.new()
	m.id = mem_id
	m.title = d.get("title", "")
	m.text = d.get("text", "")
	for f in d.get("fragments", []):
		m.fragments.append(str(f))
	m.image = d.get("image", "")
	m.mystery_tag = d.get("mystery_tag", "")
	return m
