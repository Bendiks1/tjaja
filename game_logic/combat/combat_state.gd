class_name CombatState
extends RefCounted
## Orchestrates one combat encounter: turn order, card resolution, enemy AI
## execution, win/loss detection. Zero Node references — every action returns
## a list of event dictionaries describing what happened, which an autoload
## (CombatOrchestrator, built alongside the combat scene) turns into UI signals.
##
## Event shape: {"type": <String>, ...fields}. "target"/"source" identify a
## combatant as "player" or "enemy_<index>" so the UI can route to the right view.

enum Outcome { ONGOING, VICTORY, DEFEAT }

var player: PlayerState
var enemies: Array[EnemyState]
var deck: Deck
var rng: RNGStream
var draw_per_turn: int
var turn_number: int = 0

func _init(
	player_state: PlayerState,
	enemy_states: Array[EnemyState],
	card_deck: Deck,
	rng_stream: RNGStream,
	cards_per_turn: int = 5
) -> void:
	player = player_state
	enemies = enemy_states
	deck = card_deck
	rng = rng_stream
	draw_per_turn = cards_per_turn


func get_outcome() -> Outcome:
	if not player.is_alive():
		return Outcome.DEFEAT
	for enemy in enemies:
		if enemy.is_alive():
			return Outcome.ONGOING
	return Outcome.VICTORY


func get_living_enemies() -> Array[EnemyState]:
	var living: Array[EnemyState] = []
	for enemy in enemies:
		if enemy.is_alive():
			living.append(enemy)
	return living


## Starts the encounter — the first player turn begins immediately.
func start_combat() -> Array[Dictionary]:
	turn_number = 1
	return _begin_player_turn()


## Plays a card from hand. `target_index` selects which living enemy to target
## for SINGLE_ENEMY effects; ignored otherwise. Illegal plays (card not in
## hand, insufficient energy) are a UI bug, not a state-machine event, so they
## silently no-op — the UI is expected to disable unplayable cards.
func play_card(instance_id: int, target_index: int = -1) -> Array[Dictionary]:
	var card: CardInstance = _find_in_hand(instance_id)
	if card == null or not player.can_afford(card.definition.cost):
		return []

	player.spend_energy(card.definition.cost)
	deck.remove_from_hand(instance_id)

	var events: Array[Dictionary] = [_event("card_played", {
		"instance_id": instance_id,
		"card_id": card.definition.id,
		"energy_remaining": player.energy,
	})]
	for effect in card.definition.effects:
		events.append_array(_resolve_effect(effect, target_index))

	if card.definition.exhausts:
		deck.send_to_exhaust(card)
	else:
		deck.send_to_discard(card)
	return events


## Ends the player's turn: discard hand, decay player debuffs, run every living
## enemy's telegraphed action, then either start the next player turn or leave
## combat ended (the caller reads get_outcome() to know which).
func end_player_turn() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	deck.discard_hand()
	player.decay_debuffs()
	events.append(_event("turn_ended", {"side": "player", "turn": turn_number}))

	events.append_array(_run_enemy_turn())

	if get_outcome() == Outcome.ONGOING:
		turn_number += 1
		events.append_array(_begin_player_turn())
	else:
		events.append(_event("combat_ended", {"outcome": get_outcome()}))
	return events


func _begin_player_turn() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	player.reset_block()
	player.reset_energy()
	events.append(_event("turn_started", {"side": "player", "turn": turn_number}))
	events.append_array(_draw_cards(draw_per_turn))
	return events


func _draw_cards(count: int) -> Array[Dictionary]:
	var drawn: Array[CardInstance] = deck.draw(count, rng)
	var instance_ids: Array[int] = []
	for card in drawn:
		instance_ids.append(card.instance_id)
	return [_event("cards_drawn", {"instance_ids": instance_ids})]


func _run_enemy_turn() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for i in range(enemies.size()):
		var enemy: EnemyState = enemies[i]
		if not enemy.is_alive():
			continue
		enemy.reset_block()
		events.append_array(_resolve_enemy_intent(enemy, i))
		if not player.is_alive():
			break
		enemy.decay_debuffs()
		enemy.advance_intent()
		events.append(_event("enemy_intent_changed", {
			"enemy_index": i,
			"intent_kind": enemy.current_intent.kind,
			"intent_value": enemy.current_intent.value,
		}))
	return events


func _resolve_enemy_intent(enemy: EnemyState, enemy_index: int) -> Array[Dictionary]:
	var intent: EnemyIntent = enemy.current_intent
	var source: String = "enemy_%d" % enemy_index
	match intent.kind:
		EnemyIntent.Kind.ATTACK:
			var amount: int = DamageResolver.calculate_attack_damage(
				intent.value,
				enemy.get_status(StatusTypes.Type.STRENGTH),
				enemy.has_status(StatusTypes.Type.WEAK),
				player.has_status(StatusTypes.Type.VULNERABLE)
			)
			var hp_lost: int = player.take_damage(amount)
			return [_event("damage_dealt", {
				"source": source, "target": "player", "amount": amount,
				"hp_lost": hp_lost, "hp_remaining": player.current_hp, "block_remaining": player.block,
			})]
		EnemyIntent.Kind.DEFEND:
			var amount: int = DamageResolver.calculate_block_amount(intent.value, enemy.get_status(StatusTypes.Type.DEXTERITY))
			enemy.add_block(amount)
			return [_event("block_gained", {"target": source, "amount": amount})]
		EnemyIntent.Kind.BUFF_SELF:
			enemy.add_status(intent.status, intent.value)
			return [_event("status_applied", {"target": source, "status": intent.status, "stacks": intent.value, "total_stacks": enemy.get_status(intent.status)})]
		EnemyIntent.Kind.DEBUFF_PLAYER:
			player.add_status(intent.status, intent.value)
			return [_event("status_applied", {"target": "player", "status": intent.status, "stacks": intent.value, "total_stacks": player.get_status(intent.status)})]
	return []


func _resolve_effect(effect: CardEffect, target_index: int) -> Array[Dictionary]:
	match effect.kind:
		CardEffect.Kind.DAMAGE:
			return _resolve_damage(effect, target_index)
		CardEffect.Kind.BLOCK:
			var amount: int = DamageResolver.calculate_block_amount(effect.value, player.get_status(StatusTypes.Type.DEXTERITY))
			player.add_block(amount)
			return [_event("block_gained", {"target": "player", "amount": amount})]
		CardEffect.Kind.APPLY_STATUS:
			return _resolve_apply_status(effect, target_index)
		CardEffect.Kind.DRAW_CARDS:
			return _draw_cards(effect.value)
		CardEffect.Kind.GAIN_ENERGY:
			player.energy += effect.value
			return [_event("energy_changed", {"amount": effect.value, "energy_remaining": player.energy})]
		CardEffect.Kind.HEAL:
			player.heal(effect.value)
			return [_event("heal", {"target": "player", "amount": effect.value, "hp_remaining": player.current_hp})]
	return []


func _resolve_damage(effect: CardEffect, target_index: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var attacker_strength: int = player.get_status(StatusTypes.Type.STRENGTH)
	var attacker_weak: bool = player.has_status(StatusTypes.Type.WEAK)
	for target in _resolve_targets(effect.target, target_index):
		var amount: int = DamageResolver.calculate_attack_damage(
			effect.value, attacker_strength, attacker_weak, target.has_status(StatusTypes.Type.VULNERABLE)
		)
		var hp_lost: int = target.take_damage(amount)
		events.append(_event("damage_dealt", {
			"source": "player", "target": _identify(target), "amount": amount,
			"hp_lost": hp_lost, "hp_remaining": target.current_hp, "block_remaining": target.block,
		}))
	return events


func _resolve_apply_status(effect: CardEffect, target_index: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for target in _resolve_targets(effect.target, target_index):
		target.add_status(effect.status, effect.value)
		events.append(_event("status_applied", {
			"target": _identify(target), "status": effect.status,
			"stacks": effect.value, "total_stacks": target.get_status(effect.status),
		}))
	return events


func _resolve_targets(target_kind: CardEffect.Target, target_index: int) -> Array[CombatantState]:
	var result: Array[CombatantState] = []
	match target_kind:
		CardEffect.Target.SELF:
			result.append(player)
		CardEffect.Target.SINGLE_ENEMY:
			var chosen: EnemyState = _enemy_at(target_index)
			if chosen != null:
				result.append(chosen)
		CardEffect.Target.ALL_ENEMIES:
			for enemy in get_living_enemies():
				result.append(enemy)
		CardEffect.Target.RANDOM_ENEMY:
			var living: Array[EnemyState] = get_living_enemies()
			if not living.is_empty():
				result.append(rng.pick(living))
	return result


func _enemy_at(index: int) -> EnemyState:
	if index < 0 or index >= enemies.size():
		return null
	var enemy: EnemyState = enemies[index]
	return enemy if enemy.is_alive() else null


func _find_in_hand(instance_id: int) -> CardInstance:
	for card in deck.hand:
		if card.instance_id == instance_id:
			return card
	return null


func _identify(combatant: CombatantState) -> String:
	if combatant == player:
		return "player"
	for i in range(enemies.size()):
		if enemies[i] == combatant:
			return "enemy_%d" % i
	return "unknown"


func _event(type: String, data: Dictionary) -> Dictionary:
	var event: Dictionary = {"type": type}
	event.merge(data)
	return event
