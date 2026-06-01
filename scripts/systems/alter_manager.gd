class_name AlterManager
extends RefCounted
## Loads and tracks the alters for the run. Stress changes route through EventBus so
## the graph view and HUD can react without direct coupling.

const ALTERS_PATH: String = "res://data/alters.json"

var alters: Dictionary = {}        # id -> Alter
var order: Array[String] = []      # preserves authored order


func load_data() -> void:
	alters.clear()
	order.clear()
	var data := JsonLoader.load_dict(ALTERS_PATH)
	for entry in data.get("alters", []):
		var a := Alter.from_dict(entry as Dictionary)
		alters[a.id] = a
		order.append(a.id)
		# Snapshot starting stress for the day-end summary.
		if not GameState.stress_before.has(a.id):
			GameState.stress_before[a.id] = a.stress


func get_alter(alter_id: String) -> Alter:
	return alters.get(alter_id, null)


func adjust_stress(alter_id: String, delta: int) -> void:
	var a: Alter = get_alter(alter_id)
	if a == null:
		return
	a.stress = clampi(a.stress + delta, 0, 100)
	EventBus.alter_stress_changed.emit(alter_id, a.stress)
