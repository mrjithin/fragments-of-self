extends Control
## Top-bar HUD: day, remaining time, and the objective hint that guides the player
## (critical for a stakeholder demo — nobody should ever wonder what to do next).
##
## The time meter is driven straight from GameClock every frame and eased toward the
## current budget, rather than relying on catching the time_spent signal at the exact
## instant it fires. Spends can happen during a scene's _ready (e.g. the outcome cost),
## before this HUD has connected — polling the source makes the bar always correct.

@onready var _day: Label = %DayLabel
@onready var _time: ProgressBar = %TimeMeter
@onready var _objective: Label = %ObjectiveHint

var _hint_tween: Tween


func _ready() -> void:
	_day.text = "Day %d" % GameState.day
	_time.max_value = GameClock.budget_total
	_time.value = GameClock.budget_remaining
	_objective.text = ""
	EventBus.objective_changed.connect(_on_objective_changed)


func _process(delta: float) -> void:
	if _time == null:
		return
	_time.max_value = GameClock.budget_total
	# Ease toward the real remaining time so the bar visibly drains on every spend.
	var speed: float = maxf(60.0, float(GameClock.budget_total)) * delta * 3.0
	_time.value = move_toward(_time.value, float(GameClock.budget_remaining), speed)


func _on_objective_changed(text: String) -> void:
	if _hint_tween and _hint_tween.is_running():
		_hint_tween.kill()
	_objective.text = text
	_objective.modulate.a = 0.0
	_hint_tween = create_tween()
	_hint_tween.tween_property(_objective, "modulate:a", 1.0, 0.4)
