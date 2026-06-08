class_name CardData
extends Resource
## Content definition for one card. Instanced as .tres files — never construct
## gameplay cards by hand in scripts. `to_definition()` converts this exported
## data into the pure-logic CardDefinition that CombatState actually runs on.

@export var id: StringName
@export var display_name: String
@export var cost: int = 1
@export_enum("Attack", "Skill", "Power") var card_type: int = 0
@export var exhausts: bool = false
@export_multiline var description: String = ""

## Each entry: {"kind": CardEffect.Kind, "target": CardEffect.Target, "value": int, "status": StatusTypes.Type (only read for APPLY_STATUS)}.
## Plain dictionaries (rather than a nested Resource type) keep these easy to
## hand-author and diff in .tres files; CardEffect.Kind/Target/StatusTypes.Type
## are plain int enums so the dictionary values line up with them directly.
@export var effects: Array[Dictionary] = []


func to_definition() -> CardDefinition:
	var converted_effects: Array[CardEffect] = []
	for entry in effects:
		converted_effects.append(CardEffect.new(
			entry.get("kind", CardEffect.Kind.DAMAGE),
			entry.get("target", CardEffect.Target.SINGLE_ENEMY),
			entry.get("value", 0),
			entry.get("status", StatusTypes.Type.STRENGTH)
		))
	return CardDefinition.new(id, display_name, cost, card_type, converted_effects, exhausts, description)
