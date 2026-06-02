extends Node2D
## The Internal Mind view: the relationship graph (centre) plus the "Inner System"
## sidebar (left) for managing alters. The player resolves a strained bond (Talk),
## rests an overwhelmed alter (Rest), then assigns the best-suited alter (Send),
## handing control back to the External World.

const ALTER_NODE: PackedScene = preload("res://scenes/internal/alter_node.tscn")
const ALTER_CARD: PackedScene = preload("res://scenes/internal/alter_card.tscn")
const CONFLICT_PATH: String = "res://data/conflict_dialogue.json"
const EXTERNAL_SCENE: String = "res://scenes/external/external_world.tscn"
const TASK_BOARD_SCENE: String = "res://scenes/external/task_board.tscn"

const CONFLICT_TIME_COST: int = 20
const REST_TIME_COST: int = 15

const COLOR_HEALTHY: Color = Color(0.45, 0.62, 0.48, 0.75)
const COLOR_STRAINED: Color = Color(0.86, 0.62, 0.32, 0.9)
const COLOR_BROKEN: Color = Color(0.72, 0.36, 0.36, 0.9)

@onready var _alters_root: Node2D = $GraphContainer/Alters
@onready var _edges_root: Node2D = $GraphContainer/Edges
@onready var _card_list: VBoxContainer = %CardList
@onready var _conflict_box: DialogueBox = %ConflictDialogue

var _alter_mgr: AlterManager
var _rel_mgr: RelationshipManager
var _alter_nodes: Dictionary = {}     # id -> alter_node instance
var _cards: Dictionary = {}           # id -> AlterCard
var _edges: Dictionary = {}           # "a|b" (sorted) -> Line2D
var _selected_id: String = ""
var _conflict_runner: DialogueRunner


func _ready() -> void:
	_alter_mgr = AlterManager.new()
	_alter_mgr.load_data()
	_rel_mgr = RelationshipManager.new()
	_rel_mgr.load_data()

	_build_edges()
	_build_alters()
	_build_cards()

	_conflict_box.visible = false

	EventBus.alter_selected.connect(_on_alter_selected)
	EventBus.relationship_changed.connect(_on_relationship_changed)
	EventBus.conflict_resolved.connect(_on_conflict_resolved)

	_update_cards()
	_update_objective()

	# Autosave on entering this view so the run can be resumed from the title.
	# Anchor the resume point to the day's task board (the durable hub) rather than
	# this transient mid-handoff view — see external_world.gd for the rationale.
	GameState.current_scene = TASK_BOARD_SCENE
	SaveManager.save()


# --- Graph construction ---

func _build_alters() -> void:
	for id in _alter_mgr.order:
		var node: Node2D = ALTER_NODE.instantiate()
		_alters_root.add_child(node)
		node.setup(_alter_mgr.get_alter(id))
		_alter_nodes[id] = node


func _build_edges() -> void:
	for r in _rel_mgr.relationships:
		var a: Alter = _alter_mgr.get_alter(r.from_id)
		var b: Alter = _alter_mgr.get_alter(r.to_id)
		if a == null or b == null:
			continue
		var line := Line2D.new()
		line.width = 4.0
		line.points = PackedVector2Array([a.graph_pos, b.graph_pos])
		line.default_color = _status_color(r.status)
		line.z_index = -1
		_edges_root.add_child(line)
		_edges[_edge_key(r.from_id, r.to_id)] = line


func _build_cards() -> void:
	for id in _alter_mgr.order:
		var card: AlterCard = ALTER_CARD.instantiate()
		_card_list.add_child(card)
		card.setup(_alter_mgr.get_alter(id))
		card.selected.connect(func(aid: String) -> void: EventBus.alter_selected.emit(aid))
		card.talk_pressed.connect(_on_talk)
		card.rest_pressed.connect(_on_rest)
		card.assign_pressed.connect(_on_assign)
		_cards[id] = card


func _edge_key(a: String, b: String) -> String:
	return "|".join([a, b]) if a < b else "|".join([b, a])


func _status_color(status: String) -> Color:
	match status:
		"broken": return COLOR_BROKEN
		"strained": return COLOR_STRAINED
		_: return COLOR_HEALTHY


# --- Input / picking (graph node selection; cards select via their own click) ---

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _conflict_box.visible:
			return
		var local: Vector2 = _alters_root.to_local(get_global_mouse_position())
		for id in _alter_nodes:
			var node: Node2D = _alter_nodes[id]
			if node.contains_point(local):
				EventBus.alter_selected.emit(id)
				return


func _on_alter_selected(alter_id: String) -> void:
	if _conflict_box.visible:
		return
	_selected_id = alter_id
	for cid in _cards:
		_cards[cid].set_selected(cid == alter_id)


# --- Card state ---

func _update_cards() -> void:
	# Gate: you must calm any overwhelmed alter before sending anyone. Mending a
	# strained bond is optional — but skipping it costs you at the outcome (penalty).
	var ready_to_assign: bool = not _alter_mgr.any_stressed()
	for id in _cards:
		var alter: Alter = _alter_mgr.get_alter(id)
		var strained: Relationship = _rel_mgr.first_strained_for(id)
		_cards[id].set_actions(strained != null, alter.is_stressed(), ready_to_assign)
		_cards[id].refresh_stats(alter)


# --- Conflict resolution ---

func _on_talk(_alter_id: String) -> void:
	var data := JsonLoader.load_dict(CONFLICT_PATH)
	if _conflict_runner == null:
		_conflict_runner = DialogueRunner.new()
		add_child(_conflict_runner)
		_conflict_runner.consequence_applied.connect(_on_conflict_consequence)
		_conflict_runner.finished.connect(_on_conflict_finished)
	_conflict_runner.setup(data, _conflict_box)
	_conflict_box.visible = true
	EventBus.objective_changed.emit("")
	_conflict_runner.start(data.get("start", ""))


func _on_conflict_consequence(consequence: Dictionary) -> void:
	if not consequence.has("affinity"):
		return
	var aff: Dictionary = consequence["affinity"]
	var ids: PackedStringArray = String(aff.get("pair", "")).split(":")
	if ids.size() == 2:
		_rel_mgr.adjust(ids[0], ids[1], int(aff.get("delta", 0)))


func _on_conflict_finished(_end_id: String) -> void:
	_conflict_box.visible = false
	_update_cards()
	_update_objective()


func _on_relationship_changed(a: String, b: String, affinity: int) -> void:
	var line: Line2D = _edges.get(_edge_key(a, b), null)
	if line == null:
		return
	var target: Color = _status_color(_rel_mgr.status_for(affinity))
	var tween := create_tween()
	tween.tween_property(line, "default_color", target, 0.5)


func _on_conflict_resolved(_a: String, _b: String, _affinity: int) -> void:
	GameState.set_flag("conflict_resolved")
	GameClock.spend(CONFLICT_TIME_COST)


# --- Rejuvenation ---

func _on_rest(alter_id: String) -> void:
	_alter_mgr.adjust_stress(alter_id, -50)
	EventBus.alter_sent_to_rejuvenation.emit(alter_id)
	GameClock.spend(REST_TIME_COST)
	GameState.set_flag("rested")
	_update_cards()
	_update_objective()


# --- Assignment / handoff back ---

func _on_assign(alter_id: String) -> void:
	if _alter_mgr.any_stressed():
		return
	GameState.assigned_alter_id = alter_id
	EventBus.alter_assigned_to_task.emit(alter_id, GameState.current_task_id)
	EventBus.exit_mind_requested.emit(alter_id)
	SceneFlow.change_scene_to_file(EXTERNAL_SCENE)


# --- Guidance ---

func _update_objective() -> void:
	var stressed: Alter = _alter_mgr.first_stressed()
	if stressed != null:
		EventBus.objective_changed.emit("%s is overwhelmed — press Rest before anyone faces the day." % stressed.name)
	elif _rel_mgr.has_any_strained():
		EventBus.objective_changed.emit("A bond is strained (amber edge). Mend it with Talk for a better outcome — or Send anyway.")
	else:
		EventBus.objective_changed.emit("Press Send on whoever should face the task — play to their strengths.")
