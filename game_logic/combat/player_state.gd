class_name PlayerState
extends CombatantState
## The player's combat-only state. Deck/relics/potions live in RunState;
## this is just what combat math needs turn to turn.

var energy: int
var max_energy: int


func _init(starting_hp: int, starting_max_energy: int) -> void:
	super._init(starting_hp)
	max_energy = starting_max_energy
	energy = starting_max_energy


func reset_energy() -> void:
	energy = max_energy


func can_afford(cost: int) -> bool:
	return energy >= cost


## Returns true if the cost was paid. Callers must check can_afford first;
## this never goes negative so a bad call can't corrupt state.
func spend_energy(cost: int) -> bool:
	if not can_afford(cost):
		return false
	energy -= cost
	return true
