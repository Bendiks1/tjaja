class_name CombatantState
extends RefCounted
## Runtime HP/block/status bookkeeping shared by the player and enemies.
## Pure data + the rules for mutating it — no knowledge of cards, turns, or UI.

var current_hp: int
var max_hp: int
var block: int = 0
var statuses: Dictionary = {} # StatusTypes.Type -> int stacks, zero-stack entries are removed


func _init(starting_hp: int) -> void:
	max_hp = starting_hp
	current_hp = starting_hp


func is_alive() -> bool:
	return current_hp > 0


func get_status(status: StatusTypes.Type) -> int:
	return statuses.get(status, 0)


func has_status(status: StatusTypes.Type) -> bool:
	return get_status(status) > 0


## Adds (or removes, with a negative amount) stacks, dropping the entry once it hits zero.
func add_status(status: StatusTypes.Type, stacks: int) -> void:
	var total: int = get_status(status) + stacks
	if total <= 0:
		statuses.erase(status)
	else:
		statuses[status] = total


func add_block(amount: int) -> void:
	if amount > 0:
		block += amount


## Clears block — happens to everyone at the start of their turn (no "Barricade" relic in v1).
func reset_block() -> void:
	block = 0


## Applies damage, absorbing with block first. Returns the HP actually lost,
## which combat events report back to the UI for damage-number popups.
func take_damage(amount: int) -> int:
	if amount <= 0:
		return 0
	var absorbed: int = min(block, amount)
	block -= absorbed
	var remaining: int = amount - absorbed
	var hp_lost: int = min(current_hp, remaining)
	current_hp -= hp_lost
	return hp_lost


func heal(amount: int) -> void:
	if amount > 0:
		current_hp = min(max_hp, current_hp + amount)


## Decays Vulnerable/Weak by one stack. Called at the end of this combatant's own turn —
## matches Slay the Spire's timing, where debuffs tick down only on the affected side's turn.
func decay_debuffs() -> void:
	for status in StatusTypes.DECAYING_STATUSES:
		if has_status(status):
			add_status(status, -1)
