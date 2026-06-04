extends Control
## Dev-only preview: drops straight into the memory-reassembly mini-game so it can be
## seen/screenshotted without playing a full day. Not shipped. Emits memory_unlocked
## for a sample memory after the overlay has connected.

func _ready() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.16, 0.12, 0.13)
	add_child(bg)
	var mr: Control = load("res://scenes/ui/memory_reveal.tscn").instantiate()
	add_child(mr)
	await get_tree().process_frame
	await get_tree().process_frame
	EventBus.memory_unlocked.emit("m_treehouse")
