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
