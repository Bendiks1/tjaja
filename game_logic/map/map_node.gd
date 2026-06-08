class_name MapNode
extends RefCounted
## One node in a run's map graph. `connections` lists the ids of nodes one
## floor ahead that this node can travel to — the only thing MapProgress
## needs to know what's reachable from "here".

enum NodeType { COMBAT, ELITE, SHOP, REST, EVENT, BOSS }

var id: int
var floor: int
var lane: int
var node_type: NodeType
var connections: Array[int] = []

func _init(node_id: int, floor_index: int, lane_index: int, type: NodeType) -> void:
	id = node_id
	floor = floor_index
	lane = lane_index
	node_type = type
