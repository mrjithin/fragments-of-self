extends Node2D
## A single alter on the mind graph. Drawn procedurally (no art needed): a soft halo
## whose colour/pulse reflects stress, a coloured portrait disc, name + role labels.

const PORTRAIT_SIZE: float = 56.0
const HALO_RADIUS: float = 52.0
const CALM_COLOR: Color = Color(0.43, 0.6, 0.48)      # soft green
const STRESS_COLOR: Color = Color(0.85, 0.5, 0.32)    # warm amber
const PORTRAIT_PATH: String = "res://assets/art/portrait_%s.png"

@onready var _name_label: Label = $NameLabel
@onready var _role_label: Label = $RoleLabel

var alter_id: String = ""
var _alter: Alter
var _portrait: Texture2D
var _selected: bool = false
var _pulse: float = 0.0
var _pulse_tween: Tween


func setup(alter: Alter) -> void:
	_alter = alter
	alter_id = alter.id
	position = alter.graph_pos
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait = load(PORTRAIT_PATH % alter.id)
	_name_label.text = alter.name
	_role_label.text = alter.role
	EventBus.alter_stress_changed.connect(_on_stress_changed)
	EventBus.alter_selected.connect(_on_any_selected)
	_refresh_pulse()
	queue_redraw()


## Local-space hit test (mouse already converted to this node's parent space).
func contains_point(local_point: Vector2) -> bool:
	return local_point.distance_to(position) <= HALO_RADIUS


func set_selected(value: bool) -> void:
	_selected = value
	queue_redraw()


func _on_any_selected(selected_id: String) -> void:
	set_selected(selected_id == alter_id)


func _on_stress_changed(changed_id: String, _stress: int) -> void:
	if changed_id == alter_id:
		_refresh_pulse()
		queue_redraw()


func _refresh_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_running():
		_pulse_tween.kill()
	if _alter != null and _alter.is_stressed():
		_pulse_tween = create_tween().set_loops()
		_pulse_tween.tween_method(_set_pulse, 0.0, 1.0, 0.9).set_trans(Tween.TRANS_SINE)
		_pulse_tween.tween_method(_set_pulse, 1.0, 0.0, 0.9).set_trans(Tween.TRANS_SINE)
	else:
		_set_pulse(0.0)


func _set_pulse(value: float) -> void:
	_pulse = value
	queue_redraw()


func _draw() -> void:
	if _alter == null:
		return
	var stress_t: float = clampf(float(_alter.stress) / 100.0, 0.0, 1.0)
	var halo_color: Color = CALM_COLOR.lerp(STRESS_COLOR, stress_t)
	halo_color.a = 0.22 + 0.20 * _pulse
	# Halo (grows slightly with pulse when stressed).
	draw_circle(Vector2.ZERO, HALO_RADIUS + 6.0 * _pulse, halo_color)
	# Selection ring.
	if _selected:
		draw_arc(Vector2.ZERO, HALO_RADIUS + 8.0, 0.0, TAU, 48, Color(0.95, 0.82, 0.5, 0.9), 3.0, true)
	# Pixel-art portrait, centred.
	if _portrait != null:
		var s: float = PORTRAIT_SIZE
		draw_texture_rect(_portrait, Rect2(-s * 0.5, -s * 0.5, s, s), false)
