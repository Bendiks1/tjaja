extends Node
## Serializes RunState to JSON in user:// and loads it back. The map graph
## itself is never saved — `run_seed` + `act_number` regenerate it identically
## via MapGenerator, so the save file only needs to record where the run is.

const SAVE_PATH: String = "user://save.json"


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Writes the active RunState to disk. Safe to call mid-combat — `combat_snapshot`
## (set by whoever paused the fight) is carried through verbatim.
func save(run_state: RunState) -> void:
	var data: Dictionary = {
		"character_id": String(run_state.character_id),
		"run_seed": run_state.run_seed,
		"act_number": run_state.act_number,
		"gold": run_state.gold,
		"max_hp": run_state.max_hp,
		"current_hp": run_state.current_hp,
		"deck_card_ids": run_state.deck_card_ids.map(func(id: StringName) -> String: return String(id)),
		"map_current_node_id": run_state.map_current_node_id,
		"map_visited_node_ids": run_state.map_visited_node_ids,
		"combat_snapshot": run_state.combat_snapshot,
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


## Loads a save into `run_state`, replacing whatever was there. Returns false
## (leaving `run_state` untouched) if there's no save or it's corrupt.
func load_into(run_state: RunState) -> bool:
	if not has_save():
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return false
	var data: Dictionary = parsed

	run_state.has_active_run = true
	run_state.character_id = StringName(data.get("character_id", ""))
	run_state.run_seed = int(data.get("run_seed", 0))
	run_state.act_number = int(data.get("act_number", 1))
	run_state.gold = int(data.get("gold", 0))
	run_state.max_hp = int(data.get("max_hp", 0))
	run_state.current_hp = int(data.get("current_hp", 0))

	run_state.deck_card_ids.clear()
	for id in data.get("deck_card_ids", []):
		run_state.deck_card_ids.append(StringName(id))

	run_state.map_current_node_id = int(data.get("map_current_node_id", -1))
	run_state.map_visited_node_ids.clear()
	for id in data.get("map_visited_node_ids", []):
		run_state.map_visited_node_ids.append(int(id))

	run_state.combat_snapshot = data.get("combat_snapshot", {})
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
