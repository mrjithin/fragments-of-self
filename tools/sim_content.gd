extends Node
## Content integrity: every task situation referenced by days.json loads, points at a
## real task, and every outcome tier (best/ok/strain) resolves to a real branch node.
## Catches a mistyped path or branch the moment content is added.
## Run: godot --headless res://tools/sim_content.tscn

var _fail: int = 0


func _check(label: String, ok: bool) -> void:
	print(("PASS: " if ok else "FAIL: "), label)
	if not ok:
		_fail += 1


func _ready() -> void:
	print("=== sim_content: every day's tasks load & resolve ===")
	var tasks: Dictionary = JsonLoader.load_dict("res://data/tasks.json").get("tasks", {})
	var days: Array = JsonLoader.load_dict("res://data/days.json").get("days", [])
	_check("days configured", days.size() >= 4)

	for di in days.size():
		var paths: Array = (days[di] as Dictionary).get("tasks", [])
		_check("day %d offers at least one task" % (di + 1), paths.size() >= 1)
		for p in paths:
			var sit: Dictionary = JsonLoader.load_dict(str(p))
			var nodes: Dictionary = sit.get("nodes", {})
			var tid: String = str(sit.get("task_id", ""))
			_check("%s has a valid start node" % p, sit.has("start") and nodes.has(str(sit["start"])))
			_check("%s -> task '%s' exists" % [p, tid], tasks.has(tid))
			if tasks.has(tid):
				var t := Task.from_dict(tid, tasks[tid])
				for tier in ["best", "ok", "strain"]:
					var br: String = t.branch_for_tier(tier)
					_check("%s tier '%s' -> real branch node" % [tid, tier], br != "" and nodes.has(br))

	print("=== sim_content done, failures: %d ===" % _fail)
	get_tree().quit(_fail)
