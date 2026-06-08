class_name MapGenerator
extends RefCounted
## Builds a branching MapGraph from an act's parameters and a seeded
## RNGStream — same seed always produces the same map. Layout is
## start (1 lane) -> middle floors (3 lanes each) -> boss (1 lane),
## connected so every node is reachable and every non-boss node leads
## somewhere (no dead ends).

const LANES_PER_MIDDLE_FLOOR: int = 3

## Node type pool for middle floors, weighted toward combat with sprinkled
## variety. Elites are mixed in only from the second middle floor onward so
## the run eases the player in first.
const _BASE_TYPE_POOL: Array[MapNode.NodeType] = [
	MapNode.NodeType.COMBAT, MapNode.NodeType.COMBAT, MapNode.NodeType.COMBAT,
	MapNode.NodeType.EVENT, MapNode.NodeType.EVENT,
	MapNode.NodeType.SHOP,
	MapNode.NodeType.REST,
]


static func generate(act: ActData, rng: RNGStream) -> MapGraph:
	var floor_count: int = _floor_count_for(act.node_count)
	var graph := MapGraph.new()
	var floors: Array[Array] = [] # Array[Array[int]] -- node ids per floor
	var next_id: int = 0

	for floor_index in range(floor_count):
		var lane_count: int = 1 if (floor_index == 0 or floor_index == floor_count - 1) else LANES_PER_MIDDLE_FLOOR
		var ids: Array[int] = []
		for lane in range(lane_count):
			var node_type: MapNode.NodeType = _pick_node_type(floor_index, floor_count, rng)
			graph.nodes.append(MapNode.new(next_id, floor_index, lane, node_type))
			ids.append(next_id)
			next_id += 1
		floors.append(ids)

	for floor_index in range(floor_count - 1):
		_connect_floors(graph, floors[floor_index], floors[floor_index + 1], rng)

	graph.start_node_ids = floors[0].duplicate()
	graph.boss_node_id = floors[floor_count - 1][0]
	return graph


## Layout is 1 (start) + middle*3 + 1 (boss). Solve for the smallest middle
## floor count that reaches roughly the requested node total.
static func _floor_count_for(node_count: int) -> int:
	var middle_floors: int = max(2, ceili(float(max(0, node_count - 2)) / float(LANES_PER_MIDDLE_FLOOR)))
	return middle_floors + 2


static func _pick_node_type(floor_index: int, floor_count: int, rng: RNGStream) -> MapNode.NodeType:
	if floor_index == 0:
		return MapNode.NodeType.COMBAT
	if floor_index == floor_count - 1:
		return MapNode.NodeType.BOSS
	if floor_index == floor_count - 2:
		return MapNode.NodeType.REST # guaranteed breather right before the boss

	var pool: Array[MapNode.NodeType] = _BASE_TYPE_POOL.duplicate()
	if floor_index >= 2:
		pool.append(MapNode.NodeType.ELITE)
	return rng.pick(pool)


## Connects each node in `from_ids` to one or two nodes in `to_ids`, then
## back-fills any node in `to_ids` that ended up with no incoming edge —
## guarantees full connectivity without biasing the forward distribution.
static func _connect_floors(graph: MapGraph, from_ids: Array[int], to_ids: Array[int], rng: RNGStream) -> void:
	var incoming_counts: Dictionary = {}
	for to_id in to_ids:
		incoming_counts[to_id] = 0

	for from_id in from_ids:
		var connection_count: int = 1 if rng.chance(0.6) else 2
		connection_count = min(connection_count, to_ids.size())
		var candidates: Array = to_ids.duplicate()
		rng.shuffle(candidates)
		for i in range(connection_count):
			var to_id: int = candidates[i]
			graph.get_node(from_id).connections.append(to_id)
			incoming_counts[to_id] += 1

	for to_id in to_ids:
		if incoming_counts[to_id] == 0:
			var from_id: int = rng.pick(from_ids)
			graph.get_node(from_id).connections.append(to_id)
			incoming_counts[to_id] += 1
