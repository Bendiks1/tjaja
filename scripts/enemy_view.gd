extends Control
## Displays one enemy's name, HP, block, and telegraphed intent, and reports
## taps so the combat screen can use it as a target picker. Pure UI — reads
## an EnemyState snapshot each refresh, never mutates it.

signal tapped(enemy_index: int)

## Maps EnemyIntent.Kind -> a placeholder glyph + the color that communicates
## "this is what's coming" at a glance (red = danger, blue = defensive).
const INTENT_GLYPHS: Dictionary = {
	EnemyIntent.Kind.ATTACK: ["⚔", Color(0.85, 0.3, 0.3)],
	EnemyIntent.Kind.DEFEND: ["🛡", Color(0.3, 0.55, 0.85)],
	EnemyIntent.Kind.BUFF_SELF: ["↑", Color(0.8, 0.7, 0.25)],
	EnemyIntent.Kind.DEBUFF_PLAYER: ["↓", Color(0.65, 0.35, 0.75)],
	EnemyIntent.Kind.UNKNOWN: ["?", Color(0.6, 0.6, 0.6)],
}

@onready var _name_label: Label = %NameLabel
@onready var _hp_label: Label = %HpLabel
@onready var _hp_bar: ProgressBar = %HpBar
@onready var _block_label: Label = %BlockLabel
@onready var _intent_label: Label = %IntentLabel
@onready var _intent_value_label: Label = %IntentValueLabel

var _enemy_index: int = -1
var _enemy: EnemyState


func setup(enemy: EnemyState, index: int) -> void:
	_enemy = enemy
	_enemy_index = index
	_name_label.text = tr(String(enemy.enemy_id))
	_hp_bar.max_value = enemy.max_hp
	refresh()


## Re-reads the live EnemyState. Call after any combat event that could have
## changed this enemy (damage, block, status, intent change).
func refresh() -> void:
	if _enemy == null:
		return
	_hp_label.text = "%d / %d" % [max(_enemy.current_hp, 0), _enemy.max_hp]
	_hp_bar.value = _enemy.current_hp
	_block_label.visible = _enemy.block > 0
	_block_label.text = "🛡 %d" % _enemy.block
	visible = _enemy.is_alive()
	_refresh_intent()


func _refresh_intent() -> void:
	var intent: EnemyIntent = _enemy.current_intent
	var glyph_and_color: Array = INTENT_GLYPHS.get(intent.kind, INTENT_GLYPHS[EnemyIntent.Kind.UNKNOWN])
	_intent_label.text = glyph_and_color[0]
	_intent_label.modulate = glyph_and_color[1]
	_intent_value_label.text = str(intent.value) if intent.value > 0 else ""


func _gui_input(event: InputEvent) -> void:
	var pressed: bool
	if event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pressed = (event as InputEventMouseButton).pressed
	else:
		return
	if not pressed and _enemy.is_alive():
		tapped.emit(_enemy_index)
