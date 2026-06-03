extends Control
## End-of-day reflection. Reads the run's deltas from GameState and animates the
## "ending alignment" meter — the beat that says choices accumulate toward an ending.

const MEMORIES_PATH: String = "res://data/memories.json"
const TITLE_SCENE: String = "res://scenes/ui/title_screen.tscn"
const BOARD_SCENE: String = "res://scenes/external/task_board.tscn"
const ENDING_SCENE: String = "res://scenes/ui/ending.tscn"
const DAYS_PATH: String = "res://data/days.json"

@onready var _title: Label = %TitleLabel
@onready var _body: RichTextLabel = %SummaryBody
@onready var _meter: ProgressBar = %AlignmentMeter
@onready var _meter_label: Label = %AlignmentLabel
@onready var _continue: Button = %EndDemoButton


var _skipped: int = 0


func _ready() -> void:
	# Time is finite: any of the day's tasks you left unattended costs alignment.
	_skipped = _count_skipped()
	if _skipped > 0:
		GameState.add_alignment(-_skipped)
	var summary: Dictionary = GameState.build_day_summary()
	var is_final: bool = GameState.day >= _total_days()
	_title.text = "Day %d  —  the chapter closes" % summary.get("day", 1) if is_final \
		else "Day %d  —  a good start" % summary.get("day", 1)
	_continue.text = "Finish" if is_final else "Continue to Day %d" % (GameState.day + 1)
	_body.text = _compose_body(summary)

	var align: int = summary.get("alignment", 0)
	var align_max: int = summary.get("alignment_max", 10)
	_meter.max_value = float(align_max)
	_meter.value = 0.0
	_meter_label.text = _alignment_path(align, align_max)

	_continue.pressed.connect(_on_continue)
	await get_tree().create_timer(0.5).timeout
	var tween := create_tween()
	tween.tween_property(_meter, "value", float(align), 1.2).set_trans(Tween.TRANS_CUBIC)


func _compose_body(summary: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("[b]Time spent today:[/b] %d / %d" % [summary.get("time_spent", 0), summary.get("time_total", 100)])

	var assigned: String = summary.get("assigned_alter_id", "")
	if assigned != "":
		lines.append("[b]Who stepped forward:[/b] %s" % assigned.capitalize())

	var rels: Array = summary.get("relationship_log", [])
	for entry in rels:
		lines.append("[b]Bond mended:[/b] %s (%s → %s)" % [
			entry.get("pair", ""), entry.get("from_status", ""), entry.get("to_status", "")])

	var mems: Array = summary.get("unlocked_memories", [])
	if not mems.is_empty():
		var data := JsonLoader.load_dict(MEMORIES_PATH)
		var all_mem: Dictionary = data.get("memories", {})
		for mem_id in mems:
			var title: String = all_mem.get(mem_id, {}).get("title", mem_id)
			lines.append("[b]Memory recovered:[/b] %s" % title)

	if GameState.last_outcome_penalty < 0:
		lines.append("[b]The choice cost something[/b] — strain, triggers, or an unmended bond (alignment %d)." % GameState.last_outcome_penalty)

	if _skipped > 0:
		lines.append("[b]Left unattended:[/b] %d task(s) — life doesn't pause (alignment -%d)." % [_skipped, _skipped])

	var heavy: Array[String] = []
	for aid in GameState.alter_stress:
		if int(GameState.alter_stress[aid]) >= 65:
			heavy.append("%s (%d)" % [str(aid).capitalize(), int(GameState.alter_stress[aid])])
	if not heavy.is_empty():
		lines.append("[b]Carrying heavy stress into tomorrow:[/b] %s — rest them early or it compounds." % ", ".join(heavy))

	lines.append("")
	lines.append("[i]Tomorrow brings new faces, and new pieces of the past…[/i]")
	return "\n".join(lines)


func _total_days() -> int:
	var days: Array = JsonLoader.load_dict(DAYS_PATH).get("days", [])
	return maxi(1, days.size())


## How many of today's offered tasks the player never handled.
func _count_skipped() -> int:
	var days: Array = JsonLoader.load_dict(DAYS_PATH).get("days", [])
	if days.is_empty():
		return 0
	var idx: int = clampi(GameState.day - 1, 0, days.size() - 1)
	var tasks: Array = (days[idx] as Dictionary).get("tasks", [])
	return maxi(0, tasks.size() - GameState.completed_tasks.size())


func _alignment_path(align: int, align_max: int) -> String:
	var ratio: float = float(align) / float(maxi(1, align_max))
	if ratio >= 0.6:
		return "Path: Integration"
	elif ratio >= 0.3:
		return "Path: Cooperation"
	return "Path: Survival"


func _on_continue() -> void:
	if GameState.day < _total_days():
		GameState.advance_day()
		GameClock.reset_day()
		SceneFlow.change_scene_to_file(BOARD_SCENE)
	else:
		# Final day -> the payoff ending (which resets the run on its way out).
		SceneFlow.change_scene_to_file(ENDING_SCENE)
