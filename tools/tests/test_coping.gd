extends TestCase
## Coping (outcome uncertainty): falter odds composition, the hidden-trigger rule,
## odds bands, tier demotion — plus AlterManager stress tracking.

var _mgr: RelationshipManager


func before_each() -> void:
	super()
	_mgr = RelationshipManager.new()
	_mgr.load_data()


func _alter(id: String = "june", stress: int = 0, triggers: Array = []) -> Alter:
	var a := Alter.new()
	a.id = id
	a.stress = stress
	for t in triggers:
		a.triggers.append(str(t))
	return a


func _task(trigger: String = "") -> Task:
	var t := Task.new()
	t.id = "t"
	t.trigger = trigger
	return t


func test_no_risk_is_zero() -> void:
	check_near("calm, suited, healthy = 0", Coping.falter_chance(_alter(), _task(), _mgr), 0.0)


func test_null_safety() -> void:
	check_near("null alter = 0", Coping.falter_chance(null, _task(), _mgr), 0.0)
	check_near("null task = 0", Coping.falter_chance(_alter(), null, _mgr), 0.0)
	check_near("null rel mgr skips strain risk", Coping.falter_chance(_alter(), _task(), null), 0.0)


func test_individual_risks() -> void:
	check_near("trigger hit = P_TRIGGER",
		Coping.falter_chance(_alter("june", 0, ["noise"]), _task("noise"), _mgr), Coping.P_TRIGGER)
	check_near("stressed = P_STRESSED",
		Coping.falter_chance(_alter("june", Alter.STRESS_HIGH), _task(), _mgr), Coping.P_STRESSED)
	# iris carries the authored strained bond (iris|rowan @ 25).
	check_near("strained bond = P_STRAINED",
		Coping.falter_chance(_alter("iris"), _task(), _mgr), Coping.P_STRAINED)


func test_unmatched_trigger_is_safe() -> void:
	check_near("task trigger the alter lacks adds nothing",
		Coping.falter_chance(_alter("june", 0, ["crowds"]), _task("noise"), _mgr), 0.0)
	check_near("alter trigger the task lacks adds nothing",
		Coping.falter_chance(_alter("june", 0, ["noise"]), _task(), _mgr), 0.0)


func test_risks_stack_and_clamp() -> void:
	check_near("trigger + stressed stack",
		Coping.falter_chance(_alter("june", Alter.STRESS_HIGH, ["noise"]), _task("noise"), _mgr),
		Coping.P_TRIGGER + Coping.P_STRESSED)
	check_near("all three risks clamp to P_MAX",
		Coping.falter_chance(_alter("iris", Alter.STRESS_HIGH, ["noise"]), _task("noise"), _mgr),
		Coping.P_MAX)


func test_known_only_hides_undiscovered_trigger() -> void:
	var a := _alter("june", 0, ["noise"])
	var t := _task("noise")
	check_near("undiscovered trigger hidden from shown odds",
		Coping.falter_chance(a, t, _mgr, true), 0.0)
	GameState.discovered_triggers.append("noise")
	check_near("discovered trigger counts in shown odds",
		Coping.falter_chance(a, t, _mgr, true), Coping.P_TRIGGER)
	check_near("real roll always counts the trigger",
		Coping.falter_chance(a, t, _mgr, false), Coping.P_TRIGGER)


func test_band_labels() -> void:
	check_eq("no visible risk reads good",
		str(Coping.band(_alter(), _task(), _mgr).get("key")), "good")
	check_eq("stress alone reads dim",
		str(Coping.band(_alter("june", Alter.STRESS_HIGH), _task(), _mgr).get("key")), "dim")
	GameState.discovered_triggers.append("noise")
	check_eq("a known trigger reads warn",
		str(Coping.band(_alter("june", 0, ["noise"]), _task("noise"), _mgr).get("key")), "warn")
	check_eq("known trigger + stress reads bad",
		str(Coping.band(_alter("june", Alter.STRESS_HIGH, ["noise"]), _task("noise"), _mgr).get("key")), "bad")
	check_eq("a hidden trigger does not spoil the band",
		str(Coping.band(_alter("june", 0, ["crowds"]), _task("crowds"), _mgr).get("key")), "good")


func test_demote_tiers() -> void:
	check_eq("best demotes to ok", Coping.demote("best"), "ok")
	check_eq("ok demotes to strain", Coping.demote("ok"), "strain")
	check_eq("strain stays the floor", Coping.demote("strain"), "strain")
	check_eq("unknown tier lands on strain", Coping.demote("???"), "strain")


func test_alter_manager_stress() -> void:
	var am := AlterManager.new()
	am.load_data()
	check_eq("four alters loaded in order", am.order.size(), 4)
	var first: String = am.order[0]
	var spikes: Array = []
	var cb := func(_id: String, stress: int) -> void: spikes.append(stress)
	EventBus.alter_stress_changed.connect(cb)
	am.adjust_stress(first, 999)
	check_eq("stress capped at 100", am.get_alter(first).stress, 100)
	check_eq("cap written to GameState", int(GameState.alter_stress[first]), 100)
	am.adjust_stress(first, -999)
	check_eq("stress floored at 0", am.get_alter(first).stress, 0)
	am.adjust_stress("ghost", 10)
	EventBus.alter_stress_changed.disconnect(cb)
	check_eq("unknown alter is a no-op (two signals only)", spikes.size(), 2)
	# rowan ships at stress 80 — already over the rest threshold.
	check("authored overwhelmed alter detected", am.any_stressed())
	check("first_stressed finds rowan", am.first_stressed() != null and am.first_stressed().id == "rowan")
	am.adjust_stress("rowan", -999)
	check("calming everyone clears the scan", not am.any_stressed())


func test_alter_manager_restores_live_stress() -> void:
	GameState.alter_stress["iris"] = 77
	var am := AlterManager.new()
	am.load_data()
	check_eq("live stress wins over authored", am.get_alter("iris").stress, 77)
	check_eq("snapshot captures the restored value", int(GameState.stress_before["iris"]), 77)
