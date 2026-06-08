class_name CombatSnapshot
extends RefCounted
## Captures and restores a CombatState as plain data, so a run can be saved
## and resumed mid-fight. Lives in persistence/ (not game_logic/) because it
## bridges pure combat objects to the content database for id lookups —
## exactly the kind of translation the architecture keeps out of game_logic/.

## Returns a JSON-safe Dictionary describing `combat` completely enough to
## reconstruct it via `restore()`.
static func capture(combat: CombatState) -> Dictionary:
	return {
		"player": _capture_combatant(combat.player, {"energy": combat.player.energy, "max_energy": combat.player.max_energy}),
		"enemies": combat.enemies.map(_capture_enemy),
		"deck": _capture_deck(combat.deck),
		"rng_state": combat.rng.get_state(),
		"rng_seed": combat.rng.get_seed(),
		"draw_per_turn": combat.draw_per_turn,
		"turn_number": combat.turn_number,
	}


## Rebuilds a CombatState from a Dictionary produced by `capture()`.
static func restore(data: Dictionary) -> CombatState:
	var player_data: Dictionary = data["player"]
	var player := PlayerState.new(int(player_data["max_hp"]), int(player_data["max_energy"]))
	_restore_combatant(player, player_data)
	player.energy = int(player_data["energy"])

	var enemies: Array[EnemyState] = []
	for enemy_data in data["enemies"]:
		enemies.append(_restore_enemy(enemy_data))

	var rng := RNGStream.new(int(data["rng_seed"]))
	rng.set_state(int(data["rng_state"]))

	var deck := _restore_deck(data["deck"])

	var combat := CombatState.new(player, enemies, deck, rng, int(data["draw_per_turn"]))
	combat.turn_number = int(data["turn_number"])
	return combat


static func _capture_combatant(combatant: CombatantState, extra: Dictionary) -> Dictionary:
	var statuses: Array = []
	for status in combatant.statuses:
		statuses.append([int(status), int(combatant.statuses[status])])
	var base: Dictionary = {
		"current_hp": combatant.current_hp,
		"max_hp": combatant.max_hp,
		"block": combatant.block,
		"statuses": statuses,
	}
	base.merge(extra)
	return base


static func _restore_combatant(combatant: CombatantState, data: Dictionary) -> void:
	combatant.current_hp = int(data["current_hp"])
	combatant.block = int(data["block"])
	combatant.statuses.clear()
	for entry in data["statuses"]:
		combatant.statuses[int(entry[0])] = int(entry[1])


static func _capture_enemy(enemy: EnemyState) -> Dictionary:
	var data: Dictionary = _capture_combatant(enemy, {"enemy_id": String(enemy.enemy_id), "pattern_index": enemy.get_pattern_index()})
	return data


static func _restore_enemy(data: Dictionary) -> EnemyState:
	var enemy_id := StringName(data["enemy_id"])
	var enemy: EnemyState = ContentDatabase.enemy_data(enemy_id).to_enemy_state()
	_restore_combatant(enemy, data)
	enemy.set_pattern_index(int(data["pattern_index"]))
	return enemy


static func _capture_deck(deck: Deck) -> Dictionary:
	return {
		"draw_pile": deck.draw_pile.map(_capture_card),
		"hand": deck.hand.map(_capture_card),
		"discard_pile": deck.discard_pile.map(_capture_card),
		"exhaust_pile": deck.exhaust_pile.map(_capture_card),
		"next_instance_id": deck.get_next_instance_id(),
	}


static func _capture_card(card: CardInstance) -> Dictionary:
	return {"instance_id": card.instance_id, "card_id": String(card.definition.id)}


static func _restore_deck(data: Dictionary) -> Deck:
	var deck := Deck.new()
	deck.draw_pile = _restore_pile(data["draw_pile"])
	deck.hand = _restore_pile(data["hand"])
	deck.discard_pile = _restore_pile(data["discard_pile"])
	deck.exhaust_pile = _restore_pile(data["exhaust_pile"])
	deck.set_next_instance_id(int(data["next_instance_id"]))
	return deck


static func _restore_pile(entries: Array) -> Array[CardInstance]:
	var pile: Array[CardInstance] = []
	for entry in entries:
		var card_id := StringName(entry["card_id"])
		var definition: CardDefinition = ContentDatabase.card_data(card_id).to_definition()
		pile.append(CardInstance.new(int(entry["instance_id"]), definition))
	return pile
