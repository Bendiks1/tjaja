class_name MapProgress
extends RefCounted
## Tracks where a run currently is on its map and what's reachable next.
## Serializable as just a node id + a visited list — the graph itself is
## regenerated from the run's seed, so it never needs saving.

var graph: MapGraph
var current_node_id: int = -1 # -1 == "on the map screen, haven't entered yet"
var visited_node_ids: Array[int] = []

func _init(map_graph: MapGraph) -> void:
	graph = map_graph


func get_available_node_ids() -> Array[int]:
	if current_node_id == -1:
		return graph.start_node_ids.duplicate()
	var current: MapNode = graph.get_node(current_node_id)
	return current.connections.duplicate() if current != null else []


func can_travel_to(node_id: int) -> bool:
	return get_available_node_ids().has(node_id)


## Moves to `node_id` if it's reachable from here. Returns false (no-op) for
## an illegal move — same "UI bug, not a state-machine event" reasoning as
## CombatState.play_card.
func travel_to(node_id: int) -> bool:
	if not can_travel_to(node_id):
		return false
	current_node_id = node_id
	visited_node_ids.append(node_id)
	return true


func is_on_boss_node() -> bool:
	return current_node_id == graph.boss_node_id


func has_visited(node_id: int) -> bool:
	return visited_node_ids.has(node_id)
