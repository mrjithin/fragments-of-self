extends SceneTree
## Headless validation: instantiate every scene with autoloads available and report
## any errors. Run with: godot --headless -s res://tools/validate_scenes.gd
## NOTE: development-only utility, not shipped in the game.

const SCENES: Array[String] = [
	"res://scenes/ui/title_screen.tscn",
	"res://scenes/external/external_world.tscn",
	"res://scenes/internal/internal_mind.tscn",
	"res://scenes/ui/day_end_summary.tscn",
	"res://scenes/ui/dialogue_box.tscn",
	"res://scenes/ui/hud.tscn",
	"res://scenes/ui/memory_reveal.tscn",
	"res://scenes/ui/did_fact_popup.tscn",
	"res://scenes/internal/alter_node.tscn",
	"res://scenes/internal/alter_card.tscn",
]


func _initialize() -> void:
	var failures: int = 0
	for path in SCENES:
		var packed: PackedScene = load(path)
		if packed == null:
			print("FAIL load: ", path)
			failures += 1
			continue
		var inst: Node = packed.instantiate()
		if inst == null:
			print("FAIL instantiate: ", path)
			failures += 1
			continue
		get_root().add_child(inst)
		await process_frame
		await process_frame
		inst.queue_free()
		print("OK: ", path)
	print("=== validation complete, failures: ", failures, " ===")
	quit(failures)
