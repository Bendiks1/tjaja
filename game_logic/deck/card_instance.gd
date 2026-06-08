class_name CardInstance
extends RefCounted
## One physical copy of a card sitting in a deck. Decks can contain duplicate
## definitions (two "Strike"s), so each copy carries its own `instance_id` —
## that's the stable identity saved/restored across piles and game sessions.

var instance_id: int
var definition: CardDefinition

func _init(id: int, card_definition: CardDefinition) -> void:
	instance_id = id
	definition = card_definition
