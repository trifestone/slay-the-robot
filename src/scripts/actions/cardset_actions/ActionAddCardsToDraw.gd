# Action to add cards to your draw pile
extends BaseCardsetAction

func perform_action() -> void:
	
	var action_interceptor_processors: Array[ActionInterceptorProcessor] = _intercept_action([])
	for action_interceptor_processor in action_interceptor_processors:
		var picked_cards: Array[CardData] = _get_picked_cards()
		var card_destination: int = action_interceptor_processor.get_shadowed_action_values("card_destination", CardPlayRequest.CARD_PLAY_DESTINATIONS.DRAW_TOP)
		Signals.card_add_to_draw_requested.emit(picked_cards, card_destination)
