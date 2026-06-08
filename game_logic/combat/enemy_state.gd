class_name EnemyState
extends CombatantState
## A single enemy in combat. Move selection is a fixed, ordered pattern that
## loops — simple, fully deterministic, and matches how most Slay the Spire
## enemies behave (no RNG needed for v1's roster). Random patterns can be
## layered on top later by having `move_pattern` vary per-cycle via the RNGStream.

var enemy_id: StringName
var move_pattern: Array[EnemyIntent]
var _pattern_index: int = 0
var current_intent: EnemyIntent


func _init(id: StringName, starting_hp: int, pattern: Array[EnemyIntent]) -> void:
	super._init(starting_hp)
	enemy_id = id
	move_pattern = pattern
	assert(not move_pattern.is_empty(), "Enemy %s needs at least one move in its pattern" % id)
	_refresh_intent()


## Advances to the next move in the pattern and re-telegraphs. Called once the
## current intent has been resolved, at the end of the enemy's turn.
func advance_intent() -> void:
	_pattern_index = (_pattern_index + 1) % move_pattern.size()
	_refresh_intent()


func _refresh_intent() -> void:
	current_intent = move_pattern[_pattern_index]
