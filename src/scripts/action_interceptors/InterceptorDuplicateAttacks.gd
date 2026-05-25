# duplicates the next X number of attack cards
# this intercepts the special immediate action ActionCardPlay as it is being processed in Hand
extends BaseActionInterceptor

var DUPLICATE_ATTACKS_STATUS_EFFECT_ID: String = "status_effect_duplicate_attacks"

func process_action_interception(action_interceptor_processor: ActionInterceptorProcessor, preview_mode: bool = false) -> int:
	if preview_mode:
		return ACTION_ACCEPTENCES.CONTINUE
	
	var parent_combatant: BaseCombatant = action_interceptor_processor.parent_action.parent_combatant
	
	var card_play_request: CardPlayRequest = action_interceptor_processor.parent_action.card_play_request
	# will not duplicate duplicated plays
	if not card_play_request.is_duplicate_play:
		# must be an attack card
		if card_play_request.card_data.card_type == CardData.CARD_TYPES.ATTACK:
			# must have enough charges
			var status_charges: int = parent_combatant.get_status_charges(DUPLICATE_ATTACKS_STATUS_EFFECT_ID)
			if status_charges > 0:
				# remove a charge
				parent_combatant.add_status_effect_charges(DUPLICATE_ATTACKS_STATUS_EFFECT_ID, -1, 0)
				# duplicate the card play
				var new_card_play_request: CardPlayRequest = CardPlayRequest.new()
				new_card_play_request.card_data = card_play_request.card_data
				new_card_play_request.selected_target = card_play_request.selected_target
				new_card_play_request.card_values = card_play_request.card_data.card_values.duplicate(true)
				new_card_play_request.refundable_energy = 0
				new_card_play_request.input_energy = card_play_request.input_energy
				new_card_play_request.is_duplicate_play = true
				# request duplicate play
				Signals.card_play_requested.emit(new_card_play_request, false, true)
				return ACTION_ACCEPTENCES.STOPPED
	
	return ACTION_ACCEPTENCES.CONTINUE
