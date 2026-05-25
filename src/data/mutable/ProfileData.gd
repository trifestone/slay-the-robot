## Maintains data for the player
extends SerializableData
class_name ProfileData

@export var profile_name: String = ""

@export var profile_total_wins: int = 0
@export var profile_total_losses: int = 0
@export var profile_total_runs: int = 0
@export var profile_character_object_id_to_wins: Dictionary[String, int] = {}
@export var profile_character_object_id_to_losses: Dictionary[String, int] = {}

@export var profile_character_object_id_to_highest_difficulty: Dictionary[String, int] = {}

func win_run(character_object_id: String) -> void:
	profile_total_wins += 1
	var character_wins: int = profile_character_object_id_to_wins.get(character_object_id, 0)
	character_wins += 1
	profile_character_object_id_to_wins[character_object_id] = character_wins

func lose_run(character_object_id: String) -> void:
	profile_total_losses += 1
	var character_losses: int = profile_character_object_id_to_losses.get(character_object_id, 0)
	character_losses += 1
	profile_character_object_id_to_losses[character_object_id] = character_losses
