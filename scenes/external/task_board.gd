extends Control
## The day's hub: lists the tasks available today as cards. Picking one launches
## its external situation; finishing it returns here with the task marked done.
## When the player is ready (or out of time), "End the day" goes to the summary.
## UI is built in code to keep the scene file minimal.

const DAYS_PATH: String = "res://data/days.json"
const TASKS_PATH: String = "res://data/tasks.json"
const EXTERNAL_SCENE: String = "res://scenes/external/external_world.tscn"
const DAY_END_SCENE: String = "res://scenes/ui/day_end_summary.tscn"
const BG_TEXTURE: String = "res://assets/art/bg_external.png"

const COL_TEXT := Color(0.93, 0.86, 0.74)
const COL_DIM := Color(0.82, 0.76, 0.70, 0.7)
const COL_ACCENT := Color(0.91, 0.71, 0.43)
const COL_DONE := Color(0.55, 0.72, 0.56)

var _list: VBoxContainer
var _time_label: Label


func _ready() -> void:
	var cfg := _day_config(GameState.day)
	if not GameState.has_flag("day_setup_done"):
		_apply_day_setup(cfg.get("setup", {}))
		GameState.set_flag("day_setup_done")

	# Roll the day's random event once (weighted, non-repeating, RNG-seeded).
	if not GameState.has_flag("day_event_done"):
		var pool := EventPool.new()
		pool.load_data()
		var ev: GameEvent = pool.roll(GameState.day)
		GameState.set_flag("day_event_done")
		if ev != null:
			GameState.current_event_text = ev.text
			if ev.fact != "":
				GameState.record_fact(ev.fact)
				EventBus.did_fact_surfaced.emit(ev.fact)

	_build_ui(cfg.get("tasks", []))

	GameState.current_scene = scene_file_path
	SaveManager.save()


# --- Day data ---

func _day_config(day: int) -> Dictionary:
	var days: Array = JsonLoader.load_dict(DAYS_PATH).get("days", [])
	if days.is_empty():
		return {}
	var idx: int = clampi(day - 1, 0, days.size() - 1)
	return days[idx] as Dictionary


func _apply_day_setup(setup: Dictionary) -> void:
	var stress: Dictionary = setup.get("stress", {})
	for aid in stress:
		GameState.alter_stress[aid] = clampi(int(stress[aid]), 0, 100)
	var strain: Dictionary = setup.get("strain", {})
	for key in strain:
		GameState.relationship_affinity[key] = clampi(int(strain[key]), 0, 100)


# --- UI ---

func _build_ui(task_paths: Array) -> void:
	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture = load(BG_TEXTURE)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.10, 0.07, 0.06, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(620, 0)
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)

	var title := _label("Day %d  —  what will you face?" % GameState.day, 26, COL_ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	_time_label = _label("", 14, COL_DIM)
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_time_label)
	_refresh_time()

	# The day's random event — a quiet flavour beat that varies per playthrough.
	if GameState.current_event_text != "":
		var ev_label := _label(GameState.current_event_text, 14, COL_TEXT)
		ev_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(ev_label)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	col.add_child(_list)
	for p in task_paths:
		_list.add_child(_make_task_card(str(p)))

	var end_btn := Button.new()
	end_btn.text = "End the day  ▶"
	end_btn.custom_minimum_size = Vector2(0, 44)
	end_btn.pressed.connect(_on_end_day)
	col.add_child(end_btn)


func _make_task_card(situation_path: String) -> Control:
	var task_data: Dictionary = JsonLoader.load_dict(TASKS_PATH).get("tasks", {})
	var situation := JsonLoader.load_dict(situation_path)
	var task: Dictionary = task_data.get(situation.get("task_id", ""), {})
	var done: bool = GameState.completed_tasks.has(situation_path)

	var card := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(_label(task.get("title", "A task"), 18, COL_DONE if done else COL_TEXT))
	info.add_child(_label(task.get("prompt", ""), 13, COL_DIM))
	info.add_child(_label("Calls for: %s" % str(task.get("required_skill", "—")).capitalize(), 12, COL_DIM))

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(120, 0)
	if done:
		btn.text = "✓ Done"
		btn.disabled = true
	else:
		btn.text = "Handle"
		btn.pressed.connect(_on_pick.bind(situation_path))
	row.add_child(btn)
	return card


func _refresh_time() -> void:
	_time_label.text = "Time left today:  %d / %d" % [GameClock.budget_remaining, GameClock.budget_total]


# --- Actions ---

func _on_pick(situation_path: String) -> void:
	GameState.current_situation = situation_path
	SceneFlow.change_scene_to_file(EXTERNAL_SCENE)


func _on_end_day() -> void:
	EventBus.day_ended.emit(GameState.build_day_summary())
	SceneFlow.change_scene_to_file(DAY_END_SCENE)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
