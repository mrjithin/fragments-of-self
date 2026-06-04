extends Node
## Discovers and runs every test suite in tools/tests/ (files named test_*.gd
## extending TestCase, excluding the harness itself).
## Run: godot --headless --path . res://tools/tests/test_runner.tscn
## Exit code = number of failed checks (capped), so CI can gate on it.

const TESTS_DIR: String = "res://tools/tests/"
const HARNESS: Array[String] = ["test_case.gd", "test_runner.gd"]


func _ready() -> void:
	var suites: Array[String] = _suite_files()
	var passes: int = 0
	var failures: int = 0
	for f in suites:
		var script: GDScript = load(TESTS_DIR + f)
		var case: TestCase = script.new()
		add_child(case)
		case.run()
		passes += case.passes
		failures += case.failures
		case.queue_free()
	print("=== tests done: %d suites, %d passed, %d failed ===" % [suites.size(), passes, failures])
	get_tree().quit(mini(failures, 100))


func _suite_files() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(TESTS_DIR)
	if dir == null:
		push_error("test_runner: cannot open %s" % TESTS_DIR)
		return out
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd") and not HARNESS.has(f):
			out.append(f)
	out.sort()
	return out
