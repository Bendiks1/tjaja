extends GutTest
## End-to-end tests for the run-loop controller: routing between screens,
## persisting checkpoints, and — the scenario the brief calls out by name —
## resuming a run that was saved mid-combat.

const GameRootScene: PackedScene = preload("res://scenes/screens/game_root.tscn")

var _root: Control


func before_each() -> void:
	_root = GameRootScene.instantiate()
	add_child_autofree(_root)
	SaveSystem.delete_save()
	RunState.clear()


func after_each() -> void:
	SaveSystem.delete_save()
	RunState.clear()


func _revenant() -> CharacterData:
	return ContentDatabase.character_data(&"revenant")


func test_choosing_a_character_starts_a_run_and_shows_the_map() -> void:
	_root._on_new_run_requested()
	_root._on_character_chosen(_revenant())

	assert_true(RunState.has_active_run)
	assert_eq(_root._current_screen, _root._map_screen)
	assert_true(SaveSystem.has_save())


func test_choosing_a_combat_node_starts_combat_and_persists_a_snapshot() -> void:
	_root._on_character_chosen(_revenant())
	var node_id: int = _root._map_screen.graph.start_node_ids[0]

	_root._on_map_node_chosen(node_id, MapNode.NodeType.COMBAT)

	assert_eq(_root._current_screen, _root._combat_screen)
	assert_false(RunState.combat_snapshot.is_empty(), "snapshot should be persisted as soon as combat starts")
	assert_true(SaveSystem.has_save())


func test_finishing_combat_clears_the_snapshot_and_shows_the_reward_screen() -> void:
	_root._on_character_chosen(_revenant())
	var node_id: int = _root._map_screen.graph.start_node_ids[0]
	_root._on_map_node_chosen(node_id, MapNode.NodeType.COMBAT)

	for enemy in _root._combat_screen._combat.enemies:
		enemy.current_hp = 0
	_root._on_combat_finished(CombatState.Outcome.VICTORY)

	assert_eq(_root._current_screen, _root._card_reward)
	assert_true(RunState.combat_snapshot.is_empty())


func test_resuming_a_run_saved_mid_combat_restores_the_fight() -> void:
	_root._on_character_chosen(_revenant())
	var node_id: int = _root._map_screen.graph.start_node_ids[0]
	_root._on_map_node_chosen(node_id, MapNode.NodeType.COMBAT)

	_root._combat_screen._combat.player.take_damage(15)
	_root._persist_combat_snapshot()
	var hp_when_saved: int = _root._combat_screen._combat.player.current_hp

	# Simulate killing the app: a brand new GameRoot loads straight from disk.
	var fresh_root: Control = GameRootScene.instantiate()
	add_child_autofree(fresh_root)
	RunState.clear()
	fresh_root._on_continue_requested()

	assert_eq(fresh_root._current_screen, fresh_root._combat_screen)
	assert_eq(fresh_root._combat_screen._combat.player.current_hp, hp_when_saved)
	assert_eq(fresh_root._combat_screen._enemy_views.size(), 1)
