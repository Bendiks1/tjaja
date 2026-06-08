class_name ContentDatabase
extends RefCounted
## Looks up content Resources by the stable string ids that get saved in
## RunState — saves store "strike"/"grave_rat"/"revenant", never Resource
## references, so a save file survives content being reorganized on disk.
## Centralizing the id -> path map here means persistence code never hardcodes
## res:// paths.

const CARD_PATHS: Array[String] = [
	"res://data/cards/strike.tres",
	"res://data/cards/defend.tres",
	"res://data/cards/soul_rend.tres",
	"res://data/cards/heavy_swing.tres",
	"res://data/cards/iron_resolve.tres",
	"res://data/cards/cleave.tres",
	"res://data/cards/bleeding_strike.tres",
	"res://data/cards/grim_focus.tres",
	"res://data/cards/battle_trance.tres",
	"res://data/cards/second_wind.tres",
]

const ENEMY_PATHS: Array[String] = [
	"res://data/enemies/grave_rat.tres",
	"res://data/enemies/bone_sentinel.tres",
	"res://data/enemies/charnel_brute.tres",
]

const CHARACTER_PATHS: Array[String] = [
	"res://data/characters/revenant.tres",
]

const ACT_PATHS: Array[String] = [
	"res://data/acts/act_1.tres",
]

static var _cards: Dictionary = {} # StringName -> CardData
static var _enemies: Dictionary = {} # StringName -> EnemyData
static var _characters: Dictionary = {} # StringName -> CharacterData
static var _acts: Dictionary = {} # int -> ActData


static func card_data(id: StringName) -> CardData:
	_ensure_loaded()
	return _cards.get(id)


static func enemy_data(id: StringName) -> EnemyData:
	_ensure_loaded()
	return _enemies.get(id)


static func character_data(id: StringName) -> CharacterData:
	_ensure_loaded()
	return _characters.get(id)


static func act_data(act_number: int) -> ActData:
	_ensure_loaded()
	return _acts.get(act_number)


static func all_characters() -> Array[CharacterData]:
	_ensure_loaded()
	var result: Array[CharacterData] = []
	for id in _characters:
		result.append(_characters[id])
	return result


static func _ensure_loaded() -> void:
	if not _cards.is_empty():
		return
	for path in CARD_PATHS:
		var data: CardData = load(path)
		_cards[data.id] = data
	for path in ENEMY_PATHS:
		var data: EnemyData = load(path)
		_enemies[data.id] = data
	for path in CHARACTER_PATHS:
		var data: CharacterData = load(path)
		_characters[data.id] = data
	for path in ACT_PATHS:
		var data: ActData = load(path)
		_acts[data.act_number] = data
