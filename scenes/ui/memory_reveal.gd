extends Control
## Mystery-loop payoff + mini-game: when a memory surfaces, its fragments drift in
## scattered. The player gathers the shards (click each one) to assemble the memory
## before it resolves. Gentle by design — it cannot be failed, only pieced together.
## Self-connects to EventBus.memory_unlocked so any scene can trigger it.

const MEMORIES_PATH: String = "res://data/memories.json"

@onready var _vignette: ColorRect = $Vignette
@onready var _card: PanelContainer = %MemoryCard
@onready var _title: Label = %MemoryTitle
@onready var _text: RichTextLabel = %MemoryText
@onready var _continue: Button = %MemoryContinue

var _memories: Dictionary = {}
var _pieces: Array[String] = []
var _gathered: int = 0
var _shards: HBoxContainer


func _ready() -> void:
	_memories = JsonLoader.load_dict(MEMORIES_PATH).get("memories", {})
	visible = false
	_continue.pressed.connect(_hide)
	EventBus.memory_unlocked.connect(_on_memory_unlocked)

	# Shard row sits just above the Continue button.
	_shards = HBoxContainer.new()
	_shards.alignment = BoxContainer.ALIGNMENT_CENTER
	_shards.add_theme_constant_override("separation", 12)
	var vbox: Node = _continue.get_parent()
	vbox.add_child(_shards)
	vbox.move_child(_shards, _continue.get_index())


func _on_memory_unlocked(memory_id: String) -> void:
	if not _memories.has(memory_id):
		return
	var mem := MemoryFragment.from_dict(memory_id, _memories[memory_id])
	_title.text = mem.title
	_pieces = _split_pieces(mem.text)
	_gathered = 0
	_text.text = "[i]Pieces of it drift just out of reach. Gather them, one by one.[/i]"
	_build_shards()
	_continue.disabled = _pieces.size() > 0
	visible = true
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.6)


func _split_pieces(text: String) -> Array[String]:
	var out: Array[String] = []
	for raw in text.split(".", false):
		var s := raw.strip_edges()
		if s != "":
			out.append(s + ".")
	if out.is_empty():
		out.append(text)
	return out


func _build_shards() -> void:
	for c in _shards.get_children():
		c.queue_free()
	for i in _pieces.size():
		var b := Button.new()
		b.text = "✦"
		b.custom_minimum_size = Vector2(46, 46)
		b.pressed.connect(_on_shard.bind(b))
		_shards.add_child(b)


func _on_shard(btn: Button) -> void:
	if _gathered >= _pieces.size():
		return
	btn.disabled = true
	btn.text = "·"
	_gathered += 1
	# Reveal the fragments in reading order as they are gathered.
	var shown := PackedStringArray()
	for i in _gathered:
		shown.append(_pieces[i])
	_text.text = " ".join(shown)
	if _gathered >= _pieces.size():
		_continue.disabled = false
		_continue.grab_focus()


func _hide() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	await tween.finished
	visible = false
