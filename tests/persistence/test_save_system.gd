extends GutTest
## Round-trips RunState through SaveSystem's JSON file, including a
## mid-combat snapshot — the scenario the user needs "kill the app and
## resume" to work for.

var save_system: Node


func before_each() -> void:
	save_system = load("res://persistence/save_system.gd").new()
	save_system.delete_save()


func after_each() -> void:
	save_system.delete_save()
	save_system.free()


func _run_state(seed_value: int = 7) -> Node:
	var run_state: Node = load("res://state/run_state.gd").new()
	var character: CharacterData = ContentDatabase.character_data(&"revenant")
	run_state.start_new_run(character, seed_value)
	return run_state


func test_has_save_reflects_whether_a_file_exists() -> void:
	assert_false(save_system.has_save())
	save_system.save(_run_state())
	assert_true(save_system.has_save())


func test_round_trips_basic_run_state() -> void:
	var original: Node = _run_state(123)
	original.gold = 50
	original.act_number = 2
	original.current_hp = 41
	original.map_current_node_id = 4
	original.map_visited_node_ids = [0, 2, 4]
	save_system.save(original)

	var restored: Node = load("res://state/run_state.gd").new()
	assert_true(save_system.load_into(restored))

	assert_eq(restored.character_id, original.character_id)
	assert_eq(restored.run_seed, original.run_seed)
	assert_eq(restored.act_number, 2)
	assert_eq(restored.gold, 50)
	assert_eq(restored.current_hp, 41)
	assert_eq(restored.map_current_node_id, 4)
	assert_eq(restored.map_visited_node_ids, [0, 2, 4])
	assert_eq(restored.deck_card_ids, original.deck_card_ids)
	restored.free()
	original.free()


func test_round_trips_a_mid_combat_snapshot() -> void:
	var strike: CardDefinition = ContentDatabase.card_data(&"strike").to_definition()
	var deck := Deck.new()
	var rng := RNGStream.new(5)
	deck.setup_starting_deck([strike, strike, strike, strike, strike], rng)
	var player := PlayerState.new(70, 3)
	var enemy: EnemyState = ContentDatabase.enemy_data(&"grave_rat").to_enemy_state()
	var combat := CombatState.new(player, [enemy], deck, rng, 5)
	combat.start_combat()
	combat.player.take_damage(9)

	var original: Node = _run_state(11)
	original.combat_snapshot = CombatSnapshot.capture(combat)
	save_system.save(original)

	var restored: Node = load("res://state/run_state.gd").new()
	assert_true(save_system.load_into(restored))
	assert_true(restored.is_in_combat())

	var resumed_combat: CombatState = CombatSnapshot.restore(restored.combat_snapshot)
	assert_eq(resumed_combat.player.current_hp, 61)
	assert_eq(resumed_combat.deck.hand.size(), combat.deck.hand.size())
	restored.free()
	original.free()


func test_load_into_returns_false_when_there_is_no_save() -> void:
	var run_state: Node = load("res://state/run_state.gd").new()
	assert_false(save_system.load_into(run_state))
	run_state.free()
