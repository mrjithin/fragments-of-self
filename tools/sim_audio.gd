extends Node
## Headless check of scene-reactive ambient music: drives EventBus.scene_changed for
## each view and confirms Music crossfades to the matching track with no errors.
## Run: godot --headless res://tools/sim_audio.tscn

var _fail: int = 0


func _check(label: String, ok: bool) -> void:
	print(("PASS: " if ok else "FAIL: "), label)
	if not ok:
		_fail += 1


func _ready() -> void:
	print("=== sim_audio: per-scene ambience ===")
	await get_tree().process_frame
	_check("boots on the title track", Music._current_track.ends_with("ambient_title.tres"))

	for pair in [
		["res://scenes/external/task_board.tscn", "ambient_board.tres"],
		["res://scenes/external/external_world.tscn", "ambient_world.tres"],
		["res://scenes/internal/internal_mind.tscn", "ambient_mind.tres"],
		["res://scenes/ui/day_end_summary.tscn", "ambient_dayend.tres"],
		["res://scenes/ui/title_screen.tscn", "ambient_title.tres"],
	]:
		EventBus.scene_changed.emit(pair[0])
		await get_tree().process_frame
		_check("%s -> %s" % [pair[0].get_file(), pair[1]], Music._current_track.ends_with(pair[1]))
		_check("a player is audible for %s" % pair[1], Music._players[Music._active].playing)

	# Unmapped overlay path must NOT change the track.
	var before: String = Music._current_track
	EventBus.scene_changed.emit("res://scenes/ui/memory_reveal.tscn")
	await get_tree().process_frame
	_check("unmapped scene keeps current track", Music._current_track == before)

	print("=== sim_audio done, failures: %d ===" % _fail)
	get_tree().quit()
