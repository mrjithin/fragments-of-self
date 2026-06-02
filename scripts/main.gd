extends Control
## Fragments of Self — playable vertical slice.
##
## A single-screen day-cycle loop that fuses the design doc's two cores:
##   • External loop: assign alters to the day's life tasks by skill.
##   • Internal loop: alters have RELATIONSHIPS. Pair a Lead with a Support
##     "voice" — bonds boost (or clashes sabotage) the outcome — and mediate
##     conflicts as the manager. Uncover memory fragments, reach an ending.
##
## NOTE (scope): for this slice, game objects are Dictionaries loaded from JSON
## in data/ rather than the typed `class_name` Resources ARCHITECTURE.md targets.
## Content stays fully data-driven. Promote to Resources + autoloads next.

const MAX_DAYS: int = 7
const REST_RELIEF: int = 30
const IDLE_RELIEF: int = 6
const TASKS_PER_DAY: int = 3
const SUPPORT_STRESS_DIV: int = 2     # support pays half the stress cost
const TRAIN_STRESS: int = 12          # upskilling is tiring
const SAVE_PATH: String = "user://savegame.json"

# --- Palette (cozy warm autumn — Celeste Ch.4 inspired) ---
const COL_BG := Color("#2c2733")
const COL_PANEL := Color("#3a3340")
const COL_CARD := Color("#473d4f")
const COL_CARD_SEL := Color("#5e4d3a")
const COL_TEXT := Color("#f1e6dc")
const COL_DIM := Color("#b9a9b3")
const COL_ACCENT := Color("#e8a35c")
const COL_GOOD := Color("#8fc7a0")
const COL_BAD := Color("#c96f6f")

# --- Loaded content ---
var _alter_defs: Array = []
var _task_pool: Array = []
var _memories: Dictionary = {}
var _facts: Array = []
var _seed_bonds: Array = []

# --- Runtime state ---
var _rng := RandomNumberGenerator.new()
var _seed: int = 0
var _day: int = 1
var _alters: Array = []
var _today_tasks: Array = []
var _discovered: Array = []
var _affinity: Dictionary = {}        # "id_a|id_b" (sorted) -> int 0..100
var _tasks_completed: int = 0
var _selected_task: int = -1
var _modal: Control = null            # active conflict modal, if any

# --- UI references ---
var _hud_day: Label
var _hud_mem: Label
var _hud_bond: Label
var _stress_bar: ProgressBar
var _alters_box: VBoxContainer
var _tasks_box: VBoxContainer
var _detail_label: RichTextLabel
var _mem_label: RichTextLabel
var _bonds_label: RichTextLabel
var _log_label: RichTextLabel
var _endday_btn: Button
var _body_row: HBoxContainer
var _view_stack: Control
var _graph_view: MindGraph
var _graph_btn: Button
var _graph_mode: bool = false
var _menu: Control = null

# --- Audio (procedurally generated, no external assets) ---
var _sfx_player: AudioStreamPlayer
var _ambient_player: AudioStreamPlayer
var _sfx_click: AudioStream
var _sfx_chime: AudioStream
var _sfx_tone: AudioStream
var _sfx_low: AudioStream
var _muted: bool = false
var _audio_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_load_content()
	_apply_new_game()       # default state rendered behind the menu
	_build_ui()
	_refresh_all()
	if "--graph" in OS.get_cmdline_user_args():
		_toggle_view()
	if "--selftest" in OS.get_cmdline_user_args():
		call_deferred("_run_selftest")
		return
	_show_main_menu()


func _log_intro() -> void:
	_log("[color=%s]You are the inner voice of someone living with DID.[/color] Assign a [b]Lead[/b] alter to each task, and optionally a [b]Support[/b] voice — alters who bond well lift each other up; those who clash drag each other down." % COL_ACCENT.to_html())
	_log("Select a task, press [b]Assign[/b] on a Lead, then [b]Assign[/b] another as Support. [b]Rest[/b] or [b]Train[/b], then [b]End Day[/b].")


## Dev-only smoke test: drives a full playthrough via the same handlers the UI
## uses, exercising assign / support / conflict / end-day / ending paths.
## Run with:  godot --headless --path . -- --selftest
func _run_selftest() -> void:
	print("[selftest] start")
	_new_game()
	# Save / load round-trip: state must survive a serialize → parse cycle.
	_save_game()
	var d0 := _day
	var bond0 := int(round(_avg_bond()))
	var st0 := _rng.state
	_day = 99
	_load_game()
	assert(_day == d0, "load did not restore day")
	assert(int(round(_avg_bond())) == bond0, "load did not restore bonds")
	assert(_rng.state == st0, "load did not restore rng state")
	print("[selftest] save/load round-trip OK (day=%d, rng restored)" % _day)

	# Assign + clear (undo) round-trip.
	if _today_tasks.size() > 0 and _alters.size() > 0:
		_selected_task = 0
		_on_assign_pressed(_alters[0]["id"])
		assert(_today_tasks[0]["lead"] == _alters[0]["id"], "assign failed")
		_on_clear_pressed(_alters[0]["id"])
		assert(_today_tasks[0]["lead"] == "", "clear failed")
		assert(_alters[0]["action"] == "", "clear did not free alter")
		print("[selftest] assign/clear OK")

	# Force the conflict modal to exercise creation + mediation paths.
	if _alters.size() >= 2:
		_show_conflict(_alters[0], _alters[1])
		assert(_modal != null, "conflict modal failed to build")
		_resolve_conflict(_alters[0], _alters[1], true)
		assert(_modal == null, "conflict modal failed to clear")
		print("[selftest] conflict modal built + resolved")
	# Exercise the graph view + train paths.
	_toggle_view()
	_graph_view.refresh(_alters, _get_aff)
	_toggle_view()
	print("[selftest] graph toggled")

	# Play out the chapter.
	var guard := 0
	while _day <= MAX_DAYS and guard < 50:
		guard += 1
		# One alter trains each day (when able).
		for alter in _alters:
			if alter["action"] == "" and int(alter["skill_level"]) < 5:
				_on_train_pressed(alter["id"])
				break
		for ti in range(_today_tasks.size()):
			_selected_task = ti
			for _slot in range(2):
				for alter in _alters:
					if alter["action"] == "":
						_on_assign_pressed(alter["id"])
						break
		_end_day()
		if _modal != null:
			_resolve_conflict(_alters[0], _alters[1], _day % 2 == 0)
	print("[selftest] reached end after guard=%d, memories=%d, bond=%d" % [guard, _discovered.size(), int(round(_avg_bond()))])
	# Clean up the test save so it doesn't leak into normal launches.
	if _has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	print("[selftest] OK")
	get_tree().quit()


# ---------------------------------------------------------------------------
# Content loading
# ---------------------------------------------------------------------------
func _load_content() -> void:
	var a = _load_json("res://data/alters.json")
	if a != null and a.has("alters"):
		_alter_defs = a["alters"]
	var t = _load_json("res://data/tasks.json")
	if t != null and t.has("tasks"):
		_task_pool = t["tasks"]
	var m = _load_json("res://data/memories.json")
	if m != null and m.has("memories"):
		_memories = m["memories"]
	var f = _load_json("res://data/did_facts.json")
	if f != null and f.has("facts"):
		_facts = f["facts"]
	var r = _load_json("res://data/relationships.json")
	if r != null and r.has("bonds"):
		_seed_bonds = r["bonds"]


func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("Missing data file: " + path)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed == null:
		push_error("Could not parse JSON: " + path)
	return parsed


# ---------------------------------------------------------------------------
# Game setup / day flow
# ---------------------------------------------------------------------------
func _init_game() -> void:
	_day = 1
	_alters.clear()
	for def in _alter_defs:
		if int(def.get("spawn_day", 0)) == 0:
			_alters.append(_make_alter(def))
	# Seed relationships.
	_affinity.clear()
	for b in _seed_bonds:
		_affinity[_aff_key(b["a"], b["b"])] = int(b["affinity"])
	_roll_today_tasks()


func _apply_new_game() -> void:
	var r := RandomNumberGenerator.new()
	r.randomize()
	_seed = r.seed
	_rng.seed = _seed
	_init_game()


# ---------------------------------------------------------------------------
# Save / load (seeded, reproducible)
# ---------------------------------------------------------------------------
func _has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func _read_save() -> Variant:
	if not FileAccess.file_exists(SAVE_PATH):
		return null
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return null
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	return data


func _save_game() -> void:
	_click()
	var data := {
		"version": 1,
		"seed": str(_seed),
		"rng_state": str(_rng.state),
		"day": _day,
		"tasks_completed": _tasks_completed,
		"discovered": _discovered,
		"affinity": _affinity,
		"alters": _alters,
		"today_tasks": _today_tasks,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_log("[color=%s]Could not write the save file.[/color]" % COL_BAD.to_html())
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	_log("[color=%s]Saved — Day %d.[/color]" % [COL_GOOD.to_html(), _day])


func _load_game() -> void:
	var data = _read_save()
	if data == null:
		_log("[color=%s]No save to load yet.[/color]" % COL_DIM.to_html())
		return
	_apply_load(data)
	_after_state_swap()
	_log("[color=%s]Loaded — Day %d.[/color]" % [COL_GOOD.to_html(), _day])


func _new_game() -> void:
	_apply_new_game()
	_after_state_swap()
	_log("[color=%s]New run begun. A fresh seed, a fresh start.[/color]" % COL_ACCENT.to_html())
	_log_intro()


func _apply_load(data: Dictionary) -> void:
	_seed = str(data.get("seed", "0")).to_int()
	_rng.seed = _seed
	_rng.state = str(data.get("rng_state", "0")).to_int()
	_day = int(data.get("day", 1))
	_tasks_completed = int(data.get("tasks_completed", 0))
	_discovered = (data.get("discovered", []) as Array).duplicate()
	_affinity = {}
	var aff: Dictionary = data.get("affinity", {})
	for k in aff:
		_affinity[k] = int(aff[k])
	_alters = []
	for a in data.get("alters", []):
		_alters.append(_coerce_alter(a))
	_today_tasks = []
	for t in data.get("today_tasks", []):
		_today_tasks.append(_coerce_task(t))
	_selected_task = -1


func _coerce_alter(a: Dictionary) -> Dictionary:
	return {
		"id": str(a["id"]),
		"name": str(a["name"]),
		"role": str(a["role"]),
		"skill": str(a["skill"]),
		"skill_level": int(a["skill_level"]),
		"stress": int(a["stress"]),
		"color": str(a["color"]),
		"desc": str(a.get("desc", "")),
		"action": str(a.get("action", "")),
	}


func _coerce_task(t: Dictionary) -> Dictionary:
	return {
		"id": str(t["id"]),
		"title": str(t["title"]),
		"desc": str(t["desc"]),
		"skill": str(t["skill"]),
		"difficulty": int(t["difficulty"]),
		"stress_cost": int(t["stress_cost"]),
		"memory_id": str(t.get("memory_id", "")),
		"lead": str(t.get("lead", "")),
		"support": str(t.get("support", "")),
	}


## Restores interactive state after a load / new-game while the UI is live.
func _after_state_swap() -> void:
	if _graph_mode:
		_toggle_view()
	_graph_btn.disabled = false
	_endday_btn.disabled = false
	_refresh_all()


func _make_alter(def: Dictionary) -> Dictionary:
	return {
		"id": def["id"],
		"name": def["name"],
		"role": def["role"],
		"skill": def["skill"],
		"skill_level": int(def["skill_level"]),
		"stress": int(def["stress"]),
		"color": def["color"],
		"desc": def.get("desc", ""),
		"action": "",     # "", "lead:<idx>", "support:<idx>", "rest"
	}


func _roll_today_tasks() -> void:
	_today_tasks.clear()
	_selected_task = -1
	var pool := _task_pool.duplicate()
	_shuffle(pool)
	var count: int = min(TASKS_PER_DAY, pool.size())
	for i in range(count):
		var def: Dictionary = pool[i]
		_today_tasks.append({
			"id": def["id"],
			"title": def["title"],
			"desc": def["desc"],
			"skill": def["skill"],
			"difficulty": int(def["difficulty"]),
			"stress_cost": int(def["stress_cost"]),
			"memory_id": def.get("memory_id", ""),
			"lead": "",
			"support": "",
		})


func _free_alters_for_today() -> void:
	for alter in _alters:
		alter["action"] = ""


func _end_day() -> void:
	if _modal != null:
		return     # must resolve the conflict first
	_play_sfx(_sfx_tone)
	_log("[color=%s]── Day %d ──[/color]" % [COL_ACCENT.to_html(), _day])
	for task in _today_tasks:
		_resolve_task(task)
	# Rest / train / idle resolution.
	for alter in _alters:
		if alter["action"] == "rest":
			alter["stress"] = clampi(int(alter["stress"]) - REST_RELIEF, 0, 100)
		elif alter["action"] == "train":
			alter["skill_level"] = mini(int(alter["skill_level"]) + 1, 5)
			alter["stress"] = clampi(int(alter["stress"]) + TRAIN_STRESS, 0, 100)
			_log("  • [color=%s]%s trained — %s is now Lv %d.[/color]" % [COL_GOOD.to_html(), alter["name"], alter["skill"], int(alter["skill_level"])])
		elif alter["action"] == "":
			alter["stress"] = clampi(int(alter["stress"]) - IDLE_RELIEF, 0, 100)

	_day += 1
	if _day > MAX_DAYS:
		_show_ending()
		return
	_spawn_for_day(_day)
	_free_alters_for_today()
	_roll_today_tasks()
	_show_fact()
	_refresh_all()
	_maybe_conflict()


func _resolve_task(task: Dictionary) -> void:
	# Promote a lone support to lead (defensive — e.g. lead was pulled to rest).
	if task["lead"] == "" and task["support"] != "":
		task["lead"] = task["support"]
		task["support"] = ""
	if task["lead"] == "":
		_log("  • [color=%s]%s went unhandled.[/color] The day carries on without it." % [COL_DIM.to_html(), task["title"]])
		return

	var lead := _get_alter(task["lead"])
	var support := _get_alter(task["support"]) if task["support"] != "" else {}
	var chance := _success_chance(task, lead, support)

	lead["stress"] = clampi(int(lead["stress"]) + int(task["stress_cost"]), 0, 100)
	if not support.is_empty():
		support["stress"] = clampi(int(support["stress"]) + int(task["stress_cost"]) / SUPPORT_STRESS_DIV, 0, 100)

	var who: String = lead["name"]
	if not support.is_empty():
		who += " & " + support["name"]

	if _rng.randf() < chance:
		_tasks_completed += 1
		_log("  • [color=%s]%s handled %s.[/color]" % [COL_GOOD.to_html(), who, task["title"]])
		if not support.is_empty():
			_adjust_aff(lead["id"], support["id"], 6)   # success deepens the bond
		_maybe_reveal_memory(task)
	else:
		lead["stress"] = clampi(int(lead["stress"]) + 8, 0, 100)
		_log("  • [color=%s]%s struggled with %s.[/color] It took a toll." % [COL_BAD.to_html(), who, task["title"]])
		if not support.is_empty():
			_adjust_aff(lead["id"], support["id"], -3)   # failure strains it


func _spawn_for_day(day: int) -> void:
	for def in _alter_defs:
		if int(def.get("spawn_day", 0)) == day:
			_alters.append(_make_alter(def))
			_log("[color=%s]A new alter has emerged: %s, %s.[/color] Under strain, the system makes room for who it needs." % [def["color"], def["name"], def["role"]])


func _maybe_reveal_memory(task: Dictionary) -> void:
	var mid: String = task.get("memory_id", "")
	if mid == "" or _discovered.has(mid) or not _memories.has(mid):
		return
	_discovered.append(mid)
	_play_sfx(_sfx_chime)
	_log("[color=%s]✦ A memory surfaces:[/color] %s" % [COL_ACCENT.to_html(), _memories[mid]])


# ---------------------------------------------------------------------------
# Relationships
# ---------------------------------------------------------------------------
func _aff_key(a: String, b: String) -> String:
	return (a + "|" + b) if a < b else (b + "|" + a)


func _get_aff(a: String, b: String) -> int:
	return int(_affinity.get(_aff_key(a, b), 50))


func _adjust_aff(a: String, b: String, delta: int) -> void:
	_affinity[_aff_key(a, b)] = clampi(_get_aff(a, b) + delta, 0, 100)


func _avg_bond() -> float:
	if _alters.size() < 2:
		return 50.0
	var total := 0
	var pairs := 0
	for i in range(_alters.size()):
		for j in range(i + 1, _alters.size()):
			total += _get_aff(_alters[i]["id"], _alters[j]["id"])
			pairs += 1
	return float(total) / float(pairs) if pairs > 0 else 50.0


# ---------------------------------------------------------------------------
# Conflict events (internal dialogue / mediation)
# ---------------------------------------------------------------------------
func _maybe_conflict() -> void:
	if _alters.size() < 2:
		return
	var worst_key := ""
	var worst_aff := 101
	var pa: Dictionary = {}
	var pb: Dictionary = {}
	for i in range(_alters.size()):
		for j in range(i + 1, _alters.size()):
			var aff := _get_aff(_alters[i]["id"], _alters[j]["id"])
			if aff < worst_aff:
				worst_aff = aff
				worst_key = _aff_key(_alters[i]["id"], _alters[j]["id"])
				pa = _alters[i]
				pb = _alters[j]
	if worst_aff < 42 and _rng.randf() < 0.6:
		_show_conflict(pa, pb)


func _show_conflict(a: Dictionary, b: Dictionary) -> void:
	_play_sfx(_sfx_low)
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_modal)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(center)

	var box := _panel(COL_PANEL)
	box.custom_minimum_size = Vector2(560, 0)
	center.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	box.add_child(v)

	v.add_child(_label("Inner Conflict", 22, COL_BAD))
	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.custom_minimum_size = Vector2(520, 0)
	body.text = "[color=%s][b]%s[/b] (%s) and [b]%s[/b] (%s) are clashing inside. The tension is raising everyone's stress.[/color]\n\n[i]As the manager, you can step in.[/i]" % [
		COL_TEXT.to_html(), a["name"], a["role"], b["name"], b["role"]]
	v.add_child(body)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	v.add_child(buttons)

	var mediate := Button.new()
	mediate.text = "Mediate  (+bond, costs energy)"
	mediate.custom_minimum_size = Vector2(0, 40)
	mediate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mediate.pressed.connect(_resolve_conflict.bind(a, b, true))
	buttons.add_child(mediate)

	var ignore := Button.new()
	ignore.text = "Let it pass  (bond frays)"
	ignore.custom_minimum_size = Vector2(0, 40)
	ignore.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ignore.pressed.connect(_resolve_conflict.bind(a, b, false))
	buttons.add_child(ignore)


func _resolve_conflict(a: Dictionary, b: Dictionary, mediate: bool) -> void:
	if mediate:
		_adjust_aff(a["id"], b["id"], 16)
		a["stress"] = clampi(int(a["stress"]) + 6, 0, 100)
		b["stress"] = clampi(int(b["stress"]) + 6, 0, 100)
		_log("[color=%s]You mediated between %s and %s.[/color] Hard words, then understanding — their bond grew." % [COL_GOOD.to_html(), a["name"], b["name"]])
	else:
		_adjust_aff(a["id"], b["id"], -6)
		a["stress"] = clampi(int(a["stress"]) + 10, 0, 100)
		b["stress"] = clampi(int(b["stress"]) + 10, 0, 100)
		_log("[color=%s]You let %s and %s sort it out alone.[/color] The rift widened, and the stress lingered." % [COL_BAD.to_html(), a["name"], b["name"]])
	if is_instance_valid(_modal):
		_modal.queue_free()
	_modal = null
	_refresh_all()


# ---------------------------------------------------------------------------
# Rules
# ---------------------------------------------------------------------------
func _success_chance(task: Dictionary, lead: Dictionary, support: Dictionary) -> float:
	var c := 0.5
	c += 0.13 * float(int(lead["skill_level"]) - int(task["difficulty"]))
	if lead["skill"] == task["skill"]:
		c += 0.15
	c -= 0.004 * float(lead["stress"])
	if not support.is_empty():
		c += 0.06 * float(int(support["skill_level"]) - int(task["difficulty"]))
		if support["skill"] == task["skill"]:
			c += 0.08
		c -= 0.002 * float(support["stress"])
		var aff := _get_aff(lead["id"], support["id"])
		c += (float(aff) - 50.0) / 100.0 * 0.3      # bond swing: -0.15 .. +0.15
	return clampf(c, 0.05, 0.97)


func _avg_stress() -> float:
	if _alters.is_empty():
		return 0.0
	var total := 0
	for a in _alters:
		total += int(a["stress"])
	return float(total) / float(_alters.size())


func _get_alter(id: String) -> Dictionary:
	for a in _alters:
		if a["id"] == id:
			return a
	return {}


# ---------------------------------------------------------------------------
# Player actions
# ---------------------------------------------------------------------------
func _on_task_selected(index: int) -> void:
	_click()
	_selected_task = index
	_refresh_tasks()
	_refresh_detail()


func _on_assign_pressed(alter_id: String) -> void:
	if _selected_task < 0:
		_log("[color=%s]Select a task first, then choose who takes it on.[/color]" % COL_DIM.to_html())
		return
	var alter := _get_alter(alter_id)
	if alter["action"] != "":
		return
	_click()
	var task: Dictionary = _today_tasks[_selected_task]
	if task["lead"] == "":
		task["lead"] = alter_id
		alter["action"] = "lead:%d" % _selected_task
	elif task["support"] == "" and task["lead"] != alter_id:
		task["support"] = alter_id
		alter["action"] = "support:%d" % _selected_task
	else:
		_log("[color=%s]%s is already covered. Select another task.[/color]" % [COL_DIM.to_html(), task["title"]])
		return
	_refresh_all()


func _on_rest_pressed(alter_id: String) -> void:
	_click()
	var alter := _get_alter(alter_id)
	_clear_assignment(alter)
	alter["action"] = "rest"
	_refresh_all()


func _on_train_pressed(alter_id: String) -> void:
	var alter := _get_alter(alter_id)
	if alter["action"] != "" or int(alter["skill_level"]) >= 5:
		return
	_click()
	alter["action"] = "train"
	_refresh_all()


func _on_clear_pressed(alter_id: String) -> void:
	_click()
	_clear_assignment(_get_alter(alter_id))   # frees any task slot and resets to idle
	_refresh_all()


func _clear_assignment(alter: Dictionary) -> void:
	var act: String = alter["action"]
	if act.begins_with("lead:") or act.begins_with("support:"):
		var parts := act.split(":")
		var ti := int(parts[1])
		if ti >= 0 and ti < _today_tasks.size():
			if parts[0] == "lead":
				_today_tasks[ti]["lead"] = ""
			else:
				_today_tasks[ti]["support"] = ""
	alter["action"] = ""


# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------
func _build_ui() -> void:
	theme = _make_theme()
	var bg := ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	# Header.
	var header := _panel(COL_PANEL)
	root.add_child(header)
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 16)
	header.add_child(hrow)
	var title := _label("Fragments of Self", 22, COL_ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.add_child(title)
	_hud_day = _label("Day 1 / %d" % MAX_DAYS, 16, COL_TEXT)
	hrow.add_child(_hud_day)
	_hud_mem = _label("Memories 0", 16, COL_TEXT)
	hrow.add_child(_hud_mem)
	_hud_bond = _label("Bond 50", 16, COL_TEXT)
	hrow.add_child(_hud_bond)
	_graph_btn = Button.new()
	_graph_btn.text = "Mind Graph"
	_graph_btn.pressed.connect(_toggle_view)
	hrow.add_child(_graph_btn)
	_audio_btn = Button.new()
	_audio_btn.text = "♪ On"
	_audio_btn.pressed.connect(_toggle_mute)
	hrow.add_child(_audio_btn)

	# System stress bar.
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 10)
	root.add_child(srow)
	srow.add_child(_label("System stress", 14, COL_DIM))
	_stress_bar = ProgressBar.new()
	_stress_bar.min_value = 0
	_stress_bar.max_value = 100
	_stress_bar.custom_minimum_size = Vector2(0, 22)
	_stress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	srow.add_child(_stress_bar)

	# View stack: management columns OR the mind graph occupy the same slot.
	_view_stack = Control.new()
	_view_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view_stack.clip_contents = true
	root.add_child(_view_stack)

	# Body: three columns.
	_body_row = HBoxContainer.new()
	_body_row.add_theme_constant_override("separation", 12)
	_body_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view_stack.add_child(_body_row)

	# Mind graph view (hidden until toggled).
	_graph_view = MindGraph.new()
	_graph_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_graph_view.visible = false
	_view_stack.add_child(_graph_view)

	# Left: inner system.
	var left := _panel(COL_PANEL)
	left.custom_minimum_size = Vector2(340, 0)
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_row.add_child(left)
	var left_v := VBoxContainer.new()
	left_v.add_theme_constant_override("separation", 8)
	left_v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(left_v)
	left_v.add_child(_label("Inner System", 18, COL_ACCENT))
	var alter_scroll := ScrollContainer.new()
	alter_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	alter_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_v.add_child(alter_scroll)
	_alters_box = VBoxContainer.new()
	_alters_box.add_theme_constant_override("separation", 8)
	_alters_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alter_scroll.add_child(_alters_box)

	# Center: today's tasks + detail.
	var center := _panel(COL_PANEL)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_row.add_child(center)
	var center_v := VBoxContainer.new()
	center_v.add_theme_constant_override("separation", 8)
	center_v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(center_v)
	center_v.add_child(_label("Today's World", 18, COL_ACCENT))
	_tasks_box = VBoxContainer.new()
	_tasks_box.add_theme_constant_override("separation", 8)
	center_v.add_child(_tasks_box)
	_detail_label = RichTextLabel.new()
	_detail_label.bbcode_enabled = true
	_detail_label.fit_content = true
	_detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_v.add_child(_detail_label)

	# Right: memories + bonds (scrollable).
	var right := _panel(COL_PANEL)
	right.custom_minimum_size = Vector2(310, 0)
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_row.add_child(right)
	var right_scroll := ScrollContainer.new()
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(right_scroll)
	var right_v := VBoxContainer.new()
	right_v.add_theme_constant_override("separation", 8)
	right_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(right_v)
	right_v.add_child(_label("Memory Fragments", 18, COL_ACCENT))
	_mem_label = RichTextLabel.new()
	_mem_label.bbcode_enabled = true
	_mem_label.fit_content = true
	_mem_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_v.add_child(_mem_label)
	right_v.add_child(_label("Bonds", 18, COL_ACCENT))
	_bonds_label = RichTextLabel.new()
	_bonds_label.bbcode_enabled = true
	_bonds_label.fit_content = true
	_bonds_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_v.add_child(_bonds_label)

	# Log.
	var log_panel := _panel(COL_CARD)
	log_panel.custom_minimum_size = Vector2(0, 150)
	root.add_child(log_panel)
	_log_label = RichTextLabel.new()
	_log_label.bbcode_enabled = true
	_log_label.scroll_following = true
	_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_panel.add_child(_log_label)

	# Footer.
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	root.add_child(footer)
	var hint := _label("Select task → Assign Lead → (optional) Assign Support → End Day", 13, COL_DIM)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(hint)

	var new_btn := Button.new()
	new_btn.text = "New Game"
	new_btn.pressed.connect(_new_game)
	footer.add_child(new_btn)
	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.pressed.connect(_save_game)
	footer.add_child(save_btn)
	var load_btn := Button.new()
	load_btn.text = "Load"
	load_btn.pressed.connect(_load_game)
	footer.add_child(load_btn)

	_endday_btn = Button.new()
	_endday_btn.text = "End Day  ▶"
	_endday_btn.custom_minimum_size = Vector2(150, 40)
	_endday_btn.pressed.connect(_end_day)
	footer.add_child(_endday_btn)

	_build_audio()


# ---------------------------------------------------------------------------
# UI refresh
# ---------------------------------------------------------------------------
func _toggle_view() -> void:
	_click()
	_graph_mode = not _graph_mode
	_body_row.visible = not _graph_mode
	_graph_view.visible = _graph_mode
	_graph_btn.text = "Management" if _graph_mode else "Mind Graph"
	if _graph_mode:
		_graph_view.refresh(_alters, _get_aff)


func _refresh_all() -> void:
	_refresh_hud()
	_refresh_alters()
	_refresh_tasks()
	_refresh_detail()
	_refresh_memories()
	_refresh_bonds()
	if _graph_mode and is_instance_valid(_graph_view):
		_graph_view.refresh(_alters, _get_aff)


func _refresh_hud() -> void:
	_hud_day.text = "Day %d / %d" % [_day, MAX_DAYS]
	_hud_mem.text = "Memories %d / %d" % [_discovered.size(), _memories.size()]
	_hud_bond.text = "Bond %d" % int(round(_avg_bond()))
	var avg := _avg_stress()
	_stress_bar.value = avg
	var fill := COL_GOOD
	if avg >= 75.0:
		fill = COL_BAD
	elif avg >= 50.0:
		fill = COL_ACCENT
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(4)
	_stress_bar.add_theme_stylebox_override("fill", sb)


func _refresh_alters() -> void:
	_clear(_alters_box)
	for alter in _alters:
		_alters_box.add_child(_make_alter_card(alter))


func _make_alter_card(alter: Dictionary) -> Control:
	var card := _panel(COL_CARD)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)

	v.add_child(_label("%s · %s" % [alter["name"], alter["role"]], 15, Color(alter["color"])))
	v.add_child(_label("%s  Lv %d   ·   Stress %d" % [alter["skill"], alter["skill_level"], alter["stress"]], 12, COL_DIM))

	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = alter["stress"]
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_GOOD if int(alter["stress"]) < 50 else (COL_ACCENT if int(alter["stress"]) < 75 else COL_BAD)
	sb.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", sb)
	v.add_child(bar)

	var status := _action_status(alter)
	v.add_child(_label(status if status != "" else " ", 12, COL_ACCENT))

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	v.add_child(actions)

	var busy: bool = alter["action"] != ""

	# First slot doubles as Assign (when free) or Clear (to undo a commitment).
	var first := Button.new()
	first.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if busy:
		first.text = "Clear"
		first.pressed.connect(_on_clear_pressed.bind(alter["id"]))
	else:
		first.text = "Assign"
		first.pressed.connect(_on_assign_pressed.bind(alter["id"]))
	actions.add_child(first)

	var rest := Button.new()
	rest.text = "Rest"
	rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rest.disabled = busy
	rest.pressed.connect(_on_rest_pressed.bind(alter["id"]))
	actions.add_child(rest)

	var train := Button.new()
	train.text = "Train"
	train.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	train.disabled = busy or int(alter["skill_level"]) >= 5
	train.pressed.connect(_on_train_pressed.bind(alter["id"]))
	actions.add_child(train)

	return card


func _action_status(alter: Dictionary) -> String:
	var act: String = alter["action"]
	if act == "rest":
		return "Resting"
	if act == "train":
		return "Training"
	if act.begins_with("lead:") or act.begins_with("support:"):
		var parts := act.split(":")
		var ti := int(parts[1])
		if ti >= 0 and ti < _today_tasks.size():
			var verb := "Leads" if parts[0] == "lead" else "Supports"
			return "%s → %s" % [verb, _today_tasks[ti]["title"]]
	return ""


func _refresh_tasks() -> void:
	_clear(_tasks_box)
	for i in range(_today_tasks.size()):
		_tasks_box.add_child(_make_task_card(i))


func _make_task_card(index: int) -> Control:
	var task: Dictionary = _today_tasks[index]
	var selected := index == _selected_task
	var card := _panel(COL_CARD_SEL if selected else COL_CARD)

	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(_on_task_selected.bind(index))
	card.add_child(btn)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	v.add_child(_label(task["title"], 16, COL_TEXT))
	v.add_child(_label("Needs: %s  (difficulty %d)" % [task["skill"], task["difficulty"]], 12, COL_DIM))
	var crew := _crew_line(task)
	if crew != "":
		v.add_child(_label(crew, 12, COL_GOOD))
	return card


func _crew_line(task: Dictionary) -> String:
	var parts := PackedStringArray()
	if task["lead"] != "":
		var l := _get_alter(task["lead"])
		if not l.is_empty():
			parts.append("Lead: " + l["name"])
	if task["support"] != "":
		var s := _get_alter(task["support"])
		if not s.is_empty():
			parts.append("Support: " + s["name"])
	return "   ".join(parts)


func _refresh_detail() -> void:
	if _selected_task < 0 or _selected_task >= _today_tasks.size():
		_detail_label.text = "[i][color=%s]Select a task above to see who fits it best.[/color][/i]" % COL_DIM.to_html()
		return
	var task: Dictionary = _today_tasks[_selected_task]
	var lines := PackedStringArray()
	lines.append("[b][color=%s]%s[/color][/b]" % [COL_ACCENT.to_html(), task["title"]])
	lines.append("[color=%s]%s[/color]" % [COL_DIM.to_html(), task["desc"]])
	lines.append("")

	var empty: Dictionary = {}
	if task["lead"] == "":
		lines.append("[b]Pick a Lead[/b] — solo success chance:")
		for alter in _alters:
			if alter["action"] != "":
				continue
			var ch := _success_chance(task, alter, empty)
			lines.append(_chance_line(alter, ch, alter["skill"] == task["skill"]))
	else:
		var lead := _get_alter(task["lead"])
		if task["support"] == "":
			var base := _success_chance(task, lead, empty)
			lines.append("[b]Lead:[/b] %s — [color=%s]%d%%[/color]" % [lead["name"], COL_TEXT.to_html(), _pct(base)])
			lines.append("")
			lines.append("[b]Add a Support voice[/b] — combined chance:")
			for alter in _alters:
				if alter["action"] != "" or alter["id"] == lead["id"]:
					continue
				var ch := _success_chance(task, lead, alter)
				var bond := _get_aff(lead["id"], alter["id"])
				lines.append("[color=%s]  %s — %d%%  (bond %d)[/color]" % [_chance_color(ch).to_html(), alter["name"], _pct(ch), bond])
		else:
			var support := _get_alter(task["support"])
			var ch := _success_chance(task, lead, support)
			var bond := _get_aff(lead["id"], support["id"])
			lines.append("[b]Lead:[/b] %s   [b]Support:[/b] %s" % [lead["name"], support["name"]])
			lines.append("[color=%s]Combined chance: %d%%[/color]   [color=%s]bond %d[/color]" % [_chance_color(ch).to_html(), _pct(ch), COL_DIM.to_html(), bond])
			if bond >= 60:
				lines.append("[color=%s]They lift each other up.[/color]" % COL_GOOD.to_html())
			elif bond <= 40:
				lines.append("[color=%s]Their friction is holding them back.[/color]" % COL_BAD.to_html())
	_detail_label.text = "\n".join(lines)


func _chance_line(alter: Dictionary, chance: float, star: bool) -> String:
	var tag := "  ★" if star else ""
	return "[color=%s]  %s — %d%%%s[/color]" % [_chance_color(chance).to_html(), alter["name"], _pct(chance), tag]


func _chance_color(chance: float) -> Color:
	return COL_GOOD if chance >= 0.65 else (COL_TEXT if chance >= 0.4 else COL_BAD)


func _pct(chance: float) -> int:
	return int(round(chance * 100.0))


func _refresh_memories() -> void:
	if _discovered.is_empty():
		_mem_label.text = "[i][color=%s]The past is still in fragments. Complete the right moments to remember.[/color][/i]" % COL_DIM.to_html()
		return
	var parts := PackedStringArray()
	for mid in _discovered:
		parts.append("[color=%s]✦[/color] %s" % [COL_ACCENT.to_html(), _memories[mid]])
	_mem_label.text = "\n\n".join(parts)


func _refresh_bonds() -> void:
	if _alters.size() < 2:
		_bonds_label.text = "[i][color=%s]Bonds form as alters work side by side.[/color][/i]" % COL_DIM.to_html()
		return
	var rows := []
	for i in range(_alters.size()):
		for j in range(i + 1, _alters.size()):
			var a: Dictionary = _alters[i]
			var b: Dictionary = _alters[j]
			rows.append({ "aff": _get_aff(a["id"], b["id"]), "a": a["name"], "b": b["name"] })
	rows.sort_custom(func(x, y): return x["aff"] > y["aff"])
	var parts := PackedStringArray()
	for r in rows:
		var col := COL_GOOD if r["aff"] >= 60 else (COL_BAD if r["aff"] <= 40 else COL_DIM)
		parts.append("[color=%s]%s ↔ %s   %d[/color]" % [col.to_html(), r["a"], r["b"], r["aff"]])
	_bonds_label.text = "\n".join(parts)


# ---------------------------------------------------------------------------
# Ending
# ---------------------------------------------------------------------------
func _show_ending() -> void:
	var avg := _avg_stress()
	var found := _discovered.size()
	var bond := _avg_bond()
	var title := ""
	var body := ""
	if found >= 5 and avg < 50.0 and bond >= 60.0:
		title = "Integration & Peace"
		body = "The system learned to work as one. The past is no longer a stranger, the bonds run deep, and no part carries the weight alone. The protagonist is whole — not by becoming one, but by becoming a team."
	elif found >= 3 and avg < 70.0 and bond >= 50.0:
		title = "Growing Stronger"
		body = "It wasn't easy, and the story isn't finished. But trust is building between the alters, and the protagonist is learning that being many can be a kind of strength."
	elif avg >= 80.0 or bond < 40.0:
		title = "Overwhelmed — For Now"
		body = "The days asked more than the system could give, and the bonds frayed under the strain. This is not the end of the story. Rest, support, and time are part of healing too."
	else:
		title = "Holding On"
		body = "Some days were survived rather than won — and that counts. The protagonist is still here, still trying, with parts that are learning to lean on each other."

	# Ending always shows in the management slot.
	if _graph_mode:
		_toggle_view()
	_graph_btn.disabled = true
	_clear(_body_row)
	_endday_btn.disabled = true

	var panel := _panel(COL_PANEL)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_row.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	v.add_child(_label("Ending: " + title, 26, COL_ACCENT))
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rt.text = "[color=%s]%s[/color]\n\n[color=%s]Memories recovered: %d / %d\nTasks handled: %d\nAverage bond: %d\nFinal system stress: %d%%[/color]" % [
		COL_TEXT.to_html(), body, COL_DIM.to_html(), found, _memories.size(), _tasks_completed, int(round(bond)), int(round(avg))]
	v.add_child(rt)
	v.add_child(_label("DID is real, and so is recovery. People with DID can and do live full lives.", 14, COL_GOOD))

	var again := Button.new()
	again.text = "Play Again"
	again.custom_minimum_size = Vector2(160, 42)
	again.pressed.connect(func(): get_tree().reload_current_scene())
	v.add_child(again)

	_refresh_hud()
	_log("[color=%s]The chapter closes. Ending reached: %s[/color]" % [COL_ACCENT.to_html(), title])


# ---------------------------------------------------------------------------
# Audio (procedural — soft, no sudden jerks, per the design doc)
# ---------------------------------------------------------------------------
func _build_audio() -> void:
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.volume_db = -8.0
	add_child(_sfx_player)
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.volume_db = -20.0
	add_child(_ambient_player)

	# A gentle UI tap.
	_sfx_click = _make_wav(0.06, 0.22, false, func(t): return sin(TAU * 660.0 * t) * exp(-t * 42.0))
	# A warm two-partial chime for memory unlocks.
	_sfx_chime = _make_wav(0.7, 0.30, false, func(t):
		return (sin(TAU * 528.0 * t) + 0.5 * sin(TAU * 792.0 * t)) * exp(-t * 3.5))
	# A soft mid tone marking the turn of a day.
	_sfx_tone = _make_wav(0.45, 0.26, false, func(t): return sin(TAU * 330.0 * t) * exp(-t * 5.0))
	# A low, non-alarming tone for conflict moments.
	_sfx_low = _make_wav(0.5, 0.30, false, func(t): return sin(TAU * 150.0 * t) * exp(-t * 4.5))
	# A quiet looping ambient pad (periodic over 2s for a seamless loop).
	var ambient := _make_wav(2.0, 0.5, true, func(t):
		var pad := (sin(TAU * 110.0 * t) + sin(TAU * 165.0 * t) + 0.6 * sin(TAU * 220.0 * t)) / 2.6
		var lfo := 0.6 + 0.4 * sin(TAU * 0.5 * t - PI / 2.0)
		return pad * lfo)
	_ambient_player.stream = ambient

	if not _muted and not _is_headless():
		_ambient_player.play()


func _make_wav(dur: float, vol: float, loop: bool, gen: Callable) -> AudioStreamWAV:
	var rate := 44100
	var n := int(dur * rate)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in range(n):
		var t := float(i) / float(rate)
		var s: float = clampf(float(gen.call(t)) * vol, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(s * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = n
	return w


func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


func _play_sfx(stream: AudioStream) -> void:
	if _muted or stream == null or _sfx_player == null or _is_headless():
		return
	_sfx_player.stream = stream
	_sfx_player.play()


func _click() -> void:
	_play_sfx(_sfx_click)


func _toggle_mute() -> void:
	_muted = not _muted
	_audio_btn.text = "♪ Off" if _muted else "♪ On"
	if _muted:
		_ambient_player.stop()
	elif not _is_headless():
		_ambient_player.play()


# ---------------------------------------------------------------------------
# Main menu
# ---------------------------------------------------------------------------
func _show_main_menu() -> void:
	_menu = Control.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_menu)

	var dim := ColorRect.new()
	dim.color = Color(COL_BG.r, COL_BG.g, COL_BG.b, 0.92)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(center)

	var box := _panel(COL_PANEL)
	box.custom_minimum_size = Vector2(480, 0)
	center.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	box.add_child(v)

	var title := _label("Fragments of Self", 40, COL_ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := _label("A story of many, living as one.", 16, COL_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	v.add_child(spacer)

	if _has_save():
		v.add_child(_menu_button("Continue", _menu_continue))
	v.add_child(_menu_button("New Game", _menu_new))
	v.add_child(_menu_button("Quit", func(): get_tree().quit()))

	var note := _label("An empathetic look at Dissociative Identity Disorder.", 12, COL_DIM)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(note)


func _menu_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 46)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(cb)
	return b


func _dismiss_menu() -> void:
	if is_instance_valid(_menu):
		_menu.queue_free()
	_menu = null


func _menu_new() -> void:
	_click()
	_dismiss_menu()
	_new_game()


func _menu_continue() -> void:
	_click()
	_dismiss_menu()
	_load_game()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
func _make_theme() -> Theme:
	var t := Theme.new()
	t.set_stylebox("normal", "Button", _sb(COL_CARD))
	t.set_stylebox("hover", "Button", _sb(COL_CARD_SEL))
	t.set_stylebox("pressed", "Button", _sb(COL_BG))
	t.set_stylebox("disabled", "Button", _sb(Color(0.22, 0.20, 0.24)))
	t.set_color("font_color", "Button", COL_TEXT)
	t.set_color("font_hover_color", "Button", COL_ACCENT)
	t.set_color("font_pressed_color", "Button", COL_ACCENT)
	t.set_color("font_disabled_color", "Button", COL_DIM)
	return t


func _sb(color: Color, radius: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 7
	s.content_margin_bottom = 7
	return s


func _show_fact() -> void:
	if _facts.is_empty():
		return
	var fact: String = _facts[_rng.randi_range(0, _facts.size() - 1)]
	_log("[color=%s]Did you know?[/color] [i]%s[/i]" % [COL_GOOD.to_html(), fact])


func _log(bbcode: String) -> void:
	_log_label.append_text(bbcode + "\n")


func _shuffle(arr: Array) -> void:
	# Fisher-Yates using the seeded RNG so playthroughs are reproducible.
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _panel(color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	return p
