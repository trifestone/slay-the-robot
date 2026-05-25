# adds both permanent and combat energy to the player
extends BaseAction

func perform_action():
	var action_interceptor_processors: Array[ActionInterceptorProcessor] = _intercept_action([])
	
	for action_interceptor_processor in action_interceptor_processors:
		# combat energy
		var energy_amount: int = action_interceptor_processor.get_shadowed_action_values("energy_amount", 0)
		Global.player_data.player_energy += energy_amount
		# max energy (permanent)
		var energy_amount_max: int = action_interceptor_processor.get_shadowed_action_values("energy_amount_max", 0)
		Global.player_data.player_energy_max = max(Global.player_data.player_energy_max + energy_amount_max, 1)
		
		Signals.energy_added.emit(energy_amount)

func _to_string():
	var energy_amount: int = get_action_value("energy_amount", 0)
	var energy_amount_max: int = get_action_value("energy_amount_max", 0)
	return "Add Energy Action: {0}, {1}".format([energy_amount, energy_amount_max])
