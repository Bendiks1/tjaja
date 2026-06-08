extends GutTest
## Confirms EnemyData.to_enemy_state() builds a working, independent EnemyState
## per call (shared move-pattern data must not leak shared mutable state).

func _sample_enemy_data() -> EnemyData:
	var data := EnemyData.new()
	data.id = &"grave_rat"
	data.display_name = "Grave Rat"
	data.max_hp = 18
	data.move_pattern = [
		{"kind": EnemyIntent.Kind.ATTACK, "value": 5},
		{"kind": EnemyIntent.Kind.DEFEND, "value": 4},
		{"kind": EnemyIntent.Kind.DEBUFF_PLAYER, "value": 1, "status": StatusTypes.Type.WEAK},
	]
	return data


func test_to_enemy_state_carries_over_identity_and_hp() -> void:
	var state: EnemyState = _sample_enemy_data().to_enemy_state()
	assert_eq(state.enemy_id, &"grave_rat")
	assert_eq(state.max_hp, 18)
	assert_eq(state.current_hp, 18)


func test_move_pattern_converts_in_order_and_loops() -> void:
	var state: EnemyState = _sample_enemy_data().to_enemy_state()

	assert_eq(state.current_intent.kind, EnemyIntent.Kind.ATTACK)
	assert_eq(state.current_intent.value, 5)

	state.advance_intent()
	assert_eq(state.current_intent.kind, EnemyIntent.Kind.DEFEND)

	state.advance_intent()
	assert_eq(state.current_intent.kind, EnemyIntent.Kind.DEBUFF_PLAYER)
	assert_eq(state.current_intent.status, StatusTypes.Type.WEAK)

	state.advance_intent()
	assert_eq(state.current_intent.kind, EnemyIntent.Kind.ATTACK, "pattern should loop back to the start")


func test_each_call_produces_an_independent_state() -> void:
	var data: EnemyData = _sample_enemy_data()
	var first: EnemyState = data.to_enemy_state()
	var second: EnemyState = data.to_enemy_state()

	first.take_damage(10)
	first.advance_intent()

	assert_eq(second.current_hp, 18, "damaging one instance must not affect another")
	assert_eq(second.current_intent.kind, EnemyIntent.Kind.ATTACK, "advancing one instance's pattern must not affect another")
