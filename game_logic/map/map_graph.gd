class_name MapGraph
extends RefCounted
## The full node graph for one act's map: every node plus where a run can
## start and where it must end.

var nodes: Array[MapNode] = []
var start_node_ids: Array[int] = []
var boss_node_id: int = -1

func get_node(id: int) -> MapNode:
	for node in nodes:
		if node.id == id:
			return node
	return null

func get_floor_count() -> int:
	var max_floor: int = -1
	for node in nodes:
		max_floor = max(max_floor, node.floor)
	return max_floor + 1

func get_nodes_in_floor(floor_index: int) -> Array[MapNode]:
	var result: Array[MapNode] = []
	for node in nodes:
		if node.floor == floor_index:
			result.append(node)
	return result
