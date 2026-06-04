extends Control
## The Codex / Journal: everything the player has come to understand this run — the
## memories they've recovered, the DID facts they've learned, and the parts of the
## system they've gotten to know. Read-only over GameState, reachable from the day hub.
## Doubles as the game's awareness archive (the design doc's "information loop"). The
## UI is built in code to keep the scene file minimal, matching the other screens.

const MEMORIES_PATH: String = "res://data/memories.json"
const FACTS_PATH: String = "res://data/did_facts.json"
const ALTERS_PATH: String = "res://data/alters.json"
const ACHIEVEMENTS_PATH: String = "res://data/achievements.json"
const BG_TEXTURE: String = "res://assets/art/bg_board.png"
const RETURN_SCENE: String = "res://scenes/external/task_board.tscn"

const COL_TEXT := Color(0.93, 0.86, 0.74)
const COL_DIM := Color(0.82, 0.76, 0.70, 0.82)
const COL_ACCENT := Color(0.91, 0.71, 0.43)
const COL_LOCKED := Color(0.70, 0.66, 0.60, 0.55)


func _ready() -> void:
	_build()


func _build() -> void:
	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture = load(BG_TEXTURE)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.09, 0.06, 0.06, 0.74)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(720, 560)
	col.add_theme_constant_override("separation", 12)
	center.add_child(col)

	var title := _label("The Journal", 28, COL_ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var sub := _label("What you've come to understand so far.", 13, COL_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)

	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(720, 440)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(tabs)
	_add_tab(tabs, "Memories", _build_memories())
	_add_tab(tabs, "DID Facts", _build_facts())
	_add_tab(tabs, "The System", _build_system())
	_add_tab(tabs, "Milestones", _build_achievements())

	var back := Button.new()
	back.text = "◀ Back"
	back.custom_minimum_size = Vector2(0, 42)
	back.pressed.connect(_on_back)
	col.add_child(back)


## Wrap a tab's content in a scroll view and give it the tab's title.
func _add_tab(tabs: TabContainer, tab_name: String, content: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	tabs.add_child(scroll)


# --- Tab: Memories recovered ---

func _build_memories() -> Control:
	var box := _section()
	var all_mem: Dictionary = JsonLoader.load_dict(MEMORIES_PATH).get("memories", {})
	var found: Array = GameState.unlocked_memories
	box.add_child(_label("Recovered  %d / %d" % [found.size(), all_mem.size()], 15, COL_ACCENT))
	if found.is_empty():
		box.add_child(_label("No memories recovered yet. Handle the day's situations to surface the past.", 13, COL_DIM))
	for mid in found:
		var m: Dictionary = all_mem.get(mid, {})
		box.add_child(_entry(str(m.get("title", mid)), str(m.get("text", ""))))
	return box


# --- Tab: DID facts learned ---

func _build_facts() -> Control:
	var box := _section()
	var all_facts: Dictionary = JsonLoader.load_dict(FACTS_PATH).get("facts", {})
	var seen: Array = GameState.surfaced_facts
	box.add_child(_label("Learned  %d / %d" % [seen.size(), all_facts.size()], 15, COL_ACCENT))
	if seen.is_empty():
		box.add_child(_label("Awareness notes you encounter will be collected here.", 13, COL_DIM))
	for fid in seen:
		var f: Dictionary = all_facts.get(fid, {})
		box.add_child(_entry("✦  Did you know?", str(f.get("text", ""))))
	return box


# --- Tab: The system (alters you've come to know) ---

func _build_system() -> Control:
	var box := _section()
	var alters: Array = JsonLoader.load_dict(ALTERS_PATH).get("alters", [])
	box.add_child(_label("A whole made of parts — each born to carry something.", 13, COL_DIM))
	for a in alters:
		var alter: Dictionary = a as Dictionary
		if str(alter.get("id", "")) == "manager":
			continue
		var skills: Array = alter.get("skills", [])
		var line: String = "Strengths: %s" % ", ".join(PackedStringArray(skills))
		# Triggers stay hidden until the player has lived through them (card mechanic).
		var trigs: Array = alter.get("triggers", [])
		var known: PackedStringArray = []
		for t in trigs:
			if GameState.discovered_triggers.has(str(t)):
				known.append(str(t))
		if not known.is_empty():
			line += "\nKnown trigger: %s" % ", ".join(known)
		elif not trigs.is_empty():
			line += "\nTrigger: not yet known"
		box.add_child(_entry("%s  —  %s" % [str(alter.get("name", "?")), str(alter.get("role", ""))], line))
	return box


# --- Tab: Milestones (achievements) ---

func _build_achievements() -> Control:
	var box := _section()
	var defs: Array = JsonLoader.load_dict(ACHIEVEMENTS_PATH).get("achievements", [])
	# Achievements.earned() returns the earned ones as {title, desc}; match by title.
	var earned_titles: Dictionary = {}
	for e in Achievements.earned():
		earned_titles[str((e as Dictionary).get("title", ""))] = true
	box.add_child(_label("Earned  %d / %d" % [earned_titles.size(), defs.size()], 15, COL_ACCENT))
	for d in defs:
		var def: Dictionary = d as Dictionary
		var got: bool = earned_titles.has(str(def.get("title", "")))
		var heading: String = "%s  %s" % ["★" if got else "☆", str(def.get("title", ""))]
		var entry := _entry(heading, str(def.get("desc", "")))
		if not got:
			entry.modulate = COL_LOCKED   # locked ones read dimmed
		box.add_child(entry)
	return box


# --- Helpers ---

## A padded VBox used as a tab's content; callers add entries to it directly.
func _section() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	return v


func _entry(heading: String, body: String) -> Control:
	var card := PanelContainer.new()
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	card.add_child(inner)
	inner.add_child(_label(heading, 16, COL_ACCENT))
	inner.add_child(_label(body, 13, COL_TEXT))
	return card


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _on_back() -> void:
	SceneFlow.change_scene_to_file(RETURN_SCENE)
