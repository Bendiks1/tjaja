extends Control
## The run-loop controller — the only thing that knows how all the screens
## fit together. Owns RunState transitions, persistence checkpoints, and
## routes EventBus signals from individual screens (which know nothing about
## each other) into the right next screen. This is the top-level "bridging"
## layer the architecture reserves above game_logic/ and content.

const MainMenuScene: PackedScene = preload("res://scenes/screens/main_menu.tscn")
const CharacterSelectScreenScene: PackedScene = preload("res://scenes/screens/character_select_screen.tscn")
const MapScreenScene: PackedScene = preload("res://scenes/screens/map_screen.tscn")
const CombatScreenScene: PackedScene = preload("res://scenes/screens/combat_screen.tscn")
const CardRewardScreenScene: PackedScene = preload("res://scenes/screens/card_reward_screen.tscn")

const REST_HEAL_FRACTION: float = 0.3
const CARDS_PER_TURN: int = 5

var _main_menu: Control
var _character_select: Control
var _map_screen: Control
var _combat_screen: Control
var _card_reward: Control

var _current_screen: Control
var _last_node_type: MapNode.NodeType = MapNode.NodeType.COMBAT


func _ready() -> void:
	_main_menu = _add_screen(MainMenuScene)
	_character_select = _add_screen(CharacterSelectScreenScene)
	_map_screen = _add_screen(MapScreenScene)
	_combat_screen = _add_screen(CombatScreenScene)
	_card_reward = _add_screen(CardRewardScreenScene)

	_main_menu.new_run_requested.connect(_on_new_run_requested)
	_main_menu.continue_requested.connect(_on_continue_requested)
	_character_select.character_chosen.connect(_on_character_chosen)
	_card_reward.card_chosen.connect(_on_card_chosen)
	_card_reward.skipped.connect(_on_reward_skipped)
	_combat_screen.state_changed.connect(_persist_combat_snapshot)
	EventBus.map_node_chosen.connect(_on_map_node_chosen)
	EventBus.combat_finished.connect(_on_combat_finished)

	_show_main_menu()


func _add_screen(scene: PackedScene) -> Control:
	var screen: Control = scene.instantiate()
	screen.visible = false
	add_child(screen)
	return screen


func _show_only(screen: Control) -> void:
	if _current_screen != null:
		_current_screen.visible = false
	_current_screen = screen
	_current_screen.visible = true


func _show_main_menu() -> void:
	_main_menu.refresh(SaveSystem.has_save())
	_show_only(_main_menu)


# --- Starting / resuming a run -------------------------------------------

func _on_new_run_requested() -> void:
	_character_select.show_characters(ContentDatabase.all_characters())
	_show_only(_character_select)


func _on_character_chosen(character: CharacterData) -> void:
	RunState.start_new_run(character, randi())
	SaveSystem.save(RunState)
	_show_map()


func _on_continue_requested() -> void:
	if not SaveSystem.load_into(RunState):
		_show_main_menu()
		return

	if RunState.is_in_combat():
		_resume_combat()
	else:
		_show_map()


# --- Map -------------------------------------------------------------------

func _current_act() -> ActData:
	return ContentDatabase.act_data(RunState.act_number)


func _show_map() -> void:
	var resume_progress: MapProgress = null
	if RunState.map_current_node_id != -1 or not RunState.map_visited_node_ids.is_empty():
		var graph: MapGraph = MapGenerator.generate(_current_act(), RNGStream.new(RunState.run_seed))
		resume_progress = MapProgress.new(graph)
		resume_progress.current_node_id = RunState.map_current_node_id
		resume_progress.visited_node_ids = RunState.map_visited_node_ids.duplicate()

	_map_screen.start_map(_current_act(), RunState.run_seed, resume_progress)
	_show_only(_map_screen)


func _on_map_node_chosen(node_id: int, node_type: MapNode.NodeType) -> void:
	_last_node_type = node_type
	RunState.map_current_node_id = _map_screen.progress.current_node_id
	RunState.map_visited_node_ids = _map_screen.progress.visited_node_ids.duplicate()
	SaveSystem.save(RunState)

	match node_type:
		MapNode.NodeType.COMBAT, MapNode.NodeType.ELITE, MapNode.NodeType.BOSS:
			_start_combat_for_node(node_id, node_type)
		MapNode.NodeType.REST:
			_resolve_rest()
		MapNode.NodeType.SHOP, MapNode.NodeType.EVENT:
			_show_map() # placeholder until shop/event content lands — pass straight through


# --- Combat -----------------------------------------------------------------

func _enemy_for_node(act: ActData, node_type: MapNode.NodeType, rng: RNGStream) -> EnemyState:
	match node_type:
		MapNode.NodeType.ELITE:
			return rng.pick(act.elite_enemies).to_enemy_state()
		MapNode.NodeType.BOSS:
			return act.boss.to_enemy_state()
		_:
			return rng.pick(act.regular_enemies).to_enemy_state()


func _start_combat_for_node(node_id: int, node_type: MapNode.NodeType) -> void:
	var encounter_seed: int = RunState.run_seed + node_id
	var rng := RNGStream.new(encounter_seed)
	var enemy: EnemyState = _enemy_for_node(_current_act(), node_type, rng)

	_combat_screen.start_encounter(
		RunState.max_hp,
		3,
		RunState.build_deck_definitions(),
		[enemy],
		encounter_seed,
		CARDS_PER_TURN
	)
	_combat_screen._combat.player.current_hp = RunState.current_hp
	_persist_combat_snapshot()
	_show_only(_combat_screen)


func _resume_combat() -> void:
	var combat: CombatState = CombatSnapshot.restore(RunState.combat_snapshot)
	_combat_screen.resume_encounter(combat)
	_show_only(_combat_screen)


## Saves the run with the in-progress fight captured, so the app can be
## killed at any point mid-combat and resumed exactly where it left off.
func _persist_combat_snapshot() -> void:
	RunState.combat_snapshot = CombatSnapshot.capture(_combat_screen._combat)
	SaveSystem.save(RunState)


func _on_combat_finished(outcome: CombatState.Outcome) -> void:
	RunState.combat_snapshot = {}
	RunState.current_hp = max(_combat_screen._combat.player.current_hp, 0)

	if outcome == CombatState.Outcome.DEFEAT:
		_end_run()
		return

	SaveSystem.save(RunState)
	if _last_node_type == MapNode.NodeType.BOSS:
		_end_run()
	else:
		_card_reward.show_offer(RunState.build_deck_definitions(), RunState.run_seed + RunState.map_current_node_id, 3)
		_show_only(_card_reward)


# --- Card reward -------------------------------------------------------------

func _on_card_chosen(card: CardDefinition) -> void:
	RunState.deck_card_ids.append(card.id)
	SaveSystem.save(RunState)
	_show_map()


func _on_reward_skipped() -> void:
	SaveSystem.save(RunState)
	_show_map()


# --- Rest sites ---------------------------------------------------------------

func _resolve_rest() -> void:
	var heal_amount: int = int(RunState.max_hp * REST_HEAL_FRACTION)
	RunState.current_hp = min(RunState.max_hp, RunState.current_hp + heal_amount)
	SaveSystem.save(RunState)
	_show_map()


# --- Run end -------------------------------------------------------------------

func _end_run() -> void:
	SaveSystem.delete_save()
	RunState.clear()
	_show_main_menu()
