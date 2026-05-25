extends BaseAction

func perform_action():
	var artifact_id: String = get_action_value("artifact_id", "")
	var artifact_data: ArtifactData = Global.get_artifact_data_from_prototype(artifact_id)
	if artifact_data != null:
		Global.player_data.add_artifact(artifact_id)

func _to_string():
	var artifact_id: String = get_action_value("artifact_id", "")
	return "Add Artifact Action: " + artifact_id
