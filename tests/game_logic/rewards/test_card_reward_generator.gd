extends GutTest

func _pool(size: int = 10) -> Array[CardDefinition]:
	var cards: Array[CardDefinition] = []
	for i in range(size):
		cards.append(CardDefinition.new(StringName("card_%d" % i), "Card %d" % i, 1,
			CardDefinition.CardType.ATTACK, [CardEffect.damage(CardEffect.Target.SINGLE_ENEMY, 1)]))
	return cards


func test_returns_the_requested_count_of_distinct_cards() -> void:
	var offer: Array[CardDefinition] = CardRewardGenerator.generate(_pool(), RNGStream.new(1), 3)

	assert_eq(offer.size(), 3)
	var ids: Dictionary = {}
	for card in offer:
		ids[card.id] = true
	assert_eq(ids.size(), 3, "offered cards should be distinct")


func test_same_seed_produces_the_same_offer() -> void:
	var offer_a: Array[CardDefinition] = CardRewardGenerator.generate(_pool(), RNGStream.new(42), 3)
	var offer_b: Array[CardDefinition] = CardRewardGenerator.generate(_pool(), RNGStream.new(42), 3)

	for i in range(offer_a.size()):
		assert_eq(offer_a[i].id, offer_b[i].id)


func test_different_seeds_produce_different_offers() -> void:
	var offer_a: Array[CardDefinition] = CardRewardGenerator.generate(_pool(), RNGStream.new(1), 3)
	var offer_b: Array[CardDefinition] = CardRewardGenerator.generate(_pool(), RNGStream.new(2), 3)

	var ids_a: Array = offer_a.map(func(c: CardDefinition) -> StringName: return c.id)
	var ids_b: Array = offer_b.map(func(c: CardDefinition) -> StringName: return c.id)
	assert_ne(ids_a, ids_b)


func test_pool_smaller_than_count_returns_whole_pool() -> void:
	var offer: Array[CardDefinition] = CardRewardGenerator.generate(_pool(2), RNGStream.new(1), 3)
	assert_eq(offer.size(), 2)
