extends GutTest

func test_same_seed_produces_same_sequence() -> void:
	var a := RNGStream.new(1234)
	var b := RNGStream.new(1234)
	for i in range(20):
		assert_eq(a.randi_range(0, 1000), b.randi_range(0, 1000), "stream %d should match" % i)


func test_different_seeds_diverge() -> void:
	var a := RNGStream.new(1)
	var b := RNGStream.new(2)
	var sequence_a: Array[int] = []
	var sequence_b: Array[int] = []
	for i in range(20):
		sequence_a.append(a.randi_range(0, 100000))
		sequence_b.append(b.randi_range(0, 100000))
	assert_ne(sequence_a, sequence_b, "different seeds should not produce identical sequences")


func test_randi_range_respects_bounds() -> void:
	var rng := RNGStream.new(99)
	for i in range(200):
		var value: int = rng.randi_range(3, 7)
		assert_between(value, 3, 7, "value should stay within [min, max]")


func test_shuffle_is_deterministic_for_same_seed() -> void:
	var values_a: Array = [1, 2, 3, 4, 5, 6, 7, 8]
	var values_b: Array = [1, 2, 3, 4, 5, 6, 7, 8]
	RNGStream.new(42).shuffle(values_a)
	RNGStream.new(42).shuffle(values_b)
	assert_eq(values_a, values_b, "same seed should shuffle identically")


func test_shuffle_preserves_all_elements() -> void:
	var values: Array = [1, 2, 3, 4, 5]
	RNGStream.new(7).shuffle(values)
	values.sort()
	assert_eq(values, [1, 2, 3, 4, 5], "shuffle must not lose or duplicate elements")


func test_state_can_be_saved_and_restored_to_resume_a_sequence() -> void:
	var original := RNGStream.new(555)
	original.randi_range(0, 100) # consume one value so state isn't the fresh-seed state
	var saved_state: int = original.get_state()
	var continued_value: int = original.randi_range(0, 100)

	var resumed := RNGStream.new(555)
	resumed.set_state(saved_state)
	assert_eq(resumed.randi_range(0, 100), continued_value, "restoring state should resume the same sequence")


func test_pick_returns_an_element_from_the_array() -> void:
	var values: Array = ["a", "b", "c"]
	var rng := RNGStream.new(3)
	for i in range(10):
		assert_has(values, rng.pick(values))
