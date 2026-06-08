class_name StatusTypes
extends RefCounted
## Shared enum for status effects so combat, cards, and persistence agree on
## the same integer values (also what gets written to save files).

enum Type {
	VULNERABLE, ## Take 50% more attack damage. Decays by 1 at end of owner's turn.
	WEAK,       ## Deal 25% less attack damage. Decays by 1 at end of owner's turn.
	STRENGTH,   ## +N attack damage. Permanent for the combat in v1 (no decay cards yet).
	DEXTERITY,  ## +N block gained from cards. Permanent for the combat in v1.
}

## Statuses that lose one stack at the end of the owning combatant's turn.
const DECAYING_STATUSES: Array[Type] = [Type.VULNERABLE, Type.WEAK]
