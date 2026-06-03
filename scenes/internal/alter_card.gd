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

const COL_GOOD: Color = Color(0.55, 0.78, 0.56)
const COL_WARN: Color = Color(0.94, 0.62, 0.34)
const COL_BAD: Color = Color(0.86, 0.42, 0.40)
const COL_DIM: Color = Color(0.82, 0.78, 0.74, 0.6)

@onready var _portrait: TextureRect = $Margin/VBox/Top/Portrait
@onready var _name: Label = $Margin/VBox/Top/Info/NameLabel
@onready var _headline: Label = $Margin/VBox/Top/Info/HeadlineLabel
@onready var _stress_bar: ProgressBar = $Margin/VBox/StressBar
@onready var _buttons: HBoxContainer = $Margin/VBox/Buttons
@onready var _vbox: VBoxContainer = $Margin/VBox
@onready var _talk: Button = $Margin/VBox/Buttons/TalkButton
@onready var _rest: Button = $Margin/VBox/Buttons/RestButton
@onready var _assign: Button = $Margin/VBox/Buttons/AssignButton

const PORTRAIT_PATH: String = "res://assets/art/portrait_%s.png"

var alter_id: String = ""
var _primary_skill: String = ""
var _skills: Array[String] = []
var _triggers: Array[String] = []
var _stressed: bool = false
var _meta: Label          # what this alter is good at / what triggers them
var _advice: Label        # how they fit THIS task (suited / triggered / overwhelmed)
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

	_skills = alter.skills
	_triggers = alter.triggers

	# Strengths + triggers, so the player can read each alter before choosing.
	_meta = _info_label(12)
	_vbox.add_child(_meta)
	_vbox.move_child(_meta, _stress_bar.get_index())   # sits just above the stress bar
	var strengths: String = ", ".join(alter.skills) if not alter.skills.is_empty() else "—"
	_meta.text = "Good at: %s   ·   Triggers: %s" % [strengths, _trigger_hint(alter.triggers)]
	_meta.add_theme_color_override("font_color", COL_DIM)

	# How they fit the task at hand (filled in by set_task_context).
	_advice = _info_label(13)
	_vbox.add_child(_advice)
	_vbox.move_child(_advice, _buttons.get_index())    # sits just above the buttons

	refresh_stats(alter)


func _info_label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func refresh_stats(alter: Alter) -> void:
	_stressed = alter.is_stressed()
	var tag: String = "  ·  OVERWHELMED" if _stressed else ""
	_headline.text = "%s  ·  Stress %d%s" % [_primary_skill.capitalize(), alter.stress, tag]
	var t: float = clampf(float(alter.stress) / 100.0, 0.0, 1.0)
	_fill_box.bg_color = CALM_FILL.lerp(STRESS_FILL, t)
	var tween := create_tween()
	tween.tween_property(_stress_bar, "value", float(alter.stress), 0.4).set_trans(Tween.TRANS_SINE)


## Triggers stay hidden until the player has learned them by getting burned.
func _trigger_hint(triggers: Array) -> String:
	if triggers.is_empty():
		return "—"
	var shown: PackedStringArray = []
	var hidden: bool = false
	for t in triggers:
		if GameState.discovered_triggers.has(t):
			shown.append(str(t))
		else:
			hidden = true
	if shown.is_empty():
		return "? (unknown)"
	if hidden:
		shown.append("?")
	return ", ".join(shown)


func _band_color(key: String) -> Color:
	match key:
		"good": return COL_GOOD
		"warn": return COL_WARN
		"bad": return COL_BAD
		_: return COL_DIM


## Show the coping ODDS for this task (a coarse band, never a guarantee) plus a known
## trigger warning. Hidden triggers don't show — they surface only after you've hit them.
func set_task_context(_required_skill: String, trigger: String, band: Dictionary = {}) -> void:
	if _advice == null:
		return
	var parts: PackedStringArray = []
	var col: Color = _band_color(str(band.get("key", "dim")))
	var band_text: String = str(band.get("text", ""))
	if band_text != "":
		parts.append(band_text)
	var triggered: bool = trigger != "" and _triggers.has(trigger)
	if triggered and GameState.discovered_triggers.has(trigger):
		parts.append("⚠ hits their trigger (%s)" % trigger)
		col = COL_WARN
	if _stressed:
		parts.append("overwhelmed")
	_advice.text = "  —  ".join(parts)
	_advice.add_theme_color_override("font_color", col)


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
