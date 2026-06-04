extends Node
## Headless check of the jigsaw mini-game: a memory with an image scrambles into tiles,
## swapping into the right order solves it, and solving reveals the picture + text.
## Run: godot --headless res://tools/sim_jigsaw.tscn

var _failures: int = 0


func _check(label: String, condition: bool) -> void:
	if condition:
		print("PASS: ", label)
	else:
		print("FAIL: ", label)
		_failures += 1


func _ready() -> void:
	GameState.reset_run()
	var jig: Control = load("res://scenes/ui/memory_jigsaw.tscn").instantiate()
	add_child(jig)
	await get_tree().process_frame

	# A memory with no image is ignored (the text overlay handles those).
	EventBus.memory_unlocked.emit("nonexistent_memory")
	_check("unknown memory is ignored, stays hidden", not jig.visible)

	# A memory with an image builds the scrambled board.
	EventBus.memory_unlocked.emit("m_treehouse")
	await get_tree().process_frame
	_check("a memory with an image opens the jigsaw", jig.visible)
	_check("the board has a tile per cell (3x3)", jig._buttons.size() == 9)
	_check("tiles are a full permutation", _is_permutation(jig._order, 9))
	_check("the board starts scrambled (not solved)", not jig.is_solved())
	_check("continue gated until solved", jig._continue.disabled)

	# Swapping each tile toward its home slot solves the picture.
	for target in jig._count:
		if jig._order[target] != target:
			var j: int = jig._order.find(target)
			jig._swap(target, j)
	_check("swapping tiles into order solves it", jig.is_solved())

	# The solved transition reveals the whole picture and the memory's text.
	jig._on_solved()
	_check("solving reveals the full image", jig._full.visible)
	_check("solving reveals the memory text", jig._text.visible and jig._text.text.contains("flashlight"))
	_check("continue opens once solved", not jig._continue.disabled)

	jig.queue_free()
	print("=== sim_jigsaw done, failures: ", _failures, " ===")
	get_tree().quit(_failures)


func _is_permutation(arr: Array, n: int) -> bool:
	if arr.size() != n:
		return false
	var seen: Array[bool] = []
	seen.resize(n)
	for v in arr:
		if v < 0 or v >= n or seen[v]:
			return false
		seen[v] = true
	return true
