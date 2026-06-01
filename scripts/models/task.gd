class_name Task
extends RefCounted
## An external-world situation the player must assign an alter to handle.

var id: String = ""
var title: String = ""
var prompt: String = ""
var required_skill: String = ""
var time_cost: int = 0
var outcomes: Dictionary = {}        # alter_id -> {tier, align, branch}
var default_branch: String = ""


static func from_dict(task_id: String, d: Dictionary) -> Task:
	var t := Task.new()
	t.id = task_id
	t.title = d.get("title", "")
	t.prompt = d.get("prompt", "")
	t.required_skill = d.get("required_skill", "")
	t.time_cost = int(d.get("time_cost", 0))
	t.outcomes = d.get("outcomes", {})
	t.default_branch = d.get("default_branch", "")
	return t


## Returns the outcome dict for the chosen alter, or a synthesized default.
func outcome_for(alter_id: String) -> Dictionary:
	if outcomes.has(alter_id):
		return outcomes[alter_id]
	return {"tier": "ok", "align": 0, "branch": default_branch}
