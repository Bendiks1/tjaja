extends Control
## Controller for the combat screen. Owns the CombatState, drives it from taps,
## and re-renders the relevant views from its returned events. This is the
## "orchestrator" for combat specifically — translating pure game-logic events
## into UI updates is exactly the kind of bridging the architecture reserves
## for a controller layer above game_logic/.

## Fired after each event batch is rendered while the fight is still ongoing —
## the run-loop controller uses this as the checkpoint to persist a fresh
## CombatSnapshot, so the app can be killed mid-fight and resumed exactly here.
signal state_changed

const CardViewScene: PackedScene = preload("res://scenes/components/card_view.tscn")
const EnemyViewScene: PackedScene = preload("res://scenes/components/enemy_view.tscn")

@onready var _enemy_row: HBoxContainer = %EnemyRow
@onready var _hand_row: HBoxContainer = %HandRow
@onready var _hp_label: Label = %HpLabel
@onready var _block_label: Label = %BlockLabel
@onready var _energy_label: Label = %EnergyLabel
@onready var _turn_label: Label = %TurnLabel
@onready var _end_turn_button: Button = %EndTurnButton
@onready var _prompt_label: Label = %PromptLabel

var _combat: CombatState
var _enemy_views: Array[EnemyView] = []
var _card_views: Dictionary = {} # instance_id (int) -> CardView
var _awaiting_target_for: int = -1 # instance_id of a card waiting for an enemy target, or -1


func _ready() -> void:
	_end_turn_button.pressed.connect(_on_end_turn_pressed)


## Builds a fresh encounter and starts it. `player_deck` is the full list of
## CardDefinitions in deck order (the run's actual deck, in the real flow);
## `enemies` are freshly-built EnemyStates (one per encounter — never reuse).
func start_encounter(
	starting_hp: int,
	max_energy: int,
	player_deck: Array[CardDefinition],
	enemies: Array[EnemyState],
	rng_seed: int,
	cards_per_turn: int = 5
) -> void:
	var deck := Deck.new()
	var rng := RNGStream.new(rng_seed)
	deck.setup_starting_deck(player_deck, rng)

	var player := PlayerState.new(starting_hp, max_energy)
	_combat = CombatState.new(player, enemies, deck, rng, cards_per_turn)

	_rebuild_enemy_views()
	_apply_events(_combat.start_combat())


## Re-enters an in-progress encounter restored by CombatSnapshot — same
## rendering as a fresh start, just without replaying `start_combat()`'s
## events (the fight is already underway).
func resume_encounter(combat: CombatState) -> void:
	_combat = combat
	_awaiting_target_for = -1
	_end_turn_button.disabled = false
	_rebuild_enemy_views()
	_refresh_player_stats()
	_refresh_enemy_views()
	_rebuild_hand()
	_refresh_prompt()


func _rebuild_enemy_views() -> void:
	for child in _enemy_row.get_children():
		child.queue_free()
	_enemy_views.clear()

	for i in range(_combat.enemies.size()):
		var view: EnemyView = EnemyViewScene.instantiate()
		_enemy_row.add_child(view)
		view.setup(_combat.enemies[i], i)
		view.tapped.connect(_on_enemy_tapped)
		_enemy_views.append(view)


## Re-renders the parts of the UI that could have changed. v1 keeps this
## simple — a full refresh after each batch of events — since placeholder art
## has no animations to sequence; once real art lands this is where per-event
## animation hooks would go.
func _apply_events(events: Array[Dictionary]) -> void:
	_refresh_player_stats()
	_refresh_enemy_views()
	_rebuild_hand()
	_refresh_prompt()

	for event in events:
		if event.get("type") == "combat_ended":
			_on_combat_ended(event.get("outcome"))
			return

	state_changed.emit()


func _refresh_player_stats() -> void:
	var player: PlayerState = _combat.player
	_hp_label.text = "HP %d / %d" % [max(player.current_hp, 0), player.max_hp]
	_block_label.visible = player.block > 0
	_block_label.text = "🛡 %d" % player.block
	_energy_label.text = "⚡ %d / %d" % [player.energy, player.max_energy]
	_turn_label.text = tr("Turn %d") % _combat.turn_number


func _refresh_enemy_views() -> void:
	for view in _enemy_views:
		view.refresh()


func _rebuild_hand() -> void:
	for child in _hand_row.get_children():
		child.queue_free()
	_card_views.clear()

	for card in _combat.deck.hand:
		var view: CardView = CardViewScene.instantiate()
		_hand_row.add_child(view)
		view.setup(card, _combat.player.can_afford(card.definition.cost))
		view.tapped.connect(_on_card_tapped)
		view.set_selected(card.instance_id == _awaiting_target_for)
		_card_views[card.instance_id] = view


func _refresh_prompt() -> void:
	if _awaiting_target_for != -1:
		_prompt_label.text = tr("Choose a target")
		_prompt_label.visible = true
	else:
		_prompt_label.visible = false


func _card_needs_target(definition: CardDefinition) -> bool:
	for effect in definition.effects:
		if effect.target == CardEffect.Target.SINGLE_ENEMY:
			return true
	return false


func _on_card_tapped(instance_id: int) -> void:
	if _combat == null or _combat.get_outcome() != CombatState.Outcome.ONGOING:
		return

	if _awaiting_target_for == instance_id:
		_awaiting_target_for = -1
		_refresh_prompt()
		_rebuild_hand()
		return

	var card: CardInstance = _find_in_hand(instance_id)
	if card == null or not _combat.player.can_afford(card.definition.cost):
		return

	if _card_needs_target(card.definition):
		_awaiting_target_for = instance_id
		_refresh_prompt()
		_rebuild_hand()
	else:
		_play_card(instance_id, -1)


func _on_enemy_tapped(enemy_index: int) -> void:
	if _awaiting_target_for == -1:
		return
	_play_card(_awaiting_target_for, enemy_index)


func _play_card(instance_id: int, target_index: int) -> void:
	_awaiting_target_for = -1
	_apply_events(_combat.play_card(instance_id, target_index))


func _on_end_turn_pressed() -> void:
	if _combat == null or _combat.get_outcome() != CombatState.Outcome.ONGOING:
		return
	_awaiting_target_for = -1
	_apply_events(_combat.end_player_turn())


func _on_combat_ended(outcome: CombatState.Outcome) -> void:
	_end_turn_button.disabled = true
	_prompt_label.visible = true
	_prompt_label.text = tr("Victory!") if outcome == CombatState.Outcome.VICTORY else tr("Defeated...")
	EventBus.combat_finished.emit(outcome)


func _find_in_hand(instance_id: int) -> CardInstance:
	for card in _combat.deck.hand:
		if card.instance_id == instance_id:
			return card
	return null
