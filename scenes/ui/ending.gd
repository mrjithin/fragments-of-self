extends Control
## The run's payoff: a path-based ending (Integration / Cooperation / Holding On)
## that reflects how the system fared, weaves together the memories recovered, and
## closes on the awareness note. Reached from the final day-end. UI built in code.

const MEMORIES_PATH: String = "res://data/memories.json"
const TITLE_SCENE: String = "res://scenes/ui/title_screen.tscn"
const BG_TEXTURE: String = "res://assets/art/bg_ending.png"

const COL_TEXT := Color(0.93, 0.86, 0.74)
const COL_DIM := Color(0.82, 0.76, 0.70, 0.75)
const COL_ACCENT := Color(0.91, 0.71, 0.43)
const COL_GOOD := Color(0.6, 0.78, 0.6)


func _ready() -> void:
	# Catch any achievements earned only by the run's final state (e.g. alignment).
	Achievements.evaluate()
	_build()
	# A finished run shouldn't offer "Continue" into a spent save.
	SaveManager.delete_save()


func _path() -> String:
	var ratio: float = float(GameState.ending_alignment) / float(maxi(1, GameState.ALIGNMENT_MAX))
	if ratio >= 0.6:
		return "integration"
	elif ratio >= 0.3:
		return "cooperation"
	return "survival"


func _build() -> void:
	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture = load(BG_TEXTURE)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.08, 0.05, 0.05, 0.7)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(660, 0)
	col.add_theme_constant_override("separation", 16)
	center.add_child(col)

	var heads := {"integration": "Integration", "cooperation": "Cooperation", "survival": "Holding On"}
	var path := _path()
	var title := _label(heads.get(path, "Holding On"), 34, COL_ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.custom_minimum_size = Vector2(660, 0)
	body.add_theme_color_override("default_color", COL_TEXT)
	body.text = _compose(path)
	col.add_child(body)

	var btn := Button.new()
	btn.text = "Return to the title"
	btn.custom_minimum_size = Vector2(0, 44)
	btn.pressed.connect(_on_return)
	col.add_child(btn)


func _compose(path: String) -> String:
	var lines: Array[String] = []
	match path:
		"integration":
			lines.append("The system learned to move as one — many voices, one direction. The past is no longer a stranger, and no part carries the weight alone. Not an ending so much as a beginning: a life, lived together.")
		"cooperation":
			lines.append("It wasn't easy, and the story isn't finished — but trust is taking root between the parts. They are learning, slowly, that being many can be a kind of strength.")
		_:
			lines.append("Some days were survived rather than won — and that counts for everything. The protagonist is still here, still trying, with parts beginning to lean on one another.")

	# Mystery payoff: weave the recovered fragments.
	var all_mem: Dictionary = JsonLoader.load_dict(MEMORIES_PATH).get("memories", {})
	var found: Array = GameState.unlocked_memories
	if not found.is_empty():
		lines.append("")
		if found.has("m_whole"):
			lines.append("[color=%s]The whole of it came together:[/color]" % COL_ACCENT.to_html())
		else:
			lines.append("[color=%s]Pieces of the past you recovered:[/color]" % COL_ACCENT.to_html())
		for mid in found:
			var t: String = all_mem.get(mid, {}).get("title", str(mid))
			lines.append("  ✦ %s" % t)
		if not found.has("m_whole"):
			lines.append("[i]…and more waits to be remembered.[/i]")

	lines.append("")
	lines.append("[color=%s]Memories recovered: %d / %d   ·   Alignment: %d / %d[/color]" % [
		COL_DIM.to_html(), found.size(), all_mem.size(), GameState.ending_alignment, GameState.ALIGNMENT_MAX])
	lines.append("")
	lines.append("[color=%s]DID is real, and so is recovery. People with DID can and do live full, meaningful lives.[/color]" % COL_GOOD.to_html())
	return "\n".join(lines)


func _on_return() -> void:
	GameState.reset_run()
	GameClock.reset_day()
	SceneFlow.change_scene_to_file(TITLE_SCENE)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
