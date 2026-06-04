extends Control
## Mystery-loop payoff + mini-game: REASSEMBLE THE MEMORY. A surfacing memory arrives
## the way trauma memory often does — in fragments, out of order. Its pieces drift in
## scrambled; the player rebuilds the true sequence by choosing the next piece that
## fits. Gentle by design — it cannot be failed, only pieced together — but it now asks
## the player to *read* and *reason* about the memory, not just click dots.
## Self-connects to EventBus.memory_unlocked so any scene can trigger it.

const MEMORIES_PATH: String = "res://data/memories.json"

const COL_LOCKED := Color(0.93, 0.82, 0.58)   # a piece set correctly in place
const COL_DIM := Color(1, 1, 1, 0.55)

@onready var _vignette: ColorRect = $Vignette
@onready var _card: PanelContainer = %MemoryCard
@onready var _title: Label = %MemoryTitle
@onready var _text: RichTextLabel = %MemoryText
@onready var _continue: Button = %MemoryContinue

var _memories: Dictionary = {}
var _ordered: Array[String] = []      # fragments in their correct narrative order
var _placed: int = 0                  # how many are correctly slotted so far
var _instruction: Label
var _pool: VBoxContainer              # scrambled remaining pieces (clickable)
var _hint: Label


func _ready() -> void:
	_memories = JsonLoader.load_dict(MEMORIES_PATH).get("memories", {})
	visible = false
	_continue.pressed.connect(_hide)
	EventBus.memory_unlocked.connect(_on_memory_unlocked)

	# Build the reassembly UI between the surfaced text and the Continue button.
	var vbox: Node = _continue.get_parent()

	_instruction = Label.new()
	_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction.autowrap_mode = TextServer.AUTOWRAP_WORD
	_instruction.add_theme_color_override("font_color", COL_DIM)
	vbox.add_child(_instruction)
	vbox.move_child(_instruction, _text.get_index() + 1)

	_pool = VBoxContainer.new()
	_pool.add_theme_constant_override("separation", 8)
	vbox.add_child(_pool)
	vbox.move_child(_pool, _instruction.get_index() + 1)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	_hint.add_theme_color_override("font_color", COL_DIM)
	vbox.add_child(_hint)
	vbox.move_child(_hint, _continue.get_index())


func _on_memory_unlocked(memory_id: String) -> void:
	if not _memories.has(memory_id):
		return
	var mem := MemoryFragment.from_dict(memory_id, _memories[memory_id])
	_title.text = mem.title
	# Prefer the authored ordered fragments; fall back to splitting the prose.
	_ordered = mem.fragments.duplicate() if not mem.fragments.is_empty() else _split_pieces(mem.text)
	_placed = 0
	_text.text = "[i]The memory lies in pieces…[/i]"

	# A single-fragment memory has nothing to reassemble — just show it.
	if _ordered.size() <= 1:
		_instruction.text = ""
		_hint.text = ""
		_clear(_pool)
		_text.text = _ordered[0] if not _ordered.is_empty() else mem.text
		_continue.disabled = false
	else:
		# The opening piece is given as a fixed anchor, so the order is something the
		# player can *reason* toward by reading the cues ("First… Then… And…"), not guess.
		_placed = 1
		_text.text = _ordered[0]
		_instruction.text = "The opening is here. Place what followed, in the order it happened."
		_hint.text = ""
		_build_pool()
		_continue.disabled = true

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


## A deterministic (seed-driven) shuffle of [start, n) that never returns sorted order.
## `start` lets the pre-placed anchor pieces stay out of the scrambled pool.
func _scrambled_indices(start: int, n: int) -> Array[int]:
	var idx: Array[int] = []
	for i in range(start, n):
		idx.append(i)
	if idx.size() <= 1:
		return idx
	# Fisher-Yates using the seeded RNG so playthroughs stay reproducible.
	for i in range(idx.size() - 1, 0, -1):
		var j: int = RNG.randi_range_inclusive(0, i)
		var tmp: int = idx[i]
		idx[i] = idx[j]
		idx[j] = tmp
	# Guard against the (rare) already-in-order shuffle — that would be no puzzle.
	var sorted := true
	for k in idx.size():
		if idx[k] != start + k:
			sorted = false
			break
	if sorted:
		var swap: int = idx[0]
		idx[0] = idx[1]
		idx[1] = swap
	return idx


func _build_pool() -> void:
	_clear(_pool)
	for ord_i in _scrambled_indices(_placed, _ordered.size()):
		var b := Button.new()
		b.text = _ordered[ord_i]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD
		b.clip_text = false
		b.custom_minimum_size = Vector2(560, 0)
		b.add_theme_color_override("font_color", Color(0.9, 0.86, 0.78))
		b.pressed.connect(_on_piece.bind(b, ord_i))
		_pool.add_child(b)


## Click a piece. If it is the NEXT one in the true order, it locks into the rebuilt
## memory; otherwise it gently refuses (a shake + a nudge) — never a failure.
func _on_piece(btn: Button, ord_i: int) -> void:
	if ord_i == _placed:
		# Correct: append to the reconstructed memory and retire the piece.
		var shown := PackedStringArray()
		for i in _placed + 1:
			shown.append(_ordered[i])
		_text.text = " ".join(shown)
		_placed += 1
		_hint.text = "…it fits."
		_hint.add_theme_color_override("font_color", COL_LOCKED)
		btn.disabled = true
		var fade := create_tween()
		fade.tween_property(btn, "modulate:a", 0.0, 0.25)
		fade.tween_callback(btn.queue_free)
		if _placed >= _ordered.size():
			_hint.text = "The memory is whole again."
			_continue.disabled = false
			_continue.grab_focus()
	else:
		# Wrong: shake in place and nudge, but cost nothing.
		_hint.text = "Not there — that piece belongs another moment."
		_hint.add_theme_color_override("font_color", COL_DIM)
		_shake(btn)


func _shake(node: Control) -> void:
	var base: Vector2 = node.position
	var t := create_tween()
	t.tween_property(node, "position:x", base.x - 8.0, 0.04)
	t.tween_property(node, "position:x", base.x + 8.0, 0.08)
	t.tween_property(node, "position:x", base.x, 0.04)


func _clear(container: Node) -> void:
	for c in container.get_children():
		c.queue_free()


func _hide() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	await tween.finished
	visible = false
