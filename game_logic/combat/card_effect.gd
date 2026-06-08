class_name CardEffect
extends RefCounted
## One atomic thing a card does. A card's effect list is resolved in order;
## keeping each effect this small is what lets 30 cards be expressed as data
## (CardData.tres in the data layer) instead of 30 bespoke scripts.

enum Kind {
	DAMAGE,       ## Deal `value` damage to the target(s) (Strength/Weak/Vulnerable applied at resolution).
	BLOCK,        ## Gain `value` block (Dexterity applied at resolution). Target is always SELF.
	APPLY_STATUS, ## Apply `value` stacks of `status` to the target(s).
	DRAW_CARDS,   ## Draw `value` cards. Target is always SELF.
	GAIN_ENERGY,  ## Gain `value` energy this turn. Target is always SELF.
	HEAL,         ## Restore `value` HP. Target is always SELF.
}

enum Target {
	SELF,
	SINGLE_ENEMY, ## The enemy the player targeted when playing the card.
	ALL_ENEMIES,
	RANDOM_ENEMY,
}

var kind: Kind
var target: Target
var value: int
var status: StatusTypes.Type # only meaningful when kind == APPLY_STATUS

func _init(
	effect_kind: Kind,
	effect_target: Target,
	effect_value: int,
	status_type: StatusTypes.Type = StatusTypes.Type.STRENGTH
) -> void:
	kind = effect_kind
	target = effect_target
	value = effect_value
	status = status_type


static func damage(target_kind: Target, amount: int) -> CardEffect:
	return CardEffect.new(Kind.DAMAGE, target_kind, amount)


static func block(amount: int) -> CardEffect:
	return CardEffect.new(Kind.BLOCK, Target.SELF, amount)


static func apply_status(target_kind: Target, status_type: StatusTypes.Type, stacks: int) -> CardEffect:
	return CardEffect.new(Kind.APPLY_STATUS, target_kind, stacks, status_type)


static func draw_cards(amount: int) -> CardEffect:
	return CardEffect.new(Kind.DRAW_CARDS, Target.SELF, amount)


static func gain_energy(amount: int) -> CardEffect:
	return CardEffect.new(Kind.GAIN_ENERGY, Target.SELF, amount)


static func heal(amount: int) -> CardEffect:
	return CardEffect.new(Kind.HEAL, Target.SELF, amount)
