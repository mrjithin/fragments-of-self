extends Control
## Top-bar HUD: day, remaining time, and the objective hint that guides the player
## (critical for a stakeholder demo — nobody should ever wonder what to do next).

@onready var _day: Label = %DayLabel
@onready var _time: ProgressBar = %TimeMeter
@onready var _objective: Label = %ObjectiveHint

var _hint_tween: Tween


func _ready() -> void:
	_day.text = "Day %d" % GameState.day
	_time.max_value = GameClock.budget_total
	_time.value = GameClock.budget_remaining
	_objective.text = ""
	EventBus.time_spent.connect(_on_time_spent)
	EventBus.objective_changed.connect(_on_objective_changed)


func _on_time_spent(_amount: int, remaining: int) -> void:
	var tween := create_tween()
	tween.tween_property(_time, "value", float(remaining), 0.4).set_trans(Tween.TRANS_SINE)


func _on_objective_changed(text: String) -> void:
	if _hint_tween and _hint_tween.is_running():
		_hint_tween.kill()
	_objective.text = text
	_objective.modulate.a = 0.0
	_hint_tween = create_tween()
	_hint_tween.tween_property(_objective, "modulate:a", 1.0, 0.4)
