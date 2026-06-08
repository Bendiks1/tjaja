class_name RNGStream
extends RefCounted
## Deterministic RNG wrapper. Two streams created with the same seed produce
## identical sequences, including identical shuffles — required for seeded
## daily runs and for save/resume (the stream's state is part of run state).

var _rng: RandomNumberGenerator

func _init(seed_value: int = 0) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_value


func get_seed() -> int:
	return _rng.seed


## Full internal state, including how many numbers have been consumed.
## Save this (not just the seed) to resume mid-sequence after a reload.
func get_state() -> int:
	return _rng.state


func set_state(state_value: int) -> void:
	_rng.state = state_value


func randi_range(min_value: int, max_value: int) -> int:
	return _rng.randi_range(min_value, max_value)


func randf() -> float:
	return _rng.randf()


## True with the given probability in [0.0, 1.0].
func chance(probability: float) -> bool:
	return _rng.randf() < probability


## Returns a random element without modifying the array. Errors on an empty array.
func pick(values: Array) -> Variant:
	assert(not values.is_empty(), "Cannot pick from an empty array")
	return values[_rng.randi_range(0, values.size() - 1)]


## In-place Fisher-Yates shuffle driven by this stream, so the result is
## reproducible — Array.shuffle() uses the engine's global RNG and must not
## be used anywhere runs need to be deterministic.
func shuffle(values: Array) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var temp: Variant = values[i]
		values[i] = values[j]
		values[j] = temp
