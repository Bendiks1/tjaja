extends GutTest

func test_plain_damage_passes_through() -> void:
	assert_eq(DamageResolver.calculate_attack_damage(10, 0, false, false), 10)


func test_strength_adds_flat_damage() -> void:
	assert_eq(DamageResolver.calculate_attack_damage(6, 3, false, false), 9)


func test_negative_total_floors_at_zero() -> void:
	assert_eq(DamageResolver.calculate_attack_damage(2, -10, false, false), 0)


func test_weak_reduces_damage_by_25_percent_rounded_down() -> void:
	# (10 + 0) * 0.75 = 7.5 -> floor 7
	assert_eq(DamageResolver.calculate_attack_damage(10, 0, true, false), 7)


func test_vulnerable_increases_damage_by_50_percent_rounded_down() -> void:
	# (10 + 0) * 1.5 = 15
	assert_eq(DamageResolver.calculate_attack_damage(10, 0, false, true), 15)


func test_weak_and_vulnerable_stack_multiplicatively_in_order() -> void:
	# base 8 + strength 2 = 10; *0.75 = 7.5; *1.5 = 11.25 -> floor 11
	assert_eq(DamageResolver.calculate_attack_damage(8, 2, true, true), 11)


func test_block_amount_adds_dexterity() -> void:
	assert_eq(DamageResolver.calculate_block_amount(5, 2), 7)


func test_block_amount_floors_at_zero() -> void:
	assert_eq(DamageResolver.calculate_block_amount(3, -10), 0)
