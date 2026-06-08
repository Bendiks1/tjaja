extends GutTest

var deck: Deck
var strike: CardDefinition
var defend: CardDefinition

func before_each() -> void:
	deck = Deck.new()
	strike = CardDefinition.new(&"strike", "Strike", 1, CardDefinition.CardType.ATTACK, [CardEffect.damage(CardEffect.Target.SINGLE_ENEMY, 6)])
	defend = CardDefinition.new(&"defend", "Defend", 1, CardDefinition.CardType.SKILL, [CardEffect.block(5)])


func _build_starting_deck(strike_count: int, defend_count: int, seed_value: int = 1) -> RNGStream:
	var definitions: Array[CardDefinition] = []
	for i in range(strike_count):
		definitions.append(strike)
	for i in range(defend_count):
		definitions.append(defend)
	var rng := RNGStream.new(seed_value)
	deck.setup_starting_deck(definitions, rng)
	return rng


func test_instantiate_assigns_unique_increasing_ids() -> void:
	var a: CardInstance = deck.instantiate(strike)
	var b: CardInstance = deck.instantiate(strike)
	assert_eq(a.instance_id, 0)
	assert_eq(b.instance_id, 1)
	assert_ne(a.instance_id, b.instance_id)


func test_setup_starting_deck_fills_draw_pile() -> void:
	_build_starting_deck(5, 4)
	assert_eq(deck.draw_pile.size(), 9)
	assert_true(deck.hand.is_empty())
	assert_true(deck.discard_pile.is_empty())


func test_draw_moves_cards_from_draw_pile_to_hand() -> void:
	var rng := _build_starting_deck(5, 4)
	var drawn: Array[CardInstance] = deck.draw(5, rng)
	assert_eq(drawn.size(), 5)
	assert_eq(deck.hand.size(), 5)
	assert_eq(deck.draw_pile.size(), 4)


func test_draw_reshuffles_discard_into_draw_pile_when_empty() -> void:
	var rng := _build_starting_deck(2, 1) # 3 cards total
	deck.draw(3, rng)
	deck.discard_hand()
	assert_true(deck.draw_pile.is_empty())
	assert_eq(deck.discard_pile.size(), 3)

	var drawn: Array[CardInstance] = deck.draw(2, rng)
	assert_eq(drawn.size(), 2, "should reshuffle discard into draw pile mid-draw")
	assert_true(deck.discard_pile.is_empty())
	assert_eq(deck.draw_pile.size(), 1)


func test_draw_stops_when_both_piles_are_empty() -> void:
	var rng := _build_starting_deck(1, 0)
	var drawn: Array[CardInstance] = deck.draw(5, rng)
	assert_eq(drawn.size(), 1, "can only draw the cards that exist")


func test_discard_hand_moves_all_hand_cards_to_discard() -> void:
	var rng := _build_starting_deck(3, 2)
	deck.draw(3, rng)
	deck.discard_hand()
	assert_true(deck.hand.is_empty())
	assert_eq(deck.discard_pile.size(), 3)


func test_remove_from_hand_returns_and_removes_matching_card() -> void:
	var rng := _build_starting_deck(2, 2)
	deck.draw(2, rng)
	var instance_id: int = deck.hand[0].instance_id
	var removed: CardInstance = deck.remove_from_hand(instance_id)
	assert_not_null(removed)
	assert_eq(removed.instance_id, instance_id)
	assert_eq(deck.hand.size(), 1)


func test_remove_from_hand_returns_null_when_not_present() -> void:
	assert_null(deck.remove_from_hand(9999))


func test_send_to_exhaust_and_discard_route_to_correct_piles() -> void:
	var card_a: CardInstance = deck.instantiate(strike)
	var card_b: CardInstance = deck.instantiate(defend)
	deck.send_to_exhaust(card_a)
	deck.send_to_discard(card_b)
	assert_eq(deck.exhaust_pile, [card_a])
	assert_eq(deck.discard_pile, [card_b])


func test_get_all_cards_returns_cards_from_every_pile() -> void:
	var rng := _build_starting_deck(2, 2)
	deck.draw(2, rng)
	deck.send_to_exhaust(deck.remove_from_hand(deck.hand[0].instance_id))
	assert_eq(deck.get_all_cards().size(), 4)
