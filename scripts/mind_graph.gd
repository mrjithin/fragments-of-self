extends Control
class_name MindGraph
## Read-only visualization of the internal system: alters as nodes arranged in a
## ring, bonds drawn as edges (thicker/greener = stronger, thinner/red = strained).
## Node fill = alter colour, ring = stress level. Driven by main.gd via refresh().

const COL_TEXT := Color("#f1e6dc")
const COL_DIM := Color("#7a6f78")
const COL_GOOD := Color("#8fc7a0")
const COL_ACCENT := Color("#e8a35c")
const COL_BAD := Color("#c96f6f")

var _alters: Array = []
var _get_aff: Callable


func refresh(alters: Array, get_aff: Callable) -> void:
	_alters = alters
	_get_aff = get_aff
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var n := _alters.size()
	if n == 0:
		draw_string(font, Vector2(20, 40), "No alters yet.", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COL_DIM)
		return

	var rect := get_rect()
	var center := Vector2(rect.size.x, rect.size.y) * 0.5
	var ring_radius: float = min(rect.size.x, rect.size.y) * 0.36
	if n == 1:
		ring_radius = 0.0

	# Node positions around a ring.
	var pos: Array = []
	for i in range(n):
		var ang := -PI / 2.0 + TAU * float(i) / float(n)
		pos.append(center + Vector2(cos(ang), sin(ang)) * ring_radius)

	# Edges (draw under nodes).
	if _get_aff.is_valid():
		for i in range(n):
			for j in range(i + 1, n):
				var aff: int = _get_aff.call(_alters[i]["id"], _alters[j]["id"])
				var t: float = abs(float(aff) - 50.0) / 50.0
				var width: float = 1.0 + t * 5.0
				var col := COL_GOOD if aff >= 60 else (COL_BAD if aff <= 40 else COL_DIM)
				col.a = 0.35 + t * 0.5
				draw_line(pos[i], pos[j], col, width, true)
				# Affinity number at the midpoint.
				var mid: Vector2 = (pos[i] + pos[j]) * 0.5
				draw_string(font, mid, str(aff), HORIZONTAL_ALIGNMENT_CENTER, -1, 12, COL_DIM)

	# Nodes.
	for i in range(n):
		var alter: Dictionary = _alters[i]
		var node_r: float = 22.0 + float(int(alter["skill_level"])) * 2.0
		var fill := Color(alter["color"])
		draw_circle(pos[i], node_r, fill)
		# Stress ring.
		var stress: int = int(alter["stress"])
		var ring := COL_GOOD if stress < 50 else (COL_ACCENT if stress < 75 else COL_BAD)
		draw_arc(pos[i], node_r + 3.0, 0.0, TAU, 48, ring, 3.0, true)
		# Name + stress label under the node.
		var name_str: String = alter["name"]
		var nsize := font.get_string_size(name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		draw_string(font, pos[i] + Vector2(-nsize.x / 2.0, node_r + 18.0), name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COL_TEXT)
		var s_str := "%s · %d%%" % [alter["skill"], stress]
		var ssize := font.get_string_size(s_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
		draw_string(font, pos[i] + Vector2(-ssize.x / 2.0, node_r + 33.0), s_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COL_DIM)
