extends GutTest

func _act(node_count: int = 15) -> ActData:
	var act := ActData.new()
	act.act_number = 1
	act.node_count = node_count
	return act


func test_same_seed_produces_an_identical_graph() -> void:
	var act := _act()
	var graph_a: MapGraph = MapGenerator.generate(act, RNGStream.new(42))
	var graph_b: MapGraph = MapGenerator.generate(act, RNGStream.new(42))

	assert_eq(graph_a.nodes.size(), graph_b.nodes.size())
	for i in range(graph_a.nodes.size()):
		assert_eq(graph_a.nodes[i].node_type, graph_b.nodes[i].node_type, "node %d type should match" % i)
		assert_eq(graph_a.nodes[i].connections, graph_b.nodes[i].connections, "node %d connections should match" % i)
	assert_eq(graph_a.boss_node_id, graph_b.boss_node_id)


func test_different_seeds_produce_different_graphs() -> void:
	var act := _act()
	var graph_a: MapGraph = MapGenerator.generate(act, RNGStream.new(1))
	var graph_b: MapGraph = MapGenerator.generate(act, RNGStream.new(2))

	var types_a: Array = graph_a.nodes.map(func(n: MapNode) -> MapNode.NodeType: return n.node_type)
	var types_b: Array = graph_b.nodes.map(func(n: MapNode) -> MapNode.NodeType: return n.node_type)
	assert_ne(types_a, types_b)


func test_first_floor_is_combat_and_a_single_lane() -> void:
	var graph: MapGraph = MapGenerator.generate(_act(), RNGStream.new(7))
	var first_floor: Array[MapNode] = graph.get_nodes_in_floor(0)
	assert_eq(first_floor.size(), 1)
	assert_eq(first_floor[0].node_type, MapNode.NodeType.COMBAT)
	assert_eq(graph.start_node_ids, [first_floor[0].id])


func test_last_floor_is_a_single_boss_node() -> void:
	var graph: MapGraph = MapGenerator.generate(_act(), RNGStream.new(7))
	var last_floor_index: int = graph.get_floor_count() - 1
	var last_floor: Array[MapNode] = graph.get_nodes_in_floor(last_floor_index)

	assert_eq(last_floor.size(), 1)
	assert_eq(last_floor[0].node_type, MapNode.NodeType.BOSS)
	assert_eq(graph.boss_node_id, last_floor[0].id)
	assert_true(last_floor[0].connections.is_empty(), "boss has nowhere further to go")


func test_floor_before_the_boss_is_always_a_rest_site() -> void:
	var graph: MapGraph = MapGenerator.generate(_act(), RNGStream.new(7))
	var rest_floor_index: int = graph.get_floor_count() - 2
	for node in graph.get_nodes_in_floor(rest_floor_index):
		assert_eq(node.node_type, MapNode.NodeType.REST)


func test_every_non_start_node_has_at_least_one_incoming_connection() -> void:
	var graph: MapGraph = MapGenerator.generate(_act(), RNGStream.new(99))
	var reachable: Dictionary = {}
	for start_id in graph.start_node_ids:
		reachable[start_id] = true
	for node in graph.nodes:
		for target_id in node.connections:
			reachable[target_id] = true

	for node in graph.nodes:
		assert_true(reachable.has(node.id), "node %d (floor %d) is unreachable" % [node.id, node.floor])


func test_every_non_boss_node_has_at_least_one_outgoing_connection() -> void:
	var graph: MapGraph = MapGenerator.generate(_act(), RNGStream.new(99))
	for node in graph.nodes:
		if node.id == graph.boss_node_id:
			continue
		assert_false(node.connections.is_empty(), "node %d (floor %d) is a dead end" % [node.id, node.floor])


func test_node_count_is_in_the_right_ballpark() -> void:
	var graph: MapGraph = MapGenerator.generate(_act(15), RNGStream.new(3))
	assert_between(graph.nodes.size(), 13, 20)
