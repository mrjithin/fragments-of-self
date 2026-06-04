extends Node
## Headless check of the Codex/Journal: its tabs reflect exactly what the run has
## discovered, and an alter's trigger stays hidden until it has been lived through.
## Run: godot --headless res://tools/sim_codex.tscn

var _failures: int = 0


func _check(label: String, condition: bool) -> void:
	if condition:
		print("PASS: ", label)
	else:
		print("FAIL: ", label)
		_failures += 1


func _ready() -> void:
	GameState.reset_run()
	GameState.record_memory("m_treehouse")
	GameState.record_memory("m_porch")
	GameState.record_fact("f_switching")
	GameState.discovered_triggers.append("deadlines")   # Rowan's, now learned
	GameState.ending_alignment = 6                        # earns "Integration"
	GameState.bonds_mended = 1                            # earns "Mediator"

	var codex: Control = load("res://scenes/ui/codex.tscn").instantiate()
	add_child(codex)
	await get_tree().process_frame
	_check("the Journal builds all four tabs without crashing", is_instance_valid(codex))

	var mem: Control = codex._build_memories()
	_check("Memories tab lists each recovered memory", _count_entries(mem) == 2)

	var facts: Control = codex._build_facts()
	_check("DID Facts tab lists each learned fact", _count_entries(facts) == 1)

	var sys: Control = codex._build_system()
	_check("The System tab lists the 3 alters (manager excluded)", _count_entries(sys) == 3)

	var sys_text: String = _all_text(sys)
	_check("a discovered trigger is shown", sys_text.contains("Known trigger: deadlines"))
	_check("an undiscovered trigger stays hidden", sys_text.contains("not yet known"))

	# Milestones tab reflects the mid-run Achievements.earned() (Integration and
	# Mediator; Held Together stays locked until the run's final evaluation).
	var mile: Control = codex._build_achievements()
	var mile_text: String = _all_text(mile)
	_check("Milestones tab lists every achievement", _count_entries(mile) >= 5)
	_check("Milestones marks an earned badge (Integration ★)", mile_text.contains("★  Integration"))
	_check("Milestones marks an unearned badge (Aware ☆)", mile_text.contains("☆  Aware"))
	_check("Milestones locks 'Held Together' mid-run", mile_text.contains("☆  Held Together"))

	# Nothing discovered -> empty-state copy, not a crash.
	GameState.reset_run()
	var empty: Control = codex._build_memories()
	_check("empty Memories tab shows guidance, no entries", _count_entries(empty) == 0)

	codex.queue_free()
	print("=== sim_codex done, failures: ", _failures, " ===")
	get_tree().quit(_failures)


## Count the entry cards (PanelContainers) under a tab section.
func _count_entries(node: Node) -> int:
	var n: int = 0
	for c in node.get_children():
		if c is PanelContainer:
			n += 1
	return n


## Flatten all Label text under a node, for asserting on shown copy.
func _all_text(node: Node) -> String:
	var out: String = ""
	if node is Label:
		out += (node as Label).text + "\n"
	for c in node.get_children():
		out += _all_text(c)
	return out
