extends Node2D
## The Internal Mind view: the relationship graph (centre) plus the "Inner System"
## sidebar (left) for managing alters. The player resolves a strained bond (Talk),
## rests an overwhelmed alter (Rest), then assigns the best-suited alter (Send),
## handing control back to the External World.

const ALTER_NODE: PackedScene = preload("res://scenes/internal/alter_node.tscn")
const ALTER_CARD: PackedScene = preload("res://scenes/internal/alter_card.tscn")
const CONFLICT_PATH: String = "res://data/conflict_dialogue.json"
const TASKS_PATH: String = "res://data/tasks.json"
const EXTERNAL_SCENE: String = "res://scenes/external/external_world.tscn"
const TASK_BOARD_SCENE: String = "res://scenes/external/task_board.tscn"

const CONFLICT_TIME_COST: int = 20
const REST_TIME_COST: int = 20
const REST_RELIEF: int = 35          # partial — rest eases, it doesn't erase

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
var _task: Task                       # the task the player came in to handle (for card advice)


func _ready() -> void:
	_alter_mgr = AlterManager.new()
	_alter_mgr.load_data()
	_rel_mgr = RelationshipManager.new()
	_rel_mgr.load_data()
	_task = _load_current_task()

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


## Load the task the player came in to handle, so cards can advise skill/trigger fit.
func _load_current_task() -> Task:
	if GameState.current_task_id == "":
		return null
	var tasks: Dictionary = JsonLoader.load_dict(TASKS_PATH).get("tasks", {})
	if not tasks.has(GameState.current_task_id):
		return null
	return Task.from_dict(GameState.current_task_id, tasks[GameState.current_task_id])


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
	# No gate — anyone can be sent. Rest is offered when an alter is overwhelmed
	# (it eases stress but costs time); Talk mends a strained bond (optional, but
	# skipping it costs you at the outcome). The strategy is the tradeoff, not a lock.
	var req_skill: String = _task.required_skill if _task else ""
	var trigger: String = _task.trigger if _task else ""
	for id in _cards:
		var alter: Alter = _alter_mgr.get_alter(id)
		var strained: Relationship = _rel_mgr.first_strained_for(id)
		_cards[id].set_actions(strained != null, alter.is_stressed(), true)
		_cards[id].refresh_stats(alter)
		var band: Dictionary = Coping.band(alter, _task, _rel_mgr) if _task != null else {}
		_cards[id].set_task_context(req_skill, trigger, band)


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
	_alter_mgr.adjust_stress(alter_id, -REST_RELIEF)
	EventBus.alter_sent_to_rejuvenation.emit(alter_id)
	GameClock.spend(REST_TIME_COST)
	GameState.set_flag("rested")
	_update_cards()
	_update_objective()


# --- Assignment / handoff back ---

func _on_assign(alter_id: String) -> void:
	# No wall: you may send anyone. Sending an overwhelmed or ill-suited alter just
	# costs you at the outcome — that tradeoff is the point, not a forced rest.
	GameState.assigned_alter_id = alter_id
	EventBus.alter_assigned_to_task.emit(alter_id, GameState.current_task_id)
	EventBus.exit_mind_requested.emit(alter_id)
	SceneFlow.change_scene_to_file(EXTERNAL_SCENE)


# --- Guidance ---

func _update_objective() -> void:
	# Non-prescriptive: name the levers, not the move. The odds on each card are a
	# read, not a guarantee — and a part you haven't learned yet may still surprise you.
	EventBus.objective_changed.emit("Weigh each part — their strengths, their state, the odds shown. Rest eases stress and Talk mends a bond (both cost time), but there's rarely a risk-free choice.")
