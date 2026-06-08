extends Control
## A single tappable "go here next" choice on the map screen. Pure UI —
## displays a MapNode's type as a placeholder glyph + label and reports taps.

signal chosen(node_id: int)

const TYPE_INFO: Dictionary = {
	MapNode.NodeType.COMBAT: ["⚔", "Combat", Color(0.55, 0.2, 0.2)],
	MapNode.NodeType.ELITE: ["👑", "Elite", Color(0.5, 0.25, 0.5)],
	MapNode.NodeType.SHOP: ["🏪", "Shop", Color(0.25, 0.45, 0.55)],
	MapNode.NodeType.REST: ["🔥", "Rest Site", Color(0.35, 0.5, 0.3)],
	MapNode.NodeType.EVENT: ["❓", "Event", Color(0.5, 0.45, 0.2)],
	MapNode.NodeType.BOSS: ["💀", "Boss", Color(0.6, 0.15, 0.15)],
}

@onready var _background: ColorRect = %Background
@onready var _glyph_label: Label = %GlyphLabel
@onready var _type_label: Label = %TypeLabel

var _node_id: int = -1


func setup(node: MapNode) -> void:
	_node_id = node.id
	var info: Array = TYPE_INFO[node.node_type]
	_glyph_label.text = info[0]
	_type_label.text = tr(info[1])
	_background.color = info[2]


func _gui_input(event: InputEvent) -> void:
	var pressed: bool
	if event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pressed = (event as InputEventMouseButton).pressed
	else:
		return
	if not pressed:
		chosen.emit(_node_id)
