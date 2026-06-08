class_name EnemyData
extends Resource
## Content definition for one enemy. Instanced as .tres files. `to_enemy_state()`
## builds the pure-logic EnemyState (with a fresh move-pattern cursor) that
## CombatState runs — call it once per encounter so enemies don't share state.

@export var id: StringName
@export var display_name: String
@export var max_hp: int = 10
@export_enum("Regular", "Elite", "Boss") var rank: int = 0
@export_multiline var flavor_text: String = ""

## Looping, ordered list of telegraphed moves. Each entry:
## {"kind": EnemyIntent.Kind, "value": int, "status": StatusTypes.Type (only read for BUFF_SELF/DEBUFF_PLAYER)}.
## Plain dictionaries for the same hand-authoring reasons as CardData.effects.
@export var move_pattern: Array[Dictionary] = []


func to_enemy_state() -> EnemyState:
	var pattern: Array[EnemyIntent] = []
	for entry in move_pattern:
		pattern.append(EnemyIntent.new(
			entry.get("kind", EnemyIntent.Kind.ATTACK),
			entry.get("value", 0),
			entry.get("status", StatusTypes.Type.STRENGTH)
		))
	return EnemyState.new(id, max_hp, pattern)
