extends GutTest
## Integration tests for the combat screen controller: wiring taps through to
## CombatState and re-rendering views from the events it returns.

const CombatScreenScene: PackedScene = preload("res://scenes/screens/combat_screen.tscn")

func _strike() -> CardDefinition:
	return CardDefinition.new(&"strike", "Strike", 1, CardDefinition.CardType.ATTACK,
		[CardEffect.damage(CardEffect.Target.SINGLE_ENEMY, 6)], false, "Deal 6 damage.")

func _defend() -> CardDefinition:
	return CardDefinition.new(&"defend", "Defend", 1, CardDefinition.CardType.SKILL,
		[CardEffect.block(5)], false, "Gain 5 Block.")

func _build_deck() -> Array[CardDefinition]:
	var definitions: Array[CardDefinition] = []
	for i in range(5):
		definitions.append(_strike())
	for i in range(4):
		definitions.append(_defend())
	return definitions

func _dummy_enemy(hp: int = 30, attack: int = 6) -> EnemyState:
	return EnemyState.new(&"dummy", hp, [EnemyIntent.attack(attack)])

func _strike_in_hand(screen: Control) -> CardInstance:
	for card in screen._combat.deck.hand:
		if card.definition.id == &"strike":
			return card
	fail_test("no Strike in hand")
	return null


func test_start_encounter_populates_hand_and_enemy_views() -> void:
	var screen: Control = CombatScreenScene.instantiate()
	add_child_autofree(screen)

	screen.start_encounter(70, 3, _build_deck(), [_dummy_enemy()], 1)

	assert_eq(screen._combat.deck.hand.size(), 5)
	assert_eq(screen._enemy_views.size(), 1)
	assert_eq(screen._card_views.size(), 5)
	assert_eq(screen._hp_label.text, "HP 70 / 70")


func test_tapping_a_single_target_card_then_an_enemy_plays_it() -> void:
	var screen: Control = CombatScreenScene.instantiate()
	add_child_autofree(screen)
	screen.start_encounter(70, 3, _build_deck(), [_dummy_enemy(30, 6)], 1)

	var strike: CardInstance = _strike_in_hand(screen)
	screen._on_card_tapped(strike.instance_id)
	assert_eq(screen._awaiting_target_for, strike.instance_id, "should enter targeting mode for a single-enemy card")

	screen._on_enemy_tapped(0)
	assert_eq(screen._awaiting_target_for, -1, "targeting mode should clear once a target is chosen")
	assert_eq(screen._combat.enemies[0].current_hp, 24, "30 - 6 damage")


func test_tapping_a_self_target_card_plays_immediately() -> void:
	var screen: Control = CombatScreenScene.instantiate()
	add_child_autofree(screen)
	screen.start_encounter(70, 3, _build_deck(), [_dummy_enemy()], 1)

	var defend: CardInstance = null
	for card in screen._combat.deck.hand:
		if card.definition.id == &"defend":
			defend = card
			break
	assert_not_null(defend)

	screen._on_card_tapped(defend.instance_id)
	assert_eq(screen._awaiting_target_for, -1, "self-target cards should not enter targeting mode")
	assert_eq(screen._combat.player.block, 5)


func test_tapping_the_same_card_twice_cancels_targeting() -> void:
	var screen: Control = CombatScreenScene.instantiate()
	add_child_autofree(screen)
	screen.start_encounter(70, 3, _build_deck(), [_dummy_enemy()], 1)

	var strike: CardInstance = _strike_in_hand(screen)
	screen._on_card_tapped(strike.instance_id)
	screen._on_card_tapped(strike.instance_id)

	assert_eq(screen._awaiting_target_for, -1)
	assert_true(screen._find_in_hand(strike.instance_id) != null, "card should remain in hand, unplayed")


func test_end_turn_runs_enemy_attack_and_updates_stats() -> void:
	var screen: Control = CombatScreenScene.instantiate()
	add_child_autofree(screen)
	screen.start_encounter(70, 3, _build_deck(), [_dummy_enemy(30, 6)], 1)

	screen._on_end_turn_pressed()

	assert_eq(screen._combat.player.current_hp, 64)
	assert_eq(screen._hp_label.text, "HP 64 / 70")
	assert_eq(screen._turn_label.text, "Turn 2")


func test_victory_disables_end_turn_and_emits_event_bus_signal() -> void:
	var screen: Control = CombatScreenScene.instantiate()
	add_child_autofree(screen)
	screen.start_encounter(70, 3, _build_deck(), [_dummy_enemy(4, 1)], 1)

	watch_signals(EventBus)
	var strike: CardInstance = _strike_in_hand(screen)
	screen._play_card(strike.instance_id, 0) # 6 damage kills the 4 HP dummy

	assert_signal_emitted(EventBus, "combat_finished")
	assert_true(screen._end_turn_button.disabled)
	assert_eq(screen._prompt_label.text, "Victory!")
