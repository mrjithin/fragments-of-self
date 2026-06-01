extends Control
## Information loop: a gentle, non-blocking corner card that surfaces a real DID fact.
## Self-connects to EventBus.did_fact_surfaced.

@onready var _card: PanelContainer = %FactCard
@onready var _title: Label = %FactTitle
@onready var _text: RichTextLabel = %FactText
@onready var _dismiss: Button = %FactDismiss

const SLIDE_OFFSET: float = 360.0

var _shown_x: float = 0.0


func _ready() -> void:
	_dismiss.pressed.connect(_hide)
	EventBus.did_fact_surfaced.connect(_on_fact)
	_shown_x = _card.position.x
	_card.position.x = _shown_x + SLIDE_OFFSET
	_card.modulate.a = 0.0


func _on_fact(fact_id: String) -> void:
	var fact: Dictionary = DIDFacts.get_fact(fact_id)
	if fact.is_empty():
		return
	_title.text = fact.get("title", "Did you know?")
	_text.text = fact.get("text", "")
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_card, "position:x", _shown_x, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_card, "modulate:a", 1.0, 0.4)


func _hide() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_card, "position:x", _shown_x + SLIDE_OFFSET, 0.4).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_card, "modulate:a", 0.0, 0.4)
