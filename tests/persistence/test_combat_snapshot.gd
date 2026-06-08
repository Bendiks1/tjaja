extends GutTest
## Round-trips a live CombatState through capture()/restore() and checks the
## restored fight behaves identically — the actual guarantee a mid-combat
## save/resume needs, not just that the data shapes match.

func _build_combat(rng_seed: int = 1) -> CombatState:
	var strike: CardDefinition = ContentDatabase.card_data(&"strike").to_definition()
	var defend: CardDefinition = ContentDatabase.card_data(&"defend").to_definition()
	var definitions: Array[CardDefinition] = []
	for i in range(5):
		definitions.append(strike)
	for i in range(4):
		definitions.append(defend)

	var deck := Deck.new()
	var rng := RNGStream.new(rng_seed)
	deck.setup_starting_deck(definitions, rng)

	var player := PlayerState.new(70, 3)
	var enemy: EnemyState = ContentDatabase.enemy_data(&"grave_rat").to_enemy_state()
	var combat := CombatState.new(player, [enemy], deck, rng, 5)
	combat.start_combat()
	return combat


func test_round_trip_preserves_player_enemy_and_deck_state() -> void:
	var combat := _build_combat()
	combat.player.take_damage(12)
	combat.player.add_status(StatusTypes.Type.STRENGTH, 2)
	combat.enemies[0].take_damage(5)
	combat.enemies[0].advance_intent()

	var data: Dictionary = CombatSnapshot.capture(combat)
	var restored: CombatState = CombatSnapshot.restore(data)

	assert_eq(restored.player.current_hp, combat.player.current_hp)
	assert_eq(restored.player.energy, combat.player.energy)
	assert_eq(restored.player.get_status(StatusTypes.Type.STRENGTH), 2)
	assert_eq(restored.enemies[0].current_hp, combat.enemies[0].current_hp)
	assert_eq(restored.enemies[0].current_intent.kind, combat.enemies[0].current_intent.kind)
	assert_eq(restored.deck.hand.size(), combat.deck.hand.size())
	assert_eq(restored.deck.draw_pile.size(), combat.deck.draw_pile.size())
	assert_eq(restored.turn_number, combat.turn_number)


func test_round_trip_preserves_card_identity_and_order() -> void:
	var combat := _build_combat()
	var data: Dictionary = CombatSnapshot.capture(combat)
	var restored: CombatState = CombatSnapshot.restore(data)

	for i in range(combat.deck.hand.size()):
		assert_eq(restored.deck.hand[i].instance_id, combat.deck.hand[i].instance_id)
		assert_eq(restored.deck.hand[i].definition.id, combat.deck.hand[i].definition.id)


func test_restored_combat_can_continue_playing_identically() -> void:
	var combat_a := _build_combat(9)
	var combat_b := CombatSnapshot.restore(CombatSnapshot.capture(combat_a))

	var card_a: CardInstance = combat_a.deck.hand[0]
	var card_b: CardInstance = combat_b.deck.hand[0]
	assert_eq(card_a.instance_id, card_b.instance_id)

	combat_a.play_card(card_a.instance_id, 0)
	combat_b.play_card(card_b.instance_id, 0)

	assert_eq(combat_a.enemies[0].current_hp, combat_b.enemies[0].current_hp)
	assert_eq(combat_a.player.energy, combat_b.player.energy)
	assert_eq(combat_a.deck.hand.size(), combat_b.deck.hand.size())
