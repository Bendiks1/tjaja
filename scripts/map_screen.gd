extends Control
## Controller for the map screen. Owns a MapGraph + MapProgress, renders the
## currently-available node choices as tappable NodeChoiceViews, and reports
## the player's pick to the run-loop controller via EventBus — translating
## pure map-progress state into UI is exactly the bridging this layer is for.

const NodeChoiceViewScene: PackedScene = preload("res://scenes/components/node_choice_view.tscn")

@onready var _choice_row: HBoxContainer = %ChoiceRow
@onready var _floor_label: Label = %FloorLabel

var graph: MapGraph
var progress: MapProgress


## Builds a fresh map for `act` from `rng_seed` and renders the start choices.
## Called for a new run; `resume_from` lets a restored run skip straight to
## wherever it left off without re-rolling the graph (same seed regenerates
## an identical graph, so progress can be replayed onto it).
func start_map(act: ActData, rng_seed: int, resume_from: MapProgress = null) -> void:
	graph = MapGenerator.generate(act, RNGStream.new(rng_seed))
	progress = resume_from if resume_from != null else MapProgress.new(graph)
	_refresh()


func _refresh() -> void:
	for child in _choice_row.get_children():
		child.queue_free()

	for node_id in progress.get_available_node_ids():
		var node: MapNode = graph.get_node(node_id)
		var view: NodeChoiceView = NodeChoiceViewScene.instantiate()
		_choice_row.add_child(view)
		view.setup(node)
		view.chosen.connect(_on_node_chosen)

	if progress.current_node_id == -1:
		_floor_label.text = tr("Choose your path")
	else:
		var current: MapNode = graph.get_node(progress.current_node_id)
		_floor_label.text = tr("Floor %d") % current.floor


func _on_node_chosen(node_id: int) -> void:
	if not progress.travel_to(node_id):
		return
	var node: MapNode = graph.get_node(node_id)
	EventBus.map_node_chosen.emit(node_id, node.node_type)
	_refresh()
