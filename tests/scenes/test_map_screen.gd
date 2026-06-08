extends GutTest
## Integration tests for the map screen controller: generating a graph,
## rendering available choices, and routing taps through MapProgress.

const MapScreenScene: PackedScene = preload("res://scenes/screens/map_screen.tscn")

func _act(node_count: int = 15) -> ActData:
	var act := ActData.new()
	act.act_number = 1
	act.node_count = node_count
	return act


func test_start_map_renders_a_choice_per_available_node() -> void:
	var screen: Control = MapScreenScene.instantiate()
	add_child_autofree(screen)

	screen.start_map(_act(), 7)

	assert_eq(screen._choice_row.get_child_count(), screen.progress.get_available_node_ids().size())


func test_choosing_a_node_travels_and_emits_event_bus_signal() -> void:
	var screen: Control = MapScreenScene.instantiate()
	add_child_autofree(screen)
	screen.start_map(_act(), 7)

	var watcher := watch_signals(EventBus)
	var first_choice: Control = screen._choice_row.get_child(0)
	var node_id: int = screen.graph.start_node_ids[0]

	first_choice.chosen.emit(node_id)

	assert_signal_emitted_with_parameters(EventBus, "map_node_chosen", [node_id, screen.graph.get_node(node_id).node_type])
	assert_eq(screen.progress.current_node_id, node_id)


func test_choosing_a_node_refreshes_available_choices() -> void:
	var screen: Control = MapScreenScene.instantiate()
	add_child_autofree(screen)
	screen.start_map(_act(), 7)

	var node_id: int = screen.graph.start_node_ids[0]
	screen._on_node_chosen(node_id)

	assert_eq(screen._choice_row.get_child_count(), screen.progress.get_available_node_ids().size())
	assert_eq(screen._floor_label.text, tr("Floor %d") % screen.graph.get_node(node_id).floor)
