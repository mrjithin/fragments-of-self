extends Control
## Mystery-loop payoff: a soft-focus modal that reveals a recovered memory fragment.
## Self-connects to EventBus.memory_unlocked so any scene can trigger it.

const MEMORIES_PATH: String = "res://data/memories.json"

@onready var _vignette: ColorRect = $Vignette
@onready var _card: PanelContainer = %MemoryCard
@onready var _title: Label = %MemoryTitle
@onready var _text: RichTextLabel = %MemoryText
@onready var _continue: Button = %MemoryContinue

var _memories: Dictionary = {}


func _ready() -> void:
	_memories = JsonLoader.load_dict(MEMORIES_PATH).get("memories", {})
	visible = false
	_continue.pressed.connect(_hide)
	EventBus.memory_unlocked.connect(_on_memory_unlocked)


func _on_memory_unlocked(memory_id: String) -> void:
	if not _memories.has(memory_id):
		return
	var mem := MemoryFragment.from_dict(memory_id, _memories[memory_id])
	_title.text = mem.title
	_text.text = mem.text
	visible = true
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.6)


func _hide() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	await tween.finished
	visible = false
