class_name AlterCard
extends PanelContainer
## One alter's entry in the "Inner System" sidebar: name · role, headline skill +
## stress, a colour-coded stress bar, and the contextual actions (Talk / Rest / Send).
## Mirrors the clarity of a roster panel while staying in the warm theme.

signal selected(alter_id: String)
signal talk_pressed(alter_id: String)
signal rest_pressed(alter_id: String)
signal assign_pressed(alter_id: String)

const CALM_FILL: Color = Color(0.45, 0.62, 0.48)
const STRESS_FILL: Color = Color(0.85, 0.45, 0.35)

@onready var _portrait: TextureRect = $Margin/VBox/Top/Portrait
@onready var _name: Label = $Margin/VBox/Top/Info/NameLabel
@onready var _headline: Label = $Margin/VBox/Top/Info/HeadlineLabel
@onready var _stress_bar: ProgressBar = $Margin/VBox/StressBar
@onready var _talk: Button = $Margin/VBox/Buttons/TalkButton
@onready var _rest: Button = $Margin/VBox/Buttons/RestButton
@onready var _assign: Button = $Margin/VBox/Buttons/AssignButton

const PORTRAIT_PATH: String = "res://assets/art/portrait_%s.png"

var alter_id: String = ""
var _primary_skill: String = ""
var _fill_box: StyleBoxFlat
var _base_box: StyleBox
var _sel_box: StyleBox


func setup(alter: Alter) -> void:
	alter_id = alter.id
	_primary_skill = alter.skills[0] if not alter.skills.is_empty() else "—"
	_name.text = "%s · %s" % [alter.name, alter.role]
	_name.add_theme_color_override("font_color", alter.color)

	var tex: Texture2D = load(PORTRAIT_PATH % alter.id)
	if tex != null:
		_portrait.texture = tex

	_base_box = get_theme_stylebox("panel")
	_sel_box = preload("res://scenes/internal/card_selected.tres")

	_fill_box = StyleBoxFlat.new()
	_fill_box.corner_radius_top_left = 4
	_fill_box.corner_radius_top_right = 4
	_fill_box.corner_radius_bottom_left = 4
	_fill_box.corner_radius_bottom_right = 4
	_stress_bar.add_theme_stylebox_override("fill", _fill_box)
	_stress_bar.max_value = 100.0

	_talk.pressed.connect(func() -> void: talk_pressed.emit(alter_id))
	_rest.pressed.connect(func() -> void: rest_pressed.emit(alter_id))
	_assign.pressed.connect(func() -> void: assign_pressed.emit(alter_id))

	refresh_stats(alter)


func refresh_stats(alter: Alter) -> void:
	_headline.text = "%s  ·  Stress %d" % [_primary_skill.capitalize(), alter.stress]
	var t: float = clampf(float(alter.stress) / 100.0, 0.0, 1.0)
	_fill_box.bg_color = CALM_FILL.lerp(STRESS_FILL, t)
	var tween := create_tween()
	tween.tween_property(_stress_bar, "value", float(alter.stress), 0.4).set_trans(Tween.TRANS_SINE)


## Drive button affordances from the view's current state.
func set_actions(talk_visible: bool, rest_enabled: bool, assign_enabled: bool) -> void:
	_talk.visible = talk_visible
	_rest.disabled = not rest_enabled
	_assign.disabled = not assign_enabled


func set_selected(value: bool) -> void:
	add_theme_stylebox_override("panel", _sel_box if value else _base_box)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected.emit(alter_id)
