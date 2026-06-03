class_name DialogueRunner
extends Node
## Walks a JSON-authored dialogue tree, rendering each node through a DialogueBox.
## Applies global effects (memory/fact/alignment/flags) itself; emits scene-specific
## effects (affinity changes) and custom actions (the enter_mind handoff) as signals
## for the host scene to handle.

signal finished(end_id: String)
signal consequence_applied(consequence: Dictionary)
signal action_triggered(action: String)

var _nodes: Dictionary = {}        # id -> DialogueNode
var _box: DialogueBox
var _current: DialogueNode


func setup(dialogue_data: Dictionary, box: DialogueBox) -> void:
	_box = box
	_nodes.clear()
	var raw: Dictionary = dialogue_data.get("nodes", {})
	for nid in raw:
		_nodes[nid] = DialogueNode.from_dict(nid, raw[nid])
	if not _box.advance_requested.is_connected(_on_advance):
		_box.advance_requested.connect(_on_advance)
	if not _box.choice_selected.is_connected(_on_choice):
		_box.choice_selected.connect(_on_choice)


func start(start_id: String) -> void:
	_goto(start_id)


## Override a node's speaker before it is shown — used when a coping roll reuses a
## tier branch authored for a different alter (the voice is whoever was sent).
func override_speaker(node_id: String, speaker: String) -> void:
	if _nodes.has(node_id):
		_nodes[node_id].speaker = speaker


func _goto(node_id: String) -> void:
	if not _nodes.has(node_id):
		# Terminal sentinel (e.g. END_DAY, END_CONFLICT) — let the host decide.
		finished.emit(node_id)
		return
	_current = _nodes[node_id]
	_apply_on_enter(_current.on_enter)
	_box.show_node(_current)


func _on_advance() -> void:
	if _current == null or _current.has_choices():
		return
	_goto(_current.next)


func _on_choice(index: int) -> void:
	if _current == null or index < 0 or index >= _current.choices.size():
		return
	var choice: Dictionary = _current.choices[index]
	if choice.has("action"):
		action_triggered.emit(choice["action"])
		return
	_apply_consequence(choice.get("consequence", {}))
	_goto(choice.get("next", ""))


## on_enter effects fire the moment a node is shown (global, idempotent-ish).
func _apply_on_enter(effects: Dictionary) -> void:
	if effects.is_empty():
		return
	if effects.has("align"):
		GameState.add_alignment(int(effects["align"]))
	if effects.has("set_flag"):
		GameState.set_flag(str(effects["set_flag"]))
	var mem: String = effects.get("unlock_memory", "")
	if mem != "":
		GameState.record_memory(mem)
		EventBus.memory_unlocked.emit(mem)
	var fact: String = effects.get("surface_fact", "")
	if fact != "":
		GameState.record_fact(fact)
		EventBus.did_fact_surfaced.emit(fact)


## Choice consequences: apply global parts here, hand affinity to the host scene.
func _apply_consequence(consequence: Dictionary) -> void:
	if consequence.is_empty():
		return
	if consequence.has("align"):
		GameState.add_alignment(int(consequence["align"]))
	if consequence.has("set_flag"):
		GameState.set_flag(str(consequence["set_flag"]))
	consequence_applied.emit(consequence)
