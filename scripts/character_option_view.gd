extends Control
## A single tappable character choice on the select screen. Pure UI — shows
## the character's name, blurb, and starting HP, and reports taps by id.

signal chosen(character_id: StringName)

@onready var _name_label: Label = %NameLabel
@onready var _description_label: Label = %DescriptionLabel
@onready var _hp_label: Label = %HpLabel

var _character_id: StringName = &""


func setup(character: CharacterData) -> void:
	_character_id = character.id
	_name_label.text = tr(character.display_name)
	_description_label.text = tr(character.description)
	_hp_label.text = tr("HP %d") % character.starting_hp


func _gui_input(event: InputEvent) -> void:
	var pressed: bool
	if event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pressed = (event as InputEventMouseButton).pressed
	else:
		return
	if not pressed:
		chosen.emit(_character_id)
