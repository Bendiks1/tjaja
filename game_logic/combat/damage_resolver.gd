class_name DamageResolver
extends RefCounted
## Pure damage math, kept separate from CombatantState so the formula can be
## unit-tested in isolation against known input/output pairs.

## Order matches Slay the Spire: add Strength to the base, then apply Weak,
## then Vulnerable, flooring only at the very end. Applying the percentage
## modifiers before flooring avoids compounding rounding errors.
static func calculate_attack_damage(
	base_damage: int,
	attacker_strength: int,
	attacker_is_weak: bool,
	defender_is_vulnerable: bool
) -> int:
	var amount: float = float(max(0, base_damage + attacker_strength))
	if attacker_is_weak:
		amount *= 0.75
	if defender_is_vulnerable:
		amount *= 1.5
	return int(floor(amount))


## Dexterity adds flat block, same as Strength adds flat damage.
static func calculate_block_amount(base_block: int, dexterity: int) -> int:
	return max(0, base_block + dexterity)
