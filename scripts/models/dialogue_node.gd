class_name DialogueNode
extends RefCounted
## One node in a branching dialogue. Covers both story and conflict dialogue.
## Authored as JSON; hydrated via from_dict().

var id: String = ""
var speaker: String = ""
var text: String = ""
var next: String = ""                       # linear follow-up (empty if this node branches)
var choices: Array[Dictionary] = []          # [{text, next, action, consequence}]
var on_enter: Dictionary = {}                # effects fired when shown, e.g. {unlock_memory, surface_fact, align}


static func from_dict(node_id: String, d: Dictionary) -> DialogueNode:
	var n := DialogueNode.new()
	n.id = node_id
	n.speaker = d.get("speaker", "")
	n.text = d.get("text", "")
	n.next = d.get("next", "")
	n.on_enter = d.get("on_enter", {})
	for c in d.get("choices", []):
		n.choices.append(c as Dictionary)
	return n


func has_choices() -> bool:
	return not choices.is_empty()
