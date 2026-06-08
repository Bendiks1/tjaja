class_name CardDefinition
extends RefCounted
## The static template for a card — what CardData.tres resources convert into
## for the logic layer. Kept independent of Resource/@export so combat and deck
## code can be tested with plain constructed instances, no .tres loading required.

enum CardType { ATTACK, SKILL, POWER }

var id: StringName
var display_name: String
var cost: int
var card_type: CardType
var effects: Array[CardEffect]
var exhausts: bool ## Goes to the exhaust pile instead of discard when played.
var description: String ## Display-only flavor/rules text; never read by combat resolution.

func _init(
	card_id: StringName,
	name: String,
	energy_cost: int,
	type: CardType,
	card_effects: Array[CardEffect],
	does_exhaust: bool = false,
	display_description: String = ""
) -> void:
	id = card_id
	display_name = name
	cost = energy_cost
	card_type = type
	effects = card_effects
	exhausts = does_exhaust
	description = display_description
