extends Control
## Controller for the main menu screen. Pure UI — shows "Continue Run" only
## when a save exists, and reports the player's choice up to the run-loop
## controller (GameRoot), which owns starting/resuming runs.

signal new_run_requested
signal continue_requested

@onready var _continue_button: Button = %ContinueButton
@onready var _new_run_button: Button = %NewRunButton


func _ready() -> void:
	_continue_button.pressed.connect(func() -> void: continue_requested.emit())
	_new_run_button.pressed.connect(func() -> void: new_run_requested.emit())


## Called by GameRoot each time the menu is shown, since whether a save
## exists can change between visits (e.g. after a run ends).
func refresh(has_save: bool) -> void:
	_continue_button.visible = has_save
