extends TestCase
## Content integrity: the JSON data files cross-reference each other (days ->
## situations -> tasks -> alters/branches, facts, memories, achievements), so a
## typo in authored content fails here instead of breaking mid-run.

const DATA := "res://data/"
const VALID_TIERS := ["best", "ok", "strain"]


func _situation_paths() -> Array[String]:
	var out: Array[String] = []
	var days: Dictionary = JsonLoader.load_dict(DATA + "days.json")
	for p in days.get("secondary_pool", []):
		if not out.has(str(p)):
			out.append(str(p))
	for d in days.get("days", []):
		for p in (d as Dictionary).get("tasks", []):
			if not out.has(str(p)):
				out.append(str(p))
	return out


func test_days_reference_existing_situations() -> void:
	for p in _situation_paths():
		check("situation file exists: %s" % p.get_file(), FileAccess.file_exists(p))


func test_day_setups_reference_real_alters_and_pairs() -> void:
	var alter_ids: Array[String] = []
	for a in JsonLoader.load_dict(DATA + "alters.json").get("alters", []):
		alter_ids.append(str((a as Dictionary).get("id", "")))
	var mgr := RelationshipManager.new()
	mgr.load_data()
	for d in JsonLoader.load_dict(DATA + "days.json").get("days", []):
		var setup: Dictionary = (d as Dictionary).get("setup", {})
		for aid in setup.get("stress", {}):
			check("setup stress targets a real alter: %s" % aid, alter_ids.has(str(aid)))
		for pair in setup.get("affinity", {}):
			var parts: PackedStringArray = str(pair).split("|")
			check("setup affinity targets a real bond: %s" % pair,
				parts.size() == 2 and mgr.get_between(parts[0], parts[1]) != null)


func test_situations_link_to_real_tasks_and_nodes() -> void:
	var tasks: Dictionary = JsonLoader.load_dict(DATA + "tasks.json").get("tasks", {})
	for p in _situation_paths():
		var s: Dictionary = JsonLoader.load_dict(p)
		var nodes: Dictionary = s.get("nodes", {})
		check("%s has nodes" % p.get_file(), not nodes.is_empty())
		check("%s start node exists" % p.get_file(), nodes.has(str(s.get("start", ""))))
		var tid: String = str(s.get("task_id", ""))
		if tid != "":
			check("%s task_id '%s' exists" % [p.get_file(), tid], tasks.has(tid))


func test_task_outcomes_are_coherent() -> void:
	var alter_ids: Array[String] = []
	var all_skills: Array[String] = []
	for a in JsonLoader.load_dict(DATA + "alters.json").get("alters", []):
		var ad: Dictionary = a as Dictionary
		alter_ids.append(str(ad.get("id", "")))
		for sk in ad.get("skills", []):
			if not all_skills.has(str(sk)):
				all_skills.append(str(sk))
	var tasks: Dictionary = JsonLoader.load_dict(DATA + "tasks.json").get("tasks", {})
	check("task library is non-empty", not tasks.is_empty())
	for tid in tasks:
		var t: Dictionary = tasks[tid]
		var skill: String = str(t.get("required_skill", ""))
		if skill != "":
			check("task '%s' skill '%s' held by some alter" % [tid, skill], all_skills.has(skill))
		check("task '%s' has a default branch" % tid, str(t.get("default_branch", "")) != "")
		for aid in t.get("outcomes", {}):
			check("task '%s' outcome alter '%s' exists" % [tid, aid], alter_ids.has(str(aid)))
			var o: Dictionary = t["outcomes"][aid]
			check("task '%s'/'%s' tier valid" % [tid, aid], VALID_TIERS.has(str(o.get("tier", ""))))
			check("task '%s'/'%s' names a branch" % [tid, aid], str(o.get("branch", "")) != "")


func test_outcome_branches_exist_in_their_situations() -> void:
	var tasks: Dictionary = JsonLoader.load_dict(DATA + "tasks.json").get("tasks", {})
	for p in _situation_paths():
		var s: Dictionary = JsonLoader.load_dict(p)
		var tid: String = str(s.get("task_id", ""))
		if tid == "" or not tasks.has(tid):
			continue
		var nodes: Dictionary = s.get("nodes", {})
		var t: Dictionary = tasks[tid]
		var branches: Array[String] = [str(t.get("default_branch", ""))]
		for aid in t.get("outcomes", {}):
			branches.append(str(t["outcomes"][aid].get("branch", "")))
		for b in branches:
			if b != "":
				check("branch '%s' exists in %s" % [b, p.get_file()], nodes.has(b))


func test_dialogue_effects_reference_real_content() -> void:
	var facts: Dictionary = JsonLoader.load_dict(DATA + "did_facts.json").get("facts", {})
	var memories: Dictionary = JsonLoader.load_dict(DATA + "memories.json").get("memories", {})
	var files: Array[String] = _situation_paths()
	files.append(DATA + "conflict_dialogue.json")
	for p in files:
		var nodes: Dictionary = JsonLoader.load_dict(p).get("nodes", {})
		for nid in nodes:
			var fx: Dictionary = (nodes[nid] as Dictionary).get("on_enter", {})
			var fact: String = str(fx.get("surface_fact", ""))
			if fact != "":
				check("fact '%s' (in %s) exists" % [fact, p.get_file()], facts.has(fact))
			var mem: String = str(fx.get("unlock_memory", ""))
			if mem != "":
				check("memory '%s' (in %s) exists" % [mem, p.get_file()], memories.has(mem))


func test_dialogue_graph_has_no_dangling_links() -> void:
	# Every node's `next` / choice target must be another node or a terminal
	# sentinel (ALL-CAPS ids like END_DAY are handled by the host scene).
	var files: Array[String] = _situation_paths()
	files.append(DATA + "conflict_dialogue.json")
	for p in files:
		var nodes: Dictionary = JsonLoader.load_dict(p).get("nodes", {})
		var dangling: Array[String] = []
		for nid in nodes:
			var n: Dictionary = nodes[nid]
			var targets: Array[String] = []
			if str(n.get("next", "")) != "":
				targets.append(str(n["next"]))
			for c in n.get("choices", []):
				var cd: Dictionary = c as Dictionary
				if cd.has("action"):
					continue   # handoff actions resolve in code, not the graph
				if str(cd.get("next", "")) != "":
					targets.append(str(cd["next"]))
			for tgt in targets:
				if not nodes.has(tgt) and tgt != tgt.to_upper():
					dangling.append("%s -> %s" % [nid, tgt])
		check("%s has no dangling links %s" % [p.get_file(), str(dangling) if not dangling.is_empty() else ""],
			dangling.is_empty())


func test_every_fact_is_reachable_in_dialogue() -> void:
	# "Aware" needs every fact; each must be carried by at least one situation node.
	var facts: Dictionary = JsonLoader.load_dict(DATA + "did_facts.json").get("facts", {})
	var carried: Array[String] = []
	for p in _situation_paths():
		var nodes: Dictionary = JsonLoader.load_dict(p).get("nodes", {})
		for nid in nodes:
			var fact: String = str((nodes[nid] as Dictionary).get("on_enter", {}).get("surface_fact", ""))
			if fact != "" and not carried.has(fact):
				carried.append(fact)
	for fid in facts:
		check("fact '%s' surfaces somewhere" % fid, carried.has(str(fid)))


func test_achievement_ids_match_the_evaluator() -> void:
	# Every authored badge id must have a condition in Achievements; otherwise it
	# can never be earned (the evaluator's match returns false for unknown ids).
	var known: Array[String] = ["integration", "held_together", "whole_picture", "aware", "mediator"]
	var defs: Array = JsonLoader.load_dict(DATA + "achievements.json").get("achievements", [])
	check_eq("five badges authored", defs.size(), 5)
	for d in defs:
		var id: String = str((d as Dictionary).get("id", ""))
		check("badge '%s' has an evaluator condition" % id, known.has(id))
		check("badge '%s' has display text" % id,
			str((d as Dictionary).get("title", "")) != "" and str((d as Dictionary).get("desc", "")) != "")


func test_core_memories_exist_for_whole_picture() -> void:
	var memories: Dictionary = JsonLoader.load_dict(DATA + "memories.json").get("memories", {})
	check("enough memories authored for The Whole Picture",
		memories.size() >= Achievements.CORE_MEMORIES)
	for mid in memories:
		var m: Dictionary = memories[mid]
		check("memory '%s' has a title and text" % mid,
			str(m.get("title", "")) != "" and str(m.get("text", "")) != "")
