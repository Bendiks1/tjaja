extends Node
## Holds the active run's state (deck, HP, gold, map position, seed, ...).
## Plain data + lifecycle helpers only — serialization lives in SaveSystem/
## RunSerializer so this stays a simple thing for screens to read and mutate.

var has_active_run: bool = false
var character_id: StringName = &""
var run_seed: int = 0
var act_number: int = 1
var gold: int = 0

var max_hp: int = 0
var current_hp: int = 0
var deck_card_ids: Array[StringName] = [] ## CardData ids, one entry per copy in the deck.

var map_current_node_id: int = -1
var map_visited_node_ids: Array[int] = []

## Present only while a fight is paused mid-combat (see CombatSnapshot);
## empty whenever the run is anywhere else.
var combat_snapshot: Dictionary = {}


## Wipes any previous run and starts a fresh one with `character`, seeded by
## `seed_value` (the run's master seed — map generation derives from it).
func start_new_run(character: CharacterData, seed_value: int) -> void:
	has_active_run = true
	character_id = character.id
	run_seed = seed_value
	act_number = 1
	gold = 0
	max_hp = character.starting_hp
	current_hp = character.starting_hp

	deck_card_ids.clear()
	for card in character.starting_deck:
		deck_card_ids.append(card.id)

	map_current_node_id = -1
	map_visited_node_ids.clear()
	combat_snapshot = {}


func is_in_combat() -> bool:
	return not combat_snapshot.is_empty()


func clear() -> void:
	has_active_run = false
	character_id = &""
	run_seed = 0
	act_number = 1
	gold = 0
	max_hp = 0
	current_hp = 0
	deck_card_ids.clear()
	map_current_node_id = -1
	map_visited_node_ids.clear()
	combat_snapshot = {}


## Builds the CardDefinitions CombatState/Deck need from the saved id list.
func build_deck_definitions() -> Array[CardDefinition]:
	var definitions: Array[CardDefinition] = []
	for card_id in deck_card_ids:
		definitions.append(ContentDatabase.card_data(card_id).to_definition())
	return definitions
