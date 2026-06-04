class_name TestCase
extends Node
## Base class for the headless test suites in tools/tests/. A suite extends this
## and adds `test_*` methods; the runner (test_runner.gd) discovers and executes
## them. Each test method starts from a clean slate via before_each().

var passes: int = 0
var failures: int = 0
var _current_test: String = ""


## Reset shared global state so tests stay order-independent. Override to add
## suite-specific setup (call super() first).
func before_each() -> void:
	GameState.reset_run()
	RNG.set_seed(RNG.DEFAULT_SEED)
	GameClock.reset_day()


## Run every `test_*` method on this suite, with a fresh slate before each.
func run() -> void:
	print("--- %s" % get_script().resource_path.get_file())
	for m in get_method_list():
		var name: String = m.get("name", "")
		if not name.begins_with("test_"):
			continue
		_current_test = name
		before_each()
		call(name)


# --- Assertions ---

func check(label: String, condition: bool) -> void:
	if condition:
		passes += 1
		print("PASS: [%s] %s" % [_current_test, label])
	else:
		failures += 1
		print("FAIL: [%s] %s" % [_current_test, label])


func check_eq(label: String, got: Variant, want: Variant) -> void:
	if got == want:
		passes += 1
		print("PASS: [%s] %s" % [_current_test, label])
	else:
		failures += 1
		print("FAIL: [%s] %s — got %s, want %s" % [_current_test, label, got, want])


## Floating-point equality within a tolerance.
func check_near(label: String, got: float, want: float, eps: float = 0.0001) -> void:
	if absf(got - want) <= eps:
		passes += 1
		print("PASS: [%s] %s" % [_current_test, label])
	else:
		failures += 1
		print("FAIL: [%s] %s — got %f, want %f" % [_current_test, label, got, want])
