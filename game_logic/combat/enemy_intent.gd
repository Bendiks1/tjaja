class_name EnemyIntent
extends RefCounted
## A single telegraphed enemy action. EnemyState exposes "what I'll do next turn"
## as one of these so the UI can render the intent icon/value before it resolves.

enum Kind {
	ATTACK,       ## Deals `value` damage (before Strength/Weak/Vulnerable modifiers).
	DEFEND,       ## Gains `value` block.
	BUFF_SELF,    ## Gains `value` stacks of `status` on itself.
	DEBUFF_PLAYER,## Applies `value` stacks of `status` to the player.
	UNKNOWN,      ## Telegraph hidden — used by enemies that don't reveal intent (none in v1 data, kept for completeness).
}

var kind: Kind
var value: int
var status: StatusTypes.Type # only meaningful for BUFF_SELF / DEBUFF_PLAYER

func _init(intent_kind: Kind, intent_value: int = 0, status_type: StatusTypes.Type = StatusTypes.Type.STRENGTH) -> void:
	kind = intent_kind
	value = intent_value
	status = status_type


static func attack(damage: int) -> EnemyIntent:
	return EnemyIntent.new(Kind.ATTACK, damage)


static func defend(block_amount: int) -> EnemyIntent:
	return EnemyIntent.new(Kind.DEFEND, block_amount)


static func buff_self(status_type: StatusTypes.Type, stacks: int) -> EnemyIntent:
	return EnemyIntent.new(Kind.BUFF_SELF, stacks, status_type)


static func debuff_player(status_type: StatusTypes.Type, stacks: int) -> EnemyIntent:
	return EnemyIntent.new(Kind.DEBUFF_PLAYER, stacks, status_type)
