extends GutTest
## Integration tests for the card reward screen: rendering an offer and
## reporting the player's pick (or skip).

const CardRewardScreenScene: PackedScene = preload("res://scenes/screens/card_reward_screen.tscn")

func _pool(size: int = 10) -> Array[CardDefinition]:
	var cards: Array[CardDefinition] = []
	for i in range(size):
		cards.append(CardDefinition.new(StringName("card_%d" % i), "Card %d" % i, 1,
			CardDefinition.CardType.ATTACK, [CardEffect.damage(CardEffect.Target.SINGLE_ENEMY, 1)]))
	return cards


func test_show_offer_renders_a_card_view_per_offered_card() -> void:
	var screen: Control = CardRewardScreenScene.instantiate()
	add_child_autofree(screen)

	screen.show_offer(_pool(), 1, 3)

	assert_eq(screen._offer.size(), 3)
	assert_eq(screen._offer_row.get_child_count(), 3)


func test_tapping_an_offered_card_emits_card_chosen_with_its_definition() -> void:
	var screen: Control = CardRewardScreenScene.instantiate()
	add_child_autofree(screen)
	screen.show_offer(_pool(), 1, 3)

	var watcher := watch_signals(screen)
	screen._on_card_tapped(1)

	assert_signal_emitted_with_parameters(screen, "card_chosen", [screen._offer[1]])


func test_pressing_skip_emits_skipped() -> void:
	var screen: Control = CardRewardScreenScene.instantiate()
	add_child_autofree(screen)
	screen.show_offer(_pool(), 1, 3)

	var watcher := watch_signals(screen)
	screen._skip_button.pressed.emit()

	assert_signal_emitted(screen, "skipped")
