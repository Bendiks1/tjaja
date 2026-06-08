extends Control
## Controller for the character select screen. Lists the playable characters
## (just "the Revenant" for the MVP, but built to take more) as tappable
## cards and reports the choice for the run-loop controller to start a run with.

signal character_chosen(character: CharacterData)

const CharacterButtonScene: PackedScene = preload("res://scenes/components/character_option_view.tscn")

@onready var _option_row: HBoxContainer = %OptionRow

var _characters: Array[CharacterData] = []


## Populates the screen with `characters` to choose from.
func show_characters(characters: Array[CharacterData]) -> void:
	_characters = characters
	for child in _option_row.get_children():
		child.queue_free()

	for character in _characters:
		var view: Control = CharacterButtonScene.instantiate()
		_option_row.add_child(view)
		view.setup(character)
		view.chosen.connect(_on_character_chosen)


func _on_character_chosen(character_id: StringName) -> void:
	for character in _characters:
		if character.id == character_id:
			character_chosen.emit(character)
			return
