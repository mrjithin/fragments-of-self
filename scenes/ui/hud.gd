extends Control
## Top-bar HUD: day, remaining time (bar + number), and the objective hint that
## guides the player. The meter is driven straight from GameClock every frame and
## eased toward the current budget — polling the source means the bar can't get stuck
## out of sync if a spend happens before this HUD connects. A numeric readout sits
## beside it so the remaining time is unmissable even if styling fails to render.

const CALM_FILL: Color = Color(0.55, 0.74, 0.52)   # plenty of time
const LOW_FILL: Color = Color(0.86, 0.4, 0.34)     # nearly out

@onready var _day: Label = %DayLabel
@onready var _time: ProgressBar = %TimeMeter
@onready var _objective: Label = %ObjectiveHint

var _time_text: Label
var _fill: StyleBoxFlat
var _hint_tween: Tween


func _ready() -> void:
	_day.text = "Day %d" % GameState.day
	_time.max_value = GameClock.budget_total
	_time.value = GameClock.budget_remaining
	_time.show_percentage = false

	# Explicit, clearly-coloured fill so the bar's movement is always visible.
	_fill = StyleBoxFlat.new()
	_fill.set_corner_radius_all(4)
	_fill.bg_color = CALM_FILL
	_time.add_theme_stylebox_override("fill", _fill)

	# Numeric readout beside the bar — unmissable, independent of styling.
	_time_text = Label.new()
	_time_text.add_theme_font_size_override("font_size", 14)
	_time_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_time.get_parent().add_child(_time_text)

	_objective.text = ""
	EventBus.objective_changed.connect(_on_objective_changed)


func _process(delta: float) -> void:
	if _time == null:
		return
	var total: float = maxf(1.0, float(GameClock.budget_total))
	_time.max_value = total
	# Ease toward the real remaining time so the bar visibly drains on every spend.
	_time.value = move_toward(_time.value, float(GameClock.budget_remaining), total * delta * 3.0)
	if _time_text:
		_time_text.text = "  ⏳ %d / %d" % [GameClock.budget_remaining, GameClock.budget_total]
	var ratio: float = clampf(float(GameClock.budget_remaining) / total, 0.0, 1.0)
	_fill.bg_color = LOW_FILL.lerp(CALM_FILL, ratio)


func _on_objective_changed(text: String) -> void:
	if _hint_tween and _hint_tween.is_running():
		_hint_tween.kill()
	_objective.text = text
	_objective.modulate.a = 0.0
	_hint_tween = create_tween()
	_hint_tween.tween_property(_objective, "modulate:a", 1.0, 0.4)
