extends Control
## Displays a single card and reports taps/long-presses up to whoever owns the
## hand. Pure UI — it never touches CombatState directly; the combat screen
## decides what a tap means (select to target, or play if no target needed).

signal tapped(instance_id: int)
signal long_pressed(instance_id: int)

const LONG_PRESS_SECONDS: float = 0.45

@onready var _name_label: Label = %NameLabel
@onready var _cost_label: Label = %CostLabel
@onready var _description_label: Label = %DescriptionLabel
@onready var _background: ColorRect = %Background

var _instance_id: int = -1
var _press_time: float = 0.0
var _is_pressed: bool = false
var _long_press_fired: bool = false


func setup(card: CardInstance, playable: bool) -> void:
	_instance_id = card.instance_id
	_name_label.text = tr(card.definition.display_name)
	_cost_label.text = str(card.definition.cost)
	_description_label.text = tr(card.definition.description)
	set_playable(playable)


## Dims unaffordable cards so the player can see at a glance what they can play —
## the UI is expected to keep them tappable for inspection, just visually muted.
func set_playable(playable: bool) -> void:
	modulate = Color(1, 1, 1, 1) if playable else Color(0.55, 0.55, 0.6, 1)


func set_selected(selected: bool) -> void:
	_background.color = Color(0.55, 0.45, 0.15, 1) if selected else Color(0.16, 0.16, 0.22, 1)


func _gui_input(event: InputEvent) -> void:
	var pressed: bool
	if event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pressed = (event as InputEventMouseButton).pressed
	else:
		return

	if pressed:
		_is_pressed = true
		_long_press_fired = false
		_press_time = 0.0
	else:
		if _is_pressed and not _long_press_fired:
			tapped.emit(_instance_id)
		_is_pressed = false


func _process(delta: float) -> void:
	if not _is_pressed or _long_press_fired:
		return
	_press_time += delta
	if _press_time >= LONG_PRESS_SECONDS:
		_long_press_fired = true
		long_pressed.emit(_instance_id)
