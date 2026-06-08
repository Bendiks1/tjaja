extends GutTest
## Integration tests for the character select screen: rendering options and
## reporting the chosen character.

const CharacterSelectScreenScene: PackedScene = preload("res://scenes/screens/character_select_screen.tscn")

func _character(id: StringName, hp: int = 70) -> CharacterData:
	var character := CharacterData.new()
	character.id = id
	character.display_name = String(id).capitalize()
	character.description = "A test character."
	character.starting_hp = hp
	character.starting_energy = 3
	return character


func _characters() -> Array[CharacterData]:
	return [_character(&"revenant", 70), _character(&"paladin", 80)]


func test_show_characters_renders_an_option_per_character() -> void:
	var screen: Control = CharacterSelectScreenScene.instantiate()
	add_child_autofree(screen)

	screen.show_characters(_characters())

	assert_eq(screen._option_row.get_child_count(), 2)


func test_choosing_an_option_emits_character_chosen_with_its_data() -> void:
	var screen: Control = CharacterSelectScreenScene.instantiate()
	add_child_autofree(screen)
	var characters: Array[CharacterData] = _characters()
	screen.show_characters(characters)

	var watcher := watch_signals(screen)
	var first_option: Control = screen._option_row.get_child(0)
	first_option.chosen.emit(characters[0].id)

	assert_signal_emitted_with_parameters(screen, "character_chosen", [characters[0]])
