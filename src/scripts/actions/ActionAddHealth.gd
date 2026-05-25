# adds health and max health to the player
extends BaseAction

func perform_action():
	var action_interceptor_processors: Array[ActionInterceptorProcessor] = _intercept_action([])
	
	for action_interceptor_processor in action_interceptor_processors:
		var health_amount: int = action_interceptor_processor.get_shadowed_action_values("health_amount", 0)
		var health_max_amount: int = action_interceptor_processor.get_shadowed_action_values("health_max_amount", 0)
		Global.player_data.add_health(health_amount, health_max_amount)
	

func _to_string():
	var health_amount: int = get_action_value("health_amount", 0)
	var health_max_amount: int = get_action_value("health_max_amount", 0)
	return "Add Health Action: %s %s" % [health_amount, health_max_amount]
