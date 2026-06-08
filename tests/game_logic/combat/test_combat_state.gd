extends GutTest
## Integration-level tests for CombatState: turn flow, card resolution against
## live combat state, enemy AI execution, and win/loss detection.

var strike: CardDefinition
var defend: CardDefinition
var bash: CardDefinition # exhausting card with a status effect, for exhaust-pile coverage

func before_each() -> void:
	strike = CardDefinition.new(&"strike", "Strike", 1, CardDefinition.CardType.ATTACK,
		[CardEffect.damage(CardEffect.Target.SINGLE_ENEMY, 6)])
	defend = CardDefinition.new(&"defend", "Defend", 1, CardDefinition.CardType.SKILL,
		[CardEffect.block(5)])
	bash = CardDefinition.new(&"bash", "Bash", 2, CardDefinition.CardType.ATTACK,
		[CardEffect.damage(CardEffect.Target.SINGLE_ENEMY, 8),
		 CardEffect.apply_status(CardEffect.Target.SINGLE_ENEMY, StatusTypes.Type.VULNERABLE, 2)],
		true)


## A single dummy enemy that only ever attacks for `attack_value`.
func _attacker_enemy(hp: int, attack_value: int) -> EnemyState:
	return EnemyState.new(&"dummy", hp, [EnemyIntent.attack(attack_value)])


func _build_combat(definitions: Array[CardDefinition], enemies: Array[EnemyState], seed_value: int = 1) -> CombatState:
	var deck := Deck.new()
	var rng := RNGStream.new(seed_value)
	deck.setup_starting_deck(definitions, rng)
	var player := PlayerState.new(70, 3)
	return CombatState.new(player, enemies, deck, rng, 5)


func _starting_deck(strike_count: int, defend_count: int) -> Array[CardDefinition]:
	var definitions: Array[CardDefinition] = []
	for i in range(strike_count):
		definitions.append(strike)
	for i in range(defend_count):
		definitions.append(defend)
	return definitions


func test_start_combat_resets_resources_and_draws_a_hand() -> void:
	var combat := _build_combat(_starting_deck(5, 4), [_attacker_enemy(40, 6)])
	combat.start_combat()
	assert_eq(combat.player.energy, 3)
	assert_eq(combat.player.block, 0)
	assert_eq(combat.deck.hand.size(), 5)
	assert_eq(combat.turn_number, 1)
	assert_eq(combat.get_outcome(), CombatState.Outcome.ONGOING)


func test_playing_an_attack_card_damages_the_target_and_spends_energy() -> void:
	var combat := _build_combat(_starting_deck(5, 4), [_attacker_enemy(40, 6)])
	combat.start_combat()
	var card: CardInstance = _first_card_in_hand(combat, &"strike")
	var events: Array[Dictionary] = combat.play_card(card.instance_id, 0)

	assert_eq(combat.player.energy, 2, "Strike costs 1 energy")
	assert_eq(combat.enemies[0].current_hp, 34, "40 - 6 damage")
	assert_has_event(events, "card_played")
	assert_has_event(events, "damage_dealt")
	assert_false(_in_hand(combat, card.instance_id))
	assert_true(combat.deck.discard_pile.has(card), "non-exhausting cards go to discard")


func test_playing_an_exhausting_card_sends_it_to_the_exhaust_pile() -> void:
	var combat := _build_combat([bash, bash, bash, bash, bash], [_attacker_enemy(40, 6)])
	combat.start_combat()
	var card: CardInstance = combat.deck.hand[0]
	combat.play_card(card.instance_id, 0)
	assert_true(combat.deck.exhaust_pile.has(card))
	assert_false(combat.deck.discard_pile.has(card))


func test_apply_status_effect_stacks_vulnerable_on_target() -> void:
	var combat := _build_combat([bash, bash, bash, bash, bash], [_attacker_enemy(40, 6)])
	combat.start_combat()
	var card: CardInstance = combat.deck.hand[0]
	combat.play_card(card.instance_id, 0)
	assert_eq(combat.enemies[0].get_status(StatusTypes.Type.VULNERABLE), 2)


func test_vulnerable_target_takes_increased_damage() -> void:
	var combat := _build_combat(_starting_deck(5, 4), [_attacker_enemy(40, 6)])
	combat.start_combat()
	combat.enemies[0].add_status(StatusTypes.Type.VULNERABLE, 1)
	var card: CardInstance = _first_card_in_hand(combat, &"strike")
	combat.play_card(card.instance_id, 0)
	# (6 + 0) * 1.5 = 9
	assert_eq(combat.enemies[0].current_hp, 31)


func test_block_card_grants_block_to_player() -> void:
	var combat := _build_combat(_starting_deck(0, 5), [_attacker_enemy(40, 6)])
	combat.start_combat()
	var card: CardInstance = combat.deck.hand[0]
	combat.play_card(card.instance_id)
	assert_eq(combat.player.block, 5)


func test_cannot_play_a_card_without_enough_energy() -> void:
	var combat := _build_combat(_starting_deck(5, 4), [_attacker_enemy(40, 6)])
	combat.start_combat()
	combat.player.energy = 0
	var card: CardInstance = _first_card_in_hand(combat, &"strike")
	var events: Array[Dictionary] = combat.play_card(card.instance_id, 0)
	assert_eq(events.size(), 0, "illegal play should be a no-op")
	assert_true(_in_hand(combat, card.instance_id), "card should remain in hand")
	assert_eq(combat.enemies[0].current_hp, 40)


func test_cannot_play_a_card_not_in_hand() -> void:
	var combat := _build_combat(_starting_deck(5, 4), [_attacker_enemy(40, 6)])
	combat.start_combat()
	var events: Array[Dictionary] = combat.play_card(99999, 0)
	assert_eq(events.size(), 0)


func test_ending_turn_discards_hand_and_runs_enemy_attack() -> void:
	# Deck big enough that drawing the next hand doesn't require reshuffling
	# the discard pile mid-method — keeps "old hand discarded" observable.
	var combat := _build_combat(_starting_deck(10, 5), [_attacker_enemy(40, 6)])
	combat.start_combat()
	var hand_before: int = combat.deck.hand.size()
	var hp_before: int = combat.player.current_hp

	var events: Array[Dictionary] = combat.end_player_turn()

	assert_eq(combat.player.current_hp, hp_before - 6, "enemy should have attacked for 6")
	assert_eq(combat.deck.hand.size(), 5, "new hand drawn for the next turn")
	assert_eq(combat.deck.discard_pile.size(), hand_before, "old hand discarded")
	assert_eq(combat.turn_number, 2)
	assert_has_event(events, "enemy_intent_changed")


func test_player_block_absorbs_enemy_attack_and_resets_next_turn() -> void:
	var combat := _build_combat(_starting_deck(0, 5), [_attacker_enemy(40, 6)])
	combat.start_combat()
	var card: CardInstance = combat.deck.hand[0]
	combat.play_card(card.instance_id) # +5 block
	var hp_before: int = combat.player.current_hp

	combat.end_player_turn()

	assert_eq(combat.player.current_hp, hp_before - 1, "5 block absorbs 5 of the 6 damage")
	assert_eq(combat.player.block, 0, "block resets at the start of the next player turn")


func test_debuffs_decay_at_end_of_owners_turn() -> void:
	var combat := _build_combat(_starting_deck(5, 4), [_attacker_enemy(40, 6)])
	combat.start_combat()
	combat.player.add_status(StatusTypes.Type.WEAK, 2)
	combat.end_player_turn()
	assert_eq(combat.player.get_status(StatusTypes.Type.WEAK), 1)


func test_combat_ends_in_victory_when_all_enemies_die() -> void:
	var combat := _build_combat([bash, bash, bash, bash, bash], [_attacker_enemy(8, 6)])
	combat.start_combat()
	var card: CardInstance = combat.deck.hand[0]
	combat.play_card(card.instance_id, 0) # 8 damage kills the 8 HP dummy

	assert_false(combat.enemies[0].is_alive())
	assert_eq(combat.get_outcome(), CombatState.Outcome.VICTORY)


func test_combat_ends_in_defeat_when_player_dies() -> void:
	var combat := _build_combat(_starting_deck(5, 4), [_attacker_enemy(40, 999)])
	combat.start_combat()
	combat.end_player_turn()
	assert_false(combat.player.is_alive())
	assert_eq(combat.get_outcome(), CombatState.Outcome.DEFEAT)


func test_ending_turn_after_combat_is_decided_does_not_start_a_new_player_turn() -> void:
	var combat := _build_combat(_starting_deck(5, 4), [_attacker_enemy(40, 999)])
	combat.start_combat()
	var events: Array[Dictionary] = combat.end_player_turn()
	assert_has_event(events, "combat_ended")
	assert_does_not_have_event(events, "turn_started")


# ---- helpers -------------------------------------------------------------

func _first_card_in_hand(combat: CombatState, card_id: StringName) -> CardInstance:
	for card in combat.deck.hand:
		if card.definition.id == card_id:
			return card
	fail_test("no card with id %s in hand" % card_id)
	return null


func _in_hand(combat: CombatState, instance_id: int) -> bool:
	for card in combat.deck.hand:
		if card.instance_id == instance_id:
			return true
	return false


func assert_has_event(events: Array[Dictionary], type: String) -> void:
	for event in events:
		if event.get("type") == type:
			assert_true(true)
			return
	fail_test("expected an event of type '%s' but found: %s" % [type, _event_types(events)])


func assert_does_not_have_event(events: Array[Dictionary], type: String) -> void:
	for event in events:
		assert_ne(event.get("type"), type)


func _event_types(events: Array[Dictionary]) -> Array[String]:
	var types: Array[String] = []
	for event in events:
		types.append(str(event.get("type")))
	return types
