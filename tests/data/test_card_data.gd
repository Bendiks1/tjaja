extends GutTest
## Confirms CardData.to_definition() converts exported content data into a
## working CardDefinition/CardEffect chain that CombatState can run.

func test_simple_attack_converts_to_a_runnable_definition() -> void:
	var data := CardData.new()
	data.id = &"strike"
	data.display_name = "Strike"
	data.cost = 1
	data.card_type = CardDefinition.CardType.ATTACK
	data.effects = [{"kind": CardEffect.Kind.DAMAGE, "target": CardEffect.Target.SINGLE_ENEMY, "value": 6}]

	var definition: CardDefinition = data.to_definition()

	assert_eq(definition.id, &"strike")
	assert_eq(definition.cost, 1)
	assert_eq(definition.card_type, CardDefinition.CardType.ATTACK)
	assert_eq(definition.exhausts, false)
	assert_eq(definition.effects.size(), 1)
	assert_eq(definition.effects[0].kind, CardEffect.Kind.DAMAGE)
	assert_eq(definition.effects[0].target, CardEffect.Target.SINGLE_ENEMY)
	assert_eq(definition.effects[0].value, 6)


func test_status_field_is_carried_through_for_apply_status_effects() -> void:
	var data := CardData.new()
	data.id = &"bash"
	data.display_name = "Bash"
	data.cost = 2
	data.exhausts = true
	data.effects = [
		{"kind": CardEffect.Kind.DAMAGE, "target": CardEffect.Target.SINGLE_ENEMY, "value": 8},
		{"kind": CardEffect.Kind.APPLY_STATUS, "target": CardEffect.Target.SINGLE_ENEMY, "value": 2, "status": StatusTypes.Type.VULNERABLE},
	]

	var definition: CardDefinition = data.to_definition()

	assert_eq(definition.exhausts, true)
	assert_eq(definition.effects.size(), 2)
	assert_eq(definition.effects[1].kind, CardEffect.Kind.APPLY_STATUS)
	assert_eq(definition.effects[1].status, StatusTypes.Type.VULNERABLE)
	assert_eq(definition.effects[1].value, 2)


func test_a_converted_card_can_actually_be_played_in_combat() -> void:
	var data := CardData.new()
	data.id = &"defend"
	data.display_name = "Defend"
	data.cost = 1
	data.card_type = CardDefinition.CardType.SKILL
	data.effects = [{"kind": CardEffect.Kind.BLOCK, "target": CardEffect.Target.SELF, "value": 5}]

	var deck := Deck.new()
	var definitions: Array[CardDefinition] = [data.to_definition()]
	var rng := RNGStream.new(1)
	deck.setup_starting_deck(definitions, rng)

	var player := PlayerState.new(50, 3)
	var enemy := EnemyState.new(&"dummy", 10, [EnemyIntent.attack(3)])
	var combat := CombatState.new(player, [enemy], deck, rng, 1)
	combat.start_combat()

	combat.play_card(deck.hand[0].instance_id)
	assert_eq(player.block, 5, "the converted Defend should grant 5 block when played")
