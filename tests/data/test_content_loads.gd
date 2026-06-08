extends GutTest
## Smoke tests that the actual .tres content files on disk load, parse into the
## expected shape, and convert cleanly into runnable game-logic objects. This
## is what would catch a typo in a hand-authored resource file.

const CARD_PATHS: Array[String] = [
	"res://data/cards/strike.tres",
	"res://data/cards/defend.tres",
	"res://data/cards/soul_rend.tres",
	"res://data/cards/heavy_swing.tres",
	"res://data/cards/iron_resolve.tres",
	"res://data/cards/cleave.tres",
	"res://data/cards/bleeding_strike.tres",
	"res://data/cards/grim_focus.tres",
	"res://data/cards/battle_trance.tres",
	"res://data/cards/second_wind.tres",
]

const ENEMY_PATHS: Array[String] = [
	"res://data/enemies/grave_rat.tres",
	"res://data/enemies/bone_sentinel.tres",
	"res://data/enemies/charnel_brute.tres",
]


func test_all_starter_cards_load_as_card_data_and_convert() -> void:
	for path in CARD_PATHS:
		var data: CardData = load(path)
		assert_not_null(data, "failed to load %s" % path)
		assert_true(data is CardData, "%s should be a CardData resource" % path)
		assert_false(String(data.id).is_empty(), "%s is missing an id" % path)
		assert_gt(data.cost, -1, "%s has a negative cost" % path)
		assert_false(data.effects.is_empty(), "%s should define at least one effect" % path)

		var definition: CardDefinition = data.to_definition()
		assert_eq(definition.id, data.id)
		assert_eq(definition.effects.size(), data.effects.size())


func test_starter_card_ids_are_unique() -> void:
	var seen_ids: Dictionary = {}
	for path in CARD_PATHS:
		var data: CardData = load(path)
		assert_false(seen_ids.has(data.id), "duplicate card id: %s" % data.id)
		seen_ids[data.id] = true


func test_all_sample_enemies_load_as_enemy_data_and_convert() -> void:
	for path in ENEMY_PATHS:
		var data: EnemyData = load(path)
		assert_not_null(data, "failed to load %s" % path)
		assert_true(data is EnemyData, "%s should be an EnemyData resource" % path)
		assert_gt(data.max_hp, 0, "%s should have positive max HP" % path)
		assert_false(data.move_pattern.is_empty(), "%s should define a move pattern" % path)

		var state: EnemyState = data.to_enemy_state()
		assert_eq(state.enemy_id, data.id)
		assert_eq(state.max_hp, data.max_hp)
		assert_not_null(state.current_intent)


func test_act_1_loads_and_references_its_enemy_pools() -> void:
	var act: ActData = load("res://data/acts/act_1.tres")
	assert_not_null(act)
	assert_eq(act.act_number, 1)
	assert_gt(act.node_count, 0)
	assert_eq(act.regular_enemies.size(), 2)
	assert_eq(act.elite_enemies.size(), 1)
	assert_eq(act.elite_enemies[0].id, &"charnel_brute")


func test_starting_deck_can_be_assembled_from_loaded_card_data() -> void:
	# The actual starting deck composition: 5 Strike, 4 Defend, 1 Soul Rend.
	var strike: CardData = load("res://data/cards/strike.tres")
	var defend: CardData = load("res://data/cards/defend.tres")
	var soul_rend: CardData = load("res://data/cards/soul_rend.tres")

	var definitions: Array[CardDefinition] = []
	for i in range(5):
		definitions.append(strike.to_definition())
	for i in range(4):
		definitions.append(defend.to_definition())
	definitions.append(soul_rend.to_definition())

	var deck := Deck.new()
	deck.setup_starting_deck(definitions, RNGStream.new(1))
	assert_eq(deck.draw_pile.size(), 10)
	assert_eq(deck.get_all_cards().size(), 10)
