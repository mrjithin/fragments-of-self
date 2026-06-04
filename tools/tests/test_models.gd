extends TestCase
## Data models: from_dict hydration, defaults on missing keys, and helpers.


func test_alter_from_dict() -> void:
	var a := Alter.from_dict({
		"id": "iris", "name": "Iris", "role": "protector",
		"skills": ["calm", "boundaries"], "stress": 30,
		"triggers": ["conflict"], "color": "#aa3355",
		"graph_pos": {"x": 1.5, "y": -2.0},
	})
	check_eq("id", a.id, "iris")
	check_eq("skills hydrated", a.skills, ["calm", "boundaries"])
	check_eq("stress int", a.stress, 30)
	check_eq("graph pos", a.graph_pos, Vector2(1.5, -2.0))
	check("has_skill true", a.has_skill("calm"))
	check("has_skill false", not a.has_skill("piloting"))


func test_alter_defaults_and_stress_boundary() -> void:
	var a := Alter.from_dict({})
	check("defaults are empty/zero", a.id == "" and a.skills.is_empty() and a.stress == 0)
	a.stress = Alter.STRESS_HIGH - 1
	check("below threshold not stressed", not a.is_stressed())
	a.stress = Alter.STRESS_HIGH
	check("at threshold stressed", a.is_stressed())


func test_task_outcomes() -> void:
	var t := Task.from_dict("t1", {
		"title": "T", "required_skill": "calm", "trigger": "noise", "time_cost": 25,
		"outcomes": {
			"iris": {"tier": "best", "align": 2, "branch": "iris_best"},
			"rowan": {"tier": "strain", "align": 0, "branch": "rowan_strain"},
		},
		"default_branch": "generic",
	})
	check_eq("id from arg", t.id, "t1")
	check_eq("time cost int", t.time_cost, 25)
	check_eq("authored outcome", str(t.outcome_for("iris").get("tier")), "best")
	var fallback: Dictionary = t.outcome_for("june")
	check("fallback outcome is ok-tier on default branch",
		str(fallback.get("tier")) == "ok" and str(fallback.get("branch")) == "generic")
	check_eq("branch for authored tier", t.branch_for_tier("strain"), "rowan_strain")
	check_eq("branch for unauthored tier falls back", t.branch_for_tier("ok"), "generic")


func test_relationship_helpers() -> void:
	var r := Relationship.from_dict({"from": "iris", "to": "rowan", "affinity": 35})
	check_eq("affinity int", r.affinity, 35)
	check_eq("status defaults healthy", r.status, "healthy")
	check("involves both ends", r.involves("iris") and r.involves("rowan"))
	check("involves rejects others", not r.involves("june"))
	check("matches pair either order", r.matches_pair("iris", "rowan") and r.matches_pair("rowan", "iris"))
	check("rejects wrong pair", not r.matches_pair("iris", "june"))
	check_eq("key format", r.key(), "iris:rowan")


func test_dialogue_node() -> void:
	var n := DialogueNode.from_dict("n1", {
		"speaker": "Iris", "text": "hi", "next": "n2",
		"on_enter": {"align": 1},
		"choices": [{"text": "go", "next": "n3"}],
	})
	check_eq("id from arg", n.id, "n1")
	check_eq("on_enter carried", int(n.on_enter.get("align", 0)), 1)
	check("has_choices true", n.has_choices())
	var linear := DialogueNode.from_dict("n2", {"next": "n3"})
	check("linear node has no choices", not linear.has_choices())


func test_game_event_day_gating() -> void:
	var e := GameEvent.from_dict({"id": "ev", "weight": 2, "min_day": 2, "max_day": 4})
	check("before window", not e.available_on(1))
	check("window start", e.available_on(2))
	check("window end", e.available_on(4))
	check("after window", not e.available_on(5))
	var open := GameEvent.from_dict({"id": "ev2"})
	check("defaults: open from day 1", open.available_on(1) and open.available_on(999))
	var neg := GameEvent.from_dict({"id": "ev3", "weight": -5})
	check_near("negative weight floored to 0", neg.weight, 0.0)


func test_memory_fragment() -> void:
	var m := MemoryFragment.from_dict("m1", {
		"title": "The Porch", "text": "whole text",
		"fragments": ["a", "b", "c"], "image": "res://x.png", "mystery_tag": "origin",
	})
	check_eq("id from arg", m.id, "m1")
	check_eq("ordered fragments", m.fragments, ["a", "b", "c"])
	check_eq("image path", m.image, "res://x.png")
	var bare := MemoryFragment.from_dict("m2", {})
	check("defaults empty", bare.title == "" and bare.fragments.is_empty() and bare.image == "")
