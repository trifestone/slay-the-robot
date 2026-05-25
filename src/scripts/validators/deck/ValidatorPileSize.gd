# Validator for checking the size of a given pile (deck, hand, etc)
extends BaseValidator

func _validation(_card_data: CardData, _action: BaseAction, values: Dictionary[String, Variant]) -> bool:
	var card_pick_type: int = _get_validator_value("card_pick_type", values, _action, ActionBasePickCards.CARD_PICK_TYPES.HAND)
	var operator: String = _get_validator_value("operator", values, _action, ">") 	# whether to use turn or total stat for the fight
	var comparison_value: Variant = _get_validator_value("comparison_value", values, _action, 0)
	
	var pile: Array[CardData] = Global.player_data.get_pile(card_pick_type)
	
	# if taking hand, use hand at time of card play if it exists
	if card_pick_type == ActionBasePickCards.CARD_PICK_TYPES.HAND:
		if _action != null:
			if _action.card_play_request != null:
				pile = _action.card_play_request.hand_at_play_time
	
	return _compare(len(pile), comparison_value, operator)
