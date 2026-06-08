class_name CharacterData
extends Resource
## Content definition for a playable character: their starting stats and deck.
## Instanced as .tres files; the character select screen lists these and the
## run-loop controller uses the chosen one to seed a fresh RunState.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String = ""
@export var starting_hp: int = 70
@export var starting_energy: int = 3
@export var starting_deck: Array[CardData] = []


## Expands `starting_deck` (one CardData per copy) into the CardDefinitions
## CombatState/Deck consume — the pure logic layer never touches Resources.
func build_starting_deck() -> Array[CardDefinition]:
	var definitions: Array[CardDefinition] = []
	for card in starting_deck:
		definitions.append(card.to_definition())
	return definitions
