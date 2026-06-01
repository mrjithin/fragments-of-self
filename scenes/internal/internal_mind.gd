extends Node2D
## The Internal Mind view: the alter graph and the strategy loop. The player resolves
## a strained bond (conflict dialogue), rests an overwhelmed alter (rejuvenation), then
## assigns the best-suited alter to the task — handing control back to the External World.

const ALTER_NODE: PackedScene = preload("res://scenes/internal/alter_node.tscn")
const CONFLICT_PATH: String = "res://data/conflict_dialogue.json"
const EXTERNAL_SCENE: String = "res://scenes/external/external_world.tscn"

const CONFLICT_TIME_COST: int = 20
const REST_TIME_COST: int = 15

const COLOR_HEALTHY: Color = Color(0.45, 0.62, 0.48, 0.75)
const COLOR_STRAINED: Color = Color(0.86, 0.62, 0.32, 0.9)
const COLOR_BROKEN: Color = Color(0.72, 0.36, 0.36, 0.9)

@onready var _alters_root: Node2D = $GraphContainer/Alters
@onready var _edges_root: Node2D = $GraphContainer/Edges
@onready var _inspector: PanelContainer = %AlterInspector
@onready var _insp_name: Label = %InspName
@onready var _insp_role: Label = %InspRole
@onready var _insp_stress: Label = %InspStress
@onready var _insp_skills: Label = %InspSkills
@onready var _talk_button: Button = %TalkButton
@onready var _rest_button: Button = %RestButton
@onready var _assign_button: Button = %AssignButton
@onready var _conflict_box: DialogueBox = %ConflictDialogue

var _alter_mgr: AlterManager
var _rel_mgr: RelationshipManager
var _alter_nodes: Dictionary = {}      # id -> alter_node instance
var _edges: Dictionary = {}            # "a|b" (sorted) -> Line2D
var _selected_id: String = ""
var _conflict_runner: DialogueRunner


func _ready() -> void:
	_alter_mgr = AlterManager.new()
	_alter_mgr.load_data()
	_rel_mgr = RelationshipManager.new()
	_rel_mgr.load_data()

	_build_edges()
	_build_alters()

	_inspector.visible = false
	_conflict_box.visible = false
	_assign_button.disabled = true

	EventBus.alter_selected.connect(_on_alter_selected)
	EventBus.relationship_changed.connect(_on_relationship_changed)
	EventBus.conflict_resolved.connect(_on_conflict_resolved)
	_talk_button.pressed.connect(_on_talk_pressed)
	_rest_button.pressed.connect(_on_rest_pressed)
	_assign_button.pressed.connect(_on_assign_pressed)

	_update_objective()


# --- Graph construction ---

func _build_alters() -> void:
	for id in _alter_mgr.order:
		var node: Node2D = ALTER_NODE.instantiate()
		_alters_root.add_child(node)
		node.setup(_alter_mgr.get_alter(id))
		_alter_nodes[id] = node


func _build_edges() -> void:
	for r in _rel_mgr.relationships:
		var a: Alter = _alter_mgr.get_alter(r.from_id) if _alter_mgr else null
		var b: Alter = _alter_mgr.get_alter(r.to_id) if _alter_mgr else null
		if a == null or b == null:
			continue
		var line := Line2D.new()
		line.width = 4.0
		line.points = PackedVector2Array([a.graph_pos, b.graph_pos])
		line.default_color = _status_color(r.status)
		line.z_index = -1
		_edges_root.add_child(line)
		_edges[_edge_key(r.from_id, r.to_id)] = line


func _edge_key(a: String, b: String) -> String:
	return "|".join([a, b]) if a < b else "|".join([b, a])


func _status_color(status: String) -> Color:
	match status:
		"broken": return COLOR_BROKEN
		"strained": return COLOR_STRAINED
		_: return COLOR_HEALTHY


# --- Input / picking ---
# Deterministic hit-testing (no reliance on 2D physics picking). GUI Controls in the
# UILayer consume their own clicks first; clicks on empty graph space reach here.

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


# --- Selection / inspector ---

func _on_alter_selected(alter_id: String) -> void:
	if _conflict_box.visible:
		return
	_selected_id = alter_id
	_refresh_inspector()


func _refresh_inspector() -> void:
	var a: Alter = _alter_mgr.get_alter(_selected_id)
	if a == null:
		_inspector.visible = false
		return
	_inspector.visible = true
	_insp_name.text = a.name
	_insp_role.text = a.role
	_insp_stress.text = "Stress: %d" % a.stress
	_insp_skills.text = "Skills: %s" % ", ".join(a.skills)

	var strained: Relationship = _rel_mgr.first_strained_for(_selected_id)
	_talk_button.visible = strained != null and not GameState.has_flag("conflict_resolved")
	if _talk_button.visible:
		var other_id: String = strained.to_id if strained.from_id == _selected_id else strained.from_id
		var other: Alter = _alter_mgr.get_alter(other_id)
		_talk_button.text = "Talk it out with %s" % (other.name if other else other_id)

	_rest_button.visible = a.is_stressed()
	_update_assign_state()


func _update_assign_state() -> void:
	var ready_to_assign: bool = GameState.has_flag("conflict_resolved") and GameState.has_flag("rested")
	var a: Alter = _alter_mgr.get_alter(_selected_id)
	_assign_button.disabled = not (ready_to_assign and a != null)
	if a != null and ready_to_assign:
		_assign_button.text = "Send %s to handle it  →" % a.name
	else:
		_assign_button.text = "Send them to handle it  →"


# --- Conflict resolution ---

func _on_talk_pressed() -> void:
	var data := JsonLoader.load_dict(CONFLICT_PATH)
	if _conflict_runner == null:
		_conflict_runner = DialogueRunner.new()
		add_child(_conflict_runner)
		_conflict_runner.consequence_applied.connect(_on_conflict_consequence)
		_conflict_runner.finished.connect(_on_conflict_finished)
	_conflict_runner.setup(data, _conflict_box)
	_inspector.visible = false
	_conflict_box.visible = true
	EventBus.objective_changed.emit("")
	_conflict_runner.start(data.get("start", ""))


func _on_conflict_consequence(consequence: Dictionary) -> void:
	if not consequence.has("affinity"):
		return
	var aff: Dictionary = consequence["affinity"]
	var pair: String = aff.get("pair", "")
	var delta: int = int(aff.get("delta", 0))
	var ids: PackedStringArray = pair.split(":")
	if ids.size() == 2:
		_rel_mgr.adjust(ids[0], ids[1], delta)


func _on_conflict_finished(_end_id: String) -> void:
	_conflict_box.visible = false
	_refresh_inspector()
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

func _on_rest_pressed() -> void:
	if _selected_id == "":
		return
	_alter_mgr.adjust_stress(_selected_id, -50)
	EventBus.alter_sent_to_rejuvenation.emit(_selected_id)
	GameClock.spend(REST_TIME_COST)
	GameState.set_flag("rested")
	_refresh_inspector()
	_update_objective()


# --- Assignment / handoff back ---

func _on_assign_pressed() -> void:
	if _assign_button.disabled or _selected_id == "":
		return
	GameState.assigned_alter_id = _selected_id
	EventBus.alter_assigned_to_task.emit(_selected_id, GameState.current_task_id)
	EventBus.exit_mind_requested.emit(_selected_id)
	SceneFlow.change_scene_to_file(EXTERNAL_SCENE)


# --- Guidance ---

func _update_objective() -> void:
	if not GameState.has_flag("conflict_resolved"):
		EventBus.objective_changed.emit("A bond glows amber. Select Iris or Rowan and help them talk it out.")
	elif not GameState.has_flag("rested"):
		EventBus.objective_changed.emit("Rowan is overwhelmed (high stress). Select Rowan and send them to rest.")
	else:
		EventBus.objective_changed.emit("Now choose who should face the interview — pick the calm one — and send them out.")
