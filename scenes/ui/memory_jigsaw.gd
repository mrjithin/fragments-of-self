extends Control
## Mystery-loop payoff + jigsaw mini-game. When a memory with an image surfaces, the
## picture arrives in scrambled tiles; the player swaps them (click one, click another)
## until the memory is whole, then its text is revealed as the reward. Gentle by design
## — it cannot be failed, only solved. Self-connects to EventBus.memory_unlocked; defers
## to the text-reassembly overlay for any memory that has no image.

const MEMORIES_PATH: String = "res://data/memories.json"
const GRID: int = 3                       # 3x3 tiles
const TILE_PX: int = 96                   # on-screen size of each tile

const COL_TEXT := Color(0.93, 0.86, 0.74)
const COL_DIM := Color(0.82, 0.76, 0.70, 0.82)
const COL_ACCENT := Color(0.91, 0.71, 0.43)
const COL_SELECTED := Color(1.0, 0.92, 0.7)

var _memories: Dictionary = {}
var _count: int = GRID * GRID
var _tiles: Array[Texture2D] = []         # tile_id -> the slice of the source image
var _buttons: Array[TextureButton] = []   # slot index -> button shown there
var _order: Array[int] = []               # slot index -> tile_id currently in that slot
var _selected: int = -1
var _solved: bool = false

var _title: Label
var _instruction: Label
var _hint: Label
var _grid: GridContainer
var _continue: Button
var _full: TextureRect
var _text: RichTextLabel
var _card: VBoxContainer
var _mem_text: String = ""


func _ready() -> void:
	_memories = JsonLoader.load_dict(MEMORIES_PATH).get("memories", {})
	visible = false
	_build_chrome()
	EventBus.memory_unlocked.connect(_on_memory_unlocked)


func _build_chrome() -> void:
	var vignette := ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0.08, 0.05, 0.05, 0.84)
	add_child(vignette)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_card = VBoxContainer.new()
	_card.add_theme_constant_override("separation", 12)
	_card.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(_card)

	var tag := _label("✦  A memory surfaces  ✦", 14, COL_DIM)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.add_child(tag)
	_title = _label("Memory", 26, COL_ACCENT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.add_child(_title)
	_instruction = _label("It came back in pieces. Swap the tiles until the picture is whole.", 13, COL_DIM)
	_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.add_child(_instruction)

	_grid = GridContainer.new()
	_grid.columns = GRID
	_grid.add_theme_constant_override("h_separation", 3)
	_grid.add_theme_constant_override("v_separation", 3)
	var grid_center := CenterContainer.new()
	grid_center.add_child(_grid)
	_card.add_child(grid_center)

	# The solved picture + the memory text, shown only once assembled.
	_full = TextureRect.new()
	_full.custom_minimum_size = Vector2(GRID * TILE_PX, GRID * TILE_PX)
	_full.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_full.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_full.visible = false
	var full_center := CenterContainer.new()
	full_center.add_child(_full)
	_card.add_child(full_center)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.custom_minimum_size = Vector2(GRID * TILE_PX + 40, 0)
	_text.add_theme_color_override("default_color", COL_TEXT)
	_text.visible = false
	_card.add_child(_text)

	_hint = _label("", 13, COL_DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.add_child(_hint)

	_continue = Button.new()
	_continue.text = "Hold it close"
	_continue.custom_minimum_size = Vector2(0, 42)
	_continue.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_continue.pressed.connect(_hide)
	_card.add_child(_continue)


func _on_memory_unlocked(memory_id: String) -> void:
	if not _memories.has(memory_id):
		return
	var mem := MemoryFragment.from_dict(memory_id, _memories[memory_id])
	# No image -> let the text-reassembly overlay handle this one.
	if mem.image == "" or not ResourceLoader.exists(mem.image):
		return

	_title.text = mem.title
	_mem_text = mem.text
	_solved = false
	_selected = -1
	_text.visible = false
	_full.visible = false
	_grid.visible = true
	_instruction.visible = true
	_hint.text = ""
	_continue.disabled = true
	_slice(load(mem.image))
	_build_tiles()

	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)


## Cut the source image into GRID×GRID atlas tiles (tile_id 0..count-1, row-major).
func _slice(src: Texture2D) -> void:
	_tiles.clear()
	var tw: int = src.get_width() / GRID
	var th: int = src.get_height() / GRID
	for tile_id in _count:
		var col: int = tile_id % GRID
		var row: int = tile_id / GRID
		var at := AtlasTexture.new()
		at.atlas = src
		at.region = Rect2(col * tw, row * th, tw, th)
		_tiles.append(at)


func _build_tiles() -> void:
	for c in _grid.get_children():
		c.queue_free()
	_buttons.clear()
	_order = _scrambled()
	for slot in _count:
		var b := TextureButton.new()
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_SCALE
		b.custom_minimum_size = Vector2(TILE_PX, TILE_PX)
		b.texture_normal = _tiles[_order[slot]]
		b.pressed.connect(_on_tile.bind(slot))
		_grid.add_child(b)
		_buttons.append(b)


## A seeded permutation of [0, count) that isn't already solved.
func _scrambled() -> Array[int]:
	var idx: Array[int] = []
	for i in _count:
		idx.append(i)
	for i in range(_count - 1, 0, -1):
		var j: int = RNG.randi_range_inclusive(0, i)
		var tmp: int = idx[i]
		idx[i] = idx[j]
		idx[j] = tmp
	if _is_sorted(idx):
		var s: int = idx[0]
		idx[0] = idx[1]
		idx[1] = s
	return idx


func _is_sorted(arr: Array[int]) -> bool:
	for i in arr.size():
		if arr[i] != i:
			return false
	return true


func _on_tile(slot: int) -> void:
	if _solved:
		return
	if _selected == -1:
		_selected = slot
		_buttons[slot].modulate = COL_SELECTED
		_hint.text = "…and where does it belong?"
	elif _selected == slot:
		_buttons[slot].modulate = Color.WHITE
		_selected = -1
		_hint.text = ""
	else:
		_swap(_selected, slot)
		_buttons[_selected].modulate = Color.WHITE
		_selected = -1
		if is_solved():
			_on_solved()
		else:
			_hint.text = "Getting closer."


## Swap the tiles in two slots and refresh what each shows.
func _swap(a: int, b: int) -> void:
	var t: int = _order[a]
	_order[a] = _order[b]
	_order[b] = t
	if a < _buttons.size() and b < _buttons.size():
		_buttons[a].texture_normal = _tiles[_order[a]]
		_buttons[b].texture_normal = _tiles[_order[b]]


func is_solved() -> bool:
	return _is_sorted(_order)


func _on_solved() -> void:
	_solved = true
	_grid.visible = false
	_instruction.visible = false
	if not _tiles.is_empty():
		_full.texture = (_tiles[0] as AtlasTexture).atlas   # the whole source image
	_full.visible = true
	_text.text = "[i]%s[/i]" % _mem_text
	_text.visible = true
	_hint.text = "The memory is whole again."
	_continue.disabled = false
	_continue.grab_focus()


func _hide() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	await tween.finished
	visible = false


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
