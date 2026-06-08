extends GutTest

var graph: MapGraph
var progress: MapProgress

## Builds a tiny, fixed graph (not generated) so travel rules are tested
## against known topology rather than a random one:
##   start(0) -> {a(1), b(2)} -> boss(3)
func before_each() -> void:
	graph = MapGraph.new()
	var start := MapNode.new(0, 0, 0, MapNode.NodeType.COMBAT)
	var a := MapNode.new(1, 1, 0, MapNode.NodeType.COMBAT)
	var b := MapNode.new(2, 1, 1, MapNode.NodeType.SHOP)
	var boss := MapNode.new(3, 2, 0, MapNode.NodeType.BOSS)
	start.connections = [1, 2]
	a.connections = [3]
	b.connections = [3]
	graph.nodes = [start, a, b, boss]
	graph.start_node_ids = [0]
	graph.boss_node_id = 3

	progress = MapProgress.new(graph)


func test_initial_available_nodes_are_the_start_nodes() -> void:
	assert_eq(progress.get_available_node_ids(), [0])
	assert_true(progress.can_travel_to(0))
	assert_false(progress.can_travel_to(1))


func test_travel_to_a_reachable_node_succeeds_and_records_visit() -> void:
	assert_true(progress.travel_to(0))
	assert_eq(progress.current_node_id, 0)
	assert_eq(progress.visited_node_ids, [0])
	assert_true(progress.has_visited(0))


func test_travel_to_an_unreachable_node_is_a_no_op() -> void:
	assert_false(progress.travel_to(3), "can't jump straight to the boss")
	assert_eq(progress.current_node_id, -1)
	assert_true(progress.visited_node_ids.is_empty())


func test_available_nodes_update_after_travel() -> void:
	progress.travel_to(0)
	assert_eq(progress.get_available_node_ids(), [1, 2])

	progress.travel_to(2)
	assert_eq(progress.get_available_node_ids(), [3])


func test_is_on_boss_node_only_true_at_the_boss() -> void:
	progress.travel_to(0)
	assert_false(progress.is_on_boss_node())
	progress.travel_to(1)
	progress.travel_to(3)
	assert_true(progress.is_on_boss_node())
