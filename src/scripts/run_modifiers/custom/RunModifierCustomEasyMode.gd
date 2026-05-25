extends BaseRunModifier

func run_start_modification() -> void:
	print("Easy Mode Enabled")
	Global.player_data.add_artifact("artifact_easy_mode")
