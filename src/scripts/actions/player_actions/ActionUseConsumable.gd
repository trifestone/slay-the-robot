## Interceptable action to use a consumable in a given slot
extends BaseAction

func perform_action():
	var action_interceptor_processors: Array[ActionInterceptorProcessor] = _intercept_action([])
	for action_interceptor_processor in action_interceptor_processors:
		var consumable_slot_index: int = action_interceptor_processor.get_shadowed_action_values("consumable_slot_index", 0)
		
		var consumable_data: ConsumableData = Global.get_player_consumable_in_slot_index(consumable_slot_index)
		if consumable_data != null:
			# remove consumable
			var player_data: PlayerData = Global.player_data
			player_data.player_consumable_slot_to_consumable_object_id.erase(str(consumable_slot_index))
			
			# perform actions of consumable
			if consumable_data != null:
				var action_data: Array[Dictionary] = consumable_data.consumable_actions
				var player: Player = Global.get_player()
				
				var generated_actions: Array[BaseAction] = ActionGenerator.create_actions(player, null, targets, action_data, null)
				ActionHandler.add_actions(generated_actions)
		
			Signals.consumable_used.emit(consumable_slot_index, consumable_data.object_id)
		

func _to_string():
	var consumable_slot_index: int = get_action_value("consumable_slot_index", "")
	return "Use Consumable Action: " + str(consumable_slot_index)
