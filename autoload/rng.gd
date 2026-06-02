extends Node
## Single seeded random source for the randomness system. STUBBED for the demo —
## the guided slice is deterministic — but present so the architecture stays honest
## and reproducible playthroughs are possible later (seed persists in the save).

const DEFAULT_SEED: int = 20260601

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var seed_value: int = DEFAULT_SEED


func _ready() -> void:
	set_seed(DEFAULT_SEED)


func set_seed(value: int) -> void:
	seed_value = value
	_rng.seed = value


func randi_range_inclusive(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


func randf_unit() -> float:
	return _rng.randf()


## Pick an index in [0, weights.size()) with probability proportional to its weight.
## Returns -1 for an empty list or non-positive total. Deterministic under the seed.
func weighted_pick(weights: Array) -> int:
	var total: float = 0.0
	for w in weights:
		total += maxf(0.0, float(w))
	if total <= 0.0:
		return -1
	var roll: float = _rng.randf() * total
	var acc: float = 0.0
	for i in weights.size():
		acc += maxf(0.0, float(weights[i]))
		if roll < acc:
			return i
	return weights.size() - 1
