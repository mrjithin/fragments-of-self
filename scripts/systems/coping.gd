class_name Coping
extends RefCounted
## Outcome uncertainty. A sent alter usually performs at their aptitude for a task,
## but RISK — high stress, a strained bond, or a task that hits their trigger — gives
## a real, seeded chance to *falter* a tier (worse branch, more stress). Safe, suited,
## calm play stays reliable; taking a risk is a genuine gamble. This is what removes
## the "obvious right answer" while keeping the run reproducible under the save seed.

const P_TRIGGER: float = 0.5
const P_STRESSED: float = 0.3
const P_STRAINED: float = 0.2
const P_MAX: float = 0.9


## Probability the alter falters from their aptitude on this task, given live state.
## When `known_only`, counts only risks the player can already see — a not-yet-learned
## trigger stays hidden, so the odds band doesn't spoil it (you learn it by living it).
static func falter_chance(alter: Alter, task: Task, rel_mgr: RelationshipManager, known_only: bool = false) -> float:
	if alter == null or task == null:
		return 0.0
	var p: float = 0.0
	if task.trigger != "" and alter.triggers.has(task.trigger):
		if not known_only or GameState.discovered_triggers.has(task.trigger):
			p += P_TRIGGER
	if alter.is_stressed():
		p += P_STRESSED
	if rel_mgr != null and rel_mgr.penalty_for(alter.id) < 0:
		p += P_STRAINED
	return clampf(p, 0.0, P_MAX)


## A coarse, human odds label for the card — never an exact number. Uses only what the
## player can see, so a hidden trigger can still surprise them.
static func band(alter: Alter, task: Task, rel_mgr: RelationshipManager) -> Dictionary:
	var p: float = falter_chance(alter, task, rel_mgr, true)
	if p <= 0.05:
		return {"text": "Reliable here", "key": "good"}
	elif p < 0.35:
		return {"text": "Some risk", "key": "dim"}
	elif p < 0.6:
		return {"text": "Risky", "key": "warn"}
	return {"text": "Very risky", "key": "bad"}


## One tier worse: best -> ok -> strain (strain is the floor; faltering there just
## piles on stress toward a breaking point).
static func demote(tier: String) -> String:
	match tier:
		"best": return "ok"
		"ok": return "strain"
		_: return "strain"
