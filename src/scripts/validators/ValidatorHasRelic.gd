# Validator for checking a relic
extends BaseValidator

func _validation(_card_data: CardData, _action: BaseAction, values: Dictionary[String, Variant]) -> bool:
	var artifact_id: String = _get_validator_value("artifact_id", values, _action, "")
	return len(Global.player_data.get_player_artifacts_with_artifact_id(artifact_id)) > 0
