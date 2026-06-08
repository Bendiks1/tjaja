extends GutTest

var combatant: CombatantState

func before_each() -> void:
	combatant = CombatantState.new(50)


func test_starts_at_full_hp() -> void:
	assert_eq(combatant.current_hp, 50)
	assert_eq(combatant.max_hp, 50)
	assert_true(combatant.is_alive())


func test_take_damage_reduces_hp() -> void:
	var hp_lost: int = combatant.take_damage(12)
	assert_eq(hp_lost, 12)
	assert_eq(combatant.current_hp, 38)


func test_block_absorbs_damage_before_hp() -> void:
	combatant.add_block(10)
	var hp_lost: int = combatant.take_damage(6)
	assert_eq(hp_lost, 0, "damage fully absorbed by block should not touch HP")
	assert_eq(combatant.block, 4, "remaining block after partial absorption")
	assert_eq(combatant.current_hp, 50)


func test_damage_overflows_through_block_into_hp() -> void:
	combatant.add_block(5)
	var hp_lost: int = combatant.take_damage(8)
	assert_eq(combatant.block, 0)
	assert_eq(hp_lost, 3)
	assert_eq(combatant.current_hp, 47)


func test_hp_cannot_go_below_zero() -> void:
	var hp_lost: int = combatant.take_damage(999)
	assert_eq(hp_lost, 50)
	assert_eq(combatant.current_hp, 0)
	assert_false(combatant.is_alive())


func test_heal_cannot_exceed_max_hp() -> void:
	combatant.take_damage(10)
	combatant.heal(999)
	assert_eq(combatant.current_hp, 50)


func test_reset_block_clears_to_zero() -> void:
	combatant.add_block(20)
	combatant.reset_block()
	assert_eq(combatant.block, 0)


func test_add_status_accumulates_stacks() -> void:
	combatant.add_status(StatusTypes.Type.STRENGTH, 2)
	combatant.add_status(StatusTypes.Type.STRENGTH, 3)
	assert_eq(combatant.get_status(StatusTypes.Type.STRENGTH), 5)


func test_add_status_with_negative_removes_stacks_and_drops_at_zero() -> void:
	combatant.add_status(StatusTypes.Type.VULNERABLE, 2)
	combatant.add_status(StatusTypes.Type.VULNERABLE, -2)
	assert_eq(combatant.get_status(StatusTypes.Type.VULNERABLE), 0)
	assert_false(combatant.has_status(StatusTypes.Type.VULNERABLE))
	assert_false(combatant.statuses.has(StatusTypes.Type.VULNERABLE), "zero-stack statuses should be removed, not stored as zero")


func test_decay_debuffs_reduces_vulnerable_and_weak_by_one() -> void:
	combatant.add_status(StatusTypes.Type.VULNERABLE, 2)
	combatant.add_status(StatusTypes.Type.WEAK, 1)
	combatant.decay_debuffs()
	assert_eq(combatant.get_status(StatusTypes.Type.VULNERABLE), 1)
	assert_eq(combatant.get_status(StatusTypes.Type.WEAK), 0)


func test_decay_debuffs_does_not_affect_strength_or_dexterity() -> void:
	combatant.add_status(StatusTypes.Type.STRENGTH, 3)
	combatant.add_status(StatusTypes.Type.DEXTERITY, 2)
	combatant.decay_debuffs()
	assert_eq(combatant.get_status(StatusTypes.Type.STRENGTH), 3)
	assert_eq(combatant.get_status(StatusTypes.Type.DEXTERITY), 2)
